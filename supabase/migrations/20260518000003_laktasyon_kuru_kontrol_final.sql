-- laktasyon_kuru_kontrol — final doğru versiyon
-- Kural: Sadece GEBELİĞİ ONAYLANMIŞ (tohumlama.sonuc='Gebe') VE
--        son doğumundan 210+ gün geçmiş sağmal ineklere kuru dönem görevi aç
-- Referans: ground_truth.sql #laktasyon_kuru_kontrol bölümü

CREATE OR REPLACE FUNCTION public.laktasyon_kuru_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_rec         record;
  v_gun         int;
  v_id          uuid;
BEGIN
  -- Kriter:
  --   1) Aktif sağmal (Kuru dönemde değil)
  --   2) Gebeliği onaylanmış (tohumlama.sonuc = 'Gebe')
  --   3) Son doğumundan 210+ gün geçmiş
  FOR v_rec IN
    SELECT h.id, h.kupe_no, h.grup, h.padok,
           MAX(d.tarih) AS son_dogum_tarihi
    FROM hayvanlar h
    JOIN dogum d ON d.anne_id = h.id
    WHERE h.durum = 'Aktif'
      AND h.grup ILIKE '%Sağmal%'
      AND h.grup NOT ILIKE '%Kuru%'
      AND EXISTS (
        SELECT 1 FROM tohumlama t
        WHERE t.hayvan_id = h.id
          AND t.sonuc = 'Gebe'
      )
    GROUP BY h.id, h.kupe_no, h.grup, h.padok
    HAVING CURRENT_DATE - MAX(d.tarih) >= 210
  LOOP
    v_gun := CURRENT_DATE - v_rec.son_dogum_tarihi;
    v_id  := gen_random_uuid();

    -- Dedup: Son 24 saatte tamamlanan veya hâlâ açık kuru dönem görevi varsa ekleme
    INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, padok_hedef)
    SELECT v_id, v_rec.id, 'PADOK_DEGISIM',
           '⚠️ Kuru döneme geçiş zamanı (' || v_gun || '. gün laktasyon) — Kuru/Gebe padoğuna transfer',
           CURRENT_DATE, false,
           (SELECT ad FROM padoklar WHERE ad ILIKE '%Kuru%' LIMIT 1)
    WHERE NOT EXISTS (
      SELECT 1 FROM gorev_log
      WHERE hayvan_id = v_rec.id
        AND gorev_tipi = 'PADOK_DEGISIM'
        AND aciklama ILIKE '%Kuru döneme%'
        AND iptal = false
        AND (NOT tamamlandi OR tamamlanma_tarihi > now() - interval '24 hours')
    );
    GET DIAGNOSTICS v_sayac = ROW_COUNT;
    v_olusturulan := v_olusturulan + v_sayac;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;

GRANT EXECUTE ON FUNCTION public.laktasyon_kuru_kontrol() TO anon, authenticated;
