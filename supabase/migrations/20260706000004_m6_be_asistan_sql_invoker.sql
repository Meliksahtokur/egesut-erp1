-- M-6(BE): asistan_sql_calistir SECURITY DEFINER → INVOKER
-- SECURITY DEFINER RLS'yi tamamen bypass ediyordu (guard'lar SQL syntax'ını
-- kısıtlıyordu ama hangi satırların görüneceğini değil). INVOKER'a geçince
-- sorgu çağıran kullanıcının kendi RLS politikalarıyla çalışır. Şu an tüm
-- tablolarda USING(true) olduğu için davranış değişmiyor (M-5, Faz 2 kapsamı),
-- ama Faz 2 farm_id RLS retrofit'i geldiğinde bu fonksiyon otomatik uyumlu
-- olur — ekstra değişiklik gerekmez. Demo projede 3 senaryo ile test edildi
-- (normal SELECT çalışıyor, DELETE/çoklu-statement hâlâ reddediliyor).
CREATE OR REPLACE FUNCTION public.asistan_sql_calistir(p_sql text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  v_clean text := btrim(p_sql);
  v_low   text := lower(v_clean);
  v_result jsonb;
BEGIN
  IF v_low !~ '^(select|with)\s' THEN
    RAISE EXCEPTION 'Sadece SELECT sorgusu çalıştırılabilir';
  END IF;
  IF position(';' in btrim(v_clean, ';')) > 0 THEN
    RAISE EXCEPTION 'Çoklu statement yasak';
  END IF;
  IF v_low ~ '\m(insert|update|delete|drop|alter|create|truncate|grant|revoke|copy|call|do)\M' THEN
    RAISE EXCEPTION 'Yazma/DDL anahtar kelimesi yasak';
  END IF;

  SET LOCAL transaction_read_only = on;
  SET LOCAL statement_timeout = '5s';

  EXECUTE format(
    'SELECT coalesce(jsonb_agg(t), ''[]''::jsonb) FROM (SELECT * FROM (%s) sub LIMIT 500) t',
    rtrim(v_clean, ';')
  ) INTO v_result;

  RETURN v_result;
END $function$;
