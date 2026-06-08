# write() Offline Guard — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** `forms.js` içindeki tek doğrudan `db.from('islem_log').insert()` çağrısını `write()` ile değiştirerek offline sırasında kayıt kaybını önle.

**Architecture:** `write()` fonksiyonu (api.js) halihazırda `navigator.onLine` kontrolü yapıyor ve offline'da `_queue`'ya ekliyor. `kaydetTaskEdit` içindeki `db.from('islem_log').insert()` bu path'i bypass ediyor — sadece bu çağrıyı `write()` ile sar. `ui_logs` (app.js) intentional fire-and-forget telemetri, kapsam dışı.

**Tech Stack:** Vanilla JS, Supabase JS SDK, IndexedDB queue

---

## Araçlar

Executor bu araçları kullanmalı:
- `ast_grep_search(pattern, lang, path)` — direkt db.from çağrılarını bul
- `gitnexus_impact(target, direction)` — değişiklik öncesi blast radius kontrolü
- `memory_search(query)` — domain kuralları için

---

## Dosya Haritası

- Modify: `js/forms.js` (~satır 924) — `db.from('islem_log').insert()` → `write('islem_log', {...})`

---

## Task 1: islem_log direct DB çağrısını write() ile değiştir

**Files:**
- Modify: `js/forms.js:920-940`

- [x] **Step 1: Blast radius kontrolü**

```javascript
// Executor: gitnexus_impact çalıştır
// gitnexus_impact({ target: "kaydetTaskEdit", direction: "upstream", file_path: "js/forms.js" })
// LOW risk bekleniyor (sadece submitTaskEdit → openConfirm zinciri)
```

- [x] **Step 2: Mevcut kodu doğrula**

```bash
# Executor: ast_grep_search ile konumu bul
# ast_grep_search(pattern="db.from($$$).insert($$$)", lang="javascript", path="js/forms.js")
```

Beklenen çıktı — `forms.js` içinde 1 match: `db.from('islem_log').insert({...})` (kaydetTaskEdit içinde, try/catch ile sarılı)

- [x] **Step 3: forms.js'i oku**

`js/forms.js` dosyasını `offset=920, limit=25` ile oku. Şu kodu bul:

```js
try {
  await db.from('islem_log').insert({
    ana_hayvan_id: t.hayvan_id||null,
    islem_tipi: 'gorev_duzenle',
    islem_detay: JSON.stringify({gorev_id:t.id,...degisen}),
    tarih: new Date().toISOString(),
    kullanici: null, kaynak: 'MANUEL'
  });
} catch(_){}
```

- [x] **Step 4: Değişikliği uygula**

`old_string` → `new_string` ile değiştir:

```js
// OLD:
    try {
      await db.from('islem_log').insert({
        ana_hayvan_id: t.hayvan_id||null,
        islem_tipi: 'gorev_duzenle',
        islem_detay: JSON.stringify({gorev_id:t.id,...degisen}),
        tarih: new Date().toISOString(),
        kullanici: null, kaynak: 'MANUEL'
      });
    } catch(_){}
```

```js
// NEW:
    await write('islem_log', {
      id: crypto.randomUUID(),
      ana_hayvan_id: t.hayvan_id || null,
      islem_tipi: 'gorev_duzenle',
      islem_detay: JSON.stringify({ gorev_id: t.id, ...degisen }),
      tarih: new Date().toISOString(),
      kullanici: null,
      kaynak: 'MANUEL'
    }).catch(() => {});
```

**Neden `.catch(() => {})`:** `islem_log` audit kaydı — DB hatası ana işlemi durdurmamalı. Offline durumda `write()` zaten queue'ya ekler, `.catch` sadece gerçek DB hataları için.

- [x] **Step 5: Doğrula — artık db.from doğrudan çağrı yok**

```bash
# ast_grep_search(pattern="db.from($$$).insert($$$)", lang="javascript", path="js/forms.js")
# Beklenen: 0 match (forms.js temiz)
```

- [x] **Step 6: Değişiklik kapsamını kontrol et**

```bash
# gitnexus_detect_changes() çalıştır — sadece forms.js:kaydetTaskEdit etkilenmeli
```

- [x] **Step 7: Commit**

```bash
git add js/forms.js
git commit -m "fix: islem_log audit write() ile offline-safe hale getirildi (OV2)"
```
