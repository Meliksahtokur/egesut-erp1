CREATE OR REPLACE FUNCTION public.tohumlama_abort(p_tohumlama_id text, p_notlar text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_toh           record;
  v_islem_id      text := gen_random_uuid()::text;
  v_onceki_durum  text;
  v_onceki_tarih  date;
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama WHERE id::text = p_tohumlama_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı'); END IF;
  IF v_toh.sonuc != 'Gebe' THEN RETURN jsonb_build_object('ok', false, 'error', 'Sadece Gebe durumundaki tohumlama abort edilebilir'); END IF;
  SELECT tohumlama_durumu, tohumlama_onay_tarihi INTO v_onceki_durum, v_onceki_tarih FROM public.hayvanlar WHERE id = v_toh.hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil'); END IF;
  UPDATE public.tohumlama SET sonuc = 'Abort', abort_notlar = p_notlar WHERE id::text = p_tohumlama_id;
  UPDATE public.hayvanlar SET tohumlama_durumu = NULL, tohumlama_onay_tarihi = NULL WHERE id = v_toh.hayvan_id;
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (v_islem_id, 'ABORT_KAYDI', v_toh.hayvan_id, p_tohumlama_id, 'tohumlama',
    jsonb_build_object('olusturulan', '[]'::jsonb, 'guncellenen', jsonb_build_array(jsonb_build_object('tablo', 'tohumlama', 'id', p_tohumlama_id, 'onceki', jsonb_build_object('sonuc', v_toh.sonuc)), jsonb_build_object('tablo', 'hayvanlar', 'id', v_toh.hayvan_id, 'onceki', jsonb_build_object('tohumlama_durumu', v_onceki_durum, 'tohumlama_onay_tarihi', v_onceki_tarih))), 'notlar', p_notlar));
  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$function$
;
