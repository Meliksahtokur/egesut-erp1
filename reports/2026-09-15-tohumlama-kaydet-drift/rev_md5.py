#!/usr/bin/env python3
"""#5 dosyasının git revizyonlarındaki gövde md5'leri (norm_all varyantı,
P1 diagnose ile karşılaştırılabilir)."""
import re, hashlib, subprocess, sys, json, pathlib


def norm_all(s):
    return re.sub(r"\s+", "", s or "").lower()


def md5n(s):
    return hashlib.md5(norm_all(s).encode()).hexdigest()[:10]


def spans(t):
    # $function$ etiketi hem ilk commit'te (47c1ecd) hem bugünkü DO-blok sargılı
    # sürümde kullanılıyor; $do$ dış sargısı genel deseni yuttuğu için özel desen.
    return re.findall(r"\$function\$(.*?)\$function\$", t, re.S)


out = {}
for c in sys.argv[1:]:
    r = subprocess.run(["git", "show", f"{c}:supabase/migrations/20260910000002_sperma_eslesme_sertlestirme.sql"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        out[c] = {"hata": r.stderr[:120]}
        continue
    sp = spans(r.stdout)
    # hangi span hangi fonksiyon: her span'dan ÖNCEKİ CREATE FUNCTION başlığını bul
    labeled = {}
    for body in sp:
        idx = r.stdout.find("$function$" + body)
        head = re.findall(r"create\s+(?:or\s+replace\s+)?function\s+(?:public\.)?(\w+)\s*\(",
                          r.stdout[:idx], re.I)
        labeled[head[-1].lower() if head else f"span@{idx}"] = md5n(body)
    out[c] = labeled
print(json.dumps(out, indent=1))
pathlib.Path(__file__).resolve().parent.joinpath("revizyonlar.json").write_text(json.dumps(out, indent=1))
