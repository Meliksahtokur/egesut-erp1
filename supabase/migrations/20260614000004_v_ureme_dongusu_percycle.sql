-- v_ureme_dongusu — per-cycle hibrit kategori (grup + dogum-onceligi + manuel genc_anne)
-- NOT: CREATE OR REPLACE kolon sırasını değiştiremediği için kategori, cycle_no mevcut sırada tutuldu.
CREATE OR REPLACE VIEW public.v_ureme_dongusu AS
WITH numbered AS (
  SELECT
    t.id, t.hayvan_id, t.tarih, t.sonuc, t.deneme_no,
    LOWER(TRIM(split_part(t.sperma, '|', 1))) AS sperma_norm,
    SUM(CASE WHEN t.deneme_no = 1 THEN 1 ELSE 0 END)
      OVER (PARTITION BY t.hayvan_id ORDER BY t.tarih, t.deneme_no
            ROWS UNBOUNDED PRECEDING) AS cycle_no,
    h.padok, h.durum,
    h.genc_anne AS h_genc_anne,
    h.grup      AS h_grup,
    (SELECT COUNT(*) FROM public.dogum d2 WHERE d2.anne_id = h.id) AS dogum_sayisi
  FROM public.tohumlama t
  JOIN public.hayvanlar h ON h.id = t.hayvan_id
  WHERE h.cinsiyet = 'Dişi'
    AND h.kisir IS NOT TRUE
)
SELECT
  hayvan_id, padok, durum,
  CASE
    WHEN cycle_no >= 2 THEN 'İnek'
    WHEN h_genc_anne = true  THEN 'Düve'
    WHEN h_genc_anne = false THEN 'İnek'
    WHEN h_grup ILIKE '%düve%' OR h_grup ILIKE '%duve%' THEN 'Düve'
    WHEN dogum_sayisi >= 2 THEN 'Düve'
    ELSE 'İnek'
  END AS kategori,
  cycle_no,
  MIN(tarih)     AS baslangic,
  MAX(tarih)     AS bitis,
  MAX(deneme_no) AS deneme_sayisi,
  CASE
    WHEN bool_or(sonuc IN ('Gebe','Doğum Yaptı')) THEN 'Gebe'
    WHEN bool_or(sonuc = 'Abort')                 THEN 'Abort'
    WHEN bool_or(sonuc = 'Bekliyor')              THEN 'Bekliyor'
    ELSE 'Boş'
  END AS sonuc,
  MAX(CASE WHEN sonuc IN ('Gebe','Doğum Yaptı') THEN sperma_norm END) AS gebe_sperma,
  (ARRAY_AGG(sperma_norm ORDER BY deneme_no DESC))[1] AS son_sperma
FROM numbered
GROUP BY hayvan_id, padok, durum, cycle_no, h_genc_anne, h_grup, dogum_sayisi;

GRANT SELECT ON public.v_ureme_dongusu TO anon, authenticated;
