-- Migration: 20260502000003_drop_orphan_objects.sql
-- Date: 2026-05-02
-- Purpose: Clean up dead DB objects documented as unused in ARCHITECTURE.md §4.4
--
-- Removed objects:
--   1. buzagi_takip table — orphan, never referenced in application code
--   2. hastalik_log.ilac_stok_id — orphan column (system uses tedavi/cases/drug_administrations)
--   3. hastalik_log.ilac_miktar — orphan column (same as above)
--
-- References:
--   - ARCHITECTURE.md §4.4 (technical debt)
--   - egesut-deep-status-2026-05-02.md §3d

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Drop orphan table buzagi_takip
-- ─────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS public.buzagi_takip;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Drop orphan columns from hastalik_log
-- Note: mig-011 already dropped ilac_stok_id and ilac_miktar in 2026-04-27;
-- IF EXISTS is safe in case migration 011 was not yet applied.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.hastalik_log DROP COLUMN IF EXISTS ilac_stok_id;
ALTER TABLE public.hastalik_log DROP COLUMN IF EXISTS ilac_miktar;