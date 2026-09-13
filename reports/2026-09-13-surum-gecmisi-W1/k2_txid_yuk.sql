-- Acceptance 2 (G-20260913-SURUM-GECMISI):
--   (a) 100 rows written in one transaction land under ONE txid;
--   (b) trigger overhead: bulk INSERT/UPDATE/DELETE timed with trg_degisim_log
--       enabled vs disabled (same session, same data, alternating, 3 reps).
-- Everything is ROLLED BACK. Table: stok_hareket (no business triggers, so
-- the delta is the log trigger alone).
--
-- Run: dpsql -f reports/2026-09-13-surum-gecmisi-W1/k2_txid_yuk.sql
\set ON_ERROR_STOP 1
BEGIN;

\echo '== (a) 100-row INSERT + 100-row UPDATE in one tx =='
INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar)
SELECT (SELECT id FROM public.stok ORDER BY id LIMIT 1), 'k2', 1, 'k2-' || g
  FROM generate_series(1, 100) g;
UPDATE public.stok_hareket SET miktar = miktar + 1 WHERE notlar LIKE 'k2-%';
SELECT islem, count(*) AS satir, count(DISTINCT txid) AS txid_sayisi,
       bool_and(txid = txid_current()) AS hepsi_bu_tx
  FROM public.degisim_log
 WHERE txid = txid_current() AND tablo_adi = 'stok_hareket'
 GROUP BY islem ORDER BY islem;
DELETE FROM public.stok_hareket WHERE notlar LIKE 'k2-%';

\echo '== (b) trigger overhead, N rows per op =='
CREATE TEMP TABLE k2 (rep int, trigger_acik boolean, op text, n int, ms numeric);

DO $k2$
DECLARE
  n     constant int := 2000;
  v_st  text;
  t0    timestamptz;
  rep   int;
  acik  boolean;
BEGIN
  SELECT id INTO v_st FROM public.stok ORDER BY id LIMIT 1;
  FOR rep IN 1 .. 3 LOOP
    FOREACH acik IN ARRAY ARRAY[true, false] LOOP
      IF acik THEN
        ALTER TABLE public.stok_hareket ENABLE TRIGGER trg_degisim_log;
      ELSE
        ALTER TABLE public.stok_hareket DISABLE TRIGGER trg_degisim_log;
      END IF;

      t0 := clock_timestamp();
      INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar)
      SELECT v_st, 'k2yuk', 1, 'k2yuk-' || g FROM generate_series(1, n) g;
      INSERT INTO k2 VALUES (rep, acik, 'INSERT', n, extract(epoch FROM clock_timestamp() - t0) * 1000);

      t0 := clock_timestamp();
      UPDATE public.stok_hareket SET miktar = miktar + 1 WHERE tur = 'k2yuk';
      INSERT INTO k2 VALUES (rep, acik, 'UPDATE', n, extract(epoch FROM clock_timestamp() - t0) * 1000);

      t0 := clock_timestamp();
      DELETE FROM public.stok_hareket WHERE tur = 'k2yuk';
      INSERT INTO k2 VALUES (rep, acik, 'DELETE', n, extract(epoch FROM clock_timestamp() - t0) * 1000);
    END LOOP;
  END LOOP;
  ALTER TABLE public.stok_hareket ENABLE TRIGGER trg_degisim_log;
END;
$k2$;

SELECT rep, trigger_acik, op, n, round(ms, 1) AS ms FROM k2 ORDER BY op, rep, trigger_acik DESC;

\echo '== median per op (ms) and per-row overhead (us) =='
SELECT op,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY ms) FILTER (WHERE trigger_acik)::numeric, 1)     AS acik_ms,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY ms) FILTER (WHERE NOT trigger_acik)::numeric, 1) AS kapali_ms,
       round((percentile_cont(0.5) WITHIN GROUP (ORDER BY ms) FILTER (WHERE trigger_acik)
            / nullif(percentile_cont(0.5) WITHIN GROUP (ORDER BY ms) FILTER (WHERE NOT trigger_acik), 0))::numeric, 2) AS oran,
       round(((percentile_cont(0.5) WITHIN GROUP (ORDER BY ms) FILTER (WHERE trigger_acik)
             - percentile_cont(0.5) WITHIN GROUP (ORDER BY ms) FILTER (WHERE NOT trigger_acik)) * 1000 / max(n))::numeric, 1) AS ek_us_satir
  FROM k2 GROUP BY op ORDER BY op;

\echo '== trigger state restored =='
SELECT tgname, tgenabled FROM pg_trigger WHERE tgrelid = 'public.stok_hareket'::regclass AND tgname = 'trg_degisim_log';

ROLLBACK;
