-- ════════════════════════════════════════════════════════════════════════════
-- farm_id İleri-Disiplini — Temel (Faz 2 Hazırlığı)
-- Tarih: 2026-07-01
-- Kapsam: SADECE public.current_farm_id() helper'ı + GRANT şeması.
--         Mevcut hiçbir tabloya/RLS'e/fonksiyona dokunmaz.
-- Kaynak: .claude/farm-id-discipline.md (kanonik kural belgesi).
-- ════════════════════════════════════════════════════════════════════════════

-- 1) Helper: şimdilik sabit REAL_FARM_ID döner. Faz 2'de JWT/profiles'tan okuyacak.
CREATE OR REPLACE FUNCTION public.current_farm_id() RETURNS uuid
LANGUAGE sql STABLE SET search_path = pg_catalog, public AS $$
  SELECT '400b9107-a85e-4126-af2c-fd7fe73fb68e'::uuid;
$$;

COMMENT ON FUNCTION public.current_farm_id() IS
  'farm_id ileri-disiplini: şimdilik REAL_FARM_ID sabiti. Faz 2 multi-tenant''te JWT/profiles''tan okunacak. Detay: .claude/farm-id-discipline.md';

-- 2) Güvenlik: ground_truth dosya sonundaki REVOKE/GRANT şeması tek başına
--    migration çalıştırıldığında yoktur. PUBLIC default execute yetkisi anon'a
--    miras kalır — bu helper authenticated kapsamda kalmalı (Faz 2 RLS policy
--    çağrıları authenticated session ile yapılacak).
REVOKE ALL ON FUNCTION public.current_farm_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_farm_id() TO authenticated;