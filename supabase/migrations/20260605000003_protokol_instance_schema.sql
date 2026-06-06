BEGIN;

-- 1. protokol_instance tablosu
CREATE TABLE public.protokol_instance (
  id            uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  hayvan_id     text        NOT NULL REFERENCES public.hayvanlar(id) ON DELETE CASCADE,
  tip           text        NOT NULL,  -- UREME | BAKIM | SAGLIK
  alttip        text        NOT NULL,  -- KIZGINLIK|TOHUMLAMA|GEBELIK|DOGUM | BUZAGI|BESLEME|PADOK|SUTTEN_KESME | TEDAVI|ASI|MUAYENE
  kaynak_ref    text        NOT NULL,  -- gorev_log.kaynak ile eşleşen değer
  baslangic     date        NOT NULL,
  durum         text        NOT NULL DEFAULT 'aktif',  -- aktif | tamamlandi | iptal
  kapandi_at    timestamptz,
  kapandi_sebep text,                  -- DOGUM | OLUM | SATIS | MANUEL | TAMAMLANDI
  created_at    timestamptz DEFAULT now(),
  CONSTRAINT protokol_instance_kaynak_unique UNIQUE (kaynak_ref)
);

ALTER TABLE public.protokol_instance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "protokol_instance_all" ON public.protokol_instance;
CREATE POLICY "protokol_instance_all" ON public.protokol_instance FOR ALL USING (true) WITH CHECK (true);

CREATE INDEX idx_pi_hayvan_durum ON public.protokol_instance(hayvan_id, durum);
CREATE INDEX idx_pi_tip_alttip   ON public.protokol_instance(tip, alttip);
CREATE INDEX idx_pi_kaynak_ref   ON public.protokol_instance(kaynak_ref);

-- 2. gorev_log FK kolonu ekle
ALTER TABLE public.gorev_log
  ADD COLUMN IF NOT EXISTS protokol_instance_id uuid
  REFERENCES public.protokol_instance(id) ON DELETE SET NULL;

CREATE INDEX idx_gorev_protokol ON public.gorev_log(protokol_instance_id)
  WHERE protokol_instance_id IS NOT NULL;

NOTIFY pgrst, 'reload schema';

COMMIT;
