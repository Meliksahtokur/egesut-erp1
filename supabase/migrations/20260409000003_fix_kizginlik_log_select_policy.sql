-- kizginlik_log: RLS SELECT policy eksikti — pullTables boş dönüyordu
-- allow_all policy bir noktada silinmiş, sadece INSERT kalmıştı
DO $$ BEGIN
  CREATE POLICY "anon select kizginlik_log"
    ON public.kizginlik_log
    FOR SELECT
    TO anon
    USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
