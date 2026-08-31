// tests/unit/support/loadModule.js
// Tarayıcı-global yazılmış js/*.js modüllerini node:test altında yüklemek için
// vm tabanlı loader. js/ kaynak koduna HİÇ dokunulmadan test edilebilmesini sağlar.
//
// Kullanım:
//   const { loadBrowserModule, makeDomStub, makeElement } = require('./support/loadModule.js');
//   const { sandbox, document } = loadBrowserModule('js/state.js');
//   sandbox.getState('currentPage');  // 'dash'
//
// vm'de üst-seviye `function` bildirimleri context nesnesine property olur
// (sandbox.fnAdi). `let`/`const` bildirimleri global lexical scope'ta kalır —
// bunlar için `expose: ['ADI']` seçeneği ikinci bir script ile dışarı çıkarır.
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const REPO_ROOT = path.join(__dirname, '..', '..', '..');

// ── Minimal DOM element stub ─────────────────────────────────────────
function makeElement(tag = 'div') {
  const classes = new Set();
  const el = {
    tagName: String(tag).toUpperCase(),
    children: [],
    dataset: {},
    style: {},
    className: '',
    innerHTML: '',
    textContent: '',
    value: '',
    id: '',
    parentNode: null,
    disabled: false,
    checked: false,
    _listeners: {},
    classList: {
      add: (...cs) => cs.forEach(c => classes.add(c)),
      remove: (...cs) => cs.forEach(c => classes.delete(c)),
      toggle: (c, force) => {
        const on = force === undefined ? !classes.has(c) : force;
        on ? classes.add(c) : classes.delete(c);
        return on;
      },
      contains: c => classes.has(c),
    },
    addEventListener(type, fn) { (el._listeners[type] = el._listeners[type] || []).push(fn); },
    removeEventListener() {},
    dispatchEvent(type, ev) {
      (el._listeners[type] || []).forEach(fn => fn(ev || {}));
    },
    appendChild(child) { el.children.push(child); child.parentNode = el; return child; },
    prepend(child) { el.children.unshift(child); child.parentNode = el; return child; },
    removeChild(child) {
      const i = el.children.indexOf(child);
      if (i !== -1) el.children.splice(i, 1);
      return child;
    },
    insertBefore(newNode, ref) { el.children.unshift(newNode); newNode.parentNode = el; return newNode; },
    remove() { if (el.parentNode) el.parentNode.removeChild(el); },
    contains: () => false,
    closest: () => null,
    querySelectorAll: () => [],
    querySelector: () => null,
    focus() {}, blur() {},
    click() { el.dispatchEvent('click', { target: el, preventDefault() {} }); },
    setAttribute() {}, getAttribute: () => null, removeAttribute() {},
  };
  return el;
}

// ── Minimal document stub ────────────────────────────────────────────
function makeDomStub() {
  const byId = new Map();
  const docListeners = {};
  const doc = {
    getElementById: id => byId.get(id) || null,
    // Testte elle element yerleştir: doc.__setEl('a-kupe', makeElement('input'))
    __setEl(id, el) { el.id = id; byId.set(id, el); return el; },
    createElement: tag => makeElement(tag),
    createTextNode: t => ({ nodeType: 3, textContent: t }),
    querySelectorAll: () => [],
    querySelector: () => null,
    addEventListener(type, fn) { (docListeners[type] = docListeners[type] || []).push(fn); },
    removeEventListener() {},
    body: makeElement('body'),
    documentElement: makeElement('html'),
    // Yakalanan document listener'larını testte tetikle:
    // doc.__dispatch('click', { target: el, preventDefault(){} })
    __dispatch(type, ev) { (docListeners[type] || []).forEach(fn => fn(ev)); },
    __listeners: docListeners,
  };
  return doc;
}

// ── localStorage stub ────────────────────────────────────────────────
function makeStorage(initial = {}) {
  const m = new Map(Object.entries(initial));
  return {
    getItem: k => (m.has(k) ? m.get(k) : null),
    setItem: (k, v) => m.set(k, String(v)),
    removeItem: k => m.delete(k),
    clear: () => m.clear(),
    key: i => Array.from(m.keys())[i] ?? null,
    get length() { return m.size; },
  };
}

// ── Supabase client stub (db.rpc(...) / db.from(...) çağrıları için) ─
// rpcHandlers: { rpcAdi: (params) => ({ data, error }) }
function makeDbStub(rpcHandlers = {}) {
  return {
    rpc: async (name, params) => {
      const h = rpcHandlers[name];
      if (!h) return { data: null, error: { message: `test stub: rpc "${name}" tanımlı değil` } };
      try { return await h(params); }
      catch (e) { return { data: null, error: { message: String(e?.message || e) } }; }
    },
    from: () => { throw new Error('test stub: db.from() kullanımı bu test için stublanmadı'); },
  };
}

// ── Modül yükleme ────────────────────────────────────────────────────
function loadBrowserModule(relPath, opts = {}) {
  const abs = path.join(REPO_ROOT, relPath);
  const src = fs.readFileSync(abs, 'utf8');

  const document = opts.dom || makeDomStub();
  const localStorage = opts.storage || makeStorage();
  const winListeners = {};
  const window = Object.assign(makeElement('window'), {
    addEventListener(type, fn) { (winListeners[type] = winListeners[type] || []).push(fn); },
    removeEventListener() {},
    localStorage,
  });

  const sandbox = {
    document,
    window,
    localStorage,
    navigator: { userAgent: 'node-test' },
    location: { href: 'http://localhost/', origin: 'http://localhost', search: '', hash: '' },
    history: { pushState() {}, replaceState() {}, back() {}, go() {} },
    fetch: () => Promise.reject(new Error('fetch testlerde kapalı')),
    setTimeout, clearTimeout, setInterval, clearInterval,
    requestAnimationFrame: fn => setTimeout(fn, 0),
    alert() {}, confirm: () => false, prompt: () => null,
    console,
    // Standart tarayıcı/Node global'leri (vm context'i bunları devralmaz)
    URL, URLSearchParams, TextEncoder, TextDecoder, AbortController,
    performance, queueMicrotask, structuredClone, btoa, atob,
    crypto: require('node:crypto').webcrypto,
    ...opts.extra,
  };
  sandbox.window.sandbox = sandbox; // gerektiğinde window üzerinden erişim
  sandbox.globalThis = sandbox;
  sandbox.globalThis.window = window;
  // extra'dan geçenler (ör. supabase stub) window'a da yansıt —
  // bazı modüller `window.supabase.createClient` / `window.supabase.auth` diye erişir
  for (const k of Object.keys(opts.extra || {})) {
    try { window[k] = opts.extra[k]; } catch { /* sadece-okunur props yoksayılır */ }
  }

  vm.createContext(sandbox);
  vm.runInContext(src, sandbox, { filename: abs });

  // let/const üst-seviye bildirimlerini dışarı çıkar (function'lar zaten sandbox'ta)
  let exposed = {};
  if (opts.expose && opts.expose.length) {
    exposed = vm.runInContext(`({ ${opts.expose.join(', ')} })`, sandbox, {
      filename: abs + ' [expose]',
    });
  }

  return { sandbox, document, localStorage, window, listeners: winListeners, exposed };
}

// ── Cerrahi fonksiyon çıkarma (tüm modül yüklenemiyorsa) ─────────────
// Kaynak metinden `function adı(...){...}` gövdesini dengeli parantezle keser.
// String (' " `) ve yorumları sayar; şablon literallerindeki ${} çiftleri dengeli
// olduğu sürece doğrudur. Yalnızca tam modül yüklemesi başarısızsa fallback olarak kullan.
function extractFunctionSource(relPath, fnName) {
  const abs = path.join(REPO_ROOT, relPath);
  const src = fs.readFileSync(abs, 'utf8');
  const start = src.search(new RegExp(`^\\s*(?:async\\s+)?function\\s+${fnName}\\s*\\(`, 'm'));
  if (start === -1) throw new Error(`${relPath}: "function ${fnName}" bulunamadı`);

  let i = src.indexOf('{', start);
  let depth = 0, str = null, escNext = false, lineComment = false, blockComment = false;
  for (; i < src.length; i++) {
    const c = src[i], n = src[i + 1];
    if (lineComment) { if (c === '\n') lineComment = false; continue; }
    if (blockComment) { if (c === '*' && n === '/') { blockComment = false; i++; } continue; }
    if (str) {
      if (escNext) { escNext = false; continue; }
      if (c === '\\') { escNext = true; continue; }
      if (c === str) str = null;
      continue;
    }
    if (c === '/' && n === '/') { lineComment = true; i++; continue; }
    if (c === '/' && n === '*') { blockComment = true; i++; continue; }
    if (c === "'" || c === '"' || c === '`') { str = c; continue; }
    if (c === '{') depth++;
    else if (c === '}') {
      depth--;
      if (depth === 0) return src.slice(start, i + 1).trim();
    }
  }
  throw new Error(`${relPath}: ${fnName} gövdesi kapanmadı (dengesiz süslü parantez)`);
}

// extract + değerlendir: bağımsız (globals kullanmayan) fonksiyonlar için
function loadExtractedFunction(relPath, fnName, opts = {}) {
  const fnSrc = extractFunctionSource(relPath, fnName);
  const ctx = { console, Date, Math, JSON, ...opts.extra };
  vm.createContext(ctx);
  return vm.runInContext(`(${fnSrc})`, ctx, { filename: `${relPath}#${fnName}` });
}

module.exports = {
  makeElement,
  makeDomStub,
  makeStorage,
  makeDbStub,
  loadBrowserModule,
  extractFunctionSource,
  loadExtractedFunction,
};
