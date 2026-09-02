// tests/unit/srch-siralama.test.js
// js/utils/helpers.js → srchAdaySirala + vurguHtml birim testleri.
// Sözleşme: helpers.js "KÜPE ARAMA" bölümündeki yorum bloğu.
//
// Senaryo (2026-09-02 kullanıcı ekran görüntüsü): "01" aramasında birebir
// eşleşme ("01") dizinin ortasındaki "01" içerikleriyle (TR093114016) karışıyor,
// sıralama dizi sırasına bağlı kalıyordu. Katman sıralaması bunu kilitler.
'use strict';

const test = require('node:test');
const assert = require('node:assert');
const { srchAdaySirala, vurguHtml } = require('../../js/utils/helpers.js');

// Ekran görüntüsündeki sürüye birebir karşılık gelen fikstür
const SURU = [
  { id: 'h14',  kupe_no: '14',  devlet_kupe: 'TR093114016', irk: 'Siyah Alaca', padok: 'Düve Padok (Büyük)' },
  { id: 'h01',  kupe_no: '01',  devlet_kupe: 'TR093069793', irk: 'Siyah Alaca', padok: 'Düve Padok (Büyük)' },
  { id: 'h11',  kupe_no: '11',  devlet_kupe: 'TR093114014', irk: 'Holstein',    padok: 'Düve Padok (Büyük)' },
  { id: 'h201', kupe_no: '201', devlet_kupe: '',            irk: 'Holstein',    padok: 'Düve Padok (Büyük)' },
  { id: 'h119', kupe_no: '119', devlet_kupe: '0148',        irk: 'Montbeliarde',padok: 'Sağıl Padok' },
];

test('srchAdaySirala: "01" → birebir eşleşme ilk, devlet öneki ikinci, içerikler son', () => {
  const r = srchAdaySirala(SURU, '01');
  assert.deepStrictEqual(r.map(x => x.h.id), ['h01', 'h119', 'h201', 'h11', 'h14']);
  assert.strictEqual(r[0].tier, 0);   // kupe_no "01" birebir
  assert.strictEqual(r[1].tier, 3);   // devlet_kupe "0148" önek
  assert.strictEqual(r[2].tier, 4);   // kupe_no "201" içerir
  assert.ok(r[3].tier === 5 && r[4].tier === 5); // TR… içinde "01"
});

test('srchAdaySirala: aynı katmanda kısa gösterim önce, sonra tr localeCompare (determinizm)', () => {
  const suru = [
    { id: 'a', kupe_no: '011', devlet_kupe: '', irk: '' },
    { id: 'b', kupe_no: '0123', devlet_kupe: '', irk: '' },
    { id: 'c', kupe_no: '0110', devlet_kupe: '', irk: '' },
  ];
  const r = srchAdaySirala(suru, '01');
  assert.deepStrictEqual(r.map(x => x.h.id), ['a', 'c', 'b']); // 3 → 4 → 4 karakter; eşit uzunlukta tr sözlük
  // Dizi sırasını karıştır → sonuç değişmez
  const r2 = srchAdaySirala([...suru].reverse(), '01');
  assert.deepStrictEqual(r2.map(x => x.h.id), ['a', 'c', 'b']);
});

test('srchAdaySirala: devlet_kupe birebir eşleşme tier 1; kupe_no birebir (0) onu geçer', () => {
  const r = srchAdaySirala(SURU, 'tr093069793');
  assert.deepStrictEqual(r.map(x => x.h.id), ['h01']);
  assert.strictEqual(r[0].tier, 1);
  const ikiz = [
    { id: 'k', kupe_no: 'TR9', devlet_kupe: '', irk: '' },
    { id: 'd', kupe_no: '', devlet_kupe: 'TR9', irk: '' },
  ];
  assert.deepStrictEqual(srchAdaySirala(ikiz, 'tr9').map(x => x.h.id), ['k', 'd']); // tier 0 < tier 1
});

test('srchAdaySirala: büyük küçük harf + Türkçe İ/ı duyarsız', () => {
  const suru = [
    { id: 't1', kupe_no: '', devlet_kupe: 'TR093069793', irk: '' },
    { id: 'i1', kupe_no: 'Irk12', devlet_kupe: '', irk: '' },
  ];
  assert.deepStrictEqual(srchAdaySirala(suru, 'tr09').map(x => x.h.id), ['t1']);
  assert.deepStrictEqual(srchAdaySirala(suru, 'ırk1').map(x => x.h.id), ['i1']); // ı ↔ I
});

test('srchAdaySirala: ırktan eşleşme en son katman (6)', () => {
  const r = srchAdaySirala(SURU, 'holst');
  assert.deepStrictEqual(r.map(x => x.h.id), ['h11', 'h201']);
  assert.ok(r.every(x => x.tier === 6));
});

test('srchAdaySirala: boş/boşluk sorgu → boş liste; limit varsayılan 8', () => {
  assert.deepStrictEqual(srchAdaySirala(SURU, ''), []);
  assert.deepStrictEqual(srchAdaySirala(SURU, '   '), []);
  assert.deepStrictEqual(srchAdaySirala(SURU, null), []);
  const coklu = Array.from({ length: 12 }, (_, i) => ({ id: 'x' + i, kupe_no: '02' + i, devlet_kupe: '', irk: '' }));
  assert.strictEqual(srchAdaySirala(coklu, '02').length, 8);
  assert.strictEqual(srchAdaySirala(coklu, '02', 12).length, 12);
});

test('srchAdaySirala: eksik alanlı kayıtlar patlamaz', () => {
  const r = srchAdaySirala([{ id: 'ciplak' }, { id: 'k1', kupe_no: null, devlet_kupe: null, irk: null }], '01');
  assert.deepStrictEqual(r, []);
});

const VURGU = '<span class="ac-vurgu">';

test('vurguHtml: ilk eşleşmeyi ac-vurgu ile sarar, büyüklük duyarsız', () => {
  assert.strictEqual(vurguHtml('TR093069793', '0697'), 'TR093' + VURGU + '0697</span>93');
  assert.strictEqual(vurguHtml('TR093069793', 'tr09'), VURGU + 'TR09</span>3069793');
  assert.strictEqual(vurguHtml('Siyah Alaca', 'siyah'), VURGU + 'Siyah</span> Alaca');
});

test('vurguHtml: eşleşme yoksa ya da girdi boşsa düz metin', () => {
  assert.strictEqual(vurguHtml('TR093069793', 'xyz'), 'TR093069793');
  assert.strictEqual(vurguHtml('201', ''), '201');
  assert.strictEqual(vurguHtml('201', null), '201');
  assert.strictEqual(vurguHtml('', '01'), '');
});

test('vurguHtml: HTML karakterleri esc semantiğiyle kaçırılır (vurgu içinde ve dışında)', () => {
  assert.strictEqual(
    vurguHtml('<b>01</b>', '01'),
    '&lt;b&gt;' + VURGU + '01</span>&lt;/b&gt;'
  );
  assert.strictEqual(vurguHtml('a&b01c', '01'), 'a&amp;b' + VURGU + '01</span>c');
});
