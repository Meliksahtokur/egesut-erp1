#!/usr/bin/env python3
"""P1 ölçüm — inventory × canlı şema karşılaştırması.

CANLI  : dosyadaki (son tanım) nesneler hepsi hedef DB'de var, gövdeler eşleşiyor
EKSİK  : dosyanın yarattığı nesnelerin hiçbiri yok
KISMİ  : arada bir şey
"""
import json, re, pathlib, hashlib

HERE = pathlib.Path(__file__).resolve().parent
MIG = HERE.parents[1] / "supabase" / "migrations"
FILES = sorted(json.loads((HERE / "inventory.json").read_text()).keys())
INV = json.loads((HERE / "inventory.json").read_text())
PROBE = {t: json.loads((HERE / f"probe_{t}.json").read_text()) for t in ("prod", "demo")}

TYPE_ALIAS = {
    "int2": "smallint", "int4": "integer", "int": "integer", "int8": "bigint",
    "bool": "boolean", "varchar": "character varying", "float4": "real",
    "float8": "double precision", "timestamptz": "timestamp with time zone",
    "timetz": "time with time zone",
}


def norm_ws(s):
    return " ".join((s or "").split())


def norm_all(s):
    return re.sub(r"\s+", "", s or "").lower()


def norm_type(t):
    t = norm_ws(t).lower().strip().split(".")[-1]
    return TYPE_ALIAS.get(t, t)


def split_top_commas(s):
    out, depth, cur = [], 0, []
    for ch in s:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            out.append("".join(cur)); cur = []
        else:
            cur.append(ch)
    if "".join(cur).strip():
        out.append("".join(cur))
    return [x.strip() for x in out if x.strip()]


def file_arg_types(args_raw):
    """Dosyadaki args_raw -> tipler listesi (param adı ve DEFAULT atılır)."""
    types = []
    for a in split_top_commas(args_raw):
        a = re.sub(r"\s+DEFAULT\s+.*$", "", a, flags=re.I | re.S)
        a = re.sub(r"^(IN|OUT|INOUT|VARIADIC)\s+", "", a, flags=re.I)
        parts = a.split()
        if not parts:
            continue
        # ilk token param adıysa (tip değil) at: tip olarak bilinen kelimelerden ilki tip başlangıcı
        known = {"text", "date", "uuid", "jsonb", "numeric", "boolean", "integer", "bigint",
                 "smallint", "int", "real", "double", "character", "varying", "timestamp",
                 "timestamptz", "time", "interval", "regclass", "text\\[\\]", "int[]"}
        # dizi tipleri: text[] vs
        if re.match(r"^[a-z_]+(\[\])?$", parts[0]) and (parts[0].lower() in known or parts[0].endswith("[]")):
            types.append(norm_type(parts[0]))
        elif len(parts) >= 2:
            types.append(norm_type(" ".join(parts[1:])))
        else:
            types.append(norm_type(parts[0]))
    return types


def live_arg_types(args):
    """pg_get_function_identity_arguments çıktısı -> tipler (param adı atılır)."""
    types = []
    for a in split_top_commas(args):
        a = re.sub(r"^(IN|OUT|INOUT|VARIADIC)\s+", "", a, flags=re.I)
        # 'p_x character varying' / 'p_x text' / 'jsonb' / 'p_hedef jsonb'
        toks = a.split()
        if len(toks) >= 2 and toks[0].lower().startswith("p_"):
            types.append(norm_type(" ".join(toks[1:])))
        elif len(toks) >= 2 and toks[0].lower() in ("character", "double", "timestamp", "time"):
            types.append(norm_type(" ".join(toks)))
        elif len(toks) == 1:
            types.append(norm_type(toks[0]))
        else:
            # param adı p_ ile başlamıyorsa: bilinen tip sözcüklerinden başlayan ilk konumu bul
            idx = next((i for i, t in enumerate(toks)
                        if t.lower() in TYPE_ALIAS.values() | TYPE_ALIAS.keys()
                        or t.lower() in ("text", "date", "uuid", "jsonb", "numeric", "boolean",
                                         "integer", "bigint", "character", "double", "timestamp",
                                         "time", "interval", "regclass", "smallint", "real")), 0)
            types.append(norm_type(" ".join(toks[idx:])))
    return types


def longest_dollar_span(stmt):
    """Statement'taki en uzun dolar-quote gövdesi (fonksiyon gövdesi)."""
    best = ""
    i = 0
    while i < len(stmt):
        m = re.match(r"\$([A-Za-z_]\w*)?\$", stmt[i:])
        if m and i == 0 or (m and stmt[i - 1] not in ("$",)):
            tag = m.group(0)
            end = stmt.find(tag, i + len(tag))
            if end != -1 and (end - i) > len(best):
                best = stmt[i + len(tag):end]
                i = end + len(tag)
                continue
        i += 1
    return best


from parse_migrations import strip_comments, statements  # noqa: E402


def _find_fn_body(stmts, fname, args_startswith):
    found = None
    for stmt in stmts:
        m = re.match(r"\s*CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+(.+?)\s*\(", stmt, re.I | re.S)
        if m:
            if m.group(1).strip().split(".")[-1].strip('"').lower() != fname.split(".")[-1].strip('"').lower():
                continue
            op = stmt.index("(", m.end(1))
            depth, j = 0, op
            while j < len(stmt):
                if stmt[j] == '(':
                    depth += 1
                elif stmt[j] == ')':
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            if norm_all(stmt[op + 1:j]) != norm_all(args_startswith):
                continue
            found = longest_dollar_span(stmt)  # dosyada son eşleşme esas (drop+create / çift tanım)
            continue
        mdo = re.match(r"\s*DO\s+(\$[A-Za-z_]\w*\$|\$)\s*(.*?)\s*\1\s*;?\s*$", stmt, re.I | re.S)
        if mdo:
            r = _find_fn_body(statements(mdo.group(2)), fname, args_startswith)
            if r is not None:
                found = r
    return found


def file_fn_body(filename, fname, args_startswith):
    """Dosyadaki CREATE FUNCTION statement'ından gövdeyi çıkarır (DO-blokları içine iner)."""
    text = strip_comments((MIG / filename).read_text(encoding="utf-8", errors="replace"))
    return _find_fn_body(statements(text), fname, args_startswith)


def body_md5(s):
    return hashlib.md5(norm_ws(s).encode()).hexdigest()[:10]


# ---- live indeksleri ----
def build_live(tag):
    p = PROBE[tag]
    live = {}
    live["fn"] = {}
    for r in p["functions"]:
        live["fn"].setdefault((r["schema"], r["name"]), []).append(r)
    live["tables"] = {r["name"]: r for r in p["tables"]}
    live["cols"] = {(r["table_name"], r["column_name"]) for r in p["columns"]}
    live["trg"] = {(r["table_name"], r["name"]): r for r in p["triggers"]}
    live["pol"] = {(r["tablename"], r["name"]) for r in p["policies"]}
    live["idx"] = {r["name"]: r for r in p["indexes"]}
    live["con"] = {r["name"]: r for r in p["constraints"]}
    live["views"] = {r["name"] for r in p["views"]}
    live["tg"] = {}
    for r in p["table_grants"]:
        live["tg"].setdefault((r["table_name"], r["grantee"].lower()), set()).add(r["privilege_type"].upper())
    live["rg"] = {}
    for r in p["routine_grants"]:
        live["rg"].setdefault((r["schema"], r["name"], r["grantee"].lower()), set()).add(r["privilege_type"].upper())
    live["other"] = {r["kind"]: r["name"] for r in p["schema_ext"]}
    return live


LIVE = {t: build_live(t) for t in ("prod", "demo")}

# ---- fonksiyon sürümleri (dosya sırasına göre) ----
fn_versions = {}  # (schema,name,typesig) -> [ {file, body, args_raw} ]
for fn in FILES:
    for d in INV[fn]["functions"]:
        schema = "surum_gizli" if d["name"].startswith("surum_gizli.") else "public"
        name = d["name"].split(".")[-1].strip('"').lower()
        types = tuple(file_arg_types(d["args_raw"]))
        fn_versions.setdefault((schema, name, types), []).append(
            {"file": fn, "args_raw": d["args_raw"]})


def fn_match_body(schema, name, types, live_row, tag):
    """live_row gövdesi hangi dosya sürümleriyle eşleşiyor? (ws-collapse eşleşme)"""
    fdef = live_row["fdef"]
    live_body = longest_dollar_span(fdef)
    matches = []
    for v in fn_versions.get((schema, name, types), []):
        fb = file_fn_body(v["file"], name, norm_all(v["args_raw"]))
        v["body_md5"] = body_md5(fb or "")
        if fb and norm_all(live_body) == norm_all(fb):
            matches.append(v["file"])
    return matches, live_body


def check_function(schema, name, types, d, tag):
    """-> (durum, kanıt) durum: OK | MISSING | MISMATCH | SIG_CONFLICT"""
    lv = LIVE[tag]
    rows = lv["fn"].get((schema, name), [])
    if not rows:
        return "MISSING", "yok"
    exact = [r for r in rows if tuple(live_arg_types(r["args"])) == types]
    if not exact:
        sigs = "; ".join(f'({r["args"]})' for r in rows)
        return "SIG_CONFLICT", f"canlı aşırı-yükler: {sigs}"
    r = exact[0]
    matches, _ = fn_match_body(schema, name, types, r, tag)
    versions = fn_versions.get((schema, name, types), [])
    if matches:
        latest = versions[-1]["file"]
        note = f"gövde= {matches[0]} sürümü"
        if len(matches) < len(versions):
            note += f" (son tanım {latest}; prod'da {matches[-1]})"
        return "OK", note
    return "MISMATCH", f"gövde hiçbir dosya sürümüyle eşleşmedi (md5 {body_md5(longest_dollar_span(r['fdef']))}; son tanım {versions[-1]['file']} md5 {versions[-1].get('body_md5','?')})"


def check_grant(g, tag):
    """GRANT/REVOKE kaydını canlı ACL ile karşılaştırır -> (durum, kanıt)"""
    lv = LIVE[tag]
    priv = g["priv"].upper().rstrip(";").strip()
    tos = [t.strip().strip('"').lower().rstrip(";").strip() for t in g["to"].split(",")]
    rev = priv.startswith("REVOKE")
    privs = [p.strip() for p in (priv.replace("REVOKE", "", 1) if rev else priv).replace("ALL", "SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER").split(",") if p.strip()]
    if g["kind"] == "FUNCTION":
        name = g["obj"].split("(")[0].split(".")[-1].strip('"').lower()
        schema = "surum_gizli" if g["obj"].startswith("surum_gizli") else "public"
        out = []
        for role in tos:
            have = lv["rg"].get((schema, name, role), set())
            if rev:
                bad = [p for p in privs if p in have]
                out.append(f"{role}:{'OK-yok' if not bad else 'HÂLÂ VAR:' + ','.join(bad)}")
            else:
                missing = [p for p in privs if p not in have]
                out.append(f"{role}:{'OK' if not missing else 'YOK:' + ','.join(missing)}")
        return ("OK" if all("HÂLÂ" not in o and "YOK" not in o for o in out) else "FAIL"), ", ".join(out)
    if g["kind"] == "TABLE":
        t = g["obj"].split(".")[-1].strip().strip('"').lower()
        out = []
        for role in tos:
            have = lv["tg"].get((t, role), set())
            if rev:
                bad = [p for p in privs if p in have]
                out.append(f"{role}:{'OK-yok' if not bad else 'HÂLÂ VAR:' + ','.join(bad)}")
            else:
                missing = [p for p in privs if p not in have]
                out.append(f"{role}:{'OK' if not missing else 'YOK:' + ','.join(missing)}")
        return ("OK" if all("HÂLÂ" not in o and "YOK" not in o for o in out) else "FAIL"), ", ".join(out)
    return "SKIP", g["obj"]


# recreated-later kümesi (drop sonrası aynı nesne sonraki dosyalarda yeniden yaratılıyorsa drop ölçülemez)
# grant zaman çizelgesi: sonraki dosyanın aynı (obj, rol, ayrıcalık) üzerindeki
# işlemi bu dosyadaki grant'i geçersiz kılar (final-state ölçümü bozmamak için)
GRANT_TL = []
for _i, _fn in enumerate(FILES):
    for _g in INV[_fn]["grants"]:
        _priv = _g["priv"].upper().rstrip(";").strip()
        _rev = _priv.startswith("REVOKE")
        _privs = {p.strip() for p in (_priv.replace("REVOKE", "", 1) if _rev else _priv)
                  .replace("ALL", "SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER").split(",") if p.strip()}
        for _role in [t.strip().strip('"').lower().rstrip(";").strip() for t in _g["to"].split(",")]:
            GRANT_TL.append({"i": _i, "obj": _g["obj"].lower().rstrip(";").strip(),
                             "kind": _g["kind"], "role": _role, "privs": _privs, "rev": _rev})


def grant_superseded(g, fi):
    obj = g["obj"].lower().rstrip(";").strip()
    priv = g["priv"].upper().rstrip(";").strip()
    rev = priv.startswith("REVOKE")
    privs = {p.strip() for p in (priv.replace("REVOKE", "", 1) if rev else priv)
             .replace("ALL", "SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER").split(",") if p.strip()}
    for t in [x.strip().strip('"').lower().rstrip(";").strip() for x in g["to"].split(",")]:
        for e in GRANT_TL:
            if e["i"] > fi and e["obj"] == obj and e["role"] == t and (e["privs"] & privs):
                return e["i"]
    return None


def recreated_later(kind, item, fi):
    for other in FILES[fi + 1:]:
        k = {"FUNCTION": "functions", "TRIGGER": "triggers", "POLICY": "policies",
             "TABLE": "tables", "INDEX": "indexes", "VIEW": "views"}[kind]
        for d in INV[other][k]:
            nm = d.get("name", d.get("table", d.get("view", "")))
            nm = d.get("name") or d.get("view") or ""
            if kind == "TRIGGER" and d.get("name") == item["name"] and d.get("table") == item.get("table"):
                return True
            if kind in ("POLICY",) and d.get("name") == item["name"] and d.get("table") == item.get("table"):
                return True
            if kind in ("FUNCTION", "INDEX", "TABLE", "VIEW"):
                base = nm.split("(")[0].strip().lower()
                if base.endswith(item["name"].split("(")[0].strip().lower()):
                    return True
    return False


def file_report(fn, tag):
    """Tek dosyanın tek DB'deki madde-madde sonucu."""
    v = INV[fn]
    fi = FILES.index(fn)
    items = []  # (kategori, hedef, durum, kanıt)

    # fonksiyonlar — aynı (schema,name,types) tek maddeye düşür (aynı dosyada son tanım)
    seen = {}
    for d in v["functions"]:
        schema = "surum_gizli" if d["name"].startswith("surum_gizli.") else "public"
        name = d["name"].split(".")[-1].strip('"').lower()
        types = tuple(file_arg_types(d["args_raw"]))
        seen[(schema, name, types)] = d  # son tanım kalır
    for (schema, name, types), d in seen.items():
        st, ev = check_function(schema, name, types, d, tag)
        items.append(("fonksiyon", f"{schema}.{name}({','.join(types)})", st, ev))

    for t in v["tables"]:
        ok = t["table"] in LIVE[tag]["tables"]
        items.append(("tablo", t["table"], "OK" if ok else "MISSING", "var" if ok else "yok"))
    for t in v["columns"]:
        ok = (t["table"], t["column"]) in LIVE[tag]["cols"]
        items.append(("kolon", f"{t['table']}.{t['column']}", "OK" if ok else "MISSING", "var" if ok else "yok"))
    for t in v["drop_columns"]:
        ok = (t["table"], t["column"]) in LIVE[tag]["cols"]
        items.append(("kolon-düş", f"{t['table']}.{t['column']}", "OK" if not ok else "HÂLÂ VAR", "düşürüldü" if not ok else "hâlâ var"))
    for t in v["triggers"]:
        ok = (t["table"], t["name"]) in LIVE[tag]["trg"]
        items.append(("trigger", f"{t['name']} ON {t['table']}", "OK" if ok else "MISSING", "var" if ok else "yok"))
    for t in v["policies"]:
        ok = (t["table"], t["name"]) in LIVE[tag]["pol"]
        items.append(("policy", f"{t['name']} ON {t['table']}", "OK" if ok else "MISSING", "var" if ok else "yok"))
    for t in v["indexes"]:
        ok = t["name"] in LIVE[tag]["idx"]
        items.append(("index", t["name"], "OK" if ok else "MISSING", "var" if ok else "yok"))
    for t in v["constraints"]:
        ok = t["name"] in LIVE[tag]["con"]
        items.append(("constraint", t["name"], "OK" if ok else "MISSING", "var" if ok else "yok"))
    for t in v["views"]:
        ok = t["view"] in LIVE[tag]["views"]
        items.append(("view", t["view"], "OK" if ok else "MISSING", "var" if ok else "yok"))
    for t in v["rls"]:
        row = LIVE[tag]["tables"].get(t["table"])
        enabled = bool(row and row["rls"])
        want = t["op"] == "ENABLE"
        items.append(("rls", t["table"], "OK" if enabled == want else "FAIL",
                      f"relrowsecurity={enabled}"))
    for g in v["grants"]:
        sup = grant_superseded(g, fi)
        if sup is not None:
            items.append(("grant", f'{g["priv"]} ON {g["obj"]} TO {g["to"]}', "ARA-DURUM",
                          f"sonraki dosya değiştirdi: {FILES[sup]}"))
            continue
        st, ev = check_grant(g, tag)
        items.append(("grant", f'{g["priv"]} ON {g["obj"]} TO {g["to"]}', st, ev))
    same_file_fns = {(d["name"].split(".")[-1].strip('"').lower(), tuple(file_arg_types(d["args_raw"])))
                     for d in v["functions"]}
    for t in v["drops"]:
        drop_base = t["name"].split("(")[0].split(".")[-1].strip().lower() if t["kind"] == "FUNCTION" else None
        drop_types = None
        if t["kind"] == "FUNCTION" and "(" in t["name"]:
            argpart = t["name"][t["name"].index("(") + 1:t["name"].rindex(")")]
            drop_types = tuple(file_arg_types(argpart))
        recreated = (recreated_later(t["kind"], t, fi)
                     and not (drop_base and (drop_base, drop_types) in same_file_fns))
        same_recreate = ((drop_base and (drop_base, drop_types) in same_file_fns)
                         or (t["name"], t.get("table")) in {(d["name"], d.get("table"))
                                                            for d in v["triggers"] + v["policies"]})
        if recreated or same_recreate:
            items.append(("drop", f'{t["kind"]} {t["name"]}', "ARA-DURUM", "sonraki dosyada yeniden yaratıldı"))
            continue
        if t["kind"] == "FUNCTION":
            base = t["name"].split("(")[0].split(".")[-1].strip().lower()
            schema = "surum_gizli" if t["name"].startswith("surum_gizli") else "public"
            rows = LIVE[tag]["fn"].get((schema, base), [])
            argpart = t["name"][t["name"].index("(") + 1:t["name"].rindex(")")] if "(" in t["name"] else ""
            want_types = tuple(file_arg_types(argpart)) if argpart else None
            if want_types is not None:
                present = any(tuple(live_arg_types(r["args"])) == want_types for r in rows)
            else:
                present = bool(rows)
            items.append(("drop", f"FN {t['name']}", "OK-yok" if not present else "HÂLÂ VAR",
                          "düşürülmüş" if not present else "hâlâ mevcut"))
        elif t["kind"] in ("TRIGGER", "POLICY"):
            ok = (t.get("table"), t["name"]) in (LIVE[tag]["trg"] if t["kind"] == "TRIGGER" else LIVE[tag]["pol"])
            items.append(("drop", f'{t["kind"]} {t["name"]} ON {t.get("table")}', "OK-yok" if not ok else "HÂLÂ VAR",
                          "düşürülmüş" if not ok else "hâlâ var"))
        elif t["kind"] == "INDEX":
            ok = t["name"] in LIVE[tag]["idx"]
            items.append(("drop", f'INDEX {t["name"]}', "OK-yok" if not ok else "HÂLÂ VAR",
                          "düşürülmüş" if not ok else "hâlâ var"))
        else:
            items.append(("drop", f'{t["kind"]} {t["name"]}', "SKIP", "elle kontrol"))
    for t in v["dml"]:
        items.append(("dml", f'{t["kind"]} {t["target"]}', "VERİ", "veri-düzeyi spot-check ayrı"))

    # dosya durumu: SKIP/ARA-DURUM/VERİ hariç; dml maddeleri dosya durumuna etki etmez (ayrı raporlanır)
    core = [i for i in items if i[2] not in ("SKIP", "ARA-DURUM", "VERİ")]
    if not core:
        verdict = "N/A"
    elif all(i[2] in ("OK", "OK-yok") for i in core):
        verdict = "CANLI"
    elif all(i[2] in ("MISSING",) for i in core):
        verdict = "EKSİK"
    else:
        verdict = "KISMİ"
    return verdict, items


if __name__ == "__main__":
    out = {}
    for fn in FILES:
        out[fn] = {t: file_report(fn, t) for t in ("prod", "demo")}
    (HERE / "verdicts.json").write_text(json.dumps(out, indent=1, ensure_ascii=False))
    for fn in FILES:
        pr, dm = out[fn]["prod"][0], out[fn]["demo"][0]
        flag = "" if pr == dm else "  <-- FARK"
        print(f"{fn}  prod={pr:6s} demo={dm}{flag}")
