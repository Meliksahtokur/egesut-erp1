// js/istatistik/pano.js
// İstatistik Atölyesi AP1 (T15): kaydedilen grafikler panosu (spec §4.7, plan Task 15, P9, P10).
// Kayıt = cümle; kart açılışta güncel hesapla çizilir, geçici fiyat panoda yoktur (2. argüman her zaman {}).
// Kartlar sırayla yüklenir, bir kartın hatası diğerini durdurmaz. Hesap yok: sayı, özet ve dipnot zarftan/grafik.js'ten.
// DB değeri onclick metnine girmez: id data-grafik-id'de, işleyici this.closest ile okur.
'use strict';

// {kayitlar, kartlar: {id: {zarflar, durum, secenekler, silOnay}}, sirala, mesgul}. Her panoYukle yeni nesne kurar;
// nesne kimliği yarış jetonudur (eski koşunun yanıtı yeni duruma yazılmaz).
let _pano = null;

const _PANO_YUKLENIYOR = '<div class="loader"><div class="spin"></div></div>';
const _PANO_FIYATSIZ = 'Fiyat girilmedi';
const _PANO_GRAFIK_METIN = {
  yok: 'Grafik bulunamadı; liste yenilendi',
  sira_kumesi: 'Grafik listesi değişmiş; liste yenilendi',
};

function _panoKok() { return document.getElementById('atolye-icerik'); }
function _panoSurumTamam(kayit) { return Number(kayit.cumle_surum) === 1; }

function _panoGecerli(s) {
  return s === _pano && (!window._atolye || window._atolye.sekme === 'pano');
}

// Cümlenin ilk ölçüsünün zarfı; sıra farklı gelse de cümleden okunur.
function _panoIlkZarf(kayit, zarflar) {
  const liste = zarflar || [];
  const ad = ((kayit.cumle && kayit.cumle.olculer) || [])[0];
  return liste.find(z => z && z.olcum === ad) || liste[0] || null;
}

function _panoDurumKutu(metin) { return `<div class="atolye-durum">${esc(metin)}</div>`; }

// Fiyat panoda girilmez: kartın cümlesiyle kurucuya götürür (Kurucuda aç yolu).
function _panoFiyatEylem(sinif) { return `<button class="${sinif}" onclick="_panoKurucudaAc(this)">Kurucuda fiyat gir</button>`; }

function _panoIcerikHtml(d, ilk, cumle) {
  if (d === 'eski') return _panoDurumKutu('Bu grafik eski sürümle kaydedildi, yeniden kur.');
  if (d === 'yukleniyor') return _PANO_YUKLENIYOR;
  if (d === 'hata') return _panoDurumKutu('Bu grafik hesaplanamadı.');
  if (d === 'fiyat_yok') return `<div class="atolye-durum"><div>${esc(_PANO_FIYATSIZ)}</div><div>${_panoFiyatEylem('atolye-eylem')}</div></div>`;
  if (d === 'zaman_seyrek') return _panoDurumKutu(durumMetni(d, ilk, cumle).metin) + _kurucuYetersizSatir(ilk);   // eylem: "Kurucuda aç"
  if (d !== 'tamam' && d !== 'kontrast_yok') return _panoDurumKutu(durumMetni(d, ilk, cumle).metin);
  const uyari = d === 'kontrast_yok' ? `<div class="atolye-sayac">${esc(durumMetni(d, ilk, cumle).metin)}</div>` : '';
  return `<div class="atolye-grafik"><canvas></canvas></div><p class="atolye-ozet">${esc(zarfOzetCumle(ilk))}</p>${_kurucuUyariSatir(ilk, d)}${_kurucuYetersizSatir(ilk)}${uyari}`;
}

// Diğer ölçülerin tek satırı (P10): çizilebilir ölçüde özet cümlesi, aksi ölçü adı + durum metni.
function _panoDigerOzetHtml(z, cumle) {
  const d = zarfDurum(z, cumle);
  let metin;
  if (d === 'tamam' || d === 'kontrast_yok') metin = zarfOzetCumle(z);
  else if (d === 'zaman_seyrek' && _grafikDoluNokta(z)) metin = durumMetni(d, z, cumle).metin;   // ölçü adı cümlede var
  else {
    const o = ATOLYE_OLCULER.find(x => x.ad === z.olcum);
    metin = `${o ? o.etiket : 'Ölçü'}: ${d === 'fiyat_yok' ? _PANO_FIYATSIZ : durumMetni(d, z, cumle).metin}`;
  }
  return metin ? `<p class="atolye-ozet">${esc(metin)}${d === 'fiyat_yok' ? ` ${_panoFiyatEylem('atolye-baglanti')}` : ''}</p>` : '';
}

// Yazma kilidi görünür (A1): mesgul iken ▲/▼ ve onay Sil pasif çizilir.
function _panoKilitliDugme(sinif, ek, metin) {
  const k = !!(_pano && _pano.mesgul);
  return `<button class="${sinif}${k ? ' atolye-pasif' : ''}"${k ? ' disabled' : ''} data-pano-kilit ${ek}>${metin}</button>`;
}

// Ekrandaki düğmeleri kilide uydurur; kart yeniden çizilmez, grafik ve açık onay yerinde kalır.
function _panoKilitYaz() {
  const kok = _panoKok();
  if (!kok || !_pano) return;
  const k = !!_pano.mesgul;
  Array.from(kok.querySelectorAll('[data-pano-kilit]')).forEach(b => {
    b.disabled = k;
    b.classList.toggle('atolye-pasif', k);
  });
}

function _panoEylemHtml(onay) {
  if (onay) {
    return `<span class="atolye-sil-onay">Emin misiniz? ${_panoKilitliDugme('atolye-eylem', 'onclick="_panoSilOnayla(this)"', 'Sil')}`
      + '<button class="atolye-eylem" onclick="_panoSilVazgec(this)">Vazgeç</button></span>';
  }
  return '<button class="atolye-eylem" onclick="_panoKurucudaAc(this)">Kurucuda aç</button>'
    + '<button class="atolye-eylem" onclick="_panoSilSor(this)">Sil</button>';
}

function _panoSiraHtml() {
  if (!_pano || !_pano.sirala || _pano.kayitlar.length < 2) return '';
  return '<span class="atolye-tutamak" aria-hidden="true">⋮⋮</span><span class="atolye-sira">'
    + _panoKilitliDugme('', 'aria-label="Yukarı taşı" onclick="_panoSiraTasi(this,-1)"', '▲')
    + _panoKilitliDugme('', 'aria-label="Aşağı taşı" onclick="_panoSiraTasi(this,1)"', '▼') + '</span>';
}

/**
 * Pano kartı (P10). durum: 'yukleniyor' | 'hata' | 'cevrimdisi' | zarfDurum değeri; boşsa ilk zarftan hesaplanır.
 * Bilinmeyen cumle_surum her durumun önüne geçer; cümlesi okunmaz, hesap yapılmaz, Sil açık kalır.
 */
function panoKartHtml(kayit, zarflar, durum) {
  const kart = (_pano && _pano.kartlar[kayit.id]) || {};
  const eski = !_panoSurumTamam(kayit);
  const cumle = kayit.cumle;
  const ilk = eski ? null : _panoIlkZarf(kayit, zarflar);
  const d = eski ? 'eski' : (durum || zarfDurum(ilk, cumle));
  const ilacRozet = ilk ? grafikRozet(ilk, d) : null;
  let rozet = '';
  if (ilacRozet) rozet = `<span class="atolye-rozet">${esc(ilacRozet)}</span>`;
  else if (ilacRozet === null && ilk && ilk.n !== null && ilk.n !== undefined) rozet = `<span class="atolye-rozet">n=${esc(String(ilk.n))}</span>`;
  // Başlık cümleyle aynıysa ikinci kez yazılmaz; özel başlıkta cümle Ayrıntı'da (TF G3).
  const cumleMetin = eski ? '' : cumleBaslik(cumle, kart.secenekler);
  const cumleSatir = cumleMetin && cumleMetin !== kayit.baslik ? `<div class="atolye-hesap">${esc(cumleMetin)}</div>` : '';
  const hesap = eski || d === 'yukleniyor' ? '' : `<div class="atolye-hesap">${esc(atolyeHesapTarihi(ilk && ilk.hesap_at))} · `
    + '<button class="atolye-baglanti" onclick="_panoYenidenHesapla(this)">Yeniden hesapla</button></div>';
  const diger = eski ? '' : (zarflar || []).filter(z => z && z !== ilk).map(z => _panoDigerOzetHtml(z, cumle)).join('');
  const { kalan } = grafikDipnotAyir(ilk, d);
  const dipnot = kalan.length ? `<ul class="atolye-dipnot">${kalan.map(x => `<li>${esc(x)}</li>`).join('')}</ul>` : '';
  // Hesap hatasında "Yeniden hesapla" kapalı alanda saklanmaz.
  const hesapDisarda = d === 'hata' || d === 'cevrimdisi';
  const ayrinti = cumleSatir + (hesapDisarda ? '' : hesap) + dipnot;
  return `<div class="atolye-kart" data-grafik-id="${escAttr(kayit.id)}">`
    + `<div class="atolye-kart-bas"><div>${_panoSiraHtml()}<div class="atolye-kart-baslik">${esc(kayit.baslik)}</div></div>${rozet}</div>`
    + (hesapDisarda ? hesap : '') + _panoIcerikHtml(d, ilk, cumle) + diger
    + (ayrinti ? `<details class="atolye-ayrinti"><summary>Ayrıntı</summary>${ayrinti}</details>` : '')
    + `<div class="atolye-panel-alt" data-pano-eylem>${_panoEylemHtml(kart.silOnay)}</div></div>`;
}

function _panoKartEl(id) {
  const kok = _panoKok();
  return kok ? Array.from(kok.querySelectorAll('[data-grafik-id]')).find(k => k.dataset.grafikId === id) || null : null;
}

// Kök yazımı: varsa hata şeridi yeni içeriğin üstünde korunur (loadIstatistik şeridi dahil).
function _panoYaz(kok, html) {
  const serit = kok.querySelector('.atolye-hata');
  kok.innerHTML = (serit ? serit.outerHTML : '') + html;
}

function _panoChartBirak(kok) {
  if (!kok) return;
  Array.from(kok.querySelectorAll('canvas')).forEach(c => { if (c.__chart) c.__chart.destroy(); });
}

function _panoCiz(id) {
  const el = _panoKartEl(id);
  const canvas = el && el.querySelector('canvas');
  const kayit = _pano.kayitlar.find(k => k.id === id);
  const ilk = canvas && kayit ? _panoIlkZarf(kayit, _pano.kartlar[id].zarflar) : null;
  if (!ilk) return;
  try {
    grafikCiz(canvas, zarfGrafikConfig(ilk, { tema: temaRenkleri() }));
  } catch (e) {
    atolyeHataSeridi(e, _panoKok());
  }
}

function _panoSiraDugmeleri(el) {
  const sira = el && el.querySelector('.atolye-sira');
  return sira ? Array.from(sira.querySelectorAll('button')) : [];
}

function _panoKartYaz(id) {
  const el = _panoKartEl(id);
  const kayit = _pano.kayitlar.find(k => k.id === id);
  if (!el || !kayit) return;
  _panoChartBirak(el);
  const kart = _pano.kartlar[id];
  const odak = _panoSiraDugmeleri(el).indexOf(document.activeElement);   // sıra modunda geç gelen hesap odağı düşürmez
  el.outerHTML = panoKartHtml(kayit, kart.zarflar, kart.durum);
  if (odak !== -1) _panoSiraDugmeleri(_panoKartEl(id))[odak].focus();
  _panoCiz(id);
}

function _panoIzgaraYaz() {
  const kok = _panoKok();
  const s = _pano;
  if (!kok || !s) return;
  s.kayitlar = s.kayitlar.filter(k => s.kartlar[k.id]);   // uçuştaki eski Sil paylaşılan kartlar'dan silmiş olabilir
  _panoChartBirak(kok);
  if (!s.kayitlar.length) {
    _panoYaz(kok, '<div class="atolye-bos"><p>Henüz kaydedilmiş grafik yok.</p>'
      + `<button class="atolye-btn-ana" onclick="atolyeSekme('kurucu')">+ Yeni grafik kur</button></div>`);
    return;
  }
  const sirala = s.kayitlar.length < 2 ? '' : (s.sirala
    ? '<button class="atolye-eylem" onclick="panoSiralaModu(false)">Sıralamayı bitir</button>'
    : '<button class="atolye-eylem" onclick="panoSiralaModu(true)">Sırala</button>');
  _panoYaz(kok, '<div class="atolye-kart-bas"><div class="atolye-kart-baslik">Kaydettiğim grafikler</div>'
    + `<div class="atolye-cipler">${sirala}<button class="atolye-btn-ana" onclick="atolyeSekme('kurucu')">+ Yeni grafik kur</button></div></div>`
    + `<div class="atolye-pano">${s.kayitlar.map(k => panoKartHtml(k, s.kartlar[k.id].zarflar, s.kartlar[k.id].durum)).join('')}</div>`);
  s.kayitlar.forEach(k => _panoCiz(k.id));
}

// Tek kartın hesabı. Hastalık adı yalnız id'li cümlede ek RPC ister; alınamazsa kart "Seçili hastalık" yazar.
async function _panoKartYukle(s, k, yenile) {
  const kart = s.kartlar[k.id];
  try {
    const seri = yenile ? statAtolyeSeri(k.cumle, {}, { yenile: true }) : statAtolyeSeri(k.cumle, {});
    const sec = k.cumle.hastalik && k.cumle.hastalik.tip === 'hastalik' && !kart.secenekler
      ? statAtolyeSecenekler(k.cumle).catch(() => null) : kart.secenekler;
    const [veri, secenekler] = await Promise.all([seri, sec]);
    kart.zarflar = (veri && veri.zarflar) || [];
    kart.secenekler = secenekler;
    kart.durum = null;
    if (yenile && _panoGecerli(s)) atolyeHataTemizle(_panoKok());
  } catch (e) {
    if (!_panoGecerli(s)) return;
    if (!kart.zarflar) kart.durum = statHataKodu(e).tip === 'cevrimdisi' ? 'cevrimdisi' : 'hata';   // çizili grafik bayat kalır
    atolyeHataSeridi(e, _panoKok());
  }
  if (_panoGecerli(s)) _panoKartYaz(k.id);
}

/** Kayıtlı grafikleri yükler, ızgarayı çizer, kartları sırayla hesaplar. Boş → boş durum; liste hatası → şerit. */
async function panoYukle() {
  const kok = _panoKok();
  if (!kok) return;
  const onceki = _pano;
  const eskiIzgara = !!(onceki && kok.querySelector('.atolye-pano'));
  // Izgara ekrandaysa durum devralınır, düğmeler canlı kalır; liste gelene dek yazma kapalı (eski listeyle sıra/sil gitmez).
  const s = { kayitlar: eskiIzgara ? onceki.kayitlar : [], kartlar: eskiIzgara ? onceki.kartlar : {},
    sirala: eskiIzgara && onceki.sirala, mesgul: true };
  _pano = s;
  if (eskiIzgara) _panoKilitYaz();
  else _panoYaz(kok, _PANO_YUKLENIYOR);
  let liste;
  try {
    liste = await statGrafikListele();
  } catch (e) {
    if (!_panoGecerli(s)) return;
    s.mesgul = false;
    if (eskiIzgara) {   // son çizim bayat etiketiyle kalır (§4.8); yarıda kalan kartta çark kalmaz, "Yeniden hesapla" açılır
      const tip = statHataKodu(e).tip === 'cevrimdisi' ? 'cevrimdisi' : 'hata';
      Object.values(s.kartlar).forEach(k => { if (k.durum === 'yukleniyor') k.durum = tip; });
      _panoIzgaraYaz();
    } else _panoYaz(kok, _panoDurumKutu('Kayıtlı grafikler alınamadı.'));
    atolyeHataSeridi(e, kok);
    return;
  }
  if (!_panoGecerli(s)) return;
  if (kok.classList.contains('atolye-bayat')) atolyeHataTemizle(kok);   // liste geldi: çevrimdışı şeridi artık geçersiz
  s.mesgul = false;
  s.kayitlar = Array.isArray(liste) ? liste : [];
  s.kartlar = {};
  s.kayitlar.forEach(k => { s.kartlar[k.id] = { zarflar: null, durum: _panoSurumTamam(k) ? 'yukleniyor' : null, secenekler: null, silOnay: false }; });
  _panoIzgaraYaz();
  for (const k of s.kayitlar.slice()) {
    if (!_panoGecerli(s)) return;
    if (_panoSurumTamam(k) && s.kayitlar.includes(k)) await _panoKartYukle(s, k, false);
  }
}

/** Sıralama modu (P9): kartlarda ⋮⋮ + ▲/▼; yeniden hesap yok, kartlar eldeki zarfla çizilir. */
function panoSiralaModu(acik) {
  if (!_pano || !_pano.kayitlar.length) return;
  _pano.sirala = !!acik;
  _panoIzgaraYaz();
}

/** Saf: id'yi yon (-1 yukarı / +1 aşağı) yönünde bir adım taşır; taşınamıyorsa aynı diziyi döner. */
function panoTasi(idler, id, yon) {
  const i = idler.indexOf(id);
  const j = i + Math.sign(yon);
  if (i < 0 || j < 0 || j >= idler.length) return idler;
  const yeni = idler.slice();
  yeni[i] = idler[j];
  yeni[j] = id;
  return yeni;
}

function _panoHedef(el) {
  const k = el.closest('[data-grafik-id]');
  const id = k ? k.dataset.grafikId : null;
  const kayit = _pano ? _pano.kayitlar.find(x => x.id === id) : null;
  return kayit ? { el: k, kayit, kart: _pano.kartlar[id] } : null;
}

// Sil/sırala hatası: STAT_GRAFIK okunur metne çevrilir ve liste tazelenir (küme değişmiş); diğerleri şeride olduğu gibi.
function _panoYazmaHatasi(e) {
  const kod = statHataKodu(e);
  if (kod.tip !== 'grafik') { atolyeHataSeridi(e, _panoKok()); return null; }
  atolyeHataSeridi(new Error(_PANO_GRAFIK_METIN[kod.neden] || 'Grafik işlemi yapılamadı; liste yenilendi'), _panoKok());
  return panoYukle();
}

// Izgara yeniden yazılınca odak body'ye düşer (E13): kartın aynı yöndeki düğmesine döner, kart o uca geldiyse diğerine.
// Kullanıcı bu arada başka yere geçtiyse odak çalınmaz.
function _panoSiraOdak(id, yon) {
  const aktif = document.activeElement;
  if (!_pano || (aktif && aktif !== document.body)) return;
  const sira = _pano.kayitlar.findIndex(k => k.id === id);
  if (sira < 0) return;
  const ucta = yon < 0 ? sira === 0 : sira === _pano.kayitlar.length - 1;
  const d = _panoSiraDugmeleri(_panoKartEl(id))[(yon < 0) === ucta ? 1 : 0];
  if (d) d.focus();
}

async function _panoSiraTasi(el, yon) {
  const s = _pano;
  const h = _panoHedef(el);
  if (!h || s.mesgul) return;
  const eski = s.kayitlar;
  const idler = eski.map(k => k.id);
  const yeni = panoTasi(idler, h.kayit.id, yon);
  if (yeni === idler) return;
  s.kayitlar = yeni.map(id => eski.find(k => k.id === id));
  s.mesgul = true;
  _panoIzgaraYaz();
  try {
    await statGrafikSirala(yeni);
    s.mesgul = false;
    if (_panoGecerli(s)) { atolyeHataTemizle(_panoKok()); _panoKilitYaz(); _panoSiraOdak(h.kayit.id, yon); }
  } catch (e) {
    s.mesgul = false;
    s.kayitlar = eski;
    if (!_panoGecerli(s)) return;
    _panoIzgaraYaz();
    await _panoYazmaHatasi(e);
    _panoSiraOdak(h.kayit.id, yon);   // STAT_GRAFIK hatasında liste yenilemesi de bitmiş olur
  }
}

function _panoEylemYaz(h, onay) {
  h.kart.silOnay = onay;
  h.el.querySelector('[data-pano-eylem]').innerHTML = _panoEylemHtml(onay);
}

function _panoSilSor(el) { const h = _panoHedef(el); if (h) _panoEylemYaz(h, true); }
function _panoSilVazgec(el) { const h = _panoHedef(el); if (h) _panoEylemYaz(h, false); }

async function _panoSilOnayla(el) {
  const s = _pano;
  const h = _panoHedef(el);
  if (!h || s.mesgul) return;
  s.mesgul = true;
  _panoKilitYaz();
  try {
    await statGrafikSil(h.kayit.id);
    s.mesgul = false;
    s.kayitlar = s.kayitlar.filter(k => k.id !== h.kayit.id);
    delete s.kartlar[h.kayit.id];
    if (_panoGecerli(s)) { atolyeHataTemizle(_panoKok()); _panoIzgaraYaz(); }
    else if (_pano.kartlar === s.kartlar && _panoGecerli(_pano)) _panoIzgaraYaz();   // yeni koşu aynı kartları gösteriyor: silinen kart ekrandan düşer
  } catch (e) {
    s.mesgul = false;
    // Yeni koşu başlamış olsa da hata görünür (A1-sil); yalnız başka sekmenin ekranına yazılmaz.
    if (!_panoGecerli(_pano)) return;
    const el = _panoKartEl(h.kayit.id);
    if (el && _pano.kartlar[h.kayit.id] === h.kart) _panoEylemYaz({ el, kart: h.kart }, false);   // yeni listenin kendi onayına dokunmaz
    _panoKilitYaz();
    await _panoYazmaHatasi(e);
  }
}

// Sürümü bilinmeyen cümle kurucuya taşınmaz; kurucu mevcut cümlesiyle açılır ("yeniden kur").
function _panoKurucudaAc(el) {
  const h = _panoHedef(el);
  if (!h) return null;
  if (_panoSurumTamam(h.kayit)) window._atolye.cumle = JSON.parse(JSON.stringify(h.kayit.cumle));
  return atolyeSekme('kurucu');
}

function _panoYenidenHesapla(el) {
  const h = _panoHedef(el);
  return h ? _panoKartYukle(_pano, h.kayit, true) : null;
}

// Test için dual-mode export (tarayıcıda module undefined, etkisiz)
if (typeof module !== 'undefined' && module.exports) {
  module.exports = Object.assign(module.exports || {}, { panoYukle, panoKartHtml, panoSiralaModu, panoTasi });
}
