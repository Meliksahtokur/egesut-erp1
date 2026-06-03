-- Migration: Protokol Uyarı Sistemi — DB Altyapı (Task 1-5)
-- Etkiler: gorev_log'a etken_kod + kapatan_ref kolonları, _etken_kod_bul helper,
--   _gorev_dinle mekanizması, backfill, dogum_kaydet ve fn_gebe_gorev_yarat güncelleme
-- Geri alınabilir: ALTER TABLE DROP COLUMN IF EXISTS, DROP FUNCTION IF EXISTS

BEGIN;

-- ============================================================
-- Task 1: gorev_log Kolon Ekleme
-- ============================================================

ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS etken_kod text;
ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS kapatan_ref text;

CREATE INDEX IF NOT EXISTS idx_gorev_log_etken ON public.gorev_log(hayvan_id, etken_kod)
  WHERE tamamlandi = false AND iptal = false AND etken_kod IS NOT NULL;

COMMENT ON COLUMN public.gorev_log.etken_kod IS 'Görevin beklediği etken madde kodu (OKSITOSIN, PG, E_VIT, ADEMIN, KALSIYUM, ROTA)';
COMMENT ON COLUMN public.gorev_log.kapatan_ref IS 'Görevi kapatan kaydın referansı (ör: uygulama_log:uuid, vaccination_log:uuid)';

-- ============================================================
-- Task 2: _etken_kod_bul Helper Fonksiyonu
-- ============================================================

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

    SELECT dc.group_name, dc.class_name, dc.active_ingredient
    INTO v_group_name, v_class_name, v_active_ing
    FROM public.drug_products dp
    JOIN public.drug_classes dc ON dc.id = dp.drug_class_id
    WHERE dp.id = (
      SELECT drug_product_id FROM public.drug_administrations
      WHERE stok_id = p_stok_id LIMIT 1
    )
    OR dp.brand_name ILIKE '%' || COALESCE(v_stok_ad,'') || '%'
    LIMIT 1;

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

-- ============================================================
-- Task 3: _gorev_dinle Fonksiyonu
-- ============================================================

CREATE OR REPLACE FUNCTION public._gorev_dinle(
  p_hayvan_id text,
  p_etken_kod text,
  p_ref text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev_id text;
BEGIN
  IF p_etken_kod IS NULL OR p_hayvan_id IS NULL THEN
    RETURN;
  END IF;

  SELECT id INTO v_gorev_id
  FROM public.gorev_log
  WHERE hayvan_id = p_hayvan_id
    AND etken_kod = p_etken_kod
    AND tamamlandi = false
    AND iptal = false
  ORDER BY hedef_tarih ASC
  LIMIT 1;

  IF v_gorev_id IS NOT NULL THEN
    UPDATE public.gorev_log
    SET tamamlandi = true,
        tamamlanma_tarihi = now(),
        kapatan_ref = p_ref
    WHERE id = v_gorev_id;
  END IF;
END;
$$;

-- ============================================================
-- Task 4: Mevcut Görevlere etken_kod Backfill
-- ============================================================

UPDATE public.gorev_log SET etken_kod = 'OKSITOSIN'
WHERE etken_kod IS NULL AND tamamlandi = false AND iptal = false
  AND aciklama ILIKE '%Oksitosin%';

UPDATE public.gorev_log SET etken_kod = 'PG'
WHERE etken_kod IS NULL AND tamamlandi = false AND iptal = false
  AND aciklama ILIKE '%PG%'
  AND aciklama NOT ILIKE '%Ademin%';

UPDATE public.gorev_log SET etken_kod = 'ADEMIN'
WHERE etken_kod IS NULL AND tamamlandi = false AND iptal = false
  AND (aciklama ILIKE '%Ademin%' AND aciklama NOT ILIKE '%Yeldif%' AND aciklama NOT ILIKE '%E Vit%');

UPDATE public.gorev_log SET etken_kod = 'E_VIT'
WHERE etken_kod IS NULL AND tamamlandi = false AND iptal = false
  AND (aciklama ILIKE '%Yeldif%' OR aciklama ILIKE '%E Vit%');

UPDATE public.gorev_log SET etken_kod = 'KALSIYUM'
WHERE etken_kod IS NULL AND tamamlandi = false AND iptal = false
  AND aciklama ILIKE '%Kalsiyum%';

UPDATE public.gorev_log SET etken_kod = 'ROTA'
WHERE etken_kod IS NULL AND tamamlandi = false AND iptal = false
  AND aciklama ILIKE '%Rota%';

-- ============================================================
-- Task 5: dogum_kaydet + fn_gebe_gorev_yarat Güncelleme
-- ============================================================

CREATE OR REPLACE FUNCTION public.dogum_kaydet(
  p_anne_id    text,
  p_tarih      date,
  p_kupe       text,
  p_cins       text    DEFAULT 'Dişi',
  p_tip        text    DEFAULT 'Normal',
  p_kg         numeric DEFAULT NULL,
  p_baba       text    DEFAULT NULL,
  p_hekim_id   text    DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_anne        record;
  v_dogum_id    uuid := gen_random_uuid();
  v_buzagi_id   text;
  v_ana_gorev   uuid := gen_random_uuid();
  v_sayac       integer;
  v_dup         text;
  v_baba_bilgi  text;
BEGIN
  SELECT * INTO v_anne FROM public.hayvanlar WHERE id = p_anne_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Anne bulunamadı');
  END IF;

  SELECT id INTO v_dup FROM public.hayvanlar WHERE kupe_no = p_kupe OR devlet_kupe = p_kupe LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu küpe zaten kayıtlı: ' || p_kupe);
  END IF;

  IF p_baba IS NULL OR p_baba = '' THEN
    SELECT sperma INTO v_baba_bilgi
    FROM public.tohumlama
    WHERE hayvan_id = p_anne_id AND sonuc = 'Gebe'
    ORDER BY tarih DESC LIMIT 1;
  ELSE
    v_baba_bilgi := p_baba;
  END IF;

  INSERT INTO public.dogum (id, anne_id, tarih, yavru_cins, yavru_kupe, yavru_irk, dogum_tipi, hekim_id, dogum_kg, baba_bilgi)
  VALUES (v_dogum_id, p_anne_id, p_tarih, p_cins, p_kupe, v_anne.irk, p_tip, p_hekim_id, p_kg, v_baba_bilgi);

  SELECT 'H' || LPAD((COUNT(*)+1)::text, 6, '0') INTO v_buzagi_id FROM public.hayvanlar;

  INSERT INTO public.hayvanlar (id, kupe_no, irk, dogum_tarihi, anne_id, baba_bilgi, cinsiyet, grup, padok, durum, dogum_kg)
  VALUES (v_buzagi_id, p_kupe, v_anne.irk, p_tarih, p_anne_id, v_baba_bilgi, p_cins,
          'Süt İçen Buzağı', 'Buzağı Padok (Süt İçenler)', 'Aktif', p_kg);

  UPDATE public.hayvanlar
  SET grup = 'Sağmal (Laktasyonda)', padok = 'Sağmal Padok'
  WHERE id = p_anne_id;

  -- Anne protokol görevleri (9 görev — etken_kod ile)
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod)
  VALUES
    (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Oksitosin', p_tarih, false, 'DOGUM-' || p_anne_id, 'OKSITOSIN'),
    (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Ademin',    p_tarih, false, 'DOGUM-' || p_anne_id, 'ADEMIN'),
    (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Kalsiyum',  p_tarih, false, 'DOGUM-' || p_anne_id, 'KALSIYUM'),
    (gen_random_uuid(), p_anne_id, 'ILAC', '2. Gün PG',             p_tarih + 2,  false, 'DOGUM-' || p_anne_id, 'PG'),
    (gen_random_uuid(), p_anne_id, 'ILAC', '11. Gün PG',            p_tarih + 11, false, 'DOGUM-' || p_anne_id, 'PG'),
    (gen_random_uuid(), p_anne_id, 'ILAC', '25. Gün PG',            p_tarih + 25, false, 'DOGUM-' || p_anne_id, 'PG'),
    (gen_random_uuid(), p_anne_id, 'ILAC', '53. Gün: Ademin',       p_tarih + 53, false, 'DOGUM-' || p_anne_id, 'ADEMIN'),
    (gen_random_uuid(), p_anne_id, 'ILAC', '54. Gün: Yeldif',       p_tarih + 54, false, 'DOGUM-' || p_anne_id, 'E_VIT'),
    (gen_random_uuid(), p_anne_id, 'DIGER', '⚡ 58-63. gün kızgınlık takibi', p_tarih + 58, false, 'DOGUM-' || p_anne_id, NULL);

  -- Buzağı ana görev
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak)
  VALUES (v_ana_gorev, v_buzagi_id, 'BUZAGI_BAKIM', 'Buzağı İlk Gün Bakımı (' || p_kupe || ')', p_tarih, false, 'DOGUM-' || p_anne_id);

  -- Buzağı alt görevler (6 görev)
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, parent_id, kaynak)
  VALUES
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Kolostrum ver (doğumdan sonra ilk 2 saat)', p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Göbek kordonu dezenfeksiyonu (iyot)',        p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Küpeleme',                                   p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Ademin uygula (1. gün)',                      p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Maya ver (1. gün)',                           p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Probiyotik ver (1. gün)',                     p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id);

  UPDATE public.tohumlama
  SET sonuc = 'Doğum Yaptı', dogum_tarihi = p_tarih, buzagi_kupe = p_kupe
  WHERE hayvan_id = p_anne_id AND sonuc = 'Gebe';

  GET DIAGNOSTICS v_sayac = ROW_COUNT;

  RETURN jsonb_build_object(
    'ok', true,
    'buzagi_id', v_buzagi_id,
    'dogum_id', v_dogum_id,
    'gorev_sayisi', 16,
    'tohumlama_kapatildi', v_sayac
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- fn_gebe_gorev_yarat — etken_kod eklenmiş versiyon
CREATE OR REPLACE FUNCTION public.fn_gebe_gorev_yarat()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok_id text;
BEGIN
  IF NEW.sonuc != 'Gebe' OR OLD.sonuc = 'Gebe' THEN
    RETURN NEW;
  END IF;

  SELECT stock_item_id INTO v_stok_id FROM vaccines WHERE name ILIKE '%Rota%' LIMIT 1;

  INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, kaynak, etken_kod)
  SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE_ASI',
         '💉 Rota-Corona Aşısı (1. doz)', NEW.tarih::date + 240, false, v_stok_id, 1, 'ILERI_GEBE', 'ROTA'
  WHERE NOT EXISTS (
    SELECT 1 FROM gorev_log
    WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💉 Rota-Corona Aşısı (1. doz)' AND tamamlandi = false
  );

  INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod)
  SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE',
         '💊 SC Ademin uygulaması', NEW.tarih::date + 260, false, 'ILERI_GEBE', 'ADEMIN'
  WHERE NOT EXISTS (
    SELECT 1 FROM gorev_log
    WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💊 SC Ademin uygulaması' AND tamamlandi = false
  );

  INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod)
  SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE',
         '💊 IM E Vitamini uygulaması', NEW.tarih::date + 265, false, 'ILERI_GEBE', 'E_VIT'
  WHERE NOT EXISTS (
    SELECT 1 FROM gorev_log
    WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💊 IM E Vitamini uygulaması' AND tamamlandi = false
  );

  RETURN NEW;
END;
$$;

COMMIT;
