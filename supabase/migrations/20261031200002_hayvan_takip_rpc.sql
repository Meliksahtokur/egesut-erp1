-- Migration: Hayvan Takip RPC'leri ve çıkış tetikleyicisi
-- Tarih: 2026-10-31. Kaynak: spec §4.3, §4.4, §6; domain-rules §11, §14, §20. Şema: 20261031200001.
-- BEGIN/COMMIT yok: runbook ve test sarmalayıcısı dışarıdan sarar. Prod apply sahip kapısındadır.
--
-- Kilit sırası (R13): hayvanlar -> hayvan_takip -> gorev_log. Dört RPC önce hayvan satırını kilitler;
-- çıkışta hayvan satırını UPDATE kilitler. Aynı hayvanın yazmaları böylece sıralanır.
-- Ret sırası: parametre -> varlık -> durum.
--
-- ROLLBACK (tek işlemde, bu sırayla):
--   DROP TRIGGER trg_hayvan_cikis_takip_kapat ON public.hayvanlar;
--   DROP FUNCTION public._trg_hayvan_cikis_takip_kapat();
--   DROP FUNCTION public.hayvan_takip_muayene_sonuc(uuid, text, text, date, time);
--   DROP FUNCTION public.hayvan_takip_muayene_planla(uuid, date, time);
--   DROP FUNCTION public.hayvan_takip_kapat(uuid[], text, uuid);
--   DROP FUNCTION public.hayvan_takip_ac(text, text, text, date, time);
--   DROP FUNCTION public._hayvan_takip_kapat_ic(uuid, text, text, text, uuid);
--   DROP FUNCTION public._hayvan_takip_gorev_yaz(uuid, text, text, date, time);
--   DROP FUNCTION public._hayvan_takip_sebep_etiket(text);
--   DROP FUNCTION public._hayvan_takip_kullanici();
--   Not: Şema migration'ı geri alınmadan önce bu adımlar koşulur. islem_log satırları kalır.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- JWT email'i, yoksa sub, yoksa oturum kullanıcısı. Bozuk claim hata vermez (emsal surum_gizli._cagiran).
CREATE FUNCTION public._hayvan_takip_kullanici()
  RETURNS text
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_claims jsonb;
BEGIN
  BEGIN
    v_claims := NULLIF(current_setting('request.jwt.claims', true), '')::jsonb;
  EXCEPTION WHEN others THEN
    v_claims := NULL;
  END;
  RETURN COALESCE(NULLIF(v_claims ->> 'email', ''), NULLIF(v_claims ->> 'sub', ''), session_user::text);
END;
$function$;

-- R3: CASE kodları js/config.js listesinin alt kümesidir; bilinmeyen kod ham kalır.
CREATE FUNCTION public._hayvan_takip_sebep_etiket(p_kod text)
  RETURNS text
  LANGUAGE sql
  IMMUTABLE
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE p_kod
    WHEN 'TOPALLIK' THEN 'Topallık'
    WHEN 'SUT_DUSUSU' THEN 'Süt düşüşü'
    WHEN 'ZAYIFLAMA' THEN 'Zayıflama'
    WHEN 'ISTAHSIZLIK' THEN 'İştahsızlık'
    WHEN 'DIGER' THEN 'Diğer'
    ELSE p_kod
  END;
$function$;

CREATE FUNCTION public._hayvan_takip_gorev_yaz(p_takip uuid, p_hayvan text, p_sebep text, p_tarih date, p_saat time)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_gorev_id uuid;
BEGIN
  INSERT INTO public.gorev_log (hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, kaynak, ref_takip_id)
  VALUES (p_hayvan, 'HAYVAN_TAKIP_MUAYENE', public._hayvan_takip_sebep_etiket(p_sebep) || ' takibi muayenesi',
          p_tarih, p_saat, 'HAYVAN_TAKIP:' || p_takip::text, p_takip)
  RETURNING id INTO v_gorev_id;
  RETURN v_gorev_id;
END;
$function$;

-- Açıksa kapatır ve true döner; kapalıysa dokunmaz. RPC'ler ve çıkış tetikleyicisi ortak kullanır.
-- Çıkışta görev iptali trg_hayvan_cikis_gorev_iptal'dedir; NULL durumlu görev oradan kaçar, burada kapanır.
CREATE FUNCTION public._hayvan_takip_kapat_ic(p_takip_id uuid, p_neden text, p_kapatan text, p_not text, p_vaka uuid)
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_takip public.hayvan_takip%ROWTYPE;
BEGIN
  UPDATE public.hayvan_takip
     SET kapanis_tarihi = now(), kapanis_nedeni = p_neden, kapatan = p_kapatan,
         kapanis_notu = p_not, kapatan_vaka_id = p_vaka
   WHERE id = p_takip_id AND kapanis_tarihi IS NULL
  RETURNING * INTO v_takip;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  UPDATE public.gorev_log
     SET iptal = true, kapatan_ref = 'hayvan-takip-kapandi'
   WHERE ref_takip_id = p_takip_id AND tamamlandi IS NOT TRUE AND iptal IS NOT TRUE;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('HAYVAN_TAKIP_KAPANDI', v_takip.hayvan_id, p_takip_id::text, 'hayvan_takip',
          jsonb_build_object('sebep_kodu', v_takip.sebep_kodu, 'aciklama', v_takip.aciklama,
                             'kapanis_nedeni', p_neden, 'kapatan', p_kapatan, 'kapatan_vaka_id', p_vaka),
          p_not);
  RETURN true;
END;
$function$;

CREATE FUNCTION public.hayvan_takip_ac(
  p_hayvan_id text,
  p_sebep_kodu text,
  p_aciklama text DEFAULT NULL,
  p_muayene_tarihi date DEFAULT NULL,
  p_muayene_saati time DEFAULT NULL
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_durum text;
  v_kullanici text := public._hayvan_takip_kullanici();
  v_takip_id uuid;
  v_gorev_id uuid;
BEGIN
  IF btrim(COALESCE(p_sebep_kodu, '')) = '' THEN
    RAISE EXCEPTION 'HT_SEBEP_BOS';
  END IF;
  IF p_sebep_kodu = 'DIGER' AND btrim(COALESCE(p_aciklama, '')) = '' THEN
    RAISE EXCEPTION 'HT_ACIKLAMA_GEREKLI';
  END IF;
  IF p_muayene_saati IS NOT NULL AND p_muayene_tarihi IS NULL THEN
    RAISE EXCEPTION 'HT_TARIH_GEREKLI';
  END IF;
  IF p_muayene_tarihi < (now() AT TIME ZONE 'Europe/Istanbul')::date THEN
    RAISE EXCEPTION 'HT_GECMIS_TARIH';
  END IF;

  SELECT durum INTO v_durum FROM public.hayvanlar WHERE id = p_hayvan_id FOR UPDATE;
  IF v_durum IS DISTINCT FROM 'Aktif' THEN
    RAISE EXCEPTION 'HT_HAYVAN_AKTIF_DEGIL';
  END IF;

  -- Kısmi unique tek otorite: DIGER muafiyeti indekste durur, burada tekrarlanmaz.
  BEGIN
    INSERT INTO public.hayvan_takip (farm_id, hayvan_id, sebep_kodu, aciklama, acan)
    VALUES (public.current_farm_id(), p_hayvan_id, p_sebep_kodu, p_aciklama, v_kullanici)
    RETURNING id INTO v_takip_id;
  EXCEPTION WHEN unique_violation THEN
    RAISE EXCEPTION 'HT_SEBEP_ZATEN_ACIK';
  END;

  IF p_muayene_tarihi IS NOT NULL THEN
    v_gorev_id := public._hayvan_takip_gorev_yaz(v_takip_id, p_hayvan_id, p_sebep_kodu, p_muayene_tarihi, p_muayene_saati);
  END IF;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('HAYVAN_TAKIP_ACILDI', p_hayvan_id, v_takip_id::text, 'hayvan_takip',
          jsonb_build_object('sebep_kodu', p_sebep_kodu, 'aciklama', p_aciklama, 'acan', v_kullanici, 'gorev_id', v_gorev_id),
          p_aciklama);

  RETURN jsonb_build_object('ok', true, 'takip_id', v_takip_id, 'gorev_id', v_gorev_id);
END;
$function$;

CREATE FUNCTION public.hayvan_takip_kapat(
  p_takip_ids uuid[],
  p_not text DEFAULT NULL,
  p_kapatan_vaka_id uuid DEFAULT NULL
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_hayvan_sayisi int;
  v_hayvan_id text;
  v_neden text := CASE WHEN p_kapatan_vaka_id IS NULL THEN 'ELLE' ELSE 'VAKA' END;
  v_kullanici text := public._hayvan_takip_kullanici();
  v_takip_id uuid;
  v_kapanan int := 0;
BEGIN
  IF COALESCE(cardinality(p_takip_ids), 0) = 0 THEN
    RAISE EXCEPTION 'HT_BOS_LISTE';
  END IF;

  -- Kapalı ve bulunmayan kimlik atlanır (spec §4.4); listede hiç takip yoksa hayvan da yoktur, reddedilir.
  SELECT count(DISTINCT t.hayvan_id), min(t.hayvan_id)
    INTO v_hayvan_sayisi, v_hayvan_id
    FROM public.hayvan_takip t
   WHERE t.id = ANY (p_takip_ids);
  IF v_hayvan_sayisi = 0 THEN
    RAISE EXCEPTION 'HT_TAKIP_YOK';
  END IF;
  IF v_hayvan_sayisi > 1 THEN
    RAISE EXCEPTION 'HT_FARKLI_HAYVAN';
  END IF;
  IF p_kapatan_vaka_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM public.cases c WHERE c.id = p_kapatan_vaka_id AND c.animal_id = v_hayvan_id) THEN
    RAISE EXCEPTION 'HT_VAKA_UYUMSUZ';
  END IF;

  PERFORM 1 FROM public.hayvanlar WHERE id = v_hayvan_id FOR UPDATE;

  FOREACH v_takip_id IN ARRAY p_takip_ids LOOP
    IF public._hayvan_takip_kapat_ic(v_takip_id, v_neden, v_kullanici, p_not, p_kapatan_vaka_id) THEN
      v_kapanan := v_kapanan + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'kapanan', v_kapanan, 'hayvan_id', v_hayvan_id);
END;
$function$;

-- R11: planlama islem_log yazmaz; log yalnız sonuç girişindedir.
CREATE FUNCTION public.hayvan_takip_muayene_planla(p_takip_id uuid, p_tarih date, p_saat time DEFAULT NULL)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_hayvan_id text;
  v_durum text;
  v_takip public.hayvan_takip%ROWTYPE;
  v_gorev_id uuid;
BEGIN
  IF p_tarih IS NULL THEN
    RAISE EXCEPTION 'HT_TARIH_GEREKLI';
  END IF;
  IF p_tarih < (now() AT TIME ZONE 'Europe/Istanbul')::date THEN
    RAISE EXCEPTION 'HT_GECMIS_TARIH';
  END IF;

  SELECT hayvan_id INTO v_hayvan_id FROM public.hayvan_takip WHERE id = p_takip_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'HT_TAKIP_YOK';
  END IF;

  SELECT durum INTO v_durum FROM public.hayvanlar WHERE id = v_hayvan_id FOR UPDATE;
  SELECT * INTO v_takip FROM public.hayvan_takip WHERE id = p_takip_id FOR UPDATE;

  IF v_takip.kapanis_tarihi IS NOT NULL THEN
    RAISE EXCEPTION 'HT_TAKIP_KAPALI';
  END IF;
  IF v_durum IS DISTINCT FROM 'Aktif' THEN
    RAISE EXCEPTION 'HT_HAYVAN_AKTIF_DEGIL';
  END IF;

  UPDATE public.gorev_log
     SET hedef_tarih = p_tarih, hedef_saat = p_saat
   WHERE ref_takip_id = p_takip_id AND tamamlandi IS NOT TRUE AND iptal IS NOT TRUE
  RETURNING id INTO v_gorev_id;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'gorev_id', v_gorev_id, 'yeni', false);
  END IF;

  v_gorev_id := public._hayvan_takip_gorev_yaz(p_takip_id, v_hayvan_id, v_takip.sebep_kodu, p_tarih, p_saat);
  RETURN jsonb_build_object('ok', true, 'gorev_id', v_gorev_id, 'yeni', true);
END;
$function$;

-- Görevi doğrudan tamamlar: gorev_tamamla bu tipi MUAYENE_SONUC_GEREKLI ile reddeder (T5).
CREATE FUNCTION public.hayvan_takip_muayene_sonuc(
  p_gorev_id uuid,
  p_sonuc text,
  p_not text DEFAULT NULL,
  p_sonraki_tarih date DEFAULT NULL,
  p_sonraki_saat time DEFAULT NULL
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_gorev public.gorev_log%ROWTYPE;
  v_takip public.hayvan_takip%ROWTYPE;
  v_kullanici text := public._hayvan_takip_kullanici();
  v_yeni_gorev_id uuid;
  v_kapandi boolean := false;
BEGIN
  IF p_sonuc IS NULL OR p_sonuc NOT IN ('SURSUN', 'KAPANSIN') THEN
    RAISE EXCEPTION 'HT_SONUC_GECERSIZ';
  END IF;
  -- Sonraki tarih yalnız SURSUN'da anlamlıdır; KAPANSIN'de yok sayılır.
  IF p_sonuc = 'SURSUN' THEN
    IF p_sonraki_saat IS NOT NULL AND p_sonraki_tarih IS NULL THEN
      RAISE EXCEPTION 'HT_TARIH_GEREKLI';
    END IF;
    IF p_sonraki_tarih < (now() AT TIME ZONE 'Europe/Istanbul')::date THEN
      RAISE EXCEPTION 'HT_GECMIS_TARIH';
    END IF;
  END IF;

  SELECT * INTO v_gorev FROM public.gorev_log WHERE id = p_gorev_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'HT_GOREV_YOK';
  END IF;
  IF v_gorev.gorev_tipi IS DISTINCT FROM 'HAYVAN_TAKIP_MUAYENE' THEN
    RAISE EXCEPTION 'HT_GOREV_TIP_UYUMSUZ';
  END IF;
  IF v_gorev.ref_takip_id IS NULL THEN
    RAISE EXCEPTION 'HT_TAKIP_YOK';
  END IF;

  PERFORM 1 FROM public.hayvanlar
    WHERE id = (SELECT t.hayvan_id FROM public.hayvan_takip t WHERE t.id = v_gorev.ref_takip_id)
    FOR UPDATE;
  SELECT * INTO v_takip FROM public.hayvan_takip WHERE id = v_gorev.ref_takip_id FOR UPDATE;
  SELECT * INTO v_gorev FROM public.gorev_log WHERE id = p_gorev_id FOR UPDATE;

  IF v_gorev.tamamlandi IS TRUE OR v_gorev.iptal IS TRUE THEN
    RAISE EXCEPTION 'HT_GOREV_KAPALI';
  END IF;
  IF v_takip.kapanis_tarihi IS NOT NULL THEN
    RAISE EXCEPTION 'HT_TAKIP_KAPALI';
  END IF;

  UPDATE public.gorev_log SET tamamlandi = true, tamamlanma_tarihi = now() WHERE id = p_gorev_id;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('HAYVAN_TAKIP_MUAYENE', v_takip.hayvan_id, v_takip.id::text, 'hayvan_takip',
          jsonb_build_object('sebep_kodu', v_takip.sebep_kodu, 'aciklama', v_takip.aciklama, 'sonuc', p_sonuc,
                             'gorev_id', p_gorev_id, 'kullanici', v_kullanici),
          p_not);

  IF p_sonuc = 'KAPANSIN' THEN
    v_kapandi := public._hayvan_takip_kapat_ic(v_takip.id, 'MUAYENE', v_kullanici, p_not, NULL);
  ELSIF p_sonraki_tarih IS NOT NULL THEN
    v_yeni_gorev_id := public._hayvan_takip_gorev_yaz(v_takip.id, v_takip.hayvan_id, v_takip.sebep_kodu, p_sonraki_tarih, p_sonraki_saat);
  END IF;

  RETURN jsonb_build_object('ok', true, 'sonuc', p_sonuc, 'takip_id', v_takip.id,
                            'yeni_gorev_id', v_yeni_gorev_id, 'kapandi', v_kapandi);
END;
$function$;

-- DEFINER şart: authenticated hayvan_takip'e yazamaz; hayvanlar.durum'a doğrudan UPDATE çıkışı kırardı (T2 C04).
CREATE FUNCTION public._trg_hayvan_cikis_takip_kapat()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  PERFORM public._hayvan_takip_kapat_ic(t.id, 'CIKIS', 'sistem', NULL, NULL)
    FROM public.hayvan_takip t
   WHERE t.hayvan_id = NEW.id AND t.kapanis_tarihi IS NULL;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_hayvan_cikis_takip_kapat
  AFTER UPDATE OF durum ON public.hayvanlar
  FOR EACH ROW
  WHEN (OLD.durum = 'Aktif' AND NEW.durum IS DISTINCT FROM 'Aktif')
  EXECUTE FUNCTION public._trg_hayvan_cikis_takip_kapat();

-- Supabase default privilege'i authenticated ve service_role'e EXECUTE verir; REVOKE bu yüzden onları da kapsar.
REVOKE ALL ON FUNCTION public.hayvan_takip_ac(text, text, text, date, time) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.hayvan_takip_kapat(uuid[], text, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.hayvan_takip_muayene_planla(uuid, date, time) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.hayvan_takip_muayene_sonuc(uuid, text, text, date, time) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.hayvan_takip_ac(text, text, text, date, time) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.hayvan_takip_kapat(uuid[], text, uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.hayvan_takip_muayene_planla(uuid, date, time) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.hayvan_takip_muayene_sonuc(uuid, text, text, date, time) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public._hayvan_takip_kullanici() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public._hayvan_takip_sebep_etiket(text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public._hayvan_takip_gorev_yaz(uuid, text, text, date, time) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public._hayvan_takip_kapat_ic(uuid, text, text, text, uuid) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION public._trg_hayvan_cikis_takip_kapat() FROM PUBLIC, anon, authenticated, service_role;
