# Buzağı Toplu Giriş — Faz 1 Sonuç Raporu

> Tarih: 2026-05-31
> Görev: task-044-buzagi-toplu-giris
> Faz 1: Eksik Anne Eşleştirme (3 SQL sorgusu)

---

## SURU-TAKIP Veritabanı Taraması (Ek: 2026-05-31)

**Kaynak:** `/root/SURU-TAKIP/data/tohumlamalar.db` — vethek.org'dan scrape edilmiş
tohumlama kayıtları (1538 kayıt, 238 benzersiz küpe, 3 scrape tarihi)

### Bulgular — Doğrudan Küpe Eşleşmesi

7 eksik annenin **kendi küpe numaralarıyla** SURU-TAKIP'te GEBE tohumlama kaydı var
ve gebelik günü 270-300 aralığına tam oturuyor:

| Küpe | SURU-TAKIP ID | Tohumlama | Geb. Gün | Doğum Tarihi | Irk |
|------|---------------|-----------|----------|-------------|-----|
| 107  | 30640 | 2025-01-17 | 275 | 2025-10-19 | Holstein |
| 159  | 31298 | 2025-03-19 | 279 | 2025-12-23 | Holstein |
| 161  | 31580 | 2025-04-13 | 279 | 2026-01-17 | Holstein |
| 179  | 30863 | 2025-02-10 | 279 | 2025-11-16 | Holstein |
| 196  | 31133 | 2025-03-05 | 274 | 2025-12-04 | Holstein |
| 2045 | 30960 | 2025-02-17 | 272 | 2025-11-16 | Holstein |
| 1956 | 31282 | 2025-03-17 | 276 | 2025-12-18 | Holstein |

### Doğrudan Eşleşmeyenler (Supabase Adayları Gerekli)

| Küpe | Doğum | Durum | En İyi Supabase Adayı | Açıklama |
|------|-------|-------|----------------------|----------|
| 162  | 2025-11-07 | ⚠️ ADAY | **küpe 178** (toh:2025-01-30, G:281) | SURU-TAKIP'te hiç kaydı yok |
| 5748 | 2025-12-14 | ⚠️ ADAY | **küpe 199** (toh:2025-02-24, G:293) | SURU-TAKIP'te sadece BOŞ kayıtlar |
| 7125 | 2025-12-15 | ⚠️ ADAY | **küpe 199** (toh:2025-02-24, G:294) | SURU-TAKIP'te GEBE kaydı var ama pencere dışı (322g) |
| 106  | 2026-02-03 | ⏭️ ATLA | — | Buzağı ex, anne satıldı, eklenmeyecek |

### SURU-TAKIP'te Teyit Edilen Supabase Adayları

**Küpe 162'nin penceresinde** (2025-01-11 - 2025-02-10) GEBE kaydı olan Supabase adayları:

| Aday | SURU-TAKIP ID | Tohumlama | Durum | Irk |
|------|---------------|-----------|-------|-----|
| 182  | 30595 | 2025-01-12 | GEBE | Holstein |
| 178  | 30752 | 2025-01-30 | GEBE | Holstein |
| 197  | 30789 | 2025-02-02 | GEBE | Holstein |
| 191  | 30843 | 2025-02-08 | GEBE | Simental |
| 195  | 30851 | 2025-02-09 | GEBE | Holstein |

**Küpe 5748/7125'in penceresinde** (2025-02-17 - 2025-03-19) GEBE kaydı olan Supabase adayları:

| Aday | SURU-TAKIP ID | Tohumlama | Durum | Irk |
|------|---------------|-----------|-------|-----|
| 147  | 30974 | 2025-02-18 | GEBE | Holstein |
| 181  | 30983 | 2025-02-19 | GEBE | Holstein |
| 199  | 31033 | 2025-02-24 | GEBE | Holstein |
| 101  | 31132 | 2025-03-05 | GEBE | Holstein |

**Not:** Hayvanların tamamı Holstein (küpe 191 hariç Simental). SURU-TAKIP'teki
`hayvan_id` (int) ile Supabase UUID arasında doğrudan bağlantı yoktur — eşleştirme
küpe_no üzerinden yapılır.

### Karşılaştırmalı Değerlendirme

| Liste Küpe | Sorgu 1 (Supabase) | SURU-TAKIP | Hangisi Kullanılacak? |
|------------|-------------------|------------|----------------------|
| 107 | 142, 156, 182 aday | ✅ bizzat 107 GEBE | **107** (kendi kaydı) |
| 159 | 5638, 101, 903 aday | ✅ bizzat 159 GEBE | **159** (kendi kaydı) |
| 161 | 176, 167, 187, 134 aday | ✅ bizzat 161 GEBE | **161** (kendi kaydı) |
| 179 | 904, 178, 197, ... aday | ✅ 179---TR... GEBE | **179** (kendi kaydı) |
| 196 | 191, 195, 155, ... aday | ✅ bizzat 196 GEBE | **196** (kendi kaydı) |
| 2045 | (hiç aday yoktu) | ✅ TR354342045 GEBE | **2045** (kendi kaydı) |
| 1956 | 199, 5638, 101, 903 aday | ✅ TR354341956 GEBE | **1956** (kendi kaydı) |
| 162 | 182, 904, 178, ... aday | ❌ hiç kayıt yok | Supabase adayı **178** (G:281) |
| 5748 | 147, 181, 199, ... aday | ❌ sadece BOŞ | Supabase adayı **199** (G:293) |
| 7125 | 147, 181, 199 aday | ❌ GEBE var ama pencere dışı | Supabase adayı **199** (G:294) |
| 106 | 134, 115, 141, ... aday | ✅ var ama BOŞ | **ATLANACAK** |

---

## Sorgu 1 — Tohumlama Eşleştirme

11 eksik annenin her biri için, buzağı doğum tarihinden 270-300 gün önceki pencerede
tohumlama kaydı olan dişi hayvanlar bulundu.

### Eşleşme Tablosu

| Liste Küpe | Doğum | Aday Sayısı | En Yakın Aday | Tohumlama | Geb. Gün | Not |
|---|---|---|---|---|---|---|
| 107 | 2025-10-19 | 3 | **142** | 2025-01-02 | 290 | |
| 2045 | 2025-11-16 | 2 | **147** | 2025-02-18 | 271 | |
| | | | **181** | 2025-02-19 | 270 | |
| 162 | 2025-11-07 | 6 | **182** | 2025-01-12 | 299 | |
| | | | **904** | 2025-01-27 | 284 | |
| | | | **178** | 2025-01-30 | 281 | |
| 179 | 2025-11-16 | 9 | **904** | 2025-01-27 | 293 | ex buzağı |
| | | | **178** | 2025-01-30 | 290 | |
| | | | **197** | 2025-02-02 | 287 | |
| | | | **191** | 2025-02-08 | 281 | |
| | | | **195** | 2025-02-09 | 280 | |
| | | | **155** | 2025-02-15 | 274 | |
| | | | **905** | 2025-02-17 | 272 | |
| 196 | 2025-12-04 | 9 | **191** | 2025-02-08 | 299 | Alaca holstein |
| | | | **195** | 2025-02-09 | 298 | |
| | | | **155** | 2025-02-15 | 292 | |
| | | | **905** | 2025-02-17 | 290 | |
| | | | **147** | 2025-02-18 | 289 | |
| | | | **199** | 2025-02-24 | 283 | |
| 5748 | 2025-12-14 | 7 | **905** | 2025-02-17 | 300 | red |
| | | | **147** | 2025-02-18 | 299 | |
| | | | **199** | 2025-02-24 | 293 | |
| | | | **903** | 2025-03-17 | 272 | |
| 7125 | 2025-12-15 | 6 | **147** | 2025-02-18 | 300 | red |
| | | | **199** | 2025-02-24 | 294 | |
| | | | **903** | 2025-03-17 | 273 | |
| 1956 | 2025-12-18 | 4 | **199** | 2025-02-24 | 297 | red |
| | | | **903** | 2025-03-17 | 276 | |
| 159 | 2025-12-23 | 3 | **5638** | 2025-03-02 | 296 | ex, alaca küçük |
| | | | **101** | 2025-03-05 | 293 | |
| | | | **903** | 2025-03-17 | 281 | |
| 161 | 2026-01-17 | 5 | **176** | 2025-04-01 | 291 | |
| | | | **167** | 2025-04-01 | 291 | |
| | | | **187** | 2025-04-04 | 288 | |
| | | | **134** | 2025-04-14 | 278 | |
| | | | **183** | 2025-05-09 | 253 | (sınır dışı) |
| 106 | 2026-02-03 | 5 | **134** | 2025-04-14 | 295 | erken doğum, anne satıldı |
| | | | **115** | 2025-05-02 | 277 | |
| | | | **141** | 2025-05-04 | 275 | |
| | | | **189** | 2025-05-09 | 270 | |
| | | | **183** | 2025-05-09 | 270 | |

### Önemli Tespitler

1. **Hiçbir adayın `devlet_kupe` veya `irk` bilgisi yok** — ekleme sırasında doldurulmalı
2. **Tüm adaylar** `Sağmal (Laktasyonda)` grubunda ve `Aktif` durumda
3. **küpe 904** (UUID: `00ca7aa3-5650-4379-a930-80a8970bfe6a`) listedeki 2 farklı eksik anne için de aday (162 ve 179) — bu mantıken mümkün değil, her annenin farklı olması gerekir. Pencere çakışmasından kaynaklanıyor.
4. **küpe 106'nın annesi satıldı** — bu buzağı da ex (öldü). Anne eklense bile `durum = 'Satıldı'` olacak.

---

## Sorgu 2 — Yakın Küpe Arama

**Sonuç:** `[]` (boş küme)

11 küpe numarasından hiçbiri `hayvanlar` tablosunda `kupe_no` veya `devlet_kupe` olarak
bulunamadı. Büyük olasılıkla anneler fiziksel olarak sistemde hiç kayıtlı değil,
typo olasılığı düşük.

---

## Sorgu 3 — Mevcut Doğum Kayıtları

**Sonuç:** 1 kayıt (test)

```
id:       7e8504ef-2e68-4058-a50a-8051e321ecd5
anne:     Test inek cabbar (UUID: a0731c92-6fe9-4878-87a8-255b9f8735b3)
tarih:    2026-05-26
yavru:    Test buzağı cabbiş (Dişi, Montofon)
doğum_tipi: Normal
```

**46 buzağıdan hiçbirinin kaydı daha önce girilmemiş.** Çakışma yok, sıfırdan
başlanabilir.

---

## Faz 1 Değerlendirme

| Sorgu | Başarılı? | Sonuç |
|---|---|---|
| Tohumlama eşleştirme | ✅ | 11/11 eksik anne için aday bulundu |
| Yakın küpe arama | ✅ | Typo yok, anneler sistemde kayıtlı değil |
| Mevcut doğum kontrol | ✅ | Çakışma yok, sıfırdan başlanabilir |

### Faz 2'ye Geçiş İçin Gerekenler

1. Her eksik anne için doğru adayın seçilmesi (manuel inceleme gerekli — pencere çakışmaları var)
2. Anne 106 sistemde yoksa da eklenmeyecek (buzağı öldü, anne satıldı)
3. Toplu INSERT için SQL hazırlığı
4. `duration` güncellemeleri (ex/satılan buzağılar)