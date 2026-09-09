// tests/unit/gorev-sira.test.js
// Görevler sekmesi saat→grup→küpe katmanlamasının saf bileşenleri
// (spec: .claude/plans/2026-09-09-tedavi-doz-gorev-design.md §4.1):
//   - kuceDogalBlok / kuceDogalKarsilastir (küpe doğal sırası)
//   - gorevSaatAnahtari (hedef_saat → TEDAVI_GUN JSON planned_time, saatsiz '')
'use strict';

const test = require('node:test');
const assert = require('node:assert');
const { kuceDogalBlok, kuceDogalKarsilastir, gorevSaatAnahtari } = require('../../js/utils/helpers.js');

const sirali = (dizi) => [...dizi].sort(kuceDogalKarsilastir);

test('küpe doğal sıra: sayısal karşılaştırma 01 < 002 < 19 < 2044 (alfabetik YANLIŞ olurdu)', () => {
  assert.deepEqual(sirali(['2044', '19', '002', '01']), ['01', '002', '19', '2044']);
});

test('küpe doğal sıra: canlı küpe karışımı (5708, 903, 101, 5621…)', () => {
  const sonuc = sirali(['2044', '903', '101', '5708', '5621', '903+', '002', '008']);
  // 903+ sayısal değeri 903 → 5621'den önce gelir
  // 2044 < 5621 < 5708 (sayısal); 903+ sayısal değeri 903 → 5621'den önce
  assert.deepEqual(sonuc, ['002', '008', '101', '903', '903+', '2044', '5621', '5708']);
});

test('küpe doğal sıra: metin blokları (BZ- işaretli buzağı, kirli değerler) sayısal bloklardan SONRA', () => {
  const sonuc = sirali(['xx', 'BZ-1234', 'Test buzağı', '5']);
  assert.deepEqual(sonuc, ['5', 'BZ-1234', 'Test buzağı', 'xx']);
});

test('küpe doğal sıra: devlet küpesi uzun alfanumerik — deterministik, kendisiyle 0', () => {
  assert.equal(kuceDogalKarsilastir('TR093114016', 'TR093114016'), 0);
  const a = sirali(['TR093114016', 'TR093113016']);
  assert.equal(a[0], 'TR093113016');
});

test("küpe doğal sıra: boş/undefined küpe en başa (çağıran '—' fallback'iyle besler)", () => {
  assert.equal(kuceDogalKarsilastir('', '5'), -1);
  assert.equal(kuceDogalKarsilastir(null, '5'), -1);
});

test('küpe blok ayrıştırma: sayısal bloklar {n,s}, metin blokları string', () => {
  assert.deepEqual(kuceDogalBlok('BZ-12'), ['BZ-', { n: 12, s: '12' }]);
  assert.deepEqual(kuceDogalBlok('002'), [{ n: 2, s: '002' }]);
});

test('görev saat anahtarı: hedef_saat öncelikli ve SS:DD kırpılır', () => {
  assert.equal(gorevSaatAnahtari({ hedef_saat: '09:00:00', gorev_tipi: 'MUAYENE' }), '09:00');
  assert.equal(gorevSaatAnahtari({ hedef_saat: '13:45' }), '13:45');
});

test('görev saat anahtarı: TEDAVI_GUN açıklama JSON planned_time fallback', () => {
  const t = { gorev_tipi: 'TEDAVI_GUN', aciklama: '{"day_id":"x","planned_time":"08:30","label":"Gün 2/5"}' };
  assert.equal(gorevSaatAnahtari(t), '08:30');
});

test("görev saat anahtarı: hedef_saat boşken JSON kullanılır; saatsiz boş string döner", () => {
  assert.equal(gorevSaatAnahtari({ gorev_tipi: 'TEDAVI_GUN', hedef_saat: null, aciklama: '{"planned_time":"20:00"}' }), '20:00');
  assert.equal(gorevSaatAnahtari({ gorev_tipi: 'ASI_PLANLI', aciklama: null }), '');
  assert.equal(gorevSaatAnahtari(null), '');
});

test("görev saat anahtarı: bozuk JSON patlamaz — boş string döner", () => {
  assert.equal(gorevSaatAnahtari({ gorev_tipi: 'TEDAVI_GUN', aciklama: '{bozuk' }), '');
});

test('saat → grup → küpe birleşik karşılaştırma örneği (kullanıcı senaryosu)', () => {
  // 9.00 bloğu sağmal inekler küpe sırasıyla; 13.00 bloğu sonra; saatsiz en sonda
  const b = (saat, grup, kupe) => ({ saat, grup, kupe });
  const bloklar = [
    b('13:00', 'Sağmal (Laktasyonda)', '2044'),
    b('', 'Sağmal (Kuru)', '163'),
    b('09:00', 'Süt İçen Buzağı', '70'),
    b('09:00', 'Sağmal (Laktasyonda)', '115'),
    b('09:00', 'Süt İçen Buzağı', '66'),
  ];
  const GRUP = ['Süt İçen Buzağı', 'Sütten Kesilmiş Buzağı', 'Düve (Küçük)', 'Düve (Büyük)', 'Besi', 'Sağmal (Laktasyonda)', 'Sağmal (Kuru)'];
  const sira = x => { const i = GRUP.indexOf(x.grup); return i >= 0 ? i : 90; };
  const sonuc = [...bloklar].sort((x, y) =>
    (x.saat || '\uffff').localeCompare(y.saat || '\uffff') ||
    sira(x) - sira(y) ||
    kuceDogalKarsilastir(x.kupe, y.kupe));
  assert.deepEqual(sonuc.map(x => x.kupe), ['66', '70', '115', '2044', '163']);
});
