-- Migration: Repeat breed — dogru tespit mantigi
-- Aktif: ayni cycle (21 gun) icinde 2+ tohumlama VE son sonuc Bekliyor
-- Gecmis: ≤15 gun ara ile 2 tohumlama (tarihte herhangi bir yerde)
-- Count: toplam tekrarlanan tohumlama sayisi
-- Geri al: DROP VIEW + onceki surumu geri yukle

BEGIN;

DROP VIEW IF EXISTS public.tohumlanabilir_hayvanlar CASCADE;
DROP VIEW IF EXISTS public.hayvan_durum_view CASCADE;

CREATE VIEW public.hayvan_durum_view AS
WITH yas AS (
  SELECT
    h.id, h.kupe_no, h.devlet_kupe, h.irk, h.cinsiyet,
    h.dogum_tarihi, h.grup, h.padok_id,
    COALESCE(pk.ad, h.padok) AS padok,
    h.durum, h.anne_id, h.kategori,
    h.tohumlama_durumu, h.tohumlama_onay_tarihi, h.suttten_kesme_tarihi,
    h.cikis_tipi, h.cikis_tarihi, h.cikis_sebebi, h.satis_fiyati, h.notlar,
    h.dogum_kg, h.canli_agirlik, h.boy, h.renk,
    h.ayirici_ozellik, h.baba_bilgi, h.abort_sayisi, h.kisir,
    CASE
      WHEN h.dogum_tarihi IS NOT NULL THEN CURRENT_DATE - h.dogum_tarihi
      ELSE NULL
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
  FROM public.tohumlama
  ORDER BY hayvan_id, tarih DESC
),
aktif_hastalik AS (
  SELECT hayvan_id, COUNT(*) AS hastalik_sayisi
  FROM public.hastalik_log WHERE durum = 'Aktif' GROUP BY hayvan_id
),
-- Gecmis repeat tespiti: ≤15 gun ara ile 2 tohumlama
repeat_breed AS (
  SELECT
    t1.hayvan_id,
    COUNT(*) AS yakin_sayisi
  FROM public.tohumlama t1
  WHERE EXISTS (
    SELECT 1 FROM public.tohumlama t2
    WHERE t2.hayvan_id = t1.hayvan_id
      AND t2.id <> t1.id
      AND ABS(t2.tarih - t1.tarih) <= 15
  )
  GROUP BY t1.hayvan_id
)
SELECT
  y.*,
  st.toh_id, st.toh_tarih, st.sperma, st.toh_sonuc, st.toh_gun,
  COALESCE(ah.hastalik_sayisi, 0) AS aktif_hastalik_sayisi,
  CASE WHEN y.cikis_tipi IS NOT NULL THEN 'suruden_cikti'
    WHEN y.suttten_kesme_tarihi IS NULL AND y.yas_gun <= 75 THEN 'sut_icen'
    WHEN y.suttten_kesme_tarihi IS NOT NULL AND y.yas_gun <= 180 THEN 'suttten_kesilmis'
    WHEN y.cinsiyet = 'Erkek' AND y.yas_gun > 180 THEN 'besi'
    WHEN y.cinsiyet = 'Dişi' AND y.yas_gun BETWEEN 181 AND 365 THEN 'duve_kucuk'
    WHEN y.cinsiyet = 'Dişi' AND y.yas_gun BETWEEN 366 AND 730 THEN 'duve_buyuk'
    WHEN y.cinsiyet = 'Dişi' AND y.yas_gun > 730 THEN 'sagmal'
    ELSE 'genel'
  END AS hesap_kategori,
  CASE WHEN y.cinsiyet = 'Dişi' AND y.yas_gun >= y.tohumlama_esik_gun
    AND (st.toh_sonuc IS NULL OR st.toh_sonuc = 'Boş') THEN true ELSE false
  END AS tohumlama_bildirisi_gerekli,
  CASE WHEN y.suttten_kesme_tarihi IS NULL AND y.yas_gun BETWEEN 76 AND 180
    THEN true ELSE false
  END AS suttten_kesme_bildirisi_gerekli,
  CASE WHEN st.toh_sonuc = 'Gebe' AND (280 - st.toh_gun) BETWEEN 0 AND 7
    THEN true ELSE false
  END AS dogum_yaklasti,
  CASE WHEN st.toh_sonuc = 'Gebe' AND st.toh_gun > 280
    THEN st.toh_gun - 280 ELSE 0
  END AS dogum_gecikme_gun,
  CASE WHEN st.toh_sonuc = 'Gebe' THEN 'gebe'
    WHEN st.toh_sonuc = 'Bekliyor' THEN 'bekliyor'
    WHEN y.yas_gun >= y.tohumlama_esik_gun AND y.cinsiyet = 'Dişi' THEN 'tohumlanabilir'
    ELSE 'erken'
  END AS tohumlama_durumu_hesap,
  -- AKTIF: son tohumlama Bekliyor VE 21 gun icinde baska tohumlamasi var (ayni cycle)
  CASE
    WHEN st.toh_sonuc = 'Bekliyor'
      AND EXISTS (
        SELECT 1 FROM public.tohumlama t2
        WHERE t2.hayvan_id = st.hayvan_id
          AND t2.id <> st.toh_id
          AND ABS(t2.tarih - st.toh_tarih) <= 21
      )
    THEN true ELSE false
  END AS repeat_breed_active,
  -- GECMIS: ≤15 gun ara ile 2 tohumlama olmus (aktif degilse)
  CASE
    WHEN COALESCE(rb.yakin_sayisi, 0) >= 2
      AND NOT (
        st.toh_sonuc = 'Bekliyor'
        AND EXISTS (
          SELECT 1 FROM public.tohumlama t2
          WHERE t2.hayvan_id = st.hayvan_id
            AND t2.id <> st.toh_id
            AND ABS(t2.tarih - st.toh_tarih) <= 21
        )
      )
    THEN true ELSE false
  END AS repeat_breed_past,
  -- COUNT: toplam tekrarlanan tohumlama sayisi
  -- (active icin son 21 gun, past icin ≤15 gun)
  CASE
    WHEN st.toh_sonuc = 'Bekliyor'
      AND EXISTS (
        SELECT 1 FROM public.tohumlama t2
        WHERE t2.hayvan_id = st.hayvan_id
          AND t2.id <> st.toh_id
          AND ABS(t2.tarih - st.toh_tarih) <= 21
      )
    THEN (
      SELECT COUNT(*) FROM public.tohumlama
      WHERE hayvan_id = st.hayvan_id
        AND tarih >= st.toh_tarih - 21
        AND tarih <= st.toh_tarih
    )
    ELSE COALESCE(rb.yakin_sayisi, 0)
  END AS repeat_breed_count
FROM yas y
LEFT JOIN son_tohumlama st ON st.hayvan_id = y.id
LEFT JOIN aktif_hastalik ah ON ah.hayvan_id = y.id
LEFT JOIN repeat_breed rb ON rb.hayvan_id = y.id;

GRANT SELECT ON public.hayvan_durum_view TO anon, authenticated;

CREATE VIEW public.tohumlanabilir_hayvanlar AS
SELECT id, kupe_no, devlet_kupe, irk, cinsiyet, dogum_tarihi,
  grup, padok_id, padok, durum, anne_id, kategori,
  tohumlama_durumu, tohumlama_onay_tarihi, suttten_kesme_tarihi,
  cikis_tipi, cikis_tarihi, cikis_sebebi, satis_fiyati, notlar,
  dogum_kg, canli_agirlik, boy, renk, ayirici_ozellik, baba_bilgi, abort_sayisi,
  yas_gun, tohumlama_esik_gun, kisir,
  toh_id, toh_tarih, sperma, toh_sonuc, toh_gun,
  aktif_hastalik_sayisi, hesap_kategori,
  tohumlama_bildirisi_gerekli, suttten_kesme_bildirisi_gerekli,
  dogum_yaklasti, dogum_gecikme_gun, tohumlama_durumu_hesap,
  repeat_breed_active, repeat_breed_past, repeat_breed_count
FROM hayvan_durum_view
WHERE tohumlama_durumu_hesap = 'tohumlanabilir';

GRANT SELECT ON public.tohumlanabilir_hayvanlar TO anon, authenticated;

COMMIT;
