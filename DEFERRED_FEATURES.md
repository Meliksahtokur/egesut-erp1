# 📋 Ertelenen Özellikler ve Teknik Borçlar

**Tarih:** 2026-03-29  
**Sprint:** Bugfix Sprint (chore/bug-001-resolved)

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
| LOGIC-003: Offline tedavi günleri | 🔴 Ertelendi | Yüksek | **Sonraki** |
| UI-003: Hayvan arama iyileştirme | 🟡 Ertelendi | Düşük | Backlog |

---

## 🎯 Sonraki Sprint Önerisi

**Sprint Adı:** `feat/offline-first-clinical`

**Hedefler:**
1. LOGIC-003: Offline tedavi günleri görünür olması
2. Offline modda vaka açma + gün ekleme tam desteği
3. Sync bar iyileştirmeleri (kuyruk durumu, hata yönetimi)

**Tahmini Süre:** 2-3 gün
