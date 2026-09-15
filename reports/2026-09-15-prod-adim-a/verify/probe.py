#!/usr/bin/env python3
"""P1 ölçüm — prod ve demo canlı şema sondajı.

SADECE okuma: her istek BEGIN READ ONLY; SELECT ...; ROLLBACK; şeklinde,
Mgmt API üzerinden. Token'lar .env dosyalarından okunur, çıktıya yazılmaz.

Çıktı: probe_prod.json, probe_demo.json + queries.sql (kanıt)
"""
import json, subprocess, pathlib, re, sys

HERE = pathlib.Path(__file__).resolve().parent
PROD_REF = "zqnexqbdfvbhlxzelzju"
PROD_TOKFILE = "/home/melik/tools-bank/.env"          # SUPABASE_MANAGEMENT_TOKEN
DEMO_ENVFILE = "/home/melik/egesut-erp1/.env"          # SUPABASE_DEMO_REF, SUPABASE_DEMO_PAT


def read_env(path, key):
    txt = pathlib.Path(path).read_text()
    m = re.search(rf"^{key}=(.*)$", txt, re.M)
    if not m:
        sys.exit(f"{key} yok: {path}")
    return m.group(1).strip().strip('"').strip("'")


INV = json.loads((HERE / "inventory.json").read_text())

# ---- isim listeleri ----
def unqual(n):
    return n.split(".")[-1].strip('"').lower()

fn_names = sorted({unqual(d["name"]) for v in INV.values() for d in v["functions"]})
fn_schema = sorted({("surum_gizli" if d["name"].startswith("surum_gizli.") else "public")
                    for v in INV.values() for d in v["functions"]})
grant_fn_names = sorted({unqual(g["obj"]) for v in INV.values() for g in v["grants"]
                         if g["kind"] == "FUNCTION"})
tables = sorted({t["table"] for v in INV.values() for t in v["tables"]}
                | {t["table"] for v in INV.values() for t in v["columns"]}
                | {t["table"] for v in INV.values() for t in v["triggers"] if t.get("table")}
                | {t["table"] for v in INV.values() for t in v["policies"]}
                | {t["table"] for v in INV.values() for t in v["indexes"]}
                | {t["table"] for v in INV.values() for t in v["rls"]})
grant_tables = sorted({unqual(g["obj"].split("(")[0]) for v in INV.values() for g in v["grants"]
                       if g["kind"] == "TABLE" and g["obj"].startswith("public.")})
col_tables = {t["table"] for v in INV.values() for t in v["columns"]}
col_names = sorted({t["column"] for v in INV.values() for t in v["columns"]})
trig_names = sorted({t["name"] for v in INV.values() for t in v["triggers"]})
pol_names = sorted({t["name"] for v in INV.values() for t in v["policies"]})
idx_names = sorted({t["name"] for v in INV.values() for t in v["indexes"] if t.get("name")})
con_names = sorted({t["name"] for v in INV.values() for t in v["constraints"]})
views = sorted({t["view"] for v in INV.values() for t in v["views"]})

Q = {}


def inlist(names):
    return "ARRAY[" + ",".join("'" + n.replace("'", "''") + "'" for n in names) + "]"


Q["functions"] = f"""SELECT n.nspname AS schema, p.proname AS name,
       pg_get_function_identity_arguments(p.oid) AS args,
       pg_get_function_result(p.oid) AS ret,
       p.prosecdef AS secdef, p.provolatile AS vol,
       pg_get_functiondef(p.oid) AS fdef
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public','surum_gizli') AND p.proname = ANY({inlist(fn_names)})
ORDER BY 1,2,3;"""

Q["tables"] = f"""SELECT n.nspname AS schema, c.relname AS name, c.relkind, c.relrowsecurity AS rls
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('public','surum_gizli') AND c.relkind IN ('r','p')
  AND c.relname = ANY({inlist(tables)});"""

Q["columns"] = f"""SELECT table_schema AS schema, table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema IN ('public','surum_gizli')
  AND table_name = ANY({inlist(sorted(col_tables))})
  AND column_name = ANY({inlist(col_names)});"""

Q["triggers"] = f"""SELECT n.nspname AS schema, cl.relname AS table_name, t.tgname AS name,
       pg_get_triggerdef(t.oid) AS tdef
FROM pg_trigger t JOIN pg_class cl ON cl.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = cl.relnamespace
WHERE NOT t.tgisinternal AND n.nspname = 'public'
  AND (cl.relname = ANY({inlist(tables)}) OR t.tgname = ANY({inlist(trig_names)}));"""

Q["policies"] = """SELECT schemaname AS schema, tablename, policyname AS name, cmd, roles
FROM pg_policies WHERE schemaname IN ('public','surum_gizli');"""

Q["indexes"] = f"""SELECT schemaname AS schema, tablename, indexname AS name, indexdef
FROM pg_indexes
WHERE schemaname IN ('public','surum_gizli')
  AND (indexname = ANY({inlist(idx_names)}) OR tablename = ANY({inlist(sorted(tables))}));"""

Q["constraints"] = f"""SELECT n.nspname::text AS schema, c.conrelid::regclass::text AS tbl,
       c.conname AS name, c.contype, pg_get_constraintdef(c.oid) AS cdef
FROM pg_constraint c JOIN pg_namespace n ON n.oid = c.connamespace
WHERE n.nspname IN ('public','surum_gizli')
  AND (c.conname = ANY({inlist(con_names)}) OR c.conrelid::regclass::text = ANY({inlist(sorted('public.' + t for t in col_tables))}));"""

Q["table_grants"] = f"""SELECT table_schema AS schema, table_name, grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema IN ('public','surum_gizli')
  AND table_name = ANY({inlist(sorted(set(tables) | set(grant_tables)))});"""

Q["routine_grants"] = f"""SELECT n.nspname AS schema, p.proname AS name, gr.rolname AS grantee,
       a.privilege_type
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
JOIN pg_roles gr ON gr.oid = a.grantee
WHERE n.nspname IN ('public','surum_gizli')
  AND p.proname = ANY({inlist(sorted(set(fn_names) | set(grant_fn_names)))});"""

Q["views"] = f"""SELECT schemaname AS schema, viewname AS name FROM pg_views
WHERE schemaname IN ('public','surum_gizli') AND viewname = ANY({inlist(views)});"""

Q["schema_ext"] = """SELECT 'schema' AS kind, nspname AS name FROM pg_namespace WHERE nspname = 'surum_gizli'
UNION ALL
SELECT 'extension:' || extname, n.nspname FROM pg_extension e
JOIN pg_namespace n ON n.oid = e.extnamespace WHERE extname = 'pgcrypto';"""

HERE_Q = HERE / "queries.sql"
with HERE_Q.open("w") as fh:
    for k, q in Q.items():
        fh.write(f"-- ==== {k} ====\n{q}\n\n")


def run_sql(label, sql, ref, token, out_errors):
    body = json.dumps({"query": f"BEGIN READ ONLY; {sql} ROLLBACK;"})
    r = subprocess.run(
        ["curl", "-sS", "-X", "POST", f"https://api.supabase.com/v1/projects/{ref}/database/query",
         "-H", f"Authorization: Bearer {token}", "-H", "Content-Type: application/json",
         "-d", body, "--max-time", "120"],
        capture_output=True, text=True)
    try:
        data = json.loads(r.stdout)
    except Exception:
        out_errors.append(f"{label}: json parse: {r.stdout[:300]} {r.stderr[:200]}")
        return None
    if isinstance(data, dict) and ("error" in data or "message" in data):
        out_errors.append(f"{label}: {json.dumps(data)[:300]}")
        return None
    return data


def probe_db(tag, ref, token):
    out, errors = {}, []
    for k, q in Q.items():
        res = run_sql(k, q, ref, token, errors)
        out[k] = res
        n = len(res) if isinstance(res, list) else "-"
        print(f"[{tag}] {k}: {n} satır", flush=True)
    (HERE / f"probe_{tag}.json").write_text(json.dumps(out, indent=1, ensure_ascii=False))
    if errors:
        (HERE / f"probe_{tag}_ERRORS.txt").write_text("\n".join(errors))
        print(f"[{tag}] HATALAR: {len(errors)}")
        for e in errors[:10]:
            print("   ", e[:200])
    else:
        print(f"[{tag}] hata yok")


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "both"
    if which in ("prod", "both"):
        probe_db("prod", PROD_REF, read_env(PROD_TOKFILE, "SUPABASE_MANAGEMENT_TOKEN"))
    if which in ("demo", "both"):
        probe_db("demo", read_env(DEMO_ENVFILE, "SUPABASE_DEMO_REF"),
                 read_env(DEMO_ENVFILE, "SUPABASE_DEMO_PAT"))
