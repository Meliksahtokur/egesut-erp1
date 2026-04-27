-- ============================================================
-- Bulk Ilac RPC — Toplu Ilac Uygulama
-- Preventive treatment logged directly to islem_log (no vaka required)
-- Stok deduction via stok_hareket ledger
-- Based on: tedavi_ekle pattern (20260312000021) + bulk_vaccination pattern (20260427000010)
-- ============================================================

CREATE OR REPLACE FUNCTION public.bulk_ilac(
  p_animal_ids   text[],
  p_ilac_stok_id text,
  p_miktar       numeric,
  p_notlar       text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_animal_id       text;
  v_stok            record;
  v_success         int := 0;
  v_errors          jsonb := '[]'::jsonb;
  v_total_miktar    numeric;
  v_stok_urun_adi   text;
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

  -- Check stock availability (baslangic_miktar - consumed via stok_hareket)
  -- Using guncel_stok view or manual calculation
  IF (
    COALESCE(v_stok.baslangic_miktar, 0)
    < v_total_miktar
    -- NOTE: Could add SUM(stok_hareket.miktar) subtraction for true remaining stock
    -- but keeping simple check for v1 as per spec
  ) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'mesaj', 'Yetersiz stok: ' || COALESCE(v_stok.baslangic_miktar, 0) || ' mevcut, ' || v_total_miktar || ' gerekli'
    );
  END IF;

  -- Apply to each animal
  FOREACH v_animal_id IN ARRAY p_animal_ids LOOP
    BEGIN
      -- Log to islem_log with TOPLU_ILAC tip
      INSERT INTO public.islem_log (id, tip, ana_hayvan_id, tarih, kullanici_notu, snapshot)
      VALUES (
        gen_random_uuid()::text,
        'TOPLU_ILAC',
        v_animal_id,
        now(),
        p_notlar,
        jsonb_build_object(
          'ilac_stok_id', p_ilac_stok_id,
          'ilac_adi', v_stok_urun_adi,
          'miktar', p_miktar
        )
      );
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
    INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
    VALUES (
      gen_random_uuid()::text,
      p_ilac_stok_id,
      'TOPLU_ILAC',
      p_miktar * v_success,
      v_success || ' hayvana toplu ilaç uygulaması (' || COALESCE(v_stok_urun_adi, p_ilac_stok_id) || ')',
      false
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'total', array_length(p_animal_ids, 1),
    'success', v_success,
    'errors', v_errors
  );
END;
$$;

-- Allow anon/authenticated clients to call this RPC
GRANT EXECUTE ON FUNCTION public.bulk_ilac TO anon, authenticated;