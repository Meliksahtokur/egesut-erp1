#!/usr/bin/env python3
"""W3 dogum-tarih denetimi — genel tarama (son revizyon; root R1/R2 sonrasi).

Girdi: canli prod Mgmt API SELECT cekimleri (rapor §Kullanılan SQL (c)):
  hayvanlar.json, dogum.json, tohumlama.json, kizginlik_log.json,
  uygulama_log.json, cases.json
Kontroller: gelecek tarih, anne-yası, anne-çakışması (dogum + hayvanlar.anne_id
birleşik), mükerrer kupe, tohumlama→doğum aralığı + takas testi, kontrol_tarihi
sırası, aynı buzağıya çift doğum, "Doğum Yaptı" öksüzleri, created_at sinyali
(swap-yakınlık dahil). SQL eşdeğerleri: rapor §Kullanılan SQL (g), (j)-(m).
"""
import json, re, datetime as dt
from collections import defaultdict, Counter

D = '/home/melik/tmp/agents/w3/'
TODAY = dt.date(2026, 9, 13)
IMPORT = {'2026-05-09', '2026-05-27', '2026-06-01'}   # arka-doldurma kampanyası dilimleri

def load(n): return json.load(open(D + n))
def d(s): return dt.date.fromisoformat(s[:10]) if s else None
def cdate(r): return (r.get('created_at') or r.get('olusturma') or '')[:10]
def is_test(s): return s and 'test' in str(s).lower()
def sw(x):
    if x and x.day <= 12 and x.day != x.month:
        try: return dt.date(x.year, x.day, x.month)
        except ValueError: return None
    return None

hay = load('hayvanlar.json'); dog = load('dogum.json'); toh = load('tohumlama.json')
kiz = load('kizginlik_log.json'); uyg = load('uygulama_log.json'); cases = load('cases.json')
by_id = {h['id']: h for h in hay}
def kupe(i): return (by_id.get(i) or {}).get('kupe_no') or i or '?'

bul = defaultdict(list)

# 1) gelecek tarih (SQL eşdeğeri: rapor (f))
for r in dog:
    if not is_test(r.get('yavru_kupe')) and d(r['tarih']) > TODAY: bul['GELECEK'].append(('dogum', kupe(r['anne_id']), r['tarih']))
for r in toh:
    if d(r['tarih']) > TODAY: bul['GELECEK'].append(('tohumlama', kupe(r['hayvan_id']), r['tarih']))
    if r.get('kontrol_tarihi') and d(r['kontrol_tarihi']) > TODAY: bul['GELECEK'].append(('toh.kontrol', kupe(r['hayvan_id']), r['kontrol_tarihi']))
for r in kiz:
    if d(r['tarih']) > TODAY: bul['GELECEK'].append(('kizginlik', kupe(r['hayvan_id']), r['tarih']))
for r in cases:
    if d(r['start_date']) > TODAY: bul['GELECEK'].append(('vaka', kupe(r['animal_id']), r['start_date']))
for r in uyg:
    if d(r['tarih']) > TODAY: bul['GELECEK'].append(('uygulama', kupe(r['hayvan_id']), r['tarih']))

# 2) anne yaşı: yavru doğumu − anne doğumu < 660 gün (SQL: rapor (k))
for c in hay:
    if not c.get('dogum_tarihi') or not c.get('anne_id'): continue
    m = by_id.get(c['anne_id'])
    if not m or not m.get('dogum_tarihi'): continue
    gap = (d(c['dogum_tarihi']) - d(m['dogum_tarihi'])).days
    if gap < 660:
        bul['ANNE_COK_GENC'].append((kupe(c['id']), kupe(c['anne_id']), str(m['dogum_tarihi']), str(c['dogum_tarihi']), f'{gap}g'))

# 3) anne çakışması: aynı ineğe iki buzağı <330 gün; KAYNAKLAR BİRLEŞİK:
#    hayvanlar.anne_id VE dogum.anne_id (root R1: yalnız dogum tablosu yetmez)
#    SQL eşdeğeri: rapor (j). 0-5 gün = ikiz ya da aynı doğumun iki kaynak kaydı.
kaynak = defaultdict(set)   # anne_id -> {tarih}
for h in hay:
    if h.get('anne_id') and h.get('dogum_tarihi'): kaynak[h['anne_id']].add(h['dogum_tarihi'][:10])
for r in dog:
    if r.get('anne_id') and r.get('tarih') and not is_test(r.get('yavru_kupe')): kaynak[r['anne_id']].add(r['tarih'][:10])
for aid, ts in kaynak.items():
    ds = sorted(d(t) for t in ts)
    for a, b in zip(ds, ds[1:]):
        gap = (b - a).days
        if 5 < gap < 330:
            bul['ANNE_CAKISMA'].append((kupe(aid), str(a), str(b), f'{gap}g'))

# 4) mükerrer kupe_no (SQL: rapor (m))
kc = Counter(str(h.get('kupe_no')).strip() for h in hay if h.get('kupe_no'))
for k, n in kc.items():
    if n > 1: bul['MUKEERRER_KUPE'].append((k, n))

# 5) tohumlama → doğum aralığı (doğumdan önceki SON tohumlama; SQL: rapor (g))
toh_by_hayvan = defaultdict(list)
for r in toh:
    if r.get('hayvan_id') and r.get('tarih'): toh_by_hayvan[r['hayvan_id']].append(r)
dog_by_anne = defaultdict(list)
for r in dog:
    if r.get('anne_id') and not is_test(r.get('yavru_kupe')): dog_by_anne[r['anne_id']].append(r)
for aid, dogumlar in dog_by_anne.items():
    tl = sorted(toh_by_hayvan.get(aid, []), key=lambda r: r['tarih'])
    for dg in dogumlar:
        b = d(dg['tarih'])
        oncekiler = [r for r in tl if d(r['tarih']) <= b]
        if not oncekiler: continue
        t = d(oncekiler[-1]['tarih']); tb = (b - t).days
        if 260 <= tb <= 300: continue
        alts = [(t2, b) for t2 in [sw(t)] if t2] + [(t, b2) for b2 in [sw(b)] if b2]
        hit = [str((b2 - t2).days) + 'g' for t2, b2 in alts if 260 <= (b2 - t2).days <= 300]
        if hit:
            bul['TOH_DOGUM_TERS_ADAY'].append((kupe(aid), str(t), dg['tarih'], f'{tb}g', f'takas->{hit[0]}'))
        elif tb < 240 or tb > 330:
            bul['TOH_DOGUM_DISINDA'].append((kupe(aid), str(t), dg['tarih'], f'{tb}g'))

# 6) kontrol_tarihi sırası (SQL: rapor (l))
for r in toh:
    if r.get('kontrol_tarihi') and d(r['kontrol_tarihi']) <= d(r['tarih']):
        bul['KONTROL_SIRA_BOZUK'].append((kupe(r['hayvan_id']), r['tarih'], r['kontrol_tarihi']))
    if r.get('dogum_tarihi') and d(r['dogum_tarihi']) < d(r['tarih']):
        bul['PLAN_DOGUM_ONCE'].append((kupe(r['hayvan_id']), r['tarih'], r['dogum_tarihi']))

# 7) aynı buzağı kupeye iki doğum kaydı (SQL: rapor (e))
by_yavru = defaultdict(list)
for r in dog:
    if r.get('yavru_kupe') and not is_test(r.get('yavru_kupe')): by_yavru[str(r['yavru_kupe']).strip()].append(r)
for yk, rs in by_yavru.items():
    if len(rs) > 1 and yk:
        bul['BUZAGI_CIFT_DOGUM'].append((yk, [(kupe(x['anne_id']), x['tarih']) for x in rs]))

# 8) "Doğum Yaptı" öksüzleri: 240-320 gün penceresinde dogum olayı yok (SQL: rapor (n))
for r in toh:
    h = by_id.get(r.get('hayvan_id'), {})
    if not r.get('sonuc') or 'doğum' not in str(r['sonuc']).lower(): continue
    if is_test(h.get('kupe_no')): continue
    t = d(r['tarih'])
    var = any(dg.get('anne_id') == r['hayvan_id'] and t and d(dg['tarih']) and 240 <= (d(dg['tarih']) - t).days <= 320 for dg in dog)
    if not var:
        bul['TOH_OKSUZ_DOGUM_SONUCU'].append((h.get('kupe_no'), r['tarih']))

# 9) created_at sinyali: swap-yakınlık (|created − swap(tarih)| ≤ 7g) ve dağılım
tab = [('dogum', r, r['tarih'], kupe(r['anne_id'])) for r in dog if not is_test(r.get('yavru_kupe'))]
tab += [('tohumlama', r, r['tarih'], kupe(r['hayvan_id'])) for r in toh]
tab += [('kizginlik', r, r['tarih'], kupe(r['hayvan_id'])) for r in kiz]
tab += [('vaka', r, r['start_date'], kupe(r['animal_id'])) for r in cases]
tab += [('uygulama', r, r['tarih'], kupe(r['hayvan_id'])) for r in uyg]
ink = 0; normal = 0; strong = []
for tn, r, tar, kim in tab:
    c = cdate(r)
    if not tar or c in IMPORT: continue
    ink += 1
    x = d(tar); s = sw(x); gap = (x - d(c)).days
    if s and abs((s - d(c)).days) <= 7: strong.append((tn, kim, tar, c, f'swap={s}'))
    elif abs(gap) <= 7: normal += 1

print(f"created_at: incelenen {ink} (import dışı) | normal-yakın(<=7g): {normal} | GÜÇLÜ-SWAP ŞÜPHESİ: {len(strong)}")
for x in strong: print('  ', x)
print()
for k in ['GELECEK','ANNE_COK_GENC','ANNE_CAKISMA','MUKEERRER_KUPE','TOH_DOGUM_TERS_ADAY','TOH_DOGUM_DISINDA','KONTROL_SIRA_BOZUK','PLAN_DOGUM_ONCE','BUZAGI_CIFT_DOGUM','TOH_OKSUZ_DOGUM_SONUCU']:
    v = bul.get(k, [])
    print(f'## {k}: {len(v)}')
    for x in v: print('  ', x)
