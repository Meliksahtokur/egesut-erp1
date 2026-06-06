BEGIN;

-- Migration 10: gebelik_protokol_kontrol + besleme_tamam — BAKIM/BESLEME protokol_instance entegrasyonu
-- BESLEME görevleri artık:
--   kaynak = 'BESLEME-{hayvan_id}' (BESLEME_OTOMATIK yerine — backfill 000005 ile eski veriler zaten güncellendi)
--   protokol_instance_id = BAKIM/BESLEME instance id'si

-- ── 1. gebelik_protokol_kontrol REPLACE — BESLEME bloğuna protokol_instance ekle ──
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
  v_besleme_kaynak text;
  v_besleme_inst_id uuid;
BEGIN
  SELECT v.stock_item_id INTO v_stok_id
  FROM vaccines v WHERE v.name ILIKE '%Rota%' LIMIT 1;

  SELECT ad INTO v_padok_kuru FROM padoklar WHERE ad ILIKE '%Kuru%' LIMIT 1;

  FOR v_toh IN
    SELECT DISTINCT ON (t.hayvan_id) t.hayvan_id, t.tarih
    FROM tohumlama t
    JOIN hayvanlar h ON h.id = t.hayvan_id AND h.durum = 'Aktif'
    WHERE t.sonuc = 'Gebe'
    ORDER BY t.hayvan_id, t.tarih DESC
  LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_toh.hayvan_id;
    v_gun := CURRENT_DATE - v_toh.tarih::date;

    -- ── 210. gün: Kuru dönem transfer ──────────────────────────────
    IF v_gun >= 210
       AND v_hayvan.grup ILIKE '%Sağmal%'
       AND v_hayvan.grup NOT ILIKE '%Kuru%'
    THEN
      v_hedef := v_toh.tarih::date + 210;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, padok_hedef)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'PADOK_DEGISIM',
             '⚠️ Kuru döneme geçiş zamanı (' || v_gun || '. gün gebelik) — Kuru/Gebe padoğuna transfer',
             v_hedef, false, v_padok_kuru
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

    -- ── 240. gün: Rota-Corona 1. doz ───────────────────────────────
    IF v_gun >= 240 THEN
      v_hedef := v_toh.tarih::date + 240;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (1. doz)', v_hedef, false, v_stok_id, 1
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💉 Rota-Corona Aşısı (1. doz)'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- ── 261. gün: Rota-Corona 2. doz (düveler) ────────────────────
    IF v_gun >= 261 AND v_hayvan.grup ILIKE '%Düve%' THEN
      v_hedef := v_toh.tarih::date + 261;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (2. doz — düve)', v_hedef, false, v_stok_id, 1
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💉 Rota-Corona Aşısı (2. doz — düve)'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- ── 260. gün: SC Ademin ────────────────────────────────────────
    IF v_gun >= 260 THEN
      v_hedef := v_toh.tarih::date + 260;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 SC Ademin uygulaması', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 SC Ademin uygulaması'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- ── 265. gün: IM E Vitamini ────────────────────────────────────
    IF v_gun >= 265 THEN
      v_hedef := v_toh.tarih::date + 265;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 IM E Vitamini uygulaması', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 IM E Vitamini uygulaması'
          AND iptal = false
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- ── 260. gün: Anyonik Besleme — BAKIM/BESLEME instance ────────
    IF v_gun >= 260 THEN
      v_besleme_kaynak := 'BESLEME-' || v_toh.hayvan_id;

      -- Instance bul veya oluştur
      INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
      VALUES (v_toh.hayvan_id, 'BAKIM', 'BESLEME', v_besleme_kaynak, v_toh.tarih::date + 260, 'aktif')
      ON CONFLICT (kaynak_ref) DO NOTHING;

      SELECT id INTO v_besleme_inst_id
      FROM public.protokol_instance WHERE kaynak_ref = v_besleme_kaynak;

      -- SABAH
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, protokol_instance_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'BESLEME',
             '🌅 Anyonik Besleme (Sabah)', CURRENT_DATE, false, v_besleme_kaynak, v_besleme_inst_id
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

      -- AKŞAM
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, protokol_instance_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'BESLEME',
             '🌙 Anyonik Besleme (Akşam)', CURRENT_DATE, false, v_besleme_kaynak, v_besleme_inst_id
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

-- ── 2. besleme_tamam REPLACE — protokol_instance_id zincirleme ─────────────
CREATE OR REPLACE FUNCTION public.besleme_tamam(p_gorev_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev gorev_log%ROWTYPE;
  v_yeni_id uuid;
BEGIN
  SELECT * INTO v_gorev FROM gorev_log WHERE id = p_gorev_id::uuid;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev bulunamadı');
  END IF;
  IF v_gorev.tamamlandi OR v_gorev.iptal THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev zaten kapalı');
  END IF;

  UPDATE gorev_log
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE id = p_gorev_id::uuid;

  IF NOT EXISTS (
    SELECT 1 FROM tohumlama
    WHERE hayvan_id = v_gorev.hayvan_id AND sonuc = 'Gebe'
  ) THEN
    RETURN jsonb_build_object('ok', true, 'zincir', 'hayvan_artik_gebe_degil');
  END IF;

  -- Zincirleme: protokol_instance_id parent'tan miras alınır
  v_yeni_id := gen_random_uuid();
  INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih,
                         tamamlandi, kaynak, parent_id, protokol_instance_id)
  SELECT v_yeni_id, v_gorev.hayvan_id, 'BESLEME',
         v_gorev.aciklama,
         v_gorev.hedef_tarih + 1,
         false,
         COALESCE(v_gorev.kaynak, 'BESLEME-' || v_gorev.hayvan_id),
         v_gorev.id,
         v_gorev.protokol_instance_id
  WHERE NOT EXISTS (
    SELECT 1 FROM gorev_log
    WHERE hayvan_id = v_gorev.hayvan_id
      AND aciklama = v_gorev.aciklama
      AND hedef_tarih = v_gorev.hedef_tarih + 1
      AND iptal = false
  );

  RETURN jsonb_build_object('ok', true, 'yeni_gorev_id', v_yeni_id, 'tarih', v_gorev.hedef_tarih + 1);
END;
$$;

GRANT EXECUTE ON FUNCTION public.besleme_tamam(text) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
