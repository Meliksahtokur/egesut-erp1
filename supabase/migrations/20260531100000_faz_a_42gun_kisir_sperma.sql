-- Faz A: 42-gün kuralı + kısır dışlama + sperma limit kaldırma

-- ═══ 1. v_ureme_dongusu — kısır filtresi ═══
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
      WHEN h.grup ILIKE '%düve%' OR h.grup ILIKE '%duve%' THEN 'Düve'
      WHEN EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id) THEN 'İnek'
      WHEN h.grup ILIKE '%inek%' OR h.grup LIKE '%İnek%'
           OR h.grup ILIKE '%sağmal%' OR h.grup ILIKE '%sagmal%'
           OR h.grup ILIKE '%kuru%' THEN 'İnek'
      ELSE 'Bilinmiyor'
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

-- ═══ 2. stat_suru_ozet v3 — 42-gün kuralı + sperma_all ═══
DROP FUNCTION IF EXISTS public.stat_suru_ozet(text, boolean);

CREATE OR REPLACE FUNCTION public.stat_suru_ozet(
  p_padok     text    DEFAULT NULL,
  p_son_donem boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan   jsonb;
  v_gebelik  jsonb;
BEGIN
  -- ── Hayvan demografisi ──
  SELECT jsonb_build_object(
    'toplam', COUNT(*),
    'inek',   COUNT(*) FILTER (WHERE
                grup ILIKE '%inek%' OR grup LIKE '%İnek%'
                OR grup ILIKE '%sağmal%' OR grup ILIKE '%sagmal%'
                OR grup ILIKE '%kuru%'
                OR EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id)),
    'duve',   COUNT(*) FILTER (WHERE
                (grup ILIKE '%düve%' OR grup ILIKE '%duve%')
                AND NOT EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id)),
    'buzagi', COUNT(*) FILTER (WHERE grup ILIKE '%buzağı%' OR grup ILIKE '%buzagi%'),
    'erkek',  COUNT(*) FILTER (WHERE cinsiyet = 'Erkek'),
    'kisir',  COUNT(*) FILTER (WHERE kisir = true),
    'hasta',  (SELECT COUNT(DISTINCT c.animal_id)
               FROM public.cases c
               JOIN public.hayvanlar h2 ON h2.id = c.animal_id
               WHERE c.status = 'active'
                 AND h2.durum = 'Aktif'
                 AND (p_padok IS NULL OR h2.padok = p_padok)),
    'tohumlanan', (SELECT COUNT(DISTINCT t2.hayvan_id)
                   FROM public.tohumlama t2
                   JOIN public.hayvanlar h3 ON h3.id = t2.hayvan_id
                   WHERE h3.durum = 'Aktif'
                     AND h3.cinsiyet = 'Dişi'
                     AND (p_padok IS NULL OR h3.padok = p_padok))
  ) INTO v_hayvan
  FROM public.hayvanlar h
  WHERE h.durum = 'Aktif'
    AND (p_padok IS NULL OR h.padok = p_padok);

  -- ── Cycle-bazlı gebelik istatistikleri (42-gün kuralı uygulanmış) ──
  WITH cycles AS (
    SELECT
      v.hayvan_id, v.kategori, v.sonuc, v.deneme_sayisi,
      v.gebe_sperma, v.son_sperma, v.cycle_no, v.baslangic
    FROM public.v_ureme_dongusu v
    WHERE v.durum = 'Aktif'
      AND (p_padok IS NULL OR v.padok = p_padok)
      AND v.baslangic < CURRENT_DATE - 42
      AND (
        NOT p_son_donem
        OR NOT EXISTS (
          SELECT 1 FROM public.v_ureme_dongusu v2
          WHERE v2.hayvan_id = v.hayvan_id
            AND v2.cycle_no > v.cycle_no
            AND v2.sonuc IN ('Gebe','Doğum Yaptı')
        )
      )
  ),
  hayvan_stat AS (
    SELECT DISTINCT ON (hayvan_id)
      hayvan_id, kategori, sonuc AS son_sonuc
    FROM cycles
    ORDER BY hayvan_id, cycle_no DESC
  )
  SELECT jsonb_build_object(
    'hayvan_ozet', jsonb_build_object(
      'toplam', COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc != 'Bekliyor'),
      'gebe',   COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc = 'Gebe'),
      'bos',    COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc IN ('Boş','Abort')),
      'devam_eden', (SELECT COUNT(DISTINCT v3.hayvan_id)
                     FROM public.v_ureme_dongusu v3
                     WHERE v3.durum = 'Aktif'
                       AND (p_padok IS NULL OR v3.padok = p_padok)
                       AND v3.sonuc = 'Bekliyor'),
      'oran',   ROUND(
                  100.0 * COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc = 'Gebe')
                  / NULLIF(COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc != 'Bekliyor'), 0), 1)
    ),
    'cycle_ozet', (
      SELECT jsonb_build_object(
        'toplam_cycle', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
        'basarili',     COUNT(*) FILTER (WHERE sonuc = 'Gebe'),
        'basarisiz',    COUNT(*) FILTER (WHERE sonuc IN ('Boş','Abort')),
        'devam_eden',   (SELECT COUNT(*)
                         FROM public.v_ureme_dongusu v4
                         WHERE v4.durum = 'Aktif'
                           AND (p_padok IS NULL OR v4.padok = p_padok)
                           AND v4.sonuc = 'Bekliyor'),
        'oran',         ROUND(
                          100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe')
                          / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1),
        'ort_deneme',   ROUND(
                          AVG(deneme_sayisi) FILTER (WHERE sonuc = 'Gebe'), 1)
      ) FROM cycles
    ),
    'kategori', (
      SELECT COALESCE(jsonb_agg(row_j ORDER BY row_j->>'ad'), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'ad', hs.kategori,
          'hayvan_toplam', COUNT(*) FILTER (WHERE hs.son_sonuc != 'Bekliyor'),
          'hayvan_gebe',   COUNT(*) FILTER (WHERE hs.son_sonuc = 'Gebe'),
          'hayvan_oran',   ROUND(
                             100.0 * COUNT(*) FILTER (WHERE hs.son_sonuc = 'Gebe')
                             / NULLIF(COUNT(*) FILTER (WHERE hs.son_sonuc != 'Bekliyor'), 0), 1),
          'cycle_toplam',  (SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc != 'Bekliyor'),
          'cycle_basarili',(SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc = 'Gebe'),
          'cycle_oran',    ROUND(
                             100.0 * (SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc = 'Gebe')
                             / NULLIF((SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc != 'Bekliyor'), 0), 1)
        ) AS row_j
        FROM hayvan_stat hs
        GROUP BY hs.kategori
      ) sub
    ),
    'sperma_all', (
      SELECT COALESCE(jsonb_agg(row_j), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'ad', COALESCE(gebe_sperma, son_sperma),
          'cycle_toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
          'cycle_basarili', COUNT(*) FILTER (WHERE sonuc = 'Gebe'),
          'cycle_oran', ROUND(
                          100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe')
                          / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)
        ) AS row_j
        FROM cycles
        WHERE sonuc != 'Bekliyor'
        GROUP BY COALESCE(gebe_sperma, son_sperma)
        HAVING COUNT(*) >= 3
        ORDER BY ROUND(
                   100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe')
                   / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1) DESC
      ) sub
    ),
    'deneme', (
      SELECT COALESCE(jsonb_agg(row_j ORDER BY (row_j->>'no')::int), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'no', deneme_sayisi,
          'gebe',   COUNT(*) FILTER (WHERE sonuc = 'Gebe'),
          'toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
          'oran',   ROUND(
                      100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe')
                      / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)
        ) AS row_j
        FROM cycles
        WHERE sonuc != 'Bekliyor'
        GROUP BY deneme_sayisi
      ) sub
    )
  ) INTO v_gebelik
  FROM hayvan_stat;

  RETURN jsonb_build_object(
    'hayvan', COALESCE(v_hayvan, '{"toplam":0,"inek":0,"duve":0,"buzagi":0,"erkek":0,"kisir":0,"hasta":0,"tohumlanan":0}'::jsonb),
    'gebelik', COALESCE(v_gebelik, '{"hayvan_ozet":{"toplam":0,"gebe":0,"bos":0,"devam_eden":0,"oran":null},"cycle_ozet":{"toplam_cycle":0,"basarili":0,"basarisiz":0,"devam_eden":0,"oran":null,"ort_deneme":null},"kategori":[],"sperma_all":[],"deneme":[]}'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.stat_suru_ozet(text, boolean) TO anon, authenticated;
