-- ─────────────────────────────────────────────────────────────
-- Aşı Faz 1 — asi_ekle / asi_guncelle / asi_sil (atomik)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.asi_ekle(
  p_name text,
  p_marka text DEFAULT NULL,
  p_etken_madde text DEFAULT NULL,
  p_dose numeric DEFAULT NULL,
  p_unit text DEFAULT 'ml',
  p_route text DEFAULT 'SC',
  p_is_mandatory boolean DEFAULT false,
  p_disease_ids uuid[] DEFAULT '{}',
  p_protokol_tipi text DEFAULT 'tek_doz',
  p_protokol_adimlar jsonb DEFAULT '[]'::jsonb,
  p_repeat_interval_days int DEFAULT NULL,
  p_baslangic_stok numeric DEFAULT NULL,
  p_esik numeric DEFAULT 0
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $function$
DECLARE
  v_vaccine_id uuid := gen_random_uuid();
  v_stok_id    text := NULL;
  v_disease_names text;
  v_step jsonb;
  v_did  uuid;
BEGIN
  IF p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Aşı adı zorunlu';
  END IF;

  SELECT string_agg(d.name, ', ' ORDER BY d.name) INTO v_disease_names
  FROM public.diseases d WHERE d.id = ANY(p_disease_ids);

  IF p_baslangic_stok IS NOT NULL THEN
    v_stok_id := 'STOK-AŞI-' || v_vaccine_id::text;
    INSERT INTO public.stok (id, urun_adi, kategori, birim, baslangic_miktar, esik)
    VALUES (v_stok_id, p_name, 'Aşı', COALESCE(p_unit,'ml'), p_baslangic_stok, COALESCE(p_esik,0));
  END IF;

  INSERT INTO public.vaccines (
    id, name, marka, etken_madde, disease_target, dose, unit, route,
    repeat_interval_days, is_mandatory, protokol_tipi, stock_item_id
  ) VALUES (
    v_vaccine_id, p_name, p_marka, p_etken_madde, v_disease_names,
    COALESCE(p_dose,0), COALESCE(p_unit,'ml'), COALESCE(p_route,'SC'),
    p_repeat_interval_days, COALESCE(p_is_mandatory,false), p_protokol_tipi, v_stok_id
  );

  FOR v_step IN SELECT * FROM jsonb_array_elements(p_protokol_adimlar)
  LOOP
    INSERT INTO public.vaccine_protocol_steps (vaccine_id, adim_no, offset_gun, label)
    VALUES (
      v_vaccine_id,
      (v_step->>'adim_no')::int,
      COALESCE((v_step->>'offset_gun')::int, 0),
      v_step->>'label'
    );
  END LOOP;

  IF p_disease_ids IS NOT NULL THEN
    FOREACH v_did IN ARRAY p_disease_ids LOOP
      INSERT INTO public.vaccine_diseases (vaccine_id, disease_id)
      VALUES (v_vaccine_id, v_did) ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('ASI_EKLE', v_vaccine_id::text, 'vaccines',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(jsonb_build_object('tablo','vaccines','id',v_vaccine_id,
        'veri', jsonb_build_object('name',p_name,'marka',p_marka,'stock_item_id',v_stok_id))),
      'guncellenen','[]'::jsonb,'silinen','[]'::jsonb),
    'Yeni aşı: ' || p_name);

  RETURN jsonb_build_object('ok', true, 'vaccine_id', v_vaccine_id, 'stock_item_id', v_stok_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.asi_guncelle(
  p_vaccine_id uuid,
  p_name text,
  p_marka text DEFAULT NULL,
  p_etken_madde text DEFAULT NULL,
  p_dose numeric DEFAULT NULL,
  p_unit text DEFAULT 'ml',
  p_route text DEFAULT 'SC',
  p_is_mandatory boolean DEFAULT false,
  p_disease_ids uuid[] DEFAULT '{}',
  p_protokol_tipi text DEFAULT 'tek_doz',
  p_protokol_adimlar jsonb DEFAULT '[]'::jsonb,
  p_repeat_interval_days int DEFAULT NULL,
  p_baslangic_stok numeric DEFAULT NULL,
  p_esik numeric DEFAULT 0
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $function$
DECLARE
  v_old record;
  v_disease_names text;
  v_step jsonb;
  v_did  uuid;
  v_stok_id text;
BEGIN
  SELECT * INTO v_old FROM public.vaccines WHERE id = p_vaccine_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Aşı bulunamadı'; END IF;
  IF p_name IS NULL OR btrim(p_name) = '' THEN RAISE EXCEPTION 'Aşı adı zorunlu'; END IF;
  v_stok_id := v_old.stock_item_id;

  -- name değişiyorsa ve aktif görev (ASI_RAPEL aciklama VEYA ILERI_GEBE_ASI stok_id) varsa engelle (Ö7)
  IF p_name <> v_old.name AND EXISTS (
    SELECT 1 FROM public.gorev_log
    WHERE tamamlandi = false AND iptal = false
      AND (
        (gorev_tipi = 'ASI_RAPEL' AND aciklama LIKE v_old.name || '%')
        OR (gorev_tipi = 'ILERI_GEBE_ASI' AND v_old.stock_item_id IS NOT NULL AND stok_id = v_old.stock_item_id)
      )
  ) THEN
    RAISE EXCEPTION 'Bu aşının aktif görevi var — adı değiştirilemez';
  END IF;

  -- Ö1: stoksuz aşıya sonradan stok bağla (stock_item_id NULL + miktar verildi)
  IF v_old.stock_item_id IS NULL AND p_baslangic_stok IS NOT NULL THEN
    v_stok_id := 'STOK-AŞI-' || p_vaccine_id::text;
    INSERT INTO public.stok (id, urun_adi, kategori, birim, baslangic_miktar, esik)
    VALUES (v_stok_id, p_name, 'Aşı', COALESCE(p_unit,'ml'), p_baslangic_stok, COALESCE(p_esik,0));
  END IF;

  SELECT string_agg(d.name, ', ' ORDER BY d.name) INTO v_disease_names
  FROM public.diseases d WHERE d.id = ANY(p_disease_ids);

  UPDATE public.vaccines SET
    name = p_name, marka = p_marka, etken_madde = p_etken_madde,
    disease_target = v_disease_names, dose = COALESCE(p_dose,0),
    unit = COALESCE(p_unit,'ml'), route = COALESCE(p_route,'SC'),
    repeat_interval_days = p_repeat_interval_days,
    is_mandatory = COALESCE(p_is_mandatory,false), protokol_tipi = p_protokol_tipi,
    stock_item_id = v_stok_id
  WHERE id = p_vaccine_id;

  DELETE FROM public.vaccine_protocol_steps WHERE vaccine_id = p_vaccine_id;
  DELETE FROM public.vaccine_diseases       WHERE vaccine_id = p_vaccine_id;

  FOR v_step IN SELECT * FROM jsonb_array_elements(p_protokol_adimlar)
  LOOP
    INSERT INTO public.vaccine_protocol_steps (vaccine_id, adim_no, offset_gun, label)
    VALUES (p_vaccine_id, (v_step->>'adim_no')::int, COALESCE((v_step->>'offset_gun')::int,0), v_step->>'label');
  END LOOP;

  IF p_disease_ids IS NOT NULL THEN
    FOREACH v_did IN ARRAY p_disease_ids LOOP
      INSERT INTO public.vaccine_diseases (vaccine_id, disease_id)
      VALUES (p_vaccine_id, v_did) ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('ASI_GUNCELLE', p_vaccine_id::text, 'vaccines',
    jsonb_build_object('olusturulan','[]'::jsonb,
      'guncellenen', jsonb_build_array(jsonb_build_object('tablo','vaccines','id',p_vaccine_id)),
      'silinen','[]'::jsonb),
    'Aşı güncellendi: ' || p_name);

  RETURN jsonb_build_object('ok', true, 'vaccine_id', p_vaccine_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.asi_sil(p_vaccine_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $function$
DECLARE
  v_vac record;
  v_has_hareket boolean;
BEGIN
  SELECT * INTO v_vac FROM public.vaccines WHERE id = p_vaccine_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Aşı bulunamadı'; END IF;

  IF EXISTS (SELECT 1 FROM public.vaccination_log WHERE vaccine_id = p_vaccine_id) THEN
    RAISE EXCEPTION 'Bu aşı uygulanmış, silinemez (geçmiş korunur)';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.gorev_log
    WHERE gorev_tipi IN ('ASI_RAPEL','ILERI_GEBE_ASI')
      AND tamamlandi = false AND iptal = false
      AND ( (v_vac.stock_item_id IS NOT NULL AND stok_id = v_vac.stock_item_id)
            OR aciklama LIKE v_vac.name || '%' )
  ) THEN
    RAISE EXCEPTION 'Bu aşının aktif görevi var, silinemez';
  END IF;

  DELETE FROM public.vaccine_diseases       WHERE vaccine_id = p_vaccine_id;
  DELETE FROM public.vaccine_protocol_steps WHERE vaccine_id = p_vaccine_id;
  DELETE FROM public.vaccines WHERE id = p_vaccine_id;

  IF v_vac.stock_item_id IS NOT NULL THEN
    SELECT EXISTS(SELECT 1 FROM public.stok_hareket WHERE stok_id = v_vac.stock_item_id) INTO v_has_hareket;
    IF NOT v_has_hareket THEN
      DELETE FROM public.stok WHERE id = v_vac.stock_item_id;
    END IF;
  END IF;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('ASI_SIL', p_vaccine_id::text, 'vaccines',
    jsonb_build_object('olusturulan','[]'::jsonb,'guncellenen','[]'::jsonb,
      'silinen', jsonb_build_array(jsonb_build_object('tablo','vaccines','id',p_vaccine_id))),
    'Aşı silindi: ' || v_vac.name);

  RETURN jsonb_build_object('ok', true);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.asi_ekle(text,text,text,numeric,text,text,boolean,uuid[],text,jsonb,int,numeric,numeric) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.asi_guncelle(uuid,text,text,text,numeric,text,text,boolean,uuid[],text,jsonb,int,numeric,numeric) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.asi_sil(uuid) TO anon, authenticated;
