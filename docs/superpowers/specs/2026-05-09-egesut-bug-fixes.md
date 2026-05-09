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

### 3.1 openDet() Skeleton Loader
**Dosya:** `js/ui.js` + `index.html`  
**Sorun:** Hayvan detayı açılınca panel bir an boş görünüyor (veri çekilirken). Kullanıcı dondu sanıyor.  
**Fix:** Veri gelene kadar skeleton placeholder göster.

- [ ] `index.html`'e `.skel` CSS class ekle: `background: linear-gradient(90deg, var(--card2) 25%, var(--card3) 50%, var(--card2) 75%); background-size: 200% 100%; animation: shimmer 1.2s infinite;`
- [ ] `openDet()` başında `det-scroll` içine skeleton HTML koy
- [ ] `pullTables()` tamamlanınca skeleton'ı gerçek içerikle replace et

---

### 3.2 Türkçe Hata Mesajları
**Dosya:** `js/api.js` + `js/forms.js`  
**Sorun:** DB hataları raw olarak toast'a yansıyor: `"[hayvan_ekle] new row violates row-level security policy"` gibi.  
**Fix:** Bilinen hata kodlarını Türkçe'ye map et.

- [ ] `api.js`'de `rpc()` fonksiyonuna hata map'i ekle:
  ```js
  const ERR_MAP = {
    'row-level security': 'Yetkisiz işlem',
    'duplicate key': 'Bu kayıt zaten mevcut',
    'foreign key': 'İlişkili kayıt bulunamadı',
    'not null': 'Zorunlu alan boş bırakıldı',
    'network': 'Sunucuya ulaşılamıyor',
  };
  ```
- [ ] `catch` bloğunda `Object.entries(ERR_MAP).find(([k]) => e.message.includes(k))` ile ara, bulunan Türkçe'yi toast'a yaz

---

### 3.3 Silme / Çıkarma Onay Modali
**Dosya:** `js/ui.js` / `js/forms.js`  
**Sorun:** Hayvan silme, sürüden çıkarma gibi geri dönülemez işlemlerde onay yok. Yanlış tıklamada veri gidiyor.  
**Fix:** Basit konfirm modal.

- [ ] `index.html`'e `#m-confirm` modal ekle: başlık + açıklama + "İptal" / "Onayla" butonları
- [ ] `openConfirm(title, desc, onConfirm)` helper fonksiyon yaz
- [ ] Silme işlemlerini `openConfirm()` ile sar: hayvan sil, sürüden çıkar, vaka kapat

---

### 3.4 Task Badge Live Update
**Dosya:** `js/ui.js`  
**Sorun:** Nav'daki task sayısı yeni task eklendikten sonra güncellenmez, eski sayıyı gösterir.  
**Fix:** Task oluşturma success handler'ında badge'i güncelle.

- [ ] Task oluşturma/tamamlama sonrası `updateTaskBadge()` call et (var mı yok mu kontrol et, yoksa yaz)
- [ ] `updateTaskBadge()`: `getState('tasks').filter(t => t.durum !== 'Tamamlandi').length` say, `#tbadge` text güncelle

---

### 3.5 Tohumlama Sonuç Modalı — 3 Buton → Radio + Kaydet
**Dosya:** `js/ui.js` `openTohDet()`  
**Sorun:** Sonuç değiştirmek için 3 action butonu var (Gebe/Boş/Bekliyor), tıklayınca direkt kaydediyor. Geri yok, yanlış tıklamada hemen değişiyor.  
**Fix:** Radio button + "Kaydet" butonu pattern.

- [ ] `m-toh-det` modalında sonuç seçimini radio button'a çevir (mevcut seçili olanı checked yap)
- [ ] Ayrı "Kaydet" butonu ekle, tıklanınca seçili radio'yu kaydet
- [ ] "İptal" butonu ekle (modalı kapat, değişiklik yapma)

---

### 3.6 Autocomplete Dropdown Kapanmıyor
**Dosya:** `js/ui.js` ~450-452  
**Sorun:** Dropdown item'a tıklayınca `event.target` item olduğu için dropdown açık kalıyor.  
**Fix:** `closest()` ile parent kontrolü.

- [ ] `document.addEventListener('click', ...)` handler'ında:  
  `if (!e.target.closest('#srch') && !e.target.closest('#ac-srch'))` kullan

---

### 3.7 Edit Modalda Gelecek Tarih Girişi
**Dosya:** `js/ui.js` ~776  
**Sorun:** Add modalde `max="bugün"` var ama edit modalde yok, kullanıcı gelecek doğum tarihi girebilir.  
**Fix:** Edit modali açarken `a-dt` inputuna max set et.

- [ ] `openAnimalEdit()` içinde: `document.getElementById('a-dt').max = new Date().toISOString().slice(0,10);`

---

## Tamamlananlar Özeti
Bu satırı güncelleriz ilerledikçe.

Kritik: 4/4 ✅ · Veri: 4/4 ✅ · UX: 0/7
