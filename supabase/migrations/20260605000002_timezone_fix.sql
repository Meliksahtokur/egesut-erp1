-- Migration: BUG-049 — Timezone fix
-- Sorun: DB UTC çalışıyor, TR UTC+3. Gece 00:00–02:59 arası kullanıcının
--   girdiği "bugün" tarihi DB'de "yarın" olarak algılanıyor → ileri tarih
--   guard RAISE EXCEPTION fırlatıyor.
-- Fix: ileri tarih validasyonunda CURRENT_DATE → (NOW() AT TIME ZONE 'Europe/Istanbul')::date
-- Etkilenen fonksiyonlar: tohumlama_kaydet, tohumlama_tekrar_kaydet, gebelik_kaydet_manual

BEGIN;

-- ── 1. tohumlama_kaydet ────────────────────────────────────────────────────
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
  SELECT * INTO v_hayvan
  FROM public.hayvanlar
  WHERE id = p_hayvan_id AND durum = 'Aktif';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id;
  END IF;

  IF v_hayvan.cinsiyet = 'Erkek' THEN
    RAISE EXCEPTION 'Erkek hayvana tohumlama yapılamaz';
  END IF;

  IF v_hayvan.dogum_tarihi IS NOT NULL THEN
    v_yas_gun := CURRENT_DATE - v_hayvan.dogum_tarihi;
    IF v_yas_gun < 365 THEN
      RAISE EXCEPTION '12 aydan küçük hayvana tohumlama yapılamaz (% gün)', v_yas_gun;
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.tohumlama
    WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe'
  ) THEN
    RAISE EXCEPTION 'Hayvan zaten gebe — önce gebeliği kapatın';
  END IF;

  IF p_tarih > (NOW() AT TIME ZONE 'Europe/Istanbul')::date THEN
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

  SELECT COALESCE(MAX(deneme_no), 0) + 1 INTO v_deneme
  FROM public.tohumlama
  WHERE hayvan_id = p_hayvan_id;

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

  INSERT INTO public.gorev_log
    (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi)
  VALUES
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '21. Gün gebelik kontrolü', p_tarih + 21, false),
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '35. Gün gebelik kontrolü', p_tarih + 35, false);

  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  SELECT
    s.id, 'Tohumlama', 1,
    'Tohumlama — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
    false
  FROM public.stok s
  WHERE (s.urun_adi ILIKE '%' || p_sperma || '%' OR s.urun_adi = p_sperma)
    AND s.kategori = 'Sperma'
  LIMIT 1;

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

-- ── 2. tohumlama_tekrar_kaydet ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tohumlama_tekrar_kaydet(
  p_hayvan_id   text,
  p_tarih       date,
  p_sperma      text,
  p_hekim_id    text DEFAULT NULL,
  p_irk_bilgisi text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan   record;
  v_toh      record;
  v_eski     jsonb;
  v_yeni_denemeler jsonb;
BEGIN
  SELECT * INTO v_hayvan
  FROM public.hayvanlar
  WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id;
  END IF;

  IF p_tarih > (NOW() AT TIME ZONE 'Europe/Istanbul')::date THEN
    RAISE EXCEPTION 'Tarih ileri olamaz';
  END IF;

  SELECT * INTO v_toh
  FROM public.tohumlama
  WHERE hayvan_id = p_hayvan_id
    AND sonuc = 'Bekliyor'
    AND tarih >= CURRENT_DATE - INTERVAL '15 days'
  ORDER BY tarih DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Son 15 gün içinde Bekliyor tohumlama bulunamadı';
  END IF;

  v_eski := jsonb_build_object(
    'no',       v_toh.deneme_sayisi,
    'tarih',    v_toh.tarih,
    'sperma',   v_toh.sperma,
    'hekim_id', v_toh.hekim_id
  );
  v_yeni_denemeler := v_toh.denemeler || jsonb_build_array(v_eski);

  UPDATE public.tohumlama
  SET tarih         = p_tarih,
      sperma        = p_sperma,
      hekim_id      = COALESCE(p_hekim_id, hekim_id),
      irk_bilgisi   = COALESCE(p_irk_bilgisi, irk_bilgisi),
      deneme_sayisi = deneme_sayisi + 1,
      denemeler     = v_yeni_denemeler
  WHERE id = v_toh.id;

  UPDATE public.gorev_log
  SET iptal = true
  WHERE hayvan_id = p_hayvan_id
    AND tamamlandi = false
    AND iptal = false
    AND gorev_tipi IN ('TOHUMLAMA_HAZIRLIK', 'GEBELIK_KONTROL');

  INSERT INTO public.gorev_log
    (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, ref_tohumlama_id)
  VALUES
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '21. Gün gebelik kontrolü', p_tarih + 21, false, v_toh.id::text),
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '35. Gün gebelik kontrolü', p_tarih + 35, false, v_toh.id::text);

  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  SELECT
    s.id, 'Tohumlama', 1,
    'Tekrar Aşım ' || (v_toh.deneme_sayisi + 1) || '. deneme — ' ||
      COALESCE(v_hayvan.kupe_no, p_hayvan_id),
    false
  FROM public.stok s
  WHERE (s.urun_adi ILIKE '%' || p_sperma || '%' OR s.urun_adi = p_sperma)
    AND s.kategori = 'Sperma'
  LIMIT 1;

  RETURN jsonb_build_object(
    'ok',           true,
    'tohumlama_id', v_toh.id,
    'deneme_sayisi', v_toh.deneme_sayisi + 1
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.tohumlama_tekrar_kaydet(text, date, text, text, text)
  TO anon, authenticated;

-- ── 3. gebelik_kaydet_manual ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.gebelik_kaydet_manual(
  p_hayvan_id text,
  p_tarih date,
  p_sperma text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_tohumlama_id text;
  v_snapshot jsonb;
  v_deneme integer;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id; END IF;
  IF v_hayvan.durum IS DISTINCT FROM 'Aktif' THEN
    RAISE EXCEPTION 'Hayvan aktif değil (durum: %)', v_hayvan.durum;
  END IF;
  IF v_hayvan.cinsiyet IS DISTINCT FROM 'Dişi' THEN
    RAISE EXCEPTION 'Sadece dişi hayvanlara gebelik kaydedilebilir';
  END IF;
  IF p_tarih > (NOW() AT TIME ZONE 'Europe/Istanbul')::date THEN
    RAISE EXCEPTION 'İleri tarih girilemez: %', p_tarih;
  END IF;
  IF EXISTS (SELECT 1 FROM public.tohumlama WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe') THEN
    RAISE EXCEPTION 'Hayvanın aktif gebeliği bulunuyor';
  END IF;

  v_tohumlama_id := gen_random_uuid()::text;

  SELECT COALESCE(MAX(deneme_no), 0) + 1 INTO v_deneme
  FROM public.tohumlama WHERE hayvan_id = p_hayvan_id;

  INSERT INTO public.tohumlama (id, hayvan_id, tarih, sperma, sonuc, deneme_no)
  VALUES (v_tohumlama_id, p_hayvan_id, p_tarih, p_sperma, 'Gebe', v_deneme);

  v_snapshot := jsonb_build_object(
    'olusturulan', jsonb_build_array(jsonb_build_object(
      'tablo', 'tohumlama', 'id', v_tohumlama_id,
      'veri', jsonb_build_object(
        'hayvan_id', p_hayvan_id, 'tarih', p_tarih,
        'sperma', p_sperma, 'sonuc', 'Gebe', 'deneme_no', v_deneme
      )
    )),
    'guncellenen', '[]'::jsonb,
    'silinen', '[]'::jsonb
  );

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('GEBELIK_MANUEL', p_hayvan_id, p_hayvan_id, 'hayvanlar', v_snapshot,
    format('Manuel gebelik kaydı (tarih: %s, sperma: %s)', p_tarih, COALESCE(p_sperma, '-')));

  RETURN jsonb_build_object('ok', true, 'tohumlama_id', v_tohumlama_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.gebelik_kaydet_manual(text, date, text) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
