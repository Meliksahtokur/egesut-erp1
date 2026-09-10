# Üreme Zekası — Gelecek Fikirler

**Oluşturuldu:** 2026-05-21  
**Durum:** Fikir — henüz task açılmadı

---

## 1. 260-Gün Çıkarım Kuralı (Doğum Sayıldı)

**Fikir:** Aktif 'Gebe' kaydı olup 260+ gün geçmiş ve üzerine yeni tohumlama yapılmış hayvanlar → doğum yapmış sayılır.

**Mevcut durum:** `tohumlama_kaydet` RPC'de 260-gün auto-close var (migration 000003). Sonuç 'Doğum Yaptı' olarak yazılıyor, islem_log'a `DOGUM_OTOMATIK` tipiyle kaydediliyor.

**Eksik:** Bu otomatik kapatılan kayıtlar için `dogum` tablosuna gerçek bir buzağı kaydı oluşturulmuyor — sadece tohumlama.sonuc güncelleniyor. Hayvan kartında "X buzağı" sayısı bu vakayı saymıyor.

---

## 2. Yaşam Boyu Buzağı Sayısı

**Fikir:** Her ineğin yaşamı boyunca kaç buzağı ürettiğini hesapla.

**Veri kaynakları:**
- `dogum` tablosu — gerçek doğum kayıtları
- `tohumlama.sonuc = 'Doğum Yaptı'` — bazıları `dogum` kaydı olmadan kapanmış olabilir
- `islem_log.tip = 'DOGUM_OTOMATIK'` — 260-gün çıkarımıyla kapanan vakalar

**Hesaplama önerisi:**
```sql
SELECT COUNT(*) FROM dogum WHERE anne_id = :hayvan_id  -- gerçek kayıtlar
UNION
-- islem_log'daki DOGUM_OTOMATIK kayıtlar (dogum tablosunda karşılığı yoksa)
```

---

## 3. Hayvan Kartında Gösterim

**Fikir:** Hayvan kartı üreme sekmesinde:
- "Toplam X doğum · Y buzağı" özet satırı
- Laktasyon dönemi listesi (Döngü 1: N tohumlama → doğum, Döngü 2: ...)

---

## 4. Filtreleme & İstatistik

**Fikir:** Hayvan listesinde filtre:
- "3+ buzağı doğurmuş" 
- "Hiç doğurmamış, 2+ yıl çiftlikte"
- "Son döngüde 3+ tohumlama denendi"

**İstatistik paneli:**
- Sürü ortalama buzağı/inek
- En verimli damızlıklar
- Boş kalma oranı dönemsel

---

## 5. 300-Gün Pasif Çıkarım (İstatistik Only)

**Fikir:** 300+ gün aktif 'Gebe' kaydı olan hayvanlar — tohumlama girişi olmasa bile — istatistiklerde "muhtemelen doğurdu" olarak sayılsın. DB'ye yazılmaz, sadece hesaplama katmanında.

**Uygulama:** View veya JS-side hesaplama. `sonuc` kolonu değişmez.
