-- ============================================================================
-- Migration: 20260926000003_ovsync_baslat_gorevsiz_pencere
-- Tarih: 2026-09-26 · p5b-fix K1 (T12/T5) — DB ajanı C
--
-- HATA (T12, reports/2026-09-26-ui-test-p5b.md): "İlk Tohumlama" panel
--   bölümünün tek kaynağı ovsync_baslat_uyarilari (ui.js `if(ovList.length)`).
--   000019'ün gorevsiz kolunda kural-pencere koşulu `kural > bugun` — kural
--   == bugün olan görevsiz hayvan (C5 sözleşmesi: görev kural GÜNÜ doğar)
--   pencerenin tam dışında kalıyor; kural günü sabahında (cron henüz
--   koşmadan) panel bölümü BOŞ görünüyor. Probe [2026-09-26]: tam 1 kayıp
--   satır — kupe 32 (düve; dogum_tarihi 2025-09-05 + 386g = hedef
--   2026-09-26; görevi 24.09'da iptal edildi, demo'da pg_cron yok → görev
--   yeniden doğmuyor).
-- ONARIM (K1, TEK diff — yalnız gorevsiz pencere ucu):
--     AND (SELECT public._ovsync_kural_tarihi(h.id)) >  (SELECT d FROM bugun)
--     AND (SELECT public._ovsync_kural_tarihi(h.id)) >= (SELECT d FROM bugun)
--   Kural penceresi (bugun, bugun+2] iken [bugun, bugun+2] olur: kural günü
--   sabahında görev henüz doğmadıysa hayvan C5 öneri satırıyla panelde
--   düşer (kaynak='ACIK-DISI-ONERI:<id>'). gorevli CTE ve diğer TÜM
--   koşullara DOKUNULMADI.
-- Gövde tabanı = apply-öncesi CANLI demo gövdesi (2026-09-26 çekimi:
--   ~/tmp/p5b-fix/govde/demo/ovsync_baslat_uyarilari().sql) — tek fark yukarıdaki
--   karşılaştırma operatörü.
-- Risk (bilgi, sahibin bilgiline): kural-günü sabahında cron koşmadan önce
--   öneri satırı görünür — C5 sözleşmesinin kendisi ("görev hedef gününde
--   otomatik açılır"); görsel değişim, davranışsal değil.
-- ACL yeniden beyan (Supabase default-privilege tuzağı: REVOKE'a
--   authenticated da dahil): anon/PUBLIC kapalı, authenticated (UI bu rolle
--   çağırır) + service_role açık. anon GRANT YAZILMAZ.
-- Geri alınabilir: canlı gövde CREATE OR REPLACE ile geri yazılır.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION public.ovsync_baslat_uyarilari()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  WITH bugun AS (
    SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date AS d
  ), gorevli AS (
    SELECT g.id AS gorev_id, g.hayvan_id, h.kupe_no, COALESCE(h.kategori, h.grup) AS kategori,
           COALESCE(h.kisir, false) AS kisir, g.hedef_tarih, g.hedef_saat,
           g.hedef_tarih + 10 AS tai_tarihi, g.kaynak,
           CASE WHEN g.kaynak LIKE 'ILK-TOH-DUVE-%' THEN 'duve'
                WHEN g.kaynak LIKE 'ILK-TOH-DOGUM-%' THEN 'dogum'
                WHEN g.kaynak LIKE 'ILK-TOH-ABORT-%' THEN 'abort'
                ELSE 'acik_disi' END AS taban_turu
      FROM public.gorev_log g
      JOIN public.hayvanlar h ON h.id = g.hayvan_id
     WHERE g.gorev_tipi = 'OVSYNC_BASLAT'
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
       AND g.hedef_tarih <= (SELECT d + 2 FROM bugun)
  ), gorevsiz AS (
    -- C5 (cila2): görev kural günü doğduğu için hedef−2 penceresinde görev
    -- henüz YOK — uyarı 2 gün önceden düşsün diye görevsiz uygun açık dişiler
    -- kural tarihinden listelenir. Başlatma kural günü mümkün olur.
    SELECT NULL::uuid AS gorev_id, h.id AS hayvan_id, h.kupe_no, COALESCE(h.kategori, h.grup) AS kategori,
           COALESCE(h.kisir, false) AS kisir,
           (SELECT public._ovsync_kural_tarihi(h.id)) AS hedef_tarih,
           NULL::time AS hedef_saat,
           (SELECT public._ovsync_kural_tarihi(h.id)) + 10 AS tai_tarihi,
           'ACIK-DISI-ONERI:' || h.id AS kaynak,
           CASE WHEN EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id) THEN 'dogum'
                WHEN EXISTS (SELECT 1 FROM public.tohumlama t
                              WHERE t.hayvan_id = h.id AND t.sonuc = 'Abort'
                                AND t.abort_tarihi IS NOT NULL) THEN 'abort'
                WHEN h.dogum_tarihi IS NOT NULL THEN 'duve'
                ELSE 'acik_disi' END AS taban_turu
      FROM public.hayvanlar h
     WHERE h.durum = 'Aktif' AND h.cinsiyet = 'Dişi' AND COALESCE(h.kisir, false) = false
       AND public._acik_disi_ovsync_hedef(h.id) IS NOT NULL
       AND (SELECT public._ovsync_kural_tarihi(h.id)) >= (SELECT d FROM bugun)
       AND (SELECT public._ovsync_kural_tarihi(h.id)) <= (SELECT d + 2 FROM bugun)
       AND NOT EXISTS (SELECT 1 FROM public.gorev_log g2
                        WHERE g2.hayvan_id = h.id AND g2.gorev_tipi = 'OVSYNC_BASLAT'
                          AND COALESCE(g2.tamamlandi, false) = false
                          AND COALESCE(g2.iptal, false) = false)
  )
  SELECT jsonb_build_object(
    'ok', true,
    'uyarilar', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'gorev_id', u.gorev_id,
               'hayvan_id', u.hayvan_id,
               'kupe_no', u.kupe_no,
               'kategori', u.kategori,
               'kisir', u.kisir,
               'hedef_tarih', u.hedef_tarih,
               'hedef_saat', u.hedef_saat,
               'tai_tarihi', u.tai_tarihi,
               'kaynak', u.kaynak,
               'taban_turu', u.taban_turu)
               ORDER BY u.hedef_tarih, u.hayvan_id)
        FROM (SELECT * FROM gorevli UNION ALL SELECT * FROM gorevsiz) u
    ), '[]'::jsonb)
  );
$function$;

REVOKE ALL ON FUNCTION public.ovsync_baslat_uyarilari() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ovsync_baslat_uyarilari() TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- EOF 20260926000003_ovsync_baslat_gorevsiz_pencere (K1/T12-T5)
