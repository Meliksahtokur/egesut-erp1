-- ─────────────────────────────────────────────────────────────
-- ilac_ekle: atomik ilaç ekleme (stok + drug_product tek transaction)
--
-- TASARIM KURALI: Yeni bir ilaç KATALOGLANMADAN (drug_class /
--   etken madde olmadan) eklenemez. Önceki akış (forms.js
--   submitStokAdd) stok'u önce oluşturup etken madde
--   doğrulamasını SONRA yapıyordu → etken seçilmezse veya
--   offline ise stok katalogsuz "orphan" kalıyordu.
--
-- ÇÖZÜM: Tek RPC içinde önce zorunlu alanlar doğrulanır, sonra
--   stok + drug_product atomik olarak yazılır. drug_product
--   insert'i başarısız olursa (unique_violation) stok da rollback
--   olur — orphan imkânsız.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ilac_ekle(
  p_urun_adi text,
  p_kategori text,
  p_birim text,
  p_baslangic_miktar numeric,
  p_esik numeric DEFAULT 0,
  p_drug_class_id uuid DEFAULT NULL,
  p_concentration numeric DEFAULT NULL,
  p_concentration_unit text DEFAULT NULL,
  p_default_route text DEFAULT 'IM'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_stok_id text;
  v_dp_id   uuid;
BEGIN
  -- Katalog ZORUNLU: ilaç etken madde olmadan eklenemez (tasarım kuralı)
  IF p_drug_class_id IS NULL THEN
    RAISE EXCEPTION 'Etken madde (drug_class) zorunlu — ilaç kataloglanmadan eklenemez';
  END IF;
  IF p_urun_adi IS NULL OR trim(p_urun_adi) = '' THEN
    RAISE EXCEPTION 'İlaç adı boş olamaz';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.stok_kategorileri WHERE ad = p_kategori) THEN
    RAISE EXCEPTION 'Geçersiz kategori: %', p_kategori;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.drug_classes WHERE id = p_drug_class_id) THEN
    RAISE EXCEPTION 'Geçersiz etken madde: %', p_drug_class_id;
  END IF;

  v_stok_id := gen_random_uuid()::text;

  INSERT INTO public.stok (id, urun_adi, kategori, birim, baslangic_miktar, esik)
  VALUES (v_stok_id, p_urun_adi, p_kategori, p_birim, p_baslangic_miktar, p_esik);

  BEGIN
    INSERT INTO public.drug_products (
      drug_class_id, brand_name, concentration,
      concentration_unit, default_route, default_unit
    ) VALUES (
      p_drug_class_id, p_urun_adi, p_concentration,
      p_concentration_unit, p_default_route, p_birim
    )
    RETURNING id INTO v_dp_id;
  EXCEPTION
    WHEN unique_violation THEN
      RAISE EXCEPTION 'Bu ilaç zaten kayıtlı: %', p_urun_adi;
  END;

  UPDATE public.stok SET drug_product_id = v_dp_id WHERE id = v_stok_id;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('STOK_EKLE', v_stok_id, 'stok', jsonb_build_object(
    'olusturulan', jsonb_build_array(
      jsonb_build_object('tablo','stok','id',v_stok_id,'veri',jsonb_build_object(
        'urun_adi',p_urun_adi,'kategori',p_kategori,'birim',p_birim,
        'baslangic_miktar',p_baslangic_miktar,'esik',p_esik,'drug_product_id',v_dp_id)),
      jsonb_build_object('tablo','drug_products','id',v_dp_id,'veri',jsonb_build_object(
        'brand_name',p_urun_adi,'drug_class_id',p_drug_class_id))
    ),
    'guncellenen','[]'::jsonb,
    'silinen','[]'::jsonb
  ), 'Yeni ilaç (kataloglu): ' || p_urun_adi);

  RETURN jsonb_build_object('ok', true, 'stok_id', v_stok_id, 'drug_product_id', v_dp_id);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.ilac_ekle(text,text,text,numeric,numeric,uuid,numeric,text,text) TO anon, authenticated;
