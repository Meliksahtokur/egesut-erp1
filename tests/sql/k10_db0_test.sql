-- tests/sql/k10_db0_test.sql — DB-0 temizlik kilidi (S-DB0-temiz) + MUT-DB0-sira-yanlis. HEDEF: YALNIZ yerel izole DB.
-- KOŞUM: psql "$ISO" -X -v ON_ERROR_STOP=1 -f tests/sql/k10_db0_test.sql → rc=0 PASS; rc!=0 RED.
-- Beklenen zemin: GERI-ALMA sonrası demo (000002..000005 düşmüş) ≙ izolede kur.sh-only hali:
--   inaktif_alt_vaka_ac/kapat YOK, cases.kaynak_vaka_id YOK,
--   pg_application_event CHECK yalnız 3 ön-000002 değeri (HIZLI_UYGULAMA, TEDAVI_SEANS, TOPLU_ILAC).
-- Yalnız katalog okuma; tek transaction + ROLLBACK.
\echo '=== K10 DB-0 TEMIZLIK — izole DB testi ==='
BEGIN;
CREATE TEMP TABLE _k10_durum(senaryo text PRIMARY KEY, sonuc text, kanit text);

-- ── S-DB0-temiz (kırmızı önce): 000002..000005 uygulanmış izole DB'de RED
DO $do$ DECLARE
  v_ac int; v_kapat int; v_kolon int; v_chk text;
BEGIN
  SELECT count(*) INTO v_ac FROM pg_proc WHERE proname = 'inaktif_alt_vaka_ac';
  SELECT count(*) INTO v_kapat FROM pg_proc WHERE proname = 'inaktif_alt_vaka_kapat';
  SELECT count(*) INTO v_kolon FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'cases' AND column_name = 'kaynak_vaka_id';
  SELECT string_agg(check_clause, ' ') INTO v_chk FROM information_schema.check_constraints
   WHERE constraint_name = 'pg_application_event_source_type_check';
  INSERT INTO _k10_durum VALUES ('S-DB0-temiz',
    CASE WHEN v_ac = 0 AND v_kapat = 0 AND v_kolon = 0
      AND v_chk IS NOT NULL
      AND v_chk LIKE '%HIZLI_UYGULAMA%' AND v_chk LIKE '%TEDAVI_SEANS%' AND v_chk LIKE '%TOPLU_ILAC%'
      AND v_chk NOT LIKE '%TEDAVI_GUN%' AND v_chk NOT LIKE '%ILAC_EKLE%'
      THEN 'PASS' ELSE 'RED' END,
    format('ac=%s kapat=%s kolon=%s; check=%s', v_ac, v_kapat, v_kolon, left(COALESCE(v_chk, 'YOK'), 160)));
EXCEPTION WHEN OTHERS THEN INSERT INTO _k10_durum VALUES ('S-DB0-temiz', 'RED', SQLERRM); END $do$;

-- ── MUT-DB0-sira-yanlis: GERI-ALMA ters sırada koşulmuş gibi artık bırakılınca
--   S-DB0-temiz mantığı RED verir; GERI-ALMA DROP listesi (yedek) ile restore edilince PASS.
--   Restore `git checkout --` ile DEĞİL, yedek DROP listesiyle yapılır.
DO $do$ DECLARE
  v_ac int; v_red_gozlendi boolean := false; v_restore_pass boolean := false;
BEGIN
  CREATE OR REPLACE FUNCTION public.inaktif_alt_vaka_ac(p_case uuid) RETURNS jsonb LANGUAGE plpgsql
    AS $f$ BEGIN RETURN jsonb_build_object('ok', false); END; $f$;
  SELECT count(*) INTO v_ac FROM pg_proc WHERE proname = 'inaktif_alt_vaka_ac';
  IF v_ac > 0 THEN v_red_gozlendi := true; END IF;
  DROP FUNCTION IF EXISTS public.inaktif_alt_vaka_ac(uuid);
  DROP FUNCTION IF EXISTS public.inaktif_alt_vaka_kapat(uuid);
  DROP FUNCTION IF EXISTS public._inaktif_alt_vaka_donus_hazirla(uuid);
  SELECT count(*) INTO v_ac FROM pg_proc WHERE proname = 'inaktif_alt_vaka_ac';
  IF v_ac = 0 THEN v_restore_pass := true; END IF;
  INSERT INTO _k10_durum VALUES ('MUT-DB0-sira-yanlis',
    CASE WHEN v_red_gozlendi AND v_restore_pass THEN 'PASS' ELSE 'RED' END,
    format('artik varken sayim>0=RED-gozlendi:%s; DROP-listesi restore sonrasi sayim=0:%s',
      v_red_gozlendi, v_restore_pass));
EXCEPTION WHEN OTHERS THEN INSERT INTO _k10_durum VALUES ('MUT-DB0-sira-yanlis', 'RED', SQLERRM); END $do$;

SELECT senaryo, sonuc, kanit FROM _k10_durum ORDER BY senaryo;
SELECT count(*) FILTER (WHERE sonuc <> 'PASS') AS k10_red, count(*) AS k10_toplam FROM _k10_durum \gset
ROLLBACK;
SELECT set_config('k10.red', :'k10_red', false), set_config('k10.toplam', :'k10_toplam', false) \g /dev/null
DO $do$ BEGIN
  IF current_setting('k10.toplam')::int <> 2 OR current_setting('k10.red')::int > 0 THEN
    RAISE EXCEPTION 'K10-DB0 TEST RED: % / % senaryo kirmizi', current_setting('k10.red'), current_setting('k10.toplam');
  END IF;
  RAISE NOTICE 'K10-DB0 TEST PASS';
END $do$;
