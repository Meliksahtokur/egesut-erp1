-- Migration: buzagi_sutten_kesme_kontrol RPC
-- Pattern: ileri_gebe_gorev_kontrol ile aynı yapı
-- Domain kuralı: 60 günden büyük "Süt İçen Buzağı" → sütten kesme görevi
-- İki görev üretir: (1) sütten kesme (2) padok transfer

BEGIN;

CREATE OR REPLACE FUNCTION public.buzagi_sutten_kesme_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_hayvan      record;
  v_gun         int;
  v_hedef       date;
  v_parent_id   text;
BEGIN
  -- "Süt İçen Buzağı" grubundaki aktif hayvanları tara
  FOR v_hayvan IN
    SELECT h.*
    FROM hayvanlar h
    WHERE h.durum = 'Aktif'
      AND h.grup ILIKE '%Süt İçen Buzağı%'
      AND h.dogum_tarihi IS NOT NULL
  LOOP
    v_gun := CURRENT_DATE - v_hayvan.dogum_tarihi;

    -- 60. gün: sütten kesme zamanı
    IF v_gun >= 60 THEN
      v_hedef := v_hayvan.dogum_tarihi + 60;
      v_parent_id := gen_random_uuid()::text;

      -- Ana görev: Sütten Kesme
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
      SELECT v_parent_id, v_hayvan.id, 'SUTTEN_KESME',
             '🍼 Sütten kesme zamanı (' || v_gun || '. gün)',
             v_hedef, false
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log
        WHERE hayvan_id = v_hayvan.id
          AND gorev_tipi = 'SUTTEN_KESME'
          AND NOT tamamlandi
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT;
      v_olusturulan := v_olusturulan + v_sayac;

      -- Alt görev: Padok Transfer (Buzağı Ahırı → Sütten Kesilmiş)
      IF v_sayac > 0 THEN
        INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, parent_id, padok_hedef)
        VALUES (
          gen_random_uuid()::text, v_hayvan.id, 'PADOK_DEGISIM',
          '➡️ Padok transfer: Sütten Kesilmiş Buzağı padoğuna taşı',
          v_hedef, false, v_parent_id,
          (SELECT ad FROM padoklar WHERE ad ILIKE '%Sütten Kesilmiş%' LIMIT 1)
        );
        v_olusturulan := v_olusturulan + 1;
      END IF;

    END IF;

  END LOOP;

  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;

END;
