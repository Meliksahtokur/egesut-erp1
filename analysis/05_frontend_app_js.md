# Frontend Analiz Raporu: app.js

**Dosya:** `/root/egesut-erp1/js/app.js`  
**Tarih:** 2026-04-17  
**Analist:** WORKER_FRONTEND_1

---

## 1. Code Organization

| Öncelik | Bulgu |
|---------|-------|
| YÜKSEK | Genel dosya boyutu: **766 satır** — modüler yapıya geçiş gerekli |
| ORTA | Mantıksal bölümleme mevcut (SABİT VERİLER, GLOBAL STATE, ROUTING vb.) ancak dosyalara ayrılmalı |

### Detay

- **Öncelik: ORTA — app.js:1-766**
- **Sorun:** ~2800 satırlık ui.js ile birlikte bu dosya monolitik yapıda. Tek dosyada ~20+ farklı sorumluluk alanı var: routing, state, hayvan formu, sperma, hastalık, hekim ayarları, tarih yardımcıları, sync bar, init.
- **Çözüm önerisi:** Dosya ayrımı:
  - `app-init.js` → init(), event listeners, load lifecycle
  - `app-routing.js` → goTo(), renderFromLocal()
  - `app-hayvan-form.js` → animalFormGuncelle(), animalGrupDegisti()
  - `app-sperma.js` → spermaModStok(), buildSpermaList()
  - `app-hastalik.js` → filterHastalikList(), acDisease(), semptom sistemi
  - `app-sync.js` → updateSyncBar(), background sync
  - `app-ayar.js` → hekim/sperma ekle/sil

---

## 2. State Management

| Öncelik | Bulgu |
|---------|-------|
| KRITIK | `_A`, `_S`, `_curStk`, `_curPg` global değişkenler — getState/setState dışında |
| KRITIK | `_disFreq`, `_ilacCache`, `_diseasesCache` — açık cache değişkenleri yönetilmiyor |
| YÜKSEK | `_customHekimler`, `_customSperma` — memory only, page refresh'te kayboluyor |

### Detay

- **Öncelik: KRITIK — app.js:53-61**
- **Sorun:** Global mutable state (`let _A = [], _S = [], _curStk = null, _curPg = 'dash'`) doğrudan erişiliyor. `getState()` wrapper kullanılmıyor.
- **Çözüm önerisi:**
  ```javascript
  // Mevcut (YANLIŞ)
  _A.push(newAnimal);
  
  // Önerilen
  setState('animals', [...getState('animals'), newAnimal]);
  ```

- **Öncelik: KRITIK — app.js:44-49**
- **Sorun:** `_diseasesCache` IndexedDB'den okunuyor ama `loadDiseasesDropdown()` her modal açılışında çağrılıyor. Cache invalidation yok.
- **Çözüm önerisi:** Cache expiry: `if (_diseasesCache.length && !isExpired(_cacheTs, 5*60*1000))`

- **Öncelik: YÜKSEK — app.js:36-38**
- **Sorun:** `_customHekimler` ve `_customSperma` sadece memory'de tutuluyor. Online'da RPC ile yazılsa da refresh'te kayboluyor.
- **Çözüm önerisi:** `idbSet('customHekimler', ...)` ve app load'ta `idbGetAll('customHekimler')` ile sync

---

## 3. Function Complexity

| Öncelik | Bulgu |
|---------|-------|
| KRITIK | `openM()` — ~30 satır, 4 farklı modal tipi, çoklu sorumluluk |
| KRITIK | `loadHekimler()` — async race condition riski |
| KRITIK | `loadDiseasesDropdown()` — her çağrılışta IDB okuması |
| YÜKSEK | `animalFormGuncelle()` — ~90 satır, derin if/else zinciri |
| YÜKSEK | `goTo()` — 8 ayrı page case'i, her biri farklı data çekiyor |
| YÜKSEK | `renderFromLocal()` — `goTo()` ile neredeyse aynı logic |

### Detay

- **Öncelik: KRITIK — app.js:104-127**
- **Sorun:** `openM(id)` fonksiyonu hem modal açma, hem tarih setleme, hem form reset, hem async DB fetch yapıyor. Single Responsibility ihlali.
- **Çözüm önerisi:**
  ```javascript
  function openM(id) {
    _openModal(id);
    if (id === 'm-animal') _initAnimalModal();
    else if (id === 'm-insem') _initInsemModal();
    else if (id === 'm-disease') _initDiseaseModal();
  }
  ```

- **Öncelik: YÜKSEK — app.js:218-269**
- **Sorun:** `animalFormGuncelle()` 90+ satır, iç içe `if/else if` zinciri 6 seviye. Okunabilirlik çok düşük.
- **Çözüm önerisi:** Yaş→Grup mapping'i ayrı fonksiyona:
  ```javascript
  function _getGruplarForYas(cinsiyet, yasGun, dogumAbortVar, tohumlanmis) { ... }
  ```

- **Öncelik: YÜKSEK — app.js:145-162**
- **Sorun:** `goTo()` ve `renderFromLocal()` neredeyse identik — sadece `await` farkı var. Kod tekrarı.
- **Çözüm önerisi:** Tek `renderPage(pg)` fonksiyonu, `goTo()` sadece state güncellesin.

---

## 4. Naming Conventions

| Öncelik | Bulgu |
|---------|-------|
| ORTA | Karışık naming: `_A`, `_S` (kısaltmalar) vs `loadHekimler` (TAM) |
| ORTA | `hde*` prefix'i — ne olduğu belli değil |
| DÜŞÜK | `_suruFilter`, `_suruSiralama` — sürü odaklı ancak global state |

### Detay

- **Öncelik: ORTA — app.js:53**
- **Sorun:** `_A`, `_S` — anlaşılmaz kısaltmalar. Kod okuyan yeni developer bunları tahmin edemez.
- **Çözüm önerisi:**
  ```javascript
  // Mevcut
  let _A = [], _S = [];
  
  // Önerilen
  let _animals = [], _stock = [];
  ```

- **Öncelik: ORTA — app.js:371+**
- **Sorun:** `hdeSmptomEkle()`, `hdeSelTani()`, `hdeUpdateSmptDropdown()` — `hde` ne anlama geliyor? "Hastalık Düzenleme" ise `hastalikDuzenle*` olmalı.
- **Çözüm önerisi:** `hde` → `hastalikDuzenle` veya `hastalikEdit*`

- **Öncelik: DÜŞÜK — app.js:57-58**
- **Sorun:** `_suruFilter`, `_suruSiralama` — "sürü" Türkçe. Takım İngilizce adopt etmeye çalışırken tutarsızlık.
- **Çözüm önerisi:** `_herdFilter`, `_herdSort` veya `suru` kalsa bile consistency için tümü Türkçe olmalı.

---

## 5. Dead Code

| Öncelik | Bulgu |
|---------|-------|
| YÜKSEK | `updateBildirimBadge()` — boş fonksiyon, comment: "Sprint 3" |
| YÜSEK | `loadBildirimler()` — boş async fonksiyon |
| ORTA | `showDebug()` — sadece `console.warn` wrapper, nereye kullanılıyor? |
| ORTA | `_disFreq` — atanıyor ama hiç kullanılmıyor (`buildDiseaseFreq()` boş) |
| ORTA | `_ilacCache` — tanımlanmış ama kullanılmıyor |
| DÜŞÜK | `buildDiseaseFreq()` — boş fonksiyon, hastalik_log reference |

### Detay

- **Öncelik: YÜKSEK — app.js:205**
- **Sorun:**
  ```javascript
  function updateBildirimBadge() { /* Sprint 3 — bildirim modülü */ }
  async function loadBildirimler() { /* Sprint 3 — bildirim modülü */ }
  ```
  İki boş fonksiyon. `goTo('bildirim')` çağrıldığında hiçbir şey yapmıyor.
- **Çözüm önerisi:** Sprint 3 backlog'a taşı veya implement et. Boş fonksiyon bırakma.

- **Öncelik: ORTA — app.js:132**
- **Sorun:**
  ```javascript
  function showDebug(msg) { console.warn('[debug]', msg); }
  ```
  Arama sonucu: Hiçbir yerde kullanılmıyor.
- **Çözüm önerisi:** Kaldır veya JSDoc ile açıkla.

- **Öncelik: ORTA — app.js:46-47**
- **Sorun:**
  ```javascript
  let _disFreq = {};
  let _ilacCache = [];
  ```
  `_ilacCache` hiç kullanılmıyor. `_disFreq` sadece `buildDiseaseFreq()`'de sıfırlanıyor ama değer kullanılmıyor.
- **Çözüm önerisi:** Kullanılmayan değişkenleri kaldır.

---

## 6. Performance Bottlenecks

| Öncelik | Bulgu |
|---------|-------|
| KRITIK | `loadIrkDropdown()` — her animal modal açılışında DB RPC çağrısı |
| KRITIK | `spermaModStok()` — her çağrılışta `loadStock()` yapabilir |
| YÜKSEK | `animalFormGuncelle()` — her çağrılışta IDB 2 sorgu (`tohumlama`, `dogum`) |
| YÜKSEK | `acHayvan()` fetch — `tohumlanabilir_hayvanlar` her insem modalda tekrar çekiliyor |
| ORTA | `loadHekimler()` — `populateHekimSelects()` senkron çağrılıyor, race condition |

### Detay

- **Öncelik: KRITIK — app.js:293-314**
- **Sorun:** `loadIrkDropdown()` her modal açılışında `db.rpc('irk_listesi')` çağrıyor. DB RPC latency ~100-300ms. Sık modal açılıp kapanıyorsa UX kötü.
- **Çözüm önerisi:**
  ```javascript
  let _irkCache = null, _irkCacheTs = 0;
  async function loadIrkDropdown() {
    if (_irkCache && Date.now() - _irkCacheTs < 300000) { /* use cache */ return; }
    // ... fetch
    _irkCache = result;
    _irkCacheTs = Date.now();
  }
  ```

- **Öncelik: KRITIK — app.js:237-264**
- **Sorun:** `spermaModStok()` içinde:
  ```javascript
  if (!getState('stock') || !getState('stock').length) await loadStock();
  ```
  Her sperma modal açılışında stock yoksa fetch ediyor. Sürü sayfası zaten stock yüklemiş olabilir ama `renderFromLocal()` her page'de çağrılıyor.
- **Çözüm önerisi:** Stock cache'i app-level'da tutulmalı, `spermaModStok()` sadece filter yapsın.

- **Öncelik: YÜKSEK — app.js:111-120**
- **Sorun:** Insem modal'da `_TH` (tohumlanabilir hayvanlar) her modal açılışında tekrar fetch ediliyor. 100-500ms DB çağrısı.
- **Çözüm önerisi:** `_TH`'yi app init'te bir kez yükle, background refresh yap.

- **Öncelik: YÜKSEK — app.js:218-247**
- **Sorun:** `animalFormGuncelle()` edit modunda her seferinde IDB'den `tohumlama` ve `dogum` tablolarını komple çekiyor. Yüzlerce kayıt olabilir.
- **Çözüm önerisi:**
  ```javascript
  // Sadece ilgili hayvanın kayıtlarını çek
  const tohumlar = await idbGet('tohumlama', editId);
  const dogumlar = await idbGet('dogum', editId);
  ```

---

## Özet Tablo

| # | Kategori | Kritik | Yüksek | Orta | Düşük |
|---|----------|--------|--------|------|-------|
| 1 | Code Organization | 0 | 1 | 1 | 0 |
| 2 | State Management | 2 | 1 | 0 | 0 |
| 3 | Function Complexity | 3 | 3 | 0 | 0 |
| 4 | Naming Conventions | 0 | 0 | 2 | 1 |
| 5 | Dead Code | 0 | 3 | 3 | 1 |
| 6 | Performance Bottlenecks | 2 | 2 | 1 | 0 |
| **Toplam** | | **7** | **10** | **7** | **2** |

## Öncelikli Düzeltmeler (1-3 sprint)

1. **[KRITIK]** `openM()` → ayrı modal init fonksiyonlarına böl
2. **[KRITIK]** `_A`, `_S` → `getState()`/`setState()` wrapper kullan
3. **[YÜKSEK]** `animalFormGuncelle()` → yaş-grup mapping ayrı fonksiyona
4. **[YÜKSEK]** Boş fonksiyonları kaldır: `showDebug()`, `updateBildirimBadge()`
5. **[YÜKSEK]** `loadIrkDropdown()` → cache ekle
6. **[ORTA]** `hde*` → `hastalikDuzenle*` olarak rename
7. **[ORTA]** `_ilacCache`, `_disFreq` → kaldır veya kullan
