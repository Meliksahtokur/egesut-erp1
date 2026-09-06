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
//   5. V2 (W10) gün plan editörü — V2.1'DE DEĞİŞTİ (aşağıda 6. bölüm): eski
//      W10 bcGunlardenItems (gün.saat + secili düzlemi) ve bcGunEkle/bcGunSil
//      ordinal renumbering testleri V2.1 uyarlamasıyla YENİDEN YAZILDI.
//      Korunan W10 birimleri: bcTohumBlokDurumu, bcManuelSatirEki,
//      bcSonucSatirlari çoklu gün uzantısı (gunSayisi).
//
//   6. V2.1 (W11) — plan editörü gün kartları + seans-grup dili:
//      boşluklu gün № (kullanıcı seçimi 1..31, takvimden/numaradan), bir
//      günde ÇOKLU SEANS (her seansın kendi saati; aynı ilaç farklı
//      seanslarda geçerli), gün kopyalama ([+ Gün ▾] → Önceki günden +
//      kart altı Günü Kopyala). Saf birimler: bcGunlardenItems v2
//      (seans-saat eşlemesi — kalem.saat HER ZAMAN seans saati, gün-düzlemi
//      saat gönderilmez), bcGunKopyala (değiştir/oluştur semantiği, saf),
//      bcTakvimdenGunler (tarih[] → gün №, pre-start filtreli, saf),
//      bcGunNoKontrol (aralık 1..31 + teklik, saf), bcGunSil (gün № KORUR —
//      renumber YOK), bcButonMetni (seans state'i), bcSablonIlacTemizle
//      (TÜM günlerin seanslarını temizler).
//
//   7. V2.1 (W12) — sonuç/uyarı düzeni: bcSonucBantlari (renkli grup
//      bantları — 'Açılan (N)' green → 'Atlanan (N)' amber → 'Hata (N)'
//      red; boş grup → bant yok; .arow/.arow-id/.arow-sub satır dili,
//      ok-satır ekleri V1.1/V1.2/V2 davranışını korur), bcTohumCakismaBul
//      (açık planlı tohumlama çakışma ön-kontrolü — UI-only, non-blocking;
//      cross-case tespit) ve bcTarihKisa (DD.AA).
//
//   V2→V2.1 ADAPTASYONLAR (bilinçli, iç şekil değişimi — her biri belgelendi):
//     a. bcGunlardenItems: state şekli secili→seanslar [{saat, ilaclar}].
//        Gün-düzlemi 'saat' alanı KALDIRILDI; kalem.saat ARTIK HER ZAMAN
//        seans saatini taşır (eski 'boş saat anahtarı eklenmez' sözleşmesinin
//        yerini 'kalem.saat hep dolu' aldı). Satır hataları gün+saat önekli:
//        'Gün N (<saat>): ...'. Boş gün hatası: 'Gün N: en az bir seans
//        ekleyin ya da günü silin'. Toplama ARTIK STATE-TABANLI (kalem
//        [Seansı Ekle] anında state'e yazılır) — DOM harvest stub'ları
//        (makeChk/makeRowInputs) kaldırıldı.
//     b. bcGunEkle/bcGunSil ordinal renumbering testleri KALDIRILDI — V2.1'de
//        gün № kullanıcı seçimidir (boşluklu plan 1,5 geçerli); silme diğer
//        numaraları KORUR. Yerine bcGunKopyala / bcTakvimdenGunler /
//        bcGunNoKontrol / bcGunSil-koruma testleri geldi.
//     c. bcSablonIlacTemizle: 'secili state temizliği' yerine TÜM günlerin
//        seanslarının temizliği + açık seans formunun kapanışı.
//     d. bcButonMetni: DOM checkbox sorgusu KALDIRILDI — yalnız seans
//        state'i sorgulanır (ilaç, [Seansı Ekle] onayına kadar state'e
//        yazılmaz; buton etiketi state'i yansıtır).
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
      // js/ui.js:68 band() şablonunun BİREBİR aynası — forms.js bunu global
      // olarak kullanır (ui.js forms.js'ten ÖNCE yüklenir); W12
      // bcSonucBantlari bant dilini buradan alır.
      band: (cls, title, content) =>
        `<div class="aband"><div class="aband-hdr ${cls}">${title}</div><div class="aband-body">${content}</div></div>`,
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
// V1.1 (W6) — MANUEL İLAÇ YOLU (V2.1'de plan editörü katmanına evrildi)
//
// forms.js ikinci kez yüklenir: _drugsCache globali (bcGunlardenItems v2
// stok_id/legacy çözümü için gerekli). V2.1'de plan TOPLAMASI STATE-TABANLI
// olduğundan checkbox/doz DOM stub'larına gerek kalmadı ([Seansı Ekle]
// anında kalem state'e yazılır; bcGunlardenItems yalnız _bcGunler okur).
// ══════════════════════════════════════════════════════════════════════
function setupFormsPlan() {
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
      pullTables: async () => {},
      openConfirm: () => {},
      getUserMessage: (e) => String(e?.message || e),
      hayvanByKupeRef: () => null,
      renderSafe: () => {},
      loadDrugsCache: async () => {},
      // bcGunlardenItems v2 stok çözümü: D1 → stok S1 (normal), L1 → legacy stok SL1
      _drugsCache: [
        { id: 'D1', stock_id: 'S1', _legacy: false },
        { id: 'L1', stock_id: 'SL1', _legacy: true },
      ],
    },
  });
  return { sandbox, document };
}

// seans state fabrikası — V2.1 gün.seanslar girdisi
function seans(saat, ilaclar) { return { saat, ilaclar }; }

// kalem state fabrikası — seans.ilaclar[drugId] girdisi ([Seansı Ekle]
// onayındaki çözümlü biçim). legacy/stock_id kasıtlı olarak BELİRTİLMEZ —
// bcGunlardenItems'in _drugsCache fallback yolunu egzersizler (gerçek
// akışta [Seansı Ekle] bunları çözerek yazar; state'te belirtilirse state kazanır).
function kalem(over = {}) {
  return Object.assign(
    { name: 'Baytril 10%', dose: '', unit: '', route: '' },
    over
  );
}

// state kurulum yardımcı — _bcGunler doğrudan sandbox'a yazılır
function gunle(sandbox, gunler) { sandbox.globalThis._bcGunler = gunler; }

// ══════════════════════════════════════════════════════════════════════
// V2.1 (W11) — bcGunlardenItems: seans-saat eşlemeli plan toplayıcısı.
// RPC v4 sözleşmesi DEVAM (gün-keyed p_items) ama saat düzlemi değişti:
//   [{gun: 1..31, kalemler: [{drug_product_id, stok_id, dose>0, unit,
//     route?, saat}]}] — kalem.saat HER ZAMAN seans saatidir (gün-düzlemi
//   'saat' alanı GÖNDERİLMEZ; 'replace-old-day-saat' semantiği).
// Doğrulama: seans saati regex (SS:DD); kalem doz>0/birim — hatalar
//   'Gün N (<saat>): ' önekli; seanssız gün (>1. gün planı varken)
//   'Gün N: en az bir seans ekleyin ya da günü silin'.
// TÜM günler boş → {hatalar:[], items:[]} (eski akış: vaka ilaçsız / şablon).
// Toplama STATE-TABANLI — DOM harvest yok.
// ══════════════════════════════════════════════════════════════════════
describe('bcGunlardenItems v2.1 (seans-saat eşlemeli plan toplayıcısı)', () => {
  it('tek gün tek seans → kalem.saat = seans saati; gün-düzlemi saat anahtarı YOK (replace-old-day-saat)', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 1, seanslar: [seans('08:00', { D1: kalem({ dose: '12.5', unit: 'ml', route: 'IM' }) })] }]);
    const sec = sandbox.bcGunlardenItems();
    assert.deepStrictEqual(host(sec), {
      hatalar: [],
      items: [{ gun: 1, kalemler: [{ drug_product_id: 'D1', stok_id: 'S1', dose: 12.5, unit: 'ml', route: 'IM', saat: '08:00' }] }],
    });
    assert.strictEqual(Object.prototype.hasOwnProperty.call(sec.items[0], 'saat'), false);
    assert.strictEqual(sec.items[0].kalemler[0].saat, '08:00');
  });

  it('aynı ilaç iki seanssa (seans A 08:00 + seans B 20:00) → iki kalem, her biri kendi seans saatiyle', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 1, seanslar: [
      seans('08:00', { D1: kalem({ dose: '10', unit: 'ml', route: 'IM' }) }),
      seans('20:00', { D1: kalem({ dose: '10', unit: 'ml', route: 'IM' }) }),
    ] }]);
    const sec = sandbox.bcGunlardenItems();
    assert.deepStrictEqual(host(sec.hatalar), []);
    assert.deepStrictEqual(host(sec.items[0].kalemler.map(k => k.saat)), ['08:00', '20:00']);
    assert.strictEqual(sec.items[0].kalemler.length, 2);
  });

  it('boşluklu günler (gun 1 + gun 5) → items gun sıralı ASC; her kalem kendi seans saatini taşır', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [
      { gun: 5, seanslar: [seans('16:30', { D1: kalem({ dose: '5', unit: 'ml', route: 'SC' }) })] },
      { gun: 1, seanslar: [seans('09:00', { D1: kalem({ dose: '10', unit: 'ml', route: 'IM' }) })] },
    ]);
    const sec = sandbox.bcGunlardenItems();
    assert.deepStrictEqual(host(sec.hatalar), []);
    assert.deepStrictEqual(host(sec.items.map(g => g.gun)), [1, 5]);
    assert.strictEqual(sec.items[0].kalemler[0].saat, '09:00');
    assert.strictEqual(sec.items[1].kalemler[0].saat, '16:30');
  });

  it('route boş → route:null ama kalem.saat YİNE dolu (saat her zaman set)', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 1, seanslar: [seans('09:00', { D1: kalem({ dose: '10', unit: 'ml', route: '' }) })] }]);
    const sec = sandbox.bcGunlardenItems();
    assert.strictEqual(sec.items[0].kalemler[0].route, null);
    assert.strictEqual(sec.items[0].kalemler[0].saat, '09:00');
  });

  it('doz eksik → "Gün 1 (08:00): <ad>: doz girin" — gün+saat önekli; kalem toplanmaz', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 1, seanslar: [seans('08:00', { D1: kalem({ dose: '', unit: 'ml', route: 'IM' }) })] }]);
    const sec = sandbox.bcGunlardenItems();
    assert.deepStrictEqual(host(sec.hatalar), ['Gün 1 (08:00): Baytril 10%: doz girin']);
    assert.deepStrictEqual(host(sec.items), []);
  });

  it('doz ≤ 0 → aynı gün+saat önekli doz hatası', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 3, seanslar: [seans('20:00', { D1: kalem({ dose: '-2', unit: 'ml', route: 'IM' }) })] }]);
    assert.deepStrictEqual(host(sandbox.bcGunlardenItems().hatalar), ['Gün 3 (20:00): Baytril 10%: doz girin']);
  });

  it('birim eksik → "Gün 2 (16:00): <ad>: birim girin"', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 2, seanslar: [seans('16:00', { D1: kalem({ dose: '10', unit: '  ', route: 'IM' }) })] }]);
    const sec = sandbox.bcGunlardenItems();
    assert.deepStrictEqual(host(sec.hatalar), ['Gün 2 (16:00): Baytril 10%: birim girin']);
    assert.deepStrictEqual(host(sec.items), []);
  });

  it('çoklu kalem bir seansta — sıra korunur, satır hataları toplanır (gün+saat önekli)', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 1, seanslar: [seans('08:00', {
      D1: kalem({ dose: '10', unit: 'ml', route: 'IV' }),
      L1: kalem({ name: 'Eski Stok İlacı', dose: '', unit: '', route: '' }),
    })] }]);
    const sec = sandbox.bcGunlardenItems();
    assert.deepStrictEqual(host(sec.hatalar), [
      'Gün 1 (08:00): Eski Stok İlacı: doz girin',
      'Gün 1 (08:00): Eski Stok İlacı: birim girin',
    ]);
    assert.strictEqual(sec.items.length, 1);
    assert.strictEqual(sec.items[0].kalemler.length, 1);
    assert.strictEqual(sec.items[0].kalemler[0].route, 'IV');
  });

  it('aradaki gün seanssız (gün 1 dolu, gün 5 boş) → "Gün 5: en az bir seans ekleyin ya da günü silin"; dolu gün toplanır', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [
      { gun: 1, seanslar: [seans('09:00', { D1: kalem({ dose: '10', unit: 'ml', route: 'IM' }) })] },
      { gun: 5, seanslar: [] },
    ]);
    const sec = sandbox.bcGunlardenItems();
    assert.deepStrictEqual(host(sec.hatalar), ['Gün 5: en az bir seans ekleyin ya da günü silin']);
    assert.strictEqual(sec.items.length, 1);
    assert.strictEqual(sec.items[0].gun, 1);
  });

  it('TÜM günler boş → {hatalar:[], items:[]} (eski akış korunur: vaka ilaçsız / şablon yolu)', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 1, seanslar: [] }, { gun: 5, seanslar: [] }]);
    assert.deepStrictEqual(host(sandbox.bcGunlardenItems()), { hatalar: [], items: [] });
  });

  it('_bcGunler tanımsız → {hatalar:[], items:[]} (patlamaz)', () => {
    const { sandbox } = setupFormsPlan();
    sandbox.globalThis._bcGunler = undefined;
    assert.deepStrictEqual(host(sandbox.bcGunlardenItems()), { hatalar: [], items: [] });
  });

  it('legacy ilaç → drug_product_id:null, stok_id cache\'ten çözülür, saat seansdan', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 1, seanslar: [seans('07:15', { L1: kalem({ name: 'Eski Stok İlacı', dose: '5', unit: 'ml', route: '' }) })] }]);
    const sec = sandbox.bcGunlardenItems();
    assert.deepStrictEqual(host(sec), {
      hatalar: [],
      items: [{ gun: 1, kalemler: [{ drug_product_id: null, stok_id: 'SL1', dose: 5, unit: 'ml', route: null, saat: '07:15' }] }],
    });
  });

  it('geçersiz seans saati → "Gün 1: geçersiz seans saati (25:99)"; boş saat → "Gün 1: seans saati girin"', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 1, seanslar: [seans('25:99', { D1: kalem({ dose: '10', unit: 'ml', route: 'IM' }) })] }]);
    assert.deepStrictEqual(host(sandbox.bcGunlardenItems().hatalar), ['Gün 1: geçersiz seans saati (25:99)']);
    gunle(sandbox, [{ gun: 1, seanslar: [seans('', { D1: kalem({ dose: '10', unit: 'ml', route: 'IM' }) })] }]);
    assert.deepStrictEqual(host(sandbox.bcGunlardenItems().hatalar), ['Gün 1: seans saati girin']);
  });
});

// ══════════════════════════════════════════════════════════════════════
// V2.1 (W11) — GÜN KARTLARI (boşluklu gün №) SAF BİRİMLERİ.
// Eski W10 bcGunEkle/bcGunSil ordinal renumbering sözleşmesi KALDIRILDI:
// V2.1'de gün № KULLANICI SEÇİMİDİR (boşluklu plan 1,5 geçerli); silme
// diğer numaraları KORUR. Yerine: bcGunKopyala (gün kopyalama butonu +
// önceki-günden menüsünün saf özü), bcTakvimdenGunler (takvimden gün
// ekleme saf özü), bcGunNoKontrol (gün № düzenleme doğrulaması),
// bcGunSil v2.1 (koruma semantiği).
// ══════════════════════════════════════════════════════════════════════
describe('bcGunKopyala (V2.1 saf — gün kopyalama: değiştir/oluştur)', () => {
  const kaynak = [
    { gun: 1, seanslar: [seans('08:00', { D1: kalem({ dose: '10', unit: 'ml', route: 'IM' }) })] },
    { gun: 5, seanslar: [] },
  ];

  it('hedef gün YOK → oluşturur (olusturuldu:true), ASC sıralı, seanslar kopyalanır', () => {
    const r = sb.bcGunKopyala(kaynak, 1, 3);
    assert.strictEqual(r.olusturuldu, true);
    assert.deepStrictEqual(host(r.gunler.map(g => g.gun)), [1, 3, 5]);
    assert.deepStrictEqual(host(r.gunler.find(g => g.gun === 3).seanslar), host(kaynak[0].seanslar));
  });

  it('hedef gün VAR → seansları DEĞİŞTİRİR (olusturuldu:false), diğer günler dokunulmaz', () => {
    const gunler = [
      { gun: 1, seanslar: [seans('08:00', { D1: kalem({ dose: '10', unit: 'ml', route: 'IM' }) })] },
      { gun: 3, seanslar: [seans('20:00', { L1: kalem({ name: 'Eski', dose: '1', unit: 'adet', route: 'PO' }) })] },
    ];
    const r = sb.bcGunKopyala(gunler, 1, 3);
    assert.strictEqual(r.olusturuldu, false);
    assert.deepStrictEqual(host(r.gunler.map(g => g.gun)), [1, 3]);
    assert.deepStrictEqual(host(r.gunler.find(g => g.gun === 3).seanslar), host(gunler[0].seanslar));
  });

  it('kaynak gün yok → null', () => {
    assert.strictEqual(sb.bcGunKopyala(kaynak, 9, 2), null);
  });

  it('hedef === kaynak → null', () => {
    assert.strictEqual(sb.bcGunKopyala(kaynak, 1, 1), null);
  });

  it('hedef 1..31 dışı / ondalık → null', () => {
    assert.strictEqual(sb.bcGunKopyala(kaynak, 1, 0), null);
    assert.strictEqual(sb.bcGunKopyala(kaynak, 1, 32), null);
    assert.strictEqual(sb.bcGunKopyala(kaynak, 1, 2.5), null);
  });

  it('girdi dizi MUTASYONLANMAZ (saf — kaynak dizide hiçbir değişiklik yok)', () => {
    const once = JSON.stringify(kaynak);
    sb.bcGunKopyala(kaynak, 1, 3);
    assert.strictEqual(JSON.stringify(kaynak), once);
  });

  it('deep-copy: sonucun seanslarını değiştirmek kaynağı bozmaz', () => {
    const r = sb.bcGunKopyala(kaynak, 1, 3);
    r.gunler.find(g => g.gun === 3).seanslar[0].saat = '23:59';
    assert.strictEqual(kaynak[0].seanslar[0].saat, '08:00');
  });

  it('boş seanslı gün de kopyalanır (saf semantiği total — boş-kaynak UI politikası ayrı)', () => {
    const r = sb.bcGunKopyala(kaynak, 5, 6);
    assert.strictEqual(r.olusturuldu, true);
    assert.deepStrictEqual(host(r.gunler.find(g => g.gun === 6).seanslar), []);
  });

  it('null girdi → null (patlamaz)', () => {
    assert.strictEqual(sb.bcGunKopyala(null, 1, 2), null);
  });
});

describe('bcTakvimdenGunler (V2.1 saf — takvim tarihleri → gün numaraları)', () => {
  it('başlangıç + ileri tarihler → gün = fark+1 (boşluklu plan: 1 ve 5)', () => {
    assert.deepStrictEqual(
      host(sb.bcTakvimdenGunler(['2026-09-06', '2026-09-10'], '2026-09-06')),
      [1, 5]
    );
  });

  it('başlangıçtan ÖNCEKİ tarihler filtrelenir (pre-start guard)', () => {
    assert.deepStrictEqual(
      host(sb.bcTakvimdenGunler(['2026-09-05', '2026-09-07'], '2026-09-06')),
      [2]
    );
  });

  it('dedupe + ASC sıralama (girdi sırası karışıksa bile)', () => {
    assert.deepStrictEqual(
      host(sb.bcTakvimdenGunler(['2026-09-10', '2026-09-08', '2026-09-08'], '2026-09-06')),
      [3, 5]
    );
  });

  it('ay/yıl sınırını doğru atar (UTC gün aritmetiği)', () => {
    assert.deepStrictEqual(
      host(sb.bcTakvimdenGunler(['2026-09-30', '2026-10-02'], '2026-09-28')),
      [3, 5]
    );
  });

  it('başlangıç tarihinin kendisi → gün 1 (dahil)', () => {
    assert.deepStrictEqual(host(sb.bcTakvimdenGunler(['2026-09-06'], '2026-09-06')), [1]);
  });

  it('boş liste / geçersiz başlangıç → []', () => {
    assert.deepStrictEqual(host(sb.bcTakvimdenGunler([], '2026-09-06')), []);
    assert.deepStrictEqual(host(sb.bcTakvimdenGunler(['2026-09-07'], '')), []);
    assert.deepStrictEqual(host(sb.bcTakvimdenGunler(null, '2026-09-06')), []);
  });
});

describe('bcGunNoKontrol (V2.1 saf — gün № düzenleme doğrulaması: aralık + teklik)', () => {
  const gunler = [{ gun: 1, seanslar: [] }, { gun: 5, seanslar: [] }];

  it('aralık içi + tek → {ok:true, mesaj:null}', () => {
    assert.deepStrictEqual(host(sb.bcGunNoKontrol(gunler, 1, 3)), { ok: true, mesaj: null });
  });

  it('kendi numarası → ok (kendisiyle çakışma sayılmaz)', () => {
    assert.deepStrictEqual(host(sb.bcGunNoKontrol(gunler, 0, 1)), { ok: true, mesaj: null }); // gün 1 kendisi
  });

  it('0 / 32 / ondalık → aralık hatası "Gün 1-31 aralığında bir tam sayı olmalı"', () => {
    for (const v of [0, 32, 2.5]) {
      const r = sb.bcGunNoKontrol(gunler, 1, v);
      assert.strictEqual(r.ok, false);
      assert.strictEqual(r.mesaj, 'Gün 1-31 aralığında bir tam sayı olmalı');
    }
  });

  it('mevcut başka günle çakışma → "Aynı gün zaten var; seansları o günün altında toplayın"', () => {
    const r = sb.bcGunNoKontrol(gunler, 0, 5); // gün 1 → 5'e taşınmak isteniyor
    assert.strictEqual(r.ok, false);
    assert.strictEqual(r.mesaj, 'Aynı gün zaten var; seansları o günün altında toplayın');
  });

  it('sayı olmayan giriş → aralık hatası', () => {
    assert.strictEqual(sb.bcGunNoKontrol(gunler, 0, 'abc').ok, false);
    assert.strictEqual(sb.bcGunNoKontrol(gunler, 0, '').ok, false);
    assert.strictEqual(sb.bcGunNoKontrol(gunler, 0, null).ok, false);
  });
});

describe('bcGunSil v2.1 (gün kartı silme: gün № KORUNUR, renumber YOK)', () => {
  it('aradaki gün silinir → diğer gün numaraları KORUNUR ([1,5] → sil 1 → [5])', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [
      { gun: 1, seanslar: [seans('08:00', { D1: kalem({ dose: '10', unit: 'ml' }) })] },
      { gun: 5, seanslar: [] },
    ]);
    sandbox.globalThis._bcAktifGunCard = 1;
    sandbox.bcGunSil(1);
    assert.deepStrictEqual(host(sandbox.globalThis._bcGunler.map(g => g.gun)), [5]);
  });

  it('boşluklu plandan orta gün silinir → kalanlar kendi № ile kalır ([1,3,5] → sil 3 → [1,5])', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 1, seanslar: [] }, { gun: 3, seanslar: [] }, { gun: 5, seanslar: [] }]);
    sandbox.bcGunSil(3);
    assert.deepStrictEqual(host(sandbox.globalThis._bcGunler.map(g => g.gun)), [1, 5]);
  });

  it('son gün silinirse tek boş gün 1 ile sıfırlanır (editörde en az bir gün kalır)', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 5, seanslar: [seans('08:00', {})] }]);
    sandbox.bcGunSil(5);
    assert.deepStrictEqual(host(sandbox.globalThis._bcGunler), [{ gun: 1, seanslar: [] }]);
  });

  it('silinen gün açıksa _bcAktifGunCard/_bcSeansFormGun temizlenir', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 1, seanslar: [] }, { gun: 3, seanslar: [] }]);
    sandbox.globalThis._bcAktifGunCard = 3;
    sandbox.globalThis._bcSeansFormGun = 3;
    sandbox.bcGunSil(3);
    assert.strictEqual(sandbox.globalThis._bcAktifGunCard, null);
    assert.strictEqual(sandbox.globalThis._bcSeansFormGun, null);
  });

  it('var olmayan gün № silinirse no-op', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 1, seanslar: [] }]);
    sandbox.bcGunSil(9);
    assert.strictEqual(sandbox.globalThis._bcGunler.length, 1);
  });
});

describe('bcSablonaDonustur (V1.1 — ilaç→şablon karşılıklı dışlama; V2.1 semantiği değişmedi)', () => {
  function sablonRadyolari(document) {
    const rS1 = document.createElement('input');
    rS1.type = 'radio'; rS1.value = 'S1'; rS1.checked = true;
    const rBos = document.createElement('input');
    rBos.type = 'radio'; rBos.value = ''; rBos.checked = false;
    document.__setEl('bc-sablon-list', document.createElement('div'));
    const tumu = [rS1, rBos];
    document.querySelectorAll = (sel) =>
      sel === 'input[name="bc-sablon"]' ? tumu : [];
    document.querySelector = (sel) =>
      sel === 'input[name="bc-sablon"][value=""]' ? rBos : null;
    return { rS1, rBos };
  }

  it('şablon seçiliyken ilaç işaretlenince Şablonsuz’a döner + state temizlenir', () => {
    const { sandbox, document } = setupFormsPlan();
    const { rS1, rBos } = sablonRadyolari(document);
    sandbox.globalThis._bcSeciliSablonId = 'S1';
    const dondu = sandbox.bcSablonaDonustur();
    assert.strictEqual(dondu, true);
    assert.strictEqual(sandbox.globalThis._bcSeciliSablonId, null);
    assert.strictEqual(rBos.checked, true);
    assert.strictEqual(rS1.checked, false);
  });

  it('zaten Şablonsuz → no-op (true dönmez, radyolara dokunulmaz)', () => {
    const { sandbox, document } = setupFormsPlan();
    const { rS1, rBos } = sablonRadyolari(document);
    rS1.checked = false; rBos.checked = true;
    sandbox.globalThis._bcSeciliSablonId = null;
    const dondu = sandbox.bcSablonaDonustur();
    assert.strictEqual(dondu, false);
    assert.strictEqual(sandbox.globalThis._bcSeciliSablonId, null);
    assert.strictEqual(rBos.checked, true);
  });

  it('radyo listesi hiç render edilmemişse patlamaz', () => {
    const { sandbox } = setupFormsPlan();
    sandbox.globalThis._bcSeciliSablonId = null;
    assert.doesNotThrow(() => sandbox.bcSablonaDonustur());
  });
});

// V2.1 ADAPTASYON: V2 testi 'TÜM günlerin secili state temizliği'
// assertion'ı içeriyordu; V2.1'de kalem state'i SEANSLARIN içindedir —
// assertion TÜM günlerin seanslarının temizlenmesi + açık seans formunun
// kapanması oldu (eski gün saati koruma cümlesi kaldırıldı: gün-düzlemi
// saat alanı V2.1'de yok).
describe('bcSablonIlacTemizle (V2.1 — şablon seçilince TÜM günlerin seansları temizlenir)', () => {
  it('bütün günlerin seansları silinir, açık seans formu kapanır', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [
      { gun: 1, seanslar: [seans('08:00', { D1: kalem({ dose: '5' }) })] },
      { gun: 5, seanslar: [seans('16:00', { L1: kalem({ dose: '2' }) }), seans('20:00', { D1: kalem({ dose: '3' }) })] },
    ]);
    sandbox.globalThis._bcSeansFormGun = 5;
    sandbox.bcSablonIlacTemizle();
    assert.deepStrictEqual(host(sandbox.globalThis._bcGunler.map(g => g.seanslar.length)), [0, 0]);
    assert.strictEqual(sandbox.globalThis._bcSeansFormGun, null);
  });

  it('state yokken patlamaz', () => {
    const { sandbox } = setupFormsPlan();
    sandbox.globalThis._bcGunler = undefined;
    assert.doesNotThrow(() => sandbox.bcSablonIlacTemizle());
  });
});

// V2.1 ADAPTASYON: V2 testi aktif günün DOM checkbox'larını da sorguluyordu;
// V2.1'de kalem yalnız [Seansı Ekle] onayıyla state'e yazıldığından etiket
// YALNIZ seans state'inden okunur (DOM sorgusu kaldırıldı).
describe('bcButonMetni (V2.1 — seans state tabanlı dinamik buton etiketi)', () => {
  it('herhangi bir günün herhangi bir seansında ilaç var → "💊 Tedaviyi Uygula"', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [
      { gun: 1, seanslar: [] },
      { gun: 5, seanslar: [seans('08:00', { D1: kalem({ dose: '5', unit: 'ml' }) })] },
    ]);
    assert.strictEqual(sandbox.bcButonMetni(), '💊 Tedaviyi Uygula');
  });

  it('boş seanslar → "🩺 Vakaları Aç" (boş ilaçlı seans etiketi değiştirmez)', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 1, seanslar: [] }, { gun: 5, seanslar: [seans('08:00', {})] }]);
    assert.strictEqual(sandbox.bcButonMetni(), '🩺 Vakaları Aç');
  });

  it('state yok → "🩺 Vakaları Aç" (patlamaz)', () => {
    const { sandbox } = setupFormsPlan();
    sandbox.globalThis._bcGunler = undefined;
    assert.strictEqual(sandbox.bcButonMetni(), '🩺 Vakaları Aç');
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

// ══════════════════════════════════════════════════════════════════════
// V2.1 (W12) — bcSonucBantlari: renkli grup bantları (owner-approved
// 'bantlı sonuç düzeni'). bcSonucSatirlari çıktısı üç banda ayrılır:
// 'Açılan (N)' → green, 'Atlanan (N)' → amber, 'Hata (N)' → red; sabit
// sıra; boş grup → bant YOK; eski tek-satır özet ('Toplam X · Açılan Y')
// kaldırıldı — sayaçlar bant başlıklarında. Satır dili dashboard aband
// gövdesiyle aynı (.arow / .arow-id bold + .arow-sub gri detay).
// ══════════════════════════════════════════════════════════════════════
describe('bcSonucBantlari (V2.1 — bantlı sonuç düzeni)', () => {
  const karisik = [
    { tip: 'ok', kupe: 'TR-1', tohumlamaOlustu: true },
    { tip: 'ok', kupe: 'TR-4', ilacSayisi: 5, gunSayisi: 3 },
    { tip: 'atlanan', kupe: 'TR-2', mesaj: 'zaten aktif vaka' },
    { tip: 'hata', kupe: 'TR-3', mesaj: 'şablon hatası' },
  ];

  it('bant başlıklarında sayaç var: Açılan (2) / Atlanan (1) / Hata (1)', () => {
    const html = sb.bcSonucBantlari(karisik, { acilan: [], tohumIste: false, tohumSaat: '08:00' });
    assert.match(html, /Açılan \(2\)/);
    assert.match(html, /Atlanan \(1\)/);
    assert.match(html, /Hata \(1\)/);
  });

  it('bant sırası sabit: Açılan (green) → Atlanan (amber) → Hata (red)', () => {
    const html = sb.bcSonucBantlari(karisik, { acilan: [] });
    const iA = html.indexOf('Açılan (2)');
    const iAt = html.indexOf('Atlanan (1)');
    const iH = html.indexOf('Hata (1)');
    assert.ok(iA !== -1 && iAt !== -1 && iH !== -1, 'üç bant da basılmalı');
    assert.ok(iA < iAt && iAt < iH, 'sıra Açılan → Atlanan → Hata olmalı');
    assert.match(html, /aband-hdr green/);
    assert.match(html, /aband-hdr amber/);
    assert.match(html, /aband-hdr red/);
  });

  it('boş grup → bant YOK', () => {
    const html = sb.bcSonucBantlari([{ tip: 'ok', kupe: 'TR-1' }], { acilan: [] });
    assert.match(html, /Açılan \(1\)/);
    assert.ok(!html.includes('Atlanan'), 'Atlanan bantı olmamalı');
    assert.ok(!html.includes('Hata ('), 'Hata bantı olmamalı');
  });

  it('hepsi boş → boş string', () => {
    assert.strictEqual(sb.bcSonucBantlari([], { acilan: [] }), '');
    assert.strictEqual(sb.bcSonucBantlari(undefined, null), '');
  });

  it('ok satırı: kupe .arow-id + detay .arow-sub (vaka açıldı + manuel/tohum ekleri)', () => {
    const html = sb.bcSonucBantlari(
      [{ tip: 'ok', kupe: 'TR-9', ilacSayisi: 5, gunSayisi: 3, tohumlamaOlustu: true }],
      { acilan: [{ kupe: 'TR-9', manuel: { gun_sayisi: 3, seans_sayisi: 5 } }], tohumIste: true, tohumSaat: '09:30' }
    );
    assert.match(html, /arow-id[^>]*>✅ TR-9</);
    assert.match(html, /arow-sub[^>]*>vaka açıldı \+ 3 gün · 5 ilaç/);
    assert.match(html, /🐄 tohumlama 09:30/);
  });

  it('ok satırı şablon yolu: "+ N gün şablon" eki korunur', () => {
    const html = sb.bcSonucBantlari(
      [{ tip: 'ok', kupe: 'TR-7' }],
      { acilan: [{ kupe: 'TR-7', sablon: { gun_sayisi: 2 } }] }
    );
    assert.match(html, /vaka açıldı \+ 2 gün şablon/);
  });

  it('ok satırı tohumlama olmadı + istek vardı → sebep eki (⏭)', () => {
    const html = sb.bcSonucBantlari(
      [{ tip: 'ok', kupe: 'TR-5', tohumlamaSebep: 'Hayvan gebe' }],
      { acilan: [], tohumIste: true, tohumSaat: '08:00' }
    );
    assert.match(html, /⏭ tohumlama: Hayvan gebe/);
  });

  it('atlanan satırı: ⏭ kupe (.arow-id) + mesaj (.arow-sub); hata satırı: ❌ mesaj', () => {
    const html = sb.bcSonucBantlari(
      [
        { tip: 'atlanan', kupe: 'TR-2', mesaj: 'zaten aktif vaka' },
        { tip: 'hata', kupe: 'TR-3', mesaj: 'STOK_YETERSIZ' },
      ],
      { acilan: [] }
    );
    assert.match(html, /arow-id[^>]*>⏭ TR-2</);
    assert.match(html, /arow-sub[^>]*>zaten aktif vaka</);
    assert.match(html, /arow-id[^>]*>❌ STOK_YETERSIZ</);
  });

  it('uzun liste: bant gövdesi kaydırma kutusu (max-height:220px + overflow-y:auto)', () => {
    const cok = Array.from({ length: 30 }, (_, i) => ({ tip: 'ok', kupe: 'TR-' + i }));
    const html = sb.bcSonucBantlari(cok, { acilan: [] });
    assert.match(html, /max-height:220px;overflow-y:auto/);
  });

  it('eski tek-satır özet dili YOK (sayaçlar yalnız bant başlığında)', () => {
    const html = sb.bcSonucBantlari(karisik, { acilan: [] });
    assert.ok(!html.includes('Toplam '), 'eski özet satırı dönmemeli');
  });
});

// ══════════════════════════════════════════════════════════════════════
// V2.1 (W12) — bcTohumCakismaBul: açık planlı tohumlama çakışma
// ön-kontrolü (UI-only, non-blocking — owner kararı). Seçili hayvandan
// OPEN gorev_log kaydı olanlar: gorev_tipi='TOHUMLAMA_PLANLI' (harf
// duyarsız — A1 denetim bulgusu), tamamlandi falsy + iptal falsy
// (kodbase konvansiyonu: forms.js:2372 '!tamamlandi && !iptal').
// Sunucu per-case soft-skip semantiği DEĞİŞMEZ; uyarı yalnız satır ekler.
// ══════════════════════════════════════════════════════════════════════
describe('bcTohumCakismaBul (V2.1 — açık planlı tohumlama çakışması)', () => {
  const hayvanlar = [
    { id: 'H1', kupe: 'TR-001' },
    { id: 'H2', kupe: 'TR-002' },
    { id: 'H3', kupe: 'TR-003' },
  ];
  const gorevler = [
    { hayvan_id: 'H1', gorev_tipi: 'TOHUMLAMA_PLANLI', tamamlandi: false, iptal: false, hedef_tarih: '2026-09-10' },
    { hayvan_id: 'H2', gorev_tipi: 'TOHUMLAMA_PLANLI', tamamlandi: true, iptal: false, hedef_tarih: '2026-09-10' },
    { hayvan_id: 'H3', gorev_tipi: 'ASI_PLANLI', tamamlandi: false, iptal: false, hedef_tarih: '2026-09-10' },
  ];

  it('açık (tamamlandi=false, iptal=false) TOHUMLAMA_PLANLI → {id, kupe, tarih}', () => {
    const cakisan = sb.bcTohumCakismaBul(hayvanlar, gorevler);
    assert.deepStrictEqual(host(cakisan), [{ id: 'H1', kupe: 'TR-001', tarih: '2026-09-10' }]);
  });

  it('tamamlandı / iptal görevleri çakışma sayılmaz', () => {
    const cakisan = sb.bcTohumCakismaBul(hayvanlar, [
      { hayvan_id: 'H1', gorev_tipi: 'TOHUMLAMA_PLANLI', tamamlandi: true, iptal: false, hedef_tarih: '2026-09-10' },
      { hayvan_id: 'H2', gorev_tipi: 'TOHUMLAMA_PLANLI', tamamlandi: false, iptal: true, hedef_tarih: '2026-09-11' },
    ]);
    assert.deepStrictEqual(host(cakisan), []);
  });

  it('cross-case tespiti: gorev_tipi büyük/küçük harf duyarsız', () => {
    const cakisan = sb.bcTohumCakismaBul(hayvanlar, [
      { hayvan_id: 'H2', gorev_tipi: 'tohumlama_planli', tamamlandi: false, iptal: false, hedef_tarih: '2026-09-12' },
    ]);
    assert.deepStrictEqual(host(cakisan), [{ id: 'H2', kupe: 'TR-002', tarih: '2026-09-12' }]);
  });

  it('başka görev tipi (ASI_PLANLI) çakışma sayılmaz', () => {
    const cakisan = sb.bcTohumCakismaBul(hayvanlar, [
      { hayvan_id: 'H3', gorev_tipi: 'ASI_PLANLI', tamamlandi: false, iptal: false, hedef_tarih: '2026-09-10' },
    ]);
    assert.deepStrictEqual(host(cakisan), []);
  });

  it('hedef_tarih yok → tarih null taşınır (satır yine üretilir)', () => {
    const cakisan = sb.bcTohumCakismaBul(hayvanlar, [
      { hayvan_id: 'H1', gorev_tipi: 'TOHUMLAMA_PLANLI', tamamlandi: false, iptal: false },
    ]);
    assert.deepStrictEqual(host(cakisan), [{ id: 'H1', kupe: 'TR-001', tarih: null }]);
  });

  it('görev yok / boş argümanlar → []', () => {
    assert.deepStrictEqual(host(sb.bcTohumCakismaBul(hayvanlar, [])), []);
    assert.deepStrictEqual(host(sb.bcTohumCakismaBul([], gorevler)), []);
    assert.deepStrictEqual(host(sb.bcTohumCakismaBul(null, null)), []);
  });
});

// V2.1 (W12) — bcTarihKisa: 'YYYY-MM-DD' → 'DD.AA' (uyarı satırı tarihi);
// boş / geçersiz → '—'.
describe('bcTarihKisa (V2.1 — DD.AA kısa tarih)', () => {
  it("'2026-09-10' → '10.09'", () => {
    assert.strictEqual(sb.bcTarihKisa('2026-09-10'), '10.09');
  });

  it('boş / geçersiz → —', () => {
    assert.strictEqual(sb.bcTarihKisa(''), '—');
    assert.strictEqual(sb.bcTarihKisa(null), '—');
    assert.strictEqual(sb.bcTarihKisa('10/09/2026'), '—');
  });
});
