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
// Gömülü demo kullanıcı — PUBLIC-BY-DESIGN (kullanıcı kararı 2026-08-31): demo,
// izole klon bir Supabase projesine bağlanan herkese açık canlı-test/inceleme
// alanıdır. Prod tablolarına demo yolundan yazılamaz. B1 bulgusu bu kararla kapatıldı.
const DEMO_LOGIN = { email: 'demo@egesut.web', password: 'demo2026' };
window.DEMO_LOGIN = DEMO_LOGIN;

// ── CONFIG ─────────────────────────────────
const PROD_URL = 'https://zqnexqbdfvbhlxzelzju.supabase.co';
const DEMO_URL = 'https://vtzqjmazsvurxdeondmi.supabase.co';
const DEMO_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ0enFqbWF6c3Z1cnhkZW9uZG1pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NDc0OTcsImV4cCI6MjA5ODUyMzQ5N30.t9Bq7jZhV316SYt0HH5tih78dCckxHuUjdHUA9GeAs8';
const SB_URL  = IS_DEMO ? DEMO_URL : PROD_URL;
const PROD_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpxbmV4cWJkZnZiaGx4emVsemp1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzMDE4OTksImV4cCI6MjA4Nzg3Nzg5OX0.VggKv3KsmXm7C1LqBxCJaMj2yLQh10iRwSXMtuC4cmc';
const SB_KEY  = IS_DEMO ? DEMO_KEY : PROD_KEY;
const DB_VER  = 24;
const TABLES  = ['hayvanlar','tohumlama','dogum','stok','stok_hareket',
                  'gorev_log','kizginlik_log','bildirim_log','islem_log','cop_kutusu','vaccines',
                  'cases','diseases','drugs','drug_classes','drug_products','drug_administrations',
                  'vaccination_log','vaccine_diseases','vaccine_protocol_steps','vaccination_schedule','padoklar','grup_padok_eslem','hekimler','treatment_days','treatment_day_uygulamalar','stok_kategorileri',
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
/**
 * Mesajı alıp hata kodlarını içeren bir diziyle eşleştirir ve eşleşen bir hata kodu bulunursa onu, yoksa orijinal mesajı döndürür.
 * @param {string} msg - İşlenecek hata mesajı.
 * @returns {string} Eşleşen hata kodu veya orijinal mesaj.
 */
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
  // M-25 fix: navigator.onLine captive-portal/VPN'de yanlış değer dönebilir (MDN:
  // "unreliable"). Artık ön-kontrol yapmıyoruz — RPC'yi gerçekten deniyoruz, ancak
  // gerçek bir ağ hatası (fetch/TypeError, db.rpc'nin kendi error objesi değil) alırsak
  // offline kabul ediyoruz.
  let data, error;
  try {
    ({ data, error } = await db.rpc(name, params));
  } catch (networkErr) {
    // B23: yalnız gerçek iletim hataları "internet" olarak etiketlenir —
    // TypeError/auth yenileme gibi başka istisnalar yanlış teşhisle
    // "İnternet bağlantısı gerekli" diye yeniden adlandırılıyordu
    if (networkErr instanceof TypeError || networkErr?.name === 'AbortError' ||
        /failed to fetch|networkerror|load failed/i.test(networkErr?.message || '')) {
      throw new Error('İnternet bağlantısı gerekli');
    }
    throw networkErr;
  }
  if (error) {
    // H8 (§10h, v7): PostgREST deadlock (40P01) / lock_not_available (55P03) yanıtında
    // hata .code alanını taşır — _ERR_MAP yalnız mesaj METNİ eşlediğinden bu iki SQLSTATE
    // burada yakalanır. Tek nokta Türkçe bilgilendirme; tüm UI catch'leri e.message gösterir.
    // Otomatik retry YOK — kullanıcı kendi tekrarını bilerek dener.
    if (error.code === '40P01' || error.code === '55P03') {
      throw new Error('İşlem başka bir kayıtla çakıştı, tekrar deneyin');
    }
    throw new Error(_trErr(error.message));
  }
  // ok:false gövdesini (oneri, detay vb.) hataya taşır — çağıranlar e.data ile okur
  if (data && data.ok === false) {
    const err = new Error(data.mesaj || data.error || 'İşlem başarısız');   // T8: sunucu 'error' alanlı Türkçe mesaj kaybolmasın
    err.data = data;
    throw err;
  }
  return data;
}

// ── INDEXEDDB ───────────────────────────────
let _idb;

/**
 * 'egesut_v12' IndexedDB veritabanını siler ve sayfayı yeniler.
 * @returns {Promise} Veritabanı silinip sayfa yenilenmesi işleminin tamamlanmasını temsil eden Promise.
 */
async function clearAndReloadIDB() {
  // M-23 fix: eskiden 'egesut_v9' siliyordu ama openDB() 'egesut_v12' açıyordu —
  // v9 zaten hiç açılmadığı için deleteDatabase no-op'tu, fonksiyon aslında bir işe
  // yaramıyordu.
  return new Promise((res, rej) => {
    const req = indexedDB.deleteDatabase('egesut_v12');
    req.onsuccess = () => { location.reload(); };
    req.onerror = () => rej('IDB silinemedi');
  });
}

/**
 * 'egesut_v12' adlı IndexedDB veritabanını açar, gerekli tabloları oluşturur,
 * eksik index'leri ekler ve veritabanı güncellemesi sırasında bloklandıysa kullanıcıya bildirim gösterir.
 * @returns {Promise} Veritabanı bağlantısını döndüren Promise nesnesi.
 */
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
    // M-24 fix: eski versiyon başka sekmede açıkken upgrade bloklanıyordu, kullanıcıya
    // hiçbir bilgi verilmiyordu — sayfa askıda kalmış gibi görünüyordu.
    req.onblocked = () => { if (typeof toast === 'function') toast('Veritabanı güncellemesi bloklandı — diğer sekmeleri kapatıp tekrar deneyin', true); };
  });
}

/**
 * Verilen IndexedDB mağazasından (store) tüm kayıtları okuyup Promise olarak döndürür.
 * @param {string} store Okunacak kayıtların bulunduğu mağaza (store) adı.
 * @returns {Promise<Array>} Mağazadaki tüm kayıtlardan oluşan dizi veya hata.
 */
async function idbGetAll(store) {
  return new Promise((res, rej) => {
    const tx = _idb.transaction(store, 'readonly');
    const req = tx.objectStore(store).getAll();
    req.onsuccess = () => res(req.result || []);
    req.onerror   = e => rej(e.target.error);
  });
}

/**
 * Verilen store adında bir IndexedDB transaction oluşturur, belirtilen store'daki tüm satırları (rows) bu store'ya ekler veya günceller ve işlem tamamlandığında Promise'i çözer.
 * @param {string} store İşlem yapılacak IndexedDB store'ının adı.
 * @param {Array} rows Store'ya eklenecek veya güncellenecek nesne dizisi.
 * @returns {Promise} İşlem tamamlandığında çözülür, hata oluştuğunda reddedilir.
 */
async function idbPut(store, rows) {
  return new Promise((res, rej) => {
    const tx = _idb.transaction(store, 'readwrite');
    const os = tx.objectStore(store);
    rows.forEach(r => os.put(r));
    tx.oncomplete = () => res();
    tx.onerror    = e => rej(e.target.error);
  });
}

/**
 * Verilen store'daki tüm kayıtları siler ve ardından sağlanan yeni satırları ekler.
 * @param {string} store İşlem yapılacak IndexedDB store'ının adı.
 * @param {Array} rows Silinip eklenecek kayıtların dizi.
 * @returns {Promise} İşlemin tamamlanmasını bekleyen Promise.
 */
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

/**
 * Belirtilen IndexedDB deposundan verilen kimliği (ID) taşıyan kaydı siler.
 * @param {string} store Silinmesi istenen verinin bulunduğu depo (store) adı.
 * @param {any} id Silinecek kaydı tanımlayan benzersiz kimlik (ID).
 * @returns {Promise} İşlemin tamamlanıp tamamlanmadığını bildiren Promise nesnesi.
 */
async function idbDelete(store, id) {
  return new Promise((res, rej) => {
    const tx = _idb.transaction(store, 'readwrite');
    tx.objectStore(store).delete(id);
    tx.oncomplete = () => res();
    tx.onerror    = e => rej(e.target.error);
  });
}

// ── OFFLINE QUEUE ───────────────────────────
/**
 * Verilen işlemin (op) verisini '_queue' adlı IndexedDB işleminin '_queue' depolama alanına ekler.
 * İşlem tamamlandığında Promise'i çözer, hata oluşursa hata mesajını reddeder.
 * @param {Object} op Eklenmesi gereken işlemin (operation) nesnesi.
 * @returns {Promise} İşlemin tamamlanmasını veya başarısız olmasını temsil eden Promise.
 */
async function queueOp(op) {
  return new Promise((res, rej) => {
    const tx = _idb.transaction('_queue', 'readwrite');
    tx.objectStore('_queue').add(op);
    tx.oncomplete = () => res();
    tx.onerror    = e => rej(e.target.error);
  });
}

/**
 * '_queue' adlı IndexedDB saklama alanından tüm kayıtları okuyup döndürür.
 * @returns {Promise<Array>} Kayıtların bulunduğu dizi veya hata durumunda Promise.reject.
 */
async function getQueue() {
  return new Promise((res, rej) => {
    const tx = _idb.transaction('_queue', 'readonly');
    const req = tx.objectStore('_queue').getAll();
    req.onsuccess = () => res(req.result || []);
    req.onerror   = e => rej(e.target.error);
  });
}

/**
 * Belirtilen kimlikli öğeyi '_queue' veritabanından siler.
 * @param {string} qid Silinecek öğenin kimliği.
 * @returns {Promise} İşlemin tamamlanmasını bekleme için Promise döndürür.
 */
async function removeFromQueue(qid) {
  return new Promise((res, rej) => {
    const tx = _idb.transaction('_queue', 'readwrite');
    tx.objectStore('_queue').delete(qid);
    tx.oncomplete = () => res();
    tx.onerror    = e => rej(e.target.error);
  });
}

// ── SDK YARDIMCILARI ────────────────────────
/**
 * Verilen tablodaki belirtilen kaydı (id ile eşleşen satırı) günceller.
 * Güncelleme sırasında 'id' alanı hariç undefined olan tüm alanlar temizlenir (null gönderilerek).
 * Kayıt sunucuda bulunamazsa (silinmişse) özel bir hata fırlatır.
 * @param {string} table Güncellenecek tablonun adı.
 * @param {any} id Güncellenecek kaydın benzersiz kimlik değeri.
 * @param {Object} changes Güncellenecek alanların ve yeni değerlerinin içerdği nesne.
 * @returns {Promise<void>} Güncelleme başarılı olduğunda boş Promise döndürür.
 */
async function dbUpdate(table, id, changes) {
  // B16: null/'' SUNUCUYA GİDER — eskiden filtrelendikleri için hiçbir alan
  // sunucuda temizlenemiyordu (toggleSub geri-alında tamamlanma_tarihi hayaleti).
  // (dbInsert'teki filtre bilinçli olarak aynı bırakıldı: INSERT'te null atmak
  // DB default'larına bırakır; UPDATE'te null göndermek alan temizlemektir.)
  const clean = Object.fromEntries(Object.entries(changes).filter(([k, v]) => k !== 'id' && v !== undefined));
  const { data, error } = await db.from(table).update(clean).eq('id', id).select('id');
  if (error) throw new Error(_trErr(error.message));
  // B17: hedef satır sunucuda silinmişse update 0 satır etkiler, hata vermezdi —
  // değişiklik iz bırakmadan yutuluyordu. dead-target olarak işaretle
  if (!data || data.length === 0) {
    const e = new Error(`Hedef kayıt sunucuda yok (silinmiş olabilir): ${table}/${id}`);
    e.deadTarget = true;
    throw e;
  }
}

/**
 * Verilen tabloya satırları ekler; null, undefined veya boş olan alanları temizler ve eksik ID'ler için rastgele UUID oluşturur.
 * @param {string} table Eklemelerin yapılacağı tablo adı.
 * @param {Array|Object} rows Eklenmesi gereken satır verisi; tek bir nesne veya nesnelerden oluşan bir dizi.
 * @returns {Array} İşlem sonrası orijinal satır verilerini içeren dizi.
 */
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
/**
 * Verilen tablo ve filtre (id=eq. içermeli) ile eşleşen kaydı bulup günceller;
 * çevrimdışıysa işleği kuyruğa ekler, çevrimdışı değilse sunucuya gönderir ve kuyruğu temizler.
 * @param {string} table Güncellenecek tablonun adı.
 * @param {string} filter Tablodaki kaydı belirlemek için kullanılan filtre (id=eq. ile başlamalı).
 * @param {Array} arr Güncellenecek alanların ve değerlerin bulunduğu dizi.
 * @returns {Array} Güncellenen kayıt nesnesini içeren dizi.
 */
async function _writePatch(table, filter, arr) {
  const idMatch = filter.match(/id=eq\.([^&]+)/);
  // B28: id=eq. dışı filtreyle PATCH eskiden null dönüp _writePost'a düşüyordu —
  // parça satır INSERT'i üretiyordu. Artık net hata.
  if (!idMatch) throw new Error(`PATCH için id=eq. filtresi gerekli (tablo: ${table}, filtre: ${filter || 'yok'})`);
  const targetId = idMatch[1];
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

/**
 * Verilen tablo için kayıtları işler, eksik ID'leri oluşturur, veritabanına kaydeder ve çevrimdışı modda veya hata durumunda işlemleri kuyruğa ekler.
 * @param {Object} table İşlenecek tablo nesnesi.
 * @param {Array} arr İşlenecek kayıt dizisi.
 * @param {string} method Kullanılacak yöntem (örneğin 'insert' veya 'update').
 * @param {Object} filter Filtreleme kriterleri.
 * @returns {Array} İşlenen kayıt dizisi.
 */
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
  if (method === 'PATCH') return _writePatch(table, filter, arr);
  return _writePost(table, arr, method, filter);
}


// ── RPC TABLOLARI MAP ───────────────────────
// Her RPC hangi tabloları etkiliyor — sadece onlar çekilir
const RPC_TABLES = {
  hayvan_ekle:               ['hayvanlar'],
  // R3.2: dogum anne + dişi buzağı OVSYNC_BASLAT aciyor
  dogum_kaydet:              ['hayvanlar','dogum','gorev_log','tohumlama'],
  // P2: S-7 vaka kapanisi (cases + seanslar); review: islem_log yaziyordu
  tohumlama_kaydet:          ['tohumlama','gorev_log','stok','stok_hareket','hayvanlar','islem_log','cases','treatment_days','treatment_day_uygulamalar'],
  planli_tohumlama_kaydet:   ['tohumlama','gorev_log','stok','stok_hareket','hayvanlar','islem_log','cases','treatment_days','treatment_day_uygulamalar'],
  tohumlama_tekrar_kaydet:   ['tohumlama','gorev_log','stok_hareket'],
  tohumlama_sonuc_gebe:      ['hayvanlar','tohumlama','islem_log','gorev_log'],
  // R3.2: sonuc_bos artik OVSYNC_BASLAT gorevu de aciyor (acik disi)
  tohumlama_sonuc_bos:       ['hayvanlar','tohumlama','islem_log','gorev_log'],
  tohumlama_sonuc_bekliyor:  ['hayvanlar','tohumlama','islem_log'],
  // P4 (ovsync-takip): P2b sarmalı — Boş sonrası devam (PG/OVSYNC/TAKIP/GEBE modları):
  // tohumlama/hayvanlar yazması, görev açma-kapatma, stok+stok_hareket, islem_log,
  // PG modunda pg_application_event→tetikleyiciler. Pull seti tohumlama_kaydet ile aynı.
  tohumlama_bos_ve_devam:    ['tohumlama','gorev_log','stok','stok_hareket','hayvanlar','islem_log','cases','treatment_days','treatment_day_uygulamalar'],
  // R3.2: abort ILK-TOH-ABORT gorevu aciyor
  tohumlama_abort:           ['hayvanlar','tohumlama','islem_log','gorev_log'],
  kizginlik_kaydet:          ['kizginlik_log','gorev_log'],
  kizginlik_sil:             ['kizginlik_log'],
  kizginlik_tedavi_baglanti_kur:['kizginlik_log'],
  abort_kaydet:              ['tohumlama','gorev_log'],
  hayvan_not_ekle:           ['hayvanlar'],
  cikis_yap:                 ['hayvanlar'],
  geri_al:                   ['hayvanlar','tohumlama','dogum','gorev_log','islem_log','cases','treatment_days'],
  create_case:               ['cases'],
  // G-20260906-TOPLU-VAKA — toplu vaka; pull seti submitCase'in (forms.js:629)
  // birebir aynısı. NOT: offline-replay RPC_MAP'e (ui.js dataTrafficTekGonder)
  // EKLENMEZ — online-only RPC.
  vaka_toplu_ac:             ['cases','diseases','drugs','kizginlik_log','islem_log','treatment_days','treatment_day_uygulamalar','drug_administrations','stok','stok_hareket','gorev_log'],
  // P2 (Ovsync/PG): yeni RPC pull setleri
  start_first_service_protocol: ['cases','treatment_days','treatment_day_uygulamalar','drug_administrations','gorev_log','islem_log','stok','stok_hareket','diseases','drugs','tedavi_sablonu'],
  tohumlama_gorev_ertele:    ['gorev_log','islem_log'],
  // E1-UI (erteleme-genel): genel gorev erteleme — tohumlama_gorev_ertele deseni.
  // RPC_MAP'e (ui.js dataTrafficTekGonder, offline kuyruk replay) BILINCLI girmez:
  // erteleme online-only'dir (E6 kapisu) — vaka_toplu_ac gerekce kalibi.
  gorev_ertele:              ['gorev_log','islem_log'],
  // F1 (coklu-kaydirma): gorev listesinden coklu vaka kaydirma — vaka_kalan_gunleri_kaydir
  // pull setinin coklu hali. RPC_MAP'e (ui.js dataTrafficTekGonder) BILINCLI girmez:
  // online-only'dir — vaka_toplu_ac gerekce kalibi.
  vaka_kalan_gunleri_kaydir_coklu: ['gorev_log','treatment_days','treatment_day_uygulamalar','islem_log'],
  // E4-UI (erteleme-genel): protokol iptali — vaka + gorev/seans/gun kapanisi +
  // stok iadesi + instance kapanisi (+ yeniden-baslat yeni gorevi). RPC_MAP'e
  // BILINCLI girmez — online-only (E6 guard ovsyncIptal girişinde).
  protokol_iptal:            ['gorev_log','islem_log','cases','treatment_days','treatment_day_uygulamalar','drug_administrations','stok','stok_hareket','protokol_instance'],
  // pg_uyari_kontrol / ovsync_baslat_uyarilari salt-okuma: RPC_TABLES'te DEGIL
  // (invariant: her deger dolu dizi; pull istemeyen RPC haritaya girmez;
  //  gorev_ertele_kural_listele de salt-okuma — kural cache'i ui.js'te rpc() +
  //  setState ile yenilenir, ovsync_baslat_uyarilari deseni)
  // ovsync_takip_listele de salt-okuma (P4, ovsync-takip planı): HARİTA DIŞI —
  //  ovsyncTakipGetir kendi window.__ovsyncTakip cache'ini yönetir, pull istemez.
  ilk_tohumlama_zamanlayici: ['gorev_log','cases','treatment_days','treatment_day_uygulamalar','islem_log'],
  add_treatment_day:         ['cases','treatment_days'],
  add_drug_administration:   ['stok','stok_hareket','drug_administrations'],
  remove_drug_administration:['stok','stok_hareket','drug_administrations'],
  close_case:                ['cases'],
  add_vaccination:           ['vaccination_log','gorev_log','stok_hareket','islem_log'],
  asi_ekle:                  ['vaccines','stok','vaccine_protocol_steps','vaccine_diseases','islem_log','stok_hareket'],
  asi_guncelle:              ['vaccines','vaccine_protocol_steps','vaccine_diseases','stok','islem_log'],
  asi_sil:                   ['vaccines','vaccine_protocol_steps','vaccine_diseases','stok','islem_log'],
  bulk_vaccination:          ['vaccination_log','gorev_log','stok_hareket','islem_log'],
  // P2: S-4 toplu yol gorev acabilir (PG+48s); review: gorev_log eksikti
  bulk_ilac:                  ['islem_log','stok','stok_hareket','gorev_log'],
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
  hizli_uygulama:              ['uygulama_log', 'stok_hareket', 'gorev_log'],
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
  // seed_defaults(p_tip) canlı gövdeden (pg_get_functiondef, oid 109988): diseases/drugs/stok_kategorileri
  // yazar — drug_classes YAZMAZ (onu drug_class_varsayilan_yukle yazar, yukarıda mapli). Tip'e göre
  // koşullu çekilemediğinden üçü de listelenir; küçük tablolar, over-pull maliyeti ihmal edilebilir.
  seed_defaults:                 ['diseases','drugs','stok_kategorileri'],
  // BUG-059 — saat bazlı tedavi seans sistemi (Faz 5 RPC'leri)
  add_treatment_day_with_sessions: ['cases','treatment_days','treatment_day_uygulamalar','stok','stok_hareket','gorev_log'],
  seans_tamamla:                 ['treatment_day_uygulamalar','stok','stok_hareket','gorev_log','treatment_days'],
  recete_guncelle:               ['treatment_days','treatment_day_uygulamalar','stok','stok_hareket'],
  close_case_with_remaining:     ['cases','treatment_day_uygulamalar','stok','stok_hareket','treatment_days'],
  // #63 — şablon tedavi planlama
  tedavi_sablon_kaydet:  ['tedavi_sablonu','sablon_hastalik_eslem','tedavi_sablonu_kalem'],
  tedavi_sablon_sil:     ['tedavi_sablonu','sablon_hastalik_eslem','tedavi_sablonu_kalem'],
  tedavi_sablon_uygula:  ['cases','treatment_days','treatment_day_uygulamalar','drug_administrations','stok','stok_hareket','gorev_log','islem_log'],
  tedavi_sablon_tohumlama_gorev_ekle: ['gorev_log'],
  vaka_tohumlama_ekle:   ['gorev_log','islem_log'],
};

// ── RENDER DEBOUNCE ─────────────────────────
// Kısa sürede çok çağrı gelirse sadece 1 render yapar
let _renderTimer;
/**
 * Render timer'ını sıfırlar ve 60 milisaniye sonra renderFromLocal fonksiyonunu çalıştırarak render işlemini tetikler.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function renderSafe() {
  clearTimeout(_renderTimer);
  _renderTimer = setTimeout(() => renderFromLocal(), 60);
}

// ── PULL LOCK ───────────────────────────────
// B18: gerçek sıralı kuyruk — eskiden bekleyenler ilk pull çözülünce HEPsi
// aynı anda salınıyor, erken biten finally kilidi boşaltıp geç fetch'in bayat
// snapshot'ıyla yeniyi ezebiliyordu. Her çağrı zincirin sonuna eklenir.
let _pullChain = Promise.resolve();

// Sadece belirtilen tabloları Supabase'den çek
/**
 * Verilen tablo listesi için veri çekme zincirini başlatır ve sonucu döndürür.
 * @param {Array} tables Çekilecek tablo listesi.
 * @returns {Promise} Tablo verilerinin çekilmesi işlemi için Promise.
 */
function pullTables(tables = []) {
  _suruStatCache = {};
  if (!tables.length) return Promise.resolve();
  const run = _pullChain.then(() => _pullTablesNow(tables), () => _pullTablesNow(tables));
  _pullChain = run.catch(() => {});
  return run;
}

// TG1-W3 (luna F10): islem_log 100-satır cap'i "seçilen gün için tüm olaylar"
// vaadini kırıyordu (demo 4087 satır — son 100 dışındaki olaylar IDB'ye hiç
// ulaşmıyordu). REST tek istekte 1000 satırda cap'lenir (ölçüldü: limit=5000
// isteği 1000 döndü) → sayfalı tam çekim. Ölçüm (demo, 2026-09-14): 4087 satır
// · ~1.6 sn · 2.6 MB — arka plan pull'u için kabul edilebilir. Tarih-aralıklı
// çekim UYGUN DEĞİL: pull idbClearAndPut ile DEĞİŞTİRİR, aralıklı çekim diğer
// günlerin satırlarını silerdi. Defter/klasik davranış ve çevrimdışı kriter
// bozulmaz (skipPull akışı değişmedi; defter aynı hattın bütünüyle dolan
// verisini okur).
/**
 * 'islem_log' tablosundan en son 50.000 kaydı (her sayfa 1000 satır) alarak döner.
 * Veritabanı hatası oluşursa hata bilgisini, yoksa toplanan kayıtları döndürür.
 * @returns {Object} { data: Kayıtlar dizisi, error: Hata mesajı (varsa) } objesi.
 */
async function _fetchIslemLogTumu(){
  const SAYFA = 1000, MAX_SAYFA = 50; // güven sınırı: 50k satır
  let rows = [], off = 0;
  for (let s = 0; s < MAX_SAYFA; s++) {
    const { data, error } = await db.from('islem_log').select('*').order('tarih', { ascending: false }).range(off, off + SAYFA - 1);
    if (error) return rows.length ? { data: rows, error } : { data: null, error };
    if (!data || !data.length) break;
    rows = rows.concat(data);
    if (data.length < SAYFA) break;
    off += SAYFA;
  }
  return { data: rows, error: null };
}

/**
 * Verilen tablo isimlerinden oluşan dizideki her bir tablo için ilgili veritabanı sorgusunu (fetcher) çalıştırır,
 * sonuçları işler ve hata durumunda uyarı verir. Başarılı olan tablolardan gelen verileri işlenmiş hale getirir.
 * @param {Array} tables İşlenecek tablo isimlerinin listesi. Varsayılan olarak boş dizidir.
 * @returns {Promise<void>} İşlem tamamlandığında (başarılı veya hata) void döner.
 */
async function _pullTablesNow(tables = []) {
  try {
    const FETCHERS = {
      /**
       * 'hayvan_durum_view' tablosundan tüm kayıtları seçer.
       * @returns {Array} Seçilen tüm hayvan kayıtlarından oluşan dizi.
       */
      hayvanlar:    () => db.from('hayvan_durum_view').select('*'),
      /**
       * 'v_gorev_log_sync' tablosundan tüm sütunları seçerek veri döndürür.
       * @returns {Object} Seçilen tüm sütunlardan oluşan veri seti.
       */
      gorev_log:    () => db.from('v_gorev_log_sync').select('*'),
      /**
       * 'stok_tuketim_view' tablosundan tüm sütunları seçerek stok tüketim verilerini döndürür.
       * @returns {Array} Seçilen stok tüketim kayıtlarından oluşan dizi.
       */
      stok:         () => db.from('stok_tuketim_view').select('*'),
      /**
       * 'stok_hareket' tablosundan tüm kayıtları seçer.
       * @returns {Object} Seçilen tüm kayıtlardan oluşan nesne.
       */
      stok_hareket: () => db.from('stok_hareket').select('*'),
      /**
       * 'cases' tablosundan en son oluşturulmuş 200 kaydı seçer ve sıralar.
       * @returns {Array} En yeni 200 'case' kaydı içeren dizi.
       */
      cases:        () => db.from('cases').select('*').order('created_at', { ascending: false }).limit(200),
      /**
       * 'diseases' tablosundan tüm kayıtları seçer, önce 'category' sonra 'name' sütunlarına göre sıralar.
       * @returns {Array} Sıralanmış hastalık kayıtlarından oluşan dizi.
       */
      diseases:     () => db.from('diseases').select('*').order('category').order('name'),
      /**
       * 'drugs' tablosundan tüm sütunları seçip 'name' sütununa göre sıralanmış ilaç listesini döndürür.
       * @returns {Array} İlaç kayıtlarından oluşan dizi.
       */
      drugs:        () => db.from('drugs').select('*').order('name'),
      /**
       * 'drug_classes' tablosundan tüm kayıtları seçip 'group_name' sütununa göre sıralanmış bir liste döndürür.
       * @returns {Array} group_name sütununa göre sıralanmış ilaç sınıfları kayıtlarından oluşan dizi.
       */
      drug_classes: () => db.from('drug_classes').select('*').order('group_name'),
      /**
       * 'drug_products' tablosundan tüm sütunları seçip 'brand_name' sütununa göre sıralanmış veriyi döndürür.
       * @returns {Object} Seçilen ve sıralanmış drug_products verisi.
       */
      drug_products:() => db.from('drug_products').select('*').order('brand_name'),
      /**
       * 'drug_administrations' tablosundan tüm kayıtları seçer.
       * @returns {Object} Seçilen tüm drug_administrations kayıtlarını içeren nesne.
       */
      drug_administrations: () => db.from('drug_administrations').select('*'),
      /**
       * 'treatment_days' tablosundan tüm kayıtları seçer.
       * @returns {Array} treatment_days tablosundaki tüm kayıtlardan oluşan dizi.
       */
      treatment_days: () => db.from('treatment_days').select('*'),
      /**
       * 'treatment_day_uygulamalar' tablosundan tüm kayıtları seçer.
       * @returns {Array} Seçilen tüm kayıtlardan oluşan dizi.
       */
      treatment_day_uygulamalar: () => db.from('treatment_day_uygulamalar').select('*'),
      /**
       * 'tohumlama' tablosundan tüm kayıtları seçer.
       * @returns {Object} Seçilen tüm kayıtlardan oluşan nesne.
       */
      tohumlama:    () => db.from('tohumlama').select('*'),
      /**
       * 'vaccines' tablosundan tüm sütunları seçerek kayıtları döndürür.
       * @returns {Array} Vaccine kayıtlarından oluşan dizi.
       */
      vaccines:     () => db.from('vaccines').select('*'),
      /**
       * vaccine_diseases tablosundan tüm kayıtları seçer ve döndürür.
       * @returns {Array} vaccine_diseases tablosundaki tüm kayıtlardan oluşan dizi.
       */
      vaccine_diseases: () => db.from('vaccine_diseases').select('*'),
      /**
       * 'vaccine_protocol_steps' tablosundan tüm kayıtları seçer ve döndürür.
       * @returns {Array} vaccine_protocol_steps tablosundaki tüm kayıtlardan oluşan dizi.
       */
      vaccine_protocol_steps: () => db.from('vaccine_protocol_steps').select('*'),
      /**
       * 'vaccination_schedule' tablosundan tüm kayıtları seçer ve döndürür.
       * @returns {Array} vaccination_schedule tablosundaki tüm kayıtlardan oluşan dizi.
       */
      vaccination_schedule: () => db.from('vaccination_schedule').select('*'),
      vaccination_log: () => db.from('vaccination_log').select('*'),
      /**
       * 'dogum' tablosundan en son 100 kaydı tarih sırasına göre (azalan) seçer.
       * @returns {Object} Seçilen 100 kaydı içeren nesne.
       */
      dogum:        () => db.from('dogum').select('*').order('tarih', { ascending: false }).limit(100),
      /**
       * 'bildirim_log' tablosundan durumu 'bekliyor' olan tüm kayıtları seçer.
       * @returns {Object} Seçilen kayıtlardan oluşan veritabanı sonucu.
       */
      bildirim_log: () => db.from('bildirim_log').select('*').eq('durum', 'bekliyor'),
      /**
       * Tüm işlem loglarını getirir.
       * @returns {Promise} İşlem loglarını içeren Promise nesnesi.
       */
      islem_log:    () => _fetchIslemLogTumu(),
      uygulama_log: () => db.from('uygulama_log').select('*').order('created_at', { ascending: false }).limit(500),
      /**
       * 'kizginlik_log' tablosundan tüm kayıtları seçer.
       * @returns {Object} Seçilen tüm kayıtlardan oluşan nesne.
       */
      kizginlik_log:() => db.from('kizginlik_log').select('*'),
      /**
       * 'padoklar' tablosundan aktif olan kayıtları sıralı olarak seçer.
       * @returns {Object} Seçilen aktif padok kayıtlarından oluşan nesne.
       */
      padoklar:         () => db.from('padoklar').select('*').eq('aktif', true).order('sira'),
      /**
       * 'grup_padok_eslem' tablosundan tüm kayıtları seçer.
       * @returns {Object} Seçilen tüm kayıtlardan oluşan nesne.
       */
      grup_padok_eslem: () => db.from('grup_padok_eslem').select('*'),
      /**
       * 'hekimler' tablosundan aktif olan hekimleri seçer.
       * @returns {Array} Aktif hekimlerin kayıtlarından oluşan dizi.
       */
      hekimler:         () => db.from('hekimler').select('*').eq('aktif', true),
      /**
       * Veritabanındaki 'stok_kategorileri' tablosundan tüm kayıtları seçip 'sira' sütununa göre sıralar.
       * @returns {Array} Sıralanmış stok kategori kayıtlarından oluşan dizi.
       */
      stok_kategorileri:() => db.from('stok_kategorileri').select('*').order('sira'),
      /**
       * 'tedavi_sablonu' tablosundan tüm kayıtları seçip 'ad' sütununa göre sıralanmış bir liste döndürür.
       * @returns {Object} Seçilen ve sıralanmış veri setini içeren obje.
       */
      tedavi_sablonu:        () => db.from('tedavi_sablonu').select('*').order('ad'),
      /**
       * 'sablon_hastalik_eslem' tablosundan tüm kayıtları seçer.
       * @returns {Object} Seçilen tüm kayıtlardan oluşan nesne.
       */
      sablon_hastalik_eslem: () => db.from('sablon_hastalik_eslem').select('*'),
      /**
       * 'tedavi_sablonu_kalem' tablosundan tüm kayıtları seçer.
       * @returns {Object} Seçilen tüm kayıtlardan oluşan nesne.
       */
      tedavi_sablonu_kalem:  () => db.from('tedavi_sablonu_kalem').select('*'),
      /**
       * 'protokol_ayar' tablosundan tüm kayıtları seçer.
       * @returns {Array} Seçilen tüm protokol ayar kayıtlarından oluşan dizi.
       */
      protokol_ayar:    () => db.from('protokol_ayar').select('*'),
      // B27: TABLES'ta olup fetcher'ı olmayanlar sessiz no-op'tu — eklendi
      /**
       * 'protokol_instance' tablosundan tüm kayıtları seçer.
       * @returns {Array} Seçilen tüm protokol_instance kayıtlarından oluşan dizi.
       */
      protokol_instance: () => db.from('protokol_instance').select('*'),
      /**
       * 'cop_kutusu' tablosundan tüm kayıtları seçer ve döndürür.
       * @returns {Object} Seçilen tüm kayıtlardan oluşan nesne.
       */
      cop_kutusu:        () => db.from('cop_kutusu').select('*'),
      // ileri_gebe_view: () => db.from('ileri_gebe_view').select('*'), — dashboard RPC sonucu kullanıyor
    };
    // B27: tohumlanabilir_hayvanlar/gebelik_ozet fetcher'ları kaldırıldı — IDB
    // store'ları yoktu (TABLES dışı), ilk pullTables çağrısında NotFoundError
    // patlatırlardı; çağıranları yok (m-insem doğrudan db.from kullanıyor)
    const uniq = [...new Set(tables)].filter(t => FETCHERS[t]);
    const results = await Promise.all(uniq.map(t => FETCHERS[t]()));
    let hataSayisi = 0;
    await Promise.all(uniq.map((t, i) => {
      if (results[i].error) {
        hataSayisi++;
        console.warn(`⚠️ pullTables ${t}: ${results[i].error.message}`);
        return Promise.resolve();
      }
      return idbClearAndPut(t, results[i].data || []);
    }));
    // B19: tablo bazlı pull hataları yutulup nokta yeşil kalıyordu — bayat
    // veri "senkron" görünüyordu. warn sınıfı mevcut dot stili.
    if (hataSayisi > 0) document.getElementById('dot')?.classList.add('warn');
  } finally {
    // zincir _pullChain'de yönetiliyor; burada kilitleyecek bir şey yok
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
/**
 * Verilen tablo listesinden '_queue' hariç olanları Supabase'den çekmeye çalışır.
 * Başarılı işlem durumunda 'dot' elementinden 'off' ve 'warn' sınıflarını kaldırır.
 * Hata durumunda 'dot' elementine 'off' sınıfını ekler ve hatayı konsola yazar.
 * @returns {Promise<void>} İşlemin tamamlanmasını bekleme.
 */
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
// B17: op başına ardışık hata sayacı — 5'ten sonra dead-letter (otomatik atla,
// Veri Trafik panelinden manuel 'Gönder' hâlâ mümkün)
const _syncFailCount = {};

/**
 * İnternet bağlantısı varsa ve senkronizasyon yapılmıyorsa, kuyruktaki işlemleri sırayla işler.
 * Sunucu ile senkronize edilecek verileri (INSERT veya PATCH) işler, başarısız olanları kuyruğa bırakır
 * ve hedef satırın silinmesi durumunda kuyruktan kaldırır. İşlem tamamlandığında senkronizasyon barını günceller.
 * @returns {Promise<void>} Senkronizasyon işleminin tamamlanmasını temsil eden Promise.
 */
async function syncNow() {
  if (_syncing || !navigator.onLine) return;
  _syncing = true;
  try {
    const q = await getQueue();
    for (const op of q) {
      if ((_syncFailCount[op._qid] || 0) >= 5) continue;
      try {
        if (op.method === 'PATCH') {
          const idMatch = (op.filter || '').match(/id=eq\.([^&]+)/);
          if (idMatch) await dbUpdate(op.table, idMatch[1], op.data[0]);
        } else {
          await dbInsert(op.table, op.data);
        }
        await removeFromQueue(op._qid);
        delete _syncFailCount[op._qid];
      } catch (e) {
        // B17: ilk kalıcı hata tüm drain'i kesiyordu — zehirli kayıttan sonraki
        // TÜM offline yazmalar sonsuza dek yerel kalıyordu. Atla-devam; hatalı
        // op kuyrukta kalır, sonraki sync'te tekrar denenir.
        console.warn('sync item failed:', e.message);
        _syncFailCount[op._qid] = (_syncFailCount[op._qid] || 0) + 1;
        if (e.deadTarget) {
          // Hedef satır sunucuda silinmiş — yeniden denemenin anlamı yok, düşür
          await removeFromQueue(op._qid).catch(console.warn);
          delete _syncFailCount[op._qid];
        }
      }
    }
    const remaining = await getQueue();
    if (remaining.length) updateSyncBar(); else hideSyncBar();
  } finally {
    _syncing = false;
  }
}

// ── AUTO SYNC ──────────────────────────────
// B37: bu dinleyici kaldırıldı — app.js'in online handler'ı zaten syncNow +
// pullFromSupabase yapıyor; çift dinleyici çift syncNow çağırıyordu (_syncing
// guard'ı no-op'a indirgediği içinsessizdi, ama bilgi kirliliğiydi).

// ── REALTIME SUBSCRIPTIONS (Organik geçiş — yeni özellikler kullanır) ─────
// Sprint 5 — Realtime kanalları:
// - hayvanlar: INSERT/UPDATE/DELETE → renderFromLocal()
// - gorev_log: INSERT → task badge güncelle
// - stok_hareket: INSERT → stok hesapla
//
// Geçici çözüm: Her 30sn'de bir arka plan sync (polling'den 6x daha yavaş)
// Hedef: Supabase Realtime WebSocket kanalları (sonraki sprint)
let _backgroundSyncInterval = null;

/**
 * Belirtilen aralıklarla arka plan senkronizasyonunu başlatır veya mevcut aralığı temizler.
 * @param {number} intervalMs Senkronizasyonun tekrarlanacağı milisaniye cinsinden aralık süresi. Varsayılan değer 30000'dir.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function startBackgroundSync(intervalMs = 30000) {
  if (_backgroundSyncInterval) clearInterval(_backgroundSyncInterval);
  _backgroundSyncInterval = setInterval(() => {
    if (navigator.onLine && !_syncing) {
      syncNow().catch(console.warn);
    }
  }, intervalMs);
  
}

/**
 * Arka plan senkronizasyonu aralığını durdurur ve ilgili zamanlayıcıyı temizler.
 */
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

/**
 * ERP tablosundaki değişiklikleri dinleyerek ilgili tabloları günceller ve kullanıcı arayüzünü (UI) gerçek zamanlı olarak yeniler.
 * Bağlantı durumu (SUBSCRIBED, CHANNEL_ERROR, TIMED_OUT) kontrol edilerek arka plan senkronizasyonu (polling) başlatılır veya durdurulur.
 * @returns {void} Fonksiyon herhangi bir değer döndürmez.
 */
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
      // B35: online handler'ın polling restart'ı realtime durumunu bilsin
      globalThis._realtimeSubscribed = (status === 'SUBSCRIBED');
      if (status === 'SUBSCRIBED') {

        stopBackgroundSync(); // polling artık gereksiz
      } else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
        console.warn('⚠️ Realtime bağlantı hatası, polling devam ediyor');
        startBackgroundSync(30000); // fallback
      }
    });
}

/**
 * Verilen tablodan tüm kayıtları getirir ve opsiyonel bir filtre fonksiyonu varsa onları uygular.
 * @param {string} table İndenilecek tablonun adı.
 * @param {Function} filterFn Kayıtları filtrelemek için kullanılan fonksiyon.
 * @returns {Array} Filtrelenmiş veya orijinal tablo verisi.
 */
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
async function rpcSeansTamamla(seansAdminId, uygulanmadi = false, not = null, pgOnay = false, pgGerekce = null) {
  if (!seansAdminId) throw new Error('seansAdminId zorunlu');
  /**
   * Seans tamamlama işlemi için gerekli onay ve gerekçe bilgilerini alarak RPC çağrısı yapar.
   * @param {boolean} onay Seansın onaylanıp onaylanmadığını belirten boolean değer.
   * @param {string} gerekce Onay verilmediğinde veya ek bilgi gerektiğinde sağlanan gerekçe metni.
   * @returns {Promise} RPC çağrısının sonucu döndürür.
   */
  const cagri = (onay, gerekce) => rpc('seans_tamamla', {
    p_seans_admin_id: seansAdminId,
    p_uygulanmadi: !!uygulanmadi,
    p_not: not,
    p_pg_onay: !!onay,
    p_pg_gerekce: gerekce || null,
  });
  // P5: seans PG kapısı — RAISE'ı yakala, onaylı tekrarı modal zincirine ver.
  // uygulanmadi=true yolu uygulamadır değil; kapı uygulanmayan çağrıda atlanır.
  try {
    return await cagri(pgOnay, pgGerekce);
  } catch (e) {
    if (!uygulanmadi && typeof _pgKapiHata === 'function' && _pgKapiHata(e, cagri)) {
      return { ok: false, _pgKapi: true };
    }
    throw e;
  }
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

// ── SÜRÜM GEÇMİŞİ (G-20260913-SURUM-GECMISI F2 frozen contract) ─────
// Kalıp: rpcSeansTamamla / rpcReceteGuncelle — ince sarmal, rpc() hata/ok:false
// yolunu aynen kullanır. ok:false → Error, e.data.hata kodu taşır.
// L4 entegrasyon (2026-09-14): stub katmanı söküldü — bu 4 wrapper gerçek RPC'lere gider.
/**
 * Verilen şifre ile geri alma bileti alma işlemi başlatır.
 * @param {string} sifre Geri alma işlemi için kullanılacak şifre.
 * @returns {Promise} İşlem sonucunu içeren Promise nesnesi.
 */
async function rpcGeriAlmaBiletiAl(sifre) {
  return rpc('geri_alma_bileti_al', { p_sifre: sifre });
}
/**
 * Verilen filtreye göre değişim listesini getirir.
 * @param {Object} filtre Filtreleme kriterlerini içeren nesne.
 * @returns {Promise} Filtrelenmiş değişim listesini döndüren Promise.
 */
async function rpcDegisimListele(filtre = {}) {
  return rpc('degisim_listele', { p_filtre: filtre || {} });
}
/**
 * Belirtilen hedef ve seviye parametrelerini kullanarak değişim önizlemesini alır.
 * @param {string} hedef Önizleme yapılacak hedef.
 * @param {number} seviye Önizleme yapılacak seviye.
 * @returns {Promise} Değişim önizleme verisini içeren Promise.
 */
async function rpcDegisimOnizle(hedef, seviye) {
  return rpc('degisim_onizle', { p_hedef: hedef, p_seviye: seviye });
}
/**
 * Belirtilen hedef, seviye ve bilet bilgilerini kullanarak değişim geri alma işlemi başlatır.
 * @param {string} hedef İşlem yapılacak hedef kimlik veya kod.
 * @param {number} seviye İşlem yapılacak seviye değeri.
 * @param {string} bilet İşlem için gerekli olan bilet bilgisi.
 * @param {string|null} gerekce İşlem gerekçesi (varsayılan: null).
 * @returns {Promise} İşlem sonucunu içeren Promise nesnesi.
 */
async function rpcDegisimGeriAl(hedef, seviye, bilet, gerekce = null) {
  return rpc('degisim_geri_al', { p_hedef: hedef, p_seviye: seviye, p_bilet: bilet, p_gerekce: gerekce || null });
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

/**
 * vaka_kalan_gunleri_kaydir_coklu — görev listesindeki vakaların kalan günlerini
 * topluca +N kaydır (F1 coklu-kaydirma). Kısmi başarı sözleşmesi: RPC gövdesi
 * {ok, toplam, kaydirilan, atlanan, hatalar, detaylar} döner; rpc() hata/ok:false
 * yolunda throw eder (e.data gövdeyi taşır) — buraya gelen res hep ok:true'dur.
 * Online-only: RPC_MAP'e (offline replay) girmez, pull seti RPC_TABLES'te.
 * @param {string[]} gorevIds - gorev_log.id listesi
 * @param {number} gun - kaydırma günü (pozitif tam sayı, tek yönlü ileri)
 * @returns {Promise<{ok, toplam, kaydirilan, atlanan, hatalar, detaylar}>}
 */
async function apiCokluKaydir(gorevIds, gun) {
  if (!Array.isArray(gorevIds) || !gorevIds.length) throw new Error('gorevIds boş olamaz');
  if (!Number.isInteger(gun) || gun < 1) throw new Error('gun pozitif tam sayı olmalı');
  return rpc('vaka_kalan_gunleri_kaydir_coklu', {
    p_gorev_ids: gorevIds,
    p_gun: gun,
  });
}

// ── OVSYNC TAKİP (P4 — ovsync-takip planı) ──

/**
 * Ovsync takip panosu cache'ini bozar. ovsync_takip_listele verisini etkileyen her
 * yazma akışından sonra çağrılır: api.js içi nokta = tohumlamaBosVeDevam sarmalı;
 * ui.js/forms.js'teki çağrı noktaları P9/P10'da eklenir (plan P4 tek-yazıcı sınırı).
 * @returns {void}
 */
function _ovsyncTakipInvalidate() {
  window.__ovsyncTakip = null;
}

/**
 * Ovsync takip listesini çeker — P1 RPC ovsync_takip_listele(p_padok text DEFAULT NULL,
 * p_sonlanan_gun int DEFAULT 60; p_sonlanan_gun DEFAULT'lu, buradan geçilmez).
 * Bayat-veri sözleşmesi (plan §6): başarıda window.__ovsyncTakip = {veri, zaman: Date.now()}
 * cache'i yazılır ve {bayat:false, veri, zaman} döner; hata/offline'da throw ETMEZ —
 * {bayat:true, veri: önceki cache verisi|null} döner (önbellek yoksa veri:null —
 * UI açık mesaj basar: P5 loadOvsyncDash). Bayat yolda cache EZİLMEZ.
 * Offline tanıma rpc()'nin gerçek fetch hatasından gelir (M-25: navigator.onLine ön koşulu yazılmaz).
 * @param {string|null} [p_padok=null] - padok filtresi
 * @returns {Promise<{bayat: boolean, veri: any, zaman?: number}>}
 */
async function ovsyncTakipGetir(p_padok = null) {
  try {
    const veri = await rpc('ovsync_takip_listele', { p_padok: p_padok || null });
    const cache = { veri, zaman: Date.now() };
    window.__ovsyncTakip = cache;
    return { bayat: false, veri, zaman: cache.zaman };
  } catch (e) {
    // bayat-veri sözleşmesi: önceki cache korunur; throw yok
    return { bayat: true, veri: window.__ovsyncTakip ? window.__ovsyncTakip.veri : null };
  }
}

/**
 * tohumlama_bos_ve_devam P2b sarmal RPC — Boş sonrası devam (secim: PG|OVSYNC|TAKIP|GEBE
 * modları; gerçek imza P2b DONE: p_tohumlama_id/p_muayene_gorev_id/p_secim/p_pg_urun/
 * p_pg_doz/p_gun/p_saat/p_notlar, tümü DEFAULT'lu → params nesnesi birebir taşınır).
 * rpc() ok:false yolunda throw eder; sunucu red kodları e.data ile taşınır
 * (H5 sözleşmesi: TAKIP_ACIK:{muayene_tarihi,muayene_saat}, PG_KAPI:*, OVSYNC_SECIM_* vb.).
 * Çağrı takip verisini değiştirdiğinden her iki yolda da takip cache'i bozulur
 * (api.js içi invalidate noktası). Online-only: RPC_MAP'e (offline replay) girmez;
 * pull seti RPC_TABLES'ta (tohumlama_bos_ve_devam).
 * @param {object} params - P2b imzası p_* parametreleri
 * @returns {Promise<object>} RPC dönüşü (ok:true yolu)
 */
async function tohumlamaBosVeDevam(params) {
  try {
    const res = await rpc('tohumlama_bos_ve_devam', params);
    _ovsyncTakipInvalidate();
    return res;
  } catch (e) {
    _ovsyncTakipInvalidate();
    throw e;
  }
}
