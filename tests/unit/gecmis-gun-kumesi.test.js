// tests/unit/gecmis-gun-kumesi.test.js
// js/gecmis.js — W3 takvim işaretli günler: _gmGunKumesiFromSources (SAF).
//
// Kilitlenen sözleşmeler (zarf L4-W3 md.B; plan raporu §6):
//   1. Gün kümesi _gmGunEntriesFromSources ile AYNI pipeline'dan gelir —
//      olay-günü kuralı + DEDUP + geri_alindi dışlaması birebir ortaktır
//      (takvim işareti ile gün görünümü ASLA ayrışamaz).
//   2. Küme Set<'YYYY-MM-DD'> döner; boş havuz → boş Set (bugün varsayımı YOK).
//   3. scope:{animalId} kart kapsamı: yalnız o hayvanın günleri; stok_hareket
//      hayvansızdır (§E.3) — genel kümede VAR, kapsam kümesinde YOK.
//
// RED-BEFORE: _gmGunKumesiFromSources sandbox'ta yokken tüm testler kırmızıdır.

const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');

const { sandbox } = loadBrowserModule('js/gecmis.js');

const HAVUZ = {
  dogum: [{ id: 'd1', tarih: '2026-09-03', anne_id: 'h-A' }],
  tohumlama: [
    { id: 't1', tarih: '2026-09-05', hayvan_id: 'h-A', sonuc: '' },
    { id: 't2', tarih: '2026-09-06', hayvan_id: 'h-B', durum: 'geri_alindi' }, // geri alınmış → işaret YOK
  ],
  vaccination_log: [{ id: 'v1', vaccination_date: '2026-09-05', animal_id: 'h-A' }],
  islem_log: [
    { id: 'i1', tarih: '2026-09-05', tip: 'ASI_KAYDI', ana_hayvan_id: 'h-A' }, // ayna — vaccination_log baskılar (aynı gün)
    { id: 'i2', tarih: '2026-09-08', tip: 'HAYVAN_EKLENDI', ana_hayvan_id: null }, // baskılanmayan genel islem
  ],
  stok_hareket: [{ id: 's1', tarih: '2026-09-09', stok_id: 'st1', iptal: false }], // hayvansız
};

test('genel küme: havuzdaki olay günleri Set olarak döner, geri_alindi hariç', () => {
  const k = sandbox._gmGunKumesiFromSources(HAVUZ);
  // vm realm Set — instanceof main-realm Set ile prototype atar; yapısal kontrol
  assert.strictEqual(typeof k.has, 'function', 'Set arayüzü (has)');
  assert.strictEqual(typeof k.size, 'number', 'Set arayüzü (size)');
  assert.strictEqual(k.size, 4, '03/05/08/09: geri_alindi (06) hariç 4 benzersiz gün');
  for (const gun of ['2026-09-03', '2026-09-05', '2026-09-08', '2026-09-09']) {
    assert.ok(k.has(gun), gun + ' işaretli');
  }
  assert.ok(!k.has('2026-09-06'), 'geri_alindi tohumlama işaretsiz');
  assert.ok(!k.has('2026-09-30'), 'olmayan gün işaretsiz');
});

test('kapsam kümesi: animalId — yalnız o hayvanın günleri; stok hayvansız çıkar', () => {
  const kA = sandbox._gmGunKumesiFromSources(HAVUZ, { animalId: 'h-A' });
  assert.ok(kA.has('2026-09-03'), 'A doğumu');
  assert.ok(kA.has('2026-09-05'), 'A aşısı');
  assert.ok(!kA.has('2026-09-09'), 'stok hareketi kapsamda değil');
  assert.strictEqual(kA.size, 2);
  const kB = sandbox._gmGunKumesiFromSources(HAVUZ, { animalId: 'h-B' });
  assert.deepStrictEqual([...kB], [], 'B yalnız geri_alindi tohumlaması var → boş');
});

test('boş/eksik havuz → boş Set (varsayılan gün YOK); DEDUP çift gün TEK işaret', () => {
  assert.deepStrictEqual([...sandbox._gmGunKumesiFromSources({})], []);
  assert.deepStrictEqual([...sandbox._gmGunKumesiFromSources(null)], []);
  // aynı gün iki kaynak → kümede tek kalemden fazlası OLMASIN (Set doğası) ve
  // ayna baskısı kümeyi değiştirmez: gün 2026-09-05 hem vaccination hem ayna islem
  const k = sandbox._gmGunKumesiFromSources({ vaccination_log: [{ id: 'v1', vaccination_date: '2026-09-05', animal_id: 'x' }], islem_log: [{ id: 'i1', tarih: '2026-09-05', tip: 'ASI_KAYDI', ana_hayvan_id: 'x' }] });
  assert.deepStrictEqual([...k], ['2026-09-05']);
});
