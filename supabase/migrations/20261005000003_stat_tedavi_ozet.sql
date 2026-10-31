-- ============================================================================
-- Migration: 20261005000003_stat_tedavi_ozet
-- Tarih: 2026-10-05 · istatistik F1 Task 5 (plan P5 — spec §5.1, §5.3, §8.1, §8.2, K8)
-- Etkiler: 6 yeni fonksiyon (stat_zarf_bos, stat_filtre_dogrula, stat_donem_dogrula,
--   stat_olcum_listele, stat_sonuc_oku, stat_tedavi_ozet) + stat_olcum_kayit'a 5 kayıt
--   satırı (upsert ON CONFLICT (ad), preflight R13). Tablo/şema değişikliği YOK;
--   cases/treatment_days/drug_administrations yalnız v_stat_vaka üzerinden okunur (§13.9).
-- Hepsi STABLE SECURITY INVOKER, search_path = public, pg_temp (spec §5.1).
-- ACL (R8): her fonksiyonda REVOKE ALL FROM PUBLIC, anon, authenticated; GRANT EXECUTE
--   TO authenticated (helper'lar dahil: INVOKER zincirinde çağıran rol onları da çağırır).
-- Fail-closed: NULL/ters dönem, nesne olmayan filtre, izinli dışı anahtar, metin olmayan
--   filtre değeri, kayıtsız ölçüm adı → RAISE EXCEPTION 'stat: …'. Eşleşen vaka yoksa hata
--   değil: n=0, yetersiz=true zarf.
-- K8: eşik sabit 5 (fonksiyon içinde); n<5 satırında değer alanları NULL, n/devam_n basılır.
-- Statik kapı notu (T3): FROM'lu set-dönen fonksiyon ve LATERAL yok; CTE'ler `), ad AS (`.
-- Idempotent: CREATE OR REPLACE + upsert; ikinci koşum no-op.
-- Geri alma: DROP FUNCTION IF EXISTS stat_tedavi_ozet(date,date,jsonb), stat_sonuc_oku(text,jsonb),
--   stat_olcum_listele(), stat_donem_dogrula(date,date), stat_filtre_dogrula(jsonb,text[]),
--   stat_zarf_bos(text,text,int,text[]); DELETE FROM stat_olcum_kayit WHERE ad LIKE 'stat_tedavi_%';
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- §8.1 zarfı: x null, seriler/tablo boş; yetersiz = (n < 5)
CREATE OR REPLACE FUNCTION public.stat_zarf_bos(p_olcum text, p_surum text, p_n int, p_dipnot text[])
RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'olcum', p_olcum, 'hesap_at', now(), 'surum', p_surum,
    'n', coalesce(p_n, 0), 'yetersiz', coalesce(p_n, 0) < 5,
    'x', NULL, 'seriler', '[]'::jsonb, 'tablo', '[]'::jsonb,
    'dipnot', to_jsonb(coalesce(p_dipnot, '{}'::text[])));
$$;

CREATE OR REPLACE FUNCTION public.stat_filtre_dogrula(p_filtre jsonb, p_izinli text[])
RETURNS void
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_fazla jsonb;
BEGIN
  IF p_filtre IS NULL OR jsonb_typeof(p_filtre) <> 'object' THEN
    RAISE EXCEPTION 'stat: filtre bir JSON nesnesi olmalı (verilen: %)', coalesce(jsonb_typeof(p_filtre), 'NULL');
  END IF;
  v_fazla := p_filtre - coalesce(p_izinli, '{}'::text[]);
  IF v_fazla <> '{}'::jsonb THEN
    RAISE EXCEPTION 'stat: bilinmeyen filtre anahtarı %',
      array_to_string(ARRAY(SELECT jsonb_object_keys(v_fazla) ORDER BY 1), ', ');
  END IF;
  -- "Tümü" = anahtarı göndermemek; null/sayı değer sessizce "filtresiz"e dönmez
  IF jsonb_path_exists(p_filtre, '$.* ? (@.type() != "string")') THEN
    RAISE EXCEPTION 'stat: filtre değerleri metin olmalı (%)', p_filtre;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.stat_donem_dogrula(p_baslangic date, p_bitis date)
RETURNS void
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_baslangic IS NULL OR p_bitis IS NULL THEN
    RAISE EXCEPTION 'stat: dönem başlangıcı ve bitişi zorunlu';
  END IF;
  IF p_bitis < p_baslangic THEN
    RAISE EXCEPTION 'stat: dönem bitişi (%) başlangıçtan (%) önce olamaz', p_bitis, p_baslangic;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.stat_olcum_listele()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'ad', k.ad, 'alan', k.alan, 'baslik', k.baslik, 'aciklama', k.aciklama,
           'tip', k.tip, 'surum', k.surum) ORDER BY k.sira, k.ad), '[]'::jsonb)
  FROM public.stat_olcum_kayit k
  WHERE k.farm_id = public.current_farm_id() AND k.aktif IS TRUE;
$$;

-- motor sonucu: kayıtlı ölçüm + anahtar → saklı zarf (hesap_at kolondan); yoksa boş zarf
CREATE OR REPLACE FUNCTION public.stat_sonuc_oku(p_olcum text, p_anahtar jsonb DEFAULT '{}')
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_sonuc jsonb;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.stat_olcum_kayit k
                  WHERE k.ad = p_olcum AND k.farm_id = public.current_farm_id()) THEN
    RAISE EXCEPTION 'stat: tanınmayan ölçüm adı %', coalesce(p_olcum, 'NULL');
  END IF;
  IF p_anahtar IS NULL OR jsonb_typeof(p_anahtar) <> 'object' THEN
    RAISE EXCEPTION 'stat: anahtar bir JSON nesnesi olmalı';
  END IF;
  SELECT s.sonuc || jsonb_build_object('hesap_at', s.hesap_at) INTO v_sonuc
  FROM public.stat_analiz_sonuc s
  WHERE s.farm_id = public.current_farm_id() AND s.olcum = p_olcum AND s.anahtar = p_anahtar;
  RETURN coalesce(v_sonuc, public.stat_zarf_bos(p_olcum, 'motor:-', 0, ARRAY['Henüz hesaplanmadı']));
END;
$$;

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

  RETURN public.stat_zarf_bos('stat_tedavi_ozet', 'sql:20261005000003', v_n, ARRAY[
           'Şiddet bilgisi yok; süreler dağılım (medyan) olarak verilir, ortalama tek başına okunmaz.',
           'Karşılaştırma yalnız aynı hastalık ve aynı dönem içinde anlamlıdır.',
           'Maliyet: güncel stok maliyeti × doz; fiyat geçmişi ve birim dönüşümü yok.'])
         || jsonb_build_object('tablo', v_tablo);
END;
$$;

COMMENT ON FUNCTION public.stat_tedavi_ozet(date, date, jsonb) IS
  'Tedavi özeti (spec §5.3): hastalık başına n, devam_n, iyileşme/nüks/ölüm % (payda n − devam_n), '
  'medyan vaka/tedavi süresi, ort. maliyet; n<5 satırda değerler NULL (K8). Filtre: hastalik, kategori.';

INSERT INTO public.stat_olcum_kayit (ad, alan, baslik, aciklama, tip, surum, aktif, sira) VALUES
  ('stat_tedavi_ozet', 'tedavi', 'Tedavi özeti',
   'Hastalık başına vaka sayısı, iyileşme/nüks/ölüm yüzdesi, medyan vaka ve tedavi süresi, ortalama maliyet.',
   'sql', 'sql:20261005000003', true, 10),
  ('stat_tedavi_protokol', 'tedavi', 'Protokol karşılaştırması',
   'Hastalık × protokol: özet kolonları ve protokole uyum.', 'sql', 'sql:20261005000004', true, 20),
  ('stat_tedavi_sure_dagilim', 'tedavi', 'Tedavi süresi dağılımı',
   'Hastalık × protokol: tedavi süresi histogramı, Q1/medyan/Q3.', 'sql', 'sql:20261005000004', true, 30),
  ('stat_tedavi_sagkalim', 'tedavi', 'İyileşme eğrisi',
   'Kaplan-Meier: protokol başına iyileşme olasılığı – gün, sansürlü vakalar dahil.', 'motor', 'motor:-', false, 40),
  ('stat_tedavi_protokol_fark', 'tedavi', 'Protokol farkı',
   'İki protokol arası fark: log-rank p, hazard oranı (Cox).', 'motor', 'motor:-', false, 50)
ON CONFLICT (ad) DO UPDATE SET alan = EXCLUDED.alan, baslik = EXCLUDED.baslik, aciklama = EXCLUDED.aciklama,
  tip = EXCLUDED.tip, surum = EXCLUDED.surum, aktif = EXCLUDED.aktif, sira = EXCLUDED.sira;

REVOKE ALL ON FUNCTION public.stat_zarf_bos(text, text, int, text[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_filtre_dogrula(jsonb, text[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_donem_dogrula(date, date) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_olcum_listele() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_sonuc_oku(text, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_tedavi_ozet(date, date, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.stat_zarf_bos(text, text, int, text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_filtre_dogrula(jsonb, text[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_donem_dogrula(date, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_olcum_listele() TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_sonuc_oku(text, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_tedavi_ozet(date, date, jsonb) TO authenticated;

COMMIT;
