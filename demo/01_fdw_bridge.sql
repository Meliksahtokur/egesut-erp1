-- D1: FDW köprüsü — DEMO projesinde çalıştırılır (prod_fdw = canlı prod aynası)
-- ⚠️ SADECE DEMO'da (ref vtzqjmazsvurxdeondmi). Prod'a UYGULAMA — prod_fdw yok, patlar.
-- ⚠️ :demo_reader_password → .env SUPABASE_DEMO içinde / scratchpad demo_reader_pw.txt.
--    demo_reader = prod'da LOGIN + SELECT-only + BYPASSRLS rolü (Management API ile açıldı).
-- Not: demo Management API'ye Python urllib → Cloudflare 1010; curl kullan.

CREATE EXTENSION IF NOT EXISTS postgres_fdw;

DROP SERVER IF EXISTS prod_srv CASCADE;
CREATE SERVER prod_srv FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (
    host 'aws-1-eu-west-1.pooler.supabase.com',  -- prod pooler
    port '5432',                                  -- session mode (6543 transaction FDW'ye uymaz)
    dbname 'postgres',
    sslmode 'require'
  );

-- postgres için: D2 demo_klonla() SECURITY DEFINER + pg_cron postgres olarak koşar
CREATE USER MAPPING FOR postgres SERVER prod_srv
  OPTIONS (user 'demo_reader.zqnexqbdfvbhlxzelzju', password :'demo_reader_password');

CREATE SCHEMA IF NOT EXISTS prod_fdw;

-- Tüm egesut tabloları + view'ları; 3 AI-infra (vector) hariç (demo'da tip yok)
IMPORT FOREIGN SCHEMA public
  EXCEPT (code_embeddings, entity_graph, memory_notes)
  FROM SERVER prod_srv INTO prod_fdw;

-- Read testi: SELECT count(*) FROM prod_fdw.hayvanlar;
