-- Migration: Agent DB Telemetry Publication
-- Tarih: 2026-03-31
-- Açıklama: Gwen agent'ın DB değişikliklerini izlemesi için CDC publication

BEGIN;

-- Mevcut publication'ı temizle
DROP PUBLICATION IF EXISTS gwen_db_watch;

-- Agent için publication oluştur
-- Kritik tablolar: islem_log, stok_hareket, gorev_log, hayvanlar
CREATE PUBLICATION gwen_db_watch FOR TABLE 
  public.islem_log, 
  public.stok_hareket, 
  public.gorev_log,
  public.hayvanlar;

-- Realtime replication'i aktif et
ALTER PUBLICATION gwen_db_watch 
  SET (publish = 'insert, update, delete');

COMMIT;

-- Doğrulama
SELECT pubname, puballtables 
FROM pg_publication 
WHERE pubname = 'gwen_db_watch';
