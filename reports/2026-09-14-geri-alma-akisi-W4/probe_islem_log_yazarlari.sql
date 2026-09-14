-- islem_log'a yazan TÜM fonksiyonlar: SECURITY DEFINER mı? (review Minor-4 taraması — SALT OKUNUR)
\set ON_ERROR_STOP 1
BEGIN READ ONLY;
SELECT p.oid::regprocedure::text AS fonksiyon,
       p.prosecdef AS definer,
       p.proowner::regrole::text AS sahip
  FROM pg_proc p
 WHERE p.pronamespace = 'public'::regnamespace
   AND (p.prosrc ILIKE '%insert into%islem_log%'
        OR p.prosrc ILIKE '%insert into public%islem_log%')
 ORDER BY p.prosecdef, 1;
ROLLBACK;
