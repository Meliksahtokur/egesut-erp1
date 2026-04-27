-- Drop orphan columns no longer used by the clinical system
-- (new system uses cases/drug_administrations tables)
ALTER TABLE public.hastalik_log DROP COLUMN IF EXISTS ilac_stok_id;
ALTER TABLE public.hastalik_log DROP COLUMN IF EXISTS ilac_miktar;
