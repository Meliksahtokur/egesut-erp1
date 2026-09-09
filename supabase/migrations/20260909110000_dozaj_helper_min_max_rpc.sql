-- ──────────────────────────────────────────────────────────────
-- 20260909110000_dozaj_helper_min_max_rpc.sql
-- Dozaj helper sheet — F1 faz 2 (spec: .claude/plans/2026-09-09-tedavi-doz-gorev-design.md §3, kullanıcı revizyonu 2026-09-09)
--
-- 1) drug_products: std_dose_min + std_dose_max (prospektüs aralıkları).
--    Birim std_dose_unit ile aynı; hesap tarafı 'varsayılan' = std_dose.
-- 2) Aralık seed'i: web araştırmasından (2026-09-09) ELİMİZDE OLAN
--    aralıklar; tek-değerli ürünlerde NULL (helper'da yalnız varsayılan çipi).
-- 3) ilac_dozaj_guncelle RPC: helper sheet'inin "Uygula" eylemi ilaç
--    kartına (drug_products) frontend'den db.from ile DEĞİL, bu RPC ile
--    yazar (kontrat: frontend raw SQL/db.from yazımı yapmaz). JSON param
--    anahtarı gönderilmemişse alan DOKUNULMAZ — sheet yalnız değişenleri
--    gönderir. Global katalog: farm_id ALINMAZ (kontrat invariant).
-- PROD deploy ayrı onay kapısı (önce demo'da doğrulandı).
-- ──────────────────────────────────────────────────────────────

ALTER TABLE public.drug_products
  ADD COLUMN IF NOT EXISTS std_dose_min numeric,
  ADD COLUMN IF NOT EXISTS std_dose_max numeric;

COMMENT ON COLUMN public.drug_products.std_dose_min IS 'Prospektüs alt doz (birim std_dose_unit) — NULL ise helper yalnız varsayılan çipi';
COMMENT ON COLUMN public.drug_products.std_dose_max IS 'Prospektüs üst doz (birim std_dose_unit) — NULL ise helper yalnız varsayılan çipi';

-- ── Aralık seed (kaynak: prospektüs/VetRehberi taraması 2026-09-09) ──
UPDATE public.drug_products SET std_dose_min = 2.5,  std_dose_max = 5    WHERE lower(btrim(brand_name)) = 'enrolen';             -- komplikasyonda 2 katı
UPDATE public.drug_products SET std_dose_min = 20,   std_dose_max = 40   WHERE lower(btrim(brand_name)) IN ('florkem','florkem (ceva)'); -- IM 20 / SC 40
UPDATE public.drug_products SET std_dose_min = 2,    std_dose_max = 8    WHERE lower(btrim(brand_name)) = 'marbox';              -- 3 gün 2 / tek IM 8
UPDATE public.drug_products SET std_dose_min = 1,    std_dose_max = 4    WHERE lower(btrim(brand_name)) = 'oksitosin yerli';     -- 1–4 ml/hayvan
UPDATE public.drug_products SET std_dose_min = 2.5,  std_dose_max = 5    WHERE lower(btrim(brand_name)) = 'buserin (alke)';      -- tohumlama 2,5 / kist 5
UPDATE public.drug_products SET std_dose_min = 80,   std_dose_max = 100  WHERE lower(btrim(brand_name)) = 'kalsiyum ( vilsan )'; -- 200–500 kg → 80–100 ml
UPDATE public.drug_products SET std_dose_min = 0.02, std_dose_max = 0.06 WHERE lower(btrim(brand_name)) = 'vetakort / kortikosteroid'; -- 20–60 µg/kg
UPDATE public.drug_products SET std_dose_min = 0.035,std_dose_max = 0.07 WHERE lower(btrim(brand_name)) = 'carofertin-e ( alivira )'; -- 3,5–7 ml/100 kg
UPDATE public.drug_products SET std_dose_min = 0.05, std_dose_max = 0.25 WHERE lower(btrim(brand_name)) = 'k vitamin (alke)';    -- 0,5–2,5 ml/10 kg
UPDATE public.drug_products SET std_dose_min = 5,    std_dose_max = 25   WHERE lower(btrim(brand_name)) = 'teknovet - b12 (fosforlu)'; -- 5–25 ml

-- ──────────────────────────────────────────────────────────────
-- ilac_dozaj_guncelle — helper sheet "Uygula" eyleminin ilaç kartı yazımı
-- p_guncellemeler JSON: yalnız gönderilen anahtarlar set edilir.
--   std_dose, std_dose_unit ('ml/kg'|'mg/kg'|'ml/hayvan'),
--   std_dose_min, std_dose_max, concentration, concentration_unit
-- Doğrulama: std_dose>0; min/max ikisi de doluysa min<=max; concentration>0.
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ilac_dozaj_guncelle(
  p_id            uuid,
  p_guncellemeler jsonb
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row   public.drug_products%ROWTYPE;
  v_json  jsonb := COALESCE(p_guncellemeler, '{}'::jsonb);
  v_unit  text;
  v_dose  numeric;
  v_min   numeric;
  v_max   numeric;
  v_conc  numeric;
BEGIN
  IF p_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'drug_product_id gerekli');
  END IF;
  SELECT * INTO v_row FROM public.drug_products WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'İlaç kartı bulunamadı');
  END IF;

  v_unit := COALESCE(v_json->>'std_dose_unit', v_row.std_dose_unit);
  IF v_unit IS NOT NULL AND v_unit NOT IN ('ml/kg','mg/kg','ml/hayvan') THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'std_dose_unit geçersiz: ' || v_unit);
  END IF;

  v_dose := COALESCE((v_json->>'std_dose')::numeric, v_row.std_dose);
  IF v_dose IS NOT NULL AND v_dose <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'std_dose > 0 olmalı');
  END IF;

  v_min := COALESCE((v_json->>'std_dose_min')::numeric, v_row.std_dose_min);
  v_max := COALESCE((v_json->>'std_dose_max')::numeric, v_row.std_dose_max);
  IF v_min IS NOT NULL AND v_max IS NOT NULL AND v_min > v_max THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'min > max olamaz');
  END IF;

  v_conc := COALESCE((v_json->>'concentration')::numeric, v_row.concentration);
  IF v_conc IS NOT NULL AND v_conc <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'concentration > 0 olmalı');
  END IF;

  UPDATE public.drug_products SET
    std_dose            = COALESCE((v_json->>'std_dose')::numeric,            std_dose),
    std_dose_unit       = COALESCE(v_json->>'std_dose_unit',                  std_dose_unit),
    std_dose_min        = COALESCE((v_json->>'std_dose_min')::numeric,        std_dose_min),
    std_dose_max        = COALESCE((v_json->>'std_dose_max')::numeric,        std_dose_max),
    concentration       = COALESCE((v_json->>'concentration')::numeric,       concentration),
    concentration_unit  = COALESCE(v_json->>'concentration_unit',             concentration_unit)
  WHERE id = p_id;

  RETURN jsonb_build_object('ok', true, 'id', p_id,
    'std_dose', v_dose, 'std_dose_unit', v_unit,
    'std_dose_min', v_min, 'std_dose_max', v_max, 'concentration', v_conc);
END;
$$;

GRANT EXECUTE ON FUNCTION public.ilac_dozaj_guncelle(uuid, jsonb) TO anon, authenticated;
