-- G-20260913-SURUM-GECMISI — F1: row-version log (degisim_log)
--
-- Frozen contract: .harness/goals/2026/G-20260913-SURUM-GECMISI.md
--   "Frozen contract — degisim_log schema".
-- Scope inventory (live DEMO schema, 2026-09-13) and include/exclude rationale:
--   reports/2026-09-13-surum-gecmisi-W1-db.md §Inventory.
--
-- Tenant/RLS: mirrors live islem_log (RLS enabled, SELECT USING(true), no
-- farm_id). Grants are narrower than islem_log on purpose: authenticated gets
-- SELECT only (islem_log's INSERT grant would allow forged history rows);
-- rows are written exclusively by the SECURITY DEFINER trigger below.
--
-- DEMO ONLY until the owner's prod deploy gate.

BEGIN;

CREATE TABLE IF NOT EXISTS public.degisim_log (
  id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  txid            bigint      NOT NULL,
  kayit_zamani    timestamptz NOT NULL DEFAULT now(),
  tablo_adi       text        NOT NULL,
  satir_pk        jsonb       NOT NULL,
  islem           text        NOT NULL CHECK (islem IN ('I','U','D')),
  eski            jsonb,
  yeni            jsonb,
  degisen_alanlar text[],
  teknikal_mi     boolean     NOT NULL DEFAULT false,
  kaynak          jsonb       NOT NULL
);

COMMENT ON TABLE public.degisim_log IS
  'G-20260913-SURUM-GECMISI F1: immutable row-version log. One row per changed business row; txid groups a transaction.';

CREATE INDEX IF NOT EXISTS idx_degisim_log_tablo_pk ON public.degisim_log (tablo_adi, satir_pk);
CREATE INDEX IF NOT EXISTS idx_degisim_log_txid     ON public.degisim_log (txid);
CREATE INDEX IF NOT EXISTS idx_degisim_log_zaman    ON public.degisim_log (kayit_zamani);

ALTER TABLE public.degisim_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS degisim_log_select ON public.degisim_log;
CREATE POLICY degisim_log_select ON public.degisim_log FOR SELECT USING (true);

-- Default privileges hand authenticated arwd on new public tables; undo that.
REVOKE ALL ON public.degisim_log FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.degisim_log TO authenticated;

-- ── Immutability ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._degisim_log_degistirilemez()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
BEGIN
  RAISE EXCEPTION 'degisim_log degistirilemez (% reddedildi)', TG_OP
    USING ERRCODE = 'insufficient_privilege';
END;
$$;

DROP TRIGGER IF EXISTS trg_degisim_log_immutable ON public.degisim_log;
CREATE TRIGGER trg_degisim_log_immutable
  BEFORE UPDATE OR DELETE ON public.degisim_log
  FOR EACH ROW EXECUTE FUNCTION public._degisim_log_degistirilemez();

DROP TRIGGER IF EXISTS trg_degisim_log_no_truncate ON public.degisim_log;
CREATE TRIGGER trg_degisim_log_no_truncate
  BEFORE TRUNCATE ON public.degisim_log
  FOR EACH STATEMENT EXECUTE FUNCTION public._degisim_log_degistirilemez();

-- ── Generic row trigger ─────────────────────────────────────────────────────
-- TG_ARGV = primary-key column names of the attached table (set at attach
-- time from the catalog), so satir_pk is composite-safe without a per-row
-- catalog lookup.
CREATE OR REPLACE FUNCTION public._degisim_log_yaz()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  -- Technical columns (live DEMO inventory 2026-09-13): bookkeeping
  -- timestamps only. A U touching only these is logged with teknikal_mi=true.
  c_teknik  CONSTANT text[] := ARRAY['created_at','updated_at','olusturma',
                                     'guncelleme','guncelleme_tarihi','guncellendi'];
  v_eski    jsonb;
  v_yeni    jsonb;
  v_kaynak_satir jsonb;
  v_pk      jsonb := '{}'::jsonb;
  v_alanlar text[];
  v_claims  jsonb;
  v_headers jsonb;
  v_rol     text;
  v_bilet   text;
  v_kaynak  jsonb;
  i         int;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_yeni := to_jsonb(NEW);
    v_kaynak_satir := v_yeni;
  ELSIF TG_OP = 'UPDATE' THEN
    v_eski := to_jsonb(OLD);
    v_yeni := to_jsonb(NEW);
    v_kaynak_satir := v_yeni;
    SELECT array_agg(k ORDER BY k) INTO v_alanlar
      FROM jsonb_object_keys(v_yeni) AS k
     WHERE (v_yeni -> k) IS DISTINCT FROM (v_eski -> k);
    IF v_alanlar IS NULL THEN
      RETURN NULL;                       -- no content change → no record
    END IF;
  ELSE
    v_eski := to_jsonb(OLD);
    v_kaynak_satir := v_eski;
  END IF;

  FOR i IN 0 .. TG_NARGS - 1 LOOP
    v_pk := v_pk || jsonb_build_object(TG_ARGV[i], v_kaynak_satir -> TG_ARGV[i]);
  END LOOP;

  BEGIN
    v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  EXCEPTION WHEN others THEN v_claims := NULL;
  END;
  BEGIN
    v_headers := nullif(current_setting('request.headers', true), '')::jsonb;
  EXCEPTION WHEN others THEN v_headers := NULL;
  END;

  -- SECURITY DEFINER masks current_user; the 'role' GUC keeps the caller's
  -- SET ROLE (PostgREST: authenticated/anon). Fall back to the login role.
  v_rol := nullif(current_setting('role', true), 'none');
  v_bilet := nullif(current_setting('app.geri_alma_bileti', true), '');

  v_kaynak := jsonb_strip_nulls(jsonb_build_object(
    'rol',             coalesce(v_rol, session_user::text),
    'oturum_rolu',     session_user::text,
    'jwt_sub',         v_claims ->> 'sub',
    'jwt_role',        v_claims ->> 'role',
    'app_name',        nullif(current_setting('application_name', true), ''),
    'istemci_etiketi', coalesce(nullif(current_setting('app.istemci_etiketi', true), ''),
                                v_headers ->> 'x-client-info')
  ));
  IF v_bilet IS NOT NULL THEN
    v_kaynak := v_kaynak || jsonb_build_object('geri_alma', jsonb_strip_nulls(jsonb_build_object(
      'bilet',   v_bilet,
      'gerekce', nullif(current_setting('app.geri_alma_gerekce', true), ''))));
  END IF;

  INSERT INTO public.degisim_log
    (txid, tablo_adi, satir_pk, islem, eski, yeni, degisen_alanlar, teknikal_mi, kaynak)
  VALUES
    (txid_current(), TG_TABLE_NAME, v_pk, left(TG_OP, 1), v_eski, v_yeni, v_alanlar,
     coalesce(v_alanlar <@ c_teknik, false), v_kaynak);

  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public._degisim_log_yaz() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._degisim_log_degistirilemez() FROM PUBLIC, anon, authenticated;

-- ── Attach to the business-table inventory ─────────────────────────────────
-- Explicit list (reviewable); PK columns derived from the live catalog.
-- A listed table that is missing or has no PK aborts the migration.
DO $$
DECLARE
  v_tablolar text[] := ARRAY[
    'cases','diseases','dogum','drug_administrations',
    'drug_classes','drug_products','drugs','gorev_log','grup_padok_eslem',
    'hastalik_log','hayvan_override','hayvanlar','hekimler','irk_esik',
    'kizginlik_log','padoklar','pedigree_meta','pedigree_nodes',
    'pedigree_parentage','protokol_ayar','protokol_dismiss','protokol_instance',
    'sablon_hastalik_eslem','semen_catalog','stok','stok_hareket',
    'stok_kategorileri','tedavi','tedavi_sablonu','tedavi_sablonu_kalem',
    'tohumlama','treatment_day_uygulamalar','treatment_days','uygulama_log',
    'vaccination_log','vaccination_schedule','vaccine_diseases',
    'vaccine_protocol_steps','vaccines'];
  t text;
  v_args text;
BEGIN
  -- drift cleanup: detach from tables that fell out of the inventory list
  FOR t IN
    SELECT cl.relname::text
      FROM pg_trigger g JOIN pg_class cl ON cl.oid = g.tgrelid
      JOIN pg_namespace cn ON cn.oid = cl.relnamespace
     WHERE g.tgname = 'trg_degisim_log' AND cn.nspname = 'public'
       AND cl.relname <> ALL (v_tablolar)
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_degisim_log ON public.%I', t);
  END LOOP;

  FOREACH t IN ARRAY v_tablolar LOOP
    SELECT string_agg(quote_literal(a.attname), ', ' ORDER BY k.ord)
      INTO v_args
      FROM pg_constraint c
      CROSS JOIN LATERAL unnest(c.conkey) WITH ORDINALITY AS k(attnum, ord)
      JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum
     WHERE c.conrelid = format('public.%I', t)::regclass AND c.contype = 'p';
    IF v_args IS NULL THEN
      RAISE EXCEPTION 'degisim_log attach: % has no primary key', t;
    END IF;
    -- The revert executor re-inserts rows column-by-column from eski; an
    -- always-identity or generated PK could not be re-supplied and would
    -- renumber silently. Refuse such tables at attach time (none today).
    IF EXISTS (
      SELECT 1
        FROM pg_constraint c2
        CROSS JOIN LATERAL unnest(c2.conkey) AS u(attnum)
        JOIN pg_attribute a ON a.attrelid = c2.conrelid AND a.attnum = u.attnum
       WHERE c2.conrelid = format('public.%I', t)::regclass AND c2.contype = 'p'
         AND (a.attidentity <> '' OR a.attgenerated <> '')) THEN
      RAISE EXCEPTION 'degisim_log attach: % PK identity/generated kolon tasiyor (revert yazamaz)', t;
    END IF;
    EXECUTE format('DROP TRIGGER IF EXISTS trg_degisim_log ON public.%I', t);
    EXECUTE format(
      'CREATE TRIGGER trg_degisim_log AFTER INSERT OR UPDATE OR DELETE ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION public._degisim_log_yaz(%s)', t, v_args);
  END LOOP;
END;
$$;

COMMIT;
