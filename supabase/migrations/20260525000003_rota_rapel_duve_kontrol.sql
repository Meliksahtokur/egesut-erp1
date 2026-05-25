-- Migration: Rota-Corona rapel (2. doz) sadece düveler için
-- Etkiler:
--   1. ileri_gebe_asi_tamamla REPLACE — rapel görevi sadece düveler için oluşur
--   2. Hatalı oluşmuş bekleyen 2. doz görevleri iptal edilir (inekler)
--   3. Tamamlanmış hatalı 2. doz görevi gorev_geri_al ile temizlenir (ayrı adım)
-- Geri alınabilir: DROP FUNCTION public.ileri_gebe_asi_tamamla(text,uuid,date,numeric);
--   Cleanup UPDATE'leri manual reverse: iptal=false + aciklama eski haline döndür

BEGIN;

-- ═══════════════════════════════════════════════════════════
-- 1. ileri_gebe_asi_tamamla REPLACE — düve kontrolü eklendi
-- ═══════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.ileri_gebe_asi_tamamla(
  p_gorev_id   text,
  p_vaccine_id uuid,
  p_tarih      date    DEFAULT CURRENT_DATE,
  p_doz        numeric DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev       gorev_log%ROWTYPE;
  v_vax_result  jsonb;
  v_rapel_id    uuid;
  v_rapel_tarih date;
  v_is_first    boolean;
BEGIN
  -- 1. Görevi çek ve kontrol et
  SELECT * INTO v_gorev FROM gorev_log WHERE id = p_gorev_id::uuid;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev bulunamadı');
  END IF;
  IF v_gorev.tamamlandi THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev zaten tamamlanmış');
  END IF;

  -- 2. Aşıyı kaydet (add_vaccination → vaccination_log + stok trigger)
  SELECT public.add_vaccination(
    v_gorev.hayvan_id::text, p_vaccine_id, p_tarih, p_doz, 'GorevID:' || p_gorev_id
  ) INTO v_vax_result;

  IF (v_vax_result->>'ok')::boolean = false THEN
    RETURN v_vax_result;
  END IF;

  -- 3. Görevi tamamla
  UPDATE gorev_log
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE id = p_gorev_id::uuid;

  -- 4. 1. doz ise rapel görevi oluştur (21 gün sonra) — sadece düveler
  v_is_first := v_gorev.aciklama ILIKE '%1. doz%';
  IF v_is_first THEN
    -- Sadece Düve grubundaki hayvanlar rapel alır (inekler tek doz)
    PERFORM 1 FROM hayvanlar
    WHERE id = v_gorev.hayvan_id AND grup ILIKE '%Düve%';
    IF FOUND THEN
      v_rapel_tarih := p_tarih + 21;
      v_rapel_id := gen_random_uuid();
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, parent_id, kaynak)
      VALUES (
        v_rapel_id,
        v_gorev.hayvan_id,
        'ILERI_GEBE_ASI',
        '💉 Rota-Corona Aşısı (2. doz — düve)',
        v_rapel_tarih,
        false,
        v_gorev.stok_id,
        1,
        v_gorev.id,
        'ILERI_GEBE'
      )
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'vaccination_id', v_vax_result->>'vaccination_id',
    'rapel_gorev_id', v_rapel_id,
    'rapel_tarih', v_rapel_tarih
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.ileri_gebe_asi_tamamla(text,uuid,date,numeric) TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════
-- 2. Bekleyen hatalı 2. dozları iptal et (inekler)
-- ═══════════════════════════════════════════════════════════
-- Düve grubunda olmayan hayvanlara hatalı oluşmuş 2. doz görevleri iptal
UPDATE gorev_log
SET iptal = true,
    aciklama = aciklama || ' — iptal edildi (tek doz, rapel gerekmez)'
WHERE aciklama = '💉 Rota-Corona Aşısı (2. doz)'
  AND tamamlandi = false
  AND iptal = false
  AND hayvan_id IN (
    SELECT id FROM hayvanlar
    WHERE grup NOT ILIKE '%Düve%'
  );

-- ═══════════════════════════════════════════════════════════
-- 3. Varsa hatalı oluşan "2. doz — düve" görevlerini de temizle
--    (gebelik_protokol_kontrol'den düve olmayanlara yanlışlıkla oluşmuş olabilir)
-- ═══════════════════════════════════════════════════════════
UPDATE gorev_log
SET iptal = true,
    aciklama = aciklama || ' — iptal edildi (tek doz, rapel gerekmez)'
WHERE aciklama = '💉 Rota-Corona Aşısı (2. doz — düve)'
  AND tamamlandi = false
  AND iptal = false
  AND hayvan_id IN (
    SELECT id FROM hayvanlar
    WHERE grup NOT ILIKE '%Düve%'
  );

END;
