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
//   4. V1.1 manuel ilaç yolu (W6): bcSablonaDonustur + bcSablonIlacTemizle
//      (şablon↔ilaç karşılıklı dışlama), bcButonMetni (dinamik buton
//      etiketi) ve bcSonucSatirlari manuel uzantısı (acilan[i].manuel.
//      seans_sayisi → ilacSayisi).
//
//   5. V2 çoklu gün plan editörü (W10): bcGunlardenItems (gün-keyed p_items
//      toplayıcısı; saat önceliği kalem>gün>09:00 sunucuda, istemci yalnız
//      dolu alanları taşır), bcGunEkle/bcGunSil (ordinal 1..N renumbering),
//      bcTohumBlokDurumu (keşfedilebilirlik durumu), bcManuelSatirEki
//      (' + N gün · M ilaç' metin kurucusu) ve bcButonMetni çoklu gün
//      uzantısı.
//
//   V1.1→V2 ADAPTASYONLAR (bilinçli, iç şekil değişimi — her biri belgelendi):
//     a. bcIlacSecilenler KALDIRILDI → bcGunlardenItems. Eski 8 testin
//        senaryoları gün-önekli hata dizeleriyle ('Gün N: ...') ve state
//        kurulumuyla yeniden yazıldı: geçerli seçim, legacy cache fallback,
//        doz/birim eksik (artık 'Gün N: ' önekli), hiç seçim (TÜM günler
//        boş → {hatalar:[], items:[]}), çoklu seçim sırası.
//     b. bcSablonIlacTemizle: 'alan.style.display=none' assertion'ı KALDIRILDI
//        (V2'de doz alanı hep görünür — gün plan editörü); yerine TÜM
//        günlerin secili state temizliği assertion'ı GEÇTİ.
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

// state kurulum yardımcı — _bcGunler/_bcAktifGun doğrudan sandbox'a yazılır
function gunle(sandbox, gunler, aktif = 1) {
  sandbox.globalThis._bcGunler = gunler;
  sandbox.globalThis._bcAktifGun = aktif;
}

// kalem state fabrikası — secili drugId → girdi (dose/birim henüz girilmemiş
// alanlar boş string; DOM satırı harvest'ı bcGunlardenItems içinde)
function kalem(over = {}) {
  return Object.assign(
    { name: 'Baytril 10%', dose: '', unit: '', route: '', saat: '' },
    over
  );
}

// ══════════════════════════════════════════════════════════════════════
// V2 (W10) — bcGunlardenItems: çoklu gün plan toplayıcısı.
// RPC v4 sözleşmesi: p_items GÜN-KEYED —
//   [{gun: 1..31, saat?: "HH:MM", kalemler: [{drug_product_id, stok_id,
//     dose>0, unit, route?, saat?}]}]
// planned_time önceliği SUNUCUDA: kalem.saat > gün.saat > '09:00'. İstemci
// yalnız DOLU alanları taşır (boş saat anahtarı hiç eklenmez).
// Tüm günler boş → {hatalar:[], items:[]} (eski akış: vaka ilaçsız / şablon).
// ══════════════════════════════════════════════════════════════════════
describe('bcGunlardenItems (V2 — çoklu gün plan toplayıcısı)', () => {
  it('tek gün, saat yok → {gun:1, kalemler:[...]} — day.saat/kalem.saat anahtarı HİÇ eklenmez (sunucu 09:00 varsayılanı)', () => {
    const { sandbox } = setupFormsIlac();
    gunle(sandbox, [{ gun: 1, saat: '', secili: { D1: kalem({ dose: '12.5', unit: 'ml', route: 'IM' }) } }]);
    const sec = sandbox.bcGunlardenItems();
    assert.deepStrictEqual(host(sec), {
      hatalar: [],
      items: [{ gun: 1, kalemler: [{ drug_product_id: 'D1', stok_id: 'S1', dose: 12.5, unit: 'ml', route: 'IM' }] }],
    });
    assert.strictEqual(Object.prototype.hasOwnProperty.call(sec.items[0], 'saat'), false);
    assert.strictEqual(Object.prototype.hasOwnProperty.call(sec.items[0].kalemler[0], 'saat'), false);
  });

  it('saat önceliği taşınır: kalem saati dolu → kalem.saat korunur, gün saati de ayrı gönderilir (öncelik sunucuda)', () => {
    const { sandbox } = setupFormsIlac();
    gunle(sandbox, [{ gun: 1, saat: '08:30', secili: { D1: kalem({ dose: '10', unit: 'ml', route: 'IM', saat: '07:15' }) } }]);
    const sec = sandbox.bcGunlardenItems();
    assert.strictEqual(sec.items[0].saat, '08:30');
    assert.strictEqual(sec.items[0].kalemler[0].saat, '07:15');
  });

  it('gün saati dolu, kalem saati boş → kalemde saat anahtarı YOK (gün saati o günün varsayılanı)', () => {
    const { sandbox } = setupFormsIlac();
    gunle(sandbox, [{ gun: 1, saat: '20:00', secili: { D1: kalem({ dose: '10', unit: 'ml', route: 'IM', saat: '' }) } }]);
    const sec = sandbox.bcGunlardenItems();
    assert.strictEqual(sec.items[0].saat, '20:00');
    assert.strictEqual(Object.prototype.hasOwnProperty.call(sec.items[0].kalemler[0], 'saat'), false);
  });

  it('çoklu gün — gun sıralı ordinals 1..N; gün saati yalnız dolu günde', () => {
    const { sandbox } = setupFormsIlac();
    gunle(sandbox, [
      { gun: 1, saat: '', secili: { D1: kalem({ dose: '10', unit: 'ml', route: 'IM' }) } },
      { gun: 2, saat: '16:00', secili: { D1: kalem({ dose: '5', unit: 'ml', route: 'SC', saat: '09:30' }) } },
    ]);
    const sec = sandbox.bcGunlardenItems();
    assert.deepStrictEqual(host(sec.hatalar), []);
    assert.deepStrictEqual(host(sec.items.map(g => g.gun)), [1, 2]);
    assert.strictEqual(Object.prototype.hasOwnProperty.call(sec.items[0], 'saat'), false);
    assert.strictEqual(sec.items[1].saat, '16:00');
    assert.strictEqual(sec.items[1].kalemler[0].saat, '09:30');
  });

  it('aktif günün DOM satırı harvest edilir: doz + per-kalem saat (bc-isaat-<id>-g<gun>) state\'e yazılır', () => {
    const { sandbox, document, qsMap } = setupFormsIlac();
    gunle(sandbox, [
      { gun: 1, saat: '', secili: { D1: kalem() } },
      { gun: 2, saat: '', secili: {} },
    ], 1);
    makeChk(document, qsMap, { id: 'D1', name: 'Baytril 10%' });
    makeRowInputs(document, 'D1', { dose: '12.5', unit: 'ml', route: 'IM' });
    const saatInp = document.createElement('input');
    saatInp.value = '06:30';
    document.__setEl('bc-isaat-D1-g1', saatInp);
    const sec = sandbox.bcGunlardenItems();
    assert.deepStrictEqual(host(sec.hatalar), ['Gün 2: en az bir ilaç seçin']);
    assert.deepStrictEqual(host(sec.items[0].kalemler[0]), {
      drug_product_id: 'D1', stok_id: 'S1', dose: 12.5, unit: 'ml', route: 'IM', saat: '06:30',
    });
  });

  it('gün 2 boş (gün 1 dolu) → hata "Gün 2: en az bir ilaç seçin"; dolu gün yine toplanır', () => {
    const { sandbox } = setupFormsIlac();
    gunle(sandbox, [
      { gun: 1, saat: '', secili: { D1: kalem({ dose: '10', unit: 'ml', route: 'IM' }) } },
      { gun: 2, saat: '', secili: {} },
    ]);
    const sec = sandbox.bcGunlardenItems();
    assert.deepStrictEqual(host(sec.hatalar), ['Gün 2: en az bir ilaç seçin']);
    assert.deepStrictEqual(host(sec.items.length), 1);
    assert.deepStrictEqual(host(sec.items[0].gun), 1);
  });

  it('TÜM günler boş → {hatalar:[], items:[]} (eski akış korunur: vaka ilaçsız / şablon yolu)', () => {
    const { sandbox } = setupFormsIlac();
    gunle(sandbox, [
      { gun: 1, saat: '', secili: {} },
      { gun: 2, saat: '08:00', secili: {} },
    ]);
    assert.deepStrictEqual(host(sandbox.bcGunlardenItems()), { hatalar: [], items: [] });
  });

  it('doz eksik → "Gün N: <ad>: doz girin" (gün önekli), öğe toplanmaz', () => {
    const { sandbox } = setupFormsIlac();
    gunle(sandbox, [{ gun: 1, saat: '', secili: { D1: kalem({ dose: '', unit: 'ml', route: 'IM' }) } }]);
    const sec = sandbox.bcGunlardenItems();
    assert.deepStrictEqual(host(sec.hatalar), ['Gün 1: Baytril 10%: doz girin']);
    assert.deepStrictEqual(host(sec.items), []);
  });

  it('doz ≤ 0 / sayı olmayan → gün önekli doz hatası sayılır', () => {
    const { sandbox } = setupFormsIlac();
    gunle(sandbox, [{ gun: 1, saat: '', secili: { D1: kalem({ dose: '-2', unit: 'ml', route: 'IM' }) } }]);
    assert.deepStrictEqual(host(sandbox.bcGunlardenItems().hatalar), ['Gün 1: Baytril 10%: doz girin']);
  });

  it('birim eksik → "Gün N: <ad>: birim girin"', () => {
    const { sandbox } = setupFormsIlac();
    gunle(sandbox, [{ gun: 1, saat: '', secili: { D1: kalem({ dose: '10', unit: '  ', route: 'IM' }) } }]);
    const sec = sandbox.bcGunlardenItems();
    assert.deepStrictEqual(host(sec.hatalar), ['Gün 1: Baytril 10%: birim girin']);
    assert.deepStrictEqual(host(sec.items), []);
  });

  it('legacy ilaç → drug_product_id:null, stok_id cache\'ten çözülür (state legacy/stock tanımsızsa cache fallback)', () => {
    const { sandbox } = setupFormsIlac();
    gunle(sandbox, [{ gun: 1, saat: '', secili: { L1: kalem({ name: 'Eski Stok İlacı', dose: '5', unit: 'ml', route: '' }) } }]);
    const sec = sandbox.bcGunlardenItems();
    assert.deepStrictEqual(host(sec), {
      hatalar: [],
      items: [{ gun: 1, kalemler: [{ drug_product_id: null, stok_id: 'SL1', dose: 5, unit: 'ml', route: null }] }],
    });
  });

  it('çoklu kalem — sıra korunur, satır hataları toplanır (V1.1 çoklu seçim senaryosunun V2 aynası)', () => {
    const { sandbox } = setupFormsIlac();
    gunle(sandbox, [{ gun: 1, saat: '', secili: {
      D1: kalem({ dose: '10', unit: 'ml', route: 'IV' }),
      L1: kalem({ name: 'Eski Stok İlacı', dose: '', unit: '', route: '' }),
    } }]);
    const sec = sandbox.bcGunlardenItems();
    assert.deepStrictEqual(host(sec.hatalar), [
      'Gün 1: Eski Stok İlacı: doz girin',
      'Gün 1: Eski Stok İlacı: birim girin',
    ]);
    assert.deepStrictEqual(host(sec.items.length), 1);
    assert.deepStrictEqual(host(sec.items[0].kalemler.length), 1);
    assert.deepStrictEqual(host(sec.items[0].kalemler[0].route), 'IV');
  });
});

// ══════════════════════════════════════════════════════════════════════
// V2 (W10) — bcGunEkle/bcGunSil: gün sekmesi mekaniği. Gün numaraları
// KULLANICI SEÇİMİ DEĞİL ordinal: ekleme sonuna ekler, silme sonrası 1..N
// yeniden numaralanır (RPC 'gun' alanı = ordinal). Maksimum 31 gün.
// ══════════════════════════════════════════════════════════════════════
describe('bcGunEkle/bcGunSil (V2 — gün ekleme/silme, ordinal renumbering)', () => {
  it('gün ekleme → sona ordinal gün ekler, aktif gün yeni güne geçer', () => {
    const { sandbox } = setupFormsIlac();
    gunle(sandbox, [{ gun: 1, saat: '', secili: {} }]);
    sandbox.bcGunEkle();
    assert.strictEqual(sandbox.globalThis._bcGunler.length, 2);
    assert.strictEqual(sandbox.globalThis._bcAktifGun, 2);
    assert.strictEqual(sandbox.globalThis._bcGunler[1].gun, 2);
    assert.deepStrictEqual(host(sandbox.globalThis._bcGunler[1].secili), {});
  });

  it('31 gün dolu → eklenmez, "⚠️ En fazla 31 gün" toastı', () => {
    const { sandbox } = setupFormsIlac();
    const toasts = [];
    sandbox.toast = (m) => { toasts.push(m); };
    gunle(sandbox, Array.from({ length: 31 }, (_, i) => ({ gun: i + 1, saat: '', secili: {} })));
    sandbox.bcGunEkle();
    assert.strictEqual(sandbox.globalThis._bcGunler.length, 31);
    assert.deepStrictEqual(host(toasts), ['⚠️ En fazla 31 gün']);
  });

  it('aktif gün silinir → kalan günler 1..N yeniden numaralanır (RPC gun = ordinal), aktif clamp edilir', () => {
    const { sandbox } = setupFormsIlac();
    gunle(sandbox, [
      { gun: 1, saat: '', secili: {} },
      { gun: 2, saat: '16:00', secili: { D1: kalem({ dose: '5', unit: 'ml', route: 'IM' }) } },
      { gun: 3, saat: '20:00', secili: {} },
    ], 2);
    sandbox.bcGunSil();
    const gunler = sandbox.globalThis._bcGunler;
    assert.deepStrictEqual(host(gunler.map(g => g.gun)), [1, 2]);
    assert.strictEqual(gunler[1].saat, '20:00'); // eski gün 3 → yeni gün 2
    assert.strictEqual(sandbox.globalThis._bcAktifGun, 2); // min(2, yeniN)
  });

  it('tek gün silinemez — no-op', () => {
    const { sandbox } = setupFormsIlac();
    gunle(sandbox, [{ gun: 1, saat: '08:00', secili: {} }]);
    sandbox.bcGunSil();
    assert.strictEqual(sandbox.globalThis._bcGunler.length, 1);
    assert.strictEqual(sandbox.globalThis._bcGunler[0].saat, '08:00');
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

describe('bcSablonIlacTemizle (V1.1 → V2 — şablon→ilaç karşılıklı dışlama)', () => {
  // V2 ADAPTASYON: V1.1 testi 'alan.style.display===none' assertion'ı içeriyordu;
  // V2'de doz alanı hep görünür (gün plan editörü) — assertion yerine TÜM
  // günlerin secili state temizliği kontrol edilir.
  it('işaretli kutuları kapatır, doz satırlarını sıfırlar, TÜM günlerin secili state\'ini temizler', () => {
    const { sandbox, document, qsMap } = setupFormsIlac();
    const chk = makeChk(document, qsMap, { id: 'D1', name: 'Baytril 10%' });
    const satirlar = document.createElement('div');
    satirlar.innerHTML = '<div id="bc-irow-D1"></div>';
    document.__setEl('bc-ilac-doz-satirlar', satirlar);
    gunle(sandbox, [
      { gun: 1, saat: '', secili: { D1: kalem({ dose: '5' }) } },
      { gun: 2, saat: '16:00', secili: { L1: kalem({ name: 'Eski', dose: '2' }) } },
    ], 1);
    sandbox.bcSablonIlacTemizle();
    assert.strictEqual(chk.checked, false);
    assert.strictEqual(satirlar.innerHTML, '');
    assert.deepStrictEqual(
      host(sandbox.globalThis._bcGunler.map(g => Object.keys(g.secili).length)),
      [0, 0]
    );
    assert.strictEqual(sandbox.globalThis._bcGunler[1].saat, '16:00'); // gün saati korunur
  });
});

describe('bcButonMetni (V1.1 → V2 — dinamik buton etiketi)', () => {
  it('manuel ilaç yok → "🩺 Vakaları Aç"', () => {
    const { sandbox, document, qsMap } = setupFormsIlac();
    qsMap.set('.bc-ichk:checked', []);
    assert.strictEqual(sandbox.bcButonMetni(), '🩺 Vakaları Aç');
  });

  it('manuel ilaç var (aktif gün DOM) → "💊 Tedaviyi Uygula"', () => {
    const { sandbox, document, qsMap } = setupFormsIlac();
    makeChk(document, qsMap, { id: 'D1', name: 'Baytril 10%' });
    assert.strictEqual(sandbox.bcButonMetni(), '💊 Tedaviyi Uygula');
  });

  it('V2 — ilaç yalnız BAŞKA bir günde (DOM boş) → "💊 Tedaviyi Uygula"', () => {
    const { sandbox, document, qsMap } = setupFormsIlac();
    qsMap.set('.bc-ichk:checked', []);
    gunle(sandbox, [
      { gun: 1, saat: '', secili: {} },
      { gun: 2, saat: '', secili: { D1: kalem({ dose: '5' }) } },
    ], 1);
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

// ══════════════════════════════════════════════════════════════════════
// V2 (W10) — bcTohumBlokDurumu: tohumlama bloğu keşfedilebilirlik durumu.
// Blok HER ZAMAN görünür; yalnız duruma göre disabled olur (eski
// display:none + silent-uncheck davranışı kaldırıldı — sahibi bulamıyordu).
//    disabled-bos   → seçim yok: 'Hayvan seçince aktifleşir'
//    disabled-erkek → tümü Erkek: kırmızı uyarı, hâlâ disabled
//    aktif          → orijinal uygunluk ipucu, tam opaklık
// Saf, DOM'suz.
// ══════════════════════════════════════════════════════════════════════
describe('bcTohumBlokDurumu (V2 — tohumlama bloğu keşfedilebilirliği)', () => {
  it('boş liste → {mod:"disabled-bos", ipucu:"Hayvan seçince aktifleşir"}', () => {
    assert.deepStrictEqual(host(sb.bcTohumBlokDurumu([])), {
      mod: 'disabled-bos',
      ipucu: 'Hayvan seçince aktifleşir',
    });
  });

  it('null/undefined → disabled-bos (patlamaz)', () => {
    assert.strictEqual(sb.bcTohumBlokDurumu(null).mod, 'disabled-bos');
    assert.strictEqual(sb.bcTohumBlokDurumu(undefined).mod, 'disabled-bos');
  });

  it('tümü Erkek → {mod:"disabled-erkek", ipucu:"Seçili hayvanların tümü erkek — tohumlama uygulanamaz"}', () => {
    const r = sb.bcTohumBlokDurumu([
      { id: 'H1', kupe: 'TR-1', cinsiyet: 'Erkek' },
      { id: 'H2', kupe: 'TR-2', cinsiyet: 'Erkek' },
    ]);
    assert.deepStrictEqual(host(r), {
      mod: 'disabled-erkek',
      ipucu: 'Seçili hayvanların tümü erkek — tohumlama uygulanamaz',
    });
  });

  it('en az bir dişi → {mod:"aktif", ipucu: orijinal uygunluk ipucu}', () => {
    const r = sb.bcTohumBlokDurumu([
      { id: 'H1', kupe: 'TR-1', cinsiyet: 'Erkek' },
      { id: 'H2', kupe: 'TR-2', cinsiyet: 'Dişi' },
    ]);
    assert.strictEqual(r.mod, 'aktif');
    assert.match(r.ipucu, /Erkek, 12 aydan küçük ve gebe/);
  });
});

// ══════════════════════════════════════════════════════════════════════
// V2 (W10) — bcSonucSatirlari çoklu gün uzantısı + bcManuelSatirEki.
// RPC v4: acilan[i].manuel = {gun_sayisi, seans_sayisi}. Ok satırı metni:
// '✅ <kupe> — vaka açıldı + N gün · M ilaç' (gün yoksa eski '+ M ilaç'
// fallback; hiçbiri yoksa ek yok).
// ══════════════════════════════════════════════════════════════════════
describe('bcSonucSatirlari V2 uzantısı (çoklu gün — gunSayisi)', () => {
  it('manuel {gun_sayisi, seans_sayisi} → satıra gunSayisi + ilacSayisi taşınır', () => {
    const rows = sb.bcSonucSatirlari({
      ok: true, manuel: true,
      acilan: [{ kupe: 'TR-9', case_id: 'c9', manuel: { gun_sayisi: 3, seans_sayisi: 5 } }],
    });
    assert.deepStrictEqual(host(rows), [
      { tip: 'ok', kupe: 'TR-9', ilacSayisi: 5, gunSayisi: 3 },
    ]);
  });

  it('gun_sayisi eksik → gunSayisi anahtarı HİÇ eklenmez (fallback)', () => {
    const rows = sb.bcSonucSatirlari({
      ok: true, manuel: true,
      acilan: [{ kupe: 'TR-2', case_id: 'c2', manuel: { seans_sayisi: 2 } }],
    });
    assert.strictEqual(Object.prototype.hasOwnProperty.call(rows[0], 'gunSayisi'), false);
  });
});

describe('bcManuelSatirEki (V2 — manuel ok-satırı metin kurucusu)', () => {
  it('gun + seans → " + 3 gün · 5 ilaç"', () => {
    assert.strictEqual(sb.bcManuelSatirEki({ gun_sayisi: 3, seans_sayisi: 5 }), ' + 3 gün · 5 ilaç');
  });

  it('yalnız seans → eski " + 5 ilaç" fallback', () => {
    assert.strictEqual(sb.bcManuelSatirEki({ seans_sayisi: 5 }), ' + 5 ilaç');
  });

  it('manuel yok / alanlar eksik → "" (ek yok)', () => {
    assert.strictEqual(sb.bcManuelSatirEki(undefined), '');
    assert.strictEqual(sb.bcManuelSatirEki(null), '');
    assert.strictEqual(sb.bcManuelSatirEki({}), '');
    assert.strictEqual(sb.bcManuelSatirEki({ gun_sayisi: 3 }), '');
  });
});
