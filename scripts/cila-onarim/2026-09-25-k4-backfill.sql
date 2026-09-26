-- DEMO'YA ÖZEL tek-seferlik backfill (cila-onarım K4) — MIGRATION DEĞİL, prod'a uygulanmaz.
-- HEDEF REF DOĞRULA (F4/K4): vtzqjmazsvurxdeondmi (demo) — prod zqnexqbdfvbhlxzelzju YASAK.
-- Koşum (tam komut; env kaynaklı; sıra: 000013 migration'ından SONRA):
--   bash -c 'set -a; source /home/melik/egesut-erp1/.env; set +a; \
--     PGPASSWORD="$SUPABASE_DEMO_DB_PASSWORD" psql \
--     "postgresql://postgres.${SUPABASE_DEMO_REF}:${SUPABASE_DEMO_DB_PASSWORD}@${SUPABASE_DEMO_POOLER}:6543/postgres" \
--     -X -v ON_ERROR_STOP=1 -f scripts/cila-onarim/2026-09-25-k4-backfill.sql'
-- Aktif Ovsync vakalarına protocol_family='OVSYNC' yazar (M6 ölçümü 2026-09-25:
-- 12/12 NULL). Migration 20260925000013 yalnız YENİ vakalara yazar; bu betik
-- mevcut aktif zincirleri onarır.
-- HEDEF KİLİDİ (F4/K4, review bulgusu): UPDATE koşulları ortam-özgü DEĞİL —
--   prod'da da aktif ovsync-hastalıklı NULL'lar vaka birikir (prod 20260923
--   serisi canlı; 20260925 dalda push'suz); başlıktaki ref notu tek korumaydı.
--   Betik artık mekanik demo işareti arar: 20260925 migration ailesi bu seride
--   YALNIZ demo'da kayıtlıdır; yoksa UPDATE bloğu HİÇ çalışmaz, EXCEPTION ile
--   durur. (İşaret, seri prod'a da uygulandıktan sonra zayıflar — betik
--   tek-seferlik uygulandı, yeniden koşulmaz.)
DO $guard$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations
                  WHERE version LIKE '20260925%') THEN
    RAISE EXCEPTION 'HEDEF ORTAM DEMO DEGIL: 20260925 serisi bu veritabaninda yok — DUR (ref dogrula: vtzqjmazsvurxdeondmi; prod zqnexqbdfvbhlxzelzju YASAK)';
  END IF;
END
$guard$;
BEGIN;
UPDATE public.cases c
   SET protocol_family = 'OVSYNC'
 WHERE c.status = 'active'
   AND c.protocol_family IS NULL
   AND EXISTS (SELECT 1 FROM public.diseases d
               WHERE d.id = c.disease_id AND d.name ILIKE '%ovsync%');
COMMIT;
