-- ============================================================================
-- Migration: 20260925100005_bagimsiz_pg_vaka_kapat
-- Tarih: 2026-09-25 · Erteleme-genel turu E3 (zarf E3 / plan-db.md Adım 4)
-- Etkiler:
--   1. cases.close_reason CHECK kısıtı: uzaya 'PG' eklenir
--      (RA notu "gövde içi ~83" EKSİKTİ — uzay AYNI ZAMANDA DB CHECK kısıtında
--      yaşıyor [OBSERVED \d cases: cases_close_reason_check]; iki yer birden)
--   2. public._vaka_kapat yeniden tanımı (canlı DEMO gövdesinden başlar — 000008
--      tuzağı): 'PG' dalı + CASE_CLOSED_BY_PG audit
--   3. public._pg_olay_isle yeniden tanımı (canlı gövde + E3 kapatma kancası)
--
-- Amaç (S3, RA VERDICT: IMPLEMENT): plan uygulama ortasında BAĞIMSIZ bir PG
--   girişi (hızlı uygulama / toplu ilaç) hayvanın AKTİF senkron protokol
--   vakasını kapatır; protokolün KENDİ PG seansı KAPATMAZ.
--
-- Ayırıcı (RA §E3/3): pg_application_event.source_type
--   - HIZLI_UYGULAMA / TOPLU_ILAC → bağımsız → aktif protocol_family vakası
--     _vaka_kapat(vaka,'PG')
--   - TEDAVI_SEANS → source_id çözümlenir (treatment_day_uygulamalar.case_id):
--     hayvanın aktif protokol vakasıyla AYNI vaka → protokolün kendi PG'si →
--     KAPATMA (vaka AÇIK kalır); FARKLI vaka → bağımsız sayılır (RA assumption,
--     plan 4c: sahip tersini isterse yalnız karşılaştırma koşulu değişir).
--
-- Sıra (plan 4b): kanca _pg_sonrasi_tohumlama BAŞARILI döndükten SONRA —
--   şablon TAI o ana kadar PG_YERINE ile kapalı (_vaka_kapat 5b no-op düşer);
--   PG+48 TAI (kaynak 'PG_TOHUMLAMA:<event>') 5b filtresine takılmaz → YAŞAR.
--   Yalnız protocol_family IS NOT NULL AKTİF vaka (tohumlama_kaydet S-7 deseni);
--   Mastit vb. protocol_family NULL vakalar dokunulmaz.
--
-- Kenar durumlar (plan 4d; DONE sahip kapısına listelenir):
--   (i) ILAC "25. Gün PG" hatırlatma görevi görev-tamamlama uygulamasıyla
--       kapanırsa hizli_uygulama'dan geçer → bağımsız sınıflanır → aktif ovsync
--       vakasını kapatır (tıbben tutarlı, bilinçli davranış).
--   (ii) geri_al uyumu: bağımsız PG geri alınınca (trg_uygulama_log_pg_geri_al)
--       kapatılan vaka geri AÇILMAZ — v1 kararı: kapalı kalır.
--
-- Geri alınabilir: DROP CONSTRAINT yeniden eski liste + önceki gövdelere dönüş.
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- ── 1) close_reason uzayı: 'PG' ────────────────────────────────────────
-- IF EXISTS: yerel LSP aynası tabloları constraint'siz kurar (kısıt yalnız
-- canlıda); demo/prod'da kısıt VAR ve yenisiyle değiştirilir.
ALTER TABLE public.cases DROP CONSTRAINT IF EXISTS cases_close_reason_check;
ALTER TABLE public.cases ADD CONSTRAINT cases_close_reason_check
  CHECK (close_reason = ANY (ARRAY['ERKEN_KAPANIS'::text, 'TOHUMLAMA'::text, 'PG'::text]));

-- ── 2) _vaka_kapat: canlı gövde + 'PG' dalı ────────────────────────────
CREATE OR REPLACE FUNCTION public._vaka_kapat(p_case_id uuid, p_close_reason text, p_not text, p_ref jsonb)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_remaining_count int;
  v_case            record;
  v_iptal_nedeni    text;
  v_n               int;
  v_stok_iade       int := 0;
  v_iptal_gorev     int := 0;
  v_gerceklesen     int;
  v_closed_at       timestamptz;
BEGIN
  IF p_close_reason IS NULL OR p_close_reason NOT IN ('ERKEN_KAPANIS', 'TOHUMLAMA', 'PG') THEN
    RAISE EXCEPTION '_vaka_kapat: geçersiz close_reason: %', p_close_reason;
  END IF;

  -- Kilit (yazma değil). Kilit sırası (MK9): vaka (burada) → seans/stok/gün
  -- (aşağıdaki UPDATE'ler) → görev (adım 5/5b) → vaka satırının kendisi (zaten
  -- kilitli). ERKEN_KAPANIS canlıdaki gibi durumdan bağımsız ilerler — TEK
  -- istisna: tohumlama ile kapanmış vaka (R3.1, T21) → no-op. TOHUMLAMA/PG zaten
  -- kapalı/olmayan vakada hiçbir şey yazmaz (E3: PG kapanışı da tek-seferlik).
  SELECT id, animal_id, status, close_reason INTO v_case
    FROM public.cases WHERE id = p_case_id FOR UPDATE;
  IF p_close_reason IN ('TOHUMLAMA', 'PG') AND (NOT FOUND OR v_case.status IS DISTINCT FROM 'active') THEN
    RETURN jsonb_build_object('case_id', p_case_id, 'zaten_kapali', true);
  END IF;
  IF p_close_reason = 'ERKEN_KAPANIS' AND FOUND
     AND v_case.status = 'closed' AND v_case.close_reason = 'TOHUMLAMA' THEN
    -- Yazma yok, audit yok: tek audit CASE_CLOSED_BY_TOHUMLAMA kalır, iptal_nedeni
    -- 'Tohumlama ile sonlandırıldı' ezilmez. Diğer kapalı vakalar canlıdaki gibi
    -- yeniden yazılır (MK5).
    RETURN jsonb_build_object('case_id', p_case_id, 'zaten_kapali', true,
      'iptal_seans', 0, 'iptal_gorev', 0, 'gerceklesen_seans', NULL, 'stok_iade', 0);
  END IF;

  v_iptal_nedeni := CASE p_close_reason
    WHEN 'ERKEN_KAPANIS' THEN 'Vaka erken kapatildi' || COALESCE(': ' || p_not, '')
    WHEN 'PG' THEN 'Bağımsız PG uygulaması ile sonlandırıldı' || COALESCE(': ' || p_not, '')
    ELSE 'Tohumlama ile sonlandırıldı'
  END;

  UPDATE public.stok_hareket sh
  SET iptal = true
  FROM public.drug_administrations da
  JOIN public.treatment_day_uygulamalar tdu
    ON tdu.id = da.seans_admin_id
  WHERE tdu.case_id = p_case_id
    AND tdu.uygulanmadi = false
    AND tdu.uygulama_tamamlandi_at IS NULL
    AND sh.notlar = 'drug_admin:' || da.id::text
    AND sh.iptal = false;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_stok_iade := v_stok_iade + v_n;

  UPDATE public.stok_hareket sh
  SET iptal = true
  FROM public.drug_administrations da
  JOIN public.treatment_days td ON td.id = da.treatment_day_id
  WHERE td.case_id = p_case_id
    AND da.seans_admin_id IS NULL
    AND td.tamamlandi = false
    AND (da.uygulanmadi IS NULL OR da.uygulanmadi = false)
    AND sh.notlar = 'drug_admin:' || da.id::text
    AND sh.iptal = false;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_stok_iade := v_stok_iade + v_n;

  UPDATE public.treatment_day_uygulamalar
  SET uygulanmadi = true,
      iptal_nedeni = v_iptal_nedeni,
      updated_at = now()
  WHERE case_id = p_case_id
    AND uygulanmadi = false
    AND uygulama_tamamlandi_at IS NULL;

  GET DIAGNOSTICS v_remaining_count = ROW_COUNT;

  UPDATE public.drug_administrations da
  SET uygulanmadi = true
  FROM public.treatment_day_uygulamalar tdu
  WHERE tdu.id = da.seans_admin_id
    AND tdu.case_id = p_case_id
    AND tdu.uygulanmadi = true
    AND da.uygulanmadi IS DISTINCT FROM (true);

  UPDATE public.drug_administrations da
  SET uygulanmadi = true
  FROM public.treatment_days td
  WHERE td.id = da.treatment_day_id
    AND td.case_id = p_case_id
    AND da.seans_admin_id IS NULL
    AND td.tamamlandi = false
    AND da.uygulanmadi IS DISTINCT FROM (true);

  UPDATE public.treatment_days
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE case_id = p_case_id AND tamamlandi = false;

  -- 5. gorev_log kalan acik gorevler — gorev_tipi guard (JSON-olmayan aciklama'lari cast'ten ele)
  UPDATE public.gorev_log g
  SET tamamlandi = true, tamamlanma_tarihi = now()
  FROM public.treatment_days td
  WHERE td.case_id = p_case_id
    AND g.gorev_tipi IN ('TEDAVI_GUN','TEDAVI_SEANS')
    AND (CASE WHEN g.aciklama IS JSON OBJECT
              THEN (g.aciklama::jsonb->>'day_id') END)::uuid = td.id
    AND g.tamamlandi = false;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_iptal_gorev := v_iptal_gorev + v_n;

  -- 5b. Planlı tohumlama gorevi bagimsiz (parent_id/day_id yok) — adim 5'in
  -- treatment_days JOIN'i onu GOREMEZ. Vaka kapaninca acikta kalmasin.
  -- (E3 sırası gereği bağımsız PG akışında şablon TAI zaten PG_YERINE ile kapalı:
  -- no-op; PG+48 TAI kaynağı 'PG_TOHUMLAMA:<event>' olduğundan filtreye takılmaz.)
  UPDATE public.gorev_log
  SET iptal = true, tamamlandi = true, tamamlanma_tarihi = now()
  WHERE gorev_tipi = 'TOHUMLAMA_PLANLI'
    AND kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:' || p_case_id::text || ':%'
    AND tamamlandi = false AND iptal = false;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  v_iptal_gorev := v_iptal_gorev + v_n;

  UPDATE public.cases
  SET status = 'closed', closed_at = now(), close_reason = p_close_reason
  WHERE id = p_case_id;

  SELECT count(*) INTO v_gerceklesen
    FROM public.treatment_day_uygulamalar
   WHERE case_id = p_case_id AND uygulama_tamamlandi_at IS NOT NULL;

  IF p_close_reason = 'ERKEN_KAPANIS' THEN
    INSERT INTO public.islem_log(id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
    VALUES (
      gen_random_uuid()::text, 'CASE_CLOSED_EARLY',
      (SELECT animal_id FROM public.cases WHERE id = p_case_id),
      p_case_id::text, 'cases',
      jsonb_build_object(
        'iptal_edilen_seans', v_remaining_count,
        'stok_iade_edildi', v_remaining_count > 0,
        'not', p_not
      )
    );
  ELSIF p_close_reason = 'PG' THEN
    -- E3 (S3): bağımsız PG kapanışı — TOHUMLAMA dalının payload kalıbı,
    -- olay referansı p_ref->>'pg_event_id' üzerinden.
    v_closed_at := now();
    INSERT INTO public.islem_log(tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
    VALUES (
      'CASE_CLOSED_BY_PG', v_case.animal_id,
      p_case_id::text, 'cases',
      jsonb_build_object(
        'case_id',           p_case_id,
        'pg_event_id',       p_ref->>'pg_event_id',
        'close_reason',      p_close_reason,
        'iptal_seans',       v_remaining_count,
        'iptal_gorev',       v_iptal_gorev,
        'gerceklesen_seans', v_gerceklesen,
        'closed_at',         v_closed_at
      ),
      '{}'::jsonb
    );
  ELSE
    v_closed_at := now();
    INSERT INTO public.islem_log(tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot)
    VALUES (
      'CASE_CLOSED_BY_TOHUMLAMA', v_case.animal_id,
      p_case_id::text, 'cases',
      jsonb_build_object(
        'case_id',           p_case_id,
        'tohumlama_id',      p_ref->>'tohumlama_id',
        'close_reason',      p_close_reason,
        'iptal_seans',       v_remaining_count,
        'iptal_gorev',       v_iptal_gorev,
        'gerceklesen_seans', v_gerceklesen,
        'closed_at',         v_closed_at
      ),
      '{}'::jsonb
    );
  END IF;

  RETURN jsonb_build_object(
    'case_id',           p_case_id,
    'iptal_seans',       v_remaining_count,
    'iptal_gorev',       v_iptal_gorev,
    'gerceklesen_seans', v_gerceklesen,
    'stok_iade',         v_stok_iade
  );
END;
$function$;

-- ── 3) _pg_olay_isle: canlı gövde + E3 bağımsız-PG kapatma kancası ────
CREATE OR REPLACE FUNCTION public._pg_olay_isle(p_source_type text, p_source_id text, p_hayvan_id text, p_stok_id text, p_drug_product_id uuid, p_occurred_at timestamp with time zone, p_kapi jsonb, p_gerekce text)
RETURNS uuid
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_karar      text;
  v_pg         text;
  v_event_id   uuid;
  v_toh_id     text;
  v_iptal      integer := 0;
  -- E3 kancası değişkenleri
  v_seans_case uuid;
  v_vaka       record;
  v_kapatan    integer := 0;
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
  IF p_source_type IS NULL OR p_source_type NOT IN ('HIZLI_UYGULAMA', 'TEDAVI_SEANS', 'TOPLU_ILAC')
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

  -- ── E3 (S3): bağımsız PG → aktif senkron protokol vakasını kapat ──────
  -- Ayırıcı source_type (RA §E3/3). Sıra: _pg_sonrasi_tohumlama SONRASI —
  -- PG+48 TAI (kaynak 'PG_TOHUMLAMA:<event>') _vaka_kapat 5b filtresine
  -- takılmaz, YAŞAR. TEDAVI_SEANS olayında seansın KENDİ vakası hariç tutulur
  -- (protokolün kendi PG'si → vaka AÇIK kalır; farklı vaka → bağımsız).
  -- Seans çözülemezse (v_seans_case NULL) bağımsız sayılır — fail-safe.
  -- Yalnız protocol_family IS NOT NULL AKTİF vaka (S-7 deseni): Mastit vb.
  -- protocol_family NULL vakalar ve OVSYNC_BASLAT görevleri dokunulmaz.
  IF p_source_type = 'TEDAVI_SEANS' THEN
    SELECT tdu.case_id INTO v_seans_case
      FROM public.treatment_day_uygulamalar tdu
     WHERE tdu.id::text = p_source_id;
  END IF;

  FOR v_vaka IN
    SELECT c.id
      FROM public.cases c
     WHERE c.animal_id = p_hayvan_id
       AND c.status = 'active'
       AND c.protocol_family IS NOT NULL
       AND c.id IS DISTINCT FROM (v_seans_case)
     ORDER BY c.start_date, c.id
     FOR UPDATE
  LOOP
    PERFORM public._vaka_kapat(v_vaka.id, 'PG',
      'Bağımsız PG (' || p_source_type || ')',
      jsonb_build_object('pg_event_id', v_event_id));
    v_kapatan := v_kapatan + 1;
  END LOOP;

  RETURN v_event_id;
END;
$function$;

-- ── Kapı kuralları: iç yardımcılar — EXECUTE grant'i YOK, PUBLIC/anon kapalı
REVOKE ALL ON FUNCTION public._vaka_kapat(uuid, text, text, jsonb) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public._pg_olay_isle(text, text, text, text, uuid, timestamp with time zone, jsonb, text) FROM PUBLIC, anon;

COMMIT;
