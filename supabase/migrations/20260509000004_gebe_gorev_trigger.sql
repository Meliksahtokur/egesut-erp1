-- Migration: DB trigger — tohumlama Gebe olunca tüm ileri gebe görevleri yarat
-- Etkiler:
--   1. fn_gebe_gorev_yarat(): tohumlama.sonuc Gebe olunca 4 görev yarat (240/260/261/265. gün)
--   2. trg_tohumlama_gebe_gorev: AFTER UPDATE ON tohumlama trigger
--   3. Catch-up: halihazırda gebe tüm hayvanlar için görev yarat
-- Geri alınabilir: DROP TRIGGER trg_tohumlama_gebe_gorev ON tohumlama; DROP FUNCTION fn_gebe_gorev_yarat();

BEGIN;

CREATE OR REPLACE FUNCTION public.fn_gebe_gorev_yarat()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan  record;
  v_stok_id text;
BEGIN
  -- Sadece 'Gebe' olarak değiştiğinde çalış
  IF NEW.sonuc != 'Gebe' OR OLD.sonuc = 'Gebe' THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_hayvan FROM hayvanlar WHERE id = NEW.hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN RETURN NEW; END IF;

  SELECT stock_item_id INTO v_stok_id FROM vaccines WHERE name ILIKE '%Rota%' LIMIT 1;

  -- 240. gün: Rota-Corona 1. doz (tüm gebeler)
  INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, kaynak)
  SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE_ASI',
         '💉 Rota-Corona Aşısı (1. doz)', NEW.tarih::date + 240, false, v_stok_id, 1, 'ILERI_GEBE'
  WHERE NOT EXISTS (
    SELECT 1 FROM gorev_log
    WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💉 Rota-Corona Aşısı (1. doz)' AND tamamlandi = false
  );

  -- 261. gün: Rota-Corona 2. doz — sadece düveler
  IF v_hayvan.grup ILIKE '%Düve%' THEN
    INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, kaynak)
    SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE_ASI',
           '💉 Rota-Corona Aşısı (2. doz — düve)', NEW.tarih::date + 261, false, v_stok_id, 1, 'ILERI_GEBE'
    WHERE NOT EXISTS (
      SELECT 1 FROM gorev_log
      WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💉 Rota-Corona Aşısı (2. doz — düve)' AND tamamlandi = false
    );
  END IF;

  -- 260. gün: SC Ademin
  INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak)
  SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE',
         '💊 SC Ademin uygulaması', NEW.tarih::date + 260, false, 'ILERI_GEBE'
  WHERE NOT EXISTS (
    SELECT 1 FROM gorev_log
    WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💊 SC Ademin uygulaması' AND tamamlandi = false
  );

  -- 265. gün: IM E Vitamini
  INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak)
  SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE',
         '💊 IM E Vitamini uygulaması', NEW.tarih::date + 265, false, 'ILERI_GEBE'
  WHERE NOT EXISTS (
    SELECT 1 FROM gorev_log
    WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💊 IM E Vitamini uygulaması' AND tamamlandi = false
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tohumlama_gebe_gorev ON tohumlama;
CREATE TRIGGER trg_tohumlama_gebe_gorev
  AFTER UPDATE ON tohumlama
  FOR EACH ROW EXECUTE FUNCTION public.fn_gebe_gorev_yarat();

END;
