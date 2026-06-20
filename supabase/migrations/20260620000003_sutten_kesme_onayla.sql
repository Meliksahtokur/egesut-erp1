-- Kanonik sütten kesme RPC: tarihi yazar, trigger grup/padok'u doldurur + görev/instance kapatır
BEGIN;

-- Eski tek-param imzayı DROP et (PostgREST overload/PGRST203 önlemi)
DROP FUNCTION IF EXISTS public.buzagi_sutten_kesme_onayla(text);

CREATE OR REPLACE FUNCTION public.buzagi_sutten_kesme_onayla(
  p_hayvan_id text,
  p_tarih date DEFAULT CURRENT_DATE
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_wpadok record;
  v_snapshot jsonb;
  v_min numeric;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id; END IF;
  IF v_hayvan.durum IS DISTINCT FROM 'Aktif' THEN
    RAISE EXCEPTION 'Hayvan aktif değil (durum: %)', v_hayvan.durum; END IF;
  -- idempotency: zaten kesilmişse no-op
  IF v_hayvan.suttten_kesme_tarihi IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'mesaj', 'zaten kesilmiş', 'hayvan_id', p_hayvan_id);
  END IF;
  IF v_hayvan.dogum_tarihi IS NULL THEN
    RAISE EXCEPTION 'Doğum tarihi yok: %', p_hayvan_id; END IF;
  -- tarih doğrulama
  IF p_tarih > CURRENT_DATE THEN RAISE EXCEPTION 'Gelecek tarihe kesim yapılamaz: %', p_tarih; END IF;
  IF p_tarih < v_hayvan.dogum_tarihi THEN RAISE EXCEPTION 'Kesim tarihi doğumdan önce olamaz'; END IF;
  v_min := public._ayar('sutten_kesme_erken_uyari', 40);
  IF (p_tarih - v_hayvan.dogum_tarihi) < v_min THEN
    RAISE EXCEPTION 'Çok erken sütten kesim: % gün (min %)', (p_tarih - v_hayvan.dogum_tarihi), v_min; END IF;

  -- snapshot ÖNCE (undo için grup/padok şart)
  SELECT * INTO v_wpadok FROM public.padoklar WHERE ad ILIKE '%Sütten Kesilmiş%' ORDER BY id LIMIT 1;
  v_snapshot := jsonb_build_object(
    'olusturulan','[]'::jsonb, 'silinen','[]'::jsonb,
    'guncellenen', jsonb_build_array(jsonb_build_object(
      'tablo','hayvanlar','id',p_hayvan_id,
      'onceki', jsonb_build_object('suttten_kesme_tarihi',v_hayvan.suttten_kesme_tarihi,
                                   'grup',v_hayvan.grup,'padok',v_hayvan.padok,'padok_id',v_hayvan.padok_id),
      'sonraki', jsonb_build_object('suttten_kesme_tarihi',p_tarih,
                                    'grup','Sütten Kesilmiş Buzağı','padok',v_wpadok.ad,'padok_id',v_wpadok.id))));

  -- sadece tarihi yaz → BEFORE trigger grup/padok doldurur, AFTER trigger instance/görev kapatır
  UPDATE public.hayvanlar SET suttten_kesme_tarihi = p_tarih WHERE id = p_hayvan_id;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('SUTEN_KESME', p_hayvan_id, p_hayvan_id, 'hayvanlar', v_snapshot, 'Buzağı sütten kesildi');

  RETURN jsonb_build_object('ok', true, 'hayvan_id', p_hayvan_id, 'tarih', p_tarih);
END; $$;

GRANT EXECUTE ON FUNCTION public.buzagi_sutten_kesme_onayla(text, date) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
