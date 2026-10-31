-- ============================================================================
-- Migration: 20261005000004_stat_tedavi_protokol
-- Tarih: 2026-10-05 · istatistik F1 Task 6 (plan P6 — spec §5.3, §8.1, K8, K9)
-- Etkiler: 3 yeni fonksiyon (stat_protokol_etiket, stat_tedavi_protokol, stat_tedavi_sure_dagilim). Tablo/şema
--   değişikliği YOK; stat_olcum_kayit'a dokunulmaz (kayıt satırları T5'te, preflight R13).
--   cases/treatment_days/drug_administrations yalnız v_stat_vaka üzerinden okunur (§13.9).
-- Kalıp T5 ile aynı: STABLE SECURITY INVOKER, search_path = public, pg_temp; önce
--   stat_donem_dogrula + stat_filtre_dogrula (filtre değerleri metin; "Tümü" = anahtar yok).
-- ACL (R8): REVOKE ALL FROM PUBLIC, anon, authenticated; GRANT EXECUTE TO authenticated.
-- Protokol etiketi (R30, stat_protokol_etiket): uygulanmış ilaç yok (tedavi_suresi_gun NULL)
--   → '(ilaçsız)'; yoksa ürün (varsayılan) array_to_string(protokol,' + '), sınıf
--   array_to_string(protokol_sinif,' + '); uygulama var ama dizi boş → '(adsız)' / '(sınıfsız)'.
-- K8: eşik sabit 5; n<5 satır/seride değer alanları NULL (y=null), yetersiz=true.
-- Statik kapı notu (T3): FROM'lu set-dönen fonksiyon ve LATERAL yok; CTE'ler `), ad AS (`.
-- Idempotent: CREATE OR REPLACE; ikinci koşum no-op.
-- Geri alma: DROP FUNCTION IF EXISTS stat_tedavi_sure_dagilim(date,date,jsonb),
--   stat_tedavi_protokol(date,date,jsonb), stat_protokol_etiket(text[],int,text);
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- R30: iki ölçümün ortak etiket kuralı (protokol filtresi de bu etikete tam eşleşir)
CREATE OR REPLACE FUNCTION public.stat_protokol_etiket(p_dizi text[], p_tedavi_suresi_gun int, p_duzey text)
RETURNS text
LANGUAGE sql IMMUTABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT CASE WHEN p_tedavi_suresi_gun IS NULL THEN '(ilaçsız)'
              WHEN cardinality(p_dizi) > 0 THEN array_to_string(p_dizi, ' + ')
              WHEN p_duzey = 'sinif' THEN '(sınıfsız)'
              ELSE '(adsız)' END;
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

  RETURN public.stat_zarf_bos('stat_tedavi_protokol', 'sql:20261005000004', v_n, ARRAY[
           'Şiddet bilgisi yok; süreler dağılım (medyan) olarak verilir, ortalama tek başına okunmaz.',
           'Karşılaştırma yalnız aynı hastalık ve aynı dönem içinde anlamlıdır.',
           'Maliyet: güncel stok maliyeti × doz; fiyat geçmişi ve birim dönüşümü yok.',
           'Karşılaştırma yalnız aynı hastalık ve aynı dönem içinde anlamlıdır; neden-sonuç değildir.'])
         || jsonb_build_object('tablo', v_tablo);
END;
$$;

COMMENT ON FUNCTION public.stat_tedavi_protokol(date, date, jsonb) IS
  'Protokol karşılaştırması (spec §5.3): hastalık × protokol (duzey urun|sinif) satırında özet kolonları + '
  'protokol_uyum_ort; n<5 satırda değerler NULL (K8). Filtre: hastalik, kategori, duzey.';

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

  RETURN public.stat_zarf_bos('stat_tedavi_sure_dagilim', 'sql:20261005000004', v_n, v_dipnot)
         || jsonb_build_object('x', jsonb_build_object('ad', 'gün', 'deger', v_deger),
                               'seriler', v_seriler, 'tablo', v_tablo);
END;
$$;

COMMENT ON FUNCTION public.stat_tedavi_sure_dagilim(date, date, jsonb) IS
  'Tedavi süresi dağılımı (spec §5.3, K9): tek hastalıkta protokol (ürün) başına gün histogramı ve '
  'Q1/medyan/Q3; süresi NULL (ilaçsız) vaka dışarıda, sayısı dipnotta; n<5 seride y=null (K8). '
  'Filtre: hastalik (zorunlu), protokol.';

REVOKE ALL ON FUNCTION public.stat_protokol_etiket(text[], int, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_tedavi_protokol(date, date, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_tedavi_sure_dagilim(date, date, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.stat_protokol_etiket(text[], int, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_tedavi_protokol(date, date, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_tedavi_sure_dagilim(date, date, jsonb) TO authenticated;

COMMIT;
