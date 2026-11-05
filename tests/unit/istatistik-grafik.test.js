// tests/unit/istatistik-grafik.test.js — istatistik AP1 (T10): js/istatistik/grafik.js zarf → grafik.
// Test adları plan Task 10 Step 1 ile birebir (docs/plans/2026-10-17-istatistik-ap1-saglik-plan.md).
// Zarf fixture'ları demo stat_atolye_seri çıktısının gerçek şeklinden (2026-10-18, salt-okur):
//   kırılımsız/ilaç: tek seri, diziler grup sırasında; zaman: grup başına seri, diziler periyot sırasında.
// Gerçek Chart yüklenmez; grafikCiz için sahte Chart sınıfı. Saf fonksiyonlar Node'da (document yok) koşar.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const DOSYA = path.join(__dirname, '../../js/istatistik/grafik.js');
// grafik.js _cumleIlacEtiket'i tarayıcıdaki gibi cumle.js'ten alır (index.html sırası): gerçek dosya yüklenir, kopya yazılmaz.
vm.runInThisContext(fs.readFileSync(path.join(__dirname, '../../js/istatistik/cumle.js'), 'utf8'), { filename: 'cumle.js' });
const G = require(DOSYA);

const TEMA = { vurgu: '#0a0', kiyas: '#555', gri: '#999', metin: '#111', izgara: '#ddd', zemin: '#fff' };
const SAYAC = { acik_n: 3, olgunlasmamis_n: 1, vekil_n: 0, vekil_G: 6, fiyatsiz_n: 0, dislanan_ovsync_n: 0,
  bilinmiyor_n: 0, kapali_tarihsiz_n: 0, ilacsiz_n: 0, kiyas_n: 22 };
const kopya = o => JSON.parse(JSON.stringify(o));

function zarf(olcum, seri, ek = {}) {
  const deger = ek.deger || ['Enrolen içeren', 'Tüm Enterit vakaları'];
  return Object.assign({
    olcum, hesap_at: '2026-10-18T09:00:00+03:00', surum: 'sql:20261017000002', n: seri.n[0], yetersiz: seri.n[0] < 5,
    x: { ad: 'grup', deger, anahtar: ['x', 'tumu'] }, seriler: [seri],
    sayac: Object.assign({}, SAYAC, { kiyas_n: seri.n.length > 1 ? seri.n[1] : null }, ek.sayac || {}),
    gecici: { var: false, ilac_fiyat: {} }, tanim: olcum, dipnot: [], fiyat_kaynagi: ek.fiyat_kaynagi || null,
    egri: ek.egri || null,
  }, ek.zarf || {});
}
const BASARI = () => zarf('saglik_basari',
  { ad: 'başarı %', n: [21, 22], k: [17, 18], y: [81.0, 81.8], alt: [60.0, 61.5], ust: [92.3, 92.7] });
const HIZ = () => zarf('saglik_kapanma_gunu', { ad: 'kapanma günü', n: [21, 22], y: [8.0, 10.0], q1: [6.0, 7.5], q3: [11.3, 22.0] });
const CUMLE = (donem = { tip: 'son_ay', n: 12 }, x = 'Enrolen') => ({
  v: 1, alan: 'saglik', hastalik: { tip: 'hastalik', deger: 'h1' }, ilac: { duzey: 'etken', x, y: null },
  kiyas_grubu: 'tumu', olculer: ['saglik_basari'], kirilim: 'yok', donem, kiyas_duzeyi: ['biz'] });

// ── zarfDurum ──────────────────────────────────────────────────────────────
test('durum_veri_yok', () => {
  const z = zarf('saglik_basari', { ad: 'başarı %', n: [0, 0], k: [0, 0], y: [null, null], alt: [null, null], ust: [null, null] });
  assert.strictEqual(G.zarfDurum(z, CUMLE()), 'veri_yok');
  const bos = zarf('saglik_basari', { ad: 'başarı %', n: [0], k: [0], y: [null] }, { zarf: { seriler: [] } });
  assert.strictEqual(G.zarfDurum(bos, CUMLE()), 'veri_yok');
});

test('durum_yetersiz', () => {
  const z = zarf('saglik_basari', { ad: 'başarı %', n: [3, 22], k: [2, 18], y: [null, 81.8], alt: [null, 61.5], ust: [null, 92.7] });
  assert.strictEqual(G.zarfDurum(z, CUMLE()), 'yetersiz');
});

test('durum_fiyat_yok', () => {
  // gerçek şekil: fiyatsız vaka ₺ kümesine girmez → tüm n=0, fiyat_kaynagi 'fiyatsiz', fiyatsiz_n>0
  const z = zarf('saglik_vaka_tl', { ad: 'vaka başı ₺', n: [0, 0], y: [null, null], q1: [null, null], q3: [null, null] },
    { fiyat_kaynagi: 'fiyatsiz', sayac: { fiyatsiz_n: 79, kiyas_n: 0 } });
  assert.strictEqual(G.zarfDurum(z, CUMLE()), 'fiyat_yok');
  // ilk grup y null + fiyatsiz_n>0 (kısmi fiyat)
  const k = zarf('saglik_basari_tl', { ad: 'başarı başına ₺', n: [3, 9], y: [null, 41.5] },
    { fiyat_kaynagi: 'kayitli', sayac: { fiyatsiz_n: 6 } });
  assert.strictEqual(G.zarfDurum(k, CUMLE()), 'fiyat_yok');
  // ₺ dışı ölçüde fiyatsız sayaç durum belirlemez
  const b = zarf('saglik_basari', { ad: 'başarı %', n: [0, 0], k: [0, 0], y: [null, null] }, { sayac: { fiyatsiz_n: 79 } });
  assert.strictEqual(G.zarfDurum(b, CUMLE()), 'veri_yok');
});

test('durum_kontrast_yok', () => {
  const z = zarf('saglik_basari', { ad: 'başarı %', n: [21, 2], k: [17, 1], y: [81.0, null], alt: [60.0, null], ust: [92.3, null] },
    { deger: ['Enrolen içeren', "Enrolen içeren, Halocur'suz"] });
  assert.strictEqual(G.zarfDurum(z, CUMLE()), 'kontrast_yok');
});

test('durum_kontrast_x_yok_tamam', () => {
  // RULING-2: ilaç kırılımında (x yok) 2. satır başka bir ilaçtır; kiyas_n<5 kontrast sayılmaz
  const z = zarf('saglik_basari', { ad: 'başarı %', n: [21, 2], k: [17, 1], y: [81.0, null], alt: [60.0, null], ust: [92.3, null] },
    { deger: ['Enrofloksasin içeren', 'Seftiofur içeren'] });
  assert.strictEqual(z.sayac.kiyas_n, 2);
  assert.strictEqual(G.zarfDurum(z, CUMLE(undefined, null)), 'tamam');
  assert.strictEqual(G.zarfDurum(z, CUMLE(undefined, 'Enrolen')), 'kontrast_yok');
});

test('durum_tamam', () => {
  assert.strictEqual(G.zarfDurum(BASARI(), CUMLE()), 'tamam');
  const tek = zarf('saglik_basari', { ad: 'başarı %', n: [22], k: [18], y: [81.8], alt: [61.5], ust: [92.7] }, { deger: ['Tüm vakalar'] });
  assert.strictEqual(tek.sayac.kiyas_n, null);
  assert.strictEqual(G.zarfDurum(tek, CUMLE(undefined, null)), 'tamam');
});

// ── durumMetni (spec §4.8 birebir) ─────────────────────────────────────────
const YET = () => zarf('saglik_basari', { ad: 'başarı %', n: [3, 22], k: [2, 18], y: [null, 81.8], alt: [null, 61.5], ust: [null, 92.7] });

test('metin_yetersiz_12ay_eylem_24', () => {
  const m = G.durumMetni('yetersiz', YET(), CUMLE({ tip: 'son_ay', n: 12 }));
  assert.strictEqual(m.metin, 'Yetersiz veri (n=3) — en az 5 vaka gerekir');
  assert.deepStrictEqual(kopya(m.eylem), { etiket: 'Dönemi 24 aya çıkar', slot: 'donem', deger: { tip: 'son_ay', n: 24 } });
});

test('metin_yetersiz_24ay_tum', () => {
  const m = G.durumMetni('yetersiz', YET(), CUMLE({ tip: 'son_ay', n: 24 }));
  assert.strictEqual(m.metin, 'Yetersiz veri (n=3) — en az 5 vaka gerekir');
  assert.deepStrictEqual(kopya(m.eylem), { etiket: 'Tüm zamanlar', slot: 'donem', deger: { tip: 'tumu' } });
});

test('metin_yetersiz_tumu_eylemsiz', () => {
  const m = G.durumMetni('yetersiz', YET(), CUMLE({ tip: 'tumu' }));
  assert.strictEqual(m.metin, 'Yetersiz veri (n=3) — en az 5 vaka gerekir');
  assert.strictEqual(m.eylem, null);
});

test('metin_doz', () => {
  const bek = 'Doz verisi yok: uygulamalar ml olarak kayıtlı, hayvan ağırlığı yok; doz kıyası yapılamaz.';
  assert.strictEqual(G.dozMetni(), bek);
  const m = G.durumMetni('doz', null, CUMLE());
  assert.strictEqual(m.metin, bek);
  assert.strictEqual(m.eylem, null);
});

test('metin_diger_durumlar', () => {
  const vy = G.durumMetni('veri_yok', BASARI(), CUMLE());
  assert.strictEqual(vy.metin, 'Bu seçimde vaka yok');
  assert.deepStrictEqual(kopya(vy.eylem), { etiket: 'Son seçimi geri al', slot: 'geri', deger: null });
  const fz = zarf('saglik_vaka_tl', { ad: 'vaka başı ₺', n: [0, 0], y: [null, null] }, { fiyat_kaynagi: 'fiyatsiz', sayac: { fiyatsiz_n: 79 } });
  const fy = G.durumMetni('fiyat_yok', fz, CUMLE());
  assert.strictEqual(fy.metin, '79 vakanın ilaç fiyatı yok');
  assert.deepStrictEqual(kopya(fy.eylem), { etiket: 'Fiyat gir', slot: 'fiyat_panel', deger: null });
  const kz = zarf('saglik_basari', { ad: 'başarı %', n: [21, 2], k: [17, 1], y: [81.0, null] });
  const ky = G.durumMetni('kontrast_yok', kz, CUMLE());
  assert.strictEqual(ky.metin, 'Karşı grup çok küçük (n=2)');
  assert.deepStrictEqual(kopya(ky.eylem), { etiket: 'Ek ilaç ekseninde kıyasla', slot: 'kombinasyon', deger: null });
  const cd = G.durumMetni('cevrimdisi', null, CUMLE());
  assert.strictEqual(cd.metin, 'İstatistik çevrimiçi hesaplanır');
  assert.strictEqual(cd.eylem, null);
  assert.deepStrictEqual(kopya(G.durumMetni('tamam', BASARI(), CUMLE())), { metin: '', eylem: null });
});

// ── zarfOzetCumle (M5, tr-TR) ──────────────────────────────────────────────
test('ozet_basari_iki_grup', () => {
  assert.strictEqual(G.zarfOzetCumle(BASARI()), 'Başarı Enrolen içeren %81,0, Tüm Enterit vakaları %81,8 (fark 0,8 puan).');
});

test('ozet_hiz_fark', () => {
  assert.strictEqual(G.zarfOzetCumle(HIZ()),
    'Medyan kapanma Enrolen içeren 8,0 gün, Tüm Enterit vakaları 10,0 gün (2,0 gün daha kısa).');
  const ters = HIZ(); ters.seriler[0].y = [12.5, 10.0];
  assert.strictEqual(G.zarfOzetCumle(ters),
    'Medyan kapanma Enrolen içeren 12,5 gün, Tüm Enterit vakaları 10,0 gün (2,5 gün daha uzun).');
  const tl = zarf('saglik_vaka_tl', { ad: 'vaka başı ₺', n: [16, 19], y: [1234.5, 20.0], q1: [20, 20], q3: [35, 35] });
  assert.strictEqual(G.zarfOzetCumle(tl),
    'Medyan vaka maliyeti Enrolen içeren ₺1.234,50, Tüm Enterit vakaları ₺20,00 (₺1.214,50 yüksek).');
  const tek = zarf('saglik_basari', { ad: 'başarı %', n: [22], k: [18], y: [81.8] }, { deger: ['Tüm vakalar'] });
  assert.strictEqual(G.zarfOzetCumle(tek), 'Başarı Tüm vakalar: %81,8 (18/22).');
});

test('ozet_zaman_iki_seri_ortak_periyot', () => {
  // KF2-B1: iki seride fark yalnız ikisinde de dolu (y≠null) ORTAK son periyot için yazılır
  const ZX = { x: { ad: 'ay', deger: ['2026-08', '2026-09', '2026-10'], anahtar: ['2026-08-01', '2026-09-01', '2026-10-01'] } };
  const iki = (a, b) => zarf('saglik_basari', a, { zarf: Object.assign({ seriler: [a, b] }, ZX) });
  const A = { ad: 'A', anahtar: 'x', n: [10, 10, 10], k: [7, 7, 8], y: [70.0, 75.0, 80.0] };
  const B = { ad: 'B', anahtar: 'tumu', n: [10, 10, 2], k: [4, 5, 1], y: [40.0, 50.0, null] };
  assert.strictEqual(G.zarfOzetCumle(iki(A, B)), 'Başarı A 2026-09 %75,0, B 2026-09 %50,0 (fark 25,0 puan).');
  // ortak dolu periyot yok (Kapı F2 probe senaryosu): farklı aylar kıyaslanmaz, fark basılmaz
  const A2 = { ad: 'A', anahtar: 'x', n: [2, 3, 10], k: [1, 2, 8], y: [null, null, 80.0] };
  const s = G.zarfOzetCumle(iki(A2, B));
  assert.notStrictEqual(s, 'Başarı A 2026-10 %80,0, B 2026-09 %50,0 (fark 30,0 puan).');
  assert.strictEqual(s, 'Başarı A 2026-10 %80,0, B 2026-10 yetersiz veri (n=2).');
  assert.doesNotMatch(s, /fark/);
  // tek seri: kendi son dolu periyodu (değişmedi)
  const tek = zarf('saglik_basari', B, { zarf: Object.assign({ seriler: [B] }, ZX) });
  assert.strictEqual(G.zarfOzetCumle(tek), 'Başarı B 2026-09: %50,0 (5/10).');
});

test('ozet_neden_fiili_yok', () => {
  const zarflar = [BASARI(), HIZ(),
    zarf('saglik_tedavi_suresi', { ad: 'tedavi süresi (gün)', n: [21, 22], y: [3.0, 5.0], q1: [3, 3], q3: [7, 10] }),
    zarf('saglik_vaka_tl', { ad: 'vaka başı ₺', n: [16, 19], y: [20.0, 35.0], q1: [20, 20], q3: [35, 35] }),
    zarf('saglik_basari_tl', { ad: 'başarı başına ₺', n: [15, 16], y: [37.2, 40.1] }),
    zarf('saglik_basari', { ad: 'başarı %', n: [3, 22], k: [2, 18], y: [null, 81.8] })];
  for (const z of zarflar) {
    const s = G.zarfOzetCumle(z);
    assert.ok(s.length > 0, z.olcum);
    assert.doesNotMatch(s, /sağla|etkili|karşılığı/, s);
  }
});

// ── zarfGrafikConfig (spec §4.6) ───────────────────────────────────────────
test('config_basari_yatay', () => {
  const c = G.zarfGrafikConfig(BASARI(), { tema: TEMA });
  assert.strictEqual(c.options.indexAxis, 'y');
  assert.strictEqual(c.data.datasets.length, 2);
  assert.deepStrictEqual(kopya(c.data.labels), ['Enrolen içeren', 'Tüm Enterit vakaları']);
  assert.deepStrictEqual(kopya(c.data.datasets[0].data), [81.0, 81.8]);
  assert.deepStrictEqual(kopya(c.data.datasets[0].metinler), ['%81 · 17/21', '%82 · 18/22']);
  assert.deepStrictEqual(kopya(c.data.datasets[1].data), [[60.0, 92.3], [61.5, 92.7]]);
  assert.strictEqual(c.data.datasets[1].type, 'bar');
  assert.strictEqual(c.options.animation, false);
});

test('config_hiz_floating', () => {
  const c = G.zarfGrafikConfig(HIZ(), { tema: TEMA });
  assert.strictEqual(c.options.indexAxis, 'y');
  const [aralik, medyan] = c.data.datasets;
  assert.strictEqual(aralik.type, 'bar');
  assert.deepStrictEqual(kopya(aralik.data), [[6.0, 11.3], [7.5, 22.0]]);
  assert.strictEqual(medyan.type, 'scatter');
  assert.deepStrictEqual(kopya(medyan.data), [{ x: 8.0, y: 'Enrolen içeren' }, { x: 10.0, y: 'Tüm Enterit vakaları' }]);
});

test('config_null_nokta', () => {
  const z = zarf('saglik_basari', { ad: 'Tüm vakalar', anahtar: 'tumu', n: [0, 3, 25, 66], k: [0, 1, 19, 55],
    y: [null, null, 76.0, 83.3], alt: [null, null, 56.6, 72.6], ust: [null, null, 88.5, 90.4] },
  { deger: ['2025 Ç4', '2026 Ç1', '2026 Ç2', '2026 Ç3'], zarf: { x: { ad: 'ceyrek',
    deger: ['2025 Ç4', '2026 Ç1', '2026 Ç2', '2026 Ç3'], anahtar: ['2025-10-01', '2026-01-01', '2026-04-01', '2026-07-01'] } } });
  const c = G.zarfGrafikConfig(z, { tema: TEMA });
  assert.strictEqual(c.type, 'line');
  const d = c.data.datasets[0];
  assert.deepStrictEqual(kopya(d.data), [null, null, 76.0, 83.3]);
  assert.strictEqual(d.spanGaps, false);
  assert.strictEqual(d.label, 'Tüm vakalar');
  // hız zaman kırılımı: Q1–Q3 bandı (fill)
  const h = zarf('saglik_kapanma_gunu', { ad: 'Tüm vakalar', anahtar: 'tumu', n: [0, 24, 65], y: [null, 5.0, 8.0],
    q1: [null, 0.0, 7.0], q3: [null, 14.3, 18.0] }, { zarf: { x: { ad: 'ay', deger: ['2026-08', '2026-09', '2026-10'],
    anahtar: ['2026-08-01', '2026-09-01', '2026-10-01'] } } });
  const hc = G.zarfGrafikConfig(h, { tema: TEMA });
  const bant = hc.data.datasets.filter(x => x.fill);
  assert.strictEqual(bant.length, 1);
  assert.ok(hc.data.datasets.every(x => x.spanGaps === false));
  assert.deepStrictEqual(kopya(hc.data.datasets[0].data), [null, 5.0, 8.0]);
});

test('config_gecici_desen', () => {
  const z = zarf('saglik_vaka_tl', { ad: 'vaka başı ₺', n: [16, 19], y: [20.0, 35.0], q1: [20, 20], q3: [35, 35] },
    { fiyat_kaynagi: 'gecici' });
  const c = G.zarfGrafikConfig(z, { tema: TEMA });
  const bg = c.data.datasets[0].backgroundColor;
  assert.strictEqual(bg[0].desen, 'tarali');
  assert.strictEqual(bg[0].renk, TEMA.vurgu);
  assert.strictEqual(bg[1].desen, 'tarali');
  assert.match(c.data.datasets[0].label, /geçici/);
  const kayitli = G.zarfGrafikConfig(Object.assign(z, { fiyat_kaynagi: 'kayitli' }), { tema: TEMA });
  assert.strictEqual(kayitli.data.datasets[0].backgroundColor[0], TEMA.vurgu);
  // başarı başına ₺ bıyıksız
  const bt = zarf('saglik_basari_tl', { ad: 'başarı başına ₺', n: [15, 16], y: [37.2, 40.1] });
  assert.strictEqual(G.zarfGrafikConfig(bt, { tema: TEMA }).data.datasets.length, 1);
});

test('config_renk_yetersiz_gri', () => {
  const z = zarf('saglik_basari', { ad: 'başarı %', n: [21, 22, 3], k: [17, 18, 1], y: [81.0, 81.8, null],
    alt: [60.0, 61.5, null], ust: [92.3, 92.7, null] }, { deger: ['A içeren', 'B içeren', 'C içeren'] });
  const c = G.zarfGrafikConfig(z, { tema: TEMA });
  assert.deepStrictEqual(kopya(c.data.datasets[0].backgroundColor), [TEMA.vurgu, TEMA.kiyas, TEMA.gri]);
  assert.strictEqual(c.data.datasets[1].data[2], null);
});

test('egri_stepped', () => {
  const z = HIZ();
  z.egri = [{ anahtar: 'x', gun: [2, 5, 9], oran: [0.25, 0.5, 1.0] }, { anahtar: 'tumu', gun: [3, 8], oran: [0.4, 1.0] }];
  const c = G.egriGrafikConfig(z, TEMA);
  assert.strictEqual(c.type, 'line');
  assert.strictEqual(c.data.datasets.length, 2);
  const d = c.data.datasets[0];
  assert.strictEqual(d.stepped, true);
  assert.strictEqual(d.label, 'Enrolen içeren');
  assert.deepStrictEqual(kopya(d.data), [{ x: 2, y: 25 }, { x: 5, y: 50 }, { x: 9, y: 100 }]);
  assert.strictEqual(c.options.scales.x.type, 'linear');
  assert.strictEqual(G.egriGrafikConfig(BASARI(), TEMA), null);
});

// ── grafikCiz / temaRenkleri (DOM + Chart) ─────────────────────────────────
test('ciz_destroy_eski', () => {
  const ornekler = [];
  class SahteChart {
    constructor(canvas, config) { this.canvas = canvas; this.config = config; this.yok = 0; ornekler.push(this); }
    destroy() { this.yok += 1; }
  }
  const nitelik = {};
  const ctx = { createPattern: (src, tekrar) => ({ desenKaynak: src, tekrar }) };
  const canvas = { getContext: () => ctx, setAttribute: (k, v) => { nitelik[k] = v; } };
  const pc = { width: 0, height: 0, getContext: () => ({ beginPath() {}, moveTo() {}, lineTo() {}, stroke() {} }) };
  globalThis.Chart = SahteChart;
  globalThis.document = { createElement: () => pc };
  try {
    const z = zarf('saglik_vaka_tl', { ad: 'vaka başı ₺', n: [16, 19], y: [20.0, 35.0], q1: [20, 20], q3: [35, 35] },
      { fiyat_kaynagi: 'gecici' });
    const c1 = G.zarfGrafikConfig(z, { tema: TEMA });
    const a = G.grafikCiz(canvas, c1);
    assert.strictEqual(a, ornekler[0]);
    assert.strictEqual(canvas.__chart, a);
    assert.strictEqual(a.config.data.datasets[0].backgroundColor[0].tekrar, 'repeat');   // desen → CanvasPattern
    assert.strictEqual(pc.width, 8);
    assert.strictEqual(nitelik['aria-label'], G.zarfOzetCumle(z));
    const b = G.grafikCiz(canvas, G.zarfGrafikConfig(BASARI(), { tema: TEMA }));
    assert.strictEqual(a.yok, 1);
    assert.strictEqual(b.yok, 0);
    assert.strictEqual(canvas.__chart, b);
  } finally {
    delete globalThis.Chart;
    delete globalThis.document;
  }
});

test('tema_renkleri_stub', () => {
  const stil = { getPropertyValue: ad => ` v${ad} ` };
  globalThis.document = { body: { ad: 'body' }, documentElement: { ad: 'root' } };
  globalThis.getComputedStyle = el => { assert.strictEqual(el.ad, 'body'); return stil; };
  try {
    assert.deepStrictEqual(kopya(G.temaRenkleri()),
      { vurgu: 'v--green', kiyas: 'v--ink3', gri: 'v--ink3', metin: 'v--ink', izgara: 'v--card3', zemin: 'v--card' });
  } finally {
    delete globalThis.document;
    delete globalThis.getComputedStyle;
  }
  // KF2 Ruling 4: gri = nötr mürekkep --ink3, iki temada da tanımlı (:root açık, body.dark koyu)
  const html = fs.readFileSync(path.join(__dirname, '../../index.html'), 'utf8');
  assert.match(html, /:root\{[^}]*--ink3:#/);
  assert.match(html, /body\.dark\{[^}]*--ink3:#/);
});

// ── TKF3b: çok gruplu çubuk grafik okunurluğu + SQL grup eki ───────────────
const ON_IKI = Array.from({ length: 12 }, (_, i) => `İlaç ${i + 1} içeren`);
const coklu = (olcum, ek = {}) => {
  const d = v => ON_IKI.map(() => v);
  return zarf(olcum, Object.assign({ ad: olcum, n: d(9), k: d(5), y: d(50), alt: d(30), ust: d(70), q1: d(2), q3: d(4) }, ek),
    { deger: ON_IKI });
};

test('cubuk_y_etiketleri_atlanmaz', () => {
  for (const o of ['saglik_basari', 'saglik_kapanma_gunu', 'saglik_tedavi_suresi', 'saglik_vaka_tl', 'saglik_basari_tl']) {
    const y = G.zarfGrafikConfig(coklu(o), { tema: TEMA }).options.scales.y;
    assert.strictEqual(y.ticks.autoSkip, false, o);
    assert.strictEqual(y.ticks.color, TEMA.metin, `${o}: tema rengi korunur`);
  }
  // zaman ekseni 25 periyotta atlamayı Chart.js'e bırakır
  const z = zarf('saglik_basari', { ad: 'Tüm', anahtar: 'tumu', n: [9, 9], k: [5, 5], y: [50, 50] },
    { zarf: { x: { ad: 'ay', deger: ['2026-08', '2026-09'], anahtar: ['2026-08-01', '2026-09-01'] } } });
  assert.notStrictEqual(G.zarfGrafikConfig(z, { tema: TEMA }).options.scales.x.ticks.autoSkip, false);
});

test('cubuk_yukseklik_grup_sayisina_gore', () => {
  const c = G.zarfGrafikConfig(coklu('saglik_basari'), { tema: TEMA });
  assert.ok(c.yukseklik >= 12 * 24, `12 grup satır başına ≥24 px: ${c.yukseklik}`);
  // 2 grup CSS'teki 240 px'te kalır: sabit değer dayatılmaz
  assert.strictEqual(G.zarfGrafikConfig(BASARI(), { tema: TEMA }).yukseklik, null);
  const z = zarf('saglik_basari', { ad: 'Tüm', anahtar: 'tumu', n: [9], k: [5], y: [50] },
    { zarf: { x: { ad: 'ay', deger: ['2026-08'], anahtar: ['2026-08-01'] } } });
  assert.strictEqual(G.zarfGrafikConfig(z, { tema: TEMA }).yukseklik, null);
});

test('ciz_sarmalayici_yuksekligi_chart_oncesi', () => {
  let sira = null;
  const sar = { style: { height: '' } };
  class SahteChart {
    constructor() { sira = sar.style.height; }
    destroy() {}
  }
  const canvas = { getContext: () => null, setAttribute() {}, parentElement: sar };
  globalThis.Chart = SahteChart;
  try {
    const cok = G.zarfGrafikConfig(coklu('saglik_basari'), { tema: TEMA });
    G.grafikCiz(canvas, cok);
    assert.strictEqual(sira, `${cok.yukseklik}px`, 'Chart ölçmeden önce yazılır');
    G.grafikCiz(canvas, G.zarfGrafikConfig(BASARI(), { tema: TEMA }));
    assert.strictEqual(sar.style.height, '', 'az gruba dönünce CSS yüksekliği geri gelir');
  } finally {
    delete globalThis.Chart;
  }
});

test('basari_yuzde_100_etiketi_kesilmez_eksen_0_100', () => {
  const z = zarf('saglik_basari', { ad: 'başarı %', n: [5, 22], k: [5, 18], y: [100, 81.8], alt: [56.6, 61.5], ust: [100, 92.7] });
  const c = G.zarfGrafikConfig(z, { tema: TEMA });
  // 11 px sans-serif rakam ≈ 6,2 px; eklenti metni 4 px sağa yazar
  assert.ok(c.options.layout.padding.right >= 4 + '18/22'.length * 6.2, `dolgu ${c.options.layout.padding.right}`);
  const x = c.options.scales.x;
  assert.strictEqual(x.min, 0);
  assert.strictEqual(x.max, 100);
  assert.strictEqual(x.suggestedMax, undefined);
  assert.strictEqual(x.grace, undefined);
  assert.strictEqual(x.ticks.callback, undefined, 'sahte tik yok');
  // dolgu en uzun metne göre
  const b = zarf('saglik_basari', { ad: 'başarı %', n: [1000, 22], k: [1000, 18], y: [100, 81.8], alt: [99, 61.5], ust: [100, 92.7] });
  assert.ok(G.zarfGrafikConfig(b, { tema: TEMA }).options.layout.padding.right > c.options.layout.padding.right);
  // metinsiz ölçüde dolgu yok
  assert.strictEqual(G.zarfGrafikConfig(HIZ(), { tema: TEMA }).options.layout, undefined);
});

// SQL grup etiketi (stat_atolye_gruplar_k) ile panel eki aynı kural: tablo tek yerde, iki taraf aynı girdiyle koşar.
test('siz_eki_sql_tablosu_gercek_panel_ile_ayni', () => {
  const kok = path.join(__dirname, '../..');
  const sql = fs.readFileSync(path.join(kok, 'tests/sql/stat_atolye_seri_test.sql'), 'utf8');
  const m = sql.match(/-- EK-TABLO-BAS\n([\s\S]*?)-- EK-TABLO-SON/);
  assert.ok(m, 'SQL test dosyasında EK-TABLO bloğu');
  const satir = [...m[1].matchAll(/\('([^']+)', '([^']+)'\)/g)].map(r => [r[1], r[2]]);
  assert.ok(satir.length >= 14, `tablo ${satir.length} satır`);
  for (const ek of ['sız', 'siz', 'suz', 'süz']) assert.ok(satir.some(r => r[1] === ek), ek);
  // panelin çağırdığı helpers.js trLower gövdesi: kopya kural yazılmaz
  const tr = fs.readFileSync(path.join(kok, 'js/utils/helpers.js'), 'utf8').match(/function trLower\(s\) \{[^\n]*\}/);
  const ctx = vm.createContext({ console, girdi: '' });
  vm.runInContext(tr[0], ctx, { filename: 'helpers.js' });
  vm.runInContext(fs.readFileSync(path.join(kok, 'js/istatistik/kombinasyon.js'), 'utf8'), ctx, { filename: 'kombinasyon.js' });
  for (const [y, ek] of satir) {
    ctx.girdi = y;
    assert.strictEqual(vm.runInContext('_kombinasyonSiz(girdi)', ctx), `${y}'${ek}`);
  }
});

test('dosya_kurallari', () => {
  const src = fs.readFileSync(DOSYA, 'utf8');
  assert.doesNotMatch(src, /protokol/i);
  assert.doesNotMatch(src, /sağla|etkili|karşılığı/);
  assert.doesNotMatch(src, /#[0-9a-fA-F]{3,8}\b/, 'sabit hex renk yok');
  assert.doesNotMatch(src, /rgba?\(/, 'sabit rgb renk yok');
  assert.match(src, /^'use strict';$/m);
  assert.match(src, /module\.exports/);
});

// ── TFA G1: ilaç kırılımında yalnız yeterli gruplar, ölçüye göre sıra ──────
// Fikstür demo Enterit etken kırılımının biçimi (T16 S2: 2/11). Kâhinler elle.
const ILACLAR = ['Enrofloksasin', 'Flunixin', 'Halofuginon', 'Meloksikam', 'Sukralfat (Antepsin)', 'Tilmikosin', 'Gentamisin',
  'Oksitetrasiklin', 'E Vitamini', 'kalsiyum karbonat', 'Marbofloksasin'];
const ILAC_X = l => ({ ad: 'grup', deger: l.map(a => `${a} içeren`), anahtar: l.map(a => `ilac:${a}`) });
const ENTERIT = () => zarf('saglik_basari', { ad: 'başarı %', n: [16, 4, 4, 6, 4, 4, 2, 1, 1, 1, 1], k: [13, 4, 3, 4, 2, 3, 1, 0, 1, 1, 0],
  y: [81.3, null, null, 66.7, null, null, null, null, null, null, null],
  alt: [57, null, null, 30, null, null, null, null, null, null, null], ust: [93, null, null, 90, null, null, null, null, null, null, null] },
{ zarf: { n: 16, x: ILAC_X(ILACLAR) }, sayac: { kiyas_n: 4 } });
const CUMLE_ILAC = () => Object.assign(CUMLE(undefined, null), { kirilim: 'ilac' });
const ILAC_ZARF = (olcum, l, n, y, ek = {}) => zarf(olcum, Object.assign({ ad: olcum, n, y }, ek),
  { zarf: { n: n[0], x: ILAC_X(l) }, sayac: { kiyas_n: n[1] === undefined ? null : n[1] } });

test('gruplar_enterit_2_11', () => {
  const h = G.grafikGruplariHazirla(ENTERIT());
  assert.strictEqual(h.rozet, '2/11 ilaçta yeterli veri');
  assert.deepStrictEqual(kopya(h.cizilen.x.deger), ['Enrofloksasin içeren', 'Meloksikam içeren']);
  assert.deepStrictEqual(kopya(h.cizilen.x.anahtar), ['ilac:Enrofloksasin', 'ilac:Meloksikam']);
  assert.deepStrictEqual(kopya(h.cizilen.seriler[0].n), [16, 6]);
  assert.deepStrictEqual(kopya(h.cizilen.seriler[0].k), [13, 4]);
  assert.deepStrictEqual(kopya(h.cizilen.seriler[0].ust), [93, 90]);
  assert.strictEqual(h.azGruplar.length, 9);
  assert.deepStrictEqual(kopya(h.azGruplar[0]), { anahtar: 'ilac:Flunixin', ad: 'Flunixin', n: 4 });
  assert.strictEqual(h.azMetin, '9 ilaçta veri az (<5 vaka): Flunixin 4 · Halofuginon 4 · Sukralfat (Antepsin) 4 · Tilmikosin 4 · '
    + 'Gentamisin 2 · Oksitetrasiklin 1 · E Vitamini 1 · kalsiyum karbonat 1 · Marbofloksasin 1');
});

test('gruplar_girdi_degismez', () => {
  const z = ENTERIT();
  const once = JSON.stringify(z);
  G.grafikGruplariHazirla(z);
  G.zarfGrafikConfig(z, { tema: TEMA });
  assert.strictEqual(JSON.stringify(z), once);
});

test('gruplar_az_liste_n_buyuk_once', () => {
  const z = ILAC_ZARF('saglik_basari', ['A', 'B', 'C'], [1, 4, 6], [null, null, 50], { k: [0, 1, 3] });
  assert.deepStrictEqual(G.grafikGruplariHazirla(z).azGruplar.map(g => g.ad), ['B', 'A']);
});

test('sira_basari_azalan_esitlikte_n_buyuk', () => {
  const z = ILAC_ZARF('saglik_basari', ['A', 'B', 'C', 'D'], [20, 8, 12, 9], [60, 100, 100, 70], { k: [12, 8, 12, 6] });
  assert.deepStrictEqual(kopya(G.grafikGruplariHazirla(z).cizilen.x.deger), ['C içeren', 'B içeren', 'D içeren', 'A içeren']);
});

for (const olcum of ['saglik_kapanma_gunu', 'saglik_tedavi_suresi', 'saglik_vaka_tl', 'saglik_basari_tl']) {
  test(`sira_artan_esitlikte_n_buyuk_${olcum}`, () => {
    const z = ILAC_ZARF(olcum, ['A', 'B', 'C', 'D'], [20, 8, 12, 9], [10, 4, 4, 7.5], { q1: [1, 2, 3, 4], q3: [5, 6, 7, 8] });
    const c = G.grafikGruplariHazirla(z).cizilen;
    assert.deepStrictEqual(kopya(c.x.deger), ['C içeren', 'B içeren', 'D içeren', 'A içeren']);
    assert.deepStrictEqual(kopya(c.seriler[0].y), [4, 4, 7.5, 10]);
    assert.deepStrictEqual(kopya(c.seriler[0].q3), [7, 6, 8, 5], 'paralel diziler birlikte taşınır');
  });
}

test('gruplar_kiyas_ilacsiz_zaman_aynen', () => {
  const kiyas = BASARI();
  const h = G.grafikGruplariHazirla(kiyas);
  assert.strictEqual(h.cizilen, kiyas);
  assert.strictEqual(h.rozet, null);
  assert.deepStrictEqual(kopya(h.azGruplar), []);
  assert.strictEqual(h.azMetin, '');
  const ilacsiz = zarf('saglik_basari', { ad: 'b', n: [3], k: [1], y: [null] }, { zarf: { x: { ad: 'grup', deger: ['Tüm vakalar'], anahtar: ['tumu'] } } });
  assert.strictEqual(G.grafikGruplariHazirla(ilacsiz).cizilen, ilacsiz);
  const z = zarf('saglik_basari', { ad: 'T', anahtar: 'tumu', n: [9, 9], k: [5, 5], y: [50, 60] },
    { zarf: { x: { ad: 'ay', deger: ['2026-08', '2026-09'], anahtar: ['2026-08-01', '2026-09-01'] } } });
  assert.strictEqual(G.grafikGruplariHazirla(z).cizilen, z);
  // çubuk, n metni ve sıra kıyas kartında değişmez
  const c = G.zarfGrafikConfig(HIZ(), { tema: TEMA });
  assert.strictEqual(c.data.datasets[0].metinler, undefined);
});

test('config_ilac_yalniz_yeterli_gruplar', () => {
  const c = G.zarfGrafikConfig(ENTERIT(), { tema: TEMA });
  assert.deepStrictEqual(kopya(c.data.labels), ['Enrofloksasin içeren', 'Meloksikam içeren']);
  assert.deepStrictEqual(kopya(c.data.datasets[0].data), [81.3, 66.7]);
  assert.deepStrictEqual(kopya(c.data.datasets[0].metinler), ['%81 · 13/16', '%67 · 4/6']);
  assert.strictEqual(c.yukseklik, null, '2 satır taban yükseklikte');
});

test('config_ilac_her_satirda_vaka_sayisi', () => {
  const sure = ILAC_ZARF('saglik_kapanma_gunu', ['A', 'B'], [6, 16], [10, 8], { q1: [7, 5], q3: [12, 9] });
  const c = G.zarfGrafikConfig(sure, { tema: TEMA });
  assert.deepStrictEqual(kopya(c.data.labels), ['B içeren', 'A içeren']);
  assert.deepStrictEqual(kopya(c.data.datasets[0].metinler), ['8 gün · n=16', '10 gün · n=6']);
  assert.deepStrictEqual(kopya(c.data.datasets[0].metinX), [9, 12]);
  assert.ok(c.options.layout.padding.right > 0);
  const tl = G.zarfGrafikConfig(ILAC_ZARF('saglik_vaka_tl', ['A', 'B'], [6, 16], [40, 20], { q1: [30, 10], q3: [50, 30] }), { tema: TEMA });
  assert.deepStrictEqual(kopya(tl.data.datasets[0].metinler), ['₺20 · n=16', '₺40 · n=6']);
  assert.deepStrictEqual(kopya(tl.data.datasets[0].metinX), [30, 50], 'bıyık ucunun sağına');
  const bt = G.zarfGrafikConfig(ILAC_ZARF('saglik_basari_tl', ['A', 'B'], [6, 16], [40, 20]), { tema: TEMA });
  assert.deepStrictEqual(kopya(bt.data.datasets[0].metinler), ['₺20 · n=16', '₺40 · n=6']);
  const ts = G.zarfGrafikConfig(ILAC_ZARF('saglik_tedavi_suresi', ['A'], [6], [3], { q1: [2], q3: [4] }), { tema: TEMA });
  assert.deepStrictEqual(kopya(ts.data.datasets[0].metinler), ['3 gün · n=6']);
});

test('ozet_ilac_cizilen_gruplardan', () => {
  assert.strictEqual(G.zarfOzetCumle(ENTERIT()), 'Başarı Enrofloksasin içeren %81,3, Meloksikam içeren %66,7 (fark 14,6 puan).');
  const uc = ILAC_ZARF('saglik_basari', ['A', 'B', 'C', 'D'], [20, 8, 12, 2], [60, 100, 90, null], { k: [12, 8, 11, 1] });
  assert.strictEqual(G.zarfOzetCumle(uc), 'Başarı B içeren: %100,0 (8/8). 2 grup daha grafikte.');
});

test('durum_ilac_yeterli_grup_varsa_tamam', () => {
  // SQL sırası tüm vaka sayısına göre: 1. grubun ölçü n'i <5 olsa da yeterli grup çizilir
  const z = ILAC_ZARF('saglik_kapanma_gunu', ['A', 'B'], [4, 6], [null, 8], { q1: [null, 5], q3: [null, 9] });
  assert.strictEqual(G.zarfDurum(z, CUMLE_ILAC()), 'tamam');
  assert.strictEqual(G.zarfDurum(ENTERIT(), CUMLE_ILAC()), 'tamam');
  assert.strictEqual(G.zarfDurum(ENTERIT(), null), 'tamam', 'ilaç satırları kıyas grubu değildir');
});

test('durum_ilac_yeterli_grup_yoksa_yetersiz', () => {
  const z = ILAC_ZARF('saglik_basari', ['A', 'B'], [4, 3], [null, null], { k: [1, 1] });
  assert.strictEqual(G.zarfDurum(z, CUMLE_ILAC()), 'yetersiz');
  assert.strictEqual(G.durumMetni('yetersiz', z, CUMLE_ILAC()).metin, 'Yetersiz veri (n=4) — en az 5 vaka gerekir');
  const bos = ILAC_ZARF('saglik_basari', ['A', 'B'], [0, 0], [null, null], { k: [0, 0] });
  assert.strictEqual(G.zarfDurum(bos, CUMLE_ILAC()), 'veri_yok');
});

test('durum_ilac_fiyat', () => {
  const hep = ILAC_ZARF('saglik_vaka_tl', ['A', 'B'], [0, 0], [null, null]);
  Object.assign(hep, { fiyat_kaynagi: 'fiyatsiz', sayac: { fiyatsiz_n: 18, kiyas_n: 0 } });
  assert.strictEqual(G.zarfDurum(hep, CUMLE_ILAC()), 'fiyat_yok');
  // kısmi fiyat: 1. grup boş, 2. grup dolu → çizilir ("Fiyat gir" kartta kalır)
  const kismi = ILAC_ZARF('saglik_vaka_tl', ['A', 'B'], [2, 6], [null, 30], { q1: [null, 20], q3: [null, 40] });
  Object.assign(kismi, { fiyat_kaynagi: 'kayitli', sayac: { fiyatsiz_n: 4, kiyas_n: 6 } });
  assert.strictEqual(G.zarfDurum(kismi, CUMLE_ILAC()), 'tamam');
  // hiçbir grup dolu değilken fiyatsız vaka varsa fiyat eylemi yetersizden önce
  const az = ILAC_ZARF('saglik_vaka_tl', ['A', 'B'], [2, 3], [null, null]);
  Object.assign(az, { fiyat_kaynagi: 'kayitli', sayac: { fiyatsiz_n: 4, kiyas_n: 3 } });
  assert.strictEqual(G.zarfDurum(az, CUMLE_ILAC()), 'fiyat_yok');
});

test('sabit_false_eski_davranis_doner', () => {
  const src = fs.readFileSync(DOSYA, 'utf8');
  assert.strictEqual((src.match(/const _GRAFIK_YETERLI_GRUPLAR = true;/g) || []).length, 1, 'tek açık/kapalı noktası');
  const kapali = src.replace('const _GRAFIK_YETERLI_GRUPLAR = true;', 'const _GRAFIK_YETERLI_GRUPLAR = false;');
  const m = { exports: {} };
  vm.runInNewContext(kapali, { module: m, Number, Object, Array, Math, String, JSON });
  const E = m.exports;
  const z = ENTERIT();
  const h = E.grafikGruplariHazirla(z);
  assert.strictEqual(h.cizilen, z);
  assert.strictEqual(h.rozet, null);
  assert.strictEqual(h.azGruplar.length, 0);
  const c = E.zarfGrafikConfig(z, { tema: TEMA });
  assert.deepStrictEqual(kopya(c.data.labels), ILACLAR.map(a => `${a} içeren`), 'SQL sırası, tüm gruplar');
  assert.strictEqual(E.zarfOzetCumle(z), 'Başarı Enrofloksasin içeren: %81,3 (13/16). 10 grup daha grafikte.');
  const sure = ILAC_ZARF('saglik_kapanma_gunu', ['A', 'B'], [4, 6], [null, 8], { q1: [null, 5], q3: [null, 9] });
  assert.strictEqual(E.zarfGrafikConfig(sure, { tema: TEMA }).data.datasets[0].metinler, undefined, 'n metni eklenmez');
  assert.strictEqual(E.zarfDurum(sure, CUMLE_ILAC()), 'yetersiz', 'eski kural: 1. grubun n\'i');
});

// ── TFA G2: zaman kırılımı ─────────────────────────────────────────────────
const AYLAR = ['2026-06', '2026-07', '2026-08', '2026-09', '2026-10'];
const ZAMAN = (seriler, ad = 'ay', deger = AYLAR) => zarf('saglik_basari', seriler[0],
  { zarf: { n: _toplamN(seriler[0]), x: { ad, deger, anahtar: deger.map(d => `${d}-01`) }, seriler } });
function _toplamN(s) { return s.n.reduce((a, b) => a + b, 0); }
const S = (n, y, ad = 'Tüm Enterit vakaları', anahtar = 'tumu') => ({ ad, anahtar, n, k: n.map(() => 1), y });
const CUMLE_AY = (kirilim = 'ay', donem) => Object.assign(CUMLE(donem, null), { kirilim });

test('durum_zaman_seyrek_tek_nokta', () => {
  const z = ZAMAN([S([4, 8, 3, 3, 0], [null, 75, null, null, null])]);
  assert.strictEqual(G.zarfDurum(z, CUMLE_AY()), 'zaman_seyrek');
  const m = G.durumMetni('zaman_seyrek', z, CUMLE_AY());
  assert.strictEqual(m.metin, 'Başarı Tüm Enterit vakaları 2026-07: %75,0 (1/8). Çizgi için en az 2 dönemde 5 vaka gerekir.');
  assert.deepStrictEqual(kopya(m.eylem), { etiket: 'Çeyreklik göster', slot: 'kirilim', deger: 'ceyrek' });
});

test('durum_zaman_seyrek_hic_dolu_yok', () => {
  const z = ZAMAN([S([4, 3, 3, 0, 0], [null, null, null, null, null])]);
  assert.strictEqual(G.zarfDurum(z, CUMLE_AY()), 'zaman_seyrek');
  assert.strictEqual(G.durumMetni('zaman_seyrek', z, CUMLE_AY()).metin, 'Çizgi için en az 2 dönemde 5 vaka gerekir.');
});

test('durum_zaman_toplam_az_yetersiz_kalir', () => {
  const z = ZAMAN([S([2, 2, 0, 0, 0], [null, null, null, null, null])]);
  assert.strictEqual(G.zarfDurum(z, CUMLE_AY()), 'yetersiz');
});

test('durum_zaman_eylem_ceyrek_yil', () => {
  const c = ZAMAN([S([9, 2], [75, null])], 'ceyrek', ['2026 Ç2', '2026 Ç3']);
  assert.strictEqual(G.zarfDurum(c, CUMLE_AY('ceyrek')), 'zaman_seyrek');
  assert.deepStrictEqual(kopya(G.durumMetni('zaman_seyrek', c, CUMLE_AY('ceyrek')).eylem), { etiket: 'Yıllık göster', slot: 'kirilim', deger: 'yil' });
  const y = ZAMAN([S([9, 2], [75, null])], 'yil', ['2025', '2026']);
  assert.deepStrictEqual(kopya(G.durumMetni('zaman_seyrek', y, CUMLE_AY('yil')).eylem),
    { etiket: 'Dönemi 24 aya çıkar', slot: 'donem', deger: { tip: 'son_ay', n: 24 } }, 'yıldan yukarı yok: dönem');
  assert.strictEqual(G.durumMetni('zaman_seyrek', y, CUMLE_AY('yil', { tip: 'tumu' })).eylem, null);
});

test('durum_zaman_iki_nokta_tamam_iki_seri_en_doluya_gore', () => {
  assert.strictEqual(G.zarfDurum(ZAMAN([S([9, 0, 9, 0, 0], [75, null, 50, null, null])]), CUMLE_AY()), 'tamam');
  const iki = ZAMAN([S([9, 0, 2, 0, 0], [75, null, null, null, null], 'A içeren', 'x'), S([9, 9, 9, 0, 0], [70, 60, 50, null, null])]);
  assert.notStrictEqual(G.zarfDurum(iki, CUMLE_AY()), 'zaman_seyrek', 'Tüm serisi 3 nokta');
  const ikiSeyrek = ZAMAN([S([9, 0, 2, 0, 0], [75, null, null, null, null], 'A içeren', 'x'), S([9, 2, 2, 0, 0], [70, null, null, null, null])]);
  assert.strictEqual(G.zarfDurum(ikiSeyrek, CUMLE_AY()), 'zaman_seyrek');
});

test('cizgi_kopuk_periyot_etiketi', () => {
  const z = ZAMAN([S([9, 4, 0, 8, 2], [75, null, null, 50, null])]);
  const c = G.zarfGrafikConfig(z, { tema: TEMA });
  assert.deepStrictEqual(kopya(c.data.datasets[0].data), [75, null, null, 50, null], 'n<5 çizilmez');
  assert.strictEqual(c.data.datasets[0].spanGaps, false);
  assert.deepStrictEqual(kopya(c.data.labels), AYLAR, 'tüm periyotlar eksende');
  const cb = c.options.scales.x.ticks.callback;
  assert.strictEqual(cb(0), '2026-06');
  assert.deepStrictEqual(kopya(cb(1)), ['2026-07', 'n<5']);
  assert.deepStrictEqual(kopya(cb(2)), ['2026-08', 'n=0']);
  assert.strictEqual(cb(3), '2026-09');
  assert.deepStrictEqual(kopya(cb(4)), ['2026-10', 'n<5']);
  assert.strictEqual(c.options.scales.x.ticks.color, TEMA.metin);
  // iki seri: bir serisi dolu periyot etiketlenmez
  const iki = ZAMAN([S([9, 2, 0, 0, 0], [75, null, null, null, null], 'A', 'x'), S([9, 9, 3, 0, 0], [70, 60, null, null, null])]);
  const k = G.zarfGrafikConfig(iki, { tema: TEMA }).options.scales.x.ticks.callback;
  assert.strictEqual(k(1), '2026-07');
  assert.deepStrictEqual(kopya(k(2)), ['2026-08', 'n<5']);
});

// ── TFA review tur1 ────────────────────────────────────────────────────────
for (const [olcum, y] of [['saglik_basari', [60, 100, 80]], ['saglik_kapanma_gunu', [9, 1, 5]], ['saglik_tedavi_suresi', [9, 1, 5]],
  ['saglik_vaka_tl', [90, 1, 50]], ['saglik_basari_tl', [90, 1, 50]]]) {
  test(`b1_bilinmiyor_en_iyi_degerde_de_son_${olcum}`, () => {
    const z = ILAC_ZARF(olcum, ['A', '(bilinmiyor)', 'B'], [9, 30, 8], y, { k: [5, 30, 6], q1: [1, 2, 3], q3: [4, 5, 6] });
    assert.deepStrictEqual(kopya(G.grafikGruplariHazirla(z).cizilen.x.deger), ['B içeren', 'A içeren', '(bilinmiyor) içeren']);
    assert.doesNotMatch(G.zarfOzetCumle(z), /^\S+( \S+)? \(bilinmiyor\)/, 'özet başta göstermez');
    assert.strictEqual(G.zarfGrafikConfig(z, { tema: TEMA }).data.labels[2], '(bilinmiyor) içeren');
  });
}

test('b1_bilinmiyor_az_listede_de_son', () => {
  const z = ILAC_ZARF('saglik_basari', ['(bilinmiyor)', 'A', 'B'], [4, 2, 9], [null, null, 50], { k: [1, 1, 5] });
  assert.deepStrictEqual(G.grafikGruplariHazirla(z).azGruplar.map(g => g.anahtar), ['ilac:A', 'ilac:(bilinmiyor)']);
});

test('b2_seyrek_iki_seri_dolu_seriden_cumle', () => {
  const z = ZAMAN([S([4, 3, 0, 0, 0], [null, null, null, null, null], 'X içeren', 'x'), S([4, 6, 0, 0, 0], [null, 66.7, null, null, null], 'Tüm')]);
  z.seriler[1].k = [1, 4, 0, 0, 0];
  assert.strictEqual(G.zarfDurum(z, CUMLE_AY()), 'zaman_seyrek');
  assert.strictEqual(G.durumMetni('zaman_seyrek', z, CUMLE_AY()).metin,
    'Başarı Tüm 2026-07: %66,7 (4/6). Çizgi için en az 2 dönemde 5 vaka gerekir.');
  const once = JSON.stringify(z);
  G.durumMetni('zaman_seyrek', z, CUMLE_AY());
  assert.strictEqual(JSON.stringify(z), once, 'girdi değişmez');
});

test('b4_rozet_veri_yok_fiyat_yok_basilmaz', () => {
  const z = ENTERIT();
  assert.strictEqual(G.grafikRozet(z, 'tamam'), '2/11 ilaçta yeterli veri');
  assert.strictEqual(G.grafikRozet(z, 'yetersiz'), '2/11 ilaçta yeterli veri');
  assert.strictEqual(G.grafikRozet(z, 'veri_yok'), '');
  assert.strictEqual(G.grafikRozet(z, 'fiyat_yok'), '');
  assert.strictEqual(G.grafikRozet(BASARI(), 'veri_yok'), null, 'ilaç kırılımı değil: çağıran kendi rozetini yazar');
});

test('b5_veri_az_tanınamayan_ilac', () => {
  const z = ILAC_ZARF('saglik_basari', ['A', '(bilinmiyor)'], [9, 2], [50, null], { k: [5, 1] });
  const h = G.grafikGruplariHazirla(z);
  assert.strictEqual(h.azMetin, '1 ilaçta veri az (<5 vaka): Tanınamayan ilaç 2');
  assert.strictEqual(h.azGruplar[0].anahtar, 'ilac:(bilinmiyor)');
});

// ── TKF4: satır etiketi değeri söyler, aralık ve medyan çubuğun üstünde ────
test('etiket_basari_yuzde_ve_k_n', () => {
  const z = ILAC_ZARF('saglik_basari', ['A', 'B'], [16, 5], [81.25, 100], { k: [13, 5], alt: [57, 56.6], ust: [93, 100] });
  assert.deepStrictEqual(kopya(G.zarfGrafikConfig(z, { tema: TEMA }).data.datasets[0].metinler), ['%100 · 5/5', '%81 · 13/16']);
});

test('etiket_sure_tr_ondalik', () => {
  for (const o of ['saglik_kapanma_gunu', 'saglik_tedavi_suresi']) {
    const z = ILAC_ZARF(o, ['A', 'B'], [5, 8], [8, 9.5], { q1: [7, 6], q3: [11, 12] });
    assert.deepStrictEqual(kopya(G.zarfGrafikConfig(z, { tema: TEMA }).data.datasets[0].metinler), ['8 gün · n=5', '9,5 gün · n=8'], o);
  }
});

test('etiket_tl_tam_ve_kurus', () => {
  for (const o of ['saglik_vaka_tl', 'saglik_basari_tl']) {
    const z = ILAC_ZARF(o, ['A', 'B', 'C'], [6, 7, 8], [150, 1234.5, 150.25], { q1: [1, 2, 3], q3: [200, 1500, 300] });
    assert.deepStrictEqual(kopya(G.zarfGrafikConfig(z, { tema: TEMA }).data.datasets[0].metinler),
      ['₺150 · n=6', '₺150,25 · n=8', '₺1.234,50 · n=7'], o);
  }
});

test('etiket_n_kucuk_hic_basilmaz', () => {
  // kıyas kartında süzme yok: y=null satırın değeri de sayısı da etikete girmez
  const b = zarf('saglik_basari', { ad: 'başarı %', n: [21, 3], k: [17, 2], y: [81, null], alt: [60, null], ust: [92, null] });
  const m = G.zarfGrafikConfig(b, { tema: TEMA }).data.datasets[0].metinler;
  assert.strictEqual(m[0], '%81 · 17/21');
  assert.strictEqual(m[1], '', 'n<5 satırı boş');
  // ilaç kırılımı: n<5 satır etiket dizisine hiç gelmez
  for (const [o, ek] of [['saglik_kapanma_gunu', { q1: [5, null], q3: [9, null] }], ['saglik_vaka_tl', { q1: [5, null], q3: [9, null] }], ['saglik_basari_tl', {}]]) {
    const z = ILAC_ZARF(o, ['A', 'B'], [6, 4], [8, null], ek);
    const e = G.zarfGrafikConfig(z, { tema: TEMA }).data.datasets[0].metinler;
    assert.strictEqual(e.length, 1, o);
    assert.doesNotMatch(e.join(' '), /n=4/, o);
  }
});

// Eklenti gerçek kancasıyla koşar; ctx yalnız çizilen segmentleri kaydeder. Eksen: 1 birim = 2 px; scatter öğesi kendi pikselini taşır.
function isaretKosu(config) {
  const seg = [];
  let g = null;
  const ctx = { save() {}, restore() {}, fillText() {}, beginPath() { g = []; }, moveTo(x, y) { g.push([x, y]); }, lineTo(x, y) { g.push([x, y]); },
    stroke() { seg.push({ renk: ctx.strokeStyle, kalin: ctx.lineWidth, yol: g }); } };
  const ds = config.data.datasets;
  const chart = { ctx, data: config.data, scales: { x: { getPixelForValue: v => v * 2 } },
    getDatasetMeta: i => ({ data: ds[i].data.map((d, j) => ({ x: d && d.x !== undefined ? d.x * 2 : 0, y: 40 + j * 40 })) }) };
  config.plugins.forEach(p => { if (p.afterDatasetsDraw) p.afterDatasetsDraw(chart); });
  return seg;
}

test('wilson_tum_aralik_alt_uc_dahil_haleli', () => {
  const z = ILAC_ZARF('saglik_basari', ['Flunixin'], [5], [100], { k: [5], alt: [56.6], ust: [100] });
  const seg = isaretKosu(G.zarfGrafikConfig(z, { tema: TEMA }));
  const ust = seg.filter(s => s.renk === TEMA.metin);
  const hale = seg.filter(s => s.renk === TEMA.zemin);
  assert.ok(ust.length >= 3 && hale.length === ust.length, 'gövde + iki uç, her biri haleli');
  assert.ok(ust.some(s => s.yol[0][0] === 113.2 && s.yol[1][0] === 200 && s.yol[0][1] === s.yol[1][1]), 'gövde alt→üst');
  assert.ok(ust.some(s => s.yol[0][0] === 113.2 && s.yol[1][0] === 113.2 && s.yol[0][1] !== s.yol[1][1]), 'alt uç dikey');
  assert.ok(ust.some(s => s.yol[0][0] === 200 && s.yol[1][0] === 200), 'üst uç dikey');
  assert.ok(hale.every(h => h.kalin > ust[0].kalin), 'hale çizgiden kalın');
  assert.ok(seg.findIndex(s => s.renk === TEMA.zemin) < seg.findIndex(s => s.renk === TEMA.metin), 'hale altta');
});

test('wilson_degerler_zarftan_null_cizilmez', () => {
  const b = zarf('saglik_basari', { ad: 'başarı %', n: [21, 3], k: [17, 2], y: [81, null], alt: [60, null], ust: [92, null] });
  const xler = new Set(isaretKosu(G.zarfGrafikConfig(b, { tema: TEMA })).flatMap(s => s.yol.map(p => p[0])));
  assert.deepStrictEqual([...xler].sort((a, c) => a - c), [120, 184], 'yalnız zarfın alt/üst değeri (×2 px)');
});

test('vaka_tl_q1_q3_biyigi_de_ustte', () => {
  const z = ILAC_ZARF('saglik_vaka_tl', ['A'], [6], [150], { q1: [100], q3: [200] });
  assert.ok(isaretKosu(G.zarfGrafikConfig(z, { tema: TEMA })).some(s => s.renk === TEMA.metin && s.yol[0][0] === 200 && s.yol[1][0] === 400));
  const bt = ILAC_ZARF('saglik_basari_tl', ['A'], [6], [150]);
  assert.strictEqual(isaretKosu(G.zarfGrafikConfig(bt, { tema: TEMA })).length, 0, 'başarı başına ₺ bıyıksız');
});

test('medyan_isareti_ustte_haleli_iki_sure_olcusu', () => {
  for (const o of ['saglik_kapanma_gunu', 'saglik_tedavi_suresi']) {
    const z = ILAC_ZARF(o, ['A'], [5], [8], { q1: [8], q3: [11] });
    const seg = isaretKosu(G.zarfGrafikConfig(z, { tema: TEMA }));
    const ust = seg.filter(s => s.renk === TEMA.metin);
    assert.strictEqual(ust.length, 1, o);
    assert.strictEqual(ust[0].yol[0][0], 16, 'scatter noktasının x pikseli');
    assert.strictEqual(ust[0].yol[1][0], 16, 'dikey');
    assert.ok(Math.abs(ust[0].yol[0][1] - ust[0].yol[1][1]) >= 14, 'satırda okunur boy');
    assert.ok(seg.some(s => s.renk === TEMA.zemin && s.kalin > ust[0].kalin), 'hale');
  }
});

test('uzun_etikete_sag_dolgu_yeter', () => {
  const z = ILAC_ZARF('saglik_vaka_tl', ['A'], [123], [1234.5], { q1: [1], q3: [1500] });
  const c = G.zarfGrafikConfig(z, { tema: TEMA });
  const uzun = c.data.datasets[0].metinler[0];
  assert.ok(c.options.layout.padding.right >= 4 + uzun.length * 6.2, `dolgu ${c.options.layout.padding.right}, ${uzun}`);
});

// Duman T(390): sağ dolgu Chart.js'in y payını kısar (kullanılabilir genişliğin yarısı), "Enrofloksasin içeren" 3 px kesildi.
test('y_ekseni_sag_dolgudan_kisilmaz', () => {
  const y = G.zarfGrafikConfig(ENTERIT(), { tema: TEMA }).options.scales.y;
  const olc = (genis, widest) => { const s = { width: genis, chart: { width: 348 }, _getLabelSizes: () => ({ widest: { width: widest } }) }; y.afterFit(s); return s.width; };
  assert.strictEqual(olc(116, 108), 122, 'Chart.js payı 116; etiket + 14 px çentik/boşluk');
  assert.strictEqual(olc(130, 108), 130, 'daraltmaz');
  assert.strictEqual(olc(116, 300), 174, 'tuvalin yarısını aşmaz');
});

// ── BORC-UI ──
test('borc_u2_cizilir_tek_tanim', () => {
  for (const d of ['tamam', 'kontrast_yok']) assert.strictEqual(G.grafikCizilir(d), true, d);
  for (const d of ['veri_yok', 'yetersiz', 'fiyat_yok', 'zaman_seyrek', 'eski', 'hata', 'cevrimdisi', 'yukleniyor']) assert.strictEqual(G.grafikCizilir(d), false, d);
  for (const f of ['grafik', 'kurucu', 'pano']) {
    const s = fs.readFileSync(path.join(__dirname, `../../js/istatistik/${f}.js`), 'utf8').replace(/function grafikCizilir[^\n]*\n/, '');
    assert.ok(!/'tamam' (&&|\|\|) \w+ [!=]== 'kontrast_yok'/.test(s), `${f}: koşul tekrarı`);
  }
});

const TL_ILAC = (olcum, fiyatsiz) => zarf(olcum, { ad: 'tl', n: [6, 3, 0], y: [120, null, null], q1: [100, null, null], q3: [140, null, null] }, {
  sayac: { fiyatsiz_n: fiyatsiz }, fiyat_kaynagi: 'gecici',
  zarf: { x: { ad: 'grup', deger: ['A içeren', 'B içeren', 'C içeren'], anahtar: ['ilac:Aa', 'ilac:Bb', 'ilac:Cc'] } },
});

test('borc_u3_tl_kismi_fiyat_vaka_azdan_ayrilir', () => {
  assert.strictEqual(G.grafikGruplariHazirla(TL_ILAC('saglik_vaka_tl', 4)).azMetin,
    '1 ilaçta fiyatlı vaka az (<5): Bb 3. 1 ilaçta fiyatlı vaka yok: Cc');
  assert.strictEqual(G.grafikGruplariHazirla(TL_ILAC('saglik_basari_tl', 4)).azMetin,
    '1 ilaçta fiyatlı başarılı vaka az (<5): Bb 3. 1 ilaçta fiyatlı başarılı vaka yok: Cc');
});

test('borc_u3_fiyatsiz_yoksa_ya_da_tl_degilse_metin_aynen', () => {
  const eski = '2 ilaçta veri az (<5 vaka): Bb 3 · Cc 0';
  assert.strictEqual(G.grafikGruplariHazirla(TL_ILAC('saglik_vaka_tl', 0)).azMetin, eski);
  assert.strictEqual(G.grafikGruplariHazirla(TL_ILAC('saglik_kapanma_gunu', 4)).azMetin, eski);
});

const yKapsam = (en, ad) => ({
  getLabelForValue: () => ad, chart: { width: en }, _resolveTickFontOptions: () => ({ string: '12px x' }),
  ctx: { font: '', save() {}, restore() {}, measureText: t => ({ width: t.length * 6 }) },
});

test('borc_u5_yazi_tipi_tik_indeksiyle_cozulur', () => {
  const cb = G.zarfGrafikConfig(coklu('saglik_basari'), { tema: TEMA }).options.scales.y.ticks.callback;
  const istenen = [];
  const kapsam = Object.assign(yKapsam(348, 'kısa'), { _resolveTickFontOptions: i => { istenen.push(i); return { string: '12px x' }; } });
  cb.call(kapsam, 7, 2);                                          // değer 7, indeks 2: Chart.js ticks[i] indeksle okur
  assert.deepStrictEqual(istenen, [2]);
});

test('borc_u5_uzun_ad_kesilmez_iki_satira_bolunur', () => {
  const cb = G.zarfGrafikConfig(coklu('saglik_basari'), { tema: TEMA }).options.scales.y.ticks.callback;
  const ad = 'CAROFERTIN-E ( alivira ) içeren';                    // 31 × 6 = 186 px; 348/2-14 = 160 px
  assert.deepStrictEqual([...cb.call(yKapsam(348, ad), 0)], ['CAROFERTIN-E (', 'alivira ) içeren']);
  assert.strictEqual(cb.call(yKapsam(798, ad), 0), ad, 'geniş tuvalde tek satır');
  assert.strictEqual(cb.call(yKapsam(348, 'X'.repeat(40)), 0), 'X'.repeat(40), 'boşluksuz ad bölünmez');
});
