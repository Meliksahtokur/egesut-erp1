-- 20260902000004_asi_toplu_gorev.sql
-- Toplu aşı görevi (kullanıcı onayı 2026-09-02): tek kart + alt görevler.
-- Checkbox ile birden çok aşı seçilince: 1 parent ASI_PLANLI görev + her aşı için
-- 1 alt görev (kendi rezervasyonu) atomik olarak yaratılır.
-- Ayrıca asi_gorev_planla'ya mükerrer-plan koruması eklenir:
--   aynı hayvan + aynı aşı stoğu + aynı hedef tarih için açık görev varsa reddeder
--   (kullanıcı kararı: 'aynı gün için aynı aşı görevi tekrar açılamamalı').

-- ── 1) asi_gorev_planla v2: mükerrer-plan koruması ─────────────────────────
CREATE OR REPLACE FUNCTION public.asi_gorev_planla(
  p_hayvan_id text,
  p_vaccine_id uuid,
  p_doz numeric,
  p_tarih date,
  p_aciklama text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_vax      record;
  v_hayvan   text;
  v_gorev_id uuid := gen_random_uuid();
BEGIN
  IF p_doz IS NULL OR p_doz <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Doz pozitif olmalı');
  END IF;

  SELECT * INTO v_vax FROM public.vaccines WHERE id = p_vaccine_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Aşı bulunamadı');
  END IF;
  IF v_vax.stock_item_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Aşının stok bağlantısı yok: ' || v_vax.name);
  END IF;

  IF p_hayvan_id IS NOT NULL THEN
    SELECT id INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
    END IF;
  END IF;

  -- Mükerrer plan koruması: aynı hayvan + aynı aşı stoğu + aynı gün, açık görev
  IF EXISTS (
    SELECT 1 FROM public.gorev_log
     WHERE gorev_tipi = 'ASI_PLANLI'
       AND tamamlandi = false
       AND iptal = false
       AND stok_id = v_vax.stock_item_id
       AND hedef_tarih = p_tarih
       AND ((p_hayvan_id IS NULL AND hayvan_id IS NULL) OR hayvan_id = p_hayvan_id)
  ) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'mesaj', v_vax.name || ' için ' || p_tarih || ' tarihinde zaten planlı bir görev var',
      'kod', 'DUPLICATE');
  END IF;

  INSERT INTO public.gorev_log
    (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, kaynak)
  VALUES
    (v_gorev_id, p_hayvan_id, 'ASI_PLANLI',
     COALESCE(NULLIF(btrim(p_aciklama), ''), '💉 ' || v_vax.name || ' (planlı)'),
     p_tarih, false, v_vax.stock_item_id, p_doz, 'MANUEL');

  INSERT INTO public.stok_hareket
    (stok_id, tur, miktar, notlar, iptal, referans_tipi, referans_id)
  VALUES
    (v_vax.stock_item_id, 'Aşı (Plan)', p_doz, 'GorevID:' || v_gorev_id::text, false, 'asi_plan', v_gorev_id::text);

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('ASI_GOREV_PLAN', p_hayvan_id, v_gorev_id::text, 'gorev_log',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(jsonb_build_object('tablo', 'gorev_log', 'id', v_gorev_id::text)),
      'vaccine', v_vax.name, 'doz', p_doz, 'tarih', p_tarih),
    'Planlı aşı görevi: ' || v_vax.name || ' ' || p_doz || 'ml');

  RETURN jsonb_build_object('ok', true, 'gorev_id', v_gorev_id::text);
END;
$function$;

-- ── 2) Toplu planlama: 1 parent + N alt görev + N rezervasyon (atomik) ─────
CREATE OR REPLACE FUNCTION public.asi_toplu_planla(
  p_hayvan_id text,
  p_tarih date,
  p_items jsonb,
  p_aciklama text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_item       jsonb;
  v_vax        record;
  v_hayvan     text;
  v_parent_id  uuid := gen_random_uuid();
  v_child_id   uuid;
  v_ad         int := 0;
  v_isimler    text := '';
  v_cakisan    jsonb := '[]'::jsonb;
BEGIN
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Aşı listesi boş');
  END IF;
  IF p_hayvan_id IS NOT NULL THEN
    SELECT id INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
    END IF;
  END IF;

  -- Önce tümünü doğrula (tek biri sorunluysa hiçbiri yaratılmaz)
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    SELECT * INTO v_vax FROM public.vaccines WHERE id = (v_item->>'vaccine_id')::uuid;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Aşı bulunamadı (index ' || v_ad || ')');
    END IF;
    IF v_vax.stock_item_id IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Aşının stok bağlantısı yok: ' || v_vax.name);
    END IF;
    IF COALESCE((v_item->>'doz')::numeric, 0) <= 0 THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Doz pozitif olmalı: ' || v_vax.name);
    END IF;
    IF EXISTS (
      SELECT 1 FROM public.gorev_log
       WHERE gorev_tipi = 'ASI_PLANLI'
         AND tamamlandi = false
         AND iptal = false
         AND stok_id = v_vax.stock_item_id
         AND hedef_tarih = p_tarih
         AND ((p_hayvan_id IS NULL AND hayvan_id IS NULL) OR hayvan_id = p_hayvan_id)
    ) THEN
      v_cakisan := v_cakisan || jsonb_build_array(v_vax.name || ' (' || p_tarih || ' planlı)');
    END IF;
    v_ad := v_ad + 1;
  END LOOP;

  IF jsonb_array_length(v_cakisan) > 0 THEN
    RETURN jsonb_build_object('ok', false, 'kod', 'DUPLICATE', 'cakisan', v_cakisan,
      'mesaj', 'Bu tarih için zaten planlı: ' || (SELECT string_agg(x, ', ') FROM jsonb_array_elements_text(v_cakisan) x));
  END IF;

  INSERT INTO public.gorev_log
    (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak)
  VALUES
    (v_parent_id, p_hayvan_id, 'ASI_PLANLI',
     COALESCE(NULLIF(btrim(p_aciklama), ''), '💉 Toplu aşı (' || jsonb_array_length(p_items) || ' aşı)'),
     p_tarih, false, 'MANUEL');

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    SELECT * INTO v_vax FROM public.vaccines WHERE id = (v_item->>'vaccine_id')::uuid;
    v_child_id := gen_random_uuid();

    INSERT INTO public.gorev_log
      (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi,
       stok_id, miktar, kaynak, parent_id)
    VALUES
      (v_child_id, p_hayvan_id, 'ASI_PLANLI',
       '💉 ' || v_vax.name || ' — ' || (v_item->>'doz') || ' ' || COALESCE(v_vax.unit, 'ml'),
       p_tarih, false, v_vax.stock_item_id, (v_item->>'doz')::numeric, 'MANUEL', v_parent_id);

    INSERT INTO public.stok_hareket
      (stok_id, tur, miktar, notlar, iptal, referans_tipi, referans_id)
    VALUES
      (v_vax.stock_item_id, 'Aşı (Plan)', (v_item->>'doz')::numeric,
       'GorevID:' || v_child_id::text, false, 'asi_plan', v_child_id::text);

    v_isimler := v_isimler || CASE WHEN v_isimler = '' THEN '' ELSE ', ' END || v_vax.name;
  END LOOP;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('ASI_GOREV_PLAN', p_hayvan_id, v_parent_id::text, 'gorev_log',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(jsonb_build_object('tablo', 'gorev_log', 'id', v_parent_id::text, 'tip', 'toplu')),
      'vaccines', p_items, 'tarih', p_tarih),
    'Toplu aşı görevi: ' || v_isimler);

  RETURN jsonb_build_object('ok', true, 'parent_id', v_parent_id::text, 'adet', jsonb_array_length(p_items));
END;
$function$;
