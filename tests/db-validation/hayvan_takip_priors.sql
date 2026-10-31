-- YALNIZ IZOLE BASELINE: db-validate --priors fixture'i; prod/demo/kabul DB'ye uygulanmaz.
-- Ayna constraint tasimaz; canli hayvanlar_pkey'i REFERENCES hayvanlar(id) icin yeniden kurar.
ALTER TABLE public.hayvanlar ADD CONSTRAINT hayvanlar_pkey PRIMARY KEY (id);
