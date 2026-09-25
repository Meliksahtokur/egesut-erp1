-- ============================================================================
-- Migration: 20260925100003_gorev_ertele_kural_tablo_seed
-- Tarih: 2026-09-25 · Erteleme-genel turu E1-a (zarf E1 / plan-db.md Adım 2)
-- Etkiler: yeni tablo public.gorev_ertele_kural + 20 satırlık seed + kapı kuralları
--
-- Amaç: görev tipi başına ertelenebilirlik KURAL KATALOĞU (S1+S2 sahip
--   kararları). GLOBAL katalog → farm_id kolonu YOK (contract §multi-tenancy:
--   katalog farm_id almaz). Okuma yalnız SECDEF RPC'lerden (_gorev_ertele_kural,
--   gorev_ertele_kural_listele — M4); UI doğrudan tablo okumaz, JS'e kural
--   kopyası yazılmaz.
--
-- Erişim modeli (canlı protokol_ayar'dan nokta-doğrulanan desen):
--   - RLS ENABLE, KABUL POLİTİKASİ YOK (protokol_ayar'daki permissive all-policy
--     bilinçli olarak VERİLMEZ — bu katalog UI'ın doğrudan erişimine kapalıdır);
--     owner (postgres) RLS'e tabi değildir, service_role bypassrls=t.
--   - REVOKE ALL FROM PUBLIC, anon, authenticated → anon erişimi YOK;
--     authenticated'a tablo yetkisi VERİLMEZ (okuma SECDEF RPC üzerinden —
--     Supabase default-privileges postgres tablolarına authenticated'a otomatik
--     CRUD verir; bu katalogda bilinçli olarak kapatılır [OBSERVED ilk apply]).
--   - Yazma (kural değişimi sahip işlemi): service_role'a açık beyan.
--
-- Seed matrisi (plan-db.md §Adım 2 — SAHİP KARARLARI S1+S2, RA gerçek sözlük):
--   18 tip ertelenebilir=t (pencere_kurali 'yok'; OVSYNC_BASLAT /
--   TOHUMLAMA_HAZIRLIK / TOHUMLAMA_PLANLI 'tohumlama'), TEDAVI_GUN ve
--   TEDAVI_SEANS ertelenebilir=f (S2 kırmızı çizgi: zincir/aralık bütünlüğü —
--   bunların yerine E0 zincir kaydırma ya da E4 protokol iptal kullanılır).
--   Kayıtsız/bilinmyen tip → helper'da fail-closed ertelenebilir=false (M4).
--   Kapsam dışı bırakılan adlar (satır YOK → fail-closed): ASI_HATIRLATMA,
--   ILAC_UYGULAMA (UI kategorisi var, gorev_log'da 0 satır), KIZGINLIK_TAKIP,
--   DOGUM_TAKIP, '<BOS>' legacy tipi.
--
-- max_erteleme_gun: NULL = sınır YOK (MK2 — hiçbir satıra sınır konmaz).
-- asimi_uyari_gun: 7 (yalnız uyarı alanı; red değil).
-- zincir_tetikler: yalnız OVSYNC_BASLAT'ta {"tai_ofset_gun": 10}.
--
-- Geri alınabilir: DROP TABLE public.gorev_ertele_kural; (yalnız katalog;
--   iş verisi taşımaz).
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE TABLE public.gorev_ertele_kural (
  gorev_tipi       text PRIMARY KEY,
  ertelenebilir    boolean NOT NULL,
  pencere_kurali   text NOT NULL DEFAULT 'yok',
  max_erteleme_gun integer,
  asimi_uyari_gun  integer NOT NULL DEFAULT 7,
  zincir_tetikler  jsonb NOT NULL DEFAULT '{}'::jsonb,
  guncellendi      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.gorev_ertele_kural IS
  'Gorev tipi bazli ertelenebilirlik kural katalogu (GLOBAL, farm_id YOK). Okuma SECDEF RPC; yazma yalniz service_role (sahip islemi). Kayitsiz tip = fail-closed ertelenebilir=false.';
COMMENT ON COLUMN public.gorev_ertele_kural.pencere_kurali IS
  '''yok'' (serbest) ya da ''tohumlama'' (_tohumlama_pencere yuvarlamasi uygulanir).';
COMMENT ON COLUMN public.gorev_ertele_kural.max_erteleme_gun IS
  'NULL = sinir YOK (MK2). Doluysa asilirsa GOREV_ERTELENEMEZ:MAX_ASIM sert red.';
COMMENT ON COLUMN public.gorev_ertele_kural.zincir_tetikler IS
  'Zincir senkron anahtarlari; OVSYNC_BASLAT: {"tai_ofset_gun": N}.';

-- ── SEED: 20 satır (18 t + 2 f) — S1+S2 matrisi ─────────────────────────
INSERT INTO public.gorev_ertele_kural
  (gorev_tipi, ertelenebilir, pencere_kurali, zincir_tetikler)
VALUES
  ('ASI_PLANLI',          true,  'yok',        '{}'::jsonb),
  ('ASI_RAPEL',           true,  'yok',        '{}'::jsonb),
  ('BESLEME',             true,  'yok',        '{}'::jsonb),
  ('BUZAGI_BAKIM',        true,  'yok',        '{}'::jsonb),
  ('DIGER',               true,  'yok',        '{}'::jsonb),
  ('GEBELIK_KONTROL',     true,  'yok',        '{}'::jsonb),
  ('ILAC',                true,  'yok',        '{}'::jsonb),
  ('ILERI_GEBE',          true,  'yok',        '{}'::jsonb),
  ('ILERI_GEBE_ASI',      true,  'yok',        '{}'::jsonb),
  ('MANUEL',              true,  'yok',        '{}'::jsonb),
  ('MUAYENE',             true,  'yok',        '{}'::jsonb),
  ('OVSYNC_BASLAT',       true,  'tohumlama',  '{"tai_ofset_gun": 10}'::jsonb),
  ('PADOK_DEGISIM',       true,  'yok',        '{}'::jsonb),
  ('SUTTEN_KESME',        true,  'yok',        '{}'::jsonb),
  ('TEDAVI',              true,  'yok',        '{}'::jsonb),
  ('TOHUMLAMA_HAZIRLIK',  true,  'tohumlama',  '{}'::jsonb),
  ('TOHUMLAMA_PLANLI',    true,  'tohumlama',  '{}'::jsonb),
  ('VETERINER_KONTROL',   true,  'yok',        '{}'::jsonb),
  -- S2 kırmızı çizgi: zincir/aralık bütünlüğü — tekil erteleme KAPALI
  ('TEDAVI_GUN',          false, 'yok',        '{}'::jsonb),
  ('TEDAVI_SEANS',        false, 'yok',        '{}'::jsonb);

-- ── Kapı kuralları ─────────────────────────────────────────────────────
ALTER TABLE public.gorev_ertele_kural ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.gorev_ertele_kural FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.gorev_ertele_kural TO service_role;

COMMIT;
