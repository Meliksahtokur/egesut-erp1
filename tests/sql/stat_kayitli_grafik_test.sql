-- tests/sql/stat_kayitli_grafik_test.sql
-- İstatistik Atölyesi AP1 Task 6 — stat_kayitli_grafik + stat_grafik_listele/kaydet/sil/sirala
-- (spec v2 §4.7, AK-11; plan Task 6, Review Focus 3: cümlede `gecici` → RAISE; domain-rules §14 farm_id).
--
-- HEDEF: YALNIZ demo (ref vtzqjmazsvurxdeondmi). Yazmalar yalnız `E2E-ST2-` başlıklı stat_kayitli_grafik satırları
-- (+ farm_id yabancı tek E2E-ST2- satırı, çiftlik süzgeci için). Vaka fixture'ı (stat_saglik_fixture.sql) GEREKMEZ:
-- cümleler hastalik=tumu ile kurulur, vaka verisi okunmaz.
-- KOŞUM:
--   psql "$OVS_DEMO_DB_URL" -X -v ON_ERROR_STOP=0 -v stat_fixture_ok=true -f tests/sql/stat_kayitli_grafik_test.sql
--   (stat_fixture_ok verilmemiş/false → hiçbir şey yazılmaz, tüm kodlar UNMEASURED kalır.)
-- SONUÇ: _stat_durum(kod, PASS|FAIL|UNMEASURED, etiket); kod başına bir satır. Her test bir DO bloğu; blok içi hata
--   → FAIL + hata metni (migration yokken kırmızı FAIL verir, UNMEASURED'da kalmaz).
-- Çiftliğin gerçek kayıtları korunur: sira'yı değiştiren ya da kayıt silen denemeler zorla geri alınan alt blokta
--   (SQLSTATE ZZ999) koşar; red denemeleri de _st6_hata içinde her durumda geri alınır.
-- TEMİZLİK: başta ve sonda pg_temp._st6_temizle() (baslik LIKE 'E2E-ST2-%'); sonda `artik` = 0.

\if :{?stat_fixture_ok}
\else
\set stat_fixture_ok false
\endif
\echo '=== stat_kayitli_grafik testi ===' stat_fixture_ok= :stat_fixture_ok

DROP TABLE IF EXISTS _stat_durum;
CREATE TEMP TABLE _stat_durum(kod text PRIMARY KEY, deger text, etiket text);
INSERT INTO _stat_durum(kod, deger, etiket) VALUES
  ('kaydet_ekle',              'UNMEASURED', 'p_id NULL → INSERT: sira = max+1, cumle_surum 1, farm_id, cumle aynen'),
  ('kaydet_guncelle',          'UNMEASURED', 'p_id dolu → baslik/cumle/cumle_surum/guncelleme_at; sira/olusturma_at aynı'),
  ('kaydet_guncelle_yok_red',  'UNMEASURED', 'olmayan / yabancı çiftlik id → STAT_GRAFIK:yok'),
  ('kaydet_gecici_red',        'UNMEASURED', 'cümlede gecici → STAT_CUMLE:gecici:bilinmeyen_anahtar (ekle + güncelle)'),
  ('kaydet_gecersiz_cumle_red','UNMEASURED', 'bozuk cümle → STAT_CUMLE:*; tablo değişmez'),
  ('kaydet_bos_baslik_red',    'UNMEASURED', 'boş/boşluk/NULL/121 karakter başlık → CHECK/NOT NULL; 120 karakter geçer'),
  ('listele_sira',             'UNMEASURED', 'sira, olusturma_at sırası; 6 anahtar; yabancı çiftlik yok; boşken []'),
  ('sil',                      'UNMEASURED', 'kayıt silinir, diğerleri kalır'),
  ('sil_yok_red',              'UNMEASURED', 'olmayan / NULL / yabancı çiftlik id → STAT_GRAFIK:yok'),
  ('sirala',                   'UNMEASURED', 'ters çevrilmiş tam küme → sira 1..n dizideki konum; yabancı çiftlik dokunulmaz'),
  ('sirala_eksik_red',         'UNMEASURED', 'eksik / fazla / yabancı / NULL → STAT_GRAFIK:sira_kumesi; sira değişmez'),
  ('sirala_tekrar_red',        'UNMEASURED', 'tekrarlı id → STAT_GRAFIK:sira_kumesi'),
  ('sirala_cok_boyut_red',     'UNMEASURED', 'çok boyutlu dizi (tam küme, n×1) → STAT_GRAFIK:sira_kumesi'),
  ('acl_anon',                 'UNMEASURED', 'tablo: anon 0, PUBLIC 0, authenticated SELECT/INSERT/UPDATE/DELETE; 4 fn: anon 0/4, PUBLIC 0/4, authenticated 4/4'),
  ('rls_acik',                 'UNMEASURED', 'RLS açık, FOR ALL USING(true) WITH CHECK(true); authenticated ile uçtan uca 4 RPC'),
  ('index_var',                'UNMEASURED', 'index (farm_id, sira)'),
  ('tablo_kolonlar',           'UNMEASURED', 'spec §4.7 kolonları: ad/tip/NOT NULL/varsayılan + baslik CHECK'),
  ('invoker',                  'UNMEASURED', '4 fn SECURITY INVOKER + search_path; listele STABLE, diğerleri VOLATILE'),
  ('artik',                    'UNMEASURED', 'E2E-ST2- artık = 0');

\if :stat_fixture_ok
CREATE FUNCTION pg_temp._st6_temizle() RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF to_regclass('public.stat_kayitli_grafik') IS NOT NULL THEN
    DELETE FROM public.stat_kayitli_grafik WHERE baslik LIKE 'E2E-ST2-%';
  END IF;
END $f$;
CREATE FUNCTION pg_temp._st6_artik() RETURNS int LANGUAGE plpgsql AS $f$
DECLARE v int := 0;
BEGIN
  IF to_regclass('public.stat_kayitli_grafik') IS NOT NULL THEN
    SELECT count(*) INTO v FROM public.stat_kayitli_grafik WHERE baslik LIKE 'E2E-ST2-%';
  END IF;
  RETURN v;
END $f$;
-- deneme her durumda geri alınır; dönüş 'HATA_YOK' ya da '<SQLSTATE> <mesaj>'
CREATE FUNCTION pg_temp._st6_hata(p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE p_sql;
  RAISE EXCEPTION USING ERRCODE = 'ZZ999', MESSAGE = 'HATA_YOK';
EXCEPTION WHEN OTHERS THEN
  RETURN CASE WHEN SQLSTATE = 'ZZ999' THEN 'HATA_YOK' ELSE SQLSTATE || ' ' || SQLERRM END;
END $f$;
CREATE FUNCTION pg_temp._st6_yaz(p_kod text, p_ok boolean, p_etiket text) RETURNS void LANGUAGE sql AS $f$
  UPDATE _stat_durum SET deger = CASE WHEN p_ok THEN 'PASS' ELSE 'FAIL' END, etiket = p_etiket WHERE kod = p_kod;
$f$;

SELECT pg_temp._st6_temizle();

-- cümleler (vaka verisi okunmaz) ve test kimlikleri
DROP TABLE IF EXISTS _st6_c;
CREATE TEMP TABLE _st6_c(ad text PRIMARY KEY, c jsonb);
INSERT INTO _st6_c VALUES
  ('c1', '{"v":1,"alan":"saglik","hastalik":{"tip":"tumu","deger":null},"ilac":{"duzey":"etken","x":null,"y":null},
           "kiyas_grubu":"tumu","olculer":["saglik_basari"],"kirilim":"yok","donem":{"tip":"son_ay","n":12},
           "kiyas_duzeyi":["biz"]}'),
  ('c2', '{"v":1,"alan":"saglik","hastalik":{"tip":"kategori","deger":"Meme"},"ilac":{"duzey":"sinif","x":null,"y":null},
           "kiyas_grubu":"tumu","olculer":["saglik_kapanma_gunu","saglik_vaka_tl"],"kirilim":"ay","donem":{"tip":"tumu"},
           "kiyas_duzeyi":["biz"]}');
DROP TABLE IF EXISTS _st6_id;
CREATE TEMP TABLE _st6_id(ad text PRIMARY KEY, id uuid, t timestamptz);

-- yabancı çiftlik satırı: RPC'ler görmemeli (listele/sil/sirala/güncelle)
DO $t$
BEGIN
  INSERT INTO public.stat_kayitli_grafik(farm_id, baslik, cumle, cumle_surum, sira)
  SELECT '00000000-0000-4000-8000-0000000e2e06', 'E2E-ST2-yabanci', c, 1, -5 FROM _st6_c WHERE ad = 'c1';
  INSERT INTO _st6_id SELECT 'yabanci', id, olusturma_at FROM public.stat_kayitli_grafik WHERE baslik = 'E2E-ST2-yabanci';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'yabanci satır yazılamadı: %', SQLERRM;
END $t$;

-- ── kaydet_ekle ─────────────────────────────────────────────────────────────
DO $t$
DECLARE
  v_c jsonb := (SELECT c FROM _st6_c WHERE ad = 'c1');
  v_m0 int; v_id1 uuid; v_id2 uuid; r1 record; v_s2 int;
BEGIN
  SELECT COALESCE(max(sira), 0) INTO v_m0 FROM public.stat_kayitli_grafik WHERE farm_id = public.current_farm_id();
  v_id1 := public.stat_grafik_kaydet(NULL, 'E2E-ST2-G1', v_c);
  v_id2 := public.stat_grafik_kaydet(NULL, 'E2E-ST2-G2', v_c);
  SELECT * INTO r1 FROM public.stat_kayitli_grafik WHERE id = v_id1;
  SELECT sira INTO v_s2 FROM public.stat_kayitli_grafik WHERE id = v_id2;
  INSERT INTO _st6_id VALUES ('G1', v_id1, r1.guncelleme_at), ('G2', v_id2, NULL);
  PERFORM pg_temp._st6_yaz('kaydet_ekle',
    r1.sira = v_m0 + 1 AND v_s2 = v_m0 + 2 AND r1.cumle_surum = 1 AND r1.cumle = v_c AND r1.baslik = 'E2E-ST2-G1'
      AND r1.farm_id = '400b9107-a85e-4126-af2c-fd7fe73fb68e' AND r1.olusturan IS NOT DISTINCT FROM auth.uid()
      AND r1.olusturma_at = r1.guncelleme_at AND v_id1 <> v_id2,
    format('max0=%s sira=%s/%s surum=%s farm=%s cumle_ayni=%s', v_m0, r1.sira, v_s2, r1.cumle_surum, r1.farm_id, r1.cumle = v_c));
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st6_yaz('kaydet_ekle', false, 'hata: ' || SQLERRM);
END $t$;

-- ── kaydet_guncelle (ayrı işlem: now() ilerler) ─────────────────────────────
DO $t$
DECLARE
  v_c2 jsonb := (SELECT c FROM _st6_c WHERE ad = 'c2');
  v_id uuid := (SELECT id FROM _st6_id WHERE ad = 'G1');
  v_t0 timestamptz := (SELECT t FROM _st6_id WHERE ad = 'G1');
  v_once record; v_r uuid; s record; v_n0 int; v_n1 int;
BEGIN
  SELECT * INTO v_once FROM public.stat_kayitli_grafik WHERE id = v_id;
  SELECT count(*) INTO v_n0 FROM public.stat_kayitli_grafik;
  v_r := public.stat_grafik_kaydet(v_id, 'E2E-ST2-G1b', v_c2);
  SELECT * INTO s FROM public.stat_kayitli_grafik WHERE id = v_id;
  SELECT count(*) INTO v_n1 FROM public.stat_kayitli_grafik;
  PERFORM pg_temp._st6_yaz('kaydet_guncelle',
    v_r = v_id AND s.baslik = 'E2E-ST2-G1b' AND s.cumle = v_c2 AND s.cumle_surum = 1 AND s.sira = v_once.sira
      AND s.olusturma_at = v_once.olusturma_at AND s.farm_id = v_once.farm_id AND s.guncelleme_at > v_t0 AND v_n1 = v_n0,
    format('donen=%s baslik=%s cumle=c2:%s sira %s→%s guncelleme ilerledi=%s satir %s→%s', v_r = v_id, s.baslik,
           s.cumle = v_c2, v_once.sira, s.sira, s.guncelleme_at > v_t0, v_n0, v_n1));
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st6_yaz('kaydet_guncelle', false, 'hata: ' || SQLERRM);
END $t$;

-- ── red yolları (hata metni birebir; denemeler geri alınır) ───────────────────
DROP TABLE IF EXISTS _st6_red;
CREATE TEMP TABLE _st6_red(kod text, sorgu text, bek text);
INSERT INTO _st6_red
SELECT k.kod, k.sorgu, k.bek FROM (SELECT
    (SELECT c FROM _st6_c WHERE ad = 'c1') AS c1,
    (SELECT id FROM _st6_id WHERE ad = 'G1') AS g1,
    (SELECT id FROM _st6_id WHERE ad = 'yabanci') AS yab) v,
  LATERAL (VALUES
  ('kaydet_guncelle_yok_red', format('SELECT public.stat_grafik_kaydet(%L, %L, %L)', 'e2e57206-0000-4000-8000-0000000000ff',
                              'E2E-ST2-yok', v.c1), 'P0001 STAT_GRAFIK:yok'),
  ('kaydet_guncelle_yok_red', format('SELECT public.stat_grafik_kaydet(%L, %L, %L)', v.yab, 'E2E-ST2-yok', v.c1),
                              'P0001 STAT_GRAFIK:yok'),
  ('kaydet_gecici_red', format('SELECT public.stat_grafik_kaydet(NULL, %L, %L)', 'E2E-ST2-gec',
                        v.c1 || '{"gecici":{"ilac_fiyat":{"E2E-ST2-SA":2}}}'), 'P0001 STAT_CUMLE:gecici:bilinmeyen_anahtar'),
  ('kaydet_gecici_red', format('SELECT public.stat_grafik_kaydet(%L, %L, %L)', v.g1, 'E2E-ST2-gec',
                        v.c1 || '{"gecici":{}}'), 'P0001 STAT_CUMLE:gecici:bilinmeyen_anahtar'),
  ('kaydet_gecersiz_cumle_red', format('SELECT public.stat_grafik_kaydet(NULL, %L, %L)', 'E2E-ST2-bz', v.c1 || '{"v":2}'),
                                'P0001 STAT_CUMLE:v:surum'),
  ('kaydet_gecersiz_cumle_red', format('SELECT public.stat_grafik_kaydet(NULL, %L, %L)', 'E2E-ST2-bz',
                                v.c1 || '{"olculer":[]}'), 'P0001 STAT_CUMLE:olculer:bos'),
  ('kaydet_gecersiz_cumle_red', format('SELECT public.stat_grafik_kaydet(NULL, %L, %L)', 'E2E-ST2-bz', v.c1 - 'donem'),
                                'P0001 STAT_CUMLE:donem:eksik'),
  ('kaydet_gecersiz_cumle_red', format('SELECT public.stat_grafik_kaydet(NULL, %L, NULL)', 'E2E-ST2-bz'),
                                'P0001 STAT_CUMLE:cumle:nesne_degil'),
  ('kaydet_gecersiz_cumle_red', format('SELECT public.stat_grafik_kaydet(%L, %L, %L)', v.g1, 'E2E-ST2-bz',
                                v.c1 || '{"kiyas_duzeyi":["biz","ulke"]}'), 'P0001 STAT_CUMLE:kiyas_duzeyi:yalniz_biz'),
  ('kaydet_bos_baslik_red', format('SELECT public.stat_grafik_kaydet(NULL, %L, %L)', '', v.c1), '23514 %'),
  ('kaydet_bos_baslik_red', format('SELECT public.stat_grafik_kaydet(NULL, %L, %L)', '   ', v.c1), '23514 %'),
  ('kaydet_bos_baslik_red', format('SELECT public.stat_grafik_kaydet(NULL, NULL, %L)', v.c1), '23502 %'),
  ('kaydet_bos_baslik_red', format('SELECT public.stat_grafik_kaydet(NULL, %L, %L)', 'E2E-ST2-' || repeat('x', 113), v.c1),
                            '23514 %'),
  ('kaydet_bos_baslik_red', format('SELECT public.stat_grafik_kaydet(%L, %L, %L)', v.g1, ' ', v.c1), '23514 %'),
  ('kaydet_bos_baslik_red', format('SELECT public.stat_grafik_kaydet(NULL, %L, %L)', 'E2E-ST2-' || repeat('x', 112), v.c1),
                            'HATA_YOK'),
  ('sil_yok_red', format('SELECT public.stat_grafik_sil(%L)', 'e2e57206-0000-4000-8000-0000000000ff'), 'P0001 STAT_GRAFIK:yok'),
  ('sil_yok_red', 'SELECT public.stat_grafik_sil(NULL)', 'P0001 STAT_GRAFIK:yok'),
  ('sil_yok_red', format('SELECT public.stat_grafik_sil(%L)', v.yab), 'P0001 STAT_GRAFIK:yok')
  ) AS k(kod, sorgu, bek);
-- sirala red'leri: tam küme (çiftlik, sira sırasıyla) üzerinden
INSERT INTO _st6_red
SELECT k.kod, format('SELECT public.stat_grafik_sirala(%L::uuid[])', k.dizi), 'P0001 STAT_GRAFIK:sira_kumesi'
  FROM (SELECT array_agg(id ORDER BY sira, olusturma_at, id) AS a FROM public.stat_kayitli_grafik
         WHERE farm_id = public.current_farm_id()) v,
       (SELECT id AS yab FROM _st6_id WHERE ad = 'yabanci') y,
  LATERAL (VALUES
    ('sirala_eksik_red', v.a[2:]),
    ('sirala_eksik_red', v.a || 'e2e57206-0000-4000-8000-0000000000ff'::uuid),
    ('sirala_eksik_red', v.a || y.yab),
    ('sirala_eksik_red', NULL::uuid[]),
    ('sirala_eksik_red', '{}'::uuid[]),
    ('sirala_eksik_red', v.a || NULL::uuid),
    ('sirala_tekrar_red', v.a || v.a[1]),
    ('sirala_tekrar_red', v.a[1:1] || v.a[1:cardinality(v.a) - 1]),
    ('sirala_cok_boyut_red', (SELECT array_agg(ARRAY[u]) FROM pg_catalog.unnest(v.a) AS t(u)))
  ) AS k(kod, dizi);

DROP TABLE IF EXISTS _st6_sira0;
CREATE TEMP TABLE _st6_sira0 AS SELECT id, sira, baslik, cumle FROM public.stat_kayitli_grafik;
SELECT count(*) AS n_once FROM public.stat_kayitli_grafik \gset
UPDATE _stat_durum d SET
  deger = CASE WHEN x.ok = x.n THEN 'PASS' ELSE 'FAIL' END,
  etiket = x.ok || '/' || x.n || ' ' || coalesce(x.fark, 'hepsi beklenen')
FROM (SELECT r.kod, count(*) AS n, count(*) FILTER (WHERE h.hata LIKE r.bek) AS ok,
             string_agg('bek=' || r.bek || ' gelen=' || h.hata, '; ') FILTER (WHERE NOT h.hata LIKE r.bek) AS fark
        FROM _st6_red r, LATERAL (SELECT pg_temp._st6_hata(r.sorgu) AS hata) h GROUP BY r.kod) x
WHERE d.kod = x.kod;
-- red denemelerinden sonra tablo birebir aynı (sira, başlık, cümle; yeni/eksik satır yok)
SELECT ((SELECT count(*) FROM public.stat_kayitli_grafik) = :n_once
        AND NOT EXISTS (SELECT 1 FROM _st6_sira0 o LEFT JOIN public.stat_kayitli_grafik g ON g.id = o.id
                         WHERE g.id IS NULL OR (g.sira, g.baslik, g.cumle) IS DISTINCT FROM (o.sira, o.baslik, o.cumle)))
       AS red_degismedi \gset
UPDATE _stat_durum SET deger = 'FAIL', etiket = etiket || ' · TABLO DEĞİŞTİ'
 WHERE kod IN (SELECT DISTINCT kod FROM _st6_red) AND NOT :'red_degismedi'::boolean;
UPDATE _stat_durum SET deger = 'FAIL', etiket = 'red listesi kurulamadı (tablo yok?)'
 WHERE kod IN ('kaydet_guncelle_yok_red', 'kaydet_gecici_red', 'kaydet_gecersiz_cumle_red', 'kaydet_bos_baslik_red',
               'sil_yok_red', 'sirala_eksik_red', 'sirala_tekrar_red', 'sirala_cok_boyut_red')
   AND kod NOT IN (SELECT kod FROM _st6_red);
-- gecici hiçbir satırın cümlesine sızmadı
UPDATE _stat_durum SET deger = 'FAIL', etiket = etiket || ' · gecici SIZDI'
 WHERE kod = 'kaydet_gecici_red' AND EXISTS (SELECT 1 FROM public.stat_kayitli_grafik WHERE cumle ? 'gecici');

-- ── listele_sira ────────────────────────────────────────────────────────────
DO $t$
DECLARE
  v_c jsonb := (SELECT c FROM _st6_c WHERE ad = 'c1');
  v_id3 uuid; v_l jsonb; v_bek jsonb; v_e2e text[]; v_anahtar boolean; v_yab boolean; v_bos jsonb;
BEGIN
  v_id3 := public.stat_grafik_kaydet(NULL, 'E2E-ST2-G3', v_c);
  INSERT INTO _st6_id VALUES ('G3', v_id3, NULL);
  -- eşit sira: G3 (sonra oluşturuldu) G1'in sirasına çekilir → G1 önce gelmeli
  UPDATE public.stat_kayitli_grafik SET sira = (SELECT sira FROM public.stat_kayitli_grafik WHERE id = (SELECT id FROM _st6_id WHERE ad = 'G1'))
   WHERE id = v_id3;
  v_l := public.stat_grafik_listele();
  SELECT COALESCE(jsonb_agg(jsonb_build_object('id', id, 'baslik', baslik, 'cumle', cumle, 'cumle_surum', cumle_surum,
                                               'sira', sira, 'guncelleme_at', guncelleme_at) ORDER BY sira, olusturma_at, id), '[]')
    INTO v_bek FROM public.stat_kayitli_grafik WHERE farm_id = '400b9107-a85e-4126-af2c-fd7fe73fb68e';
  SELECT array_agg(e->>'baslik' ORDER BY o) INTO v_e2e
    FROM pg_catalog.jsonb_array_elements(v_l) WITH ORDINALITY AS t(e, o) WHERE e->>'baslik' LIKE 'E2E-ST2-%';
  SELECT bool_and((SELECT array_agg(k ORDER BY k) FROM pg_catalog.jsonb_object_keys(e) AS u(k))
                  = ARRAY['baslik', 'cumle', 'cumle_surum', 'guncelleme_at', 'id', 'sira'])
    INTO v_anahtar FROM pg_catalog.jsonb_array_elements(v_l) AS t(e);
  v_yab := EXISTS (SELECT 1 FROM pg_catalog.jsonb_array_elements(v_l) AS t(e) WHERE e->>'baslik' = 'E2E-ST2-yabanci');
  BEGIN  -- boş çiftlik → [] (zorla geri alınır)
    DELETE FROM public.stat_kayitli_grafik WHERE farm_id = public.current_farm_id();
    v_bos := public.stat_grafik_listele();
    RAISE EXCEPTION USING ERRCODE = 'ZZ999';
  EXCEPTION WHEN SQLSTATE 'ZZ999' THEN NULL;
  END;
  PERFORM pg_temp._st6_yaz('listele_sira',
    v_l = v_bek AND v_e2e = ARRAY['E2E-ST2-G1b', 'E2E-ST2-G3', 'E2E-ST2-G2']
      AND v_anahtar AND NOT v_yab AND v_bos = '[]'::jsonb AND jsonb_typeof(v_l) = 'array',
    format('bağımsız sıra eşit=%s e2e=%s anahtarlar=%s yabanci_gorundu=%s bos=%s', v_l = v_bek, v_e2e, v_anahtar, v_yab, v_bos));
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st6_yaz('listele_sira', false, 'hata: ' || SQLERRM);
END $t$;

-- ── sil ─────────────────────────────────────────────────────────────────────
DO $t$
DECLARE v_id uuid; v_n0 int; v_n1 int; v_var boolean;
BEGIN
  v_id := public.stat_grafik_kaydet(NULL, 'E2E-ST2-G4', (SELECT c FROM _st6_c WHERE ad = 'c1'));
  SELECT count(*) INTO v_n0 FROM public.stat_kayitli_grafik;
  PERFORM public.stat_grafik_sil(v_id);
  SELECT count(*) INTO v_n1 FROM public.stat_kayitli_grafik;
  v_var := EXISTS (SELECT 1 FROM public.stat_kayitli_grafik WHERE id = v_id);
  PERFORM pg_temp._st6_yaz('sil', NOT v_var AND v_n1 = v_n0 - 1
      AND EXISTS (SELECT 1 FROM public.stat_kayitli_grafik WHERE id = (SELECT id FROM _st6_id WHERE ad = 'G1'))
      AND EXISTS (SELECT 1 FROM public.stat_kayitli_grafik WHERE id = (SELECT id FROM _st6_id WHERE ad = 'yabanci')),
    format('silinen yok=%s satır %s→%s', NOT v_var, v_n0, v_n1));
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st6_yaz('sil', false, 'hata: ' || SQLERRM);
END $t$;

-- ── sirala (zorla geri alınır: gerçek kayıtların sirası korunur) ──────────────
DO $t$
DECLARE v_a uuid[]; v_ters uuid[]; v_sonra uuid[]; v_siralar int[]; v_liste uuid[]; v_yab_sira int; v_n int;
BEGIN
  SELECT array_agg(id ORDER BY sira, olusturma_at, id) INTO v_a FROM public.stat_kayitli_grafik
   WHERE farm_id = public.current_farm_id();
  SELECT array_agg(v_a[i] ORDER BY i DESC) INTO v_ters FROM pg_catalog.generate_subscripts(v_a, 1) AS g(i);
  BEGIN
    PERFORM public.stat_grafik_sirala(v_ters);
    SELECT array_agg(id ORDER BY sira, olusturma_at, id), array_agg(sira ORDER BY sira) INTO v_sonra, v_siralar
      FROM public.stat_kayitli_grafik WHERE farm_id = public.current_farm_id();
    SELECT array_agg((e->>'id')::uuid ORDER BY o) INTO v_liste
      FROM pg_catalog.jsonb_array_elements(public.stat_grafik_listele()) WITH ORDINALITY AS t(e, o);
    SELECT sira INTO v_yab_sira FROM public.stat_kayitli_grafik WHERE id = (SELECT id FROM _st6_id WHERE ad = 'yabanci');
    RAISE EXCEPTION USING ERRCODE = 'ZZ999';
  EXCEPTION WHEN SQLSTATE 'ZZ999' THEN NULL;
  END;
  v_n := cardinality(v_a);
  PERFORM pg_temp._st6_yaz('sirala',
    v_n >= 3 AND v_sonra = v_ters AND v_liste = v_ters
      AND v_siralar = (SELECT array_agg(i ORDER BY i) FROM pg_catalog.generate_series(1, v_n) AS s(i)) AND v_yab_sira = -5,
    format('n=%s sira=ters:%s listele=ters:%s siralar=1..n:%s yabanci sira=%s', v_n, v_sonra = v_ters, v_liste = v_ters,
           v_siralar = (SELECT array_agg(i ORDER BY i) FROM pg_catalog.generate_series(1, v_n) AS s(i)), v_yab_sira));
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st6_yaz('sirala', false, 'hata: ' || SQLERRM);
END $t$;

-- ── acl_anon ────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS _st6_fn;
CREATE TEMP TABLE _st6_fn(imza text PRIMARY KEY);
INSERT INTO _st6_fn VALUES ('public.stat_grafik_listele()'), ('public.stat_grafik_kaydet(uuid,text,jsonb)'),
                           ('public.stat_grafik_sil(uuid)'), ('public.stat_grafik_sirala(uuid[])');
DO $t$
DECLARE f record; t record;
BEGIN
  SELECT count(*) FILTER (WHERE has_function_privilege('anon', imza, 'EXECUTE')) AS anon_fn,
         count(*) FILTER (WHERE has_function_privilege('authenticated', imza, 'EXECUTE')) AS au_fn,
         count(*) FILTER (WHERE EXISTS (SELECT 1 FROM pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                                         WHERE p.oid = imza::regprocedure AND a.grantee = 0)) AS pub_fn
    INTO f FROM _st6_fn;
  SELECT (SELECT count(*) FROM unnest(ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER']) p
           WHERE has_table_privilege('anon', 'public.stat_kayitli_grafik', p)) AS anon_t,
         (SELECT count(*) FROM unnest(ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE']) p
           WHERE has_table_privilege('authenticated', 'public.stat_kayitli_grafik', p)) AS au_t,
         (SELECT count(*) FROM unnest(ARRAY['TRUNCATE', 'REFERENCES', 'TRIGGER']) p
           WHERE has_table_privilege('authenticated', 'public.stat_kayitli_grafik', p)) AS au_fazla,
         (SELECT count(*) FROM pg_class c, aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) a
           WHERE c.oid = 'public.stat_kayitli_grafik'::regclass AND a.grantee = 0) AS pub_t
    INTO t;
  PERFORM pg_temp._st6_yaz('acl_anon',
    f.anon_fn = 0 AND f.pub_fn = 0 AND f.au_fn = 4 AND t.anon_t = 0 AND t.pub_t = 0 AND t.au_t = 4 AND t.au_fazla = 0,
    format('fn anon=%s public=%s authenticated=%s · tablo anon=%s public=%s authenticated=%s/4 fazla=%s',
           f.anon_fn, f.pub_fn, f.au_fn, t.anon_t, t.pub_t, t.au_t, t.au_fazla));
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st6_yaz('acl_anon', false, 'hata: ' || SQLERRM);
END $t$;

-- ── rls_acik: katalog + authenticated rolüyle uçtan uca (zorla geri alınır) ───
DO $t$
DECLARE
  v_rls boolean; v_pol int; v_uid uuid := 'e2e57206-0000-4000-8000-0000000000a1';
  v_c1 jsonb := (SELECT c FROM _st6_c WHERE ad = 'c1'); v_c2 jsonb := (SELECT c FROM _st6_c WHERE ad = 'c2');
  v_id uuid; v_l jsonb; v_olusturan uuid; v_farm uuid; v_baslik text; v_kalan boolean; v_rol text;
BEGIN
  SELECT relrowsecurity INTO v_rls FROM pg_class WHERE oid = 'public.stat_kayitli_grafik'::regclass;
  SELECT count(*) INTO v_pol FROM pg_policy
   WHERE polrelid = 'public.stat_kayitli_grafik'::regclass AND polcmd = '*' AND polpermissive
     AND pg_get_expr(polqual, polrelid) = 'true' AND pg_get_expr(polwithcheck, polrelid) = 'true';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_uid::text, true);
    SET LOCAL ROLE authenticated;
    v_rol := current_user;
    v_id := public.stat_grafik_kaydet(NULL, 'E2E-ST2-AU', v_c1);   -- temp tablo authenticated'a kapalı: cümleler önceden
    PERFORM public.stat_grafik_kaydet(v_id, 'E2E-ST2-AU2', v_c2);
    v_l := public.stat_grafik_listele();
    PERFORM public.stat_grafik_sirala((SELECT array_agg((e->>'id')::uuid ORDER BY o)
                                         FROM pg_catalog.jsonb_array_elements(v_l) WITH ORDINALITY AS t(e, o)));
    SELECT olusturan, farm_id, baslik INTO v_olusturan, v_farm, v_baslik FROM public.stat_kayitli_grafik WHERE id = v_id;
    PERFORM public.stat_grafik_sil(v_id);
    v_kalan := EXISTS (SELECT 1 FROM public.stat_kayitli_grafik WHERE id = v_id);
    RAISE EXCEPTION USING ERRCODE = 'ZZ999';
  EXCEPTION WHEN SQLSTATE 'ZZ999' THEN NULL;
  END;
  PERFORM pg_temp._st6_yaz('rls_acik',
    v_rls AND v_pol = 1 AND v_rol = 'authenticated' AND v_baslik = 'E2E-ST2-AU2' AND v_olusturan = v_uid
      AND v_farm = '400b9107-a85e-4126-af2c-fd7fe73fb68e' AND NOT v_kalan
      AND EXISTS (SELECT 1 FROM pg_catalog.jsonb_array_elements(v_l) AS t(e) WHERE e->>'id' = v_id::text)
      AND current_user <> 'authenticated',
    format('rls=%s policy=%s rol=%s başlık=%s olusturan=auth.uid():%s farm=%s silindi=%s', v_rls, v_pol, v_rol, v_baslik,
           v_olusturan = v_uid, v_farm, NOT v_kalan));
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st6_yaz('rls_acik', false, 'hata: ' || SQLERRM);
END $t$;

-- ── index_var, tablo_kolonlar, invoker ──────────────────────────────────────
DO $t$
DECLARE v_n int;
BEGIN
  SELECT count(*) INTO v_n FROM pg_index i
   WHERE i.indrelid = 'public.stat_kayitli_grafik'::regclass AND i.indnatts = 2
     AND (SELECT array_agg(a.attname ORDER BY k.o) FROM pg_catalog.unnest(i.indkey) WITH ORDINALITY AS k(n, o)
            JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = k.n) = ARRAY['farm_id', 'sira']::name[];
  PERFORM pg_temp._st6_yaz('index_var', v_n = 1, '(farm_id, sira) index sayısı=' || v_n);
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st6_yaz('index_var', false, 'hata: ' || SQLERRM);
END $t$;

DO $t$
DECLARE v_kol text; v_bek text; v_chk int; v_pk boolean;
BEGIN
  SELECT string_agg(column_name || ' ' || data_type || ' ' || is_nullable || ' ' || coalesce(column_default, '-'), ' | '
                    ORDER BY ordinal_position)
    INTO v_kol FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'stat_kayitli_grafik';
  v_bek := 'id uuid NO gen_random_uuid() | farm_id uuid NO ''400b9107-a85e-4126-af2c-fd7fe73fb68e''::uuid | '
        || 'baslik text NO - | cumle jsonb NO - | cumle_surum integer NO - | sira integer NO - | olusturan uuid YES auth.uid() | '
        || 'olusturma_at timestamp with time zone NO now() | guncelleme_at timestamp with time zone NO now()';
  SELECT count(*) INTO v_chk FROM pg_constraint
   WHERE conrelid = 'public.stat_kayitli_grafik'::regclass AND contype = 'c'
     AND pg_get_constraintdef(oid) ILIKE '%length(btrim(baslik))%1%120%';
  v_pk := EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'public.stat_kayitli_grafik'::regclass AND contype = 'p'
                     AND conkey = ARRAY[1]::int2[]);
  PERFORM pg_temp._st6_yaz('tablo_kolonlar', v_kol = v_bek AND v_chk = 1 AND v_pk,
    CASE WHEN v_kol = v_bek THEN 'kolonlar birebir' ELSE 'kolonlar: ' || coalesce(v_kol, '∅') END
      || ' · baslik CHECK=' || v_chk || ' · PK(id)=' || v_pk);
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st6_yaz('tablo_kolonlar', false, 'hata: ' || SQLERRM);
END $t$;

DO $t$
DECLARE v_ok int; v_stable boolean;
BEGIN
  SELECT count(*) INTO v_ok FROM _st6_fn f JOIN pg_proc p ON p.oid = f.imza::regprocedure
   WHERE NOT p.prosecdef AND 'search_path=public, pg_temp' = ANY (p.proconfig)
     AND p.provolatile = CASE WHEN p.proname = 'stat_grafik_listele' THEN 's' ELSE 'v' END;
  PERFORM pg_temp._st6_yaz('invoker', v_ok = 4, 'invoker+search_path+oynaklık uygun=' || v_ok || '/4');
EXCEPTION WHEN OTHERS THEN PERFORM pg_temp._st6_yaz('invoker', false, 'hata: ' || SQLERRM);
END $t$;

-- ── temizlik + artık ────────────────────────────────────────────────────────
SELECT pg_temp._st6_temizle();
UPDATE _stat_durum SET deger = CASE WHEN pg_temp._st6_artik() = 0 THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'artık=' || pg_temp._st6_artik()
WHERE kod = 'artik';
\endif

\echo '=== ÖZET ==='
SELECT kod, deger, etiket FROM _stat_durum ORDER BY kod;
SELECT 'TOPLAM: PASS=' || count(*) FILTER (WHERE deger = 'PASS') || ' FAIL=' || count(*) FILTER (WHERE deger = 'FAIL')
       || ' UNMEASURED=' || count(*) FILTER (WHERE deger = 'UNMEASURED') AS ozet FROM _stat_durum;
