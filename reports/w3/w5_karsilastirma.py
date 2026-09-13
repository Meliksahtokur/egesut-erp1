#!/usr/bin/env python3
"""W5 — sahip tablosu ↔ saha defteri ↔ DB üç yönlü karşılaştırma (salt-okuma).

Girdi:
  - Tablo: W5 zarfındaki sahibin buzağı tablosu (aşağıda birebir).
  - Defter: W3 görev zarfındaki saha doğum defteri.
  - DB: Mgmt API SELECT çekimleri (/home/melik/tmp/agents/w3/):
    hayvanlar.json, dogum.json, tohumlama.json, w5-buzagi.json (buzağı tam satırlar),
    w5-vac.json (vaccination_log), kizginlik_log.json
Kabul: her tablo satırı çalıştırılmış sorgunun verisine dayanır (SQL: rapor §Kullanılan SQL).
"""
import json, re, datetime as dt
from collections import defaultdict

D = '/home/melik/tmp/agents/w3/'
def load(n): return json.load(open(D + n))
def d(s): return dt.date.fromisoformat(s[:10]) if s else None
def tr(s):  # '05.09.2025' -> date
    dd, mm, yy = map(int, s.split('.')); return dt.date(yy, mm, dd)

hay = load('hayvanlar.json'); dog = load('dogum.json'); toh = load('tohumlama.json')
vac = load('w5-vac.json'); buza = load('w5-buzagi.json'); kiz = load('kizginlik_log.json')
by_id = {h['id']: h for h in hay}
buz_row = {str(b['kupe_no']).strip(): b for b in buza}
def kupe(i): return (by_id.get(i) or {}).get('kupe_no') or i or '?'

# --- vaccination_log: buzağı bazına
vac_by_hayvan = defaultdict(list)
for v in vac: vac_by_hayvan[v['animal_id']].append(d(v['vaccination_date']))

# --- TABLO (sahibin elektronik tablosu, W5 zarfı birebir)
TABLO = [  # buzağı, tarih, cins, anne, aşı, durum, ölüm sebebi, ırk
 ('32','05.09.2025','Düve','156','','Canlı','',''),
 ('—','08.09.2025','Dana','185','','Canlı','',''),
 ('—','08.09.2025','Düve','188','','Canlı','',''),
 ('33','15.09.2025','Dana','1940-5621','+','Satıldı','',''),
 ('34','17.09.2025','Dana','145','+','Satıldı','',''),
 ('35','17.09.2025','Dana','177','+','Satıldı','',''),
 ('36','06.10.2025','Düve','142','++','Canlı','',''),
 ('37','08.10.2025','Düve','153','-','Öldü','Tendon Kontraktürü',''),
 ('38','14.10.2025','Düve','182','++','Canlı','',''),
 ('39','19.10.2025','Dana','107','-','Canlı','',''),
 ('40','21.10.2025','Dana','Küpesiz düve','-','Satıldı','',''),
 ('41','29.10.2025','Dana','8','-','Satıldı','',''),
 ('42','02.11.2025','Dana','167','-','Satıldı','',''),
 ('43','03.11.2025','Dana','178','-','Canlı','',''),
 ('44','07.11.2025','Dana','162','-','Canlı','',''),
 ('45','09.11.2025','Düve','197','-','Canlı','',''),
 ('46','13.11.2025','Düve','191','-','Canlı','',''),
 ('47','13.11.2025','Dana','155','-','Canlı','',''),
 ('48','15.11.2025','Dana','5708','+','Canlı','',''),
 ('49','16.11.2025','Dana','2045','+-','Canlı','',''),
 ('50','16.11.2025','Düve','179','-','Öldü','',''),
 ('51','17.11.2025','Düve','195','+-','Canlı','',''),
 ('52','23.11.2025','Dana','181','-','Öldü','',''),
 ('53','24.11.2025','Dana','199','-','Canlı','','Alaca'),
 ('54','28.11.2025','Dana','147','-','Canlı','',''),
 ('55','01.12.2025','Düve','196','-','Canlı','','Alaca'),
 ('56','02.12.2025','Düve','101','-','Canlı','','Red Holstein'),
 ('57','02.12.2025','Düve','5638','-','Öldü','','Red Holstein'),
 ('58','05.12.2025','Dana','Minik panda','-','Öldü','',''),
 ('59','09.12.2025','Dana','5748','+','Canlı','',''),
 ('60','12.12.2025','Dana','7125','+','Canlı','',''),
 ('61','12.12.2025','Düve','1956','+','Canlı','',''),
 ('62','20.12.2025','Düve','154','+','Canlı','','Alaca'),
 ('63','21.12.2025','Düve','159','+','Öldü','Gelişim Geriliği','Alaca'),
 ('64','27.12.2025','Dana','187','--','Canlı','',''),
 ('65','31.12.2025','Dana','161','--','Canlı','',''),
 ('66','04.01.2026','Dana','189','--','Canlı','',''),
 ('xx','15.02.2026','Dana','106','+','Öldü','Erken Doğum',''),
 ('67','03.01.2026','Dana','141','--','Canlı','',''),
 ('68','15.01.2026','Düve','176','--','Canlı','',''),
 ('69','17.01.2026','Düve','152','--','Canlı','',''),
 ('70','25.01.2026','Dana','115','--','Canlı','',''),
 ('71','04.02.2026','Dana','134','--','Canlı','',''),
 ('72','06.02.2026','Dana','175','--','Canlı','',''),
 ('73','09.02.2026','Dana','183','--','Canlı','',''),
 ('74','19.02.2026','Düve','121','--','Canlı','',''),
]

# --- DEFTER (W3 zarfı: buzağı -> tarih / cins / anne / durum-kodu)
DEFTER = {
 '32':('05.09.2025','D','156',''), '33':('15.09.2025','E','1940-5621','₺'),
 '34':('17.09.2025','E','145','₺'), '35':('17.09.2025','E','177','₺'),
 '36':('06.10.2025','D','142',''), '37':('08.10.2025','D','153','ex'),
 '38':('14.10.2025','D','182',''), '39':('19.10.2025','E','107',''),
 '40':('21.10.2025','E','Küpesiz düve','₺'), '41':('29.10.2025','E','008','₺'),
 '42':('02.11.2025','E','167','₺'), '43':('03.11.2025','E','178',''),
 '44':('07.11.2025','E','162',''), '45':('09.11.2025','D','197',''),
 '46':('13.11.2025','D','191',''), '47':('13.11.2025','E','155',''),
 '48':('15.11.2025','E','5708',''), '49':('16.11.2025','E','2045',''),
 '50':('16.11.2025','D','179','ex'), '51':('17.11.2025','D','195',''),
 '52':('23.11.2025','E','181','ex'), '53':('29.11.2025','E','199',''),
 '54':('03.12.2025','E','147',''), '55':('04.12.2025','D','196',''),
 '56':('08.12.2025','D','101',''), '57':('09.12.2025','D','5638','ex'),
 '58':('12.12.2025','E','Minik panda','ex'), '59':('14.12.2025','E','5748',''),
 '60':('15.12.2025','E','7125',''), '61':('18.12.2025','D','1956',''),
 '62':('23.12.2025','D','154',''), '63':('23.12.2025','D','159','ex'),
 '64':('12.01.2026','E','187',''), '65':('17.01.2026','E','161',''),
 '66':('02.02.2026','E','189','ex'), 'xx':('03.02.2026','E','106','ex'),
 '67':('05.02.2026','E','141',''), '68':('06.02.2026','D','176',''),
 '69':('07.02.2026','D','152',''), '70':('09.02.2026','E','115','ex'),
 '71':('10.02.2026','E','134',''), '72':('15.02.2026','E','175','ex'),
 '73':('16.02.2026','E','183',''), '74':('19.02.2026','D','121',''),
}
CINS = {'Düve':'D','Dana':'E'}
DBDURUM = {'Aktif':'Canlı','Satıldı':'Satıldı','Ölü':'Öldü'}

# --- anne eşleme (W3 mantığı): kupe | devlet | devlet son-4
def norm_kupe(s):
    if s is None: return None
    s = str(s).strip().upper()
    return str(int(s)) if re.fullmatch(r'0*\d+', s) else (s or None)
by_kupe = {}
by_dev4 = {}
for h in hay:
    k = norm_kupe(h.get('kupe_no'))
    if k: by_kupe[k] = h
    dk = norm_kupe(h.get('devlet_kupe'))
    if dk:
        m = re.search(r'(\d{4})$', dk)
        if m: by_dev4[m.group(1)] = h
def find_anne(tok):
    t = norm_kupe(tok)
    if not t: return None
    if t in by_kupe: return by_kupe[t]
    for seg in re.split(r'[-\s]+', str(tok)):
        s = norm_kupe(seg)
        if s and s in by_kupe: return by_kupe[s]
    return by_dev4.get(t)

toh_by_hayvan = defaultdict(list)
for r in toh:
    if r.get('hayvan_id') and r.get('tarih'): toh_by_hayvan[r['hayvan_id']].append(d(r['tarih']))

def anne_marker(tok, db_anne_kupe):
    """Tablo/defter anne tokenu DB anne kupe'siyle uyumlu mu? (W5 root revizyonu)
    'OK' = birebir ya da devlet kupe son-4; 'DB-NULL' = DB'de anne bağlantısı yok;
    'FARK' = DB'de başka anne yazılı."""
    if not db_anne_kupe or db_anne_kupe == '-': return 'DB-NULL'
    h = by_kupe.get(norm_kupe(db_anne_kupe))
    dk = norm_kupe((h or {}).get('devlet_kupe')) or ''
    for seg in re.split(r'[-\s]+', str(tok)):
        s = norm_kupe(seg)
        if not s: continue
        if s == norm_kupe(db_anne_kupe): return 'OK'
        if re.fullmatch(r'\d{4}', s) and dk.endswith(s): return 'OK(son4)'
    return 'FARK'

def gebelik_kanit(anne_id, cand1, cand2):
    """anneın aday doğumdan önceki SON tohumlaması -> her iki aday için gebelik günü."""
    if not anne_id: return None
    tl = sorted(t for t in toh_by_hayvan.get(anne_id, []) if t)
    out = {}
    for ad in (cand1, cand2):
        once = [t for t in tl if t <= ad]
        out[ad.isoformat()] = f"{(ad - once[-1]).days}g (toh {once[-1]})" if once else 'toh yok'
    return out

def durum_db(b):
    if not b: return None
    return DBDURUM.get((b.get('durum') or '').strip(), b.get('durum'))

rows = []
for tk, ttarih, tcins, tanne, tasi, tdurum, tolum, tirk in TABLO:
    key = tk
    led_t, led_c, led_anne, led_not = DEFTER.get(key, (None,None,None,None))
    tab_d = tr(ttarih); led_d = tr(led_t) if led_t else None
    b = buz_row.get(key)
    db_d = b.get('dogum_tarihi')[:10] if b else None
    db_d = d(db_d) if db_d else None
    dog_ev = next((r for r in dog if str(r.get('yavru_kupe','')).strip() == key), None)
    if db_d is None and dog_ev: db_d = d(dog_ev['tarih'])
    db_anne = None
    if dog_ev and dog_ev.get('anne_id'): db_anne = kupe(dog_ev['anne_id'])
    elif b and b.get('anne_id'): db_anne = kupe(b['anne_id'])
    # doğum kaydında anne NULL ama defter/tablo anneye eşleme (W3 eşlemesi)
    anne_h = find_anne(tanne)
    durum = None
    if db_d is None:
        durum = "DB'DE YOK"
    else:
        s = []
        if db_d == led_d and db_d == tab_d: durum = 'ÜÇÜ UYUMLU'
        elif db_d == led_d: durum = 'DB=DEFTER≠TABLO'
        elif db_d == tab_d: durum = 'DB=TABLO≠DEFTER'
        else: durum = 'ÜÇÜ FARKLI'
    # bağımsız kanıt (yalnız tarih çelişkisinde)
    kanit = ''
    if db_d and db_d != tab_d and anne_h:
        g = gebelik_kanit(anne_h['id'], tab_d, db_d)
        # hangisi 260-300 penceresinde?
        v = []
        for ad, metin in g.items():
            try: gun = int(metin.split('g')[0])
            except Exception: v.append(f"{ad}: {metin}"); continue
            v.append(f"{ad}: {gun}g {'✓pencerede' if 260 <= gun <= 300 else '✗pencere-dışı'} ({metin.split('(')[1][:-1] if '(' in metin else 'toh yok'})")
        kanit = '; '.join(v)
    # aşı tarihleri hangi tarihi yansıtıyor (DB'den türemişse offset sabit çıkar)
    vacs = sorted(vac_by_hayvan.get(b['id'], [])) if b else []
    vac_ofs = ','.join(f"+{(v - db_d).days}" for v in vacs[:4]) if (vacs and db_d) else ''
    rows.append(dict(tk=tk, tab=tab_d.isoformat(), led=led_d.isoformat() if led_d else '-',
                     db=db_d.isoformat() if db_d else '-', durum=durum, kanit=kanit,
                     tcins=CINS[tcins], led_c=led_c, db_cins=(b or {}).get('cinsiyet','')[:1],
                     tanne=tanne, led_anne=led_anne, db_anne=db_anne or '-',
                     anne_m=anne_marker(tanne, db_anne),
                     tdurum=tdurum, leddurum=('Satıldı' if led_not=='₺' else 'Öldü' if led_not=='ex' else 'Canlı'),
                     dbdurum=durum_db(b) or '-', tolum=tolum, tirk=tirk,
                     dbirk=(b or {}).get('irk') or '-', db_yirk=(dog_ev or {}).get('yavru_irk') or '-',
                     vac=len(vacs), vac_ofs=vac_ofs,
                     devlet=(b or {}).get('devlet_kupe') or '-'))

from collections import Counter
print('DURUM DAĞILIMI:', json.dumps(Counter(r['durum'] for r in rows), ensure_ascii=False))
print()
for r in rows:
    print(f"| {r['tk']} | {r['tab']} | {r['led']} | {r['db']} | {r['durum']} | {r['kanit']} |")
print()
print('== AŞI TARİHİ OFFSETLERİ (DB doğumuna göre; sabit desen = protokolden üretilme):')
for r in rows:
    if r['vac_ofs']: print(f"   {r['tk']}: {r['vac_ofs']} (toplam {r['vac']} kayıt)")
print()
print('== ANNE KARŞILAŞTIRMASI (T/L tokenı ↔ DB):')
for r in rows:
    if r['anne_m'] != 'OK': print(f"   {r['tk']}: T/L={r['tanne']} ↔ DB={r['db_anne']} → {r['anne_m']}")
print()
print('== IRK İKİ YÖNLÜ (tablo boş ama DB dolu dahil):')
for r in rows:
    if r['tirk'] or (r['dbirk'] and r['dbirk'] != '-'):
        print(f"   {r['tk']}: T={r['tirk'] or '—'} | DB.irk={r['dbirk']} | DB.yavru_irk={r.get('db_yirk') or '-'}")
print()
print('== Q3/Q4 ÇEŞİTLİ:')
for r in rows:
    fark = []
    if r['tcins'] != r['led_c'] or r['tcins'] != r['db_cins']: fark.append(f"cins T:{r['tcins']}/L:{r['led_c']}/DB:{r['db_cins']}")
    if r['tdurum'] != r['leddurum'] or r['tdurum'] != r['dbdurum']: fark.append(f"durum T:{r['tdurum']}/L:{r['leddurum']}/DB:{r['dbdurum']}")
    if r['tolum']: fark.append(f"ölüm sebebi T:{r['tolum']}")
    if r['tirk']: fark.append(f"ırk T:{r['tirk']}/DB:{r['dbirk']}")
    if r['tk'] in ('40','41','58'): fark.append(f"anne T:{r['tanne']}/L:{r['led_anne']}/DB:{r['db_anne']}")
    if fark: print(f"   {r['tk']}: " + ' | '.join(fark))
