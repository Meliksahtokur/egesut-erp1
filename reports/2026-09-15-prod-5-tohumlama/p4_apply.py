#!/usr/bin/env python3
"""P4 — #5 migration'ı prod'a uygula (Sahip onaylı PROD YAZIMI — tek dosya).

Zarf (P4 §2): `20260910000002_sperma_eslesme_sertlestirme.sql` tek transaction,
dosya metni olduğu gibi. Dosya KENDİ BEGIN/COMMIT'İNİ İÇERMEZ (grep kanıtı:
yalnız DO/fonksiyon blok açılış BEGIN'leri) — atomiklik tek DO $do$ statement'ından
gelir; çift sarmalama yapılmaz. Hata olursa DUR: ham hatayı kaydet, exit 2.

Koruma: betik yalnız bu TEK dosyayı gönderir; başka dosya koşulmaz.
"""
import json, subprocess, pathlib, re, sys, time, datetime

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[1]   # worktree kökü: .../agent/prod-tohumlama-5
PROD_REF = "zqnexqbdfvbhlxzelzju"
FILE = "20260910000002_sperma_eslesme_sertlestirme.sql"
MIG = REPO / "supabase" / "migrations" / FILE

TOK = re.search(r"^SUPABASE_MANAGEMENT_TOKEN=(.*)$",
                pathlib.Path("/home/melik/tools-bank/.env").read_text(), re.M).group(1).strip()

sql = MIG.read_text(encoding="utf-8")
low = sql.lower()
for kw in ("start transaction", "\ncommit", "\nbegin;", "\nbegin "):
    if kw in low:
        sys.exit(f"DUR: dosya transaction kontrolü içeriyor ({kw!r}) — zarf gereği elle karar.")
print(f"Dosya: {FILE} ({len(sql)} bayt) — transaction kontrolü yok, tek DO statement.")

body = json.dumps({"query": sql})
t0 = time.time()
r = subprocess.run(
    ["curl", "-sS", "-X", "POST",
     f"https://api.supabase.com/v1/projects/{PROD_REF}/database/query",
     "-H", f"Authorization: Bearer {TOK}", "-H", "Content-Type: application/json",
     "-d", body, "--max-time", "120"],
    capture_output=True, text=True)
dur = round(time.time() - t0, 1)

resp_file = HERE / f"apply_01_{FILE.replace('.sql', '.txt')}"
resp_file.write_text(r.stdout + (("\n[stderr] " + r.stderr) if r.stderr.strip() else ""))

ok = False
detail = ""
try:
    data = json.loads(r.stdout)
    if isinstance(data, list):
        ok = True
        detail = f"OK ({len(data)} sonuç kümesi)"
    elif isinstance(data, dict):
        detail = json.dumps(data)[:500]
except Exception:
    detail = f"json parse: {r.stdout[:300]} {r.stderr[:200]}"

log = {
    "started": datetime.datetime.now().astimezone().isoformat(),
    "prod_ref": PROD_REF,
    "files": [{
        "n": 1, "file": FILE, "ok": ok, "duration_s": dur,
        "response_file": resp_file.name, "detail": detail,
        "sent_as": "dosya metni olduğu gibi — tek istek; atomiklik dosyanın tek DO $do$ statement'ından",
    }],
    "finished": datetime.datetime.now().astimezone().isoformat(),
    "total_s": dur,
}
(HERE / "apply_log.json").write_text(json.dumps(log, indent=1, ensure_ascii=False))
print(f"Süre: {dur}s — yanıt: {detail}")
if not ok:
    print("\nDUR — uygulama hatası (zarf §2): ham yanıt apply_01_*.txt içinde; sorulacak.")
    sys.exit(2)
print("UYGULAMA OK.")
