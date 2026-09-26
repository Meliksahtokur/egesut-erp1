-- ============================================================================
-- Migration: 20260925000015_sessiz_reconcile_acl_yeniden_beyan
-- Tarih: 2026-09-25 · Cila-onarım F4 onarım turu (K1 review bulgusu; a-db ve
--   b-guvenlik lensleri aynı sapmayı doğruladı)
--
-- Zarf kuralı (cila-onarim-GOREV.md): her yeni migration'da
--   `REVOKE … FROM PUBLIC, anon` VAR. 000009 (sessiz_hayvanlar_reconcile
--   eşik onarımı) bu savunmacı beyanı taşımıyordu — ACL yalnızca CREATE OR
--   REPLACE'in ACL koruma davranışına ve 20260925000002:391-392'de kurulan
--   geçmiş ACL'ye dayanıyordu. Fonksiyon ileride DROP+CREATE ile taze
--   kurulursa PostgreSQL fonksiyon default'u PUBLIC EXECUTE sessizce döner
--   (20260915000001 genel kalkışı o senaryoda yeniden koşmaz).
-- 000009 demo'da UYGULANMIŞTIR; "uygulanmış migration değişmez" kuralı
--   (zarf: 000001..000008 için konmuş, ilkesi genel) gereği dosyası
--   düzenlenmez — kural harfi, serinin ucuna eklenen bu beyan migration'ıyla
--   kapatılır. Taze kurulum senaryosunda da bu dosya 000009'dan SONRA
--   koşacağından default PUBLIC EXECUTE açıkta kalmaz.
-- İçerik: mevcut canlı ACL'nin birebir, idempotent yeniden beyanı —
--   anon/PUBLIC EXECUTE kapalı, authenticated + service_role açık
--   (F4 ön-ölçümü 2026-09-25, demo: anon=f auth=t svc=t; beyan değişiklik
--   yapmaz, kayıt altına alır).
-- Geri alınabilir: beyan DROP yaratmaz; geri almak = bu dosyayı uygulamamak.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

REVOKE ALL ON FUNCTION public.sessiz_hayvanlar_reconcile() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sessiz_hayvanlar_reconcile() TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- EOF 20260925000015_sessiz_reconcile_acl_yeniden_beyan (F4/K1)
