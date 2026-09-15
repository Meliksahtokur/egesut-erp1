-- L4-W4 onarım öncesi canlı DEMO şema yoklaması — SALT OKUNUR (BEGIN READ ONLY)
-- Amaç: L4-02 policy/ACL gerçekleri + k4 sahne kurulumu için tablo/FK envanteri.
\set ON_ERROR_STOP 1
BEGIN READ ONLY;

\echo '== 1. islem_log policy + grant + RLS =='
SELECT policyname, cmd, roles, qual, with_check FROM pg_policies
 WHERE schemaname='public' AND tablename='islem_log';
SELECT grantee, privilege_type FROM information_schema.role_table_grants
 WHERE table_schema='public' AND table_name='islem_log' ORDER BY grantee, privilege_type;
SELECT relrowsecurity, relforcerowsecurity FROM pg_class
 WHERE oid = 'public.islem_log'::regclass;

\echo '== 2. islem_log kolonlar (tarih var? created_at yok? degisim_txid?) =='
SELECT column_name, data_type FROM information_schema.columns
 WHERE table_schema='public' AND table_name='islem_log' ORDER BY ordinal_position;

\echo '== 3. islem_log triggerlar =='
SELECT tgname, pg_get_triggerdef(t.oid) FROM pg_trigger t
 WHERE tgrelid = 'public.islem_log'::regclass AND NOT tgisinternal ORDER BY tgname;

\echo '== 4. roller: superuser / bypassrls =='
SELECT rolname, rolsuper, rolbypassrls FROM pg_roles
 WHERE rolname IN ('postgres','authenticated','anon','service_role','authenticator')
 ORDER BY rolname;

\echo '== 5. degisim_log kolonlar =='
SELECT column_name, data_type FROM information_schema.columns
 WHERE table_schema='public' AND table_name='degisim_log' ORDER BY ordinal_position;

\echo '== 6. kapsam tabloları (surum_gizli._kapsamda gövdesinden) =='
SELECT prosrc FROM pg_proc WHERE oid = 'surum_gizli._kapsamda(text)'::regprocedure;

\echo '== 7. dogum -> tohumlama FK var mı? hayvan FK envanteri =='
SELECT conrelid::regclass AS child, confrelid::regclass AS parent,
       (SELECT string_agg(a.attname, ',' ORDER BY x.ord)
          FROM unnest(con.conkey) WITH ORDINALITY AS x(attnum, ord)
          JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = x.attnum) AS ccols
  FROM pg_constraint con
 WHERE con.contype='f'
   AND (con.confrelid IN ('public.tohumlama'::regclass, 'public.hayvanlar'::regclass)
        OR con.conrelid IN ('public.dogum'::regclass, 'public.tohumlama'::regclass));

\echo '== 8. test sahnesi tablolarının zorunlu kolonları =='
SELECT table_name, column_name, is_nullable, data_type, column_default
  FROM information_schema.columns
 WHERE table_schema='public' AND table_name IN ('hayvanlar','tohumlama','dogum','asilar')
 ORDER BY table_name, ordinal_position;

\echo '== 9. tohumlama triggerlar (gebe görev tetikleyicisi) =='
SELECT tgname FROM pg_trigger WHERE tgrelid='public.tohumlama'::regclass AND NOT tgisinternal ORDER BY tgname;

\echo '== 10. islem_log tip örnekleri (orijinal_tip çözümü için) =='
SELECT DISTINCT tip FROM public.islem_log ORDER BY tip LIMIT 40;

\echo '== 11. L4 fonksiyonları yerinde mi =='
SELECT oid::regprocedure FROM pg_proc
 WHERE proname IN ('_l4_zincir','_l4_zaman_txid','_degisim_plan','_pk_json','_pk_gorunum','_guncel_satir','_degisim_uygula','_ekle_bagli')
   AND pronamespace='surum_gizli'::regnamespace ORDER BY 1::text;

\echo '== 12. dogum örneği satır (kolon gerçekleri) =='
SELECT to_jsonb(d) FROM public.dogum d LIMIT 1;

ROLLBACK;
