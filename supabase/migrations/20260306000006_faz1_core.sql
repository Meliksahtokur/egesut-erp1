-- ═══════════════════════════════════════════════════════
-- FAZ 3 MIGRATION — İşlem Geçmişi + Geri Alma
-- EgeSüt ERP v9 — 2026-03-06
-- ═══════════════════════════════════════════════════════

-- ──────────────────────────────────────────
-- 1. UPDATED_AT KOLONLARI
-- ──────────────────────────────────────────
ALTER TABLE public.hayvanlar     ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();
ALTER TABLE public.tohumlama     ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();
ALTER TABLE public.hastalik_log  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();
ALTER TABLE public.dogum         ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();
ALTER TABLE public.gorev_log     ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();
ALTER TABLE public.bildirim_log  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

-- ──────────────────────────────────────────
-- 2. UPDATED_AT OTOMATİK TRIGGER
-- ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_hayvanlar_updated_at
  BEFORE UPDATE ON public.hayvanlar
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE TRIGGER trg_tohumlama_updated_at
  BEFORE UPDATE ON public.tohumlama
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE TRIGGER trg_hastalik_updated_at
  BEFORE UPDATE ON public.hastalik_log
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE TRIGGER trg_dogum_updated_at
  BEFORE UPDATE ON public.dogum
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE TRIGGER trg_gorev_updated_at
  BEFORE UPDATE ON public.gorev_log
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ──────────────────────────────────────────
-- 3. HAYVAN_DURUM_VIEW GÜNCELLEMESİ (bos_gun eklendi)
-- ──────────────────────────────────────────
CREATE OR REPLACE VIEW public.hayvan_durum_view AS
WITH yas AS (
  SELECT
    h.id, h.kupe_no, h.devlet_kupe, h.irk, h.cinsiyet, h.dogum_tarihi,
    h.grup, h.padok, h.durum, h.anne_id, h.kategori,
    h.tohumlama_durumu, h.tohumlama_onay_tarihi, h.suttten_kesme_tarihi,
    h.cikis_tipi, h.cikis_tarihi,
    CASE WHEN h.dogum_tarihi IS NOT NULL THEN CURRENT_DATE - h.dogum_tarihi ELSE NULL END AS yas_gun,
    COALESCE(ie.tohumlama_gun, 365) AS tohumlama_esik_gun
  FROM public.hayvanlar h
  LEFT JOIN public.irk_esik ie ON ie.irk = h.irk
),
son_tohumlama AS (
  SELECT DISTINCT ON (hayvan_id)
    hayvan_id, id AS toh_id, tarih AS toh_tarih, sperma,
    sonuc AS toh_sonuc, (CURRENT_DATE - tarih) AS toh_gun
  FROM public.tohumlama
  ORDER BY hayvan_id, tarih DESC
),
son_bos_ref AS (
  -- Son boş tohumlama VEYA son doğumdan bu yana gün (gebe olmayan dişiler için)
  SELECT t.hayvan_id,
    MAX(t.tarih) AS bos_ref_tarih
  FROM (
    SELECT hayvan_id, tarih FROM public.tohumlama
    WHERE sonuc IN ('Boş', 'Abort')
    UNION ALL
    SELECT anne_id AS hayvan_id, tarih FROM public.dogum
  ) t
  GROUP BY t.hayvan_id
),
aktif_hastalik AS (
  SELECT hayvan_id, COUNT(*) AS hastalik_sayisi
  FROM public.hastalik_log WHERE durum = 'Aktif'
  GROUP BY hayvan_id
)
SELECT
  y.*,
  st.toh_id, st.toh_tarih, st.sperma, st.toh_sonuc, st.toh_gun,
  CASE
    WHEN st.toh_sonuc IS DISTINCT FROM 'Gebe' AND sb.bos_ref_tarih IS NOT NULL
    THEN (CURRENT_DATE - sb.bos_ref_tarih)
    ELSE NULL
  END AS bos_gun,
  COALESCE(ah.hastalik_sayisi, 0) AS aktif_hastalik_sayisi,
  CASE
    WHEN y.cikis_tipi IS NOT NULL THEN 'suruden_cikti'
    WHEN y.suttten_kesme_tarihi IS NULL AND y.yas_gun <= 75 THEN 'sut_icen'
    WHEN y.suttten_kesme_tarihi IS NOT NULL AND y.yas_gun <= 180 THEN 'suttten_kesilmis'
    WHEN y.yas_gun > 180 AND y.yas_gun <= 365 THEN 'kucuk_dana_duve'
    WHEN y.yas_gun > 365 AND st.toh_sonuc IS DISTINCT FROM 'Gebe' AND y.cinsiyet = 'Dişi' THEN 'buyuk_duve'
    WHEN st.toh_sonuc = 'Gebe' THEN 'gebe_duve_inek'
    WHEN y.grup LIKE '%Sağmal%' THEN 'sagmal_inek'
    WHEN y.cinsiyet = 'Erkek' AND y.yas_gun > 180 THEN 'besi_danasi'
    ELSE 'diger'
  END AS hesap_kategori,
  CASE
    WHEN y.cinsiyet = 'Dişi'
      AND y.yas_gun >= y.tohumlama_esik_gun
      AND (y.tohumlama_durumu IS NULL OR y.tohumlama_durumu = 'ertelendi')
      AND st.toh_sonuc IS DISTINCT FROM 'Gebe'
      AND y.cikis_tipi IS NULL
    THEN true ELSE false
  END AS tohumlama_bildirisi_gerekli,
  CASE
    WHEN y.suttten_kesme_tarihi IS NULL
      AND y.yas_gun >= COALESCE((SELECT suttten_kesme_gun FROM public.irk_esik WHERE irk = y.irk), 60)
      AND y.cikis_tipi IS NULL
    THEN true ELSE false
  END AS suttten_kesme_bildirisi_gerekli,
  CASE
    WHEN st.toh_sonuc = 'Gebe' AND (280 - st.toh_gun) BETWEEN 0 AND 14 THEN true ELSE false
  END AS dogum_yaklasti,
  CASE
    WHEN st.toh_sonuc = 'Gebe' AND st.toh_gun > 280 THEN (st.toh_gun - 280) ELSE 0
  END AS dogum_gecikme_gun
FROM yas y
LEFT JOIN son_tohumlama st ON st.hayvan_id = y.id
LEFT JOIN son_bos_ref sb ON sb.hayvan_id = y.id
LEFT JOIN aktif_hastalik ah ON ah.hayvan_id = y.id
WHERE y.durum = 'Aktif';

-- ──────────────────────────────────────────
-- 4. CIKIS_YAP STORED PROCEDURE
-- Tek transaction: hayvan güncelle + görevleri kapat + bildirimleri iptal et
-- Frontend artık bu RPC'yi çağırır, JS cascade kaldırılır
-- ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.cikis_yap(
  p_hayvan_id   text,
  p_cikis_tipi  text,
  p_cikis_tarihi date,
  p_cikis_sebebi text DEFAULT NULL,
  p_satis_fiyati numeric DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_hayvan record;
  v_snapshot jsonb;
BEGIN
  -- Hayvanı bul
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı veya zaten pasif');
  END IF;

  -- Snapshot oluştur (geri alma için)
  v_snapshot := jsonb_build_object(
    'olusturulan', '[]'::jsonb,
    'guncellenen', jsonb_build_array(
      jsonb_build_object(
        'tablo', 'hayvanlar', 'id', p_hayvan_id,
        'onceki', jsonb_build_object('durum', v_hayvan.durum, 'cikis_tipi', v_hayvan.cikis_tipi),
        'sonraki', jsonb_build_object('durum', 'Pasif', 'cikis_tipi', p_cikis_tipi)
      )
    ),
    'silinen', '[]'::jsonb
  );

  -- 1. Hayvanı pasif yap
  UPDATE public.hayvanlar SET
    durum = 'Pasif',
    cikis_tipi = p_cikis_tipi,
    cikis_tarihi = p_cikis_tarihi,
    cikis_sebebi = p_cikis_sebebi,
    satis_fiyati = p_satis_fiyati
  WHERE id = p_hayvan_id;

  -- 2. Açık görevleri kapat
  UPDATE public.gorev_log SET
    iptal = true, tamamlandi = true, tamamlanma_tarihi = now()
  WHERE hayvan_id = p_hayvan_id AND tamamlandi = false AND (iptal IS NULL OR iptal = false);

  -- 3. Bekleyen bildirimleri iptal et
  UPDATE public.bildirim_log SET durum = 'iptal'
  WHERE hayvan_id = p_hayvan_id AND durum = 'bekliyor';

  -- 4. İşlem log'una yaz
  INSERT INTO public.islem_log (tip, ana_hayvan_id, snapshot)
  VALUES (
    CASE WHEN p_cikis_tipi = 'olum' THEN 'OLUM_KAYDI' ELSE 'SATIS_KAYDI' END,
    p_hayvan_id,
    v_snapshot
  );

  RETURN jsonb_build_object('ok', true);
END;
$$ LANGUAGE plpgsql;

-- ──────────────────────────────────────────
-- 5. GERİ_AL STORED PROCEDURE
-- islem_log snapshot'ından işlemi tersine çevirir
-- ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.geri_al(
  p_islem_id text
) RETURNS jsonb AS $$
DECLARE
  v_log    record;
  v_item   jsonb;
  v_tablo  text;
  v_id     text;
  v_set    text;
  v_pairs  text[];
  v_key    text;
  v_val    text;
BEGIN
  SELECT * INTO v_log FROM public.islem_log WHERE id = p_islem_id AND durum = 'aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'İşlem bulunamadı veya zaten geri alındı');
  END IF;

  -- Oluşturulanları sil
  FOR v_item IN SELECT value FROM jsonb_array_elements(v_log.snapshot->'olusturulan')
  LOOP
    v_tablo := v_item->>'tablo';
    v_id    := v_item->>'id';
    EXECUTE format('DELETE FROM public.%I WHERE id = %L', v_tablo, v_id);
  END LOOP;

  -- Güncellenenleri eski haline döndür
  FOR v_item IN SELECT value FROM jsonb_array_elements(v_log.snapshot->'guncellenen')
  LOOP
    v_tablo  := v_item->>'tablo';
    v_id     := v_item->>'id';
    v_pairs  := ARRAY[]::text[];
    FOR v_key, v_val IN SELECT key, value #>> '{}' FROM jsonb_each(v_item->'onceki')
    LOOP
      v_pairs := v_pairs || format('%I = %L', v_key, v_val);
    END LOOP;
    IF array_length(v_pairs, 1) > 0 THEN
      v_set := array_to_string(v_pairs, ', ');
      EXECUTE format('UPDATE public.%I SET %s WHERE id = %L', v_tablo, v_set, v_id);
    END IF;
  END LOOP;

  -- İşlem log'unu geri alındı olarak işaretle
  UPDATE public.islem_log
  SET durum = 'geri_alindi', geri_alma_tarihi = now()
  WHERE id = p_islem_id;

  RETURN jsonb_build_object('ok', true);
END;
$$ LANGUAGE plpgsql;

NOTIFY pgrst, 'reload schema';
