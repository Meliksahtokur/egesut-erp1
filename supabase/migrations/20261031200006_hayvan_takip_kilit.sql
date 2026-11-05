-- Migration: Hayvan Takip RPC'lerinde hayvan kilidi FOR NO KEY UPDATE
-- Tarih: 2026-10-31. Kaynak: U2 kapısı, domain-rules §20. Önceki migration: 20261031200005. 20261031200002 demoda uygulandı, değişmez.
-- BEGIN/COMMIT yok: runbook ve test sarmalayıcısı dışarıdan sarar. Prod apply sahip kapısındadır.
-- Hayvan FOR UPDATE, FK KEY SHARE tutan oturumu bekler; o oturum takibi kilitlediyse deadlock (tests/sql/hayvan_takip_kilit_test.sh K4, K5).
-- Kod tabanı kuralı aynı (start_first_service_protocol: hayvan satırında FOR UPDATE yok). NO KEY UPDATE kendisiyle ve hayvan UPDATE'iyle yine çakışır: R13 sırası korunur (K6, K7).
-- Gövdeler 20261031200002'nin kopyasıdır, yalnız hayvan kilit satırı değişir. Takip ve görev kilitleri FOR UPDATE kalır. _hayvan_takip_kapat_ic'te FOR UPDATE yoktur, dokunulmadı.
-- ACL'ye dokunulmaz: CREATE OR REPLACE korur, REVOKE+GRANT proacl sırasını değiştirir (K0-meta).
-- ROLLBACK: 20261031200002'deki dört gövde CREATE OR REPLACE ile yeniden kurulur.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION public.hayvan_takip_ac(
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

  SELECT durum INTO v_durum FROM public.hayvanlar WHERE id = p_hayvan_id FOR NO KEY UPDATE;
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

CREATE OR REPLACE FUNCTION public.hayvan_takip_kapat(
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

  PERFORM 1 FROM public.hayvanlar WHERE id = v_hayvan_id FOR NO KEY UPDATE;

  FOREACH v_takip_id IN ARRAY p_takip_ids LOOP
    IF public._hayvan_takip_kapat_ic(v_takip_id, v_neden, v_kullanici, p_not, p_kapatan_vaka_id) THEN
      v_kapanan := v_kapanan + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'kapanan', v_kapanan, 'hayvan_id', v_hayvan_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.hayvan_takip_muayene_planla(p_takip_id uuid, p_tarih date, p_saat time DEFAULT NULL)
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

  SELECT durum INTO v_durum FROM public.hayvanlar WHERE id = v_hayvan_id FOR NO KEY UPDATE;
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

CREATE OR REPLACE FUNCTION public.hayvan_takip_muayene_sonuc(
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
    FOR NO KEY UPDATE;
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
