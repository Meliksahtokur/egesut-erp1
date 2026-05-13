# Aşama 1 Altyapı Tamamlama — Implementation Plan

> **REQUIRED SUB-SKILL:** Use the executing-plans skill to implement this plan task-by-task.
> **Neye dokunma:** config.js'ye dokunma (tamamlandı), Supabase migration'larına dokunma, mevcut iş mantığını değiştirme — sadece taşı/tekilleştir.

**Goal:** Aşama 1'in kalan 3 maddesini tamamla: yardımcı fonksiyonları utils/'e taşı, autocomplete'i tekilleştir, global state referanslarını AppState'e geçir.

**Architecture:** `app.js`'teki `g()`, `v()`, `cl()`, `toast()`, `openM()`, `closeM()`, `dAgo()`, `dFwd()`, `fmtTarih()` → `js/utils/helpers.js` ve `js/utils/modal.js`. `acHdeTani` + `acDisease` → tek `setupAutocomplete()`. `ui.js`'teki `_A`/`_S` referansları → `getState('animals')`/`setState(...)`.

**Tech Stack:** Vanilla JS

**⚠️ İNSAN ONAYI GEREKİR:** Task 5 (state migration) — 24 adet `_A`/`_S` referansı değişecek. Yanlış referans = hayvan listesi boş gelir. Gözden geçirilmeden uygulanmasın.

---

### Task 1: `utils/helpers.js` Oluştur

**TDD scenario:** Modifying tested code — run existing tests first

**Files:**
- Create: `js/utils/helpers.js`
- Modify: `js/app.js` (g, v, cl, dAgo, dFwd, fmtTarih, toast'u kaldır)

**Step 1: helpers.js oluştur, DOM yardımcılarını taşı**

```js
// js/utils/helpers.js
// Genel yardımcı fonksiyonlar

function g(id)   { return document.getElementById(id); }
function v(id)   { return g(id)?.value || ''; }
function cl(id)  { const el = g(id); if (el) el.value = ''; }

function dAgo(n) {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d.toISOString().split('T')[0];
}

function dFwd(base, n) {
  const d = base ? new Date(base) : new Date();
  d.setDate(d.getDate() + n);
  return d.toISOString().split('T')[0];
}

function fmtTarih(iso) {
  if (!iso) return '—';
  const p = iso.slice(0, 10).split('-');
  return p.length === 3 ? `${p[2]}.${p[1]}.${p[0]}` : iso;
}

function toast(msg, err = false) {
  const t = document.createElement('div');
  t.className = `toast ${err ? 'err' : 'ok'}`;
  t.textContent = msg;
  document.body.appendChild(t);
  setTimeout(() => t.classList.add('show'), 10);
  setTimeout(() => { t.classList.remove('show'); setTimeout(() => t.remove(), 300); }, 3000);
}
```

**Step 2: helpers.js'in çalıştığını doğrula**

Bash test: `grep -c "function " /root/egesut-erp1/js/utils/helpers.js` → 8

**Step 3: index.html'de helpers.js'i diğer scriptlerden önce yükle**

```html
<script src="js/utils/helpers.js?v=3"></script>
<script src="js/config.js?v=3"></script>
<script src="js/state.js?v=3"></script>
...
```

**Step 4: app.js'den taşınan fonksiyonları sil**

`app.js`'ten `g()`, `v()`, `cl()`, `dAgo()`, `dFwd()`, `fmtTarih()`, `toast()` fonksiyon tanımlarını kaldır (satır 88-158 arası).

**Step 5: Commit**

```bash
git add js/utils/helpers.js js/app.js index.html
git commit -m "refactor: helpers.js olustur, DOM yardimcilari ve toast tasindi"
```

---

### Task 2: `utils/modal.js` Oluştur

**TDD scenario:** Modifying tested code — run existing tests first

**Files:**
- Create: `js/utils/modal.js`
- Modify: `js/app.js` (openM, closeM, mClose'u kaldır)

**Step 1: modal.js oluştur**

```js
// js/utils/modal.js
// Modal yönetimi

function openM(id) {
  const el = document.getElementById(id);
  if (!el) return;
  el.classList.add('on');
  el.setAttribute('aria-hidden', 'false');

  // ESC ile kapat
  const escHandler = (e) => {
    if (e.key === 'Escape') {
      closeM(id);
      document.removeEventListener('keydown', escHandler);
    }
  };
  document.addEventListener('keydown', escHandler);
  el._escHandler = escHandler;
}

function closeM(id) {
  const el = document.getElementById(id);
  if (!el) return;
  el.classList.remove('on');
  el.setAttribute('aria-hidden', 'true');
  if (el._escHandler) {
    document.removeEventListener('keydown', el._escHandler);
    delete el._escHandler;
  }
}

function mClose(e, el) {
  if (e.target === el) el.classList.remove('on');
}
```

**Step 2: index.html'de modal.js yükle**

Helpers.js'den sonra, diğerlerinden önce.

**Step 3: app.js'den eski openM/closeM/mClose tanımlarını kaldır**

**Step 4: Commit**

```bash
git add js/utils/modal.js js/app.js index.html
git commit -m "refactor: modal.js olustur, openM/closeM/mClose tasindi"
```

---

### Task 3: `setupAutocomplete()` Tekilleştirme

**TDD scenario:** New feature — full TDD cycle

**Files:**
- Modify: `js/app.js` (acHdeTani, acDisease → setupAutocomplete)

**Step 1: setupAutocomplete fonksiyonunu helpers.js'e ekle**

```js
/**
 * Genel autocomplete fonksiyonu
 * @param {string} inputId - Input element ID'si
 * @param {object} options
 * @param {string[]|function} options.dataSource - Statik liste veya async fonksiyon
 * @param {string} options.displayField - Görüntülenecek alan (obje datasource için)
 * @param {string} options.valueField - Değer alanı (obje datasource için)
 * @param {function} options.onSelect - Seçim yapıldığında çağrılır (value, item)
 */
function setupAutocomplete(inputId, options) {
  const input = g(inputId);
  if (!input) return;

  let list = [];
  let selectedIndex = -1;

  const wrapper = document.createElement('div');
  wrapper.className = 'ac-wrapper';
  input.parentNode.insertBefore(wrapper, input.nextSibling);

  const listEl = document.createElement('ul');
  listEl.className = 'ac-list';
  wrapper.appendChild(listEl);

  async function loadData(query) {
    if (typeof options.dataSource === 'function') {
      list = await options.dataSource(query);
    } else {
      const q = query.toLowerCase();
      list = options.dataSource.filter(item => {
        const text = typeof item === 'string' ? item : item[options.displayField];
        return text.toLowerCase().includes(q);
      });
    }
  }

  function renderList() {
    listEl.innerHTML = '';
    selectedIndex = -1;
    list.slice(0, 10).forEach((item, i) => {
      const li = document.createElement('li');
      li.textContent = typeof item === 'string' ? item : item[options.displayField];
      li.addEventListener('mousedown', (e) => {
        e.preventDefault();
        selectItem(i);
      });
      listEl.appendChild(li);
    });
    if (list.length) listEl.style.display = 'block';
    else listEl.style.display = 'none';
  }

  function selectItem(idx) {
    const item = list[idx];
    const value = typeof item === 'string' ? item : item[options.valueField];
    input.value = typeof item === 'string' ? item : item[options.displayField];
    listEl.style.display = 'none';
    if (options.onSelect) options.onSelect(value, item);
  }

  input.addEventListener('input', async () => {
    const q = input.value.trim();
    if (q.length < 1) { listEl.style.display = 'none'; return; }
    await loadData(q);
    renderList();
  });

  input.addEventListener('keydown', (e) => {
    const items = listEl.querySelectorAll('li');
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (selectedIndex < items.length - 1) selectedIndex++;
      highlightItem(items);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (selectedIndex > 0) selectedIndex--;
      highlightItem(items);
    } else if (e.key === 'Enter' && selectedIndex >= 0) {
      e.preventDefault();
      selectItem(selectedIndex);
    } else if (e.key === 'Escape') {
      listEl.style.display = 'none';
    }
  });

  function highlightItem(items) {
    items.forEach((li, i) => li.classList.toggle('active', i === selectedIndex));
  }

  document.addEventListener('click', (e) => {
    if (!wrapper.contains(e.target) && e.target !== input) {
      listEl.style.display = 'none';
    }
  });
}
```

**Step 2: Mevcut autocomplete çağrılarını değiştir**

`acHdeTani(inp)` çağrısını değiştir:

```js
// ESKI:
acHdeTani('hdeTaniInp');

// YENI:
setupAutocomplete('hdeTaniInp', {
  dataSource: async (query) => {
    const all = await getData('hastalik_katalog');
    return all.filter(h => h.tani_ad.toLowerCase().includes(query.toLowerCase()));
  },
  displayField: 'tani_ad',
  valueField: 'id',
  onSelect: (value, item) => {
    // mevcut callback mantığı
  }
});
```

`acDisease()` çağrısını değiştir (benzer şekilde).

**Step 3: app.js'den eski acHdeTani ve acDisease fonksiyonlarını kaldır**

**Step 4: test — input'a yazıp autocomplete'in çalıştığını doğrula**

Manuel test: tarayıcıda hastalık tanı input'una yaz → autocomplete listesi görünmeli.

**Step 5: Commit**

```bash
git add js/utils/helpers.js js/app.js
git commit -m "refactor: setupAutocomplete tekillestirildi, acHdeTani/acDisease kaldirildi"
```

---

### Task 4: State Migration — `_A`/`_S` → `getState`/`setState`

**⚠️ İNSAN ONAYI GEREKİR**

**TDD scenario:** Modifying tested code — run existing tests first, verify after every change

**Files:**
- Modify: `js/ui.js` (18 `_A`/`_S` referansı)
- Modify: `js/app.js` (6 `_A`/`_S` referansı)

**Mevcut durum:**
- `state.js`'te `AppState` class'ı var, `globalThis.__state` olarak erişilebilir
- `getState(key)` / `setState(key, value)` yardımcıları var
- `ui.js` hala `_A` (animals array), `_S` (stock array) gibi global değişkenleri direkt kullanıyor

**Step 1: ui.js ve app.js'teki tüm `_A`/`_S` referanslarını listele**

```bash
grep -n "_A\b\|_S\b" /root/egesut-erp1/js/ui.js /root/egesut-erp1/js/app.js
```

**Step 2: Her referansı değiştir**

| Eski | Yeni |
|------|------|
| `_A` (okuma) | `getState('animals')` |
| `_A = x` (yazma) | `setState('animals', x)` |
| `_S` (okuma) | `getState('stock')` |
| `_S = x` (yazma) | `setState('stock', x)` |

Örnek:
```js
// ESKI:
_A.forEach(a => { ... });
_S.push(newItem);

// YENI:
getState('animals').forEach(a => { ... });
const stock = getState('stock');
stock.push(newItem);
setState('stock', stock);
```

**Step 3: ui.js'in başındaki `/* global _A, _S */` yorumunu güncelle**

```js
/* global
   getState, setState,
   _gebeIds, _hastaIds,
   ...
*/
```

**Step 4: Syntax check**

```bash
grep -rn "\.js" /root/egesut-erp1/js/*.js | grep -v "node_modules" | head -5
```

**Step 5: Commit**

```bash
git add js/ui.js js/app.js
git commit -m "refactor: _A/_S global referanslar getState/setState'e gecirildi"
```

---

### Task 5: Diğer Global Referansları Temizleme

**TDD scenario:** Modifying tested code — run existing tests first

**Files:**
- Modify: `js/ui.js` (global değişkenleri state'e taşı)

**Mevcut global değişkenler (`ui.js` içinde `let` ile tanımlanmış):**

```
_taskKategori, _stokTab, _curStokDet
```

**Step 1: Bu değişkenleri module-scope'dan kaldırıp state'e taşı**

```js
// ESKI (ui.js tepesi):
let _taskKategori='all';
let _stokTab='tumu';
let _curStokDet=null;

// YENI:
// Bu değişkenler state üzerinden yönetilsin
// Kullanan yerler: getState('taskKategori'), setState('taskKategori', 'all')
```

**Step 2: state.js'ye yeni key'ler ekle**

```js
// state.js constructor'ına ekle:
taskKategori: 'all',
stokTab: 'tumu',
curStokDet: null,
```

**Step 3: Tüm referansları değiştir**

```bash
grep -n "_taskKategori\|_stokTab\|_curStokDet" js/ui.js
```

Her referansı `getState`/`setState` ile değiştir.

**Step 4: Commit**

```bash
git add js/ui.js js/state.js
git commit -m "refactor: _taskKategori/_stokTab/_curStokDet state'e tasindi"
```

---

## Test Instructions

Tüm task'lardan sonra:

```bash
cd /root/egesut-erp1
# Syntax check
for f in js/utils/*.js js/state.js js/config.js js/api.js js/app.js js/forms.js js/ui.js; do
  node --check "$f" 2>&1 && echo "✓ $f" || echo "✗ $f"
done

# Kullanim kontrolü — tasinan fonksiyonlarin artik app.js'te tanimli OLMADIGINI dogrula
grep -c "^function g(\|^function v(\|^function cl(\|^function openM(\|^function closeM(" js/app.js
# Yukaridaki 0 dönmeli (hepsi tasindi)

# Yeni fonksiyonlarin utils'te oldugunu dogrula
grep -c "^function g(\|^function v(\|^function toast(" js/utils/helpers.js
# Yukaridaki 7+ dönmeli

grep -c "^function openM(\|^function closeM(" js/utils/modal.js
# Yukaridaki 2 dönmeli
```

---

## Onay Gerektiren İşler

| Task | Risk | Neden |
|------|------|-------|
| Task 4 | **YÜKSEK** | 24 adet `_A`/`_S` referansı değişecek. Yanlış `getState` çağrısı = boş liste, render hatası |
| Task 5 | Orta | 3 global değişken state'e taşınıyor, görev filtresi ve stok sekmesi etkilenir |

**Task 1-3** risksiz, hemen başlanabilir. Task 4-5 için onay iste.
