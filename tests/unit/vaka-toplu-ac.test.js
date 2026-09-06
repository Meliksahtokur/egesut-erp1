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
