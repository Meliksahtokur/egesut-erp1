-- ═══ Migration: BUG-061 treatment_day_tamamla UPDATE eksik ═══
-- Tarih: 2026-06-13
-- Bug: tedavi günü done edilse de treatment_days.tamamlandi=true olmuyor
--      (gorev_log tamamlanır ama treatment_days tablosu açık kalıyor)
-- Scope: tüm treatment_day_tamamla çağrıları (küpe 82 gün 4 ile kanıtlandı)
-- TDD: başarısız test reproduce edildi (treatment_days.tamamlandi false kaldı)
-- Plan: docs/plans/2026-06-13-tedavi-gun-tamamla-bug.md

CREATE OR REPLACE FUNCTION public.treatment_day_tamamla(
  p_day_id           uuid,
  p_not              text DEFAULT NULL,
  p_uygulanmadi_ids  uuid[] DEFAULT '{}'::uuid[]
)
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
BEGIN
  SELECT * INTO v_day FROM public.treatment_days WHERE id = p_day_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Tedavi gunu bulunamadi: %', p_day_id; END IF;
  IF v_day.tamamlandi THEN
    RETURN jsonb_build_object('ok', true, 'day_id', p_day_id, 'mesaj', 'Zaten tamamlanmis (idempotent)');
  END IF;

  -- hayvan_id'yi case üzerinden çek (audit için)
  SELECT animal_id INTO v_case_animal FROM public.cases WHERE id = v_day.case_id;

  -- Onceki gun tamamlanmali
  SELECT EXISTS(
    SELECT 1 FROM public.treatment_days
    WHERE case_id = v_day.case_id AND day_no < v_day.day_no
      AND (tamamlandi IS NULL OR tamamlandi = false)
  ) INTO v_onceki;
  IF v_onceki THEN RAISE EXCEPTION 'Onceki tedavi gunleri tamamlanmadan bu gun tamamlanamaz'; END IF;

  -- seans_sayisi > 0 ise "tum seanslar done" kontrolu
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

  -- Uygulanmadi isaretlemeleri (mevcut davranis korunur)
  IF array_length(p_uygulanmadi_ids, 1) > 0 THEN
    FOREACH v_admin_id IN ARRAY p_uygulanmadi_ids
    LOOP
      UPDATE public.drug_administrations
      SET uygulanmadi = true
      WHERE id = v_admin_id
        AND treatment_day_id = p_day_id
        AND uygulanmadi IS DISTINCT FROM true;

      UPDATE public.drug_administrations
      SET uygulanmadi = true
      WHERE seans_admin_id = v_admin_id
        AND treatment_day_id = p_day_id
        AND uygulanmadi IS DISTINCT FROM true;

      UPDATE public.treatment_day_uygulamalar
      SET uygulama_tamamlandi_at = COALESCE(uygulama_tamamlandi_at, now()),
          uygulama_notu = COALESCE(uygulama_notu, p_not),
          gerceklesme_saati = COALESCE(gerceklesme_saati, NOW()::time),
          updated_at = now()
      WHERE id = v_admin_id
        AND uygulama_tamamlandi_at IS NULL
        AND uygulanmadi = false;

      UPDATE public.stok_hareket sh
      SET iptal = true
      FROM public.drug_administrations da
      WHERE (
        da.seans_admin_id = v_admin_id
        OR da.id = v_admin_id
      )
      AND da.treatment_day_id = p_day_id
      AND sh.notlar = 'drug_admin:' || da.id::text
      AND sh.iptal = false;
    END LOOP;
  END IF;

  -- ═══ FIX: tedavi_days tamamlandi olarak işaretle ═══
  UPDATE public.treatment_days
  SET tamamlandi = true,
      tamamlanma_tarihi = now(),
      tamamlanma_notu = p_not
  WHERE id = p_day_id;

  -- Audit: islem_log (BUG-064 pattern)
  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES (
    'TEDAVI_GUN_TAMAMLA',
    v_case_animal,
    p_day_id::text,
    'treatment_days',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(jsonb_build_object(
        'tablo', 'treatment_days',
        'id', p_day_id::text,
        'onceki', jsonb_build_object('tamamlandi', v_day.tamamlandi, 'tamamlanma_tarihi', v_day.tamamlanma_tarihi::text),
        'sonraki', jsonb_build_object('tamamlandi', true, 'tamamlanma_tarihi', now()::text)
      )),
      'silinen', '[]'::jsonb
    ),
    format('Tedavi günü %s tamamlandı (day_no=%s, uygulanmadi_ids=%s)',
      p_day_id, v_day.day_no,
      COALESCE(array_length(p_uygulanmadi_ids, 1)::text, '0'))
  );

  RETURN jsonb_build_object(
    'ok', true,
    'day_id', p_day_id,
    'mesaj', 'Tedavi günü tamamlandı'
  );
END;
$function$;

NOTIFY pgrst, 'reload schema';
