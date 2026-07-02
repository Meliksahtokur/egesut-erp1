// ══════════════════════════════════════════
// EgeSüt — api.js
// Tüm veri katmanı: Supabase SDK + IndexedDB
// ══════════════════════════════════════════

// ── DEMO MODU ──────────────────────────────
// ?demo → localStorage kilit (reload'da kalır). ?prod → çıkış. Demo ayrı Supabase projesine bağlanır.
// Demo yazmaları geçici; demo_klonla() prod'dan üzerine yazar. service_role ASLA client'ta yok (demo de anon+RLS).
(function () {
  const p = new URLSearchParams(location.search);
  if (p.has('demo')) localStorage.setItem('EGESUT_DEMO', '1');
  if (p.has('prod')) localStorage.removeItem('EGESUT_DEMO');
})();
const IS_DEMO = localStorage.getItem('EGESUT_DEMO') === '1';
window.IS_DEMO = IS_DEMO;
// Gömülü demo kullanıcı (gizli değil — demo herkese açık, çöpe-atılır)
const DEMO_LOGIN = { email: 'demo@egesut.web', password: 'demo2026' };
window.DEMO_LOGIN = DEMO_LOGIN;

// ── CONFIG ─────────────────────────────────
const PROD_URL = 'https://zqnexqbdfvbhlxzelzju.supabase.co';
const DEMO_URL = 'https://vtzqjmazsvurxdeondmi.supabase.co';
const DEMO_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ0enFqbWF6c3Z1cnhkZW9uZG1pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NDc0OTcsImV4cCI6MjA5ODUyMzQ5N30.t9Bq7jZhV316SYt0HH5tih78dCckxHuUjdHUA9GeAs8';
const SB_URL  = IS_DEMO ? DEMO_URL : PROD_URL;
const PROD_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxbmV4cWJkZnZiaGx4emVsemp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMDE4OTksImV4cCI6MjA4Nzg3Nzg5OX0.VggKv3KsmXm7C1LqBxCJaMj2yLQh10iRwSXMtuC4cmc';
const SB_KEY  = IS_DEMO ? DEMO_KEY : PROD_KEY;
const DB_VER  = 23;
const TABLES  = ['hayvanlar','tohumlama','dogum','stok','stok_hareket',
                  'gorev_log','kizginlik_log','bildirim_log','islem_log','cop_kutusu','vaccines',
                  'cases','diseases','drugs','drug_classes','drug_products','drug_administrations',
                  'vaccination_log','vaccine_diseases','vaccine_protocol_steps','padoklar','grup_padok_eslem','hekimler','treatment_days','treatment_day_uygulamalar','stok_kategorileri',
                  'uygulama_log','protokol_instance','protokol_ayar',
                  'tedavi_sablonu','sablon_hastalik_eslem','tedavi_sablonu_kalem'];
const APP_VERSION = '2026-03-12-cln03';

// ── SUPABASE SDK ────────────────────────────
const { createClient } = window.supabase;
const db = createClient(SB_URL, SB_KEY);
window.db = db;

// ── HATA MAP ────────────────────────────────
const _ERR_MAP = [
  ['row-level security',  'Yetkisiz işlem'],
  ['duplicate key',       'Bu kayıt zaten mevcut'],
  ['foreign key',         'İlişkili kayıt bulunamadı'],
  ['not-null',            'Zorunlu alan boş bırakıldı'],
  ['not null',            'Zorunlu alan boş bırakıldı'],
  ['network',             'Sunucuya ulaşılamıyor'],
  ['Failed to fetch',     'Sunucuya ulaşılamıyor'],
];
function _trErr(msg) {
  const m = String(msg || '');
  const found = _ERR_MAP.find(([k]) => m.toLowerCase().includes(k.toLowerCase()));
  return found ? found[1] : m;
}

// ── RPC WRAPPER ─────────────────────────────
/**
 * Supabase RPC çağrısı
 * @param {string} name - RPC fonksiyon adı
 * @param {object} [params] - Parametreler
 * @returns {Promise<any>} RPC sonucu
 */
async function rpc(name, params = {}) {
  if (!navigator.onLine) throw new Error('İnternet bağlantısı gerekli');
  const { data, error } = await db.rpc(name, params);
  if (error) throw new Error(_trErr(error.message));
  if (data && data.ok === false) throw new Error(data.mesaj || 'İşlem başarısız');
  return data;
}

// ── INDEXEDDB ───────────────────────────────
let _idb;

async function clearAndReloadIDB() {
  return new Promise((res, rej) => {
    const req = indexedDB.deleteDatabase('egesut_v9');
    req.onsuccess = () => { location.reload(); };
    req.onerror = () => rej('IDB silinemedi');
  });
}

async function openDB() {
  return new Promise((res, rej) => {
    const req = indexedDB.open('egesut_v12', DB_VER);
    req.onupgradeneeded = e => {
      const d = e.target.result;
      TABLES.forEach(t => { if (!d.objectStoreNames.contains(t)) d.createObjectStore(t, { keyPath: t === 'protokol_ayar' ? 'anahtar' : 'id' }); });
      if (!d.objectStoreNames.contains('_queue')) d.createObjectStore('_queue', { keyPath: '_qid', autoIncrement: true });
      // Index'ler: gorev_log, tohumlama, dogum
      ['gorev_log','tohumlama','dogum'].forEach(t => {
        if (d.objectStoreNames.contains(t)) {
          const st = req.transaction.objectStore(t);
          if (!st.indexNames.contains('hayvan_id_idx')) st.createIndex('hayvan_id_idx', 'hayvan_id', { unique: false });
        }
      });
      if (d.objectStoreNames.contains('gorev_log')) {
        const st = req.transaction.objectStore('gorev_log');
        if (!st.indexNames.contains('tamamlandi_idx')) st.createIndex('tamamlandi_idx', 'tamamlandi', { unique: false });
      }
    };
    req.onsuccess = e => { _idb = e.target.result; _dbReady = true; res(_idb); };
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
  const clean = Object.fromEntries(Object.entries(changes).filter(([k, v]) => k !== 'id' && v !== null && v !== undefined && v !== ''));
  const { error } = await db.from(table).update(clean).eq('id', id);
  if (error) throw new Error(_trErr(error.message));
}

async function dbInsert(table, rows) {
  const arr = Array.isArray(rows) ? rows : [rows];
  arr.forEach(r => { if (!r.id) r.id = crypto.randomUUID(); });
  const clean = arr.map(r => Object.fromEntries(Object.entries(r).filter(([, v]) => v !== null && v !== undefined && v !== '')));
  const { error } = await db.from(table).insert(clean);
  if (error) throw new Error(_trErr(error.message));
  return arr;
}

// ── OFFLINE-FIRST WRITE ─────────────────────
// Basit tablo işlemleri için (görev tamamla, stok hareketi vb.)
// Karmaşık işlemler → rpc() kullanır, bu fonksiyon değil
async function _writePatch(table, filter, arr) {
  const idMatch = filter.match(/id=eq\.([^&]+)/);
  const targetId = idMatch ? idMatch[1] : null;
  if (!targetId) return null;
  const existing = await idbGetAll(table);
  const base = existing.find(r => r.id === targetId) || { id: targetId };
  const merged = { ...base, ...arr[0], id: targetId };
  await idbPut(table, [merged]);
  if (navigator.onLine) {
    try {
      await dbUpdate(table, targetId, arr[0]);
      const q = await getQueue();
      for (const op of q) {
        if (op.table === table && op.filter === filter) await removeFromQueue(op._qid);
      }
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

async function _writePost(table, arr, method, filter) {
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

async function write(table, data, method = 'POST', filter = '') {
  const arr = Array.isArray(data) ? data : [data];
  if (method === 'PATCH') {
    const result = await _writePatch(table, filter, arr);
    if (result) return result;
  }
  return _writePost(table, arr, method, filter);
}


// ── RPC TABLOLARI MAP ───────────────────────
// Her RPC hangi tabloları etkiliyor — sadece onlar çekilir
const RPC_TABLES = {
  hayvan_ekle:               ['hayvanlar'],
  dogum_kaydet:              ['hayvanlar','dogum','gorev_log','tohumlama'],
  tohumlama_kaydet:          ['tohumlama','gorev_log','stok','stok_hareket','hayvanlar'],
  tohumlama_tekrar_kaydet:   ['tohumlama','gorev_log','stok_hareket'],
  tohumlama_sonuc_gebe:      ['hayvanlar','tohumlama','islem_log'],
  tohumlama_sonuc_bos:       ['hayvanlar','tohumlama','islem_log'],
  tohumlama_sonuc_bekliyor:  ['hayvanlar','tohumlama','islem_log'],
  tohumlama_abort:           ['hayvanlar','tohumlama','islem_log'],
  kizginlik_kaydet:          ['kizginlik_log','gorev_log'],
  kizginlik_sil:             ['kizginlik_log'],
  kizginlik_tedavi_baglanti_kur:['kizginlik_log'],
  abort_kaydet:              ['tohumlama','gorev_log'],
  hayvan_not_ekle:           ['hayvanlar'],
  cikis_yap:                 ['hayvanlar'],
  geri_al:                   ['hayvanlar','tohumlama','dogum','gorev_log','islem_log','cases','treatment_days'],
  create_case:               ['cases'],
  add_treatment_day:         ['cases','treatment_days'],
  add_drug_administration:   ['stok','stok_hareket','drug_administrations'],
  remove_drug_administration:['stok','stok_hareket','drug_administrations'],
  close_case:                ['cases'],
  add_vaccination:           ['vaccination_log','gorev_log','stok_hareket','islem_log'],
  asi_ekle:                  ['vaccines','stok','vaccine_protocol_steps','vaccine_diseases','islem_log','stok_hareket'],
  asi_guncelle:              ['vaccines','vaccine_protocol_steps','vaccine_diseases','stok','islem_log'],
  asi_sil:                   ['vaccines','vaccine_protocol_steps','vaccine_diseases','stok','islem_log'],
  bulk_vaccination:          ['vaccination_log','gorev_log','stok_hareket','islem_log'],
  bulk_ilac:                  ['islem_log','stok','stok_hareket'],
  ileri_gebe_asi_tamamla:    ['vaccination_log','gorev_log','stok_hareket','islem_log'],
  delete_treatment_day:      ['cases','treatment_days','drug_administrations','stok','stok_hareket'],
  update_treatment_time:     ['treatment_days'],
  // Faz 1 — RPC bypass fix
  buzagi_sutten_kesme_onayla:  ['hayvanlar','gorev_log','protokol_instance'],
  buzagi_sutten_kesme_toplu:   ['hayvanlar','gorev_log','protokol_instance'],
  buzagi_sutten_kesme_geri_al: ['hayvanlar','gorev_log','protokol_instance'],
  protokol_ayar_guncelle:      ['protokol_ayar'],
  hayvan_tohumlanabilir_onayla:['hayvanlar'],
  gebelik_protokol_kontrol:   ['gorev_log'],
  besleme_tamam:              ['gorev_log'],
  hayvan_tohumlama_ertele:     ['hayvanlar'],
  gorev_tamamla:               ['gorev_log', 'stok_hareket', 'hayvanlar', 'uygulama_log'],
  hizli_uygulama:              ['uygulama_log', 'stok_hareket'],
  gorev_guncelle:              ['gorev_log'],
  stok_hareket_ekle:           ['stok_hareket'],
  stok_ekle:                   ['stok'],
  ilac_ekle:                   ['stok','drug_products','islem_log'],
  stok_ekleme:                 ['stok_hareket'],
  gebelik_kaydet_manual:       ['tohumlama', 'islem_log'],
  // Faz 3 — db.from() REST → RPC
  stok_guncelle:               ['stok'],
  stok_arsivle:                ['stok'],
  vaccine_rapel_guncelle:      ['vaccines'],
  hekim_ekle:                  ['hekimler'],
  hekim_guncelle:              ['hekimler'],
  padok_ekle:                  ['padoklar', 'grup_padok_eslem'],
  padok_guncelle:              ['padoklar'],
  padok_sil:                   ['padoklar', 'grup_padok_eslem'],
  grup_padok_eslem_toggle:     ['grup_padok_eslem'],
  tohumlama_geri_al: ['tohumlama','gorev_log','kizginlik_log','stok_hareket'],
  case_geri_al:      ['cases','treatment_days','drug_administrations','stok_hareket','kizginlik_log'],
  drug_class_ekle:               ['drug_classes'],
  drug_class_guncelle:           ['drug_classes'],
  drug_class_sil:                ['drug_classes'],
  drug_class_varsayilan_yukle:   ['drug_classes'],
  disease_ekle:                  ['diseases'],
  disease_guncelle:              ['diseases'],
  disease_sil:                   ['diseases'],
  // BUG-059 — saat bazlı tedavi seans sistemi (Faz 5 RPC'leri)
  add_treatment_day_with_sessions: ['cases','treatment_days','treatment_day_uygulamalar','stok','stok_hareket','gorev_log'],
  seans_tamamla:                 ['treatment_day_uygulamalar','stok','stok_hareket','gorev_log','treatment_days'],
  recete_guncelle:               ['treatment_days','treatment_day_uygulamalar','stok','stok_hareket'],
  close_case_with_remaining:     ['cases','treatment_day_uygulamalar','stok','stok_hareket','treatment_days'],
  // #63 — şablon tedavi planlama
  tedavi_sablon_kaydet:  ['tedavi_sablonu','sablon_hastalik_eslem','tedavi_sablonu_kalem'],
  tedavi_sablon_sil:     ['tedavi_sablonu','sablon_hastalik_eslem','tedavi_sablonu_kalem'],
  tedavi_sablon_uygula:  ['cases','treatment_days','treatment_day_uygulamalar','drug_administrations','stok','stok_hareket','gorev_log','islem_log'],
};

// ── RENDER DEBOUNCE ─────────────────────────
// Kısa sürede çok çağrı gelirse sadece 1 render yapar
let _renderTimer;
function renderSafe() {
  clearTimeout(_renderTimer);
  _renderTimer = setTimeout(() => renderFromLocal(), 60);
}

// ── PULL LOCK ───────────────────────────────
// Devam eden pull varsa yeni çağrılar onu bekler, drop edilmez
let _pullingPromise = null;

// Sadece belirtilen tabloları Supabase'den çek
async function pullTables(tables = []) {
  _suruStatCache={};
  if (!tables.length) return;
  if (_pullingPromise) await _pullingPromise;
  let resolve;
  _pullingPromise = new Promise(r => { resolve = r; });
  try {
    const FETCHERS = {
      hayvanlar:    () => db.from('hayvan_durum_view').select('*'),
      gorev_log:    () => db.from('v_gorev_log_sync').select('*'),
      stok:         () => db.from('stok_tuketim_view').select('*'),
      stok_hareket: () => db.from('stok_hareket').select('*'),
      cases:        () => db.from('cases').select('*').order('created_at', { ascending: false }).limit(200),
      diseases:     () => db.from('diseases').select('*').order('category').order('name'),
      drugs:        () => db.from('drugs').select('*').order('name'),
      drug_classes: () => db.from('drug_classes').select('*').order('group_name'),
      drug_products:() => db.from('drug_products').select('*').order('brand_name'),
      drug_administrations: () => db.from('drug_administrations').select('*'),
      treatment_days: () => db.from('treatment_days').select('*'),
      treatment_day_uygulamalar: () => db.from('treatment_day_uygulamalar').select('*'),
      tohumlama:    () => db.from('tohumlama').select('*'),
      vaccines:     () => db.from('vaccines').select('*'),
      vaccine_diseases: () => db.from('vaccine_diseases').select('*'),
      vaccine_protocol_steps: () => db.from('vaccine_protocol_steps').select('*'),
      vaccination_log: () => db.from('vaccination_log').select('*'),
      dogum:        () => db.from('dogum').select('*').order('tarih', { ascending: false }).limit(100),
      bildirim_log: () => db.from('bildirim_log').select('*').eq('durum', 'bekliyor'),
      islem_log:    () => db.from('islem_log').select('*').order('tarih', { ascending: false }).limit(100),
      uygulama_log: () => db.from('uygulama_log').select('*').order('created_at', { ascending: false }).limit(500),
      kizginlik_log:() => db.from('kizginlik_log').select('*'),
      tohumlanabilir_hayvanlar: () => db.from('tohumlanabilir_hayvanlar').select('*'),
      padoklar:         () => db.from('padoklar').select('*').eq('aktif', true).order('sira'),
      grup_padok_eslem: () => db.from('grup_padok_eslem').select('*'),
      hekimler:         () => db.from('hekimler').select('*').eq('aktif', true),
      gebelik_ozet:     () => db.from('gebelik_ozet_view').select('*'),
      stok_kategorileri:() => db.from('stok_kategorileri').select('*').order('sira'),
      tedavi_sablonu:        () => db.from('tedavi_sablonu').select('*').order('ad'),
      sablon_hastalik_eslem: () => db.from('sablon_hastalik_eslem').select('*'),
      tedavi_sablonu_kalem:  () => db.from('tedavi_sablonu_kalem').select('*'),
      protokol_ayar:    () => db.from('protokol_ayar').select('*'),
      // ileri_gebe_view: () => db.from('ileri_gebe_view').select('*'), — dashboard RPC sonucu kullanıyor
    };
    const uniq = [...new Set(tables)].filter(t => FETCHERS[t]);
    const results = await Promise.all(uniq.map(t => FETCHERS[t]()));
    await Promise.all(uniq.map((t, i) => {
      if (results[i].error) {
        console.warn(`⚠️ pullTables ${t}: ${results[i].error.message}`);
        return Promise.resolve();
      }
      return idbClearAndPut(t, results[i].data || []);
    }));
    if (uniq.includes('tohumlanabilir_hayvanlar')) globalThis._TH = results[uniq.indexOf('tohumlanabilir_hayvanlar')].data || [];
  } finally {
    _pullingPromise = null;
    resolve();
  }
}

// Optimistic RPC: toast önce → rpc gönder → arka planda pull + render
async function rpcOptimistic(name, params = {}, { onSuccess, onError, successMsg } = {}) {
  if (!navigator.onLine) {
    const msg = 'İnternet bağlantısı gerekli';
    toast(msg, true);
    throw new Error(msg);
  }
  try {
    const data = await rpc(name, params);
    // RPC başarılıysa toast göster
    if (successMsg) toast(successMsg);
    // Arka planda sadece ilgili tabloları çek, UI'ı bloklamaz
    const tables = RPC_TABLES[name] || [];
    // Opus #11 fix: seans_tamamla treatment_days tamamlandi=true yapar, mapping'e ekle
    if (tables.length) pullTables(tables).then(renderSafe).catch(console.warn);
    if (onSuccess) onSuccess(data);
    return data;
  } catch (e) {
    if (onError) onError(e);
    else toast('❌ ' + getUserMessage(e), true);
    throw e;
  }
}

// ── PULL FROM SUPABASE ──────────────────────
async function pullFromSupabase() {
  try {
    await pullTables(TABLES.filter(t => t !== '_queue'));
    document.getElementById('dot')?.classList.remove('off', 'warn');
  } catch(e) {
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
    if (remaining.length) updateSyncBar(); else hideSyncBar();
  } finally {
    _syncing = false;
  }
}

// ── AUTO SYNC ───────────────────────────────
// Online event'te syncNow tetiklenir (polling kaldırıldı — organik realtime geçişi)
window.addEventListener('online', syncNow);

// ── REALTIME SUBSCRIPTIONS (Organik geçiş — yeni özellikler kullanır) ─────
// Sprint 5 — Realtime kanalları:
// - hayvanlar: INSERT/UPDATE/DELETE → renderFromLocal()
// - gorev_log: INSERT → task badge güncelle
// - stok_hareket: INSERT → stok hesapla
//
// Geçici çözüm: Her 30sn'de bir arka plan sync (polling'den 6x daha yavaş)
// Hedef: Supabase Realtime WebSocket kanalları (sonraki sprint)
let _backgroundSyncInterval = null;

function startBackgroundSync(intervalMs = 30000) {
  if (_backgroundSyncInterval) clearInterval(_backgroundSyncInterval);
  _backgroundSyncInterval = setInterval(() => {
    if (navigator.onLine && !_syncing) {
      syncNow().catch(console.warn);
    }
  }, intervalMs);
  
}

function stopBackgroundSync() {
  if (_backgroundSyncInterval) {
    clearInterval(_backgroundSyncInterval);
    _backgroundSyncInterval = null;
    
  }
}

// ── REALTIME SUBSCRIPTIONS ──────────────────
// supabase_realtime publication aktif → WebSocket kanalları

const REALTIME_TABLES = ['hayvanlar','gorev_log','stok','stok_hareket','tohumlama','dogum','kizginlik_log','islem_log','ui_logs','treatment_days','treatment_day_uygulamalar','protokol_ayar'];
let _realtimeChannel = null;

function initRealtime() {
  if (_realtimeChannel) return; // zaten başlatıldı

  _realtimeChannel = db
    .channel('erp-changes')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'hayvanlar' },    () => pullTables(['hayvanlar']).then(renderSafe))
    .on('postgres_changes', { event: '*', schema: 'public', table: 'gorev_log' },    () => pullTables(['gorev_log']).then(renderSafe))
    .on('postgres_changes', { event: '*', schema: 'public', table: 'stok' },         () => pullTables(['stok','stok_hareket']).then(renderSafe))
    .on('postgres_changes', { event: '*', schema: 'public', table: 'stok_hareket' }, () => pullTables(['stok','stok_hareket']).then(renderSafe))
    .on('postgres_changes', { event: '*', schema: 'public', table: 'tohumlama' },    () => pullTables(['tohumlama']).then(renderSafe))
    .on('postgres_changes', { event: '*', schema: 'public', table: 'dogum' },        () => pullTables(['dogum']).then(renderSafe))
    .on('postgres_changes', { event: '*', schema: 'public', table: 'kizginlik_log' }, () => pullTables(['kizginlik_log']).then(renderSafe))
    .on('postgres_changes', { event: '*', schema: 'public', table: 'islem_log' },    () => pullTables(['islem_log']))
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'ui_logs' },  () => {})
    .on('postgres_changes', { event: '*', schema: 'public', table: 'protokol_ayar' }, () => pullTables(['protokol_ayar']))
    .subscribe(status => {
      if (status === 'SUBSCRIBED') {
        
        stopBackgroundSync(); // polling artık gereksiz
      } else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
        console.warn('⚠️ Realtime bağlantı hatası, polling devam ediyor');
        startBackgroundSync(30000); // fallback
      }
    });
}

async function getData(table, filterFn) {
  const data = await idbGetAll(table);
  return filterFn ? data.filter(filterFn) : data;
}

// ══════════════════════════════════════════
// BUG-059 — Saat Bazlı Tedavi Seans RPC Wrapper'ları
// ══════════════════════════════════════════

/**
 * add_treatment_day_with_sessions — çok seanslı tedavi günü ekle / mevcut günün seanslarını değiştir
 * existingDayId verilirse RPC update modunda çalışır: günün tüm drug_admins + seansları
 * silinir, p_sessions'tan yeniden kurulur (stok hareketleri iptal+yeniden).
 * @param {string} caseId - cases.id
 * @param {string} date - YYYY-MM-DD
 * @param {Array<{planned_time, stok_id, dose, unit, route}>} sessions
 * @param {string|null} existingDayId - treatment_days.id (replace modu)
 * @returns {Promise<{ok, day_id, day_no, seans_sayisi, mesaj?}>}
 */
async function rpcAddTreatmentDayWithSessions(caseId, date, sessions, existingDayId = null) {
  if (!caseId) throw new Error('caseId zorunlu');
  if (!date) throw new Error('date zorunlu');
  if (!Array.isArray(sessions)) throw new Error('sessions array olmalı');
  if (sessions.length > MAX_SEANS_PER_DAY) throw new Error(`Maksimum ${MAX_SEANS_PER_DAY} seans`);
  return rpc('add_treatment_day_with_sessions', {
    p_case_id: caseId,
    p_date: date,
    p_sessions: sessions,
    p_existing_day_id: existingDayId,
  });
}

/**
 * seans_tamamla — tek seansı tamamla veya iptal et
 * @param {string} seansAdminId - treatment_day_uygulamalar.id
 * @param {boolean} uygulanmadi - true=stok iade, false=uygulandı
 * @param {string|null} not - seans notu (opsiyonel)
 * @returns {Promise<{ok, seans_done, mesaj?}>}
 */
async function rpcSeansTamamla(seansAdminId, uygulanmadi = false, not = null) {
  if (!seansAdminId) throw new Error('seansAdminId zorunlu');
  return rpc('seans_tamamla', {
    p_seans_admin_id: seansAdminId,
    p_uygulanmadi: !!uygulanmadi,
    p_not: not,
  });
}

/**
 * recete_guncelle — reçetedeki tüm tedavi günlerini ve seanslarını değiştir (full replace)
 * @param {string} caseId - cases.id
 * @param {Array<{day_no, tarih, sessions: [...]}>} yeniPlan
 * @returns {Promise<{ok, gun_sayisi, seans_adet, mesaj?}>}
 */
async function rpcReceteGuncelle(caseId, yeniPlan) {
  if (!caseId) throw new Error('caseId zorunlu');
  if (!Array.isArray(yeniPlan)) throw new Error('yeniPlan array olmalı');
  return rpc('recete_guncelle', {
    p_case_id: caseId,
    p_yeni_plan: yeniPlan,
  });
}

/**
 * close_case_with_remaining — vakayı kapat, kalan seansları iptal et, stok iade
 * @param {string} caseId - cases.id
 * @param {string|null} not - kapatma notu (opsiyonel)
 * @returns {Promise<{ok, kalan_seans_sayisi, iade_edilen_adet, mesaj?}>}
 */
async function rpcCloseCaseWithRemaining(caseId, not = null) {
  if (!caseId) throw new Error('caseId zorunlu');
  return rpc('close_case_with_remaining', {
    p_case_id: caseId,
    p_not: not,
  });
}
