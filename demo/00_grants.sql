-- D0-sonrası: demo authenticated grant'ları — D0 pg_dump ACL'leri taşımadı → demo kullanıcı
-- hiçbir tabloyu göremiyordu (42501). ⚠️ SADECE DEMO'da. Klon veriye dokunur, grant'lar kalıcı.
-- Demo modeli prod ile aynı: authenticated CRUD + RLS USING(true). anon kilitli kalır (demo login = authenticated).
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
-- gelecekte eklenecek nesneler için default privileges
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO authenticated;
