# pullTables Offline Güvenilirlik — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `pullTables` fonksiyonunda partial success riskini ortadan kaldır — herhangi bir tablo Supabase'den çekilemediğinde IndexedDB tutarsız durumda kalmasın.

**Architecture:** `pullTables` şu an `Promise.all` ile tüm tabloları paralel çekiyor. Herhangi bir tabloda `results[i].error` varsa `console.warn` edip devam ediyor — bu IndexedDB'yi kısmen güncel, kısmen eski bırakıyor. Fix: hataları topla, tüm idbClearAndPut'lar bittikten sonra hata varsa kullanıcıya toast + throw et. Caller'ların büyük çoğunluğu zaten `.catch(console.warn)` veya try/catch içinde — throw propagation güvenli.

**Tech Stack:** Vanilla JS, IndexedDB, Supabase JS SDK

**Bağımlılık:** Bu plan, quick-fixes planından SONRA uygulanmalı. Daha yüksek blast radius (75 caller) — dikkatli test gerektirir.

---

## ⚠️ Önce Oku

`pullTables` CRITICAL blast radius taşıyor: **75 doğrudan caller, 53 execution flow**. Bu fonksiyona dokunmadan önce:

1. `gitnexus_impact({target: "pullTables", direction: "upstream"})` çalıştır
2. CRITICAL/HIGH risk uyarısı gelirse kullanıcıyı bildir

---

## Dosya Haritası

- Modify: `js/api.js:304-352` (pullTables fonksiyonu — error handling)

---

## Task 1: pullTables — Partial Fail → Toast + Throw

**Files:**
- Modify: `js/api.js` (pullTables içindeki Promise.all bloğu)

**Mevcut kod (api.js ~344-352):**
```js
await Promise.all(uniq.map((t, i) => {
  if (results[i].error) {
    console.warn(`⚠️ pullTables ${t}: ${results[i].error.message}`);
    return Promise.resolve();  // ← sessizce devam, IndexedDB tutarsız kalabilir
  }
  return idbClearAndPut(t, results[i].data || []);
}));
```

- [ ] **Step 1: gitnexus impact analizi çalıştır**

```js
// MCP tool çağrısı:
mcp__gitnexus__impact({ target: "pullTables", direction: "upstream" })
```

Çıktıda risk level'i not et. HIGH veya CRITICAL ise kullanıcıya bildir, onay al.

- [ ] **Step 2: Caller listesini ast_grep ile gözden geçir**

```js
// pullTables çağrılarını bul:
mcp__tools_bank__ast_grep_search({ pattern: "pullTables($$$)", lang: "javascript", path: "js/", max_results: 30 })
```

Çıktıda `.catch` olmayan çağrıları işaretle — bunlar Task 2'nin hedefi.

`.catch(console.warn)` olmayan caller'ları bul. Bunlar throw'dan etkilenecek — toast görecekler ama crash olmayacak (UI async handler'da try/catch var genelde).

- [ ] **Step 3: pullTables'a hata toplama ve throw ekle**

`api.js`'te şu bloğu bul:
```js
await Promise.all(uniq.map((t, i) => {
  if (results[i].error) {
    console.warn(`⚠️ pullTables ${t}: ${results[i].error.message}`);
    return Promise.resolve();
  }
  return idbClearAndPut(t, results[i].data || []);
}));
```

Şuna değiştir:
```js
const pullErrors = [];
await Promise.all(uniq.map((t, i) => {
  if (results[i].error) {
    console.warn(`⚠️ pullTables ${t}: ${results[i].error.message}`);
    pullErrors.push(t);
    return Promise.resolve();  // idbClearAndPut atla — stale data koru
  }
  return idbClearAndPut(t, results[i].data || []);
}));
if (pullErrors.length) {
  const msg = `Veri senkronizasyon hatası: ${pullErrors.join(', ')}`;
  toast(msg, true);
  throw new Error(msg);
}
```

**Neden bu yaklaşım:**
- Hata olan tablolar için idbClearAndPut yapılmıyor → IDB'de eski (ama tutarlı) data kalıyor
- Hata olmayan tablolar güncelleniyor
- `throw` caller'a propagate olur:
  - `.catch(console.warn)` olanlar: sadece console log, UI etkilenmez
  - `try/catch` olanlar: catch bloğu devreye girer
  - Bare `await pullTables(...)` olanlar: unhandled rejection → Sentry/console

- [ ] **Step 4: Doğrula — network hata simülasyonu**

Browser DevTools → Network tab → "Offline" moduna geç:

```js
// Console'da pullTables'ı tetikle:
pullTables(['hayvanlar', 'gorev_log'])
  .then(() => console.log('✅ başarı'))
  .catch(e => console.log('❌ hata (beklenen):', e.message))
```

Beklenen davranış offline:
1. Supabase çağrısı başarısız → results[i].error dolu
2. `pullErrors` = ['hayvanlar', 'gorev_log']
3. Toast görünür: "Veri senkronizasyon hatası: hayvanlar, gorev_log"
4. Promise reject oluyor
5. IDB değişmemiş (eski data korundu)

Online'a geri geç → normal çalışması kontrol et.

- [ ] **Step 5: Caller uyumluluğunu kontrol et**

```js
// await pullTables — .catch olmayan:
mcp__tools_bank__ast_grep_search({ pattern: "await pullTables($$$)", lang: "javascript", path: "js/", max_results: 20 })
```

ast_grep çıktısında `.catch` veya try/catch içinde olmayan satırları listele → bunlar Task 2 hedefi.

Eğer bare `await pullTables(...)` olan caller try/catch içinde değilse, o caller'a `.catch(e => toast(e.message, true))` ekle veya try/catch içine al.

- [ ] **Step 6: Commit öncesi — detect changes**

```js
mcp__gitnexus__detect_changes()
```

Beklenen: sadece `pullTables` fonksiyonu. CRITICAL blast radius nedeniyle beklenmedik sembol çıkarsa kullanıcıya bildir.

- [ ] **Step 7: Commit**

```bash
git add js/api.js
git commit -m "fix: pullTables partial fail → hata toast + throw, IDB tutarlılığı korunuyor"
```

---

## Task 2: pullTables Caller Audit (gerekirse)

Task 1, Step 5'te bulunan bare caller'lara .catch ekle.

**Files:**
- Modify: ilgili JS dosyaları (Task 1 Step 5 çıktısına göre)

- [ ] **Step 1: Her bare caller için .catch ekle**

Örnek pattern:
```js
// ÖNCE (bare await, try/catch dışında):
await pullTables(['hayvanlar']);

// SONRA:
await pullTables(['hayvanlar']).catch(e => console.warn('pull failed:', e.message));
```

Sadece Task 1 Step 5'in çıktısındaki satırları değiştir.

- [ ] **Step 2: Doğrula**

Offline modda uygulama genel akışını test et:
1. Bir hayvan detayını aç
2. Offline moda geç
3. Herhangi bir mutasyon dene (kaydetmeyi dene)
4. Toast "Veri senkronizasyon hatası" görünmeli
5. Uygulama crash etmemeli — eski data gösteriyor olmalı

- [ ] **Step 3: Commit öncesi — detect changes**

```js
mcp__gitnexus__detect_changes()
```

- [ ] **Step 4: Commit (eğer değişiklik yapıldıysa)**

```bash
git add js/ui.js js/forms.js js/app.js  # hangisi değiştiyse
git commit -m "fix: pullTables caller'larına catch eklendi (partial fail propagation)"
```

---

## Tamamlama

- [ ] **Final push**
```bash
git push origin fix/big-analysis-2026-06-08
```

- [ ] **gitnexus detect changes**
```js
mcp__gitnexus__detect_changes()
```
Beklenen: sadece `pullTables` ve etkilenen caller'lar değişmiş görünmeli.
