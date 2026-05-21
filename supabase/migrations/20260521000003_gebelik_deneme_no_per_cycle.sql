-- Migration: Tohumlama deneme_no per-cycle sıfırlama + 260-gün auto-close
-- Etkiler: set_deneme_no() trigger, tohumlama_kaydet() RPC
-- Tablolar: tohumlama, islem_log
-- Geri alınabilir: evet — DROP IF EXISTS ile mevcut imza korunur

BEGIN;

-- ═══════════════════════════════════════════════════════════════
-- DEĞİŞİKLİK 1: set_deneme_no() trigger — per-cycle
-- ═══════════════════════════════════════════════════════════════
-- ESKİ: SELECT COALESCE(MAX(deneme_no), 0) + 1 (tüm zamanlar)
-- YENİ: Son 'Doğum Yaptı' veya 'Abort' sonrası tohumlama sayısı + 1
--        (per-cycle: her doğum/abortta deneme_no sıfırlanır)

CREATE OR REPLACE FUNCTION public.set_deneme_no()
RETURNS TRIGGER AS $$
BEGIN
  SELECT COALESCE(COUNT(*), 0) + 1 INTO NEW.deneme_no
  FROM public.tohumlama
  WHERE hayvan_id = NEW.hayvan_id
    AND tarih > COALESCE(
      (SELECT MAX(tarih) FROM public.tohumlama
       WHERE hayvan_id = NEW.hayvan_id AND sonuc IN ('Doğum Yaptı', 'Abort')),
      '1900-01-01'::date
    );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger aynı isimde kalır, sadece fonksiyon değişir
-- DROP/CREATE TRIGGER gerekmez — OR REPLACE FUNCTION yeterli

-- ═══════════════════════════════════════════════════════════════
-- DEĞİŞİKLİK 2: tohumlama_kaydet RPC — per-cycle + 260g auto-close
-- ═══════════════════════════════════════════════════════════════
-- Değişiklikler:
--   a) v_deneme hesabı per-cycle (trigger ile aynı mantık)
--   b) Gebe kontrolü: 260+ gün geçmişse auto-close + islem_log
--                      <260 günse hala blok (hata döndür)
--   c) Return'e uyarı alanı eklendi

DROP FUNCTION IF EXISTS public.tohumlama_kaydet(text, date, text, text, text);

CREATE FUNCTION public.tohumlama_kaydet(
  p_hayvan_id    text,
  p_tarih        date,
  p_sperma       text,
  p_hekim_id     text    DEFAULT NULL,
  p_irk_bilgisi  text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan      record;
  v_yas_gun     integer;
  v_deneme      integer;
  v_toh_id      uuid := gen_random_uuid();
  v_gorev1_id   uuid := gen_random_uuid();
  v_gorev2_id   uuid := gen_random_uuid();
  v_islem_id    text := gen_random_uuid()::text;
  v_stok_id     uuid;
  v_gebe_toh    record;
  v_uyari       text := NULL;
  v_auto_close  boolean := false;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  IF v_hayvan.cinsiyet = 'Erkek' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Erkek hayvana tohumlama yapılamaz');
  END IF;

  IF v_hayvan.dogum_tarihi IS NOT NULL THEN
    v_yas_gun := CURRENT_DATE - v_hayvan.dogum_tarihi;
    IF v_yas_gun < 365 THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan 12 aydan küçük — tohumlama yapılamaz');
    END IF;
  END IF;

  -- Gebe kontrolü: 260+ gün auto-close, <260 gün blok
  SELECT * INTO v_gebe_toh FROM public.tohumlama
  WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe'
  ORDER BY tarih DESC LIMIT 1;

  IF FOUND THEN
    IF (CURRENT_DATE - v_gebe_toh.tarih::date) > 260 THEN
      -- Auto-close: 260 günü geçmiş gebelik otomatik kapatılır
      UPDATE public.tohumlama
      SET sonuc = 'Doğum Yaptı'
      WHERE id = v_gebe_toh.id;

      INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
      VALUES (
        gen_random_uuid()::text,
        'DOGUM_OTOMATIK',
        p_hayvan_id,
        v_gebe_toh.id::text,
        'tohumlama',
        jsonb_build_object(
          'olusturulan', '[]'::jsonb,
          'guncellenen', jsonb_build_array(
            jsonb_build_object(
              'tablo', 'tohumlama',
              'id', v_gebe_toh.id::text,
              'degisim', 'sonuc: Gebe → Doğum Yaptı'
            )
          )
        )
      );

      v_uyari := '260+ günlük gebelik otomatik kapatıldı (Doğum Yaptı). Yeni tohumlama kaydediliyor.';
      v_auto_close := true;
      -- Devam et — yeni tohumlama kaydedilecek
    ELSE
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan zaten gebe — önce gebeliği kapatın');
    END IF;
  END IF;

  -- Önceki Bekliyor tohumlamaları Boş yap (event stack kuralı)
  UPDATE public.tohumlama
  SET sonuc = 'Boş'
  WHERE hayvan_id = p_hayvan_id
    AND sonuc = 'Bekliyor';

  -- Deneme no: per-cycle (son Doğum/Abort sonrası tohumlama sayısı)
  SELECT COALESCE(COUNT(*), 0) + 1 INTO v_deneme
  FROM public.tohumlama
  WHERE hayvan_id = p_hayvan_id
    AND tarih > COALESCE(
      (SELECT MAX(tarih) FROM public.tohumlama
       WHERE hayvan_id = p_hayvan_id AND sonuc IN ('Doğum Yaptı', 'Abort')),
      '1900-01-01'::date
    );

  INSERT INTO public.tohumlama (id, hayvan_id, tarih, sperma, irk_bilgisi, hekim_id, sonuc, deneme_no)
  VALUES (v_toh_id, p_hayvan_id, p_tarih, p_sperma, p_irk_bilgisi, p_hekim_id, 'Bekliyor', v_deneme);

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
  VALUES
    (v_gorev1_id, p_hayvan_id, 'TOHUMLAMA_HAZIRLIK', '21. Gün gebelik kontrolü', p_tarih + 21, false),
    (v_gorev2_id, p_hayvan_id, 'TOHUMLAMA_HAZIRLIK', '35. Gün gebelik kontrolü', p_tarih + 35, false);

  -- Sperma stok düş
  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  SELECT s.id, 'Tohumlama', 1,
    'Tohumlama — ' || v_hayvan.kupe_no, false
  FROM public.stok s
  WHERE (s.urun_adi ILIKE '%' || p_sperma || '%' OR s.urun_adi = p_sperma)
    AND s.kategori = 'Sperma'
  LIMIT 1
  RETURNING id INTO v_stok_id;

  -- islem_log
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'TOHUMLAMA',
    p_hayvan_id,
    v_toh_id::text,
    'tohumlama',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'tohumlama',  'id', v_toh_id::text),
        jsonb_build_object('tablo', 'gorev_log',  'id', v_gorev1_id::text),
        jsonb_build_object('tablo', 'gorev_log',  'id', v_gorev2_id::text)
      ) ||
      CASE WHEN v_stok_id IS NOT NULL
        THEN jsonb_build_array(jsonb_build_object('tablo', 'stok_hareket', 'id', v_stok_id::text))
        ELSE '[]'::jsonb
      END,
      'guncellenen', '[]'::jsonb
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'tohumlama_id', v_toh_id,
    'deneme_no', v_deneme,
    'islem_id', v_islem_id,
    'uyari', v_uyari
  );
END;
$$;

-- ═══════════════════════════════════════════════════════════════
-- GRANT EXECUTE
-- ═══════════════════════════════════════════════════════════════
GRANT EXECUTE ON FUNCTION public.tohumlama_kaydet(text, date, text, text, text) TO anon, authenticated;

COMMIT;
