-- Belirsiz üreme statüsü: grup düve değil + <2 sistem-içi doğum + tohumlaması var + incelenmedi
-- NOT: stat_suru_ozet'in ham per-cycle + belirsiz sayısı değişikliği ground_truth.sql'e yazılır (Task 4).
CREATE OR REPLACE FUNCTION public.hayvan_belirsiz_ureme_listele()
RETURNS TABLE (
  hayvan_id text, kupe_no text, grup text, padok text,
  dogum_sayisi integer, tohumlama_sayisi integer, son_tohumlama date
)
LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT h.id, h.kupe_no, h.grup, h.padok,
    (SELECT COUNT(*) FROM public.dogum d WHERE d.anne_id = h.id)::int,
    (SELECT COUNT(*) FROM public.tohumlama t WHERE t.hayvan_id = h.id)::int,
    (SELECT MAX(t.tarih) FROM public.tohumlama t WHERE t.hayvan_id = h.id)
  FROM public.hayvanlar h
  WHERE h.cinsiyet = 'Dişi' AND h.durum = 'Aktif' AND h.kisir IS NOT TRUE
    AND h.genc_anne IS NULL
    AND NOT (h.grup ILIKE '%düve%' OR h.grup ILIKE '%duve%')
    AND (SELECT COUNT(*) FROM public.dogum d WHERE d.anne_id = h.id) < 2
    AND EXISTS (SELECT 1 FROM public.tohumlama t WHERE t.hayvan_id = h.id)
  ORDER BY (SELECT MAX(t.tarih) FROM public.tohumlama t WHERE t.hayvan_id = h.id) DESC NULLS LAST;
$$;

GRANT EXECUTE ON FUNCTION public.hayvan_belirsiz_ureme_listele() TO anon, authenticated;
