// tests/unit/pedigree-cache.test.js
// js/pedigree/pedigree-api.js — P2 Task 4 cache davranışı.
// SEMANTİK (W2-fix, cache-first — lead demo kapısı ölçümü: 3 açılışta 3 RPC
// atılıyordu; goal G5 "zaten açılmış görünüm memory cache'ten" ONLINE'da
// karşılanmalı): sıcak anahtar ağa HİÇ gitmez; ağ yalnız cache miss'te denenir.
// Kilit senaryolar (zarf a-d):
//   a) ikinci erişim ağ çağrısı ATMAZ (stub sayacı: 1 → hâlâ 1)
//   b) cache-servisli payload meta.cached===true; ağ payload'unda false
//   c) invalidateCache sonrası erişim yeniden ağa gider
//   d) offline miss açık "çevrimdışı" hatası verir
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

test('SENARYO 1 — ilk erişim (miss) RPC\'ye gider ve cache\'e yazılır', async () => {
  const stub = makeRpcStub();
  stub.on('pedigree_subgraph_for_animal', () => payloadFor('H-1'));
  const m = loadApi(stub);
  const out = await m.window.pedigreeApi.subgraphForAnimal('H-1');
  assert.strictEqual(stub.calls.length, 1);
  assert.strictEqual(m.exposed.PEDIGREE_CACHE.size, 1);
  assert.strictEqual(out.focus, 'H-1');
});

test('(a) SENARYO 2 — ikinci erişim ağ çağrısı ATMAZ (cache-first kilidi)', async () => {
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
  assert.strictEqual(stub.calls.length, 1, 'demo ölçümü kilidi: 3 açılışta 3 RPC olamaz');
  assert.strictEqual(second.meta.revision, 1, 'cache\'ten servis edildi — revize payload GELMEDİ');
  // aynı payload (değer) — meta.cached mührü hariç (ağdan false, cache'ten true)
  assert.deepStrictEqual(second.nodes, first.nodes);
  assert.deepStrictEqual(second.edges, first.edges);
  assert.strictEqual(second.focus, first.focus);
  assert.strictEqual(second.meta.revision, first.meta.revision);
  // farklı depth = YENİ görünüm = farklı anahtar = miss → RPC'ye gider
  await api.subgraphForAnimal('H-1', 6, 1);
  assert.strictEqual(stub.calls.length, 2);
  assert.strictEqual(m.exposed.PEDIGREE_CACHE.size, 2);
});

test('(b) meta.cached mührü: cache\'ten true, ağdan false', async () => {
  const stub = makeRpcStub();
  stub.on('pedigree_subgraph_for_animal', () => payloadFor('H-1'));
  const m = loadApi(stub);
  const api = m.window.pedigreeApi;
  const fromNetwork = await api.subgraphForAnimal('H-1');
  assert.strictEqual(fromNetwork.meta.cached, false, 'ağ payload\'u cached=false mühürlü');
  const fromCache = await api.subgraphForAnimal('H-1');
  assert.strictEqual(fromCache.meta.cached, true, 'cache payload\'u cached=true mühürlü');
  // mühür DÖNÜŞ sınırında: saklanan snapshot W1 kontratı gibi mühürsüz kalır
  const stored = Array.from(m.exposed.PEDIGREE_CACHE.values())[0];
  assert.strictEqual('cached' in stored.meta, false, 'saklanan snapshot mühürsüz (W1-saf)');
});

test('(c) invalidateCache sonrası erişim yeniden AĞA gider', async () => {
  const stub = makeRpcStub();
  let rev = 0;
  stub.on('pedigree_subgraph_for_animal', () => {
    const p = payloadFor('H-1');
    p.meta.revision = ++rev;
    return p;
  });
  const m = loadApi(stub);
  const api = m.window.pedigreeApi;
  await api.subgraphForAnimal('H-1');
  api.invalidateCache();
  const after = await api.subgraphForAnimal('H-1');
  assert.strictEqual(stub.calls.length, 2, 'invalidation sonrası miss → ağ');
  assert.strictEqual(after.meta.revision, 2, 'taze payload');
  assert.strictEqual(after.meta.cached, false);
});

test('SENARYO 3 (d) — offline MISS yeni görünüm isteği açık "çevrimdışı" hatası verir', async () => {
  const stub = makeRpcStub();
  stub.on('pedigree_subgraph_for_animal', () => payloadFor('H-1'));
  const m = loadApi(stub);
  await m.window.pedigreeApi.subgraphForAnimal('H-1'); // cache: H-1@4/1
  stub.offline();
  await assert.rejects(
    m.window.pedigreeApi.subgraphForAnimal('H-2'), // YENİ görünüm = miss
    { message: 'İnternet bağlantısı gerekli' }
  );
  assert.strictEqual(m.exposed.PEDIGREE_CACHE.size, 1);
});

test('offline + sıcak anahtar → cache\'ten, ağ denenmez (hit-path gücü)', async () => {
  const stub = makeRpcStub();
  stub.on('pedigree_subgraph_for_animal', () => payloadFor('H-1'));
  const m = loadApi(stub);
  const api = m.window.pedigreeApi;
  const first = await api.subgraphForAnimal('H-1');
  stub.offline(); // ağ ölü — ama istek sıcak anahtara geliyor
  const second = await api.subgraphForAnimal('H-1');
  assert.strictEqual(stub.calls.length, 1, 'offline hit-path ağ çağrısı atmaz');
  assert.strictEqual(second.meta.cached, true);
  assert.deepStrictEqual(second.nodes, first.nodes);
  assert.deepStrictEqual(second.edges, first.edges);
});

test('offline miss hatası AYNEN yükselir (_trErr "Sunucuya ulaşılamıyor" sınıfı dahil)', async () => {
  const stub = makeRpcStub();
  stub.on('pedigree_subgraph_for_animal', () => payloadFor('H-1'));
  const m = loadApi(stub);
  stub.offline('Sunucuya ulaşılamıyor'); // api.js _trErr iletim-sınıfı mesajı
  await assert.rejects(
    m.window.pedigreeApi.subgraphForAnimal('H-1'),
    { message: 'Sunucuya ulaşılamıyor' }
  );
});

test('SENARYO 4 — invalidateCache: Map TAMAMEN boşalır, offline miss artık hata verir', async () => {
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
  assert.strictEqual(after.nodes.length, 2, 'taze veri — bayat cache servis edilmedi');
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
  // cache-first: ikinci erişim AĞA gitmez, cache'ten gelir
  const second = await api.subgraphForAnimal('H-1');
  assert.strictEqual(stub.calls.length, 1);
  assert.strictEqual(second.nodes.length, 1, 'kirletici node cache\'e sızmadı');
  assert.strictEqual(second.meta.ancestor_depth, 4, 'cache\'teki meta bozulmadı');
});
