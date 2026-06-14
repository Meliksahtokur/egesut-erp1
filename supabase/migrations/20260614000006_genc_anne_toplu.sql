-- Toplu genç anne / olgun inek işaretleme (belirsiz liste modalı checkbox sistemi için)
CREATE OR REPLACE FUNCTION public.hayvan_genc_anne_isaretle_toplu(
  p_ids text[],
  p_genc_anne boolean
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count integer;
BEGIN
  UPDATE public.hayvanlar SET genc_anne = p_genc_anne WHERE id = ANY(p_ids);
  GET DIAGNOSTICS v_count = ROW_COUNT;

  INSERT INTO public.islem_log (id, tip, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    'GENC_ANNE_STATU_TOPLU',
    'hayvanlar',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(jsonb_build_object(
        'tablo', 'hayvanlar', 'adet', v_count,
        'genc_anne', p_genc_anne, 'ids', to_jsonb(p_ids)
      )),
      'silinen', '[]'::jsonb
    )
  );

  RETURN jsonb_build_object('ok', true, 'adet', v_count, 'genc_anne', p_genc_anne);
END;
$$;

GRANT EXECUTE ON FUNCTION public.hayvan_genc_anne_isaretle_toplu(text[], boolean) TO anon, authenticated;
