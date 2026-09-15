#!/usr/bin/env python3
"""P4 ön kontrol (SALT OKUNUR — her istek BEGIN READ ONLY; ... ROLLBACK;).

1) fn_sperma_stok_dus prod'da VAR mı, tek overload mı (M1 ön koşulu).
2) tohumlama_kaydet / tohumlama_tekrar_kaydet canlı gövde md5 (P3 compare.py
   md5_normall varyantı: boşluk-sil + küçük-harf, ilk 10 hex).
   Beklenen (P3 raporu §2): kaydet=e144cf1f71, tekrar=64dc7fc09a  — eski sürüm.
3) prosecdef + proacl ön değerlerini yakala (uygulama sonrası karşılaştırma için).
4) overload sayıları.

md5 beklenenden farklıysa exit 2 (zarf: DUR ve sor). Token hiçbir çıktıya yazılmaz.
"""
import json, re, hashlib, pathlib, subprocess, sys, datetime

HERE = pathlib.Path(__file__).resolve().parent
PROD_REF = "zqnexqbdfvbhlxzelzju"
TOK = re.search(r"^SUPABASE_MANAGEMENT_TOKEN=(.*)$",
                pathlib.Path("/home/melik/tools-bank/.env").read_text(), re.M).group(1).strip()

EXPECTED_OLD = {"tohumlama_kaydet": "e144cf1f71", "tohumlama_tekrar_kaydet": "64dc7fc09a"}
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


rows = run_sql(f"BEGIN READ ONLY; {SQL} ROLLBACK;")
(HERE / "precheck_prod.json").write_text(json.dumps(rows, indent=1, ensure_ascii=False))

out = {"measured_at": datetime.datetime.now().astimezone().isoformat(),
       "prod_ref": PROD_REF, "wrap": "BEGIN READ ONLY; ... ROLLBACK;", "fns": {}}
bad = []
for name in FN_NAMES:
    rs = [r for r in rows if r["name"] == name]
    rec = {"overload_count": len(rs), "variants": []}
    for r in rs:
        body = None
        if r["fdef"]:
            m = re.search(r"\$function\$(.*?)\$function\$", r["fdef"], re.S)
            body = m.group(1) if m else None
        rec["variants"].append({
            "args": r["args"], "ret": r["ret"], "nargs": r["nargs"],
            "secdef": r["secdef"], "vol": r["vol"], "owner": r["owner"],
            "proacl": r["proacl"],
            "md5_normall": md5_normall(body), "body_len": len(body or ""),
            "fdef_len": len(r["fdef"] or ""),
        })
    out["fns"][name] = rec
    print(f"{name}: overload={rec['overload_count']}")
    for v in rec["variants"]:
        print(f"   ({v['args']}) -> {v['ret']} secdef={v['secdef']} vol={v['vol']} "
              f"proacl={v['proacl']} md5={v['md5_normall']} len={v['body_len']}")

# --- kapılar ---
stk = out["fns"].get("fn_sperma_stok_dus", {"overload_count": 0, "variants": []})
if stk["overload_count"] != 1:
    bad.append(f"fn_sperma_stok_dus overload sayisi {stk['overload_count']} (beklenen 1, M1 on kosulu)")
else:
    print(f"[OK] fn_sperma_stok_dus(text,text) VAR, tek overload — imza: ({stk['variants'][0]['args']})")

for name in FN_NAMES[:2]:
    rec = out["fns"][name]
    if rec["overload_count"] != 1:
        bad.append(f"{name} overload sayisi {rec['overload_count']} (beklenen 1)")
    v = rec["variants"][0]
    exp = EXPECTED_OLD[name]
    if v["md5_normall"] != exp:
        bad.append(f"{name} canli md5 {v['md5_normall']} != beklenen-eski {exp} (P3 §2)")
    else:
        print(f"[OK] {name} canli md5 {v['md5_normall']} = beklenen-eski (prod hâlâ eski sürüm)")

(HERE / "precheck_summary.json").write_text(json.dumps(out, indent=1, ensure_ascii=False))
if bad:
    print("\nDUR — zarf geregi:")
    for b in bad:
        print("  -", b)
    sys.exit(2)
print("\nÖN KONTROL TAMAM — uygulama ön koşulları sağlı.")
