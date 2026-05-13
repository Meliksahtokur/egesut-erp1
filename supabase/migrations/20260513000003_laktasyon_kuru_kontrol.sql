-- Migration: laktasyon_kuru_kontrol RPC
-- 210+ gün laktasyondaki sağmal inekleri bulup kuru dönem transfer görevi oluşturur

BEGIN;

CREATE OR REPLACE FUNCTION public.laktasyon_kuru_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_rec         record;
  v_gun         int;
  v_hedef       date;
BEGIN
  -- Son doğumundan 210+ gün geçmiş, hala "Sağmal" grubundaki inekleri bul
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
    v_hedef := v_rec.son_dogum_tarihi + 210;

    INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, padok_hedef)
    SELECT gen_random_uuid()::text, v_rec.id, 'PADOK_DEGISIM',
           '⚠️ Kuru döneme geçiş zamanı (' || v_gun || '. gün laktasyon) — Kuru/Gebe padoğuna transfer',
           v_hedef, false,
           (SELECT ad FROM padoklar WHERE ad ILIKE '%Kuru%' LIMIT 1)
    WHERE NOT EXISTS (
      SELECT 1 FROM gorev_log
      WHERE hayvan_id = v_rec.id
        AND gorev_tipi = 'PADOK_DEGISIM'
        AND aciklama ILIKE '%Kuru döneme%'
        AND NOT tamamlandi
    );
    GET DIAGNOSTICS v_sayac = ROW_COUNT;
    v_olusturulan := v_olusturulan + v_sayac;

  END LOOP;

  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;

END;
