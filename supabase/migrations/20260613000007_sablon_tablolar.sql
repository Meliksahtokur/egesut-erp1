-- 20260613000007_sablon_tablolar.sql
-- #63 Şablon tedavi planlama — şema

-- ── Şablon başlığı ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tedavi_sablonu (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ad          text UNIQUE NOT NULL,
  aciklama    text,
  aktif       boolean DEFAULT true,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);
COMMENT ON TABLE public.tedavi_sablonu IS 'Kullanıcı tanımlı tedavi şablonu başlığı (#63)';

-- ── Şablon ↔ Hastalık (çoka-çok) — surrogate id (IDB keyPath uyumu) ──
CREATE TABLE IF NOT EXISTS public.sablon_hastalik_eslem (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sablon_id   uuid NOT NULL REFERENCES public.tedavi_sablonu(id) ON DELETE CASCADE,
  disease_id  uuid NOT NULL REFERENCES public.diseases(id)       ON DELETE CASCADE,
  created_at  timestamptz DEFAULT now(),
  CONSTRAINT she_uniq UNIQUE (sablon_id, disease_id)
);
CREATE INDEX IF NOT EXISTS she_disease_idx ON public.sablon_hastalik_eslem(disease_id);
CREATE INDEX IF NOT EXISTS she_sablon_idx  ON public.sablon_hastalik_eslem(sablon_id);

-- ── Şablon kalemleri (p_sessions + gun_no) ──────────────────────
CREATE TABLE IF NOT EXISTS public.tedavi_sablonu_kalem (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sablon_id        uuid     NOT NULL REFERENCES public.tedavi_sablonu(id) ON DELETE CASCADE,
  gun_no           smallint NOT NULL CHECK (gun_no > 0),
  planned_time     time     NOT NULL,
  stok_id          text     REFERENCES public.stok(id),
  drug_product_id  uuid     REFERENCES public.drug_products(id),
  dose             numeric  NOT NULL CHECK (dose > 0),
  unit             text     NOT NULL,
  route            text     CHECK (route IS NULL OR route IN ('IM','IV','SC','PO','Topikal','Intrauterin')),
  created_at       timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS tsk_sablon_idx ON public.tedavi_sablonu_kalem(sablon_id, gun_no, planned_time);

-- ── RLS (anon_all pattern — ground_truth ile aynı) ──────
ALTER TABLE public.tedavi_sablonu        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sablon_hastalik_eslem ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tedavi_sablonu_kalem  ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS anon_all_tedavi_sablonu        ON public.tedavi_sablonu;
DROP POLICY IF EXISTS anon_all_sablon_hastalik_eslem ON public.sablon_hastalik_eslem;
DROP POLICY IF EXISTS anon_all_tedavi_sablonu_kalem  ON public.tedavi_sablonu_kalem;
CREATE POLICY anon_all_tedavi_sablonu        ON public.tedavi_sablonu        FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY anon_all_sablon_hastalik_eslem ON public.sablon_hastalik_eslem FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY anon_all_tedavi_sablonu_kalem  ON public.tedavi_sablonu_kalem  FOR ALL USING (true) WITH CHECK (true);

GRANT ALL ON public.tedavi_sablonu        TO anon, authenticated;
GRANT ALL ON public.sablon_hastalik_eslem TO anon, authenticated;
GRANT ALL ON public.tedavi_sablonu_kalem  TO anon, authenticated;
