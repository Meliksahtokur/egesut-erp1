-- AI Asistan Faz 2.5 — zengin diff önizlemesi
-- _asistan_step_dogrula tam gövde: hizli_uygulama (grup eklendi) + tedavi_gun_ekle (ilaç/doz/vaka özeti)

CREATE OR REPLACE FUNCTION public._asistan_step_dogrula(p_tip text, p_param jsonb)
RETURNS jsonb AS $$
DECLARE
  v_n int; v_seans text; v_vaka text;
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
      (SELECT kupe_no || COALESCE(' ('||grup||')','') FROM public.hayvanlar WHERE id=p_param->>'hayvan_id')||
      ' → bağımsız uygulama: '||
      (SELECT urun_adi FROM public.stok WHERE id=p_param->>'stok_id')||' '||
      (p_param->>'doz')||COALESCE(p_param->>'birim','')||' '||COALESCE(p_param->>'rota',''));

  WHEN 'vaka_ac' THEN
    IF NOT (p_param ? 'hayvan_id' AND p_param ? 'disease_id') THEN
      RETURN jsonb_build_object('ok',false,'hata','vaka_ac: hayvan_id/disease_id gerekli'); END IF;
    IF NOT EXISTS (SELECT 1 FROM public.diseases WHERE id=(p_param->>'disease_id')::uuid) THEN
      RETURN jsonb_build_object('ok',false,'hata','Hastalık bulunamadı'); END IF;
    RETURN jsonb_build_object('ok',true,'onizleme',
      (SELECT kupe_no || COALESCE(' ('||grup||')','') FROM public.hayvanlar WHERE id=p_param->>'hayvan_id')||
      ' → yeni vaka aç: '||
      (SELECT name FROM public.diseases WHERE id=(p_param->>'disease_id')::uuid));

  WHEN 'tedavi_gun_ekle' THEN
    IF NOT (p_param ? 'case_id' AND p_param ? 'tarih' AND p_param ? 'sessions') THEN
      RETURN jsonb_build_object('ok',false,'hata','tedavi_gun_ekle: case_id/tarih/sessions gerekli'); END IF;
    -- Seans özeti (ilaç adı + doz + rota)
    SELECT string_agg(
      COALESCE((SELECT urun_adi FROM public.stok WHERE id = s->>'stok_id'), s->>'stok_id')||' '||
      (s->>'dose')||COALESCE(s->>'unit','')||' '||COALESCE(s->>'route','')||
      COALESCE(' @'||(s->>'planned_time'),''), ', ')
    INTO v_seans FROM jsonb_array_elements(p_param->'sessions') s;
    -- Vaka bağlamı (case_id $ref değilse hastalık adını çek)
    v_vaka := CASE
      WHEN left(p_param->>'case_id',1) = '$' THEN 'yeni açılan vakaya'
      ELSE COALESCE((SELECT d.name FROM public.cases c JOIN public.diseases d ON d.id=c.disease_id
                     WHERE c.id=(p_param->>'case_id')::uuid),'vakaya')||' vakasına'
    END;
    RETURN jsonb_build_object('ok',true,'onizleme',
      v_vaka||' tedavi günü ('||(p_param->>'tarih')||'): '||COALESCE(v_seans,'seans yok'));

  WHEN 'tohumlama_kaydet' THEN
    IF NOT (p_param ? 'hayvan_id' AND p_param ? 'tarih' AND p_param ? 'sperma') THEN
      RETURN jsonb_build_object('ok',false,'hata','tohumlama_kaydet: hayvan_id/tarih/sperma gerekli'); END IF;
    IF EXISTS (SELECT 1 FROM public.hayvanlar WHERE id=p_param->>'hayvan_id'
               AND (tohumlama_durumu ILIKE 'gebe' OR grup ILIKE 'Sağmal (Kuru)')) THEN
      RETURN jsonb_build_object('ok',false,'hata','Hayvan gebe veya kuru — tohumlanamaz'); END IF;
    RETURN jsonb_build_object('ok',true,'onizleme',
      (SELECT kupe_no FROM public.hayvanlar WHERE id=p_param->>'hayvan_id')||' → tohumlama: '||
      (p_param->>'sperma')||' ('||(p_param->>'tarih')||')');

  WHEN 'padok_toplu' THEN
    IF NOT (p_param ? 'hayvan_idler' AND p_param ? 'yeni_padok_id') THEN
      RETURN jsonb_build_object('ok',false,'hata','padok_toplu: hayvan_idler/yeni_padok_id gerekli'); END IF;
    RETURN jsonb_build_object('ok',true,'onizleme',
      jsonb_array_length(p_param->'hayvan_idler')||' hayvan → '||
      (SELECT ad FROM public.padoklar WHERE id=(p_param->>'yeni_padok_id')::uuid)||' padok'||
      COALESCE(' / grup: '||(p_param->>'yeni_grup'),''));

  WHEN 'dogum_kaydet' THEN
    IF NOT (p_param ? 'anne_id' AND p_param ? 'tarih' AND p_param ? 'buzagi_kupe') THEN
      RETURN jsonb_build_object('ok',false,'hata','dogum_kaydet: anne_id/tarih/buzagi_kupe gerekli'); END IF;
    RETURN jsonb_build_object('ok',true,'onizleme',
      (SELECT kupe_no FROM public.hayvanlar WHERE id=p_param->>'anne_id')||' doğum → buzağı '||
      (p_param->>'buzagi_kupe')||COALESCE(' ('||(p_param->>'cins')||')','')||
      ' · anne otomatik Sağmal''a alınır + görevler açılır');

  ELSE
    RETURN jsonb_build_object('ok',false,'hata','Bilinmeyen adım tipi: '||p_tip);
  END CASE;
END;
$$ LANGUAGE plpgsql STABLE;
