-- Sohbet auto-prune: 90 günden eski VEYA kullanıcı başına 200'den fazla thread
BEGIN;

CREATE OR REPLACE FUNCTION public.agent_threads_prune()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- 90 günden eski
  DELETE FROM public.agent_threads WHERE updated_at < now() - interval '90 days';
  -- Kullanıcı başına 200 üstü (en eskiler)
  DELETE FROM public.agent_threads t
  USING (
    SELECT id, row_number() OVER (PARTITION BY kullanici_id ORDER BY updated_at DESC) AS rn
    FROM public.agent_threads
  ) ranked
  WHERE t.id = ranked.id AND ranked.rn > 200;
END $$;

-- pg_cron job (günlük 03:00)
SELECT cron.schedule('agent-threads-prune', '0 3 * * *', 'SELECT public.agent_threads_prune()')
WHERE NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'agent-threads-prune');

COMMIT;
