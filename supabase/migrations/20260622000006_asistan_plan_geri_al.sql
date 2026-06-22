-- AI Asistan Faz 2.5 — plan geri alma (kısmi undo + uyarı)
-- Spesifik geri_al RPC'leri kullanılır (stok telafisi doğru; generic geri_al stok sızdırıyor).
-- Kapsam: gorev_kapat, hizli_uygulama, vaka_ac, tohumlama_kaydet. Diğerleri atlanır + raporlanır.

-- durum'a geri_alma değerleri ekle
ALTER TABLE public.agent_plans DROP CONSTRAINT IF EXISTS agent_plans_durum_check;
ALTER TABLE public.agent_plans ADD CONSTRAINT agent_plans_durum_check
  CHECK (durum IN ('pending','applied','cancelled','failed','expired','geri_alindi','kismen_geri_alindi'));

CREATE OR REPLACE FUNCTION public.asistan_plan_geri_al(p_plan_id uuid)
RETURNS jsonb AS $$
DECLARE
  v_plan record; v_adim jsonb; v_step_out jsonb;
  v_tip text; v_i int; v_n int; v_geri int := 0;
  v_atlanan jsonb := '[]'::jsonb; g text;
BEGIN
  SELECT * INTO v_plan FROM public.agent_plans
  WHERE id = p_plan_id AND kullanici_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'mesaj','Plan bulunamadı'); END IF;
  IF v_plan.durum <> 'applied' THEN
    RETURN jsonb_build_object('ok',false,'mesaj','Sadece uygulanmış plan geri alınır (durum: '||v_plan.durum||')');
  END IF;

  v_n := jsonb_array_length(v_plan.adimlar);
  -- Ters sırada geri al (her adım kendi subtransaction'ında — best effort)
  FOR v_i IN REVERSE v_n..1 LOOP
    v_adim     := v_plan.adimlar->(v_i-1);
    v_tip      := v_adim->>'tip';
    v_step_out := v_plan.sonuc->(v_i::text);
    BEGIN
      CASE v_tip
      WHEN 'gorev_kapat' THEN
        FOR g IN SELECT jsonb_array_elements_text(v_adim->'parametreler'->'gorev_idler') LOOP
          PERFORM public.gorev_geri_al(g);
        END LOOP;
        v_geri := v_geri + 1;
      WHEN 'hizli_uygulama' THEN
        PERFORM public.hizli_uygulama_geri_al((v_step_out->>'id')::uuid);
        v_geri := v_geri + 1;
      WHEN 'vaka_ac' THEN
        PERFORM public.case_geri_al((v_step_out->>'case_id')::uuid);
        v_geri := v_geri + 1;
      WHEN 'tohumlama_kaydet' THEN
        PERFORM public.tohumlama_geri_al(v_step_out->>'tohumlama_id');
        v_geri := v_geri + 1;
      ELSE
        v_atlanan := v_atlanan || jsonb_build_array(v_tip||' (geri alınamaz)');
      END CASE;
    EXCEPTION WHEN OTHERS THEN
      v_atlanan := v_atlanan || jsonb_build_array(v_tip||' (hata: '||SQLERRM||')');
    END;
  END LOOP;

  UPDATE public.agent_plans
  SET durum = CASE WHEN jsonb_array_length(v_atlanan)=0 THEN 'geri_alindi' ELSE 'kismen_geri_alindi' END,
      sonuc = COALESCE(sonuc,'{}'::jsonb) || jsonb_build_object('geri_al',
                jsonb_build_object('geri_alinan', v_geri, 'atlanan', v_atlanan))
  WHERE id = p_plan_id;

  RETURN jsonb_build_object('ok',true,'geri_alinan',v_geri,'atlanan',v_atlanan,
    'kismi', (jsonb_array_length(v_atlanan) > 0));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.asistan_plan_geri_al(uuid) TO authenticated;
