-- Sessiz hayvan yaş filtresi: <13 ay + buzağı grubunu üreme istatistiklerinden hariç tut
-- sessiz_gun fallback: dogum_tarihi bazlı (NULL ise NULL kalır)
-- min_gun 60→55'e düşür
BEGIN;

-- ═══ 1. v_eligible — buzağı hariç + 13 ay yaş filtresi ═══
CREATE OR REPLACE VIEW public.v_eligible AS
SELECT
  h.id, h.kupe_no, h.grup, h.padok,
  son_dogum.tarih                    AS son_dogum_tarihi,
  CURRENT_DATE - son_dogum.tarih     AS dogum_gun,
  son_aktivite.tarih                 AS son_aktivite_tarihi,
  CASE
    WHEN son_aktivite.tarih IS NOT NULL THEN CURRENT_DATE - son_aktivite.tarih
    ELSE CASE
      WHEN h.dogum_tarihi IS NOT NULL THEN CURRENT_DATE - h.dogum_tarihi
      ELSE NULL
    END
  END                                AS sessiz_gun
FROM public.hayvanlar h
LEFT JOIN LATERAL (
  SELECT MAX(d.tarih) AS tarih FROM public.dogum d WHERE d.anne_id = h.id
) son_dogum ON true
LEFT JOIN LATERAL (
  SELECT MAX(tarih) AS tarih FROM (
    SELECT tarih FROM public.tohumlama WHERE hayvan_id = h.id
    UNION ALL
    SELECT tarih FROM public.kizginlik_log WHERE hayvan_id = h.id
  ) aktivite
) son_aktivite ON true
WHERE h.cinsiyet = 'Dişi'
  AND h.durum = 'Aktif'
  AND h.kisir IS NOT TRUE
  AND h.grup NOT ILIKE '%buzağı%' AND h.grup NOT ILIKE '%buzagi%'
  AND h.grup NOT ILIKE '%Küçük%' AND h.grup NOT ILIKE '%Kucuk%'
  AND (h.dogum_tarihi IS NULL OR h.dogum_tarihi <= CURRENT_DATE - INTERVAL '13 months')
  AND NOT EXISTS (SELECT 1 FROM public.tohumlama t WHERE t.hayvan_id = h.id AND t.sonuc = 'Gebe')
  AND NOT EXISTS (SELECT 1 FROM public.cases c WHERE c.animal_id = h.id AND c.status = 'active')
  AND (son_dogum.tarih IS NULL OR son_dogum.tarih < CURRENT_DATE - 55);

-- ═══ 2. sessiz_hayvanlar_listele — default 55 gün ═══
CREATE OR REPLACE FUNCTION public.sessiz_hayvanlar_listele(
  p_padok   text    DEFAULT NULL,
  p_min_gun integer DEFAULT 55
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN (SELECT COALESCE(jsonb_agg(
    jsonb_build_object('hayvan_id', e.id, 'kupe_no', e.kupe_no, 'grup', e.grup, 'padok', e.padok,
      'sessiz_gun', COALESCE(e.sessiz_gun, 9999), 'son_aktivite', e.son_aktivite_tarihi)
    ORDER BY COALESCE(e.sessiz_gun, 9999) DESC), '[]'::jsonb)
  FROM public.v_eligible e
  WHERE (p_padok IS NULL OR e.padok = p_padok) AND COALESCE(e.sessiz_gun, 9999) >= p_min_gun);
END;
$$;
GRANT EXECUTE ON FUNCTION public.sessiz_hayvanlar_listele(text, integer) TO anon, authenticated;

-- ═══ 3. sessiz_hayvanlar_gorev_olustur — 55 gün eşik ═══
CREATE OR REPLACE FUNCTION public.sessiz_hayvanlar_gorev_olustur()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_count integer := 0; v_rec record;
BEGIN
  FOR v_rec IN
    SELECT e.id, e.kupe_no, e.sessiz_gun FROM public.v_eligible e
    WHERE COALESCE(e.sessiz_gun, 9999) >= 55
      AND NOT EXISTS (SELECT 1 FROM public.gorev_log g WHERE g.hayvan_id = e.id AND g.gorev_tipi = 'VETERINER_KONTROL' AND g.tamamlandi = false)
  LOOP
    INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
    VALUES (gen_random_uuid(), v_rec.id, 'VETERINER_KONTROL',
      format('Sessiz hayvan: %s gündür üreme aktivitesi yok (%s)', COALESCE(v_rec.sessiz_gun, 0), v_rec.kupe_no),
      CURRENT_DATE, false);
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;
GRANT EXECUTE ON FUNCTION public.sessiz_hayvanlar_gorev_olustur() TO anon, authenticated;

COMMIT;
