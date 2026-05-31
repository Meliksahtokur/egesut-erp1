-- Faz C: Eligible view + Sessiz hayvanlar RPC'leri + dashboard kartı

-- ═══ 1. v_eligible view ═══
CREATE OR REPLACE VIEW public.v_eligible AS
SELECT
  h.id,
  h.kupe_no,
  h.grup,
  h.padok,
  son_dogum.tarih                    AS son_dogum_tarihi,
  CURRENT_DATE - son_dogum.tarih     AS dogum_gun,
  son_aktivite.tarih                 AS son_aktivite_tarihi,
  CASE
    WHEN son_aktivite.tarih IS NOT NULL THEN CURRENT_DATE - son_aktivite.tarih
    WHEN son_dogum.tarih IS NOT NULL THEN CURRENT_DATE - son_dogum.tarih
    ELSE NULL
  END                                AS sessiz_gun
FROM public.hayvanlar h
LEFT JOIN LATERAL (
  SELECT MAX(d.tarih) AS tarih
  FROM public.dogum d
  WHERE d.anne_id = h.id
) son_dogum ON true
LEFT JOIN LATERAL (
  SELECT MAX(tarih) AS tarih
  FROM (
    SELECT tarih FROM public.tohumlama WHERE hayvan_id = h.id
    UNION ALL
    SELECT tarih FROM public.kizginlik_log WHERE hayvan_id = h.id
  ) aktivite
) son_aktivite ON true
WHERE h.cinsiyet = 'Dişi'
  AND h.durum = 'Aktif'
  AND h.kisir IS NOT TRUE
  AND NOT EXISTS (
    SELECT 1 FROM public.tohumlama t
    WHERE t.hayvan_id = h.id AND t.sonuc = 'Gebe'
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.cases c
    WHERE c.animal_id = h.id AND c.status = 'active'
  )
  AND (
    son_dogum.tarih IS NULL
    OR son_dogum.tarih < CURRENT_DATE - 55
  );

GRANT SELECT ON public.v_eligible TO anon, authenticated;

-- ═══ 2. sessiz_hayvanlar_listele ═══
CREATE OR REPLACE FUNCTION public.sessiz_hayvanlar_listele(
  p_padok   text    DEFAULT NULL,
  p_min_gun integer DEFAULT 60
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN (
    SELECT COALESCE(jsonb_agg(
      jsonb_build_object(
        'hayvan_id', e.id,
        'kupe_no', e.kupe_no,
        'grup', e.grup,
        'padok', e.padok,
        'sessiz_gun', COALESCE(e.sessiz_gun, 9999),
        'son_aktivite', e.son_aktivite_tarihi
      ) ORDER BY COALESCE(e.sessiz_gun, 9999) DESC
    ), '[]'::jsonb)
    FROM public.v_eligible e
    WHERE (p_padok IS NULL OR e.padok = p_padok)
      AND COALESCE(e.sessiz_gun, 9999) >= p_min_gun
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sessiz_hayvanlar_listele(text, integer) TO anon, authenticated;

-- ═══ 3. sessiz_hayvanlar_gorev_olustur ═══
CREATE OR REPLACE FUNCTION public.sessiz_hayvanlar_gorev_olustur()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count integer := 0;
  v_rec   record;
BEGIN
  FOR v_rec IN
    SELECT e.id, e.kupe_no, e.sessiz_gun
    FROM public.v_eligible e
    WHERE COALESCE(e.sessiz_gun, 9999) >= 60
      AND NOT EXISTS (
        SELECT 1 FROM public.gorev_log g
        WHERE g.hayvan_id = e.id
          AND g.gorev_tipi = 'VETERINER_KONTROL'
          AND g.tamamlandi = false
      )
  LOOP
    INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
    VALUES (
      gen_random_uuid(),
      v_rec.id,
      'VETERINER_KONTROL',
      format('Sessiz hayvan: %s gündür üreme aktivitesi yok (%s)', COALESCE(v_rec.sessiz_gun, 0), v_rec.kupe_no),
      CURRENT_DATE,
      false
    );
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.sessiz_hayvanlar_gorev_olustur() TO anon, authenticated;

-- ═══ 4. stat_suru_ozet'e sessiz tetikleme ekle ═══
-- NOT: stat_suru_ozet v3 zaten Faz A'da yeniden yazıldı.
-- Burada sadece fonksiyon sonuna sessiz görev tetikleme ekliyoruz.

CREATE OR REPLACE FUNCTION public.stat_suru_ozet(
  p_padok     text    DEFAULT NULL,
  p_son_donem boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan   jsonb;
  v_gebelik  jsonb;
  v_sessiz   integer;
BEGIN
  -- Sessiz hayvanlar görev oluştur (side effect)
  SELECT sessiz_hayvanlar_gorev_olustur() INTO v_sessiz;

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
                     AND (p_padok IS NULL OR h3.padok = p_padok)),
    'sessiz', (SELECT COUNT(*) FROM public.v_eligible e
               WHERE (p_padok IS NULL OR e.padok = p_padok)
                 AND COALESCE(e.sessiz_gun, 9999) >= 60)
  ) INTO v_hayvan
  FROM public.hayvanlar h
  WHERE h.durum = 'Aktif'
    AND (p_padok IS NULL OR h.padok = p_padok);

  -- ── Cycle-bazlı gebelik istatistikleri (42-gün kuralı) ──
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
    'hayvan', COALESCE(v_hayvan, '{"toplam":0,"inek":0,"duve":0,"buzagi":0,"erkek":0,"kisir":0,"hasta":0,"tohumlanan":0,"sessiz":0}'::jsonb),
    'gebelik', COALESCE(v_gebelik, '{"hayvan_ozet":{"toplam":0,"gebe":0,"bos":0,"devam_eden":0,"oran":null},"cycle_ozet":{"toplam_cycle":0,"basarili":0,"basarisiz":0,"devam_eden":0,"oran":null,"ort_deneme":null},"kategori":[],"sperma_all":[],"deneme":[]}'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.stat_suru_ozet(text, boolean) TO anon, authenticated;
