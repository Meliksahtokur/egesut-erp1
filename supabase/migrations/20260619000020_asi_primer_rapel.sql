-- add_vaccination: primer 2. doz (vaccine_protocol_steps) + muadil (vaccine_diseases) gecmis kontrolu
-- Yeni param: p_next_offset_days (offset override). p_skip_next ELENDI (olu feature, YAGNI).
-- Korunan: gorev_tipi='ASI_RAPEL', aciklama name-prefix, GorevID: branch, duplicate guard, islem_log,
--          vaccination_log INSERT (trg_vaccination_stok stok dusum trigger'i aynen calisir).
-- ATOMIK: yeni 6-param CREATE + eski 5-param DROP ayni transaction (yoksa positional call eski overload'a duser).
BEGIN;

CREATE OR REPLACE FUNCTION public.add_vaccination(
  p_animal_id        text,
  p_vaccine_id       uuid,
  p_date             date    DEFAULT CURRENT_DATE,
  p_dose_override    numeric DEFAULT NULL,
  p_notes            text    DEFAULT NULL,
  p_next_offset_days int     DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_vaccine     record;
  v_new_id      uuid;
  v_next_due    date;
  v_dose        numeric;
  v_animal      record;
  v_islem_id    text := gen_random_uuid()::text;
  v_is_gorev_triggered boolean;
  v_is_naive    boolean;
  v_step2       int;
  v_offset      int;
  v_label       text;
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

  -- vaccination_log INSERT -> trg_vaccination_stok stok dusum + yetersiz stok EXCEPTION (degismedi)
  INSERT INTO public.vaccination_log (
    animal_id, vaccine_id, vaccination_date, dose_given, unit, route, next_due_date, notes
  ) VALUES (
    p_animal_id, p_vaccine_id, p_date, v_dose,
    v_vaccine.unit, v_vaccine.route, NULL, p_notes
  )
  RETURNING id INTO v_new_id;

  v_is_gorev_triggered := (p_notes IS NOT NULL AND p_notes LIKE 'GorevID:%');

  -- Sonraki gorev offset belirleme (ileri_gebe kendi rapelini yaratir -> skip)
  v_offset := NULL;
  v_label  := NULL;
  IF NOT v_is_gorev_triggered THEN
    -- muadil naive: bu asinin kapsadigi hastaligi kapsayan onceki kayit var mi? (yeni satir haric)
    v_is_naive := NOT EXISTS (
      SELECT 1 FROM public.vaccination_log vl
      WHERE vl.animal_id = p_animal_id
        AND vl.id <> v_new_id
        AND (
          vl.vaccine_id = p_vaccine_id
          OR EXISTS (
            SELECT 1
            FROM public.vaccine_diseases a
            JOIN public.vaccine_diseases b ON b.disease_id = a.disease_id
            WHERE a.vaccine_id = p_vaccine_id
              AND b.vaccine_id = vl.vaccine_id
          )
        )
    );

    SELECT offset_gun INTO v_step2
    FROM public.vaccine_protocol_steps
    WHERE vaccine_id = p_vaccine_id AND adim_no = 2
    LIMIT 1;

    IF v_is_naive AND v_step2 IS NOT NULL THEN
      v_offset := v_step2;                        v_label := ' (2. doz)';
    ELSIF v_vaccine.repeat_interval_days IS NOT NULL THEN
      v_offset := v_vaccine.repeat_interval_days; v_label := ' (rapel)';
    END IF;

    -- modal override (kullanici offset gunu elle degistirdi)
    v_offset := COALESCE(p_next_offset_days, v_offset);
  END IF;

  IF v_offset IS NOT NULL THEN
    v_next_due := p_date + (v_offset || ' days')::interval;
    UPDATE public.vaccination_log SET next_due_date = v_next_due WHERE id = v_new_id;

    INSERT INTO public.gorev_log (
      hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi,
      stok_id, miktar, kaynak
    )
    SELECT
      p_animal_id, 'ASI_RAPEL',
      v_vaccine.name || COALESCE(v_label,''),
      v_next_due, false,
      v_vaccine.stock_item_id, v_dose, 'ASI_RAPEL'
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
    v_islem_id, 'ASI_KAYDI', p_animal_id, v_new_id::text, 'vaccination_log',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(jsonb_build_object('tablo','vaccination_log','id',v_new_id::text)),
      'guncellenen', '[]'::jsonb,
      'vaccine_name', v_vaccine.name,
      'next_due', v_next_due
    )
  );

  RETURN jsonb_build_object('ok', true, 'vaccination_id', v_new_id, 'next_due', v_next_due, 'islem_id', v_islem_id);
END;
$$;

-- Eski 5-param overload'i DROP (ATOMIK -- yoksa positional call'lar eskiye duser)
DROP FUNCTION IF EXISTS public.add_vaccination(text, uuid, date, numeric, text);

GRANT EXECUTE ON FUNCTION public.add_vaccination(text,uuid,date,numeric,text,int) TO anon, authenticated;

COMMIT;
