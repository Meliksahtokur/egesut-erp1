---
id: "044"
title: "Buzağı Toplu Giriş — 49 kayıt (Eylül 2025 – Nisan 2026)"
status: completed
phase: "2-toplu-insert"
created: 2026-05-31
updated: 2026-06-01
completed: 2026-06-01
---

# Buzağı Toplu Giriş Planı

## Özet

46 buzağı doğum kaydı sisteme girilecek. Faz 1 tamamlandı: 11 eksik anneden 3'ü eşleştirildi, 7'si bulunamadı (piç kayıt — anne_id NULL), 1'i arşivlendi.

---

## Faz 1 — Eksik Anne Eşleştirme ✅ TAMAMLANDI

### Sonuç: 3 eşleşme, 7 bulunamadı, 1 arşiv

| Eski Küpe | Yeni Küpe (Supabase) | Kanıt | Durum |
|-----------|---------------------|-------|-------|
| **2045** | **905** | Toh.tarihi birebir: 2025-02-17 | ✅ Kesin |
| **1956** | **903** (4aee4470) | Toh.tarihi birebir: 2025-03-17 | ✅ Kesin |
| **162** | **904** (00ca7aa3) | Toh: 01-27→doğum 11-07=284g, kullanıcı onayı | ✅ Onaylı |
| **106** | — | Buzağı ex (erken doğum), anne satıldı | ⏭️ Arşiv/seed |

### Bulunamayan Anneler (anne_id = NULL olacak)

| Eski Küpe | SURU-TAKIP Bilgisi | İpucu | Not |
|-----------|-------------------|-------|-----|
| **107** | Toh: 2025-01-17, GEBE, Holstein | Supabase'de eşleşme yok | Küpesi değişmiş, yeni küpe bilinmiyor |
| **179** | Toh: 2025-02-10, GEBE, Holstein | Supabase'de eşleşme yok | Buzağısı ex |
| **196** | Toh: 2025-03-05, GEBE, Holstein | 101'in küpesi 900-serisi olmuş olabilir | Alaca holstein buzağı |
| **159** | Toh: 2025-03-19, GEBE, Holstein | Supabase'de eşleşme yok | Buzağısı ex |
| **161** | Toh: 2025-04-13, GEBE, Holstein | Supabase'de eşleşme yok | |
| **5748** | SURU'da sadece BOŞ kayıtlar | Devlet küpe sonu 2073 olabilir | DB'de devlet_kupe NULL |
| **7125** | SURU'da GEBE ama pencere dışı (322g) | Küpe 190 olabilir | DB'de 190 yok |

### Küpesiz Anneler (kimliği belirsiz)

| Liste Adı | Buzağı | Not |
|-----------|--------|-----|
| **Küpesiz düve** | #40 (21.10.2025, dana, ₺) | Fiziksel küpe yok, anne_id NULL |
| **Minik panda** | #58 (12.12.2025, dana, ex) | Lakap, anne_id NULL |

**Detaylı araştırma raporu:** `docs/superpowers/plans/2026-05-31-buzagi-toplu-giris-faz1-sonuc.md`

---

## Faz 2 — Toplu Insert (SIRADA)

**Güncel durum (2026-06-01, tamamlandı):** Faz 1-2 tamam. 49 buzağı kaydı girildi (hayvanlar + dogum). 177 DB'de yok → anne_id NULL. Faz 3 (aşılama) opsiyonel, bu task kapsamı dışında.

### Adım 1: Anne UUID Haritası

Eşleşen anneler (35 bilinen + 3 bulunan = 38):

| Liste Küpe | Supabase küpe_no | UUID |
|-----------|-----------------|------|
| 5621 | 5621 | 87323e7b-c8e7-4d48-aaea-36644684b14a |
| 145 | 145 | a4c61f97-64d4-403c-b6d2-878195020a44 |
| 177 | — | ❓ DB'de aranacak |
| 142 | 142 | 143fbad6-2d0b-494b-9da6-d5db896bc095 |
| 153 | 153 | 6f4f3c76-6ff8-4d72-b224-560a3c8230d3 |
| 182 | 182 | ff007c90-6bdb-463c-8773-1af57bf30bc9 |
| 008 | 008 | fa8e6daa-d73b-4bf0-97d8-3ff1e597256a |
| 167 | 167 | 4211de36-69f3-4148-b9f8-9fc88c35653e |
| 178 | 178 | 1ae146e4-916b-4337-a256-f05a22ae9ec6 |
| 197 | 197 | 9dc8cbae-529c-42c0-ab9f-abd855949faa |
| 191 | 191 | 01ae80a9-a05b-4b38-b2df-76992beff9bb |
| 155 | 155 | 115011e1-5d34-483f-ad89-f2bd69fd8697 |
| 5708 | 5708 | c8861b6f-b96a-42ef-94b7-1591729396ac |
| 2045 | **905** | d607db2d-3af5-4303-9528-159021e917d4 |
| 195 | 195 | bac3b8f8-43c3-4cf5-83ed-6e1073c16fec |
| 181 | 181 | c4c1c3d6-747e-4536-82e8-f9b5250220de |
| 199 | 199 | e31a60e5-0fe8-4a1a-882b-3b0ab0bd61f5 |
| 147 | 147 | 3b8b66ba-3c29-4e20-b494-043737125fef |
| 196 | — | NULL (bulunamadı) |
| 101 | 101 | e9d582a1-cf08-4619-adda-9812048e6647 |
| 5638 | 5638 | 456d7c6d-e1cf-4500-a325-7afe9be15260 |
| 154 | 154 | 34e04643-713a-4646-a9e1-190cc5b3ec3d |
| 162 | **904** | 00ca7aa3-5650-4379-a930-80a8970bfe6a |
| 187 | 187 | acbbc7ce-3aff-4ed4-9600-5dd74ea5a9b2 |
| 161 | — | NULL (bulunamadı) |
| 189 | 189 | 1433f5f2-b60a-425e-9ab8-897ab089a711 |
| 141 | 141 | 1f0706c0-e89c-42a4-a8a5-27d6d0e0a3cd |
| 176 | 176 | 629a040e-8f9d-4e38-9742-db6db23b3f5d |
| 152 | 152 | e641d149-a928-4624-b1f4-a4821f601e62 |
| 115 | 115 | d9e1838e-ae5f-405d-b1aa-9a59835e345d |
| 134 | 134 | 38e3ec48-ae34-436c-bd32-6562f969c576 |
| 175 | 175 | 995c15e1-29d8-420d-a22d-4f58bae2c5ab |
| 183 | 183 | f454bdd3-6b76-48dd-98c7-f68ba8635b96 |
| 121 | 121 | f7ae4a63-65a0-444e-a3ab-a22a0a241828 |
| 146 | 146 | 4f56df98-403f-4894-96ff-8b9dbfce8368 |
| 192 | 192 | 1841c6e0-16ea-4d43-a25d-a65352f99718 |
| 901 | 901 | 88449c15-0915-4cd3-a2ac-83c88bcecfb1 |
| 1956 | **903** | 4aee4470-0101-4c2d-9f65-a28e02238634 |
| 173 | 173 | 548df203-5c9c-4620-8858-8de93ef13841 |
| 180 | 180 | b6053753-b612-4040-82b6-e06f4c947bb2 |

**Hâlâ UUID'si eksik:** 177 (DB'de aranacak)
**anne_id NULL olacaklar:** 107, 179, 196, 5748, 7125, 159, 161, 106, Küpesiz düve, Minik panda

#### 🔍 Alt-adım: 177 UUID çözümü

```sql
-- DB'de 177 küpeli hayvan var mı?
SELECT id, kupe_no, durum FROM hayvanlar WHERE kupe_no = '177';
-- Yoksa → anne_id = NULL ile devam
-- Varsa → UUID'yi haritaya ekle
```

### Adım 2: Buzağıları `hayvanlar` tablosuna ekle (46 kayıt)

```
id:            gen_random_uuid()
kupe_no:       sıra numarası string ('33', '34', ... '80') — 106'nın buzağısı 'xx'
cinsiyet:      dana → 'Erkek', düve → 'Dişi'
dogum_tarihi:  listeden
anne_id:       UUID haritasından (bulunamayanlar NULL)
grup:          yaşa göre belirlenecek (şu an çoğu 7-8 aylık = Düve Küçük/Büyük)
durum:         normal → 'Aktif', ex → 'Ölü', ₺ → 'Satıldı'
irk:           notlardaki (Alaca holstein, red holstein, Norveç) veya NULL
```

**Grup ataması (doğum tarihine göre, bugün 2026-05-31):**
- Eylül-Ekim 2025 doğumlu (8-9 ay) → 'Düve (Büyük)' veya dana ise satıldı/öldü
- Kasım-Aralık 2025 doğumlu (6-7 ay) → 'Düve (Küçük)' veya dana ise satıldı/öldü
- Ocak-Şubat 2026 doğumlu (3-5 ay) → 'Süt İçen Buzağı'
- Mart-Nisan 2026 doğumlu (1-3 ay) → 'Süt İçen Buzağı'
- Ex/Satıldı olanlar → durum güncellenir, grup son bilinen

**Durum atamaları:**
- **Ölü (ex):** #37(153), #50(179), #52(181), #57(5638), #58(Minik panda), #63(159), #66(189), #xx(106), #70(115), #72(175)
- **Satıldı (₺):** #33(5621), #34(145), #35(177), #40(Küpesiz düve), #41(008), #42(167)
- **Aktif:** geri kalan 30 buzağı

### Adım 3: Doğum kayıtlarını `dogum` tablosuna ekle (46 kayıt)

```
id:          gen_random_uuid()
anne_id:     UUID haritasından (bulunamayanlar NULL)
tarih:       doğum tarihi
yavru_cins:  dana → 'Erkek', düve → 'Dişi'
yavru_kupe:  buzağı küpe_no (sıra numarası string)
dogum_tipi:  'Normal' (106 → 'Erken Doğum')
```

### Adım 4: Anne 106 seed data

```sql
-- 106 Supabase'e eklenmeyecek, sadece doğum kaydı tutulacak
-- anne_id = NULL, buzağı durum = 'Ölü', doğum_tipi = 'Erken Doğum'
-- Not: Anne satıldı bilgisi bu dosyada arşivlendi
```

---

## Faz 3 — Aşılama Kayıtları (opsiyonel, tablo varsa)

- Sıra 33-76: Coglavax + Feedlot aşıları yapıldı (rapelli)
- Sıra 77-80: Coglavax + Feedlot 25 Mayıs 2026'da yapıldı (rapel yok)

---

## Ham Veri (referans)

| Anne Küpe | Doğum Tarihi | Cinsiyet | Sıra | Not | Anne UUID |
|-----------|-------------|----------|------|-----|-----------|
| 5621 | 2025-09-15 | dana | 33 | ₺ | 87323e7b |
| 145 | 2025-09-17 | dana | 34 | ₺ | a4c61f97 |
| 177 | 2025-09-17 | dana | 35 | ₺ | ❓ |
| 142 | 2025-10-06 | düve | 36 | ++ | 143fbad6 |
| 153 | 2025-10-08 | düve | 37 | ex, tendon kontraktürü | 6f4f3c76 |
| 182 | 2025-10-14 | düve | 38 | ++ | ff007c90 |
| 107 | 2025-10-19 | dana | 39 | - | **NULL** |
| Küpesiz düve | 2025-10-21 | dana | 40 | ₺ | **NULL** |
| 008 | 2025-10-29 | dana | 41 | ₺ | fa8e6daa |
| 167 | 2025-11-02 | dana | 42 | ₺ | 4211de36 |
| 178 | 2025-11-03 | dana | 43 | - | 1ae146e4 |
| 162→904 | 2025-11-07 | dana | 44 | - | 00ca7aa3 |
| 197 | 2025-11-09 | düve | 45 | - | 9dc8cbae |
| 191 | 2025-11-13 | düve | 46 | - | 01ae80a9 |
| 155 | 2025-11-13 | dana | 47 | - | 115011e1 |
| 5708 | 2025-11-15 | dana | 48 | | c8861b6f |
| 2045→905 | 2025-11-16 | dana | 49 | +- | d607db2d |
| 179 | 2025-11-16 | düve | 50 | ex | **NULL** |
| 195 | 2025-11-17 | düve | 51 | +- | bac3b8f8 |
| 181 | 2025-11-23 | dana | 52 | ex | c4c1c3d6 |
| 199 | 2025-11-29 | dana | 53 | Alaca holstein | e31a60e5 |
| 147 | 2025-12-03 | dana | 54 | Norveç | 3b8b66ba |
| 196 | 2025-12-04 | düve | 55 | Alaca holstein | **NULL** |
| 101 | 2025-12-08 | düve | 56 | red holstein | e9d582a1 |
| 5638 | 2025-12-09 | düve | 57 | ex, red holstein | 456d7c6d |
| Minik panda | 2025-12-12 | dana | 58 | ex, red | **NULL** |
| 5748 | 2025-12-14 | dana | 59 | red | **NULL** |
| 7125 | 2025-12-15 | dana | 60 | red | **NULL** |
| 1956→903 | 2025-12-18 | düve | 61 | red | 4aee4470 |
| 154 | 2025-12-23 | düve | 62 | alaca iri | 34e04643 |
| 159 | 2025-12-23 | düve | 63 | ex, alaca küçük | **NULL** |
| 187 | 2026-01-12 | dana | 64 | -- | acbbc7ce |
| 161 | 2026-01-17 | dana | 65 | -- | **NULL** |
| 189 | 2026-02-02 | dana | 66 | ex (kronik pnömoni) | 1433f5f2 |
| 106 | 2026-02-03 | dana | xx | ex (erken doğum), anne satıldı | **NULL** |
| 141 | 2026-02-05 | dana | 67 | -- | 1f0706c0 |
| 176 | 2026-02-06 | düve | 68 | -- | 629a040e |
| 152 | 2026-02-07 | düve | 69 | -- | e641d149 |
| 115 | 2026-02-09 | dana | 70 | ex (diyafram spazmı) | d9e1838e |
| 134 | 2026-02-10 | dana | 71 | -- | 38e3ec48 |
| 175 | 2026-02-15 | dana | 72 | ex (rota ishali) | 995c15e1 |
| 183 | 2026-02-16 | dana | 73 | -- | f454bdd3 |
| 121 | 2026-02-19 | düve | 74 | -- | f7ae4a63 |
| 146 | 2026-03-19 | düve | 75 | -- | 4f56df98 |
| 192 | 2026-03-19 | dana | 76 | -- | 1841c6e0 |
| 901 | 2026-04-08 | düve | 77 | -- İKİZ | 88449c15 |
| 901 | 2026-04-08 | düve | 78 | -- İKİZ | 88449c15 |
| 173 | 2026-04-14 | düve | 79 | -- | 548df203 |
| 180 | 2026-04-16 | dana | 80 | -- | b6053753 |
