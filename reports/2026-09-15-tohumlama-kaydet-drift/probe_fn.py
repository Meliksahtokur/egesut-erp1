#!/usr/bin/env python3
"""P3 — tohumlama_kaydet / tohumlama_tekrar_kaydet canlı gövde sondajı.

SADECE okuma: her istek BEGIN READ ONLY; SELECT ...; ROLLBACK; (P1 probe.py deseni).
Mgmt API üzerinden; token'lar .env'den okunur, çıktıya yazılmaz.

Çıktı: probe_fn_demo.json, probe_fn_prod.json, probe_fn_queries.sql
"""
import json, subprocess, pathlib, re, sys

HERE = pathlib.Path(__file__).resolve().parent
PROD_REF = "zqnexqbdfvbhlxzelzju"
PROD_TOKFILE = "/home/melik/tools-bank/.env"          # SUPABASE_MANAGEMENT_TOKEN
DEMO_ENVFILE = "/home/melik/egesut-erp1/.env"          # SUPABASE_DEMO_REF, SUPABASE_DEMO_PAT

FN_NAMES = ["tohumlama_kaydet", "tohumlama_tekrar_kaydet"]


def read_env(path, key):
    txt = pathlib.Path(path).read_text()
    m = re.search(rf"^{key}=(.*)$", txt, re.M)
    if not m:
        sys.exit(f"{key} yok: {path}")
    return m.group(1).strip().strip('"').strip("'")


SQL = f"""SELECT n.nspname AS schema, p.proname AS name,
       pg_get_function_identity_arguments(p.oid) AS args,
       pg_get_function_result(p.oid) AS ret,
       p.pronargs AS nargs,
       p.prosecdef AS secdef, p.provolatile AS vol, p.proowner::regrole::text AS owner,
       pg_get_functiondef(p.oid) AS fdef
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = ANY(ARRAY['{FN_NAMES[0]}','{FN_NAMES[1]}'])
ORDER BY p.proname, 3;"""


def run_sql(ref, token):
    body = json.dumps({"query": f"BEGIN READ ONLY; {SQL} ROLLBACK;"})
    r = subprocess.run(
        ["curl", "-sS", "-X", "POST", f"https://api.supabase.com/v1/projects/{ref}/database/query",
         "-H", f"Authorization: Bearer {token}", "-H", "Content-Type: application/json",
         "-d", body, "--max-time", "120"],
        capture_output=True, text=True)
    try:
        data = json.loads(r.stdout)
    except Exception:
        sys.exit(f"json parse hatası: {r.stdout[:300]} {r.stderr[:200]}")
    if isinstance(data, dict) and ("error" in data or "message" in data):
        sys.exit(f"DB hatası: {json.dumps(data)[:300]}")
    return data


(HERE / "probe_fn_queries.sql").write_text(f"-- P3 canlı fonksiyon sondajı (BEGIN READ ONLY sarmında)\n{SQL}\n")

if __name__ == "__main__":
    for tag, ref, tokfile, key in (
            ("demo", read_env(DEMO_ENVFILE, "SUPABASE_DEMO_REF"), DEMO_ENVFILE, "SUPABASE_DEMO_PAT"),
            ("prod", PROD_REF, PROD_TOKFILE, "SUPABASE_MANAGEMENT_TOKEN")):
        rows = run_sql(ref, read_env(tokfile, key))
        (HERE / f"probe_fn_{tag}.json").write_text(json.dumps(rows, indent=1, ensure_ascii=False))
        print(f"[{tag}] {len(rows)} overload:")
        for r in rows:
            print(f"   {r['name']}({r['nargs']} arg) -> {r['ret']} secdef={r['secdef']} fdef={len(r['fdef'] or '')} char")
