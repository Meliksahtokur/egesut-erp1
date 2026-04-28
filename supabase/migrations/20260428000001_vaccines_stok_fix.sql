-- Migration: Vaccines stok backend integration — create real stock pools for vaccines
-- Fixes: All 10 vaccine seeds have stock_item_id=NULL, so vaccination_stok_dusum trigger
--        skips stock deduction entirely.
-- Solution: Auto-create stok items for vaccines and link them.
-- Revertable: YES — undo via DELETE + UPDATE (see ROLLBACK section)

BEGIN;

-- ══════════════════════════════════════════════════════════════
-- 1. Create stok items for vaccines where stock_item_id IS NULL
-- ══════════════════════════════════════════════════════════════
-- For each vaccine without a stock pool, create one with initial qty 1000 units

INSERT INTO public.stok (id, urun_adi, kategori, birim, baslangic_miktar, esik)
SELECT
  'STOK-AŞI-' || v.id::text,
  v.name,
  'Aşı',
  v.unit,
  1000,   -- initial stock: 1000 units (configurable)
  100    -- low-stock threshold
FROM public.vaccines v
WHERE v.stock_item_id IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.stok s
    WHERE s.id = 'STOK-AŞI-' || v.id::text
  );

-- ══════════════════════════════════════════════════════════════
-- 2. Update vaccines.stock_item_id to point to the new stok items
-- ══════════════════════════════════════════════════════════════
UPDATE public.vaccines
SET stock_item_id = 'STOK-AŞI-' || id::text
WHERE stock_item_id IS NULL;

-- ══════════════════════════════════════════════════════════════
-- 3. Verification query (run manually to check)
-- ══════════════════════════════════════════════════════════════
-- SELECT v.name, v.stock_item_id, s.baslangic_miktar
-- FROM public.vaccines v
-- JOIN public.stok s ON s.id = v.stock_item_id;

-- ══════════════════════════════════════════════════════════════
-- ROLLBACK (manual — run only if reverting)
-- ══════════════════════════════════════════════════════════════
-- UPDATE public.vaccines SET stock_item_id = NULL WHERE stock_item_id LIKE 'STOK-AŞI-%';
-- DELETE FROM public.stok WHERE id LIKE 'STOK-AŞI-%';

COMMIT;

-- PostgREST schema cache yenile
NOTIFY pgrst, 'reload schema';
