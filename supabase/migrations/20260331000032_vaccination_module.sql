-- Migration: Aşılama Modülü — Controlled vaccine entity + protocol + log
-- Etkiler: vaccines tablosu, vaccination_schedule, vaccination_log, RPC'ler
--          gorev_log ile entegrasyon (otomatik aşı görevleri)
-- Geri alınabilir: evet — DROP TABLE vaccination_log, vaccination_schedule, vaccines

BEGIN;

-- ══════════════════════════════════════════════════════════════
-- 1. VACCINES — Controlled aşı listesi
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.vaccines (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name                text        UNIQUE NOT NULL,
  disease_target      text,                    -- Hangi hastalığa karşı
  dose                numeric     NOT NULL,    -- Standart doz
  unit                text        NOT NULL,    -- ml, gr, vb.
  route               text        NOT NULL,    -- IM, SC, PO, vb.
  repeat_interval_days integer,                -- Tekrar aralığı (gün)
  is_mandatory        boolean     DEFAULT true, -- Zorunlu aşı mı?
  stock_item_id       text        REFERENCES public.stok(id) ON DELETE SET NULL,
  created_at          timestamptz DEFAULT now()
);

COMMENT ON TABLE  public.vaccines           IS 'Controlled aşı listesi — free text yasak';
COMMENT ON COLUMN public.vaccines.disease_target IS 'Hedef hastalık (örn: Şarbon, BVD, IBR)';
COMMENT ON COLUMN public.vaccines.repeat_interval_days IS 'Yıllık=365, 6 aylık=180, vb. NULL=tek doz';
COMMENT ON COLUMN public.vaccines.stock_item_id IS 'stok.id FK — NULL ise stok düşümü yapılmaz';

-- ══════════════════════════════════════════════════════════════
-- 2. VACCINATION_SCHEDULE — Aşı protokol tanımları
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.vaccination_schedule (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  vaccine_id          uuid        NOT NULL REFERENCES public.vaccines(id) ON DELETE CASCADE,
  target_type         text        NOT NULL,    -- 'buzağı' | 'düve' | 'inek' | 'tüm'
  timing_type         text        NOT NULL,    -- 'yas' | 'gebelik' | 'dogum_sonra'
  timing_days         integer,                 -- Doğumdan/gébelenen kaç gün sonra
  sequence_order      integer,                 -- Protokol sırası (1,2,3...)
  notes               text,
  created_at          timestamptz DEFAULT now()
);

COMMENT ON TABLE  public.vaccination_schedule IS 'Aşı protokol tanımları — otomatik görev üretimi için';
COMMENT ON COLUMN public.vaccination_schedule.target_type IS 'Hedef grup: buzağı | düve | inek | tüm';
COMMENT ON COLUMN public.vaccination_schedule.timing_type IS 'Zamanlama: yas (doğumdan) | gebelik (gebelikten) | dogum_sonra';
COMMENT ON COLUMN public.vaccination_schedule.timing_days IS 'Zamanlama günü (timing_type''a göre)';
COMMENT ON COLUMN public.vaccination_schedule.sequence_order IS 'Protokol sırası — 1=ilk aşı, 2=ikinci aşı';

CREATE INDEX IF NOT EXISTS vac_schedule_vaccine_id_idx ON public.vaccination_schedule(vaccine_id);

-- ══════════════════════════════════════════════════════════════
-- 3. VACCINATION_LOG — Yapılan aşı kayıtları
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.vaccination_log (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  animal_id           text        NOT NULL REFERENCES public.hayvanlar(id),
  vaccine_id          uuid        NOT NULL REFERENCES public.vaccines(id),
  vaccination_date    date        NOT NULL DEFAULT CURRENT_DATE,
  dose_given          numeric     NOT NULL,
  unit                text        NOT NULL,
  route               text        NOT NULL,
  next_due_date       date,                    -- Bir sonraki aşı tarihi
  notes               text,
  created_at          timestamptz DEFAULT now(),
  created_by          text                     -- Kullanıcı ID (opsiyonel)
);

COMMENT ON TABLE  public.vaccination_log IS 'Yapılan aşı kayıtları — hayvan başına aşı geçmişi';
COMMENT ON COLUMN public.vaccination_log.next_due_date IS 'repeat_interval_days + vaccination_date';

CREATE INDEX IF NOT EXISTS vac_log_animal_id_idx ON public.vaccination_log(animal_id);
CREATE INDEX IF NOT EXISTS vac_log_vaccine_id_idx ON public.vaccination_log(vaccine_id);
CREATE INDEX IF NOT EXISTS vac_log_date_idx ON public.vaccination_log(vaccination_date);

-- ══════════════════════════════════════════════════════════════
-- 4. TRIGGER: vaccination_log → stok_hareket (ledger)
-- ══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.vaccination_stok_dusum()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok_id   text;
  v_vaccine_name text;
  v_kupe_no   text;
  v_guncel    numeric;
BEGIN
  -- Aşının stok bağlantısını kontrol et
  SELECT v.stock_item_id, v.name
  INTO   v_stok_id, v_vaccine_name
  FROM   public.vaccines v
  WHERE  v.id = NEW.vaccine_id;

  -- Stok bağlantısı yoksa ledger kaydı yapmadan geç
  IF v_stok_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Hayvan küpe no'sunu bul (notlar için)
  SELECT kupe_no INTO v_kupe_no
  FROM   public.hayvanlar
  WHERE  id = NEW.animal_id;

  -- Stok yeterliliği kontrolü
  SELECT COALESCE(s.baslangic_miktar, 0)
         - COALESCE((
             SELECT SUM(sh.miktar)
             FROM   public.stok_hareket sh
             WHERE  sh.stok_id = v_stok_id
               AND  NOT sh.iptal
           ), 0)
  INTO v_guncel
  FROM public.stok s
  WHERE s.id = v_stok_id;

  IF v_guncel < NEW.dose_given THEN
    RAISE EXCEPTION 'Yetersiz stok: % (mevcut: %, istenen: %)',
      v_vaccine_name, v_guncel, NEW.dose_given;
  END IF;

  -- Ledger: pozitif = kullanım
  INSERT INTO public.stok_hareket (
    stok_id, tur, miktar, notlar, iptal,
    referans_tipi, referans_id
  ) VALUES (
    v_stok_id,
    'Aşı',
    NEW.dose_given,
    v_vaccine_name || ' — ' || COALESCE(v_kupe_no, NEW.animal_id),
    false,
    'vaccination',
    NEW.id::text
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_vaccination_stok ON public.vaccination_log;
CREATE TRIGGER trg_vaccination_stok
  AFTER INSERT ON public.vaccination_log
  FOR EACH ROW EXECUTE FUNCTION public.vaccination_stok_dusum();

-- ══════════════════════════════════════════════════════════════
-- 5. RPC: add_vaccination — Aşı uygula + stok düş + görev üret
-- ══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.add_vaccination(
  p_animal_id     text,
  p_vaccine_id    uuid,
  p_date          date    DEFAULT CURRENT_DATE,
  p_dose_override numeric DEFAULT NULL,  -- NULL ise vaccine.dose kullan
  p_notes         text    DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_vaccine     record;
  v_new_id      uuid;
  v_next_due    date;
  v_dose        numeric;
  v_animal      record;
  v_islem_id    text := gen_random_uuid()::text;
BEGIN
  -- Hayvan kontrolü
  SELECT * INTO v_animal FROM public.hayvanlar WHERE id = p_animal_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  -- Aşı bilgilerini al
  SELECT * INTO v_vaccine FROM public.vaccines WHERE id = p_vaccine_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Aşı kaydı bulunamadı');
  END IF;

  -- Doz belirle (override veya default)
  v_dose := COALESCE(p_dose_override, v_vaccine.dose);

  -- Bir sonraki aşı tarihi (tekrar aralığı varsa)
  IF v_vaccine.repeat_interval_days IS NOT NULL THEN
    v_next_due := p_date + (v_vaccine.repeat_interval_days || ' days')::interval;
  END IF;

  -- Aşı kaydı oluştur
  INSERT INTO public.vaccination_log (
    animal_id, vaccine_id, vaccination_date, dose_given, unit, route, next_due_date, notes
  ) VALUES (
    p_animal_id, p_vaccine_id, p_date, v_dose,
    v_vaccine.unit, v_vaccine.route, v_next_due, p_notes
  )
  RETURNING id INTO v_new_id;

  -- Otomatik görev üret (bir sonraki aşı hatırlatması)
  IF v_next_due IS NOT NULL THEN
    INSERT INTO public.gorev_log (
      hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi
    ) VALUES (
      p_animal_id,
      'ASI_HATIRLATMA',
      v_vaccine.name || ' — Tekrar dozu',
      v_next_due,
      false
    );
  END IF;

  -- islem_log kaydı (geri al için)
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'ASI_KAYDI',
    p_animal_id,
    v_new_id::text,
    'vaccination_log',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'vaccination_log', 'id', v_new_id::text)
      ),
      'guncellenen', '[]'::jsonb,
      'vaccine_name', v_vaccine.name,
      'next_due', v_next_due
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'vaccination_id', v_new_id,
    'next_due', v_next_due,
    'islem_id', v_islem_id
  );
END;
$$;

-- ══════════════════════════════════════════════════════════════
-- 6. RPC: get_vaccination_schedule — Hayvan için protokol öner
-- ══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.get_vaccination_schedule(
  p_animal_id text
) RETURNS TABLE(
  vaccine_id        uuid,
  vaccine_name      text,
  disease_target    text,
  dose              numeric,
  unit              text,
  route             text,
  schedule_date     date,
  is_due            boolean,
  notes             text
) LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_animal        record;
  v_birth_date    date;
  v_today         date := CURRENT_DATE;
  v_age_days      integer;
  v_schedule_rec  record;
  v_last_vac_date date;
BEGIN
  -- Hayvan bilgilerini al
  SELECT * INTO v_animal
  FROM public.hayvanlar
  WHERE id = p_animal_id AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN;
  END IF;

  v_birth_date := v_animal.dogum_tarihi;
  v_age_days := CASE
    WHEN v_birth_date IS NOT NULL
    THEN v_today - v_birth_date
    ELSE 0
  END;

  -- Her aşı protokolü için
  FOR v_schedule_rec IN
    SELECT vs.*, v.name as vaccine_name, v.disease_target, v.dose, v.unit, v.route
    FROM public.vaccination_schedule vs
    JOIN public.vaccines v ON v.id = vs.vaccine_id
    WHERE vs.target_type IN ('tüm', v_animal.cinsiyet,
      CASE WHEN v_animal.cinsiyet = 'Dişi' AND v_animal.yas_gun < 365 THEN 'buzağı'
           WHEN v_animal.cinsiyet = 'Dişi' AND v_animal.yas_gun < 730 THEN 'düve'
           ELSE 'inek' END)
    ORDER BY vs.sequence_order
  LOOP
    -- Zamanlama tipi göre tarih hesapla
    IF v_schedule_rec.timing_type = 'yas' AND v_birth_date IS NOT NULL THEN
      schedule_date := v_birth_date + (v_schedule_rec.timing_days || ' days')::interval;
    ELSIF v_schedule_rec.timing_type = 'dogum_sonra' THEN
      -- Son doğum tarihini bul
      SELECT MAX(tarih) INTO v_last_vac_date
      FROM public.dogum
      WHERE hayvan_id = p_animal_id;
      
      IF v_last_vac_date IS NOT NULL THEN
        schedule_date := v_last_vac_date + (v_schedule_rec.timing_days || ' days')::interval;
      ELSE
        CONTINUE; -- Doğum yoksa bu protokolü atla
      END IF;
    ELSE
      CONTINUE; -- Diğer timing_type'lar henüz implement değil
    END IF;

    -- Geçmiş mi, gelecek mi?
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

-- ══════════════════════════════════════════════════════════════
-- 7. RPC: list_vaccinations — Hayvan aşı geçmişi
-- ══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.list_vaccinations(
  p_animal_id text
) RETURNS TABLE(
  id              uuid,
  vaccine_name    text,
  disease_target  text,
  vaccination_date date,
  dose_given      numeric,
  unit            text,
  route           text,
  next_due_date   date,
  notes           text
) LANGUAGE plpgsql STABLE AS $$
BEGIN
  RETURN QUERY
  SELECT
    vl.id,
    v.name,
    v.disease_target,
    vl.vaccination_date,
    vl.dose_given,
    vl.unit,
    vl.route,
    vl.next_due_date,
    vl.notes
  FROM public.vaccination_log vl
  JOIN public.vaccines v ON v.id = vl.vaccine_id
  WHERE vl.animal_id = p_animal_id
  ORDER BY vl.vaccination_date DESC;
END;
$$;

-- ══════════════════════════════════════════════════════════════
-- 8. RLS
-- ══════════════════════════════════════════════════════════════
ALTER TABLE public.vaccines             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vaccination_schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vaccination_log      ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS vaccines_select             ON public.vaccines;
DROP POLICY IF EXISTS vac_schedule_select         ON public.vaccination_schedule;
DROP POLICY IF EXISTS vac_log_all                 ON public.vaccination_log;

CREATE POLICY vaccines_select         ON public.vaccines             FOR ALL USING (true);
CREATE POLICY vac_schedule_select     ON public.vaccination_schedule FOR ALL USING (true);
CREATE POLICY vac_log_all             ON public.vaccination_log      FOR ALL USING (true);

-- SECURITY DEFINER GRANTS
GRANT EXECUTE ON FUNCTION public.add_vaccination       TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_vaccination_schedule TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_vaccinations     TO anon, authenticated;

-- ══════════════════════════════════════════════════════════════
-- 9. SEED DATA — Türkiye'de yaygın sığır aşıları
-- ══════════════════════════════════════════════════════════════
INSERT INTO public.vaccines (name, disease_target, dose, unit, route, repeat_interval_days, is_mandatory) VALUES
  ('Şarbon Aşısı',           'Şarbon',              2, 'ml', 'SC', 365, true),
  ('BVD Aşısı',              'BVD (Viral Diare)',   2, 'ml', 'IM', 365, true),
  ('IBR Aşısı',              'IBR (Rinotracheitis)', 2, 'ml', 'IM', 365, true),
  ('Leptospirosis Aşısı',    'Leptospirosis',       2, 'ml', 'IM', 365, true),
  ('BRSV Aşısı',             'BRSV (Solunum)',      2, 'ml', 'IM', 365, false),
  ('Piogen Aşısı',           'Piogen (Yavru Atma)', 2, 'ml', 'IM', 365, false),
  ('Clostridium Aşısı',      'Clostridial Hast.',   5, 'ml', 'IM', 365, false),
  ('E. coli Aşısı',          'E. coli (Buzağı)',    2, 'ml', 'IM', 365, false),
  ('Rotavirus Aşısı',        'Rotavirus (Buzağı)',  2, 'ml', 'IM', 365, false),
  ('Coronavirus Aşısı',      'Coronavirus (Buzağı)',2, 'ml', 'IM', 365, false)
ON CONFLICT (name) DO NOTHING;

-- ══════════════════════════════════════════════════════════════
-- 10. SEED DATA — Aşı protokolü (örnek)
-- ══════════════════════════════════════════════════════════════
-- Buzağı protokolü: 2-4-6 aylık
INSERT INTO public.vaccination_schedule (vaccine_id, target_type, timing_type, timing_days, sequence_order, notes)
SELECT v.id, 'buzağı', 'yas', 60, 1, 'İlk BVD dozu'
FROM public.vaccines v WHERE v.name = 'BVD Aşısı'
ON CONFLICT DO NOTHING;

INSERT INTO public.vaccination_schedule (vaccine_id, target_type, timing_type, timing_days, sequence_order, notes)
SELECT v.id, 'buzağı', 'yas', 120, 2, 'İkinci BVD dozu (pekiştirme)'
FROM public.vaccines v WHERE v.name = 'BVD Aşısı'
ON CONFLICT DO NOTHING;

INSERT INTO public.vaccination_schedule (vaccine_id, target_type, timing_type, timing_days, sequence_order, notes)
SELECT v.id, 'buzağı', 'yas', 180, 3, 'Şarbon ilk doz'
FROM public.vaccines v WHERE v.name = 'Şarbon Aşısı'
ON CONFLICT DO NOTHING;

-- Düve protokolü: Tohumlama öncesi
INSERT INTO public.vaccination_schedule (vaccine_id, target_type, timing_type, timing_days, sequence_order, notes)
SELECT v.id, 'düve', 'yas', 365, 4, 'Tohumlama öncesi IBR'
FROM public.vaccines v WHERE v.name = 'IBR Aşısı'
ON CONFLICT DO NOTHING;

-- Doğum sonrası protokol
INSERT INTO public.vaccination_schedule (vaccine_id, target_type, timing_type, timing_days, sequence_order, notes)
SELECT v.id, 'inek', 'dogum_sonra', 30, 5, 'Doğum sonrası Leptospirosis'
FROM public.vaccines v WHERE v.name = 'Leptospirosis Aşısı'
ON CONFLICT DO NOTHING;

COMMIT;

-- PostgREST schema cache yenile
NOTIFY pgrst, 'reload schema';
