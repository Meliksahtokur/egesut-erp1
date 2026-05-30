-- 20260530000001_ilac_kategori_fix.sql
-- Ilac siniflandirma refactor Faz 1: kategori duzeltmeleri + drug_classes FK

BEGIN;

-- 1. Kategori Tutarsizliklari

-- "Diger Ilaclar" → "Diger Ilac" rename
UPDATE public.stok_kategorileri SET ad = 'Diğer İlaç' WHERE ad = 'Diğer İlaçlar';

-- Stok tablosundaki tutarsiz degerleri duzelt
UPDATE public.stok SET kategori = 'Diğer İlaç' WHERE kategori = 'Diger Ilac';

-- "Mide Koruyucular" → sil (GI Ilaclar ile degistirilecek)
-- Once bagli stok varsa GI Ilaclar'a tasi
UPDATE public.stok SET kategori = 'GI İlaçlar' WHERE kategori = 'Mide Koruyucular';
DELETE FROM public.stok_kategorileri WHERE ad = 'Mide Koruyucular';

-- 2. Yeni Kategoriler Ekle

INSERT INTO public.stok_kategorileri (ad, sira, tip) VALUES
  ('Metabolik', 14, 'ilac'),
  ('GI İlaçlar', 15, 'ilac'),
  ('Topikal', 16, 'ilac'),
  ('Anestezik / Sedatif', 17, 'ilac')
ON CONFLICT DO NOTHING;

-- 3. drug_classes: drug_id → kategori_id FK

-- Yeni kolon ekle
ALTER TABLE public.drug_classes ADD COLUMN IF NOT EXISTS kategori_id UUID REFERENCES public.stok_kategorileri(id);

-- Backfill: group_name → stok_kategorileri eslestirmesi
UPDATE public.drug_classes dc SET kategori_id = sk.id
FROM public.stok_kategorileri sk
WHERE sk.ad = CASE dc.group_name
  WHEN 'Antibiyotik' THEN 'Antibiyotik'
  WHEN 'NSAID' THEN 'NSAID'
  WHEN 'Hormon' THEN 'Hormon'
  WHEN 'Vitamin' THEN 'Vitamin'
  WHEN 'Antiparaziter' THEN 'Antiparaziter'
  WHEN 'Kortikosteroid' THEN 'Hormon'
  WHEN 'Metabolik' THEN 'Metabolik'
  WHEN 'Rumen' THEN 'GI İlaçlar'
  WHEN 'Elektrolit' THEN 'Metabolik'
  ELSE 'Diğer İlaç'
END;

-- Eski drug_id kolonunu kaldir
ALTER TABLE public.drug_classes DROP COLUMN IF EXISTS drug_id;

COMMIT;
