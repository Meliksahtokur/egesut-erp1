-- tests/sql/stat_saglik_vaka_test.sql
-- İstatistik Atölyesi AP1 Task 3 — v_stat_saglik_vaka, v_stat_saglik_vaka_ilac, vekil gecikme, maliyet yardımcıları
-- (spec v2 §4.2.1-§4.2.5; plan Task 3 + Review Focus 1, 2, 4; root ruling 2026-10-17 T1(e)=C log kolu daraltması).
--
-- HEDEF: YALNIZ demo (ref vtzqjmazsvurxdeondmi). Fixture: stat_saglik_fixture.sql (E2E-ST2- önekli).
-- KOŞUM:
--   psql "$OVS_DEMO_DB_URL" -X -v ON_ERROR_STOP=0 -v stat_fixture_ok=true -f tests/sql/stat_saglik_vaka_test.sql
--   (stat_fixture_ok verilmemiş/false → fixture yazılmaz, tüm kodlar UNMEASURED kalır.)
-- SONUÇ: _stat_durum(kod, PASS|FAIL|UNMEASURED, etiket); kod başına bir satır. Başta ve sonda temizlik;
--   sonda `artik` kodu E2E-ST2- artık sayımı = 0'ı ölçer.
-- G kuralı: toplu beklentileri stat_saglik_vekil().g ile hesaplanır; `vekil_kahin` bu G'yi test içinde ayrıca
--   yazılmış bağımsız kâhinle (aynı tanım, taban tablolardan) karşılaştırır.

\if :{?stat_fixture_ok}
\else
\set stat_fixture_ok false
\endif
\echo '=== v_stat_saglik_vaka testi ===' stat_fixture_ok= :stat_fixture_ok

DROP TABLE IF EXISTS _stat_durum;
CREATE TEMP TABLE _stat_durum(kod text PRIMARY KEY, deger text, etiket text);

-- vaka beklentileri: var = view'da satır var mı; G'ye bağlı kapanma: toplu_1 = LEAST(2+G,20), toplu_2 = LEAST(G,15)
DROP TABLE IF EXISTS _st2_bek;
-- ts/uyg/plan/uyum/ilk (review tur1): tedavi_suresi_gun, uygulanan_gun, plan_gun, plan_uyum, ilk_uygulama = T − ilk;
-- elle sabit (fixture uygulama tablosundan); kupe_no = 'K-' || hayvan_id (fixture öyle yazar; id ile karışmasın)
CREATE TEMP TABLE _st2_bek(kod text PRIMARY KEY, var boolean, durum text, sonuc text, kapanma text,
                           vekil boolean, toplu boolean, ts int, uyg int, plan int, uyum numeric, ilk int);
INSERT INTO _st2_bek VALUES
  ('normal',           true,  'sonuclandi', 'basarili',             '5',     false, false, 3, 3, 3, 1.000, 100),
  ('olum_30',          true,  'sonuclandi', 'basarisiz_olum_kesim', '4',     false, false, 1, 1, 1, 1.000, 80),
  ('kesim_31',         true,  'sonuclandi', 'basarili',             '2',     false, false, 1, 1, 1, 1.000, 90),
  ('satis',            true,  'sonuclandi', 'basarili',             '3',     false, false, 1, 1, 1, 1.000, 70),
  ('nuks_30',          true,  'sonuclandi', 'basarisiz_nuks',       '5',     false, false, 1, 1, 1, 1.000, 120),
  ('nuks_30_b',        true,  'sonuclandi', 'basarili',             '5',     false, false, 1, 1, 1, 1.000, 85),
  ('nuks_31',          true,  'sonuclandi', 'basarili',             '5',     false, false, 1, 1, 1, 1.000, 150),
  ('nuks_31_b',        true,  'sonuclandi', 'basarili',             '4',     false, false, 1, 1, 1, 1.000, 114),
  ('olgun_degil',      true,  'sonuclandi', 'olgunlasmamis',        '10',    false, false, 1, 1, 1, 1.000, 20),
  ('olgun_sinir',      true,  'sonuclandi', 'basarili',             '3',     false, false, 1, 1, 1, 1.000, 33),
  ('aktif_olum',       true,  'sonuclandi', 'basarisiz_olum_kesim', NULL,    false, false, 1, 1, 1, 1.000, 40),
  ('aktif_acik',       true,  'acik',       NULL,                   NULL,    false, false, 1, 1, 1, 1.000, 30),
  ('toplu_1',          true,  'sonuclandi', 'basarili',             'T1',    true,  true, 3, 3, 3, 1.000, 70),
  ('toplu_2',          true,  'sonuclandi', 'basarili',             'T2',    true,  true, 1, 1, 1, 1.000, 65),
  ('toplu_bos',        true,  'sonuclandi', 'basarili',             NULL,    false, true, NULL, 0, 0, NULL, NULL),
  ('ovsync',           false, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('fallback',         true,  'sonuclandi', 'basarili',             '4',     false, false, 1, 1, 1, 1.000, 55),
  ('uyusmaz',          true,  'sonuclandi', 'basarili',             '4',     false, false, 1, 1, 1, 1.000, 58),
  ('stoksuz_tekil',    true,  'sonuclandi', 'basarili',             '3',     false, false, 1, 1, 1, 1.000, 62),
  ('stoksuz_coklu',    true,  'sonuclandi', 'basarili',             '3',     false, false, 1, 1, 1, 1.000, 62),
  ('bilinmiyor',       true,  'sonuclandi', 'basarili',             '4',     false, false, 1, 1, 1, 1.000, 45),
  ('tz_gece',          true,  'sonuclandi', 'basarili',             '4',     false, false, 1, 1, 1, 1.000, 35),
  ('ovsync_log',       false, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('ovsync_sablon',    false, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('tz_olgun',         true,  'sonuclandi', 'olgunlasmamis',        '4',     false, false, 1, 1, 1, 1.000, 33),
  ('log_iptal_tedavi', true,  'sonuclandi', 'basarili',             '4',     false, false, 1, 1, 1, 1.000, 48),
  ('log_ovsync_aktif', false, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
  ('kapali_tarihsiz',  true,  'kapali_tarihsiz', NULL,                   NULL,    false, false, 1, 1, 1, 1.000, 40),
  ('plan_eksik',       true,  'sonuclandi', 'basarili',             '5',     false, false, 1, 1, 3, 0.333, 75);

INSERT INTO _stat_durum(kod, deger, etiket)
SELECT 'vaka_sonuc_' || kod, 'UNMEASURED', 'sonuc + kapanma_gunu + vekil + tedavi/plan kolonları' FROM _st2_bek;
INSERT INTO _stat_durum(kod, deger, etiket) VALUES
  ('bugun_tr',             'UNMEASURED', 'stat_bugun() = TR günü'),
  ('ovsync_yok',           'UNMEASURED', '14/21/22/25 iki view''da yok; 21 nüks adayı değil'),
  ('ovsync_dislanan_sayi', 'UNMEASURED', 'fixture''ta stat_vaka_ovsync_mu = 4 vaka'),
  ('log_iptal_tedavi',     'UNMEASURED', 'NULL ailesi şablonu + iptal=true log → kapsamda'),
  ('log_ovsync_aktif',     'UNMEASURED', 'OVSYNC şablonu + iptal=false log → dışlanır'),
  ('tz_gece_kapanis',      'UNMEASURED', '01:30 TR kapanış TR gününe'),
  ('tz_olgun_tr',          'UNMEASURED', 'olgunlaşma TR gününe göre'),
  ('ilac_normal',          'UNMEASURED', 'iki ilaç × üç düzey, DISTINCT'),
  ('ilac_fallback',        'UNMEASURED', 'stok fallback 3 düzey'),
  ('ilac_bilinmiyor',      'UNMEASURED', '(bilinmiyor) 3 düzey'),
  ('kalem_normal',         'UNMEASURED', '(stok,birim) birleşik toplam'),
  ('kalem_uyusmaz',        'UNMEASURED', 'birim_uyusmaz'),
  ('kalem_stoksuz_tekil',  'UNMEASURED', 'tekil stok fallback'),
  ('kalem_stoksuz_coklu',  'UNMEASURED', 'çok stoklu ürün → stoksuz'),
  ('kategorisiz',          'UNMEASURED', 'NULL kategori → Kategorisiz'),
  ('tl_normal_gecici',     'UNMEASURED', 'SA=2, SB=10 → 90.00, gecici'),
  ('tl_kayitli',           'UNMEASURED', 'SK 3 ml × 20 → 60.00, kayitli'),
  ('tl_fiyatsiz',          'UNMEASURED', 'SA fiyatsız → NULL, fiyatsiz'),
  ('tl_bos',               'UNMEASURED', 'boş kalem dizisi → 0'),
  ('medyan_gecikme_az',    'UNMEASURED', '{1,2,3,4} → 0'),
  ('medyan_gecikme_yuvarla','UNMEASURED', '{4,6,7,13,20,1} → 7'),
  ('vekil_kahin',          'UNMEASURED', 'stat_saglik_vekil() = bağımsız kâhin'),
  ('acl_anon',             'UNMEASURED', 'anon hiçbir nesneye erişemez; authenticated erişir'),
  ('invoker',              'UNMEASURED', 'prosecdef=false, search_path, oynaklık, security_invoker, rol eşitliği'),
  ('artik',                'UNMEASURED', 'E2E-ST2- artık = 0');
-- TK1 (root ruling R2): nüks penceresi kapanış günü dahil (n.start_date >= kapanış)
INSERT INTO _stat_durum(kod, deger, etiket) VALUES
  ('nuks_gun0',            'UNMEASURED', 'n0_a kapanış günü açılan n0_b ile basarisiz_nuks; n0_b basarili');
-- TS1 (sahip S1 (c), domain §19.7): kapanış + 24 saat içinde aynı hayvan + hastalık için yeni vaka → tedavi değişti
INSERT INTO _stat_durum(kod, deger, etiket) VALUES
  ('tedavi_degisti_23s',         'UNMEASURED', 'td23_a: yeni vaka +23 saat → tedavi değişti (nüks değil), kg NULL, vekil false; td23_b basarili'),
  ('tedavi_degisti_24s_sinir',   'UNMEASURED', 'td24_a: yeni vaka tam +24 saat → tedavi değişti (24 saat dahil)'),
  ('nuks_24s_ustu',              'UNMEASURED', 'ust_a: yeni vaka +24 saat 1 sn, start_date 30 gün içinde → basarisiz_nuks kalır, kg dolu'),
  ('olum_oncelik',               'UNMEASURED', 'ol_a: ölüm/kesim + 24 saat içinde yeni vaka → basarisiz_olum_kesim, kg dolu'),
  ('tedavi_degisti_once_kayit',  'UNMEASURED', 'yeni vaka kapanıştan önce kaydedilmiş (aynı gün) → tedavi değişti (ruling)'),
  ('tedavi_degisti_created_null','UNMEASURED', 'yeni vaka created_at NULL → koşul sağlanmaz, nüks kolu'),
  ('tedavi_degisti_eski_kayit',  'UNMEASURED', 'Ö2: kardeş vaka eskisinden önce kaydedilmiş → tedavi değişti değil, nüks kolu'),
  ('tedavi_degisti_ayni_an',     'UNMEASURED', 'Ö2: kardeş vaka aynı anda kaydedilmiş (created_at eşit) → sonra kaydedilmiş sayılmaz, nüks kolu'),
  ('tedavi_degisti_eski_null',   'UNMEASURED', 'Ö2: kapanan vakanın created_at NULL → sonra kaydedildiği kanıtlanamaz, nüks kolu'),
  ('tedavi_degisti_kapsam_disi', 'UNMEASURED', 'yeni vaka Ovsync (kapsam dışı) → tedavi değişti değil, basarili'),
  ('tedavi_degisti_baska_hastalik','UNMEASURED', 'yeni vaka başka hastalık → tedavi değişti değil, basarili'),
  ('tedavi_degisti_toplu',       'UNMEASURED', 'toplu kapanış vakası da kurala tabi: kg NULL, vekil false');

\if :stat_fixture_ok
\ir stat_saglik_fixture.sql

SELECT g AS g, normal_n AS normal_n FROM public.stat_saglik_vekil() \gset
\echo 'vekil G = ' :g ' normal_n = ' :normal_n

-- view görüntüsü (postgres rolü)
DROP TABLE IF EXISTS _st2_v;
CREATE TEMP TABLE _st2_v AS
SELECT b.kod, v.* FROM v_stat_saglik_vaka v JOIN _st2_vaka b ON b.vaka_id = v.vaka_id;
\echo '--- fixture satırları ---'
SELECT kod, durum, sonuc, baslangic, kapanis, toplu_kapanis AS toplu, son_uygulama AS son, tedavi_suresi_gun AS ts,
       kapanma_gunu AS kg, kapanma_vekil AS vekil, kategori, maliyet_kalemleri
FROM _st2_v ORDER BY kod;

-- vaka_sonuc_<kod>
UPDATE _stat_durum d SET
  deger = CASE WHEN r.ok THEN 'PASS' ELSE 'FAIL' END,
  etiket = r.iz
FROM (
  SELECT b.kod,
         CASE WHEN NOT b.var THEN NOT EXISTS (SELECT 1 FROM _st2_v v WHERE v.kod = b.kod)
              ELSE (SELECT count(*) = 1 AND bool_and(
                      v.durum IS NOT DISTINCT FROM b.durum AND v.sonuc IS NOT DISTINCT FROM b.sonuc
                      AND v.kapanma_gunu IS NOT DISTINCT FROM (CASE b.kapanma
                            WHEN 'T1' THEN LEAST(2 + :'g'::int, 20) WHEN 'T2' THEN LEAST(:'g'::int, 15)
                            ELSE b.kapanma::int END)
                      AND v.kapanma_vekil = b.vekil AND v.toplu_kapanis = b.toplu
                      AND v.tedavi_suresi_gun IS NOT DISTINCT FROM b.ts AND v.uygulanan_gun = b.uyg
                      AND v.plan_gun = b.plan AND v.plan_uyum IS NOT DISTINCT FROM b.uyum
                      AND v.ilk_uygulama IS NOT DISTINCT FROM :'t'::date - b.ilk AND v.kupe_no = 'K-' || v.hayvan_id)
                    FROM _st2_v v WHERE v.kod = b.kod)
         END AS ok,
         coalesce((SELECT 'durum=' || v.durum || ' sonuc=' || coalesce(v.sonuc, '∅') || ' kg='
                          || coalesce(v.kapanma_gunu::text, '∅') || ' vekil=' || v.kapanma_vekil
                          || ' toplu=' || v.toplu_kapanis || ' ts=' || coalesce(v.tedavi_suresi_gun::text, '∅')
                          || ' uyg/plan=' || v.uygulanan_gun || '/' || v.plan_gun || ' uyum=' || coalesce(v.plan_uyum::text, '∅')
                          || ' ilk=T-' || coalesce((:'t'::date - v.ilk_uygulama)::text, '∅') || ' kupe=' || coalesce(v.kupe_no, '∅')
                     FROM _st2_v v WHERE v.kod = b.kod), 'satır yok') AS iz
  FROM _st2_bek b
) r
WHERE d.kod = 'vaka_sonuc_' || r.kod;

-- nuks_gun0 (R2): elle sabit beklenti; n0_a.kapanis = n0_b.baslangic = T-55
UPDATE _stat_durum SET
  deger = CASE WHEN a.sonuc = 'basarisiz_nuks' AND a.kapanis = :'t'::date - 55 AND b.baslangic = :'t'::date - 55
                AND b.sonuc = 'basarili' AND a.durum = 'sonuclandi' THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'n0_a sonuc=' || coalesce(a.sonuc, '∅') || ' kapanis=T-' || coalesce((:'t'::date - a.kapanis)::text, '∅')
           || ' / n0_b sonuc=' || coalesce(b.sonuc, '∅') || ' baslangic=T-' || coalesce((:'t'::date - b.baslangic)::text, '∅')
FROM _st2_v a, _st2_v b WHERE a.kod = 'n0_a' AND b.kod = 'n0_b' AND _stat_durum.kod = 'nuks_gun0';

-- TS1: elle sabit beklenti; fark = yeni.created_at − eski.closed_at
CREATE FUNCTION pg_temp._st2_fark(p_eski text, p_yeni text) RETURNS interval LANGUAGE sql AS $f$
  SELECT cy.created_at - ce.closed_at
  FROM _st2_vaka e JOIN cases ce ON ce.id = e.vaka_id, _st2_vaka y JOIN cases cy ON cy.id = y.vaka_id
  WHERE e.kod = p_eski AND y.kod = p_yeni;
$f$;
CREATE FUNCTION pg_temp._st2_iz(p_kod text) RETURNS text LANGUAGE sql AS $f$
  SELECT p_kod || ' durum=' || coalesce(v.durum, '∅') || ' sonuc=' || coalesce(v.sonuc, '∅') || ' kg=' || coalesce(v.kapanma_gunu::text, '∅')
         || ' vekil=' || coalesce(v.kapanma_vekil::text, '∅') || ' ts=' || coalesce(v.tedavi_suresi_gun::text, '∅')
  FROM _st2_v v WHERE v.kod = p_kod;
$f$;
UPDATE _stat_durum SET
  deger = CASE WHEN a.durum = 'sonuclandi' AND a.sonuc = 'basarisiz_tedavi_degisti' AND a.kapanma_gunu IS NULL AND a.kapanma_vekil = false
                AND a.toplu_kapanis = false AND a.tedavi_suresi_gun = 2 AND b.sonuc = 'basarili' AND b.kapanma_gunu = 3
                AND pg_temp._st2_fark('td23_a', 'td23_b') = interval '23 hours' THEN 'PASS' ELSE 'FAIL' END,
  etiket = pg_temp._st2_iz('td23_a') || ' / ' || pg_temp._st2_iz('td23_b') || ' fark=' || coalesce(pg_temp._st2_fark('td23_a', 'td23_b')::text, '∅')
FROM _st2_v a, _st2_v b WHERE a.kod = 'td23_a' AND b.kod = 'td23_b' AND _stat_durum.kod = 'tedavi_degisti_23s';
UPDATE _stat_durum SET
  deger = CASE WHEN a.sonuc = 'basarisiz_tedavi_degisti' AND a.kapanma_gunu IS NULL AND a.kapanma_vekil = false
                AND pg_temp._st2_fark('td24_a', 'td24_b') = interval '24 hours' THEN 'PASS' ELSE 'FAIL' END,
  etiket = pg_temp._st2_iz('td24_a') || ' fark=' || coalesce(pg_temp._st2_fark('td24_a', 'td24_b')::text, '∅')
FROM _st2_v a WHERE a.kod = 'td24_a' AND _stat_durum.kod = 'tedavi_degisti_24s_sinir';
UPDATE _stat_durum SET
  deger = CASE WHEN a.sonuc = 'basarisiz_nuks' AND a.kapanma_gunu = 5 AND b.baslangic <= a.kapanis + 30
                AND pg_temp._st2_fark('ust_a', 'ust_b') = interval '24 hours 1 second' THEN 'PASS' ELSE 'FAIL' END,
  etiket = pg_temp._st2_iz('ust_a') || ' fark=' || coalesce(pg_temp._st2_fark('ust_a', 'ust_b')::text, '∅')
FROM _st2_v a, _st2_v b WHERE a.kod = 'ust_a' AND b.kod = 'ust_b' AND _stat_durum.kod = 'nuks_24s_ustu';
UPDATE _stat_durum SET
  deger = CASE WHEN a.sonuc = 'basarisiz_olum_kesim' AND a.kapanma_gunu = 5 AND pg_temp._st2_fark('ol_a', 'ol_b') = interval '2 hours'
               THEN 'PASS' ELSE 'FAIL' END,
  etiket = pg_temp._st2_iz('ol_a') || ' fark=' || coalesce(pg_temp._st2_fark('ol_a', 'ol_b')::text, '∅')
FROM _st2_v a WHERE a.kod = 'ol_a' AND _stat_durum.kod = 'olum_oncelik';

-- TS1 kenar durumları: tek transaction içinde fixture değiştirilir, view okunur, ROLLBACK (fixture aynen kalır)
CREATE FUNCTION pg_temp._st2_sonuc(p_kod text) RETURNS text LANGUAGE sql AS $f$
  SELECT coalesce((SELECT v.sonuc || '/' || coalesce(v.kapanma_gunu::text, '∅') || '/' || v.kapanma_vekil
                     FROM v_stat_saglik_vaka v JOIN _st2_vaka k ON k.vaka_id = v.vaka_id WHERE k.kod = p_kod), '∅');
$f$;
BEGIN;
UPDATE cases c SET created_at = o.closed_at - interval '1 hour'
  FROM cases o WHERE o.id = (SELECT vaka_id FROM _st2_vaka WHERE kod = 'td24_a')
                 AND c.id = (SELECT vaka_id FROM _st2_vaka WHERE kod = 'td24_b');
SELECT pg_temp._st2_sonuc('td24_a') AS s_once \gset
ROLLBACK;
UPDATE _stat_durum SET deger = CASE WHEN :'s_once' = 'basarisiz_tedavi_degisti/∅/false' THEN 'PASS' ELSE 'FAIL' END, etiket = :'s_once'
WHERE kod = 'tedavi_degisti_once_kayit';
-- Ö2 (kapı F3): yeni vaka, kapanan vakadan SONRA kaydedilmiş olmalı (n.created_at > k.created_at). Çift açılmış kaydın
--   kısa olanı kapatılınca "tedavi değişti" sayılmaz. td24_a beklenen kg = 10 (kapanış T-270 − başlangıç T-280).
BEGIN;
UPDATE cases c SET created_at = o.created_at - interval '1 hour'
  FROM cases o WHERE o.id = (SELECT vaka_id FROM _st2_vaka WHERE kod = 'td24_a')
                 AND c.id = (SELECT vaka_id FROM _st2_vaka WHERE kod = 'td24_b');
SELECT pg_temp._st2_sonuc('td24_a') AS s_eski \gset
ROLLBACK;
UPDATE _stat_durum SET deger = CASE WHEN :'s_eski' = 'basarisiz_nuks/10/false' THEN 'PASS' ELSE 'FAIL' END, etiket = :'s_eski'
WHERE kod = 'tedavi_degisti_eski_kayit';
BEGIN;
UPDATE cases c SET created_at = o.created_at
  FROM cases o WHERE o.id = (SELECT vaka_id FROM _st2_vaka WHERE kod = 'td24_a')
                 AND c.id = (SELECT vaka_id FROM _st2_vaka WHERE kod = 'td24_b');
SELECT pg_temp._st2_sonuc('td24_a') AS s_esit \gset
ROLLBACK;
UPDATE _stat_durum SET deger = CASE WHEN :'s_esit' = 'basarisiz_nuks/10/false' THEN 'PASS' ELSE 'FAIL' END, etiket = :'s_esit'
WHERE kod = 'tedavi_degisti_ayni_an';
BEGIN;
UPDATE cases SET created_at = NULL WHERE id = (SELECT vaka_id FROM _st2_vaka WHERE kod = 'td24_a');
SELECT pg_temp._st2_sonuc('td24_a') AS s_enull \gset
ROLLBACK;
UPDATE _stat_durum SET deger = CASE WHEN :'s_enull' = 'basarisiz_nuks/10/false' THEN 'PASS' ELSE 'FAIL' END, etiket = :'s_enull'
WHERE kod = 'tedavi_degisti_eski_null';
BEGIN;
UPDATE cases SET created_at = NULL WHERE id = (SELECT vaka_id FROM _st2_vaka WHERE kod = 'td23_b');
SELECT pg_temp._st2_sonuc('td23_a') AS s_null \gset
ROLLBACK;
UPDATE _stat_durum SET deger = CASE WHEN :'s_null' = 'basarisiz_nuks/10/false' THEN 'PASS' ELSE 'FAIL' END, etiket = :'s_null'
WHERE kod = 'tedavi_degisti_created_null';
BEGIN;
UPDATE cases SET protocol_family = 'OVSYNC' WHERE id = (SELECT vaka_id FROM _st2_vaka WHERE kod = 'td23_b');
SELECT pg_temp._st2_sonuc('td23_a') AS s_ovs \gset
ROLLBACK;
UPDATE _stat_durum SET deger = CASE WHEN :'s_ovs' = 'basarili/10/false' THEN 'PASS' ELSE 'FAIL' END, etiket = :'s_ovs'
WHERE kod = 'tedavi_degisti_kapsam_disi';
BEGIN;
UPDATE cases SET disease_id = 'e2e57201-0000-4000-8000-000000000005'
 WHERE id = (SELECT vaka_id FROM _st2_vaka WHERE kod = 'td23_b');
SELECT pg_temp._st2_sonuc('td23_a') AS s_bh \gset
ROLLBACK;
UPDATE _stat_durum SET deger = CASE WHEN :'s_bh' = 'basarili/10/false' THEN 'PASS' ELSE 'FAIL' END, etiket = :'s_bh'
WHERE kod = 'tedavi_degisti_baska_hastalik';
BEGIN;
-- toplu_1 fixture'da DEFAULT now() ile kaydedilir; Ö2 yeni vakanın ondan sonra kaydedilmesini ister, gerçekçi kayıt anı yazılır.
UPDATE cases SET created_at = start_date::timestamp AT TIME ZONE 'Europe/Istanbul' WHERE id = (SELECT vaka_id FROM _st2_vaka WHERE kod = 'toplu_1');
INSERT INTO cases(id, animal_id, disease_id, start_date, status, created_at)
SELECT 'e2e57209-0000-4000-8000-000000000099', 'E2E-ST2-11', 'e2e57201-0000-4000-8000-000000000001', :'t'::date - 50, 'active',
       ((:'t'::date - 50) + time '17:00') AT TIME ZONE 'Europe/Istanbul';
SELECT pg_temp._st2_sonuc('toplu_1') AS s_top \gset
ROLLBACK;
UPDATE _stat_durum SET deger = CASE WHEN :'s_top' = 'basarisiz_tedavi_degisti/∅/false' THEN 'PASS' ELSE 'FAIL' END, etiket = :'s_top'
WHERE kod = 'tedavi_degisti_toplu';

UPDATE _stat_durum SET
  deger = CASE WHEN public.stat_bugun() = :'t'::date THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'stat_bugun=' || public.stat_bugun() || ' T=' || :'t'
WHERE kod = 'bugun_tr';

-- ovsync_yok: dört protokol vakası iki view'da yok; 21'in önüne (kapanış+10) konan Enterit vakası nüks olmaz
SELECT count(*) AS ovs_n FROM (
  SELECT vaka_id FROM v_stat_saglik_vaka UNION ALL SELECT vaka_id FROM v_stat_saglik_vaka_ilac) x
WHERE vaka_id IN (SELECT vaka_id FROM _st2_vaka WHERE kod IN ('ovsync', 'ovsync_log', 'ovsync_sablon', 'log_ovsync_aktif'))
\gset
BEGIN;
INSERT INTO cases(id, animal_id, disease_id, start_date, status, closed_at) VALUES
  ('e2e57205-0000-4000-8000-000000000099', 'E2E-ST2-21', 'e2e57201-0000-4000-8000-000000000001', :'t'::date - 75,
   'closed', ((:'t'::date - 70) + time '12:00') AT TIME ZONE 'Europe/Istanbul');
SELECT coalesce((SELECT sonuc FROM v_stat_saglik_vaka WHERE vaka_id = 'e2e57205-0000-4000-8000-000000000099'), '∅')
  AS onceki_sonuc \gset
ROLLBACK;
UPDATE _stat_durum SET
  deger = CASE WHEN :'ovs_n'::int = 0 AND :'onceki_sonuc' = 'basarili' THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'view satırı=' || :'ovs_n' || ' 21-önceki sonuc=' || :'onceki_sonuc'
WHERE kod = 'ovsync_yok';

UPDATE _stat_durum SET
  deger = CASE WHEN x.n = 4 AND x.kodlar = 'log_ovsync_aktif,ovsync,ovsync_log,ovsync_sablon' THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'n=' || x.n || ' ' || coalesce(x.kodlar, '∅')
FROM (SELECT count(*)::int AS n, string_agg(kod, ',' ORDER BY kod) AS kodlar
        FROM _st2_vaka WHERE public.stat_vaka_ovsync_mu(vaka_id)) x
WHERE kod = 'ovsync_dislanan_sayi';

UPDATE _stat_durum SET
  deger = CASE WHEN NOT public.stat_vaka_ovsync_mu(v.vaka_id)
                AND EXISTS (SELECT 1 FROM _st2_v s WHERE s.kod = 'log_iptal_tedavi' AND s.sonuc = 'basarili')
                AND EXISTS (SELECT 1 FROM v_stat_saglik_vaka_ilac i WHERE i.vaka_id = v.vaka_id)
                AND EXISTS (SELECT 1 FROM gorev_log g WHERE g.hayvan_id = v.hayvan_id AND g.iptal
                              AND g.kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:' || v.vaka_id::text || ':%')
               THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'ovsync_mu=' || public.stat_vaka_ovsync_mu(v.vaka_id)
FROM _st2_vaka v WHERE v.kod = 'log_iptal_tedavi' AND _stat_durum.kod = 'log_iptal_tedavi';

UPDATE _stat_durum SET
  deger = CASE WHEN public.stat_vaka_ovsync_mu(v.vaka_id)
                AND NOT EXISTS (SELECT 1 FROM v_stat_saglik_vaka s WHERE s.vaka_id = v.vaka_id)
                AND NOT EXISTS (SELECT 1 FROM sablon_hastalik_eslem e
                                 WHERE e.disease_id = 'e2e57201-0000-4000-8000-000000000001')
               THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'ovsync_mu=' || public.stat_vaka_ovsync_mu(v.vaka_id) || ' (Enterit şablon eşlemesiz → yalnız log kolu)'
FROM _st2_vaka v WHERE v.kod = 'log_ovsync_aktif' AND _stat_durum.kod = 'log_ovsync_aktif';

UPDATE _stat_durum SET
  deger = CASE WHEN v.kapanis = :'t'::date - 31 AND (c.closed_at AT TIME ZONE 'UTC')::date = :'t'::date - 32
               THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'kapanis=' || coalesce(v.kapanis::text, '∅') || ' utc=' || (c.closed_at AT TIME ZONE 'UTC')::date
FROM _st2_v v JOIN cases c ON c.id = v.vaka_id WHERE v.kod = 'tz_gece' AND _stat_durum.kod = 'tz_gece_kapanis';

UPDATE _stat_durum SET
  deger = CASE WHEN v.kapanis = :'t'::date - 29 AND v.sonuc = 'olgunlasmamis'
                AND (c.closed_at AT TIME ZONE 'UTC')::date = :'t'::date - 30 THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'kapanis=' || coalesce(v.kapanis::text, '∅') || ' sonuc=' || coalesce(v.sonuc, '∅')
FROM _st2_v v JOIN cases c ON c.id = v.vaka_id WHERE v.kod = 'tz_olgun' AND _stat_durum.kod = 'tz_olgun_tr';

-- vaka × ilaç
CREATE FUNCTION pg_temp._st2_ilac(p_kod text) RETURNS text LANGUAGE sql AS $f$
  SELECT coalesce(string_agg(i.duzey || '=' || i.deger, ',' ORDER BY i.duzey, i.deger), '∅') || ' n=' || count(*)
  FROM v_stat_saglik_vaka_ilac i JOIN _st2_vaka v ON v.vaka_id = i.vaka_id WHERE v.kod = p_kod;
$f$;
UPDATE _stat_durum SET etiket = pg_temp._st2_ilac('normal'),
  deger = CASE WHEN pg_temp._st2_ilac('normal') = 'etken=E2E-ETK-A,etken=E2E-ETK-B,preparat=E2E-PREP-A,'
            || 'preparat=E2E-PREP-B,sinif=E2E-GRUP-2,sinif=E2E-SINIF-1 n=6' THEN 'PASS' ELSE 'FAIL' END
WHERE kod = 'ilac_normal';
UPDATE _stat_durum SET etiket = pg_temp._st2_ilac('fallback'),
  deger = CASE WHEN pg_temp._st2_ilac('fallback') = 'etken=E2E-ETK-B,preparat=E2E-PREP-B,sinif=E2E-GRUP-2 n=3'
          THEN 'PASS' ELSE 'FAIL' END
WHERE kod = 'ilac_fallback';
UPDATE _stat_durum SET etiket = pg_temp._st2_ilac('bilinmiyor'),
  deger = CASE WHEN pg_temp._st2_ilac('bilinmiyor')
                    = 'etken=(bilinmiyor),preparat=(bilinmiyor),sinif=(bilinmiyor) n=3' THEN 'PASS' ELSE 'FAIL' END
WHERE kod = 'ilac_bilinmiyor';

-- maliyet kalemleri
CREATE FUNCTION pg_temp._st2_kalem(p_kod text) RETURNS jsonb LANGUAGE sql AS $f$
  SELECT maliyet_kalemleri FROM _st2_v WHERE kod = p_kod;
$f$;
UPDATE _stat_durum SET etiket = coalesce(pg_temp._st2_kalem('normal')::text, '∅'),
  deger = CASE WHEN pg_temp._st2_kalem('normal') = '[{"stok_id":"E2E-ST2-SA","birim":"ml","miktar":20,"neden":null},
                    {"stok_id":"E2E-ST2-SB","birim":"ml","miktar":5,"neden":null}]'::jsonb THEN 'PASS' ELSE 'FAIL' END
WHERE kod = 'kalem_normal';
UPDATE _stat_durum SET etiket = coalesce(pg_temp._st2_kalem('uyusmaz')::text, '∅'),
  deger = CASE WHEN pg_temp._st2_kalem('uyusmaz')
                    = '[{"stok_id":"E2E-ST2-SA","birim":"gr","miktar":2,"neden":"birim_uyusmaz"}]'::jsonb
                AND public.stat_saglik_vaka_tl(pg_temp._st2_kalem('uyusmaz'), '{"E2E-ST2-SA":2}') IS NULL
               THEN 'PASS' ELSE 'FAIL' END
WHERE kod = 'kalem_uyusmaz';
UPDATE _stat_durum SET etiket = coalesce(pg_temp._st2_kalem('stoksuz_tekil')::text, '∅'),
  deger = CASE WHEN pg_temp._st2_kalem('stoksuz_tekil')
                    = '[{"stok_id":"E2E-ST2-SA","birim":"ml","miktar":4,"neden":null}]'::jsonb THEN 'PASS' ELSE 'FAIL' END
WHERE kod = 'kalem_stoksuz_tekil';
UPDATE _stat_durum SET etiket = coalesce(pg_temp._st2_kalem('stoksuz_coklu')::text, '∅'),
  deger = CASE WHEN pg_temp._st2_kalem('stoksuz_coklu')
                    = '[{"stok_id":null,"birim":"ml","miktar":4,"neden":"stoksuz"}]'::jsonb
                AND public.stat_saglik_vaka_tl(pg_temp._st2_kalem('stoksuz_coklu'),
                                               '{"E2E-ST2-SB":10,"E2E-ST2-SK":10}') IS NULL
               THEN 'PASS' ELSE 'FAIL' END
WHERE kod = 'kalem_stoksuz_coklu';
UPDATE _stat_durum SET
  etiket = (SELECT string_agg(kod || '=' || kategori, ',' ORDER BY kod) FROM _st2_v
             WHERE kod IN ('stoksuz_coklu', 'normal')),
  deger = CASE WHEN (SELECT kategori FROM _st2_v WHERE kod = 'stoksuz_coklu') = 'Kategorisiz'
                AND (SELECT kategori FROM _st2_v WHERE kod = 'normal') = 'E2E-ST2-Kat' THEN 'PASS' ELSE 'FAIL' END
WHERE kod = 'kategorisiz';

-- ₺ hesap
UPDATE _stat_durum SET
  etiket = 'tl=' || coalesce(x.tl::text, '∅') || ' kaynak=' || coalesce(x.kaynak, '∅'),
  deger = CASE WHEN x.tl = 90.00 AND x.kaynak = 'gecici' THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT public.stat_saglik_vaka_tl(pg_temp._st2_kalem('normal'), '{"E2E-ST2-SA":2,"E2E-ST2-SB":10}') AS tl,
             public.stat_saglik_fiyat_kaynagi(pg_temp._st2_kalem('normal'), '{"E2E-ST2-SA":2,"E2E-ST2-SB":10}') AS kaynak) x
WHERE kod = 'tl_normal_gecici';
UPDATE _stat_durum SET
  etiket = 'tl=' || coalesce(x.tl::text, '∅') || ' kaynak=' || coalesce(x.kaynak, '∅'),
  deger = CASE WHEN x.tl = 60.00 AND x.kaynak = 'kayitli' THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT public.stat_saglik_vaka_tl(k, '{}') AS tl, public.stat_saglik_fiyat_kaynagi(k, '{}') AS kaynak
        FROM (SELECT '[{"stok_id":"E2E-ST2-SK","birim":"ml","miktar":3,"neden":null}]'::jsonb AS k) q) x
WHERE kod = 'tl_kayitli';
UPDATE _stat_durum SET
  etiket = 'tl=' || coalesce(x.tl::text, '∅') || ' kaynak=' || coalesce(x.kaynak, '∅'),
  deger = CASE WHEN x.tl IS NULL AND x.kaynak = 'fiyatsiz' THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT public.stat_saglik_vaka_tl(k, '{}') AS tl, public.stat_saglik_fiyat_kaynagi(k, '{}') AS kaynak
        FROM (SELECT '[{"stok_id":"E2E-ST2-SA","birim":"ml","miktar":10,"neden":null}]'::jsonb AS k) q) x
WHERE kod = 'tl_fiyatsiz';
UPDATE _stat_durum SET
  etiket = 'tl=' || coalesce(x.tl::text, '∅') || ' toplu_bos kalem=' || coalesce(pg_temp._st2_kalem('toplu_bos')::text, '∅'),
  deger = CASE WHEN x.tl = 0 AND pg_temp._st2_kalem('toplu_bos') = '[]'::jsonb THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT public.stat_saglik_vaka_tl('[]'::jsonb, '{}') AS tl) x
WHERE kod = 'tl_bos';

-- medyan gecikme
UPDATE _stat_durum SET etiket = 'sonuc=' || coalesce(public.stat_medyan_gecikme('{1,2,3,4}')::text, '∅'),
  deger = CASE WHEN public.stat_medyan_gecikme('{1,2,3,4}') = 0 THEN 'PASS' ELSE 'FAIL' END
WHERE kod = 'medyan_gecikme_az';
UPDATE _stat_durum SET etiket = 'sonuc=' || coalesce(public.stat_medyan_gecikme('{4,6,7,13,20,1}')::text, '∅'),
  deger = CASE WHEN public.stat_medyan_gecikme('{4,6,7,13,20,1}') = 7 THEN 'PASS' ELSE 'FAIL' END
WHERE kod = 'medyan_gecikme_yuvarla';

-- vekil kâhini: aynı tanım, taban tablolardan bağımsız yazım (ruling log kolu dahil)
WITH kapsam AS (
  SELECT c.id, c.closed_at, (c.closed_at AT TIME ZONE 'Europe/Istanbul')::date AS kap
  FROM cases c JOIN diseases d ON d.id = c.disease_id
  WHERE c.status = 'closed' AND c.closed_at IS NOT NULL
    AND NOT (coalesce(c.protocol_family, '') = 'OVSYNC' OR d.name ILIKE '%ovsync%'
             OR (c.protocol_family IS NULL AND (
                   c.disease_id IN (SELECT e.disease_id FROM sablon_hastalik_eslem e
                                      JOIN tedavi_sablonu t ON t.id = e.sablon_id WHERE t.protokol_ailesi = 'OVSYNC')
                   OR c.id::text IN (SELECT split_part(g.kaynak, ':', 2) FROM gorev_log g
                                       JOIN tedavi_sablonu t ON t.id::text = split_part(g.kaynak, ':', 3)
                                      WHERE g.kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:%' AND g.iptal = false
                                        AND t.protokol_ailesi = 'OVSYNC'))))
), toplu AS (
  SELECT closed_at FROM cases WHERE status = 'closed' AND closed_at IS NOT NULL GROUP BY closed_at HAVING count(*) >= 3
), son AS (
  SELECT td.case_id, max(td.treatment_date) AS son FROM treatment_days td
  JOIN drug_administrations a ON a.treatment_day_id = td.id AND coalesce(a.uygulanmadi, false) = false
  GROUP BY td.case_id
), gec AS (
  SELECT k.kap - s.son AS x FROM kapsam k JOIN son s ON s.case_id = k.id
  WHERE k.closed_at NOT IN (SELECT closed_at FROM toplu)
)
SELECT count(*)::int AS k_n,
       CASE WHEN count(*) < 5 THEN 0
            ELSE round((percentile_cont(0.5) WITHIN GROUP (ORDER BY x))::numeric, 0)::int END AS k_g
FROM gec \gset
UPDATE _stat_durum SET
  deger = CASE WHEN :'k_g'::int = :'g'::int AND :'k_n'::int = :'normal_n'::int THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'fn g=' || :'g' || ' n=' || :'normal_n' || ' / kâhin g=' || :'k_g' || ' n=' || :'k_n'
WHERE kod = 'vekil_kahin';

-- ACL + INVOKER
DROP TABLE IF EXISTS _st2_fn;
CREATE TEMP TABLE _st2_fn(imza text PRIMARY KEY, oynak char);
INSERT INTO _st2_fn VALUES
  ('public.stat_bugun()', 's'), ('public.stat_vaka_ovsync_mu(uuid)', 's'), ('public.stat_medyan_gecikme(integer[])', 'i'),
  ('public.stat_saglik_vekil()', 's'), ('public.stat_saglik_vaka_tl(jsonb,jsonb)', 's'),
  ('public.stat_saglik_fiyat_kaynagi(jsonb,jsonb)', 's');
UPDATE _stat_durum SET
  deger = CASE WHEN x.anon_fn = 0 AND x.anon_v = 0 AND x.au_fn = 6 AND x.au_v = 2 THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'anon fn=' || x.anon_fn || ' view=' || x.anon_v || ' / authenticated fn=' || x.au_fn || ' view=' || x.au_v
FROM (SELECT (SELECT count(*) FILTER (WHERE has_function_privilege('anon', imza, 'EXECUTE')) FROM _st2_fn) AS anon_fn,
             (SELECT count(*) FILTER (WHERE has_function_privilege('authenticated', imza, 'EXECUTE')) FROM _st2_fn) AS au_fn,
             (SELECT count(*) FILTER (WHERE has_table_privilege('anon', v, 'SELECT'))
                FROM unnest(ARRAY['public.v_stat_saglik_vaka', 'public.v_stat_saglik_vaka_ilac']) v) AS anon_v,
             (SELECT count(*) FILTER (WHERE has_table_privilege('authenticated', v, 'SELECT'))
                FROM unnest(ARRAY['public.v_stat_saglik_vaka', 'public.v_stat_saglik_vaka_ilac']) v) AS au_v) x
WHERE kod = 'acl_anon';

-- authenticated geçici tablolara erişemez → iki rol de sabit uuid önekiyle süzer
SELECT count(*) AS pg_n,
       string_agg(vaka_id || ':' || coalesce(sonuc, '-') || ':' || coalesce(kapanma_gunu::text, '-') || ':'
                  || maliyet_kalemleri::text, ',' ORDER BY vaka_id) AS pg_iz
FROM v_stat_saglik_vaka WHERE vaka_id::text LIKE 'e2e57205-%' \gset
SELECT count(*) AS pg_ilac_n FROM v_stat_saglik_vaka_ilac WHERE vaka_id::text LIKE 'e2e57205-%' \gset
BEGIN;
SET LOCAL ROLE authenticated;
SELECT count(*) AS au_n,
       string_agg(vaka_id || ':' || coalesce(sonuc, '-') || ':' || coalesce(kapanma_gunu::text, '-') || ':'
                  || maliyet_kalemleri::text, ',' ORDER BY vaka_id) AS au_iz
FROM v_stat_saglik_vaka WHERE vaka_id::text LIKE 'e2e57205-%' \gset
SELECT count(*) AS au_ilac_n FROM v_stat_saglik_vaka_ilac WHERE vaka_id::text LIKE 'e2e57205-%' \gset
ROLLBACK;
\if :{?au_ilac_n}
\else
\set au_ilac_n -1
\set au_n -1
\set au_iz hata
\endif
UPDATE _stat_durum SET
  deger = CASE WHEN x.fn_ok = 6 AND x.v_ok = 2 AND :'pg_n'::int = 25 AND :'au_n'::int = :'pg_n'::int
                AND :'pg_iz' = :'au_iz' AND :'au_ilac_n'::int = :'pg_ilac_n'::int THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'fn uygun=' || x.fn_ok || '/6 view invoker=' || x.v_ok || '/2 postgres n=' || :'pg_n'
           || ' authenticated n=' || :'au_n' || ' ilac ' || :'pg_ilac_n' || '/' || :'au_ilac_n'
FROM (SELECT (SELECT count(*) FROM _st2_fn f JOIN pg_proc p ON p.oid = f.imza::regprocedure
               WHERE NOT p.prosecdef AND p.provolatile = f.oynak
                 AND 'search_path=public, pg_temp' = ANY (p.proconfig)) AS fn_ok,
             (SELECT count(*) FROM pg_class c
               WHERE c.oid IN ('public.v_stat_saglik_vaka'::regclass, 'public.v_stat_saglik_vaka_ilac'::regclass)
                 AND 'security_invoker=true' = ANY (c.reloptions)) AS v_ok) x
WHERE kod = 'invoker';

SELECT pg_temp._st2_temizle();
UPDATE _stat_durum SET deger = CASE WHEN pg_temp._st2_artik() = 0 THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'artık=' || pg_temp._st2_artik()
WHERE kod = 'artik';
\endif

\echo '=== ÖZET ==='
SELECT kod, deger, etiket FROM _stat_durum ORDER BY kod;
SELECT 'TOPLAM: PASS=' || count(*) FILTER (WHERE deger = 'PASS') || ' FAIL=' || count(*) FILTER (WHERE deger = 'FAIL')
       || ' UNMEASURED=' || count(*) FILTER (WHERE deger = 'UNMEASURED') AS ozet FROM _stat_durum;
