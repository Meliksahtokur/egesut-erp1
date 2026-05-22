-- Migration: Tekrar Aşım — deneme takibi ve tohumlama_tekrar_kaydet RPC
-- Etkiler:
--   1. tohumlama.deneme_sayisi + denemeler kolonları
--   2. tohumlama_cycle_gorevcil_iptal trigger GEBELIK_KONTROL fix
--   3. tohumlama_tekrar_kaydet RPC
-- Geri alınabilir:
--   ALTER TABLE public.tohumlama DROP COLUMN IF EXISTS deneme_sayisi;
--   ALTER TABLE public.tohumlama DROP COLUMN IF EXISTS denemeler;
--   CREATE OR REPLACE FUNCTION ... önceki versiyona dön
--   DROP FUNCTION IF EXISTS public.tohumlama_tekrar_kaydet;

BEGIN;

-- ═══════════════════════════════════════════════════════════
-- 1. tohumlama tablosuna deneme takip kolonları
-- ═══════════════════════════════════════════════════════════
ALTER TABLE public.tohumlama
  ADD COLUMN IF NOT EXISTS deneme_sayisi integer NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS denemeler    jsonb   NOT NULL DEFAULT '[]'::jsonb;

-- ═══════════════════════════════════════════════════════════
-- 2. Cycle trigger GEBELIK_KONTROL fix
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.tohumlama_cycle_gorevcil_iptal()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Yeni tohumlama INSERT → tüm önceki cycle gebelik görevleri iptal
  IF TG_OP = 'INSERT' THEN
    UPDATE public.gorev_log
    SET iptal = true
    WHERE hayvan_id = NEW.hayvan_id
      AND tamamlandi = false
      AND iptal = false
      AND gorev_tipi IN (
        'ILERI_GEBE', 'ILERI_GEBE_ASI', 'PADOK_DEGISIM',
        'BESLEME', 'TOHUMLAMA_HAZIRLIK', 'GEBELIK_KONTROL'
      );
    RETURN NEW;
  END IF;

  -- UPDATE: sonuc Boş veya Abort oldu → bu cycle görevleri iptal
  IF TG_OP = 'UPDATE'
     AND OLD.sonuc IN ('Bekliyor', 'Gebe')
     AND NEW.sonuc IN ('Boş', 'Abort') THEN
    UPDATE public.gorev_log
    SET iptal = true
    WHERE hayvan_id = NEW.hayvan_id
      AND tamamlandi = false
      AND iptal = false
      AND gorev_tipi IN (
        'ILERI_GEBE', 'ILERI_GEBE_ASI', 'PADOK_DEGISIM',
        'BESLEME', 'TOHUMLAMA_HAZIRLIK', 'GEBELIK_KONTROL'
      )
      AND (ref_tohumlama_id IS NULL OR ref_tohumlama_id = NEW.id::text);
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

-- ═══════════════════════════════════════════════════════════
-- 3. tohumlama_tekrar_kaydet RPC
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.tohumlama_tekrar_kaydet(
  p_hayvan_id   text,
  p_tarih       date,
  p_sperma      text,
  p_hekim_id    text DEFAULT NULL,
  p_irk_bilgisi text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan   record;
  v_toh      record;
  v_eski     jsonb;
  v_yeni_denemeler jsonb;
BEGIN
  -- Hayvan var mı?
  SELECT * INTO v_hayvan
  FROM public.hayvanlar
  WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id;
  END IF;

  -- İleri tarih kontrolü
  IF p_tarih > CURRENT_DATE THEN
    RAISE EXCEPTION 'Tarih ileri olamaz';
  END IF;

  -- Son 15 gün içinde Bekliyor tohumlama bul
  SELECT * INTO v_toh
  FROM public.tohumlama
  WHERE hayvan_id = p_hayvan_id
    AND sonuc = 'Bekliyor'
    AND tarih >= CURRENT_DATE - INTERVAL '15 days'
  ORDER BY tarih DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Son 15 gün içinde Bekliyor tohumlama bulunamadı';
  END IF;

  -- Mevcut denemeyi denemeler dizisine ekle
  v_eski := jsonb_build_object(
    'no',       v_toh.deneme_sayisi,
    'tarih',    v_toh.tarih,
    'sperma',   v_toh.sperma,
    'hekim_id', v_toh.hekim_id
  );
  v_yeni_denemeler := v_toh.denemeler || jsonb_build_array(v_eski);

  -- Tohumlama kaydını güncelle
  UPDATE public.tohumlama
  SET tarih         = p_tarih,
      sperma        = p_sperma,
      hekim_id      = COALESCE(p_hekim_id, hekim_id),
      irk_bilgisi   = COALESCE(p_irk_bilgisi, irk_bilgisi),
      deneme_sayisi = deneme_sayisi + 1,
      denemeler     = v_yeni_denemeler
  WHERE id = v_toh.id;

  -- Mevcut gebelik kontrol görevlerini iptal et
  UPDATE public.gorev_log
  SET iptal = true
  WHERE hayvan_id = p_hayvan_id
    AND tamamlandi = false
    AND iptal = false
    AND gorev_tipi IN ('TOHUMLAMA_HAZIRLIK', 'GEBELIK_KONTROL');

  -- Yeni görevler oluştur (yeni tarihten)
  INSERT INTO public.gorev_log
    (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, ref_tohumlama_id)
  VALUES
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '21. Gün gebelik kontrolü', p_tarih + 21, false, v_toh.id::text),
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '35. Gün gebelik kontrolü', p_tarih + 35, false, v_toh.id::text);

  -- Sperma stok düş
  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  SELECT
    s.id, 'Tohumlama', 1,
    'Tekrar Aşım ' || (v_toh.deneme_sayisi + 1) || '. deneme — ' ||
      COALESCE(v_hayvan.kupe_no, p_hayvan_id),
    false
  FROM public.stok s
  WHERE (s.urun_adi ILIKE '%' || p_sperma || '%' OR s.urun_adi = p_sperma)
    AND s.kategori = 'Sperma'
  LIMIT 1;

  RETURN jsonb_build_object(
    'ok',           true,
    'tohumlama_id', v_toh.id,
    'deneme_sayisi', v_toh.deneme_sayisi + 1
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.tohumlama_tekrar_kaydet(text, date, text, text, text)
  TO anon, authenticated;

COMMIT;
