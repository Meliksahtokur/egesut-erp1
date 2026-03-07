// ══════════════════════════════════════════
// EgeSüt — api.js
// Tüm veri katmanı: Supabase SDK + IndexedDB
// ══════════════════════════════════════════

// ── CONFIG ─────────────────────────────────
const SB_URL  = 'https://zqnexqbdfvbhlxzelzju.supabase.co';
const SB_KEY  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxbmV4cWJkZnZiaGx4emVsemp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMDE4OTksImV4cCI6MjA4Nzg3Nzg5OX0.VggKv3KsmXm7C1LqBxCJaMj2yLQh10iRwSXMtuC4cmc';
const DB_VER  = 6;
const TABLES  = ['hayvanlar','tohumlama','hastalik_log','dogum','stok','stok_hareket',
                  'gorev_log','buzagi_takip','kizginlik_log','bildirim_log','islem_log','cop_kutusu'];
const APP_VERSION = '2026-03-06-b2';

// ── SUPABASE SDK ────────────────────────────
const { createClient } = window.supabase;
const db = createClient(SB_URL, SB_KEY);

// ── RPC WRAPPER ─────────────────────────────
async function rpc(name, params = {}) {
  if (!navigator.onLine) throw new Error('İnternet bağlantısı gerekli');
  const { data, error } = await db.rpc(name, params);
  if (error) throw new Error(error.message);
  if (data && data.ok === false) throw new Error(data.mesaj || 'İşlem başarısız');
  return data;
}

// ── INDEXEDDB ───────────────────────────────
let _idb;

async function openDB() {
  return new Promise((res, rej) => {
    const req = indexedDB.open('egesut_v9', DB_VER);
    req.onupgradeneeded = e => {
      const d = e.target.result;
      TABLES.forEach(t => { if (!d.objectStoreNames.contains(t)) d.createObjectStore(t, { keyPath: 'id' }); });
      if (!d.objectStoreNames.contains('_queue')) d.createObjectStore('_queue', { keyPath: '_qid', autoIncrement: true });
    };
    req.onsuccess = e => { _idb = e.target.result; res(_idb); };
    req.onerror   = e => rej(e.target.error);
  });
}

async function idbGetAll(store) {
  return new Promise((res, rej) => {
    const tx = _idb.transaction(store, 'readonly');
    const req = tx.objectStore(store).getAll();
    req.onsuccess = () => res(req.result || []);
    req.onerror   = e => rej(e.target.error);
  });
}

async function idbPut(store, rows) {
  return new Promise((res, rej) => {
    const tx = _idb.transaction(store, 'readwrite');
    const os = tx.objectStore(store);
    rows.forEach(r => os.put(r));
    tx.oncomplete = () => res();
    tx.onerror    = e => rej(e.target.error);
  });
}

async function idbClearAndPut(store, rows) {
  return new Promise((res, rej) => {
    const tx = _idb.transaction(store, 'readwrite');
    const os = tx.objectStore(store);
    os.clear();
    (rows || []).forEach(r => os.put(r));
    tx.oncomplete = () => res();
    tx.onerror    = e => rej(e.target.error);
  });
}

async function idbDelete(store, id) {
  return new Promise((res, rej) => {
    const tx = _idb.transaction(store, 'readwrite');
    tx.objectStore(store).delete(id);
    tx.oncomplete = () => res();
    tx.onerror    = e => rej(e.target.error);
  });
}

// ── OFFLINE QUEUE ───────────────────────────
async function queueOp(op) {
  return new Promise((res, rej) => {
    const tx = _idb.transaction('_queue', 'readwrite');
    tx.objectStore('_queue').add(op);
    tx.oncomplete = () => res();
    tx.onerror    = e => rej(e.target.error);
  });
}

async function getQueue() {
  return new Promise((res, rej) => {
    const tx = _idb.transaction('_queue', 'readonly');
    const req = tx.objectStore('_queue').getAll();
    req.onsuccess = () => res(req.result || []);
    req.onerror   = e => rej(e.target.error);
  });
}

async function removeFromQueue(qid) {
  return new Promise((res, rej) => {
    const tx = _idb.transaction('_queue', 'readwrite');
    tx.objectStore('_queue').delete(qid);
    tx.oncomplete = () => res();
    tx.onerror    = e => rej(e.target.error);
  });
}

// ── SDK YARDIMCILARI ────────────────────────
async function dbUpdate(table, id, changes) {
  const clean = Object.fromEntries(Object.entries(changes).filter(([, v]) => v !== null && v !== undefined && v !== ''));
  const { error } = await db.from(table).update(clean).eq('id', id);
  if (error) throw new Error(error.message);
}

async function dbInsert(table, rows) {
  const arr = Array.isArray(rows) ? rows : [rows];
  arr.forEach(r => { if (!r.id) r.id = crypto.randomUUID(); });
  const clean = arr.map(r => Object.fromEntries(Object.entries(r).filter(([, v]) => v !== null && v !== undefined && v !== '')));
  const { error } = await db.from(table).insert(clean);
  if (error) throw new Error(error.message);
  return arr;
}

// ── OFFLINE-FIRST WRITE ─────────────────────
// Basit tablo işlemleri için (görev tamamla, stok hareketi vb.)
// Karmaşık işlemler → rpc() kullanır, bu fonksiyon değil
async function write(table, data, method = 'POST', filter = '') {
  const arr = Array.isArray(data) ? data : [data];

  if (method === 'PATCH') {
    const idMatch = filter.match(/id=eq\.([^&]+)/);
    const targetId = idMatch ? idMatch[1] : null;
    if (targetId) {
      const existing = await idbGetAll(table);
      const base = existing.find(r => r.id === targetId) || { id: targetId };
      const merged = { ...base, ...arr[0], id: targetId };
      await idbPut(table, [merged]);
      if (navigator.onLine) {
        try {
          await dbUpdate(table, targetId, arr[0]);
          const q = await getQueue();
          for (const op of q) { if (op.table === table && op.filter === filter) await removeFromQueue(op._qid); }
        } catch (e) {
          console.warn(`PATCH ${table}:`, e.message);
          await queueOp({ table, method: 'PATCH', data: [merged], filter });
          updateSyncBar();
        }
      } else {
        await queueOp({ table, method: 'PATCH', data: [merged], filter });
        updateSyncBar();
      }
      return [merged];
    }
  }

  arr.forEach(r => { if (!r.id) r.id = crypto.randomUUID(); });
  await idbPut(table, arr);
  if (navigator.onLine) {
    try {
      await dbInsert(table, arr);
      const q = await getQueue();
      for (const op of q) {
        if (op.table === table && op.data?.some(d => arr.find(a => a.id === d.id)))
          await removeFromQueue(op._qid);
      }
    } catch (e) {
      console.warn(`write ${table}:`, e.message);
      await queueOp({ table, method, data: arr, filter });
      updateSyncBar();
    }
  } else {
    await queueOp({ table, method, data: arr, filter });
    updateSyncBar();
  }
  return arr;
}

// ── RPC TABLOLARI MAP ───────────────────────
// Her RPC hangi tabloları etkiliyor — sadece onlar çekilir
const RPC_TABLES = {
  hayvan_ekle:       ['hayvanlar'],
  dogum_kaydet:      ['hayvanlar','dogum','gorev_log'],
  tohumlama_kaydet:  ['tohumlama','gorev_log'],
  kizginlik_kaydet:  ['kizginlik_log','gorev_log'],
  hastalik_kaydet:   ['hastalik_log','gorev_log','stok','stok_hareket'],
  abort_kaydet:      ['tohumlama','gorev_log'],
  hayvan_not_ekle:   ['hayvanlar'],
  cikis_yap:         ['hayvanlar'],
  geri_al:           ['hayvanlar','tohumlama','hastalik_log','dogum','gorev_log','islem_log'],
};

// ── RENDER DEBOUNCE ─────────────────────────
// Kısa sürede çok çağrı gelirse sadece 1 render yapar
let _renderTimer;
function renderSafe() {
  clearTimeout(_renderTimer);
  _renderTimer = setTimeout(() => renderFromLocal(), 60);
}

// ── PULL LOCK ───────────────────────────────
// Aynı anda iki pullTables çalışmasını önler
let _pulling = false;

// Sadece belirtilen tabloları Supabase'den çek
async function pullTables(tables = []) {
  if (!tables.length || _pulling) return;
  _pulling = true;
  try {
    const FETCHERS = {
      hayvanlar:    () => db.from('hayvan_durum_view').select('*'),
      gorev_log:    () => db.from('gorev_log').select('*').eq('tamamlandi', false),
      stok:         () => db.from('stok').select('*'),
      stok_hareket: () => db.from('stok_hareket').select('*').eq('iptal', false),
      hastalik_log: () => db.from('hastalik_log').select('*'),
      tohumlama:    () => db.from('tohumlama').select('*'),
      dogum:        () => db.from('dogum').select('*').order('tarih', { ascending: false }).limit(100),
      bildirim_log: () => db.from('bildirim_log').select('*').eq('durum', 'bekliyor'),
      islem_log:    () => db.from('islem_log').select('*').order('tarih', { ascending: false }).limit(100),
      kizginlik_log:() => db.from('kizginlik_log').select('*'),
    };
    const uniq = [...new Set(tables)].filter(t => FETCHERS[t]);
    const results = await Promise.all(uniq.map(t => FETCHERS[t]()));
    await Promise.all(uniq.map((t, i) => idbClearAndPut(t, results[i].data || [])));
  } finally {
    _pulling = false;
  }
}

// Optimistic RPC: toast önce → rpc gönder → arka planda pull + render
async function rpcOptimistic(name, params = {}, { onSuccess, onError, successMsg } = {}) {
  if (!navigator.onLine) {
    const msg = 'İnternet bağlantısı gerekli';
    toast(msg, true);
    throw new Error(msg);
  }
  // Kullanıcıya anında geri bildirim
  if (successMsg) toast(successMsg);
  try {
    const data = await rpc(name, params);
    // Arka planda sadece ilgili tabloları çek, UI'ı bloklamaz
    const tables = RPC_TABLES[name] || [];
    if (tables.length) pullTables(tables).then(renderSafe).catch(console.warn);
    if (onSuccess) onSuccess(data);
    return data;
  } catch (e) {
    if (onError) onError(e);
    else toast('❌ ' + e.message, true);
    throw e;
  }
}

// ── PULL FROM SUPABASE ──────────────────────
async function pullFromSupabase() {
  try {
    const [animals, tasks, stock, moves, diseases, tohs, births, bildirims, islemler] = await Promise.all([
      db.from('hayvan_durum_view').select('*'),
      db.from('gorev_log').select('*').eq('tamamlandi', false),
      db.from('stok').select('*'),
      db.from('stok_hareket').select('*').eq('iptal', false),
      db.from('hastalik_log').select('*'),
      db.from('tohumlama').select('*'),
      db.from('dogum').select('*').order('tarih', { ascending: false }).limit(100),
      db.from('bildirim_log').select('*').eq('durum', 'bekliyor'),
      db.from('islem_log').select('*').order('tarih', { ascending: false }).limit(100),
    ]);

    await Promise.all([
      idbClearAndPut('hayvanlar',    animals.data    || []),
      idbClearAndPut('gorev_log',    tasks.data      || []),
      idbClearAndPut('stok',         stock.data      || []),
      idbClearAndPut('stok_hareket', moves.data      || []),
      idbClearAndPut('hastalik_log', diseases.data   || []),
      idbClearAndPut('tohumlama',    tohs.data       || []),
      idbClearAndPut('dogum',        births.data     || []),
      idbClearAndPut('bildirim_log', bildirims.data  || []),
      idbClearAndPut('islem_log',    islemler.data   || []),
    ]);

    document.getElementById('dot')?.classList.remove('off', 'warn');
  } catch (e) {
    console.warn('pull failed:', e.message);
    document.getElementById('dot')?.classList.add('off');
  }
}

// ── AUTO SYNC ENGINE ────────────────────────
let _syncing = false;

async function syncNow() {
  if (_syncing || !navigator.onLine) return;
  _syncing = true;
  try {
    const q = await getQueue();
    for (const op of q) {
      try {
        if (op.method === 'PATCH') {
          const idMatch = (op.filter || '').match(/id=eq\.([^&]+)/);
          if (idMatch) await dbUpdate(op.table, idMatch[1], op.data[0]);
        } else {
          await dbInsert(op.table, op.data);
        }
        await removeFromQueue(op._qid);
      } catch (e) {
        console.warn('sync item failed:', e.message);
        break;
      }
    }
    const remaining = await getQueue();
    if (!remaining.length) hideSyncBar(); else updateSyncBar();
  } finally {
    _syncing = false;
  }
}

// ── AUTO SYNC ───────────────────────────────
// Her 5sn offline queue'yu otomatik gönderir
setInterval(syncNow, 5000);
window.addEventListener('online', syncNow);
async function getData(table, filterFn) {
  const data = await idbGetAll(table);
  return filterFn ? data.filter(filterFn) : data;
}
