-- ══════════════════════════════════════════════════════════════
-- MIGRATION 025 — TREATMENT DAY TIME COLUMN
-- EgeSüt ERP — 2026-03-25
--
-- Değişiklikler:
-- 1. treatment_days.treatment_time (time) kolonu eklendi
-- 2. update_treatment_time RPC eklendi
--
-- NOT: treatment_timeline view'ı yeniden tanımlanmıyor —
-- gerçek DB şeması repo'daki migration 022 ile tam örtüşmüyor
-- (drug_administrations kolon adları farklı). MCP erişimi
-- sağlandıktan sonra view güncellenecek.
-- ══════════════════════════════════════════════════════════════

-- 1. Kolon ekle
ALTER TABLE public.treatment_days
  ADD COLUMN IF NOT EXISTS treatment_time time;

COMMENT ON COLUMN public.treatment_days.treatment_time IS 'Tedavi saati (örn. 08:00) — opsiyonel';

-- 2. RPC: tedavi günü saatini güncelle
DROP FUNCTION IF EXISTS public.update_treatment_time(uuid, time);
CREATE OR REPLACE FUNCTION public.update_treatment_time(
  p_day_id        uuid,
  p_treatment_time time
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.treatment_days
  SET treatment_time = p_treatment_time
  WHERE id = p_day_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tedavi günü bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_treatment_time TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
