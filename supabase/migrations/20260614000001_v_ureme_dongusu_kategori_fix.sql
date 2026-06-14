-- v_ureme_dongusu — kategori tespiti grup-string yerine doğum/abort geçmişi
-- Düve = hiç Doğum/Abort yok · İnek = en az 1 Doğum/Abort
-- app.js:299 dogumAbortVar mantığının DB hali; dogum_kaydet grup'u senkron tutar

CREATE OR REPLACE VIEW public.v_ureme_dongusu AS
WITH numbered AS (
  SELECT
    t.id,
    t.hayvan_id,
    t.tarih,
    t.sonuc,
    t.deneme_no,
    LOWER(TRIM(split_part(t.sperma, '|', 1))) AS sperma_norm,
    SUM(CASE WHEN t.deneme_no = 1 THEN 1 ELSE 0 END)
      OVER (PARTITION BY t.hayvan_id ORDER BY t.tarih, t.deneme_no
            ROWS UNBOUNDED PRECEDING) AS cycle_no,
    CASE
      WHEN EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id)
        OR EXISTS (SELECT 1 FROM public.tohumlama t2
                   WHERE t2.hayvan_id = h.id
                     AND t2.sonuc IN ('Doğum Yaptı','Abort'))
        THEN 'İnek'
      ELSE 'Düve'
    END AS kategori,
    h.padok,
    h.durum
  FROM public.tohumlama t
  JOIN public.hayvanlar h ON h.id = t.hayvan_id
  WHERE h.cinsiyet = 'Dişi'
    AND h.kisir IS NOT TRUE
)
SELECT
  hayvan_id,
  padok,
  durum,
  kategori,
  cycle_no,
  MIN(tarih)           AS baslangic,
  MAX(tarih)           AS bitis,
  MAX(deneme_no)       AS deneme_sayisi,
  CASE
    WHEN bool_or(sonuc IN ('Gebe','Doğum Yaptı')) THEN 'Gebe'
    WHEN bool_or(sonuc = 'Abort')                 THEN 'Abort'
    WHEN bool_or(sonuc = 'Bekliyor')              THEN 'Bekliyor'
    ELSE 'Boş'
  END                  AS sonuc,
  MAX(CASE WHEN sonuc IN ('Gebe','Doğum Yaptı') THEN sperma_norm END) AS gebe_sperma,
  (ARRAY_AGG(sperma_norm ORDER BY deneme_no DESC))[1] AS son_sperma
FROM numbered
GROUP BY hayvan_id, padok, durum, kategori, cycle_no;

GRANT SELECT ON public.v_ureme_dongusu TO anon, authenticated;
