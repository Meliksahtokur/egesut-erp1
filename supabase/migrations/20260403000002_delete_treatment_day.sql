-- Migration: delete_treatment_day RPC
-- Duzeltildi: 2026-05-13 — drug_id→drug_product_id, stock_item_id JOIN kaldirildi (stok_id direkt kullan)

CREATE OR REPLACE FUNCTION public.delete_treatment_day(
  p_day_id uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_admin record;
BEGIN
  -- Stok geri yaz (her ilaç uygulaması için ters hareket)
  FOR v_admin IN
    SELECT da.id, da.dose, da.stok_id
    FROM drug_administrations da
    WHERE da.treatment_day_id = p_day_id
      AND da.stok_id IS NOT NULL
  LOOP
    INSERT INTO stok_hareket (id, stok_id, tur, miktar, notlar)
    VALUES (
      gen_random_uuid(),
      v_admin.stok_id,
      'Tedavi Duzelt',
      v_admin.dose,
      'drug_admin:' || v_admin.id::text || ' — tedavi gunu silindi, iade'
    );
  END LOOP;

  -- Kayıtları sil (drug_administrations önce, sonra treatment_day)
  DELETE FROM drug_administrations WHERE treatment_day_id = p_day_id;
  DELETE FROM treatment_days WHERE id = p_day_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;
