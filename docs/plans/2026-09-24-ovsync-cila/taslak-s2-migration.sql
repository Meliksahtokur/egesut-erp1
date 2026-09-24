-- ════════════════════════════════════════════════════════════════════
-- S2 TASLAK — Sessiz sınıflandırma: eşik 55→50, kapsam Boş+bilinmeyen,
-- Bekliyor ≥40g gebelik muayenesi akışı + izole vurgulu liste (M3)
-- Tarih: 2026-09-24 · Spec: docs/plans/2026-09-24-ovsync-cila/spec-s2.md
--
-- KURALLAR:
--  · Yalnız DEMO'ya uygulanır (sahip onaylı); prod ayrı sahip kapısıdır.
--  · anon GRANT YAZILMAZ (20260915000001 genel kalkanı korunur);
--    yeni RPC'ler: REVOKE FROM PUBLIC, anon + GRANT TO authenticated, service_role
--    (20260924000001 deseni).
--  · v_eligible baz tanımı = GÜNCEL canlı tanım (20260831000002_duve_sessiz_13ay.sql);
--    20260531400000 gövdesi BAZ ALINMAZ (baz-tanım kuralı, plan-4 M1).
--  · Bekliyor hariç tutma SAHİP KAPSAM KURALININ birebir karşılığıdır:
--    "sessiz kapsam yalnız Boş + durumu bilinmeyen" (sentez §5A) — Bekliyor
--    hayvanın sessiz havuzuna hiç girmemesi dört tüketiciyi birden doğruya çevirir.
--    40 günlük eşik yalnız muayene RPC'sinde yaşar (protokol_ayar).
-- ════════════════════════════════════════════════════════════════════

BEGIN;

-- squawk hijyeni: view/fonksiyon yeniden tanımları öncesinde timeout'lar
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ── 1) protokol_ayar seed: Bekliyor→muayene eşiği ─────────────────────
-- NOT: canlıda anahtar PK'lidir (canlı pg_constraint: protokol_ayar_pkey —
-- 20260923000002 kanıtı) ancak db-validate baseline'ı PK'yi yeniden kurmadığı
-- için ON CONFLICT yerine PK-bağımsız idempotent desen (update-önce/insert-eksikse).
UPDATE public.protokol_ayar
   SET deger = 40, birim = 'gün', min_deger = 0, max_deger = 120,
       aciklama = 'Tohumlama sonrası sessiz muafiyet penceresi; dolanlar gebelik muayenesine yönlenir',
       guncellendi = now()
 WHERE anahtar = 'sessiz_tohumlama_muafiyet_gun';
INSERT INTO public.protokol_ayar (anahtar, deger, birim, min_deger, max_deger, aciklama)
SELECT 'sessiz_tohumlama_muafiyet_gun', 40, 'gün', 0, 120,
       'Tohumlama sonrası sessiz muafiyet penceresi; dolanlar gebelik muayenesine yönlenir'
WHERE NOT EXISTS (SELECT 1 FROM public.protokol_ayar WHERE anahtar = 'sessiz_tohumlama_muafiyet_gun');

-- ── 2) v_eligible — güncel baz (20260831000002) + Bekliyor tam hariç + eşik 50 ──
CREATE OR REPLACE VIEW public.v_eligible AS
SELECT h.id,
       h.kupe_no,
       h.grup,
       h.padok,
       son_dogum.tarih AS son_dogum_tarihi,
       CURRENT_DATE - son_dogum.tarih AS dogum_gun,
       son_event.tarih AS son_aktivite_tarihi,
       CASE
           WHEN son_event.tarih IS NOT NULL THEN CURRENT_DATE - son_event.tarih
           WHEN son_dogum.tarih IS NOT NULL THEN CURRENT_DATE - son_dogum.tarih
           WHEN h.dogum_tarihi IS NOT NULL THEN GREATEST(0, CURRENT_DATE - ((h.dogum_tarihi + INTERVAL '1 year 1 mon')::date))
           ELSE NULL::integer
       END AS sessiz_gun
FROM hayvanlar h
LEFT JOIN LATERAL (SELECT max(d.tarih) AS tarih FROM dogum d WHERE d.anne_id = h.id) son_dogum ON true
LEFT JOIN LATERAL (SELECT max(ev.tarih) AS tarih FROM (
       SELECT t.tarih FROM tohumlama t WHERE t.hayvan_id = h.id
       UNION ALL
       SELECT k.tarih FROM kizginlik_log k WHERE k.hayvan_id = h.id
       UNION ALL
       SELECT t.abort_tarihi FROM tohumlama t WHERE t.hayvan_id = h.id AND t.abort_tarihi IS NOT NULL
       UNION ALL
       SELECT t.dogum_tarihi FROM tohumlama t WHERE t.hayvan_id = h.id AND t.dogum_tarihi IS NOT NULL
       UNION ALL
       SELECT d.tarih FROM dogum d WHERE d.anne_id = h.id
     ) ev) son_event ON true
WHERE h.cinsiyet = 'Dişi'::text AND h.durum = 'Aktif'::text AND h.kisir IS NOT TRUE
  AND h.grup !~~* '%buzağı%' AND h.grup !~~* '%buzagi%' AND h.grup !~~* '%Küçük%' AND h.grup !~~* '%Kucuk%'
  AND (h.dogum_tarihi IS NULL OR h.dogum_tarihi <= (CURRENT_DATE - '1 year 1 mon'::interval))
  AND NOT EXISTS (SELECT 1 FROM tohumlama t WHERE t.hayvan_id = h.id AND t.sonuc = 'Gebe'::text)
  -- S2: Bekliyor tam hariç — "Bekliyor" hayvan sessiz DEĞİLDİR; <40g muafiyet,
  -- ≥40g gebelik muayenesi akışı (gebelik_muayene_gorev_uret / _listele).
  AND NOT EXISTS (SELECT 1 FROM tohumlama t WHERE t.hayvan_id = h.id AND t.sonuc = 'Bekliyor'::text)
  -- S2: sessiz eşiği 55 → 50 (sahip kararı, sentez §5A)
  AND (son_event.tarih IS NULL OR son_event.tarih < (CURRENT_DATE - 50));

-- ── 3) sessiz_hayvanlar_listele — imza AYNI (overload yaratma!), default 55→50 ──
CREATE OR REPLACE FUNCTION public.sessiz_hayvanlar_listele(
  p_padok   text    DEFAULT NULL,
  p_min_gun integer DEFAULT 50
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

-- ── 4) sessiz_hayvanlar_reconcile — üret ve guard eşikleri 55→50 (2 nokta) ──
CREATE OR REPLACE FUNCTION public.sessiz_hayvanlar_reconcile()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_uretilen  integer := 0;
  v_kapatilan integer := 0;
  v_rec       record;
BEGIN
  -- 1) ÜRET: eligible + açık SESSIZ görevi yok + son 30 günde kullanıcı-tamamlaması yok
  FOR v_rec IN
    SELECT e.id, e.kupe_no, e.sessiz_gun
    FROM public.v_eligible e
    WHERE e.sessiz_gun >= 50
      AND NOT EXISTS (
        SELECT 1 FROM public.gorev_log g
        WHERE g.hayvan_id = e.id
          AND g.kaynak = 'SESSIZ-' || e.id
          AND g.tamamlandi = false AND g.iptal = false
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.gorev_log g
        WHERE g.hayvan_id = e.id
          AND g.kaynak = 'SESSIZ-' || e.id
          AND g.tamamlandi = true
          AND g.tamamlanma_tarihi >= (CURRENT_DATE - 30)
      )
  LOOP
    INSERT INTO public.gorev_log
      (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, iptal, kaynak)
    VALUES (
      gen_random_uuid(), v_rec.id, 'VETERINER_KONTROL',
      format('Sessiz hayvan: %s gündür üreme aktivitesi yok (%s)', v_rec.sessiz_gun, v_rec.kupe_no),
      CURRENT_DATE, false, false, 'SESSIZ-' || v_rec.id
    );
    v_uretilen := v_uretilen + 1;
  END LOOP;

  -- 2) KAPAT: açık SESSIZ görevi var ama artık eligible değil (auto-close, cooldown SAYMAZ)
  UPDATE public.gorev_log g
  SET iptal = true, kapatan_ref = 'sessiz-noteligible'
  WHERE g.gorev_tipi = 'VETERINER_KONTROL'
    AND g.kaynak LIKE 'SESSIZ-%'
    AND g.tamamlandi = false AND g.iptal = false
    AND NOT EXISTS (
      SELECT 1 FROM public.v_eligible e
      WHERE e.id = g.hayvan_id AND e.sessiz_gun >= 50
    );
  GET DIAGNOSTICS v_kapatilan = ROW_COUNT;

  RETURN jsonb_build_object('uretilen', v_uretilen, 'kapatilan', v_kapatilan, 'zaman', now());
END;
$function$;

-- ── 5) stat_suru_ozet — sessiz sayacı: eşik 55→50 + 9999-sentinel hizalaması ──
--    Canlıda listele (11) ile stat (9) FARKLI: NULL sessiz_gun COALESCE'siz
--    eleniyordu (OBSERVED 2026-09-24). COALESCE ile listele ile tutarlı.
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
    'sessiz', (SELECT COUNT(*) FROM public.v_eligible e WHERE (p_padok IS NULL OR e.padok = p_padok) AND COALESCE(e.sessiz_gun, 9999) >= 50),
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
$function$;

-- ── 6) gebelik_muayene_listele — izole vurgulu bandın/sheet bölümünün veri kaynağı ──
CREATE OR REPLACE FUNCTION public.gebelik_muayene_listele()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
BEGIN
  RETURN (
    SELECT COALESCE(jsonb_agg(row_j ORDER BY (row_j->>'bekliyor_gun')::int DESC), '[]'::jsonb)
    FROM (
      SELECT jsonb_build_object(
        'hayvan_id', h.id, 'kupe_no', h.kupe_no, 'grup', h.grup, 'padok', h.padok,
        'tohumlama_id', t.id, 'son_tohumlama_tarihi', t.tarih,
        'bekliyor_gun', CURRENT_DATE - t.tarih,
        'acik_gorev_var', EXISTS (SELECT 1 FROM public.gorev_log g
                                  WHERE g.hayvan_id = h.id AND g.gorev_tipi = 'GEBELIK_KONTROL'
                                    AND g.tamamlandi = false AND g.iptal = false)
      ) AS row_j
      FROM public.tohumlama t
      JOIN public.hayvanlar h ON h.id = t.hayvan_id
      WHERE t.sonuc = 'Bekliyor'
        AND t.tarih <= CURRENT_DATE - public._ayar('sessiz_tohumlama_muafiyet_gun', 40)::int
        AND h.cinsiyet = 'Dişi' AND h.durum = 'Aktif' AND h.kisir IS NOT TRUE
        AND t.id = (SELECT t2.id FROM public.tohumlama t2
                    WHERE t2.hayvan_id = t.hayvan_id
                    ORDER BY t2.tarih DESC NULLS LAST, t2.created_at DESC NULLS LAST
                    LIMIT 1)
      -- Onarım (final review DÜŞÜK bulgu): _uret:345-348 ile AYNI 30-gün tamamlanmış-
      -- cooldown filtresi — yakın zamanda muayenesi tamamlanan hayvan liste gürültüsü
      -- olmasın. Açık görev filtrelenmez (acik_gorev_var bayrağı ayrıştırır).
      AND NOT EXISTS (SELECT 1 FROM public.gorev_log g
                      WHERE g.kaynak = 'GEBELIK-KONTROL-' || t.id
                        AND g.tamamlandi = true
                        AND g.tamamlanma_tarihi >= (CURRENT_DATE - 30))
    ) s
  );
END;
$function$;

-- ── 7) gebelik_muayene_gorev_uret — dry-run varsayılan; onaylı koşum deseni ──
CREATE OR REPLACE FUNCTION public.gebelik_muayene_gorev_uret(p_dry_run boolean DEFAULT true)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_esik      integer := public._ayar('sessiz_tohumlama_muafiyet_gun', 40)::int;
  v_uretilen  integer := 0;
  v_liste     jsonb   := '[]'::jsonb;
  v_rec       record;
BEGIN
  FOR v_rec IN
    SELECT h.id AS hayvan_id, h.kupe_no, h.grup, h.padok,
           t.id AS tohumlama_id, t.tarih,
           (CURRENT_DATE - t.tarih) AS bekliyor_gun
    FROM public.tohumlama t
    JOIN public.hayvanlar h ON h.id = t.hayvan_id
    WHERE t.sonuc = 'Bekliyor'
      AND t.tarih <= CURRENT_DATE - v_esik
      AND h.cinsiyet = 'Dişi' AND h.durum = 'Aktif' AND h.kisir IS NOT TRUE
      AND t.id = (SELECT t2.id FROM public.tohumlama t2
                  WHERE t2.hayvan_id = t.hayvan_id
                  ORDER BY t2.tarih DESC NULLS LAST, t2.created_at DESC NULLS LAST
                  LIMIT 1)
      AND NOT EXISTS (SELECT 1 FROM public.gorev_log g
                      WHERE g.hayvan_id = h.id AND g.gorev_tipi = 'GEBELIK_KONTROL'
                        AND g.tamamlandi = false AND g.iptal = false)
      AND NOT EXISTS (SELECT 1 FROM public.gorev_log g
                      WHERE g.kaynak = 'GEBELIK-KONTROL-' || t.id
                        AND g.tamamlandi = true
                        AND g.tamamlanma_tarihi >= (CURRENT_DATE - 30))
    ORDER BY bekliyor_gun DESC
  LOOP
    v_liste := v_liste || jsonb_build_object(
      'hayvan_id', v_rec.hayvan_id, 'kupe_no', v_rec.kupe_no,
      'grup', v_rec.grup, 'padok', v_rec.padok,
      'tohumlama_id', v_rec.tohumlama_id, 'son_tohumlama_tarihi', v_rec.tarih,
      'bekliyor_gun', v_rec.bekliyor_gun);
    IF NOT p_dry_run THEN
      -- ref_tohumlama_id TEXT kolonudur (canlı information_schema OBSERVED 2026-09-24;
      -- 20260522000002:L23) → tohumlama.id uuid için ::text kuralı (20260522000004:L137 deseni).
      INSERT INTO public.gorev_log
        (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, iptal, kaynak, ref_tohumlama_id)
      VALUES (
        gen_random_uuid(), v_rec.hayvan_id, 'GEBELIK_KONTROL',
        format('🔬 Gebelik muayenesi: %s. gün Bekliyor (%s)', v_rec.bekliyor_gun, v_rec.kupe_no),
        CURRENT_DATE, false, false, 'GEBELIK-KONTROL-' || v_rec.tohumlama_id, v_rec.tohumlama_id::text);
      v_uretilen := v_uretilen + 1;
    END IF;
  END LOOP;
  RETURN jsonb_build_object(
    'dry_run', p_dry_run,
    'esik_gun', v_esik,
    'adet', jsonb_array_length(v_liste),
    'uretilen', v_uretilen,
    'liste', v_liste,
    'zaman', now());
END;
$function$;

-- ── 8) ACL — anon/PUBLIC kapalı kalır (20260915000001 kapanışı), authenticated açık ──
REVOKE ALL ON FUNCTION public.sessiz_hayvanlar_listele(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sessiz_hayvanlar_listele(text, integer) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.sessiz_hayvanlar_reconcile() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sessiz_hayvanlar_reconcile() TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.stat_suru_ozet(text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.stat_suru_ozet(text, boolean) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.gebelik_muayene_listele() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.gebelik_muayene_listele() TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.gebelik_muayene_gorev_uret(boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.gebelik_muayene_gorev_uret(boolean) TO service_role;
-- not: _uret yalnız cron+service_role; UI/_uret çağrısı yok, dry-run raporu
-- service_role bağlamıyla (psql/MCP) alınır. İstenirse sahibe authenticated açılır.

-- ── 9) cron — reconcile 05:00'ten SONRA (SESSIZ kapama → muayene üretim sırası) ──
-- pg_cron koruması: doğrulama baseline'ında pg_cron yok; canlıda var.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'gebelik-muayene-daily') THEN
      PERFORM cron.unschedule('gebelik-muayene-daily');
    END IF;
    PERFORM cron.schedule('gebelik-muayene-daily', '10 5 * * *', 'SELECT public.gebelik_muayene_gorev_uret(false)');
  ELSE
    RAISE NOTICE 'pg_cron yok — gebelik-muayene-daily zamanlanmadi (canli ortamda pg_cron mevcut)';
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
COMMIT;
