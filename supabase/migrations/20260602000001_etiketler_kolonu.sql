-- supabase/migrations/20260602000001_etiketler_kolonu.sql
ALTER TABLE hayvanlar ADD COLUMN IF NOT EXISTS etiketler text[] DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_hayvanlar_etiketler
  ON hayvanlar USING GIN(etiketler);

COMMENT ON COLUMN hayvanlar.etiketler IS
  'Hayvan etiketleri. Geçerli değerler: kisir, satista';
