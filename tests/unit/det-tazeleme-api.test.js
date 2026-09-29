// tests/unit/det-tazeleme-api.test.js
// kart-tazeleme T1 — pullTables üçlü kontrat (requested/ok/failed) + detInternal
// işareti + gevşek window._detAciksaTazele kancası.
// Sözleşme: docs/plans/2026-09-29-acik-kart-tazeleme-SPEC.md §3.1/§3.4 (v6) —
//   * run RESOLVE olduğunda kanca `window._detAciksaTazele?.(requested, ok, failed, detInternal)`
//     ile çağrılır; reject'te çağrılmaz ("tam red'de kanca doğal olarak çağrılmaz").
//   * `tables.length===0` erken dönüşte kanca çağrılmaz.
//   * `_pullTablesNow(tables)` → `{ ok: string[], failed: string[] }`
//     (ok = başarıyla fetch+IDB yazımı yapanlar).
//   * 4. argüman boolean — `opts.detInternal === true` içsel run işareti, dış pull'da false.
//   * Kanca gevşek bağ: try/catch içinde, api.js DOM bilmez.
// js/api.js TAM modül loadBrowserModule ile yüklenir; stub kalıpları
// tests/unit/api.test.js'ten: makeClient (:45-62), makeIdbStub (:68-98),
// _idb enjeksiyonu (:126-128).
const test = require('node:test');
const assert = require('node:assert');
const vm = require('node:vm');
const {
  loadBrowserModule,
  makeStorage,
} = require('./support/loadModule.js');

const API = 'js/api.js';

function spy(fn = () => {}) {
  const f = (...a) => { f.calls.push(a); return fn(...a); };
  f.calls = [];
  return f;
}

// db.from(...) zinciri — select/eq/order/limit chainable-thenable; `result`
// await edilen tek sonuçtur ({ data, error }).
function fromChain(result = { data: [], error: null }) {
  const chain = {
    select: () => chain, eq: () => chain, order: () => chain, limit: () => chain,
    insert: () => Promise.resolve({ error: null }),
    update: () => { throw new Error('test: update bu fromHandlerda tanımlı değil'); },
    then: (res, rej) => Promise.resolve(result).then(res, rej),
  };
  return chain;
}

// M-01: await edildiğinde REJECT eden from zinciri — fetcher'ın {data,error}
// dönmediği, Promise'i düştüğü gerçek tarz (ağ kopması/istisna vb.).
function rejectingChain(err) {
  const chain = {
    select: () => chain, eq: () => chain, order: () => chain, limit: () => chain,
    then: (res, rej) => Promise.reject(err).then(res, rej),
  };
  return chain;
}

// api.test.js:45-62 makeClient kalıbı (rpc bu testte kullanılmamalı)
function makeClient({ fromHandler } = {}) {
  const calls = { createClient: [], from: [] };
  const client = {
    rpc: async () => ({ data: null, error: { message: 'test stub: rpc bu testte kullanılmamalı' } }),
    from: (table) => {
      calls.from.push(table);
      return fromHandler ? fromHandler(table) : fromChain();
    },
    channel: () => { throw new Error('test: db.channel bu testte kullanılmamalı'); },
  };
  const createClient = (url, key) => { calls.createClient.push({ url, key }); return client; };
  return { createClient, client, calls };
}

// api.test.js:68-98 makeIdbStub kalıbı — idbClearAndPut'ın kullandığı yüzey:
// transaction(store).objectStore.clear/.put + tx.oncomplete (queueMicrotask ile).
function makeIdbStub(initial = {}) {
  const stores = new Map(); // store adı → Map(key → satır)
  for (const [n, rows] of Object.entries(initial)) {
    stores.set(n, new Map(rows.map(r => [r.id, r])));
  }
  const store = (name) => { if (!stores.has(name)) stores.set(name, new Map()); return stores.get(name); };
  const mkOs = (name) => ({
    getAll() {
      const req = {};
      queueMicrotask(() => {
        req.result = [...store(name).values()];
        req.onsuccess?.({ target: { result: req.result } });
      });
      return req;
    },
    put(row) { store(name).set(row.id, row); return {}; },
    add(row) { store(name).set(row.id, row); return {}; },
    delete(key) { store(name).delete(key); return {}; },
    clear() { store(name).clear(); return {}; },
  });
  return {
    transaction(name) {
      const tx = { objectStore: () => mkOs(name) };
      queueMicrotask(() => tx.oncomplete?.({}));
      return tx;
    },
    __snapshot: (name) => [...(stores.get(name)?.values() ?? [])],
  };
}

// Mikrotask havuzunu boşalt (_pullChain zincirleri için — api.test.js:101)
const settle = () => new Promise(r => setImmediate(r));

// api.js yükle + kanca kaydedicisini sandbox window stub'una tak (rec.kanca).
// _idb enjeksiyonu api.test.js:126-128 kalıbıyla.
function loadApi({ fromHandler } = {}) {
  const sb = makeClient({ fromHandler });
  const loaded = loadBrowserModule(API, {
    storage: makeStorage(),
    extra: {
      supabase: { createClient: sb.createClient },
      navigator: { onLine: true, userAgent: 'node-test' },
    },
  });
  const rec = { kanca: spy() };
  loaded.window._detAciksaTazele = rec.kanca;
  const idbStub = makeIdbStub();
  loaded.sandbox.__idb = idbStub;
  vm.runInContext('_idb = __idb', loaded.sandbox);
  return { ...loaded, rec, calls: sb.calls, idb: idbStub };
}

// ── hook-01: başarılı pull → üçlü kontrat + detInternal=false ─────────

test('hook-01: başarılı pull — kanca bir kez, requested aynı dizi, ok tabloları taşır, failed boş, detInternal=false', async () => {
  const t = ['hayvanlar', 'gorev_log'];
  const { sandbox, rec, idb } = loadApi({
    fromHandler: () => fromChain({ data: [{ id: 'x1' }], error: null }),
  });
  await sandbox.pullTables(t);
  await settle();

  assert.strictEqual(rec.kanca.calls.length, 1, 'kanca tam 1 kez çağrılmalı');
  const [requested, ok, failed, detInternal] = rec.kanca.calls[0];
  assert.strictEqual(requested, t, 'requested, pullTables\'a verilen dizinin kendisi olmalı');
  assert.deepStrictEqual(Array.from(ok), ['hayvanlar', 'gorev_log'], 'ok, fetch+IDB yazımı başarılı tabloları taşır');
  assert.deepStrictEqual(Array.from(failed), [], 'başarılı run\'da failed boş');
  assert.strictEqual(detInternal, false, 'dış pull için 4. argüman boolean false');
  assert.strictEqual(idb.__snapshot('hayvanlar').length, 1, 'IDB yazımı gerçekleşti');
});

// ── hook-02: tek tablo fetcher hatası → run RESOLVE, failed taşınır ────

test('hook-02: bir tablonun fetcher\'ı hata verir — run RESOLVE olur, kanca failed içinde o tabloyu taşır', async () => {
  const t = ['hayvanlar', 'gorev_log'];
  const { sandbox, rec } = loadApi({
    fromHandler: (table) => table === 'hayvan_durum_view' // 'hayvanlar' fetcher'ının kaynağı
      ? fromChain({ data: null, error: { message: 'boom' } })
      : fromChain({ data: [{ id: 'g1' }], error: null }),
  });
  // reject ETMEMELİ — _pullTablesNow tablo hatasını yutar (hataSayisi yolu)
  const sonuc = await sandbox.pullTables(t);
  await settle();

  assert.ok(sonuc, 'run resolve oldu');
  assert.strictEqual(rec.kanca.calls.length, 1);
  const [requested, ok, failed, detInternal] = rec.kanca.calls[0];
  assert.deepStrictEqual(requested, ['hayvanlar', 'gorev_log']);
  assert.deepStrictEqual(Array.from(ok), ['gorev_log'], 'yalnız başarılı tablo ok\'ta');
  assert.deepStrictEqual(Array.from(failed), ['hayvanlar'], 'hatalı tablo failed\'da');
  assert.strictEqual(detInternal, false);
});

// ── hook-03: detInternal bayrağı dürüst taşınır ────────────────────────

test('hook-03: pullTables(t, {detInternal:true}) — kanca detInternal===true ile çağrılır', async () => {
  const t = ['hayvanlar'];
  const { sandbox, rec } = loadApi();
  await sandbox.pullTables(t, { detInternal: true });
  await settle();

  assert.strictEqual(rec.kanca.calls.length, 1);
  assert.strictEqual(rec.kanca.calls[0][3], true, 'api bayrağı dürüst taşır (bastırma ui.js tarafında)');
  assert.deepStrictEqual(Array.from(rec.kanca.calls[0][1]), ['hayvanlar']);
});

// ── hook-04: boş tablo listesi → kanca çağrılmaz ───────────────────────

test('hook-04: pullTables([]) — erken dönüşte kanca çağrılmaz', async () => {
  const { sandbox, rec } = loadApi();
  await sandbox.pullTables([]);
  await settle();

  assert.strictEqual(rec.kanca.calls.length, 0, 'tables.length===0\'da kanca DOĞMAMALI');
});

// ── hook-05: tek-argümanlı mevcut çağrı biçimi (geriye dönük uyum) ─────

test('hook-05: tek argümanlı mevcut çağrı — çalışır, kanca detInternal=false ile 4 argüman alır', async () => {
  const { sandbox, rec } = loadApi();
  await sandbox.pullTables(['protokol_ayar']);
  await settle();

  assert.strictEqual(rec.kanca.calls.length, 1);
  const [requested, ok, failed, detInternal] = rec.kanca.calls[0];
  assert.deepStrictEqual(requested, ['protokol_ayar']);
  assert.deepStrictEqual(Array.from(ok), ['protokol_ayar']);
  assert.deepStrictEqual(Array.from(failed), []);
  assert.strictEqual(detInternal, false, 'opts verilmediğinde false');
  assert.strictEqual(rec.kanca.calls[0].length, 4, 'kanca 4 argümanla çağrılır');
});

// ── hook-06 (FIX-R1 M-01): fetcher Promise REJECTION da failed setine düşer ──
// hook-02 yalnız {data:null,error:{message}} dönüş biçimini ölçüyordu; fetcher
// Promise'i düştüğünde Promise.all run'u düşürüyor, failed seti ve kanca oluşmuyordu.
// SPEC §3.1: tablo hatası run'u reject etmez — rejection da aynı kapıdan failed'a
// girer, run RESOLVE olur, kanca üçlüyü taşır ("fetcher rejection = tam red" ayrımı YOK).

test('hook-06 (M-01): fetcher Promise REJECT eder — run RESOLVE, kanca failed içinde o tabloyu taşır', async () => {
  const t = ['hayvanlar', 'gorev_log'];
  const { sandbox, rec } = loadApi({
    fromHandler: (table) => table === 'hayvan_durum_view' // 'hayvanlar' fetcher'ının kaynağı
      ? rejectingChain(new Error('kabul-koptu'))
      : fromChain({ data: [{ id: 'g1' }], error: null }),
  });
  const sonuc = await sandbox.pullTables(t).catch(e => ({ __reject: String((e && e.message) || e) }));
  await settle();

  assert.ok(!sonuc.__reject, `rejection run'u düşürmemeli — reject sebebi: ${sonuc.__reject}`);
  assert.deepStrictEqual(Array.from(sonuc.ok), ['gorev_log'], 'başarılı tablo ok\'ta');
  assert.deepStrictEqual(Array.from(sonuc.failed), ['hayvanlar'], 'REJECT eden tablo failed setinde (bastırma predicate\'ini bu besler)');
  assert.strictEqual(rec.kanca.calls.length, 1, 'kanca yine çağrıldı (run resolve — kancaya üçlü taşınır)');
  assert.deepStrictEqual(Array.from(rec.kanca.calls[0][2]), ['hayvanlar'], 'kanca failed üçlüsü rejection\'ı içerir');
});
