#!/usr/bin/env python3
"""P7 ön kontrol (SALT OKUNUR — her istek BEGIN READ ONLY; ... ROLLBACK;).

Zarf P7 §0:
  a) 8 dosyanın prod durumu: hepsi EKSİK/KISMİ olmalı; CANLI varsa DUR (exit 2).
  b) Ön koşullar: 39 hedef tablo + PK (identity/generated YOK), islem_log,
     extensions.crypt/gen_salt (pgcrypto), surum_gizli beklenen-yok durumu.
  c) Canlı site uyumu verisi: islem_log authenticated INSERT grant durumu
     (L4-03 REVOKE öncesi kayıt), mevcut islem_log policy/trigger listesi.
md5 yöntemi: P1/P3 md5_normall (boşluk-sil + küçük-harf, ilk 10 hex).
CANLI tanımı: dosyanın anahtar nesnelerinin TAMAMI canlıda var ve gövde md5
  dosya sürümüyle aynı. Tek nesne bile eksikse en fazla KISMİ.
Token hiçbir çıktıya yazılmaz.
"""
import json, re, hashlib, pathlib, subprocess, sys, datetime

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[1]
PROD_REF = "zqnexqbdfvbhlxzelzju"
TOK = re.search(r"^SUPABASE_MANAGEMENT_TOKEN=(.*)$",
                pathlib.Path("/home/melik/tools-bank/.env").read_text(), re.M).group(1).strip()

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

TABLOLAR_39 = ['cases','diseases','dogum','drug_administrations',
    'drug_classes','drug_products','drugs','gorev_log','grup_padok_eslem',
    'hastalik_log','hayvan_override','hayvanlar','hekimler','irk_esik',
    'kizginlik_log','padoklar','pedigree_meta','pedigree_nodes',
    'pedigree_parentage','protokol_ayar','protokol_dismiss','protokol_instance',
    'sablon_hastalik_eslem','semen_catalog','stok','stok_hareket',
    'stok_kategorileri','tedavi','tedavi_sablonu','tedavi_sablonu_kalem',
    'tohumlama','treatment_day_uygulamalar','treatment_days','uygulama_log',
    'vaccination_log','vaccination_schedule','vaccine_diseases',
    'vaccine_protocol_steps','vaccines']


def run_sql(sql_wrapped):
    body = json.dumps({"query": sql_wrapped})
    r = subprocess.run(
        ["curl", "-sS", "-X", "POST",
         f"https://api.supabase.com/v1/projects/{PROD_REF}/database/query",
         "-H", f"Authorization: Bearer {TOK}", "-H", "Content-Type: application/json",
         "-d", body, "--max-time", "120"],
        capture_output=True, text=True)
    try:
        data = json.loads(r.stdout)
    except Exception:
        sys.exit(f"json parse hatasi: {r.stdout[:300]} {r.stderr[:200]}")
    if isinstance(data, dict) and ("error" in data or "message" in data):
        sys.exit(f"DB hatasi: {json.dumps(data)[:300]}")
    return data


def md5_normall(s):
    return hashlib.md5(re.sub(r"\s+", "", s or "").lower().encode()).hexdigest()[:10]


# ---- 1) dosya tarafı: fonksiyon gövdelerini topla (dosya sırasına göre) ----
FN_RE = re.compile(
    r"CREATE\s+OR\s+REPLACE\s+FUNCTION\s+([a-zA-Z_][\w]*)\.([a-zA-Z_][\w]*)\s*\("
    r"(.*?)\nAS\s+\$\$\n(.*?)\n\$\$;", re.S)

file_versions = {}   # "schema.name" -> list of {file, md5} (uygulama sırası)
for fname in FILES:
    txt = (REPO / "supabase" / "migrations" / fname).read_text(encoding="utf-8")
    for m in FN_RE.finditer(txt):
        key = f"{m.group(1)}.{m.group(2)}"
        file_versions.setdefault(key, []).append(
            {"file": fname, "md5": md5_normall(m.group(4))})

# ---- 2) canlı taraf: fonksiyonlar ----
FN_NAMES = sorted(file_versions)
SQL_FNS = f"""SELECT n.nspname AS schema, p.proname AS name,
       pg_get_function_identity_arguments(p.oid) AS args,
       pg_get_function_result(p.oid) AS ret,
       p.prosecdef AS secdef, p.proacl::text AS proacl,
       pg_get_functiondef(p.oid) AS fdef
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public','surum_gizli')
  AND p.proname = ANY(ARRAY[{','.join(repr(n.split('.',1)[1]) for n in FN_NAMES)}])
ORDER BY n.nspname, p.proname, 3;"""
rows = run_sql(f"BEGIN READ ONLY; {SQL_FNS} ROLLBACK;")
(HERE / "precheck_prod_fns.json").write_text(json.dumps(rows, indent=1, ensure_ascii=False))

live_fns = {}   # "schema.name" -> list of {args, md5, secdef, proacl}
for r in rows:
    body = None
    if r["fdef"]:
        m = re.search(r"\$function\$(.*?)\$function\$", r["fdef"], re.S)
        body = m.group(1) if m else None
    live_fns.setdefault(f"{r['schema']}.{r['name']}", []).append({
        "args": r["args"], "ret": r["ret"], "secdef": r["secdef"], "proacl": r["proacl"],
        "md5": md5_normall(body)})

# ---- 3) canlı taraf: nesneler ----
Q = {
 "tables_pub_degisim_log": "SELECT to_regclass('public.degisim_log') IS NOT NULL AS var;",
 "surum_gizli_var": "SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname='surum_gizli') AS var;",
 "surum_gizli_tables": """SELECT c.relname AS t FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='surum_gizli' AND c.relkind='r' ORDER BY 1;""",
 "trg_degisim_log_tables": """SELECT cl.relname AS t FROM pg_trigger g JOIN pg_class cl ON cl.oid=g.tgrelid
    JOIN pg_namespace cn ON cn.oid=cl.relnamespace
    WHERE g.tgname='trg_degisim_log' AND cn.nspname='public' ORDER BY 1;""",
 "islem_log_degisim_txid": """SELECT a.attname FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid
    JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname='islem_log' AND a.attname='degisim_txid';""",
 "trg_islem_log": """SELECT t.tgname, pg_get_triggerdef(t.oid) AS tdef FROM pg_trigger t
    JOIN pg_class cl ON cl.oid=t.tgrelid JOIN pg_namespace n ON n.oid=cl.relnamespace
    WHERE NOT t.tgisinternal AND n.nspname='public' AND cl.relname='islem_log' ORDER BY 1;""",
 "islem_log_grants": """SELECT grantee, privilege_type FROM information_schema.table_privileges
    WHERE table_schema='public' AND table_name='islem_log' ORDER BY grantee, privilege_type;""",
 "islem_log_policies": "SELECT * FROM pg_policies WHERE schemaname='public' AND tablename='islem_log';",
 "pgcrypto_fns": """SELECT to_regprocedure('extensions.crypt(text,text)') IS NOT NULL AS crypt_var,
    to_regprocedure('extensions.gen_salt(text,int)') IS NOT NULL AS gen_salt_var;""",
 "degisim_log_grants": """SELECT grantee, privilege_type FROM information_schema.table_privileges
    WHERE table_schema='public' AND table_name='degisim_log' ORDER BY grantee, privilege_type;""",
}
live_obj = {k: run_sql(f"BEGIN READ ONLY; {v} ROLLBACK;") for k, v in Q.items()}

# 39 tablo: varlık + PK + identity kontrolü (tek sorgu)
tab_list = ",".join(repr(t) for t in TABLOLAR_39)
rows39 = run_sql(f"""BEGIN READ ONLY;
WITH hedef AS (SELECT unnest(ARRAY[{tab_list}]) AS t),
k AS (SELECT c.conrelid, count(*) AS n FROM pg_constraint c WHERE c.contype='p' GROUP BY 1)
SELECT h.t,
       (to_regclass(format('public.%I', h.t)) IS NOT NULL) AS tablo_var,
       COALESCE(k.n, 0) AS pk_sayisi,
       EXISTS(SELECT 1 FROM pg_constraint c2
                CROSS JOIN LATERAL unnest(c2.conkey) AS u(attnum)
                JOIN pg_attribute a ON a.attrelid=c2.conrelid AND a.attnum=u.attnum
               WHERE c2.conrelid = format('public.%I', h.t)::regclass
                 AND c2.contype='p' AND (a.attidentity <> '' OR a.attgenerated <> '')) AS identity_pk
FROM hedef h LEFT JOIN k ON k.conrelid = format('public.%I', h.t)::regclass
ORDER BY 1; ROLLBACK;""")
live_obj["tables39"] = rows39

(HERE / "precheck_prod_objects.json").write_text(json.dumps(live_obj, indent=1, ensure_ascii=False))

# ---- 4) dosya-başı durum sınıflaması ----
def fn_matches(key, md5s):
    """True: canlı o fonksiyonun dosya sürümlerinden biri (overload dahil)."""
    for v in live_fns.get(key, []):
        if v["md5"] in md5s:
            return True
    return False

def file_functions(fname):
    out = {}
    for key, versions in file_versions.items():
        md5s = [v["md5"] for v in versions if v["file"] == fname]
        if md5s:
            out[key] = set(md5s)
    return out

L = live_obj
degisim_log_var = L["tables_pub_degisim_log"][0]["var"]
surum_var = L["surum_gizli_var"][0]["var"]
sg_tables = [r["t"] for r in L["surum_gizli_tables"]]
trg39 = [r["t"] for r in L["trg_degisim_log_tables"]]
col_txid = len(L["islem_log_degisim_txid"]) > 0
trg_il = [r["tgname"] for r in L["trg_islem_log"]]

def status(fname):
    """(durum, [eksik listesi]) — CANLI yalnız dosyanın anahtar nesneleri tamamsa."""
    eksik = []
    ff = file_functions(fname)
    # fonksiyon tarafı
    fn_ok, fn_top = 0, 0
    for key, md5s in ff.items():
        fn_top += 1
        if fn_matches(key, md5s):
            fn_ok += 1
        else:
            eksik.append(f"fn {key} (dosya sürümü yok/different)")
    return fn_ok, fn_top, eksik

# dosya anahtar nesne tabloları (fonksiyon dışı)
def objects_for(fname):
    o = []
    if fname.startswith("20260913000001"):
        o += ["degisim_log tablosu"] if not degisim_log_var else []
        if degisim_log_var:
            o += [] if len(trg39) == 39 else [f"trg_degisim_log {len(trg39)}/39"]
    if fname.startswith("20260913000002"):
        if not surum_var:
            o.append("surum_gizli şeması")
        else:
            for t in ("sahip_sifresi", "geri_alma_bileti", "geri_alma_kullanim"):
                if t not in sg_tables:
                    o.append(f"surum_gizli.{t}")
    if fname.startswith("20260913000003"):
        pass  # fonksiyon + grant tarafı fn_matches ile
    if fname.startswith("20260914000001"):
        if not col_txid:
            o.append("islem_log.degisim_txid")
        if "trg_islem_log_degisim_txid" not in trg_il:
            o.append("trg_islem_log_degisim_txid")
    if fname.startswith("20260914000003"):
        if "l4_rehber_adimlari" not in sg_tables:
            o.append("surum_gizli.l4_rehber_adimlari")
    return o

summary = {"measured_at": datetime.datetime.now().astimezone().isoformat(),
           "prod_ref": PROD_REF, "wrap": "BEGIN READ ONLY; ... ROLLBACK;",
           "files": {}}
CANLI_HATALI = []
for fname in FILES:
    fn_ok, fn_top, eksik = status(fname)
    obj_eksik = objects_for(fname)
    # grant kontrolü (03: service_role EXECUTE)
    if fname.startswith("20260913000003"):
        v = live_fns.get("public.sahip_sifresi_ayarla", [])
        if not any("service_role" in (x["proacl"] or "") for x in v):
            obj_eksik.append("sahip_sifresi_ayarla service_role EXECUTE grant")
    tam = (fn_ok == fn_top) and not obj_eksik and fn_top > 0
    hicbiri = (fn_ok == 0 and not obj_eksik)   # tek fn bile canlı değil + nesne eksik yok
    durum = "CANLI" if tam else ("EKSİK" if hicbiri else "KISMİ")
    summary["files"][fname] = {"fn_toplam": fn_top, "fn_canli": fn_ok,
                               "nesne_eksik": obj_eksik, "durum": durum}
    print(f"{fname}: {durum} (fn {fn_ok}/{fn_top}; nesne eksik: {obj_eksik or 'yok'})")
    if durum == "CANLI":
        CANLI_HATALI.append(fname)

# ---- 5) ön koşul kapıları ----
bad = []
if CANLI_HATALI:
    bad.append("CANLI çıkan dosyalar: " + ", ".join(CANLI_HATALI))

bad39 = [r["t"] for r in rows39 if not r["tablo_var"]]
pk39 = [r["t"] for r in rows39 if r["tablo_var"] and r["pk_sayisi"] == 0]
id39 = [r["t"] for r in rows39 if r["identity_pk"]]
if bad39:
    bad.append(f"ÖN KOŞUL: prod'da olmayan hedef tablolar: {bad39}")
if pk39:
    bad.append(f"ÖN KOŞUL: PK'sız hedef tablolar: {pk39}")
if id39:
    bad.append(f"ÖN KOŞUL: identity/generated PK'lı tablolar: {id39}")
pc = L["pgcrypto_fns"][0]
if not (pc["crypt_var"] and pc["gen_salt_var"]):
    bad.append(f"ÖN KOŞUL: extensions.crypt/gen_salt yok: {pc}")

il_ins = [g for g in L["islem_log_grants"] if g["grantee"] == "authenticated" and g["privilege_type"] == "INSERT"]
summary["islem_log_authenticated_INSERT_grant"] = bool(il_ins)
summary["objects_snapshot"] = {
    "degisim_log_var": degisim_log_var, "surum_gizli_var": surum_var,
    "surum_gizli_tables": sg_tables, "trg_degisim_log_count": len(trg39),
    "islem_log_triggers": trg_il, "pgcrypto": pc,
}
summary["prereq_fail"] = bad

(HERE / "precheck_summary.json").write_text(json.dumps(summary, indent=1, ensure_ascii=False))
print(f"\nislem_log authenticated INSERT grant (REVOKE öncesi): {'VAR' if il_ins else 'YOK'}")
print(f"trg_degisim_log: {len(trg39)}/39 tablo")
if bad:
    print("\nDUR — zarf §0 gereği:")
    for b in bad:
        print("  -", b)
    sys.exit(2)
print("\nÖN KONTROL TAMAM — 8 dosya EKSİK/KISMİ, ön koşullar sağlı.")
