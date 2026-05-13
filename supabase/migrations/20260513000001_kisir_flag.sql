-- Migration: kisir flag + hayvan_kisir_isaretle RPC
BEGIN;

-- 1. Kolon ekle
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS kisir boolean DEFAULT false;

-- 2. RPC: kısır işaretle/kaldır
CREATE OR REPLACE FUNCTION public.hayvan_kisir_isaretle(
  p_hayvan_id text,
  p_kisir boolean
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_islem_id text := gen_random_uuid()::text;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  IF v_hayvan.kisir = p_kisir THEN
    RETURN jsonb_build_object('ok', true, 'mesaj', 'Zaten bu durumda');
  END IF;

  UPDATE public.hayvanlar SET kisir = p_kisir WHERE id = p_hayvan_id;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, snapshot)
  VALUES (
    v_islem_id,
    CASE WHEN p_kisir THEN 'KISIR_ISARETLE' ELSE 'KISIR_KALDIR' END,
    p_hayvan_id,
    jsonb_build_object(
      'guncellenen', jsonb_build_array(
        jsonb_build_object('tablo','hayvanlar','id',p_hayvan_id,'onceki',jsonb_build_object('kisir',v_hayvan.kisir))
      )
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$$;

END;
