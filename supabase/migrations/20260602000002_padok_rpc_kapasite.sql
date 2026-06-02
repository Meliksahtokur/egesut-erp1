-- supabase/migrations/20260602000002_padok_rpc_kapasite.sql
-- Mevcut padok_degistir RPC'yi kapasite kontrolü ile günceller
-- Yeni: padok_degistir_toplu all-or-nothing versiyonu

CREATE OR REPLACE FUNCTION padok_degistir(
  p_hayvan_id text,
  p_yeni_padok_id uuid,
  p_not text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_hayvan        hayvanlar%ROWTYPE;
  v_yeni_padok    padoklar%ROWTYPE;
  v_aktif_sayisi  integer;
  v_doluluk_yuzde integer;
  v_kapasite_uyari boolean := false;
BEGIN
  -- Hayvan var mı?
  SELECT * INTO v_hayvan FROM hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hayvan bulunamadı');
  END IF;

  -- Hedef padok var mı?
  SELECT * INTO v_yeni_padok FROM padoklar WHERE id = p_yeni_padok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef padok bulunamadı');
  END IF;

  -- Zaten aynı padokta mı?
  IF v_hayvan.padok_id = p_yeni_padok_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hayvan zaten bu padokta');
  END IF;

  -- Kapasite kontrolü
  IF v_yeni_padok.kapasite IS NOT NULL THEN
    SELECT COUNT(*) INTO v_aktif_sayisi
      FROM hayvanlar
      WHERE padok_id = p_yeni_padok_id AND durum = 'Aktif';

    IF v_aktif_sayisi >= v_yeni_padok.kapasite THEN
      RETURN jsonb_build_object(
        'success', false,
        'error',   'kapasite_dolu',
        'detay',   v_aktif_sayisi::text || '/' || v_yeni_padok.kapasite::text
      );
    END IF;

    v_doluluk_yuzde  := ROUND((v_aktif_sayisi::numeric / v_yeni_padok.kapasite) * 100);
    v_kapasite_uyari := v_doluluk_yuzde >= 80;
  END IF;

  -- Güncelle
  UPDATE hayvanlar
     SET padok_id   = p_yeni_padok_id,
         padok      = v_yeni_padok.ad,
         updated_at = now()
   WHERE id = p_hayvan_id;

  -- İşlem logu (correct columns for islem_log table)
  INSERT INTO islem_log (tip, ana_hayvan_id, ref_id, snapshot, kullanici_notu)
  VALUES ('padok_degisim', p_hayvan_id, p_hayvan_id, '{}'::jsonb,
          COALESCE(p_not, 'Padok değiştirildi → ' || v_yeni_padok.ad));

  RETURN jsonb_build_object(
    'success',         true,
    'yeni_padok',      v_yeni_padok.ad,
    'yeni_padok_id',   p_yeni_padok_id,
    'kapasite_uyari',  v_kapasite_uyari
  );
END;
$$;

GRANT EXECUTE ON FUNCTION padok_degistir(text, uuid, text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION padok_degistir_toplu(
  p_hayvan_ids   text[],
  p_yeni_padok_id uuid,
  p_etiketler    text[] DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_yeni_padok   padoklar%ROWTYPE;
  v_aktif_sayisi integer;
  v_hayvan_id    text;
  v_hayvan       hayvanlar%ROWTYPE;
BEGIN
  -- Hedef padok var mı?
  SELECT * INTO v_yeni_padok FROM padoklar WHERE id = p_yeni_padok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef padok bulunamadı');
  END IF;

  -- Kapasite hard block (validasyon, yazma yok)
  IF v_yeni_padok.kapasite IS NOT NULL THEN
    SELECT COUNT(*) INTO v_aktif_sayisi
      FROM hayvanlar
      WHERE padok_id = p_yeni_padok_id AND durum = 'Aktif';

    IF v_aktif_sayisi + array_length(p_hayvan_ids, 1) > v_yeni_padok.kapasite THEN
      RETURN jsonb_build_object(
        'success', false,
        'error',   'kapasite_dolu',
        'detay',   (v_aktif_sayisi + array_length(p_hayvan_ids, 1))::text
                   || '/' || v_yeni_padok.kapasite::text
      );
    END IF;
  END IF;

  -- Hayvan validasyonları (validasyon, yazma yok)
  FOREACH v_hayvan_id IN ARRAY p_hayvan_ids LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_hayvan_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hayvan bulunamadı: ' || v_hayvan_id);
    END IF;
    IF v_hayvan.padok_id = p_yeni_padok_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hayvan zaten bu padokta: ' || v_hayvan_id);
    END IF;
  END LOOP;

  -- Tüm validasyonlar geçti — yazma işlemleri
  FOREACH v_hayvan_id IN ARRAY p_hayvan_ids LOOP
    UPDATE hayvanlar
       SET padok_id   = p_yeni_padok_id,
           padok      = v_yeni_padok.ad,
           updated_at = now()
     WHERE id = v_hayvan_id;

    INSERT INTO islem_log (tip, ana_hayvan_id, ref_id, snapshot, kullanici_notu)
    VALUES ('padok_degisim', v_hayvan_id, v_hayvan_id, '{}'::jsonb,
            'Toplu padok değişimi → ' || v_yeni_padok.ad);
  END LOOP;

  -- Etiket güncelleme (varsa, mevcut etiketlerle birleştir)
  IF p_etiketler IS NOT NULL AND array_length(p_etiketler, 1) > 0 THEN
    UPDATE hayvanlar
       SET etiketler = array(
             SELECT DISTINCT unnest(COALESCE(etiketler, '{}') || p_etiketler)
           )
     WHERE id = ANY(p_hayvan_ids);
  END IF;

  RETURN jsonb_build_object(
    'success',       true,
    'hayvan_sayisi', array_length(p_hayvan_ids, 1),
    'yeni_padok',    v_yeni_padok.ad,
    'yeni_padok_id', p_yeni_padok_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION padok_degistir_toplu(text[], uuid, text[]) TO anon, authenticated;
