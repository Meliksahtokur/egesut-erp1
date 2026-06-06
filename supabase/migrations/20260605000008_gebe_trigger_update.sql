BEGIN;

-- ── 1. fn_gebe_gorev_yarat trigger — kaynak + protokol_instance_id ekle ──
CREATE OR REPLACE FUNCTION public.fn_gebe_gorev_yarat()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok_id text;
  v_kaynak  text;
  v_inst_id uuid;
BEGIN
  IF NEW.sonuc != 'Gebe' OR OLD.sonuc = 'Gebe' THEN
    RETURN NEW;
  END IF;

  SELECT stock_item_id INTO v_stok_id FROM vaccines WHERE name ILIKE '%Rota%' LIMIT 1;

  v_kaynak := 'ILERI_GEBE-' || NEW.hayvan_id;

  -- Instance aç veya güncelle (hayvan tekrar gebe olabilir)
  INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
  VALUES (NEW.hayvan_id, 'UREME', 'GEBELIK', v_kaynak, NEW.tarih::date, 'aktif')
  ON CONFLICT (kaynak_ref) DO UPDATE
    SET durum = 'aktif', kapandi_at = NULL, kapandi_sebep = NULL
  RETURNING id INTO v_inst_id;

  -- RETURNING DO UPDATE durumunda NULL döner — ayrıca çek
  IF v_inst_id IS NULL THEN
    SELECT id INTO v_inst_id FROM public.protokol_instance WHERE kaynak_ref = v_kaynak;
  END IF;

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, kaynak, etken_kod, protokol_instance_id)
  SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE_ASI',
         '💉 Rota-Corona Aşısı (1. doz)', NEW.tarih::date + 240, false, v_stok_id, 1, v_kaynak, 'ROTA', v_inst_id
  WHERE NOT EXISTS (
    SELECT 1 FROM public.gorev_log
    WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💉 Rota-Corona Aşısı (1. doz)' AND tamamlandi = false
  );

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod, protokol_instance_id)
  SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE',
         '💊 SC Ademin uygulaması', NEW.tarih::date + 260, false, v_kaynak, 'ADEMIN', v_inst_id
  WHERE NOT EXISTS (
    SELECT 1 FROM public.gorev_log
    WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💊 SC Ademin uygulaması' AND tamamlandi = false
  );

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod, protokol_instance_id)
  SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE',
         '💊 IM E Vitamini uygulaması', NEW.tarih::date + 265, false, v_kaynak, 'E_VIT', v_inst_id
  WHERE NOT EXISTS (
    SELECT 1 FROM public.gorev_log
    WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💊 IM E Vitamini uygulaması' AND tamamlandi = false
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tohumlama_gebe_gorev ON tohumlama;
CREATE TRIGGER trg_tohumlama_gebe_gorev
  AFTER UPDATE ON tohumlama
  FOR EACH ROW EXECUTE FUNCTION public.fn_gebe_gorev_yarat();

-- ── 2. ileri_gebe_gorev_kontrol — kaynak + protokol_instance_id ekle ──
CREATE OR REPLACE FUNCTION public.ileri_gebe_gorev_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_toh         record;
  v_hayvan      record;
  v_gun         int;
  v_hedef       date;
  v_stok_id     text;
  v_kaynak      text;
  v_inst_id     uuid;
BEGIN
  SELECT v.stock_item_id INTO v_stok_id FROM vaccines v WHERE v.name ILIKE '%Rota%' LIMIT 1;

  FOR v_toh IN
    SELECT DISTINCT ON (t.hayvan_id) t.hayvan_id, t.tarih
    FROM tohumlama t
    JOIN hayvanlar h ON h.id = t.hayvan_id AND h.durum = 'Aktif'
    WHERE t.sonuc = 'Gebe'
    ORDER BY t.hayvan_id, t.tarih DESC
  LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_toh.hayvan_id;
    v_gun    := CURRENT_DATE - v_toh.tarih::date;
    v_kaynak := 'ILERI_GEBE-' || v_toh.hayvan_id;

    -- Instance bul veya oluştur
    INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
    VALUES (v_toh.hayvan_id, 'UREME', 'GEBELIK', v_kaynak, v_toh.tarih::date, 'aktif')
    ON CONFLICT (kaynak_ref) DO NOTHING;

    SELECT id INTO v_inst_id FROM public.protokol_instance WHERE kaynak_ref = v_kaynak;

    -- 240. gün: Rota-Corona 1. doz
    IF v_gun >= 240 THEN
      v_hedef := v_toh.tarih::date + 240;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, kaynak, protokol_instance_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (1. doz)', v_hedef, false, v_stok_id, 1, v_kaynak, v_inst_id
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id AND aciklama = '💉 Rota-Corona Aşısı (1. doz)'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 261. gün: Rota-Corona 2. doz (düveler)
    IF v_gun >= 261 AND v_hayvan.grup ILIKE '%Düve%' THEN
      v_hedef := v_toh.tarih::date + 261;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, kaynak, protokol_instance_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (2. doz — düve)', v_hedef, false, v_stok_id, 1, v_kaynak, v_inst_id
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id AND aciklama = '💉 Rota-Corona Aşısı (2. doz — düve)'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 260. gün: SC Ademin
    IF v_gun >= 260 THEN
      v_hedef := v_toh.tarih::date + 260;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, protokol_instance_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 SC Ademin uygulaması', v_hedef, false, v_kaynak, v_inst_id
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log WHERE hayvan_id = v_toh.hayvan_id AND aciklama = '💊 SC Ademin uygulaması'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 265. gün: E Vitamini
    IF v_gun >= 265 THEN
      v_hedef := v_toh.tarih::date + 265;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, protokol_instance_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 IM E Vitamini uygulaması', v_hedef, false, v_kaynak, v_inst_id
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log WHERE hayvan_id = v_toh.hayvan_id AND aciklama = '💊 IM E Vitamini uygulaması'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

  END LOOP;

  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;

GRANT EXECUTE ON FUNCTION public.ileri_gebe_gorev_kontrol() TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
