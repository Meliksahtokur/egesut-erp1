-- Migration: tohumlama_case_link
-- 1. tohumlama.case_id FK eklenir
-- 2. kizginlik_vaka_ac RPC — kızgınlık bağlamından case açar

-- ============================================================
-- 1. tohumlama.case_id kolonu
-- ============================================================
ALTER TABLE public.tohumlama
  ADD COLUMN IF NOT EXISTS case_id uuid REFERENCES public.cases(id) ON DELETE SET NULL;

-- ============================================================
-- 2. kizginlik_vaka_ac RPC
-- kızgınlık bağlamından case açma, kızgınlık+tohumlama çapraz bağlantı
-- ============================================================
CREATE OR REPLACE FUNCTION public.kizginlik_vaka_ac(
  p_kizginlik_id   text,
  p_tani           text,
  p_tohumlama_id   text    DEFAULT NULL,
  p_notlar         text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_kiz       record;
  v_case_id   uuid;
  v_disease   record;
BEGIN
  SELECT * INTO v_kiz FROM public.kizginlik_log WHERE id = p_kizginlik_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kızgınlık kaydı bulunamadı');
  END IF;

  -- Hastalık adından disease_id bul (case-insensitive)
  SELECT * INTO v_disease FROM public.diseases
  WHERE name ILIKE p_tani OR p_tani ILIKE '%' || name || '%'
  ORDER BY length(name) DESC
  LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO public.diseases (name, category)
    VALUES (p_tani, 'Üreme')
    RETURNING * INTO v_disease;
  END IF;

  INSERT INTO public.cases (animal_id, disease_id, start_date, status, notes, created_at)
  VALUES (
    v_kiz.hayvan_id,
    v_disease.id,
    CURRENT_DATE,
    'active',
    COALESCE(p_notlar, 'Tohumlama sırasında tespit edildi'),
    now()
  )
  RETURNING id INTO v_case_id;

  UPDATE public.kizginlik_log
  SET tedavi_case_id = v_case_id
  WHERE id = p_kizginlik_id;

  IF p_tohumlama_id IS NOT NULL AND p_tohumlama_id <> '' THEN
    UPDATE public.tohumlama
    SET case_id = v_case_id
    WHERE id = p_tohumlama_id;
  END IF;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    'KIZGINLIK_VAKA_ACILDI',
    v_kiz.hayvan_id,
    p_kizginlik_id,
    'kizginlik_log',
    jsonb_build_object(
      'case_id', v_case_id,
      'tani', p_tani,
      'kizginlik_id', p_kizginlik_id,
      'tohumlama_id', p_tohumlama_id
    )
  );

  RETURN jsonb_build_object('ok', true, 'case_id', v_case_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.kizginlik_vaka_ac(text, text, text, text) TO anon, authenticated;
