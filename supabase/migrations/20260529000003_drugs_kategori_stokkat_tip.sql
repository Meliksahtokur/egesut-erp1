-- drugs.kategori + stok_kategorileri.tip kolonu + RPC güncelleme
ALTER TABLE public.drugs ADD COLUMN IF NOT EXISTS kategori text;

UPDATE public.drugs SET kategori = 'Antibiyotik' WHERE name IN ('Makrovil','Enrolen','Florkem','Penicilin','Oksitetrasiklin');
UPDATE public.drugs SET kategori = 'NSAID' WHERE name IN ('Meloksikam','Flunixin');
UPDATE public.drugs SET kategori = 'Kortikosteroid' WHERE name = 'Deksametazon';
UPDATE public.drugs SET kategori = 'Metabolik' WHERE name = 'Kalsiyum Boroglukonat';
UPDATE public.drugs SET kategori = 'Vitamin' WHERE name IN ('B12 Vitamini','AD3E Vitamini');
UPDATE public.drugs SET kategori = 'Antiparaziter' WHERE name IN ('Albendazol','İvermektin');

ALTER TABLE public.stok_kategorileri ADD COLUMN IF NOT EXISTS tip text NOT NULL DEFAULT 'genel';
UPDATE public.stok_kategorileri SET tip = 'ilac' WHERE ad IN ('Antibiyotik','NSAID','Hormon','Vitamin','Antiparaziter','Diğer İlaç');

-- drug_ekle v2 (p_kategori eklendi)
DROP FUNCTION IF EXISTS public.drug_ekle(text, text, text, text);
CREATE OR REPLACE FUNCTION public.drug_ekle(
  p_name text, p_default_unit text DEFAULT NULL, p_default_route text DEFAULT NULL,
  p_stock_item_id text DEFAULT NULL, p_kategori text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_id uuid;
BEGIN
  IF p_name IS NULL OR trim(p_name) = '' THEN RETURN jsonb_build_object('ok',false,'mesaj','İlaç adı zorunlu'); END IF;
  IF EXISTS (SELECT 1 FROM drugs WHERE lower(name)=lower(trim(p_name))) THEN RETURN jsonb_build_object('ok',false,'mesaj','Bu isimde ilaç zaten var'); END IF;
  INSERT INTO drugs (name,default_unit,default_route,stock_item_id,kategori)
  VALUES (trim(p_name),p_default_unit,p_default_route,p_stock_item_id,p_kategori) RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok',true,'id',v_id);
END;$fn$;

-- drug_guncelle v2 (p_kategori eklendi)
DROP FUNCTION IF EXISTS public.drug_guncelle(uuid, text, text, text, text);
CREATE OR REPLACE FUNCTION public.drug_guncelle(
  p_id uuid, p_name text DEFAULT NULL, p_default_unit text DEFAULT NULL,
  p_default_route text DEFAULT NULL, p_stock_item_id text DEFAULT NULL, p_kategori text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $fn$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM drugs WHERE id=p_id) THEN RETURN jsonb_build_object('ok',false,'mesaj','İlaç bulunamadı'); END IF;
  IF p_name IS NOT NULL AND EXISTS (SELECT 1 FROM drugs WHERE lower(name)=lower(trim(p_name)) AND id<>p_id) THEN RETURN jsonb_build_object('ok',false,'mesaj','Bu isimde başka ilaç var'); END IF;
  UPDATE drugs SET name=COALESCE(NULLIF(trim(p_name),''),name), default_unit=p_default_unit,
    default_route=p_default_route, stock_item_id=p_stock_item_id, kategori=p_kategori WHERE id=p_id;
  RETURN jsonb_build_object('ok',true);
END;$fn$;

-- kategori_ekle v2 (p_tip eklendi)
DROP FUNCTION IF EXISTS public.kategori_ekle(text);
CREATE OR REPLACE FUNCTION public.kategori_ekle(
  p_ad text, p_tip text DEFAULT 'genel'
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $fn$
DECLARE v_id uuid; v_max int;
BEGIN
  IF p_ad IS NULL OR trim(p_ad)='' THEN RETURN jsonb_build_object('ok',false,'mesaj','Kategori adı zorunlu'); END IF;
  IF EXISTS (SELECT 1 FROM stok_kategorileri WHERE lower(ad)=lower(trim(p_ad))) THEN RETURN jsonb_build_object('ok',false,'mesaj','Bu kategori zaten var'); END IF;
  SELECT COALESCE(MAX(sira),0) INTO v_max FROM stok_kategorileri;
  INSERT INTO stok_kategorileri (ad,sira,tip) VALUES (trim(p_ad),v_max+1,p_tip) RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok',true,'id',v_id);
END;$fn$;

-- kategori_guncelle v2 (p_tip eklendi)
DROP FUNCTION IF EXISTS public.kategori_guncelle(uuid, text);
CREATE OR REPLACE FUNCTION public.kategori_guncelle(
  p_id uuid, p_new_ad text DEFAULT NULL, p_tip text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $fn$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM stok_kategorileri WHERE id=p_id) THEN RETURN jsonb_build_object('ok',false,'mesaj','Kategori bulunamadı'); END IF;
  IF p_new_ad IS NOT NULL AND EXISTS (SELECT 1 FROM stok_kategorileri WHERE lower(ad)=lower(trim(p_new_ad)) AND id<>p_id) THEN RETURN jsonb_build_object('ok',false,'mesaj','Bu isimde kategori var'); END IF;
  UPDATE stok_kategorileri SET ad=COALESCE(NULLIF(trim(p_new_ad),''),ad), tip=COALESCE(p_tip,tip) WHERE id=p_id;
  RETURN jsonb_build_object('ok',true);
END;$fn$;

GRANT EXECUTE ON FUNCTION public.drug_ekle TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drug_guncelle TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kategori_ekle TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kategori_guncelle TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
