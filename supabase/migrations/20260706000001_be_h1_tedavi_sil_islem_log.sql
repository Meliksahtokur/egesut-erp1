-- BE-H-1 fix: tedavi_sil audit izi eksikti (islem_log INSERT yoktu).
-- Mevcut stok_hareket/stok/tedavi mantığı AYNEN korunuyor, sadece islem_log yazımı ekleniyor.
CREATE OR REPLACE FUNCTION public.tedavi_sil(p_tedavi_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_tedavi  record;
  v_stok    record;
BEGIN
  SELECT * INTO v_tedavi FROM public.tedavi WHERE id::text = p_tedavi_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tedavi kaydı bulunamadı');
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = v_tedavi.ilac_stok_id;

  INSERT INTO public.stok_hareket (
    id, stok_id, tur, miktar, notlar, iptal, referans_tipi, referans_id
  ) VALUES (
    gen_random_uuid(),
    v_tedavi.ilac_stok_id,
    'Tedavi İptal',
    v_tedavi.miktar,
    'Tedavi silindi — ' || COALESCE(v_tedavi.tani, '?'),
    false,
    'tedavi_iptal',
    p_tedavi_id
  );

  UPDATE public.stok SET miktar = miktar + v_tedavi.miktar WHERE id = v_tedavi.ilac_stok_id;

  INSERT INTO public.islem_log (
    tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu, durum
  ) VALUES (
    'TEDAVI_SIL',
    v_tedavi.hayvan_id,
    p_tedavi_id,
    'tedavi',
    jsonb_build_object('silinen', to_jsonb(v_tedavi)),
    format('Tedavi silindi — %s', COALESCE(v_tedavi.tani, '?')),
    'aktif'
  );

  DELETE FROM public.tedavi WHERE id::text = p_tedavi_id;

  RETURN jsonb_build_object('ok', true);
END;
$function$;

-- BE-H-4 fix: drug_administration_stok_dusum hiçbir trigger'a bağlı değil (dead code,
-- pg_depend ile 0 gerçek bağımlılık doğrulandı) ama authenticated role'e EXECUTE açıktı
-- (SECURITY DEFINER + public + client-callable attack surface). DROP değil REVOKE —
-- fonksiyon iz olarak kalır, çağrılabilirlik kapanır.
REVOKE EXECUTE ON FUNCTION public.drug_administration_stok_dusum() FROM authenticated;
