# 📋 Ertelenen Özellikler ve Teknik Borçlar

**Tarih:** 2026-03-30
**Son Güncelleme:** Tohumlama RPC ve SonarCloud fixleri tamamlandı.

---

## ✅ TAMAMLANMIŞ (Son 30 Gün)

### Tohumlama Modülü RPC Refaktöring — %70 Tamamlandı

**Tamamlanan İşler:**
- ✅ `tohumlama_kaydet` RPC — Event stack + islem_log + geri al desteği (migration 030)
- ✅ `tohumlama_sonuc_gebe` RPC — Yeni kayıt (migration 030)
- ✅ `tohSonucGuncelle` kaldırıldı — Korumasız write path temizlendi
- ✅ `tohSonuc` tek versiyon — ui.js'deki çakışan fonksiyon silindi
- ✅ Geri al butonu — `ref_id` fix (migration 028)
- ✅ Tohumlama modal durum bazlı buton kontrolü
- ✅ Input validation — İleri tarih engeli (forms.js:40,113,155)

**Kalan İşler:**
- 🔴 `tohumlama_sonuc_bos` RPC — `tohSonuc()` hala REST PATCH kullanıyor (forms.js:656)
- 🔴 `tohumlama_abort` RPC — Gebe → Abort için

**Öncelik:** Yüksek — 1 write path kalacak, tüm tohumlama işlemleri RPC üzerinden

---

### SonarCloud Remediation — S2 & S3 Tamamlandı

**Tamamlanan Sprint'ler:**
- ✅ S1 — Gerçek Bug'lar (10 issue) — f8874a0
- ✅ S2 — BLOCKER Globals (28 issue) — 14cda49
- ✅ S3 — Mantık Tutarsızlıkları (~35 issue) — b572e26
- ✅ S4 — Cognitive Complexity + Nested Ternary (~75 issue) — 0f2f0e2
- ✅ S5 — Minor Modernizasyon (Bulk, ~100 issue) — 55e8212

**Kalan:**
- 🟡 WONTFIX katalog (~188 issue) — SonarCloud UI'da manuel işaretleme gerekli
  - Label accessibility (S6853): 64 issue
  - Non-native element (S6848): 24 issue
  - Mouse event (S7726): 24 issue
  - SQL literal duplication: 72 issue
  - Diğer: 4 issue

**Tahmini:** 30-45 dk (manuel)

---

## 🔴 Yüksek Öncelikli (Gelecek Sprint)

### LOGIC-003: Offline Modda Tedavi Günleri Görünmüyor

**Sorun:**  
Offline modda eklenen tedavi günleri ve ilaç uygulamaları, online moda geçilene kadar UI'da görünmüyor.

**Kök Sebep:**  
- `renderCaseTimeline()` fonksiyonu `tedavi` ve `drug_administrations` tablolarını IndexedDB'den okuyor
- Ancak offline modda `write()` ile eklenen kayıtlar timeline render'ından önce cache'e yansımıyor
- Mevcut mimari: RPC → pullTables → render (online-first)
- Offline-first mimari için: write → local cache update → render → background sync

**Çözüm Yaklaşımı:**  
1. `caseDrugKaydet()` fonksiyonunda offline modda:
   - `drug_administrations` tablosuna write() ile ekle
   - `_drugAdminCache` adında local cache oluştur
   - Render fonksiyonunu cache'den besle
2. `renderCaseTimeline()` fonksiyonunu refactor et:
   - Önce IDB'den oku
   - Sonra pending offline kayıtları merge et
   - Birleştirilmiş liste ile render yap

**Tahmini Efor:** 4-6 saat  
**Risk:** Orta (timeline render karmaşık, regression test gerekli)  
**Bağımlılıklar:**  
- `drug_administrations` tablosu IndexedDB'de tam destekli değil
- `renderCaseTimeline()` fonksiyonu yüksek kompleksite (S3776)

**Not:** Bu özellik şu anki sprint kapsamı dışında. Klinik modülü stabil çalışıyor, online modda sorun yok. Offline-first destek bir sonraki sprint'te eklenecek.

---

## 🟡 Orta Öncelikli

### UI-003: Hayvan Listeleme — Input Odaklı Arama

**Durum:** Kısmen çalışıyor  
**Açıklama:**  
- Kızgınlık ve Doğum modallarında spesifik hayvan listesi çalışıyor (tohumlanabilir / anne adayları)
- Tohumlama ve Hastalık modallarında tüm hayvanlar listeleniyor (rakam tuşlamak gerekiyor)

**Öneri:**  
- Tohumlama modalı: `tohumlanabilir_hayvanlar` view'ını kullan (zaten var)
- Hastalık modalı: Aktif dişi hayvanları filtrele (erkek hariç)

**Öncelik:** Düşük — mevcut kullanım akışını bozmuyor

---

## 🟢 Düşük Öncelikli (İyileştirme)

### PERF-001: Hayvan Arama — Otomatik Tamamlama İyileştirmesi

**Sorun:** Kullanıcılar hala rakam tuşlamak zorunda

**Önerilen Çözüm:**  
```javascript
// acHayvan() fonksiyonunu geliştir
if (!q) {
  // Boş sorguda tüm hayvanları göster (ilk 20)
  filtered = src.slice(0, 20);
} else {
  // Küpe, ID, ırk bazlı filtrele
  filtered = src.filter(/* ... */);
}
```

**Risk:** Çok fazla hayvan varsa dropdown performansı düşebilir

---

## 📊 Sprint Özeti

| Özellik | Durum | Öncelik | Sprint |
|---------|-------|---------|--------|
| UI-001: Gebe Ata buton boyutu | ✅ Tamamlandı | Yüksek | chore/bug-001-resolved |
| UI-002: Modal ilk tıklama focus | ✅ Tamamlandı (kısmi) | Yüksek | chore/bug-001-resolved |
| LOGIC-001: Offline ilaç ekleme | ✅ Tamamlandı | Yüksek | chore/bug-001-resolved |
| LOGIC-002: Online sync | ✅ Tamamlandı | Yüksek | chore/bug-001-resolved |
| FEAT-001: Stok hareketleri listesi | ✅ Tamamlandı | Orta | chore/bug-001-resolved |
| TOHUMLAMA: Event Stack + RPC | ✅ Tamamlandı (70%) | Yüksek | tohumlama-rpc-030 |
| SONARCLOUD: S2-S5 fixleri | ✅ Tamamlandı (~250 issue) | Yüksek | sonarcloud-remediation |
| LOGIC-003: Offline tedavi günleri | 🔴 Ertelendi | Yüksek | **Sonraki** |
| TOHUMLAMA: `tohumlama_sonuc_bos` RPC | 🔴 Ertelendi | Yüksek | **Sonraki** |
| TOHUMLAMA: `tohumlama_abort` RPC | 🟠 Ertelendi | Orta | Backlog |
| SONARCLOUD: WONTFIX işaretleme | 🟡 Ertelendi | Düşük | Backlog |
| UI-003: Hayvan arama iyileştirme | 🟢 Ertelendi | Düşük | Backlog |

---

## 🎯 Sonraki Sprint Önerisi

**Sprint Adı:** `feat/tohumlama-bos-rpc`

**Hedefler:**
1. `tohumlama_sonuc_bos` RPC ekle (migration)
2. `tohSonuc()` fonksiyonunu RPC'ye çevir (forms.js:656)
3. Basit test: Tohumlama modal → "Boş" butonu → islem_log kontrolü

**Tahmini Süre:** 30-45 dk

---

**Sprint Adı:** `feat/offline-first-clinical`

**Hedefler:**
1. LOGIC-003: Offline tedavi günleri görünür olması
2. `_drugAdminCache` local cache oluştur
3. `renderCaseTimeline()` cache + DB merge refactor

**Tahmini Süre:** 2-3 saat

---

**Sprint Adı:** `chore/sonarcloud-wontfix`

**Hedefler:**
1. SonarCloud UI'da ~188 issue'yu "Won't Fix" olarak işaretle
2. Her kategori için açıklama ekle

**Tahmini Süre:** 30-45 dk (manuel)
