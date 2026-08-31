// tests/unit/events.test.js
// js/utils/events.js birim testleri — merkezi event delegation.
//
// Modül yükleme anında document üzerine 5 listener bağlar (loader bunları
// document.__listeners içinde yakalar; document.__dispatch ile tetiklenir).
// registerAction / registerActions sandbox üzerinde erişilebilir.

const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule, makeElement } = require('./support/loadModule.js');

function yukle() {
  return loadBrowserModule('js/utils/events.js');
}

// data-* attribute taşıyan ve closest çağrısında KENDİSİNİ döndüren element
// (gerçek DOM'da [data-action] atası gibi davranır).
function aksiyonEl(tag, attr, deger) {
  const el = makeElement(tag);
  el.dataset[attr] = deger;
  el.closest = () => el;
  return el;
}

// ── Yükleme / listener kaydı ─────────────────────────────────────

test('yükleme anında document üzerine 5 listener eklenir: click, input, focusin, keydown, change', () => {
  const { document } = yukle();
  assert.deepStrictEqual(
    Object.keys(document.__listeners).sort(),
    ['change', 'click', 'focusin', 'input', 'keydown']
  );
  for (const tip of Object.keys(document.__listeners)) {
    assert.strictEqual(document.__listeners[tip].length, 1, `${tip} için 1 dinleyici olmalı`);
  }
});

// ── data-action (click delegation) ───────────────────────────────

test('data-action tıklama: handler (el, event) imzasıyla çağrılır, closest "[data-action]" ile aranır', () => {
  const { sandbox, document } = yukle();
  const cagri = [];
  sandbox.registerAction('deneme', (...a) => cagri.push(a));
  const el = makeElement('div');
  el.dataset.action = 'deneme';
  let closestArg = null;
  el.closest = (sel) => { closestArg = sel; return el; };
  const ev = { target: el, preventDefault() {} };
  document.__dispatch('click', ev);
  assert.strictEqual(cagri.length, 1, 'handler tam 1 kez çağrılmalı');
  assert.strictEqual(cagri[0].length, 2, 'handler (el, event) iki argüman almalı');
  assert.strictEqual(cagri[0][0], el, 'ilk argüman bulunan element olmalı');
  assert.strictEqual(cagri[0][1], ev, 'ikinci argüman olay nesnesi olmalı');
  assert.strictEqual(closestArg, '[data-action]');
});

test('data-action atası yok (closest null): handler çağrılmaz, preventDefault çağrılmaz', () => {
  const { sandbox, document } = yukle();
  let cagri = 0;
  sandbox.registerAction('deneme', () => cagri++);
  const el = makeElement('div'); // varsayılan closest → null
  let prevented = false;
  document.__dispatch('click', { target: el, preventDefault() { prevented = true; } });
  assert.strictEqual(cagri, 0);
  assert.strictEqual(prevented, false);
});

test('kayıtlı olmayan action: handler çağrılmaz, preventDefault da çağrılmaz', () => {
  const { sandbox, document } = yukle();
  let cagri = 0;
  sandbox.registerAction('baska', () => cagri++);
  const el = makeElement('div');
  el.dataset.action = 'kayitli-degil';
  el.closest = () => el;
  let prevented = false;
  document.__dispatch('click', { target: el, preventDefault() { prevented = true; } });
  assert.strictEqual(cagri, 0, 'başka actionın handlerı tetiklenmemeli');
  assert.strictEqual(prevented, false, 'kayıtsız actionda preventDefault çağrılmamalı');
});

test('click: DIV hedefte preventDefault ÇAĞRILIR', () => {
  const { sandbox, document } = yukle();
  sandbox.registerAction('a', () => {});
  const el = aksiyonEl('div', 'action', 'a');
  let prevented = false;
  document.__dispatch('click', { target: el, preventDefault() { prevented = true; } });
  assert.strictEqual(prevented, true);
});

test('click: BUTTON hedefte preventDefault ÇAĞRILIR', () => {
  const { sandbox, document } = yukle();
  sandbox.registerAction('a', () => {});
  const el = aksiyonEl('button', 'action', 'a');
  let prevented = false;
  document.__dispatch('click', { target: el, preventDefault() { prevented = true; } });
  assert.strictEqual(prevented, true);
});

test('click: INPUT/SELECT/TEXTAREA/LABEL hedeflerinde preventDefault ÇAĞRILMAZ, handler yine çalışır', () => {
  const { sandbox, document } = yukle();
  for (const tag of ['input', 'select', 'textarea', 'label']) {
    let cagri = 0;
    let prevented = false;
    let gelenEl = null;
    sandbox.registerAction('f', (el) => { cagri++; gelenEl = el; });
    // Hedef form elemanı; data-action taşıyan ata ise DIV
    const ata = makeElement('div');
    ata.dataset.action = 'f';
    const hedef = makeElement(tag);
    hedef.closest = () => ata;
    document.__dispatch('click', { target: hedef, preventDefault() { prevented = true; } });
    assert.strictEqual(cagri, 1, `${tag}: handler çağrılmalı`);
    assert.strictEqual(gelenEl, ata, `${tag}: handler ata elementini almalı`);
    assert.strictEqual(prevented, false, `${tag}: preventDefault çağrılmamalı`);
  }
});

// ── data-input / data-focus / data-change delegasyonları ────────

test('data-input: input olayı handlera (el, event) geçer, preventDefault kullanılmaz', () => {
  const { sandbox, document } = yukle();
  const cagri = [];
  sandbox.registerAction('yazi', (...a) => cagri.push(a));
  const el = aksiyonEl('input', 'input', 'yazi');
  let prevented = false;
  const ev = { target: el, preventDefault() { prevented = true; } };
  document.__dispatch('input', ev);
  assert.strictEqual(cagri.length, 1);
  assert.strictEqual(cagri[0].length, 2);
  assert.strictEqual(cagri[0][0], el);
  assert.strictEqual(cagri[0][1], ev);
  assert.strictEqual(prevented, false, 'input delegasyonu preventDefault çağırmaz');
});

test('data-focus: focusin olayı handlera (el, event) geçer', () => {
  const { sandbox, document } = yukle();
  const cagri = [];
  sandbox.registerAction('odak', (...a) => cagri.push(a));
  const el = aksiyonEl('input', 'focus', 'odak');
  const ev = { target: el, preventDefault() {} };
  document.__dispatch('focusin', ev);
  assert.strictEqual(cagri.length, 1);
  assert.strictEqual(cagri[0].length, 2);
  assert.strictEqual(cagri[0][0], el);
  assert.strictEqual(cagri[0][1], ev);
});

test('data-change: change olayı handlera (el, event) geçer', () => {
  const { sandbox, document } = yukle();
  const cagri = [];
  sandbox.registerAction('degis', (...a) => cagri.push(a));
  const el = aksiyonEl('select', 'change', 'degis');
  const ev = { target: el, preventDefault() {} };
  document.__dispatch('change', ev);
  assert.strictEqual(cagri.length, 1);
  assert.strictEqual(cagri[0].length, 2);
  assert.strictEqual(cagri[0][0], el);
  assert.strictEqual(cagri[0][1], ev);
});

// ── data-keydown delegasyonu (FARKLI kontrat) ────────────────────

test('data-keydown: handler FARKLI imzayla çağrılır — TEK argüman { key, event } alır', () => {
  // ŞÜPHELİ DAVRANIŞ: click/input/focusin/change delegasyonları handlera (el, e)
  // geçirirken keydown SARMALANMIŞ tek nesne ({ key, event }) geçirir; element
  // handlera hiç verilmez. Tutarsız delegasyon kontratı — mevcut davranış test edildi.
  const { sandbox, document } = yukle();
  const cagri = [];
  sandbox.registerAction('tus', (...a) => cagri.push(a));
  const el = aksiyonEl('input', 'keydown', 'tus');
  const ev = { key: 'Enter', target: el, preventDefault() {} };
  document.__dispatch('keydown', ev);
  assert.strictEqual(cagri.length, 1);
  assert.strictEqual(cagri[0].length, 1, 'keydown handlerı (el, e) değil TEK argüman alır');
  assert.strictEqual(cagri[0][0].key, 'Enter');
  assert.strictEqual(cagri[0][0].event, ev);
  assert.strictEqual(cagri[0][0].el, undefined, 'sarmalanmış nesnede element verilmez');
});

// ── registerActions (toplu kayıt) ────────────────────────────────

test('registerActions: toplu kayıt aynı adlı tekil kaydı Ezer, yeni anahtarlar ekler', () => {
  const { sandbox, document } = yukle();
  const tekil = [];
  const bulkOrtak = [];
  const bulkYeni = [];
  sandbox.registerAction('ortak', () => tekil.push(1));
  sandbox.registerActions({ ortak: () => bulkOrtak.push(1), yeni: () => bulkYeni.push(1) });
  document.__dispatch('click', { target: aksiyonEl('div', 'action', 'ortak'), preventDefault() {} });
  document.__dispatch('click', { target: aksiyonEl('div', 'action', 'yeni'), preventDefault() {} });
  assert.strictEqual(tekil.length, 0, 'tekil kayıt ezilmiş olmalı');
  assert.strictEqual(bulkOrtak.length, 1, 'toplu kayıttaki override çalışmalı');
  assert.strictEqual(bulkYeni.length, 1, 'toplu kayıt yeni anahtarı eklemeli');
});
