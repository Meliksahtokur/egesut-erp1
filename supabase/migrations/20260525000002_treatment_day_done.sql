-- treatment_days: done tracking kolonları + treatment_day_tamamla RPC
-- Sıralı tamamlama: önceki gün done değilse sonraki finished edilemez.

-- 1. Kolonlar
ALTER TABLE public.treatment_days
  ADD COLUMN IF NOT EXISTS tamamlandi         boolean     DEFAULT false,
  ADD COLUMN IF NOT EXISTS tamamlanma_tarihi  timestamptz,
  ADD COLUMN IF NOT EXISTS tamamlanma_notu    text;

-- 2. RPC: treatment_day_tamamla
CREATE OR REPLACE FUNCTION public.treatment_day_tamamla(
  p_day_id  uuid,
  p_not     text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_day     public.treatment_days%ROWTYPE;
  v_onceki  boolean;
BEGIN
  SELECT * INTO v_day FROM public.treatment_days WHERE id = p_day_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tedavi günü bulunamadı: %', p_day_id;
  END IF;

  IF v_day.tamamlandi THEN
    RAISE EXCEPTION 'Bu tedavi günü zaten tamamlandı';
  END IF;

  -- Sıralı kontrol: aynı vakada day_no daha küçük olan tamamlanmamış var mı?
  SELECT EXISTS(
    SELECT 1 FROM public.treatment_days
    WHERE case_id = v_day.case_id
      AND day_no  < v_day.day_no
      AND (tamamlandi IS NULL OR tamamlandi = false)
  ) INTO v_onceki;

  IF v_onceki THEN
    RAISE EXCEPTION 'Önceki tedavi günleri tamamlanmadan bu gün tamamlanamaz';
  END IF;

  UPDATE public.treatment_days
  SET tamamlandi        = true,
      tamamlanma_tarihi = now(),
      tamamlanma_notu   = p_not
  WHERE id = p_day_id;

  RETURN jsonb_build_object('ok', true, 'day_id', p_day_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.treatment_day_tamamla(uuid, text) TO anon, authenticated;
