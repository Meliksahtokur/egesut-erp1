-- 20260913000004 — LUNA-1 düzeltmesi: bilet değeri degisim_log'a MASKELİ yazılır.
-- Bulgu (agent/luna-denetim-l2 §3): revert sırasında kaynak.geri_alma.bilet
-- tam UUID olarak public degisim_log'a düşüyordu; authenticated bir kullanıcı
-- degisim_listele detayından 1 saatlik çok-kullanımlı bileti okuyup sahip
-- şifresi kapısını atlayabiliyordu. Düzeltme: log'a yalnız ilk 8 karakter +
-- ellipsis yazılır (korelasyon için); tam bilet yalnız surum_gizli'de kalır.
-- Gövde 20260913000001'deki _degisim_log_yaz ile birebir aynıdır; tek fark
-- maske satırıdır (CREATE OR REPLACE, imza değişmedi).

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
      'bilet',   left(v_bilet, 8) || '…', -- LUNA-1: tam bilet public log'a yazilmaz (maske: ilk 8 + ellipsis)
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
