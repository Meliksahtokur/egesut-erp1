-- tests/sql/ovsync_mu_log_kolu_test.sql — `_vaka_ovsync_mu` log kolu yanlış pozitif kilidi (2026-10-17).
-- HEDEF: YALNIZ yerel izole parite DB (db-build-baseline.sh çıktısı). Canlıya (demo/prod) bu betikle erişilmez.
-- KOŞUM: psql "$ISO" -X -v ON_ERROR_STOP=1 -f tests/sql/ovsync_mu_log_kolu_test.sql → rc=0 hepsi PASS; rc!=0 en az biri RED.
-- Kural (root ruling, istatistik `stat_vaka_ovsync_mu` ile aynı): log kolu yalnız anahtardaki şablon
-- `protokol_ailesi='OVSYNC'` VE log `iptal=false` iken Ovsync sayar; `:MANUEL` anahtarı şablonsuzdur → saymaz.
-- Diğer kollar (protocol_family damgası, OVSYNC-eşlemeli hastalık) AYNEN. Fixture + yan etkiler tek
-- transaction'da, sonda ROLLBACK. Sabit uuid: pg_temp.omu_id(sınıf, no) — c=vaka, e=görev, 1=hastalık, 3=şablon, 5=eşlem.
\echo '=== OVSYNC-MU LOG KOLU — izole DB testi ==='
BEGIN;
CREATE FUNCTION pg_temp.omu_id(p text, i int) RETURNS uuid LANGUAGE sql IMMUTABLE
  AS $$ SELECT ('e2e00000-0000-4000-8000-0000000' || p || '0f' || lpad(i::text, 2, '0'))::uuid $$;
CREATE FUNCTION pg_temp.bg() RETURNS date LANGUAGE sql STABLE AS $$ SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date $$;
DELETE FROM gorev_log WHERE hayvan_id LIKE 'E2E-OMU-H-%'; DELETE FROM cases WHERE animal_id LIKE 'E2E-OMU-H-%';
DELETE FROM hayvanlar WHERE id LIKE 'E2E-OMU-H-%'; DELETE FROM sablon_hastalik_eslem WHERE sablon_id IN (SELECT id FROM tedavi_sablonu WHERE ad LIKE 'E2E-OMU-%');
DELETE FROM tedavi_sablonu WHERE ad LIKE 'E2E-OMU-%'; DELETE FROM diseases WHERE name LIKE 'E2E-OMU-%';
-- Hastalıklar: 1=Mastit (eşlemesiz), 2=Ovsync (OVSYNC şablonuna eşlemeli)
INSERT INTO diseases(id, name, category) VALUES (pg_temp.omu_id('1',1), 'E2E-OMU-Mastit', 'Meme'), (pg_temp.omu_id('1',2), 'E2E-OMU-Ovsync', 'Üreme');
-- Şablonlar: 1=mastit tedavisi (protokol_ailesi NULL, planlı tohumlama adımlı), 2=OVSYNC
INSERT INTO tedavi_sablonu(id, ad, protokol_ailesi) VALUES (pg_temp.omu_id('3',1), 'E2E-OMU-MASTIT', NULL), (pg_temp.omu_id('3',2), 'E2E-OMU-OVSYNC', 'OVSYNC');
INSERT INTO sablon_hastalik_eslem(id, sablon_id, disease_id) VALUES (pg_temp.omu_id('5',1), pg_temp.omu_id('3',2), pg_temp.omu_id('1',2));
INSERT INTO hayvanlar(id, kupe_no, cinsiyet, durum, grup, padok, dogum_tarihi)
  SELECT 'E2E-OMU-H-' || i, 'E2E-OMU-' || i, 'Dişi', 'Aktif', 'Sağmal (Laktasyonda)', 'Sağmal Padok', pg_temp.bg() - 800 FROM generate_series(1, 8) i;
-- Vakalar (hepsi active): i → (hastalık, protocol_family)
INSERT INTO cases(id, animal_id, disease_id, start_date, status, protocol_family)
  SELECT pg_temp.omu_id('c', i), 'E2E-OMU-H-' || i, pg_temp.omu_id('1', d), pg_temp.bg() - 5, 'active', pf
    FROM (VALUES (1, 1, NULL), (2, 1, NULL), (3, 1, NULL), (4, 1, NULL), (5, 1, NULL), (6, 1, 'OVSYNC'), (7, 2, NULL), (8, 1, NULL)) v(i, d, pf);
-- TEDAVI_SABLON_TOHUMLAMA logları: vaka i → (şablon eki, iptal)
INSERT INTO gorev_log(id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, kaynak, iptal, tamamlandi)
  SELECT pg_temp.omu_id('e', i), 'E2E-OMU-H-' || i, 'TOHUMLAMA_PLANLI', 'E2E-OMU planlı tohumlama', pg_temp.bg() + 10,
         'TEDAVI_SABLON_TOHUMLAMA:' || pg_temp.omu_id('c', i)::text || ':' || ek, ip, ip
    FROM (VALUES (1, pg_temp.omu_id('3',1)::text, true),   -- mastit şablonu, iptal (prod 232e7f7d deseni)
                 (2, pg_temp.omu_id('3',1)::text, false),  -- mastit şablonu, açık
                 (3, pg_temp.omu_id('3',2)::text, false),  -- OVSYNC şablonu, açık
                 (4, pg_temp.omu_id('3',2)::text, true),   -- OVSYNC şablonu, iptal
                 (5, 'MANUEL', false),                     -- elle eklenen tohumlama
                 (8, pg_temp.omu_id('3',2)::text, NULL)    -- iptal NULL (kolon nullable) → açık sayılmaz
         ) v(i, ek, ip);
CREATE TEMP TABLE _omu_durum(senaryo text PRIMARY KEY, sonuc text, kanit text);

-- ── Sınıflama matrisi: (vaka, beklenen) — (i) yanlış pozitifler, (ii) OVSYNC logu, (iii) değişmeyen kollar
DO $do$ DECLARE r record; v_g boolean; BEGIN
  FOR r IN SELECT * FROM (VALUES
      ('L-MASTIT-IPTAL', 1, false), ('L-MASTIT-ACIK', 2, false), ('L-OVSYNC-ACIK', 3, true),
      ('L-OVSYNC-IPTAL', 4, false), ('L-MANUEL', 5, false), ('K-DAMGA', 6, true), ('K-ESLEM', 7, true),
      ('L-IPTAL-NULL', 8, false)) v(ad, i, bek) LOOP
    BEGIN
      v_g := public._vaka_ovsync_mu(pg_temp.omu_id('c', r.i));
      INSERT INTO _omu_durum VALUES (r.ad, CASE WHEN v_g IS NOT DISTINCT FROM r.bek THEN 'PASS' ELSE 'RED' END,
        format('vaka %s: beklenen=%s gelen=%s', r.i, r.bek, v_g));
    EXCEPTION WHEN OTHERS THEN INSERT INTO _omu_durum VALUES (r.ad, 'RED', SQLERRM); END;
  END LOOP;
END $do$;

-- ── C-RPC (çağıran 1): mastit vakasına hastalık günü açılmaz → ANA_ACIK_OVSYNC_DEGIL, gün yazılmaz
DO $do$ DECLARE v_r jsonb; v_n int; BEGIN
  v_r := public.ovsync_hastalik_gunu_ekle(pg_temp.omu_id('c', 1), pg_temp.omu_id('1', 1), pg_temp.bg(), 7, '[]'::jsonb);
  SELECT count(*) INTO v_n FROM treatment_days WHERE case_id = pg_temp.omu_id('c', 1);
  INSERT INTO _omu_durum VALUES ('C-RPC', CASE WHEN v_r->>'error' = 'ANA_ACIK_OVSYNC_DEGIL' AND v_n = 0 THEN 'PASS' ELSE 'RED' END,
    format('rpc=%s gun=%s', v_r, v_n));
EXCEPTION WHEN OTHERS THEN INSERT INTO _omu_durum VALUES ('C-RPC', 'RED', SQLERRM); END $do$;

-- ── C-KISIR (çağıran 2): kısır işaretleme mastit vakasını kapatmaz, OVSYNC-damgalı vakayı ERKEN_KAPANIS ile kapatır.
-- İzole ayna tetik taşımaz → prod tanımı (20261013000003 §4) transaction içinde kurulur.
DROP TRIGGER IF EXISTS trg_hayvan_kisir_zincir_bitir ON public.hayvanlar;
CREATE TRIGGER trg_hayvan_kisir_zincir_bitir AFTER UPDATE OF kisir ON public.hayvanlar
  FOR EACH ROW WHEN (NEW.kisir IS TRUE AND OLD.kisir IS DISTINCT FROM TRUE) EXECUTE FUNCTION public._kisir_zincir_bitir();
DO $do$ DECLARE v_m text; v_o text; BEGIN
  UPDATE hayvanlar SET kisir = true WHERE id IN ('E2E-OMU-H-1', 'E2E-OMU-H-6');
  SELECT status || '/' || COALESCE(close_reason, '-') INTO v_m FROM cases WHERE id = pg_temp.omu_id('c', 1);
  SELECT status || '/' || COALESCE(close_reason, '-') INTO v_o FROM cases WHERE id = pg_temp.omu_id('c', 6);
  INSERT INTO _omu_durum VALUES ('C-KISIR', CASE WHEN v_m = 'active/-' AND v_o = 'closed/ERKEN_KAPANIS' THEN 'PASS' ELSE 'RED' END,
    format('mastit=%s ovsync=%s', v_m, v_o));
EXCEPTION WHEN OTHERS THEN INSERT INTO _omu_durum VALUES ('C-KISIR', 'RED', SQLERRM); END $do$;

-- ── G-YETKI: imza/güvenlik aynen (DEFINER, STABLE, search_path; anon/authenticated EXECUTE yok)
DO $do$ DECLARE v_p record; BEGIN
  SELECT p.prosecdef, p.provolatile, p.proconfig, has_function_privilege('anon', p.oid, 'EXECUTE') AS an,
         has_function_privilege('authenticated', p.oid, 'EXECUTE') AS au, has_function_privilege('service_role', p.oid, 'EXECUTE') AS sr
    INTO v_p FROM pg_proc p WHERE p.oid = 'public._vaka_ovsync_mu(uuid)'::regprocedure;
  INSERT INTO _omu_durum VALUES ('G-YETKI', CASE WHEN v_p.prosecdef AND v_p.provolatile = 's' AND NOT v_p.an AND NOT v_p.au AND v_p.sr
    AND array_to_string(v_p.proconfig, ',') LIKE '%search_path=public, pg_temp%' THEN 'PASS' ELSE 'RED' END, format('%s', v_p));
EXCEPTION WHEN OTHERS THEN INSERT INTO _omu_durum VALUES ('G-YETKI', 'RED', SQLERRM); END $do$;

-- ── Özet + hüküm (ROLLBACK = temizlik). Beklenen senaryo sayısı: 11.
SELECT senaryo, sonuc, kanit FROM _omu_durum ORDER BY senaryo;
SELECT count(*) FILTER (WHERE sonuc <> 'PASS') AS omu_red, count(*) AS omu_toplam FROM _omu_durum \gset
ROLLBACK;
SELECT set_config('omu.red', :'omu_red', false), set_config('omu.toplam', :'omu_toplam', false) \g /dev/null
DO $do$ BEGIN
  IF current_setting('omu.toplam')::int <> 11 OR current_setting('omu.red')::int > 0 THEN
    RAISE EXCEPTION 'OVSYNC-MU TEST RED: % / % senaryo kirmizi', current_setting('omu.red'), current_setting('omu.toplam');
  END IF;
  RAISE NOTICE 'OVSYNC-MU TEST PASS';
END $do$;
