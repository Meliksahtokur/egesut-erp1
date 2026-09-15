#!/usr/bin/env python3
"""P2 Adım A — 9 main-borcu migration'ını prod'a uygula (Mgmt API).

Zarf: her dosya AYRI transaction (BEGIN; <dosya>; COMMIT;), dosya metni
olduğu gibi; #5 (20260910000002) ATLA; 20260902000001 ASLA koşulmaz.
İLK HATADA DUR (exit 1). Ham yanıtlar reports/2026-09-15-prod-adim-a/ altına.
Token hiçbir çıktıya yazılmaz.
"""
import json, subprocess, pathlib, re, sys, time, datetime

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[1]
MIG = REPO / "supabase" / "migrations"
PROD_REF = "zqnexqbdfvbhlxzelzju"

TOK = re.search(r"^SUPABASE_MANAGEMENT_TOKEN=(.*)$",
                pathlib.Path("/home/melik/tools-bank/.env").read_text(), re.M).group(1).strip()

FILES = [
    "20260831000003_tablo_guard_triggerlari.sql",
    "20260909100000_dozaj_std_dose_seed.sql",
    "20260909110000_dozaj_helper_min_max_rpc.sql",
    "20260910000001_planli_tohumlama_sperma_dus.sql",
    # 20260910000002_sperma_eslesme_sertlestirme.sql — ATLA (P3)
    "20260910000003_gebelik_kaydet_manual_42804_fix.sql",
    "20260911000001_dogum_buzagi_id_foundation.sql",
    "20260911000002_pedigree_foundation.sql",
    "20260911000003_pedigree_farm_backfill.sql",
    "20260911000004_pedigree_projection_rpc.sql",
]

log = {"started": datetime.datetime.now().astimezone().isoformat(), "prod_ref": PROD_REF,
       "files": []}

for i, fname in enumerate(FILES, 1):
    sql_text = (MIG / fname).read_text()
    if re.search(r"^\s*BEGIN\s*;|\s*COMMIT\s*;", sql_text, re.M):
        sys.exit(f"{fname}: dosya kendi BEGIN/COMMIT'ini içeriyor — sarma kuralı belirsiz, DUR")
    body = json.dumps({"query": f"BEGIN;\n{sql_text}\nCOMMIT;"})
    t0 = time.time()
    r = subprocess.run(
        ["curl", "-sS", "-X", "POST",
         f"https://api.supabase.com/v1/projects/{PROD_REF}/database/query",
         "-H", f"Authorization: Bearer {TOK}", "-H", "Content-Type: application/json",
         "-d", body, "--max-time", "300"],
        capture_output=True, text=True)
    dt = round(time.time() - t0, 1)
    out = HERE / f"apply_{i:02d}_{fname.replace('.sql', '')}.txt"
    out.write_text(r.stdout + (("\n[stderr] " + r.stderr) if r.stderr else ""))
    ok = False
    detail = ""
    try:
        data = json.loads(r.stdout)
        if isinstance(data, list):
            ok = True
            detail = f"OK ({len(data)} sonuç kümesi)"
        else:
            detail = json.dumps(data, ensure_ascii=False)[:500]
    except Exception:
        detail = (r.stdout or r.stderr)[:500]
    entry = {"n": i, "file": fname, "ok": ok, "duration_s": dt,
             "response_file": out.name, "detail": detail[:300]}
    log["files"].append(entry)
    print(f"[{i}/9] {fname}: {'OK' if ok else 'HATA'} ({dt}s) {detail[:200]}", flush=True)
    (HERE / "apply_log.json").write_text(json.dumps(log, ensure_ascii=False, indent=1))
    if not ok:
        print(f"\nİLK HATA dosya {i}: {fname} → DUR (zarf gereği). Sonraki dosyalar koşulmadı.")
        sys.exit(1)

log["finished"] = datetime.datetime.now().astimezone().isoformat()
log["total_s"] = round(sum(f["duration_s"] for f in log["files"]), 1)
(HERE / "apply_log.json").write_text(json.dumps(log, ensure_ascii=False, indent=1))
print(f"\n9/9 dosya uygulandı, toplam {log['total_s']}s")
