-- 20260909000001_sablon_aktif_vakaya_uygula.sql
-- Aktif vakaya şablon uygulama: iki şablon RPC'sine opsiyonel çapa tarihi.
-- p_baslangic_tarihi NULL ⇔ eski davranış (case.start_date çapası) — geriye
-- uyumlu: submitCase (forms.js) ve vaka_toplu_ac'un 2-argümanlı çağrıları
-- DEFAULT üzerinden aynı davranışa bağlanır (PL/pgSQL çağrıları plan-anında
-- isimle çözümlenir; DROP+CREATE sonrası iç çağrılar yeniden bağlanır).
-- Gövdeler: tedavi_sablon_uygula = GT/20260613000009 birebir;
-- tohumlama = 20260730000002 birebir. Yalnız v_date çapası COALESCE'e bağlandı.

-- 1) tedavi_sablon_uygula — gün kalemlerini çapadan dizer
DROP FUNCTION IF EXISTS public.tedavi_sablon_uygula(uuid, uuid);
CREATE FUNCTION public.tedavi_sablon_uygula(
  p_case_id          uuid,
  p_sablon_id        uuid,
  p_baslangic_tarihi date DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_case         record;
  v_gun_no       smallint;
  v_date         date;
  v_sessions     jsonb;
  v_atlanan      jsonb := '[]'::jsonb;
  v_gun_atlanan  jsonb;
  v_gun_sayisi   int := 0;
  v_seans_sayisi int := 0;
BEGIN
  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadı'); END IF;
  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakaya şablon uygulanamaz');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.tedavi_sablonu WHERE id = p_sablon_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Şablon bulunamadı');
  END IF;

  FOR v_gun_no IN
    SELECT DISTINCT gun_no FROM public.tedavi_sablonu_kalem
    WHERE sablon_id = p_sablon_id ORDER BY gun_no
  LOOP
    v_date := COALESCE(p_baslangic_tarihi, v_case.start_date) + (v_gun_no - 1);

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
             'planned_time',    to_char(k.planned_time,'HH24:MI'),
             'stok_id',         k.stok_id,
             'drug_product_id', k.drug_product_id,
             'dose',            k.dose,
             'unit',            k.unit,
             'route',           k.route
           ) ORDER BY k.planned_time), '[]'::jsonb)
    INTO v_sessions
    FROM public.tedavi_sablonu_kalem k
    WHERE k.sablon_id = p_sablon_id AND k.gun_no = v_gun_no
      AND (k.drug_product_id IS NULL OR EXISTS (SELECT 1 FROM public.drug_products dp WHERE dp.id = k.drug_product_id))
      AND (k.stok_id IS NULL OR EXISTS (SELECT 1 FROM public.stok s WHERE s.id = k.stok_id));

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
             'gun_no', k.gun_no,
             'planned_time', to_char(k.planned_time,'HH24:MI'),
             'neden', 'silinmiş ilaç/stok')), '[]'::jsonb)
    INTO v_gun_atlanan
    FROM public.tedavi_sablonu_kalem k
    WHERE k.sablon_id = p_sablon_id AND k.gun_no = v_gun_no
      AND ((k.drug_product_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.drug_products dp WHERE dp.id = k.drug_product_id))
        OR (k.stok_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.stok s WHERE s.id = k.stok_id)));
    IF jsonb_array_length(v_gun_atlanan) > 0 THEN
      v_atlanan := v_atlanan || v_gun_atlanan;
    END IF;

    IF jsonb_array_length(v_sessions) > 0 THEN
      PERFORM public.add_treatment_day_with_sessions(p_case_id, v_date, v_sessions, NULL);
      v_gun_sayisi   := v_gun_sayisi + 1;
      v_seans_sayisi := v_seans_sayisi + jsonb_array_length(v_sessions);
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true,
    'gun_sayisi', v_gun_sayisi, 'seans_sayisi', v_seans_sayisi, 'atlanan', v_atlanan);
END;
$$;

GRANT EXECUTE ON FUNCTION public.tedavi_sablon_uygula(uuid, uuid, date) TO anon, authenticated;

-- 2) tedavi_sablon_tohumlama_gorev_ekle — planlı tohumlamayı çapadan dizer
DROP FUNCTION IF EXISTS public.tedavi_sablon_tohumlama_gorev_ekle(uuid, uuid);
CREATE FUNCTION public.tedavi_sablon_tohumlama_gorev_ekle(
  p_case_id          uuid,
  p_sablon_id        uuid,
  p_baslangic_tarihi date DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_plan  jsonb;
  v_case  record;
  v_sebep text;
  v_id    uuid;
  v_date  date;
  v_time  time;
BEGIN
  -- nullif(...,'null'::jsonb): kolonda jsonb 'null' skaleri duruyor olabilir.
  SELECT nullif(tohumlama_plani, 'null'::jsonb) INTO v_plan
  FROM public.tedavi_sablonu WHERE id = p_sablon_id;
  IF v_plan IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'olustu', false);
  END IF;
  IF (v_plan->>'gun_ofset') IS NULL OR nullif(v_plan->>'planned_time','') IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'olustu', false, 'sebep', 'Şablondaki tohumlama planı eksik');
  END IF;

  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Vaka bulunamadı'; END IF;

  IF EXISTS (SELECT 1 FROM public.gorev_log
             WHERE kaynak = 'TEDAVI_SABLON_TOHUMLAMA:' || p_case_id::text || ':' || p_sablon_id::text) THEN
    RETURN jsonb_build_object('ok', true, 'olustu', false);
  END IF;

  v_date := COALESCE(p_baslangic_tarihi, v_case.start_date) + (v_plan->>'gun_ofset')::integer;
  v_time := (v_plan->>'planned_time')::time;

  -- Uygun değilse vaka açılışı patlamaz; görev açılmaz, sebep UI'a döner.
  v_sebep := public._tohumlama_gorev_uygunluk(v_case.animal_id, v_date);
  IF v_sebep IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'olustu', false, 'sebep', v_sebep);
  END IF;

  INSERT INTO public.gorev_log(id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, tamamlandi, kaynak)
  VALUES(gen_random_uuid(), v_case.animal_id, 'TOHUMLAMA_PLANLI', 'Planlı tohumlama', v_date, v_time, false,
          'TEDAVI_SABLON_TOHUMLAMA:' || p_case_id::text || ':' || p_sablon_id::text)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'olustu', true, 'gorev_id', v_id);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.tedavi_sablon_tohumlama_gorev_ekle(uuid, uuid, date) TO anon, authenticated;
