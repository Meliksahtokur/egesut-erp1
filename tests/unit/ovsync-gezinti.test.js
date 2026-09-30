// tests/unit/ovsync-gezinti.test.js — PLAN P5: sayfa iskeleti + gezinme sözleşmesi
// (G-20260930-OVSYNC-TAKIP-IMPL, plan.md P5).
//
// Kapsam:
//  1. Durum matrisi (spec §5, plan P5 Interfaces): bayrak_kapalı / bayat / veri:null /
//     taze-yer-tutucu — sessiz boş YASAK.
//  2. Bayat etiket biçimi: "çevrimdışı · HH:MM verisi".
//  3. loadOvsyncDash DOM koşumu: 4 durum + §6b scroll geri yükleme + gezinme durumu
//     (window._curOvsyncPadok / window._curOvsyncBolum{acik}).
//  4. Gezinme sözleşmesi (§6b, kaynak testleri): goTo ovsync dalı; scroll kaydı;
//     #pg-ovsync .pg bloğu + R13 geri butonu (mevcut nav-geri = history.back —
//     goTo('dash') YOK); alt-nav'a giriş YOK; render P6'nın (loadOvsyncDash
//     renderOvsyncSayfa ÇAĞIRMAZ).
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { loadBrowserModule, extractFunctionSource, makeElement, makeDomStub } = require('./support/loadModule.js');

const REPO = path.join(__dirname, '..', '..');
const UI = 'js/ui.js';
const APP = 'js/app.js';
const HANDLERS = 'js/utils/handlers.js';
const HTML = path.join(REPO, 'index.html');

const escMirror = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const escAttrMirror = (s) => String(s ?? '')
  .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
  .replace(/</g, '&lt;').replace(/>/g, '&gt;');

// ui.js bir kez yüklenir (saf fonksiyonlar; loadOvsyncDash DOM testlerinde taze sandbox kullanır)
const { sandbox: ui } = loadBrowserModule(UI, {
  extra: {
    esc: escMirror, escAttr: escAttrMirror,
    getData: async () => [],
    getState: () => [],
  },
});

// ── 1. Durum matrisi (saf: _ovsyncDashDurum) ─────────────────────────
test('P5: durum makinesi fonksiyonları ui.js tanımlı (_ovsyncDashDurum, _ovsyncBayatEtiket, loadOvsyncDash)', () => {
  assert.equal(typeof ui._ovsyncDashDurum, 'function', 'P5: _ovsyncDashDurum ui.js tanımlı değil');
  assert.equal(typeof ui._ovsyncBayatEtiket, 'function', 'P5: _ovsyncBayatEtiket ui.js tanımlı değil');
  assert.equal(typeof ui.loadOvsyncDash, 'function', 'P5: loadOvsyncDash ui.js tanımlı değil');
});

test('P5 matris (i): bayrak_kapalı → tur bayrak_kapali (açık mesaj durumu)', () => {
  const d = ui._ovsyncDashDurum({ veri: { bayrak_kapali: true, kpa: {}, satirlar: [] } });
  assert.deepEqual(d, { tur: 'bayrak_kapali' });
});

test('P5 matris (ii): bayat önbellek + veri → tur bayat (etiket + bayat içerik)', () => {
  const veri = { kpa: {}, satirlar: [] };
  const d = ui._ovsyncDashDurum({ bayat: true, veri, zaman: 1788000000000 });
  assert.equal(d.tur, 'bayat');
  assert.equal(d.veri, veri);
  assert.equal(d.zaman, 1788000000000);
});

test('P5 matris (iii): bayat + veri:null → tur veri_yok ("İnternet yok" durumu)', () => {
  assert.deepEqual(ui._ovsyncDashDurum({ bayat: true, veri: null }), { tur: 'veri_yok' });
});

test('P5 matris (iii-b): taze çağrıda veri null/eksik → tur veri_yok (sessiz boş YASAK)', () => {
  assert.deepEqual(ui._ovsyncDashDurum({ veri: null }), { tur: 'veri_yok' });
  assert.deepEqual(ui._ovsyncDashDurum({}), { tur: 'veri_yok' });
  assert.deepEqual(ui._ovsyncDashDurum(null), { tur: 'veri_yok' });
});

test('P5 matris (iv): taze veri → tur taze (render P6)', () => {
  const veri = { bayrak_kapali: false, kpa: {}, satirlar: [] };
  const d = ui._ovsyncDashDurum({ veri });
  assert.equal(d.tur, 'taze');
  assert.equal(d.veri, veri);
});

test('P5 bayat etiketi: "çevrimdışı · HH:MM verisi" (sıfır dolgulu; zaman yoksa açık etiket)', () => {
  const t1405 = new Date(2026, 8, 30, 14, 5).getTime();
  assert.equal(ui._ovsyncBayatEtiket(t1405), 'çevrimdışı · 14:05 verisi');
  const t905 = new Date(2026, 8, 30, 9, 5).getTime();
  assert.equal(ui._ovsyncBayatEtiket(t905), 'çevrimdışı · 09:05 verisi');
  assert.equal(ui._ovsyncBayatEtiket(null), 'çevrimdışı veri');
  assert.equal(ui._ovsyncBayatEtiket(NaN), 'çevrimdışı veri');
});

// ── 2. loadOvsyncDash DOM koşumu (taze sandbox per test) ─────────────
// ovsyncTakipGetir P4'ündür (js/api.js) — burada stub'lanır; P5 sözleşmesi
// "P4 throw etmez" der ama iskelet throw'da da dayanıklı olmalı.
function ovsyncSandboxu(getirImpl, { bayatZaman } = {}) {
  const dom = makeDomStub();
  const root = makeElement('div');
  const pgEl = makeElement('div');
  dom.__setEl('ovsync-root', root);
  dom.__setEl('pg-ovsync', pgEl);
  const getir = getirImpl
    ? async () => getirImpl()
    : async () => ({ veri: null });
  const { sandbox, window } = loadBrowserModule(UI, {
    dom,
    extra: {
      esc: escMirror, escAttr: escAttrMirror,
      getData: async () => [],
      getState: () => [],
      ovsyncTakipGetir: getir,
    },
  });
  return { sandbox, window, root, pgEl };
}

test('P5 DOM (i): bayrak_kapalı → açık mesaj "Ovsync/PG kuralları kapalı — takip verisi yok"', async () => {
  const { sandbox, root } = ovsyncSandboxu(() => ({ veri: { bayrak_kapali: true } }));
  await sandbox.loadOvsyncDash();
  assert.match(root.innerHTML, /Ovsync\/PG kuralları kapalı — takip verisi yok/);
});

test('P5 DOM (ii): bayat → etiket "çevrimdışı · HH:MM verisi" görünür', async () => {
  const zaman = new Date(2026, 8, 30, 14, 5).getTime();
  const { sandbox, root } = ovsyncSandboxu(() => ({ bayat: true, veri: { kpa: {} }, zaman }));
  await sandbox.loadOvsyncDash();
  assert.match(root.innerHTML, /çevrimdışı · 14:05 verisi/);
  assert.doesNotMatch(root.innerHTML, /İnternet yok/);
});

test('P5 DOM (iii): veri:null → açık mesaj "İnternet yok — takip verisi alınamadı"', async () => {
  const { sandbox, root } = ovsyncSandboxu(() => ({ bayat: true, veri: null }));
  await sandbox.loadOvsyncDash();
  assert.match(root.innerHTML, /İnternet yok — takip verisi alınamadı/);
});

test('P5 DOM (iii-b): getir throw eder → açık mesaj (çökmez, sessiz boş YASAK)', async () => {
  const { sandbox, root } = ovsyncSandboxu(() => { throw new Error('fetch kapalı'); });
  await sandbox.loadOvsyncDash();
  assert.match(root.innerHTML, /İnternet yok — takip verisi alınamadı/);
});

test('P5 DOM (iv): taze → P6 yer tutucusu (P6 işareti taşır; hata mesajı YOK)', async () => {
  const { sandbox, root } = ovsyncSandboxu(() => ({ veri: { bayrak_kapali: false, kpa: {} } }));
  await sandbox.loadOvsyncDash();
  assert.match(root.innerHTML, /P6/);
  assert.doesNotMatch(root.innerHTML, /İnternet yok/);
  assert.doesNotMatch(root.innerHTML, /kuralları kapalı/);
});

test('P5 DOM: §6b scroll geri yükleme — _ovsyncScrollY render sonrası uygulanır', async () => {
  const { sandbox, window, pgEl } = ovsyncSandboxu(() => ({ veri: { kpa: {} } }));
  window._ovsyncScrollY = 240;
  await sandbox.loadOvsyncDash();
  assert.equal(pgEl.scrollTop, 240);
});

test('P5 DOM: _ovsyncScrollY yokken scrollTop dokunulmaz; pg-ovsync eksikse çökmez', async () => {
  const { sandbox, pgEl } = ovsyncSandboxu(() => ({ veri: { kpa: {} } }));
  await sandbox.loadOvsyncDash();
  assert.equal(pgEl.scrollTop, undefined);
  // root/page olmayan sandbox: loadOvsyncDash sessiz dönmalı
  const bos = makeDomStub();
  const { sandbox: sb2 } = loadBrowserModule(UI, {
    dom: bos,
    extra: { esc: escMirror, escAttr: escAttrMirror, getData: async () => [], getState: () => [] },
  });
  await sb2.loadOvsyncDash(); // throw etmemeli
});

test('P5 DOM: gezinme durumu başlangıç değerleri — _curOvsyncPadok null, _curOvsyncBolum.acik obje', async () => {
  const { sandbox, window } = ovsyncSandboxu(() => ({ veri: { kpa: {} } }));
  await sandbox.loadOvsyncDash();
  assert.equal(window._curOvsyncPadok, null);
  assert.equal(typeof window._curOvsyncBolum, 'object');
  assert.equal(typeof window._curOvsyncBolum.acik, 'object');
});

// ── 3. Gezinme sözleşmesi (§6b; kaynak testleri) ─────────────────────
test('P5 gezinti: goTo zincirinde ovsync dalı + scroll kaydı (app.js)', () => {
  const app = fs.readFileSync(path.join(REPO, APP), 'utf8');
  assert.match(app, /pg === 'ovsync'/, 'goTo zincirinde ovsync dalı yok');
  assert.match(app, /loadOvsyncDash\(\)/, 'ovsync dalı loadOvsyncDash çağırmıyor');
  assert.match(app, /_ovsyncScrollY/, 'goTo ovsync scroll sözleşmesi (_ovsyncScrollY) yok');
});

test('P5 gezinti: index.html #pg-ovsync .pg bloğu + başlıkta ‹ geri (nav-geri)', () => {
  const src = fs.readFileSync(HTML, 'utf8');
  const bas = src.indexOf('<div id="pg-ovsync" class="pg">');
  assert.notEqual(bas, -1, '#pg-ovsync .pg bloğu index.html yok');
  const son = src.indexOf('</div><!-- /pages -->');
  assert.notEqual(son, -1, 'index.html /pages kapanışı bulunamadı');
  assert.ok(bas < son, '#pg-ovsync bloğu #pages İÇİNDE olmalı');
  const blok = src.slice(bas, son);
  assert.match(blok, /data-action="nav-geri"/, 'başlıkta nav-geri geri butonu yok');
  assert.doesNotMatch(blok, /goTo\('dash'\)/, 'R13 İHLALİ: pg-ovsync bloğunda goTo(dash) var');
  assert.doesNotMatch(blok, /<input[^>]+type="date"/, 'F4 kilidi: pg-ovsync native date input yasak');
});

test('P5 gezinti: R13 — nav-geri mevcut handler history.back; goTo(dash) YOK', () => {
  const handlers = fs.readFileSync(path.join(REPO, HANDLERS), 'utf8');
  assert.match(handlers, /'nav-geri':\s*\(\)\s*=>\s*navGeriDon\(\)/, 'nav-geri action kaydı yok');
  const geriKaynak = extractFunctionSource(HANDLERS, 'navGeriDon');
  assert.match(geriKaynak, /history\.back\(\)/, 'navGeriDon history.back kullanmıyor');
  assert.doesNotMatch(geriKaynak, /goTo\('dash'\)/, 'R13 İHLALİ: navGeriDon goTo(dash) çağırıyor');
});

test('P5 gezinti: alt-nav\'a giriş YOK (nb-ovsync yok)', () => {
  const src = fs.readFileSync(HTML, 'utf8');
  assert.doesNotMatch(src, /nb-ovsync/, 'alt-nav ovsync butonu olmamalı (§6b)');
});

test('P5 sınır: loadOvsyncDash renderOvsyncSayfa ÇAĞIRMAZ (render P6\'nın işi)', () => {
  const kaynak = extractFunctionSource(UI, 'loadOvsyncDash');
  assert.doesNotMatch(kaynak, /renderOvsyncSayfa\(/, 'P5 render implementasyonu içeremez (P6 sınırı)');
});
