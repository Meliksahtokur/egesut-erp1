// tests/unit/vaka-toplu-kisir-dusme.test.js
// K6 (p5b-fix, 2026-09-26) — toplu vaka açılışında KISIR-DÜŞME zinciri +
// loadDiseasesDropdown yarış-guard/seçim-koruma sertleştirmesi.
//
// Zincir (forms.js):
//   bcChipEkle → _bcHayvanlar[..].kisir (K6 ile taşınır)
//   submitBulkCase → _ovsyncAileHastalikIdSet × diseaseId koşulu (2528)
//     → kısır olanlar düşer (2529-2531) + "N kısır işaretli hayvan atlandı"
//       toast (2532) → liste boşaldıysa İSTEK ATILMAZ (2533 return)
//   loadDiseasesDropdown → _ddFillSeq yarış-guard (bayat doldurma yazmaz)
//     + oncekiDeger seçim-koruma (kilitliyse geri konmaz — C1 kilidiyle
//       kesişim: kısır hayvanda OVSYNC option disabled kalır)
//
// Loader pattern: vaka-toplu-ac.test.js setupFormsPlan ile birebir — forms.js
// vm'de yüklenir, db/rpc erişimi stub (gerçek Supabase çağrısı YOK).
'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule, makeDomStub, makeElement } = require('./support/loadModule.js');

// ── fixture: OVSYNC ailesi tek şablon + iki hastalık (DOV=Ovsync, DMET=serbest) ──
const OVS_HASTALIK = 'DOV';
const TABLOLAR = {
  tedavi_sablonu: [{ id: 'S1', protokol_ailesi: 'OVSYNC', ad: 'Ovsynch-56' }],
  'sablon_hastalik_eslem': [{ sablon_id: 'S1', disease_id: OVS_HASTALIK }],
  diseases: [
    { id: OVS_HASTALIK, name: 'Ovsync Protokol', category: 'Üreme' },
    { id: 'DMET', name: 'Metrit', category: 'Üreme' },
  ],
  cases: [],
  gorev_log: [],
};

// Cross-realm: vm'de üretilen diziler farklı Array.prototype taşır —
// deepStrictEqual prototipleri de kıyasladığından host realm'ine çevrilir.
const host = (x) => JSON.parse(JSON.stringify(x ?? null));

function kur(opts = {}) {
  const document = makeDomStub();
  const toasts = [];
  const rpcCagrilar = [];
  const tablolar = Object.assign({}, TABLOLAR, opts.idbTablolar || {});
  const { sandbox } = loadBrowserModule('js/forms.js', {
    dom: document,
    extra: {
      // submitBulkCase çevrimiçi kapısı (varsayılan loader navigator'ı
      // onLine taşımaz — kapı erken dönerdi)
      navigator: { userAgent: 'node-test', onLine: true },
      db: { rpc: async () => ({ data: null, error: null }), from: () => { throw new Error('test stub'); } },
      g: (id) => document.getElementById(id),
      v: (id) => { const el = document.getElementById(id); return (el && el.value) || ''; },
      cl: () => {},
      esc: (s) => String(s || ''),
      escAttr: (s) => String(s || ''),
      getState: () => null,
      setState: () => {},
      toast: (m, isErr) => toasts.push({ m: String(m), isErr: !!isErr }),
      rpc: async (name, params) => {
        rpcCagrilar.push({ name, params });
        return { ok: true, acilan: [{ kupe: 'TR-2' }], atlanan: [], hatalar: [], basari: 1 };
      },
      idbGetAll: async (t) => tablolar[t] || [],
      getData: async () => [],
      pullTables: async () => {},
      openConfirm: () => {},
      getUserMessage: (e) => String(e?.message || e),
      hayvanByKupeRef: () => opts.hayvan || null, // d-disease kilit testi kısır hayvan verir
      renderSafe: () => {},
      loadDrugsCache: async () => {},
    },
  });
  sandbox.__toasts = toasts;
  sandbox.__rpc = rpcCagrilar;
  return { sandbox, document, toasts, rpcCagrilar };
}

// bc-disease-id değer elemanı (submitBulkCase v() üzerinden okur)
function hastalikSec(document, id) {
  const el = makeElement('select');
  el.value = id;
  document.__setEl('bc-disease-id', el);
  return el;
}

// ── tarayıcı-sempatik <select> stub'u ────────────────────────────────
// makeElement'in düz innerHTML alanı tarayıcı seçim-semantiğini taşımaz:
// gerçek DOM'da option seti değişince seçim boşa düşer. Ayna: innerHTML
// yazımı value'yu sıfırlar + options getter'ı optgroup çocuklarını düzleştirir.
function selectStub() {
  const sel = makeElement('select');
  let html = '';
  Object.defineProperty(sel, 'innerHTML', {
    configurable: true,
    get: () => html,
    set(v) { html = String(v); sel.value = ''; },
  });
  Object.defineProperty(sel, 'options', {
    configurable: true,
    get: () => sel.children.flatMap(og => og.children),
  });
  return sel;
}

// ══════════════════════════════════════════════════════════════════════
// submitBulkCase — KISIR-DÜŞME (K6: bcChipEkle kisir taşır → 2529 filtresi)
// ══════════════════════════════════════════════════════════════════════
describe('submitBulkCase kısır-düşme (K6 — Ovsync + kısır işaretli chip)', () => {
  it('tek kısır hayvan + Ovsync hastalığı → toast basılır, RPC ATILMAZ (liste 0 kaldı)', async () => {
    const { sandbox, document, toasts, rpcCagrilar } = kur();
    hastalikSec(document, OVS_HASTALIK);
    sandbox.bcChipEkle({ id: 'H1', kupe_no: 'TR-1', cinsiyet: 'Dişi', kisir: true });

    await sandbox.submitBulkCase(null);

    const kisirToast = toasts.find(t => /kısır işaretli hayvan atlandı/.test(t.m));
    assert.ok(kisirToast, 'kısır-düşme toast basılmalı; gelen: ' + JSON.stringify(toasts));
    assert.match(kisirToast.m, /1 kısır işaretli hayvan atlandı/);
    assert.strictEqual(kisirToast.isErr, true);
    assert.deepStrictEqual(host(rpcCagrilar.map(c => c.name)), [], 'liste boşaldı — vaka_toplu_ac çağrılmaz');
  });

  it('karışık liste (kısır + değil) → yalnız kısır düşer, kalan TEK istekte gönderilir', async () => {
    const { sandbox, document, toasts, rpcCagrilar } = kur();
    hastalikSec(document, OVS_HASTALIK);
    sandbox.bcChipEkle({ id: 'H1', kupe_no: 'TR-1', cinsiyet: 'Dişi', kisir: true });
    sandbox.bcChipEkle({ id: 'H2', kupe_no: 'TR-2', cinsiyet: 'Dişi', kisir: false });

    await sandbox.submitBulkCase(null);

    assert.ok(toasts.some(t => /1 kısır işaretli hayvan atlandı/.test(t.m)), 'düşme bildirimi toast');
    const cagri = rpcCagrilar.find(c => c.name === 'vaka_toplu_ac');
    assert.ok(cagri, 'kalan hayvan için istek atılır');
    assert.strictEqual(rpcCagrilar.filter(c => c.name === 'vaka_toplu_ac').length, 1, 'tek istek');
    assert.deepStrictEqual(host(cagri.params.p_animal_ids), ['H2'], 'yalnız kısır olmayan gider');
    assert.strictEqual(cagri.params.p_disease_id, OVS_HASTALIK);
  });

  it('Ovsync DIŞI hastalık → kısır hayvan DÜŞMEZ, filtre toast yok (koşul aile-özel)', async () => {
    const { sandbox, document, toasts, rpcCagrilar } = kur();
    hastalikSec(document, 'DMET');
    sandbox.bcChipEkle({ id: 'H1', kupe_no: 'TR-1', cinsiyet: 'Dişi', kisir: true });

    await sandbox.submitBulkCase(null);

    assert.ok(!toasts.some(t => /kısır işaretli hayvan atlandı/.test(t.m)), 'Ovsync değil — toast olmaz');
    const cagri = rpcCagrilar.find(c => c.name === 'vaka_toplu_ac');
    assert.ok(cagri, 'istek atılır');
    assert.deepStrictEqual(host(cagri.params.p_animal_ids), ['H1'], 'kısır hayvan da gider');
  });
});

// ══════════════════════════════════════════════════════════════════════
// bcChipEkle — kisir alanı chip state'ine taşınır (K6 tek satırın kilidi)
// ══════════════════════════════════════════════════════════════════════
describe('bcChipEkle kisir taşınması (K6 — 2529 filtresinin girdisi)', () => {
  it('kisir:true → chip kisir:true; alan yoksa → false (boolean normalizasyon)', () => {
    const { sandbox } = kur();
    sandbox.globalThis._bcHayvanlar = null; // temiz başlangıç
    assert.strictEqual(sandbox.bcChipEkle({ id: 'H1', kupe_no: 'TR-1', kisir: true }), true);
    assert.strictEqual(sandbox.bcChipEkle({ id: 'H2', kupe_no: 'TR-2' }), true);
    assert.deepStrictEqual(host(sandbox.globalThis._bcHayvanlar.map(h => ({ id: h.id, kisir: h.kisir }))), [
      { id: 'H1', kisir: true },
      { id: 'H2', kisir: false },
    ]);
  });
});

// ══════════════════════════════════════════════════════════════════════
// loadDiseasesDropdown — K6 sertleştirme: yarış-guard + seçim-koruma
// ══════════════════════════════════════════════════════════════════════
describe('loadDiseasesDropdown yarış-guard (K6 — bayat doldurma yazmaz)', () => {
  it('çakışan iki çağrı: GEÇ tamamlanan (bayat) innerHTML/option YAZMAZ, son çağrı kazanır', async () => {
    const { sandbox, document } = kur({ idbTablolar: { diseases: [] } });
    // idbGetAll'i ertelenmiş yap: tamamlanma sırasını test belirler
    const bekleyen = [];
    sandbox.idbGetAll = async (t) => new Promise(res => bekleyen.push({ t, res }));

    const sel = selectStub();
    document.__setEl('d-disease-id', sel);

    const pEski = sandbox.loadDiseasesDropdown(); // çağrı 1 — bayatlayacak
    const pYeni = sandbox.loadDiseasesDropdown(); // çağrı 2 — kazanır
    assert.strictEqual(bekleyen.length, 2, 'her çağrı kendi diseases okumasını açar');

    bekleyen[1].res([{ id: 'YENI', name: 'Yeni Hastalık', category: 'Üreme' }]); // yeni önce biter
    await pYeni;
    bekleyen[0].res([{ id: 'ESKI', name: 'Eski Hastalık', category: 'Üreme' }]); // eski GEÇ biter
    await pEski;

    assert.deepStrictEqual(host(sel.options.map(o => o.value)), ['YENI'],
      'yalnız son çağrının option seti kalır — bayat doldurma append YOK');
  });
});

describe('loadDiseasesDropdown seçim-koruma (K6 — oncekiDeger)', () => {
  it('önceki değer yeni listede ETKİNSE geri konur (onDiseaseSelect zinciri gerekmez)', async () => {
    const { sandbox, document } = kur();
    const sel = selectStub();
    document.__setEl('d-disease-id', sel);
    sel.value = 'DMET';

    await sandbox.loadDiseasesDropdown();

    assert.strictEqual(sel.value, 'DMET', 'etkin seçim korunur');
  });

  it('kısır hayvanda kilitli (disabled) OVSYNC seçim geri KONMAZ — boşa düşer; C1 kilidi korunur', async () => {
    const { sandbox, document } = kur({ hayvan: { id: 'H9', kisir: true } });
    const hid = makeElement('input');
    hid.value = 'TR-9';
    document.__setEl('d-hid', hid); // aktifHayvan çözümü için küpe ref
    const sel = selectStub();
    document.__setEl('d-disease-id', sel);
    sel.value = OVS_HASTALIK;

    await sandbox.loadDiseasesDropdown();

    const dovOpt = sel.options.find(o => o.value === OVS_HASTALIK);
    assert.ok(dovOpt, 'Ovsync option listelenir (görünür ama kilitli)');
    assert.strictEqual(dovOpt.disabled, true, 'C1 kısır kilidi korunur');
    assert.match(dovOpt.textContent, /kısır işaretli — Ovsync protokolü açılamaz/);
    assert.notStrictEqual(sel.value, OVS_HASTALIK, 'kilitli değer geri konmaz');
    assert.strictEqual(sel.value, '', 'seçim boşa düşer — mevcut onDiseaseSelect zinciri yolu');
  });
});
