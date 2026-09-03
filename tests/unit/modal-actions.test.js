'use strict';
// Pilot 2: router-modal empty-state buttons must dispatch registered actions
// (MODAL-ROUTER-01), not inline onclick openM calls.
const { test } = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule');

function loadRegistry() {
  let captured = null;
  const calls = [];
  const mod = loadBrowserModule('js/utils/handlers.js', {
    extra: {
      registerActions: (map) => { captured = map; },
      openM: (id) => calls.push(`openM:${id}`),
      openStokAdd: () => calls.push('openStokAdd'),
    },
  });
  return { captured, calls };
}

test('empty-state modal buttons route through registered actions', () => {
  const { captured, calls } = loadRegistry();
  assert.ok(captured, 'handlers.js must register its action map');
  assert.strictEqual(typeof captured['open-kizginlik-modal'], 'function', 'kızgınlık empty-state action kayıtlı olmalı');
  captured['open-kizginlik-modal']();
  assert.deepStrictEqual(calls, ['openM:m-kizginlik']);
  captured['open-insem-modal']();
  assert.deepStrictEqual(calls, ['openM:m-kizginlik', 'openM:m-insem']);
  captured['stok-add-open']();
  assert.strictEqual(calls[calls.length - 1], 'openStokAdd');
});

test('generated empty-state markup uses data-action, not inline openM onclick', () => {
  const ui = require('node:fs').readFileSync('js/ui.js', 'utf8');
  assert.ok(!/onclick="openM\('/.test(ui), 'inline onclick openM kalmamalı');
  assert.ok(/data-action="open-kizginlik-modal"/.test(ui));
  assert.ok(/data-action="open-insem-modal"/.test(ui));
  assert.ok(/data-action="stok-add-open"/.test(ui));
});
