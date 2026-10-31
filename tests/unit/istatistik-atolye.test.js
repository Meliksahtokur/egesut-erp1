'use strict';
// İstatistik Atölyesi AP1 Task 11 — kabuk: #pg-istatistik, sekmeler, script sırası, ?v= damgası,
// eski ekranın emekliliği (js/ui.js), atolye.js (hesap tarihi, hata şeridi, sekme), T12-T15 stub'ları.
const { test } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { extractFunctionSource } = require('./support/loadModule.js');

const KOK = path.join(__dirname, '..', '..');
const oku = rel => fs.readFileSync(path.join(KOK, rel), 'utf8');
const HTML = oku('index.html');
const UI = oku('js/ui.js');

function pgIstatistik() {
  const bas = HTML.indexOf('<div id="pg-istatistik"');
  assert.ok(bas >= 0, '#pg-istatistik yok');
  const son = HTML.indexOf('</div><!-- /pages -->', bas);
  assert.ok(son > bas, '#pg-istatistik sonu bulunamadı');
  return HTML.slice(bas, son);
}
const yerelSrc = () => [...HTML.matchAll(/<script src="([^"]+)"/g)].map(m => m[1]).filter(s => !s.startsWith('http'));
const YENI = ['vendor/chart.umd.min.js', 'js/istatistik/cumle.js', 'js/istatistik/grafik.js',
  'js/istatistik/kombinasyon.js', 'js/istatistik/gecici-fiyat.js', 'js/istatistik/kurucu.js',
  'js/istatistik/pano.js', 'js/istatistik/atolye.js'];
const ESKI = ['_istatistikTabloHtml', '_istatistikSeriTabloHtml', '_istatistikFiltreHtml', '_istatistikDurum',
  'loadIstatistik', '_istatistikFiltreYaz', 'istatistikSec', 'istatistikYenile'];

// ── Sahte DOM (yalnız atolye.js'in kullandığı yüzey) ──
function sahteKok(html) {
  const siniflar = new Set();
  const k = {
    html,
    classList: { add: c => siniflar.add(c), remove: c => siniflar.delete(c), contains: c => siniflar.has(c) },
    insertAdjacentHTML(yer, h) { assert.strictEqual(yer, 'afterbegin'); k.html = h + k.html; },
    canvaslar: [],
    querySelectorAll(sec) { assert.strictEqual(sec, 'canvas'); return k.canvaslar; },
    querySelector(sec) {
      if (sec === '.atolye-hata') {
        if (!k.html.includes('class="atolye-hata"')) return null;
        return { set innerHTML(v) { k.html = k.html.replace(/(<div class="atolye-hata"[^>]*>)[\s\S]*?(<\/div>)/, `$1${v}$2`); },
          remove() { k.html = k.html.replace(/<div class="atolye-hata"[^>]*>[\s\S]*?<\/div>/, ''); } };
      }
      if (sec === 'canvas') return /<canvas/.test(k.html) ? {} : null;
      if (sec === 'canvas,.atolye-kart') return /<canvas|class="atolye-kart/.test(k.html) ? {} : null;
      throw new Error('beklenmeyen seçici: ' + sec);
    },
  };
  return k;
}
function atolyeYukle(ek = {}) {
  const kacis = v => String(v).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  const c = {
    console, Date, Intl, String, Object, Array, JSON, Promise, Error,
    navigator: { onLine: true },
    esc: v => (v == null ? '' : kacis(v)),
    window: {},
    ...ek,
  };
  vm.createContext(c);
  vm.runInContext(extractFunctionSource('js/api.js', 'statHataKodu'), c);
  vm.runInContext(oku('js/istatistik/atolye.js'), c);
  return c;
}

// ── Step 1 (plan Task 11): 9 test ──
test('html_sekmeler_iki', () => {
  const s = pgIstatistik();
  assert.ok(/>Pano</.test(s), 'Pano sekmesi');
  assert.ok(/>Kurucu</.test(s), 'Kurucu sekmesi');
  assert.ok(!s.includes('Kıyas') && !s.includes('Fiyatlar'), 'Kıyas/Fiyatlar sekmesi çizilmez');
  assert.ok(s.includes(`onclick="atolyeSekme('pano')"`) && s.includes(`onclick="atolyeSekme('kurucu')"`));
  assert.ok(!/data-action="atolye/.test(s), 'sekme düğmeleri data-action değil onclick');
  const root = s.slice(s.indexOf('id="istatistik-root"'));
  assert.ok(root.indexOf('id="atolye-sekmeler"') > 0 && root.indexOf('id="atolye-icerik"') > root.indexOf('id="atolye-sekmeler"'),
    '#istatistik-root altında #atolye-sekmeler + #atolye-icerik');
});

test('html_baslik', () => {
  const s = pgIstatistik();
  assert.ok(s.includes('📊 İstatistik Atölyesi'));
  assert.ok(!s.includes('Tedavi ölçümleri'), 'eski alt satır kalktı');
  const bas = s.slice(0, s.indexOf('id="istatistik-root"'));
  assert.ok(!/font-size:\.7rem/.test(bas), 'başlıkta alt satır yok');
  assert.ok(bas.includes('data-action="nav-geri"') && bas.includes('‹ Geri'), '‹ Geri kalır');
});

test('html_script_sirasi', () => {
  const src = yerelSrc().map(s => s.replace(/\?v=.*$/, ''));
  const i = ad => src.indexOf(ad);
  YENI.forEach(ad => assert.ok(i(ad) >= 0, 'etiket yok: ' + ad));
  YENI.forEach((ad, k) => { if (k) assert.strictEqual(i(ad), i(YENI[k - 1]) + 1, 'sıra/bitişiklik: ' + ad); });
  assert.ok(i('js/ui.js') < i(YENI[0]) && i(YENI[7]) < i('js/app.js'), 'js/ui.js ile js/app.js arasında');
  assert.strictEqual(i(YENI[0]), i('js/degisiklikler/degisiklikler.js') + 1, 'degisiklikler.js hemen sonrası (Ruling F3)');
  assert.strictEqual(i(YENI[7]) + 1, i('js/app.js'), 'app.js hemen öncesi');
  YENI.forEach(ad => assert.strictEqual(src.filter(s => s === ad).length, 1, 'tek etiket: ' + ad));
});

test('html_damga_tek', () => {
  const yerel = yerelSrc();
  const damgasiz = yerel.filter(s => !/\?v=[0-9]{8}-[0-9]+$/.test(s));
  assert.deepStrictEqual(damgasiz, [], 'damgasız yerel script yok');
  YENI.forEach(ad => assert.ok(yerel.some(s => s.startsWith(ad + '?v=')), 'yeni etiket damgalı: ' + ad));
  const tum = [...new Set([...HTML.matchAll(/\?v=([0-9]{8}-[0-9]+)/g)].map(m => m[1]))];
  assert.strictEqual(tum.length, 1, 'tüm ?v= tek değer: ' + tum.join(' / '));
});

test('ui_eski_fn_yok', () => {
  ESKI.forEach(ad => assert.ok(!new RegExp('function\\s+' + ad + '\\s*\\(').test(UI), 'js/ui.js tanımı kalmış: ' + ad));
  assert.ok(!/statOlcumCagir|statSonucOku/.test(UI), 'eski RPC sarmalayıcı çağrısı yok');
  assert.ok(!/_istatistik(Tablo|SeriTablo|Filtre|Durum|FiltreYaz)|istatistikSec|istatistikYenile/.test(UI + HTML));
});

test('ui_dashboard_hucre_kalir', () => {
  assert.ok(UI.includes(`onclick="goTo('istatistik')"`), 'dashboard İstatistik hücresi');
  assert.ok(/function _ovsyncBayatEtiket\(/.test(UI), '_ovsyncBayatEtiket kalır');
  assert.ok(oku('js/app.js').includes(`else if (pg === 'istatistik') { if (typeof loadIstatistik === 'function') loadIstatistik(); }`),
    'app.js:139 değişmez');
  assert.ok(/async function loadIstatistik\(/.test(oku('js/istatistik/atolye.js')), 'giriş atolye.js');
});

test('hesap_tarihi_bicim', () => {
  const c = atolyeYukle();
  assert.strictEqual(c.atolyeHesapTarihi('2026-10-17T06:05:00Z'), 'Hesap tarihi: 17.10.2026 09:05');
  assert.strictEqual(c.atolyeHesapTarihi('2026-10-17T21:30:00Z'), 'Hesap tarihi: 18.10.2026 00:30', 'TR gün dönümü');
  assert.strictEqual(c.atolyeHesapTarihi('2026-01-05T09:00:00+03:00'), 'Hesap tarihi: 05.01.2026 09:00', 'kış: DST yok');
  assert.strictEqual(c.atolyeHesapTarihi('bozuk'), 'Hesap tarihi: —');
});

test('hata_seridi_cumle', () => {
  const c = atolyeYukle();
  const kok = sahteKok('<div class="atolye-kart">eski</div>');
  const kod = c.atolyeHataSeridi(new Error('STAT_CUMLE:ilac.y:x_yok'), kok);
  assert.strictEqual(kod.tip, 'cumle');
  assert.ok(kok.html.startsWith('<div class="atolye-hata"'), 'şerit en üstte');
  assert.ok(kok.html.includes('Seçim geçersiz (ilac.y)'));
  assert.ok(kok.html.includes('eski'), 'içerik silinmez');
  assert.ok(!kok.classList.contains('atolye-bayat'), 'cümle hatası bayat değil');
  // ikinci çağrı yeni şerit eklemez, mevcut olanı günceller; yol kaçışlı
  c.atolyeHataSeridi(new Error('STAT_CUMLE:<b>:x'), kok);
  assert.strictEqual((kok.html.match(/class="atolye-hata"/g) || []).length, 1);
  assert.ok(kok.html.includes('Seçim geçersiz (&lt;b&gt;)') && !kok.html.includes('<b>'));
});

test('hata_seridi_cevrimdisi_bayat', () => {
  const c = atolyeYukle();
  const kok = sahteKok('<div class="atolye-kart"><canvas id="g1"></canvas></div>');
  const kod = c.atolyeHataSeridi(new Error('İnternet bağlantısı gerekli'), kok);
  assert.strictEqual(kod.tip, 'cevrimdisi');
  assert.ok(kok.html.includes('İstatistik çevrimiçi hesaplanır'), '§4.8 metni');
  assert.ok(kok.html.includes('<canvas id="g1">'), 'son grafik silinmez');
  assert.ok(/class="atolye-bayat-etiket"[^>]*>[^<]*bayat/.test(kok.html), 'bayat etiketi');
  assert.ok(kok.classList.contains('atolye-bayat'));
  // içerik yoksa bayat etiketi basılmaz
  const bos = sahteKok('');
  c.atolyeHataSeridi(new Error('Sunucuya ulaşılamıyor'), bos);
  assert.ok(bos.html.includes('İstatistik çevrimiçi hesaplanır') && !bos.html.includes('atolye-bayat-etiket'));
});

// ── Ek testler ──
test('hata_seridi_genel_kacis_ve_temizle', () => {
  const c = atolyeYukle();
  const kok = sahteKok('<div class="atolye-kart"></div>');
  const kod = c.atolyeHataSeridi(new Error('<img src=x>'), kok);
  assert.strictEqual(kod.tip, 'genel');
  assert.ok(kok.html.includes('İstatistik alınamadı: &lt;img src=x&gt;'));
  c.atolyeHataSeridi(new Error('STAT_GRAFIK:yok'), kok);
  assert.ok(kok.html.includes('>İstatistik alınamadı</div>') && !kok.html.includes('STAT_GRAFIK'), 'ham grafik kodu kullanıcıya gitmez');
  kok.classList.add('atolye-bayat');
  c.atolyeHataTemizle(kok);
  assert.ok(!kok.html.includes('atolye-hata') && !kok.classList.contains('atolye-bayat'));
  assert.doesNotThrow(() => c.atolyeHataSeridi(new Error('x'), null), 'kök yoksa sessiz');
});

// ── TKF3: lead ruling'leri (T12 RÖ1, T15 RÖ1-3) ──
const seritMetni = kok => (kok.html.match(/<div class="atolye-hata"[^>]*>([\s\S]*?)<\/div>/) || [])[1];

function girisKur(ek = {}) {
  const cagri = [];
  const icerik = sahteKok(ek.html || '');
  const document = {
    getElementById: id => ({ 'istatistik-root': {}, 'atolye-icerik': icerik }[id] || null),
    querySelectorAll: () => [],
  };
  const bekleyen = [];
  const c = atolyeYukle({
    document,
    statOlcumListele: () => new Promise((ok, red) => { cagri.push('liste'); bekleyen.push({ ok, red }); }),
    panoYukle: () => cagri.push('pano'),
    kurucuAc: () => cagri.push('kurucu'),
  });
  return { c, icerik, cagri, bitir: () => bekleyen.forEach(b => b.ok([])), kir: e => bekleyen.forEach(b => b.red(e)) };
}

test('giris_liste_beklerken_kurucu_pano_ezmez', async () => {
  const { c, cagri, bitir } = girisKur();
  const p = c.loadIstatistik();
  c.atolyeSekme('kurucu');
  bitir();
  await p;
  assert.deepStrictEqual(cagri, ['liste', 'kurucu'], 'liste dönünce pano açılmaz');
  assert.strictEqual(c.window._atolye.sekme, 'kurucu');
});

test('giris_onceki_sekme_kurucu_ayni_tik_de_sayilir', async () => {
  // Önceki ziyaretten sekme='kurucu' kalmış: değer karşılaştırması bu tıklamayı göremez.
  const { c, cagri, bitir } = girisKur();
  c.atolyeSekme('kurucu');
  cagri.length = 0;
  const p = c.loadIstatistik();
  c.atolyeSekme('kurucu');
  bitir();
  await p;
  assert.deepStrictEqual(cagri, ['liste', 'kurucu']);
});

test('giris_tiklama_yoksa_onceki_sekme_ne_olursa_pano', async () => {
  const { c, cagri, bitir } = girisKur();
  c.atolyeSekme('kurucu');
  cagri.length = 0;
  const p = c.loadIstatistik();
  bitir();
  await p;
  assert.deepStrictEqual(cagri, ['liste', 'pano'], 'her giriş panoyu açar (plan)');
  assert.strictEqual(c.window._atolye.sekme, 'pano');
});

test('giris_gec_liste_hatasi_kurucuya_serit_yazmaz', async () => {
  const { c, icerik, cagri, kir } = girisKur();
  const p = c.loadIstatistik();
  c.atolyeSekme('kurucu');
  kir(new Error('İnternet bağlantısı gerekli'));
  await p;
  assert.deepStrictEqual(cagri, ['liste', 'kurucu']);
  assert.ok(!icerik.html.includes('atolye-hata'), 'kurucu tanım kartı hatasını kendi tolere eder; eski girişin hatası yazılmaz');
});

test('giris_ust_uste_iki_giris_tek_pano', async () => {
  const { c, cagri, bitir } = girisKur();
  const giris = [c.loadIstatistik(), c.loadIstatistik()];
  bitir();
  await Promise.all(giris);
  assert.deepStrictEqual(cagri, ['liste', 'liste', 'pano'], 'ikinci yanıt panoyu yeniden yüklemez');
});

test('giris_bayat_serit_liste_cagrisindan_once_temizlenir', async () => {
  const { c, icerik, bitir } = girisKur({ html: '<div class="atolye-hata" role="status">eski hata</div><div class="atolye-kart"></div>' });
  icerik.classList.add('atolye-bayat');
  const p = c.loadIstatistik();
  assert.ok(!icerik.html.includes('eski hata'), 'liste beklenirken eski şerit kalmaz');
  assert.ok(!icerik.classList.contains('atolye-bayat'));
  bitir();
  await p;
});

test('hata_seridi_grafik_ham_kod_genel_metin', () => {
  const c = atolyeYukle();
  for (const kodMetni of ['STAT_GRAFIK:yok', 'STAT_GRAFIK:sira_kumesi', 'STAT_GRAFIK:bilinmeyen']) {
    const kok = sahteKok('');
    assert.strictEqual(c.atolyeHataSeridi(new Error(kodMetni), kok).tip, 'grafik');
    assert.strictEqual(seritMetni(kok), 'İstatistik alınamadı', kodMetni);
  }
});

test('hata_seridi_pano_cevirisi_oneksiz', () => {
  // Gerçek çağıran: pano.js çeviriyi yeni Error olarak verir, statHataKodu 'genel' döner. Metinler pano.js'ten okunur;
  // pano.js'te metin biçimi değişirse bu test kırılır (atolye.js tanıması buna bağlı).
  const kok = sahteKok('');
  const c = atolyeYukle({ _panoKok: () => kok, panoYukle: () => null });
  vm.runInContext(oku('js/istatistik/pano.js').match(/^const _PANO_GRAFIK_METIN = \{[\s\S]*?^\};/m)[0], c);
  vm.runInContext(extractFunctionSource('js/istatistik/pano.js', '_panoYazmaHatasi'), c);
  const beklenen = {
    'STAT_GRAFIK:yok': 'Grafik bulunamadı; liste yenilendi',
    'STAT_GRAFIK:sira_kumesi': 'Grafik listesi değişmiş; liste yenilendi',
    'STAT_GRAFIK:bilinmeyen': 'Grafik işlemi yapılamadı; liste yenilendi',
  };
  for (const [kodMetni, metin] of Object.entries(beklenen)) {
    c._panoYazmaHatasi(new Error(kodMetni));
    assert.strictEqual(seritMetni(kok), metin);
  }
});

test('hata_seridi_grafik_cevirisi_kacisli_ve_genel_onek_kalir', () => {
  const c = atolyeYukle();
  const kok = sahteKok('');
  c.atolyeHataSeridi(new Error('<b>; liste yenilendi'), kok);
  assert.strictEqual(seritMetni(kok), '&lt;b&gt;; liste yenilendi');
  c.atolyeHataSeridi(new Error('liste yenilendi değil'), kok);
  assert.strictEqual(seritMetni(kok), 'İstatistik alınamadı: liste yenilendi değil');
});

test('bayat_etiket_yalniz_canvas_varken', () => {
  const c = atolyeYukle();
  const kart = sahteKok('<div class="atolye-kart"><div class="loader"></div></div>');
  c.atolyeHataSeridi(new Error('Sunucuya ulaşılamıyor'), kart);
  assert.ok(kart.html.includes('İstatistik çevrimiçi hesaplanır'));
  assert.ok(!kart.html.includes('atolye-bayat-etiket'), 'çizim yokken "gösterilen sonuç bayat" yazılmaz');
  // pano.js:200 şeridi bu sınıfla temizler: çizimsiz kartta da sınıf kalır, yoksa şerit çevrimiçi dönüşte takılır.
  assert.ok(kart.classList.contains('atolye-bayat'));
});

test('atolye_sekme_ve_giris', async () => {
  const cagri = [];
  const dugme = s => {
    const sinif = new Set();
    return { dataset: { sekme: s }, attrs: {}, classList: { toggle: (c, f) => (f ? sinif.add(c) : sinif.delete(c)), contains: c => sinif.has(c) },
      setAttribute(a, v) { this.attrs[a] = v; } };
  };
  const d = [dugme('pano'), dugme('kurucu')];
  const icerik = sahteKok('');
  const document = {
    getElementById: id => ({ 'istatistik-root': {}, 'atolye-icerik': icerik }[id] || null),
    querySelectorAll: sec => (sec === '#atolye-sekmeler [data-sekme]' ? d : []),
  };
  const c = atolyeYukle({
    document,
    statOlcumListele: async () => { cagri.push('liste'); return []; },
    panoYukle: () => cagri.push('pano'),
    kurucuAc: cumle => cagri.push(['kurucu', cumle]),
  });
  await c.loadIstatistik();
  assert.deepStrictEqual(Object.keys(c.window._atolye), ['sekme', 'cumle', 'secenekler', 'gecici', 'sonZarflar', 'onceki', 'jeton']);
  assert.deepStrictEqual(JSON.parse(JSON.stringify(c.window._atolye)),
    { sekme: 'pano', cumle: null, secenekler: null, gecici: { ilac_fiyat: {} }, sonZarflar: null, onceki: [], jeton: 0 });
  assert.deepStrictEqual(cagri, ['liste', 'pano']);
  assert.ok(d[0].classList.contains('on') && !d[1].classList.contains('on'));
  c.window._atolye.cumle = { v: 1 };
  c.atolyeSekme('kurucu');
  assert.deepStrictEqual(JSON.parse(JSON.stringify(cagri[2])), ['kurucu', { v: 1 }]);
  assert.ok(d[1].classList.contains('on') && d[1].attrs['aria-selected'] === 'true' && d[0].attrs['aria-selected'] === 'false');
  // ölçüm listesi alınamazsa şerit basılır, pano yine açılır; durum korunur
  cagri.length = 0;
  c.statOlcumListele = async () => { throw new Error('İnternet bağlantısı gerekli'); };
  await c.loadIstatistik();
  assert.ok(icerik.html.includes('İstatistik çevrimiçi hesaplanır'));
  assert.deepStrictEqual(cagri, ['pano']);
  assert.deepStrictEqual(JSON.parse(JSON.stringify(c.window._atolye.cumle)), { v: 1 }, 'kurucu cümlesi korunur');
});

test('stub_imzalari', () => {
  const beklenen = {
    'js/istatistik/kurucu.js': { kurucuAc: 1, kurucuSlotDegis: 2, kurucuYenile: 0, kurucuCumlePanelHtml: 2, kurucuKartHtml: 3, kurucuVakalarAc: 1, kurucuKaydet: 0 },
    'js/istatistik/kombinasyon.js': { kombinasyonHtml: 1, kombinasyonBagla: 1 },
    'js/istatistik/gecici-fiyat.js': { geciciFiyatPanelHtml: 2, geciciFiyatOku: 1, geciciFiyatBagla: 1 },
    'js/istatistik/pano.js': { panoYukle: 0, panoKartHtml: 3, panoSiralaModu: 1, panoTasi: 3 },
  };
  for (const [dosya, fnler] of Object.entries(beklenen)) {
    const metin = oku(dosya);
    assert.ok(/^\/\/ js\/istatistik\//.test(metin) && metin.includes("'use strict'"), dosya + ' başlık + use strict');
    const M = require(path.join(KOK, dosya));
    for (const [ad, uz] of Object.entries(fnler)) {
      assert.strictEqual(typeof M[ad], 'function', dosya + ': ' + ad);
      assert.strictEqual(M[ad].length, uz, ad + ' parametre sayısı');
    }
  }
  // Yalnız plan sözleşmesi olan dönüşler (T13 "komb null → ''", T14 "dizi boşsa ''"); stub gövdeleri pinlenmez.
  assert.strictEqual(require(path.join(KOK, 'js/istatistik/kombinasyon.js')).kombinasyonHtml(null, {}), '');
  assert.strictEqual(require(path.join(KOK, 'js/istatistik/gecici-fiyat.js')).geciciFiyatPanelHtml([], {}), '');
});

test('css_kirmizi_amber_yok_ve_yasak_kelime', () => {
  const bas = HTML.indexOf('/* ═══ İSTATİSTİK');
  assert.ok(bas > 0);
  const css = HTML.slice(bas, HTML.indexOf('</style>', bas));
  assert.ok(!/var\(--red\)|#fff8e1|#b26a00|#ffe082|\.stat-hata|\.stat-yetersiz/.test(css), 'kırmızı/amber kural yok');
  assert.ok(!/#[0-9a-f]{3,6}\b/i.test(css), 'sabit hex yok — tema değişkenleri');
  assert.ok(/@media\s*\(min-width:\s*1024px\)[^@]*\.atolye-kurucu\{[^}]*360px/.test(css), 'masaüstü kurucu 360px + kartlar');
  assert.ok(/\.atolye-grafik\{[^}]*position:relative[^}]*width:100%/.test(css), 'canvas sarmalayıcı');
  for (const f of ['atolye', 'kurucu', 'kombinasyon', 'gecici-fiyat', 'pano']) {
    const m = oku(`js/istatistik/${f}.js`);
    assert.ok(!/protokol/i.test(m), f + ': protokol kelimesi yok');
    assert.ok(!/sağla|etkili|karşılığı/i.test(m), f + ': nedensellik fiili yok');
  }
});

// ── TFC (T16 G4-G6): CSS metin testleri. Tarayıcı ölçümü T16 yeniden koşumunda. ──
function atolyeCss() {
  const bas = HTML.indexOf('/* ═══ İSTATİSTİK');
  assert.ok(bas > 0);
  return HTML.slice(bas, HTML.indexOf('</style>', bas));
}
// `@media (<kosul>){...}` gövdesi (iç içe süslü parantez sayılır).
function medyaGovde(css, kosul) {
  const bas = css.indexOf(`@media (${kosul}){`);
  assert.ok(bas >= 0, 'media yok: ' + kosul);
  let i = css.indexOf('{', bas) + 1, derin = 1;
  const ilk = i;
  while (derin && i < css.length) { if (css[i] === '{') derin++; else if (css[i] === '}') derin--; i++; }
  return css.slice(ilk, i - 1);
}
// Seçici birebir (virgül listesinin bir üyesi) geçen kuralların bildirimleri, birleşik.
function kural(css, secici) {
  let d = '';
  for (const m of css.replace(/\/\*[\s\S]*?\*\//g, '').matchAll(/([^{}]+)\{([^{}]*)\}/g)) {
    if (m[1].split(',').map(s => s.trim()).includes(secici)) d += m[2] + ';';
  }
  return d;
}
function degiskenler(blok) {
  const v = {};
  for (const m of blok.matchAll(/(--[a-z0-9]+):\s*(#[0-9a-f]{6})/gi)) v[m[1]] = m[2];
  return v;
}
function temalar() {
  const kok = degiskenler(HTML.match(/:root\{([\s\S]*?)\}/)[1]);
  return { acik: kok, koyu: { ...kok, ...degiskenler(HTML.match(/body\.dark\{([\s\S]*?)\}/)[1]) } };
}
function kontrast(a, b) {
  const lum = hex => {
    const k = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16) / 255)
      .map(c => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
    return 0.2126 * k[0] + 0.7152 * k[1] + 0.0722 * k[2];
  };
  const [u, d] = [lum(a), lum(b)].sort((x, y) => y - x);
  return (u + 0.05) / (d + 0.05);
}
function renkTok(bildirim) {
  const m = bildirim.match(/(?:^|;)\s*color:var\((--[a-z0-9]+)\)/);
  assert.ok(m, 'color:var(--x) yok: ' + bildirim);
  return m[1];
}
const baslikSatiri = () => pgIstatistik().slice(0, pgIstatistik().indexOf('id="istatistik-root"'));

test('g4_baslik_kontrast_iki_temada_en_az_4_5', () => {
  const css = atolyeCss();
  const t = temalar();
  // Kök neden pini: --bg iki temada da koyu, sayfanın kendi zemini yok; --ink açık temada koyu.
  assert.ok(/html,body\{[^}]*background:var\(--bg\)/.test(HTML), 'zemin body --bg');
  assert.strictEqual(t.acik['--bg'], t.koyu['--bg'], '--bg tema ile değişmiyor');
  const bas = baslikSatiri();
  assert.ok(!/background/.test(bas), 'başlık satırı kendi zeminini koymaz');
  assert.ok(!/color:/.test(bas.match(/atolye-sayfa-baslik"[^>]*>/)[0]), 'başlık rengi satır içi değil');
  assert.ok(!/background/.test(kural(css, '.atolye-sayfa-baslik') + kural(css, '#pg-istatistik')), 'zemin eklenmedi');
  const acik = renkTok(kural(css, '.atolye-sayfa-baslik'));
  const koyu = renkTok(kural(css, 'body.dark .atolye-sayfa-baslik'));
  const zemin = t.acik['--bg'];
  assert.ok(kontrast(t.acik[acik], zemin) >= 4.5, `açık ${acik}: ${kontrast(t.acik[acik], zemin).toFixed(2)}`);
  assert.ok(kontrast(t.koyu[koyu], zemin) >= 4.5, `koyu ${koyu}: ${kontrast(t.koyu[koyu], zemin).toFixed(2)}`);
});

test('g4_kontrast_hesabi_t16_olcumunu_verir', () => {
  // T16 U1b ham ölçümü: --ink / --bg açık=1,06:1, koyu=14,25:1. Hesap aracı buna göre sınanır.
  const t = temalar();
  assert.strictEqual(kontrast(t.acik['--ink'], t.acik['--bg']).toFixed(2), '1.06');
  assert.strictEqual(kontrast(t.koyu['--ink'], t.koyu['--bg']).toFixed(2), '14.25');
});

test('g4_geri_dugmesi_kalipta_tam_genislik_degil', () => {
  const bas = baslikSatiri();
  assert.ok(bas.includes('border-bottom:1px solid var(--bg3)'), 'kalıp ayırıcı: --bg3 (pg-ovsync, pg-asistan)');
  const dugme = bas.match(/<button[^>]*nav-geri[^>]*>/)[0];
  // .btn tek başına display:block;width:100%: flex satırda başlığı ezer. .btn-sm width:auto.
  assert.ok(/class="btn btn-sm"/.test(dugme), '.btn-sm şart: ' + dugme);
  assert.ok(/\.btn-sm\{[^}]*width:auto/.test(HTML), '.btn-sm width:auto');
  assert.ok(dugme.includes('padding:5px 10px'), 'kalıp dolgusu');
});

test('g5_dar_ekranda_dokunma_en_az_36px', () => {
  const m = medyaGovde(atolyeCss(), 'max-width:600px');
  for (const s of ['#pg-istatistik button', '#pg-istatistik select', '#pg-istatistik input:not([type=checkbox])',
    '.atolye-cip', '.atolye-onay', '.atolye-ayrinti summary']) {
    assert.ok(/min-height:36px/.test(kural(m, s)), 'min-height:36px yok: ' + s);
  }
  // span.atolye-cip ("Biz") düğme gibi kendiliğinden ortalanmaz.
  assert.ok(/align-items:center/.test(kural(m, '.atolye-cip')), 'çip yazısı ortalı');
  assert.ok(/padding:10px 0/.test(kural(m, '.atolye-ayrinti summary')), 'özet yazısı dolguyla ortalı');
  // TFA sonrası .atolye-tanim düz <div>; özeti Ayrıntı'nın.
  assert.ok(!/<details class="atolye-tanim"/.test(oku('js/istatistik/kurucu.js')), 'tanım details değil');
  assert.ok(!/\.atolye-tanim summary/.test(atolyeCss()), 'ölü seçici yok');
});

test('g5_kontroller_dugme_etiketinde_kural_kapsaminda', () => {
  // Dokunma kuralı #pg-istatistik button etiketine bağlı; bağlantı/eylem sınıfları <button> dışına çıkarsa kural tutmaz.
  for (const f of ['kurucu', 'pano', 'kombinasyon', 'gecici-fiyat']) {
    const m = oku(`js/istatistik/${f}.js`);
    for (const s of m.matchAll(/<([a-z]+)\b[^>]*class="[^"]*atolye-(?:eylem|btn-ana|baglanti)\b[^"]*"/g)) {
      assert.strictEqual(s[1], 'button', `${f}: ${s[0]}`);
    }
  }
});

test('g5_masaustu_kurallari_degismez', () => {
  const css = atolyeCss();
  const dis = css.replace(medyaGovde(css, 'max-width:600px'), '');
  assert.ok(!/min-height/.test(dis), 'dokunma yüksekliği yalnız ≤600px');
  const beklenen = {
    '.atolye-sekmeler button': 'padding:6px 16px', '.atolye-eylem': 'padding:6px 12px', '.atolye-cip': 'padding:5px 10px',
    '.atolye-baglanti': 'padding:0', '.atolye-onay': 'padding:3px 0', '.atolye-slot select': 'padding:5px 8px',
  };
  for (const [s, d] of Object.entries(beklenen)) assert.ok(kural(dis, s).includes(d), `${s}: ${d}`);
});

test('g6_panel_kaydet_ve_yeniden_hesapla_kaydirmadan', () => {
  const css = atolyeCss();
  const m = medyaGovde(css, 'min-width:1024px');
  const panel = kural(m, '.atolye-cumle-panel');
  assert.ok(/position:sticky/.test(panel) && /top:8px/.test(panel), 'panel sticky kalır');
  assert.ok(/overflow-y:auto/.test(panel), 'panel kendi içinde kayar');
  const h = panel.match(/max-height:calc\(100vh - (\d+)px\)/);
  assert.ok(h, 'max-height:calc(100vh - Npx): ' + panel);
  // T16 E9 ham: kaydırma 0'da panelUst=231 (900 px viewport). Panel altı viewport içinde kalmalı.
  assert.ok(231 + (900 - Number(h[1])) <= 900, 'kaydırma 0 da panel altı görünür: üst=' + h[1]);
  const alt = kural(m, '.atolye-cumle-panel>.atolye-panel-alt');
  assert.ok(/position:sticky/.test(alt) && /bottom:0/.test(alt), 'eylem satırı panel altına yapışır');
  assert.ok(/background:var\(--card\)/.test(alt), 'altından kayan yazı görünmez (kartla aynı zemin)');
  // Pano kartı ve geçici fiyat da .atolye-panel-alt kullanır; onlara sızmasın.
  assert.ok(!/sticky/.test(kural(css, '.atolye-panel-alt')), 'yapışma yalnız panel içi');
  assert.ok(!/sticky|max-height/.test(medyaGovde(css, 'max-width:600px')), 'dar ekranda yok');
});

test('tfa_siniflari_ayrinti_veri_az_pano_pasif', () => {
  const css = atolyeCss();
  const ay = kural(css, '.atolye-ayrinti summary');
  assert.ok(/cursor:pointer/.test(ay) && renkTok(ay) === '--ink3', 'özet tıklanır, sakin');
  assert.ok(kural(css, '.atolye-ayrinti') && !/background/.test(kural(css, '.atolye-ayrinti')), 'ayrıntı zeminsiz');
  const az = kural(css, '.atolye-veri-az');
  assert.ok(renkTok(az) === '--ink3' && /font-size:11px/.test(az), 'veri az küçük, sakin');
  assert.ok(!/background|border/.test(az), 'veri az zemin/kutu yok');
  assert.ok(/align-items:start/.test(kural(css, '.atolye-pano')), 'pano kartı gerilmez');
  // .atolye-sira button{cursor:pointer} daha özgül: ▲/▼ için ayrı seçici şart.
  for (const s of ['.atolye-pasif', '.atolye-sira button.atolye-pasif']) {
    assert.ok(/cursor:not-allowed/.test(kural(css, s)), 'pasif imleç: ' + s);
  }
  assert.ok(/opacity:\.55/.test(kural(css, '.atolye-pasif')), 'pasif soluk');
});

// ── TFB G8 ──
test('e14_cevrimdisi_sinif_icerik_olmadan_da_kalkar_tipi_tasir', () => {
  const c = atolyeYukle();
  const bos = sahteKok('');
  c.atolyeHataSeridi(new Error('İnternet bağlantısı gerekli'), bos);
  assert.ok(bos.classList.contains('atolye-bayat'), 'ilk çevrimdışı giriş: kart yok, sınıf yine kurulur');
  assert.ok(!bos.html.includes('atolye-bayat-etiket'), 'çizim yokken etiket yok');
  // aynı şerit başka tipe dönünce sınıf düşer: liste başarısı bu şeridi silmemeli
  c.atolyeHataSeridi(new Error('Grafik bulunamadı; liste yenilendi'), bos);
  assert.ok(!bos.classList.contains('atolye-bayat'));
  c.atolyeHataSeridi(new Error('İnternet bağlantısı gerekli'), bos);
  assert.ok(bos.classList.contains('atolye-bayat'));
  c.atolyeHataSeridi(new Error('STAT_GRAFIK:yok'), bos);
  assert.ok(!bos.classList.contains('atolye-bayat'), 'ham kod da çevrimdışı değil');
});

function sekmeKur() {
  const icerik = sahteKok('');
  const cizimler = [];
  const canvas = () => {
    const cv = { __chart: { destroy() { cv.yokEdildi = (cv.yokEdildi || 0) + 1; } } };
    cizimler.push(cv);
    return cv;
  };
  const c = atolyeYukle({
    document: { getElementById: id => ({ 'atolye-icerik': icerik }[id] || null), querySelectorAll: () => [] },
    panoYukle: () => null,
    kurucuAc: () => null,
  });
  return { c, icerik, canvas, cizimler };
}

test('e13_sekme_degisince_onceki_ekranin_grafikleri_yok_edilir', () => {
  const { c, icerik, canvas } = sekmeKur();
  c.atolyeSekme('pano');
  const a = canvas();
  icerik.canvaslar = [a, { __chart: null }];                 // çizimsiz canvas da olabilir
  c.atolyeSekme('kurucu');
  assert.strictEqual(a.yokEdildi, 1, 'pano→kurucu');
  assert.strictEqual(a.__chart, null, 'çift destroy olmasın');
  const b = canvas();
  icerik.canvaslar = [b];
  c.atolyeSekme('pano');
  assert.strictEqual(b.yokEdildi, 1, 'kurucu→pano');
});

test('e13_ayni_sekmeye_basis_grafik_yok_etmez', () => {
  const { c, icerik, canvas } = sekmeKur();
  c.atolyeSekme('pano');
  const a = canvas();
  icerik.canvaslar = [a];
  c.atolyeSekme('pano');
  assert.strictEqual(a.yokEdildi, undefined);
});
