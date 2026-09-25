-- DEMO'YA ÖZEL tek-seferlik fix (cila-onarım K12) — MIGRATION DEĞİL, prod'a uygulanmaz.
-- HEDEF REF DOĞRULA (F4/K12): vtzqjmazsvurxdeondmi (demo) — prod zqnexqbdfvbhlxzelzju YASAK.
-- Koşum (tam komut; env kaynaklı):
--   bash -c 'set -a; source /home/melik/egesut-erp1/.env; set +a; \
--     PGPASSWORD="$SUPABASE_DEMO_DB_PASSWORD" psql \
--     "postgresql://postgres.${SUPABASE_DEMO_REF}:${SUPABASE_DEMO_DB_PASSWORD}@${SUPABASE_DEMO_POOLER}:6543/postgres" \
--     -X -v ON_ERROR_STOP=1 -f scripts/cila-onarim/2026-09-25-k12-sablon-ailesi.sql'
-- Kök neden (M8 + R-ARAŞTIRMA k12-sablon-belirsiz.md, 2026-09-25, birebir eşleşti):
--   tek aktif Ovsync şablonu 'Sağmal inek: Ovsynch-56 + çift PGs'
--   (id a152f7fe-e1d5-4de4-8157-344f1bffbaf7) protokol_ailesi NULL →
--   start_first_service_protocol guard'ı v_n=0 → OVSYNC_SABLON_BELIRSIZ.
--   Değeri 2026-09-23 22:30 S-3 backfill DOLDURMUŞTU; 2026-09-24 13:25 demo
--   klonu (TRUNCATE+COPY — satır tetikleyicisi tetiklenmez) prod'daki NULL
--   değeriyle ezip geri aldı. Aynı NULL, 20260923000005 kapanış-yolu aile
--   doldurmasını da besleyemiyordu (BUG-CILA-PROTOCOL-FAMILY-BOS ikinci besleyici).
-- Güvenlik: tek satır, tek kolon, NULL→'OVSYNC'; S-3 backfill'in birebir yenisi;
--   2. guard ölçülmüş geçiyor (sablon_hastalik_eslem tam 1 hastalık).
--   R-ARAŞTIRMA'nın ad-guard'lı biçimi kullanılır (UPDATE 1 beklenir; 0 dönurse
--   koşullar değişmiştir — DUR, yeniden ölç). trg_degisim_log audit kaydını
--   satır UPDATE'i otomatik yazar.
-- HEDEF KİLİDİ (F4/K12, review bulgusu): UPDATE guard koşulları prod satırında da
--   eşleşir (klon anında demo satırı = prod satırı, prod'da NULL kaldı) — yanlış
--   hedefe koşulursa sessizce prod satırını mutasyonlardı. Betik artık mekanik
--   demo işareti arar: 20260925 migration ailesi bu seride YALNIZ demo'da kayıtlıdır;
--   yoksa UPDATE bloğu HİÇ çalışmaz, EXCEPTION ile durur. (İşaret, seri prod'a da
--   uygulandıktan sonra zayıflar — betik tek-seferlik uygulandı, yeniden koşulmaz.)
-- Geri dönüş: UPDATE tedavi_sablonu SET protokol_ailesi=NULL WHERE id='a152f7fe-…'.
DO $guard$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations
                  WHERE version LIKE '20260925%') THEN
    RAISE EXCEPTION 'HEDEF ORTAM DEMO DEGIL: 20260925 serisi bu veritabaninda yok — DUR (ref dogrula: vtzqjmazsvurxdeondmi; prod zqnexqbdfvbhlxzelzju YASAK)';
  END IF;
END
$guard$;
BEGIN;
UPDATE public.tedavi_sablonu
   SET protokol_ailesi = 'OVSYNC'
 WHERE id = 'a152f7fe-e1d5-4de4-8157-344f1bffbaf7'
   AND ad ILIKE '%ovsync%'
   AND aktif IS TRUE
   AND protokol_ailesi IS NULL;
COMMIT;
