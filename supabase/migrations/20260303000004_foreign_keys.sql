ALTER TABLE public.stok_hareket 
  ADD CONSTRAINT IF NOT EXISTS stok_hareket_stok_id_fkey 
  FOREIGN KEY (stok_id) REFERENCES public.stok(id) ON DELETE CASCADE;

ALTER TABLE public.tohumlama
  ADD CONSTRAINT IF NOT EXISTS tohumlama_hayvan_id_fkey
  FOREIGN KEY (hayvan_id) REFERENCES public.hayvanlar(id) ON DELETE CASCADE;

ALTER TABLE public.dogum
  ADD CONSTRAINT IF NOT EXISTS dogum_anne_id_fkey
  FOREIGN KEY (anne_id) REFERENCES public.hayvanlar(id) ON DELETE CASCADE;

ALTER TABLE public.gorev_log
  ADD CONSTRAINT IF NOT EXISTS gorev_log_hayvan_id_fkey
  FOREIGN KEY (hayvan_id) REFERENCES public.hayvanlar(id) ON DELETE CASCADE;

NOTIFY pgrst, 'reload schema';