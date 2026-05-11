-- Migration: hayvan_ekle + hayvan_guncelle RPCs now accept p_padok_id (uuid)
-- Backward compat: p_padok text still works via name lookup
BEGIN;

CREATE OR REPLACE FUNCTION public.hayvan_ekle(
  p_kupe_no        text    DEFAULT NULL,
  p_devlet_kupe    text    DEFAULT NULL,
  p_irk            text    DEFAULT NULL,
  p_cinsiyet       text    DEFAULT NULL,
  p_dogum_tarihi   date    DEFAULT NULL,
  p_grup           text    DEFAULT 'Genel',
  p_padok          text    DEFAULT NULL,
  p_dogum_kg       numeric DEFAULT NULL,
  p_anne_id        text    DEFAULT NULL,
  p_baba_bilgi     text    DEFAULT NULL,
  p_canli_agirlik  numeric DEFAULT NULL,
  p_boy            numeric DEFAULT NULL,
  p_renk           text    DEFAULT NULL,
  p_ayirici_ozellik text   DEFAULT NULL,
  p_padok_id       uuid    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id text;
  v_padok_id uuid;
  v_padok_ad text;
BEGIN
  v_id := gen_random_uuid()::text;

  IF p_padok_id IS NOT NULL THEN
    v_padok_id := p_padok_id;
    SELECT ad INTO v_padok_ad FROM padoklar WHERE id = p_padok_id;
  ELSIF p_padok IS NOT NULL THEN
    SELECT id, ad INTO v_padok_id, v_padok_ad FROM padoklar WHERE ad = p_padok;
    IF v_padok_id IS NULL THEN
      v_padok_ad := p_padok;
    END IF;
  END IF;

  INSERT INTO hayvanlar (
    id, kupe_no, devlet_kupe, irk, cinsiyet, dogum_tarihi,
    grup, padok, padok_id, durum, dogum_kg, anne_id, baba_bilgi,
    canli_agirlik, boy, renk, ayirici_ozellik
  ) VALUES (
    v_id, NULLIF(p_kupe_no,''), NULLIF(p_devlet_kupe,''),
    NULLIF(p_irk,''), p_cinsiyet, p_dogum_tarihi,
    p_grup, v_padok_ad, v_padok_id, 'Aktif', p_dogum_kg, p_anne_id, p_baba_bilgi,
    p_canli_agirlik, p_boy, p_renk, p_ayirici_ozellik
  );

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

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
  p_ayirici_ozellik text    DEFAULT NULL,
  p_baba_bilgi      text    DEFAULT NULL,
  p_notlar          text    DEFAULT NULL,
  p_anne_id         text    DEFAULT NULL,
  p_padok_id        uuid    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_padok_id uuid;
  v_padok_ad text;
BEGIN
  IF p_padok_id IS NOT NULL THEN
    v_padok_id := p_padok_id;
    SELECT ad INTO v_padok_ad FROM padoklar WHERE id = p_padok_id;
  ELSIF p_padok IS NOT NULL THEN
    SELECT id, ad INTO v_padok_id, v_padok_ad FROM padoklar WHERE ad = p_padok;
  END IF;

  UPDATE hayvanlar SET
    kupe_no          = COALESCE(NULLIF(p_kupe_no,''),        kupe_no),
    devlet_kupe      = COALESCE(NULLIF(p_devlet_kupe,''),    devlet_kupe),
    irk              = COALESCE(NULLIF(p_irk,''),            irk),
    cinsiyet         = COALESCE(NULLIF(p_cinsiyet,''),       cinsiyet),
    dogum_tarihi     = COALESCE(p_dogum_tarihi,              dogum_tarihi),
    grup             = COALESCE(NULLIF(p_grup,''),           grup),
    padok            = COALESCE(v_padok_ad,                  padok),
    padok_id         = COALESCE(v_padok_id,                  padok_id),
    dogum_kg         = COALESCE(p_dogum_kg,                  dogum_kg),
    canli_agirlik    = COALESCE(p_canli_agirlik,             canli_agirlik),
    boy              = COALESCE(p_boy,                       boy),
    renk             = COALESCE(NULLIF(p_renk,''),           renk),
    ayirici_ozellik  = COALESCE(NULLIF(p_ayirici_ozellik,''),ayirici_ozellik),
    baba_bilgi       = COALESCE(NULLIF(p_baba_bilgi,''),     baba_bilgi),
    notlar           = COALESCE(NULLIF(p_notlar,''),         notlar),
    anne_id          = COALESCE(NULLIF(p_anne_id,''),        anne_id)
  WHERE id = p_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

END;
