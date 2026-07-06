-- ============================================================================
-- H-11 BUG FIX: hayvan_ekle / hayvan_guncelle — yaş/grup validasyonu
-- ============================================================================
-- BUG-XXX (H-11): js/forms.js:66-77'deki yaş/grup kuralları (buzağı grupları
-- için 180/365 gün sınırı) SADECE frontend'de var. Backend RPC'lerinde karşılığı
-- YOK. Bu migration, frontend'deki 3 kuralı BİREBİR PL/pgSQL'e taşır:
--
--   1) Doğum tarihi ileri tarih olamaz
--   2) "Süt İçen Buzağı" grubuna 6 aylıktan (180 gün) büyük hayvan eklenemez
--   3) Buzağı gruplarına (Süt İçen / Sütten Kesilmiş) 12 aylıktan (365 gün)
--      büyük hayvan eklenemez
--
-- SADECE frontend'den gerçek çağrılan overload'lar değiştirildi:
--   - hayvan_ekle  : p_padok_id parametreli, SECURITY DEFINER overload
--   - hayvan_guncelle: p_padok_id + p_kisir parametreli (en geniş) overload
-- Diğer overload'lara DOKUNULMADI (dead/legacy).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- hayvan_ekle — p_padok_id parametreli overload (frontend'in çağırdığı)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.hayvan_ekle(
  p_kupe_no text DEFAULT NULL::text,
  p_devlet_kupe text DEFAULT NULL::text,
  p_irk text DEFAULT NULL::text,
  p_cinsiyet text DEFAULT NULL::text,
  p_dogum_tarihi date DEFAULT NULL::date,
  p_grup text DEFAULT 'Genel'::text,
  p_padok text DEFAULT NULL::text,
  p_dogum_kg numeric DEFAULT NULL::numeric,
  p_anne_id text DEFAULT NULL::text,
  p_baba_bilgi text DEFAULT NULL::text,
  p_canli_agirlik numeric DEFAULT NULL::numeric,
  p_boy numeric DEFAULT NULL::numeric,
  p_renk text DEFAULT NULL::text,
  p_ayirici_ozellik text DEFAULT NULL::text,
  p_padok_id uuid DEFAULT NULL::uuid
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id text;
  v_padok_id uuid;
  v_padok_ad text;
  v_yas_gun integer;
BEGIN
  -- H-11: Yaş/grup validasyonu (js/forms.js:66-77 birebir)
  -- Sadece doğum tarihi verildiğinde kontrol et (nullable alan — mevcut satırlar NULL olabilir)
  IF p_dogum_tarihi IS NOT NULL THEN
    v_yas_gun := floor((current_date - p_dogum_tarihi));
    IF v_yas_gun < 0 THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Doğum tarihi ileri tarih olamaz');
    END IF;
    IF p_grup = 'Süt İçen Buzağı' AND v_yas_gun > 180 THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', '6 aylıktan büyük hayvan "Süt İçen Buzağı" grubuna eklenemez');
    END IF;
    IF (p_grup = 'Süt İçen Buzağı' OR p_grup = 'Sütten Kesilmiş Buzağı') AND v_yas_gun > 365 THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', '12 aylıktan büyük hayvan buzağı grubuna eklenemez');
    END IF;
  END IF;

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
$function$;

-- ----------------------------------------------------------------------------
-- hayvan_guncelle — p_padok_id + p_kisir parametreli overload (en geniş)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.hayvan_guncelle(
  p_id text,
  p_kupe_no text DEFAULT NULL::text,
  p_devlet_kupe text DEFAULT NULL::text,
  p_irk text DEFAULT NULL::text,
  p_cinsiyet text DEFAULT NULL::text,
  p_dogum_tarihi date DEFAULT NULL::date,
  p_grup text DEFAULT NULL::text,
  p_padok text DEFAULT NULL::text,
  p_dogum_kg numeric DEFAULT NULL::numeric,
  p_canli_agirlik numeric DEFAULT NULL::numeric,
  p_boy numeric DEFAULT NULL::numeric,
  p_renk text DEFAULT NULL::text,
  p_ayirici_ozellik text DEFAULT NULL::text,
  p_baba_bilgi text DEFAULT NULL::text,
  p_notlar text DEFAULT NULL::text,
  p_anne_id text DEFAULT NULL::text,
  p_padok_id uuid DEFAULT NULL::uuid,
  p_kisir boolean DEFAULT NULL::boolean
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_padok_id uuid;
  v_padok_ad text;
  v_gebe     boolean;
  v_efektif_dt   date;
  v_efektif_grup text;
  v_yas_gun integer;
BEGIN
  -- Kısır işaretleme validation: gebe hayvan kısır olamaz
  IF p_kisir IS NOT NULL AND p_kisir = true THEN
    SELECT EXISTS (
      SELECT 1 FROM tohumlama t
      WHERE t.hayvan_id = p_id AND t.sonuc = 'Gebe'
    ) INTO v_gebe;
    IF v_gebe THEN
      RETURN jsonb_build_object('ok', false, 'error', 'Gebe hayvan kısır olarak işaretlenemez');
    END IF;
  END IF;

  -- H-11: Yaş/grup validasyonu (js/forms.js:66-77 birebir)
  -- p_dogum_tarihi VEYA p_grup güncelleniyorsa, EFEKTİF (yeni ya da mevcut
  -- satırdan gelen, COALESCE ile) değerler üzerinden kontrol et.
  -- Eğer ikisi de NULL geliyorsa (sadece diğer alanlar güncelleniyor), mevcut
  -- satırın değerleri kullanılır.
  IF p_dogum_tarihi IS NOT NULL OR p_grup IS NOT NULL THEN
    SELECT COALESCE(p_dogum_tarihi, h.dogum_tarihi),
           COALESCE(NULLIF(p_grup, ''), h.grup)
      INTO v_efektif_dt, v_efektif_grup
      FROM hayvanlar h
     WHERE h.id = p_id;

    IF v_efektif_dt IS NOT NULL THEN
      v_yas_gun := floor((current_date - v_efektif_dt));
      IF v_yas_gun < 0 THEN
        RETURN jsonb_build_object('ok', false, 'error', 'Doğum tarihi ileri tarih olamaz');
      END IF;
      IF v_efektif_grup = 'Süt İçen Buzağı' AND v_yas_gun > 180 THEN
        RETURN jsonb_build_object('ok', false, 'error', '6 aylıktan büyük hayvan "Süt İçen Buzağı" grubuna eklenemez');
      END IF;
      IF (v_efektif_grup = 'Süt İçen Buzağı' OR v_efektif_grup = 'Sütten Kesilmiş Buzağı') AND v_yas_gun > 365 THEN
        RETURN jsonb_build_object('ok', false, 'error', '12 aylıktan büyük hayvan buzağı grubuna eklenemez');
      END IF;
    END IF;
  END IF;

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
    anne_id          = COALESCE(NULLIF(p_anne_id,''),        anne_id),
    kisir            = COALESCE(p_kisir,                     kisir)
  WHERE id = p_id;

  RETURN jsonb_build_object('ok', true);
END;
$function$;
