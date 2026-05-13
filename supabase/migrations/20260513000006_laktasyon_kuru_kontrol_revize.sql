-- Migration: laktasyon_kuru_kontrol RPC (revize) — dogum tablosu olmadan
-- Sağmal grupta olup gebe olmayan hayvanlar → kuru dönem transfer görevi
BEGIN;

CREATE OR REPLACE FUNCTION public.laktasyon_kuru_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_rec         record;
BEGIN
  -- Sağmal grupta olup gebe olmayan aktif hayvanları bul
  FOR v_rec IN
    SELECT h.id, h.kupe_no, h.grup, h.padok
    FROM hayvanlar h
    WHERE h.durum = 'Aktif'
      AND h.grup ILIKE '%Sağmal%'
      AND h.grup NOT ILIKE '%Kuru%'
      AND NOT EXISTS (
        SELECT 1 FROM tohumlama t
        WHERE t.hayvan_id = h.id AND t.sonuc = 'Gebe'
      )
  LOOP
    INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, padok_hedef)
    SELECT gen_random_uuid()::text, v_rec.id, 'PADOK_DEGISIM',
           '⚠️ Kuru döneme geçiş zamanı — Kuru/Gebe padoğuna transfer',
           CURRENT_DATE, false,
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
