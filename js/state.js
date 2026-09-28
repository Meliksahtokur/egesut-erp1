// js/state.js
// Merkezi state yönetimi (basit EventEmitter)

class AppState {
  /**
   * Yeni bir sınıf örneği oluşturur; uygulamanın tüm durumunu (hayvanlar, stok, sayfa ve filtre seçimleri, tedavi planları vb.) tutan _state nesnesini başlatır ve olay aboneliklerini saklayan _listeners sözlüğünü boş olarak tanımlar.
   * @returns {void}
   */
  constructor() {
    this._state = {
      animals: [],              // _A
      stock: [],                 // _S
      curStok: null,             // _curStk
      currentPage: 'dash',       // _curPg
      suruFilter: 'tumuu',       // _suruFilter
      suruSiralama: 'kupe',      // _suruSiralama
      currentUremeTab: 'kizginlik',     // _curUremeTab (zaten var)
      currentHistoryFilter: 'hepsi',   // _curGecmisFilter (zaten var)
      currentTaskFilter: 'today',      // _curTaskFilter (zaten var)
      currentTaskDetail: null,         // _curTaskDet (zaten var)
      currentDisease: null,            // _curHst (zaten var)
      currentInsem: null,              // _curToh (zaten var)
      currentNotificationTab: 'bekliyor', // _curBildirimTab (zaten var)
      gebeIds: [],               // _gebeIds — ARRAY (new Set() sarilarak kullanilir)
      hastaIds: new Set(),       // _hastaIds — SET (direkt .has() ile)
      aktifVakalar: [],          // cases status='active' satırları — hastalık filtresi seçenekleri + açılış sıralaması
      diseases: [],              // diseases tablosu — filtre seçeneklerinde hastalık adı eşlemesi
      // BUG-059 — saat bazlı tedavi seans sistemi
      tedaviPlan: [],            // treatment_day_uygulamalar (seans listesi) — case_id'ye göre filtrelenir
      aktifSeansUndo: new Map(),  // seansId → {undoUntil: Date, prevState: 'done'|'cancelled'}
    };
    this._listeners = {};
  }

  /**
   * Verilen anahtara (key) sahip durumu döndürür.
   * @param {string} key - Döndürülecek değerin bulunduğu anahtar.
   * @returns {*} İstenen anahtara ait durum değeri.
   */
  get(key) {
    return this._state[key];
  }

  /**
   * İç durumu sığ kopya olarak döndürür.
   * @returns {Object} İç durumun (this._state) sığ kopyası olan nesne.
   */
  getAll() {
    return { ...this._state };
  }

  /**
   * Verilen anahtarın mevcut değeri ile yeni değeri eşitse işlemi atlar,
   * yoksa durumu günceller ve değişiklikleri ilgili dinleyicilere bildirir.
   * @param {string} key Güncellenecek veya yeni eklenmek istenen anahtar.
   * @param {*} value Yeni atanan değer.
   * @returns {void} Değer değişmediğinde veya değiştiğinde hiçbir şey döndürmez.
   */
  set(key, value) {
    const old = this._state[key];
    if (old === value) return;
    this._state[key] = value;
    this.emit(key, value, old);
    this.emit('*', key, value, old);
  }

  // SÖZLEŞME (test-rapor #3 — davranış bilinçli korunuyor, state.test.js kilitli):
  // set():     key event → (value, old)  ·  '*' event → (key, value, old)
  // setBatch(): key event → (value)      ·  '*' event → tek seferde [{key, value}]
  // '*' dinleyicileri iki biçimi ayrı işlemek zorundadır.
  /**
   * Verilen güncellemeleri toplu olarak durum nesnesine uygular; sadece değeri değişen anahtarlar için olay yayınlar.
   * Değişen anahtarların her biri için ilgili anahtar adıyla bir olay, ardından tüm değişiklikleri içeren '*' olayı yayınlar.
   * @param {Object} updates - Anahtar/değer çiftlerinden oluşan güncelleme nesnesi.
   * @returns {void} Değişiklik yoksa hiçbir şey yapmadan çıkar.
   */
  setBatch(updates) {
    const changed = [];
    for (const [key, value] of Object.entries(updates)) {
      if (this._state[key] !== value) {
        this._state[key] = value;
        changed.push(key);
      }
    }
    if (changed.length === 0) return;
    for (const key of changed) {
      this.emit(key, this._state[key]);
    }
    this.emit('*', changed.map(k => ({ key: k, value: this._state[k] })));
  }

  /**
   * Belirtilen olaya (event) bağlı bir callback fonksiyonunu dinleyici listesine ekler.
   * Eğer olay zaten aktif bir durumda ise, mevcut durumu callback ile hemen çağırır.
   * Dinleyiciyi ekledikten sonra, bu dinleyiciyi kaldırmak için kullanılan bir silme fonksiyonu döndürür.
   * @param {string} event Dinlenecek olayın adı.
   * @param {Function} callback Olay tetiklendiğinde çalışacak fonksiyon.
   * @returns {Function} Dinleyiciyi kaldırmak için çağrılacak silme fonksiyonu.
   */
  on(event, callback) {
    if (!this._listeners[event]) this._listeners[event] = [];
    this._listeners[event].push(callback);
    if (event !== '*') {
      const current = this._state[event];
      if (current !== undefined) callback(current);
    }
    return () => this.off(event, callback);
  }

  /**
   * Belirtilen olaya (event) kayıtlı olan callback fonksiyonunu dinleyiciler listesinden kaldırır.
   * @param {string} event Silinmesi istenen olayın adı.
   * @param {Function} callback Silinmesi istenen callback fonksiyonu.
   * @returns {void}
   */
  off(event, callback) {
    if (!this._listeners[event]) return;
    const idx = this._listeners[event].indexOf(callback);
    if (idx !== -1) this._listeners[event].splice(idx, 1);
  }

  emit(event, ...args) {
    if (this._listeners[event]) {
      this._listeners[event].forEach(cb => cb(...args));
    }
  }
}

const AppStateInstance = new AppState();
globalThis.__state = AppStateInstance;

/**
 * Global durum objesinden verilen anahtara karşılık gelen değeri döndürür.
 * @param {string} key - Durum objesinde aranacak anahtar.
 * @returns {*} Durum objesindeki ilgili değer.
 */
function getState(key) {
  return globalThis.__state.get(key);
}

/**
 * globalThis üzerinde tutulan state haritasına verilen anahtarla değer atar.
 * @param {string} key - Değerin kaydedileceği anahtar.
 * @param {*} value - Kaydedilecek değer.
 * @returns {*} state haritasındaki set işleminden dönen değer.
 */
function setState(key, value) {
  return globalThis.__state.set(key, value);
}
