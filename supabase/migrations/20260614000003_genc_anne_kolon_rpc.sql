-- genc_anne: nullable boolean üreme statüsü override
-- NULL = incelenmedi (temkinli İnek), true = genç anne (Düve), false = olgun İnek
ALTER TABLE public.hayvanlar
  ADD COLUMN IF NOT EXISTS genc_anne boolean DEFAULT NULL;

CREATE OR REPLACE FUNCTION public.hayvan_genc_anne_isaretle(
  p_hayvan_id text,
  p_genc_anne boolean   -- true | false | NULL (incelenmedi'ye döndür)
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  UPDATE public.hayvanlar SET genc_anne = p_genc_anne WHERE id = p_hayvan_id;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    'GENC_ANNE_STATU',
    p_hayvan_id,
    p_hayvan_id,
    'hayvanlar',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(jsonb_build_object(
        'tablo', 'hayvanlar', 'id', p_hayvan_id,
        'degisim', 'genc_anne: ' || COALESCE(v_hayvan.genc_anne::text,'null') || ' → ' || COALESCE(p_genc_anne::text,'null')
      )),
      'silinen', '[]'::jsonb
    )
  );

  RETURN jsonb_build_object('ok', true, 'genc_anne', p_genc_anne);
END;
$$;

GRANT EXECUTE ON FUNCTION public.hayvan_genc_anne_isaretle(text, boolean) TO anon, authenticated;
