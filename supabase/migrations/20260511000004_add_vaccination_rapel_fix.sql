-- Migration: add_vaccination RPC — improved rapel gorev creation
-- Changes:
--   1. stok_id + miktar + kaynak='ASI_RAPEL' added to rapel gorev
--   2. Skip rapel when p_notes starts with 'GorevID:' (ileri_gebe handles its own)
--   3. Duplicate check: same hayvan_id + gorev_tipi + hedef_tarih + vaccine name
BEGIN;

CREATE OR REPLACE FUNCTION public.add_vaccination(
  p_animal_id     text,
  p_vaccine_id    uuid,
  p_date          date    DEFAULT CURRENT_DATE,
  p_dose_override numeric DEFAULT NULL,
  p_notes         text    DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_vaccine     record;
  v_new_id      uuid;
  v_next_due    date;
  v_dose        numeric;
  v_animal      record;
  v_islem_id    text := gen_random_uuid()::text;
  v_is_gorev_triggered boolean;
BEGIN
  SELECT * INTO v_animal FROM public.hayvanlar WHERE id = p_animal_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadi veya aktif degil');
  END IF;

  SELECT * INTO v_vaccine FROM public.vaccines WHERE id = p_vaccine_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Asi kaydi bulunamadi');
  END IF;

  v_dose := COALESCE(p_dose_override, v_vaccine.dose);

  IF v_vaccine.repeat_interval_days IS NOT NULL THEN
    v_next_due := p_date + (v_vaccine.repeat_interval_days || ' days')::interval;
  END IF;

  INSERT INTO public.vaccination_log (
    animal_id, vaccine_id, vaccination_date, dose_given, unit, route, next_due_date, notes
  ) VALUES (
    p_animal_id, p_vaccine_id, p_date, v_dose,
    v_vaccine.unit, v_vaccine.route, v_next_due, p_notes
  )
  RETURNING id INTO v_new_id;

  -- Rapel gorev olustur SADECE:
  -- 1. repeat_interval_days varsa
  -- 2. ileri_gebe'den tetiklenmemisse (GorevID: prefix = ileri_gebe kendi rapelini yaratir)
  -- 3. Duplicate yoksa (ayni hayvan + ASI_RAPEL + ayni hedef tarih + ayni asi)
  v_is_gorev_triggered := (p_notes IS NOT NULL AND p_notes LIKE 'GorevID:%');

  IF v_next_due IS NOT NULL AND NOT v_is_gorev_triggered THEN
    INSERT INTO public.gorev_log (
      hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi,
      stok_id, miktar, kaynak
    )
    SELECT
      p_animal_id,
      'ASI_RAPEL',
      v_vaccine.name || ' (rapel)',
      v_next_due,
      false,
      v_vaccine.stock_item_id,
      v_dose,
      'ASI_RAPEL'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.gorev_log
      WHERE hayvan_id = p_animal_id
        AND gorev_tipi = 'ASI_RAPEL'
        AND hedef_tarih = v_next_due
        AND aciklama LIKE v_vaccine.name || '%'
        AND tamamlandi = false
    );
  END IF;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'ASI_KAYDI',
    p_animal_id,
    v_new_id::text,
    'vaccination_log',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'vaccination_log', 'id', v_new_id::text)
      ),
      'guncellenen', '[]'::jsonb,
      'vaccine_name', v_vaccine.name,
      'next_due', v_next_due
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'vaccination_id', v_new_id,
    'next_due', v_next_due,
    'islem_id', v_islem_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_vaccination(text,uuid,date,numeric,text) TO anon, authenticated;

END;
