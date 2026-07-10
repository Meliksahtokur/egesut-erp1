-- ============================================================================
-- Migration: Protokol etken_kod — otorite + scanner recompute + orphan guard +
--            gorev üretim 3-ayrı + mevcut birleşik görev bölme (5 katman)
-- Tarih: 2026-07-10
-- Kök neden: "Protokol uyarıları done edilen görevleri hâlâ gecikmiş gösteriyor,
--           stok çekilmiş ama protokol başarılı saymıyor" — hortlayan bug.
--           2026-07-10 canlı doğrulama: İKİ ayrı kök bulundu (8 orphan + 157 birleşik gorev).
--
-- ÖNCEKİ FIX'LER NEDEN KIRILDI:
--   (a) _etken_kod_bul hardcoded ILIKE text-guesser olarak kaldı → yeni ilaç/
--       drug_classes yeniden sınıflandırma → etken NULL → uygulama_log.etken_kod NULL
--       → trigger tetiklenmedi → gorev_log açık + scanner stored NULL'ı ıskaladı.
--       Her fix tek etken için yama (whack-a-mole).
--   (b) dogum_kaydet 3-ayrı fix'leri (20260603000001, 20260605000001, 20260605000006)
--       canlıya apply edilmemiş/regressed → HÂLÂ birleşik etken_kod=NULL gorev üretiyor
--       → scanner `g.etken_kod=ek` NULL eşleşmez → 3 false-positive "eksik" (157 vb.).
--
-- BU FIX — 5 katmanlı savunma derinliği (bir katman gerilerse diğeri yakalar):
--   Katman 1: drug_classes.etken_kod otorite kolonu + backfill. _etken_kod_bul önce
--            bunu okur (otorite), NULL ise mevcut ILIKE legacy ağı korunur.
--   Katman 2: protokol_eksik_tara uygulama_log yolunda stored etken_kod yerine
--            _etken_kod_bul(u.stok_id) yeniden hesaplar (drug_administrations yoluyla
--            simetrik). Yazma anında NULL olsa bile stok sınıflandırılabilirse yakalar.
--   Katman 3: protokol_orphan_temizle() + protokol_orphan_audit() RPC'leri. Mevcut NULL
--            uygulama_log kayıtlarını onarır (etken_kod backfill + eşleşen gorev_log kapat)
--            ve orphan sayısını guard olarak döner → sessiz gerileme görünür.
--   Katman 4: dogum_kaydet gorev_log INSERT bloğu — her etken AYRI satır + etken_kod SET
--            (day-0: 3 ayrı OKSITOSIN/ADEMIN/KALSIYUM; d53 ADEMIN; d54 E_VIT).
--            GELECEK doğumlar hortlamaz. Gövde canlı ile birebir, sadece bu blok değişti.
--   Katman 5: protokol_gorev_bol() RPC — mevcut etken_kod=NULL birleşik gorev_log
--            görevlerini 3/2 ayrı etken_kod'lu göreve böler (dry-run+onay). 157 dahil
--            MEVCUT birleşik görevli hayvanları onarır.
--
-- GÜVENLİK AYRIMI: Bu migration otomatik olarak SADECE şema değişikliği (kolon +
--   backfill UPDATE — yalnızca class_name/active_ingredient ile sınıflandırılabilen
--   drug_classes satırlarına etken_kod yazar) + fonksiyon tanımları uygular.
--   Bulk onarım (uygulama_log/gorev_log UPDATE/INSERT) deploy'da OTOMATİK ÇALIŞMAZ —
--   protokol_orphan_temizle / protokol_gorev_bol (p_dry_run=>true) ile önce sayılır,
--   kullanıcı onayı sonra p_dry_run=>false çağrılır.
--
-- Bağımlılıklar: önceki _etken_kod_bul (20260705000001), protokol_eksik_tara (20260624000020),
--   dogum_kaydet (20260605000006 son sürüm — bu migration 3-ayrı'yı yeniden uygular)
-- ============================================================================

BEGIN;

-- ============================================================================
-- KATMAN 1: drug_classes.etken_kod otorite kolonu + backfill
-- ============================================================================

ALTER TABLE public.drug_classes ADD COLUMN IF NOT EXISTS etken_kod text;

COMMENT ON COLUMN public.drug_classes.etken_kod IS
  'Otorite etken_kod (OKSITOSIN/PG/E_VIT/ADEMIN/KALSIYUM/ROTA). _etken_kod_bul önce bunu okur; '
  'boş ise ILIKE legacy ağına düşer. Yeni ilaç sınıfı tanımlanırken açıkça set edilmeli.';

-- Backfill: mevcut ILIKE mantığıyla drug_classes satırlarına etken_kod yaz.
-- Sadece etken_kod IS NULL olanlara dokunur (idempotent). Stok-adı (marka) bazlı
-- eşleşmeler (yeldif/ademin/kalsiyum marka) burada kullanılmaz — bunlar runtime'da
-- _etken_kod_bul ILIKE ağında korunur; drug_classes seviyesinde class/active_ing/grouple sınıflandırılır.
UPDATE public.drug_classes SET etken_kod = 'OKSITOSIN'
WHERE etken_kod IS NULL
  AND (class_name ILIKE '%oksitosin%' OR active_ingredient ILIKE '%oxytocin%');

UPDATE public.drug_classes SET etken_kod = 'PG'
WHERE etken_kod IS NULL
  AND (class_name ILIKE '%prostaglandin%' OR group_name ILIKE '%PG%'
       OR active_ingredient ILIKE '%dinoprost%' OR active_ingredient ILIKE '%cloprostenol%');

UPDATE public.drug_classes SET etken_kod = 'E_VIT'
WHERE etken_kod IS NULL
  AND (active_ingredient ILIKE '%E Vitamini%' OR class_name ILIKE '%E Vit%');

UPDATE public.drug_classes SET etken_kod = 'ADEMIN'
WHERE etken_kod IS NULL
  AND class_name ILIKE '%ademin%';

UPDATE public.drug_classes SET etken_kod = 'KALSIYUM'
WHERE etken_kod IS NULL
  AND (class_name ILIKE '%kalsiyum%' OR class_name ILIKE '%calcium%');

-- ============================================================================
-- KATMAN 1: _etken_kod_bul rewrite — otorite önce, ILIKE legacy ağı
-- ============================================================================

CREATE OR REPLACE FUNCTION public._etken_kod_bul(
  p_stok_id text DEFAULT NULL,
  p_vaccine_id uuid DEFAULT NULL
) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_class_name   text;
  v_group_name   text;
  v_active_ing   text;
  v_stok_ad      text;
  v_vaccine_name text;
  v_etken_kod    text;   -- otorite (drug_classes.etken_kod)
BEGIN
  -- Aşı yolu
  IF p_vaccine_id IS NOT NULL THEN
    SELECT name INTO v_vaccine_name FROM public.vaccines WHERE id = p_vaccine_id;
    IF v_vaccine_name ILIKE '%Rota%' THEN RETURN 'ROTA'; END IF;
    RETURN NULL;
  END IF;

  -- İlaç yolu: stok → drug_products → drug_classes
  IF p_stok_id IS NOT NULL THEN
    SELECT s.urun_adi INTO v_stok_ad FROM public.stok s WHERE s.id = p_stok_id;

    -- Aşı (stok yolu): FK zinciri aşılarda boş — isimden yakala.
    IF v_stok_ad ILIKE '%Rota%' THEN RETURN 'ROTA'; END IF;

    -- Önce stok.drug_product_id FK zinciri (en doğru yol) — etken_kod dahil 4 alan
    SELECT dc.etken_kod, dc.group_name, dc.class_name, dc.active_ingredient
    INTO v_etken_kod, v_group_name, v_class_name, v_active_ing
    FROM public.drug_products dp
    JOIN public.drug_classes dc ON dc.id = dp.drug_class_id
    WHERE dp.id = (SELECT drug_product_id FROM public.stok WHERE id = p_stok_id)
    LIMIT 1;

    -- Otorite: drug_classes.etken_kod set ise kesin dönüş (ILIKE'ı atla)
    IF v_etken_kod IS NOT NULL THEN RETURN v_etken_kod; END IF;

    -- Fallback: brand_name eşleşmesi (FK boşsa) — etken_kod'u da çek
    IF v_class_name IS NULL THEN
      SELECT dc.etken_kod, dc.group_name, dc.class_name, dc.active_ingredient
      INTO v_etken_kod, v_group_name, v_class_name, v_active_ing
      FROM public.drug_products dp
      JOIN public.drug_classes dc ON dc.id = dp.drug_class_id
      WHERE dp.brand_name ILIKE '%' || COALESCE(v_stok_ad,'') || '%'
      LIMIT 1;
      IF v_etken_kod IS NOT NULL THEN RETURN v_etken_kod; END IF;
    END IF;

    -- Legacy ILIKE güvenlik ağı: etken_kod kolonu boşsa text-guesser dener.
    -- (Geçiş dönemi: etken_kod henükse set edilmemiş drug_classes için.)
    IF v_class_name ILIKE '%oksitosin%' OR v_active_ing ILIKE '%oxytocin%' THEN RETURN 'OKSITOSIN'; END IF;
    IF v_class_name ILIKE '%prostaglandin%' OR v_group_name ILIKE '%PG%'
       OR v_active_ing ILIKE '%dinoprost%' OR v_active_ing ILIKE '%cloprostenol%' THEN RETURN 'PG'; END IF;
    IF v_active_ing ILIKE '%E Vitamini%' THEN RETURN 'E_VIT'; END IF;
    IF v_class_name ILIKE '%E Vit%' OR v_stok_ad ILIKE '%yeldif%' OR v_stok_ad ILIKE '%e vit%' THEN RETURN 'E_VIT'; END IF;
    IF v_class_name ILIKE '%ademin%' OR v_stok_ad ILIKE '%ademin%' THEN RETURN 'ADEMIN'; END IF;
    IF v_class_name ILIKE '%kalsiyum%' OR v_class_name ILIKE '%calcium%' OR v_stok_ad ILIKE '%kalsiyum%' THEN RETURN 'KALSIYUM'; END IF;

    RETURN NULL;
  END IF;

  RETURN NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION public._etken_kod_bul(text, uuid) TO anon, authenticated;

-- ============================================================================
-- KATMAN 2: protokol_eksik_tara — uygulama_log yolunda recompute (simetrik)
--   Değişiklik: DOĞUM + İLERİ_GEBE uygulama_log kontrollerinde
--     `u.etken_kod = ek`  →  `(u.etken_kod = ek OR _etken_kod_bul(u.stok_id,NULL) = ek)`
--   OR kullanımı: stored doğru olsa veya NULL (artık sınıflandırılabilir) olsa da yakalar.
--   Hiçbir senaryoda eski davranışın altına düşmez (superset).
--   Gövde 20260624000020 (null-guard fix, canlı ile BİREBİR — 2026-07-10 aynadan doğrulandı)
--   üzerine: 2 uygulama_log koşulu OR recompute + İLERİ_GEBE'ye drug_administrations yolu
--   eklenmesi (canlıda sadece DOĞUM'da vardı; ADEMIN/E_VIT tedavi yolu için simetrik).
-- ============================================================================

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
      (54, 'E_VIT',     '54. Gün: Yeldif')
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
        BEGIN
          IF v_hedef > v_today + 7 THEN CONTINUE; END IF;

          v_found := false;
          v_tamamlanma := NULL;
          v_kapatan := NULL;

          SELECT true, g.tamamlanma_tarihi, g.kapatan_ref
          INTO v_found, v_tamamlanma, v_kapatan
          FROM gorev_log g
          WHERE g.hayvan_id = v_rec.hayvan_id
            AND g.etken_kod = v_a.ek
            AND g.tamamlandi = true
            AND g.hedef_tarih BETWEEN v_hedef - 3 AND v_hedef + 3
          LIMIT 1;

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

  -- ═══ C. KIZGINLIK TAKİBİ (55-70 gün) — değişmedi ═══
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

-- ============================================================================
-- KATMAN 3: protokol_orphan_temizle() — NULL etken_kod'u artık sınıflandırılabilir
--   uygulama_log kayıtlarını onarır. p_dry_run=true ise sadece sayar (UPDATE yok).
--   p_dry_run=false ise: (a) uygulama_log.etken_kod backfill,
--                        (b) eşleşen bekleyen gorev_log'u kapat (±3 gün pencere).
--   Deploy'da OTOMATİK çağrılmaz — kullanıcı dry-run çıktısını onayladıktan sonra.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.protokol_orphan_temizle(
  p_dry_run boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_orphan       int := 0;
  v_fixed        int := 0;
  v_gorev_closed int := 0;
  v_rc           int;
  v_rec          record;
  v_ek           text;
  v_samples      jsonb := '[]'::jsonb;
BEGIN
  FOR v_rec IN
    SELECT u.id AS uyg_id, u.hayvan_id, u.stok_id, u.tarih, u.notlar,
           h.kupe_no
    FROM public.uygulama_log u
    LEFT JOIN public.hayvanlar h ON h.id = u.hayvan_id
    WHERE u.etken_kod IS NULL
      AND u.stok_id IS NOT NULL
      AND public._etken_kod_bul(u.stok_id, NULL) IS NOT NULL
    ORDER BY u.tarih DESC
  LOOP
    v_orphan := v_orphan + 1;

    IF v_orphan <= 10 THEN
      v_samples := v_samples || jsonb_build_object(
        'uyg_id', v_rec.uyg_id,
        'hayvan_id', v_rec.hayvan_id,
        'kupe_no', v_rec.kupe_no,
        'stok_id', v_rec.stok_id,
        'tarih', v_rec.tarih,
        'etken_kod', public._etken_kod_bul(v_rec.stok_id, NULL));
    END IF;

    IF p_dry_run THEN
      CONTINUE;
    END IF;

    v_ek := public._etken_kod_bul(v_rec.stok_id, NULL);

    -- (a) uygulama_log.etken_kod backfill
    UPDATE public.uygulama_log
    SET etken_kod = v_ek
    WHERE id = v_rec.uyg_id;
    v_fixed := v_fixed + 1;

    -- (b) eşleşen bekleyen gorev_log'u kapat (uygulama tarihi ±3 gün içindeki hedef)
    UPDATE public.gorev_log
    SET tamamlandi = true,
        tamamlanma_tarihi = now(),
        kapatan_ref = 'orphan_temizle:uygulama_log:' || v_rec.uyg_id::text
    WHERE hayvan_id = v_rec.hayvan_id
      AND etken_kod = v_ek
      AND tamamlandi = false
      AND iptal = false
      AND hedef_tarih BETWEEN v_rec.tarih - 3 AND v_rec.tarih + 3;
    GET DIAGNOSTICS v_rc = ROW_COUNT;
    v_gorev_closed := v_gorev_closed + v_rc;
  END LOOP;

  RETURN jsonb_build_object(
    'dry_run', p_dry_run,
    'orphan_count', v_orphan,
    'fixed_uygulama_log', v_fixed,
    'closed_gorev_log', v_gorev_closed,
    'samples', v_samples
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.protokol_orphan_temizle(boolean) TO anon, authenticated;

-- ============================================================================
-- KATMAN 3: protokol_orphan_audit() — guard. Mevcut orphan sayısı + riskli
--   drug_classes (protokol stoklarında kullanılan ama etken_kod NULL) sayısı.
--   Periyodik/istek-üzerine çağrılır; orphan>0 ise UI'da "N kayıt onarılabilir".
--   Sessiz gerilemeyi görünür kılar (kullanıcıdan önce yakalarız).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.protokol_orphan_audit()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_orphan_uyg        int;
  v_riskli_classes    int;
  v_etken_dagilim     jsonb;
BEGIN
  -- Mevcut orphan uygulama_log (false-warning kaynağı)
  SELECT count(*) INTO v_orphan_uyg
  FROM public.uygulama_log u
  WHERE u.etken_kod IS NULL
    AND u.stok_id IS NOT NULL
    AND public._etken_kod_bul(u.stok_id, NULL) IS NOT NULL;

  -- Riskli drug_classes: protokol-relevant stoğa bağlı ama etken_kod NULL
  -- (gelecekte orphan üretebilir — proaktif sinyal)
  SELECT count(DISTINCT dc.id) INTO v_riskli_classes
  FROM public.drug_classes dc
  JOIN public.drug_products dp ON dp.drug_class_id = dc.id
  JOIN public.stok s ON s.drug_product_id = dp.id
  WHERE dc.etken_kod IS NULL;

  -- Etkan dağılımı (etken_kod set edilen drug_classes sayıları)
  SELECT jsonb_object_agg(etken_kod, cnt) INTO v_etken_dagilim
  FROM (
    SELECT coalesce(etken_kod, 'NULL') AS etken_kod, count(*) AS cnt
    FROM public.drug_classes
    GROUP BY etken_kod
  ) t;

  RETURN jsonb_build_object(
    'orphan_uygulama_log', v_orphan_uyg,
    'riskli_drug_classes', v_riskli_classes,
    'drug_classes_etken_dagilim', v_etken_dagilim
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.protokol_orphan_audit() TO anon, authenticated;

-- ============================================================================
-- KATMAN 4: dogum_kaydet — gorev_log INSERT bloğunu her etken AYRI satır + etken_kod SET
--   KÖK: canlı dogum_kaydet hâlâ birleşik etken_kod=NULL gorev üretiyordu:
--     'Doğum günü: Oksitosin + Ademin + Kalsiyum' (3 etken TEK görev, NULL)
--     '53. Gün: Ademin + Yeldif' (ADEMIN+E_VIT TEK görev, NULL)
--     '54. Gün: Yeldif' (E_VIT ama etken_kod NULL)
--   Scanner `g.etken_kod = ek` ile NULL eşleşmez → 3 false-positive "eksik" (157 vb.).
--   3-ayrı fix'ler (20260603000001, 20260605000001, 20260605000006) canlıya
--   apply edilmemiş/regressed → "yine patladı" cümlesinin kanıtı (2026-07-10).
--   FIX: her etken ayrı satır, etken_kod SET. Gövde canlı ile birebir, SADECE bu
--   INSERT VALUES bloğu + gorev_sayisi (14→16: +2 day-0 ayrı, d53 bölünür ama net
--   +2 = 3 ayrı yerine 1 birleşik day-0 = +2; d53 2 ayrı yerine 1 = +1; d54 etken set
--   değişmez; kızgınlık aynı → toplam 7→9 = +2... sayım: 9+1+6=16) değişti.
--   Kızgınlık görevi etken_kod=NULL kalır — scanner aciklama ILIKE ile arar (doğru).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.dogum_kaydet(
  p_anne_id text, p_tarih date, p_kupe text,
  p_cins text DEFAULT 'Dişi', p_tip text DEFAULT 'Normal',
  p_kg numeric DEFAULT NULL, p_baba text DEFAULT NULL, p_hekim_id text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
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

  -- 5. Anne protokol görevleri — her etken AYRI satır + etken_kod SET (2026-07-10 kök fix).
  --    Postpartum PG: d2 · d25 · d39 (Presynch-14). d11 kaldırıldı (2026-06-24).
  --    day-0: Oksitosin/Ademin/Kalsiyum ayrı görevler (eskiden birleşik NULL → scanner ıskalardı).
  --    d53: Ademin ayrı. d54: E_VIT (Yeldif). Kızgınlık etken_kod=NULL (scanner aciklama ile arar).
  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod)
  VALUES
    (gen_random_uuid(), p_anne_id, 'ILAC',  'Doğum günü: Oksitosin', p_tarih,       false, 'DOGUM-' || p_anne_id, 'OKSITOSIN'),
    (gen_random_uuid(), p_anne_id, 'ILAC',  'Doğum günü: Ademin',    p_tarih,       false, 'DOGUM-' || p_anne_id, 'ADEMIN'),
    (gen_random_uuid(), p_anne_id, 'ILAC',  'Doğum günü: Kalsiyum',  p_tarih,       false, 'DOGUM-' || p_anne_id, 'KALSIYUM'),
    (gen_random_uuid(), p_anne_id, 'ILAC',  '2. Gün PG',             p_tarih + 2,   false, 'DOGUM-' || p_anne_id, 'PG'),
    (gen_random_uuid(), p_anne_id, 'ILAC',  '25. Gün PG',            p_tarih + 25,  false, 'DOGUM-' || p_anne_id, 'PG'),
    (gen_random_uuid(), p_anne_id, 'ILAC',  '39. Gün PG (Presynch-14 senkron)', p_tarih + 39, false, 'DOGUM-' || p_anne_id, 'PG'),
    (gen_random_uuid(), p_anne_id, 'ILAC',  '53. Gün: Ademin',       p_tarih + 53,  false, 'DOGUM-' || p_anne_id, 'ADEMIN'),
    (gen_random_uuid(), p_anne_id, 'ILAC',  '54. Gün: Yeldif',       p_tarih + 54,  false, 'DOGUM-' || p_anne_id, 'E_VIT'),
    (gen_random_uuid(), p_anne_id, 'DIGER', '⚡ 58-63. gün kızgınlık takibi', p_tarih + 58, false, 'DOGUM-' || p_anne_id, NULL);

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
    'gorev_sayisi', 16,
    'tohumlama_kapatildi', v_sayac
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.dogum_kaydet(text, date, text, text, text, numeric, text, text) TO anon, authenticated;

-- ============================================================================
-- KATMAN 5: protokol_gorev_bol() — mevcut etken_kod=NULL birleşik gorev_log
--   görevlerini ayrı etken_kod'lu göreve böler. p_dry_run=true → sayar (değişiklik yok).
--   p_dry_run=false → böler + eski birleşiği iptal eder.
--
--   Scope (3 tip, 2026-07-10 sayım):
--     Tip A: 'Doğum günü: Oksitosin + Ademin + Kalsiyum' (6 görev) → 3 ayrı
--            (OKSITOSIN/ADEMIN/KALSIYUM, hedef=orijinal, durum kopya), birleşik iptal.
--     Tip B: '53. Gün: Ademin + Yeldif' (6 görev) → 2 ayrı (ADEMIN + E_VIT,
--            hedef=orijinal), birleşik iptal.
--     Tip C: '54. Gün: Yeldif' AND etken_kod IS NULL (6 görev) → UPDATE etken_kod='E_VIT'.
--   Kızgınlık (etken_kod NULL, DIGER) → dokunulmaz (scanner aciklama ile arar).
--   Deploy'da OTOMATİK çağrılmaz — dry-run → kullanıcı onayı → p_dry_run=false.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.protokol_gorev_bol(
  p_dry_run boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tipA   int := 0;  v_tipA_new int := 0;
  v_tipB   int := 0;  v_tipB_new int := 0;
  v_tipC   int := 0;
  v_g      record;
  v_rc     int;
  v_samples jsonb := '[]'::jsonb;
BEGIN
  -- ── Tip A: day-0 birleşik → 3 ayrı ──
  FOR v_g IN
    SELECT id, hayvan_id, hedef_tarih, tamamlandi, tamamlanma_tarihi, kapatan_ref, kaynak
    FROM public.gorev_log
    WHERE etken_kod IS NULL
      AND iptal = false
      AND aciklama ILIKE 'Doğum günü: Oksitosin + Ademin + Kalsiyum'
    ORDER BY hedef_tarih DESC
  LOOP
    v_tipA := v_tipA + 1;
    IF v_tipA <= 5 THEN
      v_samples := v_samples || jsonb_build_object('tip','A','gorev_id',v_g.id,'hayvan_id',v_g.hayvan_id,'hedef',v_g.hedef_tarih);
    END IF;

    IF p_dry_run THEN CONTINUE; END IF;

    -- 3 ayrı etken_kod'lu görev yarat (durum birleşikten kopya)
    INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, tamamlanma_tarihi, kapatan_ref, kaynak, etken_kod)
    VALUES
      (gen_random_uuid(), v_g.hayvan_id, 'ILAC', 'Doğum günü: Oksitosin', v_g.hedef_tarih, v_g.tamamlandi, v_g.tamamlanma_tarihi, v_g.kapatan_ref, v_g.kaynak, 'OKSITOSIN'),
      (gen_random_uuid(), v_g.hayvan_id, 'ILAC', 'Doğum günü: Ademin',    v_g.hedef_tarih, v_g.tamamlandi, v_g.tamamlanma_tarihi, v_g.kapatan_ref, v_g.kaynak, 'ADEMIN'),
      (gen_random_uuid(), v_g.hayvan_id, 'ILAC', 'Doğum günü: Kalsiyum',  v_g.hedef_tarih, v_g.tamamlandi, v_g.tamamlanma_tarihi, v_g.kapatan_ref, v_g.kaynak, 'KALSIYUM');
    GET DIAGNOSTICS v_rc = ROW_COUNT;
    v_tipA_new := v_tipA_new + v_rc;

    -- Birleşik görevi iptal et (scanner görmesin)
    UPDATE public.gorev_log SET iptal = true
    WHERE id = v_g.id AND iptal = false;
  END LOOP;

  -- ── Tip B: d53 birleşik → 2 ayrı (ADEMIN + E_VIT) ──
  FOR v_g IN
    SELECT id, hayvan_id, hedef_tarih, tamamlandi, tamamlanma_tarihi, kapatan_ref, kaynak
    FROM public.gorev_log
    WHERE etken_kod IS NULL
      AND iptal = false
      AND aciklama ILIKE '53. Gün: Ademin + Yeldif'
    ORDER BY hedef_tarih DESC
  LOOP
    v_tipB := v_tipB + 1;
    IF v_tipB <= 5 THEN
      v_samples := v_samples || jsonb_build_object('tip','B','gorev_id',v_g.id,'hayvan_id',v_g.hayvan_id,'hedef',v_g.hedef_tarih);
    END IF;

    IF p_dry_run THEN CONTINUE; END IF;

    -- Önce bu hayvanda mevcut "54. Gün: Yeldif" etken_kod=NULL ayrı görevi var mı?
    -- Varsa: Tip B yalnızca "53. Gün: Ademin" yaratır; mevcut 54. Yeldif görevini
    --   etken_kod='E_VIT' set eder (duplicate yaratma). Yoksa: 2 ayrı yarat (ADEMIN+E_VIT).
    SELECT 1 INTO v_rc FROM public.gorev_log
      WHERE hayvan_id = v_g.hayvan_id AND etken_kod IS NULL AND iptal = false
        AND aciklama ILIKE '54. Gün: Yeldif' LIMIT 1;

    IF v_rc = 1 THEN
      -- Mevcut 54. Yeldif var → sadece 53. Ademin yarat + mevcut Yeldif'i E_VIT set
      INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, tamamlanma_tarihi, kapatan_ref, kaynak, etken_kod)
      VALUES (gen_random_uuid(), v_g.hayvan_id, 'ILAC', '53. Gün: Ademin', v_g.hedef_tarih, v_g.tamamlandi, v_g.tamamlanma_tarihi, v_g.kapatan_ref, v_g.kaynak, 'ADEMIN');
      GET DIAGNOSTICS v_rc = ROW_COUNT; v_tipB_new := v_tipB_new + v_rc;
      UPDATE public.gorev_log SET etken_kod = 'E_VIT'
        WHERE hayvan_id = v_g.hayvan_id AND etken_kod IS NULL AND iptal = false
          AND aciklama ILIKE '54. Gün: Yeldif';
    ELSE
      -- Mevcut 54. Yeldif yok → 2 ayrı yarat
      INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, tamamlanma_tarihi, kapatan_ref, kaynak, etken_kod)
      VALUES
        (gen_random_uuid(), v_g.hayvan_id, 'ILAC', '53. Gün: Ademin', v_g.hedef_tarih, v_g.tamamlandi, v_g.tamamlanma_tarihi, v_g.kapatan_ref, v_g.kaynak, 'ADEMIN'),
        (gen_random_uuid(), v_g.hayvan_id, 'ILAC', '54. Gün: Yeldif', v_g.hedef_tarih, v_g.tamamlandi, v_g.tamamlanma_tarihi, v_g.kapatan_ref, v_g.kaynak, 'E_VIT');
      GET DIAGNOSTICS v_rc = ROW_COUNT; v_tipB_new := v_tipB_new + v_rc;
    END IF;

    -- Birleşik 53. görevi iptal et
    UPDATE public.gorev_log SET iptal = true
    WHERE id = v_g.id AND iptal = false;
  END LOOP;

  -- ── Tip C: kapatıldı — Tip B artık mevcut 54. Yeldif NULL'ları set eder
  --   (duplicate yaratma). Aşağıdaki blok pasif; v_tipC=0 raporlanır. ──
  v_tipC := 0;

  RETURN jsonb_build_object(
    'dry_run', p_dry_run,
    'tipA_day0_birlesik', v_tipA, 'tipA_new_gorev', v_tipA_new,
    'tipB_d53_birlesik', v_tipB, 'tipB_new_gorev', v_tipB_new,
    'tipC_d54_set', v_tipC,
    'samples', v_samples
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.protokol_gorev_bol(boolean) TO anon, authenticated;

COMMIT;