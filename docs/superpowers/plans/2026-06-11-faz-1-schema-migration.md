# Faz 1 — Schema Migration Planı

**Bağlam:** BUG-059 saat-bazlı seans yönetimi. Faz 0 (drift + stratejik karar) tamamlandı, push `6ff0c69`. DB yedek alındı (`egesut_20260611.pg.enc`, GitHub artifact 90 gün). 4 temel tablo ground truth ile %100 aynı — **drift yok**.

**Amaç:** Saat-bazlı seans mimarisini DB'ye kazandırmak. Mevcut şema 1-gün-1-ilaç varsayımıyla çalışıyor; gerçek tedavi çoklu seans + stok iade + recete güncelleme gerektiriyor.

---

## 1. Stratejik Karar (Faz 0 + Faz 1 gözden geçirme)

**Mevcut şema yetmez**, çünkü:
- `drug_administrations`'da **saat bilgisi yok** → günde 3 kez verilen ilaç ayırt edilemez
- Stok iade `stok_hareket.referans_tipi` üzerinden takip ediliyor → **mevcut pattern** bu, FK'a gerek yok
- 1 gün = 1 ilaç varsayımı recete güncelleme (sabah doz atla, sadece akşam) yapılamaz hale getiriyor

**Karar:**
- `route` CHECK → `drug_administrations` ile **aynı tuple** (`('IM','IV','SC','PO','Topikal','Intrauterin')`)
- `stok_hareket_ref` **KALDIRILDI** → `stok_hareket.referans_tipi='tedavi_seans' + referans_id=seans.id` ile çözülecek (mevcut `vaccination` pattern'iyle birebir)
- `UNIQUE(treatment_day_id, planned_time, stok_id)` → aynı saatte **farklı ilaçlar** olabilir (Antibiyotik + Vitamin 08:00'de), aynı saatte **aynı ilaç** 2 kez olamaz. UI "seans = uygulama zaman dilimi" semantiğine uygun.
- `sira_no` KALDIRILDI → `ORDER BY planned_time` zaten sıralama veriyor, ek kolon gereksiz
- `seans_sayisi` **NULL izni KALIYOR** → `seans_sayisi IS NULL` = "eski tek-seans, bilinmiyor" (geriye uyumlu, default YOK — eski satırlar NULL kalır), `seans_sayisi>=1` = "yeni çoklu-seans" (CHECK 0'ı blokluyor)

---

## 2. Yeni Tablo: `treatment_day_uygulamalar`

**Amaç:** Tedavi günü alt seansları. Her seans = 1 ilaç, 1 saat, 1 uygulama kaydı.

```sql
CREATE TABLE IF NOT EXISTS public.treatment_day_uygulamalar (
  -- KIMLIK
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  treatment_day_id            uuid NOT NULL REFERENCES public.treatment_days(id) ON DELETE CASCADE,
  case_id                     uuid NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,

  -- SEANS BİLGİSİ
  planned_time                time NOT NULL,
  planned_date                date NOT NULL,

  -- İLAÇ
  stok_id                     text REFERENCES public.stok(id),
  drug_product_id             uuid REFERENCES public.drug_products(id),
  dose                        numeric NOT NULL CHECK (dose > 0),
  unit                        text NOT NULL,
  route                       text CHECK (route IS NULL OR route IN ('IM','IV','SC','PO','Topikal','Intrauterin')),

  -- DONE STATE (seans seviyesi)
  uygulama_tamamlandi_at      timestamptz,
  uygulayan                   text,
  uygulama_notu               text,
  gerceklesme_saati           time,            -- Faz 0 fix: sahada gerceklestigi saat
  uygulanmadi                 boolean DEFAULT false,
  iptal_nedeni                text,

  -- AUDIT
  created_at                  timestamptz DEFAULT now(),
  updated_at                  timestamptz DEFAULT now(),

  -- KISITLAR
  -- planned_time + stok_id unique: ayni saatte farkli ilaclar olabilir
  -- (Antibiyotik + Vitamin 08:00'de), ayni ilac ayni saatte 2 kez OLAMAZ
  -- 5dk aralik kurali UI/validasyon katmaninda kontrol edilir
  UNIQUE(treatment_day_id, planned_time, stok_id)
);
```

**Stok referansı:** Bu tabloda `stok_hareket_ref` FK **YOK**. Stok düşümü `stok_hareket` tablosuna ayrı INSERT ile yapılır ve `referans_tipi='tedavi_seans'`, `referans_id=<bu seans.id>`. İptalde `stok_hareket.tur='iade'` ile yeni hareket yazılır (mevcut `vaccination` iade pattern'iyle birebir).

---

## 2.5 Kolon Hiyerarşisi Kuralı (H2 fix)

`treatment_days` ve `treatment_day_uygulamalar` arasında 3 zaman kolonu birlikte yaşayacak:

| Durum | `treatment_days.planned_time` | `treatment_days.treatment_time` | `treatment_day_uygulamalar.planned_time` | `treatment_day_uygulamalar.gerceklesme_saati` |
|---|---|---|---|---|
| **Eski tek-seans gün** (`seans_sayisi IS NULL`) | NULL veya set | Son uygulamanın saati | (bu gün için satır yok) | (bu gün için satır yok) |
| **Yeni tek-seans gün** (`seans_sayisi=1`) | Seansın `planned_time`'ı | Seansın `gerceklesme_saati`'si | Seansın `planned_time`'ı | Uygulayıcının set ettiği saat |
| **Yeni çoklu-seans gün** (`seans_sayisi>=2`) | İlk seansın `planned_time`'ı | Son seansın `gerceklesme_saati`'si | Her seans ayrı | Her seans ayrı |

**Trigger sorumluluğu (Faz 2'de yazılacak):**
- `treatment_day_uygulamalar` INSERT/UPDATE → `treatment_days.planned_time` ve `treatment_time`'ı yukarıdaki kurala göre güncelle
- Veya: RPC'ler bunu explicit set eder, trigger yok (Faz 2'de karar)

---

## 3. Mevcut Tablolara Kolon Ekleme (4 adet)

### 3.1 `treatment_days.seans_sayisi`

```sql
ALTER TABLE public.treatment_days
  ADD COLUMN IF NOT EXISTS seans_sayisi smallint
  CHECK (seans_sayisi IS NULL OR seans_sayisi > 0);  -- DEFAULT YOK: eski satirlar NULL = geriye uyumluluk

COMMENT ON COLUMN public.treatment_days.seans_sayisi
  IS 'Bu gun kac seans planlandi. NULL = eski tek-seans davranis (geriye uyumlu, default yok). N >= 1 = yeni coklu-seans.';
```

**Neden:** Eski günlerde `treatment_day_uygulamalar` satırı olmayacak. `seans_sayisi` ile yeni/legacy ayrımı yapılır.

### 3.2 `drug_administrations.seans_admin_id`

```sql
ALTER TABLE public.drug_administrations
  ADD COLUMN IF NOT EXISTS seans_admin_id uuid
  REFERENCES public.treatment_day_uygulamalar(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.drug_administrations.seans_admin_id
  IS 'Bu ilac kaydi hangi seans icin olusturuldu. NULL = eski tek-seans.';
```

**Neden:** Drug admin tek doğruluk kaynağı, ama **hangi seans için** oluşturulduğunu bilmesi gerekiyor. Stok düşümü de bu bağ ile takip edilebilir.

### 3.3 `gorev_log.seans_admin_id`

```sql
ALTER TABLE public.gorev_log
  ADD COLUMN IF NOT EXISTS seans_admin_id uuid
  REFERENCES public.treatment_day_uygulamalar(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.gorev_log.seans_admin_id
  IS 'Sahaya gonderilen gorev hangi seans icin. NULL = eski parent_id=treatment_day_id pattern.';
```

**Neden:** Eski `gorev_log.parent_id` tedavi gününe bağlanıyordu, seansa değil. Yeni pattern'de seansa bağlanır.

### 3.4 `gorev_log.hedef_saat`

```sql
ALTER TABLE public.gorev_log
  ADD COLUMN IF NOT EXISTS hedef_saat time;

COMMENT ON COLUMN public.gorev_log.hedef_saat
  IS 'Gorevin sahada yapilmasi gereken saat (seans.planned_time ile ayni).';
```

**Neden:** "Bu görevi saat kaçta yap?" sorusu için. Frontend timer + geç uyarı buna göre çalışacak.

---

## 4. Index Stratejisi

```sql
-- tedavi gunu bazli hizli erisim
CREATE INDEX IF NOT EXISTS tdu_day_id_idx
  ON public.treatment_day_uygulamalar(treatment_day_id);

-- vaka + tarih bazli dashboard sorgulari
CREATE INDEX IF NOT EXISTS tdu_case_date_idx
  ON public.treatment_day_uygulamalar(case_id, planned_date);

-- acik seanslar (tamamlanmamis) — geç uyarı, frontend listeleme
CREATE INDEX IF NOT EXISTS tdu_open_idx
  ON public.treatment_day_uygulamalar(case_id)
  WHERE uygulama_tamamlandi_at IS NULL AND uygulanmadi = false;

-- geç kalan seanslar (planned_date <= today) — dashboard "geciken" widget
CREATE INDEX IF NOT EXISTS tdu_late_idx
  ON public.treatment_day_uygulamalar(planned_date, planned_time)
  WHERE uygulama_tamamlandi_at IS NULL AND uygulanmadi = false;

-- drug_admin'den seansa geri link
CREATE INDEX IF NOT EXISTS da_seans_admin_id_idx
  ON public.drug_administrations(seans_admin_id)
  WHERE seans_admin_id IS NOT NULL;
```

**5 index**, hepsi partial veya composite — mevcut `drug_admin_day_id_idx` (127 satır) ve `treatment_days_case_id_idx` (12 satır) zaten var, yeni index'ler sadece yeni pattern için.

---

## 5. RLS (Row Level Security)

Mevcut tablolar (`cases`, `treatment_days`, `drug_administrations`, `gorev_log`) RLS'siz çalışıyor (anon key ile okunur-yazılır, app katmanı auth yapar). Yeni tablo da **aynı pattern** ile açılır — ek RLS yok, **Phase 2'de** karar verilir.

---

## 6. Migration Dosyası

**Dosya:** `supabase/migrations/20260611000001_bug059_treatment_sessions.sql`

**Yapı:**
1. CREATE TABLE treatment_day_uygulamalar
2. 4× ALTER TABLE (kolon ekleme)
3. 5× CREATE INDEX
4. COMMENT ON (kolonlar)

**ÖNEMLİ:** `BEGIN/COMMIT` **YOK** — `supabase_migrate` tool'u her migration'ı ayrı transaction olarak çalıştırıyor. Explicit BEGIN yazılırsa nested transaction hatası oluşur. (Mevcut migration'lar: bazılarında BEGIN var, bazılarında yok — tutarsız, biz temiz yazıyoruz.)

**Boyut tahmini:** ~120 satır SQL.

---

## 7. Deploy + Doğrulama

1. **`supabase_migrate(sql=...)`** ile canlıya uygula
2. **`information_schema.columns` doğrulama** (Faz 0.8 patterns):
   - `treatment_day_uygulamalar` tablosu var mı
   - 4 yeni kolon eklendi mi
   - 5 index oluştu mu
3. **`pg_indexes` doğrulama** (5 index adı kontrolü)
4. **Canlı test:** `c4ff42d9` Gün 4-5'e 1 test seansı INSERT (rollback'li dry-run)

**Rollback stratejisi:** Yedek zaten alındı (`egesut_20260611.pg.enc`, 19 MB, 90 gün GitHub artifact). Schema migration kolon ekleme + yeni tablo olduğu için geri alma kolay: `DROP TABLE treatment_day_uygulamalar CASCADE` + `ALTER TABLE ... DROP COLUMN` × 4.

---

## 8. Faz 1 Kabul Kriterleri

- [ ] Migration dosyası yazıldı (`20260611000001_bug059_treatment_sessions.sql`)
- [ ] `supabase_migrate` başarıyla çalıştı
- [ ] `information_schema.columns` ile 4 yeni kolon doğrulandı
- [ ] `pg_indexes` ile 5 yeni index doğrulandı
- [ ] `treatment_day_uygulamalar` tablosu boş (0 satır) — INSERT testi Faz 2'de
- [ ] Plan dosyası (`2026-06-11-bug-059-saat-bazli-seans.md`) Faz 1 checkbox işaretlendi
- [ ] Commit + push edildi

---

## 9. Faz 1 Sonrası

- **Faz 2:** 5 RPC (4 yeni + 1 güncelleme) — `add_treatment_day_with_sessions`, `seans_tamamla`, `recete_guncelle`, `close_case_with_remaining`, `treatment_day_tamamla` (güncelleme)
  - **H1 notu (stok pattern tutarsızlığı):** Mevcut `drug_admin:UUID` pattern'i (`stok_hareket.notlar LIKE 'drug_admin:' || v_id`) + yeni `referans_tipi='tedavi_seans' + referans_id=seans.id` pattern'i birlikte yaşayacak. Fonksiyonel sorun yok, debug/bakım karmaşıklığı artar. Faz 3 ground truth sync'te birleştirme değerlendirilir.
- **Faz 3:** Ground truth sync (`99999999999999_ground_truth.sql` + bu migration birleştirilir)
- **Faz 4:** Deploy + canlı doğrulama (zaten Faz 1'de yapıldı, Faz 4 dashboard+UI için)
- **Faz 5:** UI (api.js + ui.js + forms.js)
- **Faz 6:** 10 test senaryosu (A-J) — c4ff42d9 gerçek hedefi
- **Faz 7:** Session update + final handoff
