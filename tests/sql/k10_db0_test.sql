-- tests/sql/k10_db0_test.sql — DB-0 temizlik kilidi (S-DB0-temiz). HEDEF: YALNIZ yerel izole DB.
-- KOŞUM: psql "$ISO" -X -v ON_ERROR_STOP=1 -f tests/sql/k10_db0_test.sql → rc=0 PASS; rc!=0 RED.
-- Zemin: kur.sh + 000002..000005 (CHECK-3-değer probu k10-db/db0-prob.sql'de, mutant k10-db/mutant-db0-*.sh'de).
-- Yalnız katalog okuma; tek transaction + ROLLBACK.
\echo '=== K10 DB-0 TEMIZLIK — izole DB testi ==='
BEGIN;
CREATE TEMP TABLE _k10_durum(senaryo text PRIMARY KEY, sonuc text, kanit text);

-- ── S-DB0-temiz: eski alt-vaka makinesi kalkmış olmalı (CHECK şartı yok — ERT2: db0-prob.sql'de)
DO $do$ DECLARE
  v_ac int; v_kapat int; v_kolon int;
BEGIN
  SELECT count(*) INTO v_ac FROM pg_proc WHERE proname = 'inaktif_alt_vaka_ac';
  SELECT count(*) INTO v_kapat FROM pg_proc WHERE proname = 'inaktif_alt_vaka_kapat';
  SELECT count(*) INTO v_kolon FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'cases' AND column_name = 'kaynak_vaka_id';
  INSERT INTO _k10_durum VALUES ('S-DB0-temiz',
    CASE WHEN v_ac = 0 AND v_kapat = 0 AND v_kolon = 0
      THEN 'PASS' ELSE 'RED' END,
    format('ac=%s kapat=%s kolon=%s', v_ac, v_kapat, v_kolon));
EXCEPTION WHEN OTHERS THEN INSERT INTO _k10_durum VALUES ('S-DB0-temiz', 'RED', SQLERRM); END $do$;

SELECT senaryo, sonuc, kanit FROM _k10_durum ORDER BY senaryo;
SELECT count(*) FILTER (WHERE sonuc <> 'PASS') AS k10_red, count(*) AS k10_toplam FROM _k10_durum \gset
ROLLBACK;
SELECT set_config('k10.red', :'k10_red', false), set_config('k10.toplam', :'k10_toplam', false) \g /dev/null
DO $do$ BEGIN
  IF current_setting('k10.toplam')::int <> 1 OR current_setting('k10.red')::int > 0 THEN
    RAISE EXCEPTION 'K10-DB0 TEST RED: % / % senaryo kirmizi', current_setting('k10.red'), current_setting('k10.toplam');
  END IF;
  RAISE NOTICE 'K10-DB0 TEST PASS';
END $do$;
