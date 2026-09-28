// js/degisiklikler/diff.js
// SAF katman (G-20260913-SURUM-GECMISI F3): degisim_log satırlarından alan farkı
// ve işlem özeti üretir. DOM'a dokunmaz; node --test ile test edilir
// (tests/unit/degisiklikler-diff.test.js).

// Anahtar sırasından bağımsız, derin eşitlik için kararlı serileştirme
/**
 * Verilen değeri derinlemesine JSON formatına dönüştürür; dizi ve nesne yapılarını koruyarak sıralı anahtarlarla string'ler döndürür.
 * @param {*} v Dönüştürülecek değer.
 * @returns {string} JSON benzeri string formatında dönüştürülmüş değer.
 */
function _dgKararli(v) {
  if (v === undefined) return 'undefined';
  if (v === null || typeof v !== 'object') return JSON.stringify(v);
  if (Array.isArray(v)) return '[' + v.map(_dgKararli).join(',') + ']';
  return '{' + Object.keys(v).sort().map(k => JSON.stringify(k) + ':' + _dgKararli(v[k])).join(',') + '}';
}

/**
 * Verilen değeri kontrol edip nesne ise döndürür, yoksa null döndürür.
 * @param {*} v Kontrol edilecek değer.
 * @returns {*} Nesne ise o nesne, değilse null.
 */
function _dgNesne(v) {
  return v && typeof v === 'object' && !Array.isArray(v) ? v : null;
}

// diffSatirlari(eski, yeni) -> [{alan, eski, yeni, durum}]
// durum: 'eklendi' | 'silindi' | 'degisti' | 'ayni'
//  - eski yok (INSERT)  → tüm alanlar 'eklendi'
//  - yeni yok (DELETE)  → tüm alanlar 'silindi'
//  - ikisi de var (UPDATE) → alan bazında karşılaştırma; eksik değer null gösterilir
// Sıra: eski satırın alan sırası, ardından yalnız yenide olan alanlar.
/**
 * İki nesne arasındaki alan (property) farklarını tespit eder;
 * sadece birinde olan alanları 'eklendi' veya 'silindi' olarak,
 * her ikisinde olan alanları ise değerlerini karşılaştırarak 'ayni' veya 'degisti' olarak etiketler.
 * @param {Object} eski Karşılaştırma için eski nesne.
 * @param {Object} yeni Karşılaştırma için yeni nesne.
 * @returns {Array} Her satır için { alan, eski, yeni, durum } yapısında nesnelerden oluşan dizi.
 */
function diffSatirlari(eski, yeni) {
  const e = _dgNesne(eski), y = _dgNesne(yeni);
  if (!e && !y) return [];
  const alanlar = [];
  const gorulen = new Set();
  [e, y].forEach(o => {
    if (!o) return;
    Object.keys(o).forEach(k => { if (!gorulen.has(k)) { gorulen.add(k); alanlar.push(k); } });
  });
  return alanlar.map(alan => {
    const eVar = !!e && Object.prototype.hasOwnProperty.call(e, alan);
    const yVar = !!y && Object.prototype.hasOwnProperty.call(y, alan);
    const ev = eVar ? e[alan] : null;
    const yv = yVar ? y[alan] : null;
    let durum;
    if (!eVar) durum = 'eklendi';
    else if (!yVar) durum = 'silindi';
    else durum = _dgKararli(ev) === _dgKararli(yv) ? 'ayni' : 'degisti';
    return { alan, eski: ev, yeni: yv, durum };
  });
}

// islemOzeti(rows) -> {tablo_sayisi, satir_sayisi, islemler:{I,U,D}}
// rows: degisim_log detay kayıtları ({tablo_adi, satir_pk, islem}).
// Aynı satırın aynı tx içindeki birden çok sürümü tek satır sayılır.
/**
 * Verilen satır dizisini işleyerek tabloların, satırların sayısını ve islemlerin (I, U, D) dağılımını döndürür.
 * @param {Array} rows İşlenecek satır nesnelerinden oluşan dizi.
 * @returns {Object} tablo_sayisi, satir_sayisi ve islemler (I, U, D sayıları) içeren nesne.
 */
function islemOzeti(rows) {
  const liste = Array.isArray(rows) ? rows : [];
  const tablolar = new Set();
  const satirlar = new Set();
  const islemler = { I: 0, U: 0, D: 0 };
  liste.forEach(r => {
    if (!r) return;
    tablolar.add(r.tablo_adi);
    satirlar.add(r.tablo_adi + '|' + _dgKararli(r.satir_pk));
    if (Object.prototype.hasOwnProperty.call(islemler, r.islem)) islemler[r.islem]++;
  });
  return { tablo_sayisi: tablolar.size, satir_sayisi: satirlar.size, islemler };
}

// "3 tablo · 5 satır" özet parçası (başlık çağıranda eklenir)
/**
 * Verilen nesnin tablo ve satır sayılarını alıp bunları metin formatında birleştirerek döndürür.
 * @param {Object} ozet Nesne içinde 'tablo_sayisi' ve 'satir_sayisi' özelliklerini içeren nesne.
 * @returns {String} Tablo ve satır sayılarını içeren formatta bir dize.
 */
function ozetMetni(ozet) {
  const o = ozet || {};
  return (o.tablo_sayisi || 0) + ' tablo · ' + (o.satir_sayisi || 0) + ' satır';
}

// Hücre değerini okunur düz metne çevirir (HTML ÜRETMEZ — çağıran esc() uygular).
//  null/undefined → '—' · bool → Evet/Hayır · 'YYYY-MM-DD' → gg.aa.yyyy ·
//  ISO zaman damgası → gg.aa.yyyy SS:DD (İstanbul) · nesne/dizi → JSON
/**
 * Farklı tipteki bir değeri kullanıcıya gösterilecek metne dönüştürür; null/undefined için '—', boolean için 'Evet'/'Hayır', nesneler için JSON, tarih ve tarih-saat dizgilerini Türkçe biçime çevirir.
 * @param {*} v - Metne dönüştürülecek değer.
 * @returns {string} Değerin görüntülenmeye uygun hâli: null/undefined için '—', boolean için 'Evet'/'Hayır', sayı için dizgi karşılığı, nesne için JSON dizgisi, 'YYYY-AA-GG' biçimli dizgiler için 'GG.AA.YYYY', saat dilimi bilgili tarih-saatler için tr-TR yerel ayarına göre (Europe/Istanbul) biçimlendirilmiş dizgi, saat dilimi bilgisiz tarih-saatler için 'GG.AA.YYYY SS:DD', boş dizgi için '""', diğer dizgiler için kendisi.
 */
function degerMetni(v) {
  if (v === null || v === undefined) return '—';
  if (typeof v === 'boolean') return v ? 'Evet' : 'Hayır';
  if (typeof v === 'number') return String(v);
  if (typeof v === 'object') return JSON.stringify(v);
  const s = String(v);
  let m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (m) return m[3] + '.' + m[2] + '.' + m[1];
  m = /^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})/.exec(s);
  if (m) {
    const d = new Date(s);
    if (!isNaN(d.getTime()) && /(Z|[+-]\d{2}(:?\d{2})?)$/.test(s)) {
      return d.toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul', day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }).replace(',', '');
    }
    return m[3] + '.' + m[2] + '.' + m[1] + ' ' + m[4] + ':' + m[5];
  }
  return s === '' ? '""' : s;
}

// ── Gürültü ayracı (L4-W2, plan §5) — SAF ─────────────────────────────
// Uygulama-dışı kaynak (app_name ≠ 'egesut-web') tx kartları ve teknikal
// satırlar varsayılan GİZLİ; çip sayacı gizlilerden, liste görünenlerden kurulur.
/**
 * Verilen nesnenin app_name özelliği var olup olmadığını ve 'egesut-web' değeri olup olmadığını kontrol ederek sonucu döndürür.
 * @param {Object} kaynak Kontrol edilecek nesne.
 * @returns {Boolean} Nesne geçerliyse ve app_name 'egesut-web' değilse true, aksi halde false.
 */
function dgUygulamaDisiMi(kaynak) {
  return !!(kaynak && typeof kaynak === 'object' && kaynak.app_name && kaynak.app_name !== 'egesut-web');
}
/**
 * Verilen satır nesnesinin 'teknikal_mi' özelliğinin true olup olmadığını kontrol eder.
 * @param {Object} satir Kontrol edilecek nesne.
 * @returns {boolean} Nesne var ise ve 'teknikal_mi' özelliği true ise true, aksi halde false döndürür.
 */
function dgTeknikMi(satir) {
  return !!(satir && satir.teknikal_mi);
}
// dgGurultuAyir(liste, gizliTest) → {gorunen, gizli, gizliSayi}
// Çağıran gizliTest'i dgUygulamaDisiMi/dgTeknikMi'den türetir; sayaç FİLTRE
// ÖNCESİ tam listeden sayılır (çip sayacı değişmez).
/**
 * Verilen listedeki öğeleri gizli test fonksiyonuna göre görünür ve gizli olarak ayırır.
 * @param {*} liste - Ayrılacak öğe dizisi; dizi değilse boş dizi olarak ele alınır.
 * @param {Function} gizliTest - Öğenin gizli olup olmadığını belirleyen fonksiyon; fonksiyon değilse hiçbir öğe gizli sayılmaz.
 * @returns {{gorunen: Array, gizli: Array, gizliSayi: number}} Görünen öğeler, gizli öğeler ve gizli öğe sayısını içeren nesne.
 */
function dgGurultuAyir(liste, gizliTest) {
  const arr = Array.isArray(liste) ? liste : [];
  const test = typeof gizliTest === 'function' ? gizliTest : () => false;
  const gizli = arr.filter(test);
  return { gorunen: arr.filter(x => !test(x)), gizli, gizliSayi: gizli.length };
}
// Boş değer satırı gizleme (plan §5 "boş değer → satır gizli"): diff satırının
// iki tarafı da null/'' ise satır bilgi taşımaz.
/**
 * d nesnesinin hem eski hem yeni değerinin boş olup olmadığını kontrol eder.
 * @param {Object} d - eski ve yeni özelliklerini içeren nesne.
 * @returns {boolean} Nesne geçersizse veya eski ve yeni değerlerinin ikisi de null/undefined ya da boş dize ise true, aksi halde false.
 */
function dgAlanBosMu(d) {
  if (!d || typeof d !== 'object') return true;
  /**
   * Verilen değerin null, undefined veya boş string olup olmadığını kontrol eder.
   * @param {*} v Kontrol edilecek değer.
   * @returns {boolean} Değer boş ise true, değilse false döndürür.
   */
  const bos = v => v == null || v === '';
  return bos(d.eski) && bos(d.yeni);
}

// satir_pk (jsonb) → kısa gösterim: {"id":"a1b2…"} → "a1b2c3d4"
/**
 * Birincil anahtarı (pk) kısaltılmış biçimde gösterilecek metne dönüştürür.
 * Boş değerler için '—', tek alanlı anahtarlar için sadece o değerin ilk 8 karakteri,
 * birden fazla alanlı anahtarlar için her alanın ilk 8 karakterinin '/' ile birleştirilmiş halini döndürür.
 * @param {*} pk - Kısaltılacak birincil anahtar; null, ilkel değer veya dizi olmayan bir nesne olabilir.
 * @returns {string} Kısaltılmış anahtar metni.
 */
function pkKisa(pk) {
  if (pk === null || pk === undefined) return '—';
  if (typeof pk !== 'object') return String(pk).slice(0, 8);
  const vals = Object.values(pk);
  if (vals.length === 1) return String(vals[0]).slice(0, 8);
  return vals.map(v => String(v).slice(0, 8)).join('/');
}
