-- Migration: BUG-056 + BUG-057 fix
-- BUG-056: _etken_kod_bul stok.drug_product_id FK kullanmıyor
-- BUG-057: treatment_day_tamamla bağlı TEDAVI_GUN görevini kapatmıyor

-- ── 1. _etken_kod_bul — stok.drug_product_id öncelikli lookup ──
CREATE OR REPLACE FUNCTION public._etken_kod_bul(
  p_stok_id text DEFAULT NULL,
  p_vaccine_id uuid DEFAULT NULL
) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_class_name text;
  v_group_name text;
  v_active_ing text;
  v_stok_ad text;
  v_vaccine_name text;
BEGIN
  -- Aşı yolu
  IF p_vaccine_id IS NOT NULL THEN
    SELECT name INTO v_vaccine_name FROM public.vaccines WHERE id = p_vaccine_id;
    IF v_vaccine_name ILIKE '%Rota%' THEN RETURN 'ROTA'; END IF;
    RETURN NULL;
  END IF;

  -- İlaç yolu: stok.drug_product_id → drug_products → drug_classes
  IF p_stok_id IS NOT NULL THEN
    SELECT s.urun_adi INTO v_stok_ad FROM public.stok s WHERE s.id = p_stok_id;

    -- Önce stok.drug_product_id FK kullan (en doğru yol)
    SELECT dc.group_name, dc.class_name, dc.active_ingredient
    INTO v_group_name, v_class_name, v_active_ing
    FROM public.drug_products dp
    JOIN public.drug_classes dc ON dc.id = dp.drug_class_id
    WHERE dp.id = (SELECT drug_product_id FROM public.stok WHERE id = p_stok_id)
    LIMIT 1;

    -- Fallback: brand_name eşleşmesi
    IF v_class_name IS NULL THEN
      SELECT dc.group_name, dc.class_name, dc.active_ingredient
      INTO v_group_name, v_class_name, v_active_ing
      FROM public.drug_products dp
      JOIN public.drug_classes dc ON dc.id = dp.drug_class_id
      WHERE dp.brand_name ILIKE '%' || COALESCE(v_stok_ad,'') || '%'
      LIMIT 1;
    END IF;

    -- Sınıf bazlı eşleşme
    IF v_class_name ILIKE '%oksitosin%' OR v_active_ing ILIKE '%oxytocin%' THEN RETURN 'OKSITOSIN'; END IF;
    IF v_class_name ILIKE '%prostaglandin%' OR v_group_name ILIKE '%PG%' OR v_active_ing ILIKE '%dinoprost%' OR v_active_ing ILIKE '%cloprostenol%' THEN RETURN 'PG'; END IF;
    IF v_class_name ILIKE '%E Vit%' OR v_stok_ad ILIKE '%yeldif%' OR v_stok_ad ILIKE '%e vit%' THEN RETURN 'E_VIT'; END IF;
    IF v_class_name ILIKE '%ademin%' OR v_stok_ad ILIKE '%ademin%' THEN RETURN 'ADEMIN'; END IF;
    IF v_class_name ILIKE '%kalsiyum%' OR v_class_name ILIKE '%calcium%' OR v_stok_ad ILIKE '%kalsiyum%' THEN RETURN 'KALSIYUM'; END IF;

    RETURN NULL;
  END IF;

  RETURN NULL;
END;
$$;

-- ── 2. treatment_day_tamamla — bağlı gorev_log'u da tamamla ──
DROP FUNCTION IF EXISTS public.treatment_day_tamamla(uuid, text);
DROP FUNCTION IF EXISTS public.treatment_day_tamamla(uuid, text, uuid[]);
CREATE OR REPLACE FUNCTION public.treatment_day_tamamla(
  p_day_id           uuid,
  p_not              text    DEFAULT NULL,
  p_uygulanmadi_ids  uuid[]  DEFAULT '{}'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_day       public.treatment_days%ROWTYPE;
  v_onceki    boolean;
  v_admin_id  uuid;
  v_stok_id   text;
BEGIN
  SELECT * INTO v_day FROM public.treatment_days WHERE id = p_day_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tedavi günü bulunamadı: %', p_day_id;
  END IF;

  IF v_day.tamamlandi THEN
    RAISE EXCEPTION 'Bu tedavi günü zaten tamamlandı';
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.treatment_days
    WHERE case_id = v_day.case_id
      AND day_no  < v_day.day_no
      AND (tamamlandi IS NULL OR tamamlandi = false)
  ) INTO v_onceki;

  IF v_onceki THEN
    RAISE EXCEPTION 'Önceki tedavi günleri tamamlanmadan bu gün tamamlanamaz';
  END IF;

  UPDATE public.treatment_days
  SET tamamlandi        = true,
      tamamlanma_tarihi = now(),
      tamamlanma_notu   = p_not
  WHERE id = p_day_id;

  -- Bağlı TEDAVI_GUN görevini de atomik olarak kapat
  UPDATE public.gorev_log
  SET tamamlandi = true,
      tamamlanma_tarihi = now()
  WHERE gorev_tipi = 'TEDAVI_GUN'
    AND tamamlandi = false
    AND iptal = false
    AND (aciklama::jsonb->>'day_id')::uuid = p_day_id;

  -- Uygulanmayan ilaçlar: uygulanmadi=true + stok iadesi
  IF array_length(p_uygulanmadi_ids, 1) > 0 THEN
    FOREACH v_admin_id IN ARRAY p_uygulanmadi_ids
    LOOP
      UPDATE public.drug_administrations
      SET uygulanmadi = true
      WHERE id = v_admin_id
        AND treatment_day_id = p_day_id
      RETURNING stok_id INTO v_stok_id;

      IF v_stok_id IS NOT NULL THEN
        UPDATE public.stok_hareket
        SET iptal = true
        WHERE notlar = 'drug_admin:' || v_admin_id::text
          AND iptal = false;
      END IF;
    END LOOP;
  END IF;

  RETURN jsonb_build_object('ok', true, 'day_id', p_day_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.treatment_day_tamamla TO anon, authenticated;
