-- ════════════════════════════════════════════════════════════
-- Faz 1 Auth Gate — anon rolünü kilitle, authenticated'a tam eriş
-- Login olmayan kullanıcı (anon) hiçbir tablo/RPC/sequence'a erişemez.
-- Veri izolasyonu YOK (Faz 2) — authenticated paylaşımlı veriyi görür.
-- ════════════════════════════════════════════════════════════

-- 1) anon'dan TÜM yetkileri al
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon;

-- 2) authenticated'a tam eriş ver (paylaşımlı veri — Faz 1)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- 3) Gelecekte eklenen objeler de aynı kurala uysun
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES    FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon;
