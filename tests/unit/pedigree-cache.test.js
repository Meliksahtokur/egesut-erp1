// tests/unit/pedigree-cache.test.js
// js/pedigree/pedigree-api.js — P2 Task 4 cache davranışı (plan 4.1-4.3).
// SEMANTİK (plan 4.1, zarf davranış maddesi): network RPC KOŞULSUZ denenir;
// cache yalnız iletim hatası fallback'idir (offline cache — request-dedup DEĞİL).
// Üç kilit senaryo + invalidation kilidi:
//   1) online çağrı → RPC'ye gider ve cache'e yazılır
//   2) ikinci erişim (ağ kesikken) cache'ten aynı payload'ı alır
//   3) ağ yokken YENİ görünüm isteği → açık "çevrimdışı" hatası
//   4) invalidateCache() → Map TAMAMEN boşalır (hedefli invalidation yok)
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule } = require('./support/loadModule.js');

// rpc() wrapper stub'u — hata → throw, başarı → data (js/api.js rpc sözleşmesi)
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
  stub.offline = (msg) => { // tüm handler'lar iletim hatası fırlatır
    for (const k of Object.keys(handlers)) {
      handlers[k] = () => { throw new Error(msg || 'İnternet bağlantısı gerekli'); };
    }
  };
  return stub;
}

function loadApi(stub) {
  return loadBrowserModule('js/pedigree/pedigree-api.js', {
    extra: { rpc: stub },
    expose: ['PEDIGREE_CACHE'],
  });
}

function payloadFor(focus) {
  return {
    focus,
    nodes: [{ id: focus, kind: 'farm_animal', label: focus }],
    edges: [],
    meta: { ancestor_depth: 4, descendant_depth: 1, truncated: false },
  };
}

test('SENARYO 1 — online çağrı RPC\'ye gider ve cache\'e yazılır', async () => {
  const stub = makeRpcStub();
  stub.on('pedigree_subgraph_for_animal', () => payloadFor('H-1'));
  const m = loadApi(stub);
  const out = await m.window.pedigreeApi.subgraphForAnimal('H-1');
  assert.strictEqual(stub.calls.length, 1);
  assert.strictEqual(m.exposed.PEDIGREE_CACHE.size, 1);
  assert.strictEqual(out.focus, 'H-1');
});

test('online\'da ikinci erişim RPC\'yi tazeler (network-first kilidi — plan 4.1 adım 1)', async () => {
  const stub = makeRpcStub();
  let rev = 0;
  stub.on('pedigree_subgraph_for_animal', () => {
    const p = payloadFor('H-1');
    p.meta.revision = ++rev;
    return p;
  });
  const m = loadApi(stub);
  const api = m.window.pedigreeApi;
  const first = await api.subgraphForAnimal('H-1');
  const second = await api.subgraphForAnimal('H-1');
  assert.strictEqual(stub.calls.length, 2, 'network-first: cache online\'da RPC\'yi atlamaz');
  assert.strictEqual(second.meta.revision, 2, 'taze payload cache\'i de günceller');
  assert.notStrictEqual(second, first);
  // farklı depth = farklı görünüm = farklı anahtar
  await api.subgraphForAnimal('H-1', 6, 1);
  assert.strictEqual(m.exposed.PEDIGREE_CACHE.size, 2);
});

test('SENARYO 2 — ikinci erişim (ağ kesikken) cache\'ten aynı payload\'ı alır', async () => {
  const stub = makeRpcStub();
  stub.on('pedigree_subgraph_for_animal', () => payloadFor('H-1'));
  const m = loadApi(stub);
  const api = m.window.pedigreeApi;
  const first = await api.subgraphForAnimal('H-1');
  stub.offline(); // ağ kesilir — artık her RPC denemesi iletim hatası fırlatır
  // RPC denemesi YAPILIR (network-first) ama hata cache fallback'ine döner
  const second = await api.subgraphForAnimal('H-1');
  assert.ok(stub.calls.length >= 2, 'deneme yapılır');
  assert.deepStrictEqual(second, first, 'hata yerine cache\'ten aynı payload (değer) dönmeli');
  // farklı depth = YENİ görünüm = cache'te yok → SENARYO 3'e düşer
  await assert.rejects(api.subgraphForAnimal('H-1', 6, 1), { message: 'İnternet bağlantısı gerekli' });
  assert.strictEqual(m.exposed.PEDIGREE_CACHE.size, 1);
});

test('SENARYO 3 — ağ yokken YENİ görünüm isteği açık "çevrimdışı" hatası verir', async () => {
  const stub = makeRpcStub();
  stub.on('pedigree_subgraph_for_animal', () => payloadFor('H-1'));
  const m = loadApi(stub);
  await m.window.pedigreeApi.subgraphForAnimal('H-1'); // cache: H-1@4/1
  stub.offline();
  await assert.rejects(
    m.window.pedigreeApi.subgraphForAnimal('H-2'), // YENİ görünüm
    { message: 'İnternet bağlantısı gerekli' }
  );
  // cache bozulmadı
  assert.strictEqual(m.exposed.PEDIGREE_CACHE.size, 1);
});

test('ağ yokken cache\'te olan görünüm aynı payload (değer) ile döner', async () => {
  const stub = makeRpcStub();
  stub.on('pedigree_subgraph_for_animal', () => payloadFor('H-1'));
  const m = loadApi(stub);
  const first = await m.window.pedigreeApi.subgraphForAnimal('H-1');
  stub.offline();
  const second = await m.window.pedigreeApi.subgraphForAnimal('H-1');
  assert.deepStrictEqual(second, first, 'yapısal olarak aynı payload');
});

test('iletim hatası varyantları cache fallback\'ine girer (Failed to fetch vb.)', async () => {
  const stub = makeRpcStub();
  stub.on('pedigree_subgraph_for_animal', () => payloadFor('H-1'));
  const m = loadApi(stub);
  const first = await m.window.pedigreeApi.subgraphForAnimal('H-1');
  stub.offline('Failed to fetch');
  assert.deepStrictEqual(await m.window.pedigreeApi.subgraphForAnimal('H-1'), first);
});

test('_trErr sınıfı "Sunucuya ulaşılamıyor" da iletim hatası sayılır (review bulgusu kilidi)', async () => {
  const stub = makeRpcStub();
  stub.on('pedigree_subgraph_for_animal', () => payloadFor('H-1'));
  const m = loadApi(stub);
  const first = await m.window.pedigreeApi.subgraphForAnimal('H-1');
  stub.offline('Sunucuya ulaşılamıyor'); // api.js _trErr: 'Failed to fetch'/'network' → bu mesaj
  assert.deepStrictEqual(await m.window.pedigreeApi.subgraphForAnimal('H-1'), first,
    'bu sınıf fallback\'i ATLAMAMALI');
});

test('çağıranın payload mutation\'ı cache\'i kirletemez (review bulgusu kilidi)', async () => {
  const stub = makeRpcStub();
  stub.on('pedigree_subgraph_for_animal', () => payloadFor('H-1'));
  const m = loadApi(stub);
  const api = m.window.pedigreeApi;
  const first = await api.subgraphForAnimal('H-1');
  // W3 adapter tipik mutation'ı: dönüşüm için payload'ı yerinde değiştirir
  first.nodes.push({ id: 'X', kind: 'external_animal', label: 'kirletici' });
  first.meta.ancestor_depth = 99;
  stub.offline();
  const second = await api.subgraphForAnimal('H-1');
  assert.strictEqual(second.nodes.length, 1, 'kirletici node cache\'e sızmadı');
  assert.strictEqual(second.meta.ancestor_depth, 4, 'cache\'teki meta bozulmadı');
});

test('SENARYO 4 — invalidateCache: Map TAMAMEN boşalır, offline istek artık hata verir', async () => {
  const stub = makeRpcStub();
  stub.on('pedigree_subgraph_for_animal', () => payloadFor('H-1'));
  stub.on('pedigree_integrity_report', () => ({ ok: true }));
  const m = loadApi(stub);
  const api = m.window.pedigreeApi;
  await api.subgraphForAnimal('H-1');
  await api.subgraphForAnimal('H-2', 2, 2);
  await api.integrityReport();
  assert.strictEqual(m.exposed.PEDIGREE_CACHE.size, 3);
  api.invalidateCache();
  assert.strictEqual(m.exposed.PEDIGREE_CACHE.size, 0, 'hedefli invalidation yok — TAM boşaltma');
  // write-sonrası offline dünyada eski payload servis EDİLEMEZ
  stub.offline();
  await assert.rejects(api.subgraphForAnimal('H-1'), { message: 'İnternet bağlantısı gerekli' });
});

test('write-sonrası akış simülasyonu: invalidate sonrası online istek TAZE payload getirir', async () => {
  const stub = makeRpcStub();
  let parentAdded = false;
  stub.on('pedigree_subgraph_for_animal', () => {
    const p = payloadFor('H-1');
    if (parentAdded) p.nodes.push({ id: 'ext-1', kind: 'external_animal', label: 'Dış baba' });
    return p;
  });
  const m = loadApi(stub);
  const api = m.window.pedigreeApi;
  const before = await api.subgraphForAnimal('H-1');
  assert.strictEqual(before.nodes.length, 1);
  // P3'te pedigree_parent_set başarıdan sonra invalidateCache() çağıracak
  parentAdded = true;
  api.invalidateCache();
  const after = await api.subgraphForAnimal('H-1');
  assert.strictEqual(after.nodes.length, 2, 'taze veri gelmeli — bayat cache servis edilmedi');
});
