-- Toplu sütten kesme (partial success) + geri alma (undo)
BEGIN;

CREATE OR REPLACE FUNCTION public.buzagi_sutten_kesme_toplu(
  p_hayvan_idler text[],
  p_tarih date DEFAULT CURRENT_DATE
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id text;
  v_basari int := 0;
  v_hatalar jsonb := '[]'::jsonb;
BEGIN
  IF p_hayvan_idler IS NULL OR array_length(p_hayvan_idler,1) IS NULL THEN
    RETURN jsonb_build_object('ok',false,'hata','Hayvan listesi boş','basari',0,'hata_sayisi',0,'hatalar','[]'::jsonb);
  END IF;
  IF array_length(p_hayvan_idler,1) > 200 THEN
    RETURN jsonb_build_object('ok',false,'hata','Çok fazla hayvan (limit 200)','basari',0,'hata_sayisi',0,'hatalar','[]'::jsonb);
  END IF;
  FOREACH v_id IN ARRAY p_hayvan_idler LOOP
    BEGIN
      PERFORM public.buzagi_sutten_kesme_onayla(v_id, p_tarih);
      v_basari := v_basari + 1;
    EXCEPTION WHEN OTHERS THEN
      v_hatalar := v_hatalar || jsonb_build_array(jsonb_build_object('hayvan_id',v_id,'hata',SQLERRM,'kod',SQLSTATE));
    END;
  END LOOP;
  RETURN jsonb_build_object('ok',true,'basari',v_basari,
    'hata_sayisi',jsonb_array_length(v_hatalar),'hatalar',v_hatalar,
    'toplam',v_basari+jsonb_array_length(v_hatalar));
END; $$;

CREATE OR REPLACE FUNCTION public.buzagi_sutten_kesme_geri_al(p_hayvan_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_log record; v_onceki jsonb;
BEGIN
  SELECT * INTO v_log FROM public.islem_log
   WHERE tip='SUTEN_KESME' AND ana_hayvan_id=p_hayvan_id AND durum='aktif'
   ORDER BY tarih DESC LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'Sütten kesim kaydı bulunamadı: %', p_hayvan_id; END IF;
  v_onceki := v_log.snapshot->'guncellenen'->0->'onceki';
  -- tarihi NULL'a çek + grup/padok geri yükle → AFTER trigger instance'ı tekrar açar
  UPDATE public.hayvanlar
     SET suttten_kesme_tarihi = NULL,
         grup     = COALESCE(v_onceki->>'grup', grup),
         padok    = COALESCE(v_onceki->>'padok', padok),
         padok_id = COALESCE((v_onceki->>'padok_id')::uuid, padok_id)
   WHERE id = p_hayvan_id;
  UPDATE public.islem_log SET durum='geri_alindi', geri_alma_tarihi=now() WHERE id=v_log.id;
  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('SUTTEN_KESME_GERI_AL', p_hayvan_id, p_hayvan_id, 'hayvanlar',
    jsonb_build_object('olusturulan','[]'::jsonb,'silinen','[]'::jsonb,
      'guncellenen', jsonb_build_array(jsonb_build_object('tablo','hayvanlar','id',p_hayvan_id,'geri_alinan_log',v_log.id))),
    'Sütten kesim geri alındı');
  RETURN jsonb_build_object('ok', true, 'hayvan_id', p_hayvan_id);
END; $$;

GRANT EXECUTE ON FUNCTION public.buzagi_sutten_kesme_toplu(text[], date) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.buzagi_sutten_kesme_geri_al(text) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
