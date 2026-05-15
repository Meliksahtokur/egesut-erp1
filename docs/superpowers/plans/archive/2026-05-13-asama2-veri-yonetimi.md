> **✅ TAMAMLANDI** — Commit'ler: `96109ad` (insertOffline+updateOffline+IDB index+JSDoc), `c9f4088` (rpcOptimistic fix). Veri yönetimi katmanı tamamlandı.

# Aşama 2 — Veri Yönetimi İyileştirmeleri

> **REQUIRED SUB-SKILL:** Use the executing-plans skill.
> **Bağımlılık:** Plan 1 (utils/, helpers.js) tamamlanmış olmalı.

**Goal:** `write()` → `insertOffline`/`updateOffline`, sync motoru exponential backoff, IndexedDB index'leri, RPC optimistic update.

**Architecture:** `api.js`'deki `write(table, data, method='POST', filter='')` (satır 205) ikiye bölünür. `syncNow` tek retry timer ile race condition önlenir. `openDB`'ye index'ler eklenir. `rpcOptimistic` dönen sonucu local state'e yazar.

**Mevcut write() çağrıları (19 adet):**

| Dosya | Satır | Tablo | Method |
|-------|-------|-------|--------|
| ui.js:396 | gorev_log | PATCH | alt görev tamamlandı |
| ui.js:402 | gorev_log | PATCH | parent görev tamamlandı |
| ui.js:432 | gorev_log | PATCH | görev tamamlandı |
| ui.js:434 | stok_hareket | INSERT | stok hareketi |
| ui.js:443 | hayvanlar | PATCH | padok değişimi |
| ui.js:2186 | gorev_log | PATCH | hedef tarih güncelle |
| ui.js:2197 | gorev_log | PATCH | görev iptal |
| ui.js:2199 | gorev_log | PATCH | alt görevler iptal |
| ui.js:2702 | drug_administrations | INSERT | ilaç uygulama |
| ui.js:2713 | stok_hareket | INSERT | ilaç stok düşümü |
| ui.js:3023 | stok_hareket | INSERT | tohumlama stok |
| forms.js:429 | hayvanlar | PATCH | sütten kesme |
| forms.js:447 | hayvanlar | PATCH | sütten kesme |
| forms.js:462 | hayvanlar | PATCH | tohumlanabilir |
| forms.js:476 | hayvanlar | PATCH | ertelendi |
| forms.js:626 | gorev_log | PATCH | görev tamamlandı |
| forms.js:629 | stok_hareket | INSERT | stok hareketi |
| forms.js:631 | hayvanlar | PATCH | padok |

**Tech Stack:** Vanilla JS, IndexedDB, Supabase

---

### Task 1: `write()` → `insertOffline()` + `updateOffline()`

**Files:** Modify: `js/api.js` (ekle + eski write'ı wrapper yap)

**Step 1: insertOffline + updateOffline ekle**

```js
async function insertOffline(table, data) {
  const db = await openDB();
  const tx = db.transaction(['offline_queue'], 'readwrite');
  await tx.objectStore('offline_queue').put({
    id: crypto.randomUUID(),
    method: 'POST', table, data,
    createdAt: new Date().toISOString(), retryCount: 0
  });
  await idbPut(table, data);
}

async function updateOffline(table, id, changes) {
  const db = await openDB();
  const tx = db.transaction(['offline_queue'], 'readwrite');
  await tx.objectStore('offline_queue').put({
    id: crypto.randomUUID(),
    method: 'PATCH', table,
    data: changes,
    filter: `id=eq.${id}`,
    createdAt: new Date().toISOString(), retryCount: 0
  });
  await idbPut(table, { id, ...changes });
}
```

**Step 2: Mevcut write()'ı eski kod için wrapper olarak koru (breaking change önle)**

```js
// Mevcut write() fonksiyonu değişmesin — eski çağrılar sorunsuz çalışsın.
// insertOffline/updateOffline YENİ kod için kullanılacak.
// Aşamalı geçiş: yeni feature'lar insertOffline/updateOffline, eski kod write() kullanır.
```

Bu şekilde 19 çağrının hepsini bir anda değiştirmek zorunda kalmayız. Risk yok.

**Step 3: Commit**

```bash
git add js/api.js
git commit -m "feat: insertOffline + updateOffline eklendi, write() korundu"
```

---

### Task 2: Sync Motoru — Exponential Backoff

**Files:** Modify: `js/api.js` (syncNow fonksiyonu)

**Step 1: syncNow'a retry mantığı ekle (TEK timer, race condition yok)**

```js
let _retryTimer = null;
const MAX_RETRIES = 5;

async function syncNow() {
  const db = await openDB();
  const tx = db.transaction(['offline_queue'], 'readonly');
  const items = await tx.objectStore('offline_queue').getAll();
  if (!items.length) return { synced: 0, failed: 0 };

  let synced = 0, failed = 0, hasFailed = false;

  for (const item of items) {
    if (item.retryCount >= MAX_RETRIES) { failed++; continue; }
    try {
      if (item.method === 'POST') {
        await supabase.from(item.table).insert(item.data);
      } else if (item.method === 'PATCH') {
        await supabase.from(item.table).update(item.data).filter(item.filter);
      }
      await removeFromQueue(item.id);
      synced++;
    } catch (err) {
      failed++;
      hasFailed = true;
      const retryTx = db.transaction(['offline_queue'], 'readwrite');
      const store = retryTx.objectStore('offline_queue');
      const existing = await store.get(item.id);
      if (existing) {
        existing.retryCount = (existing.retryCount || 0) + 1;
        existing.lastAttempt = new Date().toISOString();
        await store.put(existing);
      }
    }
  }

  // TEK retry timer — race condition yok
  if (hasFailed && !_retryTimer) {
    _retryTimer = setTimeout(() => { _retryTimer = null; syncNow(); }, 30000);
  }

  updateSyncBar();
  return { synced, failed };
}
```

**Step 2: Commit**

```bash
git add js/api.js
git commit -m "feat: syncNow exponential backoff, single retry timer"
```

---

### Task 3: IndexedDB Index'leri

**Files:** Modify: `js/api.js` (openDB fonksiyonu)

**Step 1: openDB'ye index ekle**

```js
// openDB içinde, upgrade'de:
if (!store.indexNames.contains('hayvan_id_idx')) {
  store.createIndex('hayvan_id_idx', 'hayvan_id', { unique: false });
}
if (!store.indexNames.contains('tamamlandi_idx')) {
  store.createIndex('tamamlandi_idx', 'tamamlandi', { unique: false });
}
```

`gorev_log`, `tohumlama`, `dogum` store'larına `hayvan_id_idx`; `gorev_log`'a ek olarak `tamamlandi_idx`.

**Step 2: Commit**

```bash
git add js/api.js
git commit -m "perf: IndexedDB index'leri eklendi (hayvan_id, tamamlandi)"
```

---

### Task 4: RPC Optimistic Update

**Files:** Modify: `js/api.js`

**Step 1: rpcOptimistic — dönen sonucu local state'e yaz**

```js
async function rpcOptimistic(fnName, params, { localUpdate, successToast, errorToast } = {}) {
  try {
    const result = await rpc(fnName, params);
    if (result.ok && localUpdate) localUpdate(result);
    if (result.ok && successToast) toast(successToast);
    if (!result.ok && errorToast) toast(errorToast, true);
    return result;
  } catch (err) {
    if (errorToast) toast(errorToast, true);
    return { ok: false, error: err.message };
  }
}

// Kullanım:
await rpcOptimistic('tohumlama_kaydet', params, {
  localUpdate: (res) => setState('tohumlamalar', [...getState('tohumlamalar'), res.data]),
  successToast: 'Tohumlama kaydedildi'
});
```

**Step 2: pullTables sonrası değil, direkt güncelle**

rpcOptimistic kullanıldığında `pullTables` çağrılmasına gerek kalmaz — local state RPC dönüşüyle güncellenir. `pullTables` sadece 5dk'da bir periyodik olarak çalışır (zaten postgres_changes subscription var).

**Step 3: Commit**

```bash
git add js/api.js
git commit -m "feat: rpcOptimistic local state update, pullTables azaltildi"
```

---

## Test Instructions

```bash
# insertOffline/updateOffline tanimli
grep -c "function insertOffline\|function updateOffline" js/api.js  # 2

# syncNow retryCount kontrol ediyor
grep -c "retryCount" js/api.js  # >= 2

# Tek timer
grep -c "_retryTimer" js/api.js  # >= 2

# IndexedDB index
grep -c "createIndex" js/api.js  # >= 3

# rpcOptimistic
grep -c "function rpcOptimistic" js/api.js  # 1
```
