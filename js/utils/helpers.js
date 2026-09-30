// js/utils/helpers.js
// Genel yardımcı fonksiyonlar (app.js'den taşındı)

/**
 * Belirtilen ID'ye sahip DOM elementini bulup döndürür.
 * @param {string} id Bulunacak elementin ID'si.
 * @returns {HTMLElement|null} Bulunan element veya bulunamazsa null.
 */
function g(id)   { return document.getElementById(id); }
/**
 * Verilen ID'ye sahip öğenin 'value' özelliğini döndürür, yoksa boş string döndürür.
 * @param {string} id Sorgulanacak öğenin ID'si.
 * @returns {string} İstenen öğenin 'value' değeri veya yoksa boş string.
 */
function v(id)   { return g(id)?.value || ''; }
/**
 * Belirtilen ID'ye sahip elemanın değerini temizler (boş string yapar).
 * @param {string} id Temizlenmesi istenen elemanın ID'si.
 * @returns {void} Hiçbir değer döndürmez.
 */
function cl(id)  { const el = g(id); if (el) el.value = ''; }

// Yerel Y-M-D biçimlendirici. toISOString() UTC'dir — yerel 00:00-02:59 arasında
// bir gün ÖNCEKİ tarihi basar (B4: gece doğumları yanlış güne kaydırıyordu).
// "Bugün" gereken HER yerde bugun() kullan; toISOString().split('T') ile bugün üretme.
/**
 * Verilen tarih nesnesini 'YYYY-MM-DD' formatında bir string olarak döndürür.
 * @param {Date} d Tarih nesnesi.
 * @returns {string} Tarih formatı (YYYY-MM-DD).
 */
function _ymd(d) {
  const y = d.getFullYear(), m = String(d.getMonth() + 1).padStart(2, '0'), g = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${g}`;
}
/**
 * Bugünün tarihini YIL-AY-GÜN biçiminde bir dize olarak döndürür.
 * @returns {string} Bugünün tarihi _ymd formatında.
 */
function bugun() { return _ymd(new Date()); }
/**
 * Verilen gün sayısını geriye alarak tarihi hesaplar ve Yıl-Ay-Gün formatında döndürür.
 * @param {number} n Geriye alınacak gün sayısı.
 * @returns {string} Hesaplanan tarih için Yıl-Ay-Gün formatındaki string.
 */
function dAgo(n) { const d = new Date(); d.setDate(d.getDate() - n); return _ymd(d); }
/**
 * Verilen tarihi n gün ileri kaydırıp YYYY-AA-GG biçiminde döndürür; base verilmezse bugünü kullanır.
 * @param {string} base - 'YYYY-AA-GG' biçiminde temel tarih; boş/falsy ise bugünün tarihi kullanılır.
 * @param {number} n - Eklenecek gün sayısı.
 * @returns {string} Kaydırılmış tarihin YYYY-AA-GG biçimindeki karşılığı.
 */
function dFwd(base, n) { const d = base ? new Date(base + 'T00:00:00') : new Date(); d.setDate(d.getDate() + n); return _ymd(d); }
/**
 * ISO tarih dizgisini "GG.AA.YYYY" biçimine dönüştürür; boş girişte '—', geçersiz biçimde girişi olduğu gibi döndürür.
 * @param {string} iso - "YYYY-MM-DD" biçiminde ISO tarih dizgisi.
 * @returns {string} Dönüştürülmüş tarih dizgisi, '—' ya da olduğu gibi giriş.
 */
function fmtTarih(iso) { if (!iso) return '—'; const p = iso.slice(0, 10).split('-'); return p.length === 3 ? `${p[2]}.${p[1]}.${p[0]}` : iso; }
/**
 * Geçersiz tarih saatini '—' olarak, geçerli olanı İstanbul saati ile formatlayarak döndürür.
 * @param {string} iso ISO 8601 formatında bir tarih saat stringi.
 * @returns {string} Formatlanmış tarih saat stringi veya hata durumunda alt fonksiyonun sonucu.
 */
function fmtTarihSaat(iso) { if (!iso) return '—'; try { const d = new Date(iso); return d.toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul', day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }); } catch(e) { return fmtTarih(iso); } }
/**
 * Geçerli bir nesne (h) yoksa fallback değerini, yoksa fallback yoksa '—'yi döndürür.
 * Geçerli bir nesne varsa, nesnenin 'kupe_no', 'devlet_kupe' veya 'id' özelliklerinden ilk bulunanı döndürür.
 * @param {Object} h Nesne parametresi.
 * @param {*} fallback Varsayılan döndürülecek değer.
 * @returns {string} Kupa numarası, devlet kupa numarası, ID veya fallback değeri.
 */
function getDisplayKupe(h, fallback) { if (!h) return fallback || '—'; return h.kupe_no || h.devlet_kupe || h.id || fallback || '—'; }

// ── TOAST KUYRUĞU (ReFactorRoadmap Aşama 3.4) ────────────────────────
// SÖZLEŞME (testle kilitli: tests/unit/toast.test.js):
// 1. toast(msg, err) imzası DEĞİŞMEZ; renkler mevcut 'err' bayrağıyla aynı
//    ('on' / 'on err', gizliyken '').
// 2. Aynı anda TEK bildirim görünür. Yeni çağrı görünür mesajı EZMEZ —
//    FIFO kuyruğa girer; sırası gelince gösterilir (ardışık işlemlerin her
//    birinden kullanıcı haberdar olur, son mesaj öncekileri gölgelemez).
// 3. Her mesaj TOAST_MS görünür; sonraki mesaja geçmeden önce #toast'un
//    .28s CSS fade-out'ı tamamlansın diye TOAST_GAP_MS boşluk bırakılır.
// 4. Kuyruk tavanı TOAST_MAX_QUEUE bekleyendir; taşmada EN ESKİ bekleyen
//    düşürülür (toast fırtınasında kuyruk sonsuz uzayıp dakikalarca süren
//    bildirim şeridine dönüşmez; en yeni mesaj, kullanıcının az önceki
//    eylemi hakkında olduğu için önceliklidir).
// 5. Birebir aynı (msg, err) görünür mesajla YA DA kuyruğun sonundakiyle
//    aynıysa yutulır — aynı hata üst üste 5 kez kuyruğu doldurup farklı
//    mesajları dışarıda bırakmaz. (Aynı mesajın araya başka mesaj girmeden
//    tekrarı zaten bilgi taşımaz.)
// 6. #toast elementi yoksa eski davranış korunur: sessiz no-op, kuyruk da
//    birikmez.
const TOAST_MS = 3200;
const TOAST_GAP_MS = 300;   // index.html #toast transition:all .28s
const TOAST_MAX_QUEUE = 3;

const _toastQ = [];         // bekleyen {msg, err}
let _toastCur = null;       // görünür/gösterilmiş son mesaj (dedupe karşılaştırması için)
let _toastBusy = false;     // gösterim döngüsü (gösterim+gap) çalışıyor mu

/**
 * Toast elementini gizlemek için zamanlayıcıyı temizler ve sınıfı sıfırlar.
 * @returns {void}
 */
function _toastHide() {
  const el = g('toast');
  if (el) { clearTimeout(el._tid); el._tid = 0; el.className = ''; }
}

// Kuyruğun başını göster; süre dolunca gizle, gap bekle, sıradakine geç
/**
 * Toast kuyruğundan bir sonraki bildirimi alıp gösterir, ardından belirlenen süre sonra kuyruğa döner.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function _toastPump() {
  const el = g('toast');
  const next = _toastQ.shift();
  if (!el || !next) {                       // kuyruk bitti ya da element gitti: dur
    _toastCur = null; _toastBusy = false; _toastHide();
    return;
  }
  _toastCur = next;
  el.textContent = next.msg;
  el.className = 'on' + (next.err ? ' err' : '');
  clearTimeout(el._tid);
  el._tid = setTimeout(() => {
    _toastHide();
    el._tid = setTimeout(_toastPump, TOAST_GAP_MS);
  }, TOAST_MS);
}

/**
 * Bir toast mesajını gösterilmek üzere kuyruğa ekler; aynı mesaj ve hata durumuyla tekrarlanan çağrıları yoksayar ve kuyruk doluysa en eski bekleyen mesajı düşürür.
 * @param {string} msg - Gösterilecek toast mesajı.
 * @param {boolean} [err=false] - Mesajın hata toast'u olarak gösterilip gösterilmeyeceği.
 * @returns {void} Değer döndürmez.
 */
function toast(msg, err = false) {
  const el = g('toast'); if (!el) return;
  err = !!err;
  // dedupe (sözleşme madde 5): görünür mesaj ya da kuyruk tail'i ile birebir aynı
  const tail = _toastQ.length ? _toastQ[_toastQ.length - 1] : _toastCur;
  if (tail && tail.msg === msg && tail.err === err) return;
  if (!_toastBusy) { _toastBusy = true; _toastQ.push({ msg, err }); _toastPump(); return; }
  _toastQ.push({ msg, err });
  if (_toastQ.length > TOAST_MAX_QUEUE) _toastQ.shift();   // en eski bekleyeni düşür (madde 4)
}

/**
 * Mesajı alıp '[debug]' etiketiyle birlikte konsola uyarı olarak yazdırır.
 * @param {string} msg - Konsola yazdırılacak mesaj.
 * @returns {void} Fonksiyon bir değer döndürmez.
 */
function showDebug(msg) { console.warn('[debug]', msg); }

/**
 * Verilen metni HTML özel karakterlerinden arındırarak güvenli bir şekilde döndürür.
 * @param {string} str Dönüştürülecek metin.
 * @returns {string} HTML özel karakterlerinden temizlenmiş metin.
 */
function esc(str) {
  const div = document.createElement('div');
  div.textContent = str || '';
  return div.innerHTML;
}
// Yalnız HTML attribute bağlamı için escape (data-x="…" title="…" value="…" vb.).
// esc() tırnak kaçırmaz; ama escAttr DA onclick="fn('${escAttr(v)}')" kalıbında ÇALIŞMAZ:
// HTML parser attribute değerini entity-decode edip JS motoruna verir, &#39; → ' string'i kırar
// (ampirik kanıt: 2026-09-02 kod-temizlik raporu §0). Metin değerli onclick argümanları için
// data-x="${escAttr(v)}" + this.dataset.x deseni kullan (AGENTS.md modal-router kuralı).
/**
 * Verilen değeri HTML özniteliği içinde güvenle kullanılabilecek şekilde kaçış karakterlerine dönüştürür.
 * @param {*} str - Kaçış karakterlerine dönüştürülecek değer; null/undefined ise boş dize olarak ele alınır.
 * @returns {string} &, ", ', < ve > karakterleri HTML karşılıklarıyla değiştirilmiş dize.
 */
function escAttr(str) {
  return String(str ?? '').replace(/&/g,'&amp;').replace(/"/g,'&quot;').replace(/'/g,'&#39;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}
/**
 * Verilen metni Türkçe karakter dönüşümleri (İ->i, I->ı) uygulayarak tamamen küçük harfe çevirir.
 * @param {string} s Dönüştürülecek metin.
 * @returns {string} Küçük harflere çevrilen metin.
 */
function trLower(s) { return s.replace(/İ/g, 'i').replace(/I/g, 'ı').toLowerCase(); }

/**
 * Genel autocomplete
 * @param {string} inputId
 * @param {object} opts - { source: string[] | async (q) => string[], onSelect: (val) => void }
 */
function setupAutocomplete(inputId, opts) {
  const input = g(inputId);
  if (!input) return;

  let list = [], idx = -1;
  const wrap = document.createElement('div');
  wrap.className = 'ac-wrapper';
  input.parentNode.insertBefore(wrap, input.nextSibling);
  const ul = document.createElement('ul');
  ul.className = 'ac-list';
  wrap.appendChild(ul);

  async function load(q) {
    if (typeof opts.source === 'function') list = await opts.source(q);
    else { const lq = trLower(q); list = opts.source.filter(s => trLower(s).includes(lq)); }
  }

  /**
   * Öneri listesini yeniden oluşturur; listenin ilk 10 ögesini <li> olarak ekler, tıklamada ögeyi seçer ve liste boşsa gizler.
   * @returns {void}
   */
  function render() {
    ul.innerHTML = ''; idx = -1;
    list.slice(0, 10).forEach((item, i) => {
      const li = document.createElement('li');
      li.textContent = item;
      li.addEventListener('mousedown', e => { e.preventDefault(); select(i); });
      ul.appendChild(li);
    });
    ul.style.display = list.length ? 'block' : 'none';
  }

  /**
   * Seçilen dizin değerini input'a atar, liste gizler ve varsa onSelect callback'ini tetikler.
   * @param {number} i Seçilecek dizin indeksi.
   * @returns {void} Fonksiyon bir değer döndürmez.
   */
  function select(i) {
    input.value = list[i];
    ul.style.display = 'none';
    if (opts.onSelect) opts.onSelect(list[i]);
  }

  input.addEventListener('input', async () => {
    const q = input.value.trim();
    if (!q) { ul.style.display = 'none'; return; }
    await load(q); render();
  });

  input.addEventListener('keydown', e => {
    const items = ul.querySelectorAll('li');
    if (e.key === 'ArrowDown') { e.preventDefault(); if (idx < items.length - 1) idx++; }
    else if (e.key === 'ArrowUp') { e.preventDefault(); if (idx > 0) idx--; }
    else if (e.key === 'Enter' && idx >= 0) { e.preventDefault(); select(idx); return; }

    else if (e.key === 'Escape') { ul.style.display = 'none'; return; }
    items.forEach((li, i) => li.classList.toggle('active', i === idx));
  });

  document.addEventListener('click', e => {
    if (!wrap.contains(e.target) && e.target !== input) ul.style.display = 'none';
  });
}

/**
 * Verilen fonksiyonu belirli bir gecikme süresinden sonra çağırarak,
 * aynı fonksiyon tekrar çağrıldığında önceki zamanlayıcıyı iptal eder.
 * @param {Function} fn - Gecikmeli olarak çalıştırılacak fonksiyon.
 * @param {number} delay - Fonksiyonun çalıştırılacağı gecikme süresi (milisaniye cinsinden).
 * @returns {Function} Gecikmeli çağrıyı sağlayan yeni bir fonksiyon.
 */
function debounce(fn, delay = 300) {
  let timer;
  return (...args) => { clearTimeout(timer); timer = setTimeout(() => fn(...args), delay); };
}

/**
 * Verilen fonksiyonu belirli bir zaman aralığı (limit) içinde sadece bir kez çalıştırarak çağrı sıklığını kısıtlar.
 * @param {Function} fn Çalıştırılacak ana fonksiyon.
 * @param {number} limit İki çağrı arasındaki minimum zaman aralığı (milisaniye cinsinden). Varsayılan değer 1000'dir.
 * @returns {Function} Sınırlama mekanizmasını uygulayan yeni bir fonksiyon.
 */
function throttle(fn, limit = 1000) {
  let last = 0;
  return (...args) => { const now = Date.now(); if (now - last >= limit) { last = now; fn(...args); } };
}

// ── KÜPE ARAMA — ALAKA SIRALAMASI + EŞLEŞME VURGUSU (srchDropdown + acHayvan) ──
// SÖZLEŞME (testle kilitli: tests/unit/srch-siralama.test.js):
// 1. srchAdaySirala katmanları (küçük tier daha alakalı):
//    0 kupe_no birebir · 1 devlet_kupe birebir · 2 kupe_no önek ·
//    3 devlet_kupe önek · 4 kupe_no içerir · 5 devlet_kupe içerir · 6 ırk içerir.
//    "01" yazınca 01'in birebir eşleşmesi, TR…'nin ortasındaki "01"den önce gelir.
// 2. Aynı katmanda kısa gösterim önce (daha spesifik), sonra 'tr' localeCompare
//    ({numeric:true} — "02" < "10" doğal sayı sırası); deterministik, dizi sırasına bağımlı değil.
// 3. q boşsa [] döner; en fazla limit (varsayılan 8) aday döner.
// 4. vurguHtml esc() semantiğiyle (& < >) kaçırır, İLK eşleşmeyi
//    <span class="ac-vurgu"> ile sarar; eşleşme yoksa düz kaçırılmış metin.
//    Büyüklük duyarsızlığı trLower ile (İ/i, I/ı).
function srchAdaySirala(hayvanlar, q, limit = 8) {
  const ql = trLower(String(q ?? '')).trim();
  if (!ql) return [];
  /**
   * Verilen nesnenin 'kupe_no', 'devlet_kupe' veya 'id' alanlarından ilk bulunanı alıp string olarak döndürür.
   * @param {Object} h Nesne.
   * @returns {string} Nesnenin kimlik alanlarından biri veya boş string.
   */
  const disp = h => String(h.kupe_no || h.devlet_kupe || h.id || '');
  /**
   * Verilen nesne alanlarının (kupe_no, devlet_kupe, irk) 'ql' değeriyle eşleşip eşleşmediğini kontrol ederek öncelik sırasına göre bir kod döndürür.
   * @param {Object} h Nesne; kupe_no, devlet_kupe ve irk alanlarını içermelidir.
   * @returns {number} Eşleşme durumu: 0 (kupe_no tam eşleşme), 1 (devlet_kupe tam eşleşme), 2 (kupe_no başlangıç eşleşmesi), 3 (devlet_kupe başlangıç eşleşmesi), 4 (kupe_no içerir), 5 (devlet_kupe içerir), 6 (irk içerir), -1 (hiçbiri).
   */
  const gec = h => {
    const k = trLower(h.kupe_no || ''), d = trLower(h.devlet_kupe || ''), i = trLower(h.irk || '');
    if (k === ql) return 0;
    if (d === ql) return 1;
    if (k.startsWith(ql)) return 2;
    if (d.startsWith(ql)) return 3;
    if (k.includes(ql)) return 4;
    if (d.includes(ql)) return 5;
    if (i.includes(ql)) return 6;
    return -1;
  };
  return hayvanlar
    .map(h => ({ h, tier: gec(h) }))
    .filter(x => x.tier >= 0)
    .sort((x, y) => x.tier - y.tier
      || disp(x.h).length - disp(y.h).length
      || disp(x.h).localeCompare(disp(y.h), 'tr', { numeric: true }))
    .slice(0, limit);
}

/**
 * Metin içindeki belirli bir kelimeyi veya ifadeyi vurgulamak için HTML etiketi ekler.
 * @param {string} metin Vurgulanacak ana metin.
 * @param {string} q Vurgulanacak kelime veya ifade.
 * @returns {string} Vurgulanmış metnin HTML kodu.
 */
function vurguHtml(metin, q) {
  /**
   * Verilen metindeki özel karakterleri HTML entity kodlarına dönüştürerek XSS saldırılarına karşı güvenli hale getirir.
   * @param {string} t HTML entity kodlaması yapılması gereken metin.
   * @returns {string} Özel karakterleri entity kodlarıyla değiştirilmiş metin.
   */
  const esc = t => t.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const s = String(metin ?? '');
  const ql = trLower(String(q ?? '')).trim();
  if (!s || !ql) return esc(s);
  const i = trLower(s).indexOf(ql);
  if (i < 0) return esc(s);
  return esc(s.slice(0, i)) + '<span class="ac-vurgu">' + esc(s.slice(i, i + ql.length)) + '</span>' + esc(s.slice(i + ql.length));
}

// ── SÜRDEN ÇIKAN HAYVAN FİLTRESİ (dashboard bantları + görev listesi güvenlik ağı) ──
// SÖZLEŞME (testle kilitli: tests/unit/cikis-filtre.test.js):
// 1. rows içinden idKey kolonu aktifIdler kümesinde OLMAYAN satırları düşürür
//    (durumu 'Aktif' olmayan: Satıldı/Ölü/Kesildi + cop_kutusu'dan silinenler —
//    ikisi de aktif kümesinde yer almaz).
// 2. idKey'siz satırlar (genel görev vb.) filtrelenmeden kalır.
// 3. aktifIdler Set YA DA dizi kabul eder; null/undefined ise hiçbir satır
//    düşürülmez (hayvan verisi yüklenememişse liste boşaltılmaz).
// 4. Saf: girişleri değiştirmez, yeni dizi döner.
/**
 * Verilen satırlardan belirtilen kimliklere sahip aktif kayıtları filtreleyerek döndürür.
 * @param {Array} rows Filtrelenmesi gereken satırlar dizisi.
 * @param {string} idKey Satırlarda kimlik bilgisinin bulunduğu alan adı.
 * @param {Set|Array|null} aktifIdler Aktif olarak kabul edilecek kimliklerin bulunduğu Set veya dizi (null ise tüm satırlar döndürülür).
 * @returns {Array} Aktif kimliklere sahip satırlardan oluşan dizi.
 */
function aktifHayvanSatirlari(rows, idKey, aktifIdler) {
  if (!Array.isArray(rows)) return [];
  if (aktifIdler == null) return rows.slice();
  const set = aktifIdler instanceof Set ? aktifIdler : new Set(aktifIdler);
  return rows.filter(r => !r || !r[idKey] || set.has(r[idKey]));
}

// ── SÜTTEN KESME — BUZAĞI SETİ + KESİM VAKTİ (dashboard kartı ↔ m-sutten-kes) ──
// SÖZLEŞME (testle kilitli: tests/unit/sutten-kes-secim.test.js):
// 1. sutIcenBuzagiSec SAF'tır — animals'ı parametre alır, state'e dokunmaz.
//    Kanonik tanım (forms.js _sutIcenBuzagilar'ın birebir aynası): aktif +
//    kesilmemiş + (grup 'Buzağı' içerir VEYA yaş ≤ 180g). forms.js bu saf
//    katmanı getState('animals') ile çağırır — tek kaynak burası.
// 2. Gün yaşı Math.floor((now - dogum_tarihi)/86400000) (forms.js'teki birebir hesap).
// 3. suttenKesimeHazirSec: set içinden yaş ≥ eşik olanlar = "kesim vakti gelenler".
//    Dashboard kartının sayacı BU sayıdır; modal listesinde 'Kesim vakti' rozetli
//    satırlar bu kümedir — sayaç ↔ rozet sayısı birebir tutarlı.
// 4. suttenKesListeSirala: kesim vakti gelenler önce; grup içi mevcut sıra korunur.
/**
 * Verilen kaydın doğum tarihine göre yaşını gün cinsinden hesaplar; doğum tarihi yoksa null döndürür.
 * @param {Object} a - dogum_tarihi özelliğini içeren kayıt nesnesi.
 * @returns {number|null} Doğum tarihi bugüne kadar geçen gün sayısı; doğum tarihi yoksa null.
 */
function _sutGunYasi(a) {
  return a && a.dogum_tarihi ? Math.floor((Date.now() - new Date(a.dogum_tarihi)) / 86400000) : null;
}
function sutIcenBuzagiSec(animals) {
  return (animals || []).filter(a => {
    if (!a || a.durum !== 'Aktif' || a.suttten_kesme_tarihi) return false;
    const yas = _sutGunYasi(a);
    return (a.grup && a.grup.includes('Buzağı')) || (yas !== null && yas <= 180);
  });
}
/**
 * Süt içen buzağıları seçip yaşları belirtilen eşiğe (varsayılan 60) eşit veya üzerinde olanları döndürür.
 * @param {Array} animals - Filtrelenecek hayvan kayıtlarının bulunduğu dizi.
 * @param {number} [esik=60] - Kesime hazır saymak için gereken minimum yaş (gün).
 * @returns {Array} Yaşı eşiğe eşit veya eşikten büyük olan süt içen buzağılardan oluşan dizi.
 */
function suttenKesimeHazirSec(animals, esik = 60) {
  return sutIcenBuzagiSec(animals).filter(a => {
    const yas = _sutGunYasi(a);
    return yas !== null && yas >= esik;
  });
}
function suttenKesListeSirala(animals, esik = 60) {
  return sutIcenBuzagiSec(animals)
    .map((a, i) => ({ a, i, h: (() => { const y = _sutGunYasi(a); return y !== null && y >= esik ? 0 : 1; })() }))
    .sort((x, y) => x.h - y.h || x.i - y.i)
    .map(x => x.a);
}

// ── DOZAJ HELPERI (spec: .claude/plans/2026-09-09-tedavi-doz-gorev-design.md §3.2) ──
// Saf hesap motoru: DOM'a dokunmaz. kart = _drugsCache item'ı
// (std_dose / std_dose_unit / concentration alanları loadDrugsCache'ten gelir).
// Birim tipleri: 'ml/kg' (ağırlık × oran) | 'mg/kg' (÷ concentration → ml) |
// 'ml/hayvan' (sabit — ağırlık gerekmez). RPC sözleşmesi değişmez: yalnız form
// ön-dolumu. Kullanıcı kuralı: doz kutusuna asla otomatik yazılmaz; buton
// tıklamasıyla doldurulur (dozOneriUygula, ui.js).
/**
 * Sayının nokta ondalık ayracını virgüle çevirerek metin olarak döndürür.
 * @param {*} n - Ondalık ayracı dönüştürülecek sayı.
 * @returns {string} Ondalık ayracı virgülle değiştirilmiş metin.
 */
function _trNum(n) { return String(n).replace('.', ','); }

/**
 * Standart doz kartı verisi ve hayvan ağırlığına göre doz hesaplaması yapar.
 * @param {number} canliAgirlik Hayvanın canlı ağırlığı (kg).
 * @param {Object} kart Doz hesaplama için gerekli olan standart doz bilgilerini içeren kart nesnesi.
 * @param {string} seviye Doz seviyesi ('min', 'max' veya 'tip').
 * @returns {Object} Hesaplama sonucu içeren {ok, doz, birim, aciklama, neden} alanlarına sahip nesne.
 */
function dozOner(canliAgirlik, kart, seviye) {
  if (!kart) return { ok: false, neden: 'Kartta standart doz yok' };
  seviye = seviye || 'tip';
  const oranKaynak = seviye === 'min' ? +kart.std_dose_min
    : seviye === 'max' ? +kart.std_dose_max
    : +kart.std_dose;
  if (!(oranKaynak > 0)) {
    return { ok: false, neden: seviye === 'tip' ? 'Kartta standart doz yok'
      : 'Kartta ' + (seviye === 'min' ? 'minimum' : 'maksimum') + ' doz girilmemiş' };
  }
  const unit = kart.std_dose_unit || 'ml/kg';
  const birim = kart.default_unit || kart.birim || 'ml';
  /**
   * Verilen sayıyı ondalık basamaklı olarak yuvarlar.
   * @param {number} x Yuvarlanacak sayı.
   * @returns {number} Ondalık kısmı 1 basamağa yuvarlanmış sayı.
   */
  const _yuvarla = x => Math.round(x * 10) / 10;
  if (unit === 'ml/hayvan') {
    const doz = _yuvarla(oranKaynak);
    if (!(doz > 0)) return { ok: false, neden: 'Karttaki standart doz geçersiz' };
    return { ok: true, doz, birim, aciklama: 'sabit doz: ' + _trNum(doz) + ' ' + birim };
  }
  const kg = +canliAgirlik;
  if (!kg || kg <= 0) return { ok: false, neden: 'Hayvanın canlı ağırlığı girilmemiş' };
  if (unit === 'ml/kg') {
    const doz = _yuvarla(kg * oranKaynak);
    if (!(doz > 0)) return { ok: false, neden: 'Hesaplanan doz sıfır' };
    return { ok: true, doz, birim, aciklama: _trNum(kg) + ' kg × ' + _trNum(Math.round(oranKaynak * 1e4) / 1e4) + ' ml/kg = ' + _trNum(doz) + ' ' + birim };
  }
  const conc = +kart.concentration;
  if (!conc || conc <= 0) return { ok: false, neden: 'Kartta konsantrasyon (mg/ml) girilmemiş' };
  const doz = _yuvarla(kg * oranKaynak / conc);
  if (!(doz > 0)) return { ok: false, neden: 'Hesaplanan doz sıfır' };
  return { ok: true, doz, birim: 'ml', aciklama: _trNum(kg) + ' kg × ' + _trNum(Math.round(oranKaynak * 1e4) / 1e4) + ' mg/kg ÷ ' + _trNum(conc) + ' mg/ml = ' + _trNum(doz) + ' ml' };
}

// ── 💡 SHEET ÇİP HESABI (kullanıcı revizyonu 2026-09-09) ──
// Helper sheet'inin "hesaplanmış dozajlar" bölgesi: pratik + pro (konsantrasyon
// varsa birbirine çevrilir) × min/varsayılan/max. Dönen her çip
// {tip:'pratik'|'pro'|'sabit', seviye:'min'|'tip'|'max', doz, birim, aciklama}.
// dozOner'in üzerine saf katman — DOM'a dokunmaz.
/**
 * Verilen canlı ağırlığı ve kart bilgilerine dayanarak doz önerilerini hesaplar.
 * Konsantrasyon, birim ve doz tiplerine göre sabit, pro ve pratik doz aralıklarını belirler.
 * @param {number} canliAgirlik - Canlı ağırlık değeri.
 * @param {Object} kart - Doz hesaplama parametrelerini içeren kart nesnesi.
 * @returns {Array} Hesaplanan doz önerilerini içeren dizi.
 */
function dozCipleri(canliAgirlik, kart) {
  const cikti = [];
  if (!kart) return cikti;
  const unit = kart.std_dose_unit || 'ml/kg';
  const conc = +kart.concentration > 0 ? +kart.concentration : null;
  const birim = kart.default_unit || kart.birim || 'ml';
  /**
   * Verilen etiket için minimum, tip ve maksimum seviyelerine göre doz önerilerini filtreleyip çıktı dizisine ekler.
   * @param {string} tipEtiket Filtreleme yapılacak doz tipinin etiketi.
   * @param {Object} oranlar Min, tip ve max değerlerini içeren nesne.
   * @param {string} birimTip Doz birimi tanımlaması için kullanılan tip ('mg/kg' veya diğer).
   * @returns {void} Filtrelenen ve işlenmiş doz önerilerini içeren çıktı dizisini değiştirir.
   */
  const _tipeGore = (tipEtiket, oranlar, birimTip) => {
    [['min', oranlar.min], ['tip', oranlar.tip], ['max', oranlar.max]].forEach(([seviye, d]) => {
      if (!(+d > 0)) return;
      const r = dozOner(canliAgirlik, birimTip === 'mg/kg'
        ? { std_dose: d, std_dose_unit: 'mg/kg', concentration: conc, default_unit: birim }
        : { std_dose: d, std_dose_unit: birimTip, default_unit: birim });
      if (r.ok) cikti.push({ tip: tipEtiket, seviye, ...r });
    });
  };
  if (unit === 'ml/hayvan') {
    _tipeGore('sabit', { min: kart.std_dose_min, tip: kart.std_dose, max: kart.std_dose_max }, 'ml/hayvan');
    return cikti;
  }
  // kartın kendi tipi
  const kendiTip = unit === 'mg/kg' ? 'pro' : 'pratik';
  _tipeGore(kendiTip, { min: kart.std_dose_min, tip: kart.std_dose, max: kart.std_dose_max }, unit);
  // karşı tip — yalnız konsantrasyon varken (pro ÷ conc = pratik; pratik × conc = pro)
  if (conc) {
    /**
     * Değeri birim türüne ('ml/kg' veya diğer) göre conc ile çarparak ya da bölerek birim dönüşümü yapar; sıfırdan küçük veya eşit değerler için null döndürür.
     * @param {number|string} d - Dönüştürülecek değer.
     * @returns {number|null} Yuvarlanmış dönüştürülmüş değer ya da d pozitif değilse null.
     */
    const _cevir = d => (+d > 0 ? Math.round((unit === 'ml/kg' ? +d * conc : +d / conc) * 1e6) / 1e6 : null);
    const karsiTip = unit === 'mg/kg' ? 'pratik' : 'pro';
    _tipeGore(karsiTip, {
      min: _cevir(kart.std_dose_min), tip: _cevir(kart.std_dose), max: _cevir(kart.std_dose_max),
    }, unit === 'mg/kg' ? 'ml/kg' : 'mg/kg');
  }
  return cikti;
}

// ── KÜPE DOĞAL SIRASI (spec §4.1) ──
// "002" → 2, "19" → 19, "2044" → 2044 (alfabetik sıralama "19" < "2044" < "002"
// yanlış verirdi). Sayısal bloklar değerle, eşitlikte metinle karşılaştırılır;
// sayı blokları metin bloklarından önce. Kirli küpeler ("Test buzağı", "xx")
// sayısal bloklardan SONRA alfabetik — listede sonda.
/**
 * Verilen stringi sayısal olmayan parçalar ve sayısal parçalar (n: sayı, s: string) içeren nesnelerle ayırarak filtreler.
 * @param {string} s İşlenecek string.
 * @returns {Array} Sayısal olmayan parçalar ve {n: number, s: string} nesnelerinden oluşan dizi.
 */
function kuceDogalBlok(s) {
  return String(s ?? '').split(/(\d+)/).map(p => /^\d+$/.test(p) ? { n: +p, s: p } : p).filter(p => p !== '');
}
function kuceDogalKarsilastir(a, b) {
  const A = kuceDogalBlok(a), B = kuceDogalBlok(b);
  for (let i = 0; i < Math.max(A.length, B.length); i++) {
    const x = A[i], y = B[i];
    if (x === undefined) return -1;
    if (y === undefined) return 1;
    const xn = typeof x === 'object', yn = typeof y === 'object';
    if (xn && yn) { if (x.n !== y.n) return x.n - y.n; if (x.s !== y.s) return x.s < y.s ? -1 : 1; }
    else if (!xn && !yn) { if (x !== y) return x < y ? -1 : 1; }
    else return xn ? -1 : 1;
  }
  return 0;
}

// ── GÖREV SAAT ANAHTARI (spec §4.1) ──
// Gruplamanın 1. katmanı: hedef_saat → TEDAVI_GUN açıklama JSON planned_time.
// "08:00:00" (PostgREST time) → "08:00" kırpılır. Saatsiz '' döner (çağıran en
// sona koyar).
/**
 * Görev saati anahtarını belirler; hedef saat varsa onu, Tedavi_Gün görevi ise açıklama JSON'undan planlanan saati döndürür.
 * @param {Object} t Görev nesnesi.
 * @returns {string} Görevin hedef saati veya planlanan saati (saat formatında) veya boş string.
 */
function gorevSaatAnahtari(t) {
  if (!t) return '';
  if (t.hedef_saat) return String(t.hedef_saat).slice(0, 5);
  if (t.gorev_tipi === 'TEDAVI_GUN') {
    try { return JSON.parse(t.aciklama || '{}').planned_time || ''; } catch (e) { return ''; }
  }
  return '';
}

// ── 💡 AKIŞI: AĞIRLIĞI EKSİK HAYVANLAR ──
// dozOneriUygula'nın "soru-sor → kart'a kaydet → kaldığı yerden devam" dalında
// eksik (canli_agirlik ≤ 0 / boş) hayvanları verilen sırayla döndürür — sıra
// korunur ki çoklu seçimde zincir soru deterministik olsun.
/**
 * Verilen hayvan ID'lerinden, canlı ağırlığı 0 veya negatif olanları (yani ağırlığı eksik olanları) döndürür.
 * @param {Array} ids - Kontrol edilecek hayvan ID'lerinin bulunduğu dizi.
 * @param {Array} animals - Canlı ağırlık bilgisi içeren hayvan kayıtlarının bulunduğu dizi.
 * @returns {Array} Canlı ağırlığı 0 veya daha düşük olan hayvanların ID'lerinden oluşan dizi.
 */
function agirlikEksikHayvanlar(ids, animals) {
  const liste = Array.isArray(animals) ? animals : [];
  return (ids || []).filter(id => {
    const a = liste.find(x => x && x.id === id);
    return !(+a?.canli_agirlik > 0);
  });
}

// ── GÜN FARKI ETİKETİ (P9b — kalem 12, spec §10e UI-R1) ──
// SÖZLEŞME (testle kilitli: tests/unit/ovsync-takip.test.js):
// 1. gunFarkiEtiket(tarihISO, bugun?) → 'bugün' | 'dün' | 'N gün önce' | 'N gün sonra'
//    — Europe/Istanbul YEREL takvim günü farkı (UTC değil).
// 2. Fark İKİ takvim günü alanının karşılaştırmasıyla bulunur (Intl gg.aa.yyyy
//    parçaları; UTC-milisaniye bölümü DEĞİL): dün 23:30 ile bugün 00:30 arası
//    gerçek fark 1 saat olsa da takvim günü farkı 1'dir.
// 3. Z/offset'li timestamptz İstanbul saatine çevrilir: UTC 21:30 = İstanbul
//    00:30 ERTESİ gün → etiket ertesi güne göre. fmtTarih'in ilk-10-karakter
//    kesimi timestamptz'de yanlış gün okur (yukarıdaki tuzak) — burada KULLANILMAZ.
// 4. İleri tarih → 'N gün sonra' (1 gün ileri dahi '1 gün sonra'; 'dün' kısaltması
//    yalnız geriye özeldir).
// 5. bugun? verilmezse bugünün İstanbul takvim günü alınır; 'YYYY-MM-DD' (bugun())
//    ya da gg.aa.yyyy kabul edilir. Ayrıştırılamayan girişte '' döner.
// 6. Saf/durumsuz — DOM/window erişimi yok; Node require ile test edilir.
/**
 * İstanbul yerel takvim gününü gün numarasına çevirir (1 Ocak 1970'ten itibaren takvim günü sayısı).
 * @param {string} iso ISO tarih/tarih-saat dizgisi.
 * @returns {number|null} Takvim gün numarası; ayrıştırılamazsa null.
 */
function _istanbulGunNo(iso) {
  if (!iso) return null;
  try {
    const parca = {};
    new Intl.DateTimeFormat('tr-TR', { timeZone: 'Europe/Istanbul', day: '2-digit', month: '2-digit', year: 'numeric' })
      .formatToParts(new Date(iso))
      .forEach(p => { parca[p.type] = p.value; });
    if (!parca.day || !parca.month || !parca.year) return null;
    return Date.UTC(+parca.year, +parca.month - 1, +parca.day) / 86400000;
  } catch (e) { return null; }
}
/**
 * Başvuru tarihini ('YYYY-MM-DD' ya da gg.aa.yyyy) takvim gün numarasına çevirir.
 * @param {string} s Tarih dizgisi.
 * @returns {number|null} Takvim gün numarası; tanınmayan biçimde null.
 */
function _gunNo(s) {
  const str = String(s ?? '');
  const ymd = /^(\d{4})-(\d{2})-(\d{2})/.exec(str);
  if (ymd) return Date.UTC(+ymd[1], +ymd[2] - 1, +ymd[3]) / 86400000;
  const gaa = /^(\d{2})\.(\d{2})\.(\d{4})/.exec(str);
  return gaa ? Date.UTC(+gaa[3], +gaa[2] - 1, +gaa[1]) / 86400000 : null;
}
/**
 * Verilen tarihin bugüne göre İstanbul yerel takvim günü farkını etiketler.
 * @param {string} tarihISO ISO tarih/tarih-saat dizgisi (timestamptz dahil).
 * @param {string} [bugun] Başvuru günü ('YYYY-MM-DD' ya da gg.aa.yyyy); verilmezse bugün.
 * @returns {string} 'bugün' | 'dün' | 'N gün önce' | 'N gün sonra'; geçersiz girişte ''.
 */
function gunFarkiEtiket(tarihISO, bugun) {
  const gun = _istanbulGunNo(tarihISO);
  if (gun === null) return '';
  const ref = bugun == null || bugun === '' ? _istanbulGunNo(new Date().toISOString()) : _gunNo(bugun);
  if (ref === null) return '';
  const fark = gun - ref;
  if (fark === 0) return 'bugün';
  if (fark === -1) return 'dün';
  return fark < 0 ? `${-fark} gün önce` : `${fark} gün sonra`;
}

// Test için dual-mode export (tarayıcıda module undefined, etkisiz)
if (typeof module !== 'undefined' && module.exports) {
  module.exports = Object.assign(module.exports || {}, { trLower, _ymd, bugun, dAgo, dFwd, fmtTarih, fmtTarihSaat, getDisplayKupe, srchAdaySirala, vurguHtml, aktifHayvanSatirlari, sutIcenBuzagiSec, suttenKesimeHazirSec, suttenKesListeSirala, dozOner, dozCipleri, kuceDogalBlok, kuceDogalKarsilastir, gorevSaatAnahtari, agirlikEksikHayvanlar, gunFarkiEtiket });
}
