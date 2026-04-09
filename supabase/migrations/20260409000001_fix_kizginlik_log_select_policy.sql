-- kizginlik_log: RLS SELECT policy eksikti — pullTables boş dönüyordu
-- allow_all policy bir noktada silinmiş, sadece INSERT kalmıştı
CREATE POLICY IF NOT EXISTS "anon select kizginlik_log"
  ON public.kizginlik_log
  FOR SELECT
  TO anon
  USING (true);
