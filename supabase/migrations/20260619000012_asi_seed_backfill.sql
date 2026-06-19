-- ─────────────────────────────────────────────────────────────
-- Aşı Faz 1 — seed/backfill. İsim üzerinden eşleşir, idempotent.
-- ─────────────────────────────────────────────────────────────
-- 1) Aşı hastalıkları (yoksa ekle)
INSERT INTO public.diseases (name, category)
SELECT x.name, 'Aşı ile Önlenebilir'
FROM (VALUES
  ('Enterotoksemi'),('Kara Hastalık'),('Yanıkara'),('Tetanoz'),
  ('BVD'),('IBR'),('BRSV'),('PI3'),('Şarbon'),('E. coli (K99)'),
  ('Rotavirus'),('Coronavirus'),('Leptospirosis'),('Piogen'),
  ('Pasteurella'),('Mannheimia')
) AS x(name)
WHERE NOT EXISTS (SELECT 1 FROM public.diseases d WHERE d.name = x.name);

-- 2) Marka backfill
UPDATE public.vaccines SET marka = 'Ceva'       WHERE name = 'Coglavax'          AND marka IS NULL;
UPDATE public.vaccines SET marka = 'Microsules' WHERE name = 'Vac-Sules Feedlot' AND marka IS NULL;

-- 3) protokol_tipi backfill: hepsi tek_doz, Coglavax/Vac-Sules primer_seri
UPDATE public.vaccines SET protokol_tipi = 'tek_doz' WHERE protokol_tipi IS NULL;
UPDATE public.vaccines SET protokol_tipi = 'primer_seri' WHERE name IN ('Coglavax','Vac-Sules Feedlot');

-- 4) protokol adımları (yoksa)
--    Coglavax: g0 + g28 ; Vac-Sules: g0 + g30 ; diğerleri: g0 tek doz
INSERT INTO public.vaccine_protocol_steps (vaccine_id, adim_no, offset_gun, label)
SELECT v.id, 1, 0, '1. doz' FROM public.vaccines v
WHERE NOT EXISTS (SELECT 1 FROM public.vaccine_protocol_steps s WHERE s.vaccine_id = v.id AND s.adim_no = 1);

INSERT INTO public.vaccine_protocol_steps (vaccine_id, adim_no, offset_gun, label)
SELECT v.id, 2, 28, '2. doz (primer)' FROM public.vaccines v
WHERE v.name = 'Coglavax'
  AND NOT EXISTS (SELECT 1 FROM public.vaccine_protocol_steps s WHERE s.vaccine_id = v.id AND s.adim_no = 2);

INSERT INTO public.vaccine_protocol_steps (vaccine_id, adim_no, offset_gun, label)
SELECT v.id, 2, 30, '2. doz (primer)' FROM public.vaccines v
WHERE v.name = 'Vac-Sules Feedlot'
  AND NOT EXISTS (SELECT 1 FROM public.vaccine_protocol_steps s WHERE s.vaccine_id = v.id AND s.adim_no = 2);

-- 5) vaccine_diseases bağları — disease_target metninden isim eşlemesi
INSERT INTO public.vaccine_diseases (vaccine_id, disease_id)
SELECT v.id, d.id
FROM public.vaccines v
JOIN public.diseases d ON v.disease_target ILIKE '%' || d.name || '%'
WHERE v.disease_target IS NOT NULL
ON CONFLICT DO NOTHING;

-- 5b) Ö3: ILIKE ile 0 bağ kalan 2 aşı için açık eşleme
INSERT INTO public.vaccine_diseases (vaccine_id, disease_id)
SELECT v.id, d.id FROM public.vaccines v CROSS JOIN public.diseases d
WHERE v.name = 'Clostridium Aşısı' AND d.name IN ('Enterotoksemi','Kara Hastalık','Yanıkara','Tetanoz')
ON CONFLICT DO NOTHING;

INSERT INTO public.vaccine_diseases (vaccine_id, disease_id)
SELECT v.id, d.id FROM public.vaccines v CROSS JOIN public.diseases d
WHERE v.name = 'E. coli Aşısı' AND d.name = 'E. coli (K99)'
ON CONFLICT DO NOTHING;

-- 6) Ö6/M-3: vaccines.disease_target'ı vaccine_diseases'ten yeniden formatla
--     (display-only alan; aktif zincir okumaz). Bağ olmayan aşıda mevcut değeri korur.
UPDATE public.vaccines v
SET disease_target = COALESCE(
  (SELECT string_agg(d.name, ', ' ORDER BY d.name)
   FROM public.vaccine_diseases vd JOIN public.diseases d ON d.id = vd.disease_id
   WHERE vd.vaccine_id = v.id),
  v.disease_target);
