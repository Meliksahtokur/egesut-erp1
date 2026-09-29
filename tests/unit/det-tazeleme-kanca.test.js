'use strict';
// tests/unit/det-tazeleme-kanca.test.js
// kart-tazeleme T2 — js/ui.js açık-kart tazeleme kancası (_detAciksaTazele),
// _detGen/_detEpoch protokolü ve ara-çizim cap'i (≤2 ara + 1 onaylı nihai).
// Plan: docs/plans/2026-09-29-acik-kart-tazeleme-PLAN.md Task 2 Step 1 — 12 madde:
// kapali-01, ic-01, bastir-01, evren-01, merge-01, cap-01, epoch-01, close-01,
// race-01, hist-01, flush-01, temiz-01. SPEC: …-SPEC.md §3 + §6 A6/A7/A8/A12/A13/A14/A15.
//
// Yükleme deseni: hizli-uygulama-guard.test.js — loadBrowserModule ile TAM js/ui.js.
// Kart-open senaryosunda GERÇEK openDet koşturulur (_detOpenId + det.on kurulur,
// pull stub'ı anında resolve eder); kanca draw'ları spy openDet ile sayılır.
// Debounce testte hızlandırılır: vm.runInContext('_DET_TAZELE_DEBOUNCE_MS = 5',
// sandbox) — sabit `let` bilinçli (testlere yazma kapısı); üretim değeri 250.
const { test } = require('node:test');
const assert = require('node:assert');
const vm = require('node:vm');
const { loadBrowserModule, makeDomStub, makeElement } = require('./support/loadModule.js');

// ── Saf yardımcı stub'ları (js/utils/helpers.js karşılıkları) — kart-open
//    senaryosunda çizim yolu gerçek openDet ile koştuğu için esc/fmtTarih vb.
//    gerekir; test tarafında minimal, deterministik karşılıkları kullanılır. ──
const _ymd = d => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const bugun = () => _ymd(new Date());
const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const escAttr = esc;
const fmtTarih = iso => (iso && iso.length >= 10 ? `${iso.slice(8, 10)}.${iso.slice(5, 7)}.${iso.slice(0, 4)}` : '—');
const fmtTarihSaat = fmtTarih;

const DET_EL_IDS = ['det', 'det-name', 'det-meta', 'det-chips', 'tab-ozet', 'tab-saglik', 'tab-ureme', 'tab-pedigree', 'tab-gorev', 'tab-gecmis'];

const bekle = ms => new Promise(r => setTimeout(r, ms));

// ── Sahne kurulumu ──────────────────────────────────────────────────
// gercmisYardimcilari=true: _detRenderGecmis STUB'LANMAZ (gerçek helper koşar);
// js/gecmis.js global'lerinin minimal test karşılıkları extra'ya girer (H-02 yarışı).
function kurSahne({ hayvanFix = null, casesFix = null, gercmisYardimcilari = false } = {}) {
  const rec = { pulls: [], pullOpts: [], draws: [], toasts: [], refresh: [], hist: [], showTab: [], pedigree: [], pushState: [], rpcs: [], ozet: [] };
  const document = makeDomStub();
  for (const id of DET_EL_IDS) document.__setEl(id, makeElement('div'));
  // hızlı uygulama form alanları (temiz-01 — hizli-uygulama-guard kalıbı)
  for (const [id, val] of [['pu-stok', 'S-1'], ['pu-doz', '5'], ['pu-birim', 'ml'], ['pu-rota', 'IM']]) {
    const el = makeElement('input'); el.value = val; document.__setEl(id, el);
  }
  const btn = makeElement('button'); btn.textContent = 'Kaydet';
  document.__setEl('pu-kaydet-btn', btn);

  const hayvanlar = hayvanFix || [
    { id: 'H-1', kupe_no: 'KUPE-1', durum: 'Aktif', irk: 'Holstein', padok: 'P1', dogum_tarihi: '2023-01-15', cinsiyet: 'Dişi' },
  ];
  const veri = { hayvanlar, cases: casesFix || [], tohumlama: [], dogum: [], gorev_log: [], kizginlik_log: [], uygulama_log: [], vaccination_log: [] };
  const pullKontrol = { beklet: false, coz: null };
  // FIX-R1 H-02: idbGetAll çağrı kontrolü — plan(tab, çağrıNo) true dönerse O çağrı
  // askıda tutulur (bekleyen haritasında coz/patlat ile); helper içi yarışlar bunu
  // kullanır. plan yoksa eski davranış: her çağrı anında [] çözer.
  const idbKontrol = { plan: null, bekleyen: new Map(), sayac: new Map() };
  const idbGetAll = (tab) => {
    const n = (idbKontrol.sayac.get(tab) || 0) + 1;
    idbKontrol.sayac.set(tab, n);
    if (idbKontrol.plan && idbKontrol.plan(tab, n)) {
      return new Promise((coz, patlat) => { idbKontrol.bekleyen.set(`${tab}#${n}`, { coz, patlat }); });
    }
    return Promise.resolve([]);
  };
  const gecmisEkstra = gercmisYardimcilari ? {
    // js/gecmis.js global'leri — gerçek _detRenderGecmis sandbox'ta koşsun diye
    // minimal, deterministik test karşılıkları (A'ya işaretli kayıt, B'ye boş):
    _gmEntriesFromSources: (sources, scope) => (scope && scope.animalId === 'A')
      ? [{ type: 'islem', data: { id: 'A-GECMIS' } }]
      : [],
    _gecmisSearchText: e => `ar-${e.type}`,
    _gecmisEntryHtml: e => `<div class="gm-stub">${(e.data && e.data.id) || '?'}</div>`,
    _gmSearch: entries => entries,
  } : {};

  const sahne = loadBrowserModule('js/ui.js', {
    dom: document,
    extra: {
      db: {},
      toast: (m, e) => rec.toasts.push([m, !!e]),
      confirm: () => true,
      write: async () => [],
      getState: k => (k === 'animals' ? veri.hayvanlar : null),
      bugun, esc, escAttr, fmtTarih, fmtTarihSaat,
      getData: async (tab, pred) => (veri[tab] || []).filter(pred),
      idbGetAll,
      rpc: async (name, args) => { rec.rpcs.push({ name, args }); return { ok: true }; },
      pullTables: async (t, opts) => {
        rec.pulls.push(t); rec.pullOpts.push(opts || null);
        if (pullKontrol.beklet) return new Promise(res => { pullKontrol.coz = () => res({ ok: [...t], failed: [] }); });
        return { ok: [...t], failed: [] };
      },
      ...gecmisEkstra,
    },
  });
  const { sandbox } = sahne;
  vm.runInContext('_DET_TAZELE_DEBOUNCE_MS = 5', sandbox); // hızlı debounce (sabit let)
  // monkeypatch kaydediciler
  sandbox.showTab = (...a) => { rec.showTab.push(a); };
  sandbox.pedigreeSetFocus = (...a) => { rec.pedigree.push(a); };
  if (!gercmisYardimcilari) sandbox._detRenderGecmis = async (...a) => { rec.hist.push(a); };
  sandbox._islemSonrasiRefresh = async () => { rec.refresh.push(1); };
  sandbox._detOzetHtml = (...a) => { rec.ozet.push(a[0] && a[0].id); return '<ozet-stub>'; };
  sandbox.history.pushState = (...a) => { rec.pushState.push(a); };
  return { sandbox, document, rec, veri, pullKontrol, idbKontrol, window: sahne.window };
}

// Kartı GERÇEK openDet ile açar (_detOpenId + det.on kurulur), sonra kanca
// draw'larını saymak için openDet'i spy'la değiştirir.
async function kartAc(sahne, id = 'H-1') {
  const gercek = sahne.sandbox.openDet;
  await gercek(id); // keepTab falsy — ilk açış semantiği
  const spy = (...a) => { sahne.rec.draws.push(a); };
  sahne.sandbox.openDet = spy;
  return { gercek, spy };
}

// ── 12 test (plan Task 2 Step 1 ad ad) ──────────────────────────────

test('kapali-01 (R5): kart kapalıyken nitelikli kanca çizim planlamaz — 0 draw', async () => {
  const sahne = kurSahne();
  const { sandbox, rec } = sahne;
  assert.strictEqual(sandbox._detAcik(), false, 'kart kapalı başlangıç');
  sandbox._detAciksaTazele(['hayvanlar'], ['hayvanlar'], [], false);
  await bekle(40); // debounce + pay
  assert.strictEqual(rec.draws.length, 0, 'kapalı kartta kanca çizim kurmamalı (fetch/render maliyeti sıfır)');
});

test('ic-01 (A6a/A6b): detInternal pull bastırılır; dış pull kendi flushını kurar', async () => {
  const sahne = kurSahne();
  const { sandbox, rec } = sahne;
  await kartAc(sahne);
  sandbox._detAciksaTazele(['hayvanlar'], ['hayvanlar'], [], true); // openDet'in kendi pull'u
  await bekle(40);
  assert.strictEqual(rec.draws.length, 0, 'içsel işaretli pull kanca doğurmamalı');
  sandbox._detAciksaTazele(['hayvanlar'], ['hayvanlar'], [], false); // dış pull
  await bekle(40);
  assert.strictEqual(rec.draws.length, 1, 'içsel pull dış flush\'ı silmez — dış pull çizer');
  assert.deepStrictEqual(rec.draws[0], ['H-1', true], 'draw (_detOpenId, keepTab=true)');
});

test('bastir-01 (A14): kesişen tablo hatası flush\'ı bastırır; ilgisiz hata bozmaz', async () => {
  const sahne = kurSahne();
  const { sandbox, rec } = sahne;
  await kartAc(sahne);
  sandbox._detAciksaTazele(['hayvanlar', 'protokol_ayar'], ['protokol_ayar'], ['hayvanlar'], false);
  await bekle(40);
  assert.strictEqual(rec.draws.length, 0, 'evren-İÇİ tablo hatası çizimi bastırmalı (bayat IDB silent-success kapısı)');
  sandbox._detAciksaTazele(['hayvanlar', 'protokol_ayar'], ['hayvanlar'], ['protokol_ayar'], false);
  await bekle(40);
  assert.strictEqual(rec.draws.length, 1, 'evren-DIŞI tablo hatası davranışı bozmamalı');
});

test('evren-01 (A8): evren-dışı tablo tek başına çizdirmez; stok evren İÇİDİR', async () => {
  const sahne = kurSahne();
  const { sandbox, rec } = sahne;
  await kartAc(sahne);
  sandbox._detAciksaTazele(['protokol_ayar'], ['protokol_ayar'], [], false);
  await bekle(40);
  assert.strictEqual(rec.draws.length, 0, 'protokol_ayar (evren-dışı) kart çizdirmemeli');
  sandbox._detAciksaTazele(['stok'], ['stok'], [], false);
  await bekle(40);
  assert.strictEqual(rec.draws.length, 1, 'stok kart evreni İÇİNDEDİR (R1-H01 zenginleştirme)');
});

test('merge-01: debounce penceresi içindeki 3 nitelikli pull tek çizime birleşir', async () => {
  const sahne = kurSahne();
  const { sandbox, rec } = sahne;
  await kartAc(sahne);
  sandbox._detAciksaTazele(['hayvanlar'], ['hayvanlar'], [], false);
  sandbox._detAciksaTazele(['gorev_log'], ['gorev_log'], [], false);
  sandbox._detAciksaTazele(['uygulama_log'], ['uygulama_log'], [], false);
  await bekle(40);
  assert.strictEqual(rec.draws.length, 1, 'pencere içi 3 pull tek draw olmalı');
  assert.deepStrictEqual(rec.draws[0], ['H-1', true], 'draw (_detOpenId, keepTab=true)');
});

test('cap-01 (A6f/A7): uzun nitelikli zincir toplam 3 çizim (2 ara + 1 nihai), hepsi keepTab=true', async () => {
  const DB = 10, ARALIK = 15; // ARALIK ∈ (debounce, 2×debounce) — her yeni pull bekleyen nihai timer'ı iptal eder
  const sahne = kurSahne();
  const { sandbox, rec } = sahne;
  vm.runInContext(`_DET_TAZELE_DEBOUNCE_MS = ${DB}`, sandbox);
  await kartAc(sahne);
  for (let i = 0; i < 4; i++) {
    sandbox._detAciksaTazele(['hayvanlar'], ['hayvanlar'], [], false);
    await bekle(ARALIK);
  }
  await bekle(60);
  assert.strictEqual(rec.draws.length, 3, `4-pull zinciri tam 3 çizim: ${JSON.stringify(rec.draws)}`);
  assert.ok(rec.draws.every(a => a[1] === true), 'her çizim keepTab=true');

  // 10-pull zinciri — taze sahne (taze epoch)
  const s2 = kurSahne();
  vm.runInContext(`_DET_TAZELE_DEBOUNCE_MS = ${DB}`, s2.sandbox);
  await kartAc(s2);
  for (let i = 0; i < 10; i++) {
    s2.sandbox._detAciksaTazele(['hayvanlar'], ['hayvanlar'], [], false);
    await bekle(ARALIK);
  }
  await bekle(60);
  assert.strictEqual(s2.rec.draws.length, 3, '10-pull zinciri de tam 3 çizim');
  assert.ok(s2.rec.draws.every(a => a[1] === true), 'her çizim keepTab=true');
});

test('epoch-01 (A6f/R5-M01): yerinde tazeleme sayacı sıfırlamaz; kapat-aç epoch artırır, sayacı sıfırlar', async () => {
  const sahne = kurSahne();
  const { sandbox, rec } = sahne;
  const { gercek } = await kartAc(sahne);
  const epoch0 = sandbox.window.__detSayac.epoch;
  // 2 ara + 1 nihai
  sandbox._detAciksaTazele(['hayvanlar'], ['hayvanlar'], [], false); await bekle(30);
  sandbox._detAciksaTazele(['hayvanlar'], ['hayvanlar'], [], false); await bekle(30);
  sandbox._detAciksaTazele(['hayvanlar'], ['hayvanlar'], [], false); await bekle(30);
  assert.strictEqual(rec.draws.length, 3, '2 ara + 1 nihai tamamlandı');
  // cap doluyken yeni burst — yalnız 1 nihai daha
  sandbox._detAciksaTazele(['hayvanlar'], ['hayvanlar'], [], false); await bekle(30);
  assert.strictEqual(rec.draws.length, 4, 'cap dolu epoch\'ta yeni burst yalnız 1 nihai çizer');
  assert.strictEqual(vm.runInContext('_detAraSayac', sandbox), 2, 'ara sayacı epoch boyunca 2 kalır (yerinde tazeleme sıfırlamaz)');
  // closeDet + yeniden aç — epoch artar, sayaç sıfırdan
  sandbox.closeDet();
  assert.strictEqual(sandbox.window.__detSayac.epoch, epoch0 + 1, 'closeDet epoch artırır');
  sandbox.openDet = gercek;
  await sandbox.openDet('H-1');
  assert.strictEqual(sandbox.window.__detSayac.epoch, epoch0 + 2, 'yeni açılış epoch artırır');
  assert.strictEqual(vm.runInContext('_detAraSayac', sandbox), 0, 'yeni epoch\'ta ara sayacı sıfır');
  sandbox.openDet = (...a) => { rec.draws.push(a); };
  sandbox._detAciksaTazele(['hayvanlar'], ['hayvanlar'], [], false); await bekle(30);
  assert.strictEqual(rec.draws.length, 5, 'yeni epoch\'ta çizim yeniden mümkün');
  assert.strictEqual(vm.runInContext('_detAraSayac', sandbox), 1, 'ara çizimler sıfırdan yeniden doğuyor');
});

test('close-01 (A15): debounce dolmadan closeDet — bekleyen timer kartı yeniden AÇMAZ', async () => {
  const sahne = kurSahne();
  const { sandbox, rec, document } = sahne;
  await kartAc(sahne);
  sandbox._detAciksaTazele(['hayvanlar'], ['hayvanlar'], [], false);
  sandbox.closeDet(); // debounce dolmadan
  await bekle(40);
  assert.strictEqual(rec.draws.length, 0, 'kapalı kartı timer yeniden AÇMAMALI');
  assert.strictEqual(document.getElementById('det').classList.contains('on'), false, 'kart kapalı kalır');
});

test('race-01 (A6c/d/e): geç kalan gen DOM\'a yazamaz — farklı-ID ve aynı-ID close/reopen', async () => {
  const sahne = kurSahne({
    hayvanFix: [
      { id: 'A', kupe_no: 'A-KUPE', durum: 'Aktif', irk: 'Holstein', padok: 'P1', dogum_tarihi: '2023-01-15', cinsiyet: 'Dişi' },
      { id: 'B', kupe_no: 'B-KUPE', durum: 'Aktif', irk: 'Holstein', padok: 'P2', dogum_tarihi: '2023-02-20', cinsiyet: 'Dişi' },
    ],
  });
  const { sandbox, rec, document, pullKontrol } = sahne;
  // (c) farklı-ID: openDet(A) askıda → openDet(B) tamamlanır → A'nın pull'u çözülür
  pullKontrol.beklet = true;
  const pA = sandbox.openDet('A');
  pullKontrol.beklet = false;
  await sandbox.openDet('B');
  assert.strictEqual(document.getElementById('det-name').textContent, 'B-KUPE', 'B çizildi');
  assert.deepStrictEqual(rec.ozet, ['B'], 'yalnız B render etti');
  pullKontrol.coz(); // A'nın pull'u çözülür
  await pA;
  await bekle(20);
  assert.strictEqual(document.getElementById('det-name').textContent, 'B-KUPE', 'gen-1 (A) devamı DOM\'u ezemedi');
  assert.deepStrictEqual(rec.ozet, ['B'], 'A devamı render çağırmadı');

  // (d) aynı-ID close/reopen: openDet(A) askıda → closeDet → openDet(A) → gen-1 çözülür
  pullKontrol.beklet = true;
  const pA2 = sandbox.openDet('A');
  pullKontrol.beklet = false;
  sandbox.closeDet();
  await sandbox.openDet('A');
  assert.strictEqual(document.getElementById('det-name').textContent, 'A-KUPE', 'gen-2 A çizildi');
  const ozetSayisi = rec.ozet.length;
  pullKontrol.coz(); // gen-1'in pull'u çözülür
  await pA2;
  await bekle(20);
  assert.strictEqual(rec.ozet.length, ozetSayisi, 'gen-1 devamı gen-2 DOM\'una yazmadı (A6d: aynı-ID close/reopen)');
  assert.strictEqual(document.getElementById('det-name').textContent, 'A-KUPE', 'DOM gen-2 içeriğini korur');
  assert.strictEqual(document.getElementById('det').classList.contains('on'), true, 'kart açık kalır');
});

test('hist-01 (A12): kanca draw\'u (keepTab=true) history.pushState çağırmaz; ilk açış çağırır', async () => {
  const sahne = kurSahne();
  const { sandbox, rec } = sahne;
  await sandbox.openDet('H-1'); // ilk açış — keepTab falsy
  assert.strictEqual(rec.pushState.length, 1, 'ilk açış pushState yazar (6 yolun semantiği korunur)');
  const acikSayaci = sandbox.window.__detSayac.openDet;
  sandbox._detAciksaTazele(['hayvanlar'], ['hayvanlar'], [], false);
  await bekle(30);
  assert.strictEqual(sandbox.window.__detSayac.openDet, acikSayaci + 1, 'kanca draw gerçekleşti (gerçek openDet)');
  assert.strictEqual(rec.pushState.length, 1, 'keepTab=true flush history girişi üretmez');
});

test('flush-01 (A13): flushPendingDone pull seti kart evreniyle kesişir (statik üyelik)', async () => {
  const sahne = kurSahne();
  const { sandbox } = sahne;
  const tablolar = vm.runInContext('_DET_TABLOLAR', sandbox);
  const flushSet = ['gorev_log', 'treatment_days', 'treatment_day_uygulamalar', 'drug_administrations', 'stok', 'stok_hareket', 'cases'];
  const kesisim = flushSet.filter(t => tablolar.includes(t));
  assert.ok(kesisim.length > 0, `kesişim boş olmamalı — kesişen: ${kesisim.join(',')}`);
});

test('temiz-01: hızlı uygulama akışı doğrudan openDet ÇAĞIRMAZ — _islemSonrasiRefresh kalır', async () => {
  const sahne = kurSahne();
  const { sandbox, rec } = sahne;
  sandbox.openDet = (...a) => { rec.draws.push(a); }; // kart kapalı sahne — spy boş kalmalı
  await sandbox._hayvanHizliUygulaKaydet('H-1');
  await bekle(30); // olası bir kanca yolu da batsın
  assert.strictEqual(rec.rpcs.filter(r => r.name === 'hizli_uygulama').length, 1, 'hizli_uygulama rpc bir kez');
  assert.strictEqual(rec.refresh.length, 1, '_islemSonrasiRefresh çağrıldı (pull seti evren içi — kanca çizer)');
  assert.strictEqual(rec.draws.length, 0, 'doğrudan openDet YOK (çifte çizim temizliği)');
});

// ── FIX-R1 (luna review R1 bulguları) ───────────────────────────────
// H-01: t1/t2 timer callback'leri kurulma anındaki generation/epoch'u doğrulamalı.
// closeDet/openDet(keepTab=false) timer'ı temizler; ama keepTab=true yerinde tazeleme
// (T3'ün forms yolu: abortKaydet/hayvanNotEkle → openDet(id, _detAcik())) gen'i
// ARTIRIRken timer'ı TEMİZLEMEZ — deadline'ı geçmiş callback eski gen bağlamıyla
// koşar. Node'da timer cancel-until-started olduğundan (clearTimeout çalışma
// başlayana kadar iptal eder) tarayıcı giriş-kuyruk yarışı burada birebir
// simüle edilemez; gen sapması aynı guard'ı deterministik koşturur — guard'ın
// kendisi (scheduledGen===_detGen && scheduledEpoch===_detEpoch && _detAcik())
// her iki düzende de aynı kapıdır.

test('timer-01 (H-01): t1 askıdayken gen artarsa (keepTab=true tazeleme) callback çizmemeli', async () => {
  const sahne = kurSahne();
  const { sandbox, rec } = sahne;
  const { gercek } = await kartAc(sahne); // gen=G, epoch=E; openDet→spy
  sandbox._detAciksaTazele(['hayvanlar'], ['hayvanlar'], [], false); // t1 kuruldu, scheduledGen=G
  await gercek('H-1', true); // keepTab=true: gen=G+1 — t1 temizlenmez
  await bekle(40); // t1 deadline geçer, callback koşar
  assert.strictEqual(rec.draws.length, 0,
    'stale gen\'li t1 callback\'i kart açık olsa bile ÇİZMEMELİ (H-01)');
});

test('timer-02 (H-01): t2 (nihai) askıdayken gen artarsa nihai çizim düşmeli', async () => {
  const sahne = kurSahne();
  const { sandbox, rec } = sahne;
  const { gercek } = await kartAc(sahne);
  sandbox._detAciksaTazele(['hayvanlar'], ['hayvanlar'], [], false); await bekle(30); // ara 1
  sandbox._detAciksaTazele(['hayvanlar'], ['hayvanlar'], [], false); await bekle(30); // ara 2
  // cap dolu: 3. pull'un t1'i fire edince t2 kurulur (+5ms). 7ms'lik test bekleyişi
  // heap sırasıyla t1-fire (5ms) SONRASI, t2-fire (10ms) ÖNCESİ uyanır — gen artışı
  // tam t2'nin askıdaki penceresine düşer (debounce=5, kurSahne).
  sandbox._detAciksaTazele(['hayvanlar'], ['hayvanlar'], [], false);
  await new Promise(r => setTimeout(r, 7));
  await gercek('H-1', true); // gen artar — t2 temizlenmez (keepTab=true yolu timer'ı silmez)
  await bekle(40); // t2 deadline geçer, callback koşar
  assert.strictEqual(rec.draws.length, 2,
    'stale gen\'li t2 nihai çizimi düşmeli — yalnız 2 ara çizim kalmalı (H-01)');
});

// ── FIX-R1 H-02: async alt-render yardımcılarının DOM yazımları guard kapsamına ──
// openDet'in kendi guard'ları (myGen) _detSaglikRender/_detRenderGecmis ÇAĞRISINDAN
// sonraya geliyor; helper kendi await'inden sonra doğrudan DOM'a yazıyor. Gerçek
// helper'lar (stub'sız) + planlı idbGetAll askılarıyla: A askıdayken B tamamlanır,
// A'nın devamı B'nin DOM'una YAZAMAMALI; stale catch de DOM'A YAZMAMALI.

const IKI_HAYVAN = [
  { id: 'A', kupe_no: 'A-KUPE', durum: 'Aktif', irk: 'Holstein', padok: 'P1', dogum_tarihi: '2023-01-15', cinsiyet: 'Dişi' },
  { id: 'B', kupe_no: 'B-KUPE', durum: 'Aktif', irk: 'Holstein', padok: 'P2', dogum_tarihi: '2023-02-20', cinsiyet: 'Dişi' },
];

test('race-02 (H-02): gerçek _detSaglikRender askıdayken B çizer — A\'nın devamı tab-saglik\'e yazamaz', async () => {
  const sahne = kurSahne({
    hayvanFix: IKI_HAYVAN,
    casesFix: [{ id: 'C-A', animal_id: 'A', status: 'active', disease_id: 'D1' }], // yalnız A'nın vaka chip'i
  });
  const { sandbox, document, idbKontrol } = sahne;
  idbKontrol.plan = (tab, n) => tab === 'cases' && n === 1; // A: renderCasesForAnimal askıda
  const pA = sandbox.openDet('A');
  await bekle(10);
  assert.strictEqual(document.getElementById('det-name').textContent, 'A-KUPE',
    'A senkron bloğunu yazdı, helper await\'inde askıda');
  await sandbox.openDet('B'); // B tamamlanır — gen artar
  assert.strictEqual(document.getElementById('det-name').textContent, 'B-KUPE', 'B çizildi');
  const bIcerik = document.getElementById('tab-saglik').innerHTML;
  assert.ok(!bIcerik.includes('C-A'), 'B içeriğinde A izi yok');
  idbKontrol.bekleyen.get('cases#1').coz([]); // A'nın askısı çözülür
  await pA;
  await bekle(10);
  const son = document.getElementById('tab-saglik').innerHTML;
  assert.ok(!son.includes('C-A'), 'A\'nın stale helper devamı tab-saglik\'e yazamaz (H-02)');
  assert.strictEqual(son, bIcerik, 'B içeriği aynen korunur');
});

test('race-03 (H-02): gerçek _detRenderGecmis askıdayken B çizer — A\'nın gecmis devamı yazamaz', async () => {
  const sahne = kurSahne({ hayvanFix: IKI_HAYVAN, gercmisYardimcilari: true });
  const { sandbox, document, idbKontrol } = sahne;
  idbKontrol.plan = (tab, n) => tab === 'gorev_log' && n === 1; // A: _gecmisCollectSources askıda
  const pA = sandbox.openDet('A');
  await bekle(10);
  assert.ok(document.getElementById('tab-gecmis').innerHTML.includes('loader'),
    'A loader yazdı, collect await\'inde askıda');
  await sandbox.openDet('B'); // B tamamlanır — gen artar
  const bIcerik = document.getElementById('tab-gecmis').innerHTML;
  assert.ok(bIcerik.includes('Kayıt yok'), 'B gecmis içeriği yerleşti');
  idbKontrol.bekleyen.get('gorev_log#1').coz([]); // A'nın collect'i çözülür (A için kayıt var)
  await pA;
  await bekle(10);
  const son = document.getElementById('tab-gecmis').innerHTML;
  assert.ok(son.includes('Kayıt yok'), 'A\'nın stale gecmis devamı B içeriğini EZEMEZ (H-02)');
  assert.strictEqual(son, bIcerik, 'tab-gecmis B içeriğiyle aynı kalır');
});

test('race-04 (H-02): stale _detRenderGecmis catch DOM\'a yazmaz — hata güncel akışta basılır', async () => {
  const sahne = kurSahne({ hayvanFix: IKI_HAYVAN, gercmisYardimcilari: true });
  const { sandbox, document, idbKontrol } = sahne;
  idbKontrol.plan = (tab, n) => tab === 'gorev_log' && n === 1;
  const pA = sandbox.openDet('A');
  await bekle(10);
  await sandbox.openDet('B');
  const bIcerik = document.getElementById('tab-gecmis').innerHTML;
  idbKontrol.bekleyen.get('gorev_log#1').patlat(new Error('idb-patlat')); // A'nın collect'i PATLAR
  await pA;
  await bekle(10);
  const son = document.getElementById('tab-gecmis').innerHTML;
  assert.ok(!son.includes('idb-patlat'), 'stale catch DOM\'a hata YAZMAMALI (H-02: stale catch DOM\'a yazmaz)');
  assert.strictEqual(son, bIcerik, 'B içeriği korunur');
});

test('race-05 (H-02): stale openDet catch det-name\'i ezemez', async () => {
  const sahne = kurSahne({ hayvanFix: IKI_HAYVAN, casesFix: [{ id: 'C-A', animal_id: 'A', status: 'active', disease_id: 'D1' }] });
  const { sandbox, document, idbKontrol } = sahne;
  idbKontrol.plan = (tab, n) => tab === 'vaccines' && n === 1; // A: _detSaglikRender 2. await'i askıda
  const pA = sandbox.openDet('A');
  await bekle(10);
  assert.strictEqual(document.getElementById('det-name').textContent, 'A-KUPE', 'A helper içinde askıda');
  await sandbox.openDet('B');
  assert.strictEqual(document.getElementById('det-name').textContent, 'B-KUPE', 'B çizildi');
  idbKontrol.bekleyen.get('vaccines#1').patlat(new Error('asipatla')); // A helper'ı PATLAR
  await pA; // openDet catch'ine düşer
  await bekle(10);
  const isim = document.getElementById('det-name').textContent;
  assert.ok(!isim.includes('asipatla'), 'stale openDet catch DOM\'a hata YAZMAMALI (hata yalnız güncel akışta basılır)');
  assert.strictEqual(isim, 'B-KUPE', 'det-name B içeriğini korur');
});
