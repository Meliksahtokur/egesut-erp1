-- Vaka Geri Alma — islem_log Entegrasyonu
-- Etkiler: geri_al (UUID fix), create_case (islem_log snapshot), add_treatment_day (gorev RETURNING + islem_log)
-- Idempotent: CREATE OR REPLACE

-- 1. geri_al: UUID id desteği (try/catch)
CREATE OR REPLACE FUNCTION public.geri_al(p_islem_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_snapshot  jsonb;
  v_item      jsonb;
  v_tablo     text;
  v_pk        text;
  v_onceki    jsonb;
  v_col       text;
  v_val       text;
  v_set_parts text[] := '{}';
  v_sql       text;
BEGIN
  SELECT snapshot INTO v_snapshot
  FROM islem_log
  WHERE id = p_islem_id;

  IF v_snapshot IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'islem bulunamadi');
  END IF;

  -- Oluşturulan kayıtları sil (text veya uuid id kolonuna göre)
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_snapshot->'olusturulan')
  LOOP
    v_tablo := v_item->>'tablo';
    v_pk    := v_item->>'id';
    BEGIN
      EXECUTE format('DELETE FROM %I WHERE id = $1', v_tablo) USING v_pk;
    EXCEPTION WHEN others THEN
      EXECUTE format('DELETE FROM %I WHERE id = $1::uuid', v_tablo) USING v_pk;
    END;
  END LOOP;

  -- Güncellenen kayıtları geri al
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_snapshot->'guncellenen')
  LOOP
    v_tablo  := v_item->>'tablo';
    v_pk     := v_item->>'id';
    v_onceki := v_item->'onceki';
    v_set_parts := '{}';

    FOR v_col, v_val IN SELECT key, value #>> '{}' FROM jsonb_each(v_onceki)
    LOOP
      v_set_parts := array_append(
        v_set_parts,
        format('%I = %L', v_col, v_val)
      );
    END LOOP;

    IF array_length(v_set_parts, 1) > 0 THEN
      v_sql := format(
        'UPDATE %I SET %s WHERE id = $1',
        v_tablo,
        array_to_string(v_set_parts, ', ')
      );
      EXECUTE v_sql USING v_pk;
    END IF;
  END LOOP;

  UPDATE islem_log SET durum = 'geri_alindi' WHERE id = p_islem_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.geri_al(text) TO anon, authenticated;

-- 2. create_case: islem_log snapshot ekle
CREATE OR REPLACE FUNCTION public.create_case(
  p_animal_id   text,
  p_disease_id  uuid,
  p_notes       text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_new_id  uuid;
  v_animal  record;
  v_disease record;
BEGIN
  SELECT * INTO v_animal FROM public.hayvanlar WHERE id = p_animal_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  SELECT * INTO v_disease FROM public.diseases WHERE id = p_disease_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hastalık kaydı bulunamadı');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.cases
    WHERE animal_id = p_animal_id AND disease_id = p_disease_id AND status = 'active'
  ) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu hayvan için zaten aktif bir ' || v_disease.name || ' vakası mevcut');
  END IF;

  INSERT INTO public.cases (animal_id, disease_id, notes)
  VALUES (p_animal_id, p_disease_id, p_notes)
  RETURNING id INTO v_new_id;

  -- islem_log: geri alma için snapshot
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    'VAKA_ACILDI',
    p_animal_id,
    v_new_id::text,
    'cases',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'cases', 'id', v_new_id::text)
      ),
      'guncellenen', '[]'::jsonb
    )
  );

  RETURN jsonb_build_object('ok', true, 'case_id', v_new_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_case(text, uuid, text) TO anon, authenticated;

-- 3. add_treatment_day: gorev_log RETURNING + islem_log snapshot
CREATE OR REPLACE FUNCTION public.add_treatment_day(
  p_case_id uuid,
  p_date date
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_day_id   uuid;
  v_gorev_id uuid;
  v_day_no   int;
  v_case     record;
BEGIN
  SELECT COALESCE(MAX(day_no), 0) + 1 INTO v_day_no
  FROM public.treatment_days
  WHERE case_id = p_case_id;

  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadı');
  END IF;

  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakaya gün eklenemez');
  END IF;

  INSERT INTO public.treatment_days(id, case_id, day_no, treatment_date)
  VALUES (gen_random_uuid(), p_case_id, v_day_no, p_date)
  RETURNING id INTO v_day_id;

  INSERT INTO public.gorev_log(id, gorev_tipi, hayvan_id, hedef_tarih, aciklama, tamamlandi)
  VALUES (
    gen_random_uuid(),
    'TEDAVI_GUN',
    v_case.animal_id,
    p_date,
    jsonb_build_object(
      'day_id', v_day_id,
      'gun_no', v_day_no,
      'label',  'Gün ' || v_day_no || ' tedavisi — ' || to_char(p_date, 'DD.MM.YYYY')
    )::text,
    false
  )
  RETURNING id INTO v_gorev_id;

  -- islem_log snapshot (geri alma için)
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    'TEDAVI_GUN_EKLENDI',
    v_case.animal_id,
    v_day_id::text,
    'treatment_days',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'treatment_days', 'id', v_day_id::text),
        jsonb_build_object('tablo', 'gorev_log',      'id', v_gorev_id::text)
      ),
      'guncellenen', '[]'::jsonb
    )
  );

  RETURN jsonb_build_object('ok', true, 'day_id', v_day_id, 'day_no', v_day_no);
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_treatment_day(uuid, date) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
