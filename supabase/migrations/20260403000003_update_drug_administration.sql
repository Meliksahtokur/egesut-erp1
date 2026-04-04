-- Migration: update_drug_administration RPC
-- Etkiler: Yeni RPC — ilaç uygulaması güncelle, stok delta kaydet
-- Geri alınabilir: DROP FUNCTION IF EXISTS public.update_drug_administration(uuid, numeric, text, text);

CREATE OR REPLACE FUNCTION public.update_drug_administration(
  p_admin_id  uuid,
  p_dose      numeric,
  p_unit      text,
  p_route     text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_admin  record;
  v_delta  numeric;
BEGIN
  SELECT da.*, d.stock_item_id
  INTO v_admin
  FROM drug_administrations da
  JOIN drugs d ON d.id = da.drug_id
  WHERE da.id = p_admin_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Kayıt bulunamadı');
  END IF;

  -- Doz farkı varsa stok hareketi ekle
  v_delta := p_dose - v_admin.dose;
  IF v_delta <> 0 AND v_admin.stock_item_id IS NOT NULL THEN
    INSERT INTO stok_hareket (id, stok_id, tur, miktar, notlar)
    VALUES (
      gen_random_uuid(),
      v_admin.stock_item_id::uuid,
      'Tedavi Düzelt',
      ABS(v_delta),
      'drug_admin:' || p_admin_id::text || ' — doz güncellendi, delta: ' || v_delta::text
    );
  END IF;

  UPDATE drug_administrations
  SET dose = p_dose, unit = p_unit, route = p_route
  WHERE id = p_admin_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;