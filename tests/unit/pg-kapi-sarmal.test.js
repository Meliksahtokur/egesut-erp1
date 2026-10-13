'use strict';
const test = require('node:test'); const assert = require('node:assert');
const { extractFunctionSource } = require('./support/loadModule.js');
test('pg-kapi-sarmal-kilidi', () => {
  for (const [dosya, fn] of [['js/ui.js', '_tedaviGunExecute'], ['js/ui.js', 'caseDayTamamla'],
      ['js/ui.js', 'caseDrugKaydet'], ['js/ui.js', 'caseSablonUygula'], ['js/forms.js', 'submitCase']]) {
    assert.ok(extractFunctionSource(dosya, fn).includes('_pgKapiHata('), fn + ': PG kapı sarmalı (§18.8)');
  }
});
// Madde 2 (IMPL-A-F1): submitCase — PG reddinde return YOK, akış kapanışa düşer.
// KAPI madde 2: create_case commit olmuşken closeM/_seciliSablonId/pullTables/openCaseDet atlanmamalı.
test('pg-return-kapanis-kilidi', () => {
  const govde = extractFunctionSource('js/forms.js', 'submitCase');
  const satirlar = govde.split('\n');
  const kapiSatirlari = satirlar.filter(s => s.includes('_pgKapiHata('));
  assert.ok(kapiSatirlari.length >= 2,
    'submitCase: iki PG kapısı sarmalı beklenir (:831 ve :887), bulunan: ' + kapiSatirlari.length);
  for (const s of kapiSatirlari)
    assert.ok(!s.includes('return'), 'PG kapısı satırında return YOK: ' + s.trim());
  for (const parca of ["closeM(", '_seciliSablonId', 'pullTables(', 'openCaseDet('])
    assert.ok(govde.includes(parca), 'kapanış erişilebilir: ' + parca);
  // Yapısal: ilk PG kapısı ile ardından gelen ilk kapanış arasında erken çıkış yok.
  const ilkKapi = satirlar.findIndex(s => s.includes('_pgKapiHata('));
  const sonrakiKapanis = satirlar.findIndex((s, i) => i > ilkKapi && s.includes('closeM('));
  assert.ok(sonrakiKapanis > ilkKapi, 'kapıdan sonra kapanış çağrısı gelir');
  const ara = satirlar.slice(ilkKapi, sonrakiKapanis + 1).join('\n');
  assert.ok(!/\breturn\b/.test(ara), 'kapı ile kapanış arasında return YOK (akış kapanışa düşer)');
});
// Madde 3 (IMPL-A-F1): caseDrugKaydet — PG reddinde döngüden break, tazeleme yine koşar.
// KAPI madde 3: tazeleme (:13500-13509) atlanırsa tekrar Kaydet mükerrer ilaç yazar.
test('drug-return-kilidi', () => {
  const govde = extractFunctionSource('js/ui.js', 'caseDrugKaydet');
  const satirlar = govde.split('\n');
  const kapiIdx = satirlar.findIndex(s => s.includes('_pgKapiHata('));
  assert.ok(kapiIdx !== -1, 'caseDrugKaydet: PG kapısı sarmalı (§18.8)');
  // PG kapısı dalında return yok (dal = kapı satırı ±2 satır).
  const dal = satirlar.slice(Math.max(0, kapiIdx - 2), kapiIdx + 3).join('\n');
  assert.ok(!/\breturn\b/.test(dal), 'PG kapısı dalında return YOK: ' + dal);
  assert.ok(govde.includes('break'), 'PG reddinde döngüden break ile çıkılır');
  // Tazeleme bloğu döngü sonrasında koşar.
  const forIdx = satirlar.findIndex(s => s.includes('for (const item of secililar)'));
  const tazeleIdx = satirlar.findIndex(s => s.includes('pullTables('));
  assert.ok(forIdx !== -1 && tazeleIdx !== -1 && tazeleIdx > forIdx,
    'tazeleme (pullTables) döngü sonrasında');
  assert.ok(/kapıda durdu/.test(govde), 'toast k/n sayısıyla kapıda durduğunu bildirir');
});
