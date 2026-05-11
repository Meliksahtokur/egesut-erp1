-- Migration: hekimler tablosu oluştur (production'da yoktu) + hekim_sil + sperma_sil RPCs
BEGIN;

-- hekimler tablosu (lokal migration 009 DB'ye uygulanmamıştı)
CREATE TABLE IF NOT EXISTS public.hekimler (
  id      text PRIMARY KEY,
  ad      text NOT NULL,
  telefon text,
  aktif   boolean NOT NULL DEFAULT true
);

INSERT INTO public.hekimler (id, ad, aktif) VALUES
  ('H1', 'Melik Tokur',        true),
  ('H2', 'Hüseyin Aygün',      true),
  ('H3', 'Süleyman Kocabaş',   true)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.hekimler ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "hekimler_all" ON public.hekimler;
CREATE POLICY "hekimler_all" ON public.hekimler FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON public.hekimler TO anon, authenticated;

-- hekim_sil: constraint check then delete
CREATE OR REPLACE FUNCTION public.hekim_sil(p_hekim_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM hekimler WHERE id = p_hekim_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hekim bulunamadi');
  END IF;
  IF EXISTS (SELECT 1 FROM tohumlama WHERE hekim_id = p_hekim_id LIMIT 1) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tohumlama kaydi olan hekim silinemez');
  END IF;
  IF EXISTS (SELECT 1 FROM dogum WHERE hekim_id = p_hekim_id LIMIT 1) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Dogum kaydi olan hekim silinemez');
  END IF;
  DELETE FROM hekimler WHERE id = p_hekim_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.hekim_sil(text) TO anon, authenticated;

-- sperma_sil: check tohumlama references then delete from stok
CREATE OR REPLACE FUNCTION public.sperma_sil(p_stok_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_urun_adi text;
BEGIN
  SELECT urun_adi INTO v_urun_adi FROM stok WHERE id = p_stok_id AND kategori = 'Sperma';
  IF v_urun_adi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Sperma stok kaydi bulunamadi');
  END IF;
  IF EXISTS (SELECT 1 FROM tohumlama WHERE sperma = v_urun_adi LIMIT 1) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tohumlama kaydinda kullanilan sperma silinemez');
  END IF;
  DELETE FROM stok_hareket WHERE stok_id = p_stok_id;
  DELETE FROM stok WHERE id = p_stok_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.sperma_sil(text) TO anon, authenticated;

END;
