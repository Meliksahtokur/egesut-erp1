-- drug_product_ekle RPC v2 — security hardening

CREATE UNIQUE INDEX IF NOT EXISTS idx_drug_products_brand_class
  ON drug_products (LOWER(brand_name), drug_class_id);

CREATE OR REPLACE FUNCTION drug_product_ekle(
  p_drug_class_id      UUID,
  p_brand_name         TEXT,
  p_concentration      NUMERIC DEFAULT NULL,
  p_concentration_unit TEXT    DEFAULT NULL,
  p_default_route      TEXT    DEFAULT 'IM',
  p_default_unit       TEXT    DEFAULT NULL,
  p_stok_id            UUID    DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  IF p_brand_name IS NULL OR trim(p_brand_name) = '' THEN
    RAISE EXCEPTION 'İlaç adı boş olamaz';
  END IF;

  BEGIN
    INSERT INTO drug_products (
      drug_class_id, brand_name, concentration,
      concentration_unit, default_route, default_unit
    ) VALUES (
      p_drug_class_id, p_brand_name, p_concentration,
      p_concentration_unit, p_default_route, p_default_unit
    )
    RETURNING id INTO v_id;
  EXCEPTION
    WHEN unique_violation THEN
      RAISE EXCEPTION 'Bu ilaç zaten kayıtlı: %', p_brand_name;
  END;

  IF p_stok_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM stok WHERE id = p_stok_id) THEN
      RAISE EXCEPTION 'Stok kaydı bulunamadı: %', p_stok_id;
    END IF;
    UPDATE stok SET drug_product_id = v_id WHERE id = p_stok_id;
  END IF;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = public, pg_temp;

GRANT EXECUTE ON FUNCTION public.drug_product_ekle(UUID, TEXT, NUMERIC, TEXT, TEXT, TEXT, UUID)
  TO authenticated;
