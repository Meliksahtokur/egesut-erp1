-- Migration: stok iade on geri_al + geçmiş tarih auto-done
-- Etkilenen: geri_al RPC, add_treatment_day RPC

-- 1. geri_al: treatment_days ve cases silinirken stok_hareket cleanup
--    Canlıda stok_hareket.notlar = 'drug_admin:{uuid}' formatında saklanıyor
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

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_snapshot->'olusturulan')
  LOOP
    v_tablo := v_item->>'tablo';
    v_pk    := v_item->>'id';

    IF v_tablo = 'treatment_days' THEN
      -- Stok iade: bu güne ait drug_admin stok hareketlerini sil
      DELETE FROM public.stok_hareket
      WHERE notlar IN (
        SELECT 'drug_admin:' || da.id::text
        FROM public.drug_administrations da
        WHERE da.treatment_day_id = v_pk::uuid
      );
      -- Sonra treatment_day sil (CASCADE: drug_administrations otomatik)
      DELETE FROM public.treatment_days WHERE id = v_pk::uuid;

    ELSIF v_tablo = 'cases' THEN
      -- Stok iade: tüm treatment_days'e ait stok hareketleri
      DELETE FROM public.stok_hareket
      WHERE notlar IN (
        SELECT 'drug_admin:' || da.id::text
        FROM public.drug_administrations da
        JOIN public.treatment_days td ON da.treatment_day_id = td.id
        WHERE td.case_id = v_pk::uuid
      );
      -- Sonra sil (CASCADE zinciri)
      DELETE FROM public.cases WHERE id = v_pk::uuid;

    ELSE
      BEGIN
        EXECUTE format('DELETE FROM %I WHERE id = $1', v_tablo) USING v_pk;
      EXCEPTION WHEN others THEN
        EXECUTE format('DELETE FROM %I WHERE id = $1::uuid', v_tablo) USING v_pk;
      END;
    END IF;
  END LOOP;

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


-- 2. add_treatment_day: geçmiş tarih → tamamlandi=true, gorev de done
CREATE OR REPLACE FUNCTION public.add_treatment_day(
  p_case_id uuid,
  p_date    date
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_day_id   uuid;
  v_gorev_id uuid;
  v_day_no   int;
  v_case     record;
  v_gecmis   boolean;
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

  v_gecmis := p_date < CURRENT_DATE;

  INSERT INTO public.treatment_days(id, case_id, day_no, treatment_date, tamamlandi, tamamlanma_tarihi)
  VALUES (
    gen_random_uuid(), p_case_id, v_day_no, p_date,
    v_gecmis,
    CASE WHEN v_gecmis THEN p_date::timestamptz ELSE NULL END
  )
  RETURNING id INTO v_day_id;

  INSERT INTO public.gorev_log(id, gorev_tipi, hayvan_id, hedef_tarih, aciklama, tamamlandi, tamamlanma_tarihi)
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
    v_gecmis,
    CASE WHEN v_gecmis THEN p_date::timestamptz ELSE NULL END
  )
  RETURNING id INTO v_gorev_id;

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

  RETURN jsonb_build_object('ok', true, 'day_id', v_day_id, 'day_no', v_day_no, 'gecmis', v_gecmis);
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_treatment_day(uuid, date) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
