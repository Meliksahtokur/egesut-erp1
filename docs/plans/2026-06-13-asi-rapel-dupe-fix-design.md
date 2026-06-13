# Aşı 2. Doz Duplicate Görev Fix — Tasarım

> **Tarih:** 2026-06-13
> **Kapsam:** Sadece aşı 2. doz (Rota-Corona) görev tekrarı
> **Sorun:** `ileri_gebe_asi_tamamla`, `gebelik_protokol_kontrol`, `ileri_gebe_gorev_kontrol` aynı görevi farklı zamanlarda iki kez yaratabiliyor
> **Çözüm:** Semantic key (`etken_kod='ROTA_2DOZ'`) + UNIQUE partial index
> **Branch:** main (hotfix) — `feature/asilama-tam-mimari` değil
> **Yazar:** Pi agent (MiniMax-M3) + kullanıcı brainstorm

---

## 0. Özet (1 paragraf)

Bugün (2026-06-13) aynı düve için iki adet "Rota-Corona 2. doz" görevi görünüyor. Bunun nedeni: aşı 1. doz tamamlandığında `ileri_gebe_asi_tamamla` bir rapel görevi oluşturuyor; 261. gün geldiğinde `gebelik_protokol_kontrol` ve/veya `ileri_gebe_gorev_kontrol` **ayrı bir görev** daha oluşturuyor. Dedupe kontrolü `aciklama` text'i üzerinden yapıldığı için eski string formatındaki kayıtlar yeni scan'lerde görünmüyor. Bu fix, dedupe anahtarını `etken_kod` semantik alanına taşıyor ve `UNIQUE PARTIAL INDEX` ile atomik koruma sağlıyor. 3 yol birleştirilmiyor (kullanıcı scope kararı), sadece duplicate oluşumu engelleniyor.

---

## 1. Sorunun Kök Nedeni

### 1.1 Gözlem (canlı DB kanıtı)

Bugün küpe **184** için iki kayıt:

| id | aciklama | hedef_tarih | tamamlandi | parent_id | kaynak | created_at |
|---|---|---|---|---|---|---|
| `2caf290b-...` | 💉 Rota-Corona Aşısı **(2. doz)** | 2026-06-12 | ✅ true | `dda9dbcb-...` | `ILERI_GEBE-184` | 2026-05-22 16:29 |
| `16de0128-...` | 💉 Rota-Corona Aşısı **(2. doz — düve)** | 2026-06-12 | ❌ false | NULL | NULL | 2026-06-12 03:10 |

Aynı düve, aynı hedef tarih, aynı stok — ama farklı `aciklama` string'i.

### 1.2 Neden oluştu (zaman çizelgesi)

| Tarih | Olay | Sonuç |
|---|---|---|
| 2026-05-09 | 1. doz uygulandı | `ileri_gebe_asi_tamamla` (eski hali) tetiklendi |
| 2026-05-22 | Eski `ileri_gebe_asi_tamamla` → rapel oluşturuldu: `'(2. doz)'` (düve'siz) | Kayıt `2caf290b` (parent_id dolu) |
| 2026-05-25 | Migration `20260525000003_rota_rapel_duve_kontrol.sql` deploy | `ileri_gebe_asi_tamamla` artık `'(2. doz — düve)'` yazıyor |
| 2026-06-12 03:10 | `gebelik_protokol_kontrol` cron çalıştı | 261. gün düve kriteri → `NOT EXISTS WHERE aciklama='(2. doz — düve)'` sorgusu eski `(2. doz)` kaydını görmedi → yeni kayıt `16de0128` |

### 1.3 Neden bug var: 3 temel neden

**(a) String drift:** Migration ile `aciklama` text'i değişti (`(2. doz)` → `(2. doz — düve)`). Eski kayıtlar yeni string'i taşımıyor.

**(b) Dedupe text-based:** Tüm 3 yolda `NOT EXISTS` veya `ON CONFLICT DO NOTHING` `aciklama` üzerinden çalışıyor. Farklı string = farklı kayıt = duplicate.

**(c) Non-atomic dedupe:** `NOT EXISTS ... + INSERT ... SELECT` PostgreSQL default `READ COMMITTED` izolasyonunda atomik değil. İki paralel transaction aynı kontrolü yapıp aynı INSERT'i yapabilir.

### 1.4 Hangi fonksiyonlar etkilendi

| Fonksiyon | Rol | Şu anki dedupe | Fix sonrası |
|---|---|---|---|
| `ileri_gebe_asi_tamamla` | 1. doz tamamlanınca rapel oluşturur | `ON CONFLICT DO NOTHING` (anlamsız, UNIQUE yok) | `etken_kod='ROTA_2DOZ'` + UNIQUE koruması |
| `gebelik_protokol_kontrol` | 261. gün gelince preventive oluşturur | `NOT EXISTS WHERE aciklama='(2. doz — düve)'` | `etken_kod='ROTA_2DOZ'` + UNIQUE koruması |
| `ileri_gebe_gorev_kontrol` | 261. gün gelince preventive oluşturur (eski) | `NOT EXISTS WHERE aciklama='(2. doz — düve)'` | `etken_kod='ROTA_2DOZ'` + UNIQUE koruması |

---

## 2. Çözüm Tasarımı

### 2.1 Yaklaşım: Semantic Key + UNIQUE Constraint

**Neden `etken_kod`?** Çünkü:
- `etken_kod` semantik bir alan (ROTA, ROTA_2DOZ, ADEMIN, E_VIT, vb.) — kullanıcı diline/UI metnine bağlı değil
- 1. doz zaten `etken_kod='ROTA'` kullanıyor (migration 20260509000004 + 20260610000001)
- `aciklama` UI presentation katmanı — değişmesi doğal
- Aynı etken_kod altında 1 aktif kayıt kuralı, domain mantığıyla uyumlu

### 2.2 Neden UNIQUE partial index?

- **Atomic:** Constraint kontrolü transaction commit anında yapılır, race condition imkansız
- **DB seviyesinde:** Client tarafı hatalarından bağımsız
- **Partial:** Sadece aktif kayıtları kısıtlar; tamamlanmış/iptal edilmiş görevler birikebilir (audit trail)
- **Performanslı:** Index sadece `WHERE` koşuluna uyan küçük subset üzerinde

### 2.3 Neden 3 yol birleştirilmiyor?

Kullanıcı kararı: scope sadece duplicate engelleme. 3 yolun teke indirilmesi (mimari iş) ayrı bir refactor olarak `feature/asilama-tam-mimari` branch'inde kalır. Bu fix minimal müdahale ile kritik bug'ı çözer.

---

## 3. Schema Değişikliği (Migration İçeriği)

### 3.1 Bileşen 1: Backfill — mevcut kayıtlara `etken_kod='ROTA_2DOZ'` yaz

```sql
-- Mevcut 2. doz kayıtlarını semantik anahtarla işaretle
-- (1. doz 'ROTA', 2. doz artık 'ROTA_2DOZ')
UPDATE gorev_log
SET etken_kod = 'ROTA_2DOZ'
WHERE gorev_tipi = 'ILERI_GEBE_ASI'
  AND aciklama ILIKE '%Rota-Corona%2. doz%'
  AND etken_kod IS NULL;
```

**Neden:** UNIQUE constraint aktif duplicate'leri yakalayabilsin. Backfill olmadan eski kayıtlar constraint'in dışında kalır → hala duplicate oluşabilir.

### 3.2 Bileşen 2: UNIQUE Partial Index

```sql
CREATE UNIQUE INDEX IF NOT EXISTS uq_gorev_rota_2doz_active
  ON gorev_log (hayvan_id, etken_kod)
  WHERE etken_kod = 'ROTA_2DOZ'
    AND iptal = false
    AND tamamlandi = false;
```

**Neden partial:** Tamamlanmış görevler (aşı gerçekten yapıldı, audit lazım) birikebilir. İptal edilmiş görevler (hatalı oluşmuş, temizlik geçmişi) birikebilir. Sadece aktif duplicate'leri kısıtla.

### 3.3 Bileşen 3: 3 RPC Güncellemesi

#### 3.3.1 `ileri_gebe_asi_tamamla` (rapel INSERT)

```sql
-- ESKİ:
INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, parent_id, kaynak)
VALUES (
  v_rapel_id, v_gorev.hayvan_id, 'ILERI_GEBE_ASI',
  '💉 Rota-Corona Aşısı (2. doz — düve)', v_rapel_tarih, false,
  v_gorev.stok_id, 1, v_gorev.id, 'ILERI_GEBE'
)
ON CONFLICT DO NOTHING;
-- ↑ UNIQUE constraint yok → anlamsız

-- YENİ:
INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, parent_id, kaynak, etken_kod)
VALUES (
  v_rapel_id, v_gorev.hayvan_id, 'ILERI_GEBE_ASI',
  '💉 Rota-Corona Aşısı (2. doz — düve)', v_rapel_tarih, false,
  v_gorev.stok_id, 1, v_gorev.id, 'ILERI_GEBE',
  'ROTA_2DOZ'  -- ← yeni
)
ON CONFLICT (hayvan_id, etken_kod) WHERE etken_kod='ROTA_2DOZ' AND iptal=false AND tamamlandi=false DO NOTHING;
-- ↑ UNIQUE index ile çalışır
```

**Not:** PostgreSQL `ON CONFLICT (cols) WHERE ...` syntax'ını destekler — partial index üzerinde çalışır.

#### 3.3.2 `gebelik_protokol_kontrol` (261. gün INSERT)

```sql
-- ESKİ:
INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, ref_tohumlama_id)
SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
       '💉 Rota-Corona Aşısı (2. doz — düve)', v_hedef, false, v_stok_id, 1, v_toh.id::text
WHERE NOT EXISTS (
  SELECT 1 FROM gorev_log
  WHERE hayvan_id = v_toh.hayvan_id
    AND aciklama = '💉 Rota-Corona Aşısı (2. doz — düve)'
    AND iptal = false
);

-- YENİ:
INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, ref_tohumlama_id, etken_kod)
SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
       '💉 Rota-Corona Aşısı (2. doz — düve)', v_hedef, false, v_stok_id, 1, v_toh.id::text,
       'ROTA_2DOZ'  -- ← yeni
WHERE NOT EXISTS (
  SELECT 1 FROM gorev_log
  WHERE hayvan_id = v_toh.hayvan_id
    AND etken_kod = 'ROTA_2DOZ'  -- ← aciklama yerine etken_kod
    AND iptal = false
    AND tamamlandi = false  -- ← partial index ile uyumlu
);
```

#### 3.3.3 `ileri_gebe_gorev_kontrol` (261. gün INSERT) — aynı değişiklik

Yukarıdaki `gebelik_protokol_kontrol` değişikliğinin birebir aynısı.

### 3.4 Bileşen 4: Mevcut Duplicate Temizliği

```sql
-- Aktif duplicate'leri (parent_id NULL olan) iptal et
-- Kural: aynı hayvan için etken_kod='ROTA_2DOZ' parent_id'li başka kayıt varsa
-- ve bizim kaydımız parent_id NULL ise → iptal (duplicate)
UPDATE gorev_log uzak
SET iptal = true,
    aciklama = aciklama || ' — duplicate temizlendi (2026-06-13 fix)',
    kapatan_ref = 'ASI_RAPEL_DUPE_CLEANUP'
WHERE uzak.gorev_tipi = 'ILERI_GEBE_ASI'
  AND uzak.etken_kod = 'ROTA_2DOZ'
  AND uzak.iptal = false
  AND uzak.parent_id IS NULL
  AND EXISTS (
    SELECT 1 FROM gorev_log legit
    WHERE legit.hayvan_id = uzak.hayvan_id
      AND legit.etken_kod = 'ROTA_2DOZ'
      AND legit.parent_id IS NOT NULL
      AND legit.iptal = false
  );
```

**Neden sadece `parent_id IS NULL` olan:** `ileri_gebe_asi_tamamla` her zaman `parent_id` set eder (1. doz görevinin ID'si). `gebelik_protokol_kontrol` ve `ileri_gebe_gorev_kontrol` `parent_id` set etmez. Dolayısıyla parent_id NULL olan = duplicate.

**Neden sadece legitimate kayıt varsa:** Eğer hayvan için SADECE `gebelik_protokol_kontrol` kayıt oluşturduysa (1. doz henüz yapılmadıysa), bu legitimate'tir, iptal etme. Sadece gerçekten duplicate olanları işaretle.

### 3.5 Bileşen 5: Audit Log

```sql
-- Temizlik özetini islem_log'a yaz
INSERT INTO islem_log (id, tip, snapshot)
SELECT
  gen_random_uuid()::text,
  'ASI_RAPEL_DUPE_CLEANUP',
  jsonb_build_object(
    'iptal_edilen_count', COUNT(*),
    'tarih', CURRENT_DATE,
    'migration', '20260613000001_asi_rapel_dupe_fix'
  )
FROM gorev_log
WHERE kapatan_ref = 'ASI_RAPEL_DUPE_CLEANUP'
  AND iptal = true;
```

---

## 4. Doğrulama (supabase_migrate ile — çalıştırma SONRA)

### 4.1 Migration öncesi snapshot

```sql
-- Duplicate sayısı (cleanup öncesi)
SELECT hayvan_id, COUNT(*) AS aktif_2doz
FROM gorev_log
WHERE etken_kod = 'ROTA_2DOZ' AND iptal = false
GROUP BY hayvan_id HAVING COUNT(*) > 1;
-- Beklenti: 0 satır (henüz backfill yapılmadı, etken_kod NULL)

-- Veya aciklama bazlı
SELECT hayvan_id, COUNT(*) AS aktif_2doz
FROM gorev_log
WHERE aciklama ILIKE '%Rota-Corona%2. doz%' AND iptal = false
GROUP BY hayvan_id HAVING COUNT(*) > 1;
-- Beklenti: 2 hayvan (184 + bcc67af7)
```

### 4.2 Migration sonrası doğrulama

```sql
-- 1. UNIQUE constraint test (duplicate INSERT denemesi)
--    Beklenti: 1. INSERT başarılı, 2. INSERT unique_violation hatası
DO $$
DECLARE
  v_test_hayvan_id text := 'TEST-HAYVAN-' || gen_random_uuid()::text;
  v_first_id uuid;
  v_err text;
BEGIN
  -- Test hayvanı oluştur (yoksa)
  INSERT INTO hayvanlar (id, kupe_no, grup, durum)
  VALUES (v_test_hayvan_id, 'TEST-' || substring(v_test_hayvan_id, 1, 8), 'Test Grubu', 'Aktif')
  ON CONFLICT (id) DO NOTHING;

  -- 1. INSERT (başarılı olmalı)
  INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, etken_kod, hedef_tarih, tamamlandi, iptal)
  VALUES (gen_random_uuid(), v_test_hayvan_id, 'ILERI_GEBE_ASI', 'test 1', 'ROTA_2DOZ', CURRENT_DATE+10, false, false);

  -- 2. INSERT (UNIQUE violation beklenir)
  BEGIN
    INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, etken_kod, hedef_tarih, tamamlandi, iptal)
    VALUES (gen_random_uuid(), v_test_hayvan_id, 'ILERI_GEBE_ASI', 'test 2', 'ROTA_2DOZ', CURRENT_DATE+11, false, false);
    RAISE EXCEPTION 'TEST BAŞARISIZ: UNIQUE constraint çalışmıyor';
  EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'TEST BAŞARILI: UNIQUE violation yakalandı';
  END;

  -- Temizlik
  DELETE FROM gorev_log WHERE hayvan_id = v_test_hayvan_id;
  DELETE FROM hayvanlar WHERE id = v_test_hayvan_id;
END $$;

-- 2. Idempotency: aynı düve için 2. çağrıda olusturulan=0 olmalı
SELECT ileri_gebe_gorev_kontrol();
-- (olusturulan=0 dönmeli, çünkü tüm düveler için zaten kayıt var)

-- 3. Temizlik sonrası aktif duplicate sayısı
SELECT hayvan_id, COUNT(*) AS aktif_2doz
FROM gorev_log
WHERE etken_kod = 'ROTA_2DOZ' AND iptal = false
GROUP BY hayvan_id HAVING COUNT(*) > 1;
-- Beklenti: 0 satır

-- 4. İptal edilen duplicate sayısı
SELECT COUNT(*) AS iptal_edilen_duplicate
FROM gorev_log
WHERE kapatan_ref = 'ASI_RAPEL_DUPE_CLEANUP' AND iptal = true;
-- Beklenti: 2 (küpe 184 + bcc67af7)

-- 5. islem_log audit
SELECT * FROM islem_log
WHERE tip = 'ASI_RAPEL_DUPE_CLEANUP'
ORDER BY created_at DESC LIMIT 1;
-- Beklenti: 1 kayıt, snapshot.iptal_edilen_count = 2
```

### 4.3 Hata Pattern'leri (bilinen)

| Hata | Anlam | Aksiyon |
|---|---|---|
| `duplicate key value violates unique constraint "uq_gorev_rota_2doz_active"` | Beklenen, UNIQUE çalışıyor | ✅ Test başarılı |
| `column "etken_kod" does not exist` | `gorev_log`'da kolon yok (sürpriz!) | Migration'ı DURDUR, kolon ekle (önceki migration var mı kontrol) |
| `0 rows` dönen `RETURNING` | `ON CONFLICT` sessizce geçti | ✅ Doğru davranış |
| İkinci `ileri_gebe_gorev_kontrol()` çağrısında `olusturulan > 0` | Dedupe çalışmıyor | Migration geri al, debug |

---

## 5. Geri Alma

```sql
-- 1. Index'i kaldır
DROP INDEX IF EXISTS uq_gorev_rota_2doz_active;

-- 2. 3 RPC'yi eski haline döndür (migration dosyalarından)
--    (Bu dokümanda gösterilmedi, migration dosyasındaki CREATE OR REPLACE
--     bloğunu silmek yeterli)

-- 3. iptal edilen duplicate'leri geri al (opsiyonel, audit için bırakılabilir)
UPDATE gorev_log
SET iptal = false,
    aciklama = REPLACE(aciklama, ' — duplicate temizlendi (2026-06-13 fix)', ''),
    kapatan_ref = NULL
WHERE kapatan_ref = 'ASI_RAPEL_DUPE_CLEANUP';

-- 4. etken_kod='ROTA_2DOZ' backfill geri alınamaz (bilgi kaybı kabul edilebilir,
--    çünkü sadece semantik etiket, başka anlamı yok)
```

**Geri alma riski:** Düşük. Sadece INSERT davranışını değiştirir, var olan tamamlanmış görevlere dokunmaz.

---

## 6. Kapsam Dışı (Açıkça Hariç)

- 1. doz duplicate'leri (kullanıcı sadece 2. doz istedi)
- `SC Ademin` ve `IM E Vitamini` duplicate'leri (aynı pattern muhtemelen var, ayrı fix)
- 3 yolun (`ileri_gebe_gorev_kontrol` vs `gebelik_protokol_kontrol`) teke indirilmesi (mimari refactor, `feature/asilama-tam-mimari` branch'inde)
- Otomatik test framework kurulumu (pgTAP vb.) — manuel doğrulama yeterli
- `ileri_gebe_gorev_kontrol` scheduler'ı kaldırma — ayrı temizlik işi
- 1. doz → 2. doz tarih senkronizasyonu (gerçek 21 gün vs 261. gün farkı, ayrı konu)

---

## 7. Review Checklist (PR'ı review eden kişi için)

- [ ] Migration dosyası: `supabase/migrations/20260613000001_asi_rapel_dupe_fix.sql`
- [ ] Backfill `etken_kod='ROTA_2DOZ'` mevcut 2. doz kayıtlarına uygulandı mı?
- [ ] UNIQUE partial index doğru kolonlar ve `WHERE` koşulu ile oluşturuldu mu?
- [ ] `ileri_gebe_asi_tamamla` `etken_kod='ROTA_2DOZ'` ekliyor + `ON CONFLICT` UNIQUE ile çalışıyor mu?
- [ ] `gebelik_protokol_kontrol` 261. gün INSERT'i `etken_kod` bazlı dedupe kullanıyor mu?
- [ ] `ileri_gebe_gorev_kontrol` 261. gün INSERT'i `etken_kod` bazlı dedupe kullanıyor mu?
- [ ] Duplicate temizliği sadece `parent_id IS NULL` olanları iptal ediyor mu?
- [ ] `islem_log` audit kaydı oluşuyor mu?
- [ ] Tüm SQL blokları idempotent (re-runnable) mi? (`IF NOT EXISTS`, `CREATE OR REPLACE`)
- [ ] Bölüm 4.2 doğrulama sorguları çalıştırıldı mı, hepsi geçti mi?
- [ ] Bölüm 4.3 hata pattern'leri gözden geçirildi mi?

---

## 8. Referanslar

- **Live kanıt:** 2026-06-13 `supabase_query` çıktısı (küpe 184: `2caf290b` + `16de0128`)
- **Migration tarihçesi:**
  - `20260331000032_vaccination_module.sql` — `add_vaccination` RPC (etken_kod pattern başlangıcı)
  - `20260509000003_ileri_gebe_asi_tamamla.sql` — ilk rapel (string: `(2. doz)`)
  - `20260509000004_gebe_gorev_trigger.sql` — `fn_gebe_gorev_yarat` (1. doz + Ademin + E Vit)
  - `20260525000003_rota_rapel_duve_kontrol.sql` — string değişimi: `(2. doz)` → `(2. doz — düve)`
  - `20260603000005_protokol_fix_v2.sql` — `ileri_gebe_asi_tamamla` düve kontrolü geri alındı (string hâlâ `(2. doz)`!)
  - `20260605000008_gebe_trigger_update.sql` — `gebelik_protokol_kontrol` + `ileri_gebe_gorev_kontrol` (string: `(2. doz — düve)`)
  - **`20260613000001_asi_rapel_dupe_fix.sql`** ← BU FIX
- **Daha geniş aşılama mimarisi:** `docs/research/2026-06-12-asi-sistemi-mevcut-durum-ve-dilek.md`
- **Daha geniş plan:** `docs/plans/2026-06-12-asilama-tam-mimari-design.md` (3-yol birleştirme burada kalır)
