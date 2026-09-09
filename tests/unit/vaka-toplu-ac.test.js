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
//   8. V2.2 (W13) — takvim ay-geçiş/gün-seçim düzeltmesi (sahibe hata
//      bildirimi: "takvimden seçimde sıkıntı — gün tıklanınca ay
//      değişiyor; ay değişince gün…"). Saf ay durum makinesi:
//      bcTakvimAyKaydir (yıl rollover'lı ay kaydırma), bcTakvimAyGosterim
//      (ayOffset → hücre matrisi; komşu-ay hücresi ÜRETİLMEZ), 
//      bcTakvimSecimEkle (toggle + min=başlangıç + maks=gün 31 = 
//      başlangıç+30 sınırları — SİNIRSIZ gün>31 seçimi HATASI burada
//      kilitlenir), bcTakvimBaslikTarihi (DD.MM.YYYY) ve 
//      bcTakvimChipEtiketi (DD.MM). DOM katmanı: ay ‹/› BC takvim
//      butonları artık bcTakvimAyDegistir üzerinden saf kaydırma kullanır
//      (inline _bcTkAy-- wrap matematiği KALDIRILDI); seçim Set'i ay
//      değişimlerinde DOKUNULMAZ.
//
//   9. V2.2.1 (W14) — sahibe onaylı ikili: P1 çoklu hedef gün kopyalama
//      (bcGunKopyalaCoklu — degisti[]/olusturuldu[] listeleri; W11
//      bcGunKopyala boolean sözleşmesi korunarak çoklu çekirdeğe delege),
//      P2 sonuç satırı → hayvan kartı (bcSonucSatirlari hayvanId + 
//      bcSonucBantlari data-action="bc-sonuc-hayvan" satır affordance'ı).
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
const vm = require('node:vm');
const { loadBrowserModule, makeDomStub, makeElement } = require('./support/loadModule.js');

// ── forms.js yükleme (saf helper'lar için minimal stub seti) ──────────
function setupForms() {
  const document = makeDomStub();
  const toasts = [];
  const { sandbox } = loadBrowserModule('js/forms.js', {
    dom: document,
    extra: {
      db: { rpc: async () => ({ data: null, error: null }), from: () => { throw new Error('test stub'); } },
      // js/utils/helpers.js:15-17 birebir — takvim yolları bugun()/dFwd kullanır
      bugun: () => {
        const d = new Date();
        return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
      },
      dFwd: (base, n) => {
        const d = base ? new Date(base + 'T00:00:00') : new Date();
        d.setDate(d.getDate() + n);
        return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
      },
      g: (id) => document.getElementById(id),
      v: (id) => { const el = document.getElementById(id); return (el && el.value) || ''; },
      toast: (m, isErr) => toasts.push({ m: String(m), isErr: !!isErr }),
      cl: () => {},
      esc: (s) => String(s || ''),
      escAttr: (s) => String(s || ''),
      getState: () => null,
      setState: () => {},
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
  sandbox.__toasts = toasts; // W13: takvim toast iddiaları için canlı yakalama
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

// ══════════════════════════════════════════════════════════════════════
// V2.2 (W13) — bc-gun-takvim ay-geçiş/gün-seçim durumu
// Sahibe hata bildirimi: "takvimden seçimde sıkıntı — gün tıklanınca ay
// değişiyor; ay değişince gün…". RED-ÖNCE: aşağıdaki testler düzeltmeden
// ÖNCE yazıldı ve mevcut kodda KIRMIZI çıktı (ay durum matematiği inline
// onclick string'lerinde gömülü + gün>31 üst sınırı YOK).
//
// Saf yüzey (js/forms.js):
//   bcTakvimAyKaydir(yil, ayIdx, delta)     → { yil, ay }   yıl rollover'lı
//   bcTakvimAyGosterim(baslangic, ayOffset) → { yil, ay, etiket, bosluk,
//        hucreler:[{gunNo, tarihISO, disiMi}] }  — komşu-ay hücresi üretilmez
//   bcTakvimSecimEkle(secimler, iso, bas)   → { ok, eklendi, secimler, mesaj }
//   bcTakvimBaslikTarihi(str)               → 'DD.MM.YYYY'
//   bcTakvimChipEtiketi(iso)                → 'DD.MM'
// ══════════════════════════════════════════════════════════════════════

// Takvim modül state'ine CANLI erişim (vm üst-seviye let — snapshot değil).
// Ay durumu TEK skalerdir: _bcTkOffset (0 = başlangıç ayı; ‹/› ±1) —
// görüntülenen yıl/ay SAF bcTakvimAyGosterim'den türetilir (kilit: rollover
// matematiği DOM'da DEĞİL).
function tkDurum(baslangic) {
  const ham = vm.runInContext('({ offset: _bcTkOffset, secili: [..._bcTkSecili] })', sb);
  const gost = host(sb.bcTakvimAyGosterim(baslangic, ham.offset));
  return { ...ham, ay: gost.ay, yil: gost.yil, etiket: gost.etiket };
}

// bcTakvimAc'yı bc-tarih input'u ile aç ve modal kutusunu döndür.
// Gerçek tarayıcıda getElementById appendChild'la eklenen elemanları bulur;
// makeDomStub yalnız __setEl ile kaydedilenleri bulur — tarayıcıya sadık
// köprü (yoksa her render yeni kutu yaratır ve referans bayatlar).
// V2.3-W20: başlangıç artık TEK kapıdan yazılır (bcTarihYaz — görüntü TR +
// kanonik ISO); eski el.value = tarih ataması v('bc-tarih') okumasıyla
// birlikte kalktı.
function takvimAc(tarih) {
  const el = makeElement('input');
  sb.document.__setEl('bc-tarih', el);
  sb.bcTarihYaz(tarih);
  if(!sb.document.__getByIdKoprulu){
    const origGet = sb.document.getElementById.bind(sb.document);
    sb.document.getElementById = (id) => origGet(id) || sb.document.body.children.find(c => c.id === id) || null;
    sb.document.__getByIdKoprulu = true;
  }
  sb.bcTakvimAc();
  const kutu = sb.document.getElementById('bc-gun-takvim');
  assert.strictEqual(kutu.id, 'bc-gun-takvim');
  return kutu;
}

describe('bcTakvimAyKaydir (V2.2 saf — yıl rollover\'lı ay kaydırma)', () => {
  it('ay içi kaydırma: Ağustos 2026 +1 → Eylül 2026', () => {
    assert.deepStrictEqual(host(sb.bcTakvimAyKaydir(2026, 7, 1)), { yil: 2026, ay: 8 });
  });

  it('yıl sınırı İLERİ: Aralık 2026 +1 → Ocak 2027', () => {
    assert.deepStrictEqual(host(sb.bcTakvimAyKaydir(2026, 11, 1)), { yil: 2027, ay: 0 });
  });

  it('yıl sınırı GERİ: Ocak 2027 -1 → Aralık 2026', () => {
    assert.deepStrictEqual(host(sb.bcTakvimAyKaydir(2027, 0, -1)), { yil: 2026, ay: 11 });
  });

  it('çok adımlı ileri: Eylül 2026 +16 → Ocak 2028', () => {
    assert.deepStrictEqual(host(sb.bcTakvimAyKaydir(2026, 8, 16)), { yil: 2028, ay: 0 });
  });

  it('çok adımlı geri: Eylül 2026 -20 → Ocak 2025', () => {
    assert.deepStrictEqual(host(sb.bcTakvimAyKaydir(2026, 8, -20)), { yil: 2025, ay: 0 });
  });
});

describe('bcTakvimAyGosterim (V2.2 saf — ayOffset → hücre matrisi)', () => {
  it('offset 0: başlangıç ayı — 30 hücre, Eylül 2026, Pazartesi-bazlı 1 boşluk (1 Eylül Salı)', () => {
    const g = host(sb.bcTakvimAyGosterim('2026-09-06', 0));
    assert.strictEqual(g.yil, 2026);
    assert.strictEqual(g.ay, 8);
    assert.strictEqual(g.etiket, 'Eylül 2026');
    assert.strictEqual(g.bosluk, 1);
    assert.strictEqual(g.hucreler.length, 30);
    assert.deepStrictEqual(g.hucreler[0], { gunNo: 1, tarihISO: '2026-09-01', disiMi: false });
    assert.deepStrictEqual(g.hucreler[29], { gunNo: 30, tarihISO: '2026-09-30', disiMi: false });
  });

  it('komşu-ay hücresi ÜRETİLMEZ: tüm tarihISO görüntülenen aydan (gün tıkının yanlış aya düşmesi kilitlenir)', () => {
    for (const off of [-1, 0, 1, 2]) {
      const g = host(sb.bcTakvimAyGosterim('2026-09-06', off));
      const onEk = g.yil + '-' + String(g.ay + 1).padStart(2, '0') + '-';
      for (const h of g.hucreler) {
        assert.ok(h.tarihISO.startsWith(onEk), 'offset ' + off + ' hücre taşması: ' + h.tarihISO);
        assert.strictEqual(h.disiMi, false);
      }
    }
  });

  it('offset +1: Ekim 2026 — 31 hücre, 3 boşluk (1 Ekim Perşembe)', () => {
    const g = host(sb.bcTakvimAyGosterim('2026-09-06', 1));
    assert.strictEqual(g.etiket, 'Ekim 2026');
    assert.strictEqual(g.bosluk, 3);
    assert.strictEqual(g.hucreler.length, 31);
    assert.strictEqual(g.hucreler[0].tarihISO, '2026-10-01');
  });

  it('offset yıl atlar: 2026-12-15 başlangıç, +1 → Ocak 2027 (etiket + yıl doğru)', () => {
    const g = host(sb.bcTakvimAyGosterim('2026-12-15', 1));
    assert.strictEqual(g.yil, 2027);
    assert.strictEqual(g.ay, 0);
    assert.strictEqual(g.etiket, 'Ocak 2027');
    assert.strictEqual(g.hucreler[0].tarihISO, '2027-01-01');
  });

  it('negatif offset yıl atlar: 2026-12-15 başlangıç, -1 → Kasım 2026; 2027-01-10, -1 → Aralık 2026', () => {
    const g1 = host(sb.bcTakvimAyGosterim('2026-12-15', -1));
    assert.strictEqual(g1.etiket, 'Kasım 2026');
    const g2 = host(sb.bcTakvimAyGosterim('2027-01-10', -1));
    assert.strictEqual(g2.yil, 2026);
    assert.strictEqual(g2.ay, 11);
    assert.strictEqual(g2.etiket, 'Aralık 2026');
  });

  it('12 ay etiketinin tamamı Türkçe + yıl taşımalı', () => {
    const beklenen = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    for (let i = 0; i < 12; i++) {
      const g = host(sb.bcTakvimAyGosterim('2026-01-01', i));
      assert.ok(g.etiket.startsWith(beklenen[i]), i + ' → ' + g.etiket);
      assert.ok(g.etiket.endsWith('2026'), i + ' → ' + g.etiket);
    }
  });

  it('geçersiz başlangıç → bugün ayına düşer (patlamaz)', () => {
    const g = host(sb.bcTakvimAyGosterim('', 0));
    assert.strictEqual(g.hucreler.length >= 28 && g.hucreler.length <= 31, true);
    assert.strictEqual(g.bosluk >= 0 && g.bosluk <= 6, true);
  });
});

describe('bcTakvimSecimEkle (V2.2 saf — toggle + min/maks doğrulama)', () => {
  const BAS = '2026-09-06';

  it('geçerli gün eklenir → ASC dizide birebir aynı ISO (başka ay görünümündeki gün YANLIŞ aya düşmez; 2026-10-05 = Gün 30 ≤ 31)', () => {
    const r = host(sb.bcTakvimSecimEkle(['2026-09-15'], '2026-10-05', BAS));
    assert.strictEqual(r.ok, true);
    assert.strictEqual(r.eklendi, true);
    assert.deepStrictEqual(r.secimler, ['2026-09-15', '2026-10-05']);
  });

  it('mevcut seçim toggle → çıkarılır (eklendi:false)', () => {
    const r = host(sb.bcTakvimSecimEkle(['2026-09-15', '2026-09-20'], '2026-09-15', BAS));
    assert.strictEqual(r.ok, true);
    assert.strictEqual(r.eklendi, false);
    assert.deepStrictEqual(r.secimler, ['2026-09-20']);
  });

  it('başlangıçtan ÖNCEKİ gün reddedilir + mesaj + seçimler değişmez', () => {
    const mevcut = ['2026-09-10'];
    const r = host(sb.bcTakvimSecimEkle(mevcut, '2026-09-01', BAS));
    assert.strictEqual(r.ok, false);
    assert.ok(r.mesaj && r.mesaj.length > 0);
    assert.deepStrictEqual(r.secimler, ['2026-09-10']);
  });

  it('gün 31 SINIRI (başlangıç+30): 2026-10-06 → ok', () => {
    const r = host(sb.bcTakvimSecimEkle([], '2026-10-06', BAS));
    assert.strictEqual(r.ok, true);
    assert.deepStrictEqual(r.secimler, ['2026-10-06']);
  });

  it('gün 32 (başlangıç+31) REDDEDİLİR — sınırsız gün>31 seçimi HATASI kilitlenir', () => {
    const r = host(sb.bcTakvimSecimEkle([], '2026-10-07', BAS));
    assert.strictEqual(r.ok, false);
    assert.ok(/31/.test(r.mesaj), 'mesaj sınırı açıklar: ' + r.mesaj);
    assert.deepStrictEqual(r.secimler, []);
  });

  it('çok ileri tarih (gün 40 = 2026-10-15) reddedilir', () => {
    const r = host(sb.bcTakvimSecimEkle([], '2026-10-15', BAS));
    assert.strictEqual(r.ok, false);
  });

  it('yıl sınırında sınır kontrolü: 2026-12-20 başlangıç → 2027-01-19 gün 31 ok, 2027-01-20 gün 32 red', () => {
    assert.strictEqual(host(sb.bcTakvimSecimEkle([], '2027-01-19', '2026-12-20')).ok, true);
    assert.strictEqual(host(sb.bcTakvimSecimEkle([], '2027-01-20', '2026-12-20')).ok, false);
  });

  it('geçersiz başlangıç → red (mesajlı), seçim eklenmez', () => {
    const r = host(sb.bcTakvimSecimEkle([], '2026-10-07', ''));
    assert.strictEqual(r.ok, false);
    assert.deepStrictEqual(r.secimler, []);
  });
});

describe('bcTakvimBaslikTarihi + bcTakvimChipEtiketi (V2.2 saf — TR tarih biçimi)', () => {
  it("bcTakvimBaslikTarihi('2026-09-06') → '06.09.2026' (YYYY-MM-DD değil)", () => {
    assert.strictEqual(sb.bcTakvimBaslikTarihi('2026-09-06'), '06.09.2026');
  });

  it("bcTakvimBaslikTarihi('') ve geçersiz → bugün DD.MM.YYYY biçiminde", () => {
    assert.match(sb.bcTakvimBaslikTarihi(''), /^\d{2}\.\d{2}\.\d{4}$/);
    assert.match(sb.bcTakvimBaslikTarihi('10/09/2026'), /^\d{2}\.\d{2}\.\d{4}$/);
    assert.match(sb.bcTakvimBaslikTarihi(null), /^\d{2}\.\d{2}\.\d{4}$/);
  });

  it("bcTakvimChipEtiketi('2026-10-15') → '15.10' (GÜN.AY — eski '10.15' ters okuma kilitlenir)", () => {
    assert.strictEqual(sb.bcTakvimChipEtiketi('2026-10-15'), '15.10');
    assert.strictEqual(sb.bcTakvimChipEtiketi('2026-09-06'), '06.09');
  });
});

describe('bc-gun-takvim DOM davranışı (V2.2 — ay geçişi + seçim kalıcılığı + toast)', () => {
  it('gün tıklanınca GÖRÜNTÜLENEN AY KORUNUR (sahibe "gün tıklayınca ay değişiyor" kilidi)', () => {
    takvimAc('2026-09-06');
    sb.bcTakvimToggle('2026-09-15');
    const d = tkDurum('2026-09-06');
    assert.strictEqual(d.ay, 8);
    assert.strictEqual(d.yil, 2026);
    assert.deepStrictEqual(host(d.secili), ['2026-09-15']);
  });

  it('‹ sonra › : ay etiketi geri döner, seçim ÇİP ve Set\'te kalıcı', () => {
    const kutu = takvimAc('2026-09-06');
    sb.bcTakvimToggle('2026-09-15');
    sb.bcTakvimAyDegistir(-1);
    assert.ok(kutu.innerHTML.includes('Ağustos 2026'), '‹ sonrası Ağustos');
    sb.bcTakvimAyDegistir(1);
    assert.ok(kutu.innerHTML.includes('Eylül 2026'), '› sonrası Eylül');
    assert.deepStrictEqual(host(tkDurum('2026-09-06').secili), ['2026-09-15']);
    assert.ok(kutu.innerHTML.includes('15.09'), 'çip DD.MM kalır: ' + (kutu.innerHTML.match(/Seçili Günler[\s\S]{0,400}/) || [''])[0]);
  });

  it('› ile sonraki ayda gün tıklama: ay EKİM kalır, seçim 2026-10-05 birebir (yanlış aya düşmez)', () => {
    const kutu = takvimAc('2026-09-06');
    sb.bcTakvimAyDegistir(1);
    assert.ok(kutu.innerHTML.includes('Ekim 2026'));
    sb.bcTakvimToggle('2026-10-05'); // Gün 30 — sınır içi
    const d = tkDurum('2026-09-06');
    assert.strictEqual(d.ay, 9, 'ay Ekim (9) korunmalı');
    assert.strictEqual(d.yil, 2026);
    assert.deepStrictEqual(host(d.secili), ['2026-10-05']);
    assert.ok(kutu.innerHTML.includes('05.10'));
  });

  it('başlangıç+31 ötesi gün: toast + seçim REDDİ (sahibin 31-gün taarruzu zarif düşer)', () => {
    takvimAc('2026-09-06');
    sb.__toasts.length = 0;
    sb.bcTakvimToggle('2026-10-10'); // gün 35
    assert.deepStrictEqual(host(tkDurum('2026-09-06').secili), [], 'gün>31 seçime girmez');
    assert.strictEqual(sb.__toasts.length, 1, 'tek uyarı toast');
    assert.strictEqual(sb.__toasts[0].isErr, true);
    assert.ok(/31/.test(sb.__toasts[0].m), 'toast sınırı açıklar: ' + sb.__toasts[0].m);
  });

  it('başlık tarihi DD.MM.YYYY: modal başlığında 06.09.2026 (2026-09-06 değil)', () => {
    const kutu = takvimAc('2026-09-06');
    assert.ok(kutu.innerHTML.includes('06.09.2026'), 'DD.MM.YYYY başlık');
    assert.ok(!kutu.innerHTML.includes('başlangıç: 2026-09-06'), 'ISO biçimi kalmaz');
  });

  it('hücre onclick ISO\'ları görüntülenen aya ait (› sonrası Ekim ISO\'ları)', () => {
    const kutu = takvimAc('2026-09-06');
    sb.bcTakvimAyDegistir(1);
    const onclicklar = [...kutu.innerHTML.matchAll(/bcTakvimToggle\(&#39;([\d-]+)&#39;\)/g)].map(m => m[1]);
    assert.ok(onclicklar.length === 31, '31 tıklanabilir Ekim hücresi');
    assert.ok(onclicklar.every(iso => iso.startsWith('2026-10-')), 'hepsi Ekim: ' + onclicklar[0] + '..' + onclicklar[onclicklar.length - 1]);
  });
});

// ══════════════════════════════════════════════════════════════════════
// 9. V2.2.1 (W14) — SAHİBE ONAYLI İKİLİ (2026-09-06):
//    P1 = gün kopyalama ÇOKLU hedef (tek tek useless) — bcGunKopyalaCoklu
//    saf özü: var olan hedef DEĞİŞİR (degisti[]), olmayan OLUŞTURULUR
//    (olusturuldu[]); kaynak kendisi hedef olamaz, hedefler unique + 1..31
//    (bcGunNoKontrol aralığı). W11 bcGunKopyala sözleşmesi KORUNUR — çoklu
//    çekirdeğe TEK-ELEMANLI delege olur (bilinçli adaptasyon: iç şekil
//    {gunler, degisti, olusturuldu} → dış boolean {gunler, olusturuldu}).
//    P2 = sonuç satırı → hayvan kartı: bcSonucSatirlari satırları hayvanId
//    taşır (acilan[i].hayvan_id + atlanan[i].hayvan_id — RPC sözleşmesi
//    20260906120000_vaka_toplu_ac.sql; hata satırları KASTEN haritalanmaz =
//    inert); bcSonucBantlari hayvanId'lı satırı data-action + data-hayvan-id
//    + cursor:pointer + '›' ucuyla basar (events.js data-action delege dili).
// ══════════════════════════════════════════════════════════════════════
describe('bcGunKopyalaCoklu (V2.2.1 saf — çoklu hedef gün kopyalama)', () => {
  const kaynak = [
    { gun: 1, seanslar: [seans('08:00', { D1: kalem({ dose: '10', unit: 'ml', route: 'IM' }) })] },
    { gun: 3, seanslar: [seans('20:00', { L1: kalem({ name: 'Eski', dose: '1', unit: 'adet', route: 'PO' }) })] },
    { gun: 5, seanslar: [] },
  ];

  it('karışık: var olan hedef DEĞİŞİR (degisti), olmayan OLUŞTURULUR (olusturuldu); ASC plan', () => {
    const r = sb.bcGunKopyalaCoklu(kaynak, 1, [2, 3]);
    assert.deepStrictEqual(host(r.degisti), [3]);
    assert.deepStrictEqual(host(r.olusturuldu), [2]);
    assert.deepStrictEqual(host(r.gunler.map(g => g.gun)), [1, 2, 3, 5]);
    const h2 = r.gunler.find(g => g.gun === 2);
    const h3 = r.gunler.find(g => g.gun === 3);
    assert.deepStrictEqual(host(h2.seanslar), host(kaynak[0].seanslar), 'yeni gün kaynak seanslarını taşır');
    assert.deepStrictEqual(host(h3.seanslar), host(kaynak[0].seanslar), 'eski gün 3 seansları KAYNAKLA değişmeli');
    assert.deepStrictEqual(host(r.gunler.find(g => g.gun === 5).seanslar), [], 'dokunulmamış gün aynı kalır');
  });

  it('üç hedef karışık sırayla → sonuç ASC, her hedefe AYRI deep-copy', () => {
    const r = sb.bcGunKopyalaCoklu(kaynak, 1, [7, 3, 2]);
    assert.deepStrictEqual(host(r.gunler.map(g => g.gun)), [1, 2, 3, 5, 7]);
    assert.deepStrictEqual(host(r.degisti), [3]);
    assert.deepStrictEqual(host(r.olusturuldu.slice().sort((a, b) => a - b)), [2, 7]);
    const h2 = r.gunler.find(g => g.gun === 2);
    const h7 = r.gunler.find(g => g.gun === 7);
    assert.notStrictEqual(h2.seanslar, h7.seanslar, 'hedefler arasında paylaşımlı dizi olmamalı');
    h2.seanslar[0].saat = '23:59';
    assert.strictEqual(h7.seanslar[0].saat, '08:00', 'h2 mutasyonu h7\'ye sıçramamalı');
  });

  it('kaynak kendisi hedefler arasında → null (tek başına da, karışıkta da)', () => {
    assert.strictEqual(sb.bcGunKopyalaCoklu(kaynak, 1, [1]), null);
    assert.strictEqual(sb.bcGunKopyalaCoklu(kaynak, 1, [2, 1]), null);
  });

  it('hedefler TEKRARLI → null (unique zorunlu)', () => {
    assert.strictEqual(sb.bcGunKopyalaCoklu(kaynak, 1, [2, 2]), null);
  });

  it('hedef 1..31 dışı / ondalık → null (bcGunNoKontrol aralık kuralı)', () => {
    assert.strictEqual(sb.bcGunKopyalaCoklu(kaynak, 1, [0]), null);
    assert.strictEqual(sb.bcGunKopyalaCoklu(kaynak, 1, [32]), null);
    assert.strictEqual(sb.bcGunKopyalaCoklu(kaynak, 1, [2.5]), null);
    assert.strictEqual(sb.bcGunKopyalaCoklu(kaynak, 1, [2, 32]), null);
  });

  it('kaynak gün yok → null', () => {
    assert.strictEqual(sb.bcGunKopyalaCoklu(kaynak, 9, [2]), null);
  });

  it('boş hedef listesi → null', () => {
    assert.strictEqual(sb.bcGunKopyalaCoklu(kaynak, 1, []), null);
    assert.strictEqual(sb.bcGunKopyalaCoklu(kaynak, 1, null), null);
  });

  it('girdi dizi MUTASYONLANMAZ + kaynak seansları deep-copy korunur', () => {
    const once = JSON.stringify(kaynak);
    const r = sb.bcGunKopyalaCoklu(kaynak, 1, [2]);
    assert.strictEqual(JSON.stringify(kaynak), once, 'kaynak plan dokunulmaz');
    r.gunler.find(g => g.gun === 2).seanslar[0].saat = '23:59';
    assert.strictEqual(kaynak[0].seanslar[0].saat, '08:00', 'sonuçtan mutasyon kaynağa sıçramaz');
  });

  it('null girdi → null (patlamaz)', () => {
    assert.strictEqual(sb.bcGunKopyalaCoklu(null, 1, [2]), null);
  });

  it('bcGunKopyala (W11) eski sözleşme KORUNUR — çoklu çekirdeğe delege', () => {
    const r = sb.bcGunKopyala(kaynak, 1, 2);
    assert.strictEqual(r.olusturuldu, true, 'eski boolean sözleşme');
    assert.deepStrictEqual(host(r.gunler.map(g => g.gun)), [1, 2, 3, 5]);
    const r2 = sb.bcGunKopyala(kaynak, 1, 3);
    assert.strictEqual(r2.olusturuldu, false, 'değiştirmede false kalır');
  });
});

// ── P2: bcSonucSatirlari hayvanId uzantısı ────────────────────────────
describe('bcSonucSatirlari V2.2.1 uzantısı (hayvanId → hayvan kartı)', () => {
  it('acilan[i].hayvan_id → ok satırına hayvanId taşınır (additive)', () => {
    const rows = sb.bcSonucSatirlari({ ok: true, acilan: [{ hayvan_id: 'H-1', kupe: 'TR-1', case_id: 'c1' }] });
    assert.strictEqual(rows[0].hayvanId, 'H-1');
    assert.strictEqual(rows[0].tip, 'ok');
  });

  it('atlanan[i].hayvan_id → atlanan satırına hayvanId taşınır (RPC sözleşmesi)', () => {
    const rows = sb.bcSonucSatirlari({
      ok: true,
      atlanan: [{ hayvan_id: 'H-2', kupe: 'TR-2', mesaj: 'zaten aktif' }],
    });
    assert.strictEqual(rows[0].hayvanId, 'H-2');
    assert.strictEqual(rows[0].tip, 'atlanan');
  });

  it('hayvan_id YOKSA hayvanId anahtarı hiç eklenmez (eski sözleşme korunur)', () => {
    const rows = sb.bcSonucSatirlari({
      ok: true,
      acilan: [{ kupe: 'TR-1', case_id: 'c1' }],
      atlanan: [{ kupe: 'TR-2', mesaj: 'x' }],
      hatalar: [{ kupe: 'TR-3', mesaj: 'y' }],
    });
    assert.deepStrictEqual(host(rows), [
      { tip: 'ok', kupe: 'TR-1' },
      { tip: 'atlanan', kupe: 'TR-2', mesaj: 'x' },
      { tip: 'hata', kupe: 'TR-3', mesaj: 'y' },
    ]);
  });

  it('hata satırı KASTEN inert: RPC hayvan_id taşısa bile hayvanId haritalanmaz', () => {
    const rows = sb.bcSonucSatirlari({ ok: true, hatalar: [{ hayvan_id: 'H-9', kupe: 'TR-9', mesaj: 'stok' }] });
    assert.ok(!('hayvanId' in rows[0]), 'hata satırı hayvan kartına gitmez');
  });
});

// ── P2: bcSonucBantlari tap affordance + gün kartı DOM çapraz kontrolü ─
describe('bcSonucBantlari V2.2.1 (satır → hayvan kartı affordance)', () => {
  it('hayvanId\'lı satır tıklanabilir: data-action + data-hayvan-id + cursor:pointer + › ucu', () => {
    const html = sb.bcSonucBantlari(
      [
        { tip: 'ok', kupe: 'TR-1', hayvanId: 'H-1' },
        { tip: 'atlanan', kupe: 'TR-2', mesaj: 'zaten aktif', hayvanId: 'H-2' },
      ],
      { acilan: [] }
    );
    assert.match(html, /data-action="bc-sonuc-hayvan"/);
    assert.match(html, /data-hayvan-id="H-1"/);
    assert.match(html, /data-hayvan-id="H-2"/);
    assert.match(html, /cursor:pointer/);
    assert.ok(html.includes('›'), 'satır ucunda › ipucu olmalı');
  });

  it('hayvanId\'siz satır inert: data-action/data-hayvan-id YOK', () => {
    const html = sb.bcSonucBantlari(
      [
        { tip: 'ok', kupe: 'TR-1' },
        { tip: 'hata', kupe: 'TR-3', mesaj: 'stok' },
      ],
      { acilan: [] }
    );
    assert.ok(!html.includes('data-action'), 'inert satır data-action taşımamalı');
    assert.ok(!html.includes('data-hayvan-id'), 'inert satır data-hayvan-id taşımamalı');
  });
});

describe('_bcGunKartiHtml V2.2.1 (çoklu kopyalama alanı — DOM çapraz kontrol)', () => {
  function kartHtml() {
    sb._bcGunler = [
      { gun: 1, seanslar: [seans('08:00', {})] },
      { gun: 2, seanslar: [] },
      { gun: 5, seanslar: [] },
    ];
    sb._bcAktifGunCard = 1;
    sb._bcKopyaAcikGun = 1;
    return sb._bcGunKartiHtml(sb._bcGunler[0], '2026-09-06');
  }

  it('yeni id\'ler birer kez: bc-gkopya-alan-1 + bc-gkopya-chips-1 + bc-gkopya-no-1', () => {
    const html = kartHtml();
    assert.strictEqual((html.match(/id="bc-gkopya-alan-1"/g) || []).length, 1);
    assert.strictEqual((html.match(/id="bc-gkopya-chips-1"/g) || []).length, 1);
    assert.strictEqual((html.match(/id="bc-gkopya-no-1"/g) || []).length, 1);
  });

  it('diğer HER gün için çip (Gün 2, Gün 5); kaynak gün 1 için çip YOK', () => {
    const html = kartHtml();
    assert.match(html, /data-action="bc-gun-kopya-chip"[^>]*data-hedef="2"[^>]*>Gün 2</);
    assert.match(html, /data-action="bc-gun-kopya-chip"[^>]*data-hedef="5"[^>]*>Gün 5</);
    assert.ok(!html.includes('data-hedef="1"'), 'kaynak gün kendisi çip olmamalı');
  });

  it('+№ ekle girişi + ✅ Uygula + alan aç/kapa toggle action\'ları', () => {
    const html = kartHtml();
    assert.match(html, /data-action="bc-gun-kopya-ekle"/);
    assert.match(html, /data-action="bc-gun-kopyala"/);
    assert.match(html, /data-action="bc-gun-kopya-toggle"/);
  });
});

// ══════════════════════════════════════════════════════════════════════
// 10. V2.2.2 (W16) — SAHİBE ONAYLI İKİLİ (2026-09-06):
//     P3 = 💾 planı tedavi şablonu olarak kaydet (submit akışı SÜRER —
//     bellek; şablon kayıt akışı sablonKaydet ui.js:4522 örnek):
//       - bcSablonKalemleriOlustur(gunler): gün planı state'ini
//         tedavi_sablon_kaydet p_kalemler.kalemler sözleşmesine düzleştirir —
//         gun_no AS-IS (boşluklu plan korunur — W15 RPC sözleşmesi),
//         planned_time = seans saati, dose Number, route boş→null,
//         legacy/stok_id çözümü bcGunlardenItems aynası.
//       - bcSablonOzetMetni(gunler): mini-form canlı özeti
//         'İçerik: N gün · M seans (gün 1,2,5)' — şablon listesi
//         _renderSablonSecim 'N gün · M seans' dilinin aynısı (M = kalem).
//     P4 = tohumlama çakışma radyosu (W15 p_tohumlama_cakisma sözleşmesi):
//       - bcCakismaRadyosu(tohumIste, cakisanlar): openConfirm opts.radyolar
//         yapılandırması — varsayılan 'atla' (muhafazakâr), aksi halde null.
//       - bcCakismaPayloadDegeri(radyoVar, secim): radyo + geçerli seçim →
//         seçim; aksi her durumda 'ekle' (eski davranış birebir).
//       - bcSonucSatirlari V2.2 uzantısı: acilan[i].tohumlama.uzerine_yazildi
//         → satıra uzerineYazildi (ADDITIVE — anahtar yoksa hiç eklenmez).
//       - bcSonucBantlari ok-satırı eki: ' (üzerine yazıldı: eski DD.MM, …)'.
// ══════════════════════════════════════════════════════════════════════
describe('bcSablonKalemleriOlustur (V2.2.2 W16 — plan state → şablon kalem dizisi)', () => {
  it('çoklu gün + boşluk: gun_no AS-IS korunur (1 ve 5 — renumber YOK), ASC sıralı', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [
      { gun: 5, seanslar: [seans('16:00', { D1: kalem({ dose: '5', unit: 'ml', route: 'SC' }) })] },
      { gun: 1, seanslar: [seans('09:00', { D1: kalem({ dose: '10', unit: 'ml', route: 'IM' }) })] },
    ]);
    const kalemler = sandbox.bcSablonKalemleriOlustur(sandbox.globalThis._bcGunler);
    assert.deepStrictEqual(host(kalemler.map(k => k.gun_no)), [1, 5]);
  });

  it('kalem sözleşmesi: planned_time = seans saati; dose Number; route boş→null', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 1, seanslar: [seans('09:00', { D1: kalem({ dose: '12.5', unit: ' ml ', route: '' }) })] }]);
    const kalemler = sandbox.bcSablonKalemleriOlustur(sandbox.globalThis._bcGunler);
    assert.deepStrictEqual(host(kalemler), [
      { gun_no: 1, planned_time: '09:00', drug_product_id: 'D1', stok_id: 'S1', dose: 12.5, unit: 'ml', route: null },
    ]);
  });

  it('aynı ilaç iki seansta → iki kalem, her biri kendi planned_time ile', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 2, seanslar: [
      seans('08:00', { D1: kalem({ dose: '10', unit: 'ml', route: 'IM' }) }),
      seans('20:00', { D1: kalem({ dose: '10', unit: 'ml', route: 'IM' }) }),
    ] }]);
    const kalemler = sandbox.bcSablonKalemleriOlustur(sandbox.globalThis._bcGunler);
    assert.deepStrictEqual(host(kalemler.map(k => k.planned_time)), ['08:00', '20:00']);
    assert.deepStrictEqual(host(kalemler.map(k => k.gun_no)), [2, 2]);
  });

  it('legacy ilaç → drug_product_id:null, stok_id cache fallback (SL1 — bcGunlardenItems aynası)', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 1, seanslar: [seans('07:15', { L1: kalem({ name: 'Eski', dose: '5', unit: 'ml', route: '' }) })] }]);
    const kalemler = sandbox.bcSablonKalemleriOlustur(sandbox.globalThis._bcGunler);
    assert.deepStrictEqual(host(kalemler), [
      { gun_no: 1, planned_time: '07:15', drug_product_id: null, stok_id: 'SL1', dose: 5, unit: 'ml', route: null },
    ]);
  });

  it('boş / null plan → [] (patlamaz)', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 1, seanslar: [] }]);
    assert.deepStrictEqual(host(sandbox.bcSablonKalemleriOlustur(sandbox.globalThis._bcGunler)), []);
    assert.deepStrictEqual(host(sandbox.bcSablonKalemleriOlustur(null)), []);
    assert.deepStrictEqual(host(sandbox.bcSablonKalemleriOlustur(undefined)), []);
  });

  it('girdi dizi MUTASYONLANMAZ (saf)', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 1, seanslar: [seans('08:00', { D1: kalem({ dose: '10', unit: 'ml', route: 'IM' }) })] }]);
    const once = JSON.stringify(sandbox.globalThis._bcGunler);
    sandbox.bcSablonKalemleriOlustur(sandbox.globalThis._bcGunler);
    assert.strictEqual(JSON.stringify(sandbox.globalThis._bcGunler), once);
  });
});

describe('bcSablonOzetMetni (V2.2.2 W16 — şablon kaydet mini-formu canlı özeti)', () => {
  it('gün 1,2,5 + 5 kalem → "İçerik: 3 gün · 5 seans (gün 1,2,5)" (şablon listesi dili)', () => {
    const { sandbox } = setupFormsPlan();
    const D = (doz) => kalem({ dose: doz, unit: 'ml', route: 'IM' });
    gunle(sandbox, [
      { gun: 1, seanslar: [seans('08:00', { D1: D('10') }), seans('20:00', { D1: D('10') })] },
      { gun: 2, seanslar: [seans('08:00', { D1: D('10') })] },
      { gun: 3, seanslar: [] }, // seanssız gün şablona kalem üretmez
      { gun: 5, seanslar: [seans('16:00', { D1: D('10') }), seans('16:00', { L1: D('2') })] },
    ]);
    assert.strictEqual(sandbox.bcSablonOzetMetni(sandbox.globalThis._bcGunler), 'İçerik: 3 gün · 5 seans (gün 1,2,5)');
  });

  it('doz boş (taslak) kalem özete SAYILMAZ — geçerli kalem sayısı düşer', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 1, seanslar: [
      seans('08:00', { D1: kalem({ dose: '10', unit: 'ml', route: 'IM' }) }),
      seans('20:00', { D1: kalem({ dose: '', unit: '', route: '' }) }),
    ] }]);
    assert.strictEqual(sandbox.bcSablonOzetMetni(sandbox.globalThis._bcGunler), 'İçerik: 1 gün · 1 seans (gün 1)');
  });

  it('boş / null plan → "İçerik: boş plan" (patlamaz)', () => {
    const { sandbox } = setupFormsPlan();
    gunle(sandbox, [{ gun: 1, seanslar: [] }]);
    assert.strictEqual(sandbox.bcSablonOzetMetni(sandbox.globalThis._bcGunler), 'İçerik: boş plan');
    assert.strictEqual(sandbox.bcSablonOzetMetni(null), 'İçerik: boş plan');
  });
});

describe('bcCakismaRadyosu (V2.2.2 W16 — çakışma radyosu kararı, saf)', () => {
  it('tohumlama + çakışan var → {isim:"cakisma", varsayilan:"atla", 2 seçenek}', () => {
    const r = sb.bcCakismaRadyosu(true, [{ id: 'H1', kupe: 'TR-1', tarih: '2026-09-10' }]);
    assert.deepStrictEqual(host(r), {
      isim: 'cakisma',
      varsayilan: 'atla',
      secenekler: [
        { deger: 'uzerine_yaz', etiket: 'Üzerine yaz — eski plan iptal, yenisi planlanır' },
        { deger: 'atla', etiket: 'Atla — eski plan kalır, yenisi açılmaz' },
      ],
    });
  });

  it('tohumlama yok → null (radyo gösterilmez)', () => {
    assert.strictEqual(sb.bcCakismaRadyosu(false, [{ id: 'H1' }]), null);
  });

  it('çakışan yok → null (radyo gösterilmez)', () => {
    assert.strictEqual(sb.bcCakismaRadyosu(true, []), null);
    assert.strictEqual(sb.bcCakismaRadyosu(true, null), null);
  });

  it('varsayılan MUHAFAZAKÂR: atla — eski plan korunur (sahip kararı)', () => {
    const r = sb.bcCakismaRadyosu(true, [{ id: 'H1' }]);
    assert.strictEqual(r.varsayilan, 'atla');
  });
});

describe('bcCakismaPayloadDegeri (V2.2.2 W16 — p_tohumlama_cakisma payload değeri, saf)', () => {
  it('radyo gösterildi + seçim → seçim birebir (uzerine_yaz/atla)', () => {
    assert.strictEqual(sb.bcCakismaPayloadDegeri(true, 'uzerine_yaz'), 'uzerine_yaz');
    assert.strictEqual(sb.bcCakismaPayloadDegeri(true, 'atla'), 'atla');
  });

  it('radyo yok → "ekle" (eski davranış birebir)', () => {
    assert.strictEqual(sb.bcCakismaPayloadDegeri(false, 'atla'), 'ekle');
    assert.strictEqual(sb.bcCakismaPayloadDegeri(false, undefined), 'ekle');
  });

  it('radyo var ama seçim geçersiz/eksik → "ekle" (RPC default güvencesi)', () => {
    assert.strictEqual(sb.bcCakismaPayloadDegeri(true, undefined), 'ekle');
    assert.strictEqual(sb.bcCakismaPayloadDegeri(true, ''), 'ekle');
    assert.strictEqual(sb.bcCakismaPayloadDegeri(true, 'sil_bunu'), 'ekle');
  });
});

describe('bcSonucSatirlari V2.2.2 uzantısı (uzerine_yazildi — W15 RPC sözleşmesi)', () => {
  it('tohumlama.olustu=true + uzerine_yazildi → satıra uzerineYazildi taşınır (additive)', () => {
    const rows = sb.bcSonucSatirlari({
      ok: true,
      acilan: [{ kupe: 'TR-1', case_id: 'c1', tohumlama: { olustu: true, gorev_id: 'g1', uzerine_yazildi: ['10.09', '12.09'] } }],
    });
    assert.deepStrictEqual(host(rows), [
      { tip: 'ok', kupe: 'TR-1', tohumlamaOlustu: true, uzerineYazildi: ['10.09', '12.09'] },
    ]);
  });

  it('uzerine_yazildi YOKSA anahtar HİÇ eklenmez (eski sözleşme korunur)', () => {
    const rows = sb.bcSonucSatirlari({
      ok: true,
      acilan: [{ kupe: 'TR-2', case_id: 'c2', tohumlama: { olustu: true, gorev_id: 'g2' } }],
    });
    assert.strictEqual(Object.prototype.hasOwnProperty.call(rows[0], 'uzerineYazildi'), false);
  });

  it('boş uzerine_yazildi dizisi → anahtar eklenmez (üzerine yazma gerçekleşmedi)', () => {
    const rows = sb.bcSonucSatirlari({
      ok: true,
      acilan: [{ kupe: 'TR-3', case_id: 'c3', tohumlama: { olustu: true, uzerine_yazildi: [] } }],
    });
    assert.strictEqual(Object.prototype.hasOwnProperty.call(rows[0], 'uzerineYazildi'), false);
  });
});

describe('bcSonucBantlari V2.2.2 (üzerine yazıldı eki)', () => {
  it('ok satırı uzerineYazildi → tohum ekine " (üzerine yazıldı: eski 10.09, 12.09)" eklenir', () => {
    const html = sb.bcSonucBantlari(
      [{ tip: 'ok', kupe: 'TR-1', tohumlamaOlustu: true, uzerineYazildi: ['10.09', '12.09'] }],
      { acilan: [], tohumIste: true, tohumSaat: '08:00' }
    );
    assert.match(html, /🐄 tohumlama 08:00 \(üzerine yazıldı: eski 10\.09, 12\.09\)/);
  });

  it('uzerineYazildi yoksa eki YOK — eski "· 🐄 tohumlama SS:DD" dili birebir', () => {
    const html = sb.bcSonucBantlari(
      [{ tip: 'ok', kupe: 'TR-2', tohumlamaOlustu: true }],
      { acilan: [], tohumIste: true, tohumSaat: '09:30' }
    );
    assert.match(html, /· 🐄 tohumlama 09:30</);
    assert.ok(!html.includes('üzerine yazıldı'), 'eki olmamalı');
  });
});

// ══════════════════════════════════════════════════════════════════════
// 11. V2.2.2 (W16) — openConfirm radyo grubu (P4 devamı): onay diyaloğuna
//     OPSİYONEL opts.radyolar — {isim, varsayilan, secenekler:[{deger,
//     etiket}]} — desc ile butonlar arası radio grubu; Onayla callback'i
//     seçilen değeri ek argümanla alır. opts'suz yol BİREBİR eski davranış
//     (radyo kutusu boş+gizli, callback args'sız — 12 mevcut çağıranın
//     hepsi sıfır-argüman callback; GitNexus d=1: 12 kanıtı).
//     ui.js testleri bu dosyada: goal write_manifest yalnız
//     tests/unit/vaka-toplu-ac.test.js'i listeler (ui-pure.test.js DEĞİL).
//     Saf yüz: _confirmRadyolarHtml(radyolar) → HTML | '' (radio dili
//     _renderSablonSecim forms.js aynası).
// ══════════════════════════════════════════════════════════════════════

// helpers.js esc/escAttr tarayıcı aynaları (ui.js bunları global'den alır)
const escUi = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
const escAttrUi = (s) => String(s ?? '')
  .replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
  .replace(/</g, '&lt;').replace(/>/g, '&gt;');

// m-confirm elemanları stub'lanmış ayrı ui.js sandbox'ı (openM/closeM
// js/utils/modal.js'ten gelir — vm'de yok; testte gözlemlenebilir stub).
function setupConfirm() {
  const document = makeDomStub();
  const acilan = [], kapanan = [];
  const { sandbox } = loadBrowserModule('js/ui.js', {
    dom: document,
    extra: {
      esc: escUi, escAttr: escAttrUi,
      openM: (id) => acilan.push(id),
      closeM: (id) => kapanan.push(id),
    },
  });
  return { sandbox, document, acilan, kapanan };
}

const CAKISMA_RADYO = {
  isim: 'cakisma',
  varsayilan: 'atla',
  secenekler: [
    { deger: 'uzerine_yaz', etiket: 'Üzerine yaz — eski plan iptal, yenisi planlanır' },
    { deger: 'atla', etiket: 'Atla — eski plan kalır, yenisi açılmaz' },
  ],
};

describe('openConfirm radyo grubu (V2.2.2 W16 — _confirmRadyolarHtml saf yüzü)', () => {
  it('radio dili _renderSablonSecim aynası — name/value/etiket', () => {
    const { sandbox } = setupConfirm();
    const html = sandbox._confirmRadyolarHtml(CAKISMA_RADYO);
    assert.match(html, /<label[^>]*>/);
    assert.match(html, /<input type="radio" name="cakisma" value="uzerine_yaz">/);
    assert.match(html, /<input type="radio" name="cakisma" value="atla" checked>/);
    assert.ok(html.includes('Üzerine yaz — eski plan iptal, yenisi planlanır'));
    assert.ok(html.includes('Atla — eski plan kalır, yenisi açılmaz'));
  });

  it('varsayılan işaretli (checked) — diğer işaretsiz', () => {
    const { sandbox } = setupConfirm();
    const html = sandbox._confirmRadyolarHtml(CAKISMA_RADYO);
    assert.match(html, /<input type="radio" name="cakisma" value="atla" checked>/);
    assert.ok(!html.includes('value="uzerine_yaz" checked'), 'varsayılan dışı işaretlenmez');
  });

  it('boş/eksik/hatalı girdi → "" (grup basılmaz)', () => {
    const { sandbox } = setupConfirm();
    assert.strictEqual(sandbox._confirmRadyolarHtml(null), '');
    assert.strictEqual(sandbox._confirmRadyolarHtml(undefined), '');
    assert.strictEqual(sandbox._confirmRadyolarHtml({}), '');
    assert.strictEqual(sandbox._confirmRadyolarHtml({ isim: 'x', secenekler: [] }), '');
    assert.strictEqual(sandbox._confirmRadyolarHtml({ isim: 'x', secenekler: 'dizi-degil' }), '');
  });

  it('etiket HTML kaçırılır (esc)', () => {
    const { sandbox } = setupConfirm();
    const html = sandbox._confirmRadyolarHtml({
      isim: 'r', varsayilan: '', secenekler: [{ deger: 'a', etiket: '<b>kalin</b>' }],
    });
    assert.ok(html.includes('&lt;b&gt;kalin&lt;/b&gt;'));
    assert.ok(!html.includes('<b>kalin</b>'));
  });
});

describe('openConfirm + _confirmOk DOM davranışı (V2.2.2 W16 — m-confirm stub)', () => {
  it('radyolar: desc ile butonlar arasında grup basılır, default checked, modal açılır', () => {
    const { sandbox, document, acilan } = setupConfirm();
    const title = document.__setEl('m-confirm-title', makeElement('div'));
    const desc = document.__setEl('m-confirm-desc', makeElement('div'));
    const radyoKutu = document.__setEl('m-confirm-radyolar', makeElement('div'));
    const fn = () => {};
    sandbox.openConfirm('⚠️ Uyarılar', 'satır1\nsatır2', fn, { radyolar: CAKISMA_RADYO });
    assert.strictEqual(title.textContent, '⚠️ Uyarılar');
    assert.strictEqual(desc.textContent, 'satır1\nsatır2');
    assert.match(radyoKutu.innerHTML, /name="cakisma" value="atla" checked>/);
    assert.strictEqual(radyoKutu.style.display, 'block');
    assert.ok(acilan.includes('m-confirm'), 'modal açılır');
  });

  it('opts\'suz: radyo kutusu TEMİZLENİR + gizlenir (önceki onayın radyosu sızmaz)', () => {
    const { sandbox, document } = setupConfirm();
    document.__setEl('m-confirm-title', makeElement('div'));
    document.__setEl('m-confirm-desc', makeElement('div'));
    const radyoKutu = document.__setEl('m-confirm-radyolar', makeElement('div'));
    radyoKutu.innerHTML = '<input type="radio" name="eski">';
    radyoKutu.style.display = 'block';
    sandbox.openConfirm('Onay', 'Açıklama', () => {});
    assert.strictEqual(radyoKutu.innerHTML, '');
    assert.strictEqual(radyoKutu.style.display, 'none');
  });

  it('_confirmOk + radyo: callback seçilen değeri ek argümanla alır + modal kapanır', () => {
    const { sandbox, document, kapanan } = setupConfirm();
    document.__setEl('m-confirm-title', makeElement('div'));
    document.__setEl('m-confirm-desc', makeElement('div'));
    document.__setEl('m-confirm-radyolar', makeElement('div'));
    const secili = makeElement('input');
    secili.type = 'radio'; secili.name = 'cakisma'; secili.value = 'uzerine_yaz'; secili.checked = true;
    document.querySelector = (sel) =>
      (sel === '#m-confirm-radyolar input[type="radio"]' || sel === 'input[name="cakisma"]:checked')
        ? secili : null;
    let alinan = { args: null, cagrildi: false };
    sandbox.openConfirm('T', 'D', (...args) => { alinan = { args, cagrildi: true }; }, { radyolar: CAKISMA_RADYO });
    sandbox._confirmOk();
    assert.strictEqual(alinan.cagrildi, true);
    assert.deepStrictEqual([...alinan.args], ['uzerine_yaz'], 'callback seçilen değeri alır');
    assert.ok(kapanan.includes('m-confirm'), 'modal kapanır');
  });

  it('_confirmOk opts\'suz yol: callback ARGÜMANSIZ çağrılır (mevcut çağıranlar birebir)', () => {
    const { sandbox, document } = setupConfirm();
    document.__setEl('m-confirm-title', makeElement('div'));
    document.__setEl('m-confirm-desc', makeElement('div'));
    document.__setEl('m-confirm-radyolar', makeElement('div'));
    let argSayisi = null, cagrildi = false;
    sandbox.openConfirm('T', 'D', (...args) => { argSayisi = args.length; cagrildi = true; });
    sandbox._confirmOk();
    assert.strictEqual(cagrildi, true);
    assert.strictEqual(argSayisi, 0, 'radyo yoksa eski fn() imzası korunur');
  });

  it('_confirmOk tek-atım: ikinci OK çağrısı fn çalıştırmaz (eski davranış korunur)', () => {
    const { sandbox, document } = setupConfirm();
    document.__setEl('m-confirm-title', makeElement('div'));
    document.__setEl('m-confirm-desc', makeElement('div'));
    document.__setEl('m-confirm-radyolar', makeElement('div'));
    let sayac = 0;
    sandbox.openConfirm('T', 'D', () => { sayac++; });
    sandbox._confirmOk();
    sandbox._confirmOk();
    assert.strictEqual(sayac, 1, '_confirmAction tek-atımlı — eski davranış korunur');
  });
});

// ══════════════════════════════════════════════════════════════════════
// V2.3 (W18, 2026-09-07) — şablona tohumlama kaydı + 📂 Şablon Yükle
// (geri çağırma-düzenleme). Saf birimler:
//   bcSablonTohumPayload(istenen, gunStr, saatStr) — bc-tohum üçlüsünü
//     tedavi_sablon_kaydet p_kalemler.tohumlama_plani sözleşmesine (W15 GT:
//     {gun_ofset int ≥0, planned_time 'HH:MM'}) map eder; istek yoksa NULL
//     döner (anahtar GÖNDERİLMEZ — sablonKaydet ui.js konvansiyonu).
//   bcSablondenPlan(sablon, drugs) — IDB şablon satırı + tedavi_sablonu_kalem
//     satırlarını bc plan editörü state'ine ({gunler, tohumlama}) çevirir:
//     (gun_no, planned_time) seans-gruplama, boşluklu gün № korunur, kalem
//     ilaç anahtarı drug_product_id (legacy'de stok_id), planned_time
//     'HH:MM' dilimlenir.
// ══════════════════════════════════════════════════════════════════════

describe('bcSablonTohumPayload (şablona tohumlama payload haritası)', () => {
  it('istek yoksa null döner — tohumlama_plani anahtarı GÖNDERİLMEZ (ui.js konvansiyonu)', () => {
    assert.strictEqual(sb.bcSablonTohumPayload(false, '21', '14:00'), null);
  });

  it('istek varsa {gun_ofset, planned_time} üretir', () => {
    assert.deepStrictEqual(
      host(sb.bcSablonTohumPayload(true, '21', '14:00')),
      { gun_ofset: 21, planned_time: '14:00' });
  });

  it('gun_ofset 0..365 aralığına kelepirlenir (RPC sözleşmesi)', () => {
    assert.strictEqual(sb.bcSablonTohumPayload(true, '400', '08:00').gun_ofset, 365);
    assert.strictEqual(sb.bcSablonTohumPayload(true, '-3', '08:00').gun_ofset, 0);
    assert.strictEqual(sb.bcSablonTohumPayload(true, 'abc', '08:00').gun_ofset, 0);
    assert.strictEqual(sb.bcSablonTohumPayload(true, '', '08:00').gun_ofset, 0);
  });

  it('geçersiz/boş saat varsayılana düşer (08:00 — submitBulkCase paritesi)', () => {
    assert.strictEqual(sb.bcSablonTohumPayload(true, '5', '25:99').planned_time, '08:00');
    assert.strictEqual(sb.bcSablonTohumPayload(true, '5', '').planned_time, '08:00');
    assert.strictEqual(sb.bcSablonTohumPayload(true, '5', null).planned_time, '08:00');
    assert.strictEqual(sb.bcSablonTohumPayload(true, '5', '06:30').planned_time, '06:30');
  });
});

// W19 (2026-09-07) — bcSablonKaydet tohumlama kaydı KAPISI: şablon kaydı bir
// PROTOKOL tanımıdır — hayvan seçiminden bağımsız. Kapı YALNIZ bc-tohum
// checkbox'ına bakar; 🐄 bloğunun disabled görünümü YALNIZ submit yolunu
// ilgilendirir (root E2E bulgusu: hayvan seçimi boşken işaretli kutuya
// rağmen şablon tohumlama_plani NULL kaydediliyordu — demo DB kanıtı
// 'E2E Yükle Turu — tohumlamalı', gün 2, saat 16:00).
describe('bcSablonKaydet tohumlama kapısı (W19 — yalnız checkbox)', () => {
  // bcSablonKaydet'i RPC yakalayarak sürer: _drugsCache'li taze sandbox
  // (setupFormsPlan) + mini-form DOM'u + geçerli tek-günlük plan state'i.
  async function kaydetVeYakala({ checked, hayvanlar }) {
    const { sandbox, document } = setupFormsPlan();
    document.__setEl('bc-disease-id', makeElement('input')).value = 'dis-1';
    document.__setEl('bc-sablon-kaydet-ad', makeElement('input')).value = 'E2E Yükle Turu — tohumlamalı';
    const chk = document.__setEl('bc-tohum', makeElement('input'));
    chk.type = 'checkbox';
    chk.checked = !!checked;
    document.__setEl('bc-tohum-gun', makeElement('input')).value = '2';
    document.__setEl('bc-tohum-saat', makeElement('input')).value = '16:00';
    sandbox.globalThis._bcHayvanlar = hayvanlar; // [] → blok disabled-bos; kapı burada OLMAMALI
    sandbox.globalThis._bcGunler = [{ gun: 1, seanslar: [seans('08:00', {
      D1: { name: 'Baytril 10%', dose: '5', unit: 'ml', route: '' },
    })] }];
    const cagrilar = [];
    sandbox.rpc = async (name, params) => { cagrilar.push({ name, params }); return {}; };
    await sandbox.bcSablonKaydet();
    return cagrilar;
  }

  it('checkbox İŞARETLİ + hayvan listesi BOŞ → tohumlama_plani payload\'a DAHİL (gün 2, 16:00)', async () => {
    const cagrilar = await kaydetVeYakala({ checked: true, hayvanlar: [] });
    const cagri = cagrilar.find(c => c.name === 'tedavi_sablon_kaydet');
    assert.ok(cagri, 'tedavi_sablon_kaydet çağrıldı — plan doğrulaması geçildi');
    assert.deepStrictEqual(
      host(cagri.params.p_kalemler.tohumlama_plani),
      { gun_ofset: 2, planned_time: '16:00' },
      'blok-disabled (hayvan boş) kaydı engellememeli — kapı yalnız checkbox');
  });

  it('checkbox işaretsiz → tohumlama_plani anahtarı GÖNDERİLMEZ (mevcut doğrulama korunur)', async () => {
    const cagrilar = await kaydetVeYakala({ checked: false, hayvanlar: [{ id: 'h1', cinsiyet: 'Dişi' }] });
    const cagri = cagrilar.find(c => c.name === 'tedavi_sablon_kaydet');
    assert.ok(cagri, 'tedavi_sablon_kaydet çağrıldı');
    assert.ok(!('tohumlama_plani' in cagri.params.p_kalemler), 'kapalı kutu anahtar göndermez');
  });
});

describe('bcSablondenPlan (şablon → plan editörü geri çağırma)', () => {
  const K = (gun_no, planned_time, over) => Object.assign({
    gun_no, planned_time, stok_id: 'stk-' + gun_no + planned_time,
    drug_product_id: 'drug-' + gun_no + planned_time, dose: 10, unit: 'ml', route: 'IM',
  }, over || {});

  it('kalemler (gun_no, planned_time) düzleminde seanslara gruplanır, saatler ASC', () => {
    const r = sb.bcSablondenPlan({
      tohumlama_plani: null,
      kalemler: [K(1, '16:00'), K(1, '09:00'), K(1, '09:00', { drug_product_id: 'drug-b', stok_id: 'stk-b' })],
    });
    assert.strictEqual(r.gunler.length, 1);
    assert.strictEqual(r.gunler[0].gun, 1);
    assert.deepStrictEqual(host(r.gunler[0].seanslar.map(s => s.saat)), ['09:00', '16:00'], 'seans saatleri ASC');
    assert.strictEqual(Object.keys(r.gunler[0].seanslar[0].ilaclar).length, 2, 'aynı seans iki ilaç taşır');
    assert.strictEqual(Object.keys(r.gunler[0].seanslar[1].ilaclar).length, 1);
  });

  it('boşluklu gün № korunur (gün 1 ve 5 — 2,3,4 SIKIŞTIRILMAZ; criterion 14 dili)', () => {
    const r = sb.bcSablondenPlan({ tohumlama_plani: null, kalemler: [K(5, '09:00'), K(1, '09:00')] });
    assert.deepStrictEqual(host(r.gunler.map(g => g.gun)), [1, 5]);
  });

  it('tohumlama_plani {gun_ofset, planned_time} olarak taşınır', () => {
    const r = sb.bcSablondenPlan({
      tohumlama_plani: { gun_ofset: 10, planned_time: '08:30' },
      kalemler: [K(1, '09:00')],
    });
    assert.deepStrictEqual(host(r.tohumlama), { gun_ofset: 10, planned_time: '08:30' });
  });

  it('tohumlama_plani eksik/geçersizse tohumlama null (jsonb null normalize)', () => {
    assert.strictEqual(sb.bcSablondenPlan({ tohumlama_plani: null, kalemler: [K(1, '09:00')] }).tohumlama, null);
    assert.strictEqual(sb.bcSablondenPlan({ kalemler: [] }).tohumlama, null);
    assert.strictEqual(
      sb.bcSablondenPlan({ tohumlama_plani: { gun_ofset: 10 }, kalemler: [] }).tohumlama, null,
      'planned_time eksik — sunucu "gün ve saat bilgisi zorunlu" sözleşmesi');
  });

  it('kalem ilaç anahtarı drug_product_id; legacy (null) kalemin anahtarı stok_id', () => {
    const r = sb.bcSablondenPlan({
      tohumlama_plani: null,
      kalemler: [K(1, '09:00'), K(2, '10:00', { drug_product_id: null, stok_id: 'stk-legacy' })],
    });
    const gun1 = r.gunler.find(g => g.gun === 1).seanslar[0].ilaclar;
    const gun2 = r.gunler.find(g => g.gun === 2).seanslar[0].ilaclar;
    assert.ok('drug-109:00' in gun1, 'drug_product_id anahtar');
    assert.strictEqual(gun1['drug-109:00'].legacy, false);
    assert.ok('stk-legacy' in gun2, 'legacy kalem stok_id anahtarı');
    assert.strictEqual(gun2['stk-legacy'].legacy, true);
  });

  it('kalem doz sayı, stock_id stok_id\'den, planned_time HH:MM dilimlenir', () => {
    const drugs = [{ id: 'dp-1', name: 'Penisilin', stock_id: 'stk-farkli' }];
    const r = sb.bcSablondenPlan({
      tohumlama_plani: null,
      kalemler: [K(1, '09:00:00', { drug_product_id: 'dp-1', stok_id: 'stk-gercek', dose: 12.5 })],
    }, drugs);
    const ilac = r.gunler[0].seanslar[0].ilaclar['dp-1'];
    assert.strictEqual(ilac.dose, 12.5);
    assert.strictEqual(r.gunler[0].seanslar[0].saat, '09:00', ':ss soneki dilimlenir (seans düzleminde — bc state sözleşmesi)');
    assert.strictEqual(ilac.name, 'Penisilin', 'ad drugs cache\'ten çözülür');
    assert.strictEqual(ilac.stock_id, 'stk-gercek', 'stock_id kalem stok_id\'sinden');
  });

  it('boş şablon: gunler [] (çağıran editörü gün-1 boş planla açar), tohumlama null', () => {
    const r = sb.bcSablondenPlan({ tohumlama_plani: null, kalemler: [] });
    assert.deepStrictEqual(host(r.gunler), []);
    assert.strictEqual(r.tohumlama, null);
  });
});

describe('V2.3 (W18) — 📂 Şablon Yükle kablolaması + ?v= damgası (manifest-içi metin denetimi)', () => {
  const fs = require('node:fs');

  it('handlers.js yeni bc-sablon-yukle aksiyonlarını kaydeder', () => {
    const src = fs.readFileSync('js/utils/handlers.js', 'utf8');
    assert.ok(/'bc-sablon-yukle-toggle':\s*\(\)\s*=>\s*bcSablonYukleToggle\(\)/.test(src));
    assert.ok(/'bc-sablon-yukle':\s*\(el\)\s*=>\s*bcSablonYukle\(el\.dataset\.sablonId\)/.test(src));
    assert.ok(/'bc-sablon-yukle-kapat':\s*\(\)\s*=>\s*bcSablonYukleKapat\(\)/.test(src));
  });

  it('index.html: 📂 çipi + yükle alanı tek örnekte; her yerel script ?v=20260909-8 damgalı', () => {
    const html = fs.readFileSync('index.html', 'utf8');
    assert.strictEqual((html.match(/data-action="bc-sablon-yukle-toggle"/g) || []).length, 1);
    assert.strictEqual((html.match(/id="bc-sablon-yukle-alan"/g) || []).length, 1);
    assert.strictEqual((html.match(/id="bc-sablon-yukle-list"/g) || []).length, 1);
    // Cache-busting (owner feedback 2026-09-07): her YEREL script src'si damgalı
    // W21: stamp 20260907-4 (bc-tarih tek buton); 20260909-8: dozaj helperi + görev saat-grup-kupe
    const srcs = [...html.matchAll(/<script src="([^"]+)"/g)].map(m => m[1]);
    const yerel = srcs.filter(s => !s.startsWith('http'));
    assert.ok(yerel.length >= 14, 'yerel script sayısı: ' + yerel.length);
    const damgasiz = yerel.filter(s => !/\?v=20260909-8$/.test(s));
    assert.deepStrictEqual(host(damgasiz), [], 'damgasız yerel script kalmamalı');
    assert.ok(/<!-- \?v= damgası: her js\/css değişikliğinde GÜNCELLE \(cache-busting\) -->/.test(html),
      'damga bakım notu ilk script etiketinin yanında');
  });

  it('dinamik yükleyici bypass yok: js/ içinde js/*.js bare-path yükleyici tanımı yok', () => {
    const fs2 = require('node:fs');
    const taranacak = ['js/app.js', 'js/ui.js', 'js/forms.js', 'js/api.js', 'js/auth.js', 'js/demo.js',
      'js/config.js', 'js/state.js', 'js/ai-asistan.js'];
    const ihlal = [];
    taranacak.forEach(f => {
      const src = fs2.readFileSync(f, 'utf8');
      if (/import\s*\(\s*['"`]js\//.test(src) || /new\s+Worker\(/.test(src)) ihlal.push(f);
      // satır-içi yorumdaki bahsi sayma (app.js M-10 bloğu 'çağrısı yok' açıklaması taşır)
      const kod = src.split('\n').filter(l => !/^\s*\/\//.test(l)).join('\n');
      if (/serviceWorker\.register\s*\(/.test(kod)) ihlal.push(f + ' (SW register)');
    });
    assert.deepStrictEqual(ihlal, [], 'dinamik ?v= bypass kaynağı kalmamalı');
  });
});

// ══════════════════════════════════════════════════════════════════════
// V2.3 (W20) — TEDAVİ TARİHİ: yerel-input MM/DD gösteriminden kurtarma
// Sahibe kök teşhis (ekran görüntüleri, 2026-09-07): #bc-tarih type=date
// idi; GÖRÜNEN string tarayıcı yereline göre çiziliyor (in-app en-US →
// '09/26/2026' MM/DD/YYYY) — hesap ve hint ISO'su doğruydu ama sahibe alanı
// ters okudu ('gün değiştiriyorum ay değişiyor'). Ayrıca hint boşluksuz ve
// soldan taşan render oldu ('tedavi günleri2026-09-09gününe'). Çözüm
// (vanilla, yerelden bağımsız): alan readonly metin (görünen 'DD.MM.YYYY')
// + 📅 tek-seçim takvim butonu; kanonik ISO globalThis._bcTarihIso'da —
// görüntü ve değer ASLA ayrışmaz (tek yazma kapısı bcTarihYaz, tek okuma
// kapısı bcTarihDeger). Saf yüzey:
//   bcIsoTrGoster(iso)              → 'DD.MM.YYYY' | ''  (saf, locale'siz)
//   bcTrGosterIso(tr)               → 'YYYY-MM-DD' | ''  (yuvarlama çifti)
//   bcTarihSecimEkle(sec,iso,bugun) → { ok, secim, mesaj }  tek seçim;
//        min=bugun, maks=bugun+365 — seçim DEĞİŞTİRİR (toggle yok)
// Tüketiciler (bcTarihIpucuGuncelle/bcPlanRender/_bcTkBaslangic/
// submitBulkCase) artık v('bc-tarih') DEĞİL bcTarihDeger() okur.
// ══════════════════════════════════════════════════════════════════════

describe('bcIsoTrGoster (V2.3-W20 saf — ISO → TR DD.MM.YYYY, locale bağımsız)', () => {
  it("'2026-09-26' → '26.09.2026' (MM/DD ters-okuma kilitlenir)", () => {
    assert.strictEqual(sb.bcIsoTrGoster('2026-09-26'), '26.09.2026');
  });

  it('tek haneli gün/ay padStart: 2026-09-09 → 09.09.2026', () => {
    assert.strictEqual(sb.bcIsoTrGoster('2026-09-09'), '09.09.2026');
    assert.strictEqual(sb.bcIsoTrGoster('2027-01-05'), '05.01.2027');
  });

  it('boş / null / biçim dışı → boş string (bugün fallback YOK — alan placeholder gösterir)', () => {
    assert.strictEqual(sb.bcIsoTrGoster(''), '');
    assert.strictEqual(sb.bcIsoTrGoster(null), '');
    assert.strictEqual(sb.bcIsoTrGoster(undefined), '');
    assert.strictEqual(sb.bcIsoTrGoster('26.09.2026'), '', 'zaten TR biçimli girdi yutulmaz');
    assert.strictEqual(sb.bcIsoTrGoster('09/26/2026'), '');
    assert.strictEqual(sb.bcIsoTrGoster('2026-13-40'), '', 'ay 01-12 dışı reddedilir');
  });
});

describe('bcTrGosterIso (V2.3-W20 saf — TR DD.MM.YYYY → ISO; yuvarlama çifti)', () => {
  it("'26.09.2026' → '2026-09-26'", () => {
    assert.strictEqual(sb.bcTrGosterIso('26.09.2026'), '2026-09-26');
    assert.strictEqual(sb.bcTrGosterIso('05.01.2027'), '2027-01-05');
  });

  it('boş / null / biçim dışı → boş string', () => {
    assert.strictEqual(sb.bcTrGosterIso(''), '');
    assert.strictEqual(sb.bcTrGosterIso(null), '');
    assert.strictEqual(sb.bcTrGosterIso('2026-09-26'), '');
    assert.strictEqual(sb.bcTrGosterIso('26.09.26'), '');
    assert.strictEqual(sb.bcTrGosterIso('32.13.2026'), '', 'gün/ay aralık dışı reddedilir');
  });

  it('yuvarlama: bcTrGosterIso(bcIsoTrGoster(iso)) === iso ve tersi', () => {
    for (const iso of ['2026-09-26', '2026-09-09', '2027-01-01', '2026-12-31']) {
      assert.strictEqual(sb.bcTrGosterIso(sb.bcIsoTrGoster(iso)), iso, 'ISO→TR→ISO: ' + iso);
      const tr = sb.bcIsoTrGoster(iso);
      assert.strictEqual(sb.bcIsoTrGoster(sb.bcTrGosterIso(tr)), tr, 'TR→ISO→TR: ' + tr);
    }
  });
});

describe('bcTarihSecimEkle (V2.3-W20 saf — tek-seçim takvim durumu; min=bugun, maks=+365)', () => {
  const BUGUN = '2026-09-07';

  it('seçim DEĞİŞTİRİR: mevcut 2026-09-10 iken 2026-09-26 tıkı → secim 2026-09-26 (toggle yok)', () => {
    const r = host(sb.bcTarihSecimEkle('2026-09-10', '2026-09-26', BUGUN));
    assert.deepStrictEqual(r, { ok: true, secim: '2026-09-26', mesaj: null });
  });

  it('aynı güne tık idempotent: seçim korunur, ok', () => {
    const r = host(sb.bcTarihSecimEkle('2026-09-26', '2026-09-26', BUGUN));
    assert.deepStrictEqual(r, { ok: true, secim: '2026-09-26', mesaj: null });
  });

  it('geçmiş gün RED: mesaj tam "Geçmiş tarih seçilemez", mevcut seçim DOKUNULMAZ', () => {
    const r = host(sb.bcTarihSecimEkle('2026-09-10', '2026-09-06', BUGUN));
    assert.strictEqual(r.ok, false);
    assert.strictEqual(r.mesaj, 'Geçmiş tarih seçilemez');
    assert.strictEqual(r.secim, '2026-09-10');
  });

  it('sınır min: bugünün kendisi seçilebilir (2026-09-07)', () => {
    const r = host(sb.bcTarihSecimEkle(null, BUGUN, BUGUN));
    assert.strictEqual(r.ok, true);
    assert.strictEqual(r.secim, BUGUN);
  });

  it('sınır maks: bugün+365 seçilebilir; bugün+366 RED (mesaj 365 açıklar)', () => {
    const sinir = host(sb.bcTarihSecimEkle(null, '2027-09-07', BUGUN));
    assert.strictEqual(sinir.ok, true, 'bugün+365 ok');
    const tasma = host(sb.bcTarihSecimEkle('2026-09-10', '2027-09-08', BUGUN));
    assert.strictEqual(tasma.ok, false, 'bugün+366 red');
    assert.strictEqual(tasma.secim, '2026-09-10', 'mevcut seçim korunur');
    assert.ok(/365/.test(tasma.mesaj), 'mesaj sınırı açıklar: ' + tasma.mesaj);
    assert.ok(tasma.mesaj.includes('07.09.2027'), 'son gün (bugün+365) TR gösterilir: ' + tasma.mesaj);
  });

  it('geçersiz ISO RED: "⚠️ Geçersiz tarih" (bcTakvimSecimEkle kardeş dili)', () => {
    const r = host(sb.bcTarihSecimEkle(null, 'garbage', BUGUN));
    assert.strictEqual(r.ok, false);
    assert.strictEqual(r.mesaj, '⚠️ Geçersiz tarih');
  });
});

// ── V2.3-W21 DOM katmanı — bcTarihYaz/bcTarihDeger tek kapı + ipucu ──
// W21 (sahibe: 'iki buton da acayip duruyo ve ikisinin de aynı işlevi var'):
// alan input DEĞİL TEK BUTON — bcTarihYaz butunun GÖRÜNENİNİ yazar.

function bcTarihElSifirla() {
  const el = makeElement('button');
  sb.document.__setEl('bc-tarih', el);
  sb.bcTarihYaz('');
  return el;
}

describe('bcTarihYaz/bcTarihDeger (V2.3-W21 — butun görüneni 📅 DD.MM.YYYY, kanonik ISO; ayrışmaz)', () => {
  it('yaz: butun textContent "📅 26.09.2026", bcTarihDeger() ISO döner', () => {
    const el = bcTarihElSifirla();
    sb.bcTarihYaz('2026-09-26');
    assert.strictEqual(el.textContent, '📅 26.09.2026', 'görünen DD.MM.YYYY (tarayıcı yereli DEVRE DIŞI)');
    assert.strictEqual(sb.bcTarihDeger(), '2026-09-26', 'kanonik ISO');
  });

  it('okuma textContent DEĞİL: butun etiketi elle bozulsa bile kanonik ISO döner (diverge olmaz)', () => {
    const el = bcTarihElSifirla();
    sb.bcTarihYaz('2026-09-26');
    el.textContent = '09/26/2026'; // hayali tarayıcı yereli müdahalesi
    assert.strictEqual(sb.bcTarihDeger(), '2026-09-26');
  });

  it('boş yazım: butun "📅 Tarih seç" olur + kanonik boşalır (aynı anda)', () => {
    const el = bcTarihElSifirla();
    sb.bcTarihYaz('2026-09-26');
    sb.bcTarihYaz('');
    assert.strictEqual(el.textContent, '📅 Tarih seç');
    assert.strictEqual(sb.bcTarihDeger(), '');
  });

  it('geçersiz ISO yazımı yutulur (etiket 📅 Tarih seç + kanonik boş — asla yarım durum yok)', () => {
    const el = bcTarihElSifirla();
    sb.bcTarihYaz('09/26/2026');
    assert.strictEqual(el.textContent, '📅 Tarih seç');
    assert.strictEqual(sb.bcTarihDeger(), '');
  });
});

describe('bcTarihIpucuGuncelle (V2.3-W20 — hint BOŞLUKLU + TR tarih)', () => {
  function ipucuEl() {
    const el = makeElement('div');
    sb.document.__setEl('bc-tarih-ipucu', el);
    return el;
  }

  it('ileri tarih: "Vaka ve tüm tedavi günleri 26.09.2026 gününe planlanacak" — tarih çevresinde boşluk ZORUNLU', () => {
    bcTarihElSifirla();
    sb.bcTarihYaz('2026-09-26');
    const el = ipucuEl();
    sb.bcTarihIpucuGuncelle();
    assert.strictEqual(el.textContent, 'Vaka ve tüm tedavi günleri 26.09.2026 gününe planlanacak');
    assert.ok(el.textContent.includes(' 26.09.2026 '), 'tarih öncesi+sonrası boşluk');
    assert.ok(!el.textContent.includes('günleri2026'), 'sahibe ekranındaki bitişik hata kilitlenir');
  });

  it('boş tarih: varsayılan cümle aynen korunur', () => {
    bcTarihElSifirla();
    const el = ipucuEl();
    sb.bcTarihIpucuGuncelle();
    assert.strictEqual(el.textContent, 'Tarih boş bırakılırsa vakalar bugün açılır.');
  });
});

describe('bc-tarih takvim (V2.3-W20 DOM — tek-seçim picker; açılış/seçim/onay)', () => {
  // Gerçek bugün (vm bugun() stub'u ile aynı saat) — DOM yol testleri göreli tarih kurar.
  const BUGUN_ISO = (() => {
    const d = new Date();
    return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
  })();
  const isoKaydir = (base, n) => {
    const d = new Date(base + 'T00:00:00Z');
    d.setUTCDate(d.getUTCDate() + n);
    return d.toISOString().slice(0, 10);
  };

  // bc-gun-takvim testköprüsüyle aynı desen: appendChild'lanan kutuyu
  // getElementById köprüsüyle bul (yoksa her render yeni kutu yaratır).
  function takvimKoprusuKur() {
    if (!sb.document.__getByIdKoprulu) {
      const origGet = sb.document.getElementById.bind(sb.document);
      sb.document.getElementById = (id) => origGet(id) || sb.document.body.children.find(c => c.id === id) || null;
      sb.document.__getByIdKoprulu = true;
    }
  }

  it('açılış: kutu çizilir, başlıkta mevcut tarih TR (Seçilen: DD.MM.YYYY), Onayla/İptal var', () => {
    bcTarihElSifirla();
    sb.bcTarihYaz('2026-09-26');
    takvimKoprusuKur();
    sb.bcTarihTakvimAc();
    const kutu = sb.document.getElementById('bc-tarih-takvim');
    assert.ok(kutu, 'takvim kutusu açılır');
    assert.ok(kutu.innerHTML.includes('26.09.2026'), 'başlık TR tarih: ' + kutu.innerHTML.slice(0, 200));
    assert.ok(kutu.innerHTML.includes('bcTarihTakvimOnayla()'), 'Onayla butonu');
    sb.bcTarihTakvimKapat();
    assert.strictEqual(sb.document.getElementById('bc-tarih-takvim'), null, 'kapatma kutuyu kaldırır');
  });

  it('geçmiş güne tık: toast "Geçmiş tarih seçilemez", seçim değişmez', () => {
    bcTarihElSifirla();
    sb.bcTarihYaz(BUGUN_ISO);
    takvimKoprusuKur();
    sb.bcTarihTakvimAc();
    sb.__toasts.length = 0;
    sb.bcTarihTakvimSec(isoKaydir(BUGUN_ISO, -1));
    assert.strictEqual(sb.__toasts.length, 1);
    assert.strictEqual(sb.__toasts[0].isErr, true);
    assert.strictEqual(sb.__toasts[0].m, 'Geçmiş tarih seçilemez');
    sb.bcTarihTakvimKapat();
  });

  it('gelecek güne tık: başlık güncellenir; Onayla → butun "📅 TR" + bcTarihDeger ISO + ipucu boşluklu + kutu kapanır', () => {
    const el = bcTarihElSifirla();
    sb.bcTarihYaz(BUGUN_ISO);
    const ipucu = makeElement('div');
    sb.document.__setEl('bc-tarih-ipucu', ipucu);
    takvimKoprusuKur();
    sb.bcTarihTakvimAc();
    const hedef = isoKaydir(BUGUN_ISO, 10);
    sb.bcTarihTakvimSec(hedef);
    const kutu = sb.document.getElementById('bc-tarih-takvim');
    const trBeklenen = sb.bcIsoTrGoster(hedef);
    assert.ok(kutu.innerHTML.includes(trBeklenen), 'başlık yeni seçimi gösterir: ' + trBeklenen);
    sb.bcTarihTakvimOnayla();
    assert.strictEqual(el.textContent, '📅 ' + trBeklenen, 'butun DD.MM.YYYY etiketi');
    assert.strictEqual(sb.bcTarihDeger(), hedef, 'kanonik ISO');
    assert.strictEqual(ipucu.textContent, 'Vaka ve tüm tedavi günleri ' + trBeklenen + ' gününe planlanacak');
    assert.strictEqual(sb.document.getElementById('bc-tarih-takvim'), null, 'onay kutuyu kapatır');
  });

  it('ay ‹/› : bcTakvimAyKaydir dili — etiket değişir, seçim korunur', () => {
    bcTarihElSifirla();
    sb.bcTarihYaz('2026-09-26');
    takvimKoprusuKur();
    sb.bcTarihTakvimAc();
    sb.bcTarihTakvimSec('2026-09-26');
    sb.bcTarihTakvimAyDegistir(3);
    const kutu = sb.document.getElementById('bc-tarih-takvim');
    assert.ok(kutu.innerHTML.includes('Aralık 2026'), 'Eylül+3 → Aralık: ' + kutu.innerHTML.slice(0, 300));
    assert.ok(kutu.innerHTML.includes('26.09.2026'), 'seçim başlıkta kalır');
    sb.bcTarihTakvimAyDegistir(-3);
    assert.ok(sb.document.getElementById('bc-tarih-takvim').innerHTML.includes('Eylül 2026'), 'geri dönüş');
    sb.bcTarihTakvimKapat();
  });
});

describe('V2.3 (W21) — m-bulk-case tarih alanı yapısı + takvim aksiyonu + manifest damgası', () => {
  const fs = require('node:fs');

  function mBulkCaseBolumu() {
    const html = fs.readFileSync('index.html', 'utf8');
    const bas = html.indexOf('<div id="m-bulk-case"');
    const son = html.indexOf('<div id="m-sablon"');
    assert.ok(bas !== -1 && son > bas, 'm-bulk-case bölümü bulunamadı');
    return html.slice(bas, son);
  }

  it('handlers.js bc-tarih-takvim aksiyonunu kaydeder (takvim açılır)', () => {
    const src = fs.readFileSync('js/utils/handlers.js', 'utf8');
    assert.ok(/'bc-tarih-takvim':\s*\(\)\s*=>\s*bcTarihTakvimAc\(\)/.test(src));
  });

  it('index.html: #bc-tarih TEK buton (çift kontrol YOK) + hint sarma stili; m-bulk-case içinde type=date YOK', () => {
    const bolum = mBulkCaseBolumu();
    assert.strictEqual((bolum.match(/data-action="bc-tarih-takvim"/g) || []).length, 1,
      'TEK kontrol: readonly input + 📅 çifti kaldırıldı (sahibe W21)');
    assert.ok(/<button type="button" id="bc-tarih"/.test(bolum), '#bc-tarih artık BUTTON');
    assert.ok(/id="bc-tarih"[^>]*style="[^"]*width:100%/.test(bolum), 'buton tam genişlik');
    assert.ok(!/<input[^>]*id="bc-tarih"/.test(bolum), 'input kaldırıldı');
    assert.ok(/>📅 Tarih seç<\/button>/.test(bolum), 'ilk etiket 📅 Tarih seç');
    assert.ok(!/type="date"/.test(bolum), 'm-bulk-case içinde native date input KALMAZ');
    const ipucu = bolum.match(/<div id="bc-tarih-ipucu"[^>]*>/);
    assert.ok(ipucu && /overflow-wrap:\s*anywhere/.test(ipucu[0]), 'hint sarma stili (taşma kilidi)');
  });

  it('manifest link de damgalı: manifest.json?v=20260909-8', () => {
    const html = fs.readFileSync('index.html', 'utf8');
    assert.ok(html.includes('manifest.json?v=20260909-8'), 'manifest damgası 20260909-8');
    assert.ok(!html.includes('?v=20260907-4'), 'eski 20260907-4 damgası kalmaz');
    assert.ok(!html.includes('?v=20260907-3'), 'eski -3 damgası kalmaz');
    assert.ok(!html.includes('?v=20260907-2'), 'eski -2 damgası kalmaz');
  });
});
