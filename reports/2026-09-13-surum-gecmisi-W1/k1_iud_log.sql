-- Acceptance 1 (G-20260913-SURUM-GECMISI): for EVERY table carrying
-- trg_degisim_log, prove
--   I -> one 'I' row, U -> one 'U' row naming the changed column,
--   D -> one 'D' row with the full old row, content-free U -> no row.
-- Also proves the kaynak stamp (caller role, jwt sub) under PostgREST-like
-- SET ROLE + request.jwt.claims.
-- One transaction, ROLLED BACK at the end: demo data is left untouched.
--
-- Run: dpsql -f reports/2026-09-13-surum-gecmisi-W1/k1_iud_log.sql
\set ON_ERROR_STOP 1
BEGIN;

CREATE TEMP TABLE k1 (tablo text, adim text, beklenen text, bulunan text, sonuc text, detay text);

DO $k1$
DECLARE
  t         text;
  v_rel     regclass;
  v_pkcols  text[];
  v_where   text;
  v_pk      jsonb;
  r         jsonb;
  v_j       jsonb;
  v_val     jsonb;
  v_mark    bigint;
  v_n       int;
  v_rows    int;
  v_bos     boolean;
  v_done    boolean;
  v_cols    text;
  v_alan    text;
  v_expr    text;
  c         record;
  i         int;
BEGIN
  FOR t IN
    SELECT cl.relname FROM pg_trigger g JOIN pg_class cl ON cl.oid = g.tgrelid
     WHERE g.tgname = 'trg_degisim_log' ORDER BY 1
  LOOP
    v_rel := format('public.%I', t)::regclass;
    SELECT array_agg(a.attname::text ORDER BY k.ord) INTO v_pkcols
      FROM pg_constraint co
      CROSS JOIN LATERAL unnest(co.conkey) WITH ORDINALITY AS k(attnum, ord)
      JOIN pg_attribute a ON a.attrelid = co.conrelid AND a.attnum = k.attnum
     WHERE co.conrelid = v_rel AND co.contype = 'p';

    -- Prefer a fresh synthetic row (no children, so D is FK-safe); fall back
    -- to an existing row when synthesis is refused (unique/composite PK...).
    -- v_bos = "synthetic path taken".
    r := NULL;
    v_bos := true;
    IF v_bos THEN
      v_j := '{}'::jsonb;
      FOR c IN
        SELECT a.attname::text AS col, a.atttypid::regtype::text AS typ,
               (SELECT format('SELECT to_jsonb(%I) FROM %s WHERE %I IS NOT NULL LIMIT 1',
                              pa.attname, f.confrelid::regclass, pa.attname)
                  FROM pg_constraint f
                  JOIN pg_attribute pa ON pa.attrelid = f.confrelid
                   AND pa.attnum = f.confkey[array_position(f.conkey, a.attnum)]
                 WHERE f.conrelid = a.attrelid AND f.contype = 'f'
                   AND a.attnum = ANY (f.conkey) LIMIT 1) AS fkq
          FROM pg_attribute a
         WHERE a.attrelid = v_rel AND a.attnum > 0 AND NOT a.attisdropped
           AND a.attnotnull AND NOT a.atthasdef AND a.attidentity = ''
      LOOP
        IF c.fkq IS NOT NULL THEN
          EXECUTE c.fkq INTO v_val;
        ELSE
          v_val := CASE
            WHEN c.typ IN ('text', 'character varying') THEN to_jsonb('k1_' || gen_random_uuid()::text)
            WHEN c.typ = 'uuid' THEN to_jsonb(gen_random_uuid())
            WHEN c.typ IN ('integer','bigint','smallint','numeric','double precision','real') THEN '1'::jsonb
            WHEN c.typ = 'boolean' THEN 'false'::jsonb
            WHEN c.typ = 'date' THEN to_jsonb(current_date)
            WHEN c.typ LIKE 'timestamp%' THEN to_jsonb(now())
            WHEN c.typ IN ('json','jsonb') THEN '{}'::jsonb
          END;
        END IF;
        v_j := v_j || jsonb_build_object(c.col, v_val);
      END LOOP;

      SELECT max(id) INTO v_mark FROM public.degisim_log;
      v_mark := coalesce(v_mark, 0);
      BEGIN
        IF v_j = '{}'::jsonb THEN
          EXECUTE format('INSERT INTO public.%I DEFAULT VALUES RETURNING to_jsonb(%I.*)', t, t) INTO r;
        ELSE
          SELECT string_agg(quote_ident(k), ', ') INTO v_cols FROM jsonb_object_keys(v_j) k;
          EXECUTE format('INSERT INTO public.%I (%s) SELECT %s FROM jsonb_populate_record(NULL::public.%I, $1) RETURNING to_jsonb(%I.*)',
                         t, v_cols, v_cols, t, t) USING v_j INTO r;
        END IF;
        SELECT jsonb_object_agg(pc, r -> pc) INTO v_pk FROM unnest(v_pkcols) pc;
        SELECT count(*) INTO v_n FROM public.degisim_log
         WHERE id > v_mark AND tablo_adi = t AND islem = 'I' AND satir_pk = v_pk AND eski IS NULL AND yeni = r;
        INSERT INTO k1 VALUES (t, '1_I_sentetik', '1', v_n::text, CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END, v_pk::text);
      EXCEPTION WHEN others THEN
        v_bos := false;
        EXECUTE format('SELECT to_jsonb(x) FROM public.%I x LIMIT 1', t) INTO r;
        IF r IS NULL THEN
          INSERT INTO k1 VALUES (t, '1_I_sentetik', '1', 'hata', 'FAIL', SQLSTATE || ' ' || SQLERRM);
          CONTINUE;
        END IF;
      END;
    END IF;

    SELECT jsonb_object_agg(pc, r -> pc) INTO v_pk FROM unnest(v_pkcols) pc;
    SELECT string_agg(format('%I::text = %L', pc, r ->> pc), ' AND ') INTO v_where FROM unnest(v_pkcols) pc;

    -- ── content-free UPDATE → no record ──
    SELECT coalesce(max(id), 0) INTO v_mark FROM public.degisim_log;
    BEGIN
      EXECUTE format('UPDATE public.%I SET %I = %I WHERE %s', t, v_pkcols[1], v_pkcols[1], v_where);
      GET DIAGNOSTICS v_rows = ROW_COUNT;
      SELECT count(*) INTO v_n FROM public.degisim_log
       WHERE id > v_mark AND tablo_adi = t AND satir_pk = v_pk AND NOT teknikal_mi;
      SELECT count(*) INTO v_rows FROM public.degisim_log
       WHERE id > v_mark AND tablo_adi = t AND satir_pk = v_pk AND teknikal_mi;
      INSERT INTO k1 VALUES (t, '2_U_bos', '0', v_n::text,
        CASE WHEN v_n = 0 THEN 'PASS' ELSE 'FAIL' END,
        CASE WHEN v_rows > 0 THEN 'teknik-only rows=' || v_rows ELSE '' END);
    EXCEPTION WHEN others THEN
      INSERT INTO k1 VALUES (t, '2_U_bos', '0', 'hata', 'FAIL', SQLSTATE || ' ' || SQLERRM);
    END;

    -- ── real UPDATE on first column that accepts a change ──
    v_done := false;
    FOR c IN
      SELECT a.attname::text AS col, a.atttypid::regtype::text AS typ
        FROM pg_attribute a
       WHERE a.attrelid = v_rel AND a.attnum > 0 AND NOT a.attisdropped
         AND a.attgenerated = '' AND a.attname <> ALL (v_pkcols)
         AND a.attname NOT IN ('created_at','updated_at','olusturma','guncelleme','guncelleme_tarihi','guncellendi')
         AND NOT EXISTS (SELECT 1 FROM pg_constraint f WHERE f.conrelid = v_rel AND f.contype = 'f' AND a.attnum = ANY (f.conkey))
       ORDER BY CASE WHEN a.atttypid::regtype::text IN ('text','character varying') THEN 0
                     WHEN a.atttypid::regtype::text IN ('integer','bigint','smallint','numeric') THEN 1
                     WHEN a.atttypid::regtype::text = 'boolean' THEN 2 ELSE 3 END, a.attnum
    LOOP
      v_expr := CASE
        WHEN c.typ IN ('text','character varying') THEN format('coalesce(%I, %L) || %L', c.col, '', '~k1')
        WHEN c.typ IN ('integer','bigint','smallint','numeric') THEN format('coalesce(%I, 0) + 1', c.col)
        WHEN c.typ = 'boolean' THEN format('NOT coalesce(%I, false)', c.col)
        WHEN c.typ = 'date' THEN format('coalesce(%I, current_date) + 1', c.col)
      END;
      CONTINUE WHEN v_expr IS NULL;
      SELECT coalesce(max(id), 0) INTO v_mark FROM public.degisim_log;
      BEGIN
        EXECUTE format('UPDATE public.%I SET %I = %s WHERE %s', t, c.col, v_expr, v_where);
        GET DIAGNOSTICS v_rows = ROW_COUNT;
        IF v_rows = 1 THEN
          SELECT count(*) INTO v_n FROM public.degisim_log
           WHERE id > v_mark AND tablo_adi = t AND islem = 'U' AND satir_pk = v_pk
             AND c.col = ANY (degisen_alanlar) AND eski IS NOT NULL AND yeni IS NOT NULL
             AND NOT teknikal_mi;
          INSERT INTO k1 VALUES (t, '3_U', '1', v_n::text, CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END, 'alan=' || c.col);
          v_done := true;
          EXIT;
        END IF;
      EXCEPTION WHEN others THEN
        NULL;  -- constraint/guard refused this column; try the next one
      END;
    END LOOP;
    -- Fallback for tables whose every column is PK/FK (e.g. vaccine_diseases):
    -- move one FK column to another valid referenced value. If that column is
    -- part of the PK, satir_pk follows the NEW key.
    IF NOT v_done THEN
      FOR c IN
        SELECT a.attname::text AS col, pa.attname::text AS refcol, f.confrelid::regclass::text AS reftab
          FROM pg_attribute a
          JOIN pg_constraint f ON f.conrelid = v_rel AND f.contype = 'f' AND a.attnum = ANY (f.conkey)
          JOIN pg_attribute pa ON pa.attrelid = f.confrelid
           AND pa.attnum = f.confkey[array_position(f.conkey, a.attnum)]
         WHERE a.attrelid = v_rel AND a.attname <> 'farm_id'
      LOOP
        FOR i IN 1 .. 5 LOOP
          SELECT coalesce(max(id), 0) INTO v_mark FROM public.degisim_log;
          BEGIN
            EXECUTE format('UPDATE public.%I x SET %I = (SELECT %I FROM %s WHERE %I IS DISTINCT FROM %L ORDER BY random() LIMIT 1) WHERE %s RETURNING to_jsonb(x.*)',
                           t, c.col, c.refcol, c.reftab, c.refcol, r ->> c.col, v_where) INTO v_j;
            CONTINUE WHEN v_j IS NULL;
            SELECT jsonb_object_agg(pc, v_j -> pc) INTO v_pk FROM unnest(v_pkcols) pc;
            SELECT count(*) INTO v_n FROM public.degisim_log
             WHERE id > v_mark AND tablo_adi = t AND islem = 'U' AND satir_pk = v_pk
               AND c.col = ANY (degisen_alanlar);
            INSERT INTO k1 VALUES (t, '3_U', '1', v_n::text, CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END,
                                   'alan=' || c.col || ' (FK fallback)');
            r := v_j;
            SELECT string_agg(format('%I::text = %L', pc, r ->> pc), ' AND ') INTO v_where FROM unnest(v_pkcols) pc;
            v_done := true;
            EXIT;
          EXCEPTION WHEN others THEN
            NULL;
          END;
        END LOOP;
        EXIT WHEN v_done;
      END LOOP;
    END IF;
    IF NOT v_done THEN
      INSERT INTO k1 VALUES (t, '3_U', '1', 'yok', 'FAIL', 'no column accepted an update');
    END IF;

    -- ── DELETE → full old row ──
    SELECT coalesce(max(id), 0) INTO v_mark FROM public.degisim_log;
    BEGIN
      EXECUTE format('SELECT to_jsonb(x) FROM public.%I x WHERE %s', t, v_where) INTO v_j;
      EXECUTE format('DELETE FROM public.%I WHERE %s', t, v_where);
      SELECT count(*) INTO v_n FROM public.degisim_log
       WHERE id > v_mark AND tablo_adi = t AND islem = 'D' AND satir_pk = v_pk
         AND eski = v_j AND yeni IS NULL;
      INSERT INTO k1 VALUES (t, '4_D', '1', v_n::text, CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END, '');
    EXCEPTION WHEN others THEN
      INSERT INTO k1 VALUES (t, '4_D', '1', 'hata', 'FAIL', SQLSTATE || ' ' || SQLERRM);
      CONTINUE;
    END;

    -- ── INSERT (re-insert the original row) for non-empty tables ──
    IF NOT v_bos THEN
      SELECT coalesce(max(id), 0) INTO v_mark FROM public.degisim_log;
      BEGIN
        SELECT string_agg(quote_ident(k), ', ') INTO v_cols FROM jsonb_object_keys(r) k;
        EXECUTE format('INSERT INTO public.%I (%s) SELECT %s FROM jsonb_populate_record(NULL::public.%I, $1)',
                       t, v_cols, v_cols, t) USING r;
        SELECT count(*) INTO v_n FROM public.degisim_log
         WHERE id > v_mark AND tablo_adi = t AND islem = 'I' AND satir_pk = v_pk AND eski IS NULL;
        INSERT INTO k1 VALUES (t, '1_I', '1', v_n::text, CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END, '');
      EXCEPTION WHEN others THEN
        INSERT INTO k1 VALUES (t, '1_I', '1', 'hata', 'FAIL', SQLSTATE || ' ' || SQLERRM);
      END;
    END IF;
  END LOOP;
END;
$k1$;

\echo '== per-step results =='
SELECT tablo, adim, beklenen, bulunan, sonuc, detay FROM k1 ORDER BY tablo, adim;

\echo '== summary =='
SELECT count(DISTINCT tablo) AS tablo_sayisi,
       count(*) FILTER (WHERE sonuc = 'PASS') AS pass,
       count(*) FILTER (WHERE sonuc <> 'PASS') AS fail
  FROM k1;
SELECT tablo FROM k1 GROUP BY tablo
HAVING count(DISTINCT left(adim, 1)) FILTER (WHERE sonuc = 'PASS') < 4;

\echo '== kaynak stamp under PostgREST-like caller =='
SELECT set_config('request.jwt.claims', '{"sub":"k1-test-sub","role":"authenticated"}', true);
SELECT set_config('app.istemci_etiketi', 'k1-betik', true);
SET LOCAL ROLE authenticated;
UPDATE public.hekimler SET telefon = coalesce(telefon, '') || '~kaynak'
 WHERE id = (SELECT id FROM public.hekimler ORDER BY id LIMIT 1);
RESET ROLE;
SELECT islem, degisen_alanlar, kaynak FROM public.degisim_log
 WHERE txid = txid_current() AND tablo_adi = 'hekimler' ORDER BY id DESC LIMIT 1;

\echo '== single txid for the whole script transaction =='
SELECT count(DISTINCT txid) AS distinct_txid, count(*) AS rows_in_tx
  FROM public.degisim_log WHERE txid = txid_current();

ROLLBACK;
