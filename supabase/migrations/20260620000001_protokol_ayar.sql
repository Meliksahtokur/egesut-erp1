-- Protokol Ayar — UI'dan yönetilen protokol eşikleri (config tablosu, DDL değil)
BEGIN;

CREATE TABLE IF NOT EXISTS public.protokol_ayar (
  anahtar     text PRIMARY KEY,
  deger       numeric NOT NULL,
  birim       text DEFAULT 'gün',
  min_deger   numeric,
  max_deger   numeric,
  aciklama    text,
  guncellendi timestamptz DEFAULT now()
);

ALTER TABLE public.protokol_ayar ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS protokol_ayar_all ON public.protokol_ayar;
CREATE POLICY protokol_ayar_all ON public.protokol_ayar FOR ALL USING (true) WITH CHECK (true);

INSERT INTO public.protokol_ayar(anahtar, deger, min_deger, max_deger, aciklama) VALUES
  ('sutten_kesme_gun',          60, 20, 200, 'Otomatik sütten kesme alarmı eşiği (gün)'),
  ('sutten_kesme_gecikme_gun',  75, 30, 250, 'Bu günden sonra görev "GECİKMİŞ" vurgulanır'),
  ('sutten_kesme_erken_uyari',  40, 0,  120, 'SERT ALT SINIR: kesim yaşı bu günün altında ise DB reddeder'),
  ('besleme_baslangic_gun',    260, 200, 285, 'Anyonik besleme başlangıcı (gebelik günü)'),
  ('kuru_donem_gun',           210, 180, 285, 'Kuru döneme transfer (gebelik günü)'),
  ('ileri_gebe_asi1_gun',      240, 200, 285, 'Rota-Corona 1. doz (gebelik günü)'),
  ('ileri_gebe_asi2_gun',      261, 200, 285, 'Rota-Corona 2. doz düve (gebelik günü)'),
  ('ileri_gebe_ademin_gun',    260, 200, 285, 'SC Ademin (gebelik günü)'),
  ('ileri_gebe_evit_gun',      265, 200, 285, 'IM E Vitamini (gebelik günü)')
ON CONFLICT (anahtar) DO NOTHING;

-- Helper: config oku, yoksa varsayılan (mantık geriye uyumlu)
CREATE OR REPLACE FUNCTION public._ayar(p_anahtar text, p_varsayilan numeric)
RETURNS numeric LANGUAGE sql STABLE AS $$
  SELECT COALESCE((SELECT deger FROM public.protokol_ayar WHERE anahtar = p_anahtar), p_varsayilan);
$$;

-- RPC: ayar güncelle (min/max doğrulama + audit)
CREATE OR REPLACE FUNCTION public.protokol_ayar_guncelle(p_anahtar text, p_deger numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_row record;
BEGIN
  SELECT * INTO v_row FROM public.protokol_ayar WHERE anahtar = p_anahtar;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bilinmeyen ayar: %', p_anahtar; END IF;
  IF v_row.min_deger IS NOT NULL AND p_deger < v_row.min_deger THEN
    RAISE EXCEPTION 'Değer çok küçük: % (min %)', p_deger, v_row.min_deger; END IF;
  IF v_row.max_deger IS NOT NULL AND p_deger > v_row.max_deger THEN
    RAISE EXCEPTION 'Değer çok büyük: % (max %)', p_deger, v_row.max_deger; END IF;
  UPDATE public.protokol_ayar SET deger = p_deger, guncellendi = now() WHERE anahtar = p_anahtar;
  INSERT INTO public.islem_log (tip, ref_tablo, snapshot, kullanici_notu)
  VALUES ('PROTOKOL_AYAR', 'protokol_ayar',
    jsonb_build_object('olusturulan','[]'::jsonb,'silinen','[]'::jsonb,
      'guncellenen', jsonb_build_array(jsonb_build_object(
        'tablo','protokol_ayar','id',p_anahtar,
        'onceki', jsonb_build_object('deger', v_row.deger),
        'sonraki', jsonb_build_object('deger', p_deger)))),
    'Protokol ayarı: ' || p_anahtar);
  RETURN jsonb_build_object('ok', true, 'anahtar', p_anahtar, 'deger', p_deger);
END; $$;

GRANT EXECUTE ON FUNCTION public._ayar(text, numeric) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.protokol_ayar_guncelle(text, numeric) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
