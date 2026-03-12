-- ══════════════════════════════════════════════════════════════
-- MIGRATION 019 — TEDAVİ TABLOSU YENİDEN TASARIM
-- EgeSüt ERP — 2026-03-12
--
-- Değişiklikler:
-- 1. tedavi tablosuna eksik kolonlar eklendi
--    (uygulama_yolu, hekim_id, uygulayan, bekleme_suresi_gun)
-- 2. stok.kategori standardize edildi (İlaç / Sperma / Malzeme / Yem)
-- 3. hastalik_kaydet RPC → ilaçları tedavi tablosuna yazar
-- 4. tedavi_ekle RPC → sonradan ilaç eklemek için
-- 5. tedavi_sil RPC → ilaç kaydı sil + stok_hareket iptal
-- 6. hastalik_guncelle RPC → p_ilaclar kaldırıldı (tedavi_ekle/sil kullanılacak)
-- 7. tedavi view → hastalık detayı için
-- 8. RLS politikaları
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- 1. TEDAVİ TABLOSUNA EKSİK KOLONLAR
-- ──────────────────────────────────────────────────────────────
ALTER TABLE public.tedavi
  ADD COLUMN IF NOT EXISTS uygulama_yolu    text,     -- IM, SC, IV, Oral, Topikal
  ADD COLUMN IF NOT EXISTS hekim_id         text,
  ADD COLUMN IF NOT EXISTS bekleme_suresi_gun integer, -- süt/et bekleme süresi (gün)
  ADD COLUMN IF NOT EXISTS notlar           text;

-- uygulama_yolu kısıtı (opsiyonel, esnek tutmak için CHECK yok)
COMMENT ON COLUMN public.tedavi.uygulama_yolu IS 'IM | SC | IV | Oral | Topikal | Intrauterin';
COMMENT ON COLUMN public.tedavi.bekleme_suresi_gun IS 'İlaç sonrası süt/et yasağı gün sayısı';

-- ──────────────────────────────────────────────────────────────
-- 2. STOK KATEGORİ COMMENT
-- ──────────────────────────────────────────────────────────────
COMMENT ON COLUMN public.stok.kategori IS 'İlaç | Sperma | Malzeme | Yem | Diğer';

-- ──────────────────────────────────────────────────────────────
-- 3. TEDAVİ VIEW — hastalık detay modalı için
-- ──────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS public.tedavi_view CASCADE;
CREATE OR REPLACE VIEW public.tedavi_view AS
SELECT
  t.id,
  t.hayvan_id,
  t.vaka_id,
  t.tarih,
  t.tani,
  t.miktar,
  t.uygulama_yolu,
  t.hekim_id,
  t.bekleme_suresi_gun,
  t.sut_yasagi_bitis,
  t.aktif,
  t.notlar,
  t.created_at,
  s.urun_adi   AS ilac_adi,
  s.birim      AS ilac_birim,
  s.kategori   AS ilac_kategori
FROM public.tedavi t
LEFT JOIN public.stok s ON s.id = t.ilac_stok_id;

-- ──────────────────────────────────────────────────────────────
-- 4. HASTALIK_KAYDET — ilaçları tedavi tablosuna yazar
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hastalik_kaydet(
  p_hayvan_id   text,
  p_tani        text,
  p_kategori    text    DEFAULT NULL,
  p_siddet      text    DEFAULT NULL,
  p_semptomlar  text    DEFAULT NULL,
  p_lokasyon    text    DEFAULT NULL,
  p_hekim_id    text    DEFAULT NULL,
  p_ilaclar     jsonb   DEFAULT '[]',
  p_tedavi_gun  integer DEFAULT 1
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan    record;
  v_hst_id    uuid := gen_random_uuid();
  v_bugun     date := CURRENT_DATE;
  v_ilac      jsonb;
  v_stok_id   text;
  v_miktar    numeric;
  v_yol       text;
  v_bekleme   integer;
  v_g         integer;
  v_ilac_ac   text := '';
  v_stok_rec  record;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  -- Hastalık (vaka) kaydı
  INSERT INTO public.hastalik_log (
    id, hayvan_id, tarih, kategori, tani, siddet, semptomlar,
    lokasyon, hekim_id, durum
  ) VALUES (
    v_hst_id, p_hayvan_id, v_bugun, p_kategori, p_tani, p_siddet, p_semptomlar,
    p_lokasyon, p_hekim_id, 'Aktif'
  );

  -- İlaçları tedavi tablosuna yaz + stok_hareket düş
  FOR v_ilac IN SELECT * FROM jsonb_array_elements(p_ilaclar)
  LOOP
    v_stok_id := v_ilac->>'stokId';
    v_miktar  := (v_ilac->>'mik')::numeric;
    v_yol     := v_ilac->>'uygulama_yolu';
    v_bekleme := (v_ilac->>'bekleme_suresi_gun')::integer;

    IF v_stok_id IS NOT NULL AND v_stok_id <> '' AND v_miktar > 0 THEN
      -- Stok adını bul
      SELECT * INTO v_stok_rec FROM public.stok WHERE id = v_stok_id;

      -- Tedavi kaydı
      INSERT INTO public.tedavi (
        hayvan_id, vaka_id, tarih, tani,
        ilac_stok_id, miktar, uygulama_yolu,
        hekim_id, bekleme_suresi_gun,
        sut_yasagi_bitis, aktif
      ) VALUES (
        p_hayvan_id, v_hst_id::text, v_bugun, p_tani,
        v_stok_id, v_miktar, v_yol,
        p_hekim_id, v_bekleme,
        CASE WHEN v_bekleme > 0 THEN v_bugun + v_bekleme ELSE NULL END,
        true
      );

      -- Stok hareketi
      INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
      VALUES (
        v_stok_id, 'Tedavi', v_miktar,
        p_tani || ' — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
        false
      );

      v_ilac_ac := v_ilac_ac || COALESCE(v_stok_rec.urun_adi, v_stok_id) || ' ' || v_miktar::text || ' ';
    END IF;
  END LOOP;

  -- Takip görevleri
  IF p_tedavi_gun > 1 AND jsonb_array_length(p_ilaclar) > 0 THEN
    FOR v_g IN 1..(p_tedavi_gun - 1) LOOP
      INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak)
      VALUES (
        gen_random_uuid(), p_hayvan_id, 'ILAC',
        'Tedavi ' || (v_g+1) || '. gün: ' || TRIM(v_ilac_ac),
        v_bugun + v_g, false, 'TEDAVI-' || v_hst_id::text
      );
    END LOOP;
  END IF;

  RETURN jsonb_build_object('ok', true, 'hastalik_id', v_hst_id);
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 5. TEDAVİ_EKLE — Mevcut vakaya ilaç ekle
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tedavi_ekle(
  p_vaka_id         text,
  p_hayvan_id       text,
  p_ilac_stok_id    text,
  p_miktar          numeric,
  p_uygulama_yolu   text    DEFAULT NULL,
  p_bekleme_gun     integer DEFAULT NULL,
  p_hekim_id        text    DEFAULT NULL,
  p_notlar          text    DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok    record;
  v_hayvan  record;
  v_bugun   date := CURRENT_DATE;
  v_tani    text;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = p_ilac_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok kalemi bulunamadı');
  END IF;

  SELECT tani INTO v_tani FROM public.hastalik_log WHERE id::text = p_vaka_id;

  INSERT INTO public.tedavi (
    hayvan_id, vaka_id, tarih, tani,
    ilac_stok_id, miktar, uygulama_yolu,
    hekim_id, bekleme_suresi_gun,
    sut_yasagi_bitis, aktif, notlar
  ) VALUES (
    p_hayvan_id, p_vaka_id, v_bugun, v_tani,
    p_ilac_stok_id, p_miktar, p_uygulama_yolu,
    p_hekim_id, p_bekleme_gun,
    CASE WHEN p_bekleme_gun > 0 THEN v_bugun + p_bekleme_gun ELSE NULL END,
    true, p_notlar
  );

  -- Stok hareketi
  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  VALUES (
    p_ilac_stok_id, 'Tedavi', p_miktar,
    COALESCE(v_tani, 'Tedavi') || ' — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
    false
  );

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 6. TEDAVİ_SİL — İlaç kaydını sil + stok_hareket iptal et
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tedavi_sil(
  p_tedavi_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tedavi record;
BEGIN
  SELECT * INTO v_tedavi FROM public.tedavi WHERE id::text = p_tedavi_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tedavi kaydı bulunamadı');
  END IF;

  -- Stok hareketini iptal et (son eşleşen)
  UPDATE public.stok_hareket
  SET iptal = true
  WHERE id = (
    SELECT id FROM public.stok_hareket
    WHERE stok_id = v_tedavi.ilac_stok_id
      AND tur = 'Tedavi'
      AND iptal = false
      AND miktar = v_tedavi.miktar
    ORDER BY created_at DESC
    LIMIT 1
  );

  DELETE FROM public.tedavi WHERE id::text = p_tedavi_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 7. HASTALIK_GUNCELLE — ilaç parametresi yok (tedavi_ekle/sil kullanılır)
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hastalik_guncelle(
  p_id         text,
  p_tani       text    DEFAULT NULL,
  p_kategori   text    DEFAULT NULL,
  p_siddet     text    DEFAULT NULL,
  p_semptomlar text    DEFAULT NULL,
  p_lokasyon   text    DEFAULT NULL,
  p_hekim_id   text    DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.hastalik_log SET
    tani       = COALESCE(p_tani,       tani),
    kategori   = COALESCE(p_kategori,   kategori),
    siddet     = COALESCE(p_siddet,     siddet),
    semptomlar = COALESCE(p_semptomlar, semptomlar),
    lokasyon   = COALESCE(p_lokasyon,   lokasyon),
    hekim_id   = COALESCE(p_hekim_id,   hekim_id)
  WHERE id::text = p_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayıt bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 8. HASTALIK_SİL — tedavi kayıtlarını da temizle
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hastalik_sil(
  p_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_ted record;
BEGIN
  -- Bağlı tedavilerin stok hareketlerini iptal et
  FOR v_ted IN SELECT * FROM public.tedavi WHERE vaka_id = p_id
  LOOP
    UPDATE public.stok_hareket
    SET iptal = true
    WHERE id = (
      SELECT id FROM public.stok_hareket
      WHERE stok_id = v_ted.ilac_stok_id
        AND tur = 'Tedavi'
        AND iptal = false
        AND miktar = v_ted.miktar
      ORDER BY created_at DESC
      LIMIT 1
    );
  END LOOP;

  -- Bağlı tedavileri sil
  DELETE FROM public.tedavi WHERE vaka_id = p_id;

  -- Takip görevlerini kapat
  UPDATE public.gorev_log SET
    tamamlandi = true,
    aciklama   = COALESCE(aciklama, '') || ' [Hastalık kaydı silindi]'
  WHERE kaynak = 'TEDAVI-' || p_id AND tamamlandi = false;

  -- Hastalık kaydını sil
  DELETE FROM public.hastalik_log WHERE id::text = p_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayıt bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 9. RLS POLİTİKALARI
-- ──────────────────────────────────────────────────────────────
ALTER TABLE public.tedavi ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tedavi_select ON public.tedavi;
DROP POLICY IF EXISTS tedavi_insert ON public.tedavi;
DROP POLICY IF EXISTS tedavi_update ON public.tedavi;
DROP POLICY IF EXISTS tedavi_delete ON public.tedavi;

CREATE POLICY tedavi_select ON public.tedavi FOR SELECT USING (true);
CREATE POLICY tedavi_insert ON public.tedavi FOR INSERT WITH CHECK (true);
CREATE POLICY tedavi_update ON public.tedavi FOR UPDATE USING (true);
CREATE POLICY tedavi_delete ON public.tedavi FOR DELETE USING (true);

-- SECURITY DEFINER
ALTER FUNCTION public.hastalik_kaydet  SECURITY DEFINER;
ALTER FUNCTION public.tedavi_ekle      SECURITY DEFINER;
ALTER FUNCTION public.tedavi_sil       SECURITY DEFINER;
ALTER FUNCTION public.hastalik_guncelle SECURITY DEFINER;
ALTER FUNCTION public.hastalik_sil     SECURITY DEFINER;

NOTIFY pgrst, 'reload schema';
