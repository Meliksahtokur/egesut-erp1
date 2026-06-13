-- BUG-059 ROOT CAUSE: treatment_day_uygulamalar RLS policy eksikti
--
-- Sorun: Tablo RLS ENABLED ama HIÇ policy yoktu (kardeş tablolar treatment_days/
--        drug_administrations 'FOR ALL USING(true)' policy'sine sahip, bu tablo
--        unutulmuş). PostgreSQL'de RLS açık + policy yok = anon role'e deny-all.
--        add_treatment_day_with_sessions (SECURITY DEFINER) seansları INSERT
--        edebiliyordu ama frontend anon SELECT ile geri OKUYAMIYORDU →
--        pullTables boş → IndexedDB boş → modal/görev hiç seans göstermiyordu.
--
-- Kanıt: RLS bypass ile satir_sayisi=13, anon SELECT=0, policy_sayisi=0.
-- Çözüm: Kardeş tablolarla aynı permissive policy.

ALTER TABLE public.treatment_day_uygulamalar ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS treatment_day_uygulamalar_all ON public.treatment_day_uygulamalar;
CREATE POLICY treatment_day_uygulamalar_all ON public.treatment_day_uygulamalar FOR ALL USING (true);
