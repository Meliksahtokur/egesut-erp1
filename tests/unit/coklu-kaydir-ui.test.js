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

test('F1-T3-a: açık TEDAVI_GUN kartında checkbox var — dataset deseni, id interpolasyonu yok; ILAC\'ta yok', () => {
  t3reset();
  const html = T3.sandbox.renderTask(gunTask());
  assert.ok(html.includes('class="task-sec-kutu"'), 'checkbox çizilir');
  assert.ok(html.includes('data-gorev-id="gungorev-1"'), 'görev id dataset attribute\'ta (escAttr\'li)');
  assert.ok(html.includes('this.dataset.gorevId'), 'onclick dataset üzerinden okur');
  assert.ok(!html.includes("_cokluSecimToggle('gungorev-1"), 'id inline-handler\'a interpolasyon YASAK');
  // Not (fix-1 review): TEDAVI_SEANS görevleri Görevler ekranında renderTask'tan
  // GEÇMEZ — renderSeansGorevKart mini-kartıyla çizilir; gerçek-akış kapsamı T3-i'de.
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

test('F1-T3-i (fix-1): gerçek akış — renderSeansGorevKart açık mini-kartta checkbox VAR ve toggle Set\'i günceller; kapalı (done/cancelled) mini-kartta YOK', () => {
  t3reset();
  const sb = T3.sandbox;
  const task = { id: 'seansgorev-9', gorev_tipi: 'TEDAVI_SEANS', tamamlandi: false, iptal: false, hedef_tarih: '2099-01-01' };
  // AÇIK seans (gelecek planlı → computeSeansState 'scheduled' → açık dal)
  const acik = sb.renderSeansGorevKart(task, { id: 'seans-a', planned_date: '2099-01-01', planned_time: '10:00' }, { drugName: 'GnRH' });
  assert.ok(acik.includes('class="task-sec-kutu"'), 'açık mini-kartta selection checkbox VAR');
  assert.ok(acik.includes('data-gorev-id="seansgorev-9"'), 'task id dataset attribute\'ta (escAttr\'li)');
  assert.ok(acik.includes('this.dataset.gorevId'), 'onclick dataset üzerinden okur');
  assert.ok(!acik.includes("_cokluSecimToggle('seansgorev-9"), 'id inline-handler\'a interpolasyon YASAK');
  // checkbox akışı gerçek toggle yardımcısına bağlanır (Set + storage)
  sb._cokluSecimToggle('seansgorev-9', true);
  assert.ok(sb.window._ckSecilenGorevler.has('seansgorev-9'), 'toggle Set\'i günceller');
  assert.deepStrictEqual(JSON.parse(sb.sessionStorage.getItem('ege_coklu_secim')), ['seansgorev-9'], 'storage senkron');
  // KAPALI dallar — kart görünür ama checkbox YOK (done / cancelled)
  const doneKart = sb.renderSeansGorevKart(task, { id: 'seans-b', planned_date: '2099-01-01', planned_time: '10:00', uygulama_tamamlandi_at: '2099-01-01T10:05:00Z' }, { drugName: 'GnRH' });
  assert.ok(!doneKart.includes('task-sec-kutu'), 'done mini-kartında checkbox YOK');
  const iptalKart = sb.renderSeansGorevKart(task, { id: 'seans-c', planned_date: '2099-01-01', planned_time: '10:00', uygulanmadi: true }, { drugName: 'GnRH' });
  assert.ok(!iptalKart.includes('task-sec-kutu'), 'cancelled mini-kartında checkbox YOK');
  // görev-tarafı kapalıysa (tamamlandi) kart açık dahi olsa checkbox YOK (çift-taraf fail-closed)
  sb.window._ckSecilenGorevler = new Set();
  const kapaliGorev = sb.renderSeansGorevKart({ ...task, tamamlandi: true }, { id: 'seans-d', planned_date: '2099-01-01', planned_time: '10:00' }, { drugName: 'GnRH' });
  assert.ok(!kapaliGorev.includes('task-sec-kutu'), 'tamamlanmış seans görevinde checkbox YOK');
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

// ═══════════════════════════════════════════════════════════════════════════
// Task 4: çoklu kaydırma onay + submit + bantlı sonuç (js/forms.js)
// Tam modül sandbox'ı (vaka-toplu-kisir-dusme.test.js `kur` deseni) — forms.js
// vm'de yüklenir; apiCokluKaydir/openConfirm/pullTables/renderSafe/
// _cokluSecimTemizle stub enjekte edilir (gerçek RPC YOK).
// ═══════════════════════════════════════════════════════════════════════════

// RPC'nin kısmi-başarı gövdesi (20260927000001 dönüş şeması):
// {ok, toplam, kaydirilan, atlanan(SAYI), hatalar:[{gorev_id|case_id, sebep}], detaylar:[...]}
function t4BasariliGovde(opts = {}) {
  return {
    ok: true,
    toplam: opts.toplam ?? 2,
    kaydirilan: opts.kaydirilan ?? 2,
    atlanan: opts.atlanan ?? 0,
    hatalar: opts.hatalar || [],
    detaylar: opts.detaylar ?? [
      { case_id: '11111111-aaaa-bbbb-cccc-dddddddd001', ilk_tarih: '2026-10-01', son_tarih: '2026-10-04', tasinan_gun_satiri: 3, tasinan_gorev: 2, tasinan_seans: 1 },
      { case_id: '22222222-aaaa-bbbb-cccc-dddddddd002', ilk_tarih: '2026-10-02', son_tarih: '2026-10-05', tasinan_gun_satiri: 2, tasinan_gorev: 1, tasinan_seans: 0 },
    ],
  };
}

// forms.js tam-modül sandbox'ı + iz kayıtları. opts.api = apiCokluKaydir
// davranışı; opts.online = navigator.onLine (varsayılan true);
// opts.gecerli = _cokluSecimGecerliIds kesişim kümesi (undefined → tüm seçim
// geçerli — ui.js fail-open aynası); opts.idb = idbGetAll stub'u
// (tablo adı → satırlar; fix-tur1 I-2/I-4 çözümleme testleri için).
function t4kur(opts = {}) {
  const document = makeDomStub();
  const toasts = [];
  const apiCagrilari = [];
  const pullCagrilari = [];
  let renderSayisi = 0;
  let temizleIzleri = [];
  const durum = {
    api: opts.api || (async () => t4BasariliGovde()),
    online: opts.online !== false,
    gecerli: opts.gecerli,
    idb: opts.idb,
  };
  const { sandbox } = loadBrowserModule('js/forms.js', {
    dom: document,
    extra: {
      navigator: { userAgent: 'node-test', onLine: durum.online },
      toast: (m, isErr) => toasts.push({ m: String(m), isErr: !!isErr }),
      apiCokluKaydir: async (...a) => {
        apiCagrilari.push({ args: a });
        return durum.api(...a);
      },
      openConfirm: (title, desc, onConfirm) => { document.__confirm = { title, desc, onConfirm }; },
      pullTables: async (tables) => { pullCagrilari.push(tables); },
      renderSafe: () => { renderSayisi++; },
      _cokluSecimGecerliIds: async () => {
        // ui.js fail-open aynası: gecerli tanımsızsa tüm seçim geçerli sayılır
        const secim = sandbox.window._ckSecilenGorevler || new Set();
        if (!durum.gecerli) return new Set([...secim]);
        return new Set([...secim].filter(id => durum.gecerli.has(id)));
      },
      _cokluSecimPrune: (gecerli) => {
        // ui.js aynası: kesişim-dışı id'ler Set'ten düşürülür, sayı döner
        const once = sandbox.window._ckSecilenGorevler || new Set();
        const kalan = new Set([...once].filter(id => gecerli.has(id)));
        const n = once.size - kalan.size;
        if (n) sandbox.window._ckSecilenGorevler = kalan;
        return n;
      },
      _cokluSecimTemizle: () => {
        const el = sandbox.window._ckKaydirSonucEl;
        temizleIzleri.push(el && el.style.display === 'block' ? 'bant-acik' : 'bant-yok');
        sandbox.window._ckSecilenGorevler = new Set();
      },
      RPC_TABLES: { vaka_kalan_gunleri_kaydir_coklu: ['gorev_log', 'treatment_days', 'treatment_day_uygulamalar', 'islem_log'] },
      band: (cls, title, content) => `<div class="aband" data-cls="${cls}"><div class="aband-hdr">${title}</div><div class="aband-body">${content}</div></div>`,
      fmtTarih: (d) => String(d || ''),
      esc: (s) => String(s ?? ''),
      escAttr: (s) => String(s ?? ''),
      getUserMessage: (e) => String(e?.message || e),
      // forms.js yüklemesinde dokunulan diğer global'ler (kisir-deseni)
      db: { rpc: async () => ({ data: null, error: null }), from: () => { throw new Error('test stub'); } },
      g: (id) => document.getElementById(id),
      v: (id) => { const el = document.getElementById(id); return (el && el.value) || ''; },
      cl: () => {},
      getState: () => null,
      setState: () => {},
      idbGetAll: async (tablo) => (durum.idb ? durum.idb(tablo) : []),
      getData: async () => [],
      hayvanByKupeRef: () => null,
      loadDrugsCache: async () => {},
    },
  });
  return { sandbox, document, toasts, apiCagrilari, pullCagrilari, durum,
    get renderSayisi() { return renderSayisi; },
    get temizleIzleri() { return temizleIzleri; } };
}

// Seçim Set'i doldur + gün girişi koy (varsayılan: 2 görev, +3 gün)
function t4SecimYap(sb, document, gunDeger) {
  sb.window._ckSecilenGorevler = new Set(['g1', 'g2']);
  const girdi = makeElement('input');
  girdi.value = gunDeger === undefined ? '3' : gunDeger;
  document.__setEl('k-coklu-gun', girdi);
  const btn = makeElement('button');
  btn.textContent = '⏩ Seçilenleri Kaydır';
  document.__setEl('k-coklu-onayla', btn);
  return btn;
}

test('F1-T4-a: doğrulama — Set boş → sessiz çıkış; gün boş/0/nedizali/31 üstü → RPC ÇAĞRILMAZ + açıklayıcı toast', async () => {
  // Set boş → sessiz çıkış (çubuk zaten 0 seçimde gizli)
  {
    const { sandbox, document, toasts, apiCagrilari } = t4kur();
    t4SecimYap(sandbox, document, '3');
    sandbox.window._ckSecilenGorevler = new Set();
    await sandbox.cokluKaydirBaslat();
    assert.ok(!document.__confirm, 'Set boşken onay açılmaz');
    assert.strictEqual(apiCagrilari.length, 0);
    assert.ok(!toasts.length, 'Set boşken sessiz çıkış (çubuk gizlidir)');
  }
  const durumlar = [
    { gun: '', neden: 'gün boş' },
    { gun: '0', neden: '0 gün' },
    { gun: '1.5', neden: 'nedizali' },
    { gun: '32', neden: '31 üstü' },
    { gun: 'abc', neden: 'sayı değil' },
  ];
  for (const d of durumlar) {
    const { sandbox, document, toasts, apiCagrilari } = t4kur();
    t4SecimYap(sandbox, document, d.gun);
    await sandbox.cokluKaydirBaslat();
    assert.ok(!document.__confirm, d.neden + ': onay AÇILMAZ');
    assert.strictEqual(apiCagrilari.length, 0, d.neden + ': RPC çağrılmaz');
    assert.ok(toasts.some(t => t.isErr), d.neden + ': toast basılır');
  }
});

test('F1-T4-b: geçerli girişte openConfirm — SPEC metni birebir ("N görev +N gün kaydırılacak (bağlı vakaların …)") + callback cokluKaydirOnayla', async () => {
  const { sandbox, document } = t4kur();
  t4SecimYap(sandbox, document, '3');
  await sandbox.cokluKaydirBaslat();
  assert.ok(document.__confirm, 'onay diyaloğu açılır');
  assert.ok(document.__confirm.desc.includes('2 görev +3 gün kaydırılacak'), 'görev sayısı + gün onay metninde');
  assert.ok(document.__confirm.desc.includes('bağlı vakaların tüm açık günleri/görevleri/seansları ve planlı tohumlaması birlikte kayar'), 'kapsam uyarısı onay metninde');
  assert.strictEqual(document.__confirm.onConfirm, sandbox.cokluKaydirOnayla, 'onay callback\'i cokluKaydirOnayla');
});

test('F1-T4-c: başarılı koşum — RPC([ids],N) → bant "2 vaka kaydırıldı" → pull(RPC_TABLES seti) → renderSafe → temizle → buton serbest', async () => {
  const kur = t4kur();
  const { sandbox, document, apiCagrilari, pullCagrilari, temizleIzleri } = kur;
  const btn = t4SecimYap(sandbox, document, '3');
  await sandbox.cokluKaydirBaslat();
  await document.__confirm.onConfirm();

  assert.strictEqual(apiCagrilari.length, 1, 'tek RPC');
  assert.deepStrictEqual(JSON.parse(JSON.stringify(apiCagrilari[0].args)), [['g1', 'g2'], 3], 'apiCokluKaydir([...Set], N)');
  const bant = sandbox.window._ckKaydirSonucEl; // bant kapsayıcısı (window cache)
  assert.ok(bant, 'bant kapsayıcısı yaratılır');
  assert.strictEqual(bant.id, 'k-coklu-sonuc', 'kapsayıcı id');
  assert.strictEqual(bant.style.display, 'block', 'bant görünür (sessiz başarı YASAK)');
  assert.ok(bant.innerHTML.includes('2 vaka kaydırıldı'), 'bant başlığı kaydırılan vaka sayısını verir');
  assert.deepStrictEqual(JSON.parse(JSON.stringify(pullCagrilari[0])),
    ['gorev_log', 'treatment_days', 'treatment_day_uygulamalar', 'islem_log'], 'pull seti RPC_TABLES kaydı');
  assert.strictEqual(kur.renderSayisi, 1, 'renderSafe çağrılır (getter canlı okunur)');
  assert.deepStrictEqual(temizleIzleri, ['bant-acik'], 'seçim temizliği bant gösterildikten SONRA koşar');
  assert.strictEqual(sandbox.window._ckSecilenGorevler.size, 0, 'Set temizlenir');
  assert.strictEqual(btn.disabled, false, 'buton koşum sonunda serbest');
  assert.strictEqual(btn.textContent, '⏩ Seçilenleri Kaydır', 'buton etiketi geri gelir');
});

test('F1-T4-d: bant şeması (pure) — Kaydırılan M vaka + Atlanan satırları + Hatalar satırları; id inline-handler interpolasyonu YASAK', () => {
  const { sandbox } = t4kur();
  const sonuc = t4BasariliGovde({
    toplam: 4, kaydirilan: 2, atlanan: 1,
    hatalar: [
      { case_id: '33333333-aaaa-bbbb-cccc-dddddddd003', sebep: 'VAKA_KAYDIRILAMAZ:{"sebep":"VAKA_ACIK_DEGIL","case_id":"33333333-aaaa-bbbb-cccc-dddddddd003"}' },
      { gorev_id: 'g9', sebep: 'GOREV_COZULEMEDI' },
    ],
  });
  const html = sandbox._cokluKaydirBanti(sonuc);
  assert.ok(typeof html === 'string', 'bant pure — HTML string döner');
  assert.ok(html.includes('2 vaka kaydırıldı'), 'kaydırılan sayısı');
  assert.ok(html.includes('Atlanan (1)'), 'atlanan bandı görünür (sessiz başarı yok)');
  assert.ok(html.includes('VAKA_ACIK_DEGIL'), 'atlanan sebep metni görünür');
  assert.ok(html.includes('Hata (1)'), 'hata bandı görünür');
  assert.ok(html.includes('GOREV_COZULEMEDI'), 'hata sebep metni görünür');
  assert.ok(html.includes('Vaka 33333333') && html.includes('Görev g9'), 'satır etiketleri metin taşıyıcı');
  const onclickSayisi = html.split('onclick=').length - 1;
  assert.strictEqual(onclickSayisi, 0, 'PURE bantta inline handler YOK (kapatma chrome\'undadır, T4-i)');
  assert.ok(!html.includes('data-aksiyon'), 'pure bant etkileşim attribute\'u taşımaz');
  // VAKA_KAYDIRILAMAZ zarfı soyulur (kullanıcı-dostu sebep kalır)
  assert.ok(html.includes('Atlanan (1)') && !html.includes('VAKA_KAYDIRILAMAZ:{"sebep"'), 'zarf öneki soyulur');
});

test('F1-T4-e (fix-tur1 I-1): RPC reject — SONUÇ BELİRSİZ yolu: önce pull+renderSafe (veri tazelenir), belirsizlik bandı + hata mesajı; seçim TEMİZLENMEZ, buton normal metinle serbest KALMAZ', async () => {
  const kur = t4kur({
    api: async () => { throw new Error('VAKA_KAYDIRILAMAZ:{"sebep":"GECERSIZ_GUN","gun":99}'); },
  });
  const { sandbox, document, toasts, apiCagrilari, pullCagrilari, temizleIzleri } = kur;
  const btn = t4SecimYap(sandbox, document, '3');
  await sandbox.cokluKaydirBaslat();
  await assert.doesNotReject(() => document.__confirm.onConfirm(), 'onay yolu kullanıcıya fırlatmaz');

  assert.strictEqual(apiCagrilari.length, 1, 'RPC denendi');
  // (a) catch yolu ÖNCE veriyi tazeler — ağ kopması sunucu tarafında işlem
  // yapılmış olabilir; liste gerçeği göstersin
  assert.deepStrictEqual(JSON.parse(JSON.stringify(pullCagrilari[0])),
    ['gorev_log', 'treatment_days', 'treatment_day_uygulamalar', 'islem_log'], 'catch yolu pull(RPC_TABLES seti)');
  assert.strictEqual(kur.renderSayisi, 1, 'catch yolunda renderSafe ÇAĞRILIR (getter canlı okunur)');
  // (b) belirsizlik bandı — sessiz hata/başarı YASAK, mesaj + sebep görünür
  const bant = sandbox.window._ckKaydirSonucEl;
  assert.ok(bant && bant.style.display === 'block', 'belirsizlik bandı görünür');
  assert.ok(bant.innerHTML.includes('Sonuç belirsiz'), 'belirsizlik başlığı');
  assert.ok(bant.innerHTML.includes('tekrar deneme'), 'tekrar-deneme uyarısı');
  assert.ok(bant.innerHTML.includes('GECERSIZ_GUN'), 'hata sebebi bantta');
  assert.ok(toasts.some(t => t.isErr), 'hata toast basılır');
  // (c) seçim temizlenmez ama buton normal metinle serbest bırakılmaz
  assert.deepStrictEqual(temizleIzleri, [], 'reject yolunda seçim temizlenmez');
  assert.strictEqual(sandbox.window._ckSecilenGorevler.size, 2, 'Set korunur (tekrar deneme imkânı)');
  assert.strictEqual(sandbox.window._ckKaydirBelirsiz, true, 'belirsizlik bayrağı set edilir');
  assert.strictEqual(btn.disabled, false, 'buton kilitli kalmaz');
  assert.strictEqual(btn.textContent, '⚠ Kontrol et — tekrar deneme riski', 'buton normal metinle DÖNMEZ — kontrol uyarısı taşır');
});

test('F1-T4-f: offline savunma-derinliği — Baslat ve Onayla çevrimdışında RPC ÇAĞRILMAZ, "İnternet" toast', async () => {
  // Baslat yolu
  {
    const { sandbox, document, toasts, apiCagrilari } = t4kur({ online: false });
    t4SecimYap(sandbox, document, '3');
    await sandbox.cokluKaydirBaslat();
    assert.ok(!document.__confirm, 'offline onay açılmaz');
    assert.strictEqual(apiCagrilari.length, 0, 'offline RPC çağrılmaz');
    assert.ok(toasts.some(t => /İnternet/.test(t.m)), '"İnternet" toast');
  }
  // Onayla yolu (savunma-derinliği: ui.js çubuğu zaten gizler; bekleme yok)
  {
    const { sandbox, document, toasts, apiCagrilari } = t4kur({ online: false });
    t4SecimYap(sandbox, document, '3');
    sandbox.window._ckKaydirBekleyenGun = 3;
    await sandbox.cokluKaydirOnayla();
    assert.strictEqual(apiCagrilari.length, 0, 'offline Onayla RPC çağrılmaz');
    assert.ok(toasts.some(t => /İnternet/.test(t.m)), '"İnternet" toast (Onayla yolu)');
  }
});

test('F1-T4-g: çift-gönderim kilidi — RPC koşumu sırasında ikinci çağrı gitmez; buton disabled', async () => {
  let coz;
  const { sandbox, document, apiCagrilari } = t4kur({
    api: (...a) => new Promise((res) => { coz = () => res(t4BasariliGovde()); apiCagrilari.push({ args: a }); }),
  });
  const btn = t4SecimYap(sandbox, document, '3');
  await sandbox.cokluKaydirBaslat();
  const kosum = document.__confirm.onConfirm();
  assert.strictEqual(btn.disabled, true, 'koşum sırasında buton disabled');
  const rpcOncesi = apiCagrilari.length;
  await sandbox.cokluKaydirOnayla(); // ikinci çağrı: kilide takılır
  assert.strictEqual(apiCagrilari.length, rpcOncesi, 'koşum sırasında ikinci çağrı GİTMEZ');
  coz();
  await kosum;
  assert.strictEqual(apiCagrilari.length, rpcOncesi, 'sonuç değişmez');
  assert.strictEqual(btn.disabled, false, 'koşum bitince buton serbest');
  assert.strictEqual(btn.textContent, '⏩ Seçilenleri Kaydır', 'başarılı koşumda buton metni normal');
});

test('F1-T4-h: kablolama — document delegasyonu [data-aksiyon="coklu-kaydir"] → cokluKaydirBaslat; band kapatma DOM\'dan kaldırır', async () => {
  // Kaynak denetimi (F1-T3-h deseni): buton ui.js'te inline handler'sız +
  // her render'da yeniden çizildiğinden bağlama document-delegasyon olmalı.
  const src = require('node:fs').readFileSync('js/forms.js', 'utf8');
  assert.ok(src.includes("addEventListener('click'"), 'document-seviyesi click delegasyonu');
  assert.ok(src.includes('[data-aksiyon="coklu-kaydir"]'), 'delegasyon data-aksiyon dataset\'i üzerinden');
  assert.ok(src.includes('cokluKaydirBaslat()'), 'delegasyon cokluKaydirBaslat\'ı tetikler');
  // Davranışsal: stub target.closest ile delegasyon tıkı gerçekten Baslat'ı çalıştırır
  const { sandbox, document } = t4kur();
  t4SecimYap(sandbox, document, '3');
  const btn = document.getElementById('k-coklu-onayla');
  btn.closest = () => btn; // makeElement stub closest'i test için bağlanır
  await document.__dispatch('click', { target: btn });
  await new Promise(r => setImmediate(r)); // async Baslat'ın mikro-görev zincirini boşalt
  assert.ok(document.__confirm, 'delegasyon tıkı onay diyaloğunu açar');
});

test('F1-T4-i: bant kapatma — _cokluKaydirBantiKapat elementi kaldırır + cache düşer; yeniden koşumda bant içeriği TAZELENİR', async () => {
  const { sandbox, document, durum } = t4kur();
  const btn = t4SecimYap(sandbox, document, '2');
  await sandbox.cokluKaydirBaslat();
  await document.__confirm.onConfirm();
  const bant = sandbox.window._ckKaydirSonucEl;
  assert.ok(bant && bant.style.display === 'block', 'bant görünür');
  assert.ok(bant.innerHTML.includes('onclick="_cokluKaydirBantiKapat()"'), 'chrome kapatma handler\'ı parametresiz global');
  assert.ok(bant.innerHTML.includes('Çoklu Kaydırma Sonucu'), 'chrome başlığı');
  sandbox._cokluKaydirBantiKapat();
  assert.ok(!document.body.children.includes(bant), 'kapatma elementi body\'den kaldırır');
  assert.strictEqual(sandbox.window._ckKaydirSonucEl, null, 'kapatma cache\'i düşürür');
  // yeniden koşum: kapatılmış bandın yerine TAZE bant açılır (eski içerik sızmaz)
  durum.api = async () => t4BasariliGovde({
    toplam: 1, kaydirilan: 1, detaylar: [
      { case_id: '99999999-aaaa-bbbb-cccc-dddddddd009', ilk_tarih: '2026-11-01', son_tarih: '2026-11-04', tasinan_gun_satiri: 1, tasinan_gorev: 0, tasinan_seans: 0 },
    ],
  });
  sandbox.window._ckSecilenGorevler = new Set(['g3']);
  await sandbox.cokluKaydirBaslat();
  await document.__confirm.onConfirm();
  const bant2 = sandbox.window._ckKaydirSonucEl;
  assert.ok(bant2 && bant2 !== bant, 'kapatılan element yeniden kullanILMAZ — taze kapsayıcı');
  assert.ok(bant2.style.display === 'block', 'yeni koşumda bant yeniden görünür');
  assert.ok(bant2.innerHTML.includes('1 vaka kaydırıldı') && bant2.innerHTML.includes('Vaka 99999999'), 'yeni koşum içeriği TAZE (eski 2-vaka içeriği sızmadı)');
  assert.strictEqual(btn.disabled, false);
});

// ═══════════════════════════════════════════════════════════════════════════
// Task 5: index.html statik çubuk konteyneri + ?v= damgası değer-bağımsızlığı
// Statik konteyner (id=k-coklu-bar) loadTasks'taki `!getElementById('k-coklu-bar')`
// koşuluyla dinamik çubuğu susturur (zero-friction geçiş); görünürlük/sayaç TEK
// _cokluSecimBarGuncelle'den senkronlanır. Damga testleri değer-bağımsız: bump
// testi kırmaz, karışık damga kılar (plan-review Critical kök fix —
// vaka-toplu-ac sweep ile aynı sözleşme).
// ═══════════════════════════════════════════════════════════════════════════
test('F1-T5-a: index.html statik k-coklu-bar konteyneri tam 1 kez ve tasks-body DIŞINDA (loadTasks re-render silmez)', () => {
  const html = fs.readFileSync('index.html', 'utf8');
  assert.strictEqual((html.match(/id="k-coklu-bar"/g) || []).length, 1,
    'statik konteyner tam 1 kez (id varlığı dinamik yolu sessizleştirir)');
  const barIdx = html.indexOf('id="k-coklu-bar"');
  const bodyIdx = html.indexOf('id="tasks-body"');
  assert.ok(barIdx !== -1, 'k-coklu-bar konteyneri index.html\'de');
  assert.ok(bodyIdx !== -1, 'tasks-body index.html\'de');
  assert.ok(barIdx < bodyIdx, 'konteyner görev listesi başlığının altında, tasks-body\'den ÖNCE');
  // innerHTML senaryosu: konteyner tasks-body div'i İÇİNE yazılmışsa ilk render'da silinir
  assert.ok(!/<div id="tasks-body"[^>]*>[\s\S]*id="k-coklu-bar"/.test(html),
    'konteyner tasks-body İÇİNDE DEĞİL');
});

test('F1-T5-b: statik konteyner içeriği tam — sayaç/chip/girdi/onayla/temizle id\'leri + delegasyon data-aksiyonu', () => {
  const html = fs.readFileSync('index.html', 'utf8');
  const kesit = html.slice(html.indexOf('id="k-coklu-bar"'), html.indexOf('id="tasks-body"'));
  for (const id of ['k-coklu-sayac', 'k-coklu-gun', 'k-coklu-onayla', 'k-coklu-temizle']) {
    assert.strictEqual((kesit.match(new RegExp('id="' + id + '"', 'g')) || []).length, 1,
      id + ' konteyner içinde tam 1 kez');
  }
  assert.strictEqual((kesit.match(/data-aksiyon="coklu-kaydir"/g) || []).length, 1,
    'onay butonu forms.js document-delegasyon data-aksiyonunu taşır');
  for (const gun of ['1', '2', '3', '7']) {
    assert.ok(kesit.includes('data-gun="' + gun + '"'), '+' + gun + ' hızlı chip');
  }
});

test('F1-T5-c: index.html tüm ?v= referansları TEK ayrık değerde (değer-bağımsız — bump testi kırmaz)', () => {
  const html = fs.readFileSync('index.html', 'utf8');
  const damgalar = [...html.matchAll(/\?v=([0-9]{8}-[0-9]+)/g)].map(m => m[1]);
  assert.ok(damgalar.length >= 14, 'dosyada ?v= referans sayısı: ' + damgalar.length);
  const ayrik = [...new Set(damgalar)];
  assert.strictEqual(ayrik.length, 1, 'tüm ?v= referansları tek değerde: ' + ayrik.join(' / '));
});

// ═══════════════════════════════════════════════════════════════════════════
// FIX-TUR 1 (dış-review 2026-09-27) — I-1 belirsiz sonuç, I-2 kör onay,
// I-3 görünmez seçim, I-4 UUID bandı. RPC/MIGRATION DEĞİŞMEZ.
// ═══════════════════════════════════════════════════════════════════════════

// I-3 yardımcıları (js/ui.js): kesişim + prune + Temizle belirsiz bayrağı
test('F1-T3-j (fix-tur1): _cokluSecimGecerliIds seçimi yüklü gorev_log ile kesiştirir; _cokluSecimPrune düşeni Set+storage\'dan atar; IDB hatasında fail-open; Temizle belirsiz bayrağını sıfırlar', async () => {
  t3reset();
  const sb = T3.sandbox;
  sb.idbGetAll = async (tablo) => tablo === 'gorev_log'
    ? [gunTask({ id: 'g1' }), gunTask({ id: 'g2' })]
    : [];
  sb.window._ckSecilenGorevler = new Set(['g1', 'g2', 'g-x']);
  const gecerli = await sb._cokluSecimGecerliIds();
  assert.ok(gecerli.has('g1') && gecerli.has('g2') && !gecerli.has('g-x'), 'kesişim yüklü görevlerle');
  const dusen = sb._cokluSecimPrune(gecerli);
  assert.strictEqual(dusen, 1, 'düşen sayısı döner');
  assert.ok(!sb.window._ckSecilenGorevler.has('g-x'), 'düşen id Set\'ten atılır');
  assert.deepStrictEqual(JSON.parse(sb.sessionStorage.getItem('ege_coklu_secim')).sort(), ['g1', 'g2'], 'sessionStorage senkron düşer');
  // IDB okunamazsa fail-open — seçim KISMAZ (yanlışlıkla tüm seçim silinmesin;
  // sunucu tarafı GOREV_COZULEMEDI kısmi-başarı ile zaten raporlar)
  t3reset();
  T3.sandbox.idbGetAll = async () => { throw new Error('idb yok'); };
  T3.sandbox.window._ckSecilenGorevler = new Set(['g1']);
  const failOpen = await T3.sandbox._cokluSecimGecerliIds();
  assert.ok(failOpen.has('g1'), 'okuma hatası → fail-open (seçim korunur)');
  // Temizle belirsizlik bayrağını sıfırlar (I-1: kullanıcı seçimi bıraktıysa uyarı kalkar)
  T3.sandbox.window._ckKaydirBelirsiz = true;
  assert.doesNotThrow(() => T3.sandbox._cokluSecimTemizle());
  assert.strictEqual(T3.sandbox.window._ckKaydirBelirsiz, false, 'Temizle belirsiz uyarısını sıfırlar');
});

// I-2: onay metninde hayvan listesi — kupe + tarih aralığı, max 8 satır,
// '+X hayvan daha', çözülemeyen görev satırı
test('F1-T4-j (fix-tur1 I-2): onay metni seçilen görevleri kupe+tarih aralığı ile listeler (max 8, fazlası "+X hayvan daha"); çözülemeyen görev sayacı içerir', async () => {
  // 2 hayvanlı normal durum
  {
    const { sandbox, document } = t4kur({
      idb: async (tablo) => {
        if (tablo === 'gorev_log') return [
          { id: 'g1', gorev_tipi: 'TEDAVI_GUN', hayvan_id: 'h-1', hedef_tarih: '2026-10-01', aciklama: '{}' },
          { id: 'g2', gorev_tipi: 'TEDAVI_GUN', hayvan_id: 'h-1', hedef_tarih: '2026-10-03', aciklama: '{}' },
          { id: 'gx', gorev_tipi: 'TEDAVI_GUN', hayvan_id: 'h-2', hedef_tarih: '2026-10-02', aciklama: '{}' },
        ];
        if (tablo === 'hayvanlar') return [
          { id: 'h-1', kupe_no: 'TR-111' },
          { id: 'h-2', kupe_no: 'TR-222' },
        ];
        return [];
      },
    });
    sandbox.window._ckSecilenGorevler = new Set(['g1', 'g2', 'gx']);
    const girdi = makeElement('input'); girdi.value = '3';
    document.__setEl('k-coklu-gun', girdi);
    document.__setEl('k-coklu-onayla', makeElement('button'));
    await sandbox.cokluKaydirBaslat();
    const desc = document.__confirm.desc;
    assert.ok(desc.includes('TR-111') && desc.includes('TR-222'), 'her hayvanın kupe\'si listede');
    assert.ok(desc.includes('2026-10-01 → 2026-10-03'), 'aynı hayvanın tarih aralığı min→max');
    assert.ok(!desc.includes('çözülemeyen'), 'tüm görevler çözümlendiğinde çözülemeyen satırı YOK');
  }
  // çözülemeyen görev
  {
    const { sandbox, document } = t4kur();
    t4SecimYap(sandbox, document, '3');   // idb boş → hiçbir görev çözülemez
    await sandbox.cokluKaydirBaslat();
    assert.ok(document.__confirm.desc.includes('çözülemeyen 2 görev atlanacak'), 'çözülemeyen görev sayısı bildirilir');
  }
  // 9 hayvan → 8 satır + "+1 hayvan daha"
  {
    const gorevler = [], hayvanlar = [];
    for (let i = 1; i <= 9; i++) {
      gorevler.push({ id: 'g' + i, gorev_tipi: 'TEDAVI_GUN', hayvan_id: 'h-' + i, hedef_tarih: '2026-10-0' + ((i % 9) + 1), aciklama: '{}' });
      hayvanlar.push({ id: 'h-' + i, kupe_no: 'TR-' + i });
    }
    const { sandbox, document } = t4kur({
      idb: async (tablo) => (tablo === 'gorev_log' ? gorevler : tablo === 'hayvanlar' ? hayvanlar : []),
    });
    sandbox.window._ckSecilenGorevler = new Set(gorevler.map(g => g.id));
    const girdi = makeElement('input'); girdi.value = '2';
    document.__setEl('k-coklu-gun', girdi);
    document.__setEl('k-coklu-onayla', makeElement('button'));
    await sandbox.cokluKaydirBaslat();
    const desc = document.__confirm.desc;
    assert.strictEqual((desc.match(/• TR-/g) || []).length, 8, 'en fazla 8 hayvan satırı');
    assert.ok(desc.includes('+1 hayvan daha'), 'fazlası "+X hayvan daha" satırı');
    assert.ok(desc.includes('TR-8') && !desc.includes('TR-9'), 'ilk 8 hayvan satırda; 9\'cusu yalnız "+1 hayvan daha" arkasında');
  }
});

// I-3: submit anında kesişim — listede olmayan (artık yüklü değil) görev
// confirm'de bildirilir + Set/sessionStorage'dan düşürülür; RPC'ye yalnız
// geçerli kesişim gider
test('F1-T4-k (fix-tur1 I-3): kesişim-dışı görevler onayda bildirilir, Set\'ten düşer ve RPC\'ye GÖNDERİLMEZ', async () => {
  const { sandbox, document, apiCagrilari } = t4kur({ gecerli: new Set(['g1']) });
  const btn = t4SecimYap(sandbox, document, '3');   // Set = {g1, g2}
  await sandbox.cokluKaydirBaslat();
  assert.ok(document.__confirm.desc.includes('1 görev artık listede değil — atlanacak'), 'kesişim-dışı sayısı onay metninde');
  assert.strictEqual(sandbox.window._ckSecilenGorevler.size, 1, 'Set kesişime indirilir');
  await document.__confirm.onConfirm();
  assert.deepStrictEqual(JSON.parse(JSON.stringify(apiCagrilari[0].args)), [['g1'], 3], 'RPC yalnız geçerli kesişimi alır');
  // tam kesişimde uyarı satırı YOK
  const kur2 = t4kur({ gecerli: new Set(['g1', 'g2']) });
  t4SecimYap(kur2.sandbox, kur2.document, '3');
  await kur2.sandbox.cokluKaydirBaslat();
  assert.ok(!kur2.document.__confirm.desc.includes('artık listede değil'), 'tam kesişimde uyarı yok');
});

// I-1 devam: belirsizlikten sonra yeniden Baslat → confirm'de uyarı satırı;
// başarılı koşum bayrağı temizler + buton normal metne döner
test('F1-T4-l (fix-tur1 I-1): belirsiz sonucu izleyen onayda uyarı satırı tekrar görünür; başarılı koşum bayrağı ve buton metnini normale çevirir', async () => {
  let at = 0;
  const kur = t4kur({
    api: async () => {
      at++;
      if (at === 1) throw new Error('ağ hatası: yanıt alınamadı');
      return t4BasariliGovde();
    },
  });
  const { sandbox, document } = kur;
  const btn = t4SecimYap(sandbox, document, '3');
  await sandbox.cokluKaydirBaslat();
  await document.__confirm.onConfirm();          // 1. koşum: belirsiz
  assert.strictEqual(sandbox.window._ckKaydirBelirsiz, true, '1. koşum belirsiz bırakır');
  await sandbox.cokluKaydirBaslat();             // tekrar dene → confirm'de uyarı
  assert.ok(document.__confirm.desc.includes('BELİRSİZ'), 'belirsizlik uyarısı confirm metnine taşınır');
  await document.__confirm.onConfirm();          // 2. koşum: başarılı
  assert.strictEqual(sandbox.window._ckKaydirBelirsiz, false, 'başarılı koşum bayrağı temizler');
  assert.strictEqual(btn.textContent, '⏩ Seçilenleri Kaydır', 'buton normal metne döner');
});

// I-4: bantta case_id UUID'si yerine kupe — çözülemeyen vaka kısa-id fallback
test('F1-T4-m (fix-tur1 I-4): sonuç bandı vakayı kupe ile gösterir (cases→animal_id→hayvanlar); çözülemeyen vaka kısa-id fallback', async () => {
  const kur = t4kur({
    idb: async (tablo) => {
      if (tablo === 'cases') return [
        { id: '11111111-aaaa-bbbb-cccc-dddddddd001', animal_id: 'h-77' },
      ];
      if (tablo === 'hayvanlar') return [{ id: 'h-77', kupe_no: 'TR-777' }];
      return [];
    },
  });
  const { sandbox, document } = kur;
  t4SecimYap(sandbox, document, '3');
  await sandbox.cokluKaydirBaslat();
  await document.__confirm.onConfirm();
  const bant = sandbox.window._ckKaydirSonucEl;
  assert.ok(bant.innerHTML.includes('Vaka TR-777'), 'çözülen vaka kupe ile gösterilir');
  assert.ok(bant.innerHTML.includes('Vaka 22222222'), 'çözülemeyen vaka kısa-id fallback');
  assert.ok(!bant.innerHTML.includes('Vaka 11111111'), 'çözülen vaka için UUID gösterilmez');
  // pure fonksiyon da haritayla çalışır (sıfır harita → fallback)
  const ham = sandbox._cokluKaydirBanti(t4BasariliGovde(), {});
  assert.ok(ham.includes('Vaka 11111111'), 'haritasız çağrıda fallback (pure sözleşme korunur)');
});

