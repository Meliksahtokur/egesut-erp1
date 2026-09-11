// tests/unit/pedigree-api.test.js
// js/pedigree/pedigree-api.js — P2 Task 4 arayüz/RPC-kablolama testleri.
// Cache davranışı (offline fallback, invalidation) pedigree-cache.test.js'te.
// TESTING-01 deseni: loadBrowserModule + rpc stub (api.js rpc() wrapper
// sözleşmesi: hata → throw, başarı → data). Ağ çağrısı YOK.
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');

// rpc() wrapper stub'u — js/api.js rpc() sözleşmesi (throw/return data)
function makeRpcStub() {
  const calls = [];
  const handlers = {};
  const stub = async (name, params) => {
    calls.push({ name, params });
    const h = handlers[name];
    if (!h) throw new Error('stub: rpc "' + name + '" tanımlı değil');
    return h(params);
  };
  stub.calls = calls;
  stub.on = (name, fn) => { handlers[name] = fn; };
  return stub;
}

function loadApi(stub) {
  return loadBrowserModule('js/pedigree/pedigree-api.js', {
    extra: { rpc: stub },
    expose: ['PEDIGREE_CACHE', 'PEDIGREE_FARM_ID', 'PEDIGREE_ALGO_VERSION'],
  });
}

// Ağdan dönüş wrapper tarafından mühürlenir (W2-fix): meta.cached=false.
// (Cache-servisli dönüşlerde true — bakınız pedigree-cache.test.js)
const PAYLOAD = {
  focus: 'u-1',
  nodes: [{ id: 'u-1', kind: 'farm_animal', label: '136' }],
  edges: [],
  meta: { ancestor_depth: 4, descendant_depth: 1, truncated: false, cached: false },
};

// vm realm: modül içi nesneler farklı prototipte gelir — deepStrictEqual
// prototip farkından düşer (ai-asistan.test.js dersi), yapısal kontrol kullan.
function sameJson(a, b) {
  return JSON.stringify(a) === JSON.stringify(b);
}

test('window.pedigreeApi yüzeyi: W3 sözleşmesi birebir', () => {
  const m = loadApi(makeRpcStub());
  const api = m.window.pedigreeApi;
  assert.ok(api, 'window.pedigreeApi tanımlı olmalı');
  assert.strictEqual(typeof api.subgraphForAnimal, 'function');
  assert.strictEqual(typeof api.subgraphForNode, 'function');
  assert.strictEqual(typeof api.integrityReport, 'function');
  assert.strictEqual(typeof api.invalidateCache, 'function');
});

test('subgraphForAnimal: pedigree_subgraph_for_animal + p_* parametre adları, default 4/1', async () => {
  const stub = makeRpcStub();
  stub.on('pedigree_subgraph_for_animal', () => PAYLOAD);
  const m = loadApi(stub);
  const out = await m.window.pedigreeApi.subgraphForAnimal('H-1');
  assert.strictEqual(stub.calls.length, 1);
  assert.strictEqual(stub.calls[0].name, 'pedigree_subgraph_for_animal');
  assert.ok(sameJson(stub.calls[0].params, {
    p_hayvan_id: 'H-1',
    p_ancestor_depth: 4,
    p_descendant_depth: 1,
  }), JSON.stringify(stub.calls[0].params));
  // Task 3 dönüş kontratı aynen döner (değer olarak — cache savunma kopyası)
  assert.deepStrictEqual(out, PAYLOAD);
});

test('subgraphForAnimal: açık depth override RPC parametrelerine geçer', async () => {
  const stub = makeRpcStub();
  stub.on('pedigree_subgraph_for_animal', () => PAYLOAD);
  const m = loadApi(stub);
  await m.window.pedigreeApi.subgraphForAnimal('H-2', 8, 3);
  assert.ok(sameJson(stub.calls[0].params, {
    p_hayvan_id: 'H-2',
    p_ancestor_depth: 8,
    p_descendant_depth: 3,
  }), JSON.stringify(stub.calls[0].params));
});

test('subgraphForNode: pedigree_subgraph + p_focus_node_id', async () => {
  const stub = makeRpcStub();
  stub.on('pedigree_subgraph', () => PAYLOAD);
  const m = loadApi(stub);
  await m.window.pedigreeApi.subgraphForNode('uuid-9', 2, 1);
  assert.strictEqual(stub.calls[0].name, 'pedigree_subgraph');
  assert.ok(sameJson(stub.calls[0].params, {
    p_focus_node_id: 'uuid-9',
    p_ancestor_depth: 2,
    p_descendant_depth: 1,
  }), JSON.stringify(stub.calls[0].params));
});

test('integrityReport: pedigree_integrity_report, paramsiz; anahtar "-" focus diliminde', async () => {
  const stub = makeRpcStub();
  stub.on('pedigree_integrity_report', () => ({ ok: true, rows: [] }));
  const m = loadApi(stub);
  await m.window.pedigreeApi.integrityReport();
  assert.strictEqual(stub.calls[0].name, 'pedigree_integrity_report');
  assert.strictEqual(JSON.stringify(stub.calls[0].params), '{}');
  const keys = Array.from(m.exposed.PEDIGREE_CACHE.keys());
  assert.strictEqual(keys.length, 1);
  assert.ok(keys[0].includes(':pedigree_integrity_report:-:'), 'focus "-" olmalı: ' + keys[0]);
});

test('boş id → RPC hiç çağrılmadan reddedilir', async () => {
  const stub = makeRpcStub();
  stub.on('pedigree_subgraph_for_animal', () => PAYLOAD);
  stub.on('pedigree_subgraph', () => PAYLOAD);
  const m = loadApi(stub);
  await assert.rejects(m.window.pedigreeApi.subgraphForAnimal(''), { message: 'hayvanId zorunlu' });
  await assert.rejects(m.window.pedigreeApi.subgraphForNode(''), { message: 'nodeId zorunlu' });
  assert.strictEqual(stub.calls.length, 0);
});

test('domain hatası (miss\'te) aynen yükselir ve cache DOLDURULMAZ', async () => {
  const stub = makeRpcStub();
  stub.on('pedigree_subgraph_for_animal', () => { throw new Error('Yetkisiz işlem'); });
  const m = loadApi(stub);
  await assert.rejects(m.window.pedigreeApi.subgraphForAnimal('H-9'), { message: 'Yetkisiz işlem' });
  assert.strictEqual(m.exposed.PEDIGREE_CACHE.size, 0, 'hatalı yanıt cache\'e yazılmamalı');
});

test('cache anahtarı farm-scope öneklidir: farm:<farm_id>:...', async () => {
  const stub = makeRpcStub();
  stub.on('pedigree_subgraph_for_animal', () => PAYLOAD);
  const m = loadApi(stub);
  await m.window.pedigreeApi.subgraphForAnimal('H-1');
  const keys = Array.from(m.exposed.PEDIGREE_CACHE.keys());
  assert.ok(keys[0].startsWith('farm:' + m.exposed.PEDIGREE_FARM_ID + ':'), keys[0]);
});
