-- Migration: postpartum_gozlem_kizginlik
-- kizginlik_kaydet: doğumdan <55 gün içindeyse sonuc='POSTPARTUM_GOZLEM' set et

CREATE OR REPLACE FUNCTION public.kizginlik_kaydet(
  p_hayvan_id  text,
  p_tarih      date,
  p_belirti    text    DEFAULT NULL,
  p_notlar     text    DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_hayvan       record;
  v_yas_gun      integer;
  v_son_dogum    date;
  v_dogum_gun    integer := NULL;
  v_sonuc        text := 'GOZLEMLENDI';
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  IF v_hayvan.cinsiyet = 'Erkek' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Erkek hayvanlarda kızgınlık kaydı yapılamaz');
  END IF;

  IF v_hayvan.dogum_tarihi IS NOT NULL THEN
    v_yas_gun := CURRENT_DATE - v_hayvan.dogum_tarihi;
    IF v_yas_gun < 365 THEN
      RETURN jsonb_build_object(
        'ok', false,
        'mesaj', 'Hayvan 12 aydan küçük — kızgınlık kaydı yapılamaz',
        'oneri', 'Hayvan kartındaki Notlar bölümüne ekleyin'
      );
    END IF;
  END IF;

  -- Son doğum tarihini kontrol et (dogum tablosundan)
  SELECT MAX(d.tarih) INTO v_son_dogum
  FROM public.dogum d
  WHERE d.anne_id = p_hayvan_id;

  IF v_son_dogum IS NOT NULL THEN
    v_dogum_gun := p_tarih - v_son_dogum;
    IF v_dogum_gun >= 0 AND v_dogum_gun < 55 THEN
      v_sonuc := 'POSTPARTUM_GOZLEM';
    END IF;
  END IF;

  INSERT INTO public.kizginlik_log (id, hayvan_id, tarih, belirti, notlar, sonuc)
  VALUES (gen_random_uuid()::text, p_hayvan_id, p_tarih, p_belirti, p_notlar, v_sonuc);

  RETURN jsonb_build_object(
    'ok', true,
    'postpartum', v_sonuc = 'POSTPARTUM_GOZLEM',
    'dogum_gun', v_dogum_gun
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.kizginlik_kaydet(text, date, text, text) TO anon, authenticated;
