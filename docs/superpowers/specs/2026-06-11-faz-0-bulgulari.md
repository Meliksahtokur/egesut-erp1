# BUG-059 — Faz 0 Pre-Check Bulguları

> **Tarih:** 2026-06-11
> **Amaç:** Spec yazımı → canlı DB drift kontrolü (Pato 12)
> **Referans:** 99999999999999_ground_truth.sql + 120+ ara migration

## Yöntem

7 adımda canlı DB doğrulandı:
1. Canonical ground truth (ara migration DEĞİL)
2. Canlı şema (curl REST + supabase_query)
3. Geçmiş bug pattern taraması (memory_search)
4. 5 aktif vaka snapshot
5. tools-bank memory RPC notları
6. GitNexus blast radius
7. Stratejik karar (planned_time vs treatment_time)

## 🔴 KRİTİK DRİFT (Spec'te düzeltildi)

### D1. `gorev_log.id` tipi yanlış
- **Spec'te:** "`text` ama UUID string saklar"
- **Ground truth (L48):** `uuid PRIMARY KEY DEFAULT gen_random_uuid()`
- **Canlı:** uuid (doğrulandı)
- **Aksiyon:** spec'te "INSERT gen_random_uuid()::text" → "INSERT gen_random_uuid()"

### D2. `uygulama_tamamlandi_at` kolonu
- **Spec'te:** `treatment_day_uygulamalar.uygulama_tamamlandi_at` (done durumu)
- **Canlı:** Bu kolon **yok** (YENİ tablo, eklenecek) → Spec doğru, migration gerekli ✅
- **Ama spec'te treatment_time konsepti eksik** → bkz. D3

### D3. treatment_time vs planned_time (stratejik karar)
- **Canlıda 2 kolon var:**
  - `treatment_days.treatment_time` (2026-03-25 migration 025, sahada gerçekleşen saat)
  - `treatment_days.planned_time` (2026-05-28 migration 037, planlanan saat)
- **Spec'te:** sadece `planned_time` (seans seviyesinde YENİ) var, `treatment_time` YOK
- **Kullanıcı kararı:** iki kolon ayrı amaçlara hizmet eder
  - `planned_time` = **planlanan** saat (veteriner kararı)
  - `treatment_time` = **gerçekleşen** saat (uygulayıcı sahada tamamlayınca)
- **Yeni eklenen:** `treatment_day_uygulamalar.gerceklesme_saati time` (seans seviyesinde, sizin isteğinize göre)
- **Aksiyon:** spec'e `treatment_days.treatment_time` (gün seviyesi) + `treatment_day_uygulamalar.gerceklesme_saati` (seans seviyesi) eklendi

## 🟡 EK KOLONLAR (Drift değil, gözden kaçmış)

- `stok_hareket.tarih, referans_tipi, referans_id` — Canlıda var, ground truth'ta yok
- `stok.tur, birim_turu, maliyet, drug_product_id` — Canlıda var, ground truth'ta yok
- `ground_truth.sql` artık **canonical değil** — 2026-03-25 sonrası 120+ migration drift
- **Aksiyon:** Spec'te "ground truth L48" gibi referanslar → "migration NNN" referanslarına çevrilecek (Faz 3'te ground truth sync yapılacak)

## 🎯 GERÇEK TEST HEDEFİ

5 aktif vaka (Faz 0 Step 0.4 doğrulandı):

| Case | Hayvan | Gün | Tamamlanmış | Notu |
|---|---|---|---|---|
| 1db49a4e | H000142 | 3 | 3 | trivial pass |
| 57bfc92c | H000088 | 3 | 3 | trivial pass |
| a09f0d0b | 1433f5f2 (uuid) | 1 | 1 | trivial pass |
| **c4ff42d9** | **H000144 (Enterit)** | **5** | **3** | 🎯 **GERÇEK TEST** |
| eb10376a | 1433f5f2 (uuid) | 0 | 0 | trivial pass |

**c4ff42d9 detay:**
- Gün 1-3: 07:00:00 (sabah rutin tedavi) — tamamlanmış
- Gün 4: treatment_time=NULL, planned_time=NULL, ilaç eklendi (5ml IM, stok a4584fce) — tamamlanmamış
- Gün 5: henüz ilaç yok — tamamlanmamış

**12 tedavi günü, 10 tamamlanmış, 2 devam eden** (c4ff42d9'da 2 gün) — Plan P5 verisi doğrulandı.

## ✅ GitNexus Blast Radius (Step 0.6)

**Mevcut UI çağrı yerleri:**
- `caseDayTamamla` (ui.js:4532) — `treatment_day_tamamla` çağrısı
- `caseGunEkleOnayla` (ui.js:4688) — `add_treatment_day` çağrısı
- `tedavi-gun-tamamla` (handlers.js:219) — Yeni handler eklenecek
- `_tedaviGunExecute` (ui.js:4033) — Tedavi günü işlemleri

**Eski migration'lar:**
- 20260325000025 (treatment_time) + 20260325075027 (timeline view) + 20260528000001 (planned_time + uygulanmadi)

## Stratejik Kararlar (Faz 0'da alındı)

1. **K1 (`stok_hareket.id` text):** Spec zaten doğru yazmış ✅
2. **planned_time vs treatment_time:** iki kolon ayrı amaçlara hizmet eder, ikisi de yaşar
3. **`treatment_day_uygulamalar` tablosu + yeni `gerceklesme_saati` kolonu** ile saat-bazlı seans mimarisi
4. **Yeni RPC:** `add_treatment_day_with_sessions` — sarmalayıcı (eski `add_treatment_day` + N×`add_drug_administration` yerine atomik)
5. **5 vaka geriye uyumluluk:** seans_sayisi=1 (eski) → yeni tablo boş, eski akış çalışır; seans_sayisi>=2 (yeni) → alt tablo dolu

## Faz 1'e Geçiş Koşulu

✅ Tüm 7 step tamamlandı
✅ 3 kritik drift düzeltildi (spec v4 → v5)
✅ 5 vaka snapshot doğrulandı
✅ c4ff42d9 gerçek test hedefi olarak belirlendi
✅ 1 stratejik karar (planned_time/treatment_time ayrımı) netleşti

**Faz 1 başlatılabilir:** Schema migration (treatment_day_uygulamalar + gerceklesme_saati + seans_sayisi + seans_admin_id)
