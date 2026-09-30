// tests/unit/ovsync-render.test.js — PLAN P6: S0–S4 render + KPA şeridi (js/ui.js)
// Kırmızı→yeşil TDD. Kapsam:
//   * _ovsyncGunDurumu matrisi (5 durum + tutarsiz + bilinmiyor yolları, §7.3/§7.8)
//   * _ovsyncGunSinif CSS eşlemesi (tamam yeşil · plan amber · gecikti kırmızı ·
//     uygulanmadı soluk · tutarsız ⚠ — R12)
//   * KPA sınıf kuralı (_ovsyncStatSinif — P7 _dashStatRow bağlayacak)
//   * KPA şeridi: bekleyen_baslatma toplam + "(N takipte)" alt metni (§10c #8)
//   * rozetler: deneme (§18.14 son doğumdan), sapma, takipte (mockup 06), muayene sayaç,
//     sonlanma (close_reason + toh_sonuc, §7.4/§7.5)
//   * satır/bölüm/sayfa HTML: S0 boşsa gizli, S3 ilk 5 + tümü, S4 katlanır,
//     tanınmayan → "bilinmiyor" (§7.8 — sessiz varsayılan YASAK)
//   * satır aksiyonları MEVCUT motorlara: openTaskDet / openCaseDet /
//     _ovsyncBaslatKilitHtml / _erteleBtnHtml / _ovsyncMuayeneSatirAc→(P9 _muayeneSonucAc
//     ya da openDet — §10d #2)
//   * eşik-sızıntısı: 21/50/55 sayıları ovsync render kodunda YOK (eşikler RPC'den)
// Desen: extractFunctionSource ile SAF ailesi tek vm ctx'te (render ailesi birbirini çağırır).
'use strict';

const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { extractFunctionSource } = require('./support/loadModule.js');

const UI = 'js/ui.js';
const REPO_ROOT = path.join(__dirname, '..', '..');
const uiSrc = fs.readFileSync(path.join(REPO_ROOT, UI), 'utf8');

// ── Sabit bugün: 2026-09-30 (çarşamba) — Date stub'ı determinizmi taşır ──
const BUGUN_ISO = '2026-09-30';

class SabitDate extends Date {
  constructor(...a) { super(a.length ? a : ['2026-09-30T10:00:00']); }
  static now() { return new Date('2026-09-30T10:00:00').getTime(); }
}

// SAF ailesi + gerçek motor gövdeleri (render ailesi birbirini çağırır — tek ctx).
const SAF_FNS = [
  // render ailesi (P6 üretir)
  '_ovsyncGunDurumu', '_ovsyncGunSinif', '_ovsyncGunAy', '_ovsyncStatSinif',
  '_ovsyncKpaHtml', '_ovsyncDenemeRozeti', '_ovsyncSapmaRozeti',
  '_ovsyncTakipteRozeti', '_ovsyncMuayeneHtml', '_ovsyncSonlanmaRozeti',
  '_ovsyncGunlerHtml', '_ovsyncS0Tip', '_ovsyncSatirHtml',
  '_ovsyncBolumHtml', 'renderOvsyncSayfa',
  // satır üreticileri + yardımcılar (_ovsyncSatirHtml bunları çağırır)
  '_ovsyncS0SatirHtml', '_ovsyncS1SatirHtml', '_ovsyncS2SatirHtml',
  '_ovsyncS3SatirHtml', '_ovsyncS4SatirHtml', '_ovsyncBilinmeyenSatirHtml',
  '_ovsyncBaglamAl', '_ovsyncDalgaGrupla', '_ovsyncTabanEtiketi',
  // S2 satır aksiyonu köprüsü (P9 _muayeneSonucAc çağrı noktası; §10d #2 fallback)
  '_ovsyncMuayeneSatirAc',
  // IDB eşleme kurucusu (RPC satırında case_id / OVSYNC_BASLAT gorev_id taşınmaz)
  '_ovsyncBaglamKur',
  // gerçek motor gövdeleri (bağ kanıtı): pencere kilit + Başlat/İptal/Ertele markup
  '_ovsyncBaslatKilitHtml', '_ovsyncBaslatPencereGunu', '_erteleBtnHtml',
];

function ovsyncCtx(ekstra = {}) {
  const cagri = { muayene: [], openDet: [], baslat: [], ertele: [], iptal: [] };
  const stubs = {
    esc: v => String(v == null ? '' : v),
    escAttr: v => String(v == null ? '' : v),
    bugun: () => BUGUN_ISO,
    // motor kayıtları — render çıktısı bunları ADIYLA taşır; köprü davranışı burada pinlenir
    _muayeneSonucAc: id => { cagri.muayene.push(id); },
    openDet: id => { cagri.openDet.push(id); },
    ovsyncBaslat: (g, h) => { cagri.baslat.push([g, h]); },
    ovsyncIptal: id => { cagri.iptal.push(id); },
    _erteleModal: id => { cagri.ertele.push(id); },
    // _erteleBtnHtml bağımlılıkları (kural JS'e YAZILMAZ — §18.10; test stub'u meşru)
    ertelemeKuralGetir: () => ({ ertelenebilir: true }),
    _ertelemeOnline: () => true,
    Date: SabitDate,
    ...ekstra,
  };
  const src = SAF_FNS.map(n => extractFunctionSource(UI, n)).join('\n');
  const ctx = { console, Math, JSON, ...stubs };
  const win = ekstra.window || { _curOvsyncBolum: { acik: {} }, _ovsyncBaglam: null };
  ctx.window = win;
  ctx.globalThis = ctx;
  ctx.globalThis.window = win;
  vm.createContext(ctx);
  vm.runInContext(src, ctx, { filename: UI + '#ovsync-saf' });
  return { ctx, cagri };
}

// ══ 1. _ovsyncGunDurumu matrisi (5+1 durum + bilinmiyor) ══════════════════

test('GUN-DURUMU: RPC durum otoritesi tanınan değeri aynen taşır', () => {
  const { ctx } = ovsyncCtx();
  for (const d of ['planli', 'tamam', 'gecikti', 'uygulanmadi', 'tutarsiz']) {
    assert.equal(ctx._ovsyncGunDurumu({ durum: d, tarih: '2026-09-20' }, BUGUN_ISO, false), d,
      `RPC durumu ${d} JS'te yeniden hesaplanmamalı (tek hesap noktası RPC)`);
  }
});

test('GUN-DURUMU: fallback matrisi — tamam / tutarsiz (§7.3 gelecek tamam kaydı)', () => {
  const { ctx } = ovsyncCtx();
  // RPC durumu yok: tamamlandi_tarihi dolu + gün geçmiş → tamam
  assert.equal(ctx._ovsyncGunDurumu({ tarih: '2026-09-20', tamamlandi_tarihi: '2026-09-20' }, BUGUN_ISO, false), 'tamam');
  // tamamlandi_tarihi dolu + gün BUGÜN → tamam (gelecek değil)
  assert.equal(ctx._ovsyncGunDurumu({ tarih: BUGUN_ISO, tamamlandi_tarihi: BUGUN_ISO }, BUGUN_ISO, false), 'tamam');
  // tamamlandi_tarihi dolu + gün bugünden İLERİDE → tutarsiz (§7.3; 'uygulanmadi' yazılmaz)
  assert.equal(ctx._ovsyncGunDurumu({ tarih: '2026-10-04', tamamlandi_tarihi: '2026-10-04' }, BUGUN_ISO, false), 'tutarsiz');
});

test('GUN-DURUMU: fallback matrisi — planli / gecikti / uygulanmadi', () => {
  const { ctx } = ovsyncCtx();
  assert.equal(ctx._ovsyncGunDurumu({ tarih: BUGUN_ISO }, BUGUN_ISO, false), 'planli');
  assert.equal(ctx._ovsyncGunDurumu({ tarih: '2026-10-01' }, BUGUN_ISO, false), 'planli');
  assert.equal(ctx._ovsyncGunDurumu({ tarih: '2026-09-29' }, BUGUN_ISO, false), 'gecikti');
  // vaka kapalı + gün açık kalmış → uygulanmadi
  assert.equal(ctx._ovsyncGunDurumu({ tarih: '2026-10-01' }, BUGUN_ISO, true), 'uygulanmadi');
  assert.equal(ctx._ovsyncGunDurumu({ tarih: '2026-09-29' }, BUGUN_ISO, true), 'uygulanmadi');
});

test('GUN-DURUMU: bilinmiyor yolları — gün yok / tarih yok / tamamlandi_tarihi tarihsiz (§7.8)', () => {
  const { ctx } = ovsyncCtx();
  assert.equal(ctx._ovsyncGunDurumu(null, BUGUN_ISO, false), 'bilinmiyor');
  assert.equal(ctx._ovsyncGunDurumu(undefined, BUGUN_ISO, false), 'bilinmiyor');
  assert.equal(ctx._ovsyncGunDurumu({ durum: 'planli' }, BUGUN_ISO, false), 'bilinmiyor',
    'durum alanı da tarih de yoksa tahmin YASAK');
  assert.equal(ctx._ovsyncGunDurumu({}, BUGUN_ISO, false), 'bilinmiyor');
});

// ══ 2. _ovsyncGunSinif CSS eşlemesi (R12 renk kuralları) ══════════════════

test('GUN-SINIF: 5 durum ayrı sınıf + bilinmiyor; tanınmayan durum bilinmiyor sınıfına düşer', () => {
  const { ctx } = ovsyncCtx();
  assert.equal(ctx._ovsyncGunSinif('tamam'), 'ovs-g-tamam');       // yeşil
  assert.equal(ctx._ovsyncGunSinif('planli'), 'ovs-g-plan');       // amber
  assert.equal(ctx._ovsyncGunSinif('gecikti'), 'ovs-g-gecikti');   // kırmızı
  assert.equal(ctx._ovsyncGunSinif('uygulanmadi'), 'ovs-g-soluk'); // soluk
  assert.equal(ctx._ovsyncGunSinif('tutarsiz'), 'ovs-g-tutarsiz'); // ⚠
  assert.equal(ctx._ovsyncGunSinif('bilinmiyor'), 'ovs-g-bilinmiyor');
  assert.equal(ctx._ovsyncGunSinif('SAMANYOLU'), 'ovs-g-bilinmiyor', '§7.8: tanınmayan → bilinmiyor');
  assert.equal(ctx._ovsyncGunSinif(null), 'ovs-g-bilinmiyor');
});

// ══ 3. KPA sınıf kuralı (P7 _dashStatRow bunu bağlar) ═════════════════════

test('KPA-SINIF: S0>0 ya da muayene vakti>0 → alert', () => {
  const { ctx } = ovsyncCtx();
  const kpa = { aktif: 13, bugun: 1, geciken: 0, muayene_bekleyen: 10, bekleyen_baslatma: 31 };
  assert.deepEqual(ctx._ovsyncStatSinif(kpa, 0, true), { sinif: 'alert', soru: false });
  assert.deepEqual(ctx._ovsyncStatSinif({ ...kpa, bugun: 0 }, 2, true), { sinif: 'alert', soru: false },
    'muayene vakti dolan (kalan_gun<=0) tek başına alert');
  assert.deepEqual(ctx._ovsyncStatSinif({ ...kpa, bugun: 0, geciken: 3 }, 0, true), { sinif: 'alert', soru: false });
});

test('KPA-SINIF: yalnız bekleyen-baslatma>0 → warn; sakin → ok', () => {
  const { ctx } = ovsyncCtx();
  const kpa = { aktif: 13, bugun: 0, geciken: 0, muayene_bekleyen: 10, bekleyen_baslatma: 31 };
  assert.deepEqual(ctx._ovsyncStatSinif(kpa, 0, true), { sinif: 'warn', soru: false });
  const sakin = { aktif: 0, bugun: 0, geciken: 0, muayene_bekleyen: 0, bekleyen_baslatma: 0 };
  assert.deepEqual(ctx._ovsyncStatSinif(sakin, 0, true), { sinif: 'ok', soru: false });
});

test('KPA-SINIF: bayat/hata → warn + soru işareti (§7.8 sessiz varsayılan yok)', () => {
  const { ctx } = ovsyncCtx();
  assert.deepEqual(ctx._ovsyncStatSinif(null, 0, false), { sinif: 'warn', soru: true });
  assert.deepEqual(ctx._ovsyncStatSinif(undefined, 0, false), { sinif: 'warn', soru: true });
  // taze ama kpa alanı okunamıyor → bilinmiyor sayılır + soru
  assert.deepEqual(ctx._ovsyncStatSinif({}, 0, true), { sinif: 'warn', soru: true });
});

// ══ 4. KPA şeridi HTML ════════════════════════════════════════════════════

test('KPA-HTML: 5 hücre etiketleri birebir', () => {
  const { ctx } = ovsyncCtx();
  const kpa = { aktif: 13, bugun: 1, geciken: 0, muayene_bekleyen: 10, bekleyen_baslatma: 31, bekleyen_baslatma_takipte: 1 };
  const h = ctx._ovsyncKpaHtml(kpa);
  assert.match(h, /aktif/);
  assert.match(h, /bugün/);
  assert.match(h, /geciken/);
  assert.match(h, /muayene bekleyen/);
  assert.match(h, /bekleyen başlatma/);
  assert.match(h, />13</);
  assert.match(h, />1</);
  assert.match(h, />10</);
  assert.match(h, />31</);
});

test('KPA-HTML: (N takipte) alt metni — bekleyen_baslatma_takipte>0 (§10c #8)', () => {
  const { ctx } = ovsyncCtx();
  const kpa = { aktif: 0, bugun: 0, geciken: 0, muayene_bekleyen: 0, bekleyen_baslatma: 31, bekleyen_baslatma_takipte: 2 };
  const h = ctx._ovsyncKpaHtml(kpa);
  assert.match(h, /\(2 takipte\)/);
  const kpa0 = { ...kpa, bekleyen_baslatma_takipte: 0 };
  assert.doesNotMatch(ctx._ovsyncKpaHtml(kpa0), /takipte/, 'takipte 0 ise alt metin çizilmez');
});

test('KPA-HTML: eksik kpa alanı → "bilinmiyor" hücresi (§7.8 sessiz varsayılan yok)', () => {
  const { ctx } = ovsyncCtx();
  const h = ctx._ovsyncKpaHtml({ aktif: 3 });
  assert.match(h, /bilinmiyor/);
  const h2 = ctx._ovsyncKpaHtml(null);
  assert.match(h2, /bilinmiyor/);
});

// ══ 5. Rozetler ═══════════════════════════════════════════════════════════

test('DENEME-ROZETI: 2+ → "N. deneme — önceki boş" (§18.14 son doğumdan); 1/0/null → boş', () => {
  const { ctx } = ovsyncCtx();
  assert.match(ctx._ovsyncDenemeRozeti(2), /2\. deneme — önceki boş/);
  assert.match(ctx._ovsyncDenemeRozeti(5), /5\. deneme — önceki boş/);
  assert.equal(ctx._ovsyncDenemeRozeti(1), '');
  assert.equal(ctx._ovsyncDenemeRozeti(0), '');
  assert.equal(ctx._ovsyncDenemeRozeti(null), '');
});

test('SAPMA-ROZETI: kayma +Ng / erken Ng / görevsiz; boş sapma → boş', () => {
  const { ctx } = ovsyncCtx();
  assert.match(ctx._ovsyncSapmaRozeti({ hedef_baslangic: '2026-09-24', kayma_gun: 3 }), /\+3g/);
  assert.match(ctx._ovsyncSapmaRozeti({ hedef_baslangic: '2026-09-24', kayma_gun: 3 }), /24\.09/); // GG.AA (fmtTarih dili)
  assert.match(ctx._ovsyncSapmaRozeti({ hedef_baslangic: '2026-09-24', kayma_gun: -6 }), /erken 6g/);
  assert.match(ctx._ovsyncSapmaRozeti({ hedef_baslangic: null, kayma_gun: null, gorevsiz_tai: true }), /görevsiz/);
  assert.equal(ctx._ovsyncSapmaRozeti({ kayma_gun: null, gorevsiz_tai: false, erken_tai: false }), '');
  assert.equal(ctx._ovsyncSapmaRozeti(null), '');
});

test('TAKIPTE-ROZETI: "🔍 takipte · muayene GG.AA SS:DD" (mockup 06); saatsiz → tarih; null → boş', () => {
  const { ctx } = ovsyncCtx();
  const h = ctx._ovsyncTakipteRozeti({ gorev_id: 'g1', hedef_tarih: '2026-10-05', hedef_saat: '14:35:00' });
  assert.match(h, /takipte/);
  assert.match(h, /05\.10/);
  assert.match(h, /14:35/);
  const hs = ctx._ovsyncTakipteRozeti({ gorev_id: 'g1', hedef_tarih: '2026-10-05', hedef_saat: null });
  assert.match(hs, /05\.10/);
  assert.doesNotMatch(hs, /:/, 'saatsiz takipte saat göstermez');
  assert.equal(ctx._ovsyncTakipteRozeti(null), '');
});

test('MUAYENE-HTML: sayaç "muayeneye N gün (GG.AA)"; vakti dolan → "muayene vakti · +Ng"; okunamıyor → bilinmiyor', () => {
  const { ctx } = ovsyncCtx();
  assert.match(ctx._ovsyncMuayeneHtml({ tai_tarihi: '2026-09-23', muayene_tarihi: '2026-11-02', kalan_gun: 35 }), /muayeneye 35 gün/);
  assert.match(ctx._ovsyncMuayeneHtml({ tai_tarihi: '2026-09-23', muayene_tarihi: '2026-11-02', kalan_gun: 35 }), /02\.11/);
  assert.match(ctx._ovsyncMuayeneHtml({ tai_tarihi: '2026-08-15', muayene_tarihi: '2026-09-24', kalan_gun: 0 }), /muayene vakti/);
  assert.match(ctx._ovsyncMuayeneHtml({ tai_tarihi: '2026-08-15', muayene_tarihi: '2026-09-26', kalan_gun: -4 }), /muayene vakti/);
  assert.match(ctx._ovsyncMuayeneHtml({ tai_tarihi: '2026-08-15', muayene_tarihi: '2026-09-26', kalan_gun: -4 }), /\+4g/);
  assert.match(ctx._ovsyncMuayeneHtml(null), /bilinmiyor/, '§7.8: muayene verisi okunamıyorsa sessiz sayaç YOK');
  assert.match(ctx._ovsyncMuayeneHtml({ tai_tarihi: '2026-08-15' }), /bilinmiyor/, 'kalan_gun eksik → bilinmiyor');
});

test('SONLANMA-ROZETI: toh_sonuc + close_reason eşlemesi; tanınmayan → bilinmiyor (§7.4/§7.5/§7.8)', () => {
  const { ctx } = ovsyncCtx();
  assert.match(ctx._ovsyncSonlanmaRozeti('TOHUMLAMA', 'Gebe'), /Gebe/);
  assert.match(ctx._ovsyncSonlanmaRozeti('TOHUMLAMA', 'Boş'), /Boş/);
  assert.match(ctx._ovsyncSonlanmaRozeti('TOHUMLAMA', 'bilinmiyor'), /bilinmiyor/);
  assert.match(ctx._ovsyncSonlanmaRozeti('PG', null), /PG/);
  assert.match(ctx._ovsyncSonlanmaRozeti('IPTAL', null), /İptal/);
  assert.match(ctx._ovsyncSonlanmaRozeti('ERKEN_KAPANIS', null), /Erken kapanış/);
  assert.match(ctx._ovsyncSonlanmaRozeti('ESKI', null), /Eski/);
  // NULL close_reason → 'ESKI' (§7.4)
  assert.match(ctx._ovsyncSonlanmaRozeti(null, null), /Eski/);
  // tanınmayan enum → bilinmiyor (tahmin yok)
  assert.match(ctx._ovsyncSonlanmaRozeti('SAMANYOLU', null), /bilinmiyor/);
  assert.match(ctx._ovsyncSonlanmaRozeti('TOHUMLAMA', 'SAMANYOLU'), /bilinmiyor/);
});

// ══ 6. Gün şeridi + S0 tip türetme ════════════════════════════════════════

test('GUNLER-HTML: etiketler "1./2./3./4. uygulama" (A10: ilaç adlı etiket YASAK) + TAI hücresi', () => {
  const { ctx } = ovsyncCtx();
  const satir = {
    gunler: [
      { gun_no: 0, tarih: '2026-09-23', planned_time: null, durum: 'tamam' },
      { gun_no: 7, tarih: '2026-10-04', planned_time: '19:00:00', durum: 'planli' },
    ],
    tai: { gorev_id: 't1', hedef_tarih: '2026-10-06', hedef_saat: '19:00:00', durum: 'planli', kaynak: 'sablon' },
  };
  const h = ctx._ovsyncGunlerHtml(satir, BUGUN_ISO);
  assert.match(h, /1\. uygulama/);
  assert.match(h, /2\. uygulama/);
  assert.match(h, /TAI/);
  assert.match(h, /ovs-g-tamam/);
  assert.match(h, /ovs-g-plan/);
  assert.doesNotMatch(h, /PGs|Estradiol|PG2|dinoprost/i, 'A10: ilaç adlı gün etiketi çıkmaz');
  // sıra numarası gun_no'dan değil ŞERİT SIRASINDAN: 0. gün "1. uygulama"
});

test('GUNLER-HTML: TAI bugünse BUGÜN etiketi + kırmızı vurgu; RPC tutarsız gün ⚠ sınıfı taşır', () => {
  const { ctx } = ovsyncCtx();
  const bugunki = ctx._ovsyncGunlerHtml({
    gunler: [],
    tai: { gorev_id: 't1', hedef_tarih: BUGUN_ISO, hedef_saat: '19:00:00', durum: 'planli', kaynak: 'pg' },
  }, BUGUN_ISO);
  assert.match(bugunki, /BUGÜN/);
  assert.match(bugunki, /ovs-g-bugun/);
  const tutarsiz = ctx._ovsyncGunlerHtml({
    gunler: [{ gun_no: 7, tarih: '2026-10-04', planned_time: null, durum: 'tutarsiz' }],
    tai: null,
  }, BUGUN_ISO);
  assert.match(tutarsiz, /ovs-g-tutarsiz/);
  assert.match(tutarsiz, /⚠/);
});

test('S0-TIP: gecikme>0 ya da TAI gecikti → geciken; değilse bugun (RPC bolum CASE aynası)', () => {
  const { ctx } = ovsyncCtx();
  assert.equal(ctx._ovsyncS0Tip({ gecikme_gun: 3, tai: null }), 'geciken');
  assert.equal(ctx._ovsyncS0Tip({ gecikme_gun: 0, tai: { durum: 'gecikti' } }), 'geciken');
  assert.equal(ctx._ovsyncS0Tip({ gecikme_gun: 0, tai: { durum: 'planli' } }), 'bugun');
  assert.equal(ctx._ovsyncS0Tip({ gecikme_gun: 0, tai: null }), 'bugun');
});

// ══ 7. Satır HTML (S1/S0/S2/S3/S4) + motor bağları ════════════════════════

const BAGLAM_DOLU = {
  baslat: new Map([['h1', { id: 'g-baslat', hayvan_id: 'h1', gorev_tipi: 'OVSYNC_BASLAT', hedef_tarih: BUGUN_ISO }]]),
  vakaAktif: new Map([['h1', { id: 'c1', status: 'active' }]]),
  vakaKapali: new Map([['h1', { id: 'c9', status: 'closed' }]]),
  kisir: new Set(),
};

test('S1-SATIR: kupe/grup/taban etiketleri + gün şeridi + "Gün detayı" openCaseDet motoru', () => {
  const { ctx, cagri } = ovsyncCtx({ window: { _curOvsyncBolum: { acik: {} }, _ovsyncBaglam: BAGLAM_DOLU } });
  const satir = {
    bolum: 'S1', dalga_anahtari: '2026-09-24', hayvan_id: 'h1', kupe_no: '168',
    grup: 'Sağmal', padok: 'Sağmal Padok', taban_turu: 'dogum',
    gunler: [{ gun_no: 0, tarih: '2026-09-27', planned_time: null, durum: 'tamam' }],
    tai: { gorev_id: 't9', hedef_tarih: '2026-10-07', hedef_saat: null, durum: 'planli', kaynak: 'sablon' },
    sonraki_gun: 7, gecikme_gun: 0,
    sapma: { hedef_baslangic: '2026-09-24', fiili_baslangic: '2026-09-27', kayma_gun: 3, erken_tai: false, gorevsiz_tai: false },
    close_reason: null, toh_sonuc: null, deneme_sayisi: 1, muayene: null, takip: null, muayene_gorev_id: null,
  };
  const h = ctx._ovsyncSatirHtml(satir, BUGUN_ISO);
  assert.match(h, /168/);
  assert.match(h, /Sağmal/);
  assert.match(h, /Doğum\+51/, 'taban_turu=dogum → Doğum+51 etiketi');
  assert.match(h, /\+3g/, 'sapma rozeti');
  assert.match(h, /1\/1 uygulandı/, 'alt bilgi tamam sayacı');
  assert.match(h, /openCaseDet\('c1'\)/, 'gün aksiyonu MEVCUT openCaseDet motoruna bağlı');
  // gerçek buton tıklaması motoru çözer (onclick string'i ctx adıyla aynı)
  assert.match(h, /openTaskDet\('t9'\)/, 'TAI aksiyonu MEVCUT openTaskDet motoruna bağlı');
});

test('S1-SATIR: vaka eşlemesi yoksa aksiyon yerine "bilinmiyor" (§7.8 — sessiz buton yok)', () => {
  const { ctx } = ovsyncCtx({ window: { _curOvsyncBolum: { acik: {} }, _ovsyncBaglam: { baslat: new Map(), vakaAktif: new Map(), vakaKapali: new Map(), kisir: new Set() } } });
  const satir = {
    bolum: 'S1', dalga_anahtari: '2026-09-24', hayvan_id: 'hx', kupe_no: '168',
    grup: 'Sağmal', padok: '', taban_turu: 'dogum',
    gunler: [{ gun_no: 0, tarih: '2026-09-27', planned_time: null, durum: 'tamam' }],
    tai: null, sonraki_gun: null, gecikme_gun: 0,
    sapma: { hedef_baslangic: null, fiili_baslangic: '2026-09-27', kayma_gun: null, erken_tai: false, gorevsiz_tai: false },
    close_reason: null, toh_sonuc: null, deneme_sayisi: 0, muayene: null, takip: null, muayene_gorev_id: null,
  };
  const h = ctx._ovsyncSatirHtml(satir, BUGUN_ISO);
  assert.match(h, /bilinmiyor/, 'vaka bağlantısı çözülemeyen satır dürüst "bilinmiyor" gösterir');
  assert.doesNotMatch(h, /openCaseDet\(/, 'eşleşmeyen aksiyon kurgulanmaz');
});

test('S1-SATIR: taban_turu tanınmayan → "bilinmiyor" etiketi', () => {
  const { ctx } = ovsyncCtx({ window: { _curOvsyncBolum: { acik: {} }, _ovsyncBaglam: BAGLAM_DOLU } });
  const satir = {
    bolum: 'S1', dalga_anahtari: '2026-09-24', hayvan_id: 'h1', kupe_no: '168',
    grup: 'Sağmal', padok: '', taban_turu: 'SAMANYOLU',
    gunler: [], tai: null, sonraki_gun: null, gecikme_gun: 0,
    sapma: { hedef_baslangic: null, fiili_baslangic: null, kayma_gun: null, erken_tai: false, gorevsiz_tai: false },
    close_reason: null, toh_sonuc: null, deneme_sayisi: 0, muayene: null, takip: null, muayene_gorev_id: null,
  };
  const h = ctx._ovsyncSatirHtml(satir, BUGUN_ISO);
  assert.match(h, /bilinmiyor/);
});

test('S0-KART: BUGÜN kartı kırmızı vurgu + TAI kaydet openTaskDet; geciken kartı +Ng', () => {
  const { ctx } = ovsyncCtx({ window: { _curOvsyncBolum: { acik: {} }, _ovsyncBaglam: BAGLAM_DOLU } });
  const bugun = {
    bolum: 'S0', dalga_anahtari: '2026-09-18', hayvan_id: 'h1', kupe_no: '002',
    grup: 'Sağmal', padok: '', taban_turu: 'dogum',
    gunler: [
      { gun_no: 0, tarih: '2026-09-18', planned_time: null, durum: 'tamam' },
      { gun_no: 9, tarih: '2026-09-27', planned_time: null, durum: 'tamam' },
    ],
    tai: { gorev_id: 't1', hedef_tarih: BUGUN_ISO, hedef_saat: '19:00:00', durum: 'planli', kaynak: 'pg' },
    sonraki_gun: null, gecikme_gun: 0,
    sapma: { hedef_baslangic: null, fiili_baslangic: '2026-09-18', kayma_gun: null, erken_tai: false, gorevsiz_tai: true },
    close_reason: null, toh_sonuc: null, deneme_sayisi: 1, muayene: null, takip: null, muayene_gorev_id: null,
  };
  const h = ctx._ovsyncSatirHtml(bugun, BUGUN_ISO);
  assert.match(h, /BUGÜN/);
  assert.match(h, /ovs-bugun-kart/);
  assert.match(h, /openTaskDet\('t1'\)/);
  assert.match(h, /19:00/, 'TAI saat gösterimi (mockup: TAI bugün 19:00)');

  const geciken = { ...bugun, kupe_no: '045', gecikme_gun: 2, tai: { gorev_id: 't2', hedef_tarih: '2026-09-28', hedef_saat: null, durum: 'gecikti', kaynak: 'pg' } };
  const hg = ctx._ovsyncSatirHtml(geciken, BUGUN_ISO);
  assert.match(hg, /\+2g/);
  assert.doesNotMatch(hg, /ovs-bugun-kart/);
});

test('S2-SATIR: sayaç; vakti dolan → rozet + aksiyon köprüsü (muayene_gorev_id taşınır); deneme rozeti', () => {
  const { ctx } = ovsyncCtx({ window: { _curOvsyncBolum: { acik: {} }, _ovsyncBaglam: BAGLAM_DOLU } });
  const sayac = {
    bolum: 'S2', dalga_anahtari: null, hayvan_id: 'h2', kupe_no: '119',
    grup: 'Sağmal', padok: '', taban_turu: 'dogum', gunler: [], tai: null,
    sonraki_gun: null, gecikme_gun: 0,
    sapma: { hedef_baslangic: null, fiili_baslangic: null, kayma_gun: null, erken_tai: false, gorevsiz_tai: false },
    close_reason: null, toh_sonuc: 'Bekliyor', deneme_sayisi: 2,
    muayene: { tai_tarihi: '2026-09-23', muayene_tarihi: '2026-11-02', kalan_gun: 33 },
    takip: null, muayene_gorev_id: 'mg1',
  };
  const h = ctx._ovsyncSatirHtml(sayac, BUGUN_ISO);
  assert.match(h, /muayeneye 33 gün/);
  assert.match(h, /2\. deneme — önceki boş/);
  assert.doesNotMatch(h, /_ovsyncMuayeneSatirAc\(/, 'kalan_gun>0 → aksiyon YOK (yalnız bilgi satırı)');

  const vakti = { ...sayac, kupe_no: '136', muayene: { tai_tarihi: '2026-08-15', muayene_tarihi: '2026-09-24', kalan_gun: -6 } };
  const hv = ctx._ovsyncSatirHtml(vakti, BUGUN_ISO);
  assert.match(hv, /muayene vakti/);
  assert.match(hv, /_ovsyncMuayeneSatirAc\('h2','mg1'\)/, 'vakti dolan satır P9 _muayeneSonucAc çağrı noktasına bağlı');
});

test('S2-SATIR: muayene_gorev_id NULL → köprü hayvan detayına düşer (§10d #2 KARAR)', () => {
  const { ctx, cagri } = ovsyncCtx({ window: { _curOvsyncBolum: { acik: {} }, _ovsyncBaglam: BAGLAM_DOLU } });
  const vaktiGorevsiz = {
    bolum: 'S2', dalga_anahtari: null, hayvan_id: 'h3', kupe_no: '136',
    grup: 'Sağmal', padok: '', taban_turu: 'dogum', gunler: [], tai: null,
    sonraki_gun: null, gecikme_gun: 0,
    sapma: { hedef_baslangic: null, fiili_baslangic: null, kayma_gun: null, erken_tai: false, gorevsiz_tai: false },
    close_reason: null, toh_sonuc: 'Bekliyor', deneme_sayisi: 1,
    muayene: { tai_tarihi: '2026-08-15', muayene_tarihi: '2026-09-24', kalan_gun: -6 },
    takip: null, muayene_gorev_id: null,
  };
  const h = ctx._ovsyncSatirHtml(vaktiGorevsiz, BUGUN_ISO);
  assert.match(h, /_ovsyncMuayeneSatirAc\('h3',''\)/);
  // köprü davranışı: gorev boş → openDet(hayvan)
  ctx._ovsyncMuayeneSatirAc('h3', '');
  assert.deepEqual(cagri.openDet, ['h3']);
  assert.deepEqual(cagri.muayene, []);
  // köprü davranışı: gorev dolu → P9 fonksiyonu
  ctx._ovsyncMuayeneSatirAc('h2', 'mg9');
  assert.deepEqual(cagri.muayene, ['mg9']);
});

test('S3-SATIR: pencere içinde ▶ Başlat (gerçek _ovsyncBaslatKilitHtml gövdesi); görevsiz → otomatik açılır notu', () => {
  const { ctx, cagri } = ovsyncCtx({ window: { _curOvsyncBolum: { acik: {} }, _ovsyncBaglam: BAGLAM_DOLU } });
  const gorevli = {
    bolum: 'S3', dalga_anahtari: BUGUN_ISO, hayvan_id: 'h1', kupe_no: '058',
    grup: 'Düve (Büyük)', padok: '', taban_turu: 'duve', gunler: [], tai: null,
    sonraki_gun: null, gecikme_gun: 0,
    sapma: { hedef_baslangic: BUGUN_ISO, fiili_baslangic: null, kayma_gun: null, erken_tai: false, gorevsiz_tai: false },
    close_reason: null, toh_sonuc: null, deneme_sayisi: 0, muayene: null, takip: null, muayene_gorev_id: null,
  };
  const h = ctx._ovsyncSatirHtml(gorevli, BUGUN_ISO);
  assert.match(h, /▶ Başlat/, 'pencere içinde (hedef=bugün) Başlat butonu çizilir');
  // gerçek _ovsyncBaslatKilitHtml gövdesi dataset deseniyle bağlar (K4 — değiştirilmez):
  assert.match(h, /data-g="g-baslat"/, 'Başlat MEVCUT _ovsyncBaslatKilitHtml motorundan çıktı (data-g görev id)');
  assert.match(h, /data-h="h1"/, 'hayvan id data-h ile taşınır');
  assert.match(h, /ovsyncBaslat\(this\.dataset\.g,this\.dataset\.h\)/, 'Başlat MEVCUT ovsyncBaslat motoruna bağlı');
  assert.match(h, /🗓️ Ertele/, '_erteleBtnHtml gerçek gövdesi kural stub ile buton üretir');

  const pencereDisi = { ...gorevli, kupe_no: '045', dalga_anahtari: '2026-11-14' };
  const hd = ctx._ovsyncSatirHtml(pencereDisi, BUGUN_ISO);
  assert.match(hd, /sonra başlatılabilir/, 'pencere dışı → kilit metni (K4)');
  assert.doesNotMatch(hd, /▶ Başlat/);

  const gorevsiz = { ...gorevli, hayvan_id: 'h9', kupe_no: '077', dalga_anahtari: BUGUN_ISO };
  const hg = ctx._ovsyncSatirHtml(gorevsiz, BUGUN_ISO);
  assert.match(hg, /otomatik açılır/, '§18.2: görevsiz satır görevin kural günü doğacağını söyler');
  assert.doesNotMatch(hg, /▶ Başlat/, 'görevsiz satırdan Başlat kurgulanmaz');
});

test('S3-TAKIP: dalga NULL + takip dolu → mor vurgulu takip satırı + rozet (mockup 06)', () => {
  const { ctx } = ovsyncCtx({ window: { _curOvsyncBolum: { acik: {} }, _ovsyncBaglam: BAGLAM_DOLU } });
  const satir = {
    bolum: 'S3', dalga_anahtari: null, hayvan_id: 'h7', kupe_no: '197',
    grup: 'Sağmal', padok: '', taban_turu: 'dogum', gunler: [], tai: null,
    sonraki_gun: null, gecikme_gun: 0,
    sapma: { hedef_baslangic: null, fiili_baslangic: null, kayma_gun: null, erken_tai: false, gorevsiz_tai: false },
    close_reason: null, toh_sonuc: null, deneme_sayisi: 1,
    muayene: null, takip: { gorev_id: 'tk1', hedef_tarih: '2026-10-05', hedef_saat: '14:35:00' }, muayene_gorev_id: null,
  };
  const h = ctx._ovsyncSatirHtml(satir, BUGUN_ISO);
  assert.match(h, /ovs-takip-satir/);
  assert.match(h, /takipte/);
  assert.match(h, /05\.10 14:35/);
  assert.doesNotMatch(h, /▶ Başlat/);
});

test('S4-SATIR: sonlanma rozeti + toh_sonuc; vaka eşlemesi openCaseDet salt-okuma', () => {
  const { ctx } = ovsyncCtx({ window: { _curOvsyncBolum: { acik: {} }, _ovsyncBaglam: BAGLAM_DOLU } });
  const satir = {
    bolum: 'S4', dalga_anahtari: null, hayvan_id: 'h1', kupe_no: '183',
    grup: 'Sağmal', padok: '', taban_turu: 'dogum', gunler: [], tai: null,
    sonraki_gun: null, gecikme_gun: 0,
    sapma: { hedef_baslangic: null, fiili_baslangic: null, kayma_gun: null, erken_tai: false, gorevsiz_tai: false },
    close_reason: 'TOHUMLAMA', toh_sonuc: 'Gebe', deneme_sayisi: 1, muayene: null, takip: null, muayene_gorev_id: null,
  };
  const h = ctx._ovsyncSatirHtml(satir, BUGUN_ISO);
  assert.match(h, /Gebe/);
  assert.match(h, /openCaseDet\('c9'\)/, 'S4 salt-okuma vaka detayı');
  const bilinmeyen = { ...satir, close_reason: 'SAMANYOLU', toh_sonuc: 'SAMANYOLU' };
  assert.match(ctx._ovsyncSatirHtml(bilinmeyen, BUGUN_ISO), /bilinmiyor/);
});

// ══ 8. Bölüm + sayfa ══════════════════════════════════════════════════════

const satirS1 = h => ({
  bolum: 'S1', dalga_anahtari: h.dalga || '2026-09-24', hayvan_id: h.id, kupe_no: h.kupe,
  grup: 'Sağmal', padok: '', taban_turu: 'dogum',
  gunler: [{ gun_no: 0, tarih: '2026-09-27', planned_time: null, durum: 'tamam' }],
  tai: null, sonraki_gun: null, gecikme_gun: 0,
  sapma: { hedef_baslangic: null, fiili_baslangic: h.fiil || null, kayma_gun: h.kayma || null, erken_tai: false, gorevsiz_tai: false },
  close_reason: null, toh_sonuc: null, deneme_sayisi: 0, muayene: null, takip: null, muayene_gorev_id: null,
});

test('BOLUM-HTML: boş satır listesi → boş string (bölüm gizli); dolu → başlık + içerik', () => {
  const { ctx } = ovsyncCtx({ window: { _curOvsyncBolum: { acik: {} }, _ovsyncBaglam: BAGLAM_DOLU } });
  assert.equal(ctx._ovsyncBolumHtml('S0', []), '');
  assert.equal(ctx._ovsyncBolumHtml('S0', null), '');
  const h = ctx._ovsyncBolumHtml('S1', [satirS1({ id: 'h1', kupe: '168' })]);
  assert.match(h, /S1/);
  assert.match(h, /168/);
});

test('SAYFA: boş S0 gizli — dolu S0 çizilir; KPA şeridi her zaman var', () => {
  const { ctx } = ovsyncCtx({ window: { _curOvsyncBolum: { acik: {} }, _ovsyncBaglam: BAGLAM_DOLU } });
  const veri = {
    ok: true, bayrak_kapali: false,
    kpa: { aktif: 1, bugun: 0, geciken: 0, muayene_bekleyen: 0, bekleyen_baslatma: 0, bekleyen_baslatma_takipte: 0 },
    esikler: { muayene_gun: 40, pencere_gun: 2 },
    satirlar: [satirS1({ id: 'h1', kupe: '168' })],
  };
  const h = ctx.renderOvsyncSayfa(veri, BUGUN_ISO);
  assert.match(h, /ovs-kpa/);
  assert.doesNotMatch(h, /S0/, 'S0 boşken bölüm başlığı dahil hiçbir iz kalmaz');
  assert.match(h, /S1/);
});

test('SAYFA: S3 ilk 5 + "tümü (M)"; açılınca hepsi; S4 katlanır kapalıyken kartlar çıkmaz', () => {
  const satirlar = [];
  for (let i = 1; i <= 8; i++) {
    satirlar.push({
      bolum: 'S3', dalga_anahtari: '2026-10-1' + (i % 10), hayvan_id: 'h' + i, kupe_no: String(100 + i),
      grup: 'Sağmal', padok: '', taban_turu: 'duve', gunler: [], tai: null,
      sonraki_gun: null, gecikme_gun: 0,
      sapma: { hedef_baslangic: null, fiili_baslangic: null, kayma_gun: null, erken_tai: false, gorevsiz_tai: false },
      close_reason: null, toh_sonuc: null, deneme_sayisi: 0, muayene: null, takip: null, muayene_gorev_id: null,
    });
  }
  const veri = {
    ok: true, bayrak_kapali: false,
    kpa: { aktif: 0, bugun: 0, geciken: 0, muayene_bekleyen: 0, bekleyen_baslatma: 8, bekleyen_baslatma_takipte: 1 },
    esikler: { muayene_gun: 40, pencere_gun: 2 },
    satirlar,
  };
  const { ctx } = ovsyncCtx({ window: { _curOvsyncBolum: { acik: {} }, _ovsyncBaglam: BAGLAM_DOLU } });
  const h = ctx.renderOvsyncSayfa(veri, BUGUN_ISO);
  const say = (h.match(/ovs-s3-satir/g) || []).length;
  assert.equal(say, 5, 'S3 kapalıyken ilk 5 satır');
  assert.match(h, /tümü \(8\)/, '"tümü (M)" sayısıyla');

  const { ctx: ctx2 } = ovsyncCtx({ window: { _curOvsyncBolum: { acik: { S3Tumu: true } }, _ovsyncBaglam: BAGLAM_DOLU } });
  const h2 = ctx2.renderOvsyncSayfa(veri, BUGUN_ISO);
  assert.equal((h2.match(/ovs-s3-satir/g) || []).length, 8, 'S3Tumu açıkken 8 satırın hepsi');

  const s4Satirlar = [{ ...satirlar[0], bolum: 'S4', close_reason: 'TOHUMLAMA', toh_sonuc: 'Gebe', dalga_anahtari: null, hayvan_id: 'h1', kupe_no: '183' }, ...satirlar];
  const veri4 = { ...veri, satirlar: s4Satirlar };
  const h4 = ctx.renderOvsyncSayfa(veri4, BUGUN_ISO);
  assert.match(h4, /S4/, 'S4 başlığı katlıyken de görünür');
  assert.doesNotMatch(h4, /ovs-s4-kart/, 'S4 kapalıyken kart çıkmaz (katlanır varsayılan kapalı)');
  const { ctx: ctx3 } = ovsyncCtx({ window: { _curOvsyncBolum: { acik: { S4: true } }, _ovsyncBaglam: BAGLAM_DOLU } });
  const h5 = ctx3.renderOvsyncSayfa(veri4, BUGUN_ISO);
  assert.match(h5, /ovs-s4-kart/, 'S4 açıkken kartlar çizilir');
});

test('SAYFA: dalga gruplama — aynı dalga_anahtari 2+ hayvan grup kartında; tekil "Tekil başlangıçlar"da', () => {
  const { ctx } = ovsyncCtx({ window: { _curOvsyncBolum: { acik: {} }, _ovsyncBaglam: BAGLAM_DOLU } });
  const veri = {
    ok: true, bayrak_kapali: false,
    kpa: { aktif: 3, bugun: 0, geciken: 0, muayene_bekleyen: 0, bekleyen_baslatma: 0, bekleyen_baslatma_takipte: 0 },
    esikler: { muayene_gun: 40, pencere_gun: 2 },
    satirlar: [
      satirS1({ id: 'h1', kupe: '168', dalga: '2026-09-24' }),
      satirS1({ id: 'h2', kupe: '122', dalga: '2026-09-24' }),
      satirS1({ id: 'h3', kupe: '032', dalga: '2026-09-27' }),
    ],
  };
  const h = ctx.renderOvsyncSayfa(veri, BUGUN_ISO);
  assert.match(h, /Dalga:/, 'grup başlığı');
  assert.match(h, /Tekil başlangıçlar/, 'tek hayvanlı dalga tekil gruba düşer');
  // dalga başlığında hayvan sayısı
  assert.match(h, /2 hayvan/);
});

test('SAYFA: tanınmayan bolum satırı sessizce DÜŞMEZ — "bilinmiyor" bölümünde görünür (§7.8)', () => {
  const { ctx } = ovsyncCtx({ window: { _curOvsyncBolum: { acik: {} }, _ovsyncBaglam: BAGLAM_DOLU } });
  const veri = {
    ok: true, bayrak_kapali: false,
    kpa: { aktif: 0, bugun: 0, geciken: 0, muayene_bekleyen: 0, bekleyen_baslatma: 0, bekleyen_baslatma_takipte: 0 },
    esikler: { muayene_gun: 40, pencere_gun: 2 },
    satirlar: [{ ...satirS1({ id: 'h1', kupe: '168' }), bolum: 'S9' }],
  };
  const h = ctx.renderOvsyncSayfa(veri, BUGUN_ISO);
  assert.match(h, /bilinmiyor/);
  assert.match(h, /168/, 'satır içeriği kaybolmaz');
});

test('SAYFA: bekleyen_baslatma_takipte>0 iken KPA alt metni "(N takipte)" taşınır', () => {
  const { ctx } = ovsyncCtx({ window: { _curOvsyncBolum: { acik: {} }, _ovsyncBaglam: BAGLAM_DOLU } });
  const veri = {
    ok: true, bayrak_kapali: false,
    kpa: { aktif: 0, bugun: 0, geciken: 0, muayene_bekleyen: 0, bekleyen_baslatma: 31, bekleyen_baslatma_takipte: 4 },
    esikler: { muayene_gun: 40, pencere_gun: 2 },
    satirlar: [],
  };
  const h = ctx.renderOvsyncSayfa(veri, BUGUN_ISO);
  assert.match(h, /\(4 takipte\)/);
});

// ══ 9. IDB eşleme kurucusu ════════════════════════════════════════════════

test('BAGLAM-KUR: hayvan→açık OVSYNC_BASLAT + hayvan→aktif/kapalı OVSYNC vakası + kısır kümesi', () => {
  const { ctx } = ovsyncCtx();
  const gorevler = [
    { id: 'g1', hayvan_id: 'h1', gorev_tipi: 'OVSYNC_BASLAT', hedef_tarih: '2026-09-28', tamamlandi: false, iptal: false },
    { id: 'g2', hayvan_id: 'h1', gorev_tipi: 'OVSYNC_BASLAT', hedef_tarih: '2026-09-20', tamamlandi: true },
    { id: 'g3', hayvan_id: 'h2', gorev_tipi: 'OVSYNC_BASLAT', hedef_tarih: '2026-10-01', tamamlandi: false, iptal: true },
    { id: 'g4', hayvan_id: 'h3', gorev_tipi: 'GEBELIK_KONTROL', tamamlandi: false },
  ];
  const vakalar = [
    { id: 'c1', animal_id: 'h1', protocol_family: 'OVSYNC', status: 'active' },
    { id: 'c2', animal_id: 'h1', protocol_family: 'OVSYNC', status: 'closed', closed_at: '2026-09-01T10:00:00' },
    { id: 'c3', animal_id: 'h1', protocol_family: 'OVSYNC', status: 'closed', closed_at: '2026-09-20T10:00:00' },
    { id: 'c4', animal_id: 'h2', protocol_family: 'METRIT', status: 'active' },
  ];
  const hayvanlar = [{ id: 'h1', kisir: false }, { id: 'h2', kisir: true }];
  const b = ctx._ovsyncBaglamKur(gorevler, vakalar, hayvanlar);
  assert.equal(b.baslat.get('h1').id, 'g1', 'en güncel açık OVSYNC_BASLAT eşlenir');
  assert.equal(b.baslat.has('h2'), false, 'iptal görev eşlenmez');
  assert.equal(b.vakaAktif.get('h1').id, 'c1');
  assert.equal(b.vakaAktif.has('h2'), false, 'OVSYNC ailesi dışı vaka eşlenmez');
  assert.equal(b.vakaKapali.get('h1').id, 'c3', 'en son kapanan OVSYNC vakası');
  assert.ok(b.kisir.has('h2'));
});

// ══ 10. Eşik-sızıntısı + motor varlığı ════════════════════════════════════

test('ESIK-SIZINTISI: ovsync render kodunda 21/50/55 sabiti YOK (eşikler RPC esikler alanından)', () => {
  const kaynaklar = SAF_FNS.filter(n => n.startsWith('_ovsync') || n === 'renderOvsyncSayfa')
    .map(n => extractFunctionSource(UI, n));
  for (const k of kaynaklar) {
    assert.doesNotMatch(k, /\b21\b|\b50\b|\b55\b/, `eşik sabiti sızdı: ${k.slice(0, 80)}`);
  }
});

test('MOTOR-VARLIGI: render satırı mevcut motor adlarını onclick ile taşır (bağ kanıtı kaynakta)', () => {
  for (const motor of ['openTaskDet', 'openCaseDet', 'ovsyncBaslat', '_ovsyncBaslatKilitHtml', '_erteleBtnHtml', '_ovsyncMuayeneSatirAc']) {
    assert.ok(uiSrc.includes(motor), `ui.js'te motor adı geçmeli: ${motor}`);
  }
});
