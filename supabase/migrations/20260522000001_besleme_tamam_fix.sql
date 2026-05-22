-- Migration: besleme_tamam parent_id cast düzeltmesi
-- Sorun: v_gorev.id::text → parent_id uuid kolona text geçiriliyordu
-- Düzeltme: ::text cast kaldırıldı, uuid direkt geçiliyor

CREATE OR REPLACE FUNCTION public.besleme_tamam(p_gorev_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev gorev_log%ROWTYPE;
  v_yeni_id uuid;
BEGIN
  -- 1. Görevi çek
  SELECT * INTO v_gorev FROM gorev_log WHERE id = p_gorev_id::uuid;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev bulunamadı');
  END IF;
  IF v_gorev.tamamlandi OR v_gorev.iptal THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev zaten kapalı');
  END IF;

  -- 2. Tamamla
  UPDATE gorev_log
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE id = p_gorev_id::uuid;

  -- 3. Hayvan hâlâ gebe mi kontrol et (doğum yapmışsa zinciri kesme)
  IF NOT EXISTS (
    SELECT 1 FROM tohumlama
    WHERE hayvan_id = v_gorev.hayvan_id
      AND sonuc = 'Gebe'
  ) THEN
    RETURN jsonb_build_object('ok', true, 'zincir', 'hayvan_artik_gebe_degil');
  END IF;

  -- 4. Zincirleme: ertesi gün için aynı besleme tipini oluştur
  v_yeni_id := gen_random_uuid();
  INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih,
                         tamamlandi, kaynak, parent_id)
  SELECT v_yeni_id, v_gorev.hayvan_id, 'BESLEME',
         v_gorev.aciklama,
         v_gorev.hedef_tarih + 1,
         false, 'BESLEME_OTOMATIK', v_gorev.id   -- uuid direkt, ::text cast yok
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
