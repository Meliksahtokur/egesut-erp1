-- Migration: kizginlik_postpartum
-- 1. Add sonuc column to kizginlik_log
-- 2. Create kizginlik_yok_kaydet RPC for yoktu recordings

-- ============================================================
-- 1. Add sonuc column
-- ============================================================
ALTER TABLE public.kizginlik_log
  ADD COLUMN IF NOT EXISTS sonuc text DEFAULT 'GOZLEMLENDI';

-- ============================================================
-- 2. Create kizginlik_yok_kaydet RPC
-- ============================================================
CREATE OR REPLACE FUNCTION public.kizginlik_yok_kaydet(
  p_hayvan_id  text,
  p_dogum_id   text,
  p_notlar     text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_id     text := gen_random_uuid()::text;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  INSERT INTO public.kizginlik_log (id, hayvan_id, tarih, belirti, notlar, sonuc)
  VALUES (v_id, p_hayvan_id, CURRENT_DATE, NULL, p_notlar, 'YOKTU');

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.kizginlik_yok_kaydet TO anon, authenticated;