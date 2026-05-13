# Aşama 4 + 6 — Hata Yönetimi + XSS Güvenliği

> **REQUIRED SUB-SKILL:** Use the executing-plans skill.
> **Bağımlılık:** Plan 1 (helpers.js'te `esc()` ve `toast()` mevcut olmalı).

**Goal:** Merkezi hata yakalama, kullanıcı dostu mesajlar, debug modu; innerHTML XSS temizliği.

**Architecture:** `withErrorHandling(fn, context)` wrapper tüm async çağrıları sarar. `window.onerror` + `unhandledrejection` dinleyicileri. innerHTML'de kullanıcı verisi → `esc()`.

**Scope — innerHTML değişikliği:** Toplam 186 innerHTML var. SADECE kullanıcı verisi içerenler değişecek. CSS class, SVG, HTML yapısal string'ler, `band()` yardımcı fonksiyonu DOKUNULMAYACAK.

```bash
# Değişecek innerHTML'leri bul:
grep -n 'innerHTML.*=.*\$\{' js/ui.js js/forms.js js/app.js | grep -v 'band(' | grep -v '\.css' | grep -v '<svg'
# Bu çıktıdaki tüm satırlarda kullanıcı verisi basılan yerler esc() ile sarılacak
```

**Tech Stack:** Vanilla JS

---

### Task 1: `withErrorHandling()` + Debug Modu

**Files:**
- Create: `js/utils/errorHandler.js`
- Modify: `index.html` (errorHandler.js yükle + debug panel div'i)

**Step 1: errorHandler.js oluştur**

```js
// js/utils/errorHandler.js
let debugMode = false;
try { debugMode = localStorage.getItem('debug') === 'true'; } catch(e) {}

const USER_FRIENDLY = {
  'Failed to fetch': 'İnternet bağlantısı kesildi.',
  'NetworkError': 'Sunucuya ulaşılamıyor.',
  'timeout': 'İşlem zaman aşımına uğradı.',
  'duplicate key': 'Bu kayıt zaten mevcut.',
  'PGRST': 'Veritabanı işlemi başarısız oldu.',
};

function getUserMessage(err) {
  const msg = err?.message || String(err);
  for (const [k, v] of Object.entries(USER_FRIENDLY)) {
    if (msg.includes(k)) return v;
  }
  return 'Bir hata oluştu. Lütfen daha sonra tekrar deneyin.';
}

function withErrorHandling(fn, context) {
  return async (...args) => {
    try { return await fn(...args); }
    catch (err) {
      console.error(`[EgeSüt] ${context || '?'}:`, err);
      toast(getUserMessage(err), true);
      if (debugMode) showDebug(err, context);
      return null; // re-throw yerine null dön — çift toast'u önle
    }
  };
}

function showDebug(err, context) {
  const panel = g('debugPanel');
  if (!panel) return;
  const entry = document.createElement('div');
  entry.className = 'debug-entry';
  entry.innerHTML = `<strong>${new Date().toLocaleTimeString()}</strong> [${context||'?'}] ${esc(err.message || String(err))}`;
  panel.prepend(entry);
  if (panel.children.length > 50) panel.lastChild?.remove();
}

window.addEventListener('error', (e) => {
  console.error('[EgeSüt] Global error:', e.message, e.filename, e.lineno);
  if (debugMode) showDebug(e.error || e, 'window.onerror');
});

window.addEventListener('unhandledrejection', (e) => {
  console.error('[EgeSüt] Unhandled:', e.reason);
  toast('Beklenmeyen bir hata oluştu.', true);
  if (debugMode) showDebug(e.reason, 'unhandledrejection');
});
```

**Step 2: index.html'ye debug panel div'i ekle**

```html
<!-- </body> öncesine: -->
<div id="debugPanel" style="display:none; position:fixed; bottom:0; left:0; right:0; max-height:200px; overflow-y:auto;
  background:#1a1a2e; color:#0f0; font:12px monospace; padding:8px; z-index:9999; border-top:2px solid #333;"></div>
```

**Step 3: index.html'ye errorHandler.js yükle**

```html
<script src="js/utils/errorHandler.js?v=3"></script>
```

**Step 4: Merge: helpers.js'teki `esc()` errorHandler.js'te de import edilmiş gibi davran (global scope)**

`errorHandler.js`, `helpers.js`'ten sonra yüklendiği için `esc()` erişilebilir olacak. Hiçbir import gerekmez — global scope.

**Step 5: Commit**

```bash
git add js/utils/errorHandler.js index.html
git commit -m "feat: merkezi hata yonetimi + debug modu eklendi"
```

---

### Task 2: Mevcut Async Çağrıları `withErrorHandling` ile Sarma

**Files:** Modify: `js/app.js`, `js/ui.js`, `js/forms.js`

**Step 1: Sarılması gereken async fonksiyonları tara**

```bash
grep -n "async function\|async (" js/app.js js/ui.js js/forms.js | head -30
```

**Step 2: Ana giriş noktalarını sar (hepsini değil, sadece üst seviye)**

```js
// app.js'de:
document.addEventListener('DOMContentLoaded', withErrorHandling(async () => {
  // mevcut init kodu
}, 'init'));

// loadDash çağrısı:
const loadDashSafe = withErrorHandling(loadDash, 'loadDash');
```

**Step 3: Commit**

```bash
git add js/app.js js/ui.js js/forms.js
git commit -m "feat: ana async fonksiyonlar withErrorHandling ile sarildi"
```

---

### Task 3: innerHTML XSS Temizliği

**Files:** Modify: `js/ui.js`, `js/forms.js`, `js/app.js`

**Step 1: Değişecek innerHTML'leri listele**

```bash
grep -n 'innerHTML.*=.*\$\{' js/ui.js js/forms.js js/app.js | grep -v 'band(' | grep -v '\.css' | grep -v '<svg' > /tmp/innerhtml_fixes.txt
wc -l /tmp/innerhtml_fixes.txt  # kaç satır var?
```

**Step 2: Her satırda kullanıcı verisi içeren `${...}` ifadelerini `esc()` ile sar**

```js
// ESKI:
el.innerHTML = `<span>${hayvan.kupe_no}</span>`;

// YENI:
el.innerHTML = `<span>${esc(hayvan.kupe_no)}</span>`;
```

**Neye DOKUNMA:**
- `band(...)` çağrıları (statik HTML yapısı)
- CSS class, SVG içeren innerHTML'ler
- `${...}` sadece CSS class/renk/ikon içerenler

**Neye esc() EKLE:**
- Hayvan adı, küpe no, grup adı, padok adı
- Görev açıklaması, not
- Kullanıcıdan gelen herhangi bir string

**Step 3: Syntax check + commit**

```bash
for f in js/ui.js js/forms.js js/app.js; do node --check "$f" && echo "✓ $f"; done
git add js/ui.js js/forms.js js/app.js
git commit -m "security: innerHTML kullanici verilerine esc() eklendi (XSS)"
```

---

## Test Instructions

```bash
cd /root/egesut-erp1

# errorHandler.js var mi?
grep -c "withErrorHandling" js/utils/errorHandler.js  # >= 1
grep -c "getUserMessage" js/utils/errorHandler.js      # >= 1

# Global hata dinleyicileri
grep -c "addEventListener.*error" js/utils/errorHandler.js       # 1
grep -c "addEventListener.*unhandledrejection" js/utils/errorHandler.js  # 1

# Debug panel HTML'de var mi?
grep -c "debugPanel" index.html  # 1

# esc() kullanimi artti mi?
grep -c "esc(" js/ui.js  # innerHTML fix listesindeki satır sayısı kadar artmalı
```
