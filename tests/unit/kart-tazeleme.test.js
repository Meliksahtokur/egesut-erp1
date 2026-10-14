// tests/unit/kart-tazeleme.test.js — Faz 4 (PLAN ### Faz 4 Step 1 birebir).
// NOT: 'iptal-sonrasi-kart-guncel' + 's4-devam-rozeti' genişletilmiş hâlleriyle
// tests/unit/cd-protokol-iptal-ui.test.js içinde de koşar (yerleşim sapması;
// niyet korunur, taşınmaz). Bu dosya PLAN'ın emrettiği addır.
'use strict';
const test = require('node:test'); const assert = require('node:assert');
const { extractFunctionSource } = require('./support/loadModule.js');
test('iptal-sonrasi-kart-guncel', () => {
  assert.match(extractFunctionSource('js/ui.js', 'caseTohumlamaIptal'), /pullTables\(\[[^\]]*'gorev_log'/);
});
test('s4-devam-rozeti', () => {
  assert.ok(extractFunctionSource('js/ui.js', '_ovsyncS4SatirHtml').includes('alt_vakalar'));
});
