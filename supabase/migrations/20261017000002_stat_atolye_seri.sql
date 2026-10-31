-- ============================================================================
-- Migration: 20261017000002_stat_atolye_seri
-- 2026-10-17 · İstatistik Atölyesi AP1 Task 4 (spec v2 §4.3-§4.5, §4.8; plan Task 4, P4-P8, P12, P13;
--   root ruling 2026-10-17: kapali_tarihsiz vaka açık sayacına girmez, dipnotta ayrı sayılır;
--   root ruling R1 (kapı F1): ilaçsız vaka ₺ ölçülerine girmez, ilacsiz_n sayacı + ₺ zarfında dipnot;
--   sahip S1 (c), domain §19.7: basarisiz_tedavi_degisti başarı paydasında, hızda yok, tedavi_degisti_n + dipnot).
-- Etkiler: YENİ fonksiyonlar — stat_cumle_dogrula, stat_cumle_donem, stat_cumle_kapsam, stat_wilson, stat_atolye_gruplar,
--   stat_atolye_gruplar_k, stat_atolye_kombinasyon + stat_atolye_kombinasyon_k (T4 gövdeleri NULL; T5 değiştirir),
--   stat_atolye_seri.
--   Okur: v_stat_saglik_vaka, v_stat_saglik_vaka_ilac, stat_saglik_vekil, stat_saglik_vaka_tl, stat_saglik_fiyat_kaynagi,
--   stat_vaka_ovsync_mu, stat_bugun (20261017000001), stat_donem_dogrula (20261005000003). Tablo yazımı yok;
--   mevcut nesneye dokunulmaz.
-- ACL: hepsi SECURITY INVOKER + SET search_path = public, pg_temp; REVOKE ALL FROM PUBLIC, anon, authenticated;
--   GRANT EXECUTE yalnız authenticated (INVOKER zincirinde yardımcıları da çağıran rol çağırır). anon GRANT yok.
-- Hata sözleşmesi (P13): doğrulama hataları RAISE EXCEPTION 'STAT_CUMLE:<yol>:<neden>'; sessiz varsayılan yok.
-- TZ: bugün = stat_bugun() (Europe/Istanbul); sunucu tarihi kullanılmaz.
-- Perf (T5 perf c, root ruling): view'lar okuma başına ≈125 ms (stat_vaka_ovsync_mu tüm vakalarda) ve süzgeç içeri
--   itilmiyor; dönem, hastalık süzgeci ve Ovsync dışlama sayısı stat_cumle_kapsam'da tek yerde çözülür, vaka ve ilaç
--   view'ı orada bir kez okunur; *_k iç yardımcıları bu jsonb'yi kullanır (dış imzalar ve çıktılar aynı).
-- Statik kapı notu (T3 dersi): küme-dönen yerleşik fonksiyonlar FROM/JOIN'de pg_catalog. önekiyle; LATERAL ve
--   AS MATERIALIZED yok; CTE'ler `), ad AS (` biçiminde.
-- Idempotent: CREATE OR REPLACE FUNCTION; ikinci psql -f hatasız.
-- Geri alma: DROP FUNCTION stat_atolye_seri(jsonb,jsonb), stat_atolye_kombinasyon(jsonb,jsonb),
--   stat_atolye_kombinasyon_k(jsonb,jsonb,jsonb), stat_atolye_gruplar(jsonb), stat_atolye_gruplar_k(jsonb,jsonb),
--   stat_wilson(int,int), stat_cumle_donem(jsonb), stat_cumle_kapsam(jsonb), stat_cumle_dogrula(jsonb);
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ── 1. Cümle doğrulama (spec §4.4 şeması + P4, P5, P8) ───────────────────────
CREATE OR REPLACE FUNCTION public.stat_cumle_dogrula(p_cumle jsonb)
RETURNS void
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  c_anahtar CONSTANT text[] := ARRAY['v', 'alan', 'hastalik', 'ilac', 'kiyas_grubu', 'olculer', 'kirilim', 'donem',
                                     'kiyas_duzeyi'];
  c_olcu CONSTANT text[] := ARRAY['saglik_basari', 'saglik_kapanma_gunu', 'saglik_tedavi_suresi', 'saglik_vaka_tl',
                                  'saglik_basari_tl'];
  v_h jsonb := p_cumle->'hastalik';
  v_i jsonb := p_cumle->'ilac';
  v_o jsonb := p_cumle->'olculer';
  v_d jsonb := p_cumle->'donem';
  v_k text;
  v_x text;
  v_y text;
  v_bas date;
  v_bit date;
BEGIN
  IF p_cumle IS NULL OR jsonb_typeof(p_cumle) <> 'object' THEN
    RAISE EXCEPTION 'STAT_CUMLE:cumle:nesne_degil';
  END IF;
  v_k := (SELECT min(t.k) FROM pg_catalog.jsonb_object_keys(p_cumle) AS t(k) WHERE NOT t.k = ANY (c_anahtar));
  IF v_k IS NOT NULL THEN RAISE EXCEPTION 'STAT_CUMLE:%:bilinmeyen_anahtar', v_k; END IF;
  FOREACH v_k IN ARRAY c_anahtar LOOP
    IF NOT p_cumle ? v_k THEN RAISE EXCEPTION 'STAT_CUMLE:%:eksik', v_k; END IF;
  END LOOP;
  IF (p_cumle->'v' = '1'::jsonb) IS NOT TRUE THEN RAISE EXCEPTION 'STAT_CUMLE:v:surum'; END IF;
  IF (p_cumle->'alan' = '"saglik"'::jsonb) IS NOT TRUE THEN RAISE EXCEPTION 'STAT_CUMLE:alan:gecersiz'; END IF;

  -- hastalik: {tip: tumu|kategori|hastalik, deger}
  IF jsonb_typeof(v_h) <> 'object' THEN RAISE EXCEPTION 'STAT_CUMLE:hastalik:nesne_degil'; END IF;
  v_k := (SELECT min(t.k) FROM pg_catalog.jsonb_object_keys(v_h) AS t(k) WHERE NOT t.k = ANY (ARRAY['tip', 'deger']));
  IF v_k IS NOT NULL THEN RAISE EXCEPTION 'STAT_CUMLE:hastalik.%:bilinmeyen_anahtar', v_k; END IF;
  CASE v_h->>'tip'
    WHEN 'tumu' THEN
      IF jsonb_typeof(v_h->'deger') <> 'null' THEN RAISE EXCEPTION 'STAT_CUMLE:hastalik.deger:tumu_ile_deger'; END IF;
    WHEN 'kategori' THEN
      IF COALESCE(jsonb_typeof(v_h->'deger'), '') <> 'string' OR btrim(v_h->>'deger') = '' THEN
        RAISE EXCEPTION 'STAT_CUMLE:hastalik.deger:metin_degil';
      END IF;
    WHEN 'hastalik' THEN
      IF COALESCE(jsonb_typeof(v_h->'deger'), '') <> 'string'
         OR v_h->>'deger' !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        RAISE EXCEPTION 'STAT_CUMLE:hastalik.deger:uuid_degil';
      END IF;
      IF NOT EXISTS (SELECT 1 FROM public.diseases d WHERE d.id = (v_h->>'deger')::uuid) THEN
        RAISE EXCEPTION 'STAT_CUMLE:hastalik.deger:hastalik_yok';
      END IF;
    ELSE RAISE EXCEPTION 'STAT_CUMLE:hastalik.tip:gecersiz';
  END CASE;

  -- ilac: {duzey, x, y}; y için x zorunlu ve y ≠ x
  IF COALESCE(jsonb_typeof(v_i), '') <> 'object' THEN RAISE EXCEPTION 'STAT_CUMLE:ilac:nesne_degil'; END IF;
  v_k := (SELECT min(t.k) FROM pg_catalog.jsonb_object_keys(v_i) AS t(k) WHERE NOT t.k = ANY (ARRAY['duzey', 'x', 'y']));
  IF v_k IS NOT NULL THEN RAISE EXCEPTION 'STAT_CUMLE:ilac.%:bilinmeyen_anahtar', v_k; END IF;
  IF NOT COALESCE(v_i->>'duzey', '') = ANY (ARRAY['etken', 'preparat', 'sinif']) THEN
    RAISE EXCEPTION 'STAT_CUMLE:ilac.duzey:gecersiz';
  END IF;
  FOREACH v_k IN ARRAY ARRAY['x', 'y'] LOOP
    IF COALESCE(jsonb_typeof(v_i->v_k), 'null') NOT IN ('null', 'string') OR btrim(v_i->>v_k) = '' THEN
      RAISE EXCEPTION 'STAT_CUMLE:ilac.%:metin_degil', v_k;
    END IF;
  END LOOP;
  v_x := v_i->>'x';
  v_y := v_i->>'y';
  IF v_y IS NOT NULL AND v_x IS NULL THEN RAISE EXCEPTION 'STAT_CUMLE:ilac.y:x_yok'; END IF;
  IF v_y = v_x THEN RAISE EXCEPTION 'STAT_CUMLE:ilac.y:x_ile_ayni'; END IF;

  IF NOT COALESCE(p_cumle->>'kiyas_grubu', '') = ANY (ARRAY['tumu', 'x_y_siz']) THEN
    RAISE EXCEPTION 'STAT_CUMLE:kiyas_grubu:gecersiz';
  END IF;
  IF p_cumle->>'kiyas_grubu' = 'x_y_siz' AND v_y IS NULL THEN RAISE EXCEPTION 'STAT_CUMLE:kiyas_grubu:y_yok'; END IF;

  -- olculer: boş olmayan, tekrarsız, bilinen ölçüler; doz sunucuda hesaplanmaz (P8)
  IF COALESCE(jsonb_typeof(v_o), '') <> 'array' THEN RAISE EXCEPTION 'STAT_CUMLE:olculer:dizi_degil'; END IF;
  IF jsonb_array_length(v_o) = 0 THEN RAISE EXCEPTION 'STAT_CUMLE:olculer:bos'; END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.jsonb_array_elements(v_o) AS t(e) WHERE jsonb_typeof(t.e) <> 'string') THEN
    RAISE EXCEPTION 'STAT_CUMLE:olculer:metin_degil';
  END IF;
  IF v_o ? 'saglik_doz' THEN RAISE EXCEPTION 'STAT_CUMLE:olculer:doz_hesaplanmaz'; END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.jsonb_array_elements_text(v_o) AS t(e) WHERE NOT t.e = ANY (c_olcu)) THEN
    RAISE EXCEPTION 'STAT_CUMLE:olculer:bilinmeyen';
  END IF;
  IF (SELECT count(DISTINCT t.e) FROM pg_catalog.jsonb_array_elements_text(v_o) AS t(e)) < jsonb_array_length(v_o) THEN
    RAISE EXCEPTION 'STAT_CUMLE:olculer:tekrar';
  END IF;

  IF NOT COALESCE(p_cumle->>'kirilim', '') = ANY (ARRAY['yok', 'ilac', 'ay', 'ceyrek', 'yil']) THEN
    RAISE EXCEPTION 'STAT_CUMLE:kirilim:gecersiz';
  END IF;
  IF v_x IS NOT NULL AND p_cumle->>'kirilim' = 'ilac' THEN RAISE EXCEPTION 'STAT_CUMLE:kirilim:x_ile_ilac'; END IF;

  -- donem: son_ay{n∈3,6,12,24} | yil{yil} | aralik{bas,bit} | tumu (P5)
  IF COALESCE(jsonb_typeof(v_d), '') <> 'object' THEN RAISE EXCEPTION 'STAT_CUMLE:donem:nesne_degil'; END IF;
  IF NOT COALESCE(v_d->>'tip', '') = ANY (ARRAY['son_ay', 'yil', 'aralik', 'tumu']) THEN
    RAISE EXCEPTION 'STAT_CUMLE:donem.tip:gecersiz';
  END IF;
  v_k := (SELECT min(t.k) FROM pg_catalog.jsonb_object_keys(v_d) AS t(k)
           WHERE NOT t.k = ANY (CASE v_d->>'tip' WHEN 'son_ay' THEN ARRAY['tip', 'n'] WHEN 'yil' THEN ARRAY['tip', 'yil']
                                                 WHEN 'aralik' THEN ARRAY['tip', 'bas', 'bit'] ELSE ARRAY['tip'] END));
  IF v_k IS NOT NULL THEN RAISE EXCEPTION 'STAT_CUMLE:donem.%:bilinmeyen_anahtar', v_k; END IF;
  CASE v_d->>'tip'
    WHEN 'son_ay' THEN
      IF COALESCE(jsonb_typeof(v_d->'n'), '') <> 'number' OR NOT v_d->>'n' = ANY (ARRAY['3', '6', '12', '24']) THEN
        RAISE EXCEPTION 'STAT_CUMLE:donem.n:gecersiz';
      END IF;
    WHEN 'yil' THEN
      IF COALESCE(jsonb_typeof(v_d->'yil'), '') <> 'number'
         OR NOT (CASE WHEN v_d->>'yil' ~ '^[0-9]{4}$' THEN (v_d->>'yil')::int BETWEEN 1900 AND 2100 ELSE false END) THEN
        RAISE EXCEPTION 'STAT_CUMLE:donem.yil:gecersiz';
      END IF;
    WHEN 'aralik' THEN
      FOREACH v_k IN ARRAY ARRAY['bas', 'bit'] LOOP
        IF COALESCE(jsonb_typeof(v_d->v_k), '') <> 'string' OR v_d->>v_k !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
          RAISE EXCEPTION 'STAT_CUMLE:donem.%:tarih_degil', v_k;
        END IF;
      END LOOP;
      BEGIN
        v_bas := (v_d->>'bas')::date;
        v_bit := (v_d->>'bit')::date;
      EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN
        RAISE EXCEPTION 'STAT_CUMLE:donem:tarih_degil';
      END;
      IF v_bit < v_bas THEN RAISE EXCEPTION 'STAT_CUMLE:donem:ters'; END IF;
    ELSE NULL;
  END CASE;

  IF (p_cumle->'kiyas_duzeyi' = '["biz"]'::jsonb) IS NOT TRUE THEN
    RAISE EXCEPTION 'STAT_CUMLE:kiyas_duzeyi:yalniz_biz';
  END IF;
END;
$$;

COMMENT ON FUNCTION public.stat_cumle_dogrula(jsonb) IS
  'AP1 cümle doğrulayıcı (spec §4.4, plan P4/P5/P8/P13): anahtar kümesi tam {v, alan, hastalik, ilac, kiyas_grubu, olculer, '
  'kirilim, donem, kiyas_duzeyi}; iç nesnelerde de bilinmeyen anahtar, yanlış tip ve geçersiz değer '
  'RAISE ''STAT_CUMLE:<yol>:<neden>'' verir (fail-closed, sessiz varsayılan yok).';

-- ── 2. Dönem (bugün = stat_bugun) ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.stat_cumle_donem(p_cumle jsonb, OUT bas date, OUT "bit" date)
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_d jsonb := p_cumle->'donem';
  v_bugun date := public.stat_bugun();
BEGIN
  PERFORM public.stat_cumle_dogrula(p_cumle);
  "bit" := v_bugun;
  CASE v_d->>'tip'
    WHEN 'son_ay' THEN
      bas := (v_bugun - make_interval(months => (v_d->>'n')::int))::date;
    WHEN 'yil' THEN
      bas := make_date((v_d->>'yil')::int, 1, 1);
      "bit" := make_date((v_d->>'yil')::int, 12, 31);
    WHEN 'aralik' THEN
      bas := (v_d->>'bas')::date;
      "bit" := (v_d->>'bit')::date;
      PERFORM public.stat_donem_dogrula(bas, "bit");
    ELSE   -- tumu: alt sınır kapsamdan (hastalık süzgeci yalnız stat_cumle_kapsam'da)
      bas := (public.stat_cumle_kapsam(p_cumle)->>'bas')::date;
  END CASE;
END;
$$;

COMMENT ON FUNCTION public.stat_cumle_donem(jsonb) IS
  'Cümlenin dönemi [bas, bit] (spec §4.4, P5): son_ay n → [bugün − n ay, bugün]; yil → [Y-01-01, Y-12-31]; aralik → '
  'stat_donem_dogrula sonrası; tumu → [hastalık süzgecine uyan kapsam vakalarının en eski başlangıcı (yoksa bugün), bugün] '
  '(stat_cumle_kapsam''dan).';

CREATE OR REPLACE FUNCTION public.stat_cumle_kapsam(p_cumle jsonb)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_tip text := p_cumle#>>'{hastalik,tip}';
  v_hid uuid;
  v_kat text;
  v_bas date;
  v_bit date;
  v_sonuc jsonb;
BEGIN
  PERFORM public.stat_cumle_dogrula(p_cumle);
  IF v_tip = 'hastalik' THEN v_hid := (p_cumle#>>'{hastalik,deger}')::uuid; END IF;
  IF v_tip = 'kategori' THEN v_kat := p_cumle#>>'{hastalik,deger}'; END IF;
  IF p_cumle#>>'{donem,tip}' = 'tumu' THEN
    v_bit := public.stat_bugun();   -- alt sınır aşağıdaki okumadan
  ELSE
    SELECT d.bas, d.bit INTO v_bas, v_bit FROM public.stat_cumle_donem(p_cumle) AS d;   -- bu yol view okumaz
  END IF;

  WITH c AS (   -- her vaka bir satır: s = cümlenin hastalık süzgeci (tek tanım), r = kapsam satırı (Ovsync dışı, yoksa NULL)
    SELECT c.id, c.start_date AS bas, v.r,
           COALESCE(CASE v_tip WHEN 'tumu' THEN true WHEN 'hastalik' THEN c.disease_id = v_hid
                               ELSE COALESCE(d.category, 'Kategorisiz') = v_kat END, false) AS s
    FROM public.cases c
    LEFT JOIN public.diseases d ON d.id = c.disease_id
    LEFT JOIN (SELECT v.vaka_id, to_jsonb(v) AS r FROM public.v_stat_saglik_vaka v) v ON v.vaka_id = c.id
  ), b AS (     -- dönem=tumu: süzgece uyan kapsam vakalarının en eski başlangıcı (yoksa bugün)
    SELECT COALESCE(v_bas, LEAST(COALESCE(min(c.bas) FILTER (WHERE c.s AND c.r IS NOT NULL), v_bit), v_bit)) AS bas FROM c
  ), k AS (
    SELECT c.* FROM c CROSS JOIN b WHERE c.bas BETWEEN b.bas AND v_bit
  )
  SELECT jsonb_build_object(
           'bas', b.bas, 'bit', v_bit,
           'vakalar', COALESCE((SELECT jsonb_agg(k.r) FROM k WHERE k.s AND k.r IS NOT NULL), '[]'::jsonb),
           'diger', COALESCE((SELECT jsonb_agg(k.r) FROM k WHERE NOT k.s AND k.r IS NOT NULL), '[]'::jsonb),
           -- kapsam satırı olan vaka Ovsync değildir; stat_vaka_ovsync_mu yalnız satırı olmayanlara sorulur
           'dislanan_ovsync_n', (SELECT count(*) FROM k
                                  WHERE CASE WHEN k.s AND k.r IS NULL THEN public.stat_vaka_ovsync_mu(k.id) ELSE false END),
           'ilac', COALESCE((SELECT jsonb_agg(jsonb_build_object('vaka_id', i.vaka_id, 'deger', i.deger))
                             FROM public.v_stat_saglik_vaka_ilac i
                             WHERE i.duzey = p_cumle#>>'{ilac,duzey}'
                               AND i.vaka_id IN (SELECT k.id FROM k WHERE k.s AND k.r IS NOT NULL)), '[]'::jsonb))
    INTO v_sonuc
  FROM b;
  RETURN v_sonuc;
END;
$$;

COMMENT ON FUNCTION public.stat_cumle_kapsam(jsonb) IS
  'Cümlenin kapsamı (T5 perf c): cümle doğrulanır; {bas, bit (stat_cumle_donem kuralı), vakalar = dönemde (baslangic) '
  'hastalık süzgecine uyan v_stat_saglik_vaka satırları (açık dahil), diger = dönemde süzgece uymayanlar, '
  'dislanan_ovsync_n = dönemde süzgece uyan Ovsync vakası sayısı (cases LEFT JOIN diseases; hastalıksız vaka view''da '
  'yok, review T4 tur1 #5), ilac = vakalar''ın seçili düzeydeki {vaka_id, deger} satırları}. Vaka ve ilaç view''ı bir kez '
  'okunur; stat_atolye_*_k yardımcıları bu nesneyi kullanır.';

-- ── 3. Wilson %95 ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.stat_wilson(p_k int, p_n int, OUT alt numeric, OUT ust numeric)
LANGUAGE sql IMMUTABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT CASE WHEN w.ok THEN round(greatest(0, 100 * (w.m - w.h)), 1) END,
         CASE WHEN w.ok THEN round(least(100, 100 * (w.m + w.h)), 1) END
  FROM (SELECT r.ok, (r.p + r.z2 / (2 * r.n)) / (1 + r.z2 / r.n) AS m,
               1.96 * sqrt(r.p * (1 - r.p) / r.n + r.z2 / (4 * r.n * r.n)) / (1 + r.z2 / r.n) AS h
        FROM (SELECT COALESCE(p_n > 0 AND p_k BETWEEN 0 AND p_n, false) AS ok, 3.8416::numeric AS z2,
                     CASE WHEN p_n > 0 AND p_k BETWEEN 0 AND p_n THEN p_n::numeric END AS n,
                     CASE WHEN p_n > 0 AND p_k BETWEEN 0 AND p_n THEN p_k::numeric / p_n END AS p) r) w;
$$;

COMMENT ON FUNCTION public.stat_wilson(int, int) IS
  'Wilson %95 aralığı (z = 1.96): merkez = (p + z²/2n)/(1 + z²/n), yarı = z·√(p(1−p)/n + z²/4n²)/(1 + z²/n); alt/üst yüzde, '
  '1 ondalık, [0, 100]''e kırpılır; n ≤ 0 ya da k ∉ [0, n] → NULL, NULL.';

-- ── 4. Gruplar ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.stat_atolye_gruplar_k(p_cumle jsonb, p_kapsam jsonb)
RETURNS TABLE(anahtar text, etiket text, sira int, vaka_id uuid)
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_tip text := p_cumle#>>'{hastalik,tip}';
  v_x text := p_cumle#>>'{ilac,x}';
  v_y text := p_cumle#>>'{ilac,y}';
  v_tumu text;
  v_kap uuid[];
  v_xs uuid[];
  v_ys uuid[];
  v_siz text;
  v_grup jsonb;
BEGIN
  PERFORM public.stat_cumle_dogrula(p_cumle);
  v_tumu := CASE v_tip WHEN 'hastalik' THEN 'Tüm ' || (SELECT d.name FROM public.diseases d
                                                         WHERE d.id = (p_cumle#>>'{hastalik,deger}')::uuid) || ' vakaları'
                       WHEN 'kategori' THEN 'Tüm ' || (p_cumle#>>'{hastalik,deger}') || ' vakaları' ELSE 'Tüm vakalar' END;
  v_kap := ARRAY(SELECT v.vaka_id FROM pg_catalog.jsonb_to_recordset(p_kapsam->'vakalar') AS v(vaka_id uuid));

  IF v_x IS NULL AND p_cumle->>'kirilim' = 'ilac' THEN
    -- seçili düzeydeki her değer bir grup: vaka sayısı azalan, (bilinmiyor) en son
    SELECT COALESCE(jsonb_agg(jsonb_build_object('a', 'ilac:' || q.deger, 'e', q.deger || ' içeren', 's', q.s, 'ids', q.ids)
                              ORDER BY q.s), '[]'::jsonb)
      INTO v_grup
    FROM (SELECT i.deger, array_agg(i.vaka_id) AS ids,
                 row_number() OVER (ORDER BY i.deger = '(bilinmiyor)', count(*) DESC, i.deger) AS s
          FROM pg_catalog.jsonb_to_recordset(p_kapsam->'ilac') AS i(vaka_id uuid, deger text)
          GROUP BY i.deger) q;
  ELSIF v_x IS NULL THEN
    v_grup := jsonb_build_array(jsonb_build_object('a', 'tumu', 'e', v_tumu, 's', 1, 'ids', v_kap));
  ELSE
    SELECT COALESCE(array_agg(i.vaka_id) FILTER (WHERE i.deger = v_x), '{}'),
           COALESCE(array_agg(i.vaka_id) FILTER (WHERE i.deger = v_y), '{}')
      INTO v_xs, v_ys
    FROM pg_catalog.jsonb_to_recordset(p_kapsam->'ilac') AS i(vaka_id uuid, deger text);
    -- ek: son ünlüye göre, kombinasyon.js _kombinasyonSiz ile aynı kural (İ→i, I→ı; ünlüsüz → siz)
    v_siz := CASE substring(reverse(translate(v_y, 'AIEİOÖUÜ', 'aıeioöuü')) FROM '[aıeiouöü]')
               WHEN 'a' THEN 'sız' WHEN 'ı' THEN 'sız' WHEN 'o' THEN 'suz' WHEN 'u' THEN 'suz'
               WHEN 'ö' THEN 'süz' WHEN 'ü' THEN 'süz' ELSE 'siz' END;
    v_grup := CASE
      WHEN v_y IS NULL THEN jsonb_build_array(
        jsonb_build_object('a', 'x', 'e', v_x || ' içeren', 's', 1, 'ids', v_xs),
        jsonb_build_object('a', 'tumu', 'e', v_tumu, 's', 2, 'ids', v_kap))
      ELSE jsonb_build_array(
        jsonb_build_object('a', 'xy', 'e', v_x || ' + ' || v_y || ' içeren', 's', 1,
                           'ids', ARRAY(SELECT u.id FROM pg_catalog.unnest(v_xs) AS u(id) WHERE u.id = ANY (v_ys))),
        CASE WHEN p_cumle->>'kiyas_grubu' = 'x_y_siz'
             THEN jsonb_build_object('a', 'x_y_siz', 'e', v_x || ' içeren, ' || v_y || '''' || v_siz, 's', 2,
                                     'ids', ARRAY(SELECT u.id FROM pg_catalog.unnest(v_xs) AS u(id) WHERE NOT u.id = ANY (v_ys)))
             ELSE jsonb_build_object('a', 'tumu', 'e', v_tumu, 's', 2, 'ids', v_kap) END) END;
  END IF;

  -- boş grup da bir satır taşır (vaka_id NULL): zarfta n = 0 olarak görünür
  RETURN QUERY
  SELECT g.a, g.e, g.s, u.id
  FROM pg_catalog.jsonb_to_recordset(v_grup) AS g(a text, e text, s int, ids uuid[])
  LEFT JOIN pg_catalog.unnest(g.ids) AS u(id) ON true
  ORDER BY g.s, u.id;
END;
$$;

COMMENT ON FUNCTION public.stat_atolye_gruplar_k(jsonb, jsonb) IS
  'stat_atolye_gruplar''ın iç gövdesi: p_kapsam = stat_cumle_kapsam(p_cumle) (view okumaz).';

CREATE OR REPLACE FUNCTION public.stat_atolye_gruplar(p_cumle jsonb)
RETURNS TABLE(anahtar text, etiket text, sira int, vaka_id uuid)
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT g.anahtar, g.etiket, g.sira, g.vaka_id
  FROM public.stat_atolye_gruplar_k(p_cumle, public.stat_cumle_kapsam(p_cumle)) AS g;
$$;

COMMENT ON FUNCTION public.stat_atolye_gruplar(jsonb) IS
  'Cümlenin grupları (spec §4.4, M4, P4): dönem (baslangic) + hastalık süzgeçli kapsam vakaları (açık dahil); x yok → '
  'tumu (kırılım ilac ise seçili düzeyin her değeri, n azalan, (bilinmiyor) en son); x → [x, tumu]; x+y → [xy, tumu | x_y_siz]. '
  'Gruplar örtüşebilir; boş grup vaka_id NULL tek satırla döner.';

-- ── 5. Kombinasyon paneli (T5 doldurur) ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.stat_atolye_kombinasyon(p_cumle jsonb, p_gecici jsonb)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$ SELECT NULL::jsonb $$;

CREATE OR REPLACE FUNCTION public.stat_atolye_kombinasyon_k(p_cumle jsonb, p_fiyat jsonb, p_kapsam jsonb)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$ SELECT NULL::jsonb $$;

COMMENT ON FUNCTION public.stat_atolye_kombinasyon(jsonb, jsonb) IS
  'Kombinasyon paneli (spec §4.4): T4''te NULL döner; T5 değiştirir.';
COMMENT ON FUNCTION public.stat_atolye_kombinasyon_k(jsonb, jsonb, jsonb) IS
  'Kombinasyon panelinin iç gövdesi (p_kapsam = stat_cumle_kapsam): T4''te NULL; T5 değiştirir. stat_atolye_seri bunu çağırır.';

-- ── 6. Seri (zarflar) ──────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.stat_atolye_seri(p_cumle jsonb, p_gecici jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  c_esik CONSTANT int := 5;   -- K8
  c_surum CONSTANT text := 'sql:20261017000002';
  c_basari CONSTANT text[] := ARRAY['basarili', 'basarisiz_olum_kesim', 'basarisiz_tedavi_degisti', 'basarisiz_nuks'];
  v_kir text := p_cumle->>'kirilim';
  v_kapsam jsonb;
  v_birim text;
  v_fiyat jsonb;
  v_bas date;
  v_bit date;
  v_g int;
  v_normal_n int;
  v_dislanan int;
  v_bilinmeyen uuid[];
  v_base jsonb;
  v_grup jsonb;
  v_per jsonb;
  v_sayac jsonb;
  v_eksik jsonb;
  v_dip_on text[] := '{}';
  v_dip_son text[] := '{}';
  v_olcum text;
  v_tl boolean;
  v_ond int;
  v_ad text;
  v_cikar text[];
  v_zarf jsonb;
  v_zarflar jsonb := '[]'::jsonb;
BEGIN
  PERFORM public.stat_cumle_dogrula(p_cumle);
  -- p_gecici = {"ilac_fiyat": {"<stok_id>": sayı > 0}}; DB'ye ve cümleye girmez (V11)
  p_gecici := COALESCE(p_gecici, '{}'::jsonb);
  IF jsonb_typeof(p_gecici) <> 'object' THEN RAISE EXCEPTION 'STAT_CUMLE:gecici:nesne_degil'; END IF;
  v_olcum := (SELECT min(t.k) FROM pg_catalog.jsonb_object_keys(p_gecici) AS t(k) WHERE t.k <> 'ilac_fiyat');
  IF v_olcum IS NOT NULL THEN RAISE EXCEPTION 'STAT_CUMLE:gecici.%:bilinmeyen_anahtar', v_olcum; END IF;
  v_fiyat := COALESCE(p_gecici->'ilac_fiyat', '{}'::jsonb);
  IF jsonb_typeof(v_fiyat) <> 'object' THEN RAISE EXCEPTION 'STAT_CUMLE:gecici.ilac_fiyat:nesne_degil'; END IF;
  IF EXISTS (SELECT 1 FROM pg_catalog.jsonb_each(v_fiyat) AS t(k, d)
              WHERE CASE WHEN jsonb_typeof(t.d) = 'number' THEN (t.d #>> '{}')::numeric <= 0 ELSE true END) THEN
    RAISE EXCEPTION 'STAT_CUMLE:gecici.ilac_fiyat:pozitif_sayi_degil';
  END IF;

  -- dönem, kapsam satırları ve Ovsync sayısı: view'lar burada bir kez okunur, sonrası jsonb üzerinde
  v_kapsam := public.stat_cumle_kapsam(p_cumle);
  v_bas := (v_kapsam->>'bas')::date;
  v_bit := (v_kapsam->>'bit')::date;
  v_dislanan := (v_kapsam->>'dislanan_ovsync_n')::int;
  SELECT s.g, s.normal_n INTO v_g, v_normal_n FROM public.stat_saglik_vekil() AS s;
  v_birim := CASE v_kir WHEN 'ay' THEN 'month' WHEN 'ceyrek' THEN 'quarter' WHEN 'yil' THEN 'year' END;
  v_bilinmeyen := ARRAY(SELECT i.vaka_id FROM pg_catalog.jsonb_to_recordset(v_kapsam->'ilac') AS i(vaka_id uuid, deger text)
                         WHERE i.deger = '(bilinmiyor)');

  -- (grup, vaka) tabanı
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
           'a', g.anahtar, 'e', g.etiket, 's', g.sira, 'id', g.vaka_id, 'durum', v.durum, 'sonuc', v.sonuc,
           'kg', v.kapanma_gunu, 'vekil', v.kapanma_vekil, 'ts', v.tedavi_suresi_gun, 'kalem', v.maliyet_kalemleri,
           'tl', public.stat_saglik_vaka_tl(v.maliyet_kalemleri, v_fiyat),
           'kaynak', CASE WHEN v.maliyet_kalemleri <> '[]'::jsonb
                          THEN public.stat_saglik_fiyat_kaynagi(v.maliyet_kalemleri, v_fiyat) END,
           'bilinmiyor', g.vaka_id = ANY (v_bilinmeyen),
           'per', date_trunc(v_birim, v.baslangic::timestamp)::date)), '[]'::jsonb)
    INTO v_base
  FROM public.stat_atolye_gruplar_k(p_cumle, v_kapsam) AS g
  LEFT JOIN pg_catalog.jsonb_to_recordset(v_kapsam->'vakalar')
         AS v(vaka_id uuid, baslangic date, durum text, sonuc text, kapanma_gunu int, kapanma_vekil boolean,
              tedavi_suresi_gun int, maliyet_kalemleri jsonb) ON v.vaka_id = g.vaka_id;

  SELECT COALESCE(jsonb_agg(DISTINCT jsonb_build_object('a', t.a, 'e', t.e, 's', t.s)), '[]'::jsonb) INTO v_grup
  FROM pg_catalog.jsonb_to_recordset(v_base) AS t(a text, e text, s int);
  IF v_birim IS NULL THEN
    v_per := '[{"p": null, "e": null}]'::jsonb;
  ELSE   -- P12: dönemdeki tüm periyotlar, boşlar dahil
    SELECT jsonb_agg(jsonb_build_object('p', t.p::date, 'e', CASE v_kir WHEN 'ay' THEN to_char(t.p, 'YYYY-MM')
                     WHEN 'ceyrek' THEN to_char(t.p, 'YYYY "Ç"Q') ELSE to_char(t.p, 'YYYY') END) ORDER BY t.p)
      INTO v_per
    FROM pg_catalog.generate_series(date_trunc(v_birim, v_bas::timestamp), date_trunc(v_birim, v_bit::timestamp),
                                    CASE v_birim WHEN 'quarter' THEN interval '3 months' ELSE ('1 ' || v_birim)::interval END) AS t(p);
  END IF;

  -- sayaçlar: grupların birleşimindeki tekil vakalar üzerinden (kiyas_n zarf başına eklenir)
  SELECT jsonb_build_object(
           'acik_n', count(DISTINCT t.id) FILTER (WHERE t.durum = 'acik'),
           'olgunlasmamis_n', count(DISTINCT t.id) FILTER (WHERE t.sonuc = 'olgunlasmamis'),
           'vekil_n', count(DISTINCT t.id) FILTER (WHERE t.vekil AND t.kg IS NOT NULL),
           'vekil_G', v_g,
           'fiyatsiz_n', count(DISTINCT t.id) FILTER (WHERE t.durum = 'sonuclandi' AND t.tl IS NULL),
           'dislanan_ovsync_n', v_dislanan,
           'bilinmiyor_n', count(DISTINCT t.id) FILTER (WHERE t.bilinmiyor),
           'kapali_tarihsiz_n', count(DISTINCT t.id) FILTER (WHERE t.durum = 'kapali_tarihsiz'),
           'ilacsiz_n', count(DISTINCT t.id) FILTER (WHERE t.durum = 'sonuclandi' AND t.kalem = '[]'::jsonb),
           'tedavi_degisti_n', count(DISTINCT t.id) FILTER (WHERE t.sonuc = 'basarisiz_tedavi_degisti'))
    INTO v_sayac
  FROM pg_catalog.jsonb_to_recordset(v_base) AS t(id uuid, durum text, sonuc text, vekil boolean, kg int, tl numeric,
                                                  bilinmiyor boolean, kalem jsonb);

  -- dipnot (sıra sabit; k = 0 cümlesi basılmaz)
  IF v_dislanan > 0 THEN
    v_dip_on := v_dip_on || format('Ovsync üreme protokolü vakaları dahil değil (%s).', v_dislanan);
  END IF;
  IF jsonb_array_length(v_grup) >= 2   -- tek/boş ilaç grubunda örtüşme yok (review T4 tur1 #1)
     AND (v_kir = 'ilac' OR (p_cumle#>>'{ilac,x}' IS NOT NULL AND NOT p_cumle->>'kiyas_grubu' = 'x_y_siz')) THEN
    v_dip_on := v_dip_on || 'Gruplar örtüşür: bir vaka birden çok satırda sayılır.'::text;
  END IF;
  IF (v_sayac->>'vekil_n')::int > 0 THEN
    v_dip_on := v_dip_on || format('%s vaka toplu kapatılmış; kapanma günü son ilaç + %s gün ile tahmin edildi.',
                                   v_sayac->>'vekil_n', v_g);
  END IF;
  IF v_normal_n < c_esik THEN
    v_dip_on := v_dip_on || 'Vekil G hesaplanamadı (normal vaka n<5); G=0 kullanıldı.'::text;
  END IF;
  IF (v_sayac->>'kapali_tarihsiz_n')::int > 0 THEN
    v_dip_on := v_dip_on || format('%s vaka kapalı ama kapanış tarihi yok; hesaba girmedi.', v_sayac->>'kapali_tarihsiz_n');
  END IF;
  IF (v_sayac->>'tedavi_degisti_n')::int > 0 THEN
    v_dip_on := v_dip_on || format('%s vaka 24 saat içinde yeniden açıldı (tedavi değişti).', v_sayac->>'tedavi_degisti_n');
  END IF;
  IF (v_sayac->>'bilinmiyor_n')::int > 0 THEN
    v_dip_on := v_dip_on || format('%s vakanın ilacı tanınamadı: (bilinmiyor).', v_sayac->>'bilinmiyor_n');
  END IF;
  IF jsonb_array_length(v_grup) >= 2 THEN
    v_dip_son := ARRAY['Karşılaştırma gözlemseldir; şiddet/yaş eşleştirmesi yok.'];
  END IF;

  FOR v_olcum IN SELECT t.o FROM pg_catalog.jsonb_array_elements_text(p_cumle->'olculer') WITH ORDINALITY AS t(o, i)
                 ORDER BY t.i LOOP
    v_tl := v_olcum IN ('saglik_vaka_tl', 'saglik_basari_tl');
    v_ond := CASE WHEN v_tl THEN 2 ELSE 1 END;
    v_ad := CASE v_olcum WHEN 'saglik_basari' THEN 'başarı %' WHEN 'saglik_kapanma_gunu' THEN 'kapanma günü'
                         WHEN 'saglik_tedavi_suresi' THEN 'tedavi süresi (gün)' WHEN 'saglik_vaka_tl' THEN 'vaka başı ₺'
                         ELSE 'başarı başına ₺' END;
    v_cikar := CASE v_olcum WHEN 'saglik_basari' THEN ARRAY['q1', 'q3'] WHEN 'saglik_basari_tl' THEN ARRAY['k', 'alt', 'ust', 'q1', 'q3']
                            ELSE ARRAY['k', 'alt', 'ust'] END;
    -- kümeler (spec §4.3, P6, P7): yalnız sonuçlanmış vaka; açık/kapali_tarihsiz hiçbir ölçüye girmez;
    --   ilaçsız vaka (kalem []) ₺ kümelerinin payına ve paydasına girmez (R1), diğer ölçülerde kalır
    WITH b AS (
      SELECT t.a, t.per, t.sonuc, t.tl, t.kaynak,
             CASE v_olcum WHEN 'saglik_kapanma_gunu' THEN t.kg WHEN 'saglik_tedavi_suresi' THEN t.ts ELSE t.tl END::numeric AS d,
             CASE v_olcum WHEN 'saglik_basari' THEN t.sonuc = ANY (c_basari)
                          WHEN 'saglik_kapanma_gunu' THEN t.durum = 'sonuclandi' AND t.kg IS NOT NULL
                          WHEN 'saglik_tedavi_suresi' THEN t.durum = 'sonuclandi' AND t.ts IS NOT NULL
                          WHEN 'saglik_vaka_tl' THEN t.durum = 'sonuclandi' AND t.tl IS NOT NULL AND t.kalem <> '[]'::jsonb
                          ELSE t.sonuc = 'basarili' AND t.tl IS NOT NULL AND t.kalem <> '[]'::jsonb END AS uye,   -- basari_tl: payda
             CASE v_olcum WHEN 'saglik_vaka_tl' THEN t.durum = 'sonuclandi'
                          WHEN 'saglik_basari_tl' THEN t.sonuc = ANY (c_basari) END
               AND t.kalem <> '[]'::jsonb AS tl_aday                                                  -- ₺ pay/fiyat kümesi
      FROM pg_catalog.jsonb_to_recordset(v_base) AS t(a text, per date, durum text, sonuc text, kg int, ts int,
                                                      tl numeric, kaynak text, kalem jsonb)
    ), h AS (
      SELECT g.a, g.e, g.s, p.p, p.e AS pe,
             (count(b.a) FILTER (WHERE b.uye))::int AS n,
             (count(b.a) FILTER (WHERE b.uye AND b.sonuc = 'basarili'))::int AS k,
             percentile_cont(ARRAY[0.25, 0.5, 0.75]) WITHIN GROUP (ORDER BY b.d) FILTER (WHERE b.uye) AS q,
             sum(b.tl) FILTER (WHERE b.tl_aday AND b.tl IS NOT NULL) AS pay
      FROM pg_catalog.jsonb_to_recordset(v_grup) AS g(a text, e text, s int)
      CROSS JOIN pg_catalog.jsonb_to_recordset(v_per) AS p(p date, e text)
      LEFT JOIN b ON b.a = g.a AND (p.p IS NULL OR b.per = p.p)
      GROUP BY g.a, g.e, g.s, p.p, p.e
    ), c AS (
      SELECT h.a, h.e, h.s, h.p, h.n, h.k,
             CASE WHEN h.n < c_esik THEN NULL
                  WHEN v_olcum = 'saglik_basari' THEN round(100.0 * h.k / h.n, 1)
                  WHEN v_olcum = 'saglik_basari_tl' THEN round(h.pay / h.n, 2)
                  ELSE round(h.q[2]::numeric, v_ond) END AS y,
             CASE WHEN h.n >= c_esik THEN round(h.q[1]::numeric, v_ond) END AS q1,
             CASE WHEN h.n >= c_esik THEN round(h.q[3]::numeric, v_ond) END AS q3,
             CASE WHEN h.n >= c_esik THEN (public.stat_wilson(h.k, h.n)).alt END AS alt,
             CASE WHEN h.n >= c_esik THEN (public.stat_wilson(h.k, h.n)).ust END AS ust
      FROM h
    )
    SELECT jsonb_build_object(
      'olcum', v_olcum, 'hesap_at', now(), 'surum', c_surum,
      'n', COALESCE((SELECT sum(c.n) FROM c WHERE c.s = 1), 0),
      'yetersiz', COALESCE((SELECT sum(c.n) FROM c WHERE c.s = 1), 0) < c_esik,
      'x', CASE WHEN v_birim IS NULL
                THEN jsonb_build_object('ad', 'grup', 'deger', COALESCE((SELECT jsonb_agg(c.e ORDER BY c.s) FROM c), '[]'),
                                        'anahtar', COALESCE((SELECT jsonb_agg(c.a ORDER BY c.s) FROM c), '[]'))
                ELSE jsonb_build_object('ad', v_kir,
                       'deger', (SELECT jsonb_agg(t.e ORDER BY t.p) FROM pg_catalog.jsonb_to_recordset(v_per) AS t(p date, e text)),
                       'anahtar', (SELECT jsonb_agg(t.p ORDER BY t.p) FROM pg_catalog.jsonb_to_recordset(v_per) AS t(p date)))
           END,
      'seriler', (SELECT COALESCE(jsonb_agg(r.o ORDER BY r.s), '[]') FROM (
                    SELECT min(c.s) AS s,
                           (CASE WHEN v_birim IS NULL THEN jsonb_build_object('ad', v_ad)
                                 ELSE jsonb_build_object('ad', min(c.e), 'anahtar', min(c.a)) END
                            || jsonb_build_object('n', jsonb_agg(c.n ORDER BY c.s, c.p), 'k', jsonb_agg(c.k ORDER BY c.s, c.p),
                                                  'y', jsonb_agg(c.y ORDER BY c.s, c.p),
                                                  'alt', jsonb_agg(c.alt ORDER BY c.s, c.p),
                                                  'ust', jsonb_agg(c.ust ORDER BY c.s, c.p),
                                                  'q1', jsonb_agg(c.q1 ORDER BY c.s, c.p),
                                                  'q3', jsonb_agg(c.q3 ORDER BY c.s, c.p))) - v_cikar AS o
                    FROM c GROUP BY CASE WHEN v_birim IS NULL THEN NULL ELSE c.a END) r),
      'sayac', v_sayac || jsonb_build_object('kiyas_n', (SELECT sum(c.n) FROM c WHERE c.s = 2)),
      'gecici', jsonb_build_object('var', v_fiyat <> '{}'::jsonb, 'ilac_fiyat', v_fiyat),
      'tanim', v_olcum,
      -- ₺ zarfında ilaçsız dipnotu fiyat dipnotunun hemen önünde: ikisi de ₺ kümesinden düşen vakayı sayar
      'dipnot', to_jsonb(v_dip_on || CASE WHEN v_tl AND (v_sayac->>'ilacsiz_n')::int > 0
                                          THEN ARRAY[format('%s vaka ilaç uygulanmadığı için ₺ ölçülerine girmedi.',
                                                            v_sayac->>'ilacsiz_n')]
                                          ELSE '{}'::text[] END
                                  || CASE WHEN v_tl AND (v_sayac->>'fiyatsiz_n')::int > 0
                                          THEN ARRAY[format('%s vakanın ilaç fiyatı yok.', v_sayac->>'fiyatsiz_n')]
                                          ELSE '{}'::text[] END || v_dip_son),
      'fiyat_kaynagi', CASE WHEN v_tl THEN (
                         SELECT CASE WHEN bool_or(b.tl_aday AND b.tl IS NOT NULL AND b.kaynak = 'gecici') THEN 'gecici'
                                     WHEN bool_or(b.tl_aday AND b.tl IS NOT NULL AND b.kaynak = 'kayitli') THEN 'kayitli'
                                     WHEN bool_or(b.tl_aday) THEN 'fiyatsiz' END FROM b) END,
      'egri', CASE WHEN v_olcum = 'saglik_kapanma_gunu' AND v_birim IS NULL THEN (
                SELECT jsonb_agg(jsonb_build_object('anahtar', g.a, 'gun', COALESCE(e.gun, '[]'), 'oran', COALESCE(e.oran, '[]'))
                                 ORDER BY g.s)
                FROM pg_catalog.jsonb_to_recordset(v_grup) AS g(a text, s int)
                LEFT JOIN (SELECT q.a, jsonb_agg(q.d ORDER BY q.d) AS gun, jsonb_agg(q.o ORDER BY q.d) AS oran
                           FROM (SELECT b.a, b.d::int AS d,
                                        round(sum(count(*)) OVER (PARTITION BY b.a ORDER BY b.d)
                                              / sum(count(*)) OVER (PARTITION BY b.a), 3) AS o
                                 FROM b WHERE b.uye GROUP BY b.a, b.d) q
                           WHERE q.a IN (SELECT c.a FROM c WHERE c.n >= c_esik)
                           GROUP BY q.a) e ON e.a = g.a) END)
      INTO v_zarf;
    v_zarflar := v_zarflar || jsonb_build_array(v_zarf);
  END LOOP;

  -- fiyat_eksik: sonuçlanmış vakaların kalemlerindeki kayıtlı fiyatı olmayan stoklar (neden dolu kalem hariç)
  SELECT COALESCE(jsonb_agg(jsonb_build_object('stok_id', q.stok_id, 'urun_adi', s.urun_adi, 'birim', s.birim,
                                               'vaka_n', q.n, 'gecici_deger', v_fiyat->q.stok_id)
                            ORDER BY q.n DESC, q.stok_id), '[]'::jsonb)
    INTO v_eksik
  FROM (SELECT e.k->>'stok_id' AS stok_id, count(DISTINCT e.id) AS n
        FROM (SELECT t.id, pg_catalog.jsonb_array_elements(t.kalem) AS k
              FROM pg_catalog.jsonb_to_recordset(v_base) AS t(id uuid, durum text, kalem jsonb)
              WHERE t.durum = 'sonuclandi') e
        WHERE e.k->>'neden' IS NULL
        GROUP BY e.k->>'stok_id') q
  JOIN public.stok s ON s.id = q.stok_id
  WHERE COALESCE(s.maliyet, 0) <= 0;

  RETURN jsonb_build_object('zarflar', v_zarflar, 'kombinasyon', public.stat_atolye_kombinasyon_k(p_cumle, v_fiyat, v_kapsam),
                            'fiyat_eksik', v_eksik);
END;
$$;

COMMENT ON FUNCTION public.stat_atolye_seri(jsonb, jsonb) IS
  'AP1 seri (spec §4.3, §4.5, P6, P7, P12): cümlenin her ölçüsü için bir zarf (gruplar = stat_atolye_gruplar); kümeler yalnız '
  'durum=sonuclandi vakalardan: başarı = sonuc ∈ {basarili, basarisiz_*} (Wilson), kapanma/tedavi = medyan + Q1–Q3, vaka ₺ = '
  'medyan + Q1–Q3, başarı başına ₺ = Σ ₺(başarı kümesi) / başarılı ∩ ₺ hesaplanabilen; ilaçsız vaka (maliyet_kalemleri []) '
  'iki ₺ ölçüsünün payına ve paydasına girmez (root ruling R1; sayac ilacsiz_n, ₺ zarfında dipnot); basarisiz_tedavi_degisti '
  'başarı, tedavi ve ₺ kümelerinde kalır, kapanma günü NULL olduğundan hız ve eğride yoktur (sayac tedavi_degisti_n, dipnot); '
  'n<5 hücrede değerler NULL; '
  'p_gecici yalnız hesapta kullanılır, saklanmaz; sayaçlar grupların birleşimindeki tekil vakalardır.';

-- ── 7. ACL ─────────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION public.stat_cumle_dogrula(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_cumle_donem(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_cumle_kapsam(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_wilson(int, int) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_atolye_gruplar_k(jsonb, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_atolye_gruplar(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_atolye_kombinasyon_k(jsonb, jsonb, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_atolye_kombinasyon(jsonb, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.stat_atolye_seri(jsonb, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.stat_cumle_dogrula(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_cumle_donem(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_cumle_kapsam(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_wilson(int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_atolye_gruplar_k(jsonb, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_atolye_gruplar(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_atolye_kombinasyon_k(jsonb, jsonb, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_atolye_kombinasyon(jsonb, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stat_atolye_seri(jsonb, jsonb) TO authenticated;

COMMIT;
