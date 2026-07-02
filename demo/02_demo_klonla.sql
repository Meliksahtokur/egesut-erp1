-- D2: demo_klonla() — prod'u prod_fdw üzerinden demo'ya birebir klonlar (atomik, DİNAMİK)
-- ⚠️ SADECE DEMO'da (prod_fdw'e bağlı). Prod'a UYGULAMA.
-- DİNAMİK: tablo listesi + FK sırası + kolonlar + sequence'ler runtime demo katalogundan
--          hesaplanır → demo'ya tablo/kolon eklenince klon otomatik kapsar, regen gerekmez.

CREATE TABLE IF NOT EXISTS public.demo_klon_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  calisti_at timestamptz NOT NULL DEFAULT now(),
  satir_sayisi bigint,
  sure_ms int,
  durum text NOT NULL DEFAULT 'OK',
  farm_id uuid NOT NULL DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e'
);
ALTER TABLE public.demo_klon_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS demo_klon_log_all ON public.demo_klon_log;
CREATE POLICY demo_klon_log_all ON public.demo_klon_log FOR ALL TO authenticated USING (true) WITH CHECK (true);
GRANT SELECT ON public.demo_klon_log TO authenticated;

CREATE OR REPLACE FUNCTION public.demo_klonla()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
SET statement_timeout TO '300s'   -- authenticated rolünün ~8s limiti FDW ağ-okumasında yetmez
AS $fn$
DECLARE
  ins_order text[];   -- topolojik FK sırası (ebeveyn -> çocuk), runtime hesaplanır
  trunc_list text;
  rec record;
  t text; cols text; n bigint; rows_total bigint := 0;
  started timestamptz := clock_timestamp(); ms int;
BEGIN
  -- 0) klon kapsamı + topolojik sıra: public base tabloları,
  --    hariç agent_* / demo_klon_log / 3 AI-infra vector; SADECE prod_fdw'de karşılığı olanlar.
  --    Sıra = FK grafiğinde en uzun ebeveyn-yolu (DAG; self-FK hariç) → ebeveyn önce.
  WITH RECURSIVE set_tables AS (
    SELECT c.oid, c.relname
    FROM pg_class c JOIN pg_namespace nsp ON nsp.oid = c.relnamespace
    WHERE nsp.nspname='public' AND c.relkind='r'
      AND c.relname NOT LIKE 'agent\_%'
      AND c.relname <> 'demo_klon_log'
      AND c.relname NOT IN ('code_embeddings','entity_graph','memory_notes')
      AND EXISTS (SELECT 1 FROM pg_class fc JOIN pg_namespace fn ON fn.oid=fc.relnamespace
                  WHERE fn.nspname='prod_fdw' AND fc.relname=c.relname)
  ),
  edges AS (   -- child -> parent, sadece set içi, self-FK hariç
    SELECT con.conrelid AS child, con.confrelid AS parent
    FROM pg_constraint con
    WHERE con.contype='f'
      AND con.conrelid  IN (SELECT oid FROM set_tables)
      AND con.confrelid IN (SELECT oid FROM set_tables)
      AND con.conrelid <> con.confrelid
    GROUP BY 1,2
  ),
  depth(oid, d) AS (
    SELECT oid, 0 FROM set_tables WHERE oid NOT IN (SELECT child FROM edges)
    UNION ALL
    SELECT e.child, depth.d + 1 FROM depth JOIN edges e ON e.parent = depth.oid
  )
  SELECT array_agg(st.relname ORDER BY md.max_d, st.relname)
    INTO ins_order
  FROM set_tables st
  JOIN LATERAL (SELECT COALESCE(max(d),0) AS max_d FROM depth WHERE depth.oid = st.oid) md ON true;

  IF ins_order IS NULL OR array_length(ins_order,1) = 0 THEN
    RAISE EXCEPTION 'demo_klonla: klonlanacak tablo bulunamadı (prod_fdw boş mu?)';
  END IF;

  -- 1) app trigger'larını sustur (klon prod'u birebir yansıtsın; postgres superuser değil → USER, ALL değil)
  FOREACH t IN ARRAY ins_order LOOP
    EXECUTE format('ALTER TABLE public.%I DISABLE TRIGGER USER', t);
  END LOOP;

  -- 2) hepsini tek deyimde boşalt (FK-güvenli: tüm set listeli)
  SELECT string_agg('public.'||quote_ident(x), ', ') INTO trunc_list FROM unnest(ins_order) x;
  EXECUTE 'TRUNCATE ' || trunc_list;

  -- 3) ebeveyn->çocuk sırayla kopyala; kolonlar = demo ∩ prod_fdw (iki yönlü drift-güvenli)
  FOREACH t IN ARRAY ins_order LOOP
    SELECT string_agg(quote_ident(dc.column_name), ', ' ORDER BY dc.ordinal_position)
      INTO cols
    FROM information_schema.columns dc
    WHERE dc.table_schema='public' AND dc.table_name=t
      AND EXISTS (SELECT 1 FROM information_schema.columns fc
                  WHERE fc.table_schema='prod_fdw' AND fc.table_name=t AND fc.column_name=dc.column_name);
    IF cols IS NULL THEN CONTINUE; END IF;
    EXECUTE format('INSERT INTO public.%1$I (%2$s) SELECT %2$s FROM prod_fdw.%1$I', t, cols);
    GET DIAGNOSTICS n = ROW_COUNT; rows_total := rows_total + n;
  END LOOP;

  -- 3b) ertelenmiş FK kontrollerini şimdi zorla (yoksa pending trigger events → ALTER TABLE patlar)
  SET CONSTRAINTS ALL IMMEDIATE;

  -- 4) trigger'ları geri aç
  FOREACH t IN ARRAY ins_order LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE TRIGGER USER', t);
  END LOOP;

  -- 5) sequence senkron (set tablolarının serial/identity sequence'leri, runtime)
  FOR rec IN
    SELECT c.table_name, c.column_name,
           pg_get_serial_sequence('public.'||c.table_name, c.column_name) AS seq
    FROM information_schema.columns c
    WHERE c.table_schema='public' AND c.table_name = ANY(ins_order)
      AND pg_get_serial_sequence('public.'||c.table_name, c.column_name) IS NOT NULL
  LOOP
    EXECUTE format('SELECT setval(%L, GREATEST((SELECT COALESCE(max(%I),0) FROM public.%I),1))',
                   rec.seq, rec.column_name, rec.table_name);
  END LOOP;

  ms := round(extract(epoch from clock_timestamp()-started)*1000);
  INSERT INTO public.demo_klon_log(satir_sayisi, sure_ms, durum) VALUES (rows_total, ms, 'OK');
  RETURN jsonb_build_object('ok', true, 'rows', rows_total, 'ms', ms, 'tables', array_length(ins_order,1));
END;
$fn$;

REVOKE ALL ON FUNCTION public.demo_klonla() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.demo_klonla() TO authenticated;
