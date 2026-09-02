// js/utils/helpers.js
// Genel yardımcı fonksiyonlar (app.js'den taşındı)

function g(id)   { return document.getElementById(id); }
function v(id)   { return g(id)?.value || ''; }
function cl(id)  { const el = g(id); if (el) el.value = ''; }

// Yerel Y-M-D biçimlendirici. toISOString() UTC'dir — yerel 00:00-02:59 arasında
// bir gün ÖNCEKİ tarihi basar (B4: gece doğumları yanlış güne kaydırıyordu).
// "Bugün" gereken HER yerde bugun() kullan; toISOString().split('T') ile bugün üretme.
function _ymd(d) {
  const y = d.getFullYear(), m = String(d.getMonth() + 1).padStart(2, '0'), g = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${g}`;
}
function bugun() { return _ymd(new Date()); }
function dAgo(n) { const d = new Date(); d.setDate(d.getDate() - n); return _ymd(d); }
function dFwd(base, n) { const d = base ? new Date(base + 'T00:00:00') : new Date(); d.setDate(d.getDate() + n); return _ymd(d); }
function fmtTarih(iso) { if (!iso) return '—'; const p = iso.slice(0, 10).split('-'); return p.length === 3 ? `${p[2]}.${p[1]}.${p[0]}` : iso; }
function fmtTarihSaat(iso) { if (!iso) return '—'; try { const d = new Date(iso); return d.toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul', day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }); } catch(e) { return fmtTarih(iso); } }
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

function _toastHide() {
  const el = g('toast');
  if (el) { clearTimeout(el._tid); el._tid = 0; el.className = ''; }
}

// Kuyruğun başını göster; süre dolunca gizle, gap bekle, sıradakine geç
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

function showDebug(msg) { console.warn('[debug]', msg); }

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
function escAttr(str) {
  return String(str ?? '').replace(/&/g,'&amp;').replace(/"/g,'&quot;').replace(/'/g,'&#39;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
}
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

function debounce(fn, delay = 300) {
  let timer;
  return (...args) => { clearTimeout(timer); timer = setTimeout(() => fn(...args), delay); };
}

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
  const disp = h => String(h.kupe_no || h.devlet_kupe || h.id || '');
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

function vurguHtml(metin, q) {
  const esc = t => t.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const s = String(metin ?? '');
  const ql = trLower(String(q ?? '')).trim();
  if (!s || !ql) return esc(s);
  const i = trLower(s).indexOf(ql);
  if (i < 0) return esc(s);
  return esc(s.slice(0, i)) + '<span class="ac-vurgu">' + esc(s.slice(i, i + ql.length)) + '</span>' + esc(s.slice(i + ql.length));
}

// Test için dual-mode export (tarayıcıda module undefined, etkisiz)
if (typeof module !== 'undefined' && module.exports) {
  module.exports = Object.assign(module.exports || {}, { trLower, _ymd, bugun, dAgo, dFwd, fmtTarih, fmtTarihSaat, getDisplayKupe, srchAdaySirala, vurguHtml });
}
