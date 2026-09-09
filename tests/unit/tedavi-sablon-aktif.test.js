// tests/unit/tedavi-sablon-aktif.test.js
// Aktif vakaya şablon uygulama — saf çekirdek birim testleri.
// cdSablonListeBul: bcSablonYukleListeRender (forms.js) satır hesabının
// DOM'suz aynası — gun = unique gun_no sayısı, seans = kalem sayısı,
// tohumVar = tohumlama_plani tam mı (gun_ofset + planned_time).
//
// Not: vm sandbox'ta üretilen dizi/obje literalleri başka realm'dendir;
// deepStrictEqual prototipleri === ile karşılaştırıp çapraz-realm yapıda
// patlar (ui-pure.test.js'deki gibi yapısal karşılaştırmalarda
// deepEqual kullanılır).
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');

const { sandbox } = loadBrowserModule('js/ui.js');
const { cdSablonListeBul } = sandbox;

const E = (sablon_id, disease_id) => ({ sablon_id, disease_id });
const S = (id, ad, tohumlama_plani) => ({ id, ad, tohumlama_plani: tohumlama_plani ?? null });
const K = (sablon_id, gun_no) => ({ sablon_id, gun_no });

test('hastaliga bagli sablon: gun=unique gun_no, seans=kalem sayisi, tohum=false', () => {
  const r = cdSablonListeBul(
    [E('s1', 'd1')],
    [S('s1', 'Mantar')],
    [K('s1', 1), K('s1', 1), K('s1', 3)],
    'd1'
  );
  assert.deepEqual(r, [
    { id: 's1', ad: 'Mantar', gun: 2, seans: 3, tohumVar: false },
  ]);
});

test('tohumlama_plani tam ise tohumVar=true; eksik parcali planlarda false', () => {
  const sablonlar = [
    S('s1', 'Tam', { gun_ofset: 2, planned_time: '09:00' }),
    S('s2', 'OfsetYok', { planned_time: '09:00' }),
    S('s3', 'SaatYok', { gun_ofset: 2 }),
    S('s4', 'Null', null),
  ];
  const eslem = [E('s1', 'd1'), E('s2', 'd1'), E('s3', 'd1'), E('s4', 'd1')];
  const r = cdSablonListeBul(eslem, sablonlar, [], 'd1');
  assert.strictEqual(r[0].tohumVar, true);
  assert.strictEqual(r[1].tohumVar, false);
  assert.strictEqual(r[2].tohumVar, false);
  assert.strictEqual(r[3].tohumVar, false);
});

test('baska hastaliga eslenmis sablon ve eslemsiz sablon listelenmez', () => {
  const r = cdSablonListeBul(
    [E('s1', 'd2'), E('yok', 'd1')],
    [S('s1', 'Baska'), S('yoksablon', 'Yetim')],
    [K('s1', 1)],
    'd1'
  );
  assert.deepEqual(r, []); // 'yok' eslemi sablon bulunamadigi icin duser
});

test('coklu sablon eslem sirasi korunur', () => {
  const r = cdSablonListeBul(
    [E('s2', 'd1'), E('s1', 'd1')],
    [S('s1', 'A'), S('s2', 'B')],
    [],
    'd1'
  );
  assert.deepEqual(r.map(x => x.ad), ['B', 'A']);
});

test('bos/eksik girdi → [] (patlama yok)', () => {
  assert.deepEqual(cdSablonListeBul(null, null, null, 'd1'), []);
  assert.deepEqual(cdSablonListeBul([], [], [], 'd1'), []);
});
