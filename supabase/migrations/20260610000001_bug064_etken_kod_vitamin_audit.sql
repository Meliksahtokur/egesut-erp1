-- Migration: BUG-064 fix
-- BUG-064: Protokol uygulama — E Vitamini görevi stok düşüyor ama gorev_log kapanmıyor
-- Yaklaşım 2: Trigger mimarisini KORU, 2 SQL fix + 1 bonus audit
-- Tarih: 2026-06-10
--
-- GERÇEK MEVCUT YAPI (Faz 0.2 doğrulaması):
--   hizli_uygulama(p_hayvan_id text, p_stok_id text, p_doz numeric,
--                  p_birim text, p_rota text, p_notlar text) → jsonb
-- Spec Rev 7'deki 11 parametreli imza YANLIŞ'tı → arşiv:
--   docs/ideas/2026-06-10-hizli-uygulama-genisletilmis-imza.md
-- v1 yanlış: backup/20260610000001_bug064_etken_kod_vitamin_audit.WRONG-11param-v1.sql
-- v2 doğru: ground truth'tan birebir kopyalama + islem_log INSERT ekleme
--
-- DEĞİŞEN DOSYALAR:
--   1) _etken_kod_bul (L9169-9224) — E_VIT için v_active_ing spesifik kontrolü
--   2) hizli_uygulama (L9256-9306) — mevcut yapı + islem_log audit
--   3) hizli_uygulama_geri_al (L9309-9342) — mevcut yapı + islem_log audit (Bonus)
--
-- DEĞİŞMEYEN: fn_dinle_uygulama (L9463-9473), _gorev_dinle (L9224-9255),
--   gorev_tamamla, tüm trigger'lar, diğer RPC'ler
-- ============================================================================

-- ════════════════════════════════════════════════════════════════
-- Fix #1: _etken_kod_bul — E_VIT için v_active_ing spesifik eşleşmesi
-- Kök neden: drug_classes.class_name='Yağda Eriyen Vitaminler' için
--   "E Vit" ILIKE eşleşmesi başarısız ("E " yerine "riyen " geliyor).
-- Çözüm: v_active_ing (active_ingredient) öncelikli kontrol — mevcut
--   E_VIT bloğundan ÖNCE eklenir.
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public._etken_kod_bul(
  p_stok_id text DEFAULT NULL,
  p_vaccine_id uuid DEFAULT NULL
) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

    -- E_VIT: YENİ — v_active_ing spesifik kontrol (aktif içerik "E Vitamini" içeriyorsa)
    IF v_active_ing ILIKE '%E Vitamini%' THEN RETURN 'E_VIT'; END IF;

    -- E_VIT: MEVCUT — sınıf adı + marka adı fallback'leri
    IF v_class_name ILIKE '%E Vit%' OR v_stok_ad ILIKE '%yeldif%' OR v_stok_ad ILIKE '%e vit%' THEN RETURN 'E_VIT'; END IF;

    IF v_class_name ILIKE '%ademin%' OR v_stok_ad ILIKE '%ademin%' THEN RETURN 'ADEMIN'; END IF;
    IF v_class_name ILIKE '%kalsiyum%' OR v_class_name ILIKE '%calcium%' OR v_stok_ad ILIKE '%kalsiyum%' THEN RETURN 'KALSIYUM'; END IF;

    RETURN NULL;
  END IF;

  RETURN NULL;
END;
$$;

-- ════════════════════════════════════════════════════════════════
-- Fix #2: hizli_uygulama — islem_log audit trail
-- Kök neden: uygulama_log + stok_hareket başarılı ama audit izi yok.
-- Çözüm: ground truth L9256-9306 birebir kopyalandı + uygulama_log
--   INSERT sonrası islem_log INSERT eklendi.
-- DİKKAT: Mevcut yapıya DOKUNULMADI — sadece 1 INSERT bloğu eklendi.
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.hizli_uygulama(
  p_hayvan_id text,
  p_stok_id text,
  p_doz numeric,
  p_birim text,
  p_rota text,
  p_notlar text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_hayvan hayvanlar%ROWTYPE;
  v_stok   record;
  v_etken  text;
  v_id     uuid;
  v_kalan  numeric;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = p_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok bulunamadı');
  END IF;

  v_etken := public._etken_kod_bul(p_stok_id, NULL);

  INSERT INTO public.uygulama_log (hayvan_id, stok_id, etken_kod, doz, birim, rota, notlar)
  VALUES (p_hayvan_id, p_stok_id, v_etken, p_doz, p_birim, p_rota, p_notlar)
  RETURNING id INTO v_id;

  -- YENİ: islem_log audit (BUG-064 Fix #2)
  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES (
    'HIZLI_UYGULAMA',
    p_hayvan_id,
    v_id::text,
    'uygulama_log',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(jsonb_build_object('tablo','uygulama_log','id',v_id::text)),
      'guncellenen', '[]'::jsonb,
      'silinen', '[]'::jsonb
    ),
    format('Hızlı Uygulama — %s — %s %s %s', v_hayvan.kupe_no, v_stok.urun_adi, p_doz, p_birim)
  );

  INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
  VALUES (gen_random_uuid(), p_stok_id, 'Hızlı Uygulama', p_doz,
          'Hızlı Uygulama — ' || v_hayvan.kupe_no || ' — ' || v_stok.urun_adi, false);

  SELECT COALESCE(s.baslangic_miktar, 0) - COALESCE(SUM(CASE WHEN sh.iptal = false THEN sh.miktar ELSE 0 END), 0)
  INTO v_kalan
  FROM public.stok s
  LEFT JOIN public.stok_hareket sh ON sh.stok_id = s.id
  WHERE s.id = p_stok_id
  GROUP BY s.baslangic_miktar;

  RETURN jsonb_build_object(
    'ok', true,
    'id', v_id,
    'etken_kod', v_etken,
    'stok_kalan', COALESCE(v_kalan, 0)
  );
END;
$$;

-- ════════════════════════════════════════════════════════════════
-- Bonus: hizli_uygulama_geri_al — islem_log audit simetrisi
-- Kök neden: geri alma işleminde audit izi yok, hizli_uygulama'daki
--   audit pattern boşluğu.
-- Çözüm: ground truth L9309-9342 birebir kopyalandı + islem_log INSERT
--   eklendi (UPDATE gorev_log sonrası, stok iade bloğu öncesi).
-- MEVCUT YAPI KORUNDU: kontrol + stok iade + gorev_log geri aç + RETURN
-- ⚠️ v_uyg.aktif_ing kolonu YOK (Faz 0.2 doğrulaması) → sade format.
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.hizli_uygulama_geri_al(
  p_uygulama_id uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_uyg    record;
  v_hayvan record;
BEGIN
  SELECT * INTO v_uyg FROM public.uygulama_log WHERE id = p_uygulama_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Uygulama kaydı bulunamadı');
  END IF;

  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = v_uyg.hayvan_id;

  -- Stok iade (ters hareket) — mevcut blok, KORUNDU
  IF v_uyg.stok_id IS NOT NULL THEN
    INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
    VALUES (gen_random_uuid(), v_uyg.stok_id, 'İade (Hızlı Uyg.)', -v_uyg.doz,
            'Geri Al — ' || COALESCE(v_hayvan.kupe_no, v_uyg.hayvan_id), false);
  END IF;

  -- YENİ: islem_log audit (Bonus simetri) — mevcut yapı AYNEN korundu
  INSERT INTO public.islem_log (
    tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu, durum, geri_alma_tarihi
  )
  VALUES (
    'HIZLI_UYGULAMA_GERI_AL',
    v_uyg.hayvan_id,
    p_uygulama_id::text,
    'uygulama_log',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'tablo','gorev_log','id',g.id::text,'alan','tamamlandi','eski',true,'yeni',false
        ))
        FROM public.gorev_log g
        WHERE g.kapatan_ref = 'uygulama_log:' || p_uygulama_id::text
      ), '[]'::jsonb),
      'silinen', jsonb_build_array(jsonb_build_object(
        'tablo','uygulama_log','id',p_uygulama_id::text
      ))
    ),
    format('Hızlı Uygulama Geri Al — %s — uygulama_id=%s', v_hayvan.kupe_no, p_uygulama_id),
    'geri_alindi',
    now()
  );

  -- Bu uygulama ile kapanan görevi tekrar aç — mevcut blok, KORUNDU
  UPDATE public.gorev_log
  SET tamamlandi = false,
      tamamlanma_tarihi = NULL,
      kapatan_ref = NULL
  WHERE kapatan_ref = 'uygulama_log:' || p_uygulama_id::text;

  -- uygulama_log DELETE — mevcut blok, KORUNDU
  DELETE FROM public.uygulama_log WHERE id = p_uygulama_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;
