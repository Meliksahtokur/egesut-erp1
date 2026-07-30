-- 2026-07-30 — Vakaya elle planlı tohumlama ekleme + uygunluk kapısının ortaklanması
--
-- Neden: Tohumlama şu an yalnızca şablondan doğabiliyor; kullanıcı bir vakaya
-- ilaç ekler gibi elle tohumlama ekleyemiyor. Ayrıca uygunluk kontrolü tek
-- fonksiyonun içine gömülüydü — ikinci bir giriş noktası açılınca kural
-- kopyalanacaktı. Kural ortak bir yardımcıya alındı.
--
-- kaynak konvansiyonu: 'TEDAVI_SABLON_TOHUMLAMA:<case_id>:<sablon_id|MANUEL>'
-- Üçüncü segment elle eklenenlerde 'MANUEL'. Prefix bilinçli olarak aynı
-- bırakıldı: close_case_with_remaining ve diğer yaşam döngüsü kancaları
-- 'TEDAVI_SABLON_TOHUMLAMA:<case_id>:%' kalıbıyla eşleştiği için elle eklenen
-- tohumlamalar da hiçbir değişiklik olmadan aynı kancalara dahil olur.

BEGIN;

-- ── 1) Ortak uygunluk kapısı ───────────────────────────────────────────────
-- NULL döner = uygun. Aksi halde kullanıcıya gösterilecek sebep metni.
-- tohumlama_kaydet'in gerçek kapılarını hedef TARİHTE ön-uygular.
-- hayvanlar.tohumlama_durumu KULLANILMAZ (bayat + 4 farklı yazım) —
-- gebelik sinyali yalnız tohumlama tablosundan okunur.
CREATE OR REPLACE FUNCTION public._tohumlama_gorev_uygunluk(p_hayvan_id text, p_tarih date)
RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $function$
DECLARE v_h record;
BEGIN
  SELECT * INTO v_h FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND OR v_h.durum <> 'Aktif' THEN
    RETURN 'Hayvan aktif değil';
  END IF;
  IF v_h.cinsiyet = 'Erkek' THEN
    RETURN 'Erkek hayvana tohumlama görevi açılmaz';
  END IF;
  IF v_h.dogum_tarihi IS NOT NULL AND (p_tarih - v_h.dogum_tarihi) < 365 THEN
    RETURN 'Hayvan hedef tarihte 12 aydan küçük';
  END IF;
  IF EXISTS (SELECT 1 FROM public.tohumlama WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe') THEN
    RETURN 'Hayvan gebe';
  END IF;
  RETURN NULL;
END;
$function$;

-- ── 2) Şablon yolu artık ortak kapıyı kullanır ─────────────────────────────
CREATE OR REPLACE FUNCTION public.tedavi_sablon_tohumlama_gorev_ekle(p_case_id uuid, p_sablon_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_plan  jsonb;
  v_case  record;
  v_sebep text;
  v_id    uuid;
  v_date  date;
  v_time  time;
BEGIN
  -- nullif(...,'null'::jsonb): kolonda jsonb 'null' skaleri duruyor olabilir.
  SELECT nullif(tohumlama_plani, 'null'::jsonb) INTO v_plan
  FROM public.tedavi_sablonu WHERE id = p_sablon_id;
  IF v_plan IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'olustu', false);
  END IF;
  IF (v_plan->>'gun_ofset') IS NULL OR nullif(v_plan->>'planned_time','') IS NULL THEN
    RETURN jsonb_build_object('ok', true, 'olustu', false, 'sebep', 'Şablondaki tohumlama planı eksik');
  END IF;

  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Vaka bulunamadı'; END IF;

  IF EXISTS (SELECT 1 FROM public.gorev_log
             WHERE kaynak = 'TEDAVI_SABLON_TOHUMLAMA:' || p_case_id::text || ':' || p_sablon_id::text) THEN
    RETURN jsonb_build_object('ok', true, 'olustu', false);
  END IF;

  v_date := v_case.start_date + (v_plan->>'gun_ofset')::integer;
  v_time := (v_plan->>'planned_time')::time;

  -- Uygun değilse vaka açılışı patlamaz; görev açılmaz, sebep UI'a döner.
  v_sebep := public._tohumlama_gorev_uygunluk(v_case.animal_id, v_date);
  IF v_sebep IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'olustu', false, 'sebep', v_sebep);
  END IF;

  INSERT INTO public.gorev_log(id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, tamamlandi, kaynak)
  VALUES (gen_random_uuid(), v_case.animal_id, 'TOHUMLAMA_PLANLI', 'Planlı tohumlama', v_date, v_time, false,
          'TEDAVI_SABLON_TOHUMLAMA:' || p_case_id::text || ':' || p_sablon_id::text)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'olustu', true, 'gorev_id', v_id);
END;
$function$;

-- ── 3) Elle ekleme: vakaya ilaç ekler gibi tohumlama ekle ──────────────────
CREATE OR REPLACE FUNCTION public.vaka_tohumlama_ekle(
  p_case_id uuid,
  p_tarih   date,
  p_saat    time DEFAULT '08:00'::time
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $function$
DECLARE
  v_case  record;
  v_sebep text;
  v_id    uuid;
BEGIN
  IF p_tarih IS NULL OR p_saat IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tarih ve saat zorunlu');
  END IF;

  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadı');
  END IF;
  IF v_case.status <> 'active' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakaya tohumlama eklenemez');
  END IF;

  -- Vaka başına aynı anda tek açık planlı tohumlama.
  IF EXISTS (SELECT 1 FROM public.gorev_log
             WHERE gorev_tipi = 'TOHUMLAMA_PLANLI'
               AND kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:' || p_case_id::text || ':%'
               AND NOT tamamlandi AND NOT iptal) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu vakada zaten açık bir planlı tohumlama var');
  END IF;

  -- Elle eklemede uygunluk SESSİZ atlanmaz — kullanıcı bilerek istedi, sebebi görsün.
  v_sebep := public._tohumlama_gorev_uygunluk(v_case.animal_id, p_tarih);
  IF v_sebep IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', v_sebep);
  END IF;

  INSERT INTO public.gorev_log(id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, tamamlandi, kaynak)
  VALUES (gen_random_uuid(), v_case.animal_id, 'TOHUMLAMA_PLANLI', 'Planlı tohumlama', p_tarih, p_saat, false,
          'TEDAVI_SABLON_TOHUMLAMA:' || p_case_id::text || ':MANUEL')
  RETURNING id INTO v_id;

  INSERT INTO public.islem_log(id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (gen_random_uuid()::text, 'VAKA_TOHUMLAMA_EKLE', v_case.animal_id, v_id::text, 'gorev_log',
          jsonb_build_object('case_id', p_case_id, 'hedef_tarih', p_tarih, 'hedef_saat', p_saat));

  RETURN jsonb_build_object('ok', true, 'gorev_id', v_id);
END;
$function$;

GRANT EXECUTE ON FUNCTION public._tohumlama_gorev_uygunluk(text, date) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tedavi_sablon_tohumlama_gorev_ekle(uuid, uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.vaka_tohumlama_ekle(uuid, date, time) TO anon, authenticated;

COMMIT;
