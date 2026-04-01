-- Migration: Realtime publication aktif (idempotent)
-- Tablolar zaten publication'daysa hata vermez

DO $$
DECLARE
  t text;
  tables text[] := ARRAY['hayvanlar','gorev_log','stok','stok_hareket','tohumlama','dogum','islem_log'];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END;
$$;
