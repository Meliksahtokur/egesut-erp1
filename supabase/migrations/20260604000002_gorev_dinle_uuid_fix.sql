-- Migration: _gorev_dinle UUID Fix
-- Sorun: v_gorev_id text tipinde olduğu için WHERE id = v_gorev_id → uuid = text hatası
-- Çözüm: v_gorev_id tipini uuid olarak düzelt
-- Tarih: 2026-06-04
-- Geri alınabilir: DROP FUNCTION IF EXISTS, eski haliyle recreate

BEGIN;

CREATE OR REPLACE FUNCTION public._gorev_dinle(
  p_hayvan_id text,
  p_etken_kod text,
  p_ref text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev_id uuid;  -- FIX: text → uuid (gorev_log.id uuid tipinde)
BEGIN
  IF p_etken_kod IS NULL OR p_hayvan_id IS NULL THEN
    RETURN;
  END IF;

  SELECT id INTO v_gorev_id
  FROM public.gorev_log
  WHERE hayvan_id = p_hayvan_id
    AND etken_kod = p_etken_kod
    AND tamamlandi = false
    AND iptal = false
  ORDER BY hedef_tarih ASC
  LIMIT 1
  FOR UPDATE;

  IF v_gorev_id IS NOT NULL THEN
    UPDATE public.gorev_log
    SET tamamlandi = true,
        tamamlanma_tarihi = now(),
        kapatan_ref = p_ref
    WHERE id = v_gorev_id;
  END IF;
END;
$$;

COMMIT;
