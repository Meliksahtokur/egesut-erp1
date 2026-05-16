-- Migration: Faz 1 — RPC Bypass Düzeltmeleri
-- A1-A6 + Phantom RPC'ler
-- Tarih: 2026-05-16

-- ── A1: BUZAĞI SÜTTEN KESME ONAYLA ─────────────
CREATE OR REPLACE FUNCTION public.buzagi_sutten_kesme_onayla(p_hayvan_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_snapshot jsonb;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id;
  END IF;
  IF v_hayvan.hesap_kategori IS DISTINCT FROM 'sut_icen' THEN
    RAISE EXCEPTION 'Bu hayvan süt içen kategorisinde değil (kategori: %)', v_hayvan.hesap_kategori;
  END IF;
  IF v_hayvan.durum IS DISTINCT FROM 'Aktif' THEN
    RAISE EXCEPTION 'Hayvan aktif değil (durum: %)', v_hayvan.durum;
  END IF;

  v_snapshot := jsonb_build_object(
    'guncellenen', jsonb_build_array(jsonb_build_object(
      'tablo', 'hayvanlar', 'id', p_hayvan_id,
      'onceki', jsonb_build_object('suttten_kesme_tarihi', v_hayvan.suttten_kesme_tarihi),
      'sonraki', jsonb_build_object('suttten_kesme_tarihi', CURRENT_DATE)
    ))
  );

  UPDATE public.hayvanlar SET suttten_kesme_tarihi = CURRENT_DATE WHERE id = p_hayvan_id;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, snapshot, kullanici_notu)
  VALUES ('SUTEN_KESME', p_hayvan_id, v_snapshot, 'Buzağı sütten kesildi');

  RETURN jsonb_build_object('ok', true, 'hayvan_id', p_hayvan_id, 'tarih', CURRENT_DATE);
END;
$$;

GRANT EXECUTE ON FUNCTION public.buzagi_sutten_kesme_onayla(text) TO anon, authenticated;

-- ── A2: TOHUMLANABILIR ONAY ────────────────────
CREATE OR REPLACE FUNCTION public.hayvan_tohumlanabilir_onayla(p_hayvan_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_snapshot jsonb;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id; END IF;
  IF v_hayvan.durum IS DISTINCT FROM 'Aktif' THEN
    RAISE EXCEPTION 'Hayvan aktif değil (durum: %)', v_hayvan.durum;
  END IF;
  IF v_hayvan.cinsiyet IS DISTINCT FROM 'Dişi' THEN
    RAISE EXCEPTION 'Sadece dişi hayvanlar tohumlanabilir';
  END IF;
  IF v_hayvan.kisir THEN
    RAISE EXCEPTION 'Kısır hayvan tohumlanamaz';
  END IF;

  v_snapshot := jsonb_build_object(
    'guncellenen', jsonb_build_array(jsonb_build_object(
      'tablo', 'hayvanlar', 'id', p_hayvan_id,
      'onceki', jsonb_build_object(
        'tohumlama_durumu', v_hayvan.tohumlama_durumu,
        'tohumlama_onay_tarihi', v_hayvan.tohumlama_onay_tarihi
      ),
      'sonraki', jsonb_build_object(
        'tohumlama_durumu', 'tohumlanabilir',
        'tohumlama_onay_tarihi', CURRENT_DATE
      )
    ))
  );

  UPDATE public.hayvanlar SET
    tohumlama_durumu = 'tohumlanabilir',
    tohumlama_onay_tarihi = CURRENT_DATE
  WHERE id = p_hayvan_id;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, snapshot, kullanici_notu)
  VALUES ('TOHUMLAMA_DURUMU_ONAYLA', p_hayvan_id, v_snapshot, 'Tohumlanabilir olarak onaylandı');

  RETURN jsonb_build_object('ok', true, 'hayvan_id', p_hayvan_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.hayvan_tohumlanabilir_onayla(text) TO anon, authenticated;

-- ── A3: TOHUMLAMA ERTELE ───────────────────────
CREATE OR REPLACE FUNCTION public.hayvan_tohumlama_ertele(p_hayvan_id text, p_ay integer)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_hedef_tarih date;
  v_snapshot jsonb;
BEGIN
  IF p_ay < 1 OR p_ay > 12 THEN
    RAISE EXCEPTION 'Erteleme süresi 1-12 ay arasında olmalıdır (% girildi)', p_ay;
  END IF;

  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id; END IF;
  IF v_hayvan.durum IS DISTINCT FROM 'Aktif' THEN
    RAISE EXCEPTION 'Hayvan aktif değil (durum: %)', v_hayvan.durum;
  END IF;

  v_hedef_tarih := CURRENT_DATE + (p_ay * 30);

  v_snapshot := jsonb_build_object(
    'guncellenen', jsonb_build_array(jsonb_build_object(
      'tablo', 'hayvanlar', 'id', p_hayvan_id,
      'onceki', jsonb_build_object(
        'tohumlama_durumu', v_hayvan.tohumlama_durumu,
        'tohumlama_onay_tarihi', v_hayvan.tohumlama_onay_tarihi
      ),
      'sonraki', jsonb_build_object(
        'tohumlama_durumu', 'ertelendi',
        'tohumlama_onay_tarihi', v_hedef_tarih
      )
    ))
  );

  UPDATE public.hayvanlar SET
    tohumlama_durumu = 'ertelendi',
    tohumlama_onay_tarihi = v_hedef_tarih
  WHERE id = p_hayvan_id;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, snapshot, kullanici_notu)
  VALUES ('TOHUMLAMA_ERTELE', p_hayvan_id, v_snapshot,
    format('Tohumlama %s ay ertelendi (hedef: %s)', p_ay, v_hedef_tarih));

  RETURN jsonb_build_object('ok', true, 'hedef_tarih', v_hedef_tarih);
END;
$$;

GRANT EXECUTE ON FUNCTION public.hayvan_tohumlama_ertele(text, integer) TO anon, authenticated;

-- ── A4: GÖREV TAMAMLA (transaction: gorev_log + stok + padok) ──
CREATE OR REPLACE FUNCTION public.gorev_tamamla(
  p_gorev_id text,
  p_padok_hedef text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev record;
  v_hayvan record;
  v_snapshot jsonb;
  v_stok_dusuldu boolean := false;
  v_padok_guncellendi boolean := false;
  v_olusturulan jsonb := '[]'::jsonb;
  v_guncellenen jsonb := '[]'::jsonb;
BEGIN
  SELECT * INTO v_gorev FROM public.gorev_log WHERE id = p_gorev_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Görev bulunamadı: %', p_gorev_id;
  END IF;
  IF v_gorev.tamamlandi THEN
    RETURN jsonb_build_object('ok', true, 'mesaj', 'Görev zaten tamamlanmış');
  END IF;

  -- a) Görevi tamamla
  v_guncellenen := v_guncellenen || jsonb_build_object(
    'tablo', 'gorev_log', 'id', p_gorev_id,
    'onceki', jsonb_build_object('tamamlandi', v_gorev.tamamlandi, 'tamamlanma_tarihi', v_gorev.tamamlanma_tarihi),
    'sonraki', jsonb_build_object('tamamlandi', true, 'tamamlanma_tarihi', now())
  );

  UPDATE public.gorev_log SET
    tamamlandi = true,
    tamamlanma_tarihi = now()
  WHERE id = p_gorev_id;

  -- b) Stok düşümü (görevde stok_id + miktar varsa)
  IF v_gorev.stok_id IS NOT NULL AND v_gorev.miktar IS NOT NULL AND v_gorev.miktar > 0 THEN
    v_stok_dusuldu := true;
    v_olusturulan := v_olusturulan || jsonb_build_object(
      'tablo', 'stok_hareket',
      'id', gen_random_uuid()::text,
      'veri', jsonb_build_object(
        'stok_id', v_gorev.stok_id,
        'tur', 'Görev',
        'miktar', v_gorev.miktar,
        'notlar', 'GorevID:' || p_gorev_id,
        'iptal', false
      )
    );

    INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
    VALUES (gen_random_uuid(), v_gorev.stok_id, 'Görev', v_gorev.miktar,
      'GorevID:' || p_gorev_id, false);
  END IF;

  -- c) Padok değişikliği
  IF p_padok_hedef IS NOT NULL AND v_gorev.hayvan_id IS NOT NULL THEN
    SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = v_gorev.hayvan_id;
    IF FOUND THEN
      v_padok_guncellendi := true;
      v_guncellenen := v_guncellenen || jsonb_build_object(
        'tablo', 'hayvanlar', 'id', v_gorev.hayvan_id,
        'onceki', jsonb_build_object('padok', v_hayvan.padok),
        'sonraki', jsonb_build_object('padok', p_padok_hedef)
      );

      UPDATE public.hayvanlar SET padok = p_padok_hedef WHERE id = v_gorev.hayvan_id;
    END IF;
  END IF;

  v_snapshot := jsonb_build_object(
    'olusturulan', v_olusturulan,
    'guncellenen', v_guncellenen
  );

  INSERT INTO public.islem_log (tip, ana_hayvan_id, snapshot, kullanici_notu)
  VALUES ('GOREV_TAMAMLA', v_gorev.hayvan_id, v_snapshot,
    format('Görev tamamlandı (stok: %s, padok: %s)',
      CASE WHEN v_stok_dusuldu THEN 'evet' ELSE 'hayır' END,
      CASE WHEN v_padok_guncellendi THEN 'evet' ELSE 'hayır' END));

  RETURN jsonb_build_object(
    'ok', true,
    'gorev_id', p_gorev_id,
    'stok_dusuldu', v_stok_dusuldu,
    'padok_guncellendi', v_padok_guncellendi
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.gorev_tamamla(text, text) TO anon, authenticated;

-- ── Phantom Fix: stok_hareket_ekle (RPC_MAP'te referans ediliyor) ──
CREATE OR REPLACE FUNCTION public.stok_hareket_ekle(
  p_stok_id text,
  p_tur text,
  p_miktar numeric,
  p_notlar text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id text;
BEGIN
  v_id := gen_random_uuid()::text;

  INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
  VALUES (v_id, p_stok_id, p_tur, p_miktar, COALESCE(p_notlar, ''), false);

  INSERT INTO public.islem_log (tip, snapshot, kullanici_notu)
  VALUES ('STOK_HAREKET', jsonb_build_object(
    'olusturulan', jsonb_build_array(jsonb_build_object(
      'tablo', 'stok_hareket', 'id', v_id,
      'veri', jsonb_build_object('stok_id', p_stok_id, 'tur', p_tur, 'miktar', p_miktar, 'notlar', p_notlar, 'iptal', false)
    ))
  ), 'Stok hareketi: ' || COALESCE(p_notlar, p_tur));

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.stok_hareket_ekle(text, text, numeric, text) TO anon, authenticated;

-- ── A5-a: STOK EKLE (yeni stok kaydı) ──────────
CREATE OR REPLACE FUNCTION public.stok_ekle(
  p_urun_adi text,
  p_kategori text,
  p_birim text,
  p_baslangic_miktar numeric,
  p_esik numeric DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id text;
  v_hareket_id text;
BEGIN
  v_id := gen_random_uuid()::text;
  v_hareket_id := gen_random_uuid()::text;

  INSERT INTO public.stok (id, urun_adi, kategori, birim, baslangic_miktar, esik)
  VALUES (v_id, p_urun_adi, p_kategori, p_birim, p_baslangic_miktar, p_esik);

  INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
  VALUES (v_hareket_id, v_id, 'Başlangıç', p_baslangic_miktar, 'İlk kayıt', false);

  INSERT INTO public.islem_log (tip, snapshot, kullanici_notu)
  VALUES ('STOK_EKLE', jsonb_build_object(
    'olusturulan', jsonb_build_array(
      jsonb_build_object('tablo', 'stok', 'id', v_id,
        'veri', jsonb_build_object('urun_adi', p_urun_adi, 'kategori', p_kategori, 'birim', p_birim, 'baslangic_miktar', p_baslangic_miktar, 'esik', p_esik)),
      jsonb_build_object('tablo', 'stok_hareket', 'id', v_hareket_id,
        'veri', jsonb_build_object('stok_id', v_id, 'tur', 'Başlangıç', 'miktar', p_baslangic_miktar))
    )
  ), 'Yeni stok: ' || p_urun_adi);

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.stok_ekle(text, text, text, numeric, numeric) TO anon, authenticated;

-- ── A5-b: STOK EKLEME (mevcut stoğa ekle) ──────
CREATE OR REPLACE FUNCTION public.stok_ekleme(
  p_stok_id text,
  p_miktar numeric,
  p_notlar text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok record;
  v_hareket_id text;
BEGIN
  IF p_miktar <= 0 THEN
    RAISE EXCEPTION 'Miktar pozitif olmalıdır (%)', p_miktar;
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = p_stok_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Stok kaydı bulunamadı: %', p_stok_id;
  END IF;

  v_hareket_id := gen_random_uuid()::text;

  -- Stok miktarını güncelle (baslangic_miktar + p_miktar)
  -- NOT: stok_tuketim_view guncel_stok = baslangic_miktar - SUM(hareket)
  -- Bu nedenle baslangic_miktar'ı değiştirmek yerine pozitif ekleme hareketi INSERT
  -- gerçekçi olarak: stok hareketinde tur='Ekleme' ile pozitif miktar
  INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
  VALUES (v_hareket_id, p_stok_id, 'Ekleme', p_miktar,
    COALESCE(p_notlar, 'Manuel ekleme'), false);

  INSERT INTO public.islem_log (tip, snapshot, kullanici_notu)
  VALUES ('STOK_EKLEME', jsonb_build_object(
    'olusturulan', jsonb_build_array(jsonb_build_object(
      'tablo', 'stok_hareket', 'id', v_hareket_id,
      'veri', jsonb_build_object('stok_id', p_stok_id, 'tur', 'Ekleme', 'miktar', p_miktar, 'notlar', p_notlar)
    ))
  ), 'Stok ekleme: +' || p_miktar || ' (' || COALESCE(p_notlar, 'manuel') || ')');

  RETURN jsonb_build_object('ok', true, 'stok_id', p_stok_id, 'eklenen', p_miktar);
END;
$$;

GRANT EXECUTE ON FUNCTION public.stok_ekleme(text, numeric, text) TO anon, authenticated;

-- ── A6: GEBELIK KAYDET MANUAL ──────────────────
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
  v_gorev_sayisi integer := 0;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id; END IF;
  IF v_hayvan.durum IS DISTINCT FROM 'Aktif' THEN
    RAISE EXCEPTION 'Hayvan aktif değil (durum: %)', v_hayvan.durum;
  END IF;
  IF v_hayvan.cinsiyet IS DISTINCT FROM 'Dişi' THEN
    RAISE EXCEPTION 'Sadece dişi hayvanlara gebelik kaydedilebilir';
  END IF;
  IF p_tarih > CURRENT_DATE THEN
    RAISE EXCEPTION 'İleri tarih girilemez: %', p_tarih;
  END IF;
  IF EXISTS (SELECT 1 FROM public.tohumlama WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe' AND iptal = false) THEN
    RAISE EXCEPTION 'Hayvanın aktif gebeliği bulunuyor';
  END IF;

  v_tohumlama_id := gen_random_uuid()::text;

  INSERT INTO public.tohumlama (id, hayvan_id, tarih, sperma, sonuc, deneme_no)
  VALUES (v_tohumlama_id, p_hayvan_id, p_tarih, p_sperma, 'Gebe', 1);

  v_snapshot := jsonb_build_object(
    'olusturulan', jsonb_build_array(jsonb_build_object(
      'tablo', 'tohumlama', 'id', v_tohumlama_id,
      'veri', jsonb_build_object(
        'hayvan_id', p_hayvan_id, 'tarih', p_tarih,
        'sperma', p_sperma, 'sonuc', 'Gebe', 'deneme_no', 1
      )
    ))
  );

  INSERT INTO public.islem_log (tip, ana_hayvan_id, snapshot, kullanici_notu)
  VALUES ('GEBELIK_MANUEL', p_hayvan_id, v_snapshot,
    format('Manuel gebelik kaydı (tarih: %s, sperma: %s)', p_tarih, COALESCE(p_sperma, '-')));

  RETURN jsonb_build_object('ok', true, 'tohumlama_id', v_tohumlama_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.gebelik_kaydet_manual(text, date, text) TO anon, authenticated;

-- ── RPC_TABLES mapping ──────────────────────────
-- Bu mapping'ler api.js RPC_TABLES için referanstır:
-- buzagi_sutten_kesme_onayla: ['hayvanlar']
-- hayvan_tohumlanabilir_onayla: ['hayvanlar']
-- hayvan_tohumlama_ertele: ['hayvanlar']
-- gorev_tamamla: ['gorev_log', 'stok_hareket', 'hayvanlar']
-- stok_hareket_ekle: ['stok_hareket']
-- stok_ekle: ['stok', 'stok_hareket']
-- stok_ekleme: ['stok_hareket']
-- gebelik_kaydet_manual: ['tohumlama']
