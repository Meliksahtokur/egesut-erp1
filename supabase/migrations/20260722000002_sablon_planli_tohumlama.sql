-- Şablon sonuna planlı tohumlama adımı: mevcut parent_id UI zincirini kullanır.
ALTER TABLE public.tedavi_sablonu
  ADD COLUMN IF NOT EXISTS tohumlama_plani jsonb;

ALTER TABLE public.tohumlama
  ADD COLUMN IF NOT EXISTS gerceklesme_at timestamptz;

CREATE OR REPLACE FUNCTION public.tedavi_sablon_kaydet(
  p_id uuid, p_ad text, p_aciklama text, p_disease_ids jsonb, p_kalemler jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id uuid;
  v_kalemler jsonb := CASE WHEN jsonb_typeof(p_kalemler)='object' THEN coalesce(p_kalemler->'kalemler','[]'::jsonb) ELSE coalesce(p_kalemler,'[]'::jsonb) END;
  v_tohumlama jsonb := CASE WHEN jsonb_typeof(p_kalemler)='object' THEN p_kalemler->'tohumlama_plani' ELSE NULL END;
BEGIN
  IF p_ad IS NULL OR btrim(p_ad) = '' THEN RETURN jsonb_build_object('ok',false,'mesaj','Şablon adı zorunlu'); END IF;
  IF EXISTS (SELECT 1 FROM public.tedavi_sablonu WHERE lower(ad)=lower(p_ad) AND (p_id IS NULL OR id<>p_id)) THEN
    RETURN jsonb_build_object('ok',false,'mesaj','Bu isimde başka bir şablon var');
  END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_kalemler) k WHERE coalesce((k->>'gun_no')::smallint,0)<1) THEN
    RETURN jsonb_build_object('ok',false,'mesaj','Şablon gün ofseti 0 veya daha büyük olmalı');
  END IF;
  IF v_tohumlama IS NOT NULL AND (
    coalesce((v_tohumlama->>'gun_ofset')::integer,-1)<0 OR nullif(v_tohumlama->>'planned_time','') IS NULL
  ) THEN RETURN jsonb_build_object('ok',false,'mesaj','Planlı tohumlama gün ve saat bilgisi zorunlu'); END IF;

  IF p_id IS NULL THEN
    INSERT INTO public.tedavi_sablonu(ad,aciklama,tohumlama_plani)
    VALUES(p_ad,NULLIF(btrim(coalesce(p_aciklama,'')),''),v_tohumlama) RETURNING id INTO v_id;
  ELSE
    UPDATE public.tedavi_sablonu SET ad=p_ad,aciklama=NULLIF(btrim(coalesce(p_aciklama,'')),''),tohumlama_plani=v_tohumlama,updated_at=now() WHERE id=p_id;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'mesaj','Şablon bulunamadı'); END IF;
    v_id:=p_id;
    DELETE FROM public.sablon_hastalik_eslem WHERE sablon_id=v_id;
    DELETE FROM public.tedavi_sablonu_kalem WHERE sablon_id=v_id;
  END IF;
  INSERT INTO public.sablon_hastalik_eslem(sablon_id,disease_id)
  SELECT v_id,t.val::uuid FROM jsonb_array_elements_text(coalesce(p_disease_ids,'[]'::jsonb)) t(val)
  ON CONFLICT(sablon_id,disease_id) DO NOTHING;
  INSERT INTO public.tedavi_sablonu_kalem(sablon_id,gun_no,planned_time,stok_id,drug_product_id,dose,unit,route)
  SELECT v_id,(k->>'gun_no')::smallint,(k->>'planned_time')::time,NULLIF(k->>'stok_id',''),NULLIF(k->>'drug_product_id','')::uuid,(k->>'dose')::numeric,k->>'unit',NULLIF(k->>'route','')
  FROM jsonb_array_elements(v_kalemler) k;
  RETURN jsonb_build_object('ok',true,'sablon_id',v_id);
END; $$;

CREATE OR REPLACE FUNCTION public.tedavi_sablon_tohumlama_gorev_ekle(p_case_id uuid,p_sablon_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_plan jsonb; v_case record; v_parent uuid; v_id uuid; v_date date; v_time time;
BEGIN
  SELECT tohumlama_plani INTO v_plan FROM public.tedavi_sablonu WHERE id=p_sablon_id;
  IF v_plan IS NULL THEN RETURN jsonb_build_object('ok',true,'olustu',false); END IF;
  SELECT * INTO v_case FROM public.cases WHERE id=p_case_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Vaka bulunamadı'; END IF;
  SELECT g.id INTO v_parent FROM public.gorev_log g JOIN public.treatment_days td ON (g.aciklama::jsonb->>'day_id')::uuid=td.id
   WHERE td.case_id=p_case_id AND g.gorev_tipi='TEDAVI_GUN' ORDER BY td.day_no DESC LIMIT 1;
  IF v_parent IS NULL THEN RAISE EXCEPTION 'Tohumlama için tedavi görevi bulunamadı'; END IF;
  IF EXISTS (SELECT 1 FROM public.gorev_log WHERE kaynak='TEDAVI_SABLON_TOHUMLAMA:'||p_case_id::text||':'||p_sablon_id::text) THEN
    RETURN jsonb_build_object('ok',true,'olustu',false);
  END IF;
  v_date:=v_case.start_date+(v_plan->>'gun_ofset')::integer; v_time:=(v_plan->>'planned_time')::time;
  INSERT INTO public.gorev_log(id,hayvan_id,gorev_tipi,aciklama,hedef_tarih,hedef_saat,tamamlandi,parent_id,kaynak)
  VALUES(gen_random_uuid(),v_case.animal_id,'TOHUMLAMA_PLANLI','Planlı tohumlama',v_date,v_time,false,v_parent,'TEDAVI_SABLON_TOHUMLAMA:'||p_case_id::text||':'||p_sablon_id::text)
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
  IF v_gorev.parent_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.gorev_log WHERE id=v_gorev.parent_id AND tamamlandi=true) THEN RAISE EXCEPTION 'Önceki tedavi görevi tamamlanmadan tohumlama yapılamaz'; END IF;
  v_result:=public.tohumlama_kaydet(p_hayvan_id,p_tarih,p_sperma,p_hekim_id,p_irk_bilgisi,p_ek_uygulamalar,p_vwp_override);
  v_tohumlama_id:=v_result->>'tohumlama_id';
  UPDATE public.tohumlama SET gerceklesme_at=now() WHERE id=v_tohumlama_id::uuid;
  UPDATE public.gorev_log SET tamamlandi=true,tamamlanma_tarihi=now(),ref_tohumlama_id=v_tohumlama_id WHERE id=p_gorev_id;
  INSERT INTO public.islem_log(id,tip,ana_hayvan_id,ref_id,ref_tablo,snapshot)
  VALUES(gen_random_uuid()::text,'PLANLI_TOHUMLAMA_TAMAMLA',p_hayvan_id,p_gorev_id::text,'gorev_log',jsonb_build_object('tohumlama_id',v_tohumlama_id));
  RETURN v_result || jsonb_build_object('gorev_id',p_gorev_id);
END; $$;

GRANT EXECUTE ON FUNCTION public.tedavi_sablon_tohumlama_gorev_ekle(uuid,uuid) TO anon,authenticated;
GRANT EXECUTE ON FUNCTION public.planli_tohumlama_kaydet(uuid,text,date,text,text,text,jsonb,boolean) TO anon,authenticated;
