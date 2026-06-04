-- Migration: Protokol-Görev Entegrasyonu (§1 + §3)
-- §1: _etken_kod_bul — FK zinciri (stok→drug_products→drug_classes) öncelikli
-- §3: gorev_tamamla — stok parametreleri + uygulama_log entegrasyonu
-- Tarih: 2026-06-04
-- Geri alınabilir: DROP FUNCTION IF EXISTS, eski imzaya dönülebilir

BEGIN;

-- ============================================================
-- §1: _etken_kod_bul Fix — FK Zinciri + active_ingredient
-- ============================================================
-- Sorun: CAROFERTIN-E gibi ürünler drug_administrations üzerinden
--        join edildiği için hiç kullanılmamışsa bulunamıyordu.
-- Çözüm: stok.drug_product_id → drug_products.drug_class_id →
--        drug_classes.active_ingredient direkt zinciri.
--        Text fallback sadece drug_product_id=NULL eski stoklar için.

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
  v_dp_id uuid;  -- stok.drug_product_id ve drug_products.id uuid tipinde
BEGIN
  -- Aşı yolu
  IF p_vaccine_id IS NOT NULL THEN
    SELECT name INTO v_vaccine_name FROM public.vaccines WHERE id = p_vaccine_id;
    IF v_vaccine_name ILIKE '%Rota%' THEN RETURN 'ROTA'; END IF;
    RETURN NULL;
  END IF;

  -- İlaç yolu: önce FK zinciri (stok → drug_products → drug_classes)
  IF p_stok_id IS NOT NULL THEN
    SELECT s.urun_adi, s.drug_product_id INTO v_stok_ad, v_dp_id
    FROM public.stok s WHERE s.id = p_stok_id;

    -- FK zinciri ile drug_class bilgilerini çek
    IF v_dp_id IS NOT NULL THEN
      SELECT dc.class_name, dc.group_name, dc.active_ingredient
      INTO v_class_name, v_group_name, v_active_ing
      FROM public.drug_products dp
      JOIN public.drug_classes dc ON dc.id = dp.drug_class_id
      WHERE dp.id = v_dp_id;
    END IF;

    -- active_ingredient bazlı eşleşme (en güvenilir)
    IF v_active_ing ILIKE '%oxytocin%' OR v_active_ing ILIKE '%oksitosin%' THEN RETURN 'OKSITOSIN'; END IF;
    IF v_active_ing ILIKE '%dinoprost%' OR v_active_ing ILIKE '%cloprostenol%' OR v_active_ing ILIKE '%prostaglandin%' THEN RETURN 'PG'; END IF;
    IF v_active_ing ILIKE '%E Vitamini%' OR v_active_ing ILIKE '%vitamin e%' OR v_active_ing ILIKE '%tocopherol%' THEN RETURN 'E_VIT'; END IF;
    IF v_active_ing ILIKE '%ademin%' OR v_active_ing ILIKE '%ADE%' THEN RETURN 'ADEMIN'; END IF;
    IF v_active_ing ILIKE '%kalsiyum%' OR v_active_ing ILIKE '%calcium%' THEN RETURN 'KALSIYUM'; END IF;

    -- Fallback: class_name / group_name (active_ingredient boş olan drug_class'lar)
    IF v_class_name ILIKE '%oksitosin%' THEN RETURN 'OKSITOSIN'; END IF;
    IF v_class_name ILIKE '%prostaglandin%' OR v_group_name ILIKE '%PG%' THEN RETURN 'PG'; END IF;
    IF v_class_name ILIKE '%E Vit%' THEN RETURN 'E_VIT'; END IF;
    IF v_class_name ILIKE '%ademin%' THEN RETURN 'ADEMIN'; END IF;
    IF v_class_name ILIKE '%kalsiyum%' OR v_class_name ILIKE '%calcium%' THEN RETURN 'KALSIYUM'; END IF;

    -- Son çare: urun_adi text matching (drug_product_id olmayan eski stoklar)
    IF v_stok_ad ILIKE '%oksitosin%' THEN RETURN 'OKSITOSIN'; END IF;
    IF v_stok_ad ILIKE '%pg%' OR v_stok_ad ILIKE '%cloprostenol%' OR v_stok_ad ILIKE '%dalmazin%' THEN RETURN 'PG'; END IF;
    IF v_stok_ad ILIKE '%yeldif%' OR v_stok_ad ILIKE '%e vit%' OR v_stok_ad ILIKE '%carofertin%' THEN RETURN 'E_VIT'; END IF;
    IF v_stok_ad ILIKE '%ademin%' THEN RETURN 'ADEMIN'; END IF;
    IF v_stok_ad ILIKE '%kalsiyum%' THEN RETURN 'KALSIYUM'; END IF;

    RETURN NULL;
  END IF;

  RETURN NULL;
END;
$$;

-- ============================================================
-- §3: gorev_tamamla — Stok Parametreleri + Uygulama Log
-- ============================================================
-- ÖNCE eski (text,text) imzayı DROP et — PostgREST overload PGRST203 önlemi
DROP FUNCTION IF EXISTS public.gorev_tamamla(text, text);

CREATE OR REPLACE FUNCTION public.gorev_tamamla(
  p_gorev_id text,
  p_padok_hedef text DEFAULT NULL,
  p_stok_id text DEFAULT NULL,
  p_doz numeric DEFAULT NULL,
  p_birim text DEFAULT NULL,
  p_rota text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev record;
  v_hayvan record;
  v_snapshot jsonb;
  v_stok_dusuldu boolean := false;
  v_padok_guncellendi boolean := false;
  v_olusturulan jsonb := '[]'::jsonb;
  v_guncellenen jsonb := '[]'::jsonb;
  v_yeni_padok_id uuid;
  v_etken text;
  v_uygulama_id uuid;
BEGIN
  SELECT * INTO v_gorev FROM public.gorev_log WHERE id = p_gorev_id::uuid;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Görev bulunamadı: %', p_gorev_id;
  END IF;
  IF v_gorev.tamamlandi THEN
    RETURN jsonb_build_object('ok', true, 'mesaj', 'Görev zaten tamamlanmış');
  END IF;
  IF v_gorev.iptal THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev iptal edilmiş, tamamlanamaz');
  END IF;

  -- a) Görevi tamamla
  v_guncellenen := v_guncellenen || jsonb_build_object(
    'tablo', 'gorev_log', 'id', p_gorev_id,
    'onceki', jsonb_build_object('tamamlandi', v_gorev.tamamlandi, 'tamamlanma_tarihi', v_gorev.tamamlanma_tarihi),
    'sonraki', jsonb_build_object('tamamlandi', true, 'tamamlanma_tarihi', now())
  );

  UPDATE public.gorev_log SET
    tamamlandi = true,
    tamamlanma_tarihi = now()
  WHERE id = p_gorev_id::uuid;

  -- b) Stok düşümü + uygulama_log (YENİ: p_stok_id öncelikli)
  IF p_stok_id IS NOT NULL AND p_doz IS NOT NULL AND p_doz > 0 THEN
    -- Yeni davranış: frontend'den gelen stok ile düşüm + uygulama log
    v_etken := public._etken_kod_bul(p_stok_id, NULL);

    v_stok_dusuldu := true;
    v_olusturulan := v_olusturulan || jsonb_build_object(
      'tablo', 'stok_hareket',
      'id', gen_random_uuid()::text,
      'veri', jsonb_build_object(
        'stok_id', p_stok_id,
        'tur', 'Görev',
        'miktar', p_doz,
        'notlar', 'GorevID:' || p_gorev_id,
        'iptal', false
      )
    );

    INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
    VALUES (gen_random_uuid(), p_stok_id, 'Görev', p_doz,
      'GorevID:' || p_gorev_id, false);

    -- Uygulama log kaydı → trigger fn_dinle_uygulama tetiklenir
    -- Görev zaten tamamlandığı için _gorev_dinle idempotent (tamamlandi=false filtresi)
    -- Ancak aynı etken_kod'lu başka bekleyen görev varsa onu da kapatır (istenen davranış)
    v_uygulama_id := gen_random_uuid();
    INSERT INTO public.uygulama_log (id, hayvan_id, stok_id, etken_kod, doz, birim, rota, notlar)
    VALUES (v_uygulama_id, v_gorev.hayvan_id, p_stok_id, v_etken, p_doz,
            COALESCE(p_birim, 'ml'), COALESCE(p_rota, 'IM'),
            'Görev: ' || COALESCE(v_gorev.aciklama, ''));

    v_olusturulan := v_olusturulan || jsonb_build_object(
      'tablo', 'uygulama_log',
      'id', v_uygulama_id::text,
      'veri', jsonb_build_object(
        'hayvan_id', v_gorev.hayvan_id,
        'stok_id', p_stok_id,
        'etken_kod', v_etken,
        'doz', p_doz,
        'birim', COALESCE(p_birim, 'ml'),
        'rota', COALESCE(p_rota, 'IM')
      )
    );

  ELSIF v_gorev.stok_id IS NOT NULL AND v_gorev.miktar IS NOT NULL AND v_gorev.miktar > 0 THEN
    -- Eski davranış: görevde stok_id + miktar doluysa düş (geriye uyumlu)
    v_stok_dusuldu := true;
    v_olusturulan := v_olusturulan || jsonb_build_object(
      'tablo', 'stok_hareket',
      'id', gen_random_uuid()::text,
      'veri', jsonb_build_object(
        'stok_id', v_gorev.stok_id,
        'tur', 'Görev',
        'miktar', v_gorev.miktar,
        'notlar', 'GorevID:' || p_gorev_id,
        'iptal', false
      )
    );

    INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
    VALUES (gen_random_uuid(), v_gorev.stok_id, 'Görev', v_gorev.miktar,
      'GorevID:' || p_gorev_id, false);
  END IF;

  -- c) Padok değişikliği — text + FK birlikte güncelle
  IF p_padok_hedef IS NOT NULL AND v_gorev.hayvan_id IS NOT NULL THEN
    SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = v_gorev.hayvan_id;
    IF FOUND THEN
      SELECT id INTO v_yeni_padok_id FROM public.padoklar WHERE ad = p_padok_hedef LIMIT 1;

      v_padok_guncellendi := true;
      v_guncellenen := v_guncellenen || jsonb_build_object(
        'tablo', 'hayvanlar', 'id', v_gorev.hayvan_id,
        'onceki', jsonb_build_object('padok', v_hayvan.padok, 'padok_id', v_hayvan.padok_id),
        'sonraki', jsonb_build_object('padok', p_padok_hedef, 'padok_id', v_yeni_padok_id)
      );

      UPDATE public.hayvanlar
      SET padok = p_padok_hedef,
          padok_id = v_yeni_padok_id
      WHERE id = v_gorev.hayvan_id;

      IF v_gorev.gorev_tipi = 'PADOK_DEGISIM' AND v_gorev.aciklama ILIKE '%Kuru döneme%' THEN
        UPDATE public.hayvanlar SET grup = 'Sağmal (Kuru Dönem)' WHERE id = v_gorev.hayvan_id;
      END IF;
    END IF;
  END IF;

  v_snapshot := jsonb_build_object(
    'olusturulan', v_olusturulan,
    'guncellenen', v_guncellenen,
    'silinen', '[]'::jsonb
  );

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('GOREV_TAMAMLA', v_gorev.hayvan_id, p_gorev_id, 'gorev_log', v_snapshot,
    format('Görev tamamlandı (stok: %s, padok: %s)',
      CASE WHEN v_stok_dusuldu THEN 'evet' ELSE 'hayır' END,
      CASE WHEN v_padok_guncellendi THEN 'evet' ELSE 'hayır' END));

  RETURN jsonb_build_object(
    'ok', true,
    'gorev_id', p_gorev_id,
    'stok_dusuldu', v_stok_dusuldu,
    'padok_guncellendi', v_padok_guncellendi
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.gorev_tamamla(text, text, text, numeric, text, text) TO anon, authenticated;

COMMIT;
