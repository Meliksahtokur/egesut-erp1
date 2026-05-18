-- Migration: Kuru Dönem Geçiş Bug Fix
-- Fix 1: gorev_tamamla RPC'ye grup güncelleme ekle
-- Fix 2: laktasyon_kuru_kontrol dedup düzelt
-- Fix 3: Mevcut veri düzeltmesi
-- Tarih: 2026-05-18

BEGIN;

-- ── Fix 1: gorev_tamamla — Kuru dönem geçişinde grup güncelle ──
CREATE OR REPLACE FUNCTION public.gorev_tamamla(
  p_gorev_id text,
  p_padok_hedef text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev record;
  v_hayvan record;
  v_snapshot jsonb;
  v_stok_dusuldu boolean := false;
  v_padok_guncellendi boolean := false;
  v_olusturulan jsonb := '[]'::jsonb;
  v_guncellenen jsonb := '[]'::jsonb;
BEGIN
  SELECT * INTO v_gorev FROM public.gorev_log WHERE id = p_gorev_id::uuid;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Görev bulunamadı: %', p_gorev_id;
  END IF;
  IF v_gorev.tamamlandi THEN
    RETURN jsonb_build_object('ok', true, 'mesaj', 'Görev zaten tamamlanmış');
  END IF;
  -- H2: İptal edilmiş görev tamamlanamaz
  IF v_gorev.iptal THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev iptal edilmiş, tamamlanamaz');
  END IF;

  -- a) Görevi tamamla
  v_guncellenen := v_guncellenen || jsonb_build_object(
    'tablo', 'gorev_log', 'id', p_gorev_id,
    'onceki', jsonb_build_object('tamamlandi', v_gorev.tamamlandi, 'tamamlanma_tarihi', v_gorev.tamamlanma_tarihi),
    'sonraki', jsonb_build_object('tamamlandi', true, 'tamamlanma_tarihi', now())
  );

  UPDATE public.gorev_log SET
    tamamlandi = true,
    tamamlanma_tarihi = now()
  WHERE id = p_gorev_id::uuid;

  -- b) Stok düşümü (görevde stok_id + miktar varsa)
  IF v_gorev.stok_id IS NOT NULL AND v_gorev.miktar IS NOT NULL AND v_gorev.miktar > 0 THEN
    v_stok_dusuldu := true;
    v_olusturulan := v_olusturulan || jsonb_build_object(
      'tablo', 'stok_hareket',
      'id', gen_random_uuid()::text,
      'veri', jsonb_build_object(
        'stok_id', v_gorev.stok_id,
        'tur', 'Görev',
        'miktar', v_gorev.miktar,
        'notlar', 'GorevID:' || p_gorev_id,
        'iptal', false
      )
    );

    INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
    VALUES (gen_random_uuid(), v_gorev.stok_id, 'Görev', v_gorev.miktar,
      'GorevID:' || p_gorev_id, false);
  END IF;

  -- c) Padok değişikliği
  IF p_padok_hedef IS NOT NULL AND v_gorev.hayvan_id IS NOT NULL THEN
    SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = v_gorev.hayvan_id;
    IF FOUND THEN
      v_padok_guncellendi := true;
      v_guncellenen := v_guncellenen || jsonb_build_object(
        'tablo', 'hayvanlar', 'id', v_gorev.hayvan_id,
        'onceki', jsonb_build_object('padok', v_hayvan.padok),
        'sonraki', jsonb_build_object('padok', p_padok_hedef)
      );

      UPDATE public.hayvanlar SET padok = p_padok_hedef WHERE id = v_gorev.hayvan_id;

      -- YENİ: Kuru dönem geçişinde grup da güncelle
      IF v_gorev.gorev_tipi = 'PADOK_DEGISIM' AND v_gorev.aciklama ILIKE '%Kuru döneme%' THEN
        UPDATE public.hayvanlar SET grup = 'Sağmal (Kuru Dönem)' WHERE id = v_gorev.hayvan_id;
      END IF;
    END IF;
  END IF;

  v_snapshot := jsonb_build_object(
    'olusturulan', v_olusturulan,
    'guncellenen', v_guncellenen,
    'silinen', '[]'::jsonb
  );

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('GOREV_TAMAMLA', v_gorev.hayvan_id, p_gorev_id, 'gorev_log', v_snapshot,
    format('Görev tamamlandı (stok: %s, padok: %s)',
      CASE WHEN v_stok_dusuldu THEN 'evet' ELSE 'hayır' END,
      CASE WHEN v_padok_guncellendi THEN 'evet' ELSE 'hayır' END));

  RETURN jsonb_build_object(
    'ok', true,
    'gorev_id', p_gorev_id,
    'stok_dusuldu', v_stok_dusuldu,
    'padok_guncellendi', v_padok_guncellendi
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.gorev_tamamla(text, text) TO anon, authenticated;

-- ── Fix 2: laktasyon_kuru_kontrol — dedup düzelt ──
CREATE OR REPLACE FUNCTION public.laktasyon_kuru_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_rec         record;
  v_id          uuid;
BEGIN
  FOR v_rec IN
    SELECT h.id, h.kupe_no, h.grup, h.padok
    FROM hayvanlar h
    WHERE h.durum = 'Aktif'
      AND h.grup ILIKE '%Sağmal%'
      AND h.grup NOT ILIKE '%Kuru%'
      AND NOT EXISTS (
        SELECT 1 FROM tohumlama t
        WHERE t.hayvan_id = h.id AND t.sonuc = 'Gebe'
      )
  LOOP
    v_id := gen_random_uuid();
    INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, padok_hedef)
    SELECT v_id, v_rec.id, 'PADOK_DEGISIM',
           '⚠️ Kuru döneme geçiş zamanı — Kuru/Gebe padoğuna transfer',
           CURRENT_DATE, false,
           (SELECT ad FROM padoklar WHERE ad ILIKE '%Kuru%' LIMIT 1)
    WHERE NOT EXISTS (
      SELECT 1 FROM gorev_log
      WHERE hayvan_id = v_rec.id
        AND gorev_tipi = 'PADOK_DEGISIM'
        AND aciklama ILIKE '%Kuru döneme%'
        AND (NOT tamamlandi OR tamamlanma_tarihi > now() - interval '24 hours')
    );
    GET DIAGNOSTICS v_sayac = ROW_COUNT;
    v_olusturulan := v_olusturulan + v_sayac;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;

GRANT EXECUTE ON FUNCTION public.laktasyon_kuru_kontrol() TO anon, authenticated;

-- ── Fix 3: Mevcut veri düzeltmesi ──

-- 1. Padok zaten Kuru/Gebe olan ama grup güncellenmemiş hayvanları düzelt
UPDATE public.hayvanlar
SET grup = 'Sağmal (Kuru Dönem)'
WHERE padok = 'Kuru/Gebe Padok'
  AND grup ILIKE '%Sağmal%'
  AND grup NOT ILIKE '%Kuru%'
  AND durum = 'Aktif';

-- 2. Bu hayvanların duplicate açık kuru dönem görevlerini iptal et
UPDATE public.gorev_log
SET iptal = true
WHERE gorev_tipi = 'PADOK_DEGISIM'
  AND aciklama ILIKE '%Kuru döneme%'
  AND tamamlandi = false
  AND hayvan_id IN (
    SELECT id FROM public.hayvanlar
    WHERE grup = 'Sağmal (Kuru Dönem)'
  );

COMMIT;
