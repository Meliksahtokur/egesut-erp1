-- M3 uygulama doğrulaması — SALT OKUNUR
\set ON_ERROR_STOP 1
BEGIN READ ONLY;
\echo == trigger tanimlari ==
SELECT pg_get_triggerdef(t.oid) FROM pg_trigger t
 WHERE tgrelid = 'public.islem_log'::regclass AND NOT tgisinternal ORDER BY tgname;
\echo == policy ==
SELECT policyname, cmd, roles::text, with_check FROM pg_policies
 WHERE schemaname = 'public' AND tablename = 'islem_log' ORDER BY policyname;
\echo == authenticated grant ==
SELECT grantee, privilege_type FROM information_schema.role_table_grants
 WHERE table_schema = 'public' AND table_name = 'islem_log' AND grantee = 'authenticated';
\echo == jeton tablosu ==
SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'surum_gizli' AND c.relname = 'l4_rehber_adimlari';
\echo == fonksiyonlar ==
SELECT oid::regprocedure::text FROM pg_proc
 WHERE proname IN ('_l4_rehber_uyesi', '_islem_log_geri_alindi_kapisi', '_islem_log_degisim_txid')
 ORDER BY 1;
ROLLBACK;
