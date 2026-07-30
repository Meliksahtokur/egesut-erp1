-- Protokol scanner: ileri-gebe adımlarında gerçek görev tarihini otorite kabul et.
--
-- Sorun: protokol_eksik_tara ileri-gebe hedefini tohumlama tarihinden yeniden
-- hesaplıyor ve tamamlanan görevleri yalnız bu kanonik tarihin +/-3 gününde
-- arıyordu. Kullanıcı görevi ertelediğinde gorev_log doğru biçimde kapanmasına
-- rağmen scanner eski kanonik tarihten yeni bir "eksik" uyarı üretiyordu.
--
-- Çözüm: aynı aktif gebelik protokol_instance'ındaki etken_kod görevini önce
-- bul; görev varsa düzenlenmiş hedef tarihi ve durumunu otorite kabul et.
-- Instance bağlantısı olmayan legacy görevlerde mevcut kanonik tarih fallback'i
-- aynen korunur.

CREATE OR REPLACE FUNCTION public.protokol_eksik_tara()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_result jsonb := '[]'::jsonb;
  v_today date := CURRENT_DATE;
  v_rec record;
  v_found boolean;
  v_tamamlanma timestamptz;
  v_kapatan text;
BEGIN

  -- ═══ A. DOĞUM SONRASI PROTOKOL (0-63 gün) ═══
  FOR v_rec IN
    SELECT d.id AS dogum_id, d.anne_id AS hayvan_id, d.tarih AS dogum_tarihi,
           h.kupe_no, h.grup,
           a.gun, a.ek, a.aciklama
    FROM (
      SELECT DISTINCT ON (anne_id) *
      FROM public.dogum
      ORDER BY anne_id, tarih DESC
    ) d
    JOIN public.hayvanlar h ON h.id = d.anne_id AND h.durum = 'Aktif'
    CROSS JOIN (VALUES
      (0,  'OKSITOSIN', 'Doğum günü: Oksitosin'),
      (0,  'ADEMIN',    'Doğum günü: Ademin'),
      (0,  'KALSIYUM',  'Doğum günü: Kalsiyum'),
      (2,  'PG',        '2. Gün PG'),
      (39, 'PG',        '39. Gün PG (Presynch-14 senkron)'),
      (25, 'PG',        '25. Gün PG'),
      (53, 'ADEMIN',    '53. Gün: Ademin'),
      (53, 'E_VIT',     '53. Gün: E Vitamini')
    ) AS a(gun, ek, aciklama)
    WHERE d.tarih >= v_today - 70
      AND d.tarih <= v_today
  LOOP
    DECLARE
      v_hedef date := v_rec.dogum_tarihi + v_rec.gun;
      v_gecikme int;
      v_durum text;
    BEGIN
      IF v_hedef > v_today + 7 THEN CONTINUE; END IF;

      v_found := false;
      v_tamamlanma := NULL;
      v_kapatan := NULL;

      SELECT true, g.tamamlanma_tarihi, g.kapatan_ref
      INTO v_found, v_tamamlanma, v_kapatan
      FROM gorev_log g
      WHERE g.hayvan_id = v_rec.hayvan_id
        AND g.etken_kod = v_rec.ek
        AND g.tamamlandi = true
        AND g.hedef_tarih BETWEEN v_hedef - 3 AND v_hedef + 3
      LIMIT 1;

      IF v_found IS NOT TRUE THEN
        SELECT true INTO v_found
        FROM uygulama_log u
        WHERE u.hayvan_id = v_rec.hayvan_id
          AND (u.etken_kod = v_rec.ek
               OR public._etken_kod_bul(u.stok_id, NULL) = v_rec.ek)
          AND u.tarih BETWEEN v_hedef - 3 AND v_hedef + 3
        LIMIT 1;
      END IF;

      IF v_found IS NOT TRUE THEN
        SELECT true INTO v_found
        FROM drug_administrations da
        JOIN treatment_days td ON td.id = da.treatment_day_id
        JOIN cases c ON c.id = td.case_id
        WHERE c.animal_id = v_rec.hayvan_id
          AND public._etken_kod_bul(da.stok_id, NULL) = v_rec.ek
          AND da.created_at::date BETWEEN v_hedef - 3 AND v_hedef + 3
        LIMIT 1;
      END IF;

      IF v_found IS NOT TRUE THEN
        SELECT true INTO v_found
        FROM protokol_dismiss pd
        WHERE pd.hayvan_id = v_rec.hayvan_id
          AND pd.etken_kod = v_rec.ek
          AND pd.protokol = 'DOGUM_PROTOKOL'
        LIMIT 1;
      END IF;

      v_gecikme := v_today - v_hedef;

      IF v_found AND v_tamamlanma IS NOT NULL AND v_tamamlanma >= now() - interval '24 hours' THEN
        v_durum := 'tamamlandi';
      ELSIF v_found THEN
        CONTINUE;
      ELSIF v_gecikme >= 0 THEN
        v_durum := 'eksik';
      ELSE
        v_durum := 'yaklasan';
      END IF;

      v_result := v_result || jsonb_build_object(
        'hayvan_id', v_rec.hayvan_id,
        'kupe_no', v_rec.kupe_no,
        'grup', v_rec.grup,
        'protokol', 'DOGUM_PROTOKOL',
        'adim', v_rec.aciklama,
        'etken_kod', v_rec.ek,
        'hedef_tarih', v_hedef,
        'gecikme_gun', v_gecikme,
        'durum', v_durum,
        'tamamlanma_tarihi', v_tamamlanma,
        'kapatan_ref', v_kapatan
      );
    END;
  END LOOP;

  -- ═══ B. İLERI GEBE PROTOKOL (240-265 gün) ═══
  FOR v_rec IN
    SELECT t.id AS toh_id, t.hayvan_id, t.tarih AS toh_tarihi,
           h.kupe_no, h.grup
    FROM public.tohumlama t
    JOIN public.hayvanlar h ON h.id = t.hayvan_id AND h.durum = 'Aktif'
    WHERE t.sonuc = 'Gebe'
      AND (v_today - t.tarih::date) >= 230
  LOOP
    DECLARE
      v_a record;
    BEGIN
      FOR v_a IN
        SELECT * FROM (VALUES
          (240, 'ROTA',   '💉 Rota-Corona Aşısı'),
          (260, 'ADEMIN', '💊 SC Ademin uygulaması'),
          (265, 'E_VIT',  '💊 IM E Vitamini uygulaması')
        ) AS t(gun, ek, aciklama)
      LOOP
        DECLARE
          v_hedef date := v_rec.toh_tarihi::date + v_a.gun;
          v_gecikme int;
          v_durum text;
          v_task_exists boolean := false;
          v_task_tamamlandi boolean := false;
          v_task_hedef date;
        BEGIN
          IF v_hedef > v_today + 7 THEN CONTINUE; END IF;

          v_found := false;
          v_tamamlanma := NULL;
          v_kapatan := NULL;

          -- Mevcut aktif gebelik instance'ındaki gerçek görev otoritedir.
          -- Tamamlanan kayıt varsa onu; yoksa en yeni açık görevi seç.
          SELECT true, g.hedef_tarih, g.tamamlandi,
                 g.tamamlanma_tarihi, g.kapatan_ref
          INTO v_task_exists, v_task_hedef, v_task_tamamlandi,
               v_tamamlanma, v_kapatan
          FROM gorev_log g
          JOIN protokol_instance pi ON pi.id = g.protokol_instance_id
          WHERE g.hayvan_id = v_rec.hayvan_id
            AND g.etken_kod = v_a.ek
            AND NOT COALESCE(g.iptal, false)
            AND pi.hayvan_id = v_rec.hayvan_id
            AND pi.tip = 'UREME'
            AND pi.alttip = 'GEBELIK'
            AND pi.baslangic = v_rec.toh_tarihi::date
            AND pi.durum = 'aktif'
          ORDER BY g.tamamlandi DESC, g.created_at DESC
          LIMIT 1;

          IF v_task_exists IS TRUE THEN
            v_hedef := v_task_hedef;
            v_found := v_task_tamamlandi;
          ELSE
            -- Instance bağlantısı olmayan legacy görevler için mevcut davranış.
            SELECT true, g.tamamlanma_tarihi, g.kapatan_ref
            INTO v_found, v_tamamlanma, v_kapatan
            FROM gorev_log g
            WHERE g.hayvan_id = v_rec.hayvan_id
              AND g.etken_kod = v_a.ek
              AND g.tamamlandi = true
              AND g.hedef_tarih BETWEEN v_hedef - 3 AND v_hedef + 3
            LIMIT 1;
          END IF;

          IF v_found IS NOT TRUE AND v_a.ek = 'ROTA' THEN
            SELECT true INTO v_found
            FROM vaccination_log vl
            JOIN vaccines v ON v.id = vl.vaccine_id
            WHERE vl.animal_id = v_rec.hayvan_id
              AND v.name ILIKE '%Rota%'
              AND vl.vaccination_date BETWEEN v_hedef - 7 AND v_hedef + 7
            LIMIT 1;
          END IF;

          IF v_found IS NOT TRUE THEN
            SELECT true INTO v_found
            FROM uygulama_log u
            WHERE u.hayvan_id = v_rec.hayvan_id
              AND (u.etken_kod = v_a.ek
                   OR public._etken_kod_bul(u.stok_id, NULL) = v_a.ek)
              AND u.tarih BETWEEN v_hedef - 3 AND v_hedef + 3
            LIMIT 1;
          END IF;

          IF v_found IS NOT TRUE THEN
            SELECT true INTO v_found
            FROM drug_administrations da
            JOIN treatment_days td ON td.id = da.treatment_day_id
            JOIN cases c ON c.id = td.case_id
            WHERE c.animal_id = v_rec.hayvan_id
              AND public._etken_kod_bul(da.stok_id, NULL) = v_a.ek
              AND da.created_at::date BETWEEN v_hedef - 3 AND v_hedef + 3
            LIMIT 1;
          END IF;

          IF v_found IS NOT TRUE THEN
            SELECT true INTO v_found
            FROM protokol_dismiss pd
            WHERE pd.hayvan_id = v_rec.hayvan_id
              AND pd.etken_kod = v_a.ek
              AND pd.protokol = 'ILERI_GEBE_PROTOKOL'
            LIMIT 1;
          END IF;

          v_gecikme := v_today - v_hedef;

          IF v_found AND v_tamamlanma IS NOT NULL AND v_tamamlanma >= now() - interval '24 hours' THEN
            v_durum := 'tamamlandi';
          ELSIF v_found THEN
            CONTINUE;
          ELSIF v_gecikme >= 0 THEN
            v_durum := 'eksik';
          ELSE
            v_durum := 'yaklasan';
          END IF;

          v_result := v_result || jsonb_build_object(
            'hayvan_id', v_rec.hayvan_id,
            'kupe_no', v_rec.kupe_no,
            'grup', v_rec.grup,
            'protokol', 'ILERI_GEBE_PROTOKOL',
            'adim', v_a.aciklama,
            'etken_kod', v_a.ek,
            'hedef_tarih', v_hedef,
            'gecikme_gun', v_gecikme,
            'durum', v_durum,
            'tamamlanma_tarihi', v_tamamlanma,
            'kapatan_ref', v_kapatan
          );
        END;
      END LOOP;
    END;
  END LOOP;

  -- ═══ C. KIZGINLIK TAKİBİ (55-70 gün) ═══
  FOR v_rec IN
    SELECT d.id AS dogum_id, d.anne_id AS hayvan_id, d.tarih AS dogum_tarihi,
           h.kupe_no, h.grup
    FROM (
      SELECT DISTINCT ON (anne_id) *
      FROM public.dogum
      ORDER BY anne_id, tarih DESC
    ) d
    JOIN public.hayvanlar h ON h.id = d.anne_id AND h.durum = 'Aktif'
    WHERE (v_today - d.tarih) BETWEEN 55 AND 75
  LOOP
    DECLARE
      v_hedef date := v_rec.dogum_tarihi + 58;
      v_gecikme int := v_today - v_hedef;
      v_durum text;
    BEGIN
      v_found := false;
      v_tamamlanma := NULL;
      v_kapatan := NULL;

      SELECT true, g.tamamlanma_tarihi
      INTO v_found, v_tamamlanma
      FROM gorev_log g
      WHERE g.hayvan_id = v_rec.hayvan_id
        AND g.aciklama ILIKE '%kızgınlık%'
        AND g.tamamlandi = true
        AND g.hedef_tarih BETWEEN v_hedef - 3 AND v_hedef + 7
      LIMIT 1;

      IF v_found IS NOT TRUE THEN
        SELECT true INTO v_found
        FROM kizginlik_log k
        WHERE k.hayvan_id = v_rec.hayvan_id
          AND k.tarih >= v_rec.dogum_tarihi + 50
        LIMIT 1;
      END IF;

      IF v_found IS NOT TRUE THEN
        SELECT true INTO v_found
        FROM tohumlama t
        WHERE t.hayvan_id = v_rec.hayvan_id
          AND t.tarih >= v_rec.dogum_tarihi + 50
        LIMIT 1;
      END IF;

      IF v_found IS NOT TRUE THEN
        SELECT true INTO v_found
        FROM protokol_dismiss pd
        WHERE pd.hayvan_id = v_rec.hayvan_id
          AND pd.protokol = 'KIZGINLIK_TAKIP'
        LIMIT 1;
      END IF;

      IF v_found AND v_tamamlanma IS NOT NULL AND v_tamamlanma >= now() - interval '24 hours' THEN
        v_durum := 'tamamlandi';
      ELSIF v_found THEN
        CONTINUE;
      ELSIF v_gecikme >= 0 THEN
        v_durum := 'eksik';
      ELSE
        v_durum := 'yaklasan';
      END IF;

      v_result := v_result || jsonb_build_object(
        'hayvan_id', v_rec.hayvan_id,
        'kupe_no', v_rec.kupe_no,
        'grup', v_rec.grup,
        'protokol', 'KIZGINLIK_TAKIP',
        'adim', '⚡ 58-63. gün kızgınlık takibi',
        'etken_kod', NULL,
        'hedef_tarih', v_hedef,
        'gecikme_gun', v_gecikme,
        'durum', v_durum,
        'tamamlanma_tarihi', v_tamamlanma,
        'kapatan_ref', v_kapatan
      );
    END;
  END LOOP;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.protokol_eksik_tara() TO anon, authenticated;

-- Doğum sonrası aşı takviminde Leptospirosis uygulanmıyor. Aşı katalog/hareket
-- kayıtları korunur; yalnız otomatik doğum sonrası plan kaldırılır.
DELETE FROM public.vaccination_schedule vs
USING public.vaccines v
WHERE v.id = vs.vaccine_id
  AND vs.timing_type = 'dogum_sonra'
  AND v.name = 'Leptospirosis Aşısı';

-- Doğum sonrası görevleri etken sınıfına göre üret. E vitamini ürün adı değildir:
-- E_VIT sınıfındaki herhangi bir ürün (ör. Carofertin-E veya Yeldif) uygundur.
CREATE OR REPLACE FUNCTION public.dogum_kaydet(p_anne_id text, p_tarih date, p_kupe text, p_cins text DEFAULT 'Dişi'::text, p_tip text DEFAULT 'Normal'::text, p_kg numeric DEFAULT NULL::numeric, p_baba text DEFAULT NULL::text, p_hekim_id text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_anne       record;
  v_dogum_id   uuid := gen_random_uuid();
  v_buzagi_id  text;
  v_ana_gorev  uuid := gen_random_uuid();
  v_sayac      integer;
  v_dup        text;
  v_baba_bilgi text;
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

  SELECT 'H' || LPAD((COUNT(*) + 1)::text, 6, '0') INTO v_buzagi_id FROM public.hayvanlar;

  INSERT INTO public.hayvanlar (id, kupe_no, irk, dogum_tarihi, anne_id, baba_bilgi, cinsiyet, grup, padok, durum, dogum_kg)
  VALUES (v_buzagi_id, p_kupe, v_anne.irk, p_tarih, p_anne_id, v_baba_bilgi, p_cins,
          'Süt İçen Buzağı', 'Buzağı Padok (Süt İçenler)', 'Aktif', p_kg);

  UPDATE public.hayvanlar
  SET grup = 'Sağmal (Laktasyonda)', padok = 'Sağmal Padok'
  WHERE id = p_anne_id;

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod)
  VALUES
    (gen_random_uuid(), p_anne_id, 'ILAC',  'Doğum günü: Oksitosin', p_tarih, false, 'DOGUM-' || p_anne_id, 'OKSITOSIN'),
    (gen_random_uuid(), p_anne_id, 'ILAC',  'Doğum günü: Ademin', p_tarih, false, 'DOGUM-' || p_anne_id, 'ADEMIN'),
    (gen_random_uuid(), p_anne_id, 'ILAC',  'Doğum günü: Kalsiyum', p_tarih, false, 'DOGUM-' || p_anne_id, 'KALSIYUM'),
    (gen_random_uuid(), p_anne_id, 'ILAC',  '2. Gün PG', p_tarih + 2, false, 'DOGUM-' || p_anne_id, 'PG'),
    (gen_random_uuid(), p_anne_id, 'ILAC',  '25. Gün PG', p_tarih + 25, false, 'DOGUM-' || p_anne_id, 'PG'),
    (gen_random_uuid(), p_anne_id, 'ILAC',  '39. Gün PG (Presynch-14 senkron)', p_tarih + 39, false, 'DOGUM-' || p_anne_id, 'PG'),
    (gen_random_uuid(), p_anne_id, 'ILAC',  '53. Gün: Ademin', p_tarih + 53, false, 'DOGUM-' || p_anne_id, 'ADEMIN'),
    (gen_random_uuid(), p_anne_id, 'ILAC',  '53. Gün: E Vitamini', p_tarih + 53, false, 'DOGUM-' || p_anne_id, 'E_VIT'),
    (gen_random_uuid(), p_anne_id, 'DIGER', '⚡ 58-63. gün kızgınlık takibi', p_tarih + 58, false, 'DOGUM-' || p_anne_id, NULL);

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak)
  VALUES (v_ana_gorev, v_buzagi_id, 'BUZAGI_BAKIM', 'Buzağı İlk Gün Bakımı (' || p_kupe || ')', p_tarih, false, 'DOGUM-' || p_anne_id);

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, parent_id, kaynak)
  VALUES
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Kolostrum ver (doğumdan sonra ilk 2 saat)', p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Göbek kordonu dezenfeksiyonu (iyot)', p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Küpeleme', p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Ademin uygula (1. gün)', p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Maya ver (1. gün)', p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id),
    (gen_random_uuid(), v_buzagi_id, 'BUZAGI_BAKIM', 'Probiyotik ver (1. gün)', p_tarih, false, v_ana_gorev, 'DOGUM-' || p_anne_id);

  UPDATE public.tohumlama
  SET sonuc = 'Doğum Yaptı', dogum_tarihi = p_tarih, buzagi_kupe = p_kupe
  WHERE hayvan_id = p_anne_id AND sonuc = 'Gebe';

  GET DIAGNOSTICS v_sayac = ROW_COUNT;

  UPDATE public.gorev_log
  SET iptal = true
  WHERE hayvan_id = p_anne_id AND gorev_tipi = 'BESLEME'
    AND tamamlandi = false AND iptal = false;

  RETURN jsonb_build_object('ok', true, 'buzagi_id', v_buzagi_id, 'dogum_id', v_dogum_id,
                            'gorev_sayisi', 16, 'tohumlama_kapatildi', v_sayac);
END;
$$;

-- Yaş-temelli aşı planını çalışır bırak: canlı hayvan tablosunda yas_gun yoktur;
-- doğum sonrası planlarda ilişki dogum.anne_id üzerinden kurulur.
CREATE OR REPLACE FUNCTION public.get_vaccination_schedule(p_animal_id text)
RETURNS TABLE(vaccine_id uuid, vaccine_name text, disease_target text, dose numeric, unit text, route text, schedule_date date, is_due boolean, notes text)
LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_animal record;
  v_birth_date date;
  v_today date := CURRENT_DATE;
  v_age_days integer;
  v_schedule_rec record;
  v_last_vac_date date;
BEGIN
  SELECT * INTO v_animal FROM public.hayvanlar WHERE id = p_animal_id AND durum = 'Aktif';
  IF NOT FOUND THEN RETURN; END IF;

  v_birth_date := v_animal.dogum_tarihi;
  v_age_days := COALESCE(v_today - v_birth_date, 0);

  FOR v_schedule_rec IN
    SELECT vs.*, v.name AS vaccine_name, v.disease_target, v.dose, v.unit, v.route
    FROM public.vaccination_schedule vs
    JOIN public.vaccines v ON v.id = vs.vaccine_id
    WHERE vs.target_type IN (
      'tüm', v_animal.cinsiyet,
      CASE WHEN v_animal.cinsiyet = 'Dişi' AND v_age_days < 365 THEN 'buzağı'
           WHEN v_animal.cinsiyet = 'Dişi' AND v_age_days < 730 THEN 'düve'
           ELSE 'inek' END)
    ORDER BY vs.sequence_order
  LOOP
    IF v_schedule_rec.timing_type = 'yas' AND v_birth_date IS NOT NULL THEN
      schedule_date := v_birth_date + v_schedule_rec.timing_days;
    ELSIF v_schedule_rec.timing_type = 'dogum_sonra' THEN
      SELECT MAX(tarih) INTO v_last_vac_date FROM public.dogum WHERE anne_id = p_animal_id;
      IF v_last_vac_date IS NULL THEN CONTINUE; END IF;
      schedule_date := v_last_vac_date + v_schedule_rec.timing_days;
    ELSE
      CONTINUE;
    END IF;

    is_due := schedule_date <= v_today;
    vaccine_id := v_schedule_rec.vaccine_id;
    vaccine_name := v_schedule_rec.vaccine_name;
    disease_target := v_schedule_rec.disease_target;
    dose := v_schedule_rec.dose;
    unit := v_schedule_rec.unit;
    route := v_schedule_rec.route;
    notes := v_schedule_rec.notes;
    RETURN NEXT;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.dogum_kaydet(text, date, text, text, text, numeric, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_vaccination_schedule(text) TO anon, authenticated;
