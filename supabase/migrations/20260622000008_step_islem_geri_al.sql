-- AI Asistan Faz 2.5 — sohbetten geri alma: islem_geri_al step
-- Agent'a undo yeteneği (HITL akışından geçer: aksiyon_plani → onay kartı → plani_uygula).
-- ref_tablo'ya göre SPESİFİK geri_al RPC'sine yönlendirir (generic geri_al stok sızdırıyor — kullanılmaz).
-- Her iki helper tam gövde yeniden tanımı (8 step tipi).

CREATE OR REPLACE FUNCTION public._asistan_step_dogrula(p_tip text, p_param jsonb)
RETURNS jsonb AS $$
DECLARE
  v_n int; v_seans text; v_vaka text;
  v_rt text; v_rtip text; v_rdurum text;
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
    SELECT string_agg(
      COALESCE((SELECT urun_adi FROM public.stok WHERE id = s->>'stok_id'), s->>'stok_id')||' '||
      (s->>'dose')||COALESCE(s->>'unit','')||' '||COALESCE(s->>'route','')||
      COALESCE(' @'||(s->>'planned_time'),''), ', ')
    INTO v_seans FROM jsonb_array_elements(p_param->'sessions') s;
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

  WHEN 'islem_geri_al' THEN
    IF NOT (p_param ? 'islem_id') THEN
      RETURN jsonb_build_object('ok',false,'hata','islem_geri_al: islem_id gerekli (islem_log.id)'); END IF;
    SELECT ref_tablo, tip, durum INTO v_rt, v_rtip, v_rdurum
    FROM public.islem_log WHERE id = p_param->>'islem_id';
    IF v_rtip IS NULL THEN RETURN jsonb_build_object('ok',false,'hata','İşlem bulunamadı'); END IF;
    IF v_rdurum = 'geri_alindi' THEN RETURN jsonb_build_object('ok',false,'hata','Bu işlem zaten geri alınmış'); END IF;
    IF v_rt NOT IN ('uygulama_log','cases','tohumlama','gorev_log') THEN
      RETURN jsonb_build_object('ok',false,'hata','Bu işlem tipi geri alınamaz ('||COALESCE(v_rt,'?')||') — manuel düzeltme gerekir');
    END IF;
    RETURN jsonb_build_object('ok',true,'onizleme','GERİ AL: '||v_rtip||' ('||v_rt||') işlemi geri alınacak');

  ELSE
    RETURN jsonb_build_object('ok',false,'hata','Bilinmeyen adım tipi: '||p_tip);
  END CASE;
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION public._asistan_step_calistir(p_tip text, p_param jsonb)
RETURNS jsonb AS $$
DECLARE
  g text; r jsonb; v_rt text; v_rid text;
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
    RETURN r;

  WHEN 'tedavi_gun_ekle' THEN
    r := public.add_treatment_day_with_sessions(
      (p_param->>'case_id')::uuid, (p_param->>'tarih')::date, p_param->'sessions', NULL);
    IF (r->>'ok')='false' THEN RAISE EXCEPTION 'add_treatment_day: %', r->>'mesaj'; END IF;
    RETURN r;

  WHEN 'tohumlama_kaydet' THEN
    r := public.tohumlama_kaydet(
      p_hayvan_id   := p_param->>'hayvan_id',
      p_tarih       := (p_param->>'tarih')::date,
      p_sperma      := p_param->>'sperma',
      p_hekim_id    := NULLIF(p_param->>'hekim_id',''),
      p_irk_bilgisi := NULLIF(p_param->>'irk_bilgisi',''),
      p_vwp_override := false);
    IF (r->>'ok')='false' THEN RAISE EXCEPTION 'tohumlama_kaydet: %', r->>'mesaj'; END IF;
    RETURN r;

  WHEN 'padok_toplu' THEN
    r := public.padok_degistir_toplu(
      ARRAY(SELECT jsonb_array_elements_text(p_param->'hayvan_idler')),
      (p_param->>'yeni_padok_id')::uuid, NULL, NULLIF(p_param->>'yeni_grup',''));
    IF (r->>'success')='false' THEN RAISE EXCEPTION 'padok_degistir_toplu: %', r->>'error'; END IF;
    RETURN r;

  WHEN 'dogum_kaydet' THEN
    r := public.dogum_kaydet(p_param->>'anne_id', (p_param->>'tarih')::date, p_param->>'buzagi_kupe',
      COALESCE(p_param->>'cins','Dişi'), COALESCE(p_param->>'tip','Normal'),
      NULLIF(p_param->>'kg','')::numeric, NULLIF(p_param->>'baba',''), NULLIF(p_param->>'hekim_id',''));
    IF (r->>'ok')='false' THEN RAISE EXCEPTION 'dogum_kaydet: %', r->>'mesaj'; END IF;
    RETURN r;

  WHEN 'islem_geri_al' THEN
    SELECT ref_tablo, ref_id INTO v_rt, v_rid FROM public.islem_log WHERE id = p_param->>'islem_id';
    IF v_rt IS NULL THEN RAISE EXCEPTION 'İşlem bulunamadı: %', p_param->>'islem_id'; END IF;
    IF    v_rt='uygulama_log' THEN r := public.hizli_uygulama_geri_al(v_rid::uuid);
    ELSIF v_rt='cases'        THEN r := public.case_geri_al(v_rid::uuid);
    ELSIF v_rt='tohumlama'    THEN r := public.tohumlama_geri_al(v_rid);
    ELSIF v_rt='gorev_log'    THEN r := public.gorev_geri_al(v_rid);
    ELSE  RAISE EXCEPTION 'Geri alınamaz işlem tipi: %', v_rt; END IF;
    IF (r->>'ok')='false' THEN RAISE EXCEPTION 'geri alma başarısız: %', COALESCE(r->>'mesaj',r->>'hata'); END IF;
    RETURN jsonb_build_object('geri_alindi', v_rt, 'ref_id', v_rid);

  ELSE
    RAISE EXCEPTION 'Bilinmeyen adım tipi: %', p_tip;
  END CASE;
END;
$$ LANGUAGE plpgsql;
