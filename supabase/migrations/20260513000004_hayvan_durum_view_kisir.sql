-- Migration: hayvan_durum_view + tohumlanabilir_hayvanlar — zeki tohumlama mantigi
-- Duzenlenme: 2026-05-13 — kisir kontrolu, dogum_tarihi NULL ise tohumlama/laktasyon kontrolu

BEGIN;

DROP VIEW IF EXISTS public.tohumlanabilir_hayvanlar CASCADE;
DROP VIEW IF EXISTS public.hayvan_durum_view CASCADE;

CREATE VIEW public.hayvan_durum_view AS
WITH yas AS (
  SELECT
    h.id, h.kupe_no, h.devlet_kupe, h.irk, h.cinsiyet, h.dogum_tarihi,
    h.grup, h.padok_id, h.durum, h.anne_id, h.kategori,
    h.tohumlama_durumu, h.tohumlama_onay_tarihi, h.suttten_kesme_tarihi,
    h.cikis_tipi, h.cikis_tarihi, h.cikis_sebebi, h.satis_fiyati, h.notlar,
    h.dogum_kg, h.canli_agirlik, h.boy, h.renk, h.ayirici_ozellik,
    h.baba_bilgi, h.abort_sayisi, h.kisir,
    COALESCE(pk.ad, h.padok) AS padok,
    CASE WHEN h.dogum_tarihi IS NOT NULL
      THEN CURRENT_DATE - h.dogum_tarihi ELSE NULL
    END AS yas_gun,
    COALESCE(ie.tohumlama_gun, 365) AS tohumlama_esik_gun
  FROM public.hayvanlar h
  LEFT JOIN public.padoklar pk ON pk.id = h.padok_id
  LEFT JOIN public.irk_esik ie ON ie.irk = h.irk
),
son_tohumlama AS (
  SELECT DISTINCT ON (hayvan_id)
    hayvan_id, id AS toh_id, tarih AS toh_tarih,
    sperma, sonuc AS toh_sonuc,
    (CURRENT_DATE - tarih) AS toh_gun
  FROM public.tohumlama ORDER BY hayvan_id, tarih DESC
),
aktif_hastalik AS (
  SELECT hayvan_id, COUNT(*) AS hastalik_sayisi
  FROM public.hastalik_log WHERE durum = 'Aktif'
  GROUP BY hayvan_id
)
SELECT
  y.*,
  st.toh_id, st.toh_tarih, st.sperma, st.toh_sonuc, st.toh_gun,
  COALESCE(ah.hastalik_sayisi, 0) AS aktif_hastalik_sayisi,
  CASE
    WHEN y.cikis_tipi IS NOT NULL THEN 'suruden_cikti'
    WHEN y.suttten_kesme_tarihi IS NULL AND y.yas_gun <= 75 THEN 'sut_icen'
    WHEN y.suttten_kesme_tarihi IS NOT NULL AND y.yas_gun <= 180 THEN 'suttten_kesilmis'
    WHEN y.cinsiyet = 'Erkek' AND y.yas_gun > 180 THEN 'besi'
    WHEN y.cinsiyet = 'Disi' AND y.yas_gun BETWEEN 181 AND 365 THEN 'duve_kucuk'
    WHEN y.cinsiyet = 'Disi' AND y.yas_gun BETWEEN 366 AND 730 THEN 'duve_buyuk'
    WHEN y.cinsiyet = 'Disi' AND y.yas_gun > 730 THEN 'sagmal'
    ELSE 'genel'
  END AS hesap_kategori,
  CASE WHEN st.toh_sonuc = 'Gebe' AND (280 - st.toh_gun) BETWEEN 0 AND 7
    THEN true ELSE false END AS dogum_yaklasti,
  CASE WHEN st.toh_sonuc = 'Gebe' AND st.toh_gun > 280
    THEN st.toh_gun - 280 ELSE 0 END AS dogum_gecikme_gun,
  CASE
    WHEN st.toh_sonuc = 'Gebe' THEN 'gebe'
    WHEN st.toh_sonuc = 'Bekliyor' THEN 'bekliyor'
    WHEN y.cinsiyet = 'Erkek' THEN 'erken'
    WHEN y.kisir = true THEN 'erken'
    WHEN y.yas_gun >= y.tohumlama_esik_gun THEN 'tohumlanabilir'
    WHEN st.toh_id IS NOT NULL THEN 'tohumlanabilir'
    WHEN y.grup IN ('Sagmal (Laktasyonda)', 'Sagmal (Kuru)', 'Gebe Inek', 'Gebe Duve') THEN 'tohumlanabilir'
    ELSE 'erken'
  END AS tohumlama_durumu_hesap
FROM yas y
LEFT JOIN son_tohumlama st ON st.hayvan_id = y.id
LEFT JOIN aktif_hastalik ah ON ah.hayvan_id = y.id;

GRANT SELECT ON public.hayvan_durum_view TO anon, authenticated;

CREATE VIEW public.tohumlanabilir_hayvanlar AS
SELECT * FROM hayvan_durum_view
WHERE tohumlama_durumu_hesap = 'tohumlanabilir';

GRANT SELECT ON public.tohumlanabilir_hayvanlar TO anon, authenticated;

END;
