#!/usr/bin/env python3
"""P5 — Y (13:52 ara yedek) ↔ C (canlı prod dökümü) karşılaştırması.

Girdiler (repo dışı, ikisi de salt okunur okunur):
  Y = /home/melik/tmp/agents/prod-yedek-2026-09-15
  C = /home/melik/tmp/agents/github-yedek-2026-09-15/live_c

Çıktılar (kanıt dizini; yalnız AD + SAYI + md5 + saat aralığı — satır verisi YOK):
  schema_diff.json, data_counts.json, hour_hist.json, migration_map.json

Yöntem: P3 compare.py md5_normall = md5(re.sub(r"\\s+","",s).lower())[:10];
fonksiyon gövdeleri fdef içinden $function$ span'i ile çıkarılır.
"""
import json, re, pathlib, hashlib, datetime, collections

HERE = pathlib.Path(__file__).resolve().parent
Y = pathlib.Path("/home/melik/tmp/agents/prod-yedek-2026-09-15")
C = pathlib.Path("/home/melik/tmp/agents/github-yedek-2026-09-15/live_c")
REPO = HERE.parents[1]          # repo kökü (worktree)
MIG = REPO / "supabase" / "migrations"


def norm_all(s):
    return re.sub(r"\s+", "", s or "").lower()


def md5_normall(s):
    return hashlib.md5(norm_all(s).encode()).hexdigest()[:10]


def md5_json(x):
    return md5_normall(json.dumps(x, sort_keys=True, ensure_ascii=False, default=str))


def span_body(fdef):
    m = re.search(r"\$function\$(.*?)\$function\$", fdef or "", re.S)
    return m.group(1) if m else (fdef or "")


def load(side, name):
    p = (Y if side == "Y" else C) / f"{name}.json"
    if not p.exists():
        return None
    return json.loads(p.read_text())


# ---------- 1. Migration haritası (nesne adı → dosya) ----------
mig_map = collections.defaultdict(set)
for f in sorted(MIG.glob("*.sql")):
    txt = f.read_text(encoding="utf-8", errors="replace")
    for m in re.finditer(r"create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?(\w+)", txt, re.I):
        mig_map[f"fn:{m.group(1).lower()}"].add(f.name)
    for m in re.finditer(r"create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?(\w+)", txt, re.I):
        mig_map[f"tbl:{m.group(1).lower()}"].add(f.name)
    for m in re.finditer(r"create\s+(?:or\s+replace\s+)?trigger\s+(\w+)\s+on\s+(?:public\.)?(\w+)", txt, re.I):
        mig_map[f"trg:{m.group(1).lower()}@{m.group(2).lower()}"].add(f.name)
    for m in re.finditer(r"create\s+policy\s+([\"\w\s]+?)\s+on\s+(?:public\.)?(\w+)", txt, re.I):
        mig_map[f"pol:{m.group(1).strip('\"').lower()}@{m.group(2).lower()}"].add(f.name)
    for m in re.finditer(r"create\s+(?:unique\s+)?index\s+(?:if\s+not\s+exists\s+)?([\w]+)\s+on\s+(?:public\.)?(\w+)", txt, re.I):
        mig_map[f"idx:{m.group(1).lower()}@{m.group(2).lower()}"].add(f.name)
    for m in re.finditer(r"alter\s+table\s+(?:if\s+exists\s+)?(?:public\.)?(\w+)\s+(?:add\s+column\s+)?(?:if\s+not\s+exists\s+)?(\w+)", txt, re.I):
        mig_map[f"col:{m.group(2).lower()}@{m.group(1).lower()}"].add(f.name)


def map_names(kind, *parts):
    key = f"{kind}:" + "@".join(p.lower() for p in parts)
    return sorted(mig_map.get(key, []))


# ---------- 2. Şema karşılaştırması ----------
schema_diff = {}


def setdiff(kind, keyY, keyC):
    ky = set(keyY) - set(keyC)
    kc = set(keyC) - set(keyY)
    schema_diff[kind] = {
        "sadece_Y": sorted(ky), "sadece_C": sorted(kc),
        "sadece_Y_sayi": len(ky), "sadece_C_sayi": len(kc),
    }
    return ky, kc


# fonksiyonlar: ad+argüman → md5(gövde) (+ imza alanları)
fy = load("Y", "functions") or []
fc = load("C", "functions") or []
dy, dc = {}, {}
for side, rows, dst in (("Y", fy, dy), ("C", fc, dc)):
    for r in rows:
        k = (r["schema"], r["name"], " ".join(r["args"].split()))
        dst[k] = {
            "body_md5": md5_normall(span_body(r.get("fdef"))),
            "ret": " ".join((r.get("ret") or "").split()),
            "secdef": r.get("secdef"),
            "fdef_md5": md5_normall(r.get("fdef") or ""),
        }
common_f = set(dy) & set(dc)
setdiff("fonksiyonlar", {f"{s}.{n}({a})" for s, n, a in dy}, {f"{s}.{n}({a})" for s, n, a in dc})
schema_diff["fonksiyonlar"]["gövde_farklı_ortak"] = sorted(
    (f"{s}.{n}({a})", dy[k]["body_md5"], dc[k]["body_md5"])
    for k in common_f if dy[k]["body_md5"] != dc[k]["body_md5"]
    for s, n, a in [k])
schema_diff["fonksiyonlar"]["gövde_farklı_sayi"] = len(schema_diff["fonksiyonlar"]["gövde_farklı_ortak"])
# yeni fonksiyonlara migration eşleme
schema_diff["fonksiyonlar"]["sadece_C_migration"] = {
    name: map_names("fn", re.search(r"\.(\w+)\(", name).group(1))
    for name in schema_diff["fonksiyonlar"]["sadece_C"]}
schema_diff["fonksiyonlar"]["gövde_farklı_migration"] = {
    name: map_names("fn", re.search(r"\.(\w+)\(", name).group(1))
    for name, *_ in schema_diff["fonksiyonlar"]["gövde_farklı_ortak"]}

# tablolar (tablolar dolaylı: table_*.json dosyaları + columns kümeleri)
tabY = {p.stem.removeprefix("table_") for p in Y.glob("table_*.json")}
tabC = {p.stem.removeprefix("table_") for p in C.glob("table_*.json")}
setdiff("tablolar", sorted(tabY), sorted(tabC))
schema_diff["tablolar"]["sadece_C_migration"] = {
    t: map_names("tbl", t) for t in schema_diff["tablolar"]["sadece_C"]}

# kolonlar: tablo@kolon → (data_type, is_nullable, default_norm)
def col_index(side):
    rows = load(side, "columns") or []
    return {(r["table_name"], r["column_name"]):
            (r["data_type"], r["is_nullable"],
             " ".join((r.get("column_default") or "").split())) for r in rows}
coly, colc = col_index("Y"), col_index("C")
setdiff("kolonlar", {f"{t}@{c}" for t, c in coly}, {f"{t}@{c}" for t, c in colc})
schema_diff["kolonlar"]["öznitelik_farklı"] = sorted(
    f"{t}@{c} Y={coly[(t, c)]} C={colc[(t, c)]}"
    for (t, c) in set(coly) & set(colc) if coly[(t, c)] != colc[(t, c)])
schema_diff["kolonlar"]["öznitelik_farklı_sayi"] = len(schema_diff["kolonlar"]["öznitelik_farklı"])
schema_diff["kolonlar"]["sadece_C_migration"] = {
    k: map_names("col", k.split("@")[1], k.split("@")[0])
    for k in schema_diff["kolonlar"]["sadece_C"]}

# trigger'lar
def tri_index(side):
    rows = load(side, "triggers") or []
    return {(r["schema"], r["table_name"], r["name"]): md5_normall(r["tdef"]) for r in rows}
try_, tric = tri_index("Y"), tri_index("C")
setdiff("triggerlar", {f"{s}.{t}.{n}" for s, t, n in try_}, {f"{s}.{t}.{n}" for s, t, n in tric})
schema_diff["triggerlar"]["gövde_farklı"] = sorted(
    f"{s}.{t}.{n}" for (s, t, n) in set(try_) & set(tric) if try_[(s, t, n)] != tric[(s, t, n)])
schema_diff["triggerlar"]["sadece_C_migration"] = {
    k: map_names("trg", k.split(".")[2], k.split(".")[1])
    for k in schema_diff["triggerlar"]["sadece_C"]}

# policy'ler
def pol_index(side):
    rows = load(side, "policies") or []
    return {(r["schemaname"], r["tablename"], r["policyname"]): md5_json(r) for r in rows}
poly, polc = pol_index("Y"), pol_index("C")
setdiff("policyler", {f"{s}.{t}.{n}" for s, t, n in poly}, {f"{s}.{t}.{n}" for s, t, n in polc})
schema_diff["policyler"]["gövde_farklı"] = sorted(
    f"{s}.{t}.{n}" for (s, t, n) in set(poly) & set(polc) if poly[(s, t, n)] != polc[(s, t, n)])

# grant'ler
def grant_index(side, name, keyf):
    rows = load(side, name) or []
    return {keyf(r): md5_json(r) for r in rows}
gy = grant_index("Y", "grants_table", lambda r: (r["table_schema"], r["table_name"], r["grantee"], r["privilege_type"]))
gc = grant_index("C", "grants_table", lambda r: (r["table_schema"], r["table_name"], r["grantee"], r["privilege_type"]))
setdiff("grant_tablo", sorted(gy), sorted(gc))
ry = grant_index("Y", "grants_routine", lambda r: (r["routine_schema"], r["routine_name"], r["grantee"], r["privilege_type"]))
rc = grant_index("C", "grants_routine", lambda r: (r["routine_schema"], r["routine_name"], r["grantee"], r["privilege_type"]))
setdiff("grant_routine", sorted(ry), sorted(rc))

# index'ler
def idx_index(side):
    rows = load(side, "indexes") or []
    return {(r["schemaname"], r["tablename"], r["indexname"]): md5_normall(r["indexdef"]) for r in rows}
idxy, idxc = idx_index("Y"), idx_index("C")
setdiff("indexler", {f"{s}.{t}.{n}" for s, t, n in idxy}, {f"{s}.{t}.{n}" for s, t, n in idxc})
schema_diff["indexler"]["gövde_farklı"] = sorted(
    f"{s}.{t}.{n}" for (s, t, n) in set(idxy) & set(idxc) if idxy[(s, t, n)] != idxc[(s, t, n)])
schema_diff["indexler"]["sadece_C_migration"] = {
    k: map_names("idx", k.split(".")[2], k.split(".")[1])
    for k in schema_diff["indexler"]["sadece_C"]}

# constraint'ler
def con_index(side):
    rows = load(side, "constraints") or []
    return {(r["schema"], r["tbl"], r["name"]): (r["contype"], md5_normall(r["cdef"])) for r in rows}
cony, conc = con_index("Y"), con_index("C")
setdiff("constraintler", {f"{s}.{t}.{n}" for s, t, n in cony}, {f"{s}.{t}.{n}" for s, t, n in conc})
schema_diff["constraintler"]["gövde_farklı"] = sorted(
    f"{s}.{t}.{n}" for (s, t, n) in set(cony) & set(conc) if cony[(s, t, n)] != conc[(s, t, n)])

# view + extension
vy = {f"{r['schemaname']}.{r['viewname']}": md5_normall(r["definition"]) for r in (load("Y", "views") or [])}
vc = {f"{r['schemaname']}.{r['viewname']}": md5_normall(r["definition"]) for r in (load("C", "views") or [])}
setdiff("viewler", sorted(vy), sorted(vc))
schema_diff["viewler"]["gövde_farklı"] = sorted(k for k in set(vy) & set(vc) if vy[k] != vc[k])
ey = {r["extname"]: r["extversion"] for r in (load("Y", "extensions") or [])}
ec = {r["extname"]: r["extversion"] for r in (load("C", "extensions") or [])}
setdiff("extensionlar", sorted(ey), sorted(ec))
schema_diff["extensionlar"]["sürüm_farklı"] = sorted(k for k in set(ey) & set(ec) if ey[k] != ec[k])

# ---------- 3. Veri karşılaştırması (PK bazlı) ----------
consY = {r["tbl"].split(".")[-1]: r["cdef"] for r in (load("Y", "constraints") or []) if r["contype"] == "p"}
consC = {r["tbl"].split(".")[-1]: r["cdef"] for r in (load("C", "constraints") or []) if r["contype"] == "p"}


def pk_cols(tbl, cdef):
    m = re.search(r"PRIMARY\s+KEY\s*\(([^)]+)\)", cdef or "")
    if not m:
        return []
    return [c.strip().strip('"') for c in m.group(1).split(",")]


data_counts, no_pk, hour_hist = {}, {}, {}
for tbl in sorted(tabY | tabC):
    py_, pc_ = Y / f"table_{tbl}.json", C / f"table_{tbl}.json"
    ry = json.loads(py_.read_text())["data"] if py_.exists() else []
    rc = json.loads(pc_.read_text())["data"] if pc_.exists() else []
    cdef = consC.get(tbl) or consY.get(tbl)
    pks = pk_cols(tbl, cdef)
    rec = {"Y": len(ry), "C": len(rc), "diff": len(rc) - len(ry)}
    if pks:
        iy = {tuple(str(r.get(c)) for c in pks): r for r in ry}
        ic = {tuple(str(r.get(c)) for c in pks): r for r in rc}
        eklenen = set(ic) - set(iy)
        silinen = set(iy) - set(ic)
        # ortak kolon kümesi: iki tarafta da var olan kolonlara bak (yeni kolon
        # eklenmesi "değişim" sayılmasın); yalnız yeni-kolon dolgusu ayrı sayılır
        common_cols = (set(ry[0].keys()) & set(rc[0].keys())) if ry and rc else set()
        new_cols = (set(rc[0].keys()) - set(ry[0].keys())) if ry and rc else set()
        degisen = 0
        sadece_yeni_kolon = 0
        for k in set(iy) & set(ic):
            d_ortak = [c for c in common_cols if md5_json(iy[k].get(c)) != md5_json(ic[k].get(c))]
            if d_ortak:
                degisen += 1
            elif any(md5_json(iy[k].get(c)) != md5_json(ic[k].get(c)) for c in new_cols):
                sadece_yeni_kolon += 1
        rec.update({"pk": pks, "eklenen": len(eklenen), "silinen": len(silinen),
                    "degisen": degisen, "yalniz_yeni_kolon": sadece_yeni_kolon})
        # saat dağılımı: bilinen zaman kolonlarında (yalnız sayım)
        for side, rows in (("Y", ry), ("C", rc)):
            for tcol in ("tarih", "created_at", "kayit_zamani", "timestamp"):
                if rows and tcol in rows[0]:
                    cnt = collections.Counter()
                    for r in rows:
                        v = str(r.get(tcol) or "")
                        mm = re.match(r"(\d{4}-\d{2}-\d{2})T(\d{2})", v)
                        if mm:
                            cnt[f"{mm.group(1)} {mm.group(2)}:00Z"] += 1
                    if cnt:
                        hour_hist.setdefault(tbl, {}).setdefault(side, {tcol: cnt.most_common()})[tcol] = cnt.most_common()
                    break
    else:
        no_pk[tbl] = rec
        continue
    data_counts[tbl] = rec

(HERE / "schema_diff.json").write_text(json.dumps(schema_diff, ensure_ascii=False, indent=1))
(HERE / "data_counts.json").write_text(json.dumps({"tables": data_counts, "no_pk": no_pk}, ensure_ascii=False, indent=1))
(HERE / "hour_hist.json").write_text(json.dumps(hour_hist, ensure_ascii=False, indent=1))
(HERE / "migration_map.json").write_text(json.dumps({k: sorted(v) for k, v in sorted(mig_map.items())}, ensure_ascii=False, indent=1))

# ---- özet konsol ----
print("== ŞEMA ÖZETİ Y↔C ==")
for kind, d in schema_diff.items():
    if d.get("sadece_Y_sayi") or d.get("sadece_C_sayi"):
        print(f"  {kind}: sadece_Y={d.get('sadece_Y_sayi')} sadece_C={d.get('sadece_C_sayi')}")
    for extra in ("gövde_farklı_sayi", "öznitelik_farklı_sayi"):
        if d.get(extra):
            print(f"  {kind}: {extra}={d[extra]}")
    if d.get("sürüm_farklı"):
        print(f"  {kind}: sürüm_farklı={d['sürüm_farklı']}")
print("== VERİ ÖZETİ Y↔C (farkı olan tablolar) ==")
for t, r in data_counts.items():
    if r.get("eklenen") or r.get("silinen") or r.get("degisen"):
        print(f"  {t}: Y={r['Y']} C={r['C']} ekl={r['eklenen']} sil={r['silinen']} deg={r['degisen']}")
print("\nÇıktılar yazıldı:", [p.name for p in HERE.glob('*.json')])
