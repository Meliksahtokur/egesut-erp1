-- Migration: Protokol Uyarı Sistemi — protokol_dismiss + protokol_eksik_tara scanner (Task 10-11)
-- Etkiler: yeni protokol_dismiss tablosu, protokol_eksik_tara scanner RPC
-- Bağımlılık: 20260603000001 (_etken_kod_bul), 20260603000002 (uygulama_log), 20260603000003 (trigger'lar)
-- Not: Doğum protokol adımları unnest(ARRAY[ROW::record]) yerine VALUES + CROSS JOIN ile yazıldı

BEGIN;

-- ============================================================
-- Task 10: protokol_dismiss Tablosu
-- ============================================================

CREATE TABLE IF NOT EXISTS public.protokol_dismiss (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hayvan_id text NOT NULL REFERENCES public.hayvanlar(id),
  etken_kod text NOT NULL,
  protokol text NOT NULL,
  tarih timestamptz DEFAULT now(),
  neden text,
  UNIQUE(hayvan_id, etken_kod, protokol)
);

COMMENT ON TABLE public.protokol_dismiss IS 'Kullanıcı tarafından geçersiz kılınan protokol uyarıları';

ALTER TABLE public.protokol_dismiss ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='protokol_dismiss' AND policyname='anon_all_protokol_dismiss') THEN
    CREATE POLICY anon_all_protokol_dismiss ON public.protokol_dismiss FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.protokol_dismiss TO anon, authenticated;

-- ============================================================
-- Task 11: protokol_eksik_tara Scanner RPC
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
  -- unnest(ARRAY[ROW::record]) yerine VALUES + CROSS JOIN
  FOR v_rec IN
    SELECT d.id AS dogum_id, d.anne_id AS hayvan_id, d.tarih AS dogum_tarihi,
           h.kupe_no, h.grup,
           a.gun, a.ek, a.aciklama
    FROM public.dogum d
    JOIN public.hayvanlar h ON h.id = d.anne_id AND h.durum = 'Aktif'
    CROSS JOIN (VALUES
      (0,  'OKSITOSIN', 'Doğum günü: Oksitosin'),
      (0,  'ADEMIN',    'Doğum günü: Ademin'),
      (0,  'KALSIYUM',  'Doğum günü: Kalsiyum'),
      (2,  'PG',        '2. Gün PG'),
      (11, 'PG',        '11. Gün PG'),
      (25, 'PG',        '25. Gün PG'),
      (53, 'ADEMIN',    '53. Gün: Ademin'),
      (53, 'E_VIT',     '53. Gün: Yeldif'),
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

      -- 1. gorev_log tamamlanmış mı?
      SELECT true, g.tamamlanma_tarihi, g.kapatan_ref
      INTO v_found, v_tamamlanma, v_kapatan
      FROM gorev_log g
      WHERE g.hayvan_id = v_rec.hayvan_id
        AND g.etken_kod = v_rec.ek
        AND g.tamamlandi = true
        AND g.hedef_tarih BETWEEN v_hedef - 3 AND v_hedef + 3
      LIMIT 1;

      -- 2. uygulama_log
      IF NOT v_found THEN
        SELECT true INTO v_found
        FROM uygulama_log u
        WHERE u.hayvan_id = v_rec.hayvan_id
          AND u.etken_kod = v_rec.ek
          AND u.tarih BETWEEN v_hedef - 3 AND v_hedef + 3
        LIMIT 1;
      END IF;

      -- 3. drug_administrations (case üzerinden)
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

      -- 4. protokol_dismiss
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

  -- ═══ C. KIZGINLIK TAKİBİ (58-70 gün) ═══
  FOR v_rec IN
    SELECT d.id AS dogum_id, d.anne_id AS hayvan_id, d.tarih AS dogum_tarihi,
           h.kupe_no, h.grup
    FROM public.dogum d
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

-- Scanner performans index'leri
CREATE INDEX IF NOT EXISTS idx_dogum_anne_tarih ON public.dogum(anne_id, tarih);
CREATE INDEX IF NOT EXISTS idx_tohumlama_hayvan_sonuc_tarih ON public.tohumlama(hayvan_id, sonuc, tarih);

COMMIT;
