// js/istatistik/cumle.js
// İstatistik Atölyesi AP1 — cümle modeli (spec §4.4, plan Task 9, P4/P5/P8).
// Saf modül: DOM'a, tarayıcı globallerine ve sunucuya dokunmaz; girdiyi değiştirmez.
// Cümle şeması v:1; sunucu doğrulayıcısı stat_cumle_dogrula (20261017000002) tek otoritedir,
// cumleIstemciDogrula onun aynasıdır (hata yolu biçimi '<yol>:<neden>', öneksiz).
// Başlık düz metindir; HTML'e basan çağıran esc() ile kaçırır.
'use strict';

const ATOLYE_OLCULER = [
  { ad: 'saglik_basari', etiket: 'Başarı oranı' },
  { ad: 'saglik_kapanma_gunu', etiket: 'Kapanma hızı' },
  { ad: 'saglik_tedavi_suresi', etiket: 'Tedavi süresi' },
  { ad: 'saglik_vaka_tl', etiket: 'Vaka başı ₺' },
  { ad: 'saglik_basari_tl', etiket: 'Başarı başına ₺' },
  { ad: 'doz', etiket: 'Doz', pasif: true },   // P8: cümleye girmez, istemci durum kartı çizer
];

// Sonuç etiketleri tek kaynak (v_stat_saglik_vaka.sonuc, 20261017000001).
const SONUC_ETIKETLERI = {
  basarili: 'Başarılı',
  basarisiz_olum_kesim: 'Başarısız (ölüm/kesim)',
  basarisiz_nuks: 'Başarısız (nüks)',
  basarisiz_tedavi_degisti: 'Başarısız (tedavi değişti)',
  olgunlasmamis: '30 gün dolmadı',
};

const _CUMLE_ANAHTAR = ['v', 'alan', 'hastalik', 'ilac', 'kiyas_grubu', 'olculer', 'kirilim', 'donem', 'kiyas_duzeyi'];
const _CUMLE_KIRILIM = ['yok', 'ilac', 'ay', 'ceyrek', 'yil'];
const _CUMLE_DUZEY = { etken: 'etken maddeye göre', preparat: 'preparata göre', sinif: 'sınıfa göre' };
const _CUMLE_ZAMAN = { ay: 'aylık', ceyrek: 'çeyreklik', yil: 'yıllık' };
const _CUMLE_DONEM_ANAHTAR = { son_ay: ['tip', 'n'], yil: ['tip', 'yil'], aralik: ['tip', 'bas', 'bit'], tumu: ['tip'] };
const _CUMLE_UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const _CUMLE_BILINMIYOR = '(bilinmiyor)';

function _cumleKopya(o) { return JSON.parse(JSON.stringify(o)); }
function _cumleNesne(o) { return o !== null && typeof o === 'object' && !Array.isArray(o); }
function _cumleVar(o, k) { return Object.prototype.hasOwnProperty.call(o, k) && o[k] !== undefined; }
function _cumleBos(s) { return s.replace(/^ +| +$/g, '') === ''; }   // PG btrim: yalnız boşluk
function _cumleEtkinOlcu(ad) { return ATOLYE_OLCULER.some(o => o.ad === ad && !o.pasif); }
// jsonb ->> eşdeğeri: metin aynen, null/eksik null, diğer tipler JSON metni
function _cumleMetin(v) { return v === null || v === undefined ? null : (typeof v === 'string' ? v : JSON.stringify(v)); }

/** Varsayılan açılış (spec §4.4): en çok vakalı hastalık, ilaçsız, etken kırılımı, son 12 ay. */
function cumleVarsayilan(secenekler) {
  const liste = (secenekler && Array.isArray(secenekler.hastaliklar)) ? secenekler.hastaliklar : [];
  let en = null;
  for (const h of liste) {
    if (!h || typeof h.id !== 'string' || !h.id) continue;
    if (!en || (Number(h.n) || 0) > (Number(en.n) || 0)) en = h;
  }
  return {
    v: 1, alan: 'saglik',
    hastalik: en ? { tip: 'hastalik', deger: en.id } : { tip: 'tumu', deger: null },
    ilac: { duzey: 'etken', x: null, y: null },
    kiyas_grubu: 'tumu',
    olculer: ['saglik_basari', 'saglik_kapanma_gunu', 'saglik_vaka_tl'],
    kirilim: 'ilac',
    donem: { tip: 'son_ay', n: 12 },
    kiyas_duzeyi: ['biz'],
  };
}

/**
 * Tek slotu günceller; yeni nesne döner, girdi değişmez. Reddedilen değerde girdinin kendisi
 * döner (çağıran `===` ile no-op'u anlar). Bilinmeyen slot programcı hatasıdır → throw.
 */
function cumleGuncelle(cumle, slot, deger) {
  const c = _cumleKopya(cumle);
  const i = c.ilac || (c.ilac = { duzey: 'etken', x: null, y: null });
  const ilacSifirla = () => { i.x = null; i.y = null; c.kiyas_grubu = 'tumu'; };
  switch (slot) {
    case 'hastalik': c.hastalik = _cumleKopya(deger); ilacSifirla(); break;
    case 'duzey':
      if (!Object.prototype.hasOwnProperty.call(_CUMLE_DUZEY, deger)) return cumle;
      i.duzey = deger; ilacSifirla();
      break;
    case 'x':
      if (deger === null || deger === undefined) { ilacSifirla(); break; }
      i.x = deger; i.y = null; c.kiyas_grubu = 'tumu';
      if (c.kirilim === 'ilac') c.kirilim = 'yok';   // P4: ilaç ekseni kombinasyon paneline geçer
      break;
    case 'y':
      if (deger === null || deger === undefined) { i.y = null; c.kiyas_grubu = 'tumu'; break; }
      if (i.x === null || i.x === undefined || deger === i.x) return cumle;
      i.y = deger; c.kiyas_grubu = 'x_y_siz';
      break;
    case 'kiyas_grubu':
      if (deger !== 'tumu' && !(deger === 'x_y_siz' && i.y !== null && i.y !== undefined)) return cumle;
      c.kiyas_grubu = deger;
      break;
    case 'olculer':
      if (!Array.isArray(deger) || deger.length === 0 || new Set(deger).size !== deger.length
          || !deger.every(_cumleEtkinOlcu)) return cumle;   // son ölçü kaldırılamaz; doz/bilinmeyen girmez
      c.olculer = deger.slice();
      break;
    case 'kirilim':
      if (!_CUMLE_KIRILIM.includes(deger) || (deger === 'ilac' && i.x !== null && i.x !== undefined)) return cumle;
      c.kirilim = deger;
      break;
    case 'donem': c.donem = _cumleKopya(deger); break;
    default: throw new Error('cumleGuncelle: bilinmeyen slot ' + String(slot));
  }
  return c;
}

function _cumleIlacEtiket(d) { return d === _CUMLE_BILINMIYOR ? 'Tanınamayan ilaç' : String(d); }
function _cumleTarih(s) { const p = String(s).split('-'); return p.length === 3 ? `${p[2]}.${p[1]}.${p[0]}` : String(s); }

/** Okunur başlık: "Sağlık › <H> vakalarında › <x>[ + <y>] içeren › <ölçüler> › <kırılım> › <dönem>". */
function cumleBaslik(cumle, secenekler) {
  const h = cumle.hastalik || {};
  let ad = 'Tüm hastalıklar';
  if (h.tip === 'kategori') ad = String(h.deger);
  else if (h.tip === 'hastalik') {
    const bul = (secenekler && Array.isArray(secenekler.hastaliklar) ? secenekler.hastaliklar : [])
      .find(o => o && o.id === h.deger);
    ad = bul && bul.ad ? bul.ad : 'Seçili hastalık';
  }
  const parca = ['Sağlık', `${ad} vakalarında`];
  const i = cumle.ilac || {};
  if (i.x !== null && i.x !== undefined) {
    parca.push(`${_cumleIlacEtiket(i.x)}${i.y !== null && i.y !== undefined ? ' + ' + _cumleIlacEtiket(i.y) : ''} içeren`);
  }
  parca.push((cumle.olculer || []).map(a => (ATOLYE_OLCULER.find(o => o.ad === a) || { etiket: a }).etiket).join(', '));
  if (cumle.kirilim === 'ilac') parca.push(_CUMLE_DUZEY[i.duzey] || _CUMLE_DUZEY.etken);
  else if (_CUMLE_ZAMAN[cumle.kirilim]) parca.push(_CUMLE_ZAMAN[cumle.kirilim]);
  const d = cumle.donem || {};
  if (d.tip === 'son_ay') parca.push(`son ${d.n} ay`);
  else if (d.tip === 'yil') parca.push(`${d.yil} yılı`);
  else if (d.tip === 'aralik') parca.push(`${_cumleTarih(d.bas)}–${_cumleTarih(d.bit)}`);
  else if (d.tip === 'tumu') parca.push('tüm zamanlar');
  return parca.join(' › ');
}

function _cumleGecerliTarih(s) {
  const [y, a, g] = s.split('-').map(Number);
  if (y < 1 || a < 1 || a > 12 || g < 1) return false;
  return g <= new Date(Date.UTC(y, a, 0)).getUTCDate();   // ayın son günü (artık yıl dahil)
}

// Slot denetçileri: SQL sırasıyla, slotun İLK hatasını döner (yoksa null).
function _cumleHastalikHata(h) {
  if (!_cumleNesne(h)) return 'hastalik:nesne_degil';
  const fazla = Object.keys(h).filter(k => !['tip', 'deger'].includes(k)).sort()[0];
  if (fazla) return `hastalik.${fazla}:bilinmeyen_anahtar`;
  const d = h.deger;
  if (h.tip === 'tumu') return d === null || d === undefined ? null : 'hastalik.deger:tumu_ile_deger';
  if (h.tip === 'kategori') return typeof d === 'string' && !_cumleBos(d) ? null : 'hastalik.deger:metin_degil';
  if (h.tip === 'hastalik') return typeof d === 'string' && _CUMLE_UUID.test(d) ? null : 'hastalik.deger:uuid_degil';
  return 'hastalik.tip:gecersiz';   // hastalik_yok (DB varlığı) yalnız sunucuda
}

function _cumleIlacHata(i) {
  if (!_cumleNesne(i)) return 'ilac:nesne_degil';
  const fazla = Object.keys(i).filter(k => !['duzey', 'x', 'y'].includes(k)).sort()[0];
  if (fazla) return `ilac.${fazla}:bilinmeyen_anahtar`;
  if (!Object.prototype.hasOwnProperty.call(_CUMLE_DUZEY, i.duzey)) return 'ilac.duzey:gecersiz';
  for (const k of ['x', 'y']) {
    const v = i[k];
    if (!(v === null || v === undefined || (typeof v === 'string' && !_cumleBos(v)))) return `ilac.${k}:metin_degil`;
  }
  const x = _cumleMetin(i.x), y = _cumleMetin(i.y);
  if (y !== null && x === null) return 'ilac.y:x_yok';
  if (y !== null && y === x) return 'ilac.y:x_ile_ayni';
  return null;
}

function _cumleOlcuHata(o) {
  if (!Array.isArray(o)) return 'olculer:dizi_degil';
  if (o.length === 0) return 'olculer:bos';
  if (o.some(e => typeof e !== 'string')) return 'olculer:metin_degil';
  if (o.includes('saglik_doz')) return 'olculer:doz_hesaplanmaz';
  if (!o.every(_cumleEtkinOlcu)) return 'olculer:bilinmeyen';
  return new Set(o).size < o.length ? 'olculer:tekrar' : null;
}

function _cumleDonemHata(d) {
  if (!_cumleNesne(d)) return 'donem:nesne_degil';
  const izin = typeof d.tip === 'string' && Object.prototype.hasOwnProperty.call(_CUMLE_DONEM_ANAHTAR, d.tip)
    ? _CUMLE_DONEM_ANAHTAR[d.tip] : null;
  if (!izin) return 'donem.tip:gecersiz';
  const fazla = Object.keys(d).filter(k => !izin.includes(k)).sort()[0];
  if (fazla) return `donem.${fazla}:bilinmeyen_anahtar`;
  if (d.tip === 'son_ay') return [3, 6, 12, 24].includes(d.n) ? null : 'donem.n:gecersiz';
  if (d.tip === 'yil') return Number.isInteger(d.yil) && d.yil >= 1900 && d.yil <= 2100 ? null : 'donem.yil:gecersiz';
  if (d.tip === 'aralik') {
    for (const k of ['bas', 'bit']) {
      if (typeof d[k] !== 'string' || !/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(d[k])) return `donem.${k}:tarih_degil`;
    }
    if (!_cumleGecerliTarih(d.bas) || !_cumleGecerliTarih(d.bit)) return 'donem:tarih_degil';
    if (d.bit < d.bas) return 'donem:ters';
  }
  return null;
}

/** stat_cumle_dogrula istemci aynası: hata yolları ('<yol>:<neden>'); boş dizi = geçerli. */
function cumleIstemciDogrula(cumle) {
  if (!_cumleNesne(cumle)) return ['cumle:nesne_degil'];
  const h = [];
  Object.keys(cumle).filter(k => !_CUMLE_ANAHTAR.includes(k)).sort().forEach(k => h.push(`${k}:bilinmeyen_anahtar`));
  _CUMLE_ANAHTAR.filter(k => !_cumleVar(cumle, k)).forEach(k => h.push(`${k}:eksik`));
  const ekle = (k, f) => { if (_cumleVar(cumle, k)) { const e = f(cumle[k]); if (e) h.push(e); } };
  ekle('v', v => (v === 1 ? null : 'v:surum'));
  ekle('alan', a => (a === 'saglik' ? null : 'alan:gecersiz'));
  ekle('hastalik', _cumleHastalikHata);
  ekle('ilac', _cumleIlacHata);
  const i = _cumleNesne(cumle.ilac) ? cumle.ilac : {};
  const x = _cumleMetin(i.x), y = _cumleMetin(i.y);
  ekle('kiyas_grubu', k => (k !== 'tumu' && k !== 'x_y_siz' ? 'kiyas_grubu:gecersiz'
    : (k === 'x_y_siz' && y === null ? 'kiyas_grubu:y_yok' : null)));
  ekle('olculer', _cumleOlcuHata);
  ekle('kirilim', k => (!_CUMLE_KIRILIM.includes(k) ? 'kirilim:gecersiz'
    : (x !== null && k === 'ilac' ? 'kirilim:x_ile_ilac' : null)));
  ekle('donem', _cumleDonemHata);
  ekle('kiyas_duzeyi', k => (Array.isArray(k) && k.length === 1 && k[0] === 'biz' ? null : 'kiyas_duzeyi:yalniz_biz'));
  return h;
}

/** Kararlı JSON: nesne anahtarları sıralı, dizi sırası korunur (önbellek/eşitlik anahtarı). */
function cumleAnahtar(cumle) {
  const sirala = v => (Array.isArray(v) ? v.map(sirala)
    : (_cumleNesne(v) ? Object.keys(v).sort().reduce((o, k) => { o[k] = sirala(v[k]); return o; }, {}) : v));
  return JSON.stringify(sirala(cumle));
}

/** Sonuç etiketi; bilinmeyen değer gizlenmez → 'Diğer' + bilinmeyen:true (çağıran uyarı basar).
 *  NULL sonuç: 'Açık' yalnız durum 'acik' iken; durum eksik/bilinmiyorsa fail-closed 'Diğer' (KF2-Ö2). */
function sonucEtiket(deger, durum) {
  if (deger === null || deger === undefined) {
    if (durum === 'acik') return { etiket: 'Açık', bilinmeyen: false };
    if (durum === 'kapali_tarihsiz') return { etiket: 'Kapanış tarihi yok', bilinmeyen: false };
    return { etiket: 'Diğer', bilinmeyen: true };
  }
  if (typeof deger === 'string' && Object.prototype.hasOwnProperty.call(SONUC_ETIKETLERI, deger)) {
    return { etiket: SONUC_ETIKETLERI[deger], bilinmeyen: false };
  }
  return { etiket: 'Diğer', bilinmeyen: true };
}

// Test için dual-mode export (tarayıcıda module undefined, etkisiz)
if (typeof module !== 'undefined' && module.exports) {
  module.exports = Object.assign(module.exports || {}, {
    ATOLYE_OLCULER, SONUC_ETIKETLERI, cumleVarsayilan, cumleGuncelle, cumleBaslik,
    cumleIstemciDogrula, cumleAnahtar, sonucEtiket,
  });
}
