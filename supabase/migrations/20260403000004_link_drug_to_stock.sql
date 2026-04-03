-- Migration: link_drug_to_stock RPC
-- Etkiler: Yeni RPC — ilacı stok kalemi ile ilişkilendir
-- Geri alınabilir: DROP FUNCTION IF EXISTS public.link_drug_to_stock(uuid, text);

CREATE OR REPLACE FUNCTION public.link_drug_to_stock(
  p_drug_id       uuid,
  p_stock_item_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE drugs SET stock_item_id = p_stock_item_id::uuid WHERE id = p_drug_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'İlaç bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;