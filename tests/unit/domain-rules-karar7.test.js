// tests/unit/domain-rules-karar7.test.js
'use strict';
const test = require('node:test'); const assert = require('node:assert');
const fs = require('node:fs'); const path = require('node:path');
const dr = () => fs.readFileSync(path.join(__dirname, '..', '..', '.harness/references/domain-rules.md'), 'utf8');
test('domain-rules-karar7-kilidi', () => {
  const m = /Üreme vakaları: ([^\n]*?)\.(?=\s|$)/m.exec(dr());   // cümle sonu: nokta + boşluk/satır sonu ('§18.18' içindeki nokta durdurmaz)
  assert.ok(m && m[1].includes('İnaktif Ovaryum') && !m[1].includes('Anoestrus'), '§18.16 karar 7');
  assert.match(dr(), /^18\. \*\*Hastalık = Ovsync içinde gün \(karar 10/m, '§18.18 yeni başlık (karar 10)');
  assert.ok(dr().includes('inaktif/kist için ayrı vaka AÇILMAZ'), '§18.18 ayrı vaka yok');
  assert.ok(dr().includes('ön-öneri inaktifte CAROFERTIN-E 20 ml, kistte boş'), 'karar 7 gerçek ilaç ön-önerisi');
  assert.match(dr(), /HASTALIK_KAT` — elle Vaka Aç seçim listesi/, '§8 başlığı gerçeğe göre');
});
