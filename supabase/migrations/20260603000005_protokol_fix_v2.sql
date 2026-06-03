-- Migration: Protokol Fix v2 — uuid cast, backfill, scanner, indexes
-- Sorunlar: ileri_gebe_asi_tamamla uuid=text, eksik backfill, scanner duplikasyon
BEGIN;

-- ============================================================
-- Fix 1: ileri_gebe_asi_tamamla — uuid cast kaldır
-- gorev_log.id TEXT, ::uuid cast text ile karşılaştırılamaz
-- ============================================================

CREATE OR REPLACE FUNCTION public.ileri_gebe_asi_tamamla(
  p_gorev_id   text,
  p_vaccine_id uuid,
  p_tarih      date    DEFAULT CURRENT_DATE,
  p_doz        numeric DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev       gorev_log%ROWTYPE;
  v_vax_result  jsonb;
  v_rapel_id    uuid;
  v_rapel_tarih date;
  v_is_first    boolean;
BEGIN
  SELECT * INTO v_gorev FROM gorev_log WHERE id = p_gorev_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev bulunamadı');
  END IF;
  IF v_gorev.tamamlandi THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev zaten tamamlanmış');
  END IF;

  SELECT public.add_vaccination(
    v_gorev.hayvan_id::text, p_vaccine_id, p_tarih, p_doz, 'GorevID:' || p_gorev_id
  ) INTO v_vax_result;

  IF (v_vax_result->>'ok')::boolean = false THEN
    RETURN v_vax_result;
  END IF;

  UPDATE gorev_log
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE id = p_gorev_id;

  v_is_first := v_gorev.aciklama ILIKE '%1. doz%';
  IF v_is_first THEN
    v_rapel_tarih := p_tarih + 21;
    v_rapel_id := gen_random_uuid();
    INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, parent_id, kaynak)
    VALUES (
      v_rapel_id,
      v_gorev.hayvan_id,
      'ILERI_GEBE_ASI',
      '💉 Rota-Corona Aşısı (2. doz)',
      v_rapel_tarih,
      false,
      v_gorev.stok_id,
      v_gorev.miktar,
      NULL,
      'ILERI_GEBE'
    );
  END IF;

  v_rapel_tarih := COALESCE(v_rapel_tarih, NULL);
  RETURN jsonb_build_object(
    'ok', true,
    'mesaj', 'Aşı kaydedildi',
    'rapel_tarih', v_rapel_tarih
  );
END;
$$;

-- ============================================================
-- Fix 2: Tamamlanmış görevlere etken_kod backfill
-- İlk migration sadece tamamlandi=false görevleri güncelledi
-- Scanner tamamlandi=true + etken_kod ile arar → eski tamamlanmış görevler invisible
-- ============================================================

UPDATE public.gorev_log SET etken_kod = 'OKSITOSIN'
WHERE etken_kod IS NULL AND tamamlandi = true
  AND aciklama ILIKE '%Oksitosin%';

UPDATE public.gorev_log SET etken_kod = 'PG'
WHERE etken_kod IS NULL AND tamamlandi = true
  AND aciklama ILIKE '%PG%'
  AND aciklama NOT ILIKE '%Ademin%';

UPDATE public.gorev_log SET etken_kod = 'ADEMIN'
WHERE etken_kod IS NULL AND tamamlandi = true
  AND (aciklama ILIKE '%Ademin%' AND aciklama NOT ILIKE '%Yeldif%' AND aciklama NOT ILIKE '%E Vit%');

UPDATE public.gorev_log SET etken_kod = 'E_VIT'
WHERE etken_kod IS NULL AND tamamlandi = true
  AND (aciklama ILIKE '%Yeldif%' OR aciklama ILIKE '%E Vit%');

UPDATE public.gorev_log SET etken_kod = 'KALSIYUM'
WHERE etken_kod IS NULL AND tamamlandi = true
  AND aciklama ILIKE '%Kalsiyum%';

UPDATE public.gorev_log SET etken_kod = 'ROTA'
WHERE etken_kod IS NULL AND tamamlandi = true
  AND aciklama ILIKE '%Rota%';

-- ============================================================
-- Fix 3: Eski doğum dismiss backfill
-- Son 4 buzağı (küpe 80,79,78,77) anneleri HARİÇ tüm eski doğumlar dismiss
-- Scanner bunları artık "eksik" göstermeyecek
-- ============================================================

INSERT INTO public.protokol_dismiss (hayvan_id, etken_kod, protokol, neden)
SELECT DISTINCT d.anne_id, a.ek, 'DOGUM_PROTOKOL', 'Otomatik: migration öncesi doğum'
FROM public.dogum d
CROSS JOIN (VALUES
  ('OKSITOSIN'), ('ADEMIN'), ('KALSIYUM'), ('PG'), ('E_VIT')
) AS a(ek)
WHERE d.tarih >= CURRENT_DATE - 70
  AND d.tarih <= CURRENT_DATE
  AND d.yavru_kupe NOT IN ('80','79','78','77')
ON CONFLICT (hayvan_id, etken_kod, protokol) DO NOTHING;

INSERT INTO public.protokol_dismiss (hayvan_id, etken_kod, protokol, neden)
SELECT DISTINCT d.anne_id, 'MANUAL', 'KIZGINLIK_TAKIP', 'Otomatik: migration öncesi doğum'
FROM public.dogum d
WHERE (CURRENT_DATE - d.tarih) BETWEEN 55 AND 70
  AND d.yavru_kupe NOT IN ('80','79','78','77')
ON CONFLICT (hayvan_id, etken_kod, protokol) DO NOTHING;

-- ============================================================
-- Fix 4: protokol_eksik_tara — DISTINCT ON + E_VIT tutarsızlığı
-- ============================================================

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
  -- DISTINCT ON: aynı anne için sadece en son doğumu al (ikiz doğum fix)
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
      (11, 'PG',        '11. Gün PG'),
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

      IF NOT v_found THEN
        SELECT true INTO v_found
        FROM uygulama_log u
        WHERE u.hayvan_id = v_rec.hayvan_id
          AND u.etken_kod = v_rec.ek
          AND u.tarih BETWEEN v_hedef - 3 AND v_hedef + 3
        LIMIT 1;
      END IF;

      IF NOT v_found THEN
        SELECT true INTO v_found
        FROM drug_administrations da
        JOIN treatment_days td ON td.id = da.treatment_day_id
        JOIN cases c ON c.id = td.case_id
        WHERE c.animal_id = v_rec.hayvan_id
          AND public._etken_kod_bul(da.stok_id, NULL) = v_rec.ek
          AND da.created_at::date BETWEEN v_hedef - 3 AND v_hedef + 3
        LIMIT 1;
      END IF;

      IF NOT v_found THEN
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
        'gecikme_gun', GREATEST(v_gecikme, 0),
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

          IF NOT v_found AND v_a.ek = 'ROTA' THEN
            SELECT true INTO v_found
            FROM vaccination_log vl
            JOIN vaccines v ON v.id = vl.vaccine_id
            WHERE vl.animal_id = v_rec.hayvan_id
              AND v.name ILIKE '%Rota%'
              AND vl.vaccination_date BETWEEN v_hedef - 7 AND v_hedef + 7
            LIMIT 1;
          END IF;

          IF NOT v_found THEN
            SELECT true INTO v_found
            FROM uygulama_log u
            WHERE u.hayvan_id = v_rec.hayvan_id
              AND u.etken_kod = v_a.ek
              AND u.tarih BETWEEN v_hedef - 3 AND v_hedef + 3
            LIMIT 1;
          END IF;

          IF NOT v_found THEN
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
            'gecikme_gun', GREATEST(v_gecikme, 0),
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
    WHERE (v_today - d.tarih) BETWEEN 55 AND 70
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

      IF NOT v_found THEN
        SELECT true INTO v_found
        FROM kizginlik_log k
        WHERE k.hayvan_id = v_rec.hayvan_id
          AND k.tarih >= v_rec.dogum_tarihi + 50
        LIMIT 1;
      END IF;

      IF NOT v_found THEN
        SELECT true INTO v_found
        FROM tohumlama t
        WHERE t.hayvan_id = v_rec.hayvan_id
          AND t.tarih >= v_rec.dogum_tarihi + 50
        LIMIT 1;
      END IF;

      IF NOT v_found THEN
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
        'gecikme_gun', GREATEST(v_gecikme, 0),
        'durum', v_durum,
        'tamamlanma_tarihi', v_tamamlanma,
        'kapatan_ref', v_kapatan
      );
    END;
  END LOOP;

  RETURN v_result;
END;
$$;

-- ============================================================
-- Fix 5: Ek index'ler — scanner performansı
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_dogum_anne_tarih
  ON public.dogum(anne_id, tarih DESC);

CREATE INDEX IF NOT EXISTS idx_tohumlama_hayvan_sonuc
  ON public.tohumlama(hayvan_id, sonuc, tarih);

COMMIT;
