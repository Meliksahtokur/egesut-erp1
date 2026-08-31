// tests/unit/modal.test.js
// js/utils/modal.js — modal router (openM/closeM/mClose) sözleşme testleri.
//
// Stub notları:
// - modal.js global `g` yardımcısını (js/utils/helpers.js) kullanır; testte
//   birebir aynısı sağlanır: g = id => document.getElementById(id).
// - history stub'ı tarayıcı semantiğini taklit eder: pushState state'i kurar,
//   back() onu düşürür. Böylece open→close router zinciri gerçek gibi çalışır.
// - Kapsam DIŞI id'ler: m-animal/m-insem/m-disease/m-bulk-vaccine/m-bulk-ilac
//   dalları loadIrkDropdown, db.from(...) gibi bu stub'da bulunmayan global
//   yükleyicilere dokunur — yalnız nötr id'ler ve closeM('m-insem') bayrak
//   sıfırlaması test edilir.
const test = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule, makeDomStub, makeElement } = require('./support/loadModule.js');

function loadModal() {
  const calls = { pushes: [], backs: 0 };
  const history = {
    state: null,
    pushState(s) { this.state = s; calls.pushes.push(s); },
    replaceState(s) { this.state = s; },
    back() { this.state = null; calls.backs++; },
    go() {},
  };
  const doc = makeDomStub();
  const m = loadBrowserModule('js/utils/modal.js', {
    dom: doc,
    extra: { g: (id) => doc.getElementById(id), history },
  });
  return { api: m.sandbox, doc, calls, history };
}

// ── openM ──────────────────────────────────────────────────────
test('openM: nötr modal id — "on" sınıfı + history.pushState({modal:id})', () => {
  const { api, doc, calls } = loadModal();
  const el = doc.__setEl('m-birth', makeElement('div'));
  api.openM('m-birth');
  assert.ok(el.classList.contains('on'), 'modal "on" sınıfı almalı');
  // Not: pushState argümanı vm realm'ında yaratıldığı için deepStrictEqual
  // prototype çakışması atar — alan bazlı doğrulama yapılır.
  assert.strictEqual(calls.pushes.length, 1);
  assert.strictEqual(calls.pushes[0].modal, 'm-birth');
});

test('openM: olmayan element → sessiz no-op, pushState ÇAĞRILMAZ', () => {
  const { api, calls } = loadModal();
  api.openM('m-yok');
  assert.strictEqual(calls.pushes.length, 0);
});

// ── closeM ─────────────────────────────────────────────────────
test('closeM: "on" kalkar; history.state eşleşiyorsa back() çağrılır', () => {
  const { api, doc, calls, history } = loadModal();
  const el = doc.__setEl('m-birth', makeElement('div'));
  el.classList.add('on');
  history.state = { modal: 'm-birth' }; // openM'in pushState'inin tarayıcıdaki etkisi
  api.closeM('m-birth');
  assert.ok(!el.classList.contains('on'));
  assert.strictEqual(calls.backs, 1);
});

test('closeM: history.state eşleşmiyorsa back() ÇAĞRILMAZ', () => {
  const { api, doc, calls, history } = loadModal();
  const el = doc.__setEl('m-birth', makeElement('div'));
  el.classList.add('on');
  history.state = { modal: 'baska-modal' };
  api.closeM('m-birth');
  assert.ok(!el.classList.contains('on'));
  assert.strictEqual(calls.backs, 0);
});

test('closeM: element olmasa bile state eşleşiyorsa back() çağrılır (mevcut davranış)', () => {
  // ŞÜPHELİ DAVRANIŞ (belgelenmiş): closeM önce g(id)?.classList.remove yapar —
  // element null olabilir; ama history.state kontrolü element varlığından bağımsız
  // çalışır. DOM'da olmayan bir modalın closeM'i history'de geri gider.
  const { api, calls, history } = loadModal();
  history.state = { modal: 'm-hayalet' };
  api.closeM('m-hayalet');
  assert.strictEqual(calls.backs, 1);
});

test('closeM("m-insem"): planlı tohumlama bayrağı HER kapanış yolunda sıfırlanır', () => {
  const { api, doc } = loadModal();
  doc.__setEl('m-insem', makeElement('div'));
  api._planliTohumlamaGorevId = 'gorev-1'; // globalThis üzerindeki bayrak
  api.closeM('m-insem');
  assert.strictEqual(api._planliTohumlamaGorevId, null);
  // Element olmasa bile (overlay/X/ESC yolları) bayrak yine sıfırlanır
  api._planliTohumlamaGorevId = 'gorev-2';
  api.closeM('m-insem');
  assert.strictEqual(api._planliTohumlamaGorevId, null);
});

// ── mClose (backdrop tıklaması) ────────────────────────────────
test('mClose: e.target === el (backdrop) → kapanır + state eşleşirse back()', () => {
  const { api, doc, calls, history } = loadModal();
  const el = doc.__setEl('m-birth', makeElement('div'));
  el.id = 'm-birth';
  el.classList.add('on');
  history.state = { modal: 'm-birth' };
  api.mClose({ target: el }, el);
  assert.ok(!el.classList.contains('on'));
  assert.strictEqual(calls.backs, 1);
});

test('mClose: e.target ≠ el (içerik tıklaması) → dokunmaz', () => {
  const { api, doc, calls, history } = loadModal();
  const el = doc.__setEl('m-birth', makeElement('div'));
  el.classList.add('on');
  history.state = { modal: 'm-birth' };
  api.mClose({ target: makeElement('button') }, el);
  assert.ok(el.classList.contains('on'));
  assert.strictEqual(calls.backs, 0);
});

// ── router zinciri ─────────────────────────────────────────────
test('router zinciri: open → close turunda state tutarlı (pushState kurar, back düşürür)', () => {
  const { api, doc, calls, history } = loadModal();
  const el = doc.__setEl('m-not', makeElement('div'));
  api.openM('m-not');
  assert.ok(el.classList.contains('on'));
  assert.strictEqual(history.state?.modal, 'm-not'); // pushState state'i kurdu
  api.closeM('m-not');
  assert.ok(!el.classList.contains('on'));
  assert.strictEqual(history.state, null); // back() state'i düşürdü
  assert.strictEqual(calls.backs, 1);
});
