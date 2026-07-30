-- 2026-07-30 — Şablon planlı tohumlama: opsiyonellik + iptal edilebilirlik + yaşam döngüsü
--
-- KÖK NEDEN (1): jsonb 'null' ≠ SQL NULL.
--   Frontend `tohumlama_plani` anahtarını HER ZAMAN gönderiyor (checkbox kapalıyken
--   değeri null). Postgres'te `'{"a":null}'::jsonb->'a'` SQL NULL değil, jsonb 'null'
--   skaleri döner → `v_tohumlama IS NOT NULL` guard'ı tetiklenir → gun_ofset NULL
--   olduğu için "Planlı tohumlama gün ve saat bilgisi zorunlu" hatası.
--   SONUÇ: 22 Tem 2026'dan beri TOHUMLAMASIZ HİÇBİR ŞABLON KAYDEDİLEMİYORDU
--   (ayak mantarı/mastit şablonuna bile tohumlama eklemek zorunluydu).
--   FIX: nullif(..., 'null'::jsonb) ile normalize — hem yazan hem okuyan tarafta.
--
-- KÖK NEDEN (2): Görev açılırken hayvan uygunluğuna hiç bakılmıyordu.
--   8 günlük buzağıya ve gebe ineklere planlı tohumlama görevi açılmıştı.
--   FIX: tohumlama_kaydet'in kapıları (erkek / <12 ay / gebe / pasif) görev
--   açılışında ön-uygulanır; uygun değilse görev açılmaz, sebep UI'a döner.
--
-- KÖK NEDEN (3): Görevin hiçbir otomatik kapanma yolu yoktu.
--   Migration ...000003 görevi parent_id'siz bağımsız yaptığı için vaka erken
--   kapatma onu göremiyordu; gebe ilanı ve doğrudan tohumlama da kapatmıyordu.
--   FIX: üç yaşam döngüsü kancası (close_case_with_remaining, tohumlama_sonuc_gebe,
--   tohumlama_kaydet).
--
-- Fonksiyon gövdeleri canlı pg_get_functiondef çıktısından üretildi (scratchpad/
-- gen_migration.py) — sadece işaretli bloklar değişti, gerisi birebir aynı.

BEGIN;

-- ── 1) tedavi_sablon_kaydet — jsonb 'null' normalize ──────────────────
CREATE OR REPLACE FUNCTION public.tedavi_sablon_kaydet(p_id uuid, p_ad text, p_aciklama text, p_disease_ids jsonb, p_kalemler jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id uuid;
  v_kalemler jsonb := CASE WHEN jsonb_typeof(p_kalemler)='object' THEN coalesce(p_kalemler->'kalemler','[]'::jsonb) ELSE coalesce(p_kalemler,'[]'::jsonb) END;
  v_tohumlama jsonb := CASE WHEN jsonb_typeof(p_kalemler)='object' THEN nullif(p_kalemler->'tohumlama_plani','null'::jsonb) ELSE NULL END;
BEGIN
  IF p_ad IS NULL OR btrim(p_ad) = '' THEN RETURN jsonb_build_object('ok',false,'mesaj','Şablon adı zorunlu'); END IF;
  IF EXISTS (SELECT 1 FROM public.tedavi_sablonu WHERE lower(ad)=lower(p_ad) AND (p_id IS NULL OR id<>p_id)) THEN
    RETURN jsonb_build_object('ok',false,'mesaj','Bu isimde başka bir şablon var');
  END IF;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(v_kalemler) k WHERE coalesce((k->>'gun_no')::smallint,0)<1) THEN
    RETURN jsonb_build_object('ok',false,'mesaj','Şablon gün ofseti 0 veya daha büyük olmalı');
  END IF;
  IF v_tohumlama IS NOT NULL AND (
    coalesce((v_tohumlama->>'gun_ofset')::integer,-1)<0 OR nullif(v_tohumlama->>'planned_time','') IS NULL
  ) THEN RETURN jsonb_build_object('ok',false,'mesaj','Planlı tohumlama gün ve saat bilgisi zorunlu'); END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.tedavi_sablonu(ad,aciklama,tohumlama_plani)
    VALUES(p_ad,NULLIF(btrim(coalesce(p_aciklama,'')),''),v_tohumlama) RETURNING id INTO v_id;
  ELSE
    UPDATE public.tedavi_sablonu SET ad=p_ad,aciklama=NULLIF(btrim(coalesce(p_aciklama,'')),''),tohumlama_plani=v_tohumlama,updated_at=now() WHERE id=p_id;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'mesaj','Şablon bulunamadı'); END IF;
    v_id:=p_id;
    DELETE FROM public.sablon_hastalik_eslem WHERE sablon_id=v_id;
    DELETE FROM public.tedavi_sablonu_kalem WHERE sablon_id=v_id;
  END IF;
  INSERT INTO public.sablon_hastalik_eslem(sablon_id,disease_id)
  SELECT v_id,t.val::uuid FROM jsonb_array_elements_text(coalesce(p_disease_ids,'[]'::jsonb)) t(val)
  ON CONFLICT(sablon_id,disease_id) DO NOTHING;
  INSERT INTO public.tedavi_sablonu_kalem(sablon_id,gun_no,planned_time,stok_id,drug_product_id,dose,unit,route)
  SELECT v_id,(k->>'gun_no')::smallint,(k->>'planned_time')::time,NULLIF(k->>'stok_id',''),NULLIF(k->>'drug_product_id','')::uuid,(k->>'dose')::numeric,k->>'unit',NULLIF(k->>'route','')
  FROM jsonb_array_elements(v_kalemler) k;
  RETURN jsonb_build_object('ok',true,'sablon_id',v_id);
END; $function$;

-- ── 2) tedavi_sablon_tohumlama_gorev_ekle — jsonb 'null' + uygunluk kapısı 
CREATE OR REPLACE FUNCTION public.tedavi_sablon_tohumlama_gorev_ekle(p_case_id uuid, p_sablon_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_plan   jsonb;
  v_case   record;
  v_hayvan record;
  v_id     uuid;
  v_date   date;
  v_time   time;
BEGIN
  -- nullif(...,'null'::jsonb): kolonda jsonb 'null' skaleri duruyor olabilir
  -- (eski frontend her zaman anahtarı gönderiyordu) — SQL NULL'a normalize et.
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

  -- UYGUNLUK KAPISI: tohumlama_kaydet'in kapıları burada ÖN-uygulanır.
  -- Uygun değilse vaka açılışı patlamaz — sadece görev açılmaz, sebep UI'a döner.
  -- (Regresyon: ayak/mastit şablonu buzağıya uygulanınca tohumlama görevi açılıyordu.)
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = v_case.animal_id;
  IF NOT FOUND OR v_hayvan.durum <> 'Aktif' THEN
    RETURN jsonb_build_object('ok', true, 'olustu', false, 'sebep', 'Hayvan aktif değil');
  END IF;
  IF v_hayvan.cinsiyet = 'Erkek' THEN
    RETURN jsonb_build_object('ok', true, 'olustu', false, 'sebep', 'Erkek hayvana tohumlama görevi açılmaz');
  END IF;
  -- Yaş kontrolü hedef tarihte yapılır (görev geleceğe planlanıyor).
  IF v_hayvan.dogum_tarihi IS NOT NULL AND (v_date - v_hayvan.dogum_tarihi) < 365 THEN
    RETURN jsonb_build_object('ok', true, 'olustu', false, 'sebep', 'Hayvan hedef tarihte 12 aydan küçük');
  END IF;
  IF lower(coalesce(v_hayvan.tohumlama_durumu, '')) = 'gebe'
     OR EXISTS (SELECT 1 FROM public.tohumlama WHERE hayvan_id = v_case.animal_id AND sonuc = 'Gebe') THEN
    RETURN jsonb_build_object('ok', true, 'olustu', false, 'sebep', 'Hayvan gebe');
  END IF;

  INSERT INTO public.gorev_log(id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, hedef_saat, tamamlandi, kaynak)
  VALUES (gen_random_uuid(), v_case.animal_id, 'TOHUMLAMA_PLANLI', 'Planlı tohumlama', v_date, v_time, false,
          'TEDAVI_SABLON_TOHUMLAMA:' || p_case_id::text || ':' || p_sablon_id::text)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'olustu', true, 'gorev_id', v_id);
END; $function$;

-- ── 3) close_case_with_remaining — vaka kapaninca planli tohumlamayi da kapat 
CREATE OR REPLACE FUNCTION public.close_case_with_remaining(p_case_id uuid, p_not text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_remaining_count int;
BEGIN
  UPDATE public.stok_hareket sh
  SET iptal = true
  FROM public.drug_administrations da
  JOIN public.treatment_day_uygulamalar tdu
    ON tdu.id = da.seans_admin_id
  WHERE tdu.case_id = p_case_id
    AND tdu.uygulanmadi = false
    AND tdu.uygulama_tamamlandi_at IS NULL
    AND sh.notlar = 'drug_admin:' || da.id::text
    AND sh.iptal = false;

  UPDATE public.stok_hareket sh
  SET iptal = true
  FROM public.drug_administrations da
  JOIN public.treatment_days td ON td.id = da.treatment_day_id
  WHERE td.case_id = p_case_id
    AND da.seans_admin_id IS NULL
    AND td.tamamlandi = false
    AND (da.uygulanmadi IS NULL OR da.uygulanmadi = false)
    AND sh.notlar = 'drug_admin:' || da.id::text
    AND sh.iptal = false;

  UPDATE public.treatment_day_uygulamalar
  SET uygulanmadi = true,
      iptal_nedeni = 'Vaka erken kapatildi' || COALESCE(': ' || p_not, ''),
      updated_at = now()
  WHERE case_id = p_case_id
    AND uygulanmadi = false
    AND uygulama_tamamlandi_at IS NULL;

  GET DIAGNOSTICS v_remaining_count = ROW_COUNT;

  UPDATE public.drug_administrations da
  SET uygulanmadi = true
  FROM public.treatment_day_uygulamalar tdu
  WHERE tdu.id = da.seans_admin_id
    AND tdu.case_id = p_case_id
    AND tdu.uygulanmadi = true
    AND da.uygulanmadi IS DISTINCT FROM true;

  UPDATE public.drug_administrations da
  SET uygulanmadi = true
  FROM public.treatment_days td
  WHERE td.id = da.treatment_day_id
    AND td.case_id = p_case_id
    AND da.seans_admin_id IS NULL
    AND td.tamamlandi = false
    AND da.uygulanmadi IS DISTINCT FROM true;

  UPDATE public.treatment_days
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE case_id = p_case_id AND tamamlandi = false;

  -- 5. gorev_log kalan acik gorevler — gorev_tipi guard (JSON-olmayan aciklama'lari cast'ten ele)
  UPDATE public.gorev_log g
  SET tamamlandi = true, tamamlanma_tarihi = now()
  FROM public.treatment_days td
  WHERE td.case_id = p_case_id
    AND g.gorev_tipi IN ('TEDAVI_GUN','TEDAVI_SEANS')
    AND (CASE WHEN g.aciklama IS JSON OBJECT
              THEN (g.aciklama::jsonb->>'day_id') END)::uuid = td.id
    AND g.tamamlandi = false;

  -- 5b. Planlı tohumlama gorevi bagimsiz (parent_id/day_id yok) — adim 5'in
  -- treatment_days JOIN'i onu GOREMEZ. Vaka kapaninca acikta kalmasin.
  UPDATE public.gorev_log
  SET iptal = true, tamamlandi = true, tamamlanma_tarihi = now()
  WHERE gorev_tipi = 'TOHUMLAMA_PLANLI'
    AND kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:' || p_case_id::text || ':%'
    AND tamamlandi = false AND iptal = false;

  UPDATE public.cases
  SET status = 'closed', closed_at = now()
  WHERE id = p_case_id;

  INSERT INTO public.islem_log(id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text, 'CASE_CLOSED_EARLY',
    (SELECT animal_id FROM public.cases WHERE id = p_case_id),
    p_case_id::text, 'cases',
    jsonb_build_object(
      'iptal_edilen_seans', v_remaining_count,
      'stok_iade_edildi', v_remaining_count > 0,
      'not', p_not
    )
  );

  RETURN jsonb_build_object('ok', true, 'iptal_edilen_seans', v_remaining_count);
END;
$function$;

-- ── 4) tohumlama_sonuc_gebe — gebe ilaninda planli tohumlamayi da iptal et 
CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_gebe(p_tohumlama_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_toh               record;
  v_son_toh_id        text;
  v_islem_id          text   := gen_random_uuid()::text;
  v_onceki_durum      text;
  v_iptal_gorev_ids   text[] := '{}';
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama WHERE id::text = p_tohumlama_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tohumlama bulunamadı');
  END IF;

  IF v_toh.sonuc != 'Bekliyor' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Sadece Bekliyor durumundaki tohumlama gebe ilanı alabilir');
  END IF;

  SELECT id::text INTO v_son_toh_id
  FROM public.tohumlama
  WHERE hayvan_id = v_toh.hayvan_id
  ORDER BY tarih DESC, created_at DESC, id::text DESC
  LIMIT 1
  FOR UPDATE;

  IF v_son_toh_id != p_tohumlama_id THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Sadece son tohumlama gebe ilanı alabilir');
  END IF;

  SELECT tohumlama_durumu INTO v_onceki_durum
  FROM public.hayvanlar WHERE id = v_toh.hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan aktif değil');
  END IF;

  UPDATE public.tohumlama SET sonuc = 'Gebe' WHERE id::text = p_tohumlama_id;
  UPDATE public.hayvanlar SET tohumlama_durumu = 'Gebe' WHERE id = v_toh.hayvan_id;

  SELECT COALESCE(array_agg(id::text), '{}') INTO v_iptal_gorev_ids
  FROM public.gorev_log
  WHERE hayvan_id = v_toh.hayvan_id
    AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK', 'TOHUMLAMA_PLANLI')
    AND NOT tamamlandi AND NOT iptal;

  UPDATE public.gorev_log SET iptal = true
  WHERE hayvan_id = v_toh.hayvan_id
    AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK', 'TOHUMLAMA_PLANLI')
    AND NOT tamamlandi AND NOT iptal;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id, 'GEBE_ATAMA', v_toh.hayvan_id, p_tohumlama_id, 'tohumlama',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object('tablo', 'tohumlama', 'id', p_tohumlama_id, 'onceki', jsonb_build_object('sonuc', v_toh.sonuc)),
        jsonb_build_object('tablo', 'hayvanlar', 'id', v_toh.hayvan_id, 'onceki', jsonb_build_object('tohumlama_durumu', v_onceki_durum))
      ),
      'iptal_gorevler', to_jsonb(v_iptal_gorev_ids),
      'iptal_sebep', 'gebe'
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$function$;

-- ── 5) tohumlama_kaydet — dogrudan tohumlama planli gorevi konusuz birakir 
CREATE OR REPLACE FUNCTION public.tohumlama_kaydet(p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text DEFAULT NULL::text, p_irk_bilgisi text DEFAULT NULL::text, p_ek_uygulamalar jsonb DEFAULT '[]'::jsonb, p_vwp_override boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_hayvan         record;
  v_yas_gun        integer;
  v_deneme         integer;
  v_toh_id         uuid := gen_random_uuid();
  v_ek             jsonb;
  v_ek_stok        uuid;
  v_son_dogum      date;
  v_vwp_gun        integer;
  v_inst_id        uuid;
  v_kaynak         text;
  v_eski_tohumlama record;
  v_iptal_gorev    integer := 0;
  v_iptal_inst     integer := 0;
  v_islem_id       text    := gen_random_uuid()::text;
  v_snapshot       jsonb;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar
    WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id; END IF;
  IF v_hayvan.cinsiyet = 'Erkek' THEN RAISE EXCEPTION 'Erkek hayvana tohumlama yapılamaz'; END IF;

  IF v_hayvan.dogum_tarihi IS NOT NULL THEN
    v_yas_gun := CURRENT_DATE - v_hayvan.dogum_tarihi;
    IF v_yas_gun < 365 THEN
      RAISE EXCEPTION '12 aydan küçük hayvana tohumlama yapılamaz (% gün)', v_yas_gun;
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM public.tohumlama WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe') THEN
    RAISE EXCEPTION 'Hayvan zaten gebe — önce gebeliği kapatın';
  END IF;

  IF p_tarih > (NOW() AT TIME ZONE 'Europe/Istanbul')::date THEN
    RAISE EXCEPTION 'Tohumlama tarihi ileri tarih olamaz';
  END IF;

  SELECT MAX(d.tarih) INTO v_son_dogum FROM public.dogum d WHERE d.anne_id = p_hayvan_id;
  IF v_son_dogum IS NOT NULL THEN
    v_vwp_gun := p_tarih - v_son_dogum;
    IF v_vwp_gun < 55 AND NOT p_vwp_override THEN
      RAISE EXCEPTION 'VWP_VIOLATION:%:%', v_vwp_gun, 55;
    END IF;
  END IF;

  -- OTOMATIK BOS + ORPHAN TEMIZLEME
  FOR v_eski_tohumlama IN
    SELECT id, deneme_no, tarih, sperma
    FROM public.tohumlama
    WHERE hayvan_id = p_hayvan_id AND sonuc = 'Bekliyor'
    FOR UPDATE
  LOOP
    UPDATE public.tohumlama SET sonuc = 'Boş' WHERE id = v_eski_tohumlama.id;

    UPDATE public.gorev_log
      SET iptal = true
      WHERE kaynak = 'TOH-' || v_eski_tohumlama.id::text
        AND tamamlandi = false
        AND iptal = false;
    GET DIAGNOSTICS v_iptal_gorev = ROW_COUNT;

    UPDATE public.protokol_instance
      SET durum = 'iptal'
      WHERE kaynak_ref = 'TOH-' || v_eski_tohumlama.id::text
        AND durum = 'aktif';
    GET DIAGNOSTICS v_iptal_inst = ROW_COUNT;

    v_snapshot := jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'tohumlama', 'id', v_toh_id::text, 'veri', jsonb_build_object(
          'hayvan_id', p_hayvan_id, 'tarih', p_tarih, 'sperma', p_sperma,
          'hekim_id', p_hekim_id, 'irk_bilgisi', p_irk_bilgisi,
          'sonuc', 'Bekliyor', 'deneme_no', v_deneme
        ))
      ),
      'guncellenen', jsonb_build_array(
        jsonb_build_object(
          'tablo', 'tohumlama', 'id', v_eski_tohumlama.id::text,
          'onceki', jsonb_build_object('sonuc', 'Bekliyor'),
          'sonraki', jsonb_build_object('sonuc', 'Boş', 'sebep', 'OTOMATIK_YENI_TOHUMLAMA')
        )
      ),
      'iptal_gorev_sayisi', v_iptal_gorev,
      'iptal_instance_sayisi', v_iptal_inst,
      'notlar', 'Yeni tohumlama girildi — eski Bekliyor cycle otomatik kapatildi'
    );
    INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
    VALUES (v_islem_id, 'TOHUMLAMA_OTOMATIK_BOS', p_hayvan_id,
            v_eski_tohumlama.id::text, 'tohumlama', v_snapshot);
  END LOOP;

  SELECT COALESCE(MAX(deneme_no), 0) + 1 INTO v_deneme
  FROM public.tohumlama WHERE hayvan_id = p_hayvan_id;

  INSERT INTO public.tohumlama
    (id, hayvan_id, tarih, sperma, irk_bilgisi, hekim_id, sonuc, deneme_no, ek_uygulamalar, vwp_override)
  VALUES
    (v_toh_id, p_hayvan_id, p_tarih, p_sperma, p_irk_bilgisi, p_hekim_id, 'Bekliyor', v_deneme,
     p_ek_uygulamalar,
     CASE WHEN v_son_dogum IS NOT NULL AND (p_tarih - v_son_dogum) < 55 THEN true ELSE false END);

  IF v_son_dogum IS NOT NULL AND (p_tarih - v_son_dogum) < 55 AND p_vwp_override THEN
    INSERT INTO public.islem_log (id, tip, ana_hayvan_id, snapshot)
    VALUES (
      gen_random_uuid()::text, 'VWP_OVERRIDE', p_hayvan_id,
      jsonb_build_object('tohumlama_id', v_toh_id, 'vwp_gun', p_tarih - v_son_dogum, 'son_dogum', v_son_dogum)
    );
  END IF;

  v_kaynak := 'TOH-' || v_toh_id::text;

  INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
  VALUES (p_hayvan_id, 'UREME', 'TOHUMLAMA', v_kaynak, p_tarih, 'aktif')
  RETURNING id INTO v_inst_id;

  INSERT INTO public.gorev_log
    (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, protokol_instance_id)
  VALUES
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '21. Gün gebelik kontrolü', p_tarih + 21, false, v_kaynak, v_inst_id),
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '35. Gün gebelik kontrolü', p_tarih + 35, false, v_kaynak, v_inst_id);

  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
    SELECT s.id, 'Tohumlama', 1,
           'Tohumlama — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id), false
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
          v_ek_stok, 'Tohumlama',
          COALESCE((v_ek->>'doz')::numeric, 1),
          'Tohumlama ek uygulama: ' || COALESCE(v_ek->>'tur', '') || ' — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
          false
        );
      END IF;
    END LOOP;
  END IF;

  -- Hayvan dogrudan (gorev uzerinden degil) tohumlandiysa acik planli tohumlama
  -- gorevi artik konusuz kalir. planli_tohumlama_kaydet bu fonksiyonu icerden
  -- cagirir ve HEMEN ARDINDAN kendi gorevini iptal=false + tamamlandi=true
  -- yapar; sirali oldugu icin dogru sonuc kazanir.
  UPDATE public.gorev_log
  SET iptal = true, tamamlandi = true, tamamlanma_tarihi = now()
  WHERE hayvan_id = p_hayvan_id
    AND gorev_tipi = 'TOHUMLAMA_PLANLI'
    AND tamamlandi = false AND iptal = false;

  RETURN jsonb_build_object(
    'ok',                       true,
    'tohumlama_id',             v_toh_id,
    'deneme_no',                v_deneme,
    'inst_id',                  v_inst_id,
    'otomatik_bos_sayisi',      v_iptal_gorev,
    'otomatik_iptal_instance',  v_iptal_inst
  );
END;
$function$;

-- ── 6) planli_tohumlama_kaydet — kendi gorevini iptal=false ile kapatir 
CREATE OR REPLACE FUNCTION public.planli_tohumlama_kaydet(p_gorev_id uuid, p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text DEFAULT NULL::text, p_irk_bilgisi text DEFAULT NULL::text, p_ek_uygulamalar jsonb DEFAULT '[]'::jsonb, p_vwp_override boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_gorev record; v_result jsonb; v_tohumlama_id text;
BEGIN
  SELECT * INTO v_gorev FROM public.gorev_log WHERE id=p_gorev_id FOR UPDATE;
  IF NOT FOUND OR v_gorev.gorev_tipi<>'TOHUMLAMA_PLANLI' THEN RAISE EXCEPTION 'Planlı tohumlama görevi bulunamadı'; END IF;
  IF v_gorev.tamamlandi OR v_gorev.iptal THEN RAISE EXCEPTION 'Görev kapalı'; END IF;
  IF v_gorev.hayvan_id<>p_hayvan_id THEN RAISE EXCEPTION 'Görev hayvanı ile tohumlama hayvanı eşleşmiyor'; END IF;
  v_result:=public.tohumlama_kaydet(p_hayvan_id,p_tarih,p_sperma,p_hekim_id,p_irk_bilgisi,p_ek_uygulamalar,p_vwp_override);
  v_tohumlama_id:=v_result->>'tohumlama_id';
  UPDATE public.tohumlama SET gerceklesme_at=now() WHERE id=v_tohumlama_id::uuid;
  UPDATE public.gorev_log SET tamamlandi=true,iptal=false,tamamlanma_tarihi=now(),ref_tohumlama_id=v_tohumlama_id WHERE id=p_gorev_id;
  INSERT INTO public.islem_log(id,tip,ana_hayvan_id,ref_id,ref_tablo,snapshot)
  VALUES(gen_random_uuid()::text,'PLANLI_TOHUMLAMA_TAMAMLA',p_hayvan_id,p_gorev_id::text,'gorev_log',jsonb_build_object('tohumlama_id',v_tohumlama_id));
  RETURN v_result || jsonb_build_object('gorev_id',p_gorev_id);
END; $function$;

GRANT EXECUTE ON FUNCTION public.tedavi_sablon_kaydet(uuid, text, text, jsonb, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tedavi_sablon_tohumlama_gorev_ekle(uuid, uuid) TO anon, authenticated;

COMMIT;
