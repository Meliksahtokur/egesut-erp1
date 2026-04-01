-- Migration: Realtime publication aktif
-- Etkiler: supabase_realtime publication — 7 tablo eklendi
-- Geri alınabilir: evet — ALTER PUBLICATION supabase_realtime DROP TABLE ile

BEGIN;
  ALTER PUBLICATION supabase_realtime ADD TABLE
    public.hayvanlar,
    public.gorev_log,
    public.stok,
    public.stok_hareket,
    public.tohumlama,
    public.dogum,
    public.islem_log;
COMMIT;
