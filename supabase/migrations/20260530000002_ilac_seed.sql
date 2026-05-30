-- 20260530000002_ilac_seed.sql
-- Ders kitabi referans seed — veteriner farmakoloji

BEGIN;

-- Unique constraint: ayni group+class+ingredient tekrari onle
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'uq_drug_classes_combo') THEN
    ALTER TABLE public.drug_classes ADD CONSTRAINT uq_drug_classes_combo
      UNIQUE (group_name, class_name, active_ingredient);
  END IF;
END $$;

-- Mevcut eski group_name/class_name'leri yeni isimlere guncelle
-- (ON CONFLICT oncesi — eski kayitlar yeni isimlere donusmeli)
UPDATE public.drug_classes SET group_name = 'Antimikrobiyaller (Antibiyotikler)', class_name = 'Beta-Laktamlar' WHERE group_name = 'Antibiyotik' AND class_name = 'Beta-Laktam';
UPDATE public.drug_classes SET group_name = 'Antimikrobiyaller (Antibiyotikler)', class_name = 'Makrolidler' WHERE group_name = 'Antibiyotik' AND class_name = 'Makrolid';
UPDATE public.drug_classes SET group_name = 'Antimikrobiyaller (Antibiyotikler)', class_name = 'Florokinolonlar' WHERE group_name = 'Antibiyotik' AND class_name = 'Florokinolon';
UPDATE public.drug_classes SET group_name = 'Antimikrobiyaller (Antibiyotikler)', class_name = 'Tetrasiklinler' WHERE group_name = 'Antibiyotik' AND class_name = 'Tetrasiklin';
UPDATE public.drug_classes SET group_name = 'Antimikrobiyaller (Antibiyotikler)', class_name = 'Aminoglikozidler' WHERE group_name = 'Antibiyotik' AND class_name = 'Aminoglikozid';
UPDATE public.drug_classes SET group_name = 'Antimikrobiyaller (Antibiyotikler)', class_name = 'Sulfonamidler' WHERE group_name = 'Antibiyotik' AND class_name = 'Sülfonamid';
UPDATE public.drug_classes SET group_name = 'Anti-inflamatuar İlaçlar' WHERE group_name = 'NSAID';
UPDATE public.drug_classes SET group_name = 'Anti-inflamatuar İlaçlar', class_name = 'Kortikosteroidler' WHERE group_name = 'Kortikosteroid';
UPDATE public.drug_classes SET group_name = 'Hormonlar ve Üreme İlaçları', class_name = 'Prostaglandinler' WHERE group_name = 'Hormon' AND class_name = 'Prostaglandin';
UPDATE public.drug_classes SET group_name = 'Hormonlar ve Üreme İlaçları' WHERE group_name = 'Hormon' AND class_name = 'Oksitosin';
UPDATE public.drug_classes SET group_name = 'Hormonlar ve Üreme İlaçları', class_name = 'Progestagenler' WHERE group_name = 'Hormon' AND class_name = 'Progestagen';
UPDATE public.drug_classes SET group_name = 'Hormonlar ve Üreme İlaçları', class_name = 'GnRH Agonistleri' WHERE group_name = 'Hormon' AND class_name = 'GnRH';
UPDATE public.drug_classes SET group_name = 'Antiparaziter İlaçlar', class_name = 'Makrosiklik Laktonlar' WHERE group_name = 'Antiparaziter' AND class_name = 'Makrosiklik';
UPDATE public.drug_classes SET group_name = 'Vitaminler ve Mineraller', class_name = 'Suda Eriyen Vitaminler' WHERE group_name = 'Vitamin' AND class_name = 'B Grubu';
UPDATE public.drug_classes SET group_name = 'Vitaminler ve Mineraller', class_name = 'Yağda Eriyen Vitaminler' WHERE group_name = 'Vitamin' AND class_name = 'A,D,E';
UPDATE public.drug_classes SET group_name = 'Vitaminler ve Mineraller', class_name = 'Suda Eriyen Vitaminler' WHERE group_name = 'Vitamin' AND class_name = 'C';
UPDATE public.drug_classes SET group_name = 'Metabolik / Sıvı Tedavi', class_name = 'Kalsiyum Preparatları' WHERE group_name = 'Metabolik' AND class_name = 'Kalsiyum';
UPDATE public.drug_classes SET group_name = 'Metabolik / Sıvı Tedavi' WHERE group_name = 'Metabolik' AND class_name = 'Magnezyum';
UPDATE public.drug_classes SET group_name = 'Metabolik / Sıvı Tedavi', class_name = 'Glukoz / Dekstroz' WHERE group_name = 'Metabolik' AND class_name = 'Glukoz';
UPDATE public.drug_classes SET group_name = 'Metabolik / Sıvı Tedavi', class_name = 'Elektrolitler' WHERE group_name = 'Elektrolit' AND class_name = 'Oral';
UPDATE public.drug_classes SET active_ingredient = 'Oral Rehidrasyon Solüsyonu' WHERE group_name = 'Metabolik / Sıvı Tedavi' AND active_ingredient = 'Elektrolit';
UPDATE public.drug_classes SET group_name = 'Gastrointestinal İlaçlar', class_name = 'Rumen Stimülanları' WHERE group_name = 'Rumen' AND class_name = 'Stimülan';

-- Seed — mevcut verilerle cakisanlar ON CONFLICT ile atlanir

-- 1. Antimikrobiyaller (Antibiyotikler)
INSERT INTO public.drug_classes (group_name, class_name, active_ingredient, kategori_id)
VALUES
  ('Antimikrobiyaller (Antibiyotikler)', 'Beta-Laktamlar', 'Penisilin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
  ('Antimikrobiyaller (Antibiyotikler)', 'Beta-Laktamlar', 'Amoksisilin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
  ('Antimikrobiyaller (Antibiyotikler)', 'Beta-Laktamlar', 'Seftiofur', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
  ('Antimikrobiyaller (Antibiyotikler)', 'Makrolidler', 'Tilmikosin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
  ('Antimikrobiyaller (Antibiyotikler)', 'Makrolidler', 'Tulathromycin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
  ('Antimikrobiyaller (Antibiyotikler)', 'Florokinolonlar', 'Enrofloksasin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
  ('Antimikrobiyaller (Antibiyotikler)', 'Florokinolonlar', 'Marbofloksasin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
  ('Antimikrobiyaller (Antibiyotikler)', 'Tetrasiklinler', 'Oksitetrasiklin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
  ('Antimikrobiyaller (Antibiyotikler)', 'Tetrasiklinler', 'Doksisiklin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
  ('Antimikrobiyaller (Antibiyotikler)', 'Aminoglikozidler', 'Gentamisin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
  ('Antimikrobiyaller (Antibiyotikler)', 'Sulfonamidler', 'Trimetoprim-SMX', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik'))
ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;

-- 2. Anti-inflamatuar Ilaclar
INSERT INTO public.drug_classes (group_name, class_name, active_ingredient, kategori_id)
VALUES
  ('Anti-inflamatuar İlaçlar', 'NSAID', 'Meloksikam', (SELECT id FROM stok_kategorileri WHERE ad='NSAID')),
  ('Anti-inflamatuar İlaçlar', 'NSAID', 'Ketoprofen', (SELECT id FROM stok_kategorileri WHERE ad='NSAID')),
  ('Anti-inflamatuar İlaçlar', 'NSAID', 'Flunixin', (SELECT id FROM stok_kategorileri WHERE ad='NSAID')),
  ('Anti-inflamatuar İlaçlar', 'Kortikosteroidler', 'Deksametazon', (SELECT id FROM stok_kategorileri WHERE ad='Hormon'))
ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;

-- 3. Hormonlar ve Ureme Ilaclari
INSERT INTO public.drug_classes (group_name, class_name, active_ingredient, kategori_id)
VALUES
  ('Hormonlar ve Üreme İlaçları', 'Prostaglandinler', 'Dinoprost', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
  ('Hormonlar ve Üreme İlaçları', 'GnRH Agonistleri', 'Gonadorelin', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
  ('Hormonlar ve Üreme İlaçları', 'Progestagenler', 'Progesteron', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
  ('Hormonlar ve Üreme İlaçları', 'Oksitosin', 'Oksitosin', (SELECT id FROM stok_kategorileri WHERE ad='Hormon'))
ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;

-- 4. Antiparaziter Ilaclar
INSERT INTO public.drug_classes (group_name, class_name, active_ingredient, kategori_id)
VALUES
  ('Antiparaziter İlaçlar', 'Makrosiklik Laktonlar', 'İvermektin', (SELECT id FROM stok_kategorileri WHERE ad='Antiparaziter')),
  ('Antiparaziter İlaçlar', 'Makrosiklik Laktonlar', 'Doramektin', (SELECT id FROM stok_kategorileri WHERE ad='Antiparaziter')),
  ('Antiparaziter İlaçlar', 'Benzimidazoller', 'Albendazol', (SELECT id FROM stok_kategorileri WHERE ad='Antiparaziter'))
ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;

-- 5. Vitaminler ve Mineraller
INSERT INTO public.drug_classes (group_name, class_name, active_ingredient, kategori_id)
VALUES
  ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B1 (Tiamin)', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
  ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B6 (Piridoksin)', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
  ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B12 (Siyanokobalamin)', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
  ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B Kompleks', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
  ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'C Vitamini', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
  ('Vitaminler ve Mineraller', 'Yağda Eriyen Vitaminler', 'E Vitamini', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
  ('Vitaminler ve Mineraller', 'Yağda Eriyen Vitaminler', 'AD3E Kombinasyon', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
  ('Vitaminler ve Mineraller', 'Mineraller / İz Elementler', 'Selenyum', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin'))
ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;

-- 6. Metabolik / Sivi Tedavi
INSERT INTO public.drug_classes (group_name, class_name, active_ingredient, kategori_id)
VALUES
  ('Metabolik / Sıvı Tedavi', 'Kalsiyum Preparatları', 'Kalsiyum Boroglukonat', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
  ('Metabolik / Sıvı Tedavi', 'Magnezyum', 'Magnezyum Sülfat', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
  ('Metabolik / Sıvı Tedavi', 'Glukoz / Dekstroz', 'Glukoz %50', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
  ('Metabolik / Sıvı Tedavi', 'Glukoz / Dekstroz', 'Dekstroz %30', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
  ('Metabolik / Sıvı Tedavi', 'Elektrolitler', 'Oral Rehidrasyon Solüsyonu', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
  ('Metabolik / Sıvı Tedavi', 'Elektrolitler', 'IV Serum (İzotonik NaCl, Ringer Laktat)', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik'))
ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;

-- 7. Gastrointestinal Ilaclar
INSERT INTO public.drug_classes (group_name, class_name, active_ingredient, kategori_id)
VALUES
  ('Gastrointestinal İlaçlar', 'Gastroprotektanlar', 'Sukralfat (Antepsin)', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
  ('Gastrointestinal İlaçlar', 'Rumen Stimülanları', 'Rumen Stimülanı', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
  ('Gastrointestinal İlaçlar', 'Probiyotikler / Maya', 'Saccharomyces (Maya)', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
  ('Gastrointestinal İlaçlar', 'Probiyotikler / Maya', 'Probiyotik Preparatları', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar'))
ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;

-- 8. Topikal / Harici Ilaclar
INSERT INTO public.drug_classes (group_name, class_name, active_ingredient, kategori_id)
VALUES
  ('Topikal / Harici İlaçlar', 'Merhemler', 'İhtiyol (Kara Merhem)', (SELECT id FROM stok_kategorileri WHERE ad='Topikal'))
ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;

-- 9. Anestezik / Sedatif
INSERT INTO public.drug_classes (group_name, class_name, active_ingredient, kategori_id)
VALUES
  ('Anestezik / Sedatif', 'Sedatifler', 'Ksilazin', (SELECT id FROM stok_kategorileri WHERE ad='Anestezik / Sedatif')),
  ('Anestezik / Sedatif', 'Genel Anestezikler', 'Ketamin', (SELECT id FROM stok_kategorileri WHERE ad='Anestezik / Sedatif')),
  ('Anestezik / Sedatif', 'Lokal Anestezikler', 'Lidokain', (SELECT id FROM stok_kategorileri WHERE ad='Anestezik / Sedatif'))
ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;

COMMIT;
