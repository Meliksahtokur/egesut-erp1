-- D2: demo_klonla() — prod'u prod_fdw üzerinden demo'ya birebir klonlar (atomik)
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
SET search_path = public, pg_temp AS $fn$
DECLARE
  ins_order text[] := ARRAY[
    '_regen_fndefs',
    'bildirim_log',
    'chat',
    'cop_kutusu',
    'diseases',
    'goose_embeddings',
    'hastalik_log',
    'hayvan_override',
    'hekimler',
    'irk_esik',
    'islem_log',
    'padoklar',
    'protokol_ayar',
    'stok_kategorileri',
    'tasks',
    'tedavi_sablonu',
    'ui_logs',
    'vethek_tohumlamalar',
    'drug_classes',
    'grup_padok_eslem',
    'hayvanlar',
    'sablon_hastalik_eslem',
    'cases',
    'dogum',
    'drug_products',
    'protokol_dismiss',
    'protokol_instance',
    'tedavi',
    'kizginlik_log',
    'stok',
    'tohumlama',
    'treatment_days',
    'drugs',
    'stok_hareket',
    'tedavi_sablonu_kalem',
    'treatment_day_uygulamalar',
    'uygulama_log',
    'vaccines',
    'drug_administrations',
    'gorev_log',
    'vaccination_log',
    'vaccination_schedule',
    'vaccine_diseases',
    'vaccine_protocol_steps'
  ];
  trunc_list text;
  t text; cols text; n bigint; rows_total bigint := 0;
  started timestamptz := clock_timestamp(); ms int;
BEGIN
  -- 1) app trigger'larını sustur (klon prod'u birebir yansıtsın, trigger görev üretmesin)
  FOREACH t IN ARRAY ins_order LOOP
    EXECUTE format('ALTER TABLE public.%I DISABLE TRIGGER USER', t);
  END LOOP;

  -- 2) hepsini tek deyimde boşalt (FK-güvenli: tüm set listeli)
  SELECT string_agg('public.'||quote_ident(x), ', ') INTO trunc_list FROM unnest(ins_order) x;
  EXECUTE 'TRUNCATE ' || trunc_list;

  -- 3) ebeveyn->çocuk sırayla prod_fdw'den kopyala (FK açık, sırayla sağlanıyor)
  FOREACH t IN ARRAY ins_order LOOP
    SELECT string_agg(quote_ident(column_name), ', ' ORDER BY ordinal_position)
      INTO cols FROM information_schema.columns
      WHERE table_schema='public' AND table_name=t;
    EXECUTE format('INSERT INTO public.%1$I (%2$s) SELECT %2$s FROM prod_fdw.%1$I', t, cols);
    GET DIAGNOSTICS n = ROW_COUNT; rows_total := rows_total + n;
  END LOOP;

  -- 3b) ertelenmiş FK kontrollerini şimdi zorla (aksi halde pending trigger events → ALTER TABLE patlar)
  SET CONSTRAINTS ALL IMMEDIATE;

  -- 4) trigger'ları geri aç
  FOREACH t IN ARRAY ins_order LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE TRIGGER USER', t);
  END LOOP;

  -- 5) sequence senkron
  PERFORM setval('public.chat_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM public.chat),1));
  PERFORM setval('public.goose_embeddings_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM public.goose_embeddings),1));
  PERFORM setval('public.ui_logs_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM public.ui_logs),1));
  PERFORM setval('public.vethek_tohumlamalar_id_seq', GREATEST((SELECT COALESCE(max(id),0) FROM public.vethek_tohumlamalar),1));

  ms := round(extract(epoch from clock_timestamp()-started)*1000);
  INSERT INTO public.demo_klon_log(satir_sayisi, sure_ms, durum) VALUES (rows_total, ms, 'OK');
  RETURN jsonb_build_object('ok',true,'rows',rows_total,'ms',ms,'tables',array_length(ins_order,1));
END;
$fn$;

REVOKE ALL ON FUNCTION public.demo_klonla() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.demo_klonla() TO authenticated;
