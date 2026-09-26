-- ============================================================================
-- Migration: 20260925000014_ovsync_seans_uyarilari
-- Tarih: 2026-09-25 · Cila-onarım K8-DB (BUG-PROTOKOL-OVSYNC-AYRIK)
--
-- AMAÇ: başlamış ovsync zincirinin gecikmiş/yaklaşan TEDAVI_SEANS görevleri
--   protokol panelinde ve rozette görünmüyordu (mevcut iki kaynak
--   protokol_eksik_tara + ovsync_baslat_uyarilari yalnız zincir BAŞLATICISI
--   OVSYNC_BASLAT'ı görüyordu). Bu RPC başlamış zincirin seanslarını listeler.
--
-- SÖZLEŞME SAHİBİ: P-UI plan-ui.md Task 7 (ad: ovsync_seans_uyarilari —
--   plan-db Task 6'daki ovsync_zincir_uyarilari adı/kapsamı P-UI lehine
--   hizalandı; karar kırıntısı 2026-09-25). Kolon seti plan-ui.md ile
--   birebir: gorev_id, hayvan_id, kupe_no, grup, case_id, hedef_tarih,
--   hedef_saat, durum, gun_no, toplam_gun, seans_adi.
--
-- MANTIK: gorev_tipi='TEDAVI_SEANS' + açık (tamamlandi=false, iptal=false)
--   → seans_admin_id → treatment_day_uygulamalar → treatment_days →
--   cases (status='active') → hayvanlar. Filtre: c.protocol_family IS NOT
--   NULL (K4'ün damgası — yalnız başlamış ovsync zincirleri; Metrit vb.
--   Üreme vakaları DIŞ) VE hedef_tarih <= bugün+7 (geçmiş sınırsız —
--   gecikmişler; gelecek 7 güne kadar — yaklaşanlar).
--   durum: hedef_tarih+hedef_saat (NULL sahne 08:00) Istanbul yerel saati
--   ile karşılaştırılır → 'gecikmis' | 'yaklasan'.
-- KAYNAK: STABLE — salt-okuma. search_path tırnaksız kilitli.
-- ACL: PUBLIC/anon kapalı; authenticated + service_role açık
--   (ovsync_baslat_uyarilari deseni).
-- Geri alınabilir: DROP FUNCTION public.ovsync_seans_uyarilari();
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION public.ovsync_seans_uyarilari()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
  SELECT jsonb_build_object(
    'ok', true,
    'uyarilar', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
               'gorev_id', g.id,
               'hayvan_id', g.hayvan_id,
               'kupe_no', h.kupe_no,
               'grup', h.grup,
               'case_id', c.id,
               'hedef_tarih', g.hedef_tarih,
               'hedef_saat', g.hedef_saat,
               'durum', CASE WHEN (g.hedef_tarih::timestamp
                                   + COALESCE(g.hedef_saat, '08:00'::time)::interval)
                                  <= (now() AT TIME ZONE 'Europe/Istanbul')
                          THEN 'gecikmis' ELSE 'yaklasan' END,
               'gun_no', td.day_no,
               'toplam_gun', (SELECT count(*) FROM public.treatment_days x
                               WHERE x.case_id = c.id),
               'seans_adi', NULLIF(concat_ws(' ',
                     (SELECT s.urun_adi FROM public.stok s WHERE s.id = tua.stok_id),
                     NULLIF(tua.dose::text, ''), NULLIF(tua.unit, ''),
                     NULLIF(tua.route, '')), ''))
               ORDER BY g.hedef_tarih, g.hedef_saat, g.id)
        FROM public.gorev_log g
        JOIN public.treatment_day_uygulamalar tua ON tua.id = g.seans_admin_id
        JOIN public.treatment_days td ON td.id = tua.treatment_day_id
        JOIN public.cases c ON c.id = td.case_id AND c.status = 'active'
        JOIN public.hayvanlar h ON h.id = g.hayvan_id
       WHERE g.gorev_tipi = 'TEDAVI_SEANS'
         AND COALESCE(g.tamamlandi, false) = false
         AND COALESCE(g.iptal, false) = false
         AND c.protocol_family IS NOT NULL
         AND g.hedef_tarih <= ((now() AT TIME ZONE 'Europe/Istanbul')::date + 7)
    ), '[]'::jsonb)
  );
$fn$;

COMMENT ON FUNCTION public.ovsync_seans_uyarilari() IS
  'K8: başlamış ovsync zincirinin (aktif vaka + protocol_family damgalı) açık TEDAVI_SEANS görevleri — gecikmiş (sınırsız geçmiş) + yaklaşan (≤7 gün). Panel/rozet/bildirim ortak kaynağı. Salt-okuma.';

REVOKE ALL ON FUNCTION public.ovsync_seans_uyarilari() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ovsync_seans_uyarilari() TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- EOF 20260925000014_ovsync_seans_uyarilari (K8-DB)
