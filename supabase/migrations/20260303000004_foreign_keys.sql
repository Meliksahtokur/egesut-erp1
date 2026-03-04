DO $$ BEGIN
  ALTER TABLE public.stok_hareket 
    ADD CONSTRAINT stok_hareket_stok_id_fkey 
    FOREIGN KEY (stok_id) REFERENCES public.stok(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE public.tohumlama
    ADD CONSTRAINT tohumlama_hayvan_id_fkey
    FOREIGN KEY (hayvan_id) REFERENCES public.hayvanlar(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE public.dogum
    ADD CONSTRAINT dogum_anne_id_fkey
    FOREIGN KEY (anne_id) REFERENCES public.hayvanlar(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE public.gorev_log
    ADD CONSTRAINT gorev_log_hayvan_id_fkey
    FOREIGN KEY (hayvan_id) REFERENCES public.hayvanlar(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

NOTIFY pgrst, 'reload schema';