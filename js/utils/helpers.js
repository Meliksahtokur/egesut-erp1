// js/utils/helpers.js
// Genel yardımcı fonksiyonlar (app.js'den taşındı)

function g(id)   { return document.getElementById(id); }
function v(id)   { return g(id)?.value || ''; }
function cl(id)  { const el = g(id); if (el) el.value = ''; }

function dAgo(n) { const d = new Date(); d.setDate(d.getDate() - n); return d.toISOString().split('T')[0]; }
function dFwd(base, n) { const d = base ? new Date(base) : new Date(); d.setDate(d.getDate() + n); return d.toISOString().split('T')[0]; }
function fmtTarih(iso) { if (!iso) return '—'; const p = iso.slice(0, 10).split('-'); return p.length === 3 ? `${p[2]}.${p[1]}.${p[0]}` : iso; }
function fmtTarihSaat(iso) { if (!iso) return '—'; try { const d = new Date(iso); return d.toLocaleString('tr-TR', { timeZone: 'Europe/Istanbul', day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }); } catch(e) { return fmtTarih(iso); } }
function getDisplayKupe(h, fallback) { if (!h) return fallback || '—'; return h.kupe_no || h.devlet_kupe || h.id || fallback || '—'; }

function toast(msg, err = false) {
  const el = g('toast'); if (!el) return;
  el.textContent = msg;
  el.className = 'on' + (err ? ' err' : '');
  clearTimeout(el._tid);
  el._tid = setTimeout(() => el.className = '', 3200);
}

function showDebug(msg) { console.warn('[debug]', msg); }

function esc(str) {
  const div = document.createElement('div');
  div.textContent = str || '';
  return div.innerHTML;
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
