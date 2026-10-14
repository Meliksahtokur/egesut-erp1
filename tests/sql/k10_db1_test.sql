-- tests/sql/k10_db1_test.sql — DB-1 adli testler: S-DB1-sablon-tai-son-pg + MUT-SON-PG-KAZANMAZ probu
--   + S-DB1-gun-tekil, S-DB1-cift-tik, S-DB1-ertele-iptalsiz, S-DB1-pg-opsiyonel,
--   S-DB1-grant-tek, S-DB1-zincir + MUT-DB1-unique-yok, MUT-DB1-anon-acik
--   + B1 (null-sablonlu/null-mastit/kisir-null-ovsync) + ERT5 (alt-ozet: durum+sıra+ad).
-- HEDEF: YALNIZ yerel izole DB.
-- KOŞUM: psql "$ISO" -X -v ON_ERROR_STOP=1 -f tests/sql/k10_db1_test.sql → rc=0 PASS; rc!=0 RED.
-- Zemin: kur.sh + 000002..000005 sırayla (rc=0). kur.sh-only zeminde (yeni nesneler yok) KIRMIZI (FAIL).
-- S-KISIR ve S-PG bloklarına DOKUNULMAZ (ovsync_paketi_test.sql'dedir).
-- ROOT RULING 1: g8 = bg()-2, g9 = bg()-1; iki PG S-PG2 kalıbıyla
--   hizli_uygulama(…, p_occurred_at => <geçmiş gün> 10:00 Europe/Istanbul);
--   (i) g8 PG sonrası tek açık TOHUMLAMA_PLANLI hedef = bg() (= g10), şablon TAI PG_YERINE ile kapalı;
--   (ii) g9 PG sonrası tek açık TAI hedef = bg()+1 (= g11 = şablon TAI günü);
--   (iii) S-PG2 kalıbı aynen PASS.
-- ROOT RULING 2 (MUT-SON-PG-KAZANMAZ): _pg_sonrasi_tohumlama (20260923000003:331) içindeki PG_YERINE
--   iptal UPDATE'i kaldırılmış kopya izole DB'de CREATE OR REPLACE ile uygulanırsa prob hayvanında
--   2 açık TAI kalır → bu dosya FAIL verir (RED MEASURED); orijinal yedekten geri yüklenince PASS.
-- Faz 0 notu (Ruling): hizli_uygulama geçmiş an alt sınırı repo 20260923000003:580-581
--   `p_occurred_at < now() - interval '7 days'` → RED; g8/g9 (2 gün) kapsanır (yeşil koşumla ölçüldü).
-- treatment_day_tamamla ve _pg_sonrasi_tohumlama DEĞİŞMEZ (karakterizasyon; kilit yazılmaz).
-- Tüm fixture + RPC yan etkileri tek transaction'da, sonda ROLLBACK.
-- Sabit uuid: pg_temp.k10_id(sınıf, no) — a=OVSYNC vaka, e=gorev, f=ürün, 1=hastalık, 2=ilaç sınıfı, 3=şablon.
\echo '=== K10 DB-1 SABLON-TAI-SON-PG — izole DB testi ==='
BEGIN;
CREATE FUNCTION pg_temp.k10_id(p text, i int) RETURNS uuid LANGUAGE sql IMMUTABLE
  AS $$ SELECT ('a11ce000-0000-4000-8000-0000000' || p || '00' || lpad(i::text, 2, '0'))::uuid $$;
CREATE FUNCTION pg_temp.k10_bg() RETURNS date LANGUAGE sql STABLE AS $$ SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date $$;
DELETE FROM gorev_log WHERE hayvan_id LIKE 'K10-H-%'; DELETE FROM tohumlama WHERE hayvan_id LIKE 'K10-H-%';
DELETE FROM cases WHERE animal_id LIKE 'K10-H-%'; DELETE FROM hayvanlar WHERE id LIKE 'K10-H-%'; DELETE FROM stok WHERE id LIKE 'K10-%';
DELETE FROM drug_products WHERE brand_name LIKE 'K10-%'; DELETE FROM drug_classes WHERE group_name = 'K10';
DELETE FROM tedavi_sablonu WHERE ad LIKE 'K10-%'; DELETE FROM diseases WHERE name LIKE 'K10-%';
INSERT INTO protokol_ayar(anahtar, deger) VALUES ('ovsync_pg_kurallari_aktif', 1) ON CONFLICT (anahtar) DO UPDATE SET deger = 1;
INSERT INTO diseases(id, name, category) SELECT pg_temp.k10_id('1', i), 'K10-' || n, k
  FROM (VALUES (1, 'Ovsync', 'Üreme')) v(i, n, k);
INSERT INTO tedavi_sablonu(id, ad, protokol_ailesi) VALUES (pg_temp.k10_id('3',1), 'K10-OVSYNC', 'OVSYNC');
INSERT INTO sablon_hastalik_eslem(sablon_id, disease_id) VALUES (pg_temp.k10_id('3',1), pg_temp.k10_id('1',1));
INSERT INTO drug_classes(id, group_name, class_name, farmakolojik_sinif_kodu, etken_kod)
  VALUES (pg_temp.k10_id('2',1), 'K10', 'PG', 'PGF2A', 'PG');
INSERT INTO drug_products(id, drug_class_id, brand_name) VALUES (pg_temp.k10_id('f',1), pg_temp.k10_id('2',1), 'K10-PG');
INSERT INTO stok(id, urun_adi, kategori, birim, baslangic_miktar, drug_product_id)
  VALUES ('K10-STK-PG', 'K10-PG', 'İlaç', 'ml', 100, pg_temp.k10_id('f',1));
INSERT INTO hayvanlar(id, kupe_no, cinsiyet, durum, grup, padok, dogum_tarihi)
  SELECT 'K10-H-' || i, 'K10-' || i, 'Dişi', 'Aktif', 'Sağmal (Laktasyonda)', 'Sağmal Padok', pg_temp.k10_bg() - 800 FROM generate_series(1, 3) i;
-- K10-H-1: OVSYNC vaka + şablon TAI (hedef g11); K10-H-2: (iii) S-PG2 ertelenmiş TAI; K10-H-3: mutant probu TAI
INSERT INTO cases(id, animal_id, disease_id, start_date, status, protocol_family, source_template_id)
  VALUES (pg_temp.k10_id('a',1), 'K10-H-1', pg_temp.k10_id('1',1), pg_temp.k10_bg() - 3, 'active', 'OVSYNC', pg_temp.k10_id('3',1));
INSERT INTO gorev_log(id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, kaynak)
  VALUES (pg_temp.k10_id('e',1), 'K10-H-1', 'TOHUMLAMA_PLANLI', 'K10 sablon TAI (g11)',
          pg_temp.k10_bg() + 1, '09:00',
          'TEDAVI_SABLON_TOHUMLAMA:' || pg_temp.k10_id('a',1)::text || ':' || pg_temp.k10_id('3',1)::text),
         (pg_temp.k10_id('e',2), 'K10-H-2', 'TOHUMLAMA_PLANLI', 'K10 ertelenmis TAI',
          pg_temp.k10_bg() + 20, '10:00', 'K10-TAI:2'),
         (pg_temp.k10_id('e',3), 'K10-H-3', 'TOHUMLAMA_PLANLI', 'K10 mutant probu TAI',
          pg_temp.k10_bg() + 20, '10:00', 'K10-MUT:3');
CREATE TEMP TABLE _k10_durum(senaryo text PRIMARY KEY, sonuc text, kanit text);
CREATE TEMP TABLE _k10_ids(anahtar text PRIMARY KEY, deger uuid);

-- ── S-DB1-sablon-tai-son-pg (i): g8 PG → tek açık TAI hedef=bg() (=g10); şablon TAI PG_YERINE kapalı
DO $do$ DECLARE
  v_at timestamptz := ((pg_temp.k10_bg() - 2) + time '10:00') AT TIME ZONE 'Europe/Istanbul';
  v_r jsonb; v_n int; v_hedef date; v_eski text; v_zincir text; v_tai uuid;
BEGIN
  SELECT string_agg(check_clause, ' ') INTO v_zincir FROM information_schema.check_constraints
   WHERE constraint_name = 'pg_application_event_source_type_check';
  v_r := public.hizli_uygulama('K10-H-1', 'K10-STK-PG', 2, 'ml', 'IM', 'K10', p_occurred_at => v_at);
  SELECT count(*), min(hedef_tarih) INTO v_n, v_hedef FROM gorev_log
   WHERE hayvan_id = 'K10-H-1' AND gorev_tipi = 'TOHUMLAMA_PLANLI' AND NOT COALESCE(iptal, false) AND NOT COALESCE(tamamlandi, false);
  SELECT COALESCE(iptal, false) || '/' || COALESCE(tamamlandi, false) || '/' || COALESCE(kapatan_ref, '-') INTO v_eski
    FROM gorev_log WHERE id = pg_temp.k10_id('e',1);
  SELECT id INTO v_tai FROM gorev_log
   WHERE hayvan_id = 'K10-H-1' AND gorev_tipi = 'TOHUMLAMA_PLANLI' AND NOT COALESCE(iptal, false) AND NOT COALESCE(tamamlandi, false) LIMIT 1;
  INSERT INTO _k10_ids VALUES ('tai_g10', v_tai);
  INSERT INTO _k10_durum VALUES ('S-DB1-sablon-tai-son-pg',
    CASE WHEN v_zincir LIKE '%TEDAVI_GUN%' AND (v_r->>'ok')::boolean
      AND v_n = 1 AND v_hedef = pg_temp.k10_bg() AND v_eski LIKE 'true/true/PG_YERINE:%'
      THEN 'PASS' ELSE 'RED' END,
    format('(i) zincir000002=%s rpc ok=%s; acik TAI n=%s hedef=%s; sablon=%s',
      (v_zincir LIKE '%TEDAVI_GUN%'), v_r->>'ok', v_n, v_hedef, v_eski));
EXCEPTION WHEN OTHERS THEN INSERT INTO _k10_durum VALUES ('S-DB1-sablon-tai-son-pg', 'RED', '(i) ' || SQLERRM); END $do$;

-- ── S-DB1-sablon-tai-son-pg (ii): g9 PG → tek açık TAI hedef=bg()+1 (=g11); g10 TAI PG_YERINE kapalı
DO $do$ DECLARE
  v_at timestamptz := ((pg_temp.k10_bg() - 1) + time '10:00') AT TIME ZONE 'Europe/Istanbul';
  v_r jsonb; v_n int; v_hedef date; v_g10 text;
BEGIN
  v_r := public.hizli_uygulama('K10-H-1', 'K10-STK-PG', 2, 'ml', 'IM', 'K10', p_occurred_at => v_at);
  SELECT count(*), min(hedef_tarih) INTO v_n, v_hedef FROM gorev_log
   WHERE hayvan_id = 'K10-H-1' AND gorev_tipi = 'TOHUMLAMA_PLANLI' AND NOT COALESCE(iptal, false) AND NOT COALESCE(tamamlandi, false);
  SELECT COALESCE(iptal, false) || '/' || COALESCE(tamamlandi, false) || '/' || COALESCE(kapatan_ref, '-') INTO v_g10
    FROM gorev_log WHERE id = (SELECT deger FROM _k10_ids WHERE anahtar = 'tai_g10');
  UPDATE _k10_durum SET
    sonuc = CASE WHEN sonuc = 'PASS' AND (v_r->>'ok')::boolean AND v_n = 1 AND v_hedef = pg_temp.k10_bg() + 1
      AND v_g10 LIKE 'true/true/PG_YERINE:%' THEN 'PASS' ELSE 'RED' END,
    kanit = kanit || format(' | (ii) rpc ok=%s; acik TAI n=%s hedef=%s; g10=%s', v_r->>'ok', v_n, v_hedef, v_g10)
    WHERE senaryo = 'S-DB1-sablon-tai-son-pg';
EXCEPTION WHEN OTHERS THEN UPDATE _k10_durum SET sonuc = 'RED', kanit = kanit || ' | (ii) ' || SQLERRM
  WHERE senaryo = 'S-DB1-sablon-tai-son-pg'; END $do$;

-- ── S-DB1-sablon-tai-son-pg (iii): S-PG2 kalıbı aynen PASS (ertelenmiş TAI + g9 PG → eski PG_YERINE, yeni @+2g)
DO $do$ DECLARE
  v_at timestamptz := ((pg_temp.k10_bg() - 1) + time '10:00') AT TIME ZONE 'Europe/Istanbul';
  v_r jsonb; v_eski text; v_yeni text;
BEGIN
  v_r := public.hizli_uygulama('K10-H-2', 'K10-STK-PG', 2, 'ml', 'IM', 'K10', p_occurred_at => v_at);
  SELECT COALESCE(iptal, false) || '/' || COALESCE(tamamlandi, false) || '/' || COALESCE(kapatan_ref, '-') INTO v_eski
    FROM gorev_log WHERE id = pg_temp.k10_id('e',2);
  SELECT string_agg(kaynak || '@' || hedef_tarih, ',') INTO v_yeni FROM gorev_log
   WHERE hayvan_id = 'K10-H-2' AND gorev_tipi = 'TOHUMLAMA_PLANLI' AND NOT COALESCE(iptal, false) AND NOT COALESCE(tamamlandi, false);
  UPDATE _k10_durum SET
    sonuc = CASE WHEN sonuc = 'PASS' AND v_eski LIKE 'true/true/PG_YERINE:%' AND v_yeni NOT LIKE '%,%'
      AND v_yeni LIKE 'PG_TOHUMLAMA:%@' || ((v_at AT TIME ZONE 'Europe/Istanbul')::date + 2) THEN 'PASS' ELSE 'RED' END,
    kanit = kanit || format(' | (iii) eski=%s; acik TAI=%s', v_eski, v_yeni)
    WHERE senaryo = 'S-DB1-sablon-tai-son-pg';
EXCEPTION WHEN OTHERS THEN UPDATE _k10_durum SET sonuc = 'RED', kanit = kanit || ' | (iii) ' || SQLERRM
  WHERE senaryo = 'S-DB1-sablon-tai-son-pg'; END $do$;

-- ── MUT-SON-PG-KAZANMAZ probu: prob hayvanında tek PG → orijinalde 1 açık TAI (PASS);
--    PG_YERINE UPDATE'siz mutant gövdede 2 açık TAI (RED — mutant doğrular, restore sonrası PASS)
DO $do$ DECLARE
  v_at timestamptz := ((pg_temp.k10_bg() - 1) + time '10:00') AT TIME ZONE 'Europe/Istanbul';
  v_r jsonb; v_n int;
BEGIN
  v_r := public.hizli_uygulama('K10-H-3', 'K10-STK-PG', 2, 'ml', 'IM', 'K10', p_occurred_at => v_at);
  SELECT count(*) INTO v_n FROM gorev_log
   WHERE hayvan_id = 'K10-H-3' AND gorev_tipi = 'TOHUMLAMA_PLANLI' AND NOT COALESCE(iptal, false) AND NOT COALESCE(tamamlandi, false);
  INSERT INTO _k10_durum VALUES ('MUT-SON-PG-KAZANMAZ',
    CASE WHEN v_n = 1 THEN 'PASS' ELSE 'RED' END,
    format('prob acik TAI n=%s (orijinalde 1; PG_YERINE-siz mutantta 2)', v_n));
EXCEPTION WHEN OTHERS THEN INSERT INTO _k10_durum VALUES ('MUT-SON-PG-KAZANMAZ', 'RED', SQLERRM); END $do$;

-- ── DB-1 hastalık-günü fixture (K10-H-4..7; her senaryo kendi vakasında izole) ──
INSERT INTO diseases(id, name, category)
  SELECT pg_temp.k10_id('1', 2), 'K10-Hastalik', 'Üreme'
  WHERE NOT EXISTS (SELECT 1 FROM diseases WHERE id = pg_temp.k10_id('1', 2));
INSERT INTO hayvanlar(id, kupe_no, cinsiyet, durum, grup, padok, dogum_tarihi)
  SELECT 'K10-H-' || i, 'K10-' || i, 'Dişi', 'Aktif', 'Sağmal (Laktasyonda)', 'Sağmal Padok', pg_temp.k10_bg() - 800 FROM generate_series(4, 7) i;
INSERT INTO cases(id, animal_id, disease_id, start_date, status, protocol_family)
  SELECT pg_temp.k10_id('a', i), 'K10-H-' || i, pg_temp.k10_id('1', 1), pg_temp.k10_bg() - 3, 'active', 'OVSYNC' FROM generate_series(4, 7) i;
INSERT INTO gorev_log(id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, kaynak)
  SELECT pg_temp.k10_id('e', i), 'K10-H-' || i, 'TOHUMLAMA_PLANLI', 'K10 TAI ' || i,
         pg_temp.k10_bg() + 2, '10:00', 'K10-TAI:' || i FROM generate_series(4, 7) i;

-- ── B1 null-aile fixture (K10-H-8..11): a8 eşleme-kolu, a9 log-kolu, a10 izsiz (Mastit),
--   a11 kısır (izli), a12 H-11'in ikinci izsiz vakası (kısır negatif kolu) ──
INSERT INTO diseases(id, name, category) SELECT pg_temp.k10_id('1', 3), 'K10-Mastit', 'Üreme'
  WHERE NOT EXISTS (SELECT 1 FROM diseases WHERE id = pg_temp.k10_id('1', 3));
INSERT INTO hayvanlar(id, kupe_no, cinsiyet, durum, grup, padok, dogum_tarihi)
  SELECT 'K10-H-' || i, 'K10-' || i, 'Dişi', 'Aktif', 'Sağmal (Laktasyonda)', 'Sağmal Padok', pg_temp.k10_bg() - 800 FROM generate_series(8, 11) i;
INSERT INTO cases(id, animal_id, disease_id, start_date, status, protocol_family)
  VALUES (pg_temp.k10_id('a',8), 'K10-H-8', pg_temp.k10_id('1',1), pg_temp.k10_bg()-3, 'active', NULL),
         (pg_temp.k10_id('a',9), 'K10-H-9', pg_temp.k10_id('1',2), pg_temp.k10_bg()-3, 'active', NULL),
         (pg_temp.k10_id('a',10), 'K10-H-10', pg_temp.k10_id('1',3), pg_temp.k10_bg()-3, 'active', NULL),
         (pg_temp.k10_id('a',11), 'K10-H-11', pg_temp.k10_id('1',1), pg_temp.k10_bg()-3, 'active', NULL),
         (pg_temp.k10_id('a',12), 'K10-H-11', pg_temp.k10_id('1',2), pg_temp.k10_bg()-3, 'active', NULL);
INSERT INTO gorev_log(id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, kaynak)
  VALUES (pg_temp.k10_id('e',9), 'K10-H-9', 'TOHUMLAMA_PLANLI', 'K10 sablon TAI a9',
          pg_temp.k10_bg()+2, '10:00',
          'TEDAVI_SABLON_TOHUMLAMA:' || pg_temp.k10_id('a',9)::text || ':' || pg_temp.k10_id('3',1)::text),
         (pg_temp.k10_id('e',10), 'K10-H-10', 'TOHUMLAMA_PLANLI', 'K10 duz TAI a10',
          pg_temp.k10_bg()+2, '10:00', 'K10-TAI:10');

-- ── S-DB1-gun-tekil: aynı vaka+hastalık+tarih iki kez → ikinci çağrı aynı günü döner, ilaç tekrar yazılmaz ──
DO $do$ DECLARE
  v_d date := pg_temp.k10_bg() + 2;
  v_r1 jsonb; v_r2 jsonb; v_c1 int; v_c2 int; v_idx text;
BEGIN
  SELECT indexdef INTO v_idx FROM pg_indexes
   WHERE schemaname = 'public' AND indexname = 'treatment_days_hastalik_gun_uniq';
  v_r1 := public.ovsync_hastalik_gunu_ekle(pg_temp.k10_id('a', 4), pg_temp.k10_id('1', 2), v_d, 7, '[{"dose": 5, "unit": "ml"}]');
  SELECT count(*) INTO v_c1 FROM drug_administrations da JOIN treatment_days td ON td.id = da.treatment_day_id
   WHERE td.case_id = pg_temp.k10_id('a', 4) AND td.disease_id = pg_temp.k10_id('1', 2) AND td.treatment_date = v_d;
  v_r2 := public.ovsync_hastalik_gunu_ekle(pg_temp.k10_id('a', 4), pg_temp.k10_id('1', 2), v_d, 7, '[{"dose": 5, "unit": "ml"}]');
  SELECT count(*) INTO v_c2 FROM drug_administrations da JOIN treatment_days td ON td.id = da.treatment_day_id
   WHERE td.case_id = pg_temp.k10_id('a', 4) AND td.disease_id = pg_temp.k10_id('1', 2) AND td.treatment_date = v_d;
  INSERT INTO _k10_durum VALUES ('S-DB1-gun-tekil',
    CASE WHEN (v_r1->>'ok')::boolean AND COALESCE((v_r1->>'mevcut')::boolean, false) = false
      AND (v_r2->>'ok')::boolean AND COALESCE((v_r2->>'mevcut')::boolean, false) = true
      AND (v_r1->>'gun_id') = (v_r2->>'gun_id') AND (v_r2->>'ertelenen')::int = 0 AND (v_r2->>'ilac')::int = 0
      AND v_c1 = 1 AND v_c2 = 1
      AND v_idx IS NOT NULL AND v_idx ILIKE '%disease_id IS NOT NULL%'
      THEN 'PASS' ELSE 'RED' END,
    format('cagri1 ok=%s mevcut=%s gun=%s; cagri2 ok=%s mevcut=%s gun=%s ertelenen=%s ilac=%s; ilac_satir %s->%s; kismi-unique=%s',
      v_r1->>'ok', v_r1->>'mevcut', left(v_r1->>'gun_id', 8), v_r2->>'ok', v_r2->>'mevcut',
      left(v_r2->>'gun_id', 8), v_r2->>'ertelenen', v_r2->>'ilac', v_c1, v_c2, (v_idx IS NOT NULL)));
EXCEPTION WHEN OTHERS THEN INSERT INTO _k10_durum VALUES ('S-DB1-gun-tekil', 'RED', 'onkoşul yok (kur-only): ' || SQLERRM); END $do$;

-- ── S-DB1-cift-tik: çift çağrı tek treatment_days satırı düşürür ──
DO $do$ DECLARE
  v_d date := pg_temp.k10_bg() + 3;
  v_g1 uuid; v_g2 uuid; v_n int;
BEGIN
  SELECT (public.ovsync_hastalik_gunu_ekle(pg_temp.k10_id('a', 5), pg_temp.k10_id('1', 2), v_d, 7, '[]')->>'gun_id')::uuid INTO v_g1;
  SELECT (public.ovsync_hastalik_gunu_ekle(pg_temp.k10_id('a', 5), pg_temp.k10_id('1', 2), v_d, 7, '[]')->>'gun_id')::uuid INTO v_g2;
  SELECT count(*) INTO v_n FROM treatment_days
   WHERE case_id = pg_temp.k10_id('a', 5) AND disease_id = pg_temp.k10_id('1', 2) AND treatment_date = v_d;
  INSERT INTO _k10_durum VALUES ('S-DB1-cift-tik',
    CASE WHEN v_g1 IS NOT NULL AND v_g1 = v_g2 AND v_n = 1 THEN 'PASS' ELSE 'RED' END,
    format('gun1=%s gun2=%s satir=%s', left(v_g1::text, 8), left(v_g2::text, 8), v_n));
EXCEPTION WHEN OTHERS THEN INSERT INTO _k10_durum VALUES ('S-DB1-cift-tik', 'RED', 'onkoşul yok (kur-only): ' || SQLERRM); END $do$;

-- ── S-DB1-ertele-iptalsiz: erteleme TAI'yi +7 öteler, iptal=false ──
DO $do$ DECLARE
  v_eski date; v_yeni date; v_iptal boolean; v_tam boolean; v_r jsonb; v_n int;
BEGIN
  SELECT hedef_tarih INTO v_eski FROM gorev_log WHERE id = pg_temp.k10_id('e', 6);
  v_r := public.ovsync_hastalik_gunu_ekle(pg_temp.k10_id('a', 6), pg_temp.k10_id('1', 2), pg_temp.k10_bg() + 4, 7, '[]');
  SELECT hedef_tarih, COALESCE(iptal, false), COALESCE(tamamlandi, false) INTO v_yeni, v_iptal, v_tam
    FROM gorev_log WHERE id = pg_temp.k10_id('e', 6);
  v_n := COALESCE((v_r->>'ertelenen')::int, -1);
  INSERT INTO _k10_durum VALUES ('S-DB1-ertele-iptalsiz',
    CASE WHEN COALESCE((v_r->>'ok')::boolean, false) AND v_n >= 1
      AND v_yeni = v_eski + 7 AND v_iptal = false AND v_tam = false THEN 'PASS' ELSE 'RED' END,
    format('ok=%s ertelenen=%s; TAI %s->%s iptal=%s tamamlandi=%s', v_r->>'ok', v_n, v_eski, v_yeni, v_iptal, v_tam));
EXCEPTION WHEN OTHERS THEN INSERT INTO _k10_durum VALUES ('S-DB1-ertele-iptalsiz', 'RED', 'onkoşul yok (kur-only): ' || SQLERRM); END $do$;

-- ── S-DB1-pg-opsiyonel: 5. gün PG zorunlu değil — ilaçsız çağrı ok, PG otomatik yazılmaz, TAI +5 ──
DO $do$ DECLARE
  v_eski date; v_yeni date; v_iptal boolean; v_r jsonb; v_ilac int;
BEGIN
  SELECT hedef_tarih INTO v_eski FROM gorev_log WHERE id = pg_temp.k10_id('e', 7);
  v_r := public.ovsync_hastalik_gunu_ekle(pg_temp.k10_id('a', 7), pg_temp.k10_id('1', 2), pg_temp.k10_bg() + 4, 5, '[]');
  SELECT count(*) INTO v_ilac FROM drug_administrations da JOIN treatment_days td ON td.id = da.treatment_day_id
   WHERE td.case_id = pg_temp.k10_id('a', 7) AND td.disease_id = pg_temp.k10_id('1', 2);
  SELECT hedef_tarih, COALESCE(iptal, false) INTO v_yeni, v_iptal FROM gorev_log WHERE id = pg_temp.k10_id('e', 7);
  INSERT INTO _k10_durum VALUES ('S-DB1-pg-opsiyonel',
    CASE WHEN COALESCE((v_r->>'ok')::boolean, false) AND COALESCE((v_r->>'mevcut')::boolean, true) = false
      AND v_ilac = 0 AND v_yeni = v_eski + 5 AND v_iptal = false THEN 'PASS' ELSE 'RED' END,
    format('ok=%s mevcut=%s; gun_ilac_satir=%s (PG otomatik yok); TAI %s->%s iptal=%s',
      v_r->>'ok', v_r->>'mevcut', v_ilac, v_eski, v_yeni, v_iptal));
EXCEPTION WHEN OTHERS THEN INSERT INTO _k10_durum VALUES ('S-DB1-pg-opsiyonel', 'RED', 'onkoşul yok (kur-only): ' || SQLERRM); END $do$;

-- ── S-DB1-grant-tek: ovsync_hastalik_gunu_ekle tek imza, anon EXECUTE yok ──
DO $do$ DECLARE
  v_c int; v_anon int;
BEGIN
  SELECT count(*) INTO v_c FROM pg_proc WHERE proname = 'ovsync_hastalik_gunu_ekle';
  SELECT count(*) INTO v_anon FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'ovsync_hastalik_gunu_ekle'
     AND has_function_privilege('anon', p.oid, 'EXECUTE');
  INSERT INTO _k10_durum VALUES ('S-DB1-grant-tek',
    CASE WHEN v_c = 1 AND v_anon = 0 THEN 'PASS' ELSE 'RED' END,
    format('pg_proc sayim=%s (beklenen 1); anon EXECUTE=%s (beklenen 0)', v_c, v_anon));
EXCEPTION WHEN OTHERS THEN INSERT INTO _k10_durum VALUES ('S-DB1-grant-tek', 'RED', SQLERRM); END $do$;

-- ── S-DB1-zincir: 000002..000005 zincir izleri (kur.sh-only zeminde RED) ──
DO $do$ DECLARE
  v_chk text; v_kolon int; v_idx text; v_rpc int; v_dinle text; v_rozet text;
BEGIN
  SELECT string_agg(check_clause, ' ') INTO v_chk FROM information_schema.check_constraints
   WHERE constraint_name = 'pg_application_event_source_type_check';
  SELECT count(*) INTO v_kolon FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'treatment_days' AND column_name = 'disease_id';
  SELECT indexdef INTO v_idx FROM pg_indexes
   WHERE schemaname = 'public' AND indexname = 'treatment_days_hastalik_gun_uniq';
  SELECT count(*) INTO v_rpc FROM pg_proc WHERE proname = 'ovsync_hastalik_gunu_ekle';
  SELECT pg_get_functiondef(p.oid) INTO v_dinle FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'fn_dinle_uygulama' LIMIT 1;
  SELECT pg_get_functiondef(p.oid) INTO v_rozet FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'ovsync_takip_listele' LIMIT 1;
  INSERT INTO _k10_durum VALUES ('S-DB1-zincir',
    CASE WHEN v_chk LIKE '%TEDAVI_GUN%' AND v_chk LIKE '%ILAC_EKLE%'
      AND v_kolon = 1 AND v_idx ILIKE '%disease_id IS NOT NULL%' AND v_rpc = 1
      AND v_dinle ILIKE '%_etken_kod_bul%' AND v_rozet ILIKE '%alt_vakalar%'
      THEN 'PASS' ELSE 'RED' END,
    format('000002 CHECK gun/ilac=%s/%s; 000003 kolon=%s uniq=%s rpc=%s; 000004 dinle-kopru=%s; 000005 rozet=%s',
      (v_chk LIKE '%TEDAVI_GUN%'), (v_chk LIKE '%ILAC_EKLE%'), v_kolon, (v_idx IS NOT NULL), v_rpc,
      (v_dinle ILIKE '%_etken_kod_bul%'), (v_rozet ILIKE '%alt_vakalar%')));
EXCEPTION WHEN OTHERS THEN INSERT INTO _k10_durum VALUES ('S-DB1-zincir', 'RED', SQLERRM); END $do$;

-- ── S-DB1-null-sablonlu: NULL aile + Ovsync izi (a8 eşleme-kolu, a9 log-kolu) → PASS ──
DO $do$ DECLARE
  v_r8 jsonb; v_r9 jsonb; v_n8 int; v_n9 int;
BEGIN
  v_r8 := public.ovsync_hastalik_gunu_ekle(pg_temp.k10_id('a',8), pg_temp.k10_id('1',2), pg_temp.k10_bg()+4, 7, '[]');
  v_r9 := public.ovsync_hastalik_gunu_ekle(pg_temp.k10_id('a',9), pg_temp.k10_id('1',2), pg_temp.k10_bg()+4, 7, '[]');
  SELECT count(*) INTO v_n8 FROM treatment_days WHERE case_id = pg_temp.k10_id('a',8);
  SELECT count(*) INTO v_n9 FROM treatment_days WHERE case_id = pg_temp.k10_id('a',9);
  INSERT INTO _k10_durum VALUES ('S-DB1-null-sablonlu',
    CASE WHEN COALESCE((v_r8->>'ok')::boolean, false) AND COALESCE((v_r9->>'ok')::boolean, false)
      AND v_n8 = 1 AND v_n9 = 1 THEN 'PASS' ELSE 'RED' END,
    format('esleme-kolu(a8) ok=%s gun=%s; log-kolu(a9) ok=%s gun=%s', v_r8->>'ok', v_n8, v_r9->>'ok', v_n9));
EXCEPTION WHEN OTHERS THEN INSERT INTO _k10_durum VALUES ('S-DB1-null-sablonlu', 'RED', SQLERRM); END $do$;

-- ── S-DB1-null-mastit: NULL aile + Ovsync izi yok (vaka hastalığı K10-Mastit, Ovsync-dışı) + dolu ilaç
--   listesi → ANA_ACIK_OVSYNC_DEGIL; gün açılamaz, ilaç yazılamaz, TAI oynayamaz ──
DO $do$ DECLARE
  v_r jsonb; v_eski date; v_yeni date; v_gun int; v_ilac int;
BEGIN
  SELECT hedef_tarih INTO v_eski FROM gorev_log WHERE id = pg_temp.k10_id('e',10);
  v_r := public.ovsync_hastalik_gunu_ekle(pg_temp.k10_id('a',10), pg_temp.k10_id('1',3), pg_temp.k10_bg()+4, 7, '[{"dose": 5, "unit": "ml"}]');
  SELECT count(*) INTO v_gun FROM treatment_days WHERE case_id = pg_temp.k10_id('a',10);
  SELECT count(*) INTO v_ilac FROM drug_administrations da JOIN treatment_days td ON td.id = da.treatment_day_id
   WHERE td.case_id = pg_temp.k10_id('a',10);
  SELECT hedef_tarih INTO v_yeni FROM gorev_log WHERE id = pg_temp.k10_id('e',10);
  INSERT INTO _k10_durum VALUES ('S-DB1-null-mastit',
    CASE WHEN COALESCE((v_r->>'ok')::boolean, true) = false AND v_r->>'error' = 'ANA_ACIK_OVSYNC_DEGIL'
      AND v_gun = 0 AND v_ilac = 0 AND v_yeni = v_eski THEN 'PASS' ELSE 'RED' END,
    format('ok=%s err=%s; gun_satir=%s (beklenen 0); ilac_satir=%s (beklenen 0); TAI %s->%s (oynamamali)',
      v_r->>'ok', v_r->>'error', v_gun, v_ilac, v_eski, v_yeni));
EXCEPTION WHEN OTHERS THEN INSERT INTO _k10_durum VALUES ('S-DB1-null-mastit', 'RED', SQLERRM); END $do$;

-- ── S-DB1-kisir-null-ovsync: NULL-aile Ovsync vakası kısırda kapanır; izsiz NULL vakalar
--   (a10 + H-11'in ikinci izsiz vakası a12) açık kalır ──
DO $do$ DECLARE
  v_d11 text; v_k11 text; v_d10 text; v_d12 text;
BEGIN
  UPDATE public.hayvanlar SET kisir = true WHERE id = 'K10-H-11';
  SELECT status, close_reason INTO v_d11, v_k11 FROM cases WHERE id = pg_temp.k10_id('a',11);
  SELECT status INTO v_d10 FROM cases WHERE id = pg_temp.k10_id('a',10);
  SELECT status INTO v_d12 FROM cases WHERE id = pg_temp.k10_id('a',12);
  INSERT INTO _k10_durum VALUES ('S-DB1-kisir-null-ovsync',
    CASE WHEN v_d11 = 'closed' AND v_k11 = 'ERKEN_KAPANIS' AND v_d10 = 'active' AND v_d12 = 'active' THEN 'PASS' ELSE 'RED' END,
    format('izli(a11)=%s/%s (closed/ERKEN_KAPANIS); izsiz(a10)=%s izsiz(a12)=%s (active)', v_d11, v_k11, v_d10, v_d12));
EXCEPTION WHEN OTHERS THEN INSERT INTO _k10_durum VALUES ('S-DB1-kisir-null-ovsync', 'RED', SQLERRM); END $do$;

-- ── S-DB1-alt-ozet (ERT5): hastalık günü olan vakada takip_listele gün durumu + sıra + diseases.name ──
DO $do$ DECLARE
  v_out jsonb; v_alt jsonb; v_n int;
BEGIN
  PERFORM public.ovsync_hastalik_gunu_ekle(pg_temp.k10_id('a',4), pg_temp.k10_id('1',1), pg_temp.k10_bg()+1, 7, '[]');
  UPDATE public.treatment_days SET tamamlandi = true, tamamlanma_tarihi = now()
   WHERE case_id = pg_temp.k10_id('a',4) AND disease_id = pg_temp.k10_id('1',1) AND treatment_date = pg_temp.k10_bg()+1;
  v_out := public.ovsync_takip_listele();
  SELECT r->'alt_vakalar' INTO v_alt FROM jsonb_array_elements(COALESCE(v_out->'satirlar', '[]')) r
   WHERE r->>'kupe_no' = 'K10-4' AND jsonb_array_length(COALESCE(r->'alt_vakalar', '[]')) > 0 LIMIT 1;
  v_n := COALESCE(jsonb_array_length(v_alt), -1);
  INSERT INTO _k10_durum VALUES ('S-DB1-alt-ozet',
    CASE WHEN v_n = 2
      AND v_alt->0->>'hastalik' = 'K10-Ovsync' AND v_alt->0->>'status' = 'tamam'
      AND v_alt->1->>'hastalik' = 'K10-Hastalik' AND v_alt->1->>'status' = 'acik'
      THEN 'PASS' ELSE 'RED' END,
    format('alt_vakalar n=%s; [0]=%s/%s [1]=%s/%s (tarih sirali: tamam once)',
      v_n, v_alt->0->>'hastalik', v_alt->0->>'status', v_alt->1->>'hastalik', v_alt->1->>'status'));
EXCEPTION WHEN OTHERS THEN INSERT INTO _k10_durum VALUES ('S-DB1-alt-ozet', 'RED', SQLERRM); END $do$;

SELECT senaryo, sonuc, kanit FROM _k10_durum ORDER BY senaryo;
SELECT count(*) FILTER (WHERE sonuc <> 'PASS') AS k10_red, count(*) AS k10_toplam FROM _k10_durum \gset
ROLLBACK;
SELECT set_config('k10.red', :'k10_red', false), set_config('k10.toplam', :'k10_toplam', false) \g /dev/null
DO $do$ BEGIN
  IF current_setting('k10.toplam')::int <> 12 OR current_setting('k10.red')::int > 0 THEN
    RAISE EXCEPTION 'K10-DB1 TEST RED: % / % senaryo kirmizi', current_setting('k10.red'), current_setting('k10.toplam');
  END IF;
  RAISE NOTICE 'K10-DB1 TEST PASS';
END $do$;
