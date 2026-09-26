-- ============================================================================
-- Migration: 20260925100001_vaka_kalan_gunleri_kaydir
-- Tarih: 2026-09-25 · Erteleme-genel turu E0-DB (zarf E0 / sahip kararı S5)
-- Etkiler: yeni RPC public.vaka_kalan_gunleri_kaydir(uuid, integer)
--   (SECDEF plpgsql VOLATILE, SET search_path = public, pg_temp — tırnaksız)
--
-- Amaç: bir AKTİF tedavi vakasının TAMAMLANMAMIŞ günlerini, açık
--   TEDAVI_GUN/TEDAVI_SEANS görevlerini, uygulanmamış seans planlarını ve
--   şablon-türevi AÇIK TAI görevini (TOHUMLAMA_PLANLI, kaynak
--   'TEDAVI_SABLON_TOHUMLAMA:<case>:%') tek atomik işlemde +N gün kaydırır.
--   Aralıklar korunur (tüm açık yüzeyler aynı N ile kayar), tamamlanmış
--   gün/görev/semana DOKUNMAZ, sonuç tarihi geçmişe düşemez (p_gun >= 1,
--   tek yönlü ileri; TAI ayrıca tohumlama_gorev_ertele pencere/GECMIS_TARIH
--   korumasından geçer — K10 U5 deseni).
--
-- Kapsam envanteri (demo kanıtlı, plan-e0.md §1):
--   treatment_days.treatment_date (tamamlandi=false) ............ +p_gun
--   gorev_log.hedef_tarih (açık TEDAVI_GUN/TEDAVI_SEANS, day_id) . +p_gun (hedef_saat DOKUNMA)
--   gorev_log TEDAVI_GUN aciklama->label (biçim-eşleşen) ......... tarih tazeleme
--   treatment_day_uygulamalar.planned_date (uygulanmamış) ........ +p_gun
--   açık TAI gorev_log ........................................... tohumlama_gorev_ertele RPC'si
--   protokol_instance: vaka-bağlı satır YOK (demo 0 satır — plan §0); DOKUNULMAZ
--   drug_administrations: tarih kolonu yok (created_at geçmiş); DOKUNULMAZ
--   cases.start_date: vaka çapası (domain-rules §13-9); DOKUNULMAZ
--
-- protocol_family GEREKTİRMEZ: ovsync ayrımı yalnız kaynak/kaynak_ref
--   kalıplarından türer → prod önkoşulu minimal (yalnız 20260923000003 serisi).
--
-- farm_id damgası YOK: fonksiyon UPDATE-only (yeni satır üretmez; islem_log
--   audit'i farm_id kolonu taşımayan global log) — plan-e0.md §2-6.
--
-- Hata ailesi: VAKA_KAYDIRILAMAZ:<json> (GOREV_ERTELENEMEZ kalıbının vaka
--   eşi) — GECERSIZ_GUN / VAKA_BULUNAMADI / VAKA_ACIK_DEGIL.
-- Audit: islem_log tip 'VAKA_KAYDIR' (ref_tablo 'cases', snapshot özetli).
--
-- Geri alınabilir: evet — DROP FUNCTION public.vaka_kalan_gunleri_kaydir(uuid, integer);
--   (veri yazmaz; yalnız nesne tanımıdır).
-- ============================================================================

BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION public.vaka_kalan_gunleri_kaydir(p_case_id uuid, p_gun integer)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_case          public.cases%ROWTYPE;
  v_gun_satiri    integer := 0;
  v_gorev         integer := 0;
  v_seans         integer := 0;
  v_uygulama      integer := 0;
  v_tai           integer := 0;
  v_ilk_eski      date;
  v_son_eski      date;
  v_ilk_yeni      date;
  v_son_yeni      date;
  v_tai_rec       record;
BEGIN
  -- 0) Parametre: tek yönlü ileri kaydırma (p_gun >= 1 zorunlu)
  IF p_gun IS NULL OR p_gun < 1 THEN
    RAISE EXCEPTION 'VAKA_KAYDIRILAMAZ:%', jsonb_build_object(
      'case_id', p_case_id, 'gun', p_gun, 'sebep', 'GECERSIZ_GUN');
  END IF;

  -- 1) Vaka kilitle + doğrula
  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'VAKA_KAYDIRILAMAZ:%', jsonb_build_object(
      'case_id', p_case_id, 'gun', p_gun, 'sebep', 'VAKA_BULUNAMADI');
  END IF;
  IF v_case.status IS DISTINCT FROM 'active' THEN
    RAISE EXCEPTION 'VAKA_KAYDIRILAMAZ:%', jsonb_build_object(
      'case_id', p_case_id, 'gun', p_gun, 'sebep', 'VAKA_ACIK_DEGIL', 'status', v_case.status);
  END IF;

  -- 2) Özet: kaydırma ÖNCESİ açık gün tarih aralığı
  SELECT min(td.treatment_date), max(td.treatment_date) INTO v_ilk_eski, v_son_eski
    FROM public.treatment_days td
   WHERE td.case_id = p_case_id AND td.tamamlandi = false;

  -- 3) Gün satırları: yalnız TAMAMLANMAMIŞ günler (tamamlanmışa dokunma)
  UPDATE public.treatment_days td
     SET treatment_date = td.treatment_date + p_gun
   WHERE td.case_id = p_case_id
     AND td.tamamlandi = false;
  GET DIAGNOSTICS v_gun_satiri = ROW_COUNT;

  -- 4) Üst görevler: vakaya bağlı AÇIK TEDAVI_GUN (hedef_saat DOKUNMA)
  UPDATE public.gorev_log g
     SET hedef_tarih = g.hedef_tarih + p_gun
   WHERE g.gorev_tipi = 'TEDAVI_GUN'
     AND COALESCE(g.tamamlandi, false) = false
     AND COALESCE(g.iptal, false) = false
     AND left(g.aciklama, 1) = '{'
     AND EXISTS (SELECT 1
                   FROM public.treatment_days td
                  WHERE td.case_id = p_case_id
                    AND td.id::text = g.aciklama::jsonb ->> 'day_id');
  GET DIAGNOSTICS v_gorev = ROW_COUNT;

  -- 5) Seans görevleri: vakaya bağlı AÇIK TEDAVI_SEANS (hedef_saat DOKUNMA)
  UPDATE public.gorev_log g
     SET hedef_tarih = g.hedef_tarih + p_gun
   WHERE g.gorev_tipi = 'TEDAVI_SEANS'
     AND COALESCE(g.tamamlandi, false) = false
     AND COALESCE(g.iptal, false) = false
     AND left(g.aciklama, 1) = '{'
     AND EXISTS (SELECT 1
                   FROM public.treatment_days td
                  WHERE td.case_id = p_case_id
                    AND td.id::text = g.aciklama::jsonb ->> 'day_id');
  GET DIAGNOSTICS v_seans = ROW_COUNT;

  -- 6) TEDAVI_GUN etiket tazeleme: yalnız biçim-eşleşen 'Gun N tedavisi - DD.MM.YYYY'
  --    (TEDAVI_SEANS etiketi 'Gun N - Seans (HH:MM)' tarih taşımaz — dokunma).
  --    Tarih, 3. adımda kaydırılmış gün satırının YENİ treatment_date'inden üretilir.
  UPDATE public.gorev_log g
     SET aciklama = jsonb_set(
           g.aciklama::jsonb, '{label}',
           to_jsonb('Gun ' || td.day_no || ' tedavisi - '
                    || to_char(td.treatment_date, 'DD.MM.YYYY')))::text
    FROM public.treatment_days td
   WHERE td.case_id = p_case_id
     AND td.tamamlandi = false
     AND td.id::text = g.aciklama::jsonb ->> 'day_id'
     AND g.gorev_tipi = 'TEDAVI_GUN'
     AND COALESCE(g.tamamlandi, false) = false
     AND COALESCE(g.iptal, false) = false
     AND left(g.aciklama, 1) = '{'
     AND g.aciklama::jsonb ->> 'label' ~ '^Gun [0-9]+ tedavisi - [0-9]{2}\.[0-9]{2}\.[0-9]{4}$';

  -- 7) Seans plan satırları: UYGULANMAMIŞ olanlar (uygulanmış = geçmiş, dokunma)
  UPDATE public.treatment_day_uygulamalar tdu
     SET planned_date = tdu.planned_date + p_gun
   WHERE tdu.case_id = p_case_id
     AND tdu.uygulama_tamamlandi_at IS NULL
     AND COALESCE(tdu.uygulanmadi, false) = false;
  GET DIAGNOSTICS v_uygulama = ROW_COUNT;

  -- 8) Şablon-türevi AÇIK TAI: destekli RPC ile (pencere + GECMIS_TARIH +
  --    TOHUMLAMA_ERTELE audit + ilk_hedef/toplam_erteleme_gun soyu devralır;
  --    K10 U5 deseni — demo'da 8/8 kanıtlı). RPC hatası tüm kaydı geri sarar.
  FOR v_tai_rec IN
    SELECT g.id, g.hedef_tarih, g.hedef_saat
      FROM public.gorev_log g
     WHERE g.gorev_tipi = 'TOHUMLAMA_PLANLI'
       AND g.kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:' || p_case_id::text || ':%'
       AND COALESCE(g.tamamlandi, false) = false
       AND COALESCE(g.iptal, false) = false
     ORDER BY g.id
  LOOP
    PERFORM public.tohumlama_gorev_ertele(
      v_tai_rec.id, v_tai_rec.hedef_tarih + p_gun, v_tai_rec.hedef_saat);
    v_tai := v_tai + 1;
  END LOOP;

  -- 9) Özet: kaydırma SONRASI açık gün tarih aralığı
  SELECT min(td.treatment_date), max(td.treatment_date) INTO v_ilk_yeni, v_son_yeni
    FROM public.treatment_days td
   WHERE td.case_id = p_case_id AND td.tamamlandi = false;

  -- 10) Audit (islem_log immutable; farm_id taşımayan global log)
  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot, kullanici_notu)
  VALUES (
    'VAKA_KAYDIR',
    v_case.animal_id,
    p_case_id::text,
    'cases',
    jsonb_build_object(
      'case_id', p_case_id,
      'gun', p_gun,
      'tasinan_gun_satiri', v_gun_satiri,
      'tasinan_gorev', v_gorev,
      'tasinan_seans', v_seans,
      'tasinan_uygulama_satiri', v_uygulama,
      'tai', v_tai,
      'eski_ilk_tarih', v_ilk_eski,
      'eski_son_tarih', v_son_eski,
      'yeni_ilk_tarih', v_ilk_yeni,
      'yeni_son_tarih', v_son_yeni),
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object('tablo', 'treatment_days', 'adet', v_gun_satiri,
                           'kosul', 'case_id + tamamlandi=false, treatment_date+N'),
        jsonb_build_object('tablo', 'gorev_log', 'adet', v_gorev + v_seans,
                           'kosul', 'acik TEDAVI_GUN/TEDAVI_SEANS (day_id), hedef_tarih+N'),
        jsonb_build_object('tablo', 'gorev_log', 'adet', v_tai,
                           'kosul', 'acik TAI via tohumlama_gorev_ertele'),
        jsonb_build_object('tablo', 'treatment_day_uygulamalar', 'adet', v_uygulama,
                           'kosul', 'uygulanmamis, planned_date+N')),
      'silinen', '[]'::jsonb),
    format('Vaka kalan gunleri kaydirildi: +%s gun | gun satiri %s, gorev %s, seans %s, uygulama %s, TAI %s | %s .. %s -> %s .. %s',
           p_gun, v_gun_satiri, v_gorev, v_seans, v_uygulama, v_tai,
           v_ilk_eski, v_son_eski, v_ilk_yeni, v_son_yeni));

  RETURN jsonb_build_object(
    'ok', true,
    'case_id', p_case_id,
    'gun', p_gun,
    'tasinan_gun_satiri', v_gun_satiri,
    'tasinan_gorev', v_gorev,
    'tasinan_seans', v_seans,
    'tasinan_uygulama_satiri', v_uygulama,
    'tai', v_tai,
    'ilk_tarih', v_ilk_yeni,
    'son_tarih', v_son_yeni);

EXCEPTION WHEN OTHERS THEN
  -- Tek EXCEPTION bloğu: orijinal SQLSTATE/message korunur (VAKA_KAYDIRILAMAZ /
  -- GECMIS_TARIH / GOREV_ERTELENEMEZ aileleri UI tarafında ayırt edilebilir kalır).
  -- COMMIT/ROLLBACK gövde içinde YOK — transaction migration dosyasına aittir.
  RAISE;
END;
$function$;

-- Kapı kuralları: PUBLIC/anon kapalı, yalnız authenticated (UI'ın çağırdığı RPC)
REVOKE ALL ON FUNCTION public.vaka_kalan_gunleri_kaydir(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vaka_kalan_gunleri_kaydir(uuid, integer) TO authenticated;

COMMIT;
