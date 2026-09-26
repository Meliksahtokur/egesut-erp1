// tests/unit/det-kisir-chip.test.js — C2 (cila2): hayvan detay kartında 💲 Kısır rozeti
// Kabul: kisir=true → kart chip'lerinde "💲 Kısır" (liste satırı badge'iyle aynı dil);
//        kisir=false/undefined → chip yok; gebe/aktif vaka chip'leri korunur.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { loadExtractedFunction } = require('./support/loadModule.js');

const _detChipsHtml = loadExtractedFunction('js/ui.js', '_detChipsHtml', {
  extra: {
    esc: s => String(s),
    dFwd: (t, n) => t + '+' + n,
  },
});

const baseHayvan = { grup: 'Düve (Büyük)', padok: 'Düve Padok (Büyük)' };

test('C2-1: kisir=true → 💲 Kısır chip basılır ve amber stilli', () => {
  const html = _detChipsHtml({ ...baseHayvan, kisir: true }, [], 0, []);
  assert.match(html, /💲 Kısır/);
  assert.match(html, /rgba\(255,160,0,\.15\)/);
});

test('C2-2: kisir=false/undefined → Kısır chip YOK', () => {
  assert.ok(!/Kısır/.test(_detChipsHtml({ ...baseHayvan, kisir: false }, [], 0, [])));
  assert.ok(!/Kısır/.test(_detChipsHtml({ ...baseHayvan }, [], 0, [])));
});

test('C2-3: mevcut chip sözleşmesi korunur (vaka + gebe)', () => {
  const html = _detChipsHtml({ ...baseHayvan, kisir: true }, [{ sonuc: 'Gebe', tarih: bugunISO(-40) }], 2, [{}, {}]);
  assert.match(html, /🚨 2 aktif vaka/);
  assert.match(html, /🤰 40\. gün/);
  assert.match(html, /chip-g/);
});

function bugunISO(gunOffset) {
  const d = new Date(Date.now() + gunOffset * 86400000);
  return d.toISOString().slice(0, 10);
}
