-- Cleanup: Drop old 6-param overload of tohumlama_kaydet
-- 7-param version (with p_ek_uygulamalar jsonb + p_vwp_override boolean) is the correct one.
-- The 6-param version was created by 20260526000003_ek_uygulama_stok.sql
-- and 20260531200000_faz_b_vwp_enforcement.sql added p_vwp_override but
-- CREATE OR REPLACE cannot change parameter count, so it created a 2nd overload.
-- This caused: "cannot get array length of a scalar" when frontend sends
-- p_ek_uygulamalar as JSON.stringify string instead of raw array.
-- The frontend fix (remove JSON.stringify) is in forms.js.
-- This migration removes the stale 6-param overload so PostgREST
-- always resolves to the 7-param version.

DROP FUNCTION IF EXISTS public.tohumlama_kaydet(text, date, text, text, text, jsonb);
