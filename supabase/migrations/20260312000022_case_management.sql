-- ══════════════════════════════════════════════════════════════
-- MIGRATION 022 — CASE MANAGEMENT SYSTEM
-- EgeSüt ERP — 2026-03-12
--
-- Değişiklikler:
-- 1. diseases        — controlled entity (FK ile tanı)
-- 2. drugs           — controlled entity (FK ile ilaç, stok bağlı)
-- 3. cases           — vaka katmanı (hayvanlar → cases)
-- 4. treatment_days  — günlük tedavi kaydı
-- 5. drug_administrations — ilaç uygulama (controlled FK)
-- 6. Trigger: day_no otomatik artar
-- 7. Trigger: drug_administrations INSERT → stok_hareket ledger
-- 8. View: treatment_timeline
-- 9. RPC: create_case, add_treatment_day, add_drug_administration, close_case
-- 10. RLS policies
-- 11. Seed data: diseases, drugs
--
-- Dokunulmayan tablolar: hayvanlar, stok, stok_hareket, hastalik_log, tedavi
-- Stok ledger mantığı: stok_hareket.miktar pozitif = kullanım
--   (frontend: guncel = baslangic_miktar - SUM(stok_hareket.miktar WHERE NOT iptal))
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- 1. DISEASES — Controlled entity
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.diseases (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text        UNIQUE NOT NULL,
  category    text,
  created_at  timestamptz DEFAULT now()
);

COMMENT ON TABLE  public.diseases           IS 'Controlled hastalık listesi — free text yasak';
COMMENT ON COLUMN public.diseases.category  IS 'Meme | Üreme | Metabolik | Ayak | Solunum | Sindirim | Buzağı | Diğer';

-- ──────────────────────────────────────────────────────────────
-- 2. DRUGS — Controlled entity, stok ile bağlı
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.drugs (
  id             uuid  PRIMARY KEY DEFAULT gen_random_uuid(),
  name           text  UNIQUE NOT NULL,
  stock_item_id  text  REFERENCES public.stok(id) ON DELETE SET NULL,
  default_unit   text,
  default_route  text,
  created_at     timestamptz DEFAULT now()
);

COMMENT ON TABLE  public.drugs                IS 'Controlled ilaç listesi — free text yasak';
COMMENT ON COLUMN public.drugs.stock_item_id  IS 'stok.id FK — NULL ise stok düşümü yapılmaz';
COMMENT ON COLUMN public.drugs.default_route  IS 'IM | IV | SC | PO | Topikal | Intrauterin';

-- ──────────────────────────────────────────────────────────────
-- 3. CASES — Vaka katmanı
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.cases (
  id          uuid  PRIMARY KEY DEFAULT gen_random_uuid(),
  animal_id   text  NOT NULL REFERENCES public.hayvanlar(id),
  disease_id  uuid  NOT NULL REFERENCES public.diseases(id),
  start_date  date  NOT NULL DEFAULT CURRENT_DATE,
  status      text  NOT NULL DEFAULT 'active',
  notes       text,
  created_at  timestamptz DEFAULT now(),
  closed_at   timestamptz,
  CONSTRAINT cases_status_check CHECK (status IN ('active','closed'))
);

COMMENT ON TABLE  public.cases         IS 'Veteriner vaka kaydı — hayvan başına aktif/kapalı vakalar';
COMMENT ON COLUMN public.cases.status  IS 'active | closed';

CREATE INDEX IF NOT EXISTS cases_animal_id_idx ON public.cases(animal_id);
CREATE INDEX IF NOT EXISTS cases_status_idx    ON public.cases(status);

-- ──────────────────────────────────────────────────────────────
-- 4. TREATMENT DAYS — Günlük tedavi
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.treatment_days (
  id               uuid  PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id          uuid  NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  day_no           integer,
  treatment_date   date  NOT NULL DEFAULT CURRENT_DATE,
  notes            text,
  created_at       timestamptz DEFAULT now()
);

COMMENT ON COLUMN public.treatment_days.day_no IS 'Trigger ile otomatik artar — frontend set etmez';

CREATE INDEX IF NOT EXISTS treatment_days_case_id_idx ON public.treatment_days(case_id);

-- ──────────────────────────────────────────────────────────────
-- 5. DRUG ADMINISTRATIONS — İlaç uygulama (controlled FK)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.drug_administrations (
  id                uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  treatment_day_id  uuid    NOT NULL REFERENCES public.treatment_days(id) ON DELETE CASCADE,
  drug_id           uuid    NOT NULL REFERENCES public.drugs(id),
  dose              numeric NOT NULL CHECK (dose > 0),
  unit              text    NOT NULL,
  route             text,
  notes             text,
  created_at        timestamptz DEFAULT now(),
  CONSTRAINT drug_administrations_route_check
    CHECK (route IS NULL OR route IN ('IM','IV','SC','PO','Topikal','Intrauterin'))
);

COMMENT ON TABLE  public.drug_administrations  IS 'Controlled ilaç uygulama — drug_id FK zorunlu';
COMMENT ON COLUMN public.drug_administrations.route IS 'IM | IV | SC | PO | Topikal | Intrauterin';

CREATE INDEX IF NOT EXISTS drug_admin_day_id_idx ON public.drug_administrations(treatment_day_id);

-- ──────────────────────────────────────────────────────────────
-- 6. TRIGGER: day_no otomatik artar
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_treatment_day_no()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.day_no IS NULL THEN
    SELECT COALESCE(MAX(day_no), 0) + 1
    INTO   NEW.day_no
    FROM   public.treatment_days
    WHERE  case_id = NEW.case_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_day_no ON public.treatment_days;
CREATE TRIGGER trg_set_day_no
  BEFORE INSERT ON public.treatment_days
  FOR EACH ROW EXECUTE FUNCTION public.set_treatment_day_no();

-- ──────────────────────────────────────────────────────────────
-- 7. TRIGGER: drug_administrations → stok_hareket ledger
--
-- Mevcut ledger mantığı korunur:
--   stok_hareket.miktar POZİTİF = kullanım
--   frontend: guncel = baslangic_miktar - SUM(miktar WHERE NOT iptal)
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.drug_administration_stok_dusum()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok_id   text;
  v_drug_name text;
  v_animal_id text;
  v_kupe_no   text;
  v_guncel    numeric;
BEGIN
  -- İlacın stok bağlantısını kontrol et
  SELECT d.stock_item_id, d.name
  INTO   v_stok_id, v_drug_name
  FROM   public.drugs d
  WHERE  d.id = NEW.drug_id;

  -- Stok bağlantısı yoksa ledger kaydı yapmadan geç
  IF v_stok_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Hayvan küpe no'sunu bul (notlar için)
  SELECT c.animal_id INTO v_animal_id
  FROM   public.treatment_days td
  JOIN   public.cases c ON c.id = td.case_id
  WHERE  td.id = NEW.treatment_day_id;

  SELECT kupe_no INTO v_kupe_no
  FROM   public.hayvanlar
  WHERE  id = v_animal_id;

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

  IF v_guncel < NEW.dose THEN
    RAISE EXCEPTION 'Yetersiz stok: % (mevcut: %, istenen: %)',
      v_drug_name, v_guncel, NEW.dose;
  END IF;

  -- Ledger: pozitif = kullanım (frontend bu değeri SUM'dan düşürür)
  INSERT INTO public.stok_hareket (
    stok_id, tur, miktar, notlar, iptal,
    referans_tipi, referans_id
  ) VALUES (
    v_stok_id,
    'Tedavi',
    NEW.dose,   -- POZİTİF — mevcut ledger mantığıyla uyumlu
    v_drug_name || ' — ' || COALESCE(v_kupe_no, v_animal_id),
    false,
    'drug_administration',
    NEW.id::text
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_drug_administration_stok ON public.drug_administrations;
CREATE TRIGGER trg_drug_administration_stok
  AFTER INSERT ON public.drug_administrations
  FOR EACH ROW EXECUTE FUNCTION public.drug_administration_stok_dusum();

-- ──────────────────────────────────────────────────────────────
-- 8. VIEW: treatment_timeline
-- ──────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS public.treatment_timeline CASCADE;
CREATE VIEW public.treatment_timeline AS
SELECT
  h.id          AS animal_id,
  h.kupe_no     AS kupe_no,
  c.id          AS case_id,
  c.status      AS case_status,
  c.start_date  AS case_start,
  dis.name      AS disease,
  dis.category  AS disease_category,
  td.id         AS day_id,
  td.day_no,
  td.treatment_date,
  dr.id         AS drug_id,
  dr.name       AS drug,
  da.id         AS administration_id,
  da.dose,
  da.unit,
  da.route,
  da.notes      AS admin_notes
FROM public.drug_administrations da
JOIN public.treatment_days  td  ON td.id  = da.treatment_day_id
JOIN public.cases           c   ON c.id   = td.case_id
JOIN public.hayvanlar       h   ON h.id   = c.animal_id
JOIN public.drugs           dr  ON dr.id  = da.drug_id
JOIN public.diseases        dis ON dis.id = c.disease_id;

COMMENT ON VIEW public.treatment_timeline IS 'Vaka → gün → ilaç timeline, frontend için hazır';

-- ──────────────────────────────────────────────────────────────
-- 9. RPC FONKSİYONLARI
-- ──────────────────────────────────────────────────────────────

-- 9a. create_case
DROP FUNCTION IF EXISTS public.create_case(text, uuid, text);
CREATE OR REPLACE FUNCTION public.create_case(
  p_animal_id   text,
  p_disease_id  uuid,
  p_notes       text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_new_id  uuid;
  v_animal  record;
  v_disease record;
BEGIN
  SELECT * INTO v_animal FROM public.hayvanlar WHERE id = p_animal_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  SELECT * INTO v_disease FROM public.diseases WHERE id = p_disease_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hastalık kaydı bulunamadı');
  END IF;

  -- Aynı hayvanda aynı hastalıkta zaten aktif vaka var mı?
  IF EXISTS (
    SELECT 1 FROM public.cases
    WHERE animal_id = p_animal_id
      AND disease_id = p_disease_id
      AND status = 'active'
  ) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu hayvan için zaten aktif bir ' || v_disease.name || ' vakası mevcut');
  END IF;

  INSERT INTO public.cases (animal_id, disease_id, notes)
  VALUES (p_animal_id, p_disease_id, p_notes)
  RETURNING id INTO v_new_id;

  RETURN jsonb_build_object('ok', true, 'case_id', v_new_id);
END;
$$;

-- 9b. add_treatment_day
DROP FUNCTION IF EXISTS public.add_treatment_day(uuid);
CREATE OR REPLACE FUNCTION public.add_treatment_day(
  p_case_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_new_id uuid;
  v_case   record;
BEGIN
  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadı');
  END IF;

  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakaya gün eklenemez');
  END IF;

  INSERT INTO public.treatment_days (case_id)
  VALUES (p_case_id)
  RETURNING id INTO v_new_id;

  RETURN jsonb_build_object('ok', true, 'day_id', v_new_id);
END;
$$;

-- 9c. add_drug_administration
DROP FUNCTION IF EXISTS public.add_drug_administration(uuid, uuid, numeric, text, text);
CREATE OR REPLACE FUNCTION public.add_drug_administration(
  p_day_id   uuid,
  p_drug_id  uuid,
  p_dose     numeric,
  p_unit     text,
  p_route    text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_new_id   uuid;
  v_day      record;
  v_case     record;
  v_drug     record;
BEGIN
  SELECT * INTO v_day FROM public.treatment_days WHERE id = p_day_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tedavi günü bulunamadı');
  END IF;

  SELECT * INTO v_case FROM public.cases WHERE id = v_day.case_id;
  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakaya ilaç eklenemez');
  END IF;

  SELECT * INTO v_drug FROM public.drugs WHERE id = p_drug_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'İlaç kaydı bulunamadı');
  END IF;

  IF p_dose IS NULL OR p_dose <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçerli bir doz girin');
  END IF;

  INSERT INTO public.drug_administrations (
    treatment_day_id, drug_id, dose, unit, route
  ) VALUES (
    p_day_id, p_drug_id, p_dose,
    COALESCE(p_unit, v_drug.default_unit, ''),
    COALESCE(p_route, v_drug.default_route)
  )
  RETURNING id INTO v_new_id;

  RETURN jsonb_build_object('ok', true, 'administration_id', v_new_id);
END;
$$;

-- 9d. close_case
DROP FUNCTION IF EXISTS public.close_case(uuid);
CREATE OR REPLACE FUNCTION public.close_case(
  p_case_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.cases
  SET status    = 'closed',
      closed_at = now()
  WHERE id = p_case_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 10. RLS
-- ──────────────────────────────────────────────────────────────
ALTER TABLE public.diseases             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drugs                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cases                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.treatment_days       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drug_administrations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS diseases_select             ON public.diseases;
DROP POLICY IF EXISTS drugs_select                ON public.drugs;
DROP POLICY IF EXISTS cases_all                   ON public.cases;
DROP POLICY IF EXISTS treatment_days_all          ON public.treatment_days;
DROP POLICY IF EXISTS drug_administrations_all    ON public.drug_administrations;

CREATE POLICY diseases_select          ON public.diseases             FOR SELECT USING (true);
CREATE POLICY drugs_select             ON public.drugs                FOR SELECT USING (true);
CREATE POLICY cases_all                ON public.cases                FOR ALL    USING (true);
CREATE POLICY treatment_days_all       ON public.treatment_days       FOR ALL    USING (true);
CREATE POLICY drug_administrations_all ON public.drug_administrations FOR ALL    USING (true);

-- SECURITY DEFINER GRANTS
GRANT EXECUTE ON FUNCTION public.create_case             TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.add_treatment_day       TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.add_drug_administration TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.close_case              TO anon, authenticated;

-- ──────────────────────────────────────────────────────────────
-- 11. SEED DATA — Diseases
-- ──────────────────────────────────────────────────────────────
INSERT INTO public.diseases (name, category) VALUES
  ('Mastit',                    'Meme'),
  ('Subklinik Mastit',          'Meme'),
  ('Klinik Mastit',             'Meme'),
  ('Metrit',                    'Üreme'),
  ('Endometrit',                'Üreme'),
  ('Pyometra',                  'Üreme'),
  ('Retensiyo Sekundinarum',    'Üreme'),
  ('Kistik Over',               'Üreme'),
  ('Anoestrus',                 'Üreme'),
  ('Hipokalsemi (Süt Humması)', 'Metabolik'),
  ('Ketozis',                   'Metabolik'),
  ('Ruminal Asidoz',            'Metabolik'),
  ('Timpani',                   'Metabolik'),
  ('Şirden Deplasmanı',         'Metabolik'),
  ('Topallık (Dermatit)',       'Ayak'),
  ('Topallık (Laminit)',        'Ayak'),
  ('Beyaz Çizgi Hastalığı',     'Ayak'),
  ('Tırnak Yarası',             'Ayak'),
  ('Pnömoni',                   'Solunum'),
  ('Buzağı İshali',             'Buzağı'),
  ('Buzağı Göbek İltihabı',    'Buzağı'),
  ('Neonatal Zayıflık',         'Buzağı')
ON CONFLICT (name) DO NOTHING;

-- ──────────────────────────────────────────────────────────────
-- 12. SEED DATA — Drugs (stock_item_id başlangıçta NULL)
--     UI'dan stok kalemini drugs tablosuna bağlamak gerekir
-- ──────────────────────────────────────────────────────────────
INSERT INTO public.drugs (name, default_unit, default_route) VALUES
  ('Enrofloksasin',    'ml',  'IM'),
  ('Oksitetrasiklin',  'ml',  'IM'),
  ('Penisilin',        'ml',  'IM'),
  ('Meloksikam',       'ml',  'IM'),
  ('Ketoprofen',       'ml',  'IM'),
  ('Flunixin',         'ml',  'IV'),
  ('Deksametazon',     'ml',  'IM'),
  ('B Kompleks',       'ml',  'IM'),
  ('Kalsiyum Boroglukonat', 'ml', 'IV'),
  ('Magnezyum Sülfat', 'ml',  'IV'),
  ('Glukoz %50',       'ml',  'IV'),
  ('Elektrolit',       'gr',  'PO'),
  ('Rumen Stimülanı',  'ml',  'PO'),
  ('Oksitoksin',       'ml',  'IM'),
  ('Progesteron',      'ml',  'IM'),
  ('GnRH',             'ml',  'IM'),
  ('PGF2α',            'ml',  'IM'),
  ('Antiparaziter',    'ml',  'SC'),
  ('Vitamin AD3E',     'ml',  'IM'),
  ('Vitamin C',        'ml',  'IV')
ON CONFLICT (name) DO NOTHING;

-- ──────────────────────────────────────────────────────────────
-- PostgREST schema cache yenile
-- ──────────────────────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
