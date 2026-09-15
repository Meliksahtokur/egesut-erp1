-- Acceptance 1b: degisim_log UPDATE/DELETE/TRUNCATE are refused.
-- Red-before: with the guard triggers disabled the same statements succeed
-- (proves the guard, not something else, is what refuses). All rolled back.
--
-- Run: dpsql -f reports/2026-09-13-surum-gecmisi-W1/k1b_immutability.sql
\set ON_ERROR_STOP 0
\echo '== seed one log row (hekimler content update, rolled back later) =='
BEGIN;
UPDATE public.hekimler SET telefon = coalesce(telefon, '') || '~k1b'
 WHERE id = (SELECT id FROM public.hekimler ORDER BY id LIMIT 1);
SELECT count(*) AS log_rows_in_tx FROM public.degisim_log WHERE txid = txid_current();

\echo '== RED-BEFORE: guards disabled -> mutations succeed =='
ALTER TABLE public.degisim_log DISABLE TRIGGER trg_degisim_log_immutable;
ALTER TABLE public.degisim_log DISABLE TRIGGER trg_degisim_log_no_truncate;
SAVEPOINT s1;
UPDATE public.degisim_log SET tablo_adi = 'tampered' WHERE txid = txid_current();
ROLLBACK TO SAVEPOINT s1;
SAVEPOINT s2;
DELETE FROM public.degisim_log WHERE txid = txid_current();
ROLLBACK TO SAVEPOINT s2;
ALTER TABLE public.degisim_log ENABLE TRIGGER trg_degisim_log_immutable;
ALTER TABLE public.degisim_log ENABLE TRIGGER trg_degisim_log_no_truncate;

\echo '== GREEN: guards enabled -> UPDATE refused =='
SAVEPOINT s3;
UPDATE public.degisim_log SET tablo_adi = 'tampered' WHERE txid = txid_current();
ROLLBACK TO SAVEPOINT s3;
\echo '== GREEN: DELETE refused =='
SAVEPOINT s4;
DELETE FROM public.degisim_log WHERE txid = txid_current();
ROLLBACK TO SAVEPOINT s4;
\echo '== GREEN: TRUNCATE refused =='
SAVEPOINT s5;
TRUNCATE public.degisim_log;
ROLLBACK TO SAVEPOINT s5;

\echo '== authenticated role: INSERT/UPDATE/DELETE denied, SELECT allowed =='
SET LOCAL ROLE authenticated;
SAVEPOINT s6;
SELECT count(*) >= 0 AS select_ok FROM public.degisim_log;
ROLLBACK TO SAVEPOINT s6;
SAVEPOINT s7;
INSERT INTO public.degisim_log (txid, tablo_adi, satir_pk, islem, kaynak)
VALUES (1, 'sahte', '{}', 'I', '{}');
ROLLBACK TO SAVEPOINT s7;
SAVEPOINT s8;
DELETE FROM public.degisim_log WHERE txid = txid_current();
ROLLBACK TO SAVEPOINT s8;
\echo '== anon role: SELECT denied =='
SET LOCAL ROLE anon;
SAVEPOINT s9;
SELECT count(*) FROM public.degisim_log;
ROLLBACK TO SAVEPOINT s9;
RESET ROLE;
ROLLBACK;
