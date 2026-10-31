-- Migration: Muayene sonucundan vakaya bağ
-- Tarih: 2026-10-31. Kaynak: sahip kararı ("muayene tedavi planı ile kapanmıyor oraya bağlanamıyor"), domain-rules §20.5-7. Önceki migration: 20261031200004.
-- BEGIN/COMMIT yok: runbook ve test sarmalayıcısı dışarıdan sarar. Prod apply sahip kapısındadır.
-- Kilit sırası ve ret kodları hayvan_takip_muayene_sonuc ile aynı; ek olarak HT_VAKA_UYUMSUZ.
-- Vaka aktifliği: cases.status = 'active' (_vaka_ac_tek tanımı; CHECK yalnız active|closed).
-- ROLLBACK: DROP FUNCTION public.hayvan_takip_muayene_vaka(uuid, uuid, text); islem_log satırları kalır.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- Sıra zorunlu: görev önce tamamlanır, yoksa _hayvan_takip_kapat_ic açık görevi iptal eder.
CREATE FUNCTION public.hayvan_takip_muayene_vaka(p_gorev_id uuid, p_case_id uuid, p_not text DEFAULT NULL)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_gorev public.gorev_log%ROWTYPE;
  v_takip public.hayvan_takip%ROWTYPE;
  v_kullanici text := public._hayvan_takip_kullanici();
  v_kapandi boolean;
BEGIN
  SELECT * INTO v_gorev FROM public.gorev_log WHERE id = p_gorev_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'HT_GOREV_YOK';
  END IF;
  IF v_gorev.gorev_tipi IS DISTINCT FROM 'HAYVAN_TAKIP_MUAYENE' THEN
    RAISE EXCEPTION 'HT_GOREV_TIP_UYUMSUZ';
  END IF;
  IF v_gorev.ref_takip_id IS NULL THEN
    RAISE EXCEPTION 'HT_TAKIP_YOK';
  END IF;

  PERFORM 1 FROM public.hayvanlar
    WHERE id = (SELECT t.hayvan_id FROM public.hayvan_takip t WHERE t.id = v_gorev.ref_takip_id)
    FOR UPDATE;
  SELECT * INTO v_takip FROM public.hayvan_takip WHERE id = v_gorev.ref_takip_id FOR UPDATE;
  SELECT * INTO v_gorev FROM public.gorev_log WHERE id = p_gorev_id FOR UPDATE;

  IF v_gorev.tamamlandi IS TRUE OR v_gorev.iptal IS TRUE THEN
    RAISE EXCEPTION 'HT_GOREV_KAPALI';
  END IF;
  IF v_takip.kapanis_tarihi IS NOT NULL THEN
    RAISE EXCEPTION 'HT_TAKIP_KAPALI';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.cases c
                  WHERE c.id = p_case_id AND c.animal_id = v_takip.hayvan_id AND c.status = 'active') THEN
    RAISE EXCEPTION 'HT_VAKA_UYUMSUZ';
  END IF;

  UPDATE public.gorev_log SET tamamlandi = true, tamamlanma_tarihi = now() WHERE id = p_gorev_id;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('HAYVAN_TAKIP_MUAYENE', v_takip.hayvan_id, v_takip.id::text, 'hayvan_takip',
          jsonb_build_object('sebep_kodu', v_takip.sebep_kodu, 'aciklama', v_takip.aciklama, 'sonuc', 'VAKA',
                             'gorev_id', p_gorev_id, 'kullanici', v_kullanici, 'kapatan_vaka_id', p_case_id),
          p_not);

  v_kapandi := public._hayvan_takip_kapat_ic(v_takip.id, 'VAKA', v_kullanici, p_not, p_case_id);

  RETURN jsonb_build_object('ok', true, 'sonuc', 'VAKA', 'takip_id', v_takip.id, 'case_id', p_case_id, 'kapandi', v_kapandi);
END;
$function$;

-- Supabase default privilege'i authenticated ve service_role'e EXECUTE verir; REVOKE bu yüzden onları da kapsar.
REVOKE ALL ON FUNCTION public.hayvan_takip_muayene_vaka(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.hayvan_takip_muayene_vaka(uuid, uuid, text) TO authenticated, service_role;
