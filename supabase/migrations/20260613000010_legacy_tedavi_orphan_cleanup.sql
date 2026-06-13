-- 20260613000010: Legacy tedavi orphan cleanup
-- Sorun: Eski 'tedavi' şeması kullanımdan kalktı (0 kayıt). Bu şemadan oluşturulan
--         gorev_log görevleri orphaned kaldı çünkü FK cascade yoktu.
--         close_case_with_remaining yeni 'cases' şemasını hedefliyor, eski görevleri yakalamıyor.
-- Tespit: 6 TEDAVI_SEANS görevi stale görünüyor (H000088 - Test buzağı cabbiş dahil).
--         dry-run: 6 orphaned (aciklama->day_id tedavi_days'da yok, gorev_tipi=TEDAVI_SEANS, açık).
-- Fix: Tek seferlik cleanup — orphaned görevleri iptal et + audit trail.
--      Pattern: 345f93a fix (gorev_tipi guard + JSON regex guard).
-- Refs:
--   - BUG-059 close_case_with_remaining (cases şeması, scope dışı)
--   - 345f93a (gorev_tipi + JSON guard)
--   - bugs.md BUG-XXX (kullanıcı raporu — "Test buzağı cabbiş 3 farklı day_id")
-- Kapsam dışı (kasıtlı):
--   - Recurring engine (DEFERRED, ayrı iş)
--   - tedavi tablosu DROP (0 kayıt, silmek ileride audit trail kirletir)
--   - Savunma trigger (henüz ekleme gerekmiyor, BUG-059 cases şemasında cascade var)

BEGIN;

-- 1. Orphaned TEDAVI_GUN/SEANS görevleri temizle
--    (aciklama JSON içinde day_id var ama treatment_days'da karşılığı yok)
WITH orphaned AS (
  SELECT gl.id
  FROM public.gorev_log gl
  LEFT JOIN public.treatment_days td
    ON td.id::text = (gl.aciklama::jsonb->>'day_id')
  WHERE gl.gorev_tipi IN ('TEDAVI_GUN','TEDAVI_SEANS')
    AND (gl.tamamlandi IS NULL OR gl.tamamlandi = false)
    AND (gl.iptal IS NULL OR gl.iptal = false)
    AND gl.aciklama IS NOT NULL
    AND gl.aciklama ~ '^\{.*\}$'      -- JSON guard (345f93a fix pattern'i)
    AND td.id IS NULL                 -- orphaned: parent day_id tedavi_days'da yok
)
UPDATE public.gorev_log
SET iptal = true,
    kapatan_ref = 'legacy-tedavi-orphan-cleanup-2026-06-13'
WHERE id IN (SELECT id FROM orphaned);

-- 2. Audit trail — islem_log'a kayıt (geri alınabilirlik için)
INSERT INTO public.islem_log (id, tip, ref_id, ref_tablo, snapshot)
VALUES (
  gen_random_uuid()::text,
  'LEGACY_TEDAVI_ORPHAN_CLEANUP',
  '2026-06-13',
  'gorev_log',
  jsonb_build_object(
    'cleaned_count', (
      SELECT COUNT(*) FROM public.gorev_log
      WHERE kapatan_ref = 'legacy-tedavi-orphan-cleanup-2026-06-13'
    ),
    'hayvan_ids', (
      SELECT array_agg(DISTINCT hayvan_id) FROM public.gorev_log
      WHERE kapatan_ref = 'legacy-tedavi-orphan-cleanup-2026-06-13'
    ),
    'gorev_tipleri', (
      SELECT array_agg(DISTINCT gorev_tipi) FROM public.gorev_log
      WHERE kapatan_ref = 'legacy-tedavi-orphan-cleanup-2026-06-13'
    ),
    'reason', 'tedavi tablosu 0 kayıt, eski şema görevleri orphaned kaldı (FK cascade yoktu)',
    'pattern', 'close_case_with_remaining yeni cases şemasını hedefliyor, eski tedavi görevlerini yakalamıyor',
    'detected_at', '2026-06-13',
    'detected_by', 'pi agent systematic-debugging (BUG-XXX araştırması)',
    'fix_pattern', '345f93a (gorev_tipi IN + JSON regex guard)'
  )
);

COMMIT;
