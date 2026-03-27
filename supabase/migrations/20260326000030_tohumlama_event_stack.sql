-- Migration: tohumlama event stack — önceki Bekliyor→Boş + islem_log snapshot + tohumlama_sonuc_gebe RPC
-- Etkiler: tohumlama_kaydet RPC (güncelleme), tohumlama_sonuc_gebe RPC (yeni)
--          Tablolar: tohumlama, gorev_log, islem_log, hayvanlar
-- Geri alınabilir: evet — DROP FUNCTION tohumlama_sonuc_gebe(text);
--                          DROP FUNCTION tohumlama_kaydet(text,date,text,text,text);
--                          (eski versiyonu migration 20260326000028'den yeniden uygula)

BEGIN;

-- 1. tohumlama_kaydet: DROP + yeniden oluştur
--    Değişiklikler:
--      a) Yeni tohumlama INSERT'ten önce: önceki Bekliyor kayıtları Boş yap
--      b) gorev_log için önceden ID üret (v_gorev1_id, v_gorev2_id)
--      c) islem_log INSERT ekle — tohumlama + gorev_log ID'leri olusturulan array'inde
--      d) Dönüş değerine islem_id eklendi

DROP FUNCTION IF EXISTS public.tohumlama_kaydet(text, date, text, text, text);

CREATE FUNCTION public.tohumlama_kaydet(
  p_hayvan_id    text,
  p_tarih        date,
  p_sperma       text,
  p_hekim_id     text,
  p_irk_bilgisi  text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan    record;
  v_yas_gun   integer;
  v_deneme    integer;
  v_toh_id    uuid := gen_random_uuid();
  v_gorev1_id uuid := gen_random_uuid();
  v_gorev2_id uuid := gen_random_uuid();
  v_islem_id  text := gen_random_uuid()::text;
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

  IF EXISTS (SELECT 1 FROM public.tohumlama WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe') THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan zaten gebe — önce gebeliği kapatın');
  END IF;

  -- Önceki Bekliyor tohumlamaları Boş yap (event stack kuralı)
  UPDATE public.tohumlama
  SET sonuc = 'Boş'
  WHERE hayvan_id = p_hayvan_id
    AND sonuc = 'Bekliyor';

  SELECT COALESCE(MAX(deneme_no), 0) + 1 INTO v_deneme FROM public.tohumlama WHERE hayvan_id = p_hayvan_id;

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
  LIMIT 1;

  -- islem_log: tohumlama + gorev_log ID'leri olusturulan array'ine ekle (geri alınabilmesi için)
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
      ),
      'guncellenen', '[]'::jsonb
    )
  );

  RETURN jsonb_build_object('ok', true, 'tohumlama_id', v_toh_id, 'deneme_no', v_deneme, 'islem_id', v_islem_id);
END;
$$;

-- 2. tohumlama_sonuc_gebe: yeni RPC
--    Sadece son + Bekliyor tohumlamayı Gebe yapar,
--    hayvanlar.tohumlama_durumu günceller,
--    islem_log'a guncellenen snapshot ile kaydeder (geri alınabilir)

CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_gebe(
  p_tohumlama_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh          record;
  v_son_toh_id   text;
  v_islem_id     text := gen_random_uuid()::text;
  v_onceki_durum text;
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama
  WHERE id::text = p_tohumlama_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  IF v_toh.sonuc != 'Bekliyor' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Bekliyor durumundaki tohumlama gebe ilanı alabilir');
  END IF;

  -- Bu hayvanın son tohumlaması mı?
  SELECT id::text INTO v_son_toh_id
  FROM public.tohumlama
  WHERE hayvan_id = v_toh.hayvan_id
  ORDER BY deneme_no DESC
  LIMIT 1;

  IF v_son_toh_id != p_tohumlama_id THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece son tohumlama gebe ilanı alabilir');
  END IF;

  -- Hayvanın önceki tohumlama_durumu kaydet (geri alınabilmesi için)
  SELECT tohumlama_durumu INTO v_onceki_durum
  FROM public.hayvanlar
  WHERE id = v_toh.hayvan_id::uuid;

  UPDATE public.tohumlama SET sonuc = 'Gebe' WHERE id::text = p_tohumlama_id;

  UPDATE public.hayvanlar
  SET tohumlama_durumu = 'Gebe'
  WHERE id = v_toh.hayvan_id::uuid;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'GEBE_ATAMA',
    v_toh.hayvan_id,
    p_tohumlama_id,
    'tohumlama',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object(
          'tablo', 'tohumlama',
          'id', p_tohumlama_id,
          'onceki', jsonb_build_object('sonuc', v_toh.sonuc)
        ),
        jsonb_build_object(
          'tablo', 'hayvanlar',
          'id', v_toh.hayvan_id,
          'onceki', jsonb_build_object('tohumlama_durumu', v_onceki_durum)
        )
      )
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$$;

COMMIT;
