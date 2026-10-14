-- tests/sql/ovsync_paketi_test.sql — Ovsync paketi senaryoları. HEDEF: YALNIZ yerel izole parite DB (Global Constraints).
-- KOŞUM: psql "$ISO" -X -v ON_ERROR_STOP=1 -f tests/sql/ovsync_paketi_test.sql → rc=0 hepsi PASS; rc!=0 en az biri RED.
-- Her DO bloğu EXCEPTION kolunda RED+SQLERRM yazar; henüz olmayan kolon/imza dinamik EXECUTE ile çağrılır.
-- Tüm fixture + RPC yan etkileri tek transaction'da, sonda ROLLBACK. Sabit uuid: pg_temp.ovp_id(sınıf, no)
--   a=ana OVSYNC, b=alt, c=mastit, d=treatment_day, e=gorev, f=ürün, 1=hastalık, 2=ilaç sınıfı, 3=şablon.
\echo '=== OVSYNC PAKETI — izole DB testi ==='
BEGIN;
CREATE FUNCTION pg_temp.ovp_id(p text, i int) RETURNS uuid LANGUAGE sql IMMUTABLE
  AS $$ SELECT ('e2e00000-0000-4000-8000-0000000' || p || '00' || lpad(i::text, 2, '0'))::uuid $$;
CREATE FUNCTION pg_temp.bg() RETURNS date LANGUAGE sql STABLE AS $$ SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date $$;
DELETE FROM gorev_log WHERE hayvan_id LIKE 'E2E-OVP-H-%'; DELETE FROM tohumlama WHERE hayvan_id LIKE 'E2E-OVP-H-%';
DELETE FROM cases WHERE animal_id LIKE 'E2E-OVP-H-%'; DELETE FROM hayvanlar WHERE id LIKE 'E2E-OVP-H-%'; DELETE FROM stok WHERE id LIKE 'E2E-OVP-%';
DELETE FROM drug_products WHERE brand_name LIKE 'E2E-OVP-%'; DELETE FROM drug_classes WHERE group_name = 'E2E-OVP';
DELETE FROM tedavi_sablonu WHERE ad LIKE 'E2E-OVP-%'; DELETE FROM diseases WHERE name LIKE 'E2E-OVP-%';
INSERT INTO protokol_ayar(anahtar, deger) VALUES ('ovsync_pg_kurallari_aktif', 1) ON CONFLICT (anahtar) DO UPDATE SET deger = 1;
INSERT INTO diseases(id, name, category) SELECT pg_temp.ovp_id('1', i), 'E2E-OVP-' || n, k
  FROM (VALUES (1, 'Ovsync', 'Üreme'), (2, 'Inaktif Ovaryum', 'Üreme'), (3, 'Mastit', 'Meme')) v(i, n, k);
INSERT INTO tedavi_sablonu(id, ad, protokol_ailesi) VALUES (pg_temp.ovp_id('3',1), 'E2E-OVP-OVSYNC', 'OVSYNC');
INSERT INTO sablon_hastalik_eslem(sablon_id, disease_id) VALUES (pg_temp.ovp_id('3',1), pg_temp.ovp_id('1',1));
INSERT INTO drug_classes(id, group_name, class_name, farmakolojik_sinif_kodu, etken_kod)   -- PG = PGF2A (_pg_urun_durumu)
  VALUES (pg_temp.ovp_id('2',1), 'E2E-OVP', 'PG', 'PGF2A', 'PG'), (pg_temp.ovp_id('2',2), 'E2E-OVP', 'VIT', NULL, NULL);
INSERT INTO drug_products(id, drug_class_id, brand_name) SELECT pg_temp.ovp_id('f', i), pg_temp.ovp_id('2', i), 'E2E-OVP-' || n
  FROM (VALUES (1, 'PG'), (2, 'VIT')) v(i, n);
INSERT INTO stok(id, urun_adi, kategori, birim, baslangic_miktar, drug_product_id)
  SELECT 'E2E-OVP-STK-' || n, 'E2E-OVP-' || n, 'İlaç', 'ml', 100, pg_temp.ovp_id('f', i) FROM (VALUES (1, 'PG'), (2, 'VIT')) v(i, n);
INSERT INTO hayvanlar(id, kupe_no, cinsiyet, durum, grup, padok, dogum_tarihi)   -- 800 g: uygunluk eşiği (365) geçer
  SELECT 'E2E-OVP-H-' || i, 'E2E-OVP-' || i, 'Dişi', 'Aktif', 'Sağmal (Laktasyonda)', 'Sağmal Padok', pg_temp.bg() - 800 FROM generate_series(1, 10) i;
INSERT INTO cases(id, animal_id, disease_id, start_date, status, protocol_family, source_template_id)
  SELECT pg_temp.ovp_id('a', i), 'E2E-OVP-H-' || i, pg_temp.ovp_id('1',1), pg_temp.bg() - 3, 'active', 'OVSYNC', pg_temp.ovp_id('3',1)
    FROM unnest(ARRAY[1, 5, 6, 7, 8, 9, 10]) i;
INSERT INTO tohumlama(hayvan_id, tarih, sperma, sonuc) VALUES ('E2E-OVP-H-3', pg_temp.bg() - 60, 'E2E-OVP', 'Gebe'), ('E2E-OVP-H-4', pg_temp.bg() - 20, 'E2E-OVP', 'Bekliyor');
INSERT INTO cases(id, animal_id, disease_id, start_date, status) SELECT pg_temp.ovp_id('c', i), 'E2E-OVP-H-' || i, pg_temp.ovp_id('1',3), pg_temp.bg(), 'active' FROM generate_series(3, 4) i;
INSERT INTO treatment_days(id, case_id, treatment_date) SELECT pg_temp.ovp_id('d', i), pg_temp.ovp_id('c', i), pg_temp.bg() FROM generate_series(3, 4) i;
INSERT INTO gorev_log(id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, kaynak)   -- açık TAI: H-2 ertelenmiş, H-5 PG kaynaklı
  VALUES (pg_temp.ovp_id('e',2), 'E2E-OVP-H-2', 'TOHUMLAMA_PLANLI', 'E2E-OVP ertelenmiş TAI', pg_temp.bg() + 20, '10:00', 'E2E-OVP-TAI:2');
CREATE TEMP TABLE _ovp_durum(senaryo text PRIMARY KEY, sonuc text, kanit text);

-- ── S-PG1 (kırmızı): aktif OVSYNC + bağımsız PG (hizli_uygulama → _pg_olay_isle) → vaka active KALIR
DO $do$ DECLARE v_r jsonb; v_st text; BEGIN
  v_r := public.hizli_uygulama('E2E-OVP-H-1', 'E2E-OVP-STK-PG', 2, 'ml', 'IM', 'E2E-OVP');
  SELECT status || '/' || COALESCE(close_reason, '-') INTO v_st FROM cases WHERE id = pg_temp.ovp_id('a',1);
  INSERT INTO _ovp_durum VALUES ('S-PG1', CASE WHEN v_st = 'active/-' AND (v_r->>'ok')::boolean THEN 'PASS' ELSE 'RED' END,
    format('ana vaka=%s; rpc ok=%s', v_st, v_r->>'ok'));
EXCEPTION WHEN OTHERS THEN INSERT INTO _ovp_durum VALUES ('S-PG1', 'RED', SQLERRM); END $do$;

-- ── S-PG2 (kilit): ertelenmiş açık TAI + yeni PG → eski PG_YERINE ile kapanır, yeni PG_TOHUMLAMA @ PG+2 g
DO $do$ DECLARE v_at timestamptz := ((pg_temp.bg() - 1) + time '10:00') AT TIME ZONE 'Europe/Istanbul'; v_eski text; v_yeni text; BEGIN
  PERFORM public.hizli_uygulama('E2E-OVP-H-2', 'E2E-OVP-STK-PG', 2, 'ml', 'IM', 'E2E-OVP', p_occurred_at => v_at);
  SELECT COALESCE(iptal, false) || '/' || COALESCE(tamamlandi, false) || '/' || COALESCE(kapatan_ref, '-') INTO v_eski
    FROM gorev_log WHERE id = pg_temp.ovp_id('e',2);
  SELECT string_agg(kaynak || '@' || hedef_tarih, ',') INTO v_yeni FROM gorev_log
   WHERE hayvan_id = 'E2E-OVP-H-2' AND gorev_tipi = 'TOHUMLAMA_PLANLI' AND NOT COALESCE(iptal, false) AND NOT COALESCE(tamamlandi, false);
  INSERT INTO _ovp_durum VALUES ('S-PG2', CASE WHEN v_eski LIKE 'true/true/PG_YERINE:%' AND v_yeni NOT LIKE '%,%'
    AND v_yeni LIKE 'PG_TOHUMLAMA:%@' || ((v_at AT TIME ZONE 'Europe/Istanbul')::date + 2) THEN 'PASS' ELSE 'RED' END,
    format('eski=%s; acik TAI=%s', v_eski, v_yeni));
EXCEPTION WHEN OTHERS THEN INSERT INTO _ovp_durum VALUES ('S-PG2', 'RED', SQLERRM); END $do$;

-- ── S-OVERLOAD (kırmızı): 3 RPC'de tek imza + p_pg_onay ... DEFAULT NULL
DO $do$ DECLARE r record; v_ok boolean := true; v_k text := ''; BEGIN
  FOR r IN SELECT a.ad, count(p.oid) AS n, COALESCE(bool_or(pg_get_function_arguments(p.oid) ~ 'p_pg_onay boolean DEFAULT NULL'), false) AS onay
             FROM unnest(ARRAY['treatment_day_tamamla', 'add_drug_administration', 'tedavi_sablon_uygula']) a(ad)
             LEFT JOIN (pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace AND n.nspname = 'public') ON p.proname = a.ad
            GROUP BY a.ad ORDER BY a.ad LOOP
    v_ok := v_ok AND r.n = 1 AND r.onay; v_k := v_k || format('%s: sayim=%s p_pg_onay=%s; ', r.ad, r.n, r.onay);
  END LOOP;
  INSERT INTO _ovp_durum VALUES ('S-OVERLOAD', CASE WHEN v_ok THEN 'PASS' ELSE 'RED' END, v_k);
EXCEPTION WHEN OTHERS THEN INSERT INTO _ovp_durum VALUES ('S-OVERLOAD', 'RED', SQLERRM); END $do$;

-- ── S-REPLAY (kırmızı; offline replay'in çarptığı sunucu sözleşmesi): gebe hayvana add_drug_administration(PG)
--    → 'PG_KAPI:%' + satır YOK; ACK kolu (son tohumlama Bekliyor) p_pg_onay => true ile geçer
DO $do$ DECLARE v_e text := 'HATA YOK'; v_n int; v_ack text; BEGIN
  BEGIN PERFORM public.add_drug_administration(pg_temp.ovp_id('d',3), pg_temp.ovp_id('f',1), 'E2E-OVP-STK-PG', 2, 'ml', 'IM');
  EXCEPTION WHEN OTHERS THEN v_e := SQLERRM; END;
  SELECT count(*) INTO v_n FROM drug_administrations WHERE treatment_day_id = pg_temp.ovp_id('d',3);
  IF to_regprocedure('public.add_drug_administration(uuid,uuid,text,numeric,text,text,boolean,text)') IS NULL THEN
    v_ack := 'ACK kolu: yeni imza YOK';
  ELSE
    EXECUTE 'SELECT public.add_drug_administration(p_day_id => $1, p_drug_product_id => $2, p_stok_id => $3, p_dose => 2, p_unit => ''ml'', p_route => ''IM'', p_pg_onay => true, p_pg_gerekce => ''E2E'')'
      USING pg_temp.ovp_id('d',4), pg_temp.ovp_id('f',1), 'E2E-OVP-STK-PG';
    SELECT 'ACK kolu: satir=' || count(*) INTO v_ack FROM drug_administrations WHERE treatment_day_id = pg_temp.ovp_id('d',4);
  END IF;
  INSERT INTO _ovp_durum VALUES ('S-REPLAY', CASE WHEN v_e LIKE 'PG_KAPI:%' AND v_n = 0 AND v_ack = 'ACK kolu: satir=1' THEN 'PASS' ELSE 'RED' END,
    format('blok kolu: hata=%s, satir=%s; %s', left(v_e, 60), v_n, v_ack));
EXCEPTION WHEN OTHERS THEN INSERT INTO _ovp_durum VALUES ('S-REPLAY', 'RED', SQLERRM); END $do$;

-- ── S-KISIR (tek OVSYNC vakası; karar 10: ayrı alt vaka yok): hayvan_guncelle(p_kisir => true) → vaka
--    closed/ERKEN_KAPANIS; yeni OVSYNC reddedilir (§18.5 KISIR_HAYVAN_OVSYNC_YASAK korunur)
DO $do$ DECLARE v_ana uuid := pg_temp.ovp_id('a',9); v_s text; v_ins text := 'INSERT GECTI'; v_c boolean; BEGIN
  PERFORM public.hayvan_guncelle(p_id => 'E2E-OVP-H-9', p_kisir => true);
  SELECT string_agg(status || '/' || COALESCE(close_reason, '-'), ',' ORDER BY id) INTO v_s FROM cases WHERE animal_id = 'E2E-OVP-H-9';
  SELECT bool_and(closed_at IS NOT NULL) INTO v_c FROM cases WHERE animal_id = 'E2E-OVP-H-9';
  BEGIN INSERT INTO cases(animal_id, disease_id, start_date, status, protocol_family) VALUES ('E2E-OVP-H-9', pg_temp.ovp_id('1',1), pg_temp.bg(), 'active', 'OVSYNC');
  EXCEPTION WHEN OTHERS THEN v_ins := 'reddedildi: ' || left(SQLERRM, 60); END;
  INSERT INTO _ovp_durum VALUES ('S-KISIR', CASE WHEN v_s = 'closed/ERKEN_KAPANIS' AND COALESCE(v_c, false)
    AND v_ins LIKE 'reddedildi: KISIR_HAYVAN_OVSYNC_YASAK%' THEN 'PASS' ELSE 'RED' END, format('vakalar=%s; closed_at_dolu=%s; yeni OVSYNC=%s', v_s, v_c, v_ins));
EXCEPTION WHEN OTHERS THEN INSERT INTO _ovp_durum VALUES ('S-KISIR', 'RED', SQLERRM); END $do$;

-- ── S-PG-TEK-OLAY (kırmızı; çift PG olayı kilidi, 000002:262-265 ↔ :204-212):
--    (i) tamamlanmamış bugünkü güne PG ekle → olay 0; günü tamamla → olay 1 + _pg_sonrasi_tohumlama 1 kez;
--    (ii) tamamlanmış güne PG ekle → olay 1
DO $do$ DECLARE
  v_r jsonb; v_id1 uuid; v_id2 uuid;
  v_i_ekle int; v_i_tamamla int; v_i_tai int; v_ii_olay int; v_ii_tai int;
BEGIN
  INSERT INTO hayvanlar(id, kupe_no, cinsiyet, durum, grup, padok, dogum_tarihi)
    VALUES ('E2E-OVP-H-11', 'E2E-OVP-11', 'Dişi', 'Aktif', 'Sağmal (Laktasyonda)', 'Sağmal Padok', pg_temp.bg() - 800);
  INSERT INTO cases(id, animal_id, disease_id, start_date, status)
    VALUES (pg_temp.ovp_id('c',11), 'E2E-OVP-H-11', pg_temp.ovp_id('1',3), pg_temp.bg(), 'active');
  INSERT INTO treatment_days(id, case_id, treatment_date)
    VALUES (pg_temp.ovp_id('d',11), pg_temp.ovp_id('c',11), pg_temp.bg());
  v_r := public.add_drug_administration(pg_temp.ovp_id('d',11), pg_temp.ovp_id('f',1), 'E2E-OVP-STK-PG', 2, 'ml', 'IM');
  v_id1 := (v_r->>'id')::uuid;
  SELECT count(*) INTO v_i_ekle FROM pg_application_event WHERE source_id = v_id1::text;
  PERFORM public.treatment_day_tamamla(pg_temp.ovp_id('d',11));
  SELECT count(*) INTO v_i_tamamla FROM pg_application_event WHERE source_id = v_id1::text;
  SELECT count(*) INTO v_i_tai FROM gorev_log WHERE hayvan_id = 'E2E-OVP-H-11' AND kaynak LIKE 'PG_TOHUMLAMA:%';
  INSERT INTO hayvanlar(id, kupe_no, cinsiyet, durum, grup, padok, dogum_tarihi)
    VALUES ('E2E-OVP-H-12', 'E2E-OVP-12', 'Dişi', 'Aktif', 'Sağmal (Laktasyonda)', 'Sağmal Padok', pg_temp.bg() - 800);
  INSERT INTO cases(id, animal_id, disease_id, start_date, status)
    VALUES (pg_temp.ovp_id('c',12), 'E2E-OVP-H-12', pg_temp.ovp_id('1',3), pg_temp.bg(), 'active');
  INSERT INTO treatment_days(id, case_id, treatment_date)
    VALUES (pg_temp.ovp_id('d',12), pg_temp.ovp_id('c',12), pg_temp.bg());
  PERFORM public.treatment_day_tamamla(pg_temp.ovp_id('d',12));
  v_r := public.add_drug_administration(pg_temp.ovp_id('d',12), pg_temp.ovp_id('f',1), 'E2E-OVP-STK-PG', 2, 'ml', 'IM');
  v_id2 := (v_r->>'id')::uuid;
  SELECT count(*) INTO v_ii_olay FROM pg_application_event WHERE source_id = v_id2::text;
  SELECT count(*) INTO v_ii_tai FROM gorev_log WHERE hayvan_id = 'E2E-OVP-H-12' AND kaynak LIKE 'PG_TOHUMLAMA:%';
  INSERT INTO _ovp_durum VALUES ('S-PG-TEK-OLAY',
    CASE WHEN v_i_ekle = 0 AND v_i_tamamla = 1 AND v_i_tai = 1 AND v_ii_olay = 1 AND v_ii_tai = 1 THEN 'PASS' ELSE 'RED' END,
    format('(i) ekle-sonrasi=%s tamamla-sonrasi=%s tai=%s; (ii) olay=%s tai=%s', v_i_ekle, v_i_tamamla, v_i_tai, v_ii_olay, v_ii_tai));
EXCEPTION WHEN OTHERS THEN INSERT INTO _ovp_durum VALUES ('S-PG-TEK-OLAY', 'RED', SQLERRM); END $do$;

-- ── S-PG-SAVUNMA (NOT EXISTS savunma kilidi, 000002:204-211):
--    ILAC_EKLE olayı önceden var olan kalemde günü tamamla → yeni olay YOK
--    (toplam 1, TEDAVI_GUN 0). MUT-PG-SAVUNMASIZ (NOT EXISTS silik) → RED.
DO $do$ DECLARE
  v_r jsonb; v_id uuid; v_toplam int; v_tgun int; v_tai int;
BEGIN
  INSERT INTO hayvanlar(id, kupe_no, cinsiyet, durum, grup, padok, dogum_tarihi)
    VALUES ('E2E-OVP-H-13', 'E2E-OVP-13', 'Dişi', 'Aktif', 'Sağmal (Laktasyonda)', 'Sağmal Padok', pg_temp.bg() - 800);
  INSERT INTO cases(id, animal_id, disease_id, start_date, status)
    VALUES (pg_temp.ovp_id('c',13), 'E2E-OVP-H-13', pg_temp.ovp_id('1',3), pg_temp.bg(), 'active');
  INSERT INTO treatment_days(id, case_id, treatment_date)
    VALUES (pg_temp.ovp_id('d',13), pg_temp.ovp_id('c',13), pg_temp.bg());
  v_r := public.add_drug_administration(pg_temp.ovp_id('d',13), pg_temp.ovp_id('f',1), 'E2E-OVP-STK-PG', 2, 'ml', 'IM');
  v_id := (v_r->>'id')::uuid;
  INSERT INTO public.pg_application_event(source_type, source_id, hayvan_id, stok_id, drug_product_id, occurred_at, karar)
    VALUES ('ILAC_EKLE', v_id::text, 'E2E-OVP-H-13', 'E2E-OVP-STK-PG', pg_temp.ovp_id('f',1), now(), 'ALLOW')
    ON CONFLICT (source_type, source_id) DO NOTHING;
  PERFORM public.treatment_day_tamamla(pg_temp.ovp_id('d',13));
  SELECT count(*) INTO v_toplam FROM pg_application_event WHERE source_id = v_id::text;
  SELECT count(*) INTO v_tgun FROM pg_application_event WHERE source_id = v_id::text AND source_type = 'TEDAVI_GUN';
  SELECT count(*) INTO v_tai FROM gorev_log WHERE hayvan_id = 'E2E-OVP-H-13' AND kaynak LIKE 'PG_TOHUMLAMA:%';
  INSERT INTO _ovp_durum VALUES ('S-PG-SAVUNMA',
    CASE WHEN v_toplam = 1 AND v_tgun = 0 THEN 'PASS' ELSE 'RED' END,
    format('toplam=%s tgun=%s tai=%s', v_toplam, v_tgun, v_tai));
EXCEPTION WHEN OTHERS THEN INSERT INTO _ovp_durum VALUES ('S-PG-SAVUNMA', 'RED', SQLERRM); END $do$;

-- ── Özet + hüküm (ROLLBACK = temizlik). Beklenen senaryo sayısı: karar 10 sonrası 7
--    (S-PG1, S-PG2, S-OVERLOAD, S-REPLAY, S-KISIR, S-PG-TEK-OLAY, S-PG-SAVUNMA;
--    S-ERT1, S-VIT, S-DONUS, S-VIT-ONCE, S-GUN-AC, S-S4 alt-vaka modeliyle kalktı).
SELECT senaryo, sonuc, kanit FROM _ovp_durum ORDER BY senaryo;
SELECT count(*) FILTER (WHERE sonuc <> 'PASS') AS ovp_red, count(*) AS ovp_toplam FROM _ovp_durum \gset
ROLLBACK;
SELECT set_config('ovp.red', :'ovp_red', false), set_config('ovp.toplam', :'ovp_toplam', false) \g /dev/null
DO $do$ BEGIN
  IF current_setting('ovp.toplam')::int <> 7 OR current_setting('ovp.red')::int > 0 THEN
    RAISE EXCEPTION 'OVSYNC-PAKETI TEST RED: % / % senaryo kirmizi', current_setting('ovp.red'), current_setting('ovp.toplam');
  END IF;
  RAISE NOTICE 'OVSYNC-PAKETI TEST PASS';
END $do$;
