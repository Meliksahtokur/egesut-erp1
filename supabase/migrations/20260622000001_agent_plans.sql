-- AI Asistan Faz 2 — plan saklama (HITL onay arası kalıcılık)
CREATE TABLE IF NOT EXISTS public.agent_plans (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id    uuid REFERENCES public.agent_threads(id) ON DELETE CASCADE,
  kullanici_id uuid NOT NULL DEFAULT auth.uid(),
  durum        text NOT NULL DEFAULT 'pending'
               CHECK (durum IN ('pending','applied','cancelled','failed','expired')),
  adimlar      jsonb NOT NULL,
  onizleme     jsonb,
  sonuc        jsonb,
  created_at   timestamptz NOT NULL DEFAULT now(),
  applied_at   timestamptz
);

CREATE INDEX IF NOT EXISTS idx_agent_plans_thread ON public.agent_plans(thread_id);
CREATE INDEX IF NOT EXISTS idx_agent_plans_durum  ON public.agent_plans(kullanici_id, durum);

ALTER TABLE public.agent_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS agent_plans_select ON public.agent_plans;
CREATE POLICY agent_plans_select ON public.agent_plans
  FOR SELECT USING (kullanici_id = auth.uid());
DROP POLICY IF EXISTS agent_plans_insert ON public.agent_plans;
CREATE POLICY agent_plans_insert ON public.agent_plans
  FOR INSERT WITH CHECK (kullanici_id = auth.uid());
DROP POLICY IF EXISTS agent_plans_update ON public.agent_plans;
CREATE POLICY agent_plans_update ON public.agent_plans
  FOR UPDATE USING (kullanici_id = auth.uid());

-- Bayat onay: 30 dk'dan eski pending planları expired yap (pg_cron)
CREATE OR REPLACE FUNCTION public.agent_plans_prune() RETURNS void AS $$
BEGIN
  UPDATE public.agent_plans
  SET durum = 'expired'
  WHERE durum = 'pending' AND created_at < now() - interval '30 minutes';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('agent-plans-prune')
      WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'agent-plans-prune');
    PERFORM cron.schedule('agent-plans-prune', '*/15 * * * *',
      'SELECT public.agent_plans_prune()');
  END IF;
END $$;
