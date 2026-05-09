# Egesut UI — Bug Fix & UX İyileştirme Spec
Tarih: 2026-05-09  
Kapsam: Kritik buglar → veri bütünlüğü → UX polish  
Format: Tamamlananları `[x]` yap, ilerle.

---

## BÖLÜM 1 — Kritik Buglar

### 1.1 openDet() Race Condition
**Dosya:** `js/ui.js` ~652  
**Sorun:** Kullanıcı hızlı hayvan değiştirirse eski hayvanın verisi yeni hayvanın paneline render oluyor. `pullTables()` await'lenmeden UI temizlenip render başlıyor.  
**Fix:** `pullTables()` tamamlanmadan tab render etme. Aktif hayvan id'yi değişken olarak tut (`let _detOpenId`), pull dönünce hâlâ aynı hayvan açıksa render et, değilse iptal et.

- [ ] `openDet()` başında `_detOpenId = id` set et
- [ ] `pullTables([...])` await'le, sonra `if (_detOpenId !== id) return;` guard koy
- [ ] Tüm tab render satırlarına aynı guard'ı ekle
- [ ] `pullTables()` çağrısına `.catch(e => toast('Veri yüklenemedi', true))` ekle

---

### 1.2 openAnimalEdit() Form State Pollution
**Dosya:** `js/ui.js` ~770-817  
**Sorun:** `setTimeout(100ms) → setTimeout(50ms) → setTimeout(50ms)` zinciriyle form dolduruluyor. Modal submit edilebilir hale gelmeden önce veri gelmeyebilir. Hızlı açma/kapamada eski değerler kalıyor.  
**Fix:** Tüm fonksiyonu `async/await` yap, setTimeout kaldır.

- [ ] `openAnimalEdit(a)` → `async function openAnimalEdit(a)`
- [ ] `setTimeout` bloklarını `await`'li ardışık satırlara dönüştür
- [ ] Modal açılırken önce tüm alanları temizle (`clearAnimalForm()` veya benzeri)
- [ ] Submit butonu modal hazır olmadan disable tut, hazır olunca enable et

---

### 1.3 `_TH` Lazy Init — Hayvan Autocomplete Patlar
**Dosya:** `js/ui.js` / `js/forms.js`  
**Sorun:** `_TH` (tohumlama için hayvan listesi) sadece insem modalı açılınca initialize ediliyor. Kızgınlık, doğum gibi diğer modallarda `acHayvan()` çağrılırsa `_TH` undefined → sessiz fail.  
**Fix:** `_TH`'yi app startup'ta veya `_A` yüklendiğinde initialize et.

- [ ] `_TH` init kodunu `loadData()` veya `initApp()` içine taşı
- [ ] `acHayvan()` başına `if (!_TH || !_TH.length) _TH = _A || [];` guard ekle
- [ ] Tüm `acHayvan()` çağıran modalları doğrula — hepsinde çalışıyor mu test et

---

### 1.4 Optimistic Update — Yanlış Başarı Toast'u
**Dosya:** `js/api.js`  
**Sorun:** `rpcOptimistic()` RPC henüz tamamlanmadan "Başarılı" toast'u gösteriyor. RPC fail olursa kullanıcı zaten başka sayfaya geçmiş, hata görmüyor ama veri kaydedilmedi.  
**Fix:** Toast'u RPC resolve sonrası göster.

- [ ] `rpcOptimistic()` içinde toast'u `await rpc(...)` sonrasına taşı
- [ ] Hata durumunda `toast('Kaydedilemedi: ' + e.message, true)` göster
- [ ] UI optimistic update'i yine de anında yap (hız için), ama toast beklesin

---

## BÖLÜM 2 — Veri Bütünlüğü

### 2.1 Gebelik Durumu Tek Kaynaktan
**Dosya:** `js/ui.js` ~343-355  
**Sorun:** `_gebeIds` tohumlama tablosundan, `a.durum === 'Gebe'` hayvanlar tablosundan — ikisi diverge edebilir. Farklı ekranlarda çelişkili gebelik bilgisi görünebilir.  
**Fix:** `_gebeIds` tek source of truth, `a.durum`'a bakma.

- [ ] Tüm gebelik badge/chip renderlarında `_gebeIds.has(a.id)` veya `_gebeIds.has(a.kupe_no)` kullan, `a.durum === 'Gebe'` kontrolünü kaldır
- [ ] `_gebeIds` set'i sadece `tohumlama.sonuc === 'Gebe'` olanlardan build et (zaten öyle, ama doğrula)
- [ ] `filterA()` ve `openDet()` chip/badge hesaplamalarını kontrol et

---

### 2.2 Stale Filter — Sayfa Dönüşünde Filter Sıfırlanmıyor
**Dosya:** `js/ui.js` ~454-491  
**Sorun:** `_fchip` (aktif filtre) sayfa değiştirince resetlenmiyor. Kullanıcı "Dişi" filtresiyle baktı, başka sayfaya gitti, döndü — hâlâ "Dişi" filtreli görünüyor ama buton aktif gözükmüyor.  
**Fix:** Sürü sayfasına her girişte filtreyi resetle veya görsel durumu sync et.

- [ ] Sürü sayfası `showPage('suru')` çağrısında `_fchip = {}` reset et
- [ ] Alternatif: filter butonlarının görsel durumunu `_fchip` ile sync et (her renderda buton classList güncelle)
- [ ] `filterA()` başında `getState('animals') || []` null guard ekle

---

### 2.3 Kızgınlık 90-Gün Hesabı Hatalı
**Dosya:** `js/ui.js` ~131-132  
**Sorun:** Doğumdan 90 gün geçince "muayene gerekli" uyarısı çıkıyor, ama bu sürede hayvan tohumlama/kızgınlık kaydı almışsa hâlâ uyarı çıkıyor.  
**Fix:** 90-gün uyarısında son tohumlama veya kızgınlık tarihini de kontrol et.

- [ ] `muayeneGerekli` listesini hesaplarken: son 90 günde `tohumlama` veya `kizginlik` kaydı varsa listeden çıkar
- [ ] Tarih karşılaştırması için `_tohMap` kullan (zaten var, `a.id` ile lookup yap)

---

### 2.4 Stok Negatife Düşebilir
**Dosya:** `js/ui.js` ~163 + `js/forms.js` bulk vaccination  
**Sorun:** `submitBulkVaccination()` transaction olmadan birden fazla stok hareketi ekliyor. Çift tıklamada double-apply riski var.  
**Fix:** Submit butonunu disable et, işlem bitince enable et.

- [ ] `submitBulkVaccination()` başında submit butonunu disable et
- [ ] `finally` bloğunda enable et
- [ ] Stok sıfırın altına düşerse (negatif) kullanıcıya uyarı göster: `if (stkNet[id] < 0) toast('Stok yetersiz', true)`

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

Kritik: 0/4 · Veri: 0/4 · UX: 0/7
