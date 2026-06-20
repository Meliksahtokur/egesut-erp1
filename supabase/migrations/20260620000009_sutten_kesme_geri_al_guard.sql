-- buzagi_sutten_kesme_geri_al: geri alma koşulları (FE ile birebir)
-- grup buzağı + kesimden ≤15 gün + (dogum yok VEYA yaş≤180g) + tohumlama kaydı yok
BEGIN;

CREATE OR REPLACE FUNCTION public.buzagi_sutten_kesme_geri_al(p_hayvan_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_log record; v_onceki jsonb; v_h record;
BEGIN
  SELECT * INTO v_h FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id; END IF;
  IF v_h.suttten_kesme_tarihi IS NULL THEN
    RAISE EXCEPTION 'Hayvan sütten kesilmemiş'; END IF;
  IF v_h.grup IS NULL OR v_h.grup NOT ILIKE '%Buzağı%' THEN
    RAISE EXCEPTION 'Sadece buzağı grubunda geri alınabilir (grup: %)', v_h.grup; END IF;
  IF (CURRENT_DATE - v_h.suttten_kesme_tarihi) > 15 THEN
    RAISE EXCEPTION 'Kesimden 15 günden fazla geçti (% gün) — geri alınamaz', (CURRENT_DATE - v_h.suttten_kesme_tarihi); END IF;
  IF v_h.dogum_tarihi IS NOT NULL AND (CURRENT_DATE - v_h.dogum_tarihi) > 180 THEN
    RAISE EXCEPTION '6 aylıktan büyük (% gün) — geri alınamaz', (CURRENT_DATE - v_h.dogum_tarihi); END IF;
  IF EXISTS (SELECT 1 FROM public.tohumlama WHERE hayvan_id = p_hayvan_id) THEN
    RAISE EXCEPTION 'Tohumlama kaydı olan hayvanda geri alınamaz'; END IF;

  SELECT * INTO v_log FROM public.islem_log
   WHERE tip='SUTEN_KESME' AND ana_hayvan_id=p_hayvan_id AND durum='aktif'
   ORDER BY tarih DESC LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'Sütten kesim kaydı bulunamadı: %', p_hayvan_id; END IF;
  v_onceki := v_log.snapshot->'guncellenen'->0->'onceki';
  UPDATE public.hayvanlar
     SET suttten_kesme_tarihi = NULL,
         grup     = COALESCE(v_onceki->>'grup', grup),
         padok    = COALESCE(v_onceki->>'padok', padok),
         padok_id = COALESCE((v_onceki->>'padok_id')::uuid, padok_id)
   WHERE id = p_hayvan_id;
  UPDATE public.islem_log SET durum='geri_alindi', geri_alma_tarihi=now() WHERE id=v_log.id;
  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('SUTTEN_KESME_GERI_AL', p_hayvan_id, p_hayvan_id, 'hayvanlar',
    jsonb_build_object('olusturulan','[]'::jsonb,'silinen','[]'::jsonb,
      'guncellenen', jsonb_build_array(jsonb_build_object('tablo','hayvanlar','id',p_hayvan_id,'geri_alinan_log',v_log.id))),
    'Sütten kesim geri alındı');
  RETURN jsonb_build_object('ok', true, 'hayvan_id', p_hayvan_id);
END; $$;

GRANT EXECUTE ON FUNCTION public.buzagi_sutten_kesme_geri_al(text) TO anon, authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
