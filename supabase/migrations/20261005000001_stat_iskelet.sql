-- ============================================================================
-- Migration: 20261005000001_stat_iskelet
-- Tarih: 2026-10-05 · istatistik F0 Task 2 (plan P2 — spec §4.3, §5.1)
-- Etkiler: 3 yeni tenant-scoped tablo (stat_olcum_kayit, stat_analiz_sonuc,
--   stat_motor_kosum) + index + RLS + ACL + COMMENT. Fonksiyon/veri satırı YOK
--   (kayıt satırları T5'te `ON CONFLICT (ad)` ile gelir).
-- farm_id: domain-rules §14 — NOT NULL DEFAULT REAL_FARM_ID, FK YOK,
--   policy USING(true) (Faz 2'de current_farm_id() flip).
-- ACL (preflight R8): Supabase default privileges anon+authenticated'a ALL
--   verir → REVOKE ALL FROM PUBLIC, anon, authenticated; yalnız SELECT
--   authenticated'a. INSERT/UPDATE grant'i YOK (motor rolü F2).
-- Idempotent: IF NOT EXISTS + DROP POLICY IF EXISTS; ikinci koşum no-op.
-- Geri alma: DROP TABLE IF EXISTS stat_motor_kosum, stat_analiz_sonuc,
--   stat_olcum_kayit; (ledger "Demo geri alma listesi" R19).
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE TABLE IF NOT EXISTS public.stat_olcum_kayit (
  id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  farm_id   uuid NOT NULL DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e',
  ad        text NOT NULL UNIQUE,
  alan      text,
  baslik    text,
  aciklama  text,
  tip       text NOT NULL CHECK (tip IN ('sql', 'motor')),
  surum     text,
  aktif     boolean DEFAULT true,
  sira      int DEFAULT 100
);

CREATE TABLE IF NOT EXISTS public.stat_analiz_sonuc (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  farm_id      uuid NOT NULL DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e',
  olcum        text NOT NULL,
  anahtar      jsonb NOT NULL DEFAULT '{}',
  sonuc        jsonb NOT NULL,
  girdi_ozeti  text,
  hesap_at     timestamptz NOT NULL DEFAULT now(),
  motor_surum  text,
  UNIQUE (farm_id, olcum, anahtar)
);

CREATE TABLE IF NOT EXISTS public.stat_motor_kosum (
  id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  farm_id            uuid NOT NULL DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e',
  baslangic_at       timestamptz NOT NULL DEFAULT now(),
  bitis_at           timestamptz,
  durum              text CHECK (durum IN ('ok', 'hata', 'atlandi')),
  mesaj              text,
  degisen_kaynaklar  jsonb,
  surum              text
);

ALTER TABLE public.stat_olcum_kayit ALTER COLUMN ad SET NOT NULL;
ALTER TABLE public.stat_olcum_kayit ALTER COLUMN tip SET NOT NULL;
ALTER TABLE public.stat_analiz_sonuc ALTER COLUMN olcum SET NOT NULL;

CREATE INDEX IF NOT EXISTS stat_olcum_kayit_farm_aktif_sira_idx
  ON public.stat_olcum_kayit (farm_id, aktif, sira);
CREATE INDEX IF NOT EXISTS stat_analiz_sonuc_farm_olcum_idx
  ON public.stat_analiz_sonuc (farm_id, olcum);
CREATE INDEX IF NOT EXISTS stat_motor_kosum_farm_baslangic_idx
  ON public.stat_motor_kosum (farm_id, baslangic_at DESC);

COMMENT ON TABLE public.stat_olcum_kayit IS
  'Ölçüm kaydı: ekranın ölçüm listesini çektiği katalog (ad, alan, başlık, tip sql|motor, sürüm, aktif); yeni ölçüm = migration + kayıt satırı.';
COMMENT ON TABLE public.stat_analiz_sonuc IS
  'Motorun tek yazdığı yer: ölçüm başına çizime hazır sonuç serisi; upsert anahtarı (farm_id, olcum, anahtar).';
COMMENT ON TABLE public.stat_motor_kosum IS
  'Motor koşum defteri (durum ok/hata/atlandi); hata olursa önceki sonuç satırları silinmez (K5).';
COMMENT ON COLUMN public.stat_motor_kosum.durum IS
  'ok/hata/atlandi; NULL = koşum sürüyor (spec §7.1: koşum kaydı sonuç bilinmeden açılır).';

ALTER TABLE public.stat_olcum_kayit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stat_analiz_sonuc ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stat_motor_kosum ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS stat_olcum_kayit_all ON public.stat_olcum_kayit;
CREATE POLICY stat_olcum_kayit_all ON public.stat_olcum_kayit FOR ALL USING (true);
DROP POLICY IF EXISTS stat_analiz_sonuc_all ON public.stat_analiz_sonuc;
CREATE POLICY stat_analiz_sonuc_all ON public.stat_analiz_sonuc FOR ALL USING (true);
DROP POLICY IF EXISTS stat_motor_kosum_all ON public.stat_motor_kosum;
CREATE POLICY stat_motor_kosum_all ON public.stat_motor_kosum FOR ALL USING (true);

REVOKE ALL ON TABLE public.stat_olcum_kayit FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.stat_analiz_sonuc FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.stat_motor_kosum FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.stat_olcum_kayit TO authenticated;
GRANT SELECT ON TABLE public.stat_analiz_sonuc TO authenticated;
GRANT SELECT ON TABLE public.stat_motor_kosum TO authenticated;

COMMIT;
