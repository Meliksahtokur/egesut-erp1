-- Migration: Kuru Dönem Padok_id Fix
-- gorev_tamamla RPC'de padok_id güncellemesi + mevcut veri düzeltmesi
-- Tarih: 2026-05-31

BEGIN;

-- ═══════════════════════════════════════════════════════════
-- Fix 1: gorev_tamamla — padok_id de güncelle
-- ═══════════════════════════════════════════════════════════
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
  v_yeni_padok_id uuid;
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

  -- c) Padok değişikliği — text + FK birlikte güncelle
  IF p_padok_hedef IS NOT NULL AND v_gorev.hayvan_id IS NOT NULL THEN
    SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = v_gorev.hayvan_id;
    IF FOUND THEN
      -- Padok adından UUID çöz
      SELECT id INTO v_yeni_padok_id FROM public.padoklar WHERE ad = p_padok_hedef LIMIT 1;

      v_padok_guncellendi := true;
      v_guncellenen := v_guncellenen || jsonb_build_object(
        'tablo', 'hayvanlar', 'id', v_gorev.hayvan_id,
        'onceki', jsonb_build_object('padok', v_hayvan.padok, 'padok_id', v_hayvan.padok_id),
        'sonraki', jsonb_build_object('padok', p_padok_hedef, 'padok_id', v_yeni_padok_id)
      );

      UPDATE public.hayvanlar
      SET padok = p_padok_hedef,
          padok_id = v_yeni_padok_id
      WHERE id = v_gorev.hayvan_id;

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

-- ═══════════════════════════════════════════════════════════
-- Fix 2: Mevcut veri düzeltmesi
-- Grup "Sağmal (Kuru Dönem)" olup padok_id'si Kuru/Gebe Padok'a
-- işaret etmeyen hayvanları düzelt
-- ═══════════════════════════════════════════════════════════
UPDATE public.hayvanlar h
SET padok_id = kuru.id,
    padok = kuru.ad
FROM (SELECT id, ad FROM public.padoklar WHERE ad ILIKE '%Kuru%' LIMIT 1) kuru
WHERE h.grup = 'Sağmal (Kuru Dönem)'
  AND (h.padok_id IS DISTINCT FROM kuru.id OR h.padok_id IS NULL);

COMMIT;
