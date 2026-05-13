# Aşama 2 — Veri Yönetimi İyileştirmeleri

> **REQUIRED SUB-SKILL:** Use the executing-plans skill to implement.
> **Bağımlılık:** Aşama 1 tamamlanmadan başlanmasın (state, helpers, utils taşınmış olmalı).

**Goal:** `write()` → `insertOffline`/`updateOffline`, sync motoru exponential backoff, IndexedDB index'leri, RPC optimistic update.

**Architecture:** `api.js`'deki `write()` bölünür, `syncNow` retry mantığı eklenir, `openDB`'ye index'ler gelir, `rpcOptimistic` local state'i RPC dönüşüyle günceller.

**Tech Stack:** Vanilla JS, IndexedDB

---

### Task 1: `write()` → `insertOffline()` + `updateOffline()`

**Files:** Modify: `js/api.js`

**Step 1: insertOffline + updateOffline fonksiyonlarını yaz**

```js
async function insertOffline(table, data) {
  const db = await openDB();
  const tx = db.transaction(['offline_queue'], 'readwrite');
  const store = tx.objectStore('offline_queue');
  await store.put({
    id: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
    method: 'POST',
    table,
    data,
    createdAt: new Date().toISOString(),
    retryCount: 0
  });
  // Local'e de ekle
  await idbPut(table, data);
}

async function updateOffline(table, id, changes) {
  const db = await openDB();
  const tx = db.transaction(['offline_queue'], 'readwrite');
  const store = tx.objectStore('offline_queue');
  await store.put({
    id: Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
    method: 'PATCH',
    table,
    data: changes,
    filter: { id },
    createdAt: new Date().toISOString(),
    retryCount: 0
  });
  // Local'i de güncelle
  await idbPut(table, { id, ...changes });
}
```

**Step 2: Eski `write()` çağrılarını değiştir**

```bash
grep -n "write(" js/ui.js js/forms.js js/app.js
```

Her çağrıyı uygun fonksiyonla değiştir:
- INSERT → `insertOffline(table, data)`
- UPDATE → `updateOffline(table, id, changes)`

**Step 3: Commit**

---

### Task 2: Sync Motoru — Exponential Backoff

**Files:** Modify: `js/api.js` (syncNow fonksiyonu)

**Step 1: Retry mantığı ekle**

```js
async function syncNow() {
  const db = await openDB();
  const tx = db.transaction(['offline_queue'], 'readonly');
  const items = await tx.objectStore('offline_queue').getAll();
  if (!items.length) return { synced: 0, failed: 0 };

  let synced = 0, failed = 0;
  const MAX_RETRIES = 5;

  for (const item of items) {
    if (item.retryCount >= MAX_RETRIES) {
      failed++;
      continue;
    }

    try {
      if (item.method === 'POST') {
        await supabase.from(item.table).insert(item.data);
      } else if (item.method === 'PATCH') {
        await supabase.from(item.table).update(item.data).eq('id', item.filter.id);
      }
      await removeFromQueue(item.id);
      synced++;
    } catch (err) {
      failed++;
      const retryCount = (item.retryCount || 0) + 1;
      if (retryCount < MAX_RETRIES) {
        // exponential backoff: 2^retryCount saniye sonra tekrar dene
        const delay = Math.min(Math.pow(2, retryCount) * 1000, 60000);
        setTimeout(() => syncNow(), delay);
      }
      // Update retry count in queue
      const tx2 = db.transaction(['offline_queue'], 'readwrite');
      const store2 = tx2.objectStore('offline_queue');
      const existing = await store2.get(item.id);
      if (existing) {
        existing.retryCount = retryCount;
        existing.lastAttempt = new Date().toISOString();
        await store2.put(existing);
      }
    }
  }

  updateSyncBar();
  return { synced, failed };
}
```

**Step 2: Commit**

---

### Task 3: IndexedDB Index'leri

**Files:** Modify: `js/api.js` (openDB fonksiyonu)

**Step 1: openDB'ye index ekle**

```js
// openDB içinde, createObjectStore'lara ekle:
// gorev_log store'u için:
store.createIndex('hayvan_id_idx', 'hayvan_id', { unique: false });
store.createIndex('tamamlandi_idx', 'tamamlandi', { unique: false });

// tohumlama store'u için:
store.createIndex('hayvan_id_idx', 'hayvan_id', { unique: false });

// dogum store'u için:
store.createIndex('hayvan_id_idx', 'hayvan_id', { unique: false });
```

**Step 2: getData'da index kullanımı**

```js
// Filtreleme için index kullan
if (filter && filter.hayvan_id) {
  const idx = store.index('hayvan_id_idx');
  return idx.getAll(filter.hayvan_id);
}
```

**Step 3: Commit**

---

### Task 4: RPC Optimistic Update

**Files:** Modify: `js/api.js` (rpcOptimistic fonksiyonu)

**Step 1: rpcOptimistic — dönen sonucu local state'e yaz**

```js
async function rpcOptimistic(fnName, params, { localUpdate, successToast, errorToast } = {}) {
  try {
    const result = await rpc(fnName, params);
    if (result.ok && localUpdate) {
      localUpdate(result); // RPC dönüşünü local state'e uygula
    }
    if (result.ok && successToast) toast(successToast);
    if (!result.ok && errorToast) toast(errorToast, true);
    return result;
  } catch (err) {
    if (errorToast) toast(errorToast, true);
    throw err;
  }
}

// Kullanım örneği (tohumlama kaydet):
await rpcOptimistic('tohumlama_kaydet', params, {
  localUpdate: (result) => setState('tohumlamalar', [...getState('tohumlamalar'), result.data]),
  successToast: 'Tohumlama kaydedildi'
});
```

**Step 2: Commit**

---

## Test Instructions

```bash
# insertOffline/updateOffline tanimli mi?
grep -c "function insertOffline\|function updateOffline" js/api.js  # 2

# syncNow retryCount kontrol ediyor mu?
grep -c "retryCount" js/api.js  # > 2

# IndexedDB index'leri eklendi mi?
grep -c "createIndex" js/api.js  # >= 3
```
