-- Migration: Faz 1 — RPC Bypass Düzeltmeleri (v3)
-- A1-A6 + Phantom RPC'ler
-- Tarih: 2026-05-16 (CRITICAL: +B1-B10)
-- Review fix'leri: C1-C4, H2-H3, M1-M3
-- Deploy fix: uuid/text cast, eski overload DROP

BEGIN;

-- Eski overload'lari temizle (Faz 3 ilk implementasyondan kalan)
DROP FUNCTION IF EXISTS public.hekim_ekle(text, text, text);
DROP FUNCTION IF EXISTS public.hekim_guncelle(uuid, text, text, text, boolean);
DROP FUNCTION IF EXISTS public.padok_ekle(text, text, integer);
DROP FUNCTION IF EXISTS public.padok_guncelle(uuid, text, text, integer, boolean);
DROP FUNCTION IF EXISTS public.grup_padok_eslem_toggle(text, text, uuid);

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
    'olusturulan', '[]'::jsonb,
    'guncellenen', jsonb_build_array(jsonb_build_object(
      'tablo', 'hayvanlar', 'id', p_hayvan_id,
      'onceki', jsonb_build_object('suttten_kesme_tarihi', v_hayvan.suttten_kesme_tarihi),
      'sonraki', jsonb_build_object('suttten_kesme_tarihi', CURRENT_DATE)
    )),
    'silinen', '[]'::jsonb
  );

  UPDATE public.hayvanlar SET suttten_kesme_tarihi = CURRENT_DATE WHERE id = p_hayvan_id;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('SUTEN_KESME', p_hayvan_id, p_hayvan_id, 'hayvanlar', v_snapshot, 'Buzağı sütten kesildi');

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
  -- M1: Yaş kontrolü — 12 aydan küçük hayvan tohumlanamaz
  IF v_hayvan.dogum_tarihi IS NOT NULL AND (CURRENT_DATE - v_hayvan.dogum_tarihi) < 365 THEN
    RAISE EXCEPTION 'Hayvan 12 aydan küçük — tohumlanabilir olarak işaretlenemez (yaş: % gün)',
      CURRENT_DATE - v_hayvan.dogum_tarihi;
  END IF;

  v_snapshot := jsonb_build_object(
    'olusturulan', '[]'::jsonb,
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
    )),
    'silinen', '[]'::jsonb
  );

  UPDATE public.hayvanlar SET
    tohumlama_durumu = 'tohumlanabilir',
    tohumlama_onay_tarihi = CURRENT_DATE
  WHERE id = p_hayvan_id;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('TOHUMLAMA_DURUMU_ONAYLA', p_hayvan_id, p_hayvan_id, 'hayvanlar', v_snapshot, 'Tohumlanabilir olarak onaylandı');

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

  -- M2: PostgreSQL interval kullan — doğru ay hesabı
  v_hedef_tarih := (CURRENT_DATE + (p_ay || ' months')::interval)::date;

  v_snapshot := jsonb_build_object(
    'olusturulan', '[]'::jsonb,
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
    )),
    'silinen', '[]'::jsonb
  );

  UPDATE public.hayvanlar SET
    tohumlama_durumu = 'ertelendi',
    tohumlama_onay_tarihi = v_hedef_tarih
  WHERE id = p_hayvan_id;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('TOHUMLAMA_ERTELE', p_hayvan_id, p_hayvan_id, 'hayvanlar', v_snapshot,
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
  SELECT * INTO v_gorev FROM public.gorev_log WHERE id = p_gorev_id::uuid;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Görev bulunamadı: %', p_gorev_id;
  END IF;
  IF v_gorev.tamamlandi THEN
    RETURN jsonb_build_object('ok', true, 'mesaj', 'Görev zaten tamamlanmış');
  END IF;
  -- H2: İptal edilmiş görev tamamlanamaz
  IF v_gorev.iptal THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev iptal edilmiş, tamamlanamaz');
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
  WHERE id = p_gorev_id::uuid;

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
    'guncellenen', v_guncellenen,
    'silinen', '[]'::jsonb
  );

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('GOREV_TAMAMLA', v_gorev.hayvan_id, p_gorev_id, 'gorev_log', v_snapshot,
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
  v_id uuid;
BEGIN
  v_id := gen_random_uuid();

  INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
  VALUES (v_id, p_stok_id, p_tur, p_miktar, COALESCE(p_notlar, ''), false);

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('STOK_HAREKET', p_stok_id, 'stok', jsonb_build_object(
    'olusturulan', jsonb_build_array(jsonb_build_object(
      'tablo', 'stok_hareket', 'id', v_id,
      'veri', jsonb_build_object('stok_id', p_stok_id, 'tur', p_tur, 'miktar', p_miktar, 'notlar', p_notlar, 'iptal', false)
    )),
    'guncellenen', '[]'::jsonb,
    'silinen', '[]'::jsonb
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
BEGIN
  v_id := gen_random_uuid()::text;

  INSERT INTO public.stok (id, urun_adi, kategori, birim, baslangic_miktar, esik)
  VALUES (v_id, p_urun_adi, p_kategori, p_birim, p_baslangic_miktar, p_esik);

  -- C2: ÇİFT SAYMA YOK — stok_hareket INSERT yalnızca hareketler için.
  -- stok_tuketim_view guncel_stok = baslangic_miktar - SUM(miktar) hesaplar.
  -- Başlangıç hareketi eklenmez; baslangic_miktar zaten ilk değerdir.

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('STOK_EKLE', v_id, 'stok', jsonb_build_object(
    'olusturulan', jsonb_build_array(jsonb_build_object(
      'tablo', 'stok', 'id', v_id,
      'veri', jsonb_build_object('urun_adi', p_urun_adi, 'kategori', p_kategori, 'birim', p_birim, 'baslangic_miktar', p_baslangic_miktar, 'esik', p_esik)
    )),
    'guncellenen', '[]'::jsonb,
    'silinen', '[]'::jsonb
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
  v_hareket_id uuid;
BEGIN
  IF p_miktar <= 0 THEN
    RAISE EXCEPTION 'Miktar pozitif olmalıdır (%)', p_miktar;
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = p_stok_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Stok kaydı bulunamadı: %', p_stok_id;
  END IF;

  v_hareket_id := gen_random_uuid();

  -- C3: NEGATİF miktar = stok artışı (view: guncel = baslangic - SUM(hareket))
  INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
  VALUES (v_hareket_id, p_stok_id, 'Ekleme', -p_miktar,
    COALESCE(p_notlar, 'Manuel ekleme'), false);

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('STOK_EKLEME', p_stok_id, 'stok', jsonb_build_object(
    'olusturulan', jsonb_build_array(jsonb_build_object(
      'tablo', 'stok_hareket', 'id', v_hareket_id,
      'veri', jsonb_build_object('stok_id', p_stok_id, 'tur', 'Ekleme', 'miktar', -p_miktar, 'notlar', p_notlar)
    )),
    'guncellenen', '[]'::jsonb,
    'silinen', '[]'::jsonb
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
  IF p_tarih > CURRENT_DATE THEN
    RAISE EXCEPTION 'İleri tarih girilemez: %', p_tarih;
  END IF;
  -- C1: tohumlama tablosunda iptal kolonu YOK — sadece sonuc kontrol et
  IF EXISTS (SELECT 1 FROM public.tohumlama WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe') THEN
    RAISE EXCEPTION 'Hayvanın aktif gebeliği bulunuyor';
  END IF;

  v_tohumlama_id := gen_random_uuid()::text;

  -- M3: deneme_no'yu otomatik hesapla (mevcut maks + 1)
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

-- ── B1: STOK GUNCELLE ──────────────────────────
CREATE OR REPLACE FUNCTION public.stok_guncelle(
  p_stok_id text,
  p_urun_adi text DEFAULT NULL,
  p_kategori text DEFAULT NULL,
  p_birim text DEFAULT NULL,
  p_esik numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok record;
  v_onceki jsonb;
  v_sonraki jsonb;
BEGIN
  SELECT * INTO v_stok FROM public.stok WHERE id = p_stok_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Stok bulunamadı: %', p_stok_id; END IF;

  v_onceki := row_to_json(v_stok)::jsonb;
  v_sonraki := v_onceki;

  UPDATE public.stok SET
    urun_adi = COALESCE(NULLIF(p_urun_adi, ''), urun_adi),
    kategori = COALESCE(NULLIF(p_kategori, ''), kategori),
    birim    = COALESCE(NULLIF(p_birim, ''), birim),
    esik     = COALESCE(p_esik, esik)
  WHERE id = p_stok_id;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('STOK_GUNCELLE', p_stok_id, 'stok', jsonb_build_object(
    'olusturulan', '[]'::jsonb,
    'guncellenen', jsonb_build_array(jsonb_build_object(
      'tablo', 'stok', 'id', p_stok_id,
      'onceki', v_onceki,
      'sonraki', (SELECT row_to_json(stok)::jsonb FROM public.stok WHERE id = p_stok_id)
    )),
    'silinen', '[]'::jsonb
  ), 'Stok güncellendi: ' || COALESCE(p_urun_adi, (SELECT urun_adi FROM public.stok WHERE id = p_stok_id)));

  RETURN jsonb_build_object('ok', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.stok_guncelle(text,text,text,text,numeric) TO anon, authenticated;

-- ── B2: STOK ARSIVLE ───────────────────────────
CREATE OR REPLACE FUNCTION public.stok_arsivle(p_stok_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_stok record;
BEGIN
  SELECT * INTO v_stok FROM public.stok WHERE id = p_stok_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Stok bulunamadı: %', p_stok_id; END IF;

  UPDATE public.stok SET kategori = 'Arşiv' WHERE id = p_stok_id;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('STOK_ARSIVLE', p_stok_id, 'stok', jsonb_build_object(
    'olusturulan', '[]'::jsonb,
    'guncellenen', jsonb_build_array(jsonb_build_object(
      'tablo', 'stok', 'id', p_stok_id,
      'onceki', jsonb_build_object('kategori', v_stok.kategori),
      'sonraki', jsonb_build_object('kategori', 'Arşiv')
    )),
    'silinen', '[]'::jsonb
  ), 'Stok arşivlendi: ' || v_stok.urun_adi);

  RETURN jsonb_build_object('ok', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.stok_arsivle(text) TO anon, authenticated;

-- ── B3: VACCINE RAPEL GUNCELLE ────────────────
CREATE OR REPLACE FUNCTION public.vaccine_rapel_guncelle(p_vaccine_id uuid, p_repeat_days integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_vac record;
BEGIN
  IF p_repeat_days IS NOT NULL AND p_repeat_days <= 0 THEN RAISE EXCEPTION 'Rapel süresi pozitif olmalıdır'; END IF;
  SELECT * INTO v_vac FROM public.vaccines WHERE id = p_vaccine_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Aşı bulunamadı'; END IF;

  UPDATE public.vaccines SET repeat_interval_days = p_repeat_days WHERE id = p_vaccine_id;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('VACCINE_RAPEL', p_vaccine_id::text, 'vaccines', jsonb_build_object(
    'olusturulan', '[]'::jsonb,
    'guncellenen', jsonb_build_array(jsonb_build_object(
      'tablo', 'vaccines', 'id', p_vaccine_id,
      'onceki', jsonb_build_object('repeat_interval_days', v_vac.repeat_interval_days),
      'sonraki', jsonb_build_object('repeat_interval_days', p_repeat_days)
    )),
    'silinen', '[]'::jsonb
  ), 'Aşı rapel süresi güncellendi: ' || COALESCE(v_vac.name, v_vac.id::text));

  RETURN jsonb_build_object('ok', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.vaccine_rapel_guncelle(uuid,integer) TO anon, authenticated;

-- ── B4: HEKIM EKLE ─────────────────────────────
CREATE OR REPLACE FUNCTION public.hekim_ekle(
  p_ad text, p_telefon text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id text;
BEGIN
  IF NULLIF(p_ad, '') IS NULL THEN RAISE EXCEPTION 'Hekim adı zorunlu'; END IF;
  v_id := 'H' || extract(epoch from now())::bigint::text;

  INSERT INTO public.hekimler (id, ad, telefon, aktif)
  VALUES (v_id, p_ad, p_telefon, true);

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('HEKIM_EKLE', v_id, 'hekimler', jsonb_build_object(
    'olusturulan', jsonb_build_array(jsonb_build_object(
      'tablo', 'hekimler', 'id', v_id,
      'veri', jsonb_build_object('ad', p_ad, 'telefon', p_telefon)
    )),
    'guncellenen', '[]'::jsonb,
    'silinen', '[]'::jsonb
  ), 'Yeni hekim: ' || p_ad);

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.hekim_ekle(text,text) TO anon, authenticated;

-- ── B5: HEKIM GUNCELLE ─────────────────────────
CREATE OR REPLACE FUNCTION public.hekim_guncelle(
  p_hekim_id text, p_ad text DEFAULT NULL, p_telefon text DEFAULT NULL,
  p_aktif boolean DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_hekim record;
BEGIN
  SELECT * INTO v_hekim FROM public.hekimler WHERE id = p_hekim_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Hekim bulunamadı'; END IF;

  UPDATE public.hekimler SET
    ad     = COALESCE(NULLIF(p_ad, ''), ad),
    telefon = COALESCE(NULLIF(p_telefon, ''), telefon),
    aktif  = COALESCE(p_aktif, aktif)
  WHERE id = p_hekim_id;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('HEKIM_GUNCELLE', p_hekim_id, 'hekimler', jsonb_build_object(
    'olusturulan', '[]'::jsonb,
    'guncellenen', jsonb_build_array(jsonb_build_object(
      'tablo', 'hekimler', 'id', p_hekim_id,
      'onceki', row_to_json(v_hekim)::jsonb,
      'sonraki', (SELECT row_to_json(hekimler)::jsonb FROM public.hekimler WHERE id = p_hekim_id)
    )),
    'silinen', '[]'::jsonb
  ), 'Hekim güncellendi: ' || COALESCE(p_ad, v_hekim.ad));

  RETURN jsonb_build_object('ok', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.hekim_guncelle(text,text,text,boolean) TO anon, authenticated;

-- ── B6: PADOK EKLE ─────────────────────────────
CREATE OR REPLACE FUNCTION public.padok_ekle(
  p_ad text, p_kapasite integer DEFAULT NULL, p_sira integer DEFAULT 0
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id uuid;
BEGIN
  IF NULLIF(p_ad, '') IS NULL THEN RAISE EXCEPTION 'Padok adı zorunlu'; END IF;
  v_id := gen_random_uuid();

  INSERT INTO public.padoklar (id, ad, kapasite, sira, aktif)
  VALUES (v_id, p_ad, p_kapasite, p_sira, true);

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('PADOK_EKLE', v_id::text, 'padoklar', jsonb_build_object(
    'olusturulan', jsonb_build_array(jsonb_build_object(
      'tablo', 'padoklar', 'id', v_id,
      'veri', jsonb_build_object('ad', p_ad, 'kapasite', p_kapasite, 'sira', p_sira)
    )),
    'guncellenen', '[]'::jsonb,
    'silinen', '[]'::jsonb
  ), 'Yeni padok: ' || p_ad);

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.padok_ekle(text,integer,integer) TO anon, authenticated;

-- ── B7: PADOK GUNCELLE ─────────────────────────
CREATE OR REPLACE FUNCTION public.padok_guncelle(
  p_padok_id uuid, p_ad text DEFAULT NULL, p_kapasite integer DEFAULT NULL,
  p_sira integer DEFAULT NULL, p_aktif boolean DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_padok record;
BEGIN
  SELECT * INTO v_padok FROM public.padoklar WHERE id = p_padok_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Padok bulunamadı'; END IF;

  UPDATE public.padoklar SET
    ad   = COALESCE(NULLIF(p_ad, ''), ad),
    kapasite = COALESCE(p_kapasite, kapasite),
    sira = COALESCE(p_sira, sira),
    aktif = COALESCE(p_aktif, aktif)
  WHERE id = p_padok_id;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('PADOK_GUNCELLE', p_padok_id::text, 'padoklar', jsonb_build_object(
    'olusturulan', '[]'::jsonb,
    'guncellenen', jsonb_build_array(jsonb_build_object(
      'tablo', 'padoklar', 'id', p_padok_id,
      'onceki', row_to_json(v_padok)::jsonb,
      'sonraki', (SELECT row_to_json(padoklar)::jsonb FROM public.padoklar WHERE id = p_padok_id)
    )),
    'silinen', '[]'::jsonb
  ), 'Padok güncellendi: ' || COALESCE(p_ad, v_padok.ad));

  RETURN jsonb_build_object('ok', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.padok_guncelle(uuid,text,integer,integer,boolean) TO anon, authenticated;

-- ── B8: PADOK SIL ──────────────────────────────
CREATE OR REPLACE FUNCTION public.padok_sil(p_padok_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_padok record;
BEGIN
  SELECT * INTO v_padok FROM public.padoklar WHERE id = p_padok_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Padok bulunamadı'; END IF;

  IF EXISTS (SELECT 1 FROM public.hayvanlar WHERE padok_id = p_padok_id AND durum = 'Aktif') THEN
    RAISE EXCEPTION 'Padokta aktif hayvan var, silinemez';
  END IF;

  DELETE FROM public.grup_padok_eslem WHERE padok_id = p_padok_id;
  DELETE FROM public.padoklar WHERE id = p_padok_id;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('PADOK_SIL', p_padok_id::text, 'padoklar', jsonb_build_object(
    'olusturulan', '[]'::jsonb,
    'guncellenen', '[]'::jsonb,
    'silinen', jsonb_build_array(jsonb_build_object(
      'tablo', 'padoklar', 'id', p_padok_id,
      'veri', row_to_json(v_padok)::jsonb
    ))
  ), 'Padok silindi: ' || v_padok.ad);

  RETURN jsonb_build_object('ok', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.padok_sil(uuid) TO anon, authenticated;

-- ── B9: GRUP PADOK ESLEM TOGGLE ───────────────
CREATE OR REPLACE FUNCTION public.grup_padok_eslem_toggle(p_grup_adi text, p_padok_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.grup_padok_eslem WHERE grup = p_grup_adi AND padok_id = p_padok_id) THEN
    DELETE FROM public.grup_padok_eslem WHERE grup = p_grup_adi AND padok_id = p_padok_id;
    RETURN jsonb_build_object('ok', true, 'durum', 'silindi');
  ELSE
    INSERT INTO public.grup_padok_eslem (grup, padok_id)
    VALUES (p_grup_adi, p_padok_id);
    RETURN jsonb_build_object('ok', true, 'durum', 'eklendi');
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.grup_padok_eslem_toggle(text,uuid) TO anon, authenticated;

COMMIT;
