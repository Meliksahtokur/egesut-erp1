-- Migration: padok_degistir RPC — safe, logged padok change
BEGIN;

CREATE OR REPLACE FUNCTION public.padok_degistir(
  p_hayvan_id text,
  p_yeni_padok_id uuid,
  p_not text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_hayvan record;
  v_eski_padok text;
  v_eski_padok_id uuid;
  v_yeni_padok_adi text;
BEGIN
  -- 1. Validate hayvan exists
  SELECT id, kupe_no, padok, padok_id INTO v_hayvan
  FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hayvan bulunamadı');
  END IF;

  -- 2. Validate target padok exists
  SELECT ad INTO v_yeni_padok_adi
  FROM public.padoklar WHERE id = p_yeni_padok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef padok bulunamadı');
  END IF;

  -- 3. Check if already in that padok
  IF v_hayvan.padok_id = p_yeni_padok_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hayvan zaten bu padokta');
  END IF;

  v_eski_padok := v_hayvan.padok;
  v_eski_padok_id := v_hayvan.padok_id;

  -- 4. Update hayvan — both padok_id (FK) and padok (TEXT fallback)
  UPDATE public.hayvanlar
  SET padok_id = p_yeni_padok_id,
      padok = v_yeni_padok_adi,
      updated_at = now()
  WHERE id = p_hayvan_id;

  -- 5. Log to islem_log
  INSERT INTO public.islem_log (islem, aciklama, ref_id, created_at)
  VALUES (
    'padok_degistir',
    format(
      'Hayvan %s (%s): %s (%s) → %s (%s)',
      v_hayvan.kupe_no, p_hayvan_id,
      COALESCE(v_eski_padok, '—'), COALESCE(v_eski_padok_id::text, '—'),
      v_yeni_padok_adi, p_yeni_padok_id::text
    ),
    p_hayvan_id,
    now()
  );

  RETURN jsonb_build_object(
    'success', true,
    'hayvan_id', p_hayvan_id,
    'eski_padok', v_eski_padok,
    'eski_padok_id', v_eski_padok_id,
    'yeni_padok', v_yeni_padok_adi,
    'yeni_padok_id', p_yeni_padok_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.padok_degistir(text, uuid, text) TO anon, authenticated;

COMMIT;
