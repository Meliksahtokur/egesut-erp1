// js/istatistik/kurucu.js
// İstatistik Atölyesi AP1 (T12): kurucu ekranı — cümle paneli, ölçü kartları, vaka izi, panoya kaydet
// (spec §4.4-4.8, plan Task 12). Hesap yok: sayılar, sayaçlar ve dipnotlar sunucu zarfından basılır;
// sonuç etiketleri yalnız cumle.js'te, durum/grafik çevirisi yalnız grafik.js'te.
// Cümle window._atolye'de (atolye.js), cümle dışı ekran durumu _kurucuEkran'da; geçici fiyat yalnız
// statAtolyeSeri parametresi olur, kayıt yüküne girmez. Olaylar #atolye-icerik üzerinde tek dinleyici:
// DB değeri HTML'e data-* olarak (escAttr) girer, satır içi JS'e girmez.
'use strict';

const _kurucuEkran = {
  cumle: null,          // son yazılan cümle: başka kaynaktan açılan cümleyi ayırt eder (yığın sıfırlanır)
  seri: null,           // son başarılı stat_atolye_seri yanıtı (doz anahtarı RPC'siz yeniden çizer)
  seriCumle: null,      // kartların çizildiği cümle: seri hatasından sonra panelin cümlesinden ayrılabilir
  seriGecici: null,     // kartların çizildiği geçici fiyat nesnesi: Hesapla düşerse s.gecici'den ayrılır (kimlik kıyası)
  tanimlar: [],         // son başarılı tanım kartları
  canvaslar: [],        // çizilmiş kartların canvas'ları (yeniden çizimde Chart yok edilir)
  doz: false, egri: false, katli: true, fiyatAcik: false,
  kaydet: false, kaydetBaslik: null, kaydediyor: false, vakaJeton: 0,
};

const _KURUCU_DUZEY = [['etken', 'Etken madde'], ['preparat', 'Preparat'], ['sinif', 'Sınıf']];
const _KURUCU_KIRILIM = [['yok', 'Yok'], ['ilac', 'İlaç'], ['ay', 'Ay'], ['ceyrek', 'Çeyrek'], ['yil', 'Yıl']];
const _KURUCU_YUKLENIYOR = '<div class="loader"><div class="spin"></div></div>';

// ── HTML parçaları ──
// Olay değeri her yerde kararlı JSON (cumleAnahtar): çip data-deger'i ve <option value>.
function _kurucuDeger(d) { return escAttr(cumleAnahtar(d)); }

function _kurucuCip(etiket, slot, deger, on) {
  return `<button type="button" class="atolye-cip${on ? ' on' : ''}" data-kurucu-slot="${slot}" data-deger="${_kurucuDeger(deger)}"` +
    ` aria-pressed="${on ? 'true' : 'false'}">${esc(etiket)}</button>`;
}

function _kurucuEylem(etiket, slot, deger) {
  return `<button type="button" class="atolye-eylem" data-kurucu-slot="${slot}" data-deger="${_kurucuDeger(deger)}">${esc(etiket)}</button>`;
}

function _kurucuSlot(anahtar, ad, govde) {
  return `<div class="atolye-slot" data-slot="${anahtar}"><div class="atolye-slot-ad">${ad}</div>${govde}</div>`;
}

function _kurucuCipler(icerik) { return `<div class="atolye-cipler">${icerik}</div>`; }

/** <select>: secenek = [[deger, etiket]...]. Seçili değer listede yoksa gizlenmez, eksikEtiket ile eklenir. */
function _kurucuSecim(slot, ad, secenek, secili, eksikEtiket) {
  const a = cumleAnahtar(secili);
  const liste = secenek.some(o => cumleAnahtar(o[0]) === a) ? secenek : [...secenek, [secili, eksikEtiket]];
  const satir = liste.map(o => `<option value="${_kurucuDeger(o[0])}"${cumleAnahtar(o[0]) === a ? ' selected' : ''}>${esc(o[1])}</option>`);
  return `<select data-kurucu-slot="${slot}" aria-label="${ad}">${satir.join('')}</select>`;
}

function _kurucuHastalikSecim(cumle, sec) {
  const h = cumle.hastalik || {};
  const secili = h.tip === 'hastalik' || h.tip === 'kategori' ? { tip: h.tip, deger: h.deger } : { tip: 'tumu', deger: null };
  const kat = (Array.isArray(sec.kategoriler) ? sec.kategoriler : []).map(k => [{ tip: 'kategori', deger: k.ad }, `${k.ad} (tümü) · ${k.n}`]);
  const has = (Array.isArray(sec.hastaliklar) ? sec.hastaliklar : []).map(o => [{ tip: 'hastalik', deger: o.id }, `${o.ad} · ${o.n}`]);
  const eksik = h.tip === 'kategori' ? `${h.deger} (tümü) · 0` : 'Seçili hastalık · 0';
  return _kurucuSecim('hastalik', 'Hastalık', [[{ tip: 'tumu', deger: null }, 'Tüm hastalıklar'], ...kat, ...has], secili, eksik);
}

function _kurucuIlacSlot(x, y, sec) {
  const aday = l => (Array.isArray(l) ? l : []).map(a => [a.deger, `${_cumleIlacEtiket(a.deger)} · ${a.n}`]);
  const eksik = d => `${_cumleIlacEtiket(d)} · 0`;
  let g = _kurucuSecim('x', 'İlaç', [[null, 'yok'], ...aday(sec.x_adaylari)], x, eksik(x));
  if (x !== null) g += ' ' + _kurucuSecim('y', 'Ek ilaç', [[null, y === null ? '+ ekle' : 'Ek ilaç yok'], ...aday(sec.y_adaylari)], y, eksik(y));
  return _kurucuSlot('ilac', 'İlaç', g);
}

function _kurucuOlcuSlot(cumle) {
  const secili = cumle.olculer || [];
  const satir = ATOLYE_OLCULER.map(o => {
    const on = o.pasif ? _kurucuEkran.doz : secili.includes(o.ad);
    const kilit = !o.pasif && on && secili.length === 1;   // son ölçü kaldırılamaz
    return `<label class="atolye-onay${o.pasif ? ' atolye-pasif' : ''}"><input type="checkbox" data-kurucu-olcu="${o.ad}"` +
      `${on ? ' checked' : ''}${kilit ? ' disabled' : ''}> ${esc(o.etiket)}</label>`;
  });
  return _kurucuSlot('olculer', 'Ölçüler', satir.join(''));
}

function _kurucuDonemSlot(d) {
  const yil = Number(bugun().slice(0, 4));
  let c = [3, 6, 12, 24].map(n => _kurucuCip(`Son ${n} ay`, 'donem', { tip: 'son_ay', n }, d.tip === 'son_ay' && d.n === n)).join('');
  c += _kurucuCip('Tüm zamanlar', 'donem', { tip: 'tumu' }, d.tip === 'tumu');
  c += _kurucuCip('Takvim yılı', 'donem', { tip: 'yil', yil }, d.tip === 'yil');
  c += `<button type="button" class="atolye-cip${d.tip === 'aralik' ? ' on' : ''}" data-kurucu-eylem="aralik">Özel aralık</button>`;
  let alt = '';
  if (d.tip === 'yil') {
    const yillar = [0, 1, 2, 3, 4, 5].map(k => [{ tip: 'yil', yil: yil - k }, String(yil - k)]);
    alt = _kurucuSecim('donem', 'Takvim yılı', yillar, { tip: 'yil', yil: d.yil }, String(d.yil));
  } else if (d.tip === 'aralik') {
    alt = _kurucuCipler([['bas', 'Başlangıç'], ['bit', 'Bitiş']].map(([k, ad]) =>
      `<input type="hidden" id="atolye-aralik-${k}" data-kurucu-tarih="${k}" value="${escAttr(d[k])}">` +
      `<button type="button" class="atolye-eylem" data-kurucu-eylem="tarih" data-alan="${k}">${ad}: ${esc(tarihIsoTr(d[k]))}</button>`).join(''));
  }
  return _kurucuSlot('donem', 'Dönem', _kurucuCipler(c) + alt);
}

/** Cümle paneli HTML'i (spec §4.4 slot sırası). secenekler null olabilir: seçili değerler yine görünür. */
function kurucuCumlePanelHtml(cumle, secenekler) {
  const e = _kurucuEkran;
  const sec = secenekler || {};
  const i = cumle.ilac || {};
  const x = i.x === undefined ? null : i.x;
  const y = i.y === undefined ? null : i.y;
  const slot = [
    _kurucuSlot('alan', 'Alan', _kurucuCipler('<span class="atolye-cip on">Sağlık</span>')),
    _kurucuSlot('hastalik', 'Hastalık', _kurucuHastalikSecim(cumle, sec)),
    _kurucuSlot('duzey', 'İlaç düzeyi', _kurucuCipler(_KURUCU_DUZEY.map(o => _kurucuCip(o[1], 'duzey', o[0], (i.duzey || 'etken') === o[0])).join(''))),
    _kurucuIlacSlot(x, y, sec),
  ];
  if (x !== null) {
    let g = _kurucuCip('Hastalığın tüm vakaları', 'kiyas_grubu', 'tumu', cumle.kiyas_grubu !== 'x_y_siz');
    if (y !== null) g += _kurucuCip(`${_cumleIlacEtiket(x)} içeren, ${_kombinasyonSiz(_cumleIlacEtiket(y))}`, 'kiyas_grubu', 'x_y_siz', cumle.kiyas_grubu === 'x_y_siz');
    slot.push(_kurucuSlot('kiyas_grubu', 'Kıyas grubu', _kurucuCipler(g)));
  }
  slot.push(_kurucuOlcuSlot(cumle));
  const kirilim = _KURUCU_KIRILIM.filter(o => o[0] !== 'ilac' || x === null);   // P4
  slot.push(_kurucuSlot('kirilim', 'Kırılım', _kurucuCipler(kirilim.map(o => _kurucuCip(o[1], 'kirilim', o[0], cumle.kirilim === o[0])).join(''))));
  slot.push(_kurucuDonemSlot(cumle.donem || {}));
  slot.push(_kurucuSlot('kiyas_duzeyi', 'Kıyas düzeyi', _kurucuCipler('<span class="atolye-cip on atolye-pasif">Biz</span>')));
  const baslik = cumleBaslik(cumle, sec);
  let kaydet = '<button type="button" class="atolye-btn-ana" data-kurucu-eylem="kaydet">Kaydettiğim grafiklere kaydet</button>';
  if (e.kaydet) {
    slot.push(`<div class="atolye-slot"><label class="atolye-slot-ad" for="atolye-kaydet-baslik">Grafik başlığı</label>` +
      `<input type="text" id="atolye-kaydet-baslik" value="${escAttr(e.kaydetBaslik === null ? baslik : e.kaydetBaslik)}"></div>`);
    kaydet = '<button type="button" class="atolye-btn-ana" data-kurucu-eylem="kaydet">Kaydet</button>' +
      '<button type="button" class="atolye-eylem" data-kurucu-eylem="kaydet-iptal">Vazgeç</button>';
  }
  return `<div id="atolye-cumle-panel" class="atolye-cumle-panel${e.katli ? ' katli' : ''}">` +
    `<div class="atolye-cumle-baslik">${esc(baslik)}</div>` +
    `<button type="button" class="atolye-katla atolye-eylem" data-kurucu-eylem="katla" aria-expanded="${e.katli ? 'false' : 'true'}">Cümleyi düzenle</button>` +
    slot.join('') +
    `<div class="atolye-panel-alt">${kaydet}<button type="button" class="atolye-eylem" data-kurucu-eylem="yenile">Yeniden hesapla</button></div></div>`;
}

// ── Kart ──
function _kurucuGruplar(z) {
  if (_grafikZamanMi(z)) return (z.seriler || []).map(s => ({ anahtar: s.anahtar, ad: s.ad, n: _grafikToplam(s.n) }));
  const x = z.x || {};
  const n = ((z.seriler || [])[0] || {}).n || [];
  return (x.anahtar || []).map((a, i) => ({ anahtar: a, ad: (x.deger || [])[i], n: n[i] }));
}

function _kurucuRozet(z, durum) {
  const ilac = grafikRozet(z, durum);
  if (ilac !== null) return ilac;
  const grup = _grafikZamanMi(z) ? (z.seriler || []).length : ((z.x || {}).deger || []).length;
  if (grup > 2) return `${grup} grup`;   // ilaç kırılımı: her grubun n'i grafikte ve iz bağlantısında
  const kiyas = (z.sayac || {}).kiyas_n;
  return `n=${z.n || 0}${grup === 2 && kiyas !== null && kiyas !== undefined ? ` / n=${kiyas}` : ''}`;
}

// n<5 metinle ayırt edilir, renkle değil: sunucunun y=null bıraktığı hücreler. Zamanda boş periyot (n=0) yazılmaz (P12).
// İlaç kırılımında tek satır (grafik.js yardımcısı). Kart altında görünür kalır (TF G3).
function _kurucuYetersizSatir(z) {
  const ilac = grafikGruplariHazirla(z).azMetin;
  if (ilac) return `<div class="atolye-veri-az">${esc(ilac)}</div>`;
  const zaman = _grafikZamanMi(z);
  const etiket = (z.x || {}).deger || [];
  const seriler = z.seriler || [];
  const liste = [];
  seriler.forEach(s => (s.n || []).forEach((n, i) => {
    const y = (s.y || [])[i];
    if ((y !== null && y !== undefined) || (zaman && !Number(n))) return;
    const ad = zaman && seriler.length > 1 ? `${s.ad} ${etiket[i]}` : etiket[i];
    liste.push(`${ad} yetersiz (n=${Number(n) || 0})`);
  }));
  return liste.length ? `<div class="atolye-veri-az">${esc(liste.join(' · '))}</div>` : '';
}

// S4: az vakalı ilaç üstteyken uyarı kapalı Ayrıntı'da kalmasın (pano da bunu kullanır).
function _kurucuUyariSatir(metin) {
  return metin ? `<div class="atolye-veri-az">${esc(metin)}</div>` : '';
}

function _kurucuDurumHtml(durum, z, cumle) {
  const m = durumMetni(durum, z, cumle);
  const geriYok = m.eylem && m.eylem.slot === 'geri' && !((window._atolye || {}).onceki || []).length;
  const eylem = m.eylem && !geriYok ? `<div>${_kurucuEylem(m.eylem.etiket, m.eylem.slot, m.eylem.deger)}</div>` : '';
  return `<div class="atolye-durum"><div>${esc(m.metin)}</div>${eylem}</div>`;
}

function _kurucuSayacHtml(z) {
  const s = z.sayac || {};
  const parca = [];
  if (Number(s.acik_n) > 0) parca.push(`+${Number(s.acik_n)} açık vaka hesap dışı`);
  if (z.olcum === 'saglik_basari' && Number(s.olgunlasmamis_n) > 0) parca.push(`${Number(s.olgunlasmamis_n)} vaka 30 gün dolmadı`);
  return parca.length ? `<div class="atolye-sayac">${esc(parca.join(' · '))}</div>` : '';
}

function _kurucuVakaBaglanti(z) {
  const g = _kurucuGruplar(z).filter(o => o.anahtar);
  // data-olcu-n: bu kartın ölçü n'i; liste başlığı aynı grubu kartla bu sayıyla kıyaslar (U21).
  const dugme = (o, ad) => `<button type="button" class="atolye-baglanti" data-kurucu-vakalar="${escAttr(o.anahtar)}"` +
    `${o.n === undefined ? '' : ` data-olcu-n="${Number(o.n)}"`}>${esc(ad)}</button>`;
  if (!g.length) return '';
  return `<div class="atolye-sayac">${g.length === 1 ? dugme(g[0], 'Bu sayıya giren vakalar')
    : `Bu sayıya giren vakalar: ${g.map(o => dugme(o, o.ad)).join(' · ')}`}</div>`;
}

/** Ölçü kartı: bir kart tek ölçü (AK-6). {olcum:'doz'} istemci durum kartıdır (P8). */
function kurucuKartHtml(zarf, tanimKarti, idx) {
  const z = zarf || {};
  const t = tanimKarti || {};
  const olcu = ATOLYE_OLCULER.find(o => o.ad === z.olcum);
  const baslik = t.baslik || (olcu ? olcu.etiket : z.olcum);
  const bas = rozet => `<div class="atolye-kart-bas"><span class="atolye-kart-baslik">${esc(baslik)}</span>${rozet}</div>`;
  if (z.olcum === 'doz') return `<div class="atolye-kart">${bas('')}${_kurucuDurumHtml('doz', z, null)}</div>`;

  const cumle = (window._atolye || {}).cumle;
  const durum = zarfDurum(z, cumle);
  const cizilir = grafikCizilir(durum);
  const rozet = _kurucuRozet(z, durum);
  const { uyari, kalan } = grafikDipnotAyir(z, durum);
  let g = bas(rozet ? `<span class="atolye-rozet">${esc(rozet)}</span>` : '');
  if (z.fiyat_kaynagi === 'gecici') g += '<div class="atolye-gecici-bant">geçici, kaydedilmedi</div>';
  if (cizilir) {
    g += `<div class="atolye-grafik"><canvas data-kurucu-kart="${Number(idx)}"></canvas></div>`;
    g += `<div class="atolye-ozet">${esc(zarfOzetCumle(z))}</div>` + _kurucuUyariSatir(uyari) + _kurucuYetersizSatir(z);
    if (z.olcum === 'saglik_kapanma_gunu' && (z.egri || []).some(k => k.gun && k.gun.length)) {
      g += `<label class="atolye-onay"><input type="checkbox" data-kurucu-egri="1"${_kurucuEkran.egri ? ' checked' : ''}> Kapanma eğrisini göster</label>`;
    }
  }
  if (durum !== 'tamam') g += _kurucuDurumHtml(durum, z, cumle);
  if (durum === 'zaman_seyrek') g += _kurucuYetersizSatir(z);
  if (cizilir && z.fiyat_kaynagi && Number((z.sayac || {}).fiyatsiz_n) > 0) {
    g += `<div class="atolye-sayac"><button type="button" class="atolye-baglanti" data-kurucu-slot="fiyat_panel" data-deger="null">Fiyat gir</button></div>`;
  }
  // Kart altı sade (TF G3): sayaç, dipnot, hesap tarihi, tanım ve vaka izi tek kapalı alanda; iç içe details yok.
  const dipnot = kalan.length ? `<ul class="atolye-dipnot">${kalan.map(d => `<li>${esc(d)}</li>`).join('')}</ul>` : '';
  g += '<details class="atolye-ayrinti"><summary>Ayrıntı</summary>' + _kurucuSayacHtml(z) + dipnot +
    `<div class="atolye-hesap">${esc(atolyeHesapTarihi(z.hesap_at))}</div>` +
    `<div class="atolye-tanim"><div>${esc(t.tanim)}</div><div>${esc(t.kume)}</div><div>Sürüm: ${esc(z.surum || t.surum)}</div></div>` +
    `${_kurucuVakaBaglanti(z)}</details>`;
  return `<div class="atolye-kart" data-olcum="${escAttr(z.olcum)}">${g}</div>`;
}

// ── Çizim ──
function _kurucuKabuk() {
  const kok = document.getElementById('atolye-icerik');
  if (!kok) return null;
  if (!document.getElementById('atolye-kartlar')) {
    kok.innerHTML = '<div class="atolye-kurucu"><div id="atolye-cumle-panel" class="atolye-cumle-panel"></div>' +
      `<div id="atolye-kartlar" class="atolye-kartlar">${_KURUCU_YUKLENIYOR}</div></div>`;
  }
  if (!kok.__kurucuBagli) {
    kok.__kurucuBagli = true;
    kok.addEventListener('click', _kurucuTikla);
    kok.addEventListener('change', _kurucuDegis);
    kok.addEventListener('input', _kurucuBaslikYaz);
  }
  return kok;
}

// Yeniden çizimde aynı denetimi bulur: select değeri değişse de aynıdır, çip değeriyle ayrılır.
function _kurucuOdakAnahtar(el) {
  const d = el.dataset || {};
  return el.id || [el.tagName, d.kurucuSlot, d.kurucuOlcu, d.kurucuEylem, d.alan, el.tagName === 'SELECT' ? '' : d.deger].join('|');
}

function _kurucuPanelCiz() {
  const s = window._atolye;
  const p = document.getElementById('atolye-cumle-panel');
  if (!p || !s.cumle) return;
  const alan = document.getElementById('atolye-kaydet-baslik');
  if (alan && _kurucuEkran.kaydet) _kurucuEkran.kaydetBaslik = alan.value;   // yanıt gelince yazılan başlık silinmesin
  // outerHTML düğümü değiştirir: denetim odağı, imleç ve panelin kendi kaydırması (index.html G6) elle taşınır (TF G7).
  const odak = document.activeElement;
  const anahtar = odak && p.contains(odak) ? _kurucuOdakAnahtar(odak) : null;
  const imlec = anahtar && typeof odak.selectionStart === 'number' ? [odak.selectionStart, odak.selectionEnd] : null;
  const tepe = p.scrollTop;
  p.outerHTML = kurucuCumlePanelHtml(s.cumle, s.secenekler);
  const yeni = document.getElementById('atolye-cumle-panel');
  yeni.scrollTop = tepe;
  const hedef = anahtar ? Array.from(yeni.querySelectorAll('button,select,input')).find(el => _kurucuOdakAnahtar(el) === anahtar) : null;
  if (!hedef) return;
  hedef.focus({ preventScroll: true });
  if (imlec) hedef.setSelectionRange(imlec[0], imlec[1]);
}

// Başlık yazıldıkça durumda: Pano'ya geçişte alan DOM'dan gider, aynı cümleyle dönüşte yazılan geri gelir.
function _kurucuBaslikYaz(ev) {
  if (ev.target && ev.target.id === 'atolye-kaydet-baslik') _kurucuEkran.kaydetBaslik = ev.target.value;
}

function _kurucuGrafikTemizle() {
  _kurucuEkran.canvaslar.forEach(c => { if (c.__chart) { c.__chart.destroy(); c.__chart = null; } });
  _kurucuEkran.canvaslar = [];
}

function _kurucuConfig(z, tema) {
  const egri = _kurucuEkran.egri && z.olcum === 'saglik_kapanma_gunu' ? egriGrafikConfig(z, tema) : null;
  return egri || zarfGrafikConfig(z, { tema });
}

function _kurucuGrafikCiz(canvaslar) {
  const tema = temaRenkleri();
  const zarflar = window._atolye.sonZarflar || [];
  canvaslar.forEach(c => { const z = zarflar[Number(c.dataset.kurucuKart)]; if (z) grafikCiz(c, _kurucuConfig(z, tema)); });
}

function _kurucuKartlarCiz() {
  const s = window._atolye;
  const e = _kurucuEkran;
  const kartlar = document.getElementById('atolye-kartlar');
  if (!kartlar || !e.seri) return;
  const zarflar = e.seri.zarflar || [];
  _kurucuGrafikTemizle();
  kartlar.innerHTML = zarflar.map((z, i) => kurucuKartHtml(z, e.tanimlar.find(t => t.ad === z.olcum), i)).join('') +
    `<div id="atolye-doz-alan"${e.doz ? '' : ' hidden'}>${_kurucuDozHtml()}</div>` +
    `<div id="atolye-komb-alan">${kombinasyonHtml(e.seri.kombinasyon, { gecici: s.gecici })}</div>` +
    `<div id="atolye-fiyat-alan"${e.fiyatAcik ? '' : ' hidden'}>${geciciFiyatPanelHtml(e.seri.fiyat_eksik, s.gecici)}</div>` +
    '<div id="atolye-vakalar-alan" class="atolye-vakalar" hidden></div>';
  e.canvaslar = Array.from(kartlar.querySelectorAll('canvas[data-kurucu-kart]'));
  _kurucuGrafikCiz(e.canvaslar);
  kombinasyonBagla(document.getElementById('atolye-komb-alan'));
  geciciFiyatBagla(document.getElementById('atolye-fiyat-alan'));
}

function _kurucuDozHtml() { return _kurucuEkran.doz ? kurucuKartHtml({ olcum: 'doz' }, null, 0) : ''; }

function _kurucuEgriDegis(acik) {
  _kurucuEkran.egri = !!acik;
  _kurucuGrafikCiz(_kurucuEkran.canvaslar);
}

// Hata: şerit + son kartlar kalır; ilk yükleme çarkı yerine "yeniden dene". Eski yanıt/ekran çağıran tarafta elenir.
function _kurucuHata(err) {
  const kartlar = document.getElementById('atolye-kartlar');
  if (kartlar) {
    kartlar.classList.remove('atolye-pasif');
    if (kartlar.querySelector('.loader')) {
      kartlar.innerHTML = '<div class="atolye-durum"><button type="button" class="atolye-eylem" data-kurucu-eylem="yenile">Yeniden hesapla</button></div>';
    }
  }
  atolyeHataSeridi(err, document.getElementById('atolye-icerik'));
}

// Hesap dışı bir başarı (liste, kayıt) uyarıyı yalnız kartlar panelin cümlesi ve geçici fiyatıyla çizilmişken kaldırır;
// aksi eski sayılar uyarısız kalır (Hesapla düştüyse ₺ kartı eskidir, A2). Geçici fiyat her basışta yeni nesne yazılır.
function _kurucuBayatDegilseTemizle() {
  const s = window._atolye;
  if (_kurucuEkran.seriCumle === s.cumle && _kurucuEkran.seriGecici === s.gecici) atolyeHataTemizle(document.getElementById('atolye-icerik'));
}

function _kurucuCumleYaz(cumle) {
  window._atolye.cumle = cumle;
  _kurucuEkran.cumle = cumle;
  _kurucuEkran.kaydet = false;        // açık başlık alanı eski cümleye ait
  _kurucuEkran.kaydetBaslik = null;
}

// ── Genel giriş noktaları ──
/** Kurucuyu açar; cumle null ise tüm vakalar + son 12 ay seçeneklerinden varsayılan kurulur. */
async function kurucuAc(cumle) {
  const s = window._atolye;
  if (!_kurucuKabuk()) return;
  if (cumle) {
    // Aynı cümle = sekme dönüşü: yığın ve açık başlık alanı korunur (E10b).
    if (cumle !== _kurucuEkran.cumle) {
      s.onceki = [];
      _kurucuCumleYaz(cumle);
    }
    return kurucuYenile();
  }
  const j = ++s.jeton;
  try {
    const sec = await statAtolyeSecenekler(cumleVarsayilan(null));
    if (j !== s.jeton || !document.getElementById('atolye-kartlar')) return;
    s.secenekler = sec;
    s.onceki = [];
    _kurucuCumleYaz(cumleVarsayilan(sec));
  } catch (err) {
    if (j === s.jeton && document.getElementById('atolye-kartlar')) _kurucuHata(err);
    return;
  }
  return kurucuYenile();
}

/**
 * Slot değişimi: mevcut cümle yığına girer, cumleGuncelle, yeniden hesap. 'geri' yığından alır.
 * Cümle dışı eylemler yığına girmez, RPC çağırmaz: fiyat_panel, kombinasyon, doz (P8).
 */
function kurucuSlotDegis(slot, deger) {
  const s = window._atolye;
  const e = _kurucuEkran;
  if (slot === 'fiyat_panel') {
    const a = document.getElementById('atolye-fiyat-alan');
    if (!((e.seri || {}).fiyat_eksik || []).length) { toast('Bu seçimde fiyatı girilebilecek ilaç yok'); return undefined; }
    e.fiyatAcik = true;
    if (a) { a.hidden = false; a.scrollIntoView(); }
    return undefined;
  }
  if (slot === 'kombinasyon') {
    const x = (s.cumle.ilac || {}).x;
    if (x === null || x === undefined) {
      e.katli = false;
      _kurucuPanelCiz();
      toast('İlaç seçin');
      return undefined;
    }
    const a = document.getElementById('atolye-komb-alan');
    if (a) a.scrollIntoView();
    return undefined;
  }
  if (slot === 'doz') {
    e.doz = !!deger;
    const a = document.getElementById('atolye-doz-alan');   // yalnız doz kartı: açık liste, yazılı fiyat, grafik yerinde (E10)
    if (a) { a.innerHTML = _kurucuDozHtml(); a.hidden = !e.doz; }
    return undefined;
  }
  if (slot === 'geri') {
    if (!s.onceki.length) return undefined;
    _kurucuCumleYaz(s.onceki.pop());
    return kurucuYenile();
  }
  const yeni = cumleGuncelle(s.cumle, slot, deger);
  if (cumleAnahtar(yeni) === cumleAnahtar(s.cumle)) {   // reddedilen ya da aynı seçim: panel durumu geri gelir
    _kurucuPanelCiz();
    return undefined;
  }
  s.onceki.push(s.cumle);
  _kurucuCumleYaz(yeni);
  return kurucuYenile();
}

/** Seçenek + seri paralel; jeton eski yanıtı, kartlar alanının varlığı sekme değişimini eler. */
// Dönem=tumu'da SQL alt sınırı seçili hastalığın ilk vakasıdır; hastalık listesi tüm geçmişi saysın diye süzgeçsiz de sorulur.
async function _kurucuSecenekler(cumle) {
  if ((cumle.donem || {}).tip !== 'tumu' || (cumle.hastalik || {}).tip === 'tumu') return statAtolyeSecenekler(cumle);
  const [sec, tum] = await Promise.all([
    statAtolyeSecenekler(cumle),
    statAtolyeSecenekler(Object.assign({}, cumle, { hastalik: { tip: 'tumu', deger: null } })),
  ]);
  return Object.assign({}, sec, { hastaliklar: tum.hastaliklar, kategoriler: tum.kategoriler });
}

async function kurucuYenile({ yenile = false } = {}) {
  const s = window._atolye;
  const e = _kurucuEkran;
  if (!s || !s.cumle || !_kurucuKabuk()) return;
  const j = ++s.jeton;
  _kurucuPanelCiz();
  document.getElementById('atolye-kartlar').classList.add('atolye-pasif');
  if (yenile) _statInvalidate();   // seçenek sayıları da taze olsun (§4.8 "önbelleği boşaltıp")
  const gecerli = () => j === s.jeton && document.getElementById('atolye-kartlar');
  try {
    const [sec, seri, tanimlar] = await Promise.all([
      _kurucuSecenekler(s.cumle),
      statAtolyeSeri(s.cumle, s.gecici, { yenile }),
      statOlcumListele().catch(() => e.tanimlar),   // tanım kartı alınamazsa sayılar yine çizilir
    ]);
    if (!gecerli()) return;
    s.secenekler = sec;
    s.sonZarflar = seri.zarflar || [];
    e.seri = seri;
    e.seriCumle = s.cumle;
    e.seriGecici = s.gecici;
    e.tanimlar = Array.isArray(tanimlar) ? tanimlar : [];
    _kurucuPanelCiz();
    _kurucuKartlarCiz();
    document.getElementById('atolye-kartlar').classList.remove('atolye-pasif');
    atolyeHataTemizle(document.getElementById('atolye-icerik'));
  } catch (err) {
    if (!gecerli()) return;
    _kurucuPanelCiz();
    _kurucuHata(err);
  }
}

/** Sayıya Türkçe iyelik eki: 16'sı, 4'ü, 40'ı. */
function _kurucuSayiEk(n) {
  const birler = ['', 'i', 'si', 'ü', 'ü', 'i', 'sı', 'si', 'i', 'u'];
  const onlar = ['', 'u', 'si', 'u', 'ı', 'si', 'ı', 'i', 'i', 'ı'];
  let ek = n === 0 ? 'ı' : 'i';              // sıfır, bin
  if (n % 10) ek = birler[n % 10];
  else if (n % 100) ek = onlar[(n % 100) / 10];
  else if (n % 1000) ek = 'ü';
  return `${n}'${ek}`;
}

// U21: "20 vaka · 16'sı bu ölçüde · 4'ü açık". Ölçü n'i karttan gelir. Açık satırlardan sayılır: sayac.acik_n tüm
// grupların birleşimidir, tek grubun değil. Kesik listede açık ve kalan bilinmez, yazılmaz.
function _kurucuVakaOzet(toplam, vakalar, olcuN) {
  const tam = toplam <= vakalar.length;
  const n = olcuN === undefined ? null : Number(olcuN);
  const parca = [tam ? `${vakalar.length} vaka` : `ilk ${vakalar.length} / ${toplam}`];
  if (n !== null) parca.push(`${_kurucuSayiEk(n)} bu ölçüde`);
  if (tam) {
    const acik = vakalar.filter(v => v.durum === 'acik').length;
    if (acik) parca.push(`${_kurucuSayiEk(acik)} açık`);
    const kalan = n === null ? 0 : vakalar.length - n - acik;   // olgunlaşmamış, fiyatsız, kapanış tarihi yok
    if (kalan > 0) parca.push(`${_kurucuSayiEk(kalan)} ölçü dışı`);
  }
  return parca.join(' · ');
}

function _kurucuVakaTablo(r, grupAnahtari, olcuN) {
  const vakalar = (r && r.vakalar) || [];
  const toplam = Number(r && r.toplam) || 0;
  const zarf = ((window._atolye || {}).sonZarflar || [])[0];
  const grup = zarf ? _kurucuGruplar(zarf).find(o => o.anahtar === grupAnahtari) : null;
  const bilinmeyen = [];
  const satir = vakalar.map(v => {
    const et = sonucEtiket(v.sonuc, v.durum);
    if (et.bilinmeyen) bilinmeyen.push(v.sonuc);
    return `<tr><td>${esc(v.kupe_no)}</td><td>${esc(v.hastalik)}</td><td>${esc(tarihIsoTr(v.baslangic))}</td>` +
      `<td>${v.kapanma_vekil ? '≈ ' : ''}${esc(tarihIsoTr(v.kapanis))}</td><td>${esc(et.etiket)}</td></tr>`;
  });
  const uyari = bilinmeyen.length
    ? `<div class="atolye-sayac">${bilinmeyen.length} satırda tanınmayan sonuç: ${esc([...new Set(bilinmeyen.map(String))].join(', '))}</div>` : '';
  return `<div class="atolye-kart-bas"><span class="atolye-kart-baslik">Bu sayıya giren vakalar${grup ? ' · ' + esc(grup.ad) : ''}</span></div>` +
    `<div class="atolye-sayac">${esc(_kurucuVakaOzet(toplam, vakalar, olcuN))}</div>` +
    '<div class="atolye-sayac">Grubun tüm vakaları (açık dahil); ölçüye girmeyenler sonuç sütunundan okunur. ≈ kapanış günü tahminidir.</div>' +
    uyari +
    `<table><thead><tr><th>Küpe</th><th>Hastalık</th><th>Başlangıç</th><th>Kapanış</th><th>Sonuç</th></tr></thead><tbody>${satir.join('')}</tbody></table>` +
    '<button type="button" class="atolye-baglanti" data-kurucu-eylem="vakalar-kapat">Kapat</button>';
}

/** "Bu sayıya giren vakalar": kartların altındaki tek listeye yazar. */
async function kurucuVakalarAc(grupAnahtari, { olcuN } = {}) {
  const s = window._atolye;
  const e = _kurucuEkran;
  const alan = document.getElementById('atolye-vakalar-alan');
  if (!alan) return;
  const j = ++e.vakaJeton;
  const jeton = s.jeton;
  alan.hidden = false;
  alan.innerHTML = _KURUCU_YUKLENIYOR;
  alan.scrollIntoView();
  try {
    const r = await statAtolyeVakalar(e.seriCumle, grupAnahtari);   // liste kartların sayısına aittir, panelin cümlesine değil
    if (j !== e.vakaJeton || jeton !== s.jeton) return;
    alan.innerHTML = _kurucuVakaTablo(r, grupAnahtari, olcuN);
    _kurucuBayatDegilseTemizle();
  } catch (err) {
    if (j !== e.vakaJeton || jeton !== s.jeton) return;
    alan.hidden = true;
    atolyeHataSeridi(err, document.getElementById('atolye-icerik'));
  }
}

/** İlk basış satır içi başlık alanını açar, ikincisi kaydeder. Yük: yalnız cümle (geçici fiyat yok). */
async function kurucuKaydet() {
  const s = window._atolye;
  const e = _kurucuEkran;
  if (!s.cumle || e.kaydediyor) return;
  const alan = document.getElementById('atolye-kaydet-baslik');
  if (!alan) {
    e.kaydet = true;
    e.kaydetBaslik = null;
    _kurucuPanelCiz();
    return;
  }
  const baslik = String(alan.value || '').trim() || cumleBaslik(s.cumle, s.secenekler);
  e.kaydediyor = true;
  try {
    await statGrafikKaydet(null, baslik, s.cumle);
    e.kaydet = false;
    _kurucuPanelCiz();
    _kurucuBayatDegilseTemizle();
    toast('Panoya kaydedildi');
  } catch (err) {
    atolyeHataSeridi(err, document.getElementById('atolye-icerik'));
  } finally {
    e.kaydediyor = false;
  }
}

// ── Olaylar (tek dinleyici, #atolye-icerik) ──
function _kurucuEylemCalis(ad, d) {
  const s = window._atolye;
  const e = _kurucuEkran;
  switch (ad) {
    case 'kaydet': return kurucuKaydet();
    case 'kaydet-iptal': e.kaydet = false; e.kaydetBaslik = null; return _kurucuPanelCiz();
    case 'yenile': return s.cumle ? kurucuYenile({ yenile: true }) : kurucuAc(null);
    case 'katla': e.katli = !e.katli; return _kurucuPanelCiz();
    case 'vakalar-kapat': { const a = document.getElementById('atolye-vakalar-alan'); e.vakaJeton += 1; a.hidden = true; a.innerHTML = ''; return undefined; }
    case 'aralik': {   // aynı dönemle başlar: cümle her an geçerli kalır
      const don = (s.secenekler || {}).donem || {};
      if ((s.cumle.donem || {}).tip === 'aralik') return undefined;
      return kurucuSlotDegis('donem', { tip: 'aralik', bas: don.bas || bugun(), bit: don.bit || bugun() });
    }
    case 'tarih': {
      const donem = s.cumle.donem || {};
      const bas = d.alan === 'bas';
      return tarihAlaniTakvimAc(document.getElementById(`atolye-aralik-${d.alan}`),
        bas ? { baslik: 'Başlangıç', max: donem.bit } : { baslik: 'Bitiş', min: donem.bas, max: 'bugun' });
    }
    default: return undefined;
  }
}

function _kurucuTikla(ev) {
  const t = ev.target && ev.target.closest
    ? ev.target.closest('button[data-kurucu-slot],button[data-kurucu-eylem],button[data-kurucu-vakalar]') : null;
  if (!t) return undefined;
  const d = t.dataset;
  if (d.kurucuVakalar !== undefined) return kurucuVakalarAc(d.kurucuVakalar, { olcuN: d.olcuN });
  if (d.kurucuSlot) return kurucuSlotDegis(d.kurucuSlot, JSON.parse(d.deger));
  return _kurucuEylemCalis(d.kurucuEylem, d);
}

function _kurucuDegis(ev) {
  const t = ev.target;
  const d = (t && t.dataset) || {};
  const s = window._atolye;
  if (d.kurucuSlot) return kurucuSlotDegis(d.kurucuSlot, JSON.parse(t.value));
  if (d.kurucuEgri) return _kurucuEgriDegis(t.checked);
  if (d.kurucuTarih) return kurucuSlotDegis('donem', Object.assign({}, s.cumle.donem, { [d.kurucuTarih]: t.value }));
  if (d.kurucuOlcu === 'doz') return kurucuSlotDegis('doz', t.checked);
  if (d.kurucuOlcu) {
    const secili = s.cumle.olculer || [];
    return kurucuSlotDegis('olculer', ATOLYE_OLCULER
      .filter(o => !o.pasif && (o.ad === d.kurucuOlcu ? t.checked : secili.includes(o.ad))).map(o => o.ad));
  }
  return undefined;
}

// Test için dual-mode export (tarayıcıda module undefined, etkisiz)
if (typeof module !== 'undefined' && module.exports) {
  module.exports = Object.assign(module.exports || {}, {
    kurucuAc, kurucuSlotDegis, kurucuYenile, kurucuCumlePanelHtml, kurucuKartHtml, kurucuVakalarAc, kurucuKaydet,
  });
}
