ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS padok text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS kupe_no text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS durum text DEFAULT 'Aktif';
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS grup text;
ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS iptal boolean DEFAULT false;
ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS padok_hedef text;
ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS hekim_id text;
ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS miktar numeric;
NOTIFY pgrst, 'reload schema';