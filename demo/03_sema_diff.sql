-- D-şema: demo_sema_diff() — prod (prod_fdw) ile demo (public) şema farkını bildirir.
-- ⚠️ SADECE DEMO'da. Klon değil, salt-okuma uyarı. UI: js/demo.js semaDiffKontrol().
-- Dönüş: {eksik_tablo:[...], eksik_kolon:["tablo.kolon",...]} — prod'da olup demo'da olmayanlar.
CREATE OR REPLACE FUNCTION public.demo_sema_diff()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT jsonb_build_object(
    'eksik_tablo', COALESCE((
      SELECT jsonb_agg(fc.relname ORDER BY fc.relname)
      FROM pg_class fc JOIN pg_namespace fn ON fn.oid=fc.relnamespace
      WHERE fn.nspname='prod_fdw' AND fc.relkind IN ('f','r','v')
        AND NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
                        WHERE n.nspname='public' AND c.relkind IN ('r','v') AND c.relname=fc.relname)
    ), '[]'::jsonb),
    'eksik_kolon', COALESCE((
      SELECT jsonb_agg(fc.table_name || '.' || fc.column_name ORDER BY fc.table_name, fc.column_name)
      FROM information_schema.columns fc
      WHERE fc.table_schema='prod_fdw'
        AND EXISTS (SELECT 1 FROM information_schema.tables t
                    WHERE t.table_schema='public' AND t.table_name=fc.table_name)
        AND NOT EXISTS (SELECT 1 FROM information_schema.columns dc
                        WHERE dc.table_schema='public' AND dc.table_name=fc.table_name AND dc.column_name=fc.column_name)
    ), '[]'::jsonb)
  );
$$;
REVOKE ALL ON FUNCTION public.demo_sema_diff() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.demo_sema_diff() TO authenticated;
