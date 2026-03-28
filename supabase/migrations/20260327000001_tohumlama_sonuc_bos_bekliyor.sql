-- Migration: Tohumlama sonuç RPC'leri — Boş ve Bekliyor durumları
-- Etkiler: Yeni RPC'ler: tohumlama_sonuc_bos, tohumlama_sonuc_bekliyor
--          Tablolar: tohumlama, hayvanlar, islem_log
-- Geri alınabilir: evet — DROP FUNCTION tohumlama_sonuc_bos(text); DROP FUNCTION tohumlama_sonuc_bekliyor(text);

BEGIN;

-- 1. tohumlama_sonuc_bos: Tohumlama sonucu Boş yap
--    - Tohumlama sonucu 'Bekliyor' → 'Boş' güncelle
--    - Hayvanlar.tohumlama_durumu → 'Boş' yap
--    - islem_log kaydı ekle (geri alınabilir)

CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_bos(
  p_tohumlama_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh             record;
  v_islem_id        text := gen_random_uuid()::text;
  v_onceki_durum    text;
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama
  WHERE id::text = p_tohumlama_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  -- Sadece Bekliyor durumundaki tohumlama Boş yapılabilir
  IF v_toh.sonuc != 'Bekliyor' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Bekliyor durumundaki tohumlama Boş yapılabilir');
  END IF;

  -- Hayvanın önceki tohumlama_durumu kaydet (geri alınabilmesi için)
  -- AND durum = 'Aktif' guard: pasif/ölü hayvan işlemi engellensin
  SELECT tohumlama_durumu INTO v_onceki_durum
  FROM public.hayvanlar
  WHERE id = v_toh.hayvan_id::uuid
    AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil');
  END IF;

  -- Tohumlama sonucu Boş yap
  UPDATE public.tohumlama SET sonuc = 'Boş' WHERE id::text = p_tohumlama_id;

  -- Hayvanlar.tohumlama_durumu Boş yap
  UPDATE public.hayvanlar
  SET tohumlama_durumu = 'Boş'
  WHERE id = v_toh.hayvan_id::uuid;

  -- islem_log: değişikliği geri alınabilir hale getir
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'BOS_ATAMA',
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

-- 2. tohumlama_sonuc_bekliyor: Hatalı tohumlama kaydını Bekliyor'a al ve önceki duruma dön
--    - Tohumlama sonucu 'Gebe' veya diğer → 'Bekliyor' güncelle
--    - Hayvanlar.tohumlama_durumu → önceki duruma dön
--    - islem_log kaydı ekle (geri alınabilir)
--    Not: Bu genellikle sistem hatası veya operatör hatasını düzeltmek için kullanılır

CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_bekliyor(
  p_tohumlama_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh             record;
  v_islem_id        text := gen_random_uuid()::text;
  v_onceki_durum    text;
  v_onceki_toh_sonuc text;
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama
  WHERE id::text = p_tohumlama_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  -- Sadece Gebe veya Boş durumundaki tohumlama Bekliyor yapılabilir
  -- (Doğum Yaptı ve Abort değiştirilemez — domain kuralı)
  IF v_toh.sonuc NOT IN ('Gebe', 'Boş') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Gebe veya Boş durumundaki tohumlama Bekliyor yapılabilir');
  END IF;

  -- Hayvanın mevcut tohumlama_durumu kaydet (geri alınabilmesi için)
  -- AND durum = 'Aktif' guard: pasif/ölü hayvan işlemi engellensin
  SELECT tohumlama_durumu INTO v_onceki_durum
  FROM public.hayvanlar
  WHERE id = v_toh.hayvan_id::uuid
    AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil');
  END IF;

  -- Tohumlama sonucu önceki değerini kaydet
  v_onceki_toh_sonuc := v_toh.sonuc;

  -- Tohumlama sonucu Bekliyor yap
  UPDATE public.tohumlama SET sonuc = 'Bekliyor' WHERE id::text = p_tohumlama_id;

  -- Hayvanlar.tohumlama_durumu 'Tohumlanabilir' haline getir
  -- (Bu, sistem hatası düzeltme işlemi olduğundan, güvenli default olarak tohumlanabilir yapıyoruz)
  UPDATE public.hayvanlar
  SET tohumlama_durumu = 'Tohumlanabilir'
  WHERE id = v_toh.hayvan_id::uuid;

  -- islem_log: değişikliği geri alınabilir hale getir
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'BEKLIYOR_ATAMA',
    v_toh.hayvan_id,
    p_tohumlama_id,
    'tohumlama',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object(
          'tablo', 'tohumlama',
          'id', p_tohumlama_id,
          'onceki', jsonb_build_object('sonuc', v_onceki_toh_sonuc)
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
