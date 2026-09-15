#!/usr/bin/env python3
"""P1 devam — DML veri spot-probe'ları + satır sayıları + yedek durumu (PROD, salt-okunur).

Her sorgu BEGIN READ ONLY; ... ROLLBACK; zarfında. Hata (eksik kolon/tablo) beklenen
kanıt olarak kaydedilir — migration uygulanmamış demektir.
Çıktı: data_probe_prod.json + backup_status.json
"""
import json, subprocess, pathlib, re, sys

HERE = pathlib.Path(__file__).resolve().parent
PROD_REF = "zqnexqbdfvbhlxzelzju"

TOK = re.search(r"^SUPABASE_MANAGEMENT_TOKEN=(.*)$",
                pathlib.Path("/home/melik/tools-bank/.env").read_text(), re.M).group(1).strip()

QUERIES = {
    "abort_tarihi_backfill": "SELECT count(*) AS toplam, count(*) FILTER (WHERE sonuc='Abort' AND abort_tarihi IS NULL) AS abort_tarihi_bos FROM public.tohumlama;",
    "dogum_olay_id_backfill": "SELECT count(*) AS toplam, count(*) FILTER (WHERE olay_id IS NULL) AS olay_id_bos FROM public.dogum;",
    "asi_stok_satirlari": "SELECT count(*) AS asi_stok_satiri FROM public.stok WHERE id LIKE 'STOK-AŞI-%';",
    "asi_stok_baglanti": "SELECT name, (stock_item_id IS NOT NULL) AS bagli FROM public.vaccines WHERE name IN ('Coglavax','Vac-Sules Feedlot');",
    "asi_planli_gorev": "SELECT count(*) AS asi_planli FROM public.gorev_log WHERE gorev_tipi='ASI_PLANLI';",
    "postpartum_d53_gorev": "SELECT count(*) AS d53_gorev FROM public.gorev_log WHERE aciklama LIKE '53. Gün%';",
    "dozaj_seed": "SELECT count(*) AS toplam, count(*) FILTER (WHERE std_dose IS NOT NULL) AS std_dose_dolu FROM public.drug_products;",
    "dozaj_min_max": "SELECT count(*) FILTER (WHERE std_dose_min IS NOT NULL) AS min_dolu, count(*) FILTER (WHERE std_dose_max IS NOT NULL) AS max_dolu FROM public.drug_products;",
    "asi_seed_vaccines": "SELECT count(*) FILTER (WHERE marka IN ('Vetal','MSD')) AS seed_marka FROM public.vaccines;",
    "buzagi_id_backfill": "SELECT count(*) AS toplam, count(*) FILTER (WHERE buzagi_id IS NOT NULL) AS buzagi_dolu FROM public.dogum;",
    "pedigree_nodes": "SELECT count(*) AS node FROM public.pedigree_nodes;",
    "pedigree_parentage": "SELECT count(*) AS bag FROM public.pedigree_parentage;",
    "degisim_log": "SELECT count(*) AS kayit FROM public.degisim_log;",
    # risk bölümü için satır sayıları (kilit/backfill süresi tahmini)
    "satir_sayilari": """SELECT (SELECT count(*) FROM public.hayvanlar) AS hayvanlar,
       (SELECT count(*) FROM public.tohumlama) AS tohumlama,
       (SELECT count(*) FROM public.dogum) AS dogum,
       (SELECT count(*) FROM public.gorev_log) AS gorev_log,
       (SELECT count(*) FROM public.cases) AS cases,
       (SELECT count(*) FROM public.drug_products) AS drug_products,
       (SELECT count(*) FROM public.vaccines) AS vaccines,
       (SELECT count(*) FROM public.stok) AS stok,
       (SELECT count(*) FROM public.islem_log) AS islem_log;""",
}


def run(label, sql):
    body = json.dumps({"query": f"BEGIN READ ONLY; {sql} ROLLBACK;"})
    r = subprocess.run(
        ["curl", "-sS", "-X", "POST", f"https://api.supabase.com/v1/projects/{PROD_REF}/database/query",
         "-H", f"Authorization: Bearer {TOK}", "-H", "Content-Type: application/json",
         "-d", body, "--max-time", "120"], capture_output=True, text=True)
    try:
        return {"ok": True, "rows": json.loads(r.stdout)}
    except Exception:
        return {"ok": False, "raw": r.stdout[:300]}


if __name__ == "__main__":
    out = {}
    for label, sql in QUERIES.items():
        out[label] = run(label, sql)
        s = json.dumps(out[label], ensure_ascii=False)[:150]
        print(f"{label}: {s}", flush=True)
    (HERE / "data_probe_prod.json").write_text(json.dumps(out, indent=1, ensure_ascii=False))

    # yedek/PITR durumu (Mgmt API, salt-okunur GET)
    r = subprocess.run(["curl", "-sS", f"https://api.supabase.com/v1/projects/{PROD_REF}/database/backups",
                        "-H", f"Authorization: Bearer {TOK}", "--max-time", "60"],
                       capture_output=True, text=True)
    try:
        b = json.loads(r.stdout)
    except Exception:
        b = {"raw": r.stdout[:400]}
    (HERE / "backup_status.json").write_text(json.dumps(b, indent=1, ensure_ascii=False)[:20000])
    if isinstance(b, dict) and "backups" in b:
        print("backups:", len(b["backups"]), "kayıt; PITR:", b.get("pitr_enabled"), "; physical:",
              [x.get("status") for x in b["backups"] if x.get("type") == "physical backup"][:3])
    else:
        print("backups endpoint:", json.dumps(b, ensure_ascii=False)[:200])
