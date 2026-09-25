// tests/unit/kisir-ovsync-ui.test.js — C1 (cila2): kısır hayvanda Ovsync UI hardblock
// Kapsam: OVSYNC-aile hastalık çözümlemesi + kısır kilidi nedeni (pure, forms.js)
// + PG_HATA_SOZLUGU çevirisi (config × errorHandler sözleşmesi).
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule, loadExtractedFunction } = require('./support/loadModule.js');

const _ovsyncAileHastalikIdleri = loadExtractedFunction('js/forms.js', '_ovsyncAileHastalikIdleri');
const _kisirOvsyncNedeni = loadExtractedFunction('js/forms.js', '_kisirOvsyncNedeni');

// config sözlüğü: const lexical scope — expose kalıbıyla dışarı alınır (K7 deseni)
const cfg = loadBrowserModule('js/config.js', { expose: ['PG_HATA_SOZLUGU'] }).exposed;

const sablonlar = [
  { id: 'S1', protokol_ailesi: 'OVSYNC', ad: 'Ovsynch-56' },
  { id: 'S2', protokol_ailesi: null, ad: 'Metrit şablonu' },
];
const eslem = [
  { sablon_id: 'S1', disease_id: 'DOV' },   // Ovsync Protokol
  { sablon_id: 'S2', disease_id: 'DMET' },  // Metrit
];

test('C1-1: OVSYNC-aile şablonuna eşli hastalık çözülür; ailesiz eşlenmez', () => {
  const ids = _ovsyncAileHastalikIdleri(eslem, sablonlar);
  assert.ok(ids.has('DOV'));
  assert.ok(!ids.has('DMET'));
  // boş/eksik girdi: geçerli boş küme (sessiz hata değil)
  assert.equal(_ovsyncAileHastalikIdleri(null, null).size, 0);
});

test('C1-2: kısır + OVSYNC hastalık → Türkçe sebep; diğer kombinasyonlar null', () => {
  const ids = _ovsyncAileHastalikIdleri(eslem, sablonlar);
  const kisir = { kupe_no: '184', kisir: true };
  const normal = { kupe_no: '110', kisir: false };
  assert.match(_kisirOvsyncNedeni(kisir, 'DOV', ids), /kısır işaretli — Ovsync protokolü açılamaz/);
  assert.equal(_kisirOvsyncNedeni(kisir, 'DMET', ids), null);   // kısır ama OVSYNC değil → serbest
  assert.equal(_kisirOvsyncNedeni(normal, 'DOV', ids), null);   // OVSYNC ama kısır değil → serbest
  assert.equal(_kisirOvsyncNedeni(null, 'DOV', ids), null);
  assert.equal(_kisirOvsyncNedeni(kisir, '', ids), null);
});

test('C1-3: DB RAISE kodu PG_HATA_SOZLUGU\'de Türkçe karşılıklı', () => {
  const sozluk = cfg.PG_HATA_SOZLUGU;
  assert.ok(sozluk, 'PG_HATA_SOZLUGU yüklendi');
  assert.match(sozluk['KISIR_HAYVAN_OVSYNC_YASAK'], /Kısır işaretli hayvana Ovsync protokolü açılamaz/);
});

test('C1-4: getUserMessage KISIR_HAYVAN_OVSYNC_YASAK mesajını çevirir (sözlük üzerinden)', () => {
  const { sandbox } = loadBrowserModule('js/utils/errorHandler.js', {
    extra: { toast: () => {}, g: () => null, PG_HATA_SOZLUGU: cfg.PG_HATA_SOZLUGU },
  });
  const out = sandbox.getUserMessage(
    { message: 'KISIR_HAYVAN_OVSYNC_YASAK: hayvan 00000000-0000 kısır işaretli — Ovsync protokolü açılamaz' });
  assert.equal(out, 'Kısır işaretli hayvana Ovsync protokolü açılamaz.');
});
