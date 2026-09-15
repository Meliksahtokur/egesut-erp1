// tests/unit/gecmis-geri-alindi.test.js
// L4-W5 onarım turu L4-06 — GERI_ALINDI telafi kaydının Geçmiş akışına girişi.
//
// Sözleşme (onarım turu sözleşmesi md.6):
//   1. degisim_geri_al'ın yazdığı islem_log telafi kaydı (tip='GERI_ALINDI')
//      ana Geçmiş allow-list'ine girer — kart düşmez ("GERI_ALINDI_entries=0"
//      luna bulgusu kapanır).
//   2. Kart "X geri alındı" ile anlatılır; payload.orijinal_tip GERÇEK işlem
//      tipidir (W4) — harf-kümesi (I,U,D) nötr 'Kayıt' etiketine düşer.
//   3. Kartın geri-al hedefi geri alma tx'idir ({txid} — akış f; çözücü testi
//      geri-al-hedef.test.js'te).
//
// RED-BEFORE: allow-list GERI_ALINDI'yı içermiyorken pipeline testi kırmızıdır.

const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');
const { sandbox, exposed } = loadBrowserModule('js/gecmis.js', {
  expose: ['_gmGeriAlindiEtiketi', '_gmGeriAlBaglam', '_GM_ISLEM_TIPLERI'],
});
const { _gmPolicyRow, _gmPolicyRowKlasik, _gmEntriesFromSources } = sandbox;
const { _gmGeriAlindiEtiketi, _gmGeriAlBaglam, _GM_ISLEM_TIPLERI } = exposed;

// Demo telafi kaydı — degisim_geri_al INSERT biçimi (migration 20260914000002):
// INSERT INTO islem_log (tip, ref_id, ref_tablo, ana_hayvan_id, payload, snapshot)
// VALUES ('GERI_ALINDI', hedef_pk, hedef_tablo, hayvan, {orijinal_tip, seviye, adim}, {});
// tarih kolonu default now() (faz1_core) — köprü trigger'ı degisim_txid yazar.
const TELAFI = {
  id: 'tl-1',
  tip: 'GERI_ALINDI',
  ref_id: 'toh-9',
  ref_tablo: 'tohumlama',
  ana_hayvan_id: 'hv-1',
  payload: { orijinal_tip: 'TOHUMLAMA', seviye: 'satir', adim: 1 },
  snapshot: {},
  tarih: '2026-09-14T17:25:00+03:00',
  degisim_txid: '777666555',
  durum: null,
};

test('L4-06 — GERI_ALINDI allow-listte (defter politikası)', () => {
  assert.strictEqual(_gmPolicyRow('islem_log', { tip: 'GERI_ALINDI' }), true);
});

test('L4-06 — GERI_ALINDI allow-listte (klasik görünüm politikası)', () => {
  assert.strictEqual(_gmPolicyRowKlasik('islem_log', { tip: 'GERI_ALINDI' }), true);
});

test('L4-06 — GERI_ALINDI girişi ana Geçmiş listesinde ENTRY ÜRETİR (pipeline; luna: entries=0)', () => {
  const out = _gmEntriesFromSources({ islem_log: [TELAFI] });
  assert.strictEqual(out.length, 1, 'telafi kaydı listeden DÜŞMEMELİ');
  const e = out[0];
  assert.strictEqual(e.type, 'islem');
  assert.strictEqual(e.data.tip, 'GERI_ALINDI');
  assert.strictEqual(e.eventAt, '2026-09-14T17:25:00+03:00');
});

test('L4-06 — harita sabiti GERI_ALINDI\'yı içerir (tek kaynak)', () => {
  assert.ok(Array.isArray(_GM_ISLEM_TIPLERI) && _GM_ISLEM_TIPLERI.includes('GERI_ALINDI'));
});

test('L4-06 — telafi kartı etiketi gerçek tipi söyler + bağlam işlem dilli', () => {
  assert.strictEqual(_gmGeriAlindiEtiketi(TELAFI), 'Tohumlama geri alındı');
  const baglam = _gmGeriAlBaglam(TELAFI);
  assert.strictEqual(baglam.olayEtiketi, 'Tohumlama geri alındı');
  assert.ok(!/toh-9/.test(baglam.kim), 'ref_id etikete ham pk olarak sızmaz');
});
