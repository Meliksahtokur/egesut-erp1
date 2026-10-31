// js/istatistik/kombinasyon.js
// İstatistik Atölyesi AP1 (T13) — kombinasyon paneli (spec §4.4, plan Task 13).
// Girdi: stat_atolye_seri.kombinasyon (20261017000003); sayılar SQL'den, burada yeniden hesaplanmaz.
// n<5 metinle ayrılır ("yetersiz (n=k)"), gri yalnız yazı rengi; çubuklar CSS genişlikli, canvas yok.
// Sayı biçimi grafik.js, x etiketi cumle.js (script sırası: ikisi de önce yüklenir).
'use strict';

const _KOMBINASYON_ESIK = 5;   // K8
const _KOMBINASYON_SIZ = { a: 'sız', ı: 'sız', e: 'siz', i: 'siz', o: 'suz', u: 'suz', ö: 'süz', ü: 'süz' };

// Ünlü uyumlu olumsuzluk eki: Enrolen'siz, Meloksikam'sız, Halocur'suz. Ünlüsüz değer: 'siz'.
function _kombinasyonSiz(y) {
  const unluler = trLower(String(y)).match(/[aıeiouöü]/g);
  return `${y}'${unluler ? _KOMBINASYON_SIZ[unluler[unluler.length - 1]] : 'siz'}`;
}

function _kombinasyonAdet(v) {
  const n = Number(v);
  return Number.isFinite(n) && n > 0 ? Math.trunc(n) : 0;
}

// null/eksik medyan 0 sayılmaz (Number(null) === 0 tuzağı).
function _kombinasyonDeger(v) {
  if (v === null || v === undefined || v === '') return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function _kombinasyonYetersiz(n) {
  return `<div class="atolye-yetersiz">yetersiz (n=${n})</div>`;
}

function _kombinasyonCubuk(yuzde, kiyas) {
  const w = Math.min(100, Math.max(0, yuzde));
  return `<div class="atolye-cubuk"><span${kiyas ? ' class="kiyas"' : ''} style="width:${w}%"></span></div>`;
}

// Hücrede basılabilir ₺ medyanı; yetersiz/fiyatsız → null (çubuk ölçeğine de girmez).
function _kombinasyonTl(g) {
  const tl = g.tl || {};
  return _kombinasyonAdet(tl.n) < _KOMBINASYON_ESIK ? null : _kombinasyonDeger(tl.medyan);
}

function _kombinasyonBasariHucre(g, kiyas) {
  const b = g.basari || {};
  const n = _kombinasyonAdet(b.n);
  const y = _kombinasyonDeger(b.y);
  if (n < _KOMBINASYON_ESIK || y === null) return _kombinasyonYetersiz(n);
  return `<div>${esc(`%${_grafikSayi(y, 1)} (${_kombinasyonAdet(b.k)}/${n})`)}${_kombinasyonCubuk(y, kiyas)}</div>`;
}

function _kombinasyonHizHucre(g) {
  const h = g.hiz || {};
  const n = _kombinasyonAdet(h.n);
  const m = _kombinasyonDeger(h.medyan);
  if (n < _KOMBINASYON_ESIK || m === null) return _kombinasyonYetersiz(n);
  return `<div>${esc(`medyan ${_grafikSayi(m, 1)} gün`)}</div>`;
}

function _kombinasyonTlHucre(g, kiyas, enBuyuk) {
  const n = _kombinasyonAdet((g.tl || {}).n);
  const m = _kombinasyonTl(g);
  if (m !== null) {
    const w = enBuyuk > 0 ? (100 * m) / enBuyuk : 0;
    return `<div>${esc(`₺${_grafikSayi(m, 2)}`)}${_kombinasyonCubuk(w, kiyas)}</div>`;
  }
  // ₺ kümesi boş: sonuçlanmış vaka varsa neden fiyattır; hiç yoksa (hepsi açık) fiyat demek yanlış olur.
  const sonuclanmis = _kombinasyonAdet((g.basari || {}).n) + _kombinasyonAdet((g.hiz || {}).n) > 0;
  return n === 0 && sonuclanmis ? '<div>fiyat yok</div>' : _kombinasyonYetersiz(n);
}

function _kombinasyonAlt(etiket, g, gri, kiyas, enBuyuk) {
  // .atolye-komb-alt rengi kendisi set eder: gri sınıfı üst satırdan miras kalmaz, burada şart.
  return `<div class="atolye-komb-alt${gri ? ' atolye-yetersiz' : ''}">`
    + `<div>${esc(etiket)}</div><div>${esc(`n=${_kombinasyonAdet(g.n)}`)}</div>`
    + _kombinasyonBasariHucre(g, kiyas) + _kombinasyonHizHucre(g) + _kombinasyonTlHucre(g, kiyas, enBuyuk)
    + '</div>';
}

function _kombinasyonSatir(s, xAd, enBuyuk) {
  const a = s.a || {};
  const b = s.b || {};
  const gri = s.yetersiz === true || _kombinasyonAdet(a.n) < _KOMBINASYON_ESIK || _kombinasyonAdet(b.n) < _KOMBINASYON_ESIK;
  return `<div class="atolye-komb-satir${gri ? ' atolye-yetersiz' : ''}">`
    + _kombinasyonAlt(`${xAd} + ${s.y} içeren`, a, gri, false, enBuyuk)
    + _kombinasyonAlt(`${xAd} içeren, ${_kombinasyonSiz(s.y)}`, b, gri, true, enBuyuk)
    + `<button type="button" class="atolye-eylem" data-komb-y="${escAttr(s.y)}">Cümleye ekle</button>`
    + '</div>';
}

/**
 * Kombinasyon paneli HTML'i; komb null → ''.
 * @param {?{x:string, satirlar:Array}} komb SQL sırası korunur.
 * @param {{gecici?:{ilac_fiyat:Object}}} [secenek] ₺ geçici fiyatla hesaplandıysa bant basılır.
 */
function kombinasyonHtml(komb, { gecici } = {}) {
  if (!komb) return '';
  const xAd = _cumleIlacEtiket(komb.x);
  const satirlar = Array.isArray(komb.satirlar) ? komb.satirlar : [];
  const tller = satirlar.flatMap(s => [_kombinasyonTl(s.a || {}), _kombinasyonTl(s.b || {})]).filter(m => m !== null);
  const enBuyuk = Math.max(0, ...tller);
  const geciciVar = !!gecici && Object.keys(gecici.ilac_fiyat || {}).length > 0;
  return '<section class="atolye-komb">'
    + `<div class="atolye-kart-baslik">${esc(`${xAd} içeren vakalarda birlikte kullanılan ilaçlar`)}</div>`
    + (geciciVar ? '<div class="atolye-gecici-bant">geçici, kaydedilmedi</div>' : '')
    + (satirlar.length
      ? satirlar.map(s => _kombinasyonSatir(s, xAd, enBuyuk)).join('')
        + '<ul class="atolye-dipnot"><li>Gruplar örtüşür; karşılaştırma gözlemseldir.</li></ul>'
      : '<div class="atolye-durum">Bu seçimde birlikte kullanılan ilaç yok</div>')
    + '</section>';
}

/** "Cümleye ekle" düğmeleri; onclick ataması yeniden çizimde dinleyici biriktirmez. */
function kombinasyonBagla(kok) {
  if (!kok) return;
  kok.querySelectorAll('[data-komb-y]').forEach(b => {
    b.onclick = () => kurucuSlotDegis('y', b.dataset.kombY);
  });
}

// Test için dual-mode export (tarayıcıda module undefined, etkisiz)
if (typeof module !== 'undefined' && module.exports) {
  module.exports = Object.assign(module.exports || {}, { kombinasyonHtml, kombinasyonBagla });
}
