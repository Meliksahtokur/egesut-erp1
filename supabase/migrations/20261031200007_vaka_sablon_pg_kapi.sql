-- Migration: şablonlu vakada PG kapısı "Boş ata ve uygula" — tek işlemde Boş + seçilen tedavi planı
-- Tarih: 2026-11-05. Kaynak: sahip kararı (domain-rules §18.8), U2-PG raporu. Önceki migration: 20261031200006.
-- BEGIN/COMMIT yok: runbook ve test sarmalayıcısı dışarıdan sarar. Prod apply sahip kapısındadır.
-- Neden: bugünkü kapı yolu (tohumlama_bos_ve_devam PG modu) PG'yi hemen uygular, plan ikinci kez PG yazar (çift PG);
--   tohumlama_sonuc_bos + plan ise Ovsync şablonunda (plan yazılmadan vaka ailesiz) fazladan OVSYNC_BASLAT açar ve atomik değildir (U2-PG M2/M3).
-- 1) _tohumlama_bos_cekirdek: tohumlama_sonuc_bos'un Boş yazım çekirdeği (20260924000001 gövdesi), açık dişi görevi
--    çağıranda (tohumlama_sonuc_bos hemen, yeni RPC plandan sonra).
-- 2) tohumlama_sonuc_bos: yalnız çekirdeği çağıracak şekilde yeniden yazılır; imza, ACL, dönüşler ve yan etki aynı.
--    Önkoşul: canlı gövde 20260924000001 ile birebir (md5 aşağıda); değilse migration durur.
-- 3) tedavi_sablon_bos_ata_uygula: hayvan kilidi (FOR NO KEY UPDATE, 200006 kuralı) → ön koşullar → Boş çekirdeği →
--    tedavi_sablon_uygula (onaysız; kapı Boş sonrası ALLOW verir) → açık dişi görevi. Plandaki PG tek PG'dir.
--    Açık dişi görevi plandan SONRA (root kararı 2026-11-05): _acik_disi_hedef_ic aileli (OVSYNC) vakada görev açmaz,
--    ailesiz şablonda normal Boş yolundaki görevi açar (§18.12 rotası korunur).
--    p_baslangic_tarihi: vaka detayından uygulamada (caseSablonUygula) planın ilk günü; NULL = vaka başlangıcı.
-- ROLLBACK: DROP FUNCTION tedavi_sablon_bos_ata_uygula(uuid, uuid, text, text, date), tohumlama_sonuc_bos'u 20260924000001 gövdesiyle kur, DROP _tohumlama_bos_cekirdek.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $$ BEGIN
  IF NOT COALESCE((SELECT md5(prosrc) FROM pg_catalog.pg_proc WHERE oid = 'public.tohumlama_sonuc_bos(text,text)'::regprocedure)
                  = '33144c237d1749ab79f6a0e968e92a01', false) THEN
    RAISE EXCEPTION 'TOHUMLAMA_SONUC_BOS_GOVDE_FARKLI: canlı gövde 20260924000001 değil, çekirdek ayrımı durdu'; END IF;
END $$;

CREATE FUNCTION public._tohumlama_bos_cekirdek(p_tohumlama_id text, p_gerekce text DEFAULT NULL)
  RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $function$
-- Boş yazımı: tohumlama + hayvan Boş, açık GEBELIK_KONTROL/TOHUMLAMA_HAZIRLIK iptal, islem_log TOHUMLAMA_SONUC.
-- Döner: islem_id; hayvan Aktif değilse NULL (yazma yok). Sonuç denetimi çağırandadır.
DECLARE v_toh record; v_islem_id text := gen_random_uuid()::text; v_onceki_durum text; v_iptal text[];
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama WHERE id::text = p_tohumlama_id;
  SELECT tohumlama_durumu INTO v_onceki_durum FROM public.hayvanlar WHERE id = v_toh.hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN RETURN NULL; END IF;
  UPDATE public.tohumlama SET sonuc = 'Boş' WHERE id::text = p_tohumlama_id;
  UPDATE public.hayvanlar SET tohumlama_durumu = 'Boş' WHERE id = v_toh.hayvan_id;
  WITH u AS (UPDATE public.gorev_log SET iptal = true
              WHERE hayvan_id = v_toh.hayvan_id AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK')
                AND NOT tamamlandi AND NOT iptal RETURNING id::text)
  SELECT COALESCE(array_agg(id), '{}') INTO v_iptal FROM u;
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (v_islem_id, 'TOHUMLAMA_SONUC', v_toh.hayvan_id, p_tohumlama_id, 'tohumlama',
    jsonb_build_object('olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object('tablo', 'tohumlama', 'id', p_tohumlama_id, 'onceki', jsonb_build_object('sonuc', v_toh.sonuc)),
        jsonb_build_object('tablo', 'hayvanlar', 'id', v_toh.hayvan_id, 'onceki', jsonb_build_object('tohumlama_durumu', v_onceki_durum))),
      'iptal_gorevler', to_jsonb(v_iptal), 'iptal_sebep', 'bos')
    || jsonb_strip_nulls(jsonb_build_object('gerekce', p_gerekce)));
  RETURN v_islem_id;
END;
$function$;
REVOKE ALL ON FUNCTION public._tohumlama_bos_cekirdek(text, text) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_bos(p_tohumlama_id text, p_notlar text DEFAULT NULL::text)
  RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $function$
DECLARE v_toh record; v_islem_id text;
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama WHERE id::text = p_tohumlama_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı'); END IF;
  IF v_toh.sonuc != 'Bekliyor' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Bekliyor durumundaki tohumlama boş ilan edilebilir'); END IF;
  v_islem_id := public._tohumlama_bos_cekirdek(p_tohumlama_id);
  IF v_islem_id IS NULL THEN RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil'); END IF;
  -- R3.2 SK8: Boş çıkan açık dişidir — kural fonksiyonuyla görev (bayrak kapalıyken NULL).
  PERFORM public._acik_disi_gorev_kur(v_toh.hayvan_id);
  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$function$;

CREATE FUNCTION public.tedavi_sablon_bos_ata_uygula(p_case_id uuid, p_sablon_id uuid, p_tohumlama_id text, p_gerekce text,
                                                     p_baslangic_tarihi date DEFAULT NULL)
  RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp
AS $function$
-- §18.8 şablonlu vaka: kapı onayı = Boş + seçilen plan, tek işlem. Ret: PG_KAPI_BOS_ATA:<SEBEP>:<json>.
DECLARE
  v_hayvan text; v_son record; v_islem text; v_r jsonb;
  v_d jsonb := jsonb_build_object('case_id', p_case_id, 'sablon_id', p_sablon_id, 'tohumlama_id', p_tohumlama_id);
BEGIN
  IF btrim(COALESCE(p_gerekce, '')) = '' THEN RAISE EXCEPTION 'PG_KAPI_BOS_ATA:GEREKCE_GEREKLI:%', v_d; END IF;
  SELECT animal_id INTO v_hayvan FROM public.cases WHERE id = p_case_id AND status = 'active';
  IF NOT FOUND THEN RAISE EXCEPTION 'PG_KAPI_BOS_ATA:VAKA_YOK:%', v_d; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.tedavi_sablonu_kalem k WHERE k.sablon_id = p_sablon_id
                    AND public._pg_urun_durumu(k.stok_id, k.drug_product_id) = 'PG') THEN
    RAISE EXCEPTION 'PG_KAPI_BOS_ATA:PG_YOK:%', v_d; END IF;
  PERFORM 1 FROM public.hayvanlar WHERE id = v_hayvan FOR NO KEY UPDATE;
  SELECT t.id::text AS id, t.sonuc INTO v_son FROM public._son_tohumlama(v_hayvan) t;
  IF NOT COALESCE(v_son.id = p_tohumlama_id, false) THEN RAISE EXCEPTION 'PG_KAPI_BOS_ATA:TOH_SON_DEGIL:%', v_d; END IF;
  IF NOT COALESCE(v_son.sonuc = 'Bekliyor', false) THEN
    RAISE EXCEPTION 'PG_KAPI_BOS_ATA:TOH_SONUCLU:%', v_d || jsonb_build_object('sonuc', v_son.sonuc); END IF;
  v_islem := public._tohumlama_bos_cekirdek(p_tohumlama_id, btrim(p_gerekce));
  IF v_islem IS NULL THEN RAISE EXCEPTION 'PG_KAPI_BOS_ATA:HAYVAN_AKTIF_DEGIL:%', v_d; END IF;
  v_r := public.tedavi_sablon_uygula(p_case_id, p_sablon_id, p_baslangic_tarihi, false, NULL);
  IF NOT COALESCE((v_r->>'ok')::boolean, false) THEN
    RAISE EXCEPTION 'PG_KAPI_BOS_ATA:PLAN_RED:%', v_d || jsonb_build_object('mesaj', v_r->>'mesaj'); END IF;
  PERFORM public._acik_disi_gorev_kur(v_hayvan);
  RETURN v_r || jsonb_build_object('tohumlama_id', p_tohumlama_id, 'islem_id', v_islem);
END;
$function$;
REVOKE ALL ON FUNCTION public.tedavi_sablon_bos_ata_uygula(uuid, uuid, text, text, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tedavi_sablon_bos_ata_uygula(uuid, uuid, text, text, date) TO authenticated, service_role;
