-- ══════════════════════════════════════════════════════════════
-- MIGRATION 023 — REMOVE DRUG ADMINISTRATION RPC
-- EgeSüt ERP — 2026-03-12
--
-- Değişiklikler:
-- 1. remove_drug_administration(p_admin_id uuid) → jsonb
--    - drug_administrations kaydını siler
--    - Bağlı stok_hareket satırını iptal=true yapar (ledger bütünlüğü)
--    - Kapalı vakada silme yasak
--    - stok_hareket kaydı yoksa (stok_item_id=NULL ilaç) yine de siler
-- ══════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.remove_drug_administration(uuid);

CREATE OR REPLACE FUNCTION public.remove_drug_administration(
  p_admin_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_admin  record;
  v_day    record;
  v_case   record;
BEGIN
  -- Kaydı çek
  SELECT * INTO v_admin
  FROM   public.drug_administrations
  WHERE  id = p_admin_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'İlaç kaydı bulunamadı');
  END IF;

  -- Tedavi günü → vaka kontrolü
  SELECT * INTO v_day  FROM public.treatment_days WHERE id = v_admin.treatment_day_id;
  SELECT * INTO v_case FROM public.cases          WHERE id = v_day.case_id;

  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakadan ilaç silinemez');
  END IF;

  -- Bağlı stok_hareket satırını iptal et (ledger'ı geri al)
  -- referans_tipi='drug_administration' AND referans_id=p_admin_id::text ile eşleştir
  UPDATE public.stok_hareket
  SET    iptal = true
  WHERE  referans_tipi = 'drug_administration'
    AND  referans_id   = p_admin_id::text
    AND  NOT iptal;

  -- Kaydı sil (ON DELETE CASCADE: yoksa gün silerken zaten temizlenir ama burada explicit)
  DELETE FROM public.drug_administrations WHERE id = p_admin_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.remove_drug_administration TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
