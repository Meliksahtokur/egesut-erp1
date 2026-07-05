-- Migration: _etken_kod_bul — stok yolunda aşı (ROTA) isim-yakalaması
-- ------------------------------------------------------------------------
-- BUG: "Rota aşısı uygulandı (Hızlı Uygulama / protokol paneli) ama görev kapanmadı."
--
-- KÖK NEDEN: Aşılar stok kalemi olarak uygulanır → hizli_uygulama, etken_kod'u
--   _etken_kod_bul(p_stok_id, NULL) ile çözer. Ama '%Rota% → ROTA' kontrolü SADECE
--   p_vaccine_id (aşı) kolunda vardı; stok (ilaç) kolunda yoktu. Aşı stoklarının
--   drug_product_id FK'i de NULL (STOK-AŞI-*) → sınıf-bazlı kontroller de kaçıyor
--   → RETURN NULL. Sonuç: uygulama_log.etken_kod = NULL → AFTER INSERT trigger
--   fn_dinle_uygulama'nın `IF NEW.etken_kod IS NOT NULL` koşulu FALSE → _gorev_dinle
--   hiç çağrılmıyor → hayvan+etken_kod ile eşleşen bekleyen ROTA görevi kapanmıyor.
--   Stok düşümü etken_kod'a bağlı olmadığından gerçekleşir (semptom: stok düşer,
--   görev açık kalır). Canlı doğrulama: gorev_log(hayvan 110).etken_kod='ROTA' doğru,
--   uygulama_log.etken_kod=NULL, _etken_kod_bul(Rotavirus Aşısı)=NULL.
--
-- FIX: stok yolunda, v_stok_ad çekildikten hemen sonra ROTA isim-yakalaması ekle
--   (p_vaccine_id kolundaki 9429 mantığının aynısı). Salt additive: daha önce NULL
--   dönen rota-isimli stoklar artık 'ROTA' döner; başka hiçbir dalın davranışı değişmez.
--   Bekleyen aşı görevlerinde tek matchable vaccine etken_kod'u 'ROTA' (21 görev);
--   diğer aşılar görev tarafında da etiketsiz (null) → kapsam dışı, bu fix'i etkilemez.
--
-- Geri alınabilir: aşağıdaki IF satırını kaldırıp fonksiyonu yeniden REPLACE et.

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

  -- İlaç yolu: stok → drug_products → drug_classes
  IF p_stok_id IS NOT NULL THEN
    SELECT s.urun_adi INTO v_stok_ad FROM public.stok s WHERE s.id = p_stok_id;

    -- Aşı (stok yolu): FK zinciri aşılarda boş — isimden yakala.
    -- Görev tarafı rota görevini etken_kod='ROTA' ile etiketler; eşleşme için
    -- stok üzerinden uygulanan rota aşısı da 'ROTA'ya çözülmeli.
    IF v_stok_ad ILIKE '%Rota%' THEN RETURN 'ROTA'; END IF;

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
    IF v_active_ing ILIKE '%E Vitamini%' THEN RETURN 'E_VIT'; END IF;
    IF v_class_name ILIKE '%E Vit%' OR v_stok_ad ILIKE '%yeldif%' OR v_stok_ad ILIKE '%e vit%' THEN RETURN 'E_VIT'; END IF;
    IF v_class_name ILIKE '%ademin%' OR v_stok_ad ILIKE '%ademin%' THEN RETURN 'ADEMIN'; END IF;
    IF v_class_name ILIKE '%kalsiyum%' OR v_class_name ILIKE '%calcium%' OR v_stok_ad ILIKE '%kalsiyum%' THEN RETURN 'KALSIYUM'; END IF;

    RETURN NULL;
  END IF;

  RETURN NULL;
END;
$$;
