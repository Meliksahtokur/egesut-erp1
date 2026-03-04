ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS padok text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS kupe_no text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS durum text DEFAULT 'Aktif';
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS grup text;
NOTIFY pgrst, 'reload schema';
