-- Supabase'e özgü bağımlılıkların yerel stub'ları (yalnız egesut_ovsync_kabul DB'sine uygulanır;
-- roller küme-geneli olduğundan yalnız YOKSA yaratılır, var olanlara dokunulmaz).
\set ON_ERROR_STOP 1

DO $$
DECLARE r text;
BEGIN
  FOREACH r IN ARRAY ARRAY['anon', 'authenticated', 'service_role'] LOOP
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
      EXECUTE format('CREATE ROLE %I NOLOGIN', r);
      RAISE NOTICE 'rol yaratildi: %', r;
    END IF;
  END LOOP;
END $$;

CREATE SCHEMA IF NOT EXISTS extensions;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS kabul_meta;

-- Canlıda extensions şemasında olan ve public nesnelerinin kullandığı / kullanabileceği eklentiler.
-- Yerelde mevcut olmayan (pg_cron, pg_net, postgis, pgroonga, ...) atlanır ve listelenir.
CREATE TABLE kabul_meta.atlanan (nesne text PRIMARY KEY, neden text);
DO $$
DECLARE e text;
BEGIN
  FOREACH e IN ARRAY ARRAY['pgcrypto', 'uuid-ossp', 'vector', 'pg_trgm', 'unaccent', 'citext', 'btree_gist', 'btree_gin', 'moddatetime'] LOOP
    IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = e) THEN
      EXECUTE format('CREATE EXTENSION IF NOT EXISTS %I WITH SCHEMA extensions', e);
    ELSE
      INSERT INTO kabul_meta.atlanan VALUES ('extension ' || e, 'yerelde paket yok');
    END IF;
  END LOOP;
END $$;

-- auth.* — Supabase GoTrue yardımcılarının birebir davranışı (JWT claim GUC'larından okur).
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''),
                  (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'))::uuid
$$;
CREATE OR REPLACE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$
  SELECT coalesce(nullif(current_setting('request.jwt.claim.role', true), ''),
                  (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role'))::text
$$;
CREATE OR REPLACE FUNCTION auth.email() RETURNS text LANGUAGE sql STABLE AS $$
  SELECT coalesce(nullif(current_setting('request.jwt.claim.email', true), ''),
                  (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email'))::text
$$;
CREATE OR REPLACE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$
  SELECT coalesce(nullif(current_setting('request.jwt.claim', true), ''),
                  nullif(current_setting('request.jwt.claims', true), ''))::jsonb
$$;

-- cron.* — pg_cron yerelde yok: yalnız kayıt tutan stub (işler ÇALIŞMAZ).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_available_extensions WHERE name = 'pg_cron') THEN
    INSERT INTO kabul_meta.atlanan VALUES ('cron stub', 'pg_cron paketi var ama shared_preload gerektirir; yine stub kullanildi');
  END IF;
END $$;
CREATE SCHEMA IF NOT EXISTS cron;
CREATE TABLE cron.job (
  jobid bigserial PRIMARY KEY,
  schedule text NOT NULL,
  command text NOT NULL,
  nodename text NOT NULL DEFAULT 'localhost',
  nodeport integer NOT NULL DEFAULT 5432,
  database text NOT NULL DEFAULT current_database(),
  username text NOT NULL DEFAULT current_user,
  active boolean NOT NULL DEFAULT true,
  jobname text UNIQUE
);
CREATE OR REPLACE FUNCTION cron.schedule(job_name text, schedule text, command text) RETURNS bigint
LANGUAGE sql AS $$
  INSERT INTO cron.job (jobname, schedule, command) VALUES (job_name, schedule, command)
  ON CONFLICT (jobname) DO UPDATE SET schedule = excluded.schedule, command = excluded.command
  RETURNING jobid
$$;
CREATE OR REPLACE FUNCTION cron.schedule(schedule text, command text) RETURNS bigint
LANGUAGE sql AS $$ INSERT INTO cron.job (schedule, command) VALUES (schedule, command) RETURNING jobid $$;
CREATE OR REPLACE FUNCTION cron.unschedule(job_id bigint) RETURNS boolean
LANGUAGE sql AS $$ WITH d AS (DELETE FROM cron.job WHERE jobid = job_id RETURNING 1) SELECT count(*) > 0 FROM d $$;
CREATE OR REPLACE FUNCTION cron.unschedule(job_name text) RETURNS boolean
LANGUAGE sql AS $$ WITH d AS (DELETE FROM cron.job WHERE jobname = job_name RETURNING 1) SELECT count(*) > 0 FROM d $$;

GRANT USAGE ON SCHEMA extensions, auth TO anon, authenticated, service_role;
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA auth TO anon, authenticated, service_role;

-- Canlıda Supabase dışı nesneler (kayıt amaçlı; kurulmaz)
INSERT INTO kabul_meta.atlanan VALUES
  ('publication supabase_realtime', 'Supabase realtime; kabul testi icin gereksiz'),
  ('pg_net / http / vault / pgsodium / pgmq', 'public nesneleri kullanmiyor (canli pg_depend + govde taramasi)'),
  ('postgis / tiger / topology / pgroonga / pgrouting', 'public nesneleri kullanmiyor; yerelde paket yok'),
  ('cron isleri', 'cron.job satirlari kaydedilir ama zamanlanmis calisma YOK');

-- DDL yükleme tablosu
CREATE TABLE kabul_meta.ddl (
  id serial PRIMARY KEY,
  phase int NOT NULL,
  ord text NOT NULL,
  kind text NOT NULL,
  name text NOT NULL,
  sql text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  pass int,
  err text
);
