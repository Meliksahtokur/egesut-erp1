#!/usr/bin/env python3
"""P4 — PROD mantıksal yedek (Mgmt API, yazma YOK). P2 backup_prod.py uyarlaması.

Zarf (P4 §1): P2'nin yedek betiği, OUT değiştirilmiş:
  /home/melik/tmp/agents/prod-yedek-2026-09-15-p4/   (yeni klasör; mevcut
  prod-yedek-2026-09-15/ ve diğer yedekler salt okunur — dokunulmaz).

Doğrulama (zarf): satır sayıları canlı count(*) ile eşleşmeli; eşleşmezse DUR.
  Kapı A: tablo başına backup_rows == yedek-başı count(*)
  Kapı B: TÜM tablolar bittikten sonra ikinci count turu == backup_rows
          (yedek penceresinde yazma trafiği olup olmadığını söyler)
P1/P2 referans sayıları (9 tablo) bilgilendirme amaçlı raporlanır — DUR kapısı
değil (zarfın ölçütü canlı count ile eşleşme; canlı sistemde satır değişebilir).
"""
import json, subprocess, pathlib, re, sys, time, hashlib, datetime

HERE = pathlib.Path(__file__).resolve().parent
PROD_REF = "zqnexqbdfvbhlxzelzju"
OUT = pathlib.Path("/home/melik/tmp/agents/prod-yedek-2026-09-15-p4")
OUT.mkdir(parents=True, exist_ok=True)

TOK = re.search(r"^SUPABASE_MANAGEMENT_TOKEN=(.*)$",
                pathlib.Path("/home/melik/tools-bank/.env").read_text(), re.M).group(1).strip()

# P1/P2 referansı (bilgilendirme; DUR kapısı DEĞİL)
EXPECTED = {
    "hayvanlar": 166, "tohumlama": 282, "dogum": 72, "gorev_log": 3084,
    "cases": 113, "drug_products": 33, "stok": 49, "islem_log": 4253,
    "vaccines": 12,
}


def q(sql, max_time=300):
    """Tek Mgmt API isteği. Dönüş: (parsed, raw_bytes, error_or_None)."""
    body = json.dumps({"query": sql})
    r = subprocess.run(
        ["curl", "-sS", "-X", "POST",
         f"https://api.supabase.com/v1/projects/{PROD_REF}/database/query",
         "-H", f"Authorization: Bearer {TOK}", "-H", "Content-Type: application/json",
         "-d", body, "--max-time", str(max_time)],
        capture_output=True, text=True)
    try:
        data = json.loads(r.stdout)
    except Exception:
        return None, r.stdout, f"json parse: {r.stdout[:200]} {r.stderr[:200]}"
    if isinstance(data, dict) and ("error" in data or "message" in data):
        return None, r.stdout, json.dumps(data)[:300]
    return data, r.stdout, None


def qi(sql):
    data, raw, err = q(sql)
    if err:
        sys.exit(f"METADATA HATASI: {err}\nSQL: {sql[:200]}")
    return data


def qid(x):
    return '"' + x.replace('"', '""') + '"'


t0 = time.time()
meta = {"started": datetime.datetime.now().astimezone().isoformat(), "prod_ref": PROD_REF,
        "purpose": "P4 - 20260910000002 oncesi yedek",
        "method": "Mgmt API /database/query, salt okunur SELECT; her tablo parçalı json_agg",
        "files": {}}

# ---- 1. public tabloları + yedek-başı count (KAPI A referansı) ----
tables = qi("SELECT c.relname AS name, c.relrowsecurity AS rls "
            "FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace "
            "WHERE n.nspname='public' AND c.relkind IN ('r','p') ORDER BY 1;")
tab_meta = {}
for t in tables:
    n = qi(f"SELECT count(*) AS n FROM public.{qid(t['name'])};")
    tab_meta[t["name"]] = {"rls": t["rls"], "rows": n[0]["n"]}
print(f"public tablolar: {len(tab_meta)}", flush=True)

# ---- 2. tablo verileri (parçalı json_agg) ----
for name, m in sorted(tab_meta.items()):
    tf0 = time.time()
    chunk, offset, rows, chunks = 500, 0, [], 0
    tq = f"public.{qid(name)}"
    while True:
        sql = (f"SELECT COALESCE(json_agg(x),'[]'::json) AS batch FROM "
               f"(SELECT * FROM {tq} LIMIT {chunk} OFFSET {offset}) x;")
        data, raw, err = q(sql)
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
    if m["backup_rows"] != m["rows"]:
        sys.exit(f"KAPI A DUR: {name} backup_rows={m['backup_rows']} != count={m['rows']}")
    print(f"  {name}: {len(rows)} satır ({chunks} parça, {f.stat().st_size} B, "
          f"{time.time()-tf0:.1f}s)", flush=True)

# ---- 3. şema tanımları ----
SC = "('public','surum_gizli')"
CAPTURES = {
    "functions": f"""SELECT n.nspname AS schema, p.proname AS name,
        pg_get_function_identity_arguments(p.oid) AS args,
        pg_get_function_result(p.oid) AS ret, p.prosecdef AS secdef,
        p.proacl::text AS proacl,
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

# ---- 4. KAPI B: yedek-sonu ikinci count turu ----
post_bad = []
for name, m in sorted(tab_meta.items()):
    n = qi(f"SELECT count(*) AS n FROM public.{qid(name)};")
    m["post_count"] = n[0]["n"]
    if m["post_count"] != m["backup_rows"]:
        post_bad.append(f"{name}: post_count={m['post_count']} != backup_rows={m['backup_rows']}")
        print(f"  [FARK] {name}: post={m['post_count']} yedek={m['backup_rows']}")
if post_bad:
    print("\nKAPI B DUR — yedek penceresinde yazma trafiği görüldü (zarf gereği sorulacak):")
    for b in post_bad:
        print("  -", b)

# ---- 5. P1/P2 referansı (bilgilendirme) + sha256 + manifest ----
verify = {}
for t, exp in EXPECTED.items():
    got = tab_meta.get(t, {}).get("backup_rows")
    verify[t] = {"expected_P1": exp, "backup": got,
                 "note": "bilgilendirme; DUR kapısı canlı count eşleşmesidir"}
meta["verify_vs_P1_reference"] = verify
meta["gate_A"] = "OK - her tablo backup_rows == yedek-basi count(*)"
meta["gate_B"] = ("OK - yedek-sonu count turu backup_rows ile birebir" if not post_bad
                  else {"FAIL": post_bad})
meta["tables"] = tab_meta
meta["duration_s"] = round(time.time() - t0, 1)

for f in sorted(OUT.glob("*.json")):
    if f.name == "manifest.json":
        continue
    h = hashlib.sha256(f.read_bytes()).hexdigest()
    meta["files"].setdefault(f.name, {})["sha256"] = h

(OUT / "manifest.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1))
total_b = sum(v["bytes"] for v in meta["files"].values())
print(f"\nYedek: {len(meta['files'])} dosya, {total_b} bayt, {meta['duration_s']}s")
if post_bad:
    sys.exit(2)
print("KAPI A + KAPI B TAMAM — yedek doğrulandı (canlı count ile birebir).")
