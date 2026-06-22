-- ════════════════════════════════════════════════════════════════
-- AI Asistan Faz 2 — Plan motoru
-- ════════════════════════════════════════════════════════════════

-- $ref çözücü: p_param içindeki "$N.key" string'lerini p_ctx->N->key ile değiştirir
CREATE OR REPLACE FUNCTION public._asistan_ref_coz(p_param jsonb, p_ctx jsonb)
RETURNS jsonb AS $$
DECLARE
  k text; v jsonb; m text[];
  v_out jsonb := p_param;
BEGIN
  FOR k, v IN SELECT * FROM jsonb_each(p_param) LOOP
    IF jsonb_typeof(v) = 'string' AND left(v #>> '{}', 1) = '$' THEN
      m := regexp_match(v #>> '{}', '^\$([0-9]+)\.(.+)$');
      IF m IS NOT NULL THEN
        v_out := jsonb_set(v_out, ARRAY[k],
          COALESCE(p_ctx -> m[1] -> m[2], 'null'::jsonb));
      END IF;
    END IF;
  END LOOP;
  RETURN v_out;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Step doğrulayıcı: {ok, hata, onizleme} döner. ÇALIŞTIRMAZ.
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
    v_satir := v_n || ' görev kapatılacak';
    RETURN jsonb_build_object('ok',true,'onizleme',v_satir);
  ELSE
    RETURN jsonb_build_object('ok',false,'hata','Bilinmeyen adım tipi: '||p_tip);
  END CASE;
END;
$$ LANGUAGE plpgsql STABLE;

-- Step çalıştırıcı: ilgili RPC'yi çağırır, çıktı jsonb döner. Transaction içinde çağrılır.
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
  ELSE
    RAISE EXCEPTION 'Bilinmeyen adım tipi: %', p_tip;
  END CASE;
END;
$$ LANGUAGE plpgsql;

-- Plan oluştur: adımları valide eder, agent_plans'e pending yazar, önizleme döner.
CREATE OR REPLACE FUNCTION public.asistan_plan_olustur(p_thread_id uuid, p_adimlar jsonb)
RETURNS jsonb AS $$
DECLARE
  v_adim jsonb; v_d jsonb; v_satirlar jsonb := '[]'::jsonb;
  v_plan_id uuid; v_n int;
BEGIN
  v_n := jsonb_array_length(COALESCE(p_adimlar,'[]'::jsonb));
  IF v_n = 0 THEN RETURN jsonb_build_object('ok',false,'mesaj','Boş plan'); END IF;
  IF v_n > 50 THEN RETURN jsonb_build_object('ok',false,'mesaj','Plan çok büyük (max 50 adım)'); END IF;

  FOR v_adim IN SELECT jsonb_array_elements(p_adimlar) LOOP
    v_d := public._asistan_step_dogrula(v_adim->>'tip', COALESCE(v_adim->'parametreler','{}'::jsonb));
    IF (v_d->>'ok') = 'false' THEN
      RETURN jsonb_build_object('ok',false,'mesaj', v_d->>'hata');
    END IF;
    v_satirlar := v_satirlar || jsonb_build_array(v_d->>'onizleme');
  END LOOP;

  INSERT INTO public.agent_plans (thread_id, adimlar, onizleme, durum)
  VALUES (p_thread_id, p_adimlar, jsonb_build_object('satirlar', v_satirlar), 'pending')
  RETURNING id INTO v_plan_id;

  RETURN jsonb_build_object('ok',true,'plan_id',v_plan_id,'onizleme',v_satirlar);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Plan uygula: pending planı sahiplik+atomik çalıştırır. $ref çözer. Hata → ROLLBACK.
CREATE OR REPLACE FUNCTION public.asistan_plan_uygula(p_plan_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_plan record; v_adim jsonb; v_ctx jsonb := '{}'::jsonb;
  v_param jsonb; v_out jsonb; v_i int := 0;
BEGIN
  SELECT * INTO v_plan FROM public.agent_plans
  WHERE id = p_plan_id AND kullanici_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'mesaj','Plan bulunamadı'); END IF;
  IF v_plan.durum <> 'pending' THEN
    RETURN jsonb_build_object('ok',false,'mesaj','Plan zaten '||v_plan.durum);
  END IF;

  BEGIN
    FOR v_adim IN SELECT jsonb_array_elements(v_plan.adimlar) LOOP
      v_i := v_i + 1;
      v_param := public._asistan_ref_coz(COALESCE(v_adim->'parametreler','{}'::jsonb), v_ctx);
      v_out := public._asistan_step_calistir(v_adim->>'tip', v_param);
      v_ctx := jsonb_set(v_ctx, ARRAY[v_i::text], COALESCE(v_out,'{}'::jsonb));
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    UPDATE public.agent_plans
    SET durum='failed', sonuc=jsonb_build_object('hata',SQLERRM,'adim',v_i)
    WHERE id = p_plan_id;
    RETURN jsonb_build_object('ok',false,'mesaj','Adım '||v_i||' başarısız: '||SQLERRM);
  END;

  UPDATE public.agent_plans
  SET durum='applied', applied_at=now(), sonuc=v_ctx
  WHERE id = p_plan_id;
  RETURN jsonb_build_object('ok',true,'plan_id',p_plan_id,'sonuc',v_ctx);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.asistan_plan_olustur(uuid, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.asistan_plan_uygula(uuid)         TO authenticated;
