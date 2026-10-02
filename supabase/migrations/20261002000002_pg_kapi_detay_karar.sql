-- ============================================================================
-- 20261002000002_pg_kapi_detay_karar (OVSYNC-SONRASI-BORC kalem 5 / TB-5, SQL ayağı)
--
-- SORUN: birleşik PG kapısı `PG_KAPI:TAKIP_ACIK:{pg_kapi:{…}, takip_acik:{…}}` RAISE
-- ettiğinde (hizli_uygulama / seans_tamamla / tohumlama_bos_ve_devam / bulk_ilac
-- satırı) hata KODU önekinde `TAKIP_ACIK` yazar; sunucunun PG kapı KARARI
-- (REQUIRE_ACK_PENDING | BLOCK_PREGNANT | BLOCK_CATALOG_UNRESOLVED) yükte YOKTU
-- (`pg_kapi` = `_pg_kapi_detay` çıktısı `karar` anahtarı taşımıyordu). UI bu yüzden
-- "Son tohumlama sonucu <sonuc>" metnine düşüyordu (ui-fix1 K3).
--
-- DÜZELTME: `_pg_kapi_detay` çıktısına makine-okunur `karar` anahtarı EKLENİR
-- (`p_kapi->'karar'`, değer yoksa JSON null — "anahtarlar her zaman vardır"
-- sözleşmesi korunur). YALNIZ EKLEME: mevcut 9 anahtar, imza, dönüş tipi, IMMUTABLE,
-- SECURITY DEFINER, search_path ve ACL birebir canlıdaki gibi. Yeni iş davranışı
-- YOK: `karar`, `_pg_kapi`'nın ZATEN ürettiği değerdir (20260923000003:S-4 _pg_kapi);
-- tüm RAISE noktalarında kapı yalnız şu üç değerde bloklar, dolayısıyla birleşik
-- yükte `pg_kapi.karar` her zaman bu kümeden gelir:
--   REQUIRE_ACK_PENDING | BLOCK_PREGNANT | BLOCK_CATALOG_UNRESOLVED
-- (tek-başına `PG_KAPI:<karar>:<detay>` RAISE'inde karar zaten önekte; detayda da
--  artık aynı değer tekrar eder. bulk_ilac pg_blocked / pg_requires_ack satırlarında
--  `kod` ile aynı değerdir.)
--
-- CANLI DOĞRULAMA (2026-10-02, [OBSERVED]): demo (pg_get_functiondef) ve prod (Mgmt API,
--   SELECT) gövde md5'i = ac157e9cf078ffd6d22bad3e1fc90565 (özdeş); proacl =
--   {postgres=X/postgres,service_role=X/postgres}; prosecdef=t; provolatile=i;
--   proconfig={"search_path=public, pg_temp"}.
--
-- ROLLBACK: önceki gövde `20260923000004_ovsync_pg_uygulama_kapisi.sql:60-77`
--   (9 anahtarlı `_pg_kapi_detay`); geri almak için o CREATE OR REPLACE bloğu aynen
--   yeniden uygulanır. `karar` anahtarını okuyan tek istemci js/ui.js
--   `_takipAcikAc` (`_pgk.karar || kod-önek yedeği`) — anahtar yokken yedek yola
--   düşer (N-1 uyumlu), geri alma güvenlidir.
--
-- ACL: CREATE OR REPLACE mevcut ACL'yi korur; REVOKE satırı idempotent olarak
--   şablon gereği tekrarlanır (PUBLIC, anon, authenticated — Supabase default-privilege
--   tuzağı: erteleme-turu 2026-09-25 dersi). anon GRANT YAZILMAZ.
-- ============================================================================

CREATE OR REPLACE FUNCTION public._pg_kapi_detay(p_kapi jsonb, p_hayvan_id text, p_kupe_no text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
  SELECT jsonb_build_object(
    'karar',            p_kapi->'karar',
    'hayvan_id',        COALESCE(p_kapi->'hayvan_id', to_jsonb(p_hayvan_id)),
    'kupe_no',          COALESCE(p_kapi->'kupe_no', to_jsonb(p_kupe_no)),
    'tohumlama_id',     p_kapi->'tohumlama_id',
    'tohumlama_tarihi', p_kapi->'tohumlama_tarihi',
    'tohumlama_sonuc',  p_kapi->'tohumlama_sonuc',
    'gun',              p_kapi->'gun',
    'sperma',           p_kapi->'sperma',
    'deneme_no',        p_kapi->'deneme_no',
    'urun_durumu',      p_kapi->'urun_durumu'
  );
$fn$;

REVOKE ALL ON FUNCTION public._pg_kapi_detay(jsonb, text, text) FROM PUBLIC, anon, authenticated;
