ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS devlet_kupe text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS cinsiyet text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS anne_id text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS baba_bilgi text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS canli_agirlik numeric;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS dogum_kg numeric;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS boy numeric;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS renk text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS ayirici_ozellik text;

ALTER TABLE public.stok ADD COLUMN IF NOT EXISTS kategori text;
ALTER TABLE public.stok ADD COLUMN IF NOT EXISTS esik numeric DEFAULT 0;

ALTER TABLE public.dogum ADD COLUMN IF NOT EXISTS dogum_kg numeric;
ALTER TABLE public.dogum ADD COLUMN IF NOT EXISTS baba_bilgi text;

ALTER TABLE public.hastalik_log DROP CONSTRAINT IF EXISTS hastalik_log_hayvan_id_fkey;

ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS iptal boolean DEFAULT false;
ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS padok_hedef text;

NOTIFY pgrst, 'reload schema';