-- ─────────────────────────────────────────────────────────────
-- Aşı Faz 1 — additive şema: vaccines kolonları + M:N + protokol
-- Aktif zincirlere (ASI_RAPEL, ILERI_GEBE_ASI) dokunmaz.
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.vaccines ADD COLUMN IF NOT EXISTS marka         text;
ALTER TABLE public.vaccines ADD COLUMN IF NOT EXISTS etken_madde   text;
ALTER TABLE public.vaccines ADD COLUMN IF NOT EXISTS protokol_tipi text;

COMMENT ON COLUMN public.vaccines.marka         IS 'Üretici firma (Ceva, Microsules) — aramada name ile taranır';
COMMENT ON COLUMN public.vaccines.etken_madde   IS 'Antijen özeti, opsiyonel';
COMMENT ON COLUMN public.vaccines.protokol_tipi IS 'Brand protokolü: tek_doz | primer_seri';

-- Bir markanın kapsadığı hastalıklar (içerik-odaklı motorun çekirdeği)
CREATE TABLE IF NOT EXISTS public.vaccine_diseases (
  vaccine_id  uuid NOT NULL REFERENCES public.vaccines(id) ON DELETE CASCADE,
  disease_id  uuid NOT NULL REFERENCES public.diseases(id) ON DELETE CASCADE,
  PRIMARY KEY (vaccine_id, disease_id)
);
COMMENT ON TABLE public.vaccine_diseases IS 'Aşı↔hastalık M:N — bir markanın koruduğu hastalıklar';

-- Markanın primer serisi (koruma kurmak için doz dizisi)
CREATE TABLE IF NOT EXISTS public.vaccine_protocol_steps (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  vaccine_id  uuid NOT NULL REFERENCES public.vaccines(id) ON DELETE CASCADE,
  adim_no     int  NOT NULL,
  offset_gun  int  NOT NULL DEFAULT 0,
  label       text,
  created_at  timestamptz DEFAULT now(),
  UNIQUE(vaccine_id, adim_no)
);
COMMENT ON TABLE public.vaccine_protocol_steps IS 'Markanın primer doz serisi — offset_gun önceki doza göre';

CREATE INDEX IF NOT EXISTS vaccine_diseases_disease_idx ON public.vaccine_diseases(disease_id);
CREATE INDEX IF NOT EXISTS vaccine_protocol_steps_vac_idx ON public.vaccine_protocol_steps(vaccine_id);

-- RLS (vaccination_schedule pattern'i: FOR ALL USING(true))
ALTER TABLE public.vaccine_diseases       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vaccine_protocol_steps ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS vaccine_diseases_all       ON public.vaccine_diseases;
DROP POLICY IF EXISTS vaccine_protocol_steps_all ON public.vaccine_protocol_steps;
CREATE POLICY vaccine_diseases_all       ON public.vaccine_diseases       FOR ALL USING (true);
CREATE POLICY vaccine_protocol_steps_all ON public.vaccine_protocol_steps FOR ALL USING (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.vaccine_diseases       TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.vaccine_protocol_steps TO anon, authenticated;
