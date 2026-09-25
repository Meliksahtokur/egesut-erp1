// tests/unit/erteleme-offline-ui.test.js — E6-UI (erteleme-genel S7):
// offline erteleme kapısı. Sahip kararı S7: navigator.onLine === false
// iken erteleme/kaydırma butonlarının TAMAMI gizli; yine tetiklenirse
// "İnternet yok — erteleme yapılamadı" toast + console kaydı; RPC ÇAĞRILMAZ.
// Tekrar-online olunca butonlar geri gelir (online/offline window olayları).
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const vm = require('node:vm');
const { extractFunctionSource, makeElement } = require('./support/loadModule.js');

const UI = 'js/ui.js';
const MSJ = 'İnternet yok — erteleme yapılamadı';

// escAttr aynası — test künyelerindeki id'ler sade (özel karakter yok)
const escAttrMirror = s => String(s);

// Sessiz console kayıt toplayıcısı — log VE warn ikisini de yakalar
// (kabul hem "console kaydı" hem plan 1c'in console.warn'ünü kapsar)
function konsolKayitci() {
  const kayit = [];
  const konsol = {
    log:   (...a) => kayit.push(['log', ...a]),
    warn:  (...a) => kayit.push(['warn', ...a]),
    error: () => {}, info: () => {}, debug: () => {},
  };
  return { kayit, konsol };
}

// E6 çekirdeğini (_ertelemeOnline + _ertelemeOfflineGuard) + istenen
// kardeş fonksiyonları taze vm ctx'e yükler (K8-5 izole-kardeş deseni).
function e6Yukle(isimler, ctxExtra) {
  const ctx = { Math, JSON, Number, parseInt, Date, ...ctxExtra };
  vm.createContext(ctx);
  for (const n of ['_ertelemeOnline', '_ertelemeOfflineGuard', ...isimler]) {
    vm.runInContext(extractFunctionSource(UI, n), ctx, { filename: `${UI}#${n}` });
  }
  return ctx;
}

test('E6-1: ertelemeBtnGuncelle — offline #cd-kaydir-btn VE [data-ertele] butonlarını gizler; online geri getirir', () => {
  const mkDoc = (cd, kart) => ({
    getElementById: id => (id === 'cd-kaydir-btn' ? cd : null),
    querySelectorAll: sel => (sel === '[data-ertele]' ? kart : []),
  });
  const cd = makeElement('button'); cd.style.display = 'block';
  const kartBtn = makeElement('button'); kartBtn.style.display = '';
  e6Yukle(['ertelemeBtnGuncelle'], { document: mkDoc(cd, [kartBtn]), navigator: { onLine: false } })
    .ertelemeBtnGuncelle();
  assert.strictEqual(cd.style.display, 'none', 'offline → #cd-kaydir-btn gizli');
  assert.strictEqual(kartBtn.style.display, 'none', 'offline → [data-ertele] kart butonu gizli');
  e6Yukle(['ertelemeBtnGuncelle'], { document: mkDoc(cd, [kartBtn]), navigator: { onLine: true } })
    .ertelemeBtnGuncelle();
  assert.strictEqual(cd.style.display, 'block', 'tekrar-online → #cd-kaydir-btn geri');
  assert.strictEqual(kartBtn.style.display, '', 'tekrar-online → kart butonu varsayılan görünürlük');
  // DOM'da buton yoksa çökmez
  assert.doesNotThrow(() => e6Yukle(['ertelemeBtnGuncelle'], {
    document: { getElementById: () => null, querySelectorAll: () => [] },
    navigator: { onLine: false },
  }).ertelemeBtnGuncelle());
});

test('E6-2: _erteleBtnHtml — offline buton ÜRETİLMEZ; online data-ertele rozetiyle üretilir', () => {
  const t = { id: 'g1', gorev_tipi: 'TOHUMLAMA_PLANLI', tamamlandi: false, iptal: false };
  // E1-UI sonrası buton kural cache'den karar verir — kural kardeşi ctx'e veriliyor
  const kuralCtx = { ertelemeKuralGetir: tip => (tip === 'TOHUMLAMA_PLANLI' ? { ertelenebilir: true, pencere_kurali: 'tohumlama' } : null) };
  const offline = e6Yukle(['_erteleBtnHtml'], { navigator: { onLine: false }, escAttr: escAttrMirror, ...kuralCtx })._erteleBtnHtml;
  assert.strictEqual(offline(t), '', 'offline → kart HTML üretiminde buton YOK');
  const online = e6Yukle(['_erteleBtnHtml'], { navigator: { onLine: true }, escAttr: escAttrMirror, ...kuralCtx })._erteleBtnHtml;
  const html = online(t);
  assert.ok(html.includes('🗓️ Ertele'), 'online → buton üretilir');
  assert.ok(html.includes('data-ertele'), 'canlı-DOM görünürlük güncellemesi için rozet taşır');
  assert.ok(html.includes('_erteleModal'), 'modal açışına kablolu');
  // mevcut durum kilidi korunur (tip kilidi E1-UI ile kural cache'e taşındı —
  // TEDAVI_GUN/kayıtsız tip butonsuz davranışı orada ayrıca kilitli)
  assert.strictEqual(online({ ...t, tamamlandi: true }), '', 'tamamlanmış görevde butonsuz');
  assert.strictEqual(online({ ...t, iptal: true }), '', 'iptal görevde butonsuz');
});

test('E6-3: caseKalanGunleriKaydir(1) offline — RPC ÇAĞRILMAZ + birleşik toast + console kaydı', async () => {
  const cagri = [], toastlar = [];
  const { kayit, konsol } = konsolKayitci();
  const r = e6Yukle(['caseKalanGunleriKaydir'], {
    console: konsol,
    navigator: { onLine: false },
    rpc: async (...a) => { cagri.push(a); return { ok: true }; },
    toast: (m, e) => toastlar.push({ m, e }),
    document: { getElementById: () => null },
    _curCase: { id: 'c1', status: 'active' },
  }).caseKalanGunleriKaydir;
  await r(1);
  assert.strictEqual(cagri.length, 0, 'offline: vaka_kalan_gunleri_kaydir RPC ÇAĞRILMAZ');
  const hata = toastlar.find(t => t.e);
  assert.ok(hata, 'hata toast var');
  assert.strictEqual(hata.m, MSJ, 'birleşik mesaj: ' + hata.m);
  assert.ok(!toastlar.some(t => !t.e), 'başarı toast yok');
  assert.ok(kayit.some(k => String(k[1] || '').includes('offline')), 'console kaydı atıldı: ' + JSON.stringify(kayit));
});

test('E6-4: _erteleModal offline — modal DOM üretilmez, veri okunmaz, toast verilir', async () => {
  const toastlar = [], olusan = [];
  let veriOkundu = 0;
  const { kayit, konsol } = konsolKayitci();
  const m = e6Yukle(['_erteleModal'], {
    console: konsol,
    navigator: { onLine: false },
    document: {
      getElementById: () => null,
      createElement: tag => { olusan.push(tag); return makeElement(tag); },
      body: makeElement('body'),
    },
    toast: (msg, e) => toastlar.push({ msg, e }),
    getData: async () => { veriOkundu++; return []; },
    history: { pushState() {}, back() {} },
  })._erteleModal;
  m('g1');
  await new Promise(r => setTimeout(r, 15));   // async IIFE yarışı için bekle
  assert.ok(toastlar.some(t => t.e && t.msg === MSJ), 'birleşik offline toast');
  assert.strictEqual(veriOkundu, 0, 'offline: gorev_log verisi okunmaz (guard girişte)');
  assert.strictEqual(olusan.length, 0, 'offline: modal DOM üretilmez');
});

test('E6-5: _erteleKaydet offline — modal açıkken bağlantı düşmüşse Ertele RPC ye ulaşmaz', async () => {
  const cagri = [], toastlar = [];
  const { konsol } = konsolKayitci();
  const tarihInput = makeElement('input'); tarihInput.value = '05.10.2026';
  const saatInput = makeElement('input'); saatInput.value = '09:00';
  const k = e6Yukle(['_erteleKaydet'], {
    console: konsol,
    navigator: { onLine: false },
    document: { getElementById: id => (id === 'ert-tarih' ? tarihInput : id === 'ert-saat' ? saatInput : null) },
    rpc: async (...a) => { cagri.push(a); return { hedef_tarih: '2026-10-05' }; },
    toast: (m, e) => toastlar.push({ m, e }),
    _ovsyncTarihOku: v => { const m2 = /^(\d{2})\.(\d{2})\.(\d{4})$/.exec(String(v || '').trim()); return m2 ? `${m2[3]}-${m2[2]}-${m2[1]}` : null; },
    getUserMessage: e => String(e?.message || e),
    fmtTarih: s => s,
    loadTasks: async () => {},
    _erteleKapat: () => {},
  })._erteleKaydet;
  await k('g1');
  assert.strictEqual(cagri.length, 0, 'offline: tohumlama_gorev_ertele RPC ÇAĞRILMAZ');
  assert.ok(toastlar.some(t => t.e && t.m === MSJ), 'birleşik offline toast (geçmiş-tarih/tarih-biçim toast u değil)');
});

test('E6-6: kablolama — tek yardımcı + iki olay dinleyicisi; dört giriş noktası guard lı; mesaj tek yerde', () => {
  const src = fs.readFileSync(UI, 'utf8');
  assert.ok(/\bwindow\.addEventListener\('online',\s*\(\)\s*=>\s*ertelemeBtnGuncelle\(\)\)/.test(src),
    'online olayı tek yardımcıya bağlı');
  assert.ok(/\bwindow\.addEventListener\('offline',\s*\(\)\s*=>\s*ertelemeBtnGuncelle\(\)\)/.test(src),
    'offline olayı tek yardımcıya bağlı');
  assert.ok(!src.includes('function cdKaydirBtnGuncelle'), 'E0 özel isimli kopya kalmadı (kalıp genelleşti)');
  for (const ad of ['cdKaydirAc', 'caseKalanGunleriKaydir', '_erteleModal', '_erteleKaydet']) {
    assert.ok(extractFunctionSource(UI, ad).includes('_ertelemeOfflineGuard('),
      `${ad} giriş guard ı taşıyor (RPC ye ulaşmadan erken çıkış)`);
  }
  const adet = (src.match(/İnternet yok — erteleme yapılamadı/g) || []).length;
  assert.strictEqual(adet, 1, 'birleşik mesaj yalnız guard içinde (kopya-yapıştır yok)');
  const ocd = src.slice(src.indexOf('async function openCaseDet'), src.indexOf('function fmtGunSaat'));
  assert.ok(ocd.includes('ertelemeBtnGuncelle()'), 'openCaseDet açılışta görünürlüğü kurar');
});
