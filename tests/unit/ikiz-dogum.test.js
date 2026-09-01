// tests/unit/ikiz-dogum.test.js
// İkiz/çoklu doğum saf yardımcıları — js/ui.js içindeki _kardeslerBul,
// _ikinciYavruDogumu, _dogumAnneBazliTekillestir.
// DOM-ağır kısımlar E2E kapsamında; burada yalnız saf fonksiyonlar.
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');

const { sandbox } = loadBrowserModule('js/ui.js', {});
const { _kardeslerBul, _ikinciYavruDogumu, _dogumAnneBazliTekillestir } = sandbox;

test('_kardeslerBul: aynı anne + aynı dogum_tarihi → kardeş; diğerleri değil', () => {
  const A = [
    { id: 'H1', anne_id: 'A1', dogum_tarihi: '2026-04-08' },
    { id: 'H2', anne_id: 'A1', dogum_tarihi: '2026-04-08' },   // H1'in ikizi
    { id: 'H3', anne_id: 'A1', dogum_tarihi: '2025-01-01' },   // aynı anne, farklı doğum
    { id: 'H4', anne_id: 'A2', dogum_tarihi: '2026-04-08' },   // farklı anne
    { id: 'H5', anne_id: null,  dogum_tarihi: '2026-04-08' },  // anne bilinmiyor
  ];
  const k = _kardeslerBul(A, A[0]);
  assert.equal(k.length, 1);
  assert.equal(k[0].id, 'H2');
  assert.deepEqual(_kardeslerBul(A, A[2]), []);
  assert.deepEqual(_kardeslerBul(A, A[4]), []);
  assert.deepEqual(_kardeslerBul(A, null), []);
  assert.deepEqual(_kardeslerBul(null, A[0]), []);
});

test('_ikinciYavruDogumu: pencere içindeki en son doğum → satır; pencere dışı/boş → null', () => {
  const bugun = '2026-05-01';
  const yakin = [{ anne_id: 'A1', tarih: '2026-04-28' }];
  const eski  = [{ anne_id: 'A1', tarih: '2026-04-15' }];  // 16 gün önce
  const coklu = [{ anne_id: 'A1', tarih: '2026-04-25' }, { anne_id: 'A1', tarih: '2026-04-27' }];
  assert.equal(_ikinciYavruDogumu(yakin, bugun, 10)?.tarih, '2026-04-28');
  assert.equal(_ikinciYavruDogumu(coklu, bugun, 10)?.tarih, '2026-04-27');
  assert.equal(_ikinciYavruDogumu(eski, bugun, 10), null);
  assert.equal(_ikinciYavruDogumu([], bugun, 10), null);
  assert.equal(_ikinciYavruDogumu([{ anne_id: 'A1' }], bugun, 10), null); // tarihsiz
});

test('_dogumAnneBazliTekillestir: anne başına ilk satır kalır', () => {
  const b = [
    { anne_id: 'A1', id: 'd1' }, { anne_id: 'A1', id: 'd2' },
    { anne_id: 'A2', id: 'd3' }, { anne_id: null, id: 'd4' },
  ];
  const r = _dogumAnneBazliTekillestir(b);
  assert.equal(r.length, 2);
  assert.equal(r[0].id, 'd1');
  assert.ok(r.some(x => x.id === 'd3'));
  assert.deepEqual(_dogumAnneBazliTekillestir(null), []);
});
