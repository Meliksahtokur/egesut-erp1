-- 20260923000004_ovsync_pg_uygulama_kapisi.sql
-- SPEC: docs/plans/2026-09-23-ovsync-pg-tohumlama-SPEC.md (R3) — S-4 "Uygulama yolları"
-- Kapsam: PG güvenlik kapısı + gerçekleşme kaydı dört uygulama yoluna bağlanır:
--   hizli_uygulama         + p_pg_onay boolean DEFAULT false, p_pg_gerekce text DEFAULT NULL
--                            (eski 6'lı imza DROP)
--   seans_tamamla          + p_pg_onay, p_pg_gerekce (eski 3'lü imza DROP); kapı yalnız
--                            p_uygulanmadi=false; hayvan = cases.animal_id
--   bulk_ilac              + p_pg_onaylar text[] DEFAULT '{}', p_pg_gerekce (eski 4'lü imza DROP);
--                            satır bazında atlama + applied[]/blocked[]/requires_ack[]
--   hizli_uygulama_geri_al imza aynı; event geri_alindi_at + PG görevi iptal +
--                            PG_CYCLE_REVIEW_REQUIRED (yalnız yerine geçilmiş görev varsa)
--   _pg_kapi_detay         iç yardımcı: PG_KAPI hata/rapor json'u (hayvan_id, kupe_no,
--                            tohumlama_id, tohumlama_tarihi, gun, ...)
-- Kanonik taban: canlı prod pg_get_functiondef (2026-09-23). Eski satırlar bayt-bayt
--   korunur; yeni kod yalnız `IF v_pg_aktif THEN … END IF;` blokları olarak eklenmiştir
--   (v_pg_aktif = public._ovsync_pg_aktif(), fonksiyon başında TEK kez okunur) → MK5:
--   bayrak kapalıyken yan etkiler eski gövdeyle aynıdır.
-- MK6: tekil yolda (hizli_uygulama, seans_tamamla) blok → RAISE EXCEPTION
--   'PG_KAPI:<BLOCK_PREGNANT|REQUIRE_ACK_PENDING|BLOCK_CATALOG_UNRESOLVED>:<json>'.
-- Kasıtlı sertleştirme: seans_tamamla ve bulk_ilac canlıda `SET search_path` taşımıyordu;
--   `SET search_path TO 'public', 'pg_temp'` eklendi (gövdeler zaten public. nitelikli).
-- Bağımlılık: 20260923000002 (_ovsync_pg_aktif, pg_application_event),
--             20260923000003 (_pg_kapi, _pg_olay_isle, _pg_sonrasi_tohumlama).
-- JS uyumu: tüm frontend çağrıları PostgREST isimli argümanla gelir (yeni parametreler
--   DEFAULT'lu); _asistan_step_calistir hizli_uygulama'yı 6 pozisyonel argümanla çağırır
--   → tek aday kaldığı için DEFAULT'larla çözülür (overload belirsizliği yok).
-- ACL: REVOKE ALL FROM PUBLIC, anon; GRANT EXECUTE TO authenticated (+ service_role: yeniden
--   yaratılan üç RPC'de canlı ACL paritesi). _pg_kapi_detay
--   authenticated'dan da REVOKE. anon'a GRANT yok.
-- ROLLBACK (elle, sahip kapısı): DROP FUNCTION yeni imzalar
--   hizli_uygulama(text,text,numeric,text,text,text,boolean,text),
--   seans_tamamla(uuid,boolean,text,boolean,text),
--   bulk_ilac(text[],text,numeric,text,text[],text), _pg_kapi_detay(jsonb,text,text);
--   ardından dört fonksiyonun canlı 2026-09-23 gövdeleri (pg_get_functiondef yedeği)
--   yeniden CREATE + GRANT EXECUTE TO authenticated. Bayrak 0 iken rollback gerekmez.
-- İç transaction deyimi YOK.
--
-- R3.1 (bağımsız inceleme sonrası, SPEC §"R3.1 — Bağımsız inceleme sonrası kararlar"):
--   MK7  hizli_uygulama 8'li imza da DROP edilir; 9'lu imza + p_occurred_at
--        timestamptz DEFAULT NULL (NULL→now(); >+5dk ya da <-7g → PG_ZAMAN_GECERSIZ).
--        seans_tamamla occurred_at = LEAST(now(), planned_date+planned_time İstanbul).
--        bulk_ilac değişmedi (now()).
--   MK9  Kilit sırası hayvan → seans/vaka → görev: seans_tamamla artık seansın
--        hayvanını (case_id→animal_id) kilitsiz çözüp FOR NO KEY UPDATE ile
--        kilitledikten SONRA mevcut tdu…FOR UPDATE'e geçer (p_uygulanmadi dalından
--        bağımsız, sıra sabit — deadlock önleme). bulk_ilac bayrak açıkken hayvan
--        id'lerini işlemeden önce sıralar (v_animal_ids_calisma).
--   MK10 PG geri alma trg_uygulama_log_pg_geri_al'a (uygulama_log AFTER DELETE,
--        bayraktan bağımsız — MK8) taşındı; hizli_uygulama_geri_al canlı gövdeye
--        geri döndü (kendi DELETE'i trigger'ı tetikler). Aynı trigger UI'nin
--        degisim_geri_al('satir') yolunu da kapsar (o da gerçek bir DELETE
--        FROM uygulama_log çalıştırır) — tek motor, çift iş yok.
--   ACL: yeni trigger fonksiyonu _trg_uygulama_log_pg_geri_al PUBLIC/anon/
--        authenticated'dan REVOKE (yalnız trigger olarak tetiklenir).

-- ─────────────────────────────────────────────────────────────────────────────
-- _pg_kapi_detay — PG_KAPI hata mesajı / toplu rapor satırı (iç, saf).
--   Anahtarlar her zaman vardır (değer yoksa null).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._pg_kapi_detay(p_kapi jsonb, p_hayvan_id text, p_kupe_no text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE SECURITY DEFINER
 SET search_path = public, pg_temp
AS $fn$
  SELECT jsonb_build_object(
    'hayvan_id',        COALESCE(p_kapi->'hayvan_id', to_jsonb(p_hayvan_id)),
    'kupe_no',          COALESCE(p_kapi->'kupe_no', to_jsonb(p_kupe_no)),
    'tohumlama_id',     p_kapi->'tohumlama_id',
    'tohumlama_tarihi', p_kapi->'tohumlama_tarihi',
    'tohumlama_sonuc',  p_kapi->'tohumlama_sonuc',
    'gun',              p_kapi->'gun',
    'sperma',           p_kapi->'sperma',
    'deneme_no',        p_kapi->'deneme_no',
    'urun_durumu',      p_kapi->'urun_durumu'
  );
$fn$;

REVOKE ALL ON FUNCTION public._pg_kapi_detay(jsonb, text, text) FROM PUBLIC, anon, authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- S-4 hizli_uygulama — kapı INSERT öncesi, event uygulama_log INSERT sonrası
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.hizli_uygulama(text, text, numeric, text, text, text);
-- R3.1 MK7: 000004'ün ilk (pre-review) uygulamasında yaratılan 8'li imza da düşürülür
-- (upgrade-in-place; bu DROP idempotent, hiç var olmadıysa no-op).
DROP FUNCTION IF EXISTS public.hizli_uygulama(text, text, numeric, text, text, text, boolean, text);

CREATE OR REPLACE FUNCTION public.hizli_uygulama(p_hayvan_id text, p_stok_id text, p_doz numeric, p_birim text, p_rota text, p_notlar text, p_pg_onay boolean DEFAULT false, p_pg_gerekce text DEFAULT NULL::text, p_occurred_at timestamptz DEFAULT NULL::timestamptz)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_hayvan hayvanlar%ROWTYPE;
  v_stok   record;
  v_etken  text;
  v_id     uuid;
  v_kalan  numeric;
  -- [OVSYNC-PG S-4] bayrak tek kez okunur (fonksiyon boyunca tutarlı karar)
  v_pg_aktif boolean := public._ovsync_pg_aktif();
  v_pg_kapi  jsonb;
  -- [OVSYNC-PG R3.1 MK7] PG anı; yalnız event'in occurred_at'ını etkiler
  v_occurred_at timestamptz;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = p_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok bulunamadı');
  END IF;

  v_etken := public._etken_kod_bul(p_stok_id, NULL);

  -- [OVSYNC-PG S-4] güvenlik kapısı (MK6: blok → RAISE PG_KAPI:<KOD>:<json>)
  -- [OVSYNC-PG R3.1 MK7] PG anı doğrulaması aynı kapıda: NULL → now(); gelecekte
  -- >5dk ya da geçmişte >7g → PG_ZAMAN_GECERSIZ. Bayrak kapalıyken kontrol edilmez
  -- (MK5: eski davranış, p_occurred_at yok sayılır).
  IF v_pg_aktif THEN
    IF p_occurred_at IS NULL THEN
      v_occurred_at := now();
    ELSIF p_occurred_at > now() + interval '5 minutes'
       OR p_occurred_at < now() - interval '7 days' THEN
      RAISE EXCEPTION 'PG_ZAMAN_GECERSIZ:%', jsonb_build_object(
        'p_occurred_at', p_occurred_at, 'simdi', now());
    ELSE
      v_occurred_at := p_occurred_at;
    END IF;

    v_pg_kapi := public._pg_kapi(p_hayvan_id, p_stok_id, NULL, COALESCE(p_pg_onay, false));
    IF v_pg_kapi->>'karar' IN ('BLOCK_PREGNANT', 'REQUIRE_ACK_PENDING', 'BLOCK_CATALOG_UNRESOLVED') THEN
      RAISE EXCEPTION 'PG_KAPI:%:%', v_pg_kapi->>'karar',
        public._pg_kapi_detay(v_pg_kapi, p_hayvan_id, v_hayvan.kupe_no);
    END IF;
  END IF;

  INSERT INTO public.uygulama_log (hayvan_id, stok_id, etken_kod, doz, birim, rota, notlar)
  VALUES (p_hayvan_id, p_stok_id, v_etken, p_doz, p_birim, p_rota, p_notlar)
  RETURNING id INTO v_id;

  -- [OVSYNC-PG S-4] PG gerçekleşme kaydı (+ACK, +S-5 görev); PG değilse no-op
  -- [OVSYNC-PG R3.1 MK7] now() yerine doğrulanmış v_occurred_at
  IF v_pg_aktif THEN
    PERFORM public._pg_olay_isle('HIZLI_UYGULAMA', v_id::text, p_hayvan_id, p_stok_id,
      v_stok.drug_product_id, v_occurred_at, v_pg_kapi, p_pg_gerekce);
  END IF;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES (
    'HIZLI_UYGULAMA',
    p_hayvan_id,
    v_id::text,
    'uygulama_log',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(jsonb_build_object('tablo','uygulama_log','id',v_id::text)),
      'guncellenen', '[]'::jsonb,
      'silinen', '[]'::jsonb
    ),
    format('Hızlı Uygulama — %s — %s %s %s', v_hayvan.kupe_no, v_stok.urun_adi, p_doz, p_birim)
  );

  INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
  VALUES (gen_random_uuid(), p_stok_id, 'Hızlı Uygulama', p_doz,
          'Hızlı Uygulama — ' || v_hayvan.kupe_no || ' — ' || v_stok.urun_adi, false);

  SELECT COALESCE(s.baslangic_miktar, 0) - COALESCE(SUM(CASE WHEN sh.iptal = false THEN sh.miktar ELSE 0 END), 0)
  INTO v_kalan
  FROM public.stok s
  LEFT JOIN public.stok_hareket sh ON sh.stok_id = s.id
  WHERE s.id = p_stok_id
  GROUP BY s.baslangic_miktar;

  RETURN jsonb_build_object(
    'ok', true,
    'id', v_id,
    'etken_kod', v_etken,
    'stok_kalan', COALESCE(v_kalan, 0)
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.hizli_uygulama(text, text, numeric, text, text, text, boolean, text, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hizli_uygulama(text, text, numeric, text, text, text, boolean, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.hizli_uygulama(text, text, numeric, text, text, text, boolean, text, timestamptz) TO service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- S-4 seans_tamamla — kapı + event yalnız p_uygulanmadi=false
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.seans_tamamla(uuid, boolean, text);

CREATE OR REPLACE FUNCTION public.seans_tamamla(p_seans_admin_id uuid, p_uygulanmadi boolean DEFAULT false, p_not text DEFAULT NULL::text, p_pg_onay boolean DEFAULT false, p_pg_gerekce text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_seans      public.treatment_day_uygulamalar%ROWTYPE;
  v_all_done   boolean;
  v_total      int;
  v_done       int;
  v_tip        text;
  -- [OVSYNC-PG S-4]
  v_pg_aktif   boolean := public._ovsync_pg_aktif();
  v_pg_kapi    jsonb;
  v_pg_hayvan  text;
  v_pg_kupe    text;
  -- [OVSYNC-PG R3.1 MK7]
  v_occurred_at timestamptz;
BEGIN
  -- [OVSYNC-PG R3.1 MK9] kilit sırası: hayvan → seans → görev. Bayrak açıkken
  -- seansın hayvanını kilitsiz çözüp hayvanlar satırını FOR NO KEY UPDATE ile
  -- kilitleriz; sonra (aşağıda) mevcut seans FOR UPDATE'e geçilir. p_uygulanmadi
  -- dalından bağımsız — sıra her zaman aynı olmalı (deadlock önleme).
  IF v_pg_aktif THEN
    SELECT c.animal_id INTO v_pg_hayvan
      FROM public.treatment_day_uygulamalar t
      JOIN public.cases c ON c.id = t.case_id
     WHERE t.id = p_seans_admin_id;
    IF v_pg_hayvan IS NOT NULL THEN
      PERFORM 1 FROM public.hayvanlar h WHERE h.id = v_pg_hayvan FOR NO KEY UPDATE;
    END IF;
  END IF;

  -- RACE CONDITION GUARD
  SELECT * INTO v_seans FROM public.treatment_day_uygulamalar
  WHERE id = p_seans_admin_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Seans bulunamadi');
  END IF;
  IF v_seans.uygulama_tamamlandi_at IS NOT NULL OR v_seans.uygulanmadi THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu seans zaten kapatilmis', 'race', true);
  END IF;

  IF p_uygulanmadi THEN
    -- Seans tablosunu isaretle
    UPDATE public.treatment_day_uygulamalar
    SET uygulanmadi = true, iptal_nedeni = p_not, updated_at = now()
    WHERE id = p_seans_admin_id
      AND uygulama_tamamlandi_at IS NULL
      AND uygulanmadi = false;

    -- drug_admins senkron
    UPDATE public.drug_administrations
    SET uygulanmadi = true
    WHERE seans_admin_id = p_seans_admin_id
      AND uygulanmadi IS DISTINCT FROM true;

    -- Stok iade: stok_hareket_ref kolonu Faz 1'de yok.
    -- Bunun yerine drug_admins.notlar pattern'i ile bul:
    UPDATE public.stok_hareket sh
    SET iptal = true
    FROM public.drug_administrations da
    WHERE da.seans_admin_id = p_seans_admin_id
      AND sh.notlar = 'drug_admin:' || da.id::text
      AND sh.iptal = false;
    v_tip := 'TEDAVI_SEANS_IPTAL';
  ELSE
    -- [OVSYNC-PG S-4] kapı yalnız uygulandı yolunda (p_uygulanmadi=false).
    -- Blok → RAISE; seans açık kalır, kullanıcı 'uygulanmadı' işaretleyebilir.
    -- [OVSYNC-PG R3.1 MK9] v_pg_hayvan yukarıda (kilit sırası bloğunda) zaten
    -- çözüldü; burada yalnız NULL koruması tekrarlanır (case_id yok/silinmiş).
    IF v_pg_aktif THEN
      IF v_pg_hayvan IS NULL THEN
        RAISE EXCEPTION 'PG_KAPI_IC_HATA:%', jsonb_build_object('sebep', 'SEANS_HAYVAN_YOK',
          'seans_admin_id', p_seans_admin_id, 'case_id', v_seans.case_id);
      END IF;
      v_pg_kapi := public._pg_kapi(v_pg_hayvan, v_seans.stok_id, v_seans.drug_product_id, COALESCE(p_pg_onay, false));
      IF v_pg_kapi->>'karar' IN ('BLOCK_PREGNANT', 'REQUIRE_ACK_PENDING', 'BLOCK_CATALOG_UNRESOLVED') THEN
        SELECT h.kupe_no INTO v_pg_kupe FROM public.hayvanlar h WHERE h.id = v_pg_hayvan;
        RAISE EXCEPTION 'PG_KAPI:%:%', v_pg_kapi->>'karar',
          public._pg_kapi_detay(v_pg_kapi, v_pg_hayvan, v_pg_kupe)
            || jsonb_build_object('seans_admin_id', p_seans_admin_id, 'case_id', v_seans.case_id);
      END IF;
    END IF;
    -- Seans tamamlandi
    UPDATE public.treatment_day_uygulamalar
    SET uygulama_tamamlandi_at = now(),
        uygulama_notu = p_not,
        gerceklesme_saati = NOW()::time,
        updated_at = now()
    WHERE id = p_seans_admin_id
      AND uygulama_tamamlandi_at IS NULL
      AND uygulanmadi = false;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu seans baska biri tarafindan kapatilmis', 'race', true);
    END IF;
    -- [OVSYNC-PG S-4] PG gerçekleşme kaydı; source_id = seans id
    -- [OVSYNC-PG R3.1 MK7] occurred_at = LEAST(now(), planlanan an) — kaydın geç
    -- girilmesi TAI'yi ileri kaydırmasın.
    IF v_pg_aktif THEN
      v_occurred_at := LEAST(now(), (v_seans.planned_date + v_seans.planned_time) AT TIME ZONE 'Europe/Istanbul');
      PERFORM public._pg_olay_isle('TEDAVI_SEANS', p_seans_admin_id::text, v_pg_hayvan,
        v_seans.stok_id, v_seans.drug_product_id, v_occurred_at, v_pg_kapi, p_pg_gerekce);
    END IF;
    v_tip := 'TEDAVI_SEANS_TAMAM';
  END IF;

  -- Gorev log kapat
  UPDATE public.gorev_log
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE seans_admin_id = p_seans_admin_id AND tamamlandi = false;

  -- Tum seanslar done mi?
  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE uygulama_tamamlandi_at IS NOT NULL OR uygulanmadi = true)
  INTO v_total, v_done
  FROM public.treatment_day_uygulamalar
  WHERE treatment_day_id = v_seans.treatment_day_id;

  v_all_done := (v_total = v_done);

  IF v_all_done THEN
    -- Gun seviyesi tamamlandi
    UPDATE public.treatment_days
    SET tamamlandi = true,
        tamamlanma_tarihi = now()
    WHERE id = v_seans.treatment_day_id AND tamamlandi = false;

    UPDATE public.gorev_log
    SET tamamlandi = true, tamamlanma_tarihi = now()
    WHERE gorev_tipi = 'TEDAVI_GUN'
      AND tamamlandi = false
      AND (aciklama::jsonb->>'day_id')::uuid = v_seans.treatment_day_id;
  END IF;

  -- Audit
  INSERT INTO public.islem_log(id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text, v_tip,
    (SELECT animal_id FROM public.cases WHERE id = v_seans.case_id),
    p_seans_admin_id::text, 'treatment_day_uygulamalar',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object('tablo', 'treatment_day_uygulamalar', 'id', p_seans_admin_id::text)
      ),
      'gun_tamam', v_all_done
    )
  );

  RETURN jsonb_build_object('ok', true, 'seans_done', true, 'gun_tamam', v_all_done);
END;
$function$;

REVOKE ALL ON FUNCTION public.seans_tamamla(uuid, boolean, text, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.seans_tamamla(uuid, boolean, text, boolean, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.seans_tamamla(uuid, boolean, text, boolean, text) TO service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- S-4 bulk_ilac — satır bazında kapı; stok = uygulanan hayvan sayısı
-- ─────────────────────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.bulk_ilac(text[], text, numeric, text);

CREATE OR REPLACE FUNCTION public.bulk_ilac(p_animal_ids text[], p_ilac_stok_id text, p_miktar numeric, p_notlar text DEFAULT NULL::text, p_pg_onaylar text[] DEFAULT '{}'::text[], p_pg_gerekce text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_animal_id       text;
  v_stok            record;
  v_success         int := 0;
  v_errors          jsonb := '[]'::jsonb;
  v_total_miktar    numeric;
  v_stok_urun_adi   text;
  v_log_id          text;
  v_stok_hareket_id uuid;
  -- [OVSYNC-PG S-4]
  v_pg_aktif        boolean := public._ovsync_pg_aktif();
  v_pg_kapi         jsonb;
  v_pg_kapilar      jsonb := '{}'::jsonb;   -- hayvan_id → kapı (yalnız uygulanacaklar)
  v_pg_uygula_adet  int := 0;
  v_pg_urun         uuid;
  v_pg_kupe         text;
  v_pg_event        uuid;
  v_pg_applied      jsonb := '[]'::jsonb;
  v_pg_blocked      jsonb := '[]'::jsonb;
  v_pg_requires_ack jsonb := '[]'::jsonb;
  -- [OVSYNC-PG R3.1 MK9] deterministik kilit sırası için sıralanmış çalışma
  -- kopyası; bayrak kapalıyken p_animal_ids ile bit-bit aynı (MK5).
  v_animal_ids_calisma text[] := p_animal_ids;
BEGIN
  -- Verify stok exists
  SELECT id, urun_adi, baslangic_miktar INTO v_stok
  FROM public.stok
  WHERE id = p_ilac_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok kalemi bulunamadı');
  END IF;

  v_stok_urun_adi := v_stok.urun_adi;
  v_total_miktar := p_miktar * array_length(p_animal_ids, 1);

  -- [OVSYNC-PG S-4] ön geçiş: hayvan başına kapı. Blok/onaysız hayvan atlanır
  -- (yazma yok); stok gereksinimi yalnız uygulanacak hayvan sayısıyla hesaplanır.
  IF v_pg_aktif THEN
    SELECT s.drug_product_id INTO v_pg_urun FROM public.stok s WHERE s.id = p_ilac_stok_id;
    -- [OVSYNC-PG R3.1 MK9] hayvan id'lerini işlemeden önce sırala (deterministik
    -- kilit sırası; _pg_kapi her hayvan için hayvanlar satırını kilitler).
    SELECT COALESCE(array_agg(x ORDER BY x NULLS LAST), '{}'::text[])
      INTO v_animal_ids_calisma
      FROM unnest(p_animal_ids) AS x;
    FOREACH v_animal_id IN ARRAY v_animal_ids_calisma LOOP
      IF v_animal_id IS NULL THEN
        v_pg_kapi := jsonb_build_object('karar', 'PG_KAPI_IC_HATA', 'hata', 'HAYVAN_ID_BOS');
      ELSE
        BEGIN
          v_pg_kapi := public._pg_kapi(v_animal_id, p_ilac_stok_id, NULL,
                         v_animal_id = ANY(COALESCE(p_pg_onaylar, '{}'::text[])));
        EXCEPTION WHEN OTHERS THEN
          v_pg_kapi := jsonb_build_object('karar', 'PG_KAPI_IC_HATA', 'hata', SQLERRM);
        END;
      END IF;
      IF v_pg_kapi->>'karar' IN ('ALLOW', 'ACK_PENDING') THEN
        v_pg_kapilar := v_pg_kapilar || jsonb_build_object(v_animal_id, v_pg_kapi);
        v_pg_uygula_adet := v_pg_uygula_adet + 1;
      ELSE
        v_pg_kupe := NULL;
        SELECT h.kupe_no INTO v_pg_kupe FROM public.hayvanlar h WHERE h.id = v_animal_id;
        IF v_pg_kapi->>'karar' = 'REQUIRE_ACK_PENDING' THEN
          v_pg_requires_ack := v_pg_requires_ack || jsonb_build_array(
            public._pg_kapi_detay(v_pg_kapi, v_animal_id, v_pg_kupe)
              || jsonb_build_object('kod', v_pg_kapi->>'karar'));
        ELSE
          v_pg_blocked := v_pg_blocked || jsonb_build_array(
            public._pg_kapi_detay(v_pg_kapi, v_animal_id, v_pg_kupe)
              || jsonb_build_object('kod', COALESCE(v_pg_kapi->>'karar', 'PG_KAPI_IC_HATA'),
                                    'hata', v_pg_kapi->>'hata'));
        END IF;
      END IF;
    END LOOP;
    v_total_miktar := p_miktar * v_pg_uygula_adet;
  END IF;

  -- Check stock availability (baslangic_miktar - consumed via stok_hareket)
  IF (
    COALESCE(v_stok.baslangic_miktar, 0)
    < v_total_miktar
  ) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'mesaj', 'Yetersiz stok: ' || COALESCE(v_stok.baslangic_miktar, 0) || ' mevcut, ' || v_total_miktar || ' gerekli'
    );
  END IF;

  -- Apply to each animal
  -- [OVSYNC-PG R3.1 MK9] bayrak kapalıyken v_animal_ids_calisma = p_animal_ids
  -- (aynı sıra, MK5); bayrak açıkken sıralanmış kopya (yukarıda).
  FOREACH v_animal_id IN ARRAY v_animal_ids_calisma LOOP
    -- [OVSYNC-PG S-4] kapıdan geçmeyen hayvan atlanır (satır bazında rapor)
    IF v_pg_aktif AND (v_pg_kapilar ? v_animal_id) IS NOT TRUE THEN
      CONTINUE;
    END IF;
    BEGIN
      -- Log to islem_log with TOPLU_ILAC tip
      v_log_id := gen_random_uuid()::text;
      INSERT INTO public.islem_log (id, tip, ana_hayvan_id, tarih, kullanici_notu, snapshot, ref_id, ref_tablo)
      VALUES (
        v_log_id,
        'TOPLU_ILAC',
        v_animal_id,
        now(),
        p_notlar,
        jsonb_build_object(
          'ilac_stok_id', p_ilac_stok_id,
          'ilac_adi', v_stok_urun_adi,
          'miktar', p_miktar
        ),
        v_log_id,
        'islem_log'
      );
      -- [OVSYNC-PG S-4] event source_id = bu hayvan için yazılan islem_log id'si.
      -- Hata → alt-transaction geri alınır (islem_log dahil), errors[]'a düşer.
      IF v_pg_aktif THEN
        v_pg_event := public._pg_olay_isle('TOPLU_ILAC', v_log_id, v_animal_id, p_ilac_stok_id,
          v_pg_urun, now(), v_pg_kapilar -> v_animal_id, p_pg_gerekce);
        v_pg_applied := v_pg_applied || jsonb_build_array(jsonb_build_object(
          'hayvan_id', v_animal_id, 'islem_log_id', v_log_id,
          'karar', v_pg_kapilar -> v_animal_id ->> 'karar', 'pg_event_id', v_pg_event));
      END IF;
      v_success := v_success + 1;
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors || jsonb_build_array(
        jsonb_build_object('animal_id', v_animal_id, 'error', SQLERRM)
      );
    END;
  END LOOP;

  -- Deduct total from stok (single operation for efficiency)
  IF v_success > 0 THEN
    UPDATE public.stok
    SET baslangic_miktar = baslangic_miktar - (p_miktar * v_success)
    WHERE id = p_ilac_stok_id;

    -- Log stok hareket
    v_stok_hareket_id := gen_random_uuid();
    INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
    VALUES (
      v_stok_hareket_id,
      p_ilac_stok_id,
      'TOPLU_ILAC',
      p_miktar * v_success,
      v_success || ' hayvana toplu ilaç uygulaması (' || COALESCE(v_stok_urun_adi, p_ilac_stok_id) || ')',
      false
    );
  END IF;

  -- [OVSYNC-PG S-4] mevcut anahtarlar korunur; ek applied[]/blocked[]/requires_ack[]
  IF v_pg_aktif THEN
    RETURN jsonb_build_object(
      'ok', true,
      'total', array_length(p_animal_ids, 1),
      'success', v_success,
      'errors', v_errors,
      'applied', v_pg_applied,
      'blocked', v_pg_blocked,
      'requires_ack', v_pg_requires_ack
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'total', array_length(p_animal_ids, 1),
    'success', v_success,
    'errors', v_errors
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.bulk_ilac(text[], text, numeric, text, text[], text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.bulk_ilac(text[], text, numeric, text, text[], text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.bulk_ilac(text[], text, numeric, text, text[], text) TO service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- S-4 hizli_uygulama_geri_al — event geri alma (imza aynı)
-- [OVSYNC-PG R3.1 MK10] Gövde canlı 2026-09-23 tanımına GERİ DÖNDÜ (PG bloğu
-- kaldırıldı): PG geri alma artık trg_uygulama_log_pg_geri_al (aşağıda) ile
-- tekilleştirildi — bu fonksiyonun kendi DELETE FROM uygulama_log satırı o
-- trigger'ı tetikler, çift iş yapılmaz. Bayraktan bağımsız (MK8): trigger
-- yalnız eşleşen açık pg_application_event varsa iş yapar.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hizli_uygulama_geri_al(p_uygulama_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uyg    record;
  v_hayvan record;
BEGIN
  SELECT * INTO v_uyg FROM public.uygulama_log WHERE id = p_uygulama_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Uygulama kaydı bulunamadı');
  END IF;

  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = v_uyg.hayvan_id;

  -- Stok iade (ters hareket) — mevcut blok, KORUNDU
  IF v_uyg.stok_id IS NOT NULL THEN
    INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
    VALUES (gen_random_uuid(), v_uyg.stok_id, 'İade (Hızlı Uyg.)', -v_uyg.doz,
            'Geri Al — ' || COALESCE(v_hayvan.kupe_no, v_uyg.hayvan_id), false);
  END IF;

  -- YENİ: islem_log audit (Bonus simetri) — mevcut yapı AYNEN korundu
  INSERT INTO public.islem_log (
    tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu, durum, geri_alma_tarihi
  )
  VALUES (
    'HIZLI_UYGULAMA_GERI_AL',
    v_uyg.hayvan_id,
    p_uygulama_id::text,
    'uygulama_log',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'tablo','gorev_log','id',g.id::text,'alan','tamamlandi','eski',true,'yeni',false
        ))
        FROM public.gorev_log g
        WHERE g.kapatan_ref = 'uygulama_log:' || p_uygulama_id::text
      ), '[]'::jsonb),
      'silinen', jsonb_build_array(jsonb_build_object(
        'tablo','uygulama_log','id',p_uygulama_id::text
      ))
    ),
    format('Hızlı Uygulama Geri Al — %s — uygulama_id=%s', v_hayvan.kupe_no, p_uygulama_id),
    'geri_alindi',
    now()
  );

  -- Bu uygulama ile kapanan görevi tekrar aç — mevcut blok, KORUNDU
  UPDATE public.gorev_log
  SET tamamlandi = false,
      tamamlanma_tarihi = NULL,
      kapatan_ref = NULL
  WHERE kapatan_ref = 'uygulama_log:' || p_uygulama_id::text;

  -- uygulama_log DELETE — mevcut blok, KORUNDU. [OVSYNC-PG R3.1 MK10] bu DELETE
  -- trg_uygulama_log_pg_geri_al'ı (AFTER DELETE, aşağıda) tetikler; PG event
  -- işaretleme + görev iptal/geri açma + PG_CYCLE_REVIEW_REQUIRED oradan yazılır.
  DELETE FROM public.uygulama_log WHERE id = p_uygulama_id;

  RETURN jsonb_build_object('ok', true);
END;
$function$;

REVOKE ALL ON FUNCTION public.hizli_uygulama_geri_al(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hizli_uygulama_geri_al(uuid) TO authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- R3.1 MK10  trg_uygulama_log_pg_geri_al — uygulama_log üzerinde AFTER DELETE.
--   Her iki geri alma yolunu da kapsar: degisim_geri_al (UI, js/ui.js
--   _protokolGeriAl → dgGeriAlAkisi → degisim_geri_al(..,'satir',..) →
--   surum_gizli._degisim_uygula gerçek bir DELETE FROM public.uygulama_log
--   çalıştırır) ve hizli_uygulama_geri_al (yukarıda, aynı DELETE satırı).
--   MK8: bayraktan BAĞIMSIZ çalışır — yalnız eşleşen açık pg_application_event
--   varsa iş yapar; bayrak hiç açılmadıysa hiç event yoktur → 0 satır (MK5).
--   a) event.geri_alindi_at = now()
--   b) event'in açık PG_TOHUMLAMA görevi iptal (kapatan_ref='PG_GERI_AL:<event>')
--   c) PG_ONAY:<event> ile kapatılmış GEBELIK_KONTROL görevleri — ilgili
--      tohumlama (event.ack_tohumlama_id) hâlâ 'Bekliyor' ise geri açılır;
--      değilse açılamayan listesine düşer.
--   d) PG_YERINE:<event> görevi var ya da (c) açılamadıysa → islem_log
--      PG_CYCLE_REVIEW_REQUIRED (yerine geçilen görev CANLANMAZ, yalnız raporlanır).
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public._trg_uygulama_log_pg_geri_al()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public, pg_temp
AS $trg$
DECLARE
  v_event          public.pg_application_event%ROWTYPE;
  v_pg_iptal       uuid[];
  v_pg_yerine      uuid[];
  v_pg_onay_ids    uuid[];
  v_pg_acilan      uuid[];
  v_pg_acilamayan  uuid[];
  v_toh_sonuc      text;
  v_reopen         boolean := false;
BEGIN
  SELECT * INTO v_event
    FROM public.pg_application_event
   WHERE source_type = 'HIZLI_UYGULAMA' AND source_id = OLD.id::text
     AND geri_alindi_at IS NULL
   FOR UPDATE;
  IF NOT FOUND THEN
    RETURN NULL;  -- eşleşen açık PG event yok (bayrak hiç açılmadıysa hep buraya düşer)
  END IF;

  UPDATE public.pg_application_event SET geri_alindi_at = now() WHERE id = v_event.id;

  -- b) event'in açık PG_TOHUMLAMA (S-5) görevi iptal
  WITH u AS (
    UPDATE public.gorev_log
       SET iptal = true, tamamlandi = true, kapatan_ref = 'PG_GERI_AL:' || v_event.id::text
     WHERE kaynak = 'PG_TOHUMLAMA:' || v_event.id::text
       AND gorev_tipi = 'TOHUMLAMA_PLANLI'
       AND COALESCE(tamamlandi, false) = false
       AND COALESCE(iptal, false) = false
    RETURNING id
  )
  SELECT COALESCE(array_agg(id), '{}'::uuid[]) INTO v_pg_iptal FROM u;

  -- c) PG_ONAY:<event> ile kapatılmış GEBELIK_KONTROL görevleri — koşullu geri açma
  SELECT COALESCE(array_agg(id), '{}'::uuid[]) INTO v_pg_onay_ids
    FROM public.gorev_log
   WHERE kapatan_ref = 'PG_ONAY:' || v_event.id::text
     AND gorev_tipi = 'GEBELIK_KONTROL'
     AND COALESCE(iptal, false) = true
     AND COALESCE(tamamlandi, false) = true;

  IF cardinality(v_pg_onay_ids) > 0 AND v_event.ack_tohumlama_id IS NOT NULL THEN
    SELECT t.sonuc INTO v_toh_sonuc FROM public.tohumlama t WHERE t.id::text = v_event.ack_tohumlama_id;
    v_reopen := (v_toh_sonuc = 'Bekliyor');
  END IF;

  IF cardinality(v_pg_onay_ids) > 0 AND v_reopen THEN
    UPDATE public.gorev_log
       SET iptal = false, tamamlandi = false, kapatan_ref = NULL, tamamlanma_tarihi = NULL
     WHERE id = ANY(v_pg_onay_ids);
    v_pg_acilan := v_pg_onay_ids;
    v_pg_acilamayan := '{}'::uuid[];
  ELSE
    v_pg_acilan := '{}'::uuid[];
    v_pg_acilamayan := v_pg_onay_ids;
  END IF;

  -- d) yerine geçilen (PG_YERINE:<event>) görevler CANLANMAZ, yalnız raporlanır
  SELECT COALESCE(array_agg(id), '{}'::uuid[]) INTO v_pg_yerine
    FROM public.gorev_log
   WHERE kapatan_ref = 'PG_YERINE:' || v_event.id::text;

  IF cardinality(v_pg_yerine) > 0 OR cardinality(v_pg_acilamayan) > 0 THEN
    INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot, kullanici_notu)
    VALUES ('PG_CYCLE_REVIEW_REQUIRED', v_event.hayvan_id, v_event.id::text, 'pg_application_event',
            jsonb_build_object(
              'event_id', v_event.id,
              'uygulama_log_id', OLD.id,
              'occurred_at', v_event.occurred_at,
              'iptal_edilen_pg_gorev_ids', to_jsonb(v_pg_iptal),
              'yerine_gecilen_gorev_ids', to_jsonb(v_pg_yerine),
              'gebelik_kontrol_acilan_ids', to_jsonb(v_pg_acilan),
              'gebelik_kontrol_acilamayan_ids', to_jsonb(v_pg_acilamayan)),
            '{}'::jsonb,
            format('PG uygulaması geri alındı (uygulama_log=%s); yerine geçilen %s planlı tohumlama, açılamayan gebelik kontrolü %s — döngüyü gözden geçirin',
                   OLD.id, cardinality(v_pg_yerine), cardinality(v_pg_acilamayan)));
  END IF;

  RETURN NULL;
END;
$trg$;

REVOKE ALL ON FUNCTION public._trg_uygulama_log_pg_geri_al() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_uygulama_log_pg_geri_al ON public.uygulama_log;
CREATE TRIGGER trg_uygulama_log_pg_geri_al
  AFTER DELETE ON public.uygulama_log
  FOR EACH ROW EXECUTE FUNCTION public._trg_uygulama_log_pg_geri_al();

NOTIFY pgrst, 'reload schema';

-- EOF 20260923000004
