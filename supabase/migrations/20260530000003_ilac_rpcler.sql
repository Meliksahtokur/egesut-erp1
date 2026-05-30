-- 20260530000003_ilac_rpcler.sql
-- Ilac siniflandirma CRUD RPC'leri + stok validate

BEGIN;

-- 1. drug_class_ekle
CREATE OR REPLACE FUNCTION public.drug_class_ekle(
  p_group_name text,
  p_class_name text,
  p_active_ingredient text,
  p_kategori_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_group_name IS NULL OR p_group_name = '' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Grup adı zorunlu');
  END IF;
  IF p_active_ingredient IS NULL OR p_active_ingredient = '' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Etken madde adı zorunlu');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.drug_classes
    WHERE group_name = p_group_name
      AND COALESCE(class_name,'') = COALESCE(p_class_name,'')
      AND active_ingredient = p_active_ingredient
  ) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu kombinasyon zaten mevcut');
  END IF;

  v_id := gen_random_uuid();
  INSERT INTO public.drug_classes (id, group_name, class_name, active_ingredient, kategori_id)
  VALUES (v_id, p_group_name, NULLIF(p_class_name,''), p_active_ingredient, p_kategori_id);

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'mesaj', 'Etken madde eklendi');
END;
$$;
GRANT EXECUTE ON FUNCTION public.drug_class_ekle(text,text,text,uuid) TO anon, authenticated;

-- 2. drug_class_guncelle
CREATE OR REPLACE FUNCTION public.drug_class_guncelle(
  p_id uuid,
  p_group_name text DEFAULT NULL,
  p_class_name text DEFAULT NULL,
  p_active_ingredient text DEFAULT NULL,
  p_kategori_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.drug_classes WHERE id = p_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayıt bulunamadı');
  END IF;

  UPDATE public.drug_classes SET
    group_name = COALESCE(NULLIF(p_group_name,''), group_name),
    class_name = COALESCE(p_class_name, class_name),
    active_ingredient = COALESCE(NULLIF(p_active_ingredient,''), active_ingredient),
    kategori_id = COALESCE(p_kategori_id, kategori_id)
  WHERE id = p_id;

  RETURN jsonb_build_object('ok', true, 'mesaj', 'Güncellendi');
END;
$$;
GRANT EXECUTE ON FUNCTION public.drug_class_guncelle(uuid,text,text,text,uuid) TO anon, authenticated;

-- 3. drug_class_sil
CREATE OR REPLACE FUNCTION public.drug_class_sil(
  p_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count integer;
BEGIN
  SELECT COUNT(*) INTO v_count FROM public.drug_products WHERE drug_class_id = p_id;
  IF v_count > 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      'Bu etken maddeye bağlı ' || v_count || ' preparat var. Önce preparatları başka sınıfa taşıyın.');
  END IF;

  DELETE FROM public.drug_classes WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'mesaj', 'Silindi');
END;
$$;
GRANT EXECUTE ON FUNCTION public.drug_class_sil(uuid) TO anon, authenticated;

-- 4. drug_class_varsayilan_yukle
CREATE OR REPLACE FUNCTION public.drug_class_varsayilan_yukle()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_before integer;
  v_after integer;
BEGIN
  SELECT COUNT(*) INTO v_before FROM public.drug_classes;

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
    ('Antimikrobiyaller (Antibiyotikler)', 'Sulfonamidler', 'Trimetoprim-SMX', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Anti-inflamatuar İlaçlar', 'NSAID', 'Meloksikam', (SELECT id FROM stok_kategorileri WHERE ad='NSAID')),
    ('Anti-inflamatuar İlaçlar', 'NSAID', 'Ketoprofen', (SELECT id FROM stok_kategorileri WHERE ad='NSAID')),
    ('Anti-inflamatuar İlaçlar', 'NSAID', 'Flunixin', (SELECT id FROM stok_kategorileri WHERE ad='NSAID')),
    ('Anti-inflamatuar İlaçlar', 'Kortikosteroidler', 'Deksametazon', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
    ('Hormonlar ve Üreme İlaçları', 'Prostaglandinler', 'Dinoprost', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
    ('Hormonlar ve Üreme İlaçları', 'GnRH Agonistleri', 'Gonadorelin', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
    ('Hormonlar ve Üreme İlaçları', 'Progestagenler', 'Progesteron', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
    ('Hormonlar ve Üreme İlaçları', 'Oksitosin', 'Oksitosin', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
    ('Antiparaziter İlaçlar', 'Makrosiklik Laktonlar', 'İvermektin', (SELECT id FROM stok_kategorileri WHERE ad='Antiparaziter')),
    ('Antiparaziter İlaçlar', 'Makrosiklik Laktonlar', 'Doramektin', (SELECT id FROM stok_kategorileri WHERE ad='Antiparaziter')),
    ('Antiparaziter İlaçlar', 'Benzimidazoller', 'Albendazol', (SELECT id FROM stok_kategorileri WHERE ad='Antiparaziter')),
    ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B1 (Tiamin)', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B6 (Piridoksin)', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B12 (Siyanokobalamin)', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B Kompleks', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'C Vitamini', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Yağda Eriyen Vitaminler', 'E Vitamini', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Yağda Eriyen Vitaminler', 'AD3E Kombinasyon', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Mineraller / İz Elementler', 'Selenyum', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Metabolik / Sıvı Tedavi', 'Kalsiyum Preparatları', 'Kalsiyum Boroglukonat', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Metabolik / Sıvı Tedavi', 'Magnezyum', 'Magnezyum Sülfat', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Metabolik / Sıvı Tedavi', 'Glukoz / Dekstroz', 'Glukoz %50', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Metabolik / Sıvı Tedavi', 'Glukoz / Dekstroz', 'Dekstroz %30', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Metabolik / Sıvı Tedavi', 'Elektrolitler', 'Oral Rehidrasyon Solüsyonu', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Metabolik / Sıvı Tedavi', 'Elektrolitler', 'IV Serum (İzotonik NaCl, Ringer Laktat)', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Gastrointestinal İlaçlar', 'Gastroprotektanlar', 'Sukralfat (Antepsin)', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
    ('Gastrointestinal İlaçlar', 'Rumen Stimülanları', 'Rumen Stimülanı', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
    ('Gastrointestinal İlaçlar', 'Probiyotikler / Maya', 'Saccharomyces (Maya)', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
    ('Gastrointestinal İlaçlar', 'Probiyotikler / Maya', 'Probiyotik Preparatları', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
    ('Topikal / Harici İlaçlar', 'Merhemler', 'İhtiyol (Kara Merhem)', (SELECT id FROM stok_kategorileri WHERE ad='Topikal')),
    ('Anestezik / Sedatif', 'Sedatifler', 'Ksilazin', (SELECT id FROM stok_kategorileri WHERE ad='Anestezik / Sedatif')),
    ('Anestezik / Sedatif', 'Genel Anestezikler', 'Ketamin', (SELECT id FROM stok_kategorileri WHERE ad='Anestezik / Sedatif')),
    ('Anestezik / Sedatif', 'Lokal Anestezikler', 'Lidokain', (SELECT id FROM stok_kategorileri WHERE ad='Anestezik / Sedatif'))
  ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;

  SELECT COUNT(*) INTO v_after FROM public.drug_classes;

  RETURN jsonb_build_object('ok', true, 'eklenen', v_after - v_before);
END;
$$;
GRANT EXECUTE ON FUNCTION public.drug_class_varsayilan_yukle() TO anon, authenticated;

-- 5. stok_ekle — kategori validate ekle
CREATE OR REPLACE FUNCTION public.stok_ekle(
  p_urun_adi text,
  p_kategori text,
  p_birim text,
  p_baslangic_miktar numeric,
  p_esik numeric DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.stok_kategorileri WHERE ad = p_kategori) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçersiz kategori: ' || p_kategori);
  END IF;

  v_id := gen_random_uuid()::text;

  INSERT INTO public.stok (id, urun_adi, kategori, birim, baslangic_miktar, esik)
  VALUES (v_id, p_urun_adi, p_kategori, p_birim, p_baslangic_miktar, p_esik);

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('STOK_EKLE', v_id, 'stok', jsonb_build_object(
    'olusturulan', jsonb_build_array(jsonb_build_object(
      'tablo', 'stok', 'id', v_id,
      'veri', jsonb_build_object('urun_adi', p_urun_adi, 'kategori', p_kategori, 'birim', p_birim, 'baslangic_miktar', p_baslangic_miktar, 'esik', p_esik)
    )),
    'guncellenen', '[]'::jsonb,
    'silinen', '[]'::jsonb
  ), 'Yeni stok: ' || p_urun_adi);

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.stok_ekle(text, text, text, numeric, numeric) TO anon, authenticated;

-- 6. stok_guncelle — kategori validate ekle
CREATE OR REPLACE FUNCTION public.stok_guncelle(
  p_stok_id text,
  p_urun_adi text DEFAULT NULL,
  p_kategori text DEFAULT NULL,
  p_birim text DEFAULT NULL,
  p_esik numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok record;
  v_onceki jsonb;
BEGIN
  SELECT * INTO v_stok FROM public.stok WHERE id = p_stok_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Stok bulunamadı: %', p_stok_id; END IF;

  IF p_kategori IS NOT NULL AND p_kategori != '' THEN
    IF NOT EXISTS (SELECT 1 FROM public.stok_kategorileri WHERE ad = p_kategori) THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçersiz kategori: ' || p_kategori);
    END IF;
  END IF;

  v_onceki := row_to_json(v_stok)::jsonb;

  UPDATE public.stok SET
    urun_adi = COALESCE(NULLIF(p_urun_adi, ''), urun_adi),
    kategori = COALESCE(NULLIF(p_kategori, ''), kategori),
    birim    = COALESCE(NULLIF(p_birim, ''), birim),
    esik     = COALESCE(p_esik, esik)
  WHERE id = p_stok_id;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('STOK_GUNCELLE', p_stok_id, 'stok', jsonb_build_object(
    'olusturulan', '[]'::jsonb,
    'guncellenen', jsonb_build_array(jsonb_build_object(
      'tablo', 'stok', 'id', p_stok_id,
      'onceki', v_onceki,
      'sonraki', (SELECT row_to_json(stok)::jsonb FROM public.stok WHERE id = p_stok_id)
    )),
    'silinen', '[]'::jsonb
  ), 'Stok güncellendi: ' || COALESCE(p_urun_adi, (SELECT urun_adi FROM public.stok WHERE id = p_stok_id)));

  RETURN jsonb_build_object('ok', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.stok_guncelle(text,text,text,text,numeric) TO anon, authenticated;

COMMIT;
