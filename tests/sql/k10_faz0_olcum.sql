-- tests/sql/k10_faz0_olcum.sql — Faz 0 ölçüm kilitleri (PLAN-K10.md Faz 0 :52-118) + KILIT-F0-olcumsuz-secim-yok.
-- HEDEF: YALNIZ yerel izole DB.
-- KOŞUM: psql "$ISO" -X -v ON_ERROR_STOP=1 -f tests/sql/k10_faz0_olcum.sql → rc=0 PASS; rc!=0 RED.
-- Zemin: kur.sh + 000002..000005 sırayla (rc=0) → hepsi PASS. kur.sh-only zeminde
--   S-F0-sema/S-F0-imza PASS (ölçüm çıktısıdır — plan Step 2: RED geçme notu değil),
--   S-F0-zincir + KILIT RED (ölçümsüz seçimle DB-1 yazılmamış zemin).
-- Kapsam-plan ilişkisi: S-F0-sema ↔ Step 1 (yerel şema); S-F0-imza ↔ Step 1 Produces
--   (ertele/add_drug imzaları — yerel ölçülebilir kısım); KILIT-F0-olcumsuz-secim-yok ↔ Step 5
--   (yürütme kilidi: Faz 0 kararı uygulanmamış zeminde RED); S-F0-zincir ↔ Step 6
--   (commit önkoşulu: 000002..000005 sıralı zincir izleri).
-- Step 3 (canlı SELECT: demo+prod ayrı) + Step 4 (Dal A tek-RPC kararı) izolede koşmaz;
--   karar 000003'tedir (tek RPC + kısmi unique), canlı ölçüm notu rapordadır.
-- Yalnız katalog okuma; tek transaction + ROLLBACK.
\echo '=== K10 FAZ-0 OLCUM — izole DB testi ==='
BEGIN;
CREATE TEMP TABLE _k10_durum(senaryo text PRIMARY KEY, sonuc text, kanit text);

-- ── S-F0-sema (Step 1): taban şekli + cases.disease_id FK + day_no tetiği; plain UNIQUE yok
DO $do$ DECLARE
  v_kolon int; v_fk int; v_trg int; v_govde text; v_plain int;
BEGIN
  SELECT count(*) INTO v_kolon FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'treatment_days'
     AND ((column_name = 'id' AND is_nullable = 'NO')
       OR (column_name = 'case_id' AND is_nullable = 'NO')
       OR column_name = 'day_no'
       OR (column_name = 'treatment_date' AND is_nullable = 'NO')
       OR column_name = 'notes');
  SELECT count(*) INTO v_fk FROM pg_constraint
   WHERE conrelid = 'public.cases'::regclass AND confrelid = 'public.diseases'::regclass;
  SELECT count(*) INTO v_trg FROM pg_trigger
   WHERE tgrelid = 'public.treatment_days'::regclass AND tgname = 'trg_set_day_no' AND NOT tgisinternal;
  SELECT pg_get_functiondef(p.oid) INTO v_govde FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'set_treatment_day_no';
  SELECT count(*) INTO v_plain FROM pg_index i JOIN pg_class c ON c.oid = i.indrelid
   JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relname = 'treatment_days'
     AND i.indisunique AND NOT i.indisprimary AND i.indpred IS NULL;
  INSERT INTO _k10_durum VALUES ('S-F0-sema',
    CASE WHEN v_kolon = 5 AND v_fk >= 1 AND v_trg = 1 AND v_govde ILIKE '%MAX(day_no)%' AND v_plain = 0
      THEN 'PASS' ELSE 'RED' END,
    format('kolon5=%s fk=%s trg=%s max+1=%s plain-unique=%s', v_kolon, v_fk, v_trg,
      (v_govde ILIKE '%MAX(day_no)%'), v_plain));
EXCEPTION WHEN OTHERS THEN INSERT INTO _k10_durum VALUES ('S-F0-sema', 'RED', SQLERRM); END $do$;

-- ── S-F0-imza (Step 1 Produces): ertele + add_drug tek imza
DO $do$ DECLARE
  v_ertele int; v_ilac int;
BEGIN
  SELECT count(*) INTO v_ertele FROM pg_proc WHERE proname = 'tohumlama_gorev_ertele';
  SELECT count(*) INTO v_ilac FROM pg_proc WHERE proname = 'add_drug_administration';
  INSERT INTO _k10_durum VALUES ('S-F0-imza',
    CASE WHEN v_ertele = 1 AND v_ilac = 1 THEN 'PASS' ELSE 'RED' END,
    format('ertele=%s ilac=%s (beklenen 1/1)', v_ertele, v_ilac));
EXCEPTION WHEN OTHERS THEN INSERT INTO _k10_durum VALUES ('S-F0-imza', 'RED', SQLERRM); END $do$;

-- ── S-F0-zincir (Step 6): 000002 CHECK 5 değer (sıralı zincir önkoşulu)
DO $do$ DECLARE
  v_chk text;
BEGIN
  SELECT string_agg(check_clause, ' ') INTO v_chk FROM information_schema.check_constraints
   WHERE constraint_name = 'pg_application_event_source_type_check';
  INSERT INTO _k10_durum VALUES ('S-F0-zincir',
    CASE WHEN v_chk LIKE '%HIZLI_UYGULAMA%' AND v_chk LIKE '%TEDAVI_SEANS%' AND v_chk LIKE '%TOPLU_ILAC%'
      AND v_chk LIKE '%TEDAVI_GUN%' AND v_chk LIKE '%ILAC_EKLE%' THEN 'PASS' ELSE 'RED' END,
    format('check=%s', left(COALESCE(v_chk, 'YOK'), 140)));
EXCEPTION WHEN OTHERS THEN INSERT INTO _k10_durum VALUES ('S-F0-zincir', 'RED', SQLERRM); END $do$;

-- ── KILIT-F0-olcumsuz-secim-yok (Step 5): Faz 0 kararı uygulanmış mı?
-- disease_id kolonu + kısmi unique + tek RPC + anon kapalı. Ölçümsüz/eksik DB-1'de RED.
DO $do$ DECLARE
  v_kolon int; v_idx text; v_rpc int; v_anon int;
BEGIN
  SELECT count(*) INTO v_kolon FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'treatment_days' AND column_name = 'disease_id';
  SELECT indexdef INTO v_idx FROM pg_indexes
   WHERE schemaname = 'public' AND indexname = 'treatment_days_hastalik_gun_uniq';
  SELECT count(*) INTO v_rpc FROM pg_proc WHERE proname = 'ovsync_hastalik_gunu_ekle';
  SELECT count(*) INTO v_anon FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public' AND p.proname = 'ovsync_hastalik_gunu_ekle'
     AND has_function_privilege('anon', p.oid, 'EXECUTE');
  INSERT INTO _k10_durum VALUES ('KILIT-F0-olcumsuz-secim-yok',
    CASE WHEN v_kolon = 1 AND v_idx ILIKE '%disease_id IS NOT NULL%' AND v_rpc = 1 AND v_anon = 0
      THEN 'PASS' ELSE 'RED' END,
    format('kolon=%s uniq=%s rpc=%s anon=%s', v_kolon, (v_idx IS NOT NULL), v_rpc, v_anon));
EXCEPTION WHEN OTHERS THEN INSERT INTO _k10_durum VALUES ('KILIT-F0-olcumsuz-secim-yok', 'RED', SQLERRM); END $do$;

SELECT senaryo, sonuc, kanit FROM _k10_durum ORDER BY senaryo;
SELECT count(*) FILTER (WHERE sonuc <> 'PASS') AS k10_red, count(*) AS k10_toplam FROM _k10_durum \gset
ROLLBACK;
SELECT set_config('k10.red', :'k10_red', false), set_config('k10.toplam', :'k10_toplam', false) \g /dev/null
DO $do$ BEGIN
  IF current_setting('k10.toplam')::int <> 4 OR current_setting('k10.red')::int > 0 THEN
    RAISE EXCEPTION 'K10-FAZ0 TEST RED: % / % senaryo kirmizi', current_setting('k10.red'), current_setting('k10.toplam');
  END IF;
  RAISE NOTICE 'K10-FAZ0 TEST PASS';
END $do$;
