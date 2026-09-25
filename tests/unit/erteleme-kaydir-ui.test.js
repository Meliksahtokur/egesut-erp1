// tests/unit/erteleme-kaydir-ui.test.js — E0-UI (erteleme-genel S5):
// "Kalan günleri kaydır" butonu + vaka_kalan_gunleri_kaydir RPC kablolaması.
// Buton online-only: offline'da gizli; yine tetiklenirse toast + RPC ÇAĞRILMAZ.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const vm = require('node:vm');
const { loadExtractedFunction, extractFunctionSource, makeElement } = require('./support/loadModule.js');

// fmtTarih aynası (js/utils/helpers.js:18 — ISO→DD.MM.YYYY)
const fmtTarihMirror = (iso) => { if (!iso) return '—'; const p = iso.slice(0, 10).split('-'); return p.length === 3 ? `${p[2]}.${p[1]}.${p[0]}` : iso; };

// extract + değerlendir — çağrılan fonksiyonun globals'ı test verir (K8-5 deseni).
// E6 sonrası görünürlük fonksiyonu _ertelemeOnline kardeşine başvurur —
// her extract'ta kardeşi de ctx'e koy (bağımlılık yüklemesi).
function kaydirFn(name, ctxExtra) {
  const src = extractFunctionSource('js/ui.js', name);
  const ctx = { console, Math, JSON, Number, parseInt, ...ctxExtra };
  vm.createContext(ctx);
  if (name === 'ertelemeBtnGuncelle') {
    vm.runInContext(extractFunctionSource('js/ui.js', '_ertelemeOnline'), ctx, { filename: 'js/ui.js#_ertelemeOnline' });
  }
  return vm.runInContext(`(${src})`, ctx, { filename: `js/ui.js#${name}` });
}

// Akış fonksiyonu kardeşleriyle birlikte yükler (akor: özet + hata üreticileri
// aynı modül-scope'tan gelir; izole ctx'te elle deklare edilir; E6 sonrası
// offline guard kardeşleri de akışın girişinde gereklidir)
function kaydirAkisFn(ctxExtra) {
  const ctx = { console, Math, JSON, Number, parseInt, ...ctxExtra };
  vm.createContext(ctx);
  vm.runInContext(extractFunctionSource('js/ui.js', '_kaydirOzetMetni'), ctx, { filename: 'js/ui.js#_kaydirOzetMetni' });
  vm.runInContext(extractFunctionSource('js/ui.js', '_kaydirHataMesaj'), ctx, { filename: 'js/ui.js#_kaydirHataMesaj' });
  vm.runInContext(extractFunctionSource('js/ui.js', '_ertelemeOnline'), ctx, { filename: 'js/ui.js#_ertelemeOnline' });
  vm.runInContext(extractFunctionSource('js/ui.js', '_ertelemeOfflineGuard'), ctx, { filename: 'js/ui.js#_ertelemeOfflineGuard' });
  vm.runInContext(extractFunctionSource('js/ui.js', 'caseKalanGunleriKaydir'), ctx, { filename: 'js/ui.js#caseKalanGunleriKaydir' });
  return ctx.caseKalanGunleriKaydir;
}

test('E0-UI-1: sheet — +1/+2/+3 hızlı butonları (data-gun) + özel mini-form', () => {
  const html = loadExtractedFunction('js/ui.js', 'cdKaydirSheetHtml')();
  assert.match(html, /Kalan Günleri Kaydır/, 'başlık');
  for (const n of [1, 2, 3]) {
    assert.ok(html.includes(`data-gun="${n}"`), `+${n} hızlı butonu data-gun="${n}" taşır`);
    assert.ok(html.includes(`caseKalanGunleriKaydir(${n})`), `+${n} butonu RPC akışını tetikler`);
  }
  assert.ok(html.includes('id="kaydir-ozel-input"'), 'özel gün sayısı inputu');
  assert.ok(html.includes('min="1"'), 'özel input alt sınırı 1 (tek yönlü ileri)');
  assert.ok(html.includes('cdKaydirOzelUygula'), 'özel uygula butonu');
  assert.ok(html.includes("getElementById('kaydir-modal').remove()"), 'vazgeç butonu sayfayı kapatır');
});

test('E0-UI-2: index.html — buton cd-gun-bolum içinde (aktif-vaka alanı), onclick kablolu', () => {
  const html = fs.readFileSync('index.html', 'utf8');
  const bolum = html.slice(html.indexOf('id="cd-gun-bolum"'), html.indexOf('id="cd-kapat-bolum"'));
  assert.ok(bolum.length > 0, 'cd-gun-bolum .. cd-kapat-bolum dilimi bulundu');
  assert.ok(bolum.includes('id="cd-kaydir-btn"'), 'buton cd-gun-bolum içinde (yalnız aktif vakada görünür)');
  assert.ok(bolum.includes('onclick="cdKaydirAc()"'), 'statik onclick deseni');
});

test('E0-UI-3: görünürlük — offline gizler, online gösterir; openCaseDet açılışta kurar (E6: ertelemeBtnGuncelle)', () => {
  const el = makeElement('button');
  el.style.display = 'block';
  const doc = { getElementById: id => (id === 'cd-kaydir-btn' ? el : null), querySelectorAll: () => [] };
  const gizle = kaydirFn('ertelemeBtnGuncelle', { document: doc, navigator: { onLine: false } });
  gizle();
  assert.strictEqual(el.style.display, 'none', 'offline → gizli');
  const goster = kaydirFn('ertelemeBtnGuncelle', { document: doc, navigator: { onLine: true } });
  goster();
  assert.strictEqual(el.style.display, 'block', 'online → görünür');
  // buton DOM'da yoksa çökmez
  kaydirFn('ertelemeBtnGuncelle', { document: { getElementById: () => null, querySelectorAll: () => [] }, navigator: { onLine: false } })();
  // kablolama: openCaseDet görünürlüğü kurar + online/offline olayları dinler
  const src = fs.readFileSync('js/ui.js', 'utf8');
  const ocd = src.slice(src.indexOf('async function openCaseDet'), src.indexOf('function fmtGunSaat'));
  assert.ok(ocd.includes('ertelemeBtnGuncelle()'), 'openCaseDet açılışta görünürlüğü kurar');
  assert.ok(src.includes("window.addEventListener('offline'") && src.includes("window.addEventListener('online'"),
    'online/offline olaylarında görünürlük canlı güncellenir');
});

test('E0-UI-4: offline stub — RPC çağrılmaz, "İnternet yok" toast', async () => {
  const cagri = [], toastlar = [];
  const sessizKonsol = { log() {}, warn() {}, error() {}, info() {}, debug() {} };   // E6 guard logunu sustur
  const r = kaydirAkisFn({
    console: sessizKonsol,
    navigator: { onLine: false },
    rpc: async (...a) => { cagri.push(a); return { ok: true }; },
    toast: (m, e) => toastlar.push({ m, e }),
    document: { getElementById: () => null },
    _curCase: { id: 'c1', status: 'active' },
    pullTables: async () => {}, renderCaseTimeline: async () => {}, _updateKapatBtn: async () => {},
    fmtTarih: fmtTarihMirror,
  });
  await r(2);
  assert.strictEqual(cagri.length, 0, 'offline: RPC ÇAĞRILMAZ');
  assert.ok(toastlar.some(t => t.e && t.m.includes('İnternet yok')), 'İnternet yok hata toast');
  assert.ok(!toastlar.some(t => !t.e), 'başarı toast yok');
});

test('E0-UI-5: RPC kablolama — doğru argümanlar + özet toast + tazeleme zinciri', async () => {
  const cagri = [], toastlar = [], tazelendi = [];
  const r = kaydirAkisFn({
    navigator: { onLine: true },
    rpc: async (name, params) => {
      cagri.push({ name, params });
      return { ok: true, case_id: 'c1', gun: 2,
               tasinan_gun_satiri: 5, tasinan_gorev: 3, tasinan_seans: 4,
               tasinan_uygulama_satiri: 6, tai: 1,
               ilk_tarih: '2026-09-27', son_tarih: '2026-10-03' };
    },
    toast: (m, e) => toastlar.push({ m, e }),
    document: { getElementById: () => null },
    _curCase: { id: 'c1', status: 'active' },
    pullTables: async (t) => { tazelendi.push(Array.isArray(t) ? t.join(',') : t); },
    renderCaseTimeline: async (id) => { tazelendi.push('tl:' + id); },
    _updateKapatBtn: async (id) => { tazelendi.push('kapat:' + id); },
    fmtTarih: fmtTarihMirror,
  });
  await r(2);
  assert.strictEqual(cagri.length, 1, 'tek RPC çağrısı');
  assert.strictEqual(cagri[0].name, 'vaka_kalan_gunleri_kaydir');
  assert.deepStrictEqual(JSON.parse(JSON.stringify(cagri[0].params)), { p_case_id: 'c1', p_gun: 2 },
    'p_case_id + p_gun argümanları');   // JSON köprüsü: vm-realm prototip farkı deepStrictEqual'ı düşürür
  const ozet = toastlar.find(t => !t.e);
  assert.ok(ozet, 'başarı toast var');
  assert.ok(ozet.m.includes('+2 gün') && ozet.m.includes('5 gün satırı') && ozet.m.includes('1 tohumlama'),
    'özet taşınan sayıları taşır: ' + ozet.m);
  assert.ok(tazelendi.some(x => x.includes('treatment_days') && x.includes('gorev_log')), 'pullTables tazeleme');
  assert.ok(tazelendi.includes('tl:c1') && tazelendi.includes('kapat:c1'), 'timeline + kapat butonu yenilenir');
});

test('E0-UI-5b: guard\'lar — geçersiz gün / kapalı vaka RPC\'ye ulaşmaz', async () => {
  const cagri = [], toastlar = [];
  const mkCtx = (curCase) => ({
    navigator: { onLine: true },
    rpc: async (name, params) => { cagri.push({ name, params }); return { ok: true }; },
    toast: (m, e) => toastlar.push({ m, e }),
    document: { getElementById: () => null },
    _curCase: curCase,
    pullTables: async () => {}, renderCaseTimeline: async () => {}, _updateKapatBtn: async () => {},
    fmtTarih: fmtTarihMirror,
  });
  await kaydirAkisFn(mkCtx({ id: 'c1', status: 'active' }))(0);
  await kaydirAkisFn(mkCtx({ id: 'c1', status: 'active' }))('');
  await kaydirAkisFn(mkCtx({ id: 'c1', status: 'closed' }))(2);
  await kaydirAkisFn(mkCtx(null))(2);
  assert.strictEqual(cagri.length, 0, 'hiçbiri RPC\'ye ulaşmaz');
  assert.ok(toastlar.some(t => t.m.includes('Geçerli bir gün')), 'geçersiz gün toast');
  assert.ok(toastlar.some(t => t.m.includes('aktif vaka')), 'kapalı vaka toast');
});

test('E0-UI-6: hata çevirisi — VAKA_KAYDIRILAMAZ ailesi Türkçe; hata akışı toast\'a düşer', () => {
  const h = loadExtractedFunction('js/ui.js', '_kaydirHataMesaj');
  assert.match(h('VAKA_KAYDIRILAMAZ:{"case_id":"c1","gun":2,"sebep":"VAKA_ACIK_DEGIL","status":"closed"}'), /Vaka açık değil/);
  assert.match(h('VAKA_KAYDIRILAMAZ:{"sebep":"GECERSIZ_GUN"}'), /Geçersiz gün/);
  assert.match(h('VAKA_KAYDIRILAMAZ:{"sebep":"VAKA_BULUNAMADI"}'), /Vaka bulunamadı/);
  assert.match(h('GECMIS_TARIH:{"gorev_id":"g1"}'), /geçmişe/);
  assert.match(h('GOREV_ERTELENEMEZ:{"sebep":"TIP_UYGUN_DEGIL"}'), /ertelenemedi/);
  assert.strictEqual(h('başka bir hata'), 'başka bir hata', 'bilinmeyen mesaj olduğu gibi kalır');
  assert.strictEqual(h(''), '', 'boş mesaj çökmez');
  assert.match(h('VAKA_KAYDIRILAMAZ:bu-json-degil'), /VAKA_KAYDIRILAMAZ/, 'bozuk JSON ham düşer');
  // akış: RPC hata fırlatırsa çevrilmiş mesaj hata toast olur
  const toastlar = [];
  const r = kaydirAkisFn({
    navigator: { onLine: true },
    rpc: async () => { throw new Error('VAKA_KAYDIRILAMAZ:{"sebep":"VAKA_ACIK_DEGIL","status":"closed"}'); },
    toast: (m, e) => toastlar.push({ m, e }),
    document: { getElementById: () => null },
    _curCase: { id: 'c1', status: 'active' },
    pullTables: async () => {}, renderCaseTimeline: async () => {}, _updateKapatBtn: async () => {},
    fmtTarih: fmtTarihMirror,
  });
  return r(2).then(() => {
    assert.ok(toastlar.some(t => t.e && t.m.includes('Vaka açık değil') && !t.m.includes('VAKA_KAYDIRILAMAZ')),
      'hata toast Türkçe, ham kod değil: ' + JSON.stringify(toastlar));
  });
});

test('E0-UI-7: özet metni — sayılar + tarih aralığı; sıfırlar listelenmez; boş sonuç ayrı mesaj', () => {
  const ozet = loadExtractedFunction('js/ui.js', '_kaydirOzetMetni', { extra: { fmtTarih: fmtTarihMirror } });
  const m = ozet({ gun: 3, tasinan_gun_satiri: 2, tasinan_gorev: 1, tasinan_seans: 0,
                   tasinan_uygulama_satiri: 4, tai: 1, ilk_tarih: '2026-09-28', son_tarih: '2026-10-05' });
  assert.ok(m.includes('+3 gün'), 'kaydırma miktarı');
  assert.ok(m.includes('2 gün satırı') && m.includes('1 görev') && m.includes('4 seans planı') && m.includes('1 tohumlama'),
    'dolu sayılar listelenir');
  assert.ok(!m.includes('0 seans'), 'sıfır kalem listelenmez');
  assert.ok(m.includes('28.09.2026') && m.includes('05.10.2026'), 'yeni tarih aralığı insan dilinde');
  assert.match(ozet({ gun: 1, tasinan_gun_satiri: 0, tasinan_gorev: 0, tasinan_seans: 0,
                      tasinan_uygulama_satiri: 0, tai: 0 }), /açık kalem/i, 'hepsi sıfır: ayrı mesaj');
  assert.doesNotThrow(() => ozet(null), 'null sonuç çökmez');
});
