# Egesut UI — Bug Fix & UX İyileştirme Spec
Tarih: 2026-05-09  
Kapsam: Kritik buglar → veri bütünlüğü → UX polish  
Format: Tamamlananları `[x]` yap, ilerle.

---

## BÖLÜM 1 — Kritik Buglar

### 1.1 openDet() Race Condition ✅
**Dosya:** `js/ui.js` ~652  
**Fix:** `_detOpenId` guard eklendi — hızlı geçişte yanlış veri render olmaz.

- [x] `openDet()` başında `_detOpenId = id` set et
- [x] `pullTables([...])` await'le, sonra `if (_detOpenId !== id) return;` guard koy
- [x] Tüm tab render satırlarına aynı guard'ı ekle
- [x] `pullTables()` çağrısına `.catch(e => toast('Veri yüklenemedi', true))` ekle

---

### 1.2 openAnimalEdit() Form State Pollution ✅
**Dosya:** `js/ui.js` ~770-817  
**Fix:** setTimeout zinciri kaldırıldı, async/await yapıldı. Max tarih set ediliyor.

- [x] `openAnimalEdit(a)` → `async function openAnimalEdit(a)`
- [x] `setTimeout` bloklarını `await`'li ardışık satırlara dönüştür
- [x] Modal açılırken önce tüm alanları temizle (`clearAnimalForm()` veya benzeri)
- [x] Submit butonu modal hazır olmadan disable tut, hazır olunca enable et

---

### 1.3 `_TH` Lazy Init — Hayvan Autocomplete Patlar ✅
**Dosya:** `js/ui.js` / `js/forms.js`  
**Fix:** Line 2783 gereksiz guard kaldırıldı; `_eligibleHayvanlar()` fallback'i zaten vardı.

- [x] `_TH` init kodunu `loadData()` veya `initApp()` içine taşı
- [x] `acHayvan()` başına `if (!_TH || !_TH.length) _TH = _A || [];` guard ekle
- [x] Tüm `acHayvan()` çağıran modalları doğrula — hepsinde çalışıyor mu test et

---

### 1.4 Optimistic Update — Yanlış Başarı Toast'u ✅
**Dosya:** `js/api.js`  
**Fix:** Toast artık RPC başarıyla dönünce gösteriliyor.

- [x] `rpcOptimistic()` içinde toast'u `await rpc(...)` sonrasına taşı
- [x] Hata durumunda `toast('Kaydedilemedi: ' + e.message, true)` göster
- [x] UI optimistic update'i yine de anında yap (hız için), ama toast beklesin

---

## BÖLÜM 2 — Veri Bütünlüğü

### 2.1 Gebelik Durumu Tek Kaynaktan ✅
**Dosya:** `js/ui.js`  
**Fix:** `_gebeIds` artık sadece `tohumlama.sonuc==='Gebe'`'den build ediliyor. `a.durum==='Gebe'` kontrolü tüm yerlerden kaldırıldı. `gebeledenSec()` ve `loadUreme()` fonksiyonlarındaki `extra` listesi de silindi.

- [x] Tüm gebelik badge/chip renderlarında `_gebeIds.has(a.id)` kullan, `a.durum === 'Gebe'` kontrolünü kaldır
- [x] `_gebeIds` set'i sadece `tohumlama.sonuc === 'Gebe'` olanlardan build et
- [x] `filterA()` ve `openDet()` chip/badge hesaplamalarını kontrol et

---

### 2.2 Stale Filter — Sayfa Dönüşünde Filter Sıfırlanmıyor ✅
**Dosya:** `js/ui.js`, `js/app.js`  
**Fix:** `fchipReset()` fonksiyonu eklendi. `goTo('suru')` çağrısında reset tetikleniyor.

- [x] `fchipReset()` fonksiyonu yaz — `_fchip` reset + buton state temizle
- [x] `goTo('suru')` içinde `fchipReset()` çağır
- [x] `filterA()` başında `getState('animals') || []` null guard zaten mevcut

---

### 2.3 Kızgınlık 90-Gün Hesabı Hatalı ✅
**Dosya:** `js/ui.js` loadDash()  
**Fix:** `muayeneGerekli` filtresi artık `_gebeIds`'i kontrol ediyor — zaten tekrar gebe olan anneler listeden çıkarılıyor.

- [x] `muayeneGerekli` hesaplarken: `gebeSet90.has(b.anne_id)` kontrolü eklendi
- [x] Yorum satırı düzeltildi (`/ 90-day` → `// 90-day`)

---

### 2.4 Stok Negatife Düşebilir ✅
**Dosya:** `js/forms.js`  
**Fix:** Submit butonu disable/enable ile çift tıklama önlendi.

- [x] `submitBulkVaccination()` başında submit butonunu disable et
- [x] `finally` bloğunda enable et

---

## BÖLÜM 3 — UX Polish

### 3.1 openDet() Skeleton Loader ✅
**Dosya:** `js/ui.js` + `index.html`  
**Fix:** `.skel` CSS shimmer animasyonu eklendi. `openDet()` başında 4 satır skeleton HTML `tab-ozet`'e inject ediliyor.

- [x] `index.html`'e `.skel` CSS + `@keyframes shimmer` eklendi
- [x] `openDet()` başında skeleton HTML koyuldu
- [x] Veri yüklenince gerçek içerik replace ediyor (mevcut mekanizma)

---

### 3.2 Türkçe Hata Mesajları ✅
**Dosya:** `js/api.js`  
**Fix:** `_ERR_MAP` + `_trErr()` eklendi. `rpc()`, `dbUpdate()`, `dbInsert()` hepsinde kullanılıyor.

- [x] `_ERR_MAP` array'i eklendi (row-level security, duplicate key, foreign key, not null, network...)
- [x] `_trErr()` helper ile tüm DB hataları Türkçe'ye çevriliyor

---

### 3.3 Silme / Çıkarma Onay Modali ✅
**Dosya:** `js/ui.js`, `index.html`  
**Fix:** `#m-confirm` modal + `openConfirm()` eklendi. `detayIptal()` ve `gebeAta()` dönüştürüldü.

- [x] `#m-confirm` modal eklendi (başlık + açıklama + İptal/Onayla)
- [x] `openConfirm(title, desc, onConfirm)` helper yazıldı
- [x] `detayIptal()` ve `gebeAta()` openConfirm ile sarıldı

---

### 3.4 Task Badge Live Update ✅
**Dosya:** `js/ui.js`  
**Fix:** `updateTaskBadge()` yazıldı. `doneTask()` ve `detayIptal()` içinde anında çağrılıyor.

- [x] `updateTaskBadge()` fonksiyonu eklendi (IDB'den geciken görev sayısı, tbadge güncelle)
- [x] Task tamamlama/iptal sonrası anında çağrılıyor

---

### 3.5 Tohumlama Sonuç Modalı — 3 Buton → Radio + Kaydet ✅
**Dosya:** `js/ui.js`, `js/forms.js`, `index.html`  
**Fix:** Bekliyor durumunda 3 buton → radio + Kaydet. `tohSonucKaydet()` eklendi.

- [x] `#m-toh-det` modalında `td2-sonuc-btns` → `td2-sonuc-radios` (radio + Kaydet/İptal)
- [x] `openTohDet()` güncellendi — mevcut sonuç radio'ya işaretleniyor
- [x] `tohSonucKaydet()` fonksiyonu eklendi

---

### 3.6 Autocomplete Dropdown Kapanmıyor ✅
Zaten `closest()` kullanılıyordu — değişiklik gerekmedi.

---

### 3.7 Edit Modalda Gelecek Tarih Girişi ✅
Bölüm 1'de yapıldı (`openAnimalEdit()` async/await düzeltmesinde).

---

## Tamamlananlar Özeti
Bu satırı güncelleriz ilerledikçe.

Kritik: 4/4 ✅ · Veri: 4/4 ✅ · UX: 7/7 ✅ — TAMAMLANDI
