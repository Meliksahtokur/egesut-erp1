// tests/unit/ui-pure.test.js
// js/ui.js SADECE saf/hesaplanabilir fonksiyonlarının birim testleri.
// DOM-ağır render kısımları E2E kapsamında — burada dışarıdan bakılmaz.
//
// Kapsam: yasHesapla, band, _dashVacAlerts, _yeniDogumGun,
//         _durumClr, _durumTxt, renderSeansGupAyrac yerine renderSeansGrupAyrac
//
// Not: _dashVacAlerts ve renderSeansGrupAyrac, ui.js'te tanımlı olmayan
// global esc/escAttr/fmtTarih kullanır (bunlar js/utils/helpers.js'ten gelir).
// helpers.js'in esc()'i DOM'a bağımlı olduğundan (document.createElement),
// tarayıcı davranışının SAF aynası enjekte edilir: textContent→innerHTML
// & < > kaçırır, tırnak kaçırmaz. escAttr/fmtTarih helpers.js'tekiyle birebir.
const test = require('node:test');
const assert = require('node:assert');
const fc = require('fast-check');
const { loadBrowserModule } = require('./support/loadModule.js');
const { fmtTarih } = require('../../js/utils/helpers.js');

// helpers.js esc()'inin saf aynası (tarayıcı: div.textContent=s; div.innerHTML)
const escMirror = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
// helpers.js escAttr()'ının birebir kopyası (kaynak: js/utils/helpers.js:31)
const escAttrMirror = (s) => String(s ?? '')
  .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
  .replace(/</g, '&lt;').replace(/>/g, '&gt;');

// Tam modülü BİR KEZ yükle (8k satır derleme maliyeti), sandbox'ı testlerde yeniden kullan.
const { sandbox, exposed } = loadBrowserModule('js/ui.js', {
  extra: { esc: escMirror, escAttr: escAttrMirror, fmtTarih },
  expose: ['_katTipMap', 'OZEL_ALT_TIPLER'],
});
const {
  yasHesapla, band, _dashVacAlerts, _yeniDogumGun,
  _durumClr, _durumTxt, renderSeansGrupAyrac, _asiVaccineCoz, _sessizGrupla, _asiStokKalanlar,
} = sandbox;

// ── Tarih yardımcıları (yerel takvim; yasHesapla new Date() ile yerel çalışır) ──
function toLocalIso(d) {
  return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
}
function daysAgoIso(n) { const d = new Date(); d.setDate(d.getDate() - n); return toLocalIso(d); }
// n ay önce, istenen ay-günü (ay kısa günü kelepçelenir: 31 → 30/28/29)
function monthsBackIso(n, dayOfMonth) {
  const now = new Date();
  const total = now.getFullYear() * 12 + now.getMonth() - n;
  const y = Math.floor(total / 12);
  const m = ((total % 12) + 12) % 12;
  const len = new Date(y, m + 1, 0).getDate();
  const day = Math.max(1, Math.min(dayOfMonth, len));
  return y + '-' + String(m + 1).padStart(2, '0') + '-' + String(day).padStart(2, '0');
}
function monthLenBack(n) { // now'dan n ay önceki ayın uzunluğu
  const now = new Date();
  const total = now.getFullYear() * 12 + now.getMonth() - n;
  return new Date(Math.floor(total / 12), ((total % 12) + 12) % 12 + 1, 0).getDate();
}

// ── yasHesapla'nın AYNA implementasyonu (oracle DEĞİL — regresyon kilidi) ──
// Kaynak algoritmayı (js/ui.js:70-79) birebir yeniden uygular: aynı Y/M farkı +
// gün-ödünç (önceki ayın uzunluğu) + ay-ödünç (12) kaskadı. Kaynak davranış
// değişirse bu test kırılır — yanlışlığı kanıtlamaz, kararlılığı kilitler.
function yasMirror(dogumTarihi, now = new Date()) {
  if (!dogumTarihi) return '';
  const d = new Date(dogumTarihi);
  let y = now.getFullYear() - d.getFullYear();
  let m = now.getMonth() - d.getMonth();
  let gn = now.getDate() - d.getDate();
  if (gn < 0) { m--; gn += new Date(now.getFullYear(), now.getMonth(), 0).getDate(); }
  if (m < 0) { y--; m += 12; }
  if (y > 0) return `${y} yıl ${m} ay`;
  if (m > 0) return `${m} ay ${gn} gün`;
  return `${gn} gün`;
}
// Yaş yazısını toplam ay sayısına indirger ('X gün' → 0 ay; 'X ay Y gün' → X; 'X yıl Y ay' → X*12+Y)
function totalAy(yas) {
  let m = /^(\d+) yıl (\d+) ay$/.exec(yas); if (m) return Number(m[1]) * 12 + Number(m[2]);
  m = /^(\d+) ay \d+ gün$/.exec(yas); if (m) return Number(m[1]);
  return 0;
}

// ═══════════════════════════════════════════════════════════════
// yasHesapla (js/ui.js:70)
// ═══════════════════════════════════════════════════════════════
test('yasHesapla: boş/null/undefined girdi → boş string', () => {
  assert.strictEqual(yasHesapla(''), '');
  assert.strictEqual(yasHesapla(null), '');
  assert.strictEqual(yasHesapla(undefined), '');
  assert.strictEqual(yasHesapla(0), '');
});

test('yasHesapla: bugünün tarihi → "0 gün"', () => {
  assert.strictEqual(yasHesapla(toLocalIso(new Date())), '0 gün');
});

test('yasHesapla: dün → "1 gün" (ay sınırı geçse bile)', () => {
  // setDate geri sarması ay/yıl sınırını kendisi halleder; algoritma
  // ay-sınırında gün-ödünç alarak yine 1 verir.
  assert.strictEqual(yasHesapla(daysAgoIso(1)), '1 gün');
});

test('yasHesapla: tam 14 ay önce → "1 yıl 2 ay"', () => {
  // Aynı ay-günü korunur (kısa ayda kelepçelenir); kelepçeleme gn>=0 garantiler,
  // m=2 ve y=1 sabit kalır → çıktı koşucu tarihinden bağımsız "1 yıl 2 ay".
  assert.strictEqual(yasHesapla(monthsBackIso(14, new Date().getDate())), '1 yıl 2 ay');
});

test('yasHesapla: ~2,5 ay önce → "2 ay X gün" (X = gün farkı)', () => {
  const now = new Date();
  const iso = monthsBackIso(2, now.getDate() - 15);
  const day = Number(iso.slice(8, 10));
  const beklenenGn = now.getDate() - day; // 15 (kısa ay kelepçesinde daha az)
  assert.strictEqual(yasHesapla(iso), `2 ay ${beklenenGn} gün`);
  assert.ok(beklenenGn >= 0 && beklenenGn <= 15);
});

test('yasHesapla: gün-ödünç dalı — doğum günü > bugünün ay-günü', (t) => {
  // Geçmişte, uzunluğu bugünkü ay-gününden BÜYÜK bir ay bul (ör. bugün 15'i,
  // geçen ay 31 çeken). Oraya bugünkü gün+1 yaz → gn<0 → önceki aydan gün ödünç.
  const now = new Date();
  let b = null;
  for (let i = 1; i <= 12; i++) {
    if (monthLenBack(i) > now.getDate()) { b = i; break; }
  }
  if (b === null) {
    // Ayın 31'inde geçmiş hiçbir ay 31+ gün çekmez → dal takvimsel olarak erişilemez.
    t.skip(`Bugün ayın ${now.getDate()}'i — geçmişte daha uzun ay yok, gn<0 dalı üretilemez (fast-check ayna testi kapsar)`);
    return;
  }
  const iso = monthsBackIso(b, now.getDate() + 1);
  const oncekiAyLen = new Date(now.getFullYear(), now.getMonth(), 0).getDate(); // now'un öncesindeki ay
  const effAy = b - 1;           // 1 ay gün-ödünç ile düşer
  const gn = oncekiAyLen - 1;    // gn = -1 + önceki ay uzunluğu
  const beklenen = effAy >= 1 ? `${effAy} ay ${gn} gün` : `${gn} gün`;
  assert.strictEqual(yasHesapla(iso), beklenen);
});

test('yasHesapla: ay-ödünç (yıl borrow) dalı — geçen yılın Aralık ayı', (t) => {
  const now = new Date();
  if (now.getMonth() === 11) {
    t.skip('Aralık ayında ham m<0 üretilemez (ham m = 11 - birthM ≥ 0); dal başka ay üzerinde zaten çalışıyor');
    return;
  }
  const iso = (now.getFullYear() - 1) + '-12-' + String(now.getDate()).padStart(2, '0');
  // Ham: y=1, m = nowM - 11 < 0 → ödünç: y=0, m = nowM+1, gn=0
  assert.strictEqual(yasHesapla(iso), `${now.getMonth() + 1} ay 0 gün`);
});

test('yasHesapla: property — çıktı her zaman üç formattan birine uyar', () => {
  fc.assert(fc.property(fc.integer({ min: 0, max: 3650 }), (n) => {
    assert.match(yasHesapla(daysAgoIso(n)), /^(?:\d+ yıl \d+ ay|\d+ ay \d+ gün|\d+ gün)$/);
  }));
});

test('yasHesapla: property — ayna algoritma ile birebir aynı (regresyon kilidi)', () => {
  // DİKKAT: yasMirror kaynak algoritmanın kopyasıdır — hata bulmaz, kararlılığı kilitler.
  fc.assert(fc.property(fc.integer({ min: 0, max: 7300 }), (n) => {
    const iso = daysAgoIso(n);
    assert.strictEqual(yasHesapla(iso), yasMirror(iso));
  }));
});

test('yasHesapla: property — monotonluk; erken doğum asla daha küçük toplam-ay yaş vermez', () => {
  fc.assert(fc.property(
    fc.integer({ min: 0, max: 3650 }),
    fc.integer({ min: 0, max: 3650 }),
    (a, c) => {
      const [azOnce, cokOnce] = a <= c ? [a, c] : [c, a]; // azOnce gün önce = GEÇ doğum, cokOnce = ERKEN doğum
      const erken = yasHesapla(daysAgoIso(cokOnce));
      const gec = yasHesapla(daysAgoIso(azOnce));
      assert.ok(totalAy(erken) >= totalAy(gec), `erken(${erken}) >= gec(${gec}) — ${cokOnce} vs ${azOnce} gün`);
    }
  ));
});

// ═══════════════════════════════════════════════════════════════
// band (js/ui.js:67)
// ═══════════════════════════════════════════════════════════════
test('band: şablon birebir — sarmalayıcı + cls + title + content', () => {
  assert.strictEqual(
    band('red', 'Başlık', 'İçerik'),
    '<div class="aband"><div class="aband-hdr red">Başlık</div><div class="aband-body">İçerik</div></div>'
  );
});

test("band: ŞÜPHELİ DAVRANIŞ — title/content kaçırılmadan (escape'siz) ara girer", () => {
  // ŞÜPHELİ DAVRANIŞ: band() html-escape yapmaz — çağıranlar önceden esc() ile
  // kaçırmak zorunda. En az bir çağrı yeri bunu doğru yapıyor (_dashVacAlerts,
  // ui.js:149: esc(v.vaxName)); ama örn. _dashBands births60 satırı (ui.js:196)
  // ${b.anne_id} ve ${b.tarih} ham girer. Burada MEVCUT davranış kilitlenir.
  const out = band('x', '<b>T&"', '<script>alert(1)</script>');
  assert.ok(out.includes('<b>T&"'));
  assert.ok(out.includes('<script>alert(1)</script>'));
  assert.ok(!out.includes('&lt;'));
  assert.ok(!out.includes('&amp;'));
});

test('band: property — her girdi için sarmalayıcı ön/son ek ve ham içerik korunur', () => {
  fc.assert(fc.property(fc.string({ maxLength: 20 }), fc.string({ maxLength: 20 }), (t1, c1) => {
    const out = band(t1, c1);
    assert.ok(out.startsWith('<div class="aband"><div class="aband-hdr '));
    assert.ok(out.endsWith('</div></div>'));
    assert.ok(out.includes(t1));
    assert.ok(out.includes(c1));
  }));
});

test('band: boş title/content dahi geçerli şablon üretir', () => {
  assert.strictEqual(
    band('', '', ''),
    '<div class="aband"><div class="aband-hdr "></div><div class="aband-body"></div></div>'
  );
});

// ═══════════════════════════════════════════════════════════════
// _dashVacAlerts (js/ui.js:107) — `today` parametre aldığı için tam deterministik
// ═══════════════════════════════════════════════════════════════
const BUGUN = '2026-08-31';
const VAX = [{ id: 'v1', name: 'Şap Aşısı' }, { id: 'v2', name: 'Brucella' }];
const log = (o) => ({ vaccination_date: '2026-06-01', ...o });

test('_dashVacAlerts: null/boş vaxLogs → boş string', () => {
  assert.strictEqual(_dashVacAlerts(BUGUN, null, VAX), '');
  assert.strictEqual(_dashVacAlerts(BUGUN, [], VAX), '');
});

test('_dashVacAlerts: (animal_id, vaccine_id) başına EN YENİ kayıt kazanır', () => {
  const logs = [
    log({ id: 'eski', animal_id: 'A1', vaccine_id: 'v1', vaccination_date: '2026-05-01', next_due_date: '2026-09-01' }),
    log({ id: 'yeni', animal_id: 'A1', vaccine_id: 'v1', vaccination_date: '2026-06-01', next_due_date: '2026-10-01' }),
  ];
  const kopya = JSON.parse(JSON.stringify(logs));
  const out = _dashVacAlerts(BUGUN, logs, VAX);
  assert.ok(out.includes(fmtTarih('2026-10-01')), 'yeni kaydın next_due_date tarihi görünmeli');
  assert.ok(!out.includes(fmtTarih('2026-09-01')), 'eski kaydın next_due_date tarihi GÖRÜNMEMELİ');
  assert.ok(out.includes('(1)'), 'tek (animal,vaccine) çifti → toplam 1');
  // Girdi dizisi mutasyona uğramaz (filter+sort kopya üzerinde)
  assert.deepStrictEqual(logs, kopya);
});

test('_dashVacAlerts: ertelendi (dismissed) kayıtlar tamamen atlanır', () => {
  assert.strictEqual(_dashVacAlerts(BUGUN, [
    log({ id: 'e1', animal_id: 'A1', vaccine_id: 'v1', ertelendi: true, next_due_date: '2026-09-05' }),
  ], VAX), '');

  // Ertelenen kayıt DAHA YENİ olsa bile kazanan non-dismissed olan olur
  const out = _dashVacAlerts(BUGUN, [
    log({ id: 'aktif', animal_id: 'A2', vaccine_id: 'v1', vaccination_date: '2026-05-01', next_due_date: '2026-09-05' }),
    log({ id: 'erteli', animal_id: 'A2', vaccine_id: 'v1', vaccination_date: '2026-07-01', ertelendi: true, next_due_date: '2026-12-05' }),
  ], VAX);
  assert.ok(out.includes(fmtTarih('2026-09-05')));
  assert.ok(!out.includes(fmtTarih('2026-12-05')));
});

test('_dashVacAlerts: MEVCUT DAVRANIŞ — en yeni kaydın next_due_date yoksa çift düşer (eski kaydın ki de gösterilmez)', () => {
  // Filtre latest-wins SONRASı uygulanır: en yeni kayıtta next_due_date yoksa,
  // eski kayıtta olsa bile o çift listeden silinir. Bilinçli tasarım olabilir
  // (eski kaydın due tarihi bayat); mevcut davranış kilitlenir.
  assert.strictEqual(_dashVacAlerts(BUGUN, [
    log({ id: 'eski-dueli-var', animal_id: 'A1', vaccine_id: 'v1', vaccination_date: '2026-05-01', next_due_date: '2026-09-01' }),
    log({ id: 'yeni-dueli-yok', animal_id: 'A1', vaccine_id: 'v1', vaccination_date: '2026-06-01' }),
  ], VAX), '');
});

test('_dashVacAlerts: gecikmiş aşı → kırmızı bant + "gecikti" metni', () => {
  const out = _dashVacAlerts(BUGUN, [
    log({ id: 'x', animal_id: 'A1', vaccine_id: 'v1', next_due_date: '2026-08-30' }), // 1 gün gecikmiş
    log({ id: 'y', animal_id: 'A2', vaccine_id: 'v2', next_due_date: '2026-08-21' }), // 10 gün gecikmiş
  ], VAX);
  assert.ok(out.includes('aband-hdr red'), 'gecikme varsa priority red');
  assert.ok(out.includes('1 gün gecikti'));
  assert.ok(out.includes('10 gün gecikti'));
  assert.ok(out.includes('Şap Aşısı'));
  assert.ok(out.includes('Brucella'));
});

test('_dashVacAlerts: bu hafta (0-7 gün) → amber bant + "kaldı" metni', () => {
  const out = _dashVacAlerts(BUGUN, [
    log({ id: 'x', animal_id: 'A1', vaccine_id: 'v1', next_due_date: '2026-09-03' }), // 3 gün kaldı
  ], VAX);
  assert.ok(out.includes('aband-hdr amber'));
  assert.ok(out.includes('3 gün kaldı'));
  assert.ok(!out.includes('gecikti'));
});

test('_dashVacAlerts: 8-30 gün → mavi bant; en yakın önce sıralanır', () => {
  const out = _dashVacAlerts(BUGUN, [
    log({ id: 'uzak', animal_id: 'A1', vaccine_id: 'v1', next_due_date: '2026-09-30' }), // 30 gün
    log({ id: 'yakin', animal_id: 'A2', vaccine_id: 'v2', next_due_date: '2026-09-10' }), // 10 gün
  ], VAX);
  assert.ok(out.includes('aband-hdr blue'));
  const iYakin = out.indexOf(fmtTarih('2026-09-10'));
  const iUzak = out.indexOf(fmtTarih('2026-09-30'));
  assert.ok(iYakin !== -1 && iUzak !== -1 && iYakin < iUzak, 'gün küçüğü (yakın) önce render edilir');
});

test('_dashVacAlerts: bilinmeyen vaccine_id → aşı adı "?" düşer; vaccines null bile kabul', () => {
  const out1 = _dashVacAlerts(BUGUN, [
    log({ id: 'x', animal_id: 'A1', vaccine_id: 'yok', next_due_date: '2026-09-03' }),
  ], VAX);
  assert.ok(out1.includes('>?<'), 'vaxMap içinde olmayan id → esc("?") = "?"');

  const out2 = _dashVacAlerts(BUGUN, [
    log({ id: 'x', animal_id: 'A1', vaccine_id: 'v1', next_due_date: '2026-09-03' }),
  ], null);
  assert.ok(out2.includes('>?<'), 'vaccines null → (vaccines||[]) → boş harita → "?"');
});

test('_dashVacAlerts: 5+ kayıt → ilk 5 satır + "+N daha" satırı', () => {
  const logs = [];
  for (let i = 0; i < 7; i++) {
    logs.push(log({ id: 'l' + i, animal_id: 'A' + i, vaccine_id: 'v1', next_due_date: '2026-10-' + String(10 + i).padStart(2, '0') }));
  }
  const out = _dashVacAlerts(BUGUN, logs, VAX); // tümü 40-46 gün → else dalı, slice(0,5)
  assert.ok(out.includes('(7)'), 'toplam 7 sayacı başlıkta');
  assert.ok(out.includes('+2 daha'), '7 - 5 = 2 satır gizlenir');
});

// ═══════════════════════════════════════════════════════════════
// _yeniDogumGun (js/ui.js:837) — globalThis._sonDogumMap/_sonTohMap okur
// (globalThis === sandbox olduğundan sandbox üzerinden enjekte edilir)
// ═══════════════════════════════════════════════════════════════
function setMaps(dogumMap, tohMap) {
  sandbox._sonDogumMap = dogumMap;
  sandbox._sonTohMap = tohMap;
}

test('_yeniDogumGun: kısırlar her zaman null (harita dolu olsa bile)', () => {
  setMaps({ K1: daysAgoIso(5) }, {});
  assert.strictEqual(_yeniDogumGun({ id: 'K1', kisir: true }), null);
});

test('_yeniDogumGun: doğum haritasında olmayan hayvan → null', () => {
  setMaps({}, {});
  assert.strictEqual(_yeniDogumGun({ id: 'YOK' }), null);
});

test('_yeniDogumGun: doğumdan SONRA tohumlama varsa → null (>= karşılaştırması)', () => {
  const dogum = daysAgoIso(10), toh = daysAgoIso(5);
  setMaps({ H1: dogum }, { H1: toh });
  assert.strictEqual(_yeniDogumGun({ id: 'H1' }), null, 'sonToh > dogum');
  setMaps({ H1: dogum }, { H1: dogum });
  assert.strictEqual(_yeniDogumGun({ id: 'H1' }), null, 'sonToh == dogum da eşitlikle engellenir');
});

test('_yeniDogumGun: doğumdan önce tohumlama → gün sayısı döner (aynı floor formülü)', () => {
  const dogumIso = daysAgoIso(12), tohIso = daysAgoIso(20);
  setMaps({ H1: dogumIso }, { H1: tohIso });
  const beklenen = Math.floor((Date.now() - new Date(dogumIso).getTime()) / 86400000);
  const sonuc = _yeniDogumGun({ id: 'H1' });
  assert.strictEqual(sonuc, beklenen);
  assert.ok(sonuc >= 11 && sonuc <= 12, 'yaklaşık 12 gün (UTC-yerel kayma toleransı)');
});

test('_yeniDogumGun: MEVCUT DAVRANIŞ — bugünkü doğum null döner (gun>0 koşulu katı; "0 gün" gösterilmez)', () => {
  setMaps({ H0: toLocalIso(new Date()) }, {});
  assert.strictEqual(_yeniDogumGun({ id: 'H0' }), null);
});

test('_yeniDogumGun: haritalar hiç set edilmemişse çökmez → null', () => {
  delete sandbox._sonDogumMap;
  delete sandbox._sonTohMap;
  assert.strictEqual(_yeniDogumGun({ id: 'H1' }), null);
});

// ═══════════════════════════════════════════════════════════════
// _durumClr / _durumTxt (js/ui.js:3102-3103) — saf durum eşlemeleri
// ═══════════════════════════════════════════════════════════════
test('_durumClr: neg→kırmızı, crit→amber, diğer/hepsi→yeşil', () => {
  assert.strictEqual(_durumClr('neg'), 'var(--red)');
  assert.strictEqual(_durumClr('crit'), 'var(--amber)');
  assert.strictEqual(_durumClr('ok'), 'var(--green)');
  assert.strictEqual(_durumClr(''), 'var(--green)');
  assert.strictEqual(_durumClr(undefined), 'var(--green)');
});

test('_durumTxt: neg/crit/diğer etiketleri birebir', () => {
  assert.strictEqual(_durumTxt('neg'), '🆘 Negatif');
  assert.strictEqual(_durumTxt('crit'), '⚠️ Kritik');
  assert.strictEqual(_durumTxt('ok'), '✅ Normal');
  assert.strictEqual(_durumTxt('bilinmeyen'), '✅ Normal');
});

test('_durumClr/_durumTxt: property — bilinen iki durum dışındaki her girdi "normal" dalına düşer', () => {
  fc.assert(fc.property(fc.string({ minLength: 1 }).filter(s => s !== 'neg' && s !== 'crit'), (s) => {
    assert.strictEqual(_durumClr(s), 'var(--green)');
    assert.strictEqual(_durumTxt(s), '✅ Normal');
  }));
});

// ═══════════════════════════════════════════════════════════════
// renderSeansGrupAyrac (js/ui.js:684) — argümanlardan string üreten saf builder
// ═══════════════════════════════════════════════════════════════
test('renderSeansGrupAyrac: minimal girdi — varsayılan "—" etiket + yalnız gün', () => {
  assert.strictEqual(
    renderSeansGrupAyrac({ gunNo: 3 }),
    '<div class="seans-grup-ayrac">🐄 — · Gün 3</div>'
  );
});

test('renderSeansGrupAyrac: tam girdi — gün/toplam, hastalık, seans, tarih segmentleri', () => {
  const out = renderSeansGrupAyrac({
    gunNo: 2, totalGun: 5, disease: 'Mastitis',
    seansDone: 1, seansTotal: 4, date: '2026-08-20', animalLabel: 'TR-123',
  });
  assert.strictEqual(out, '<div class="seans-grup-ayrac">🐄 TR-123 · Gün 2/5 · 🏥 Mastitis · 1/4 seans · 20.08.2026</div>');
});

test('renderSeansGrupAyrac: etiket esc() ile kaçırılır (ham HTML girmez)', () => {
  const out = renderSeansGrupAyrac({ gunNo: 1, animalLabel: '<b>X&Y</b>' });
  assert.ok(out.includes('&lt;b&gt;X&amp;Y&lt;/b&gt;'));
  assert.ok(!out.includes('<b>'));
});

test('renderSeansGrupAyrac: falsy segmentler (hastalık/seans/tarih) hiç render edilmez', () => {
  const out = renderSeansGrupAyrac({ gunNo: 1, animalLabel: 'A1', disease: '', seansTotal: 0, date: '' });
  assert.ok(!out.includes('🏥'));
  assert.ok(!/\d+\/\d+ seans/.test(out), 'seans sayacı segmenti olmamalı');
  assert.ok(!out.includes('20.08'));
  assert.ok(out.includes('Gün 1'));
});

// ═══════════════════════════════════════════════════════════════
// _asiVaccineCoz (js/ui.js) — aşı görevinden aşı çözümleme zinciri
// Gerçek arka plan: Coglavax/Vac-Sules'un stock_item_id'si NULL ve
// add_vaccination'ın ürettiği ASI_RAPEL görevleri stok_id'siz doğar;
// eski kod yalnız stok_id eşleşmesi aradığı için bu görevlere aşı
// uygulanamıyordu ('Aşı bilgisi eksik').
// ═══════════════════════════════════════════════════════════════
const VAX_ORNEK = [
  { id: 'v-sarbon',  name: 'Şarbon Aşısı',  stock_item_id: 'STOK-AŞI-v-sarbon',  dose: 2, unit: 'ml' },
  { id: 'v-cogla',   name: 'Coglavax',      stock_item_id: null,                 dose: 4, unit: 'ml' },
  { id: 'v-sules',   name: 'Vac-Sules Feedlot', stock_item_id: null,             dose: 5, unit: 'ml' },
  { id: 'v-rota',    name: 'Rotavirus Aşısı', stock_item_id: 'STOK-AŞI-v-rota',  dose: 2, unit: 'ml' },
];

test('_asiVaccineCoz: stok_id → vaccines.stock_item_id eşleşmesi (eski davranış korunur)', () => {
  const t = { stok_id: 'STOK-AŞI-v-rota', aciklama: '💉 Rota-Corona Aşısı (1. doz)' };
  assert.equal(_asiVaccineCoz(t, VAX_ORNEK).id, 'v-rota');
});

test('_asiVaccineCoz: stok_id bulunamazsa aciklama ad-öneki fallback (Coglavax rapeli)', () => {
  const t = { stok_id: null, aciklama: 'Coglavax (rapel)' };
  const v = _asiVaccineCoz(t, VAX_ORNEK);
  assert.ok(v, 'Coglavax (rapel) bir aşıya çözümlenmeli');
  assert.equal(v.id, 'v-cogla');
});

test('_asiVaccineCoz: 💉 emoji öneki temizlenir', () => {
  const t = { stok_id: null, aciklama: '💉 Şarbon Aşısı (rapel)' };
  assert.equal(_asiVaccineCoz(t, VAX_ORNEK).id, 'v-sarbon');
});

test('_asiVaccineCoz: en uzun ad öncelik alır', () => {
  const vaxlar = [
    { id: 'kisa',  name: 'Vac-Sules',        stock_item_id: null },
    { id: 'uzun',  name: 'Vac-Sules Feedlot', stock_item_id: null },
  ];
  assert.equal(_asiVaccineCoz({ aciklama: 'Vac-Sules Feedlot (rapel)' }, vaxlar).id, 'uzun');
  assert.equal(_asiVaccineCoz({ aciklama: 'Vac-Sules (rapel)' }, vaxlar).id, 'kisa');
});

test('_asiVaccineCoz: eşleşmeyen açıklama → null (formda seçim listesi açılacak)', () => {
  // Gerçek vaka: kullanıcının manuel oluşturduğu 'rota' görevi
  assert.equal(_asiVaccineCoz({ stok_id: null, aciklama: 'rota' }, VAX_ORNEK), null);
  // Rota-Corona metni Rotavirus Aşısı ile başlamadığından YANLIŞ eşleşmez
  assert.equal(_asiVaccineCoz({ stok_id: null, aciklama: 'Rota-Corona Aşısı (1. doz)' }, VAX_ORNEK), null);
});

test('_asiVaccineCoz: stok_id hiçbir aşıyla eşleşmezse ad-öneki denenir', () => {
  const t = { stok_id: 'STOK-AŞI-SILINMIS', aciklama: 'Coglavax (rapel)' };
  assert.equal(_asiVaccineCoz(t, VAX_ORNEK).id, 'v-cogla');
});

test('_asiVaccineCoz: boş/eksik girişler → null', () => {
  assert.equal(_asiVaccineCoz(null, VAX_ORNEK), null);
  assert.equal(_asiVaccineCoz({ stok_id: null, aciklama: null }, VAX_ORNEK), null);
  assert.equal(_asiVaccineCoz({ stok_id: null, aciklama: '   ' }, VAX_ORNEK), null);
  assert.equal(_asiVaccineCoz({ aciklama: 'Coglavax (rapel)' }, []), null);
  assert.equal(_asiVaccineCoz({ aciklama: 'Coglavax (rapel)' }, undefined), null);
});

// ═══════════════════════════════════════════════════════════════
// ASI_PLANLI tip entegrasyonu (planlı aşı görevi, 2026-09-02)
// Bu iki liste; filtre görünürlüğü ve 'düz PATCH ile kapanamaz'
// korumasının tek savunma hattı — unutulursa rezervasyon atlanır.
// ═══════════════════════════════════════════════════════════════
test('_katTipMap.asi ASI_PLANLI içerir (görev filtresi)', () => {
  assert.ok(exposed._katTipMap.asi.includes('ASI_PLANLI'));
});
test('OZEL_ALT_TIPLER ASI_PLANLI içerir (düz PATCH koruması)', () => {
  assert.ok(exposed.OZEL_ALT_TIPLER.includes('ASI_PLANLI'));
});

// _sessizGrupla (js/ui.js — REV-5 idle/sessiz-ui)
// Sessiz listesinin gruplu bölümlemesi: grup sırası en yüksek sessiz_gun'a
// göre; grup içi sessiz_gun DESC; 'Hiç kayıt yok' (sessiz_gun>=9999) her
// zaman EN ALTta ayrı bölüm (sentinel-son kuralı, bb4ea92). Saf fonksiyon —
// grup adları HAM döner, esc() render'da uygulanır (helpers.js sözleşmesi).
// ═══════════════════════════════════════════════════════════════
const SG = (id, gun, grup) => ({ hayvan_id: id, sessiz_gun: gun, grup, kupe_no: id, son_aktivite: null });

test('_sessizGrupla: boş/null liste → boş dizi', () => {
  assert.deepEqual(_sessizGrupla([]), []);
  assert.deepEqual(_sessizGrupla(null), []);
  assert.deepEqual(_sessizGrupla(undefined), []);
});

test('_sessizGrupla: tek grup, grup içi sessiz_gun DESC', () => {
  const r = _sessizGrupla([SG('a', 60, 'Sağmal'), SG('b', 90, 'Sağmal'), SG('c', 75, 'Sağmal')]);
  assert.equal(r.length, 1);
  assert.equal(r[0].grup, 'Sağmal');
  assert.deepEqual(r[0].items.map(s => s.hayvan_id), ['b', 'c', 'a']);
});

test('_sessizGrupla: en yüksek sessiz_gun\'u içeren grup önce', () => {
  const r = _sessizGrupla([
    SG('a', 58, 'Düve'),     // Düve'un en yükseği 58
    SG('b', 120, 'Sağmal'),  // Sağmal'ın en yükseği 120 → Sağmal önce
    SG('c', 61, 'Düve'),
    SG('d', 70, 'Kuru Dönem'), // Kuru Dönem'in en yükseği 70 → ikinci
  ]);
  assert.deepEqual(r.map(g => g.grup), ['Sağmal', 'Kuru Dönem', 'Düve']);
  assert.deepEqual(r[2].items.map(s => s.hayvan_id), ['c', 'a']); // grup içi DESC
});

test('_sessizGrupla: sessiz_gun>=9999 her zaman EN ALTta ayrı bölüm', () => {
  const r = _sessizGrupla([
    SG('k1', 9999, 'Düve'),
    SG('a', 100, 'Sağmal'),
    SG('k2', 12000, 'Sağmal'),
    SG('b', 65, 'Düve'),
  ]);
  assert.deepEqual(r.map(g => g.grup), ['Sağmal', 'Düve', 'Hiç kayıt yok']);
  // Kayıtsız bölüm grubundan bağımsız toplanır, içinde DESC
  assert.deepEqual(r[2].items.map(s => s.hayvan_id), ['k2', 'k1']);
  // Satırda grubun kendi etiketi görünür kalsın — item HAM grup değerini taşır
  assert.equal(r[2].items[0].grup, 'Sağmal');
  assert.equal(r[2].items[1].grup, 'Düve');
});

test('_sessizGrupla: grupsuz hayvanlar "Grupsuz" bölümünde toplanır', () => {
  const r = _sessizGrupla([
    SG('a', 70, 'Sağmal'),
    SG('x', 80, ''),
    SG('y', 60, null),
  ]);
  // Grupsuz'un en yükseği (80) > Sağmal'ın en yükseği (70) → Grupsuz önce
  assert.deepEqual(r.map(g => g.grup), ['Grupsuz', 'Sağmal']);
  assert.deepEqual(r[0].items.map(s => s.hayvan_id), ['x', 'y']);
});

test('_sessizGrupla: Türkçe grup adları HAM korunur (escape render\'da)', () => {
  const ad = 'İnek<Script> & "Düve"';
  const r = _sessizGrupla([SG('a', 70, ad)]);
  assert.equal(r[0].grup, ad); // saf fonksiyon kaçırmaz — render esc()'ler
});

test('_sessizGrupla: sentinel-son kuralı yalnız kayıtsız varken bölüm ekler', () => {
  const r = _sessizGrupla([SG('a', 70, 'Sağmal'), SG('b', 90, 'Sağmal')]);
  assert.deepEqual(r.map(g => g.grup), ['Sağmal']); // 9999 yoksa kayıtsız bölümü YOK
});

// ── _asiStokKalanlar — aşı→stok entegrasyonu (kalan hesabı) ──
const STOK_ORNEK=[
  { id:'STOK-AŞI-v-cogla', baslangic_miktar:20 },
  { id:'STOK-AŞI-v-rota',  baslangic_miktar:15 },
];
const HAREKET_ORNEK=[
  { stok_id:'STOK-AŞI-v-cogla', miktar:4,  iptal:false },  // uygulama
  { stok_id:'STOK-AŞI-v-cogla', miktar:4,  iptal:true  },  // iade edilen rezervasyon — sayılmaz
  { stok_id:'STOK-AŞI-v-rota',  miktar:2,  iptal:false },
  { stok_id:'STOK-AŞI-v-rota',  miktar:-10, iptal:false },  // stok girişi (negatif)
];
test('_asiStokKalanlar: net kalan = baslangıç − Σ(iptal olmayan)', () => {
  const k=_asiStokKalanlar([{id:'v-cogla',stock_item_id:'STOK-AŞI-v-cogla'}],STOK_ORNEK,HAREKET_ORNEK);
  assert.equal(k['v-cogla'], 16); // 20 − 4 (iptal olan 4 hariç)
});
test('_asiStokKalanlar: negatif hareket (stok girişi) kalanı artırır', () => {
  const k=_asiStokKalanlar([{id:'v-rota',stock_item_id:'STOK-AŞI-v-rota'}],STOK_ORNEK,HAREKET_ORNEK);
  assert.equal(k['v-rota'], 23); // 15 − 2 − (−10)
});
test('_asiStokKalanlar: stok satırı yoksa null (bağlantısız aşı)', () => {
  const k=_asiStokKalanlar([{id:'v-x',stock_item_id:'STOK-AŞI-v-x'},{id:'v-y',stock_item_id:null}],STOK_ORNEK,[]);
  assert.equal(k['v-x'], null);
  assert.equal(k['v-y'], null);
});
