// js/istatistik/atolye.js
// İstatistik Atölyesi AP1 (T11): kabuk — giriş (loadIstatistik), sekmeler (Pano · Kurucu),
// hata şeridi ve hesap tarihi. Kurucu/pano içeriği kendi modüllerinde (kurucu.js, pano.js).
// Şerit sakin gri (07 deseni): kırmızı yok; çevrimdışında son çizilen içerik silinmez, bayat işaretlenir.
'use strict';

function _atolyeDurumKur() {
  return { sekme: 'pano', cumle: null, secenekler: null, gecici: { ilac_fiyat: {} }, sonZarflar: null, onceki: [], jeton: 0 };
}

// atolyeSekme çağrı sayacı: liste beklenirken sekmeye basıldı mı (aynı sekmeye basmak da sayılır; değer kıyası bunu göremez).
let _atolyeSekmeSayac = 0;
// pano.js STAT_GRAFIK çevirisini yeni Error olarak verir (statHataKodu 'genel' der); bu biçimdeki metin önek almaz.
const _ATOLYE_GRAFIK_CEVIRI = /; liste yenilendi$/;

/**
 * Giriş (js/app.js goTo): durum kurulur (varsa korunur), önceki şerit kalkar, tanım kartları önbelleğe alınır,
 * pano açılır. Liste beklenirken sekme değiştiyse kullanıcının ekranı ezilmez, geç hata da yazılmaz.
 */
async function loadIstatistik() {
  if (!document.getElementById('istatistik-root')) return;
  if (!window._atolye) window._atolye = _atolyeDurumKur();
  atolyeHataTemizle(document.getElementById('atolye-icerik'));
  const giris = _atolyeSekmeSayac;
  try {
    await statOlcumListele();   // api.js 5 dk önbellek; kurucu/pano tanım kartlarını buradan okur
  } catch (e) {
    if (giris === _atolyeSekmeSayac) atolyeHataSeridi(e, document.getElementById('atolye-icerik'));
  }
  if (giris !== _atolyeSekmeSayac) return undefined;
  return atolyeSekme('pano');
}

/** Sekme değişimi: düğme durumu + ilgili modülün girişi. */
function atolyeSekme(sekme) {
  _atolyeSekmeSayac += 1;
  const s = window._atolye || (window._atolye = _atolyeDurumKur());
  const onceki = s.sekme;
  s.sekme = sekme === 'kurucu' ? 'kurucu' : 'pano';
  if (onceki !== s.sekme) _atolyeGrafikBirak();
  document.querySelectorAll('#atolye-sekmeler [data-sekme]').forEach(b => {
    const on = b.dataset.sekme === s.sekme;
    b.classList.toggle('on', on);
    b.setAttribute('aria-selected', on ? 'true' : 'false');
  });
  return s.sekme === 'kurucu' ? kurucuAc(s.cumle) : panoYukle();
}

// Önceki ekranın Chart örnekleri (E13): içerik birazdan yazılır, canvas giderse örnek Chart.instances'ta kalırdı.
// Aynı sekmeye basışta çağrılmaz: pano ızgarası liste gelene dek görünür kalır.
function _atolyeGrafikBirak() {
  const kok = document.getElementById('atolye-icerik');
  if (!kok) return;
  Array.from(kok.querySelectorAll('canvas')).forEach(c => {
    if (c.__chart) { c.__chart.destroy(); c.__chart = null; }
  });
}

/**
 * Hata şeridi (P13): kökün en üstüne tek şerit yazar (varsa günceller); içerik silinmez.
 * cumle → "Seçim geçersiz (<yol>)" · cevrimdisi → "İstatistik çevrimiçi hesaplanır" (+ canvas varsa bayat etiketi)
 * · ham STAT_GRAFIK → "İstatistik alınamadı" (kod gösterilmez) · çağıranın grafik çevirisi → öneksiz metin
 * · diğer → "İstatistik alınamadı: <mesaj>".
 * @returns {{tip:string}} statHataKodu sonucu.
 */
function atolyeHataSeridi(err, kok) {
  const kod = statHataKodu(err);
  let metin;
  if (kod.tip === 'cumle') {
    metin = `Seçim geçersiz (${esc(kod.yol)})`;
  } else if (kod.tip === 'cevrimdisi') {
    metin = 'İstatistik çevrimiçi hesaplanır';
    if (kok && kok.querySelector('canvas')) metin += ' <span class="atolye-bayat-etiket">gösterilen sonuç bayat</span>';
  } else if (kod.tip === 'grafik') {
    metin = 'İstatistik alınamadı';
  } else {
    const mesaj = String((err && err.message) || err || '');
    metin = _ATOLYE_GRAFIK_CEVIRI.test(mesaj) ? esc(mesaj) : `İstatistik alınamadı: ${esc(mesaj)}`;
  }
  if (!kok) return kod;
  // Sınıf şeridin tipidir: pano.js liste gelince yalnız çevrimdışı şeridi temizler (içerik yokken de, E14);
  // çeviri ya da genel hata bu şeridin üstüne yazıldıysa silinmez (K2 tur1).
  if (kod.tip === 'cevrimdisi') kok.classList.add('atolye-bayat');
  else kok.classList.remove('atolye-bayat');
  const var_ = kok.querySelector('.atolye-hata');
  if (var_) var_.innerHTML = metin;
  else kok.insertAdjacentHTML('afterbegin', `<div class="atolye-hata" role="status">${metin}</div>`);
  return kod;
}

/** Başarılı yanıttan sonra şeridi ve bayat işaretini kaldırır. */
function atolyeHataTemizle(kok) {
  if (!kok) return;
  const s = kok.querySelector('.atolye-hata');
  if (s) s.remove();
  kok.classList.remove('atolye-bayat');
}

const _ATOLYE_TR_SAAT = new Intl.DateTimeFormat('tr-TR', {
  timeZone: 'Europe/Istanbul', day: '2-digit', month: '2-digit', year: 'numeric',
  hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
});

/** ISO zaman damgası → 'Hesap tarihi: GG.AA.YYYY SS:DD' (Europe/Istanbul). Okunamazsa '—'. */
function atolyeHesapTarihi(iso) {
  const d = iso ? new Date(iso) : null;
  if (!d || isNaN(d.getTime())) return 'Hesap tarihi: —';
  const p = {};
  _ATOLYE_TR_SAAT.formatToParts(d).forEach(x => { p[x.type] = x.value; });
  return `Hesap tarihi: ${p.day}.${p.month}.${p.year} ${p.hour}:${p.minute}`;
}

// Test için dual-mode export (tarayıcıda module undefined, etkisiz)
if (typeof module !== 'undefined' && module.exports) {
  module.exports = Object.assign(module.exports || {}, {
    loadIstatistik, atolyeSekme, atolyeHataSeridi, atolyeHataTemizle, atolyeHesapTarihi,
  });
}
