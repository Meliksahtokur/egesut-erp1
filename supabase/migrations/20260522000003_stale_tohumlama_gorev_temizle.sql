-- Migration: stale_tohumlama_gorev_temizle
-- Amac: Eski tohumlama cycle'larına ait TOHUMLAMA_HAZIRLIK görevlerini otomatik iptal et
-- Çalışma: 4 saatlik pg_cron + elle RPC çağrısı

BEGIN;

-- ── Cleanup fonksiyonu ───────────────────────────────────────────────────────
-- Bir hayvana yeni tohumlama girildiğinde önceki cycle'ın TOHUMLAMA_HAZIRLIK
-- görevleri trigger ile anında iptal edilir. Trigger'ı geçmişte kaçıran durumlar
-- (deployment öncesi INSERT'ler) için bu fonksiyon her 4 saatte bir tarama yapar.
--
-- Mantık: hedef_tarih < (hayvanın en son tohumlama tarihi + 20 gün)
-- → en az 21. gün kontrolü olduğundan 20 gün eşiği yeni cycle'a dokunmaz.
CREATE OR REPLACE FUNCTION public.stale_tohumlama_gorev_temizle()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_iptal_sayisi integer;
BEGIN
  UPDATE public.gorev_log
  SET iptal = true
  WHERE tamamlandi = false
    AND iptal = false
    AND gorev_tipi = 'TOHUMLAMA_HAZIRLIK'
    AND hedef_tarih < (
      SELECT MAX(t.tarih) + INTERVAL '20 days'
      FROM public.tohumlama t
      WHERE t.hayvan_id = gorev_log.hayvan_id
    );

  GET DIAGNOSTICS v_iptal_sayisi = ROW_COUNT;
  RETURN jsonb_build_object('iptal_edilen', v_iptal_sayisi, 'zaman', now());
END;
$$;

GRANT EXECUTE ON FUNCTION public.stale_tohumlama_gorev_temizle() TO anon, authenticated;

-- ── pg_cron: 4 saatte bir otomatik çalıştır ──────────────────────────────────
CREATE EXTENSION IF NOT EXISTS pg_cron;

DO $$
BEGIN
  PERFORM cron.unschedule('stale-tohumlama-gorev-temizle');
EXCEPTION WHEN OTHERS THEN NULL;
END;
$$;

SELECT cron.schedule(
  'stale-tohumlama-gorev-temizle',
  '0 */4 * * *',
  $$SELECT public.stale_tohumlama_gorev_temizle()$$
);

-- ── One-time cleanup: mevcut stale görevleri hemen temizle ───────────────────
SELECT public.stale_tohumlama_gorev_temizle();

END;
