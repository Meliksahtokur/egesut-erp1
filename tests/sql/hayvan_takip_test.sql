-- Hayvan Takip DB sözleşme testleri. BEGIN/ROLLBACK taşımaz: hayvan_takip_kos.sh sarar.
-- Bölüm seçimi BOLUM ile: sema = P01 P02 L01; rpc = P03 A* K* M* S* C*; guard = G*.
-- Migration'lar gelmeden nesneler bulunamaz: gövdeler ht_test içinde dinamik koşar, P01 ilk düşer.
-- Her gövde kendi alt işleminde koşar ve daima geri sarılır; senaryolar birbirini görmez.
-- OZET'i koşucu sayar; dosya yalnız "<id> PASS" NOTICE'ı yazar. Fixture: E2E-HT-T-*.
\o /dev/null
SELECT :'bolum' IN ('hepsi', 'sema') AS b_sema, :'bolum' IN ('hepsi', 'rpc') AS b_rpc, :'bolum' IN ('hepsi', 'guard') AS b_guard \gset
-- JWT: acan/kapatan email'den okunur; C02 ve C04 bu claim altında SET LOCAL ROLE yapar.
SELECT set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000cafe","email":"e2e-ht-t@example.test","role":"authenticated"}', true);
SELECT set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000cafe', true);
CREATE FUNCTION pg_temp.ht_id(p_n int) RETURNS uuid LANGUAGE sql IMMUTABLE AS $f$ SELECT ('00000000-0000-4000-8000-0000000e2f' || lpad(p_n::text, 2, '0'))::uuid $f$;
CREATE FUNCTION pg_temp.ht_gun() RETURNS date LANGUAGE sql STABLE AS $f$ SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date $f$;
CREATE FUNCTION pg_temp.ht_eposta() RETURNS text LANGUAGE sql IMMUTABLE AS $f$ SELECT 'e2e-ht-t@example.test'::text $f$;
CREATE FUNCTION pg_temp.ht_dogru(p_kosul boolean, p_mesaj text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF p_kosul IS NOT TRUE THEN RAISE EXCEPTION '%', p_mesaj; END IF; END $f$;
CREATE FUNCTION pg_temp.ht_esit(p_gercek text, p_beklenen text, p_mesaj text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN IF p_gercek IS DISTINCT FROM p_beklenen THEN RAISE EXCEPTION '%: gerçek=% beklenen=%', p_mesaj, COALESCE(p_gercek, '<NULL>'), COALESCE(p_beklenen, '<NULL>'); END IF; END $f$;
-- jsonb alanlarını çiftlerle karşılaştırır: alan, beklenen, alan, beklenen...
CREATE FUNCTION pg_temp.ht_alan(p_j jsonb, VARIADIC p_c text[]) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  FOR i IN 1 .. array_length(p_c, 1) / 2 LOOP
    PERFORM pg_temp.ht_esit(p_j->>p_c[2 * i - 1], p_c[2 * i], p_c[2 * i - 1]);
  END LOOP;
END $f$;
-- Senaryo gövdesini (DECLARE ... END) alt işlemde koşar, etkisini her durumda geri sarar.
CREATE FUNCTION pg_temp.ht_test(p_id text, p_govde text) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  BEGIN
    EXECUTE 'DO ' || quote_literal(p_govde);
    RAISE EXCEPTION USING ERRCODE = 'HTGER', MESSAGE = 'geri sar';
  EXCEPTION
    WHEN SQLSTATE 'HTGER' THEN NULL;
    WHEN OTHERS THEN RAISE EXCEPTION '% FAIL: % [%]', p_id, SQLERRM, SQLSTATE;
  END;
  RAISE NOTICE '% PASS', p_id;
END $f$;
-- Komutun reddini doğrular: p_beklenen, hata metniyle (HT_* kodu) ya da SQLSTATE ile tam eşleşir.
CREATE FUNCTION pg_temp.ht_red(p_beklenen text, p_sql text, VARIADIC p_arg text[] DEFAULT '{}') RETURNS void LANGUAGE plpgsql AS $f$
DECLARE v_gercek text;
BEGIN
  BEGIN
    EXECUTE format(p_sql, VARIADIC p_arg);
    v_gercek := '<hata yok>';
  EXCEPTION WHEN OTHERS THEN
    IF p_beklenen IN (SQLERRM, SQLSTATE) THEN RETURN; END IF;
    v_gercek := SQLSTATE || ' ' || SQLERRM;
  END;
  RAISE EXCEPTION 'red bekleniyordu % gerçek % (%)', p_beklenen, v_gercek, format(p_sql, VARIADIC p_arg);
END $f$;
CREATE FUNCTION pg_temp.ht_hayvan(p_n int, p_durum text DEFAULT 'Aktif') RETURNS text LANGUAGE plpgsql AS $f$
BEGIN
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, dogum_tarihi, durum, irk, grup, padok)
  VALUES (pg_temp.ht_id(p_n)::text, 'E2E-HT-T-' || p_n, 'Dişi', pg_temp.ht_gun() - 1500, p_durum, 'Holstein', 'Sağmal', 'P1');
  RETURN pg_temp.ht_id(p_n)::text;
END $f$;
CREATE FUNCTION pg_temp.ht_vaka(p_hayvan text) RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE v uuid;
BEGIN
  INSERT INTO public.cases (animal_id, disease_id, notes)
  VALUES (p_hayvan, (SELECT id FROM public.diseases ORDER BY id LIMIT 1), 'E2E-HT-T') RETURNING id INTO v;
  RETURN v;
END $f$;
-- RPC'siz takip satırı: yalnız kısıt, audit ve "elle kurulan" durumlar için.
CREATE FUNCTION pg_temp.ht_satir(p_hayvan text, p_sebep text DEFAULT 'TOPALLIK', p_aciklama text DEFAULT NULL) RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE v uuid;
BEGIN
  INSERT INTO public.hayvan_takip (hayvan_id, sebep_kodu, aciklama) VALUES (p_hayvan, p_sebep, p_aciklama) RETURNING id INTO v;
  RETURN v;
END $f$;
CREATE FUNCTION pg_temp.ht_gorev(p_hayvan text, p_tip text, p_ref uuid DEFAULT NULL, p_tamam boolean DEFAULT false, p_iptal boolean DEFAULT false) RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE v uuid;
BEGIN
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih, ref_takip_id, tamamlandi, iptal)
  VALUES (p_hayvan, p_tip, 'E2E-HT-T', pg_temp.ht_gun() + 7, p_ref, p_tamam, p_iptal) RETURNING id INTO v;
  RETURN v;
END $f$;
CREATE FUNCTION pg_temp.ht_ac(p_hayvan text, p_sebep text DEFAULT 'TOPALLIK', p_aciklama text DEFAULT NULL, p_tarih date DEFAULT NULL, p_saat time DEFAULT NULL) RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE r jsonb;
BEGIN
  r := public.hayvan_takip_ac(p_hayvan, p_sebep, p_aciklama, p_tarih, p_saat);
  PERFORM pg_temp.ht_alan(r, 'ok', 'true');
  RETURN (r->>'takip_id')::uuid;
END $f$;
CREATE FUNCTION pg_temp.ht_tk(p_id uuid) RETURNS jsonb LANGUAGE plpgsql AS $f$ BEGIN RETURN (SELECT to_jsonb(x) FROM public.hayvan_takip x WHERE x.id = p_id); END $f$;
CREATE FUNCTION pg_temp.ht_gr(p_id uuid) RETURNS jsonb LANGUAGE plpgsql AS $f$ BEGIN RETURN (SELECT to_jsonb(x) FROM public.gorev_log x WHERE x.id = p_id); END $f$;
-- Takibin açık muayene görevleri: sayı ve (tekse) kimlik.
CREATE FUNCTION pg_temp.ht_acik(p_takip uuid) RETURNS int LANGUAGE plpgsql AS $f$ BEGIN RETURN (SELECT count(*) FROM public.gorev_log WHERE ref_takip_id = p_takip AND tamamlandi IS NOT TRUE AND iptal IS NOT TRUE); END $f$;
CREATE FUNCTION pg_temp.ht_acik_id(p_takip uuid) RETURNS uuid LANGUAGE plpgsql AS $f$ BEGIN RETURN (SELECT id FROM public.gorev_log WHERE ref_takip_id = p_takip AND tamamlandi IS NOT TRUE AND iptal IS NOT TRUE); END $f$;
CREATE FUNCTION pg_temp.ht_log(p_tip text, p_takip uuid) RETURNS int LANGUAGE plpgsql AS $f$ BEGIN RETURN (SELECT count(*) FROM public.islem_log WHERE tip = p_tip AND ref_tablo = 'hayvan_takip' AND ref_id = p_takip::text); END $f$;

CREATE FUNCTION pg_temp.ht_kayit(p_takip uuid, VARIADIC p_c text[]) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  FOR i IN 1 .. array_length(p_c, 1) / 2 LOOP
    PERFORM pg_temp.ht_esit(pg_temp.ht_log('HAYVAN_TAKIP_' || p_c[2 * i - 1], p_takip)::text, p_c[2 * i], p_c[2 * i - 1] || ' log');
  END LOOP;
END $f$;

\if :b_sema

SELECT pg_temp.ht_test('P01', $t$ DECLARE p text;
BEGIN
  PERFORM pg_temp.ht_dogru(has_table_privilege('authenticated', 'public.hayvan_takip', 'SELECT'), 'authenticated SELECT yok');
  FOREACH p IN ARRAY ARRAY['INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER'] LOOP
    PERFORM pg_temp.ht_dogru(NOT has_table_privilege('authenticated', 'public.hayvan_takip', p), 'authenticated ' || p || ' var');
  END LOOP;
  FOREACH p IN ARRAY ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER'] LOOP
    PERFORM pg_temp.ht_dogru(NOT has_table_privilege('anon', 'public.hayvan_takip', p), 'anon ' || p || ' var');
  END LOOP;
END $t$);
SELECT pg_temp.ht_test('P02', $t$ DECLARE
  h text := pg_temp.ht_hayvan(1);
  e constant text := 'INSERT INTO public.hayvan_takip (hayvan_id, sebep_kodu, aciklama, kapanis_tarihi, kapanis_nedeni, kapatan_vaka_id) VALUES (%L, %L, %L, %L::timestamptz, %L, %L::uuid)';
  t uuid; ga uuid; gk uuid; v jsonb;
BEGIN
  -- RLS, policy, audit, indeks
  PERFORM pg_temp.ht_dogru((SELECT relrowsecurity FROM pg_class WHERE oid = 'public.hayvan_takip'::regclass), 'RLS kapalı');
  PERFORM pg_temp.ht_dogru(EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'hayvan_takip' AND cmd = 'SELECT' AND 'authenticated' = ANY (roles)), 'SELECT policy yok');
  PERFORM pg_temp.ht_dogru(EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.hayvan_takip'::regclass AND tgname = 'trg_degisim_log' AND tgenabled <> 'D'), 'trg_degisim_log yok');
  PERFORM pg_temp.ht_dogru(to_regclass('public.hayvan_takip_farm_hayvan_idx') IS NOT NULL, 'farm_hayvan indeksi yok');
  -- Görünüm: kolon, açık kol, kapalı kol, LIMIT korunur
  PERFORM pg_temp.ht_dogru(EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'v_gorev_log_sync' AND column_name = 'ref_takip_id'), 'görünümde ref_takip_id yok');
  PERFORM pg_temp.ht_dogru(pg_get_viewdef('public.v_gorev_log_sync'::regclass) LIKE '%LIMIT 300%', 'görünümde LIMIT 300 yok');
  t := pg_temp.ht_satir(h);
  ga := pg_temp.ht_gorev(h, 'HAYVAN_TAKIP_MUAYENE', t);
  gk := pg_temp.ht_gorev(h, 'HAYVAN_TAKIP_MUAYENE', t, true);
  SELECT to_jsonb(x) INTO v FROM public.v_gorev_log_sync x WHERE x.id = ga;
  PERFORM pg_temp.ht_alan(v, 'ref_takip_id', t::text);
  SELECT to_jsonb(x) INTO v FROM public.v_gorev_log_sync x WHERE x.id = gk;
  PERFORM pg_temp.ht_alan(v, 'ref_takip_id', t::text);
  -- Kapanış çifti
  PERFORM pg_temp.ht_red('23514', e, h, 'ZAYIFLAMA', NULL, now()::text, NULL, NULL);
  PERFORM pg_temp.ht_red('23514', e, h, 'ZAYIFLAMA', NULL, NULL, 'ELLE', NULL);
  -- Neden listesi; VAKA kapatan_vaka_id ister
  PERFORM pg_temp.ht_red('23514', e, h, 'ZAYIFLAMA', NULL, now()::text, 'BASKA', NULL);
  PERFORM pg_temp.ht_red('23514', e, h, 'ZAYIFLAMA', NULL, now()::text, 'VAKA', NULL);
  -- Boş sebep; DIGER açıklaması
  PERFORM pg_temp.ht_red('23514', e, h, '', NULL, NULL, NULL, NULL);
  PERFORM pg_temp.ht_red('23514', e, h, '   ', NULL, NULL, NULL, NULL);
  PERFORM pg_temp.ht_red('23514', e, h, 'DIGER', NULL, NULL, NULL, NULL);
  PERFORM pg_temp.ht_red('23514', e, h, 'DIGER', '   ', NULL, NULL, NULL);
  -- FK: hayvan ve görev referansı
  PERFORM pg_temp.ht_red('23503', e, pg_temp.ht_id(99)::text, 'ZAYIFLAMA', NULL, NULL, NULL, NULL);
  PERFORM pg_temp.ht_red('23503', 'INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, ref_takip_id) VALUES (%L, %L, %L::uuid)', h, 'HAYVAN_TAKIP_MUAYENE', pg_temp.ht_id(99)::text);
  -- Kısmi unique: açık aynı sebep reddedilir, DIGER ve kapalı satır muaf
  PERFORM pg_temp.ht_red('23505', e, h, 'TOPALLIK', NULL, NULL, NULL, NULL);
  EXECUTE format(e, h, 'DIGER', 'bir', NULL, NULL, NULL);
  EXECUTE format(e, h, 'DIGER', 'iki', NULL, NULL, NULL);
  EXECUTE format(e, h, 'TOPALLIK', NULL, now()::text, 'ELLE', NULL);
END $t$);
SELECT pg_temp.ht_test('L01', $t$ DECLARE h text := pg_temp.ht_hayvan(1); t uuid; n int;
BEGIN
  t := pg_temp.ht_satir(h);
  UPDATE public.hayvan_takip SET aciklama = 'E2E-HT-T güncel' WHERE id = t;
  SELECT count(*) INTO n FROM public.degisim_log WHERE tablo_adi = 'hayvan_takip' AND satir_pk->>'id' = t::text AND islem = 'I';
  PERFORM pg_temp.ht_esit(n::text, '1', 'I satırı');
  SELECT count(*) INTO n FROM public.degisim_log WHERE tablo_adi = 'hayvan_takip' AND satir_pk->>'id' = t::text AND islem = 'U';
  PERFORM pg_temp.ht_esit(n::text, '1', 'U satırı');
END $t$);

\endif

\if :b_rpc

SELECT pg_temp.ht_test('P03', $t$ DECLARE f text; r record; n int := 0;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'public.hayvan_takip_ac(text,text,text,date,time)',
    'public.hayvan_takip_kapat(uuid[],text,uuid)',
    'public.hayvan_takip_muayene_planla(uuid,date,time)',
    'public.hayvan_takip_muayene_sonuc(uuid,text,text,date,time)',
    'public.hayvan_takip_muayene_vaka(uuid,uuid,text)'] LOOP
    PERFORM pg_temp.ht_dogru(NOT has_function_privilege('anon', f, 'EXECUTE'), 'anon EXECUTE var: ' || f);
    PERFORM pg_temp.ht_dogru(has_function_privilege('authenticated', f, 'EXECUTE'), 'authenticated EXECUTE yok: ' || f);
    PERFORM pg_temp.ht_dogru(has_function_privilege('service_role', f, 'EXECUTE'), 'service_role EXECUTE yok: ' || f);
    PERFORM pg_temp.ht_dogru((SELECT prosecdef FROM pg_proc WHERE oid = f::regprocedure), 'DEFINER değil: ' || f);
  END LOOP;
  FOR r IN SELECT oid, proname, prosecdef FROM pg_proc
            WHERE pronamespace = 'public'::regnamespace AND (proname LIKE '\_hayvan\_takip\_%' OR proname = '_trg_hayvan_cikis_takip_kapat') LOOP
    n := n + 1;
    PERFORM pg_temp.ht_dogru(NOT has_function_privilege('authenticated', r.oid, 'EXECUTE'), 'authenticated EXECUTE var: ' || r.proname);
    PERFORM pg_temp.ht_dogru(NOT has_function_privilege('anon', r.oid, 'EXECUTE'), 'anon EXECUTE var: ' || r.proname);
    IF r.proname = '_trg_hayvan_cikis_takip_kapat' THEN
      PERFORM pg_temp.ht_dogru(r.prosecdef, '_trg_hayvan_cikis_takip_kapat DEFINER değil');
    END IF;
  END LOOP;
  PERFORM pg_temp.ht_esit(n::text, '5', 'iç yardımcı + tetikleyici fonksiyon sayısı');
END $t$);
SELECT pg_temp.ht_test('A01', $t$ DECLARE h text := pg_temp.ht_hayvan(1); r jsonb; t uuid; s jsonb;
BEGIN
  r := public.hayvan_takip_ac(h, 'TOPALLIK');
  PERFORM pg_temp.ht_alan(r, 'ok', 'true', 'gorev_id', NULL);
  t := (r->>'takip_id')::uuid;
  s := pg_temp.ht_tk(t);
  PERFORM pg_temp.ht_alan(s, 'hayvan_id', h, 'sebep_kodu', 'TOPALLIK', 'farm_id', public.current_farm_id()::text, 'acan', pg_temp.ht_eposta());
  PERFORM pg_temp.ht_alan(s, 'kapanis_tarihi', NULL, 'kapanis_nedeni', NULL, 'kapatan', NULL);
  PERFORM pg_temp.ht_kayit(t, 'ACILDI', '1');
  PERFORM pg_temp.ht_esit((SELECT count(*)::text FROM public.gorev_log WHERE hayvan_id = h), '0', 'görev sayısı');
END $t$);
SELECT pg_temp.ht_test('A02', $t$ DECLARE h text := pg_temp.ht_hayvan(1); d date := pg_temp.ht_gun() + 3; r jsonb; t uuid; g jsonb;
BEGIN
  r := public.hayvan_takip_ac(h, 'TOPALLIK', NULL, d, '10:30'::time);
  t := (r->>'takip_id')::uuid;
  g := pg_temp.ht_gr((r->>'gorev_id')::uuid);
  PERFORM pg_temp.ht_alan(g, 'hayvan_id', h, 'gorev_tipi', 'HAYVAN_TAKIP_MUAYENE', 'kaynak', 'HAYVAN_TAKIP:' || t, 'ref_takip_id', t::text);
  PERFORM pg_temp.ht_alan(g, 'hedef_tarih', d::text, 'hedef_saat', '10:30:00', 'aciklama', 'Topallık takibi muayenesi', 'parent_id', NULL);
  PERFORM pg_temp.ht_alan(g, 'etken_kod', NULL);
END $t$);
SELECT pg_temp.ht_test('A03', $t$ DECLARE h text := pg_temp.ht_hayvan(1, 'Ölü');
BEGIN
  PERFORM pg_temp.ht_red('HT_HAYVAN_AKTIF_DEGIL', 'SELECT public.hayvan_takip_ac(%L, %L)', h, 'TOPALLIK');
END $t$);
SELECT pg_temp.ht_test('A04', $t$ DECLARE h text := pg_temp.ht_hayvan(1); t uuid; t2 uuid;
BEGIN
  t := pg_temp.ht_ac(h);
  PERFORM pg_temp.ht_red('HT_SEBEP_ZATEN_ACIK', 'SELECT public.hayvan_takip_ac(%L, %L)', h, 'TOPALLIK');
  PERFORM public.hayvan_takip_kapat(ARRAY[t]);
  t2 := pg_temp.ht_ac(h);
  PERFORM pg_temp.ht_dogru(t2 IS DISTINCT FROM t, 'yeni takip satırı açılmadı');
END $t$);
SELECT pg_temp.ht_test('A05', $t$ DECLARE h text := pg_temp.ht_hayvan(1);
BEGIN
  PERFORM pg_temp.ht_red('HT_ACIKLAMA_GEREKLI', 'SELECT public.hayvan_takip_ac(%L, %L, %L)', h, 'DIGER', NULL);
  PERFORM pg_temp.ht_red('HT_ACIKLAMA_GEREKLI', 'SELECT public.hayvan_takip_ac(%L, %L, %L)', h, 'DIGER', '   ');
  PERFORM pg_temp.ht_red('HT_SEBEP_BOS', 'SELECT public.hayvan_takip_ac(%L, %L)', h, '   ');
END $t$);
SELECT pg_temp.ht_test('A06', $t$ DECLARE h text := pg_temp.ht_hayvan(1); t2 uuid; n int;
BEGIN
  PERFORM pg_temp.ht_ac(h, 'DIGER', 'birinci');
  t2 := pg_temp.ht_ac(h, 'DIGER', 'ikinci', pg_temp.ht_gun());
  SELECT count(*) INTO n FROM public.hayvan_takip WHERE hayvan_id = h AND sebep_kodu = 'DIGER' AND kapanis_tarihi IS NULL;
  PERFORM pg_temp.ht_esit(n::text, '2', 'açık DIGER sayısı');
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(pg_temp.ht_acik_id(t2)), 'aciklama', 'Diğer takibi muayenesi');
END $t$);
SELECT pg_temp.ht_test('A07', $t$ DECLARE h text := pg_temp.ht_hayvan(1); t uuid;
BEGIN
  t := pg_temp.ht_ac(h, 'YENI_KOD', NULL, pg_temp.ht_gun());
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t), 'sebep_kodu', 'YENI_KOD');
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(pg_temp.ht_acik_id(t)), 'aciklama', 'YENI_KOD takibi muayenesi');
  PERFORM pg_temp.ht_esit(public._hayvan_takip_sebep_etiket('SUT_DUSUSU'), 'Süt düşüşü', 'etiket SUT_DUSUSU');
  PERFORM pg_temp.ht_esit(public._hayvan_takip_sebep_etiket('ZAYIFLAMA'), 'Zayıflama', 'etiket ZAYIFLAMA');
  PERFORM pg_temp.ht_esit(public._hayvan_takip_sebep_etiket('ISTAHSIZLIK'), 'İştahsızlık', 'etiket ISTAHSIZLIK');
END $t$);
-- 200004: HALSIZLIK etiketi; diğer kodlar, ham kod davranışı, öznitelik ve ACL 200002 ile aynı.
SELECT pg_temp.ht_test('A09', $t$ DECLARE h text := pg_temp.ht_hayvan(1); t uuid; p record; n int;
BEGIN
  t := pg_temp.ht_ac(h, 'HALSIZLIK', NULL, pg_temp.ht_gun());
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(pg_temp.ht_acik_id(t)), 'aciklama', 'Halsizlik takibi muayenesi');
  PERFORM pg_temp.ht_esit(public._hayvan_takip_sebep_etiket('HALSIZLIK'), 'Halsizlik', 'etiket HALSIZLIK');
  PERFORM pg_temp.ht_esit(public._hayvan_takip_sebep_etiket('TOPALLIK'), 'Topallık', 'etiket TOPALLIK');
  PERFORM pg_temp.ht_esit(public._hayvan_takip_sebep_etiket('DIGER'), 'Diğer', 'etiket DIGER');
  PERFORM pg_temp.ht_esit(public._hayvan_takip_sebep_etiket('YOK_KOD'), 'YOK_KOD', 'bilinmeyen ham');
  SELECT f.oid, f.provolatile, f.prosecdef, f.proconfig, f.proacl, f.proowner INTO p FROM pg_proc f
   WHERE f.oid = 'public._hayvan_takip_sebep_etiket(text)'::regprocedure;
  PERFORM pg_temp.ht_esit(p.provolatile::text, 'i', 'IMMUTABLE');
  PERFORM pg_temp.ht_dogru(p.prosecdef, 'DEFINER değil');
  PERFORM pg_temp.ht_esit(p.proconfig::text, '{"search_path=public, pg_temp"}', 'search_path');
  PERFORM pg_temp.ht_dogru(p.proacl IS NOT NULL, 'ACL varsayılana döndü');
  SELECT count(*) INTO n FROM aclexplode(p.proacl) a WHERE a.grantee <> p.proowner;
  PERFORM pg_temp.ht_esit(n::text, '0', 'sahipten başkasına yetki');
  PERFORM pg_temp.ht_dogru(NOT has_function_privilege('service_role', p.oid, 'EXECUTE'), 'service_role EXECUTE var');
END $t$);
SELECT pg_temp.ht_test('A08', $t$ DECLARE h text := pg_temp.ht_hayvan(1); t uuid; n int;
BEGIN
  PERFORM pg_temp.ht_red('HT_GECMIS_TARIH', 'SELECT public.hayvan_takip_ac(%L, %L, NULL, %L)', h, 'TOPALLIK', (pg_temp.ht_gun() - 1)::text);
  PERFORM pg_temp.ht_red('HT_TARIH_GEREKLI', 'SELECT public.hayvan_takip_ac(%L, %L, NULL, NULL, %L)', h, 'TOPALLIK', '10:30');
  SELECT count(*) INTO n FROM public.hayvan_takip WHERE hayvan_id = h;
  PERFORM pg_temp.ht_esit(n::text, '0', 'red sonrası takip sayısı');
  t := pg_temp.ht_ac(h, 'TOPALLIK', NULL, pg_temp.ht_gun());
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(pg_temp.ht_acik_id(t)), 'hedef_tarih', pg_temp.ht_gun()::text);
END $t$);
SELECT pg_temp.ht_test('K01', $t$ DECLARE h text := pg_temp.ht_hayvan(1); t1 uuid; t2 uuid; r jsonb; x uuid;
BEGIN
  t1 := pg_temp.ht_ac(h, 'TOPALLIK');
  t2 := pg_temp.ht_ac(h, 'ZAYIFLAMA');
  r := public.hayvan_takip_kapat(ARRAY[t1, t2], 'E2E not');
  PERFORM pg_temp.ht_alan(r, 'ok', 'true', 'kapanan', '2', 'hayvan_id', h);
  FOREACH x IN ARRAY ARRAY[t1, t2] LOOP
    PERFORM pg_temp.ht_dogru(pg_temp.ht_tk(x)->>'kapanis_tarihi' IS NOT NULL, 'kapanis_tarihi boş');
    PERFORM pg_temp.ht_alan(pg_temp.ht_tk(x), 'kapanis_nedeni', 'ELLE', 'kapanis_notu', 'E2E not', 'kapatan', pg_temp.ht_eposta());
    PERFORM pg_temp.ht_kayit(x, 'KAPANDI', '1');
  END LOOP;
END $t$);
SELECT pg_temp.ht_test('K02', $t$ DECLARE h text := pg_temp.ht_hayvan(1); t uuid; g uuid;
BEGIN
  t := pg_temp.ht_ac(h, 'TOPALLIK', NULL, pg_temp.ht_gun() + 1);
  g := pg_temp.ht_acik_id(t);
  PERFORM public.hayvan_takip_kapat(ARRAY[t]);
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(g), 'iptal', 'true', 'kapatan_ref', 'hayvan-takip-kapandi');
END $t$);
SELECT pg_temp.ht_test('K03', $t$ BEGIN
  PERFORM pg_temp.ht_red('HT_BOS_LISTE', 'SELECT public.hayvan_takip_kapat(%L::uuid[])', '{}');
  PERFORM pg_temp.ht_red('HT_BOS_LISTE', 'SELECT public.hayvan_takip_kapat(NULL::uuid[])');
END $t$);
SELECT pg_temp.ht_test('K04', $t$ DECLARE t1 uuid := pg_temp.ht_ac(pg_temp.ht_hayvan(1)); t2 uuid := pg_temp.ht_ac(pg_temp.ht_hayvan(2));
BEGIN
  PERFORM pg_temp.ht_red('HT_FARKLI_HAYVAN', 'SELECT public.hayvan_takip_kapat(%L::uuid[])', ARRAY[t1, t2]::text);
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t1), 'kapanis_tarihi', NULL);
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t2), 'kapanis_tarihi', NULL);
END $t$);
SELECT pg_temp.ht_test('K05', $t$ DECLARE h text := pg_temp.ht_hayvan(1); t1 uuid := pg_temp.ht_ac(h, 'TOPALLIK'); t2 uuid := pg_temp.ht_ac(h, 'ZAYIFLAMA'); r jsonb;
BEGIN
  PERFORM public.hayvan_takip_kapat(ARRAY[t1], 'ilk');
  r := public.hayvan_takip_kapat(ARRAY[t1, t2], 'ikinci');
  PERFORM pg_temp.ht_alan(r, 'kapanan', '1');
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t1), 'kapanis_notu', 'ilk');
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t2), 'kapanis_notu', 'ikinci');
  PERFORM pg_temp.ht_kayit(t1, 'KAPANDI', '1');
  PERFORM pg_temp.ht_kayit(t2, 'KAPANDI', '1');
END $t$);
SELECT pg_temp.ht_test('K06', $t$ DECLARE h text := pg_temp.ht_hayvan(1); t uuid := pg_temp.ht_ac(h); c uuid := pg_temp.ht_vaka(h); r jsonb;
BEGIN
  r := public.hayvan_takip_kapat(ARRAY[t], NULL, c);
  PERFORM pg_temp.ht_alan(r, 'kapanan', '1');
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t), 'kapanis_nedeni', 'VAKA', 'kapatan_vaka_id', c::text);
END $t$);
SELECT pg_temp.ht_test('K07', $t$ DECLARE h text := pg_temp.ht_hayvan(1); t uuid := pg_temp.ht_ac(h); c uuid := pg_temp.ht_vaka(pg_temp.ht_hayvan(2));
BEGIN
  PERFORM pg_temp.ht_red('HT_VAKA_UYUMSUZ', 'SELECT public.hayvan_takip_kapat(%L::uuid[], NULL, %L::uuid)', ARRAY[t]::text, c::text);
  -- FK yok (R9): var olmayan vaka da aynı kodla düşmeli
  PERFORM pg_temp.ht_red('HT_VAKA_UYUMSUZ', 'SELECT public.hayvan_takip_kapat(%L::uuid[], NULL, %L::uuid)', ARRAY[t]::text, pg_temp.ht_id(99)::text);
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t), 'kapanis_tarihi', NULL);
END $t$);
SELECT pg_temp.ht_test('M01', $t$ DECLARE t uuid := pg_temp.ht_ac(pg_temp.ht_hayvan(1)); d date := pg_temp.ht_gun() + 2; r jsonb; g jsonb;
BEGIN
  r := public.hayvan_takip_muayene_planla(t, d, '09:15'::time);
  PERFORM pg_temp.ht_alan(r, 'ok', 'true', 'yeni', 'true');
  PERFORM pg_temp.ht_esit(pg_temp.ht_acik(t)::text, '1', 'açık görev');
  PERFORM pg_temp.ht_alan(r, 'gorev_id', pg_temp.ht_acik_id(t)::text);
  g := pg_temp.ht_gr(pg_temp.ht_acik_id(t));
  PERFORM pg_temp.ht_alan(g, 'gorev_tipi', 'HAYVAN_TAKIP_MUAYENE', 'hedef_tarih', d::text, 'hedef_saat', '09:15:00');
END $t$);
SELECT pg_temp.ht_test('M02', $t$ DECLARE t uuid := pg_temp.ht_ac(pg_temp.ht_hayvan(1)); d date := pg_temp.ht_gun() + 5; r1 jsonb; r2 jsonb; g jsonb;
BEGIN
  r1 := public.hayvan_takip_muayene_planla(t, pg_temp.ht_gun() + 2, '09:15'::time);
  r2 := public.hayvan_takip_muayene_planla(t, d, '14:00'::time);
  PERFORM pg_temp.ht_alan(r2, 'yeni', 'false', 'gorev_id', r1->>'gorev_id');
  PERFORM pg_temp.ht_esit(pg_temp.ht_acik(t)::text, '1', 'açık görev');
  g := pg_temp.ht_gr((r2->>'gorev_id')::uuid);
  PERFORM pg_temp.ht_alan(g, 'hedef_tarih', d::text, 'hedef_saat', '14:00:00');
END $t$);
SELECT pg_temp.ht_test('M03', $t$ DECLARE h text := pg_temp.ht_hayvan(1); t uuid := pg_temp.ht_ac(h); b uuid := pg_temp.ht_satir(pg_temp.ht_hayvan(2, 'Ölü')); s constant text := 'SELECT public.hayvan_takip_muayene_planla(%L::uuid, %L::date)';
BEGIN
  PERFORM public.hayvan_takip_kapat(ARRAY[t]);
  PERFORM pg_temp.ht_red('HT_TAKIP_KAPALI', s, t::text, (pg_temp.ht_gun() + 1)::text);
  PERFORM pg_temp.ht_red('HT_HAYVAN_AKTIF_DEGIL', s, b::text, (pg_temp.ht_gun() + 1)::text);
  PERFORM pg_temp.ht_red('HT_TAKIP_YOK', s, pg_temp.ht_id(99)::text, (pg_temp.ht_gun() + 1)::text);
END $t$);
SELECT pg_temp.ht_test('M04', $t$ DECLARE
  h text := pg_temp.ht_hayvan(1);
  t uuid := pg_temp.ht_ac(h, 'TOPALLIK', NULL, pg_temp.ht_gun() + 1);
  t2 uuid := pg_temp.ht_ac(h, 'ZAYIFLAMA');
  s constant text := 'INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, ref_takip_id, tamamlandi, iptal) VALUES (%L, %L, %L::uuid, %L::boolean, %L::boolean)';
BEGIN
  PERFORM pg_temp.ht_red('23505', s, h, 'HAYVAN_TAKIP_MUAYENE', t::text, 'false', 'false');
  -- R1: NULL durumlu satır indeks dışına kaçmaz; iki yönde de
  PERFORM pg_temp.ht_red('23505', s, h, 'HAYVAN_TAKIP_MUAYENE', t::text, NULL, NULL);
  EXECUTE format(s, h, 'HAYVAN_TAKIP_MUAYENE', t2, NULL, NULL);
  PERFORM pg_temp.ht_red('23505', s, h, 'HAYVAN_TAKIP_MUAYENE', t2::text, 'false', 'false');
  -- Kapalı satırlar kural dışı
  EXECUTE format(s, h, 'HAYVAN_TAKIP_MUAYENE', t, 'true', 'false');
  EXECUTE format(s, h, 'HAYVAN_TAKIP_MUAYENE', t, 'false', 'true');
END $t$);
SELECT pg_temp.ht_test('M05', $t$ DECLARE t uuid := pg_temp.ht_ac(pg_temp.ht_hayvan(1));
BEGIN
  PERFORM pg_temp.ht_red('HT_TARIH_GEREKLI', 'SELECT public.hayvan_takip_muayene_planla(%L::uuid, NULL::date)', t::text);
  PERFORM pg_temp.ht_red('HT_GECMIS_TARIH', 'SELECT public.hayvan_takip_muayene_planla(%L::uuid, %L::date)', t::text, (pg_temp.ht_gun() - 1)::text);
  PERFORM pg_temp.ht_esit(pg_temp.ht_acik(t)::text, '0', 'açık görev');
END $t$);
SELECT pg_temp.ht_test('S01', $t$ DECLARE t uuid := pg_temp.ht_ac(pg_temp.ht_hayvan(1), 'TOPALLIK', NULL, pg_temp.ht_gun()); g uuid := pg_temp.ht_acik_id(t);
  d date := pg_temp.ht_gun() + 3; r jsonb; y jsonb; l record;
BEGIN
  r := public.hayvan_takip_muayene_sonuc(g, 'SURSUN', 'E2E sonuç', d, '11:00'::time);
  PERFORM pg_temp.ht_alan(r, 'ok', 'true', 'sonuc', 'SURSUN', 'takip_id', t::text, 'kapandi', 'false');
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(g), 'tamamlandi', 'true', 'iptal', 'false');
  PERFORM pg_temp.ht_dogru(pg_temp.ht_gr(g)->>'tamamlanma_tarihi' IS NOT NULL, 'tamamlanma_tarihi boş');
  PERFORM pg_temp.ht_esit(pg_temp.ht_acik(t)::text, '1', 'yeni açık görev');
  PERFORM pg_temp.ht_alan(r, 'yeni_gorev_id', pg_temp.ht_acik_id(t)::text);
  y := pg_temp.ht_gr((r->>'yeni_gorev_id')::uuid);
  PERFORM pg_temp.ht_alan(y, 'hedef_tarih', d::text, 'hedef_saat', '11:00:00');
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t), 'kapanis_tarihi', NULL);
  PERFORM pg_temp.ht_kayit(t, 'MUAYENE', '1');
  SELECT kullanici_notu, snapshot INTO l FROM public.islem_log WHERE tip = 'HAYVAN_TAKIP_MUAYENE' AND ref_id = t::text;
  PERFORM pg_temp.ht_esit(l.kullanici_notu, 'E2E sonuç', 'log notu');
  PERFORM pg_temp.ht_alan(l.snapshot, 'sonuc', 'SURSUN');
  PERFORM pg_temp.ht_kayit(t, 'KAPANDI', '0');
END $t$);
SELECT pg_temp.ht_test('S02', $t$ DECLARE t uuid := pg_temp.ht_ac(pg_temp.ht_hayvan(1), 'TOPALLIK', NULL, pg_temp.ht_gun()); g uuid := pg_temp.ht_acik_id(t); r jsonb;
BEGIN
  -- R7: geçmiş sonraki tarih reddedilir, görev açık kalır
  PERFORM pg_temp.ht_red('HT_GECMIS_TARIH', 'SELECT public.hayvan_takip_muayene_sonuc(%L::uuid, %L, NULL, %L::date)', g::text, 'SURSUN', (pg_temp.ht_gun() - 1)::text);
  PERFORM pg_temp.ht_esit(pg_temp.ht_acik_id(t)::text, g::text, 'red sonrası görev açık');
  r := public.hayvan_takip_muayene_sonuc(g, 'SURSUN');
  PERFORM pg_temp.ht_alan(r, 'yeni_gorev_id', NULL);
  PERFORM pg_temp.ht_esit(pg_temp.ht_acik(t)::text, '0', 'açık görev');
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(g), 'tamamlandi', 'true');
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t), 'kapanis_tarihi', NULL);
END $t$);
SELECT pg_temp.ht_test('S03', $t$ DECLARE t uuid := pg_temp.ht_ac(pg_temp.ht_hayvan(1), 'TOPALLIK', NULL, pg_temp.ht_gun()); g uuid := pg_temp.ht_acik_id(t); r jsonb;
BEGIN
  r := public.hayvan_takip_muayene_sonuc(g, 'KAPANSIN', 'iyileşti');
  PERFORM pg_temp.ht_alan(r, 'kapandi', 'true', 'sonuc', 'KAPANSIN', 'yeni_gorev_id', NULL);
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(g), 'tamamlandi', 'true', 'iptal', 'false');
  PERFORM pg_temp.ht_esit(pg_temp.ht_acik(t)::text, '0', 'açık görev');
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t), 'kapanis_nedeni', 'MUAYENE', 'kapanis_notu', 'iyileşti');
  PERFORM pg_temp.ht_kayit(t, 'MUAYENE', '1', 'KAPANDI', '1');
END $t$);
SELECT pg_temp.ht_test('S04', $t$ DECLARE g uuid := pg_temp.ht_gorev(pg_temp.ht_hayvan(1), 'E2E_HT_DUZ');
BEGIN
  PERFORM pg_temp.ht_red('HT_GOREV_TIP_UYUMSUZ', 'SELECT public.hayvan_takip_muayene_sonuc(%L::uuid, %L)', g::text, 'SURSUN');
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(g), 'tamamlandi', 'false');
END $t$);
SELECT pg_temp.ht_test('S05', $t$ DECLARE h text := pg_temp.ht_hayvan(1); t uuid := pg_temp.ht_ac(h, 'TOPALLIK', NULL, pg_temp.ht_gun()); g uuid := pg_temp.ht_acik_id(t); t2 uuid := pg_temp.ht_ac(h, 'ZAYIFLAMA', NULL, pg_temp.ht_gun()); g2 uuid := pg_temp.ht_acik_id(t2); s constant text := 'SELECT public.hayvan_takip_muayene_sonuc(%L::uuid, %L)';
BEGIN
  PERFORM public.hayvan_takip_muayene_sonuc(g, 'SURSUN');
  PERFORM pg_temp.ht_red('HT_GOREV_KAPALI', s, g::text, 'SURSUN');
  UPDATE public.gorev_log SET iptal = true WHERE id = g2;
  PERFORM pg_temp.ht_red('HT_GOREV_KAPALI', s, g2::text, 'SURSUN');
  PERFORM pg_temp.ht_red('HT_GOREV_YOK', s, pg_temp.ht_id(99)::text, 'SURSUN');
END $t$);
SELECT pg_temp.ht_test('S06', $t$ DECLARE t uuid := pg_temp.ht_ac(pg_temp.ht_hayvan(1), 'TOPALLIK', NULL, pg_temp.ht_gun()); g uuid := pg_temp.ht_acik_id(t);
BEGIN
  UPDATE public.hayvan_takip SET kapanis_tarihi = now(), kapanis_nedeni = 'ELLE' WHERE id = t;
  PERFORM pg_temp.ht_red('HT_TAKIP_KAPALI', 'SELECT public.hayvan_takip_muayene_sonuc(%L::uuid, %L)', g::text, 'SURSUN');
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(g), 'tamamlandi', 'false');
END $t$);
SELECT pg_temp.ht_test('S07', $t$ DECLARE t uuid := pg_temp.ht_ac(pg_temp.ht_hayvan(1), 'TOPALLIK', NULL, pg_temp.ht_gun()); g uuid := pg_temp.ht_acik_id(t);
BEGIN
  PERFORM pg_temp.ht_red('HT_SONUC_GECERSIZ', 'SELECT public.hayvan_takip_muayene_sonuc(%L::uuid, %L)', g::text, 'BELKI');
  PERFORM pg_temp.ht_red('HT_SONUC_GECERSIZ', 'SELECT public.hayvan_takip_muayene_sonuc(%L::uuid, NULL)', g::text);
  PERFORM pg_temp.ht_esit(pg_temp.ht_acik_id(t)::text, g::text, 'görev açık');
END $t$);
SELECT pg_temp.ht_test('V01', $t$ DECLARE h text := pg_temp.ht_hayvan(1); t uuid := pg_temp.ht_ac(h, 'TOPALLIK', NULL, pg_temp.ht_gun()); g uuid := pg_temp.ht_acik_id(t); c uuid := pg_temp.ht_vaka(h); r jsonb; l record;
BEGIN
  r := public.hayvan_takip_muayene_vaka(g, c, 'tedaviye alındı');
  PERFORM pg_temp.ht_alan(r, 'ok', 'true', 'sonuc', 'VAKA', 'takip_id', t::text, 'case_id', c::text, 'kapandi', 'true');
  -- Görev iptal değil tamam: sıra yanlışsa _kapat_ic iptal yazardı
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(g), 'tamamlandi', 'true', 'iptal', 'false', 'kapatan_ref', NULL);
  PERFORM pg_temp.ht_dogru(pg_temp.ht_gr(g)->>'tamamlanma_tarihi' IS NOT NULL, 'tamamlanma_tarihi boş');
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t), 'kapanis_nedeni', 'VAKA', 'kapatan_vaka_id', c::text, 'kapanis_notu', 'tedaviye alındı', 'kapatan', pg_temp.ht_eposta());
  PERFORM pg_temp.ht_kayit(t, 'MUAYENE', '1', 'KAPANDI', '1');
  SELECT kullanici_notu, snapshot INTO l FROM public.islem_log WHERE tip = 'HAYVAN_TAKIP_MUAYENE' AND ref_id = t::text;
  PERFORM pg_temp.ht_esit(l.kullanici_notu, 'tedaviye alındı', 'log notu');
  PERFORM pg_temp.ht_alan(l.snapshot, 'sonuc', 'VAKA', 'gorev_id', g::text, 'kapatan_vaka_id', c::text, 'sebep_kodu', 'TOPALLIK', 'kullanici', pg_temp.ht_eposta());
  PERFORM pg_temp.ht_esit(pg_temp.ht_acik(t)::text, '0', 'açık görev');
END $t$);
SELECT pg_temp.ht_test('V02', $t$ DECLARE h text := pg_temp.ht_hayvan(1); c uuid := pg_temp.ht_vaka(h); d uuid := pg_temp.ht_gorev(h, 'E2E_HT_DUZ'); rs uuid := pg_temp.ht_gorev(h, 'HAYVAN_TAKIP_MUAYENE'); s constant text := 'SELECT public.hayvan_takip_muayene_vaka(%L::uuid, %L::uuid)';
BEGIN
  PERFORM pg_temp.ht_red('HT_GOREV_YOK', s, pg_temp.ht_id(99)::text, c::text);
  PERFORM pg_temp.ht_red('HT_GOREV_TIP_UYUMSUZ', s, d::text, c::text);
  PERFORM pg_temp.ht_red('HT_TAKIP_YOK', s, rs::text, c::text);
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(d), 'tamamlandi', 'false');
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(rs), 'tamamlandi', 'false');
END $t$);
SELECT pg_temp.ht_test('V03', $t$ DECLARE h text := pg_temp.ht_hayvan(1); c uuid := pg_temp.ht_vaka(h); t uuid := pg_temp.ht_ac(h, 'TOPALLIK', NULL, pg_temp.ht_gun()); g uuid := pg_temp.ht_acik_id(t);
  t2 uuid := pg_temp.ht_ac(h, 'ZAYIFLAMA', NULL, pg_temp.ht_gun()); g2 uuid := pg_temp.ht_acik_id(t2);
  t3 uuid := pg_temp.ht_ac(h, 'ISTAHSIZLIK', NULL, pg_temp.ht_gun()); g3 uuid := pg_temp.ht_acik_id(t3); s constant text := 'SELECT public.hayvan_takip_muayene_vaka(%L::uuid, %L::uuid)';
BEGIN
  -- Tamamlanmış görev: ikinci çağrı dahil; iptal görev
  PERFORM public.hayvan_takip_muayene_sonuc(g, 'SURSUN');
  PERFORM pg_temp.ht_red('HT_GOREV_KAPALI', s, g::text, c::text);
  UPDATE public.gorev_log SET iptal = true WHERE id = g2;
  PERFORM pg_temp.ht_red('HT_GOREV_KAPALI', s, g2::text, c::text);
  -- Görev açık, takip kapalı (RPC dışı kurulan tutarsızlık, §20.9)
  UPDATE public.hayvan_takip SET kapanis_tarihi = now(), kapanis_nedeni = 'ELLE' WHERE id = t3;
  PERFORM pg_temp.ht_red('HT_TAKIP_KAPALI', s, g3::text, c::text);
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(g3), 'tamamlandi', 'false');
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t3), 'kapanis_nedeni', 'ELLE', 'kapatan_vaka_id', NULL);
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t), 'kapanis_tarihi', NULL);
  PERFORM pg_temp.ht_kayit(t3, 'MUAYENE', '0');
END $t$);
SELECT pg_temp.ht_test('V04', $t$ DECLARE h text := pg_temp.ht_hayvan(1); t uuid := pg_temp.ht_ac(h, 'TOPALLIK', NULL, pg_temp.ht_gun()); g uuid := pg_temp.ht_acik_id(t);
  baska uuid := pg_temp.ht_vaka(pg_temp.ht_hayvan(2)); kapali uuid := pg_temp.ht_vaka(h); s constant text := 'SELECT public.hayvan_takip_muayene_vaka(%L::uuid, %L::uuid)';
BEGIN
  UPDATE public.cases SET status = 'closed', closed_at = now() WHERE id = kapali;
  PERFORM pg_temp.ht_red('HT_VAKA_UYUMSUZ', s, g::text, baska::text);
  PERFORM pg_temp.ht_red('HT_VAKA_UYUMSUZ', s, g::text, kapali::text);
  PERFORM pg_temp.ht_red('HT_VAKA_UYUMSUZ', s, g::text, pg_temp.ht_id(99)::text);
  PERFORM pg_temp.ht_red('HT_VAKA_UYUMSUZ', 'SELECT public.hayvan_takip_muayene_vaka(%L::uuid, NULL::uuid)', g::text);
  -- Hiçbir ret iz bırakmaz
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(g), 'tamamlandi', 'false', 'iptal', 'false');
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t), 'kapanis_tarihi', NULL);
  PERFORM pg_temp.ht_kayit(t, 'MUAYENE', '0', 'KAPANDI', '0');
END $t$);
-- K6: yalnız muayenesi yapılan takip kapanır; diğer takip ve görevi sorulana kadar açık kalır. Mevcut vakaya ikinci takip de bağlanabilir.
SELECT pg_temp.ht_test('V05', $t$ DECLARE h text := pg_temp.ht_hayvan(1); c uuid := pg_temp.ht_vaka(h);
  t uuid := pg_temp.ht_ac(h, 'TOPALLIK', NULL, pg_temp.ht_gun()); g uuid := pg_temp.ht_acik_id(t);
  t2 uuid := pg_temp.ht_ac(h, 'ZAYIFLAMA', NULL, pg_temp.ht_gun() + 1); g2 uuid := pg_temp.ht_acik_id(t2);
BEGIN
  PERFORM public.hayvan_takip_muayene_vaka(g, c);
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t2), 'kapanis_tarihi', NULL);
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(g2), 'tamamlandi', 'false', 'iptal', 'false');
  PERFORM pg_temp.ht_kayit(t2, 'MUAYENE', '0', 'KAPANDI', '0');
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t), 'kapanis_notu', NULL);
  PERFORM public.hayvan_takip_muayene_vaka(g2, c);
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t2), 'kapanis_nedeni', 'VAKA', 'kapatan_vaka_id', c::text);
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(g2), 'tamamlandi', 'true', 'iptal', 'false');
END $t$);
-- Yol A zinciri: create_case açık HAYVAN_TAKIP_MUAYENE görevini görmez (TAKIP_ACIK yok), sonra bağ kurulur.
SELECT pg_temp.ht_test('V07', $t$ DECLARE h text := pg_temp.ht_hayvan(1); t uuid := pg_temp.ht_ac(h, 'TOPALLIK', NULL, pg_temp.ht_gun()); g uuid := pg_temp.ht_acik_id(t); r jsonb;
BEGIN
  r := public.create_case(h, (SELECT id FROM public.diseases ORDER BY id LIMIT 1), 'E2E-HT-T', false);
  PERFORM pg_temp.ht_alan(r, 'ok', 'true');
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(g), 'tamamlandi', 'false', 'iptal', 'false');
  PERFORM public.hayvan_takip_muayene_vaka(g, (r->>'case_id')::uuid);
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t), 'kapanis_nedeni', 'VAKA', 'kapatan_vaka_id', r->>'case_id');
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(g), 'tamamlandi', 'true', 'iptal', 'false');
END $t$);
-- ACL: PUBLIC ve anon yok. proacl NULL varsayılan PUBLIC EXECUTE demektir, ayrı ölçülür.
SELECT pg_temp.ht_test('V06', $t$ DECLARE f constant regprocedure := 'public.hayvan_takip_muayene_vaka(uuid,uuid,text)'::regprocedure; p record;
BEGIN
  SELECT prosecdef, proacl, proconfig INTO p FROM pg_proc WHERE oid = f;
  PERFORM pg_temp.ht_dogru(p.proacl IS NOT NULL, 'proacl NULL: PUBLIC EXECUTE varsayılan');
  PERFORM pg_temp.ht_dogru(NOT EXISTS (SELECT 1 FROM aclexplode(p.proacl) a WHERE a.grantee = 0), 'PUBLIC EXECUTE var');
  PERFORM pg_temp.ht_dogru(NOT has_function_privilege('anon', f, 'EXECUTE'), 'anon EXECUTE var');
  PERFORM pg_temp.ht_dogru(has_function_privilege('authenticated', f, 'EXECUTE'), 'authenticated EXECUTE yok');
  PERFORM pg_temp.ht_dogru(p.prosecdef, 'DEFINER değil');
  PERFORM pg_temp.ht_dogru('search_path=public, pg_temp' = ANY (p.proconfig), 'search_path sabit değil');
END $t$);
-- Kilitler: vaka FOR SHARE, hayvan FOR NO KEY UPDATE. Eşzamanlı davranış: tests/sql/hayvan_takip_kilit_test.sh.
SELECT pg_temp.ht_test('V08', $t$ DECLARE src text := (SELECT prosrc FROM pg_proc WHERE oid = 'public.hayvan_takip_muayene_vaka(uuid,uuid,text)'::regprocedure);
BEGIN
  PERFORM pg_temp.ht_dogru(src ~ 'public\.cases c\s+WHERE[^;]*FOR SHARE;', 'vaka satırı kilitli değil');
  PERFORM pg_temp.ht_dogru(src ~ 'public\.hayvanlar\s+WHERE[^;]*FOR NO KEY UPDATE;', 'hayvan kilidi NO KEY UPDATE değil');
END $t$);
SELECT pg_temp.ht_test('C01', $t$ DECLARE h text := pg_temp.ht_hayvan(1); t1 uuid := pg_temp.ht_ac(h, 'TOPALLIK', NULL, pg_temp.ht_gun() + 1); g uuid := pg_temp.ht_acik_id(t1);
  t2 uuid := pg_temp.ht_ac(h, 'ZAYIFLAMA'); t3 uuid := pg_temp.ht_ac(h, 'ISTAHSIZLIK'); x uuid; r jsonb;
BEGIN
  PERFORM public.hayvan_takip_kapat(ARRAY[t3], 'önceden kapalı');
  r := public.cikis_yap(h, 'olum');
  PERFORM pg_temp.ht_alan(r, 'ok', 'true');
  FOREACH x IN ARRAY ARRAY[t1, t2] LOOP
    PERFORM pg_temp.ht_dogru(pg_temp.ht_tk(x)->>'kapanis_tarihi' IS NOT NULL, 'kapanis_tarihi boş');
    PERFORM pg_temp.ht_alan(pg_temp.ht_tk(x), 'kapanis_nedeni', 'CIKIS', 'kapatan', 'sistem');
    PERFORM pg_temp.ht_kayit(x, 'KAPANDI', '1');
  END LOOP;
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(g), 'iptal', 'true');
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t3), 'kapanis_nedeni', 'ELLE', 'kapatan', pg_temp.ht_eposta(), 'kapanis_notu', 'önceden kapalı');
  PERFORM pg_temp.ht_kayit(t3, 'KAPANDI', '1');
END $t$);
-- C02, C04: rol değişikliği pg_temp çağrılarının dışında kalır; hata halinde alt işlem geri sarar.
SELECT pg_temp.ht_test('C02', $t$ DECLARE h text := pg_temp.ht_hayvan(1); t uuid := pg_temp.ht_ac(h); r jsonb;
BEGIN
  SET LOCAL ROLE authenticated;
  r := public.cikis_yap(h, 'olum');
  RESET ROLE;
  PERFORM pg_temp.ht_alan(r, 'ok', 'true');
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t), 'kapanis_nedeni', 'CIKIS');
END $t$);
SELECT pg_temp.ht_test('C03', $t$ DECLARE h text := pg_temp.ht_hayvan(1); t uuid := pg_temp.ht_ac(h, 'TOPALLIK', NULL, pg_temp.ht_gun() + 1); g uuid := pg_temp.ht_acik_id(t);
BEGIN
  UPDATE public.hayvanlar SET durum = 'Aktif' WHERE id = h;
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t), 'kapanis_tarihi', NULL);
  PERFORM pg_temp.ht_kayit(t, 'KAPANDI', '0');
  PERFORM pg_temp.ht_esit(pg_temp.ht_acik_id(t)::text, g::text, 'görev kapandı');
END $t$);
SELECT pg_temp.ht_test('C04', $t$ DECLARE h text := pg_temp.ht_hayvan(1); t uuid := pg_temp.ht_ac(h); n int;
BEGIN
  SET LOCAL ROLE authenticated;
  UPDATE public.hayvanlar SET durum = 'Ölü' WHERE id = h;
  GET DIAGNOSTICS n = ROW_COUNT;
  RESET ROLE;
  PERFORM pg_temp.ht_esit(n::text, '1', 'güncellenen hayvan');
  PERFORM pg_temp.ht_alan(pg_temp.ht_tk(t), 'kapanis_nedeni', 'CIKIS', 'kapatan', 'sistem');
  PERFORM pg_temp.ht_kayit(t, 'KAPANDI', '1');
END $t$);

\endif

\if :b_guard

SELECT pg_temp.ht_test('G01', $t$ DECLARE t uuid := pg_temp.ht_ac(pg_temp.ht_hayvan(1), 'TOPALLIK', NULL, pg_temp.ht_gun()); g uuid := pg_temp.ht_acik_id(t);
BEGIN
  PERFORM pg_temp.ht_red('MUAYENE_SONUC_GEREKLI:HAYVAN_TAKIP_MUAYENE', 'SELECT public.gorev_tamamla(%L, NULL, false)', g::text);
  PERFORM pg_temp.ht_esit(pg_temp.ht_acik_id(t)::text, g::text, 'görev açık');
END $t$);
SELECT pg_temp.ht_test('G02', $t$ DECLARE t uuid := pg_temp.ht_ac(pg_temp.ht_hayvan(1), 'TOPALLIK', NULL, pg_temp.ht_gun()); g uuid := pg_temp.ht_acik_id(t); r jsonb;
BEGIN
  r := public.gorev_tamamla(g::text, NULL, true);
  PERFORM pg_temp.ht_alan(r, 'ok', 'true', 'iptal', 'true');
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(g), 'iptal', 'true');
END $t$);
SELECT pg_temp.ht_test('G03', $t$ DECLARE h text := pg_temp.ht_hayvan(1); k text;
BEGIN
  FOREACH k IN ARRAY ARRAY['TAKIP_MUAYENE', 'GEBELIK_KONTROL'] LOOP
    PERFORM pg_temp.ht_red('MUAYENE_SONUC_GEREKLI:' || k, 'SELECT public.gorev_tamamla(%L, NULL, false)', pg_temp.ht_gorev(h, k)::text);
  END LOOP;
END $t$);
SELECT pg_temp.ht_test('G04', $t$ DECLARE g uuid := pg_temp.ht_gorev(pg_temp.ht_hayvan(1), 'E2E_HT_DUZ'); r jsonb;
BEGIN
  r := public.gorev_tamamla(g::text);
  PERFORM pg_temp.ht_alan(r, 'ok', 'true');
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(g), 'tamamlandi', 'true', 'iptal', 'false');
END $t$);
SELECT pg_temp.ht_test('G05', $t$ DECLARE t uuid := pg_temp.ht_ac(pg_temp.ht_hayvan(1), 'TOPALLIK', NULL, pg_temp.ht_gun()); g uuid := pg_temp.ht_acik_id(t);
BEGIN
  PERFORM pg_temp.ht_red('MUAYENE_SONUC_GEREKLI:HAYVAN_TAKIP_MUAYENE', 'SELECT public._asistan_step_calistir(%L, %L::jsonb)', 'gorev_kapat', jsonb_build_object('gorev_idler', jsonb_build_array(g))::text);
  PERFORM pg_temp.ht_esit(pg_temp.ht_acik_id(t)::text, g::text, 'görev açık');
END $t$);
SELECT pg_temp.ht_test('G06', $t$ DECLARE d date := pg_temp.ht_gun() + 2; t uuid := pg_temp.ht_ac(pg_temp.ht_hayvan(1), 'TOPALLIK', NULL, d); g uuid := pg_temp.ht_acik_id(t); v text;
BEGIN
  BEGIN
    PERFORM public.gorev_ertele(g, d + 3);
    v := '<hata yok>';
  EXCEPTION WHEN OTHERS THEN v := SQLERRM;
  END;
  PERFORM pg_temp.ht_dogru(v LIKE 'GOREV_ERTELENEMEZ:%TIP_ERTELENEMEZ%', 'gorev_ertele: ' || v);
  PERFORM pg_temp.ht_alan(pg_temp.ht_gr(g), 'hedef_tarih', d::text);
END $t$);

\endif
\o
