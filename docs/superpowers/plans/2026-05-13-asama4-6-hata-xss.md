# Aşama 4 + 6 — Hata Yönetimi + XSS Güvenliği

> **REQUIRED SUB-SKILL:** Use the executing-plans skill to implement.

**Goal:** Merkezi hata yakalama, kullanıcı dostu mesajlar, debug modu; innerHTML XSS temizliği.

**Architecture:** `withErrorHandling(fn, context)` wrapper tüm async çağrıları sarar. `window.onerror` + `unhandledrejection` dinleyicileri. innerHTML → textContent + escapeHtml.

**Tech Stack:** Vanilla JS

---

### Task 1: `withErrorHandling()` Wrapper + Global Hata Dinleyici

**Files:** Create: `js/utils/errorHandler.js`, Modify: `index.html`

**Step 1: errorHandler.js oluştur**

```js
// js/utils/errorHandler.js
// Merkezi hata yönetimi

let debugMode = false;
try { debugMode = localStorage.getItem('debug') === 'true'; } catch(e) {}

function withErrorHandling(fn, context) {
  return async (...args) => {
    try {
      return await fn(...args);
    } catch (err) {
      const msg = context
        ? `${context}: ${err.message || err}`
        : (err.message || String(err));
      console.error(`[EgeSüt] ${msg}`, err);
      toast(msg, true);
      if (debugMode) showDebug(err, context);
      throw err; // re-throw ile üst katmana da ilet
    }
  };
}

function showDebug(err, context) {
  const panel = g('debugPanel');
  if (!panel) return;
  const entry = document.createElement('div');
  entry.className = 'debug-entry';
  entry.innerHTML = `<strong>${new Date().toLocaleTimeString()}</strong> [${context || '?'}] ${escapeHtml(err.message || String(err))}`;
  panel.prepend(entry);
  if (panel.children.length > 50) panel.lastChild.remove();
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

window.addEventListener('error', (e) => {
  console.error('[EgeSüt] Global error:', e.message, e.filename, e.lineno);
  if (debugMode) showDebug(e.error || e, 'window.onerror');
});

window.addEventListener('unhandledrejection', (e) => {
  console.error('[EgeSüt] Unhandled rejection:', e.reason);
  toast('Beklenmeyen bir hata oluştu. Lütfen sayfayı yenileyin.', true);
  if (debugMode) showDebug(e.reason, 'unhandledrejection');
});
```

**Step 2: index.html'ye yükle (helpers.js'ten sonra)**

```html
<script src="js/utils/errorHandler.js?v=3"></script>
```

**Step 3: Syntax check + commit**

---

### Task 2: Kullanıcı Dostu Hata Mesajları

**Files:** Modify: `js/utils/errorHandler.js`, `js/app.js`

**Step 1: Hata -> kullanıcı mesajı haritası ekle**

```js
const USER_FRIENDLY_ERRORS = {
  'Failed to fetch': 'İnternet bağlantısı kesildi. Lütfen bağlantınızı kontrol edin.',
  'NetworkError': 'Sunucuya ulaşılamıyor. Lütfen daha sonra tekrar deneyin.',
  'timeout': 'İşlem zaman aşımına uğradı. Lütfen tekrar deneyin.',
  'duplicate key': 'Bu kayıt zaten mevcut.',
  'PGRST': 'Veritabanı işlemi başarısız oldu.',
};

function getUserMessage(err) {
  const msg = err.message || String(err);
  for (const [key, friendly] of Object.entries(USER_FRIENDLY_ERRORS)) {
    if (msg.includes(key)) return friendly;
  }
  return 'Bir hata oluştu. Lütfen daha sonra tekrar deneyin.';
}
```

**Step 2: toast çağrılarında getUserMessage kullan**

```js
// withErrorHandling içindeki toast satırını güncelle:
toast(getUserMessage(err), true);
```

**Step 3: Commit**

---

### Task 3: innerHTML → `esc()` Temizliği

**Files:** Modify: `js/ui.js`, `js/forms.js`, `js/app.js`

**Step 1: helpers.js'e esc fonksiyonu ekle**

```js
function esc(str) {
  const div = document.createElement('div');
  div.textContent = str || '';
  return div.innerHTML;
}
```

**Step 2: Kullanıcı verisi basılan innerHTML'leri tara ve değiştir**

Tarama (riskli olanlar — kullanıcı girdisi içerenler):

```bash
grep -n "innerHTML.*=" js/ui.js js/forms.js js/app.js | grep -v "band(\|\.css\|\\.svg\|html>" | head -30
```

Değiştirilmesi gereken pattern:

```js
// ESKI (XSS riski):
el.innerHTML = `<span>${hayvan.kupe_no}</span>`;

// YENI (güvenli):
el.innerHTML = `<span>${esc(hayvan.kupe_no)}</span>`;
```

**Neye dokunma:** CSS class, SVG, HTML yapısal string'ler, `band()` yardımcı fonksiyonu içindeki statik HTML.

**Sadece şu pattern'leri değiştir:** Template literal içinde `${degisken}` olup `degisken` kullanıcı verisi olan innerHTML atamaları.

**Step 3: Syntax check + commit**

```bash
for f in js/utils/helpers.js js/ui.js js/forms.js js/app.js; do node --check "$f" && echo "✓ $f"; done
```

---

## Test Instructions

```bash
cd /root/egesut-erp1
# Hata yönetimi testi:
grep -c "withErrorHandling" js/utils/errorHandler.js  # > 0
grep -c "addEventListener.*error" js/utils/errorHandler.js  # 1
grep -c "addEventListener.*unhandledrejection" js/utils/errorHandler.js  # 1

# XSS testi:
# esc() fonksiyonu tanimli mi?
grep -c "function esc(" js/utils/helpers.js  # 1
# innerHTML'in kullanildigi ama esc() KULLANILMAYAN yer var mi kontrol et
```
