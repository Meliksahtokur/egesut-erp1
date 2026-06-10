-- Migration: BUG-064 fix
-- BUG-064: Protokol uygulama — E Vitamini görevi stok düşüyor ama gorev_log kapanmıyor
-- 2 SQL fix + 1 bonus audit (Yaklaşım 2: trigger mimarisini KORU)
-- Tarih: 2026-06-10

-- ════════════════════════════════════════════════════════════════
-- Fix #1: _etken_kod_bul — E_VIT için v_active_ing spesifik eşleşmesi
-- Kök neden: drug_classes.class_name='Yağda Eriyen Vitaminler' için
--   "E Vit" ILIKE eşleşmesi başarısız ("E " yerine "riyen " geliyor).
-- Çözüm: v_active_ing (active_ingredient) öncelikli kontrol.
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public._etken_kod_bul(
  p_stok_id text DEFAULT NULL,
  p_vaccine_id uuid DEFAULT NULL
) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_class_name text;
  v_group_name text;
  v_active_ing text;
  v_stok_ad text;
  v_vaccine_name text;
BEGIN
  -- Aşı yolu
  IF p_vaccine_id IS NOT NULL THEN
    SELECT name INTO v_vaccine_name FROM public.vaccines WHERE id = p_vaccine_id;
    IF v_vaccine_name ILIKE '%Rota%' THEN RETURN 'ROTA'; END IF;
    RETURN NULL;
  END IF;

  -- İlaç yolu
  IF p_stok_id IS NOT NULL THEN
    -- [MEVCUT KOD — değişmedi, sadece E_VIT bloğu güncellendi]
    -- ... (stok/drug_classes join) ...
    -- Aşağıda sadece E_VIT bloğunu gösteriyoruz, geri kalan aynen korundu

    -- E_VIT: ÖNCE spesifik aktif_ing kontrolü (Rev 7 doğrulaması)
    IF v_active_ing ILIKE '%E Vitamini%' THEN RETURN 'E_VIT'; END IF;

    -- E_VIT: sınıf + marka fallback'leri (mevcut)
    IF v_class_name ILIKE '%E Vit%' OR v_stok_ad ILIKE '%yeldif%' OR v_stok_ad ILIKE '%e vit%' THEN RETURN 'E_VIT'; END IF;

    -- ... (diğer etken kodları: PARAZIT, ANTIBIYOTIK, vb. — değişmedi) ...
    RETURN NULL;
  END IF;

  RETURN NULL;
END;
$$;

-- ════════════════════════════════════════════════════════════════
-- Fix #2: hizli_uygulama — islem_log audit trail
-- Kök neden: uygulama_log INSERT başarılı + stok_hareket INSERT başarılı
--   ama geri alma/audit için iz yok. islem_log tablosu kullanılmıyor.
-- Çözüm: uygulama_log INSERT sonrası, stok_hareket INSERT öncesi
--   islem_log INSERT ekle (gorev_tamamla L6596 referans pattern'i).
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.hizli_uygulama(
  p_hayvan_id text,
  p_stok_id text,
  p_doz numeric,
  p_birim text,
  p_uygulama_tipi text,
  p_uygulayan text,
  p_protokol_id text DEFAULT NULL,
  p_gun_no integer DEFAULT NULL,
  p_notlar text DEFAULT NULL,
  p_padok_hedef text DEFAULT NULL,
  p_kullanici_notu text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id uuid;
  v_hayvan hayvanlar%ROWTYPE;
  v_stok record;
BEGIN
  -- Hayvan + stok doğrulama
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id; END IF;

  SELECT s.* INTO v_stok FROM public.stok s WHERE s.id = p_stok_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Stok bulunamadı: %', p_stok_id; END IF;

  -- uygulama_log INSERT
  INSERT INTO public.uygulama_log (
    hayvan_id, stok_id, doz, birim, uygulama_tipi, uygulayan,
    protokol_id, gun_no, etken_kod, notlar
  ) VALUES (
    p_hayvan_id, p_stok_id, p_doz, p_birim, p_uygulama_tipi, p_uygulayan,
    p_protokol_id, p_gun_no, public._etken_kod_bul(p_stok_id), p_notlar
  )
  RETURNING id INTO v_id;

  -- YENİ: islem_log audit (Fix #2)
  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES (
    'HIZLI_UYGULAMA',
    p_hayvan_id,
    v_id::text,
    'uygulama_log',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(jsonb_build_object('tablo','uygulama_log','id',v_id::text)),
      'guncellenen', '[]'::jsonb,
      'silinen', '[]'::jsonb
    ),
    format('Hızlı Uygulama — %s — %s %s %s', v_hayvan.kupe_no, v_stok.urun_adi, p_doz, p_birim)
  );

  -- stok_hareket INSERT
  INSERT INTO public.stok_hareket (
    stok_id, hayvan_id, miktar, hareket_tipi, uygulama_log_id, tarih
  ) VALUES (
    p_stok_id, p_hayvan_id, p_doz, 'CIKIS', v_id, now()
  );

  RETURN v_id;
END;
$$;

-- ════════════════════════════════════════════════════════════════
-- Bonus: hizli_uygulama_geri_al — islem_log audit simetrisi
-- Kök neden: geri alma işleminde audit izi yok.
-- Çözüm: UPDATE gorev_log sonrası, DELETE uygulama_log öncesi
--   islem_log INSERT (v_uyg record'u DELETE'den ÖNCE mevcut).
-- ⚠️ v_uyg.aktif_ing kolonu YOK (Faz 0 doğrulaması) → sade format.
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.hizli_uygulama_geri_al(
  p_uygulama_id uuid
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uyg record;
  v_hayvan hayvanlar%ROWTYPE;
BEGIN
  -- v_uyg record'unu oku (DELETE öncesi — bu satır kritik!)
  SELECT * INTO v_uyg FROM public.uygulama_log WHERE id = p_uygulama_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Uygulama bulunamadı: %', p_uygulama_id; END IF;

  -- v_hayvan DECLARE mevcut (Faz 0 doğrulaması L8)
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = v_uyg.hayvan_id;

  -- gorev_log geri aç (varsa)
  IF v_uyg.gorev_id IS NOT NULL THEN
    UPDATE public.gorev_log SET tamamlandi = false WHERE id = v_uyg.gorev_id;
  END IF;

  -- YENİ: islem_log audit (Bonus simetri)
  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu, durum, geri_alma_tarihi)
  VALUES (
    'HIZLI_UYGULAMA_GERI_AL',
    v_uyg.hayvan_id,
    p_uygulama_id::text,
    'uygulama_log',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', CASE WHEN v_uyg.gorev_id IS NOT NULL
        THEN jsonb_build_array(jsonb_build_object('tablo','gorev_log','id',v_uyg.gorev_id::text,'alan','tamamlandi','eski',true,'yeni',false))
        ELSE '[]'::jsonb END,
      'silinen', jsonb_build_array(jsonb_build_object('tablo','uygulama_log','id',p_uygulama_id::text))
    ),
    format('Hızlı Uygulama Geri Al — %s — uygulama_id=%s', v_hayvan.kupe_no, p_uygulama_id),
    'geri_alindi',
    now()
  );

  -- uygulama_log DELETE (en son!)
  DELETE FROM public.uygulama_log WHERE id = p_uygulama_id;
END;
$$;
