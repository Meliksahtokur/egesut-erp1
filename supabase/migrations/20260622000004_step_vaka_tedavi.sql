-- AI Asistan Faz 2 — vaka_ac + tedavi_gun_ekle step ($ref bağımlılık)
-- Her iki helper tam gövde yeniden tanımı: gorev_kapat + hizli_uygulama + vaka_ac + tedavi_gun_ekle

CREATE OR REPLACE FUNCTION public._asistan_step_dogrula(p_tip text, p_param jsonb)
RETURNS jsonb AS $$
DECLARE
  v_n int;
BEGIN
  CASE p_tip
  WHEN 'gorev_kapat' THEN
    v_n := jsonb_array_length(COALESCE(p_param->'gorev_idler','[]'::jsonb));
    IF v_n = 0 THEN RETURN jsonb_build_object('ok',false,'hata','gorev_idler boş'); END IF;
    IF EXISTS (
      SELECT 1 FROM jsonb_array_elements_text(p_param->'gorev_idler') g(id)
      LEFT JOIN public.gorev_log gl ON gl.id::text = g.id
      WHERE gl.id IS NULL OR gl.tamamlandi = true OR gl.iptal = true
    ) THEN
      RETURN jsonb_build_object('ok',false,'hata','Bazı görevler bulunamadı veya zaten kapalı');
    END IF;
    RETURN jsonb_build_object('ok',true,'onizleme', v_n || ' görev kapatılacak');

  WHEN 'hizli_uygulama' THEN
    IF NOT (p_param ? 'hayvan_id' AND p_param ? 'stok_id' AND p_param ? 'doz') THEN
      RETURN jsonb_build_object('ok',false,'hata','hizli_uygulama: hayvan_id/stok_id/doz gerekli');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.hayvanlar WHERE id = p_param->>'hayvan_id' AND durum='Aktif') THEN
      RETURN jsonb_build_object('ok',false,'hata','Hayvan aktif değil: '||(p_param->>'hayvan_id'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.stok WHERE id = p_param->>'stok_id') THEN
      RETURN jsonb_build_object('ok',false,'hata','Stok yok: '||(p_param->>'stok_id'));
    END IF;
    RETURN jsonb_build_object('ok',true,'onizleme',
      (SELECT kupe_no FROM public.hayvanlar WHERE id=p_param->>'hayvan_id')||' → '||
      (SELECT urun_adi FROM public.stok WHERE id=p_param->>'stok_id')||' '||
      (p_param->>'doz')||COALESCE(p_param->>'birim','')||' '||COALESCE(p_param->>'rota',''));

  WHEN 'vaka_ac' THEN
    IF NOT (p_param ? 'hayvan_id' AND p_param ? 'disease_id') THEN
      RETURN jsonb_build_object('ok',false,'hata','vaka_ac: hayvan_id/disease_id gerekli'); END IF;
    IF NOT EXISTS (SELECT 1 FROM public.diseases WHERE id=(p_param->>'disease_id')::uuid) THEN
      RETURN jsonb_build_object('ok',false,'hata','Hastalık bulunamadı'); END IF;
    RETURN jsonb_build_object('ok',true,'onizleme',
      (SELECT kupe_no FROM public.hayvanlar WHERE id=p_param->>'hayvan_id')||' → vaka: '||
      (SELECT name FROM public.diseases WHERE id=(p_param->>'disease_id')::uuid));

  WHEN 'tedavi_gun_ekle' THEN
    IF NOT (p_param ? 'case_id' AND p_param ? 'tarih' AND p_param ? 'sessions') THEN
      RETURN jsonb_build_object('ok',false,'hata','tedavi_gun_ekle: case_id/tarih/sessions gerekli'); END IF;
    RETURN jsonb_build_object('ok',true,'onizleme',
      jsonb_array_length(p_param->'sessions')||' seans tedavi günü eklenecek');

  ELSE
    RETURN jsonb_build_object('ok',false,'hata','Bilinmeyen adım tipi: '||p_tip);
  END CASE;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION public._asistan_step_calistir(p_tip text, p_param jsonb)
RETURNS jsonb AS $$
DECLARE
  g text; r jsonb;
BEGIN
  CASE p_tip
  WHEN 'gorev_kapat' THEN
    FOR g IN SELECT jsonb_array_elements_text(p_param->'gorev_idler') LOOP
      r := public.gorev_tamamla(g, NULL);
      IF (r->>'ok') = 'false' THEN
        RAISE EXCEPTION 'gorev_tamamla(%) başarısız: %', g, r->>'mesaj';
      END IF;
    END LOOP;
    RETURN jsonb_build_object('kapatilan', jsonb_array_length(p_param->'gorev_idler'));

  WHEN 'hizli_uygulama' THEN
    r := public.hizli_uygulama(
      p_param->>'hayvan_id', p_param->>'stok_id',
      (p_param->>'doz')::numeric, COALESCE(p_param->>'birim','ml'),
      COALESCE(p_param->>'rota','IM'), COALESCE(p_param->>'notlar','AI Asistan'));
    IF (r->>'ok')='false' THEN RAISE EXCEPTION 'hizli_uygulama: %', r->>'mesaj'; END IF;
    RETURN r;

  WHEN 'vaka_ac' THEN
    r := public.create_case(p_param->>'hayvan_id', (p_param->>'disease_id')::uuid, p_param->>'not');
    IF (r->>'ok')='false' THEN RAISE EXCEPTION 'create_case: %', r->>'mesaj'; END IF;
    RETURN r;  -- case_id içerir ($ref için)

  WHEN 'tedavi_gun_ekle' THEN
    r := public.add_treatment_day_with_sessions(
      (p_param->>'case_id')::uuid, (p_param->>'tarih')::date, p_param->'sessions', NULL);
    IF (r->>'ok')='false' THEN RAISE EXCEPTION 'add_treatment_day: %', r->>'mesaj'; END IF;
    RETURN r;

  ELSE
    RAISE EXCEPTION 'Bilinmeyen adım tipi: %', p_tip;
  END CASE;
END;
$$ LANGUAGE plpgsql;
