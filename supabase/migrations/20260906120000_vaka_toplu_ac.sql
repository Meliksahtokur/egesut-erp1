-- ============================================================================
-- TOPLU VAKA AÇ — vaka_toplu_ac RPC (G-20260906-TOPLU-VAKA, 2026-09-06)
-- ============================================================================
-- 1) create_case gövdesi birebir _vaka_ac_tek helper'ına taşındı (tek fark:
--    parametre adı p_animal_id → p_hayvan_id); create_case ince wrapper oldu —
--    imza ve davranış değişmedi (m-disease tek akışı, _asistan_step_calistir
--    çağrısı ve geri_al'in tükettiği islem_log VAKA_ACILDI snapshot'ı aynen).
-- 2) vaka_toplu_ac: N hayvana tek RPC ile vaka açar. Per-hayvan guard'lar
--    helper'dan {ok:false,mesaj} döner → 'atlanan' (dup aktif vaka buraya
--    düşer — server guard değişmez); beklenmeyen exception → 'hatalar'
--    (bulk_ilac 20260427000011 per-animal EXCEPTION deseni). Kısmi başarı
--    semantiği: ok:true (buzagi_sutten_kesme_toplu aynası).
--    p_sablon_id verilirse her açılan vakaya tedavi_sablon_uygula + VARSA
--    tedavi_sablon_tohumlama_gorev_ekle uygulanır. Tohumlama helper'ı GT'de
--    yok (GT drift riski) → pg_proc guard'ı bir kez kontrol eder; yoksa
--    RPC güvenli düşer, üst seviyede toplanti_uygulandi:false döner.
-- CANLI ŞEMA PROBE (2026-09-06, salt-okunur pg_get_functiondef):
--   create_case / tedavi_sablon_uygula / add_drug_administration imza+gövde
--   GT ile birebir; tedavi_sablon_tohumlama_gorev_ekle(uuid,uuid) → jsonb ve
--   _tohumlama_gorev_uygunluk(text,date) → text canlıda MEVCUT (GT'de yok).
-- Demo satırları owner verisidir; bu migration demo'ya uygulanır, PROD ayrı
-- owner onayı bekler.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. _vaka_ac_tek — create_case gövdesi birebir (yalnız parametre adı
--    p_animal_id → p_hayvan_id). GRANT YOK: internal helper (şema
--    sertleştirme bloğu anon/PUBLIC execute'u zaten kesiyor).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._vaka_ac_tek(
  p_hayvan_id   text,
  p_disease_id  uuid,
  p_notes       text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_new_id  uuid;
  v_animal  record;
  v_disease record;
BEGIN
  SELECT * INTO v_animal FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  SELECT * INTO v_disease FROM public.diseases WHERE id = p_disease_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hastalık kaydı bulunamadı');
  END IF;

  -- Aynı hayvanda aynı hastalıkta zaten aktif vaka var mı?
  IF EXISTS (
    SELECT 1 FROM public.cases
    WHERE animal_id = p_hayvan_id
      AND disease_id = p_disease_id
      AND status = 'active'
  ) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu hayvan için zaten aktif bir ' || v_disease.name || ' vakası mevcut');
  END IF;

  INSERT INTO public.cases (animal_id, disease_id, notes)
  VALUES (p_hayvan_id, p_disease_id, p_notes)
  RETURNING id INTO v_new_id;

  -- islem_log: geri alma icin snapshot
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    'VAKA_ACILDI',
    p_hayvan_id,
    v_new_id::text,
    'cases',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'cases', 'id', v_new_id::text)
      ),
      'guncellenen', '[]'::jsonb
    )
  );

  RETURN jsonb_build_object('ok', true, 'case_id', v_new_id);
END;
$$;

-- ----------------------------------------------------------------------------
-- 2. create_case — ince wrapper (imza/değer değişmedi)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.create_case(text, uuid, text);
CREATE OR REPLACE FUNCTION public.create_case(
  p_animal_id   text,
  p_disease_id  uuid,
  p_notes       text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN public._vaka_ac_tek(p_animal_id, p_disease_id, p_notes);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_case(text, uuid, text) TO anon, authenticated;

-- ----------------------------------------------------------------------------
-- 3. vaka_toplu_ac — toplu vaka açma (girdi sırası korunur, dedupe edilir)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.vaka_toplu_ac(
  p_animal_ids  text[],
  p_disease_id  uuid,
  p_sablon_id   uuid DEFAULT NULL,
  p_notes       text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_list          text[] := ARRAY[]::text[];
  v_seen          text[] := ARRAY[]::text[];
  v_id            text;
  v_toplam        int;
  v_basari        int := 0;
  v_acilan        jsonb := '[]'::jsonb;
  v_atlanan       jsonb := '[]'::jsonb;
  v_hatalar       jsonb := '[]'::jsonb;
  v_kupe          text;
  v_res           jsonb;
  v_case_id       uuid;
  v_sab           jsonb;
  v_sab_obj       jsonb;
  v_top           jsonb;
  v_ok            boolean;
  v_tohumlama_var boolean;
BEGIN
  IF p_animal_ids IS NULL OR array_length(p_animal_ids, 1) IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan listesi boş');
  END IF;
  IF array_length(p_animal_ids, 1) > 200 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'En fazla 200 hayvan');
  END IF;

  -- Dedupe: girdi sırası korunur
  FOREACH v_id IN ARRAY p_animal_ids LOOP
    IF v_id IS NOT NULL AND NOT (v_id = ANY (v_seen)) THEN
      v_seen := v_seen || v_id;
      v_list := v_list || v_id;
    END IF;
  END LOOP;
  v_toplam := array_length(v_list, 1);
  IF v_toplam IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan listesi boş');
  END IF;

  -- GT'de olmayan opsiyonel helper canlıdaysa uygula (pg_proc guard — bir kez,
  -- döngü dışında; helper yoksa RPC güvenli düşer)
  SELECT EXISTS (
    SELECT 1 FROM pg_proc
    WHERE proname = 'tedavi_sablon_tohumlama_gorev_ekle'
      AND pronamespace = 'public'::regnamespace
  ) INTO v_tohumlama_var;

  FOREACH v_id IN ARRAY v_list LOOP
    SELECT kupe_no INTO v_kupe FROM public.hayvanlar WHERE id = v_id;
    v_ok      := true;
    v_case_id := NULL;
    v_sab_obj := NULL;
    BEGIN
      v_res := public._vaka_ac_tek(v_id, p_disease_id, p_notes);
      IF (v_res->>'ok') <> 'true' THEN
        v_ok := false;
        v_atlanan := v_atlanan || jsonb_build_array(jsonb_build_object(
          'hayvan_id', v_id, 'kupe', v_kupe, 'mesaj', v_res->>'mesaj'));
      ELSE
        v_case_id := (v_res->>'case_id')::uuid;
        IF p_sablon_id IS NOT NULL THEN
          BEGIN
            v_sab := public.tedavi_sablon_uygula(p_case_id := v_case_id, p_sablon_id := p_sablon_id);
            v_sab_obj := jsonb_build_object(
              'gun_sayisi',   v_sab->'gun_sayisi',
              'seans_sayisi', v_sab->'seans_sayisi',
              'atlanan',      v_sab->'atlanan');
            IF v_tohumlama_var THEN
              v_top := public.tedavi_sablon_tohumlama_gorev_ekle(p_case_id := v_case_id, p_sablon_id := p_sablon_id);
              v_sab_obj := v_sab_obj || jsonb_build_object(
                'toplanti_uygulandi', COALESCE((v_top->>'olustu') = 'true', false),
                'toplanti_sebep',     v_top->'sebep');
            ELSE
              v_sab_obj := v_sab_obj || jsonb_build_object('toplanti_uygulandi', false);
            END IF;
          EXCEPTION WHEN OTHERS THEN
            -- Şablon hatası tek hayvanı hatalar'a düşürür; vaka açık kalır.
            v_ok := false;
            v_hatalar := v_hatalar || jsonb_build_array(jsonb_build_object(
              'hayvan_id', v_id, 'kupe', v_kupe, 'mesaj', SQLERRM, 'case_id', v_case_id));
          END;
        END IF;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      v_ok := false;
      v_hatalar := v_hatalar || jsonb_build_array(jsonb_build_object(
        'hayvan_id', v_id, 'kupe', v_kupe, 'mesaj', SQLERRM));
    END;

    IF v_ok THEN
      v_basari := v_basari + 1;
      v_acilan := v_acilan || jsonb_build_array(jsonb_build_object(
        'hayvan_id', v_id, 'kupe', v_kupe, 'case_id', v_case_id, 'sablon', v_sab_obj));
    END IF;
  END LOOP;

  IF v_tohumlama_var THEN
    RETURN jsonb_build_object('ok', true, 'toplam', v_toplam, 'basari', v_basari,
      'atlanan', v_atlanan, 'hatalar', v_hatalar, 'acilan', v_acilan,
      'sablon', p_sablon_id IS NOT NULL);
  END IF;

  -- Tohumlama helper'ı canlıda yok: güvenli düşüm işareti
  RETURN jsonb_build_object('ok', true, 'toplam', v_toplam, 'basari', v_basari,
    'atlanan', v_atlanan, 'hatalar', v_hatalar, 'acilan', v_acilan,
    'sablon', p_sablon_id IS NOT NULL, 'toplanti_uygulandi', false);
END;
$$;

GRANT EXECUTE ON FUNCTION public.vaka_toplu_ac(text[], uuid, uuid, text) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
