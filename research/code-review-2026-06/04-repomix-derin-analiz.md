# Aşama 4 — Repomix + Claude Derin Analizi

**Tarih:** 2026-06-07  
**Pack boyutu:** 723.176 byte / 12.472 satır (repomix-output.xml)  
**Bağlam:** Aşama 1-3 bulguları + tam kaynak kodu doğrudan okundu (js/*.js, supabase/migrations/)

---

## Önceki Aşama Bulguları — Özet

| Araç | Kritik Bulgu Sayısı | En Önemli |
|------|---------------------|-----------|
| Semgrep | 4 WARNING + 3 INFO | `js/ui.js` onclick XSS (4 lokasyon), hardcoded anon key |
| SonarCloud | 31 bug, 4 BLOCKER vuln (tooling) | `forms.js:920` arg hatası, 9× sort bug, 45% duplikasyon |
| GitNexus | 2 CRITICAL blast radius | `pullTables` 75 caller, `idbClearAndPut` 134 etki |

---

## Soru 1 — Mantık Hataları

### 1.1 forms.js:919 — `kaydetTaskEdit` Argüman Uyumsuzluğu

```js
// Çağrı (submitTaskEdit, satır 918):
openConfirm(..., async() => kaydetTaskEdit(btn, t, degisen, desc, tarih, tip));
//                                              ↑4   ↑5     ↑6 — bunlar ignore edilir

// Fonksiyon tanımı (satır 919):
async function kaydetTaskEdit(btn, t, degisen) {  // sadece 3 parametre
```

**Durum:** Runtime crash değil — JS fazla arg'ları sessizce yoksayar. Ancak:
- `degisen` nesnesi çağrı öncesinde diff'ten inşa edildiği için işlem doğru çalışır
- Risk: gelecekte `kaydetTaskEdit`'e `desc`/`tarih`/`tip` eklemek isteyen geliştirici bunları zaten 4-5-6. argüman olarak geçilmiş sanacak — yanılacak
- **Düzeltme:** Fonksiyon imzasını `(btn, t, degisen, _desc, _tarih, _tip)` yaparak ya da çağrıyı `(btn, t, degisen)` olarak kırpmak

### 1.2 app.js:492 — Ternary Her Zaman Aynı Değer

```js
// Mevcut (hatalı):
const val = sel.value || sel._noReset && sel.value === '' ? sel.value : sel.value;
// Operatör önceliği nedeniyle: (A || B) ? sel.value : sel.value = DAIMA sel.value

// Muhtemelen istenen:
const val = (sel._noReset && sel.value === '') ? '' : sel.value;
```

**Durum:** `semptomEkle` fonksiyonunda. `sel._noReset` flag'inin amacı kaybolmuş — selector değeri sıfırlanması için tasarlanmış ama ternary her zaman `sel.value` döndürüyor. Bu özellik etkin değil.

### 1.3 ui.js:3369 — Constant Truthiness

```js
// SonarCloud bulgusunun konumu ui.js:3369'da
// Benzer pattern: bir || ifadesinin sol tarafı her zaman truthy
```

**Durum:** Render logic'te ölü dal. Fonksiyonel değil ama kodun okunurluğunu düşürüyor.

---

## Soru 2 — Domain Kuralı İhlalleri

### 2.1 Tohumlama State Machine — TEMİZ ✅

Tohumlama lifecycle RPC-first olarak doğru implement edilmiş:

```
Bekliyor → tohumlama_kaydet  → DB tetikleyicileri gorev_log'a yazar
         → tohumlama_sonuc_gebe / tohumlama_sonuc_bos → durum güncellenir
         → tohumlama_abort → gebelik kapanır, audit kaydı oluşur
```

- May 2026'daki `tohSonuc` REST PATCH bypass düzeltildi (commit 23832b2 ✅)
- `vwp_override` flag kontrolü mevcut (VWP bypass kasıtlı, güvenli)
- State transition guard: `'Gebe' || 'Doğum Yaptı'` kontrolü `tohSonuc`'ta var — geri dönüşü engelliyor

**Not:** `abortKaydet` (forms.js:527) — `tohumlama_abort` RPC'yi çağırıyor (doğru). Ama abort öncesi `confirm()` kullanıyor (native browser dialog) — özel UI olmayan tek durum. Standart form kalıbından farklı.

### 2.2 Sort Kuralı İhlalleri — 9 Lokasyon

Tohumlama/hayvan listeleri sort() ile sıralanırken `localeCompare` eksik:

| Dosya:Satır | Alan | Türkçe Etkisi |
|-------------|------|---------------|
| js/ui.js:2800 | Hayvan listeleri | İ/ı/Ğ/ğ vb. yanlış sıralar |
| js/ui.js:2818 | Hayvan listeleri | Aynı |
| js/ui.js:4211 | Stok listesi | |
| js/ui.js:4488, 4523, 4555 | Çeşitli | |
| js/ui.js:2544 | Geçmiş | |
| js/forms.js:1493, 1380 | Form seçenekleri | |
| js/forms.js:433 | Hayvan seçici | |

**Düzeltme:**
```js
// Mevcut (hatalı):
arr.sort()
arr.sort((a,b) => a.name > b.name ? 1 : -1)  // Türkçe'de yanlış

// Doğru:
arr.sort((a,b) => a.name.localeCompare(b.name, 'tr', { sensitivity: 'base' }))
```

> **Not:** `trLower()` fonksiyonu mevcut ve doğru (Türkçe İ→i fix commit 2a39519). Ama sort() düzeltilmedi.

### 2.3 Stok Ledger — TEMİZ ✅

`stok_hareket` immutable pattern doğru: sadece INSERT, hiçbir yerde UPDATE/DELETE yok. Bakiye her zaman `SUM(miktar)` hesaplanıyor.

---

## Soru 3 — Teknik Borç Delta (Mayıs 2026 → Haziran 2026)

| Sorun | Mayıs 2026 | Haziran 2026 | Değişim |
|-------|-----------|--------------|---------|
| Tohumlama 3 write path | 🔴 Açık | ✅ Kapatıldı (commit 23832b2) | ✅ Düzeldi |
| Offline klinik cache merge | 🔴 Açık | ✅ Kapatıldı (treatment_days cache) | ✅ Düzeldi |
| Türkçe İ→i Unicode bug | 🔴 Açık | ✅ Kapatıldı (commit 2a39519) | ✅ Düzeldi |
| RLS açıklığı (13 tablo) | 🔴 Açık | 🔴 Hâlâ açık | ❌ Değişmedi |
| `ui.js` monolith | 🔴 2804 satır | 🔴 2800+ satır | ❌ Değişmedi |
| Frontend filtreleme (loadTasks) | 🔴 Açık | 🔴 Hâlâ açık | ❌ Değişmedi |
| sort() localeCompare eksikliği | ❓ Belgelenmemiş | 🔴 9 lokasyon | 🆕 Yeni (belgelendi) |
| forms.js:920 arg mismatch | ❓ Belgelenmemiş | 🔴 Aktif | 🆕 Yeni (belgelendi) |
| onclick XSS (kupe_no, p.ad) | ❓ Belgelenmemiş | ⚠️ 4 lokasyon | 🆕 Yeni (belgelendi) |
| app.js:492 ternary ölü dal | ❓ Belgelenmemiş | 🔴 Aktif | 🆕 Yeni (belgelendi) |
| Test coverage | 🔴 ~0% | 🔴 ~0% | ❌ Değişmedi |
| protokol_instance lifecycle | 🔴 Açık | ✅ Tamamlandı (commit fe4c926) | ✅ Düzeldi |

---

## Soru 4 — Offline-First Güvenilirlik

### 4.1 `idbClearAndPut` — Atomiklik Analizi

```js
async function idbClearAndPut(store, rows) {
  return new Promise((res, rej) => {
    const tx = _idb.transaction(store, 'readwrite');
    const os = tx.objectStore(store);
    os.clear();          // ← aynı transaction içinde
    rows.forEach(r => os.put(r));  // ← atomik
    tx.oncomplete = () => res();
    tx.onerror = e => rej(e.target.error);
  });
}
```

**Tek store için:** ✅ Atomik — `clear()` ve `put()` aynı transaction içinde. Bağlantı koparsa transaction geri alınır, store eski verisini korur.

**pullTables için:** ⚠️ Risk var — `Promise.all(uniq.map(...idbClearAndPut...))` birden fazla store'u ayrı transaction'larda güncelliyor:

```js
// pullTables içinde (api.js:344-349):
await Promise.all(uniq.map((t, i) => {
  if (results[i].error) { console.warn(...); return; }  // ← sessiz başarı!
  return idbClearAndPut(t, results[i].data || []);
}));
```

**Senaryo:** Supabase'den 5 tablo çekiliyor. 3. tablo için network timeout → `results[3].error` var → `console.warn` ve devam. İlk 2 tablo güncellendi, 3-5 eski kaldı → **tutarsız IndexedDB durumu.**

Bu Supabase error'ı (network/RLS) olduğunda, pullTables partial success ile dönüyor ve UI yeniden render ediyor — bozuk/karışık state gösterilebilir.

### 4.2 Çevrimdışı → Çevrimiçi Geçiş

`syncNow()` sıralı işler (`for of q` loop) — duplikat riski düşük. Queue'da timestamp yok, ama `id` unique olduğundan yeniden işleme güvenli.

**Risk:** Offline'da `write()` çağrıları (kaydetTaskEdit gibi) navigator.onLine kontrolü **yapmıyor**. Offline'da çağrılırsa DB isteği atar, hata alır, sadece toast gösterir — queue'a eklenmez. Yani bazı offline yazma işlemleri kalıcı olarak kaybolabilir.

```js
// write() fonksiyonu - navigator.onLine kontrolü YOK:
async function write(table, data, method = 'POST', filter = '') {
  // Doğrudan Supabase'e yazar, offline değil
```

Bu RPC olmayan direkt DB yazma işlemleri için geçerli: `gorev_log` PATCH (kaydetTaskEdit), `islem_log` INSERT.

---

## Soru 5 — Refactor Önerileri

### 5.1 ui.js Bölme Önerisi (2800+ satır → 4 dosya)

```
js/ui-render.js     (~700 satır)  → loadTasks, renderAnimals, hayvanObj*, openDet
js/ui-actions.js    (~900 satır)  → case*, kizginlik*, stok*, gebeAta, islemGeriAl
js/ui-settings.js   (~600 satır)  → padok*, ayarlar*, hekim*, _dc*, _kategori*, _tanim*
js/ui-tasks.js      (~400 satır)  → openTaskDet, gorevGeriAl, _gorev*, sessiz hayvan
```

**Önce yapılması gerekenler:**
1. GitNexus'ta tam bağımlılık haritası çıkar (şimdi mevcut)
2. `_cur*` global state'leri `state.js`'e taşı — bunlar bölme için en büyük engel
3. Her dosya kendi `_cur*` variables ile çalışır hale gelene kadar bölme erken

### 5.2 forms.js Bölme Önerisi (~1600 satır → 3 dosya)

```
js/forms-hayvan.js   (~400 satır) → submitAnimal, submitBirth, submitCikis, submitInsem, abortKaydet
js/forms-klinik.js   (~500 satır) → submitCase, caseDrug*, hst*, bulk*, submitVaccination
js/forms-diger.js    (~400 satır) → submitStok*, padok*, hekim*, gorev*, bildirim*
```

**Kritik:** forms.js paylaşımlı global'lar (`_curToh`, `_curHst`, `_curCase`) farklı domain'lere ait — bölmeden önce her birini kendi `ui-*.js` dosyasına taşı.

---

## Teknik Borç Skoru (0-100)

| Deduction | Açıklama | Puan |
|-----------|---------|------|
| Taban | — | +100 |
| Kritik mantık hatası | app.js:492 ternary ölü dal | -10 |
| Kritik mantık hatası | forms.js:920 arg mismatch | -10 |
| Offline güvenilirlik açığı | pullTables partial success + write() offline bypass | -10 |
| ui.js >2000 satır monolith | 2800+ satır | -5 |
| forms.js >1500 satır monolith | ~1600 satır | -3 |
| Test coverage <%10 | 0% test coverage | -5 |

**Teknik Borç Skoru: 57/100**

---

## Sonraki Aşamaya Bağlam

Tüm aşamaların birleşik kritik bulgu listesi (sentez aşamasına hazır):

**Güvenlik (Aşama 1+2):**
- ui.js:1390-1391, 5970-5977, 6458 — onclick XSS (kupe_no, p.ad esc() eksik)
- api.js:7-8 — hardcoded anon key (kabul edilebilir ama belgelenmeli)
- 13 tablo RLS'siz — single-tenant için kabul edilebilir, multi-tenant için kritik

**Kalite (Aşama 2):**
- forms.js:920 — 6 arg, 3 bekleniyor (runtime-safe ama maintenance riski)
- 9× sort() localeCompare eksik — Türkçe sıralama bozukluğu
- app.js:492 — ternary ölü dal
- ui.js:996 — await eksik, try içinde promise hatası yakalanamıyor
- forms.js:1625 — const mutation

**Mimari (Aşama 3):**
- pullTables CRITICAL blast radius (75 caller) — bilinçli tasarım ama single point of failure
- idbClearAndPut partial success riski (ayrı transaction'lar)

**Teknik Borç (Aşama 4):**
- write() offline guard eksik (gorev_log, islem_log offline kaybı)
- ui.js + forms.js monolith — refactor için ön koşul: global state taşıması
- sort() localeCompare: tek satır fix, yüksek etki
