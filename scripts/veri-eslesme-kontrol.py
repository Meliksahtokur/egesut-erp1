#!/usr/bin/env python3
"""P6 — Prod/demo veri eşleşme kontrolü: prod'a demo/test verisi sızmış mı?

SALT OKUNUR. Her sorgu `BEGIN READ ONLY; ... ROLLBACK;` sarmında, Supabase
Management API (`POST /v1/projects/<ref>/database/query`) üzerinden koşar.
Token'lar .env dosyalarından okunur; hiçbir çıktıya/dosyaya yazılmaz.
Prod ve demo'ya HİÇBİR ŞEY YAZILMAZ — açılışta READ ONLY guard self-test'i
bunu kanıtlar (yazma denemesi reddedilmeli).

Dört kontrol (her biri alt komut; `hepsi` hepsini koşar):
  sizinti  demo-doğumlu satırların prod'da bulunması — hüküm kopya-sonrası
           created_at sinyaline bağlıdır (varsayılan kopya tarihi 2026-07-02:
           docs/demo-mirror-ROADMAP.md D0). Kesişimde klon imzası (demo/prod
           created_at birebir eşit = `demo_klonla()` prod→demo akışı) AYIKLANIR;
           hüküm yalnız şüpheli (created_at farklı) satırlara bağlanır. PK küme
           farkı ve prod-only sayısı bilgidir. Takma ad: sizinta
  isaret   prod text/varchar/jsonb kolonlarında test işaretleri (sayı + yerel bağlam)
  koken    yeni tabloların (pedigree_*, semen_catalog) ve doldurulan kolonların
           (dogum.buzagi_id, drug_products.std_dose) prod kaynağa bağlanması
  statik   verilen migration dosyalarındaki INSERT/UPDATE/DELETE'lerin
           türetilmiş (prod tablosundan) mi sabit değer mi olduğu

Çıktı: --cikti dizininde ozet.json (yalnız sayı/ad — satır değeri YOK) ve
yerel ayrıntı dosyaları + sorgular.sql (kanıt). Kapanışta tek satır hüküm:
`TEMIZ` / `BULGU: <n>` / hata varsa `HATA: <n> sorgu koşulamadı`.

Kullanım:
  python3 scripts/veri-eslesme-kontrol.py hepsi
  python3 scripts/veri-eslesme-kontrol.py isaret --ek-isaret eksper
  python3 scripts/veri-eslesme-kontrol.py statik --dosya 20260911000002 --dosya 20260911000003
  python3 scripts/veri-eslesme-kontrol.py sizinti            # takma ad: sizinta
  python3 scripts/veri-eslesme-kontrol.py sizinti --kopya-tarihi 2026-07-02T00:00:00+03:00

Her prod migration uygulamasından sonra tekrar koşulur.
"""
import argparse
import datetime as dt
import json
import pathlib
import re
import subprocess
import sys

PROD_REF = "zqnexqbdfvbhlxzelzju"
PROD_TOKFILE = "/home/melik/tools-bank/.env"        # SUPABASE_MANAGEMENT_TOKEN
DEMO_ENVFILE = "/home/melik/egesut-erp1/.env"        # SUPABASE_DEMO_REF, SUPABASE_DEMO_PAT

# Zarf P6: sabit işaret listesi (+ --ek-isaret ile genişletilir).
# Kısa işaretler (<=3 krk) kelime sınırlı eşleşir (~* '\\yk1\\y'), uzunlar
# alt dizin (lower(col) LIKE '%isaret%') — kısa alt dizinin yanlış pozitif
# yağmurunu sınırlamak için.
TEMEL_ISARETLER = [
    "l4-yuruyus", "fixture", "deneme", "test", "demo", "w2b",
    "k1", "k2", "k3", "k4", "k5", "k6",
    "yuruyus", "root-gate",
]

# Zarf P6 kontrol 4: varsayılan bugünkü 10 dosya (supabase/migrations/ altında önek).
VARSAYILAN_MIGRATIONLAR = [
    "20260831000003", "20260909100000", "20260909110000",
    "20260910000001", "20260910000002", "20260910000003",
    "20260911000001", "20260911000002", "20260911000003", "20260911000004",
]

# Zarf P6 kontrol 3: yeni tablolar + doldurulan kolonlar + ad eşleşmeleri.
YENI_TABLOLAR = ["pedigree_nodes", "pedigree_parentage", "pedigree_meta", "semen_catalog"]
AD_ESLESMELER = [("semen_catalog", "display_name", "tohumlama", "sperma")]
DOLDURULAN_FK = [("dogum", "buzagi_id", "hayvanlar", "id")]

MAX_SATIR = 100_000  # PK kümesi çekme eşiği: üstünde tablo atlanır ve raporlanır


def read_env(path, key):
    txt = pathlib.Path(path).read_text()
    m = re.search(rf"^{key}=(.*)$", txt, re.M)
    if not m:
        sys.exit(f"{key} yok: {path}")
    return m.group(1).strip().strip('"').strip("'")


class Db:
    """Management API üzerinden salt-okunur SQL koşucusu."""

    def __init__(self, tag, ref, token, cikti_dir):
        self.tag, self.ref, self.token = tag, ref, token
        self.proof = open(cikti_dir / "sorgular.sql", "a", encoding="utf-8")
        self.errors = []

    def sql(self, sql, label=""):
        body = json.dumps({"query": f"BEGIN READ ONLY; {sql} ROLLBACK;"})
        r = subprocess.run(
            ["curl", "-sS", "-X", "POST",
             f"https://api.supabase.com/v1/projects/{self.ref}/database/query",
             "-H", f"Authorization: Bearer {self.token}",
             "-H", "Content-Type: application/json",
             "-d", body, "--max-time", "180"],
            capture_output=True, text=True)
        self.proof.write(f"-- [{self.tag}] {label}\n{sql}\n\n")
        try:
            data = json.loads(r.stdout)
        except Exception:
            self.errors.append(f"{label}: json parse: {r.stdout[:200]} {r.stderr[:150]}")
            return None
        if isinstance(data, dict) and ("error" in data or "message" in data):
            self.errors.append(f"{label}: {json.dumps(data, ensure_ascii=False)[:250]}")
            return None
        return data

    def scalar(self, sql, label=""):
        rows = self.sql(sql, label)
        if not rows:
            return None
        return list(rows[0].values())[0]

    def close(self):
        self.proof.close()


def selftest_readonly(db):
    """READ ONLY guard kanıtı: yazma denemesi REDDEDİLMELİ. Başarırsa dur."""
    body = json.dumps({"query": "BEGIN READ ONLY; CREATE TEMP TABLE _ro_guard(i int); ROLLBACK;"})
    r = subprocess.run(
        ["curl", "-sS", "-X", "POST",
         f"https://api.supabase.com/v1/projects/{db.ref}/database/query",
         "-H", f"Authorization: Bearer {db.token}",
         "-H", "Content-Type: application/json",
         "-d", body, "--max-time", "60"],
        capture_output=True, text=True)
    out = r.stdout
    if "read-only" in out:
        return True
    print(f"PANIK: [{db.tag}] READ ONLY guard çalışmıyor — yazma kabul edildi!: {out[:200]}")
    sys.exit(2)


def qident(name):
    return '"' + name.replace('"', '""') + '"'


def qstr(s):
    return "'" + s.replace("'", "''") + "'"


def inlist(names):
    return "ARRAY[" + ",".join(qstr(n) for n in names) + "]"


# ---------------------------------------------------------------- sizinta ----

def tablo_ve_pk_map(db):
    """public tabloları + PK kolonları (pg_index indisprimary yoluyla)."""
    tables = db.sql(
        "SELECT c.relname AS t FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace "
        "WHERE n.nspname='public' AND c.relkind IN ('r','p') ORDER BY 1;", "tablo-listesi")
    pk = db.sql(
        "SELECT cl.relname AS t, a.attname AS c, x.ord AS pos "
        "FROM pg_index i JOIN pg_class cl ON cl.oid=i.indrelid "
        "JOIN pg_namespace n ON n.oid=cl.relnamespace "
        "CROSS JOIN unnest(i.indkey) WITH ORDINALITY x(attnum, ord) "
        "JOIN pg_attribute a ON a.attrelid=cl.oid AND a.attnum=x.attnum "
        "WHERE i.indisprimary AND n.nspname='public' "
        "ORDER BY cl.relname, x.ord;", "pk-katalogu")
    pk_map = {}
    if pk:
        for row in pk:
            pk_map.setdefault(row["t"], []).append((row["pos"], row["c"]))
    return ([r["t"] for r in (tables or [])],
            {t: [c for _, c in sorted(cols)] for t, cols in pk_map.items()})


def pk_set(db, tablo, pk_cols):
    cast = " || '|' || ".join(f"t.{qident(c)}::text" for c in pk_cols)
    rows = db.sql(f"SELECT {cast} AS pk FROM public.{qident(tablo)} t;", f"pk:{tablo}")
    return set(r["pk"] for r in (rows or []))


def cmd_sizinta(prod, demo, args, out):
    pt, ppk = tablo_ve_pk_map(prod)
    dt_, dpk = tablo_ve_pk_map(demo)
    ortak = sorted(set(pt) & set(dt_))
    sonuc = {"ortak_tablo": len(ortak), "pk_yok": sorted(set(ortak) - set(ppk) - set(dpk)),
             "atlanan_buyuk": [], "demo_dogumlu": {}, "sizinti": {}, "prod_only": {},
             "kopya_tarihi": args.kopya_tarihi, "kopya_sonrasi_prodda": {},
             "kopya_sonrasi_klon_imzali": {}, "kopya_sonrasi_supheli": {},
             "kopya_sonrasi_olculmeyen": []}
    for t in ortak:
        if t not in ppk or t not in dpk:
            continue
        n_demo = demo.scalar(f"SELECT count(*) AS n FROM public.{qident(t)};", f"count-demo:{t}")
        n_prod = prod.scalar(f"SELECT count(*) AS n FROM public.{qident(t)};", f"count-prod:{t}")
        if n_demo is None or n_prod is None:
            continue
        if n_demo > MAX_SATIR or n_prod > MAX_SATIR:
            sonuc["atlanan_buyuk"].append(t)
            continue
        dset, pset = pk_set(demo, t, dpk[t]), pk_set(prod, t, ppk[t])
        dogumlu = dset - pset
        sonuc["demo_dogumlu"][t] = len(dogumlu)
        # SIZINTI: demo-doğumlu PK'ların prod'da bulunması (zarf formülü).
        if dogumlu:
            chunk, bulunan = 1000, 0
            keys = sorted(dogumlu)
            for i in range(0, len(keys), chunk):
                part = keys[i:i + chunk]
                n = prod.scalar(
                    f"SELECT count(*) AS n FROM public.{qident(t)} t WHERE ("
                    + " || '|' || ".join(f"t.{qident(c)}::text" for c in ppk[t])
                    + ") IN (" + ",".join(qstr(k) for k in part) + ");",
                    f"sizinti-ara:{t}:{i}")
                bulunan += int(n or 0)
            sonuc["sizinti"][t] = bulunan
        sonuc["prod_only"][t] = len(pset - dset)
        # created_at sinyali (varsayılan açık): kopyadan sonra doğan demo satırı
        # prod'da var mı — SIZINTI hükmü bu ölçüme bağlıdır. KESİŞİM satırları
        # ikiye ayrılır: klon imzalı (demo/prod created_at birebir eşit —
        # `demo_klonla()` prod_fdw'den created_at dahil birebir kopyalar, meşru
        # prod→demo akışı) ve ŞÜPHELİ (created_at farklı — elle/uygunsuz kopya).
        if args.kopya_tarihi:
            cols = demo.sql(
                "SELECT column_name AS c FROM information_schema.columns "
                "WHERE table_schema='public' AND table_name=" + qstr(t)
                + " AND column_name IN ('created_at','olusturulma','eklenme_tarihi');",
                f"created_at-kolon:{t}")
            if cols:
                ca = cols[0]["c"]
                sonraki = demo.sql(
                    f"SELECT {qident(ppk[t][0])}::text AS pk, extract(epoch from {qident(ca)})::text AS ep "
                    f"FROM public.{qident(t)} WHERE {qident(ca)} > "
                    + qstr(args.kopya_tarihi) + ";", f"kopya-sonrasi:{t}")
                dmap = {r["pk"]: r["ep"] for r in (sonraki or [])}
                pkeys = list(dmap)[:MAX_SATIR]
                if pkeys:
                    prows = prod.sql(
                        f"SELECT {qident(ppk[t][0])}::text AS pk, extract(epoch from {qident(ca)})::text AS ep "
                        f"FROM public.{qident(t)} WHERE {qident(ppk[t][0])}::text IN ("
                        + ",".join(qstr(k) for k in pkeys) + ");", f"kopya-sonrasi-prod:{t}")
                    pmap = {r["pk"]: r["ep"] for r in (prows or [])}
                    kesisim = [k for k in pkeys if k in pmap]
                    supheli = [k for k in kesisim if pmap[k] != dmap[k]]
                    sonuc["kopya_sonrasi_prodda"][t] = len(kesisim)
                    sonuc["kopya_sonrasi_klon_imzali"][t] = len(kesisim) - len(supheli)
                    sonuc["kopya_sonrasi_supheli"][t] = len(supheli)
                else:
                    sonuc["kopya_sonrasi_prodda"][t] = 0
            else:
                sonuc["kopya_sonrasi_olculmeyen"].append(t)
    out["sizinti"] = sonuc
    # Hükme yalnız kopya-sonrası ŞÜPHELİ ölçümü girer: ham kesişim (prodda)
    # klon akışını (meşru prod→demo) da sayar, PK-farkı (zarf formülü, tanımı
    # gereği hep 0) bilgi olarak ozette kalır.
    toplam_sizinti = sum(sonuc["kopya_sonrasi_supheli"].values())
    print(f"[sizinti] ortak={sonuc['ortak_tablo']} kopya_tarihi={sonuc['kopya_tarihi']} "
          f"SIZINTI(supheli)={toplam_sizinti} "
          f"bilgi: kesisim={sum(sonuc['kopya_sonrasi_prodda'].values())} "
          f"(klon_imzali={sum(sonuc['kopya_sonrasi_klon_imzali'].values())}) "
          f"pk_farki={sum(sonuc['sizinti'].values())} "
          f"demo_dogumlu={sum(sonuc['demo_dogumlu'].values())} "
          f"prod_only={sum(sonuc['prod_only'].values())} "
          f"olculmeyen={len(sonuc['kopya_sonrasi_olculmeyen'])}")
    return toplam_sizinti


# ----------------------------------------------------------------- isaret ----

def isaret_pred(isaret):
    """Kısa işaret: kelime sınırlı regex; uzun: alt dizin LIKE."""
    if len(isaret) <= 3:
        return ("regex", r"\y" + re.escape(isaret) + r"\y")
    return ("like", "%" + isaret.lower() + "%")


def cmd_isaret(prod, args, out, cikti):
    isaretler = list(dict.fromkeys(TEMEL_ISARETLER + (args.ek_isaret or [])))
    cols = prod.sql(
        "SELECT table_name AS t, column_name AS c, data_type AS d "
        "FROM information_schema.columns "
        "WHERE table_schema='public' AND data_type IN ('text','character varying','json','jsonb') "
        "ORDER BY table_name, column_name;", "isaret-kolonlar")
    by_table = {}
    for r in (cols or []):
        by_table.setdefault(r["t"], []).append(r)
    eslesen = []
    for t, tcols in sorted(by_table.items()):
        parts = []
        for r in tcols:
            expr = f"{qident(r['c'])}::text"
            filters = []
            for is_ in isaretler:
                kind, pat = isaret_pred(is_)
                if kind == "like":
                    cond = f"lower({expr}) LIKE {qstr(pat)}"
                else:
                    cond = f"{expr} ~* {qstr(pat)}"
                filters.append(f"count(*) FILTER (WHERE {cond}) AS {qident('m_' + is_.replace('-', '_'))}")
            parts.append(f"SELECT {qstr(t)} AS t, {qstr(r['c'])} AS c, " + ", ".join(filters)
                         + f" FROM public.{qident(t)}")
        rows = prod.sql("\nUNION ALL\n".join(parts) + ";", f"isaret:{t}")
        if not rows:
            continue
        for row in rows:
            for is_ in isaretler:
                n = row.get("m_" + is_.replace("-", "_"), 0)
                if n:
                    eslesen.append({"tablo": t, "kolon": row["c"], "isaret": is_, "sayi": int(n)})
    # Bağlam: yalnız yerel çıktı dizinine (rapora girmez).
    with open(cikti / "isaret-baglam.txt", "w", encoding="utf-8") as fh:
        for e in eslesen:
            kind, pat = isaret_pred(e["isaret"])
            if kind == "like":
                pos = f"greatest(strpos(lower({qident(e['kolon'])}::text), {qstr(e['isaret'].lower())}) - 10, 1)"
                cond = f"lower({qident(e['kolon'])}::text) LIKE {qstr(pat)}"
            else:
                pos = f"greatest(coalesce(position(lower({qstr(e['isaret'])}) in lower({qident(e['kolon'])}::text)), 1) - 10, 1)"
                cond = f"{qident(e['kolon'])}::text ~* {qstr(pat)}"
            baglam = prod.sql(
                f"SELECT substring({qident(e['kolon'])}::text from {pos} for 40) AS ctx "
                f"FROM public.{qident(e['tablo'])} WHERE {cond} LIMIT 3;",
                f"baglam:{e['tablo']}.{e['kolon']}:{e['isaret']}")
            for b in (baglam or []):
                fh.write(f"[{e['tablo']}.{e['kolon']} | {e['isaret']}] {b['ctx']}\n")
    out["isaret"] = {"isaretler": isaretler, "eslesen_kombinasyon": len(eslesen),
                     "eslesen_toplam_satir": sum(e["sayi"] for e in eslesen),
                     "eslesen": sorted(eslesen, key=lambda e: (-e["sayi"], e["tablo"], e["kolon"]))}
    print(f"[isaret] eslesen_kombinasyon={len(eslesen)} "
          f"eslesen_toplam_satir={out['isaret']['eslesen_toplam_satir']}")
    return len(eslesen)


# ------------------------------------------------------------------ koken ----

def cmd_koken(prod, out):
    sonuc: dict = {"fk": [], "ad_eslesme": [], "doldurulan": []}
    fks = prod.sql(
        "SELECT cl.relname AS tbl, rc.relname AS reftbl, "
        "(SELECT string_agg(a.attname, ',' ORDER BY x.ord) FROM unnest(c.conkey) WITH ORDINALITY x(attnum, ord) "
        "  JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=x.attnum) AS cols, "
        "(SELECT string_agg(a.attname, ',' ORDER BY x.ord) FROM unnest(c.confkey) WITH ORDINALITY x(attnum, ord) "
        "  JOIN pg_attribute a ON a.attrelid=c.confrelid AND a.attnum=x.attnum) AS refcols "
        "FROM pg_constraint c "
        "JOIN pg_class cl ON cl.oid=c.conrelid JOIN pg_namespace n ON n.oid=cl.relnamespace "
        "JOIN pg_class rc ON rc.oid=c.confrelid "
        "WHERE c.contype='f' AND n.nspname='public' AND cl.relname = ANY(" + inlist(YENI_TABLOLAR) + ");",
        "yeni-tablo-fk")
    fk_hedefler = set()
    for fk in (fks or []):
        cols = str(fk["cols"] or "").split(",")
        refcols = str(fk["refcols"] or "").split(",")
        null_guard = " AND ".join(f"t.{qident(c)} IS NOT NULL" for c in cols)
        join = " AND ".join(f"r.{qident(rc)} = t.{qident(c)}" for c, rc in zip(cols, refcols))
        n = prod.scalar(
            f"SELECT count(*) AS n FROM public.{qident(fk['tbl'])} t "
            f"WHERE {null_guard} AND NOT EXISTS (SELECT 1 FROM public.{qident(fk['reftbl'])} r WHERE {join});",
            f"fk-yetim:{fk['tbl']}.{fk['cols']}")
        sonuc["fk"].append({"tablo": fk["tbl"], "kolonlar": fk["cols"], "hedef": fk["reftbl"],
                            "hedef_kolonlar": fk["refcols"], "yetim": int(n or 0)})
        fk_hedefler.add((fk["tbl"], fk["cols"]))
    # dogum.buzagi_id gibi doldurulan FK kolonları (tablo yeni değil).
    for (t, c, rt, rc) in DOLDURULAN_FK:
        n = prod.scalar(
            f"SELECT count(*) AS n FROM public.{qident(t)} t WHERE t.{qident(c)} IS NOT NULL "
            f"AND NOT EXISTS (SELECT 1 FROM public.{qident(rt)} r WHERE r.{qident(rc)} = t.{qident(c)});",
            f"doldurulan-yetim:{t}.{c}")
        sonuc["doldurulan"].append({"tablo": t, "kolon": c, "hedef": rt, "yetim": int(n or 0)})
    # Ad eşleşmeleri: semen_catalog → prod tohumlama sperma adları.
    for (t, c, rt, rc) in AD_ESLESMELER:
        n = prod.scalar(
            f"SELECT count(*) AS n FROM public.{qident(t)} s WHERE NOT EXISTS ("
            f"SELECT 1 FROM public.{qident(rt)} r WHERE lower(btrim(r.{qident(rc)})) = lower(btrim(s.{qident(c)})));",
            f"ad-eslesme:{t}.{c}->{rt}.{rc}")
        sonuc["ad_eslesme"].append({"tablo": t, "kolon": c, "hedef": rt, "hedef_kolon": rc,
                                    "baglanamayan": int(n or 0)})
    # Bilgi: drug_products.std_dose doluluk (kaynağı statik kontrolde sınıflanır).
    n = prod.scalar(
        "SELECT count(*) AS n FROM public.drug_products WHERE std_dose IS NOT NULL;", "std_dose-dolu")
    sonuc["std_dose_dolu"] = int(n or 0)
    out["koken"] = sonuc
    yetim = (sum(f["yetim"] for f in sonuc["fk"]) + sum(d["yetim"] for d in sonuc["doldurulan"])
             + sum(a["baglanamayan"] for a in sonuc["ad_eslesme"]))
    print(f"[koken] fk={len(sonuc['fk'])} doldurulan={len(sonuc['doldurulan'])} "
          f"ad_eslesme={len(sonuc['ad_eslesme'])} YETIM={yetim} std_dose_dolu={sonuc['std_dose_dolu']}")
    return yetim


# ----------------------------------------------------------------- statik ----

DELIM = re.compile(r"\$([A-Za-z_][A-Za-z0-9_]*)?\$")
DML_BAS = re.compile(r"(?im)^[\t ]*(INSERT\s+INTO|UPDATE|DELETE\s+FROM)\s+((?:public\.)?\"?[A-Za-z_][A-Za-z0-9_]*\"?)")
KAYNAK = re.compile(r"(?i)\bFROM\s+((?:public\.)?\"?[A-Za-z_][A-Za-z0-9_]*\"?)")


def dollar_bloklari(text):
    """`$$` / `$etiket$` sınırlı gövdeler (DO blokları + CREATE FUNCTION gövdeleri).

    Açılış, AYNI sınırlayıcı diziyle kapanır (`$function$`...`$function$`).
    """
    bloklar, pos = [], 0
    while True:
        m = DELIM.search(text, pos)
        if not m:
            break
        b = text.find(m.group(0), m.end())
        if b == -1:
            bloklar.append((m.start(), len(text)))
            break
        bloklar.append((m.start(), b + len(m.group(0))))
        pos = b + len(m.group(0))
    return bloklar


def cmd_statik(args, out):
    kok = pathlib.Path(__file__).resolve().parent.parent / "supabase" / "migrations"
    dosyalar = args.dosya or VARSAYILAN_MIGRATIONLAR
    sonuc = {}
    for on_ek in dosyalar:
        eslesen = sorted(kok.glob(on_ek + "*.sql"))
        if not eslesen:
            sonuc[on_ek] = {"hata": "dosya bulunamadi"}
            continue
        for dosya in eslesen:
            text = dosya.read_text(encoding="utf-8")
            bloklar = dollar_bloklari(text)
            bulgular = []
            for m in DML_BAS.finditer(text):
                tur = "INSERT" if m.group(1).upper().startswith("INSERT") else (
                    "UPDATE" if m.group(1).upper().startswith("UPDATE") else "DELETE")
                tablo = m.group(2).removeprefix("public.").strip('"')
                son2 = text.find(";", m.end())
                govde = text[m.end():son2 if son2 != -1 else len(text)]
                satir = text[:m.start()].count("\n") + 1
                plpgsql = any(a <= m.start() <= b for a, b in bloklar)
                govde_u = govde.upper()
                if plpgsql:
                    # RPC gövdesi: değerler parametre/değişken — sabit yazma değil,
                    # doğrudan prod türetmesi de değil (koşullu programatik akış).
                    sinif = "rpc-govdesi"
                elif tur == "INSERT":
                    sinif = "turetilmis" if "SELECT" in govde_u else "sabit"
                elif tur == "UPDATE":
                    sinif = "turetilmis" if (re.search(r"\bFROM\b", govde_u)
                                             or re.search(r"=\s*(\(\s*)?SELECT\b", govde_u)) else "sabit"
                else:
                    sinif = "turetilmis" if " USING " in f" {govde_u} " else "sabit"
                kaynaklar = sorted({mm.group(1).removeprefix("public.").strip('"')
                                    for mm in KAYNAK.finditer(govde)})
                bulgular.append({"tur": tur, "tablo": tablo, "satir": satir,
                                 "tur_sinif": sinif, "kaynaklar": kaynaklar})
            ad = dosya.name
            sonuc[ad] = {
                "insert": sum(1 for b in bulgular if b["tur"] == "INSERT"),
                "update": sum(1 for b in bulgular if b["tur"] == "UPDATE"),
                "delete": sum(1 for b in bulgular if b["tur"] == "DELETE"),
                "turetilmis": sum(1 for b in bulgular if b["tur_sinif"] == "turetilmis"),
                "sabit": sum(1 for b in bulgular if b["tur_sinif"] == "sabit"),
                "rpc_govdesi": sum(1 for b in bulgular if b["tur_sinif"] == "rpc-govdesi"),
                "ifadeler": bulgular,
            }
    out["statik"] = sonuc
    sabit_top = sum(d.get("sabit", 0) for d in sonuc.values())
    turetilmis_top = sum(d.get("turetilmis", 0) for d in sonuc.values())
    rpc_top = sum(d.get("rpc_govdesi", 0) for d in sonuc.values())
    print(f"[statik] dosya={len(sonuc)} turetilmis={turetilmis_top} sabit={sabit_top} rpc_govdesi={rpc_top}")
    return 0  # statik bulgu sayısına girmez; sınıflandırma bilgisidir


# ------------------------------------------------------------------- main ----

def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("komut", choices=["sizinti", "sizinta", "isaret", "koken", "statik", "hepsi"])
    ap.add_argument("--cikti", default=None,
                    help="çıktı dizini (varsayılan: ~/tmp/agents/veri-eslesme-<tarih>/, REPO DIŞI)")
    ap.add_argument("--ek-isaret", action="append", default=None,
                    help="isaret kontrolüne ek işaret (tekrarlanabilir)")
    ap.add_argument("--dosya", action="append", default=None,
                    help="statik kontrol migration öneği (tekrarlanabilir; varsayılan: bugünün 10 dosyası)")
    ap.add_argument("--kopya-tarihi", default="2026-07-02T00:00:00+03:00",
                    help="demo kopyasının prod'dan alındığı tarih (ISO; varsayılan 2026-07-02 — "
                         "docs/demo-mirror-ROADMAP.md D0). Kopyadan sonra doğan demo satırının "
                         "prod'da bulunması (kopya_sonrasi_prodda) HÜKME girer")
    args = ap.parse_args()

    gun = dt.date.today().strftime("%Y%m%d")
    cikti = pathlib.Path(args.cikti).expanduser() if args.cikti \
        else pathlib.Path.home() / "tmp" / "agents" / f"veri-eslesme-{gun}"
    cikti.mkdir(parents=True, exist_ok=True)

    prod = Db("prod", PROD_REF, read_env(PROD_TOKFILE, "SUPABASE_MANAGEMENT_TOKEN"), cikti)
    demo_ref = read_env(DEMO_ENVFILE, "SUPABASE_DEMO_REF")
    demo = Db("demo", demo_ref, read_env(DEMO_ENVFILE, "SUPABASE_DEMO_PAT"), cikti)

    print(f"[selftest] READ ONLY guard sınanıyor...")
    selftest_readonly(prod)
    selftest_readonly(demo)
    print("[selftest] OK — iki DB'de de yazma reddedildi (salt-okunur kanıtlandı)")

    out: dict = {"tarih": dt.datetime.now().isoformat(timespec="seconds"),
                 "prod_ref": PROD_REF, "demo_ref": demo_ref, "cikti_dizini": str(cikti)}
    bulgu = 0
    if args.komut in ("sizinti", "sizinta", "hepsi"):
        bulgu += cmd_sizinta(prod, demo, args, out)
    if args.komut in ("isaret", "hepsi"):
        bulgu += cmd_isaret(prod, args, out, cikti)
    if args.komut in ("koken", "hepsi"):
        bulgu += cmd_koken(prod, out)
    if args.komut in ("statik", "hepsi"):
        cmd_statik(args, out)

    hata = len(prod.errors) + len(demo.errors)
    out["hatalar"] = {"prod": prod.errors, "demo": demo.errors}
    out["hukum"] = (f"HATA: {hata} sorgu koşulamadı" if hata
                    else ("BULGU: " + str(bulgu) if bulgu else "TEMIZ"))
    (cikti / "ozet.json").write_text(json.dumps(out, indent=1, ensure_ascii=False), encoding="utf-8")
    prod.close()
    demo.close()
    print(f"\nÖZET: {cikti / 'ozet.json'}")
    print(f"HÜKÜM: {out['hukum']}")
    return 0


if __name__ == "__main__":
    main()
