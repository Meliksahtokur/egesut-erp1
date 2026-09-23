-- kabul_meta.ddl içindeki deyimleri (phase, ord) sırasıyla uygular; bağımlılık sırası
-- katalogdan bilinmediği için başarısızları ilerleme durana kadar yeniden dener.
\set ON_ERROR_STOP 1
SET search_path TO public, extensions;
SET check_function_bodies = off;
DO $$
DECLARE r record; n_ok int; p int := 0;
BEGIN
  LOOP
    p := p + 1; n_ok := 0;
    FOR r IN SELECT id, sql FROM kabul_meta.ddl WHERE status <> 'ok' ORDER BY phase, ord, id LOOP
      BEGIN
        EXECUTE r.sql;
        UPDATE kabul_meta.ddl SET status = 'ok', pass = p, err = NULL WHERE id = r.id;
        n_ok := n_ok + 1;
      EXCEPTION WHEN others THEN
        UPDATE kabul_meta.ddl SET status = 'fail', pass = p, err = SQLSTATE || ' ' || SQLERRM WHERE id = r.id;
      END;
    END LOOP;
    RAISE NOTICE 'gecis %: % deyim basarili', p, n_ok;
    EXIT WHEN n_ok = 0 OR NOT EXISTS (SELECT 1 FROM kabul_meta.ddl WHERE status <> 'ok');
  END LOOP;
END $$;
