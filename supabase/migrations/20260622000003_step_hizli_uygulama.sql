-- AI Asistan Faz 2 — hizli_uygulama step (çoklu hayvan uygulama)
-- _asistan_step_dogrula + _asistan_step_calistir tam gövde yeniden tanımı (gorev_kapat + hizli_uygulama)

CREATE OR REPLACE FUNCTION public._asistan_step_dogrula(p_tip text, p_param jsonb)
RETURNS jsonb AS $$
DECLARE
  v_n int; v_satir text;
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

  ELSE
    RAISE EXCEPTION 'Bilinmeyen adım tipi: %', p_tip;
  END CASE;
END;
$$ LANGUAGE plpgsql;
