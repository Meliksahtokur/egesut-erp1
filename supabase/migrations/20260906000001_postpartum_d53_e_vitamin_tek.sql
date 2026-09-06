-- ============================================================================
-- DOĞUM SONRASI d53: TEK 'E VITAMINI' GÖREVİ — 2026-09-06 (kullanıcı kararı, bağlayıcı)
-- ============================================================================
-- BUG (canlı): 20260901000002 dogum_kaydet d53'te 3 sorunlu görev üretiyor —
--   '53. Gün: Ademin' (ADEMIN)  → istenmiyor
--   '53. Gün: Yeldif'  (E_VIT)  → adı 'E Vitamini' olmalı (Yeldif ürün değil, etken sınıfı)
--   '54. Gün: Yeldif'  (E_VIT)  → d54 tekrarı, çift yaratma
-- KARAR: d53'te YALNIZCA tek bir '53. Gün: E Vitamini' (E_VIT) görevi üretilir;
--        d53 ADEMIN ve d54 E_VIT görevleri kaldırılır.
-- BAZLAR:
--   dogum_kaydet        ← CANLI gövde: 20260901000002_kupe_revizyon.sql (ikiz guard + olay_id +
--                         tüm diğer görev satırları AYNEN; TEK FARK görev listesi ve
--                         gorev_sayisi 10→8: anne 8 + buzağı 7 = 15 / yalnız buzağı 7)
--   protokol_eksik_tara ← 20260730000002_dogum_sonrasi_e_vitamini.sql gövdesi (canlıya gitmedi);
--                         DOĞUM_PROTOKOL listesi dogum_kaydet ile eşitlendi: d53 tek satır
--                         (53,'E_VIT','53. Gün: E Vitamini'); (53,'ADEMIN',…) satırı silindi;
--                         canlıdaki (54,'E_VIT','54. Gün: Yeldif') satırı bu gövdede zaten yok.
--   legacy temizlik     ← 20260730000003_postpartum_e_vitamin_legacy_task_reconcile.sql deseni
--                         (latest_birth + kaynak='DOGUM-<anne_id>' disiplini; o dosya canlıya
--                         gitmedi, desen buraya uyarlandı)
-- E_VIT etken_kod'u gebelik d265'te de kullanılır → _etken_kod_bul ve gebelik tarafına
-- DOKUNULMADI; yalnız DOĞUM (postpartum) d53/d54 satırları değişti.
-- JS tarafı değişmedi (gorev_sayisi dönüşü forms.js:221-223 toast'ında bilgi amaçlı).
-- DURUM: migration yazıldı, canlıya DEPLOY BEKLİYOR (2026-09-06) — canlı henüz eski davranışta.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. dogum_kaydet — canlı 20260901000002 gövdesi AYNEN (imza, SECURITY DEFINER,
--    ikiz guard, olay penceresi, 60g anne guard, BESLEME iptali, buzağı görevleri).
--    Tek fark — anne görev listesi 10→8:
--      SILINDI: (d53,'53. Gün: Ademin',ADEMIN), (d54,'54. Gün: Yeldif',E_VIT)
--      ADLANDI: (d53,'53. Gün: Yeldif',E_VIT) → (d53,'53. Gün: E Vitamini',E_VIT)
--    gorev_sayisi dönüşü yeni listeye hizalandı (8+7=15; anne ayağı atlanırsa 7).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dogum_kaydet(p_anne_id text, p_tarih date, p_kupe text, p_cins text DEFAULT 'Dişi'::text, p_tip text DEFAULT 'Normal'::text, p_kg numeric DEFAULT NULL::numeric, p_baba text DEFAULT NULL::text, p_hekim_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
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

  -- İKİZ GUARD: aynı anne + aynı yavru küpesi zaten kayıtlıysa reddet (typo → yanlış ikiz engeli)
  IF EXISTS (SELECT 1 FROM public.dogum WHERE anne_id = p_anne_id AND yavru_kupe = p_kupe) THEN
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

  SELECT 'H' || LPAD((COUNT(*)+1)::text, 6, '0') INTO v_buzagi_id FROM public.hayvanlar;

  INSERT INTO public.hayvanlar (id, kupe_no, irk, dogum_tarihi, anne_id, baba_bilgi, cinsiyet, grup, padok, durum, dogum_kg)
  VALUES (v_buzagi_id, p_kupe, v_anne.irk, p_tarih, p_anne_id, v_baba_bilgi, p_cins,
          'Süt İçen Buzağı', 'Buzağı Padok (Süt İçenler)', 'Aktif', p_kg);

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
      (gen_random_uuid(), p_anne_id, 'ILAC', '11. Gün PG',            p_tarih + 11, false, 'DOGUM-' || p_anne_id, 'PG',        v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', '25. Gün PG',            p_tarih + 25, false, 'DOGUM-' || p_anne_id, 'PG',        v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'ILAC', '53. Gün: E Vitamini',       p_tarih + 53, false, 'DOGUM-' || p_anne_id, 'E_VIT',     v_anne_inst_id),
      (gen_random_uuid(), p_anne_id, 'DIGER','⚡ 58-63. gün kızgınlık takibi', p_tarih + 58, false, 'DOGUM-' || p_anne_id, NULL, v_anne_inst_id);

    UPDATE public.tohumlama
    SET sonuc = 'Doğum Yaptı', dogum_tarihi = p_tarih, buzagi_kupe = p_kupe
    WHERE hayvan_id = p_anne_id AND sonuc = 'Gebe';
    GET DIAGNOSTICS v_sayac = ROW_COUNT;

    UPDATE public.gorev_log SET iptal = true
    WHERE hayvan_id = p_anne_id AND gorev_tipi = 'BESLEME' AND tamamlandi = false AND iptal = false;

    UPDATE public.protokol_instance SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = 'DOGUM'
    WHERE hayvan_id = p_anne_id AND alttip = 'BESLEME' AND durum = 'aktif';
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

GRANT EXECUTE ON FUNCTION public.dogum_kaydet(text, date, text, text, text, numeric, text, text) TO anon, authenticated;

-- ----------------------------------------------------------------------------
-- 2. protokol_eksik_tara — 20260730000002 gövdesi AYNEN; tek fark DOĞUM_PROTOKOL
--    VALUES listesi: d53 artık tek satır (E_VIT '53. Gün: E Vitamini');
--    (53,'ADEMIN','53. Gün: Ademin') silindi. Böylece scanner d53'te yalnız
--    E Vitamini adımını tarar (canlı d54 E_VIT satırı bu baz gövdede yok).
--    İleri-gebe (ROTA/ADEMIN/E_VIT d240-265) ve kızgınlık bölümlerine dokunulmadı.
-- ----------------------------------------------------------------------------
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

-- ----------------------------------------------------------------------------
-- 3. Legacy veri temizliği — canlı dogum_kaydet'in (20260901000002) ürettiği eski
--    desenli AÇIK görevler yeni karara taşınır. Desen: 20260730000003 (canlıya
--    gitmedi) — latest_birth CTE + kaynak='DOGUM-<anne_id>' + yalnız açık görevler.
--    TAMAMLANAN görevlere dokunulmaz (geçmiş kayıt). gorev_log farm_id'sizdir;
--    kapsam disiplini 20260730000003 ile aynıdır (hayvan+kaynak eşleşmesi).
--    Idempotent: ikinci çalıştırmada 0 satır eşleşir.
--    a) Açık d53 '53. Gün: Yeldif' (E_VIT) → '53. Gün: E Vitamini' (hedef doğum+53'e sabitlenir)
--    b) Açık '53. Gün: Ademin' (ADEMIN) görevleri iptal
--    c) Açık '54. Gün: Yeldif' (E_VIT) görevleri iptal (hedef +53/+54 farkı gözetmeksizin —
--       protokol_gorev_bol Tip-B +53 tarihli d54 adlı satır da üretebildiği için)
-- ----------------------------------------------------------------------------
WITH latest_birth AS (
  SELECT DISTINCT ON (anne_id) anne_id, tarih
  FROM public.dogum
  ORDER BY anne_id, tarih DESC, created_at DESC, id DESC
)
UPDATE public.gorev_log g
SET aciklama   = '53. Gün: E Vitamini',
    hedef_tarih = b.tarih + 53
FROM latest_birth b
WHERE g.hayvan_id = b.anne_id
  AND g.kaynak = 'DOGUM-' || b.anne_id
  AND g.etken_kod = 'E_VIT'
  AND g.aciklama = '53. Gün: Yeldif'
  AND NOT g.tamamlandi
  AND NOT COALESCE(g.iptal, false);

WITH latest_birth AS (
  SELECT DISTINCT ON (anne_id) anne_id, tarih
  FROM public.dogum
  ORDER BY anne_id, tarih DESC, created_at DESC, id DESC
)
UPDATE public.gorev_log g
SET iptal = true
FROM latest_birth b
WHERE g.hayvan_id = b.anne_id
  AND g.kaynak = 'DOGUM-' || b.anne_id
  AND g.etken_kod = 'ADEMIN'
  AND g.aciklama = '53. Gün: Ademin'
  AND NOT g.tamamlandi
  AND NOT COALESCE(g.iptal, false);

WITH latest_birth AS (
  SELECT DISTINCT ON (anne_id) anne_id, tarih
  FROM public.dogum
  ORDER BY anne_id, tarih DESC, created_at DESC, id DESC
)
UPDATE public.gorev_log g
SET iptal = true
FROM latest_birth b
WHERE g.hayvan_id = b.anne_id
  AND g.kaynak = 'DOGUM-' || b.anne_id
  AND g.etken_kod = 'E_VIT'
  AND g.aciklama = '54. Gün: Yeldif'
  AND NOT g.tamamlandi
  AND NOT COALESCE(g.iptal, false);

NOTIFY pgrst, 'reload schema';

COMMIT;
