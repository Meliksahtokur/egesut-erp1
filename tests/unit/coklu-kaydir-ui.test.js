// tests/unit/coklu-kaydir-ui.test.js — F1 Task 2 (coklu-kaydirma):
// apiCokluKaydir RPC yardımcısı (js/api.js) + vaka_kalan_gunleri_kaydir_coklu
// pull seti (RPC_TABLES). Yardımcı online-only: offline RPC_MAP'e girmez
// (vaka_toplu_ac gerekçe kalıbı). Task 3/4 bu dosyaya UI testlerini ekler.
'use strict';
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const vm = require('node:vm');
const { extractFunctionSource, loadBrowserModule, makeStorage, makeElement, makeDomStub } = require('./support/loadModule.js');
const { fmtTarih } = require('../../js/utils/helpers.js');

// RPC_TABLES const'u cerrahi çıkarır (extractFunctionSource yalnız function
// bildirimi keser; const objesi için kaynak dilimleme + vm değerlendirme).
function rpcTables() {
  const src = fs.readFileSync('js/api.js', 'utf8');
  const start = src.indexOf('const RPC_TABLES = {');
  assert.ok(start !== -1, 'RPC_TABLES bildirimi api.js\'te bulunamadı');
  const end = src.indexOf('\n};', start);
  assert.ok(end !== -1, 'RPC_TABLES kapanışı bulunamadı');
  const objSrc = src.slice(src.indexOf('{', start), end + 2); // son ';' hariç — (obj) ifadesi geçerli kalsın
  const ctx = {};
  vm.createContext(ctx);
  return vm.runInContext(`(${objSrc})`, ctx, { filename: 'js/api.js#RPC_TABLES' });
}

// apiCokluKaydir'i izole ctx'te yükler; rpc mock'u çağrıları kaydeder
// (erteleme-kaydir-ui.test.js kaydirAkisFn deseni).
function apiCokluKaydirFn(rpcMock) {
  const src = extractFunctionSource('js/api.js', 'apiCokluKaydir');
  const ctx = { console, rpc: rpcMock };
  vm.createContext(ctx);
  return vm.runInContext(`(${src})`, ctx, { filename: 'js/api.js#apiCokluKaydir' });
}

test('F1-API-1: pull seti tanimli — coklu kaydir RPC_TABLES girisi', () => {
  // JSON köprüsü: vm-realm Array prototip farkı deepStrictEqual'i düşürür
  assert.deepStrictEqual(JSON.parse(JSON.stringify(rpcTables()['vaka_kalan_gunleri_kaydir_coklu'])),
    ['gorev_log', 'treatment_days', 'treatment_day_uygulamalar', 'islem_log']);
});

test('F1-API-2: parametre sirasi dogru — named args + sonuc aynen doner', async () => {
  const cagri = [];
  const sonucGövde = { ok: true, toplam: 2, kaydirilan: 2, atlanan: [], hatalar: [], detaylar: [] };
  const fn = apiCokluKaydirFn(async (name, params) => {
    cagri.push({ name, params });
    return sonucGövde;
  });
  const res = await fn(['g1', 'g2'], 3);
  assert.strictEqual(cagri.length, 1, 'tek RPC çağrısı');
  assert.strictEqual(cagri[0].name, 'vaka_kalan_gunleri_kaydir_coklu');
  assert.deepStrictEqual(JSON.parse(JSON.stringify(cagri[0].params)),
    { p_gorev_ids: ['g1', 'g2'], p_gun: 3 },
    'p_gorev_ids + p_gun named args (vm-realm prototip farkı için JSON köprüsü)');
  assert.deepStrictEqual(res, sonucGövde, 'RPC gövdesi çağırana aynen döner');
});

test('F1-API-3: guard — boş/geçersiz liste ve gün RPC\'ye ulaşmaz', async () => {
  const cagri = [];
  const fn = apiCokluKaydirFn(async (name, params) => { cagri.push({ name, params }); return { ok: true }; });
  await assert.rejects(() => fn([], 3), 'boş liste reddedilir');
  await assert.rejects(() => fn('g1', 3), 'dizi olmayan liste reddedilir');
  await assert.rejects(() => fn(['g1'], 0), '0 gün reddedilir');
  await assert.rejects(() => fn(['g1'], 1.5), 'kesirli gün reddedilir');
  assert.strictEqual(cagri.length, 0, 'hiçbiri RPC\'ye ulaşmaz');
});

// ═══════════════════════════════════════════════════════════════════════════
// Task 3: çoklu-seçim checkbox + kaydırma çubuğu (js/ui.js)
// Tam modül sandbox'ı (buzagi-gorev-modal.test.js deseni) — renderTask + seçim
// fonksiyonları gerçek kaynak üstünde koşar; esc/escAttr aynaları, fmtTarih,
// sessionStorage stub ve getState stub enjekte edilir.
// ═══════════════════════════════════════════════════════════════════════════
const escT3 = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const escAttrT3 = (s) => String(s ?? '')
  .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
  .replace(/</g, '&lt;').replace(/>/g, '&gt;');

const T3 = loadBrowserModule('js/ui.js', {
  extra: { esc: escT3, escAttr: escAttrT3, fmtTarih, sessionStorage: makeStorage() },
});
T3.sandbox.getState = () => [];   // renderTask hayvan/erteleme-kural aramaları boş sürü okur

// Test izolasyonu: seçim Set'i + storage + navigator + bar DOM'u sıfırla
function t3reset() {
  T3.sandbox.window._ckSecilenGorevler = new Set();
  T3.sandbox.sessionStorage = makeStorage();
  T3.sandbox.navigator = { userAgent: 'node-test', onLine: true };
  T3.sandbox.document = makeDomStub();
  T3.sandbox.rpc = async () => { throw new Error('Task 3\'te RPC çağrısı YOK'); };
}

// Açık TEDAVI_GUN görevi (aciklama JSON day_id'li — RPC çözümleme formatı)
function gunTask(opts = {}) {
  return {
    id: opts.id || 'gungorev-1',
    gorev_tipi: opts.tip || 'TEDAVI_GUN',
    tamamlandi: !!opts.done,
    iptal: !!opts.iptal,
    hedef_tarih: '2026-10-01',
    hayvan_id: 'hayvan-1',
    aciklama: JSON.stringify({ day_id: 'day-1', label: 'Gün 1', planned_time: '' }),
  };
}

test('F1-T3-a: açık TEDAVI_GUN/TEDAVI_SEANS kartında checkbox var — dataset deseni, id interpolasyonu yok; ILAC\'ta yok', () => {
  t3reset();
  const html = T3.sandbox.renderTask(gunTask());
  assert.ok(html.includes('class="task-sec-kutu"'), 'checkbox çizilir');
  assert.ok(html.includes('data-gorev-id="gungorev-1"'), 'görev id dataset attribute\'ta (escAttr\'li)');
  assert.ok(html.includes('this.dataset.gorevId'), 'onclick dataset üzerinden okur');
  assert.ok(!html.includes("_cokluSecimToggle('gungorev-1"), 'id inline-handler\'a interpolasyon YASAK');
  const seansHtml = T3.sandbox.renderTask(gunTask({ id: 'seansgorev-2', tip: 'TEDAVI_SEANS' }));
  assert.ok(seansHtml.includes('class="task-sec-kutu"'), 'TEDAVI_SEANS kartında da checkbox');
  const ilacHtml = T3.sandbox.renderTask(gunTask({ id: 'ilacgorev-3', tip: 'ILAC' }));
  assert.ok(!ilacHtml.includes('task-sec-kutu'), 'ILAC kartında checkbox YOK (fail-closed)');
});

test('F1-T3-b: tamamlanmış / iptal görevde checkbox YOK', () => {
  t3reset();
  assert.ok(!T3.sandbox.renderTask(gunTask({ done: true })).includes('task-sec-kutu'), 'tamamlanmışta yok');
  assert.ok(!T3.sandbox.renderTask(gunTask({ iptal: true })).includes('task-sec-kutu'), 'iptalde yok');
});

test('F1-T3-c: toggle Set\'i günceller; _cokluSecimBarGuncelle sayacı "N görev seçili" yazar ve çubuğu görünür kılar', () => {
  t3reset();
  const doc = T3.sandbox.document;
  const bar = doc.__setEl('k-coklu-bar', makeElement('div'));
  const sayac = doc.__setEl('k-coklu-sayac', makeElement('span'));
  const sb = T3.sandbox;
  sb._cokluSecimToggle('g1', true);
  sb._cokluSecimToggle('g2', true);
  assert.ok(sb.window._ckSecilenGorevler.has('g1') && sb.window._ckSecilenGorevler.has('g2'), 'Set her ikisini tutar');
  sb._cokluSecimBarGuncelle();
  assert.strictEqual(sayac.textContent, '2 görev seçili', 'sayaç metni');
  assert.strictEqual(bar.hidden, false, '≥1 seçimde çubuk görünür');
  assert.strictEqual(bar.style.display, 'flex', 'display:none kalkar');
  sb._cokluSecimToggle('g2', false);
  sb._cokluSecimBarGuncelle();
  assert.ok(!sb.window._ckSecilenGorevler.has('g2'), 'unchecked Set\'ten düşer');
  assert.strictEqual(sayac.textContent, '1 görev seçili', 'sayaç geriler');
  sb._cokluSecimToggle('g1', false);
  sb._cokluSecimBarGuncelle();
  assert.strictEqual(bar.hidden, true, '0 seçimde çubuk gizli');
  assert.strictEqual(bar.style.display, 'none', 'display:none geri gelir');
});

test('F1-T3-d: offline — çubuk hidden, RPC çağrısı YOK; online\'a dönüşte çubuk canlı açılır', () => {
  t3reset();
  const doc = T3.sandbox.document;
  const bar = doc.__setEl('k-coklu-bar', makeElement('div'));
  doc.__setEl('k-coklu-sayac', makeElement('span'));
  const cagri = [];
  T3.sandbox.rpc = async (...a) => { cagri.push(a); return { ok: true }; };
  T3.sandbox.navigator = { userAgent: 'node-test', onLine: false };
  T3.sandbox._cokluSecimToggle('g1', true);   // toggle + bar guncelle offline koşar
  T3.sandbox._cokluSecimBarGuncelle();
  assert.strictEqual(bar.hidden, true, 'offline → çubuk gizli');
  assert.strictEqual(bar.style.display, 'none', 'offline → display none');
  assert.strictEqual(cagri.length, 0, 'offline: RPC ÇAĞRILMAZ');
  T3.sandbox.navigator = { userAgent: 'node-test', onLine: true };
  T3.sandbox._cokluSecimBarGuncelle();
  assert.strictEqual(bar.hidden, false, 'online dönüşü → çubuk görünür');
  assert.strictEqual(cagri.length, 0, 'bar güncellemesi asla RPC tetiklemez');
});

test('F1-T3-e: kalıcılık — sessionStorage senkronu, tab-geçişi geri yükleme, temizle birlikte boşaltır', () => {
  t3reset();
  const sb = T3.sandbox;
  sb._cokluSecimYukle();
  sb._cokluSecimToggle('ga', true);
  sb._cokluSecimToggle('gb', true);
  const ham = sb.sessionStorage.getItem('ege_coklu_secim');
  assert.deepStrictEqual(JSON.parse(ham).sort(), ['ga', 'gb'], 'toggle sonrası storage güncel');
  // tab geçişi simülasyonu: Set sıfırlanır (storage dokunulmaz), _cokluSecimYukle geri getirir
  sb.window._ckSecilenGorevler = new Set();
  sb._cokluSecimYukle();
  assert.ok(sb.window._ckSecilenGorevler.has('ga') && sb.window._ckSecilenGorevler.has('gb'), 'seçimler geri döner');
  // temizle: Set + storage birlikte boşalır
  sb._cokluSecimTemizle();
  assert.strictEqual(sb.window._ckSecilenGorevler.size, 0, 'temizle Set\'i boşaltır');
  assert.deepStrictEqual(JSON.parse(sb.sessionStorage.getItem('ege_coklu_secim')), [], 'temizle storage\'ı da boşaltır');
  // bozuk storage verisi çökmez, boş Set ile açılır
  sb.sessionStorage.setItem('ege_coklu_secim', '{{bozuk');
  assert.doesNotThrow(() => sb._cokluSecimYukle());
  assert.strictEqual(sb.window._ckSecilenGorevler.size, 0, 'bozuk JSON → boş Set (fail-closed)');
});

test('F1-T3-f: çubuk markup — SPEC §4 birebir (sayacı, chip 1·2·3·7, gün girişi 1-31, onay, temizle)', () => {
  t3reset();
  const bar = T3.sandbox._cokluSecimBarHtml();
  for (const id of ['k-coklu-bar', 'k-coklu-sayac', 'k-coklu-gun', 'k-coklu-onayla', 'k-coklu-temizle']) {
    assert.ok(bar.includes(`id="${id}"`), `çubuk id: ${id}`);
  }
  assert.ok(bar.includes('görev seçili'), 'sayaç etiketi');
  for (const n of [1, 2, 3, 7]) {
    assert.ok(bar.includes(`data-gun="${n}"`), `hızlı chip +${n} (data-gun)`);
  }
  assert.ok(bar.includes('_cokluSecimGunDoldur(this.dataset.gun)'), 'chip tıkı dataset ile günü doldurur');
  assert.ok(bar.includes('type="number"') && bar.includes('min="1"') && bar.includes('max="31"'), 'sayı girişi 1-31 (RPC guard aynası)');
  assert.ok(bar.includes('_cokluSecimTemizle()'), 'temizle butonu seçim temizliğini tetikler');
  assert.ok(bar.includes('hidden'), 'başlangıçta gizli doğar');
});

test('F1-T3-g: chip tıkı k-coklu-gun değerini doldurur', () => {
  t3reset();
  const girdi = T3.sandbox.document.__setEl('k-coklu-gun', makeElement('input'));
  T3.sandbox._cokluSecimGunDoldur('3');
  assert.strictEqual(girdi.value, '3', 'chip değeri girişe yazılır');
});

test('F1-T3-h: kablolama — loadTasks her render\'da _cokluSecimYukle + çubuk çizer/günceller; renderTask checkbox dalını çağırır', () => {
  const src = require('node:fs').readFileSync('js/ui.js', 'utf8');
  const ltBas = src.indexOf('async function loadTasks');
  const ltSon = src.indexOf('// B34:', ltBas);
  assert.ok(ltBas !== -1 && ltSon > ltBas, 'loadTasks bloğu bulunur');
  const lt = src.slice(ltBas, ltSon);
  assert.ok(lt.includes('_cokluSecimYukle()'), 'her görev-listesi render\'ı seçimleri geri yükler');
  assert.ok(lt.includes('_cokluSecimBarHtml()'), 'çubuk görev listesi başında üretilir');
  assert.ok(lt.includes("getElementById('k-coklu-bar')"), 'statik konteyner (Task 5) varsa dinamik çubuk çizilmez');
  assert.ok(lt.includes('_cokluSecimBarGuncelle()'), 'render sonrası sayaç/görünürlük senkronlanır');
  const rtBas = src.indexOf('function renderTask');
  const rtSon = src.indexOf('// Görev listesi: hayvan+gün seans grubu ayracı', rtBas);
  const rt = src.slice(rtBas, rtSon);
  assert.ok(rt.includes('_cokluSecimKutuHtml(t)'), 'renderTask checkbox yardımcısını çağırır');
});

