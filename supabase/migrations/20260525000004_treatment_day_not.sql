-- treatment_days.notes için ayrı güncelleme RPC
-- Not sistemi done'dan bağımsız — treatment_days.notes kolonu (zaten mevcut)

CREATE OR REPLACE FUNCTION public.treatment_day_not_guncelle(
  p_day_id  uuid,
  p_notes   text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.treatment_days
  SET notes = p_notes
  WHERE id = p_day_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tedavi günü bulunamadı: %', p_day_id;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.treatment_day_not_guncelle(uuid, text) TO anon, authenticated;
