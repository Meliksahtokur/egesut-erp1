-- ============================================================================
-- Migration: 20261005000005_stat_protokol_disla
-- 2026-10-06 · istatistik F1 T3b (S3; spec §5.3 [F1 ruling]; domain-rules §8; R31). İleri düzeltme:
--   000002-000004 dosyalarına dokunulmaz.
-- Etkiler: v_stat_vaka CREATE OR REPLACE (kolon şekli aynı): protokol vakası (protocol_family dolu ya da
--   adı ILIKE '%ovsync%') view'da ve nüks "sonraki vaka"sında yok. Yeni stat_tedavi_dislanan_dipnot;
--   üç ölçüm CREATE OR REPLACE (gövde 000003/000004 kopyası; fark dipnot birleştirmesi + surum
--   'sql:20261005000005'); stat_olcum_kayit surum UPDATE.
-- Dipnot: (a) dönemde protokol vakası k>0, hastalik/kategori filtresizken; (b) seçimde closed_at'i ≥3 vakayla
--   (cases geneli) paylaşan k>0. Seçim: dönem + hastalik/kategori (+ protokol etiketi, R30).
-- INVOKER, search_path, ACL R8; TZ, CURRENT_DATE yasağı, fail-closed, K8 değişmez.
-- Idempotent. Geri alma: 000002→000004 yeniden psql -f; DROP FUNCTION stat_tedavi_dislanan_dipnot.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE VIEW public.v_stat_vaka WITH (security_invoker = true) AS
WITH uygulama AS (
  -- tedavi günü × uygulama satırı (uygulaması olmayan gün de plan_gun için kalır)
  SELECT td.case_id,
         td.id AS gun_id,
         td.treatment_date,
         (a.id IS NOT NULL AND a.uygulanmadi IS NOT TRUE) AS uygulandi,
         COALESCE(dp.brand_name, s.urun_adi) AS urun,
         COALESCE(dc.class_name, dc.group_name) AS sinif,
         CASE WHEN s.maliyet > 0 THEN a.dose * s.maliyet END AS maliyet_katki
  FROM public.treatment_days td
  LEFT JOIN public.drug_administrations a ON a.treatment_day_id = td.id
  LEFT JOIN public.drug_products dp ON dp.id = a.drug_product_id
  LEFT JOIN public.drug_classes dc ON dc.id = dp.drug_class_id
  LEFT JOIN public.stok s ON s.id = a.stok_id
), vaka_uygulama AS (
  SELECT u.case_id,
         count(DISTINCT u.gun_id) AS plan_gun,
         count(DISTINCT u.treatment_date) FILTER (WHERE u.uygulandi) AS uygulanan_gun,
         min(u.treatment_date) FILTER (WHERE u.uygulandi) AS ilk_uygulama,
         max(u.treatment_date) FILTER (WHERE u.uygulandi) AS son_uygulama,
         array_agg(DISTINCT u.urun ORDER BY u.urun)
           FILTER (WHERE u.uygulandi AND u.urun IS NOT NULL) AS protokol,
         array_agg(DISTINCT u.sinif ORDER BY u.sinif)
           FILTER (WHERE u.uygulandi AND u.sinif IS NOT NULL) AS protokol_sinif,
         sum(u.maliyet_katki) FILTER (WHERE u.uygulandi) AS maliyet_tl
  FROM uygulama u
  GROUP BY u.case_id
), kapanisli AS (
  SELECT c.id, c.animal_id, c.disease_id, c.start_date, c.status, c.protocol_family,
         CASE WHEN c.status = 'closed'
              THEN (c.closed_at AT TIME ZONE 'Europe/Istanbul')::date END AS kapanis
  FROM public.cases c
  LEFT JOIN public.diseases pd ON pd.id = c.disease_id
  WHERE c.protocol_family IS NULL AND coalesce(pd.name, '') NOT ILIKE '%ovsync%'   -- R31: protokol vakası dışarıda
), olayli AS (
  SELECT k.*,
         CASE WHEN k.kapanis >= k.start_date THEN k.kapanis - k.start_date END AS vaka_suresi_gun,
         h.cikis_tipi, h.cikis_tarihi,
         (SELECT min(n.start_date)                        -- R12: (kapanis, kapanis+30] içinde ilk nüks
            FROM public.cases n
           WHERE n.animal_id = k.animal_id AND n.disease_id = k.disease_id AND n.id <> k.id
             AND n.start_date > k.kapanis AND n.start_date <= k.kapanis + 30
             AND n.protocol_family IS NULL) AS nuks_baslangic  -- R31 (ad kolu: disease_id k ile aynı)
  FROM kapanisli k
  LEFT JOIN public.hayvanlar h ON h.id = k.animal_id
), sonuclu AS (
  SELECT o.*,
         CASE                                             -- spec §5.2 sırası, ilk eşleşen kazanır
           WHEN o.cikis_tipi IN ('olum', 'kesim')
                AND (o.status = 'active' OR o.cikis_tarihi <= o.kapanis + 30) THEN 'oldu_kesildi'
           WHEN o.nuks_baslangic IS NOT NULL THEN 'nuks'
           WHEN o.status = 'closed' THEN 'iyilesti'
           ELSE 'devam'
         END AS sonuc
  FROM olayli o
), olay_hesap AS (
  SELECT s.*,
         CASE s.sonuc
           WHEN 'oldu_kesildi' THEN s.cikis_tarihi - s.start_date
           WHEN 'nuks'         THEN s.nuks_baslangic - s.start_date
           WHEN 'iyilesti'     THEN s.vaka_suresi_gun
           ELSE (now() AT TIME ZONE 'Europe/Istanbul')::date - s.start_date
         END AS olay_ham
  FROM sonuclu s
)
SELECT v.id::uuid                                        AS vaka_id,
       v.animal_id::text                                 AS hayvan_id,
       d.name::text                                      AS hastalik,
       d.category::text                                  AS kategori,
       v.protocol_family::text                           AS protokol_ailesi,
       v.start_date::date                                AS baslangic,
       v.kapanis::date                                   AS kapanis,
       v.vaka_suresi_gun::int                            AS vaka_suresi_gun,
       vu.ilk_uygulama::date                             AS ilk_uygulama,
       vu.son_uygulama::date                             AS son_uygulama,
       (vu.son_uygulama - vu.ilk_uygulama + 1)::int      AS tedavi_suresi_gun,
       COALESCE(vu.uygulanan_gun, 0)::int                AS uygulanan_gun,
       COALESCE(vu.plan_gun, 0)::int                     AS plan_gun,
       (CASE WHEN vu.uygulanan_gun > 0
             THEN round(vu.uygulanan_gun::numeric / NULLIF(vu.plan_gun, 0), 3)
        END)::numeric(5,3)                               AS protokol_uyum,
       COALESCE(vu.protokol, '{}')::text[]               AS protokol,
       COALESCE(vu.protokol_sinif, '{}')::text[]         AS protokol_sinif,
       v.sonuc::text                                     AS sonuc,
       (CASE WHEN v.olay_ham >= 0 THEN v.olay_ham END)::int AS olay_gun,
       (v.sonuc = 'devam')::boolean                      AS sansur,
       round(vu.maliyet_tl, 2)::numeric(12,2)            AS maliyet_tl
FROM olay_hesap v
JOIN public.diseases d ON d.id = v.disease_id
LEFT JOIN vaka_uygulama vu ON vu.case_id = v.id;

COMMENT ON VIEW public.v_stat_vaka IS
  'İstatistik tedavi pilotu (spec §5.2, K7-K9): vaka başına bir satır. Üreme protokolü vakaları '
  '(protocol_family dolu ya da adı Ovsync) view''dan ve nüksten dışlanır (sahip 2026-10-06, R31). Sınırlamalar: şiddet alanı yok, '
  'süreler dağılım (medyan + Q1/Q3) olarak okunur, ortalama tek başına basılmaz; ilaç karşılaştırması '
  'yalnız aynı hastalık ve aynı dönem içinde anlamlıdır; oldu_kesildi yalnız cikis_tipi olum|kesim '
  '(satis/kayip ölüm sayılmaz; küme 2026-10-05 demo+prod {kesim,olum,satis,NULL}); maliyet_tl güncel '
  'stok.maliyet ile, fiyat geçmişi ve birim dönüşümü yok.';

REVOKE ALL ON TABLE public.v_stat_vaka FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.v_stat_vaka TO authenticated;

-- R31 dipnot yardımcısı
CREATE OR REPLACE FUNCTION public.stat_tedavi_dislanan_dipnot(p_baslangic date, p_bitis date, p_filtre jsonb)
RETURNS text[]
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  c_toplu_esik CONSTANT int := 3;
  v_k int;
  v_dipnot text[] := '{}';
BEGIN
  PERFORM public.stat_donem_dogrula(p_baslangic, p_bitis);
  IF p_filtre IS NULL OR jsonb_typeof(p_filtre) <> 'object' THEN
    RAISE EXCEPTION 'stat: filtre bir JSON nesnesi olmalı (verilen: %)', coalesce(jsonb_typeof(p_filtre), 'NULL');
  END IF;

  IF NOT (p_filtre ? 'hastalik' OR p_filtre ? 'kategori') THEN
    SELECT count(*)::int INTO v_k
    FROM public.cases c
    LEFT JOIN public.diseases d ON d.id = c.disease_id
    WHERE (c.protocol_family IS NOT NULL OR d.name ILIKE '%ovsync%')
      AND c.start_date BETWEEN p_baslangic AND p_bitis;
    IF v_k > 0 THEN
      v_dipnot := v_dipnot || ('Üreme protokolü vakaları (' || v_k
                               || ') dahil edilmedi; gebelik sonucuyla ayrı değerlendirilir.');
    END IF;
  END IF;

  WITH toplu AS (
    SELECT c.closed_at FROM public.cases c
    WHERE c.status = 'closed' AND c.closed_at IS NOT NULL
    GROUP BY c.closed_at HAVING count(*) >= c_toplu_esik
  )
  SELECT count(*)::int INTO v_k
  FROM public.v_stat_vaka v
  JOIN public.cases c ON c.id = v.vaka_id
  WHERE v.baslangic BETWEEN p_baslangic AND p_bitis
    AND (NOT p_filtre ? 'hastalik' OR v.hastalik = p_filtre->>'hastalik')
    AND (NOT p_filtre ? 'kategori' OR v.kategori = p_filtre->>'kategori')
    AND (NOT p_filtre ? 'protokol'
         OR public.stat_protokol_etiket(v.protokol, v.tedavi_suresi_gun, 'urun') = p_filtre->>'protokol')
    AND c.status = 'closed' AND c.closed_at IN (SELECT t.closed_at FROM toplu t);
  IF v_k > 0 THEN
    v_dipnot := v_dipnot || ('Toplu kapatılmış ' || v_k || ' vaka var; kapanış günü iyileşme günü olmayabilir.');
  END IF;
  RETURN v_dipnot;
END;
$$;

COMMENT ON FUNCTION public.stat_tedavi_dislanan_dipnot(date, date, jsonb) IS
  'R31: dışlanan protokol vakası (filtresizken) ve toplu kapanış (aynı closed_at ≥3) dipnotu; k=0 cümle yok.';

REVOKE ALL ON FUNCTION public.stat_tedavi_dislanan_dipnot(date, date, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.stat_tedavi_dislanan_dipnot(date, date, jsonb) TO authenticated;

-- hastalık × dönem özeti (spec §5.3); seçim baslangic BETWEEN p_baslangic AND p_bitis
CREATE OR REPLACE FUNCTION public.stat_tedavi_ozet(p_baslangic date, p_bitis date, p_filtre jsonb DEFAULT '{}')
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  c_esik CONSTANT int := 5;   -- K8
  v_n int;
  v_tablo jsonb;
BEGIN
  PERFORM public.stat_donem_dogrula(p_baslangic, p_bitis);
  PERFORM public.stat_filtre_dogrula(p_filtre, ARRAY['hastalik', 'kategori']);

  WITH secim AS (
    SELECT v.* FROM public.v_stat_vaka v
    WHERE v.baslangic BETWEEN p_baslangic AND p_bitis
      AND (NOT p_filtre ? 'hastalik' OR v.hastalik = p_filtre->>'hastalik')
      AND (NOT p_filtre ? 'kategori' OR v.kategori = p_filtre->>'kategori')
  ), grup AS (
    SELECT s.hastalik,
           count(*)::int                                          AS n,
           count(*) FILTER (WHERE s.sonuc = 'devam')::int         AS devam_n,
           count(*) FILTER (WHERE s.sonuc = 'iyilesti')::int      AS iyilesti_n,
           count(*) FILTER (WHERE s.sonuc = 'nuks')::int          AS nuks_n,
           count(*) FILTER (WHERE s.sonuc = 'oldu_kesildi')::int  AS olum_n,
           percentile_cont(0.5) WITHIN GROUP (ORDER BY s.vaka_suresi_gun)   AS vaka_med,
           percentile_cont(0.5) WITHIN GROUP (ORDER BY s.tedavi_suresi_gun) AS tedavi_med,
           avg(s.maliyet_tl)                                      AS maliyet_ort
    FROM secim s
    GROUP BY s.hastalik
  ), satir AS (
    SELECT g.*, g.n < c_esik AS yetersiz, NULLIF(g.n - g.devam_n, 0) AS payda FROM grup g
  )
  SELECT coalesce(sum(r.n), 0)::int,
         coalesce(jsonb_agg(jsonb_build_object(
           'hastalik', r.hastalik, 'n', r.n, 'devam_n', r.devam_n, 'yetersiz', r.yetersiz,
           'iyilesme_pct', CASE WHEN NOT r.yetersiz THEN round(100.0 * r.iyilesti_n / r.payda, 1) END,
           'nuks_pct',     CASE WHEN NOT r.yetersiz THEN round(100.0 * r.nuks_n / r.payda, 1) END,
           'olum_pct',     CASE WHEN NOT r.yetersiz THEN round(100.0 * r.olum_n / r.payda, 1) END,
           'vaka_suresi_medyan',   CASE WHEN NOT r.yetersiz THEN round(r.vaka_med::numeric, 1) END,
           'tedavi_suresi_medyan', CASE WHEN NOT r.yetersiz THEN round(r.tedavi_med::numeric, 1) END,
           'maliyet_ort',  CASE WHEN NOT r.yetersiz THEN round(r.maliyet_ort, 2) END)
           ORDER BY r.hastalik), '[]'::jsonb)
    INTO v_n, v_tablo
  FROM satir r;

  RETURN public.stat_zarf_bos('stat_tedavi_ozet', 'sql:20261005000005', v_n, ARRAY[
           'Şiddet bilgisi yok; süreler dağılım (medyan) olarak verilir, ortalama tek başına okunmaz.',
           'Karşılaştırma yalnız aynı hastalık ve aynı dönem içinde anlamlıdır.',
           'Maliyet: güncel stok maliyeti × doz; fiyat geçmişi ve birim dönüşümü yok.'] || public.stat_tedavi_dislanan_dipnot(p_baslangic, p_bitis, p_filtre))
         || jsonb_build_object('tablo', v_tablo);
END;
$$;

-- hastalık × protokol (ürün ya da sınıf düzeyi): T5 özet kolonları + protokol_uyum_ort
CREATE OR REPLACE FUNCTION public.stat_tedavi_protokol(p_baslangic date, p_bitis date, p_filtre jsonb DEFAULT '{}')
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  c_esik CONSTANT int := 5;   -- K8
  v_duzey text;
  v_n int;
  v_tablo jsonb;
BEGIN
  PERFORM public.stat_donem_dogrula(p_baslangic, p_bitis);
  PERFORM public.stat_filtre_dogrula(p_filtre, ARRAY['hastalik', 'kategori', 'duzey']);
  v_duzey := coalesce(p_filtre->>'duzey', 'urun');
  IF v_duzey NOT IN ('urun', 'sinif') THEN
    RAISE EXCEPTION 'stat: duzey urun ya da sinif olmalı (verilen: %)', v_duzey;
  END IF;

  WITH secim AS (
    SELECT v.*, public.stat_protokol_etiket(CASE WHEN v_duzey = 'sinif' THEN v.protokol_sinif ELSE v.protokol END,
                                            v.tedavi_suresi_gun, v_duzey) AS etiket
    FROM public.v_stat_vaka v
    WHERE v.baslangic BETWEEN p_baslangic AND p_bitis
      AND (NOT p_filtre ? 'hastalik' OR v.hastalik = p_filtre->>'hastalik')
      AND (NOT p_filtre ? 'kategori' OR v.kategori = p_filtre->>'kategori')
  ), grup AS (
    SELECT e.hastalik, e.etiket,
           count(*)::int                                          AS n,
           count(*) FILTER (WHERE e.sonuc = 'devam')::int         AS devam_n,
           count(*) FILTER (WHERE e.sonuc = 'iyilesti')::int      AS iyilesti_n,
           count(*) FILTER (WHERE e.sonuc = 'nuks')::int          AS nuks_n,
           count(*) FILTER (WHERE e.sonuc = 'oldu_kesildi')::int  AS olum_n,
           percentile_cont(0.5) WITHIN GROUP (ORDER BY e.vaka_suresi_gun)   AS vaka_med,
           percentile_cont(0.5) WITHIN GROUP (ORDER BY e.tedavi_suresi_gun) AS tedavi_med,
           avg(e.maliyet_tl)                                      AS maliyet_ort,
           avg(e.protokol_uyum)                                   AS uyum_ort   -- NULL'suz (R25)
    FROM secim e
    GROUP BY e.hastalik, e.etiket
  ), satir AS (
    SELECT g.*, g.n < c_esik AS yetersiz, NULLIF(g.n - g.devam_n, 0) AS payda FROM grup g
  )
  SELECT coalesce(sum(r.n), 0)::int,
         coalesce(jsonb_agg(jsonb_build_object(
           'hastalik', r.hastalik, 'protokol', r.etiket, 'n', r.n, 'devam_n', r.devam_n, 'yetersiz', r.yetersiz,
           'iyilesme_pct', CASE WHEN NOT r.yetersiz THEN round(100.0 * r.iyilesti_n / r.payda, 1) END,
           'nuks_pct',     CASE WHEN NOT r.yetersiz THEN round(100.0 * r.nuks_n / r.payda, 1) END,
           'olum_pct',     CASE WHEN NOT r.yetersiz THEN round(100.0 * r.olum_n / r.payda, 1) END,
           'vaka_suresi_medyan',   CASE WHEN NOT r.yetersiz THEN round(r.vaka_med::numeric, 1) END,
           'tedavi_suresi_medyan', CASE WHEN NOT r.yetersiz THEN round(r.tedavi_med::numeric, 1) END,
           'maliyet_ort',  CASE WHEN NOT r.yetersiz THEN round(r.maliyet_ort, 2) END,
           'protokol_uyum_ort', CASE WHEN NOT r.yetersiz THEN round(r.uyum_ort, 3) END)
           ORDER BY r.hastalik, r.n DESC, r.etiket), '[]'::jsonb)
    INTO v_n, v_tablo
  FROM satir r;

  RETURN public.stat_zarf_bos('stat_tedavi_protokol', 'sql:20261005000005', v_n, ARRAY[
           'Şiddet bilgisi yok; süreler dağılım (medyan) olarak verilir, ortalama tek başına okunmaz.',
           'Karşılaştırma yalnız aynı hastalık ve aynı dönem içinde anlamlıdır.',
           'Maliyet: güncel stok maliyeti × doz; fiyat geçmişi ve birim dönüşümü yok.',
           'Karşılaştırma yalnız aynı hastalık ve aynı dönem içinde anlamlıdır; neden-sonuç değildir.'] || public.stat_tedavi_dislanan_dipnot(p_baslangic, p_bitis, p_filtre))
         || jsonb_build_object('tablo', v_tablo);
END;
$$;

-- tek hastalıkta protokol başına tedavi süresi histogramı + Q1/medyan/Q3 (K9)
CREATE OR REPLACE FUNCTION public.stat_tedavi_sure_dagilim(p_baslangic date, p_bitis date, p_filtre jsonb DEFAULT '{}')
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  c_esik CONSTANT int := 5;   -- K8
  v_k int;
  v_n int;
  v_deger jsonb;
  v_seriler jsonb;
  v_tablo jsonb;
  v_dipnot text[] := ARRAY[
    'Şiddet bilgisi yok; süreler dağılım (medyan) olarak verilir, ortalama tek başına okunmaz.',
    'Karşılaştırma yalnız aynı hastalık ve aynı dönem içinde anlamlıdır; neden-sonuç değildir.'];
BEGIN
  PERFORM public.stat_donem_dogrula(p_baslangic, p_bitis);
  PERFORM public.stat_filtre_dogrula(p_filtre, ARRAY['hastalik', 'protokol']);
  IF NOT p_filtre ? 'hastalik' THEN
    RAISE EXCEPTION 'stat: hastalik filtresi zorunlu';
  END IF;

  WITH secim AS (
    SELECT v.tedavi_suresi_gun AS gun,
           public.stat_protokol_etiket(v.protokol, v.tedavi_suresi_gun, 'urun') AS etiket
    FROM public.v_stat_vaka v
    WHERE v.baslangic BETWEEN p_baslangic AND p_bitis
      AND v.hastalik = p_filtre->>'hastalik'
  ), suzgec AS (
    SELECT s.* FROM secim s WHERE NOT p_filtre ? 'protokol' OR s.etiket = p_filtre->>'protokol'
  ), sureli AS (
    SELECT s.* FROM suzgec s WHERE s.gun IS NOT NULL
  ), gunler AS (
    SELECT generate_series(1, (SELECT max(s.gun) FROM sureli s)) AS i
  ), hucre AS (
    SELECT s.etiket, s.gun, count(*)::int AS c FROM sureli s GROUP BY s.etiket, s.gun
  ), seri AS (
    SELECT s.etiket, count(*)::int AS n, count(*) < c_esik AS yetersiz,
           percentile_cont(0.25) WITHIN GROUP (ORDER BY s.gun) AS q1,
           percentile_cont(0.5)  WITHIN GROUP (ORDER BY s.gun) AS medyan,
           percentile_cont(0.75) WITHIN GROUP (ORDER BY s.gun) AS q3
    FROM sureli s
    GROUP BY s.etiket
  )
  SELECT (SELECT count(*) FROM suzgec s WHERE s.gun IS NULL)::int,
         (SELECT count(*) FROM sureli)::int,
         (SELECT coalesce(jsonb_agg(g.i ORDER BY g.i), '[]'::jsonb) FROM gunler g),
         (SELECT coalesce(jsonb_agg(jsonb_build_object(
                   'ad', r.etiket, 'n', r.n, 'alt', '[]'::jsonb, 'ust', '[]'::jsonb,
                   'y', CASE WHEN NOT r.yetersiz THEN
                          (SELECT jsonb_agg(coalesce(h.c, 0) ORDER BY g.i)
                           FROM gunler g LEFT JOIN hucre h ON h.gun = g.i AND h.etiket = r.etiket) END)
                 ORDER BY r.n DESC, r.etiket), '[]'::jsonb) FROM seri r),
         (SELECT coalesce(jsonb_agg(jsonb_build_object(
                   'protokol', r.etiket, 'n', r.n, 'yetersiz', r.yetersiz,
                   'q1',     CASE WHEN NOT r.yetersiz THEN round(r.q1::numeric, 1) END,
                   'medyan', CASE WHEN NOT r.yetersiz THEN round(r.medyan::numeric, 1) END,
                   'q3',     CASE WHEN NOT r.yetersiz THEN round(r.q3::numeric, 1) END)
                 ORDER BY r.n DESC, r.etiket), '[]'::jsonb) FROM seri r)
    INTO v_k, v_n, v_deger, v_seriler, v_tablo;

  IF v_k > 0 THEN
    v_dipnot := v_dipnot || ('İlaç uygulaması olmayan ' || v_k || ' vaka dahil edilmedi.');
  END IF;

  RETURN public.stat_zarf_bos('stat_tedavi_sure_dagilim', 'sql:20261005000005', v_n,
                               v_dipnot || public.stat_tedavi_dislanan_dipnot(p_baslangic, p_bitis, p_filtre))
         || jsonb_build_object('x', jsonb_build_object('ad', 'gün', 'deger', v_deger),
                               'seriler', v_seriler, 'tablo', v_tablo);
END;
$$;

UPDATE public.stat_olcum_kayit SET surum = 'sql:20261005000005'
WHERE ad IN ('stat_tedavi_ozet', 'stat_tedavi_protokol', 'stat_tedavi_sure_dagilim')
  AND surum IS DISTINCT FROM 'sql:20261005000005';

COMMIT;
