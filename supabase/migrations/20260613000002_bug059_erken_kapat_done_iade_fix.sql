-- BUG-059: Erken kapat — biten tedavileri iade etme hatası düzeltmesi
-- Sorun: close_case_with_remaining done seansların stoğunu da iade ediyor +
--        "yapılmadı" işaretliyordu (uygulama_tamamlandi_at kontrolü yoktu).
-- Çözüm: sadece gerçekleşmemiş seanslar/günler iade edilir.
-- Spec: docs/superpowers/specs/2026-06-12-tedavi-seans-gorev-ui-revize-design.md (modal feedback)

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
    AND tdu.uygulanmadi = false
    AND tdu.uygulama_tamamlandi_at IS NULL   -- biten seans iade EDILMEZ
    AND sh.notlar = 'drug_admin:' || da.id::text
    AND sh.iptal = false;

  -- ESKI VAKA FALLBACK: seans_admin_id NULL olan drug_admins (seans tablosu kullanilmamis)
  UPDATE public.stok_hareket sh
  SET iptal = true
  FROM public.drug_administrations da
  JOIN public.treatment_days td ON td.id = da.treatment_day_id
  WHERE td.case_id = p_case_id
    AND da.seans_admin_id IS NULL
    AND td.tamamlandi = false                 -- tamamlanmis gun iade EDILMEZ
    AND (da.uygulanmadi IS NULL OR da.uygulanmadi = false)
    AND sh.notlar = 'drug_admin:' || da.id::text
    AND sh.iptal = false;

  -- 2. Seans tablosu: uygulanmadi=true (sadece gerceklesmemis)
  UPDATE public.treatment_day_uygulamalar
  SET uygulanmadi = true,
      iptal_nedeni = 'Vaka erken kapatildi' || COALESCE(': ' || p_not, ''),
      updated_at = now()
  WHERE case_id = p_case_id
    AND uygulanmadi = false
    AND uygulama_tamamlandi_at IS NULL;       -- biten seans "yapilmadi" YAPILMAZ

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
    AND td.tamamlandi = false                 -- tamamlanmis gun korunur
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
