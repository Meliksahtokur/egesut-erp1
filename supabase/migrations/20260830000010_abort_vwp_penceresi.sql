-- Goal A — Abort sonrası VWP penceresi
-- Abort'u mevcut postpartum VWP mekanizmasına bağlar: yeni pencere motoru YOK,
-- tohumlama_kaydet'in VWP bloğuna abort çapası eklenir.

-- (a) Kolon
ALTER TABLE public.tohumlama ADD COLUMN IF NOT EXISTS abort_tarihi date;

-- (b) Backfill — canlıda onaylanmış bulk UPDATE (birebir)
UPDATE public.tohumlama t
SET abort_tarihi = COALESCE((
  SELECT MIN(il.tarih)::date FROM public.islem_log il
  WHERE il.tip = 'ABORT_KAYDI' AND il.ref_id = t.id::text
), t.tarih)
WHERE t.sonuc = 'Abort' AND t.abort_tarihi IS NULL;


-- (c) tohumlama_abort — canlı gövde + minimal diff:
--     * 3. parametre p_abort_tarihi (DEFAULT CURRENT_DATE)
--     * UPDATE satırına abort_tarihi
--     * islem_log 'onceki' durumuna abort_tarihi (geri_al uyumu)
--     * Eski 2-parametreli imza korunur (DROP YOK)
CREATE OR REPLACE FUNCTION public.tohumlama_abort(p_tohumlama_id text, p_notlar text DEFAULT NULL::text, p_abort_tarihi date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_toh           record;
  v_islem_id      text := gen_random_uuid()::text;
  v_onceki_durum  text;
  v_onceki_tarih  date;
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama WHERE id::text = p_tohumlama_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı'); END IF;
  IF v_toh.sonuc != 'Gebe' THEN RETURN jsonb_build_object('ok', false, 'error', 'Sadece Gebe durumundaki tohumlama abort edilebilir'); END IF;
  SELECT tohumlama_durumu, tohumlama_onay_tarihi INTO v_onceki_durum, v_onceki_tarih FROM public.hayvanlar WHERE id = v_toh.hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil'); END IF;
  UPDATE public.tohumlama SET sonuc = 'Abort', abort_notlar = p_notlar, abort_tarihi = COALESCE(p_abort_tarihi, CURRENT_DATE) WHERE id::text = p_tohumlama_id;
  UPDATE public.hayvanlar SET tohumlama_durumu = NULL, tohumlama_onay_tarihi = NULL WHERE id = v_toh.hayvan_id;
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (v_islem_id, 'ABORT_KAYDI', v_toh.hayvan_id, p_tohumlama_id, 'tohumlama',
    jsonb_build_object('olusturulan', '[]'::jsonb, 'guncellenen', jsonb_build_array(jsonb_build_object('tablo', 'tohumlama', 'id', p_tohumlama_id, 'onceki', jsonb_build_object('sonuc', v_toh.sonuc, 'abort_tarihi', v_toh.abort_tarihi)), jsonb_build_object('tablo', 'hayvanlar', 'id', v_toh.hayvan_id, 'onceki', jsonb_build_object('tohumlama_durumu', v_onceki_durum, 'tohumlama_onay_tarihi', v_onceki_tarih))), 'notlar', p_notlar));
  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$function$
;

GRANT EXECUTE ON FUNCTION public.tohumlama_abort(text, text, date) TO anon, authenticated;


-- (d) tohumlama_kaydet — canlı gövde + SADECE iki dokunuş:
--     * DECLARE'e v_son_abort
--     * VWP bloğuna abort çapası (55 gün eşiği ve override davranışı aynı)
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
  v_son_abort      date;
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
  SELECT MAX(t.abort_tarihi) INTO v_son_abort FROM public.tohumlama t
    WHERE t.hayvan_id = p_hayvan_id AND t.sonuc = 'Abort' AND t.abort_tarihi IS NOT NULL;
  IF v_son_abort IS NOT NULL AND (v_son_dogum IS NULL OR v_son_abort > v_son_dogum) THEN
    v_vwp_gun := p_tarih - v_son_abort;
    IF v_vwp_gun < 55 AND NOT p_vwp_override THEN
      RAISE EXCEPTION 'ABORT_VWP_VIOLATION:%:%', v_vwp_gun, 55;
    END IF;
  ELSIF v_son_dogum IS NOT NULL THEN
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
$function$
;

NOTIFY pgrst, 'reload schema';
