#!/usr/bin/env python3
"""P5 — C noktası: canlı PROD anlık dökümü (Mgmt API, SALT OKUNUR).

P2 backup_prod.py yöntemiyle (parçalı json_agg + şema yakalama) aynı format;
her sorgu `BEGIN READ ONLY; ... ROLLBACK;` sarmında (zarf gereği). Çıktı REPO
DIŞI: /home/melik/tmp/agents/github-yedek-2026-09-15/live_c/. Token hiçbir
çıktıya yazılmaz. Öntanımlı OUT üzerine YAZMAZ — Y yedeği ayrı ve dokunulmaz.
"""
import json, subprocess, pathlib, re, sys, time, hashlib, datetime

HERE = pathlib.Path(__file__).resolve().parent
PROD_REF = "zqnexqbdfvbhlxzelzju"
OUT = pathlib.Path("/home/melik/tmp/agents/github-yedek-2026-09-15/live_c")
OUT.mkdir(parents=True, exist_ok=True)

TOK = re.search(r"^SUPABASE_MANAGEMENT_TOKEN=(.*)$",
                pathlib.Path("/home/melik/tools-bank/.env").read_text(), re.M).group(1).strip()


def q(sql, max_time=300):
    """Tek Mgmt API isteği, READ ONLY sarmında. Dönüş: (parsed, error_or_None)."""
    body = json.dumps({"query": f"BEGIN READ ONLY; {sql} ROLLBACK;"})
    r = subprocess.run(
        ["curl", "-sS", "-X", "POST",
         f"https://api.supabase.com/v1/projects/{PROD_REF}/database/query",
         "-H", f"Authorization: Bearer {TOK}", "-H", "Content-Type: application/json",
         "-d", body, "--max-time", str(max_time)],
        capture_output=True, text=True)
    try:
        data = json.loads(r.stdout)
    except Exception:
        return None, f"json parse: {r.stdout[:200]} {r.stderr[:200]}"
    if isinstance(data, dict) and ("error" in data or "message" in data):
        return None, json.dumps(data)[:300]
    return data, None


def qi(sql):
    data, err = q(sql)
    if err:
        sys.exit(f"METADATA HATASI: {err}\nSQL: {sql[:200]}")
    return data


def qid(x):
    return '"' + x.replace('"', '""') + '"'


t0 = time.time()
meta = {"started": datetime.datetime.now().astimezone().isoformat(), "prod_ref": PROD_REF,
        "purpose": "P5 C noktasi (canli prod, P4-#5 dahil olmayabilir; zaman damgasi asagida)",
        "method": "Mgmt API /database/query, her istek BEGIN READ ONLY; ... ROLLBACK; sarminda",
        "files": {}}

# ---- 1. public tablolar + kesin satır sayıları ----
tables = qi("SELECT c.relname AS name, c.relrowsecurity AS rls "
            "FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace "
            "WHERE n.nspname='public' AND c.relkind IN ('r','p') ORDER BY 1;")
tab_meta = {}
for t in tables:
    n = qi(f"SELECT count(*) AS n FROM public.{qid(t['name'])};")
    tab_meta[t["name"]] = {"rls": t["rls"], "rows": n[0]["n"]}
print("public tablolar:", {k: v["rows"] for k, v in sorted(tab_meta.items())}, flush=True)

# ---- 2. tablo verileri (parçalı json_agg, Y formatı ile birebir) ----
for name, m in sorted(tab_meta.items()):
    tf0 = time.time()
    chunk, offset, rows, chunks = 500, 0, [], 0
    tq = f"public.{qid(name)}"
    while True:
        sql = (f"SELECT COALESCE(json_agg(x),'[]'::json) AS batch FROM "
               f"(SELECT * FROM {tq} LIMIT {chunk} OFFSET {offset}) x;")
        data, err = q(sql)
        if err or not isinstance(data, list) or not data:
            if chunk > 50:
                chunk = max(chunk // 2, 50)
                continue
            sys.exit(f"TABLO VERİ HATASI {name}@{offset}: {err or data}")
        batch = data[0]["batch"]
        rows.extend(batch)
        chunks += 1
        offset += len(batch)
        if len(batch) < chunk:
            break
    f = OUT / f"table_{name}.json"
    doc = {"table": name, "rows": len(rows), "chunks": chunks, "data": rows}
    f.write_text(json.dumps(doc, ensure_ascii=False))
    m["backup_rows"] = len(rows)
    meta["files"][f.name] = {"bytes": f.stat().st_size, "rows": len(rows)}
    print(f"  {name}: {len(rows)} satır ({chunks} parça, {f.stat().st_size} B, "
          f"{time.time()-tf0:.1f}s)", flush=True)

# ---- 3. şema tanımları (P2 CAPTURES ile birebir) ----
SC = "('public','surum_gizli')"
CAPTURES = {
    "functions": f"""SELECT n.nspname AS schema, p.proname AS name,
        pg_get_function_identity_arguments(p.oid) AS args,
        pg_get_function_result(p.oid) AS ret, p.prosecdef AS secdef,
        pg_get_functiondef(p.oid) AS fdef
        FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname IN {SC} ORDER BY 1,2,3;""",
    "triggers": f"""SELECT n.nspname AS schema, cl.relname AS table_name,
        t.tgname AS name, pg_get_triggerdef(t.oid) AS tdef
        FROM pg_trigger t JOIN pg_class cl ON cl.oid=t.tgrelid
        JOIN pg_namespace n ON n.oid=cl.relnamespace
        WHERE NOT t.tgisinternal AND n.nspname IN {SC} ORDER BY 1,2,3;""",
    "policies": f"SELECT * FROM pg_policies WHERE schemaname IN {SC} ORDER BY 1,2,3;",
    "grants_routine": f"""SELECT * FROM information_schema.role_routine_grants
        WHERE routine_schema IN {SC} ORDER BY routine_schema, routine_name, grantee;""",
    "grants_table": f"""SELECT * FROM information_schema.table_privileges
        WHERE table_schema IN {SC} ORDER BY table_schema, table_name, grantee, privilege_type;""",
    "indexes": f"SELECT * FROM pg_indexes WHERE schemaname IN {SC} ORDER BY 1,2,3;",
    "columns": f"SELECT * FROM information_schema.columns WHERE table_schema IN {SC} ORDER BY 1,2,ordinal_position;",
    "constraints": f"""SELECT n.nspname::text AS schema, c.conrelid::regclass::text AS tbl,
        c.conname AS name, c.contype, pg_get_constraintdef(c.oid) AS cdef
        FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace
        WHERE n.nspname IN {SC} ORDER BY 1,2,3;""",
    "views": f"SELECT schemaname, viewname, definition FROM pg_views WHERE schemaname IN {SC} ORDER BY 1,2;",
    "extensions": "SELECT extname, extversion FROM pg_extension ORDER BY 1;",
    "roles_grants_schema": f"""SELECT n.nspname AS schema, pg_get_userbyid(n.nspowner) AS owner
        FROM pg_namespace n WHERE n.nspname IN {SC};""",
}
for key, sql in CAPTURES.items():
    rows = qi(sql)
    f = OUT / f"{key}.json"
    f.write_text(json.dumps(rows, ensure_ascii=False, indent=1))
    meta["files"][f.name] = {"bytes": f.stat().st_size, "rows": len(rows)}
    print(f"  {key}: {len(rows)} kayıt", flush=True)

# ---- 4. manifest + sha256 ----
meta["tables"] = tab_meta
meta["duration_s"] = round(time.time() - t0, 1)
for f in sorted(OUT.glob("*.json")):
    if f.name == "manifest.json":
        continue
    h = hashlib.sha256(f.read_bytes()).hexdigest()
    meta["files"].setdefault(f.name, {})["sha256"] = h
(OUT / "manifest.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1))
print(f"\nC dökümü tamam: {len(meta['files'])} dosya, {meta['duration_s']}s → {OUT}")
