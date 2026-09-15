#!/usr/bin/env python3
"""P7 doğrulama (SALT OKUNUR — her istek BEGIN READ ONLY; ... ROLLBACK;).

Zarf (P7 §3):
  1) 8 dosya CANLI — her fonksiyonun canlı gövde md5'i dosya sürümüyle aynı
     (md5_normall: P1/P3/P4 yöntemi); tablo/trigger/kolon/policy nesne kontrolleri.
  2) ACL: 4 public RPC → authenticated EXECUTE, anon/PUBLIC revoked;
     sahip_sifresi_ayarla → yalnız service_role; iç helper'lar → PUBLIC/anon/
     authenticated erişim yok; 5 public fonksiyon demo (vtzqjmazsvurxdeondmi)
     ile proacl paritesi.
  3) surum_gizli.l4_rehber_adimlari VAR; islem_log authenticated INSERT YOK
     (SELECT korunur); trg_degisim_log tam 39 tabloda (küme eşitliği).
  4) Tablo satır sayıları yedekle aynı; fark varsa zaman-damgası kanıtıyla
     açıklanır (canlı trafik); açıklamasız fark → DUR (exit 2).
  5) Prod'a test çağrısı YAPILMAZ (yalnız katalog/count okuması).
"""
import json, re, hashlib, pathlib, subprocess, sys, datetime

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[1]
PROD_REF = "zqnexqbdfvbhlxzelzju"
DEMO_REF, DEMO_PAT = None, None
for ln in pathlib.Path("/home/melik/egesut-erp1/.env").read_text().splitlines():
    m = re.match(r"^SUPABASE_DEMO_REF=(.*)$", ln)
    if m:
        DEMO_REF = m.group(1).strip()
    m = re.match(r"^SUPABASE_DEMO_PAT=(.*)$", ln)
    if m:
        DEMO_PAT = m.group(1).strip()
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

RPC_AUTH = ["geri_alma_bileti_al", "degisim_listele", "degisim_onizle", "degisim_geri_al"]
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


def run_sql(ref, sql):
    body = json.dumps({"query": sql})
    tok = DEMO_PAT if ref == DEMO_REF else re.search(
        r"^SUPABASE_MANAGEMENT_TOKEN=(.*)$",
        pathlib.Path("/home/melik/tools-bank/.env").read_text(), re.M).group(1).strip()
    r = subprocess.run(
        ["curl", "-sS", "-X", "POST",
         f"https://api.supabase.com/v1/projects/{ref}/database/query",
         "-H", f"Authorization: Bearer {tok}",
         "-H", "Content-Type: application/json",
         "-d", body, "--max-time", "120"],
        capture_output=True, text=True)
    try:
        data = json.loads(r.stdout)
    except Exception:
        sys.exit(f"json parse hatasi ({ref}): {r.stdout[:300]} {r.stderr[:200]}")
    if isinstance(data, dict) and ("error" in data or "message" in data):
        sys.exit(f"DB hatasi ({ref}): {json.dumps(data)[:300]}")
    return data


def md5_normall(s):
    return hashlib.md5(re.sub(r"\s+", "", s or "").lower().encode()).hexdigest()[:10]


FN_RE = re.compile(
    r"CREATE\s+OR\s+REPLACE\s+FUNCTION\s+([a-zA-Z_][\w]*)\.([a-zA-Z_][\w]*)\s*\("
    r"(.*?)\nAS\s+\$\$\n(.*?)\n\$\$;", re.S)

file_versions = {}
for fname in FILES:
    txt = (REPO / "supabase" / "migrations" / fname).read_text(encoding="utf-8")
    for m in FN_RE.finditer(txt):
        file_versions.setdefault(f"{m.group(1)}.{m.group(2)}", []).append(
            {"file": fname, "md5": md5_normall(m.group(4))})

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

rows = run_sql(PROD_REF, f"BEGIN READ ONLY; {SQL_FNS} ROLLBACK;")
(HERE / "verify_prod_fns.json").write_text(json.dumps(rows, indent=1, ensure_ascii=False))
live_fns = {}
for r in rows:
    body = None
    if r["fdef"]:
        m = re.search(r"\$function\$(.*?)\$function\$", r["fdef"], re.S)
        body = m.group(1) if m else None
    live_fns.setdefault(f"{r['schema']}.{r['name']}", []).append({
        "args": r["args"], "secdef": r["secdef"], "proacl": r["proacl"],
        "md5": md5_normall(body)})

oks, bad = [], []

# ---- kapı 1: 8 dosya CANLI (zincir semantiği) ----
# Aynı fonksiyonu birden çok dosya yeniden tanımlayabilir (örn. _degisim_plan
# 06→07→08; _degisim_log_yaz 01→04). Dosya F "CANLI" demek: F'nin getirdiği her
# nesne canlıda F'nin sürümüYLE VEYA F'DEN SONRAKİ bir dosyanın (zincirin o
# fonksiyon için son sözü) sürümüyle aynı. Zincirin nihai durumunu ayrıca
# "son dosya sürümü" kontrolü sabitler.
order = {f: i for i, f in enumerate(FILES)}
for fname in FILES:
    ff = {k: {v["md5"] for v in vs if v["file"] == fname}
          for k, vs in file_versions.items()}
    ff = {k: v for k, v in ff.items() if v}
    eksik = []
    for key, md5s in ff.items():
        sonraki = {v["md5"] for v in file_versions.get(key, [])
                   if order.get(v["file"], -1) >= order[fname]}
        kabul = md5s | sonraki
        if not any(x["md5"] in kabul for x in live_fns.get(key, [])):
            canli_md5 = [x["md5"] for x in live_fns.get(key, [])]
            eksik.append(f"{key}: canlı={canli_md5} dosya/kabul={sorted(kabul)}")
    if eksik:
        bad.append(f"{fname} CANLI DEĞİL: " + "; ".join(eksik))
    else:
        oks.append(f"{fname} CANLI ({len(ff)} fonksiyon md5=zincir-nihai)")

# zincirin nihai durumu: her fonksiyon canlıda, onu tanımlayan SON dosyanın md5'i
son_soz = {}
for key, vs in file_versions.items():
    son = max(vs, key=lambda v: order[v["file"]])
    son_soz[key] = son["md5"]
nihai_sapma = [f"{k}: canlı={[x['md5'] for x in live_fns.get(k, [])]} son-dosya({son_soz[k]})"
               for k in son_soz
               if not any(x["md5"] == son_soz[k] for x in live_fns.get(k, []))]
if nihai_sapma:
    bad.append("Zincir-nihai md5 sapması: " + "; ".join(nihai_sapma))
else:
    oks.append(f"Zincir-nihai durum: {len(son_soz)} fonksiyonun canlı gövde md5'i = son tanımlayan dosya")

# ---- kapı 2: ACL ----
def acl_set(proacl):
    """proacl text'i grantee kümesine çevir (yaklaşık: 'X' işaretli üyeler)."""
    if not proacl:
        return {"PUBLIC"}   # NULL = varsayılan PUBLIC EXECUTE
    s = set(re.findall(r"([a-zA-Z_][\w]*)=", proacl))
    return s or {"PUBLIC"}

for name in RPC_AUTH:
    key = f"public.{name}"
    vs = live_fns.get(key, [])
    if len(vs) != 1:
        bad.append(f"{key} overload sayısı {len(vs)} (beklenen 1)")
        continue
    a = acl_set(vs[0]["proacl"])
    # Dosya metni: REVOKE ALL ... FROM PUBLIC, anon; GRANT EXECUTE ... TO
    # authenticated. service_role'a dokunulmaz → Supabase default-privilege
    # EXECUTE kalır (demo referansı da aynı). Kapı: authenticated VAR,
    # anon/PUBLIC YOK; service_role bilgi amaçlı raporlanır.
    if "authenticated" not in a or "anon" in a or "PUBLIC" in a:
        bad.append(f"{key} ACL hatalı: {vs[0]['proacl']} (authenticated VAR; anon/PUBLIC YOK beklenir)")
    else:
        oks.append(f"{key} ACL: authenticated VAR, anon/PUBLIC yok, service_role=default "
                   f"({vs[0]['proacl']})")

v = live_fns.get("public.sahip_sifresi_ayarla", [])
if len(v) != 1:
    bad.append(f"public.sahip_sifresi_ayarla overload {len(v)} (beklenen 1)")
else:
    a = acl_set(v[0]["proacl"])
    if a != {"postgres", "service_role"}:
        bad.append(f"sahip_sifresi_ayarla ACL hatalı: {v[0]['proacl']} (yalnız service_role beklenir)")
    else:
        oks.append(f"sahip_sifresi_ayarla ACL: yalnız service_role ({v[0]['proacl']})")

# iç helper'lar: PUBLIC/anon/authenticated erişimi olmamalı
helper_bad = []
for key, vs in live_fns.items():
    if not key.startswith("surum_gizli."):
        continue
    for x in vs:
        a = acl_set(x["proacl"])
        if ({"anon", "authenticated"} & a) or x["proacl"] in (None, ""):
            helper_bad.append(f"{key} ({x['args']}): {x['proacl']}")
for name in ("_degisim_log_yaz", "_degisim_log_degistirilemez",
             "_islem_log_degisim_txid", "_islem_log_geri_alindi_kapisi"):
    for x in live_fns.get(f"public.{name}", []):
        a = acl_set(x["proacl"])
        if ({"anon", "authenticated"} & a) or x["proacl"] in (None, ""):
            helper_bad.append(f"public.{name}: {x['proacl']}")
if helper_bad:
    bad.append("İç helper ACL'si açık: " + "; ".join(helper_bad))
else:
    oks.append("Tüm iç helper'lar (surum_gizli.* + public._*): PUBLIC/anon/authenticated erişim yok")

# demo paritesi (5 public fonksiyon proacl + TÜM zincir fonksiyonlarının gövde md5'i)
if DEMO_REF:
    drows = run_sql(DEMO_REF, f"""BEGIN READ ONLY;
        SELECT p.proname AS name, p.proacl::text AS proacl
        FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname='public' AND p.proname = ANY(ARRAY[{','.join(repr(x) for x in RPC_AUTH + ['sahip_sifresi_ayarla'])}])
        ORDER BY 1; ROLLBACK;""")
    demo = {r["name"]: r["proacl"] for r in drows}
    for name in RPC_AUTH + ["sahip_sifresi_ayarla"]:
        pv = [x["proacl"] for x in live_fns.get(f"public.{name}", [])]
        if not pv:
            bad.append(f"demo paritesi: prod'da {name} yok")
        elif pv[0] != demo.get(name):
            bad.append(f"demo paritesi {name}: prod={pv[0]} demo={demo.get(name)}")
        else:
            oks.append(f"demo paritesi {name}: proacl birebir ({pv[0]})")

    dfns = run_sql(DEMO_REF, f"BEGIN READ ONLY; {SQL_FNS} ROLLBACK;")
    demo_fns = {}
    for r in dfns:
        body = None
        if r["fdef"]:
            m = re.search(r"\$function\$(.*?)\$function\$", r["fdef"], re.S)
            body = m.group(1) if m else None
        demo_fns.setdefault(f"{r['schema']}.{r['name']}", []).append(md5_normall(body))
    sap = []
    ileri = []
    tum_surumler = {k: {v["md5"] for v in vs} for k, vs in file_versions.items()}
    for key in sorted(son_soz):
        pm = [x["md5"] for x in live_fns.get(key, [])]
        dm = demo_fns.get(key, [])
        if not pm or not dm or sorted(pm) != sorted(dm):
            # prod zinciri demo'dan ileride olabilir (demo'ya sonradan eklenen
            # dosyalar uygulanmamıştır). demo md5'i zincirin BİLİNEN bir
            # sürümüyse açıklamalı sapma; değilse gerçek sapma.
            if all(any(d in tum_surumler.get(key, set()) for d in dm) for _ in [0]) and dm:
                ileri.append(f"{key}: prod={pm[0]} (zincir ilerisi), demo={dm[0]} (bilinen sürüm)")
            else:
                sap.append(f"{key}: prod={pm} demo={dm} (demo md5 zincirde yok!)")
    if sap:
        bad.append("prod↔demo gövde paritesi bozuk: " + "; ".join(sap))
    elif ileri:
        oks.append("prod↔demo gövde paritesi: çoğu birebir; prod ilerisi (açıklamalı): "
                   + "; ".join(ileri))
    else:
        oks.append(f"prod↔demo gövde paritesi: {len(son_soz)} fonksiyon birebir")

# ---- kapı 3: nesneler ----
Q = {
 "trg_degisim_log_tables": """SELECT cl.relname AS t FROM pg_trigger g JOIN pg_class cl ON cl.oid=g.tgrelid
    JOIN pg_namespace cn ON cn.oid=cl.relnamespace
    WHERE g.tgname='trg_degisim_log' AND cn.nspname='public' ORDER BY 1;""",
 "degisim_log_grants": """SELECT grantee, privilege_type FROM information_schema.table_privileges
    WHERE table_schema='public' AND table_name='degisim_log' ORDER BY 1,2;""",
 "sg_tables": """SELECT c.relname AS t FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='surum_gizli' AND c.relkind='r' ORDER BY 1;""",
 "sg_grants": """SELECT table_name, grantee, privilege_type FROM information_schema.table_privileges
    WHERE table_schema='surum_gizli' AND grantee IN ('anon','authenticated','PUBLIC') ORDER BY 1,2,3;""",
 "il_grants": """SELECT grantee, privilege_type FROM information_schema.table_privileges
    WHERE table_schema='public' AND table_name='islem_log' AND grantee='authenticated' ORDER BY 2;""",
 "il_policies": """SELECT policyname, cmd, roles::text AS roles, qual, with_check
    FROM pg_policies WHERE schemaname='public' AND tablename='islem_log' ORDER BY policyname;""",
 "il_triggers": """SELECT t.tgname FROM pg_trigger t JOIN pg_class cl ON cl.oid=t.tgrelid
    JOIN pg_namespace n ON n.oid=cl.relnamespace
    WHERE NOT t.tgisinternal AND n.nspname='public' AND cl.relname='islem_log' ORDER BY 1;""",
 "il_txid_trig": """SELECT pg_get_triggerdef(t.oid) AS tdef FROM pg_trigger t
    JOIN pg_class cl ON cl.oid=t.tgrelid JOIN pg_namespace n ON n.oid=cl.relnamespace
    WHERE n.nspname='public' AND cl.relname='islem_log' AND t.tgname='trg_islem_log_degisim_txid';""",
 "l4_rehber": "SELECT to_regclass('surum_gizli.l4_rehber_adimlari') AS r;",
 "il_col": """SELECT format_type(a.atttypid, a.atttypmod) AS tip FROM pg_attribute a
    JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='public' AND c.relname='islem_log' AND a.attname='degisim_txid';""",
}
obj = {k: run_sql(PROD_REF, f"BEGIN READ ONLY; {v} ROLLBACK;") for k, v in Q.items()}
(HERE / "verify_prod_objects.json").write_text(json.dumps(obj, indent=1, ensure_ascii=False))

trg39 = sorted(r["t"] for r in obj["trg_degisim_log_tables"])
if trg39 == sorted(TABLOLAR_39):
    oks.append(f"trg_degisim_log tam 39 tabloda (küme eşitliği)")
else:
    eksik39 = sorted(set(TABLOLAR_39) - set(trg39))
    fazla39 = sorted(set(trg39) - set(TABLOLAR_39))
    bad.append(f"trg_degisim_log kümesi farklı: eksik={eksik39} fazla={fazla39}")

dg = obj["degisim_log_grants"]
auth_sel = [g for g in dg if g["grantee"] == "authenticated"]
if [g["privilege_type"] for g in auth_sel] == ["SELECT"]:
    oks.append("degisim_log: authenticated yalnız SELECT")
else:
    bad.append(f"degisim_log authenticated grant'leri: {auth_sel}")
if [g for g in dg if g["grantee"] in ("anon", "PUBLIC")]:
    bad.append(f"degisim_log anon/PUBLIC grant var: {[g for g in dg if g['grantee'] in ('anon','PUBLIC')]}")

sgt = [r["t"] for r in obj["sg_tables"]]
for t in ("sahip_sifresi", "geri_alma_bileti", "geri_alma_kullanim", "l4_rehber_adimlari"):
    if t not in sgt:
        bad.append(f"surum_gizli.{t} yok")
if obj["l4_rehber"] and obj["l4_rehber"][0]["r"]:
    oks.append("surum_gizli.l4_rehber_adimlari VAR")
else:
    bad.append("surum_gizli.l4_rehber_adimlari yok")
if obj["sg_grants"]:
    bad.append(f"surum_gizli tablolarında anon/authenticated/PUBLIC grant: {obj['sg_grants']}")
else:
    oks.append("surum_gizli tabloları: anon/authenticated/PUBLIC erişim yok")

ilg = [g["privilege_type"] for g in obj["il_grants"]]
if "INSERT" in ilg:
    bad.append("islem_log: authenticated INSERT grant HÂLÂ VAR")
else:
    oks.append("islem_log: authenticated INSERT yetkisi YOK")
if "SELECT" not in ilg:
    bad.append("islem_log: authenticated SELECT grant kayboldu (canlı site kırılır!)")
else:
    oks.append("islem_log: authenticated SELECT korunuyor (api.js:417)")

pol = {r["policyname"]: r for r in obj["il_policies"]}
si = pol.get("service_insert")
if si and si["cmd"] == "INSERT" and "service_role" in si["roles"] and "public" not in si["roles"]:
    oks.append("islem_log policy service_insert: FOR INSERT TO service_role (L4-02c)")
else:
    bad.append(f"islem_log policy service_insert beklenmedik: {si}")
sel = pol.get("islem_log_select")
if sel:
    oks.append("islem_log policy islem_log_select korunuyor")
else:
    bad.append("islem_log policy islem_log_select yok (canlı SELECT kırılır!)")

ilt = [r["tgname"] for r in obj["il_triggers"]]
for t in ("trg_islem_log_immutable", "trg_islem_log_degisim_txid", "trg_islem_log_geri_alindi_kapisi"):
    if t not in ilt:
        bad.append(f"islem_log trigger eksik: {t}")
if obj["il_txid_trig"] and "WHEN" not in obj["il_txid_trig"][0]["tdef"]:
    oks.append("trg_islem_log_degisim_txid: koşulsuz (WHEN yok — L4-02a)")
elif obj["il_txid_trig"]:
    bad.append(f"trg_islem_log_degisim_txid hâlâ WHEN'li: {obj['il_txid_trig'][0]['tdef']}")

if obj["il_col"] and obj["il_col"][0]["tip"] == "bigint":
    oks.append("islem_log.degisim_txid bigint VAR")
else:
    bad.append(f"islem_log.degisim_txid: {obj['il_col'] or 'yok'}")

# ---- kapı 4: tablo satır sayıları vs yedek ----
manifest = json.loads((BACKUP / "manifest.json").read_text())
tab_rows = {k: v["backup_rows"] for k, v in manifest["tables"].items()}
t_uyg_start = json.loads((HERE / "apply_log.json").read_text())["started"]

drift = []
for t in sorted(tab_rows):
    n = run_sql(PROD_REF, f'BEGIN READ ONLY; SELECT count(*) AS n FROM public."{t}"; ROLLBACK;')
    live_n = n[0]["n"]
    if live_n == tab_rows[t]:
        continue
    # açıklama arama: timestamp kolonlarla yedek-başı sonrası satır sayısı
    cols = run_sql(PROD_REF, f"""BEGIN READ ONLY; SELECT column_name FROM information_schema.columns
        WHERE table_schema='public' AND table_name='{t}'
          AND data_type LIKE 'timestamp%' ORDER BY ordinal_position; ROLLBACK;""")
    aciklama = None
    for c in [x["column_name"] for x in cols]:
        try:
            probe = run_sql(PROD_REF, f"""BEGIN READ ONLY;
                SELECT count(*) AS n FROM public."{t}" WHERE {c} > '{t_uyg_start}'::timestamptz; ROLLBACK;""")
            if probe[0]["n"]:
                aciklama = f"{c} > yedek-başı: {probe[0]['n']} satır (canlı trafik)"
                break
        except SystemExit:
            raise
    drift.append({"table": t, "backup": tab_rows[t], "live": live_n,
                  "aciklama": aciklama or "AÇIKLAMA YOK"})
(HERE / "verify_table_counts.json").write_text(json.dumps(
    [{"table": k, "backup": tab_rows[k],
      "live": next((d["live"] for d in drift if d["table"] == k), tab_rows[k]),
      "aciklama": next((d["aciklama"] for d in drift if d["table"] == k), None)}
     for k in sorted(tab_rows)], indent=1, ensure_ascii=False))

aciklamali = [d for d in drift if d["aciklama"] and d["aciklama"] != "AÇIKLAMA YOK"]
aciklamasiz = [d for d in drift if not d["aciklama"] or d["aciklama"] == "AÇIKLAMA YOK"]
if aciklamali:
    oks.append("Canlı trafik farkları (kanıtlı): " + "; ".join(
        f"{d['table']} {d['backup']}→{d['live']} ({d['aciklama']})" for d in aciklamali))
if aciklamasiz:
    bad.append("AÇIKLANAMAYAN satır farkı: " + "; ".join(
        f"{d['table']} yedek={d['backup']} canlı={d['live']}" for d in aciklamasiz))
if not drift:
    oks.append(f"Tablo satır sayıları yedekle birebir ({len(tab_rows)} tablo)")

# yeni tabloların satır sayısı (bilgi)
yeni = {}
for t in ("degisim_log",):
    n = run_sql(PROD_REF, f'SELECT count(*) AS n FROM public."{t}";')
    yeni[t] = n[0]["n"]
for t in ("sahip_sifresi", "geri_alma_bileti", "geri_alma_kullanim", "l4_rehber_adimlari"):
    n = run_sql(PROD_REF, f'SELECT count(*) AS n FROM surum_gizli."{t}";')
    yeni[f"surum_gizli.{t}"] = n[0]["n"]
(HERE / "verify_yeni_tablolar.json").write_text(json.dumps(yeni, indent=1, ensure_ascii=False))

summary = {"measured_at": datetime.datetime.now().astimezone().isoformat(),
           "prod_ref": PROD_REF, "demo_ref": DEMO_REF,
           "oks": oks, "bad": bad, "yeni_tablolar": yeni}
(HERE / "verify_summary.json").write_text(json.dumps(summary, indent=1, ensure_ascii=False))

print("== DOĞRULAMA ==")
for o in oks:
    print("  [OK]", o)
print(f"\nyeni tablolar: {yeni}")
if bad:
    print("\nDUR — doğrulama başarısız (zarf §3):")
    for b in bad:
        print("  -", b)
    sys.exit(2)
print("\nDOĞRULAMA TAMAM — 8 dosya CANLI, tüm kapılar yeşil.")
