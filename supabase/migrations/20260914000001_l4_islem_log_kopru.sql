-- G-20260914-GERI-ALMA-AKISI — W1 §1: islem_log ↔ degisim_log köprüsü
--
-- Frozen contract: .harness/goals/2026/G-20260914-GERI-ALMA-AKISI.md,
--   "Frozen contract — FAZ B motor genişletmesi" §1.
--   * islem_log.degisim_txid bigint (nullable, ADDITIVE) + BEFORE INSERT
--     trigger stamping txid_current().
--   * Business rule: the RPC that writes the business row and the islem_log
--     INSERT run in ONE transaction, so degisim_txid matches degisim_log.txid
--     exactly (Geçmiş kartı → motor hedefi {txid: degisim_txid}).
--   * Replay-safe: IF NOT EXISTS / OR REPLACE / DROP+CREATE trigger.
--   * The existing immutable guard (trg_islem_log_immutable) only blocks
--     UPDATE/DELETE; INSERT stays free (live probe 2026-09-14, probe_sema.out).
--   * RLS: islem_log is FORCE RLS with policy service_insert (ALL, public,
--     WITH CHECK true) — the stamp trigger adds no privilege surface.
--
-- DEMO ONLY until the owner's prod deploy gate.

BEGIN;

ALTER TABLE public.islem_log ADD COLUMN IF NOT EXISTS degisim_txid bigint;

COMMENT ON COLUMN public.islem_log.degisim_txid IS
  'L4 G-20260914-GERI-ALMA-AKISI: txid of the transaction that wrote this log row; equals degisim_log.txid when the business row and the log are written in one transaction.';

CREATE OR REPLACE FUNCTION public._islem_log_degisim_txid()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $$
BEGIN
  IF NEW.degisim_txid IS NULL THEN
    NEW.degisim_txid := txid_current();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_islem_log_degisim_txid ON public.islem_log;
CREATE TRIGGER trg_islem_log_degisim_txid
  BEFORE INSERT ON public.islem_log
  FOR EACH ROW
  WHEN (NEW.degisim_txid IS NULL)
  EXECUTE FUNCTION public._islem_log_degisim_txid();

CREATE INDEX IF NOT EXISTS idx_islem_log_degisim_txid
  ON public.islem_log (degisim_txid);

REVOKE ALL ON FUNCTION public._islem_log_degisim_txid() FROM PUBLIC, anon, authenticated;

COMMIT;
