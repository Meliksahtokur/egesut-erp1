// tests/unit/vaka-toplu-ac.test.js
// G-20260906-TOPLU-VAKA — W3 (flow) birim testleri.
//
// Kapsam:
//   1. bcMukerrerBul(hayvanlar, cases, diseaseId) — IndexedDB mükerrer ön-kontrol
//      saf aynası: sunucu guard semantiği (cases.animal_id + cases.disease_id +
//      cases.status='active') birebir.
//   2. bcSonucSatirlari(result) — vaka_toplu_ac jsonb sonucunun render satır
//      haritası: acilan→{tip:'ok'}, atlanan→{tip:'atlanan'}, hatalar→{tip:'hata'};
//      sıra acilan→atlanan→hatalar; boş sonuç → [].
//   3. bcKupeParse(metin) — W2 helper'ının yeşil kilidi (satır/virgül/noktalı
//      virgül ayrımı, trim, boş at, dedupe — ilk geçiş sırası korunur).
//
//   4. V1.1 manuel ilaç yolu (W6): bcIlacSecilenler (p_items toplayıcısı),
//      bcSablonaDonustur + bcSablonIlacTemizle (şablon↔ilaç karşılıklı
//      dışlama), bcButonMetni (dinamik buton etiketi) ve bcSonucSatirlari
//      manuel uzantısı (acilan[i].manuel.seans_sayisi → ilacSayisi).
//
// Loader pattern: forms-validation.test.js ile birebir — forms.js vm'de yüklenir,
// db/rpc erişimi stub (gerçek Supabase çağrısı YOK, DOM submit YOK).
'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert');
const { loadBrowserModule, makeDomStub } = require('./support/loadModule.js');

// ── forms.js yükleme (saf helper'lar için minimal stub seti) ──────────
function setupForms() {
  const document = makeDomStub();
  const { sandbox } = loadBrowserModule('js/forms.js', {
    dom: document,
    extra: {
      db: { rpc: async () => ({ data: null, error: null }), from: () => { throw new Error('test stub'); } },
      g: (id) => document.getElementById(id),
      v: (id) => { const el = document.getElementById(id); return (el && el.value) || ''; },
      cl: () => {},
      esc: (s) => String(s || ''),
      escAttr: (s) => String(s || ''),
      getState: () => null,
      setState: () => {},
      toast: () => {},
      rpc: async () => ({}),
      idbGetAll: async () => [],
      getData: async () => [],
    },
  });
  return sandbox;
}

const sb = setupForms();

// Cross-realm: vm'de üretilen diziler farklı Array.prototype taşır —
// deepStrictEqual prototipleri de kıyasladığından host realm'ine çevrilir.
const host = (x) => JSON.parse(JSON.stringify(x ?? null));

// ══════════════════════════════════════════════════════════════════════
// bcMukerrerBul — aktif vaka mükerrer ön-kontrolü (sunucu guard aynası)
// ══════════════════════════════════════════════════════════════════════
describe('bcMukerrerBul (mükerrer aktif vaka ön-kontrolü)', () => {
  const DIS = 'disease-1';
  const hayvanlar = [
    { id: 'H1', kupe: 'TR-001' },
    { id: 'H2', kupe: 'TR-002' },
    { id: 'H3', kupe: 'TR-003' },
  ];
  const cases = [
    { animal_id: 'H1', disease_id: DIS, status: 'active' },
    { animal_id: 'H2', disease_id: DIS, status: 'closed' },
    { animal_id: 'H3', disease_id: 'disease-2', status: 'active' },
  ];

  it('yalnız aynı hayvan + aynı hastalık + status=active eşleşmesi döner', () => {
    const dups = sb.bcMukerrerBul(hayvanlar, cases, DIS);
    assert.deepStrictEqual(host(dups), [{ id: 'H1', kupe: 'TR-001' }]);
  });

  it('status=closed/kapanmış vaka mükerrer sayılmaz', () => {
    const dups = sb.bcMukerrerBul(
      [{ id: 'H2', kupe: 'TR-002' }],
      [{ animal_id: 'H2', disease_id: DIS, status: 'closed' }],
      DIS
    );
    assert.deepStrictEqual(host(dups), []);
  });

  it('farklı hastalıkta aktif vaka mükerrer sayılmaz', () => {
    const dups = sb.bcMukerrerBul(
      [{ id: 'H3', kupe: 'TR-003' }],
      [{ animal_id: 'H3', disease_id: 'baska-hastalik', status: 'active' }],
      DIS
    );
    assert.deepStrictEqual(host(dups), []);
  });

  it('birden fazla mükerrer — girdi sırası korunur, {id,kupe} alanlarıyla', () => {
    const dups = sb.bcMukerrerBul(
      hayvanlar,
      [
        { animal_id: 'H3', disease_id: DIS, status: 'active' },
        { animal_id: 'H1', disease_id: DIS, status: 'active' },
      ],
      DIS
    );
    assert.deepStrictEqual(host(dups), [
      { id: 'H1', kupe: 'TR-001' },
      { id: 'H3', kupe: 'TR-003' },
    ]);
  });

  it('mükerrer yoksa boş dizi döner', () => {
    const dups = sb.bcMukerrerBul(hayvanlar, [], DIS);
    assert.deepStrictEqual(host(dups), []);
  });

  it('null/undefined argümanlarda patlamaz', () => {
    assert.deepStrictEqual(host(sb.bcMukerrerBul(null, cases, DIS)), []);
    assert.deepStrictEqual(host(sb.bcMukerrerBul(hayvanlar, null, DIS)), []);
    assert.deepStrictEqual(host(sb.bcMukerrerBul(hayvanlar, cases, '')), []);
  });
});

// ══════════════════════════════════════════════════════════════════════
// bcSonucSatirlari — vaka_toplu_ac sonucu → render satır haritası
// ══════════════════════════════════════════════════════════════════════
describe('bcSonucSatirlari (RPC sonucu → satır haritası)', () => {
  it('acilan → tip:ok satırı (kupe taşınır)', () => {
    const rows = sb.bcSonucSatirlari({ ok: true, acilan: [{ kupe: 'TR-1', case_id: 'c1' }] });
    assert.deepStrictEqual(host(rows), [{ tip: 'ok', kupe: 'TR-1' }]);
  });

  it('atlanan → tip:atlanan satırı (kupe + mesaj taşınır)', () => {
    const rows = sb.bcSonucSatirlari({
      ok: true,
      atlanan: [{ kupe: 'TR-2', mesaj: 'Bu hayvan için zaten aktif bir Mastitis vakası mevcut' }],
    });
    assert.deepStrictEqual(host(rows), [{
      tip: 'atlanan', kupe: 'TR-2',
      mesaj: 'Bu hayvan için zaten aktif bir Mastitis vakası mevcut',
    }]);
  });

  it('hatalar → tip:hata satırı (mesaj taşınır)', () => {
    const rows = sb.bcSonucSatirlari({
      ok: true,
      hatalar: [{ kupe: 'TR-3', mesaj: 'STOK_YETERSIZ' }],
    });
    assert.deepStrictEqual(host(rows), [{ tip: 'hata', kupe: 'TR-3', mesaj: 'STOK_YETERSIZ' }]);
  });

  it('karışık sonuç — sıra sabit: acilan → atlanan → hatalar', () => {
    const rows = sb.bcSonucSatirlari({
      ok: true,
      hatalar: [{ kupe: 'TR-3', mesaj: 'şablon hatası' }],
      acilan: [
        { kupe: 'TR-1', case_id: 'c1' },
        { kupe: 'TR-4', case_id: 'c2' },
      ],
      atlanan: [{ kupe: 'TR-2', mesaj: 'zaten aktif' }],
    });
    assert.deepStrictEqual(host(rows.map(r => r.tip)), ['ok', 'ok', 'atlanan', 'hata']);
    assert.deepStrictEqual(host(rows.map(r => r.kupe ?? null)), ['TR-1', 'TR-4', 'TR-2', 'TR-3']);
  });

  it('boş/eksik diziler → []', () => {
    assert.deepStrictEqual(host(sb.bcSonucSatirlari({ ok: true, acilan: [], atlanan: [], hatalar: [] })), []);
    assert.deepStrictEqual(host(sb.bcSonucSatirlari({ ok: true })), []);
  });

  it('null sonuç → [] (patlamaz)', () => {
    assert.deepStrictEqual(host(sb.bcSonucSatirlari(null)), []);
  });
});

// ══════════════════════════════════════════════════════════════════════
// bcKupeParse — W2 helper'ının yeşil kilidi (yalnız ayrıştırma sözleşmesi)
// ══════════════════════════════════════════════════════════════════════
describe('bcKupeParse (yapıştırma kutusu token ayrıştırma)', () => {
  it('satır / virgül / noktalı virgül karışık ayırır', () => {
    assert.deepStrictEqual(
      host(sb.bcKupeParse('TR-1\nTR-2,TR-3;TR-4')),
      ['TR-1', 'TR-2', 'TR-3', 'TR-4']
    );
  });

  it('baş/son boşlukları kırpar, boş tokenları atar', () => {
    assert.deepStrictEqual(
      host(sb.bcKupeParse('  TR-1  \n\n  , TR-2 ,;')),
      ['TR-1', 'TR-2']
    );
  });

  it('aynı küpe tekrarı dedupe — ilk geçiş sırası korunur', () => {
    assert.deepStrictEqual(
      host(sb.bcKupeParse('TR-2\nTR-1\nTR-2, TR-1')),
      ['TR-2', 'TR-1']
    );
  });

  it('02 ≠ 2 — string eşleşme, sayısal normalizasyon YOK (domain kuralı)', () => {
    assert.deepStrictEqual(host(sb.bcKupeParse('02\n2')), ['02', '2']);
  });

  it('boş/null girdi → []', () => {
    assert.deepStrictEqual(host(sb.bcKupeParse('')), []);
    assert.deepStrictEqual(host(sb.bcKupeParse(null)), []);
    assert.deepStrictEqual(host(sb.bcKupeParse(undefined)), []);
  });
});

// ══════════════════════════════════════════════════════════════════════
// V1.1 (W6) — MANUEL İLAÇ YOLU
//
// forms.js ikinci kez yüklenir: DOM stub'ına selector→element kayıt haritası
// eklenir (document.querySelectorAll/querySelector override) + _drugsCache
// globali (bcIlacSecilenler stok_id/legacy çözümü için gerekli).
// ══════════════════════════════════════════════════════════════════════
function setupFormsIlac() {
  const document = makeDomStub();
  const qsMap = new Map();  // selector → element listesi (querySelectorAll)
  const q1Map = new Map();  // selector → tek element (querySelector)
  document.querySelectorAll = (sel) => qsMap.get(sel) || [];
  document.querySelector = (sel) => q1Map.get(sel) || null;
  const { sandbox } = loadBrowserModule('js/forms.js', {
    dom: document,
    extra: {
      db: { rpc: async () => ({ data: null, error: null }), from: () => { throw new Error('test stub'); } },
      g: (id) => document.getElementById(id),
      v: (id) => { const el = document.getElementById(id); return (el && el.value) || ''; },
      cl: () => {},
      esc: (s) => String(s || ''),
      escAttr: (s) => String(s || ''),
      getState: () => null,
      setState: () => {},
      toast: () => {},
      rpc: async () => ({}),
      idbGetAll: async () => [],
      getData: async () => [],
      pullTables: async () => {},
      openConfirm: () => {},
      getUserMessage: (e) => String(e?.message || e),
      hayvanByKupeRef: () => null,
      renderSafe: () => {},
      loadDrugsCache: async () => {},
      // bcIlacSecilenler stok çözümü: D1 → stok S1 (normal), L1 → legacy stok SL1
      _drugsCache: [
        { id: 'D1', stock_id: 'S1', _legacy: false },
        { id: 'L1', stock_id: 'SL1', _legacy: true },
      ],
    },
  });
  return { sandbox, document, qsMap, q1Map };
}

// checkbox stub'u — cdf-chk data sözleşmesi (data-id/name/unit/route/legacy)
function makeChk(document, qsMap, { id, name, unit = 'ml', route = 'IM', legacy = false, checked = true }) {
  const chk = document.createElement('input');
  chk.type = 'checkbox';
  chk.checked = checked;
  chk.dataset.id = id;
  chk.dataset.name = name;
  chk.dataset.unit = unit;
  chk.dataset.route = route;
  chk.dataset.legacy = String(legacy);
  if (checked) qsMap.set('.bc-ichk:checked', [...(qsMap.get('.bc-ichk:checked') || []), chk]);
  return chk;
}

// doz/birim/yol input stub'u — bc-irow satır inputları (id ile bulunur: g())
function makeRowInputs(document, id, { dose = '', unit = '', route = '' } = {}) {
  const mk = (suf, val) => {
    const el = document.createElement('input');
    el.value = val;
    document.__setEl('bc-i' + suf + '-' + id, el);
    return el;
  };
  return { doz: mk('doz', dose), unit: mk('unit', unit), rot: mk('rot', route) };
}

describe('bcIlacSecilenler (V1.1 — p_items toplayıcısı)', () => {
  it('geçerli seçim → sözleşme tam öğe: {drug_product_id, stok_id, dose:Number, unit, route}', () => {
    const { sandbox, document, qsMap } = setupFormsIlac();
    makeChk(document, qsMap, { id: 'D1', name: 'Baytril 10%' });
    makeRowInputs(document, 'D1', { dose: '12.5', unit: 'ml', route: 'IM' });
    const sec = sandbox.bcIlacSecilenler();
    assert.deepStrictEqual(host(sec), {
      hatalar: [],
      items: [{ drug_product_id: 'D1', stok_id: 'S1', dose: 12.5, unit: 'ml', route: 'IM' }],
    });
  });

  it('legacy ilaç → drug_product_id:null, stok_id stoktan çözülür', () => {
    const { sandbox, document, qsMap } = setupFormsIlac();
    makeChk(document, qsMap, { id: 'L1', name: 'Eski Stok İlacı', legacy: true });
    makeRowInputs(document, 'L1', { dose: '5', unit: 'ml', route: '' });
    const sec = sandbox.bcIlacSecilenler();
    assert.deepStrictEqual(host(sec), {
      hatalar: [],
      items: [{ drug_product_id: null, stok_id: 'SL1', dose: 5, unit: 'ml', route: null }],
    });
  });

  it('doz eksik → "İlaç adı: doz girin" hatası, öğe toplanmaz', () => {
    const { sandbox, document, qsMap } = setupFormsIlac();
    makeChk(document, qsMap, { id: 'D1', name: 'Baytril 10%' });
    makeRowInputs(document, 'D1', { dose: '', unit: 'ml', route: 'IM' });
    const sec = sandbox.bcIlacSecilenler();
    assert.deepStrictEqual(host(sec.hatalar), ['Baytril 10%: doz girin']);
    assert.deepStrictEqual(host(sec.items), []);
  });

  it('doz ≤ 0 / sayı olmayan → doz hatası sayılır', () => {
    const { sandbox, document, qsMap } = setupFormsIlac();
    makeChk(document, qsMap, { id: 'D1', name: 'Baytril 10%' });
    makeRowInputs(document, 'D1', { dose: '-2', unit: 'ml', route: 'IM' });
    assert.deepStrictEqual(host(sandbox.bcIlacSecilenler().hatalar), ['Baytril 10%: doz girin']);
  });

  it('birim eksik → "İlaç adı: birim girin" hatası', () => {
    const { sandbox, document, qsMap } = setupFormsIlac();
    makeChk(document, qsMap, { id: 'D1', name: 'Baytril 10%' });
    makeRowInputs(document, 'D1', { dose: '10', unit: '  ', route: 'IM' });
    const sec = sandbox.bcIlacSecilenler();
    assert.deepStrictEqual(host(sec.hatalar), ['Baytril 10%: birim girin']);
    assert.deepStrictEqual(host(sec.items), []);
  });

  it('hiç seçim yok → {hatalar:[], items:[]} (şablon yolu bozulmaz)', () => {
    const { sandbox, document, qsMap } = setupFormsIlac();
    const sec = sandbox.bcIlacSecilenler();
    assert.deepStrictEqual(host(sec), { hatalar: [], items: [] });
  });

  it('çoklu seçim — sıra korunur, satır hataları toplanır', () => {
    const { sandbox, document, qsMap } = setupFormsIlac();
    makeChk(document, qsMap, { id: 'D1', name: 'Baytril 10%' });
    makeRowInputs(document, 'D1', { dose: '10', unit: 'ml', route: 'IV' });
    makeChk(document, qsMap, { id: 'L1', name: 'Eski Stok İlacı', legacy: true });
    makeRowInputs(document, 'L1', { dose: '', unit: '', route: '' });
    const sec = sandbox.bcIlacSecilenler();
    assert.deepStrictEqual(host(sec.hatalar), [
      'Eski Stok İlacı: doz girin',
      'Eski Stok İlacı: birim girin',
    ]);
    assert.deepStrictEqual(host(sec.items.length), 1);
    assert.deepStrictEqual(host(sec.items[0].route), 'IV');
  });
});

describe('bcSablonaDonustur (V1.1 — ilaç→şablon karşılıklı dışlama)', () => {
  function sablonRadyolari(document, q1Map) {
    const rS1 = document.createElement('input');
    rS1.type = 'radio'; rS1.value = 'S1'; rS1.checked = true;
    const rBos = document.createElement('input');
    rBos.type = 'radio'; rBos.value = ''; rBos.checked = false;
    document.__setEl('bc-sablon-list', document.createElement('div'));
    const tumu = [rS1, rBos];
    document.querySelectorAll = (sel) =>
      sel === 'input[name="bc-sablon"]' ? tumu : (qsMap.get(sel) || []);
    q1Map.set('input[name="bc-sablon"][value=""]', rBos);
    return { rS1, rBos };
  }

  it('şablon seçiliyken ilaç işaretlenince Şablonsuz’a döner + state temizlenir', () => {
    const { sandbox, document, qsMap, q1Map } = setupFormsIlac();
    const { rS1, rBos } = sablonRadyolari(document, q1Map);
    sandbox.globalThis._bcSeciliSablonId = 'S1';
    const dondu = sandbox.bcSablonaDonustur();
    assert.strictEqual(dondu, true);
    assert.strictEqual(sandbox.globalThis._bcSeciliSablonId, null);
    assert.strictEqual(rBos.checked, true);
    assert.strictEqual(rS1.checked, false);
  });

  it('zaten Şablonsuz → no-op (true dönmez, radyolara dokunulmaz)', () => {
    const { sandbox, document, qsMap, q1Map } = setupFormsIlac();
    const { rS1, rBos } = sablonRadyolari(document, q1Map);
    rS1.checked = false; rBos.checked = true;
    sandbox.globalThis._bcSeciliSablonId = null;
    const dondu = sandbox.bcSablonaDonustur();
    assert.strictEqual(dondu, false);
    assert.strictEqual(sandbox.globalThis._bcSeciliSablonId, null);
    assert.strictEqual(rBos.checked, true);
  });

  it('radyo listesi hiç render edilmemişse patlamaz', () => {
    const { sandbox } = setupFormsIlac();
    sandbox.globalThis._bcSeciliSablonId = null;
    assert.doesNotThrow(() => sandbox.bcSablonaDonustur());
  });
});

describe('bcSablonIlacTemizle (V1.1 — şablon→ilaç karşılıklı dışlama)', () => {
  it('işaretli ilaç kutularını kapatır, doz alanını sıfırlar', () => {
    const { sandbox, document, qsMap } = setupFormsIlac();
    const chk = makeChk(document, qsMap, { id: 'D1', name: 'Baytril 10%' });
    const satirlar = document.createElement('div');
    satirlar.innerHTML = '<div id="bc-irow-D1"></div>';
    document.__setEl('bc-ilac-doz-satirlar', satirlar);
    const alan = document.createElement('div');
    alan.style.display = 'block';
    document.__setEl('bc-ilac-doz-alani', alan);
    sandbox.bcSablonIlacTemizle();
    assert.strictEqual(chk.checked, false);
    assert.strictEqual(satirlar.innerHTML, '');
    assert.strictEqual(alan.style.display, 'none');
  });
});

describe('bcButonMetni (V1.1 — dinamik buton etiketi)', () => {
  it('manuel ilaç yok → "🩺 Vakaları Aç"', () => {
    const { sandbox, document, qsMap } = setupFormsIlac();
    qsMap.set('.bc-ichk:checked', []);
    assert.strictEqual(sandbox.bcButonMetni(), '🩺 Vakaları Aç');
  });

  it('manuel ilaç var → "💊 Tedaviyi Uygula"', () => {
    const { sandbox, document, qsMap } = setupFormsIlac();
    makeChk(document, qsMap, { id: 'D1', name: 'Baytril 10%' });
    assert.strictEqual(sandbox.bcButonMetni(), '💊 Tedaviyi Uygula');
  });
});

describe('bcSonucSatirlari V1.1 uzantısı (manuel → ilacSayisi)', () => {
  it('acilan[i].manuel.seans_sayisi → ok satırına ilacSayisi olarak taşınır', () => {
    const rows = sb.bcSonucSatirlari({
      ok: true, manuel: true,
      acilan: [{ kupe: 'TR-9', case_id: 'c9', manuel: { day_no: 1, seans_sayisi: 3 } }],
    });
    assert.deepStrictEqual(host(rows), [{ tip: 'ok', kupe: 'TR-9', ilacSayisi: 3 }]);
  });

  it('manuel olmayan acilan satırı ilacSayisi TAŞIMAZ (eski sözleşme korunur)', () => {
    const rows = sb.bcSonucSatirlari({ ok: true, acilan: [{ kupe: 'TR-1', case_id: 'c1' }] });
    assert.strictEqual(Object.prototype.hasOwnProperty.call(rows[0], 'ilacSayisi'), false);
  });

  it('manuel var ama seans_sayisi eksik → ilacSayisi eklenmez (fallback)', () => {
    const rows = sb.bcSonucSatirlari({
      ok: true, manuel: true,
      acilan: [{ kupe: 'TR-2', case_id: 'c2', manuel: { day_no: 1 } }],
    });
    assert.strictEqual(Object.prototype.hasOwnProperty.call(rows[0], 'ilacSayisi'), false);
  });
});

// ══════════════════════════════════════════════════════════════════════
// V1.2 (W8) — TARİH PLANLAMA + TOHUMLAMA BÖLÜMÜ
//
// bcTohumUygunOlmayanlar(hayvanlar, hedefTarihStr): sunucu _tohumlama_
// gorev_uygunluk kurallarının istemci aynası — gebe istisna (sunucu teyitli).
// Tarih aritmetiği Date.UTC ile (TZ-safe); hedef tarih parametreden gelir,
// bugun() KULLANMAZ.
// ══════════════════════════════════════════════════════════════════════
describe('bcTohumUygunOlmayanlar (V1.2 — tohumlama uygunluk ön-kontrolü)', () => {
  const H = (over) => Object.assign({
    id: 'H1', kupe: 'TR-1', cinsiyet: 'Dişi', dogum_tarihi: '2022-01-01', durum: 'Aktif',
  }, over);

  it('erkek hayvan → sunucu cümlesi BİREBİR: "Erkek hayvana tohumlama görevi açılmaz"', () => {
    const r = sb.bcTohumUygunOlmayanlar([H({ cinsiyet: 'Erkek' })], '2027-01-01');
    assert.deepStrictEqual(host(r), [
      { id: 'H1', kupe: 'TR-1', sebep: 'Erkek hayvana tohumlama görevi açılmaz' },
    ]);
  });

  it('hedef tarihte yaş < 365 gün → "Hayvan hedef tarihte 12 aydan küçük"', () => {
    // 2026-01-01 doğumlu, hedef 2026-12-31 → 364 gün (< 365)
    const r = sb.bcTohumUygunOlmayanlar([H({ dogum_tarihi: '2026-01-01' })], '2026-12-31');
    assert.deepStrictEqual(host(r), [
      { id: 'H1', kupe: 'TR-1', sebep: 'Hayvan hedef tarihte 12 aydan küçük' },
    ]);
  });

  it('hedef tarihte yaş tam 365 gün → GEÇER (sınır: "12 aydan küçük" değil)', () => {
    // 2026-01-01 → 2027-01-01 = 365 gün (2026 artık yıl değil)
    const r = sb.bcTohumUygunOlmayanlar([H({ dogum_tarihi: '2026-01-01' })], '2027-01-01');
    assert.deepStrictEqual(host(r), []);
  });

  it('dogum_tarihi NULL → geçer (sunucu paritesi; yaş kontrolü atlanır)', () => {
    const r = sb.bcTohumUygunOlmayanlar([H({ dogum_tarihi: null })], '2026-12-31');
    assert.deepStrictEqual(host(r), []);
  });

  it('durum !== "Aktif" → "Hayvan aktif değil" (kural sırası: aktiflik önce)', () => {
    const r = sb.bcTohumUygunOlmayanlar(
      [H({ durum: 'Satıldı', cinsiyet: 'Erkek' })],
      '2027-01-01'
    );
    assert.deepStrictEqual(host(r), [
      { id: 'H1', kupe: 'TR-1', sebep: 'Hayvan aktif değil' },
    ]);
  });

  it('hedef tarih KULLANILIR, bugün kullanılmaz — aynı hayvan hedefe göre sonuç değişir', () => {
    const h = [H({ dogum_tarihi: '2026-01-01' })];
    const hedefteKucuk = sb.bcTohumUygunOlmayanlar(h, '2026-12-31'); // 364 gün → fail
    const hedefteYeterli = sb.bcTohumUygunOlmayanlar(h, '2027-01-01'); // 365 gün → pass
    assert.deepStrictEqual(host(hedefteKucuk.length), 1);
    assert.deepStrictEqual(host(hedefteYeterli), []);
  });

  it('karışık sürü — yalnız uygunsuzlar döner, girdi sırası korunur', () => {
    const suru = [
      H({ id: 'H1', kupe: 'TR-1' }),                                    // geçerli dişi
      H({ id: 'H2', kupe: 'TR-2', cinsiyet: 'Erkek' }),                 // erkek
      H({ id: 'H3', kupe: 'TR-3', dogum_tarihi: '2026-03-01' }),        // hedefte küçük
    ];
    const r = sb.bcTohumUygunOlmayanlar(suru, '2026-12-31');
    assert.deepStrictEqual(host(r), [
      { id: 'H2', kupe: 'TR-2', sebep: 'Erkek hayvana tohumlama görevi açılmaz' },
      { id: 'H3', kupe: 'TR-3', sebep: 'Hayvan hedef tarihte 12 aydan küçük' },
    ]);
  });

  it('boş liste / tümü geçerli → []', () => {
    assert.deepStrictEqual(host(sb.bcTohumUygunOlmayanlar([], '2027-01-01')), []);
    assert.deepStrictEqual(host(sb.bcTohumUygunOlmayanlar(null, '2027-01-01')), []);
  });
});

// ══════════════════════════════════════════════════════════════════════
// bcGecmisPlanTarihiMi (V1.2) — p_tarih geçmiş plan reddinin saf özü.
// YYYY-MM-DD string karşılaştırması; boş/null → false (NULL = bugün, sunucu).
// ══════════════════════════════════════════════════════════════════════
describe('bcGecmisPlanTarihiMi (V1.2 — geçmiş tarih erkenden reddi)', () => {
  it('dün → true', () => {
    assert.strictEqual(sb.bcGecmisPlanTarihiMi('2026-09-05', '2026-09-06'), true);
  });

  it('bugün → false (aynı gün planlanabilir)', () => {
    assert.strictEqual(sb.bcGecmisPlanTarihiMi('2026-09-06', '2026-09-06'), false);
  });

  it('yarın → false', () => {
    assert.strictEqual(sb.bcGecmisPlanTarihiMi('2026-09-07', '2026-09-06'), false);
  });

  it('boş/null → false (doğrulama yok — NULL=bugün sunucuda)', () => {
    assert.strictEqual(sb.bcGecmisPlanTarihiMi('', '2026-09-06'), false);
    assert.strictEqual(sb.bcGecmisPlanTarihiMi(null, '2026-09-06'), false);
    assert.strictEqual(sb.bcGecmisPlanTarihiMi(undefined, '2026-09-06'), false);
  });
});

// ══════════════════════════════════════════════════════════════════════
// bcSonucSatirlari V1.2 uzantısı — acilan[i].tohumlama → satıra ek anahtarlar
// (ADDITIVE: eski sözleşme satırlarında anahtar HİÇ görünmez)
// ══════════════════════════════════════════════════════════════════════
describe('bcSonucSatirlari V1.2 uzantısı (tohumlama alanları)', () => {
  it('tohumlama.olustu=true → satıra tohumlamaOlustu:true taşınır', () => {
    const rows = sb.bcSonucSatirlari({
      ok: true,
      acilan: [{ kupe: 'TR-1', case_id: 'c1', tohumlama: { olustu: true, gorev_id: 'g1' } }],
    });
    assert.deepStrictEqual(host(rows), [
      { tip: 'ok', kupe: 'TR-1', tohumlamaOlustu: true },
    ]);
  });

  it('tohumlama.olustu=false → satıra tohumlamaSebep taşınır', () => {
    const rows = sb.bcSonucSatirlari({
      ok: true,
      acilan: [{ kupe: 'TR-2', case_id: 'c2', tohumlama: { olustu: false, sebep: 'Hayvan gebe' } }],
    });
    assert.deepStrictEqual(host(rows), [
      { tip: 'ok', kupe: 'TR-2', tohumlamaSebep: 'Hayvan gebe' },
    ]);
  });

  it('tohumlama yoksa anahtarlar HİÇ eklenmez (eski sözleşme korunur)', () => {
    const rows = sb.bcSonucSatirlari({ ok: true, acilan: [{ kupe: 'TR-3', case_id: 'c3' }] });
    assert.strictEqual(Object.prototype.hasOwnProperty.call(rows[0], 'tohumlamaOlustu'), false);
    assert.strictEqual(Object.prototype.hasOwnProperty.call(rows[0], 'tohumlamaSebep'), false);
  });

  it('olustu=false ama sebep eksik → tohumlamaSebep eklenmez (fallback)', () => {
    const rows = sb.bcSonucSatirlari({
      ok: true,
      acilan: [{ kupe: 'TR-4', case_id: 'c4', tohumlama: { olustu: false } }],
    });
    assert.strictEqual(Object.prototype.hasOwnProperty.call(rows[0], 'tohumlamaSebep'), false);
  });
});
