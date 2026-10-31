-- Migration: Hayvan Takip şeması — hayvan_takip tablosu, gorev_log.ref_takip_id, v_gorev_log_sync
-- Tarih: 2026-10-31. Kaynak: spec §4.1, §4.2; domain-rules §14, §20.
-- BEGIN/COMMIT yok: runbook ve test sarmalayıcısı dışarıdan sarar. Prod apply sahip kapısındadır.
-- Yazma yalnız RPC ile (sonraki migration'lar); authenticated bu tabloda yalnız SELECT alır.
--
-- ROLLBACK (tek işlemde, bu sırayla; önce bu seriye bağlı RPC ve tetikleyici migration'ları geri alınır):
--   1. Görünüm ACL'ini kaydet: SELECT relacl FROM pg_class WHERE oid = 'public.v_gorev_log_sync'::regclass;
--      Prod ve demo ACL'i farklıdır, DROP VIEW bu yetkileri siler.
--   2. DROP VIEW public.v_gorev_log_sync;  -- kolon görünüme bağlı, CREATE OR REPLACE kolon düşüremez
--   3. ALTER TABLE public.gorev_log DROP COLUMN ref_takip_id;  -- FK ve kısmi indeks kolonla düşer
--   4. Görünümü aşağıdaki gövdeyle CREATE VIEW ile yeniden kur, 1. adımdaki ACL'i GRANT ile geri ver.
--   5. DROP TABLE public.hayvan_takip;  -- tetikleyici, policy, indeks ve yayın üyeliği tabloyla düşer
--   Not: Kurulan görünüm bu migration öncesindeki 22 kolona ek takip_kapanis_nedeni taşır (SELECT *);
--   client SELECT * okuduğundan zararsızdır. degisim_log'daki hayvan_takip satırları kalır.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

-- Sebep listesi js/config.js'te durur; DB sınırlamaz (spec §4.1), yalnız boş sebebi reddeder.
CREATE TABLE public.hayvan_takip (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id uuid NOT NULL DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e',
  hayvan_id text NOT NULL REFERENCES public.hayvanlar (id),
  sebep_kodu text NOT NULL,
  aciklama text,
  acilis_tarihi timestamptz NOT NULL DEFAULT now(),
  acan text,
  kapanis_tarihi timestamptz,
  kapatan text,
  kapanis_nedeni text,
  kapanis_notu text,
  kapatan_vaka_id uuid,  -- FK yok: case_geri_al silmesini bloklardı; aynı hayvanı RPC doğrular
  CONSTRAINT hayvan_takip_kapanis_cift_ck
    CHECK ((kapanis_tarihi IS NULL) = (kapanis_nedeni IS NULL)),
  CONSTRAINT hayvan_takip_kapanis_nedeni_ck
    CHECK (kapanis_nedeni IN ('ELLE', 'MUAYENE', 'VAKA', 'CIKIS')),
  CONSTRAINT hayvan_takip_sebep_bos_ck
    CHECK (btrim(sebep_kodu) <> ''),
  CONSTRAINT hayvan_takip_diger_aciklama_ck
    CHECK (sebep_kodu <> 'DIGER' OR btrim(COALESCE(aciklama, '')) <> ''),
  CONSTRAINT hayvan_takip_vaka_ref_ck
    CHECK (kapanis_nedeni IS DISTINCT FROM 'VAKA' OR kapatan_vaka_id IS NOT NULL)
);

CREATE UNIQUE INDEX hayvan_takip_acik_sebep_uq
  ON public.hayvan_takip (hayvan_id, sebep_kodu)
  WHERE kapanis_tarihi IS NULL AND sebep_kodu <> 'DIGER';

CREATE INDEX hayvan_takip_farm_hayvan_idx
  ON public.hayvan_takip (farm_id, hayvan_id);

ALTER TABLE public.hayvan_takip ENABLE ROW LEVEL SECURITY;

CREATE POLICY hayvan_takip_select ON public.hayvan_takip
  FOR SELECT TO authenticated USING (true);

-- Supabase default privilege'i authenticated'a yazma verir; REVOKE bu yüzden onu da kapsar.
REVOKE ALL ON public.hayvan_takip FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.hayvan_takip TO authenticated;
GRANT ALL ON public.hayvan_takip TO service_role;

CREATE TRIGGER trg_degisim_log
  AFTER INSERT OR UPDATE OR DELETE ON public.hayvan_takip
  FOR EACH ROW EXECUTE FUNCTION public._degisim_log_yaz('id');

-- Yayın yoksa (yerel ortam) atlar; varsa ve üye değilse ekler.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_publication WHERE pubname = 'supabase_realtime')
    AND NOT EXISTS (
      SELECT 1 FROM pg_catalog.pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'hayvan_takip'
    ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.hayvan_takip;
  END IF;
END;
$$;

ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS ref_takip_id uuid;

ALTER TABLE public.gorev_log
  ADD CONSTRAINT gorev_log_ref_takip_fk
  FOREIGN KEY (ref_takip_id) REFERENCES public.hayvan_takip (id) NOT VALID;
ALTER TABLE public.gorev_log VALIDATE CONSTRAINT gorev_log_ref_takip_fk;

-- tamamlandi ve iptal nullable: NOT x, NULL satırı indeksten kaçırırdı (IS NOT TRUE bilerek).
CREATE UNIQUE INDEX gorev_log_ref_takip_acik_uq
  ON public.gorev_log (ref_takip_id)
  WHERE ref_takip_id IS NOT NULL AND tamamlandi IS NOT TRUE AND iptal IS NOT TRUE;

-- Gövde 20260626000010 ile aynı. DROP yok: ACL prod ve demo'da farklı, DROP kaybettirir.
-- SELECT * yeni kolonları sona ekler: takip_kapanis_nedeni, ref_takip_id.
CREATE OR REPLACE VIEW public.v_gorev_log_sync AS
  SELECT * FROM public.gorev_log WHERE NOT tamamlandi AND NOT iptal
  UNION ALL
  SELECT * FROM (
    SELECT * FROM public.gorev_log
    WHERE (tamamlandi OR iptal)
    ORDER BY created_at DESC NULLS LAST
    LIMIT 300
  ) kapali;
