#!/usr/bin/env python3
"""P2 Adım A — uygulama sonrası veri doğrulaması (PROD + DEMO, salt-okunur).

Her istek BEGIN READ ONLY; SELECT...; ROLLBACK; zarfında (pedigree_integrity_report
dahil — yazma girişimi READ ONLY'de hata verir ve geri alınır). Token çıktıya yazılmaz.
"""
import json, subprocess, pathlib, re, sys

HERE = pathlib.Path(__file__).resolve().parent
PROD_REF = "zqnexqbdfvbhlxzelzju"
DEMO_ENV = pathlib.Path("/home/melik/egesut-erp1/.env").read_text()
DEMO_REF = re.search(r"^SUPABASE_DEMO_REF=(.*)$", DEMO_ENV, re.M).group(1).strip().strip('"')
DEMO_PAT = re.search(r"^SUPABASE_DEMO_PAT=(.*)$", DEMO_ENV, re.M).group(1).strip().strip('"')
TOK = re.search(r"^SUPABASE_MANAGEMENT_TOKEN=(.*)$",
                pathlib.Path("/home/melik/tools-bank/.env").read_text(), re.M).group(1).strip()

QUERIES = {
    "dozaj_seed_prod": """SELECT count(*) AS toplam,
        count(*) FILTER (WHERE std_dose IS NOT NULL) AS std_dose_dolu,
        count(*) FILTER (WHERE std_dose_min IS NOT NULL) AS min_dolu,
        count(*) FILTER (WHERE std_dose_max IS NOT NULL) AS max_dolu
        FROM public.drug_products;""",
    "dozaj_seed_isimler_prod": """SELECT brand_name, std_dose, std_dose_unit FROM public.drug_products
        WHERE std_dose IS NOT NULL ORDER BY brand_name;""",
    "dozaj_seed_demo": """SELECT count(*) AS toplam,
        count(*) FILTER (WHERE std_dose IS NOT NULL) AS std_dose_dolu
        FROM public.drug_products;""",
    "dozaj_seed_isimler_demo": """SELECT brand_name, std_dose, std_dose_unit FROM public.drug_products
        WHERE std_dose IS NOT NULL ORDER BY brand_name;""",
    "buzagi_id_prod": """SELECT count(*) AS toplam,
        count(*) FILTER (WHERE buzagi_id IS NOT NULL) AS buzagi_dolu
        FROM public.dogum;""",
    "pedigree_nodes_prod": """SELECT
        (SELECT count(*) FROM public.pedigree_nodes) AS nodes,
        (SELECT count(*) FROM public.pedigree_parentage) AS parentage,
        (SELECT count(*) FROM public.hayvanlar) AS hayvanlar;""",
    "pedigree_integrity_prod": "SELECT * FROM public.pedigree_integrity_report();",
    "rpc_var_mi_prod": """SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname='public' AND p.proname IN
        ('ilac_dozaj_guncelle','hayvan_kilo_guncelle','pedigree_subgraph_for_animal',
         'fn_sperma_stok_dus','gebelik_kaydet_manual','pedigree_integrity_report')
        ORDER BY 1, 2;""",
    "guard_fn_prod": """SELECT p.proname, md5(pg_get_functiondef(p.oid)) AS fdef_md5
        FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname='public' AND p.proname = '_guard_tohumlama_yas_cinsiyet';""",
    "tohumlama_fn_dokunulmazlik": """SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args,
        md5(pg_get_functiondef(p.oid)) AS fdef_md5
        FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
        WHERE n.nspname='public' AND p.proname IN ('tohumlama_kaydet','tohumlama_tekrar_kaydet')
        ORDER BY 1,2;""",
    "stok_hareket_dokunma": """SELECT count(*) AS toplam, max(created_at) AS son
        FROM public.stok_hareket;""",
}


def run(label, sql, ref, token):
    body = json.dumps({"query": f"BEGIN READ ONLY; {sql} ROLLBACK;"})
    r = subprocess.run(
        ["curl", "-sS", "-X", "POST",
         f"https://api.supabase.com/v1/projects/{ref}/database/query",
         "-H", f"Authorization: Bearer {token}", "-H", "Content-Type: application/json",
         "-d", body, "--max-time", "120"], capture_output=True, text=True)
    try:
        return json.loads(r.stdout)
    except Exception:
        return {"parse_error": r.stdout[:300]}


out = {}
for label, sql in QUERIES.items():
    if label.endswith("_demo"):
        out[label] = run(label, sql, DEMO_REF, DEMO_PAT)
    else:
        out[label] = run(label, sql, PROD_REF, TOK)
    print(f"{label}: {json.dumps(out[label], ensure_ascii=False)[:220]}", flush=True)

(HERE / "verify_data.json").write_text(json.dumps(out, ensure_ascii=False, indent=1))

# özet değerlendirme
p = out["dozaj_seed_prod"][0]
print("\n--- ÖZET ---")
print(f"drug_products: {p['toplam']} toplam, {p['std_dose_dolu']} std_dose dolu "
      f"(demo: {out['dozaj_seed_demo'][0]['std_dose_dolu']})")
names_p = {r["brand_name"] for r in out["dozaj_seed_isimler_prod"]}
names_d = {r["brand_name"] for r in out["dozaj_seed_isimler_demo"]}
print(f"seed isim kümesi prod==demo: {names_p == names_d} "
      f"(prod={len(names_p)}, demo={len(names_d)}; prod'a özgü={sorted(names_p-names_d)[:5]}; "
      f"demo'ya özgü={sorted(names_d-names_p)[:5]})")
b = out["buzagi_id_prod"][0]
print(f"dogum: {b['toplam']} toplam, {b['buzagi_dolu']} buzagi_id dolu")
pn = out["pedigree_nodes_prod"][0]
print(f"pedigree_nodes={pn['nodes']}, pedigree_parentage={pn['parentage']} (hayvanlar={pn['hayvanlar']})")
print("integrity_report:", json.dumps(out["pedigree_integrity_prod"], ensure_ascii=False)[:400])
