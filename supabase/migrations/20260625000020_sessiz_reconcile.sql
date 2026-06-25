-- Migration: sessiz hayvan tek-otorite reconcile + wrapper + günlük cron
-- Tarih: 2026-06-25
-- Spec §3, §5, §6. Kararlı kimlik kaynak='SESSIZ-<id>', 30g cooldown (yalnız kullanıcı tamamlaması).

CREATE OR REPLACE FUNCTION public.sessiz_hayvanlar_reconcile()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_uretilen  integer := 0;
  v_kapatilan integer := 0;
  v_rec       record;
BEGIN
  -- 1) ÜRET: eligible + açık SESSIZ görevi yok + son 30 günde kullanıcı-tamamlaması yok
  FOR v_rec IN
    SELECT e.id, e.kupe_no, e.sessiz_gun
    FROM public.v_eligible e
    WHERE e.sessiz_gun >= 55
      AND NOT EXISTS (
        SELECT 1 FROM public.gorev_log g
        WHERE g.hayvan_id = e.id
          AND g.kaynak = 'SESSIZ-' || e.id
          AND g.tamamlandi = false AND g.iptal = false
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.gorev_log g
        WHERE g.hayvan_id = e.id
          AND g.kaynak = 'SESSIZ-' || e.id
          AND g.tamamlandi = true
          AND g.tamamlanma_tarihi >= (CURRENT_DATE - 30)
      )
  LOOP
    INSERT INTO public.gorev_log
      (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, iptal, kaynak)
    VALUES (
      gen_random_uuid(), v_rec.id, 'VETERINER_KONTROL',
      format('Sessiz hayvan: %s gündür üreme aktivitesi yok (%s)', v_rec.sessiz_gun, v_rec.kupe_no),
      CURRENT_DATE, false, false, 'SESSIZ-' || v_rec.id
    );
    v_uretilen := v_uretilen + 1;
  END LOOP;

  -- 2) KAPAT: açık SESSIZ görevi var ama artık eligible değil (auto-close, cooldown SAYMAZ)
  UPDATE public.gorev_log g
  SET iptal = true, kapatan_ref = 'sessiz-noteligible'
  WHERE g.gorev_tipi = 'VETERINER_KONTROL'
    AND g.kaynak LIKE 'SESSIZ-%'
    AND g.tamamlandi = false AND g.iptal = false
    AND NOT EXISTS (
      SELECT 1 FROM public.v_eligible e
      WHERE e.id = g.hayvan_id AND e.sessiz_gun >= 55
    );
  GET DIAGNOSTICS v_kapatilan = ROW_COUNT;

  RETURN jsonb_build_object('uretilen', v_uretilen, 'kapatilan', v_kapatilan, 'zaman', now());
END;
$function$;

-- Eski jeneratör → ince wrapper (kalıntı çağıranlar güvenli; tek otorite reconcile)
CREATE OR REPLACE FUNCTION public.sessiz_hayvanlar_gorev_olustur()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE v_res jsonb;
BEGIN
  v_res := public.sessiz_hayvanlar_reconcile();
  RETURN COALESCE((v_res->>'uretilen')::int, 0);
END;
$function$;

-- Günlük cron (idempotent kurulum)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'sessiz-reconcile-daily') THEN
    PERFORM cron.unschedule('sessiz-reconcile-daily');
  END IF;
END $$;
SELECT cron.schedule('sessiz-reconcile-daily', '0 5 * * *', 'SELECT public.sessiz_hayvanlar_reconcile()');