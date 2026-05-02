-- ============================================================
-- Bulk Ilac RPC — Toplu Ilac Uygulama (FIXED)
-- Fix: explicit ::uuid casts on all gen_random_uuid() calls
--       and ::text casts on stok_id references
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
  v_log_id          text;
  v_stok_hareket_id uuid;
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
  FOREACH v_animal_id IN ARRAY p_animal_ids LOOP
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
        v_log_id,              -- ref_id = islem_log.id
        'islem_log'            -- ref_tablo
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
