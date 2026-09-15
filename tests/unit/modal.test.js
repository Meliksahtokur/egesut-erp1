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

// ── L4-08 (onarım turu): iç yeniden-açılışta TEK history entry ─────
// dgOnizleGoster zincir önerisi/⟲ yollarında openM('m-dg-onizle')'i İKİNCİ kez
// çağırır; guardsız push fazladan entry sızdırır, closeM tek back attığından
// S5 "tek geri" bozulurdu. Invariant: açık modal başına TAM BİR modal-entry'si.
test('L4-08: openM aynı modal history tepesinde ikinci kez — YENİ pushState YOK', () => {
  const { api, doc, calls, history } = loadModal();
  const el = doc.__setEl('m-dg-onizle', makeElement('div'));
  api.openM('m-dg-onizle');
  assert.strictEqual(calls.pushes.length, 1, 'ilk açılış push alır');
  api.openM('m-dg-onizle'); // iç yeniden-açılış (zincir önerisi / ⟲ deseni)
  assert.strictEqual(calls.pushes.length, 1, 'aynı-id üstteyken push EZİLMEZ');
  assert.ok(el.classList.contains('on'), 'modal açık kalır');
  assert.strictEqual(history.state?.modal, 'm-dg-onizle');
});

test('L4-08: open→open→close turunda TEK back her şeyi temizler (S5 tek-geri)', () => {
  const { api, doc, calls, history } = loadModal();
  const el = doc.__setEl('m-dg-onizle', makeElement('div'));
  api.openM('m-dg-onizle');
  api.openM('m-dg-onizle');
  api.closeM('m-dg-onizle');
  assert.strictEqual(calls.backs, 1, 'tek back');
  assert.ok(!el.classList.contains('on'));
  assert.strictEqual(history.state, null, 'entry sızmadı — altındaki görünüm bir back\'te kapanır');
  assert.strictEqual((api._modalStack || []).length, 0);
});

test('L4-08: FARKLI modallar üst üste — her biri push alır (regresyon)', () => {
  const { api, doc, calls } = loadModal();
  doc.__setEl('m-dg-onizle', makeElement('div'));
  doc.__setEl('m-dg-bilet', makeElement('div'));
  api.openM('m-dg-onizle');
  api.openM('m-dg-bilet');
  assert.strictEqual(calls.pushes.length, 2, 'farklı id — yeni entry meşru');
  assert.strictEqual(calls.pushes[1].modal, 'm-dg-bilet');
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

// ── W3: takvim router-modali (tek-tarih-takvim) ──────────────────
// Takvim .on class kullanmaz — DOM'dan remove() ile kapanır; closeM tüm
// kapanış yolları (X, backdrop, ESC, geri tuşu, Onayla) için tek noktadır.
test('closeM("tek-tarih-takvim"): element remove() edilir + back mekanizması ortak', () => {
  const { api, doc, calls, history } = loadModal();
  const el = doc.__setEl('tek-tarih-takvim', makeElement('div'));
  const cikarilan = [];
  el.remove = () => { cikarilan.push('tek-tarih-takvim'); };
  history.state = { modal: 'tek-tarih-takvim' };
  api.closeM('tek-tarih-takvim');
  assert.deepStrictEqual(cikarilan, ['tek-tarih-takvim'], 'takvim DOM\'dan kaldırılmalı (.on class YOK)');
  assert.strictEqual(calls.backs, 1, 'modal-stack deseni: history entry back ile temizlenir');
  assert.ok(!(api._modalStack || []).includes('tek-tarih-takvim'), 'stack\'ten düşer');
});

test('closeM("tek-tarih-takvim"): state modal değilse back ÇAĞRILMAZ (görünüm kapanışı yalnız DOM)', () => {
  const { api, doc, calls, history } = loadModal();
  const el = doc.__setEl('tek-tarih-takvim', makeElement('div'));
  const cikarilan = [];
  el.remove = () => { cikarilan.push('x'); };
  history.state = { pg: 'gecmis' };
  api.closeM('tek-tarih-takvim');
  assert.strictEqual(cikarilan.length, 1, 'DOM kapanır');
  assert.strictEqual(calls.backs, 0, 'history dokunulmaz');
});

test('closeM: mevcut modal id\'leri remove() ÇAĞIRMAZ (regresyon — .on class deseni)', () => {
  const { api, doc, calls, history } = loadModal();
  const el = doc.__setEl('m-birth', makeElement('div'));
  let removeCagri = 0;
  el.remove = () => { removeCagri++; };
  el.classList.add('on');
  history.state = { modal: 'm-birth' };
  api.closeM('m-birth');
  assert.strictEqual(removeCagri, 0, 'mevcut modallar remove ile KAPANMAZ');
  assert.ok(!el.classList.contains('on'));
});

// ── W3: ESC capture handler (modal.js sonundaki document keydown) ────
// Davranış: görünür autocomplete paneli varsa ESC ÖNCE panelleri kapatır
// (modal kalır); panel yoksa en üst router-modal kapanır. W3 code-review
// bulgusunun kilidi: ilk sürümdeki "yalnız YUT" guard'ı odak-dışı panelde
// ESC'i tamamen öldürüyordu.
test('ESC: görünür autocomplete paneli kapatır, modal KALIR; 2. ESC modalı kapatır', () => {
  const { api, doc, calls, history } = loadModal();
  const el = doc.__setEl('m-birth', makeElement('div'));
  el.classList.add('on');
  const panel = doc.__setEl('ac-tahid', makeElement('div'));
  panel.style.display = 'block'; // açık autocomplete paneli
  doc.querySelectorAll = () => [panel]; // makeDomStub'ın stub seçiciyi test-eleme bağla
  api._modalStack = ['m-birth']; // openM'in kurduğu stack durumu (sandbox'ta elle)
  history.state = { modal: 'm-birth' };
  doc.__dispatch('keydown', { key: 'Escape' });
  assert.strictEqual(panel.style.display, 'none', '1. ESC paneli kapatmalı');
  assert.ok(el.classList.contains('on'), '1. ESC modal AÇIK bırakmalı');
  doc.__dispatch('keydown', { key: 'Escape' });
  assert.ok(!el.classList.contains('on'), '2. ESC modalı kapatmalı');
  assert.strictEqual(calls.backs, 1);
});

test('ESC: panel yokken en üst modal direkt kapanır (odak-bağımsız — review bulgusu)', () => {
  const { api, doc, calls, history } = loadModal();
  const el = doc.__setEl('m-birth', makeElement('div'));
  el.classList.add('on');
  api._modalStack = ['m-birth'];
  history.state = { modal: 'm-birth' };
  doc.__dispatch('keydown', { key: 'Escape' });
  assert.ok(!el.classList.contains('on'), 'panel yok — ESC modalı kapatmalı (yutmamalı)');
  assert.strictEqual(calls.backs, 1);
});

test('ESC: boş stack — no-op (sayfa görünümlerine dokunmaz)', () => {
  const { api, doc, calls } = loadModal();
  doc.__dispatch('keydown', { key: 'Escape' });
  assert.strictEqual(calls.backs, 0);
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
