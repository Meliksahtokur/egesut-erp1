-- BUG-059 / Seans UI tamamlama: Planlanmış seansı düzenleme (incremental)
--
-- Sorun: add_treatment_day_with_sessions update modunda günü BAŞTAN kuruyor
--        (tüm treatment_day_uygulamalar DELETE + reinsert). Bu yüzden bir seans
--        "done" olunca tüm gün kilitleniyor (done seansı silmemek için) →
--        gerçekleşmemiş seanslara ilaç eklenip çıkarılamıyor, ekstra seans
--        eklenemiyor.
--
-- Çözüm: İki incremental RPC — mevcut (done dahil) seansları BOZMADAN çalışır.
--   1) add_sessions_to_existing_day  : güne yeni seans satırları ekler (append-only)
--   2) remove_treatment_session      : sadece done/iptal DEĞİLse tekil seans siler + stok iade
--
-- Her ikisi de add_treatment_day_with_sessions'ın seans INSERT döngüsünü birebir
-- aynalar (treatment_day_uygulamalar + drug_administrations + stok_hareket +
-- gorev_log TEDAVI_SEANS).

-- ── 1. Güne yeni seans ekle (mevcutları bozmadan) ──────────────────────────
CREATE OR REPLACE FUNCTION public.add_sessions_to_existing_day(
  p_day_id    uuid,
  p_sessions  jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_day            record;
  v_case           record;
  v_gorev_id       uuid;
  v_day_no         int;
  v_session        jsonb;
  v_admin_id       uuid;
  v_drug_admin_id  uuid;
  v_stok_id        text;
  v_added          int := 0;
  v_admin_ids      uuid[] := '{}';
BEGIN
  SELECT * INTO v_day FROM public.treatment_days WHERE id = p_day_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tedavi günü bulunamadı');
  END IF;

  SELECT * INTO v_case FROM public.cases WHERE id = v_day.case_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadı');
  END IF;
  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakaya seans eklenemez');
  END IF;
  IF p_sessions IS NULL OR jsonb_array_length(p_sessions) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Seans verisi boş');
  END IF;

  v_day_no := v_day.day_no;

  -- Parent TEDAVI_GUN görevini bul
  SELECT id INTO v_gorev_id FROM public.gorev_log
  WHERE gorev_tipi = 'TEDAVI_GUN'
    AND (aciklama::jsonb->>'day_id')::uuid = p_day_id
  LIMIT 1;

  -- Gün/görev otomatik kapanmışsa yeniden aç (yeni bekleyen seans geldi)
  UPDATE public.gorev_log
  SET tamamlandi = false, tamamlanma_tarihi = NULL
  WHERE id = v_gorev_id AND tamamlandi = true;

  UPDATE public.treatment_days
  SET tamamlandi = false, tamamlanma_tarihi = NULL
  WHERE id = p_day_id AND tamamlandi = true;

  FOR v_session IN SELECT * FROM jsonb_array_elements(p_sessions)
  LOOP
    INSERT INTO public.treatment_day_uygulamalar(
      treatment_day_id, case_id, planned_time, planned_date,
      stok_id, drug_product_id, dose, unit, route
    )
    VALUES (
      p_day_id, v_day.case_id,
      (v_session->>'planned_time')::time, v_day.treatment_date,
      v_session->>'stok_id',
      (v_session->>'drug_product_id')::uuid,
      (v_session->>'dose')::numeric,
      v_session->>'unit',
      v_session->>'route'
    )
    RETURNING id INTO v_admin_id;

    v_admin_ids := array_append(v_admin_ids, v_admin_id);

    INSERT INTO public.drug_administrations(
      treatment_day_id, stok_id, drug_product_id, dose, unit, route, seans_admin_id
    )
    VALUES (
      p_day_id,
      v_session->>'stok_id',
      (v_session->>'drug_product_id')::uuid,
      (v_session->>'dose')::numeric,
      v_session->>'unit',
      v_session->>'route',
      v_admin_id
    )
    RETURNING id INTO v_drug_admin_id;

    v_stok_id := v_session->>'stok_id';
    IF v_stok_id IS NOT NULL AND (v_session->>'dose')::numeric > 0 THEN
      INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar)
      VALUES (v_stok_id, 'Tedavi', (v_session->>'dose')::numeric,
              'drug_admin:' || v_drug_admin_id::text);
    END IF;

    INSERT INTO public.gorev_log(
      id, gorev_tipi, hayvan_id, hedef_tarih, hedef_saat,
      aciklama, tamamlandi, parent_id, seans_admin_id
    )
    VALUES (
      gen_random_uuid(), 'TEDAVI_SEANS', v_case.animal_id, v_day.treatment_date,
      (v_session->>'planned_time')::time,
      jsonb_build_object(
        'day_id', p_day_id,
        'planned_time', v_session->>'planned_time',
        'label', 'Gun ' || v_day_no || ' - Seans (' || (v_session->>'planned_time') || ')',
        'admin_id', v_admin_id
      )::text,
      false, v_gorev_id, v_admin_id
    );

    v_added := v_added + 1;
  END LOOP;

  -- seans_sayisi güncelle + planned_time'ı en erken seansa çek
  UPDATE public.treatment_days td
  SET seans_sayisi = (SELECT count(*) FROM public.treatment_day_uygulamalar WHERE treatment_day_id = p_day_id),
      planned_time = (SELECT min(planned_time) FROM public.treatment_day_uygulamalar WHERE treatment_day_id = p_day_id)
  WHERE td.id = p_day_id;

  INSERT INTO public.islem_log(id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text, 'SEANS_EKLENDI', v_case.animal_id,
    p_day_id::text, 'treatment_days',
    jsonb_build_object(
      'eklenen_seans', v_added,
      'olusturulan', COALESCE((
        SELECT jsonb_agg(jsonb_build_object('tablo', 'treatment_day_uygulamalar', 'id', id::text))
        FROM unnest(v_admin_ids) AS id), '[]'::jsonb)
    )
  );

  RETURN jsonb_build_object('ok', true, 'day_id', p_day_id, 'eklenen', v_added, 'admin_ids', v_admin_ids);
EXCEPTION WHEN unique_violation THEN
  -- treatment_day_uygulamalar(treatment_day_id, planned_time, stok_id) UNIQUE
  RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu saatte aynı ilaç zaten ekli — farklı saat ya da ilaç seçin');
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_sessions_to_existing_day(uuid, jsonb) TO anon, authenticated;

-- ── 2. Tekil seans sil (sadece gerçekleşmemiş) + stok iade ──────────────────
CREATE OR REPLACE FUNCTION public.remove_treatment_session(
  p_seans_id  uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_seans   record;
  v_animal  text;   -- animal_id bu ERP'de text (küpe ID), uuid DEĞİL
BEGIN
  SELECT * INTO v_seans FROM public.treatment_day_uygulamalar WHERE id = p_seans_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Seans bulunamadı');
  END IF;
  IF v_seans.uygulama_tamamlandi_at IS NOT NULL OR v_seans.uygulanmadi = true THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tamamlanmış/iptal seans silinemez');
  END IF;

  SELECT animal_id INTO v_animal FROM public.cases WHERE id = v_seans.case_id;

  -- Stok iade: bağlı drug_admin'in stok_hareket'ini iptal et
  UPDATE public.stok_hareket sh
  SET iptal = true
  FROM public.drug_administrations da
  WHERE da.seans_admin_id = p_seans_id
    AND sh.notlar = 'drug_admin:' || da.id::text
    AND sh.iptal = false;

  DELETE FROM public.drug_administrations WHERE seans_admin_id = p_seans_id;
  DELETE FROM public.gorev_log WHERE gorev_tipi = 'TEDAVI_SEANS' AND seans_admin_id = p_seans_id;
  DELETE FROM public.treatment_day_uygulamalar WHERE id = p_seans_id;

  -- seans_sayisi check constraint: 0 yasak → son seans silinince NULL; planned_time'ı kalan en erken seansa çek
  UPDATE public.treatment_days
  SET seans_sayisi = NULLIF((SELECT count(*) FROM public.treatment_day_uygulamalar WHERE treatment_day_id = v_seans.treatment_day_id), 0),
      planned_time = (SELECT min(planned_time) FROM public.treatment_day_uygulamalar WHERE treatment_day_id = v_seans.treatment_day_id)
  WHERE id = v_seans.treatment_day_id;

  INSERT INTO public.islem_log(id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text, 'SEANS_SILINDI', v_animal,
    p_seans_id::text, 'treatment_day_uygulamalar',
    jsonb_build_object('day_id', v_seans.treatment_day_id::text, 'stok_id', v_seans.stok_id)
  );

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.remove_treatment_session(uuid) TO anon, authenticated;
