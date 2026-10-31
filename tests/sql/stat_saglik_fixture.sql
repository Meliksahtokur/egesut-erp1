-- tests/sql/stat_saglik_fixture.sql
-- İstatistik Atölyesi AP1 — ortak sağlık fixture'ı (plan Task 3 tablosu + root ruling 2026-10-17 T1(e)=C).
-- HEDEF: YALNIZ demo (ref vtzqjmazsvurxdeondmi). Tüm yazmalar E2E-ST2- önekli doğal anahtarlı ya da
-- e2e5720N- önekli sabit uuid'li satırlardır; gerçek veriye dokunulmaz (domain-rules §13.9).
-- KULLANIM: test dosyası `\if :stat_fixture_ok` içinde `\ir stat_saglik_fixture.sql` ile alır; fixture
--   (1) pg_temp._st2_temizle() / pg_temp._st2_artik() tanımlar, (2) önce temizler, (3) :t = bugün (TR) gset,
--   (4) satırları tek transaction'da yazar, (5) _st2_vaka(kod → vaka_id, hayvan_id) geçici tablosunu bırakır.
--   Sondaki temizlik test dosyasının işidir (pg_temp._st2_temizle(); ardından _st2_artik() = 0).
-- T = (now() AT TIME ZONE 'Europe/Istanbul')::date (stat_bugun() ile aynı ifade; test ayrıca eşitliği sınar).
-- closed_at = (gün + 12:00) Europe/Istanbul, aksi yazılmadıkça.
--
-- Katalog: hastalık E2E-ST2-Enterit (kat E2E-ST2-Kat), E2E-ST2-Pnomoni (kat NULL), E2E-ST2-Inaktif (kat E2E-ST2-Kat;
--   E2E-ST2-OVSYNC şablonu protokol_ailesi='OVSYNC' + sablon_hastalik_eslem). E2E-ST2-Sablon = protokol_ailesi NULL.
--   Sınıf KA (etken E2E-ETK-A, class E2E-SINIF-1, group E2E-ST2-GRUP-1), KB (etken E2E-ETK-B, class NULL, group E2E-GRUP-2).
--   Ürün PA (E2E-PREP-A, KA), PB (E2E-PREP-B, KB). Stok SA (PA ml 0), SB (PB ml 0), SK (PB ml 20) — PB iki stoklu.
--   SAPMA (assumption): plan PX'i (brand NULL, sınıfsız) istiyor; drug_products.brand_name ve drug_class_id NOT NULL
--   (demo kataloğu, MEASURED) → `bilinmiyor` vakası ürünsüz + stoksuz uygulamayla kurulur (üç düzey de çözülemez).
--
-- kod              hayvan  hastalık  durum   bas    kap             uygulamalar                 çıkış        beklenen
-- normal           01      Enterit   closed  T-100  T-95            T-100 A10 SA; T-99 A10 SA;   —            basarili/5; tedavi 3; tl(SA=2,SB=10)=90
--                                                                   T-98 B5 SB
-- olum_30          02      Enterit   closed  T-80   T-76            T-80 A10 SA                  olum T-46    basarisiz_olum_kesim/4
-- kesim_31         03      Enterit   closed  T-90   T-88            T-90 A10 SA                  kesim T-57   basarili/2
-- satis            04      Enterit   closed  T-70   T-67            T-70 A10 SA                  satis T-60   basarili/3
-- nuks_30          05      Enterit   closed  T-120  T-115           T-120 A10 SA                 —            basarisiz_nuks/5
-- nuks_30_b        05      Enterit   closed  T-85   T-80            T-85 B5 SB                   —            basarili/5
-- nuks_31          06      Enterit   closed  T-150  T-145           T-150 A10 SA                 —            basarili/5
-- nuks_31_b        06      Enterit   closed  T-114  T-110           T-114 A10 SA                 —            basarili/4
-- olgun_degil      07      Enterit   closed  T-20   T-10            T-20 A10 SA                  —            olgunlasmamis/10
-- olgun_sinir      08      Enterit   closed  T-33   T-30            T-33 A10 SA                  —            basarili/3
-- aktif_olum       09      Enterit   active  T-40   —               T-40 A10 SA                  olum T-30    sonuclandi basarisiz_olum_kesim/NULL
-- aktif_acik       10      Enterit   active  T-30   —               T-30 A10 SA                  —            acik NULL/NULL
-- toplu_1          11      Enterit   closed  T-70   T-50 15:00 ort  T-70,T-69,T-68 A10 SA        —            basarili/LEAST(2+G,20) vekil
-- toplu_2          12      Enterit   closed  T-65   T-50 15:00 ort  T-65 A10 SA                  —            basarili/LEAST(G,15) vekil
-- toplu_bos        13      Enterit   closed  T-60   T-50 15:00 ort  yok                          —            basarili/NULL vekil=f toplu=t
-- ovsync           14      Enterit   active  T-40   —   (protocol_family OVSYNC)  T-40 A10 SA    —            view'da YOK
-- fallback         15      Enterit   closed  T-55   T-51 09:00      T-55 ürün NULL, SB 5 ml      —            basarili/4; etken B, prep B, sinif GRUP-2
-- uyusmaz          16      Enterit   closed  T-58   T-54            T-58 A 2 gr SA               —            basarili/4; tl NULL
-- stoksuz_tekil    17      Enterit   closed  T-62   T-59            T-62 A 4 ml stok NULL        —            kalem SA (tekil)
-- stoksuz_coklu    18      Pnomoni   closed  T-62   T-59            T-62 B 4 ml stok NULL        —            kalem stoksuz; Kategorisiz
-- bilinmiyor       19      Pnomoni   closed  T-45   T-41            T-45 ürün NULL stok NULL 3ml —            üç düzey (bilinmiyor)
-- tz_gece          20      Pnomoni   closed  T-35   T-31 01:30 TR   T-35 A10 SA                  —            kapanis T-31 (UTC T-32), basarili/4
-- ovsync_log       21      Enterit   closed  T-60   T-55            T-60 A10 SA                  —            YOK (log: OVSYNC şablonu, iptal=false)
-- ovsync_sablon    22      Inaktif   closed  T-50   T-45            T-50 A10 SA                  —            YOK (şablon-eşlem kolu)
-- tz_olgun         23      Pnomoni   closed  T-33   T-29 01:30 TR   T-33 A10 SA                  —            olgunlasmamis/4 (UTC'yle basarili olurdu)
-- log_iptal_tedavi 24      Enterit   closed  T-48   T-44            T-48 A10 SA                  —            VAR basarili/4 (log: NULL ailesi şablonu, iptal=true)
-- log_ovsync_aktif 25      Enterit   active  T-25   —               T-25 A10 SA                  —            YOK (log: OVSYNC şablonu, iptal=false)
-- kapali_tarihsiz  26      Enterit   closed  T-40   NULL (closed_at) T-40 A10 SA                 —            kapali_tarihsiz NULL/NULL (tur1+tur2: kapanış günü yok → sonuçsuz)
-- plan_eksik       27      Enterit   closed  T-75   T-70            T-75 A10 SA; T-74 A10 SA      —            basarili/5; plan 3, uyg 1, uyum 0.333, ts 1
--                                                                   uygulanmadi; T-73 ilaçsız gün

CREATE OR REPLACE FUNCTION pg_temp._st2_temizle() RETURNS void LANGUAGE sql AS $f$
  DELETE FROM gorev_log WHERE hayvan_id LIKE 'E2E-ST2-%';
  DELETE FROM drug_administrations WHERE treatment_day_id IN (
    SELECT td.id FROM treatment_days td JOIN cases c ON c.id = td.case_id WHERE c.animal_id LIKE 'E2E-ST2-%');
  DELETE FROM treatment_days WHERE case_id IN (SELECT id FROM cases WHERE animal_id LIKE 'E2E-ST2-%');
  DELETE FROM cases WHERE animal_id LIKE 'E2E-ST2-%';
  DELETE FROM hayvanlar WHERE id LIKE 'E2E-ST2-%';
  DELETE FROM stok WHERE id LIKE 'E2E-ST2-%';
  DELETE FROM drug_products WHERE id::text LIKE 'e2e57203-%';
  DELETE FROM drug_classes WHERE id::text LIKE 'e2e57202-%';
  DELETE FROM tedavi_sablonu WHERE ad LIKE 'E2E-ST2-%';
  DELETE FROM diseases WHERE name LIKE 'E2E-ST2-%';
$f$;

CREATE OR REPLACE FUNCTION pg_temp._st2_artik() RETURNS int LANGUAGE sql AS $f$
  SELECT ((SELECT count(*) FROM gorev_log WHERE hayvan_id LIKE 'E2E-ST2-%')
        + (SELECT count(*) FROM cases WHERE animal_id LIKE 'E2E-ST2-%')
        + (SELECT count(*) FROM hayvanlar WHERE id LIKE 'E2E-ST2-%')
        + (SELECT count(*) FROM stok WHERE id LIKE 'E2E-ST2-%')
        + (SELECT count(*) FROM drug_products WHERE id::text LIKE 'e2e57203-%')
        + (SELECT count(*) FROM drug_classes WHERE id::text LIKE 'e2e57202-%')
        + (SELECT count(*) FROM tedavi_sablonu WHERE ad LIKE 'E2E-ST2-%')
        + (SELECT count(*) FROM sablon_hastalik_eslem WHERE sablon_id::text LIKE 'e2e57204-%')
        + (SELECT count(*) FROM diseases WHERE name LIKE 'E2E-ST2-%'))::int;
$f$;

SELECT pg_temp._st2_temizle();
SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date AS t \gset
\echo 'fixture bugün (TR) = ' :t

DROP TABLE IF EXISTS _st2_vaka;
CREATE TEMP TABLE _st2_vaka(kod text PRIMARY KEY, vaka_id uuid UNIQUE, hayvan_id text, hst int, durum text,
                            bas int, kap int, saat time, pf text);
INSERT INTO _st2_vaka(kod, vaka_id, hayvan_id, hst, durum, bas, kap, saat, pf)
SELECT kod, ('e2e57205-0000-4000-8000-0000000000' || sfx)::uuid, 'E2E-ST2-' || hy, hst, durum, bas, kap, saat::time, pf
FROM (VALUES
  ('normal',           '01', '01', 1, 'closed', 100,   95, '12:00', NULL),
  ('olum_30',          '02', '02', 1, 'closed',  80,   76, '12:00', NULL),
  ('kesim_31',         '03', '03', 1, 'closed',  90,   88, '12:00', NULL),
  ('satis',            '04', '04', 1, 'closed',  70,   67, '12:00', NULL),
  ('nuks_30',          '05', '05', 1, 'closed', 120,  115, '12:00', NULL),
  ('nuks_30_b',        '55', '05', 1, 'closed',  85,   80, '12:00', NULL),
  ('nuks_31',          '06', '06', 1, 'closed', 150,  145, '12:00', NULL),
  ('nuks_31_b',        '56', '06', 1, 'closed', 114,  110, '12:00', NULL),
  ('olgun_degil',      '07', '07', 1, 'closed',  20,   10, '12:00', NULL),
  ('olgun_sinir',      '08', '08', 1, 'closed',  33,   30, '12:00', NULL),
  ('aktif_olum',       '09', '09', 1, 'active',  40, NULL, NULL,    NULL),
  ('aktif_acik',       '10', '10', 1, 'active',  30, NULL, NULL,    NULL),
  ('toplu_1',          '11', '11', 1, 'closed',  70,   50, '15:00', NULL),
  ('toplu_2',          '12', '12', 1, 'closed',  65,   50, '15:00', NULL),
  ('toplu_bos',        '13', '13', 1, 'closed',  60,   50, '15:00', NULL),
  ('ovsync',           '14', '14', 1, 'active',  40, NULL, NULL,    'OVSYNC'),
  ('fallback',         '15', '15', 1, 'closed',  55,   51, '09:00', NULL),
  ('uyusmaz',          '16', '16', 1, 'closed',  58,   54, '12:00', NULL),
  ('stoksuz_tekil',    '17', '17', 1, 'closed',  62,   59, '12:00', NULL),
  ('stoksuz_coklu',    '18', '18', 2, 'closed',  62,   59, '12:00', NULL),
  ('bilinmiyor',       '19', '19', 2, 'closed',  45,   41, '12:00', NULL),
  ('tz_gece',          '20', '20', 2, 'closed',  35,   31, '01:30', NULL),
  ('ovsync_log',       '21', '21', 1, 'closed',  60,   55, '12:00', NULL),
  ('ovsync_sablon',    '22', '22', 3, 'closed',  50,   45, '12:00', NULL),
  ('tz_olgun',         '23', '23', 2, 'closed',  33,   29, '01:30', NULL),
  ('log_iptal_tedavi', '24', '24', 1, 'closed',  48,   44, '12:00', NULL),
  ('log_ovsync_aktif', '25', '25', 1, 'active',  25, NULL, NULL,    NULL),
  ('kapali_tarihsiz',  '26', '26', 1, 'closed',  40, NULL, NULL,    NULL),
  ('plan_eksik',       '27', '27', 1, 'closed',  75,   70, '12:00', NULL)
) AS x(kod, sfx, hy, hst, durum, bas, kap, saat, pf);

BEGIN;
INSERT INTO diseases(id, name, category) VALUES
  ('e2e57201-0000-4000-8000-000000000001', 'E2E-ST2-Enterit', 'E2E-ST2-Kat'),
  ('e2e57201-0000-4000-8000-000000000002', 'E2E-ST2-Pnomoni', NULL),
  ('e2e57201-0000-4000-8000-000000000003', 'E2E-ST2-Inaktif', 'E2E-ST2-Kat');
INSERT INTO drug_classes(id, group_name, class_name, active_ingredient) VALUES
  ('e2e57202-0000-4000-8000-000000000001', 'E2E-ST2-GRUP-1', 'E2E-SINIF-1', 'E2E-ETK-A'),
  ('e2e57202-0000-4000-8000-000000000002', 'E2E-GRUP-2', NULL, 'E2E-ETK-B');
INSERT INTO drug_products(id, drug_class_id, brand_name) VALUES
  ('e2e57203-0000-4000-8000-000000000001', 'e2e57202-0000-4000-8000-000000000001', 'E2E-PREP-A'),
  ('e2e57203-0000-4000-8000-000000000002', 'e2e57202-0000-4000-8000-000000000002', 'E2E-PREP-B');
INSERT INTO stok(id, urun_adi, birim, maliyet, drug_product_id) VALUES
  ('E2E-ST2-SA', 'E2E-ST2-Stok-A', 'ml', 0,  'e2e57203-0000-4000-8000-000000000001'),
  ('E2E-ST2-SB', 'E2E-ST2-Stok-B', 'ml', 0,  'e2e57203-0000-4000-8000-000000000002'),
  ('E2E-ST2-SK', 'E2E-ST2-Stok-K', 'ml', 20, 'e2e57203-0000-4000-8000-000000000002');
INSERT INTO tedavi_sablonu(id, ad, protokol_ailesi, aktif) VALUES
  ('e2e57204-0000-4000-8000-000000000001', 'E2E-ST2-OVSYNC', 'OVSYNC', false),
  ('e2e57204-0000-4000-8000-000000000002', 'E2E-ST2-Sablon', NULL, false);
INSERT INTO sablon_hastalik_eslem(sablon_id, disease_id) VALUES
  ('e2e57204-0000-4000-8000-000000000001', 'e2e57201-0000-4000-8000-000000000003');

INSERT INTO hayvanlar(id, kupe_no, cinsiyet, dogum_tarihi, grup, cikis_tipi, cikis_tarihi)
SELECT DISTINCT v.hayvan_id, 'K-' || v.hayvan_id, 'Dişi', :'t'::date - 1500, 'Sağmal (Laktasyonda)', c.ct, :'t'::date - c.cg
FROM _st2_vaka v
LEFT JOIN (VALUES ('E2E-ST2-02', 'olum', 46), ('E2E-ST2-03', 'kesim', 57), ('E2E-ST2-04', 'satis', 60),
                  ('E2E-ST2-09', 'olum', 30)) AS c(hy, ct, cg) ON c.hy = v.hayvan_id;

INSERT INTO cases(id, animal_id, disease_id, start_date, status, closed_at, protocol_family)
SELECT v.vaka_id, v.hayvan_id, ('e2e57201-0000-4000-8000-00000000000' || v.hst)::uuid, :'t'::date - v.bas, v.durum,
       CASE WHEN v.kap IS NOT NULL THEN ((:'t'::date - v.kap) + v.saat) AT TIME ZONE 'Europe/Istanbul' END, v.pf
FROM _st2_vaka v;

-- uygulamalar: (kod, T-gün, ürün A/B/NULL, stok, doz, birim); her (vaka, gün) için bir tedavi günü
CREATE TEMP TABLE _st2_uyg(kod text, gun int, urun text, stok text, doz numeric, birim text,
                           uygulanmadi boolean DEFAULT false) ON COMMIT DROP;
INSERT INTO _st2_uyg(kod, gun, urun, stok, doz, birim) VALUES
  ('normal', 100, 'A', 'E2E-ST2-SA', 10, 'ml'), ('normal', 99, 'A', 'E2E-ST2-SA', 10, 'ml'),
  ('normal', 98, 'B', 'E2E-ST2-SB', 5, 'ml'),
  ('olum_30', 80, 'A', 'E2E-ST2-SA', 10, 'ml'), ('kesim_31', 90, 'A', 'E2E-ST2-SA', 10, 'ml'),
  ('satis', 70, 'A', 'E2E-ST2-SA', 10, 'ml'), ('nuks_30', 120, 'A', 'E2E-ST2-SA', 10, 'ml'),
  ('nuks_30_b', 85, 'B', 'E2E-ST2-SB', 5, 'ml'), ('nuks_31', 150, 'A', 'E2E-ST2-SA', 10, 'ml'),
  ('nuks_31_b', 114, 'A', 'E2E-ST2-SA', 10, 'ml'), ('olgun_degil', 20, 'A', 'E2E-ST2-SA', 10, 'ml'),
  ('olgun_sinir', 33, 'A', 'E2E-ST2-SA', 10, 'ml'), ('aktif_olum', 40, 'A', 'E2E-ST2-SA', 10, 'ml'),
  ('aktif_acik', 30, 'A', 'E2E-ST2-SA', 10, 'ml'),
  ('toplu_1', 70, 'A', 'E2E-ST2-SA', 10, 'ml'), ('toplu_1', 69, 'A', 'E2E-ST2-SA', 10, 'ml'),
  ('toplu_1', 68, 'A', 'E2E-ST2-SA', 10, 'ml'), ('toplu_2', 65, 'A', 'E2E-ST2-SA', 10, 'ml'),
  ('ovsync', 40, 'A', 'E2E-ST2-SA', 10, 'ml'),
  ('fallback', 55, NULL, 'E2E-ST2-SB', 5, 'ml'), ('uyusmaz', 58, 'A', 'E2E-ST2-SA', 2, 'gr'),
  ('stoksuz_tekil', 62, 'A', NULL, 4, 'ml'), ('stoksuz_coklu', 62, 'B', NULL, 4, 'ml'),
  ('bilinmiyor', 45, NULL, NULL, 3, 'ml'), ('tz_gece', 35, 'A', 'E2E-ST2-SA', 10, 'ml'),
  ('ovsync_log', 60, 'A', 'E2E-ST2-SA', 10, 'ml'), ('ovsync_sablon', 50, 'A', 'E2E-ST2-SA', 10, 'ml'),
  ('tz_olgun', 33, 'A', 'E2E-ST2-SA', 10, 'ml'), ('log_iptal_tedavi', 48, 'A', 'E2E-ST2-SA', 10, 'ml'),
  ('log_ovsync_aktif', 25, 'A', 'E2E-ST2-SA', 10, 'ml'), ('kapali_tarihsiz', 40, 'A', 'E2E-ST2-SA', 10, 'ml'),
  ('plan_eksik', 75, 'A', 'E2E-ST2-SA', 10, 'ml');
INSERT INTO _st2_uyg VALUES ('plan_eksik', 74, 'A', 'E2E-ST2-SA', 10, 'ml', true);   -- planlı ama uygulanmadı

INSERT INTO treatment_days(case_id, treatment_date)
SELECT DISTINCT v.vaka_id, :'t'::date - u.gun
FROM (SELECT kod, gun FROM _st2_uyg UNION SELECT 'plan_eksik', 73) u   -- 73: ilaçsız planlı gün
JOIN _st2_vaka v ON v.kod = u.kod;

INSERT INTO drug_administrations(treatment_day_id, drug_product_id, stok_id, dose, unit, uygulanmadi)
SELECT td.id,
       CASE u.urun WHEN 'A' THEN 'e2e57203-0000-4000-8000-000000000001'::uuid
                   WHEN 'B' THEN 'e2e57203-0000-4000-8000-000000000002'::uuid END,
       u.stok, u.doz, u.birim, u.uygulanmadi
FROM _st2_uyg u
JOIN _st2_vaka v ON v.kod = u.kod
JOIN treatment_days td ON td.case_id = v.vaka_id AND td.treatment_date = :'t'::date - u.gun;

-- şablon tohumlama logları (anahtar 'TEDAVI_SABLON_TOHUMLAMA:<case_id>:<tedavi_sablonu.id>')
INSERT INTO gorev_log(hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, iptal, kaynak)
SELECT v.hayvan_id, 'TOHUMLAMA_PLANLI', 'E2E-ST2 planlı tohumlama', :'t'::date - v.bas + 10, l.tam, l.iptal,
       'TEDAVI_SABLON_TOHUMLAMA:' || v.vaka_id::text || ':' || l.sablon
FROM (VALUES ('ovsync_log', 'e2e57204-0000-4000-8000-000000000001', true, false),
             ('log_iptal_tedavi', 'e2e57204-0000-4000-8000-000000000002', false, true),
             ('log_ovsync_aktif', 'e2e57204-0000-4000-8000-000000000001', false, false)) AS l(kod, sablon, tam, iptal)
JOIN _st2_vaka v ON v.kod = l.kod;
COMMIT;

-- ── T4 eki (plan Task 4: yalnız ekleme; yukarıdaki satırlar ve T3 beklentileri değişmez) ─────────────
-- vaka uuid öneki e2e57206- (T3 `invoker` sayımı e2e57205- önekini sayar → etkilenmez); hayvan/temizlik aynı önekle.
-- kod          hayvan  hastalık  durum   bas    kap    uygulamalar                      beklenen
-- sk_karisik   28      Enterit   closed  T-140  T-136  T-140 A10 SA; T-139 B 3 SK       basarili/4; ts 2; kalem SA10 + SK3;
--                                                                                       tl(SA=2,SB=10)=80 (SK kayıtlı 20 ₺/ml)
-- bilinmiyor_2 29      Pnomoni   closed  T-44   T-40   T-44 ürün NULL stok NULL 2 ml    basarili/4; üç düzey (bilinmiyor)
INSERT INTO _st2_vaka(kod, vaka_id, hayvan_id, hst, durum, bas, kap, saat, pf) VALUES
  ('sk_karisik',   'e2e57206-0000-4000-8000-000000000028', 'E2E-ST2-28', 1, 'closed', 140, 136, '12:00', NULL),
  ('bilinmiyor_2', 'e2e57206-0000-4000-8000-000000000029', 'E2E-ST2-29', 2, 'closed',  44,  40, '12:00', NULL);

BEGIN;
INSERT INTO hayvanlar(id, kupe_no, cinsiyet, dogum_tarihi, grup)
SELECT v.hayvan_id, 'K-' || v.hayvan_id, 'Dişi', :'t'::date - 1500, 'Sağmal (Laktasyonda)'
FROM _st2_vaka v WHERE v.kod IN ('sk_karisik', 'bilinmiyor_2');

INSERT INTO cases(id, animal_id, disease_id, start_date, status, closed_at, protocol_family)
SELECT v.vaka_id, v.hayvan_id, ('e2e57201-0000-4000-8000-00000000000' || v.hst)::uuid, :'t'::date - v.bas, v.durum,
       ((:'t'::date - v.kap) + v.saat) AT TIME ZONE 'Europe/Istanbul', v.pf
FROM _st2_vaka v WHERE v.kod IN ('sk_karisik', 'bilinmiyor_2');

CREATE TEMP TABLE _st2_uyg4(kod text, gun int, urun text, stok text, doz numeric, birim text) ON COMMIT DROP;
INSERT INTO _st2_uyg4 VALUES
  ('sk_karisik', 140, 'A', 'E2E-ST2-SA', 10, 'ml'), ('sk_karisik', 139, 'B', 'E2E-ST2-SK', 3, 'ml'),
  ('bilinmiyor_2', 44, NULL, NULL, 2, 'ml');

INSERT INTO treatment_days(case_id, treatment_date)
SELECT DISTINCT v.vaka_id, :'t'::date - u.gun FROM _st2_uyg4 u JOIN _st2_vaka v ON v.kod = u.kod;

INSERT INTO drug_administrations(treatment_day_id, drug_product_id, stok_id, dose, unit, uygulanmadi)
SELECT td.id,
       CASE u.urun WHEN 'A' THEN 'e2e57203-0000-4000-8000-000000000001'::uuid
                   WHEN 'B' THEN 'e2e57203-0000-4000-8000-000000000002'::uuid END,
       u.stok, u.doz, u.birim, false
FROM _st2_uyg4 u
JOIN _st2_vaka v ON v.kod = u.kod
JOIN treatment_days td ON td.case_id = v.vaka_id AND td.treatment_date = :'t'::date - u.gun;
COMMIT;

-- ── T5 eki (plan Task 5: yalnız ekleme; yukarıdaki satırlar, T3/T4 beklentileri değişmez) ─────────────
-- Kombinasyon paneli + seçenek sırası için ayrı hastalık E2E-ST2-Komb (kat E2E-ST2-Kat2 → C5 kategori sayımı etkilenmez).
-- Vaka uuid öneki e2e57207-; kapanış saatleri 13:01..13:12 (benzersiz → toplu değil; vekil G kâhinle ölçülür).
-- Yeni katalog: KC (etken E2E-ETK-C, class E2E-SINIF-3), KD (E2E-ETK-D, E2E-SINIF-4); PC (E2E-PREP-C), PD (E2E-PREP-D);
--   stok SC (PC ml maliyet 5 = kayıtlı), SD (PD ml maliyet 0 = fiyatsız). U = ürünsüz + stoksuz 1 ml → (bilinmiyor).
-- kod   hayvan bas    kap    uygulamalar (hepsi bas günü)  sonuc / kg        ₺ (SA=2,SB=10 geçici)
-- k01   30     T-200  T-195  A10 SA; C2 SC                basarili / 5      30
-- k02   31     T-198  T-194  A10 SA; C2 SC                basarili / 4      30
-- k03   32     T-196  T-190  A10 SA; C2 SC                basarili / 6      30
-- k04   33     T-194  T-191  A10 SA; C2 SC  (olum T-185)  basarisiz_olum_kesim / 3   30
-- k05   34     T-192  T-186  A10 SA; C2 SC; B5 SB         basarili / 6      80
-- k06   35     T-190  T-187  A10 SA; B5 SB                basarili / 3      70
-- k07   36     T-188  T-181  A10 SA; D3 SD                basarili / 7      NULL (SD fiyatsız)
-- k08   37     T-186  T-182  A10 SA; D3 SD; U             basarili / 4      NULL
-- k09   38     T-184  T-180  A10 SA; U                    basarili / 4      NULL (stoksuz)
-- k10   39     T-182  T-177  A10 SA                       basarili / 5      20
-- k11   40     T-180  —      A10 SA  (active)             acik
-- k12   41     T-178  T-174  C2 SC                        basarili / 4      10
-- k13   42     T-176  T-171  C2 SC                        basarili / 5      10
INSERT INTO _st2_vaka(kod, vaka_id, hayvan_id, hst, durum, bas, kap, saat, pf)
SELECT x.kod, ('e2e57207-0000-4000-8000-0000000000' || x.h)::uuid, 'E2E-ST2-' || x.h, 4, x.durum, x.bas, x.kap, x.saat::time, NULL
FROM (VALUES ('k01', '30', 'closed', 200, 195, '13:01'), ('k02', '31', 'closed', 198, 194, '13:02'),
             ('k03', '32', 'closed', 196, 190, '13:03'), ('k04', '33', 'closed', 194, 191, '13:04'),
             ('k05', '34', 'closed', 192, 186, '13:05'), ('k06', '35', 'closed', 190, 187, '13:06'),
             ('k07', '36', 'closed', 188, 181, '13:07'), ('k08', '37', 'closed', 186, 182, '13:08'),
             ('k09', '38', 'closed', 184, 180, '13:09'), ('k10', '39', 'closed', 182, 177, '13:10'),
             ('k11', '40', 'active', 180, NULL, NULL),   ('k12', '41', 'closed', 178, 174, '13:11'),
             ('k13', '42', 'closed', 176, 171, '13:12')) AS x(kod, h, durum, bas, kap, saat);

BEGIN;
INSERT INTO diseases(id, name, category) VALUES
  ('e2e57201-0000-4000-8000-000000000004', 'E2E-ST2-Komb', 'E2E-ST2-Kat2');
INSERT INTO drug_classes(id, group_name, class_name, active_ingredient) VALUES
  ('e2e57202-0000-4000-8000-000000000003', 'E2E-ST2-GRUP-3', 'E2E-SINIF-3', 'E2E-ETK-C'),
  ('e2e57202-0000-4000-8000-000000000004', 'E2E-ST2-GRUP-4', 'E2E-SINIF-4', 'E2E-ETK-D');
INSERT INTO drug_products(id, drug_class_id, brand_name) VALUES
  ('e2e57203-0000-4000-8000-000000000003', 'e2e57202-0000-4000-8000-000000000003', 'E2E-PREP-C'),
  ('e2e57203-0000-4000-8000-000000000004', 'e2e57202-0000-4000-8000-000000000004', 'E2E-PREP-D');
INSERT INTO stok(id, urun_adi, birim, maliyet, drug_product_id) VALUES
  ('E2E-ST2-SC', 'E2E-ST2-Stok-C', 'ml', 5, 'e2e57203-0000-4000-8000-000000000003'),
  ('E2E-ST2-SD', 'E2E-ST2-Stok-D', 'ml', 0, 'e2e57203-0000-4000-8000-000000000004');

INSERT INTO hayvanlar(id, kupe_no, cinsiyet, dogum_tarihi, grup, cikis_tipi, cikis_tarihi)
SELECT v.hayvan_id, 'K-' || v.hayvan_id, 'Dişi', :'t'::date - 1500, 'Sağmal (Laktasyonda)',
       CASE WHEN v.kod = 'k04' THEN 'olum' END, CASE WHEN v.kod = 'k04' THEN :'t'::date - 185 END
FROM _st2_vaka v WHERE v.vaka_id::text LIKE 'e2e57207-%';

INSERT INTO cases(id, animal_id, disease_id, start_date, status, closed_at, protocol_family)
SELECT v.vaka_id, v.hayvan_id, 'e2e57201-0000-4000-8000-000000000004', :'t'::date - v.bas, v.durum,
       CASE WHEN v.kap IS NOT NULL THEN ((:'t'::date - v.kap) + v.saat) AT TIME ZONE 'Europe/Istanbul' END, NULL
FROM _st2_vaka v WHERE v.vaka_id::text LIKE 'e2e57207-%';

CREATE TEMP TABLE _st2_uyg5(kod text, urun text, stok text, doz numeric) ON COMMIT DROP;
INSERT INTO _st2_uyg5 VALUES
  ('k01', 'A', 'E2E-ST2-SA', 10), ('k01', 'C', 'E2E-ST2-SC', 2), ('k02', 'A', 'E2E-ST2-SA', 10), ('k02', 'C', 'E2E-ST2-SC', 2),
  ('k03', 'A', 'E2E-ST2-SA', 10), ('k03', 'C', 'E2E-ST2-SC', 2), ('k04', 'A', 'E2E-ST2-SA', 10), ('k04', 'C', 'E2E-ST2-SC', 2),
  ('k05', 'A', 'E2E-ST2-SA', 10), ('k05', 'C', 'E2E-ST2-SC', 2), ('k05', 'B', 'E2E-ST2-SB', 5),
  ('k06', 'A', 'E2E-ST2-SA', 10), ('k06', 'B', 'E2E-ST2-SB', 5),
  ('k07', 'A', 'E2E-ST2-SA', 10), ('k07', 'D', 'E2E-ST2-SD', 3),
  ('k08', 'A', 'E2E-ST2-SA', 10), ('k08', 'D', 'E2E-ST2-SD', 3), ('k08', NULL, NULL, 1),
  ('k09', 'A', 'E2E-ST2-SA', 10), ('k09', NULL, NULL, 1),
  ('k10', 'A', 'E2E-ST2-SA', 10), ('k11', 'A', 'E2E-ST2-SA', 10),
  ('k12', 'C', 'E2E-ST2-SC', 2), ('k13', 'C', 'E2E-ST2-SC', 2);

INSERT INTO treatment_days(case_id, treatment_date)
SELECT v.vaka_id, :'t'::date - v.bas FROM _st2_vaka v WHERE v.vaka_id::text LIKE 'e2e57207-%';

INSERT INTO drug_administrations(treatment_day_id, drug_product_id, stok_id, dose, unit, uygulanmadi)
SELECT td.id, ('e2e57203-0000-4000-8000-00000000000' || CASE u.urun WHEN 'A' THEN '1' WHEN 'B' THEN '2' WHEN 'C' THEN '3'
                                                                     WHEN 'D' THEN '4' END)::uuid,
       u.stok, u.doz, 'ml', false
FROM _st2_uyg5 u
JOIN _st2_vaka v ON v.kod = u.kod
JOIN treatment_days td ON td.case_id = v.vaka_id;
COMMIT;

-- ── TK1 eki (root ruling R2, kapı F1 sonrası: yalnız ekleme; yukarıdaki satırlar ve T3/T4/T5 beklentileri değişmez) ──
-- Nüks gün 0: aynı hayvan + aynı hastalık; ilk vaka T-55'te kapanır, ikinci vaka T-55'te açılır → ilk vaka nüks.
-- Ayrı hastalık E2E-ST2-Nuks0 (kat E2E-ST2-Kat3) → Enterit/Pnomoni/Komb ve kategori sayımları etkilenmez.
-- Vaka uuid öneki e2e57208- (T3 `invoker` sayımı e2e57205- önekini sayar → etkilenmez). İki vaka da ilaçsız
--   (uygulama yok → vekil G kümesine girmez); kapanış saatleri 14:01 / 14:02 (benzersiz → toplu değil).
-- kod     hayvan  hastalık  durum   bas   kap   uygulamalar  beklenen (elle sabit)
-- n0_a    43      Nuks0     closed  T-60  T-55  yok          basarisiz_nuks (n0_b kapanış günü açıldı; `>` ile basarili olurdu)
-- n0_b    43      Nuks0     closed  T-55  T-50  yok          basarili (sonrasında vaka yok, 30 gün doldu)
INSERT INTO _st2_vaka(kod, vaka_id, hayvan_id, hst, durum, bas, kap, saat, pf) VALUES
  ('n0_a', 'e2e57208-0000-4000-8000-000000000043', 'E2E-ST2-43', 5, 'closed', 60, 55, '14:01', NULL),
  ('n0_b', 'e2e57208-0000-4000-8000-000000000044', 'E2E-ST2-43', 5, 'closed', 55, 50, '14:02', NULL);

BEGIN;
INSERT INTO diseases(id, name, category) VALUES
  ('e2e57201-0000-4000-8000-000000000005', 'E2E-ST2-Nuks0', 'E2E-ST2-Kat3');
INSERT INTO hayvanlar(id, kupe_no, cinsiyet, dogum_tarihi, grup)
VALUES ('E2E-ST2-43', 'K-E2E-ST2-43', 'Dişi', :'t'::date - 1500, 'Sağmal (Laktasyonda)');
INSERT INTO cases(id, animal_id, disease_id, start_date, status, closed_at, protocol_family)
SELECT v.vaka_id, v.hayvan_id, ('e2e57201-0000-4000-8000-00000000000' || v.hst)::uuid, :'t'::date - v.bas, v.durum,
       ((:'t'::date - v.kap) + v.saat) AT TIME ZONE 'Europe/Istanbul', v.pf
FROM _st2_vaka v WHERE v.kod IN ('n0_a', 'n0_b');
COMMIT;

-- ── TS1 eki (sahip S1 (c), domain §19.7: yalnız ekleme; yukarıdaki satırlar ve önceki beklentiler değişmez) ──
-- Kapanıştan sonra 24 saat içinde aynı hayvan + hastalık için yeni vaka → eski vaka basarisiz_tedavi_degisti.
-- Eşikte cases.created_at kullanılır (start_date gün hassasiyetinde); created_at burada AÇIKÇA yazılır, yukarıdaki
--   vakalarda DEFAULT now() olduğundan kapanış + 24 saati geçer ve onlar bu kola düşmez.
-- Ayrı hastalık E2E-ST2-Degisti (kat E2E-ST2-Kat4) → diğer hastalık ve kategori sayımları etkilenmez.
-- Vaka uuid öneki e2e57209-; kapanış saatleri 15:01..15:10 (benzersiz → toplu değil). ₺: SA=2, SB=10 geçici.
-- kod     hayvan bas    kap    created_at (= eski kapanış + fark)  uygulamalar        sonuc / kg                 ts  ₺
-- td23_a  44     T-300  T-290  bas 08:00                           T-300 A10; T-299 B5 basarisiz_tedavi_degisti/- 2   70
-- td23_b  44     T-289  T-286  td23_a + 23 saat                    T-289 A10          basarili / 3               1   20
-- td24_a  45     T-280  T-270  bas 08:00                           yok (ilaçsız)      basarisiz_tedavi_degisti/- -   -
-- td24_b  45     T-269  T-265  td24_a + tam 24 saat                T-269 A10          basarili / 4               1   20
-- ust_a   46     T-260  T-255  bas 08:00                           T-260 A10          basarisiz_nuks / 5         1   20
-- ust_b   46     T-254  T-250  ust_a + 24 saat 1 sn                T-254 A10          basarili / 4               1   20
-- ol_a    47     T-245  T-240  bas 08:00                           T-245 A10          basarisiz_olum_kesim / 5   1   20  (olum T-225)
-- ol_b    47     T-240  T-235  ol_a + 2 saat                       T-240 A10          basarisiz_olum_kesim / 5   1   20
-- pay_1   48     T-230  T-226  bas 08:00                           T-230 A10          basarili / 4               1   20
-- pay_2   49     T-228  T-223  bas 08:00                           T-228 A10          basarili / 5               1   20
INSERT INTO _st2_vaka(kod, vaka_id, hayvan_id, hst, durum, bas, kap, saat, pf)
SELECT x.kod, ('e2e57209-0000-4000-8000-0000000000' || x.sfx)::uuid, 'E2E-ST2-' || x.h, 6, 'closed', x.bas, x.kap, x.saat::time, NULL
FROM (VALUES ('td23_a', '01', '44', 300, 290, '15:01'), ('td23_b', '02', '44', 289, 286, '15:02'),
             ('td24_a', '03', '45', 280, 270, '15:03'), ('td24_b', '04', '45', 269, 265, '15:04'),
             ('ust_a',  '05', '46', 260, 255, '15:05'), ('ust_b',  '06', '46', 254, 250, '15:06'),
             ('ol_a',   '07', '47', 245, 240, '15:07'), ('ol_b',   '08', '47', 240, 235, '15:08'),
             ('pay_1',  '09', '48', 230, 226, '15:09'), ('pay_2',  '10', '49', 228, 223, '15:10'))
     AS x(kod, sfx, h, bas, kap, saat);

BEGIN;
INSERT INTO diseases(id, name, category) VALUES
  ('e2e57201-0000-4000-8000-000000000006', 'E2E-ST2-Degisti', 'E2E-ST2-Kat4');
INSERT INTO hayvanlar(id, kupe_no, cinsiyet, dogum_tarihi, grup, cikis_tipi, cikis_tarihi)
SELECT DISTINCT v.hayvan_id, 'K-' || v.hayvan_id, 'Dişi', :'t'::date - 1500, 'Sağmal (Laktasyonda)',
       CASE WHEN v.hayvan_id = 'E2E-ST2-47' THEN 'olum' END,
       CASE WHEN v.hayvan_id = 'E2E-ST2-47' THEN :'t'::date - 225 END
FROM _st2_vaka v WHERE v.vaka_id::text LIKE 'e2e57209-%';
INSERT INTO cases(id, animal_id, disease_id, start_date, status, closed_at, protocol_family, created_at)
SELECT v.vaka_id, v.hayvan_id, 'e2e57201-0000-4000-8000-000000000006', :'t'::date - v.bas, v.durum,
       ((:'t'::date - v.kap) + v.saat) AT TIME ZONE 'Europe/Istanbul', NULL,
       COALESCE((((:'t'::date - r.kap) + r.saat) AT TIME ZONE 'Europe/Istanbul') + f.fark,
                ((:'t'::date - v.bas) + time '08:00') AT TIME ZONE 'Europe/Istanbul')
FROM _st2_vaka v
LEFT JOIN (VALUES ('td23_b', 'td23_a', interval '23 hours'), ('td24_b', 'td24_a', interval '24 hours'),
                  ('ust_b', 'ust_a', interval '24 hours 1 second'), ('ol_b', 'ol_a', interval '2 hours'))
       AS f(kod, ref, fark) ON f.kod = v.kod
LEFT JOIN _st2_vaka r ON r.kod = f.ref
WHERE v.vaka_id::text LIKE 'e2e57209-%';

CREATE TEMP TABLE _st2_uyg9(kod text, gun int, urun text, stok text, doz numeric) ON COMMIT DROP;
INSERT INTO _st2_uyg9 VALUES
  ('td23_a', 300, 'A', 'E2E-ST2-SA', 10), ('td23_a', 299, 'B', 'E2E-ST2-SB', 5), ('td23_b', 289, 'A', 'E2E-ST2-SA', 10),
  ('td24_b', 269, 'A', 'E2E-ST2-SA', 10), ('ust_a', 260, 'A', 'E2E-ST2-SA', 10), ('ust_b', 254, 'A', 'E2E-ST2-SA', 10),
  ('ol_a', 245, 'A', 'E2E-ST2-SA', 10), ('ol_b', 240, 'A', 'E2E-ST2-SA', 10), ('pay_1', 230, 'A', 'E2E-ST2-SA', 10),
  ('pay_2', 228, 'A', 'E2E-ST2-SA', 10);
INSERT INTO treatment_days(case_id, treatment_date)
SELECT v.vaka_id, :'t'::date - u.gun FROM _st2_uyg9 u JOIN _st2_vaka v ON v.kod = u.kod;
INSERT INTO drug_administrations(treatment_day_id, drug_product_id, stok_id, dose, unit, uygulanmadi)
SELECT td.id, ('e2e57203-0000-4000-8000-00000000000' || CASE u.urun WHEN 'A' THEN '1' ELSE '2' END)::uuid, u.stok, u.doz, 'ml', false
FROM _st2_uyg9 u
JOIN _st2_vaka v ON v.kod = u.kod
JOIN treatment_days td ON td.case_id = v.vaka_id AND td.treatment_date = :'t'::date - u.gun;
COMMIT;
