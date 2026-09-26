#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""govde_karsilastir.py — cila-onarım K2 gövde doğrulayıcı (dosya ↔ canlı demo).

Kümülatif son-yazan semantiği: supabase/migrations/20260925*.sql serisinde aynı
fonksiyonu tanımlayan son dosya (ad sırası = uygulama sırası) beklenen gövdedir.
Canlı pg_get_functiondef çıktısıyla normalize edilerek karşılaştırılır.

Kullanım:
  govde_karsilastir.py --repo <kok> --list-objects          # faz 1: isim listesi (JSON)
  govde_karsilastir.py --repo <kok> --live live.json        # faz 2: karşılaştır
  (opsiyonel: --files '<glob>' — negatif testte tek geçici dosya beslemek için)

Çıkış: fonksiyon/görünüm başına OK|DIFF satırları + DROP/statement kontrolleri
+ ALTER-only hedefler (seride CREATE'i olmayıp yalnız ALTER FUNCTION ... SET
search_path ile dokunulan fonksiyonlar) için tırnaksız search_path (K5)
öznitelik denetimi; son satır GOVDE_FARK: <n>; exit 0 yalnız n=0.
[F4/K2] Bu kapsamın gerekçesi: 20260925000004 yalnız ALTER içerdiğinden
protokol_ayar_guncelle(text,numeric) CREATE tabanlı kümeye hiç girmiyordu.

Normalizasyon kuralları (yorumlar KORUNUR — guard'lar yorumlarla belgeli):
  - dollar-quote etiketleri kanonikleştir ($fn$/$fnx$/$$ → $function$)
  - SET search_path İKİ-DEĞERLİ gösterimi eşitlenir (TO 'public','pg_temp' ≡ = public, pg_temp)
  - TEK-TIRNAKLI tek-değer form (= 'public, pg_temp') EŞİTLENMEZ (F4/K2): bu bir
    gösterim farkı değil, var olmayan "public, pg_temp" şemasına kilitleyen bilinen
    semantik hatadır (mimar C1) — karşılaştırma fark üretir; dosya+canlı İKİSİ de
    tırnaklıysa K5 ihlali DIFF'i ayrıca yazılır (aşağıya bakınız)
  - öznitelik bölgesinde VOLATILE anahtar sözcüğü düşürülür (pg_get_functiondef varsayılanı yazmaz)
  - sondaki ';' düşürülür; boşluk dizileri tek boşluğa iner
"""
import argparse
import glob as globmod
import json
import os
import re
import sys

CREATE_FN_RE = re.compile(
    r"CREATE\s+OR\s+REPLACE\s+FUNCTION\s+public\.([A-Za-z_][A-Za-z0-9_]*)\s*\(",
    re.IGNORECASE)
CREATE_VIEW_RE = re.compile(
    r"CREATE\s+OR\s+REPLACE\s+VIEW\s+public\.([A-Za-z_][A-Za-z0-9_]*)\s+AS\s",
    re.IGNORECASE)
# [E7/7b 2026-09-25] CREATE TABLE hedefleri: gövde doğrulamada tablo VARLIK kontrolü
# (emit_sql yalnız fonksiyon/view/statements sınadığından yeni katalog tabloları
# kapsam dışı kalıyordu — örn. gorev_ertele_kural). Kolon/kısıt karşılaştırması YOK:
# yalnız to_regclass düzeyinde varlık.
CREATE_TABLE_RE = re.compile(
    r"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?public\.([A-Za-z_][A-Za-z0-9_]*)\s*\(",
    re.IGNORECASE)
TAG_RE = re.compile(r"\$[A-Za-z0-9_]*\$")

# Tek-parçalı tip adları: parametre-adı düşürme kararında FIRST token tipse
# isim SAYILMAZ (pg_get_function_identity_arguments param adlarını taşır).
TIPLER = {
    'text', 'date', 'uuid', 'boolean', 'integer', 'bigint', 'smallint',
    'numeric', 'jsonb', 'json', 'time', 'timestamp', 'timestamptz',
    'interval', 'bytea', 'real', 'anyelement', 'name',
}


def split_top_level(s, sep=','):
    """Parantez ve köşeli-parantez derinliğini sayan üst-düzey ayrıştırıcı."""
    out, depth, cur = [], 0, []
    for ch in s:
        if ch in '([':
            depth += 1
        elif ch in ')]':
            depth -= 1
        if ch == sep and depth == 0:
            out.append(''.join(cur))
            cur = []
        else:
            cur.append(ch)
    if ''.join(cur).strip():
        out.append(''.join(cur))
    return out


def normalize_identity(ident):
    """'p_x text, p_y boolean' ya da 'text, boolean' → 'text, boolean'."""
    ident = ident.strip()
    if not ident:
        return ''
    types = []
    for chunk in split_top_level(ident):
        chunk = re.sub(r"\s+DEFAULT\s+.*$", '', chunk.strip(), flags=re.IGNORECASE)
        toks = chunk.split()
        if not toks:
            continue
        if len(toks) >= 2 and toks[0].lower() not in TIPLER:
            toks = toks[1:]  # ilk token parametre adı → düşür
        types.append(' '.join(t.lower() for t in toks))
    return ', '.join(types)


def identity_args(argstr):
    """Dosya argüman listesi → normalize edilmiş tip kimliği."""
    return normalize_identity(argstr)


def find_matching_paren(text, open_idx):
    depth = 0
    for i in range(open_idx, len(text)):
        if text[i] == '(':
            depth += 1
        elif text[i] == ')':
            depth -= 1
            if depth == 0:
                return i
    return -1


def extract_function_def(text, start):
    """CREATE başlangıcından itibaren tam tanımı (son ';' dahil olmayan) döndürür."""
    open_idx = text.find('(', start)
    close_idx = find_matching_paren(text, open_idx)
    if close_idx < 0:
        raise ValueError('kapanmayan parantez')
    rest = text[close_idx + 1:]
    m = re.search(r"AS\s+(\$[A-Za-z0-9_]*\$)", rest, re.IGNORECASE)
    if m:
        tag = m.group(1)
        end = rest.find(tag, m.end())
        if end < 0:
            raise ValueError('dollar-quote kapanmıyor')
        after = end + len(tag)
        semi = rest.find(';', after)
        stop = semi + 1 if semi != -1 and semi <= after + 2 else after
        return text[start:close_idx + 1 + stop], close_idx + 1 + stop
    # SQL gövdesi (BEGIN..END ya da tek SELECT): ';' ya da 'COMMENT/REVOKE/GRANT/NOTIFY' kelimesine kadar
    m = re.search(r";", rest)
    if not m:
        raise ValueError('fonksiyon sonu bulunamadı')
    stop = m.start() + 1
    return text[start:close_idx + 1 + stop], close_idx + 1 + stop


def extract_view_def(text, start):
    """CREATE ... AS <select>; görünüm tanımının SELECT kısmını döndürür."""
    rest = text[start:]
    m = re.search(r"AS\s+", rest, re.IGNORECASE)
    sel_start = m.end()
    semi = rest.find(';', sel_start)
    return rest[sel_start:semi].strip(), start + semi + 1


def mask_comments(text):
    """'--' yorumlarını AYNI UZUNLUKTA boşlukla değiştirir (pozisyonlar korunur).

    Aday CREATE/DROP bulma bu maske üzerinde yapılır; tanım çıkarımı ORİJİNAL
    metinden yapılır — böylece dosya tarafındaki yorumlar karşılaştırmaya girer
    (guard'lar yorumlarla belgeli; yorum farkı da fark sayılmalı).
    """
    out = []
    for ln in text.split('\n'):
        i = ln.find('--')
        if i >= 0:
            out.append(ln[:i] + ' ' * (len(ln) - i))
        else:
            out.append(ln)
    return '\n'.join(out)


ALTER_SP_RE = re.compile(
    r"ALTER\s+FUNCTION\s+public\.([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)"
    r"\s*SET\s+search_path\s*(?:=|TO)\s*'?\s*public\s*'?\s*,\s*'?\s*pg_temp\s*'?\s*;",
    re.IGNORECASE)


def scan_files(files):
    """Dosya listesi → son-yazıcı fonksiyon/görünüm haritası + DROP hedefleri
    + ALTER-search_path öznitelik yamaları (kümülatif semantik)
    + CREATE TABLE hedef adları (E7/7b varlık kontrolü)."""
    fns = {}    # (ad, identity) → {'file':, 'def':}
    views = {}  # ad → {'file':, 'def':}
    drops = []  # {'name':, 'identity':}
    alter_sp = set()  # (ad, identity) — sonrasına SET search_path uygulanmış
    tables = set()  # public.<ad> CREATE TABLE hedefleri
    for path in files:
        with open(path, encoding='utf-8') as f:
            text = f.read()
        code = mask_comments(text)
        for m in CREATE_FN_RE.finditer(code):
            start = m.start()
            try:
                defn, _end = extract_function_def(text, start)
            except ValueError as e:
                raise SystemExit(f"HATA: {path}: {m.group(1)} tanımı ayrıştırılamadı: {e}")
            open_idx = text.find('(', start)
            close_idx = find_matching_paren(text, open_idx)
            args = text[open_idx + 1:close_idx]
            key = (m.group(1), identity_args(args))
            fns[key] = {'file': os.path.basename(path), 'def': defn}
        for m in CREATE_VIEW_RE.finditer(code):
            try:
                # View yorumları veritabanında SAKLANMAZ (pg_get_viewdefta yok) —
                # dosya tarafı maskeli (yorumsize) metinden çıkarılır; mask, yorumları
                # AYNI UZUNLUKTA boşlukla değiştirdiğinden pozisyonlar orijinalle eş.
                sel, _ = extract_view_def(code, m.start())
            except Exception as e:
                raise SystemExit(f"HATA: {path}: view {m.group(1)}: {e}")
            views[m.group(1)] = {'file': os.path.basename(path), 'def': sel}
        for m in re.finditer(
                r"DROP\s+FUNCTION\s+(?:IF\s+EXISTS\s+)?public\.([A-Za-z_][A-Za-z0-9_]*)\s*\(([^)]*)\)",
                code, re.IGNORECASE):
            drops.append({'name': m.group(1), 'identity': identity_args(m.group(2))})
        for m in ALTER_SP_RE.finditer(code):
            alter_sp.add((m.group(1), identity_args(m.group(2))))
        for m in CREATE_TABLE_RE.finditer(code):
            tables.add(m.group(1))
    return fns, views, drops, alter_sp, tables


def normalize_def(defn):
    """pg_get_functiondef ↔ dosya gösterim farklarını eleyen normalizasyon."""
    t = defn.strip()
    m = re.search(r"AS\s+(\$[A-Za-z0-9_]*\$)", t, re.IGNORECASE)
    if m and m.group(1) != '$function$':
        tag = re.escape(m.group(1))
        t = re.sub(tag, '$function$', t)
    # Yalnız İKİ-DEĞERLİ tırnaklı liste gösterimi eşitlenir (meşru render farkı).
    # TEK-TIRNAKLI tek-değer 'public, pg_temp' bilinçli olarak EŞİTLENMEZ (F4/K2,
    # mimar C1): o form search_path'i var olmayan tek şemaya kilitler — normalizasyon
    # katmanı bunu maskelediğinde tek-taraflı canlı regresyon bile OK üretiyordu.
    t = re.sub(r"SET\s+search_path\s+TO\s+'public'\s*,\s*'pg_temp'",
               'SET search_path = public, pg_temp', t, flags=re.IGNORECASE)
    # öznitelik bölgesi (AS $function$'e kadar): VOLATILE düşür, imza cast'lerini eşitle
    m = re.search(r"AS\s+\$function\$", t, re.IGNORECASE)
    if m:
        head, body = t[:m.start()], t[m.start():]
        head = re.sub(r"\bVOLATILE\s+", '', head, flags=re.IGNORECASE)
        head = re.sub(r"::[A-Za-z_][A-Za-z0-9_]*(\[\])?", '', head)  # DEFAULT NULL::text vb. render farkı
        head = re.sub(r"\s+", ' ', head)
        head = re.sub(r"\(\s+", '(', head)   # çok-satırlı imza render'ı: "( p_x" ≡ "(p_x"
        head = re.sub(r"\s+\)", ')', head)
        head = head.strip()
        # INTERVAL gösterimi: '... '::interval ≡ INTERVAL '...'
        body = re.sub(r"'([^']*)'\s*::\s*interval", r"INTERVAL '\1'", body, flags=re.IGNORECASE)
        body = re.sub(r"\s+", ' ', body).strip()
        t = head + ' ' + body
    else:
        t = re.sub(r"\s+", ' ', t).strip()
    t = re.sub(r";\s*$", '', t)
    return t


def ensure_sp_attr(defn):
    """Son-yazıcı tanımda SET search_path yoksa (sonrası ALTER ile eklenmişse)
    kanonik özniteliği AS etiketinden önce ekle."""
    if re.search(r"\bSET\s+search_path\s*=", defn, re.IGNORECASE):
        return defn
    m = re.search(r"AS\s+\$[A-Za-z0-9_]*\$", defn, re.IGNORECASE)
    if not m:
        return defn
    return defn[:m.start()] + 'SET search_path = public, pg_temp ' + defn[m.start():]


# [F4/K2] K5 öznitelik denetimi: tırnaksız kanonik form ile bilinen-hatalı
# tek-tırnaklı tek-değer formu ayrıştırılır (ikisi normalize sonrası ayrışır).
SP_UNQUOTED_RE = re.compile(
    r"SET\s+search_path\s*(?:=|TO)\s*public\s*,\s*pg_temp\b", re.IGNORECASE)
SP_QUOTED1_RE = re.compile(
    r"SET\s+search_path\s*(?:=|TO)\s*'public, pg_temp'", re.IGNORECASE)


def sp_attr_region(defn):
    """SET search_path öznitelik bölgesi: AS $..$ etiketine KADAR olan kısım.
    Gövde içinde geçen aynı metin (yorum/alıntı) K5 denetimine girmez."""
    m = re.search(r"AS\s+\$[A-Za-z0-9_]*\$", defn, re.IGNORECASE)
    return defn[:m.start()] if m else defn


def normalize_view_def(defn):
    """Görünüm normalizasyonu: boşluk + TÜM parantezler düşürülür.

    pg_get_viewdef basit ifadelerin etrafına yedek parantez ekler
    ((CURRENT_DATE - x) AS ... ≡ CURRENT_DATE - x AS ...) — gösterim farkı
    drift değildir. Belirteç/sabit/işleç farkları yine yakalanır.
    """
    t = re.sub(r"[()]", ' ', defn)
    t = re.sub(r"'([^']*)'\s*::\s*interval", r"INTERVAL '\1'", t, flags=re.IGNORECASE)
    t = re.sub(r"'([^']*)'\s*::\s*text", r"'\1'", t, flags=re.IGNORECASE)  # LIKE örüntü cast render'ı
    return re.sub(r"\s+", ' ', t).strip().rstrip(';').strip()


def first_diff(a, b, ctx=90):
    for i in range(min(len(a), len(b))):
        if a[i] != b[i]:
            lo = max(0, i - ctx)
            return f"konum {i}: DOSYA[...{a[lo:i+ctx]}...] CANLI[...{b[lo:i+ctx]}...]"
    if len(a) != len(b):
        i = min(len(a), len(b))
        lo = max(0, i - ctx)
        longer = a if len(a) > len(b) else b
        return f"uzunluk farkı ({len(a)} vs {len(b)}): [...{longer[lo:i+ctx]}...]"
    return None


def emit_sql(objs):
    """Canlı çekim SQL'ini üret (isim listeleri gömülü; boş liste → sentinel '').
    [F4/K2] ALTER-only hedef adları da çekilir — seride CREATE'i olmayan
    fonksiyonların canlı proconfig'i ancak böyle sınanabilir."""
    fn_names = sorted({f['name'] for f in objs['functions']}
                      | {d['name'] for d in objs['drops']}
                      | {a['name'] for a in objs.get('alter_only', [])})
    vw_names = sorted(objs['views'])
    tbl_names = sorted(objs.get('tables', []))
    fn_arr = ', '.join("'%s'" % n for n in fn_names) or "''"
    vw_arr = ', '.join("'%s'" % n for n in vw_names) or "''"
    tbl_arr = ', '.join("'%s'" % n for n in tbl_names) or "''"
    return ("SELECT jsonb_build_object(\n"
            "  'functions', COALESCE((SELECT jsonb_agg(jsonb_build_object(\n"
            "       'name', p.proname,\n"
            "       'identity', pg_get_function_identity_arguments(p.oid),\n"
            "       'def', pg_get_functiondef(p.oid)) ORDER BY p.proname)\n"
            "     FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace\n"
            f"     WHERE n.nspname = 'public' AND p.proname IN ({fn_arr})), '[]'::jsonb),\n"
            "  'views', COALESCE((SELECT jsonb_agg(jsonb_build_object(\n"
            "       'name', c.relname, 'def', pg_get_viewdef(c.oid)) ORDER BY c.relname)\n"
            "     FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace\n"
            f"     WHERE n.nspname = 'public' AND c.relkind = 'v' AND c.relname IN ({vw_arr})), '[]'::jsonb),\n"
            "  'tables', COALESCE((SELECT jsonb_agg(jsonb_build_object(\n"
            "       'name', c.relname) ORDER BY c.relname)\n"
            "     FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace\n"
            f"     WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relname IN ({tbl_arr})), '[]'::jsonb),\n"
            "  'statements_null', COALESCE((SELECT jsonb_agg(jsonb_build_object(\n"
            "       'version', version, 'name', name) ORDER BY version)\n"
            "     FROM supabase_migrations.schema_migrations\n"
            "     WHERE version LIKE '20260925%' AND statements IS NULL), '[]'::jsonb)\n"
            ");\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', required=True)
    ap.add_argument('--files', default=None,
                    help="tarama glob'u (negatif test); varsayılan supabase/migrations/20260925*.sql")
    ap.add_argument('--live', default=None, help='faz 2: canlı JSON dosyası')
    ap.add_argument('--list-objects', action='store_true', help='faz 1: isim listesi JSON yaz')
    ap.add_argument('--emit-sql', action='store_true',
                    help="faz 1b: objects.json stdin'den okunur, canli cekim SQL'i basilir")
    args = ap.parse_args()

    if args.emit_sql:
        objs = json.load(sys.stdin)
        sys.stdout.write(emit_sql(objs))
        return

    pattern = args.files or os.path.join('supabase', 'migrations', '20260925*.sql')
    full_pattern = pattern if os.path.isabs(pattern) else os.path.join(args.repo, pattern)
    files = sorted(globmod.glob(full_pattern))
    if not files:
        raise SystemExit(f"HATA: tarama deseni boş: {pattern}")
    fns, views, drops, alter_sp, tables = scan_files(files)
    drop_keys = {(d['name'], d['identity']) for d in drops}
    # [F4/K2] ALTER-only hedefler: seride CREATE tanımı olmayan, yalnız ALTER
    # FUNCTION ... SET search_path ile dokunulan fonksiyonlar. Dropped olanlar
    # hariç (DROP edilmiş imza için öznitelik denetimi anlamsız).
    alter_only = sorted(k for k in alter_sp if k not in fns and k not in drop_keys)

    if args.list_objects:
        print(json.dumps({
            'functions': sorted(({'name': k[0], 'identity': k[1]} for k in fns),
                                key=lambda d: (d['name'], d['identity'])),
            'views': sorted(views.keys()),
            'tables': sorted(tables),
            'drops': drops,
            'alter_only': sorted(({'name': k[0], 'identity': k[1]} for k in alter_only),
                                 key=lambda d: (d['name'], d['identity'])),
            'files': [os.path.basename(f) for f in files],
        }, ensure_ascii=False))
        return

    if not args.live:
        raise SystemExit('HATA: --live gerekli (faz 2)')
    with open(args.live, encoding='utf-8') as f:
        live = json.load(f)

    fark = 0
    live_by_key = {}
    for f_ in live.get('functions', []):
        live_by_key[(f_['name'], normalize_identity(f_['identity']))] = f_['def']
    for (name, ident), meta in sorted(fns.items()):
        ldef = live_by_key.get((name, ident))
        if ldef is None:
            print(f"DIFF {name}({ident}) — canlıda YOK (dosya: {meta['file']})")
            fark += 1
            continue
        expected = ensure_sp_attr(meta['def']) if (name, ident) in alter_sp else meta['def']
        a, b = normalize_def(expected), normalize_def(ldef)
        if a == b:
            # [F4/K2] K5 değişmezi: iki taraf TÜMÜYLE eşit olsa bile tırnaklı
            # tek-değer search_path gösterim farkı değil bilinen semantik hatadır
            # (mimar C1) — dosya+canlı ikisi de tırnaklıysa drift yoktur ama
            # ihlal vardır; kapı bunu da DIFF sayar.
            if SP_QUOTED1_RE.search(sp_attr_region(expected)):
                print(f"DIFF {name}({ident})  [{meta['file']}] — K5 İHLALİ: "
                      f"tırnaklı tek-değer 'public, pg_temp' (var olmayan şema); "
                      f"dosya↔canlı eşit ama form hatalı")
                fark += 1
            else:
                print(f"OK   {name}({ident})  [{meta['file']}]")
        else:
            print(f"DIFF {name}({ident})  [{meta['file']}] — {first_diff(a, b)}")
            fark += 1

    # [F4/K2] ALTER-only hedefler: seride CREATE'i yok, yalnız ALTER ile
    # search_path kilidi vurulmuş (ör. protokol_ayar_guncelle — 000004).
    # Canlıdan pg_get_functiondef çekilir; tırnaksız kanonik öznitelik var mı?
    for name, ident in alter_only:
        ldef = live_by_key.get((name, ident))
        if ldef is None:
            print(f"DIFF SP {name}({ident})  [alter-only] — canlıda YOK")
            fark += 1
            continue
        attr = sp_attr_region(normalize_def(ldef))
        if SP_QUOTED1_RE.search(attr):
            print(f"DIFF SP {name}({ident})  [alter-only] — K5 İHLALİ: canlıda "
                  f"tırnaklı tek-değer 'public, pg_temp' (var olmayan şema)")
            fark += 1
        elif SP_UNQUOTED_RE.search(attr):
            print(f"OK   SP {name}({ident})  [alter-only] — "
                  f"search_path = public, pg_temp (tırnaksız, K5)")
        else:
            print(f"DIFF SP {name}({ident})  [alter-only] — canlıda tırnaksız "
                  f"SET search_path = public, pg_temp özniteliği YOK")
            fark += 1

    live_views = {v['name']: v['def'] for v in live.get('views', [])}
    for name, meta in sorted(views.items()):
        ldef = live_views.get(name)
        if ldef is None:
            print(f"DIFF VIEW {name} — canlıda YOK (dosya: {meta['file']})")
            fark += 1
            continue
        if normalize_view_def(meta['def']) == normalize_view_def(ldef):
            print(f"OK   VIEW {name}  [{meta['file']}]")
        else:
            print(f"DIFF VIEW {name}  [{meta['file']}] — "
                  f"{first_diff(normalize_view_def(meta['def']), normalize_view_def(ldef))}")
            fark += 1

    for d in drops:
        if (d['name'], d['identity']) in live_by_key:
            print(f"DIFF DROP {d['name']}({d['identity']}) — DROP edilmişti ama canlıda VAR")
            fark += 1
        else:
            print(f"OK   DROP {d['name']}({d['identity']}) — canlıda yok (doğru)")

    # [E7/7b] CREATE TABLE hedefleri: canlıda VARLIK (to_regclass düzeyi;
    # kolon/kısıt karşılaştırması kapsam dışı — migration dosyası şemayı
    # tam tanımladığından db-validate C1 postcheck o katmanı sınar).
    live_tables = {t['name'] for t in live.get('tables', [])}
    for name in sorted(tables):
        if name in live_tables:
            print(f"OK   TABLE {name} — canlıda var")
        else:
            print(f"DIFF TABLE {name} — canlıda YOK (CREATE TABLE uygulanmamış)")
            fark += 1

    for rec in live.get('statements_null', []):
        print(f"DIFF STAMPS {rec['version']} ({rec.get('name','')}) — statements NULL")
        fark += 1

    print(f"GOVDE_FARK: {fark}")
    sys.exit(0 if fark == 0 else 1)


if __name__ == '__main__':
    main()
