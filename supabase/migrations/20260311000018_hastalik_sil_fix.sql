-- Migration 018 — hastalik_sil notlar→aciklama fix
CREATE OR REPLACE FUNCTION public.hastalik_sil(
  p_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.gorev_log SET
    tamamlandi = true,
    aciklama   = COALESCE(aciklama, '') || ' [Hastalik kaydi silindi]'
  WHERE kaynak = 'TEDAVI-' || p_id AND tamamlandi = false;

  DELETE FROM public.hastalik_log WHERE id::text = p_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayit bulunamadi');
  END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;
ALTER FUNCTION public.hastalik_sil SECURITY DEFINER;
NOTIFY pgrst, 'reload schema';
