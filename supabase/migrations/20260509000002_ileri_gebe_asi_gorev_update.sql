-- Migration: ileri_gebe_gorev_kontrol — ILERI_GEBE_ASI tipi + stok_id
-- Etkiler:
--   1. Mevcut tamamlanmamış 1. doz Rota-Corona görevlerini ILERI_GEBE_ASI + stok_id ile güncelle
--   2. ileri_gebe_gorev_kontrol RPC'yi aynı şekilde yeniden yaz
-- Geri alınabilir: evet

BEGIN;

-- 1. Mevcut tamamlanmamış 1. doz görevlerini güncelle
UPDATE gorev_log
SET
  gorev_tipi = 'ILERI_GEBE_ASI',
  stok_id    = (
    SELECT v.stock_item_id FROM vaccines v
    WHERE v.name ILIKE '%Rota%' LIMIT 1
  ),
  miktar     = 1
WHERE gorev_tipi = 'ILERI_GEBE'
  AND aciklama ILIKE '%Rota-Corona%1. doz%'
  AND tamamlandi = false;

-- 2. Mevcut tamamlanmamış 2. doz (düve) görevlerini güncelle
UPDATE gorev_log
SET
  gorev_tipi = 'ILERI_GEBE_ASI',
  stok_id    = (
    SELECT v.stock_item_id FROM vaccines v
    WHERE v.name ILIKE '%Rota%' LIMIT 1
  ),
  miktar     = 1
WHERE gorev_tipi = 'ILERI_GEBE'
  AND aciklama ILIKE '%Rota-Corona%2. doz%'
  AND tamamlandi = false;

-- 3. ileri_gebe_gorev_kontrol — ILERI_GEBE_ASI tipi + stok_id ile yeniden yaz
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
BEGIN
  -- Rota-Corona aşısının stock_item_id'sini bul
  SELECT v.stock_item_id INTO v_stok_id
  FROM vaccines v
  WHERE v.name ILIKE '%Rota%'
  LIMIT 1;

  FOR v_toh IN
    SELECT DISTINCT ON (t.hayvan_id) t.hayvan_id, t.tarih
    FROM tohumlama t
    JOIN hayvanlar h ON h.id = t.hayvan_id AND h.durum = 'Aktif'
    WHERE t.sonuc = 'Gebe'
    ORDER BY t.hayvan_id, t.tarih DESC
  LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_toh.hayvan_id;
    v_gun := CURRENT_DATE - v_toh.tarih::date;

    -- 240. gün: Rota-Corona 1. doz (tüm gebeler) — ILERI_GEBE_ASI tipi + stok_id
    IF v_gun >= 240 THEN
      v_hedef := v_toh.tarih::date + 240;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (1. doz)', v_hedef, false, v_stok_id, 1
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💉 Rota-Corona Aşısı (1. doz)'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 261. gün: Rota-Corona 2. doz (sadece düveler) — ILERI_GEBE_ASI tipi + stok_id
    IF v_gun >= 261 AND v_hayvan.grup ILIKE '%Düve%' THEN
      v_hedef := v_toh.tarih::date + 261;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (2. doz — düve)', v_hedef, false, v_stok_id, 1
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💉 Rota-Corona Aşısı (2. doz — düve)'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 260. gün: SC Ademin (tüm gebeler) — ILERI_GEBE tipi (ilaç, aşı değil)
    IF v_gun >= 260 THEN
      v_hedef := v_toh.tarih::date + 260;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 SC Ademin uygulaması', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 SC Ademin uygulaması'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    -- 265. gün: IM E Vitamini (tüm gebeler) — ILERI_GEBE tipi (ilaç, aşı değil)
    IF v_gun >= 265 THEN
      v_hedef := v_toh.tarih::date + 265;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE',
             '💊 IM E Vitamini uygulaması', v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_toh.hayvan_id
          AND aciklama = '💊 IM E Vitamini uygulaması'
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;
    END IF;

  END LOOP;

  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;

END;
