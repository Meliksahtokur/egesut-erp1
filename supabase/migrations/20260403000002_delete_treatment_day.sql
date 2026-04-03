-- Migration: delete_treatment_day RPC
-- Etkiler: Yeni RPC — tedavi günü + ilaçları sil, stok ledger'ı tersle
-- Geri alınabilir: DROP FUNCTION IF EXISTS public.delete_treatment_day(uuid);

CREATE OR REPLACE FUNCTION public.delete_treatment_day(
  p_day_id uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_admin record;
BEGIN
  -- Stok geri yaz (her ilaç uygulaması için ters hareket)
  FOR v_admin IN
    SELECT da.id, da.drug_id, da.dose, da.unit, d.stock_item_id
    FROM drug_administrations da
    JOIN drugs d ON d.id = da.drug_id
    WHERE da.treatment_day_id = p_day_id
      AND d.stock_item_id IS NOT NULL
  LOOP
    INSERT INTO stok_hareket (id, stok_id, tur, miktar, notlar)
    VALUES (
      gen_random_uuid(),
      v_admin.stock_item_id::uuid,
      'Tedavi Düzelt',
      v_admin.dose,
      'drug_admin:' || v_admin.id::text || ' — tedavi günü silindi, iade'
    );
  END LOOP;

  -- Kayıtları sil (drug_administrations önce, sonra treatment_day)
  DELETE FROM drug_administrations WHERE treatment_day_id = p_day_id;
  DELETE FROM treatment_days WHERE id = p_day_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;