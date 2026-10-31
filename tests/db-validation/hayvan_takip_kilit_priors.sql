-- YALNIZ IZOLE BASELINE: 20261031200006 db-validate fixture'i, 200005'ten sonra verilir; prod/demo/kabul DB'ye uygulanmaz.
-- 200006 gövdeleri INSERT INTO hayvan_takip taşır, C2 bu tabloyu tohumlar. Tohum sebep_kodu'na CHECK'teki ilk literali ('DIGER') yazar,
-- yalnız zorunlu kolonları doldurur; aciklama NULL kalınca hayvan_takip_diger_aciklama_ck düşer. Migration şemaya dokunmaz.
ALTER TABLE public.hayvan_takip ALTER COLUMN aciklama SET DEFAULT 'dbval_aciklama';
