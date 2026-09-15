#!/usr/bin/env python3
"""P7 — 8 migration'ı prod'a uygula (Sahip onaylı PROD YAZIMI 2026-09-15).

Zarf (P7 §2): sıra 20260913000001→04, 20260914000001→04; her dosya ayrı
transaction, dosya metni olduğu gibi; kendi BEGIN/COMMIT'i olan 7 dosyada
çift sarmalama YOK (atomiklik dosyanın kendi transaction kontrolünden);
20260913000004 tek CREATE OR REPLACE statement (kendiliğinden atomik).
İLK HATADA DUR: ham hatayı kaydet, exit 2, sonrakilere geçme.

Koruma: betik yalnız aşağıdaki 8 dosyayı gönderir. Başlamadan yedek manifest
kapılarını (gate_A/gate_B OK) ve sentinelleri (degisim_log/surum_gizli hâlâ
yok) doğrular — biri tersse uygulamadan çıkar.
sahip_sifresi_ayarla ÇAĞRILMAZ (zarf §2 — root kendisi kuracak).
"""
import json, subprocess, pathlib, re, sys, time, datetime

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[1]
PROD_REF = "zqnexqbdfvbhlxzelzju"
BACKUP = pathlib.Path("/home/melik/tmp/agents/prod-yedek-2026-09-15-adim-b")

FILES = [
    "20260913000001_surum_gecmisi_f1_degisim_log.sql",
    "20260913000002_surum_gecmisi_f2_geri_alma.sql",
    "20260913000003_surum_gecmisi_f2_sahip_sifresi.sql",
    "20260913000004_luna_bilet_maske.sql",
    "20260914000001_l4_islem_log_kopru.sql",
    "20260914000002_l4_geri_alma_zincir.sql",
    "20260914000003_l4_onarim.sql",
    "20260914000004_l4_stok_uyari_txid.sql",
]

TOK = re.search(r"^SUPABASE_MANAGEMENT_TOKEN=(.*)$",
                pathlib.Path("/home/melik/tools-bank/.env").read_text(), re.M).group(1).strip()


def run_sql(sql, max_time=300):
    body = json.dumps({"query": sql})
    r = subprocess.run(
        ["curl", "-sS", "-X", "POST",
         f"https://api.supabase.com/v1/projects/{PROD_REF}/database/query",
         "-H", f"Authorization: Bearer {TOK}", "-H", "Content-Type: application/json",
         "-d", body, "--max-time", str(max_time)],
        capture_output=True, text=True)
    return r


# ---- kapı 0: yedek manifest kapıları ----
man = BACKUP / "manifest.json"
if not man.exists():
    sys.exit(f"DUR: yedek manifest yok: {man} — önce yedek (zarf §1).")
m = json.loads(man.read_text())
ga, gb = m.get("gate_A"), m.get("gate_B")
if ga != "OK - her tablo backup_rows == yedek-basi count(*)" or not (
        isinstance(gb, str) and gb.startswith("OK")):
    sys.exit(f"DUR: yedek kapıları yeşil değil: gate_A={ga!r} gate_B={gb!r}")
print(f"Yedek kapıları yeşil ({m['duration_s']}s, {len(m['files'])} dosya).")

# ---- kapı 1: sentineller hâlâ yok mu (ön kontrolden sonra biri uyguladıysa DUR) ----
r = run_sql("BEGIN READ ONLY; SELECT to_regclass('public.degisim_log') AS dl, "
            "EXISTS(SELECT 1 FROM pg_namespace WHERE nspname='surum_gizli') AS sg; ROLLBACK;")
try:
    row = json.loads(r.stdout)[0]
except Exception:
    sys.exit(f"DUR: sentinel sorgusu okunamadı: {r.stdout[:300]}")
if row["dl"] is not None or row["sg"]:
    sys.exit(f"DUR: sentinel nesne(lер) canlı göründü: {row} — biri uyguladı olabilir; sorulacak.")

log = {"started": datetime.datetime.now().astimezone().isoformat(),
       "prod_ref": PROD_REF, "backup_dir": str(BACKUP),
       "sentinel_precheck": row, "files": []}
t_all = time.time()

for i, fname in enumerate(FILES, 1):
    path = REPO / "supabase" / "migrations" / fname
    sql = path.read_text(encoding="utf-8")
    print(f"[{i}/8] {fname} ({len(sql)} bayt) gönderiliyor...", flush=True)
    t0 = time.time()
    r = run_sql(sql, max_time=300)
    dur = round(time.time() - t0, 1)

    resp_file = HERE / f"apply_{i:02d}_{fname.replace('.sql', '.txt')}"
    resp_file.write_text(r.stdout + (("\n[stderr] " + r.stderr) if r.stderr.strip() else ""))

    ok, detail = False, ""
    try:
        data = json.loads(r.stdout)
        if isinstance(data, list):
            ok = True
            detail = f"OK ({len(data)} sonuç kümesi)"
        elif isinstance(data, dict):
            detail = json.dumps(data)[:500]
    except Exception:
        detail = f"json parse: {r.stdout[:300]} {r.stderr[:200]}"

    has_tx = bool(re.search(r"^BEGIN;\s*$", sql, re.M)) and bool(re.search(r"^COMMIT;\s*$", sql, re.M))
    sent_as = ("dosya metni olduğu like — tek istek; dosyanın kendi BEGIN/COMMIT'i (çift sarmalama yok)"
               if has_tx else
               "dosya metni olduğu like — tek istek; tek CREATE OR REPLACE statement (kendiliğinden atomik)")
    log["files"].append({"n": i, "file": fname, "ok": ok, "duration_s": dur,
                         "response_file": resp_file.name, "detail": detail,
                         "sent_as": sent_as})
    print(f"     {dur}s — {detail}", flush=True)
    if not ok:
        log["finished"] = datetime.datetime.now().astimezone().isoformat()
        log["total_s"] = round(time.time() - t_all, 1)
        (HERE / "apply_log.json").write_text(json.dumps(log, indent=1, ensure_ascii=False))
        print(f"\nDUR — {fname} HATA (zarf §2: ilk hatada dur). Ham yanıt: {resp_file.name}")
        sys.exit(2)

log["finished"] = datetime.datetime.now().astimezone().isoformat()
log["total_s"] = round(time.time() - t_all, 1)
(HERE / "apply_log.json").write_text(json.dumps(log, indent=1, ensure_ascii=False))
print(f"\n8/8 UYGULAMA OK — toplam {log['total_s']}s.")
