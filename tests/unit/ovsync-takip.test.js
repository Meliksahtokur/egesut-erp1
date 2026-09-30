// tests/unit/ovsync-takip.test.js
// Ovsync takip ekranı birim testleri.
// Bölümler:
//   * KALEM 12 (P9b) — gunFarkiEtiket saf yardımcısı (helpers.js)
//   * KALEM 11 (P9) — _tohumlamaGecmisSatirlari (ui.js) + üreme geçmişi iki-satır
//   * K15 (P9) — birleşik muayene bağlamaları: detayTamamla dalı, ck-btn/ertele
//     exclusion, _muayeneSonucAc bağlam kurucusu, 40 g listesi satır çözücü
//   * PG kapısı (P9) — _pgKapiBosAtaUygula tek-RPC gövdesi (T-11)
//   * tohSonuc Boş dalı (P9) — seçici + bayrak-kapalı fallback (S-5/#6)
//   * TAKIP_MUAYENE etiketi (gecmis.js tek kaynak)
//   * D3 (P11) — secim-tablo senkron kilidi: _muayeneSecimleri ↔ migration DB CASE
//
// İstanbul sabit UTC+3'tür (2016'dan beri kalıcı yaz saati yok) — test girişleri
// Z-suffixed verilir ki makine saat diliminden bağımsız deterministik koşsun:
// "İstanbul 23:30" = "20:30Z", "İstanbul 00:30 (ertesi gün)" = "21:30Z".
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const helpers = require('../../js/utils/helpers.js');
const { extractFunctionSource, loadBrowserModule, makeElement } = require('./support/loadModule.js');

const REPO_ROOT = path.join(__dirname, '..', '..');

// Sabit bugün: 2026-09-30 — göreli gün etiketleri deterministik.
const BUGUN_ISO = '2026-09-30';

// KIRMIZI adımda işlev henüz yok — TypeError değil ASSERTION hatası düşsün
// diye tüm çağrılar bu kaptan geçer (eksik-özellik hatası = beklenen kırmızı).
function cagir(...args) {
  assert.strictEqual(typeof helpers.gunFarkiEtiket, 'function',
    'gunFarkiEtiket helpers.js dışa aktarılmalı');
  return helpers.gunFarkiEtiket(...args);
}

test('gunFarkiEtiket: bugün — aynı İstanbul takvim günü', () => {
  assert.strictEqual(cagir('2026-09-30T10:00:00Z', '2026-09-30'), 'bugün'); // 13:00 İstanbul
  assert.strictEqual(cagir('2026-09-30', '2026-09-30'), 'bugün');           // saatsiz tarih
});

test('gunFarkiEtiket: dün — önceki takvim günü', () => {
  assert.strictEqual(cagir('2026-09-29T20:30:00Z', '2026-09-30'), 'dün');   // 29 23:30 İstanbul
  assert.strictEqual(cagir('2026-09-29', '2026-09-30'), 'dün');             // saatsiz tarih
});

test('gunFarkiEtiket: gece yarısı sınırı — dün 23:30 vs bugün 00:30 fark 1', () => {
  // İki an arası gerçek fark yalnız 1 SAAT; takvim günü farkı 1.
  // Milisaniye-bölümü hesabı ikisini de aynı güne koyup 'bugün' verirdi — yanlış.
  assert.strictEqual(cagir('2026-09-29T20:30:00Z', '2026-09-30'), 'dün');   // 29 23:30 İstanbul
  assert.strictEqual(cagir('2026-09-29T21:30:00Z', '2026-09-30'), 'bugün'); // 30 00:30 İstanbul
});

test('gunFarkiEtiket: UTC sınırı — UTC 21:30 = İstanbul 00:30 ERTESİ gün', () => {
  // fmtTarih'in ilk-10-karakter kesimi '2026-09-29' okuyup 'dün' derdi — tuzak.
  assert.strictEqual(cagir('2026-09-29T21:30:00Z', '2026-09-30'), 'bugün'); // 30 00:30 İstanbul
  assert.strictEqual(cagir('2026-09-29T20:59:59Z', '2026-09-30'), 'dün');   // 29 23:59:59 İstanbul
});

test('gunFarkiEtiket: N gün önce — 1 kısaltması yalnız dünde', () => {
  assert.strictEqual(cagir('2026-09-15', '2026-09-30'), '15 gün önce');
  assert.strictEqual(cagir('2026-09-28', '2026-09-30'), '2 gün önce');
});

test('gunFarkiEtiket: ileri tarih — N gün sonra', () => {
  assert.strictEqual(cagir('2026-10-05', '2026-09-30'), '5 gün sonra');
});

test('gunFarkiEtiket: ay/yıl devri — takvim aritmetiği taşınmayı doğru sayar', () => {
  assert.strictEqual(cagir('2026-10-01', '2026-09-30'), '1 gün sonra');
  assert.strictEqual(cagir('2027-01-01', '2026-12-31'), '1 gün sonra');
  assert.strictEqual(cagir('2026-09-01', '2026-09-30'), '29 gün önce');
});

// ══════════════════════════════════════════════════════════════════════════
// P9 — bağlam kaptanları (ui.js / forms.js SAF ailesi vm ctx'te)
// ══════════════════════════════════════════════════════════════════════════

// ui.js P9 fonksiyon ailesi — birbirini çağırdığından TEK ctx'te yaşar.
const P9_UI_FNS = [
  '_tohGunNormalize',            // C1: Europe/Istanbul yerel takvim günü
  '_tohumlamaGecmisSatirlari',   // kalem 11 saf veri üretimi
  '_uremeTohumlama',             // kalem 11 render + P9b göreli gün bağlaması
  '_muayeneSonucAc',             // K15: görev → birleşik muayene ekranı
  '_muayene40gAc',               // 40 g listesi satır çözücü (§10d #4)
  '_pgKapiBosAtaUygula',         // PG kapısı tek-RPC gövdesi (T-11)
  'detayTamamla',                // K15 görev_tipi dalı
  'renderTask',                  // görev listesi exclusion (P3b UI ikizi)
  '_erteleBtnHtml',              // §18.17: erteleme yalnız sonuç ekranından
];
const P9_FORMS_FNS = ['tohSonuc'];

function p9Ctx(ekstra = {}) {
  const cagri = {
    muayene: [], openDet: [], doneTask: [], planliTohum: [], rpc: [],
    confirm: [], toast: [], closeM: [], pull: [], devamSecici: [], tekrar: [],
    bosVeDevam: [], loadTasks: [], renderLocal: [],
  };
  const win = ekstra.window || {};
  const stubs = {
    esc: v => String(v == null ? '' : v),
    escAttr: v => String(v == null ? '' : v),
    fmtTarih: helpers.fmtTarih,
    bugun: () => BUGUN_ISO,
    gunFarkiEtiket: (iso, ref) => helpers.gunFarkiEtiket(iso, ref == null ? BUGUN_ISO : ref),
    trLower: helpers.trLower,
    // kayıt kaptanları
    _muayeneSonucAc: async id => { cagri.muayene.push(id); return true; },
    openDet: id => { cagri.openDet.push(id); },
    openTohDet: id => { cagri.openDet.push('toh:' + id); },
    openTekrarAsim: () => {}, tekrarTohumla: () => {},
    doneTask: async (...a) => { cagri.doneTask.push(a); },
    openPlanliTohumlama: t => { cagri.planliTohum.push(t.id); },
    rpc: async (ad, params) => { cagri.rpc.push([ad, params]); return { ok: true }; },
    confirm: s => { cagri.confirm.push(s); return ekstra.confirmSonuc !== false; },
    toast: (m, err) => { cagri.toast.push([m, !!err]); },
    closeM: id => { cagri.closeM.push(id); },
    pullTables: async t => { cagri.pull.push(t); },
    renderFromLocal: async () => { cagri.renderLocal.push(1); },
    loadTasks: () => { cagri.loadTasks.push(1); },
    loadDash: () => {},
    getUserMessage: e => String((e && e.message) || e),
    _pgKapiKapat: () => { cagri.closeM.push('pg-kapi'); },
    tohumlamaBosVeDevam: async p => {
      cagri.bosVeDevam.push(p);
      if (p.p_secim === null) return ekstra.onbilgi || { ok: true, bayrak_kapali: false };
      return { ok: true };
    },
    _devamSeciciAc: async (mod, baglam) => {
      cagri.devamSecici.push([mod, baglam]);
      if (ekstra.seciciAc) win.__devamSecici = { acik: true, mod, baglam };
    },
    ertelemeKuralGetir: () => ({ ertelenebilir: true }),
    _ertelemeOnline: () => true,
    _cokluSecimKutuHtml: () => '',
    _tohKaynakEtiket: () => '',
    _kalanGunEtiket: () => '',
    _stokAdi: () => '',
    _ovsyncBaslatBtnHtml: () => '',
    detayAltTiklanabilir: () => true,
    RPC_TABLES: { tohumlama_bos_ve_devam: ['tohumlama', 'gorev_log'] },
    Date,
  };
  const src = P9_UI_FNS.map(n => extractFunctionSource('js/ui.js', n)).join('\n')
    + '\n' + P9_FORMS_FNS.map(n => extractFunctionSource('js/forms.js', n)).join('\n');
  const ctx = { console, Math, JSON, Date, ...stubs, ...ekstra.globals };
  ctx.window = win;
  ctx.globalThis = ctx;
  ctx.globalThis.window = win;
  ctx.document = { getElementById: () => null, createElement: () => makeElement('div') };
  if (ekstra.document) ctx.document = ekstra.document;
  vm.createContext(ctx);
  vm.runInContext(src, ctx, { filename: 'js/ui.js+js/forms.js#p9-saf' });
  return { ctx, cagri, win };
}

// Ortak fikstür — P2b S20 normatif örneği: UTC 25 Eyl 21:30 = İstanbul 26 Eyl 00:30.
const KALEM11_TOH = { id: 'T1', sonuc: 'Gebe', tarih: '2026-08-10', hayvan_id: 'h1', sperma: 'Bova', deneme_no: 2 };
const KALEM11_LOG = {
  id: 'L2', tip: 'GEBE_ATAMA', ref_tablo: 'tohumlama', ref_id: 'T1',
  tarih: '2026-09-25T21:30:00Z', durum: null,
  snapshot: { bos_duzeltme: { eski_sonuc: 'Boş', bos_atama_tarihi: '2026-09-14', takip_kapanis: 'GEBE_BULUNDU' } },
};

// ══ KALEM 11 — _tohumlamaGecmisSatirlari (saf) ════════════════════════════

test('KALEM11: düzeltilmiş tohumlama iki satır verir — Boş giriş tarihi + muayene tarihi', () => {
  const { ctx } = p9Ctx();
  const r = ctx._tohumlamaGecmisSatirlari(KALEM11_TOH, [KALEM11_LOG]);
  assert.ok(r && r.duzeltme, 'düzeltme işareti dönmeli');
  assert.equal(r.bosTarihi, '2026-09-14', 'üst satır = bos_duzeltme.bos_atama_tarihi (saatsiz aynen)');
  assert.equal(r.gebeTarihi, '2026-09-26', 'GEBE_ATAMA timestamptz → İstanbul yerel gün (UTC 21:30 = ertesi gün; ilk-10 kesimi YASAK)');
});

test('KALEM11: izsiz Gebe kaydı tek satır kalır (null)', () => {
  const { ctx } = p9Ctx();
  // GEBE_ATAMA hiç yok
  assert.equal(ctx._tohumlamaGecmisSatirlari(KALEM11_TOH, []), null);
  // normal (D1'siz) GEBE_ATAMA — bos_duzeltme bloğu YOK → düzeltme değil
  const normal = { ...KALEM11_LOG, snapshot: { iptal_sebep: 'gebe' } };
  assert.equal(ctx._tohumlamaGecmisSatirlari(KALEM11_TOH, [normal]), null);
  // islem_log listesi yoksa da null (tek satır görünüm)
  assert.equal(ctx._tohumlamaGecmisSatirlari(KALEM11_TOH, null), null);
});

test('KALEM11: geri_alindi GEBE_ATAMA seçilmez — IS DISTINCT FROM UI ikizi', () => {
  const { ctx } = p9Ctx();
  assert.equal(ctx._tohumlamaGecmisSatirlari(KALEM11_TOH, [{ ...KALEM11_LOG, durum: 'geri_alindi' }]), null);
  const { ctx: c2 } = p9Ctx();
  const r = c2._tohumlamaGecmisSatirlari(KALEM11_TOH, [
    { ...KALEM11_LOG, durum: 'geri_alindi', id: 'L9' },
    KALEM11_LOG,
  ]);
  assert.ok(r && r.duzeltme, 'geri_alindi yanında geçerli kayıt varsa düzeltme görünür');
  assert.equal(r.gebeTarihi, '2026-09-26');
});

test('KALEM11: çoklu kayıtta EN SON kazanır — tarih DESC, id DESC (P2b S28 UI ikizi)', () => {
  const { ctx } = p9Ctx();
  const eski = { ...KALEM11_LOG, id: 'L1', tarih: '2026-09-20T10:00:00Z', snapshot: { bos_duzeltme: { eski_sonuc: 'Boş', bos_atama_tarihi: '2026-09-05' } } };
  const r = ctx._tohumlamaGecmisSatirlari(KALEM11_TOH, [eski, KALEM11_LOG]);
  assert.equal(r.gebeTarihi, '2026-09-26', 'daha yeni tarihli kayıt kazanır');
  assert.equal(r.bosTarihi, '2026-09-14');
  // aynı tarih → id DESC
  const a = { ...KALEM11_LOG, id: 'L2' };
  const b = { ...KALEM11_LOG, id: 'L9' };
  const r2 = ctx._tohumlamaGecmisSatirlari(KALEM11_TOH, [a, b]);
  assert.ok(r2 && r2.duzeltme, 'aynı tarihte en büyük id kazanır (kayıt yine düzeltme)');
});

test('KALEM11: sonuc Gebe değilse / kayıt başka tohumlamaya aitse satır yok', () => {
  const { ctx } = p9Ctx();
  assert.equal(ctx._tohumlamaGecmisSatirlari({ ...KALEM11_TOH, sonuc: 'Boş' }, [KALEM11_LOG]), null);
  assert.equal(ctx._tohumlamaGecmisSatirlari({ ...KALEM11_TOH, sonuc: 'Bekliyor' }, [KALEM11_LOG]), null);
  assert.equal(ctx._tohumlamaGecmisSatirlari(KALEM11_TOH, [{ ...KALEM11_LOG, ref_id: 'DIGER' }]), null);
  assert.equal(ctx._tohumlamaGecmisSatirlari(null, [KALEM11_LOG]), null);
});

// ══ KALEM 11 — _uremeTohumlama render + P9b göreli gün ════════════════════

test('KALEM11-RENDER: düzeltilmiş satırda üstü çizili Boş + altta Gebe — her satır kendi göreli günü', async () => {
  const el = makeElement('div');
  const { ctx } = p9Ctx({
    globals: {
      idbGetAll: async tablo => (tablo === 'tohumlama' ? [KALEM11_TOH] : tablo === 'islem_log' ? [KALEM11_LOG] : []),
      getState: () => [{ id: 'h1', kupe_no: '197', grup: 'Sağmal' }],
    },
  });
  ctx.globalThis._tohSearch = '';
  await ctx._uremeTohumlama(el);
  const html = el.innerHTML;
  assert.ok(html.includes('line-through'), 'Boş satırı üstü çizili');
  assert.ok(html.includes('❌ Boş'), 'üst satır ❌ Boş');
  assert.ok(html.includes('14.09.2026'), 'Boş satırı Boş giriş tarihini taşır');
  assert.ok(html.includes('16 gün önce'), 'Boş satırının göreli günü KENDİ tarihinden (14.09 → 30.09)');
  assert.ok(html.includes('✅ Gebe'), 'alt satır ✅ Gebe');
  assert.ok(html.includes('26.09.2026'), 'Gebe satırı muayene (GEBE_ATAMA) tarihini taşır');
  assert.ok(html.includes('4 gün önce'), 'Gebe satırının göreli günü KENDİ tarihinden (26.09 → 30.09)');
});

test('KALEM11-RENDER: izsiz Gebe kaydı tek sonuç satırı + göreli gün', async () => {
  const el = makeElement('div');
  const { ctx } = p9Ctx({
    globals: {
      idbGetAll: async tablo => (tablo === 'tohumlama' ? [KALEM11_TOH] : []),
      getState: () => [{ id: 'h1', kupe_no: '197' }],
    },
  });
  ctx.globalThis._tohSearch = '';
  await ctx._uremeTohumlama(el);
  const html = el.innerHTML;
  assert.ok(!html.includes('line-through'), 'düzeltme yok — üstü çizili satır yok');
  assert.ok(!html.includes('✅ Gebe'), 'izsiz kayıtta iki-satır işareti yok (mevcut görünüm: düz Gebe)');
  assert.equal((html.match(/hist-sub/g) || []).length, 1, 'tek sonuç satırı');
  assert.ok(html.includes('>Gebe</b>'), 'Gebe etiketi mevcut görünümdeki gibi');
  assert.ok(html.includes('10.08.2026'), 'tek satır tohumlama tarihini taşır');
  assert.ok(html.includes('51 gün önce'), 'göreli gün etiketi (10.08 → 30.09)');
});

// ══ K15 — detayTamamla görev_tipi dalı ════════════════════════════════════

test('K15: detayTamamla GEBELIK_KONTROL görevini _muayeneSonucAc\'a yönlenir — doneTask YOK', async () => {
  const { ctx, cagri } = p9Ctx({
    seciciAc: true,
    globals: {
      _curTaskDet: { id: 'G1', gorev_tipi: 'GEBELIK_KONTROL' },
      idbGetAll: async t => (t === 'gorev_log' ? [MUAYENE_GOREV] : []),
      getState: () => [{ id: 'h1', kupe_no: '197' }],
    },
  });
  await ctx.detayTamamla();
  assert.equal(cagri.devamSecici.length, 1, 'birleşik sonuç ekranına gider');
  assert.equal(cagri.devamSecici[0][0], 'muayene');
  assert.equal(cagri.devamSecici[0][1].muayene_gorev_id, 'G1');
  assert.deepEqual(cagri.doneTask, [], 'jenerik gorev_tamamla yoluna düşmez (P3b UI ikizi)');
});

test('K15: TAKIP_MUAYENE aynı yol — iki görev tipi AYNI ekran (ekran-özdeşliği)', async () => {
  const { ctx, cagri } = p9Ctx({
    seciciAc: true,
    globals: {
      _curTaskDet: { id: 'G2', gorev_tipi: 'TAKIP_MUAYENE' },
      idbGetAll: async t => (t === 'gorev_log' ? [{ ...MUAYENE_GOREV, id: 'G2', gorev_tipi: 'TAKIP_MUAYENE' }] : []),
      getState: () => [{ id: 'h1', kupe_no: '197' }],
    },
  });
  await ctx.detayTamamla();
  assert.equal(cagri.devamSecici.length, 1);
  assert.equal(cagri.devamSecici[0][0], 'muayene', 'iki tip AYNI _devamSeciciAc(muayene) yolu');
  assert.equal(cagri.devamSecici[0][1].gorev_tipi, 'TAKIP_MUAYENE');
  assert.deepEqual(cagri.doneTask, []);
});

test('K15: TOHUMLAMA_PLANLI dalı korunur (regresyon kilidi)', async () => {
  const { ctx, cagri } = p9Ctx({ globals: { _curTaskDet: { id: 'G3', gorev_tipi: 'TOHUMLAMA_PLANLI' } } });
  await ctx.detayTamamla();
  assert.deepEqual(cagri.planliTohum, ['G3']);
  assert.deepEqual(cagri.muayene, []);
});

// ══ K15 — görev listesi exclusion + ertele kilidi ═════════════════════════

function renderTaskHtml(ctx, gorevTipi) {
  const hayvanlar = [{ id: 'h1', kupe_no: '197' }];
  ctx.getState = () => hayvanlar;
  return ctx.renderTask(
    { id: 'g1', gorev_tipi: gorevTipi, hedef_tarih: BUGUN_ISO, hayvan_id: 'h1', aciklama: 'test' },
    '', [], [], '',
  );
}

test('K15: ck-btn (hızlı tamam) muayene tiplerinde çizilmez — P3b guard UI ikizi', () => {
  const { ctx } = p9Ctx();
  assert.ok(!/ck-btn/.test(renderTaskHtml(ctx, 'GEBELIK_KONTROL')), 'GEBELIK_KONTROL hızlı-tamam yok');
  assert.ok(!/ck-btn/.test(renderTaskHtml(ctx, 'TAKIP_MUAYENE')), 'TAKIP_MUAYENE hızlı-tamam yok');
  assert.ok(/ck-btn/.test(renderTaskHtml(ctx, 'DIGER')), 'kontrol: sıradan görevde ck-btn durur');
});

test('K15: genel ertele butonu muayene tiplerinde yok — erteleme yalnız sonuç ekranından (§18.17)', () => {
  const { ctx } = p9Ctx();
  assert.equal(ctx._erteleBtnHtml({ id: 'g1', gorev_tipi: 'GEBELIK_KONTROL' }), '');
  assert.equal(ctx._erteleBtnHtml({ id: 'g1', gorev_tipi: 'TAKIP_MUAYENE' }), '');
  assert.ok(ctx._erteleBtnHtml({ id: 'g1', gorev_tipi: 'DIGER', hedef_tarih: BUGUN_ISO }).includes('Ertele'),
    'kontrol: sıradan ertelenebilir görevde buton durur (kural tablodan)');
});

// ══ K15 — _muayeneSonucAc bağlam kurucusu ═════════════════════════════════

const MUAYENE_GOREV = {
  id: 'G1', gorev_tipi: 'GEBELIK_KONTROL', hayvan_id: 'h1',
  tamamlandi: false, iptal: false, created_at: '2026-09-25T21:30:00Z',
};

test('K15: _muayeneSonucAc görev bağlamından seçiciyi kurar', async () => {
  const { ctx, cagri } = p9Ctx({
    seciciAc: true,
    globals: {
      idbGetAll: async t => (t === 'gorev_log' ? [MUAYENE_GOREV] : []),
      getState: () => [{ id: 'h1', kupe_no: '197', grup: 'Sağmal' }],
    },
  });
  const acildi = await ctx._muayeneSonucAc('G1');
  assert.equal(acildi, true, 'seçici açıldı');
  assert.equal(cagri.devamSecici.length, 1);
  const [mod, baglam] = cagri.devamSecici[0];
  assert.equal(mod, 'muayene');
  assert.equal(baglam.muayene_gorev_id, 'G1');
  assert.equal(baglam.gorev_tipi, 'GEBELIK_KONTROL');
  assert.equal(baglam.kupe_no, '197');
  assert.equal(baglam.grup, 'Sağmal');
  assert.equal(baglam.bos_tarihi, '2026-09-26', 'created_at İstanbul yerel günü (P8 bos_tarihi sözleşmesi)');
});

test('K15: kapalı/bulunamayan muayene görevinde seçici AÇILMAZ (false + tazeleme)', async () => {
  const { ctx, cagri } = p9Ctx({
    globals: {
      idbGetAll: async t => (t === 'gorev_log' ? [{ ...MUAYENE_GOREV, tamamlandi: true }] : []),
      getState: () => [{ id: 'h1', kupe_no: '197' }],
    },
  });
  const acildi = await ctx._muayeneSonucAc('G1');
  assert.equal(acildi, false);
  assert.deepEqual(cagri.devamSecici, [], 'kapalı görevde seçici açılmaz');
  assert.ok(cagri.pull.length >= 1, 'liste tazelenir');
});

test('40G: acik_gorev_var=false → hayvan detayı; açık görev → _muayeneSonucAc; bayat IDB → detay (fail-closed)', async () => {
  const { ctx, cagri } = p9Ctx({
    seciciAc: true,
    globals: {
      idbGetAll: async t => (t === 'gorev_log' ? [MUAYENE_GOREV] : []),
      getState: () => [{ id: 'h1', kupe_no: '197' }],
    },
  });
  await ctx._muayene40gAc('h1', false);
  assert.deepEqual(cagri.openDet, ['h1'], 'bayraksız satır bugünkü davranış');
  assert.deepEqual(cagri.devamSecici, []);

  await ctx._muayene40gAc('h1', true);
  assert.equal(cagri.devamSecici.length, 1, 'IDB açık GEBELIK_KONTROL → sonuç ekranı');
  assert.equal(cagri.devamSecici[0][1].muayene_gorev_id, 'G1');
  assert.deepEqual(cagri.openDet, ['h1'], 'açık görevli satır detaya DÜŞMEZ');

  const { ctx: c2, cagri: g2 } = p9Ctx({
    seciciAc: true,
    globals: {
      idbGetAll: async t => (t === 'gorev_log' ? [{ ...MUAYENE_GOREV, tamamlandi: true }] : []),
      getState: () => [{ id: 'h1', kupe_no: '197' }],
    },
  });
  await c2._muayene40gAc('h1', true);
  assert.deepEqual(g2.devamSecici, [], 'IDB bayat — görev bulunamadı');
  assert.deepEqual(g2.openDet, ['h1'], 'fail-closed: hayvan detayı (§10d #4)');
});

// ══ PG kapısı — tek RPC gövdesi (T-11) ════════════════════════════════════

test('PG-KAPI: gövde tek RPC — tohumlamaBosVeDevam; tohumlama_sonuc_bos/tekrar zinciri YOK', () => {
  const govde = extractFunctionSource('js/ui.js', '_pgKapiBosAtaUygula');
  assert.ok(govde.includes('tohumlamaBosVeDevam('), 'yeni gövde sarmal RPC\'yi çağırır');
  assert.ok(!govde.includes("rpc('tohumlama_sonuc_bos'"), 'iki-RPC zincirinin ilk ayağı kalktı');
  assert.ok(!govde.includes('__pgKapiTekrar('), 'ikinci-dokunuş tekrar zinciri kalktı (tek transaction)');
});

function pgKapiCtx(ekstra = {}) {
  const onaylaBtn = makeElement('button');
  const gerekceInput = makeElement('input');
  gerekceInput.value = '35. gün negatif';
  const doc = {
    getElementById: id => (id === 'pg-kapi-onayla' ? onaylaBtn : id === 'pg-kapi-gerekce' ? gerekceInput : null),
    createElement: () => makeElement('div'),
  };
  return p9Ctx({
    document: doc,
    window: { __pgKapiToh: 'TOH1', __pgKapiTekrar: async () => { throw new Error('tekrar çağrılmamalı'); } },
    onbilgi: ekstra.onbilgi || { ok: true, bayrak_kapali: false, son_pg: { stok_id: 'S1', urun_adi: 'Dinoprost', doz: 2.5, birim: 'ml' } },
    ...ekstra,
  });
}

test('PG-KAPI: dry-run son_pg ile TEK yazma — PG + ürün/doz + gerekçe + p_onay', async () => {
  const { ctx, cagri, win } = pgKapiCtx();
  await ctx._pgKapiBosAtaUygula();
  const dry = cagri.bosVeDevam.filter(p => p.p_secim === null);
  const yazma = cagri.bosVeDevam.filter(p => p.p_secim !== null);
  assert.equal(dry.length, 1, 'ürün çözümü için bir dry-run (yazmasız)');
  assert.equal(yazma.length, 1, 'YAZMA TEK ÇAĞRI — yarım durum yok (T-11)');
  const p = yazma[0];
  assert.equal(p.p_tohumlama_id, 'TOH1');
  assert.equal(p.p_secim, 'PG');
  assert.equal(p.p_pg_urun, 'S1', 'ürün = dry-run son_pg (seçicinin ön dolusunun karşılığı)');
  assert.equal(p.p_pg_doz, 2.5);
  assert.equal(p.p_notlar, 'PG öncesi değerlendirme: 35. gün negatif');
  assert.equal(p.p_onay, true, 'kapı onayı tek onay');
  assert.ok(cagri.closeM.includes('pg-kapi'), 'başarıda kapı kapanır');
});

test('PG-KAPI: son_pg çözümsüzse yazma YAPILMAZ (fail-closed)', async () => {
  const { ctx, cagri } = pgKapiCtx({ onbilgi: { ok: true, bayrak_kapali: false, son_pg: null } });
  await ctx._pgKapiBosAtaUygula();
  assert.equal(cagri.bosVeDevam.filter(p => p.p_secim !== null).length, 0, 'ürünsüz PG yazılmaz (PG_URUN_GEREKLI önlenir)');
  assert.ok(cagri.toast.some(t => t[1]), 'hata bildirimi var');
  assert.ok(!cagri.closeM.includes('pg-kapi'), 'kapı açık kalır — hiçbir şey yazılmadı');
});

// ══ tohSonuc Boş dalı — seçici + bayrak-kapalı fallback (S-5/#6) ══════════

const TOH_CTX = { id: 'T1', sonuc: 'Bekliyor', tarih: '2026-08-10', hayvan_id: 'h1', sperma: 'Bova' };

test('TOH-SONUC: Boş seçimi seçiciyi açar — doğrudan tohumlama_sonuc_bos/confirm ÇAĞRILMAZ', async () => {
  const { ctx, cagri } = p9Ctx({
    seciciAc: true,
    globals: { _curToh: TOH_CTX, getState: () => [{ id: 'h1', kupe_no: '197', grup: 'Sağmal' }] },
  });
  await ctx.tohSonuc('Boş');
  assert.equal(cagri.devamSecici.length, 1, '_devamSeciciAc(bos) çağrıldı');
  const [mod, baglam] = cagri.devamSecici[0];
  assert.equal(mod, 'bos');
  assert.equal(baglam.tohumlama_id, 'T1');
  assert.equal(baglam.kupe_no, '197');
  assert.equal(baglam.tohumlama_tarihi, '2026-08-10');
  assert.equal(baglam.sperma, 'Bova');
  assert.deepEqual(cagri.rpc.filter(([ad]) => ad === 'tohumlama_sonuc_bos'), [], 'eski doğrudan Boş RPC\'si kalktı');
  assert.deepEqual(cagri.confirm, [], 'confirm() kalktı — seçim seçicide zorunlu');
  assert.ok(cagri.closeM.includes('m-toh-det'), 'sonuç modalı kapanır — akış seçicide');
});

test('TOH-SONUC: seçici açılamadı (bayrak kapalı) → bugünkü davranış: confirm + tohumlama_sonuc_bos', async () => {
  const { ctx, cagri } = p9Ctx({
    seciciAc: false,
    globals: { _curToh: TOH_CTX, getState: () => [{ id: 'h1', kupe_no: '197' }] },
  });
  await ctx.tohSonuc('Boş');
  assert.ok(cagri.confirm.length === 1, 'fallback confirm');
  assert.deepEqual(cagri.rpc.filter(([ad]) => ad === 'tohumlama_sonuc_bos'),
    [['tohumlama_sonuc_bos', { p_tohumlama_id: 'T1' }]], '#6: bayrak kapalı → eski yol');
  assert.ok(cagri.closeM.includes('m-toh-det'));
});

test('TOH-SONUC: fallback confirm reddedilirse hiçbir şey yazılmaz', async () => {
  const { ctx, cagri } = p9Ctx({
    seciciAc: false, confirmSonuc: false,
    globals: { _curToh: TOH_CTX, getState: () => [] },
  });
  await ctx.tohSonuc('Boş');
  assert.deepEqual(cagri.rpc, []);
});

test('TOH-SONUC: Gebe/Bekliyor yolları DEĞİŞMEZ (regresyon kilidi)', async () => {
  const { ctx, cagri } = p9Ctx({
    globals: { _curToh: TOH_CTX, getState: () => [{ id: 'h1', kupe_no: '197' }] },
  });
  await ctx.tohSonuc('Gebe');
  assert.deepEqual(cagri.rpc.filter(([ad]) => ad === 'tohumlama_sonuc_gebe').length, 1);
  assert.deepEqual(cagri.devamSecici, [], 'Gebe yolunda seçici YOK');
  await ctx.tohSonuc('Bekliyor');
  assert.deepEqual(cagri.rpc.filter(([ad]) => ad === 'tohumlama_sonuc_bekliyor').length, 1);
  // Gebe/Doğum Yaptı kaydı değiştirilemez (mevcut guard korunur)
  const { ctx: c2, cagri: g2 } = p9Ctx({
    globals: { _curToh: { ...TOH_CTX, sonuc: 'Gebe' }, getState: () => [] },
  });
  await c2.tohSonuc('Boş');
  assert.deepEqual(g2.rpc, []);
  assert.deepEqual(g2.devamSecici, []);
  assert.ok(g2.toast.some(t => t[1]), 'koruma mesajı');
});

// ══ TAKIP_MUAYENE etiketi (gecmis.js tek kaynak) ══════════════════════════

test('ETIKET: TAKIP_MUAYENE → "Takip Muayenesi" (gecmis.js tek kaynak; Değişiklikler aynı kaynaktan)', () => {
  const { sandbox } = loadBrowserModule('js/gecmis.js');
  assert.equal(sandbox.gmKodDegerEtiketi('gorev_tipi', 'TAKIP_MUAYENE'), 'Takip Muayenesi');
});

// ══ D3 — secim-tablo senkron kilidi (P11; plan.md:674) ═════════════════════
// İki kaynak birebir kilitli: ui.js _devamD3 tablosu (_muayeneSecimleri) ↔
// migration 20260929000002'deki DB CASE (v_gecerli := CASE v_gorev.gorev_tipi,
// muayene yolu seçim doğrulaması). Test migration metnini fs ile OKUR — CASE
// satırı değişirse test kırılır (kaynak-okuma deseni: tests/unit/ovsync-api.test.js
// dosya-okuma testleri; UI yükleme deseni: tests/unit/ovsync-secici.test.js loadUiSaf).

const D3_MIGRATION = 'supabase/migrations/20260929000002_takip_gorev_ve_bos_devam.sql';

// Migration CASE bloğundan iki görev tipinin seçim kümelerini ayıklar.
// GEBELIK_KONTROL → WHEN satırı; TAKIP_MUAYENE → ELSE satırı (DB'de adıyla
// satır YOKTUR — muayene görev tipleri :605 guard'ıyla ikisiyle sınırlıdır).
function d3DbSetleri() {
  const sql = fs.readFileSync(path.join(REPO_ROOT, D3_MIGRATION), 'utf8');
  const bas = sql.indexOf('v_gecerli := CASE v_gorev.gorev_tipi');
  assert.ok(bas !== -1,
    'migration D3 CASE bloğu bulunamadı (v_gecerli := CASE v_gorev.gorev_tipi) — migration metni değişti, D3 kilidi güncellenmeli');
  const son = sql.indexOf('END;', bas);
  assert.ok(son !== -1, 'D3 CASE bloğunun END; kapanışı bulunamadı');
  const blok = sql.slice(bas, son);
  const kume = desen => {
    const m = blok.match(desen);
    assert.ok(m, `D3 CASE satırı okunamadı: ${desen}`);
    return m[1].split(',').map(s => s.trim().replace(/^'|'$/g, '')).filter(s => s.length > 0);
  };
  return {
    gebelik: kume(/WHEN 'GEBELIK_KONTROL' THEN p_secim IN \(([^)]*)\)/),
    else_: kume(/ELSE p_secim IN \(([^)]*)\)/),
  };
}

// ui.js tam modül (saf yüzey) — D3 tablosunu gerçek yardımcı üzerinden okur.
function uiTamYukle() {
  return loadBrowserModule('js/ui.js', {
    expose: [],
    extra: {
      esc: v => String(v == null ? '' : v),
      escAttr: v => String(v == null ? '' : v),
      getData: async () => [],
      getState: () => [],
      fmtTarih: helpers.fmtTarih,
      dFwd: helpers.dFwd,
      bugun: helpers.bugun,
      rpc: async () => { throw new Error('rpc stub: D3 testinde rpc kullanılmaz'); },
      tohumlamaBosVeDevam: async () => { throw new Error('tohumlamaBosVeDevam stub: D3 testinde beklenmeyen çağrı'); },
      toast: () => {},
      openConfirm: () => {},
      pullTables: async () => {},
      loadDash: () => {},
      loadTasks: () => {},
      loadOvsyncDash: () => {},
    },
  });
}

test('D3: _muayeneSecimleri tablosu migration DB CASE ile birebir — secim-tablo senkron kilidi', () => {
  const { sandbox: ui } = uiTamYukle();
  assert.equal(typeof ui._muayeneSecimleri, 'function', '_muayeneSecimleri ui.js\'te yok');
  const db = d3DbSetleri();

  // plan.md:674 birebir beklenenler
  assert.deepEqual(ui._muayeneSecimleri('GEBELIK_KONTROL'), ['GEBE', 'OVSYNC', 'PG', 'TAKIP', 'ERTALE']);
  assert.deepEqual(ui._muayeneSecimleri('TAKIP_MUAYENE'), ['GEBE', 'OVSYNC', 'PG', 'ERTALE'],
    'TAKIP_MUAYENE seçeneklerinde TAKIP yok (sunucu karşılığı TAKIP_YENIDEN_SECILEMEZ)');

  // UI ↔ DB birebirlik: SQL IN kümesi sırasız → sıralı karşılaştırma
  assert.deepEqual([...ui._muayeneSecimleri('GEBELIK_KONTROL')].sort(), [...db.gebelik].sort(),
    'GEBELIK_KONTROL: ui _devamD3 kümesi ≠ migration CASE WHEN kümesi');
  assert.deepEqual([...ui._muayeneSecimleri('TAKIP_MUAYENE')].sort(), [...db.else_].sort(),
    'TAKIP_MUAYENE: ui _devamD3 kümesi ≠ migration CASE ELSE kümesi');

  // D3 özü iki kaynakta da: TAKIP yalnız GEBELIK_KONTROL'de
  assert.ok(db.gebelik.includes('TAKIP'), 'DB GEBELIK_KONTROL dalı TAKIP taşımıyor — D3 ihlali');
  assert.ok(!db.else_.includes('TAKIP'), 'DB ELSE (TAKIP_MUAYENE) dalı TAKIP taşıyor — D3 ihlali');
});
