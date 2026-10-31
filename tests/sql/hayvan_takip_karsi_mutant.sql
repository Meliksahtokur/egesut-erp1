-- Hayvan Takip karşı testleri için mutant: yeni görev tipini TAKIP_MUAYENE gibi davrandırır.
-- Yalnız hayvan_takip_kos.sh içinde, test dosyasından ÖNCE verilir; ROLLBACK ile yok olur.
-- Beklenen düşen küme: KR01-KR07, KR09. KR08 ve KR10 düşmez.
DO $m$
DECLARE
  r record;
  v_n int := 0;
  v_def text;
  v_yeni text;
BEGIN
  FOR r IN
    SELECT p.oid FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public' AND p.prokind = 'f'
       AND p.prosrc LIKE '%gorev_tipi = ''TAKIP_MUAYENE''%'
  LOOP
    EXECUTE replace(pg_get_functiondef(r.oid), $s$gorev_tipi = 'TAKIP_MUAYENE'$s$,
                    $s$gorev_tipi IN ('TAKIP_MUAYENE','HAYVAN_TAKIP_MUAYENE')$s$);
    v_n := v_n + 1;
  END LOOP;
  IF v_n = 0 THEN RAISE EXCEPTION 'MUTANT: uyan fonksiyon yok'; END IF;

  -- sessiz_hayvanlar_listele TAKIP_MUAYENE metnini taşımaz; KR05 için ayrı eleme.
  v_def := pg_get_functiondef('public.sessiz_hayvanlar_listele(text,integer)'::regprocedure);
  v_yeni := replace(v_def, 'AND NOT EXISTS (SELECT 1 FROM public.cases c',
    $s$AND NOT EXISTS (SELECT 1 FROM public.gorev_log g WHERE g.hayvan_id = e.id
         AND g.gorev_tipi = 'HAYVAN_TAKIP_MUAYENE' AND g.tamamlandi IS NOT TRUE AND g.iptal IS NOT TRUE)
       AND NOT EXISTS (SELECT 1 FROM public.cases c$s$);
  IF v_yeni = v_def THEN RAISE EXCEPTION 'MUTANT: sessiz_hayvanlar_listele çapası yok'; END IF;
  EXECUTE v_yeni;

  RAISE NOTICE 'MUTANT uygulandi: % fonksiyon + sessiz_hayvanlar_listele', v_n;
END $m$;
