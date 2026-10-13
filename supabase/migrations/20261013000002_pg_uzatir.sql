-- ════════════════════════════════════════════════════════════════════
-- Ovsync paketi Faz 1 — PG uzatır + PG bypass kapısı (sahip kararı 2026-10-13, karar 3)
-- "PG Ovsync'i KAPATMAZ, UZATIR; vaka tohumlamaya bağlanana kadar açık kalır."
--
-- Gövde türetme: CANLI pg_get_functiondef (Mgmt API, yalnız SELECT, 2026-10-13 MEASURED):
--   _pg_olay_isle, treatment_day_tamamla, add_drug_administration,
--   tedavi_sablon_uygula + hizli_uygulama kapı deyimi + _pg_kapi/_pg_urun_durumu.
-- TEK davranış değişiklikleri: (1) _pg_olay_isle E3 kancası kalktı (aşağıda);
-- (2) 3 RPC imza sonuna p_pg_onay/p_pg_gerekce + PG kapısı; (3) CHECK'e
-- TEDAVI_GUN/ILAC_EKLE. Eski migration dosyasına dokunulmadı.
-- İç yardımcılar (_ önekli) authenticated'a açılmadı; yeni imzalara anon EXECUTE YOK.
-- ════════════════════════════════════════════════════════════════════

BEGIN;

-- squawk hijyeni: yeniden tanım öncesinde timeout'lar (emsal 20261013000001:14-18)
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ── 1. pg_application_event kaynak CHECK: TEDAVI_GUN + ILAC_EKLE ──────────
ALTER TABLE public.pg_application_event DROP CONSTRAINT IF EXISTS pg_application_event_source_type_check;
ALTER TABLE public.pg_application_event ADD CONSTRAINT pg_application_event_source_type_check
  CHECK (source_type = ANY (ARRAY['HIZLI_UYGULAMA', 'TEDAVI_SEANS', 'TOPLU_ILAC', 'TEDAVI_GUN', 'ILAC_EKLE']));

-- ── 2. _pg_olay_isle: canlı gövde AYNI, YALNIZ E3 bloğu çıkarıldı ─────────
-- Kaldırılan: E3 kanca değişkenleri + E3 (S3) bloğu
-- (TEDAVI_SEANS çözümlemesi + _vaka_kapat(..., 'PG', ...) döngüsü).
-- Kapı RAISE'leri ve SK2 (_pg_sonrasi_tohumlama → +48 s TAI) aynen korundu.
-- Kaynak listesine TEDAVI_GUN + ILAC_EKLE eklendi.
CREATE OR REPLACE FUNCTION public._pg_olay_isle(p_source_type text, p_source_id text, p_hayvan_id text, p_stok_id text, p_drug_product_id uuid, p_occurred_at timestamp with time zone, p_kapi jsonb, p_gerekce text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_karar      text;
  v_pg         text;
  v_event_id   uuid;
  v_toh_id     text;
  v_iptal      integer := 0;
BEGIN
  IF p_kapi IS NULL OR jsonb_typeof(p_kapi) <> 'object' THEN
    RAISE EXCEPTION 'PG_KAPI_IC_HATA:%', jsonb_build_object('sebep', 'KAPI_SONUCU_YOK');
  END IF;
  v_karar := p_kapi->>'karar';
  v_pg    := p_kapi->>'pg';

  IF v_karar = 'KAPALI' THEN
    RETURN NULL;
  ELSIF v_karar IN ('BLOCK_PREGNANT', 'REQUIRE_ACK_PENDING', 'BLOCK_CATALOG_UNRESOLVED') THEN
    RAISE EXCEPTION 'PG_KAPI:%:%', v_karar, p_kapi;
  ELSIF v_karar NOT IN ('ALLOW', 'ACK_PENDING') OR v_karar IS NULL THEN
    RAISE EXCEPTION 'PG_KAPI_IC_HATA:%', jsonb_build_object('sebep', 'TANIMSIZ_KARAR', 'kapi', p_kapi);
  END IF;

  IF v_pg = 'false' AND v_karar = 'ALLOW' THEN
    RETURN NULL;  -- PG değil; olay yok
  ELSIF v_pg IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'PG_KAPI_IC_HATA:%', jsonb_build_object('sebep', 'TANIMSIZ_PG_BAYRAGI', 'kapi', p_kapi);
  END IF;

  -- Kapı başka hayvan için alınmışsa reddet
  IF (p_kapi->>'hayvan_id') IS DISTINCT FROM (p_hayvan_id) THEN
    RAISE EXCEPTION 'PG_KAPI_IC_HATA:%', jsonb_build_object('sebep', 'KAPI_HAYVAN_UYUSMAZ',
      'hayvan_id', p_hayvan_id, 'kapi', p_kapi);
  END IF;
  IF p_source_type IS NULL OR p_source_type NOT IN ('HIZLI_UYGULAMA', 'TEDAVI_SEANS', 'TOPLU_ILAC', 'TEDAVI_GUN', 'ILAC_EKLE')
     OR p_source_id IS NULL OR p_occurred_at IS NULL THEN
    RAISE EXCEPTION 'PG_KAPI_IC_HATA:%', jsonb_build_object('sebep', 'GECERSIZ_OLAY_PARAMETRESI',
      'source_type', p_source_type, 'source_id', p_source_id, 'occurred_at', p_occurred_at);
  END IF;

  IF v_karar = 'ACK_PENDING' THEN
    v_toh_id := p_kapi->>'tohumlama_id';
    IF v_toh_id IS NULL THEN
      RAISE EXCEPTION 'PG_KAPI_IC_HATA:%', jsonb_build_object('sebep', 'ACK_TOHUMLAMA_YOK', 'kapi', p_kapi);
    END IF;
  END IF;

  INSERT INTO public.pg_application_event
    (source_type, source_id, hayvan_id, stok_id, drug_product_id, occurred_at,
     karar, ack_tohumlama_id, ack_gerekce)
  VALUES
    (p_source_type, p_source_id, p_hayvan_id, p_stok_id, p_drug_product_id, p_occurred_at,
     v_karar, v_toh_id, CASE WHEN v_karar = 'ACK_PENDING' THEN p_gerekce END)
  ON CONFLICT (source_type, source_id) DO NOTHING
  RETURNING id INTO v_event_id;

  IF v_event_id IS NULL THEN
    RETURN NULL;  -- T15: aynı kaynak zaten kayıtlı; türev iş yok
  END IF;

  IF v_karar = 'ACK_PENDING' THEN
    -- Onaylanan (Bekliyor) tohumlamanın açık gebelik kontrolleri kapanır; tohumlama Bekliyor kalır.
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true, kapatan_ref = 'PG_ONAY:' || v_event_id::text
     WHERE kaynak = 'TOH-' || v_toh_id
       AND gorev_tipi = 'GEBELIK_KONTROL'
       AND COALESCE(tamamlandi, false) = false
       AND COALESCE(iptal, false) = false;
    GET DIAGNOSTICS v_iptal = ROW_COUNT;

    INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
    VALUES ('PG_APPLICATION_ACKNOWLEDGED', p_hayvan_id, v_event_id::text, 'pg_application_event',
            jsonb_build_object(
              'event_id', v_event_id, 'tohumlama_id', v_toh_id, 'gerekce', p_gerekce,
              'iptal_gorev_sayisi', v_iptal,
              'source_type', p_source_type, 'source_id', p_source_id),
            '{}'::jsonb);
  END IF;

  PERFORM public._pg_sonrasi_tohumlama(v_event_id);

  -- E3 kancası 20261013000002 ile kalktı (karar 3: PG uzatır, vaka açık kalır).

  RETURN v_event_id;
END;
$function$;

-- ── 3. treatment_day_tamamla: DROP eski imza + CREATE (canlı gövde + kapı) ─
-- Canlı gövde AYNI; eklenen: (a) imza sonuna p_pg_onay/p_pg_gerekce,
-- (b) İLK yazmadan ÖNCE PG kapısı (gündeki uygulanan doğrudan PG kalemleri;
-- seans satırları seans_tamamla P5 kapısından geçti; bu çağrıda uygulanmadi
-- işaretlenenler uygulanmaz), (c) tamamlamadan SONRA uygulanan her doğrudan
-- PG kalemi için TEDAVI_GUN olayı (+48 s TAI).
DROP FUNCTION IF EXISTS public.treatment_day_tamamla(uuid, text, uuid[]);
CREATE FUNCTION public.treatment_day_tamamla(p_day_id uuid, p_not text DEFAULT NULL, p_uygulanmadi_ids uuid[] DEFAULT '{}', p_pg_onay boolean DEFAULT NULL, p_pg_gerekce text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_day        public.treatment_days%ROWTYPE;
  v_seans_sayisi int;
  v_tamam       int;
  v_uygulanmadi int;
  v_onceki      boolean;
  v_admin_id    uuid;
  v_case_animal text;
  v_pg_hayvan   text;
  v_pg_kupe     text;
  v_pg_kalem    record;
  v_pg_ids      uuid[] := '{}';
  v_kapi        jsonb;
BEGIN
  SELECT * INTO v_day FROM public.treatment_days WHERE id = p_day_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Tedavi gunu bulunamadi: %', p_day_id; END IF;
  IF v_day.tamamlandi THEN
    RETURN jsonb_build_object('ok', true, 'day_id', p_day_id, 'mesaj', 'Zaten tamamlanmis (idempotent)');
  END IF;
  SELECT animal_id INTO v_case_animal FROM public.cases WHERE id = v_day.case_id;
  SELECT EXISTS(
    SELECT 1 FROM public.treatment_days
    WHERE case_id = v_day.case_id AND day_no < v_day.day_no
      AND (tamamlandi IS NULL OR tamamlandi = false)
  ) INTO v_onceki;
  IF v_onceki THEN RAISE EXCEPTION 'Onceki tedavi gunleri tamamlanmadan bu gun tamamlanamaz'; END IF;
  v_seans_sayisi := COALESCE(v_day.seans_sayisi, 1);
  IF v_seans_sayisi > 1 THEN
    SELECT COUNT(*) FILTER (WHERE uygulama_tamamlandi_at IS NOT NULL),
           COUNT(*) FILTER (WHERE uygulanmadi = true)
    INTO v_tamam, v_uygulanmadi
    FROM public.treatment_day_uygulamalar WHERE treatment_day_id = p_day_id;
    IF (v_tamam + v_uygulanmadi + COALESCE(array_length(p_uygulanmadi_ids, 1), 0)) < v_seans_sayisi THEN
      RAISE EXCEPTION 'Tum seanslar tamamlanmadi';
    END IF;
  END IF;
  -- ── PG kapısı (hizli_uygulama deyimi): İLK yazmadan ÖNCE ──
  SELECT c.animal_id INTO v_pg_hayvan FROM public.cases c WHERE c.id = v_day.case_id;
  FOR v_pg_kalem IN
    SELECT da.id AS id, da.stok_id AS stok_id, da.drug_product_id AS drug_product_id
      FROM public.drug_administrations da
     WHERE da.treatment_day_id = p_day_id
       AND da.seans_admin_id IS NULL
       AND da.uygulanmadi IS DISTINCT FROM true
       AND NOT (da.id = ANY (COALESCE(p_uygulanmadi_ids, '{}'::uuid[])))
       AND public._pg_urun_durumu(da.stok_id, da.drug_product_id) = 'PG'
  LOOP
    v_kapi := public._pg_kapi(v_pg_hayvan, v_pg_kalem.stok_id, v_pg_kalem.drug_product_id, COALESCE(p_pg_onay, false));
    IF v_kapi->>'karar' IN ('BLOCK_PREGNANT', 'REQUIRE_ACK_PENDING', 'BLOCK_CATALOG_UNRESOLVED') THEN
      SELECT h.kupe_no INTO v_pg_kupe FROM public.hayvanlar h WHERE h.id = v_pg_hayvan;
      RAISE EXCEPTION 'PG_KAPI:%:%', v_kapi->>'karar',
        public._pg_kapi_detay(v_kapi, v_pg_hayvan, v_pg_kupe);
    END IF;
    v_pg_ids := v_pg_ids || v_pg_kalem.id;
  END LOOP;
  IF array_length(p_uygulanmadi_ids, 1) > 0 THEN
    FOREACH v_admin_id IN ARRAY p_uygulanmadi_ids LOOP
      UPDATE public.drug_administrations SET uygulanmadi=true WHERE id=v_admin_id AND treatment_day_id=p_day_id AND uygulanmadi IS DISTINCT FROM true;
      UPDATE public.drug_administrations SET uygulanmadi=true WHERE seans_admin_id=v_admin_id AND treatment_day_id=p_day_id AND uygulanmadi IS DISTINCT FROM true;
      UPDATE public.treatment_day_uygulamalar SET uygulama_tamamlandi_at=COALESCE(uygulama_tamamlandi_at, now()), uygulama_notu=COALESCE(uygulama_notu, p_not), gerceklesme_saati=COALESCE(gerceklesme_saati, NOW()::time), updated_at=now() WHERE id=v_admin_id AND uygulama_tamamlandi_at IS NULL AND uygulanmadi=false;
      UPDATE public.stok_hareket sh SET iptal=true FROM public.drug_administrations da WHERE (da.seans_admin_id=v_admin_id OR da.id=v_admin_id) AND da.treatment_day_id=p_day_id AND sh.notlar='drug_admin:'||da.id::text AND sh.iptal=false;
    END LOOP;
  END IF;
  -- ═══ FIX: tamamlandi olarak işaretle + audit ═══
  UPDATE public.treatment_days SET tamamlandi=true, tamamlanma_tarihi=now(), tamamlanma_notu=p_not WHERE id=p_day_id;
  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('TEDAVI_GUN_TAMAMLA', v_case_animal, p_day_id::text, 'treatment_days',
    jsonb_build_object('olusturulan','[]'::jsonb, 'guncellenen', jsonb_build_array(jsonb_build_object('tablo','treatment_days','id',p_day_id::text)), 'silinen','[]'::jsonb),
    format('Tedavi günü %s tamamlandı', p_day_id));
  -- ── PG olayı = uygulama anı: kapıdan geçen her doğrudan PG kalemi için ──
  -- Savunma: aynı kalem için ILAC_EKLE olayı zaten varsa atla (çift olay yok).
  FOR v_pg_kalem IN
    SELECT da.id AS id, da.stok_id AS stok_id, da.drug_product_id AS drug_product_id
      FROM public.drug_administrations da
     WHERE da.id = ANY (v_pg_ids)
       AND NOT EXISTS (SELECT 1 FROM public.pg_application_event e
                        WHERE e.source_type = 'ILAC_EKLE' AND e.source_id = da.id::text)
  LOOP
    v_kapi := public._pg_kapi(v_pg_hayvan, v_pg_kalem.stok_id, v_pg_kalem.drug_product_id, COALESCE(p_pg_onay, false));
    PERFORM public._pg_olay_isle('TEDAVI_GUN', v_pg_kalem.id::text, v_pg_hayvan,
      v_pg_kalem.stok_id, v_pg_kalem.drug_product_id, now(), v_kapi, p_pg_gerekce);
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'day_id', p_day_id, 'mesaj', 'Tedavi günü tamamlandı');
END;
$function$;
REVOKE ALL ON FUNCTION public.treatment_day_tamamla(uuid, text, uuid[], boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.treatment_day_tamamla(uuid, text, uuid[], boolean, text) TO authenticated, service_role;

-- ── 4. add_drug_administration: DROP eski imza + CREATE (canlı gövde + kapı) ─
-- Canlı gövde AYNI; eklenen: (a) imza sonuna p_pg_onay/p_pg_gerekce,
-- (b) INSERT'ten ÖNCE PG kapısı, (c) günü ZATEN tamamlanmış (treatment_days.tamamlandi,
-- canlı şemada MEASURED 2026-10-13) ya da güne bağlı olmayan kalemde ILAC_EKLE olayı
-- (+48 s TAI). Tamamlanmamış güne eklenen kalemin olayını treatment_day_tamamla yazar
-- (çift olay yok; savunma: tamamla döngüsü ILAC_EKLE'si olan kalemi NOT EXISTS ile atlar).
DROP FUNCTION IF EXISTS public.add_drug_administration(uuid, uuid, text, numeric, text, text);
CREATE FUNCTION public.add_drug_administration(p_day_id uuid, p_drug_product_id uuid, p_stok_id text, p_dose numeric, p_unit text, p_route text DEFAULT NULL, p_pg_onay boolean DEFAULT NULL, p_pg_gerekce text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id uuid;
  v_hayvan text;
  v_tarih date;
  v_gun_tamamli boolean := false;
  v_kapi jsonb;
  v_kupe text;
BEGIN
  SELECT c.animal_id, td.treatment_date, COALESCE(td.tamamlandi, false) INTO v_hayvan, v_tarih, v_gun_tamamli
    FROM public.treatment_days td
    JOIN public.cases c ON c.id = td.case_id
   WHERE td.id = p_day_id;
  -- ── PG kapısı (hizli_uygulama deyimi): İLK yazmadan (INSERT) ÖNCE ──
  IF public._pg_urun_durumu(p_stok_id, p_drug_product_id) = 'PG' THEN
    v_kapi := public._pg_kapi(v_hayvan, p_stok_id, p_drug_product_id, COALESCE(p_pg_onay, false));
    IF v_kapi->>'karar' IN ('BLOCK_PREGNANT', 'REQUIRE_ACK_PENDING', 'BLOCK_CATALOG_UNRESOLVED') THEN
      SELECT h.kupe_no INTO v_kupe FROM public.hayvanlar h WHERE h.id = v_hayvan;
      RAISE EXCEPTION 'PG_KAPI:%:%', v_kapi->>'karar',
        public._pg_kapi_detay(v_kapi, v_hayvan, v_kupe);
    END IF;
  END IF;

  INSERT INTO public.drug_administrations (treatment_day_id, drug_product_id, stok_id, dose, unit, route)
  VALUES (p_day_id, p_drug_product_id, p_stok_id, p_dose, p_unit, p_route)
  RETURNING id INTO v_id;

  IF p_stok_id IS NOT NULL AND p_dose > 0 THEN
    INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar)
    VALUES (p_stok_id, 'Tedavi', p_dose, 'drug_admin:' || v_id::text);
  END IF;

  -- ── PG olayı = uygulama anı: yalnız gün ZATEN tamamlanmışsa ya da güne bağlı değilse ──
  -- Tamamlanmamış güne eklenen kalemin olayını treatment_day_tamamla yazar (çift olay yok).
  IF v_kapi IS NOT NULL AND (v_tarih IS NULL OR v_gun_tamamli) THEN
    PERFORM public._pg_olay_isle('ILAC_EKLE', v_id::text, v_hayvan, p_stok_id,
      p_drug_product_id, now(), v_kapi, p_pg_gerekce);
  END IF;

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.add_drug_administration(uuid, uuid, text, numeric, text, text, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_drug_administration(uuid, uuid, text, numeric, text, text, boolean, text) TO authenticated, service_role;

-- ── 5. tedavi_sablon_uygula: DROP eski imza + CREATE (canlı gövde + kapı) ──
-- Canlı gövde AYNI; eklenen: (a) imza sonuna p_pg_onay/p_pg_gerekce,
-- (b) İLK yazmadan ÖNCE PG kapısı (şablonun PG kalemleri). OLAY YOK:
-- şablon yalnız planlar; kalemler gün tamamlanınca treatment_day_tamamla
-- üzerinden olay doğurur (çift olay olmaz).
DROP FUNCTION IF EXISTS public.tedavi_sablon_uygula(uuid, uuid, date);
CREATE FUNCTION public.tedavi_sablon_uygula(p_case_id uuid, p_sablon_id uuid, p_baslangic_tarihi date DEFAULT NULL, p_pg_onay boolean DEFAULT NULL, p_pg_gerekce text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_case         record;
  v_gun_no       smallint;
  v_date         date;
  v_sessions     jsonb;
  v_atlanan      jsonb := '[]'::jsonb;
  v_gun_atlanan  jsonb;
  v_gun_sayisi   int := 0;
  v_seans_sayisi int := 0;
  v_sablon_hayvan text;
  v_sablon_kupe   text;
  v_sablon_kalem  record;
  v_kapi          jsonb;
BEGIN
  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadı'); END IF;
  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakaya şablon uygulanamaz');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.tedavi_sablonu WHERE id = p_sablon_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Şablon bulunamadı');
  END IF;

  -- 000018 (cila2 C1): OVSYNC-aile şablonu kısır hayvana uygulanamaz.
  -- Fail-closed: yumuşak dönüş değil, KISIR_HAYVAN_OVSYNC_YASAK exception.
  PERFORM public._kisir_ovsync_guard(
    v_case.animal_id,
    EXISTS (SELECT 1 FROM public.tedavi_sablonu s
             WHERE s.id = p_sablon_id AND s.protokol_ailesi = 'OVSYNC'));

  -- ── PG kapısı (hizli_uygulama deyimi): İLK yazmadan ÖNCE ──
  SELECT c.animal_id INTO v_sablon_hayvan FROM public.cases c WHERE c.id = p_case_id;
  FOR v_sablon_kalem IN
    SELECT k.stok_id AS stok_id, k.drug_product_id AS drug_product_id
      FROM public.tedavi_sablonu_kalem k
     WHERE k.sablon_id = p_sablon_id
       AND (k.drug_product_id IS NULL OR EXISTS (SELECT 1 FROM public.drug_products dp WHERE dp.id = k.drug_product_id))
       AND (k.stok_id IS NULL OR EXISTS (SELECT 1 FROM public.stok s WHERE s.id = k.stok_id))
       AND public._pg_urun_durumu(k.stok_id, k.drug_product_id) = 'PG'
  LOOP
    v_kapi := public._pg_kapi(v_sablon_hayvan, v_sablon_kalem.stok_id, v_sablon_kalem.drug_product_id, COALESCE(p_pg_onay, false));
    IF v_kapi->>'karar' IN ('BLOCK_PREGNANT', 'REQUIRE_ACK_PENDING', 'BLOCK_CATALOG_UNRESOLVED') THEN
      SELECT h.kupe_no INTO v_sablon_kupe FROM public.hayvanlar h WHERE h.id = v_sablon_hayvan;
      RAISE EXCEPTION 'PG_KAPI:%:%', v_kapi->>'karar',
        public._pg_kapi_detay(v_kapi, v_sablon_hayvan, v_sablon_kupe);
    END IF;
  END LOOP;

  FOR v_gun_no IN
    SELECT DISTINCT gun_no FROM public.tedavi_sablonu_kalem
    WHERE sablon_id = p_sablon_id ORDER BY gun_no
  LOOP
    v_date := COALESCE(p_baslangic_tarihi, v_case.start_date) + (v_gun_no - 1);

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
             'planned_time',    to_char(k.planned_time,'HH24:MI'),
             'stok_id',         k.stok_id,
             'drug_product_id', k.drug_product_id,
             'dose',            k.dose,
             'unit',            k.unit,
             'route',           k.route
           ) ORDER BY k.planned_time), '[]'::jsonb)
    INTO v_sessions
    FROM public.tedavi_sablonu_kalem k
    WHERE k.sablon_id = p_sablon_id AND k.gun_no = v_gun_no
      AND (k.drug_product_id IS NULL OR EXISTS (SELECT 1 FROM public.drug_products dp WHERE dp.id = k.drug_product_id))
      AND (k.stok_id IS NULL OR EXISTS (SELECT 1 FROM public.stok s WHERE s.id = k.stok_id));

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
             'gun_no', k.gun_no,
             'planned_time', to_char(k.planned_time,'HH24:MI'),
             'neden', 'silinmiş ilaç/stok')), '[]'::jsonb)
    INTO v_gun_atlanan
    FROM public.tedavi_sablonu_kalem k
    WHERE k.sablon_id = p_sablon_id AND k.gun_no = v_gun_no
      AND ((k.drug_product_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.drug_products dp WHERE dp.id = k.drug_product_id))
        OR (k.stok_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.stok s WHERE s.id = k.stok_id)));
    IF jsonb_array_length(v_gun_atlanan) > 0 THEN
      v_atlanan := v_atlanan || v_gun_atlanan;
    END IF;

    IF jsonb_array_length(v_sessions) > 0 THEN
      PERFORM public.add_treatment_day_with_sessions(p_case_id, v_date, v_sessions, NULL);
      v_gun_sayisi   := v_gun_sayisi + 1;
      v_seans_sayisi := v_seans_sayisi + jsonb_array_length(v_sessions);
    END IF;
  END LOOP;

  -- S-3 provenance (bayraktan bağımsız, salt metadata): vakanın İLK şablon
  -- uygulaması damgalanır; source_template_id doluysa ikinci uygulama BU
  -- provenance'ı (source_template_id, protocol_snapshot) EZMEZ (R3.1) — dal
  -- yalnız source_template_id IS NULL iken çalışır.
  UPDATE public.cases c
     SET source_template_id = t.id,
         protocol_family    = COALESCE(t.protokol_ailesi, c.protocol_family),
         protocol_snapshot  = jsonb_build_object(
           'sablon_id',       t.id,
           'ad',              t.ad,
           'protokol_ailesi', t.protokol_ailesi,
           'tohumlama_plani', t.tohumlama_plani,
           'kalemler', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
                                 'gun_no',          k.gun_no,
                                 'planned_time',    to_char(k.planned_time,'HH24:MI'),
                                 'stok_id',         k.stok_id,
                                 'drug_product_id', k.drug_product_id,
                                 'dose',            k.dose,
                                 'unit',            k.unit,
                                 'route',           k.route
                               ) ORDER BY k.gun_no, k.planned_time, k.id), '[]'::jsonb)
                          FROM public.tedavi_sablonu_kalem k
                         WHERE k.sablon_id = t.id),
           'uygulama_at',     now(),
           'baslangic',       COALESCE(p_baslangic_tarihi, v_case.start_date))
    FROM public.tedavi_sablonu t
   WHERE c.id = p_case_id
     AND c.source_template_id IS NULL
     AND t.id = p_sablon_id;

  -- R3.1 (#12): source_template_id ZATEN doluysa (ikinci+ şablon uygulaması)
  -- yukarıdaki dal atlanır — provenance/snapshot ezilmez. Ama protocol_family
  -- hâlâ NULL ise (ör. ilk uygulanan şablon ailesizdi: Mastit gibi) ve bu
  -- şablonun ailesi doluysa, YALNIZ protocol_family ayrı bir UPDATE ile
  -- doldurulur; source_template_id ve protocol_snapshot bu dalda DOKUNULMAZ.
  UPDATE public.cases c
     SET protocol_family = t.protokol_ailesi
    FROM public.tedavi_sablonu t
   WHERE c.id = p_case_id
     AND c.source_template_id IS NOT NULL
     AND c.protocol_family IS NULL
     AND t.protokol_ailesi IS NOT NULL
     AND t.id = p_sablon_id;

  RETURN jsonb_build_object('ok', true,
    'gun_sayisi', v_gun_sayisi, 'seans_sayisi', v_seans_sayisi, 'atlanan', v_atlanan);
END;
$function$;
REVOKE ALL ON FUNCTION public.tedavi_sablon_uygula(uuid, uuid, date, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tedavi_sablon_uygula(uuid, uuid, date, boolean, text) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;
