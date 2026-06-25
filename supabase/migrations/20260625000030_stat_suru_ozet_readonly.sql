-- Migration: stat_suru_ozet salt-okuma (sessiz yazma yan etkisi kaldırıldı)
-- Tarih: 2026-06-25 — Spec §6. 3 değişiklik: DECLARE + jeneratör çağrısı kaldırıldı,
--           sessiz count eski COALESCE → düz e.sessiz_gun >= 55. Gövde geri kalanı canlıyla birebir.
CREATE OR REPLACE FUNCTION public.stat_suru_ozet(p_padok text DEFAULT NULL::text, p_son_donem boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_hayvan    jsonb;
  v_gebelik   jsonb;
  v_verim     jsonb;
  v_sperma_pi jsonb;
BEGIN
  SELECT jsonb_build_object(
    'toplam', COUNT(*),
    'inek',   COUNT(*) FILTER (WHERE grup ILIKE '%inek%' OR grup LIKE '%İnek%' OR grup ILIKE '%sağmal%' OR grup ILIKE '%sagmal%' OR grup ILIKE '%kuru%' OR EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id)),
    'duve',   COUNT(*) FILTER (WHERE (grup ILIKE '%düve%' OR grup ILIKE '%duve%') AND NOT EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id)),
    'buzagi', COUNT(*) FILTER (WHERE grup ILIKE '%buzağı%' OR grup ILIKE '%buzagi%'),
    'erkek',  COUNT(*) FILTER (WHERE cinsiyet = 'Erkek'),
    'kisir',  COUNT(*) FILTER (WHERE kisir = true),
    'hasta',  (SELECT COUNT(DISTINCT c.animal_id) FROM public.cases c JOIN public.hayvanlar h2 ON h2.id = c.animal_id WHERE c.status = 'active' AND h2.durum = 'Aktif' AND (p_padok IS NULL OR h2.padok = p_padok)),
    'tohumlanan', (SELECT COUNT(DISTINCT t2.hayvan_id) FROM public.tohumlama t2 JOIN public.hayvanlar h3 ON h3.id = t2.hayvan_id WHERE h3.durum = 'Aktif' AND h3.cinsiyet = 'Dişi' AND (p_padok IS NULL OR h3.padok = p_padok)),
    'sessiz', (SELECT COUNT(*) FROM public.v_eligible e WHERE (p_padok IS NULL OR e.padok = p_padok) AND e.sessiz_gun >= 55),
    'belirsiz', (SELECT COUNT(*) FROM public.hayvanlar hb
                 WHERE hb.cinsiyet = 'Dişi' AND hb.durum = 'Aktif' AND hb.kisir IS NOT TRUE
                   AND hb.genc_anne IS NULL
                   AND NOT (hb.grup ILIKE '%düve%' OR hb.grup ILIKE '%duve%')
                   AND (SELECT COUNT(*) FROM public.dogum d WHERE d.anne_id = hb.id) < 2
                   AND EXISTS (SELECT 1 FROM public.tohumlama t WHERE t.hayvan_id = hb.id)
                   AND (p_padok IS NULL OR hb.padok = p_padok))
  ) INTO v_hayvan
  FROM public.hayvanlar h
  WHERE h.durum = 'Aktif' AND (p_padok IS NULL OR h.padok = p_padok);
  WITH cycles AS (
    SELECT v.hayvan_id, v.kategori, v.sonuc, v.deneme_sayisi, v.gebe_sperma, v.son_sperma, v.cycle_no, v.baslangic
    FROM public.v_ureme_dongusu v
    WHERE v.durum = 'Aktif' AND (p_padok IS NULL OR v.padok = p_padok) AND v.baslangic < CURRENT_DATE - 42
    AND (NOT p_son_donem OR NOT EXISTS (SELECT 1 FROM public.v_ureme_dongusu v2 WHERE v2.hayvan_id = v.hayvan_id AND v2.cycle_no > v.cycle_no AND v2.sonuc IN ('Gebe','Doğum Yaptı')))
  ),
  hayvan_stat AS (SELECT DISTINCT ON (hayvan_id) hayvan_id, kategori, sonuc AS son_sonuc FROM cycles ORDER BY hayvan_id, cycle_no DESC)
  SELECT jsonb_build_object(
    'hayvan_ozet', jsonb_build_object(
      'toplam', COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc != 'Bekliyor'),
      'gebe',   COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc = 'Gebe'),
      'bos',    COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc IN ('Boş','Abort')),
      'devam_eden', (SELECT COUNT(DISTINCT v3.hayvan_id) FROM public.v_ureme_dongusu v3 WHERE v3.durum = 'Aktif' AND (p_padok IS NULL OR v3.padok = p_padok) AND v3.sonuc = 'Bekliyor'),
      'oran', ROUND(100.0 * COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc = 'Gebe') / NULLIF(COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc != 'Bekliyor'), 0), 1)
    ),
    'cycle_ozet', (SELECT jsonb_build_object('toplam_cycle', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 'basarili', COUNT(*) FILTER (WHERE sonuc = 'Gebe'), 'basarisiz', COUNT(*) FILTER (WHERE sonuc IN ('Boş','Abort')), 'devam_eden', (SELECT COUNT(*) FROM public.v_ureme_dongusu v4 WHERE v4.durum = 'Aktif' AND (p_padok IS NULL OR v4.padok = p_padok) AND v4.sonuc = 'Bekliyor'), 'oran', ROUND(100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe') / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1), 'ort_deneme', ROUND(AVG(deneme_sayisi) FILTER (WHERE sonuc = 'Gebe'), 1)) FROM cycles),
    'kategori', (SELECT COALESCE(jsonb_agg(row_j ORDER BY row_j->>'ad'), '[]'::jsonb) FROM (SELECT jsonb_build_object('ad', hs.kategori, 'hayvan_toplam', COUNT(*) FILTER (WHERE hs.son_sonuc != 'Bekliyor'), 'hayvan_gebe', COUNT(*) FILTER (WHERE hs.son_sonuc = 'Gebe'), 'hayvan_oran', ROUND(100.0 * COUNT(*) FILTER (WHERE hs.son_sonuc = 'Gebe') / NULLIF(COUNT(*) FILTER (WHERE hs.son_sonuc != 'Bekliyor'), 0), 1), 'cycle_toplam', (SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc != 'Bekliyor'), 'cycle_basarili', (SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc = 'Gebe'), 'cycle_oran', ROUND(100.0 * (SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc = 'Gebe') / NULLIF((SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc != 'Bekliyor'), 0), 1)) AS row_j FROM hayvan_stat hs GROUP BY hs.kategori) sub),
    'sperma_all', (SELECT COALESCE(jsonb_agg(row_j), '[]'::jsonb) FROM (SELECT jsonb_build_object('ad', COALESCE(gebe_sperma, son_sperma), 'cycle_toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 'cycle_basarili', COUNT(*) FILTER (WHERE sonuc = 'Gebe'), 'cycle_oran', ROUND(100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe') / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)) AS row_j FROM cycles WHERE sonuc != 'Bekliyor' GROUP BY COALESCE(gebe_sperma, son_sperma) HAVING COUNT(*) >= 3 ORDER BY ROUND(100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe') / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1) DESC) sub),
    'deneme', (SELECT COALESCE(jsonb_agg(row_j ORDER BY (row_j->>'no')::int), '[]'::jsonb) FROM (SELECT jsonb_build_object('no', deneme_sayisi, 'gebe', COUNT(*) FILTER (WHERE sonuc = 'Gebe'), 'toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 'oran', ROUND(100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe') / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)) AS row_j FROM cycles WHERE sonuc != 'Bekliyor' GROUP BY deneme_sayisi) sub)
  ) INTO v_gebelik
  FROM hayvan_stat;

  WITH basari AS (
    SELECT v.hayvan_id, v.kategori, 1.0 / NULLIF(v.deneme_sayisi, 0) AS skor
    FROM public.v_ureme_dongusu v
    WHERE v.durum = 'Aktif' AND v.sonuc = 'Gebe' AND v.deneme_sayisi >= 1
      AND (p_padok IS NULL OR v.padok = p_padok)
  ),
  per_animal AS (SELECT hayvan_id, kategori, AVG(skor) AS animal_skor FROM basari GROUP BY hayvan_id, kategori),
  ham AS (
    SELECT
      CASE
        WHEN ic.cycle_no >= 2 THEN 'İnek'
        WHEN ic.h_genc_anne = true  THEN 'Düve'
        WHEN ic.h_genc_anne = false THEN 'İnek'
        WHEN ic.h_grup ILIKE '%düve%' OR ic.h_grup ILIKE '%duve%' THEN 'Düve'
        WHEN ic.dogum_sayisi >= 2 THEN 'Düve'
        ELSE 'İnek'
      END AS kategori,
      COUNT(*) FILTER (WHERE ic.sonuc <> 'Bekliyor')             AS tohumlama,
      COUNT(*) FILTER (WHERE ic.sonuc IN ('Gebe','Doğum Yaptı')) AS gebe,
      COUNT(*) FILTER (WHERE ic.sonuc IN ('Boş','Abort'))        AS bos,
      COUNT(*) FILTER (WHERE ic.sonuc = 'Bekliyor')              AS bekliyor
    FROM (
      SELECT t.sonuc,
        SUM(CASE WHEN t.deneme_no = 1 THEN 1 ELSE 0 END)
          OVER (PARTITION BY t.hayvan_id ORDER BY t.tarih, t.deneme_no ROWS UNBOUNDED PRECEDING) AS cycle_no,
        h.genc_anne AS h_genc_anne, h.grup AS h_grup,
        (SELECT COUNT(*) FROM public.dogum d WHERE d.anne_id = h.id) AS dogum_sayisi
      FROM public.tohumlama t
      JOIN public.hayvanlar h ON h.id = t.hayvan_id
      WHERE h.cinsiyet = 'Dişi' AND h.durum = 'Aktif' AND h.kisir IS NOT TRUE
        AND (p_padok IS NULL OR h.padok = p_padok)
    ) ic
    GROUP BY 1
  )
  SELECT jsonb_object_agg(grp, payload) INTO v_verim
  FROM (
    SELECT
      CASE WHEN ks.k = 'Düve' THEN 'duve' ELSE 'inek' END AS grp,
      jsonb_build_object(
        'ham', jsonb_build_object(
          'tohumlama', COALESCE(hm.tohumlama, 0), 'gebe', COALESCE(hm.gebe, 0),
          'bos', COALESCE(hm.bos, 0), 'bekliyor', COALESCE(hm.bekliyor, 0),
          'cr', ROUND(100.0 * COALESCE(hm.gebe, 0) / NULLIF(hm.tohumlama, 0), 1)
        ),
        'hayvan_ort',   (SELECT ROUND(100.0 * AVG(animal_skor), 1) FROM per_animal pa WHERE pa.kategori = ks.k),
        'hayvan_sayisi',(SELECT COUNT(*) FROM per_animal pa WHERE pa.kategori = ks.k),
        'cycle_ort',    (SELECT ROUND(100.0 * AVG(skor), 1) FROM basari b WHERE b.kategori = ks.k),
        'cycle_sayisi', (SELECT COUNT(*) FROM basari b WHERE b.kategori = ks.k)
      ) AS payload
    FROM (SELECT unnest(ARRAY['Düve','İnek']) AS k) ks
    LEFT JOIN ham hm ON hm.kategori = ks.k
  ) z;

  SELECT COALESCE(jsonb_agg(row_j ORDER BY (row_j->>'oran')::numeric DESC NULLS LAST), '[]'::jsonb)
  INTO v_sperma_pi
  FROM (
    SELECT jsonb_build_object('ad', sp, 'toplam', toplam, 'gebe', gebe, 'oran', ROUND(100.0 * gebe / NULLIF(toplam, 0), 1)) AS row_j
    FROM (
      SELECT LOWER(TRIM(split_part(t.sperma, '|', 1))) AS sp,
        COUNT(*) FILTER (WHERE t.sonuc <> 'Bekliyor') AS toplam,
        COUNT(*) FILTER (WHERE t.sonuc IN ('Gebe','Doğum Yaptı')) AS gebe
      FROM public.tohumlama t
      JOIN public.hayvanlar h ON h.id = t.hayvan_id
      WHERE h.cinsiyet = 'Dişi' AND h.durum = 'Aktif' AND h.kisir IS NOT TRUE
        AND (p_padok IS NULL OR h.padok = p_padok)
        AND t.sperma IS NOT NULL AND TRIM(t.sperma) <> ''
      GROUP BY 1
      HAVING COUNT(*) FILTER (WHERE t.sonuc <> 'Bekliyor') >= 3
    ) s
  ) q;

  v_gebelik := COALESCE(v_gebelik, '{"hayvan_ozet":{"toplam":0,"gebe":0,"bos":0,"devam_eden":0,"oran":null},"cycle_ozet":{"toplam_cycle":0,"basarili":0,"basarisiz":0,"devam_eden":0,"oran":null,"ort_deneme":null},"kategori":[],"sperma_all":[],"deneme":[]}'::jsonb)
    || jsonb_build_object('ureme_verimlilik', COALESCE(v_verim, '{}'::jsonb), 'sperma_pi', COALESCE(v_sperma_pi, '[]'::jsonb));

  RETURN jsonb_build_object(
    'hayvan', COALESCE(v_hayvan, '{"toplam":0,"inek":0,"duve":0,"buzagi":0,"erkek":0,"kisir":0,"hasta":0,"tohumlanan":0,"sessiz":0,"belirsiz":0}'::jsonb),
    'gebelik', v_gebelik
  );
END;
$function$