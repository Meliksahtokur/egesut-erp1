-- tests/sql/stat_atolye_secenek_test.sql
-- İstatistik Atölyesi AP1 Task 5 — stat_atolye_kombinasyon (CREATE OR REPLACE), stat_atolye_secenekler,
-- stat_atolye_vakalar (spec v2 §4.4, §4.5, AK-2, AK-3; plan Task 5, Review Focus 4; T4 review öneri 4).
--
-- HEDEF: YALNIZ demo (ref vtzqjmazsvurxdeondmi). Fixture: stat_saglik_fixture.sql (E2E-ST2- önekli; T4 + T5 ekleri).
-- KOŞUM:
--   psql "$OVS_DEMO_DB_URL" -X -v ON_ERROR_STOP=0 -v stat_fixture_ok=true -f tests/sql/stat_atolye_secenek_test.sql
-- SONUÇ: _stat_durum(kod, PASS|FAIL|UNMEASURED, etiket); kod başına bir satır; başta ve sonda temizlik; `artik` = 0.
-- Seri regresyonu (T4 testleri) ayrı dosyada: stat_atolye_seri_test.sql.
--
-- ELLE TÜRETİLMİŞ BEKLENTİLER (fixture T5 eki tablosundan; ₺ geçici SA=2, SB=10; SC kayıtlı 5; SD fiyatsız).
-- K1 = E2E-ST2-Komb, etken, x=A, dönem tumu. X (A içeren) = k01..k11 (11; k11 açık).
--   y      a (x+y içeren)                         b (x içeren, y'siz)                         yetersiz
--   C      k01-05 n5  başarı 4/5 80.0  hız 5.0    k06-11 n6  başarı 5/5 100.0 hız 4.0         false
--          ₺ n5 30.00                            ₺ n2 45.00 (k07-09 ₺'siz, k11 açık)
--   B      k05,06 n2  başarı 2/2 100.0 hız 4.5    9 vaka  başarı 7/8 87.5 hız 4.5 ₺ n5 30.00  true
--          ₺ n2 75.00
--   D      k07,08 n2  başarı 2/2 100.0 hız 5.5    9 vaka  başarı 7/8 87.5 hız 4.5 ₺ n7 30.00  true
--          ₺ n0 null
--   sıra: C (a.n 5) · B · D (a.n 2 eşit → alfabetik); (bilinmiyor) (k08, k09) satır DEĞİL.
--   K1 + aralık [T-200, T-189] → X = k01..k06: C a.n 5, b.n 1 → yetersiz (bayrak b kolunu da okur).
-- Seçenekler (Komb, tumu): x_adaylari A 11 · C 7 · B 2 · D 2 · (bilinmiyor) 2 (en son; düz "n azalan + ad" onu B'nin
--   önüne koyardı: '(' < 'E'); y_adaylari (x=A) C 5 · B 2 · D 2 · (bilinmiyor) 2, A yok.
-- E1 = E2E-ST2-Enterit, etken, x=A, tumu: tek satır y=B; a = {normal, sk_karisik} n2 başarı 2/2 hız 4.5 ₺ 85.00;
--   b = A'lı diğer 17 vaka: başarı 11/14 78.6, hız n14 medyan = kâhin(G), ₺ n14 20.00 (uyusmaz ₺'siz).
-- E2 = E1 + kırılım ay, son 24 ay, [başarı]: iki seri (x, tumu), Σn 16 / 19, periyot başına n = kâhin.

\if :{?stat_fixture_ok}
\else
\set stat_fixture_ok false
\endif
\echo '=== stat_atolye_secenek testi ===' stat_fixture_ok= :stat_fixture_ok

DROP TABLE IF EXISTS _stat_durum;
CREATE TEMP TABLE _stat_durum(kod text PRIMARY KEY, deger text, etiket text);
INSERT INTO _stat_durum(kod, deger, etiket) VALUES
  ('komb_satir_C',           'UNMEASURED', 'K1 kombinasyon = elle tablo (3 satır, a/b üç ölçü)'),
  ('komb_satir_B',           'UNMEASURED', 'E1 x=A y=B: a.n 2, b.n 17, a.başarı 2/2, b 11/14, hız/₺ kâhin'),
  ('komb_sira',              'UNMEASURED', 'a.n azalan, eşitlikte y alfabetik: C, B, D'),
  ('komb_bilinmiyor_yok',    'UNMEASURED', '(bilinmiyor) y satırı yok (seçeneklerde var)'),
  ('komb_yetersiz_bayrak',   'UNMEASURED', 'a.n<5 ∨ b.n<5 → true; değerler yine dolu'),
  ('komb_yetersiz_b',        'UNMEASURED', 'aralık [T-200, T-189]: C a.n 5, b.n 1 → yetersiz (b kolu)'),
  ('komb_null_x_yok',        'UNMEASURED', 'x yok → kombinasyon null (doğrudan + seri)'),
  ('komb_seri_esit',         'UNMEASURED', 'seri.kombinasyon = stat_atolye_kombinasyon(c, gecici)'),
  ('komb_gecici',            'UNMEASURED', 'geçicisiz → A vakaları ₺ fiyatsız (tl n 0)'),
  ('komb_y_secili',          'UNMEASURED', 'y seçiliyken de panel x içindir (aynı satırlar)'),
  ('komb_red',               'UNMEASURED', 'doğrudan çağrıda bozuk cümle/gecici → STAT_CUMLE'),
  ('secenek_hastalik_sayisi','UNMEASURED', 'AK-2: hastalık sayısı = bağımsız count(DISTINCT disease_id); n azalan; Enterit var'),
  ('secenek_toplam_kategori','UNMEASURED', 'toplam_n = Σ hastalık n; kategori sayıları; dönem'),
  ('secenek_x_sira',         'UNMEASURED', 'x adayları n azalan, (bilinmiyor) en son'),
  ('secenek_y_x_haric',      'UNMEASURED', 'y adayları x vakalarında, x hariç; x yokken []'),
  ('secenek_red',            'UNMEASURED', 'bozuk cümle → STAT_CUMLE'),
  ('vakalar_grup_x',         'UNMEASURED', 'x grubu toplam = grup n (19); başarı kümesi = zarf n (16)'),
  ('vakalar_komb_a',         'UNMEASURED', 'komb:C:a = k01-05 (= panel a.n), komb:C:b = k06-11'),
  ('vakalar_alanlar',        'UNMEASURED', 'satır alanları + baslangic azalan'),
  ('vakalar_bilinmeyen_grup_red', 'UNMEASURED', 'bilinmeyen grup → STAT_CUMLE:grup:bilinmiyor'),
  ('vakalar_limit_200',      'UNMEASURED', 'toplam > 200 → 200 satır (tx içinde ek açık vaka, ROLLBACK)'),
  ('kirilim_ay_iki_grup',    'UNMEASURED', 'zaman kırılımı + x: iki seri, periyot n = kâhin, kiyas_n'),
  ('acl',                    'UNMEASURED', 'anon 0/4, PUBLIC 0/4, authenticated 4/4'),
  ('invoker',                'UNMEASURED', 'prosecdef=false, STABLE, search_path; authenticated = postgres'),
  ('artik',                  'UNMEASURED', 'E2E-ST2- artık = 0');
-- T5 perf c: kombinasyon iç gövdesi
INSERT INTO _stat_durum(kod, deger, etiket) VALUES
  ('komb_k_acl_invoker',     'UNMEASURED', 'kombinasyon_k: anon 0/1, PUBLIC 0/1, authenticated 1/1, INVOKER, STABLE, search_path; = kombinasyon');
-- TK1 (root ruling R1)
INSERT INTO _stat_durum(kod, deger, etiket) VALUES
  ('komb_tl_ilacsiz_disi',   'UNMEASURED', 'panel ₺ hücresi ilaçsız vakayı saymaz (sentetik kapsam); gerçek x vakalarında ilaçsız 0');
-- TS1 (sahip S1 (c), domain §19.7): E2E-ST2-Degisti, x=A, y=B; a = {td23_a}, b = A'lı diğer 8 vaka; SA=2 SB=10 (elle sabit)
--   a: başarı 0/1 y 0.0, hız n 0 medyan null (kg NULL), ₺ n 1 medyan 70.00; b: başarı 5/8 62.5, hız n 8 medyan 4.5, ₺ n 8 medyan 20.00
INSERT INTO _stat_durum(kod, deger, etiket) VALUES
  ('komb_payda_tedavi_degisti', 'UNMEASURED', 'tedavi değişti vakası panel başarı paydasında ve ₺''de, hızda yok');

\if :stat_fixture_ok
\ir stat_saglik_fixture.sql

SELECT g AS g FROM public.stat_saglik_vekil() \gset
\echo 'vekil G = ' :g
\set gec '{"ilac_fiyat":{"E2E-ST2-SA":2,"E2E-ST2-SB":10}}'

-- cümleler
DROP TABLE IF EXISTS _st5_c;
CREATE TEMP TABLE _st5_c(ad text PRIMARY KEY, c jsonb);
INSERT INTO _st5_c VALUES
  ('K0', '{"v":1,"alan":"saglik","hastalik":{"tip":"hastalik","deger":"e2e57201-0000-4000-8000-000000000004"},
           "ilac":{"duzey":"etken","x":null,"y":null},"kiyas_grubu":"tumu","olculer":["saglik_basari"],"kirilim":"yok",
           "donem":{"tip":"tumu"},"kiyas_duzeyi":["biz"]}');
INSERT INTO _st5_c SELECT 'K1', jsonb_set(c, '{ilac,x}', '"E2E-ETK-A"') FROM _st5_c WHERE ad = 'K0';
INSERT INTO _st5_c SELECT 'E1', jsonb_set(c, '{hastalik,deger}', '"e2e57201-0000-4000-8000-000000000001"') FROM _st5_c WHERE ad = 'K1';
INSERT INTO _st5_c SELECT 'E1y', jsonb_set(c, '{ilac,y}', '"E2E-ETK-B"') || '{"kiyas_grubu":"x_y_siz"}' FROM _st5_c WHERE ad = 'E1';
INSERT INTO _st5_c SELECT 'E2', c || '{"kirilim":"ay","donem":{"tip":"son_ay","n":24}}' FROM _st5_c WHERE ad = 'E1';
INSERT INTO _st5_c SELECT 'D12', jsonb_set(c, '{ilac,x}', 'null') || '{"donem":{"tip":"son_ay","n":12}}' FROM _st5_c WHERE ad = 'E1';
SELECT c AS k1 FROM _st5_c WHERE ad = 'K1' \gset

-- kombinasyon
SELECT public.stat_atolye_kombinasyon(:'k1'::jsonb, :'gec'::jsonb) AS komb_k1 \gset
\if :{?komb_k1}
\else
\set komb_k1 'null'
\endif
\echo 'K1 kombinasyon: ' :komb_k1
UPDATE _stat_durum SET
  deger = CASE WHEN :'komb_k1'::jsonb = '{"x":"E2E-ETK-A","duzey":"etken","satirlar":[
    {"y":"E2E-ETK-C","a":{"n":5,"basari":{"k":4,"n":5,"y":80.0},"hiz":{"n":5,"medyan":5.0},"tl":{"n":5,"medyan":30.00}},
                     "b":{"n":6,"basari":{"k":5,"n":5,"y":100.0},"hiz":{"n":5,"medyan":4.0},"tl":{"n":2,"medyan":45.00}},
     "yetersiz":false},
    {"y":"E2E-ETK-B","a":{"n":2,"basari":{"k":2,"n":2,"y":100.0},"hiz":{"n":2,"medyan":4.5},"tl":{"n":2,"medyan":75.00}},
                     "b":{"n":9,"basari":{"k":7,"n":8,"y":87.5},"hiz":{"n":8,"medyan":4.5},"tl":{"n":5,"medyan":30.00}},
     "yetersiz":true},
    {"y":"E2E-ETK-D","a":{"n":2,"basari":{"k":2,"n":2,"y":100.0},"hiz":{"n":2,"medyan":5.5},"tl":{"n":0,"medyan":null}},
                     "b":{"n":9,"basari":{"k":7,"n":8,"y":87.5},"hiz":{"n":8,"medyan":4.5},"tl":{"n":7,"medyan":30.00}},
     "yetersiz":true}]}'::jsonb THEN 'PASS' ELSE 'FAIL' END,
  etiket = left(:'komb_k1', 300)
WHERE kod = 'komb_satir_C';

-- E1: b hız medyanı G'ye bağlı → kâhin (T4 elle tablosundaki A'lı, B'siz, sonuçlanmış, kg dolu 14 vaka)
SELECT round(percentile_cont(0.5) WITHIN GROUP (ORDER BY d)::numeric, 1) AS e1_b_hiz
FROM (VALUES (4), (2), (3), (5), (5), (4), (10), (3), (LEAST(2 + :'g'::int, 20)), (LEAST(:'g'::int, 15)), (4), (3), (4), (5)) AS t(d)
\gset
UPDATE _stat_durum SET
  deger = CASE WHEN jsonb_array_length(k->'satirlar') = 1 AND k#>'{satirlar,0}' = jsonb_build_object(
                 'y', 'E2E-ETK-B',
                 'a', '{"n":2,"basari":{"k":2,"n":2,"y":100.0},"hiz":{"n":2,"medyan":4.5},"tl":{"n":2,"medyan":85.00}}'::jsonb,
                 'b', jsonb_build_object('n', 17, 'basari', '{"k":11,"n":14,"y":78.6}'::jsonb,
                                         'hiz', jsonb_build_object('n', 14, 'medyan', :'e1_b_hiz'::numeric),
                                         'tl', '{"n":14,"medyan":20.00}'::jsonb),
                 'yetersiz', true) THEN 'PASS' ELSE 'FAIL' END,
  etiket = coalesce((k->'satirlar')::text, '∅') || ' kâhin b.hiz=' || :'e1_b_hiz'
FROM (SELECT public.stat_atolye_kombinasyon(c, :'gec') AS k FROM _st5_c WHERE ad = 'E1') x
WHERE kod = 'komb_satir_B';

UPDATE _stat_durum SET
  deger = CASE WHEN x.ys = '["E2E-ETK-C", "E2E-ETK-B", "E2E-ETK-D"]' AND x.an = '[5, 2, 2]' THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'y=' || coalesce(x.ys::text, '∅') || ' a.n=' || coalesce(x.an::text, '∅')
FROM (SELECT jsonb_agg(s->'y' ORDER BY i) AS ys, jsonb_agg(s#>'{a,n}' ORDER BY i) AS an
        FROM jsonb_array_elements(:'komb_k1'::jsonb->'satirlar') WITH ORDINALITY AS t(s, i)) x
WHERE kod = 'komb_sira';
UPDATE _stat_durum SET
  deger = CASE WHEN NOT EXISTS (SELECT 1 FROM jsonb_array_elements(:'komb_k1'::jsonb->'satirlar') s WHERE s->>'y' = '(bilinmiyor)')
                AND EXISTS (SELECT 1 FROM jsonb_array_elements(public.stat_atolye_secenekler(:'k1')->'y_adaylari') s
                             WHERE s->>'deger' = '(bilinmiyor)') THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'panel y=' || (SELECT string_agg(s->>'y', ',') FROM jsonb_array_elements(:'komb_k1'::jsonb->'satirlar') s)
WHERE kod = 'komb_bilinmiyor_yok';
UPDATE _stat_durum SET
  deger = CASE WHEN x.yet = '[false, true, true]' AND x.dolu THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'yetersiz=' || coalesce(x.yet::text, '∅') || ' B a.başarı.y dolu=' || x.dolu
FROM (SELECT jsonb_agg(s->'yetersiz' ORDER BY i) AS yet,
             bool_and(s#>'{a,basari,y}' <> 'null' AND s#>'{a,hiz,medyan}' <> 'null') FILTER (WHERE s->>'y' = 'E2E-ETK-B') AS dolu
        FROM jsonb_array_elements(:'komb_k1'::jsonb->'satirlar') WITH ORDINALITY AS t(s, i)) x
WHERE kod = 'komb_yetersiz_bayrak';
-- b kolu: X = k01..k06 → C satırı a = k01-05 (5), b = k06 (1); yalnız a.n'e bakan bayrak burada false derdi
UPDATE _stat_durum SET
  deger = CASE WHEN k#>'{satirlar,0,y}' = '"E2E-ETK-C"' AND k#>'{satirlar,0,a,n}' = '5' AND k#>'{satirlar,0,b,n}' = '1'
                AND k#>'{satirlar,0,yetersiz}' = 'true' THEN 'PASS' ELSE 'FAIL' END,
  etiket = coalesce(left((k->'satirlar')::text, 200), '∅')
FROM (SELECT public.stat_atolye_kombinasyon(:'k1'::jsonb || jsonb_build_object('donem', jsonb_build_object('tip', 'aralik',
               'bas', :'t'::date - 200, 'bit', :'t'::date - 189)), :'gec') AS k) x
WHERE kod = 'komb_yetersiz_b';
UPDATE _stat_durum SET
  deger = CASE WHEN public.stat_atolye_kombinasyon(c, :'gec') IS NULL AND public.stat_atolye_seri(c, :'gec') ? 'kombinasyon'
                AND public.stat_atolye_seri(c, :'gec')->'kombinasyon' = 'null' THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'doğrudan=' || coalesce(public.stat_atolye_kombinasyon(c, :'gec')::text, 'NULL')
FROM _st5_c WHERE ad = 'K0' AND kod = 'komb_null_x_yok';
UPDATE _stat_durum SET
  deger = CASE WHEN public.stat_atolye_seri(:'k1', :'gec')->'kombinasyon' = :'komb_k1'::jsonb THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'seri.kombinasyon satır=' || coalesce(jsonb_array_length(public.stat_atolye_seri(:'k1', :'gec')#>'{kombinasyon,satirlar}')::text, '∅')
WHERE kod = 'komb_seri_esit';
UPDATE _stat_durum SET
  deger = CASE WHEN x.k#>'{satirlar,0,a,tl}' = '{"n":0,"medyan":null}' AND x.k#>'{satirlar,0,a,basari}' = '{"k":4,"n":5,"y":80.0}'
                AND x.d#>'{satirlar,0,a,tl}' = '{"n":0,"medyan":null}' THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'geçicisiz C.a.tl=' || coalesce((x.k#>'{satirlar,0,a,tl}')::text, '∅') || ' seri varsayılan=' || coalesce((x.d#>'{satirlar,0,a,tl}')::text, '∅')
FROM (SELECT public.stat_atolye_kombinasyon(:'k1', '{}') AS k, public.stat_atolye_seri(:'k1')->'kombinasyon' AS d) x
WHERE kod = 'komb_gecici';
UPDATE _stat_durum SET
  deger = CASE WHEN public.stat_atolye_kombinasyon(y.c, :'gec') = public.stat_atolye_kombinasyon(e.c, :'gec') THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'y seçili satırlar=' || coalesce(jsonb_array_length(public.stat_atolye_kombinasyon(y.c, :'gec')->'satirlar')::text, '∅')
FROM _st5_c y, _st5_c e WHERE y.ad = 'E1y' AND e.ad = 'E1' AND kod = 'komb_y_secili';

-- TK1 R1: panel ₺ hücresi ilaçsız vakayı (maliyet_kalemleri []) saymaz. Gerçek veride x vakası hep ilaçlıdır (ilaç ve
--   kalem aynı uygulama satırlarından) → kural sentetik kapsamla sınanır: u1 ilaçsız, u2 SC 2 ml (kayıtlı 5 → 10 ₺);
--   ikisi de x (E2E-ETK-A) + y (E2E-ETK-Q). Beklenen a.tl {n 1, medyan 10.00}; ilaçsızı sayan eski hesap {n 2, medyan 5.00}.
UPDATE _stat_durum SET
  deger = CASE WHEN k#>'{satirlar,0,a,tl}' = '{"n":1,"medyan":10.00}' AND k#>'{satirlar,0,a,n}' = '2'
                AND k#>'{satirlar,0,a,basari}' = '{"k":2,"n":2,"y":100.0}' AND x.gercek_ilacsiz = 0 THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'sentetik a=' || coalesce((k#>'{satirlar,0,a}')::text, '∅') || ' · gerçek K1/E1 x vakalarında ilaçsız=' || x.gercek_ilacsiz
FROM (SELECT public.stat_atolye_kombinasyon_k(:'k1'::jsonb, '{}'::jsonb, jsonb_build_object(
               'vakalar', '[{"vaka_id":"e2e57209-0000-4000-8000-000000000001","durum":"sonuclandi","sonuc":"basarili",
                             "kapanma_gunu":3,"maliyet_kalemleri":[]},
                            {"vaka_id":"e2e57209-0000-4000-8000-000000000002","durum":"sonuclandi","sonuc":"basarili",
                             "kapanma_gunu":4,"maliyet_kalemleri":[{"stok_id":"E2E-ST2-SC","birim":"ml","miktar":2,"neden":null}]}]'::jsonb,
               'ilac', '[{"vaka_id":"e2e57209-0000-4000-8000-000000000001","deger":"E2E-ETK-A"},
                         {"vaka_id":"e2e57209-0000-4000-8000-000000000001","deger":"E2E-ETK-Q"},
                         {"vaka_id":"e2e57209-0000-4000-8000-000000000002","deger":"E2E-ETK-A"},
                         {"vaka_id":"e2e57209-0000-4000-8000-000000000002","deger":"E2E-ETK-Q"}]'::jsonb)) AS k) s,
     (SELECT count(*) FILTER (WHERE v.maliyet_kalemleri = '[]'::jsonb) AS gercek_ilacsiz
        FROM _st5_c c, LATERAL (SELECT public.stat_cumle_kapsam(c.c) AS p) q,
             jsonb_to_recordset(q.p->'vakalar') AS v(vaka_id uuid, maliyet_kalemleri jsonb)
       WHERE c.ad IN ('K1', 'E1')
         AND v.vaka_id IN (SELECT i.vaka_id FROM jsonb_to_recordset(q.p->'ilac') AS i(vaka_id uuid, deger text)
                            WHERE i.deger = 'E2E-ETK-A')) x
WHERE kod = 'komb_tl_ilacsiz_disi';

-- doğrulama yolları (hata metni birebir)
CREATE FUNCTION pg_temp._st5_hata(p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE p_sql;
  RETURN 'HATA_YOK';
EXCEPTION WHEN OTHERS THEN RETURN SQLERRM;
END $f$;
DROP TABLE IF EXISTS _st5_red;
CREATE TEMP TABLE _st5_red(kod text, sorgu text, bek text);
INSERT INTO _st5_red VALUES
  ('komb_red', format('SELECT public.stat_atolye_kombinasyon(%L::jsonb, %L)', :'k1'::jsonb || '{"v":2}', :'gec'), 'STAT_CUMLE:v:surum'),
  ('komb_red', format('SELECT public.stat_atolye_kombinasyon(%L::jsonb, %L)', :'k1', '{"ilac_fiyat":{"E2E-ST2-SA":-1}}'),
               'STAT_CUMLE:gecici.ilac_fiyat:pozitif_sayi_degil'),
  ('komb_red', format('SELECT public.stat_atolye_kombinasyon(%L::jsonb, %L)', :'k1', '{"fiyat":{}}'),
               'STAT_CUMLE:gecici.fiyat:bilinmeyen_anahtar'),
  ('secenek_red', format('SELECT public.stat_atolye_secenekler(%L::jsonb)', :'k1'::jsonb || '{"alan":"ekonomi"}'), 'STAT_CUMLE:alan:gecersiz'),
  ('secenek_red', format('SELECT public.stat_atolye_secenekler(%L::jsonb)', :'k1'::jsonb - 'olculer'), 'STAT_CUMLE:olculer:eksik'),
  ('vakalar_bilinmeyen_grup_red', format('SELECT public.stat_atolye_vakalar(%L::jsonb, %L)', :'k1', 'yok'), 'STAT_CUMLE:grup:bilinmiyor'),
  ('vakalar_bilinmeyen_grup_red', format('SELECT public.stat_atolye_vakalar(%L::jsonb, NULL)', :'k1'), 'STAT_CUMLE:grup:bilinmiyor'),
  ('vakalar_bilinmeyen_grup_red', format('SELECT public.stat_atolye_vakalar(%L::jsonb, %L)', :'k1', 'xy'), 'STAT_CUMLE:grup:bilinmiyor'),
  ('vakalar_bilinmeyen_grup_red', format('SELECT public.stat_atolye_vakalar(%L::jsonb, %L)', :'k1', 'komb:E2E-ETK-Z:a'),
                                  'STAT_CUMLE:grup:bilinmiyor'),
  ('vakalar_bilinmeyen_grup_red', format('SELECT public.stat_atolye_vakalar(%L::jsonb, %L)', :'k1', 'komb:(bilinmiyor):a'),
                                  'STAT_CUMLE:grup:bilinmiyor'),
  ('vakalar_bilinmeyen_grup_red', format('SELECT public.stat_atolye_vakalar(%L::jsonb, %L)', :'k1', 'komb:E2E-ETK-A:a'),
                                  'STAT_CUMLE:grup:bilinmiyor'),
  ('vakalar_bilinmeyen_grup_red', format('SELECT public.stat_atolye_vakalar(%L::jsonb, %L)', :'k1', 'komb:E2E-ETK-C:c'),
                                  'STAT_CUMLE:grup:bilinmiyor'),
  ('vakalar_bilinmeyen_grup_red', format('SELECT public.stat_atolye_vakalar(%L::jsonb, %L)',
                                         (SELECT c FROM _st5_c WHERE ad = 'K0'), 'komb:E2E-ETK-C:a'), 'STAT_CUMLE:grup:bilinmiyor'),
  ('vakalar_bilinmeyen_grup_red', format('SELECT public.stat_atolye_vakalar(%L::jsonb, %L)',
                                         (SELECT c FROM _st5_c WHERE ad = 'K0'), 'x'), 'STAT_CUMLE:grup:bilinmiyor'),
  ('vakalar_bilinmeyen_grup_red', format('SELECT public.stat_atolye_vakalar(%L::jsonb, %L)', :'k1'::jsonb || '{"v":2}', 'x'),
                                  'STAT_CUMLE:v:surum');
UPDATE _stat_durum d SET
  deger = CASE WHEN x.ok = x.n THEN 'PASS' ELSE 'FAIL' END,
  etiket = x.ok || '/' || x.n || ' ' || coalesce(x.fark, 'hepsi beklenen')
FROM (SELECT r.kod, count(*) AS n, count(*) FILTER (WHERE h.hata = r.bek) AS ok,
             string_agg('bek=' || r.bek || ' gelen=' || h.hata, '; ') FILTER (WHERE h.hata <> r.bek) AS fark
        FROM _st5_red r, LATERAL (SELECT pg_temp._st5_hata(r.sorgu) AS hata) h GROUP BY r.kod) x
WHERE d.kod = x.kod;

-- seçenekler
SELECT public.stat_atolye_secenekler(c) AS s_d12 FROM _st5_c WHERE ad = 'D12' \gset
SELECT (public.stat_cumle_donem(c)).bas AS d12_bas, (public.stat_cumle_donem(c)).bit AS d12_bit FROM _st5_c WHERE ad = 'D12' \gset
-- AK-2 kâhini: cases tabanından (view'sız), dönemde kapsam içi (Ovsync dışı) vakası olan hastalıklar
DROP TABLE IF EXISTS _st5_hk;
CREATE TEMP TABLE _st5_hk AS
SELECT c.disease_id, count(*) AS n
FROM cases c JOIN diseases d ON d.id = c.disease_id
WHERE c.start_date BETWEEN :'d12_bas'::date AND :'d12_bit'::date AND NOT public.stat_vaka_ovsync_mu(c.id)
GROUP BY c.disease_id;
UPDATE _stat_durum SET
  deger = CASE WHEN jsonb_array_length(s->'hastaliklar') = (SELECT count(DISTINCT disease_id) FROM _st5_hk)
                AND (SELECT bool_and(h->>'n' = k.n::text) FROM jsonb_array_elements(s->'hastaliklar') h
                       JOIN _st5_hk k ON k.disease_id = (h->>'id')::uuid)
                AND EXISTS (SELECT 1 FROM jsonb_array_elements(s->'hastaliklar') h
                             WHERE h->>'ad' = 'E2E-ST2-Enterit' AND h->>'kategori' = 'E2E-ST2-Kat' AND h->>'n' = '22')
                AND (SELECT bool_and(o.n <= coalesce(o.onceki, o.n)) FROM (
                       SELECT (h->>'n')::int AS n, lag((h->>'n')::int) OVER (ORDER BY i) AS onceki
                       FROM jsonb_array_elements(s->'hastaliklar') WITH ORDINALITY AS t(h, i)) o)
               THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'seçici=' || jsonb_array_length(s->'hastaliklar') || ' kâhin=' || (SELECT count(DISTINCT disease_id) FROM _st5_hk)
           || ' dönem=' || :'d12_bas' || '..' || :'d12_bit'
FROM (SELECT :'s_d12'::jsonb AS s) x
WHERE kod = 'secenek_hastalik_sayisi';
UPDATE _stat_durum SET
  deger = CASE WHEN (s->>'toplam_n')::int = (SELECT sum(n) FROM _st5_hk)
                AND (s->>'toplam_n')::int = (SELECT sum((h->>'n')::int) FROM jsonb_array_elements(s->'hastaliklar') h)
                AND s->'donem' = jsonb_build_object('bas', :'d12_bas'::date, 'bit', :'d12_bit'::date)
                AND (SELECT sum((k->>'n')::int) FROM jsonb_array_elements(s->'kategoriler') k) = (s->>'toplam_n')::int
                AND s->'kategoriler' @> '[{"ad":"E2E-ST2-Kat","n":22},{"ad":"E2E-ST2-Kat2","n":13}]'
               THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'toplam_n=' || coalesce(s->>'toplam_n', '∅') || ' kâhin=' || (SELECT sum(n) FROM _st5_hk)
           || ' donem=' || coalesce((s->'donem')::text, '∅')
FROM (SELECT :'s_d12'::jsonb AS s) x
WHERE kod = 'secenek_toplam_kategori';
UPDATE _stat_durum SET
  deger = CASE WHEN s->'x_adaylari' = '[{"deger":"E2E-ETK-A","n":11},{"deger":"E2E-ETK-C","n":7},{"deger":"E2E-ETK-B","n":2},
                                       {"deger":"E2E-ETK-D","n":2},{"deger":"(bilinmiyor)","n":2}]'
                AND s->'y_adaylari' = '[]' AND s#>'{hastaliklar}' @> '[{"ad":"E2E-ST2-Komb","kategori":"E2E-ST2-Kat2","n":13}]'
                AND s->'kategoriler' @> '[{"ad":"E2E-ST2-Kat2","n":13}]' THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'x=' || coalesce((s->'x_adaylari')::text, '∅') || ' y=' || coalesce((s->'y_adaylari')::text, '∅')
FROM (SELECT public.stat_atolye_secenekler(c) AS s FROM _st5_c WHERE ad = 'K0') x
WHERE kod = 'secenek_x_sira';
UPDATE _stat_durum SET
  deger = CASE WHEN s->'y_adaylari' = '[{"deger":"E2E-ETK-C","n":5},{"deger":"E2E-ETK-B","n":2},{"deger":"E2E-ETK-D","n":2},
                                       {"deger":"(bilinmiyor)","n":2}]'
                AND s->'x_adaylari' = (SELECT public.stat_atolye_secenekler(c)->'x_adaylari' FROM _st5_c WHERE ad = 'K0')
                AND (SELECT jsonb_agg(jsonb_build_object('deger', r->>'y', 'n', r#>'{a,n}') ORDER BY i)
                       FROM jsonb_array_elements(:'komb_k1'::jsonb->'satirlar') WITH ORDINALITY AS t(r, i))
                    = (s->'y_adaylari') - 3 THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'y=' || coalesce((s->'y_adaylari')::text, '∅')
FROM (SELECT public.stat_atolye_secenekler(:'k1') AS s) x
WHERE kod = 'secenek_y_x_haric';

-- vaka listesi
CREATE FUNCTION pg_temp._st5_ids(p jsonb) RETURNS text LANGUAGE sql AS $f$
  SELECT coalesce(string_agg(s.kod, ',' ORDER BY s.kod), '∅')
  FROM jsonb_array_elements(p->'vakalar') v JOIN _st2_vaka s ON s.vaka_id = (v->>'vaka_id')::uuid;
$f$;
UPDATE _stat_durum SET
  deger = CASE WHEN (vx->>'toplam')::int = 19 AND jsonb_array_length(vx->'vakalar') = 19
                AND (vx->>'toplam')::int = (SELECT count(g.vaka_id) FROM public.stat_atolye_gruplar(e.c) g WHERE g.anahtar = 'x')
                AND (SELECT count(*) FROM jsonb_array_elements(vx->'vakalar') v
                      WHERE v->>'sonuc' IN ('basarili', 'basarisiz_olum_kesim', 'basarisiz_nuks'))
                    = (SELECT (z->>'n')::int FROM jsonb_array_elements(public.stat_atolye_seri(e.c)->'zarflar') z)
                AND (vt->>'toplam')::int = 22 THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'x toplam=' || coalesce(vx->>'toplam', '∅') || ' tumu toplam=' || coalesce(vt->>'toplam', '∅') || ' zarf n='
           || (SELECT z->>'n' FROM jsonb_array_elements(public.stat_atolye_seri(e.c)->'zarflar') z)
FROM _st5_c e, LATERAL (SELECT public.stat_atolye_vakalar(e.c, 'x') AS vx, public.stat_atolye_vakalar(e.c, 'tumu') AS vt) v
WHERE e.ad = 'E1' AND kod = 'vakalar_grup_x';
UPDATE _stat_durum SET
  deger = CASE WHEN (a->>'toplam')::int = 5 AND pg_temp._st5_ids(a) = 'k01,k02,k03,k04,k05'
                AND (a->>'toplam')::int = (:'komb_k1'::jsonb#>>'{satirlar,0,a,n}')::int
                AND (b->>'toplam')::int = 6 AND pg_temp._st5_ids(b) = 'k06,k07,k08,k09,k10,k11'
                AND (b->>'toplam')::int = (:'komb_k1'::jsonb#>>'{satirlar,0,b,n}')::int
                AND pg_temp._st5_ids(ad) = 'k07,k08' THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'a=' || pg_temp._st5_ids(a) || ' b=' || pg_temp._st5_ids(b) || ' D.a=' || pg_temp._st5_ids(ad)
FROM (SELECT public.stat_atolye_vakalar(:'k1', 'komb:E2E-ETK-C:a') AS a, public.stat_atolye_vakalar(:'k1', 'komb:E2E-ETK-C:b') AS b,
             public.stat_atolye_vakalar(:'k1', 'komb:E2E-ETK-D:a') AS ad) x
WHERE kod = 'vakalar_komb_a';
UPDATE _stat_durum SET
  deger = CASE WHEN (SELECT bool_and(v.o ?& ARRAY['vaka_id', 'kupe_no', 'hastalik', 'baslangic', 'kapanis', 'durum', 'sonuc',
                                                 'kapanma_gunu', 'kapanma_vekil'] AND (SELECT count(*) FROM jsonb_object_keys(v.o)) = 9)
                       FROM jsonb_array_elements(r->'vakalar') AS v(o))
                AND r#>'{vakalar,0}' = jsonb_build_object('vaka_id', 'e2e57207-0000-4000-8000-000000000040', 'kupe_no', 'K-E2E-ST2-40',
                      'hastalik', 'E2E-ST2-Komb', 'baslangic', :'t'::date - 180, 'kapanis', NULL, 'durum', 'acik', 'sonuc', NULL,
                      'kapanma_gunu', NULL, 'kapanma_vekil', false)
                AND r#>'{vakalar,-1}' = jsonb_build_object('vaka_id', 'e2e57207-0000-4000-8000-000000000030', 'kupe_no', 'K-E2E-ST2-30',
                      'hastalik', 'E2E-ST2-Komb', 'baslangic', :'t'::date - 200, 'kapanis', :'t'::date - 195, 'durum', 'sonuclandi',
                      'sonuc', 'basarili', 'kapanma_gunu', 5, 'kapanma_vekil', false)
                AND (SELECT bool_and(o.b <= coalesce(o.onceki, o.b)) FROM (
                       SELECT (v->>'baslangic')::date AS b, lag((v->>'baslangic')::date) OVER (ORDER BY i) AS onceki
                       FROM jsonb_array_elements(r->'vakalar') WITH ORDINALITY AS t(v, i)) o) THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'ilk=' || coalesce((r#>'{vakalar,0}')::text, '∅')
FROM (SELECT public.stat_atolye_vakalar(:'k1', 'x') AS r) x
WHERE kod = 'vakalar_alanlar';

-- limit: tumu+tumu kapsamını tx içinde 200'ün üstüne çıkar (E2E-ST2- önekli açık vakalar), ölç, ROLLBACK
BEGIN;
INSERT INTO hayvanlar(id, kupe_no, cinsiyet, dogum_tarihi, grup)
SELECT 'E2E-ST2-L' || lpad(i::text, 3, '0'), 'K-E2E-ST2-L' || lpad(i::text, 3, '0'), 'Dişi', :'t'::date - 1500, 'Sağmal (Laktasyonda)'
FROM generate_series(1, 120) i;
INSERT INTO cases(animal_id, disease_id, start_date, status)
SELECT 'E2E-ST2-L' || lpad(i::text, 3, '0'), 'e2e57201-0000-4000-8000-000000000002', :'t'::date - (i % 50), 'active'
FROM generate_series(1, 120) i;
SELECT x.r->>'toplam' AS lim_toplam, jsonb_array_length(x.r->'vakalar') AS lim_satir,
       (SELECT bool_and(o.b <= coalesce(o.onceki, o.b)) FROM (
          SELECT (v->>'baslangic')::date AS b, lag((v->>'baslangic')::date) OVER (ORDER BY i) AS onceki
          FROM jsonb_array_elements(x.r->'vakalar') WITH ORDINALITY AS t(v, i)) o) AS lim_sira,
       (SELECT count(*) FROM v_stat_saglik_vaka) AS lim_view_n
FROM (SELECT public.stat_atolye_vakalar(c || '{"hastalik":{"tip":"tumu","deger":null}}', 'tumu') AS r FROM _st5_c WHERE ad = 'K0') x
\gset
ROLLBACK;
\if :{?lim_toplam}
\else
\set lim_toplam -1
\set lim_satir -1
\set lim_sira false
\set lim_view_n -1
\endif
UPDATE _stat_durum SET
  deger = CASE WHEN :'lim_toplam'::int > 200 AND :'lim_toplam'::int = :'lim_view_n'::int AND :'lim_satir'::int = 200
                AND :'lim_sira'::boolean THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'toplam=' || :'lim_toplam' || ' (view ' || :'lim_view_n' || ') satır=' || :'lim_satir' || ' sıra=' || :'lim_sira'
WHERE kod = 'vakalar_limit_200';

-- zaman kırılımı + 2 grup (x seçili): periyot başına n kâhini = başarı kümesindeki A'lı / tüm Enterit vakaları (T4 tablosu)
DROP TABLE IF EXISTS _st5_e;
CREATE TEMP TABLE _st5_e(kod text PRIMARY KEY, a boolean, basari boolean);
INSERT INTO _st5_e VALUES
  ('normal', true, true), ('olum_30', true, true), ('kesim_31', true, true), ('satis', true, true), ('nuks_30', true, true),
  ('nuks_30_b', false, true), ('nuks_31', true, true), ('nuks_31_b', true, true), ('olgun_degil', true, false),
  ('olgun_sinir', true, true), ('aktif_olum', true, true), ('aktif_acik', true, false), ('toplu_1', true, true),
  ('toplu_2', true, true), ('toplu_bos', false, true), ('fallback', false, true), ('uyusmaz', true, true),
  ('stoksuz_tekil', true, true), ('log_iptal_tedavi', true, true), ('kapali_tarihsiz', true, false),
  ('plan_eksik', true, true), ('sk_karisik', true, true);
UPDATE _stat_durum SET
  deger = CASE WHEN jsonb_array_length(z->'seriler') = 2 AND z#>'{seriler,0,anahtar}' = '"x"' AND z#>'{seriler,1,anahtar}' = '"tumu"'
                AND z#>'{seriler,0,ad}' = '"E2E-ETK-A içeren"' AND z#>'{seriler,1,ad}' = '"Tüm E2E-ST2-Enterit vakaları"'
                AND jsonb_array_length(z#>'{x,deger}') = 25 AND z#>'{x,ad}' = '"ay"'
                AND z#>'{seriler,0,n}' = k.n_x AND z#>'{seriler,1,n}' = k.n_t AND z->'n' = '16' AND z#>'{sayac,kiyas_n}' = '19'
                AND z->'dipnot' ? 'Gruplar örtüşür: bir vaka birden çok satırda sayılır.'
               THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'seriler=' || coalesce(jsonb_array_length(z->'seriler')::text, '∅') || ' x.n=' || coalesce((z#>'{seriler,0,n}')::text, '∅')
           || ' kâhin=' || k.n_x::text || ' tumu.n=' || coalesce((z#>'{seriler,1,n}')::text, '∅')
FROM (SELECT z FROM _st5_c, jsonb_array_elements(public.stat_atolye_seri(c, :'gec')->'zarflar') z WHERE ad = 'E2') s,
     (SELECT jsonb_agg(coalesce(q.nx, 0) ORDER BY p.p) AS n_x, jsonb_agg(coalesce(q.nt, 0) ORDER BY p.p) AS n_t
        FROM generate_series(date_trunc('month', :'t'::date - interval '24 months'), date_trunc('month', :'t'::date::timestamp),
                             interval '1 month') p
        LEFT JOIN (SELECT date_trunc('month', (:'t'::date - v.bas)::timestamp) AS m,
                          count(*) FILTER (WHERE e.a) AS nx, count(*) AS nt
                     FROM _st5_e e JOIN _st2_vaka v ON v.kod = e.kod WHERE e.basari GROUP BY 1) q ON q.m = p.p) k
WHERE kod = 'kirilim_ay_iki_grup';

-- ACL + INVOKER (T5 nesneleri)
DROP TABLE IF EXISTS _st5_fn;
CREATE TEMP TABLE _st5_fn(imza text PRIMARY KEY);
INSERT INTO _st5_fn VALUES ('public.stat_atolye_kombinasyon(jsonb,jsonb)'), ('public.stat_atolye_secenekler(jsonb)'),
                           ('public.stat_atolye_vakalar(jsonb,text)');
INSERT INTO _st5_fn SELECT 'public.stat_atolye_seri(jsonb,jsonb)';
UPDATE _stat_durum SET
  deger = CASE WHEN x.anon_fn = 0 AND x.au_fn = 4 AND x.pub_fn = 0 THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'anon=' || x.anon_fn || ' public=' || x.pub_fn || ' authenticated=' || x.au_fn
FROM (SELECT count(*) FILTER (WHERE has_function_privilege('anon', imza, 'EXECUTE')) AS anon_fn,
             count(*) FILTER (WHERE has_function_privilege('authenticated', imza, 'EXECUTE')) AS au_fn,
             count(*) FILTER (WHERE EXISTS (SELECT 1 FROM pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                                              WHERE p.oid = imza::regprocedure AND a.grantee = 0)) AS pub_fn
        FROM _st5_fn) x
WHERE kod = 'acl';
BEGIN;
SELECT (public.stat_atolye_kombinasyon(:'k1', :'gec')::text || public.stat_atolye_secenekler(:'k1')::text
        || public.stat_atolye_vakalar(:'k1', 'komb:E2E-ETK-C:a')::text) AS pg_r \gset
SET LOCAL ROLE authenticated;
SELECT (public.stat_atolye_kombinasyon(:'k1', :'gec')::text || public.stat_atolye_secenekler(:'k1')::text
        || public.stat_atolye_vakalar(:'k1', 'komb:E2E-ETK-C:a')::text) AS au_r \gset
ROLLBACK;
\if :{?au_r}
\else
\set au_r hata
\endif
UPDATE _stat_durum SET
  deger = CASE WHEN x.fn_ok = 4 AND :'pg_r' = :'au_r' AND length(:'pg_r') > 100 THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'fn uygun=' || x.fn_ok || '/4 authenticated=postgres: ' || (:'pg_r' = :'au_r')::text
FROM (SELECT count(*) AS fn_ok FROM _st5_fn f JOIN pg_proc p ON p.oid = f.imza::regprocedure
       WHERE NOT p.prosecdef AND p.provolatile = 's' AND 'search_path=public, pg_temp' = ANY (p.proconfig)) x
WHERE kod = 'invoker';
UPDATE _stat_durum SET
  deger = CASE WHEN x.anon_fn = 0 AND x.pub_fn = 0 AND x.au_fn = 1 AND x.fn_ok = 1 AND x.esit THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'anon=' || x.anon_fn || ' public=' || x.pub_fn || ' authenticated=' || x.au_fn || ' invoker/stable/search_path=' || x.fn_ok
           || ' kombinasyon_k = kombinasyon: ' || x.esit::text
FROM (SELECT count(*) FILTER (WHERE has_function_privilege('anon', f.oid, 'EXECUTE')) AS anon_fn,
             count(*) FILTER (WHERE has_function_privilege('authenticated', f.oid, 'EXECUTE')) AS au_fn,
             count(*) FILTER (WHERE EXISTS (SELECT 1 FROM aclexplode(coalesce(f.proacl, acldefault('f', f.proowner))) a
                                             WHERE a.grantee = 0)) AS pub_fn,
             count(*) FILTER (WHERE NOT f.prosecdef AND f.provolatile = 's' AND 'search_path=public, pg_temp' = ANY (f.proconfig)) AS fn_ok,
             COALESCE(bool_and(public.stat_atolye_kombinasyon_k(:'k1', :'gec'::jsonb->'ilac_fiyat', public.stat_cumle_kapsam(:'k1'))
                               = public.stat_atolye_kombinasyon(:'k1', :'gec')), false) AS esit
        FROM pg_proc f
       WHERE f.oid = to_regprocedure('public.stat_atolye_kombinasyon_k(jsonb,jsonb,jsonb)')) x
WHERE kod = 'komb_k_acl_invoker';

-- TS1
UPDATE _stat_durum SET
  deger = CASE WHEN x.s#>'{a,n}' = '1' AND x.s#>'{a,basari}' = '{"k":0,"n":1,"y":0.0}' AND x.s#>'{a,hiz}' = '{"n":0,"medyan":null}'
                AND x.s#>'{a,tl}' = '{"n":1,"medyan":70.00}'
                AND x.s#>'{b,n}' = '8' AND x.s#>'{b,basari}' = '{"k":5,"n":8,"y":62.5}' AND x.s#>'{b,hiz}' = '{"n":8,"medyan":4.5}'
                AND x.s#>'{b,tl}' = '{"n":8,"medyan":20.00}' AND x.s->'yetersiz' = 'true' THEN 'PASS' ELSE 'FAIL' END,
  etiket = coalesce(x.s::text, '∅')
FROM (SELECT public.stat_atolye_kombinasyon(jsonb_set(c, '{hastalik,deger}', '"e2e57201-0000-4000-8000-000000000006"'), :'gec'::jsonb)#>'{satirlar,0}' AS s
        FROM _st5_c WHERE ad = 'K1') x
WHERE kod = 'komb_payda_tedavi_degisti';

SELECT pg_temp._st2_temizle();
UPDATE _stat_durum SET deger = CASE WHEN pg_temp._st2_artik() = 0 THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'artık=' || pg_temp._st2_artik()
WHERE kod = 'artik';
\endif

\echo '=== ÖZET ==='
SELECT kod, deger, etiket FROM _stat_durum ORDER BY kod;
SELECT 'TOPLAM: PASS=' || count(*) FILTER (WHERE deger = 'PASS') || ' FAIL=' || count(*) FILTER (WHERE deger = 'FAIL')
       || ' UNMEASURED=' || count(*) FILTER (WHERE deger = 'UNMEASURED') AS ozet FROM _stat_durum;
