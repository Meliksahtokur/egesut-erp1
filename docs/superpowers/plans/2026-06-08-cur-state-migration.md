# _cur* Global State Migration → state.js — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `app.js` içinde `let` ile tanımlı cross-file `_cur*` global değişkenleri `state.js`'deki `AppState`'e taşı; tüm okuma/yazma işlemlerini `getState()`/`setState()` üzerinden yap. Bu değişiklik `forms.js` ve `ui.js` domain split'inin ön koşuludur.

**Architecture:** `state.js` zaten `AppState._state` içinde bu key'leri tanımlıyor — ama kod hâlâ `let _curUremeTab = ...` gibi script-global `let` değişkenler üzerinden çalışıyor. Yapılacak iş: `app.js`'ten tanımları sil, her dosyada okumaları `getState('key')` ve yazmaları `setState('key', val)` ile değiştir. `ui.js`'e özgü (cross-file olmayan) `_curStokDet`, `_curCase`, `_curDayId`, `_curHekimDet`, `_curPadokDet`, `_curTaskVaccineId` bu plana dahil değil — `ui.js` split sırasında ayrıca ele alınacak.

**Tech Stack:** Vanilla JS, AppState (js/state.js), getState/setState helpers

---

## Araçlar

Executor bu araçları kullanmalı:
- `ast_grep_search(pattern, lang, path, max_results)` — her değişkenin tüm kullanımlarını bul
- `gitnexus_impact(target, direction)` — değişiklik öncesi blast radius kontrolü
- `memory_search(query)` — domain kuralları ve state yönetimi için

---

## Değişken Haritası

| Eski `let` var (app.js) | state.js key | Notlar |
|------------------------|-------------|--------|
| `_curUremeTab` | `currentUremeTab` | state.js'de zaten var |
| `_curGecmisFilter` | `currentHistoryFilter` | state.js'de zaten var |
| `_curTaskFilter` | `currentTaskFilter` | state.js'de zaten var |
| `_gecmisTumu` | `gecmisTumu` | **Eksik — Task 1'de eklenecek** |
| `_tanimlarTab` | `tanimlarTab` | **Eksik — Task 1'de eklenecek** |
| `_curTaskDet` | `currentTaskDetail` | state.js'de zaten var |
| `_curHst` | `currentDisease` | state.js'de zaten var |
| `_curToh` | `currentInsem` | state.js'de zaten var |
| `_curBildirimTab` | `currentNotificationTab` | state.js'de zaten var |

**Kapsam dışı (ui.js-local, bu plana dahil değil):**
- `_curStokDet`, `_curCase`, `_curDayId`, `_curHekimDet`, `_curPadokDet`, `_curTaskVaccineId`

---

## Dosya Haritası

- Modify: `js/state.js` — `gecmisTumu`, `tanimlarTab` key ekle
- Modify: `js/app.js:57-60` — `let` tanımları sil
- Modify: `js/ui.js` — tüm cross-file `_cur*` okuma/yazma → getState/setState
- Modify: `js/forms.js` — tüm cross-file `_cur*` okuma/yazma → getState/setState
- Modify: `js/utils/handlers.js` — `_curTaskDet` okuma/yazma → getState/setState

---

## Task 1: state.js'e eksik key'leri ekle

**Files:**
- Modify: `js/state.js:6-22`

- [ ] **Step 1: state.js'i oku**

`js/state.js` dosyasını oku. `_state` objesinin sonunu bul (şu an `hastaIds: new Set()` en son).

- [ ] **Step 2: İki eksik key ekle**

`hastaIds: new Set(),` satırından sonrasına şunu ekle:

```js
      gecmisTumu: false,             // _gecmisTumu
      tanimlarTab: 'hastaliklar',    // _tanimlarTab
```

- [ ] **Step 3: Commit**

```bash
git add js/state.js
git commit -m "feat: state.js — gecmisTumu + tanimlarTab key eklendi"
```

---

## Task 2: Basit değişkenleri migrate et (_curUremeTab, _curGecmisFilter, _curBildirimTab)

**Files:**
- Modify: `js/ui.js`
- Modify: `js/forms.js`

- [ ] **Step 1: Blast radius kontrolü**

```
// gitnexus_impact({ target: "_curUremeTab", direction: "upstream" })
// gitnexus_impact({ target: "_curGecmisFilter", direction: "upstream" })
// Beklenen: LOW — bu var'lar sadece UI tab seçim state'i
```

- [ ] **Step 2: Tüm kullanımları say**

```
// ast_grep_search(pattern="_curUremeTab", lang="javascript", path="js", max_results=20)
// ast_grep_search(pattern="_curGecmisFilter", lang="javascript", path="js", max_results=10)
// ast_grep_search(pattern="_curBildirimTab", lang="javascript", path="js", max_results=10)
```

- [ ] **Step 3: ui.js — _curUremeTab yazmaları**

`js/ui.js` dosyasında şu 2 satırı bul ve güncelle:

```js
// BEFORE (iki ayrı satır, farklı fonksiyonlarda — her ikisini de değiştir):
  _curUremeTab=tab;

// AFTER:
  setState('currentUremeTab', tab);
```

`replace_all: true` kullan — `ui.js` içinde sadece bu pattern geçiyor.

- [ ] **Step 4: ui.js — _curGecmisFilter yazması**

```js
// BEFORE (ui.js ~2401):
  _curGecmisFilter=f;

// AFTER:
  setState('currentHistoryFilter', f);
```

- [ ] **Step 5: forms.js — _curUremeTab okuma**

`forms.js` içinde `window._curUremeTab` ile iki okuma var:

```js
// BEFORE:
      if (typeof loadUreme === 'function' && window._curUremeTab === 'kizginlik') {
// AFTER:
      if (typeof loadUreme === 'function' && getState('currentUremeTab') === 'kizginlik') {
```

```js
// BEFORE:
      if (typeof loadUreme === 'function' && window._curUremeTab === 'tohumlama') {
// AFTER:
      if (typeof loadUreme === 'function' && getState('currentUremeTab') === 'tohumlama') {
```

- [ ] **Step 6: _curBildirimTab kullanımlarını bul ve güncelle**

```
// ast_grep_search(pattern="_curBildirimTab", lang="javascript", path="js", max_results=10)
```

Bulunan her okuma → `getState('currentNotificationTab')`, her yazma → `setState('currentNotificationTab', val)`.

- [ ] **Step 7: Commit**

```bash
git add js/ui.js js/forms.js
git commit -m "refactor: _curUremeTab/_curGecmisFilter/_curBildirimTab → getState/setState (OV5 step 1)"
```

---

## Task 3: _curTaskFilter migrate et (14 kullanım)

**Files:**
- Modify: `js/app.js`
- Modify: `js/ui.js`
- Modify: `js/forms.js`

- [ ] **Step 1: Tüm kullanımları listele**

```
// ast_grep_search(pattern="_curTaskFilter", lang="javascript", path="js", max_results=20)
// 14 match bekleniyor: app.js ~3, ui.js ~9, forms.js ~2
```

- [ ] **Step 2: ui.js — _curTaskFilter tek yazma**

```js
// BEFORE (ui.js ~400):
  _curTaskFilter=f;

// AFTER:
  setState('currentTaskFilter', f);
```

- [ ] **Step 3: ui.js — _curTaskFilter okumaları**

```
// ast_grep_search(pattern="_curTaskFilter", lang="javascript", path="js/ui.js", max_results=20)
```

Her okuma için `_curTaskFilter` → `getState('currentTaskFilter')`. `replace_all: true` kullan.
**Önemli:** Step 2'de yazma `setState(...)` olarak değiştirildi — `replace_all` artık sadece kalan okumaları etkiler, yanlışlıkla `setState(...)` içini bozmaz çünkü `setState` içinde `_curTaskFilter` geçmiyor.

**Edit:** `_curTaskFilter` → `getState('currentTaskFilter')` (`replace_all: true`, sadece ui.js)

- [ ] **Step 4: forms.js — _curTaskFilter okumaları**

```
// ast_grep_search(pattern="_curTaskFilter", lang="javascript", path="js/forms.js", max_results=10)
```

Bulunan her yerde `_curTaskFilter` → `getState('currentTaskFilter')`. `replace_all: true` kullan.

- [ ] **Step 5: app.js — _curTaskFilter okumaları**

```
// ast_grep_search(pattern="_curTaskFilter", lang="javascript", path="js/app.js", max_results=10)
```

Bulunan her yerde `_curTaskFilter` → `getState('currentTaskFilter')`. `replace_all: true` kullan.

**NOT:** Başlangıç değerini belirleyen `let _curTaskFilter = 'today'` satırı — bu Task 6'da silinecek.

- [ ] **Step 6: Commit**

```bash
git add js/app.js js/ui.js js/forms.js
git commit -m "refactor: _curTaskFilter → getState/setState (OV5 step 2)"
```

---

## Task 4: _curHst + _curToh migrate et (33 kullanım)

**Files:**
- Modify: `js/forms.js`
- Modify: `js/ui.js`

- [ ] **Step 1: Tüm kullanımları say**

```
// ast_grep_search(pattern="_curHst", lang="javascript", path="js", max_results=25)
// → 23 match: çoğu forms.js, 1 app.js (tanım)
// ast_grep_search(pattern="_curToh", lang="javascript", path="js", max_results=15)
// → 10 match: forms.js, ui.js, app.js (tanım)
```

- [ ] **Step 2: forms.js — _curHst okumaları ve yazmaları ayır**

**Yazmalar** (değişken atama): `_curHst = ...` → `setState('currentDisease', ...)` — bunları elle bul ve değiştir (birden fazla değer var).

**Okumalar** (değişken kullanım): `_curHst` → `getState('currentDisease')` — `replace_all: true` ile forms.js'te tüm basit okumaları değiştir. (Önce yazmaları tamamla, sonra okumaları yap.)

- [ ] **Step 3: forms.js — _curToh okumaları ve yazmaları**

**Yazmalar**: `_curToh = ...` → `setState('currentInsem', ...)` — elle bul ve değiştir.

**Okumalar**: `_curToh` → `getState('currentInsem')` — `replace_all: true`.

- [ ] **Step 4: ui.js — _curToh yazması**

```
// ast_grep_search(pattern="_curToh", lang="javascript", path="js/ui.js", max_results=5)
```

Bulunan yazma: `_curToh=t;` → `setState('currentInsem', t);`

- [ ] **Step 5: Commit**

```bash
git add js/forms.js js/ui.js
git commit -m "refactor: _curHst/_curToh → getState/setState (OV5 step 3)"
```

---

## Task 5: _curTaskDet migrate et (31 kullanım — en karmaşık)

**Files:**
- Modify: `js/forms.js`
- Modify: `js/ui.js`
- Modify: `js/utils/handlers.js`

- [ ] **Step 1: Tüm kullanımları listele**

```
// ast_grep_search(pattern="_curTaskDet", lang="javascript", path="js", max_results=35)
// → 31 match: ui.js ~20, forms.js ~5, handlers.js ~3, app.js ~1 (tanım)
```

- [ ] **Step 2: handlers.js — _curTaskDet güncelle**

```
// ast_grep_search(pattern="_curTaskDet", lang="javascript", path="js/utils/handlers.js")
// → 3 match bekleniyor
```

Her biri için:
- Okuma: `_curTaskDet` → `getState('currentTaskDetail')`
- Yazma: `_curTaskDet = ...` → `setState('currentTaskDetail', ...)`

- [ ] **Step 3: forms.js — _curTaskDet güncelle**

```
// ast_grep_search(pattern="_curTaskDet", lang="javascript", path="js/forms.js")
```

Özellikle dikkat et: `forms.js:937` → `_curTaskDet={...t,...degisen};` → `setState('currentTaskDetail', {...t,...degisen});`

Kalan okumaları `replace_all: true` ile değiştir.

- [ ] **Step 4: ui.js — _curTaskDet yazmalar (elle, ~5 satır)**

```
// ast_grep_search(pattern="_curTaskDet=$$$", lang="javascript", path="js/ui.js")
```

Bulunan her atama: `_curTaskDet = ...` → `setState('currentTaskDetail', ...)`. Her yazma farklı değer içeriyor, elle değiştir.

- [ ] **Step 5: ui.js — _curTaskDet okumalar (replace_all)**

Yazmaları bitirdikten sonra kalan `_curTaskDet` → `getState('currentTaskDetail')` (`replace_all: true`, ui.js).

**Kontrol:** 0 `_curTaskDet` kalmamalı:
```
// ast_grep_search(pattern="_curTaskDet", lang="javascript", path="js/ui.js")
// → 0 match bekleniyor
```

- [ ] **Step 6: Commit**

```bash
git add js/forms.js js/ui.js js/utils/handlers.js
git commit -m "refactor: _curTaskDet → getState/setState (OV5 step 4)"
```

---

## Task 6: app.js tanımları sil + _gecmisTumu/_tanimlarTab tamamla

**Files:**
- Modify: `js/app.js:55-60`

- [ ] **Step 1: _gecmisTumu ve _tanimlarTab kullanımlarını bul**

```
// ast_grep_search(pattern="_gecmisTumu", lang="javascript", path="js", max_results=15)
// ast_grep_search(pattern="_tanimlarTab", lang="javascript", path="js", max_results=10)
```

Bulunan her okuma/yazma için `getState()`/`setState()` ile değiştir (Task 3-5 ile aynı pattern).

- [ ] **Step 2: app.js tanımları sil**

`js/app.js`'te şu 4 satırı sil (yaklaşık 57-60):

```js
let _suruFilter = 'tumuu', _suruSiralama = 'kupe';  // ← KALIR (ui.js-local)
let _curUremeTab = 'kizginlik', _curGecmisFilter = 'hepsi', _curTaskFilter = 'today', _gecmisTumu = false;  // ← SİL
let _tanimlarTab = 'hastaliklar';  // ← SİL
let _curTaskDet  = null, _curHst = null, _curToh = null;  // ← SİL
let _curBildirimTab = 'bekliyor';  // ← SİL
```

**UYARI:** `_suruFilter` ve `_suruSiralama` kalacak — bunlar state.js'de yok, kapsam dışı.

- [ ] **Step 3: Hiç `_cur*` referansı kalmadığını doğrula**

```
// ast_grep_search(pattern="_curUremeTab", lang="javascript", path="js")  → 0 match
// ast_grep_search(pattern="_curGecmisFilter", lang="javascript", path="js")  → 0 match
// ast_grep_search(pattern="_curTaskFilter", lang="javascript", path="js")  → 0 match
// ast_grep_search(pattern="_curTaskDet", lang="javascript", path="js")  → 0 match
// ast_grep_search(pattern="_curHst", lang="javascript", path="js")  → 0 match
// ast_grep_search(pattern="_curToh", lang="javascript", path="js")  → 0 match
// ast_grep_search(pattern="_curBildirimTab", lang="javascript", path="js")  → 0 match
```

- [ ] **Step 4: Browser testini açıkla**

`index.html`'yi tarayıcıda aç (veya local server). Şu akışları test et:
- Görevler tab'ı → görev detay modal açılıyor mu?
- Üreme tab'ı → kızgınlık/tohumlama sekme geçişi çalışıyor mu?
- Geçmiş filtresi değişiyor mu?
- Bildirimler tab'ı çalışıyor mu?

- [ ] **Step 5: detect_changes + commit**

```bash
# gitnexus_detect_changes()
git add js/app.js js/state.js js/ui.js js/forms.js js/utils/handlers.js
git commit -m "refactor: _cur* global vars → state.js getState/setState — forms.js split zemin hazır (OV5)"
```
