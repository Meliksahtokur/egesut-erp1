-- ============================================================================
-- Migration: 20260925000011_ureme_temizlik_revoke
-- Tarih: 2026-09-25 · Cila-onarım K6 (mimar incelemesi C2)
--
-- HATA: 20260925000005, "tek-seferlik DEMO aracı, prod'a uygulanmaz" başlıklı
--   ureme_temizlik_reconcile'a authenticated'a EXECUTE vermişti (000005:185-186).
--   Tek REST çağrısıyla p_dry_run=false toplu iptal; her çağrıda o an kurala
--   uyanları yeniden kapatır. Gövde değişmez; yalnız ACL daraltılır.
-- ONARIM: authenticated'dan REVOKE; service_role açık kalır (koşum psql/MCP
--   service_role bağlamıyla yapılır). Anon/PUBLIC zaten kapalı (000005:
--   REVOKE ... FROM PUBLIC, anon — canlı ölçüm 2026-09-25: pub=f, anon=f).
-- Geri alınabilir: GRANT EXECUTE ... TO authenticated;
--
-- UYGULAMA BİÇİMİ NOTU: ACL değişikliği varlık-guard'lı DO bloğu içinde koşar.
--   Fonksiyon 20260925000005 ürünüdür; bu migration prod sırasında 000005'ten
--   SONRA koşar (plan PROD SIRASI), ancak doğrulama aynası (prod-parite) 000005'i
--   henüz içermeyebilir. Yoksa NOTICE ile atlanır (sessiz başarı yok).
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $do$
BEGIN
  IF pg_catalog.to_regprocedure('public.ureme_temizlik_reconcile(boolean, text[])') IS NOT NULL THEN
    REVOKE EXECUTE ON FUNCTION public.ureme_temizlik_reconcile(boolean, text[]) FROM authenticated;
    GRANT EXECUTE ON FUNCTION public.ureme_temizlik_reconcile(boolean, text[]) TO service_role;
  ELSE
    RAISE NOTICE 'K6: ureme_temizlik_reconcile(boolean,text[]) bu ortamda yok (000005 öncesi sıralama) — ACL değişikliği atlandı';
  END IF;
END
$do$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- EOF 20260925000011_ureme_temizlik_revoke (K6)
