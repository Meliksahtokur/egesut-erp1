-- ══════════════════════════════════════════════════════════════
-- MIGRATION 025 — TREATMENT DAY TIME COLUMN
-- EgeSüt ERP — 2026-03-25
--
-- Değişiklikler:
-- 1. treatment_days.treatment_time (time) kolonu eklendi
-- 2. treatment_timeline view güncellendi — treatment_time dahil
-- 3. update_treatment_time RPC eklendi
-- ══════════════════════════════════════════════════════════════

-- 1. Kolon ekle
ALTER TABLE public.treatment_days
  ADD COLUMN IF NOT EXISTS treatment_time time;

COMMENT ON COLUMN public.treatment_days.treatment_time IS 'Tedavi saati (örn. 08:00) — opsiyonel';

-- 2. View güncelle — treatment_time dahil
DROP VIEW IF EXISTS public.treatment_timeline CASCADE;
CREATE VIEW public.treatment_timeline AS
SELECT
  h.id          AS animal_id,
  h.kupe_no     AS kupe_no,
  c.id          AS case_id,
  c.status      AS case_status,
  c.start_date  AS case_start,
  dis.name      AS disease,
  dis.category  AS disease_category,
  td.id         AS day_id,
  td.day_no,
  td.treatment_date,
  td.treatment_time,
  dr.id         AS drug_id,
  dr.name       AS drug,
  da.id         AS administration_id,
  da.dose,
  da.unit,
  da.route,
  da.notes      AS admin_notes
FROM public.drug_administrations da
JOIN public.treatment_days  td  ON td.id  = da.treatment_day_id
JOIN public.cases           c   ON c.id   = td.case_id
JOIN public.hayvanlar       h   ON h.id   = c.animal_id
JOIN public.drugs           dr  ON dr.id  = da.drug_id
JOIN public.diseases        dis ON dis.id = c.disease_id;

COMMENT ON VIEW public.treatment_timeline IS 'Vaka → gün → ilaç timeline (treatment_time dahil)';

-- 3. RPC: tedavi günü saatini güncelle
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
