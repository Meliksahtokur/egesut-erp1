# Spec: Yönetim Paneli CRUD İyileştirmesi

**Tarih:** 2026-05-10
**Öncelik:** ORTA
**Bağımlılık:** Yok (bağımsız)

---

## Mevcut Durum

### Ayarlar Paneli (m-ayarlar)
- Hekimler: Ekle ✅ | Sil ❌ | Düzenle ❌
- Sperma: Ekle ✅ | Sil ❌ | Düzenle ❌
- Aşı Kataloğu: Salt okunur liste ✅ | CRUD ❌
- İlaç–Stok Bağlantıları: Sadece bağlama ✅

### Padok
- `GRUP_PADOK` → `js/config.js` hardcoded
- Kullanıcı padok oluşturamaz/silemez
- DB'de padok tablosu YOK (hayvanlar.padok TEXT alanı)

### Sperma Mock Verisi
- Stok tablosunda "Starred" (50 adet) → muhtemelen mock/test

---

## 1. Hekim CRUD

### Mevcut
- `ayarlarHekimEkle()` → form göster
- `ayarlarHekimKaydet()` → DB'ye yaz
- Liste render'ı → silme yok

### Eklenmesi Gereken
- Her hekim satırının yanına 🗑 sil butonu
- Onay modal: "Bu hekimi silmek istediğinizden emin misiniz?"
- Silme: `DELETE FROM hekimler WHERE id = ?` (soft delete değil, hard delete)
- Constraint: Tohumlama kaydı varsa silinemez → uyarı

### UI
```
Hekimler:
├── Dr. Ahmet Yılmaz  [🗑]
├── Dr. Fatma Kaya     [🗑]
└── [+ Ekle]
```

---

## 2. Sperma CRUD + Mock Temizleme

### Mevcut
- Sperma listesi ayarlardan ekleniyor
- Ama nereye yazıldığı belirsiz — stok tablosu mu, ayrı tablo mu?

### Kontrol Noktaları
- `stok` tablosunda `kategori='Sperma'` olan kayıtlar sperma
- "Starred" kaydı mock → silinecek veya kullanıcıya sorulacak

### Eklenmesi Gereken
- Sperma satırına 🗑 sil butonu
- Düzenleme: isim değiştirme (urun_adi UPDATE)
- Mock temizleme: "Starred" gibi anlamsız kayıtları tespit et

### Constraint
- `tohumlama.sperma` alanında kullanılmışsa: silinemez, uyarı ver

---

## 3. Padok Yönetimi (YENİ)

### Mevcut Mimari
```js
// config.js — HARDCODED
const GRUP_PADOK = {
  'Sağmal (Laktasyonda)': ['Sağmal Padok'],
  'Sağmal (Kuru)': ['Kuru/Gebe Padok'],
  ...
};
```

- `hayvanlar.padok` → TEXT (serbest string)
- Padok listesi config'den geliyor, DB'de tablo yok

### Hedef Mimari

**Yeni tablo: `padoklar`**
```sql
CREATE TABLE padoklar (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  ad text NOT NULL UNIQUE,
  kapasite integer,
  aktif boolean DEFAULT true,
  sira integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);
```

**Migration adımları:**
1. Tablo oluştur
2. Mevcut config'deki padokları INSERT et (seed)
3. `js/config.js` GRUP_PADOK → kaldırılmaz, ama UI artık `padoklar` tablosundan okusun
4. GRUP_PADOK sadece varsayılan mapping olarak kalsın (yeni padok eklenince grup eşleşmesi kullanıcı seçsin)

### Ayarlar UI
```
🏠 Padoklar:
├── Sağmal Padok        [kapasite: 55] [🗑]
├── Kuru/Gebe Padok     [kapasite: 15] [🗑]
├── Düve Padok (Büyük)  [kapasite: 20] [🗑]
├── Buzağı Padok (Süt)  [kapasite: 10] [🗑]
└── [+ Yeni Padok Ekle]
```

### CRUD
- **Ekle:** Ad + kapasite (opsiyonel)
- **Sil:** İçinde hayvan varsa silinemez → "Önce hayvanları taşıyın"
- **Düzenle:** Ad değiştirme, kapasite güncelleme

### Config.js ile uyum
- `GRUP_PADOK` mapping hâlâ var ama UI'da padok seçilirken `padoklar` tablosundan okunur
- Yeni padok eklenince hangi gruba ait olduğu sorulur (veya "Özel" kategorisi)

---

## 4. Genel Ayarlar UX İyileştirmesi

### Mevcut Sorunlar
- Tek uzun scroll panel (hekim, sperma, aşı, ilaç, data traffic, sistem, bildirimler hepsi üst üste)
- Aradığını bulmak zor

### Hedef
- Sekmeli yapı (tabs): "Hayvan Yönetimi" | "İlaç & Aşı" | "Stok" | "Sistem"
- VEYA accordion/collapse ile bölümler

### Sekme Önerisi
| Sekme | İçerik |
|-------|--------|
| 🐄 Çiftlik | Padoklar, Hekimler, Sperma |
| 💊 İlaç & Aşı | Aşı Kataloğu, İlaç-Stok Bağlantıları |
| ⚙️ Sistem | Data Traffic, Bildirimler, PWA, Tema |

---

## Test Senaryosu

1. Hekim sil → tohumlama kaydı yoksa silinir ✅
2. Hekim sil → tohumlama kaydı varsa uyarı ❌ (silinemez)
3. Sperma sil → kullanılmamışsa silinir
4. Padok ekle → "Test Padok" → listede görünür → hayvan taşınabilir
5. Padok sil → içi boşsa silinir → doluysa uyarı
6. "Starred" mock sperma → temizle/sil
