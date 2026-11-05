'use strict';
// İstatistik Atölyesi AP1 Task 15 — pano: ızgara, kart, sırala, sil, yükleme yarışları.
// Tarayıcı yerine küçük bir ağaç DOM'u (parser + seçici); pano.js gerçek cumle.js, grafik.js, atolye.js ile yüklenir,
// yalnız RPC sarmalayıcıları, kurucuAc ve Chart stub'lanır. Satır içi onclick metni gerçekten çalıştırılır.
const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { extractFunctionSource } = require('./support/loadModule.js');

const KOK = path.join(__dirname, '..', '..');
const oku = rel => fs.readFileSync(path.join(KOK, rel), 'utf8');
const ENT = { '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'" };
const coz = s => String(s).replace(/&(amp|lt|gt|quot|#39);/g, m => ENT[m]);
const BOS_ETIKET = new Set(['br', 'img', 'input', 'hr']);

// ── Küçük DOM ──
class Dugum {
  constructor(tag, attrs = {}) { this.tag = tag; this.attrs = attrs; this.children = []; this.parent = null; this.metin = null; }
  get innerHTML() { return this.children.map(c => c.outerHTML).join(''); }
  set innerHTML(h) { this.children = cozumle(h); this.children.forEach(c => { c.parent = this; }); }
  get outerHTML() {
    if (this.metin !== null) return this.metin;
    const at = Object.entries(this.attrs).map(([k, v]) => (v === true ? ` ${k}` : ` ${k}="${v}"`)).join('');
    return BOS_ETIKET.has(this.tag) ? `<${this.tag}${at}>` : `<${this.tag}${at}>${this.innerHTML}</${this.tag}>`;
  }
  set outerHTML(h) {
    const yeni = cozumle(h);
    yeni.forEach(c => { c.parent = this.parent; });
    this.parent.children.splice(this.parent.children.indexOf(this), 1, ...yeni);
  }
  get textContent() { return this.metin !== null ? coz(this.metin) : this.children.map(c => c.textContent).join(''); }
  get dataset() {
    const d = {};
    for (const [k, v] of Object.entries(this.attrs)) {
      if (k.startsWith('data-')) d[k.slice(5).replace(/-(\w)/g, (_, c) => c.toUpperCase())] = coz(v);
    }
    return d;
  }
  get classList() {
    const liste = () => (this.attrs.class || '').split(/\s+/).filter(Boolean);
    return {
      contains: c => liste().includes(c),
      add: c => { if (!liste().includes(c)) this.attrs.class = [...liste(), c].join(' '); },
      remove: c => { this.attrs.class = liste().filter(x => x !== c).join(' '); },
      toggle: (c, f) => { if (f) { if (!liste().includes(c)) this.attrs.class = [...liste(), c].join(' '); } else this.attrs.class = liste().filter(x => x !== c).join(' '); },
    };
  }
  get disabled() { return 'disabled' in this.attrs; }
  set disabled(v) { if (v) this.attrs.disabled = true; else delete this.attrs.disabled; }
  addEventListener() {}
  scrollIntoView() {}
  contains(x) { for (let d = x; d; d = d.parent) if (d === this) return true; return false; }
  // Tarayıcı kuralı: pasif ya da ağaçtan kopmuş öğe odak alamaz (activeElement body'ye düşer).
  get bagli() { let d = this; while (d.parent) { if (!d.parent.children.includes(d)) return false; d = d.parent; } return d.attrs.id === 'atolye-icerik'; }
  focus() { if (!this.disabled && this.bagli) Dugum.odak = this; }
  getAttribute(k) { return k in this.attrs ? coz(this.attrs[k]) : null; }
  setAttribute(k, v) { this.attrs[k] = String(v); }
  remove() { this.parent.children.splice(this.parent.children.indexOf(this), 1); }
  insertAdjacentHTML(yer, h) {
    assert.strictEqual(yer, 'afterbegin');
    const yeni = cozumle(h);
    yeni.forEach(c => { c.parent = this; });
    this.children.unshift(...yeni);
  }
  uyar(sec) {
    return sec.split(',').some(s => {
      s = s.trim();
      if (s[0] === '.') return this.metin === null && this.classList.contains(s.slice(1));
      if (s[0] === '[') return this.metin === null && s.slice(1, -1) in this.attrs;
      const m = /^(\w+)\[([\w-]+)\]$/.exec(s);
      if (m) return this.tag === m[1] && m[2] in this.attrs;
      return this.tag === s;
    });
  }
  querySelectorAll(sec) {
    const c = [];
    const gez = d => d.children.forEach(k => { if (k.metin === null) { if (k.uyar(sec)) c.push(k); gez(k); } });
    gez(this);
    return c;
  }
  querySelector(sec) { return this.querySelectorAll(sec)[0] || null; }
  closest(sec) { let d = this; while (d) { if (d.metin === null && d.uyar(sec)) return d; d = d.parent; } return null; }
}
function cozumle(html) {
  const kok = new Dugum('kok');
  let ic = kok;
  const re = /<(\/?)([a-zA-Z0-9]+)((?:\s+[\w-]+(?:="[^"]*")?)*)\s*>|([^<]+)/g;
  let m;
  while ((m = re.exec(html))) {
    if (m[4] !== undefined) {
      const t = new Dugum('#metin'); t.metin = m[4]; t.parent = ic; ic.children.push(t);
    } else if (m[1]) {
      assert.strictEqual(ic.tag, m[2], 'kapanış etiketi uyuşmuyor: ' + m[2]);
      ic = ic.parent;
    } else {
      const a = {};
      for (const x of m[3].matchAll(/([\w-]+)(?:="([^"]*)")?/g)) a[x[1]] = x[2] === undefined ? true : x[2];
      const d = new Dugum(m[2], a); d.parent = ic; ic.children.push(d);
      if (!BOS_ETIKET.has(m[2])) ic = d;
    }
  }
  assert.strictEqual(ic, kok, 'kapanmamış etiket: ' + ic.tag);
  kok.children.forEach(c => { c.parent = null; });
  return kok.children;
}

// ── Fikstür ──
const CUMLE = () => ({ v: 1, alan: 'saglik', hastalik: { tip: 'kategori', deger: 'Meme' },
  ilac: { duzey: 'etken', x: null, y: null }, kiyas_grubu: 'tumu', olculer: ['saglik_basari', 'saglik_kapanma_gunu'],
  kirilim: 'yok', donem: { tip: 'son_ay', n: 12 }, kiyas_duzeyi: ['biz'] });
const KAYIT = (id, ek = {}) => ({ id, baslik: 'Grafik ' + id, cumle: CUMLE(), cumle_surum: 1, sira: 1, guncelleme_at: '2026-10-31T09:00:00Z', ...ek });
const Z_BASARI = (ek = {}) => ({ olcum: 'saglik_basari', hesap_at: '2026-10-31T09:00:00Z', n: 12,
  x: { ad: 'grup', deger: ['Tüm vakalar'], anahtar: ['t'] },
  seriler: [{ ad: 'başarı %', n: [12], k: [9], y: [75], alt: [50], ust: [90] }],
  sayac: { fiyatsiz_n: 0, kiyas_n: null }, dipnot: ['2 vaka 24 saat içinde yeniden açıldı (tedavi değişti).'], ...ek });
const Z_HIZ = (ek = {}) => ({ olcum: 'saglik_kapanma_gunu', hesap_at: '2026-10-31T09:00:00Z', n: 8,
  x: { ad: 'grup', deger: ['Tüm vakalar'], anahtar: ['t'] },
  seriler: [{ ad: 'gün', n: [8], y: [6.5], q1: [4], q3: [9] }], sayac: { kiyas_n: null }, dipnot: [], ...ek });
const Z_TL_FIYATSIZ = () => ({ olcum: 'saglik_vaka_tl', hesap_at: '2026-10-31T09:00:00Z', n: 0,
  x: { ad: 'grup', deger: ['Tüm vakalar'], anahtar: ['t'] }, seriler: [{ ad: '₺', n: [0], y: [null], q1: [null], q3: [null] }],
  sayac: { fiyatsiz_n: 7, kiyas_n: null }, dipnot: ['7 vakanın ilaç fiyatı yok.'], fiyat_kaynagi: 'fiyatsiz' });
const VERI = () => ({ zarflar: [Z_BASARI(), Z_HIZ()], kombinasyon: null, fiyat_eksik: [] });

const GOVDE = {};
function kur(ek = {}) {
  Dugum.odak = null;
  const icerik = new Dugum('div', { id: 'atolye-icerik' });
  icerik.innerHTML = '<div class="loader"><div class="spin"></div></div>';
  const cagri = { seri: [], sil: [], sirala: [], secenek: [], kurucu: [], chart: [], liste: 0 };
  let chartId = 0;
  class Chart {
    constructor(canvas, config) { this.canvas = canvas; this.config = config; this.yok = false; this.id = (chartId += 1); Chart.instances[this.id] = this; cagri.chart.push(this); }
    destroy() { this.yok = true; delete Chart.instances[this.id]; }
  }
  Chart.instances = {};   // Chart.js'te olduğu gibi: canlı örnekler, destroy siler
  const c = {
    console, Date, Intl, String, Number, Object, Array, JSON, Promise, Error, Math, Set,
    navigator: { onLine: true }, Chart,
    esc: s => String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'),
    window: { _atolye: { sekme: 'pano', cumle: null, secenekler: null, gecici: { ilac_fiyat: { s: 9 } }, sonZarflar: null, onceki: [], jeton: 0 } },
    getComputedStyle: () => ({ getPropertyValue: () => 'var' }),
    document: { body: GOVDE, get activeElement() { return Dugum.odak && Dugum.odak.bagli ? Dugum.odak : GOVDE; }, documentElement: {}, querySelectorAll: () => [], getElementById: id => {
      if (id === 'atolye-icerik' || id === 'istatistik-root') return icerik;
      const ara = d => { for (const k of d.children) { if (k.metin === null) { if (k.attrs.id === id) return k; const b = ara(k); if (b) return b; } } return null; };
      return ara(icerik);
    } },
    statOlcumListele: async () => [],
    statGrafikListele: async () => { cagri.liste += 1; return ek.liste ? ek.liste() : [KAYIT('a'), KAYIT('b')]; },
    statAtolyeSeri: async (...a) => { cagri.seri.push(a); return ek.seri ? ek.seri(...a) : VERI(); },
    statAtolyeSecenekler: async cumle => { cagri.secenek.push(cumle); return ek.secenek ? ek.secenek(cumle) : { hastaliklar: [] }; },
    statGrafikSil: async id => { cagri.sil.push(id); if (ek.sil) return ek.sil(id); return null; },
    statGrafikSirala: async idler => { cagri.sirala.push(idler); if (ek.sirala) return ek.sirala(idler); return null; },
    kurucuAc: cumle => { cagri.kurucu.push(cumle); },
  };
  vm.createContext(c);
  // extractFunctionSource escAttr'daki tırnak regex'lerini dengesiz sayar; satır başı "}" ile kesilir
  vm.runInContext(oku('js/utils/helpers.js').match(/^function escAttr[\s\S]*?^}/m)[0], c);
  vm.runInContext(extractFunctionSource('js/api.js', 'statHataKodu'), c);
  // kurucu.js gerçek: pano n<5 satırını onun yardımcısından alır (index.html sırası); kurucuAc stub'ı aşağıda geri yazılır
  ['js/istatistik/cumle.js', 'js/istatistik/grafik.js', 'js/istatistik/kurucu.js', 'js/istatistik/atolye.js', 'js/istatistik/pano.js']
    .forEach(f => vm.runInContext(oku(f), c, { filename: f }));
  if (ek.kurucuGercek) {   // pano↔kurucu geçişi uçtan uca: kardeş modüller boş
    Object.assign(c, { kombinasyonHtml: () => '', kombinasyonBagla: () => {}, geciciFiyatPanelHtml: () => '', geciciFiyatBagla: () => {},
      _statInvalidate: () => {}, tarihIsoTr: s => s, bugun: () => '2026-10-31', toast: () => {} });
  } else c.kurucuAc = cumle => { cagri.kurucu.push(cumle); };
  return { c, icerik, cagri };
}
const duz = o => JSON.parse(JSON.stringify(o));
const nefes = async () => { for (let i = 0; i < 6; i += 1) await new Promise(setImmediate); };
function tikla(c, el) {
  assert.ok(el, 'tıklanacak öğe yok');
  c.__bu = el;
  return vm.runInContext(`(function(){ return ${el.getAttribute('onclick')} }).call(__bu)`, c);
}
const dugme = (kok, metin) => kok.querySelectorAll('button').find(b => b.textContent.trim() === metin);
const kartlar = i => i.querySelectorAll('[data-grafik-id]');
const kart = (i, id) => kartlar(i).find(k => k.dataset.grafikId === id);
const sira = i => kartlar(i).map(k => k.dataset.grafikId);
const kokSar = html => { const d = new Dugum('div'); d.innerHTML = html; return d; };

// ── Step 1 (plan Task 15): 10 test ──
test('tasi_yukari', () => {
  const { c } = kur();
  assert.deepStrictEqual(duz(c.panoTasi(['a', 'b', 'c'], 'b', -1)), ['b', 'a', 'c']);
  assert.deepStrictEqual(duz(c.panoTasi(['a', 'b', 'c'], 'b', 1)), ['a', 'c', 'b']);
  const girdi = ['a', 'b'];
  c.panoTasi(girdi, 'b', -1);
  assert.deepStrictEqual(girdi, ['a', 'b'], 'saf: girdi değişmez');
});

test('tasi_ilk_yukari_degismez', () => {
  const { c } = kur();
  assert.deepStrictEqual(duz(c.panoTasi(['a', 'b'], 'a', -1)), ['a', 'b']);
  assert.deepStrictEqual(duz(c.panoTasi(['a', 'b'], 'yok', -1)), ['a', 'b'], 'bilinmeyen id');
});

test('tasi_son_asagi_degismez', () => {
  const { c } = kur();
  assert.deepStrictEqual(duz(c.panoTasi(['a', 'b'], 'b', 1)), ['a', 'b']);
});

test('kart_eski_surum', async () => {
  const { c, icerik, cagri } = kur({ liste: () => [KAYIT('e', { cumle_surum: 2, cumle: { v: 2, garip: true } })] });
  await c.panoYukle();
  await nefes();
  const k = kart(icerik, 'e');
  assert.ok(k.textContent.includes('Bu grafik eski sürümle kaydedildi, yeniden kur.'));
  assert.strictEqual(k.querySelector('canvas'), null);
  assert.deepStrictEqual(cagri.seri, [], 'eski sürümde RPC çağrılmaz');
  assert.ok(dugme(k, 'Sil'), 'silinmez: Sil elle kalır');
  assert.deepStrictEqual(cagri.sil, []);
  // kurucuya sürümü bilinmeyen cümle taşınmaz
  tikla(c, dugme(k, 'Kurucuda aç'));
  assert.strictEqual(c.window._atolye.cumle, null);
  assert.strictEqual(c.window._atolye.sekme, 'kurucu');
});

test('kart_fiyatsiz_kurucuda_fiyat_gir', () => {   // E13-fiyat-girilmedi: "— hesapla" düz yazıydı, hesaplatmıyordu
  const { c } = kur();
  const k = KAYIT('f');
  k.cumle.olculer = ['saglik_vaka_tl'];
  const d = kokSar(c.panoKartHtml(k, [Z_TL_FIYATSIZ()], null));
  assert.ok(d.textContent.includes('Fiyat girilmedi'));
  assert.ok(!d.textContent.includes('— hesapla'), 'eylem gibi okunan düz yazı kalmaz');
  assert.ok(dugme(d, 'Kurucuda fiyat gir'));
  assert.ok(dugme(d, 'Kurucuda aç'));
  assert.strictEqual(d.querySelector('canvas'), null);
  assert.ok(!d.textContent.includes('yetersiz veri'), 'fiyatsızda özet "yetersiz (n=0)" demez');
});

test('kart_ilk_olcu_canvas', async () => {
  const { c, icerik, cagri } = kur({ liste: () => [KAYIT('a')] });
  await c.panoYukle();
  await nefes();
  const k = kart(icerik, 'a');
  assert.strictEqual(k.querySelectorAll('canvas').length, 1, 'kart başına tek canvas (P10)');
  assert.ok(k.querySelector('.atolye-grafik').querySelector('canvas'));
  assert.strictEqual(cagri.chart.length, 1);
  assert.strictEqual(cagri.chart[0].config.ozet, c.zarfOzetCumle(Z_BASARI()), 'ilk ölçünün grafiği');
  assert.ok(k.textContent.includes('Medyan kapanma'), 'diğer ölçü özet satırında');
  assert.ok(k.textContent.includes('Başarı'), 'ilk ölçünün görünür özeti (spec §4.6)');
  assert.ok(k.textContent.includes('Hesap tarihi: 31.10.2026 12:00'));
  assert.ok(k.textContent.includes('n=12'));
  assert.ok(k.textContent.includes('Meme vakalarında'), 'cümle küçük satırda');
  // zarf sırası cümleden farklı gelse de ilk ölçü cümleden okunur
  const h = c.panoKartHtml(KAYIT('a'), [Z_HIZ(), Z_BASARI()], null);
  assert.ok(kokSar(h).querySelector('.atolye-ozet').textContent.startsWith('Başarı'));
});

// Kapı F3 Ö1: 3+ gruplu kartta y=null grup boş sıra %0 gibi okunmasın; metin kurucuyla aynı yardımcıdan.
const Z_COK_GRUP = () => Z_BASARI({ n: 40, x: { ad: 'grup', deger: ['A içeren', 'B içeren', 'C içeren'], anahtar: ['a', 'b', 'c'] },
  seriler: [{ ad: 'başarı %', n: [30, 3, 7], k: [24, 2, 5], y: [80, null, 71.4], alt: [60, null, 30], ust: [90, null, 90] }] });

test('kart_yetersiz_grup_metinle', () => {
  const { c } = kur();
  const z = Z_COK_GRUP();
  const k = KAYIT('g');
  k.cumle.olculer = ['saglik_basari'];
  const d = kokSar(c.panoKartHtml(k, [z], null));
  assert.ok(d.querySelector('canvas'), 'grafik yine çizilir');
  assert.ok(d.textContent.includes('B içeren yetersiz (n=3)'), 'n<5 grup metinle ayrılır');
  assert.ok(!d.textContent.includes('A içeren yetersiz'), 'yeterli grup yazılmaz');
  assert.ok(c.panoKartHtml(k, [z], null).includes(c._kurucuYetersizSatir(z)), 'kurucuyla birebir aynı satır');
});

test('kart_yetersiz_grup_yoksa_satir_yok', () => {
  const { c } = kur();
  const d = kokSar(c.panoKartHtml(KAYIT('g'), [Z_BASARI()], null));
  assert.ok(!d.textContent.includes('yetersiz (n='));
});

test('kart_kacis', () => {
  const { c } = kur();
  const k = KAYIT('i"d\'<x>', { baslik: '<img src=x onerror=alert(1)>' });
  k.cumle.hastalik = { tip: 'kategori', deger: '<img id=kat>' };
  const z = Z_BASARI({ dipnot: ['<img id=dip>'], x: { ad: 'grup', deger: ['<img id=grup>'], anahtar: ['t'] } });
  const z2 = Z_HIZ({ x: { ad: 'grup', deger: ['<img id=grup2>'], anahtar: ['t'] } });
  const d = kokSar(c.panoKartHtml(k, [z, z2], null));
  assert.strictEqual(d.querySelector('img'), null, 'DB değerinden öğe doğmaz');
  assert.ok(d.textContent.includes('<img src=x onerror=alert(1)>'));
  assert.ok(d.textContent.includes('<img id=kat>') && d.textContent.includes('<img id=dip>') && d.textContent.includes('<img id=grup>') && d.textContent.includes('<img id=grup2>'));
  assert.strictEqual(d.querySelector('[data-grafik-id]').dataset.grafikId, 'i"d\'<x>', 'id öznitelikte kaçışlı');
  d.querySelectorAll('[onclick]').forEach(b => assert.ok(!b.getAttribute('onclick').includes('i"d'), 'onclick DB değeri taşımaz'));
});

test('bos_durum', async () => {
  const { c, icerik, cagri } = kur({ liste: () => [] });
  await c.panoYukle();
  assert.ok(icerik.querySelector('.atolye-bos').textContent.includes('Henüz kaydedilmiş grafik yok.'));
  assert.strictEqual(icerik.querySelector('.atolye-pano'), null);
  assert.strictEqual(icerik.querySelector('.loader'), null);
  tikla(c, dugme(icerik, '+ Yeni grafik kur'));
  assert.strictEqual(c.window._atolye.sekme, 'kurucu');
  assert.strictEqual(cagri.kurucu.length, 1);
});

test('seri_gecicisiz_cagri', async () => {
  const { c, cagri } = kur();
  await c.panoYukle();
  await nefes();
  assert.strictEqual(cagri.seri.length, 2);
  cagri.seri.forEach(a => {
    assert.strictEqual(a.length, 2, 'yalnız cümle + {}');
    assert.deepStrictEqual(duz(a[1]), {}, '2. argüman {} (_atolye.gecici taşınmaz)');
  });
});

test('sil_onay_satir_ici', async () => {
  const { c, icerik, cagri } = kur();
  await c.panoYukle();
  await nefes();
  let k = kart(icerik, 'a');
  tikla(c, dugme(k, 'Sil'));
  assert.ok(k.querySelector('.atolye-sil-onay').textContent.includes('Emin misiniz?'));
  assert.deepStrictEqual(cagri.sil, [], 'onaysız silmez');
  assert.strictEqual(k.querySelectorAll('canvas').length, 1, 'grafik yerinde kalır');
  tikla(c, dugme(k, 'Vazgeç'));
  assert.strictEqual(k.querySelector('.atolye-sil-onay'), null);
  assert.deepStrictEqual(cagri.sil, []);
  tikla(c, dugme(k, 'Sil'));
  await tikla(c, dugme(k.querySelector('.atolye-sil-onay'), 'Sil'));
  assert.deepStrictEqual(cagri.sil, ['a']);
  assert.deepStrictEqual(sira(icerik), ['b']);
  assert.ok(!/\bconfirm\(/.test(oku('js/istatistik/pano.js')), 'confirm( yok');
  // son kart da silinince boş durum
  k = kart(icerik, 'b');
  tikla(c, dugme(k, 'Sil'));
  await tikla(c, dugme(k.querySelector('.atolye-sil-onay'), 'Sil'));
  assert.ok(icerik.querySelector('.atolye-bos'));
});

// ── Ek testler ──
test('sirala_modu_tutamak_ve_tam_dizi', async () => {
  const { c, icerik, cagri } = kur({ liste: () => [KAYIT('a'), KAYIT('b'), KAYIT('c')] });
  await c.panoYukle();
  await nefes();
  assert.strictEqual(icerik.querySelector('.atolye-tutamak'), null, 'mod kapalıyken tutamak yok');
  tikla(c, dugme(icerik, 'Sırala'));
  assert.strictEqual(icerik.querySelectorAll('.atolye-tutamak').length, 3);
  assert.ok(kart(icerik, 'a').querySelector('.atolye-tutamak').textContent.includes('⋮⋮'));
  assert.deepStrictEqual(cagri.seri.length, 3, 'mod açmak yeniden RPC çağırmaz');
  const once = cagri.chart.length;
  await tikla(c, dugme(kart(icerik, 'b'), '▲'));
  assert.deepStrictEqual(duz(cagri.sirala), [['b', 'a', 'c']], 'çiftliğin tam dizisi');
  assert.deepStrictEqual(sira(icerik), ['b', 'a', 'c']);
  assert.ok(cagri.chart.slice(0, once).every(g => g.yok), 'eski Chart örnekleri destroy');
  assert.strictEqual(cagri.chart.filter(g => !g.yok).length, 3, 'taşımadan sonra her kart yeniden çizili');
  // ilk kart yukarı: RPC yok
  await tikla(c, dugme(kart(icerik, 'b'), '▲'));
  assert.strictEqual(cagri.sirala.length, 1);
  assert.strictEqual(icerik.querySelectorAll('.atolye-tutamak').length, 3, 'mod açık kalır');
  tikla(c, dugme(icerik, 'Sıralamayı bitir'));
  assert.strictEqual(icerik.querySelector('.atolye-tutamak'), null);
});

test('sirala_hata_eski_sira_serit', async () => {
  const { c, icerik, cagri } = kur({ sirala: () => { throw new Error('boom'); } });
  await c.panoYukle();
  await nefes();
  c.panoSiralaModu(true);
  await tikla(c, dugme(kart(icerik, 'b'), '▲'));
  assert.deepStrictEqual(sira(icerik), ['a', 'b'], 'eski sıra');
  assert.ok(icerik.querySelector('.atolye-hata').textContent.includes('boom'));
  assert.strictEqual(cagri.liste, 1, 'genel hatada liste yeniden çekilmez');
});

test('sirala_grafik_hatasi_okunur_liste_yenilenir', async () => {
  const { c, icerik, cagri } = kur({ sirala: () => { throw new Error('STAT_GRAFIK:sira_kumesi'); } });
  await c.panoYukle();
  await nefes();
  c.panoSiralaModu(true);
  await tikla(c, dugme(kart(icerik, 'b'), '▲'));
  await nefes();
  const m = icerik.querySelector('.atolye-hata').textContent;
  assert.ok(m.includes('liste yenilendi') && !m.includes('STAT_GRAFIK'), 'ham kod görünmez: ' + m);
  assert.strictEqual(cagri.liste, 2);
});

test('sirala_ucusta_ikinci_tik_yok', async () => {
  let ac;
  const { c, icerik, cagri } = kur({ sirala: () => new Promise(r => { ac = r; }) });
  await c.panoYukle();
  await nefes();
  c.panoSiralaModu(true);
  const p = tikla(c, dugme(kart(icerik, 'b'), '▲'));
  tikla(c, dugme(kart(icerik, 'a'), '▲'));   // await yok: kilit kırılırsa bu çağrı askıda kalır, assert yakalar
  tikla(c, dugme(kart(icerik, 'a'), 'Sil'));
  tikla(c, dugme(kart(icerik, 'a').querySelector('.atolye-sil-onay'), 'Sil'));
  await nefes();
  assert.strictEqual(cagri.sirala.length, 1, 'uçuştayken ikinci taşıma yok');
  assert.deepStrictEqual(cagri.sil, [], 'uçuştayken silme yok');
  ac();
  await p;
  assert.deepStrictEqual(sira(icerik), ['b', 'a']);
});

test('yazma_basarisi_seridi_temizler', async () => {
  let patla = true;
  const { c, icerik } = kur({ sirala: () => { if (patla) throw new Error('boom'); return null; }, sil: () => null });
  await c.panoYukle();
  await nefes();
  c.panoSiralaModu(true);
  await tikla(c, dugme(kart(icerik, 'b'), '▲'));
  assert.ok(icerik.querySelector('.atolye-hata'));
  patla = false;
  await tikla(c, dugme(kart(icerik, 'b'), '▲'));
  assert.strictEqual(icerik.querySelector('.atolye-hata'), null, 'sırala başarısı');
  patla = true;
  await tikla(c, dugme(kart(icerik, 'b'), '▼'));
  assert.ok(icerik.querySelector('.atolye-hata'));
  const k = kart(icerik, 'a');
  tikla(c, dugme(k, 'Sil'));
  await tikla(c, dugme(k.querySelector('.atolye-sil-onay'), 'Sil'));
  assert.strictEqual(icerik.querySelector('.atolye-hata'), null, 'sil başarısı');
  assert.strictEqual(icerik.querySelector('.atolye-tutamak'), null, 'tek kartta tutamak yok');
  assert.strictEqual(dugme(icerik, 'Sırala'), undefined);
});

test('kart_hatasi_digerini_durdurmaz', async () => {
  const { c, icerik, cagri } = kur({ seri: cumle => {
    if (cagri.seri.length === 1) throw new Error('hesap patladı');
    return VERI();
  } });
  await c.panoYukle();
  await nefes();
  assert.strictEqual(cagri.seri.length, 2);
  assert.ok(kart(icerik, 'a').textContent.includes('Bu grafik hesaplanamadı.'));
  assert.strictEqual(kart(icerik, 'a').querySelector('canvas'), null);
  assert.strictEqual(kart(icerik, 'b').querySelectorAll('canvas').length, 1);
  assert.ok(icerik.querySelector('.atolye-hata').textContent.includes('hesap patladı'));
});

test('sirayla_yukler_ve_yukleniyor_gosterir', async () => {
  const bekle = [];
  const { c, icerik, cagri } = kur({ seri: () => new Promise(r => bekle.push(r)) });
  const p = c.panoYukle();
  await nefes();
  assert.strictEqual(cagri.seri.length, 1, 'ikinci kart birinci bitmeden başlamaz');
  assert.ok(kart(icerik, 'a').querySelector('.loader') && kart(icerik, 'b').querySelector('.loader'));
  bekle[0](VERI());
  await nefes();
  assert.strictEqual(cagri.seri.length, 2);
  assert.ok(kart(icerik, 'a').querySelector('canvas') && kart(icerik, 'b').querySelector('.loader'));
  bekle[1](VERI());
  await p;
});

test('sekme_degisince_gec_yanit_yazilmaz', async () => {
  const bekle = [];
  const { c, icerik, cagri } = kur({ seri: () => new Promise(r => bekle.push(r)) });
  const p = c.panoYukle();
  await nefes();
  c.atolyeSekme('kurucu');
  icerik.innerHTML = '<div id="kurucu-ici">K</div>';
  bekle[0](VERI());
  await p;
  assert.strictEqual(icerik.innerHTML, '<div id="kurucu-ici">K</div>');
  assert.strictEqual(cagri.seri.length, 1, 'kalan kartlar yüklenmez');
  assert.strictEqual(cagri.chart.length, 0);
});

test('yeni_yukleme_eskisini_iptal_eder', async () => {
  const bekle = [];
  const { c, icerik, cagri } = kur({ seri: () => new Promise(r => bekle.push(r)) });
  const p1 = c.panoYukle();
  await nefes();
  const p2 = c.panoYukle();
  await nefes();
  bekle[0](VERI());   // eski koşunun yanıtı
  await nefes();
  assert.strictEqual(cagri.seri.length, 2, 'eski koşu 2. karta geçmez');
  await p1;
  assert.strictEqual(cagri.chart.length, 0, 'eski koşunun yanıtı yeni kartlara yazılmaz');
  assert.ok(kart(icerik, 'a').querySelector('.loader'));
  bekle[1](VERI());
  await nefes();
  bekle[2](VERI());
  await p2;
  assert.strictEqual(cagri.chart.length, 2);
});

test('serit_korunur_loadIstatistik_kalibi', async () => {
  const { c, icerik } = kur();
  c.statOlcumListele = async () => { throw new Error('olcum kaynağı yok'); };
  await c.loadIstatistik();
  await nefes();
  assert.ok(icerik.querySelector('.atolye-hata').textContent.includes('olcum kaynağı yok'), 'şerit ızgara çizimini geçer');
  assert.strictEqual(kartlar(icerik).length, 2);
  // kart yeniden çizimi ve mod değişimi de şeridi silmez
  c.panoSiralaModu(true);
  assert.ok(icerik.querySelector('.atolye-hata'));
  assert.strictEqual(icerik.querySelectorAll('.atolye-hata').length, 1);
});

test('liste_hatasi_durum_ve_serit', async () => {
  const { c, icerik } = kur({ liste: () => { throw new Error('İnternet bağlantısı gerekli'); } });
  await c.panoYukle();
  assert.strictEqual(icerik.querySelector('.loader'), null, 'çarkta kalmaz');
  assert.ok(icerik.querySelector('.atolye-durum').textContent.includes('Kayıtlı grafikler alınamadı.'));
  assert.ok(icerik.querySelector('.atolye-hata').textContent.includes('İstatistik çevrimiçi hesaplanır'));
});

test('liste_beklerken_sirala_bos_durum_yazmaz', async () => {   // review T15 tur1 B1
  let bekleyen = null;
  const { c, icerik } = kur({ liste: () => (bekleyen ? new Promise((ok, red) => { bekleyen.ok = ok; bekleyen.red = red; }) : [KAYIT('a'), KAYIT('b')]) });
  await c.panoYukle();
  await nefes();
  bekleyen = {};
  const p = c.panoYukle();
  await nefes();
  tikla(c, dugme(icerik, 'Sırala'));
  assert.strictEqual(icerik.querySelector('.atolye-bos'), null, 'yanlış boş durum yok');
  assert.strictEqual(icerik.querySelectorAll('.atolye-tutamak').length, 2);
  assert.strictEqual(kart(icerik, 'a').querySelectorAll('canvas').length, 1, 'çizili grafik yerinde');
  bekleyen.red(new Error('İnternet bağlantısı gerekli'));
  await p;
  assert.strictEqual(icerik.querySelector('.atolye-bos'), null, 'liste hatası da boş durum bırakmaz');
  assert.strictEqual(kartlar(icerik).length, 2);
  assert.ok(icerik.querySelector('.atolye-bayat-etiket'), 'bayat etiketi çıkar');
  assert.ok(kart(icerik, 'a').querySelector('canvas'));
});

test('ilk_yukleme_sirasinda_sirala_carki_silmez', async () => {
  let ac;
  const { c, icerik } = kur({ liste: () => new Promise(r => { ac = r; }) });
  const p = c.panoYukle();
  await nefes();
  c.panoSiralaModu(true);
  assert.ok(icerik.querySelector('.loader'), 'boş listede ızgara yazılmaz');
  assert.strictEqual(icerik.querySelector('.atolye-bos'), null);
  ac([KAYIT('a')]);
  await p;
  assert.ok(kart(icerik, 'a').querySelector('canvas'));
});

test('liste_beklerken_yazma_yok_sonra_calisir', async () => {
  let bekleyen = null;
  const { c, icerik, cagri } = kur({ liste: () => (bekleyen ? new Promise((ok, red) => { bekleyen.ok = ok; bekleyen.red = red; }) : [KAYIT('a'), KAYIT('b')]) });
  await c.panoYukle();
  await nefes();
  c.panoSiralaModu(true);
  bekleyen = {};
  const p = c.panoYukle();
  await nefes();
  await tikla(c, dugme(kart(icerik, 'b'), '▲'));
  assert.deepStrictEqual(cagri.sirala, [], 'liste yanıtı gelmeden sıra yazılmaz');
  bekleyen.red(new Error('boom'));
  await p;
  await tikla(c, dugme(kart(icerik, 'b'), '▲'));
  assert.deepStrictEqual(duz(cagri.sirala), [['b', 'a']], 'hatadan sonra kilit açık');
});

test('yukleme_ortasi_ikinci_kosu_liste_hatasi', async () => {   // review T15 tur1 B2 (a)
  const bekle = [];
  let kes = false;
  const { c, icerik, cagri } = kur({
    liste: () => { if (kes) throw new Error('boom'); return [KAYIT('a'), KAYIT('b'), KAYIT('c')]; },
    seri: (...a) => (a.length === 3 ? VERI() : new Promise(r => bekle.push(r))),
  });
  const p1 = c.panoYukle();
  await nefes();
  bekle[0](VERI());
  await nefes();
  assert.ok(kart(icerik, 'a').querySelector('canvas') && kart(icerik, 'b').querySelector('.loader'));
  kes = true;
  await c.panoYukle();
  assert.strictEqual(icerik.querySelector('.loader'), null, 'çark kalmaz');
  assert.ok(kart(icerik, 'a').querySelector('canvas'), 'çizili kart kalır');
  assert.ok(kart(icerik, 'c').textContent.includes('Bu grafik hesaplanamadı.'));
  assert.ok(icerik.querySelector('.atolye-hata').textContent.includes('boom'));
  await tikla(c, dugme(kart(icerik, 'c'), 'Yeniden hesapla'));
  assert.ok(kart(icerik, 'c').querySelector('canvas'), 'kart üzerinden çıkış var');
  tikla(c, dugme(kart(icerik, 'c'), 'Sil'));
  assert.ok(kart(icerik, 'c').querySelector('.atolye-sil-onay'), 'Sil çalışır');
  // eski koşunun geç yanıtı çizmez, sonraki karta geçmez
  const n = cagri.seri.length;
  bekle[1](VERI());
  await p1;
  assert.strictEqual(cagri.seri.length, n);
  assert.strictEqual(kart(icerik, 'b').querySelector('canvas'), null);
});

test('yukleme_ortasi_liste_hatasi_cevrimdisi_metni', async () => {
  const bekle = [];
  let kes = false;
  const { c, icerik } = kur({
    liste: () => { if (kes) throw new Error('İnternet bağlantısı gerekli'); return [KAYIT('a')]; },
    seri: () => new Promise(r => bekle.push(r)),
  });
  const p1 = c.panoYukle();
  await nefes();
  kes = true;
  await c.panoYukle();
  assert.strictEqual(icerik.querySelector('.loader'), null);
  assert.ok(kart(icerik, 'a').querySelector('.atolye-durum').textContent.includes('İstatistik çevrimiçi hesaplanır'));
  bekle[0](VERI());
  await p1;
});

test('ust_uste_iki_kosu_son_liste_hatasi', async () => {   // review T15 tur1 B2 (b)
  const bekleyen = [];
  let ilk = true;
  const { c, icerik } = kur({ liste: () => {
    if (ilk) { ilk = false; return [KAYIT('a'), KAYIT('b')]; }
    return new Promise((ok, red) => bekleyen.push({ ok, red }));
  } });
  await c.panoYukle();
  await nefes();
  const p2 = c.panoYukle();
  await nefes();
  const p3 = c.panoYukle();
  await nefes();
  bekleyen[1].red(new Error('boom'));
  await p3;
  assert.strictEqual(kartlar(icerik).length, 2);
  tikla(c, dugme(kart(icerik, 'a'), 'Sil'));
  assert.ok(kart(icerik, 'a').querySelector('.atolye-sil-onay'), 'düğme ölü değil');
  tikla(c, dugme(kart(icerik, 'a'), 'Vazgeç'));
  tikla(c, dugme(kart(icerik, 'a'), 'Kurucuda aç'));
  assert.strictEqual(c.window._atolye.sekme, 'kurucu');
  bekleyen[0].ok([]);   // ortadaki koşunun geç yanıtı ekrana yazılmaz
  await p2;
  assert.strictEqual(icerik.querySelector('.atolye-bos'), null);
});

// review T15 tur2 B3: Sil uçuştayken kurulan yeni koşu `kartlar`ı paylaşır; başarı yolu oradan siler.
function silUcustaKur(listeIlk = () => [KAYIT('a'), KAYIT('b')], ek = {}) {
  const b = { sil: null, liste: null, ikinci: false };
  const k = kur({
    sil: () => new Promise((ok, red) => { b.sil = { ok, red }; }),
    liste: () => (b.ikinci ? new Promise((ok, red) => { b.liste = { ok, red }; }) : listeIlk()),
    ...ek,
  });
  return { ...k, b };
}
async function silUcustaBaslat({ c, icerik, b }) {
  await c.panoYukle();
  await nefes();
  tikla(c, dugme(kart(icerik, 'a'), 'Sil'));
  const silP = tikla(c, dugme(kart(icerik, 'a').querySelector('.atolye-sil-onay'), 'Sil'));
  await nefes();
  b.ikinci = true;
  const yukleP = c.panoYukle();
  await nefes();
  return { silP, yukleP };
}

test('sil_ucusta_yeni_kosu_liste_hatasi', async () => {
  const k = silUcustaKur();
  const { icerik, b } = k;
  const { silP, yukleP } = await silUcustaBaslat(k);
  b.sil.ok(null);
  await silP;
  b.liste.red(new Error('boom'));
  await yukleP;   // TypeError olsaydı burada reddedilirdi
  assert.ok(icerik.querySelector('.atolye-hata').textContent.includes('boom'), 'şerit basılır');
  assert.deepStrictEqual(sira(icerik), ['b'], 'silinen kart yok');
  assert.ok(kart(icerik, 'b').querySelector('canvas'), 'kalan kart çizili');
});

test('sil_ucusta_yeni_kosu_sirala_modu', async () => {
  const k = silUcustaKur(() => [KAYIT('a'), KAYIT('b'), KAYIT('c')]);
  const { c, icerik, b } = k;
  const { silP, yukleP } = await silUcustaBaslat(k);
  b.sil.ok(null);
  await silP;
  c.panoSiralaModu(true);   // TypeError olsaydı burada atardı
  assert.deepStrictEqual(sira(icerik), ['b', 'c'], 'silinen kart yok');
  assert.strictEqual(icerik.querySelectorAll('.atolye-tutamak').length, 2);
  b.liste.red(new Error('boom'));
  await yukleP;
  assert.deepStrictEqual(sira(icerik), ['b', 'c']);
  assert.ok(icerik.querySelector('.atolye-hata').textContent.includes('boom'));
});

test('sil_ucusta_silinen_kart_aninda_duser', async () => {
  const k = silUcustaKur();
  const { c, icerik, b } = k;
  const { silP, yukleP } = await silUcustaBaslat(k);
  const eskiDugme = dugme(kart(icerik, 'a'), 'Vazgeç');
  b.sil.ok(null);
  await silP;
  assert.deepStrictEqual(sira(icerik), ['b'], 'liste yanıtını beklemez');
  tikla(c, eskiDugme);   // kopuk düğme: _panoHedef kaydı bulamaz, TypeError yok
  b.liste.ok([KAYIT('b')]);
  await yukleP;
  await nefes();
  assert.deepStrictEqual(sira(icerik), ['b']);
  assert.ok(kart(icerik, 'b').querySelector('canvas'));
});

test('sil_ucusta_son_kart_bos_durum_serit', async () => {
  const k = silUcustaKur(() => [KAYIT('a')]);
  const { icerik, b } = k;
  const { silP, yukleP } = await silUcustaBaslat(k);
  b.sil.ok(null);
  await silP;
  b.liste.red(new Error('boom'));
  await yukleP;
  assert.strictEqual(kartlar(icerik).length, 0);
  assert.ok(icerik.querySelector('.atolye-bos'), 'son kart silindi: boş durum');
  assert.ok(icerik.querySelector('.atolye-hata').textContent.includes('boom'));
});

test('sil_ucusta_once_liste_hatasi_sonra_sil_cozulur', async () => {
  const k = silUcustaKur();
  const { icerik, b } = k;
  const { silP, yukleP } = await silUcustaBaslat(k);
  b.liste.red(new Error('boom'));
  await yukleP;
  assert.deepStrictEqual(sira(icerik), ['a', 'b'], 'Sil henüz sonuçlanmadı');
  b.sil.ok(null);
  await silP;
  assert.deepStrictEqual(sira(icerik), ['b'], 'sonuç ekrana yansır');
  assert.ok(icerik.querySelector('.atolye-hata').textContent.includes('boom'), 'liste şeridi silinmez');
});

test('sil_ucusta_sirala_hatasi_eski_dizi_silineni_dondurmez', async () => {
  let siralaRed;
  const k = silUcustaKur(() => [KAYIT('a'), KAYIT('b')], { sirala: () => new Promise((_, red) => { siralaRed = red; }) });
  const { c, icerik, b } = k;
  const { silP, yukleP } = await silUcustaBaslat(k);
  b.liste.red(new Error('boom'));
  await yukleP;
  c.panoSiralaModu(true);
  const siraP = tikla(c, dugme(kart(icerik, 'b'), '▲'));   // geri dönüş dizisi silinecek kaydı taşır
  await nefes();
  b.sil.ok(null);
  await silP;
  siralaRed(new Error('sira patladı'));
  await siraP;   // TypeError olsaydı burada reddedilirdi
  assert.deepStrictEqual(sira(icerik), ['b'], 'silinen kart dönmez');
  assert.ok(icerik.querySelector('.atolye-hata').textContent.includes('sira patladı'));
});

test('sil_ucusta_sekme_degisince_kurucu_ezilmez', async () => {
  const k = silUcustaKur();
  const { c, icerik, b, cagri } = k;
  const { silP, yukleP } = await silUcustaBaslat(k);
  c.atolyeSekme('kurucu');
  icerik.innerHTML = '<div id="kurucu-ici">K</div>';
  const n = cagri.chart.length;
  b.sil.ok(null);
  await silP;
  assert.strictEqual(icerik.innerHTML, '<div id="kurucu-ici">K</div>', 'başka sekmenin içeriği yazılmaz');
  assert.strictEqual(cagri.chart.length, n);
  b.liste.ok([KAYIT('b')]);
  await yukleP;
  assert.strictEqual(icerik.innerHTML, '<div id="kurucu-ici">K</div>');
});

test('sil_ucusta_liste_once_geldiyse_yeniden_cizim_yok', async () => {
  const k = silUcustaKur();
  const { icerik, b, cagri } = k;
  const { silP, yukleP } = await silUcustaBaslat(k);
  b.liste.ok([KAYIT('b')]);
  await yukleP;
  await nefes();
  const n = cagri.chart.length;
  b.sil.ok(null);
  await silP;
  assert.strictEqual(cagri.chart.length, n, 'yeni liste kendi kartlarını kurdu; eski Sil çizim tetiklemez');
  assert.deepStrictEqual(sira(icerik), ['b']);
});

test('sil_ucusta_hata_kart_kalir', async () => {
  const k = silUcustaKur();
  const { icerik, b } = k;
  const { silP, yukleP } = await silUcustaBaslat(k);
  b.sil.red(new Error('sil patladı'));
  await silP;
  b.liste.red(new Error('boom'));
  await yukleP;
  assert.deepStrictEqual(sira(icerik), ['a', 'b'], 'silinemeyen kart düşmez');
});

test('cevrimdisi_son_cizim_bayat_kalir', async () => {
  let kes = false;
  const { c, icerik, cagri } = kur({
    liste: () => { if (kes) throw new Error('İnternet bağlantısı gerekli'); return [KAYIT('a')]; },
    seri: () => { if (kes) throw new Error('İnternet bağlantısı gerekli'); return VERI(); },
  });
  await c.panoYukle();
  await nefes();
  kes = true;
  await tikla(c, dugme(kart(icerik, 'a'), 'Yeniden hesapla'));
  assert.ok(kart(icerik, 'a').querySelector('canvas'), 'kart hatasında son grafik kalır');
  assert.ok(icerik.querySelector('.atolye-bayat-etiket'));
  // liste de alınamazsa ızgara silinmez ve düğmeler çalışır durumda kalır
  await c.panoYukle();
  assert.ok(kart(icerik, 'a').querySelector('canvas'));
  assert.ok(icerik.classList.contains('atolye-bayat'));
  tikla(c, dugme(kart(icerik, 'a'), 'Sil'));
  assert.ok(kart(icerik, 'a').querySelector('.atolye-sil-onay'), 'eski durum korunur');
  tikla(c, dugme(kart(icerik, 'a'), 'Vazgeç'));
  // bağlantı dönünce bayat şerit temizlenir
  kes = false;
  await c.panoYukle();
  await nefes();
  assert.strictEqual(icerik.querySelector('.atolye-hata'), null);
  assert.ok(!icerik.classList.contains('atolye-bayat'));
  assert.ok(cagri.chart.length >= 2);
});

test('yeniden_hesapla_yenile_true', async () => {
  const { c, icerik, cagri } = kur({ liste: () => [KAYIT('a')] });
  await c.panoYukle();
  await nefes();
  await tikla(c, dugme(kart(icerik, 'a'), 'Yeniden hesapla'));
  const a = cagri.seri[1];
  assert.deepStrictEqual(duz(a[1]), {});
  assert.strictEqual(a[2].yenile, true);
  assert.ok(cagri.chart[0].yok, 'eski Chart destroy');
  assert.strictEqual(kart(icerik, 'a').querySelectorAll('canvas').length, 1);
});

test('kurucuda_ac_cumle_tasir', async () => {
  const { c, icerik, cagri } = kur({ liste: () => [KAYIT('a')] });
  await c.panoYukle();
  await nefes();
  tikla(c, dugme(kart(icerik, 'a'), 'Kurucuda aç'));
  assert.deepStrictEqual(duz(c.window._atolye.cumle), CUMLE());
  assert.deepStrictEqual(duz(cagri.kurucu), [CUMLE()], 'atolyeSekme tek kurucuAc çağırır');
});

test('sil_grafik_hatasi_okunur', async () => {
  const { c, icerik, cagri } = kur({ sil: () => { throw new Error('STAT_GRAFIK:yok'); } });
  await c.panoYukle();
  await nefes();
  const k = kart(icerik, 'a');
  tikla(c, dugme(k, 'Sil'));
  await tikla(c, dugme(k.querySelector('.atolye-sil-onay'), 'Sil'));
  await nefes();
  const m = icerik.querySelector('.atolye-hata').textContent;
  assert.ok(m.includes('Grafik bulunamadı; liste yenilendi') && !m.includes('STAT_GRAFIK'), m);
  assert.strictEqual(cagri.liste, 2);
});

test('sil_genel_hata_kart_kalir', async () => {
  const { c, icerik } = kur({ sil: () => { throw new Error('boom'); } });
  await c.panoYukle();
  await nefes();
  const k = kart(icerik, 'a');
  tikla(c, dugme(k, 'Sil'));
  await tikla(c, dugme(k.querySelector('.atolye-sil-onay'), 'Sil'));
  assert.deepStrictEqual(sira(icerik), ['a', 'b']);
  assert.ok(icerik.querySelector('.atolye-hata').textContent.includes('boom'));
  assert.ok(dugme(kart(icerik, 'a'), 'Sil'), 'onay kapanır, kart normal');
});

test('dipnot_zarftan_basilir', () => {
  const { c } = kur();
  const d = kokSar(c.panoKartHtml(KAYIT('a'), [Z_BASARI(), Z_HIZ()], null));
  const li = d.querySelector('.atolye-dipnot').querySelectorAll('li').map(x => x.textContent);
  assert.deepStrictEqual(li, ['2 vaka 24 saat içinde yeniden açıldı (tedavi değişti).']);
  assert.strictEqual(kokSar(c.panoKartHtml(KAYIT('a'), [Z_HIZ()], null)).querySelector('.atolye-dipnot'), null, 'boşsa liste yok');
});

test('yetersiz_metinle_ayrilir', () => {
  const { c } = kur();
  const az = Z_BASARI({ n: 3, seriler: [{ ad: 'başarı %', n: [3], k: [2], y: [null], alt: [null], ust: [null] }] });
  const d = kokSar(c.panoKartHtml(KAYIT('a'), [az, Z_HIZ()], null));
  assert.ok(d.querySelector('.atolye-durum').textContent.includes('Yetersiz veri (n=3) — en az 5 vaka gerekir'));
  assert.strictEqual(d.querySelector('canvas'), null);
  // ikinci ölçü n<5: özet satırında metin
  const k = KAYIT('a');
  const azHiz = Z_HIZ({ n: 2, seriler: [{ ad: 'gün', n: [2], y: [null], q1: [null], q3: [null] }] });
  const e = kokSar(c.panoKartHtml(k, [Z_BASARI(), azHiz], null));
  assert.ok(e.textContent.includes('Kapanma hızı: Yetersiz veri (n=2)'));
});

test('kontrast_yok_grafik_ve_uyari', () => {
  const { c } = kur();
  const k = KAYIT('a');
  k.cumle.ilac.x = 'Enrolen';
  const z = Z_BASARI({ sayac: { kiyas_n: 2 } });
  const d = kokSar(c.panoKartHtml(k, [z], null));
  assert.ok(d.querySelector('canvas'), 'plan T12 ile aynı: tamam/kontrast_yok çizilir');
  assert.ok(d.textContent.includes('Karşı grup çok küçük (n=2)'));
});

test('hastalik_adi_seceneklerden', async () => {
  const id = '11111111-1111-1111-1111-111111111111';
  const k = KAYIT('a');
  k.cumle.hastalik = { tip: 'hastalik', deger: id };
  const { c, icerik, cagri } = kur({ liste: () => [k], secenek: () => ({ hastaliklar: [{ id, ad: 'Enterit', n: 3 }] }) });
  await c.panoYukle();
  await nefes();
  assert.ok(kart(icerik, 'a').textContent.includes('Enterit vakalarında'));
  assert.strictEqual(cagri.secenek.length, 1);
});

test('hastalik_adi_alinamazsa_kart_cizilir', async () => {
  const k = KAYIT('a');
  k.cumle.hastalik = { tip: 'hastalik', deger: '11111111-1111-1111-1111-111111111111' };
  const { c, icerik } = kur({ liste: () => [k], secenek: () => { throw new Error('x'); } });
  await c.panoYukle();
  await nefes();
  assert.ok(kart(icerik, 'a').textContent.includes('Seçili hastalık vakalarında'));
  assert.ok(kart(icerik, 'a').querySelector('canvas'));
});

test('kategori_cumlede_secenek_rpc_yok', async () => {
  const { c, cagri } = kur();
  await c.panoYukle();
  await nefes();
  assert.deepStrictEqual(cagri.secenek, []);
});

test('yasak_kelime_renk_kopya', () => {
  const m = oku('js/istatistik/pano.js');
  const kucuk = m.toLocaleLowerCase('tr-TR');
  assert.ok(!kucuk.includes('protokol'));
  assert.ok(!/sağla|etkili|karşılığı/.test(kucuk));
  assert.ok(!/#[0-9a-f]{3,8}\b/i.test(m), 'sabit hex yok');
  assert.ok(!/style=/.test(m), 'inline stil yok');
  assert.ok(!/basarisiz_|SONUC_ETIKETLERI/.test(m), 'sonuç listesi kopyası yok');
  assert.ok(!/gecici\s*:|_atolye\.gecici/.test(m), 'geçici fiyat panoda yok');
  // yeni üst düzey adlar _pano önekli ya da Produces listesinde
  const adlar = [...m.matchAll(/^(?:async\s+)?(?:function|const|let)\s+([\w$]+)/gm)].map(x => x[1]);
  adlar.forEach(a => assert.ok(/^_pano/i.test(a) || ['panoYukle', 'panoKartHtml', 'panoSiralaModu', 'panoTasi'].includes(a), a));
});

test('imzalar_korunur', () => {
  const M = require(path.join(KOK, 'js/istatistik/pano.js'));
  assert.deepStrictEqual([M.panoYukle.length, M.panoKartHtml.length, M.panoSiralaModu.length, M.panoTasi.length], [0, 3, 1, 3]);
});

// ── TFA G1-G3 ──
const Z_ILAC = (ek = {}) => Z_BASARI({ n: 16, x: { ad: 'grup', deger: ['Enro içeren', 'Flu içeren', 'Melo içeren'], anahtar: ['ilac:Enro', 'ilac:Flu', 'ilac:Melo'] },
  seriler: [{ ad: 'başarı %', n: [16, 4, 6], k: [13, 4, 5], y: [81.3, null, 83.3], alt: [57, null, 40], ust: [93, null, 99] }], ...ek });
const AYRINTI = d => d.querySelector('.atolye-ayrinti');

test('kart_ilac_ortak_yardimci', async () => {
  const k = KAYIT('i');
  k.cumle.olculer = ['saglik_basari'];
  const { c, icerik, cagri } = kur({ liste: () => [k], seri: () => ({ zarflar: [Z_ILAC()], kombinasyon: null, fiyat_eksik: [] }) });
  await c.panoYukle();
  await nefes();
  const el = kart(icerik, 'i');
  assert.strictEqual(el.querySelector('.atolye-rozet').textContent, '2/3 ilaçta yeterli veri');
  assert.strictEqual(el.querySelector('.atolye-veri-az').textContent, '1 ilaçta veri az (<5 vaka): Flu 4');
  assert.deepStrictEqual(duz(cagri.chart[0].config.data.labels), ['Melo içeren', 'Enro içeren'], 'kurucuyla aynı süzme ve sıra');
  assert.strictEqual(el.querySelector('.atolye-ozet').textContent, 'Başarı Melo içeren %83,3, Enro içeren %81,3 (fark 2,0 puan).');
});

// S4: kurucuyla aynı kural, seçim tek kaynaktan (grafik.js).
const ORTUS = 'Gruplar örtüşür: bir vaka birden çok satırda sayılır.';
const GOZLEM = 'Karşılaştırma gözlemseldir; şiddet/yaş eşleştirmesi yok.';
const LILER = d => (d.querySelector('.atolye-dipnot') ? d.querySelector('.atolye-dipnot').querySelectorAll('li').map(x => x.textContent) : []);

test('kart_gozlem_uyarisi_gorunur_ayrintida_tekrarlanmaz', () => {
  const { c } = kur();
  const z = Z_BASARI({ dipnot: ['Ovsync dipnot.', ORTUS, '3 vaka tedavi değişti.', GOZLEM] });
  const h = c.panoKartHtml(KAYIT('a'), [z], null);
  assert.ok(h.includes(`${c.esc(c.zarfOzetCumle(z))}</p><div class="atolye-veri-az">${ORTUS} ${GOZLEM}</div>`), 'özetin hemen altında tek satır');
  const a = AYRINTI(kokSar(h));
  assert.deepStrictEqual(LILER(a), ['Ovsync dipnot.', '3 vaka tedavi değişti.'], 'Ayrıntıda tekrar yok');
  assert.ok(c.panoKartHtml(KAYIT('a'), [Z_ILAC({ dipnot: [ORTUS] })], null).includes(`</p><div class="atolye-veri-az">${ORTUS}</div><div class="atolye-veri-az">1 ilaçta`), 'veri az satırından önce');
  const tek = kokSar(c.panoKartHtml(KAYIT('a'), [Z_BASARI({ dipnot: ['Gözlemsel <b>x'] })], 'kontrast_yok'));
  assert.strictEqual(tek.querySelector('.atolye-veri-az').textContent, 'Gözlemsel <b>x', 'kontrast_yok da çizilir, kaçışlı');
  assert.strictEqual(tek.querySelector('.atolye-dipnot'), null, 'boş <ul> oluşmaz');
  assert.strictEqual(kokSar(c.panoKartHtml(KAYIT('a'), [Z_BASARI()], null)).querySelector('.atolye-veri-az'), null, 'seçilen yoksa satır yok');
});

test('kart_gozlem_uyarisi_cizilmeyen_kartta_ayrintida_kalir', () => {
  const { c } = kur();
  const z = Z_BASARI({ dipnot: [ORTUS, GOZLEM] });
  for (const durum of ['yukleniyor', 'hata', 'cevrimdisi', 'veri_yok']) {
    const d = kokSar(c.panoKartHtml(KAYIT('a'), [z], durum));
    assert.strictEqual(d.querySelector('.atolye-veri-az'), null, 'satır yok: ' + durum);
    assert.deepStrictEqual(LILER(AYRINTI(d)), [ORTUS, GOZLEM], 'Ayrıntıda kalır: ' + durum);
  }
  const fiyatsiz = kokSar(c.panoKartHtml(KAYIT('a'), [{ ...Z_TL_FIYATSIZ(), dipnot: [GOZLEM] }], null));
  assert.strictEqual(fiyatsiz.querySelector('.atolye-veri-az'), null);
  assert.deepStrictEqual(LILER(AYRINTI(fiyatsiz)), [GOZLEM], 'fiyat_yok: Ayrıntıda');
  assert.strictEqual(kokSar(c.panoKartHtml(KAYIT('a'), null, 'yukleniyor')).querySelector('.atolye-veri-az'), null, 'ilk yok');
  assert.strictEqual(kokSar(c.panoKartHtml(KAYIT('e', { cumle_surum: 9 }), [z], null)).querySelector('.atolye-dipnot'), null, 'eski sürüm');
});

test('gozlem_secimi_tek_kaynak', () => {
  for (const f of ['js/istatistik/kurucu.js', 'js/istatistik/pano.js']) assert.ok(!/gözlemsel/i.test(oku(f)), 'süzgeç kopyası yok: ' + f);
  assert.strictEqual((oku('js/istatistik/grafik.js').match(/örtüş\|gözlemsel/g) || []).length, 1);
});

test('kart_ayni_cumle_iki_kez_yazilmaz', () => {
  const { c } = kur();
  const k = KAYIT('a');
  k.baslik = c.cumleBaslik(k.cumle, null);
  const h = c.panoKartHtml(k, [Z_BASARI()], null);
  assert.strictEqual(h.split(c.esc(k.baslik)).length - 1, 1, 'başlık = cümle: tek yazılır');
  const ozel = KAYIT('b', { baslik: 'Benim grafiğim' });
  const d = kokSar(c.panoKartHtml(ozel, [Z_BASARI()], null));
  assert.strictEqual(d.querySelector('.atolye-kart-baslik').textContent, 'Benim grafiğim');
  assert.ok(AYRINTI(d).textContent.includes('Meme vakalarında'), 'özel başlıkta cümle Ayrıntı altında');
});

test('kart_ayrinti_kapali_ve_gorunur_alan', () => {
  const { c } = kur();
  const d = kokSar(c.panoKartHtml(KAYIT('a'), [Z_BASARI(), Z_HIZ()], null));
  const a = AYRINTI(d);
  assert.strictEqual(a.tag, 'details');
  assert.ok(!('open' in a.attrs), 'kapalı başlar');
  assert.strictEqual(d.querySelectorAll('details').length, 1);
  assert.strictEqual(a.querySelector('summary').textContent, 'Ayrıntı');
  assert.ok(a.querySelector('.atolye-dipnot') && a.querySelector('.atolye-hesap'));
  assert.ok(dugme(a, 'Yeniden hesapla'));
  assert.ok(!a.querySelector('canvas') && !a.querySelector('.atolye-ozet'));
  assert.ok(!dugme(a, 'Kurucuda aç') && dugme(d, 'Kurucuda aç'), 'eylemler dışarıda');
  assert.ok(!c.panoKartHtml(KAYIT('a'), [Z_BASARI()], null).includes('style='));
});

test('kart_hata_yeniden_hesapla_ayrinti_disinda', () => {
  const { c } = kur();
  for (const durum of ['hata', 'cevrimdisi']) {
    const d = kokSar(c.panoKartHtml(KAYIT('a'), null, durum));
    assert.ok(dugme(d, 'Yeniden hesapla'), durum);
    assert.strictEqual(dugme(d, 'Yeniden hesapla').closest('details'), null, `${durum}: kapalı alanda gizlenmez`);
  }
});

test('kart_yukleniyor_ve_eski_bos_ayrinti_yok', () => {
  const { c } = kur();
  assert.strictEqual(AYRINTI(kokSar(c.panoKartHtml(KAYIT('e', { cumle_surum: 99 }), null, null))), null);
  const k = KAYIT('a');
  k.baslik = c.cumleBaslik(k.cumle, null);
  assert.strictEqual(AYRINTI(kokSar(c.panoKartHtml(k, null, 'yukleniyor'))), null);
});

test('kart_zaman_seyrek_metin_ayni_eylem_kurucuda_ac', () => {
  const { c } = kur();
  const k = KAYIT('z');
  k.cumle.kirilim = 'ay';
  k.cumle.olculer = ['saglik_basari'];
  const z = Z_BASARI({ n: 15, x: { ad: 'ay', deger: ['2026-06', '2026-07', '2026-08'], anahtar: ['a', 'b', 'c'] },
    seriler: [{ ad: 'Tüm', anahtar: 'tumu', n: [4, 8, 3], k: [2, 6, 1], y: [null, 75, null] }] });
  const d = kokSar(c.panoKartHtml(k, [z], null));
  assert.strictEqual(d.querySelector('canvas'), null);
  assert.strictEqual(d.querySelector('.atolye-durum').textContent, 'Başarı Tüm 2026-07: %75,0 (6/8). Çizgi için en az 2 dönemde 5 vaka gerekir.');
  assert.ok(d.querySelector('.atolye-veri-az').textContent.includes('2026-06 yetersiz (n=4)'));
  assert.ok(dugme(d, 'Kurucuda aç'));
  assert.ok(!dugme(d, 'Çeyreklik göster'), 'panoda ayrı slot düğmesi yok');
});

// ── TFA review tur1 ──
const Z_ZAMAN = (y, n = [4, 8, 3]) => Z_HIZ({ n: 15, x: { ad: 'ay', deger: ['2026-06', '2026-07', '2026-08'], anahtar: ['a', 'b', 'c'] },
  seriler: [{ ad: 'Tüm', anahtar: 'tumu', n, y, q1: [null, null, null], q3: [null, null, null] }] });

test('b3_diger_olcu_zaman_seyrek_olcu_adi_tek', () => {
  const { c } = kur();
  const d = kokSar(c.panoKartHtml(KAYIT('a'), [Z_BASARI(), Z_ZAMAN([null, 6.5, null])], null));
  const satir = d.querySelectorAll('.atolye-ozet').map(x => x.textContent);
  assert.strictEqual(satir[1], 'Medyan kapanma Tüm 2026-07: 6,5 gün. Çizgi için en az 2 dönemde 5 vaka gerekir.');
  // dolu nokta yoksa metinde ölçü adı geçmez: etiket kalır
  const e = kokSar(c.panoKartHtml(KAYIT('a'), [Z_BASARI(), Z_ZAMAN([null, null, null], [4, 4, 3])], null));
  assert.strictEqual(e.querySelectorAll('.atolye-ozet')[1].textContent, 'Kapanma hızı: Çizgi için en az 2 dönemde 5 vaka gerekir.');
});

test('b4_kart_fiyat_yok_rozetsiz', () => {
  const { c } = kur();
  const k = KAYIT('f');
  k.cumle.olculer = ['saglik_vaka_tl'];
  const z = Z_TL_FIYATSIZ();
  z.x = { ad: 'grup', deger: ['A içeren', 'B içeren'], anahtar: ['ilac:A', 'ilac:B'] };
  z.seriler = [{ ad: '₺', n: [0, 0], y: [null, null], q1: [null, null], q3: [null, null] }];
  const d = kokSar(c.panoKartHtml(k, [z], null));
  assert.ok(d.textContent.includes('Fiyat girilmedi'));
  assert.strictEqual(d.querySelector('.atolye-rozet'), null);
  // ilaç dışı kart n rozetini korur
  assert.strictEqual(kokSar(c.panoKartHtml(k, [Z_TL_FIYATSIZ()], null)).querySelector('.atolye-rozet').textContent, 'n=0');
});

// ── TFB G8 ──
const kilitli = b => b.disabled && b.classList.contains('atolye-pasif');
const acikDugme = b => !b.disabled && !b.classList.contains('atolye-pasif');

test('a1_liste_beklerken_sira_ve_onay_sil_pasif', async () => {
  let bekleyen = null;
  const { c, icerik } = kur({ liste: () => (bekleyen ? new Promise(ok => { bekleyen.ok = ok; }) : [KAYIT('a'), KAYIT('b')]) });
  await c.panoYukle();
  await nefes();
  c.panoSiralaModu(true);
  tikla(c, dugme(kart(icerik, 'a'), 'Sil'));
  assert.ok(acikDugme(dugme(kart(icerik, 'b'), '▲')), 'boşta açık');
  assert.ok(acikDugme(dugme(kart(icerik, 'a').querySelector('.atolye-sil-onay'), 'Sil')), 'boşta açık');
  bekleyen = {};
  const p = c.panoYukle();
  await nefes();
  assert.ok(kilitli(dugme(kart(icerik, 'b'), '▲')), '▲ pasif');
  assert.ok(kilitli(dugme(kart(icerik, 'a'), '▼')), '▼ pasif');
  assert.ok(kilitli(dugme(kart(icerik, 'a').querySelector('.atolye-sil-onay'), 'Sil')), 'onay Sil pasif');
  assert.ok(!dugme(kart(icerik, 'a').querySelector('.atolye-sil-onay'), 'Vazgeç').disabled, 'Vazgeç açık kalır');
  // yüklenirken açılan onay da pasif gelir
  tikla(c, dugme(kart(icerik, 'b'), 'Sil'));
  assert.ok(kilitli(dugme(kart(icerik, 'b').querySelector('.atolye-sil-onay'), 'Sil')));
  bekleyen.ok([KAYIT('a'), KAYIT('b')]);
  await p;
  await nefes();
  assert.ok(acikDugme(dugme(kart(icerik, 'b'), '▲')), 'liste gelince açılır');
});

test('a1_liste_hatasinda_kilit_acilir', async () => {
  let bekleyen = null;
  const { c, icerik } = kur({ liste: () => (bekleyen ? new Promise((ok, red) => { bekleyen.red = red; }) : [KAYIT('a'), KAYIT('b')]) });
  await c.panoYukle();
  await nefes();
  c.panoSiralaModu(true);
  bekleyen = {};
  const p = c.panoYukle();
  await nefes();
  assert.ok(kilitli(dugme(kart(icerik, 'b'), '▲')));
  bekleyen.red(new Error('boom'));
  await p;
  assert.ok(acikDugme(dugme(kart(icerik, 'b'), '▲')));
});

test('a1_yazma_ucusta_pasif_bitince_acik', async () => {
  let bitir;
  let hataVer = false;
  const { c, icerik } = kur({
    sirala: () => new Promise(r => { bitir = r; }),
    sil: () => new Promise((ok, red) => { bitir = hataVer ? () => red(new Error('boom')) : ok; }),
  });
  await c.panoYukle();
  await nefes();
  c.panoSiralaModu(true);
  let p = tikla(c, dugme(kart(icerik, 'b'), '▲'));
  await nefes();
  assert.ok(kilitli(dugme(kart(icerik, 'b'), '▲')), 'sırala uçuşta');
  bitir();
  await p;
  assert.ok(acikDugme(dugme(kart(icerik, 'b'), '▲')), 'sırala başarısı kilidi açar');
  hataVer = true;
  tikla(c, dugme(kart(icerik, 'a'), 'Sil'));
  p = tikla(c, dugme(kart(icerik, 'a').querySelector('.atolye-sil-onay'), 'Sil'));
  await nefes();
  assert.ok(kilitli(dugme(kart(icerik, 'b'), '▲')), 'sil uçuşta başka kartın ▲ da pasif');
  bitir();
  await p;
  assert.ok(acikDugme(dugme(kart(icerik, 'b'), '▲')), 'sil hatası kilidi açar');
  assert.strictEqual(kart(icerik, 'a').querySelector('.atolye-sil-onay'), null, 'onay satırı kapanır');
});

test('a1_sil_yeni_kosu_sonrasi_dusen_hata_serit', async () => {   // T15 tur3 Ö1
  const k = silUcustaKur();
  const { icerik, b } = k;
  const { silP, yukleP } = await silUcustaBaslat(k);
  b.liste.ok([KAYIT('a'), KAYIT('b')]);
  await yukleP;
  await nefes();
  assert.strictEqual(icerik.querySelector('.atolye-hata'), null);
  b.sil.red(new Error('sil patladı'));
  await silP;
  assert.ok(icerik.querySelector('.atolye-hata').textContent.includes('sil patladı'), 'şerit görünür');
  assert.deepStrictEqual(sira(icerik), ['a', 'b'], 'kart yerinde');
});

test('a1_sil_yeni_kosu_sirasinda_dusen_hata_onay_kapanir', async () => {
  const k = silUcustaKur();
  const { icerik, b } = k;
  const { silP, yukleP } = await silUcustaBaslat(k);
  b.sil.red(new Error('sil patladı'));
  await silP;
  assert.ok(icerik.querySelector('.atolye-hata').textContent.includes('sil patladı'));
  assert.strictEqual(kart(icerik, 'a').querySelector('.atolye-sil-onay'), null, 'onay kapanır');
  assert.ok(dugme(kart(icerik, 'a'), 'Sil'));
  b.liste.ok([KAYIT('a'), KAYIT('b')]);
  await yukleP;
  await nefes();
  assert.ok(icerik.querySelector('.atolye-hata').textContent.includes('sil patladı'), 'genel şerit liste başarısında silinmez');
});

test('a1_sil_yeni_listenin_kendi_onayini_kapatmaz', async () => {
  const k = silUcustaKur();
  const { c, icerik, b } = k;
  const { silP, yukleP } = await silUcustaBaslat(k);
  b.liste.ok([KAYIT('a'), KAYIT('b')]);
  await yukleP;
  await nefes();
  tikla(c, dugme(kart(icerik, 'a'), 'Sil'));          // yeni koşunun kartında kullanıcı yeniden onay açtı
  b.sil.red(new Error('sil patladı'));
  await silP;
  assert.ok(kart(icerik, 'a').querySelector('.atolye-sil-onay'), 'yeni koşunun onayı açık kalır');
});

test('a1_sil_sekme_degisince_hata_kurucuya_yazilmaz', async () => {
  const k = silUcustaKur();
  const { c, icerik, b } = k;
  const { silP, yukleP } = await silUcustaBaslat(k);
  c.window._atolye.sekme = 'kurucu';
  b.sil.red(new Error('sil patladı'));
  await silP;
  b.liste.ok([KAYIT('a'), KAYIT('b')]);
  await yukleP;
  assert.strictEqual(icerik.querySelector('.atolye-hata'), null);
});

test('e13_chart_sizinti_gecislerde_ornek_birikmez', async () => {
  const { c, icerik } = kur({ kurucuGercek: true, liste: () => [KAYIT('a')] });
  c.window._atolye.cumle = CUMLE();
  const canli = () => Object.keys(c.Chart.instances).length;
  const ekranda = () => icerik.querySelectorAll('canvas').filter(x => x.__chart && !x.__chart.yok).length;
  await c.atolyeSekme('pano');
  await nefes();
  assert.strictEqual(canli(), 1, 'pano: tek kart');
  for (let i = 0; i < 6; i += 1) {
    await c.atolyeSekme('kurucu');
    await nefes();
    assert.ok(icerik.querySelectorAll('canvas[data-kurucu-kart]').length === 2, 'kurucu iki kart çizer');
    assert.strictEqual(canli(), 2, `kurucu tur ${i}: yalnız ekrandakiler`);
    assert.strictEqual(ekranda(), 2);
    await c.atolyeSekme('pano');
    await nefes();
    assert.strictEqual(canli(), 1, `pano tur ${i}: yalnız ekrandakiler`);
    assert.strictEqual(ekranda(), 1);
  }
});

test('e13_chart_ayni_sekmede_son_cizim_yok_edilmez', async () => {
  let bekleyen = null;
  const { c, icerik, cagri } = kur({ liste: () => (bekleyen ? new Promise(ok => { bekleyen.ok = ok; }) : [KAYIT('a')]) });
  await c.atolyeSekme('pano');
  await nefes();
  const ch = kart(icerik, 'a').querySelector('canvas').__chart;
  bekleyen = {};
  const p = c.atolyeSekme('pano');                     // aynı sekmeye basış: ızgara liste gelene dek görünür kalır
  await nefes();
  assert.strictEqual(ch.yok, false, 'liste beklenirken grafik canlı');
  bekleyen.ok([KAYIT('a')]);
  await p;
  await nefes();
  assert.strictEqual(Object.keys(c.Chart.instances).length, 1);
  assert.ok(cagri.chart.length >= 2);
});

test('e13_diger_olcu_fiyatsiz_metin_ve_eylem', () => {
  const { c } = kur();
  const k = KAYIT('f');
  k.cumle.olculer = ['saglik_basari', 'saglik_vaka_tl'];
  const d = kokSar(c.panoKartHtml(k, [Z_BASARI(), Z_TL_FIYATSIZ()], null));
  assert.ok(d.textContent.includes('Vaka başı ₺: Fiyat girilmedi'));
  assert.ok(!d.textContent.includes('— hesapla'));
  const b = dugme(d, 'Kurucuda fiyat gir');
  assert.ok(b, 'özet satırında eylem');
  assert.strictEqual(b.getAttribute('onclick'), '_panoKurucudaAc(this)', 'mevcut Kurucuda aç yolu');
});

test('e13_fiyat_gir_eylemi_cumleyle_kurucuya_gider', async () => {
  const k = KAYIT('f');
  k.cumle.olculer = ['saglik_vaka_tl'];
  const { c, icerik, cagri } = kur({ liste: () => [k], seri: () => ({ zarflar: [Z_TL_FIYATSIZ()], kombinasyon: null, fiyat_eksik: [] }) });
  await c.panoYukle();
  await nefes();
  await tikla(c, dugme(kart(icerik, 'f'), 'Kurucuda fiyat gir'));
  assert.deepStrictEqual(duz(cagri.kurucu), [duz(k.cumle)]);
  assert.strictEqual(c.window._atolye.sekme, 'kurucu');
});

test('e14_ilk_cevrimdisi_liste_basarisi_seridi_kaldirir', async () => {
  let kes = true;
  const { c, icerik } = kur({ liste: () => { if (kes) throw new Error('İnternet bağlantısı gerekli'); return []; } });
  await c.panoYukle();
  assert.ok(icerik.querySelector('.atolye-hata').textContent.includes('İstatistik çevrimiçi hesaplanır'));
  assert.strictEqual(icerik.querySelector('.atolye-kart'), null, 'kart yok: ilk giriş');
  kes = false;
  await c.panoYukle();
  await nefes();
  assert.strictEqual(icerik.querySelector('.atolye-hata'), null, 'liste geldi: şerit kalkar');
  assert.ok(icerik.querySelector('.atolye-bos'));
});

test('e14_grafik_cevirisi_cevrimdisi_sonrasi_da_kalir', async () => {   // K2 tur1
  let kes = false;
  const { c, icerik, cagri } = kur({
    liste: () => { if (kes) throw new Error('İnternet bağlantısı gerekli'); return [KAYIT('a'), KAYIT('b')]; },
    sil: () => { throw new Error('STAT_GRAFIK:yok'); },
  });
  await c.panoYukle();
  await nefes();
  kes = true;
  await c.panoYukle();
  assert.ok(icerik.querySelector('.atolye-hata').textContent.includes('çevrimiçi'));
  kes = false;
  tikla(c, dugme(kart(icerik, 'a'), 'Sil'));
  await tikla(c, dugme(kart(icerik, 'a').querySelector('.atolye-sil-onay'), 'Sil'));
  await nefes();
  assert.strictEqual(cagri.liste, 3, 'liste yenilendi');
  assert.strictEqual(icerik.querySelector('.atolye-hata').textContent, 'Grafik bulunamadı; liste yenilendi', 'çeviri şeridi liste başarısında kalır');
});

test('e14_genel_serit_liste_basarisinda_kalir', async () => {
  const { c, icerik } = kur({ liste: () => [KAYIT('a')] });
  await c.panoYukle();
  await nefes();
  c.atolyeHataSeridi(new Error('boom'), icerik);
  await c.panoYukle();
  await nefes();
  assert.ok(icerik.querySelector('.atolye-hata').textContent.includes('boom'));
});

// ── TKF4 / E13-sirala-titreme: ▲/▼ sonrası klavye odağı ─────────────────────
async function siraKur(ek = {}) {
  const t = kur({ liste: () => [KAYIT('a'), KAYIT('b'), KAYIT('c')], ...ek });
  await t.c.panoYukle();
  await nefes();
  tikla(t.c, dugme(t.icerik, 'Sırala'));
  return t;
}
const odak = c => c.document.activeElement;
const siraDugme = (i, id, m) => dugme(kart(i, id), m);

test('odak_ayni_kart_ayni_yon', async () => {
  const { c, icerik } = await siraKur();
  const d = siraDugme(icerik, 'a', '▼');
  d.focus();
  await tikla(c, d);
  assert.deepStrictEqual(sira(icerik), ['b', 'a', 'c']);
  assert.strictEqual(odak(c), siraDugme(icerik, 'a', '▼'), 'a kartının ▼ düğmesi');
  const y = siraDugme(icerik, 'c', '▲');
  y.focus();
  await tikla(c, y);
  assert.deepStrictEqual(sira(icerik), ['b', 'c', 'a']);
  assert.strictEqual(odak(c), siraDugme(icerik, 'c', '▲'), 'c kartının ▲ düğmesi');
});

test('odak_uca_gelince_diger_dugme', async () => {
  const { c, icerik } = await siraKur();
  const y = siraDugme(icerik, 'b', '▲');
  y.focus();
  await tikla(c, y);
  assert.deepStrictEqual(sira(icerik), ['b', 'a', 'c']);
  assert.strictEqual(odak(c), siraDugme(icerik, 'b', '▼'), 'en üstte: ▼');
  await tikla(c, odak(c));
  assert.deepStrictEqual(sira(icerik), ['a', 'b', 'c']);
  assert.strictEqual(odak(c), siraDugme(icerik, 'b', '▼'), 'ortada: yine ▼');
  await tikla(c, odak(c));
  assert.deepStrictEqual(sira(icerik), ['a', 'c', 'b']);
  assert.strictEqual(odak(c), siraDugme(icerik, 'b', '▲'), 'en altta: ▲');
});

test('odak_ucusta_kilitli_yanitta_doner', async () => {
  let bitir;
  const { c, icerik } = await siraKur({ sirala: () => new Promise(r => { bitir = r; }) });
  const d = siraDugme(icerik, 'a', '▼');
  d.focus();
  const p = tikla(c, d);
  await nefes();
  assert.strictEqual(odak(c), c.document.body, 'uçuşta düğme pasif');
  bitir(null);
  await p;
  const hedef = siraDugme(icerik, 'a', '▼');
  assert.strictEqual(hedef.disabled, false);
  assert.strictEqual(odak(c), hedef);
});

test('odak_kullanici_baska_yerdeyse_calinmaz', async () => {
  let bitir;
  const { c, icerik } = await siraKur({ sirala: () => new Promise(r => { bitir = r; }) });
  const d = siraDugme(icerik, 'a', '▼');
  d.focus();
  const p = tikla(c, d);
  await nefes();
  const baska = dugme(icerik, 'Sıralamayı bitir');
  baska.focus();
  bitir(null);
  await p;
  assert.strictEqual(odak(c), baska);
});

test('odak_hata_eski_sirada_ayni_dugme', async () => {
  const { c, icerik } = await siraKur({ sirala: () => { throw new Error('boom'); } });
  const d = siraDugme(icerik, 'b', '▲');
  d.focus();
  await tikla(c, d);
  assert.deepStrictEqual(sira(icerik), ['a', 'b', 'c']);
  assert.strictEqual(odak(c), siraDugme(icerik, 'b', '▲'));
});

test('odak_grafik_hatasi_liste_yenilenince_de_kalir', async () => {
  const { c, icerik } = await siraKur({ sirala: () => { throw new Error('STAT_GRAFIK:sira_kumesi'); } });
  const d = siraDugme(icerik, 'b', '▲');
  d.focus();
  await tikla(c, d);
  await nefes();
  assert.strictEqual(odak(c), siraDugme(icerik, 'b', '▲'));
});

test('odak_gec_gelen_kart_cizimi_dusurmez', async () => {
  // Sıra modunda hesap yanıtı kartı yeniden yazar; odaktaki ▲/▼ yeni kartta aynı düğmeye döner.
  const yan = [];
  const { c, icerik } = kur({ liste: () => [KAYIT('a'), KAYIT('b')], seri: () => new Promise(r => yan.push(r)) });
  const y = c.panoYukle();
  await nefes();
  tikla(c, dugme(icerik, 'Sırala'));
  const d = siraDugme(icerik, 'a', '▼');
  d.focus();
  yan.shift()(VERI());
  await nefes();
  assert.notStrictEqual(siraDugme(icerik, 'a', '▼'), d, 'kart yeniden yazıldı');
  assert.strictEqual(odak(c), siraDugme(icerik, 'a', '▼'));
  yan.shift()(VERI());
  await y;
});

// ── BORC-UI ──
test('borc_u2_kart_dipnotu_tek_hesap', () => {
  const { c } = kur();
  const asil = c.grafikDipnotAyir;
  let sayac = 0;
  c.grafikDipnotAyir = (...a) => { sayac += 1; return asil(...a); };
  c.panoKartHtml(KAYIT('a'), [Z_ILAC({ dipnot: [ORTUS, 'Öteki'] })], null);
  assert.strictEqual(sayac, 1);
});

test('borc_u4_sirala_dugmesinde_odak_kalir', async () => {
  const { c, icerik } = await siraKur();                        // siraKur "Sırala"ya basar
  assert.strictEqual(odak(c), dugme(icerik, 'Sıralamayı bitir'), 'mod açıldı: odak yeni düğmede');
  await tikla(c, dugme(icerik, 'Sıralamayı bitir'));
  assert.strictEqual(odak(c), dugme(icerik, 'Sırala'), 'mod kapandı: odak yeni düğmede');
});
