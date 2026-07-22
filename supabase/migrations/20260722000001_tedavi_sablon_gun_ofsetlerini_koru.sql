-- Şablon günleri göreli ofsettir: Gün 0 DB'de gun_no=1 olarak saklanır.
-- gun_no değerlerini sıkıştırma; ör. Gün 0, 7, 8, 9, 10 sırasıyla 1, 8, 9, 10, 11 kalır.
CREATE OR REPLACE FUNCTION public.tedavi_sablon_kaydet(
  p_id          uuid,
  p_ad          text,
  p_aciklama    text,
  p_disease_ids jsonb,
  p_kalemler    jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_ad IS NULL OR btrim(p_ad) = '' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Şablon adı zorunlu');
  END IF;
  IF EXISTS (SELECT 1 FROM public.tedavi_sablonu
             WHERE LOWER(ad) = LOWER(p_ad) AND (p_id IS NULL OR id != p_id)) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu isimde başka bir şablon var');
  END IF;
  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(coalesce(p_kalemler, '[]'::jsonb)) AS k
    WHERE coalesce((k->>'gun_no')::smallint, 0) < 1
  ) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Şablon gün ofseti 0 veya daha büyük olmalı');
  END IF;

  IF p_id IS NULL THEN
    INSERT INTO public.tedavi_sablonu (ad, aciklama)
    VALUES (p_ad, NULLIF(btrim(coalesce(p_aciklama,'')),''))
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.tedavi_sablonu
       SET ad = p_ad, aciklama = NULLIF(btrim(coalesce(p_aciklama,'')),''), updated_at = now()
     WHERE id = p_id;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Şablon bulunamadı'); END IF;
    v_id := p_id;
    DELETE FROM public.sablon_hastalik_eslem WHERE sablon_id = v_id;
    DELETE FROM public.tedavi_sablonu_kalem  WHERE sablon_id = v_id;
  END IF;

  INSERT INTO public.sablon_hastalik_eslem (sablon_id, disease_id)
  SELECT v_id, t.val::uuid
  FROM jsonb_array_elements_text(coalesce(p_disease_ids,'[]'::jsonb)) AS t(val)
  ON CONFLICT (sablon_id, disease_id) DO NOTHING;

  INSERT INTO public.tedavi_sablonu_kalem
    (sablon_id, gun_no, planned_time, stok_id, drug_product_id, dose, unit, route)
  SELECT
    v_id,
    (k->>'gun_no')::smallint,
    (k->>'planned_time')::time,
    NULLIF(k->>'stok_id','')::text,
    NULLIF(k->>'drug_product_id','')::uuid,
    (k->>'dose')::numeric,
    k->>'unit',
    NULLIF(k->>'route','')
  FROM jsonb_array_elements(coalesce(p_kalemler,'[]'::jsonb)) AS k;

  RETURN jsonb_build_object('ok', true, 'sablon_id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.tedavi_sablon_kaydet(uuid, text, text, jsonb, jsonb) TO anon, authenticated;
