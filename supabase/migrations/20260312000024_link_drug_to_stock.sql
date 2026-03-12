-- ══════════════════════════════════════════════════════════════
-- MIGRATION 024 — LINK DRUG TO STOCK RPC
-- EgeSüt ERP — 2026-03-12
--
-- Değişiklikler:
-- 1. link_drug_to_stock(p_drug_id uuid, p_stock_item_id text)
--    - drugs.stock_item_id günceller (NULL göndermek bağlantıyı koparır)
--    - p_stock_item_id NULL ise bağlantı kaldırılır
--    - stok kaydı yoksa hata döner
-- ══════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.link_drug_to_stock(uuid, text);

CREATE OR REPLACE FUNCTION public.link_drug_to_stock(
  p_drug_id        uuid,
  p_stock_item_id  text   -- NULL = bağlantıyı kaldır
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_drug  record;
BEGIN
  SELECT * INTO v_drug FROM public.drugs WHERE id = p_drug_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'İlaç kaydı bulunamadı');
  END IF;

  -- Stok kaydı var mı kontrolü (NULL ise atla — bağlantı kaldırma)
  IF p_stock_item_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM public.stok WHERE id = p_stock_item_id) THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok kalemi bulunamadı');
    END IF;
  END IF;

  UPDATE public.drugs
  SET stock_item_id = p_stock_item_id
  WHERE id = p_drug_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.link_drug_to_stock TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
