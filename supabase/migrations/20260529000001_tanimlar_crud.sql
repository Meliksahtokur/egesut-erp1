-- ══════════════════════════════════════════════════════════════
-- MIGRATION: Tanımlar Paneli — CRUD RPC'ler + stok_kategorileri
-- ══════════════════════════════════════════════════════════════

-- 1. STOK_KATEGORİLERİ TABLOSU
CREATE TABLE IF NOT EXISTS public.stok_kategorileri (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ad         text UNIQUE NOT NULL,
  sira       integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

COMMENT ON TABLE public.stok_kategorileri IS 'Stok kategori tanımları — Tanımlar panelinden yönetilir';

-- RLS
ALTER TABLE public.stok_kategorileri ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='stok_kategorileri' AND policyname='stok_kat_select') THEN
    CREATE POLICY stok_kat_select ON public.stok_kategorileri FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='stok_kategorileri' AND policyname='stok_kat_all') THEN
    CREATE POLICY stok_kat_all ON public.stok_kategorileri FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;

-- Seed — standart kategoriler
INSERT INTO public.stok_kategorileri (ad, sira) VALUES
  ('Antibiyotik', 1),
  ('NSAID', 2),
  ('Hormon', 3),
  ('Vitamin', 4),
  ('Antiparaziter', 5),
  ('Diğer İlaç', 6),
  ('Aşı', 7),
  ('Sperma', 8),
  ('Yem', 9),
  ('Sarf', 10),
  ('Ekipman', 11),
  ('Diğer', 12)
ON CONFLICT (ad) DO NOTHING;

-- 2. DISEASE RPC'LER
CREATE OR REPLACE FUNCTION public.disease_ekle(
  p_name     text,
  p_category text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM diseases WHERE LOWER(name) = LOWER(p_name)) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu hastalık zaten var');
  END IF;
  INSERT INTO diseases (name, category) VALUES (p_name, p_category) RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.disease_guncelle(
  p_id       uuid,
  p_name     text,
  p_category text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM diseases WHERE LOWER(name) = LOWER(p_name) AND id != p_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu isimde başka bir hastalık var');
  END IF;
  UPDATE diseases SET name = p_name, category = p_category WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hastalık bulunamadı');
  END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.disease_sil(
  p_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_aktif integer;
  v_kapali integer;
BEGIN
  SELECT
    COUNT(*) FILTER (WHERE status = 'active'),
    COUNT(*) FILTER (WHERE status = 'closed')
  INTO v_aktif, v_kapali
  FROM cases WHERE disease_id = p_id;

  IF v_aktif > 0 OR v_kapali > 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      format('Bu hastalığa ait %s vaka var (%s aktif, %s kapalı), silinemez', v_aktif + v_kapali, v_aktif, v_kapali));
  END IF;
  DELETE FROM diseases WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

-- 3. DRUG RPC'LER
CREATE OR REPLACE FUNCTION public.drug_ekle(
  p_name          text,
  p_default_unit  text DEFAULT NULL,
  p_default_route text DEFAULT NULL,
  p_stock_item_id text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM drugs WHERE LOWER(name) = LOWER(p_name)) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu ilaç zaten var');
  END IF;
  INSERT INTO drugs (name, default_unit, default_route, stock_item_id)
  VALUES (p_name, p_default_unit, p_default_route, p_stock_item_id)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.drug_guncelle(
  p_id             uuid,
  p_name           text,
  p_default_unit   text DEFAULT NULL,
  p_default_route  text DEFAULT NULL,
  p_stock_item_id  text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM drugs WHERE LOWER(name) = LOWER(p_name) AND id != p_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu isimde başka bir ilaç var');
  END IF;
  UPDATE drugs SET name = p_name, default_unit = p_default_unit,
    default_route = p_default_route, stock_item_id = p_stock_item_id
  WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'İlaç bulunamadı');
  END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.drug_sil(
  p_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok_id text;
  v_count   integer;
BEGIN
  SELECT stock_item_id INTO v_stok_id FROM drugs WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'İlaç bulunamadı');
  END IF;
  IF v_stok_id IS NOT NULL THEN
    SELECT COUNT(*) INTO v_count FROM drug_administrations WHERE stok_id = v_stok_id;
    IF v_count > 0 THEN
      RETURN jsonb_build_object('ok', false, 'mesaj',
        format('Bu ilaç %s tedavi uygulamasında kullanılmış, silinemez', v_count));
    END IF;
  END IF;
  DELETE FROM drugs WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

-- 4. KATEGORİ RPC'LER
CREATE OR REPLACE FUNCTION public.kategori_ekle(
  p_ad text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM stok_kategorileri WHERE LOWER(ad) = LOWER(p_ad)) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu kategori zaten var');
  END IF;
  INSERT INTO stok_kategorileri (ad, sira)
  VALUES (p_ad, COALESCE((SELECT MAX(sira) FROM stok_kategorileri), 0) + 1)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.kategori_guncelle(
  p_id     uuid,
  p_new_ad text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_old_ad text;
BEGIN
  IF EXISTS (SELECT 1 FROM stok_kategorileri WHERE LOWER(ad) = LOWER(p_new_ad) AND id != p_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu isimde başka bir kategori var');
  END IF;
  SELECT ad INTO v_old_ad FROM stok_kategorileri WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kategori bulunamadı');
  END IF;
  UPDATE stok SET kategori = p_new_ad WHERE kategori = v_old_ad;
  UPDATE stok_kategorileri SET ad = p_new_ad WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.kategori_sil(
  p_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_ad    text;
  v_count integer;
BEGIN
  SELECT ad INTO v_ad FROM stok_kategorileri WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kategori bulunamadı');
  END IF;
  SELECT COUNT(*) INTO v_count FROM stok WHERE kategori = v_ad;
  IF v_count > 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      format('Bu kategoride %s ürün var, silinemez', v_count));
  END IF;
  DELETE FROM stok_kategorileri WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

-- 5. SEED_DEFAULTS — varsayılana dön
CREATE OR REPLACE FUNCTION public.seed_defaults(
  p_tip text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_count integer := 0;
BEGIN
  IF p_tip = 'diseases' THEN
    WITH ins AS (
      INSERT INTO diseases (name, category) VALUES
        ('Mastitis', 'Meme'),
        ('Laminitis', 'Ayak'),
        ('Metritis', 'Üreme'),
        ('Retensio', 'Üreme'),
        ('Ketozis', 'Metabolik'),
        ('Hipokalsemi', 'Metabolik'),
        ('Pnömoni', 'Solunum'),
        ('İshal', 'Sindirim'),
        ('Neonatal Zayıflık', 'Buzağı'),
        ('Göbek İltihabı', 'Buzağı')
      ON CONFLICT (name) DO NOTHING
      RETURNING 1
    ) SELECT COUNT(*) INTO v_count FROM ins;

  ELSIF p_tip = 'drugs' THEN
    WITH ins AS (
      INSERT INTO drugs (name, default_unit, default_route) VALUES
        ('Makrovil', 'ml', 'IM'),
        ('Enrolen', 'ml', 'IM'),
        ('Florkem', 'ml', 'IM'),
        ('Penicilin', 'ml', 'IM'),
        ('Oksitetrasiklin', 'ml', 'IM'),
        ('Meloksikam', 'ml', 'IV'),
        ('Flunixin', 'ml', 'IV'),
        ('Deksametazon', 'ml', 'IM'),
        ('Kalsiyum Boroglukonat', 'ml', 'IV'),
        ('B12 Vitamini', 'ml', 'IM'),
        ('AD3E Vitamini', 'ml', 'IM'),
        ('Albendazol', 'ml', 'PO'),
        ('İvermektin', 'ml', 'SC')
      ON CONFLICT (name) DO NOTHING
      RETURNING 1
    ) SELECT COUNT(*) INTO v_count FROM ins;

  ELSIF p_tip = 'kategoriler' THEN
    WITH ins AS (
      INSERT INTO stok_kategorileri (ad, sira) VALUES
        ('Antibiyotik', 1), ('NSAID', 2), ('Hormon', 3), ('Vitamin', 4),
        ('Antiparaziter', 5), ('Diğer İlaç', 6), ('Aşı', 7), ('Sperma', 8),
        ('Yem', 9), ('Sarf', 10), ('Ekipman', 11), ('Diğer', 12)
      ON CONFLICT (ad) DO NOTHING
      RETURNING 1
    ) SELECT COUNT(*) INTO v_count FROM ins;

  ELSE
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçersiz tip: diseases | drugs | kategoriler');
  END IF;

  RETURN jsonb_build_object('ok', true, 'eklenen', v_count);
END;
$$;

-- 6. GRANT
GRANT SELECT, INSERT, UPDATE, DELETE ON public.stok_kategorileri TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.disease_ekle(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.disease_guncelle(uuid, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.disease_sil(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drug_ekle(text, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drug_guncelle(uuid, text, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drug_sil(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kategori_ekle(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kategori_guncelle(uuid, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kategori_sil(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.seed_defaults(text) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
