-- DEMO'YA ÖZEL tek-seferlik backfill (cila-onarım K4) — MIGRATION DEĞİL, prod'a uygulanmaz.
-- Aktif Ovsync vakalarına protocol_family='OVSYNC' yazar (M6 ölçümü 2026-09-25:
-- 12/12 NULL). Migration 20260925000013 yalnız YENİ vakalara yazar; bu betik
-- mevcut aktif zincirleri onarır. Koşum: psql demo (ref doğrula:
-- vtzqjmazsvurxdeondmi). Sıra: 000013 migration'ından SONRA.
BEGIN;
UPDATE public.cases c
   SET protocol_family = 'OVSYNC'
 WHERE c.status = 'active'
   AND c.protocol_family IS NULL
   AND EXISTS (SELECT 1 FROM public.diseases d
               WHERE d.id = c.disease_id AND d.name ILIKE '%ovsync%');
COMMIT;
