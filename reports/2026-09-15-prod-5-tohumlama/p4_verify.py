#!/usr/bin/env python3
"""P4 doğrulama (SALT OKUNUR — her istek BEGIN READ ONLY; ... ROLLBACK;).

Zarf (P4 §3):
1) prod tohumlama_kaydet md5_normall = e4ab00a63d, tohumlama_tekrar_kaydet = 83fe917252
   (P3 compare.py yöntemi; demo ile birebir)
2) iki fonksiyonun overload sayısı 1; secdef + proacl uygulama öncesiyle aynı
   (p4_precheck.py çıktısıyla karşılaştırma)
3) fn_sperma_stok_dus hâlâ tek overload
4) tablo satır sayıları yedekle aynı (manifest.json backup_rows)
5) tohumlama_kaydet/tekrar çağrısı YAPILMAZ — yalnız pg_proc/pg_class okuması.
"""
import json, re, hashlib, pathlib, subprocess, sys, datetime

HERE = pathlib.Path(__file__).resolve().parent
PROD_REF = "zqnexqbdfvbhlxzelzju"
OUT_BACKUP = pathlib.Path("/home/melik/tmp/agents/prod-yedek-2026-09-15-p4")

TOK = re.search(r"^SUPABASE_MANAGEMENT_TOKEN=(.*)$",
                pathlib.Path("/home/melik/tools-bank/.env").read_text(), re.M).group(1).strip()

EXPECTED_POST = {"tohumlama_kaydet": "e4ab00a63d", "tohumlama_tekrar_kaydet": "83fe917252"}
FN_NAMES = ["tohumlama_kaydet", "tohumlama_tekrar_kaydet", "fn_sperma_stok_dus"]

SQL = f"""SELECT n.nspname AS schema, p.proname AS name,
       pg_get_function_identity_arguments(p.oid) AS args,
       pg_get_function_result(p.oid) AS ret,
       p.pronargs AS nargs,
       p.prosecdef AS secdef, p.provolatile AS vol,
       p.proowner::regrole::text AS owner,
       p.proacl::text AS proacl,
       pg_get_functiondef(p.oid) AS fdef
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = ANY(ARRAY[{','.join(repr(n) for n in FN_NAMES)}])
ORDER BY p.proname, 3;"""


def run_sql(wrapped):
    body = json.dumps({"query": wrapped})
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


# ---- 1-3: fonksiyon durumu ----
rows = run_sql(f"BEGIN READ ONLY; {SQL} ROLLBACK;")
(HERE / "verify_prod_fns.json").write_text(json.dumps(rows, indent=1, ensure_ascii=False))

pre = json.loads((HERE / "precheck_summary.json").read_text())

out = {"measured_at": datetime.datetime.now().astimezone().isoformat(),
       "prod_ref": PROD_REF, "wrap": "BEGIN READ ONLY; ... ROLLBACK;", "fns": {}}
bad, oks = [], []

for name in FN_NAMES:
    rs = [r for r in rows if r["name"] == name]
    rec = {"overload_count": len(rs), "variants": []}
    for r in rs:
        body_txt = None
        if r["fdef"]:
            m = re.search(r"\$function\$(.*?)\$function\$", r["fdef"], re.S)
            body_txt = m.group(1) if m else None
        rec["variants"].append({
            "args": r["args"], "ret": r["ret"], "nargs": r["nargs"],
            "secdef": r["secdef"], "vol": r["vol"], "owner": r["owner"],
            "proacl": r["proacl"],
            "md5_normall": md5_normall(body_txt), "body_len": len(body_txt or ""),
        })
    out["fns"][name] = rec

# --- kapı 1: md5 = #5 (demo birebir) ---
for name in FN_NAMES[:2]:
    rec = out["fns"][name]
    v = rec["variants"][0] if rec["overload_count"] == 1 else None
    if v is None:
        bad.append(f"{name} overload sayisi {rec['overload_count']} (beklenen 1)")
        continue
    if v["md5_normall"] != EXPECTED_POST[name]:
        bad.append(f"{name} md5 {v['md5_normall']} != beklenen-yeni {EXPECTED_POST[name]}")
    else:
        oks.append(f"{name} md5_normall = {v['md5_normall']} = #5/demo (birebir)")

# --- kapı 2: overload=1, secdef + proacl öncesiyle aynı ---
for name in FN_NAMES:
    now = out["fns"][name]
    was = pre["fns"].get(name)
    if not was or now["overload_count"] != was["overload_count"]:
        bad.append(f"{name} overload sayısı değişti: önce={was and was['overload_count']} şimdi={now['overload_count']}")
        continue
    if name == "fn_sperma_stok_dus":
        oks.append(f"fn_sperma_stok_dus hâlâ tek overload")
        continue
    a, b = was["variants"][0], now["variants"][0]
    if a["secdef"] != b["secdef"]:
        bad.append(f"{name} secdef değişti: {a['secdef']} -> {b['secdef']}")
    elif a["proacl"] != b["proacl"]:
        bad.append(f"{name} proacl değişti:\n  önce: {a['proacl']}\n  şimdi: {b['proacl']}")
    else:
        oks.append(f"{name}: secdef={b['secdef']}, proacl uygulama öncesiyle birebir ({b['proacl']})")

# --- kapı 4: tablo satır sayıları yedekle aynı ---
manifest = json.loads((OUT_BACKUP / "manifest.json").read_text())
tab_rows = {k: v["backup_rows"] for k, v in manifest["tables"].items()}
live = {}
for t in sorted(tab_rows):
    n = run_sql(f"BEGIN READ ONLY; SELECT count(*) AS n FROM public.\"{t}\"; ROLLBACK;")
    live[t] = n[0]["n"]
(HERE / "verify_table_counts.json").write_text(json.dumps(
    [{"table": k, "backup": tab_rows[k], "live_after": live.get(k)} for k in sorted(tab_rows)],
    indent=1, ensure_ascii=False))
drift = [f"{k}: yedek={tab_rows[k]} canlı={live.get(k)}" for k in sorted(tab_rows)
         if live.get(k) != tab_rows[k]]
if drift:
    bad.append("Tablo satır sayıları yedekten saptı:\n  - " + "\n  - ".join(drift))
else:
    oks.append(f"Tablo satır sayıları yedekle birebir ({len(tab_rows)} tablo, tanım değişikliği veri değiştirmedi)")

(HERE / "verify_summary.json").write_text(json.dumps(out, indent=1, ensure_ascii=False))

print("== DOĞRULAMA ==")
for o in oks:
    print("  [OK]", o)
if bad:
    print("\nDUR — doğrulama başarısız (zarf §3):")
    for b in bad:
        print("  -", b)
    sys.exit(2)
print("\nDOĞRULAMA TAMAM — #5 prod'da CANLI, tüm kapılar yeşil.")
