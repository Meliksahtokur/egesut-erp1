> **✅ TAMAMLANDI** — Commit'ler: `65ae792` (ESLint+Prettier), `8d05f7b` (README güncelleme), `96109ad` (JSDoc). Performans/debounce, kod kalitesi/ESLint, dokümantasyon/README tamamlandı.

# Aşama 7+8+9 — Performans, Test, Dökümantasyon

> **REQUIRED SUB-SKILL:** Use the executing-plans skill.
> **Bağımlılık:** Plan 1 tamamlanmış olmalı (helpers.js, state.js mevcut).

**Goal:** pullTables'a debounce, ESLint/Prettier kurulumu, JSDoc yorumları, README güncelleme.

**ÖNCE OKU:** `pullTables` şu an debounce'suz, postgres_changes subscription'dan direkt çağrılıyor. Subscription debounce edilirse gerçek zamanlılık kaybolur. SADECE manuel refresh ve periyodik poll debounce edilecek.

**Tech Stack:** Vanilla JS, npm

---

### Task 1: Debounce + Throttle Ekle

**Files:** Modify: `js/utils/helpers.js`

**Step 1: Utility fonksiyonlarını ekle**

```js
function debounce(fn, delay = 300) {
  let timer;
  return (...args) => { clearTimeout(timer); timer = setTimeout(() => fn(...args), delay); };
}

function throttle(fn, limit = 1000) {
  let last = 0;
  return (...args) => { const now = Date.now(); if (now - last >= limit) { last = now; fn(...args); } };
}
```

**Step 2: pullTables debounce — SADECE manuel çağrılar için**

```js
// api.js'de:
const _debouncedPull = debounce((tables) => pullTables(tables).then(renderSafe).catch(console.warn), 5000);

// refreshAll() / manuel refresh → _debouncedPull kullan
// postgres_changes subscription → direkt pullTables (debounce YOK — real-time gerekli)
```

**Step 3: Commit**

```bash
git add js/utils/helpers.js js/api.js
git commit -m "perf: debounce/throttle, pullTables manuel refresh debounce"
```

---

### Task 2: ESLint + Prettier Kurulumu

**Files:** Create: `.eslintrc.json`, `.prettierrc`, `.eslintignore`

**Step 1: ESLint config**

```json
{
  "env": { "browser": true, "es2021": true },
  "extends": "eslint:recommended",
  "parserOptions": { "ecmaVersion": 2021 },
  "rules": {
    "no-unused-vars": "warn",
    "no-undef": "warn",
    "no-extra-semi": "warn"
  },
  "globals": {
    "g": "readonly", "v": "readonly", "cl": "readonly",
    "toast": "readonly", "openM": "readonly", "closeM": "readonly",
    "esc": "readonly", "fmtTarih": "readonly", "dAgo": "readonly", "dFwd": "readonly",
    "getState": "readonly", "setState": "readonly",
    "registerAction": "readonly", "registerActions": "readonly",
    "debounce": "readonly", "throttle": "readonly",
    "withErrorHandling": "readonly", "setupAutocomplete": "readonly",
    "getData": "readonly", "idbPut": "readonly", "openDB": "readonly",
    "db": "readonly", "rpc": "readonly", "rpcOptimistic": "readonly",
    "pullTables": "readonly", "renderSafe": "readonly", "syncNow": "readonly",
    "HEKIMLER": "readonly", "VARSAYILAN_HEKIM": "readonly",
    "HASTALIK_LISTESI": "readonly", "HASTALIK_KAT": "readonly",
    "LOKASYON_KAT": "readonly", "SEMPTOM_KAT": "readonly", "SEMPTOM_GENEL": "readonly",
    "SPERMA_LISTESI": "readonly", "GRUP_PADOK": "readonly", "PADOKLAR": "readonly",
    "supabase": "readonly"
  }
}
```

**Step 2: Prettier config**

```json
{ "semi": true, "singleQuote": true, "tabWidth": 2, "printWidth": 100 }
```

**Step 3: .eslintignore**

```
supabase/
node_modules/
```

**Step 4: Commit**

```bash
git add .eslintrc.json .prettierrc .eslintignore
git commit -m "chore: ESLint + Prettier kurulumu"
```

---

### Task 3: JSDoc Yorumları

**Files:** Modify: `js/ui.js`, `js/app.js`, `js/api.js`

**Step 1: Kritik fonksiyonlara JSDoc ekle**

```js
/**
 * Hayvan detay panelini açar
 * @param {string} hayvanId
 * @returns {Promise<void>}
 */
async function openDet(hayvanId) { ... }

/**
 * Dashboard'u yükler
 * @returns {Promise<void>}
 */
async function loadDash() { ... }

/**
 * Supabase RPC çağrısı
 * @param {string} fn - Fonksiyon adı
 * @param {object} params - Parametreler
 * @returns {Promise<{ok: boolean, error?: string}>}
 */
async function rpc(fn, params) { ... }
```

**Step 2: Commit**

```bash
git add js/ui.js js/app.js js/api.js
git commit -m "docs: kritik fonksiyonlara JSDoc yorumlari eklendi"
```

---

### Task 4: README.md Güncelleme

**Files:** Modify: `README.md`

```markdown
# EgeSüt ERP

Süt sığırcılığı işletmesi için offline-first yönetim paneli.

## Hızlı Başlangıç

1. `index.html`'i tarayıcıda açın
2. Supabase bağlantısı otomatik kurulur

## Proje Yapısı

| Dosya | Açıklama |
|-------|---------|
| `js/config.js` | Sabitler (hekimler, hastalıklar, padoklar) |
| `js/state.js` | Merkezi state (AppState) |
| `js/utils/helpers.js` | DOM yardımcıları, toast, tarih |
| `js/utils/modal.js` | Modal aç/kapat |
| `js/utils/events.js` | Event delegation |
| `js/utils/errorHandler.js` | Hata yönetimi |
| `js/api.js` | Supabase API, IndexedDB, sync |
| `js/app.js` | Uygulama mantığı, init |
| `js/ui.js` | Render fonksiyonları |
| `js/forms.js` | Form submit ve validasyon |
| `supabase/migrations/` | Veritabanı migration'ları |

## Geliştirme

```bash
# Syntax check
for f in js/**/*.js; do node --check "$f" && echo "✓ $f"; done

# ESLint
npx eslint js/
```
```

**Commit:**

```bash
git add README.md
git commit -m "docs: README guncellendi"
```

---

## Test Instructions

```bash
# Debounce/throttle
grep -c "function debounce\|function throttle" js/utils/helpers.js  # 2

# ESLint/Prettier
ls -la .eslintrc.json .prettierrc .eslintignore  # üçü de var mı?

# JSDoc
grep -c "@param\|@returns" js/ui.js js/app.js js/api.js  # > 5

# README
wc -l README.md  # arttı mı?
```
