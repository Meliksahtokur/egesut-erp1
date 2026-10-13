'use strict';
const test = require('node:test'); const assert = require('node:assert');
const { extractFunctionSource } = require('./support/loadModule.js');
test('pg-kapi-sarmal-kilidi', () => {
  for (const [dosya, fn] of [['js/ui.js', '_tedaviGunExecute'], ['js/ui.js', 'caseDayTamamla'],
      ['js/ui.js', 'caseDrugKaydet'], ['js/ui.js', 'caseSablonUygula'], ['js/forms.js', 'submitCase']]) {
    assert.ok(extractFunctionSource(dosya, fn).includes('_pgKapiHata('), fn + ': PG kapı sarmalı (§18.8)');
  }
});
