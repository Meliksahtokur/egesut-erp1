-- Migration: Tohumlama Cycle State Machine — görev iptal mekanizması
-- Etkiler:
--   1. gorev_log.ref_tohumlama_id kolonu + index
--   2. tohumlama_cycle_iptal_trigger — cycle geçişinde görev iptali
--   3. gorev_log_cycle_guard_trigger — stale cycle koruması
--   4. gebelik_protokol_kontrol + tohumlama_kaydet ref_tohumlama_id set
--   5. Stale görev temizliği
-- Geri alınabilir:
--   DROP TRIGGER IF EXISTS tohumlama_cycle_iptal_trigger ON public.tohumlama;
--   DROP FUNCTION IF EXISTS public.tohumlama_cycle_gorevcil_iptal();
--   DROP TRIGGER IF EXISTS gorev_log_cycle_guard_trigger ON public.gorev_log;
--   DROP FUNCTION IF EXISTS public.gorev_log_cycle_guard();
--   ALTER TABLE public.gorev_log DROP COLUMN IF EXISTS ref_tohumlama_id;
--   gebelik_protokol_kontrol → migration 20260521000005 versiyonuna dön
--   tohumlama_kaydet → migration 99999999999999_ground_truth versiyonuna dön

BEGIN;

-- ═══════════════════════════════════════════════════════════
-- 1. gorev_log.ref_tohumlama_id kolonu + index
-- ═══════════════════════════════════════════════════════════
ALTER TABLE public.gorev_log
  ADD COLUMN IF NOT EXISTS ref_tohumlama_id text;

CREATE INDEX IF NOT EXISTS idx_gorev_log_ref_tohumlama
  ON public.gorev_log(ref_tohumlama_id)
  WHERE ref_tohumlama_id IS NOT NULL;

-- ═══════════════════════════════════════════════════════════
-- 2. Tohumlama cycle geçişinde görev iptali
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
        'BESLEME', 'TOHUMLAMA_HAZIRLIK'
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
        'BESLEME', 'TOHUMLAMA_HAZIRLIK'
      )
      AND (ref_tohumlama_id IS NULL OR ref_tohumlama_id = NEW.id::text);
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tohumlama_cycle_iptal_trigger ON public.tohumlama;
CREATE TRIGGER tohumlama_cycle_iptal_trigger
  AFTER INSERT OR UPDATE OF sonuc ON public.tohumlama
  FOR EACH ROW EXECUTE FUNCTION public.tohumlama_cycle_gorevcil_iptal();

-- ═══════════════════════════════════════════════════════════
-- 3. gorev_log INSERT guard — stale cycle koruması
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.gorev_log_cycle_guard()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.ref_tohumlama_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.tohumlama
      WHERE id::text = NEW.ref_tohumlama_id
        AND sonuc IN ('Bekliyor', 'Gebe')
    ) THEN
      NEW.iptal := true;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS gorev_log_cycle_guard_trigger ON public.gorev_log;
CREATE TRIGGER gorev_log_cycle_guard_trigger
  BEFORE INSERT ON public.gorev_log
  FOR EACH ROW EXECUTE FUNCTION public.gorev_log_cycle_guard();

-- ═══════════════════════════════════════════════════════════
-- 4. gebelik_protokol_kontrol REPLACE — ref_tohumlama_id set
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.gebelik_protokol_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_toh         record;
  v_hayvan      record;
  v_gun         int;
  v_hedef       date;
  v_padok_kuru  text;
  v_stok_id     text;
BEGIN
  SELECT v.stock_item_id INTO v_stok_id
  FROM vaccines v WHERE v.name ILIKE '%Rota%' LIMIT 1;

  SELECT ad INTO v_padok_kuru FROM padoklar WHERE ad ILIKE '%Kuru%' LIMIT 1;

  FOR v_toh IN
    SELECT DISTINCT ON (t.hayvan_id) t.hayvan_id, t.tarih, t.id
    FROM tohumlama t
    JOIN hayvanlar h ON h.id = t.hayvan_id AND h.durum = 'Aktif'
    WHERE t.sonuc = 'Gebe'
    ORDER BY t.hayvan_id, t.tarih DESC
  LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_toh.hayvan_id;
    v_gun := CURRENT_DATE - v_toh.tarih::date;

    IF v_gun >= 210
       AND v_hayvan.grup ILIKE '%Sağmal%'
       AND v_hayvan.grup NOT ILIKE '%Kuru%'
    THEN
      v_hedef := v_toh.tarih::date + 210;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, padok_hedef, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'PADOK_DEGISIM',
             '⚠️ Kuru döneme geçiş zamanı (' || v_gun || '. gün gebelik) — Kuru/Gebe padoğuna transfer',
             v_hedef, false, v_padok_kuru, v_toh.id::text
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND gorev_tipi = 'PADOK_DEGISIM'
          AND aciklama ILIKE '%Kuru döneme%'
          AND iptal = false
          AND (NOT tamamlandi OR tamamlanma_tarihi > now() - interval '24 hours')
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    IF v_gun >= 240 THEN
      v_hedef := v_toh.tarih::date + 240;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (1. doz)', v_hedef, false, v_stok_id, 1, v_toh.id::text
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💉 Rota-Corona Aşısı (1. doz)'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    IF v_gun >= 261 AND v_hayvan.grup ILIKE '%Düve%' THEN
      v_hedef := v_toh.tarih::date + 261;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (2. doz — düve)', v_hedef, false, v_stok_id, 1, v_toh.id::text
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💉 Rota-Corona Aşısı (2. doz — düve)'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    IF v_gun >= 260 THEN
      v_hedef := v_toh.tarih::date + 260;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 SC Ademin uygulaması', v_hedef, false, v_toh.id::text
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 SC Ademin uygulaması'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    IF v_gun >= 265 THEN
      v_hedef := v_toh.tarih::date + 265;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 IM E Vitamini uygulaması', v_hedef, false, v_toh.id::text
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 IM E Vitamini uygulaması'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    IF v_gun >= 260 THEN
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'BESLEME',
             '🌅 Anyonik Besleme (Sabah)', CURRENT_DATE, false, 'BESLEME_OTOMATIK', v_toh.id::text
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND gorev_tipi = 'BESLEME'
          AND aciklama = '🌅 Anyonik Besleme (Sabah)'
          AND hedef_tarih = CURRENT_DATE
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;

      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'BESLEME',
             '🌙 Anyonik Besleme (Akşam)', CURRENT_DATE, false, 'BESLEME_OTOMATIK', v_toh.id::text
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND gorev_tipi = 'BESLEME'
          AND aciklama = '🌙 Anyonik Besleme (Akşam)'
          AND hedef_tarih = CURRENT_DATE
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'olusturulan', v_olusturulan,
    'hayvanlar', (
      SELECT jsonb_agg(
        jsonb_build_object(
          'hayvan_id',    t.hayvan_id,
          'tarih',        t.tarih::text,
          'gebelik_gun',  CURRENT_DATE - t.tarih::date,
          'kupe_no',      h.kupe_no,
          'devlet_kupe',  h.devlet_kupe,
          'grup',         h.grup,
          'padok',        h.padok
        )
        ORDER BY CURRENT_DATE - t.tarih::date DESC
      )
      FROM tohumlama t
      JOIN hayvanlar h ON h.id = t.hayvan_id
      WHERE t.sonuc = 'Gebe'
        AND h.durum = 'Aktif'
        AND CURRENT_DATE - t.tarih::date >= 210
        AND t.tarih = (
          SELECT MAX(t2.tarih) FROM tohumlama t2
          WHERE t2.hayvan_id = t.hayvan_id AND t2.sonuc = 'Gebe'
        )
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.gebelik_protokol_kontrol() TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════
-- 5. tohumlama_kaydet REPLACE — ref_tohumlama_id set
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.tohumlama_kaydet(
  p_hayvan_id   text,
  p_tarih       date,
  p_sperma      text,
  p_hekim_id    text  DEFAULT NULL,
  p_irk_bilgisi text  DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan   record;
  v_yas_gun  integer;
  v_deneme   integer;
  v_toh_id   uuid := gen_random_uuid();
BEGIN
  SELECT * INTO v_hayvan
  FROM public.hayvanlar
  WHERE id = p_hayvan_id AND durum = 'Aktif';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id;
  END IF;

  IF v_hayvan.cinsiyet = 'Erkek' THEN
    RAISE EXCEPTION 'Erkek hayvana tohumlama yapılamaz';
  END IF;

  IF v_hayvan.dogum_tarihi IS NOT NULL THEN
    v_yas_gun := CURRENT_DATE - v_hayvan.dogum_tarihi;
    IF v_yas_gun < 365 THEN
      RAISE EXCEPTION '12 aydan küçük hayvana tohumlama yapılamaz (% gün)', v_yas_gun;
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.tohumlama
    WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe'
  ) THEN
    RAISE EXCEPTION 'Hayvan zaten gebe — önce gebeliği kapatın';
  END IF;

  IF p_tarih > CURRENT_DATE THEN
    RAISE EXCEPTION 'Tohumlama tarihi ileri tarih olamaz';
  END IF;

  SELECT COALESCE(MAX(deneme_no), 0) + 1 INTO v_deneme
  FROM public.tohumlama
  WHERE hayvan_id = p_hayvan_id;

  INSERT INTO public.tohumlama
    (id, hayvan_id, tarih, sperma, irk_bilgisi, hekim_id, sonuc, deneme_no)
  VALUES
    (v_toh_id, p_hayvan_id, p_tarih, p_sperma, p_irk_bilgisi, p_hekim_id, 'Bekliyor', v_deneme);

  INSERT INTO public.gorev_log
    (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, ref_tohumlama_id)
  VALUES
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '21. Gün gebelik kontrolü', p_tarih + 21, false, v_toh_id::text),
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '35. Gün gebelik kontrolü', p_tarih + 35, false, v_toh_id::text);

  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  SELECT
    s.id, 'Tohumlama', 1,
    'Tohumlama — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
    false
  FROM public.stok s
  WHERE (s.urun_adi ILIKE '%' || p_sperma || '%' OR s.urun_adi = p_sperma)
    AND s.kategori = 'Sperma'
  LIMIT 1;

  RETURN jsonb_build_object(
    'ok',           true,
    'tohumlama_id', v_toh_id,
    'deneme_no',    v_deneme
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.tohumlama_kaydet(text, date, text, text, text) TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════
-- 6. Stale görev temizliği (tek seferlik) — kontrol edildi
-- ═══════════════════════════════════════════════════════════
-- 2026-05-22: 0 stale görev bulundu (tüm ILERI_GEBE/ILERI_GEBE_ASI/PADOK_DEGISIM/BESLEME
-- görevleri aktif gebeliği olan hayvanlara ait). Temizlik gerekmedi.
-- SELECT COUNT(*) FROM public.gorev_log
-- WHERE tamamlandi=false AND iptal=false
--   AND gorev_tipi IN ('ILERI_GEBE','ILERI_GEBE_ASI','PADOK_DEGISIM','BESLEME')
--   AND NOT EXISTS (
--     SELECT 1 FROM public.tohumlama
--     WHERE tohumlama.hayvan_id = gorev_log.hayvan_id
--       AND tohumlama.sonuc = 'Gebe'
--   );  → 0

COMMIT;
