-- ═══════════════════════════════════════════════════════════════
-- Migration 010 — hayvan_guncelle RPC
-- Hayvan kartından bilgi/padok düzenleme
-- ═══════════════════════════════════════════════════════════════

-- updated_at kolonu yoksa ekle
ALTER TABLE public.hayvanlar
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

CREATE OR REPLACE FUNCTION public.hayvan_guncelle(
  p_id              text,
  p_kupe_no         text    DEFAULT NULL,
  p_devlet_kupe     text    DEFAULT NULL,
  p_irk             text    DEFAULT NULL,
  p_cinsiyet        text    DEFAULT NULL,
  p_dogum_tarihi    date    DEFAULT NULL,
  p_grup            text    DEFAULT NULL,
  p_padok           text    DEFAULT NULL,
  p_dogum_kg        numeric DEFAULT NULL,
  p_canli_agirlik   numeric DEFAULT NULL,
  p_boy             numeric DEFAULT NULL,
  p_renk            text    DEFAULT NULL,
  p_ayirici_ozellik text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_chk    jsonb;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hayvan bulunamadı: %', p_id;
  END IF;

  -- Küpe değişiyorsa çakışma kontrolü (kendi küpesini hariç tut)
  IF p_kupe_no IS NOT NULL AND p_kupe_no <> '' AND p_kupe_no <> COALESCE(v_hayvan.kupe_no,'') THEN
    IF EXISTS (SELECT 1 FROM public.hayvanlar WHERE kupe_no = p_kupe_no AND id <> p_id) THEN
      RAISE EXCEPTION 'İşletme küpesi zaten kayıtlı: %', p_kupe_no;
    END IF;
  END IF;

  IF p_devlet_kupe IS NOT NULL AND p_devlet_kupe <> '' AND p_devlet_kupe <> COALESCE(v_hayvan.devlet_kupe,'') THEN
    IF EXISTS (SELECT 1 FROM public.hayvanlar WHERE devlet_kupe = p_devlet_kupe AND id <> p_id) THEN
      RAISE EXCEPTION 'Devlet küpesi zaten kayıtlı: %', p_devlet_kupe;
    END IF;
  END IF;

  UPDATE public.hayvanlar SET
    kupe_no          = COALESCE(NULLIF(p_kupe_no,''),         kupe_no),
    devlet_kupe      = COALESCE(NULLIF(p_devlet_kupe,''),     devlet_kupe),
    irk              = COALESCE(NULLIF(p_irk,''),             irk),
    cinsiyet         = COALESCE(NULLIF(p_cinsiyet,''),        cinsiyet),
    dogum_tarihi     = COALESCE(p_dogum_tarihi,               dogum_tarihi),
    grup             = COALESCE(NULLIF(p_grup,''),            grup),
    padok            = COALESCE(NULLIF(p_padok,''),           padok),
    dogum_kg         = COALESCE(p_dogum_kg,                   dogum_kg),
    canli_agirlik    = COALESCE(p_canli_agirlik,              canli_agirlik),
    boy              = COALESCE(p_boy,                        boy),
    renk             = COALESCE(NULLIF(p_renk,''),            renk),
    ayirici_ozellik  = COALESCE(NULLIF(p_ayirici_ozellik,''), ayirici_ozellik),
    updated_at       = now()
  WHERE id = p_id;

  -- islem_log trigger otomatik yazacak (HAYVAN_GUNCELLENDI)

  RETURN jsonb_build_object('ok', true, 'hayvan_id', p_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.hayvan_guncelle(text,text,text,text,text,date,text,text,numeric,numeric,numeric,text,text) TO anon, authenticated;
