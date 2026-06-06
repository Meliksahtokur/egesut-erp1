-- ============================================================
-- tohumlama_geri_al + case_geri_al RPC'leri
-- Domain-specific geri alma: stok reverse + trigger yan etkileri
-- Task 1 + Task 2 from docs/plans/2026-05-19-geri-alma-tohumlama-case.md
-- ============================================================

BEGIN;

-- 1. Tohumlama Geri Alma RPC
CREATE OR REPLACE FUNCTION public.tohumlama_geri_al(
  p_tohumlama_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tohumlama  record;
  v_stok_id    text;
  v_stok_miktar numeric;
BEGIN
  -- 1. Tohumlama kaydını oku
  SELECT * INTO v_tohumlama FROM public.tohumlama WHERE id = p_tohumlama_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'Tohumlama kaydı bulunamadı');
  END IF;

  -- 2. Kızgınlık log'u geri al
  UPDATE public.kizginlik_log
  SET cozuldu = false
  WHERE hayvan_id = v_tohumlama.hayvan_id
    AND tarih <= v_tohumlama.tarih
    AND cozuldu = true
    AND tedavi_case_id IS NULL
    AND NOT EXISTS (
      SELECT 1 FROM public.tohumlama t2
      WHERE t2.hayvan_id = v_tohumlama.hayvan_id
        AND t2.id != p_tohumlama_id
        AND t2.tarih >= v_tohumlama.tarih
    );

  -- 3. Sperma stok reverse
  IF v_tohumlama.sperma IS NOT NULL AND v_tohumlama.sperma != '' THEN
    SELECT id INTO v_stok_id FROM public.stok
    WHERE urun_adi ILIKE '%' || v_tohumlama.sperma || '%'
      AND kategori = 'Sperma'
    LIMIT 1;

    IF v_stok_id IS NOT NULL THEN
      SELECT COALESCE(SUM(miktar), 0) INTO v_stok_miktar
      FROM public.stok_hareket
      WHERE stok_id = v_stok_id
        AND referans_tipi = 'tohumlama'
        AND referans_id = p_tohumlama_id
        AND NOT iptal;

      IF v_stok_miktar > 0 THEN
        INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal, referans_tipi, referans_id)
        VALUES (v_stok_id, 'Tohumlama (Geri Al)', -v_stok_miktar, 'Tohumlama geri alındı: ' || p_tohumlama_id, false, 'tohumlama_geri_al', p_tohumlama_id);
      END IF;
    END IF;
  END IF;

  -- 4. Tohumlama kaydını sil
  DELETE FROM public.tohumlama WHERE id = p_tohumlama_id;

  -- 5. islem_log'u işaretle
  UPDATE public.islem_log
  SET durum = 'geri_alindi', geri_alma_tarihi = now()
  WHERE ref_tablo = 'tohumlama' AND ref_id = p_tohumlama_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.tohumlama_geri_al(text) TO anon, authenticated;

-- 2. Case Geri Alma RPC (Soft Delete)
CREATE OR REPLACE FUNCTION public.case_geri_al(
  p_case_id uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_case       record;
  v_da_count   integer;
BEGIN
  -- 1. Case kaydını oku
  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'Case bulunamadı');
  END IF;

  -- 2. Kızgınlık bağlantısını geri al
  UPDATE public.kizginlik_log
  SET tedavi_case_id = NULL,
      cozuldu = false
  WHERE tedavi_case_id = p_case_id;

  -- 3. Drug administrations stok reverse
  SELECT COUNT(*) INTO v_da_count FROM public.drug_administrations da
  JOIN public.treatment_days td ON td.id = da.treatment_day_id
  WHERE td.case_id = p_case_id;

  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal, referans_tipi, referans_id)
  SELECT
    da.drug_product_id,
    'Case (Geri Al)',
    -da.dose,
    'Case geri alındı: ' || p_case_id::text,
    false,
    'case_geri_al',
    p_case_id::text
  FROM public.drug_administrations da
  JOIN public.treatment_days td ON td.id = da.treatment_day_id
  WHERE td.case_id = p_case_id;

  -- 4. Drug administrations ve treatment days sil
  DELETE FROM public.drug_administrations da
  USING public.treatment_days td
  WHERE td.id = da.treatment_day_id AND td.case_id = p_case_id;

  DELETE FROM public.treatment_days WHERE case_id = p_case_id;

  -- 5. Case soft delete
  UPDATE public.cases
  SET status = 'closed', closed_at = now(), notes = COALESCE(notes || ' | ', '') || 'Geri alındı: ' || now()::text
  WHERE id = p_case_id;

  -- 6. islem_log'u işaretle
  UPDATE public.islem_log
  SET durum = 'geri_alindi', geri_alma_tarihi = now()
  WHERE ref_tablo = 'cases' AND ref_id = p_case_id::text;

  RETURN jsonb_build_object(
    'ok', true,
    'silinen_ilac_kaydi', v_da_count,
    'kizginlik_baglantisi_koptu', (SELECT count(*) FROM kizginlik_log WHERE tedavi_case_id = p_case_id) = 0
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.case_geri_al(uuid) TO anon, authenticated;

COMMIT;
