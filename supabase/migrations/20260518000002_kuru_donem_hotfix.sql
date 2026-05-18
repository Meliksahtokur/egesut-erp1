-- Hotfix: kuru dönem RPC ve veri temizliği
-- 1. Yanlış oluşturulan false-positive görevleri iptal et
-- 2. Yanlış grup değiştirilen hayvanları geri al
-- 3. laktasyon_kuru_kontrol'ü dogum tablosuyla 210 gün kontrolüne döndür

BEGIN;

-- ── 1. Yanlış görevleri iptal et ──
-- Gün sayısı olmayan (yani broken RPC'nin ürettikleri) false-positive görevler
UPDATE public.gorev_log
SET iptal = true
WHERE gorev_tipi = 'PADOK_DEGISIM'
  AND aciklama = '⚠️ Kuru döneme geçiş zamanı — Kuru/Gebe padoğuna transfer'
  AND tamamlandi = false
  AND iptal = false;

-- ── 2. Yanlış grup değiştirilen hayvanları geri al ──
-- Sadece 002,185,149,122 kuru dönemde kalacak, diğerleri Sağmal (Laktasyonda) olacak
UPDATE public.hayvanlar
SET grup = 'Sağmal (Laktasyonda)'
WHERE grup = 'Sağmal (Kuru Dönem)'
  AND kupe_no NOT IN ('002', '185', '149', '122');

-- ── 3. laktasyon_kuru_kontrol — dogum tablosuna dayalı 210 gün kontrolü ──
CREATE OR REPLACE FUNCTION public.laktasyon_kuru_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_rec         record;
  v_gun         int;
  v_id          uuid;
BEGIN
  -- Son doğumundan 210+ gün geçmiş, hâlâ "Sağmal" grubunda ve kuru dönemde olmayan inekler
  FOR v_rec IN
    SELECT h.id, h.kupe_no, h.grup, h.padok,
           MAX(d.tarih) AS son_dogum_tarihi
    FROM hayvanlar h
    JOIN dogum d ON d.anne_id = h.id
    WHERE h.durum = 'Aktif'
      AND h.grup ILIKE '%Sağmal%'
      AND h.grup NOT ILIKE '%Kuru%'
    GROUP BY h.id, h.kupe_no, h.grup, h.padok
    HAVING CURRENT_DATE - MAX(d.tarih) >= 210
  LOOP
    v_gun := CURRENT_DATE - v_rec.son_dogum_tarihi;
    v_id  := gen_random_uuid();

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
        AND (NOT tamamlandi OR tamamlanma_tarihi > now() - interval '24 hours')
    );
    GET DIAGNOSTICS v_sayac = ROW_COUNT;
    v_olusturulan := v_olusturulan + v_sayac;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;

GRANT EXECUTE ON FUNCTION public.laktasyon_kuru_kontrol() TO anon, authenticated;

COMMIT;
