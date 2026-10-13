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
// F2 (KAPI-2 işaretli 1): dilim taraması — HER kapıdan sonraki ilk tazeleme satırına
// kadar return YOK; kapı→kapanış (closeM) taraması İKİ kapıda da (:831 ve :887).
test('pg-return-kapanis-kilidi', () => {
  const govde = extractFunctionSource('js/forms.js', 'submitCase');
  const satirlar = govde.split('\n');
  const kapiIdxler = satirlar
    .map((s, i) => (s.includes('_pgKapiHata(') ? i : -1))
    .filter(i => i !== -1);
  assert.ok(kapiIdxler.length >= 2,
    'submitCase: iki PG kapısı sarmalı beklenir (:831 ve :887), bulunan: ' + kapiIdxler.length);
  for (const i of kapiIdxler)
    assert.ok(!satirlar[i].includes('return'), 'PG kapısı satırında return YOK: ' + satirlar[i].trim());
  for (const parca of ["closeM(", '_seciliSablonId', 'pullTables(', 'openCaseDet('])
    assert.ok(govde.includes(parca), 'kapanış erişilebilir: ' + parca);
  // F2: HER kapı için kapı satırından sonraki ilk tazeleme (pullTables) satırına
  // kadarki DİLİMDE return YOK (kapı satırı ±2 dilimi YASAK — mB çok satırlı return'ü kaçırıyordu).
  for (const kapi of kapiIdxler) {
    const tazele = satirlar.findIndex((s, i) => i > kapi && s.includes('pullTables('));
    assert.ok(tazele > kapi, 'kapı satırı ' + (kapi + 1) + ': ardından tazeleme (pullTables) gelir');
    const dilim = satirlar.slice(kapi, tazele + 1).join('\n');
    assert.ok(!/\breturn\b/.test(dilim),
      'kapı→tazeleme diliminde return YOK (satır ' + (kapi + 1) + '→' + (tazele + 1) + ')');
    // F2: kapı→kapanış (closeM) taraması yalnız ilk kapıda değil, İKİ kapıda da.
    const kapanis = satirlar.findIndex((s, i) => i > kapi && s.includes('closeM('));
    assert.ok(kapanis > kapi, 'kapı satırı ' + (kapi + 1) + ': ardından kapanış (closeM) gelir');
    assert.ok(kapanis < tazele, 'kapı satırı ' + (kapi + 1) + ': kapanış tazeleme öncesinde');
    const kapiKapanis = satirlar.slice(kapi, kapanis + 1).join('\n');
    assert.ok(!/\breturn\b/.test(kapiKapanis),
      'kapı→kapanış diliminde return YOK (satır ' + (kapi + 1) + '→' + (kapanis + 1) + ')');
  }
});
// Madde 3 (IMPL-A-F1): caseDrugKaydet — PG reddinde döngüden break, tazeleme yine koşar.
// KAPI madde 3: tazeleme (:13500-13509) atlanırsa tekrar Kaydet mükerrer ilaç yazar.
// F2 (KAPI-2 işaretli 1): kapı satırı ±2 dilimi YASAK — kapı satırından tazeleme
// satırına kadarki DİLİMDE return tara (mA tazeleme-öncesi return'ü kaçırıyordu).
test('drug-return-kilidi', () => {
  const govde = extractFunctionSource('js/ui.js', 'caseDrugKaydet');
  const satirlar = govde.split('\n');
  const kapiIdx = satirlar.findIndex(s => s.includes('_pgKapiHata('));
  assert.ok(kapiIdx !== -1, 'caseDrugKaydet: PG kapısı sarmalı (§18.8)');
  const tazeleIdx = satirlar.findIndex((s, i) => i > kapiIdx && s.includes('pullTables('));
  assert.ok(tazeleIdx > kapiIdx, 'kapıdan sonra tazeleme (pullTables) gelir');
  const dilim = satirlar.slice(kapiIdx, tazeleIdx + 1).join('\n');
  assert.ok(!/\breturn\b/.test(dilim),
    'kapı→tazeleme diliminde return YOK (tazeleme atlanırsa mükerrer ilaç)');
  assert.ok(govde.includes('break'), 'PG reddinde döngüden break ile çıkılır');
  // Tazeleme bloğu döngü sonrasında koşar.
  const forIdx = satirlar.findIndex(s => s.includes('for (const item of secililar)'));
  assert.ok(forIdx !== -1 && tazeleIdx !== -1 && tazeleIdx > forIdx,
    'tazeleme (pullTables) döngü sonrasında');
  assert.ok(/kapıda durdu/.test(govde), 'toast k/n sayısıyla kapıda durduğunu bildirir');
});
// Madde 6 (KAPI-2 işaretli 6): ilk kalem PG'de durursa (eklenen=0) toast nötr — ✅ YOK.
test('drug-pg-toast-notr-kilidi', () => {
  const govde = extractFunctionSource('js/ui.js', 'caseDrugKaydet');
  const satirlar = govde.split('\n');
  const toastIdx = satirlar.findIndex(s => s.includes('pgDurdu') && s.includes('toast('));
  assert.ok(toastIdx !== -1, 'PG-durma (pgDurdu) toast satırı bulunur');
  const satir = satirlar[toastIdx];
  // Koşulsuz '✅ ' öneki YASAK: toast satırı eklenen sayısına koşullu olmalı.
  assert.ok(/eklenen/.test(satir), 'pgDurdu toast eklenen sayısına koşullu olmalı: ' + satir.trim());
  // eklenen=0 kolundaki literal ✅ taşımamalı (üç yaygın koşul yazımı kapsanır).
  const l = "('[^']*'|\"[^\"]*\")";
  let sifirKol = null;
  let m = satir.match(new RegExp('eklenen\\s*===\\s*0\\s*\\?\\s*' + l + '\\s*:\\s*' + l));
  if (m) sifirKol = m[1];
  else if ((m = satir.match(new RegExp('eklenen\\s*>\\s*0\\s*\\?\\s*' + l + '\\s*:\\s*' + l)))) sifirKol = m[2];
  else if ((m = satir.match(new RegExp('eklenen\\s*\\?\\s*' + l + '\\s*:\\s*' + l)))) sifirKol = m[2];
  assert.ok(sifirKol !== null, 'eklenen=0 kolu seçilebilir olmalı: ' + satir.trim());
  assert.ok(!sifirKol.includes('✅'), 'eklenen=0 toast nötr (✅ YOK): ' + sifirKol);
});
