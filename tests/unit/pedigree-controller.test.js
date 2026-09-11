'use strict';
// Pedigree controller birim testleri (W3-fix F1 — luna review kapsamı).
// Lazy aktivasyon (Soy ilk aktive olmadan RPC yok — tekrar istekte 0), stale
// response guard (_detOpenId deyimi), farm node → openDet yönlendirmesi,
// external node → silent sheet, +2 kuşak parametre değişimi + clamp 8,
// cached/offline rozeti ve pedigreeApi yokken açık hata.
// TESTING-01: gerçek adapter yüklenip extra ile verilir (kaynak kopyası yok);
// pedigreeApi/pedigreeViewInit/el yaprakları stub — yalnız controller davranışı
// iddia edilir, stub davranışı değil.
const { test } = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule, makeDomStub, makeElement } = require('./support/loadModule');

const { sandbox: adapterSb } = loadBrowserModule('js/pedigree/pedigree-adapter.js');

const tick = () => new Promise((r) => setImmediate(r));

function payload(id, over) {
  return Object.assign({
    focus: 'N-' + id,
    nodes: [{ id: 'N-' + id, kind: 'farm_animal', farm_animal_id: id, label: id, sex: 'Dişi' }],
    edges: [],
    meta: {},
  }, over);
}

function kur(opts = {}) {
  const document = makeDomStub();
  const elMap = {};
  for (const id of ['tab-pedigree', 'ped-badge', 'ped-depth-hint', 'ped-tree-box']) {
    elMap[id] = document.__setEl(id, makeElement('div'));
  }
  const api = { calls: [], pending: [] };
  const makeP = () => new Promise((resolve, reject) => api.pending.push({ resolve, reject }));
  if (!opts.apiYok) {
    api.subgraphForAnimal = (id, anc, desc) => { api.calls.push({ fn: 'animal', id, anc, desc }); return makeP(); };
    api.subgraphForNode = (id, anc, desc) => { api.calls.push({ fn: 'node', id, anc, desc }); return makeP(); };
  }
  const toasts = [];
  const openDetCalls = [];
  const view = { calls: [] };
  const viewHandle = {
    cy: {}, relayout() {}, fit() {}, resize() {}, destroy() {},
    onTapNode(fn) { view.tapFn = fn; },
  };
  const extra = {
    // helpers.js tarayıcı-globali — controller g()/esc() üzerinden çözer
    g: (id) => document.getElementById(id),
    esc: (s) => String(s == null ? '' : s),
    escAttr: (s) => String(s == null ? '' : s),
    fmtTarih: (s) => s,
    showTab2: () => {},
    toast: (msg, err) => toasts.push(String(msg) + (err ? ' [err]' : '')),
    openDet: (id) => openDetCalls.push(id),
    pedigreeToElements: adapterSb.pedigreeToElements,
    pedigreeViewInit: (mount, els) => { view.calls.push({ mount, els }); return viewHandle; },
  };
  if (!opts.apiYok) extra.pedigreeApi = api;
  const { sandbox } = loadBrowserModule('js/pedigree/pedigree-controller.js', { dom: document, extra });
  return {
    sandbox, document, api, toasts, openDetCalls, view,
    el: (id) => elMap[id],
    cozSon: async (val) => { api.pending[api.pending.length - 1].resolve(val); await tick(); },
    reddetSon: async (err) => { api.pending[api.pending.length - 1].reject(err); await tick(); },
  };
}

test('lazy aktivasyon: Soy sekmesi aktive edilmeden RPC yok; ilk aktivasyon 1 RPC', async () => {
  const { sandbox, api, view, cozSon } = kur();
  sandbox.pedigreeSetFocus('H1', false);
  await tick();
  assert.strictEqual(api.calls.length, 0, 'openDet focus\'u bildirir ama RPC atmaz');
  sandbox.pedigreeTabActivated();
  await cozSon(payload('H1'));
  assert.strictEqual(api.calls.length, 1, 'ilk aktivasyon tam 1 RPC');
  assert.deepStrictEqual(api.calls[0], { fn: 'animal', id: 'H1', anc: 4, desc: 1 });
  assert.strictEqual(view.calls.length, 1, 'yanıt geldikten sonra tek çizim');
});

test('aynı görünüm tekrar istenmez: başarılı ilk aktivasyondan sonra 0 yeni RPC', async () => {
  const { sandbox, api, cozSon } = kur();
  sandbox.pedigreeSetFocus('H1', true);
  await cozSon(payload('H1'));
  assert.strictEqual(api.calls.length, 1);
  sandbox.pedigreeTabActivated();   // aynı focus+derinlik → rendered-key eşleşir
  await tick();
  assert.strictEqual(api.calls.length, 1, 'tekrar aktivasyon yeni RPC atmaz (önbellek/çizili yol)');
  sandbox.pedigreeTabActivated();
  await tick();
  assert.strictEqual(api.calls.length, 1);
});

test('stale guard: focus değişince eski focus yanıtı çizilmez (_detOpenId deyimi)', async () => {
  const { sandbox, api, view } = kur();
  sandbox.pedigreeSetFocus('H1', true);
  sandbox.pedigreeSetFocus('H2', true);
  assert.strictEqual(api.calls.length, 2);
  await api.pending[0].resolve(payload('H1'));
  await tick();
  assert.strictEqual(view.calls.length, 0, 'H1 yanıtı stale — çizilmez');
  await api.pending[1].resolve(payload('H2'));
  await tick();
  assert.strictEqual(view.calls.length, 1, 'yalnız güncel focus çizilir');
  assert.strictEqual(view.calls[0].els.nodes[0].data.id, 'N-H2');
});

test('farm node tık → openDet(farm_animal_id)', () => {
  const { sandbox, openDetCalls } = kur();
  sandbox.pedigreeNodeTiklandi({ data: () => ({ kind: 'farm_animal', farm_animal_id: 'H9', id: 'N9', label: '9' }) });
  assert.deepStrictEqual(openDetCalls, ['H9']);
});

test('external node tık → non-router silent sheet eklenir/kaldırılır', () => {
  const { sandbox, document } = kur();
  sandbox.pedigreeNodeTiklandi({ data: () => ({ kind: 'external_animal', id: 'N1', label: 'EXT-1', sex: 'Erkek', breed: 'Simental' }) });
  const sheet = document.body.children.find((c) => c.id === 'ped-ext-sheet');
  assert.ok(sheet, 'sheet body\'ye eklenir');
  assert.ok(sheet.innerHTML.includes('EXT-1'), 'düğüm etiketi sheet\'te');
  // Stub doc map'i statik — dinamik sheet'i kaldir'ın bulacağı şekilde kaydet
  document.__setEl('ped-ext-sheet', sheet);
  sandbox.pedigreeExtSheetKaldir();
  assert.ok(!document.body.children.find((c) => c.id === 'ped-ext-sheet'), 'kapatma doğrudan DOM\'dan kaldırır (history yok)');
});

test('+2 kuşak: derinlik 4→6→8, 8\'de clamp (RPC parametresiyle kanıtlanır)', async () => {
  const { sandbox, api, toasts } = kur();
  sandbox.pedigreeSetFocus('H1', true);
  await tick();
  sandbox.pedigreeKusakArtir();
  assert.strictEqual(api.calls[api.calls.length - 1].anc, 6);
  await api.pending[api.pending.length - 1].resolve(payload('H1'));
  await tick();
  sandbox.pedigreeKusakArtir();
  assert.strictEqual(api.calls[api.calls.length - 1].anc, 8);
  await api.pending[api.pending.length - 1].resolve(payload('H1'));
  await tick();
  const once = api.calls.length;
  sandbox.pedigreeKusakArtir();
  await tick();
  assert.strictEqual(api.calls.length, once, '8 üstü istek atılmaz');
  assert.ok(toasts.some((t) => t.includes('8 kuşak')), 'clamp bilgisi toast ile verilir');
});

test('rozet: meta.cached → "Önbellekten"; çevrimdışı hatası → "Çevrimdışı"', async () => {
  const a = kur();
  a.sandbox.pedigreeSetFocus('H1', true);
  await a.cozSon(payload('H1', { meta: { cached: true } }));
  assert.strictEqual(a.el('ped-badge').textContent, 'Önbellekten');
  assert.ok(a.el('ped-badge').style.cssText.includes('display:inline-block'));

  const b = kur();
  b.sandbox.pedigreeSetFocus('H1', true);
  await b.reddetSon(new Error('çevrimdışı: yeni görünüm isteği ağ gerektirir'));
  assert.strictEqual(b.el('ped-badge').textContent, 'Çevrimdışı');
  // Çizili görünüm yokken açık hata paneli basılır (mesajı kullanıcı görür)
  assert.ok(b.el('ped-tree-box').innerHTML.includes('çevrimdışı'), 'açık hata paneli mesajı');
});

test('pedigreeApi yüklenmemişse açık hata paneli (sessiz ölü sekme değil)', async () => {
  const { sandbox, el } = kur({ apiYok: true });
  sandbox.pedigreeSetFocus('H1', true);
  await tick();
  assert.ok(el('ped-tree-box').innerHTML.includes('Pedigree API yüklenemedi'));
});
