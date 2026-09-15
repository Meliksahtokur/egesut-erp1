-- G-20260913-SURUM-GECMISI — F2: owner-password setup RPC
--
-- No password or hash is stored in any migration. The owner sets the
-- password AFTER deploy, as a separate setup step, with the service role:
--   SELECT public.sahip_sifresi_ayarla('<owner password>');
-- (demo: the acceptance script sets a throwaway test password).
--
-- Not callable by authenticated/anon: otherwise any signed-in user could
-- replace the owner password and mint revert tickets. Changing the password
-- expires every outstanding ticket.
--
-- DEMO ONLY until the owner's prod deploy gate.

BEGIN;

CREATE OR REPLACE FUNCTION public.sahip_sifresi_ayarla(p_sifre text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF p_sifre IS NULL OR length(p_sifre) < 8 THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'SIFRE_KISA');
  END IF;

  INSERT INTO surum_gizli.sahip_sifresi (id, hash, guncelleme)
  VALUES (1, extensions.crypt(p_sifre, extensions.gen_salt('bf', 10)), now())
  ON CONFLICT (id) DO UPDATE SET hash = EXCLUDED.hash, guncelleme = EXCLUDED.guncelleme;

  UPDATE surum_gizli.geri_alma_bileti
     SET son_gecerlilik = now()
   WHERE son_gecerlilik > now();

  RETURN jsonb_build_object('ok', true, 'guncelleme', now());
END;
$$;

REVOKE ALL ON FUNCTION public.sahip_sifresi_ayarla(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sahip_sifresi_ayarla(text) TO service_role;

COMMIT;
