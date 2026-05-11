-- Migration: stok_duzelt RPC for stock count correction
BEGIN;

CREATE OR REPLACE FUNCTION public.stok_duzelt(
  p_stok_id text,
  p_yeni_miktar numeric,
  p_not text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok record;
  v_guncel numeric;
  v_fark numeric;
BEGIN
  SELECT * INTO v_stok FROM stok WHERE id = p_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok bulunamadi');
  END IF;

  SELECT COALESCE(v_stok.baslangic_miktar, 0) - COALESCE(SUM(sh.miktar), 0)
  INTO v_guncel
  FROM stok_hareket sh
  WHERE sh.stok_id = p_stok_id AND NOT sh.iptal;

  v_guncel := COALESCE(v_guncel, COALESCE(v_stok.baslangic_miktar, 0));
  v_fark := v_guncel - p_yeni_miktar;

  IF v_fark = 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Miktar zaten aynı');
  END IF;

  INSERT INTO stok_hareket (stok_id, tur, miktar, notlar, iptal, referans_tipi)
  VALUES (p_stok_id, 'Duzeltme', v_fark, COALESCE(p_not, 'Sayim duzeltmesi'), false, 'duzeltme');

  RETURN jsonb_build_object('ok', true, 'eski', v_guncel, 'yeni', p_yeni_miktar, 'fark', v_fark);
END;
$$;

GRANT EXECUTE ON FUNCTION public.stok_duzelt(text, numeric, text) TO anon, authenticated;

END;
