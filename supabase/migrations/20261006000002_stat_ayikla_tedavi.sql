-- ============================================================================
-- Migration: 20261006000002_stat_ayikla_tedavi
-- 2026-10-06 · istatistik F2 T3 (P3; spec §7.2 K4/K5; domain-rules §8 R31, §19).
-- Etkiler: iki yeni fonksiyon (motorun Postgres'ten veri çektiği tek kapı, hash-diff delta):
--   stat_ayikla_tedavi_vaka(p_ids uuid[] DEFAULT NULL) → vaka başına altı kolon (p_ids NULL = tüm küme)
--   stat_ayikla_tedavi_vaka_ozet()                     → (vaka_id, hash); hash tam fonksiyonun altı
--                                                        kolonundan (tek tanım)
-- Kaynak v_stat_vaka (protokol vakaları zaten dışarıda). Spec §7.2 p_ids bigint[] der; vaka kimliği uuid.
-- olay_tarihi = baslangic + olay_gun yalnız sonuc <> 'devam'; devam → NULL. Satır bugüne bağlı değil,
--   hash günden güne değişmez (K5). Tarihler hash'e to_char ile girer: DateStyle oturum ayarından bağımsız.
-- SECURITY DEFINER (stat_motor'un kaynak tablolarda SELECT'i yok); EXECUTE yalnız stat_motor.
-- CURRENT_DATE yok. Idempotent (CREATE OR REPLACE + ACL yeniden).
-- Geri alma: DROP FUNCTION IF EXISTS public.stat_ayikla_tedavi_vaka_ozet(),
--   public.stat_ayikla_tedavi_vaka(uuid[]);
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION public.stat_ayikla_tedavi_vaka(p_ids uuid[] DEFAULT NULL)
RETURNS TABLE(vaka_id uuid, hastalik text, protokol_etiket text, baslangic date, sonuc text, olay_tarihi date)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT v.vaka_id,
         v.hastalik,
         public.stat_protokol_etiket(v.protokol, v.tedavi_suresi_gun, 'urun'),
         v.baslangic,
         v.sonuc,
         CASE WHEN v.sonuc <> 'devam' THEN v.baslangic + v.olay_gun END
  FROM public.v_stat_vaka v
  WHERE p_ids IS NULL OR v.vaka_id = ANY (p_ids);
$$;

CREATE OR REPLACE FUNCTION public.stat_ayikla_tedavi_vaka_ozet()
RETURNS TABLE(vaka_id uuid, hash text)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT t.vaka_id,
         md5(row(t.vaka_id, t.hastalik, t.protokol_etiket, to_char(t.baslangic, 'YYYY-MM-DD'),
                 t.sonuc, to_char(t.olay_tarihi, 'YYYY-MM-DD'))::text)
  FROM public.stat_ayikla_tedavi_vaka(NULL) t;
$$;

COMMENT ON FUNCTION public.stat_ayikla_tedavi_vaka(uuid[]) IS
  'İstatistik motoru tam çekim (spec §7.2): v_stat_vaka''dan vaka başına vaka_id, hastalik, protokol_etiket '
  '(stat_protokol_etiket ürün düzeyi), baslangic, sonuc, olay_tarihi (devam → NULL). p_ids NULL = tüm küme. '
  'Yalnız stat_motor.';
COMMENT ON FUNCTION public.stat_ayikla_tedavi_vaka_ozet() IS
  'İstatistik motoru hash-diff özeti (spec §7.2, K4): vaka başına md5(row(vaka_id, hastalik, protokol_etiket, '
  'to_char(baslangic,''YYYY-MM-DD''), sonuc, to_char(olay_tarihi,''YYYY-MM-DD''))::text). Hash kolonları '
  'stat_ayikla_tedavi_vaka(NULL) çıktısının altı kolonudur; bugüne bağlı kolon yok. Yalnız stat_motor.';

REVOKE ALL ON FUNCTION public.stat_ayikla_tedavi_vaka(uuid[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_ayikla_tedavi_vaka_ozet() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.stat_ayikla_tedavi_vaka(uuid[]) TO stat_motor;
GRANT EXECUTE ON FUNCTION public.stat_ayikla_tedavi_vaka_ozet() TO stat_motor;

COMMIT;
