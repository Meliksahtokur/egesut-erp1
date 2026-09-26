-- ============================================================================
-- Migration: 20260925100002_add_treatment_day_ust_gorev_tarihi
-- Tarih: 2026-09-25 · Erteleme-genel turu E5 (zarf E5 / plan-db.md Adım 1)
-- Etkiler: public.add_treatment_day_with_sessions YENİDEN TANIMI (canlı DEMO
--   gövdesinden başlar — 000008 tuzağı; önceki tüm gövde davranışları korunur).
--
-- Amaç (E5): RPC'nin UPDATE dalı (p_existing_day_id dolu) gün satırının
--   treatment_date'ini taşır ve TEDAVI_GUN etiketini tazeler AMA üst
--   gorev_log.hedef_tarih'i güncellemez — kart eski tarihte kalır,
--   etiket yeni tarihi söyler (kırmızı probe 2026-09-25: gün 24→28.09 taşındı,
--   etiket '28.09.2026' iken hedef_tarih 2026-09-24'te kaldı).
--
-- Değişiklikler (canlı gövdeye göre TAM LİSTE — minimal):
--   1. UPDATE dalındaki gorev_log SET blokuna `hedef_tarih = p_date` eklendi
--      (INSERT dalındaki kalıbın birebir taşıması — 20260611000002:114).
--   2. Aynı dalın `DELETE FROM gorev_log WHERE gorev_tipi = 'TEDAVI_SEANS'`
--      ifadesine `left(aciklama, 1) = '{'` guard'ı eklendi: canlı gövde cast'ı
--      TÜM TEDAVI_SEANS satırlarında değerlendirir; demo'da 1 legacy JSON-dışı
--      satır ('CHILD-TED-CONTAIN', iptal=t, hedef 2030-01-02) cast'ı kırarak
--      update dalını işlemez hale getiriyordu [OBSERVED kırmızı probe hatası].
--      Guard, JSON olmayan satırları zaten eşleyemeyeceği kümeden çıkarır —
--      davranış değişimi yok, kırılma onarımı (E0 migration'ı aynı deseni
--      kullanır: left(g.aciklama, 1) = '{').
--   3. SECDEF sertleştirmesi: tırnaksız `SET search_path = public, pg_temp`
--      eklendi (canlı gövdede yoktu; migration kalıbı gereği).
--   4. FROM-pozisyonundaki iki pg_catalog builtin'i (jsonb_array_elements,
--      unnest) şema-nitelikli yazıldı — çözünürlük değişmez (pg_catalog
--      search_path'te örtük önceliklidir), db-validate Faz B statik
--      referans çözümü içindir.
--
-- Dokunulmazlar: INSERT dalı, seans kurulum döngüsü, stok hareketleri,
--   islem_log audit, RETURN sözleşmesi — bayt-es canlı gövde.
--
-- Çağıranlar (impact): js/api.js:380 (RPC tablo haritası) + js/api.js:662
--   rpcAddTreatmentDayWithSessions sarmalı; UI akışında doğrudan çağıran YOK
--   (UI 'add_treatment_day' kullanır, js/ui.js:7908) — davranış kırılması riski
--   yok; sarmalın belgelenen replace-mode sözleşmesi tutarlı hale gelir.
--
-- Geri alınabilir: evet — bu dosya CREATE OR REPLACE; önceki gövdeye dönüş
--   için önceki migration gövdesi yeniden uygulanır (DROP gerekmez).
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION public.add_treatment_day_with_sessions(p_case_id uuid, p_date date, p_sessions jsonb DEFAULT NULL::jsonb, p_existing_day_id uuid DEFAULT NULL::uuid)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
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

  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadi');
  END IF;
  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapali vakaya gun eklenemez');
  END IF;

  v_gecmis := p_date < CURRENT_DATE;

  IF v_day_no > 1 THEN
    SELECT g.id INTO v_prev_gorev_id
    FROM public.gorev_log g
    JOIN public.treatment_days td ON (g.aciklama::jsonb->>'day_id')::uuid = td.id
    WHERE td.case_id = p_case_id AND td.day_no = v_day_no - 1 AND g.gorev_tipi = 'TEDAVI_GUN'
    LIMIT 1;
  END IF;

  v_seans_sayisi := CASE WHEN p_sessions IS NULL THEN NULL ELSE jsonb_array_length(p_sessions)::smallint END;
  v_first_time   := CASE
    WHEN p_sessions IS NULL THEN NULL
    ELSE (p_sessions->0->>'planned_time')::time
  END;

  IF v_is_update THEN
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
      AND left(aciklama, 1) = '{'
      AND (aciklama::jsonb->>'day_id')::uuid = p_existing_day_id;

    UPDATE public.treatment_days
    SET planned_time = v_first_time,
        seans_sayisi = v_seans_sayisi,
        treatment_date = p_date
    WHERE id = p_existing_day_id
    RETURNING id INTO v_day_id;

    UPDATE public.gorev_log
    SET hedef_tarih = p_date,
        tamamlandi = false,
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

  IF p_sessions IS NOT NULL THEN
    FOR v_session IN SELECT * FROM pg_catalog.jsonb_array_elements(p_sessions)
    LOOP
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

      v_stok_id := v_session->>'stok_id';
      IF v_stok_id IS NOT NULL AND (v_session->>'dose')::numeric > 0 THEN
        INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar)
        VALUES (v_stok_id, 'Tedavi', (v_session->>'dose')::numeric,
                'drug_admin:' || v_drug_admin_id::text)
        RETURNING id INTO v_stok_hareket_id;
      END IF;

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
        FROM pg_catalog.unnest(v_admin_ids) AS id
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
$function$;

-- Kapı kuralları: PUBLIC/anon kapalı, yalnız authenticated (UI RPC sarmalı var)
REVOKE ALL ON FUNCTION public.add_treatment_day_with_sessions(uuid, date, jsonb, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_treatment_day_with_sessions(uuid, date, jsonb, uuid) TO authenticated;

COMMIT;
