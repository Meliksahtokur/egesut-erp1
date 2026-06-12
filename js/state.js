// js/state.js
// Merkezi state yönetimi (basit EventEmitter)

class AppState {
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
      // BUG-059 — saat bazlı tedavi seans sistemi
      tedaviPlan: [],            // treatment_day_uygulamalar (seans listesi) — case_id'ye göre filtrelenir
      aktifSeansUndo: new Map(),  // seansId → {undoUntil: Date, prevState: 'done'|'cancelled'}
    };
    this._listeners = {};
  }

  get(key) {
    return this._state[key];
  }

  getAll() {
    return { ...this._state };
  }

  set(key, value) {
    const old = this._state[key];
    if (old === value) return;
    this._state[key] = value;
    this.emit(key, value, old);
    this.emit('*', key, value, old);
  }

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

  on(event, callback) {
    if (!this._listeners[event]) this._listeners[event] = [];
    this._listeners[event].push(callback);
    if (event !== '*') {
      const current = this._state[event];
      if (current !== undefined) callback(current);
    }
    return () => this.off(event, callback);
  }

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

function getState(key) {
  return globalThis.__state.get(key);
}

function setState(key, value) {
  return globalThis.__state.set(key, value);
}
