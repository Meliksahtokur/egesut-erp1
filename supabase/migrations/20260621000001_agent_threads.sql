-- AI Asistan sohbet thread'leri + mesajları
BEGIN;

CREATE TABLE IF NOT EXISTS public.agent_threads (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kullanici_id uuid NOT NULL DEFAULT auth.uid(),
  baslik       text NOT NULL DEFAULT 'Yeni sohbet',
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.agent_messages (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id  uuid NOT NULL REFERENCES public.agent_threads(id) ON DELETE CASCADE,
  rol        text NOT NULL CHECK (rol IN ('user','assistant')),
  icerik     text NOT NULL DEFAULT '',
  metadata   jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS agent_messages_thread_idx ON public.agent_messages(thread_id, created_at);
CREATE INDEX IF NOT EXISTS agent_threads_user_idx ON public.agent_threads(kullanici_id, updated_at DESC);

ALTER TABLE public.agent_threads  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agent_messages ENABLE ROW LEVEL SECURITY;

-- Kullanıcı sadece kendi thread'lerini görür/yönetir
DROP POLICY IF EXISTS agent_threads_owner ON public.agent_threads;
CREATE POLICY agent_threads_owner ON public.agent_threads
  FOR ALL TO authenticated
  USING (kullanici_id = auth.uid()) WITH CHECK (kullanici_id = auth.uid());

DROP POLICY IF EXISTS agent_messages_owner ON public.agent_messages;
CREATE POLICY agent_messages_owner ON public.agent_messages
  FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.agent_threads t WHERE t.id = thread_id AND t.kullanici_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.agent_threads t WHERE t.id = thread_id AND t.kullanici_id = auth.uid()));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.agent_threads  TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.agent_messages TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
