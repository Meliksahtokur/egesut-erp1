-- ──────────────────────────────────────────────────────────────
-- 20260909100000_dozaj_std_dose_seed.sql
-- Tedavi dozajlama helperi — F1 (spec: .claude/plans/2026-09-09-tedavi-doz-gorev-design.md)
--
-- 1) drug_products: std_dose + std_dose_unit kolonları
--    Birim tipleri: 'ml/kg' (hacim-ağırlık) | 'mg/kg' (etken; concentration ile
--    ml'e çevrilir) | 'ml/hayvan' (sabit doz — hormonlar/aşılar).
-- 2) drug_products seed: web araştırması 2026-09-09 (kaynak URL'li tablo spec §5.1).
--    mg/kg ürünlerinde concentration + concentration_unit de set edilir
--    (canlıda alan tamamen boştu). Bozuk kayıt Gastren Duo 600/'600' → NULL.
-- 3) vaccines seed: prospektüsle doğrulanmış doz/rota düzeltmeleri + marka/etken
--    doldurma (spec §5.2). Piogen ve Coglavax dozları bilinçli DOKUNULMADI
--    (otovaksin; ergin 4 ml mevcut değeri korundu — not spec §5.3-5.4).
-- Global kataloglar: farm_id ALINMAZ (kontrat invariant).
-- ──────────────────────────────────────────────────────────────

ALTER TABLE public.drug_products
  ADD COLUMN IF NOT EXISTS std_dose numeric,
  ADD COLUMN IF NOT EXISTS std_dose_unit text;

ALTER TABLE public.drug_products
  DROP CONSTRAINT IF EXISTS drug_products_std_dose_unit_check;

ALTER TABLE public.drug_products
  ADD CONSTRAINT drug_products_std_dose_unit_check
  CHECK (std_dose_unit IS NULL OR std_dose_unit IN ('ml/kg', 'mg/kg', 'ml/hayvan'));

COMMENT ON COLUMN public.drug_products.std_dose      IS 'Sığırda standart doz değeri — birim std_dose_unit';
COMMENT ON COLUMN public.drug_products.std_dose_unit IS 'ml/kg | mg/kg (concentration ile ml''e çevrilir) | ml/hayvan (sabit)';

-- ── mg/kg ürünleri (doz etken-bazlı; ml = doz ÷ concentration) ──
UPDATE public.drug_products SET std_dose = 3,    std_dose_unit = 'mg/kg', concentration = 100, concentration_unit = 'mg/ml' WHERE lower(btrim(brand_name)) = 'ketojezik';
UPDATE public.drug_products SET std_dose = 2,    std_dose_unit = 'mg/kg', concentration = 50,  concentration_unit = 'mg/ml' WHERE lower(btrim(brand_name)) = 'fulimed';
UPDATE public.drug_products SET std_dose = 2,    std_dose_unit = 'mg/kg', concentration = 50,  concentration_unit = 'mg/ml' WHERE lower(btrim(brand_name)) = 'flunixin (alke)';
UPDATE public.drug_products SET std_dose = 2,    std_dose_unit = 'mg/kg', concentration = 50,  concentration_unit = 'mg/ml' WHERE lower(btrim(brand_name)) = 'gentavilin';
UPDATE public.drug_products SET std_dose = 4,    std_dose_unit = 'mg/kg', concentration = 100, concentration_unit = 'mg/ml' WHERE lower(btrim(brand_name)) = 'pigenta (pifarma)';
UPDATE public.drug_products SET std_dose = 2.5,  std_dose_unit = 'mg/kg', concentration = 100, concentration_unit = 'mg/ml' WHERE lower(btrim(brand_name)) = 'enrolen';
UPDATE public.drug_products SET std_dose = 20,   std_dose_unit = 'mg/kg', concentration = 300, concentration_unit = 'mg/ml' WHERE lower(btrim(brand_name)) = 'florkem';
UPDATE public.drug_products SET std_dose = 20,   std_dose_unit = 'mg/kg', concentration = 300, concentration_unit = 'mg/ml' WHERE lower(btrim(brand_name)) = 'florkem (ceva)';
UPDATE public.drug_products SET std_dose = 2,    std_dose_unit = 'mg/kg', concentration = 100, concentration_unit = 'mg/ml' WHERE lower(btrim(brand_name)) = 'marbox';
UPDATE public.drug_products SET std_dose = 1,    std_dose_unit = 'mg/kg', concentration = 50,  concentration_unit = 'mg/ml' WHERE lower(btrim(brand_name)) = 'sefanel';
UPDATE public.drug_products SET std_dose = 10,   std_dose_unit = 'mg/kg', concentration = 300, concentration_unit = 'mg/ml' WHERE lower(btrim(brand_name)) = 'makrovil';
UPDATE public.drug_products SET std_dose = 0.5,  std_dose_unit = 'mg/kg', concentration = 5,   concentration_unit = 'mg/ml' WHERE lower(btrim(brand_name)) = 'meloksikam ( bavet )';
UPDATE public.drug_products SET std_dose = 8.75, std_dose_unit = 'mg/kg', concentration = 175, concentration_unit = 'mg/ml' WHERE lower(btrim(brand_name)) = 'klavil (vilsan)';
UPDATE public.drug_products SET std_dose = 0.03, std_dose_unit = 'mg/kg' WHERE lower(btrim(brand_name)) = 'vetakort / kortikosteroid';

-- ── ml/kg ürünleri (doz direkt hacim-ağırlık) ──
UPDATE public.drug_products SET std_dose = 0.2,  std_dose_unit = 'ml/kg' WHERE lower(btrim(brand_name)) = 'halocur (msd)';
UPDATE public.drug_products SET std_dose = 0.02, std_dose_unit = 'ml/kg' WHERE lower(btrim(brand_name)) = 'ademin ( ceva )';
UPDATE public.drug_products SET std_dose = 0.05, std_dose_unit = 'ml/kg' WHERE lower(btrim(brand_name)) = 'carofertin-e ( alivira )';
UPDATE public.drug_products SET std_dose = 0.15, std_dose_unit = 'ml/kg' WHERE lower(btrim(brand_name)) = 'k vitamin (alke)';

-- ── ml/hayvan ürünleri (sabit doz) ──
UPDATE public.drug_products SET std_dose = 2,   std_dose_unit = 'ml/hayvan' WHERE lower(btrim(brand_name)) = 'oksitosin yerli';
UPDATE public.drug_products SET std_dose = 2,   std_dose_unit = 'ml/hayvan' WHERE lower(btrim(brand_name)) = 'dalmazin ( fatro )';
UPDATE public.drug_products SET std_dose = 2,   std_dose_unit = 'ml/hayvan' WHERE lower(btrim(brand_name)) = 'ovarelin (ceva)';
UPDATE public.drug_products SET std_dose = 2,   std_dose_unit = 'ml/hayvan' WHERE lower(btrim(brand_name)) = 'pgs (alke)';
UPDATE public.drug_products SET std_dose = 2.5, std_dose_unit = 'ml/hayvan' WHERE lower(btrim(brand_name)) = 'buserin (alke)';
UPDATE public.drug_products SET std_dose = 100, std_dose_unit = 'ml/hayvan' WHERE lower(btrim(brand_name)) = 'kalsiyum ( vilsan )';
UPDATE public.drug_products SET std_dose = 250, std_dose_unit = 'ml/hayvan' WHERE lower(btrim(brand_name)) = 'calcio ph ( fatro )';
UPDATE public.drug_products SET std_dose = 15,  std_dose_unit = 'ml/hayvan' WHERE lower(btrim(brand_name)) = 'teknovet - b12 (fosforlu)';

-- ── Temizlik + bilinçli boş bırakılanlar (hesap dışı; spec §5.3) ──
UPDATE public.drug_products SET concentration = NULL, concentration_unit = NULL WHERE lower(btrim(brand_name)) = 'gastren duo (humanis)';
-- Yeldif, Vitamino, Antepsin, Kara merhem, Devamisin, Tatrasiklin (ceva): std_dose GİRİLMEDİ.

-- ── Aşı kartları: prospektüs doğrulamalı doz/rota + marka/etken doldurma ──
UPDATE public.vaccines SET dose = 1,   unit = 'ml', route = 'SC', marka = 'Vetal',        etken_madde = 'B. anthracis 34F2 canlı spor (Sterne); buzağı 0.5 ml' WHERE name = 'Şarbon Aşısı';
UPDATE public.vaccines SET dose = 2,   unit = 'ml', route = 'IM', marka = 'MSD',          etken_madde = 'İnaktif BVD; 2 doz 4 hafta ara + yıllık rapel'        WHERE name = 'BVD Aşısı';
UPDATE public.vaccines SET dose = 2,   unit = 'ml', route = 'IM', marka = 'MSD',          etken_madde = 'İnaktif/canlı marker BHV-1; 2 doz + yıllık'           WHERE name = 'IBR Aşısı';
UPDATE public.vaccines SET dose = 2,   unit = 'ml', route = 'SC', marka = 'Bioveta',      etken_madde = 'İnaktif Leptospira 6 serovar (BioBos L6); 2 doz'      WHERE name = 'Leptospirosis Aşısı';
UPDATE public.vaccines SET dose = 5,   unit = 'ml', route = 'SC', marka = 'MSD',          etken_madde = 'Bovipast RSP: BRSV+PI3+Mannheimia+Pasteurella; 2 doz' WHERE name = 'BRSV Aşısı';
UPDATE public.vaccines SET dose = 2,   unit = 'ml', route = 'SC', marka = 'Zoetis',       etken_madde = 'UltraChoice 8: 8''li klostridial; 2 doz + yıllık'     WHERE name = 'Clostridium Aşısı';
UPDATE public.vaccines SET marka = 'MSD', etken_madde = 'Rotavec Corona: rota+korona+E.coli K99/F41; GEBE ANNEYE, buzağılamadan 12-3 hafta önce' WHERE name = 'Rotavirus Aşısı';
UPDATE public.vaccines SET marka = 'MSD', etken_madde = 'Rotavec Corona kombine; GEBE ANNEYE (kolostrumla buzağıya geçer)'                     WHERE name = 'E. coli Aşısı';
UPDATE public.vaccines SET marka = 'MSD', etken_madde = 'Rotavec Corona kombine; GEBE ANNEYE (kolostrumla buzağıya geçer)'                     WHERE name = 'Coronavirus Aşısı';
UPDATE public.vaccines SET marka = 'Microsules', etken_madde = 'BRD kompleksi: IBR+BHV-5+BVD+PI3+BRSV+Pasteurella+Histophilus; 2 doz 28-30 gün ara' WHERE name = 'Vac-Sules Feedlot';
-- Piogen Aşısı (otovaksin — sabit doz yok) ve Coglavax (ergin 4 ml korundu; buzağı 2 ml spec notunda): doz DEĞİŞMEDİ.
