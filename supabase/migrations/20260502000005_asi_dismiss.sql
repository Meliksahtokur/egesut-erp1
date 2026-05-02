-- Migration: Add dismiss columns to vaccination_log + vaccination_dismiss RPC
-- spec: spec-egesut-asi-dismiss Step 1

-- 1. Add dismiss columns to vaccination_log
ALTER TABLE public.vaccination_log
  ADD COLUMN IF NOT EXISTS ertelendi boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS erteleme_notu text;

-- 2. Create RPC vaccination_dismiss
CREATE OR REPLACE FUNCTION public.vaccination_dismiss(
  p_vaccination_id  uuid,
  p_note            text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_log   record;
  v_islem text := gen_random_uuid()::text;
BEGIN
  SELECT vl.*, v.name AS vaccine_name
  INTO v_log
  FROM public.vaccination_log vl
  LEFT JOIN public.vaccines v ON v.id = vl.vaccine_id
  WHERE vl.id = p_vaccination_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayıt bulunamadı');
  END IF;

  UPDATE public.vaccination_log
  SET ertelendi = true, erteleme_notu = p_note
  WHERE id = p_vaccination_id;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem,
    'ASI_ERTELEME',
    v_log.animal_id,
    p_vaccination_id::text,
    'vaccination_log',
    jsonb_build_object(
      'vaccine_name',    v_log.vaccine_name,
      'original_due',    v_log.next_due_date,
      'erteleme_notu',   p_note,
      'dismissed_at',    CURRENT_DATE
    )
  );

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.vaccination_dismiss TO anon, authenticated;