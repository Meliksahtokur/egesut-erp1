
ALTER TABLE public.stok_hareket DROP CONSTRAINT IF EXISTS stok_hareket_stok_id_fkey;
ALTER TABLE public.stok_hareket 
  ADD CONSTRAINT stok_hareket_stok_id_fkey 
  FOREIGN KEY (stok_id) REFERENCES public.stok(id) ON DELETE CASCADE;

ALTER TABLE public.tohumlama DROP CONSTRAINT IF EXISTS tohumlama_hayvan_id_fkey;
ALTER TABLE public.tohumlama
  ADD CONSTRAINT tohumlama_hayvan_id_fkey
  FOREIGN KEY (hayvan_id) REFERENCES public.hayvanlar(id) ON DELETE CASCADE;

ALTER TABLE public.dogum DROP CONSTRAINT IF EXISTS dogum_anne_id_fkey;
ALTER TABLE public.dogum
 ADD CONSTRAINT dogum_anne_id_fkey
 FOREIGN KEY (anne_id) REFERENCES public.hayvanlar(id) ON DELETE CASCADE;

ALTER TABLE public.gorev_log DROP CONSTRAINT IF EXISTS gorev_log_hayvan_id_fkey;
ALTER TABLE public.gorev_log
 ADD CONSTRAINT gorev_log_hayvan_id_fkey
 FOREIGN KEY (hayvan_id) REFERENCES public.hayvanlar(id) ON DELETE CASCADE;

NOTIFY pgrst, 'reload schema';
