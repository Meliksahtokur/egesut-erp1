-- Migration: padok_degistir_toplu RPC — bulk padok transfer with per-animal logging
BEGIN;

CREATE OR REPLACE FUNCTION public.padok_degistir_toplu(
  p_hayvan_ids text[],
  p_yeni_padok_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_hayvan record;
  v_yeni_padok_adi text;
  v_basarili int := 0;
  v_basarisiz int := 0;
  v_hatalar text[] := '{}';
  v_eski_padok text;
  v_eski_padok_id uuid;
BEGIN
  -- Validate target padok exists
  SELECT ad INTO v_yeni_padok_adi
  FROM public.padoklar WHERE id = p_yeni_padok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef padok bulunamadı');
  END IF;

  -- Loop through each hayvan
  FOR i IN 1..array_length(p_hayvan_ids, 1) LOOP
    BEGIN
      -- Validate hayvan exists
      SELECT id, kupe_no, padok, padok_id INTO v_hayvan
      FROM public.hayvanlar WHERE id = p_hayvan_ids[i];
      IF NOT FOUND THEN
        v_basarisiz := v_basarisiz + 1;
        v_hatalar := v_hatalar || format('Hayvan %s bulunamadı', p_hayvan_ids[i]);
        CONTINUE;
      END IF;

      -- Skip if already in that padok
      IF v_hayvan.padok_id = p_yeni_padok_id THEN
        v_basarisiz := v_basarisiz + 1;
        v_hatalar := v_hatalar || format('Hayvan %s (%s) zaten bu padokta', v_hayvan.kupe_no, p_hayvan_ids[i]);
        CONTINUE;
      END IF;

      v_eski_padok := v_hayvan.padok;
      v_eski_padok_id := v_hayvan.padok_id;

      -- Update hayvan — both padok_id (FK) and padok (TEXT fallback)
      UPDATE public.hayvanlar
      SET padok_id = p_yeni_padok_id,
          padok = v_yeni_padok_adi,
          updated_at = now()
      WHERE id = p_hayvan_ids[i];

      -- Log to islem_log
      INSERT INTO public.islem_log (islem, aciklama, ref_id, created_at)
      VALUES (
        'padok_degistir',
        format(
          'Hayvan %s (%s): %s (%s) → %s (%s) [toplu]',
          v_hayvan.kupe_no, p_hayvan_ids[i],
          COALESCE(v_eski_padok, '—'), COALESCE(v_eski_padok_id::text, '—'),
          v_yeni_padok_adi, p_yeni_padok_id::text
        ),
        p_hayvan_ids[i],
        now()
      );

      v_basarili := v_basarili + 1;
    EXCEPTION WHEN OTHERS THEN
      v_basarisiz := v_basarisiz + 1;
      v_hatalar := v_hatalar || format('Hayvan %s: %s', p_hayvan_ids[i], SQLERRM);
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'basarili', v_basarili,
    'basarisiz', v_basarisiz,
    'hatalar', v_hatalar,
    'yeni_padok', v_yeni_padok_adi,
    'yeni_padok_id', p_yeni_padok_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.padok_degistir_toplu(text[], uuid) TO anon, authenticated;

COMMIT;