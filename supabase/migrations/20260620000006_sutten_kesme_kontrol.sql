-- Sütten kesme alarm tarayıcısı — protokol_instance + config eşik + gecikme vurgusu
-- (Eski PADOK_DEGISIM görev üretimi kaldırıldı; artık SUTTEN_KESME tipinde görev + instance)
BEGIN;

CREATE OR REPLACE FUNCTION public.buzagi_sutten_kesme_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_esik    constant numeric := public._ayar('sutten_kesme_gun', 60);
  v_gecikme constant numeric := public._ayar('sutten_kesme_gecikme_gun', 75);
  v_h record;
  v_gun int;
  v_hedef date;
  v_kaynak text;
  v_inst_id uuid;
  v_aciklama text;
  v_olusturulan int := 0;
  v_sayac int;
BEGIN
  FOR v_h IN
    SELECT * FROM public.hayvanlar
     WHERE durum='Aktif'
       AND suttten_kesme_tarihi IS NULL
       AND dogum_tarihi IS NOT NULL
       AND (CURRENT_DATE - dogum_tarihi) >= v_esik
       AND (grup ILIKE '%Buzağı%' OR (CURRENT_DATE - dogum_tarihi) <= 180)
  LOOP
    v_gun    := CURRENT_DATE - v_h.dogum_tarihi;
    v_hedef  := v_h.dogum_tarihi + v_esik::int;
    v_kaynak := 'SUTTENKES-' || v_h.id;

    INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
    VALUES (v_h.id, 'BAKIM', 'SUTTEN_KESME', v_kaynak, v_hedef, 'aktif')
    ON CONFLICT (kaynak_ref) DO NOTHING;

    SELECT id INTO v_inst_id FROM public.protokol_instance WHERE kaynak_ref = v_kaynak;

    v_aciklama := CASE WHEN v_gun >= v_gecikme
      THEN '⏰ GECİKMİŞ — 🍼 Sütten kesme zamanı (' || v_gun || '. gün)'
      ELSE '🍼 Sütten kesme zamanı (' || v_gun || '. gün)' END;

    INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, protokol_instance_id)
    SELECT gen_random_uuid(), v_h.id, 'SUTTEN_KESME', v_aciklama, v_hedef, false, v_kaynak, v_inst_id
    WHERE NOT EXISTS (
      SELECT 1 FROM public.gorev_log
       WHERE hayvan_id=v_h.id AND gorev_tipi='SUTTEN_KESME' AND iptal=false AND tamamlandi=false);
    GET DIAGNOSTICS v_sayac = ROW_COUNT;
    v_olusturulan := v_olusturulan + v_sayac;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END; $$;

GRANT EXECUTE ON FUNCTION public.buzagi_sutten_kesme_kontrol() TO anon, authenticated;
NOTIFY pgrst, 'reload schema';
COMMIT;
