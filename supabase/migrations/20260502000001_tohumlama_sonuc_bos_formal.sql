-- Formal migration: tohumlama_sonuc_bos RPC standalone contract
-- Etkiler: tohumlama_sonuc_bos RPC (CREATE OR REPLACE)
-- Tablolar: tohumlama, hayvanlar, islem_log
-- Geri alınabilir: evet — DROP FUNCTION tohumlama_sonuc_bos(text,text);

BEGIN;

CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_bos(
  p_tohumlama_id text,
  p_notlar       text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh          record;
  v_islem_id     text := gen_random_uuid()::text;
  v_onceki_durum text;
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama
  WHERE id::text = p_tohumlama_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  IF v_toh.sonuc != 'Bekliyor' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Bekliyor durumundaki tohumlama boş ilan edilebilir');
  END IF;

  -- TEXT karşılaştırma — ::uuid cast kaldırıldı (hayvanlar.id TEXT)
  SELECT tohumlama_durumu INTO v_onceki_durum
  FROM public.hayvanlar
  WHERE id = v_toh.hayvan_id
    AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil');
  END IF;

  -- Tohumlama sonucunu Boş yap
  UPDATE public.tohumlama SET sonuc = 'Boş' WHERE id::text = p_tohumlama_id;

  -- Hayvanın tohumlama_durumu güncelle
  UPDATE public.hayvanlar
  SET tohumlama_durumu = 'Boş'
  WHERE id = v_toh.hayvan_id;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'TOHUMLAMA_SONUC',
    v_toh.hayvan_id,
    p_tohumlama_id,
    'tohumlama',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object(
          'tablo', 'tohumlama',
          'id', p_tohumlama_id,
          'onceki', jsonb_build_object('sonuc', v_toh.sonuc)
        ),
        jsonb_build_object(
          'tablo', 'hayvanlar',
          'id', v_toh.hayvan_id,
          'onceki', jsonb_build_object('tohumlama_durumu', v_onceki_durum)
        )
      ),
      'notlar', p_notlar
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$$;

COMMIT;
