// tests/unit/domain-rules-karar7.test.js
'use strict';
const test = require('node:test'); const assert = require('node:assert');
const fs = require('node:fs'); const path = require('node:path');
const dr = () => fs.readFileSync(path.join(__dirname, '..', '..', '.harness/references/domain-rules.md'), 'utf8');
test('domain-rules-karar7-kilidi', () => {
  const m = /Üreme vakaları: ([^\n]*?)\.(?=\s|$)/m.exec(dr());   // cümle sonu: nokta + boşluk/satır sonu ('§18.18' içindeki nokta durdurmaz)
  assert.ok(m && m[1].includes('İnaktif Ovaryum') && !m[1].includes('Anoestrus'), '§18.16 karar 7');
  assert.match(dr(), /^18\. \*\*İnaktif ovaryum\/kist alt vakası/m, '§18.18 var');
  assert.match(dr(), /HASTALIK_KAT` — elle Vaka Aç seçim listesi/, '§8 başlığı gerçeğe göre');
});
