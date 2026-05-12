-- Migration: tohumlama_sonuc_bos RPC
BEGIN;

CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_bos(
  p_tohumlama_id text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_hayvan_id text;
  v_toh_tarih date;
  v_sonuc text;
BEGIN
  -- Tohumlamayı bul
  SELECT hayvan_id, tarih, sonuc INTO v_hayvan_id, v_toh_tarih, v_sonuc
  FROM public.tohumlama WHERE id = p_tohumlama_id;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tohumlama bulunamadi');
  END IF;

  -- Sadece Bekliyor → Boş
  IF v_sonuc != 'Bekliyor' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Sadece Bekliyor durumundaki tohumlamalar Bos yapilabilir');
  END IF;

  -- Tohumlamayı güncelle
  UPDATE public.tohumlama
  SET sonuc = 'Bos', sonuc_tarihi = CURRENT_DATE
  WHERE id = p_tohumlama_id;

  -- islem_log'a yaz (trigger otomatik yazacak, manuel ek gerek yok)
  
  -- Event stack: Bekliyor → Boş → tohumlanabilir duruma geçir
  UPDATE public.hayvanlar
  SET tohumlama_durumu = 'tohumlanabilir'
  WHERE id = v_hayvan_id AND tohumlama_durumu = 'bekliyor';

  RETURN jsonb_build_object('ok', true, 'hayvan_id', v_hayvan_id, 'tohumlama_id', p_tohumlama_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.tohumlama_sonuc_bos(text) TO anon, authenticated;

COMMIT;