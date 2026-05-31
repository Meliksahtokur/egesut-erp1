-- Faz B: VWP Enforcement — tohumlama.vwp_override kolonu + tohumlama_kaydet güncelleme

-- ═══ 1. Kolon ekle ═══
ALTER TABLE public.tohumlama ADD COLUMN IF NOT EXISTS vwp_override boolean DEFAULT false;

-- ═══ 2. tohumlama_kaydet güncelle ═══
CREATE OR REPLACE FUNCTION public.tohumlama_kaydet(
  p_hayvan_id      text,
  p_tarih          date,
  p_sperma         text,
  p_hekim_id       text    DEFAULT NULL,
  p_irk_bilgisi    text    DEFAULT NULL,
  p_ek_uygulamalar jsonb   DEFAULT '[]'::jsonb,
  p_vwp_override   boolean DEFAULT false
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan   record;
  v_yas_gun  integer;
  v_deneme   integer;
  v_toh_id   uuid := gen_random_uuid();
  v_ek       jsonb;
  v_ek_stok  uuid;
  v_son_dogum date;
  v_vwp_gun  integer;
BEGIN
  -- Hayvan var mı?
  SELECT * INTO v_hayvan
  FROM public.hayvanlar
  WHERE id = p_hayvan_id AND durum = 'Aktif';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id;
  END IF;

  -- Erkek kontrolü
  IF v_hayvan.cinsiyet = 'Erkek' THEN
    RAISE EXCEPTION 'Erkek hayvana tohumlama yapılamaz';
  END IF;

  -- Yaş kontrolü (12 ay = 365 gün)
  IF v_hayvan.dogum_tarihi IS NOT NULL THEN
    v_yas_gun := CURRENT_DATE - v_hayvan.dogum_tarihi;
    IF v_yas_gun < 365 THEN
      RAISE EXCEPTION '12 aydan küçük hayvana tohumlama yapılamaz (% gün)', v_yas_gun;
    END IF;
  END IF;

  -- Aktif gebelik kontrolü
  IF EXISTS (
    SELECT 1 FROM public.tohumlama
    WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe'
  ) THEN
    RAISE EXCEPTION 'Hayvan zaten gebe — önce gebeliği kapatın';
  END IF;

  -- İleri tarih kontrolü
  IF p_tarih > CURRENT_DATE THEN
    RAISE EXCEPTION 'Tohumlama tarihi ileri tarih olamaz';
  END IF;

  -- VWP kontrolü (55 gün)
  SELECT MAX(d.tarih) INTO v_son_dogum
  FROM public.dogum d
  WHERE d.anne_id = p_hayvan_id;

  IF v_son_dogum IS NOT NULL THEN
    v_vwp_gun := p_tarih - v_son_dogum;
    IF v_vwp_gun < 55 AND NOT p_vwp_override THEN
      RAISE EXCEPTION 'VWP_VIOLATION:%:%', v_vwp_gun, 55;
    END IF;
  END IF;

  -- Deneme no
  SELECT COALESCE(MAX(deneme_no), 0) + 1 INTO v_deneme
  FROM public.tohumlama
  WHERE hayvan_id = p_hayvan_id;

  -- Tohumlama kaydı
  INSERT INTO public.tohumlama
    (id, hayvan_id, tarih, sperma, irk_bilgisi, hekim_id, sonuc, deneme_no, ek_uygulamalar, vwp_override)
  VALUES
    (v_toh_id, p_hayvan_id, p_tarih, p_sperma, p_irk_bilgisi, p_hekim_id, 'Bekliyor', v_deneme, p_ek_uygulamalar,
     CASE WHEN v_son_dogum IS NOT NULL AND (p_tarih - v_son_dogum) < 55 THEN true ELSE false END);

  -- VWP override loglama
  IF v_son_dogum IS NOT NULL AND (p_tarih - v_son_dogum) < 55 AND p_vwp_override THEN
    INSERT INTO public.islem_log (id, tip, ana_hayvan_id, snapshot)
    VALUES (
      gen_random_uuid()::text,
      'VWP_OVERRIDE',
      p_hayvan_id,
      jsonb_build_object(
        'tohumlama_id', v_toh_id,
        'vwp_gun', p_tarih - v_son_dogum,
        'son_dogum', v_son_dogum
      )
    );
  END IF;

  -- Kontrol görevleri
  INSERT INTO public.gorev_log
    (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
  VALUES
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '21. Gün gebelik kontrolü', p_tarih + 21, false),
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '35. Gün gebelik kontrolü', p_tarih + 35, false);

  -- Sperma stok düş
  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  SELECT
    s.id, 'Tohumlama', 1,
    'Tohumlama — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
    false
  FROM public.stok s
  WHERE (s.urun_adi ILIKE '%' || p_sperma || '%' OR s.urun_adi = p_sperma)
    AND s.kategori = 'Sperma'
  LIMIT 1;

  -- Ek uygulama stok düşüm
  IF p_ek_uygulamalar IS NOT NULL AND jsonb_array_length(p_ek_uygulamalar) > 0 THEN
    FOR v_ek IN SELECT * FROM jsonb_array_elements(p_ek_uygulamalar) LOOP
      IF (v_ek->>'stok_id') IS NOT NULL AND (v_ek->>'stok_id') <> '' THEN
        v_ek_stok := (v_ek->>'stok_id')::uuid;
        INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
        VALUES (
          v_ek_stok,
          'Tohumlama',
          COALESCE((v_ek->>'doz')::numeric, 1),
          'Tohumlama ek uygulama: ' || COALESCE(v_ek->>'tur', '') || ' — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
          false
        );
      END IF;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'ok',           true,
    'tohumlama_id', v_toh_id,
    'deneme_no',    v_deneme
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.tohumlama_kaydet(text, date, text, text, text, jsonb, boolean) TO anon, authenticated;
