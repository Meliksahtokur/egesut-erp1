// tests/unit/cikis-filtre.test.js
// T3: sürüden çıkan hayvan (durum≠'Aktif' + cop_kutusu) hiçbir dashboard bandında,
// görev listesinde görünmemeli. Kapsam:
//   - aktifHayvanSatirlari (js/utils/helpers.js) — saf filtre sözleşmesi
//   - _dashVacAlerts 4. param (aktif küme) — çıkmış hayvanın aşı hatırlatması düşer
//   - _dashBands kızgınlık bandı — annesi aktifse kupe gösterir (ham UUID değil)
const test = require('node:test');
const assert = require('node:assert');
const { aktifHayvanSatirlari } = require('../../js/utils/helpers.js');
const { loadBrowserModule } = require('./support/loadModule.js');

// helpers.js esc()'inin saf aynası (ui-pure.test.js ile aynı desen)
const escMirror = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const escAttrMirror = (s) => String(s ?? '')
  .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
  .replace(/</g, '&lt;').replace(/>/g, '&gt;');
const { fmtTarih } = require('../../js/utils/helpers.js');

const { sandbox } = loadBrowserModule('js/ui.js', {
  extra: { esc: escMirror, escAttr: escAttrMirror, fmtTarih },
});
const { _dashVacAlerts, _dashBands } = sandbox;

// ── aktifHayvanSatirlari — sözleşme ──
test('aktifHayvanSatirlari: kümede olmayan hayvan satırını düşürür', () => {
  const rows = [
    { anne_id: 'A1', tarih: '2026-07-04' },
    { anne_id: 'A2', tarih: '2026-07-01' }, // Kesildi — kümede yok
  ];
  const out = aktifHayvanSatirlari(rows, 'anne_id', new Set(['A1']));
  assert.deepEqual(out, [{ anne_id: 'A1', tarih: '2026-07-04' }]);
});

test('aktifHayvanSatirlari: idKey olmayan satır (genel görev) kalır', () => {
  const rows = [
    { id: 'g1', aciklama: 'Genel görev' },
    { id: 'g2', hayvan_id: 'A1' },
    { id: 'g3', hayvan_id: 'A2' },
  ];
  const out = aktifHayvanSatirlari(rows, 'hayvan_id', new Set(['A1']));
  assert.deepEqual(out, [rows[0], rows[1]]);
});

test('aktifHayvanSatirlari: Set ve dizi kabul eder', () => {
  const rows = [{ hayvan_id: 'A1' }, { hayvan_id: 'A2' }];
  assert.equal(aktifHayvanSatirlari(rows, 'hayvan_id', new Set(['A1'])).length, 1);
  assert.equal(aktifHayvanSatirlari(rows, 'hayvan_id', ['A1']).length, 1);
});

test('aktifHayvanSatirlari: aktifIdler null/undefined ise hiçbir satır düşmez', () => {
  const rows = [{ hayvan_id: 'A1' }, { hayvan_id: 'A2' }];
  assert.equal(aktifHayvanSatirlari(rows, 'hayvan_id', null).length, 2);
  assert.equal(aktifHayvanSatirlari(rows, 'hayvan_id', undefined).length, 2);
});

test('aktifHayvanSatirlari: boş Set = tüm hayvan-bağlı satırlar düşer (çağıran boş liste yerine null geçmeli)', () => {
  // Review bulgusu 1: hayvan pull'u başarısızsa çağıran boş küme ÜRETMEMELİ,
  // null geçmeli (fail-safe). Bu test keskin ayrımı sabitler.
  const rows = [{ hayvan_id: 'A1' }, { hayvan_id: 'A2' }, { id: 'genel' }];
  assert.deepEqual(aktifHayvanSatirlari(rows, 'hayvan_id', new Set()), [{ id: 'genel' }]);
});

test('aktifHayvanSatirlari: dizi olmayan girişte boş dizi', () => {
  assert.deepEqual(aktifHayvanSatirlari(null, 'hayvan_id', new Set()), []);
  assert.deepEqual(aktifHayvanSatirlari(undefined, 'hayvan_id', new Set()), []);
});

test('aktifHayvanSatirlari: saf — girdi dizisini değiştirmez, yeni dizi döner', () => {
  const rows = [{ hayvan_id: 'A1' }, { hayvan_id: 'A2' }];
  const kopya = JSON.parse(JSON.stringify(rows));
  const out = aktifHayvanSatirlari(rows, 'hayvan_id', new Set(['A1']));
  assert.deepEqual(rows, kopya);
  assert.notEqual(out, rows);
});

test('aktifHayvanSatirlari: cop_kutusu hayvanı (sette hiç yok) düşer', () => {
  // cop_kutusu'na taşınan hayvan hayvanlar tablosundan silinir → aktif kümede yok
  const tasks = [
    { id: 't1', hayvan_id: 'AKTIF-1' },
    { id: 't2', hayvan_id: 'COPTE-9' },
    { id: 't3' }, // genel görev
  ];
  const out = aktifHayvanSatirlari(tasks, 'hayvan_id', new Set(['AKTIF-1']));
  assert.deepEqual(out, [tasks[0], tasks[2]]);
});

// ── _dashVacAlerts — 4. param (aktif küme) ──
function _vaxRow(animalId, vaccineId, nextDue) {
  return { id: 'vl-' + animalId + '-' + vaccineId, animal_id: animalId, vaccine_id: vaccineId,
    vaccination_date: '2026-08-01', next_due_date: nextDue, ertelendi: false };
}
const VAX = [{ id: 'v1', name: 'Coglavax' }];

test('_dashVacAlerts: hayvanı çıkmış aşı hatırlatması küme verilince düşer', () => {
  const logs = [_vaxRow('A1', 'v1', '2026-09-10'), _vaxRow('A2', 'v1', '2026-09-11')];
  const out = _dashVacAlerts('2026-09-02', logs, VAX, new Set(['A1']));
  assert.match(out, /A1/);
  assert.doesNotMatch(out, /A2/);
});

test('_dashVacAlerts: param verilmezse eski davranış (filtre yok) — geriye uyumlu', () => {
  const logs = [_vaxRow('A1', 'v1', '2026-09-10'), _vaxRow('A2', 'v1', '2026-09-11')];
  const out = _dashVacAlerts('2026-09-02', logs, VAX);
  assert.match(out, /A1/);
  assert.match(out, /A2/);
});

// ── _dashBands — kızgınlık bandı kupe gösterimi ──
test('_dashBands: kızgınlık bandı annenin küpe nosunu basar, ham UUID değil', () => {
  const UUID = '120ff1e6-74ee-4da4-8c67-3f3597d2bdb7';
  const births60 = [{ id: 'd1', anne_id: UUID, tarih: '2026-07-04' }];
  const aMap = { [UUID]: { id: UUID, kupe_no: '157' } };
  const h = _dashBands(0, [], [], births60, [], 0, [], [], aMap, [], [], {}, []);
  assert.match(h, /Kızgınlık Beklenenler/);
  assert.match(h, /class="arow-id">157<\/div>/);
  // UUID yalnız işlevsel yerlerde kalır (onclick), görüntü yuvasında değil
  assert.doesNotMatch(h, /arow-id">120ff1e6/);
});

test('_dashBands: aMapte olmayan anneye geriye uyumlu UUID fallback', () => {
  const UUID = '0f449945-3bf4-4f5e-825d-2fe7e603ad1e';
  const births60 = [{ id: 'd2', anne_id: UUID, tarih: '2026-07-01' }];
  const h = _dashBands(0, [], [], births60, [], 0, [], [], {}, [], [], {}, []);
  assert.match(h, new RegExp(UUID.slice(0, 8)));
});

test('_dashBands: kupe_no yoksa devlet_kupe fallback', () => {
  const UUID = 'aaaaaaaa-74ee-4da4-8c67-3f3597d2bdb7';
  const births60 = [{ id: 'd3', anne_id: UUID, tarih: '2026-07-02' }];
  const aMap = { [UUID]: { id: UUID, kupe_no: null, devlet_kupe: 'TR-9876' } };
  const h = _dashBands(0, [], [], births60, [], 0, [], [], aMap, [], [], {}, []);
  assert.match(h, /TR-9876/);
});
