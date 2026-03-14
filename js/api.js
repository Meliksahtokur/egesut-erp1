// ══════════════════════════════════════════
// EgeSüt — api.js
// Tüm veri katmanı: Supabase SDK + IndexedDB
// ══════════════════════════════════════════

// ── CONFIG ─────────────────────────────────
const SB_URL  = 'https://zqnexqbdfvbhlxzelzju.supabase.co';
const SB_KEY  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxbmV4cWJkZnZiaGx4emVsemp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMDE4OTksImV4cCI6MjA4Nzg3Nzg5OX0.VggKv3KsmXm7C1LqBxCJaMj2yLQh10iRwSXMtuC4cmc';
const DB_VER  = 10;
const TABLES  = ['hayvanlar','tohumlama','dogum','stok','stok_hareket',
                  'gorev_log','buzagi_takip','kizginlik_log','bildirim_log','islem_log','cop_kutusu',
                  'cases','diseases','drugs'];
const APP_VERSION = '2026-03-12-cln03';

// ── SUPABASE SDK ────────────────────────────
const { createClient } = window.supabase;
const db = createClient(SB_URL, SB_KEY);

// ── RPC WRAPPER ─────────────────────────────
async function rpc(name, params = {}) {
  if (!navigator.onLine) throw new Error('İnternet bağlantısı gerekli');
  const { data, error } = await db.rpc(name, params);
  if (error) throw new Error("[" + name + "] " + error.message + " | kod: " + (error.code||"?"));
  if (data && data.ok === false) throw new Error(data.mesaj || 'İşlem başarısız');
  return data;
}

// ── INDEXEDDB ───────────────────────────────
let _idb;

async function clearAndReloadIDB() {
  return new Promise((res, rej) => {
    const req = indexedDB.deleteDatabase('egesut_v9');
    req.onsuccess = () => { console.log('IDB temizlendi, yeniden yükleniyor...'); location.reload(); };
    req.onerror = () => rej('IDB silinemedi');
  });
}

async function openDB() {
  return new Promise((res, rej) => {
    const req = indexedDB.open('egesut_v10', DB_VER);
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
  if (error) throw new Error("[" + name + "] " + error.message + " | kod: " + (error.code||"?"));
}

async function dbInsert(table, rows) {
  const arr = Array.isArray(rows) ? rows : [rows];
  arr.forEach(r => { if (!r.id) r.id = crypto.randomUUID(); });
  const clean = arr.map(r => Object.fromEntries(Object.entries(r).filter(([, v]) => v !== null && v !== undefined && v !== '')));
  const { error } = await db.from(table).insert(clean);
  if (error) throw new Error("[" + name + "] " + error.message + " | kod: " + (error.code||"?"));
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
  hayvan_ekle:               ['hayvanlar'],
  dogum_kaydet:              ['hayvanlar','dogum','gorev_log'],
  tohumlama_kaydet:          ['tohumlama','gorev_log'],
  kizginlik_kaydet:          ['kizginlik_log','gorev_log'],
  abort_kaydet:              ['tohumlama','gorev_log'],
  hayvan_not_ekle:           ['hayvanlar'],
  cikis_yap:                 ['hayvanlar'],
  geri_al:                   ['hayvanlar','tohumlama','dogum','gorev_log','islem_log'],
  create_case:               ['cases'],
  add_treatment_day:         ['cases'],
  add_drug_administration:   ['stok','stok_hareket'],
  remove_drug_administration:['stok','stok_hareket'],
  close_case:                ['cases'],
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
  console.log('📡 pullTables çağrıldı, tablolar:', tables);
  if (!tables.length || _pulling) {
    console.log('⏭️ pullTables atlandı:', !tables.length ? 'tablo yok' : 'zaten çalışıyor');
    return;
  }
  _pulling = true;
  try {
    console.log('🚀 pullTables başlıyor...');
    const FETCHERS = {
      hayvanlar:    () => {
        console.log('🔄 hayvanlar çekiliyor...');
        return db.from('hayvan_durum_view').select('*');
      },
      gorev_log:    () => db.from('gorev_log').select('*').eq('tamamlandi', false),
      stok:         () => db.from('stok').select('*'),
      stok_hareket: () => db.from('stok_hareket').select('*').eq('iptal', false),
      cases:        () => db.from('cases').select('*').order('created_at', { ascending: false }).limit(200),
      diseases:     () => db.from('diseases').select('*').order('category').order('name'),
      drugs:        () => db.from('drugs').select('*').order('name'),
      tohumlama:    () => db.from('tohumlama').select('*'),
      dogum:        () => db.from('dogum').select('*').order('tarih', { ascending: false }).limit(100),
      bildirim_log: () => db.from('bildirim_log').select('*').eq('durum', 'bekliyor'),
      islem_log:    () => db.from('islem_log').select('*').order('tarih', { ascending: false }).limit(100),
      kizginlik_log:() => db.from('kizginlik_log').select('*'),
      tohumlanabilir_hayvanlar: () => db.from('tohumlanabilir_hayvanlar').select('*'),
    };
    const uniq = [...new Set(tables)].filter(t => FETCHERS[t]);
    console.log('📥 Veriler çekiliyor...');
    const results = await Promise.all(uniq.map(t => FETCHERS[t]()));
    
    // Hata kontrolü
    results.forEach((r, i) => {
      if (r.error) {
        console.error(`❌ ${uniq[i]} çekilemedi:`, r.error);
        logError(`${uniq[i]} çekilemedi: ${r.error.message}`, 'pullTables');
      } else {
        console.log(`✅ ${uniq[i]}: ${r.data?.length || 0} kayıt`);
      }
    });
    
    console.log('💾 IndexedDB\'ye yazılıyor...');
    await Promise.all(uniq.map((t, i) => idbClearAndPut(t, results[i].data || [])));
    
    if (uniq.includes('tohumlanabilir_hayvanlar')) {
      window._TH = results[uniq.indexOf('tohumlanabilir_hayvanlar')].data || [];
      console.log(`✅ tohumlanabilir_hayvanlar: ${window._TH.length} kayıt`);
    }
    
    console.log('✅ pullTables tamamlandı');
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
    console.log('📡 Supabase\'den veri çekiliyor...');
    const tables = [
      'hayvanlar','gorev_log','stok','stok_hareket',
      'tohumlama','dogum','bildirim_log','islem_log',
      'cases','diseases','drugs',
    ];
    
    for (const table of tables) {
      console.log(`⏳ ${table} çekiliyor...`);
    }
    
    await pullTables(tables);
    
    console.log('✅ Veriler başarıyla çekildi');
    document.getElementById('dot')?.classList.remove('off', 'warn');
  } catch(e) {
    console.error('❌ pullFromSupabase hatası:', e);
    addError('pullFromSupabase: ' + e.message, 'api.js', null, e.stack);
    document.getElementById('dot')?.classList.add('off');
  }
}

async function getData(table, filterFn) {
  try {
    console.log(`🔍 getData: ${table} çağrılıyor...`);
    const data = await idbGetAll(table);
    console.log(`✅ getData: ${table} → ${data.length} kayıt bulundu`);
    return filterFn ? data.filter(filterFn) : data;
  } catch(e) {
    console.error(`❌ getData hatası (${table}):`, e);
    addError(`getData(${table}): ${e.message}`, 'api.js', null, e.stack);
    return [];
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
