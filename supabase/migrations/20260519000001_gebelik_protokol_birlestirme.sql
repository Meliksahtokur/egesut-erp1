-- ============================================================
-- gebelik_protokol_birlestirme
-- ileri_gebe_gorev_kontrol + laktasyon_kuru_kontrol → gebelik_protokol_kontrol
-- ileri_gebe_view: dashboard için backend taraflı 210+ gün hesabı
-- ============================================================

BEGIN;

-- 1. Eski fonksiyonları kaldır
DROP FUNCTION IF EXISTS public.ileri_gebe_gorev_kontrol();
DROP FUNCTION IF EXISTS public.laktasyon_kuru_kontrol();

-- 2. Birleşik RPC
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
  -- Rota-Corona aşı stok_id'sini bul
  SELECT v.stock_item_id INTO v_stok_id
  FROM vaccines v WHERE v.name ILIKE '%Rota%' LIMIT 1;

  -- Kuru/Gebe padok adını bul
  SELECT ad INTO v_padok_kuru FROM padoklar WHERE ad ILIKE '%Kuru%' LIMIT 1;

  -- Tüm aktif gebe inekler — her hayvanın en son Gebe tohumlaması
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
    -- Sadece hâlâ Sağmal grubunda olan ineklere (Kuru'ya taşınmamışsa)
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

    -- ── 240. gün: Rota-Corona 1. doz (tüm gebeler) ─────────────────
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

    -- ── 261. gün: Rota-Corona 2. doz (sadece düveler) ──────────────
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

    -- ── 260. gün: SC Ademin (tüm gebeler) ──────────────────────────
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

    -- ── 265. gün: IM E Vitamini (tüm gebeler) ──────────────────────
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

  END LOOP;

  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;

GRANT EXECUTE ON FUNCTION public.gebelik_protokol_kontrol() TO anon, authenticated;

-- 3. ileri_gebe_view — dashboard için 210+ günlük gebe inekler
CREATE OR REPLACE VIEW public.ileri_gebe_view AS
SELECT
  t.hayvan_id,
  t.tarih,
  t.tarih AS tohumlama_tarihi,
  (CURRENT_DATE - t.tarih::date)::int AS gebelik_gun,
  h.kupe_no,
  h.devlet_kupe,
  h.grup,
  h.padok
FROM tohumlama t
JOIN hayvanlar h ON h.id = t.hayvan_id
WHERE t.sonuc = 'Gebe'
  AND h.durum = 'Aktif'
  AND CURRENT_DATE - t.tarih::date >= 210
  AND t.tarih = (
    SELECT MAX(t2.tarih)
    FROM tohumlama t2
    WHERE t2.hayvan_id = t.hayvan_id AND t2.sonuc = 'Gebe'
  )
ORDER BY gebelik_gun DESC;

GRANT SELECT ON public.ileri_gebe_view TO anon, authenticated;

COMMIT;
