-- Migration: Ovsync treni — K10 sunucu kilidi + K9 hastalık günü (ovsync treni D5)
-- Tarih: 2026-11-09. Spec docs/plans/2026-11-09-ovsync-tren/design.md (K9, K10, §5); PLAN.md D5, R3/R5; progress.md RL-1.
--   Önceki migration: 20261110100004. BEGIN/COMMIT yok: runbook ve test sarmalayıcısı dışarıdan sarar. Prod apply sahip kapısında.
-- Değişen 5 fonksiyon (imzalar aynı), gövdeleri prod (kanit/fn) gövdesinden kopyalandı; yalnız "D5" yorumlu satırlar değişti:
--   gorev_ertele, tohumlama_gorev_ertele (Ovsync görevi kilidi), vaka_kalan_gunleri_kaydir (OVSYNC vaka kilidi + tren etiketi
--   += p_gun, RL-1), vaka_kalan_gunleri_kaydir_coklu (Ovsync görevleri ayrılır → ovsync_atlanan), ovsync_hastalik_gunu_ekle
--   (iç bayrak, K9: ovsync_tren NULL, dönüşe tren_ayrildi).
-- Bayrak (ovsync_tren_aktif) 0 iken davranış eski ile birebir: kilit yardımcıları sessiz döner (ayar/çapa okunmaz), coklu kümesi boş,
--   etiket kolonu NULL olduğundan etiket UPDATE'leri satır bulmaz. Yalnız ek dönüş alanları (ovsync_atlanan:[], tren_ayrildi:false).
-- Önkoşul: 5 canlı gövdenin md5'i D0 tabanı (govde-taban.md); değilse <FN>_GOVDE_FARKLI ile durur.
-- Tarih yalnız TR: (now() AT TIME ZONE 'Europe/Istanbul')::date.
-- ROLLBACK: 5 fonksiyonu kanit/fn/<ad>.sql gövdeleriyle CREATE OR REPLACE et (imzalar aynı); ACL aynı kalır.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('public.gorev_ertele(uuid,date,time without time zone)', '2af93dfba299268b912175c628d4b05c', 'GOREV_ERTELE_GOVDE_FARKLI'),
    ('public.tohumlama_gorev_ertele(uuid,date,time without time zone)', 'd9b19df7d182ddd33bc67ccab7318b1e', 'TOHUMLAMA_GOREV_ERTELE_GOVDE_FARKLI'),
    ('public.vaka_kalan_gunleri_kaydir(uuid,integer)', '0f6e319096b3905e56df52dc20bdddc4', 'VAKA_KALAN_GUNLERI_KAYDIR_GOVDE_FARKLI'),
    ('public.vaka_kalan_gunleri_kaydir_coklu(uuid[],integer)', '09875ad70b8d98bdd87061738355a964', 'VAKA_KALAN_GUNLERI_KAYDIR_COKLU_GOVDE_FARKLI'),
    ('public.ovsync_hastalik_gunu_ekle(uuid,uuid,date,integer,jsonb,boolean,text)', '1765d756f499e3ecc36740e74a65d804', 'OVSYNC_HASTALIK_GUNU_EKLE_GOVDE_FARKLI')) AS v(imza, md5, kod) LOOP
    IF NOT COALESCE((SELECT md5(p.prosrc) FROM pg_catalog.pg_proc p WHERE p.oid = to_regprocedure(r.imza)) = r.md5, false) THEN
      RAISE EXCEPTION '%: canlı gövde D0 tabanı değil (govde-taban.md: %), D5 durdu', r.kod, r.imza;
    END IF;
  END LOOP;
END $$;

-- 1) gorev_ertele (imza aynı): adım 3 sonrası K10 kilidi
CREATE OR REPLACE FUNCTION public.gorev_ertele(p_gorev_id uuid, p_yeni_tarih date, p_yeni_saat time without time zone DEFAULT NULL::time without time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_g          public.gorev_log%ROWTYPE;
  v_bugun      date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  v_kural      jsonb;
  v_saat       time;
  v_hedef      timestamptz;
  v_yerel      timestamp;
  v_yeni_tarih date;
  v_yeni_saat  time;
  v_ilk_hedef  date;
  v_toplam     integer;
  v_max        integer;
  v_asim       integer;
  v_uyari      text;
  v_zincir     jsonb := '{}'::jsonb;
BEGIN
  -- 1) Görevi kilitle
  SELECT * INTO v_g FROM public.gorev_log WHERE id = p_gorev_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'sebep', 'GOREV_BULUNAMADI');
  END IF;
  IF p_yeni_tarih IS NULL THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'sebep', 'YENI_TARIH_BOS');
  END IF;

  -- 2) Kural: fail-closed (kayıtsız tip ASLA ertelenemez)
  v_kural := public.gorev_ertele_kural_get(v_g.gorev_tipi);
  IF NOT COALESCE((v_kural->>'ertelenebilir')::boolean, false) THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'sebep', 'TIP_ERTELENEMEZ',
      'gorev_tipi', v_g.gorev_tipi,
      'kural_kaynagi', CASE WHEN v_kural ? 'gorev_tipi' THEN 'tablo'
                            ELSE 'fail-closed-default' END);
  END IF;

  -- 3) Yalnız AÇIK görev
  IF COALESCE(v_g.tamamlandi, false) OR COALESCE(v_g.iptal, false) THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'sebep', 'GOREV_ACIK_DEGIL');
  END IF;

  -- D5 (K10/R5): tren açık, iç çağrı değil ve Ovsync görevi → OVSYNC_TREN_EKRANI (yalnız Ovsync ekranından düzenlenir)
  PERFORM public._ovsync_kilit_gorev(p_gorev_id);

  -- 4) Geçmiş tarih — TÜM tiplerde red
  IF p_yeni_tarih < v_bugun THEN
    RAISE EXCEPTION 'GECMIS_TARIH:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'gorev_tipi', v_g.gorev_tipi,
      'yeni_tarih', p_yeni_tarih, 'bugun', v_bugun);
  END IF;

  -- 5) Pencere: 'tohumlama' → _tohumlama_pencere yuvarlaması (dokunmadan çağır)
  IF v_kural->>'pencere_kurali' = 'tohumlama' THEN
    v_saat  := COALESCE(p_yeni_saat, v_g.hedef_saat, time '09:00');
    v_hedef := public._tohumlama_pencere((p_yeni_tarih + v_saat) AT TIME ZONE 'Europe/Istanbul');
    IF v_hedef < now() THEN
      RAISE EXCEPTION 'GECMIS_TARIH:%', jsonb_build_object(
        'gorev_id', p_gorev_id, 'gorev_tipi', v_g.gorev_tipi,
        'yeni_tarih', p_yeni_tarih, 'yeni_saat', v_saat,
        'hedef_at', v_hedef, 'simdi', now());
    END IF;
    v_yerel      := v_hedef AT TIME ZONE 'Europe/Istanbul';
    v_yeni_tarih := v_yerel::date;
    v_yeni_saat  := v_yerel::time;
  ELSE
    v_yeni_tarih := p_yeni_tarih;
    v_yeni_saat  := COALESCE(p_yeni_saat, v_g.hedef_saat, time '09:00');
  END IF;

  -- İlk hedef soyu: GOREV_ERTELE + TOHUMLAMA_ERTELE kayıtları (süreklilik —
  -- önceki RPC ile ertelenmiş görevin soyu yeni RPC'de devam eder)
  SELECT (l.payload->>'eski_tarih')::date INTO v_ilk_hedef
    FROM public.islem_log l
   WHERE l.tip IN ('GOREV_ERTELE', 'TOHUMLAMA_ERTELE')
     AND l.ref_tablo = 'gorev_log'
     AND l.ref_id = p_gorev_id::text
     AND l.payload ? 'eski_tarih'
   ORDER BY l.tarih ASC, l.degisim_txid ASC NULLS LAST
   LIMIT 1;
  v_ilk_hedef := COALESCE(v_ilk_hedef, v_g.hedef_tarih, v_yeni_tarih);
  v_toplam    := v_yeni_tarih - v_ilk_hedef;

  -- 6) Sert sınır (NULL = sınır YOK / MK2) ve uyarı eşiği
  v_max  := NULLIF(v_kural->>'max_erteleme_gun', '')::integer;
  v_asim := COALESCE(NULLIF(v_kural->>'asimi_uyari_gun', '')::integer, 7);
  IF v_max IS NOT NULL AND v_toplam > v_max THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object(
      'gorev_id', p_gorev_id, 'sebep', 'MAX_ASIM',
      'gorev_tipi', v_g.gorev_tipi, 'max_erteleme_gun', v_max,
      'toplam_erteleme_gun', v_toplam, 'ilk_hedef_tarih', v_ilk_hedef);
  END IF;
  v_uyari := CASE WHEN v_toplam > v_asim
                  THEN 'ERTELEME_' || v_asim || '_GUN_ASILDI' END;

  -- 7) Görevi taşı
  UPDATE public.gorev_log
     SET hedef_tarih = v_yeni_tarih, hedef_saat = v_yeni_saat
   WHERE id = p_gorev_id;

  -- 8) OVSYNC_BASLAT zincir raporu — kaynak anahtarı BİLİNÇLİ korunur
  --    (çift-görev koruması idempotans katmanlarındadır; kırıntı 17:35)
  IF v_g.gorev_tipi = 'OVSYNC_BASLAT' THEN
    v_zincir := jsonb_build_object(
      'ovsync_baslat', true,
      'kaynak_ref', (SELECT pi.kaynak_ref FROM public.protokol_instance pi
                      WHERE pi.id = v_g.protokol_instance_id),
      'cift_gorev_korumasi', jsonb_build_array(
        'protokol_instance_kaynak_unique',
        'acik_disi_hedef_ic_acik_gorev_kontrolu'),
      'not', 'Anahtar bilincli korunur: acik OVSYNC_BASLAT = zincir baslamamis; TAI start_first_service_protocol aninda turetilir.');
  END IF;

  -- Audit (TOHUMLAMA_ERTELE kalıbının geneli)
  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot, kullanici_notu)
  VALUES ('GOREV_ERTELE', v_g.hayvan_id, p_gorev_id::text, 'gorev_log',
          jsonb_build_object(
            'gorev_id', p_gorev_id, 'gorev_tipi', v_g.gorev_tipi,
            'eski_tarih', v_g.hedef_tarih, 'eski_saat', v_g.hedef_saat,
            'yeni_tarih', v_yeni_tarih, 'yeni_saat', v_yeni_saat,
            'ilk_hedef_tarih', v_ilk_hedef,
            'toplam_erteleme_gun', v_toplam, 'uyari', v_uyari,
            'zincir', v_zincir),
          jsonb_build_object(
            'olusturulan', '[]'::jsonb,
            'guncellenen', jsonb_build_array(jsonb_build_object(
              'tablo', 'gorev_log', 'id', p_gorev_id::text,
              'onceki',  jsonb_build_object('hedef_tarih', v_g.hedef_tarih, 'hedef_saat', v_g.hedef_saat),
              'sonraki', jsonb_build_object('hedef_tarih', v_yeni_tarih, 'hedef_saat', v_yeni_saat))),
            'silinen', '[]'::jsonb),
          format('Gorev ertelendi (%s): %s %s -> %s %s',
                 v_g.gorev_tipi, v_g.hedef_tarih, v_g.hedef_saat, v_yeni_tarih, v_yeni_saat));

  RETURN jsonb_build_object(
    'ok', true, 'gorev_id', p_gorev_id, 'gorev_tipi', v_g.gorev_tipi,
    'hedef_tarih', v_yeni_tarih, 'hedef_saat', v_yeni_saat,
    'ilk_hedef_tarih', v_ilk_hedef, 'toplam_erteleme_gun', v_toplam,
    'uyari', v_uyari, 'zincir', v_zincir);
END;
$function$;

-- 2) tohumlama_gorev_ertele (imza aynı): açık-görev kontrolü sonrası K10 kilidi
CREATE OR REPLACE FUNCTION public.tohumlama_gorev_ertele(p_gorev_id uuid, p_yeni_tarih date, p_yeni_saat time without time zone DEFAULT NULL::time without time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_g          record;
  v_bugun      date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
  v_saat       time;
  v_hedef      timestamptz;
  v_yerel      timestamp;
  v_yeni_tarih date;
  v_yeni_saat  time;
  v_ilk_hedef  date;
  v_toplam     integer;
  v_uyari      text;
BEGIN
  SELECT * INTO v_g FROM public.gorev_log WHERE id = p_gorev_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object('gorev_id', p_gorev_id, 'sebep', 'GOREV_BULUNAMADI');
  END IF;
  IF v_g.gorev_tipi IS DISTINCT FROM 'TOHUMLAMA_PLANLI' THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object('gorev_id', p_gorev_id, 'sebep', 'TIP_UYGUN_DEGIL', 'gorev_tipi', v_g.gorev_tipi);
  END IF;
  IF COALESCE(v_g.tamamlandi, false) OR COALESCE(v_g.iptal, false) THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object('gorev_id', p_gorev_id, 'sebep', 'GOREV_ACIK_DEGIL');
  END IF;

  -- D5 (K10/R5): tren açık, iç çağrı değil ve Ovsync görevi → OVSYNC_TREN_EKRANI (yalnız Ovsync ekranından düzenlenir)
  PERFORM public._ovsync_kilit_gorev(p_gorev_id);
  IF p_yeni_tarih IS NULL THEN
    RAISE EXCEPTION 'GOREV_ERTELENEMEZ:%', jsonb_build_object('gorev_id', p_gorev_id, 'sebep', 'YENI_TARIH_BOS');
  END IF;
  IF p_yeni_tarih < v_bugun THEN
    RAISE EXCEPTION 'GECMIS_TARIH:%', jsonb_build_object('gorev_id', p_gorev_id, 'yeni_tarih', p_yeni_tarih, 'bugun', v_bugun);
  END IF;

  v_saat  := COALESCE(p_yeni_saat, v_g.hedef_saat, time '09:00');
  v_hedef := public._tohumlama_pencere((p_yeni_tarih + v_saat) AT TIME ZONE 'Europe/Istanbul');
  IF v_hedef < now() THEN
    RAISE EXCEPTION 'GECMIS_TARIH:%', jsonb_build_object('gorev_id', p_gorev_id, 'yeni_tarih', p_yeni_tarih,
      'yeni_saat', v_saat, 'hedef_at', v_hedef, 'simdi', now());
  END IF;
  v_yerel := v_hedef AT TIME ZONE 'Europe/Istanbul';
  v_yeni_tarih := v_yerel::date;
  v_yeni_saat  := v_yerel::time;

  SELECT (l.payload->>'eski_tarih')::date INTO v_ilk_hedef
    FROM public.islem_log l
   WHERE l.tip = 'TOHUMLAMA_ERTELE'
     AND l.ref_tablo = 'gorev_log'
     AND l.ref_id = p_gorev_id::text
     AND l.payload ? 'eski_tarih'
   ORDER BY l.tarih ASC, l.degisim_txid ASC NULLS LAST
   LIMIT 1;
  v_ilk_hedef := COALESCE(v_ilk_hedef, v_g.hedef_tarih, v_yeni_tarih);

  v_toplam := v_yeni_tarih - v_ilk_hedef;
  v_uyari  := CASE WHEN v_toplam > 7 THEN 'ERTELEME_7_GUN_ASILDI' END;

  UPDATE public.gorev_log
     SET hedef_tarih = v_yeni_tarih, hedef_saat = v_yeni_saat
   WHERE id = p_gorev_id;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, payload, snapshot, kullanici_notu)
  VALUES ('TOHUMLAMA_ERTELE', v_g.hayvan_id, p_gorev_id::text, 'gorev_log',
          jsonb_build_object(
            'gorev_id', p_gorev_id,
            'eski_tarih', v_g.hedef_tarih, 'eski_saat', v_g.hedef_saat,
            'yeni_tarih', v_yeni_tarih, 'yeni_saat', v_yeni_saat,
            'ilk_hedef_tarih', v_ilk_hedef,
            'toplam_erteleme_gun', v_toplam, 'uyari', v_uyari),
          jsonb_build_object(
            'olusturulan', '[]'::jsonb,
            'guncellenen', jsonb_build_array(jsonb_build_object(
              'tablo', 'gorev_log', 'id', p_gorev_id::text,
              'onceki',  jsonb_build_object('hedef_tarih', v_g.hedef_tarih, 'hedef_saat', v_g.hedef_saat),
              'sonraki', jsonb_build_object('hedef_tarih', v_yeni_tarih, 'hedef_saat', v_yeni_saat))),
            'silinen', '[]'::jsonb),
          format('Planlı tohumlama görevi ertelendi: %s %s → %s %s',
                 v_g.hedef_tarih, v_g.hedef_saat, v_yeni_tarih, v_yeni_saat));

  RETURN jsonb_build_object(
    'ok', true, 'gorev_id', p_gorev_id,
    'hedef_tarih', v_yeni_tarih, 'hedef_saat', v_yeni_saat,
    'ilk_hedef_tarih', v_ilk_hedef, 'toplam_erteleme_gun', v_toplam,
    'uyari', v_uyari);
END;
$function$;

-- 3) vaka_kalan_gunleri_kaydir (imza aynı): vaka kilidi sonrası K10 kilidi; başarılı kaydırmada ovsync_tren += p_gun (RL-1)
CREATE OR REPLACE FUNCTION public.vaka_kalan_gunleri_kaydir(p_case_id uuid, p_gun integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
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

  -- D5 (K10/R5): tren açık, iç çağrı değil ve aktif OVSYNC vaka → OVSYNC_TREN_EKRANI (Ovsync ekranı iç bayrakla çağırır)
  PERFORM public._ovsync_kilit_vaka(p_case_id);

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

  -- D5 (RL-1, R3): tren etiketi ritim sınıfıdır; günler p_gun kaydıysa etiket de aynı işlemde kayar (tek yer: çağıranlar
  --    ayrıca artırmaz). Yalnız trendeki vaka; bayrak 0'da kolon NULL → satır güncellenmez (değişim kaydı doğmaz).
  UPDATE public.cases SET ovsync_tren = ovsync_tren + p_gun
   WHERE id = p_case_id AND ovsync_tren IS NOT NULL;

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

-- 4) vaka_kalan_gunleri_kaydir_coklu (imza aynı): Ovsync vakalarının görevleri ayrılır, dönüş/islem_log ovsync_atlanan
CREATE OR REPLACE FUNCTION public.vaka_kalan_gunleri_kaydir_coklu(p_gorev_ids uuid[], p_gun integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_sonuc         jsonb;
  v_gid           uuid;
  v_case_id       uuid;
  v_toplam        integer := 0;
  v_kaydirilan    integer := 0;
  v_atlanan       integer := 0;
  v_hatalar       jsonb   := '[]'::jsonb;
  v_detaylar      jsonb   := '[]'::jsonb;
  v_ovsync_vakalar uuid[] := '{}'::uuid[];   -- D5 (K10): döngüden ayrılan aktif OVSYNC vakaları
  v_ovsync_atlanan jsonb  := '[]'::jsonb;    -- D5: [{gorev_id, case_id, hayvan_id, kupe_no}]
BEGIN
  -- 0) Fail-fast guard'lar: hiçbir vaka dokunulmadan düşer — tekli RPC ile
  --    aynı VAKA_KAYDIRILAMAZ ailesi.
  IF p_gorev_ids IS NULL OR array_length(p_gorev_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'VAKA_KAYDIRILAMAZ:%', jsonb_build_object('sebep', 'BOS_LISTE');
  END IF;

  IF p_gun IS NULL OR p_gun < 1 OR p_gun > 31 THEN
    RAISE EXCEPTION 'VAKA_KAYDIRILAMAZ:%', jsonb_build_object('sebep', 'GECERSIZ_GUN', 'gun', p_gun);
  END IF;

  IF cardinality(p_gorev_ids) > 200 THEN
    RAISE EXCEPTION 'VAKA_KAYDIRILAMAZ:%', jsonb_build_object(
      'sebep', 'LIMIT_ASIM', 'istek', cardinality(p_gorev_ids), 'limit', 200);
  END IF;

  -- 1+2) Görev → vaka çözümleme (CTE): çözülemeyen görevler hata dizisine
  --    satır olarak düşer (fail-fast DEĞİL; NULL girdi elemanı dahil —
  --    DISTINCT sayesinde her biri bir kez).
  --    Yüzey yüklemi: açık (tamamlandi/iptal = false) TEDAVI_GUN/TEDAVI_SEANS
  --    + '{' ile başlayan JSON aciklama + day_id'sine eşlenen treatment_days
  --    satırı — iç RPC'nin kabul ettiği kümeyle birebir.
  --    Not: aciklama::jsonb cast'i CASE içinde değerlendirilir — cast'in
  --    'left(aciklama,1)=' kontrolünden önce çalışmasını planner
  --    sıralamasına bırakamaz (CASE değerlendirme sırasını garanti eder;
  --    NULL/bozuk aciklama hata değil çözülemedi demektir).
  FOR v_gid IN
    WITH giris AS (
        SELECT DISTINCT unnest(p_gorev_ids) AS gid)
      , cozulen AS (
        SELECT gi.gid, td.case_id
          FROM giris gi
          JOIN public.gorev_log g
            ON g.id = gi.gid
           AND g.gorev_tipi IN ('TEDAVI_GUN', 'TEDAVI_SEANS')
           AND COALESCE(g.tamamlandi, false) = false
           AND COALESCE(g.iptal, false) = false
           AND left(g.aciklama, 1) = '{'
          JOIN public.treatment_days td
            ON td.id::text =
               (CASE WHEN left(g.aciklama, 1) = '{'
                     THEN g.aciklama::jsonb ->> 'day_id' END))
    SELECT gid FROM (SELECT gid FROM giris EXCEPT SELECT gid FROM cozulen) k
    ORDER BY gid
  LOOP
    v_hatalar := v_hatalar || jsonb_build_object('gorev_id', v_gid, 'sebep', 'GOREV_COZULEMEDI');
  END LOOP;

  -- D5 (K10/R5): tren açık ve iç çağrı değilken aktif OVSYNC vakalarının görevleri döngüden ÖNCE ayrılır; Ovsync ekranından
  --    düzenlenir. Görev başına ovsync_atlanan satırı döner; bu satırlar toplam/atlanan/hatalar'a girmez. Yüklem 'cozulen' CTE'sinin
  --    ÜÇÜNCÜ birebir kopyasıdır (senkron tutulmalı). Bayrak 0 ya da iç çağrıda küme boş → davranış eski (+ boş alan).
  IF public._ovsync_tren_aktif() AND NOT public._ovsync_ic_mi() THEN
    WITH giris AS (
        SELECT DISTINCT unnest(p_gorev_ids) AS gid)
      , cozulen AS (
        SELECT gi.gid, td.case_id
          FROM giris gi
          JOIN public.gorev_log g
            ON g.id = gi.gid
           AND g.gorev_tipi IN ('TEDAVI_GUN', 'TEDAVI_SEANS')
           AND COALESCE(g.tamamlandi, false) = false
           AND COALESCE(g.iptal, false) = false
           AND left(g.aciklama, 1) = '{'
          JOIN public.treatment_days td
            ON td.id::text =
               (CASE WHEN left(g.aciklama, 1) = '{'
                     THEN g.aciklama::jsonb ->> 'day_id' END))
    SELECT COALESCE(array_agg(DISTINCT c.id), '{}'::uuid[]),
           COALESCE(jsonb_agg(jsonb_build_object('gorev_id', x.gid, 'case_id', c.id, 'hayvan_id', c.animal_id,
                                                 'kupe_no', h.kupe_no) ORDER BY x.gid), '[]'::jsonb)
      INTO v_ovsync_vakalar, v_ovsync_atlanan
      FROM cozulen x
      JOIN public.cases c ON c.id = x.case_id AND c.status = 'active' AND c.protocol_family = 'OVSYNC'
      LEFT JOIN public.hayvanlar h ON h.id = c.animal_id;
  END IF;

  -- 3) DISTINCT sıralı vaka kümesi: dedup garantili (aynı vakaya bağlı çok
  --    görev tek kaydırma). Yüklem adım 1+2'deki 'cozulen' CTE'si ile BİREBİR
  --    aynıdır (tek tanım çıkarılamaz — CTE deyim-yereldir; iki kopya
  --    senkron tutulmalı). Vaka alt-işlemi: iç RPC raisesa yalnız o vakanın
  --    etkileri geri sarar (plpgsql EXCEPTION = alt-işlem), diğer vakalar
  --    yoluna devam eder → kısmi başarı.
  FOR v_case_id IN
    WITH giris AS (
        SELECT DISTINCT unnest(p_gorev_ids) AS gid)
      , cozulen AS (
        SELECT gi.gid, td.case_id
          FROM giris gi
          JOIN public.gorev_log g
            ON g.id = gi.gid
           AND g.gorev_tipi IN ('TEDAVI_GUN', 'TEDAVI_SEANS')
           AND COALESCE(g.tamamlandi, false) = false
           AND COALESCE(g.iptal, false) = false
           AND left(g.aciklama, 1) = '{'
          JOIN public.treatment_days td
            ON td.id::text =
               (CASE WHEN left(g.aciklama, 1) = '{'
                     THEN g.aciklama::jsonb ->> 'day_id' END))
    SELECT DISTINCT case_id
      FROM cozulen
     WHERE case_id IS NOT NULL
       AND NOT (case_id = ANY (v_ovsync_vakalar))   -- D5: ayrılan OVSYNC vakaları
     ORDER BY case_id
  LOOP
    v_toplam := v_toplam + 1;
    BEGIN
      SELECT public.vaka_kalan_gunleri_kaydir(v_case_id, p_gun) INTO v_sonuc;
      v_kaydirilan := v_kaydirilan + 1;
      v_detaylar := v_detaylar || jsonb_build_object(
        'case_id', v_case_id,
        'ilk_tarih', v_sonuc -> 'ilk_tarih',
        'son_tarih', v_sonuc -> 'son_tarih',
        'tasinan_gun_satiri', v_sonuc -> 'tasinan_gun_satiri',
        'tasinan_gorev', v_sonuc -> 'tasinan_gorev',
        'tasinan_seans', v_sonuc -> 'tasinan_seans',
        'tasinan_uygulama_satiri', v_sonuc -> 'tasinan_uygulama_satiri',
        'tai', v_sonuc -> 'tai');
    EXCEPTION WHEN OTHERS THEN
      -- Kısmi başarı: hata satır olarak döner (SQLERRM AYNEN — iç RPC'nin
      -- VAKA_KAYDIRILAMAZ:<json> mesajı UI'da ayırt edilebilir kalır).
      v_hatalar := v_hatalar || jsonb_build_object('case_id', v_case_id, 'sebep', SQLERRM);
      IF position('VAKA_ACIK_DEGIL' IN SQLERRM) > 0 THEN
        v_atlanan := v_atlanan + 1;
      END IF;
    END;
  END LOOP;

  -- 4) Audit: TEK özet kaydı (vaka-başına VAKA_KAYDIR iç RPC'den gelir;
  --    islem_log immutable, farm_id taşımayan global log).
  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, payload, snapshot, kullanici_notu)
  VALUES (
    'VAKA_KAYDIR_TOPLU',
    NULL,
    'cases',
    jsonb_build_object(
      'gun', p_gun,
      'toplam', v_toplam,
      'kaydirilan', v_kaydirilan,
      'atlanan', v_atlanan,
      'hatalar', v_hatalar,
      'ovsync_atlanan', v_ovsync_atlanan),   -- D5
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', '[]'::jsonb,
      'silinen', '[]'::jsonb),
    format('Coklu vaka kaydirma: +%s gun | %s vaka isleme alindi, %s kaydirildi, %s atlandi, %s hata satiri',
           p_gun, v_toplam, v_kaydirilan, v_atlanan, jsonb_array_length(v_hatalar)));

  -- 5) Dönüş: kısmi başarı özeti (ok=true, ayrıntı hatalar/detaylar'da).
  RETURN jsonb_build_object(
    'ok', true,
    'toplam', v_toplam,
    'kaydirilan', v_kaydirilan,
    'atlanan', v_atlanan,
    'hatalar', v_hatalar,
    'detaylar', v_detaylar,
    'ovsync_atlanan', v_ovsync_atlanan);   -- D5
END;
$function$;

-- 5) ovsync_hastalik_gunu_ekle (imza aynı): iç bayrak, K9 tren etiketi düşer, dönüşe tren_ayrildi
CREATE OR REPLACE FUNCTION public.ovsync_hastalik_gunu_ekle(p_case_id uuid, p_hastalik_id uuid DEFAULT NULL::uuid, p_tarih date DEFAULT NULL::date, p_gun integer DEFAULT 7, p_ilaclar jsonb DEFAULT '[]'::jsonb, p_pg_onay boolean DEFAULT NULL::boolean, p_pg_gerekce text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_case      record;
  v_kisir     boolean;
  v_hastalik  uuid;
  v_tarih     date := COALESCE(p_tarih, (now() AT TIME ZONE 'Europe/Istanbul')::date);
  v_gun       integer := COALESCE(p_gun, 7);
  v_day_id    uuid;
  v_ilac      jsonb;
  v_yazilan   integer := 0;
  v_g         record;
  v_ertelenen integer := 0;
  v_tren_ayrildi boolean := false;   -- D5 (K9)
BEGIN
  -- D5 (K10/R5): Ovsync ekranı RPC'si; iç TAI ötelemesi (tohumlama_gorev_ertele) kilidi işlem-yerel bayrakla aşar.
  PERFORM public._ovsync_ic_ac();

  IF v_gun < 0 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'GUN_NEGATIF');
  END IF;

  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'OVSYNC_VAKA_BULUNAMADI');
  END IF;
  IF v_case.status IS DISTINCT FROM 'active' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'VAKA_KAPALI');
  END IF;
  -- Vaka kabulü = yedek-Ovsync tanımı (TEK yer: _vaka_ovsync_mu).
  IF NOT public._vaka_ovsync_mu(p_case_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'ANA_ACIK_OVSYNC_DEGIL');
  END IF;
  SELECT COALESCE(kisir, false) INTO v_kisir FROM public.hayvanlar WHERE id = v_case.animal_id;
  IF COALESCE(v_kisir, false) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'KISIR_HAYVANA_HASTALIK_GUNU_YOK');
  END IF;

  v_hastalik := p_hastalik_id;
  IF v_hastalik IS NULL THEN
    SELECT id INTO v_hastalik FROM public.diseases WHERE name = 'İnaktif Ovaryum' LIMIT 1;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'error', 'INAKTIF_HASTALIK_YOK');
    END IF;
  ELSIF NOT EXISTS (SELECT 1 FROM public.diseases WHERE id = v_hastalik) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'HASTALIK_BULUNAMADI');
  END IF;

  -- Idempotent gün-aç: vaka satır kilidi çift-tık yarışını seriler; yine de
  -- araya giren yazma unique'e takılırsa mevcut gün okunur (kayıp güncelleme yok).
  SELECT id INTO v_day_id FROM public.treatment_days
   WHERE case_id = p_case_id AND disease_id = v_hastalik AND treatment_date = v_tarih;
  IF FOUND THEN
    RETURN jsonb_build_object('ok', true, 'gun_id', v_day_id, 'mevcut', true,
      'ertelenen', 0, 'ilac', 0, 'tren_ayrildi', false);   -- D5
  END IF;
  BEGIN
    -- id açık üretilir: constraint-free aynalarda kolon DEFAULT'u yoktur;
    -- gerçek şemalarda explicit değer default'u ezmesi zararsızdır.
    INSERT INTO public.treatment_days(id, case_id, treatment_date, disease_id)
      VALUES (gen_random_uuid(), p_case_id, v_tarih, v_hastalik) RETURNING id INTO v_day_id;
  EXCEPTION WHEN unique_violation THEN
    SELECT id INTO v_day_id FROM public.treatment_days
     WHERE case_id = p_case_id AND disease_id = v_hastalik AND treatment_date = v_tarih;
    RETURN jsonb_build_object('ok', true, 'gun_id', v_day_id, 'mevcut', true,
      'ertelenen', 0, 'ilac', 0, 'tren_ayrildi', false);   -- D5
  END;

  -- D5 (K9/R3): hastalık günü girilen hayvan bağımsız devam eder → tren etiketi düşer (yalnız doluysa; bayrak 0'da satır yok).
  -- D9 (RD9-3b): aynı UPDATE'te bağımsız işareti (R14 göçü bu vakayı bir daha trene bağlamaz).
  UPDATE public.cases SET ovsync_tren = NULL, ovsync_bagimsiz = true WHERE id = p_case_id AND ovsync_tren IS NOT NULL;
  v_tren_ayrildi := FOUND;

  -- İlaçlar o günün altına (PG sarmalı add_drug_administration içindedir;
  -- PG_KAPI:* blokları istisna olarak yükselir, burada yutulmaz).
  -- D5: pg_catalog. öneki yalnız db-validate statik denetimi için (FROM <ad> tablo sanılıyordu); çözümleme aynı fonksiyon.
  FOR v_ilac IN SELECT * FROM pg_catalog.jsonb_array_elements(COALESCE(p_ilaclar, '[]'::jsonb)) LOOP
    PERFORM public.add_drug_administration(v_day_id,
      (v_ilac->>'drug_product_id')::uuid, v_ilac->>'stok_id',
      (v_ilac->>'dose')::numeric, v_ilac->>'unit', v_ilac->>'route',
      p_pg_onay, p_pg_gerekce);
    v_yazilan := v_yazilan + 1;
  END LOOP;

  -- Açık TAI'leri ötele (iptal YOK; kaydır RPC çağrılmaz). §7.2: yalnız AKTİF
  -- TAI (iptal/tamamlanmış/kapatan_ref'li hariç).
  FOR v_g IN SELECT id, hedef_tarih, hedef_saat FROM public.gorev_log
              WHERE hayvan_id = v_case.animal_id AND gorev_tipi = 'TOHUMLAMA_PLANLI'
                AND NOT COALESCE(tamamlandi, false) AND NOT COALESCE(iptal, false)
                AND kapatan_ref IS NULL
              ORDER BY id
              FOR UPDATE LOOP
    PERFORM public.tohumlama_gorev_ertele(v_g.id, v_g.hedef_tarih + v_gun, v_g.hedef_saat);
    v_ertelenen := v_ertelenen + 1;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'gun_id', v_day_id, 'mevcut', false,
    'ertelenen', v_ertelenen, 'ilac', v_yazilan,
    'tren_ayrildi', v_tren_ayrildi);   -- D5
END;
$function$;

-- ACL (Supabase varsayılan yetkisi anon'a EXECUTE verir): CREATE OR REPLACE edilen 5 RPC'de satırlar tekrarlanır; canlıdaki gibi
-- authenticated + service_role açık kalır.
REVOKE ALL ON FUNCTION public.gorev_ertele(uuid, date, time without time zone) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.gorev_ertele(uuid, date, time without time zone) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.tohumlama_gorev_ertele(uuid, date, time without time zone) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tohumlama_gorev_ertele(uuid, date, time without time zone) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.vaka_kalan_gunleri_kaydir(uuid, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vaka_kalan_gunleri_kaydir(uuid, integer) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.vaka_kalan_gunleri_kaydir_coklu(uuid[], integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.vaka_kalan_gunleri_kaydir_coklu(uuid[], integer) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.ovsync_hastalik_gunu_ekle(uuid, uuid, date, integer, jsonb, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ovsync_hastalik_gunu_ekle(uuid, uuid, date, integer, jsonb, boolean, text) TO authenticated, service_role;
