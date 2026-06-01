---
id: "044"
title: "Buzağı Toplu Giriş — 49 kayıt (Eylül 2025 – Nisan 2026)"
status: completed
phase: "3-asi-kayitlari"
created: 2026-05-31
updated: 2026-06-01
completed: 2026-06-01
---

# Buzağı Toplu Giriş Planı

## Özet

49 buzağı kaydı sisteme girildi. Faz 1-2-3 tamamlandı. Tüm veri tutarlı.

---

## Faz 1 — Eksik Anne Eşleştirme ✅ TAMAMLANDI

### Ham veri

| Sıra | Anne Küpe | Durum | Sonuç |
|------|-----------|-------|-------|
| 33 | 5621 | dana, satıldı (₺) | UUID: `87323e7b-…` |
| 34 | 145 | dana, satıldı (₺) | UUID: `a4c61f97-…` |
| 35 | **177** | dana, satıldı (₺) | **DB'de yok → NULL** |
| 36 | 142 | düve | UUID: `143fbad6-…` |
| 37 | 153 | düve, ölü | UUID: `6f4f3c76-…` |
| 38 | 182 | düve | UUID: `ff007c90-…` |
| 39 | **107** | dana | **NULL** |
| 40 | **Küpesiz düve** | dana, satıldı | **NULL** |
| 41 | 008 | dana, satıldı | UUID: `fa8e6daa-…` |
| 42 | 167 | dana, satıldı | UUID: `4211de36-…` |
| 43 | 178 | dana | UUID: `1ae146e4-…` |
| 44 | **162→904** | dana | UUID: `00ca7aa3-…` ✅ Eskij (çift küpe) |
| 45 | 197 | düve | UUID: `9dc8cbae-…` |
| 46 | 191 | düve | UUID: `01ae80a9-…` |
| 47 | 155 | dana | UUID: `115011e1-…` |
| 48 | 5708 | dana | UUID: `c8861b6f-…` |
| 49 | **2045→905** | dana | UUID: `d607db2d-…` ✅ Eskij (çift küpe) |
| 50 | **179** | düve, ölü | **NULL** |
| 51 | 195 | düve | UUID: `bac3b8f8-…` |
| 52 | 181 | dana, ölü | UUID: `c4c1c3d6-…` |
| 53 | 199 | dana, Alaca Holstein | UUID: `e31a60e5-…` |
| 54 | 147 | dana, Norveç | UUID: `3b8b66ba-…` |
| 55 | **196** | düve, Alaca Holstein | **NULL** |
| 56 | 101 | düve, Red Holstein | UUID: `e9d582a1-…` |
| 57 | 5638 | düve, Red Holstein, ölü | UUID: `456d7c6d-…` |
| 58 | **Minik panda** | dana, Red Holstein, ölü | **NULL** |
| 59 | **5748** | dana, Red Holstein | **NULL** |
| 60 | **7125** | dana, Red Holstein | **NULL** |
| 61 | **1956→903** | düve, Red Holstein | UUID: `4aee4470-…` ✅ Eskij |
| 62 | 154 | düve, Alaca Holstein | UUID: `34e04643-…` |
| 63 | **159** | düve, Alaca Holstein, ölü | **NULL** |
| 64 | 187 | dana | UUID: `acbbc7ce-…` |
| 65 | **161** | dana | **NULL** |
| 66 | 189 | dana, ölü | UUID: `1433f5f2-…` |
| xx | **106** | dana, ölü, erken doğum | **Arşiv** ✔ |
| 67 | 141 | dana | UUID: `1f0706c0-…` |
| 68 | 176 | düve | UUID: `629a040e-…` |
| 69 | 152 | düve | UUID: `e641d149-…` |
| 70 | 115 | dana, ölü | UUID: `d9e1838e-…` |
| 71 | 134 | dana | UUID: `38e3ec48-…` |
| 72 | 175 | dana, ölü | UUID: `995c15e1-…` |
| 73 | 183 | dana | UUID: `f454bdd3-…` |
| 74 | 121 | düve | UUID: `f7ae4a63-…` |
| 75 | 146 | düve | UUID: `4f56df98-…` |
| 76 | 192 | dana | UUID: `1841c6e0-…` |
| 77 | 901 | düve (ikiz) | UUID: `88449c15-…` |
| 78 | 901 | düve (ikiz) | UUID: `88449c15-…` |
| 79 | 173 | düve | UUID: `548df203-…` |
| 80 | 180 | dana | UUID: `b6053753-…` |

### Sonuç

- **37 eşleşme** → UUID alındı
- **1 eksik (177)** → DB sorgulandı, kayıt yok → `anne_id = NULL`
- **10 NULL** (107, 179, 196, 5748, 7125, 159, 161, 106, Küpesiz düve, Minik panda)
- **1 arşiv (106)** → seed kabul edildi, `dogum_tipi = 'Erken Doğum'`

Detaylı rapor: `docs/superpowers/plans/2026-05-31-buzagi-toplu-giris-faz1-sonuc.md`

---

## Faz 2 — Toplu Insert ✅ TAMAMLANDI

**Migration:** `supabase/migrations/20260601000001_buzagi_toplu_giris.sql`

### Adım 1: Anne UUID Haritası
- 38/38 tamam (37 UUID + 1 NULL)

### Adım 2: `hayvanlar` INSERT
- 49 kayıt eklendi
- `gen_random_uuid()::text` ile ID üretildi

### Adım 3: `dogum` INSERT
- 49 kayıt eklendi (1 Erken Doğum, 48 Normal)

### Adım 4: Duplicate cleanup
- `kupe_no=78` seed'da zaten vardı (`2026-05-27`)
- Seed kaydı (`daaa2054`) korundu, yeni kayıt (`b315771e`) silindi
- `cases` FK hatası temizlendi
- 78'in `anne_id`'si NULL kalmıştı → `88449c15` (anne 901) atandı

### Veri Doğrulama

| Metrik | Değer |
|--------|-------|
| hayvanlar | 49 (unique) |
| dogum | 49 (unique) |
| Durum | 33 Aktif, 10 Ölü, 6 Satıldı |
| Cinsiyet | 20 Dişi, 29 Erkek |
| Anne NULL | 11 (bulunamayan) |

---

## Faz 3 — Aşılama Kayıtları ✅ TAMAMLANDI

### Grup 33-76 (44 buzağı) — Direct INSERT
- Coglavax (`1705d3a1`, 4ml, SC, 365g rapel)
- Feedlot (`785eeb55`, 5ml, SC, 365g rapel)
- Her buzağı: 1.doz (doğum+60g) + rapel (doğum+90g)
- **176 kayıt** `vaccination_log`'a eklendi

### Grup 77-80 (4 buzağı) — `add_vaccination` RPC
- Tarih: 2026-05-25
- Her buzağı: Coglavax + Feedlot (2 kayıt)
- **8 kayıt** `vaccination_log`'a eklendi
- **8 ASI_RAPEL görevi** `gorev_log`'a oluşturuldu
  - Hedef tarih: 2027-05-25
  - Durum: `tamamlandi=false` (bekliyor)
  - Sistem 2027'de kullanıcıya hatırlatacak

### Toplam Aşı Kaydı
- **184 kayıt** `vaccination_log`'da
- **8 açık ASI_RAPEL görevi** `gorev_log`'da

---

## İstatistik

| Buzağı # | Anne Küpe | Cinsiyet | Doğum Tarihi | Durum | Anne UUID | Aşı |
|----------|-----------|----------|--------------|-------|-----------|-----|
| 33 | 5621 | Erkek | 2025-09-15 | Satıldı | ✅ | ✅ |
| 34 | 145 | Erkek | 2025-09-17 | Satıldı | ✅ | ✅ |
| 35 | 177 | Erkek | 2025-09-17 | Satıldı | ❌ NULL | ✅ |
| 36 | 142 | Dişi | 2025-10-06 | Aktif | ✅ | ✅ |
| 37 | 153 | Dişi | 2025-10-08 | Ölü | ✅ | ✅ |
| 38 | 182 | Dişi | 2025-10-14 | Aktif | ✅ | ✅ |
| 39 | 107 | Erkek | 2025-10-19 | Aktif | ❌ NULL | ✅ |
| 40 | Küpesiz düve | Erkek | 2025-10-21 | Satıldı | ❌ NULL | ✅ |
| 41 | 008 | Erkek | 2025-10-29 | Satıldı | ✅ | ✅ |
| 42 | 167 | Erkek | 2025-11-02 | Satıldı | ✅ | ✅ |
| 43 | 178 | Erkek | 2025-11-03 | Aktif | ✅ | ✅ |
| 44 | 162→904 | Erkek | 2025-11-07 | Aktif | ✅ | ✅ |
| 45 | 197 | Dişi | 2025-11-09 | Aktif | ✅ | ✅ |
| 46 | 191 | Dişi | 2025-11-13 | Aktif | ✅ | ✅ |
| 47 | 155 | Erkek | 2025-11-13 | Aktif | ✅ | ✅ |
| 48 | 5708 | Erkek | 2025-11-15 | Aktif | ✅ | ✅ |
| 49 | 2045→905 | Erkek | 2025-11-16 | Aktif | ✅ | ✅ |
| 50 | 179 | Dişi | 2025-11-16 | Ölü | ❌ NULL | ✅ |
| 51 | 195 | Dişi | 2025-11-17 | Aktif | ✅ | ✅ |
| 52 | 181 | Erkek | 2025-11-23 | Ölü | ✅ | ✅ |
| 53 | 199 | Erkek | 2025-11-29 | Aktif | ✅ | ✅ |
| 54 | 147 | Erkek | 2025-12-03 | Aktif | ✅ | ✅ |
| 55 | 196 | Dişi | 2025-12-04 | Aktif | ❌ NULL | ✅ |
| 56 | 101 | Dişi | 2025-12-08 | Aktif | ✅ | ✅ |
| 57 | 5638 | Dişi | 2025-12-09 | Ölü | ✅ | ✅ |
| 58 | Minik panda | Erkek | 2025-12-12 | Ölü | ❌ NULL | ✅ |
| 59 | 5748 | Erkek | 2025-12-14 | Aktif | ❌ NULL | ✅ |
| 60 | 7125 | Erkek | 2025-12-15 | Aktif | ❌ NULL | ✅ |
| 61 | 1956→903 | Dişi | 2025-12-18 | Aktif | ✅ | ✅ |
| 62 | 154 | Dişi | 2025-12-23 | Aktif | ✅ | ✅ |
| 63 | 159 | Dişi | 2025-12-23 | Ölü | ❌ NULL | ✅ |
| 64 | 187 | Erkek | 2026-01-12 | Aktif | ✅ | ✅ |
| 65 | 161 | Erkek | 2026-01-17 | Aktif | ❌ NULL | ✅ |
| 66 | 189 | Erkek | 2026-02-02 | Ölü | ✅ | ✅ |
| xx | 106 | Erkek | 2026-02-03 | Ölü | ❌ Arşiv | ✅ |
| 67 | 141 | Erkek | 2026-02-05 | Aktif | ✅ | ✅ |
| 68 | 176 | Dişi | 2026-02-06 | Aktif | ✅ | ✅ |
| 69 | 152 | Dişi | 2026-02-07 | Aktif | ✅ | ✅ |
| 70 | 115 | Erkek | 2026-02-09 | Ölü | ✅ | ✅ |
| 71 | 134 | Erkek | 2026-02-10 | Aktif | ✅ | ✅ |
| 72 | 175 | Erkek | 2026-02-15 | Ölü | ✅ | ✅ |
| 73 | 183 | Erkek | 2026-02-16 | Aktif | ✅ | ✅ |
| 74 | 121 | Dişi | 2026-02-19 | Aktif | ✅ | ✅ |
| 75 | 146 | Dişi | 2026-03-19 | Aktif | ✅ | ✅ |
| 76 | 192 | Erkek | 2026-03-19 | Aktif | ✅ | ✅ |
| 77 | 901 | Dişi | 2026-04-08 | Aktif | ✅ | ✅* |
| 78 | 901 | Dişi | 2026-04-08 | Aktif | ✅ | ✅* |
| 79 | 173 | Dişi | 2026-04-14 | Aktif | ✅ | ✅* |
| 80 | 180 | Erkek | 2026-04-16 | Aktif | ✅ | ✅* |

\* 77-80: ASI_RAPEL görevi oluşturuldu (hedef: 2027-05-25)

---

## Blokerler & Tespitler

### 🔴 Sistem Sorunları (Sistem — görevle ilgili değil, genel)

Aşağıdaki sorunlar `top` çıktısında tespit edildi:

| Sorun | PID | Süre | Detay |
|-------|-----|------|-------|
| **Stuck git pre-push hook** | 14499 | 615 dk (10+ saat!) | `bash .git/hooks/pre-push` — 100% CPU, stuck `git rm --cached -r .remember/` |
| **İkinci pre-push hook** | 14498 | 560 dk | `sh -c cd ... && git rm --cached -r .remember/` — beklemede |
| **Zombie process** | 14493 | — | `git` zombie (zombie parent) |
| **Zombie process** | 14503 | — | `sort` zombie |
| **Zombie process** | 14502 | — | `grep` zombie |
| **Swap kullanımı** | — | — | 1.9GB / 4.8GB swap dolu (~40%) |
| **RAM** | — | — | 6.3GB / 7.7GB kullanımda (~82%) |

**En kritik:** Pre-push hook'u `.remember/` dizinini git'ten untrack etmeye çalışırken takılıp kalmış, 10+ saattir bir CPU core'u tüketiyor. Bu hook muhtemelen `.git/hooks/pre-push` içinde tanımlı ve her push'ta tetikleniyor. PID 14499 kill edilmeli veya hook devre dışı bırakılmalı.

```bash
# 1. Stuck hook'u öldür
kill 14499 14498

# 2. Zombie temizleme (parent process kill)
kill -9 14493 14503 14502   # veya wait ile temizlenir

# 3. Hook'u incele/devre dışı bırak
cat .git/hooks/pre-push

# 4. .remember/ varsa handle et
ls -la .remember/
git rm -r --cached .remember/ 2>/dev/null || true
```
