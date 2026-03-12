-- ══════════════════════════════════════════════════════════════
-- MIGRATION 021 — TEDAVİ GÜNCELLEME + STOK LEDGER DÜZELTMESİ
-- EgeSüt ERP — 2026-03-12
--
-- Değişiklikler:
-- 1. stok_hareket tablosuna referans_tipi + referans_id kolonları (audit trail)
-- 2. tedavi_ekle — stok_hareket'e referans bilgisi eklendi
-- 3. tedavi_sil — iptal=true yerine +miktar yeni hareket INSERT (ledger)
-- 4. tedavi_guncelle — fark hareketi INSERT eder, tedavi UPDATE eder
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- 1. STOK_HAREKET — AUDIT KOLONLARI
-- ──────────────────────────────────────────────────────────────
ALTER TABLE public.stok_hareket
  ADD COLUMN IF NOT EXISTS referans_tipi text,   -- 'tedavi' | 'stok_girisi' | 'duzeltme' vb.
  ADD COLUMN IF NOT EXISTS referans_id   text;   -- ilgili kaydın id'si

COMMENT ON COLUMN public.stok_hareket.referans_tipi IS 'tedavi | stok_girisi | duzeltme | iade';
COMMENT ON COLUMN public.stok_hareket.referans_id   IS 'İlgili kaydın id değeri (tedavi.id vb.)';

-- ──────────────────────────────────────────────────────────────
-- 2. TEDAVİ_EKLE — referans bilgisi eklendi
-- ──────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.tedavi_ekle(text,text,text,numeric,text,integer,text,text);

CREATE OR REPLACE FUNCTION public.tedavi_ekle(
  p_vaka_id         text,
  p_hayvan_id       text,
  p_ilac_stok_id    text,
  p_miktar          numeric,
  p_uygulama_yolu   text    DEFAULT NULL,
  p_bekleme_gun     integer DEFAULT NULL,
  p_hekim_id        text    DEFAULT NULL,
  p_notlar          text    DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok      record;
  v_hayvan    record;
  v_bugun     date := CURRENT_DATE;
  v_tani      text;
  v_tedavi_id uuid := gen_random_uuid();
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = p_ilac_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok kalemi bulunamadı');
  END IF;

  IF v_stok.miktar < p_miktar THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Yetersiz stok: ' || COALESCE(v_stok.urun_adi,'?'));
  END IF;

  SELECT tani INTO v_tani FROM public.hastalik_log WHERE id::text = p_vaka_id;

  INSERT INTO public.tedavi (
    id, hayvan_id, vaka_id, tarih, tani,
    ilac_stok_id, miktar, uygulama_yolu,
    hekim_id, bekleme_suresi_gun,
    sut_yasagi_bitis, aktif, notlar
  ) VALUES (
    v_tedavi_id, p_hayvan_id, p_vaka_id, v_bugun, v_tani,
    p_ilac_stok_id, p_miktar, p_uygulama_yolu,
    p_hekim_id, p_bekleme_gun,
    CASE WHEN p_bekleme_gun > 0 THEN v_bugun + p_bekleme_gun ELSE NULL END,
    true, p_notlar
  );

  -- Stok hareketi — ledger kaydı (negatif = kullanım)
  INSERT INTO public.stok_hareket (
    id, stok_id, tur, miktar, notlar, iptal, referans_tipi, referans_id
  ) VALUES (
    gen_random_uuid()::text,
    p_ilac_stok_id,
    'Tedavi',
    -p_miktar,
    COALESCE(v_tani, 'Tedavi') || ' — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
    false,
    'tedavi',
    v_tedavi_id::text
  );

  -- Stok miktarını güncelle
  UPDATE public.stok SET miktar = miktar - p_miktar WHERE id = p_ilac_stok_id;

  RETURN jsonb_build_object('ok', true, 'tedavi_id', v_tedavi_id);
END;
$$;

ALTER FUNCTION public.tedavi_ekle SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────────
-- 3. TEDAVİ_SİL — ledger: +miktar yeni hareket, DELETE tedavi
-- ──────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.tedavi_sil(text);

CREATE OR REPLACE FUNCTION public.tedavi_sil(
  p_tedavi_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tedavi  record;
  v_stok    record;
BEGIN
  SELECT * INTO v_tedavi FROM public.tedavi WHERE id::text = p_tedavi_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tedavi kaydı bulunamadı');
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = v_tedavi.ilac_stok_id;

  -- Ledger: stok iadesi — yeni pozitif hareket ekle
  INSERT INTO public.stok_hareket (
    id, stok_id, tur, miktar, notlar, iptal, referans_tipi, referans_id
  ) VALUES (
    gen_random_uuid()::text,
    v_tedavi.ilac_stok_id,
    'Tedavi İptal',
    v_tedavi.miktar,   -- pozitif = iade
    'Tedavi silindi — ' || COALESCE(v_tedavi.tani, '?'),
    false,
    'tedavi_iptal',
    p_tedavi_id
  );

  -- Stok miktarını geri ekle
  UPDATE public.stok SET miktar = miktar + v_tedavi.miktar WHERE id = v_tedavi.ilac_stok_id;

  -- Tedavi kaydını sil
  DELETE FROM public.tedavi WHERE id::text = p_tedavi_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

ALTER FUNCTION public.tedavi_sil SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────────
-- 4. TEDAVİ_GUNCELLE — fark hareketi + UPDATE
-- ──────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.tedavi_guncelle(text,numeric,text,integer,text,text);

CREATE OR REPLACE FUNCTION public.tedavi_guncelle(
  p_tedavi_id       text,
  p_miktar          numeric  DEFAULT NULL,
  p_uygulama_yolu   text     DEFAULT NULL,
  p_bekleme_gun     integer  DEFAULT NULL,
  p_hekim_id        text     DEFAULT NULL,
  p_notlar          text     DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tedavi  record;
  v_stok    record;
  v_fark    numeric;
  v_yeni_miktar numeric;
BEGIN
  SELECT * INTO v_tedavi FROM public.tedavi WHERE id::text = p_tedavi_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tedavi kaydı bulunamadı');
  END IF;

  v_yeni_miktar := COALESCE(p_miktar, v_tedavi.miktar);
  v_fark := v_tedavi.miktar - v_yeni_miktar;  -- pozitif = stok geri döner, negatif = daha fazla kullanım

  IF v_fark <> 0 THEN
    SELECT * INTO v_stok FROM public.stok WHERE id = v_tedavi.ilac_stok_id;

    -- Yetersiz stok kontrolü (daha fazla kullanılacaksa)
    IF v_fark < 0 AND v_stok.miktar < ABS(v_fark) THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Yetersiz stok: ' || COALESCE(v_stok.urun_adi,'?'));
    END IF;

    -- Ledger: fark hareketi
    INSERT INTO public.stok_hareket (
      id, stok_id, tur, miktar, notlar, iptal, referans_tipi, referans_id
    ) VALUES (
      gen_random_uuid()::text,
      v_tedavi.ilac_stok_id,
      'Tedavi Düzeltme',
      v_fark,   -- pozitif = iade, negatif = ek kullanım
      'Tedavi güncellendi — ' || COALESCE(v_tedavi.tani, '?'),
      false,
      'tedavi_duzeltme',
      p_tedavi_id
    );

    -- Stok miktarını güncelle
    UPDATE public.stok SET miktar = miktar + v_fark WHERE id = v_tedavi.ilac_stok_id;
  END IF;

  -- Tedavi kaydını güncelle
  UPDATE public.tedavi SET
    miktar             = v_yeni_miktar,
    uygulama_yolu      = COALESCE(p_uygulama_yolu,  uygulama_yolu),
    bekleme_suresi_gun = COALESCE(p_bekleme_gun,     bekleme_suresi_gun),
    sut_yasagi_bitis   = CASE
                           WHEN p_bekleme_gun IS NOT NULL AND p_bekleme_gun > 0
                           THEN tarih + p_bekleme_gun
                           ELSE sut_yasagi_bitis
                         END,
    hekim_id           = COALESCE(p_hekim_id,        hekim_id),
    notlar             = COALESCE(p_notlar,           notlar)
  WHERE id::text = p_tedavi_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

ALTER FUNCTION public.tedavi_guncelle SECURITY DEFINER;

-- RLS
GRANT EXECUTE ON FUNCTION public.tedavi_ekle    TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tedavi_sil     TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tedavi_guncelle TO anon, authenticated;
