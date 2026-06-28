-- 2026-06-28 — DOGUM PG görevleri ↔ uygulama/scanner bağlantısı (etken_kod link)
--
-- YAN GÖZLEM (20260628000001 fix'inden çıktı): dogum_kaydet'in yazdığı PG görev satırları
-- (2./25./39. Gün PG) etken_kod=NULL idi. Sonuçlar:
--   • protokol_eksik_tara scanner'ın KANIT #1'i (gorev_log.etken_kod = step.ek) bu satırları
--     "tamamlandı" sayamıyordu → görev dashboard'dan kapatılsa bile (uygulama_log yazılmadıysa)
--     scanner uyarısı asılı kalabiliyordu.
--   • Trigger zinciri (_gorev_dinle) etken_kod ile eşleştiği için bu satırları HİÇ auto-close edemiyordu.
--
-- DÜZELTME:
--   1) _gorev_dinle: "en erken açık görev" yerine "uygulama tarihine EN YAKIN açık görev" kapatır.
--      Sebep: PG satırlarına etken_kod='PG' verince bir hayvanda aynı anda 2-3 açık PG görevi
--      olabilir (d2/d25/d39). Düz "earliest" mantığı d25 uygulamasında açık kalan d2'yi yanlışça
--      kapatırdı (scanner ise tarih-pencereli, doğru adımı işaretler) → tutarsızlık. p_tarih (DEFAULT
--      NULL, geriye uyumlu) eklendi; NULL ise eski earliest davranışı korunur.
--   2) Üç trigger çağıranı (uygulama_log / drug_administrations / vaccination_log) kendi uygulama
--      tarihini _gorev_dinle'ye geçirir.
--   3) dogum_kaydet: PG satırlarını etken_kod='PG' ile yazar (ileriye dönük).
--   4) Mevcut DOGUM PG satırlarına etken_kod='PG' backfill.
--
-- KAPSAM NOTU: d0 (Oksitosin+Ademin+Kalsiyum çoklu ilaç), d53 (Ademin+Yeldif), d54 (Yeldif) satırları
-- NULL bırakıldı — bu yan gözlem yalnızca PG içindi. Scanner bunları kendi adım listesinden (ADEMIN/E_VIT)
-- ayrıca izliyor; istenirse ileride aynı desenle bağlanabilir.

-- ── 1) _gorev_dinle: nearest-date ──
DROP FUNCTION IF EXISTS public._gorev_dinle(text, text, text);

CREATE OR REPLACE FUNCTION public._gorev_dinle(p_hayvan_id text, p_etken_kod text, p_ref text DEFAULT NULL::text, p_tarih date DEFAULT NULL::date)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_gorev_id uuid;
BEGIN
  IF p_etken_kod IS NULL OR p_hayvan_id IS NULL THEN
    RETURN;
  END IF;
  SELECT id INTO v_gorev_id
  FROM public.gorev_log
  WHERE hayvan_id = p_hayvan_id
    AND etken_kod = p_etken_kod
    AND tamamlandi = false
    AND iptal = false
  ORDER BY
    CASE WHEN p_tarih IS NULL THEN 0 ELSE abs(hedef_tarih - p_tarih) END ASC,  -- uygulama tarihine en yakın
    hedef_tarih ASC                                                            -- eşitlikte en erken
  LIMIT 1
  FOR UPDATE;
  IF v_gorev_id IS NOT NULL THEN
    UPDATE public.gorev_log
    SET tamamlandi = true, tamamlanma_tarihi = now(), kapatan_ref = p_ref
    WHERE id = v_gorev_id;
  END IF;
END;
$function$;

-- ── 2) Trigger çağıranları: uygulama tarihini geçir ──
CREATE OR REPLACE FUNCTION public.fn_dinle_uygulama()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
AS $function$
BEGIN
  IF NEW.etken_kod IS NOT NULL THEN
    PERFORM public._gorev_dinle(NEW.hayvan_id, NEW.etken_kod, 'uygulama_log:' || NEW.id::text, NEW.tarih);
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_dinle_drug_admin()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
AS $function$
DECLARE
  v_etken text;
  v_animal_id text;
BEGIN
  v_etken := public._etken_kod_bul(NEW.stok_id, NULL);
  IF v_etken IS NULL THEN
    RETURN NEW;
  END IF;
  SELECT c.animal_id INTO v_animal_id
  FROM public.treatment_days td
  JOIN public.cases c ON c.id = td.case_id
  WHERE td.id = NEW.treatment_day_id;
  IF v_animal_id IS NOT NULL THEN
    PERFORM public._gorev_dinle(v_animal_id, v_etken, 'drug_admin:' || NEW.id::text, NEW.created_at::date);
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_dinle_vaccination()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
AS $function$
DECLARE
  v_etken text;
BEGIN
  v_etken := public._etken_kod_bul(NULL, NEW.vaccine_id);
  IF v_etken IS NOT NULL THEN
    PERFORM public._gorev_dinle(NEW.animal_id, v_etken, 'vaccination_log:' || NEW.id::text, NEW.vaccination_date);
  END IF;
  RETURN NEW;
END;
$function$;

-- ── 3) Mevcut DOGUM PG satırlarına etken_kod='PG' backfill ──
UPDATE public.gorev_log
SET etken_kod = 'PG'
WHERE kaynak LIKE 'DOGUM-%'
  AND etken_kod IS NULL
  AND (aciklama IN ('2. Gün PG', '25. Gün PG') OR aciklama LIKE '39. Gün PG%');

-- ── 4) dogum_kaydet: PG satırlarını etken_kod='PG' ile yaz (ileriye dönük) ──
CREATE OR REPLACE FUNCTION public.dogum_kaydet(p_anne_id text, p_tarih date, p_kupe text, p_cins text DEFAULT 'Dişi'::text, p_tip text DEFAULT 'Normal'::text, p_kg numeric DEFAULT NULL::numeric, p_baba text DEFAULT NULL::text, p_hekim_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_anne        record;
  v_dogum_id    uuid := gen_random_uuid();
  v_buzagi_id   text;
  v_ana_gorev   uuid := gen_random_uuid();
  v_sayac       integer;
  v_dup         text;
  v_baba_bilgi  text;
BEGIN
  SELECT * INTO v_anne FROM public.hayvanlar WHERE id = p_anne_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Anne bulunamadı');
  END IF;

  SELECT id INTO v_dup FROM public.hayvanlar WHERE kupe_no = p_kupe OR devlet_kupe = p_kupe LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu küpe zaten kayıtlı: ' || p_kupe);
  END IF;

  IF p_baba IS NULL OR p_baba = '' THEN
    SELECT sperma INTO v_baba_bilgi
    FROM public.tohumlama
    WHERE hayvan_id = p_anne_id AND sonuc = 'Gebe'
    ORDER BY tarih DESC
    LIMIT 1;
  ELSE
    v_baba_bilgi := p_baba;
  END IF;

  INSERT INTO public.dogum (id, anne_id, tarih, yavru_cins, yavru_kupe, yavru_irk, dogum_tipi, hekim_id, dogum_kg, baba_bilgi)
  VALUES (v_dogum_id, p_anne_id, p_tarih, p_cins, p_kupe, v_anne.irk, p_tip, p_hekim_id, p_kg, v_baba_bilgi);

  SELECT 'H' || LPAD((COUNT(*)+1)::text, 6, '0') INTO v_buzagi_id FROM public.hayvanlar;

  INSERT INTO public.hayvanlar (id, kupe_no, irk, dogum_tarihi, anne_id, baba_bilgi, cinsiyet, grup, padok, durum, dogum_kg)
  VALUES (v_buzagi_id, p_kupe, v_anne.irk, p_tarih, p_anne_id, v_baba_bilgi, p_cins,
          'Süt İçen Buzağı', 'Buzağı Padok (Süt İçenler)', 'Aktif', p_kg);

  UPDATE public.hayvanlar
  SET grup = 'Sağmal (Laktasyonda)', padok = 'Sağmal Padok'
  WHERE id = p_anne_id;

  -- 5. Anne protokol görevleri — Postpartum PG: d2 · d25 · d39 (Presynch-14). d11 kaldırıldı (2026-06-24).
  --    PG satırlarına etken_kod='PG' verilir: scanner kanıt #1 + trigger auto-close (en yakın tarihli) çalışır.
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod)
  VALUES
    (gen_random_uuid(), p_anne_id, 'ILAC',  'Doğum günü: Oksitosin + Ademin + Kalsiyum', p_tarih,        false, 'DOGUM-' || p_anne_id, NULL),
    (gen_random_uuid(), p_anne_id, 'ILAC',  '2. Gün PG',                                  p_tarih + 2,   false, 'DOGUM-' || p_anne_id, 'PG'),
    (gen_random_uuid(), p_anne_id, 'ILAC',  '25. Gün PG',                                 p_tarih + 25,  false, 'DOGUM-' || p_anne_id, 'PG'),
    (gen_random_uuid(), p_anne_id, 'ILAC',  '39. Gün PG (Presynch-14 senkron)',           p_tarih + 39,  false, 'DOGUM-' || p_anne_id, 'PG'),
    (gen_random_uuid(), p_anne_id, 'ILAC',  '53. Gün: Ademin + Yeldif',                   p_tarih + 53,  false, 'DOGUM-' || p_anne_id, NULL),
    (gen_random_uuid(), p_anne_id, 'ILAC',  '54. Gün: Yeldif',                            p_tarih + 54,  false, 'DOGUM-' || p_anne_id, NULL),
    (gen_random_uuid(), p_anne_id, 'DIGER', '⚡ 58-63. gün kızgınlık takibi',             p_tarih + 58,  false, 'DOGUM-' || p_anne_id, NULL);

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak)
  VALUES (v_ana_gorev, v_buzagi_id, 'BUZAGI_BAKIM', 'Buzağı İlk Gün Bakımı (' || p_kupe || ')', p_tarih, false, 'DOGUM-' || p_anne_id);

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, parent_id, kaynak)
  VALUES
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Kolostrum ver (doğumdan sonra ilk 2 saat)', p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Göbek kordonu dezenfeksiyonu (iyot)',        p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Küpeleme',                                   p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Ademin uygula (1. gün)',                      p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Maya ver (1. gün)',                           p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Probiyotik ver (1. gün)',                     p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id);

  UPDATE public.tohumlama
  SET sonuc = 'Doğum Yaptı', dogum_tarihi = p_tarih, buzagi_kupe = p_kupe
  WHERE hayvan_id = p_anne_id AND sonuc = 'Gebe';

  GET DIAGNOSTICS v_sayac = ROW_COUNT;

  UPDATE gorev_log
  SET iptal = true
  WHERE hayvan_id = p_anne_id
    AND gorev_tipi = 'BESLEME'
    AND tamamlandi = false
    AND iptal = false;

  RETURN jsonb_build_object(
    'ok', true,
    'buzagi_id', v_buzagi_id,
    'dogum_id', v_dogum_id,
    'gorev_sayisi', 14,
    'tohumlama_kapatildi', v_sayac
  );
END;
$function$;
