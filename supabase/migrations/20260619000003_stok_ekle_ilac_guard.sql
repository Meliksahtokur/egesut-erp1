-- ─────────────────────────────────────────────────────────────
-- stok_ekle: ilaç kategorisinde katalog zorunluluğu (DB seviyesi)
--
-- TASARIM KURALI (A seçeneği): İlaç katalogsuz eklenemez — hem
--   frontend hem DB seviyesinde. stok_ekle artık ilaç kategorisi
--   (stok_kategorileri.tip = 'ilac') için insert'i reddeder;
--   ilaçlar yalnızca ilac_ekle (etken madde/drug_class zorunlu) ile
--   eklenebilir. Böylece UI dışı bir yol (agent/script) bile
--   katalogsuz ilaç stoğu yaratamaz.
--
-- Güvenli: stok_ekle çağıranlar = forms.js (artık sadece ilaç-dışı)
--   ve Sperma ekleme. Hiçbiri ilaç kategorisi göndermez.
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.stok_ekle(
  p_urun_adi text,
  p_kategori text,
  p_birim text,
  p_baslangic_miktar numeric,
  p_esik numeric DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $function$
DECLARE
  v_id text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.stok_kategorileri WHERE ad = p_kategori) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçersiz kategori: ' || p_kategori);
  END IF;

  -- Katalog zorunlu: ilaç kategorisinde stok yalnızca ilac_ekle ile eklenir.
  IF EXISTS (SELECT 1 FROM public.stok_kategorileri WHERE ad = p_kategori AND tip = 'ilac') THEN
    RAISE EXCEPTION 'İlaç kategorisinde stok kataloglanmadan eklenemez — ilac_ekle kullanın (etken madde zorunlu)';
  END IF;

  v_id := gen_random_uuid()::text;

  INSERT INTO public.stok (id, urun_adi, kategori, birim, baslangic_miktar, esik)
  VALUES (v_id, p_urun_adi, p_kategori, p_birim, p_baslangic_miktar, p_esik);

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
$function$;
