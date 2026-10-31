-- ============================================================================
-- Migration: 20261017000003_stat_atolye_secenek
-- 2026-10-17 · İstatistik Atölyesi AP1 Task 5 (spec v2 §4.4 kombinasyon paneli + seçenek uzayı, §4.5 RPC'ler;
--   plan Task 5, P13; Review Focus 4: (bilinmiyor) seçeneklerde en sonda, panelde y olarak yok).
-- Etkiler: stat_atolye_kombinasyon(jsonb,jsonb) ve stat_atolye_kombinasyon_k(jsonb,jsonb,jsonb) CREATE OR REPLACE
--   (T4 NULL gövdeleri → panel); YENİ fonksiyonlar stat_atolye_secenekler(jsonb), stat_atolye_vakalar(jsonb,text).
--   stat_atolye_seri'ye dokunulmaz (surum 'sql:20261017000002' aynen; panel seriye kombinasyon_k üzerinden girer).
--   Okur: v_stat_saglik_vaka, stat_saglik_vaka_tl (20261017000001), stat_cumle_dogrula, stat_cumle_kapsam,
--   stat_atolye_gruplar (20261017000002). Tablo yazımı yok.
-- Perf (T5 perf c, root ruling): kombinasyon ve seçenekler view'ları kendisi okumaz; dönem + kapsam
--   stat_cumle_kapsam'dan (tek okuma, hastalık süzgeci orada).
-- ACL: hepsi SECURITY INVOKER + SET search_path = public, pg_temp, STABLE; REVOKE ALL FROM PUBLIC, anon, authenticated;
--   GRANT EXECUTE yalnız authenticated. anon GRANT yok.
-- Hata sözleşmesi (P13): RAISE EXCEPTION 'STAT_CUMLE:<yol>:<neden>'; bilinmeyen vaka listesi grubu → STAT_CUMLE:grup:bilinmiyor.
-- TZ: bugün yalnız stat_cumle_donem → stat_bugun() üzerinden; sunucu tarihi kullanılmaz.
-- Statik kapı notu (T3/T4 dersi): küme-dönen yerleşik fonksiyonlar FROM/JOIN'de pg_catalog. önekiyle; LATERAL ve
--   AS MATERIALIZED yok; CTE'ler `), ad AS (` biçiminde.
-- Idempotent: CREATE OR REPLACE FUNCTION + REVOKE/GRANT; ikinci psql -f hatasız.
-- Geri alma: DROP FUNCTION stat_atolye_vakalar(jsonb,text), stat_atolye_secenekler(jsonb); stat_atolye_kombinasyon ve
--   stat_atolye_kombinasyon_k'yı 20261017000002'deki NULL gövdeleriyle yeniden CREATE OR REPLACE.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ── 1. Kombinasyon paneli (spec §4.4) ───────────────────────────────────────
CREATE OR REPLACE FUNCTION public.stat_atolye_kombinasyon_k(p_cumle jsonb, p_fiyat jsonb, p_kapsam jsonb)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  c_esik CONSTANT int := 5;   -- K8
  c_basari CONSTANT text[] := ARRAY['basarili', 'basarisiz_olum_kesim', 'basarisiz_tedavi_degisti', 'basarisiz_nuks'];
  v_duzey text := p_cumle#>>'{ilac,duzey}';
  v_x text := p_cumle#>>'{ilac,x}';
  v_sonuc jsonb;
BEGIN
  PERFORM public.stat_cumle_dogrula(p_cumle);
  IF v_x IS NULL THEN RETURN NULL; END IF;

  -- kümeler stat_atolye_seri ile aynı: başarı = sonuc ∈ c_basari; hız = sonuçlanmış ∧ kapanma günü dolu;
  --   ₺ = sonuçlanmış ∧ ilaçlı (R1) ∧ ₺ hesaplanabilir (p_fiyat ile). Vaka ve ilaç satırları p_kapsam'dan (dönem + hastalık süzgeçli).
  WITH i AS (
    SELECT i.vaka_id, i.deger FROM pg_catalog.jsonb_to_recordset(p_kapsam->'ilac') AS i(vaka_id uuid, deger text)
  ), xv AS (    -- dönemdeki x vakaları; ₺ yalnız bunlar için hesaplanır
    SELECT v.vaka_id, v.durum, v.sonuc, v.kapanma_gunu AS kg,
           CASE WHEN v.durum = 'sonuclandi' AND v.maliyet_kalemleri <> '[]'::jsonb
                THEN public.stat_saglik_vaka_tl(v.maliyet_kalemleri, p_fiyat) END AS tl
    FROM pg_catalog.jsonb_to_recordset(p_kapsam->'vakalar')
         AS v(vaka_id uuid, durum text, sonuc text, kapanma_gunu int, maliyet_kalemleri jsonb)
    WHERE v.vaka_id IN (SELECT i.vaka_id FROM i WHERE i.deger = v_x)
  ), xi AS (    -- x vakalarının ilaç değerleri
    SELECT i.vaka_id, i.deger FROM i WHERE i.vaka_id IN (SELECT xv.vaka_id FROM xv)
  ), y AS (     -- x vakalarında birlikte görülen değerler; (bilinmiyor) panelde y olmaz
    SELECT DISTINCT xi.deger AS y FROM xi WHERE xi.deger <> v_x AND xi.deger <> '(bilinmiyor)'
  ), g AS (     -- (y, taraf, vaka): a = x + y içeren, b = x içeren, y'siz
    SELECT y.y, CASE WHEN xi.vaka_id IS NULL THEN 'b' ELSE 'a' END AS t, xv.vaka_id, xv.durum, xv.sonuc, xv.kg, xv.tl
    FROM y CROSS JOIN xv
    LEFT JOIN xi ON xi.vaka_id = xv.vaka_id AND xi.deger = y.y
  ), o AS (
    SELECT s.y, s.t, count(g.vaka_id)::int AS n,
           jsonb_build_object(
             'n', count(g.vaka_id),
             'basari', jsonb_build_object(
               'k', count(*) FILTER (WHERE g.sonuc = 'basarili'),
               'n', count(*) FILTER (WHERE g.sonuc = ANY (c_basari)),
               'y', round(100.0 * count(*) FILTER (WHERE g.sonuc = 'basarili')
                          / NULLIF(count(*) FILTER (WHERE g.sonuc = ANY (c_basari)), 0), 1)),
             'hiz', jsonb_build_object(
               'n', count(*) FILTER (WHERE g.durum = 'sonuclandi' AND g.kg IS NOT NULL),
               'medyan', round((percentile_cont(0.5) WITHIN GROUP (ORDER BY g.kg)
                                FILTER (WHERE g.durum = 'sonuclandi' AND g.kg IS NOT NULL))::numeric, 1)),
             'tl', jsonb_build_object(
               'n', count(*) FILTER (WHERE g.tl IS NOT NULL),
               'medyan', round((percentile_cont(0.5) WITHIN GROUP (ORDER BY g.tl) FILTER (WHERE g.tl IS NOT NULL))::numeric, 2))
           ) AS m
    FROM (SELECT y.y, t.t FROM y CROSS JOIN (VALUES ('a'), ('b')) AS t(t)) s
    LEFT JOIN g ON g.y = s.y AND g.t = s.t
    GROUP BY s.y, s.t
  ), r AS (
    SELECT o.y, jsonb_object_agg(o.t, o.m) AS ab, max(o.n) FILTER (WHERE o.t = 'a') AS an,
           min(o.n) < c_esik AS yetersiz
    FROM o GROUP BY o.y
  )
  SELECT jsonb_build_object('x', v_x, 'duzey', v_duzey, 'satirlar',
           COALESCE(jsonb_agg(jsonb_build_object('y', r.y, 'a', r.ab->'a', 'b', r.ab->'b', 'yetersiz', r.yetersiz)
                              ORDER BY r.an DESC, r.y), '[]'::jsonb))
    INTO v_sonuc
  FROM r;
  RETURN v_sonuc;
END;
$$;

COMMENT ON FUNCTION public.stat_atolye_kombinasyon_k(jsonb, jsonb, jsonb) IS
  'stat_atolye_kombinasyon''un iç gövdesi: p_fiyat = doğrulanmış p_gecici.ilac_fiyat, p_kapsam = stat_cumle_kapsam(p_cumle) '
  '(view okumaz); stat_atolye_seri bunu çağırır.';

CREATE OR REPLACE FUNCTION public.stat_atolye_kombinasyon(p_cumle jsonb, p_gecici jsonb)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_k text;
  v_fiyat jsonb;
BEGIN
  PERFORM public.stat_cumle_dogrula(p_cumle);
  -- p_gecici doğrudan çağrıda da stat_atolye_seri ile aynı kuralla doğrulanır (fail-closed)
  p_gecici := COALESCE(p_gecici, '{}'::jsonb);
  IF jsonb_typeof(p_gecici) <> 'object' THEN RAISE EXCEPTION 'STAT_CUMLE:gecici:nesne_degil'; END IF;
  v_k := (SELECT min(t.k) FROM pg_catalog.jsonb_object_keys(p_gecici) AS t(k) WHERE t.k <> 'ilac_fiyat');
  IF v_k IS NOT NULL THEN RAISE EXCEPTION 'STAT_CUMLE:gecici.%:bilinmeyen_anahtar', v_k; END IF;
  v_fiyat := COALESCE(p_gecici->'ilac_fiyat', '{}'::jsonb);
  IF jsonb_typeof(v_fiyat) <> 'object' THEN RAISE EXCEPTION 'STAT_CUMLE:gecici.ilac_fiyat:nesne_degil'; END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.jsonb_each(v_fiyat) AS t(k, d)
              WHERE CASE WHEN jsonb_typeof(t.d) = 'number' THEN (t.d #>> '{}')::numeric <= 0 ELSE true END) THEN
    RAISE EXCEPTION 'STAT_CUMLE:gecici.ilac_fiyat:pozitif_sayi_degil';
  END IF;
  IF p_cumle#>>'{ilac,x}' IS NULL THEN RETURN NULL; END IF;   -- x yoksa kapsam okunmaz
  RETURN public.stat_atolye_kombinasyon_k(p_cumle, v_fiyat, public.stat_cumle_kapsam(p_cumle));
END;
$$;

COMMENT ON FUNCTION public.stat_atolye_kombinasyon(jsonb, jsonb) IS
  'Kombinasyon paneli (spec §4.4, plan T5): x seçiliyse, dönem + hastalık kapsamında x vakalarında birlikte görülen her y '
  '((bilinmiyor) ve x hariç) için a = x + y içeren, b = x içeren y''siz grupları; her grupta n, başarı {k, n, y}, hız '
  '{n, medyan}, vaka ₺ {n, medyan} (kümeler stat_atolye_seri ile aynı, ₺ p_gecici ile; ilaçsız vaka ₺''ye girmez, R1); '
  'satırlar a.n azalan, eşitlikte y; '
  'yetersiz = a.n < 5 ∨ b.n < 5 (değerler yine dolu). x yoksa NULL. stat_atolye_seri bu fonksiyonu çağırır.';

-- ── 2. Seçenek uzayı (spec §4.4, AK-2) ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public.stat_atolye_secenekler(p_cumle jsonb)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_x text := p_cumle#>>'{ilac,x}';
  v_kapsam jsonb;
  v_sonuc jsonb;
BEGIN
  v_kapsam := public.stat_cumle_kapsam(p_cumle);   -- doğrular; dönem + kapsam satırları

  -- k = dönemdeki kapsam vakaları (açık dahil, hastalık süzgeçsiz: vakalar ∪ diger);
  --   i = cümlenin hastalık süzgecine uyan vakaların seçili düzeydeki değerleri
  WITH k AS (
    SELECT v.vaka_id, v.hastalik_id, v.hastalik, v.kategori
    FROM pg_catalog.jsonb_to_recordset((v_kapsam->'vakalar') || (v_kapsam->'diger'))
         AS v(vaka_id uuid, hastalik_id uuid, hastalik text, kategori text)
  ), i AS (
    SELECT i.vaka_id, i.deger FROM pg_catalog.jsonb_to_recordset(v_kapsam->'ilac') AS i(vaka_id uuid, deger text)
  ), h AS (
    SELECT k.hastalik_id, k.hastalik, k.kategori, count(DISTINCT k.vaka_id)::int AS n
    FROM k GROUP BY k.hastalik_id, k.hastalik, k.kategori
  ), kt AS (
    SELECT k.kategori, count(DISTINCT k.vaka_id)::int AS n FROM k GROUP BY k.kategori
  ), xa AS (
    SELECT i.deger, count(DISTINCT i.vaka_id)::int AS n FROM i GROUP BY i.deger
  ), ya AS (   -- yalnız x varken: x vakalarında x ile birlikte görülen değerler (birlikte-görülme n'i)
    SELECT i.deger, count(DISTINCT i.vaka_id)::int AS n
    FROM i
    WHERE v_x IS NOT NULL AND i.deger <> v_x AND i.vaka_id IN (SELECT i2.vaka_id FROM i i2 WHERE i2.deger = v_x)
    GROUP BY i.deger
  )
  SELECT jsonb_build_object(
           'donem', jsonb_build_object('bas', (v_kapsam->>'bas')::date, 'bit', (v_kapsam->>'bit')::date),
           'toplam_n', (SELECT count(*) FROM k),
           'hastaliklar', COALESCE((SELECT jsonb_agg(jsonb_build_object('id', h.hastalik_id, 'ad', h.hastalik, 'kategori',
                                                                         h.kategori, 'n', h.n) ORDER BY h.n DESC, h.hastalik)
                                    FROM h), '[]'::jsonb),
           'kategoriler', COALESCE((SELECT jsonb_agg(jsonb_build_object('ad', kt.kategori, 'n', kt.n) ORDER BY kt.n DESC, kt.kategori)
                                    FROM kt), '[]'::jsonb),
           'x_adaylari', COALESCE((SELECT jsonb_agg(jsonb_build_object('deger', xa.deger, 'n', xa.n)
                                                    ORDER BY xa.deger = '(bilinmiyor)', xa.n DESC, xa.deger) FROM xa), '[]'::jsonb),
           'y_adaylari', COALESCE((SELECT jsonb_agg(jsonb_build_object('deger', ya.deger, 'n', ya.n)
                                                    ORDER BY ya.deger = '(bilinmiyor)', ya.n DESC, ya.deger) FROM ya), '[]'::jsonb))
    INTO v_sonuc;
  RETURN v_sonuc;
END;
$$;

COMMENT ON FUNCTION public.stat_atolye_secenekler(jsonb) IS
  'Kurucu seçenekleri (spec §4.4, AK-2): cümle doğrulanır, dönem cümleden. toplam_n / hastaliklar {id, ad, kategori, n} / '
  'kategoriler {ad, n} = dönemdeki kapsam vakaları (açık dahil, hastalık süzgeçsiz), n azalan; x_adaylari = seçili '
  'hastalık + dönem + düzeyde "içeren" vaka sayısı; y_adaylari = yalnız x varken x vakalarında birlikte görülen değerler '
  '(x hariç); aday listelerinde n azalan, (bilinmiyor) en son.';

-- ── 3. Vaka listesi ("bu sayıya giren vakalar", spec §4.5) ────────────────────
CREATE OR REPLACE FUNCTION public.stat_atolye_vakalar(p_cumle jsonb, p_grup text)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  c_limit CONSTANT int := 200;
  v_x text := p_cumle#>>'{ilac,x}';
  v_m text[];
  v_ids uuid[];
  v_var boolean;
  v_sonuc jsonb;
BEGIN
  PERFORM public.stat_cumle_dogrula(p_cumle);
  v_m := pg_catalog.regexp_match(p_grup, '^komb:(.+):([ab])$');
  IF v_m IS NOT NULL THEN
    -- panel satırı: a = gruplar(x + y, x_y_siz).xy, b = .x_y_siz (panelle aynı küme tanımı)
    IF v_x IS NULL OR v_m[1] = v_x OR v_m[1] = '(bilinmiyor)' THEN RAISE EXCEPTION 'STAT_CUMLE:grup:bilinmiyor'; END IF;
    SELECT COALESCE(array_agg(g.vaka_id) FILTER (WHERE g.anahtar = CASE v_m[2] WHEN 'a' THEN 'xy' ELSE 'x_y_siz' END
                                                   AND g.vaka_id IS NOT NULL), '{}'),
           bool_or(g.anahtar = 'xy' AND g.vaka_id IS NOT NULL)
      INTO v_ids, v_var
    FROM public.stat_atolye_gruplar(jsonb_set(jsonb_set(p_cumle, '{ilac,y}', to_jsonb(v_m[1])),
                                              '{kiyas_grubu}', '"x_y_siz"')) AS g;
    IF v_var IS NOT TRUE THEN RAISE EXCEPTION 'STAT_CUMLE:grup:bilinmiyor'; END IF;   -- y, x ile birlikte görülmüyor
  ELSE
    -- zarf grup anahtarı (tumu, x, xy, x_y_siz, ilac:<değer>); boş grup gruplardan vaka_id NULL satırla gelir
    SELECT COALESCE(array_agg(g.vaka_id) FILTER (WHERE g.vaka_id IS NOT NULL), '{}'), count(*) > 0
      INTO v_ids, v_var
    FROM public.stat_atolye_gruplar(p_cumle) AS g
    WHERE g.anahtar = p_grup;
    IF v_var IS NOT TRUE THEN RAISE EXCEPTION 'STAT_CUMLE:grup:bilinmiyor'; END IF;
  END IF;

  SELECT jsonb_build_object('toplam', COALESCE(array_length(v_ids, 1), 0), 'vakalar', COALESCE(jsonb_agg(q.o ORDER BY q.s), '[]'::jsonb))
    INTO v_sonuc
  FROM (SELECT row_number() OVER (ORDER BY v.baslangic DESC, v.vaka_id) AS s,
               jsonb_build_object('vaka_id', v.vaka_id, 'kupe_no', v.kupe_no, 'hastalik', v.hastalik, 'baslangic', v.baslangic,
                                  'kapanis', v.kapanis, 'durum', v.durum, 'sonuc', v.sonuc, 'kapanma_gunu', v.kapanma_gunu,
                                  'kapanma_vekil', v.kapanma_vekil) AS o
        FROM public.v_stat_saglik_vaka v
        WHERE v.vaka_id = ANY (v_ids)
        ORDER BY v.baslangic DESC, v.vaka_id
        LIMIT c_limit) q;
  RETURN v_sonuc;
END;
$$;

COMMENT ON FUNCTION public.stat_atolye_vakalar(jsonb, text) IS
  'Bir grubun vaka listesi (spec §4.5): p_grup = stat_atolye_gruplar anahtarı (tumu, x, xy, x_y_siz, ilac:<değer>) ya da '
  'komb:<y>:a / komb:<y>:b (panel satırı); bilinmeyen grup → STAT_CUMLE:grup:bilinmiyor. toplam = gruptaki vaka sayısı '
  '(açık dahil); vakalar en çok 200, baslangic azalan; satırda durum/sonuc ölçü kümesini gösterir.';

-- ── 4. ACL ─────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.stat_atolye_kombinasyon_k(jsonb, jsonb, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_atolye_kombinasyon(jsonb, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_atolye_secenekler(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_atolye_vakalar(jsonb, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.stat_atolye_kombinasyon_k(jsonb, jsonb, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_atolye_kombinasyon(jsonb, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_atolye_secenekler(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_atolye_vakalar(jsonb, text) TO authenticated;

COMMIT;
