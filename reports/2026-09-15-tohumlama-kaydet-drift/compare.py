#!/usr/bin/env python3
"""P3 — 4 gövde karşılaştırması (final, sağlam çıkarım).

Çıkarım: CREATE FUNCTION başlığına demirlemiş $function$ span araması
(P1 verdict.py'nin DO-blok içi statement bölücüsü #5'in kaydet CREATE'ini
arg-listesi ortasından böldüğü için burada KULLANILMADI).

md5 varyantları (ikisi de raporlanır):
  md5_normall : md5(re.sub(r"\\s+","",body).lower())  — P1 diagnose.py varyantı
                (P1 raporu e4ab00a63d / e144cf1f71 bu varyantla üretildi)
  md5_normws  : md5(" ".join(body.split()))           — P1 verdict.py varyantı
"""
import json, re, difflib, pathlib, hashlib

HERE = pathlib.Path(__file__).resolve().parent
MIG = HERE.parents[1] / "supabase" / "migrations"
FNS = ("tohumlama_kaydet", "tohumlama_tekrar_kaydet")
FILE_A = "20260910000002_sperma_eslesme_sertlestirme.sql"
FILE_B = "20260830000034_review_fix_paketi.sql"
FILE_C_TEKRAR = "20260722000004_tohumlama_son_kayit_tarih_siralama.sql"


def norm_all(s):
    return re.sub(r"\s+", "", s or "").lower()


def md5_normall(s):
    return hashlib.md5(norm_all(s).encode()).hexdigest()[:10]


def md5_normws(s):
    return hashlib.md5(" ".join((s or "").split()).encode()).hexdigest()[:10]


def fn_bodies_from_text(txt, source):
    """(fname -> body) — CREATE FUNCTION başlığından sonraki ilk dollar-quote span
    ($function$ / $$ / $body$ ...)."""
    out = {}
    for m in re.finditer(r"create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?(\w+)\s*\(", txt, re.I):
        name = m.group(1).lower()
        sm = re.search(r"\$([A-Za-z_]*)\$(.*?)\$\1\$", txt[m.end():], re.S)
        if sm:
            out.setdefault(name, {"body": sm.group(2), "source": source})
    return out


def bodies_from_file(fname):
    return fn_bodies_from_text((MIG / fname).read_text(encoding="utf-8", errors="replace"), fname)


# ---- 4 kaynak ----
src = {}
src.update({("dosya-a", k): v for k, v in bodies_from_file(FILE_A).items()})
src.update({("dosya-b", k): v for k, v in bodies_from_file(FILE_B).items()})
src[("dosya-c", "tohumlama_tekrar_kaydet")] = bodies_from_file(FILE_C_TEKRAR)["tohumlama_tekrar_kaydet"]
for tag in ("demo", "prod"):
    rows = json.loads((HERE / f"probe_fn_{tag}.json").read_text())
    for r in rows:
        b = re.search(r"\$function\$(.*?)\$function\$", r["fdef"], re.S).group(1)
        src[(f"{tag}-canli", r["name"])] = {"body": b, "source": f"{tag} canlı (pg_get_functiondev)"}

# ---- md5 tablosu ----
print("== MD5 TABLOSU (norm_all = boşluk-sil+küçük-harf; P1 diagnose varyantı) ==")
table = []
for fn in FNS:
    for label in ("dosya-a", "dosya-b", "dosya-c", "demo-canli", "prod-canli"):
        v = src.get((label, fn))
        if not v:
            continue
        row = {"fn": fn, "kaynak": f"{label}:{v['source']}",
               "md5_normall": md5_normall(v["body"]), "md5_normws": md5_normws(v["body"]),
               "len": len(v["body"])}
        table.append(row)
        print(f"  {fn:26s} {row['kaynak'][:70]:72s} md5_all={row['md5_normall']}  md5_ws={row['md5_normws']}  len={row['len']}")
(HERE / "md5_table.json").write_text(json.dumps(table, indent=1, ensure_ascii=False))

# ---- diff'ler ----
diff_dir = HERE / "diffs"
diff_dir.mkdir(exist_ok=True)


def norm_lines(s):
    return [" ".join(l.split()) for l in (s or "").splitlines()]


pairs = [
    ("tohumlama_kaydet", "demo-canli_vs_dosya-a", ("demo-canli", "dosya-a")),
    ("tohumlama_kaydet", "prod-canli_vs_dosya-a", ("prod-canli", "dosya-a")),
    ("tohumlama_kaydet", "demo-canli_vs_prod-canli", ("demo-canli", "prod-canli")),
    ("tohumlama_kaydet", "dosya-b_vs_dosya-a", ("dosya-b", "dosya-a")),
    ("tohumlama_tekrar_kaydet", "demo-canli_vs_dosya-a", ("demo-canli", "dosya-a")),
    ("tohumlama_tekrar_kaydet", "prod-canli_vs_dosya-a", ("prod-canli", "dosya-a")),
    ("tohumlama_tekrar_kaydet", "prod-canli_vs_dosya-c", ("prod-canli", "dosya-c")),
    ("tohumlama_tekrar_kaydet", "demo-canli_vs_prod-canli", ("demo-canli", "prod-canli")),
]
print("\n== DIFF ÖZETİ (boşluk-normalize satır diff) ==")
summary = {}
for fn, label, (lf, rf) in pairs:
    if (lf, fn) not in src or (rf, fn) not in src:
        continue
    d = list(difflib.unified_diff(norm_lines(src[(lf, fn)]["body"]), norm_lines(src[(rf, fn)]["body"]),
                                  fromfile=lf, tofile=rf, lineterm=""))
    ch = sum(1 for l in d if l[:1] in "+-" and l[:3] not in ("+++", "---"))
    summary[f"{fn}::{label}"] = ch
    (diff_dir / f"{fn}__{label}.diff").write_text("\n".join(d) + "\n")
    print(f"  {fn:26s} {label:32s} degisen-satir={ch}")
(HERE / "diff_summary.json").write_text(json.dumps(summary, indent=1))
print("\nmd5_table.json + diff_summary.json + diffs/ yazildi")
