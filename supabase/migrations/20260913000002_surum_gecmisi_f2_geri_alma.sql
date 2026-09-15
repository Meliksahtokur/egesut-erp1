-- G-20260913-SURUM-GECMISI — F2: ticketed revert engine
--
-- Frozen contract: .harness/goals/2026/G-20260913-SURUM-GECMISI.md
--   "Frozen contract — F2 RPC surface".
-- Public RPCs (authenticated only, anon denied):
--   geri_alma_bileti_al(p_sifre)            -> 1h multi-use ticket
--   degisim_listele(p_filtre)               -> tx-grouped list / tx detail
--   degisim_onizle(p_hedef, p_seviye)       -> plan, conflicts, dependencies
--   degisim_geri_al(p_hedef, p_seviye, p_bilet, p_gerekce) -> apply
-- The owner-password setup RPC lives in 20260913000003 (no hash in any
-- migration file).
--
-- Contract clarifications (lead-approved, ss-ask c9f7fd34; goal 3674e62),
-- recorded in reports/2026-09-13-surum-gecmisi-W1-db.md:
--   * p_hedef.pk: string value of a single-column PK (uuid/text/number),
--     or an object {pk_col: value} for composite PKs. Outputs carry both
--     "pk" (scalar when single-column) and "satir_pk" (canonical object).
--   * p_hedef.txid is optional for 'satir'/'alan': given -> that tx's
--     changes of the row/field; omitted -> the latest change.
--   * Secrets (password hash, tickets, usage) live in schema surum_gizli:
--     not exposed by PostgREST and skipped by public.demo_klonla, which
--     truncates and re-copies every public table from prod.
--
-- DEMO ONLY until the owner's prod deploy gate.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE SCHEMA IF NOT EXISTS surum_gizli;
REVOKE ALL ON SCHEMA surum_gizli FROM PUBLIC, anon, authenticated;
-- future tables in this schema start locked as well
ALTER DEFAULT PRIVILEGES IN SCHEMA surum_gizli
  REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS surum_gizli.sahip_sifresi (
  id         int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  hash       text        NOT NULL,
  guncelleme timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS surum_gizli.geri_alma_bileti (
  bilet          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  olusturma      timestamptz NOT NULL DEFAULT now(),
  son_gecerlilik timestamptz NOT NULL,
  kaynak         jsonb       NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS surum_gizli.geri_alma_kullanim (
  id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  bilet          uuid        NOT NULL REFERENCES surum_gizli.geri_alma_bileti (bilet),
  zaman          timestamptz NOT NULL DEFAULT now(),
  hedef          jsonb,
  seviye         text,
  gerekce        text,
  sonuc          jsonb       NOT NULL,
  geri_alma_txid bigint,
  kaynak         jsonb       NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS idx_geri_alma_kullanim_bilet ON surum_gizli.geri_alma_kullanim (bilet);

REVOKE ALL ON ALL TABLES IN SCHEMA surum_gizli FROM PUBLIC, anon, authenticated;

-- ── internal helpers (schema surum_gizli, not callable by clients) ─────────

-- caller identity, same shape as degisim_log.kaynak
CREATE OR REPLACE FUNCTION surum_gizli._cagiran()
RETURNS jsonb
LANGUAGE plpgsql STABLE
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_claims  jsonb;
  v_headers jsonb;
BEGIN
  BEGIN
    v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  EXCEPTION WHEN others THEN v_claims := NULL;
  END;
  BEGIN
    v_headers := nullif(current_setting('request.headers', true), '')::jsonb;
  EXCEPTION WHEN others THEN v_headers := NULL;
  END;
  RETURN jsonb_strip_nulls(jsonb_build_object(
    'rol',      coalesce(nullif(current_setting('role', true), 'none'), session_user::text),
    'jwt_sub',  v_claims ->> 'sub',
    'jwt_role', v_claims ->> 'role',
    'app_name', nullif(current_setting('application_name', true), ''),
    'istemci_etiketi', coalesce(nullif(current_setting('app.istemci_etiketi', true), ''),
                                v_headers ->> 'x-client-info')));
END;
$$;

-- table is in degisim_log scope (carries trg_degisim_log)
CREATE OR REPLACE FUNCTION surum_gizli._kapsamda(p_tablo text)
RETURNS boolean
LANGUAGE sql STABLE
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (SELECT 1 FROM pg_trigger
                  WHERE tgrelid = to_regclass(format('public.%I', p_tablo))
                    AND tgname = 'trg_degisim_log');
$$;

-- quoted, comma-separated PK column list of public.<tablo>
CREATE OR REPLACE FUNCTION surum_gizli._pk_kolonlar(p_tablo text)
RETURNS text
LANGUAGE sql STABLE
SET search_path = pg_catalog, public
AS $$
  SELECT string_agg(quote_ident(a.attname), ', ' ORDER BY k.ord)
    FROM pg_constraint c
    CROSS JOIN LATERAL unnest(c.conkey) WITH ORDINALITY AS k(attnum, ord)
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum
   WHERE c.conrelid = to_regclass(format('public.%I', p_tablo)) AND c.contype = 'p';
$$;

-- client pk (scalar or object) -> canonical satir_pk object; NULL if invalid
CREATE OR REPLACE FUNCTION surum_gizli._pk_json(p_tablo text, p_pk jsonb)
RETURNS jsonb
LANGUAGE plpgsql STABLE
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_cols  text[];
  v_types text[];
  v_out   jsonb := '{}'::jsonb;
  v_val   jsonb;
  i       int;
BEGIN
  SELECT array_agg(a.attname::text ORDER BY k.ord),
         array_agg(format_type(a.atttypid, a.atttypmod) ORDER BY k.ord)
    INTO v_cols, v_types
    FROM pg_constraint c
    CROSS JOIN LATERAL unnest(c.conkey) WITH ORDINALITY AS k(attnum, ord)
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = k.attnum
   WHERE c.conrelid = to_regclass(format('public.%I', p_tablo)) AND c.contype = 'p';
  IF v_cols IS NULL OR p_pk IS NULL THEN
    RETURN NULL;
  END IF;

  IF jsonb_typeof(p_pk) = 'object' THEN
    FOR i IN 1 .. array_length(v_cols, 1) LOOP
      IF NOT p_pk ? v_cols[i] OR jsonb_typeof(p_pk -> v_cols[i]) = 'null' THEN
        RETURN NULL;
      END IF;
      EXECUTE format('SELECT to_jsonb(%L::%s)', p_pk ->> v_cols[i], v_types[i]) INTO v_val;
      v_out := v_out || jsonb_build_object(v_cols[i], v_val);
    END LOOP;
  ELSIF array_length(v_cols, 1) = 1 AND jsonb_typeof(p_pk) IN ('string', 'number') THEN
    EXECUTE format('SELECT to_jsonb(%L::%s)', p_pk #>> '{}', v_types[1]) INTO v_val;
    v_out := jsonb_build_object(v_cols[1], v_val);
  ELSE
    RETURN NULL;
  END IF;
  RETURN v_out;
EXCEPTION WHEN others THEN
  RETURN NULL;   -- value does not cast to the PK type
END;
$$;

-- satir_pk object -> display pk: scalar string for single-column PKs
CREATE OR REPLACE FUNCTION surum_gizli._pk_gorunum(p_satir_pk jsonb)
RETURNS jsonb
LANGUAGE sql IMMUTABLE
SET search_path = pg_catalog
AS $$
  SELECT CASE WHEN (SELECT count(*) FROM jsonb_object_keys(p_satir_pk)) = 1
              THEN (SELECT to_jsonb(v #>> '{}') FROM jsonb_each(p_satir_pk) AS e(k, v))
              ELSE p_satir_pk END;
$$;

-- current row of public.<tablo> identified by satir_pk (NULL if absent)
CREATE OR REPLACE FUNCTION surum_gizli._guncel_satir(p_tablo text, p_satir_pk jsonb)
RETURNS jsonb
LANGUAGE plpgsql STABLE
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_pkc text := surum_gizli._pk_kolonlar(p_tablo);
  v_row jsonb;
BEGIN
  EXECUTE format('SELECT to_jsonb(x) FROM public.%1$I x WHERE (%2$s) = (SELECT %2$s FROM jsonb_populate_record(NULL::public.%1$I, $1))',
                 p_tablo, v_pkc)
    INTO v_row USING p_satir_pk;
  RETURN v_row;
END;
$$;

-- EKLE topology: would re-inserting p_cocik require p_eklenecek to exist
-- first? (child's eski FK-column values == parent's satir_pk) — orders
-- re-inserts parents-first on cascade revert and flags cascade children
-- left out of a partial revert.
CREATE OR REPLACE FUNCTION surum_gizli._ekle_bagli(p_eklenecek public.degisim_log, p_cocik public.degisim_log)
RETURNS boolean
LANGUAGE plpgsql STABLE
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_ok boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
      FROM pg_constraint con
     WHERE con.contype = 'f'
       AND con.conrelid = format('public.%I', p_cocik.tablo_adi)::regclass
       AND con.confrelid = format('public.%I', p_eklenecek.tablo_adi)::regclass
       AND NOT EXISTS (
             SELECT 1
               FROM unnest(con.conkey, con.confkey) AS u(ck, pk)
               JOIN pg_attribute ca ON ca.attrelid = con.conrelid AND ca.attnum = u.ck
               JOIN pg_attribute pa ON pa.attrelid = con.confrelid AND pa.attnum = u.pk
              WHERE coalesce(p_cocik.eski ->> ca.attname, '')
                    IS DISTINCT FROM coalesce(p_eklenecek.satir_pk ->> pa.attname, '')))
    INTO v_ok;
  RETURN v_ok;
END;
$$;

-- ── plan: the single source of truth for onizle and geri_al ────────────────
CREATE OR REPLACE FUNCTION surum_gizli._degisim_plan(p_hedef jsonb, p_seviye text)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
DECLARE
  c_teknik  CONSTANT text[] := ARRAY['created_at','updated_at','olusturma',
                                     'guncelleme','guncelleme_tarihi','guncellendi'];
  v_txid    bigint;
  v_tablo   text;
  v_pk      jsonb;
  v_alan    text;
  v_ids     bigint[];
  v_work    bigint[];
  v_eid     bigint;
  v_cids    bigint[];
  v_ctx     bigint[];
  v_cpk     jsonb;
  v_cur     jsonb;
  v_fields  text[];
  v_exists  boolean;
  v_later   record;
  e         public.degisim_log;
  fk        record;
  ch        record;
  r         record;
  v_ekle    public.degisim_log[];
  v_sirali  public.degisim_log[];
  v_topo    public.degisim_log[] := ARRAY[]::public.degisim_log[];
  v_n       int;
  v_derece  int[];
  v_cikti   boolean[];
  v_kalan   int;
  v_bulundu boolean;
  i         int;
  j         int;
  v_plan    jsonb  := '[]'::jsonb;
  v_cak     jsonb  := '[]'::jsonb;
  v_bag     jsonb  := '[]'::jsonb;
  v_stok    jsonb  := '[]'::jsonb;
  v_eng     text[] := '{}';
  v_sira    int    := 0;
BEGIN
  IF p_seviye IS NULL OR p_seviye NOT IN ('alan', 'satir', 'islem') THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_SEVIYE');
  END IF;
  IF p_hedef IS NULL OR jsonb_typeof(p_hedef) <> 'object' THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
  END IF;
  IF nullif(p_hedef ->> 'txid', '') IS NOT NULL THEN
    BEGIN
      v_txid := (p_hedef ->> 'txid')::bigint;
    EXCEPTION WHEN others THEN
      RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
    END;
  END IF;

  -- ── 1. target entries ──
  IF p_seviye = 'islem' THEN
    IF v_txid IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
    END IF;
    SELECT array_agg(id ORDER BY id) INTO v_ids FROM public.degisim_log WHERE txid = v_txid;
  ELSE
    v_tablo := p_hedef ->> 'tablo';
    IF v_tablo IS NULL OR NOT surum_gizli._kapsamda(v_tablo) THEN
      RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
    END IF;
    v_pk := surum_gizli._pk_json(v_tablo, p_hedef -> 'pk');
    IF v_pk IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
    END IF;

    IF p_seviye = 'alan' THEN
      v_alan := p_hedef ->> 'alan';
      IF v_alan IS NULL OR NOT EXISTS (
           SELECT 1 FROM pg_attribute
            WHERE attrelid = format('public.%I', v_tablo)::regclass
              AND attname = v_alan AND attnum > 0 AND NOT attisdropped) THEN
        RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
      END IF;
      IF v_txid IS NULL THEN
        SELECT txid INTO v_txid FROM public.degisim_log
         WHERE tablo_adi = v_tablo AND satir_pk = v_pk
           AND (islem <> 'U' OR v_alan = ANY (degisen_alanlar))
         ORDER BY id DESC LIMIT 1;
      END IF;
      IF v_txid IS NULL OR NOT EXISTS (
           SELECT 1 FROM public.degisim_log
            WHERE txid = v_txid AND tablo_adi = v_tablo AND satir_pk = v_pk) THEN
        RETURN jsonb_build_object('ok', false, 'hata', 'HEDEF_BULUNAMADI');
      END IF;
      SELECT array_agg(id ORDER BY id) INTO v_ids FROM public.degisim_log
       WHERE txid = v_txid AND tablo_adi = v_tablo AND satir_pk = v_pk
         AND islem = 'U' AND v_alan = ANY (degisen_alanlar);
      IF v_ids IS NULL THEN
        -- the row changed in that tx, but not as an UPDATE of this field
        RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_HEDEF');
      END IF;
    ELSE
      IF v_txid IS NULL THEN
        SELECT txid INTO v_txid FROM public.degisim_log
         WHERE tablo_adi = v_tablo AND satir_pk = v_pk
         ORDER BY id DESC LIMIT 1;
      END IF;
      SELECT array_agg(id ORDER BY id) INTO v_ids FROM public.degisim_log
       WHERE txid = v_txid AND tablo_adi = v_tablo AND satir_pk = v_pk;

      -- stock movements of the same tx that reference this row join the plan
      IF v_ids IS NOT NULL AND v_tablo <> 'stok_hareket'
         AND (SELECT count(*) FROM jsonb_object_keys(v_pk)) = 1 THEN
        v_ids := v_ids || ARRAY(
          SELECT id FROM public.degisim_log
           WHERE txid = v_txid AND tablo_adi = 'stok_hareket'
             AND coalesce(yeni, eski) ->> 'referans_id' = (SELECT v #>> '{}' FROM jsonb_each(v_pk) AS x(k, v))
             AND id <> ALL (v_ids));
      END IF;
    END IF;
  END IF;

  IF v_ids IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'HEDEF_BULUNAMADI');
  END IF;

  -- ── 2. dependencies of rows the plan will DELETE (reverting an INSERT) ──
  IF p_seviye <> 'alan' THEN
    v_work := ARRAY(SELECT id FROM public.degisim_log WHERE id = ANY (v_ids) AND islem = 'I' ORDER BY id);
    WHILE cardinality(v_work) > 0 LOOP
      v_eid := v_work[1];
      v_work := v_work[2:];
      SELECT * INTO e FROM public.degisim_log WHERE id = v_eid;
      FOR fk IN
        SELECT cc.relname::text AS child, con.conrelid AS child_rel, con.confdeltype,
               array_agg(ca.attname::text ORDER BY k.ord) AS ccols,
               array_agg(pa.attname::text ORDER BY k.ord) AS pcols
          FROM pg_constraint con
          JOIN pg_class cc ON cc.oid = con.conrelid
          CROSS JOIN LATERAL unnest(con.conkey, con.confkey) WITH ORDINALITY AS k(ck, pk, ord)
          JOIN pg_attribute ca ON ca.attrelid = con.conrelid AND ca.attnum = k.ck
          JOIN pg_attribute pa ON pa.attrelid = con.confrelid AND pa.attnum = k.pk
         WHERE con.contype = 'f'
           AND con.confrelid = format('public.%I', e.tablo_adi)::regclass
           AND cc.relnamespace = 'public'::regnamespace
         GROUP BY 1, 2, 3
      LOOP
        FOR ch IN EXECUTE format(
            'SELECT to_jsonb(c) AS j FROM public.%I c WHERE (%s) = (SELECT %s FROM jsonb_populate_record(NULL::public.%I, $1))',
            fk.child,
            (SELECT string_agg(format('c.%I', x), ', ') FROM unnest(fk.ccols) x),
            (SELECT string_agg(format('%I', x), ', ') FROM unnest(fk.pcols) x),
            e.tablo_adi)
          USING e.yeni
        LOOP
          SELECT jsonb_object_agg(a.attname, ch.j -> a.attname) INTO v_cpk
            FROM pg_constraint pc
            CROSS JOIN LATERAL unnest(pc.conkey) AS u(n)
            JOIN pg_attribute a ON a.attrelid = pc.conrelid AND a.attnum = u.n
           WHERE pc.conrelid = fk.child_rel AND pc.contype = 'p';
          SELECT array_agg(id), array_agg(DISTINCT txid) INTO v_cids, v_ctx
            FROM public.degisim_log WHERE tablo_adi = fk.child AND satir_pk = v_cpk;

          IF v_cids && v_ids THEN
            CONTINUE;                                   -- already in the plan
          ELSIF v_cids IS NULL THEN
            -- untracked child (pre-system or written with triggers off)
            v_bag := v_bag || jsonb_build_object(
              'tablo', fk.child, 'pk', surum_gizli._pk_gorunum(v_cpk), 'satir_pk', v_cpk,
              'iliski', format('%s(%s) -> %s', fk.child, array_to_string(fk.ccols, ','), e.tablo_adi),
              'etki', CASE WHEN fk.confdeltype = 'n' THEN 'UYARI' ELSE 'ENGEL' END);
            IF fk.confdeltype <> 'n' THEN
              v_eng := v_eng || format('%s kaydı %s geçmişi olmayan bağımlı kayıt', fk.child, surum_gizli._pk_gorunum(v_cpk));
            END IF;
          ELSIF v_ctx = ARRAY[e.txid] THEN
            -- child born and only changed in the same tx: cascade it
            v_bag := v_bag || jsonb_build_object(
              'tablo', fk.child, 'pk', surum_gizli._pk_gorunum(v_cpk), 'satir_pk', v_cpk,
              'iliski', format('%s(%s) -> %s', fk.child, array_to_string(fk.ccols, ','), e.tablo_adi),
              'etki', 'KADEMELI');
            v_ids := v_ids || v_cids;
            v_work := v_work || ARRAY(SELECT id FROM public.degisim_log WHERE id = ANY (v_cids) AND islem = 'I');
          ELSE
            v_bag := v_bag || jsonb_build_object(
              'tablo', fk.child, 'pk', surum_gizli._pk_gorunum(v_cpk), 'satir_pk', v_cpk,
              'iliski', format('%s(%s) -> %s', fk.child, array_to_string(fk.ccols, ','), e.tablo_adi),
              'etki', 'ENGEL');
            v_eng := v_eng || format('%s kaydı %s hedef işlemden sonra değişmiş bağımlı kayıt', fk.child, surum_gizli._pk_gorunum(v_cpk));
          END IF;
        END LOOP;
      END LOOP;
    END LOOP;

    -- rows the plan re-INSERTs (reverting a DELETE) need their FK parents
    FOR e IN SELECT * FROM public.degisim_log WHERE id = ANY (v_ids) AND islem = 'D' LOOP
      FOR fk IN
        SELECT pcl.relname::text AS parent, con.confdeltype,
               array_agg(ca.attname::text ORDER BY k.ord) AS ccols,
               array_agg(pa.attname::text ORDER BY k.ord) AS pcols
          FROM pg_constraint con
          JOIN pg_class pcl ON pcl.oid = con.confrelid
          CROSS JOIN LATERAL unnest(con.conkey, con.confkey) WITH ORDINALITY AS k(ck, pk, ord)
          JOIN pg_attribute ca ON ca.attrelid = con.conrelid AND ca.attnum = k.ck
          JOIN pg_attribute pa ON pa.attrelid = con.confrelid AND pa.attnum = k.pk
         WHERE con.contype = 'f'
           AND con.conrelid = format('public.%I', e.tablo_adi)::regclass
           AND pcl.relnamespace = 'public'::regnamespace
         GROUP BY 1, 2
      LOOP
        CONTINUE WHEN EXISTS (SELECT 1 FROM unnest(fk.ccols) c WHERE e.eski ->> c IS NULL);
        EXECUTE format(
          'SELECT EXISTS (SELECT 1 FROM public.%I p WHERE (%s) = (SELECT %s FROM jsonb_populate_record(NULL::public.%I, $1)))',
          fk.parent,
          (SELECT string_agg(format('p.%I', x), ', ') FROM unnest(fk.pcols) x),
          (SELECT string_agg(format('%I', x), ', ') FROM unnest(fk.ccols) x),
          e.tablo_adi)
          INTO v_exists USING e.eski;
        IF NOT v_exists AND NOT EXISTS (
             SELECT 1 FROM public.degisim_log d
              WHERE d.id = ANY (v_ids) AND d.tablo_adi = fk.parent AND d.islem = 'D'
                AND NOT EXISTS (SELECT 1 FROM unnest(fk.pcols, fk.ccols) AS u(p, c)
                                 WHERE d.eski ->> u.p IS DISTINCT FROM e.eski ->> u.c)) THEN
          v_bag := v_bag || jsonb_build_object(
            'tablo', fk.parent, 'pk', NULL,
            'iliski', format('%s(%s) -> %s(%s)', e.tablo_adi, array_to_string(fk.ccols, ','),
                             fk.parent, array_to_string(fk.pcols, ',')),
            'etki', 'ENGEL');
          v_eng := v_eng || format('%s kaydı geri eklenemez: üst kayıt (%s) yok', e.tablo_adi, fk.parent);
        END IF;
      END LOOP;
    END LOOP;
  END IF;

  -- ── 3. conflicts: ANY later change not in the plan (technical-only
  --    included; no bypass — owner/lead rule), or state drift ──
  FOR r IN
    SELECT tablo_adi, satir_pk, max(id) AS son_id
      FROM public.degisim_log WHERE id = ANY (v_ids) GROUP BY 1, 2
  LOOP
    SELECT l.id, l.txid, l.islem INTO v_later
      FROM public.degisim_log l
     WHERE l.tablo_adi = r.tablo_adi AND l.satir_pk = r.satir_pk
       AND l.id > r.son_id AND l.id <> ALL (v_ids)
       AND (p_seviye <> 'alan' OR l.islem <> 'U' OR v_alan = ANY (l.degisen_alanlar))
     ORDER BY l.id LIMIT 1;
    IF FOUND THEN
      v_cak := v_cak || jsonb_strip_nulls(jsonb_build_object(
        'tablo', r.tablo_adi, 'pk', surum_gizli._pk_gorunum(r.satir_pk), 'satir_pk', r.satir_pk,
        'alan', v_alan, 'neden', 'SONRAKI_DEGISIKLIK', 'txid', v_later.txid::text));
      CONTINUE;
    END IF;

    SELECT * INTO e FROM public.degisim_log WHERE id = r.son_id;
    v_cur := surum_gizli._guncel_satir(r.tablo_adi, r.satir_pk);
    IF e.islem = 'D' THEN
      IF v_cur IS NOT NULL THEN
        v_cak := v_cak || jsonb_strip_nulls(jsonb_build_object(
          'tablo', r.tablo_adi, 'pk', surum_gizli._pk_gorunum(r.satir_pk), 'satir_pk', r.satir_pk,
          'neden', 'GUNCEL_DURUM_FARKLI'));
      END IF;
    ELSE
      v_fields := CASE WHEN p_seviye = 'alan' THEN ARRAY[v_alan]
                       ELSE ARRAY(SELECT jsonb_object_keys(e.yeni)) END;
      IF v_cur IS NULL OR EXISTS (
           SELECT 1 FROM unnest(v_fields) f
            WHERE f <> ALL (c_teknik) AND v_cur ? f
              AND (v_cur -> f) IS DISTINCT FROM (e.yeni -> f)) THEN
        v_cak := v_cak || jsonb_strip_nulls(jsonb_build_object(
          'tablo', r.tablo_adi, 'pk', surum_gizli._pk_gorunum(r.satir_pk), 'satir_pk', r.satir_pk,
          'alan', v_alan, 'neden', 'GUNCEL_DURUM_FARKLI'));
      END IF;
    END IF;
  END LOOP;

  SELECT v_eng || coalesce(array_agg(format('%s kaydı %s: %s', c ->> 'tablo', c -> 'pk', c ->> 'neden')), '{}')
    INTO v_eng FROM jsonb_array_elements(v_cak) c;

  -- ── 4. stock advisories (informational, never blocking) ──
  IF p_seviye <> 'islem' THEN
    FOR e IN
      SELECT * FROM public.degisim_log
       WHERE txid = v_txid AND tablo_adi = 'stok_hareket' AND id <> ALL (v_ids)
    LOOP
      v_stok := v_stok || jsonb_build_object(
        'stok_id', coalesce(e.yeni, e.eski) ->> 'stok_id',
        'metin', format('Aynı işlemdeki stok hareketi (%s) bu geri almaya dahil değil; stok elle kontrol edilmeli',
                        e.satir_pk ->> 'id'));
    END LOOP;
  END IF;
  FOR r IN
    SELECT DISTINCT tablo_adi, satir_pk FROM public.degisim_log
     WHERE id = ANY (v_ids) AND tablo_adi <> 'stok_hareket'
       AND (SELECT count(*) FROM jsonb_object_keys(satir_pk)) = 1
  LOOP
    FOR e IN
      SELECT * FROM public.degisim_log l
       WHERE l.tablo_adi = 'stok_hareket' AND l.id <> ALL (v_ids)
         AND coalesce(l.yeni, l.eski) ->> 'referans_id' = (SELECT v #>> '{}' FROM jsonb_each(r.satir_pk) AS x(k, v))
    LOOP
      v_stok := v_stok || jsonb_build_object(
        'stok_id', coalesce(e.yeni, e.eski) ->> 'stok_id',
        'metin', format('%s kaydına bağlı stok hareketi (txid %s) bu geri almaya dahil değil; stok elle kontrol edilmeli',
                        r.tablo_adi, e.txid));
    END LOOP;
  END LOOP;

  -- ── 5. plan steps ──
  -- EKLE steps (reverting DELETEs) are topologically ordered parents-first:
  -- cascade children carry HIGHER log ids than the parent, so plain id-DESC
  -- would re-insert the child before its parent (FK 23503, deterministic
  -- failure), and explicit multi-delete transactions can break plain id-ASC
  -- too. U/SIL steps keep reverse log order (undo-last-first). Kahn's
  -- algorithm over the plan-local FK graph; on an impossible cycle fall
  -- back to id order for the remainder.
  SELECT coalesce(array_agg(x ORDER BY x.id), ARRAY[]::public.degisim_log[])
    INTO v_ekle
    FROM public.degisim_log x
   WHERE x.id = ANY (v_ids) AND x.islem = 'D';
  SELECT coalesce(array_agg(x ORDER BY x.id DESC), ARRAY[]::public.degisim_log[])
    INTO v_sirali
    FROM public.degisim_log x
   WHERE x.id = ANY (v_ids) AND x.islem <> 'D';

  v_n := coalesce(cardinality(v_ekle), 0);
  IF v_n > 0 THEN
    v_derece := array_fill(0, ARRAY[v_n]);
    v_cikti  := array_fill(false, ARRAY[v_n]);
    FOR i IN 1 .. v_n LOOP
      FOR j IN 1 .. v_n LOOP
        CONTINUE WHEN i = j;
        IF surum_gizli._ekle_bagli(v_ekle[j], v_ekle[i]) THEN   -- i depends on j
          v_derece[i] := v_derece[i] + 1;
        END IF;
      END LOOP;
    END LOOP;
    v_kalan := v_n;
    WHILE v_kalan > 0 LOOP
      v_bulundu := false;
      FOR i IN 1 .. v_n LOOP
        CONTINUE WHEN v_cikti[i] OR v_derece[i] > 0;
        v_cikti[i] := true;
        v_kalan := v_kalan - 1;
        v_bulundu := true;
        v_topo := v_topo || v_ekle[i];
        FOR j IN 1 .. v_n LOOP
          CONTINUE WHEN v_cikti[j];
          IF surum_gizli._ekle_bagli(v_ekle[i], v_ekle[j]) THEN
            v_derece[j] := v_derece[j] - 1;
          END IF;
        END LOOP;
        EXIT;
      END LOOP;
      IF NOT v_bulundu THEN   -- cycle: emit remaining in id order
        FOR i IN 1 .. v_n LOOP
          CONTINUE WHEN v_cikti[i];
          v_cikti[i] := true;
          v_kalan := v_kalan - 1;
          v_topo := v_topo || v_ekle[i];
        END LOOP;
      END IF;
    END LOOP;
    v_sirali := v_topo || v_sirali;
  END IF;

  -- cascade children erased together with a parent whose DELETE is being
  -- reverted only partially (satir-level on the parent): they stay gone —
  -- informational, never blocking
  IF p_seviye <> 'islem' THEN
    FOR e IN SELECT * FROM public.degisim_log WHERE id = ANY (v_ids) AND islem = 'D' LOOP
      FOR ch IN
        SELECT c.* FROM public.degisim_log c
         WHERE c.txid = e.txid AND c.islem = 'D' AND c.id <> ALL (v_ids)
           AND surum_gizli._ekle_bagli(e, c)
      LOOP
        v_bag := v_bag || jsonb_build_object(
          'tablo', ch.tablo_adi, 'pk', surum_gizli._pk_gorunum(ch.satir_pk), 'satir_pk', ch.satir_pk,
          'iliski', format('%s kaydı %s ile aynı işlemde silinmiş ve bu geri almaya dahil değil',
                           ch.tablo_adi, e.tablo_adi),
          'etki', 'UYARI');
      END LOOP;
    END LOOP;
  END IF;

  FOREACH e IN ARRAY v_sirali LOOP
    v_sira := v_sira + 1;
    v_fields := CASE WHEN e.islem <> 'U' THEN NULL
                     WHEN p_seviye = 'alan' THEN ARRAY[v_alan]
                     ELSE e.degisen_alanlar END;
    v_plan := v_plan || jsonb_build_object(
      'sira', v_sira,
      'log_id', e.id,
      'txid', e.txid::text,
      'tablo', e.tablo_adi,
      'pk', surum_gizli._pk_gorunum(e.satir_pk),
      'satir_pk', e.satir_pk,
      'islem', e.islem,
      'alanlar', to_jsonb(v_fields),
      'eski', CASE e.islem WHEN 'U' THEN (SELECT jsonb_object_agg(f, e.eski -> f) FROM unnest(v_fields) f)
                           WHEN 'D' THEN e.eski END,
      'yeni', CASE e.islem WHEN 'U' THEN (SELECT jsonb_object_agg(f, e.yeni -> f) FROM unnest(v_fields) f)
                           WHEN 'I' THEN e.yeni END,
      'yapilacak', CASE e.islem WHEN 'U' THEN 'GUNCELLE' WHEN 'I' THEN 'SIL' ELSE 'EKLE' END);
  END LOOP;

  RETURN jsonb_build_object(
    'ok', true,
    'seviye', p_seviye,
    'hedef', jsonb_strip_nulls(jsonb_build_object(
               'txid', v_txid::text, 'tablo', v_tablo,
               'pk', CASE WHEN v_pk IS NOT NULL THEN surum_gizli._pk_gorunum(v_pk) END,
               'satir_pk', v_pk, 'alan', v_alan)),
    'plan', v_plan,
    'cakismalar', v_cak,
    'bagimliliklar', v_bag,
    'stok_uyari', v_stok,
    'geri_alinabilir', jsonb_array_length(v_cak) = 0 AND cardinality(v_eng) = 0
                       AND jsonb_array_length(v_plan) > 0,
    'engeller', to_jsonb(v_eng));
END;
$$;

-- ── executor: applies plan steps in order; every step must hit one row ─────
CREATE OR REPLACE FUNCTION surum_gizli._degisim_uygula(p_plan jsonb)
RETURNS int
LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
DECLARE
  s      record;
  v_pkc  text;
  v_cols text;
  v_n    int;
  v_top  int := 0;
BEGIN
  FOR s IN
    SELECT * FROM jsonb_to_recordset(p_plan)
      AS x(sira int, tablo text, satir_pk jsonb, islem text, alanlar text[], eski jsonb)
     ORDER BY sira
  LOOP
    v_pkc := surum_gizli._pk_kolonlar(s.tablo);
    IF s.islem = 'U' THEN
      SELECT string_agg(quote_ident(f), ', ') INTO v_cols
        FROM unnest(s.alanlar) f
       WHERE EXISTS (SELECT 1 FROM pg_attribute a
                      WHERE a.attrelid = format('public.%I', s.tablo)::regclass
                        AND a.attname = f AND a.attnum > 0 AND NOT a.attisdropped);
      EXECUTE format(
        'UPDATE public.%1$I SET (%2$s) = (SELECT %2$s FROM jsonb_populate_record(NULL::public.%1$I, $1)) '
        'WHERE (%3$s) = (SELECT %3$s FROM jsonb_populate_record(NULL::public.%1$I, $2))',
        s.tablo, v_cols, v_pkc) USING s.eski, s.satir_pk;
    ELSIF s.islem = 'I' THEN
      EXECUTE format(
        'DELETE FROM public.%1$I WHERE (%2$s) = (SELECT %2$s FROM jsonb_populate_record(NULL::public.%1$I, $1))',
        s.tablo, v_pkc) USING s.satir_pk;
    ELSE
      SELECT string_agg(quote_ident(a.attname), ', ' ORDER BY a.attnum) INTO v_cols
        FROM pg_attribute a
       WHERE a.attrelid = format('public.%I', s.tablo)::regclass
         AND a.attnum > 0 AND NOT a.attisdropped AND a.attgenerated = ''
         AND a.attidentity <> 'a' AND s.eski ? a.attname;
      EXECUTE format(
        'INSERT INTO public.%1$I (%2$s) SELECT %2$s FROM jsonb_populate_record(NULL::public.%1$I, $1)',
        s.tablo, v_cols) USING s.eski;
    END IF;
    GET DIAGNOSTICS v_n = ROW_COUNT;
    IF v_n <> 1 THEN
      RAISE EXCEPTION 'geri alma adımı % (% %) % satır etkiledi, 1 bekleniyordu', s.sira, s.tablo, s.satir_pk, v_n;
    END IF;
    v_top := v_top + 1;
  END LOOP;
  RETURN v_top;
END;
$$;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA surum_gizli FROM PUBLIC, anon, authenticated;

-- ── public RPCs ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.geri_alma_bileti_al(p_sifre text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_hash text;
  v_b    surum_gizli.geri_alma_bileti;
BEGIN
  SELECT hash INTO v_hash FROM surum_gizli.sahip_sifresi WHERE id = 1;
  IF v_hash IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'SIFRE_AYARLI_DEGIL');
  END IF;
  IF p_sifre IS NULL OR extensions.crypt(p_sifre, v_hash) IS DISTINCT FROM v_hash THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'SIFRE_HATALI');
  END IF;

  INSERT INTO surum_gizli.geri_alma_bileti (son_gecerlilik, kaynak)
  VALUES (now() + interval '1 hour', surum_gizli._cagiran())
  RETURNING * INTO v_b;

  RETURN jsonb_build_object(
    'ok', true,
    'bilet', v_b.bilet,
    'olusturma', v_b.olusturma,
    'son_gecerlilik', v_b.son_gecerlilik,
    'kalan_sn', greatest(0, floor(extract(epoch FROM v_b.son_gecerlilik - now())))::int);
END;
$$;

CREATE OR REPLACE FUNCTION public.degisim_listele(p_filtre jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  f        jsonb := coalesce(p_filtre, '{}'::jsonb);
  v_txid   bigint;
  v_sayfa  int;
  v_adet   int;
  v_bas    timestamptz;
  v_bit    timestamptz;
  v_hayvan text := nullif(f ->> 'hayvan_id', '');
  v_tablo  text := nullif(f ->> 'tablo', '');
  v_islem  text := nullif(f ->> 'islem', '');
  v_toplam bigint;
  v_liste  jsonb;
BEGIN
  BEGIN
    v_txid  := nullif(f ->> 'txid', '')::bigint;
    v_sayfa := greatest(coalesce(nullif(f ->> 'sayfa', '')::int, 1), 1);
    v_adet  := least(greatest(coalesce(nullif(f ->> 'adet', '')::int, 50), 1), 200);
    -- day bounds are Turkey calendar days (UI date filter is gg.aa.yyyy)
    v_bas := (nullif(f ->> 'baslangic', '')::date)::timestamp AT TIME ZONE 'Europe/Istanbul';
    v_bit := ((nullif(f ->> 'bitis', '')::date) + 1)::timestamp AT TIME ZONE 'Europe/Istanbul';
  EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'GECERSIZ_FILTRE');
  END;

  IF v_txid IS NOT NULL THEN
    RETURN jsonb_build_object(
      'ok', true,
      'detay', true,
      'kayitlar', coalesce((
        SELECT jsonb_agg(jsonb_build_object(
                 'id', id, 'txid', txid::text, 'zaman', kayit_zamani,
                 'tablo_adi', tablo_adi, 'satir_pk', satir_pk, 'islem', islem,
                 'eski', eski, 'yeni', yeni, 'degisen_alanlar', degisen_alanlar,
                 'teknikal_mi', teknikal_mi, 'kaynak', kaynak) ORDER BY id)
          FROM public.degisim_log WHERE txid = v_txid), '[]'::jsonb));
  END IF;

  WITH eslesen AS (
    SELECT DISTINCT l.txid
      FROM public.degisim_log l
     WHERE (v_bas IS NULL OR l.kayit_zamani >= v_bas)
       AND (v_bit IS NULL OR l.kayit_zamani < v_bit)
       AND (v_tablo IS NULL OR l.tablo_adi = v_tablo)
       AND (v_islem IS NULL OR l.islem = v_islem)
       AND (v_hayvan IS NULL
            OR (l.tablo_adi = 'hayvanlar' AND l.satir_pk ->> 'id' = v_hayvan)
            OR EXISTS (SELECT 1
                         FROM unnest(ARRAY['hayvan_id','anne_id','buzagi_id','animal_id',
                                           'farm_animal_id','ana_hayvan_id']) k
                        WHERE coalesce(l.yeni, l.eski) ->> k = v_hayvan))
  ), gruplar AS (
    SELECT l.txid,
           min(l.kayit_zamani) AS ilk_zaman,
           min(l.id) AS ilk_id,
           count(DISTINCT l.tablo_adi) AS tablo_sayisi,
           count(*) AS satir_sayisi,
           count(*) FILTER (WHERE l.islem = 'I') AS n_i,
           count(*) FILTER (WHERE l.islem = 'U') AS n_u,
           count(*) FILTER (WHERE l.islem = 'D') AS n_d,
           bool_and(l.teknikal_mi) AS teknik,
           bool_or(l.kaynak ? 'geri_alma') AS geri_alma
      FROM public.degisim_log l JOIN eslesen USING (txid)
     GROUP BY l.txid
  ), sayfa AS (
    SELECT g.*, count(*) OVER () AS toplam
      FROM gruplar g
     ORDER BY g.ilk_zaman DESC, g.txid DESC
     OFFSET (v_sayfa - 1) * v_adet LIMIT v_adet
  )
  SELECT max(s.toplam),
         jsonb_agg(jsonb_build_object(
           'txid', s.txid::text,
           'ilk_zaman', s.ilk_zaman,
           'ozet', jsonb_build_object(
             'tablo_sayisi', s.tablo_sayisi,
             'satir_sayisi', s.satir_sayisi,
             'islemler', jsonb_build_object('I', s.n_i, 'U', s.n_u, 'D', s.n_d),
             'baslik', (SELECT string_agg(format('%s (%s)', t.tablo_adi, t.n), ', ' ORDER BY t.n DESC, t.tablo_adi)
                          FROM (SELECT tablo_adi, count(*) AS n FROM public.degisim_log
                                 WHERE txid = s.txid GROUP BY 1) t),
             'teknik', s.teknik,
             'geri_alma', s.geri_alma),
           'kaynak', (SELECT kaynak FROM public.degisim_log WHERE id = s.ilk_id))
           ORDER BY s.ilk_zaman DESC, s.txid DESC)
    INTO v_toplam, v_liste
    FROM sayfa s;

  -- an OFFSET past the end returns no rows, so count separately then
  IF v_toplam IS NULL THEN
    WITH eslesen AS (
      SELECT DISTINCT l.txid FROM public.degisim_log l
       WHERE (v_bas IS NULL OR l.kayit_zamani >= v_bas)
         AND (v_bit IS NULL OR l.kayit_zamani < v_bit)
         AND (v_tablo IS NULL OR l.tablo_adi = v_tablo)
         AND (v_islem IS NULL OR l.islem = v_islem)
         AND (v_hayvan IS NULL
              OR (l.tablo_adi = 'hayvanlar' AND l.satir_pk ->> 'id' = v_hayvan)
              OR EXISTS (SELECT 1
                           FROM unnest(ARRAY['hayvan_id','anne_id','buzagi_id','animal_id',
                                             'farm_animal_id','ana_hayvan_id']) k
                          WHERE coalesce(l.yeni, l.eski) ->> k = v_hayvan)))
    SELECT count(*) INTO v_toplam FROM eslesen;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'kayitlar', coalesce(v_liste, '[]'::jsonb),
    'toplam', v_toplam,
    'sayfa', v_sayfa,
    'adet', v_adet);
END;
$$;

CREATE OR REPLACE FUNCTION public.degisim_onizle(p_hedef jsonb, p_seviye text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  RETURN surum_gizli._degisim_plan(p_hedef, p_seviye);
END;
$$;

CREATE OR REPLACE FUNCTION public.degisim_geri_al(p_hedef jsonb, p_seviye text, p_bilet uuid,
                                                  p_gerekce text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_b    surum_gizli.geri_alma_bileti;
  v_plan jsonb;
  v_res  jsonb;
  v_n    int;
  s      record;
BEGIN
  IF p_bilet IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'BILET_GECERSIZ', 'detay', '{}'::jsonb);
  END IF;
  SELECT * INTO v_b FROM surum_gizli.geri_alma_bileti WHERE bilet = p_bilet;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'BILET_GECERSIZ', 'detay', '{}'::jsonb);
  END IF;
  IF v_b.son_gecerlilik <= clock_timestamp() THEN
    v_res := jsonb_build_object('ok', false, 'hata', 'BILET_SURESI_DOLMUS',
                                'detay', jsonb_build_object('son_gecerlilik', v_b.son_gecerlilik));
    INSERT INTO surum_gizli.geri_alma_kullanim (bilet, hedef, seviye, gerekce, sonuc, kaynak)
    VALUES (p_bilet, p_hedef, p_seviye, p_gerekce, v_res, surum_gizli._cagiran());
    RETURN v_res;
  END IF;

  -- serialize reverts; plan, lock the rows it touches, then re-plan so the
  -- conflict check runs against locked, current state (race-safe). The lock
  -- and re-plan sit in their own subtransaction: a deadlock/timeout there
  -- returns ok:false instead of escaping (which would skip the usage record).
  PERFORM pg_advisory_xact_lock(hashtext('degisim_geri_al'));
  v_plan := surum_gizli._degisim_plan(p_hedef, p_seviye);
  IF (v_plan ->> 'ok')::boolean THEN
    BEGIN
      FOR s IN
        SELECT DISTINCT x.tablo, x.satir_pk FROM jsonb_to_recordset(v_plan -> 'plan') AS x(tablo text, satir_pk jsonb)
      LOOP
        EXECUTE format('SELECT 1 FROM public.%1$I WHERE (%2$s) = (SELECT %2$s FROM jsonb_populate_record(NULL::public.%1$I, $1)) FOR UPDATE',
                       s.tablo, surum_gizli._pk_kolonlar(s.tablo)) USING s.satir_pk;
      END LOOP;
      v_plan := surum_gizli._degisim_plan(p_hedef, p_seviye);
    EXCEPTION WHEN others THEN
      v_res := jsonb_build_object('ok', false, 'hata', 'UYGULAMA_HATASI',
                                  'detay', jsonb_build_object('asama', 'KILIT_PLAN',
                                                              'sqlstate', SQLSTATE, 'mesaj', SQLERRM));
    END;
  END IF;

  IF v_res IS NOT NULL THEN
    NULL;  -- lock/plan phase already failed; fall through to the usage record
  ELSIF NOT (v_plan ->> 'ok')::boolean THEN
    v_res := jsonb_build_object('ok', false, 'hata', v_plan ->> 'hata', 'detay', '{}'::jsonb);
  ELSIF jsonb_array_length(v_plan -> 'cakismalar') > 0 THEN
    v_res := jsonb_build_object('ok', false, 'hata', 'CAKISMA',
                                'detay', jsonb_build_object('cakismalar', v_plan -> 'cakismalar',
                                                            'engeller', v_plan -> 'engeller'));
  ELSIF NOT (v_plan ->> 'geri_alinabilir')::boolean
        AND jsonb_array_length(v_plan -> 'plan') > 0 THEN
    v_res := jsonb_build_object('ok', false, 'hata', 'BAGIMLILIK_ENGELI',
                                'detay', jsonb_build_object('bagimliliklar', v_plan -> 'bagimliliklar',
                                                            'engeller', v_plan -> 'engeller'));
  ELSIF jsonb_array_length(v_plan -> 'plan') = 0 THEN
    v_res := jsonb_build_object('ok', false, 'hata', 'HEDEF_BULUNAMADI', 'detay', '{}'::jsonb);
  ELSE
    PERFORM set_config('app.geri_alma_bileti', p_bilet::text, true);
    PERFORM set_config('app.geri_alma_gerekce', coalesce(p_gerekce, ''), true);
    BEGIN
      v_n := surum_gizli._degisim_uygula(v_plan -> 'plan');
      v_res := jsonb_build_object('ok', true, 'geri_alma_txid', txid_current()::text,
                                  'uygulanan_adim', v_n);
    EXCEPTION WHEN others THEN
      -- a business trigger/constraint refused a step: nothing was applied
      v_res := jsonb_build_object('ok', false, 'hata', 'UYGULAMA_HATASI',
                                  'detay', jsonb_build_object('sqlstate', SQLSTATE, 'mesaj', SQLERRM));
    END;
    PERFORM set_config('app.geri_alma_bileti', '', true);
    PERFORM set_config('app.geri_alma_gerekce', '', true);
  END IF;

  INSERT INTO surum_gizli.geri_alma_kullanim (bilet, hedef, seviye, gerekce, sonuc, geri_alma_txid, kaynak)
  VALUES (p_bilet, p_hedef, p_seviye, p_gerekce, v_res,
          CASE WHEN (v_res ->> 'ok')::boolean THEN txid_current() END,
          surum_gizli._cagiran());
  RETURN v_res;
END;
$$;

-- Functions get EXECUTE for PUBLIC by default; close that, open authenticated.
REVOKE ALL ON FUNCTION public.geri_alma_bileti_al(text)                  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.degisim_listele(jsonb)                     FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.degisim_onizle(jsonb, text)                FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.degisim_geri_al(jsonb, text, uuid, text)   FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.geri_alma_bileti_al(text)                TO authenticated;
GRANT EXECUTE ON FUNCTION public.degisim_listele(jsonb)                   TO authenticated;
GRANT EXECUTE ON FUNCTION public.degisim_onizle(jsonb, text)              TO authenticated;
GRANT EXECUTE ON FUNCTION public.degisim_geri_al(jsonb, text, uuid, text) TO authenticated;

COMMIT;
