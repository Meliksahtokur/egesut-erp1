#!/usr/bin/env python3
"""W3 dogum-tarih denetimi — defter karsilastirmasi (son revizyon, commit 1cc569a sonrasi).

Girdi: canli prod'dan Mgmt API /database/query ile cekilen SELECT sonacları:
  hayvanlar.json, dogum.json  (cekim SQL'i: rapor §Kullanılan SQL (c))
Cikti: 52 defter satiri icin durum tablosu (rapor §Soru 2 tablosunun kaynagi).

Durumlar: UY=uyumlu, OY=tarih uyumlu ama kayit kusurlu, KY=kayit yok.
"""
import json, re, datetime as dt
from collections import defaultdict

D = '/home/melik/tmp/agents/w3/'

def load(n): return json.load(open(D + n))
hay = load('hayvanlar.json'); dog = load('dogum.json')

def norm_kupe(s):
    if s is None: return None
    s = str(s).strip().upper()
    if re.fullmatch(r'0*\d+', s): return str(int(s))
    return s or None

by_id = {h['id']: h for h in hay}
by_kupe = defaultdict(list); by_devlet = defaultdict(list); by_devlet4 = defaultdict(list)
for h in hay:
    k = norm_kupe(h.get('kupe_no'))
    if k: by_kupe[k].append(h)
    dk = norm_kupe(h.get('devlet_kupe'))
    if dk:
        by_devlet[dk].append(h)
        m = re.search(r'(\d{4})$', dk)
        if m: by_devlet4[m.group(1)].append(h)

def find_animal(token):
    """kupe_no | devlet_kupe | devlet son-4 | tireli tokenin son segmenti."""
    t = norm_kupe(token)
    if not t: return []
    cands = list(by_kupe.get(t, []))
    seen = {h['id'] for h in cands}
    for h in by_devlet.get(t, []):
        if h['id'] not in seen: cands.append(h); seen.add(h['id'])
    if re.fullmatch(r'\d{4}', t):
        for h in by_devlet4.get(t, []):
            if h['id'] not in seen: cands.append(h); seen.add(h['id'])
    for seg in re.split(r'[-\s]+', token):          # '1940-5621' -> '5621' de dene
        s = norm_kupe(seg)
        if not s or s == t: continue
        for h in by_kupe.get(s, []):
            if h['id'] not in seen: cands.append(h); seen.add(h['id'])
    return cands

def d(s): return dt.date.fromisoformat(s[:10]) if s else None
def cins_db(v):
    v = (v or '').strip().lower()
    return 'D' if v.startswith('d') else ('E' if v.startswith('e') else '?')

LEDGER = [  # (anne, dd.mm.yyyy, düve|dana, buzağı, not) — görev zarfından birebir
 ('156','05.09.2025','düve','32',''),('185','08.09.2025','dana','?',''),('188','08.09.2025','düve','?',''),
 ('1940-5621','15.09.2025','dana','33','₺'),('145','17.09.2025','dana','34','₺'),('177','17.09.2025','dana','35','₺'),
 ('142','06.10.2025','düve','36',''),('153','08.10.2025','düve','37','ex'),('182','14.10.2025','düve','38',''),
 ('107','19.10.2025','dana','39',''),('Küpesiz düve','21.10.2025','dana','40','₺'),('008','29.10.2025','dana','41','₺'),
 ('167','02.11.2025','dana','42','₺'),('178','03.11.2025','dana','43',''),('162','07.11.2025','dana','44',''),
 ('197','09.11.2025','düve','45',''),('191','13.11.2025','düve','46',''),('155','13.11.2025','dana','47',''),
 ('5708','15.11.2025','dana','48',''),('2045','16.11.2025','dana','49',''),('179','16.11.2025','düve','50','ex'),
 ('195','17.11.2025','düve','51',''),('181','23.11.2025','dana','52','ex'),('199','29.11.2025','dana','53',''),
 ('147','03.12.2025','dana','54',''),('196','04.12.2025','düve','55',''),('101','08.12.2025','düve','56',''),
 ('5638','09.12.2025','düve','57','ex'),('Minik panda','12.12.2025','dana','58','ex'),('5748','14.12.2025','dana','59',''),
 ('7125','15.12.2025','dana','60',''),('1956','18.12.2025','düve','61',''),('154','23.12.2025','düve','62',''),
 ('159','23.12.2025','düve','63','ex'),('187','12.01.2026','dana','64',''),('161','17.01.2026','dana','65',''),
 ('189','02.02.2026','dana','66','ex'),('106','03.02.2026','dana','xx (erken doğum)','ex'),
 ('141','05.02.2026','dana','67',''),('176','06.02.2026','düve','68',''),('152','07.02.2026','düve','69',''),
 ('115','09.02.2026','dana','70','ex'),('134','10.02.2026','dana','71',''),('175','15.02.2026','dana','72','ex'),
 ('183','16.02.2026','dana','73',''),('121','19.02.2026','düve','74',''),('146','19.03.2026','düve','75',''),
 ('192','19.03.2026','dana','76',''),('901','08.04.2026','düve','77',''),('901','08.04.2026','düve','78','ikiz'),
 ('173','14.04.2026','düve','79',''),('180','16.04.2026','dana','80',''),
]

dog_by_yavru = defaultdict(list)
for r in dog: dog_by_yavru[norm_kupe(r.get('yavru_kupe'))].append(r)
CINS = {'düve':'D','dana':'E'}

rows = []
for anne_tok, tarih_tr, cins_ledger, buz, notu in LEDGER:
    dd, mm, yy = map(int, tarih_tr.split('.'))
    led = dt.date(yy, mm, dd)
    led_swap = dt.date(yy, dd, mm) if dd <= 12 and dd != mm else None
    led_cins = CINS[cins_ledger]
    notlar = []
    buz_key = norm_kupe('xx' if buz.startswith('xx') else buz)  # 'xx (erken doğum)' -> 'xx'
    anner = find_animal(anne_tok)
    anne = anner[0] if len(anner) == 1 else None
    if len(anner) > 1: notlar.append(f"anne belirsiz ({len(anner)} aday)")
    evs = sorted(dog_by_yavru.get(buz_key, []), key=lambda r: r['tarih'])
    if not evs and anne:
        evs = [r for r in dog if r.get('anne_id') == anne['id'] and d(r['tarih']) in (led, led_swap)]
    calf_list = by_kupe.get(buz_key, [])
    calf = calf_list[0] if calf_list else None
    if len(calf_list) > 1: notlar.append(f"MÜKERRER hayvan kaydı kupe {buz} ({len(calf_list)} satır)")
    status = None; db_tarih = None
    if not evs:
        if calf and calf.get('dogum_tarihi'):
            db_tarih = calf['dogum_tarihi'][:10]
            if d(db_tarih) == led: status = 'OY'; notlar.append('dogum olay kaydı YOK')
            elif led_swap and d(db_tarih) == led_swap: status = 'OY'; notlar.append('GÜN-AY TERS + dogum olay kaydı YOK')
            else: status = 'OY'; notlar.append('TARİH FARKLI + dogum olay kaydı YOK')
        else:
            status = 'KY'
    else:
        ev = evs[0]; db_tarih = ev['tarih'][:10]
        if len(evs) > 1: notlar.append(f"ÇİFT doğum kaydı ({len(evs)})")
        if d(db_tarih) == led: status = 'UY'
        elif led_swap and d(db_tarih) == led_swap: status = 'OY'; notlar.append('GÜN-AY TERS')
        else: status = 'OY'; notlar.append('TARİH FARKLI')
        if anne and ev.get('anne_id') != anne['id']:
            db_anne = by_id.get(ev.get('anne_id'), {})
            notlar.append(f"ANNE FARKLI: DB anne={db_anne.get('kupe_no') or '?'}")
        if ev.get('anne_id') is None: notlar.append('dogum kaydında anne_id NULL')
        elif ev.get('anne_id') not in by_id: notlar.append('dogum anne_id çözümlenemiyor')
    # hayvanlar.anne_id çapraz kontrolü (root revizyonu R1)
    if calf and anne is not None:
        if calf.get('anne_id') is None:
            notlar.append(f"hayvanlar.anne_id NULL ({anne['id'][:8]} olmalı)")
            if status == 'UY': status = 'OY'   # 32 ile aynı sınıf: anne bağlantısı kusurlu
        elif calf.get('anne_id') != anne['id']:
            notlar.append('hayvanlar.anne_id farklı')
            if status == 'UY': status = 'OY'
    elif calf and calf.get('anne_id') is None and status != 'KY':
        notlar.append('hayvanlar.anne_id NULL, defter annesi DB\'de yok')
    cinsler = []
    if evs: cinsler.append(('dogum.yavru_cins', cins_db(evs[0].get('yavru_cins'))))
    if calf: cinsler.append(('buzağı.cinsiyet', cins_db(calf.get('cinsiyet'))))
    if cinsler and all(c != led_cins for _, c in cinsler):
        if status == 'UY': status = 'OY'
        notlar.append('cinsiyet farklı')
    rows.append(dict(anne=anne_tok, led=led.isoformat(), led_cins=cins_ledger, buz=buz,
                     status=status, db_tarih=db_tarih,
                     db_cins='/'.join(f"{k}={v}" for k, v in cinsler) or '-',
                     calf_durum=(calf or {}).get('durum'), calf_id=(calf or {}).get('id'),
                     notu='; '.join(n for n in notlar if n) + (f' [{notu}]' if notu else '')))

from collections import Counter
print('ÖZET:', json.dumps(Counter(r['status'] for r in rows), ensure_ascii=False))
print()
for r in rows:
    print(f"| {r['anne']} | {r['led']} | {r['led_cins']} | {r['buz']} | {r['status']} | {r['db_tarih'] or '-'} | {r['db_cins']} | {r['calf_durum'] or '-'} | {r['notu'] or '-'} |")
