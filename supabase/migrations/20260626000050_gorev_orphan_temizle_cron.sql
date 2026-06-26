-- Migration: gorev_orphan_temizle — trigger kaçağı güvenlik ağı + bildirim + günlük cron
-- Tarih: 2026-06-26 — Spec §2 Faz 3.
CREATE OR REPLACE FUNCTION public.gorev_orphan_temizle()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $function$
DECLARE v_temizlenen int;
BEGIN
  UPDATE public.gorev_log g
     SET iptal = true, kapatan_ref = 'orphan-temizle'
   WHERE g.id IN (SELECT id FROM public.v_orphan_gorev);
  GET DIAGNOSTICS v_temizlenen = ROW_COUNT;

  -- Bildirim: kaçak bulundu ise iz bırak (trigger eksik bir şeyi kaçırdı demektir)
  IF v_temizlenen > 0 THEN
    INSERT INTO public.bildirim_log (tip, mesaj)
    VALUES ('ORPHAN_GOREV',
            format('%s orphan görev temizlendi (trigger kaçağı?)', v_temizlenen));
  END IF;

  RETURN jsonb_build_object('temizlenen', v_temizlenen, 'zaman', now());
END;
$function$;

-- Günlük cron (idempotent)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname='gorev-orphan-temizle-daily') THEN
    PERFORM cron.unschedule('gorev-orphan-temizle-daily');
  END IF;
END $$;
SELECT cron.schedule('gorev-orphan-temizle-daily', '15 5 * * *', 'SELECT public.gorev_orphan_temizle()');