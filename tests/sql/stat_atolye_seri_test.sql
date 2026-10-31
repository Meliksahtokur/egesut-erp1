-- tests/sql/stat_atolye_seri_test.sql
-- İstatistik Atölyesi AP1 Task 4 — stat_cumle_dogrula, stat_cumle_donem, stat_wilson, stat_atolye_gruplar,
-- stat_atolye_kombinasyon (T4: NULL), stat_atolye_seri (spec v2 §4.3-§4.5, §4.8; plan Task 4, P4-P8, P12, P13;
-- root ruling 2026-10-17 kapali_tarihsiz: açık sayaca girmez, dipnotta ayrı).
--
-- HEDEF: YALNIZ demo (ref vtzqjmazsvurxdeondmi). Fixture: stat_saglik_fixture.sql (E2E-ST2- önekli; T4 eki dahil).
-- KOŞUM:
--   psql "$OVS_DEMO_DB_URL" -X -v ON_ERROR_STOP=0 -v stat_fixture_ok=true -f tests/sql/stat_atolye_seri_test.sql
-- SONUÇ: _stat_durum(kod, PASS|FAIL|UNMEASURED, etiket); kod başına bir satır; başta ve sonda temizlik; `artik` = 0.
--
-- ELLE TÜRETİLMİŞ BEKLENTİLER (fixture tablosundan; G = stat_saglik_vekil().g, T1 = LEAST(2+G,20), T2 = LEAST(G,15)).
-- E2E-ST2-Enterit view vakaları (22; ovsync 14/21/25 dışlı). A = E2E-ETK-A içerir, B = E2E-ETK-B içerir.
-- tl_g = ₺ (SA=2, SB=10 geçici; SK kayıtlı 20), tl_0 = ₺ geçicisiz (SA/SB maliyet 0 → fiyatsız).
--   kod              A B durum            sonuc                 kg   ts   tl_g  tl_0
--   normal           x x sonuclandi       basarili              5    3    90    -
--   olum_30          x . sonuclandi       basarisiz_olum_kesim  4    1    20    -
--   kesim_31         x . sonuclandi       basarili              2    1    20    -
--   satis            x . sonuclandi       basarili              3    1    20    -
--   nuks_30          x . sonuclandi       basarisiz_nuks        5    1    20    -
--   nuks_30_b        . x sonuclandi       basarili              5    1    50    -
--   nuks_31          x . sonuclandi       basarili              5    1    20    -
--   nuks_31_b        x . sonuclandi       basarili              4    1    20    -
--   olgun_degil      x . sonuclandi       olgunlasmamis         10   1    20    -
--   olgun_sinir      x . sonuclandi       basarili              3    1    20    -
--   aktif_olum       x . sonuclandi       basarisiz_olum_kesim  -    1    20    -
--   aktif_acik       x . acik             -                     -    1    20    -     (acik_n)
--   toplu_1          x . sonuclandi       basarili              T1   3    60    -     vekil
--   toplu_2          x . sonuclandi       basarili              T2   1    20    -     vekil
--   toplu_bos        . . sonuclandi       basarili              -    -    0     0     ilaçsız: ₺ ölçülerinde YOK (TK1 R1; ilacsiz_n 1)
--   fallback         . x sonuclandi       basarili              4    1    50    -
--   uyusmaz          x . sonuclandi       basarili              4    1    -     -     birim_uyusmaz → ₺ yok
--   stoksuz_tekil    x . sonuclandi       basarili              3    1    8     -
--   log_iptal_tedavi x . sonuclandi       basarili              4    1    20    -
--   kapali_tarihsiz  x . kapali_tarihsiz  -                     -    1    20    -     hiçbir ölçüde yok; dipnot 1
--   plan_eksik       x . sonuclandi       basarili              5    1    20    -
--   sk_karisik       x x sonuclandi       basarili              4    2    80    -     (T4 eki; SK kayıtlı)
-- C1 = Enterit, etken, x=A, kıyas tumu, 5 ölçü, kırılım yok, dönem tumu ([T-150, T]); gruplar [x, tumu]:
--   başarı     n [16,19]  k [13,16]  y [81.3, 84.2]   (olgun_degil paydada yok; aktif_olum başarısız olarak var)
--   kapanma    n [16,18]  (aktif_olum, toplu_bos, açık, tarihsiz yok)  medyan/Q1/Q3 = kâhin(tablo, G)
--   tedavi     n [17,19]  vaka_tl (geçici) n [16,18] (TK1 R1: ilaçsız toplu_bos ₺ kümesinde yok; eski 19)
--   başarı ₺   n [12,14]  y [38.17, 39.86] = pay 458/12, 558/14 (uyusmaz başarılı ama ₺'siz → paydada YOK;
--              paydaya katan YANLIŞ hesap 458/13=35.23, 558/16=34.88 ≠ beklenen; ilaçsızı katan eski hesap 558/15=37.20)
--   sayaç: acik_n 1 (kapali_tarihsiz DEĞİL), kapali_tarihsiz_n 1, olgunlasmamis_n 1, vekil_n 2, vekil_G G,
--          fiyatsiz_n 1 (geçicili; uyusmaz) / 19 (geçicisiz; toplu_bos dışında hepsi), dislanan_ovsync_n 3 (14/21/25),
--          ilacsiz_n 1 (toplu_bos; C2/C3'te 0) → ₺ zarflarında fiyat dipnotundan önce ilaçsız dipnotu
--   fiyat_eksik (geçicisiz): [SA vaka_n 16, SB vaka_n 3]; SK yok (kayıtlı); SA=2 verilince SA gecici_deger 2.
-- C2 = C1 + y=B, x_y_siz, [başarı]: xy {normal, sk_karisik} n 2 k 2 y null; x_y_siz n 14 k 11 y 78.6; yetersiz.
--   C2 dipnotunda "Gruplar örtüşür" YOK (xy ile x_y_siz ayrık kümeler); toplu/tarihsiz cümleleri birleşimden gelir.
-- C3 = Pnomoni, etken, kırılım ilac, [başarı], tumu: A(2: tz_gece, tz_olgun) · B(1) · (bilinmiyor)(2) en son;
--   başarı n [1,1,2] (tz_olgun olgunlaşmamış); bilinmiyor_n 2; Ovsync 0 → o dipnot yok.
-- C4 = Enterit, kırılım ay, son 24 ay, [başarı, kapanma]: 25 periyot, ilk periyot n 0 y null, Σn 19, eğri yok.
-- C5 = kategori E2E-ST2-Kat (Enterit + Inaktif): dislanan_ovsync_n 4 (14/21/22/25), başarı n 19.
-- C8 = Pnomoni, kırılım ilac, aralık [T-36, T-30] → yalnız tz_gece + tz_olgun (ikisi de A): TEK grup, dipnot [] (örtüşür yok).
-- C9 = Inaktif, kırılım ilac, tumu: kapsamda vaka yok (tek vakası Ovsync, dönem [T, T]) → grup 0, seriler [], dipnot [].

\if :{?stat_fixture_ok}
\else
\set stat_fixture_ok false
\endif
\echo '=== stat_atolye_seri testi ===' stat_fixture_ok= :stat_fixture_ok

DROP TABLE IF EXISTS _stat_durum;
CREATE TEMP TABLE _stat_durum(kod text PRIMARY KEY, deger text, etiket text);

-- doğrulama red/kabul vakaları: cagri d = stat_cumle_dogrula, s = stat_atolye_seri; bek = beklenen tam hata metni
DROP TABLE IF EXISTS _st4_red;
CREATE TEMP TABLE _st4_red(kod text PRIMARY KEY, cagri text, c jsonb, g jsonb, bek text);
WITH c0 AS (SELECT '{"v":1,"alan":"saglik","hastalik":{"tip":"hastalik","deger":"e2e57201-0000-4000-8000-000000000001"},
  "ilac":{"duzey":"etken","x":null,"y":null},"kiyas_grubu":"tumu",
  "olculer":["saglik_basari","saglik_kapanma_gunu","saglik_vaka_tl"],"kirilim":"yok",
  "donem":{"tip":"son_ay","n":12},"kiyas_duzeyi":["biz"]}'::jsonb AS c)
INSERT INTO _st4_red(kod, cagri, c, g, bek)
SELECT x.kod, x.cagri, x.c, x.g, x.bek FROM c0, LATERAL (VALUES
  ('dogrula_red_bilinmeyen_anahtar', 'd', c0.c || '{"gecici":{}}', NULL::jsonb, 'STAT_CUMLE:gecici:bilinmeyen_anahtar'),
  ('dogrula_red_eksik_anahtar',  'd', c0.c - 'donem', NULL, 'STAT_CUMLE:donem:eksik'),
  ('dogrula_red_cumle_null',     'd', NULL, NULL, 'STAT_CUMLE:cumle:nesne_degil'),
  ('dogrula_red_v2',             'd', c0.c || '{"v":2}', NULL, 'STAT_CUMLE:v:surum'),
  ('dogrula_red_alan',           'd', c0.c || '{"alan":"ekonomi"}', NULL, 'STAT_CUMLE:alan:gecersiz'),
  ('dogrula_red_y_x_yok',        'd', jsonb_set(c0.c, '{ilac,y}', '"E2E-ETK-B"'), NULL, 'STAT_CUMLE:ilac.y:x_yok'),
  ('dogrula_red_y_esit_x',       'd', jsonb_set(jsonb_set(c0.c, '{ilac,x}', '"E2E-ETK-A"'), '{ilac,y}', '"E2E-ETK-A"'),
                                 NULL, 'STAT_CUMLE:ilac.y:x_ile_ayni'),
  ('dogrula_red_ic_bilinmeyen',  'd', jsonb_set(c0.c, '{ilac,z}', '1'), NULL, 'STAT_CUMLE:ilac.z:bilinmeyen_anahtar'),
  ('dogrula_red_x_y_siz_y_yok',  'd', jsonb_set(c0.c, '{ilac,x}', '"E2E-ETK-A"') || '{"kiyas_grubu":"x_y_siz"}', NULL,
                                 'STAT_CUMLE:kiyas_grubu:y_yok'),
  ('dogrula_red_olcu_bos',       'd', c0.c || '{"olculer":[]}', NULL, 'STAT_CUMLE:olculer:bos'),
  ('dogrula_red_olcu_tip',       'd', c0.c || '{"olculer":"saglik_basari"}', NULL, 'STAT_CUMLE:olculer:dizi_degil'),
  ('dogrula_red_olcu_tekrar',    'd', c0.c || '{"olculer":["saglik_basari","saglik_basari"]}', NULL, 'STAT_CUMLE:olculer:tekrar'),
  ('dogrula_red_olcu_doz',       'd', c0.c || '{"olculer":["saglik_basari","saglik_doz"]}', NULL,
                                 'STAT_CUMLE:olculer:doz_hesaplanmaz'),
  ('dogrula_red_olcu_bilinmeyen','d', c0.c || '{"olculer":["saglik_sut"]}', NULL, 'STAT_CUMLE:olculer:bilinmeyen'),
  ('dogrula_red_x_kirilim_ilac', 'd', jsonb_set(c0.c, '{ilac,x}', '"E2E-ETK-A"') || '{"kirilim":"ilac"}', NULL,
                                 'STAT_CUMLE:kirilim:x_ile_ilac'),
  ('dogrula_red_son_ay_5',       'd', c0.c || '{"donem":{"tip":"son_ay","n":5}}', NULL, 'STAT_CUMLE:donem.n:gecersiz'),
  ('dogrula_red_ters_aralik',    'd', c0.c || '{"donem":{"tip":"aralik","bas":"2026-03-01","bit":"2026-01-01"}}', NULL,
                                 'STAT_CUMLE:donem:ters'),
  ('dogrula_red_tarih_bozuk',    'd', c0.c || '{"donem":{"tip":"aralik","bas":"2026-02-30","bit":"2026-03-01"}}', NULL,
                                 'STAT_CUMLE:donem:tarih_degil'),
  ('dogrula_red_kiyas_duzeyi',   'd', c0.c || '{"kiyas_duzeyi":["biz","tr"]}', NULL, 'STAT_CUMLE:kiyas_duzeyi:yalniz_biz'),
  ('dogrula_red_hastalik_yok',   'd', jsonb_set(c0.c, '{hastalik,deger}', '"e2e57201-0000-4000-8000-0000000000ff"'), NULL,
                                 'STAT_CUMLE:hastalik.deger:hastalik_yok'),
  ('dogrula_red_hastalik_uuid',  'd', jsonb_set(c0.c, '{hastalik,deger}', '"Enterit"'), NULL,
                                 'STAT_CUMLE:hastalik.deger:uuid_degil'),
  ('dogrula_red_gecici_negatif', 's', c0.c, '{"ilac_fiyat":{"E2E-ST2-SA":-2}}', 'STAT_CUMLE:gecici.ilac_fiyat:pozitif_sayi_degil'),
  ('dogrula_red_gecici_sifir',   's', c0.c, '{"ilac_fiyat":{"E2E-ST2-SA":0}}', 'STAT_CUMLE:gecici.ilac_fiyat:pozitif_sayi_degil'),
  ('dogrula_red_gecici_metin',   's', c0.c, '{"ilac_fiyat":{"E2E-ST2-SA":"2"}}', 'STAT_CUMLE:gecici.ilac_fiyat:pozitif_sayi_degil'),
  ('dogrula_red_gecici_bilinmeyen','s', c0.c, '{"fiyat":{}}', 'STAT_CUMLE:gecici.fiyat:bilinmeyen_anahtar'),
  ('dogrula_red_seri_yolu',      's', c0.c || '{"v":2}', '{}', 'STAT_CUMLE:v:surum'),
  -- kabul: spec örnek cümlesi + dönem/hastalık varyantları
  ('dogrula_kabul_ornek',        'd', c0.c, NULL, 'HATA_YOK'),
  ('dogrula_kabul_varyant',      'd', c0.c || '{"hastalik":{"tip":"kategori","deger":"E2E-ST2-Kat"},"donem":{"tip":"yil","yil":2026}}',
                                 NULL, 'HATA_YOK'),
  ('dogrula_kabul_varyant2',     'd', jsonb_set(jsonb_set(c0.c, '{ilac,x}', '"E2E-ETK-A"'), '{ilac,y}', '"E2E-ETK-B"')
                                 || '{"hastalik":{"tip":"tumu","deger":null},"kiyas_grubu":"x_y_siz","kirilim":"ceyrek",
                                     "donem":{"tip":"aralik","bas":"2026-01-01","bit":"2026-03-31"}}', NULL, 'HATA_YOK'),
  ('dogrula_kabul_varyant3',     'd', c0.c || '{"hastalik":{"tip":"tumu"},"donem":{"tip":"tumu"},"kirilim":"ilac",
                                     "olculer":["saglik_basari_tl","saglik_tedavi_suresi"]}', NULL, 'HATA_YOK')
) AS x(kod, cagri, c, g, bek);

INSERT INTO _stat_durum(kod, deger, etiket) SELECT kod, 'UNMEASURED', bek FROM _st4_red;
INSERT INTO _stat_durum(kod, deger, etiket) VALUES
  ('bek_tutarli',          'UNMEASURED', 'elle tablo = view (22 Enterit vakası)'),
  ('donem_son_ay',         'UNMEASURED', 'son 12 ay = [T-12 ay, T]'),
  ('donem_tumu',           'UNMEASURED', 'tumu = [kapsamdaki en eski başlangıç, T]'),
  ('donem_yil_aralik',     'UNMEASURED', 'yil 2025 ve aralik'),
  ('wilson_17_21',         'UNMEASURED', '60.0 / 92.3'),
  ('wilson_0_5',           'UNMEASURED', '0.0 / 43.4'),
  ('wilson_5_5',           'UNMEASURED', '56.6 / 100.0'),
  ('wilson_n0',            'UNMEASURED', 'n=0 → NULL'),
  ('gruplar_c1',           'UNMEASURED', 'x 19 vaka, tumu 22 vaka'),
  ('basari_x_A',           'UNMEASURED', 'x: 13/16, 81.3, Wilson'),
  ('basari_tumu',          'UNMEASURED', 'tumu: 16/19, 84.2, Wilson'),
  ('olgun_disi',           'UNMEASURED', 'olgunlasmamis_n=1, paydada yok'),
  ('acik_sayac',           'UNMEASURED', 'acik_n=1, aktif_olum başarı kümesinde'),
  ('kapali_tarihsiz_sayac','UNMEASURED', 'açık sayaçta yok, kapali_tarihsiz_n=1, dipnotta 1'),
  ('hiz_medyan_q',         'UNMEASURED', 'kapanma medyan/Q1/Q3 = kâhin'),
  ('hiz_vekil',            'UNMEASURED', 'vekil_n=2, vekil_G=G, dipnot'),
  ('toplu_bos_hiz_disi',   'UNMEASURED', 'toplu_bos kapanma kümesinde yok (n 18)'),
  ('tedavi_suresi',        'UNMEASURED', 'tedavi medyan/Q = kâhin'),
  ('vaka_tl_gecici',       'UNMEASURED', 'SA=2, SB=10 medyan/Q, kaynak gecici, geri yansıtma'),
  ('vaka_tl_fiyatsiz',     'UNMEASURED', 'geçicisiz: n [0,0], y null, fiyatsiz, fiyatsiz_n 19'),
  ('basari_tl',            'UNMEASURED', 'P6: [38.17, 39.86], uyusmaz paydada yok'),
  ('fiyat_eksik_liste',    'UNMEASURED', 'SA 16, SB 3, SK yok; SA=2 → gecici_deger 2'),
  ('xy_grup',              'UNMEASURED', 'x+y ve x_y_siz grupları'),
  ('xy_ek_uyumu',          'UNMEASURED', 'x_y_siz etiketi ünlü uyumlu: kombinasyon.js _kombinasyonSiz ile aynı tablo'),
  ('n_lt_5_null',          'UNMEASURED', 'n<5 hücrede y/alt/ust null, n/k kalır'),
  ('kirilim_ilac_sira',    'UNMEASURED', '(bilinmiyor) en son, n azalan'),
  ('kirilim_ay',           'UNMEASURED', '25 periyot, boş periyot n=0 y=null, eğri yok'),
  ('kirilim_ceyrek_yil',   'UNMEASURED', 'çeyrek/yıl periyot sayısı + etiket'),
  ('dipnot_ovsync',        'UNMEASURED', 'Enterit 3, kategori 4; k=0 cümlesi yok'),
  ('dipnot_sira',          'UNMEASURED', 'dipnot dizisi sabit sıra'),
  ('ortusur_tek_grup',     'UNMEASURED', 'ilaç grubu <2 → örtüşür dipnotu yok (tek grup + boş kapsam)'),
  ('surum_onek',           'UNMEASURED', 'surum sql:2026101700000%, tanim = olcum, hesap_at dolu'),
  ('kombinasyon_null',     'UNMEASURED', 'kombinasyon anahtarı var; x yok → null, x var → satirlar dizisi'),
  ('egri_monoton',         'UNMEASURED', 'eğri = kâhin, artan, son 1.000'),
  ('seri_acl',             'UNMEASURED', 'anon 0/6, authenticated 6/6'),
  ('seri_invoker',         'UNMEASURED', 'prosecdef=false, search_path, oynaklık, authenticated = postgres'),
  ('artik',                'UNMEASURED', 'E2E-ST2- artık = 0');
-- T5 perf c: kapsam yardımcısı + iç gövdeler
INSERT INTO _stat_durum(kod, deger, etiket) VALUES
  ('kapsam_acl_invoker',   'UNMEASURED', 'kapsam/gruplar_k/kombinasyon_k: anon 0/3, PUBLIC 0/3, authenticated 3/3, INVOKER, STABLE, search_path');
-- TK1 (root ruling R1): ilaçsız vaka (maliyet_kalemleri []) ₺ ölçülerine girmez; diğer ölçüler aynen
INSERT INTO _stat_durum(kod, deger, etiket) VALUES
  ('vaka_tl_ilacsiz_disi',  'UNMEASURED', 'C1g vaka_tl tumu n 18 (toplu_bos yok); başarı tumu n 19 (toplu_bos var)'),
  ('basari_tl_ilacsiz_disi','UNMEASURED', 'C1g basari_tl tumu n 14, y 39.86 = 558/14 (ilaçsızlı eski 558/15 = 37.20)'),
  ('sayac_ilacsiz_n',       'UNMEASURED', 'ilacsiz_n: C1g her zarfta 1, C2 0, C3 0, C1 (geçicisiz) 1'),
  ('dipnot_ilacsiz',        'UNMEASURED', 'yalnız ₺ zarfında, fiyat dipnotundan hemen önce; ₺ dışı zarfta ve ilacsiz_n 0''da yok');
-- TS1 (sahip S1 (c), domain §19.7); elle sabit, fixture TS1 eki tablosundan.
-- C10 = E2E-ST2-Degisti, etken, x yok, kırılım yok, dönem tumu, 5 ölçü, SA=2 SB=10:
--   başarı n 10 k 5 y 50.0 (tedavi değişti 2 vaka paydada; dışlayan yanlış hesap 5/8 = 62.5)
--   kapanma n 8, 3,4,4,4,5,5,5,5 → medyan 4.5 Q1 4.0 Q3 5.0; eğri gün [3,4,5] oran [0.125, 0.500, 1.000]
--     (kapanış günleri 10, 10 sayılsa medyan 5.0; payda sayılsa son oran 0.800)
--   tedavi n 9 (td24_a ilaçsız) medyan 1.0; vaka ₺ n 9 medyan 20.00; başarı ₺ n 5 y 46.00 = (70 + 8×20)/5 (td23_a dışında 32.00)
-- C11 = C10 + kırılım ilac, [başarı]: td23_a A ve B gruplarında, td24_a ilaçsız → tedavi_degisti_n 1 (tekil; çift sayım 2)
INSERT INTO _stat_durum(kod, deger, etiket) VALUES
  ('basari_payda_tedavi_degisti', 'UNMEASURED', 'C10 başarı n 10 k 5 y 50.0'),
  ('hiz_disi_tedavi_degisti',     'UNMEASURED', 'C10 kapanma n 8 medyan 4.5 Q1 4 Q3 5; eğri gün [3,4,5] oran [0.125,0.5,1]; kapanış-bilinmiyor sayacı 0'),
  ('tedavi_sure_tl_icinde',       'UNMEASURED', 'C10 tedavi n 9, vaka ₺ n 9 medyan 20, başarı ₺ n 5 y 46.00'),
  ('nuks_sayac_disi',             'UNMEASURED', 'sayaçta nüks anahtarı yok; vaka listesinde basarisiz_nuks 1, tedavi değişti 2'),
  ('dipnot_tedavi_degisti',       'UNMEASURED', 'N>0 birebir cümle (her zarfta); N=0 cümle yok; sayaç birleşimde tekil');

\if :stat_fixture_ok
\ir stat_saglik_fixture.sql

SELECT g AS g, normal_n AS normal_n FROM public.stat_saglik_vekil() \gset
\echo 'vekil G = ' :g ' normal_n = ' :normal_n
\set gec '{"ilac_fiyat":{"E2E-ST2-SA":2,"E2E-ST2-SB":10}}'

-- doğrulama
CREATE FUNCTION pg_temp._st4_hata(p_cagri text, p_c jsonb, p_g jsonb) RETURNS text LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cagri = 'd' THEN PERFORM public.stat_cumle_dogrula(p_c); ELSE PERFORM public.stat_atolye_seri(p_c, p_g); END IF;
  RETURN 'HATA_YOK';
EXCEPTION WHEN OTHERS THEN RETURN SQLERRM;
END $f$;
UPDATE _stat_durum d SET deger = CASE WHEN x.hata = r.bek THEN 'PASS' ELSE 'FAIL' END, etiket = 'beklenen=' || r.bek || ' gelen=' || x.hata
FROM _st4_red r, LATERAL (SELECT pg_temp._st4_hata(r.cagri, r.c, r.g) AS hata) x
WHERE d.kod = r.kod;

-- elle tablo
DROP TABLE IF EXISTS _st4_bek;
CREATE TEMP TABLE _st4_bek(kod text PRIMARY KEY, a boolean, b boolean, durum text, sonuc text, kg text, ts int,
                           tl_g numeric, tl_0 numeric);
INSERT INTO _st4_bek VALUES
  ('normal',           true,  true,  'sonuclandi', 'basarili',             '5',  3, 90, NULL),
  ('olum_30',          true,  false, 'sonuclandi', 'basarisiz_olum_kesim', '4',  1, 20, NULL),
  ('kesim_31',         true,  false, 'sonuclandi', 'basarili',             '2',  1, 20, NULL),
  ('satis',            true,  false, 'sonuclandi', 'basarili',             '3',  1, 20, NULL),
  ('nuks_30',          true,  false, 'sonuclandi', 'basarisiz_nuks',       '5',  1, 20, NULL),
  ('nuks_30_b',        false, true,  'sonuclandi', 'basarili',             '5',  1, 50, NULL),
  ('nuks_31',          true,  false, 'sonuclandi', 'basarili',             '5',  1, 20, NULL),
  ('nuks_31_b',        true,  false, 'sonuclandi', 'basarili',             '4',  1, 20, NULL),
  ('olgun_degil',      true,  false, 'sonuclandi', 'olgunlasmamis',        '10', 1, 20, NULL),
  ('olgun_sinir',      true,  false, 'sonuclandi', 'basarili',             '3',  1, 20, NULL),
  ('aktif_olum',       true,  false, 'sonuclandi', 'basarisiz_olum_kesim', NULL, 1, 20, NULL),
  ('aktif_acik',       true,  false, 'acik',       NULL,                   NULL, 1, 20, NULL),
  ('toplu_1',          true,  false, 'sonuclandi', 'basarili',             'T1', 3, 60, NULL),
  ('toplu_2',          true,  false, 'sonuclandi', 'basarili',             'T2', 1, 20, NULL),
  ('toplu_bos',        false, false, 'sonuclandi', 'basarili',             NULL, NULL, 0, 0),
  ('fallback',         false, true,  'sonuclandi', 'basarili',             '4',  1, 50, NULL),
  ('uyusmaz',          true,  false, 'sonuclandi', 'basarili',             '4',  1, NULL, NULL),
  ('stoksuz_tekil',    true,  false, 'sonuclandi', 'basarili',             '3',  1, 8, NULL),
  ('log_iptal_tedavi', true,  false, 'sonuclandi', 'basarili',             '4',  1, 20, NULL),
  ('kapali_tarihsiz',  true,  false, 'kapali_tarihsiz', NULL,              NULL, 1, 20, NULL),
  ('plan_eksik',       true,  false, 'sonuclandi', 'basarili',             '5',  1, 20, NULL),
  ('sk_karisik',       true,  true,  'sonuclandi', 'basarili',             '4',  2, 80, NULL);
DROP TABLE IF EXISTS _st4_k;
CREATE TEMP TABLE _st4_k AS
SELECT b.*, CASE b.kg WHEN 'T1' THEN LEAST(2 + :'g'::int, 20) WHEN 'T2' THEN LEAST(:'g'::int, 15) ELSE b.kg::int END AS kgi,
       v.bas AS bas_gun
FROM _st4_bek b JOIN _st2_vaka v ON v.kod = b.kod;

-- bek_tutarli: elle tablo view ile aynı mı (kâhinin kendisi sapmasın)
UPDATE _stat_durum SET deger = CASE WHEN x.esit = 22 AND x.view_n = 22 THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'eşleşen=' || x.esit || '/22 view Enterit n=' || x.view_n || ' farklı=' || coalesce(x.fark, '∅')
FROM (SELECT count(*) FILTER (WHERE q.ok) AS esit, string_agg(q.kod, ',') FILTER (WHERE NOT q.ok) AS fark,
             (SELECT count(*) FROM v_stat_saglik_vaka v
               WHERE v.hastalik_id = 'e2e57201-0000-4000-8000-000000000001') AS view_n
        FROM (SELECT k.kod,
                     coalesce(v.durum = k.durum AND v.sonuc IS NOT DISTINCT FROM k.sonuc
                       AND v.kapanma_gunu IS NOT DISTINCT FROM k.kgi AND v.tedavi_suresi_gun IS NOT DISTINCT FROM k.ts
                       AND public.stat_saglik_vaka_tl(v.maliyet_kalemleri, :'gec'::jsonb->'ilac_fiyat') IS NOT DISTINCT FROM k.tl_g
                       AND public.stat_saglik_vaka_tl(v.maliyet_kalemleri, '{}') IS NOT DISTINCT FROM k.tl_0
                       AND k.a = EXISTS (SELECT 1 FROM v_stat_saglik_vaka_ilac i WHERE i.vaka_id = s.vaka_id
                                           AND i.duzey = 'etken' AND i.deger = 'E2E-ETK-A')
                       AND k.b = EXISTS (SELECT 1 FROM v_stat_saglik_vaka_ilac i WHERE i.vaka_id = s.vaka_id
                                           AND i.duzey = 'etken' AND i.deger = 'E2E-ETK-B'), false) AS ok
                FROM _st4_k k JOIN _st2_vaka s ON s.kod = k.kod LEFT JOIN v_stat_saglik_vaka v ON v.vaka_id = s.vaka_id) q) x
WHERE kod = 'bek_tutarli';

-- dönem
UPDATE _stat_durum SET deger = CASE WHEN d.bas = (:'t'::date - interval '12 months')::date AND d.bit = :'t'::date
                                    THEN 'PASS' ELSE 'FAIL' END, etiket = d.bas || ' .. ' || d.bit
FROM public.stat_cumle_donem((SELECT c FROM _st4_red WHERE kod = 'dogrula_kabul_ornek')) d WHERE kod = 'donem_son_ay';
UPDATE _stat_durum SET deger = CASE WHEN d.bas = :'t'::date - 150 AND d.bit = :'t'::date THEN 'PASS' ELSE 'FAIL' END,
  etiket = d.bas || ' .. ' || d.bit || ' (beklenen T-150 .. T)'
FROM public.stat_cumle_donem((SELECT c || '{"donem":{"tip":"tumu"}}' FROM _st4_red WHERE kod = 'dogrula_kabul_ornek')) d
WHERE kod = 'donem_tumu';
UPDATE _stat_durum SET deger = CASE WHEN y.bas = '2025-01-01' AND y.bit = '2025-12-31' AND a.bas = '2026-01-05'
                                     AND a.bit = '2026-03-01' THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'yil=' || y.bas || '..' || y.bit || ' aralik=' || a.bas || '..' || a.bit
FROM public.stat_cumle_donem((SELECT c || '{"donem":{"tip":"yil","yil":2025}}' FROM _st4_red WHERE kod = 'dogrula_kabul_ornek')) y,
     public.stat_cumle_donem((SELECT c || '{"donem":{"tip":"aralik","bas":"2026-01-05","bit":"2026-03-01"}}'
                                FROM _st4_red WHERE kod = 'dogrula_kabul_ornek')) a
WHERE kod = 'donem_yil_aralik';

-- Wilson (plan değerleri) + bağımsız kâhin (float8, aynı formül ayrı yazım)
CREATE FUNCTION pg_temp._st4_wilson(k int, n int) RETURNS numeric[] LANGUAGE sql AS $f$
  SELECT CASE WHEN n > 0 THEN ARRAY[
    greatest(0, round((100 * ((k::float8 / n + 3.8416 / (2 * n)) - 1.96 * sqrt(k::float8 / n * (1 - k::float8 / n) / n
             + 3.8416 / (4.0 * n * n))) / (1 + 3.8416 / n))::numeric, 1)),
    least(100, round((100 * ((k::float8 / n + 3.8416 / (2 * n)) + 1.96 * sqrt(k::float8 / n * (1 - k::float8 / n) / n
             + 3.8416 / (4.0 * n * n))) / (1 + 3.8416 / n))::numeric, 1))] END;
$f$;
UPDATE _stat_durum s SET deger = CASE WHEN w.alt::text = x.alt::text AND w.ust::text = x.ust::text THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'alt=' || coalesce(w.alt::text, '∅') || ' ust=' || coalesce(w.ust::text, '∅')
FROM (VALUES ('wilson_17_21', 17, 21, 60.0, 92.3), ('wilson_0_5', 0, 5, 0.0, 43.4), ('wilson_5_5', 5, 5, 56.6, 100.0))
       AS x(kod, k, n, alt, ust),
     LATERAL public.stat_wilson(x.k, x.n) w
WHERE s.kod = x.kod;
UPDATE _stat_durum SET deger = CASE WHEN w.alt IS NULL AND w.ust IS NULL THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'alt=' || coalesce(w.alt::text, '∅') || ' ust=' || coalesce(w.ust::text, '∅')
FROM public.stat_wilson(0, 0) w WHERE kod = 'wilson_n0';

-- cümleler ve sonuçlar
DROP TABLE IF EXISTS _st4_c;
CREATE TEMP TABLE _st4_c(ad text PRIMARY KEY, c jsonb);
INSERT INTO _st4_c
SELECT 'C1', jsonb_set(c, '{ilac,x}', '"E2E-ETK-A"') || '{"donem":{"tip":"tumu"},"olculer":["saglik_basari",
  "saglik_kapanma_gunu","saglik_tedavi_suresi","saglik_vaka_tl","saglik_basari_tl"]}' FROM _st4_red WHERE kod = 'dogrula_kabul_ornek';
INSERT INTO _st4_c SELECT 'C2', jsonb_set(c, '{ilac,y}', '"E2E-ETK-B"') || '{"kiyas_grubu":"x_y_siz","olculer":["saglik_basari"]}'
FROM _st4_c WHERE ad = 'C1';
INSERT INTO _st4_c SELECT 'C3', jsonb_set(c, '{ilac,x}', 'null') || '{"hastalik":{"tip":"hastalik",
  "deger":"e2e57201-0000-4000-8000-000000000002"},"kirilim":"ilac","olculer":["saglik_basari"]}' FROM _st4_c WHERE ad = 'C1';
INSERT INTO _st4_c SELECT 'C4', jsonb_set(c, '{ilac,x}', 'null') || '{"kirilim":"ay","donem":{"tip":"son_ay","n":24},
  "olculer":["saglik_basari","saglik_kapanma_gunu"]}' FROM _st4_c WHERE ad = 'C1';
INSERT INTO _st4_c SELECT 'C5', jsonb_set(c, '{ilac,x}', 'null') || '{"hastalik":{"tip":"kategori","deger":"E2E-ST2-Kat"},
  "olculer":["saglik_basari"]}' FROM _st4_c WHERE ad = 'C1';
INSERT INTO _st4_c SELECT 'C6', c || '{"kirilim":"ceyrek","olculer":["saglik_basari"]}' FROM _st4_c WHERE ad = 'C4';
INSERT INTO _st4_c SELECT 'C7', c || '{"kirilim":"yil","olculer":["saglik_basari"]}' FROM _st4_c WHERE ad = 'C4';
INSERT INTO _st4_c SELECT 'C8', jsonb_set(c, '{ilac,x}', 'null') || jsonb_build_object('hastalik', jsonb_build_object('tip',
  'hastalik', 'deger', 'e2e57201-0000-4000-8000-000000000002'), 'kirilim', 'ilac', 'olculer', '["saglik_basari"]'::jsonb,
  'donem', jsonb_build_object('tip', 'aralik', 'bas', :'t'::date - 36, 'bit', :'t'::date - 30)) FROM _st4_c WHERE ad = 'C1';
INSERT INTO _st4_c SELECT 'C9', c || '{"hastalik":{"tip":"hastalik","deger":"e2e57201-0000-4000-8000-000000000003"},
  "donem":{"tip":"tumu"}}' FROM _st4_c WHERE ad = 'C8';
SELECT c AS c1 FROM _st4_c WHERE ad = 'C1' \gset

DROP TABLE IF EXISTS _st4_r;
CREATE TEMP TABLE _st4_r(ad text PRIMARY KEY, r jsonb);
INSERT INTO _st4_r SELECT 'C1g', public.stat_atolye_seri(c, :'gec') FROM _st4_c WHERE ad = 'C1';
INSERT INTO _st4_r SELECT 'C1', public.stat_atolye_seri(c) FROM _st4_c WHERE ad = 'C1';
INSERT INTO _st4_r SELECT 'C1sa', public.stat_atolye_seri(c, '{"ilac_fiyat":{"E2E-ST2-SA":2}}') FROM _st4_c WHERE ad = 'C1';
INSERT INTO _st4_r SELECT ad, public.stat_atolye_seri(c, :'gec') FROM _st4_c WHERE ad IN ('C2', 'C3', 'C4', 'C5', 'C6', 'C7', 'C8', 'C9');
CREATE FUNCTION pg_temp._st4_z(p_ad text, p_olcum text) RETURNS jsonb LANGUAGE sql AS $f$
  SELECT z FROM _st4_r r, jsonb_array_elements(r.r->'zarflar') z WHERE r.ad = p_ad AND z->>'olcum' = p_olcum;
$f$;
\echo '--- C1g zarfları (özet) ---'
SELECT z->>'olcum' AS olcum, z->'n' AS n, z->'seriler' AS seriler, z->'sayac' AS sayac, z->'dipnot' AS dipnot
FROM _st4_r, jsonb_array_elements(r->'zarflar') z WHERE ad = 'C1g';

-- gruplar
UPDATE _stat_durum SET deger = CASE WHEN x.iz = 'tumu:Tüm E2E-ST2-Enterit vakaları:2:22,x:E2E-ETK-A içeren:1:19'
                                    THEN 'PASS' ELSE 'FAIL' END, etiket = x.iz
FROM (SELECT string_agg(q.anahtar || ':' || q.etiket || ':' || q.sira || ':' || q.n, ',' ORDER BY q.anahtar) AS iz
        FROM (SELECT g.anahtar, g.etiket, g.sira, count(g.vaka_id) AS n
                FROM public.stat_atolye_gruplar((SELECT c FROM _st4_c WHERE ad = 'C1')) g
               GROUP BY 1, 2, 3) q) x
WHERE kod = 'gruplar_c1';

-- başarı
UPDATE _stat_durum SET
  deger = CASE WHEN z#>'{seriler,0,n,0}' = '16' AND z#>'{seriler,0,k,0}' = '13' AND z#>'{seriler,0,y,0}' = '81.3'
                AND z#>'{seriler,0,alt,0}' = to_jsonb((pg_temp._st4_wilson(13, 16))[1])
                AND z#>'{seriler,0,ust,0}' = to_jsonb((pg_temp._st4_wilson(13, 16))[2])
                AND z#>'{x,anahtar,0}' = '"x"' AND z#>'{x,deger,0}' = '"E2E-ETK-A içeren"' AND z->'n' = '16'
                AND z->'yetersiz' = 'false' AND NOT z#>'{seriler,0}' ? 'q1' THEN 'PASS' ELSE 'FAIL' END,
  etiket = coalesce((z->'seriler')::text, '∅') || ' wilson kâhin=' || pg_temp._st4_wilson(13, 16)::text
FROM pg_temp._st4_z('C1g', 'saglik_basari') z WHERE kod = 'basari_x_A';
UPDATE _stat_durum SET
  deger = CASE WHEN z#>'{seriler,0,n,1}' = '19' AND z#>'{seriler,0,k,1}' = '16' AND z#>'{seriler,0,y,1}' = '84.2'
                AND z#>'{seriler,0,alt,1}' = to_jsonb((pg_temp._st4_wilson(16, 19))[1])
                AND z#>'{seriler,0,ust,1}' = to_jsonb((pg_temp._st4_wilson(16, 19))[2])
                AND z#>'{x,anahtar,1}' = '"tumu"' AND z#>'{x,deger,1}' = '"Tüm E2E-ST2-Enterit vakaları"'
                AND z#>'{sayac,kiyas_n}' = '19' THEN 'PASS' ELSE 'FAIL' END,
  etiket = coalesce((z->'seriler')::text, '∅') || ' kiyas_n=' || coalesce(z#>>'{sayac,kiyas_n}', '∅')
FROM pg_temp._st4_z('C1g', 'saglik_basari') z WHERE kod = 'basari_tumu';
UPDATE _stat_durum SET
  deger = CASE WHEN z#>'{sayac,olgunlasmamis_n}' = '1' AND z#>'{seriler,0,n,1}' = '19'
                AND (SELECT count(*) FROM _st4_bek WHERE durum = 'sonuclandi') = 20 THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'olgunlasmamis_n=' || coalesce(z#>>'{sayac,olgunlasmamis_n}', '∅') || ' başarı n=' || coalesce(z#>>'{seriler,0,n,1}', '∅')
           || ' (sonuçlanmış 20)'
FROM pg_temp._st4_z('C1g', 'saglik_basari') z WHERE kod = 'olgun_disi';
UPDATE _stat_durum SET
  deger = CASE WHEN z#>'{sayac,acik_n}' = '1' AND z#>'{seriler,0,n,1}' = '19' AND z#>'{seriler,0,k,1}' = '16'
               THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'acik_n=' || coalesce(z#>>'{sayac,acik_n}', '∅') || ' (aktif_olum hariç olsaydı n=18 k=16)'
FROM pg_temp._st4_z('C1g', 'saglik_basari') z WHERE kod = 'acik_sayac';
UPDATE _stat_durum SET
  deger = CASE WHEN (SELECT bool_and(z#>'{sayac,acik_n}' = '1' AND z#>'{sayac,kapali_tarihsiz_n}' = '1'
                                     AND z->'dipnot' ? '1 vaka kapalı ama kapanış tarihi yok; hesaba girmedi.')
                       FROM _st4_r r, jsonb_array_elements(r.r->'zarflar') z WHERE r.ad = 'C1g')
               THEN 'PASS' ELSE 'FAIL' END,
  etiket = (SELECT string_agg(z->>'olcum' || ' acik=' || coalesce(z#>>'{sayac,acik_n}', '∅') || ' tarihsiz='
                              || coalesce(z#>>'{sayac,kapali_tarihsiz_n}', '∅'), '; ')
              FROM _st4_r r, jsonb_array_elements(r.r->'zarflar') z WHERE r.ad = 'C1g')
WHERE kod = 'kapali_tarihsiz_sayac';

-- süre ölçüleri ve ₺: kâhin = elle tablo üzerinde percentile_cont (gruplar x = A içeren, tumu = hepsi)
CREATE FUNCTION pg_temp._st4_kahin(p_olcum text, p_gecici boolean) RETURNS jsonb LANGUAGE sql AS $f$
  SELECT jsonb_build_object('n', jsonb_agg(q.n ORDER BY q.s), 'y', jsonb_agg(q.y ORDER BY q.s),
                            'q1', jsonb_agg(q.q1 ORDER BY q.s), 'q3', jsonb_agg(q.q3 ORDER BY q.s))
  FROM (SELECT g.s, count(d.d)::int AS n,
               CASE WHEN count(d.d) >= 5 THEN round(percentile_cont(0.5) WITHIN GROUP (ORDER BY d.d)::numeric, g.o) END AS y,
               CASE WHEN count(d.d) >= 5 THEN round(percentile_cont(0.25) WITHIN GROUP (ORDER BY d.d)::numeric, g.o) END AS q1,
               CASE WHEN count(d.d) >= 5 THEN round(percentile_cont(0.75) WITHIN GROUP (ORDER BY d.d)::numeric, g.o) END AS q3
        FROM (VALUES (1, true), (2, false)) AS g0(s, yalniz_a)
        CROSS JOIN LATERAL (SELECT g0.s, CASE WHEN p_olcum = 'saglik_vaka_tl' THEN 2 ELSE 1 END AS o) g
        LEFT JOIN LATERAL (
          SELECT CASE p_olcum WHEN 'saglik_kapanma_gunu' THEN k.kgi WHEN 'saglik_tedavi_suresi' THEN k.ts
                              ELSE CASE WHEN p_gecici THEN k.tl_g ELSE k.tl_0 END END::numeric AS d
          FROM _st4_k k WHERE k.durum = 'sonuclandi' AND (k.a OR NOT g0.yalniz_a)
            AND (p_olcum <> 'saglik_vaka_tl' OR k.ts IS NOT NULL)) d ON d.d IS NOT NULL   -- R1: ilaçsız (ts NULL) ₺'de yok
        GROUP BY g.s, g.o) q;
$f$;
CREATE FUNCTION pg_temp._st4_seri(z jsonb) RETURNS jsonb LANGUAGE sql AS $f$
  SELECT jsonb_build_object('n', z#>'{seriler,0,n}', 'y', z#>'{seriler,0,y}', 'q1', z#>'{seriler,0,q1}', 'q3', z#>'{seriler,0,q3}');
$f$;
UPDATE _stat_durum SET
  deger = CASE WHEN pg_temp._st4_seri(z) = pg_temp._st4_kahin('saglik_kapanma_gunu', true)
                AND z#>'{seriler,0,n}' = '[16, 18]' AND NOT z#>'{seriler,0}' ? 'k' THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'gelen=' || pg_temp._st4_seri(z)::text || ' kâhin=' || pg_temp._st4_kahin('saglik_kapanma_gunu', true)::text
FROM pg_temp._st4_z('C1g', 'saglik_kapanma_gunu') z WHERE kod = 'hiz_medyan_q';
UPDATE _stat_durum SET
  deger = CASE WHEN z#>'{sayac,vekil_n}' = '2' AND z#>'{sayac,vekil_G}' = to_jsonb(:'g'::int)
                AND z->'dipnot' ? format('2 vaka toplu kapatılmış; kapanma günü son ilaç + %s gün ile tahmin edildi.', :'g')
               THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'vekil_n=' || coalesce(z#>>'{sayac,vekil_n}', '∅') || ' G=' || coalesce(z#>>'{sayac,vekil_G}', '∅')
           || ' (fn G=' || :'g' || ')'
FROM pg_temp._st4_z('C1g', 'saglik_kapanma_gunu') z WHERE kod = 'hiz_vekil';
UPDATE _stat_durum SET
  deger = CASE WHEN z#>'{seriler,0,n,1}' = '18' AND v.kapanma_gunu IS NULL AND v.toplu_kapanis THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'kapanma tumu n=' || coalesce(z#>>'{seriler,0,n,1}', '∅') || ' toplu_bos kg=' || coalesce(v.kapanma_gunu::text, '∅')
FROM pg_temp._st4_z('C1g', 'saglik_kapanma_gunu') z, _st2_vaka s JOIN v_stat_saglik_vaka v ON v.vaka_id = s.vaka_id
WHERE s.kod = 'toplu_bos' AND _stat_durum.kod = 'toplu_bos_hiz_disi';
UPDATE _stat_durum SET
  deger = CASE WHEN pg_temp._st4_seri(z) = pg_temp._st4_kahin('saglik_tedavi_suresi', true)
                AND z#>'{seriler,0,n}' = '[17, 19]' THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'gelen=' || pg_temp._st4_seri(z)::text || ' kâhin=' || pg_temp._st4_kahin('saglik_tedavi_suresi', true)::text
FROM pg_temp._st4_z('C1g', 'saglik_tedavi_suresi') z WHERE kod = 'tedavi_suresi';
UPDATE _stat_durum SET
  deger = CASE WHEN pg_temp._st4_seri(z) = pg_temp._st4_kahin('saglik_vaka_tl', true) AND z#>'{seriler,0,n}' = '[16, 18]'
                AND z->'fiyat_kaynagi' = '"gecici"' AND z->'gecici' = jsonb_build_object('var', true, 'ilac_fiyat', :'gec'::jsonb->'ilac_fiyat')
                AND z#>'{sayac,fiyatsiz_n}' = '1' THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'gelen=' || pg_temp._st4_seri(z)::text || ' kâhin=' || pg_temp._st4_kahin('saglik_vaka_tl', true)::text
           || ' kaynak=' || coalesce(z->>'fiyat_kaynagi', '∅') || ' gecici=' || coalesce((z->'gecici')::text, '∅')
FROM pg_temp._st4_z('C1g', 'saglik_vaka_tl') z WHERE kod = 'vaka_tl_gecici';
UPDATE _stat_durum SET
  deger = CASE WHEN z#>'{seriler,0,n}' = '[0, 0]' AND z#>'{seriler,0,y}' = '[null, null]' AND z#>'{seriler,0,q1}' = '[null, null]'
                AND pg_temp._st4_seri(z) = pg_temp._st4_kahin('saglik_vaka_tl', false)
                AND z->'fiyat_kaynagi' = '"fiyatsiz"' AND z#>'{sayac,fiyatsiz_n}' = '19'
                AND z->'gecici' = '{"var": false, "ilac_fiyat": {}}' AND z->'dipnot' ? '19 vakanın ilaç fiyatı yok.'
               THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'gelen=' || pg_temp._st4_seri(z)::text || ' kaynak=' || coalesce(z->>'fiyat_kaynagi', '∅')
           || ' fiyatsiz_n=' || coalesce(z#>>'{sayac,fiyatsiz_n}', '∅')
FROM pg_temp._st4_z('C1', 'saglik_vaka_tl') z WHERE kod = 'vaka_tl_fiyatsiz';
-- başarı başına ₺ (P6): beklenen [458/12, 558/14] = [38.17, 39.86]; uyusmaz'ı paydaya katan yanlış [35.23, 34.88]
UPDATE _stat_durum SET
  deger = CASE WHEN z#>'{seriler,0,n}' = '[12, 14]' AND z#>'{seriler,0,y}' = '[38.17, 39.86]'
                AND z#>'{seriler,0,y}' <> '[35.23, 34.88]' AND z->'fiyat_kaynagi' = '"gecici"'
                AND NOT z#>'{seriler,0}' ? 'q1' AND NOT z#>'{seriler,0}' ? 'k' THEN 'PASS' ELSE 'FAIL' END,
  etiket = coalesce((z->'seriler')::text, '∅')
FROM pg_temp._st4_z('C1g', 'saglik_basari_tl') z WHERE kod = 'basari_tl';
UPDATE _stat_durum SET
  deger = CASE WHEN a.r->'fiyat_eksik' = '[{"stok_id":"E2E-ST2-SA","urun_adi":"E2E-ST2-Stok-A","birim":"ml","vaka_n":16,"gecici_deger":null},
                                         {"stok_id":"E2E-ST2-SB","urun_adi":"E2E-ST2-Stok-B","birim":"ml","vaka_n":3,"gecici_deger":null}]'
                AND b.r->'fiyat_eksik' = '[{"stok_id":"E2E-ST2-SA","urun_adi":"E2E-ST2-Stok-A","birim":"ml","vaka_n":16,"gecici_deger":2},
                                         {"stok_id":"E2E-ST2-SB","urun_adi":"E2E-ST2-Stok-B","birim":"ml","vaka_n":3,"gecici_deger":null}]'
               THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'geçicisiz=' || coalesce((a.r->'fiyat_eksik')::text, '∅') || ' SA=2=' || coalesce((b.r->'fiyat_eksik')::text, '∅')
FROM _st4_r a, _st4_r b WHERE a.ad = 'C1' AND b.ad = 'C1sa' AND kod = 'fiyat_eksik_liste';

-- TK1 R1: ilaçsız vaka (toplu_bos, kalem []) ₺ ölçülerine girmez; başarı kümesinde kalır
UPDATE _stat_durum SET
  deger = CASE WHEN t#>'{seriler,0,n}' = '[16, 18]' AND b#>'{seriler,0,n,1}' = '19'
                AND v.durum = 'sonuclandi' AND v.maliyet_kalemleri = '[]'::jsonb AND v.sonuc = 'basarili' THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'vaka_tl n=' || coalesce(t#>>'{seriler,0,n}', '∅') || ' başarı tumu n=' || coalesce(b#>>'{seriler,0,n,1}', '∅')
           || ' toplu_bos kalem=' || coalesce(v.maliyet_kalemleri::text, '∅')
FROM pg_temp._st4_z('C1g', 'saglik_vaka_tl') t, pg_temp._st4_z('C1g', 'saglik_basari') b,
     _st2_vaka s JOIN v_stat_saglik_vaka v ON v.vaka_id = s.vaka_id
WHERE s.kod = 'toplu_bos' AND _stat_durum.kod = 'vaka_tl_ilacsiz_disi';
UPDATE _stat_durum SET
  deger = CASE WHEN z#>'{seriler,0,n,1}' = '14' AND z#>'{seriler,0,y,1}' = '39.86' THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'tumu n=' || coalesce(z#>>'{seriler,0,n,1}', '∅') || ' y=' || coalesce(z#>>'{seriler,0,y,1}', '∅')
           || ' (beklenen 14 / 39.86; ilaçsızlı 15 / 37.20)'
FROM pg_temp._st4_z('C1g', 'saglik_basari_tl') z WHERE kod = 'basari_tl_ilacsiz_disi';
UPDATE _stat_durum SET
  deger = CASE WHEN (SELECT bool_and(z#>'{sayac,ilacsiz_n}' = '1') FROM _st4_r r, jsonb_array_elements(r.r->'zarflar') z
                      WHERE r.ad IN ('C1g', 'C1'))
                AND (SELECT count(*) FROM _st4_r r, jsonb_array_elements(r.r->'zarflar') z WHERE r.ad IN ('C1g', 'C1')) = 10
                AND pg_temp._st4_z('C2', 'saglik_basari')#>'{sayac,ilacsiz_n}' = '0'
                AND pg_temp._st4_z('C3', 'saglik_basari')#>'{sayac,ilacsiz_n}' = '0' THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'C1g=' || coalesce((SELECT string_agg(coalesce(z#>>'{sayac,ilacsiz_n}', '∅'), ',') FROM _st4_r r,
                                 jsonb_array_elements(r.r->'zarflar') z WHERE r.ad = 'C1g'), '∅')
           || ' C2=' || coalesce(pg_temp._st4_z('C2', 'saglik_basari')#>>'{sayac,ilacsiz_n}', '∅')
           || ' C3=' || coalesce(pg_temp._st4_z('C3', 'saglik_basari')#>>'{sayac,ilacsiz_n}', '∅')
WHERE kod = 'sayac_ilacsiz_n';
UPDATE _stat_durum SET
  deger = CASE WHEN (SELECT bool_and(CASE WHEN z->>'olcum' IN ('saglik_vaka_tl', 'saglik_basari_tl')
                                          THEN coalesce((SELECT e.i FROM jsonb_array_elements_text(z->'dipnot') WITH ORDINALITY e(d, i)
                                                          WHERE e.d = '1 vaka ilaç uygulanmadığı için ₺ ölçülerine girmedi.')
                                                        = (SELECT e.i FROM jsonb_array_elements_text(z->'dipnot') WITH ORDINALITY e(d, i)
                                                            WHERE e.d = '1 vakanın ilaç fiyatı yok.') - 1, false)   -- NULL = FAIL
                                          ELSE NOT (z->>'dipnot') LIKE '%ilaç uygulanmadığı%' END)
                       FROM _st4_r r, jsonb_array_elements(r.r->'zarflar') z WHERE r.ad = 'C1g')
                AND NOT (SELECT r.r::text FROM _st4_r r WHERE r.ad = 'C3') LIKE '%ilaç uygulanmadığı%'
               THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'vaka_tl=' || coalesce((pg_temp._st4_z('C1g', 'saglik_vaka_tl')->'dipnot')::text, '∅')
           || ' | kapanma=' || coalesce((pg_temp._st4_z('C1g', 'saglik_kapanma_gunu')->'dipnot')::text, '∅')
WHERE kod = 'dipnot_ilacsiz';

-- x + y, n<5, ilaç kırılımı sırası
UPDATE _stat_durum SET
  deger = CASE WHEN z->'x' = '{"ad":"grup","anahtar":["xy","x_y_siz"],
                               "deger":["E2E-ETK-A + E2E-ETK-B içeren","E2E-ETK-A içeren, E2E-ETK-B''siz"]}'
                AND z->'yetersiz' = 'true' AND z->'n' = '2' AND z#>'{sayac,kiyas_n}' = '14' THEN 'PASS' ELSE 'FAIL' END,
  etiket = coalesce((z->'x')::text, '∅') || ' n=' || coalesce(z->>'n', '∅')
FROM pg_temp._st4_z('C2', 'saglik_basari') z WHERE kod = 'xy_grup';
-- Tablo tests/unit/istatistik-grafik.test.js'te gerçek _kombinasyonSiz ile de koşar (aynı girdi, aynı çıktı).
WITH t(y, ek) AS (VALUES
-- EK-TABLO-BAS
  ('Enrolen', 'siz'),
  ('Meloksikam', 'sız'),
  ('Halocur', 'suz'),
  ('Tilmikosin', 'siz'),
  ('Antibiyo', 'suz'),
  ('Gözlük', 'süz'),
  ('Köpö', 'süz'),
  ('NSAİİ', 'siz'),
  ('KISIM', 'sız'),
  ('HALOCUR', 'suz'),
  ('ÖZÜ', 'süz'),
  ('ÜRÖ', 'süz'),
  ('Ara', 'sız'),
  ('Halofuginon', 'suz'),
  ('B12', 'siz'),
  ('Kâr', 'siz'),
  ('(bilinmiyor)', 'suz')
-- EK-TABLO-SON
), s AS (
  SELECT t.y, t.ek, (SELECT g.etiket
                     FROM _st4_c c, public.stat_atolye_gruplar_k(jsonb_set(c.c, '{ilac,y}', to_jsonb(t.y)),
                                                                 '{"vakalar":[],"ilac":[]}'::jsonb) g
                     WHERE c.ad = 'C2' AND g.anahtar = 'x_y_siz') AS e
  FROM t)
UPDATE _stat_durum SET
  deger = CASE WHEN (SELECT count(*) FROM s) = 17
                AND (SELECT bool_and(COALESCE(s.e = 'E2E-ETK-A içeren, ' || s.y || '''' || s.ek, false)) FROM s) THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'uymayan=' || coalesce((SELECT string_agg(coalesce(s.e, '∅'), ' | ')
                                   FROM s WHERE s.e IS NULL OR s.e <> 'E2E-ETK-A içeren, ' || s.y || '''' || s.ek), '-')
WHERE kod = 'xy_ek_uyumu';
UPDATE _stat_durum SET
  deger = CASE WHEN z#>'{seriler,0,n}' = '[2, 14]' AND z#>'{seriler,0,k}' = '[2, 11]' AND z#>'{seriler,0,y}' = '[null, 78.6]'
                AND z#>'{seriler,0,alt,0}' = 'null' AND z#>'{seriler,0,ust,0}' = 'null'
                AND z#>'{seriler,0,alt,1}' = to_jsonb((pg_temp._st4_wilson(11, 14))[1]) THEN 'PASS' ELSE 'FAIL' END,
  etiket = coalesce((z->'seriler')::text, '∅')
FROM pg_temp._st4_z('C2', 'saglik_basari') z WHERE kod = 'n_lt_5_null';
UPDATE _stat_durum SET
  deger = CASE WHEN z#>'{x,anahtar}' = '["ilac:E2E-ETK-A","ilac:E2E-ETK-B","ilac:(bilinmiyor)"]'
                AND z#>'{x,deger}' = '["E2E-ETK-A içeren","E2E-ETK-B içeren","(bilinmiyor) içeren"]'
                AND z#>'{seriler,0,n}' = '[1, 1, 2]' AND z#>'{sayac,bilinmiyor_n}' = '2' THEN 'PASS' ELSE 'FAIL' END,
  etiket = coalesce((z->'x')::text, '∅') || ' n=' || coalesce(z#>>'{seriler,0,n}', '∅')
FROM pg_temp._st4_z('C3', 'saglik_basari') z WHERE kod = 'kirilim_ilac_sira';

-- zaman kırılımı
UPDATE _stat_durum SET
  deger = CASE WHEN jsonb_array_length(z#>'{x,deger}') = 25 AND z#>'{x,ad}' = '"ay"'
                AND z#>'{x,deger,0}' = to_jsonb(to_char(:'t'::date - interval '24 months', 'YYYY-MM'))
                AND z#>'{x,anahtar,0}' = to_jsonb(date_trunc('month', :'t'::date - interval '24 months')::date)
                AND jsonb_array_length(z->'seriler') = 1 AND z#>'{seriler,0,ad}' = '"Tüm E2E-ST2-Enterit vakaları"'
                AND z#>'{seriler,0,anahtar}' = '"tumu"' AND z#>'{seriler,0,n,0}' = '0' AND z#>'{seriler,0,y,0}' = 'null'
                AND z#>'{seriler,0,n}' = x.bek_n AND z->'n' = '19' AND h->'egri' = 'null'
               THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'periyot=' || coalesce(jsonb_array_length(z#>'{x,deger}')::text, '∅') || ' n=' || coalesce(z#>>'{seriler,0,n}', '∅')
           || ' kâhin=' || x.bek_n::text
FROM pg_temp._st4_z('C4', 'saglik_basari') z, pg_temp._st4_z('C4', 'saglik_kapanma_gunu') h,
     (SELECT jsonb_agg(coalesce(c.n, 0) ORDER BY p.p) AS bek_n
        FROM generate_series(date_trunc('month', :'t'::date - interval '24 months'), date_trunc('month', :'t'::date::timestamp),
                             interval '1 month') p
        LEFT JOIN (SELECT date_trunc('month', (:'t'::date - k.bas_gun)::timestamp) AS m, count(*) AS n FROM _st4_k k
                    WHERE k.sonuc IN ('basarili', 'basarisiz_olum_kesim', 'basarisiz_nuks') GROUP BY 1) c ON c.m = p.p) x
WHERE kod = 'kirilim_ay';
UPDATE _stat_durum SET
  deger = CASE WHEN jsonb_array_length(q#>'{x,deger}') = (SELECT count(*) FROM generate_series(
                      date_trunc('quarter', :'t'::date - interval '24 months'), date_trunc('quarter', :'t'::date::timestamp), interval '3 months'))
                AND q#>'{x,deger,0}' = to_jsonb(to_char(:'t'::date - interval '24 months', 'YYYY "Ç"Q'))
                AND y#>'{x,deger}' = (SELECT jsonb_agg(to_char(p, 'YYYY') ORDER BY p) FROM generate_series(
                      date_trunc('year', :'t'::date - interval '24 months'), date_trunc('year', :'t'::date::timestamp), interval '1 year') p)
                AND (SELECT sum(e::int) FROM jsonb_array_elements_text(q#>'{seriler,0,n}') e) = 19
                AND (SELECT sum(e::int) FROM jsonb_array_elements_text(y#>'{seriler,0,n}') e) = 19 THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'çeyrek=' || coalesce((q#>'{x,deger}')::text, '∅') || ' yıl=' || coalesce((y#>'{x,deger}')::text, '∅')
FROM pg_temp._st4_z('C6', 'saglik_basari') q, pg_temp._st4_z('C7', 'saglik_basari') y WHERE kod = 'kirilim_ceyrek_yil';

-- dipnotlar
UPDATE _stat_durum SET
  deger = CASE WHEN e#>'{sayac,dislanan_ovsync_n}' = '3' AND e#>'{dipnot,0}' = '"Ovsync üreme protokolü vakaları dahil değil (3)."'
                AND k#>'{sayac,dislanan_ovsync_n}' = '4' AND k#>'{dipnot,0}' = '"Ovsync üreme protokolü vakaları dahil değil (4)."'
                AND k#>'{x,deger,0}' = '"Tüm E2E-ST2-Kat vakaları"' AND k#>'{seriler,0,n,0}' = '19'
                AND p#>'{sayac,dislanan_ovsync_n}' = '0'
                AND p->'dipnot' = '["Gruplar örtüşür: bir vaka birden çok satırda sayılır.",
                                    "2 vakanın ilacı tanınamadı: (bilinmiyor).",
                                    "Karşılaştırma gözlemseldir; şiddet/yaş eşleştirmesi yok."]' THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'Enterit=' || coalesce(e#>>'{sayac,dislanan_ovsync_n}', '∅') || ' kategori=' || coalesce(k#>>'{sayac,dislanan_ovsync_n}', '∅')
           || ' Pnomoni dipnot=' || coalesce((p->'dipnot')::text, '∅')
FROM pg_temp._st4_z('C1g', 'saglik_basari') e, pg_temp._st4_z('C5', 'saglik_basari') k, pg_temp._st4_z('C3', 'saglik_basari') p
WHERE kod = 'dipnot_ovsync';
UPDATE _stat_durum SET
  deger = CASE WHEN b->'dipnot' = x.ortak || x.son
                AND t->'dipnot' = x.ortak || '["1 vaka ilaç uygulanmadığı için ₺ ölçülerine girmedi.", "1 vakanın ilaç fiyatı yok."]'::jsonb
                                  || x.son
                AND c2->'dipnot' = (x.ortak - 'Gruplar örtüşür: bir vaka birden çok satırda sayılır.') || x.son
               THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'başarı=' || coalesce((b->'dipnot')::text, '∅') || ' | vaka_tl=' || coalesce((t->'dipnot')::text, '∅')
           || ' | C2=' || coalesce((c2->'dipnot')::text, '∅')
FROM pg_temp._st4_z('C1g', 'saglik_basari') b, pg_temp._st4_z('C1g', 'saglik_vaka_tl') t, pg_temp._st4_z('C2', 'saglik_basari') c2,
     (SELECT jsonb_build_array('Ovsync üreme protokolü vakaları dahil değil (3).',
                               'Gruplar örtüşür: bir vaka birden çok satırda sayılır.',
                               format('2 vaka toplu kapatılmış; kapanma günü son ilaç + %s gün ile tahmin edildi.', :'g'))
             || CASE WHEN :'normal_n'::int < 5 THEN '["Vekil G hesaplanamadı (normal vaka n<5); G=0 kullanıldı."]'::jsonb
                     ELSE '[]'::jsonb END
             || '["1 vaka kapalı ama kapanış tarihi yok; hesaba girmedi."]'::jsonb AS ortak,
             '["Karşılaştırma gözlemseldir; şiddet/yaş eşleştirmesi yok."]'::jsonb AS son) x
WHERE kod = 'dipnot_sira';

-- tek ilaç grubu / boş kapsam: örtüşen grup yok → örtüşür dipnotu basılmaz (review tur1 #1)
UPDATE _stat_durum SET
  deger = CASE WHEN a#>'{x,anahtar}' = '["ilac:E2E-ETK-A"]' AND a#>'{seriler,0,n}' = '[1]' AND a->'dipnot' = '[]'
                AND b#>'{x,anahtar}' = '[]' AND b->'seriler' = '[]' AND b->'n' = '0' AND b->'dipnot' = '[]'
               THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'tek grup x=' || coalesce((a#>'{x,anahtar}')::text, '∅') || ' dipnot=' || coalesce((a->'dipnot')::text, '∅')
           || ' | boş x=' || coalesce((b#>'{x,anahtar}')::text, '∅') || ' dipnot=' || coalesce((b->'dipnot')::text, '∅')
FROM pg_temp._st4_z('C8', 'saglik_basari') a, pg_temp._st4_z('C9', 'saglik_basari') b WHERE kod = 'ortusur_tek_grup';

-- sürüm, kombinasyon, eğri
UPDATE _stat_durum SET
  deger = CASE WHEN x.toplam > 0 AND x.toplam = x.uygun THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'zarf=' || x.toplam || ' uygun=' || x.uygun
FROM (SELECT count(*) AS toplam,
             count(*) FILTER (WHERE z->>'surum' LIKE 'sql:2026101700000%' AND z->>'tanim' = z->>'olcum'
                                AND z->>'hesap_at' IS NOT NULL) AS uygun
        FROM _st4_r r, jsonb_array_elements(r.r->'zarflar') z) x
WHERE kod = 'surum_onek';
UPDATE _stat_durum SET
  deger = CASE WHEN x.n = 11 AND x.ok = 11 THEN 'PASS' ELSE 'FAIL' END, etiket = 'sonuç=' || x.n || ' uygun=' || x.ok
-- T5 sonrası: x'li 4 sonuç (C1g, C1, C1sa, C2) panel nesnesi taşır, x'siz 7 sonuç null kalır (elle sabit liste)
FROM (SELECT count(*) AS n, count(*) FILTER (WHERE r ? 'kombinasyon' AND jsonb_typeof(r->'zarflar') = 'array'
                                               AND CASE WHEN ad IN ('C1g', 'C1', 'C1sa', 'C2')
                                                        THEN jsonb_typeof(r#>'{kombinasyon,satirlar}') = 'array'
                                                        ELSE r->'kombinasyon' = 'null' END) AS ok FROM _st4_r) x
WHERE kod = 'kombinasyon_null';
UPDATE _stat_durum SET
  deger = CASE WHEN z->'egri' = x.bek
                AND (SELECT bool_and(e#>'{oran,-1}' = '1.000') FROM jsonb_array_elements(z->'egri') e)
                AND (SELECT bool_and(o.v >= coalesce(o.onceki, 0)) FROM (
                       SELECT (e2.v)::numeric AS v, lag((e2.v)::numeric) OVER (PARTITION BY e.i ORDER BY e2.j) AS onceki
                       FROM jsonb_array_elements(z->'egri') WITH ORDINALITY e(o, i),
                            jsonb_array_elements_text(e.o->'oran') WITH ORDINALITY e2(v, j)) o)
               THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'gelen=' || coalesce((z->'egri')::text, '∅') || ' kâhin=' || coalesce(x.bek::text, '∅')
FROM pg_temp._st4_z('C1g', 'saglik_kapanma_gunu') z,
     (SELECT jsonb_agg(jsonb_build_object('anahtar', g.a, 'gun', q.gun, 'oran', q.oran) ORDER BY g.s) AS bek
        FROM (VALUES (1, 'x', true), (2, 'tumu', false)) AS g(s, a, yalniz_a)
        CROSS JOIN LATERAL (
          SELECT jsonb_agg(w.d ORDER BY w.d) AS gun, jsonb_agg(round(w.c / w.n, 3) ORDER BY w.d) AS oran
          FROM (SELECT k.kgi AS d, sum(count(*)) OVER (ORDER BY k.kgi) AS c, sum(count(*)) OVER () AS n
                  FROM _st4_k k WHERE k.durum = 'sonuclandi' AND k.kgi IS NOT NULL AND (k.a OR NOT g.yalniz_a)
                 GROUP BY k.kgi) w) q) x
WHERE kod = 'egri_monoton';

-- ACL + INVOKER
DROP TABLE IF EXISTS _st4_fn;
CREATE TEMP TABLE _st4_fn(imza text PRIMARY KEY, oynak char);
INSERT INTO _st4_fn VALUES
  ('public.stat_cumle_dogrula(jsonb)', 's'), ('public.stat_cumle_donem(jsonb)', 's'), ('public.stat_wilson(integer,integer)', 'i'),
  ('public.stat_atolye_gruplar(jsonb)', 's'), ('public.stat_atolye_kombinasyon(jsonb,jsonb)', 's'),
  ('public.stat_atolye_seri(jsonb,jsonb)', 's');
UPDATE _stat_durum SET
  deger = CASE WHEN x.anon_fn = 0 AND x.au_fn = 6 AND x.pub_fn = 0 THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'anon=' || x.anon_fn || ' public=' || x.pub_fn || ' authenticated=' || x.au_fn
FROM (SELECT count(*) FILTER (WHERE has_function_privilege('anon', imza, 'EXECUTE')) AS anon_fn,
             count(*) FILTER (WHERE has_function_privilege('authenticated', imza, 'EXECUTE')) AS au_fn,
             count(*) FILTER (WHERE EXISTS (SELECT 1 FROM pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
                                              WHERE p.oid = imza::regprocedure AND a.grantee = 0)) AS pub_fn
        FROM _st4_fn) x
WHERE kod = 'seri_acl';
BEGIN;
SELECT public.stat_atolye_seri(:'c1'::jsonb, :'gec'::jsonb)::text AS pg_r \gset
SET LOCAL ROLE authenticated;
SELECT public.stat_atolye_seri(:'c1'::jsonb, :'gec'::jsonb)::text AS au_r \gset
ROLLBACK;
\if :{?au_r}
\else
\set au_r hata
\endif
UPDATE _stat_durum SET
  deger = CASE WHEN x.fn_ok = 6 AND :'pg_r' = :'au_r' AND length(:'pg_r') > 100 THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'fn uygun=' || x.fn_ok || '/6 authenticated=postgres: ' || (:'pg_r' = :'au_r')::text
FROM (SELECT count(*) AS fn_ok FROM _st4_fn f JOIN pg_proc p ON p.oid = f.imza::regprocedure
       WHERE NOT p.prosecdef AND p.provolatile = f.oynak AND 'search_path=public, pg_temp' = ANY (p.proconfig)) x
WHERE kod = 'seri_invoker';
UPDATE _stat_durum SET
  deger = CASE WHEN x.anon_fn = 0 AND x.pub_fn = 0 AND x.au_fn = 3 AND x.fn_ok = 3 THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'anon=' || x.anon_fn || ' public=' || x.pub_fn || ' authenticated=' || x.au_fn || ' invoker/stable/search_path=' || x.fn_ok
FROM (SELECT count(*) FILTER (WHERE has_function_privilege('anon', f.oid, 'EXECUTE')) AS anon_fn,
             count(*) FILTER (WHERE has_function_privilege('authenticated', f.oid, 'EXECUTE')) AS au_fn,
             count(*) FILTER (WHERE EXISTS (SELECT 1 FROM aclexplode(coalesce(f.proacl, acldefault('f', f.proowner))) a
                                             WHERE a.grantee = 0)) AS pub_fn,
             count(*) FILTER (WHERE NOT f.prosecdef AND f.provolatile = 's' AND 'search_path=public, pg_temp' = ANY (f.proconfig)) AS fn_ok
        FROM pg_proc f
       WHERE f.oid IN (to_regprocedure('public.stat_cumle_kapsam(jsonb)'), to_regprocedure('public.stat_atolye_gruplar_k(jsonb,jsonb)'),
                       to_regprocedure('public.stat_atolye_kombinasyon_k(jsonb,jsonb,jsonb)'))) x
WHERE kod = 'kapsam_acl_invoker';

-- TS1 (cümleler _st4_r dışında: kombinasyon_null ve surum_onek o tablonun satır sayısını sabitler)
DROP TABLE IF EXISTS _st4_ts;
CREATE TEMP TABLE _st4_ts(ad text PRIMARY KEY, r jsonb);
INSERT INTO _st4_ts SELECT 'C10', public.stat_atolye_seri(jsonb_set(c, '{ilac,x}', 'null')
    || '{"hastalik":{"tip":"hastalik","deger":"e2e57201-0000-4000-8000-000000000006"},"kiyas_grubu":"tumu"}', :'gec')
  FROM _st4_c WHERE ad = 'C1';
INSERT INTO _st4_ts SELECT 'C11', public.stat_atolye_seri(jsonb_set(c, '{ilac,x}', 'null')
    || '{"hastalik":{"tip":"hastalik","deger":"e2e57201-0000-4000-8000-000000000006"},"kiyas_grubu":"tumu","kirilim":"ilac","olculer":["saglik_basari"]}', :'gec')
  FROM _st4_c WHERE ad = 'C1';
CREATE FUNCTION pg_temp._st4_tz(p_ad text, p_olcum text) RETURNS jsonb LANGUAGE sql AS $f$
  SELECT z FROM _st4_ts r, jsonb_array_elements(r.r->'zarflar') z WHERE r.ad = p_ad AND z->>'olcum' = p_olcum;
$f$;
UPDATE _stat_durum SET
  deger = CASE WHEN z#>'{seriler,0,n}' = '[10]' AND z#>'{seriler,0,k}' = '[5]' AND z#>'{seriler,0,y}' = '[50.0]' THEN 'PASS' ELSE 'FAIL' END,
  etiket = coalesce((z->'seriler')::text, '∅')
FROM pg_temp._st4_tz('C10', 'saglik_basari') z WHERE kod = 'basari_payda_tedavi_degisti';
UPDATE _stat_durum SET
  deger = CASE WHEN z#>'{seriler,0,n}' = '[8]' AND z#>'{seriler,0,y}' = '[4.5]' AND z#>'{seriler,0,q1}' = '[4.0]' AND z#>'{seriler,0,q3}' = '[5.0]'
                AND z->'egri' = '[{"anahtar":"tumu","gun":[3,4,5],"oran":[0.125,0.500,1.000]}]'
                AND z#>'{sayac,kapali_tarihsiz_n}' = '0' AND z#>'{sayac,acik_n}' = '0' AND z#>'{sayac,olgunlasmamis_n}' = '0'
                AND z#>'{sayac,vekil_n}' = '0' AND NOT (z->>'dipnot') LIKE '%kapanış tarihi yok%' THEN 'PASS' ELSE 'FAIL' END,
  etiket = coalesce((z->'seriler')::text, '∅') || ' egri=' || coalesce((z->'egri')::text, '∅') || ' sayac=' || coalesce((z->'sayac')::text, '∅')
FROM pg_temp._st4_tz('C10', 'saglik_kapanma_gunu') z WHERE kod = 'hiz_disi_tedavi_degisti';
UPDATE _stat_durum SET
  deger = CASE WHEN s#>'{seriler,0,n}' = '[9]' AND s#>'{seriler,0,y}' = '[1.0]' AND t#>'{seriler,0,n}' = '[9]' AND t#>'{seriler,0,y}' = '[20.00]'
                AND b#>'{seriler,0,n}' = '[5]' AND b#>'{seriler,0,y}' = '[46.00]' THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'tedavi=' || coalesce((s->'seriler')::text, '∅') || ' vaka_tl=' || coalesce((t->'seriler')::text, '∅')
           || ' basari_tl=' || coalesce((b->'seriler')::text, '∅')
FROM pg_temp._st4_tz('C10', 'saglik_tedavi_suresi') s, pg_temp._st4_tz('C10', 'saglik_vaka_tl') t, pg_temp._st4_tz('C10', 'saglik_basari_tl') b
WHERE kod = 'tedavi_sure_tl_icinde';
UPDATE _stat_durum SET
  deger = CASE WHEN NOT EXISTS (SELECT 1 FROM jsonb_object_keys(z->'sayac') k WHERE k LIKE '%nuks%')
                AND x.nuks = 1 AND x.td = 2 THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'sayaç anahtarları=' || (SELECT string_agg(k, ',' ORDER BY k) FROM jsonb_object_keys(z->'sayac') k)
           || ' liste nuks=' || x.nuks || ' tedavi_degisti=' || x.td
FROM pg_temp._st4_tz('C10', 'saglik_basari') z,
     (SELECT count(*) FILTER (WHERE v->>'sonuc' = 'basarisiz_nuks') AS nuks,
             count(*) FILTER (WHERE v->>'sonuc' = 'basarisiz_tedavi_degisti') AS td
        FROM _st4_c c, jsonb_array_elements(public.stat_atolye_vakalar(jsonb_set(c.c, '{ilac,x}', 'null')
               || '{"hastalik":{"tip":"hastalik","deger":"e2e57201-0000-4000-8000-000000000006"},"kiyas_grubu":"tumu"}', 'tumu')->'vakalar') v
       WHERE c.ad = 'C1') x
WHERE kod = 'nuks_sayac_disi';
UPDATE _stat_durum SET
  deger = CASE WHEN (SELECT count(*) = 5 AND bool_and(COALESCE(z#>'{sayac,tedavi_degisti_n}' = '2'
                                                      AND z->'dipnot' ? '2 vaka 24 saat içinde yeniden açıldı (tedavi değişti).', false))
                       FROM _st4_ts r, jsonb_array_elements(r.r->'zarflar') z WHERE r.ad = 'C10')
                AND COALESCE(c11#>'{sayac,tedavi_degisti_n}' = '1'
                             AND c11->'dipnot' ? '1 vaka 24 saat içinde yeniden açıldı (tedavi değişti).', false)
                AND COALESCE(e#>'{sayac,tedavi_degisti_n}' = '0', false) AND NOT (e->>'dipnot') LIKE '%yeniden açıldı%' THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'C10=' || coalesce((pg_temp._st4_tz('C10', 'saglik_basari')->'dipnot')::text, '∅')
           || ' C11 n=' || coalesce(c11#>>'{sayac,tedavi_degisti_n}', '∅') || ' Enterit n=' || coalesce(e#>>'{sayac,tedavi_degisti_n}', '∅')
FROM pg_temp._st4_tz('C11', 'saglik_basari') c11, pg_temp._st4_z('C1g', 'saglik_basari') e
WHERE kod = 'dipnot_tedavi_degisti';

SELECT pg_temp._st2_temizle();
UPDATE _stat_durum SET deger = CASE WHEN pg_temp._st2_artik() = 0 THEN 'PASS' ELSE 'FAIL' END,
  etiket = 'artık=' || pg_temp._st2_artik()
WHERE kod = 'artik';
\endif

\echo '=== ÖZET ==='
SELECT kod, deger, etiket FROM _stat_durum ORDER BY kod;
SELECT 'TOPLAM: PASS=' || count(*) FILTER (WHERE deger = 'PASS') || ' FAIL=' || count(*) FILTER (WHERE deger = 'FAIL')
       || ' UNMEASURED=' || count(*) FILTER (WHERE deger = 'UNMEASURED') AS ozet FROM _stat_durum;
