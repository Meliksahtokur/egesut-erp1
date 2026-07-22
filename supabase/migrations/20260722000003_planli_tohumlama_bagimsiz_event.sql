-- Planlı tohumlama, tedavi gününün içinde tanımlanır ama bağımsız görev olarak çalışır.
CREATE OR REPLACE FUNCTION public.tedavi_sablon_tohumlama_gorev_ekle(p_case_id uuid,p_sablon_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_plan jsonb; v_case record; v_id uuid; v_date date; v_time time;
BEGIN
  SELECT tohumlama_plani INTO v_plan FROM public.tedavi_sablonu WHERE id=p_sablon_id;
  IF v_plan IS NULL THEN RETURN jsonb_build_object('ok',true,'olustu',false); END IF;
  SELECT * INTO v_case FROM public.cases WHERE id=p_case_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Vaka bulunamadı'; END IF;
  IF EXISTS (SELECT 1 FROM public.gorev_log WHERE kaynak='TEDAVI_SABLON_TOHUMLAMA:'||p_case_id::text||':'||p_sablon_id::text) THEN RETURN jsonb_build_object('ok',true,'olustu',false); END IF;
  v_date:=v_case.start_date+(v_plan->>'gun_ofset')::integer; v_time:=(v_plan->>'planned_time')::time;
  INSERT INTO public.gorev_log(id,hayvan_id,gorev_tipi,aciklama,hedef_tarih,hedef_saat,tamamlandi,kaynak)
  VALUES(gen_random_uuid(),v_case.animal_id,'TOHUMLAMA_PLANLI','Planlı tohumlama',v_date,v_time,false,'TEDAVI_SABLON_TOHUMLAMA:'||p_case_id::text||':'||p_sablon_id::text)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok',true,'olustu',true,'gorev_id',v_id);
END; $$;

CREATE OR REPLACE FUNCTION public.planli_tohumlama_kaydet(
  p_gorev_id uuid,p_hayvan_id text,p_tarih date,p_sperma text,p_hekim_id text DEFAULT NULL,p_irk_bilgisi text DEFAULT NULL,p_ek_uygulamalar jsonb DEFAULT '[]'::jsonb,p_vwp_override boolean DEFAULT false
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_gorev record; v_result jsonb; v_tohumlama_id text;
BEGIN
  SELECT * INTO v_gorev FROM public.gorev_log WHERE id=p_gorev_id FOR UPDATE;
  IF NOT FOUND OR v_gorev.gorev_tipi<>'TOHUMLAMA_PLANLI' THEN RAISE EXCEPTION 'Planlı tohumlama görevi bulunamadı'; END IF;
  IF v_gorev.tamamlandi OR v_gorev.iptal THEN RAISE EXCEPTION 'Görev kapalı'; END IF;
  IF v_gorev.hayvan_id<>p_hayvan_id THEN RAISE EXCEPTION 'Görev hayvanı ile tohumlama hayvanı eşleşmiyor'; END IF;
  v_result:=public.tohumlama_kaydet(p_hayvan_id,p_tarih,p_sperma,p_hekim_id,p_irk_bilgisi,p_ek_uygulamalar,p_vwp_override);
  v_tohumlama_id:=v_result->>'tohumlama_id';
  UPDATE public.tohumlama SET gerceklesme_at=now() WHERE id=v_tohumlama_id::uuid;
  UPDATE public.gorev_log SET tamamlandi=true,tamamlanma_tarihi=now(),ref_tohumlama_id=v_tohumlama_id WHERE id=p_gorev_id;
  INSERT INTO public.islem_log(id,tip,ana_hayvan_id,ref_id,ref_tablo,snapshot)
  VALUES(gen_random_uuid()::text,'PLANLI_TOHUMLAMA_TAMAMLA',p_hayvan_id,p_gorev_id::text,'gorev_log',jsonb_build_object('tohumlama_id',v_tohumlama_id));
  RETURN v_result || jsonb_build_object('gorev_id',p_gorev_id);
END; $$;
