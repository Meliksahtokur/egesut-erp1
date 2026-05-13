# Detaylı Nihai Review — İnsan Onayı Gereken Planlar

**Tarih:** 2026-05-13
**Kapsam:** Plan 1 Task 3, Plan 5 Task 1

---

## Plan 1 Task 3: State Migration — Keşfedilen Eksikler

### Bulgu 1: `app.js:81` Plan'dakinden ÇOK DAHA FAZLA global var

```js
// app.js:81 — GERÇEK DURUM:
let _A = [], _S = [], _curStk = null, _curPg = 'dash';
let _suruFilter = 'tumuu', _suruSiralama = 'kupe';
let _curUremeTab = 'kizginlik', _curGecmisFilter = 'hepsi', _curTaskFilter = 'today';
let _curTaskDet  = null, _curHst = null, _curToh = null;
let _curBildirimTab = 'bekliyor';
```

**Plan'daki hata:** Plan sadece `_A`, `_S`, `_taskKategori`, `_stokTab`, `_curStokDet` diyor. Ama 13 global değişken var!

**Düzeltilecek:** Tüm bu değişkenler state'e taşınmalı:

| Global | state key | Mevcut mu? |
|--------|-----------|------------|
| `_A` | `animals` | ✅ Zaten var |
| `_S` | `stock` | ✅ Zaten var |
| `_curStk` | `curStok` | ❌ Eksik |
| `_curPg` | `currentPage` | ✅ Zaten var |
| `_suruFilter` | `suruFilter` | ❌ Eksik |
| `_suruSiralama` | `suruSiralama` | ❌ Eksik |
| `_curUremeTab` | `currentUremeTab` | ✅ Zaten var |
| `_curGecmisFilter` | `currentHistoryFilter` | ✅ Zaten var |
| `_curTaskFilter` | `currentTaskFilter` | ✅ Zaten var |
| `_curTaskDet` | `currentTaskDetail` | ✅ Zaten var |
| `_curHst` | `currentDisease` | ✅ Zaten var |
| `_curToh` | `currentInsem` | ✅ Zaten var |
| `_curBildirimTab` | `currentNotificationTab` | ✅ Zaten var |

**Aksiyon:** Plan 1 Task 3 Step 1'e `curStok`, `suruFilter`, `suruSiralama` ekle.

---

### Bulgu 2: `_gebeIds` ARRAY, `_hastaIds` SET — farklı tipler

```js
// ui.js:469 — ARRAY:
_gebeIds = [...new Set(gebeTohs.map(t => t.hayvan_id))];

// ui.js:474 — SET:
_hastaIds = new Set(hastaLogs.map(d => d.animal_id));
```

Kullanım:
```js
new Set(_gebeIds || []).has(id)  // Her kullanımda Set'e çeviriliyor
_hastaIds.has(id)                 // Direkt Set.has() kullanılıyor
```

**Plan'daki hata:** Plan her ikisini de `new Set()` olarak state'e koyuyor. `gebeIds` ARRAY olarak saklanmalı.

**Düzeltilecek:**
```js
// state.js:
gebeIds: [],        // ARRAY (kullanırken new Set() sarılır)
hastaIds: new Set(), // SET (direkt .has() ile kullanılır)
```

---

### Bulgu 3: `globalThis._appState` direkt manipülasyonu

```js
// ui.js:476:
globalThis._appState = globalThis._appState || {};
globalThis._appState.hayvanlar = _A;

// ui.js:1480:
globalThis._appState = globalThis._appState || {};
globalThis._appState.stok = _S;
```

**Plan'daki hata:** Bu satırlardan hiç bahsedilmemiş.

**Düzeltilecek:** Bu iki satır `setState('animals', _A)` ve `setState('stock', _S)` zaten çağrıldıktan hemen sonra. `globalThis._appState` satırları SİLİNEBİLİR — `setState` zaten aynı işi yapıyor.

---

### Bulgu 4: Kod zaten hibrit — `setState` kısmen kullanılıyor

```js
// ui.js:466-467:
_A = await getData('hayvanlar', ...);
if (typeof setState === 'function') setState('animals', _A);
```

Bu pattern korunmalı. Plan'daki "her referansı değiştir" yaklaşımı doğru ama `if (typeof setState)` kontrolüyle güvenli yapılmalı.

---

## Plan 5 Task 1: Event Delegation — Keşfedilen Eksikler

### Bulgu 5: 212 değil, ~150 unique handler var

Tam sayım: ~150 benzersiz onclick/oninput/onchange/onfocus/onkeydown handler. Plan'daki handler map'i eksik.

**Eksik handler grupları:**

| Grup | Sayı | Örnek |
|------|------|-------|
| Modal submit | 12 | `submitBirth`, `submitInsem`, `submitCase`, `submitAnimal`, `submitStk`, `submitTaskAdd`... |
| Modal close | 8 | `closeM('m-birth')`, `closeM('m-insem')`... |
| mClose pattern | 18 | `mClose(event,this)` — event + element |
| Stok panel | 6 | `stokHareketiTemizle()`, `kuyrukuTemizle()`... |
| Ayarlar panel | 8 | `ayarlarHekimEkle()`, `ayarlarPadokKaydet()`... |
| Hekim panel | 7 | `hekimDetKaydet()`, `hekimPeriod(30,event)`... |
| Padok panel | 6 | `padokDuzenleKaydet()`, `padokTopluTasi()`... |
| Detay/Task panel | 10 | `asiUygulaVeTamamla()`, `gorevGeriAl()`... |
| Bulk işlemler | 12 | `bulkTabSwitch('bv','padok')`, `submitBulkVaccination()`... |
| Inline style | 5 | `document.getElementById(...).style.display='none'` |
| onfocus/onkeydown | 12 | `acHayvan(...)`, `acNav(event,...)`, `srchDropdown()` |
| onchange | 10 | `animalFormGuncelle()`, `onSpermaSelect(this)`... |

**Plan'daki hata:** Plan sadece ~30 handler map'liyor, geri kalan 120+ handler "..." ile atlanmış.

---

### Bulgu 6: `mClose(event, this)` — event objesi GEREKLİ

```html
<div onclick="mClose(event,this)">...</div>
```

Bu pattern'de hem `event` (tıklamanın hedefi kontrol için) hem `this` (kapatılacak modal elementi) gerekiyor.

Plan'daki `data-action="close-modal"` yaklaşımı eksik — event objesi delegate listener'dan alınabilir ama `this` (element) `el` parametresiyle zaten geliyor:

```js
// data-action ile:
<div data-action="m-close">...</div>

// Handler:
registerAction('m-close', (el, e) => {
  if (e.target === el) el.classList.remove('on');
  // veya parent modal'ı bulup kapat
  const modal = el.closest('.modal');
  if (modal) modal.classList.remove('on');
});
```

---

### Bulgu 7: Inline JavaScript — fonksiyona dönüştürülmeli

```html
<!-- Bu tarz inline kodlar: -->
onclick="document.getElementById('ay-hekim-form').style.display='none'"
onclick="this.style.display='none';document.getElementById('b-anne-manual').style.display='block'"
```

**Düzeltilecek:** Bunlar için ayrı handler fonksiyonları yazılmalı:

```js
registerAction('hide-ay-hekim-form', () => {
  g('ay-hekim-form').style.display = 'none';
});

registerAction('show-anne-manual', (el) => {
  el.style.display = 'none';
  g('b-anne-manual').style.display = 'block';
});
```

---

## ÖZET: Plana Eklenecekler

### Plan 1 Task 3 için:
1. `app.js:81`'deki 13 global değişkenin TAM listesini state'e ekle
2. `_gebeIds` → ARRAY olarak sakla (`gebeIds: []`), `_hastaIds` → SET (`hastaIds: new Set()`)
3. `globalThis._appState` satırlarını SIL (zaten setState var)
4. `if (typeof setState === 'function')` pattern'ini koru

### Plan 5 Task 1 için:
5. Handler listesini 150 handler'ı kapsayacak şekilde GENİŞLET
6. `mClose(event, this)` → el.closest('.modal') pattern'ine dönüştür
7. Inline JavaScript kodları → registerAction handler'larına dönüştür
8. `onfocus`/`onkeydown` → data-action-event="focus" / "keydown" ile yönet
9. `onchange` → data-action-event="change" ile yönet
