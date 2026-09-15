#!/usr/bin/env python3
"""P1 devam — 36-dışı sürüm teşhisi (YEREL; yeni DB sorgusu yok).

Prod/demo'da gövdesi 36 dosyadaki hiçbir sürümle eşleşmeyen fonksiyonların,
TÜM migration geçmişindeki hangi tanımla eşleştiğini bulur.
Ayrıca: demo grant teyitleri + demo trg_degisim_log eksik tabloları.

Çıktı: diagnosis.json + konsol özeti
"""
import json, re, pathlib, hashlib

HERE = pathlib.Path(__file__).resolve().parent
MIG = HERE.parents[1] / "supabase" / "migrations"
from parse_migrations import strip_comments, statements  # noqa: E402
from verdict import (longest_dollar_span, norm_all, file_arg_types,  # noqa: E402
                     live_arg_types, split_top_commas)

ALL_FILES = sorted(p.name for p in MIG.glob("*.sql") if not p.name.startswith("99999999999999"))
SET36 = set(json.loads((HERE / "inventory.json").read_text()).keys())

# tüm geçmişteki fonksiyon tanımları: (name, args_norm) -> [(file, body_md5, body)]
ALL_VERSIONS = {}


def register_file(fn):
    text = strip_comments((MIG / fn).read_text(encoding="utf-8", errors="replace"))
    for stmt in statements(text):
        m = re.match(r"\s*CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+(.+?)\s*\(", stmt, re.I | re.S)
        if not m:
            mdo = re.match(r"\s*DO\s+(\$[A-Za-z_]\w*\$|\$)\s*(.*?)\s*\1\s*;?\s*$", stmt, re.I | re.S)
            if mdo:
                # DO gövdesindeki fonksiyonları da kaydet
                for sub in statements(mdo.group(2)):
                    _reg_stmt(sub, fn)
            continue
        _reg_stmt(stmt, fn)


def _reg_stmt(stmt, fn):
    m = re.match(r"\s*CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+(.+?)\s*\(", stmt, re.I | re.S)
    if not m:
        return
    name = m.group(1).strip().split(".")[-1].strip('"').lower()
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
    args_norm = norm_all(stmt[op + 1:j])
    body = longest_dollar_span(stmt) or ""
    # tip-listesi anahtarı (DEFAULT'ler ve param adları atılır) — canlı identity args ile kıyaslanabilir
    types_key = tuple(file_arg_types(stmt[op + 1:j]))
    ALL_VERSIONS.setdefault((name, types_key), []).append(
        {"file": fn, "md5": hashlib.md5(norm_all(body).encode()).hexdigest()[:10],
         "body_norm": norm_all(body), "args_norm": args_norm})


for f in ALL_FILES:
    register_file(f)


def diagnose_live(tag):
    probe = json.loads((HERE / f"probe_{tag}.json").read_text())
    out = []
    for r in probe["functions"]:
        name = r["name"].lower()
        types_key = tuple(live_arg_types(r["args"]))
        live_body = norm_all(longest_dollar_span(r["fdef"]) or "")
        live_md5 = hashlib.md5(live_body.encode()).hexdigest()[:10]
        cands = ALL_VERSIONS.get((name, types_key), [])
        # 36-dosya içindekiler hariç hangi sürüm canlıyla birebir eşleşiyor?
        exact = [v for v in cands if v["body_norm"] == live_body]
        # imza-aynı ama gövde farklı tanımların kronolojisi
        out.append({
            "fn": f'{r["schema"]}.{name}({r["args"]})',
            "live_md5": live_md5,
            "match": exact[-1]["file"] if exact else None,
            "in_set36": bool(exact and exact[-1]["file"] in SET36),
            "n_versions_total": len(cands),
            "history": [f'{v["file"]}:{v["md5"]}' for v in cands][-6:],
        })
    return out


def grant_check(tag, fn_name):
    probe = json.loads((HERE / f"probe_{tag}.json").read_text())
    rows = [r for r in probe["routine_grants"] if r["name"] == fn_name]
    return [{"grantee": r["grantee"], "priv": r["privilege_type"]} for r in rows]


TRG39 = ['cases', 'diseases', 'dogum', 'drug_administrations', 'drug_classes',
         'drug_products', 'drugs', 'gorev_log', 'grup_padok_eslem', 'hastalik_log',
         'hayvan_override', 'hayvanlar', 'hekimler', 'irk_esik', 'kizginlik_log',
         'padoklar', 'pedigree_meta', 'pedigree_nodes', 'pedigree_parentage',
         'protokol_ayar', 'protokol_dismiss', 'protokol_instance',
         'sablon_hastalik_eslem', 'semen_catalog', 'stok', 'stok_hareket',
         'stok_kategorileri', 'tedavi', 'tedavi_sablonu', 'tedavi_sablonu_kalem',
         'tohumlama', 'treatment_day_uygulamalar', 'treatment_days',
         'uygulama_log', 'vaccination_log', 'vaccination_schedule',
         'vaccine_diseases', 'vaccine_protocol_steps', 'vaccines']


def trg_degisim_state(tag):
    probe = json.loads((HERE / f"probe_{tag}.json").read_text())
    have = {r["table_name"] for r in probe["triggers"] if r["name"] == "trg_degisim_log"}
    return {"var": sorted(have & set(TRG39)), "yok": sorted(set(TRG39) - have),
            "fazladan": sorted(have - set(TRG39))}


if __name__ == "__main__":
    res = {
        "prod_fn_koken": diagnose_live("prod"),
        "demo_fn_koken": diagnose_live("demo"),
        "demo_grant_pedigree_subgraph": grant_check("demo", "pedigree_subgraph"),
        "demo_grant_sahip_sifresi_ayarla": grant_check("demo", "sahip_sifresi_ayarla"),
        "demo_trg_degisim_log": trg_degisim_state("demo"),
        "prod_trg_degisim_log": trg_degisim_state("prod"),
    }
    (HERE / "diagnosis.json").write_text(json.dumps(res, indent=1, ensure_ascii=False))

    print("== PROD: gövde kökeni (36-dışı eşleşenler öne alınmaz, hepsi listelenir) ==")
    for d in res["prod_fn_koken"]:
        if d["match"] and d["match"] not in SET36:
            print(f'  {d["fn"][:80]}  -> {d["match"]} (md5 {d["live_md5"]})')
    print("== PROD: hiçbir migration sürümüyle eşleşmeyenler ==")
    for d in res["prod_fn_koken"]:
        if not d["match"]:
            print(f'  {d["fn"][:80]}  md5={d["live_md5"]} tarihçe={d["history"][-3:]}')
    print("== DEMO: 36-dışı eşleşenler ==")
    for d in res["demo_fn_koken"]:
        if d["match"] and d["match"] not in SET36:
            print(f'  {d["fn"][:80]}  -> {d["match"]} (md5 {d["live_md5"]})')
    print("== DEMO: hiçbir sürümle eşleşmeyenler ==")
    for d in res["demo_fn_koken"]:
        if not d["match"]:
            print(f'  {d["fn"][:80]}  md5={d["live_md5"]} tarihçe={d["history"][-3:]}')
    print("== DEMO grant teyitleri ==")
    print("  pedigree_subgraph:", res["demo_grant_pedigree_subgraph"])
    print("  sahip_sifresi_ayarla:", res["demo_grant_sahip_sifresi_ayarla"])
    print("== trg_degisim_log ==")
    print("  demo yok:", res["demo_trg_degisim_log"]["yok"] or "—",
          "| fazladan:", res["demo_trg_degisim_log"]["fazladan"] or "—")
    print("  prod var:", len(res["prod_trg_degisim_log"]["var"]), "| yok:", len(res["prod_trg_degisim_log"]["yok"]))
