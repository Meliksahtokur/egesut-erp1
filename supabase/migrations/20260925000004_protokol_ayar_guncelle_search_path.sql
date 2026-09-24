-- ════════════════════════════════════════════════════════════════════
-- ONARIM — protokol_ayar_guncelle SECURITY DEFINER'a search_path kilidi
-- Tarih: 2026-09-25 · Kaynak: final review güvenlik notu
--
-- SORUN: protokol_ayar_guncelle(text, numeric) SECURITY DEFINER'da
--   SET search_path YOK (20260620000001_protokol_ayar.sql:36'dan beri).
--   S2 onarımı 5 RPC'yi sertleştirmişti; bu fonksiyon o zarfın dışında kalmış
--   ön-existing borçtu. search_path'siz SECURITY DEFINER, search_path
--   zehirlenmesi yüzeyi taşır (Postgres en-iyi-praktik kuralı).
--
-- FIX: gövde yalnız public.protokol_ayar + public.islem_log'a (tam-şema-nitelikli)
--   referans veriyor — ALTER ile 'public, pg_temp' kilidi güvenlidir; gövde
--   DEĞİŞMEZ, ACL DEĞİŞMEZ, davranış DEĞİŞMEZ.
--
-- KANAL: yalnız DEMO (sahip onaylı); prod ayrı sahip kapısıdır.
-- anon GRANT YAZILMAZ (kural); ACL'ye dokunulmaz.
-- ROLLBACK: ALTER FUNCTION ... SET search_path TO DEFAULT (tek satır).
-- ════════════════════════════════════════════════════════════════════

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- Not: değer tırnaklı TEK string'tir ('public, pg_temp') — ALTER FUNCTION SET
-- grameri tek-değer alır; semantik, CREATE FUNCTION'daki list biçimiyle aynıdır.
ALTER FUNCTION public.protokol_ayar_guncelle(text, numeric)
SET search_path = 'public, pg_temp';

COMMIT;

NOTIFY pgrst, 'reload schema';

-- EOF 20260925000004
