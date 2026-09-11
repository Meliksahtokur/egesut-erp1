'use strict';
// Pedigree view birim testleri (W3-fix F1 — luna review kapsamı).
// Yaşam döngüsü (init/destroy), breadthfirst layout konfigürasyonunun
// cytoscape'a iletilmesi, fit/resize/relayout ve node tap bağlama.
// TESTING-01: cytoscape ve pedigreeStyle stub'la yüklenir — product kaynak
// kopyalanmaz; view modülü global cytoscape'ı init anında çözer.
const { test } = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule, makeElement } = require('./support/loadModule');

function makeCytoscapeStub() {
  const calls = { create: [], layouts: [], fits: [], resizes: 0, destroys: 0, taps: [] };
  const cytoscape = (opts) => {
    calls.create.push(opts);
    return {
      layout: (cfg) => { calls.layouts.push(cfg); return { run: () => {} }; },
      fit: (_el, pad) => { calls.fits.push(pad); },
      resize: () => { calls.resizes++; },
      destroy: () => { calls.destroys++; },
      on: (ev, sel, fn) => { calls.taps.push({ ev, sel, fn }); },
    };
  };
  return { cytoscape, calls };
}

function kur(cytoscape) {
  const extra = { pedigreeStyle: () => [] };
  if (cytoscape) extra.cytoscape = cytoscape;
  return loadBrowserModule('js/pedigree/pedigree-view.js', { extra });
}

const ELEMENTS = {
  nodes: [{ group: 'nodes', data: { id: 'N1', label: 'A' }, classes: 'focus farm' }],
  edges: [],
};

test('init: breadthfirst layout yapılandırması cytoscape\'a iletilir', () => {
  const stub = makeCytoscapeStub();
  const { sandbox } = kur(stub.cytoscape);
  const container = makeElement('div');
  const handle = sandbox.pedigreeViewInit(container, ELEMENTS, {});
  assert.ok(handle && typeof handle.destroy === 'function', 'handle döner');
  assert.strictEqual(stub.calls.create.length, 1);
  assert.strictEqual(stub.calls.create[0].container, container, 'konteyner cytoscape\'a verilir');
  assert.deepStrictEqual(
    JSON.parse(JSON.stringify(stub.calls.create[0].elements)),
    JSON.parse(JSON.stringify([].concat(ELEMENTS.nodes, ELEMENTS.edges))),
    'element seti cytoscape\'a olduğu gibi verilir (vm-realm: JSON taşınır)',
  );
  assert.deepStrictEqual(stub.calls.create[0].style, [], 'style pedigreeStyle() çıktısıdır (stub: boş dizi)');
  // İlk layout init içinde koşar: breadthfirst + directed (parent→child)
  assert.strictEqual(stub.calls.layouts.length, 1);
  assert.strictEqual(stub.calls.layouts[0].name, 'breadthfirst', 'P2 layout kütüphanesi breadthfirst (ELK yok)');
  assert.strictEqual(stub.calls.layouts[0].directed, true);
  assert.strictEqual(stub.calls.layouts[0].animate, false);
  // opts.roots verilirse layout'a iletilir
  sandbox.pedigreeViewInit(makeElement('div'), ELEMENTS, { roots: '#N1' });
  assert.strictEqual(stub.calls.layouts[1].roots, '#N1');
});

test('cytoscape globali yoksa açık hata (sessiz boş ekran değil)', () => {
  const { sandbox } = kur(null);
  assert.throws(
    () => sandbox.pedigreeViewInit(makeElement('div'), ELEMENTS, {}),
    /Cytoscape yüklenemedi/,
  );
});

test('yaşam döngüsü: fit/resize/relayout/destroy handle üzerinden', () => {
  const stub = makeCytoscapeStub();
  const { sandbox } = kur(stub.cytoscape);
  const handle = sandbox.pedigreeViewInit(makeElement('div'), ELEMENTS, {});
  assert.strictEqual(stub.calls.fits.length, 0, 'init fit\'i layout\'a bırakır');
  handle.fit();
  assert.strictEqual(stub.calls.fits.length, 1);
  assert.strictEqual(stub.calls.fits[0], 24, 'zoom-to-fit 24px padding');
  handle.resize();
  assert.strictEqual(stub.calls.resizes, 1);
  const layoutSayisi = stub.calls.layouts.length;
  handle.relayout();
  assert.strictEqual(stub.calls.layouts.length, layoutSayisi + 1, 're-layout yeni layout kurar');
  assert.strictEqual(stub.calls.fits.length, 2, 're-layout sonrası tekrar fit');
  handle.destroy();
  assert.strictEqual(stub.calls.destroys, 1, 'cytoscape örneği yok edilir');
});

test('node tap dinleyicisi: tap+node selektörüyle bağlanır, hedef teslim edilir', () => {
  const stub = makeCytoscapeStub();
  const { sandbox } = kur(stub.cytoscape);
  const handle = sandbox.pedigreeViewInit(makeElement('div'), ELEMENTS, {});
  const gelen = [];
  handle.onTapNode((node) => gelen.push(node));
  assert.strictEqual(stub.calls.taps.length, 1);
  assert.strictEqual(stub.calls.taps[0].ev, 'tap');
  assert.strictEqual(stub.calls.taps[0].sel, 'node');
  stub.calls.taps[0].fn({ target: 'SAHTE-NODE' });
  assert.deepStrictEqual(gelen, ['SAHTE-NODE']);
});
