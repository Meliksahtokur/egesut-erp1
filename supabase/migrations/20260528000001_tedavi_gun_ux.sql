-- ══════════════════════════════════════════════════════
-- Migration: 20260528000001_tedavi_gun_ux
-- TEDAVI_GUN UX: plan notu, saat, uygulanmadı kolonları
-- ══════════════════════════════════════════════════════

-- 1. cases.plan_notu — tüm tedavi planını kapsayan master planlayıcı notu
--    Her TEDAVI_GUN görevinde gösterilir (UI okur, görev modalında readonly)
ALTER TABLE public.cases
  ADD COLUMN IF NOT EXISTS plan_notu TEXT;

-- 2. treatment_days.planned_time — tedavi saati (sıralama için)
--    add_treatment_day RPC ile set edilir. Görev kartında ve dashboardda gösterilir.
ALTER TABLE public.treatment_days
  ADD COLUMN IF NOT EXISTS planned_time TIME;

-- 3. drug_administrations.uygulanmadi — uygulayıcı bu ilacı atladıysa TRUE
--    TRUE olursa treatment_day_tamamla stok_hareket'i iptal eder (iade).
ALTER TABLE public.drug_administrations
  ADD COLUMN IF NOT EXISTS uygulanmadi BOOLEAN DEFAULT FALSE;

-- ══════════════════════════════════════════════════════
-- RPC Güncellemeleri — Task 2+3+4
-- ══════════════════════════════════════════════════════

-- Task 2: treatment_day_tamamla — p_uygulanmadi_ids + stok iade
DROP FUNCTION IF EXISTS public.treatment_day_tamamla(uuid, text);
DROP FUNCTION IF EXISTS public.treatment_day_tamamla(uuid, text, uuid[]);

CREATE OR REPLACE FUNCTION public.treatment_day_tamamla(
  p_day_id           uuid,
  p_not              text    DEFAULT NULL,
  p_uygulanmadi_ids  uuid[]  DEFAULT '{}'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_day       public.treatment_days%ROWTYPE;
  v_onceki    boolean;
  v_admin_id  uuid;
  v_stok_id   text;
BEGIN
  -- Mevcut logic --
  SELECT * INTO v_day FROM public.treatment_days WHERE id = p_day_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tedavi günü bulunamadı: %', p_day_id;
  END IF;

  IF v_day.tamamlandi THEN
    RAISE EXCEPTION 'Bu tedavi günü zaten tamamlandı';
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.treatment_days
    WHERE case_id = v_day.case_id
      AND day_no  < v_day.day_no
      AND (tamamlandi IS NULL OR tamamlandi = false)
  ) INTO v_onceki;

  IF v_onceki THEN
    RAISE EXCEPTION 'Önceki tedavi günleri tamamlanmadan bu gün tamamlanamaz';
  END IF;

  UPDATE public.treatment_days
  SET tamamlandi        = true,
      tamamlanma_tarihi = now(),
      tamamlanma_notu   = p_not
  WHERE id = p_day_id;

  -- YENİ: Uygulanmayan ilaçlar — uygulanmadi=true + stok iadesi --
  IF array_length(p_uygulanmadi_ids, 1) > 0 THEN
    FOREACH v_admin_id IN ARRAY p_uygulanmadi_ids
    LOOP
      -- Güvenlik kilidi: sadece bu güne ait ilaçlar işlenir
      UPDATE public.drug_administrations
      SET uygulanmadi = true
      WHERE id = v_admin_id
        AND treatment_day_id = p_day_id
      RETURNING stok_id INTO v_stok_id;

      -- Stok hareketi varsa iptal et (iade)
      IF v_stok_id IS NOT NULL THEN
        UPDATE public.stok_hareket
        SET iptal = true
        WHERE notlar = 'drug_admin:' || v_admin_id::text
          AND iptal = false;
      END IF;
    END LOOP;
  END IF;

  RETURN jsonb_build_object('ok', true, 'day_id', p_day_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.treatment_day_tamamla(uuid, text, uuid[]) TO anon, authenticated;

-- Task 3: add_treatment_day — p_planned_time parametresi
DROP FUNCTION IF EXISTS public.add_treatment_day(uuid, date);
DROP FUNCTION IF EXISTS public.add_treatment_day(uuid, date, time);

CREATE OR REPLACE FUNCTION public.add_treatment_day(
  p_case_id      uuid,
  p_date         date,
  p_planned_time time DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_day_id        uuid;
  v_gorev_id      uuid;
  v_prev_gorev_id uuid := NULL;
  v_day_no        int;
  v_case          record;
  v_gecmis        boolean;
BEGIN
  SELECT COALESCE(MAX(day_no), 0) + 1 INTO v_day_no
  FROM public.treatment_days
  WHERE case_id = p_case_id;

  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadı');
  END IF;

  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakaya gün eklenemez');
  END IF;

  v_gecmis := p_date < CURRENT_DATE;

  -- Zincir: önceki günün gorev_log ID'sini bul
  IF v_day_no > 1 THEN
    SELECT g.id INTO v_prev_gorev_id
    FROM public.gorev_log g
    JOIN public.treatment_days td ON (g.aciklama::jsonb->>'day_id')::uuid = td.id
    WHERE td.case_id = p_case_id
      AND td.day_no  = v_day_no - 1
      AND g.gorev_tipi = 'TEDAVI_GUN'
    LIMIT 1;
  END IF;

  INSERT INTO public.treatment_days(id, case_id, day_no, treatment_date, tamamlandi, tamamlanma_tarihi, planned_time)
  VALUES (
    gen_random_uuid(), p_case_id, v_day_no, p_date,
    v_gecmis,
    CASE WHEN v_gecmis THEN p_date::timestamptz ELSE NULL END,
    p_planned_time
  )
  RETURNING id INTO v_day_id;

  INSERT INTO public.gorev_log(
    id, gorev_tipi, hayvan_id, hedef_tarih, aciklama,
    tamamlandi, tamamlanma_tarihi, parent_id
  )
  VALUES (
    gen_random_uuid(),
    'TEDAVI_GUN',
    v_case.animal_id,
    p_date,
    jsonb_build_object(
      'day_id',       v_day_id,
      'gun_no',       v_day_no,
      'label',        'Gün ' || v_day_no || ' tedavisi — ' || to_char(p_date, 'DD.MM.YYYY'),
      'planned_time', COALESCE(p_planned_time::text, '')
    )::text,
    v_gecmis,
    CASE WHEN v_gecmis THEN p_date::timestamptz ELSE NULL END,
    v_prev_gorev_id
  )
  RETURNING id INTO v_gorev_id;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    'TEDAVI_GUN_EKLENDI',
    v_case.animal_id,
    v_day_id::text,
    'treatment_days',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'treatment_days', 'id', v_day_id::text),
        jsonb_build_object('tablo', 'gorev_log',      'id', v_gorev_id::text)
      ),
      'guncellenen', '[]'::jsonb
    )
  );

  RETURN jsonb_build_object('ok', true, 'day_id', v_day_id, 'day_no', v_day_no, 'gecmis', v_gecmis);
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_treatment_day(uuid, date, time) TO anon, authenticated;

-- Task 4: case_plan_notu_guncelle — yeni RPC
CREATE OR REPLACE FUNCTION public.case_plan_notu_guncelle(
  p_case_id   uuid,
  p_plan_notu text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.cases
  SET plan_notu = p_plan_notu
  WHERE id = p_case_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Vaka bulunamadı: %', p_case_id;
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.case_plan_notu_guncelle(uuid, text) TO anon, authenticated;
