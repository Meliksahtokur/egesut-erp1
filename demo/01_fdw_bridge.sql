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

-- Tüm egesut tabloları + view'ları; 3 AI-infra (vector) hariç (demo'da tip yok).
-- degisim_log ve 4 stat_* tablosu da hariç (2026-10-31): prod_fdw'de görünen tablo demo_klonla() setine girer.
-- degisim_log, stat_analiz_sonuc, stat_motor_kosum, stat_olcum_kayit: id GENERATED ALWAYS, klonun id'li INSERT'i düşer.
-- stat_kayitli_grafik: id uuid default, klon düşmez; demodaki kayıtlı grafikler prod satırlarıyla ezilmesin diye hariç.
-- Listeyi daraltmadan önce ROLLBACK'li klon provası yapın.
-- Yenileme: DROP SCHEMA prod_fdw CASCADE; CREATE SCHEMA prod_fdw; + aşağıdaki IMPORT.
IMPORT FOREIGN SCHEMA public
  EXCEPT (code_embeddings, entity_graph, memory_notes,
          degisim_log, stat_analiz_sonuc, stat_kayitli_grafik, stat_motor_kosum, stat_olcum_kayit)
  FROM SERVER prod_srv INTO prod_fdw;

-- Read testi: SELECT count(*) FROM prod_fdw.hayvanlar;
