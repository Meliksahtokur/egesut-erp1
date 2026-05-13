# Aşama 1 Altyapı Tamamlama — Implementation Plan

> **REQUIRED SUB-SKILL:** Use the executing-plans skill to implement this plan task-by-task.
> **Neye dokunma:** config.js'ye dokunma (tamamlandı), Supabase migration'larına dokunma, mevcut iş mantığını değiştirme — sadece taşı/tekilleştir.
> **ÖNCE OKU:** `write()` imzası: `async function write(table, data, method = 'POST', filter = '')` (api.js:205). 19 çağrı var. Bu plan write()'a DOKUNMAZ — o Plan 3'te (Aşama 2).

**Goal:** Aşama 1'in kalan 3 maddesini tamamla: yardımcı fonksiyonları utils/'e taşı, autocomplete'i tekilleştir, global state referanslarını AppState'e geçir.

**Architecture:** `app.js`'teki `g()`, `v()`, `cl()`, `toast()`, `openM()`, `closeM()`, `dAgo()`, `dFwd()`, `fmtTarih()` → `js/utils/helpers.js` ve `js/utils/modal.js` (TEK COMMIT). `acHdeTani` + `acDisease` → tek `setupAutocomplete()`. `ui.js`'teki `_A`/`_S`/`_gebeIds`/`_hastaIds`/`_taskKategori`/`_stokTab` → `getState()`/`setState()`.

**Tech Stack:** Vanilla JS

**⚠️ İNSAN ONAYI GEREKİR:** Task 3 (state migration) — ~24 global referans değişecek. Yanlış referans = hayvan listesi boş gelir.

---

### Task 1: `utils/helpers.js` + `utils/modal.js` Oluştur (TEK COMMIT)

**TDD scenario:** Modifying tested code — run existing tests first

**Files:**
- Create: `js/utils/helpers.js`, `js/utils/modal.js`
- Modify: `js/app.js` (88-158 arası tüm fonksiyonları kaldır)
- Modify: `index.html` (her iki script'i başa ekle)

**Step 1: utils/ dizini oluştur**

```bash
mkdir -p js/utils
```

**Step 2: helpers.js oluştur**

```js
// js/utils/helpers.js
// Genel yardımcı fonksiyonlar

function g(id)   { return document.getElementById(id); }
function v(id)   { return g(id)?.value || ''; }
function cl(id)  { const el = g(id); if (el) el.value = ''; }
function dAgo(n) { const d = new Date(); d.setDate(d.getDate() - n); return d.toISOString().split('T')[0]; }
function dFwd(base, n) { const d = base ? new Date(base) : new Date(); d.setDate(d.getDate() + n); return d.toISOString().split('T')[0]; }
function fmtTarih(iso) { if (!iso) return '—'; const p = iso.slice(0, 10).split('-'); return p.length === 3 ? `${p[2]}.${p[1]}.${p[0]}` : iso; }

function toast(msg, err = false) {
  const t = document.createElement('div');
  t.className = `toast ${err ? 'err' : 'ok'}`;
  t.textContent = msg;
  document.body.appendChild(t);
  setTimeout(() => t.classList.add('show'), 10);
  setTimeout(() => { t.classList.remove('show'); setTimeout(() => t.remove(), 300); }, 3000);
}

function esc(str) {
  const div = document.createElement('div');
  div.textContent = str || '';
  return div.innerHTML;
}
```

**Step 3: modal.js oluştur**

```js
// js/utils/modal.js
// Modal yönetimi

function openM(id) {
  const el = document.getElementById(id);
  if (!el) return;
  el.classList.add('on');
  el.setAttribute('aria-hidden', 'false');
  const handler = (e) => { if (e.key === 'Escape') { closeM(id); document.removeEventListener('keydown', handler); } };
  document.addEventListener('keydown', handler);
  el._esc = handler;
}

function closeM(id) {
  const el = document.getElementById(id);
  if (!el) return;
  el.classList.remove('on');
  el.setAttribute('aria-hidden', 'true');
  if (el._esc) { document.removeEventListener('keydown', el._esc); delete el._esc; }
}

function mClose(e, el) {
  if (e.target === el) el.classList.remove('on');
}
```

**Step 4: index.html'de HER İKİSİNİ en başa ekle**

```html
<!-- MEVCUT SIRA: config → state → api → app → ui → forms -->
<!-- YENİ SIRA (helpers + modal en başta): -->
<script src="js/utils/helpers.js?v=3"></script>
<script src="js/utils/modal.js?v=3"></script>
<script src="js/config.js?v=3"></script>
<script src="js/state.js?v=3"></script>
<script src="js/api.js?v=3"></script>
<script src="js/app.js?v=3"></script>
<script src="js/ui.js?v=3"></script>
<script src="js/forms.js?v=3"></script>
```

**Step 5: app.js'den taşınan tüm fonksiyonları tek seferde sil**

`app.js` satır 88-158 arasındaki `g()`, `v()`, `cl()`, `dAgo()`, `dFwd()`, `fmtTarih()`, `toast()`, `openM()`, `closeM()`, `mClose()` tanımlarını kaldır.

**Step 6: TEK COMMIT**

```bash
git add js/utils/ js/app.js index.html
git commit -m "refactor: helpers.js + modal.js olusturuldu, app.js temizlendi"
```

Neden tek commit: helpers.js ve modal.js aynı anda index.html'de yüklü olmalı, yoksa `openM` undefined kalarak sonraki script'leri kırar.

---

### Task 2: `setupAutocomplete()` Tekilleştirme

**TDD scenario:** New feature — full TDD cycle

**Files:**
- Modify: `js/utils/helpers.js` (setupAutocomplete ekle)
- Modify: `js/app.js` (acHdeTani satır 631, acDisease satır 676 → kaldır, setupAutocomplete çağrılarıyla değiştir)

**Step 1: helpers.js'e sadeleştirilmiş setupAutocomplete ekle**

```js
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
    else { const lq = q.toLowerCase(); list = opts.source.filter(s => s.toLowerCase().includes(lq)); }
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
```

**Step 2: Mevcut autocomplete'leri setupAutocomplete ile değiştir**

Önce `acHdeTani` (app.js:631) ve `acDisease` (app.js:676) fonksiyonlarını oku, ne yaptıklarını anla.

```js
// acHdeTani(inp) → setupAutocomplete:
setupAutocomplete('hdeTaniInp', {
  source: async (q) => {
    const all = await getData('hastalik_katalog');
    return all.filter(h => h.tani_ad.toLowerCase().includes(q.toLowerCase())).map(h => h.tani_ad);
  },
  onSelect: (val) => { /* mevcut callback mantığını kopyala */ }
});

// acDisease() → setupAutocomplete:
setupAutocomplete('diseaseInp', {
  source: HASTALIK_LISTESI,
  onSelect: (val) => { /* mevcut callback */ }
});
```

**Step 3: app.js'den eski acHdeTani ve acDisease tanımlarını sil**

**Step 4: Commit**

```bash
git add js/utils/helpers.js js/app.js
git commit -m "refactor: setupAutocomplete tekillestirildi"
```

---

### Task 3: Global State Referansları → AppState

**⚠️ İNSAN ONAYI GEREKİR**

**TDD scenario:** Modifying tested code — run existing tests first, verify after every change

**Files:**
- Modify: `js/state.js` (constructor'a yeni key'ler ekle)
- Modify: `js/ui.js` (~24 global referans)
- Modify: `js/app.js` (6 `_A`/`_S` referansı)

**Step 1: state.js constructor'ına yeni key'ler ekle**

```js
// state.js constructor'ına ekle:
// app.js:81'deki TÜM global'ler:
let _A=[], _S=[], _curStk=null, _curPg='dash',
    _suruFilter='tumuu', _suruSiralama='kupe',
    _curUremeTab='kizginlik', _curGecmisFilter='hepsi', _curTaskFilter='today',
    _curTaskDet=null, _curHst=null, _curToh=null, _curBildirimTab='bekliyor';

// state.js constructor'ına TÜMÜ eklenecek:
animals: [],              // _A
stock: [],                 // _S
curStok: null,             // _curStk
currentPage: 'dash',       // _curPg (zaten var)
suruFilter: 'tumuu',       // _suruFilter
suruSiralama: 'kupe',      // _suruSiralama
currentUremeTab: 'kizginlik',     // _curUremeTab (zaten var)
currentHistoryFilter: 'hepsi',   // _curGecmisFilter (zaten var)
currentTaskFilter: 'today',      // _curTaskFilter (zaten var)
currentTaskDetail: null,         // _curTaskDet (zaten var)
currentDisease: null,            // _curHst (zaten var)
currentInsem: null,              // _curToh (zaten var)
currentNotificationTab: 'bekliyor', // _curBildirimTab (zaten var)
gebeIds: [],               // _gebeIds — ⚠️ ARRAY! (kullanimda new Set() sarilir)
hastaIds: new Set(),       // _hastaIds — ⚠️ SET! (direkt .has() ile kullanilir)
taskKategori: 'all',       // _taskKategori
stokTab: 'tumu',           // _stokTab
curStokDet: null,          // _curStokDet
```

**Step 2: Referansları tara**

```bash
grep -n "_A\b\|_S\b\|_gebeIds\|_hastaIds\|_curStk\|_curPg\|_suruFilter\|_suruSiralama\|_curTaskFilter\|_curTaskDet\|_curHst\|_curToh\|_curBildirimTab\|_taskKategori\|_stokTab\|_curStokDet" js/ui.js js/app.js
```

**Step 3: Değiştir — tam eşleme tablosu**

| Eski | Yeni (okuma) | Yeni (yazma) | Not |
|------|-------------|-------------|-----|
| `_A` | `getState('animals')` | `setState('animals', x)` | |
| `_S` | `getState('stock')` | `setState('stock', x)` | |
| `_curStk` | `getState('curStok')` | `setState('curStok', x)` | |
| `_curPg` | `getState('currentPage')` | `setState('currentPage', x)` | |
| `_suruFilter` | `getState('suruFilter')` | `setState('suruFilter', x)` | |
| `_suruSiralama` | `getState('suruSiralama')` | `setState('suruSiralama', x)` | |
| `_curTaskFilter` | `getState('currentTaskFilter')` | `setState('currentTaskFilter', x)` | |
| `_curTaskDet` | `getState('currentTaskDetail')` | `setState('currentTaskDetail', x)` | |
| `_curHst` | `getState('currentDisease')` | `setState('currentDisease', x)` | |
| `_curToh` | `getState('currentInsem')` | `setState('currentInsem', x)` | |
| `_curBildirimTab` | `getState('currentNotificationTab')` | `setState('currentNotificationTab', x)` | |
| `_gebeIds` | `getState('gebeIds')` | `setState('gebeIds', x)` | ⚠️ ARRAY — `new Set()` sarılarak kullanılır |
| `_hastaIds` | `getState('hastaIds')` | `setState('hastaIds', x)` | ⚠️ SET — direkt `.has()` ile kullanılır |
| `_taskKategori` | `getState('taskKategori')` | `setState('taskKategori', x)` | |
| `_stokTab` | `getState('stokTab')` | `setState('stokTab', x)` | |
| `_curStokDet` | `getState('curStokDet')` | `setState('curStokDet', x)` | |

**⚠️ KRİTİK: Array/Set'i doğrudan mutate etme!**

```js
// YANLIŞ — event emit tetiklenmez:
const arr = getState('animals'); arr.push(x);  // ❌

// DOĞRU — her zaman setState ile yeni referans:
setState('animals', [...getState('animals'), x]);  // ✅
setState('gebeIds', [...getState('gebeIds'), id]);  // ✅ (ARRAY)
setState('hastaIds', new Set([...getState('hastaIds'), id]));  // ✅ (SET)
```

**Step 3b: globalThis._appState satırlarını SİL**

```js
// ui.js:476 ve ui.js:1480 — BU SATIRLARI SİL:
globalThis._appState = globalThis._appState || {}; globalThis._appState.hayvanlar = _A;
globalThis._appState = globalThis._appState || {}; globalThis._appState.stok = _S;
// setState zaten aynı işi yapıyor, bu satırlar gereksiz
```

**Step 3c: Hibrit pattern'i koru**

```js
// ui.js:466-467 — mevcut pattern DOĞRU, koru:
_A = await getData('hayvanlar', ...);
if (typeof setState === 'function') setState('animals', _A);

// SADECE _A = ... atamasını _A = ... bırak, sonra setState çağrısını ekle:
const animals = await getData('hayvanlar', a => a.durum === 'Aktif');
setState('animals', animals);
```

**Step 4: ui.js ve app.js başındaki `/* global */` yorumlarını güncelle**

```js
/* global
   getState, setState,
   HEKIMLER, VARSAYILAN_HEKIM,
   HASTALIK_LISTESI, HASTALIK_KAT, LOKASYON_KAT, SEMPTOM_KAT, SEMPTOM_GENEL,
   SPERMA_LISTESI, GRUP_PADOK, PADOKLAR,
   g, v, cl, dAgo, dFwd, fmtTarih, toast, esc, openM, closeM, mClose,
   registerAction, registerActions, setupAutocomplete,
   db, rpc, rpcOptimistic, getData, idbPut, openDB,
   pullTables, renderSafe, syncNow
*/
```

**Step 5: Syntax check + commit**

```bash
for f in js/state.js js/app.js js/ui.js; do node --check "$f" && echo "✓ $f"; done
git add js/state.js js/app.js js/ui.js
git commit -m "refactor: tum global referanslar state'e gecirildi"
```

---

## Test Instructions

```bash
cd /root/egesut-erp1

# 1. Yeni dosyalar var mi?
ls -la js/utils/helpers.js js/utils/modal.js

# 2. app.js'de eski fonksiyonlar kaldirildi mi? (0 olmali)
grep -c "function g(\|function v(\|function cl(\|function openM(\|function closeM(" js/app.js

# 3. Yeni fonksiyonlar utils'te mi?
grep -c "function g(\|function toast(\|function esc(" js/utils/helpers.js  # >= 8
grep -c "function openM(\|function closeM(" js/utils/modal.js              # >= 2

# 4. Global referans kaldi mi? (0 olmali — sadece comment/string'te olabilir)
grep -n "_A\b\|_S\b" js/ui.js js/app.js | grep -v "//\|getState"

# 5. Syntax check
for f in js/utils/*.js js/state.js js/config.js js/api.js js/app.js js/forms.js js/ui.js; do
  node --check "$f" 2>&1 && echo "✓ $f" || echo "✗ $f"
done
```
