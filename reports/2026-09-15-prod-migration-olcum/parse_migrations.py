#!/usr/bin/env python3
"""P1 ölçüm — migration dosyalarından nesne envanteri çıkarır (salt-okunur, token yok).

Çıktı: reports/2026-09-15-prod-migration-olcum/inventory.json
"""
import json, re, pathlib

BASE = pathlib.Path(__file__).resolve().parents[2]
MIG = BASE / "supabase" / "migrations"
OUT = pathlib.Path(__file__).resolve().parent / "inventory.json"

FILES = sorted(p.name for p in MIG.glob("*.sql")
               if "20260830000010" <= p.name[:14] <= "20260914000004")


def strip_comments(text):
    """Yorumları boşlukla değiştir; tek tırnak ve dolar-quote gövdelerini koru."""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        m = re.match(r"\$([A-Za-z_][\w]*)?\$", text[i:]) if c == '$' else None
        if m:  # dolar-quote gövdesini aynen kopyala
            tag = m.group(0)
            end = text.find(tag, i + len(tag))
            if end == -1:
                out.append(text[i:]); break
            out.append(text[i:end + len(tag)]); i = end + len(tag); continue
        if c == "'":
            j = i + 1
            while j < n:
                if text[j] == "'":
                    if j + 1 < n and text[j + 1] == "'":
                        j += 2; continue
                    break
                j += 1
            out.append(text[i:j + 1]); i = j + 1; continue
        if text[i:i+2] == '--':
            j = text.find('\n', i)
            if j == -1: j = n
            out.append(' ' * (j - i)); i = j; continue
        if text[i:i+2] == '/*':
            j = text.find('*/', i)
            if j == -1: j = n - 2
            out.append(' ' * (j + 2 - i)); i = j + 2; continue
        out.append(c); i += 1
    return ''.join(out)


def statements(text):
    """Yorumu temizlenmiş metni ; ile biten statement'lara böler (dolar/tırnak farkındalı)."""
    i, n = 0, len(text)
    while i < n:
        start = i
        dollar, depth = None, 0
        while i < n:
            c = text[i]
            if dollar:
                e = text.find(dollar, i)
                if e == -1:
                    i = n; break
                i = e + len(dollar); dollar = None; continue
            if c == "'":
                j = i + 1
                while j < n:
                    if text[j] == "'":
                        if j + 1 < n and text[j + 1] == "'":
                            j += 2; continue
                        break
                    j += 1
                i = j + 1; continue
            m = re.match(r"\$([A-Za-z_][\w]*)?\$", text[i:]) if c == '$' else None
            if m:
                dollar = m.group(0); i += len(dollar); continue
            if c == '(':
                depth += 1; i += 1
            elif c == ')':
                depth -= 1; i += 1
            elif c == ';':
                yield text[start:i + 1]; i += 1; break
            else:
                i += 1
        else:
            if text[start:i].strip():
                yield text[start:i]
            break


QID = r'(?:[A-Za-z_][\w$]*\.)?(?:"[^"]+"|[A-Za-z_][\w$]*)'


def strip_q(s):
    return s.strip().strip('"').lower()


def qual(s):
    parts = re.findall(r'"[^"]+"|[A-Za-z_][\w$]*', s.strip())
    if len(parts) >= 2:
        return strip_q(parts[-2]), strip_q(parts[-1])
    return "public", strip_q(parts[0]) if parts else ""


def parse_file(fn, text):
    f = {"functions": [], "tables": [], "columns": [], "drop_columns": [],
         "triggers": [], "policies": [], "indexes": [], "grants": [],
         "drops": [], "constraints": [], "views": [], "rls": [],
         "dml": [], "other": []}
    clean = strip_comments(text)
    for stmt in statements(clean):
        s = stmt
        su = " ".join(s.split())
        m = re.match(r"\s*CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+(.+?)\s*\(", s, re.I | re.S)
        if m:
            op = s.index("(", m.end(1))
            depth, j = 0, op
            while j < len(s):
                if s[j] == '(':
                    depth += 1
                elif s[j] == ')':
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            f["functions"].append({"name": m.group(1).strip(),
                                   "args_raw": " ".join(s[op + 1:j].split()),
                                   "stmt_len": len(s)})
            continue
        m = re.match(r"\s*CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(" + QID + r")\s*\(", s, re.I)
        if m:
            sch, tb = qual(m.group(1))
            f["tables"].append({"schema": sch, "table": tb})
            continue
        m = re.match(r"\s*ALTER\s+TABLE\s+(?:ONLY\s+)?(" + QID + r")\s+(.*)", s, re.I | re.S)
        if m:
            sch, tb = qual(m.group(1))
            rest = m.group(2)
            for cm in re.finditer(r"ADD\s+(?:COLUMN\s+)?(?:IF\s+NOT\s+EXISTS\s+)?(?!(?:CONSTRAINT|CHECK|FOREIGN|PRIMARY|UNIQUE)\b)(" + QID + r")\s+", rest, re.I):
                f["columns"].append({"schema": sch, "table": tb, "column": strip_q(cm.group(1)), "raw": su[:160]})
            for cm in re.finditer(r"DROP\s+COLUMN\s+(?:IF\s+EXISTS\s+)?(" + QID + r")", rest, re.I):
                f["drop_columns"].append({"schema": sch, "table": tb, "column": strip_q(cm.group(1))})
            for cm in re.finditer(r"ADD\s+CONSTRAINT\s+(" + QID + r")\s+(UNIQUE|CHECK|FOREIGN\s+KEY|PRIMARY\s+KEY)", rest, re.I):
                f["constraints"].append({"schema": sch, "table": tb, "name": strip_q(cm.group(1)), "kind": cm.group(2).upper()})
            for cm in re.finditer(r"(ENABLE|DISABLE|FORCE)\s+ROW\s+LEVEL\s+SECURITY", rest, re.I):
                f["rls"].append({"schema": sch, "table": tb, "op": cm.group(1).upper()})
            continue
        m = re.match(r"\s*CREATE\s+(?:OR\s+REPLACE\s+)?(CONSTRAINT\s+)?TRIGGER\s+(" + QID + r")\s+(.*?)\s+ON\s+(" + QID + r")", s, re.I | re.S)
        if m:
            f["triggers"].append({"name": strip_q(m.group(2)), "schema": qual(m.group(4))[0],
                                  "table": qual(m.group(4))[1], "timing": " ".join(m.group(3).split())[:60]})
            continue
        m = re.match(r"\s*CREATE\s+POLICY\s+(" + QID + r")\s+ON\s+(" + QID + r")", s, re.I)
        if m:
            f["policies"].append({"name": strip_q(m.group(1)), "schema": qual(m.group(2))[0], "table": qual(m.group(2))[1]})
            continue
        m = re.match(r"\s*CREATE\s+(UNIQUE\s+)?INDEX\s+(?:CONCURRENTLY\s+)?(?:IF\s+NOT\s+EXISTS\s+)?(" + QID + r")?\s*ON\s+(?:ONLY\s+)?(" + QID + r")", s, re.I)
        if m:
            sch, tb = qual(m.group(3))
            f["indexes"].append({"name": strip_q(m.group(2)) if m.group(2) else None,
                                 "schema": sch, "table": tb, "unique": bool(m.group(1))})
            continue
        m = re.match(r"\s*GRANT\s+(.+?)\s+ON\s+(TABLE|FUNCTION|SEQUENCE|DATABASE|SCHEMA)?\s*(.+?)\s+TO\s+(.+?)\s*$", s, re.I | re.S)
        if m:
            f["grants"].append({"priv": " ".join(m.group(1).split()), "kind": (m.group(2) or "TABLE").upper(),
                                "obj": " ".join(m.group(3).split()), "to": " ".join(m.group(4).split())})
            continue
        m = re.match(r"\s*DROP\s+(?:IF\s+EXISTS\s+)?(FUNCTION|TRIGGER|POLICY|INDEX|TABLE|VIEW|MATERIALIZED\s+VIEW)\b\s*(.*?);?\s*$", s, re.I | re.S)
        if m:
            kind = m.group(1).upper()
            rest = m.group(2)
            if kind == "FUNCTION":
                for dm in re.finditer(r"((?:[A-Za-z_][\w$]*\.)?\"?[A-Za-z_][\w$]*\"?\s*\([^;]*?\))", rest):
                    f["drops"].append({"kind": kind, "name": " ".join(dm.group(1).split()), "table": None})
            elif kind in ("TRIGGER", "POLICY"):
                for dm in re.finditer(r"(" + QID + r")\s+ON\s+((?:[A-Za-z_][\w$]*\.)?" + QID + r")", rest, re.I):
                    f["drops"].append({"kind": kind, "name": strip_q(dm.group(1)), "table": qual(dm.group(2))[1]})
            elif kind == "INDEX":
                for nm in [x.strip() for x in rest.split(",") if x.strip()]:
                    f["drops"].append({"kind": kind, "name": strip_q(nm), "table": None})
            else:
                for nm in [x.strip() for x in rest.split(",") if x.strip()]:
                    f["drops"].append({"kind": kind, "name": nm, "table": None})
            continue
        m = re.match(r"\s*CREATE\s+(?:OR\s+REPLACE\s+)?(MATERIALIZED\s+)?VIEW\s+(" + QID + r")", s, re.I)
        if m:
            sch, tb = qual(m.group(2))
            f["views"].append({"schema": sch, "view": tb})
            continue
        dml_matched = False
        for kind, pat in [("UPDATE", r"^\s*(?:WITH\s+.*?\)\s*)?UPDATE\s+(" + QID + r")"),
                          ("INSERT", r"^\s*(?:WITH\s+.*?\)\s*)?INSERT\s+INTO\s+(" + QID + r")"),
                          ("DELETE", r"^\s*(?:WITH\s+.*?\)\s*)?DELETE\s+FROM\s+(" + QID + r")")]:
            mm = re.match(pat, s, re.I | re.S)
            if mm:
                f["dml"].append({"kind": kind, "target": qual(mm.group(1))[1]})
                dml_matched = True
                break
        if dml_matched:
            continue
        m = re.match(r"^\s*REVOKE\s+(.+?)\s+ON\s+(TABLE|FUNCTION|SEQUENCE)?\s*(.+?)\s+FROM\s+(.+?)\s*$", s, re.I | re.S)
        if m:
            f["grants"].append({"priv": "REVOKE " + " ".join(m.group(1).split()), "kind": (m.group(2) or "TABLE").upper(),
                                "obj": " ".join(m.group(3).split()), "to": " ".join(m.group(4).split())})
            continue
        if re.match(r"^\s*(BEGIN|COMMIT|ROLLBACK|START\s+TRANSACTION)\s*;?\s*$", s, re.I):
            continue
        if re.match(r"^\s*NOTIFY\b", s, re.I):
            continue
        m = re.match(r"^\s*DO\s+(\$[A-Za-z_]\w*\$|\$)\s*(.*?)\s*\1\s*;?\s*$", s, re.I | re.S)
        if m:
            # DO gövdesini özyinelemeli çözümle (statik iç statement'lar)
            body = m.group(2)
            sub = parse_file(fn, body)
            for k in ("functions", "tables", "columns", "drop_columns", "triggers", "policies",
                      "indexes", "grants", "drops", "constraints", "views", "rls", "dml"):
                for item in sub[k]:
                    item["via_do"] = True
                    if item not in f[k]:
                        f[k].append(item)
            for item in sub["other"]:
                item["raw"] = "DO> " + item.get("raw", "")
                f["other"].append(item)
            continue
        if su:
            f["other"].append({"raw": su[:160]})
    return f


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

# Dosyadan elle doğrulanmış ek nesneler (dinamik SQL / koşullu bloklar parser'ın
# erişemediği yerler — dosyalar satır satır okunarak eklendi):
OVERRIDES = {
    "20260910000002_sperma_eslesme_sertlestirme.sql": {
        "functions": [{"name": "public.tohumlama_kaydet",
                       "args_raw": "p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text DEFAULT NULL::text, p_irk_bilgisi text DEFAULT NULL::text, p_ek_uygulamalar jsonb DEFAULT '[]'::jsonb, p_vwp_override boolean DEFAULT false",
                       "via_do": True}],
    },
    "20260911000001_dogum_buzagi_id_foundation.sql": {
        "columns": [{"schema": "public", "table": "dogum", "column": "buzagi_id",
                     "raw": "DO-blok koşullu: ADD COLUMN buzagi_id text NULL CONSTRAINT dogum_buzagi_id_fkey REFERENCES hayvanlar(id) ON DELETE SET NULL"}],
        "constraints": [{"schema": "public", "table": "dogum", "name": "dogum_buzagi_id_fkey", "kind": "FOREIGN KEY"}],
        "dml": [{"kind": "UPDATE", "target": "dogum", "note": "DO-blok içinden _dogum_buzagi_backfill() çağrısı (buzagi_id backfill)"}],
    },
    "20260913000001_surum_gecmisi_f1_degisim_log.sql": {
        "triggers": [{"name": "trg_degisim_log", "schema": "public", "table": t,
                      "timing": "AFTER INSERT OR UPDATE OR DELETE (DO-blok EXECUTE format ile, 39 tablo)",
                      "via_do": True} for t in TRG39],
    },
}


if __name__ == "__main__":
    inv = {fn: parse_file(fn, (MIG / fn).read_text(encoding="utf-8", errors="replace")) for fn in FILES}
    for fn, ov in OVERRIDES.items():
        for k, items in ov.items():
            for it in items:
                if it not in inv[fn][k]:
                    inv[fn][k].append(it)
    OUT.write_text(json.dumps(inv, indent=1, ensure_ascii=False), encoding="utf-8")
    print(f"files={len(inv)} functions={sum(len(v['functions']) for v in inv.values())}")
    for fn, v in inv.items():
        kinds = {k: len(v[k]) for k in ("functions", "tables", "columns", "drop_columns", "triggers",
                                        "policies", "indexes", "grants", "drops", "constraints",
                                        "views", "rls", "dml") if v.get(k)}
        print(f"{fn}: {kinds}")
        for o in v["other"]:
            print(f"    UNPARSED: {o['raw'][:120]}")
