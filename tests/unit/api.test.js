// tests/unit/api.test.js
// js/api.js veri katmanı kontratları — Supabase'e HİÇ ağ çağrısı yapılmadan:
//   * createClient stub'u (extra.supabase) ile modül vm'de yüklenir,
//   * _idb, vm.runInContext ile sahte IndexedDB ile enjekte edilir
//     (openDB/onupgradeneeded mekanizması kapsam dışı — syncNow mantığı hedef).
// Kapsam: _trErr eşleme, rpc() throw kontratı + ok:false→err.data (B31),
// dbUpdate/dbInsert temizlik kuralları (B16/B17), _writePatch filtre guard'ı
// (B28), RPC_TABLES bütünlüğü, syncNow atla-devam/dead-letter (B17),
// rpcOptimistic çevrimdışı/başarı/hata yolları.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {
  loadBrowserModule,
  makeStorage,
} = require('./support/loadModule.js');

const API = 'js/api.js';
const REPO_ROOT = path.join(__dirname, '..', '..');

// ── Sahteler ──────────────────────────────────────────────────────────

function spy(fn = () => {}) {
  const f = (...a) => { f.calls.push(a); return fn(...a); };
  f.calls = [];
  return f;
}

// db.from(...) zincirleri için: read sorguları (select/eq/order/limit) boş
// chainable-thenable; insert/update davranışı fromHandler(table) ile table
// bazlı yönlendirilir. insert/onUpdate senkron throw ederse api.js'in catch
// bloklarına düşer (B17 senaryoları).
function defaultFromChain() {
  const chain = {
    select: () => chain, eq: () => chain, order: () => chain, limit: () => chain,
    insert: () => Promise.resolve({ error: null }),
    update: () => { throw new Error('test: update bu fromHandlerda tanımlı değil'); },
    then: (res, rej) => Promise.resolve({ data: [], error: null }).then(res, rej),
  };
  return chain;
}

function makeClient({ rpcHandlers = {}, fromHandler } = {}) {
  const calls = { createClient: [], rpc: [], from: [] };
  const client = {
    rpc: async (name, params) => {
      calls.rpc.push({ name, params });
      const h = rpcHandlers[name];
      if (!h) return { data: null, error: { message: `test stub: rpc "${name}" tanımlı değil` } };
      return await h(params);
    },
    from: (table) => {
      calls.from.push(table);
      return fromHandler ? fromHandler(table) : defaultFromChain();
    },
    channel: () => { throw new Error('test: db.channel bu testte kullanılmamalı'); },
  };
  const createClient = (url, key) => { calls.createClient.push({ url, key }); return client; };
  return { createClient, client, calls };
}

// Sahte IndexedDB — yalnız api.js'in kullandığı yüzey: transaction(store).objectStore
// .getAll/.put/.add/.delete/.clear + req.onsuccess/tx.oncomplete. Olaylar
// queueMicrotask ile ATANMADAN SONRA tetiklenir (api.js önce handler atayıp sonra
// await ediyor; senkron atış promise'leri asla çözmezdi).
function makeIdbStub(initial = {}) {
  const stores = new Map(); // store adı → Map(key → satır)
  for (const [n, rows] of Object.entries(initial)) {
    stores.set(n, new Map(rows.map(r => [n === '_queue' ? r._qid : r.id, r])));
  }
  let qid = initial._queue ? Math.max(0, ...initial._queue.map(r => r._qid || 0)) : 0;
  const store = (name) => { if (!stores.has(name)) stores.set(name, new Map()); return stores.get(name); };
  const keyOf = (name, row) => name === '_queue' ? row._qid : row.id;
  const mkOs = (name) => ({
    getAll() {
      const req = {};
      queueMicrotask(() => {
        req.result = [...store(name).values()];   // api.js req.result okur (event değil)
        req.onsuccess?.({ target: { result: req.result } });
      });
      return req;
    },
    put(row) { store(name).set(keyOf(name, row), row); return {}; },
    add(row) { if (name === '_queue' && row._qid == null) row._qid = ++qid; store(name).set(keyOf(name, row), row); return {}; },
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

// Mikrotask havuzunu tamamen boşalt (pullTables/_pullChain zincirleri için)
const settle = () => new Promise(r => setImmediate(r));

// ── api.js yükleme ────────────────────────────────────────────────────

function loadApi({ rpcHandlers, fromHandler, onLine = true, storage, idb } = {}) {
  const sb = makeClient({ rpcHandlers, fromHandler });
  const spies = {
    toast: spy(),
    getUserMessage: spy(e => e.message),
    renderFromLocal: spy(),
    updateSyncBar: spy(),
    hideSyncBar: spy(),
  };
  const loaded = loadBrowserModule(API, {
    storage: storage || makeStorage(),
    expose: ['RPC_TABLES', 'TABLES', 'IS_DEMO', '_syncFailCount'],
    extra: {
      supabase: { createClient: sb.createClient },
      navigator: { onLine, userAgent: 'node-test' },
      ...spies,
    },
  });
  // let _idb modül-lexical'te kalır — aynı vm context'inde atama yapılabilir
  const idbStub = idb || makeIdbStub();
  loaded.sandbox.__idb = idbStub;
  vm.runInContext('_idb = __idb', loaded.sandbox);
  return { ...loaded, client: sb.client, calls: sb.calls, spies, idb: idbStub };
}

// JWT payload'ını çöz (anon mi, service_role mi — B1 regresyon kilidi)
function jwtRole(key) {
  const payload = key.split('.')[1];
  return JSON.parse(Buffer.from(payload, 'base64url').toString('utf8')).role;
}

// ── Yükleme / config ──────────────────────────────────────────────────

test('api: prod yüklenmesi — createClient prod URL + anon key ile çağrılır, window.db set edilir', () => {
  const { window, client, calls } = loadApi();
  assert.strictEqual(calls.createClient.length, 1);
  assert.ok(calls.createClient[0].url.includes('zqnexqbdfvbhlxzelzju'), 'prod URL');
  assert.strictEqual(jwtRole(calls.createClient[0].key), 'anon'); // service_role sızıntı kilidi
  assert.strictEqual(window.db, client);
  assert.strictEqual(window.IS_DEMO, false);
});

test('api: demo modu — EGESUT_DEMO=1 ayrı demo projesine bağlanır, key yine anon', () => {
  const { window, calls } = loadApi({ storage: makeStorage({ EGESUT_DEMO: '1' }) });
  assert.ok(calls.createClient[0].url.includes('vtzqjmazsvurxdeondmi'), 'demo URL');
  assert.notStrictEqual(calls.createClient[0].url, loadApi().calls.createClient[0].url);
  assert.strictEqual(jwtRole(calls.createClient[0].key), 'anon');
  assert.strictEqual(window.IS_DEMO, true);
  assert.strictEqual(window.DEMO_LOGIN.email, 'demo@egesut.web');
});

// ── _trErr eşleme ─────────────────────────────────────────────────────

test('_trErr: bilinen İngilizce Postgres/ızgara hataları Türkçe karşılığına eşlenir', () => {
  const { sandbox } = loadApi();
  const cases = [
    ['row-level security policy', 'Yetkisiz işlem'],
    ['duplicate key value violates', 'Bu kayıt zaten mevcut'],
    ['foreign key violation', 'İlişkili kayıt bulunamadı'],
    ['not-null constraint', 'Zorunlu alan boş bırakıldı'],
    ['violates not-null', 'Zorunlu alan boş bırakıldı'],
    ['network error', 'Sunucuya ulaşılamıyor'],
    ['Failed to fetch', 'Sunucuya ulaşılamıyor'],
  ];
  for (const [inp, expected] of cases) assert.strictEqual(sandbox._trErr(inp), expected, inp);
});

test('_trErr: eşleme büyük/küçük harf duyarsız; bilinmeyen mesaj OLDUĞU GİBİ döner', () => {
  const { sandbox } = loadApi();
  assert.strictEqual(sandbox._trErr('DUPLICATE KEY VALUE'), 'Bu kayıt zaten mevcut');
  assert.strictEqual(sandbox._trErr('row-level security'.toUpperCase()), 'Yetkisiz işlem');
  assert.strictEqual(sandbox._trErr('bilinmeyen hata xyz'), 'bilinmeyen hata xyz');
  assert.strictEqual(sandbox._trErr(null), '');
  assert.strictEqual(sandbox._trErr(undefined), '');
});

// ── rpc() kontratı ────────────────────────────────────────────────────

test('rpc: başarılı çağrı → data aynen döner, parametreler iletilir', async () => {
  const { sandbox, calls } = loadApi({ rpcHandlers: { hayvan_ekle: async p => ({ data: { ok: true, id: 'h1' }, error: null }) } });
  const out = await sandbox.rpc('hayvan_ekle', { p_kupe: 'TR-1' });
  assert.deepStrictEqual(out, { ok: true, id: 'h1' });
  assert.deepStrictEqual(calls.rpc[0], { name: 'hayvan_ekle', params: { p_kupe: 'TR-1' } });
});

test('rpc: db error objesi → _trErr ile çevrilmiş mesajla throw', async () => {
  const { sandbox } = loadApi({ rpcHandlers: { x: async () => ({ data: null, error: { message: 'duplicate key value' } }) } });
  await assert.rejects(() => sandbox.rpc('x'), { message: 'Bu kayıt zaten mevcut' });
});

test('rpc: ok:false gövdesi → data.mesaj ile throw ve err.data orijinal gövdeyi taşır (B31)', async () => {
  const body = { ok: false, mesaj: 'Aynı gün için kayıt var', oneri: 'varsayılanı kabul et' };
  const { sandbox } = loadApi({ rpcHandlers: { y: async () => ({ data: body, error: null }) } });
  await assert.rejects(() => sandbox.rpc('y'), (e) => {
    // vm cross-realm: ana realm Error'ı instanceof olmaz — isim + mesaj ile doğrula
    assert.strictEqual(e.constructor.name, 'Error');
    assert.strictEqual(e.message, 'Aynı gün için kayıt var');
    assert.strictEqual(e.data, body); // identity — çağıran e.data.oneri okuyabilir
    return true;
  });
});

test('rpc: ok:false mesajsız gövde → genel "İşlem başarısız" mesajı', async () => {
  const { sandbox } = loadApi({ rpcHandlers: { y: async () => ({ data: { ok: false }, error: null }) } });
  await assert.rejects(() => sandbox.rpc('y'), { message: 'İşlem başarısız' });
});

test('rpc: iletim hatası (TypeError/AbortError) → "İnternet bağlantısı gerekli"', async () => {
  const mk = (thrower) => loadApi({ rpcHandlers: { n: thrower } });
  const net = mk(async () => { throw new TypeError('Failed to fetch'); });
  await assert.rejects(() => net.sandbox.rpc('n'), { message: 'İnternet bağlantısı gerekli' });
  const abort = mk(async () => { const e = new Error('aborted'); e.name = 'AbortError'; throw e; });
  await assert.rejects(() => abort.sandbox.rpc('n'), { message: 'İnternet bağlantısı gerekli' });
});

test('rpc: iletim DIŞI istisna yeniden adlandırılmaz — B23 (yanlış teşhis kilidi)', async () => {
  const { sandbox } = loadApi({ rpcHandlers: { n: async () => { throw new Error('auth session missing'); } } });
  await assert.rejects(() => sandbox.rpc('n'), { message: 'auth session missing' });
});

// ── dbUpdate / dbInsert temizlik kuralları ────────────────────────────

test('dbUpdate: null ve "" SUNUCUYA GİDER, undefined ve id filtrelenir (B16)', async () => {
  let sent;
  const { sandbox } = loadApi({
    fromHandler: () => ({
      update: (changes) => ({ eq: () => ({ select: () => { sent = changes; return Promise.resolve({ data: [{ id: 'h1' }], error: null }); } }) }),
    }),
  });
  await sandbox.dbUpdate('hayvanlar', 'h1', { not: null, bos: '', tanimsiz: undefined, id: 'h1', ad: 'x' });
  // vm cross-realm: Object.fromEntries vm realm'inde üretildi — prototype farkını
  // JSON round-trip ile eştirle
  assert.deepStrictEqual(JSON.parse(JSON.stringify(sent)), { not: null, bos: '', ad: 'x' });
});

test('dbUpdate: hedef satır sunucuda yoksa (0 satır) deadTarget hatası (B17)', async () => {
  const { sandbox } = loadApi({
    fromHandler: () => ({
      update: () => ({ eq: () => ({ select: () => Promise.resolve({ data: [], error: null }) }) }),
    }),
  });
  await assert.rejects(() => sandbox.dbUpdate('hayvanlar', 'yok', { ad: 'x' }), (e) => e.deadTarget === true);
});

test('dbInsert: eksik idye uuid atanır; null/""/undefined yalnız GÖNDERİLEN kopyadan silinir', async () => {
  let sent;
  const { sandbox } = loadApi({
    fromHandler: () => ({ insert: (rows) => { sent = rows; return Promise.resolve({ error: null }); } }),
  });
  const row = { id: undefined, kupe: 'TR-9', not: null, bos: '', adet: 3 };
  const out = await sandbox.dbInsert('hayvanlar', row);
  assert.match(out[0].id, /^[0-9a-f-]{36}$/);          // uuid — orijinal satıra yazıldı
  assert.strictEqual(sent[0].kupe, 'TR-9');
  assert.strictEqual(sent[0].adet, 3);
  assert.strictEqual('not' in sent[0], false);          // null düşer
  assert.strictEqual('bos' in sent[0], false);          // '' düşer
  assert.strictEqual('adet' in sent[0], true);          // 0 dışı falsy olmayan değer kalır
});

// ── _writePatch filtre guard'ı (B28) ──────────────────────────────────

test('_writePatch: id=eq. içermeyen filtre → parça-INSERT üretmeden net hata (B28)', async () => {
  const { sandbox } = loadApi();
  await assert.rejects(
    () => sandbox._writePatch('hayvanlar', 'kupe=eq.TR-1', [{ ad: 'x' }]),
    /PATCH için id=eq\. filtresi gerekli/,
  );
});

// ── RPC_TABLES bütünlüğü ──────────────────────────────────────────────

test('RPC_TABLES: her değer dolu dizi ve tüm tablolar TABLES içinde (yoksa pull sessiz no-op olurdu)', () => {
  const { exposed, sandbox } = loadApi();
  const { RPC_TABLES, TABLES } = exposed;
  const tableSet = new Set(TABLES);
  for (const [rpcName, tables] of Object.entries(RPC_TABLES)) {
    assert.ok(Array.isArray(tables) && tables.length > 0, `${rpcName} boş eşleme`);
    assert.match(rpcName, /^[a-z_][a-z0-9_]*$/, `${rpcName} geçerli tanımlayıcı`);
    for (const t of tables) {
      assert.ok(tableSet.has(t), `${rpcName} → "${t}" TABLES listesinde yok (FETCHERS filtresi sessizce düşürür)`);
    }
  }
  // kritik yazma RPC'leri kazayla silinmesin
  for (const k of ['hayvan_ekle', 'dogum_kaydet', 'tohumlama_kaydet', 'gorev_tamamla', 'geri_al', 'seans_tamamla', 'tedavi_sablon_uygula']) {
    assert.ok(RPC_TABLES[k], `${k} RPC_TABLES'te yok`);
  }
  assert.ok(typeof sandbox.rpc === 'function');
});

test('RPC_TABLES: js/ kaynaklarında rpcOptimistic("...") ile çağrılan HER RPC mapte (sessiz senkron boşluğu kilidi)', () => {
  const { exposed } = loadApi();
  const { RPC_TABLES } = exposed;
  // Bilinçli muafiyet: kategori üçlüsünün çağrı yerlerini loadTanimlarPanel() izler —
  // _renderKategoriler pullTables(['stok_kategorileri','stok']) ile telafi eder (js/ui.js).
  // seed_defaults artık muaf DEĞİL: RPC_TABLES'ta mapli (diseases/drugs/stok_kategorileri).
  const EXEMPT = new Set(['kategori_ekle', 'kategori_guncelle', 'kategori_sil']);
  const jsDir = path.join(REPO_ROOT, 'js');
  const files = fs.readdirSync(jsDir).filter(f => f.endsWith('.js'));
  const called = new Set();
  for (const f of files) {
    const src = fs.readFileSync(path.join(jsDir, f), 'utf8');
    // rpcOptimistic( sonrası ilk ~140 karakterde geçen TÜM 'ident' literallerini
    // topla — ternary (isNew?'a':'b') biçimini de yakalar
    for (const m of src.matchAll(/rpcOptimistic\((.{0,140}?),/gs)) {
      for (const lit of m[1].matchAll(/'([a-z_][a-z0-9_]*)'/g)) called.add(lit[1]);
    }
  }
  assert.ok(called.size >= 10, `tarama çok az RPC buldu (${called.size}) — regex bozulmuş olabilir`);
  const missing = [...called].filter(n => !RPC_TABLES[n] && !EXEMPT.has(n));
  assert.deepStrictEqual(missing, [], 'rpcOptimistic ile çağrılıp eşlemesi ve telafisi olmayan RPC: ' + missing.join(', '));
});

// ── syncNow: atla-devam + dead-letter (B17) ───────────────────────────

function qop(_qid, table, data, method = 'POST', filter = '') {
  return { _qid, table, method, data, filter };
}

test('syncNow: kuyruk drain — başarılı op kuyruktan düşer, doğru tabloyla insert edilir', async () => {
  const idb = makeIdbStub({ _queue: [qop(1, 'hayvanlar', [{ id: 'h1', ad: 'a' }]), qop(2, 'gorev_log', [{ id: 'g1' }])] });
  const inserted = [];
  const { sandbox, spies, calls } = loadApi({
    idb,
    fromHandler: (table) => ({ insert: (rows) => { inserted.push({ table, rows }); return Promise.resolve({ error: null }); } }),
  });
  await sandbox.syncNow();
  await settle();
  assert.deepStrictEqual(inserted.map(i => i.table), ['hayvanlar', 'gorev_log']);
  assert.deepStrictEqual(idb.__snapshot('_queue'), []);       // ikisi de gitti
  assert.strictEqual(spies.hideSyncBar.calls.length, 1);      // kuyruk boşaldı
  assert.strictEqual(spies.updateSyncBar.calls.length, 0);
  assert.strictEqual(calls.rpc.length, 0);
});

test('syncNow: zehirli op ATLA-DEVAM — sonraki op işlenir, zehirli kuyrukta kalır (B17)', async () => {
  const idb = makeIdbStub({ _queue: [qop(1, 'stok', [{ id: 's1' }]), qop(2, 'hayvanlar', [{ id: 'h1' }])] });
  const { sandbox, exposed, spies } = loadApi({
    idb,
    fromHandler: (table) => ({
      insert: () => table === 'stok'
        ? Promise.resolve({ error: { message: 'duplicate key' } })   // hep başarısız
        : Promise.resolve({ error: null }),
    }),
  });
  await sandbox.syncNow();
  await settle();
  const q = idb.__snapshot('_queue');
  assert.strictEqual(q.length, 1);
  assert.strictEqual(q[0]._qid, 1);                            // zehirli kaldı, sağlam gitti
  assert.strictEqual(exposed._syncFailCount[1], 1);
  assert.strictEqual(spies.updateSyncBar.calls.length, 1);     // remaining > 0
});

test('syncNow: aynı op 5 kez başarısız olduktan sonra denenMEZ (dead-letter), kuyrukta durur', async () => {
  const idb = makeIdbStub({ _queue: [qop(7, 'stok', [{ id: 's7' }])] });
  let attempts = 0;
  const { sandbox } = loadApi({
    idb,
    fromHandler: () => ({ insert: () => { attempts++; return Promise.resolve({ error: { message: 'server 500' } }); } }),
  });
  for (let i = 0; i < 5; i++) { await sandbox.syncNow(); await settle(); }
  assert.strictEqual(attempts, 5);
  assert.strictEqual(idb.__snapshot('_queue').length, 1);      // hâlâ kuyrukta (manuel gönder için)
  await sandbox.syncNow(); await settle(); await sandbox.syncNow(); await settle();
  assert.strictEqual(attempts, 5);                             // 6.+ turda artık denenmiyor
});

test('syncNow: deadTarget PATCH op yeniden denenmez — kuyruktan DÜŞÜRÜLÜR', async () => {
  const idb = makeIdbStub({ _queue: [qop(3, 'hayvanlar', [{ id: 'h3', ad: 'x' }], 'PATCH', 'id=eq.h3')] });
  const { sandbox, exposed } = loadApi({
    idb,
    fromHandler: () => ({
      update: () => ({ eq: () => ({ select: () => Promise.resolve({ data: [], error: null }) }) }), // 0 satır → deadTarget
    }),
  });
  await sandbox.syncNow();
  await settle();
  assert.deepStrictEqual(idb.__snapshot('_queue'), []);        // düşürüldü
  assert.strictEqual(exposed._syncFailCount[3], undefined);    // sayaç da temizlendi
});

test('syncNow: çevrimdışıysa hiç dokunmaz — kuyruk okunmaz, istek atılmaz', async () => {
  const idb = makeIdbStub({ _queue: [qop(1, 'stok', [{ id: 's1' }])] });
  const { sandbox, calls } = loadApi({ idb, onLine: false, fromHandler: () => { throw new Error('offline iken from çağrılmamalı'); } });
  await sandbox.syncNow();
  assert.strictEqual(calls.from.length, 0);
  assert.strictEqual(idb.__snapshot('_queue').length, 1);
});

// ── rpcOptimistic ─────────────────────────────────────────────────────

test('rpcOptimistic: çevrimdışı → toast(hata) + throw, RPC hiç denenmez', async () => {
  const { sandbox, spies, calls } = loadApi({ onLine: false });
  await assert.rejects(() => sandbox.rpcOptimistic('hayvan_ekle', {}), { message: 'İnternet bağlantısı gerekli' });
  assert.strictEqual(spies.toast.calls.length, 1);
  assert.strictEqual(spies.toast.calls[0][1], true);
  assert.strictEqual(calls.rpc.length, 0);
});

test('rpcOptimistic: başarı → successMsg toast + RPC_TABLES eşlemesinden tablolar çekilir', async () => {
  const { sandbox, spies, calls } = loadApi({
    rpcHandlers: { hayvan_ekle: async () => ({ data: { ok: true }, error: null }) },
  });
  const out = await sandbox.rpcOptimistic('hayvan_ekle', {}, { successMsg: 'Hayvan eklendi' });
  assert.deepStrictEqual(out, { ok: true });
  assert.strictEqual(spies.toast.calls[0][0], 'Hayvan eklendi'); // tek argüman — err bayrağı yok
  await settle();
  // hayvan_ekle → ['hayvanlar'] → FETCHERS.hayvanlar → db.from('hayvan_durum_view')
  assert.ok(calls.from.includes('hayvan_durum_view'), `from çağrıları: ${calls.from.join(',')}`);
});

test('rpcOptimistic: RPC hatası → onError verilmişse toast EDİLMEZ, hata callbacke gider ve rethrow', async () => {
  const { sandbox, spies } = loadApi({
    rpcHandlers: { asi_sil: async () => ({ data: null, error: { message: 'foreign key' } }) },
  });
  const onError = spy();
  await assert.rejects(
    () => sandbox.rpcOptimistic('asi_sil', {}, { onError }),
    { message: 'İlişkili kayıt bulunamadı' },
  );
  assert.strictEqual(onError.calls.length, 1);
  assert.strictEqual(spies.toast.calls.length, 0);             // onError varsa toast yok
});
