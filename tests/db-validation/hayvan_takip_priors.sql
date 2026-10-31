-- YALNIZ IZOLE BASELINE: db-validate --priors fixture'i; prod/demo/kabul DB'ye uygulanmaz.
-- Ayna constraint tasimaz; canli hayvanlar_pkey'i REFERENCES hayvanlar(id) icin yeniden kurar.
ALTER TABLE public.hayvanlar ADD CONSTRAINT hayvanlar_pkey PRIMARY KEY (id);
-- C2 tohumu hayvan_takip.hayvan_id'ye 'dbval_<kolon>' yazar (db-validate VALS kuralı); FK için aynı kuralla hayvan.
INSERT INTO public.hayvanlar (id) SELECT format('dbval_%s', 'hayvan_id');
-- Ayna IDENTITY taşımaz; kabul DB ve 20260913000001 tanımı bu; hayvan_takip audit tetikleyicisi id vermez.
ALTER TABLE public.degisim_log ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY;
