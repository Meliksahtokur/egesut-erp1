# Aşama 7+8+9 — Performans, Test, Dökümantasyon

> **REQUIRED SUB-SKILL:** Use the executing-plans skill.
> **Bağımlılık:** Aşama 1-3 tamamlanmış olmalı.

**Goal:** Debounce/throttle, ESLint/Prettier kurulumu, JSDoc yorumları, README güncelleme.

**Tech Stack:** Vanilla JS, npm

---

### Task 1: Debounce + Throttle Ekle

**Files:** Modify: `js/utils/helpers.js`

**Step 1: debounce ve throttle utility'leri ekle**

```js
function debounce(fn, delay = 300) {
  let timer;
  return (...args) => { clearTimeout(timer); timer = setTimeout(() => fn(...args), delay); };
}

function throttle(fn, limit = 1000) {
  let inThrottle = false;
  return (...args) => {
    if (!inThrottle) { fn(...args); inThrottle = true; setTimeout(() => inThrottle = false, limit); }
  };
}
```

**Step 2: syncNow ve pullTables'a throttle/debounce uygula**

```js
// pullTables zaten debounce varsa kontrol et, yoksa ekle
const debouncedPullTables = debounce(pullTables, 5000);
// syncNow throttle
const throttledSync = throttle(syncNow, 30000);
```

**Step 3: Commit**

---

### Task 2: ESLint + Prettier Kurulumu

**Files:** Create: `.eslintrc.json`, `.prettierrc`, `.eslintignore`

**Step 1: ESLint config**

```json
{
  "env": { "browser": true, "es2020": true },
  "extends": "eslint:recommended",
  "parserOptions": { "ecmaVersion": 2020 },
  "rules": {
    "no-unused-vars": "warn",
    "no-undef": "warn",
    "no-extra-semi": "warn",
    "semi": ["warn", "always"],
    "quotes": ["warn", "single"]
  },
  "globals": {
    "g": "readonly", "v": "readonly", "cl": "readonly",
    "toast": "readonly", "openM": "readonly", "closeM": "readonly",
    "esc": "readonly", "fmtTarih": "readonly",
    "getState": "readonly", "setState": "readonly",
    "db": "readonly", "rpc": "readonly", "getData": "readonly",
    "registerAction": "readonly", "debounce": "readonly"
  }
}
```

**Step 2: Prettier config**

```json
{ "semi": true, "singleQuote": true, "tabWidth": 2, "printWidth": 100 }
```

**Step 3: Commit**

---

### Task 3: JSDoc Yorumları (Kritik Fonksiyonlar)

**Files:** Modify: `js/ui.js`, `js/forms.js`, `js/app.js`

**Step 1: openDet fonksiyonuna JSDoc ekle**

```js
/**
 * Hayvan detay panelini açar ve render eder
 * @param {string} hayvanId - Hayvan UUID'si
 * @returns {Promise<void>}
 */
async function openDet(hayvanId) { ... }
```

**Step 2: loadDash fonksiyonuna JSDoc ekle**

```js
/**
 * Dashboard'u yükler: hayvan sayıları, görevler, bildirimler
 * @returns {Promise<void>}
 */
async function loadDash() { ... }
```

**Step 3: Tüm RPC çağrılarına JSDoc ekle**

Özellikle `api.js`'deki `rpc()` ve `rpcOptimistic()`.

**Step 4: Commit**

---

### Task 4: README.md Güncelleme

**Files:** Modify: `README.md`

**Step 1: Güncel README yaz**

```markdown
# EgeSüt ERP

Süt sığırcılığı işletmesi için offline-first yönetim paneli.

## Kurulum

1. Repoyu klonlayın: `git clone <url>`
2. `index.html`'i tarayıcıda açın
3. Supabase bağlantısı otomatik kurulur

## Geliştirme

- `js/config.js` - Sabitler
- `js/state.js` - Merkezi state yönetimi (AppState)
- `js/utils/` - Yardımcı fonksiyonlar
- `js/api.js` - Supabase API, IndexedDB
- `js/app.js` - Uygulama mantığı
- `js/ui.js` - Render fonksiyonları
- `js/forms.js` - Form submit ve validasyon
- `supabase/migrations/` - Veritabanı migration'ları
```

**Step 2: Commit**

---

## Test Instructions

```bash
# Helpers'da debounce/throttle tanimli mi?
grep -c "function debounce\|function throttle" js/utils/helpers.js  # 2

# ESLint/Prettier config'leri var mi?
ls -la .eslintrc.json .prettierrc 2>/dev/null

# JSDoc yorumlari eklendi mi?
grep -c "@param\|@returns" js/ui.js  # > 2 olmali
```
