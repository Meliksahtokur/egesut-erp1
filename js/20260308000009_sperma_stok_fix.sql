-- Migration 009a: sperma stok düşme fix
-- tohumlama_kaydet RPC'de s.tur = 'Sperma' yerine s.kategori = 'Sperma' kullan

CREATE OR REPLACE FUNCTION public.tohumlama_kaydet(
  p_hayvan_id  text,
  p_tarih      date,
  p_sperma     text,
  p_hekim_id   text    DEFAULT NULL,
  p_irk_bilgisi text   DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_hayvan   record;
  v_yas_gun  integer;
  v_deneme   integer;
  v_toh_id   uuid := gen_random_uuid();
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

  SELECT COALESCE(MAX(deneme_no), 0) + 1 INTO v_deneme FROM public.tohumlama WHERE hayvan_id = p_hayvan_id;

  INSERT INTO public.tohumlama (id, hayvan_id, tarih, sperma, irk_bilgisi, hekim_id, sonuc, deneme_no)
  VALUES (v_toh_id, p_hayvan_id, p_tarih, p_sperma, p_irk_bilgisi, p_hekim_id, 'Bekliyor', v_deneme);

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
  VALUES
    (gen_random_uuid(), p_hayvan_id, 'TOHUMLAMA_HAZIRLIK', '21. Gün gebelik kontrolü', p_tarih + 21, false),
    (gen_random_uuid(), p_hayvan_id, 'TOHUMLAMA_HAZIRLIK', '35. Gün gebelik kontrolü', p_tarih + 35, false);

  -- Sperma stok düş — kategori = 'Sperma' kullan (tur değil)
  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  SELECT s.id, 'Tohumlama', 1,
    'Tohumlama — ' || v_hayvan.kupe_no, false
  FROM public.stok s
  WHERE (s.urun_adi ILIKE '%' || p_sperma || '%' OR s.urun_adi = p_sperma)
    AND s.kategori = 'Sperma'
  LIMIT 1;

  RETURN jsonb_build_object('ok', true, 'tohumlama_id', v_toh_id, 'deneme_no', v_deneme);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
