-- 2026-06-11: BUG-059 — Saat bazli seans RPC'leri
-- Faz 2: 5 RPC (4 yeni + 1 guncelleme)
-- Bagimlilik: 20260611000001_bug059_treatment_sessions.sql (Faz 1) ONCE deploy edilmis olmali
--
-- Spec: docs/superpowers/specs/2026-06-10-tedavi-saat-bazli-seans.md
-- RPC 1 (sira_no + stok_hareket_ref referanslari): Faz 1 ile uyumlu hale getirildi
--   - sira_no INSERT kaldirildi (kolon yok, ORDER BY planned_time)
--   - stok_hareket_ref UPDATE kaldirildi (kolon yok, drug_admins notlar pattern'i)
--   - stok_hareket_ref SELECT/FROM kontrol kaldirildi (RPC 2 + RPC 5)

BEGIN;

-- RPC 1: add_treatment_day_with_sessions
-- Spec: L325-590
-- Geriye uyumlu: p_sessions NULL ise eski tek-seans davranis (seans_sayisi=NULL/NULL seans)
DROP FUNCTION IF EXISTS public.add_treatment_day_with_sessions(uuid, date, jsonb, uuid);
CREATE OR REPLACE FUNCTION public.add_treatment_day_with_sessions(
  p_case_id            uuid,
  p_date               date,
  p_sessions           jsonb DEFAULT NULL,
  p_existing_day_id    uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_day_id         uuid;
  v_gorev_id       uuid;
  v_prev_gorev_id  uuid := NULL;
  v_day_no         int;
  v_case           record;
  v_gecmis         boolean;
  v_session        jsonb;
  v_seans_sayisi   smallint;
  v_admin_ids      uuid[] := '{}';
  v_admin_id       uuid;
  v_first_time     time;
  v_is_update      boolean := false;
  v_drug_admin_id  uuid;
  v_stok_id        text;
  v_stok_hareket_id text;
BEGIN
  v_is_update := p_existing_day_id IS NOT NULL;

  -- Day no: yeni gun ise MAX+1, mevcut gun ise mevcut day_no
  IF v_is_update THEN
    SELECT day_no INTO v_day_no
    FROM public.treatment_days
    WHERE id = p_existing_day_id AND case_id = p_case_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Mevcut gun bulunamadi');
    END IF;
  ELSE
    SELECT COALESCE(MAX(day_no), 0) + 1 INTO v_day_no
    FROM public.treatment_days WHERE case_id = p_case_id;
  END IF;

  -- Case
  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadi');
  END IF;
  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapali vakaya gun eklenemez');
  END IF;

  v_gecmis := p_date < CURRENT_DATE;

  -- Onceki gun varsa parent_id
  IF v_day_no > 1 THEN
    SELECT g.id INTO v_prev_gorev_id
    FROM public.gorev_log g
    JOIN public.treatment_days td ON (g.aciklama::jsonb->>'day_id')::uuid = td.id
    WHERE td.case_id = p_case_id AND td.day_no = v_day_no - 1 AND g.gorev_tipi = 'TEDAVI_GUN'
    LIMIT 1;
  END IF;

  -- YENI: seans sayisi
  v_seans_sayisi := CASE WHEN p_sessions IS NULL THEN NULL ELSE jsonb_array_length(p_sessions)::smallint END;
  v_first_time   := CASE 
    WHEN p_sessions IS NULL THEN NULL
    ELSE (p_sessions->0->>'planned_time')::time
  END;

  -- Day INSERT veya UPDATE
  IF v_is_update THEN
    -- ONCE eski alt verileri temizle (drug_admins, seanslar, gorevler, stok iade)
    UPDATE public.stok_hareket sh
    SET iptal = true
    FROM public.drug_administrations da
    WHERE da.treatment_day_id = p_existing_day_id
      AND sh.notlar = 'drug_admin:' || da.id::text
      AND sh.iptal = false;

    DELETE FROM public.drug_administrations WHERE treatment_day_id = p_existing_day_id;
    DELETE FROM public.treatment_day_uygulamalar WHERE treatment_day_id = p_existing_day_id;
    DELETE FROM public.gorev_log
    WHERE gorev_tipi = 'TEDAVI_SEANS'
      AND (aciklama::jsonb->>'day_id')::uuid = p_existing_day_id;

    -- Mevcut gunu guncelle
    UPDATE public.treatment_days
    SET planned_time = v_first_time,
        seans_sayisi = v_seans_sayisi,
        treatment_date = p_date
    WHERE id = p_existing_day_id
    RETURNING id INTO v_day_id;

    -- Mevcut TEDAVI_GUN gorevini yeniden ac
    UPDATE public.gorev_log
    SET tamamlandi = false,
        tamamlanma_tarihi = NULL,
        aciklama = jsonb_build_object(
          'day_id', v_day_id, 'gun_no', v_day_no,
          'label', 'Gun ' || v_day_no || ' tedavisi - ' || to_char(p_date, 'DD.MM.YYYY'),
          'planned_time', COALESCE(v_first_time::text, ''),
          'seans_sayisi', v_seans_sayisi,
          'recete_guncellendi', true
        )::text
    WHERE gorev_tipi = 'TEDAVI_GUN'
      AND (aciklama::jsonb->>'day_id')::uuid = v_day_id
    RETURNING id INTO v_gorev_id;
  ELSE
    INSERT INTO public.treatment_days(
      id, case_id, day_no, treatment_date, tamamlandi,
      tamamlanma_tarihi, planned_time, seans_sayisi
    )
    VALUES (
      gen_random_uuid(), p_case_id, v_day_no, p_date,
      v_gecmis, CASE WHEN v_gecmis THEN p_date::timestamptz ELSE NULL END,
      v_first_time, v_seans_sayisi
    )
    RETURNING id INTO v_day_id;
  END IF;

  -- Ana TEDAVI_GUN gorev
  IF NOT v_is_update THEN
    INSERT INTO public.gorev_log(
      id, gorev_tipi, hayvan_id, hedef_tarih, aciklama,
      tamamlandi, tamamlanma_tarihi, parent_id
    )
    VALUES (
      gen_random_uuid(), 'TEDAVI_GUN', v_case.animal_id, p_date,
      jsonb_build_object(
        'day_id', v_day_id, 'gun_no', v_day_no,
        'label', 'Gun ' || v_day_no || ' tedavisi - ' || to_char(p_date, 'DD.MM.YYYY'),
        'planned_time', COALESCE(v_first_time::text, ''),
        'seans_sayisi', v_seans_sayisi
      )::text,
      v_gecmis, CASE WHEN v_gecmis THEN p_date::timestamptz ELSE NULL END,
      v_prev_gorev_id
    )
    RETURNING id INTO v_gorev_id;
  END IF;

  -- YENI: N seans dongusu
  IF p_sessions IS NOT NULL THEN
    FOR v_session IN SELECT * FROM jsonb_array_elements(p_sessions)
    LOOP
      -- treatment_day_uygulamalar INSERT (sira_no YOK, planned_time ile siralama)
      INSERT INTO public.treatment_day_uygulamalar(
        treatment_day_id, case_id, planned_time, planned_date,
        stok_id, drug_product_id, dose, unit, route
      )
      VALUES (
        v_day_id, p_case_id,
        (v_session->>'planned_time')::time, p_date,
        v_session->>'stok_id',
        (v_session->>'drug_product_id')::uuid,
        (v_session->>'dose')::numeric,
        v_session->>'unit',
        v_session->>'route'
      )
      RETURNING id INTO v_admin_id;

      v_admin_ids := array_append(v_admin_ids, v_admin_id);

      -- drug_administrations INSERT
      INSERT INTO public.drug_administrations(
        treatment_day_id, stok_id, drug_product_id, dose, unit, route,
        seans_admin_id
      )
      VALUES (
        v_day_id,
        v_session->>'stok_id',
        (v_session->>'drug_product_id')::uuid,
        (v_session->>'dose')::numeric,
        v_session->>'unit',
        v_session->>'route',
        v_admin_id
      )
      RETURNING id INTO v_drug_admin_id;

      -- Stok INSERT (drug_admin_id ile birebir izlenebilir)
      v_stok_id := v_session->>'stok_id';
      IF v_stok_id IS NOT NULL AND (v_session->>'dose')::numeric > 0 THEN
        INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar)
        VALUES (v_stok_id, 'Tedavi', (v_session->>'dose')::numeric,
                'drug_admin:' || v_drug_admin_id::text)
        RETURNING id INTO v_stok_hareket_id;
        -- Not: stok_hareket_ref kolonu Faz 1'de yok, stok iade drug_admins.notlar pattern'i ile yapilir
      END IF;

      -- Her seans icin ayri TEDAVI_SEANS gorev
      INSERT INTO public.gorev_log(
        id, gorev_tipi, hayvan_id, hedef_tarih, hedef_saat,
        aciklama, tamamlandi, parent_id, seans_admin_id
      )
      VALUES (
        gen_random_uuid(), 'TEDAVI_SEANS', v_case.animal_id, p_date,
        (v_session->>'planned_time')::time,
        jsonb_build_object(
          'day_id', v_day_id,
          'planned_time', v_session->>'planned_time',
          'label', 'Gun ' || v_day_no || ' - Seans (' || (v_session->>'planned_time') || ')',
          'admin_id', v_admin_id
        )::text,
        false, v_gorev_id, v_admin_id
      );
    END LOOP;
  END IF;

  -- Audit
  INSERT INTO public.islem_log(id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    CASE WHEN v_is_update THEN 'RECETE_GUNCELLENDI' ELSE 'TEDAVI_GUN_EKLENDI' END,
    v_case.animal_id,
    v_day_id::text, 'treatment_days',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'treatment_days', 'id', v_day_id::text),
        jsonb_build_object('tablo', 'gorev_log', 'id', v_gorev_id::text)
      ) || COALESCE((
        SELECT jsonb_agg(jsonb_build_object('tablo', 'treatment_day_uygulamalar', 'id', id::text))
        FROM unnest(v_admin_ids) AS id
      ), '[]'::jsonb),
      'seans_sayisi', v_seans_sayisi,
      'guncellenen', '[]'::jsonb
    )
  );

  RETURN jsonb_build_object(
    'ok', true, 'day_id', v_day_id, 'day_no', v_day_no,
    'seans_sayisi', v_seans_sayisi, 'admin_ids', v_admin_ids,
    'gorev_id', v_gorev_id, 'gecmis', v_gecmis
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_treatment_day_with_sessions TO anon, authenticated;

-- RPC 2: seans_tamamla
-- Spec: L596-714
-- Yapilan seansi kapat. Race condition guard (SELECT FOR UPDATE).
-- p_uygulanmadi=true ise stok iade de yapar (drug_admins.notlar pattern, stok_hareket_ref YOK)
DROP FUNCTION IF EXISTS public.seans_tamamla(uuid, boolean, text);
CREATE OR REPLACE FUNCTION public.seans_tamamla(
  p_seans_admin_id  uuid,
  p_uygulanmadi     boolean DEFAULT false,
  p_not             text    DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_seans      public.treatment_day_uygulamalar%ROWTYPE;
  v_all_done   boolean;
  v_total      int;
  v_done       int;
  v_tip        text;
BEGIN
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
$$;

GRANT EXECUTE ON FUNCTION public.seans_tamamla TO anon, authenticated;

-- RPC 3: recete_guncelle
-- Spec: L718-800
-- Reçete değişikliği. Yapılmamış günlere yeni reçete, kısmen yapılmış günlere DOKUNMAZ
DROP FUNCTION IF EXISTS public.recete_guncelle(uuid, jsonb);
CREATE OR REPLACE FUNCTION public.recete_guncelle(
  p_case_id     uuid,
  p_yeni_plan   jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_day_plan      jsonb;
  v_day_no        int;
  v_day_id        uuid;
  v_total_seans   int := 0;
  v_tamam         boolean;
  v_kismen_acik   boolean;
BEGIN
  -- Case kontrol
  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = p_case_id AND status = 'active') THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Aktif vaka bulunamadi');
  END IF;

  FOR v_day_plan IN SELECT * FROM jsonb_array_elements(p_yeni_plan)
  LOOP
    v_day_no := (v_day_plan->>'day_no')::int;

    -- Bu gun var mi?
    SELECT id, tamamlandi INTO v_day_id, v_tamam
    FROM public.treatment_days
    WHERE case_id = p_case_id AND day_no = v_day_no;

    -- KISMEN ACILMIS GUN DOKUNULMAZ
    IF v_day_id IS NOT NULL AND v_tamam = false THEN
      SELECT EXISTS(
        SELECT 1 FROM public.treatment_day_uygulamalar
        WHERE treatment_day_id = v_day_id
          AND (uygulama_tamamlandi_at IS NOT NULL OR uygulanmadi = true)
      ) INTO v_kismen_acik;

      IF v_kismen_acik THEN
        CONTINUE; -- atla, bu gun kilitli
      END IF;
    END IF;

    IF v_day_id IS NULL THEN
      -- YENI GUN EKLE
      PERFORM public.add_treatment_day_with_sessions(
        p_case_id,
        CURRENT_DATE + (v_day_no - 1),
        v_day_plan->'sessions'
      );
      v_total_seans := v_total_seans + jsonb_array_length(v_day_plan->'sessions');
    ELSIF v_tamam = false THEN
      -- TAMAMLANMAMIS + HICBIR SEANS YAPILMAMIS - RECETE DEGISIKLIGI
      PERFORM public.add_treatment_day_with_sessions(
        p_case_id,
        (SELECT treatment_date FROM public.treatment_days WHERE id = v_day_id),
        v_day_plan->'sessions',
        v_day_id
      );
      v_total_seans := v_total_seans + jsonb_array_length(v_day_plan->'sessions');
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'guncellenen_seans', v_total_seans);
END;
$$;

GRANT EXECUTE ON FUNCTION public.recete_guncelle TO anon, authenticated;

-- RPC 4: close_case_with_remaining
-- Spec: L804-907
-- Vakayı erken kapat. Tüm kalan seanslar uygulanmadi olarak işaretlenir + stok iade.
DROP FUNCTION IF EXISTS public.close_case_with_remaining(uuid, text);
CREATE OR REPLACE FUNCTION public.close_case_with_remaining(
  p_case_id  uuid,
  p_not      text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_remaining_count int;
BEGIN
  -- 1. Stok iade: SEANS olan drug_admins (seans_admin_id NOT NULL)
  UPDATE public.stok_hareket sh
  SET iptal = true
  FROM public.drug_administrations da
  JOIN public.treatment_day_uygulamalar tdu
    ON tdu.id = da.seans_admin_id
  WHERE tdu.case_id = p_case_id
    AND tdu.uygulama_tamamlandi_at IS NULL
    AND tdu.uygulanmadi = false
    AND sh.notlar = 'drug_admin:' || da.id::text
    AND sh.iptal = false;

  -- ESKI VAKA FALLBACK: seans_admin_id NULL olan drug_admins (seans tablosu kullanilmamis)
  UPDATE public.stok_hareket sh
  SET iptal = true
  FROM public.drug_administrations da
  JOIN public.treatment_days td ON td.id = da.treatment_day_id
  WHERE td.case_id = p_case_id
    AND da.seans_admin_id IS NULL
    AND da.uygulama_tamamlandi_at IS NULL
    AND (da.uygulanmadi IS NULL OR da.uygulanmadi = false)
    AND sh.notlar = 'drug_admin:' || da.id::text
    AND sh.iptal = false;

  -- 2. Seans tablosu: uygulanmadi=true
  UPDATE public.treatment_day_uygulamalar
  SET uygulanmadi = true,
      iptal_nedeni = 'Vaka erken kapatildi' || COALESCE(': ' || p_not, ''),
      updated_at = now()
  WHERE case_id = p_case_id
    AND uygulama_tamamlandi_at IS NULL
    AND uygulanmadi = false;

  GET DIAGNOSTICS v_remaining_count = ROW_COUNT;

  -- 3. drug_admins senkron (seans uzerinden)
  UPDATE public.drug_administrations da
  SET uygulanmadi = true
  FROM public.treatment_day_uygulamalar tdu
  WHERE tdu.id = da.seans_admin_id
    AND tdu.case_id = p_case_id
    AND tdu.uygulanmadi = true
    AND da.uygulanmadi IS DISTINCT FROM true;

  -- ESKI VAKA FALLBACK
  UPDATE public.drug_administrations da
  SET uygulanmadi = true
  FROM public.treatment_days td
  WHERE td.id = da.treatment_day_id
    AND td.case_id = p_case_id
    AND da.seans_admin_id IS NULL
    AND da.uygulama_tamamlandi_at IS NULL
    AND da.uygulanmadi IS DISTINCT FROM true;

  -- 4. treatment_days tamamlandi
  UPDATE public.treatment_days
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE case_id = p_case_id AND tamamlandi = false;

  -- 5. gorev_log kalan acik gorevler
  UPDATE public.gorev_log g
  SET tamamlandi = true, tamamlanma_tarihi = now()
  FROM public.treatment_days td
  WHERE td.case_id = p_case_id
    AND (g.aciklama::jsonb->>'day_id')::uuid = td.id
    AND g.tamamlandi = false;

  -- 6. Case kapat
  UPDATE public.cases
  SET status = 'closed', closed_at = now()
  WHERE id = p_case_id;

  -- 7. Audit
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

  RETURN jsonb_build_object('ok', true, 'iptal_edilen_seans', v_remaining_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.close_case_with_remaining TO anon, authenticated;

-- RPC 5: treatment_day_tamamla
-- Spec: L915-1046
-- Tedavi gününü kapat. Eski (drug_admin) + yeni (seans) akış destekler.
-- Idempotent: zaten tamamlanmışsa noop.
DROP FUNCTION IF EXISTS public.treatment_day_tamamla(uuid, text, uuid[]);
CREATE OR REPLACE FUNCTION public.treatment_day_tamamla(
  p_day_id           uuid,
  p_not              text    DEFAULT NULL,
  p_uygulanmadi_ids  uuid[]  DEFAULT '{}'
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_day        public.treatment_days%ROWTYPE;
  v_seans_sayisi int;
  v_tamam       int;
  v_uygulanmadi int;
  v_onceki      boolean;
  v_admin_id    uuid;
BEGIN
  SELECT * INTO v_day FROM public.treatment_days WHERE id = p_day_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Tedavi gunu bulunamadi: %', p_day_id; END IF;
  IF v_day.tamamlandi THEN
    RETURN jsonb_build_object('ok', true, 'day_id', p_day_id, 'mesaj', 'Zaten tamamlanmis (idempotent)');
  END IF;

  -- Onceki gun tamamlanmali
  SELECT EXISTS(
    SELECT 1 FROM public.treatment_days
    WHERE case_id = v_day.case_id AND day_no < v_day.day_no
      AND (tamamlandi IS NULL OR tamamlandi = false)
  ) INTO v_onceki;
  IF v_onceki THEN RAISE EXCEPTION 'Onceki tedavi gunleri tamamlanmadan bu gun tamamlanamaz'; END IF;

  -- YENI: seans_sayisi > 0 ise "tum seanslar done" kontrolu
  v_seans_sayisi := COALESCE(v_day.seans_sayisi, 1);
  IF v_seans_sayisi > 1 THEN
    SELECT
      COUNT(*) FILTER (WHERE uygulama_tamamlandi_at IS NOT NULL),
      COUNT(*) FILTER (WHERE uygulanmadi = true)
    INTO v_tamam, v_uygulanmadi
    FROM public.treatment_day_uygulamalar WHERE treatment_day_id = p_day_id;

    IF (v_tamam + v_uygulanmadi + COALESCE(array_length(p_uygulanmadi_ids, 1), 0)) < v_seans_sayisi THEN
      RAISE EXCEPTION 'Tum seanslar tamamlanmadi (%/% done, % uygulanmadi)', 
        v_tamam, v_seans_sayisi, v_uygulanmadi;
    END IF;
  END IF;

  -- Uygulanmadi isaretlemeleri
  -- p_uygulanmadi_ids: drug_admins.id (eski) veya tdu.id (yeni) olabilir
  IF array_length(p_uygulanmadi_ids, 1) > 0 THEN
    FOREACH v_admin_id IN ARRAY p_uygulanmadi_ids
    LOOP
      -- 1. drug_admins'de ara (eski tek-seans)
      UPDATE public.drug_administrations
      SET uygulanmadi = true
      WHERE id = v_admin_id
        AND treatment_day_id = p_day_id
        AND uygulanmadi IS DISTINCT FROM true;

      -- 2. Bulunamadiysa seans tablosu uzerinden (yeni cok-seans)
      -- v_admin_id = tdu.id, seans_admin_id FK ile bagli drug_admins'leri bul
      UPDATE public.drug_administrations
      SET uygulanmadi = true
      WHERE seans_admin_id = v_admin_id
        AND treatment_day_id = p_day_id
        AND uygulanmadi IS DISTINCT FROM true;

      -- Seans tablosunu da isaretle
      UPDATE public.treatment_day_uygulamalar
      SET uygulama_tamamlandi_at = COALESCE(uygulama_tamamlandi_at, now()),
          uygulama_notu = COALESCE(uygulama_notu, p_not),
          gerceklesme_saati = COALESCE(gerceklesme_saati, NOW()::time),
          updated_at = now()
      WHERE id = v_admin_id
        AND uygulama_tamamlandi_at IS NULL
        AND uygulanmadi = false;

      -- 3. Stok iade: stok_hareket_ref kolonu Faz 1'de yok.
      -- Bunun yerine: v_admin_id = tdu.id ise seans uzerinden bulunan drug_admins'lerin notlar pattern'i
      UPDATE public.stok_hareket sh
      SET iptal = true
      FROM public.drug_administrations da
      WHERE (
        -- v_admin_id tdu.id ise (seans uzerinden)
        da.seans_admin_id = v_admin_id
        OR
        -- v_admin_id drug_admins.id ise (eski tek-seans)
        da.id = v_admin_id
      )
      AND da.treatment_day_id = p_day_id
      AND sh.notlar = 'drug_admin:' || da.id::text
      AND sh.iptal = false;
    END LOOP;
  END IF;

  -- Gun done
  UPDATE public.treatment_days
  SET tamamlandi = true, tamamlanma_tarihi = now(), tamamlanma_notu = p_not
  WHERE id = p_day_id;

  -- Gorev log
  UPDATE public.gorev_log
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE gorev_tipi IN ('TEDAVI_GUN', 'TEDAVI_SEANS')
    AND tamamlandi = false
    AND (aciklama::jsonb->>'day_id')::uuid = p_day_id;

  RETURN jsonb_build_object('ok', true, 'day_id', p_day_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.treatment_day_tamamla TO anon, authenticated;

COMMIT;

