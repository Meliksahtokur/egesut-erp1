-- ============================================================================
-- Migration: 20261006000001_stat_motor_rol
-- Tarih: 2026-10-06 · istatistik F2 Task 2 (plan P2 — spec §7.1, A5)
-- Etkiler: yeni DB rolü stat_motor (NOLOGIN, parola YOK) + sonuç tablosu
--   yetkileri. Tablo/fonksiyon/veri değişikliği YOK.
-- Yetki listesi (görev Interfaces, birebir; başka yetki yok):
--   USAGE ON SCHEMA public; stat_analiz_sonuc S/I/U/D; stat_motor_kosum S/I/U;
--   stat_olcum_kayit S; iki identity sequence'ine USAGE.
--   stat_ayikla_* EXECUTE sonraki görevde (fonksiyonla aynı migration'da).
-- LOGIN + parola migration DIŞI: ortam başına elle `ALTER ROLE ... LOGIN
--   PASSWORD` (sahip kararı F2-S3); parola yalnız ~/.config/stat-motor/*.env.
-- Idempotent: rol IF NOT EXISTS; GRANT/COMMENT tekrar koşumda no-op.
-- Geri alma (ledger "Demo geri alma listesi" madde 2): REVOKE ALL ... FROM
--   stat_motor (3 tablo + 2 sequence + schema USAGE); DROP ROLE stat_motor;
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'stat_motor') THEN
    CREATE ROLE stat_motor NOLOGIN;
  END IF;
END
$$;

COMMENT ON ROLE stat_motor IS
  'İstatistik motoru DB kimliği (spec §7.1): doğrudan Postgres (pooler), özel DB rolü stat_motor (yalnız stat_ayikla_* EXECUTE + stat_analiz_sonuc/stat_motor_kosum INSERT/UPDATE); service-role anahtarı kullanılmaz.';

GRANT USAGE ON SCHEMA public TO stat_motor;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.stat_analiz_sonuc TO stat_motor;
GRANT SELECT, INSERT, UPDATE ON TABLE public.stat_motor_kosum TO stat_motor;
GRANT SELECT ON TABLE public.stat_olcum_kayit TO stat_motor;

-- identity GENERATED ALWAYS → sahip sequence'ler (pg_get_serial_sequence ile doğrulandı)
GRANT USAGE ON SEQUENCE public.stat_analiz_sonuc_id_seq TO stat_motor;
GRANT USAGE ON SEQUENCE public.stat_motor_kosum_id_seq TO stat_motor;

COMMIT;
