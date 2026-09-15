-- P3 canlı fonksiyon sondajı (BEGIN READ ONLY sarmında)
SELECT n.nspname AS schema, p.proname AS name,
       pg_get_function_identity_arguments(p.oid) AS args,
       pg_get_function_result(p.oid) AS ret,
       p.pronargs AS nargs,
       p.prosecdef AS secdef, p.provolatile AS vol, p.proowner::regrole::text AS owner,
       pg_get_functiondef(p.oid) AS fdef
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = ANY(ARRAY['tohumlama_kaydet','tohumlama_tekrar_kaydet'])
ORDER BY p.proname, 3;
