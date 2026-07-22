-- Son tohumlama seçiminde deneme_no yerine tarih kullan.
-- Tekrar aşım ve gebe atama aynı deterministik sıralamayı kullanır.

BEGIN;

CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_gebe(
  p_tohumlama_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh               record;
  v_son_toh_id        text;
  v_islem_id          text   := gen_random_uuid()::text;
  v_onceki_durum      text;
  v_iptal_gorev_ids   text[] := '{}';
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama WHERE id::text = p_tohumlama_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tohumlama bulunamadı');
  END IF;

  IF v_toh.sonuc != 'Bekliyor' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Sadece Bekliyor durumundaki tohumlama gebe ilanı alabilir');
  END IF;

  SELECT id::text INTO v_son_toh_id
  FROM public.tohumlama
  WHERE hayvan_id = v_toh.hayvan_id
  ORDER BY tarih DESC, created_at DESC, id::text DESC
  LIMIT 1
  FOR UPDATE;

  IF v_son_toh_id != p_tohumlama_id THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Sadece son tohumlama gebe ilanı alabilir');
  END IF;

  SELECT tohumlama_durumu INTO v_onceki_durum
  FROM public.hayvanlar WHERE id = v_toh.hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan aktif değil');
  END IF;

  UPDATE public.tohumlama SET sonuc = 'Gebe' WHERE id::text = p_tohumlama_id;
  UPDATE public.hayvanlar SET tohumlama_durumu = 'Gebe' WHERE id = v_toh.hayvan_id;

  SELECT COALESCE(array_agg(id::text), '{}') INTO v_iptal_gorev_ids
  FROM public.gorev_log
  WHERE hayvan_id = v_toh.hayvan_id
    AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK')
    AND NOT tamamlandi AND NOT iptal;

  UPDATE public.gorev_log SET iptal = true
  WHERE hayvan_id = v_toh.hayvan_id
    AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK')
    AND NOT tamamlandi AND NOT iptal;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id, 'GEBE_ATAMA', v_toh.hayvan_id, p_tohumlama_id, 'tohumlama',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object('tablo', 'tohumlama', 'id', p_tohumlama_id, 'onceki', jsonb_build_object('sonuc', v_toh.sonuc)),
        jsonb_build_object('tablo', 'hayvanlar', 'id', v_toh.hayvan_id, 'onceki', jsonb_build_object('tohumlama_durumu', v_onceki_durum))
      ),
      'iptal_gorevler', to_jsonb(v_iptal_gorev_ids),
      'iptal_sebep', 'gebe'
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.tohumlama_tekrar_kaydet(
  p_hayvan_id text,
  p_tarih date,
  p_sperma text,
  p_hekim_id text DEFAULT NULL::text,
  p_irk_bilgisi text DEFAULT NULL::text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_toh record;
  v_eski jsonb;
  v_yeni_denemeler jsonb;
BEGIN
  SELECT * INTO v_hayvan
  FROM public.hayvanlar
  WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id; END IF;
  IF p_tarih > CURRENT_DATE THEN RAISE EXCEPTION 'Tarih ileri olamaz'; END IF;

  SELECT * INTO v_toh
  FROM public.tohumlama
  WHERE hayvan_id = p_hayvan_id
    AND sonuc = 'Bekliyor'
    AND tarih >= CURRENT_DATE - INTERVAL '15 days'
  ORDER BY tarih DESC, created_at DESC, id::text DESC
  LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'Son 15 gün içinde Bekliyor tohumlama bulunamadı'; END IF;

  v_eski := jsonb_build_object('no', v_toh.deneme_sayisi, 'tarih', v_toh.tarih, 'sperma', v_toh.sperma, 'hekim_id', v_toh.hekim_id);
  v_yeni_denemeler := v_toh.denemeler || jsonb_build_array(v_eski);

  UPDATE public.tohumlama
  SET tarih = p_tarih, sperma = p_sperma, hekim_id = COALESCE(p_hekim_id, hekim_id),
      irk_bilgisi = COALESCE(p_irk_bilgisi, irk_bilgisi),
      deneme_sayisi = deneme_sayisi + 1, denemeler = v_yeni_denemeler
  WHERE id = v_toh.id;

  UPDATE public.gorev_log SET iptal = true
  WHERE hayvan_id = p_hayvan_id AND tamamlandi = false AND iptal = false
    AND gorev_tipi IN ('TOHUMLAMA_HAZIRLIK', 'GEBELIK_KONTROL');

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, ref_tohumlama_id)
  VALUES
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL', '21. Gün gebelik kontrolü', p_tarih + 21, false, v_toh.id::text),
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL', '35. Gün gebelik kontrolü', p_tarih + 35, false, v_toh.id::text);

  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  SELECT s.id, 'Tohumlama', 1,
    'Tekrar Aşım ' || (v_toh.deneme_sayisi + 1) || '. deneme — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id), false
  FROM public.stok s
  WHERE (s.urun_adi ILIKE '%' || p_sperma || '%' OR s.urun_adi = p_sperma)
    AND s.kategori = 'Sperma'
  LIMIT 1;

  RETURN jsonb_build_object('ok', true, 'tohumlama_id', v_toh.id, 'deneme_sayisi', v_toh.deneme_sayisi + 1);
END;
$$;

COMMIT;
