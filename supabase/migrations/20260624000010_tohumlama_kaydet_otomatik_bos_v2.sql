-- Migration: tohumlama_kaydet — otomatik Boş + orphan temizleme (v2)
-- Tarih: 2026-06-24
-- Amac:
--   1) Aynı hayvana yeni tohumlama girildiğinde önceki Bekliyor kaydını otomatik Boş yap
--   2) Eski Bekliyor kaydın GEBELIK_KONTROL gorev_log'larını iptal et
--   3) Eski Bekliyor kaydın protokol_instance durumunu 'iptal' yap
--   4) islem_log'a audit trail yaz (geri alınabilirlik için)
-- Referans: 20260605000007_tohumlama_kaydet_update.sql (mevcut RPC)
--           20260330000031_tohumlama_sonuc_rpcs.sql (islem_log snapshot pattern)
--           20260522000003_stale_tohumlama_gorev_temizle.sql (iptal=true pattern)

BEGIN;

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
  -- Otomatik Boş + orphan temizleme
  v_eski_tohumlama record;
  v_iptal_gorev    integer := 0;
  v_iptal_inst     integer := 0;
  v_islem_id       text    := gen_random_uuid()::text;
  v_snapshot       jsonb;
BEGIN
  -- ── Mevcut validasyonlar (1:1 korunur) ──────────────────────────────────
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

  -- VWP kontrolü (55 gün)
  SELECT MAX(d.tarih) INTO v_son_dogum FROM public.dogum d WHERE d.anne_id = p_hayvan_id;
  IF v_son_dogum IS NOT NULL THEN
    v_vwp_gun := p_tarih - v_son_dogum;
    IF v_vwp_gun < 55 AND NOT p_vwp_override THEN
      RAISE EXCEPTION 'VWP_VIOLATION:%:%', v_vwp_gun, 55;
    END IF;
  END IF;

  -- ── ★ OTOMATİK BOŞ + ORPHAN TEMİZLEME ──────────────────────────────────
  -- Yeni cycle başlıyor: aynı hayvana ait eski Bekliyor kayıt(lar) ve bunlara
  -- bağlı orphan gorev/instance'lar kapatılır. Kullanıcı "hayvan boş ki
  -- tohumlanmış neyi muayene edeceksin" — orphan muayene görevi olmamalı.
  FOR v_eski_tohumlama IN
    SELECT id, deneme_no, tarih, sperma
    FROM public.tohumlama
    WHERE hayvan_id = p_hayvan_id AND sonuc = 'Bekliyor'
    FOR UPDATE
  LOOP
    -- 1) Eski tohumlama sonucunu Boş yap
    UPDATE public.tohumlama SET sonuc = 'Boş' WHERE id = v_eski_tohumlama.id;

    -- 2) Eski tohumlama kaynağına bağlı açık GEBELIK_KONTROL görevlerini iptal et
    --    (kaynak formatı: 'TOH-<eski_id>'). Sadece tamamlanmamış olanlar.
    UPDATE public.gorev_log
      SET iptal = true
      WHERE kaynak = 'TOH-' || v_eski_tohumlama.id::text
        AND tamamlandi = false
        AND iptal = false;
    GET DIAGNOSTICS v_iptal_gorev = ROW_COUNT;

    -- 3) Eski tohumlama kaynağına bağlı protokol_instance'ı iptal et
    UPDATE public.protokol_instance
      SET durum = 'iptal'
      WHERE kaynak_ref = 'TOH-' || v_eski_tohumlama.id::text
        AND durum = 'aktif';
    GET DIAGNOSTICS v_iptal_inst = ROW_COUNT;

    -- 4) islem_log audit trail — geri alınabilirlik için snapshot
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
      'notlar', 'Yeni tohumlama girildi — eski Bekliyor cycle otomatik kapatıldı'
    );
    INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
    VALUES (v_islem_id, 'TOHUMLAMA_OTOMATIK_BOS', p_hayvan_id,
            v_eski_tohumlama.id::text, 'tohumlama', v_snapshot);
  END LOOP;

  -- ── Deneme no (eski Boş'lar dahil tüm geçmiş üzerinden) ─────────────────
  SELECT COALESCE(MAX(deneme_no), 0) + 1 INTO v_deneme
  FROM public.tohumlama WHERE hayvan_id = p_hayvan_id;

  -- ── Yeni tohumlama INSERT (1:1 korunur) ─────────────────────────────────
  INSERT INTO public.tohumlama
    (id, hayvan_id, tarih, sperma, irk_bilgisi, hekim_id, sonuc, deneme_no, ek_uygulamalar, vwp_override)
  VALUES
    (v_toh_id, p_hayvan_id, p_tarih, p_sperma, p_irk_bilgisi, p_hekim_id, 'Bekliyor', v_deneme,
     p_ek_uygulamalar,
     CASE WHEN v_son_dogum IS NOT NULL AND (p_tarih - v_son_dogum) < 55 THEN true ELSE false END);

  -- VWP override loglama
  IF v_son_dogum IS NOT NULL AND (p_tarih - v_son_dogum) < 55 AND p_vwp_override THEN
    INSERT INTO public.islem_log (id, tip, ana_hayvan_id, snapshot)
    VALUES (
      gen_random_uuid()::text, 'VWP_OVERRIDE', p_hayvan_id,
      jsonb_build_object('tohumlama_id', v_toh_id, 'vwp_gun', p_tarih - v_son_dogum, 'son_dogum', v_son_dogum)
    );
  END IF;

  -- ── Yeni UREME/TOHUMLAMA instance aç (1:1 korunur) ──────────────────────
  v_kaynak := 'TOH-' || v_toh_id::text;

  INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
  VALUES (p_hayvan_id, 'UREME', 'TOHUMLAMA', v_kaynak, p_tarih, 'aktif')
  RETURNING id INTO v_inst_id;

  -- Yeni görevler (kaynak + protokol_instance_id birlikte)
  INSERT INTO public.gorev_log
    (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, protokol_instance_id)
  VALUES
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '21. Gün gebelik kontrolü', p_tarih + 21, false, v_kaynak, v_inst_id),
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '35. Gün gebelik kontrolü', p_tarih + 35, false, v_kaynak, v_inst_id);

  -- Stok hareketleri (1:1 korunur)
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

  RETURN jsonb_build_object(
    'ok',                       true,
    'tohumlama_id',             v_toh_id,
    'deneme_no',                v_deneme,
    'inst_id',                  v_inst_id,
    'otomatik_bos_sayisi',      v_iptal_gorev,
    'otomatik_iptal_instance',  v_iptal_inst
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.tohumlama_kaydet(text,date,text,text,text,jsonb,boolean) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;
