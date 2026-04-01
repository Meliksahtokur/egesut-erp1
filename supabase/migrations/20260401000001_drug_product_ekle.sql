-- drug_product_ekle RPC
-- Yeni ilaç ürünü ekler, duplikat kontrolü yapar

CREATE OR REPLACE FUNCTION drug_product_ekle(
  p_drug_class_id UUID,
  p_brand_name TEXT,
  p_concentration NUMERIC DEFAULT NULL,
  p_concentration_unit TEXT DEFAULT NULL,
  p_default_route TEXT DEFAULT 'IM',
  p_default_unit TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
  v_existing_id UUID;
BEGIN
  -- Duplikat kontrolü: aynı brand_name + drug_class_id kombinasyonu
  SELECT id INTO v_existing_id
  FROM drug_products
  WHERE LOWER(brand_name) = LOWER(p_brand_name)
    AND drug_class_id = p_drug_class_id;
  
  IF v_existing_id IS NOT NULL THEN
    RAISE EXCEPTION 'Duplikat: "%" etken madde ile zaten kayıtlı', p_brand_name;
  END IF;
  
  -- Yeni kayıt ekle
  INSERT INTO drug_products (
    drug_class_id,
    brand_name,
    concentration,
    concentration_unit,
    default_route,
    default_unit
  ) VALUES (
    p_drug_class_id,
    p_brand_name,
    p_concentration,
    p_concentration_unit,
    p_default_route,
    p_default_unit
  )
  RETURNING id INTO v_id;
  
  RETURN v_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION drug_product_ekle IS 'Yeni ilaç ürünü ekler, duplikat kontrolü yapar';
