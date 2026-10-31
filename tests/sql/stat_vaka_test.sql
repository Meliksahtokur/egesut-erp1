-- tests/sql/stat_vaka_test.sql
-- İstatistik F0 / P3 (T3) — v_stat_vaka sonuç kuralı testleri (spec §5.2, K7-K9; plan Review Focus 1-4).
--
-- HEDEF: YALNIZ demo (ref vtzqjmazsvurxdeondmi). Yazmalar E2E-STAT- önekli kendi fixture'larıyla
-- sınırlıdır; gerçek cases/treatment_days/drug_administrations satırlarına dokunulmaz (domain-rules §13.9).
-- KOŞUM:
--   psql "$OVS_DEMO_DB_URL" -X -v ON_ERROR_STOP=0 -v stat_fixture_ok=true -f tests/sql/stat_vaka_test.sql
--   (stat_fixture_ok verilmemiş/false → fixture yazılmaz, 10 kod UNMEASURED kalır.)
-- SONUÇ: _stat_durum(kod, deger, etiket) — deger PASS / FAIL / UNMEASURED; kod başına bir satır,
-- bir kod = o vakanın tüm beklentileri (preflight R7).
-- TEMİZLİK: başta ve sonda pg_temp._stat_temizle() (FK sırası: drug_administrations → treatment_days →
-- cases → hayvanlar (pedigree_nodes/gorev_log CASCADE) → drug_products → drug_classes → diseases → stok).
-- degisim_log / islem_log iz satırları kalır (R21, ovsync_takip_test kalıbı).
--
-- FIXTURE (T5/T6 kopyalar). T = bugün = (now() AT TIME ZONE 'Europe/Istanbul')::date; CURRENT_DATE yok.
-- Hastalık E2E-STAT-Mastit (Meme). Sınıflar: K1 group 'E2E-STAT' class 'E2E-STAT-K1'; K2 group 'E2E-STAT'
-- class NULL. Ürünler: E2E-STAT-A (K1), E2E-STAT-B (K2). Stok E2E-STAT-S1 maliyet 10.
-- closed_at = (tarih + 12:00) TR; yalnız iyilesti_temiz 01:30 TR (UTC'de bir gün önce → R4 TZ sınaması).
--
-- kod            hayvan       durum   başlangıç kapanış  tedavi günleri (uygulama)                 çıkış          beklenen sonuc / olay_gun
-- iyilesti_temiz E2E-STAT-01  closed  T-100     T-96     T-100 A 2 + (S1 5 uygulanmadi=true),       —              iyilesti / 4; tedavi 3, uyum 1.000,
--                                                        T-99 A 3 stok S1, T-98 B 1 (uygulanmadi NULL)               maliyet 30.00
-- oldu_10gun     E2E-STAT-02  closed  T-80      T-75     T-80 A, T-79 A                             olum T-65      oldu_kesildi / 15
-- kesim_aktif    E2E-STAT-03  active  T-40      —        T-40 A                                     kesim T-30     oldu_kesildi / 10
-- nuks_20gun     E2E-STAT-04  closed  T-120     T-115    T-120 A                                    —              nuks / 25
--  (nuks_takip)  E2E-STAT-04  closed  T-95      T-90     T-95 B                                     —              iyilesti / 5
-- satis_iyilesti E2E-STAT-05  closed  T-60      T-57     T-60 A                                     satis T-52     iyilesti / 3
-- devam_eski     E2E-STAT-06  active  T-730     —        T-730 A                                    —              devam / 730, sansur
-- ilacsiz        E2E-STAT-07  closed  T-50      T-45     T-50 A uygulanmadi, T-49 A+S1 uygulanmadi  —              iyilesti / 5; uyum NULL, protokol {}
-- ters_tarih     E2E-STAT-08  closed  T-30      T-32     T-30 A                                     —              iyilesti / NULL (süre NULL)
-- Mastit dağılımı (9 vaka): iyilesti 5, oldu_kesildi 2, nuks 1, devam 1 (preflight R6).
-- T3b eki (S3, R31): protokol vakaları view'da YOK → protokol_disi. 0a E2E-STAT-04 Mastit protocol_family
-- 'OVSYNC' active T-80 (09'un kapanış+10'u: dışlanmasaydı 09 nuks olurdu); 0b E2E-STAT-07 E2E-STAT-Ovsync
-- (Üreme, protocol_family NULL → ad kolu) closed T-40→T-30.

\if :{?stat_fixture_ok}
\else
\set stat_fixture_ok false
\endif
\echo '=== v_stat_vaka testi ===' stat_fixture_ok= :stat_fixture_ok

DROP TABLE IF EXISTS _stat_durum;
CREATE TEMP TABLE _stat_durum(kod text PRIMARY KEY, deger text, etiket text);
INSERT INTO _stat_durum(kod, deger, etiket) VALUES
  ('iyilesti_temiz', 'UNMEASURED', 'closed, 3 uygulama günü'),
  ('oldu_10gun',     'UNMEASURED', 'ölüm kapanış+10'),
  ('kesim_aktif',    'UNMEASURED', 'aktifken kesim'),
  ('nuks_20gun',     'UNMEASURED', 'aynı hastalık kapanış+20'),
  ('satis_iyilesti', 'UNMEASURED', 'RF2 satış ölüm değil'),
  ('devam_eski',     'UNMEASURED', 'RF1 730 gün açık'),
  ('ilacsiz',        'UNMEASURED', 'RF3 hiç uygulama yok'),
  ('ters_tarih',     'UNMEASURED', 'RF4 kapanış < başlangıç'),
  ('rol_invoker',    'UNMEASURED', 'R7 authenticated görünürlüğü'),
  ('protokol_disi',  'UNMEASURED', 'R31 protokol vakası view dışı, nüks sayılmaz');

CREATE FUNCTION pg_temp._stat_temizle() RETURNS void LANGUAGE sql AS $f$
  DELETE FROM drug_administrations WHERE treatment_day_id IN (
    SELECT td.id FROM treatment_days td JOIN cases c ON c.id = td.case_id WHERE c.animal_id LIKE 'E2E-STAT-%');
  DELETE FROM treatment_days WHERE case_id IN (SELECT id FROM cases WHERE animal_id LIKE 'E2E-STAT-%');
  DELETE FROM cases WHERE animal_id LIKE 'E2E-STAT-%';
  DELETE FROM hayvanlar WHERE id LIKE 'E2E-STAT-%';
  DELETE FROM drug_products WHERE brand_name LIKE 'E2E-STAT-%';
  DELETE FROM drug_classes WHERE group_name = 'E2E-STAT';
  DELETE FROM diseases WHERE name LIKE 'E2E-STAT-%';
  DELETE FROM stok WHERE id LIKE 'E2E-STAT-%';
$f$;

\if :stat_fixture_ok
SELECT pg_temp._stat_temizle();
SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date AS t \gset
\echo 'bugün (TR) = ' :t

BEGIN;
INSERT INTO diseases(id, name, category) VALUES ('e2e5a7c0-0000-4000-8000-000000000001', 'E2E-STAT-Mastit', 'Meme'),
  ('e2e5a7c0-0000-4000-8000-000000000003', 'E2E-STAT-Ovsync', 'Üreme');
INSERT INTO drug_classes(id, group_name, class_name, etken_kod) VALUES
  ('e2e5a7c0-0000-4000-8000-000000000011', 'E2E-STAT', 'E2E-STAT-K1', NULL),
  ('e2e5a7c0-0000-4000-8000-000000000012', 'E2E-STAT', NULL, NULL);
INSERT INTO drug_products(id, drug_class_id, brand_name) VALUES
  ('e2e5a7c0-0000-4000-8000-000000000021', 'e2e5a7c0-0000-4000-8000-000000000011', 'E2E-STAT-A'),
  ('e2e5a7c0-0000-4000-8000-000000000022', 'e2e5a7c0-0000-4000-8000-000000000012', 'E2E-STAT-B');
INSERT INTO stok(id, urun_adi, birim, maliyet) VALUES ('E2E-STAT-S1', 'E2E-STAT-Stok1', 'ml', 10);

INSERT INTO hayvanlar(id, kupe_no, cinsiyet, dogum_tarihi, grup, cikis_tipi, cikis_tarihi)
SELECT 'E2E-STAT-0'||n, 'E2E-STAT-0'||n, 'Dişi', :'t'::date - 1500, 'Sağmal (Laktasyonda)', ct, :'t'::date - cg
FROM (VALUES (1,NULL,NULL),(2,'olum',65),(3,'kesim',30),(4,NULL,NULL),(5,'satis',52),(6,NULL,NULL),(7,NULL,NULL),(8,NULL,NULL))
  AS x(n, ct, cg);

-- vakalar: (uuid sonu, hayvan no, durum, başlangıç T-, kapanış T-, kapanış saati TR)
INSERT INTO cases(id, animal_id, disease_id, start_date, status, closed_at)
SELECT ('e2e5a7a0-0000-4000-8000-0000000000'||k)::uuid, 'E2E-STAT-0'||n, 'e2e5a7c0-0000-4000-8000-000000000001',
       :'t'::date - b, s,
       CASE WHEN kp IS NOT NULL THEN ((:'t'::date - kp) + saat) AT TIME ZONE 'Europe/Istanbul' END
FROM (VALUES ('01',1,'closed',100,96,time '01:30'), ('02',2,'closed',80,75,time '12:00'),
             ('03',3,'active',40,NULL,NULL),         ('04',4,'closed',120,115,time '12:00'),
             ('09',4,'closed',95,90,time '12:00'),   ('05',5,'closed',60,57,time '12:00'),
             ('06',6,'active',730,NULL,NULL),        ('07',7,'closed',50,45,time '12:00'),
             ('08',8,'closed',30,32,time '12:00')) AS x(k, n, s, b, kp, saat);
-- T3b protokol vakaları (trigger kapıları: açık TAKIP_MUAYENE yok, kısır değil → geçer)
INSERT INTO cases(id, animal_id, disease_id, start_date, status, closed_at, protocol_family) VALUES
  ('e2e5a7a0-0000-4000-8000-00000000000a', 'E2E-STAT-04', 'e2e5a7c0-0000-4000-8000-000000000001',
   :'t'::date - 80, 'active', NULL, 'OVSYNC'),
  ('e2e5a7a0-0000-4000-8000-00000000000b', 'E2E-STAT-07', 'e2e5a7c0-0000-4000-8000-000000000003',
   :'t'::date - 40, 'closed', ((:'t'::date - 30) + time '12:00') AT TIME ZONE 'Europe/Istanbul', NULL);

-- tedavi günleri: (uuid sonu, vaka uuid sonu, T-)
INSERT INTO treatment_days(id, case_id, treatment_date)
SELECT ('e2e5a7d0-0000-4000-8000-0000000000'||d)::uuid, ('e2e5a7a0-0000-4000-8000-0000000000'||k)::uuid, :'t'::date - g
FROM (VALUES ('11','01',100),('12','01',99),('13','01',98),('21','02',80),('22','02',79),('31','03',40),
             ('41','04',120),('91','09',95),('51','05',60),('61','06',730),('71','07',50),('72','07',49),
             ('81','08',30)) AS x(d, k, g);

-- uygulamalar: (gün uuid sonu, ürün A/B, stok, doz, uygulanmadi)
INSERT INTO drug_administrations(treatment_day_id, drug_product_id, stok_id, dose, unit, uygulanmadi)
SELECT ('e2e5a7d0-0000-4000-8000-0000000000'||d)::uuid,
       CASE p WHEN 'A' THEN 'e2e5a7c0-0000-4000-8000-000000000021'::uuid
              WHEN 'B' THEN 'e2e5a7c0-0000-4000-8000-000000000022'::uuid END,
       st, dz, 'ml', u
FROM (VALUES ('11','A',NULL,2,false),('11','B','E2E-STAT-S1',5,true),('12','A','E2E-STAT-S1',3,false),
             ('13','B',NULL,1,NULL),('21','A',NULL,2,false),('22','A',NULL,2,false),('31','A',NULL,2,false),
             ('41','A',NULL,2,false),('91','B',NULL,2,false),('51','A',NULL,2,false),('61','A',NULL,2,false),
             ('71','A',NULL,2,true),('72','A','E2E-STAT-S1',4,true),('81','A',NULL,2,false))
  AS x(d, p, st, dz, u);
COMMIT;

-- postgres rolünde view görüntüsü (kırmızıda: relation "v_stat_vaka" does not exist)
DROP TABLE IF EXISTS _stat_v;
CREATE TEMP TABLE _stat_v AS
SELECT v.*, row_number() OVER (PARTITION BY v.hayvan_id ORDER BY v.baslangic) AS sira
FROM v_stat_vaka v WHERE v.hastalik = 'E2E-STAT-Mastit';
\echo '--- fixture satırları ---'
SELECT hayvan_id, sira, sonuc, baslangic, kapanis, vaka_suresi_gun AS vs, ilk_uygulama AS ilk, son_uygulama AS son,
       tedavi_suresi_gun AS ts, uygulanan_gun AS ug, plan_gun AS pg, protokol_uyum AS uyum, protokol, protokol_sinif,
       olay_gun, sansur, maliyet_tl
FROM _stat_v ORDER BY hayvan_id, sira;

-- kod başına değerlendirme: ok = tek satır + tüm beklentiler
CREATE FUNCTION pg_temp._stat_say(p_kod text, p_hayvan text, p_sira int, p_ok boolean) RETURNS void
LANGUAGE sql AS $f$
  UPDATE _stat_durum d
     SET deger = CASE WHEN coalesce(p_ok, false) THEN 'PASS' ELSE 'FAIL' END,
         etiket = coalesce((SELECT 'sonuc='||coalesce(v.sonuc,'∅')||' olay='||coalesce(v.olay_gun::text,'∅')
                                   ||' sansur='||coalesce(v.sansur::text,'∅')
                              FROM _stat_v v WHERE v.hayvan_id = p_hayvan AND v.sira = p_sira), 'satır yok')
   WHERE d.kod = p_kod;
$f$;

SELECT pg_temp._stat_say('iyilesti_temiz', 'E2E-STAT-01', 1, (
  SELECT count(*) = 1 AND bool_and(
    sonuc = 'iyilesti' AND kapanis = :'t'::date - 96 AND vaka_suresi_gun = 4
    AND ilk_uygulama = :'t'::date - 100 AND son_uygulama = :'t'::date - 98 AND tedavi_suresi_gun = 3
    AND uygulanan_gun = 3 AND plan_gun = 3 AND protokol_uyum = 1.000
    AND protokol = ARRAY['E2E-STAT-A','E2E-STAT-B'] AND protokol_sinif = ARRAY['E2E-STAT','E2E-STAT-K1']
    AND olay_gun = vaka_suresi_gun AND sansur = false AND maliyet_tl = 30.00
    AND kategori = 'Meme' AND baslangic = :'t'::date - 100)
  FROM _stat_v WHERE hayvan_id = 'E2E-STAT-01'));

SELECT pg_temp._stat_say('oldu_10gun', 'E2E-STAT-02', 1, (
  SELECT count(*) = 1 AND bool_and(sonuc = 'oldu_kesildi' AND olay_gun = 15 AND sansur = false
    AND kapanis = :'t'::date - 75 AND vaka_suresi_gun = 5 AND tedavi_suresi_gun = 2 AND maliyet_tl IS NULL)
  FROM _stat_v WHERE hayvan_id = 'E2E-STAT-02'));

SELECT pg_temp._stat_say('kesim_aktif', 'E2E-STAT-03', 1, (
  SELECT count(*) = 1 AND bool_and(sonuc = 'oldu_kesildi' AND olay_gun = 10 AND sansur = false
    AND kapanis IS NULL AND vaka_suresi_gun IS NULL)
  FROM _stat_v WHERE hayvan_id = 'E2E-STAT-03'));

SELECT pg_temp._stat_say('nuks_20gun', 'E2E-STAT-04', 1, (
  SELECT count(*) = 2
     AND bool_and(CASE sira WHEN 1 THEN sonuc = 'nuks' AND olay_gun = 25 AND sansur = false AND vaka_suresi_gun = 5
                            WHEN 2 THEN sonuc = 'iyilesti' AND olay_gun = 5 AND baslangic = :'t'::date - 95
                                        AND protokol = ARRAY['E2E-STAT-B'] AND protokol_sinif = ARRAY['E2E-STAT'] END)
  FROM _stat_v WHERE hayvan_id = 'E2E-STAT-04'));

SELECT pg_temp._stat_say('satis_iyilesti', 'E2E-STAT-05', 1, (
  SELECT count(*) = 1 AND bool_and(sonuc = 'iyilesti' AND olay_gun = 3 AND sansur = false)
  FROM _stat_v WHERE hayvan_id = 'E2E-STAT-05'));

SELECT pg_temp._stat_say('devam_eski', 'E2E-STAT-06', 1, (
  SELECT count(*) = 1 AND bool_and(sonuc = 'devam' AND sansur = true AND olay_gun = 730
    AND kapanis IS NULL AND vaka_suresi_gun IS NULL)
  FROM _stat_v WHERE hayvan_id = 'E2E-STAT-06'));

SELECT pg_temp._stat_say('ilacsiz', 'E2E-STAT-07', 1, (
  SELECT count(*) = 1 AND bool_and(sonuc = 'iyilesti' AND olay_gun = 5 AND ilk_uygulama IS NULL
    AND son_uygulama IS NULL AND tedavi_suresi_gun IS NULL AND uygulanan_gun = 0 AND plan_gun = 2
    AND protokol_uyum IS NULL AND protokol = '{}'::text[] AND protokol_sinif = '{}'::text[]
    AND maliyet_tl IS NULL)
  FROM _stat_v WHERE hayvan_id = 'E2E-STAT-07'));

SELECT pg_temp._stat_say('ters_tarih', 'E2E-STAT-08', 1, (
  SELECT count(*) = 1 AND bool_and(sonuc = 'iyilesti' AND kapanis = :'t'::date - 32
    AND vaka_suresi_gun IS NULL AND olay_gun IS NULL AND sansur = false)
  FROM _stat_v WHERE hayvan_id = 'E2E-STAT-08'));

-- R7: aynı satırlar authenticated rolünde (SECURITY INVOKER + RLS) birebir görünmeli
SELECT count(*) AS pg_n,
       string_agg(hayvan_id||':'||sonuc||':'||coalesce(olay_gun::text,'-')||':'||coalesce(maliyet_tl::text,'-')
                  ||':'||array_to_string(protokol,'+')||':'||array_to_string(protokol_sinif,'+'),
                  ',' ORDER BY hayvan_id, baslangic) AS pg_iz
FROM _stat_v \gset
BEGIN;
SET LOCAL ROLE authenticated;
SELECT count(*) AS au_n,
       string_agg(hayvan_id||':'||sonuc||':'||coalesce(olay_gun::text,'-')||':'||coalesce(maliyet_tl::text,'-')
                  ||':'||array_to_string(protokol,'+')||':'||array_to_string(protokol_sinif,'+'),
                  ',' ORDER BY hayvan_id, baslangic) AS au_iz
FROM v_stat_vaka WHERE hastalik = 'E2E-STAT-Mastit' \gset
ROLLBACK;
\if :{?au_iz}
UPDATE _stat_durum SET deger = CASE WHEN :'pg_n'::int = 9 AND :'au_n'::int = 9 AND :'pg_iz' = :'au_iz'
                                    THEN 'PASS' ELSE 'FAIL' END,
       etiket = 'postgres n='||:'pg_n'||' authenticated n='||:'au_n'
WHERE kod = 'rol_invoker';
\else
UPDATE _stat_durum SET deger = 'FAIL', etiket = 'authenticated sorgusu hata verdi' WHERE kod = 'rol_invoker';
\endif

-- R31: iki dal (protocol_family / hastalık adı) view dışında; 0a 09'u nüks yapmaz; COMMENT + ACL
UPDATE _stat_durum SET
  deger = CASE WHEN (SELECT count(*) FROM v_stat_vaka WHERE vaka_id IN ('e2e5a7a0-0000-4000-8000-00000000000a',
                                                                       'e2e5a7a0-0000-4000-8000-00000000000b')) = 0
                AND (SELECT sonuc FROM v_stat_vaka WHERE vaka_id = 'e2e5a7a0-0000-4000-8000-000000000009') = 'iyilesti'
                AND obj_description('public.v_stat_vaka'::regclass, 'pg_class') LIKE '%Üreme protokolü%dışlanır%'
                AND NOT has_table_privilege('anon', 'public.v_stat_vaka', 'SELECT')
                AND has_table_privilege('authenticated', 'public.v_stat_vaka', 'SELECT')
               THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'protokol satırı='||(SELECT count(*) FROM v_stat_vaka WHERE hayvan_id IN ('E2E-STAT-04', 'E2E-STAT-07')
                                  AND (protokol_ailesi IS NOT NULL OR hastalik = 'E2E-STAT-Ovsync'))
           ||' 09='||coalesce((SELECT sonuc FROM v_stat_vaka WHERE vaka_id = 'e2e5a7a0-0000-4000-8000-000000000009'), '∅')
WHERE kod = 'protokol_disi';

SELECT pg_temp._stat_temizle();
\endif

\echo '=== ÖZET ==='
SELECT kod, deger, etiket FROM _stat_durum ORDER BY kod;
SELECT 'TOPLAM: PASS='||count(*) FILTER (WHERE deger = 'PASS')||' FAIL='||count(*) FILTER (WHERE deger = 'FAIL')
       ||' UNMEASURED='||count(*) FILTER (WHERE deger = 'UNMEASURED') AS ozet FROM _stat_durum;

--- ORNEKLEME (F0 kabul, plan T4): deterministik 10 kapalı vaka + ham tablo kanıtı; stat_fixture_ok'tan bağımsız, salt-okuma.
\echo '--- ORNEKLEME'
SELECT left(v.vaka_id::text, 8) AS vaka, v.hayvan_id, v.hastalik, v.baslangic, v.kapanis, v.sonuc, v.olay_gun, v.protokol
FROM v_stat_vaka v WHERE v.kapanis IS NOT NULL ORDER BY md5(v.vaka_id::text) LIMIT 10;
\echo '--- ORNEKLEME KANIT (ham: cases, hayvanlar)'
SELECT left(v.vaka_id::text, 8) AS vaka, v.sonuc AS view_sonuc, c.status, c.closed_at, v.kapanis,
       h.cikis_tipi, h.cikis_tarihi,
       (SELECT min(n.start_date) FROM cases n
         WHERE n.animal_id = c.animal_id AND n.disease_id = c.disease_id AND n.id <> c.id
           AND n.start_date > v.kapanis) AS sonraki_ayni_hastalik_start,
       (SELECT min(n.start_date) FROM cases n
         WHERE n.animal_id = c.animal_id AND n.disease_id = c.disease_id AND n.id <> c.id
           AND n.start_date > v.kapanis) - v.kapanis AS sonraki_fark_gun
FROM (SELECT * FROM v_stat_vaka WHERE kapanis IS NOT NULL ORDER BY md5(vaka_id::text) LIMIT 10) v
JOIN cases c ON c.id = v.vaka_id LEFT JOIN hayvanlar h ON h.id = c.animal_id
ORDER BY md5(v.vaka_id::text);
