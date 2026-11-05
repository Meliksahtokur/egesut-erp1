// js/istatistik/grafik.js
// İstatistik Atölyesi AP1 (T10): stat_atolye_seri zarfı → durum, durum metni, betimsel özet ve
// Chart.js 4.x yapılandırması (spec §4.5, §4.6, §4.8; plan Task 10).
//
// SÖZLEŞME (migration 20261017000002 stat_atolye_seri, zarf başına):
//   {olcum, n (1. grubun n'i), x: {ad: 'grup'|'ay'|'ceyrek'|'yil', deger[], anahtar[]},
//    seriler: kırılımsız/ilaç → tek seri, diziler (n,k,y,alt,ust,q1,q3) grup sırasında;
//             zaman → grup başına bir seri {ad, anahtar, ...}, diziler periyot sırasında (boş periyot n=0, y=null),
//    sayac: {acik_n, olgunlasmamis_n, fiyatsiz_n, ilacsiz_n, kapali_tarihsiz_n, kiyas_n (2. grup; yoksa null), ...},
//    dipnot[] (SQL üretir, burada üretilmez/değiştirilmez), fiyat_kaynagi: gecici|kayitli|fiyatsiz|null, egri}
//
// HESAP YOK (SK-7): sayılar sunucudan gelir; bu dosya yalnız çevirir. n<5 hücre sunucuda y=null gelir.
// Saf fonksiyonlar DOM'a dokunmaz; yalnız grafikCiz ve temaRenkleri DOM/Chart kullanır.
// Renk yalnız tema değişkenlerinden (temaRenkleri); 1. grup vurgu, diğerleri kıyas, yetersiz gri.
// Metinler betimseldir (M5): nedensellik fiili yok.
'use strict';

const _GRAFIK_ESIK = 5;   // K8
const _GRAFIK_TL = ['saglik_vaka_tl', 'saglik_basari_tl'];
const _GRAFIK_SURE = ['saglik_kapanma_gunu', 'saglik_tedavi_suresi'];
const _GRAFIK_ZAMAN = ['ay', 'ceyrek', 'yil'];
const _GRAFIK_SATIR_PX = 24;    // yatay çubukta grup başına satır
const _GRAFIK_EKSEN_PX = 40;    // x ekseni ve kenar payı
const _GRAFIK_TABAN_PX = 240;   // .atolye-grafik CSS yüksekliği; altına inilmez
// Tek geri alma noktası (TF G1, sahip S2 açık): false → süzme, sıra, n metni, rozet, "veri az" satırı eski davranışa döner.
const _GRAFIK_YETERLI_GRUPLAR = true;
const _GRAFIK_BILINMIYOR = 'ilac:(bilinmiyor)';
const _GRAFIK_MEDYAN_BOY = 9;    // medyan işaretinin yarı boyu (px)
const _GRAFIK_BIYIK_UC = 5;      // aralık ucunun yarı boyu (px)
const _GRAFIK_Y_BOSLUK = 14;     // y ekseni çentiği + iki yan boşluk (Chart.js varsayılanı)
const _GRAFIK_ZAMAN_EYLEM = { ay: { etiket: 'Çeyreklik göster', deger: 'ceyrek' }, ceyrek: { etiket: 'Yıllık göster', deger: 'yil' } };

function _grafikSayi(v, ond) {
  return Number(v).toLocaleString('tr-TR', { minimumFractionDigits: ond, maximumFractionDigits: ond });
}

function _grafikZamanMi(zarf) {
  return !!(zarf && zarf.x && _GRAFIK_ZAMAN.indexOf(zarf.x.ad) !== -1);
}

function _grafikToplam(dizi) {
  return (dizi || []).reduce((t, v) => t + (Number(v) || 0), 0);
}

function _grafikRenk(i, y, tema) {
  if (y === null || y === undefined) return tema.gri;
  return i === 0 ? tema.vurgu : tema.kiyas;
}

function _grafikDolu(v) { return v !== null && v !== undefined; }

// Satır metni. ₺ ölçüsünde fiyatsız vaka n'e girmez: "veri az" fiyatsız ilacı <5 vakalı gibi okuturdu (kısmi geçici fiyat).
function _grafikAzMetin(zarf, az) {
  if (!az.length) return '';
  const satir = g => `${g.ad} ${g.n}`;
  if (_GRAFIK_TL.indexOf(zarf.olcum) === -1 || !(Number((zarf.sayac || {}).fiyatsiz_n) > 0)) {
    return `${az.length} ilaçta veri az (<${_GRAFIK_ESIK} vaka): ${az.map(satir).join(' · ')}`;
  }
  const birim = zarf.olcum === 'saglik_basari_tl' ? 'fiyatlı başarılı vaka' : 'fiyatlı vaka';
  const azVar = az.filter(g => g.n > 0);
  const hic = az.filter(g => !g.n);
  return [azVar.length ? `${azVar.length} ilaçta ${birim} az (<${_GRAFIK_ESIK}): ${azVar.map(satir).join(' · ')}` : '',
    hic.length ? `${hic.length} ilaçta ${birim} yok: ${hic.map(g => g.ad).join(' · ')}` : ''].filter(Boolean).join('. ');
}

/**
 * İlaç kırılımı (x.anahtar hepsi 'ilac:…', SQL stat_atolye_gruplar_k): çizilecek gruplar ve "veri az" gruplar.
 * Yeterli = sunucunun y doldurduğu hücre (n<5 kuralı SQL'de). Sıra: başarı yüksekten düşüğe, süre ve ₺ küçükten büyüğe,
 * eşitlikte n büyük önce; (bilinmiyor) her ölçüde son (SQL sırası, vurgu ve özet ona gitmez). Girdi değişmez. İlaç kırılımı değilse (ya da sabit kapalıysa) zarf olduğu gibi döner, rozet null.
 */
function grafikGruplariHazirla(zarf) {
  const x = (zarf && zarf.x) || {};
  const anahtar = x.anahtar || [];
  if (!_GRAFIK_YETERLI_GRUPLAR || x.ad !== 'grup' || !anahtar.length || !anahtar.every(a => String(a).startsWith('ilac:'))) {
    return { cizilen: zarf, azGruplar: [], rozet: null, azMetin: '' };
  }
  const s = (zarf.seriler || [])[0] || {};
  const y = s.y || [];
  const n = i => Number((s.n || [])[i]) || 0;
  const yon = zarf.olcum === 'saglik_basari' ? -1 : 1;
  const son = a => (a === _GRAFIK_BILINMIYOR ? 1 : 0);
  const sira = anahtar.map((_, i) => i).filter(i => _grafikDolu(y[i]))
    .sort((a, b) => son(anahtar[a]) - son(anahtar[b]) || yon * (Number(y[a]) - Number(y[b])) || n(b) - n(a));
  const azGruplar = anahtar.map((a, i) => ({ anahtar: a, ad: _cumleIlacEtiket(String(a).slice(5)), n: n(i) }))
    .filter((_, i) => !_grafikDolu(y[i])).sort((a, b) => son(a.anahtar) - son(b.anahtar) || b.n - a.n);
  const sec = d => sira.map(i => d[i]);
  const seri = {};
  Object.keys(s).forEach(k => { seri[k] = Array.isArray(s[k]) ? sec(s[k]) : s[k]; });
  return {
    cizilen: Object.assign({}, zarf, { n: sira.length ? n(sira[0]) : 0, seriler: [seri],
      x: Object.assign({}, x, { deger: sec(x.deger || []), anahtar: sec(anahtar) }) }),
    azGruplar,
    rozet: `${sira.length}/${anahtar.length} ilaçta yeterli veri`,
    azMetin: _grafikAzMetin(zarf, azGruplar),
  };
}

/** İlaç kartı rozeti; null = ilaç kırılımı değil. veri_yok ve fiyat_yok kartında boş: "0/N" orada başka bir eksiği söylerdi. */
function grafikRozet(zarf, durum) {
  const r = grafikGruplariHazirla(zarf).rozet;
  return r && (durum === 'veri_yok' || durum === 'fiyat_yok') ? '' : r;
}

/** Bu durumda kartta grafik çizilir mi (kurucu, pano ve dipnot ayrımı aynı tanımı kullanır). */
function grafikCizilir(durum) { return durum === 'tamam' || durum === 'kontrast_yok'; }

// S4: kartta görünür kalacak dipnotlar; metin sunucudan. Grafik çizilmeyen kartta hepsi Ayrıntı'da kalır.
function grafikDipnotAyir(zarf, durum) {
  const tum = zarf && Array.isArray(zarf.dipnot) ? zarf.dipnot : [];
  const uyari = grafikCizilir(durum) ? tum.filter(d => /örtüş|gözlemsel/i.test(d)) : [];
  return { uyari: uyari.join(' '), kalan: tum.filter(d => !uyari.includes(d)) };
}

// Zaman: en dolu serinin n≥5 nokta sayısı (<2 ise çizgi okunmaz, E1).
function _grafikDoluNokta(zarf) {
  return Math.max(0, ...(zarf.seriler || []).map(s => (s.y || []).filter(_grafikDolu).length));
}

/** Zarfın ekran durumu: veri_yok | yetersiz | fiyat_yok | zaman_seyrek | kontrast_yok | tamam (spec §4.8). */
function zarfDurum(zarf, cumle) {
  if (!zarf) return 'veri_yok';
  const seriler = zarf.seriler || [];
  const sayac = zarf.sayac || {};
  const ilk = seriler[0] || {};
  const h = grafikGruplariHazirla(zarf);
  const ilkY = _grafikZamanMi(zarf) ? (ilk.y || []) : [(((h.cizilen.seriler || [])[0] || {}).y || [])[0]];
  // ₺: fiyatsız vaka ₺ kümesine hiç girmez → tüm n=0 gelir; fiyat eylemi "vaka yok"tan önce (RULING-ÖNERİ T10-1)
  if (_GRAFIK_TL.indexOf(zarf.olcum) !== -1 && Number(sayac.fiyatsiz_n) > 0 &&
      (zarf.fiyat_kaynagi === 'fiyatsiz' || ilkY.every(v => v === null || v === undefined))) return 'fiyat_yok';
  if (seriler.every(s => _grafikToplam(s.n) === 0)) return 'veri_yok';
  const n = h.cizilen.n !== undefined && h.cizilen.n !== null ? Number(h.cizilen.n) : _grafikToplam(ilk.n);
  if (n < _GRAFIK_ESIK) return 'yetersiz';
  if (_grafikZamanMi(zarf) && _grafikDoluNokta(zarf) < 2) return 'zaman_seyrek';
  // karşı grup yalnız x seçiliyken vardır; ilaç kırılımında 2. satır başka bir ilaçtır (RULING-ÖNERİ T10-2)
  const xVar = !h.rozet && (!cumle || !cumle.ilac || (cumle.ilac.x !== null && cumle.ilac.x !== undefined));
  if (xVar && sayac.kiyas_n !== null && sayac.kiyas_n !== undefined && Number(sayac.kiyas_n) < _GRAFIK_ESIK) {
    return 'kontrast_yok';
  }
  return 'tamam';
}

/** Doz ölçüsü (P8, V16): istemci durum kartı; RPC çağrılmaz. */
function dozMetni() {
  return 'Doz verisi yok: uygulamalar ml olarak kayıtlı, hayvan ağırlığı yok; doz kıyası yapılamaz.';
}

// Dönemi büyüten eylem; dönem zaten en genişse yok.
function _grafikDonemEylem(cumle) {
  const donem = (cumle && cumle.donem) || {};
  if (donem.tip === 'tumu') return null;
  if (donem.tip === 'son_ay' && Number(donem.n) >= 24) return { etiket: 'Tüm zamanlar', slot: 'donem', deger: { tip: 'tumu' } };
  return { etiket: 'Dönemi 24 aya çıkar', slot: 'donem', deger: { tip: 'son_ay', n: 24 } };
}

/** Durum kartı metni + eylem (spec §4.8 birebir). Eylem slot'u kurucuya gider. */
function durumMetni(durum, zarf, cumle) {
  const sayac = (zarf && zarf.sayac) || {};
  if (durum === 'yetersiz') {
    return { metin: `Yetersiz veri (n=${(zarf && zarf.n) || 0}) — en az 5 vaka gerekir`, eylem: _grafikDonemEylem(cumle) };
  }
  if (durum === 'zaman_seyrek') {
    const sonraki = _GRAFIK_ZAMAN_EYLEM[((zarf && zarf.x) || {}).ad];
    // Dolu noktası olmayan seri cümleye girmez: _grafikGruplar onun boş periyoduna düşerdi.
    const seriler = zarf.seriler.filter(s => (s.y || []).some(_grafikDolu));
    const ozet = seriler.length ? `${zarfOzetCumle(Object.assign({}, zarf, { seriler }))} ` : '';
    return { metin: `${ozet}Çizgi için en az 2 dönemde ${_GRAFIK_ESIK} vaka gerekir.`,
      eylem: sonraki ? { etiket: sonraki.etiket, slot: 'kirilim', deger: sonraki.deger } : _grafikDonemEylem(cumle) };
  }
  if (durum === 'veri_yok') {
    return { metin: 'Bu seçimde vaka yok', eylem: { etiket: 'Son seçimi geri al', slot: 'geri', deger: null } };
  }
  if (durum === 'fiyat_yok') {
    return { metin: `${sayac.fiyatsiz_n || 0} vakanın ilaç fiyatı yok`,
      eylem: { etiket: 'Fiyat gir', slot: 'fiyat_panel', deger: null } };
  }
  if (durum === 'kontrast_yok') {
    return { metin: `Karşı grup çok küçük (n=${sayac.kiyas_n || 0})`,
      eylem: { etiket: 'Ek ilaç ekseninde kıyasla', slot: 'kombinasyon', deger: null } };
  }
  if (durum === 'doz') return { metin: dozMetni(), eylem: null };
  if (durum === 'cevrimdisi') return { metin: 'İstatistik çevrimiçi hesaplanır', eylem: null };
  return { metin: '', eylem: null };
}

const _GRAFIK_GUN = {
  deger: y => `${_grafikSayi(y, 1)} gün`,
  fark: (a, b) => (a === b ? 'fark yok' : `${_grafikSayi(Math.abs(a - b), 1)} gün daha ${a < b ? 'kısa' : 'uzun'}`),
};
const _GRAFIK_TL_BIC = {
  deger: y => `₺${_grafikSayi(y, 2)}`,
  fark: (a, b) => (a === b ? 'fark yok' : `₺${_grafikSayi(Math.abs(a - b), 2)} ${a > b ? 'yüksek' : 'düşük'}`),
};
const _GRAFIK_OZET = {
  saglik_basari: { bas: 'Başarı', deger: y => `%${_grafikSayi(y, 1)}`, fark: (a, b) => `fark ${_grafikSayi(Math.abs(a - b), 1)} puan` },
  saglik_kapanma_gunu: Object.assign({ bas: 'Medyan kapanma' }, _GRAFIK_GUN),
  saglik_tedavi_suresi: Object.assign({ bas: 'Medyan tedavi süresi' }, _GRAFIK_GUN),
  saglik_vaka_tl: Object.assign({ bas: 'Medyan vaka maliyeti' }, _GRAFIK_TL_BIC),
  saglik_basari_tl: Object.assign({ bas: 'Başarı başına maliyet' }, _GRAFIK_TL_BIC),
};

// Özet için grup listesi: kırılımsız/ilaç → grup başına bir hücre; zaman → tüm seriler TEK periyotta:
// iki seride ikisinin de dolu olduğu son periyot (farklı aylar kıyaslanmaz, KF2-B1); yoksa 1. serinin son dolu periyodu.
function _grafikGruplar(zarf) {
  const x = zarf.x || {};
  const seriler = zarf.seriler || [];
  const hucre = (s, i, ad) => ({ ad, y: (s.y || [])[i], k: (s.k || [])[i], n: (s.n || [])[i] });
  if (!_grafikZamanMi(zarf)) return (x.deger || []).map((ad, i) => hucre(seriler[0] || {}, i, ad));
  const dolu = (s, i) => (s.y || [])[i] !== null && (s.y || [])[i] !== undefined;
  const son = ss => { let i = ((seriler[0] || {}).y || []).length - 1; while (i > 0 && !ss.every(s => dolu(s, i))) i -= 1; return i; };
  const ilk = seriler.slice(0, 1);
  let i = son(seriler.length === 2 ? seriler : ilk);
  if (seriler.length === 2 && !seriler.every(s => dolu(s, i))) i = son(ilk);
  return seriler.map(s => hucre(s, i, `${s.ad} ${(x.deger || [])[i] || ''}`.trim()));
}

/** Betimsel tek cümle (M5); kart altında ve canvas aria-label'ında. Sayılar tr-TR. */
function zarfOzetCumle(zarf) {
  const b = zarf && _GRAFIK_OZET[zarf.olcum];
  if (!b) return '';
  const g = _grafikGruplar(grafikGruplariHazirla(zarf).cizilen);
  if (!g.length) return `${b.bas}: vaka yok.`;
  const yok = h => h.y === null || h.y === undefined;
  const deger = h => (yok(h) ? `yetersiz veri (n=${h.n || 0})` : b.deger(h.y));
  if (g.length === 2) {
    const [a, c] = g;
    const fark = yok(a) || yok(c) ? '' : ` (${b.fark(Number(a.y), Number(c.y))})`;
    return `${b.bas} ${a.ad} ${deger(a)}, ${c.ad} ${deger(c)}${fark}.`;
  }
  const a = g[0];
  const kn = zarf.olcum === 'saglik_basari' && !yok(a) ? ` (${a.k}/${a.n})` : '';
  const ek = g.length > 2 ? ` ${g.length - 1} grup daha grafikte.` : '';
  return `${b.bas} ${a.ad}: ${deger(a)}${kn}.${ek}`;
}

// Aralık ve medyan çubuğun üstünde (TKF4): Chart.js ilk veri setini en üste koyar, bu izler çubuğun altında kalırdı.
// Hale kart zemini rengindedir: koyu temada metin/yeşil karşıtlığı 2,8:1 kalıyor; çubuk dışında zeminle birleşir.
const _GRAFIK_ISARET_EKLENTI = {
  id: 'atolyeIsaret',
  afterDatasetsDraw(chart) {
    const ctx = chart.ctx;
    const px = v => chart.scales.x.getPixelForValue(v);
    const ciz = (seg, renk, kalin) => seg.forEach(([x1, y1, x2, y2]) => {
      ctx.strokeStyle = renk;
      ctx.lineWidth = kalin;
      ctx.beginPath();
      ctx.moveTo(x1, y1);
      ctx.lineTo(x2, y2);
      ctx.stroke();
    });
    chart.data.datasets.forEach((d, di) => {
      if (!d.isaret) return;
      chart.getDatasetMeta(di).data.forEach((el, i) => {
        const v = d.data[i];
        if (!v) return;
        let seg;
        if (d.isaret === 'medyan') seg = [[el.x, el.y - _GRAFIK_MEDYAN_BOY, el.x, el.y + _GRAFIK_MEDYAN_BOY]];
        else {
          const [a, u] = [px(v[0]), px(v[1])];
          seg = [[a, el.y, u, el.y], ...[a, u].map(x => [x, el.y - _GRAFIK_BIYIK_UC, x, el.y + _GRAFIK_BIYIK_UC])];
        }
        const kalin = d.isaret === 'medyan' ? 3 : 2;
        ctx.save();
        ciz(seg, d.haleRenk, kalin + 2);
        ciz(seg, d.isaretRenk, kalin);
        ctx.restore();
      });
    });
  },
};

// Satır etiketi (TKF4): değer doğrudan yazılır; n<5 hücre (y=null) boş kalır.
function _grafikSatirEtiket(olcum, s, i) {
  const y = (s.y || [])[i];
  if (!_grafikDolu(y)) return '';
  const v = Number(y);
  const n = (s.n || [])[i] || 0;
  if (olcum === 'saglik_basari') return `%${_grafikSayi(v, 0)} · ${(s.k || [])[i] || 0}/${n}`;
  if (_GRAFIK_SURE.indexOf(olcum) !== -1) return `${v.toLocaleString('tr-TR', { maximumFractionDigits: 1 })} gün · n=${n}`;
  return `₺${_grafikSayi(v, Number.isInteger(v) ? 0 : 2)} · n=${n}`;
}

// Çubuk ucu metni: metinX değerinin (bıyık ucu ya da çubuk) sağına yazar.
const _GRAFIK_METIN_EKLENTI = {
  id: 'atolyeCubukMetin',
  afterDatasetsDraw(chart) {
    const ctx = chart.ctx;
    const eksen = chart.scales.x;
    chart.data.datasets.forEach((d, di) => {
      if (!d.metinler) return;
      chart.getDatasetMeta(di).data.forEach((el, i) => {
        if (d.data[i] === null || d.data[i] === undefined || !d.metinler[i]) return;
        const x = d.metinX && d.metinX[i] !== null && d.metinX[i] !== undefined ? eksen.getPixelForValue(d.metinX[i]) : el.x;
        ctx.save();
        ctx.fillStyle = d.metinRenk;
        ctx.font = '11px sans-serif';
        ctx.textBaseline = 'middle';
        ctx.fillText(d.metinler[i], Math.max(x, el.x) + 4, el.y);
        ctx.restore();
      });
    });
  },
};

function _grafikSecenek(tema, ek) {
  const eksen = () => ({ ticks: { color: tema.metin }, grid: { color: tema.izgara } });
  const sec = {
    animation: false, responsive: true, maintainAspectRatio: false,
    plugins: {
      legend: { display: !!ek.lejant, labels: { color: tema.metin, filter: (it, data) => !data.datasets[it.datasetIndex].lejantDisi } },
      tooltip: { callbacks: { afterLabel: c => (c.dataset.nler ? `n=${c.dataset.nler[c.dataIndex]}` : '') } },
    },
    scales: { x: Object.assign(eksen(), ek.x), y: Object.assign(eksen(), ek.y) },
  };
  if (ek.indexAxis) sec.indexAxis = ek.indexAxis;
  if (ek.layout) sec.layout = ek.layout;
  return sec;
}

// Sağ dolgu Chart.js'in y payını kısar (kalan genişliğin yarısı): telefonda grup adı soldan kesilirdi. Pay ada göre, tuvalin yarısına dek.
function _grafikYPay(s) {
  s.width = Math.max(s.width, Math.min(s._getLabelSizes().widest.width + _GRAFIK_Y_BOSLUK, s.chart.width / 2));
}

// Pay tuvalin yarısında biter: sığmayan ad ortaya en yakın boşluktan iki satıra bölünür, soldan kesilmez. Tooltip tam adı yazar.
// Yazı tipi Chart.js özel API'si (_getLabelSizes gibi, vendor sabit): options.ticks.font burada çözülmemiş gelir.
function _grafikYEtiket(v, i) {
  const ad = String(this.getLabelForValue(v));
  this.ctx.save();
  this.ctx.font = this._resolveTickFontOptions(i).string;
  const sigar = this.ctx.measureText(ad).width + _GRAFIK_Y_BOSLUK <= this.chart.width / 2;
  this.ctx.restore();
  if (sigar) return ad;
  const bosluk = [...ad.matchAll(/ /g)].map(m => m.index).sort((a, b) => Math.abs(a - ad.length / 2) - Math.abs(b - ad.length / 2))[0];
  return bosluk === undefined ? ad : [ad.slice(0, bosluk), ad.slice(bosluk + 1)];
}

function _grafikCubuk(zarf, tema, ozet, nMetni) {
  const s = (zarf.seriler || [])[0] || {};
  const y = s.y || [];
  const etiket = (zarf.x && zarf.x.deger) || [];
  const renk = etiket.map((_, i) => _grafikRenk(i, y[i], tema));
  const cift = (a, b) => etiket.map((_, i) => (a && b && a[i] !== null && a[i] !== undefined && b[i] !== null && b[i] !== undefined
    ? [a[i], b[i]] : null));
  const biyik = (label, data) => ({ type: 'bar', label, data, grouped: false, barThickness: 2, backgroundColor: tema.metin,
    lejantDisi: true, isaret: 'aralik', isaretRenk: tema.metin, haleRenk: tema.zemin });
  const o = zarf.olcum;
  const satirEtiket = etiket.map((_, i) => _grafikSatirEtiket(o, s, i));
  let ds;
  if (o === 'saglik_basari') {
    ds = [{ type: 'bar', label: s.ad, data: y, nler: s.n, backgroundColor: renk, metinRenk: tema.metin, metinX: s.ust,
      metinler: satirEtiket },
    biyik('Wilson %95', cift(s.alt, s.ust))];
  } else if (_GRAFIK_SURE.indexOf(o) !== -1) {
    ds = [{ type: 'bar', label: 'Q1–Q3', data: cift(s.q1, s.q3), nler: s.n, backgroundColor: renk },
      { type: 'scatter', label: 'medyan', pointStyle: 'line', rotation: 90, radius: 9, borderWidth: 2,
        borderColor: tema.metin, backgroundColor: tema.metin, isaret: 'medyan', isaretRenk: tema.metin, haleRenk: tema.zemin,
        data: etiket.map((e, i) => (y[i] === null || y[i] === undefined ? null : { x: y[i], y: e })).filter(Boolean) }];
  } else {
    const gecici = zarf.fiyat_kaynagi === 'gecici';
    ds = [{ type: 'bar', label: gecici ? `${s.ad} (geçici fiyat)` : s.ad, data: y, nler: s.n,
      backgroundColor: gecici ? renk.map(r => ({ desen: 'tarali', renk: r })) : renk }];
    if (o === 'saglik_vaka_tl') ds.push(biyik('Q1–Q3', cift(s.q1, s.q3)));
  }
  if (nMetni && o !== 'saglik_basari') {   // başarının etiketi yukarıda; ucu bıyık varsa onun sağında
    Object.assign(ds[0], { metinRenk: tema.metin, metinX: s.q3, metinler: satirEtiket });
  }
  const x = o === 'saglik_basari' ? { min: 0, max: 100 } : { min: 0 };
  // Eksen 0-100 kalır; %100 çubuğun metni tuval sağ dolgusuna yazılır (11 px rakam ≈ 7 px, eklenti +4).
  const metinler = (ds[0] && ds[0].metinler) || [];
  const layout = metinler.length ? { padding: { right: 4 + Math.max(...metinler.map(m => m.length)) * 7 } } : null;
  const yukseklik = etiket.length * _GRAFIK_SATIR_PX + _GRAFIK_EKSEN_PX;
  return { type: 'bar', data: { labels: etiket, datasets: ds }, plugins: [_GRAFIK_ISARET_EKLENTI, _GRAFIK_METIN_EKLENTI], ozet,
    yukseklik: yukseklik > _GRAFIK_TABAN_PX ? yukseklik : null,
    options: _grafikSecenek(tema, { indexAxis: 'y', x, layout, y: { afterFit: _grafikYPay, ticks: { color: tema.metin, autoSkip: false, callback: _grafikYEtiket } } }) };
}

function _grafikCizgi(zarf, tema, ozet) {
  const o = zarf.olcum;
  const ds = [];
  (zarf.seriler || []).forEach((s, i) => {
    const renk = i === 0 ? tema.vurgu : tema.kiyas;
    ds.push({ type: 'line', label: s.ad, data: s.y || [], nler: s.n, spanGaps: false, borderColor: renk, backgroundColor: renk,
      pointBackgroundColor: (s.y || []).map(v => (v === null || v === undefined ? tema.gri : renk)), order: 1 });
    if (i === 0 && _GRAFIK_SURE.indexOf(o) !== -1) {   // seçili grubun Q1–Q3 bandı
      ds.push({ type: 'line', label: 'Q1', data: s.q1 || [], spanGaps: false, borderWidth: 0, pointRadius: 0, fill: false,
        lejantDisi: true, order: 2 });
      ds.push({ type: 'line', label: 'Q1–Q3', data: s.q3 || [], spanGaps: false, borderWidth: 0, pointRadius: 0, fill: '-1',
        backgroundColor: tema.izgara, order: 2 });
    }
  });
  const y = o === 'saglik_basari' ? { min: 0, max: 100 } : { min: 0 };
  const x = { ticks: { color: tema.metin, callback: _grafikZamanEtiket(zarf) } };
  return { type: 'line', data: { labels: (zarf.x && zarf.x.deger) || [], datasets: ds }, ozet, yukseklik: null,
    options: _grafikSecenek(tema, { lejant: true, x, y }) };
}

// Kopuk periyot (E1): eksen tüm periyotları korur (P12), çizgi atlamaz; hiçbir serisi dolu olmayan periyodun nedeni
// etiketin altında metinle: n<5 ya da n=0 (yetersiz renkle ayrılmaz, F2 madde 3). v = kategori ekseninde periyot sırası.
function _grafikZamanEtiket(zarf) {
  const seriler = zarf.seriler || [];
  const deger = (zarf.x && zarf.x.deger) || [];
  return v => {
    if (seriler.some(s => _grafikDolu((s.y || [])[v]))) return deger[v];
    return [deger[v], seriler.some(s => Number((s.n || [])[v]) > 0) ? `n<${_GRAFIK_ESIK}` : 'n=0'];
  };
}

/** Zarf → Chart.js yapılandırması (spec §4.6). Saf; tema {vurgu, kiyas, gri, metin, izgara}. */
function zarfGrafikConfig(zarf, secenek) {
  const tema = (secenek && secenek.tema) || {};
  const ozet = zarfOzetCumle(zarf);
  if (_grafikZamanMi(zarf)) return _grafikCizgi(zarf, tema, ozet);
  const h = grafikGruplariHazirla(zarf);
  return _grafikCubuk(h.cizilen, tema, ozet, !!h.rozet);
}

/** Kümülatif kapanma eğrisi (zarf.egri): basamaklı çizgi, x = gün, y = kapanmış %. egri yoksa null. */
function egriGrafikConfig(zarf, tema) {
  if (!zarf || !Array.isArray(zarf.egri) || !zarf.egri.length) return null;
  const t = tema || {};
  const x = zarf.x || {};
  const ad = {};
  (x.anahtar || []).forEach((a, i) => { ad[a] = (x.deger || [])[i]; });
  const ds = [];
  zarf.egri.forEach((e, i) => {
    if (!e.gun || !e.gun.length) return;   // n<5 grubun eğrisi gelmez
    const renk = i === 0 ? t.vurgu : t.kiyas;
    ds.push({ type: 'line', label: ad[e.anahtar] || e.anahtar, stepped: true, spanGaps: false, pointRadius: 0,
      borderColor: renk, backgroundColor: renk,
      data: e.gun.map((g, j) => ({ x: g, y: Math.round(Number(e.oran[j]) * 1000) / 10 })) });
  });
  return { type: 'line', data: { datasets: ds }, ozet: 'Kümülatif kapanma eğrisi: gün içinde kapanmış vaka oranı (%).',
    options: _grafikSecenek(t, { lejant: true, x: { type: 'linear', min: 0, title: { display: true, text: 'gün', color: t.metin } },
      y: { min: 0, max: 100, title: { display: true, text: 'kapanmış %', color: t.metin } } }) };
}

// {desen:'tarali', renk} işaretçisini 8px çapraz çizgi CanvasPattern'ine çevirir (08 deseni, geçici fiyat).
function _grafikDesen(ctx, r) {
  if (!r || r.desen !== 'tarali') return r;
  if (!ctx || typeof document === 'undefined') return r.renk;
  const pc = document.createElement('canvas');
  pc.width = 8;
  pc.height = 8;
  const p = pc.getContext('2d');
  p.strokeStyle = r.renk;
  p.lineWidth = 2;
  p.beginPath();
  p.moveTo(0, 8); p.lineTo(8, 0);
  p.moveTo(-2, 2); p.lineTo(2, -2);
  p.moveTo(6, 10); p.lineTo(10, 6);
  p.stroke();
  return ctx.createPattern(pc, 'repeat') || r.renk;
}

/** Canvas'a çizer: önceki örneği destroy eder, desenleri çevirir, aria-label = özet. Chart döner. */
function grafikCiz(canvas, config) {
  if (canvas.__chart && typeof canvas.__chart.destroy === 'function') canvas.__chart.destroy();
  const ctx = typeof canvas.getContext === 'function' ? canvas.getContext('2d') : null;
  ((config && config.data && config.data.datasets) || []).forEach(d => {
    d.backgroundColor = Array.isArray(d.backgroundColor)
      ? d.backgroundColor.map(r => _grafikDesen(ctx, r)) : _grafikDesen(ctx, d.backgroundColor);
  });
  // Çok gruplu çubukta sarmalayıcı uzar (Chart ölçmeden önce); null → CSS'teki taban yükseklik.
  if (canvas.parentElement) canvas.parentElement.style.height = config && config.yukseklik ? `${config.yukseklik}px` : '';
  const ch = new Chart(canvas, config);
  canvas.__chart = ch;
  if (config && config.ozet) {
    canvas.setAttribute('role', 'img');
    canvas.setAttribute('aria-label', config.ozet);
  }
  return ch;
}

/** Tema renkleri CSS değişkenlerinden (body: koyu tema geçersiz kılmaları body.dark'ta). Gri = nötr mürekkep (KF2 Ruling 4). */
function temaRenkleri() {
  const st = getComputedStyle(document.body || document.documentElement);
  const v = ad => String(st.getPropertyValue(ad) || '').trim();
  return { vurgu: v('--green'), kiyas: v('--ink3'), gri: v('--ink3'), metin: v('--ink'), izgara: v('--card3'), zemin: v('--card') };
}

// Test için dual-mode export (tarayıcıda module undefined, etkisiz)
if (typeof module !== 'undefined' && module.exports) {
  module.exports = Object.assign(module.exports || {}, {
    grafikGruplariHazirla, grafikRozet, grafikCizilir, grafikDipnotAyir, zarfDurum, durumMetni, dozMetni, zarfOzetCumle, zarfGrafikConfig, egriGrafikConfig, grafikCiz, temaRenkleri,
  });
}
