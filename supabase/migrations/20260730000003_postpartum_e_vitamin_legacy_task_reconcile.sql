-- Legacy açık doğum-sonrası E vitamini görevlerini kanonik d53 protokolüne taşır.
-- Yalnız açık/iptal edilmemiş DOGUM kaynaklı görevler hedeflenir; tamamlanan kayıtlar korunur.
WITH latest_birth AS (
  SELECT DISTINCT ON (anne_id) anne_id, tarih
  FROM public.dogum
  ORDER BY anne_id, tarih DESC, created_at DESC, id DESC
)
UPDATE public.gorev_log g
SET hedef_tarih = b.tarih + 53,
    aciklama = '53. Gün: E Vitamini'
FROM latest_birth b
WHERE g.hayvan_id = b.anne_id
  AND g.kaynak = 'DOGUM-' || b.anne_id
  AND g.etken_kod = 'E_VIT'
  AND NOT g.tamamlandi
  AND NOT COALESCE(g.iptal, false)
  AND (
    (g.hedef_tarih = b.tarih + 54 AND g.aciklama = '54. Gün: Yeldif')
    OR (g.hedef_tarih = b.tarih + 53 AND g.aciklama = '53. Gün: Yeldif')
  );
