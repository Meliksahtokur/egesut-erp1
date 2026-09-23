-- public + surum_gizli şemalarının sayım + nesne-düzeyi parmak izi (canlı ve yerelde AYNI sorgu).
-- surum_gizli nesneleri 'surum_gizli.' önekiyle görünür (public ile ad çakışmasını önler;
-- public nesnelerinin görünen adı DEĞİŞMEDİ — geriye dönük uyumlu).
-- Çıktı: tek satır JSON {counts:{...}, objects:[[kind,name,md5],...]}
set search_path to pg_catalog;
with
schemas(nspname) as (values ('public'), ('surum_gizli')),
nsprel as (
  select n.oid nsp_oid, n.nspname
  from pg_namespace n join schemas s on s.nspname = n.nspname
),
pubrel as (
  select c.*, n.nspname,
    (case when n.nspname = 'public' then c.relname::text else n.nspname || '.' || c.relname end) as qn
  from pg_class c join nsprel n on n.nsp_oid = c.relnamespace
),
fnrel as (
  select p.*, n.nspname,
    (case when n.nspname = 'public' then p.proname::text else n.nspname || '.' || p.proname end) as qn
  from pg_proc p join nsprel n on n.nsp_oid = p.pronamespace
),
obj(kind, name, fp) as (
  select 'table'::text, c.qn,
         md5(coalesce((select string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod) || ':' || a.attnotnull
                                          || ':' || coalesce(pg_get_expr(ad.adbin, ad.adrelid), ''), ',' order by a.attnum)
                       from pg_attribute a left join pg_attrdef ad on ad.adrelid = a.attrelid and ad.adnum = a.attnum
                       where a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped), '')
             || ':rls=' || c.relrowsecurity || c.relforcerowsecurity)
  from pubrel c where c.relkind = 'r'
  union all
  select 'view', c.qn, md5(pg_get_viewdef(c.oid)) from pubrel c where c.relkind = 'v'
  union all
  select 'sequence', c.qn, '' from pubrel c where c.relkind = 'S'
  union all
  select 'function', p.qn || '(' || pg_get_function_identity_arguments(p.oid) || ')',
         md5(pg_get_functiondef(p.oid))
  from fnrel p where p.prokind in ('f', 'p', 'w')
  union all
  select 'trigger', c.qn || '.' || t.tgname, md5(pg_get_triggerdef(t.oid, false) || t.tgenabled::text)
  from pg_trigger t join pubrel c on c.oid = t.tgrelid where not t.tgisinternal
  union all
  select 'constraint', c.qn || '.' || co.conname, md5(co.contype::text || pg_get_constraintdef(co.oid))
  from pg_constraint co join pubrel c on c.oid = co.conrelid where co.contype in ('p', 'u', 'c', 'f', 'x')
  union all
  select 'index', ic.qn, md5(pg_get_indexdef(i.indexrelid))
  from pg_index i join pubrel ic on ic.oid = i.indexrelid
  union all
  select 'policy', c.qn || '.' || p.polname,
         md5(p.polcmd::text || p.polpermissive::text || coalesce(pg_get_expr(p.polqual, p.polrelid), '') || '|'
             || coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '')
             || (select string_agg(case when r = 0 then 'PUBLIC' else pg_get_userbyid(r) end, ',' order by 1) from unnest(p.polroles) r))
  from pg_policy p join pubrel c on c.oid = p.polrelid
  union all
  select 'fn_acl', p.qn || '(' || pg_get_function_identity_arguments(p.oid) || ')',
         md5(coalesce((select string_agg(case when x.grantee = 0 then 'PUBLIC' else pg_get_userbyid(x.grantee) end, ',' order by 1)
                       from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) x
                       where x.privilege_type = 'EXECUTE'
                         and (x.grantee = 0 or pg_get_userbyid(x.grantee) in ('anon', 'authenticated', 'service_role'))), ''))
  from fnrel p
)
select json_build_object(
  'counts', (select json_object_agg(kind, n) from (select kind, count(*) n from obj group by kind) s),
  'objects', (select json_agg(json_build_array(kind, name, fp) order by kind, name) from obj)
) as fp;
