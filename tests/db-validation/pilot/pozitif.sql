-- Pilot-pozitif: geçerli, baseline'da olmayan yeni nesne yaratan sentetik migration.
-- Beklenen: db-validate.sh PASS (exit 0).
CREATE TABLE public.val_pilot_test (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    adi text,
    olusturma_zamani timestamptz DEFAULT now()
);

ALTER TABLE public.val_pilot_test ENABLE ROW LEVEL SECURITY;

CREATE POLICY val_pilot_test_select ON public.val_pilot_test
    FOR SELECT
    TO authenticated
    USING (true);
