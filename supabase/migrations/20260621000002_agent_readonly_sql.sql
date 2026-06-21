-- Güvenli salt-okuma SQL çalıştırma RPC'si
--
-- Sandbox stratejisi (savunma derinliği):
--   1) Regex guard: yalnız tek SELECT/WITH; yazma/DDL anahtar kelimeleri reddedilir.
--   2) SET LOCAL transaction_read_only = on: motor seviyesinde TÜM yazmaları reddeder
--      (regex aşılsa bile). PostgreSQL SECURITY DEFINER içinde "SET ROLE" yasak olduğu
--      için (42501) rol-değişimi yerine bu kullanılır — daha güçlü ve basit.
--   3) statement_timeout 5s + LIMIT 500.
BEGIN;

CREATE OR REPLACE FUNCTION public.asistan_sql_calistir(p_sql text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_clean text := btrim(p_sql);
  v_low   text := lower(v_clean);
  v_result jsonb;
BEGIN
  -- Sadece tek SELECT / WITH
  IF v_low !~ '^(select|with)\s' THEN
    RAISE EXCEPTION 'Sadece SELECT sorgusu çalıştırılabilir';
  END IF;
  IF position(';' in btrim(v_clean, ';')) > 0 THEN
    RAISE EXCEPTION 'Çoklu statement yasak';
  END IF;
  IF v_low ~ '\m(insert|update|delete|drop|alter|create|truncate|grant|revoke|copy|call|do)\M' THEN
    RAISE EXCEPTION 'Yazma/DDL anahtar kelimesi yasak';
  END IF;

  -- Motor seviyesi salt-okuma + timeout (transaction-local)
  SET LOCAL transaction_read_only = on;
  SET LOCAL statement_timeout = '5s';

  EXECUTE format(
    'SELECT coalesce(jsonb_agg(t), ''[]''::jsonb) FROM (%s LIMIT 500) t',
    rtrim(v_clean, ';')
  ) INTO v_result;

  RETURN v_result;
END $$;

REVOKE ALL ON FUNCTION public.asistan_sql_calistir(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.asistan_sql_calistir(text) TO authenticated, anon;

NOTIFY pgrst, 'reload schema';
COMMIT;
