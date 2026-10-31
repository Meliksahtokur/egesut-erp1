-- ════════════════════════════════════════════════════════════════════
-- Ölü/çıkmış hayvanın küpesi her yolda serbest (K1, sahip 2026-10-31).
-- Önceki gövdeler: dogum_kaydet 20261030000001, kupe_musait_mi 20260901000002 (canlıdan okundu).
--
-- A) dogum_kaydet ikiz guard'ı yalnız AKTİF yavruda reddeder; aynı anne ölen yavrusunun küpesini
--    yeni yavruya verebilir. Aktif küpe zaten önceki kontrolde reddedilir; bu guard küpesi sonradan
--    düzeltilmiş aktif yavruyu korumayı sürdürür, mesajı aynı. Gövdenin kalanı değişmedi.
-- B) kupe_musait_mi: düzenlenen hayvanın kendi değişmeyen küpesi çakışma sayılmaz. Küpesi başkasına
--    verilmiş çıkmış hayvanın kartı hem blur kontrolünde hem hayvan_guncelle(18) içinde reddediliyordu;
--    ikisi de bu fonksiyonu çağırır. hayvan_guncelle gövdesi değişmedi.
-- Geri alma: yukarıdaki iki önceki gövde.
-- ════════════════════════════════════════════════════════════════════

BEGIN;

CREATE OR REPLACE FUNCTION public.dogum_kaydet(p_anne_id text, p_tarih date, p_kupe text, p_cins text DEFAULT 'Dişi'::text, p_tip text DEFAULT 'Normal'::text, p_kg numeric DEFAULT NULL::numeric, p_baba text DEFAULT NULL::text, p_hekim_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_anne           record;
  v_dogum_id       uuid := gen_random_uuid();
  v_buzagi_id      text;
  v_ana_gorev      uuid := gen_random_uuid();
  v_sayac          integer := 0;
  v_dup            text;
  v_baba_bilgi     text;
  v_anne_inst_id   uuid;
  v_buzagi_inst_id uuid;
  v_olay_id        uuid;
  v_ikinci         boolean := false;
  v_anne_yan_etki  boolean := true;
  v_yavru_sirasi   integer;
BEGIN
  SELECT * INTO v_anne FROM public.hayvanlar WHERE id = p_anne_id AND durum = 'Aktif';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Anne bulunamadı'); END IF;

  SELECT id INTO v_dup FROM public.hayvanlar WHERE (kupe_no = p_kupe AND durum = 'Aktif') OR devlet_kupe = p_kupe LIMIT 1;
  IF FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu küpe zaten kayıtlı: ' || p_kupe); END IF;

  -- K5: erkek buzağı sayısal küpesi 500-599 aralığında olmalı (::numeric — int4 overflow koruması)
  IF p_cins = 'Erkek' AND p_kupe ~ '^[0-9]+$'
     AND (p_kupe::numeric < 500 OR p_kupe::numeric > 599) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      'Erkek buzağı küpesi 500-599 aralığında olmalı (girilen: ' || p_kupe || ')');
  END IF;

  -- İKİZ GUARD: aynı anne + aynı yavru küpesi AKTİF yavruda kayıtlıysa reddet (typo → yanlış ikiz engeli).
  -- Çıkmış yavrunun küpesi serbest (K1, sahip 2026-10-31); buzagi_id boş satır engellemez.
  IF EXISTS (SELECT 1 FROM public.dogum d JOIN public.hayvanlar h ON h.id = d.buzagi_id
             WHERE d.anne_id = p_anne_id AND d.yavru_kupe = p_kupe AND h.durum = 'Aktif') THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu küpe bu annenin yavrusu olarak zaten kayıtlı: ' || p_kupe);
  END IF;

  -- OLAY PENCERESİ (10 gün): yakın doğum varsa aynı olaya bağlanır (ikiz/üçüz)
  SELECT olay_id INTO v_olay_id FROM public.dogum
   WHERE anne_id = p_anne_id AND tarih BETWEEN p_tarih - 10 AND p_tarih
   ORDER BY tarih DESC LIMIT 1;
  v_ikinci := v_olay_id IS NOT NULL;

  -- ANNE GÖREV GUARD'I (60 gün): yakın doğum varsa anne yan etkileri ASLA tekrarlanmaz
  -- (9 görev + tohumlama kapatma + grup/padok + protokol + BESLEME iptali)
  IF EXISTS (SELECT 1 FROM public.dogum
             WHERE anne_id = p_anne_id AND tarih BETWEEN p_tarih - 60 AND p_tarih) THEN
    v_anne_yan_etki := false;
  END IF;

  IF NOT v_ikinci THEN v_olay_id := gen_random_uuid(); END IF;

  IF p_baba IS NULL OR p_baba = '' THEN
    SELECT sperma INTO v_baba_bilgi FROM public.tohumlama
    WHERE hayvan_id = p_anne_id AND sonuc = 'Gebe' ORDER BY tarih DESC LIMIT 1;
    -- 2. yavru dalında Gebe tohumlama yoktur: babayı olayın ilk doğumundan al
    IF v_baba_bilgi IS NULL AND v_ikinci THEN
      SELECT baba_bilgi INTO v_baba_bilgi FROM public.dogum
      WHERE olay_id = v_olay_id AND baba_bilgi IS NOT NULL ORDER BY tarih DESC LIMIT 1;
    END IF;
  ELSE v_baba_bilgi := p_baba; END IF;

  INSERT INTO public.dogum (id, anne_id, tarih, yavru_cins, yavru_kupe, yavru_irk, dogum_tipi, hekim_id, dogum_kg, baba_bilgi, olay_id)
  VALUES (v_dogum_id, p_anne_id, p_tarih, p_cins, p_kupe, v_anne.irk, p_tip, p_hekim_id, p_kg, v_baba_bilgi, v_olay_id);

  v_buzagi_id := gen_random_uuid()::text;

  INSERT INTO public.hayvanlar (id, kupe_no, irk, dogum_tarihi, anne_id, baba_bilgi, cinsiyet, grup, padok, durum, dogum_kg)
  VALUES (v_buzagi_id, p_kupe, v_anne.irk, p_tarih, p_anne_id, v_baba_bilgi, p_cins,
          'Süt İçen Buzağı', 'Buzağı Padok (Süt İçenler)', 'Aktif', p_kg);

  -- buzagi_id baglama (Task 0.5, spec Rev 2 par.2): dogum satirini buzagiya ayni transaction icinde bagla
  UPDATE public.dogum SET buzagi_id = v_buzagi_id WHERE id = v_dogum_id;

  SELECT COUNT(*) INTO v_yavru_sirasi FROM public.dogum WHERE olay_id = v_olay_id;

  IF v_anne_yan_etki THEN
    UPDATE public.hayvanlar SET grup = 'Sağmal (Laktasyonda)', padok = 'Sağmal Padok' WHERE id = p_anne_id;

    INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
    VALUES (p_anne_id, 'UREME', 'DOGUM', 'DOGUM-' || p_anne_id, p_tarih, 'aktif')
    ON CONFLICT (kaynak_ref) DO UPDATE SET durum = 'aktif', kapandi_at = NULL, kapandi_sebep = NULL
    RETURNING id INTO v_anne_inst_id;
    IF v_anne_inst_id IS NULL THEN
      SELECT id INTO v_anne_inst_id FROM public.protokol_instance WHERE kaynak_ref = 'DOGUM-' || p_anne_id;
    END IF;

    INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod, protokol_instance_id)
    VALUES
      (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Oksitosin', p_tarih,      false, 'DOGUM-' || p_anne_id, 'OKSITOSIN', v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Ademin',    p_tarih,      false, 'DOGUM-' || p_anne_id, 'ADEMIN',    v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Kalsiyum',  p_tarih,      false, 'DOGUM-' || p_anne_id, 'KALSIYUM',  v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', '2. Gün PG',             p_tarih + 2,  false, 'DOGUM-' || p_anne_id, 'PG',        v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', '39. Gün PG (Presynch-14 senkron)', p_tarih + 39, false, 'DOGUM-' || p_anne_id, 'PG',        v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', '25. Gün PG',            p_tarih + 25, false, 'DOGUM-' || p_anne_id, 'PG',        v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', '53. Gün: E Vitamini',       p_tarih + 53, false, 'DOGUM-' || p_anne_id, 'E_VIT',     v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'DIGER','⚡ 58-63. gün kızgınlık takibi', p_tarih + 58, false, 'DOGUM-' || p_anne_id, NULL, v_anne_inst_id);

    UPDATE public.tohumlama
    SET sonuc = 'Doğum Yaptı', dogum_tarihi = p_tarih, buzagi_kupe = p_kupe
    WHERE hayvan_id = p_anne_id AND sonuc = 'Gebe';

    UPDATE public.gorev_log SET iptal = true
    WHERE hayvan_id = p_anne_id AND gorev_tipi = 'BESLEME' AND tamamlandi = false AND iptal = false;

    UPDATE public.protokol_instance SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = 'DOGUM'
    WHERE hayvan_id = p_anne_id AND alttip = 'BESLEME' AND durum = 'aktif';

    -- S-8/R3.2: anne ilk tohumlama rotası (kural = bu doğum + 51). Bayrak
    -- kapalıyken NULL (MK5). İkiz/üçüz ikinci yavru bu dala girmez; girse de
    -- kaynak_ref (olay_id) UNIQUE ile idempotent.
    PERFORM public._ilk_tohumlama_rota_kur(p_anne_id, p_tarih, 'ILK-TOH-DOGUM-' || v_olay_id::text);
  END IF;

  -- R3.2 SK8: DİŞİ BUZAĞI → düve rotası (kural = dogum_tarihi + 12 ay 21 gün;
  -- _ovsync_kural_tarihi buzağı için düve dalına düşer). Kaynak buzağıya özgü
  -- olduğundan ikiz dişi yavruların her biri kendi rotasını alır. Erkek buzağı
  -- ve bayrak kapalı → NULL, yan etki yok.
  IF p_cins = 'Dişi' THEN
    PERFORM public._ilk_tohumlama_rota_kur(v_buzagi_id, p_tarih, 'ILK-TOH-DUVE-' || v_buzagi_id);
  END IF;

  INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
  VALUES (v_buzagi_id, 'BAKIM', 'BUZAGI', 'BUZAGI-' || v_buzagi_id, p_tarih, 'aktif')
  RETURNING id INTO v_buzagi_inst_id;

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, protokol_instance_id)
  VALUES (v_ana_gorev, v_buzagi_id, 'BUZAGI_BAKIM', 'Buzağı İlk Gün Bakımı (' || p_kupe || ')', p_tarih, false, 'BUZAGI-' || v_buzagi_id, v_buzagi_inst_id);

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, parent_id, kaynak, protokol_instance_id)
  VALUES
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Kolostrum ver (doğumdan sonra ilk 2 saat)', p_tarih, false, v_ana_gorev, 'BUZAGI-' || v_buzagi_id, v_buzagi_inst_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Göbek kordonu dezenfeksiyonu (iyot)',        p_tarih, false, v_ana_gorev, 'BUZAGI-' || v_buzagi_id, v_buzagi_inst_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Küpeleme',                                   p_tarih, false, v_ana_gorev, 'BUZAGI-' || v_buzagi_id, v_buzagi_inst_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Ademin uygula (1. gün)',                      p_tarih, false, v_ana_gorev, 'BUZAGI-' || v_buzagi_id, v_buzagi_inst_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Maya ver (1. gün)',                           p_tarih, false, v_ana_gorev, 'BUZAGI-' || v_buzagi_id, v_buzagi_inst_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Probiyotik ver (1. gün)',                     p_tarih, false, v_ana_gorev, 'BUZAGI-' || v_buzagi_id, v_buzagi_inst_id);

  RETURN jsonb_build_object(
    'ok', true, 'buzagi_id', v_buzagi_id, 'dogum_id', v_dogum_id,
    'gorev_sayisi', (CASE WHEN v_anne_yan_etki THEN 8 ELSE 0 END) + 7,
    'anne_inst_id', v_anne_inst_id,
    'buzagi_inst_id', v_buzagi_inst_id, 'tohumlama_kapatildi', v_sayac,
    'coklu_dogum', v_ikinci, 'olay_id', v_olay_id, 'yavru_sirasi', v_yavru_sirasi
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.kupe_musait_mi(p_kupe_no text, p_devlet_kupe text, p_hayvan_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_aktif_cakisma text; v_devlet_cakisma text;
  v_gecmis_id text; v_gecmis_durum text;
BEGIN
  -- Düzenlenen hayvanın kendi değişmeyen küpesi çakışma sayılmaz (K1: küpesi yeniden verilmiş çıkmış hayvan)
  IF p_kupe_no IS NOT NULL AND p_kupe_no <> ''
     AND NOT EXISTS (SELECT 1 FROM public.hayvanlar WHERE id = p_hayvan_id AND kupe_no = p_kupe_no) THEN
    SELECT id INTO v_aktif_cakisma FROM public.hayvanlar
     WHERE kupe_no = p_kupe_no AND durum = 'Aktif'
       AND (p_hayvan_id IS NULL OR id <> p_hayvan_id) LIMIT 1;
    IF v_aktif_cakisma IS NULL THEN
      SELECT id, durum INTO v_gecmis_id, v_gecmis_durum FROM public.hayvanlar
       WHERE kupe_no = p_kupe_no AND durum IS DISTINCT FROM 'Aktif'
         AND (p_hayvan_id IS NULL OR id <> p_hayvan_id)
       ORDER BY cikis_tarihi DESC NULLS LAST, id DESC LIMIT 1;
    END IF;
  END IF;
  IF p_devlet_kupe IS NOT NULL AND p_devlet_kupe <> '' THEN
    SELECT id INTO v_devlet_cakisma FROM public.hayvanlar
     WHERE devlet_kupe = p_devlet_kupe
       AND (p_hayvan_id IS NULL OR id <> p_hayvan_id) LIMIT 1;
  END IF;
  RETURN jsonb_build_object(
    'musait', (v_aktif_cakisma IS NULL AND v_devlet_cakisma IS NULL),
    'kupe_cakisma_id', v_aktif_cakisma,
    'kupe_gecmis_id', v_gecmis_id,
    'kupe_gecmis_durum', v_gecmis_durum,
    'devlet_cakisma_id', v_devlet_cakisma);
END; $function$;

NOTIFY pgrst, 'reload schema';
COMMIT;
