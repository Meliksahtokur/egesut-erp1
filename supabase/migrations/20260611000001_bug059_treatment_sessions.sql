-- ============================================================================
-- BUG-059: Saat-Bazlı Seans Yönetimi — Schema Migration (Faz 1)
-- Tarih: 2026-06-11
-- Spec:  docs/superpowers/specs/2026-06-10-tedavi-saat-bazli-seans.md
-- Plan:  docs/superpowers/plans/2026-06-11-faz-1-schema-migration.md
--
-- Stratejik kararlar (Faz 0 + Faz 1 review):
--   * 1 gün = N seans (eski: 1 gün = N ilaç, saat bilgisi yok)
--   * Her seans = 1 ilaç, 1 saat, 1 uygulama kaydı
--   * planned_time = planlanan saat, gerceklesme_saati = gerçekleşen saat
--   * Aynı saatte FARKLI ilaçlar olabilir (Antibiyotik + Vitamin 08:00'de)
--   * Aynı saatte AYNI ilaç 2 kez OLAMAZ (UNIQUE stok_id dahil)
--   * Stok referansı: stok_hareket.referans_tipi='tedavi_seans' (mevcut vaccination pattern'i)
--   * seans_sayisi NULL = "eski tek-seans, bilinmiyor" (geriye uyumluluk)
--   * treatment_days.planned_time/treatment_time hiyerarşisi Faz 2 trigger/RPC ile set edilir
--
-- Bu migration sadece DDL (schema). Veri/RPC Faz 2'de.
-- BEGIN/COMMIT YOK — supabase_migrate zaten transaction sarıyor.
-- ============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- 1. YENİ TABLO: treatment_day_uygulamalar (seans bazlı detay)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.treatment_day_uygulamalar (
  -- KİMLİK
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  treatment_day_id            uuid NOT NULL REFERENCES public.treatment_days(id) ON DELETE CASCADE,
  case_id                     uuid NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,

  -- SEANS BİLGİSİ (sira_no YOK — ORDER BY planned_time ile sıralama)
  planned_time                time NOT NULL,
  planned_date                date NOT NULL,

  -- İLAÇ (drug_administrations ile birebir aynı kolon kümesi)
  stok_id                     text REFERENCES public.stok(id),
  drug_product_id             uuid REFERENCES public.drug_products(id),
  dose                        numeric NOT NULL CHECK (dose > 0),
  unit                        text NOT NULL,
  route                       text CHECK (route IS NULL OR route IN ('IM','IV','SC','PO','Topikal','Intrauterin')),

  -- DONE STATE (seans seviyesi — Faz 0 stratejik karar)
  uygulama_tamamlandi_at      timestamptz,
  uygulayan                   text,
  uygulama_notu               text,
  gerceklesme_saati           time,
  uygulanmadi                 boolean DEFAULT false,
  iptal_nedeni                text,

  -- AUDIT
  created_at                  timestamptz DEFAULT now(),
  updated_at                  timestamptz DEFAULT now(),

  -- KISITLAR
  -- Aynı saatte farklı ilaçlar olabilir (Antibiyotik + Vitamin 08:00'de),
  -- aynı saatte aynı ilaç 2 kez OLAMAZ (C1 kararı)
  -- 5dk aralık kuralı UI/validasyon katmanında kontrol edilir
  UNIQUE(treatment_day_id, planned_time, stok_id)
);

COMMENT ON TABLE  public.treatment_day_uygulamalar
  IS 'Tedavi gunu alt seanslari. Saat + ilac + doz + yol, gercek zamanli zincir mimarisi. NULL seans = eski tek-seans davranis.';
COMMENT ON COLUMN public.treatment_day_uygulamalar.planned_time
  IS 'PLANLANAN saat (08:00, 16:00, 24:00). Sahada gerceklesen saat = gerceklesme_saati';
COMMENT ON COLUMN public.treatment_day_uygulamalar.gerceklesme_saati
  IS 'Sahada tamamlandigi saat (NOW()::time). planned_time ile karsilastirilip gec uyarisi verilir';
COMMENT ON COLUMN public.treatment_day_uygulamalar.uygulama_tamamlandi_at
  IS 'NULL = henuz yapilmadi, now() = yapildi';
COMMENT ON COLUMN public.treatment_day_uygulamalar.uygulayan
  IS 'Sahada uygulamayi yapan kisi (text — auth entegrasyonu Faz 5)';
COMMENT ON COLUMN public.treatment_day_uygulamalar.uygulanmadi
  IS 'true = "yapilmadi, stok iade". Stok_hareket.referans_tipi=tedavi_seans ile eslesir';
COMMENT ON COLUMN public.treatment_day_uygulamalar.iptal_nedeni
  IS 'uygulanmadi=true ise neden (recete degisikligi, hayvan olum, vs.)';
COMMENT ON COLUMN public.treatment_day_uygulamalar.planned_date
  IS 'planned_time ile birlikte dashboard + gec uyari icin. treatment_days.treatment_date ile ayni olmali (denormalizasyon, kucuk trade-off)';


-- ─────────────────────────────────────────────────────────────────────────────
-- 2. MEVCUT TABLOLARA KOLON EKLEME (4 adet)
-- ─────────────────────────────────────────────────────────────────────────────

-- 2.1 treatment_days.seans_sayisi
--     NULL = "eski tek-seans, bilinmiyor" (geriye uyumlu, default yok)
--     N>=1 = yeni coklu-seans (CHECK 0'i blokluyor)
ALTER TABLE public.treatment_days
  ADD COLUMN IF NOT EXISTS seans_sayisi smallint
  CHECK (seans_sayisi IS NULL OR seans_sayisi > 0);

COMMENT ON COLUMN public.treatment_days.seans_sayisi
  IS 'NULL=eski tek-seans (geriye uyumluluk, default yok). N >= 1 = yeni coklu-seans. treatment_day_uygulamalar satirlari ile eslesmeli.';

-- 2.2 drug_administrations.seans_admin_id
--     Bu ilac kaydi hangi seans icin olusturuldu.
--     NULL = eski tek-seans (geriye uyumlu), set = yeni coklu-seans baglanti
ALTER TABLE public.drug_administrations
  ADD COLUMN IF NOT EXISTS seans_admin_id uuid
  REFERENCES public.treatment_day_uygulamalar(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.drug_administrations.seans_admin_id
  IS 'Bu ilac kaydi hangi seans icin olusturuldu. NULL = eski tek-seans.';

-- 2.3 gorev_log.seans_admin_id
--     Sahaya gonderilen gorev hangi seans icin.
--     Eski pattern: parent_id=treatment_day_id (gun bazli)
--     Yeni pattern: seans_admin_id (seans bazli) — daha detayli takip
ALTER TABLE public.gorev_log
  ADD COLUMN IF NOT EXISTS seans_admin_id uuid
  REFERENCES public.treatment_day_uygulamalar(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.gorev_log.seans_admin_id
  IS 'Sahaya gonderilen gorev hangi seans icin. NULL = eski parent_id pattern.';

-- 2.4 gorev_log.hedef_saat
--     Gorevin sahada yapilmasi gereken saat (seans.planned_time ile ayni)
--     Frontend timer + gec uyari buna gore calisir
ALTER TABLE public.gorev_log
  ADD COLUMN IF NOT EXISTS hedef_saat time;

COMMENT ON COLUMN public.gorev_log.hedef_saat
  IS 'Gorevin sahada yapilmasi gereken saat (treatment_day_uygulamalar.planned_time ile ayni).';


-- ─────────────────────────────────────────────────────────────────────────────
-- 3. INDEX STRATEJİSİ (5 yeni index)
-- ─────────────────────────────────────────────────────────────────────────────

-- Tedavi gunu bazli hizli erisim (her seans icin 1 indeks taramasi)
CREATE INDEX IF NOT EXISTS tdu_day_id_idx
  ON public.treatment_day_uygulamalar(treatment_day_id);

-- Vaka + tarih bazli dashboard sorgulari ("bu hayvanin gelecek seanslari")
CREATE INDEX IF NOT EXISTS tdu_case_date_idx
  ON public.treatment_day_uygulamalar(case_id, planned_date);

-- Acik seanslar (tamamlanmamis, iptal edilmemis) — frontend listeleme
-- Partial index: sadece acik satirlar, kucuk ve hizli
CREATE INDEX IF NOT EXISTS tdu_open_idx
  ON public.treatment_day_uygulamalar(case_id)
  WHERE uygulama_tamamlandi_at IS NULL AND uygulanmadi = false;

-- Gec kalan seanslar (planned_date <= today) — dashboard "geciken" widget
-- Partial index: sadece acik + gecmis/tarih, dashboard'a hizli
CREATE INDEX IF NOT EXISTS tdu_late_idx
  ON public.treatment_day_uygulamalar(planned_date, planned_time)
  WHERE uygulama_tamamlandi_at IS NULL AND uygulanmadi = false;

-- drug_admin'den seansa geri link (recete guncelleme, raporlar)
-- Partial index: NULL seans (eski) dahil edilmez, sadece yeni baglanti olanlar
CREATE INDEX IF NOT EXISTS da_seans_admin_id_idx
  ON public.drug_administrations(seans_admin_id)
  WHERE seans_admin_id IS NOT NULL;


-- ─────────────────────────────────────────────────────────────────────────────
-- Migration sonu — RLS YOK (mevcut pattern: anon key + app auth, Faz 2 karar)
-- Veri/RPC yok (Faz 2)
-- ─────────────────────────────────────────────────────────────────────────────
