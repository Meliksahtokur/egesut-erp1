-- ═══════════════════════════════════════════════════════
-- GROUND TRUTH MIGRATION — REFERANS, CALISTIRMAYIN
-- Tarih: 2026-05-13
-- Tum migration'larin birlestirilmis hali, sifirdan kurulum icin referans.
-- ═══════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.hayvanlar (
  id text PRIMARY KEY,
  kupe_no text,
  devlet_kupe text,
  irk text,
  cinsiyet text,
  dogum_tarihi date,
  dogum_kg numeric,
  canli_agirlik numeric,
  boy numeric,
  renk text,
  ayirici_ozellik text,
  anne_id text,
  baba_bilgi text,
  grup text,
  padok text,
  durum text DEFAULT 'Aktif',
  etiketler text[] DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_hayvanlar_etiketler
  ON public.hayvanlar USING GIN(etiketler);

CREATE TABLE IF NOT EXISTS public.stok (
  id text PRIMARY KEY,
  urun_adi text NOT NULL,
  kategori text,
  birim text,
  baslangic_miktar numeric DEFAULT 0,
  esik numeric DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.stok_hareket (
  id text PRIMARY KEY,
  stok_id text,
  tur text,
  miktar numeric,
  notlar text,
  iptal boolean DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.gorev_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hayvan_id text,
  gorev_tipi text,
  aciklama text,
  hedef_tarih date,
  tamamlandi boolean DEFAULT false,
  tamamlanma_tarihi timestamptz,
  parent_id text,
  stok_id text,
  miktar numeric,
  hekim_id text,
  kaynak text,
  padok_hedef text,
  iptal boolean DEFAULT false,
  etken_kod text,
  kapatan_ref text
);

-- uygulama_log: Case-free hızlı ilaç/vitamin uygulama kaydı (Task 6)
CREATE TABLE IF NOT EXISTS public.uygulama_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hayvan_id text NOT NULL REFERENCES public.hayvanlar(id),
  stok_id text REFERENCES public.stok(id),
  etken_kod text,
  doz numeric NOT NULL,
  birim text NOT NULL,
  rota text NOT NULL CHECK (rota IN ('IM','IV','SC','PO','Topikal','Intrauterin')),
  tarih date NOT NULL DEFAULT CURRENT_DATE,
  notlar text NOT NULL,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_uygulama_log_hayvan ON public.uygulama_log(hayvan_id);
CREATE INDEX IF NOT EXISTS idx_uygulama_log_tarih ON public.uygulama_log(tarih);
ALTER TABLE public.uygulama_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY anon_all_uygulama_log ON public.uygulama_log FOR ALL USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.uygulama_log TO anon, authenticated;

-- protokol_dismiss: Kullanıcı tarafından geçersiz kılınan protokol uyarıları (Task 10)
CREATE TABLE IF NOT EXISTS public.protokol_dismiss (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hayvan_id text NOT NULL REFERENCES public.hayvanlar(id),
  etken_kod text NOT NULL,
  protokol text NOT NULL,
  tarih timestamptz DEFAULT now(),
  neden text,
  UNIQUE(hayvan_id, etken_kod, protokol)
);
ALTER TABLE public.protokol_dismiss ENABLE ROW LEVEL SECURITY;
CREATE POLICY anon_all_protokol_dismiss ON public.protokol_dismiss FOR ALL USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.protokol_dismiss TO anon, authenticated;

CREATE TABLE IF NOT EXISTS public.hastalik_log (
  id text PRIMARY KEY,
  hayvan_id text,
  tarih date,
  kategori text,
  tani text,
  siddet text,
  semptomlar text,
  hekim_id text,
  ilac_stok_id text,
  ilac_miktar numeric,
  durum text DEFAULT 'Aktif',
  kapanma_tarihi date
);

CREATE TABLE IF NOT EXISTS public.tohumlama (
  id text PRIMARY KEY,
  hayvan_id text,
  tarih date,
  sperma text,
  hekim_id text,
  sonuc text DEFAULT 'Bekliyor',
  deneme_no integer DEFAULT 1,
  vwp_override boolean DEFAULT false
);

ALTER TABLE public.tohumlama
  ADD COLUMN IF NOT EXISTS ek_uygulamalar jsonb DEFAULT '[]'::jsonb;

ALTER TABLE public.tohumlama
  ADD COLUMN IF NOT EXISTS case_id uuid REFERENCES public.cases(id) ON DELETE SET NULL;


-- ════════════════════════════════════════════════════════════════
-- GÖREV B FAZ 2 — ground_truth onarımı (2026-06-25)
-- Eski satır 132-224 (dogum gövdesiz + yutulmuş tablolar) silindi,
-- yerine canlı Management API'den yeniden üretildi.
-- Kapsam: EgeSüt kanonik (tools-bank 9 tablo HARİÇ, set_deneme_no atlandı).
-- ════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════
-- DOGUM (Faz 2 — canlı Management API)
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.dogum (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  anne_id text,
  tarih date,
  yavru_cins text,
  yavru_kupe text,
  yavru_irk text,
  dogum_tipi text DEFAULT 'Normal'::text,
  created_at timestamp with time zone DEFAULT now(),
  hekim_id text,
  dogum_kg numeric,
  baba_bilgi text,
  CONSTRAINT dogum_pkey PRIMARY KEY (id),
  CONSTRAINT dogum_fk_anne_id FOREIGN KEY (anne_id) REFERENCES hayvanlar(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS dogum_pkey ON public.dogum USING btree (id);
CREATE INDEX IF NOT EXISTS idx_dogum_anne_tarih ON public.dogum USING btree (anne_id, tarih);

ALTER TABLE public.dogum ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow all" ON public.dogum;
CREATE POLICY "allow all" ON public.dogum FOR ALL TO public USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS anon_all ON public.dogum;
CREATE POLICY anon_all ON public.dogum FOR ALL TO public USING (true) WITH CHECK (true);

GRANT SELECT ON public.dogum TO agent_readonly;
GRANT DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE ON public.dogum TO authenticated;
GRANT DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE ON public.dogum TO postgres;
GRANT DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE ON public.dogum TO service_role;

-- ════════════════════════════════════════════════════════════════
-- TEDAVI (Faz 2 — canlı Management API)
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.tedavi (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  hayvan_id text,
  tarih date,
  tani text,
  ilac_stok_id text,
  miktar numeric,
  sut_yasagi_bitis date,
  aktif boolean DEFAULT true,
  vaka_id text,
  created_at timestamp with time zone DEFAULT now(),
  uygulama_yolu text,
  hekim_id text,
  bekleme_suresi_gun integer,
  notlar text,
  CONSTRAINT tedavi_pkey PRIMARY KEY (id),
  CONSTRAINT tedavi_fk_hayvan_id FOREIGN KEY (hayvan_id) REFERENCES hayvanlar(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS tedavi_pkey ON public.tedavi USING btree (id);

ALTER TABLE public.tedavi ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "allow all" ON public.tedavi;
CREATE POLICY "allow all" ON public.tedavi FOR ALL TO public USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS tedavi_delete ON public.tedavi;
CREATE POLICY tedavi_delete ON public.tedavi FOR DELETE TO public USING (true);
DROP POLICY IF EXISTS tedavi_insert ON public.tedavi;
CREATE POLICY tedavi_insert ON public.tedavi FOR INSERT TO public WITH CHECK (true);
DROP POLICY IF EXISTS tedavi_select ON public.tedavi;
CREATE POLICY tedavi_select ON public.tedavi FOR SELECT TO public USING (true);
DROP POLICY IF EXISTS tedavi_update ON public.tedavi;
CREATE POLICY tedavi_update ON public.tedavi FOR UPDATE TO public USING (true) WITH CHECK (true);

GRANT SELECT ON public.tedavi TO agent_readonly;
GRANT DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE ON public.tedavi TO authenticated;
GRANT DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE ON public.tedavi TO postgres;
GRANT DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE ON public.tedavi TO service_role;

-- ════════════════════════════════════════════════════════════════
-- HAYVAN_OVERRIDE (Faz 2 — canlı Management API)
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.hayvan_override (
  kupe_no text NOT NULL,
  pasif_mi boolean DEFAULT false,
  notlar text,
  guncelleme_tarihi date DEFAULT CURRENT_DATE,
  CONSTRAINT hayvan_override_pkey PRIMARY KEY (kupe_no)
);

CREATE UNIQUE INDEX IF NOT EXISTS hayvan_override_pkey ON public.hayvan_override USING btree (kupe_no);

ALTER TABLE public.hayvan_override ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.hayvan_override TO agent_readonly;
GRANT DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE ON public.hayvan_override TO authenticated;
GRANT DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE ON public.hayvan_override TO postgres;
GRANT DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE ON public.hayvan_override TO service_role;

-- ════════════════════════════════════════════════════════════════
-- VETHEK_TOHUMLAMALAR (Faz 2 — canlı Management API)
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.vethek_tohumlamalar (
  id bigint DEFAULT nextval('vethek_tohumlamalar_id_seq'::regclass) NOT NULL,
  hayvan_id integer NOT NULL,
  sperma text,
  belge_no text,
  kupe_no text,
  irk text,
  not_ text,
  tohumlama_tar date,
  gebe boolean,
  scrape_tarihi date NOT NULL,
  kaynak_url text,
  olusturulma_zamani timestamp with time zone DEFAULT now(),
  CONSTRAINT vethek_tohumlamalar_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX IF NOT EXISTS vethek_tohumlamalar_pkey ON public.vethek_tohumlamalar USING btree (id);
CREATE INDEX IF NOT EXISTS idx_vethek_kupe ON public.vethek_tohumlamalar USING btree (kupe_no);
CREATE INDEX IF NOT EXISTS idx_vethek_tarih ON public.vethek_tohumlamalar USING btree (tohumlama_tar);

ALTER TABLE public.vethek_tohumlamalar ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.vethek_tohumlamalar TO agent_readonly;
GRANT DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE ON public.vethek_tohumlamalar TO authenticated;
GRANT DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE ON public.vethek_tohumlamalar TO postgres;
GRANT DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE ON public.vethek_tohumlamalar TO service_role;

-- ════════════════════════════════════════════════════════════════
-- AGENT_PLANS (Faz 2 — canlı Management API)
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.agent_plans (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  thread_id uuid,
  kullanici_id uuid DEFAULT auth.uid() NOT NULL,
  durum text DEFAULT 'pending'::text NOT NULL,
  adimlar jsonb NOT NULL,
  onizleme jsonb,
  sonuc jsonb,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  applied_at timestamp with time zone,
  CONSTRAINT agent_plans_pkey PRIMARY KEY (id),
  CONSTRAINT agent_plans_fk_thread_id FOREIGN KEY (thread_id) REFERENCES agent_threads(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS agent_plans_pkey ON public.agent_plans USING btree (id);
CREATE INDEX IF NOT EXISTS idx_agent_plans_thread ON public.agent_plans USING btree (thread_id);
CREATE INDEX IF NOT EXISTS idx_agent_plans_durum ON public.agent_plans USING btree (kullanici_id, durum);

ALTER TABLE public.agent_plans ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS agent_plans_insert ON public.agent_plans;
CREATE POLICY agent_plans_insert ON public.agent_plans FOR INSERT TO public WITH CHECK ((kullanici_id = auth.uid()));
DROP POLICY IF EXISTS agent_plans_select ON public.agent_plans;
CREATE POLICY agent_plans_select ON public.agent_plans FOR SELECT TO public USING ((kullanici_id = auth.uid()));
DROP POLICY IF EXISTS agent_plans_update ON public.agent_plans;
CREATE POLICY agent_plans_update ON public.agent_plans FOR UPDATE TO public USING ((kullanici_id = auth.uid())) WITH CHECK (true);

GRANT SELECT ON public.agent_plans TO agent_readonly;
GRANT DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE ON public.agent_plans TO authenticated;
GRANT DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE ON public.agent_plans TO postgres;
GRANT DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE ON public.agent_plans TO service_role;

-- ════════════════════════════════════════════════════════════════
-- UI_LOGS (Faz 2 — canlı Management API)
-- ════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.ui_logs (
  id bigint DEFAULT nextval('ui_logs_id_seq'::regclass) NOT NULL,
  level text NOT NULL,
  message text NOT NULL,
  source text,
  payload jsonb,
  session_id text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT ui_logs_pkey PRIMARY KEY (id)
);

CREATE UNIQUE INDEX IF NOT EXISTS ui_logs_pkey ON public.ui_logs USING btree (id);
CREATE INDEX IF NOT EXISTS idx_ui_logs_session ON public.ui_logs USING btree (session_id, created_at DESC);

ALTER TABLE public.ui_logs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon insert" ON public.ui_logs;
CREATE POLICY "anon insert" ON public.ui_logs FOR INSERT TO public WITH CHECK (true);
DROP POLICY IF EXISTS "anon select" ON public.ui_logs;
CREATE POLICY "anon select" ON public.ui_logs FOR SELECT TO public USING (true);

GRANT SELECT ON public.ui_logs TO agent_readonly;
GRANT DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE ON public.ui_logs TO authenticated;
GRANT DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE ON public.ui_logs TO postgres;
GRANT DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE ON public.ui_logs TO service_role;

-- ════════════════════════════════════════════════════════════════
-- COZULMEMIS_KIZGINLIK_VIEW (Faz 2 — canlı Management API)
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW public.cozulmemis_kizginlik_view AS
SELECT DISTINCT ON (kl.hayvan_id) kl.id AS kizginlik_id,
    kl.hayvan_id,
    h.kupe_no,
    h.padok,
    h.grup,
    kl.tarih AS kizginlik_tarihi,
    kl.olusturma AS kizginlik_zamani,
    kl.belirti,
    (EXTRACT(epoch FROM (now() - kl.olusturma)) / (3600)::numeric) AS gecen_saat,
        CASE
            WHEN (kl.cozuldu = true) THEN 'cozuldu'::text
            WHEN (EXISTS ( SELECT 1
               FROM tohumlama t
              WHERE ((t.hayvan_id = kl.hayvan_id) AND (COALESCE(t.created_at, (t.tarih)::timestamp with time zone) >= kl.olusturma) AND (COALESCE(t.created_at, (t.tarih)::timestamp with time zone) < (kl.olusturma + '12:00:00'::interval))))) THEN 'cozuldu'::text
            WHEN ((EXTRACT(epoch FROM (now() - kl.olusturma)) / (3600)::numeric) > (24)::numeric) THEN 'bekleniyor'::text
            WHEN ((EXTRACT(epoch FROM (now() - kl.olusturma)) / (3600)::numeric) > (12)::numeric) THEN 'uyari'::text
            ELSE 'izleniyor'::text
        END AS durum
   FROM (kizginlik_log kl
     JOIN hayvanlar h ON (((h.id = kl.hayvan_id) AND (h.durum = 'Aktif'::text))))
  WHERE (kl.olusturma >= (now() - '3 days'::interval))
  ORDER BY kl.hayvan_id, kl.olusturma DESC;;

-- ════════════════════════════════════════════════════════════════
-- EKSİK EGESÜT FONKSİYONLAR (10 adet, Faz 2)
-- ════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public._asistan_ref_coz(p_param jsonb, p_ctx jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
DECLARE
  k text; v jsonb; m text[];
  v_out jsonb := p_param;
BEGIN
  FOR k, v IN SELECT * FROM jsonb_each(p_param) LOOP
    IF jsonb_typeof(v) = 'string' AND left(v #>> '{}', 1) = '$' THEN
      m := regexp_match(v #>> '{}', '^\$([0-9]+)\.(.+)$');
      IF m IS NOT NULL THEN
        v_out := jsonb_set(v_out, ARRAY[k],
          COALESCE(p_ctx -> m[1] -> m[2], 'null'::jsonb));
      END IF;
    END IF;
  END LOOP;
  RETURN v_out;
END;
$function$
;
CREATE OR REPLACE FUNCTION public._asistan_step_calistir(p_tip text, p_param jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
  g text; r jsonb; v_rt text; v_rid text;
BEGIN
  CASE p_tip
  WHEN 'gorev_kapat' THEN
    FOR g IN SELECT jsonb_array_elements_text(p_param->'gorev_idler') LOOP
      r := public.gorev_tamamla(g, NULL);
      IF (r->>'ok') = 'false' THEN
        RAISE EXCEPTION 'gorev_tamamla(%) başarısız: %', g, r->>'mesaj';
      END IF;
    END LOOP;
    RETURN jsonb_build_object('kapatilan', jsonb_array_length(p_param->'gorev_idler'));
  WHEN 'hizli_uygulama' THEN
    r := public.hizli_uygulama(
      p_param->>'hayvan_id', p_param->>'stok_id',
      (p_param->>'doz')::numeric, COALESCE(p_param->>'birim','ml'),
      COALESCE(p_param->>'rota','IM'), COALESCE(p_param->>'notlar','AI Asistan'));
    IF (r->>'ok')='false' THEN RAISE EXCEPTION 'hizli_uygulama: %', r->>'mesaj'; END IF;
    RETURN r;
  WHEN 'vaka_ac' THEN
    r := public.create_case(p_param->>'hayvan_id', (p_param->>'disease_id')::uuid, p_param->>'not');
    IF (r->>'ok')='false' THEN RAISE EXCEPTION 'create_case: %', r->>'mesaj'; END IF;
    RETURN r;
  WHEN 'tedavi_gun_ekle' THEN
    r := public.add_treatment_day_with_sessions(
      (p_param->>'case_id')::uuid, (p_param->>'tarih')::date, p_param->'sessions', NULL);
    IF (r->>'ok')='false' THEN RAISE EXCEPTION 'add_treatment_day: %', r->>'mesaj'; END IF;
    RETURN r;
  WHEN 'tohumlama_kaydet' THEN
    r := public.tohumlama_kaydet(
      p_hayvan_id   := p_param->>'hayvan_id',
      p_tarih       := (p_param->>'tarih')::date,
      p_sperma      := p_param->>'sperma',
      p_hekim_id    := NULLIF(p_param->>'hekim_id',''),
      p_irk_bilgisi := NULLIF(p_param->>'irk_bilgisi',''),
      p_vwp_override := false);
    IF (r->>'ok')='false' THEN RAISE EXCEPTION 'tohumlama_kaydet: %', r->>'mesaj'; END IF;
    RETURN r;
  WHEN 'padok_toplu' THEN
    r := public.padok_degistir_toplu(
      ARRAY(SELECT jsonb_array_elements_text(p_param->'hayvan_idler')),
      (p_param->>'yeni_padok_id')::uuid, NULL, NULLIF(p_param->>'yeni_grup',''));
    IF (r->>'success')='false' THEN RAISE EXCEPTION 'padok_degistir_toplu: %', r->>'error'; END IF;
    RETURN r;
  WHEN 'dogum_kaydet' THEN
    r := public.dogum_kaydet(p_param->>'anne_id', (p_param->>'tarih')::date, p_param->>'buzagi_kupe',
      COALESCE(p_param->>'cins','Dişi'), COALESCE(p_param->>'tip','Normal'),
      NULLIF(p_param->>'kg','')::numeric, NULLIF(p_param->>'baba',''), NULLIF(p_param->>'hekim_id',''));
    IF (r->>'ok')='false' THEN RAISE EXCEPTION 'dogum_kaydet: %', r->>'mesaj'; END IF;
    RETURN r;
  WHEN 'islem_geri_al' THEN
    SELECT ref_tablo, ref_id INTO v_rt, v_rid FROM public.islem_log WHERE id = p_param->>'islem_id';
    IF v_rt IS NULL THEN RAISE EXCEPTION 'İşlem bulunamadı: %', p_param->>'islem_id'; END IF;
    IF    v_rt='uygulama_log' THEN r := public.hizli_uygulama_geri_al(v_rid::uuid);
    ELSIF v_rt='cases'        THEN r := public.case_geri_al(v_rid::uuid);
    ELSIF v_rt='tohumlama'    THEN r := public.tohumlama_geri_al(v_rid);
    ELSIF v_rt='gorev_log'    THEN r := public.gorev_geri_al(v_rid);
    ELSE  RAISE EXCEPTION 'Geri alınamaz işlem tipi: %', v_rt; END IF;
    IF (r->>'ok')='false' THEN RAISE EXCEPTION 'geri alma başarısız: %', COALESCE(r->>'mesaj',r->>'hata'); END IF;
    RETURN jsonb_build_object('geri_alindi', v_rt, 'ref_id', v_rid);
  ELSE
    RAISE EXCEPTION 'Bilinmeyen adım tipi: %', p_tip;
  END CASE;
END;
$function$
;
CREATE OR REPLACE FUNCTION public._asistan_step_dogrula(p_tip text, p_param jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_n int; v_seans text; v_vaka text;
  v_rt text; v_rtip text; v_rdurum text;
BEGIN
  CASE p_tip
  WHEN 'gorev_kapat' THEN
    v_n := jsonb_array_length(COALESCE(p_param->'gorev_idler','[]'::jsonb));
    IF v_n = 0 THEN RETURN jsonb_build_object('ok',false,'hata','gorev_idler boş'); END IF;
    IF EXISTS (
      SELECT 1 FROM jsonb_array_elements_text(p_param->'gorev_idler') g(id)
      LEFT JOIN public.gorev_log gl ON gl.id::text = g.id
      WHERE gl.id IS NULL OR gl.tamamlandi = true OR gl.iptal = true
    ) THEN
      RETURN jsonb_build_object('ok',false,'hata','Bazı görevler bulunamadı veya zaten kapalı');
    END IF;
    RETURN jsonb_build_object('ok',true,'onizleme', v_n || ' görev kapatılacak');
  WHEN 'hizli_uygulama' THEN
    IF NOT (p_param ? 'hayvan_id' AND p_param ? 'stok_id' AND p_param ? 'doz') THEN
      RETURN jsonb_build_object('ok',false,'hata','hizli_uygulama: hayvan_id/stok_id/doz gerekli');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.hayvanlar WHERE id = p_param->>'hayvan_id' AND durum='Aktif') THEN
      RETURN jsonb_build_object('ok',false,'hata','Hayvan aktif değil: '||(p_param->>'hayvan_id'));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.stok WHERE id = p_param->>'stok_id') THEN
      RETURN jsonb_build_object('ok',false,'hata','Stok yok: '||(p_param->>'stok_id'));
    END IF;
    RETURN jsonb_build_object('ok',true,'onizleme',
      (SELECT kupe_no || COALESCE(' ('||grup||')','') FROM public.hayvanlar WHERE id=p_param->>'hayvan_id')||
      ' → bağımsız uygulama: '||
      (SELECT urun_adi FROM public.stok WHERE id=p_param->>'stok_id')||' '||
      (p_param->>'doz')||COALESCE(p_param->>'birim','')||' '||COALESCE(p_param->>'rota',''));
  WHEN 'vaka_ac' THEN
    IF NOT (p_param ? 'hayvan_id' AND p_param ? 'disease_id') THEN
      RETURN jsonb_build_object('ok',false,'hata','vaka_ac: hayvan_id/disease_id gerekli'); END IF;
    IF NOT EXISTS (SELECT 1 FROM public.diseases WHERE id=(p_param->>'disease_id')::uuid) THEN
      RETURN jsonb_build_object('ok',false,'hata','Hastalık bulunamadı'); END IF;
    RETURN jsonb_build_object('ok',true,'onizleme',
      (SELECT kupe_no || COALESCE(' ('||grup||')','') FROM public.hayvanlar WHERE id=p_param->>'hayvan_id')||
      ' → yeni vaka aç: '||
      (SELECT name FROM public.diseases WHERE id=(p_param->>'disease_id')::uuid));
  WHEN 'tedavi_gun_ekle' THEN
    IF NOT (p_param ? 'case_id' AND p_param ? 'tarih' AND p_param ? 'sessions') THEN
      RETURN jsonb_build_object('ok',false,'hata','tedavi_gun_ekle: case_id/tarih/sessions gerekli'); END IF;
    SELECT string_agg(
      COALESCE((SELECT urun_adi FROM public.stok WHERE id = s->>'stok_id'), s->>'stok_id')||' '||
      (s->>'dose')||COALESCE(s->>'unit','')||' '||COALESCE(s->>'route','')||
      COALESCE(' @'||(s->>'planned_time'),''), ', ')
    INTO v_seans FROM jsonb_array_elements(p_param->'sessions') s;
    v_vaka := CASE
      WHEN left(p_param->>'case_id',1) = '$' THEN 'yeni açılan vakaya'
      ELSE COALESCE((SELECT d.name FROM public.cases c JOIN public.diseases d ON d.id=c.disease_id
                     WHERE c.id=(p_param->>'case_id')::uuid),'vakaya')||' vakasına'
    END;
    RETURN jsonb_build_object('ok',true,'onizleme',
      v_vaka||' tedavi günü ('||(p_param->>'tarih')||'): '||COALESCE(v_seans,'seans yok'));
  WHEN 'tohumlama_kaydet' THEN
    IF NOT (p_param ? 'hayvan_id' AND p_param ? 'tarih' AND p_param ? 'sperma') THEN
      RETURN jsonb_build_object('ok',false,'hata','tohumlama_kaydet: hayvan_id/tarih/sperma gerekli'); END IF;
    IF EXISTS (SELECT 1 FROM public.hayvanlar WHERE id=p_param->>'hayvan_id'
               AND (tohumlama_durumu ILIKE 'gebe' OR grup ILIKE 'Sağmal (Kuru)')) THEN
      RETURN jsonb_build_object('ok',false,'hata','Hayvan gebe veya kuru — tohumlanamaz'); END IF;
    RETURN jsonb_build_object('ok',true,'onizleme',
      (SELECT kupe_no FROM public.hayvanlar WHERE id=p_param->>'hayvan_id')||' → tohumlama: '||
      (p_param->>'sperma')||' ('||(p_param->>'tarih')||')');
  WHEN 'padok_toplu' THEN
    IF NOT (p_param ? 'hayvan_idler' AND p_param ? 'yeni_padok_id') THEN
      RETURN jsonb_build_object('ok',false,'hata','padok_toplu: hayvan_idler/yeni_padok_id gerekli'); END IF;
    RETURN jsonb_build_object('ok',true,'onizleme',
      jsonb_array_length(p_param->'hayvan_idler')||' hayvan → '||
      (SELECT ad FROM public.padoklar WHERE id=(p_param->>'yeni_padok_id')::uuid)||' padok'||
      COALESCE(' / grup: '||(p_param->>'yeni_grup'),''));
  WHEN 'dogum_kaydet' THEN
    IF NOT (p_param ? 'anne_id' AND p_param ? 'tarih' AND p_param ? 'buzagi_kupe') THEN
      RETURN jsonb_build_object('ok',false,'hata','dogum_kaydet: anne_id/tarih/buzagi_kupe gerekli'); END IF;
    RETURN jsonb_build_object('ok',true,'onizleme',
      (SELECT kupe_no FROM public.hayvanlar WHERE id=p_param->>'anne_id')||' doğum → buzağı '||
      (p_param->>'buzagi_kupe')||COALESCE(' ('||(p_param->>'cins')||')','')||
      ' · anne otomatik Sağmal''a alınır + görevler açılır');
  WHEN 'islem_geri_al' THEN
    IF NOT (p_param ? 'islem_id') THEN
      RETURN jsonb_build_object('ok',false,'hata','islem_geri_al: islem_id gerekli (islem_log.id)'); END IF;
    SELECT ref_tablo, tip, durum INTO v_rt, v_rtip, v_rdurum
    FROM public.islem_log WHERE id = p_param->>'islem_id';
    IF v_rtip IS NULL THEN RETURN jsonb_build_object('ok',false,'hata','İşlem bulunamadı'); END IF;
    IF v_rdurum = 'geri_alindi' THEN RETURN jsonb_build_object('ok',false,'hata','Bu işlem zaten geri alınmış'); END IF;
    IF v_rt NOT IN ('uygulama_log','cases','tohumlama','gorev_log') THEN
      RETURN jsonb_build_object('ok',false,'hata','Bu işlem tipi geri alınamaz ('||COALESCE(v_rt,'?')||') — manuel düzeltme gerekir');
    END IF;
    RETURN jsonb_build_object('ok',true,'onizleme','GERİ AL: '||v_rtip||' ('||v_rt||') işlemi geri alınacak');
  ELSE
    RETURN jsonb_build_object('ok',false,'hata','Bilinmeyen adım tipi: '||p_tip);
  END CASE;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.asistan_hayvan_detay(p_kupe text DEFAULT NULL::text, p_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_h record;
  v_out jsonb;
BEGIN
  SELECT * INTO v_h FROM hayvanlar
   WHERE (p_id IS NOT NULL AND id = p_id)
      OR (p_kupe IS NOT NULL AND kupe_no = p_kupe)
   LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('bulundu', false);
  END IF;

  v_out := jsonb_build_object(
    'bulundu', true,
    'hayvan', to_jsonb(v_h),
    'tohumlama', (SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY t.tarih DESC), '[]'::jsonb)
                  FROM tohumlama t WHERE t.hayvan_id = v_h.id),
    'gorevler', (SELECT coalesce(jsonb_agg(to_jsonb(g) ORDER BY g.created_at DESC), '[]'::jsonb)
                 FROM gorev_log g WHERE g.hayvan_id = v_h.id),
    'uygulamalar', (SELECT coalesce(jsonb_agg(to_jsonb(u) ORDER BY u.created_at DESC), '[]'::jsonb)
                    FROM uygulama_log u WHERE u.hayvan_id = v_h.id),
    'islem_log', (SELECT coalesce(jsonb_agg(to_jsonb(i) ORDER BY i.tarih DESC), '[]'::jsonb)
                  FROM islem_log i WHERE i.ana_hayvan_id = v_h.id)
  );
  RETURN v_out;
END $function$
;
CREATE OR REPLACE FUNCTION public.asistan_plan_geri_al(p_plan_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_plan record; v_adim jsonb; v_step_out jsonb;
  v_tip text; v_i int; v_n int; v_geri int := 0;
  v_atlanan jsonb := '[]'::jsonb; g text;
BEGIN
  SELECT * INTO v_plan FROM public.agent_plans
  WHERE id = p_plan_id AND kullanici_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'mesaj','Plan bulunamadı'); END IF;
  IF v_plan.durum <> 'applied' THEN
    RETURN jsonb_build_object('ok',false,'mesaj','Sadece uygulanmış plan geri alınır (durum: '||v_plan.durum||')');
  END IF;

  v_n := jsonb_array_length(v_plan.adimlar);
  FOR v_i IN REVERSE v_n..1 LOOP
    v_adim     := v_plan.adimlar->(v_i-1);
    v_tip      := v_adim->>'tip';
    v_step_out := v_plan.sonuc->(v_i::text);
    BEGIN
      CASE v_tip
      WHEN 'gorev_kapat' THEN
        FOR g IN SELECT jsonb_array_elements_text(v_adim->'parametreler'->'gorev_idler') LOOP
          PERFORM public.gorev_geri_al(g);
        END LOOP;
        v_geri := v_geri + 1;
      WHEN 'hizli_uygulama' THEN
        PERFORM public.hizli_uygulama_geri_al((v_step_out->>'id')::uuid);
        v_geri := v_geri + 1;
      WHEN 'vaka_ac' THEN
        PERFORM public.case_geri_al((v_step_out->>'case_id')::uuid);
        v_geri := v_geri + 1;
      WHEN 'tohumlama_kaydet' THEN
        PERFORM public.tohumlama_geri_al(v_step_out->>'tohumlama_id');
        v_geri := v_geri + 1;
      ELSE
        v_atlanan := v_atlanan || jsonb_build_array(v_tip||' (geri alınamaz)');
      END CASE;
    EXCEPTION WHEN OTHERS THEN
      v_atlanan := v_atlanan || jsonb_build_array(v_tip||' (hata: '||SQLERRM||')');
    END;
  END LOOP;

  UPDATE public.agent_plans
  SET durum = CASE WHEN jsonb_array_length(v_atlanan)=0 THEN 'geri_alindi' ELSE 'kismen_geri_alindi' END,
      sonuc = COALESCE(sonuc,'{}'::jsonb) || jsonb_build_object('geri_al',
                jsonb_build_object('geri_alinan', v_geri, 'atlanan', v_atlanan))
  WHERE id = p_plan_id;

  RETURN jsonb_build_object('ok',true,'geri_alinan',v_geri,'atlanan',v_atlanan,
    'kismi', (jsonb_array_length(v_atlanan) > 0));
END;
$function$
;
CREATE OR REPLACE FUNCTION public.asistan_plan_olustur(p_thread_id uuid, p_adimlar jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_adim jsonb; v_d jsonb; v_satirlar jsonb := '[]'::jsonb;
  v_plan_id uuid; v_n int;
BEGIN
  v_n := jsonb_array_length(COALESCE(p_adimlar,'[]'::jsonb));
  IF v_n = 0 THEN RETURN jsonb_build_object('ok',false,'mesaj','Boş plan'); END IF;
  IF v_n > 50 THEN RETURN jsonb_build_object('ok',false,'mesaj','Plan çok büyük (max 50 adım)'); END IF;

  FOR v_adim IN SELECT jsonb_array_elements(p_adimlar) LOOP
    v_d := public._asistan_step_dogrula(v_adim->>'tip', COALESCE(v_adim->'parametreler','{}'::jsonb));
    IF (v_d->>'ok') = 'false' THEN
      RETURN jsonb_build_object('ok',false,'mesaj', v_d->>'hata');
    END IF;
    v_satirlar := v_satirlar || jsonb_build_array(v_d->>'onizleme');
  END LOOP;

  INSERT INTO public.agent_plans (thread_id, adimlar, onizleme, durum)
  VALUES (p_thread_id, p_adimlar, jsonb_build_object('satirlar', v_satirlar), 'pending')
  RETURNING id INTO v_plan_id;

  RETURN jsonb_build_object('ok',true,'plan_id',v_plan_id,'onizleme',v_satirlar);
END;
$function$
;
CREATE OR REPLACE FUNCTION public.asistan_plan_uygula(p_plan_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_plan record; v_adim jsonb; v_ctx jsonb := '{}'::jsonb;
  v_param jsonb; v_out jsonb; v_i int := 0;
BEGIN
  SELECT * INTO v_plan FROM public.agent_plans
  WHERE id = p_plan_id AND kullanici_id = auth.uid();
  IF NOT FOUND THEN RETURN jsonb_build_object('ok',false,'mesaj','Plan bulunamadı'); END IF;
  IF v_plan.durum <> 'pending' THEN
    RETURN jsonb_build_object('ok',false,'mesaj','Plan zaten '||v_plan.durum);
  END IF;

  BEGIN
    FOR v_adim IN SELECT jsonb_array_elements(v_plan.adimlar) LOOP
      v_i := v_i + 1;
      v_param := public._asistan_ref_coz(COALESCE(v_adim->'parametreler','{}'::jsonb), v_ctx);
      v_out := public._asistan_step_calistir(v_adim->>'tip', v_param);
      v_ctx := jsonb_set(v_ctx, ARRAY[v_i::text], COALESCE(v_out,'{}'::jsonb));
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    UPDATE public.agent_plans
    SET durum='failed', sonuc=jsonb_build_object('hata',SQLERRM,'adim',v_i)
    WHERE id = p_plan_id;
    RETURN jsonb_build_object('ok',false,'mesaj','Adım '||v_i||' başarısız: '||SQLERRM);
  END;

  UPDATE public.agent_plans
  SET durum='applied', applied_at=now(), sonuc=v_ctx
  WHERE id = p_plan_id;
  RETURN jsonb_build_object('ok',true,'plan_id',p_plan_id,'sonuc',v_ctx);
END;
$function$
;
CREATE OR REPLACE FUNCTION public.asistan_sql_calistir(p_sql text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_clean text := btrim(p_sql);
  v_low   text := lower(v_clean);
  v_result jsonb;
BEGIN
  IF v_low !~ '^(select|with)\s' THEN
    RAISE EXCEPTION 'Sadece SELECT sorgusu çalıştırılabilir';
  END IF;
  IF position(';' in btrim(v_clean, ';')) > 0 THEN
    RAISE EXCEPTION 'Çoklu statement yasak';
  END IF;
  IF v_low ~ '\m(insert|update|delete|drop|alter|create|truncate|grant|revoke|copy|call|do)\M' THEN
    RAISE EXCEPTION 'Yazma/DDL anahtar kelimesi yasak';
  END IF;

  SET LOCAL transaction_read_only = on;
  SET LOCAL statement_timeout = '5s';

  EXECUTE format(
    'SELECT coalesce(jsonb_agg(t), ''[]''::jsonb) FROM (SELECT * FROM (%s) sub LIMIT 500) t',
    rtrim(v_clean, ';')
  ) INTO v_result;

  RETURN v_result;
END $function$
;
CREATE OR REPLACE FUNCTION public.tohumlama_duplicate_bekliyor_temizle()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_iptal_t  integer := 0;
  v_hayvan   record;
  v_eski_id  uuid;
BEGIN
  -- Her hayvan için birden fazla Bekliyor olan grupları bul
  FOR v_hayvan IN
    SELECT hayvan_id, COUNT(*) as adet, array_agg(id ORDER BY tarih ASC, created_at ASC) as id_list
    FROM public.tohumlama
    WHERE sonuc = 'Bekliyor'
    GROUP BY hayvan_id
    HAVING COUNT(*) > 1
  LOOP
    -- En eski kaydı koru (ilk Bekliyor gerçekten muayene bekliyor olabilir)
    -- Diğerlerini Boş yap
    FOREACH v_eski_id IN ARRAY v_hayvan.id_list[2:]
    LOOP
      UPDATE public.tohumlama SET sonuc = 'Boş' WHERE id = v_eski_id;
      v_iptal_t := v_iptal_t + 1;

      -- islem_log audit
      INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
      VALUES (
        gen_random_uuid()::text,
        'TOHUMLAMA_DUPLICATE_TEMIZLE',
        v_hayvan.hayvan_id,
        v_eski_id::text,
        'tohumlama',
        jsonb_build_object(
          'sebep', 'Aynı hayvanda birden fazla Bekliyor — en eski korundu',
          'korunan_id', v_hayvan.id_list[1]::text,
          'iptal_edilen_id', v_eski_id::text,
          'hayvandaki_bekliyor_sayisi', v_hayvan.adet
        )
      );
    END LOOP;
  END LOOP;

  RETURN jsonb_build_object(
    'iptal_edilen_tohumlama', v_iptal_t,
    'etkilenen_hayvan_sayisi', (SELECT COUNT(*) FROM (SELECT hayvan_id FROM tohumlama WHERE sonuc = 'Bekliyor' GROUP BY hayvan_id HAVING COUNT(*) > 1) x),
    'zaman', now()
  );
END;
$function$
;
CREATE OR REPLACE FUNCTION public.tohumlama_orphan_gorev_temizle()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_iptal_gorev1 integer;
  v_iptal_gorev2 integer;
  v_iptal_gorev3 integer;
  v_iptal_gorev  integer;
  v_iptal_inst   integer;
BEGIN
  -- 1) ref_tohumlama_id ile bağlı (eski sistem)
  UPDATE public.gorev_log g
    SET iptal = true
    WHERE g.tamamlandi = false
      AND g.iptal = false
      AND g.gorev_tipi IN ('GEBELIK_KONTROL', 'VETERINER_KONTROL', 'KIZGINLIK_TAKIP')
      AND g.ref_tohumlama_id IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.tohumlama t
        WHERE t.id::text = g.ref_tohumlama_id
          AND t.sonuc IN ('Boş', 'Abort')
      );
  GET DIAGNOSTICS v_iptal_gorev1 = ROW_COUNT;

  -- 2) kaynak ile bağlı (yeni sistem)
  UPDATE public.gorev_log g
    SET iptal = true
    WHERE g.tamamlandi = false
      AND g.iptal = false
      AND g.kaynak LIKE 'TOH-%'
      AND EXISTS (
        SELECT 1 FROM public.tohumlama t
        WHERE 'TOH-' || t.id::text = g.kaynak
          AND t.sonuc IN ('Boş', 'Abort')
      );
  GET DIAGNOSTICS v_iptal_gorev2 = ROW_COUNT;

  -- 3) NULL kaynak + NULL ref — orphan, bağlı tohumlama Boş/Abort (yeni eklenen)
  UPDATE public.gorev_log g
    SET iptal = true
    WHERE g.tamamlandi = false
      AND g.iptal = false
      AND g.kaynak IS NULL
      AND g.ref_tohumlama_id IS NULL
      AND g.gorev_tipi IN ('GEBELIK_KONTROL', 'VETERINER_KONTROL', 'KIZGINLIK_TAKIP')
      AND EXISTS (
        SELECT 1 FROM public.tohumlama t
        WHERE t.hayvan_id = g.hayvan_id
          AND t.sonuc IN ('Boş', 'Abort')
          AND t.tarih < g.hedef_tarih  -- orphan görev önce gelmiş
      );
  GET DIAGNOSTICS v_iptal_gorev3 = ROW_COUNT;

  v_iptal_gorev := v_iptal_gorev1 + v_iptal_gorev2 + v_iptal_gorev3;

  -- 4) protokol_instance — kaynak_ref bazlı
  UPDATE public.protokol_instance pi
    SET durum = 'iptal'
    WHERE pi.durum = 'aktif'
      AND pi.kaynak_ref LIKE 'TOH-%'
      AND EXISTS (
        SELECT 1 FROM public.tohumlama t
        WHERE 'TOH-' || t.id::text = pi.kaynak_ref
          AND t.sonuc IN ('Boş', 'Abort')
      );
  GET DIAGNOSTICS v_iptal_inst = ROW_COUNT;

  RETURN jsonb_build_object(
    'iptal_gorev',  v_iptal_gorev,
    'iptal_gorev_ref_tohumlama', v_iptal_gorev1,
    'iptal_gorev_kaynak',        v_iptal_gorev2,
    'iptal_gorev_null_orphan',   v_iptal_gorev3,
    'iptal_inst',   v_iptal_inst,
    'zaman',        now()
  );
END;
$function$
;




-- ════════════════════════════════════════════════════════════════
-- 35 EKSİK FONKSİYON (canlı DB diff — REGEN 2026-06-13)
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION public.set_deneme_no()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  SELECT COALESCE(COUNT(*), 0) + 1 INTO NEW.deneme_no
  FROM public.tohumlama
  WHERE hayvan_id = NEW.hayvan_id
    AND tarih > COALESCE(
      (SELECT MAX(tarih) FROM public.tohumlama
       WHERE hayvan_id = NEW.hayvan_id AND sonuc IN ('Doğum Yaptı', 'Abort')),
      '1900-01-01'::date
    );
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.add_drug_administration(p_day_id uuid, p_drug_product_id uuid, p_stok_id text, p_dose numeric, p_unit text, p_route text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id uuid;
BEGIN
  INSERT INTO public.drug_administrations (treatment_day_id, drug_product_id, stok_id, dose, unit, route)
  VALUES (p_day_id, p_drug_product_id, p_stok_id, p_dose, p_unit, p_route)
  RETURNING id INTO v_id;

  IF p_stok_id IS NOT NULL AND p_dose > 0 THEN
    INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar)
    VALUES (p_stok_id, 'Tedavi', p_dose, 'drug_admin:' || v_id::text);
  END IF;

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.update_treatment_time(p_day_id uuid, p_treatment_time time without time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE public.treatment_days
  SET treatment_time = p_treatment_time
  WHERE id = p_day_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tedavi günü bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.drug_product_ekle(p_drug_class_id uuid, p_brand_name text, p_concentration numeric DEFAULT NULL::numeric, p_concentration_unit text DEFAULT NULL::text, p_default_route text DEFAULT 'IM'::text, p_default_unit text DEFAULT NULL::text, p_stok_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_id UUID;
BEGIN
  IF p_brand_name IS NULL OR trim(p_brand_name) = '' THEN
    RAISE EXCEPTION 'İlaç adı boş olamaz';
  END IF;

  BEGIN
    INSERT INTO drug_products (
      drug_class_id, brand_name, concentration,
      concentration_unit, default_route, default_unit
    ) VALUES (
      p_drug_class_id, p_brand_name, p_concentration,
      p_concentration_unit, p_default_route, p_default_unit
    )
    RETURNING id INTO v_id;
  EXCEPTION
    WHEN unique_violation THEN
      RAISE EXCEPTION 'Bu ilaç zaten kayıtlı: %', p_brand_name;
  END;

  IF p_stok_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM stok WHERE id = p_stok_id::text) THEN
      RAISE EXCEPTION 'Stok kaydı bulunamadı: %', p_stok_id;
    END IF;
    UPDATE stok SET drug_product_id = v_id WHERE id = p_stok_id::text;
  END IF;

  RETURN v_id;
END;
$function$;

-- Kanonik sütten kesme: tarihi yazar; BEFORE trigger grup/padok doldurur, AFTER trigger görev/instance kapatır.
DROP FUNCTION IF EXISTS public.buzagi_sutten_kesme_onayla(text);
CREATE OR REPLACE FUNCTION public.buzagi_sutten_kesme_onayla(
  p_hayvan_id text,
  p_tarih date DEFAULT CURRENT_DATE
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_hayvan record;
  v_wpadok record;
  v_snapshot jsonb;
  v_min numeric;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id; END IF;
  IF v_hayvan.durum IS DISTINCT FROM 'Aktif' THEN
    RAISE EXCEPTION 'Hayvan aktif değil (durum: %)', v_hayvan.durum; END IF;
  IF v_hayvan.suttten_kesme_tarihi IS NOT NULL THEN
    RETURN jsonb_build_object('ok', true, 'mesaj', 'zaten kesilmiş', 'hayvan_id', p_hayvan_id);
  END IF;
  IF v_hayvan.dogum_tarihi IS NULL THEN
    RAISE EXCEPTION 'Doğum tarihi yok: %', p_hayvan_id; END IF;
  IF p_tarih > CURRENT_DATE THEN RAISE EXCEPTION 'Gelecek tarihe kesim yapılamaz: %', p_tarih; END IF;
  IF p_tarih < v_hayvan.dogum_tarihi THEN RAISE EXCEPTION 'Kesim tarihi doğumdan önce olamaz'; END IF;
  v_min := public._ayar('sutten_kesme_erken_uyari', 40);
  IF (p_tarih - v_hayvan.dogum_tarihi) < v_min THEN
    RAISE EXCEPTION 'Çok erken sütten kesim: % gün (min %)', (p_tarih - v_hayvan.dogum_tarihi), v_min; END IF;

  SELECT * INTO v_wpadok FROM public.padoklar WHERE ad ILIKE '%Sütten Kesilmiş%' ORDER BY id LIMIT 1;
  v_snapshot := jsonb_build_object(
    'olusturulan','[]'::jsonb, 'silinen','[]'::jsonb,
    'guncellenen', jsonb_build_array(jsonb_build_object(
      'tablo','hayvanlar','id',p_hayvan_id,
      'onceki', jsonb_build_object('suttten_kesme_tarihi',v_hayvan.suttten_kesme_tarihi,
                                   'grup',v_hayvan.grup,'padok',v_hayvan.padok,'padok_id',v_hayvan.padok_id),
      'sonraki', jsonb_build_object('suttten_kesme_tarihi',p_tarih,
                                    'grup','Sütten Kesilmiş Buzağı','padok',v_wpadok.ad,'padok_id',v_wpadok.id))));

  UPDATE public.hayvanlar SET suttten_kesme_tarihi = p_tarih WHERE id = p_hayvan_id;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('SUTEN_KESME', p_hayvan_id, p_hayvan_id, 'hayvanlar', v_snapshot, 'Buzağı sütten kesildi');

  RETURN jsonb_build_object('ok', true, 'hayvan_id', p_hayvan_id, 'tarih', p_tarih);
END;
$function$;
GRANT EXECUTE ON FUNCTION public.buzagi_sutten_kesme_onayla(text, date) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.hayvan_tohumlanabilir_onayla(p_hayvan_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_hayvan record;
  v_snapshot jsonb;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id; END IF;
  IF v_hayvan.durum IS DISTINCT FROM 'Aktif' THEN
    RAISE EXCEPTION 'Hayvan aktif değil (durum: %)', v_hayvan.durum;
  END IF;
  IF v_hayvan.cinsiyet IS DISTINCT FROM 'Dişi' THEN
    RAISE EXCEPTION 'Sadece dişi hayvanlar tohumlanabilir';
  END IF;
  IF v_hayvan.kisir THEN
    RAISE EXCEPTION 'Kısır hayvan tohumlanamaz';
  END IF;
  IF v_hayvan.dogum_tarihi IS NOT NULL AND (CURRENT_DATE - v_hayvan.dogum_tarihi) < 365 THEN
    RAISE EXCEPTION 'Hayvan 12 aydan küçük — tohumlanabilir olarak işaretlenemez (yaş: % gün)',
      CURRENT_DATE - v_hayvan.dogum_tarihi;
  END IF;

  v_snapshot := jsonb_build_object(
    'olusturulan', '[]'::jsonb,
    'guncellenen', jsonb_build_array(jsonb_build_object(
      'tablo', 'hayvanlar', 'id', p_hayvan_id,
      'onceki', jsonb_build_object(
        'tohumlama_durumu', v_hayvan.tohumlama_durumu,
        'tohumlama_onay_tarihi', v_hayvan.tohumlama_onay_tarihi
      ),
      'sonraki', jsonb_build_object(
        'tohumlama_durumu', 'tohumlanabilir',
        'tohumlama_onay_tarihi', CURRENT_DATE
      )
    )),
    'silinen', '[]'::jsonb
  );

  UPDATE public.hayvanlar SET
    tohumlama_durumu = 'tohumlanabilir',
    tohumlama_onay_tarihi = CURRENT_DATE
  WHERE id = p_hayvan_id;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('TOHUMLAMA_DURUMU_ONAYLA', p_hayvan_id, p_hayvan_id, 'hayvanlar', v_snapshot, 'Tohumlanabilir olarak onaylandı');

  RETURN jsonb_build_object('ok', true, 'hayvan_id', p_hayvan_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.hayvan_tohumlama_ertele(p_hayvan_id text, p_ay integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_hayvan record;
  v_hedef_tarih date;
  v_snapshot jsonb;
BEGIN
  IF p_ay < 1 OR p_ay > 12 THEN
    RAISE EXCEPTION 'Erteleme süresi 1-12 ay arasında olmalıdır (% girildi)', p_ay;
  END IF;

  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id; END IF;
  IF v_hayvan.durum IS DISTINCT FROM 'Aktif' THEN
    RAISE EXCEPTION 'Hayvan aktif değil (durum: %)', v_hayvan.durum;
  END IF;

  v_hedef_tarih := (CURRENT_DATE + (p_ay || ' months')::interval)::date;

  v_snapshot := jsonb_build_object(
    'olusturulan', '[]'::jsonb,
    'guncellenen', jsonb_build_array(jsonb_build_object(
      'tablo', 'hayvanlar', 'id', p_hayvan_id,
      'onceki', jsonb_build_object(
        'tohumlama_durumu', v_hayvan.tohumlama_durumu,
        'tohumlama_onay_tarihi', v_hayvan.tohumlama_onay_tarihi
      ),
      'sonraki', jsonb_build_object(
        'tohumlama_durumu', 'ertelendi',
        'tohumlama_onay_tarihi', v_hedef_tarih
      )
    )),
    'silinen', '[]'::jsonb
  );

  UPDATE public.hayvanlar SET
    tohumlama_durumu = 'ertelendi',
    tohumlama_onay_tarihi = v_hedef_tarih
  WHERE id = p_hayvan_id;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('TOHUMLAMA_ERTELE', p_hayvan_id, p_hayvan_id, 'hayvanlar', v_snapshot,
    format('Tohumlama %s ay ertelendi (hedef: %s)', p_ay, v_hedef_tarih));

  RETURN jsonb_build_object('ok', true, 'hedef_tarih', v_hedef_tarih);
END;
$function$;

CREATE OR REPLACE FUNCTION public.stok_hareket_ekle(p_stok_id text, p_tur text, p_miktar numeric, p_notlar text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id uuid;
BEGIN
  v_id := gen_random_uuid();

  INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
  VALUES (v_id, p_stok_id, p_tur, p_miktar, COALESCE(p_notlar, ''), false);

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('STOK_HAREKET', p_stok_id, 'stok', jsonb_build_object(
    'olusturulan', jsonb_build_array(jsonb_build_object(
      'tablo', 'stok_hareket', 'id', v_id,
      'veri', jsonb_build_object('stok_id', p_stok_id, 'tur', p_tur, 'miktar', p_miktar, 'notlar', p_notlar, 'iptal', false)
    )),
    'guncellenen', '[]'::jsonb,
    'silinen', '[]'::jsonb
  ), 'Stok hareketi: ' || COALESCE(p_notlar, p_tur));

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.stok_ekleme(p_stok_id text, p_miktar numeric, p_notlar text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_stok record;
  v_hareket_id uuid;
BEGIN
  IF p_miktar <= 0 THEN
    RAISE EXCEPTION 'Miktar pozitif olmalıdır (%)', p_miktar;
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = p_stok_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Stok kaydı bulunamadı: %', p_stok_id;
  END IF;

  v_hareket_id := gen_random_uuid();

  INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
  VALUES (v_hareket_id, p_stok_id, 'Ekleme', -p_miktar,
    COALESCE(p_notlar, 'Manuel ekleme'), false);

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('STOK_EKLEME', p_stok_id, 'stok', jsonb_build_object(
    'olusturulan', jsonb_build_array(jsonb_build_object(
      'tablo', 'stok_hareket', 'id', v_hareket_id,
      'veri', jsonb_build_object('stok_id', p_stok_id, 'tur', 'Ekleme', 'miktar', -p_miktar, 'notlar', p_notlar)
    )),
    'guncellenen', '[]'::jsonb,
    'silinen', '[]'::jsonb
  ), 'Stok ekleme: +' || p_miktar || ' (' || COALESCE(p_notlar, 'manuel') || ')');

  RETURN jsonb_build_object('ok', true, 'stok_id', p_stok_id, 'eklenen', p_miktar);
END;
$function$;

CREATE OR REPLACE FUNCTION public.gebelik_kaydet_manual(p_hayvan_id text, p_tarih date, p_sperma text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_hayvan record;
  v_tohumlama_id text;
  v_snapshot jsonb;
  v_deneme integer;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id; END IF;
  IF v_hayvan.durum IS DISTINCT FROM 'Aktif' THEN
    RAISE EXCEPTION 'Hayvan aktif değil (durum: %)', v_hayvan.durum;
  END IF;
  IF v_hayvan.cinsiyet IS DISTINCT FROM 'Dişi' THEN
    RAISE EXCEPTION 'Sadece dişi hayvanlara gebelik kaydedilebilir';
  END IF;
  IF p_tarih > (NOW() AT TIME ZONE 'Europe/Istanbul')::date THEN
    RAISE EXCEPTION 'İleri tarih girilemez: %', p_tarih;
  END IF;
  IF EXISTS (SELECT 1 FROM public.tohumlama WHERE hayvan_id = p_hayvan_id AND sonuc = 'Gebe') THEN
    RAISE EXCEPTION 'Hayvanın aktif gebeliği bulunuyor';
  END IF;

  v_tohumlama_id := gen_random_uuid()::text;

  SELECT COALESCE(MAX(deneme_no), 0) + 1 INTO v_deneme
  FROM public.tohumlama WHERE hayvan_id = p_hayvan_id;

  INSERT INTO public.tohumlama (id, hayvan_id, tarih, sperma, sonuc, deneme_no)
  VALUES (v_tohumlama_id, p_hayvan_id, p_tarih, p_sperma, 'Gebe', v_deneme);

  v_snapshot := jsonb_build_object(
    'olusturulan', jsonb_build_array(jsonb_build_object(
      'tablo', 'tohumlama', 'id', v_tohumlama_id,
      'veri', jsonb_build_object(
        'hayvan_id', p_hayvan_id, 'tarih', p_tarih,
        'sperma', p_sperma, 'sonuc', 'Gebe', 'deneme_no', v_deneme
      )
    )),
    'guncellenen', '[]'::jsonb,
    'silinen', '[]'::jsonb
  );

  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('GEBELIK_MANUEL', p_hayvan_id, p_hayvan_id, 'hayvanlar', v_snapshot,
    format('Manuel gebelik kaydı (tarih: %s, sperma: %s)', p_tarih, COALESCE(p_sperma, '-')));

  RETURN jsonb_build_object('ok', true, 'tohumlama_id', v_tohumlama_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.stok_arsivle(p_stok_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_stok record;
BEGIN
  SELECT * INTO v_stok FROM public.stok WHERE id = p_stok_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Stok bulunamadı: %', p_stok_id; END IF;

  UPDATE public.stok SET kategori = 'Arşiv' WHERE id = p_stok_id;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('STOK_ARSIVLE', p_stok_id, 'stok', jsonb_build_object(
    'olusturulan', '[]'::jsonb,
    'guncellenen', jsonb_build_array(jsonb_build_object(
      'tablo', 'stok', 'id', p_stok_id,
      'onceki', jsonb_build_object('kategori', v_stok.kategori),
      'sonraki', jsonb_build_object('kategori', 'Arşiv')
    )),
    'silinen', '[]'::jsonb
  ), 'Stok arşivlendi: ' || v_stok.urun_adi);

  RETURN jsonb_build_object('ok', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.vaccine_rapel_guncelle(p_vaccine_id uuid, p_repeat_days integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_vac record;
BEGIN
  IF p_repeat_days IS NOT NULL AND p_repeat_days <= 0 THEN RAISE EXCEPTION 'Rapel süresi pozitif olmalıdır'; END IF;
  SELECT * INTO v_vac FROM public.vaccines WHERE id = p_vaccine_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Aşı bulunamadı'; END IF;

  UPDATE public.vaccines SET repeat_interval_days = p_repeat_days WHERE id = p_vaccine_id;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('VACCINE_RAPEL', p_vaccine_id::text, 'vaccines', jsonb_build_object(
    'olusturulan', '[]'::jsonb,
    'guncellenen', jsonb_build_array(jsonb_build_object(
      'tablo', 'vaccines', 'id', p_vaccine_id,
      'onceki', jsonb_build_object('repeat_interval_days', v_vac.repeat_interval_days),
      'sonraki', jsonb_build_object('repeat_interval_days', p_repeat_days)
    )),
    'silinen', '[]'::jsonb
  ), 'Aşı rapel süresi güncellendi: ' || COALESCE(v_vac.name, v_vac.id::text));

  RETURN jsonb_build_object('ok', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.padok_sil(p_padok_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_padok record;
BEGIN
  SELECT * INTO v_padok FROM public.padoklar WHERE id = p_padok_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Padok bulunamadı'; END IF;

  IF EXISTS (SELECT 1 FROM public.hayvanlar WHERE padok_id = p_padok_id AND durum = 'Aktif') THEN
    RAISE EXCEPTION 'Padokta aktif hayvan var, silinemez';
  END IF;

  DELETE FROM public.grup_padok_eslem WHERE padok_id = p_padok_id;
  DELETE FROM public.padoklar WHERE id = p_padok_id;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('PADOK_SIL', p_padok_id::text, 'padoklar', jsonb_build_object(
    'olusturulan', '[]'::jsonb,
    'guncellenen', '[]'::jsonb,
    'silinen', jsonb_build_array(jsonb_build_object(
      'tablo', 'padoklar', 'id', p_padok_id,
      'veri', row_to_json(v_padok)::jsonb
    ))
  ), 'Padok silindi: ' || v_padok.ad);

  RETURN jsonb_build_object('ok', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.grup_padok_eslem_toggle(p_grup_adi text, p_padok_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF EXISTS (SELECT 1 FROM public.grup_padok_eslem WHERE grup = p_grup_adi AND padok_id = p_padok_id) THEN
    DELETE FROM public.grup_padok_eslem WHERE grup = p_grup_adi AND padok_id = p_padok_id;
    RETURN jsonb_build_object('ok', true, 'durum', 'silindi');
  ELSE
    INSERT INTO public.grup_padok_eslem (grup, padok_id)
    VALUES (p_grup_adi, p_padok_id);
    RETURN jsonb_build_object('ok', true, 'durum', 'eklendi');
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.hekim_ekle(p_ad text, p_telefon text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_id text;
BEGIN
  IF NULLIF(p_ad, '') IS NULL THEN RAISE EXCEPTION 'Hekim adı zorunlu'; END IF;
  v_id := 'H' || extract(epoch from now())::bigint::text;

  INSERT INTO public.hekimler (id, ad, telefon, aktif)
  VALUES (v_id, p_ad, p_telefon, true);

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('HEKIM_EKLE', v_id, 'hekimler', jsonb_build_object(
    'olusturulan', jsonb_build_array(jsonb_build_object(
      'tablo', 'hekimler', 'id', v_id,
      'veri', jsonb_build_object('ad', p_ad, 'telefon', p_telefon)
    )),
    'guncellenen', '[]'::jsonb,
    'silinen', '[]'::jsonb
  ), 'Yeni hekim: ' || p_ad);

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.hekim_guncelle(p_hekim_id text, p_ad text DEFAULT NULL::text, p_telefon text DEFAULT NULL::text, p_aktif boolean DEFAULT NULL::boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_hekim record;
BEGIN
  SELECT * INTO v_hekim FROM public.hekimler WHERE id = p_hekim_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Hekim bulunamadı'; END IF;

  UPDATE public.hekimler SET
    ad     = COALESCE(NULLIF(p_ad, ''), ad),
    telefon = COALESCE(NULLIF(p_telefon, ''), telefon),
    aktif  = COALESCE(p_aktif, aktif)
  WHERE id = p_hekim_id;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('HEKIM_GUNCELLE', p_hekim_id, 'hekimler', jsonb_build_object(
    'olusturulan', '[]'::jsonb,
    'guncellenen', jsonb_build_array(jsonb_build_object(
      'tablo', 'hekimler', 'id', p_hekim_id,
      'onceki', row_to_json(v_hekim)::jsonb,
      'sonraki', (SELECT row_to_json(hekimler)::jsonb FROM public.hekimler WHERE id = p_hekim_id)
    )),
    'silinen', '[]'::jsonb
  ), 'Hekim güncellendi: ' || COALESCE(p_ad, v_hekim.ad));

  RETURN jsonb_build_object('ok', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.padok_ekle(p_ad text, p_kapasite integer DEFAULT NULL::integer, p_sira integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_id uuid;
BEGIN
  IF NULLIF(p_ad, '') IS NULL THEN RAISE EXCEPTION 'Padok adı zorunlu'; END IF;
  v_id := gen_random_uuid();

  INSERT INTO public.padoklar (id, ad, kapasite, sira, aktif)
  VALUES (v_id, p_ad, p_kapasite, p_sira, true);

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('PADOK_EKLE', v_id::text, 'padoklar', jsonb_build_object(
    'olusturulan', jsonb_build_array(jsonb_build_object(
      'tablo', 'padoklar', 'id', v_id,
      'veri', jsonb_build_object('ad', p_ad, 'kapasite', p_kapasite, 'sira', p_sira)
    )),
    'guncellenen', '[]'::jsonb,
    'silinen', '[]'::jsonb
  ), 'Yeni padok: ' || p_ad);

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.padok_guncelle(p_padok_id uuid, p_ad text DEFAULT NULL::text, p_kapasite integer DEFAULT NULL::integer, p_sira integer DEFAULT NULL::integer, p_aktif boolean DEFAULT NULL::boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_padok record;
BEGIN
  SELECT * INTO v_padok FROM public.padoklar WHERE id = p_padok_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Padok bulunamadı'; END IF;

  UPDATE public.padoklar SET
    ad   = COALESCE(NULLIF(p_ad, ''), ad),
    kapasite = COALESCE(p_kapasite, kapasite),
    sira = COALESCE(p_sira, sira),
    aktif = COALESCE(p_aktif, aktif)
  WHERE id = p_padok_id;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('PADOK_GUNCELLE', p_padok_id::text, 'padoklar', jsonb_build_object(
    'olusturulan', '[]'::jsonb,
    'guncellenen', jsonb_build_array(jsonb_build_object(
      'tablo', 'padoklar', 'id', p_padok_id,
      'onceki', row_to_json(v_padok)::jsonb,
      'sonraki', (SELECT row_to_json(padoklar)::jsonb FROM public.padoklar WHERE id = p_padok_id)
    )),
    'silinen', '[]'::jsonb
  ), 'Padok güncellendi: ' || COALESCE(p_ad, v_padok.ad));

  RETURN jsonb_build_object('ok', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.kizginlik_sil(p_kayit_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_hayvan_id text;
  v_case_id   uuid;
BEGIN
  SELECT hayvan_id, tedavi_case_id INTO v_hayvan_id, v_case_id
  FROM public.kizginlik_log WHERE id = p_kayit_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'Kayıt bulunamadı');
  END IF;
  DELETE FROM public.kizginlik_log WHERE id = p_kayit_id;
  IF v_case_id IS NOT NULL THEN
    UPDATE public.cases
    SET status = 'closed', closed_at = now()
    WHERE id = v_case_id AND status = 'active';
  END IF;
  RETURN jsonb_build_object('ok', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public._kizginlik_case_close()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.status = 'closed' AND OLD.status = 'active' THEN
    UPDATE public.kizginlik_log
    SET cozuldu = true
    WHERE tedavi_case_id = NEW.id AND cozuldu = false;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.kizginlik_tedavi_baglanti_kur(p_kayit_id text, p_case_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  UPDATE public.kizginlik_log
  SET tedavi_case_id = p_case_id,
      cozuldu       = true
  WHERE id = p_kayit_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'Kayıt bulunamadı');
  END IF;
  RETURN jsonb_build_object('ok', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public._tohumlama_kizginlik_kapat()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE public.kizginlik_log
  SET cozuldu = true
  WHERE hayvan_id = NEW.hayvan_id
    AND tarih <= NEW.tarih
    AND cozuldu = false;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.case_geri_al(p_case_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_case       record;
  v_da_count   integer;
BEGIN
  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'Case bulunamadı');
  END IF;

  UPDATE public.kizginlik_log
  SET tedavi_case_id = NULL,
      cozuldu = false
  WHERE tedavi_case_id = p_case_id;

  SELECT COUNT(*) INTO v_da_count FROM public.drug_administrations da
  JOIN public.treatment_days td ON td.id = da.treatment_day_id
  WHERE td.case_id = p_case_id;

  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal, referans_tipi, referans_id)
  SELECT
    da.drug_product_id,
    'Case (Geri Al)',
    -da.dose,
    'Case geri alındı: ' || p_case_id::text,
    false,
    'case_geri_al',
    p_case_id::text
  FROM public.drug_administrations da
  JOIN public.treatment_days td ON td.id = da.treatment_day_id
  WHERE td.case_id = p_case_id;

  DELETE FROM public.drug_administrations da
  USING public.treatment_days td
  WHERE td.id = da.treatment_day_id AND td.case_id = p_case_id;

  DELETE FROM public.treatment_days WHERE case_id = p_case_id;

  UPDATE public.cases
  SET status = 'closed', closed_at = now(), notes = COALESCE(notes || ' | ', '') || 'Geri alındı: ' || now()::text
  WHERE id = p_case_id;

  UPDATE public.islem_log
  SET durum = 'geri_alindi', geri_alma_tarihi = now()
  WHERE ref_tablo = 'cases' AND ref_id = p_case_id::text;

  RETURN jsonb_build_object(
    'ok', true,
    'silinen_ilac_kaydi', v_da_count,
    'kizginlik_baglantisi_koptu', (SELECT count(*) FROM kizginlik_log WHERE tedavi_case_id = p_case_id) = 0
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.tohumlama_cycle_gorevcil_iptal()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.gorev_log
    SET iptal = true
    WHERE hayvan_id = NEW.hayvan_id
      AND tamamlandi = false
      AND iptal = false
      AND gorev_tipi IN (
        'ILERI_GEBE', 'ILERI_GEBE_ASI', 'PADOK_DEGISIM',
        'BESLEME', 'TOHUMLAMA_HAZIRLIK', 'GEBELIK_KONTROL'
      );
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE'
     AND OLD.sonuc IN ('Bekliyor', 'Gebe')
     AND NEW.sonuc IN ('Boş', 'Abort') THEN
    UPDATE public.gorev_log
    SET iptal = true
    WHERE hayvan_id = NEW.hayvan_id
      AND tamamlandi = false
      AND iptal = false
      AND gorev_tipi IN (
        'ILERI_GEBE', 'ILERI_GEBE_ASI', 'PADOK_DEGISIM',
        'BESLEME', 'TOHUMLAMA_HAZIRLIK', 'GEBELIK_KONTROL'
      )
      AND (ref_tohumlama_id IS NULL OR ref_tohumlama_id = NEW.id::text);
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public._debug_protokol_ozet()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_toplam int;
  v_aktif  int;
  v_iptal  int;
  v_gorev_bagli int;
  v_gorev_toplam int;
BEGIN
  SELECT COUNT(*) INTO v_toplam FROM protokol_instance;
  SELECT COUNT(*) INTO v_aktif  FROM protokol_instance WHERE durum='aktif';
  SELECT COUNT(*) INTO v_iptal  FROM protokol_instance WHERE durum='iptal';
  SELECT COUNT(*) INTO v_gorev_bagli  FROM gorev_log WHERE protokol_instance_id IS NOT NULL;
  SELECT COUNT(*) INTO v_gorev_toplam FROM gorev_log;
  RETURN jsonb_build_object(
    'protokol_instance', jsonb_build_object(
      'toplam', v_toplam, 'aktif', v_aktif, 'iptal', v_iptal
    ),
    'gorev_log', jsonb_build_object(
      'toplam', v_gorev_toplam,
      'protokol_bagli', v_gorev_bagli,
      'protokol_bagli_pct', ROUND(v_gorev_bagli::numeric / NULLIF(v_gorev_toplam,0) * 100, 1)
    ),
    'tip_dagilim', (
      SELECT jsonb_agg(r ORDER BY r->>'tip', r->>'alttip')
      FROM (
        SELECT jsonb_build_object('tip', tip, 'alttip', alttip, 'durum', durum, 'adet', COUNT(*)) AS r
        FROM protokol_instance GROUP BY tip, alttip, durum
      ) sub
    )
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.add_treatment_day(p_case_id uuid, p_date date, p_planned_time time without time zone DEFAULT NULL::time without time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_day_id        uuid;
  v_gorev_id      uuid;
  v_prev_gorev_id uuid := NULL;
  v_day_no        int;
  v_case          record;
  v_gecmis        boolean;
BEGIN
  SELECT COALESCE(MAX(day_no), 0) + 1 INTO v_day_no
  FROM public.treatment_days
  WHERE case_id = p_case_id;

  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadı');
  END IF;

  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakaya gün eklenemez');
  END IF;

  v_gecmis := p_date < CURRENT_DATE;

  IF v_day_no > 1 THEN
    SELECT g.id INTO v_prev_gorev_id
    FROM public.gorev_log g
    JOIN public.treatment_days td ON (g.aciklama::jsonb->>'day_id')::uuid = td.id
    WHERE td.case_id = p_case_id
      AND td.day_no  = v_day_no - 1
      AND g.gorev_tipi = 'TEDAVI_GUN'
    LIMIT 1;
  END IF;

  INSERT INTO public.treatment_days(id, case_id, day_no, treatment_date, tamamlandi, tamamlanma_tarihi, planned_time)
  VALUES (
    gen_random_uuid(), p_case_id, v_day_no, p_date,
    v_gecmis,
    CASE WHEN v_gecmis THEN p_date::timestamptz ELSE NULL END,
    p_planned_time
  )
  RETURNING id INTO v_day_id;

  INSERT INTO public.gorev_log(
    id, gorev_tipi, hayvan_id, hedef_tarih, aciklama,
    tamamlandi, tamamlanma_tarihi, parent_id
  )
  VALUES (
    gen_random_uuid(),
    'TEDAVI_GUN',
    v_case.animal_id,
    p_date,
    jsonb_build_object(
      'day_id',       v_day_id,
      'gun_no',       v_day_no,
      'label',        'Gün ' || v_day_no || ' tedavisi — ' || to_char(p_date, 'DD.MM.YYYY'),
      'planned_time', COALESCE(p_planned_time::text, '')
    )::text,
    v_gecmis,
    CASE WHEN v_gecmis THEN p_date::timestamptz ELSE NULL END,
    v_prev_gorev_id
  )
  RETURNING id INTO v_gorev_id;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    'TEDAVI_GUN_EKLENDI',
    v_case.animal_id,
    v_day_id::text,
    'treatment_days',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'treatment_days', 'id', v_day_id::text),
        jsonb_build_object('tablo', 'gorev_log',      'id', v_gorev_id::text)
      ),
      'guncellenen', '[]'::jsonb
    )
  );

  RETURN jsonb_build_object('ok', true, 'day_id', v_day_id, 'day_no', v_day_no, 'gecmis', v_gecmis);
END;
$function$;

CREATE OR REPLACE FUNCTION public.tohumlama_geri_al(p_tohumlama_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_tohumlama  record;
  v_stok_id    text;
  v_stok_miktar numeric;
BEGIN
  SELECT * INTO v_tohumlama FROM public.tohumlama WHERE id = p_tohumlama_id::uuid;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'Tohumlama kaydı bulunamadı');
  END IF;

  UPDATE public.kizginlik_log
  SET cozuldu = false
  WHERE hayvan_id = v_tohumlama.hayvan_id
    AND tarih <= v_tohumlama.tarih
    AND cozuldu = true
    AND tedavi_case_id IS NULL
    AND NOT EXISTS (
      SELECT 1 FROM public.tohumlama t2
      WHERE t2.hayvan_id = v_tohumlama.hayvan_id
        AND t2.id != p_tohumlama_id::uuid
        AND t2.tarih >= v_tohumlama.tarih
    );

  IF v_tohumlama.sperma IS NOT NULL AND v_tohumlama.sperma != '' THEN
    SELECT id INTO v_stok_id FROM public.stok
    WHERE urun_adi ILIKE '%' || v_tohumlama.sperma || '%'
      AND kategori = 'Sperma'
    LIMIT 1;

    IF v_stok_id IS NOT NULL THEN
      SELECT COALESCE(SUM(miktar), 0) INTO v_stok_miktar
      FROM public.stok_hareket
      WHERE stok_id = v_stok_id
        AND referans_tipi = 'tohumlama'
        AND referans_id::text = p_tohumlama_id
        AND NOT iptal;

      IF v_stok_miktar > 0 THEN
        INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal, referans_tipi, referans_id)
        VALUES (v_stok_id, 'Tohumlama (Geri Al)', -v_stok_miktar, 'Tohumlama geri alındı: ' || p_tohumlama_id, false, 'tohumlama_geri_al', p_tohumlama_id);
      END IF;
    END IF;
  END IF;

  DELETE FROM public.tohumlama WHERE id = p_tohumlama_id::uuid;

  UPDATE public.islem_log
  SET durum = 'geri_alindi', geri_alma_tarihi = now()
  WHERE ref_tablo = 'tohumlama' AND ref_id::text = p_tohumlama_id;

  RETURN jsonb_build_object('ok', true);
END;
$function$;

CREATE OR REPLACE FUNCTION public.test_dollar_block()
 RETURNS text
 LANGUAGE plpgsql
AS $function$ BEGIN RETURN 'dollar_block_works'; END; $function$;



-- ════════════════════════════════════════════════════════════════
-- 2 EKSİK FONKSİYON DÜZELTME (REGEN 2026-06-13)
-- ════════════════════════════════════════════════════════════════

NOTIFY pgrst, 'reload schema';
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS devlet_kupe text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS cinsiyet text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS anne_id text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS baba_bilgi text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS canli_agirlik numeric;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS dogum_kg numeric;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS boy numeric;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS renk text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS ayirici_ozellik text;

ALTER TABLE public.stok ADD COLUMN IF NOT EXISTS kategori text;
ALTER TABLE public.stok ADD COLUMN IF NOT EXISTS esik numeric DEFAULT 0;

ALTER TABLE public.dogum ADD COLUMN IF NOT EXISTS dogum_kg numeric;
ALTER TABLE public.dogum ADD COLUMN IF NOT EXISTS baba_bilgi text;

ALTER TABLE public.hastalik_log DROP CONSTRAINT IF EXISTS hastalik_log_hayvan_id_fkey;

ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS iptal boolean DEFAULT false;
ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS padok_hedef text;

NOTIFY pgrst, 'reload schema';ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS padok text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS kupe_no text;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS durum text DEFAULT 'Aktif';
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS grup text;
ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS iptal boolean DEFAULT false;
ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS padok_hedef text;
ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS hekim_id text;
ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS miktar numeric;
NOTIFY pgrst, 'reload schema';DO $$ BEGIN
  ALTER TABLE public.stok_hareket 
    ADD CONSTRAINT stok_hareket_stok_id_fkey 
    FOREIGN KEY (stok_id) REFERENCES public.stok(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE public.tohumlama
    ADD CONSTRAINT tohumlama_hayvan_id_fkey
    FOREIGN KEY (hayvan_id) REFERENCES public.hayvanlar(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE public.dogum
    ADD CONSTRAINT dogum_anne_id_fkey
    FOREIGN KEY (anne_id) REFERENCES public.hayvanlar(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  ALTER TABLE public.gorev_log
    ADD CONSTRAINT gorev_log_hayvan_id_fkey
    FOREIGN KEY (hayvan_id) REFERENCES public.hayvanlar(id) ON DELETE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

NOTIFY pgrst, 'reload schema';CREATE OR REPLACE FUNCTION public.set_deneme_no()
RETURNS TRIGGER AS $$
BEGIN
  SELECT COALESCE(COUNT(*), 0) + 1 INTO NEW.deneme_no
  FROM public.tohumlama
  WHERE hayvan_id = NEW.hayvan_id
    AND tarih > COALESCE(
      (SELECT MAX(tarih) FROM public.tohumlama
       WHERE hayvan_id = NEW.hayvan_id AND sonuc IN ('Doğum Yaptı', 'Abort')),
      '1900-01-01'::date
    );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_deneme_no ON public.tohumlama;
CREATE TRIGGER trg_deneme_no
  BEFORE INSERT ON public.tohumlama
  FOR EACH ROW EXECUTE FUNCTION public.set_deneme_no();

NOTIFY pgrst, 'reload schema';-- ══════════════════════════════════════════════════════════════
-- FAZ 1 — CORE MIGRATION
-- EgeSüt ERP v9 — 2026-03-06
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────
-- 1. EKSİK KOLON DÜZELTMELERİ (mevcut 400 hatalarının kaynağı)
-- ──────────────────────────────────────────

-- kizginlik_log tablosu yoktu
CREATE TABLE IF NOT EXISTS public.kizginlik_log (
  id          text PRIMARY KEY,
  hayvan_id   text,
  tarih       date,
  belirti     text,
  notlar      text,
  olusturma   timestamptz DEFAULT now()
);

-- hastalik_log eksik kolonlar
ALTER TABLE public.hastalik_log ADD COLUMN IF NOT EXISTS lokasyon text;
ALTER TABLE public.hastalik_log ADD COLUMN IF NOT EXISTS siddet   text;

-- tohumlama eksik kolonlar
ALTER TABLE public.tohumlama ADD COLUMN IF NOT EXISTS dogum_tarihi  date;
ALTER TABLE public.tohumlama ADD COLUMN IF NOT EXISTS buzagi_kupe   text;
ALTER TABLE public.tohumlama ADD COLUMN IF NOT EXISTS abort_notlar  text;

-- gorev_log eksik kolon
ALTER TABLE public.gorev_log ADD COLUMN IF NOT EXISTS kaynak text;

-- dogum eksik kolon
ALTER TABLE public.dogum ADD COLUMN IF NOT EXISTS hekim_id text;

-- ──────────────────────────────────────────
-- 2. HAYVAN YAŞAM DÖNGÜSÜ KOLONLARI
-- ──────────────────────────────────────────

-- Biyolojik kategori (frontend hesaplamaz, backend view'dan gelir)
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS kategori text;
  -- Değerler: sut_icen | suttten_kesilmis | kucuk_dana_duve |
  --           buyuk_dana_duve | buyuk_duve | sagmal_inek |
  --           kuru_donem | besi_danasi | tosun

-- Yaşam olayları tarihleri
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS suttten_kesme_tarihi   date;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS tohumlama_onay_tarihi  date;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS tohumlama_durumu       text;
  -- Değerler: NULL | tohumlanabilir | tohumlandi | gebe | ertelendi

-- Sürüden çıkış
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS cikis_tipi    text;   -- olum | satis
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS cikis_tarihi  date;
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS cikis_sebebi  text;   -- ölüm sebebi veya satış notu
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS satis_fiyati  numeric;

-- ──────────────────────────────────────────
-- 3. IRK EŞİK TABLOSU
-- Tohumlama minimum yaşı ırka göre (gün cinsinden)
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.irk_esik (
  id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  irk             text NOT NULL UNIQUE,
  tohumlama_gun   integer NOT NULL DEFAULT 365,
  suttten_kesme_gun integer NOT NULL DEFAULT 60,
  guncelleme      timestamptz DEFAULT now()
);

-- Varsayılan ırk eşikleri
INSERT INTO public.irk_esik (irk, tohumlama_gun, suttten_kesme_gun) VALUES
  ('Holstein',   365, 60),
  ('Montofon',   420, 60),
  ('Simmental',  400, 60),
  ('Jersey',     365, 56),
  ('Simental',   400, 60),
  ('Melez',      365, 60)
ON CONFLICT (irk) DO NOTHING;

-- ──────────────────────────────────────────
-- 4. BİLDİRİM LOG TABLOSU
-- Backend yazar, frontend sadece okur
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.bildirim_log (
  id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  hayvan_id       text,
  tip             text NOT NULL,
    -- tohumlama_yasi | suttten_kesme | dogum_yaklasti |
    -- dogum_gecikti  | tedavi_takip  | stok_kritik
  mesaj           text,
  durum           text NOT NULL DEFAULT 'bekliyor',
    -- bekliyor | goruldu | ertelendi | tamamlandi | iptal
  erteleme_tarihi date,
  olusturma       timestamptz DEFAULT now(),
  guncelleme      timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bildirim_hayvan   ON public.bildirim_log(hayvan_id);
CREATE INDEX IF NOT EXISTS idx_bildirim_durum    ON public.bildirim_log(durum);
CREATE INDEX IF NOT EXISTS idx_bildirim_tip      ON public.bildirim_log(tip);

-- ──────────────────────────────────────────
-- 5. İŞLEM LOG TABLOSU
-- Her işlem buraya yazılır → geri alma buradan yapılır
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.islem_log (
  id              text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  tip             text NOT NULL,
    -- DOGUM_KAYDI | TOHUMLAMA | HASTALIK | OLUM | SATIS |
    -- SUTEN_KESME | ABORT | GOREV_TAMAMLA | STOK_HAREKET
  ana_hayvan_id   text,
  tarih           timestamptz DEFAULT now(),
  kullanici_notu  text,
  durum           text NOT NULL DEFAULT 'aktif',  -- aktif | geri_alindi
  geri_alma_tarihi timestamptz,
  -- Etkilenen tüm kayıtlar JSON olarak saklanır
  -- Geri almada bu snapshot kullanılır
  snapshot        jsonb NOT NULL
    -- {
    --   "olusturulan": [{"tablo":"hayvanlar","id":"...","veri":{...}}],
    --   "guncellenen": [{"tablo":"tohumlama","id":"...","onceki":{...},"sonraki":{...}}],
    --   "silinen":     [{"tablo":"gorev_log","id":"...","veri":{...}}]
    -- }
);

CREATE INDEX IF NOT EXISTS idx_islem_hayvan  ON public.islem_log(ana_hayvan_id);
CREATE INDEX IF NOT EXISTS idx_islem_tarih   ON public.islem_log(tarih DESC);
CREATE INDEX IF NOT EXISTS idx_islem_durum   ON public.islem_log(durum);

-- ──────────────────────────────────────────
-- 6. ÇÖP KUTUSU TABLOSU
-- Silinen kayıtlar 30 gün burada bekler
-- ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.cop_kutusu (
  id                    text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  kaynak_tablo          text NOT NULL,
  kaynak_id             text NOT NULL,
  veri                  jsonb NOT NULL,
  silme_tarihi          timestamptz DEFAULT now(),
  otomatik_silme_tarihi timestamptz DEFAULT (now() + interval '30 days'),
  geri_yuklendi         boolean DEFAULT false,
  silme_sebebi          text   -- islem_log.id referansı veya 'manuel'
);

CREATE INDEX IF NOT EXISTS idx_cop_tablo      ON public.cop_kutusu(kaynak_tablo);
CREATE INDEX IF NOT EXISTS idx_cop_silme      ON public.cop_kutusu(otomatik_silme_tarihi);
CREATE INDEX IF NOT EXISTS idx_cop_geri       ON public.cop_kutusu(geri_yuklendi);

-- ──────────────────────────────────────────
-- 7. HAYVAN DURUM VIEW
-- Frontend bu view'ı okur — badge ve kategori hesabı burada
-- ──────────────────────────────────────────

-- ════════════════════════════════════════════════════════════════
-- 6.6 HAYVAN_DURUM_ANALIZI VIEW (canlı DB diff — REGEN 2026-06-13)
-- ════════════════════════════════════════════════════════════════

DROP VIEW IF EXISTS public.hayvan_durum_analizi CASCADE;
CREATE OR REPLACE VIEW public.hayvan_durum_analizi AS
 WITH gebelik_donem AS (
         SELECT vethek_tohumlamalar.kupe_no,
            vethek_tohumlamalar.tohumlama_tar,
            vethek_tohumlamalar.gebe,
            vethek_tohumlamalar.sperma,
            vethek_tohumlamalar.not_,
            sum(
                CASE WHEN vethek_tohumlamalar.gebe THEN 1 ELSE 0 END
            ) OVER (PARTITION BY vethek_tohumlamalar.kupe_no ORDER BY vethek_tohumlamalar.tohumlama_tar ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS donem_no
           FROM vethek_tohumlamalar
        ), tohumlama_no AS (
         SELECT gebelik_donem.kupe_no,
            gebelik_donem.tohumlama_tar,
            row_number() OVER (PARTITION BY gebelik_donem.kupe_no, gebelik_donem.donem_no ORDER BY gebelik_donem.tohumlama_tar) AS t_no
           FROM gebelik_donem
        ), son_kayitlar AS (
         SELECT DISTINCT ON (vethek_tohumlamalar.kupe_no) vethek_tohumlamalar.kupe_no,
            vethek_tohumlamalar.tohumlama_tar,
            vethek_tohumlamalar.gebe,
            vethek_tohumlamalar.sperma,
            vethek_tohumlamalar.not_
           FROM vethek_tohumlamalar
          ORDER BY vethek_tohumlamalar.kupe_no, vethek_tohumlamalar.tohumlama_tar DESC
        ), son_gebelikler AS (
         SELECT vethek_tohumlamalar.kupe_no,
            max(vethek_tohumlamalar.tohumlama_tar) AS son_gebe_tarihi
           FROM vethek_tohumlamalar
          WHERE (vethek_tohumlamalar.gebe = true)
          GROUP BY vethek_tohumlamalar.kupe_no
        )
 SELECT kupe_no,
    tohumlama_tar AS son_islem_tarihi,
    gebe AS gebe_mi,
    sperma,
    not_::text AS not_,
    (CURRENT_DATE - tohumlama_tar) AS gecen_gun,
    (CURRENT_DATE - tohumlama_tar) > 360 AS pasif_mi,
    son_gebelikler.son_gebe_tarihi,
    (son_gebelikler.son_gebe_tarihi + interval '285 days')::date AS tahmini_dogum,
    tohumlama_no.t_no
   FROM son_kayitlar
     LEFT JOIN son_gebelikler USING (kupe_no)
     LEFT JOIN tohumlama_no USING (kupe_no, tohumlama_tar);
GRANT ALL ON public.hayvan_durum_analizi TO anon, authenticated;

DROP VIEW IF EXISTS public.hayvan_durum_view CASCADE;
-- ──────────────────────────────────────────
-- 8. RAPORLAMA VIEWleri
-- ──────────────────────────────────────────

-- Gebelik özet
CREATE OR REPLACE VIEW public.gebelik_ozet_view AS
SELECT
  COUNT(*) FILTER (WHERE sonuc = 'Gebe')        AS gebe_sayisi,
  COUNT(*) FILTER (WHERE sonuc = 'Bekliyor')    AS bekleyen_sayisi,
  COUNT(*) FILTER (WHERE sonuc = 'Abort')       AS abort_sayisi,
  COUNT(*) FILTER (WHERE sonuc = 'Doğum Yaptı') AS dogum_yapti_sayisi,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
    / NULLIF(COUNT(*), 0), 1
  ) AS gebelik_orani_pct
FROM public.tohumlama
WHERE tarih >= CURRENT_DATE - interval '12 months';

-- Hastalık istatistik
CREATE OR REPLACE VIEW public.hastalik_istatistik_view AS
SELECT
  tani,
  kategori,
  COUNT(*)                                           AS toplam,
  COUNT(*) FILTER (WHERE durum = 'Aktif')            AS aktif,
  COUNT(*) FILTER (WHERE durum = 'İyileşti')         AS iyilesti,
  MIN(tarih)                                         AS ilk_gorulme,
  MAX(tarih)                                         AS son_gorulme
FROM public.hastalik_log
GROUP BY tani, kategori
ORDER BY toplam DESC;

-- Stok tüketim
CREATE OR REPLACE VIEW public.stok_tuketim_view AS
SELECT
  s.id,
  s.urun_adi,
  s.kategori,
  s.birim,
  s.baslangic_miktar,
  s.esik,
  COALESCE(SUM(sh.miktar) FILTER (WHERE NOT sh.iptal), 0) AS toplam_kullanim,
  s.baslangic_miktar - COALESCE(SUM(sh.miktar) FILTER (WHERE NOT sh.iptal), 0) AS guncel_stok,
  CASE
    WHEN s.baslangic_miktar - COALESCE(SUM(sh.miktar) FILTER (WHERE NOT sh.iptal), 0) <= 0
    THEN 'tukendi'
    WHEN s.baslangic_miktar - COALESCE(SUM(sh.miktar) FILTER (WHERE NOT sh.iptal), 0) <= s.esik
    THEN 'kritik'
    ELSE 'normal'
  END AS stok_durum,
  s.drug_product_id
FROM public.stok s
LEFT JOIN public.stok_hareket sh ON sh.stok_id = s.id
GROUP BY s.id, s.urun_adi, s.kategori, s.birim, s.baslangic_miktar, s.esik, s.drug_product_id;

-- ──────────────────────────────────────────
-- 9. DUPLICATE KONTROL FONKSİYONU
-- Frontend kayıt öncesi bu fonksiyonu çağırır
-- ──────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.kupe_musait_mi(
  p_kupe_no     text,
  p_devlet_kupe text,
  p_hayvan_id   text DEFAULT NULL  -- güncelleme için mevcut ID hariç tut
)
RETURNS jsonb AS $func$
DECLARE
  v_kupe_cakisma    text;
  v_devlet_cakisma  text;
BEGIN
  -- İşletme küpesi çakışması
  IF p_kupe_no IS NOT NULL AND p_kupe_no != '' THEN
    SELECT id INTO v_kupe_cakisma
    FROM public.hayvanlar
    WHERE kupe_no = p_kupe_no
      AND (p_hayvan_id IS NULL OR id != p_hayvan_id)
    LIMIT 1;
  END IF;

  -- Devlet küpesi çakışması
  IF p_devlet_kupe IS NOT NULL AND p_devlet_kupe != '' THEN
    SELECT id INTO v_devlet_cakisma
    FROM public.hayvanlar
    WHERE devlet_kupe = p_devlet_kupe
      AND (p_hayvan_id IS NULL OR id != p_hayvan_id)
    LIMIT 1;
  END IF;

  RETURN jsonb_build_object(
    'musait',           (v_kupe_cakisma IS NULL AND v_devlet_cakisma IS NULL),
    'kupe_cakisma_id',  v_kupe_cakisma,
    'devlet_cakisma_id',v_devlet_cakisma
  );
END;
$func$ LANGUAGE plpgsql;

-- ──────────────────────────────────────────
-- 10. BAŞLAT
-- ──────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
-- ═══════════════════════════════════════════════════════════════
-- MIGRATION 008 — BLOK 1: BACKEND TEMELİ
-- EgeSüt ERP v9 — 2026-03-06
-- Tüm iş mantığı frontend'den backend'e taşındı.
-- Frontend artık sadece bu prosedürleri çağırır.
-- ═══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- 1. YENİ KOLONLAR
-- ──────────────────────────────────────────────────────────────
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS notlar text;
ALTER TABLE public.irk_esik  ADD COLUMN IF NOT EXISTS kullanim_sayisi integer NOT NULL DEFAULT 0;

-- ──────────────────────────────────────────────────────────────
-- 2. HAYVAN_EKLE — Yeni hayvan kaydı
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hayvan_ekle(
  p_kupe_no        text    DEFAULT NULL,
  p_devlet_kupe    text    DEFAULT NULL,
  p_irk            text    DEFAULT NULL,
  p_cinsiyet       text    DEFAULT NULL,
  p_dogum_tarihi   date    DEFAULT NULL,
  p_grup           text    DEFAULT 'Genel',
  p_padok          text    DEFAULT 'P1',
  p_dogum_kg       numeric DEFAULT NULL,
  p_anne_id        text    DEFAULT NULL,
  p_baba_bilgi     text    DEFAULT NULL,
  p_canli_agirlik  numeric DEFAULT NULL,
  p_boy            numeric DEFAULT NULL,
  p_renk           text    DEFAULT NULL,
  p_ayirici_ozellik text   DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_chk  jsonb;
  v_id   text;
  v_sayac integer;
BEGIN
  -- Küpe müsait mi?
  SELECT public.kupe_musait_mi(p_kupe_no, p_devlet_kupe) INTO v_chk;
  IF NOT (v_chk->>'musait')::boolean THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      CASE WHEN v_chk->>'kupe_cakisma_id' IS NOT NULL
        THEN 'İşletme küpesi zaten kayıtlı: ' || COALESCE(p_kupe_no,'')
        ELSE 'Devlet küpesi zaten kayıtlı: ' || COALESCE(p_devlet_kupe,'')
      END);
  END IF;

  -- ID üret (H + 6 hane sıralı)
  SELECT 'H' || LPAD((COUNT(*)+1)::text, 6, '0') INTO v_id FROM public.hayvanlar;

  INSERT INTO public.hayvanlar (
    id, kupe_no, devlet_kupe, irk, cinsiyet, dogum_tarihi,
    grup, padok, durum, dogum_kg, anne_id, baba_bilgi,
    canli_agirlik, boy, renk, ayirici_ozellik
  ) VALUES (
    v_id, NULLIF(p_kupe_no,''), NULLIF(p_devlet_kupe,''),
    NULLIF(p_irk,''), p_cinsiyet, p_dogum_tarihi,
    p_grup, p_padok, 'Aktif', p_dogum_kg, p_anne_id, p_baba_bilgi,
    p_canli_agirlik, p_boy, p_renk, p_ayirici_ozellik
  );

  -- Irk kullanım sayacı
  IF p_irk IS NOT NULL AND p_irk <> '' THEN
    UPDATE public.irk_esik SET kullanim_sayisi = kullanim_sayisi + 1
    WHERE irk = p_irk;
    -- Bilinmeyen ırk → otomatik ekle
    GET DIAGNOSTICS v_sayac = ROW_COUNT;
    IF v_sayac = 0 THEN
      INSERT INTO public.irk_esik (irk, tohumlama_gun, suttten_kesme_gun, kullanim_sayisi)
      VALUES (p_irk, 365, 60, 1)
      ON CONFLICT (irk) DO UPDATE SET kullanim_sayisi = irk_esik.kullanim_sayisi + 1;
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true, 'hayvan_id', v_id);
END;
$$ LANGUAGE plpgsql;

-- ──────────────────────────────────────────────────────────────
-- 3. DOGUM_KAYDET — Doğum + buzağı + görevler tek transaction
-- ──────────────────────────────────────────────────────────────
-- 4. TOHUMLAMA_KAYDET
-- ──────────────────────────────────────────────────────────────
-- 5. KIZGINLIK_KAYDET
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.kizginlik_kaydet(
  p_hayvan_id  text,
  p_tarih      date,
  p_belirti    text    DEFAULT NULL,
  p_notlar     text    DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_hayvan       record;
  v_yas_gun      integer;
  v_son_dogum    date;
  v_dogum_gun    integer := NULL;
  v_sonuc        text := 'GOZLEMLENDI';
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  IF v_hayvan.cinsiyet = 'Erkek' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Erkek hayvanlarda kızgınlık kaydı yapılamaz');
  END IF;

  IF v_hayvan.dogum_tarihi IS NOT NULL THEN
    v_yas_gun := CURRENT_DATE - v_hayvan.dogum_tarihi;
    IF v_yas_gun < 365 THEN
      RETURN jsonb_build_object(
        'ok', false,
        'mesaj', 'Hayvan 12 aydan küçük — kızgınlık kaydı yapılamaz',
        'oneri', 'Hayvan kartındaki Notlar bölümüne ekleyin'
      );
    END IF;
  END IF;

  -- Son doğum tarihini kontrol et (dogum tablosundan)
  SELECT MAX(d.tarih) INTO v_son_dogum
  FROM public.dogum d
  WHERE d.anne_id = p_hayvan_id;

  IF v_son_dogum IS NOT NULL THEN
    v_dogum_gun := p_tarih - v_son_dogum;
    IF v_dogum_gun >= 0 AND v_dogum_gun < 55 THEN
      v_sonuc := 'POSTPARTUM_GOZLEM';
    END IF;
  END IF;

  INSERT INTO public.kizginlik_log (id, hayvan_id, tarih, belirti, notlar, sonuc)
  VALUES (gen_random_uuid()::text, p_hayvan_id, p_tarih, p_belirti, p_notlar, v_sonuc);

  RETURN jsonb_build_object(
    'ok', true,
    'postpartum', v_sonuc = 'POSTPARTUM_GOZLEM',
    'dogum_gun', v_dogum_gun
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.kizginlik_kaydet(text, date, text, text) TO anon, authenticated;

-- ──────────────────────────────────────────────────────────────
-- 6. HASTALIK_KAYDET
-- ──────────────────────────────────────────────────────────────
-- 7. ABORT_KAYDET
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.abort_kaydet(
  p_tohumlama_id  text,
  p_notlar        text DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_toh record;
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama WHERE id = p_tohumlama_id::uuid AND sonuc = 'Gebe';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Gebe tohumlama kaydı bulunamadı');
  END IF;

  UPDATE public.tohumlama
  SET sonuc = 'Abort', abort_notlar = p_notlar
  WHERE id = p_tohumlama_id::uuid;

  UPDATE public.hayvanlar
  SET tohumlama_durumu = NULL, tohumlama_onay_tarihi = NULL
  WHERE id = v_toh.hayvan_id;

  RETURN jsonb_build_object('ok', true, 'hayvan_id', v_toh.hayvan_id);
END;
$$ LANGUAGE plpgsql;

-- ──────────────────────────────────────────────────────────────
-- 8. HAYVAN NOTU EKLE
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hayvan_not_ekle(
  p_hayvan_id  text,
  p_not        text
) RETURNS jsonb AS $$
DECLARE
  v_mevcut text;
  v_yeni   text;
  v_tarih  text := TO_CHAR(CURRENT_DATE, 'DD.MM.YYYY');
BEGIN
  SELECT notlar INTO v_mevcut FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  v_yeni := CASE
    WHEN v_mevcut IS NULL OR v_mevcut = '' THEN '[' || v_tarih || '] ' || p_not
    ELSE v_mevcut || E'\n' || '[' || v_tarih || '] ' || p_not
  END;

  UPDATE public.hayvanlar SET notlar = v_yeni WHERE id = p_hayvan_id;

  RETURN jsonb_build_object('ok', true, 'notlar', v_yeni);
END;
$$ LANGUAGE plpgsql;

-- ──────────────────────────────────────────────────────────────
-- 9. İŞLEM LOG OTOMATİK TRIGGER'LAR
-- Her tablo INSERT/UPDATE'de islem_log'a otomatik yazar.
-- Frontend'in yazIslemLog() çağırmasına gerek kalmaz.
CREATE TRIGGER trg_islem_hayvanlar
  AFTER INSERT ON public.hayvanlar
  FOR EACH ROW EXECUTE FUNCTION public._islem_log_yaz();

CREATE TRIGGER trg_islem_dogum
  AFTER INSERT ON public.dogum
  FOR EACH ROW EXECUTE FUNCTION public._islem_log_yaz();

CREATE TRIGGER trg_islem_tohumlama_insert
  AFTER INSERT ON public.tohumlama
  FOR EACH ROW EXECUTE FUNCTION public._islem_log_yaz();

CREATE TRIGGER trg_islem_tohumlama_abort
  AFTER UPDATE OF sonuc ON public.tohumlama
  FOR EACH ROW EXECUTE FUNCTION public._islem_log_yaz();

CREATE TRIGGER trg_islem_hastalik
  AFTER INSERT ON public.hastalik_log
  FOR EACH ROW EXECUTE FUNCTION public._islem_log_yaz();

CREATE TRIGGER trg_islem_kizginlik
  AFTER INSERT ON public.kizginlik_log
  FOR EACH ROW EXECUTE FUNCTION public._islem_log_yaz();

-- ──────────────────────────────────────────────────────────────
-- 10. HAYVAN_DURUM_VIEW GÜNCELLEMESİ
-- notlar ve abort_sayisi eklendi
-- ──────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS public.hayvan_durum_view CASCADE;
-- ──────────────────────────────────────────────────────────────
-- 11. IRK LİSTESİ FONKSİYONU (frontend dropdown için)
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.irk_listesi()
RETURNS TABLE(irk text, tohumlama_gun integer, suttten_kesme_gun integer, kullanim_sayisi integer)
AS $$
  SELECT irk, tohumlama_gun, suttten_kesme_gun, kullanim_sayisi
  FROM public.irk_esik
  ORDER BY kullanim_sayisi DESC, irk ASC;
$$ LANGUAGE sql;

-- ──────────────────────────────────────────────────────────────
-- 12. NOTIFY — PostgREST schema cache yenile
-- ──────────────────────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';

-- ──────────────────────────────────────────────────────────────
-- 13. RLS POLİCY'LERİ — tüm tablolar
-- ──────────────────────────────────────────────────────────────
DO $$ 
DECLARE t text;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'hayvanlar','tohumlama','hastalik_log','dogum','stok','stok_hareket',
    'gorev_log','buzagi_takip','kizginlik_log','bildirim_log','islem_log',
    'cop_kutusu','irk_esik'
  ]) LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    -- Mevcut policy varsa drop et, yeniden oluştur
    BEGIN
      EXECUTE format('DROP POLICY IF EXISTS allow_all ON public.%I', t);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    EXECUTE format(
      'CREATE POLICY allow_all ON public.%I FOR ALL USING (true) WITH CHECK (true)', t
    );
  END LOOP;
END $$;

-- Stored function'lar SECURITY DEFINER — RLS bypass eder
ALTER FUNCTION public.hayvan_ekle       SECURITY DEFINER;
ALTER FUNCTION public.dogum_kaydet      SECURITY DEFINER;
ALTER FUNCTION public.tohumlama_kaydet  SECURITY DEFINER;
ALTER FUNCTION public.kizginlik_kaydet  SECURITY DEFINER;
ALTER FUNCTION public.hastalik_kaydet   SECURITY DEFINER;
ALTER FUNCTION public.abort_kaydet      SECURITY DEFINER;
ALTER FUNCTION public.hayvan_not_ekle   SECURITY DEFINER;
ALTER FUNCTION public.cikis_yap         SECURITY DEFINER;
ALTER FUNCTION public.geri_al           SECURITY DEFINER;
ALTER FUNCTION public._islem_log_yaz    SECURITY DEFINER;
-- ═══════════════════════════════════════════════════════════════
-- Migration 009 — DB Zemini
-- 1. hekimler tablosu (app.js sabit array → DB)
-- 2. islem_log payload kolonu (event standartlaştırma)
-- 3. hayvan_timeline_view (UI'a hazır event listesi)
-- 4. tohumlama_kaydet validasyon (erkek + yaş + aktif gebelik)
-- Tümü idempotent: tekrar çalıştırılabilir
-- ═══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- 1. HEKİMLER TABLOSU
  id      text PRIMARY KEY,
  ad      text NOT NULL,
  telefon text,
  aktif   boolean NOT NULL DEFAULT true
);

-- Seed: app.js'deki sabit array buraya taşınıyor
INSERT INTO public.hekimler (id, ad, aktif) VALUES
  ('H1', 'Melik Tokur',        true),
  ('H2', 'Hüseyin Aygün',      true),
  ('H3', 'Süleyman Kocabaş',   true)
ON CONFLICT (id) DO NOTHING;

-- RLS
ALTER TABLE public.hekimler ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "hekimler_all" ON public.hekimler;
CREATE POLICY "hekimler_all"
  ON public.hekimler FOR ALL
  USING (true) WITH CHECK (true);

-- ──────────────────────────────────────────────────────────────
-- 2. islem_log — payload jsonb kolonu ekle
--    tip (text) korunuyor — geriye uyumluluk için
--    payload = standart event envelope
-- ──────────────────────────────────────────────────────────────
ALTER TABLE public.islem_log
  ADD COLUMN IF NOT EXISTS payload jsonb;

-- payload standart formatı:
-- {
--   "event_type": "insemination_performed",   -- snake_case sabit
--   "entity_type": "animal",
--   "entity_id": "...",
--   "actor": "H1",                            -- hekim_id
--   "meta": { ...işleme özel alanlar... }
-- }

-- Mevcut kayıtlar için payload backfill (tip → event_type mapping)
UPDATE public.islem_log
SET payload = jsonb_build_object(
  'event_type', CASE tip
    WHEN 'DOGUM_KAYDI'     THEN 'birth_recorded'
    WHEN 'TOHUMLAMA'       THEN 'insemination_performed'
    WHEN 'HASTALIK_KAYDI'  THEN 'treatment_recorded'
    WHEN 'HAYVAN_EKLENDI'  THEN 'animal_registered'
    WHEN 'ABORT_KAYDI'     THEN 'abortion_recorded'
    WHEN 'KIZGINLIK'       THEN 'estrus_detected'
    WHEN 'OLUM_KAYDI'      THEN 'animal_died'
    WHEN 'SATIS_KAYDI'     THEN 'animal_sold'
    WHEN 'SUTTEN_KESME'    THEN 'weaning_performed'
    WHEN 'GOREV_TAMAMLA'   THEN 'task_completed'
    WHEN 'STOK_HAREKET'    THEN 'stock_movement'
    ELSE lower(tip)
  END,
  'entity_type', 'animal',
  'entity_id',   ana_hayvan_id,
  'meta',        snapshot
)
WHERE payload IS NULL;

-- ──────────────────────────────────────────────────────────────
-- 3. _islem_log_yaz trigger fonksiyonu — payload standartla
-- ──────────────────────────────────────────────────────────────
-- 4. HAYVAN_TIMELINE_VIEW
--    UI'a hazır: hayvan başına tüm eventler, tek sorguda
-- ──────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS public.hayvan_timeline_view;

CREATE VIEW public.hayvan_timeline_view AS
-- Doğum
SELECT
  d.anne_id                        AS hayvan_id,
  'DOGUM_KAYDI'                    AS tip,
  'birth_recorded'                 AS event_type,
  d.tarih::timestamptz             AS zaman,
  jsonb_build_object(
    'yavru_kupe', d.yavru_kupe,
    'yavru_cins', d.yavru_cins,
    'dogum_tipi', d.dogum_tipi,
    'dogum_kg',   d.dogum_kg,
    'hekim_id',   d.hekim_id
  )                                AS detay,
  d.id                             AS kaynak_id
FROM public.dogum d

UNION ALL

-- Tohumlama
SELECT
  t.hayvan_id,
  'TOHUMLAMA'                      AS tip,
  'insemination_performed'         AS event_type,
  t.tarih::timestamptz             AS zaman,
  jsonb_build_object(
    'sperma',      t.sperma,
    'sonuc',       t.sonuc,
    'deneme_no',   t.deneme_no,
    'hekim_id',    t.hekim_id
  )                                AS detay,
  t.id::text                       AS kaynak_id
FROM public.tohumlama t

UNION ALL

-- Hastalık
SELECT
  hl.hayvan_id,
  'HASTALIK_KAYDI'                 AS tip,
  'treatment_recorded'             AS event_type,
  hl.tarih::timestamptz            AS zaman,
  jsonb_build_object(
    'tani',      hl.tani,
    'kategori',  hl.kategori,
    'siddet',    hl.siddet,
    'durum',     hl.durum,
    'hekim_id',  hl.hekim_id
  )                                AS detay,
  hl.id                            AS kaynak_id
FROM public.hastalik_log hl

UNION ALL

-- Kızgınlık
SELECT
  kl.hayvan_id,
  'KIZGINLIK'                      AS tip,
  'estrus_detected'                AS event_type,
  kl.tarih::timestamptz            AS zaman,
  jsonb_build_object(
    'belirti', kl.belirti,
    'notlar',  kl.notlar
  )                                AS detay,
  kl.id                            AS kaynak_id
FROM public.kizginlik_log kl

UNION ALL

-- Hayvan eklendi / güncellendi (islem_log'dan)
SELECT
  il.ana_hayvan_id                 AS hayvan_id,
  il.tip,
  COALESCE(il.payload->>'event_type', lower(il.tip)) AS event_type,
  il.tarih                         AS zaman,
  COALESCE(il.payload->'meta', il.snapshot) AS detay,
  il.id                            AS kaynak_id
FROM public.islem_log il
WHERE il.tip IN ('HAYVAN_EKLENDI', 'ABORT_KAYDI', 'SATIS_KAYDI', 'OLUM_KAYDI', 'SUTTEN_KESME')

ORDER BY zaman DESC;

-- ──────────────────────────────────────────────────────────────
-- 5. TOHUMLAMA_KAYDET — validasyon + sperma stok fix
--    (009a'yı içerir, ayrıca hekim_ad parametresi eklendi)
-- ──────────────────────────────────────────────────────────────
-- 6. hekimler tablosuna RPC — frontend için
-- ──────────────────────────────────────────────────────────────
-- 7. pullTables için hekimler izni
-- ──────────────────────────────────────────────────────────────
GRANT SELECT ON public.hekimler TO anon, authenticated;
GRANT SELECT ON public.hayvan_timeline_view TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.hekim_listesi() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.hekim_ekle(text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tohumlama_kaydet(text, date, text, text, text, jsonb, boolean) TO anon, authenticated;
-- ═══════════════════════════════════════════════════════════════
-- Migration 010 — hayvan_guncelle RPC
-- Hayvan kartından bilgi/padok düzenleme
-- ═══════════════════════════════════════════════════════════════

-- updated_at kolonu yoksa ekle
ALTER TABLE public.hayvanlar
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

CREATE OR REPLACE FUNCTION public.hayvan_guncelle(
  p_id              text,
  p_kupe_no         text    DEFAULT NULL,
  p_devlet_kupe     text    DEFAULT NULL,
  p_irk             text    DEFAULT NULL,
  p_cinsiyet        text    DEFAULT NULL,
  p_dogum_tarihi    date    DEFAULT NULL,
  p_grup            text    DEFAULT NULL,
  p_padok           text    DEFAULT NULL,
  p_dogum_kg        numeric DEFAULT NULL,
  p_canli_agirlik   numeric DEFAULT NULL,
  p_boy             numeric DEFAULT NULL,
  p_renk            text    DEFAULT NULL,
  p_ayirici_ozellik text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_chk    jsonb;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hayvan bulunamadı: %', p_id;
  END IF;

  -- Küpe değişiyorsa çakışma kontrolü (kendi küpesini hariç tut)
  IF p_kupe_no IS NOT NULL AND p_kupe_no <> '' AND p_kupe_no <> COALESCE(v_hayvan.kupe_no,'') THEN
    IF EXISTS (SELECT 1 FROM public.hayvanlar WHERE kupe_no = p_kupe_no AND id <> p_id) THEN
      RAISE EXCEPTION 'İşletme küpesi zaten kayıtlı: %', p_kupe_no;
    END IF;
  END IF;

  IF p_devlet_kupe IS NOT NULL AND p_devlet_kupe <> '' AND p_devlet_kupe <> COALESCE(v_hayvan.devlet_kupe,'') THEN
    IF EXISTS (SELECT 1 FROM public.hayvanlar WHERE devlet_kupe = p_devlet_kupe AND id <> p_id) THEN
      RAISE EXCEPTION 'Devlet küpesi zaten kayıtlı: %', p_devlet_kupe;
    END IF;
  END IF;

  UPDATE public.hayvanlar SET
    kupe_no          = COALESCE(NULLIF(p_kupe_no,''),         kupe_no),
    devlet_kupe      = COALESCE(NULLIF(p_devlet_kupe,''),     devlet_kupe),
    irk              = COALESCE(NULLIF(p_irk,''),             irk),
    cinsiyet         = COALESCE(NULLIF(p_cinsiyet,''),        cinsiyet),
    dogum_tarihi     = COALESCE(p_dogum_tarihi,               dogum_tarihi),
    grup             = COALESCE(NULLIF(p_grup,''),            grup),
    padok            = COALESCE(NULLIF(p_padok,''),           padok),
    dogum_kg         = COALESCE(p_dogum_kg,                   dogum_kg),
    canli_agirlik    = COALESCE(p_canli_agirlik,              canli_agirlik),
    boy              = COALESCE(p_boy,                        boy),
    renk             = COALESCE(NULLIF(p_renk,''),            renk),
    ayirici_ozellik  = COALESCE(NULLIF(p_ayirici_ozellik,''), ayirici_ozellik),
    updated_at       = now()
  WHERE id = p_id;

  -- islem_log trigger otomatik yazacak (HAYVAN_GUNCELLENDI)

  RETURN jsonb_build_object('ok', true, 'hayvan_id', p_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.hayvan_guncelle(text,text,text,text,text,date,text,text,numeric,numeric,numeric,text,text) TO anon, authenticated;
-- ═══════════════════════════════════════════════════════════════
-- Migration 011 — hayvan_durum_view'a fiziksel alanlar ekle
-- canli_agirlik, boy, renk, ayirici_ozellik, dogum_kg, notlar
-- abort_sayisi, baba_bilgi
-- ═══════════════════════════════════════════════════════════════

CREATE TRIGGER trg_islem_hastalik
  AFTER INSERT ON public.hastalik_log
  FOR EACH ROW EXECUTE FUNCTION public._islem_log_yaz();
-- Migration 016 — islem_log ref_id/ref_tablo + hastalık yönetim RPC'leri
-- Supabase SQL Editor'dan çalıştır

-- ── 1. islem_log'a köprü kolonları ─────────────────────────────
ALTER TABLE public.islem_log
  ADD COLUMN IF NOT EXISTS ref_id    text,
  ADD COLUMN IF NOT EXISTS ref_tablo text;

-- Eski kayıtları snapshot'tan geriye doldur
UPDATE public.islem_log
SET
  ref_id    = snapshot->>'id',
  ref_tablo = CASE tip
    WHEN 'HASTALIK_KAYDI'   THEN 'hastalik_log'
    WHEN 'TOHUMLAMA'        THEN 'tohumlama'
    WHEN 'ABORT_KAYDI'      THEN 'tohumlama'
    WHEN 'DOGUM_KAYDI'      THEN 'dogum'
    WHEN 'HAYVAN_EKLENDI'   THEN 'hayvanlar'
    WHEN 'HAYVAN_GUNCELLENDI' THEN 'hayvanlar'
    WHEN 'KIZGINLIK'        THEN 'kizginlik_log'
    ELSE NULL
  END
WHERE ref_id IS NULL AND snapshot->>'id' IS NOT NULL;

CREATE TRIGGER trg_islem_hastalik
  AFTER INSERT OR UPDATE ON public.hastalik_log
  FOR EACH ROW EXECUTE FUNCTION public._islem_log_yaz();

-- ── 6. RLS & SECURITY DEFINER ───────────────────────────────────
ALTER FUNCTION public.hastalik_guncelle SECURITY DEFINER;
ALTER FUNCTION public.hastalik_kapat    SECURITY DEFINER;
ALTER FUNCTION public.hastalik_sil      SECURITY DEFINER;

NOTIFY pgrst, 'reload schema';
-- Migration 016b — hastalik RPC cast fix
CREATE OR REPLACE FUNCTION public.hastalik_kapat(
  p_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.hastalik_log SET
    durum          = 'Kapandi',
    kapanma_tarihi = CURRENT_DATE
  WHERE id::text = p_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Aktif kayit bulunamadi');
  END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;

NOTIFY pgrst, 'reload schema';
-- Migration 018 — hastalik_sil notlar→aciklama fix
NOTIFY pgrst, 'reload schema';
-- ══════════════════════════════════════════════════════════════
-- MIGRATION 019 — TEDAVİ TABLOSU YENİDEN TASARIM
-- EgeSüt ERP — 2026-03-12
--
-- Değişiklikler:
-- 1. tedavi tablosuna eksik kolonlar eklendi
--    (uygulama_yolu, hekim_id, uygulayan, bekleme_suresi_gun)
-- 2. stok.kategori standardize edildi (İlaç / Sperma / Malzeme / Yem)
-- 3. hastalik_kaydet RPC → ilaçları tedavi tablosuna yazar
-- 4. tedavi_ekle RPC → sonradan ilaç eklemek için
-- 5. tedavi_sil RPC → ilaç kaydı sil + stok_hareket iptal
-- 6. hastalik_guncelle RPC → p_ilaclar kaldırıldı (tedavi_ekle/sil kullanılacak)
-- 7. tedavi view → hastalık detayı için
-- 8. RLS politikaları
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- 1. TEDAVİ TABLOSUNA EKSİK KOLONLAR
-- ──────────────────────────────────────────────────────────────
ALTER TABLE public.tedavi
  ADD COLUMN IF NOT EXISTS uygulama_yolu    text,     -- IM, SC, IV, Oral, Topikal
  ADD COLUMN IF NOT EXISTS hekim_id         text,
  ADD COLUMN IF NOT EXISTS bekleme_suresi_gun integer, -- süt/et bekleme süresi (gün)
  ADD COLUMN IF NOT EXISTS notlar           text;

-- uygulama_yolu kısıtı (opsiyonel, esnek tutmak için CHECK yok)
COMMENT ON COLUMN public.tedavi.uygulama_yolu IS 'IM | SC | IV | Oral | Topikal | Intrauterin';
COMMENT ON COLUMN public.tedavi.bekleme_suresi_gun IS 'İlaç sonrası süt/et yasağı gün sayısı';

-- ──────────────────────────────────────────────────────────────
-- 2. STOK KATEGORİ COMMENT
-- ──────────────────────────────────────────────────────────────
COMMENT ON COLUMN public.stok.kategori IS 'İlaç | Sperma | Malzeme | Yem | Diğer';

-- ──────────────────────────────────────────────────────────────
-- 3. TEDAVİ VIEW — hastalık detay modalı için
-- ──────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS public.tedavi_view CASCADE;
CREATE OR REPLACE VIEW public.tedavi_view AS
SELECT
  t.id,
  t.hayvan_id,
  t.vaka_id,
  t.tarih,
  t.tani,
  t.miktar,
  t.uygulama_yolu,
  t.hekim_id,
  t.bekleme_suresi_gun,
  t.sut_yasagi_bitis,
  t.aktif,
  t.notlar,
  t.created_at,
  s.urun_adi   AS ilac_adi,
  s.birim      AS ilac_birim,
  s.kategori   AS ilac_kategori
FROM public.tedavi t
LEFT JOIN public.stok s ON s.id = t.ilac_stok_id;

-- ──────────────────────────────────────────────────────────────
-- 4. HASTALIK_KAYDET — ilaçları tedavi tablosuna yazar
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hastalik_kaydet(
  p_hayvan_id   text,
  p_tani        text,
  p_kategori    text    DEFAULT NULL,
  p_siddet      text    DEFAULT NULL,
  p_semptomlar  text    DEFAULT NULL,
  p_lokasyon    text    DEFAULT NULL,
  p_hekim_id    text    DEFAULT NULL,
  p_ilaclar     jsonb   DEFAULT '[]',
  p_tedavi_gun  integer DEFAULT 1
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan    record;
  v_hst_id    uuid := gen_random_uuid();
  v_bugun     date := CURRENT_DATE;
  v_ilac      jsonb;
  v_stok_id   text;
  v_miktar    numeric;
  v_yol       text;
  v_bekleme   integer;
  v_g         integer;
  v_ilac_ac   text := '';
  v_stok_rec  record;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  -- Hastalık (vaka) kaydı
  INSERT INTO public.hastalik_log (
    id, hayvan_id, tarih, kategori, tani, siddet, semptomlar,
    lokasyon, hekim_id, durum
  ) VALUES (
    v_hst_id, p_hayvan_id, v_bugun, p_kategori, p_tani, p_siddet, p_semptomlar,
    p_lokasyon, p_hekim_id, 'Aktif'
  );

  -- İlaçları tedavi tablosuna yaz + stok_hareket düş
  FOR v_ilac IN SELECT * FROM jsonb_array_elements(p_ilaclar)
  LOOP
    v_stok_id := v_ilac->>'stokId';
    v_miktar  := (v_ilac->>'mik')::numeric;
    v_yol     := v_ilac->>'uygulama_yolu';
    v_bekleme := (v_ilac->>'bekleme_suresi_gun')::integer;

    IF v_stok_id IS NOT NULL AND v_stok_id <> '' AND v_miktar > 0 THEN
      -- Stok adını bul
      SELECT * INTO v_stok_rec FROM public.stok WHERE id = v_stok_id;

      -- Tedavi kaydı
      INSERT INTO public.tedavi (
        hayvan_id, vaka_id, tarih, tani,
        ilac_stok_id, miktar, uygulama_yolu,
        hekim_id, bekleme_suresi_gun,
        sut_yasagi_bitis, aktif
      ) VALUES (
        p_hayvan_id, v_hst_id::text, v_bugun, p_tani,
        v_stok_id, v_miktar, v_yol,
        p_hekim_id, v_bekleme,
        CASE WHEN v_bekleme > 0 THEN v_bugun + v_bekleme ELSE NULL END,
        true
      );

      -- Stok hareketi
      INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
      VALUES (
        v_stok_id, 'Tedavi', v_miktar,
        p_tani || ' — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
        false
      );

      v_ilac_ac := v_ilac_ac || COALESCE(v_stok_rec.urun_adi, v_stok_id) || ' ' || v_miktar::text || ' ';
    END IF;
  END LOOP;

  -- Takip görevleri
  IF p_tedavi_gun > 1 AND jsonb_array_length(p_ilaclar) > 0 THEN
    FOR v_g IN 1..(p_tedavi_gun - 1) LOOP
      INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak)
      VALUES (
        gen_random_uuid(), p_hayvan_id, 'ILAC',
        'Tedavi ' || (v_g+1) || '. gün: ' || TRIM(v_ilac_ac),
        v_bugun + v_g, false, 'TEDAVI-' || v_hst_id::text
      );
    END LOOP;
  END IF;

  RETURN jsonb_build_object('ok', true, 'hastalik_id', v_hst_id);
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 5. TEDAVİ_EKLE — Mevcut vakaya ilaç ekle
-- ──────────────────────────────────────────────────────────────
-- 6. TEDAVİ_SİL — İlaç kaydını sil + stok_hareket iptal et
-- ──────────────────────────────────────────────────────────────
-- 7. HASTALIK_GUNCELLE — ilaç parametresi yok (tedavi_ekle/sil kullanılır)
-- ──────────────────────────────────────────────────────────────
-- 8. HASTALIK_SİL — tedavi kayıtlarını da temizle
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.hastalik_sil(
  p_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_ted record;
BEGIN
  -- Bağlı tedavilerin stok hareketlerini iptal et
  FOR v_ted IN SELECT * FROM public.tedavi WHERE vaka_id = p_id
  LOOP
    UPDATE public.stok_hareket
    SET iptal = true
    WHERE id = (
      SELECT id FROM public.stok_hareket
      WHERE stok_id = v_ted.ilac_stok_id
        AND tur = 'Tedavi'
        AND iptal = false
        AND miktar = v_ted.miktar
      ORDER BY created_at DESC
      LIMIT 1
    );
  END LOOP;

  -- Bağlı tedavileri sil
  DELETE FROM public.tedavi WHERE vaka_id = p_id;

  -- Takip görevlerini kapat
  UPDATE public.gorev_log SET
    tamamlandi = true,
    aciklama   = COALESCE(aciklama, '') || ' [Hastalık kaydı silindi]'
  WHERE kaynak = 'TEDAVI-' || p_id AND tamamlandi = false;

  -- Hastalık kaydını sil
  DELETE FROM public.hastalik_log WHERE id::text = p_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayıt bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 9. RLS POLİTİKALARI
-- ──────────────────────────────────────────────────────────────
ALTER TABLE public.tedavi ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tedavi_select ON public.tedavi;
DROP POLICY IF EXISTS tedavi_insert ON public.tedavi;
DROP POLICY IF EXISTS tedavi_update ON public.tedavi;
DROP POLICY IF EXISTS tedavi_delete ON public.tedavi;

CREATE POLICY tedavi_select ON public.tedavi FOR SELECT USING (true);
CREATE POLICY tedavi_insert ON public.tedavi FOR INSERT WITH CHECK (true);
CREATE POLICY tedavi_update ON public.tedavi FOR UPDATE USING (true);
CREATE POLICY tedavi_delete ON public.tedavi FOR DELETE USING (true);

-- SECURITY DEFINER
ALTER FUNCTION public.hastalik_kaydet  SECURITY DEFINER;
ALTER FUNCTION public.tedavi_ekle      SECURITY DEFINER;
ALTER FUNCTION public.tedavi_sil       SECURITY DEFINER;
ALTER FUNCTION public.hastalik_guncelle SECURITY DEFINER;
ALTER FUNCTION public.hastalik_sil     SECURITY DEFINER;

NOTIFY pgrst, 'reload schema';
-- Migration 020: hastalik_guncelle RPC'ye p_tarih parametresi ekle

-- Eski imzalı fonksiyonu drop et
DROP FUNCTION IF EXISTS public.hastalik_guncelle(text,text,text,text,text,text,text);

CREATE OR REPLACE FUNCTION public.hastalik_guncelle(
  p_id         text,
  p_tani       text    DEFAULT NULL,
  p_kategori   text    DEFAULT NULL,
  p_siddet     text    DEFAULT NULL,
  p_semptomlar text    DEFAULT NULL,
  p_lokasyon   text    DEFAULT NULL,
  p_hekim_id   text    DEFAULT NULL,
  p_tarih      date    DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.hastalik_log SET
    tani       = COALESCE(p_tani,       tani),
    kategori   = COALESCE(p_kategori,   kategori),
    siddet     = COALESCE(p_siddet,     siddet),
    semptomlar = COALESCE(p_semptomlar, semptomlar),
    lokasyon   = COALESCE(p_lokasyon,   lokasyon),
    hekim_id   = COALESCE(p_hekim_id,   hekim_id),
    tarih      = COALESCE(p_tarih,      tarih)
  WHERE id::text = p_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayıt bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;-- ══════════════════════════════════════════════════════════════
-- MIGRATION 021 — TEDAVİ GÜNCELLEME + STOK LEDGER DÜZELTMESİ
-- EgeSüt ERP — 2026-03-12
--
-- Değişiklikler:
-- 1. stok_hareket tablosuna referans_tipi + referans_id kolonları (audit trail)
-- 2. tedavi_ekle — stok_hareket'e referans bilgisi eklendi
-- 3. tedavi_sil — iptal=true yerine +miktar yeni hareket INSERT (ledger)
-- 4. tedavi_guncelle — fark hareketi INSERT eder, tedavi UPDATE eder
-- ══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────────────────────
-- 1. STOK_HAREKET — AUDIT KOLONLARI
-- ──────────────────────────────────────────────────────────────
ALTER TABLE public.stok_hareket
  ADD COLUMN IF NOT EXISTS referans_tipi text,   -- 'tedavi' | 'stok_girisi' | 'duzeltme' vb.
  ADD COLUMN IF NOT EXISTS referans_id   text;   -- ilgili kaydın id'si

COMMENT ON COLUMN public.stok_hareket.referans_tipi IS 'tedavi | stok_girisi | duzeltme | iade';
COMMENT ON COLUMN public.stok_hareket.referans_id   IS 'İlgili kaydın id değeri (tedavi.id vb.)';

-- ──────────────────────────────────────────────────────────────
-- 2. TEDAVİ_EKLE — referans bilgisi eklendi
-- ──────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.tedavi_ekle(text,text,text,numeric,text,integer,text,text);

CREATE OR REPLACE FUNCTION public.tedavi_ekle(
  p_vaka_id         text,
  p_hayvan_id       text,
  p_ilac_stok_id    text,
  p_miktar          numeric,
  p_uygulama_yolu   text    DEFAULT NULL,
  p_bekleme_gun     integer DEFAULT NULL,
  p_hekim_id        text    DEFAULT NULL,
  p_notlar          text    DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok      record;
  v_hayvan    record;
  v_bugun     date := CURRENT_DATE;
  v_tani      text;
  v_tedavi_id uuid := gen_random_uuid();
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = p_ilac_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok kalemi bulunamadı');
  END IF;

  IF v_stok.miktar < p_miktar THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Yetersiz stok: ' || COALESCE(v_stok.urun_adi,'?'));
  END IF;

  SELECT tani INTO v_tani FROM public.hastalik_log WHERE id::text = p_vaka_id;

  INSERT INTO public.tedavi (
    id, hayvan_id, vaka_id, tarih, tani,
    ilac_stok_id, miktar, uygulama_yolu,
    hekim_id, bekleme_suresi_gun,
    sut_yasagi_bitis, aktif, notlar
  ) VALUES (
    v_tedavi_id, p_hayvan_id, p_vaka_id, v_bugun, v_tani,
    p_ilac_stok_id, p_miktar, p_uygulama_yolu,
    p_hekim_id, p_bekleme_gun,
    CASE WHEN p_bekleme_gun > 0 THEN v_bugun + p_bekleme_gun ELSE NULL END,
    true, p_notlar
  );

  -- Stok hareketi — ledger kaydı (negatif = kullanım)
  INSERT INTO public.stok_hareket (
    id, stok_id, tur, miktar, notlar, iptal, referans_tipi, referans_id
  ) VALUES (
    gen_random_uuid(),
    p_ilac_stok_id,
    'Tedavi',
    -p_miktar,
    COALESCE(v_tani, 'Tedavi') || ' — ' || COALESCE(v_hayvan.kupe_no, p_hayvan_id),
    false,
    'tedavi',
    v_tedavi_id::text
  );

  -- Stok miktarını güncelle
  UPDATE public.stok SET miktar = miktar - p_miktar WHERE id = p_ilac_stok_id;

  RETURN jsonb_build_object('ok', true, 'tedavi_id', v_tedavi_id);
END;
$$;

ALTER FUNCTION public.tedavi_ekle SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────────
-- 3. TEDAVİ_SİL — ledger: +miktar yeni hareket, DELETE tedavi
-- ──────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.tedavi_sil(text);

CREATE OR REPLACE FUNCTION public.tedavi_sil(
  p_tedavi_id text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tedavi  record;
  v_stok    record;
BEGIN
  SELECT * INTO v_tedavi FROM public.tedavi WHERE id::text = p_tedavi_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tedavi kaydı bulunamadı');
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = v_tedavi.ilac_stok_id;

  -- Ledger: stok iadesi — yeni pozitif hareket ekle
  INSERT INTO public.stok_hareket (
    id, stok_id, tur, miktar, notlar, iptal, referans_tipi, referans_id
  ) VALUES (
    gen_random_uuid(),
    v_tedavi.ilac_stok_id,
    'Tedavi İptal',
    v_tedavi.miktar,   -- pozitif = iade
    'Tedavi silindi — ' || COALESCE(v_tedavi.tani, '?'),
    false,
    'tedavi_iptal',
    p_tedavi_id
  );

  -- Stok miktarını geri ekle
  UPDATE public.stok SET miktar = miktar + v_tedavi.miktar WHERE id = v_tedavi.ilac_stok_id;

  -- Tedavi kaydını sil
  DELETE FROM public.tedavi WHERE id::text = p_tedavi_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

ALTER FUNCTION public.tedavi_sil SECURITY DEFINER;

-- ──────────────────────────────────────────────────────────────
-- 4. TEDAVİ_GUNCELLE — fark hareketi + UPDATE
-- ──────────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.tedavi_guncelle(text,numeric,text,integer,text,text);

CREATE OR REPLACE FUNCTION public.tedavi_guncelle(
  p_tedavi_id       text,
  p_miktar          numeric  DEFAULT NULL,
  p_uygulama_yolu   text     DEFAULT NULL,
  p_bekleme_gun     integer  DEFAULT NULL,
  p_hekim_id        text     DEFAULT NULL,
  p_notlar          text     DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tedavi  record;
  v_stok    record;
  v_fark    numeric;
  v_yeni_miktar numeric;
BEGIN
  SELECT * INTO v_tedavi FROM public.tedavi WHERE id::text = p_tedavi_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tedavi kaydı bulunamadı');
  END IF;

  v_yeni_miktar := COALESCE(p_miktar, v_tedavi.miktar);
  v_fark := v_tedavi.miktar - v_yeni_miktar;  -- pozitif = stok geri döner, negatif = daha fazla kullanım

  IF v_fark <> 0 THEN
    SELECT * INTO v_stok FROM public.stok WHERE id = v_tedavi.ilac_stok_id;

    -- Yetersiz stok kontrolü (daha fazla kullanılacaksa)
    IF v_fark < 0 AND v_stok.miktar < ABS(v_fark) THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Yetersiz stok: ' || COALESCE(v_stok.urun_adi,'?'));
    END IF;

    -- Ledger: fark hareketi
    INSERT INTO public.stok_hareket (
      id, stok_id, tur, miktar, notlar, iptal, referans_tipi, referans_id
    ) VALUES (
      gen_random_uuid(),
      v_tedavi.ilac_stok_id,
      'Tedavi Düzeltme',
      v_fark,   -- pozitif = iade, negatif = ek kullanım
      'Tedavi güncellendi — ' || COALESCE(v_tedavi.tani, '?'),
      false,
      'tedavi_duzeltme',
      p_tedavi_id
    );

    -- Stok miktarını güncelle
    UPDATE public.stok SET miktar = miktar + v_fark WHERE id = v_tedavi.ilac_stok_id;
  END IF;

  -- Tedavi kaydını güncelle
  UPDATE public.tedavi SET
    miktar             = v_yeni_miktar,
    uygulama_yolu      = COALESCE(p_uygulama_yolu,  uygulama_yolu),
    bekleme_suresi_gun = COALESCE(p_bekleme_gun,     bekleme_suresi_gun),
    sut_yasagi_bitis   = CASE
                           WHEN p_bekleme_gun IS NOT NULL AND p_bekleme_gun > 0
                           THEN tarih + p_bekleme_gun
                           ELSE sut_yasagi_bitis
                         END,
    hekim_id           = COALESCE(p_hekim_id,        hekim_id),
    notlar             = COALESCE(p_notlar,           notlar)
  WHERE id::text = p_tedavi_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

ALTER FUNCTION public.tedavi_guncelle SECURITY DEFINER;

-- RLS
GRANT EXECUTE ON FUNCTION public.tedavi_ekle    TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tedavi_sil     TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tedavi_guncelle TO anon, authenticated;
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
-- 0. STOK_KATEGORİLERİ — Dinamik kategori tanımları
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.stok_kategorileri (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ad         text UNIQUE NOT NULL,
  sira       integer DEFAULT 0,
  tip        text NOT NULL DEFAULT 'genel',
  created_at timestamptz DEFAULT now()
);
COMMENT ON TABLE public.stok_kategorileri IS 'Stok kategori tanımları — tip: ilac|genel, Tanımlar panelinden yönetilir';
ALTER TABLE public.stok_kategorileri ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='stok_kategorileri' AND policyname='stok_kat_select') THEN
    CREATE POLICY stok_kat_select ON public.stok_kategorileri FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='stok_kategorileri' AND policyname='stok_kat_all') THEN
    CREATE POLICY stok_kat_all ON public.stok_kategorileri FOR ALL USING (true) WITH CHECK (true);
  END IF;
END $$;
INSERT INTO public.stok_kategorileri (ad, sira, tip) VALUES
  ('Antibiyotik',1,'ilac'),('NSAID',2,'ilac'),('Hormon',3,'ilac'),('Vitamin',4,'ilac'),
  ('Antiparaziter',5,'ilac'),('Diğer İlaç',6,'ilac'),('Aşı',7,'genel'),('Sperma',8,'genel'),
  ('Yem',9,'genel'),('Sarf',10,'genel'),('Ekipman',11,'genel'),('Diğer',12,'genel'),
  ('Tohumlama',13,'genel'),('Metabolik',14,'ilac'),('GI İlaçlar',15,'ilac'),
  ('Topikal',16,'ilac'),('Anestezik / Sedatif',17,'ilac')
ON CONFLICT (ad) DO NOTHING;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.stok_kategorileri TO anon, authenticated;

-- ──────────────────────────────────────────────────────────────
-- 0a. DRUG_CLASSES — Etken madde sınıflandırma (3-seviye: group → class → ingredient)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.drug_classes (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_name        text NOT NULL,
  class_name        text,
  active_ingredient text,
  kategori_id       uuid REFERENCES public.stok_kategorileri(id),
  created_at        timestamptz DEFAULT now(),
  CONSTRAINT uq_drug_classes_combo UNIQUE (group_name, class_name, active_ingredient)
);

COMMENT ON TABLE  public.drug_classes IS 'Veteriner farmakoloji etken madde sınıflandırması — group_name → class_name → active_ingredient';
COMMENT ON COLUMN public.drug_classes.kategori_id IS 'stok_kategorileri FK — otomatik kategori eşleme';

ALTER TABLE public.drug_classes ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='drug_classes' AND policyname='anon_read_drug_classes') THEN
    CREATE POLICY anon_read_drug_classes ON public.drug_classes FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='drug_classes' AND policyname='anon_insert_drug_classes') THEN
    CREATE POLICY anon_insert_drug_classes ON public.drug_classes FOR INSERT WITH CHECK (true);
  END IF;
END $$;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.drug_classes TO anon, authenticated;

-- ──────────────────────────────────────────────────────────────
-- 0b. DRUG_PRODUCTS — Ticari preparat (brand_name + drug_class_id FK)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.drug_products (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  drug_class_id      uuid NOT NULL REFERENCES public.drug_classes(id),
  brand_name         text NOT NULL,
  concentration      numeric,
  concentration_unit text,
  default_route      text,
  default_unit       text,
  created_at         timestamptz DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_drug_products_brand_class
  ON drug_products (LOWER(brand_name), drug_class_id);

COMMENT ON TABLE  public.drug_products IS 'Ticari ilaç preparatları — drug_classes FK ile sınıflandırılır';

ALTER TABLE public.drug_products ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='drug_products' AND policyname='anon_read_drug_products') THEN
    CREATE POLICY anon_read_drug_products ON public.drug_products FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='drug_products' AND policyname='anon_insert_drug_products') THEN
    CREATE POLICY anon_insert_drug_products ON public.drug_products FOR INSERT WITH CHECK (true);
  END IF;
END $$;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.drug_products TO anon, authenticated;

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
  kategori       text,
  created_at     timestamptz DEFAULT now()
);

COMMENT ON TABLE  public.drugs                IS 'Controlled ilaç listesi — free text yasak';
COMMENT ON COLUMN public.drugs.stock_item_id  IS 'stok.id FK — NULL ise stok düşümü yapılmaz';
COMMENT ON COLUMN public.drugs.default_route  IS 'IM | IV | SC | PO | Topikal | Intrauterin';
COMMENT ON COLUMN public.drugs.kategori       IS 'İlaç sınıfı — stok_kategorileri.ad (tip=ilac) ile eşleşir';

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
  plan_notu   text,
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

-- done tracking (migration 20260525000002)
ALTER TABLE public.treatment_days
  ADD COLUMN IF NOT EXISTS tamamlandi         boolean     DEFAULT false,
  ADD COLUMN IF NOT EXISTS tamamlanma_tarihi  timestamptz,
  ADD COLUMN IF NOT EXISTS tamamlanma_notu    text;

-- planned_time (migration 20260528000001)
ALTER TABLE public.treatment_days
  ADD COLUMN IF NOT EXISTS planned_time TIME;

-- ──────────────────────────────────────────────────────────────
-- 5. DRUG ADMINISTRATIONS — İlaç uygulama (controlled FK)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.drug_administrations (
  id                uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  treatment_day_id  uuid    NOT NULL REFERENCES public.treatment_days(id) ON DELETE CASCADE,
  stok_id           text    REFERENCES public.stok(id),
  drug_product_id   uuid    REFERENCES public.drug_products(id),
  dose              numeric NOT NULL CHECK (dose > 0),
  unit              text    NOT NULL,
  route             text,
  notes             text,
  uygulanmadi       boolean DEFAULT false,
  created_at        timestamptz DEFAULT now(),
  CONSTRAINT drug_administrations_route_check
    CHECK (route IS NULL OR route IN ('IM','IV','SC','PO','Topikal','Intrauterin'))
);

COMMENT ON TABLE  public.drug_administrations  IS 'İlaç uygulama — stok_id + drug_product_id FK (drug_id kaldırıldı)';
COMMENT ON COLUMN public.drug_administrations.route IS 'IM | IV | SC | PO | Topikal | Intrauterin';

CREATE INDEX IF NOT EXISTS drug_admin_day_id_idx ON public.drug_administrations(treatment_day_id);

-- ════════════════════════════════════════════════════════════════
-- BUG-059: SAAT-BAZLI SEANS YÖNETİMİ (Faz 1 — Schema)
-- Deployed: 2026-06-11 (migration 20260611000001_bug059_treatment_sessions.sql)
-- Spec: docs/superpowers/specs/2026-06-10-tedavi-saat-bazli-seans.md
-- ════════════════════════════════════════════════════════════════
-- 5a. YENİ TABLO: treatment_day_uygulamalar (seans bazlı detay)
CREATE TABLE IF NOT EXISTS public.treatment_day_uygulamalar (
  -- KİMLİK
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  treatment_day_id            uuid NOT NULL REFERENCES public.treatment_days(id) ON DELETE CASCADE,
  case_id                     uuid NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,

  -- SEANS BİLGİSİ (sira_no YOK — ORDER BY planned_time ile sıralama)
  planned_time                time NOT NULL,
  planned_date                date NOT NULL,

  -- İLAÇ (drug_administrations ile birebir aynı kolon kümesi)
  stok_id                     text REFERENCES public.stok(id),
  drug_product_id             uuid REFERENCES public.drug_products(id),
  dose                        numeric NOT NULL CHECK (dose > 0),
  unit                        text NOT NULL,
  route                       text CHECK (route IS NULL OR route IN ('IM','IV','SC','PO','Topikal','Intrauterin')),

  -- DONE STATE (seans seviyesi — Faz 0 stratejik karar)
  uygulama_tamamlandi_at      timestamptz,
  uygulayan                   text,
  uygulama_notu               text,
  gerceklesme_saati           time,
  uygulanmadi                 boolean DEFAULT false,
  iptal_nedeni                text,

  -- AUDIT
  created_at                  timestamptz DEFAULT now(),
  updated_at                  timestamptz DEFAULT now(),

  -- KISITLAR
  -- Aynı saatte farklı ilaçlar olabilir (Antibiyotik + Vitamin 08:00'de)
  -- Aynı ilaç aynı saatte eklenmesin (recete hatası)
  CONSTRAINT treatment_day_uygulamalar_unique_slot
    UNIQUE(treatment_day_id, planned_time, stok_id)
);

CREATE INDEX IF NOT EXISTS tdu_day_id_idx     ON public.treatment_day_uygulamalar(treatment_day_id);
CREATE INDEX IF NOT EXISTS tdu_case_date_idx  ON public.treatment_day_uygulamalar(case_id, planned_date);
CREATE INDEX IF NOT EXISTS tdu_open_idx       ON public.treatment_day_uygulamalar(treatment_day_id) WHERE uygulama_tamamlandi_at IS NULL;
CREATE INDEX IF NOT EXISTS tdu_late_idx       ON public.treatment_day_uygulamalar(planned_date, planned_time) WHERE uygulama_tamamlandi_at IS NULL;
CREATE INDEX IF NOT EXISTS da_seans_admin_id_idx ON public.drug_administrations(seans_admin_id);

-- 5b. treatment_days — seans_sayisi (geriye uyumlu NULL semantiği)
ALTER TABLE public.treatment_days
  ADD COLUMN IF NOT EXISTS seans_sayisi smallint
    CHECK (seans_sayisi IS NULL OR seans_sayisi > 0);

-- 5c. drug_administrations — seans_admin_id FK (yeni → eski köprüsü)
ALTER TABLE public.drug_administrations
  ADD COLUMN IF NOT EXISTS seans_admin_id uuid REFERENCES public.treatment_day_uygulamalar(id) ON DELETE SET NULL;

-- 5d. gorev_log — seans_admin_id + hedef_saat (görev bazlı seans takibi)
ALTER TABLE public.gorev_log
  ADD COLUMN IF NOT EXISTS seans_admin_id uuid REFERENCES public.treatment_day_uygulamalar(id) ON DELETE SET NULL;

ALTER TABLE public.gorev_log
  ADD COLUMN IF NOT EXISTS hedef_saat time;

COMMENT ON TABLE  public.treatment_day_uygulamalar
  IS 'Tedavi gunu alt seanslari. Saat + ilac + doz + yol, gercek zamanli zincir mimarisi. NULL seans = eski tek-seans davranis.';
COMMENT ON COLUMN public.treatment_day_uygulamalar.planned_time
  IS 'PLANLANAN saat (08:00, 16:00, 24:00). Sahada gerceklesen saat = gerceklesme_saati';
COMMENT ON COLUMN public.treatment_day_uygulamalar.gerceklesme_saati
  IS 'Sahada tamamlandigi saat (NOW()::time). planned_time ile karsilastirilip gec uyarisi verilir';
COMMENT ON COLUMN public.treatment_day_uygulamalar.uygulama_tamamlandi_at
  IS 'NULL = henuz yapilmadi, now() = yapildi';
COMMENT ON COLUMN public.treatment_day_uygulamalar.uygulayan
  IS 'Sahada uygulamayi yapan kisi (text — auth entegrasyonu Faz 5)';
COMMENT ON COLUMN public.treatment_day_uygulamalar.uygulanmadi
  IS 'true = "yapilmadi, stok iade". Stok_hareket.referans_tipi=tedavi_seans ile eslesir';
COMMENT ON COLUMN public.treatment_day_uygulamalar.iptal_nedeni
  IS 'uygulanmadi=true ise neden (recete degisikligi, hayvan olum, vs.)';
COMMENT ON COLUMN public.treatment_day_uygulamalar.planned_date
  IS 'Tedavi gununun tarihi (denormalize — case_id ile birlikte index)';
COMMENT ON COLUMN public.treatment_days.seans_sayisi
  IS 'Bu gunku planlanan seans sayisi. NULL = eski tek-seans (geriye uyumlu, default yok). N >= 1 = yeni coklu-seans';
COMMENT ON COLUMN public.drug_administrations.seans_admin_id
  IS 'Yeni: baglantili treatment_day_uygulamalar.id. NULL = eski tek-seans davranis (geriye uyumlu)';
COMMENT ON COLUMN public.gorev_log.seans_admin_id
  IS 'Gorev bazli seans takibi (Faz 5) — hangi seans icin gorev';
COMMENT ON COLUMN public.gorev_log.hedef_saat
  IS 'Gorev icin hedef saat (time) — gun icinde zamanlama';

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
-- 7. TRIGGER: drug_administration → stok_hareket (KALDIRILDI)
--
-- stok hareketi artık RPC içinde yapılıyor:
--   add_drug_administration() → kendisi INSERT INTO stok_hareket
--   delete_treatment_day()    → UPDATE stok_hareket SET iptal=true
--   geri_al()                 → UPDATE stok_hareket SET iptal=true
-- Trigger kaldırıldı çünkü drug_id kolonu yok (stok_id + drug_product_id kullanılıyor)
-- ──────────────────────────────────────────────────────────────
-- Trigger kaldırıldı: stok hareketi add_drug_administration RPC içinde yapılıyor
CREATE OR REPLACE FUNCTION public.drug_administration_stok_dusum()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- This trigger is disabled. Stock ledger is handled by RPC.
  RETURN NEW;
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- 8. VIEW: treatment_timeline
-- ──────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS public.treatment_timeline CASCADE;
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

  -- islem_log: geri alma icin snapshot
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    'VAKA_ACILDI',
    p_animal_id,
    v_new_id::text,
    'cases',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'cases', 'id', v_new_id::text)
      ),
      'guncellenen', '[]'::jsonb
    )
  );

  RETURN jsonb_build_object('ok', true, 'case_id', v_new_id);
END;
$$;

-- Kızgınlık bağlamından vaka açma RPC (Plan-B)
CREATE OR REPLACE FUNCTION public.kizginlik_vaka_ac(
  p_kizginlik_id   text,
  p_tani           text,
  p_tohumlama_id   text    DEFAULT NULL,
  p_notlar         text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_kiz       record;
  v_case_id   uuid;
  v_disease   record;
BEGIN
  SELECT * INTO v_kiz FROM public.kizginlik_log WHERE id = p_kizginlik_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kızgınlık kaydı bulunamadı');
  END IF;

  -- Hastalık adından disease_id bul (case-insensitive)
  SELECT * INTO v_disease FROM public.diseases
  WHERE name ILIKE p_tani OR p_tani ILIKE '%' || name || '%'
  ORDER BY length(name) DESC
  LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO public.diseases (name, category)
    VALUES (p_tani, 'Üreme')
    RETURNING * INTO v_disease;
  END IF;

  INSERT INTO public.cases (animal_id, disease_id, start_date, status, notes, created_at)
  VALUES (
    v_kiz.hayvan_id,
    v_disease.id,
    CURRENT_DATE,
    'active',
    COALESCE(p_notlar, 'Tohumlama sırasında tespit edildi'),
    now()
  )
  RETURNING id INTO v_case_id;

  UPDATE public.kizginlik_log
  SET tedavi_case_id = v_case_id
  WHERE id = p_kizginlik_id;

  IF p_tohumlama_id IS NOT NULL AND p_tohumlama_id <> '' THEN
    UPDATE public.tohumlama
    SET case_id = v_case_id
    WHERE id = p_tohumlama_id;
  END IF;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    'KIZGINLIK_VAKA_ACILDI',
    v_kiz.hayvan_id,
    p_kizginlik_id,
    'kizginlik_log',
    jsonb_build_object(
      'case_id', v_case_id,
      'tani', p_tani,
      'kizginlik_id', p_kizginlik_id,
      'tohumlama_id', p_tohumlama_id
    )
  );

  RETURN jsonb_build_object('ok', true, 'case_id', v_case_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.kizginlik_vaka_ac(text, text, text, text) TO anon, authenticated;

-- 9b. add_treatment_day
DROP FUNCTION IF EXISTS public.add_treatment_day(uuid, date);
DROP FUNCTION IF EXISTS public.add_treatment_day(uuid, date, time);
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

-- 9e. treatment_day_tamamla
DROP FUNCTION IF EXISTS public.treatment_day_tamamla(uuid, text);
DROP FUNCTION IF EXISTS public.treatment_day_tamamla(uuid, text, uuid[]);
CREATE OR REPLACE FUNCTION public.add_treatment_day_with_sessions(
  p_case_id            uuid,
  p_date               date,
  p_sessions           jsonb DEFAULT NULL,
  p_existing_day_id    uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_day_id         uuid;
  v_gorev_id       uuid;
  v_prev_gorev_id  uuid := NULL;
  v_day_no         int;
  v_case           record;
  v_gecmis         boolean;
  v_session        jsonb;
  v_seans_sayisi   smallint;
  v_admin_ids      uuid[] := '{}';
  v_admin_id       uuid;
  v_first_time     time;
  v_is_update      boolean := false;
  v_drug_admin_id  uuid;
  v_stok_id        text;
  v_stok_hareket_id text;
BEGIN
  v_is_update := p_existing_day_id IS NOT NULL;

  -- Day no: yeni gun ise MAX+1, mevcut gun ise mevcut day_no
  IF v_is_update THEN
    SELECT day_no INTO v_day_no
    FROM public.treatment_days
    WHERE id = p_existing_day_id AND case_id = p_case_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Mevcut gun bulunamadi');
    END IF;
  ELSE
    SELECT COALESCE(MAX(day_no), 0) + 1 INTO v_day_no
    FROM public.treatment_days WHERE case_id = p_case_id;
  END IF;

  -- Case
  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadi');
  END IF;
  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapali vakaya gun eklenemez');
  END IF;

  v_gecmis := p_date < CURRENT_DATE;

  -- Onceki gun varsa parent_id
  IF v_day_no > 1 THEN
    SELECT g.id INTO v_prev_gorev_id
    FROM public.gorev_log g
    JOIN public.treatment_days td ON (g.aciklama::jsonb->>'day_id')::uuid = td.id
    WHERE td.case_id = p_case_id AND td.day_no = v_day_no - 1 AND g.gorev_tipi = 'TEDAVI_GUN'
    LIMIT 1;
  END IF;

  -- YENI: seans sayisi
  v_seans_sayisi := CASE WHEN p_sessions IS NULL THEN NULL ELSE jsonb_array_length(p_sessions)::smallint END;
  v_first_time   := CASE 
    WHEN p_sessions IS NULL THEN NULL
    ELSE (p_sessions->0->>'planned_time')::time
  END;

  -- Day INSERT veya UPDATE
  IF v_is_update THEN
    -- ONCE eski alt verileri temizle (drug_admins, seanslar, gorevler, stok iade)
    UPDATE public.stok_hareket sh
    SET iptal = true
    FROM public.drug_administrations da
    WHERE da.treatment_day_id = p_existing_day_id
      AND sh.notlar = 'drug_admin:' || da.id::text
      AND sh.iptal = false;

    DELETE FROM public.drug_administrations WHERE treatment_day_id = p_existing_day_id;
    DELETE FROM public.treatment_day_uygulamalar WHERE treatment_day_id = p_existing_day_id;
    DELETE FROM public.gorev_log
    WHERE gorev_tipi = 'TEDAVI_SEANS'
      AND (aciklama::jsonb->>'day_id')::uuid = p_existing_day_id;

    -- Mevcut gunu guncelle
    UPDATE public.treatment_days
    SET planned_time = v_first_time,
        seans_sayisi = v_seans_sayisi,
        treatment_date = p_date
    WHERE id = p_existing_day_id
    RETURNING id INTO v_day_id;

    -- Mevcut TEDAVI_GUN gorevini yeniden ac
    UPDATE public.gorev_log
    SET tamamlandi = false,
        tamamlanma_tarihi = NULL,
        aciklama = jsonb_build_object(
          'day_id', v_day_id, 'gun_no', v_day_no,
          'label', 'Gun ' || v_day_no || ' tedavisi - ' || to_char(p_date, 'DD.MM.YYYY'),
          'planned_time', COALESCE(v_first_time::text, ''),
          'seans_sayisi', v_seans_sayisi,
          'recete_guncellendi', true
        )::text
    WHERE gorev_tipi = 'TEDAVI_GUN'
      AND (aciklama::jsonb->>'day_id')::uuid = v_day_id
    RETURNING id INTO v_gorev_id;
  ELSE
    INSERT INTO public.treatment_days(
      id, case_id, day_no, treatment_date, tamamlandi,
      tamamlanma_tarihi, planned_time, seans_sayisi
    )
    VALUES (
      gen_random_uuid(), p_case_id, v_day_no, p_date,
      v_gecmis, CASE WHEN v_gecmis THEN p_date::timestamptz ELSE NULL END,
      v_first_time, v_seans_sayisi
    )
    RETURNING id INTO v_day_id;
  END IF;

  -- Ana TEDAVI_GUN gorev
  IF NOT v_is_update THEN
    INSERT INTO public.gorev_log(
      id, gorev_tipi, hayvan_id, hedef_tarih, aciklama,
      tamamlandi, tamamlanma_tarihi, parent_id
    )
    VALUES (
      gen_random_uuid(), 'TEDAVI_GUN', v_case.animal_id, p_date,
      jsonb_build_object(
        'day_id', v_day_id, 'gun_no', v_day_no,
        'label', 'Gun ' || v_day_no || ' tedavisi - ' || to_char(p_date, 'DD.MM.YYYY'),
        'planned_time', COALESCE(v_first_time::text, ''),
        'seans_sayisi', v_seans_sayisi
      )::text,
      v_gecmis, CASE WHEN v_gecmis THEN p_date::timestamptz ELSE NULL END,
      v_prev_gorev_id
    )
    RETURNING id INTO v_gorev_id;
  END IF;

  -- YENI: N seans dongusu
  IF p_sessions IS NOT NULL THEN
    FOR v_session IN SELECT * FROM jsonb_array_elements(p_sessions)
    LOOP
      -- treatment_day_uygulamalar INSERT (sira_no YOK, planned_time ile siralama)
      INSERT INTO public.treatment_day_uygulamalar(
        treatment_day_id, case_id, planned_time, planned_date,
        stok_id, drug_product_id, dose, unit, route
      )
      VALUES (
        v_day_id, p_case_id,
        (v_session->>'planned_time')::time, p_date,
        v_session->>'stok_id',
        (v_session->>'drug_product_id')::uuid,
        (v_session->>'dose')::numeric,
        v_session->>'unit',
        v_session->>'route'
      )
      RETURNING id INTO v_admin_id;

      v_admin_ids := array_append(v_admin_ids, v_admin_id);

      -- drug_administrations INSERT
      INSERT INTO public.drug_administrations(
        treatment_day_id, stok_id, drug_product_id, dose, unit, route,
        seans_admin_id
      )
      VALUES (
        v_day_id,
        v_session->>'stok_id',
        (v_session->>'drug_product_id')::uuid,
        (v_session->>'dose')::numeric,
        v_session->>'unit',
        v_session->>'route',
        v_admin_id
      )
      RETURNING id INTO v_drug_admin_id;

      -- Stok INSERT (drug_admin_id ile birebir izlenebilir)
      v_stok_id := v_session->>'stok_id';
      IF v_stok_id IS NOT NULL AND (v_session->>'dose')::numeric > 0 THEN
        INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar)
        VALUES (v_stok_id, 'Tedavi', (v_session->>'dose')::numeric,
                'drug_admin:' || v_drug_admin_id::text)
        RETURNING id INTO v_stok_hareket_id;
        -- Not: stok_hareket_ref kolonu Faz 1'de yok, stok iade drug_admins.notlar pattern'i ile yapilir
      END IF;

      -- Her seans icin ayri TEDAVI_SEANS gorev
      INSERT INTO public.gorev_log(
        id, gorev_tipi, hayvan_id, hedef_tarih, hedef_saat,
        aciklama, tamamlandi, parent_id, seans_admin_id
      )
      VALUES (
        gen_random_uuid(), 'TEDAVI_SEANS', v_case.animal_id, p_date,
        (v_session->>'planned_time')::time,
        jsonb_build_object(
          'day_id', v_day_id,
          'planned_time', v_session->>'planned_time',
          'label', 'Gun ' || v_day_no || ' - Seans (' || (v_session->>'planned_time') || ')',
          'admin_id', v_admin_id
        )::text,
        false, v_gorev_id, v_admin_id
      );
    END LOOP;
  END IF;

  -- Audit
  INSERT INTO public.islem_log(id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    CASE WHEN v_is_update THEN 'RECETE_GUNCELLENDI' ELSE 'TEDAVI_GUN_EKLENDI' END,
    v_case.animal_id,
    v_day_id::text, 'treatment_days',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(
        jsonb_build_object('tablo', 'treatment_days', 'id', v_day_id::text),
        jsonb_build_object('tablo', 'gorev_log', 'id', v_gorev_id)
      ) || COALESCE((
        SELECT jsonb_agg(jsonb_build_object('tablo', 'treatment_day_uygulamalar', 'id', id::text))
        FROM unnest(v_admin_ids) AS id
      ), '[]'::jsonb),
      'seans_sayisi', v_seans_sayisi,
      'guncellenen', '[]'::jsonb
    )
  );

  RETURN jsonb_build_object(
    'ok', true, 'day_id', v_day_id, 'day_no', v_day_no,
    'seans_sayisi', v_seans_sayisi, 'admin_ids', v_admin_ids,
    'gorev_id', v_gorev_id, 'gecmis', v_gecmis
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_treatment_day_with_sessions TO anon, authenticated;

-- RPC 1b: add_sessions_to_existing_day — mevcut güne incremental seans ekle (done seansları bozmaz)
-- Migration: 20260613000004_seans_incremental_edit.sql
CREATE OR REPLACE FUNCTION public.add_sessions_to_existing_day(
  p_day_id    uuid,
  p_sessions  jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_day            record;
  v_case           record;
  v_gorev_id       uuid;
  v_day_no         int;
  v_session        jsonb;
  v_admin_id       uuid;
  v_drug_admin_id  uuid;
  v_stok_id        text;
  v_added          int := 0;
  v_admin_ids      uuid[] := '{}';
BEGIN
  SELECT * INTO v_day FROM public.treatment_days WHERE id = p_day_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tedavi günü bulunamadı');
  END IF;

  SELECT * INTO v_case FROM public.cases WHERE id = v_day.case_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadı');
  END IF;
  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakaya seans eklenemez');
  END IF;
  IF p_sessions IS NULL OR jsonb_array_length(p_sessions) = 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Seans verisi boş');
  END IF;

  v_day_no := v_day.day_no;

  SELECT id INTO v_gorev_id FROM public.gorev_log
  WHERE gorev_tipi = 'TEDAVI_GUN'
    AND (aciklama::jsonb->>'day_id')::uuid = p_day_id
  LIMIT 1;

  UPDATE public.gorev_log
  SET tamamlandi = false, tamamlanma_tarihi = NULL
  WHERE id = v_gorev_id AND tamamlandi = true;

  UPDATE public.treatment_days
  SET tamamlandi = false, tamamlanma_tarihi = NULL
  WHERE id = p_day_id AND tamamlandi = true;

  FOR v_session IN SELECT * FROM jsonb_array_elements(p_sessions)
  LOOP
    INSERT INTO public.treatment_day_uygulamalar(
      treatment_day_id, case_id, planned_time, planned_date,
      stok_id, drug_product_id, dose, unit, route
    )
    VALUES (
      p_day_id, v_day.case_id,
      (v_session->>'planned_time')::time, v_day.treatment_date,
      v_session->>'stok_id',
      (v_session->>'drug_product_id')::uuid,
      (v_session->>'dose')::numeric,
      v_session->>'unit',
      v_session->>'route'
    )
    RETURNING id INTO v_admin_id;

    v_admin_ids := array_append(v_admin_ids, v_admin_id);

    INSERT INTO public.drug_administrations(
      treatment_day_id, stok_id, drug_product_id, dose, unit, route, seans_admin_id
    )
    VALUES (
      p_day_id,
      v_session->>'stok_id',
      (v_session->>'drug_product_id')::uuid,
      (v_session->>'dose')::numeric,
      v_session->>'unit',
      v_session->>'route',
      v_admin_id
    )
    RETURNING id INTO v_drug_admin_id;

    v_stok_id := v_session->>'stok_id';
    IF v_stok_id IS NOT NULL AND (v_session->>'dose')::numeric > 0 THEN
      INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar)
      VALUES (v_stok_id, 'Tedavi', (v_session->>'dose')::numeric,
              'drug_admin:' || v_drug_admin_id::text);
    END IF;

    INSERT INTO public.gorev_log(
      id, gorev_tipi, hayvan_id, hedef_tarih, hedef_saat,
      aciklama, tamamlandi, parent_id, seans_admin_id
    )
    VALUES (
      gen_random_uuid(), 'TEDAVI_SEANS', v_case.animal_id, v_day.treatment_date,
      (v_session->>'planned_time')::time,
      jsonb_build_object(
        'day_id', p_day_id,
        'planned_time', v_session->>'planned_time',
        'label', 'Gun ' || v_day_no || ' - Seans (' || (v_session->>'planned_time') || ')',
        'admin_id', v_admin_id
      )::text,
      false, v_gorev_id, v_admin_id
    );

    v_added := v_added + 1;
  END LOOP;

  UPDATE public.treatment_days td
  SET seans_sayisi = (SELECT count(*) FROM public.treatment_day_uygulamalar WHERE treatment_day_id = p_day_id),
      planned_time = (SELECT min(planned_time) FROM public.treatment_day_uygulamalar WHERE treatment_day_id = p_day_id)
  WHERE td.id = p_day_id;

  INSERT INTO public.islem_log(id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text, 'SEANS_EKLENDI', v_case.animal_id,
    p_day_id::text, 'treatment_days',
    jsonb_build_object(
      'eklenen_seans', v_added,
      'olusturulan', COALESCE((
        SELECT jsonb_agg(jsonb_build_object('tablo', 'treatment_day_uygulamalar', 'id', id::text))
        FROM unnest(v_admin_ids) AS id), '[]'::jsonb)
    )
  );

  RETURN jsonb_build_object('ok', true, 'day_id', p_day_id, 'eklenen', v_added, 'admin_ids', v_admin_ids);
EXCEPTION WHEN unique_violation THEN
  -- treatment_day_uygulamalar(treatment_day_id, planned_time, stok_id) UNIQUE
  RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu saatte aynı ilaç zaten ekli — farklı saat ya da ilaç seçin');
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_sessions_to_existing_day(uuid, jsonb) TO anon, authenticated;

-- RPC 1c: remove_treatment_session — gerçekleşmemiş tekil seans sil + stok iade
-- Migration: 20260613000004_seans_incremental_edit.sql
CREATE OR REPLACE FUNCTION public.remove_treatment_session(
  p_seans_id  uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_seans   record;
  v_animal  text;   -- animal_id bu ERP'de text (küpe ID), uuid DEĞİL
BEGIN
  SELECT * INTO v_seans FROM public.treatment_day_uygulamalar WHERE id = p_seans_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Seans bulunamadı');
  END IF;
  IF v_seans.uygulama_tamamlandi_at IS NOT NULL OR v_seans.uygulanmadi = true THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tamamlanmış/iptal seans silinemez');
  END IF;

  SELECT animal_id INTO v_animal FROM public.cases WHERE id = v_seans.case_id;

  UPDATE public.stok_hareket sh
  SET iptal = true
  FROM public.drug_administrations da
  WHERE da.seans_admin_id = p_seans_id
    AND sh.notlar = 'drug_admin:' || da.id::text
    AND sh.iptal = false;

  DELETE FROM public.drug_administrations WHERE seans_admin_id = p_seans_id;
  DELETE FROM public.gorev_log WHERE gorev_tipi = 'TEDAVI_SEANS' AND seans_admin_id = p_seans_id;
  DELETE FROM public.treatment_day_uygulamalar WHERE id = p_seans_id;

  -- seans_sayisi check constraint: 0 yasak → son seans silinince NULL; planned_time'ı kalan en erken seansa çek
  UPDATE public.treatment_days
  SET seans_sayisi = NULLIF((SELECT count(*) FROM public.treatment_day_uygulamalar WHERE treatment_day_id = v_seans.treatment_day_id), 0),
      planned_time = (SELECT min(planned_time) FROM public.treatment_day_uygulamalar WHERE treatment_day_id = v_seans.treatment_day_id)
  WHERE id = v_seans.treatment_day_id;

  INSERT INTO public.islem_log(id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text, 'SEANS_SILINDI', v_animal,
    p_seans_id::text, 'treatment_day_uygulamalar',
    jsonb_build_object('day_id', v_seans.treatment_day_id::text, 'stok_id', v_seans.stok_id)
  );

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.remove_treatment_session(uuid) TO anon, authenticated;

-- RPC 1d: update_treatment_session — gerçekleşmemiş seansı düzenle (doz/birim/yol/saat) + stok farkı
-- Migration: 20260613000004_seans_incremental_edit.sql
CREATE OR REPLACE FUNCTION public.update_treatment_session(
  p_seans_id      uuid,
  p_dose          numeric,
  p_unit          text,
  p_route         text,
  p_planned_time  text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_seans   record;
  v_animal  text;
  v_time    time := (p_planned_time)::time;
BEGIN
  SELECT * INTO v_seans FROM public.treatment_day_uygulamalar WHERE id = p_seans_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Seans bulunamadı');
  END IF;
  IF v_seans.uygulama_tamamlandi_at IS NOT NULL OR v_seans.uygulanmadi = true THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tamamlanmış/iptal seans düzenlenemez');
  END IF;
  IF p_dose IS NULL OR p_dose <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçerli doz girin');
  END IF;

  SELECT animal_id INTO v_animal FROM public.cases WHERE id = v_seans.case_id;

  UPDATE public.treatment_day_uygulamalar
  SET planned_time = v_time, dose = p_dose, unit = p_unit, route = p_route, updated_at = now()
  WHERE id = p_seans_id;

  UPDATE public.stok_hareket sh
  SET iptal = true
  FROM public.drug_administrations da
  WHERE da.seans_admin_id = p_seans_id
    AND sh.notlar = 'drug_admin:' || da.id::text
    AND sh.iptal = false;

  UPDATE public.drug_administrations
  SET dose = p_dose, unit = p_unit, route = p_route
  WHERE seans_admin_id = p_seans_id;

  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar)
  SELECT da.stok_id, 'Tedavi', p_dose, 'drug_admin:' || da.id::text
  FROM public.drug_administrations da
  WHERE da.seans_admin_id = p_seans_id AND da.stok_id IS NOT NULL AND p_dose > 0;

  UPDATE public.gorev_log
  SET hedef_saat = v_time,
      aciklama = (aciklama::jsonb || jsonb_build_object('planned_time', p_planned_time))::text
  WHERE gorev_tipi = 'TEDAVI_SEANS' AND seans_admin_id = p_seans_id;

  UPDATE public.treatment_days
  SET planned_time = (SELECT min(planned_time) FROM public.treatment_day_uygulamalar WHERE treatment_day_id = v_seans.treatment_day_id)
  WHERE id = v_seans.treatment_day_id;

  INSERT INTO public.islem_log(id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text, 'SEANS_GUNCELLENDI', v_animal,
    p_seans_id::text, 'treatment_day_uygulamalar',
    jsonb_build_object('dose', p_dose, 'unit', p_unit, 'route', p_route, 'planned_time', p_planned_time)
  );

  RETURN jsonb_build_object('ok', true);
EXCEPTION WHEN unique_violation THEN
  RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu saatte aynı ilaç zaten ekli — farklı saat seçin');
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_treatment_session(uuid, numeric, text, text, text) TO anon, authenticated;

-- RPC 2: seans_tamamla
-- Spec: L596-714
-- Yapilan seansi kapat. Race condition guard (SELECT FOR UPDATE).
-- p_uygulanmadi=true ise stok iade de yapar (drug_admins.notlar pattern, stok_hareket_ref YOK)
DROP FUNCTION IF EXISTS public.seans_tamamla(uuid, boolean, text);
CREATE OR REPLACE FUNCTION public.seans_tamamla(
  p_seans_admin_id  uuid,
  p_uygulanmadi     boolean DEFAULT false,
  p_not             text    DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_seans      public.treatment_day_uygulamalar%ROWTYPE;
  v_all_done   boolean;
  v_total      int;
  v_done       int;
  v_tip        text;
BEGIN
  -- RACE CONDITION GUARD
  SELECT * INTO v_seans FROM public.treatment_day_uygulamalar
  WHERE id = p_seans_admin_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Seans bulunamadi');
  END IF;
  IF v_seans.uygulama_tamamlandi_at IS NOT NULL OR v_seans.uygulanmadi THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu seans zaten kapatilmis', 'race', true);
  END IF;

  IF p_uygulanmadi THEN
    -- Seans tablosunu isaretle
    UPDATE public.treatment_day_uygulamalar
    SET uygulanmadi = true, iptal_nedeni = p_not, updated_at = now()
    WHERE id = p_seans_admin_id
      AND uygulama_tamamlandi_at IS NULL
      AND uygulanmadi = false;

    -- drug_admins senkron
    UPDATE public.drug_administrations
    SET uygulanmadi = true
    WHERE seans_admin_id = p_seans_admin_id
      AND uygulanmadi IS DISTINCT FROM true;

    -- Stok iade: stok_hareket_ref kolonu Faz 1'de yok.
    -- Bunun yerine drug_admins.notlar pattern'i ile bul:
    UPDATE public.stok_hareket sh
    SET iptal = true
    FROM public.drug_administrations da
    WHERE da.seans_admin_id = p_seans_admin_id
      AND sh.notlar = 'drug_admin:' || da.id::text
      AND sh.iptal = false;
    v_tip := 'TEDAVI_SEANS_IPTAL';
  ELSE
    -- Seans tamamlandi
    UPDATE public.treatment_day_uygulamalar
    SET uygulama_tamamlandi_at = now(),
        uygulama_notu = p_not,
        gerceklesme_saati = NOW()::time,
        updated_at = now()
    WHERE id = p_seans_admin_id
      AND uygulama_tamamlandi_at IS NULL
      AND uygulanmadi = false;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu seans baska biri tarafindan kapatilmis', 'race', true);
    END IF;
    v_tip := 'TEDAVI_SEANS_TAMAM';
  END IF;

  -- Gorev log kapat
  UPDATE public.gorev_log
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE seans_admin_id = p_seans_admin_id AND tamamlandi = false;

  -- Tum seanslar done mi?
  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE uygulama_tamamlandi_at IS NOT NULL OR uygulanmadi = true)
  INTO v_total, v_done
  FROM public.treatment_day_uygulamalar
  WHERE treatment_day_id = v_seans.treatment_day_id;

  v_all_done := (v_total = v_done);

  IF v_all_done THEN
    -- Gun seviyesi tamamlandi
    UPDATE public.treatment_days
    SET tamamlandi = true,
        tamamlanma_tarihi = now()
    WHERE id = v_seans.treatment_day_id AND tamamlandi = false;

    UPDATE public.gorev_log
    SET tamamlandi = true, tamamlanma_tarihi = now()
    WHERE gorev_tipi = 'TEDAVI_GUN'
      AND tamamlandi = false
      AND (aciklama::jsonb->>'day_id')::uuid = v_seans.treatment_day_id;
  END IF;

  -- Audit
  INSERT INTO public.islem_log(id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text, v_tip,
    (SELECT animal_id FROM public.cases WHERE id = v_seans.case_id),
    p_seans_admin_id::text, 'treatment_day_uygulamalar',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object('tablo', 'treatment_day_uygulamalar', 'id', p_seans_admin_id::text)
      ),
      'gun_tamam', v_all_done
    )
  );

  RETURN jsonb_build_object('ok', true, 'seans_done', true, 'gun_tamam', v_all_done);
END;
$$;

GRANT EXECUTE ON FUNCTION public.seans_tamamla TO anon, authenticated;

-- RPC 3: recete_guncelle
-- Spec: L718-800
-- Reçete değişikliği. Yapılmamış günlere yeni reçete, kısmen yapılmış günlere DOKUNMAZ
DROP FUNCTION IF EXISTS public.recete_guncelle(uuid, jsonb);
CREATE OR REPLACE FUNCTION public.recete_guncelle(
  p_case_id     uuid,
  p_yeni_plan   jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_day_plan      jsonb;
  v_day_no        int;
  v_day_id        uuid;
  v_total_seans   int := 0;
  v_tamam         boolean;
  v_kismen_acik   boolean;
BEGIN
  -- Case kontrol
  IF NOT EXISTS (SELECT 1 FROM public.cases WHERE id = p_case_id AND status = 'active') THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Aktif vaka bulunamadi');
  END IF;

  FOR v_day_plan IN SELECT * FROM jsonb_array_elements(p_yeni_plan)
  LOOP
    v_day_no := (v_day_plan->>'day_no')::int;

    -- Bu gun var mi?
    SELECT id, tamamlandi INTO v_day_id, v_tamam
    FROM public.treatment_days
    WHERE case_id = p_case_id AND day_no = v_day_no;

    -- KISMEN ACILMIS GUN DOKUNULMAZ
    IF v_day_id IS NOT NULL AND v_tamam = false THEN
      SELECT EXISTS(
        SELECT 1 FROM public.treatment_day_uygulamalar
        WHERE treatment_day_id = v_day_id
          AND (uygulama_tamamlandi_at IS NOT NULL OR uygulanmadi = true)
      ) INTO v_kismen_acik;

      IF v_kismen_acik THEN
        CONTINUE; -- atla, bu gun kilitli
      END IF;
    END IF;

    IF v_day_id IS NULL THEN
      -- YENI GUN EKLE
      PERFORM public.add_treatment_day_with_sessions(
        p_case_id,
        CURRENT_DATE + (v_day_no - 1),
        v_day_plan->'sessions'
      );
      v_total_seans := v_total_seans + jsonb_array_length(v_day_plan->'sessions');
    ELSIF v_tamam = false THEN
      -- TAMAMLANMAMIS + HICBIR SEANS YAPILMAMIS - RECETE DEGISIKLIGI
      PERFORM public.add_treatment_day_with_sessions(
        p_case_id,
        (SELECT treatment_date FROM public.treatment_days WHERE id = v_day_id),
        v_day_plan->'sessions',
        v_day_id
      );
      v_total_seans := v_total_seans + jsonb_array_length(v_day_plan->'sessions');
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'guncellenen_seans', v_total_seans);
END;
$$;

GRANT EXECUTE ON FUNCTION public.recete_guncelle TO anon, authenticated;

-- RPC 4: close_case_with_remaining
-- Spec: L804-907
-- Vakayı erken kapat. Tüm kalan seanslar uygulanmadi olarak işaretlenir + stok iade.
DROP FUNCTION IF EXISTS public.close_case_with_remaining(uuid, text);
CREATE OR REPLACE FUNCTION public.close_case_with_remaining(
  p_case_id  uuid,
  p_not      text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_remaining_count int;
BEGIN
  -- 1. Stok iade: SEANS olan drug_admins (seans_admin_id NOT NULL)
  UPDATE public.stok_hareket sh
  SET iptal = true
  FROM public.drug_administrations da
  JOIN public.treatment_day_uygulamalar tdu
    ON tdu.id = da.seans_admin_id
  WHERE tdu.case_id = p_case_id
    AND tdu.uygulanmadi = false
    AND tdu.uygulama_tamamlandi_at IS NULL   -- biten seans iade EDILMEZ
    AND sh.notlar = 'drug_admin:' || da.id::text
    AND sh.iptal = false;

  -- ESKI VAKA FALLBACK: seans_admin_id NULL olan drug_admins (seans tablosu kullanilmamis)
  UPDATE public.stok_hareket sh
  SET iptal = true
  FROM public.drug_administrations da
  JOIN public.treatment_days td ON td.id = da.treatment_day_id
  WHERE td.case_id = p_case_id
    AND da.seans_admin_id IS NULL
    AND td.tamamlandi = false                 -- tamamlanmis gun iade EDILMEZ
    AND (da.uygulanmadi IS NULL OR da.uygulanmadi = false)
    AND sh.notlar = 'drug_admin:' || da.id::text
    AND sh.iptal = false;

  -- 2. Seans tablosu: uygulanmadi=true
  UPDATE public.treatment_day_uygulamalar
  SET uygulanmadi = true,
      iptal_nedeni = 'Vaka erken kapatildi' || COALESCE(': ' || p_not, ''),
      updated_at = now()
  WHERE case_id = p_case_id
    AND uygulanmadi = false
    AND uygulama_tamamlandi_at IS NULL;       -- biten seans "yapilmadi" YAPILMAZ

  GET DIAGNOSTICS v_remaining_count = ROW_COUNT;

  -- 3. drug_admins senkron (seans uzerinden)
  UPDATE public.drug_administrations da
  SET uygulanmadi = true
  FROM public.treatment_day_uygulamalar tdu
  WHERE tdu.id = da.seans_admin_id
    AND tdu.case_id = p_case_id
    AND tdu.uygulanmadi = true
    AND da.uygulanmadi IS DISTINCT FROM true;

  -- ESKI VAKA FALLBACK
  UPDATE public.drug_administrations da
  SET uygulanmadi = true
  FROM public.treatment_days td
  WHERE td.id = da.treatment_day_id
    AND td.case_id = p_case_id
    AND da.seans_admin_id IS NULL
    AND td.tamamlandi = false                 -- tamamlanmis gun korunur
    AND da.uygulanmadi IS DISTINCT FROM true;

  -- 4. treatment_days tamamlandi
  UPDATE public.treatment_days
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE case_id = p_case_id AND tamamlandi = false;

  -- 5. gorev_log kalan acik gorevler
  -- NOT: gorev_tipi guard zorunlu — aksi halde gorev_log'daki JSON-olmayan
  -- (emoji'li duz metin) aciklama'lar g.aciklama::jsonb cast'inde 22P02 verir.
  UPDATE public.gorev_log g
  SET tamamlandi = true, tamamlanma_tarihi = now()
  FROM public.treatment_days td
  WHERE td.case_id = p_case_id
    AND g.gorev_tipi IN ('TEDAVI_GUN','TEDAVI_SEANS')
    AND (g.aciklama::jsonb->>'day_id')::uuid = td.id
    AND g.tamamlandi = false;

  -- 6. Case kapat
  UPDATE public.cases
  SET status = 'closed', closed_at = now()
  WHERE id = p_case_id;

  -- 7. Audit
  INSERT INTO public.islem_log(id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text, 'CASE_CLOSED_EARLY',
    (SELECT animal_id FROM public.cases WHERE id = p_case_id),
    p_case_id::text, 'cases',
    jsonb_build_object(
      'iptal_edilen_seans', v_remaining_count,
      'stok_iade_edildi', v_remaining_count > 0,
      'not', p_not
    )
  );

  RETURN jsonb_build_object('ok', true, 'iptal_edilen_seans', v_remaining_count);
END;
$$;

GRANT EXECUTE ON FUNCTION public.close_case_with_remaining TO anon, authenticated;

-- RPC 5: treatment_day_tamamla
-- Spec: L915-1046
-- Tedavi gününü kapat. Eski (drug_admin) + yeni (seans) akış destekler.
-- Idempotent: zaten tamamlanmışsa noop.
DROP FUNCTION IF EXISTS public.treatment_day_tamamla(uuid, text, uuid[]);
CREATE OR REPLACE FUNCTION public.treatment_day_tamamla(
  p_day_id           uuid,
  p_not              text    DEFAULT NULL,
  p_uygulanmadi_ids  uuid[]  DEFAULT '{}'
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_day        public.treatment_days%ROWTYPE;
  v_seans_sayisi int;
  v_tamam       int;
  v_uygulanmadi int;
  v_onceki      boolean;
  v_admin_id    uuid;
BEGIN
  SELECT * INTO v_day FROM public.treatment_days WHERE id = p_day_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Tedavi gunu bulunamadi: %', p_day_id; END IF;
  IF v_day.tamamlandi THEN
    RETURN jsonb_build_object('ok', true, 'day_id', p_day_id, 'mesaj', 'Zaten tamamlanmis (idempotent)');
  END IF;

  -- Onceki gun tamamlanmali
  SELECT EXISTS(
    SELECT 1 FROM public.treatment_days
    WHERE case_id = v_day.case_id AND day_no < v_day.day_no
      AND (tamamlandi IS NULL OR tamamlandi = false)
  ) INTO v_onceki;
  IF v_onceki THEN RAISE EXCEPTION 'Onceki tedavi gunleri tamamlanmadan bu gun tamamlanamaz'; END IF;

  -- YENI: seans_sayisi > 0 ise "tum seanslar done" kontrolu
  v_seans_sayisi := COALESCE(v_day.seans_sayisi, 1);
  IF v_seans_sayisi > 1 THEN
    SELECT
      COUNT(*) FILTER (WHERE uygulama_tamamlandi_at IS NOT NULL),
      COUNT(*) FILTER (WHERE uygulanmadi = true)
    INTO v_tamam, v_uygulanmadi
    FROM public.treatment_day_uygulamalar WHERE treatment_day_id = p_day_id;

    IF (v_tamam + v_uygulanmadi + COALESCE(array_length(p_uygulanmadi_ids, 1), 0)) < v_seans_sayisi THEN
      RAISE EXCEPTION 'Tum seanslar tamamlanmadi (%/% done, % uygulanmadi)', 
        v_tamam, v_seans_sayisi, v_uygulanmadi;
    END IF;
  END IF;

  -- Uygulanmadi isaretlemeleri
  -- p_uygulanmadi_ids: drug_admins.id (eski) veya tdu.id (yeni) olabilir
  IF array_length(p_uygulanmadi_ids, 1) > 0 THEN
    FOREACH v_admin_id IN ARRAY p_uygulanmadi_ids
    LOOP
      -- 1. drug_admins'de ara (eski tek-seans)
      UPDATE public.drug_administrations
      SET uygulanmadi = true
      WHERE id = v_admin_id
        AND treatment_day_id = p_day_id
        AND uygulanmadi IS DISTINCT FROM true;

      -- 2. Bulunamadiysa seans tablosu uzerinden (yeni cok-seans)
      -- v_admin_id = tdu.id, seans_admin_id FK ile bagli drug_admins'leri bul
      UPDATE public.drug_administrations
      SET uygulanmadi = true
      WHERE seans_admin_id = v_admin_id
        AND treatment_day_id = p_day_id
        AND uygulanmadi IS DISTINCT FROM true;

      -- Seans tablosunu da isaretle
      UPDATE public.treatment_day_uygulamalar
      SET uygulama_tamamlandi_at = COALESCE(uygulama_tamamlandi_at, now()),
          uygulama_notu = COALESCE(uygulama_notu, p_not),
          gerceklesme_saati = COALESCE(gerceklesme_saati, NOW()::time),
          updated_at = now()
      WHERE id = v_admin_id
        AND uygulama_tamamlandi_at IS NULL
        AND uygulanmadi = false;

      -- 3. Stok iade: stok_hareket_ref kolonu Faz 1'de yok.
      -- Bunun yerine: v_admin_id = tdu.id ise seans uzerinden bulunan drug_admins'lerin notlar pattern'i
      UPDATE public.stok_hareket sh
      SET iptal = true
      FROM public.drug_administrations da
      WHERE (
        -- v_admin_id tdu.id ise (seans uzerinden)
        da.seans_admin_id = v_admin_id
        OR
        -- v_admin_id drug_admins.id ise (eski tek-seans)
        da.id = v_admin_id
      )
      AND da.treatment_day_id = p_day_id
      AND sh.notlar = 'drug_admin:' || da.id::text
      AND sh.iptal = false;
    END LOOP;
  END IF;

  -- Gun done
  UPDATE public.treatment_days
  SET tamamlandi = true, tamamlanma_tarihi = now(), tamamlanma_notu = p_not
  WHERE id = p_day_id;

  -- Gorev log
  UPDATE public.gorev_log
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE gorev_tipi IN ('TEDAVI_GUN', 'TEDAVI_SEANS')
    AND tamamlandi = false
    AND (aciklama::jsonb->>'day_id')::uuid = p_day_id;

  RETURN jsonb_build_object('ok', true, 'day_id', p_day_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.treatment_day_tamamla TO anon, authenticated;

-- 9f. treatment_day_not_guncelle
DROP FUNCTION IF EXISTS public.treatment_day_not_guncelle(uuid, text);
CREATE OR REPLACE FUNCTION public.treatment_day_not_guncelle(
  p_day_id  uuid,
  p_notes   text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.treatment_days
  SET notes = p_notes
  WHERE id = p_day_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tedavi günü bulunamadı: %', p_day_id;
  END IF;
END;
$$;

-- 9g. case_plan_notu_guncelle
CREATE OR REPLACE FUNCTION public.case_plan_notu_guncelle(
  p_case_id   uuid,
  p_plan_notu text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.cases
  SET plan_notu = p_plan_notu
  WHERE id = p_case_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Vaka bulunamadı: %', p_case_id;
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
ALTER TABLE public.treatment_day_uygulamalar ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS diseases_select             ON public.diseases;
DROP POLICY IF EXISTS drugs_select                ON public.drugs;
DROP POLICY IF EXISTS cases_all                   ON public.cases;
DROP POLICY IF EXISTS treatment_days_all          ON public.treatment_days;
DROP POLICY IF EXISTS drug_administrations_all    ON public.drug_administrations;
DROP POLICY IF EXISTS treatment_day_uygulamalar_all ON public.treatment_day_uygulamalar;

CREATE POLICY diseases_select          ON public.diseases             FOR SELECT USING (true);
CREATE POLICY drugs_select             ON public.drugs                FOR SELECT USING (true);
CREATE POLICY cases_all                ON public.cases                FOR ALL    USING (true);
CREATE POLICY treatment_days_all       ON public.treatment_days       FOR ALL    USING (true);
CREATE POLICY drug_administrations_all ON public.drug_administrations FOR ALL    USING (true);
-- BUG-059: seans tablosu RLS policy'si unutulmustu — anon SELECT engelleniyordu,
-- frontend yarattigi seansi geri okuyamiyordu (modal/gorev bos gorunuyordu)
CREATE POLICY treatment_day_uygulamalar_all ON public.treatment_day_uygulamalar FOR ALL USING (true);

-- SECURITY DEFINER GRANTS
GRANT EXECUTE ON FUNCTION public.create_case             TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.add_treatment_day       TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.add_drug_administration(uuid, text, uuid, numeric, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.close_case              TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.treatment_day_tamamla   TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.treatment_day_not_guncelle TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.case_plan_notu_guncelle(uuid, text) TO anon, authenticated;

-- ──────────────────────────────────────────────────────────────
-- 10b. ŞABLON TEDAVİ PLANLAMA (#63) — tablolar + RLS + GRANT + RPC
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tedavi_sablonu (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ad          text UNIQUE NOT NULL,
  aciklama    text,
  aktif       boolean DEFAULT true,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);
COMMENT ON TABLE public.tedavi_sablonu IS 'Kullanıcı tanımlı tedavi şablonu başlığı (#63)';

CREATE TABLE IF NOT EXISTS public.sablon_hastalik_eslem (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sablon_id   uuid NOT NULL REFERENCES public.tedavi_sablonu(id) ON DELETE CASCADE,
  disease_id  uuid NOT NULL REFERENCES public.diseases(id)       ON DELETE CASCADE,
  created_at  timestamptz DEFAULT now(),
  CONSTRAINT she_uniq UNIQUE (sablon_id, disease_id)
);
CREATE INDEX IF NOT EXISTS she_disease_idx ON public.sablon_hastalik_eslem(disease_id);
CREATE INDEX IF NOT EXISTS she_sablon_idx  ON public.sablon_hastalik_eslem(sablon_id);

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

-- CRUD: kaydet (insert/update + eşlem + kalem, DENSE_RANK ile gün no 1..N)
DROP FUNCTION IF EXISTS public.tedavi_sablon_kaydet(uuid, text, text, jsonb, jsonb);
CREATE OR REPLACE FUNCTION public.tedavi_sablon_kaydet(
  p_id          uuid,
  p_ad          text,
  p_aciklama    text,
  p_disease_ids jsonb,
  p_kalemler    jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_ad IS NULL OR btrim(p_ad) = '' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Şablon adı zorunlu');
  END IF;
  IF EXISTS (SELECT 1 FROM public.tedavi_sablonu
             WHERE LOWER(ad) = LOWER(p_ad) AND (p_id IS NULL OR id != p_id)) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu isimde başka bir şablon var');
  END IF;

  IF p_id IS NULL THEN
    INSERT INTO public.tedavi_sablonu (ad, aciklama)
    VALUES (p_ad, NULLIF(btrim(coalesce(p_aciklama,'')),''))
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.tedavi_sablonu
       SET ad = p_ad, aciklama = NULLIF(btrim(coalesce(p_aciklama,'')),''), updated_at = now()
     WHERE id = p_id;
    IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Şablon bulunamadı'); END IF;
    v_id := p_id;
    DELETE FROM public.sablon_hastalik_eslem WHERE sablon_id = v_id;
    DELETE FROM public.tedavi_sablonu_kalem  WHERE sablon_id = v_id;
  END IF;

  INSERT INTO public.sablon_hastalik_eslem (sablon_id, disease_id)
  SELECT v_id, t.val::uuid
  FROM jsonb_array_elements_text(coalesce(p_disease_ids,'[]'::jsonb)) AS t(val)
  ON CONFLICT (sablon_id, disease_id) DO NOTHING;

  INSERT INTO public.tedavi_sablonu_kalem
    (sablon_id, gun_no, planned_time, stok_id, drug_product_id, dose, unit, route)
  SELECT
    v_id,
    DENSE_RANK() OVER (ORDER BY (k->>'gun_no')::int)::smallint,
    (k->>'planned_time')::time,
    NULLIF(k->>'stok_id','')::text,
    NULLIF(k->>'drug_product_id','')::uuid,
    (k->>'dose')::numeric,
    k->>'unit',
    NULLIF(k->>'route','')
  FROM jsonb_array_elements(coalesce(p_kalemler,'[]'::jsonb)) AS k;

  RETURN jsonb_build_object('ok', true, 'sablon_id', v_id);
END;
$$;

DROP FUNCTION IF EXISTS public.tedavi_sablon_sil(uuid);
CREATE OR REPLACE FUNCTION public.tedavi_sablon_sil(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  DELETE FROM public.tedavi_sablonu WHERE id = p_id;  -- CASCADE → kalem + eşlem
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Şablon bulunamadı'); END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;

-- Uygula: şablon kalemlerini gun_no'ya göre gruplayıp add_treatment_day_with_sessions motorunu besler
DROP FUNCTION IF EXISTS public.tedavi_sablon_uygula(uuid, uuid);
CREATE OR REPLACE FUNCTION public.tedavi_sablon_uygula(
  p_case_id    uuid,
  p_sablon_id  uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_case         record;
  v_gun_no       smallint;
  v_date         date;
  v_sessions     jsonb;
  v_atlanan      jsonb := '[]'::jsonb;
  v_gun_atlanan  jsonb;
  v_gun_sayisi   int := 0;
  v_seans_sayisi int := 0;
BEGIN
  SELECT * INTO v_case FROM public.cases WHERE id = p_case_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Vaka bulunamadı'); END IF;
  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakaya şablon uygulanamaz');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.tedavi_sablonu WHERE id = p_sablon_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Şablon bulunamadı');
  END IF;

  FOR v_gun_no IN
    SELECT DISTINCT gun_no FROM public.tedavi_sablonu_kalem
    WHERE sablon_id = p_sablon_id ORDER BY gun_no
  LOOP
    v_date := v_case.start_date + (v_gun_no - 1);

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
             'planned_time',    to_char(k.planned_time,'HH24:MI'),
             'stok_id',         k.stok_id,
             'drug_product_id', k.drug_product_id,
             'dose',            k.dose,
             'unit',            k.unit,
             'route',           k.route
           ) ORDER BY k.planned_time), '[]'::jsonb)
    INTO v_sessions
    FROM public.tedavi_sablonu_kalem k
    WHERE k.sablon_id = p_sablon_id AND k.gun_no = v_gun_no
      AND (k.drug_product_id IS NULL OR EXISTS (SELECT 1 FROM public.drug_products dp WHERE dp.id = k.drug_product_id))
      AND (k.stok_id IS NULL OR EXISTS (SELECT 1 FROM public.stok s WHERE s.id = k.stok_id));

    SELECT COALESCE(jsonb_agg(jsonb_build_object(
             'gun_no', k.gun_no,
             'planned_time', to_char(k.planned_time,'HH24:MI'),
             'neden', 'silinmiş ilaç/stok')), '[]'::jsonb)
    INTO v_gun_atlanan
    FROM public.tedavi_sablonu_kalem k
    WHERE k.sablon_id = p_sablon_id AND k.gun_no = v_gun_no
      AND ((k.drug_product_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.drug_products dp WHERE dp.id = k.drug_product_id))
        OR (k.stok_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.stok s WHERE s.id = k.stok_id)));
    IF jsonb_array_length(v_gun_atlanan) > 0 THEN
      v_atlanan := v_atlanan || v_gun_atlanan;
    END IF;

    IF jsonb_array_length(v_sessions) > 0 THEN
      PERFORM public.add_treatment_day_with_sessions(p_case_id, v_date, v_sessions, NULL);
      v_gun_sayisi   := v_gun_sayisi + 1;
      v_seans_sayisi := v_seans_sayisi + jsonb_array_length(v_sessions);
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true,
    'gun_sayisi', v_gun_sayisi, 'seans_sayisi', v_seans_sayisi, 'atlanan', v_atlanan);
END;
$$;

GRANT EXECUTE ON FUNCTION public.tedavi_sablon_kaydet(uuid, text, text, jsonb, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tedavi_sablon_sil(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.tedavi_sablon_uygula(uuid, uuid) TO anon, authenticated;

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
INSERT INTO public.drugs (name, default_unit, default_route, kategori) VALUES
  ('Enrofloksasin',    'ml',  'IM', 'Antibiyotik'),
  ('Oksitetrasiklin',  'ml',  'IM', 'Antibiyotik'),
  ('Penisilin',        'ml',  'IM', 'Antibiyotik'),
  ('Makrovil',         'ml',  'IM', 'Antibiyotik'),
  ('Enrolen',          'ml',  'IM', 'Antibiyotik'),
  ('Florkem',          'ml',  'IM', 'Antibiyotik'),
  ('Meloksikam',       'ml',  'IV', 'NSAID'),
  ('Ketoprofen',       'ml',  'IM', 'NSAID'),
  ('Flunixin',         'ml',  'IV', 'NSAID'),
  ('Deksametazon',     'ml',  'IM', 'Kortikosteroid'),
  ('B Kompleks',       'ml',  'IM', 'Vitamin'),
  ('B12 Vitamini',     'ml',  'IM', 'Vitamin'),
  ('AD3E Vitamini',    'ml',  'IM', 'Vitamin'),
  ('Vitamin AD3E',     'ml',  'IM', 'Vitamin'),
  ('Vitamin C',        'ml',  'IV', 'Vitamin'),
  ('Kalsiyum Boroglukonat', 'ml', 'IV', 'Metabolik'),
  ('Magnezyum Sülfat', 'ml',  'IV', 'Metabolik'),
  ('Glukoz %50',       'ml',  'IV', 'Metabolik'),
  ('Elektrolit',       'gr',  'PO', 'Metabolik'),
  ('Rumen Stimülanı',  'ml',  'PO', 'Metabolik'),
  ('Oksitoksin',       'ml',  'IM', 'Hormon'),
  ('Progesteron',      'ml',  'IM', 'Hormon'),
  ('GnRH',             'ml',  'IM', 'Hormon'),
  ('PGF2α',            'ml',  'IM', 'Hormon'),
  ('Albendazol',       'ml',  'PO', 'Antiparaziter'),
  ('İvermektin',       'ml',  'SC', 'Antiparaziter')
ON CONFLICT (name) DO NOTHING;

-- ──────────────────────────────────────────────────────────────
-- PostgREST schema cache yenile
-- ──────────────────────────────────────────────────────────────
NOTIFY pgrst, 'reload schema';
-- ══════════════════════════════════════════════════════════════
-- MIGRATION 023 — REMOVE DRUG ADMINISTRATION RPC
-- EgeSüt ERP — 2026-03-12
--
-- Değişiklikler:
-- 1. remove_drug_administration(p_admin_id uuid) → jsonb
--    - drug_administrations kaydını siler
--    - Bağlı stok_hareket satırını iptal=true yapar (ledger bütünlüğü)
--    - Kapalı vakada silme yasak
--    - stok_hareket kaydı yoksa (stok_item_id=NULL ilaç) yine de siler
-- ══════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.remove_drug_administration(uuid);

CREATE OR REPLACE FUNCTION public.remove_drug_administration(
  p_admin_id uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_admin  record;
  v_day    record;
  v_case   record;
BEGIN
  -- Kaydı çek
  SELECT * INTO v_admin
  FROM   public.drug_administrations
  WHERE  id = p_admin_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'İlaç kaydı bulunamadı');
  END IF;

  -- Tedavi günü → vaka kontrolü
  SELECT * INTO v_day  FROM public.treatment_days WHERE id = v_admin.treatment_day_id;
  SELECT * INTO v_case FROM public.cases          WHERE id = v_day.case_id;

  IF v_case.status = 'closed' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kapalı vakadan ilaç silinemez');
  END IF;

  -- Bağlı stok_hareket satırlarını iptal et
  -- add_drug_administration: notlar='drug_admin:{id}'
  -- update_drug_administration delta: notlar='drug_admin:{id}:duz:*'
  UPDATE public.stok_hareket
  SET    iptal = true
  WHERE  notlar LIKE 'drug_admin:' || p_admin_id::text || '%'
    AND  NOT iptal;

  -- Kaydı sil (ON DELETE CASCADE: yoksa gün silerken zaten temizlenir ama burada explicit)
  DELETE FROM public.drug_administrations WHERE id = p_admin_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.remove_drug_administration TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
-- ══════════════════════════════════════════════════════════════
-- MIGRATION 024 — LINK DRUG TO STOCK RPC
-- EgeSüt ERP — 2026-03-12
--
-- Değişiklikler:
-- 1. link_drug_to_stock(p_drug_id uuid, p_stock_item_id text)
--    - drugs.stock_item_id günceller (NULL göndermek bağlantıyı koparır)
--    - p_stock_item_id NULL ise bağlantı kaldırılır
--    - stok kaydı yoksa hata döner
-- ══════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS public.link_drug_to_stock(uuid, text);

NOTIFY pgrst, 'reload schema';
-- ══════════════════════════════════════════════════════════════
-- MIGRATION 025 — TREATMENT DAY TIME COLUMN
-- EgeSüt ERP — 2026-03-25
--
-- Değişiklikler:
-- 1. treatment_days.treatment_time (time) kolonu eklendi
-- 2. update_treatment_time RPC eklendi
--
-- NOT: treatment_timeline view'ı yeniden tanımlanmıyor —
-- gerçek DB şeması repo'daki migration 022 ile tam örtüşmüyor
-- (drug_administrations kolon adları farklı). MCP erişimi
-- sağlandıktan sonra view güncellenecek.
-- ══════════════════════════════════════════════════════════════

-- 1. Kolon ekle
ALTER TABLE public.treatment_days
  ADD COLUMN IF NOT EXISTS treatment_time time;

COMMENT ON COLUMN public.treatment_days.treatment_time IS 'Tedavi saati (örn. 08:00) — opsiyonel';

-- 2. RPC: tedavi günü saatini güncelle
DROP FUNCTION IF EXISTS public.update_treatment_time(uuid, time);
NOTIFY pgrst, 'reload schema';
-- ══════════════════════════════════════════════════════════════
-- MIGRATION 026 — treatment_timeline view'a treatment_time ekle
-- EgeSüt ERP — 2026-03-25
--
-- Sorun: treatment_days.treatment_time kolonu view'a dahil
--        edilmemişti. JS tarafı r.treatment_time okuyunca
--        undefined alıyor, saat hiç gösterilmiyordu.
-- ══════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW public.treatment_timeline AS
SELECT
  h.id              AS animal_id,
  h.kupe_no,
  c.id              AS case_id,
  c.status          AS case_status,
  c.start_date      AS case_start,
  dis.name          AS disease,
  dis.category      AS disease_category,
  td.id             AS day_id,
  td.day_no,
  td.treatment_date,
  dp.id             AS drug_id,
  COALESCE(dp.brand_name, s.urun_adi, '?') AS drug,
  da.id             AS administration_id,
  da.dose,
  da.unit,
  da.route,
  da.notes          AS admin_notes,
  da.stok_id,
  td.treatment_time
FROM treatment_days td
  JOIN  cases             c   ON c.id   = td.case_id
  JOIN  hayvanlar         h   ON h.id   = c.animal_id
  JOIN  diseases          dis ON dis.id = c.disease_id
  LEFT JOIN drug_administrations da  ON da.treatment_day_id = td.id
  LEFT JOIN drug_products        dp  ON dp.id = da.drug_product_id
  LEFT JOIN stok                 s   ON s.id  = da.stok_id;

NOTIFY pgrst, 'reload schema';
-- ══════════════════════════════════════════════════════════════
-- MIGRATION 026 — Grup/Padok düzeltmeleri + Gebe trigger
-- EgeSüt ERP — 2026-03-26
--
-- Değişiklikler:
-- 1. dogum_kaydet: buzağı grup 'Süt İçen Buzağılar' → 'Süt İçen Buzağı'
--                 buzağı padok 'Buzağı Ahırı' → 'Buzağı Padok (Süt İçenler)'
-- 2. dogum_kaydet: anne doğum sonrası grup → 'Sağmal (Laktasyonda)'
-- 3. Trigger: tohumlama.sonuc = 'Gebe' olunca düve grubundaki
--            hayvanlar otomatik 'Gebe Düve' grubuna geçer
-- ══════════════════════════════════════════════════════════════

CREATE TRIGGER trg_gebe_grup
  AFTER UPDATE ON public.tohumlama
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_gebe_grup_guncelle();

-- Görev listener: padok_id değişince eşleşen PADOK_DEGISIM görevini otomatik kapat (2026-06-18)
CREATE OR REPLACE FUNCTION public.fn_padok_transfer_gorev_kapat()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.gorev_log
     SET tamamlandi = true, tamamlanma_tarihi = now()
   WHERE hayvan_id = NEW.id
     AND gorev_tipi = 'PADOK_DEGISIM'
     AND tamamlandi = false
     AND iptal = false
     AND padok_hedef = NEW.padok;

  IF FOUND THEN
    INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, snapshot, kullanici_notu)
    VALUES ('GOREV_OTOKAPAT', NEW.id, NEW.id, '{}'::jsonb,
            'Padok değişimi → ' || NEW.padok || ' (transfer görevi otomatik kapatıldı)');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_padok_transfer_gorev ON public.hayvanlar;
CREATE TRIGGER trg_padok_transfer_gorev
  AFTER UPDATE OF padok_id ON public.hayvanlar
  FOR EACH ROW
  WHEN (NEW.padok_id IS DISTINCT FROM OLD.padok_id)
  EXECUTE FUNCTION public.fn_padok_transfer_gorev_kapat();

NOTIFY pgrst, 'reload schema';
-- ══════════════════════════════════════════════════════════════
-- MIGRATION 027 — Besi padok ayrımı + trigger kaldır + dogum_kaydet baba auto-fill
-- EgeSüt ERP — 2026-03-26
--
-- Değişiklikler:
-- 1. trg_gebe_grup trigger'ı ve fn_gebe_grup_guncelle fonksiyonu kaldırıldı
--    (Süt veren inekler de tohumlanabiliyor — grup otomasyonu yanlıştı)
-- 2. Mevcut Besi hayvanları padok güncellendi:
--    Erkek → 'Besi Padok (Erkek)', Dişi → 'Besi Padok (Dişi)'
-- 3. dogum_kaydet: p_baba artık isteğe bağlı (UI'den gönderilmeyecek)
--    Aktif Gebe tohumlamadan sperma otomatik baba_bilgi olarak kullanılıyor
-- ══════════════════════════════════════════════════════════════

-- ── 1. Trigger + fonksiyonu kaldır ──────────────────────────
DROP TRIGGER IF EXISTS trg_gebe_grup ON public.tohumlama;
DROP FUNCTION IF EXISTS public.fn_gebe_grup_guncelle();

-- ── 2. Mevcut Besi hayvanları padok düzelt ──────────────────
UPDATE public.hayvanlar
SET padok = CASE
  WHEN cinsiyet = 'Erkek' THEN 'Besi Padok (Erkek)'
  ELSE 'Besi Padok (Dişi)'
END
WHERE grup = 'Besi';

NOTIFY pgrst, 'reload schema';
-- Fix: tohumlama UPDATE trigger 'Doğum Yaptı' güncellemesini ABORT_KAYDI değil DOGUM_KAYDI olarak loglasın
-- Sorun: dogum_kaydet RPC tohumlama.sonuc='Doğum Yaptı' yaparken trigger her UPDATE'i ABORT_KAYDI yazıyordu

CREATE OR REPLACE FUNCTION public.fn_islem_log()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tip        text;
  v_hayvan_id  uuid;
  v_snapshot   jsonb;
  v_ref_id     uuid;
  v_ref_tablo  text;
BEGIN
  CASE TG_TABLE_NAME

    WHEN 'hayvanlar' THEN
      v_tip       := CASE TG_OP WHEN 'INSERT' THEN 'HAYVAN_EKLENDI' ELSE 'HAYVAN_GUNCELLENDI' END;
      v_hayvan_id := NEW.id;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := 'hayvanlar';

    WHEN 'dogum' THEN
      v_tip       := 'DOGUM_KAYDI';
      v_hayvan_id := NEW.anne_id;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := 'dogum';

    WHEN 'tohumlama' THEN
      v_tip := CASE
        WHEN TG_OP = 'UPDATE' AND NEW.sonuc = 'Abort'       THEN 'ABORT_KAYDI'
        WHEN TG_OP = 'UPDATE' AND NEW.sonuc = 'Doğum Yaptı' THEN 'DOGUM_KAYDI'
        WHEN TG_OP = 'UPDATE'                                THEN 'TOHUMLAMA_GUNCELLENDI'
        ELSE 'TOHUMLAMA'
      END;
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := 'tohumlama';

    WHEN 'hastalik_log' THEN
      v_tip       := CASE TG_OP WHEN 'INSERT' THEN 'HASTALIK_KAYDI' ELSE 'HASTALIK_GUNCELLENDI' END;
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := 'hastalik_log';

    WHEN 'kizginlik_log' THEN
      v_tip       := 'KIZGINLIK';
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := 'kizginlik_log';

    ELSE
      v_tip       := upper(TG_TABLE_NAME) || '_' || TG_OP;
      v_hayvan_id := NULL;
      v_snapshot  := to_jsonb(NEW);
      v_ref_id    := NEW.id;
      v_ref_tablo := TG_TABLE_NAME;
  END CASE;

  INSERT INTO public.islem_log (tip, ana_hayvan_id, snapshot, ref_id, ref_tablo)
  VALUES (v_tip, v_hayvan_id, v_snapshot, v_ref_id, v_ref_tablo);

  RETURN NEW;
END;
$$;
-- Migration 029: geri_al RPC (restore from drift)
-- Bu fonksiyon migration 013'te SQL Editor üzerinden uygulandı,
-- repo'ya hiç eklenmemişti. DB reset'e karşı kalıcı hale getiriliyor.

CREATE OR REPLACE FUNCTION public.geri_al(p_islem_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_snapshot  jsonb;
  v_item      jsonb;
  v_tablo     text;
  v_pk        text;
  v_onceki    jsonb;
  v_col       text;
  v_val       text;
  v_set_parts text[] := '{}';
  v_sql       text;
BEGIN
  SELECT snapshot INTO v_snapshot
  FROM islem_log
  WHERE id = p_islem_id;

  IF v_snapshot IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'islem bulunamadi');
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_snapshot->'olusturulan')
  LOOP
    v_tablo := v_item->>'tablo';
    v_pk    := v_item->>'id';

    IF v_tablo = 'treatment_days' THEN
      UPDATE public.stok_hareket
      SET iptal = true
      WHERE notlar IN (
        SELECT 'drug_admin:' || da.id::text
        FROM public.drug_administrations da
        WHERE da.treatment_day_id = v_pk::uuid
      );
      DELETE FROM public.treatment_days WHERE id = v_pk::uuid;

    ELSIF v_tablo = 'cases' THEN
      DELETE FROM public.gorev_log g
      WHERE g.gorev_tipi = 'TEDAVI_GUN'
        AND EXISTS (
          SELECT 1 FROM public.treatment_days td
          WHERE td.case_id = v_pk::uuid
            AND g.aciklama IS NOT NULL
            AND (g.aciklama::jsonb->>'day_id')::uuid = td.id
        );

      UPDATE public.stok_hareket
      SET iptal = true
      WHERE notlar IN (
        SELECT 'drug_admin:' || da.id::text
        FROM public.drug_administrations da
        JOIN public.treatment_days td ON da.treatment_day_id = td.id
        WHERE td.case_id = v_pk::uuid
      );

      DELETE FROM public.cases WHERE id = v_pk::uuid;

    ELSE
      BEGIN
        EXECUTE format('DELETE FROM %I WHERE id = $1', v_tablo) USING v_pk;
      EXCEPTION WHEN others THEN
        EXECUTE format('DELETE FROM %I WHERE id = $1::uuid', v_tablo) USING v_pk;
      END;
    END IF;
  END LOOP;

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_snapshot->'guncellenen')
  LOOP
    v_tablo  := v_item->>'tablo';
    v_pk     := v_item->>'id';
    v_onceki := v_item->'onceki';
    v_set_parts := '{}';

    FOR v_col, v_val IN SELECT key, value #>> '{}' FROM jsonb_each(v_onceki)
    LOOP
      v_set_parts := array_append(
        v_set_parts,
        format('%I = %L', v_col, v_val)
      );
    END LOOP;

    IF array_length(v_set_parts, 1) > 0 THEN
      v_sql := format(
        'UPDATE %I SET %s WHERE id = $1',
        v_tablo,
        array_to_string(v_set_parts, ', ')
      );
      EXECUTE v_sql USING v_pk;
    END IF;
  END LOOP;

  UPDATE islem_log SET durum = 'geri_alindi' WHERE id = p_islem_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.geri_al(text) TO anon, authenticated;
-- Migration: tohumlama event stack — önceki Bekliyor→Boş + islem_log snapshot + tohumlama_sonuc_gebe RPC
-- Etkiler: tohumlama_kaydet RPC (güncelleme), tohumlama_sonuc_gebe RPC (yeni)
--          Tablolar: tohumlama, gorev_log, islem_log, hayvanlar
-- Geri alınabilir: evet — DROP FUNCTION tohumlama_sonuc_gebe(text);
--                          DROP FUNCTION tohumlama_kaydet(text,date,text,text,text);
--                          (eski versiyonu migration 20260326000028'den yeniden uygula)

BEGIN;

-- 1. tohumlama_kaydet: DROP + yeniden oluştur
--    Değişiklikler:
--      a) Yeni tohumlama INSERT'ten önce: önceki Bekliyor kayıtları Boş yap
--      b) gorev_log için önceden ID üret (v_gorev1_id, v_gorev2_id)
--      c) islem_log INSERT ekle — tohumlama + gorev_log ID'leri olusturulan array'inde
--      d) Dönüş değerine islem_id eklendi

DROP FUNCTION IF EXISTS public.tohumlama_kaydet(text, date, text, text, text);

CREATE PUBLICATION gwen_db_watch FOR TABLE 
  public.islem_log, 
  public.stok_hareket, 
  public.gorev_log,
  public.hayvanlar;

-- Realtime replication'i aktif et
ALTER PUBLICATION gwen_db_watch 
  SET (publish = 'insert, update, delete');

COMMIT;

-- Doğrulama
SELECT pubname, puballtables 
FROM pg_publication 
WHERE pubname = 'gwen_db_watch';
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
  marka               text,                    -- Üretici firma (Ceva, Microsules)
  etken_madde         text,                    -- Antijen özeti, opsiyonel
  protokol_tipi       text,                    -- Brand protokolü: tek_doz | primer_seri
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
-- 2b. VACCINE_DISEASES + VACCINE_PROTOCOL_STEPS — Aşı Faz1 (içerik-odaklı)
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.vaccine_diseases (
  vaccine_id  uuid NOT NULL REFERENCES public.vaccines(id) ON DELETE CASCADE,
  disease_id  uuid NOT NULL REFERENCES public.diseases(id) ON DELETE CASCADE,
  PRIMARY KEY (vaccine_id, disease_id)
);
COMMENT ON TABLE public.vaccine_diseases IS 'Aşı↔hastalık M:N — bir markanın koruduğu hastalıklar';

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

ALTER TABLE public.vaccine_diseases       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vaccine_protocol_steps ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS vaccine_diseases_all       ON public.vaccine_diseases;
DROP POLICY IF EXISTS vaccine_protocol_steps_all ON public.vaccine_protocol_steps;
CREATE POLICY vaccine_diseases_all       ON public.vaccine_diseases       FOR ALL USING (true);
CREATE POLICY vaccine_protocol_steps_all ON public.vaccine_protocol_steps FOR ALL USING (true);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.vaccine_diseases       TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.vaccine_protocol_steps TO anon, authenticated;

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
-- drug_product_ekle RPC v2 — security hardening

CREATE UNIQUE INDEX IF NOT EXISTS idx_drug_products_brand_class
  ON drug_products (LOWER(brand_name), drug_class_id);

CREATE OR REPLACE FUNCTION drug_product_ekle(
  p_drug_class_id      UUID,
  p_brand_name         TEXT,
  p_concentration      NUMERIC DEFAULT NULL,
  p_concentration_unit TEXT    DEFAULT NULL,
  p_default_route      TEXT    DEFAULT 'IM',
  p_default_unit       TEXT    DEFAULT NULL,
  p_stok_id            UUID    DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_id UUID;
BEGIN
  IF p_brand_name IS NULL OR trim(p_brand_name) = '' THEN
    RAISE EXCEPTION 'İlaç adı boş olamaz';
  END IF;

  BEGIN
    INSERT INTO drug_products (
      drug_class_id, brand_name, concentration,
      concentration_unit, default_route, default_unit
    ) VALUES (
      p_drug_class_id, p_brand_name, p_concentration,
      p_concentration_unit, p_default_route, p_default_unit
    )
    RETURNING id INTO v_id;
  EXCEPTION
    WHEN unique_violation THEN
      RAISE EXCEPTION 'Bu ilaç zaten kayıtlı: %', p_brand_name;
  END;

  IF p_stok_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM stok WHERE id = p_stok_id::text) THEN
      RAISE EXCEPTION 'Stok kaydı bulunamadı: %', p_stok_id;
    END IF;
    UPDATE stok SET drug_product_id = v_id WHERE id = p_stok_id::text;
  END IF;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = public, pg_temp;

GRANT EXECUTE ON FUNCTION public.drug_product_ekle(UUID, TEXT, NUMERIC, TEXT, TEXT, TEXT, UUID)
  TO anon, authenticated;

-- ilac_ekle: atomik ilaç ekleme (stok + drug_product tek transaction).
-- Katalog (etken madde) zorunlu — ilaç kataloglanmadan eklenemez.
CREATE OR REPLACE FUNCTION public.ilac_ekle(
  p_urun_adi text,
  p_kategori text,
  p_birim text,
  p_baslangic_miktar numeric,
  p_esik numeric DEFAULT 0,
  p_drug_class_id uuid DEFAULT NULL,
  p_concentration numeric DEFAULT NULL,
  p_concentration_unit text DEFAULT NULL,
  p_default_route text DEFAULT 'IM'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_stok_id text;
  v_dp_id   uuid;
BEGIN
  IF p_drug_class_id IS NULL THEN
    RAISE EXCEPTION 'Etken madde (drug_class) zorunlu — ilaç kataloglanmadan eklenemez';
  END IF;
  IF p_urun_adi IS NULL OR trim(p_urun_adi) = '' THEN
    RAISE EXCEPTION 'İlaç adı boş olamaz';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.stok_kategorileri WHERE ad = p_kategori) THEN
    RAISE EXCEPTION 'Geçersiz kategori: %', p_kategori;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.drug_classes WHERE id = p_drug_class_id) THEN
    RAISE EXCEPTION 'Geçersiz etken madde: %', p_drug_class_id;
  END IF;

  v_stok_id := gen_random_uuid()::text;

  INSERT INTO public.stok (id, urun_adi, kategori, birim, baslangic_miktar, esik)
  VALUES (v_stok_id, p_urun_adi, p_kategori, p_birim, p_baslangic_miktar, p_esik);

  BEGIN
    INSERT INTO public.drug_products (
      drug_class_id, brand_name, concentration,
      concentration_unit, default_route, default_unit
    ) VALUES (
      p_drug_class_id, p_urun_adi, p_concentration,
      p_concentration_unit, p_default_route, p_birim
    )
    RETURNING id INTO v_dp_id;
  EXCEPTION
    WHEN unique_violation THEN
      RAISE EXCEPTION 'Bu ilaç zaten kayıtlı: %', p_urun_adi;
  END;

  UPDATE public.stok SET drug_product_id = v_dp_id WHERE id = v_stok_id;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('STOK_EKLE', v_stok_id, 'stok', jsonb_build_object(
    'olusturulan', jsonb_build_array(
      jsonb_build_object('tablo','stok','id',v_stok_id,'veri',jsonb_build_object(
        'urun_adi',p_urun_adi,'kategori',p_kategori,'birim',p_birim,
        'baslangic_miktar',p_baslangic_miktar,'esik',p_esik,'drug_product_id',v_dp_id)),
      jsonb_build_object('tablo','drug_products','id',v_dp_id,'veri',jsonb_build_object(
        'brand_name',p_urun_adi,'drug_class_id',p_drug_class_id))
    ),
    'guncellenen','[]'::jsonb,
    'silinen','[]'::jsonb
  ), 'Yeni ilaç (kataloglu): ' || p_urun_adi);

  RETURN jsonb_build_object('ok', true, 'stok_id', v_stok_id, 'drug_product_id', v_dp_id);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.ilac_ekle(TEXT, TEXT, TEXT, NUMERIC, NUMERIC, UUID, NUMERIC, TEXT, TEXT)
  TO anon, authenticated;

-- ══════════════════════════════════════════════════════════════
-- AŞI FAZ1 — asi_ekle / asi_guncelle / asi_sil (atomik, içerik-odaklı)
-- ══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.asi_ekle(
  p_name text,
  p_marka text DEFAULT NULL,
  p_etken_madde text DEFAULT NULL,
  p_dose numeric DEFAULT NULL,
  p_unit text DEFAULT 'ml',
  p_route text DEFAULT 'SC',
  p_is_mandatory boolean DEFAULT false,
  p_disease_ids uuid[] DEFAULT '{}',
  p_protokol_tipi text DEFAULT 'tek_doz',
  p_protokol_adimlar jsonb DEFAULT '[]'::jsonb,
  p_repeat_interval_days int DEFAULT NULL,
  p_baslangic_stok numeric DEFAULT NULL,
  p_esik numeric DEFAULT 0
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $function$
DECLARE
  v_vaccine_id uuid := gen_random_uuid();
  v_stok_id    text := NULL;
  v_disease_names text;
  v_step jsonb;
  v_did  uuid;
BEGIN
  IF p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Aşı adı zorunlu';
  END IF;

  SELECT string_agg(d.name, ', ' ORDER BY d.name) INTO v_disease_names
  FROM public.diseases d WHERE d.id = ANY(p_disease_ids);

  IF p_baslangic_stok IS NOT NULL THEN
    v_stok_id := 'STOK-AŞI-' || v_vaccine_id::text;
    INSERT INTO public.stok (id, urun_adi, kategori, birim, baslangic_miktar, esik)
    VALUES (v_stok_id, p_name, 'Aşı', COALESCE(p_unit,'ml'), p_baslangic_stok, COALESCE(p_esik,0));
  END IF;

  INSERT INTO public.vaccines (
    id, name, marka, etken_madde, disease_target, dose, unit, route,
    repeat_interval_days, is_mandatory, protokol_tipi, stock_item_id
  ) VALUES (
    v_vaccine_id, p_name, p_marka, p_etken_madde, v_disease_names,
    COALESCE(p_dose,0), COALESCE(p_unit,'ml'), COALESCE(p_route,'SC'),
    p_repeat_interval_days, COALESCE(p_is_mandatory,false), p_protokol_tipi, v_stok_id
  );

  FOR v_step IN SELECT * FROM jsonb_array_elements(p_protokol_adimlar)
  LOOP
    INSERT INTO public.vaccine_protocol_steps (vaccine_id, adim_no, offset_gun, label)
    VALUES (
      v_vaccine_id,
      (v_step->>'adim_no')::int,
      COALESCE((v_step->>'offset_gun')::int, 0),
      v_step->>'label'
    );
  END LOOP;

  IF p_disease_ids IS NOT NULL THEN
    FOREACH v_did IN ARRAY p_disease_ids LOOP
      INSERT INTO public.vaccine_diseases (vaccine_id, disease_id)
      VALUES (v_vaccine_id, v_did) ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('ASI_EKLE', v_vaccine_id::text, 'vaccines',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(jsonb_build_object('tablo','vaccines','id',v_vaccine_id,
        'veri', jsonb_build_object('name',p_name,'marka',p_marka,'stock_item_id',v_stok_id))),
      'guncellenen','[]'::jsonb,'silinen','[]'::jsonb),
    'Yeni aşı: ' || p_name);

  RETURN jsonb_build_object('ok', true, 'vaccine_id', v_vaccine_id, 'stock_item_id', v_stok_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.asi_guncelle(
  p_vaccine_id uuid,
  p_name text,
  p_marka text DEFAULT NULL,
  p_etken_madde text DEFAULT NULL,
  p_dose numeric DEFAULT NULL,
  p_unit text DEFAULT 'ml',
  p_route text DEFAULT 'SC',
  p_is_mandatory boolean DEFAULT false,
  p_disease_ids uuid[] DEFAULT '{}',
  p_protokol_tipi text DEFAULT 'tek_doz',
  p_protokol_adimlar jsonb DEFAULT '[]'::jsonb,
  p_repeat_interval_days int DEFAULT NULL,
  p_baslangic_stok numeric DEFAULT NULL,
  p_esik numeric DEFAULT 0
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $function$
DECLARE
  v_old record;
  v_disease_names text;
  v_step jsonb;
  v_did  uuid;
  v_stok_id text;
BEGIN
  SELECT * INTO v_old FROM public.vaccines WHERE id = p_vaccine_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Aşı bulunamadı'; END IF;
  IF p_name IS NULL OR btrim(p_name) = '' THEN RAISE EXCEPTION 'Aşı adı zorunlu'; END IF;
  v_stok_id := v_old.stock_item_id;

  IF p_name <> v_old.name AND EXISTS (
    SELECT 1 FROM public.gorev_log
    WHERE tamamlandi = false AND iptal = false
      AND (
        (gorev_tipi = 'ASI_RAPEL' AND aciklama LIKE v_old.name || '%')
        OR (gorev_tipi = 'ILERI_GEBE_ASI' AND v_old.stock_item_id IS NOT NULL AND stok_id = v_old.stock_item_id)
      )
  ) THEN
    RAISE EXCEPTION 'Bu aşının aktif görevi var — adı değiştirilemez';
  END IF;

  IF v_old.stock_item_id IS NULL AND p_baslangic_stok IS NOT NULL THEN
    v_stok_id := 'STOK-AŞI-' || p_vaccine_id::text;
    INSERT INTO public.stok (id, urun_adi, kategori, birim, baslangic_miktar, esik)
    VALUES (v_stok_id, p_name, 'Aşı', COALESCE(p_unit,'ml'), p_baslangic_stok, COALESCE(p_esik,0));
  END IF;

  SELECT string_agg(d.name, ', ' ORDER BY d.name) INTO v_disease_names
  FROM public.diseases d WHERE d.id = ANY(p_disease_ids);

  UPDATE public.vaccines SET
    name = p_name, marka = p_marka, etken_madde = p_etken_madde,
    disease_target = v_disease_names, dose = COALESCE(p_dose,0),
    unit = COALESCE(p_unit,'ml'), route = COALESCE(p_route,'SC'),
    repeat_interval_days = p_repeat_interval_days,
    is_mandatory = COALESCE(p_is_mandatory,false), protokol_tipi = p_protokol_tipi,
    stock_item_id = v_stok_id
  WHERE id = p_vaccine_id;

  DELETE FROM public.vaccine_protocol_steps WHERE vaccine_id = p_vaccine_id;
  DELETE FROM public.vaccine_diseases       WHERE vaccine_id = p_vaccine_id;

  FOR v_step IN SELECT * FROM jsonb_array_elements(p_protokol_adimlar)
  LOOP
    INSERT INTO public.vaccine_protocol_steps (vaccine_id, adim_no, offset_gun, label)
    VALUES (p_vaccine_id, (v_step->>'adim_no')::int, COALESCE((v_step->>'offset_gun')::int,0), v_step->>'label');
  END LOOP;

  IF p_disease_ids IS NOT NULL THEN
    FOREACH v_did IN ARRAY p_disease_ids LOOP
      INSERT INTO public.vaccine_diseases (vaccine_id, disease_id)
      VALUES (p_vaccine_id, v_did) ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('ASI_GUNCELLE', p_vaccine_id::text, 'vaccines',
    jsonb_build_object('olusturulan','[]'::jsonb,
      'guncellenen', jsonb_build_array(jsonb_build_object('tablo','vaccines','id',p_vaccine_id)),
      'silinen','[]'::jsonb),
    'Aşı güncellendi: ' || p_name);

  RETURN jsonb_build_object('ok', true, 'vaccine_id', p_vaccine_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.asi_sil(p_vaccine_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp' AS $function$
DECLARE
  v_vac record;
  v_has_hareket boolean;
BEGIN
  SELECT * INTO v_vac FROM public.vaccines WHERE id = p_vaccine_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Aşı bulunamadı'; END IF;

  IF EXISTS (SELECT 1 FROM public.vaccination_log WHERE vaccine_id = p_vaccine_id) THEN
    RAISE EXCEPTION 'Bu aşı uygulanmış, silinemez (geçmiş korunur)';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.gorev_log
    WHERE gorev_tipi IN ('ASI_RAPEL','ILERI_GEBE_ASI')
      AND tamamlandi = false AND iptal = false
      AND ( (v_vac.stock_item_id IS NOT NULL AND stok_id = v_vac.stock_item_id)
            OR aciklama LIKE v_vac.name || '%' )
  ) THEN
    RAISE EXCEPTION 'Bu aşının aktif görevi var, silinemez';
  END IF;

  DELETE FROM public.vaccine_diseases       WHERE vaccine_id = p_vaccine_id;
  DELETE FROM public.vaccine_protocol_steps WHERE vaccine_id = p_vaccine_id;
  DELETE FROM public.vaccines WHERE id = p_vaccine_id;

  IF v_vac.stock_item_id IS NOT NULL THEN
    SELECT EXISTS(SELECT 1 FROM public.stok_hareket WHERE stok_id = v_vac.stock_item_id) INTO v_has_hareket;
    IF NOT v_has_hareket THEN
      DELETE FROM public.stok WHERE id = v_vac.stock_item_id;
    END IF;
  END IF;

  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('ASI_SIL', p_vaccine_id::text, 'vaccines',
    jsonb_build_object('olusturulan','[]'::jsonb,'guncellenen','[]'::jsonb,
      'silinen', jsonb_build_array(jsonb_build_object('tablo','vaccines','id',p_vaccine_id))),
    'Aşı silindi: ' || v_vac.name);

  RETURN jsonb_build_object('ok', true);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.asi_ekle(text,text,text,numeric,text,text,boolean,uuid[],text,jsonb,int,numeric,numeric) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.asi_guncelle(uuid,text,text,text,numeric,text,text,boolean,uuid[],text,jsonb,int,numeric,numeric) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.asi_sil(uuid) TO anon, authenticated;

-- Migration: Realtime publication aktif (idempotent)
-- Tablolar zaten publication'daysa hata vermez

DO $$
DECLARE
  t text;
  tables text[] := ARRAY['hayvanlar','gorev_log','stok','stok_hareket','tohumlama','dogum','islem_log'];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND tablename = t
    ) THEN
      EXECUTE format('ALTER PUBLICATION supabase_realtime ADD TABLE public.%I', t);
    END IF;
  END LOOP;
END;
$$;
-- Migration: UI Telemetry Logger
-- Tarih: 2026-04-01
-- Açıklama: Test sırasında kullanıcı hareketleri ve UI hatalarını loglar

-- Tablo oluştur
create table if not exists public.ui_logs (
  id bigserial primary key,
  level text not null,        -- 'error' | 'warn' | 'action' | 'info'
  message text not null,
  source text,                -- dosya:satır (hata için)
  payload jsonb,              -- ek veri (form değerleri, tıklanan element vb.)
  session_id text,            -- test session'ı ayırt etmek için
  created_at timestamptz default now()
);

-- Index: session_id ve created_at ile hızlı sorgu
create index if not exists idx_ui_logs_session on public.ui_logs(session_id, created_at desc);

-- RLS aktif et
alter table public.ui_logs enable row level security;

-- Anon kullanıcı insert ve select yapabilir (test için)
create policy "anon insert" on public.ui_logs for insert to anon with check (true);
create policy "anon select" on public.ui_logs for select to anon using (true);
-- Migration: tohumlama_sonuc_bos ambiguity fix
-- Sorun: İki farklı imzalı fonksiyon tanımlı, PostgreSQL hangisini çağıracağını bilemiyor
-- Çözüm: Eski tek parametreli imzayı DROP et, yeni imza (DEFAULT NULL ile) kalsın
-- Geri alınabilir: evet — eski migration'dan tek param imzayı yeniden ekle

DROP FUNCTION IF EXISTS public.tohumlama_sonuc_bos(text);

-- Yeni imza zaten migration 0330'dan var, yeniden oluşturmaya gerek yok
-- Doğrulama:
-- SELECT proname, pronargs FROM pg_proc WHERE proname = 'tohumlama_sonuc_bos';
-- 1 satır dönmeli: pronargs = 2-- Migration: delete_treatment_day RPC
-- Etkiler: Yeni RPC — tedavi günü + ilaçları sil, stok ledger'ı tersle
-- Geri alınabilir: DROP FUNCTION IF EXISTS public.delete_treatment_day(uuid);

CREATE OR REPLACE FUNCTION public.delete_treatment_day(
  p_day_id uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  -- Stok iade: iptal=true (audit trail, çift düşüm bug'u fix)
  UPDATE public.stok_hareket
  SET iptal = true
  WHERE notlar IN (
    SELECT 'drug_admin:' || da.id::text
    FROM public.drug_administrations da
    WHERE da.treatment_day_id = p_day_id
  );

  -- Bağlı TEDAVI_GUN gorevini de sil
  DELETE FROM public.gorev_log
  WHERE gorev_tipi = 'TEDAVI_GUN'
    AND aciklama IS NOT NULL
    AND (aciklama::jsonb->>'day_id')::uuid = p_day_id;

  -- Kayıtları sil
  DELETE FROM public.drug_administrations WHERE treatment_day_id = p_day_id;
  DELETE FROM public.treatment_days WHERE id = p_day_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- Migration: update_drug_administration RPC
-- Etkiler: Yeni RPC — ilaç uygulaması güncelle, stok delta kaydet
-- Geri alınabilir: DROP FUNCTION IF EXISTS public.update_drug_administration(uuid, numeric, text, text);
-- Fix: Mevcut fonksiyon DEFAULT parametrelerle tanımlı — önce DROP, sonra CREATE

-- Tüm overload'ları temizle (DEFAULT farkından kaynaklanan 42P13 hatası)
DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure FROM pg_proc WHERE proname = 'update_drug_administration' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.oid::regprocedure; END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.update_drug_administration(
  p_admin_id  uuid,
  p_dose      numeric,
  p_unit      text,
  p_route     text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_admin  record;
  v_delta  numeric;
BEGIN
  -- Fix: drug_id kolonu yok — drug_administrations.stok_id direkt kullan
  SELECT * INTO v_admin
  FROM drug_administrations
  WHERE id = p_admin_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Kayıt bulunamadı');
  END IF;

  -- Doz farkı varsa stok hareketi ekle
  v_delta := p_dose - v_admin.dose;
  IF v_delta <> 0 AND v_admin.stok_id IS NOT NULL THEN
    INSERT INTO stok_hareket (stok_id, tur, miktar, notlar)
    VALUES (
      v_admin.stok_id,
      'Tedavi Düzelt',
      ABS(v_delta),
      'drug_admin:' || p_admin_id::text || ':duz:' || v_delta::text
    );
  END IF;

  UPDATE drug_administrations
  SET dose = p_dose, unit = p_unit, route = p_route
  WHERE id = p_admin_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;-- Migration: link_drug_to_stock RPC
-- Etkiler: Yeni RPC — ilacı stok kalemi ile ilişkilendir
-- Geri alınabilir: DROP FUNCTION IF EXISTS public.link_drug_to_stock(uuid, text);

CREATE OR REPLACE FUNCTION public.link_drug_to_stock(
  p_drug_id       uuid,
  p_stock_item_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE drugs SET stock_item_id = p_stock_item_id::uuid WHERE id = p_drug_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'İlaç bulunamadı');
  END IF;

  RETURN jsonb_build_object('ok', true);
END;
$$;-- BUG-6: tohumlama_sonuc_gebe — operator does not exist: text = uuid
-- Sebep: hayvan_id TEXT iken hayvanlar.id UUID olarak tanımlı. ::uuid cast
-- başarısız oluyor çünkü 'H000013' gibi string UUID değil.
-- Çözüm: TEXT->UUID cast yerine TEXT karşılaştırma yap.
BEGIN;

-- Eski fonksiyonu yeniden yaz
  CREATE POLICY "anon select kizginlik_log"
    ON public.kizginlik_log
    FOR SELECT
    TO anon
    USING (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
-- BUG-FIX 2026-06-16: authenticated RLS policy eksikti — pullTables
-- boş dönüyordu, Üreme → Kızgınlık listesi görünmüyordu.
-- Diğer tablolardaki "allow all" pattern'i ile hizalandı.
DO $$ BEGIN
  CREATE POLICY "allow all" ON public.kizginlik_log
    AS PERMISSIVE FOR ALL TO public
    USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
-- Migration: tohumlama_sonuc_bekliyor RPC
-- Reverts tohumlama from 'Boş' to 'Bekliyor' state
-- Reverts hayvanlar.tohumlama_durumu from islem_log snapshot

BEGIN;

CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_bekliyor(
  p_tohumlama_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh               record;
  v_islem_id          text := gen_random_uuid()::text;
  v_onceki_durum      text;
  v_onceki_toh_sonuc  text;
  v_snapshot          jsonb;
  v_hayvan_snapshot   jsonb;
BEGIN
  -- 1. Find tohumlama by id, require sonuc is 'Boş'
  SELECT * INTO v_toh FROM public.tohumlama
  WHERE id::text = p_tohumlama_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  -- Only 'Boş' can be reverted to 'Bekliyor'
  IF v_toh.sonuc != 'Boş' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Boş durumundaki tohumlama Bekliyor yapılabilir');
  END IF;

  -- Save current tohumlama.sonuc for logging
  v_onceki_toh_sonuc := v_toh.sonuc;

  -- 2. Get previous hayvanlar.tohumlama_durumu from islem_log (snapshot of BOS_ATAMA event)
  SELECT snapshot INTO v_snapshot
  FROM public.islem_log
  WHERE ref_id = p_tohumlama_id
    AND ref_tablo = 'tohumlama'
    AND tip = 'TOHUMLAMA_SONUC'
  ORDER BY tarih DESC
  LIMIT 1;

  IF v_snapshot IS NOT NULL THEN
    -- Extract previous tohumlama_durumu from snapshot
    SELECT elem->'onceki'->>'tohumlama_durumu' INTO v_onceki_durum
    FROM jsonb_array_elements(v_snapshot->'guncellenen') AS elem
    WHERE elem->>'tablo' = 'hayvanlar';
  END IF;

  -- Fallback: if no snapshot found, default to 'Tohumlanabilir'
  IF v_onceki_durum IS NULL THEN
    v_onceki_durum := 'Tohumlanabilir';
  END IF;

  -- 3. Set tohumlama.sonuc = 'Bekliyor'
  UPDATE public.tohumlama SET sonuc = 'Bekliyor' WHERE id::text = p_tohumlama_id;

  -- 4. Revert hayvanlar.tohumlama_durumu to prior state
  UPDATE public.hayvanlar
  SET tohumlama_durumu = v_onceki_durum
  WHERE id = v_toh.hayvan_id
    AND durum = 'Aktif';

  -- 5. Write islem_log with tip='TOHUMLAMA_SONUC'
  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'TOHUMLAMA_SONUC',
    v_toh.hayvan_id,
    p_tohumlama_id,
    'tohumlama',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object(
          'tablo', 'tohumlama',
          'id', p_tohumlama_id,
          'onceki', jsonb_build_object('sonuc', v_onceki_toh_sonuc)
        ),
        jsonb_build_object(
          'tablo', 'hayvanlar',
          'id', v_toh.hayvan_id,
          'onceki', jsonb_build_object('tohumlama_durumu', v_onceki_durum)
        )
      )
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$$;

COMMIT;
-- Drop orphan columns no longer used by the clinical system
-- (new system uses cases/drug_administrations tables)
ALTER TABLE public.hastalik_log DROP COLUMN IF EXISTS ilac_stok_id;
ALTER TABLE public.hastalik_log DROP COLUMN IF EXISTS ilac_miktar;
-- ============================================================
-- Bulk Vaccination RPC
-- Allows vaccinating multiple animals at once via a single RPC call.
-- Reads existing add_vaccination function for pattern reference:
--   migration 20260331000032_vaccination_module.sql
-- ============================================================

CREATE OR REPLACE FUNCTION public.bulk_vaccination(
  p_animal_ids  text[],
  p_vaccine_id  text,
  p_date        date,
  p_dose_ml     numeric DEFAULT NULL,
  p_notes       text    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_animal_id   text;
  v_result      jsonb;
  v_success     int := 0;
  v_errors      jsonb := '[]'::jsonb;
BEGIN
  FOREACH v_animal_id IN ARRAY p_animal_ids LOOP
    v_result := public.add_vaccination(v_animal_id, p_vaccine_id::uuid, p_date, p_dose_ml, p_notes);
    IF (v_result->>'ok')::boolean THEN
      v_success := v_success + 1;
    ELSE
      v_errors := v_errors || jsonb_build_array(
        jsonb_build_object('animal_id', v_animal_id, 'error', v_result->>'mesaj')
      );
    END IF;
  END LOOP;
  RETURN jsonb_build_object(
    'ok', true,
    'total', array_length(p_animal_ids, 1),
    'success', v_success,
    'errors', v_errors
  );
END;
$$;

-- Allow anon/authenticated clients to call this RPC
GRANT EXECUTE ON FUNCTION public.bulk_vaccination TO anon, authenticated;-- ============================================================
-- Bulk Ilac RPC — Toplu Ilac Uygulama (FIXED)
-- Fix: explicit ::uuid casts on all gen_random_uuid() calls
--       and ::text casts on stok_id references
-- ============================================================

CREATE OR REPLACE FUNCTION public.bulk_ilac(
  p_animal_ids   text[],
  p_ilac_stok_id text,
  p_miktar       numeric,
  p_notlar       text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_animal_id       text;
  v_stok            record;
  v_success         int := 0;
  v_errors          jsonb := '[]'::jsonb;
  v_total_miktar    numeric;
  v_stok_urun_adi   text;
  v_log_id          text;
  v_stok_hareket_id uuid;
BEGIN
  -- Verify stok exists
  SELECT id, urun_adi, baslangic_miktar INTO v_stok
  FROM public.stok
  WHERE id = p_ilac_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok kalemi bulunamadı');
  END IF;

  v_stok_urun_adi := v_stok.urun_adi;
  v_total_miktar := p_miktar * array_length(p_animal_ids, 1);

  -- Check stock availability (baslangic_miktar - consumed via stok_hareket)
  IF (
    COALESCE(v_stok.baslangic_miktar, 0)
    < v_total_miktar
  ) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'mesaj', 'Yetersiz stok: ' || COALESCE(v_stok.baslangic_miktar, 0) || ' mevcut, ' || v_total_miktar || ' gerekli'
    );
  END IF;

  -- Apply to each animal
  FOREACH v_animal_id IN ARRAY p_animal_ids LOOP
    BEGIN
      -- Log to islem_log with TOPLU_ILAC tip
      v_log_id := gen_random_uuid()::text;
      INSERT INTO public.islem_log (id, tip, ana_hayvan_id, tarih, kullanici_notu, snapshot, ref_id, ref_tablo)
      VALUES (
        v_log_id,
        'TOPLU_ILAC',
        v_animal_id,
        now(),
        p_notlar,
        jsonb_build_object(
          'ilac_stok_id', p_ilac_stok_id,
          'ilac_adi', v_stok_urun_adi,
          'miktar', p_miktar
        ),
        v_log_id,              -- ref_id = islem_log.id
        'islem_log'            -- ref_tablo
      );
      v_success := v_success + 1;
    EXCEPTION WHEN OTHERS THEN
      v_errors := v_errors || jsonb_build_array(
        jsonb_build_object('animal_id', v_animal_id, 'error', SQLERRM)
      );
    END;
  END LOOP;

  -- Deduct total from stok (single operation for efficiency)
  IF v_success > 0 THEN
    UPDATE public.stok
    SET baslangic_miktar = baslangic_miktar - (p_miktar * v_success)
    WHERE id = p_ilac_stok_id;

    -- Log stok hareket
    v_stok_hareket_id := gen_random_uuid();
    INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
    VALUES (
      v_stok_hareket_id,
      p_ilac_stok_id,
      'TOPLU_ILAC',
      p_miktar * v_success,
      v_success || ' hayvana toplu ilaç uygulaması (' || COALESCE(v_stok_urun_adi, p_ilac_stok_id) || ')',
      false
    );
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'total', array_length(p_animal_ids, 1),
    'success', v_success,
    'errors', v_errors
  );
END;
$$;

-- Allow anon/authenticated clients to call this RPC
GRANT EXECUTE ON FUNCTION public.bulk_ilac TO anon, authenticated;
-- Migration: Vaccines stok backend integration — create real stock pools for vaccines
-- Fixes: All 10 vaccine seeds have stock_item_id=NULL, so vaccination_stok_dusum trigger
--        skips stock deduction entirely.
-- Solution: Auto-create stok items for vaccines and link them.
-- Revertable: YES — undo via DELETE + UPDATE (see ROLLBACK section)

BEGIN;

-- ══════════════════════════════════════════════════════════════
-- 1. Create stok items for vaccines where stock_item_id IS NULL
-- ══════════════════════════════════════════════════════════════
-- For each vaccine without a stock pool, create one with initial qty 1000 units

INSERT INTO public.stok (id, urun_adi, kategori, birim, baslangic_miktar, esik)
SELECT
  'STOK-AŞI-' || v.id::text,
  v.name,
  'Aşı',
  v.unit,
  1000,   -- initial stock: 1000 units (configurable)
  100    -- low-stock threshold
FROM public.vaccines v
WHERE v.stock_item_id IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.stok s
    WHERE s.id = 'STOK-AŞI-' || v.id::text
  );

-- ══════════════════════════════════════════════════════════════
-- 2. Update vaccines.stock_item_id to point to the new stok items
-- ══════════════════════════════════════════════════════════════
UPDATE public.vaccines
SET stock_item_id = 'STOK-AŞI-' || id::text
WHERE stock_item_id IS NULL;

-- ══════════════════════════════════════════════════════════════
-- 3. Verification query (run manually to check)
-- ══════════════════════════════════════════════════════════════
-- SELECT v.name, v.stock_item_id, s.baslangic_miktar
-- FROM public.vaccines v
-- JOIN public.stok s ON s.id = v.stock_item_id;

-- ══════════════════════════════════════════════════════════════
-- ROLLBACK (manual — run only if reverting)
-- ══════════════════════════════════════════════════════════════
-- UPDATE public.vaccines SET stock_item_id = NULL WHERE stock_item_id LIKE 'STOK-AŞI-%';
-- DELETE FROM public.stok WHERE id LIKE 'STOK-AŞI-%';

COMMIT;

-- PostgREST schema cache yenile
NOTIFY pgrst, 'reload schema';
-- Formal migration: tohumlama_sonuc_bos RPC standalone contract
-- Etkiler: tohumlama_sonuc_bos RPC (CREATE OR REPLACE)
-- Tablolar: tohumlama, hayvanlar, islem_log
-- Geri alınabilir: evet — DROP FUNCTION tohumlama_sonuc_bos(text,text);

BEGIN;

CREATE OR REPLACE FUNCTION public.tohumlama_abort(
  p_tohumlama_id text,
  p_notlar       text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh           record;
  v_islem_id      text := gen_random_uuid()::text;
  v_onceki_durum  text;
  v_onceki_tarih  date;
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama
  WHERE id::text = p_tohumlama_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  IF v_toh.sonuc != 'Gebe' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Gebe durumundaki tohumlama abort edilebilir');
  END IF;

  -- Hayvanın önceki tohumlama_durumu kaydet (geri alınabilmesi için)
  SELECT tohumlama_durumu, tohumlama_onay_tarihi INTO v_onceki_durum, v_onceki_tarih
  FROM public.hayvanlar
  WHERE id = v_toh.hayvan_id
    AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil');
  END IF;

  -- Tohumlama sonucunu Abort yap
  UPDATE public.tohumlama
  SET sonuc = 'Abort', abort_notlar = p_notlar
  WHERE id::text = p_tohumlama_id;

  -- Hayvanın tohumlama_durumu ve onay tarihini sıfırla
  UPDATE public.hayvanlar
  SET tohumlama_durumu = NULL,
      tohumlama_onay_tarihi = NULL
  WHERE id = v_toh.hayvan_id;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id,
    'ABORT_KAYDI',
    v_toh.hayvan_id,
    p_tohumlama_id,
    'tohumlama',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object(
          'tablo', 'tohumlama',
          'id', p_tohumlama_id,
          'onceki', jsonb_build_object('sonuc', v_toh.sonuc)
        ),
        jsonb_build_object(
          'tablo', 'hayvanlar',
          'id', v_toh.hayvan_id,
          'onceki', jsonb_build_object(
            'tohumlama_durumu', v_onceki_durum,
            'tohumlama_onay_tarihi', v_onceki_tarih
          )
        )
      ),
      'notlar', p_notlar
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$$;

COMMIT;
-- Migration: 20260502000003_drop_orphan_objects.sql
-- Date: 2026-05-02
-- Purpose: Clean up dead DB objects documented as unused in ARCHITECTURE.md §4.4
--
-- Removed objects:
--   1. buzagi_takip table — orphan, never referenced in application code
--   2. hastalik_log.ilac_stok_id — orphan column (system uses tedavi/cases/drug_administrations)
--   3. hastalik_log.ilac_miktar — orphan column (same as above)
--
-- References:
--   - ARCHITECTURE.md §4.4 (technical debt)
--   - egesut-deep-status-2026-05-02.md §3d

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Drop orphan table buzagi_takip
-- ─────────────────────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS public.buzagi_takip;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Drop orphan columns from hastalik_log
-- Note: mig-011 already dropped ilac_stok_id and ilac_miktar in 2026-04-27;
-- IF EXISTS is safe in case migration 011 was not yet applied.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.hastalik_log DROP COLUMN IF EXISTS ilac_stok_id;
ALTER TABLE public.hastalik_log DROP COLUMN IF EXISTS ilac_miktar;-- Migration: kizginlik_postpartum
-- 1. Add sonuc column to kizginlik_log
-- 2. Create kizginlik_yok_kaydet RPC for yoktu recordings

-- ============================================================
-- 1. Add sonuc column
-- ============================================================
ALTER TABLE public.kizginlik_log
  ADD COLUMN IF NOT EXISTS sonuc text DEFAULT 'GOZLEMLENDI';

-- ============================================================
-- 2. Create kizginlik_yok_kaydet RPC
-- ============================================================
CREATE OR REPLACE FUNCTION public.kizginlik_yok_kaydet(
  p_hayvan_id  text,
  p_dogum_id   text,
  p_notlar     text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_id     text := gen_random_uuid()::text;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  INSERT INTO public.kizginlik_log (id, hayvan_id, tarih, belirti, notlar, sonuc)
  VALUES (v_id, p_hayvan_id, CURRENT_DATE, NULL, p_notlar, 'YOKTU');

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.kizginlik_yok_kaydet TO anon, authenticated;-- Migration: Add dismiss columns to vaccination_log + vaccination_dismiss RPC
-- spec: spec-egesut-asi-dismiss Step 1

-- 1. Add dismiss columns to vaccination_log
ALTER TABLE public.vaccination_log
  ADD COLUMN IF NOT EXISTS ertelendi boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS erteleme_notu text;

-- 2. Create RPC vaccination_dismiss
CREATE OR REPLACE FUNCTION public.vaccination_dismiss(
  p_vaccination_id  uuid,
  p_note            text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_log   record;
  v_islem text := gen_random_uuid()::text;
BEGIN
  SELECT vl.*, v.name AS vaccine_name
  INTO v_log
  FROM public.vaccination_log vl
  LEFT JOIN public.vaccines v ON v.id = vl.vaccine_id
  WHERE vl.id = p_vaccination_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayıt bulunamadı');
  END IF;

  UPDATE public.vaccination_log
  SET ertelendi = true, erteleme_notu = p_note
  WHERE id = p_vaccination_id;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem,
    'ASI_ERTELEME',
    v_log.animal_id,
    p_vaccination_id::text,
    'vaccination_log',
    jsonb_build_object(
      'vaccine_name',    v_log.vaccine_name,
      'original_due',    v_log.next_due_date,
      'erteleme_notu',   p_note,
      'dismissed_at',    CURRENT_DATE
    )
  );

  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.vaccination_dismiss TO anon, authenticated;-- Migration: ileri_gebe_gorev_kontrol RPC + tohumlama_sonuc_gebe fix
-- Etkiler:
--   1. ileri_gebe_gorev_kontrol: yeni RPC — 240/260/261/265. gün görevleri (idempotent)
--   2. tohumlama_sonuc_gebe: 'Bekliyor' zorunluluğu kaldırıldı
-- Geri alınabilir: evet — DROP FUNCTION ileri_gebe_gorev_kontrol();

BEGIN;

-- 1. ileri_gebe_gorev_kontrol
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
  -- 1. Görevi çek ve kontrol et
  SELECT * INTO v_gorev FROM gorev_log WHERE id = p_gorev_id::uuid;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev bulunamadı');
  END IF;
  IF v_gorev.tamamlandi THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev zaten tamamlanmış');
  END IF;

  -- 2. Aşıyı kaydet (add_vaccination → vaccination_log + stok trigger)
  SELECT public.add_vaccination(
    v_gorev.hayvan_id::text, p_vaccine_id, p_tarih, p_doz, 'GorevID:' || p_gorev_id
  ) INTO v_vax_result;

  IF (v_vax_result->>'ok')::boolean = false THEN
    RETURN v_vax_result;
  END IF;

  -- 3. Görevi tamamla
  UPDATE gorev_log
  SET tamamlandi = true, tamamlanma_tarihi = now()
  WHERE id = p_gorev_id::uuid;

  -- 4. 1. doz ise rapel görevi oluştur (21 gün sonra)
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
      1,
      v_gorev.id,
      'ILERI_GEBE'
    )
    ON CONFLICT DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'vaccination_id', v_vax_result->>'vaccination_id',
    'rapel_gorev_id', v_rapel_id,
    'rapel_tarih', v_rapel_tarih
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.ileri_gebe_asi_tamamla(text,uuid,date,numeric) TO anon, authenticated;

END;
-- Migration: DB trigger — tohumlama Gebe olunca ileri gebe görevleri yarat
-- Etkiler:
--   1. fn_gebe_gorev_yarat(): 1. doz + SC Ademin + E Vitamini yarat (2. doz rapeli RPC yaratır)
--   2. trg_tohumlama_gebe_gorev: AFTER UPDATE ON tohumlama trigger
--   3. "2. doz — düve" catch-up görevleri silindi (rapel sadece RPC'den gelir)
-- Geri alınabilir: DROP TRIGGER trg_tohumlama_gebe_gorev ON tohumlama; DROP FUNCTION fn_gebe_gorev_yarat();

BEGIN;

CREATE TRIGGER trg_tohumlama_gebe_gorev
  AFTER UPDATE ON tohumlama
  FOR EACH ROW EXECUTE FUNCTION public.fn_gebe_gorev_yarat();

END;
-- Migration: gorev_geri_al RPC
-- Etkiler: Tamamlanan görevi geri al — vaccination + stok + child sil
-- Geri alınabilir: DROP FUNCTION public.gorev_geri_al(text);

BEGIN;

CREATE OR REPLACE FUNCTION public.gorev_geri_al(
  p_gorev_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev       gorev_log%ROWTYPE;
  v_vax_id      uuid;
  v_child_count integer;
BEGIN
  SELECT * INTO v_gorev FROM gorev_log WHERE id = p_gorev_id::uuid;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev bulunamadı');
  END IF;
  IF NOT v_gorev.tamamlandi THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev zaten aktif');
  END IF;

  IF v_gorev.tamamlanma_tarihi < now() - interval '7 days' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', '7 günden eski görevler geri alınamaz');
  END IF;

  IF EXISTS (SELECT 1 FROM gorev_log WHERE parent_id = p_gorev_id::uuid AND tamamlandi = true) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Rapel görevi tamamlanmış, geri alınamaz');
  END IF;

  SELECT id INTO v_vax_id FROM vaccination_log
  WHERE notes LIKE '%GorevID:' || p_gorev_id || '%'
  ORDER BY created_at DESC LIMIT 1;

  IF v_vax_id IS NOT NULL THEN
    DELETE FROM stok_hareket WHERE referans_tipi = 'vaccination' AND referans_id = v_vax_id::text;
    DELETE FROM vaccination_log WHERE id = v_vax_id;
  END IF;

  SELECT COUNT(*) INTO v_child_count FROM gorev_log WHERE parent_id = p_gorev_id::uuid;
  DELETE FROM gorev_log WHERE parent_id = p_gorev_id::uuid;

  UPDATE gorev_log
  SET tamamlandi = false, tamamlanma_tarihi = null
  WHERE id = p_gorev_id::uuid;

  RETURN jsonb_build_object(
    'ok', true,
    'silinen_rapel', v_child_count,
    'silinen_asi_id', v_vax_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.gorev_geri_al(text) TO anon, authenticated;

-- ── gorev_tamamla ──
DROP FUNCTION IF EXISTS public.gorev_tamamla(text, text, text, numeric, text, text);
CREATE OR REPLACE FUNCTION public.gorev_tamamla(
  p_gorev_id text,
  p_padok_hedef text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev record; v_hayvan record; v_snapshot jsonb;
  v_stok_dusuldu boolean := false; v_padok_guncellendi boolean := false;
  v_olusturulan jsonb := '[]'::jsonb; v_guncellenen jsonb := '[]'::jsonb;
  v_padok_id uuid;
BEGIN
  SELECT * INTO v_gorev FROM public.gorev_log WHERE id = p_gorev_id::uuid;
  IF NOT FOUND THEN RAISE EXCEPTION 'Görev bulunamadı: %', p_gorev_id; END IF;
  IF v_gorev.tamamlandi THEN RETURN jsonb_build_object('ok', true, 'mesaj', 'Görev zaten tamamlanmış'); END IF;
  IF v_gorev.iptal THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev iptal edilmiş, tamamlanamaz'); END IF;

  -- SUTTEN_KESME görevi → gerçek kesimi tetikle (her kaynaktan garanti)
  IF v_gorev.gorev_tipi = 'SUTTEN_KESME' AND v_gorev.hayvan_id IS NOT NULL THEN
    PERFORM public.buzagi_sutten_kesme_onayla(v_gorev.hayvan_id);
    UPDATE public.gorev_log SET tamamlandi=true, tamamlanma_tarihi=COALESCE(tamamlanma_tarihi, now())
      WHERE id=p_gorev_id::uuid AND tamamlandi=false;
    RETURN jsonb_build_object('ok', true, 'gorev_id', p_gorev_id, 'sutten_kesme', true);
  END IF;

  v_guncellenen := v_guncellenen || jsonb_build_object(
    'tablo','gorev_log','id',p_gorev_id,
    'onceki', jsonb_build_object('tamamlandi',v_gorev.tamamlandi,'tamamlanma_tarihi',v_gorev.tamamlanma_tarihi),
    'sonraki', jsonb_build_object('tamamlandi',true,'tamamlanma_tarihi',now())
  );
  UPDATE public.gorev_log SET tamamlandi=true, tamamlanma_tarihi=now() WHERE id=p_gorev_id::uuid;

  IF v_gorev.stok_id IS NOT NULL AND v_gorev.miktar IS NOT NULL AND v_gorev.miktar > 0 THEN
    v_stok_dusuldu := true;
    INSERT INTO public.stok_hareket (id,stok_id,tur,miktar,notlar,iptal)
    VALUES (gen_random_uuid(),v_gorev.stok_id,'Görev',v_gorev.miktar,'GorevID:'||p_gorev_id,false);
  END IF;

  IF p_padok_hedef IS NOT NULL AND v_gorev.hayvan_id IS NOT NULL THEN
    SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id=v_gorev.hayvan_id;
    IF FOUND THEN
      v_padok_guncellendi := true;
      -- BUG B fix: padok_id de güncellenir
      SELECT id INTO v_padok_id FROM public.padoklar WHERE ad=p_padok_hedef;
      UPDATE public.hayvanlar
         SET padok=p_padok_hedef, padok_id=COALESCE(v_padok_id, padok_id)
       WHERE id=v_gorev.hayvan_id;
      -- BUG A fix: 'Sağmal (Kuru Dönem)' yerine eslem-kanonik 'Sağmal (Kuru)'
      IF v_gorev.gorev_tipi='PADOK_DEGISIM' AND v_gorev.aciklama ILIKE '%Kuru döneme%' THEN
        UPDATE public.hayvanlar SET grup='Sağmal (Kuru)' WHERE id=v_gorev.hayvan_id;
      END IF;
    END IF;
  END IF;

  v_snapshot := jsonb_build_object('olusturulan',v_olusturulan,'guncellenen',v_guncellenen,'silinen','[]'::jsonb);
  INSERT INTO public.islem_log (tip,ana_hayvan_id,ref_id,ref_tablo,snapshot,kullanici_notu)
  VALUES ('GOREV_TAMAMLA',v_gorev.hayvan_id,p_gorev_id,'gorev_log',v_snapshot,
    format('Görev tamamlandı (stok: %s, padok: %s)',
      CASE WHEN v_stok_dusuldu THEN 'evet' ELSE 'hayır' END,
      CASE WHEN v_padok_guncellendi THEN 'evet' ELSE 'hayır' END));

  RETURN jsonb_build_object('ok',true,'gorev_id',p_gorev_id,'stok_dusuldu',v_stok_dusuldu,'padok_guncellendi',v_padok_guncellendi);
END;
$$;
GRANT EXECUTE ON FUNCTION public.gorev_tamamla(text,text) TO anon, authenticated;

-- ── gorev_guncelle ──
CREATE OR REPLACE FUNCTION public.gorev_guncelle(
  p_id text,
  p_aciklama text DEFAULT NULL,
  p_hedef_tarih text DEFAULT NULL,
  p_gorev_tipi text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.gorev_log
  SET
    aciklama    = COALESCE(p_aciklama,    aciklama),
    hedef_tarih = COALESCE(p_hedef_tarih::date, hedef_tarih),
    gorev_tipi  = COALESCE(p_gorev_tipi,  gorev_tipi)
  WHERE id = p_id::uuid;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev bulunamadı');
  END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.gorev_guncelle(text, text, text, text) TO anon, authenticated;

END;
-- Migration: padoklar + grup_padok_eslem tables, hayvanlar.padok_id FK, view update
-- Note: View DROP CASCADE was needed due to tohumlanabilir_hayvanlar dependency

BEGIN;

-- 1. padoklar tablosu
CREATE TABLE IF NOT EXISTS public.padoklar (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  ad text NOT NULL UNIQUE,
  kapasite integer,
  aktif boolean DEFAULT true,
  sira integer DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.padoklar ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "padoklar_all" ON public.padoklar;
CREATE POLICY "padoklar_all" ON public.padoklar FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON public.padoklar TO anon, authenticated;

-- 2. Seed padoklar with exact Turkish chars
INSERT INTO public.padoklar (ad, sira) VALUES
  ('Sağmal Padok', 1),
  ('Kuru/Gebe Padok', 2),
  ('Düve Padok (Büyük)', 3),
  ('Düve Padok (Küçük)', 4),
  ('Buzağı Padok (Süt İçenler)', 5),
  ('Buzağı Padok (Sütten Kesilmiş)', 6),
  ('Besi Padok (Erkek)', 7),
  ('Besi Padok (Dişi)', 8)
ON CONFLICT (ad) DO NOTHING;

-- 3. grup_padok_eslem tablosu
CREATE TABLE IF NOT EXISTS public.grup_padok_eslem (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  grup text NOT NULL,
  padok_id uuid NOT NULL REFERENCES public.padoklar(id) ON DELETE CASCADE,
  UNIQUE(grup, padok_id)
);

ALTER TABLE public.grup_padok_eslem ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "gpe_all" ON public.grup_padok_eslem;
CREATE POLICY "gpe_all" ON public.grup_padok_eslem FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON public.grup_padok_eslem TO anon, authenticated;

-- 4. Seed grup_padok_eslem (Gebe İnek added — exists in production)
INSERT INTO public.grup_padok_eslem (grup, padok_id)
SELECT val.grup, p.id
FROM (VALUES
  ('Sağmal (Laktasyonda)', 'Sağmal Padok'),
  ('Sağmal (Kuru)', 'Kuru/Gebe Padok'),
  ('Gebe Düve', 'Kuru/Gebe Padok'),
  ('Gebe İnek', 'Kuru/Gebe Padok'),
  ('Düve (Büyük)', 'Düve Padok (Büyük)'),
  ('Düve (Küçük)', 'Düve Padok (Küçük)'),
  ('Süt İçen Buzağı', 'Buzağı Padok (Süt İçenler)'),
  ('Sütten Kesilmiş Buzağı', 'Buzağı Padok (Sütten Kesilmiş)'),
  ('Besi', 'Besi Padok (Erkek)'),
  ('Besi', 'Besi Padok (Dişi)')
) AS val(grup, padok_ad)
JOIN public.padoklar p ON p.ad = val.padok_ad
ON CONFLICT (grup, padok_id) DO NOTHING;

-- 5. hayvanlar.padok_id FK
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS padok_id uuid REFERENCES public.padoklar(id);

-- 6. Migrate existing TEXT values to padok_id
UPDATE public.hayvanlar h
SET padok_id = p.id
FROM public.padoklar p
WHERE h.padok = p.ad AND h.padok_id IS NULL;

END;

-- View update requires CASCADE (tohumlanabilir_hayvanlar depends on hayvan_durum_view)
DROP VIEW IF EXISTS public.tohumlanabilir_hayvanlar CASCADE;
DROP VIEW IF EXISTS public.hayvan_durum_view CASCADE;

CREATE VIEW public.tohumlanabilir_hayvanlar AS
SELECT id, kupe_no, devlet_kupe, irk, cinsiyet, dogum_tarihi,
  grup, padok_id, padok, durum, anne_id, kategori,
  tohumlama_durumu, tohumlama_onay_tarihi, suttten_kesme_tarihi,
  cikis_tipi, cikis_tarihi, cikis_sebebi, satis_fiyati, notlar,
  dogum_kg, canli_agirlik, boy, renk, ayirici_ozellik, baba_bilgi, abort_sayisi,
  yas_gun, tohumlama_esik_gun,
  toh_id, toh_tarih, sperma, toh_sonuc, toh_gun,
  aktif_hastalik_sayisi, hesap_kategori,
  tohumlama_bildirisi_gerekli, suttten_kesme_bildirisi_gerekli,
  dogum_yaklasti, dogum_gecikme_gun, tohumlama_durumu_hesap
FROM hayvan_durum_view
WHERE tohumlama_durumu_hesap = 'tohumlanabilir';

GRANT SELECT ON public.tohumlanabilir_hayvanlar TO anon, authenticated;
-- Migration: hekimler tablosu oluştur (production'da yoktu) + hekim_sil + sperma_sil RPCs
BEGIN;

-- hekimler tablosu (lokal migration 009 DB'ye uygulanmamıştı)
CREATE TABLE IF NOT EXISTS public.hekimler (
  id      text PRIMARY KEY,
  ad      text NOT NULL,
  telefon text,
  aktif   boolean NOT NULL DEFAULT true
);

INSERT INTO public.hekimler (id, ad, aktif) VALUES
  ('H1', 'Melik Tokur',        true),
  ('H2', 'Hüseyin Aygün',      true),
  ('H3', 'Süleyman Kocabaş',   true)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.hekimler ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "hekimler_all" ON public.hekimler;
CREATE POLICY "hekimler_all" ON public.hekimler FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON public.hekimler TO anon, authenticated;

-- hekim_sil: constraint check then delete
CREATE OR REPLACE FUNCTION public.hekim_sil(p_hekim_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM hekimler WHERE id = p_hekim_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hekim bulunamadi');
  END IF;
  IF EXISTS (SELECT 1 FROM tohumlama WHERE hekim_id = p_hekim_id LIMIT 1) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tohumlama kaydi olan hekim silinemez');
  END IF;
  IF EXISTS (SELECT 1 FROM dogum WHERE hekim_id = p_hekim_id LIMIT 1) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Dogum kaydi olan hekim silinemez');
  END IF;
  DELETE FROM hekimler WHERE id = p_hekim_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.hekim_sil(text) TO anon, authenticated;

-- sperma_sil: check tohumlama references then delete from stok
CREATE OR REPLACE FUNCTION public.sperma_sil(p_stok_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_urun_adi text;
BEGIN
  SELECT urun_adi INTO v_urun_adi FROM stok WHERE id = p_stok_id AND kategori = 'Sperma';
  IF v_urun_adi IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Sperma stok kaydi bulunamadi');
  END IF;
  IF EXISTS (SELECT 1 FROM tohumlama WHERE sperma = v_urun_adi LIMIT 1) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Tohumlama kaydinda kullanilan sperma silinemez');
  END IF;
  DELETE FROM stok_hareket WHERE stok_id = p_stok_id;
  DELETE FROM stok WHERE id = p_stok_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.sperma_sil(text) TO anon, authenticated;

END;
-- Migration: hayvan_ekle + hayvan_guncelle RPCs now accept p_padok_id (uuid)
-- Backward compat: p_padok text still works via name lookup
BEGIN;

CREATE OR REPLACE FUNCTION public.hayvan_ekle(
  p_kupe_no        text    DEFAULT NULL,
  p_devlet_kupe    text    DEFAULT NULL,
  p_irk            text    DEFAULT NULL,
  p_cinsiyet       text    DEFAULT NULL,
  p_dogum_tarihi   date    DEFAULT NULL,
  p_grup           text    DEFAULT 'Genel',
  p_padok          text    DEFAULT NULL,
  p_dogum_kg       numeric DEFAULT NULL,
  p_anne_id        text    DEFAULT NULL,
  p_baba_bilgi     text    DEFAULT NULL,
  p_canli_agirlik  numeric DEFAULT NULL,
  p_boy            numeric DEFAULT NULL,
  p_renk           text    DEFAULT NULL,
  p_ayirici_ozellik text   DEFAULT NULL,
  p_padok_id       uuid    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id text;
  v_padok_id uuid;
  v_padok_ad text;
BEGIN
  v_id := gen_random_uuid()::text;

  IF p_padok_id IS NOT NULL THEN
    v_padok_id := p_padok_id;
    SELECT ad INTO v_padok_ad FROM padoklar WHERE id = p_padok_id;
  ELSIF p_padok IS NOT NULL THEN
    SELECT id, ad INTO v_padok_id, v_padok_ad FROM padoklar WHERE ad = p_padok;
    IF v_padok_id IS NULL THEN
      v_padok_ad := p_padok;
    END IF;
  END IF;

  INSERT INTO hayvanlar (
    id, kupe_no, devlet_kupe, irk, cinsiyet, dogum_tarihi,
    grup, padok, padok_id, durum, dogum_kg, anne_id, baba_bilgi,
    canli_agirlik, boy, renk, ayirici_ozellik
  ) VALUES (
    v_id, NULLIF(p_kupe_no,''), NULLIF(p_devlet_kupe,''),
    NULLIF(p_irk,''), p_cinsiyet, p_dogum_tarihi,
    p_grup, v_padok_ad, v_padok_id, 'Aktif', p_dogum_kg, p_anne_id, p_baba_bilgi,
    p_canli_agirlik, p_boy, p_renk, p_ayirici_ozellik
  );

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.hayvan_guncelle(
  p_id              text,
  p_kupe_no         text    DEFAULT NULL,
  p_devlet_kupe     text    DEFAULT NULL,
  p_irk             text    DEFAULT NULL,
  p_cinsiyet        text    DEFAULT NULL,
  p_dogum_tarihi    date    DEFAULT NULL,
  p_grup            text    DEFAULT NULL,
  p_padok           text    DEFAULT NULL,
  p_dogum_kg        numeric DEFAULT NULL,
  p_canli_agirlik   numeric DEFAULT NULL,
  p_boy             numeric DEFAULT NULL,
  p_renk            text    DEFAULT NULL,
  p_ayirici_ozellik text    DEFAULT NULL,
  p_baba_bilgi      text    DEFAULT NULL,
  p_notlar          text    DEFAULT NULL,
  p_anne_id         text    DEFAULT NULL,
  p_padok_id        uuid    DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_padok_id uuid;
  v_padok_ad text;
BEGIN
  IF p_padok_id IS NOT NULL THEN
    v_padok_id := p_padok_id;
    SELECT ad INTO v_padok_ad FROM padoklar WHERE id = p_padok_id;
  ELSIF p_padok IS NOT NULL THEN
    SELECT id, ad INTO v_padok_id, v_padok_ad FROM padoklar WHERE ad = p_padok;
  END IF;

  UPDATE hayvanlar SET
    kupe_no          = COALESCE(NULLIF(p_kupe_no,''),        kupe_no),
    devlet_kupe      = COALESCE(NULLIF(p_devlet_kupe,''),    devlet_kupe),
    irk              = COALESCE(NULLIF(p_irk,''),            irk),
    cinsiyet         = COALESCE(NULLIF(p_cinsiyet,''),       cinsiyet),
    dogum_tarihi     = COALESCE(p_dogum_tarihi,              dogum_tarihi),
    grup             = COALESCE(NULLIF(p_grup,''),           grup),
    padok            = COALESCE(v_padok_ad,                  padok),
    padok_id         = COALESCE(v_padok_id,                  padok_id),
    dogum_kg         = COALESCE(p_dogum_kg,                  dogum_kg),
    canli_agirlik    = COALESCE(p_canli_agirlik,             canli_agirlik),
    boy              = COALESCE(p_boy,                       boy),
    renk             = COALESCE(NULLIF(p_renk,''),           renk),
    ayirici_ozellik  = COALESCE(NULLIF(p_ayirici_ozellik,''),ayirici_ozellik),
    baba_bilgi       = COALESCE(NULLIF(p_baba_bilgi,''),     baba_bilgi),
    notlar           = COALESCE(NULLIF(p_notlar,''),         notlar),
    anne_id          = COALESCE(NULLIF(p_anne_id,''),        anne_id)
  WHERE id = p_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

END;
-- Migration: add_vaccination RPC — primer 2.doz + muadil gecmis kontrolu (Faz 1.5)
-- Changes:
--   1. vaccine_protocol_steps adim_no=2 -> primer 2.doz gorevi (naive hayvanda)
--   2. Muadil naive: vaccine_diseases ortak disease_id ile gecmis kontrolu
--   3. p_next_offset_days (modal offset override). Eski 5-param overload migration'da DROP edildi.
--   4. Korunan: gorev_tipi='ASI_RAPEL', aciklama name-prefix, GorevID: branch, duplicate guard, islem_log
BEGIN;

CREATE OR REPLACE FUNCTION public.add_vaccination(
  p_animal_id        text,
  p_vaccine_id       uuid,
  p_date             date    DEFAULT CURRENT_DATE,
  p_dose_override    numeric DEFAULT NULL,
  p_notes            text    DEFAULT NULL,
  p_next_offset_days int     DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_vaccine     record;
  v_new_id      uuid;
  v_next_due    date;
  v_dose        numeric;
  v_animal      record;
  v_islem_id    text := gen_random_uuid()::text;
  v_is_gorev_triggered boolean;
  v_is_naive    boolean;
  v_step2       int;
  v_offset      int;
  v_label       text;
BEGIN
  SELECT * INTO v_animal FROM public.hayvanlar WHERE id = p_animal_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadi veya aktif degil');
  END IF;

  SELECT * INTO v_vaccine FROM public.vaccines WHERE id = p_vaccine_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Asi kaydi bulunamadi');
  END IF;

  v_dose := COALESCE(p_dose_override, v_vaccine.dose);

  -- vaccination_log INSERT -> trg_vaccination_stok stok dusum + yetersiz stok EXCEPTION
  INSERT INTO public.vaccination_log (
    animal_id, vaccine_id, vaccination_date, dose_given, unit, route, next_due_date, notes
  ) VALUES (
    p_animal_id, p_vaccine_id, p_date, v_dose,
    v_vaccine.unit, v_vaccine.route, NULL, p_notes
  )
  RETURNING id INTO v_new_id;

  v_is_gorev_triggered := (p_notes IS NOT NULL AND p_notes LIKE 'GorevID:%');

  -- Sonraki gorev offset belirleme (ileri_gebe kendi rapelini yaratir -> skip)
  v_offset := NULL;
  v_label  := NULL;
  IF NOT v_is_gorev_triggered THEN
    -- muadil naive: bu asinin kapsadigi hastaligi kapsayan onceki kayit var mi? (yeni satir haric)
    v_is_naive := NOT EXISTS (
      SELECT 1 FROM public.vaccination_log vl
      WHERE vl.animal_id = p_animal_id
        AND vl.id <> v_new_id
        AND (
          vl.vaccine_id = p_vaccine_id
          OR EXISTS (
            SELECT 1
            FROM public.vaccine_diseases a
            JOIN public.vaccine_diseases b ON b.disease_id = a.disease_id
            WHERE a.vaccine_id = p_vaccine_id
              AND b.vaccine_id = vl.vaccine_id
          )
        )
    );

    SELECT offset_gun INTO v_step2
    FROM public.vaccine_protocol_steps
    WHERE vaccine_id = p_vaccine_id AND adim_no = 2
    LIMIT 1;

    IF v_is_naive AND v_step2 IS NOT NULL THEN
      v_offset := v_step2;                        v_label := ' (2. doz)';
    ELSIF v_vaccine.repeat_interval_days IS NOT NULL THEN
      v_offset := v_vaccine.repeat_interval_days; v_label := ' (rapel)';
    END IF;

    -- modal override
    v_offset := COALESCE(p_next_offset_days, v_offset);
  END IF;

  IF v_offset IS NOT NULL THEN
    v_next_due := p_date + (v_offset || ' days')::interval;
    UPDATE public.vaccination_log SET next_due_date = v_next_due WHERE id = v_new_id;

    INSERT INTO public.gorev_log (
      hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi,
      stok_id, miktar, kaynak
    )
    SELECT
      p_animal_id, 'ASI_RAPEL',
      v_vaccine.name || COALESCE(v_label,''),
      v_next_due, false,
      v_vaccine.stock_item_id, v_dose, 'ASI_RAPEL'
    WHERE NOT EXISTS (
      SELECT 1 FROM public.gorev_log
      WHERE hayvan_id = p_animal_id
        AND gorev_tipi = 'ASI_RAPEL'
        AND hedef_tarih = v_next_due
        AND aciklama LIKE v_vaccine.name || '%'
        AND tamamlandi = false
    );
  END IF;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id, 'ASI_KAYDI', p_animal_id, v_new_id::text, 'vaccination_log',
    jsonb_build_object(
      'olusturulan', jsonb_build_array(jsonb_build_object('tablo','vaccination_log','id',v_new_id::text)),
      'guncellenen', '[]'::jsonb,
      'vaccine_name', v_vaccine.name,
      'next_due', v_next_due
    )
  );

  RETURN jsonb_build_object('ok', true, 'vaccination_id', v_new_id, 'next_due', v_next_due, 'islem_id', v_islem_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_vaccination(text,uuid,date,numeric,text,int) TO anon, authenticated;

END;
-- Migration: stok_duzelt RPC for stock count correction
BEGIN;

CREATE OR REPLACE FUNCTION public.stok_duzelt(
  p_stok_id text,
  p_yeni_miktar numeric,
  p_not text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok record;
  v_guncel numeric;
  v_fark numeric;
BEGIN
  SELECT * INTO v_stok FROM stok WHERE id = p_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok bulunamadi');
  END IF;

  SELECT COALESCE(v_stok.baslangic_miktar, 0) - COALESCE(SUM(sh.miktar), 0)
  INTO v_guncel
  FROM stok_hareket sh
  WHERE sh.stok_id = p_stok_id AND NOT sh.iptal;

  v_guncel := COALESCE(v_guncel, COALESCE(v_stok.baslangic_miktar, 0));
  v_fark := v_guncel - p_yeni_miktar;

  IF v_fark = 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Miktar zaten aynı');
  END IF;

  INSERT INTO stok_hareket (stok_id, tur, miktar, notlar, iptal, referans_tipi)
  VALUES (p_stok_id, 'Duzeltme', v_fark, COALESCE(p_not, 'Sayim duzeltmesi'), false, 'duzeltme');

  RETURN jsonb_build_object('ok', true, 'eski', v_guncel, 'yeni', p_yeni_miktar, 'fark', v_fark);
END;
$$;

GRANT EXECUTE ON FUNCTION public.stok_duzelt(text, numeric, text) TO anon, authenticated;

END;

CREATE OR REPLACE FUNCTION public.padok_degistir(
  p_hayvan_id text,
  p_yeni_padok_id uuid,
  p_not text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_hayvan        hayvanlar%ROWTYPE;
  v_yeni_padok    padoklar%ROWTYPE;
  v_aktif_sayisi  integer;
  v_doluluk_yuzde integer;
  v_kapasite_uyari boolean := false;
BEGIN
  -- Hayvan var mı?
  SELECT * INTO v_hayvan FROM hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hayvan bulunamadı');
  END IF;

  -- Hedef padok var mı?
  SELECT * INTO v_yeni_padok FROM padoklar WHERE id = p_yeni_padok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef padok bulunamadı');
  END IF;

  -- Zaten aynı padokta mı?
  IF v_hayvan.padok_id = p_yeni_padok_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hayvan zaten bu padokta');
  END IF;

  -- Kapasite kontrolü
  IF v_yeni_padok.kapasite IS NOT NULL THEN
    SELECT COUNT(*) INTO v_aktif_sayisi
      FROM hayvanlar
      WHERE padok_id = p_yeni_padok_id AND durum = 'Aktif';

    IF v_aktif_sayisi >= v_yeni_padok.kapasite THEN
      RETURN jsonb_build_object(
        'success', false,
        'error',   'kapasite_dolu',
        'detay',   v_aktif_sayisi::text || '/' || v_yeni_padok.kapasite::text
      );
    END IF;

    v_doluluk_yuzde  := ROUND((v_aktif_sayisi::numeric / v_yeni_padok.kapasite) * 100);
    v_kapasite_uyari := v_doluluk_yuzde >= 80;
  END IF;

  -- Güncelle
  UPDATE hayvanlar
     SET padok_id   = p_yeni_padok_id,
         padok      = v_yeni_padok.ad,
         updated_at = now()
   WHERE id = p_hayvan_id;

  -- İşlem logu (correct columns for islem_log table)
  INSERT INTO islem_log (tip, ana_hayvan_id, ref_id, snapshot, kullanici_notu)
  VALUES ('padok_degisim', p_hayvan_id, p_hayvan_id, '{}'::jsonb,
          COALESCE(p_not, 'Padok değiştirildi → ' || v_yeni_padok.ad));

  RETURN jsonb_build_object(
    'success',         true,
    'yeni_padok',      v_yeni_padok.ad,
    'yeni_padok_id',   p_yeni_padok_id,
    'kapasite_uyari',  v_kapasite_uyari
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.padok_degistir(text, uuid, text) TO anon, authenticated;

-- Drop old overloads (without p_etiketler / without p_yeni_grup) to avoid ambiguity
DROP FUNCTION IF EXISTS public.padok_degistir_toplu(text[], uuid);
DROP FUNCTION IF EXISTS public.padok_degistir_toplu(text[], uuid, text[]);

CREATE OR REPLACE FUNCTION public.padok_degistir_toplu(
  p_hayvan_ids text[],
  p_yeni_padok_id uuid,
  p_etiketler text[] DEFAULT NULL,
  p_yeni_grup text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_yeni_padok   padoklar%ROWTYPE;
  v_aktif_sayisi integer;
  v_hayvan_id    text;
  v_hayvan       hayvanlar%ROWTYPE;
  v_eslem_var    boolean;
BEGIN
  -- Hedef padok var mı?
  SELECT * INTO v_yeni_padok FROM padoklar WHERE id = p_yeni_padok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Hedef padok bulunamadı');
  END IF;

  -- Grup-padok uyum guard (UI bypass koruması)
  IF p_yeni_grup IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM grup_padok_eslem
      WHERE grup = p_yeni_grup AND padok_id = p_yeni_padok_id
    ) INTO v_eslem_var;
    IF NOT v_eslem_var THEN
      RETURN jsonb_build_object('success', false, 'error', 'grup_padok_uyumsuz');
    END IF;
  END IF;

  -- Kapasite hard block (validasyon, yazma yok)
  IF v_yeni_padok.kapasite IS NOT NULL THEN
    SELECT COUNT(*) INTO v_aktif_sayisi
      FROM hayvanlar
      WHERE padok_id = p_yeni_padok_id AND durum = 'Aktif';

    IF v_aktif_sayisi + array_length(p_hayvan_ids, 1) > v_yeni_padok.kapasite THEN
      RETURN jsonb_build_object(
        'success', false,
        'error',   'kapasite_dolu',
        'detay',   (v_aktif_sayisi + array_length(p_hayvan_ids, 1))::text
                   || '/' || v_yeni_padok.kapasite::text
      );
    END IF;
  END IF;

  -- Hayvan validasyonları (validasyon, yazma yok)
  FOREACH v_hayvan_id IN ARRAY p_hayvan_ids LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_hayvan_id;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hayvan bulunamadı: ' || v_hayvan_id);
    END IF;
    IF v_hayvan.padok_id = p_yeni_padok_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'Hayvan zaten bu padokta: ' || v_hayvan_id);
    END IF;
  END LOOP;

  -- Tüm validasyonlar geçti — yazma işlemleri
  FOREACH v_hayvan_id IN ARRAY p_hayvan_ids LOOP
    UPDATE hayvanlar
       SET padok_id   = p_yeni_padok_id,
           padok      = v_yeni_padok.ad,
           grup       = COALESCE(p_yeni_grup, grup),
           updated_at = now()
     WHERE id = v_hayvan_id;

    INSERT INTO islem_log (tip, ana_hayvan_id, ref_id, snapshot, kullanici_notu)
    VALUES ('padok_degisim', v_hayvan_id, v_hayvan_id, '{}'::jsonb,
            'Toplu padok değişimi → ' || v_yeni_padok.ad
            || COALESCE(' (grup: ' || p_yeni_grup || ')', ''));
  END LOOP;

  -- Etiket güncelleme (varsa, mevcut etiketlerle birleştir)
  IF p_etiketler IS NOT NULL AND array_length(p_etiketler, 1) > 0 THEN
    UPDATE hayvanlar
       SET etiketler = array(
             SELECT DISTINCT unnest(COALESCE(etiketler, '{}') || p_etiketler)
           )
     WHERE id = ANY(p_hayvan_ids);
  END IF;

  RETURN jsonb_build_object(
    'success',       true,
    'hayvan_sayisi', array_length(p_hayvan_ids, 1),
    'yeni_padok',    v_yeni_padok.ad,
    'yeni_padok_id', p_yeni_padok_id,
    'yeni_grup',     p_yeni_grup
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.padok_degistir_toplu(text[], uuid, text[], text) TO anon, authenticated;

-- Reconciliation scan: hedefte olup görevi açık kalan transfer görevlerini kapat (idempotent, 2026-06-18)
CREATE OR REPLACE FUNCTION public.padok_transfer_gorev_uzlastir()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_kapatilan integer;
BEGIN
  WITH kapatilacak AS (
    SELECT g.id
    FROM public.gorev_log g
    JOIN public.hayvanlar h ON h.id = g.hayvan_id
    WHERE g.gorev_tipi = 'PADOK_DEGISIM'
      AND g.tamamlandi = false
      AND g.iptal = false
      AND g.padok_hedef IS NOT NULL
      AND g.padok_hedef = h.padok
  ), upd AS (
    UPDATE public.gorev_log
       SET tamamlandi = true, tamamlanma_tarihi = now()
     WHERE id IN (SELECT id FROM kapatilacak)
     RETURNING id
  )
  SELECT count(*) INTO v_kapatilan FROM upd;

  RETURN jsonb_build_object('ok', true, 'kapatilan', v_kapatilan);
END;
$$;
GRANT EXECUTE ON FUNCTION public.padok_transfer_gorev_uzlastir() TO anon, authenticated;

-- Migration: islem_log trigger'a OLD snapshot desteği
-- hayvanlar UPDATE ve gorev_log UPDATE için OLD+NEW kaydedilir
BEGIN;

CREATE OR REPLACE FUNCTION public.islem_geri_al(
  p_islem_id text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_islem record;
  v_old jsonb;
  v_tablo text;
  v_id text;
  v_col text;
  v_val jsonb;
  v_sets text[] := ARRAY[]::text[];
  v_pairs text;
BEGIN
  -- İşlemi bul
  SELECT * INTO v_islem FROM public.islem_log WHERE id = p_islem_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Islem bulunamadi');
  END IF;

  IF v_islem.durum = 'geri_alindi' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu islem zaten geri alinmis');
  END IF;

  -- Snapshot'ta old objesi var mı?
  v_old := v_islem.snapshot->'old';
  IF v_old IS NULL OR v_old = 'null'::jsonb THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu islem icin geri alma verisi bulunamadi. Sadece yeni islemler destekleniyor.');
  END IF;

  -- Hedef tabloyu belirle
  CASE v_islem.tip
    WHEN 'HAYVAN_GUNCELLENDI' THEN
      -- old'daki tüm kolonları geri yükle (id hariç)
      FOR v_col, v_val IN SELECT * FROM jsonb_each(v_old)
      LOOP
        IF v_col != 'id' THEN
          -- #>> '{}' jsonb değerini text'e çevirir (tırnakları kaldırır)
          v_sets := array_append(v_sets, format('%I = %L', v_col, v_val #>> '{}'));
        END IF;
      END LOOP;
      v_pairs := array_to_string(v_sets, ', ');
      EXECUTE format('UPDATE hayvanlar SET %s WHERE id = %L', v_pairs, v_old->>'id');

    WHEN 'GOREV_GUNCELLENDI' THEN
      -- Görev geri alma
      FOR v_col, v_val IN SELECT * FROM jsonb_each(v_old)
      LOOP
        IF v_col != 'id' THEN
          v_sets := array_append(v_sets, format('%I = %L', v_col, v_val #>> '{}'));
        END IF;
      END LOOP;
      v_pairs := array_to_string(v_sets, ', ');
      EXECUTE format('UPDATE gorev_log SET %s WHERE id = %L', v_pairs, v_old->>'id');

    ELSE
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu islem tipi icin geri alma desteklenmiyor: ' || v_islem.tip);
  END CASE;

  -- İşlemi geri alındı olarak işaretle
  UPDATE public.islem_log
  SET durum = 'geri_alindi',
      geri_alma_tarihi = now()
  WHERE id = p_islem_id;

  RETURN jsonb_build_object('ok', true, 'mesaj', 'Islem geri alindi');
END;
$$;

GRANT EXECUTE ON FUNCTION public.islem_geri_al(text) TO anon, authenticated;

COMMIT;-- Migration: timeline view'da padok değişikliğini vurgula
-- HAYVAN_GUNCELLENDI event'lerinde snapshot->old->padok_id vs snapshot->new->padok_id karşılaştırması
BEGIN;

DROP VIEW IF EXISTS public.hayvan_timeline_view;

CREATE VIEW public.hayvan_timeline_view AS
-- Doğum
SELECT
  d.anne_id                        AS hayvan_id,
  'DOGUM_KAYDI'                    AS tip,
  'birth_recorded'                 AS event_type,
  d.tarih::timestamptz             AS zaman,
  jsonb_build_object(
    'yavru_kupe', d.yavru_kupe,
    'yavru_cins', d.yavru_cins,
    'dogum_tipi', d.dogum_tipi,
    'dogum_kg',   d.dogum_kg,
    'hekim_id',   d.hekim_id
  )                                AS detay,
  d.id::text                       AS kaynak_id
FROM public.dogum d

UNION ALL

-- Tohumlama
SELECT
  t.hayvan_id,
  'TOHUMLAMA'                      AS tip,
  'insemination_performed'         AS event_type,
  t.tarih::timestamptz             AS zaman,
  jsonb_build_object(
    'sperma',      t.sperma,
    'sonuc',       t.sonuc,
    'deneme_no',   t.deneme_no,
    'hekim_id',    t.hekim_id
  )                                AS detay,
  t.id::text                       AS kaynak_id
FROM public.tohumlama t

UNION ALL

-- Hastalık
SELECT
  hl.hayvan_id,
  'HASTALIK_KAYDI'                 AS tip,
  'treatment_recorded'             AS event_type,
  hl.tarih::timestamptz            AS zaman,
  jsonb_build_object(
    'tani',      hl.tani,
    'kategori',  hl.kategori,
    'siddet',    hl.siddet,
    'durum',     hl.durum,
    'hekim_id',  hl.hekim_id
  )                                AS detay,
  hl.id::text                       AS kaynak_id
FROM public.hastalik_log hl

UNION ALL

-- Kızgınlık
SELECT
  kl.hayvan_id,
  'KIZGINLIK'                      AS tip,
  'estrus_detected'                AS event_type,
  kl.tarih::timestamptz            AS zaman,
  jsonb_build_object(
    'belirti', kl.belirti,
    'notlar',  kl.notlar
  )                                AS detay,
  kl.id::text                       AS kaynak_id
FROM public.kizginlik_log kl

UNION ALL

-- Hayvan Güncellemeleri (islem_log'dan, PADOK_ODAKLI)
SELECT
  il.ana_hayvan_id                 AS hayvan_id,
  il.tip,
  COALESCE(il.payload->>'event_type', lower(il.tip)) AS event_type,
  il.tarih                         AS zaman,
  CASE
    -- Padok değişikliği varsa detaya ekle
    WHEN il.snapshot ? 'old' AND il.snapshot->'old' ? 'padok_id'
         AND il.snapshot->'old'->>'padok_id' IS DISTINCT FROM il.snapshot->'new'->>'padok_id'
    THEN jsonb_build_object(
      'padok_degisti', true,
      'eski_padok', il.snapshot->'old'->>'padok',
      'yeni_padok', il.snapshot->'new'->>'padok',
      'eski_padok_id', il.snapshot->'old'->>'padok_id',
      'yeni_padok_id', il.snapshot->'new'->>'padok_id'
    )
    ELSE jsonb_build_object('padok_degisti', false)
  END                               AS detay,
  il.id::text                        AS kaynak_id
FROM public.islem_log il
WHERE il.tip IN ('HAYVAN_GUNCELLENDI', 'HAYVAN_EKLENDI')

UNION ALL

-- Diğer islem_log tipleri (ABORT, SATIS, OLUM, SUTTEN_KESME)
SELECT
  il.ana_hayvan_id                 AS hayvan_id,
  il.tip,
  COALESCE(il.payload->>'event_type', lower(il.tip)) AS event_type,
  il.tarih                         AS zaman,
  COALESCE(il.payload->'meta', il.snapshot) AS detay,
  il.id                             AS kaynak_id
FROM public.islem_log il
WHERE il.tip IN ('ABORT_KAYDI', 'SATIS_KAYDI', 'OLUM_KAYDI', 'SUTTEN_KESME')

ORDER BY zaman DESC;

GRANT SELECT ON public.hayvan_timeline_view TO anon, authenticated;

COMMIT;-- Migration: tohumlama_sonuc_bos RPC
BEGIN;

CREATE OR REPLACE FUNCTION public._islem_log_yaz()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_tip          text;
  v_hayvan_id    text;
  v_snapshot     jsonb;
  v_payload      jsonb;
BEGIN
  CASE TG_TABLE_NAME
    WHEN 'hayvanlar' THEN
      v_tip := CASE TG_OP WHEN 'INSERT' THEN 'HAYVAN_EKLENDI' ELSE 'HAYVAN_GUNCELLENDI' END;
      v_hayvan_id := NEW.id;
      IF TG_OP = 'UPDATE' THEN
        v_snapshot := jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW));
      ELSE
        v_snapshot := to_jsonb(NEW);
      END IF;
    WHEN 'dogum' THEN
      v_tip := 'DOGUM_KAYDI';
      v_hayvan_id := NEW.anne_id;
      v_snapshot := to_jsonb(NEW);
    WHEN 'tohumlama' THEN
      -- FIX: UPDATE'lerde ABORT_KAYDI varsayma — tüm RPC'ler kendi islem_log'unu yapıyor
      IF TG_OP = 'INSERT' THEN
        v_tip := 'TOHUMLAMA';
      ELSE
        -- UPDATE: sadece abort (RPC dışı) durumunda logla
        -- RPC'ler (tohumlama_abort, tohumlama_sonuc_bos, vb.) kendi islem_log'unu INSERT eder
        IF NEW.sonuc = 'Abort' AND OLD.sonuc != 'Abort' THEN
          v_tip := 'ABORT_KAYDI';
        ELSE
          -- RPC tarafından yönetilen UPDATE — trigger sessizce geç
          RETURN NEW;
        END IF;
      END IF;
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot := to_jsonb(NEW);
    WHEN 'hastalik_log' THEN
      v_tip := 'HASTALIK_KAYDI';
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot := to_jsonb(NEW);
    WHEN 'kizginlik_log' THEN
      v_tip := 'KIZGINLIK';
      v_hayvan_id := NEW.hayvan_id;
      v_snapshot := to_jsonb(NEW);
    WHEN 'gorev_log' THEN
      v_tip := CASE TG_OP WHEN 'INSERT' THEN 'GOREV_EKLENDI' ELSE 'GOREV_GUNCELLENDI' END;
      v_hayvan_id := NEW.hayvan_id;
      IF TG_OP = 'UPDATE' THEN
        v_snapshot := jsonb_build_object('old', to_jsonb(OLD), 'new', to_jsonb(NEW));
      ELSE
        v_snapshot := to_jsonb(NEW);
      END IF;
    ELSE
      v_tip := upper(TG_TABLE_NAME) || '_' || TG_OP;
      v_hayvan_id := NULL;
      v_snapshot := to_jsonb(NEW);
  END CASE;

  v_payload := jsonb_build_object(
    'event_type', CASE v_tip
      WHEN 'DOGUM_KAYDI' THEN 'birth_recorded'
      WHEN 'TOHUMLAMA' THEN 'insemination_performed'
      WHEN 'HASTALIK_KAYDI' THEN 'treatment_recorded'
      WHEN 'HAYVAN_EKLENDI' THEN 'animal_registered'
      WHEN 'HAYVAN_GUNCELLENDI' THEN 'animal_updated'
      WHEN 'ABORT_KAYDI' THEN 'abortion_recorded'
      WHEN 'KIZGINLIK' THEN 'estrus_detected'
      WHEN 'GOREV_EKLENDI' THEN 'task_created'
      WHEN 'GOREV_GUNCELLENDI' THEN 'task_updated'
      ELSE lower(v_tip)
    END,
    'entity_type', 'animal',
    'entity_id', v_hayvan_id,
    'meta', v_snapshot
  );

  INSERT INTO public.islem_log (tip, ana_hayvan_id, snapshot, payload)
  VALUES (v_tip, v_hayvan_id, v_snapshot, v_payload);

  RETURN NEW;
END;
$$;

COMMIT;
-- Migration: kisir flag + hayvan_kisir_isaretle RPC
BEGIN;

-- 1. Kolon ekle
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS kisir boolean DEFAULT false;

-- 2. RPC: kısır işaretle/kaldır
CREATE OR REPLACE FUNCTION public.hayvan_kisir_isaretle(
  p_hayvan_id text,
  p_kisir boolean
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_islem_id text := gen_random_uuid()::text;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  IF v_hayvan.kisir = p_kisir THEN
    RETURN jsonb_build_object('ok', true, 'mesaj', 'Zaten bu durumda');
  END IF;

  UPDATE public.hayvanlar SET kisir = p_kisir WHERE id = p_hayvan_id;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, snapshot)
  VALUES (
    v_islem_id,
    CASE WHEN p_kisir THEN 'KISIR_ISARETLE' ELSE 'KISIR_KALDIR' END,
    p_hayvan_id,
    jsonb_build_object(
      'guncellenen', jsonb_build_array(
        jsonb_build_object('tablo','hayvanlar','id',p_hayvan_id,'onceki',jsonb_build_object('kisir',v_hayvan.kisir))
      )
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$$;

END;

-- genc_anne: nullable boolean üreme statüsü override (belirsiz düve/inek ayrımı)
-- NULL = incelenmedi (temkinli İnek), true = genç anne (Düve), false = olgun İnek
ALTER TABLE public.hayvanlar ADD COLUMN IF NOT EXISTS genc_anne boolean DEFAULT NULL;

CREATE OR REPLACE FUNCTION public.hayvan_genc_anne_isaretle(
  p_hayvan_id text,
  p_genc_anne boolean
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı');
  END IF;

  UPDATE public.hayvanlar SET genc_anne = p_genc_anne WHERE id = p_hayvan_id;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    'GENC_ANNE_STATU',
    p_hayvan_id,
    p_hayvan_id,
    'hayvanlar',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(jsonb_build_object(
        'tablo', 'hayvanlar', 'id', p_hayvan_id,
        'degisim', 'genc_anne: ' || COALESCE(v_hayvan.genc_anne::text,'null') || ' → ' || COALESCE(p_genc_anne::text,'null')
      )),
      'silinen', '[]'::jsonb
    )
  );

  RETURN jsonb_build_object('ok', true, 'genc_anne', p_genc_anne);
END;
$$;

GRANT EXECUTE ON FUNCTION public.hayvan_genc_anne_isaretle(text, boolean) TO anon, authenticated;

-- Belirsiz üreme statüsü listesi (dashboard triage chip için)
CREATE OR REPLACE FUNCTION public.hayvan_belirsiz_ureme_listele()
RETURNS TABLE (
  hayvan_id text, kupe_no text, grup text, padok text,
  dogum_sayisi integer, tohumlama_sayisi integer, son_tohumlama date
)
LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT h.id, h.kupe_no, h.grup, h.padok,
    (SELECT COUNT(*) FROM public.dogum d WHERE d.anne_id = h.id)::int,
    (SELECT COUNT(*) FROM public.tohumlama t WHERE t.hayvan_id = h.id)::int,
    (SELECT MAX(t.tarih) FROM public.tohumlama t WHERE t.hayvan_id = h.id)
  FROM public.hayvanlar h
  WHERE h.cinsiyet = 'Dişi' AND h.durum = 'Aktif' AND h.kisir IS NOT TRUE
    AND h.genc_anne IS NULL
    AND NOT (h.grup ILIKE '%düve%' OR h.grup ILIKE '%duve%')
    AND (SELECT COUNT(*) FROM public.dogum d WHERE d.anne_id = h.id) < 2
    AND EXISTS (SELECT 1 FROM public.tohumlama t WHERE t.hayvan_id = h.id)
  ORDER BY (SELECT MAX(t.tarih) FROM public.tohumlama t WHERE t.hayvan_id = h.id) DESC NULLS LAST;
$$;

GRANT EXECUTE ON FUNCTION public.hayvan_belirsiz_ureme_listele() TO anon, authenticated;

-- Toplu genç anne / olgun inek işaretleme (belirsiz liste modalı checkbox sistemi)
CREATE OR REPLACE FUNCTION public.hayvan_genc_anne_isaretle_toplu(
  p_ids text[],
  p_genc_anne boolean
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count integer;
BEGIN
  UPDATE public.hayvanlar SET genc_anne = p_genc_anne WHERE id = ANY(p_ids);
  GET DIAGNOSTICS v_count = ROW_COUNT;

  INSERT INTO public.islem_log (id, tip, ref_tablo, snapshot)
  VALUES (
    gen_random_uuid()::text,
    'GENC_ANNE_STATU_TOPLU',
    'hayvanlar',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(jsonb_build_object(
        'tablo', 'hayvanlar', 'adet', v_count,
        'genc_anne', p_genc_anne, 'ids', to_jsonb(p_ids)
      )),
      'silinen', '[]'::jsonb
    )
  );

  RETURN jsonb_build_object('ok', true, 'adet', v_count, 'genc_anne', p_genc_anne);
END;
$$;

GRANT EXECUTE ON FUNCTION public.hayvan_genc_anne_isaretle_toplu(text[], boolean) TO anon, authenticated;

-- Migration: buzagi_sutten_kesme_kontrol RPC
-- Pattern: ileri_gebe_gorev_kontrol ile aynı yapı
-- Domain kuralı: 60 günden büyük "Süt İçen Buzağı" → sütten kesme görevi
-- İki görev üretir: (1) sütten kesme (2) padok transfer

BEGIN;

-- Sütten kesme alarm tarayıcısı — protokol_instance + config eşik + gecikme vurgusu
-- (Eski PADOK_DEGISIM alt-görev üretimi kaldırıldı; SUTTEN_KESME tipi görev + instance)
CREATE OR REPLACE FUNCTION public.buzagi_sutten_kesme_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_esik    constant numeric := public._ayar('sutten_kesme_gun', 60);
  v_gecikme constant numeric := public._ayar('sutten_kesme_gecikme_gun', 75);
  v_h record;
  v_gun int;
  v_hedef date;
  v_kaynak text;
  v_inst_id uuid;
  v_aciklama text;
  v_olusturulan int := 0;
  v_sayac int;
BEGIN
  FOR v_h IN
    SELECT * FROM public.hayvanlar
     WHERE durum='Aktif'
       AND suttten_kesme_tarihi IS NULL
       AND dogum_tarihi IS NOT NULL
       AND (CURRENT_DATE - dogum_tarihi) >= v_esik
       AND (grup ILIKE '%Buzağı%' OR (CURRENT_DATE - dogum_tarihi) <= 180)
  LOOP
    v_gun    := CURRENT_DATE - v_h.dogum_tarihi;
    v_hedef  := v_h.dogum_tarihi + v_esik::int;
    v_kaynak := 'SUTTENKES-' || v_h.id;

    INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
    VALUES (v_h.id, 'BAKIM', 'SUTTEN_KESME', v_kaynak, v_hedef, 'aktif')
    ON CONFLICT (kaynak_ref) DO NOTHING;

    SELECT id INTO v_inst_id FROM public.protokol_instance WHERE kaynak_ref = v_kaynak;

    v_aciklama := CASE WHEN v_gun >= v_gecikme
      THEN '⏰ GECİKMİŞ — 🍼 Sütten kesme zamanı (' || v_gun || '. gün)'
      ELSE '🍼 Sütten kesme zamanı (' || v_gun || '. gün)' END;

    INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, protokol_instance_id)
    SELECT gen_random_uuid(), v_h.id, 'SUTTEN_KESME', v_aciklama, v_hedef, false, v_kaynak, v_inst_id
    WHERE NOT EXISTS (
      SELECT 1 FROM public.gorev_log
       WHERE hayvan_id=v_h.id AND gorev_tipi='SUTTEN_KESME' AND iptal=false AND tamamlandi=false);
    GET DIAGNOSTICS v_sayac = ROW_COUNT;
    v_olusturulan := v_olusturulan + v_sayac;
  END LOOP;
  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;
GRANT EXECUTE ON FUNCTION public.buzagi_sutten_kesme_kontrol() TO anon, authenticated;

END;
-- Migration: laktasyon_kuru_kontrol RPC
-- 210+ gün laktasyondaki sağmal inekleri bulup kuru dönem transfer görevi oluşturur

BEGIN;

CREATE VIEW public.hayvan_durum_view AS
WITH yas AS (
  SELECT
    h.id,
    h.kupe_no,
    h.devlet_kupe,
    h.irk,
    h.cinsiyet,
    h.dogum_tarihi,
    h.grup,
    h.padok_id,
    COALESCE(pk.ad, h.padok) AS padok,
    h.durum,
    h.anne_id,
    h.kategori,
    h.tohumlama_durumu,
    h.tohumlama_onay_tarihi,
    h.suttten_kesme_tarihi,
    h.cikis_tipi,
    h.cikis_tarihi,
    h.cikis_sebebi,
    h.satis_fiyati,
    h.notlar,
    h.dogum_kg,
    h.canli_agirlik,
    h.boy,
    h.renk,
    h.ayirici_ozellik,
    h.baba_bilgi,
    h.abort_sayisi,
    h.kisir,
    CASE
      WHEN h.dogum_tarihi IS NOT NULL
      THEN CURRENT_DATE - h.dogum_tarihi
      ELSE NULL
    END AS yas_gun,
    COALESCE(ie.tohumlama_gun, 365) AS tohumlama_esik_gun
  FROM public.hayvanlar h
  LEFT JOIN public.padoklar pk ON pk.id = h.padok_id
  LEFT JOIN public.irk_esik ie ON ie.irk = h.irk
),
son_tohumlama AS (
  SELECT DISTINCT ON (hayvan_id)
    hayvan_id,
    id    AS toh_id,
    tarih AS toh_tarih,
    sperma,
    sonuc AS toh_sonuc,
    (CURRENT_DATE - tarih) AS toh_gun
  FROM public.tohumlama
  ORDER BY hayvan_id, tarih DESC
),
aktif_hastalik AS (
  SELECT hayvan_id, COUNT(*) AS hastalik_sayisi
  FROM public.hastalik_log
  WHERE durum = 'Aktif'
  GROUP BY hayvan_id
)
SELECT
  y.*,
  st.toh_id,
  st.toh_tarih,
  st.sperma,
  st.toh_sonuc,
  st.toh_gun,
  COALESCE(ah.hastalik_sayisi, 0) AS aktif_hastalik_sayisi,
  CASE
    WHEN y.cikis_tipi IS NOT NULL THEN 'suruden_cikti'
    WHEN y.suttten_kesme_tarihi IS NULL AND y.yas_gun <= 75 THEN 'sut_icen'
    WHEN y.suttten_kesme_tarihi IS NOT NULL AND y.yas_gun <= 180 THEN 'suttten_kesilmis'
    WHEN y.cinsiyet = 'Erkek' AND y.yas_gun > 180 THEN 'besi'
    WHEN y.cinsiyet = 'Dişi' AND y.yas_gun BETWEEN 181 AND 365 THEN 'duve_kucuk'
    WHEN y.cinsiyet = 'Dişi' AND y.yas_gun BETWEEN 366 AND 730 THEN 'duve_buyuk'
    WHEN y.cinsiyet = 'Dişi' AND y.yas_gun > 730 THEN 'sagmal'
    ELSE 'genel'
  END AS hesap_kategori,
  CASE
    WHEN y.cinsiyet = 'Dişi'
      AND y.yas_gun >= y.tohumlama_esik_gun
      AND (st.toh_sonuc IS NULL OR st.toh_sonuc = 'Boş')
    THEN true
    ELSE false
  END AS tohumlama_bildirisi_gerekli,
  CASE
    WHEN y.suttten_kesme_tarihi IS NULL AND y.yas_gun BETWEEN 76 AND 180
    THEN true
    ELSE false
  END AS suttten_kesme_bildirisi_gerekli,
  CASE
    WHEN st.toh_sonuc = 'Gebe' AND (280 - st.toh_gun) BETWEEN 0 AND 7
    THEN true
    ELSE false
  END AS dogum_yaklasti,
  CASE
    WHEN st.toh_sonuc = 'Gebe' AND st.toh_gun > 280
    THEN st.toh_gun - 280
    ELSE 0
  END AS dogum_gecikme_gun,
  CASE
    WHEN st.toh_sonuc = 'Gebe' THEN 'gebe'
    WHEN st.toh_sonuc = 'Bekliyor' THEN 'bekliyor'
    WHEN y.yas_gun >= y.tohumlama_esik_gun AND y.cinsiyet = 'Dişi' THEN 'tohumlanabilir'
    ELSE 'erken'
  END AS tohumlama_durumu_hesap
FROM yas y
LEFT JOIN son_tohumlama st ON st.hayvan_id = y.id
LEFT JOIN aktif_hastalik ah ON ah.hayvan_id = y.id;

GRANT SELECT ON public.hayvan_durum_view TO anon, authenticated;

CREATE VIEW public.tohumlanabilir_hayvanlar AS
SELECT id, kupe_no, devlet_kupe, irk, cinsiyet, dogum_tarihi,
  grup, padok_id, padok, durum, anne_id, kategori,
  tohumlama_durumu, tohumlama_onay_tarihi, suttten_kesme_tarihi,
  cikis_tipi, cikis_tarihi, cikis_sebebi, satis_fiyati, notlar,
  dogum_kg, canli_agirlik, boy, renk, ayirici_ozellik, baba_bilgi, abort_sayisi,
  yas_gun, tohumlama_esik_gun, kisir,
  toh_id, toh_tarih, sperma, toh_sonuc, toh_gun,
  aktif_hastalik_sayisi, hesap_kategori,
  tohumlama_bildirisi_gerekli, suttten_kesme_bildirisi_gerekli,
  dogum_yaklasti, dogum_gecikme_gun, tohumlama_durumu_hesap
FROM hayvan_durum_view
WHERE tohumlama_durumu_hesap = 'tohumlanabilir';

GRANT SELECT ON public.tohumlanabilir_hayvanlar TO anon, authenticated;

END;
-- Migration: hayvan_guncelle RPC'ye p_kisir parametresi + gebe validation
BEGIN;

CREATE OR REPLACE FUNCTION public.hayvan_guncelle(
  p_id              text,
  p_kupe_no         text    DEFAULT NULL,
  p_devlet_kupe     text    DEFAULT NULL,
  p_irk             text    DEFAULT NULL,
  p_cinsiyet        text    DEFAULT NULL,
  p_dogum_tarihi    date    DEFAULT NULL,
  p_grup            text    DEFAULT NULL,
  p_padok           text    DEFAULT NULL,
  p_dogum_kg        numeric DEFAULT NULL,
  p_canli_agirlik   numeric DEFAULT NULL,
  p_boy             numeric DEFAULT NULL,
  p_renk            text    DEFAULT NULL,
  p_ayirici_ozellik text    DEFAULT NULL,
  p_baba_bilgi      text    DEFAULT NULL,
  p_notlar          text    DEFAULT NULL,
  p_anne_id         text    DEFAULT NULL,
  p_padok_id        uuid    DEFAULT NULL,
  p_kisir           boolean DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_padok_id uuid;
  v_padok_ad text;
  v_gebe     boolean;
BEGIN
  -- Kısır işaretleme validation: gebe hayvan kısır olamaz
  IF p_kisir IS NOT NULL AND p_kisir = true THEN
    SELECT EXISTS (
      SELECT 1 FROM tohumlama t
      WHERE t.hayvan_id = p_id AND t.sonuc = 'Gebe'
    ) INTO v_gebe;
    IF v_gebe THEN
      RETURN jsonb_build_object('ok', false, 'error', 'Gebe hayvan kısır olarak işaretlenemez');
    END IF;
  END IF;

  IF p_padok_id IS NOT NULL THEN
    v_padok_id := p_padok_id;
    SELECT ad INTO v_padok_ad FROM padoklar WHERE id = p_padok_id;
  ELSIF p_padok IS NOT NULL THEN
    SELECT id, ad INTO v_padok_id, v_padok_ad FROM padoklar WHERE ad = p_padok;
  END IF;

  UPDATE hayvanlar SET
    kupe_no          = COALESCE(NULLIF(p_kupe_no,''),        kupe_no),
    devlet_kupe      = COALESCE(NULLIF(p_devlet_kupe,''),    devlet_kupe),
    irk              = COALESCE(NULLIF(p_irk,''),            irk),
    cinsiyet         = COALESCE(NULLIF(p_cinsiyet,''),       cinsiyet),
    dogum_tarihi     = COALESCE(p_dogum_tarihi,              dogum_tarihi),
    grup             = COALESCE(NULLIF(p_grup,''),           grup),
    padok            = COALESCE(v_padok_ad,                  padok),
    padok_id         = COALESCE(v_padok_id,                  padok_id),
    dogum_kg         = COALESCE(p_dogum_kg,                  dogum_kg),
    canli_agirlik    = COALESCE(p_canli_agirlik,             canli_agirlik),
    boy              = COALESCE(p_boy,                       boy),
    renk             = COALESCE(NULLIF(p_renk,''),           renk),
    ayirici_ozellik  = COALESCE(NULLIF(p_ayirici_ozellik,''),ayirici_ozellik),
    baba_bilgi       = COALESCE(NULLIF(p_baba_bilgi,''),     baba_bilgi),
    notlar           = COALESCE(NULLIF(p_notlar,''),         notlar),
    anne_id          = COALESCE(NULLIF(p_anne_id,''),        anne_id),
    kisir            = COALESCE(p_kisir,                     kisir)
  WHERE id = p_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

END;
-- Migration: laktasyon_kuru_kontrol RPC (revize) — dogum tablosu olmadan
-- Sağmal grupta olup gebe olmayan hayvanlar → kuru dönem transfer görevi
-- gorev_log.id uuid tipinde olduğu için gen_random_uuid() direkt kullanılır
BEGIN;

-- ──────────────────────────────────────────────────────────────
-- TANIMLAR PANELİ — CRUD RPC'ler
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.disease_ekle(p_name text, p_category text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM diseases WHERE LOWER(name) = LOWER(p_name)) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu hastalık zaten var');
  END IF;
  INSERT INTO diseases (name, category) VALUES (p_name, p_category) RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.disease_guncelle(p_id uuid, p_name text, p_category text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM diseases WHERE LOWER(name) = LOWER(p_name) AND id != p_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu isimde başka bir hastalık var');
  END IF;
  UPDATE diseases SET name = p_name, category = p_category WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Hastalık bulunamadı'); END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.disease_sil(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_aktif integer; v_kapali integer;
BEGIN
  SELECT COUNT(*) FILTER (WHERE status='active'), COUNT(*) FILTER (WHERE status='closed')
  INTO v_aktif, v_kapali FROM cases WHERE disease_id = p_id;
  IF v_aktif > 0 OR v_kapali > 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      format('Bu hastalığa ait %s vaka var (%s aktif, %s kapalı), silinemez', v_aktif+v_kapali, v_aktif, v_kapali));
  END IF;
  DELETE FROM diseases WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.drug_ekle(p_name text, p_default_unit text DEFAULT NULL, p_default_route text DEFAULT NULL, p_stock_item_id text DEFAULT NULL, p_kategori text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM drugs WHERE LOWER(name) = LOWER(p_name)) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu ilaç zaten var');
  END IF;
  INSERT INTO drugs (name, default_unit, default_route, stock_item_id, kategori)
  VALUES (p_name, p_default_unit, p_default_route, p_stock_item_id, p_kategori) RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.drug_guncelle(p_id uuid, p_name text DEFAULT NULL, p_default_unit text DEFAULT NULL, p_default_route text DEFAULT NULL, p_stock_item_id text DEFAULT NULL, p_kategori text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF p_name IS NOT NULL AND EXISTS (SELECT 1 FROM drugs WHERE LOWER(name) = LOWER(p_name) AND id != p_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu isimde başka bir ilaç var');
  END IF;
  UPDATE drugs SET name=COALESCE(NULLIF(trim(p_name),''),name), default_unit=p_default_unit, default_route=p_default_route, stock_item_id=p_stock_item_id, kategori=p_kategori WHERE id=p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'İlaç bulunamadı'); END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.drug_sil(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_stok_id text; v_count integer;
BEGIN
  SELECT stock_item_id INTO v_stok_id FROM drugs WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'İlaç bulunamadı'); END IF;
  IF v_stok_id IS NOT NULL THEN
    SELECT COUNT(*) INTO v_count FROM drug_administrations WHERE stok_id = v_stok_id;
    IF v_count > 0 THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', format('Bu ilaç %s tedavi uygulamasında kullanılmış, silinemez', v_count));
    END IF;
  END IF;
  DELETE FROM drugs WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.kategori_ekle(p_ad text, p_tip text DEFAULT 'genel')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM stok_kategorileri WHERE LOWER(ad) = LOWER(p_ad)) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu kategori zaten var');
  END IF;
  INSERT INTO stok_kategorileri (ad, sira, tip) VALUES (p_ad, COALESCE((SELECT MAX(sira) FROM stok_kategorileri),0)+1, p_tip) RETURNING id INTO v_id;
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.kategori_guncelle(p_id uuid, p_new_ad text DEFAULT NULL, p_tip text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_old_ad text;
BEGIN
  IF p_new_ad IS NOT NULL AND EXISTS (SELECT 1 FROM stok_kategorileri WHERE LOWER(ad) = LOWER(p_new_ad) AND id != p_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu isimde başka bir kategori var');
  END IF;
  SELECT ad INTO v_old_ad FROM stok_kategorileri WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Kategori bulunamadı'); END IF;
  IF p_new_ad IS NOT NULL THEN
    UPDATE stok SET kategori = p_new_ad WHERE kategori = v_old_ad;
    UPDATE stok_kategorileri SET ad = p_new_ad WHERE id = p_id;
  END IF;
  IF p_tip IS NOT NULL THEN
    UPDATE stok_kategorileri SET tip = p_tip WHERE id = p_id;
  END IF;
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.kategori_sil(p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_ad text; v_count integer;
BEGIN
  SELECT ad INTO v_ad FROM stok_kategorileri WHERE id = p_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Kategori bulunamadı'); END IF;
  SELECT COUNT(*) INTO v_count FROM stok WHERE kategori = v_ad;
  IF v_count > 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', format('Bu kategoride %s ürün var, silinemez', v_count));
  END IF;
  DELETE FROM stok_kategorileri WHERE id = p_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.seed_defaults(p_tip text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_count integer := 0;
BEGIN
  IF p_tip = 'diseases' THEN
    WITH ins AS (
      INSERT INTO diseases (name, category) VALUES
        ('Mastitis','Meme'),('Laminitis','Ayak'),('Metritis','Üreme'),('Retensio','Üreme'),
        ('Ketozis','Metabolik'),('Hipokalsemi','Metabolik'),('Pnömoni','Solunum'),
        ('İshal','Sindirim'),('Neonatal Zayıflık','Buzağı'),('Göbek İltihabı','Buzağı')
      ON CONFLICT (name) DO NOTHING RETURNING 1
    ) SELECT COUNT(*) INTO v_count FROM ins;
  ELSIF p_tip = 'drugs' THEN
    WITH ins AS (
      INSERT INTO drugs (name, default_unit, default_route) VALUES
        ('Makrovil','ml','IM'),('Enrolen','ml','IM'),('Florkem','ml','IM'),('Penicilin','ml','IM'),
        ('Oksitetrasiklin','ml','IM'),('Meloksikam','ml','IV'),('Flunixin','ml','IV'),
        ('Deksametazon','ml','IM'),('Kalsiyum Boroglukonat','ml','IV'),
        ('B12 Vitamini','ml','IM'),('AD3E Vitamini','ml','IM'),
        ('Albendazol','ml','PO'),('İvermektin','ml','SC')
      ON CONFLICT (name) DO NOTHING RETURNING 1
    ) SELECT COUNT(*) INTO v_count FROM ins;
  ELSIF p_tip = 'kategoriler' THEN
    WITH ins AS (
      INSERT INTO stok_kategorileri (ad, sira, tip) VALUES
        ('Antibiyotik',1,'ilac'),('NSAID',2,'ilac'),('Hormon',3,'ilac'),('Vitamin',4,'ilac'),
        ('Antiparaziter',5,'ilac'),('Diğer İlaç',6,'ilac'),('Aşı',7,'genel'),('Sperma',8,'genel'),
        ('Yem',9,'genel'),('Sarf',10,'genel'),('Ekipman',11,'genel'),('Diğer',12,'genel'),
        ('Tohumlama',13,'genel'),('Metabolik',14,'ilac'),('GI İlaçlar',15,'ilac'),
        ('Topikal',16,'ilac'),('Anestezik / Sedatif',17,'ilac')
      ON CONFLICT (ad) DO NOTHING RETURNING 1
    ) SELECT COUNT(*) INTO v_count FROM ins;
  ELSE
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçersiz tip: diseases | drugs | kategoriler');
  END IF;
  RETURN jsonb_build_object('ok', true, 'eklenen', v_count);
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- drug_class CRUD RPCs
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.drug_class_ekle(
  p_group_name text,
  p_class_name text,
  p_active_ingredient text,
  p_kategori_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id uuid;
BEGIN
  IF p_group_name IS NULL OR p_group_name = '' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Grup adı zorunlu');
  END IF;
  IF p_active_ingredient IS NULL OR p_active_ingredient = '' THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Etken madde adı zorunlu');
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.drug_classes
    WHERE group_name = p_group_name
      AND COALESCE(class_name,'') = COALESCE(p_class_name,'')
      AND active_ingredient = p_active_ingredient
  ) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu kombinasyon zaten mevcut');
  END IF;
  v_id := gen_random_uuid();
  INSERT INTO public.drug_classes (id, group_name, class_name, active_ingredient, kategori_id)
  VALUES (v_id, p_group_name, NULLIF(p_class_name,''), p_active_ingredient, p_kategori_id);
  RETURN jsonb_build_object('ok', true, 'id', v_id, 'mesaj', 'Etken madde eklendi');
END;
$$;

CREATE OR REPLACE FUNCTION public.drug_class_guncelle(
  p_id uuid,
  p_group_name text DEFAULT NULL,
  p_class_name text DEFAULT NULL,
  p_active_ingredient text DEFAULT NULL,
  p_kategori_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.drug_classes WHERE id = p_id) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Kayıt bulunamadı');
  END IF;
  UPDATE public.drug_classes SET
    group_name = COALESCE(NULLIF(p_group_name,''), group_name),
    class_name = COALESCE(p_class_name, class_name),
    active_ingredient = COALESCE(NULLIF(p_active_ingredient,''), active_ingredient),
    kategori_id = COALESCE(p_kategori_id, kategori_id)
  WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'mesaj', 'Güncellendi');
END;
$$;

CREATE OR REPLACE FUNCTION public.drug_class_sil(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_count integer;
BEGIN
  SELECT COUNT(*) INTO v_count FROM public.drug_products WHERE drug_class_id = p_id;
  IF v_count > 0 THEN
    RETURN jsonb_build_object('ok', false, 'mesaj',
      'Bu etken maddeye bağlı ' || v_count || ' preparat var. Önce preparatları başka sınıfa taşıyın.');
  END IF;
  DELETE FROM public.drug_classes WHERE id = p_id;
  RETURN jsonb_build_object('ok', true, 'mesaj', 'Silindi');
END;
$$;

CREATE OR REPLACE FUNCTION public.drug_class_varsayilan_yukle()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_before integer;
  v_after integer;
BEGIN
  SELECT COUNT(*) INTO v_before FROM public.drug_classes;
  INSERT INTO public.drug_classes (group_name, class_name, active_ingredient, kategori_id)
  VALUES
    ('Antimikrobiyaller (Antibiyotikler)', 'Beta-Laktamlar', 'Penisilin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Beta-Laktamlar', 'Amoksisilin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Beta-Laktamlar', 'Seftiofur', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Makrolidler', 'Tilmikosin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Makrolidler', 'Tulathromycin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Florokinolonlar', 'Enrofloksasin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Florokinolonlar', 'Marbofloksasin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Tetrasiklinler', 'Oksitetrasiklin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Tetrasiklinler', 'Doksisiklin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Aminoglikozidler', 'Gentamisin', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Antimikrobiyaller (Antibiyotikler)', 'Sulfonamidler', 'Trimetoprim-SMX', (SELECT id FROM stok_kategorileri WHERE ad='Antibiyotik')),
    ('Anti-inflamatuar İlaçlar', 'NSAID', 'Meloksikam', (SELECT id FROM stok_kategorileri WHERE ad='NSAID')),
    ('Anti-inflamatuar İlaçlar', 'NSAID', 'Ketoprofen', (SELECT id FROM stok_kategorileri WHERE ad='NSAID')),
    ('Anti-inflamatuar İlaçlar', 'NSAID', 'Flunixin', (SELECT id FROM stok_kategorileri WHERE ad='NSAID')),
    ('Anti-inflamatuar İlaçlar', 'Kortikosteroidler', 'Deksametazon', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
    ('Hormonlar ve Üreme İlaçları', 'Prostaglandinler', 'Dinoprost', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
    ('Hormonlar ve Üreme İlaçları', 'GnRH Agonistleri', 'Gonadorelin', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
    ('Hormonlar ve Üreme İlaçları', 'Progestagenler', 'Progesteron', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
    ('Hormonlar ve Üreme İlaçları', 'Oksitosin', 'Oksitosin', (SELECT id FROM stok_kategorileri WHERE ad='Hormon')),
    ('Antiparaziter İlaçlar', 'Makrosiklik Laktonlar', 'İvermektin', (SELECT id FROM stok_kategorileri WHERE ad='Antiparaziter')),
    ('Antiparaziter İlaçlar', 'Makrosiklik Laktonlar', 'Doramektin', (SELECT id FROM stok_kategorileri WHERE ad='Antiparaziter')),
    ('Antiparaziter İlaçlar', 'Benzimidazoller', 'Albendazol', (SELECT id FROM stok_kategorileri WHERE ad='Antiparaziter')),
    ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B1 (Tiamin)', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B6 (Piridoksin)', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B12 (Siyanokobalamin)', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'B Kompleks', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Suda Eriyen Vitaminler', 'C Vitamini', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Yağda Eriyen Vitaminler', 'E Vitamini', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Yağda Eriyen Vitaminler', 'AD3E Kombinasyon', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Vitaminler ve Mineraller', 'Mineraller / İz Elementler', 'Selenyum', (SELECT id FROM stok_kategorileri WHERE ad='Vitamin')),
    ('Metabolik / Sıvı Tedavi', 'Kalsiyum Preparatları', 'Kalsiyum Boroglukonat', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Metabolik / Sıvı Tedavi', 'Magnezyum', 'Magnezyum Sülfat', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Metabolik / Sıvı Tedavi', 'Glukoz / Dekstroz', 'Glukoz %50', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Metabolik / Sıvı Tedavi', 'Glukoz / Dekstroz', 'Dekstroz %30', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Metabolik / Sıvı Tedavi', 'Elektrolitler', 'Oral Rehidrasyon Solüsyonu', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Metabolik / Sıvı Tedavi', 'Elektrolitler', 'IV Serum (İzotonik NaCl, Ringer Laktat)', (SELECT id FROM stok_kategorileri WHERE ad='Metabolik')),
    ('Gastrointestinal İlaçlar', 'Gastroprotektanlar', 'Sukralfat (Antepsin)', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
    ('Gastrointestinal İlaçlar', 'Rumen Stimülanları', 'Rumen Stimülanı', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
    ('Gastrointestinal İlaçlar', 'Probiyotikler / Maya', 'Saccharomyces (Maya)', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
    ('Gastrointestinal İlaçlar', 'Probiyotikler / Maya', 'Probiyotik Preparatları', (SELECT id FROM stok_kategorileri WHERE ad='GI İlaçlar')),
    ('Topikal / Harici İlaçlar', 'Merhemler', 'İhtiyol (Kara Merhem)', (SELECT id FROM stok_kategorileri WHERE ad='Topikal')),
    ('Anestezik / Sedatif', 'Sedatifler', 'Ksilazin', (SELECT id FROM stok_kategorileri WHERE ad='Anestezik / Sedatif')),
    ('Anestezik / Sedatif', 'Genel Anestezikler', 'Ketamin', (SELECT id FROM stok_kategorileri WHERE ad='Anestezik / Sedatif')),
    ('Anestezik / Sedatif', 'Lokal Anestezikler', 'Lidokain', (SELECT id FROM stok_kategorileri WHERE ad='Anestezik / Sedatif'))
  ON CONFLICT ON CONSTRAINT uq_drug_classes_combo DO NOTHING;
  SELECT COUNT(*) INTO v_after FROM public.drug_classes;
  RETURN jsonb_build_object('ok', true, 'eklenen', v_after - v_before);
END;
$$;

-- ──────────────────────────────────────────────────────────────
-- stok_ekle / stok_guncelle — kategori validate
-- ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.stok_ekle(
  p_urun_adi text,
  p_kategori text,
  p_birim text,
  p_baslangic_miktar numeric,
  p_esik numeric DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.stok_kategorileri WHERE ad = p_kategori) THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçersiz kategori: ' || p_kategori);
  END IF;
  -- Katalog zorunlu: ilaç kategorisinde stok yalnızca ilac_ekle ile eklenir.
  IF EXISTS (SELECT 1 FROM public.stok_kategorileri WHERE ad = p_kategori AND tip = 'ilac') THEN
    RAISE EXCEPTION 'İlaç kategorisinde stok kataloglanmadan eklenemez — ilac_ekle kullanın (etken madde zorunlu)';
  END IF;
  v_id := gen_random_uuid()::text;
  INSERT INTO public.stok (id, urun_adi, kategori, birim, baslangic_miktar, esik)
  VALUES (v_id, p_urun_adi, p_kategori, p_birim, p_baslangic_miktar, p_esik);
  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('STOK_EKLE', v_id, 'stok', jsonb_build_object(
    'olusturulan', jsonb_build_array(jsonb_build_object(
      'tablo', 'stok', 'id', v_id,
      'veri', jsonb_build_object('urun_adi', p_urun_adi, 'kategori', p_kategori, 'birim', p_birim, 'baslangic_miktar', p_baslangic_miktar, 'esik', p_esik)
    )),
    'guncellenen', '[]'::jsonb,
    'silinen', '[]'::jsonb
  ), 'Yeni stok: ' || p_urun_adi);
  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.stok_guncelle(
  p_stok_id text,
  p_urun_adi text DEFAULT NULL,
  p_kategori text DEFAULT NULL,
  p_birim text DEFAULT NULL,
  p_esik numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok record;
  v_onceki jsonb;
BEGIN
  SELECT * INTO v_stok FROM public.stok WHERE id = p_stok_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Stok bulunamadı: %', p_stok_id; END IF;
  IF p_kategori IS NOT NULL AND p_kategori != '' THEN
    IF NOT EXISTS (SELECT 1 FROM public.stok_kategorileri WHERE ad = p_kategori) THEN
      RETURN jsonb_build_object('ok', false, 'mesaj', 'Geçersiz kategori: ' || p_kategori);
    END IF;
  END IF;
  v_onceki := row_to_json(v_stok)::jsonb;
  UPDATE public.stok SET
    urun_adi = COALESCE(NULLIF(p_urun_adi, ''), urun_adi),
    kategori = COALESCE(NULLIF(p_kategori, ''), kategori),
    birim    = COALESCE(NULLIF(p_birim, ''), birim),
    esik     = COALESCE(p_esik, esik)
  WHERE id = p_stok_id;
  INSERT INTO public.islem_log (tip, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('STOK_GUNCELLE', p_stok_id, 'stok', jsonb_build_object(
    'olusturulan', '[]'::jsonb,
    'guncellenen', jsonb_build_array(jsonb_build_object(
      'tablo', 'stok', 'id', p_stok_id,
      'onceki', v_onceki,
      'sonraki', (SELECT row_to_json(stok)::jsonb FROM public.stok WHERE id = p_stok_id)
    )),
    'silinen', '[]'::jsonb
  ), 'Stok güncellendi: ' || COALESCE(p_urun_adi, (SELECT urun_adi FROM public.stok WHERE id = p_stok_id)));
  RETURN jsonb_build_object('ok', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.drug_class_ekle(text,text,text,uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drug_class_guncelle(uuid,text,text,text,uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drug_class_sil(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drug_class_varsayilan_yukle() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.stok_ekle(text,text,text,numeric,numeric) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.stok_guncelle(text,text,text,text,numeric) TO anon, authenticated;

GRANT EXECUTE ON FUNCTION public.disease_ekle(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.disease_guncelle(uuid, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.disease_sil(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drug_ekle(text, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drug_guncelle(uuid, text, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drug_sil(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kategori_ekle(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kategori_guncelle(uuid, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kategori_sil(uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.seed_defaults(text) TO anon, authenticated;

-- ══════════════════════════════════════════════
-- STAT_GEBELIK_OZET — Sürü Gebelik İstatistikleri
-- ══════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.stat_gebelik_ozet(
  p_donem_baslangic date DEFAULT CURRENT_DATE - INTERVAL '365 days',
  p_donem_bitis     date DEFAULT CURRENT_DATE,
  p_kategori        text DEFAULT NULL,
  p_grup            text DEFAULT NULL,
  p_sperma          text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_result jsonb;
BEGIN
  WITH base AS (
    SELECT
      t.id,
      t.sonuc,
      t.deneme_no,
      LOWER(TRIM(split_part(t.sperma, '|', 1))) AS sperma_norm,
      CASE
        WHEN h.grup ILIKE '%düve%' OR h.grup ILIKE '%duve%' THEN 'Düve'
        WHEN EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id) THEN 'İnek'
        WHEN h.grup ILIKE '%inek%' OR h.grup LIKE '%İnek%'
             OR h.grup ILIKE '%sağmal%' OR h.grup ILIKE '%sagmal%'
             OR h.grup ILIKE '%kuru%' THEN 'İnek'
        ELSE 'Bilinmiyor'
      END AS kategori
    FROM public.tohumlama t
    JOIN public.hayvanlar h ON h.id = t.hayvan_id
    WHERE h.cinsiyet = 'Dişi'
      AND t.tarih BETWEEN p_donem_baslangic AND p_donem_bitis
      AND (p_kategori IS NULL OR
           CASE
             WHEN h.grup ILIKE '%düve%' OR h.grup ILIKE '%duve%' THEN 'Düve'
             WHEN EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id) THEN 'İnek'
             WHEN h.grup ILIKE '%inek%' OR h.grup LIKE '%İnek%'
             OR h.grup ILIKE '%sağmal%' OR h.grup ILIKE '%sagmal%'
             OR h.grup ILIKE '%kuru%' THEN 'İnek'
             ELSE 'Bilinmiyor'
           END = p_kategori)
      AND (p_grup IS NULL OR h.grup = p_grup)
      AND (p_sperma IS NULL OR LOWER(TRIM(split_part(t.sperma, '|', 1))) = LOWER(TRIM(p_sperma)))
  )
  SELECT jsonb_build_object(
    'ozet', jsonb_build_object(
      'toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
      'gebe',   COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı')),
      'bos',    COUNT(*) FILTER (WHERE sonuc = 'Boş'),
      'abort',  COUNT(*) FILTER (WHERE sonuc = 'Abort'),
      'bekleyen', COUNT(*) FILTER (WHERE sonuc = 'Bekliyor'),
      'oran',   ROUND(
                  100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
                  / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)
    ),
    'kategori', (
      SELECT COALESCE(jsonb_agg(row_j ORDER BY row_j->>'ad'), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'ad', kategori,
          'toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
          'gebe',   COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı')),
          'oran',   ROUND(
                      100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
                      / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)
        ) AS row_j
        FROM base
        GROUP BY kategori
      ) sub
    ),
    'sperma_top5', (
      SELECT COALESCE(jsonb_agg(row_j), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'ad', sperma_norm,
          'toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
          'gebe',   COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı')),
          'oran',   ROUND(
                      100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
                      / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)
        ) AS row_j
        FROM base
        WHERE sonuc != 'Bekliyor'
        GROUP BY sperma_norm
        HAVING COUNT(*) >= 3
        ORDER BY ROUND(
                   100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
                   / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1) DESC
        LIMIT 5
      ) sub
    ),
    'deneme', (
      SELECT COALESCE(jsonb_agg(row_j ORDER BY (row_j->>'no')::int), '[]'::jsonb)
      FROM (
        SELECT jsonb_build_object(
          'no', CASE WHEN deneme_no >= 3 THEN 3 ELSE deneme_no END,
          'gebe', COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı')),
          'toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'),
          'oran', ROUND(
                    100.0 * COUNT(*) FILTER (WHERE sonuc IN ('Gebe','Doğum Yaptı'))
                    / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)
        ) AS row_j
        FROM base
        GROUP BY CASE WHEN deneme_no >= 3 THEN 3 ELSE deneme_no END
      ) sub
    )
  ) INTO v_result
  FROM base;

  RETURN COALESCE(v_result, '{"ozet":{"toplam":0,"gebe":0,"bos":0,"abort":0,"bekleyen":0,"oran":null},"kategori":[],"sperma_top5":[],"deneme":[]}'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.stat_gebelik_ozet(date, date, text, text, text) TO anon, authenticated;

-- ── v_ureme_dongusu v3 — cycle detection view + kısır filtresi ═══
-- per-cycle hibrit kategori: cycle≥2→İnek; cycle1→ genc_anne / grup-düve / dogum_sayisi≥2 / else-İnek(temkinli)
-- NOT: CREATE OR REPLACE kolon sırasını değiştiremediği için kategori, cycle_no mevcut sırada tutuldu.
CREATE OR REPLACE VIEW public.v_ureme_dongusu AS
WITH numbered AS (
  SELECT
    t.id,
    t.hayvan_id,
    t.tarih,
    t.sonuc,
    t.deneme_no,
    LOWER(TRIM(split_part(t.sperma, '|', 1))) AS sperma_norm,
    SUM(CASE WHEN t.deneme_no = 1 THEN 1 ELSE 0 END)
      OVER (PARTITION BY t.hayvan_id ORDER BY t.tarih, t.deneme_no
            ROWS UNBOUNDED PRECEDING) AS cycle_no,
    h.padok,
    h.durum,
    h.genc_anne AS h_genc_anne,
    h.grup      AS h_grup,
    (SELECT COUNT(*) FROM public.dogum d2 WHERE d2.anne_id = h.id) AS dogum_sayisi
  FROM public.tohumlama t
  JOIN public.hayvanlar h ON h.id = t.hayvan_id
  WHERE h.cinsiyet = 'Dişi'
    AND h.kisir IS NOT TRUE
)
SELECT
  hayvan_id, padok, durum,
  CASE
    WHEN cycle_no >= 2 THEN 'İnek'
    WHEN h_genc_anne = true  THEN 'Düve'
    WHEN h_genc_anne = false THEN 'İnek'
    WHEN h_grup ILIKE '%düve%' OR h_grup ILIKE '%duve%' THEN 'Düve'
    WHEN dogum_sayisi >= 2 THEN 'Düve'
    ELSE 'İnek'
  END AS kategori,
  cycle_no,
  MIN(tarih)           AS baslangic,
  MAX(tarih)           AS bitis,
  MAX(deneme_no)       AS deneme_sayisi,
  CASE
    WHEN bool_or(sonuc IN ('Gebe','Doğum Yaptı')) THEN 'Gebe'
    WHEN bool_or(sonuc = 'Abort')                 THEN 'Abort'
    WHEN bool_or(sonuc = 'Bekliyor')              THEN 'Bekliyor'
    ELSE 'Boş'
  END                  AS sonuc,
  MAX(CASE WHEN sonuc IN ('Gebe','Doğum Yaptı') THEN sperma_norm END) AS gebe_sperma,
  (ARRAY_AGG(sperma_norm ORDER BY deneme_no DESC))[1] AS son_sperma
FROM numbered
GROUP BY hayvan_id, padok, durum, cycle_no, h_genc_anne, h_grup, dogum_sayisi;

GRANT SELECT ON public.v_ureme_dongusu TO anon, authenticated;

-- ── stat_suru_ozet v5 — 42-gün + sperma_all + sessiz (salt-okuma) ═══
CREATE OR REPLACE FUNCTION public.stat_suru_ozet(
  p_padok     text    DEFAULT NULL,
  p_son_donem boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan    jsonb;
  v_gebelik   jsonb;
  v_verim     jsonb;
  v_sperma_pi jsonb;
BEGIN
  SELECT jsonb_build_object(
    'toplam', COUNT(*),
    'inek',   COUNT(*) FILTER (WHERE grup ILIKE '%inek%' OR grup LIKE '%İnek%' OR grup ILIKE '%sağmal%' OR grup ILIKE '%sagmal%' OR grup ILIKE '%kuru%' OR EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id)),
    'duve',   COUNT(*) FILTER (WHERE (grup ILIKE '%düve%' OR grup ILIKE '%duve%') AND NOT EXISTS (SELECT 1 FROM public.dogum d WHERE d.anne_id = h.id)),
    'buzagi', COUNT(*) FILTER (WHERE grup ILIKE '%buzağı%' OR grup ILIKE '%buzagi%'),
    'erkek',  COUNT(*) FILTER (WHERE cinsiyet = 'Erkek'),
    'kisir',  COUNT(*) FILTER (WHERE kisir = true),
    'hasta',  (SELECT COUNT(DISTINCT c.animal_id) FROM public.cases c JOIN public.hayvanlar h2 ON h2.id = c.animal_id WHERE c.status = 'active' AND h2.durum = 'Aktif' AND (p_padok IS NULL OR h2.padok = p_padok)),
    'tohumlanan', (SELECT COUNT(DISTINCT t2.hayvan_id) FROM public.tohumlama t2 JOIN public.hayvanlar h3 ON h3.id = t2.hayvan_id WHERE h3.durum = 'Aktif' AND h3.cinsiyet = 'Dişi' AND (p_padok IS NULL OR h3.padok = p_padok)),
    'sessiz', (SELECT COUNT(*) FROM public.v_eligible e WHERE (p_padok IS NULL OR e.padok = p_padok) AND e.sessiz_gun >= 55),
    'belirsiz', (SELECT COUNT(*) FROM public.hayvanlar hb
                 WHERE hb.cinsiyet = 'Dişi' AND hb.durum = 'Aktif' AND hb.kisir IS NOT TRUE
                   AND hb.genc_anne IS NULL
                   AND NOT (hb.grup ILIKE '%düve%' OR hb.grup ILIKE '%duve%')
                   AND (SELECT COUNT(*) FROM public.dogum d WHERE d.anne_id = hb.id) < 2
                   AND EXISTS (SELECT 1 FROM public.tohumlama t WHERE t.hayvan_id = hb.id)
                   AND (p_padok IS NULL OR hb.padok = p_padok))
  ) INTO v_hayvan
  FROM public.hayvanlar h
  WHERE h.durum = 'Aktif' AND (p_padok IS NULL OR h.padok = p_padok);
  WITH cycles AS (
    SELECT v.hayvan_id, v.kategori, v.sonuc, v.deneme_sayisi, v.gebe_sperma, v.son_sperma, v.cycle_no, v.baslangic
    FROM public.v_ureme_dongusu v
    WHERE v.durum = 'Aktif' AND (p_padok IS NULL OR v.padok = p_padok) AND v.baslangic < CURRENT_DATE - 42
    AND (NOT p_son_donem OR NOT EXISTS (SELECT 1 FROM public.v_ureme_dongusu v2 WHERE v2.hayvan_id = v.hayvan_id AND v2.cycle_no > v.cycle_no AND v2.sonuc IN ('Gebe','Doğum Yaptı')))
  ),
  hayvan_stat AS (SELECT DISTINCT ON (hayvan_id) hayvan_id, kategori, sonuc AS son_sonuc FROM cycles ORDER BY hayvan_id, cycle_no DESC)
  SELECT jsonb_build_object(
    'hayvan_ozet', jsonb_build_object(
      'toplam', COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc != 'Bekliyor'),
      'gebe',   COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc = 'Gebe'),
      'bos',    COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc IN ('Boş','Abort')),
      'devam_eden', (SELECT COUNT(DISTINCT v3.hayvan_id) FROM public.v_ureme_dongusu v3 WHERE v3.durum = 'Aktif' AND (p_padok IS NULL OR v3.padok = p_padok) AND v3.sonuc = 'Bekliyor'),
      'oran', ROUND(100.0 * COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc = 'Gebe') / NULLIF(COUNT(DISTINCT hayvan_id) FILTER (WHERE son_sonuc != 'Bekliyor'), 0), 1)
    ),
    'cycle_ozet', (SELECT jsonb_build_object('toplam_cycle', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 'basarili', COUNT(*) FILTER (WHERE sonuc = 'Gebe'), 'basarisiz', COUNT(*) FILTER (WHERE sonuc IN ('Boş','Abort')), 'devam_eden', (SELECT COUNT(*) FROM public.v_ureme_dongusu v4 WHERE v4.durum = 'Aktif' AND (p_padok IS NULL OR v4.padok = p_padok) AND v4.sonuc = 'Bekliyor'), 'oran', ROUND(100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe') / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1), 'ort_deneme', ROUND(AVG(deneme_sayisi) FILTER (WHERE sonuc = 'Gebe'), 1)) FROM cycles),
    'kategori', (SELECT COALESCE(jsonb_agg(row_j ORDER BY row_j->>'ad'), '[]'::jsonb) FROM (SELECT jsonb_build_object('ad', hs.kategori, 'hayvan_toplam', COUNT(*) FILTER (WHERE hs.son_sonuc != 'Bekliyor'), 'hayvan_gebe', COUNT(*) FILTER (WHERE hs.son_sonuc = 'Gebe'), 'hayvan_oran', ROUND(100.0 * COUNT(*) FILTER (WHERE hs.son_sonuc = 'Gebe') / NULLIF(COUNT(*) FILTER (WHERE hs.son_sonuc != 'Bekliyor'), 0), 1), 'cycle_toplam', (SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc != 'Bekliyor'), 'cycle_basarili', (SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc = 'Gebe'), 'cycle_oran', ROUND(100.0 * (SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc = 'Gebe') / NULLIF((SELECT COUNT(*) FROM cycles c2 WHERE c2.kategori = hs.kategori AND c2.sonuc != 'Bekliyor'), 0), 1)) AS row_j FROM hayvan_stat hs GROUP BY hs.kategori) sub),
    'sperma_all', (SELECT COALESCE(jsonb_agg(row_j), '[]'::jsonb) FROM (SELECT jsonb_build_object('ad', COALESCE(gebe_sperma, son_sperma), 'cycle_toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 'cycle_basarili', COUNT(*) FILTER (WHERE sonuc = 'Gebe'), 'cycle_oran', ROUND(100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe') / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)) AS row_j FROM cycles WHERE sonuc != 'Bekliyor' GROUP BY COALESCE(gebe_sperma, son_sperma) HAVING COUNT(*) >= 3 ORDER BY ROUND(100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe') / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1) DESC) sub),
    'deneme', (SELECT COALESCE(jsonb_agg(row_j ORDER BY (row_j->>'no')::int), '[]'::jsonb) FROM (SELECT jsonb_build_object('no', deneme_sayisi, 'gebe', COUNT(*) FILTER (WHERE sonuc = 'Gebe'), 'toplam', COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 'oran', ROUND(100.0 * COUNT(*) FILTER (WHERE sonuc = 'Gebe') / NULLIF(COUNT(*) FILTER (WHERE sonuc != 'Bekliyor'), 0), 1)) AS row_j FROM cycles WHERE sonuc != 'Bekliyor' GROUP BY deneme_sayisi) sub)
  ) INTO v_gebelik
  FROM hayvan_stat;

  -- Üreme verimliliği (Düve/İnek × 3 katman: ham CR / hayvan ort / cycle ort 1/N) — lifetime
  WITH basari AS (
    SELECT v.hayvan_id, v.kategori, 1.0 / NULLIF(v.deneme_sayisi, 0) AS skor
    FROM public.v_ureme_dongusu v
    WHERE v.durum = 'Aktif' AND v.sonuc = 'Gebe' AND v.deneme_sayisi >= 1
      AND (p_padok IS NULL OR v.padok = p_padok)
  ),
  per_animal AS (SELECT hayvan_id, kategori, AVG(skor) AS animal_skor FROM basari GROUP BY hayvan_id, kategori),
  ham AS (
    SELECT
      CASE
        WHEN ic.cycle_no >= 2 THEN 'İnek'
        WHEN ic.h_genc_anne = true  THEN 'Düve'
        WHEN ic.h_genc_anne = false THEN 'İnek'
        WHEN ic.h_grup ILIKE '%düve%' OR ic.h_grup ILIKE '%duve%' THEN 'Düve'
        WHEN ic.dogum_sayisi >= 2 THEN 'Düve'
        ELSE 'İnek'
      END AS kategori,
      COUNT(*) FILTER (WHERE ic.sonuc <> 'Bekliyor')             AS tohumlama,
      COUNT(*) FILTER (WHERE ic.sonuc IN ('Gebe','Doğum Yaptı')) AS gebe,
      COUNT(*) FILTER (WHERE ic.sonuc IN ('Boş','Abort'))        AS bos,
      COUNT(*) FILTER (WHERE ic.sonuc = 'Bekliyor')              AS bekliyor
    FROM (
      SELECT t.sonuc,
        SUM(CASE WHEN t.deneme_no = 1 THEN 1 ELSE 0 END)
          OVER (PARTITION BY t.hayvan_id ORDER BY t.tarih, t.deneme_no ROWS UNBOUNDED PRECEDING) AS cycle_no,
        h.genc_anne AS h_genc_anne, h.grup AS h_grup,
        (SELECT COUNT(*) FROM public.dogum d WHERE d.anne_id = h.id) AS dogum_sayisi
      FROM public.tohumlama t
      JOIN public.hayvanlar h ON h.id = t.hayvan_id
      WHERE h.cinsiyet = 'Dişi' AND h.durum = 'Aktif' AND h.kisir IS NOT TRUE
        AND (p_padok IS NULL OR h.padok = p_padok)
    ) ic
    GROUP BY 1
  )
  SELECT jsonb_object_agg(grp, payload) INTO v_verim
  FROM (
    SELECT CASE WHEN ks.k = 'Düve' THEN 'duve' ELSE 'inek' END AS grp,
      jsonb_build_object(
        'ham', jsonb_build_object('tohumlama', COALESCE(hm.tohumlama, 0), 'gebe', COALESCE(hm.gebe, 0), 'bos', COALESCE(hm.bos, 0), 'bekliyor', COALESCE(hm.bekliyor, 0), 'cr', ROUND(100.0 * COALESCE(hm.gebe, 0) / NULLIF(hm.tohumlama, 0), 1)),
        'hayvan_ort', (SELECT ROUND(100.0 * AVG(animal_skor), 1) FROM per_animal pa WHERE pa.kategori = ks.k),
        'hayvan_sayisi', (SELECT COUNT(*) FROM per_animal pa WHERE pa.kategori = ks.k),
        'cycle_ort', (SELECT ROUND(100.0 * AVG(skor), 1) FROM basari b WHERE b.kategori = ks.k),
        'cycle_sayisi', (SELECT COUNT(*) FROM basari b WHERE b.kategori = ks.k)
      ) AS payload
    FROM (SELECT unnest(ARRAY['Düve','İnek']) AS k) ks
    LEFT JOIN ham hm ON hm.kategori = ks.k
  ) z;

  -- Sperma performansı tohumlama-başına (winning-straw değil): gebe atış / toplam atış
  SELECT COALESCE(jsonb_agg(row_j ORDER BY (row_j->>'oran')::numeric DESC NULLS LAST), '[]'::jsonb) INTO v_sperma_pi
  FROM (
    SELECT jsonb_build_object('ad', sp, 'toplam', toplam, 'gebe', gebe, 'oran', ROUND(100.0 * gebe / NULLIF(toplam, 0), 1)) AS row_j
    FROM (
      SELECT LOWER(TRIM(split_part(t.sperma, '|', 1))) AS sp,
        COUNT(*) FILTER (WHERE t.sonuc <> 'Bekliyor') AS toplam,
        COUNT(*) FILTER (WHERE t.sonuc IN ('Gebe','Doğum Yaptı')) AS gebe
      FROM public.tohumlama t
      JOIN public.hayvanlar h ON h.id = t.hayvan_id
      WHERE h.cinsiyet = 'Dişi' AND h.durum = 'Aktif' AND h.kisir IS NOT TRUE
        AND (p_padok IS NULL OR h.padok = p_padok)
        AND t.sperma IS NOT NULL AND TRIM(t.sperma) <> ''
      GROUP BY 1
      HAVING COUNT(*) FILTER (WHERE t.sonuc <> 'Bekliyor') >= 3
    ) s
  ) q;

  v_gebelik := COALESCE(v_gebelik, '{"hayvan_ozet":{"toplam":0,"gebe":0,"bos":0,"devam_eden":0,"oran":null},"cycle_ozet":{"toplam_cycle":0,"basarili":0,"basarisiz":0,"devam_eden":0,"oran":null,"ort_deneme":null},"kategori":[],"sperma_all":[],"deneme":[]}'::jsonb)
    || jsonb_build_object('ureme_verimlilik', COALESCE(v_verim, '{}'::jsonb), 'sperma_pi', COALESCE(v_sperma_pi, '[]'::jsonb));

  RETURN jsonb_build_object(
    'hayvan', COALESCE(v_hayvan, '{"toplam":0,"inek":0,"duve":0,"buzagi":0,"erkek":0,"kisir":0,"hasta":0,"tohumlanan":0,"sessiz":0}'::jsonb),
    'gebelik', v_gebelik
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.stat_suru_ozet(text, boolean) TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════════
-- Faz C: v_eligible view + sessiz hayvanlar RPC'leri
-- ═══════════════════════════════════════════════════════════════

-- ── v_eligible — tohumlama için uygun hayvanlar (buzağı hariç, 13+ ay) ──
-- v2 (2026-06-25): sessiz_gun sinyal sıralaması — son_aktivite → son_dogum → dogum_tarihi → NULL.
--                  Hiç sinyal yoksa NULL (9999 hilesi kalkar). Row-set aynı.
CREATE OR REPLACE VIEW public.v_eligible AS
 SELECT h.id,
    h.kupe_no,
    h.grup,
    h.padok,
    son_dogum.tarih AS son_dogum_tarihi,
    CURRENT_DATE - son_dogum.tarih AS dogum_gun,
    son_aktivite.tarih AS son_aktivite_tarihi,
    CASE
        WHEN son_aktivite.tarih IS NOT NULL THEN CURRENT_DATE - son_aktivite.tarih
        WHEN son_dogum.tarih   IS NOT NULL THEN CURRENT_DATE - son_dogum.tarih
        WHEN h.dogum_tarihi    IS NOT NULL THEN CURRENT_DATE - h.dogum_tarihi
        ELSE NULL::integer
    END AS sessiz_gun
   FROM hayvanlar h
     LEFT JOIN LATERAL ( SELECT max(d.tarih) AS tarih
           FROM dogum d
          WHERE d.anne_id = h.id) son_dogum ON true
     LEFT JOIN LATERAL ( SELECT max(aktivite.tarih) AS tarih
           FROM ( SELECT tohumlama.tarih
                   FROM tohumlama
                  WHERE tohumlama.hayvan_id = h.id
                UNION ALL
                 SELECT kizginlik_log.tarih
                   FROM kizginlik_log
                  WHERE kizginlik_log.hayvan_id = h.id) aktivite) son_aktivite ON true
  WHERE h.cinsiyet = 'Dişi'::text
    AND h.durum = 'Aktif'::text
    AND h.kisir IS NOT TRUE
    AND h.grup !~~* '%buzağı%'::text
    AND h.grup !~~* '%buzagi%'::text
    AND h.grup !~~* '%Küçük%'::text
    AND h.grup !~~* '%Kucuk%'::text
    AND (h.dogum_tarihi IS NULL OR h.dogum_tarihi <= (CURRENT_DATE - '1 year 1 mon'::interval))
    AND NOT (EXISTS ( SELECT 1 FROM tohumlama t WHERE t.hayvan_id = h.id AND t.sonuc = 'Gebe'::text))
    AND NOT (EXISTS ( SELECT 1 FROM cases c WHERE c.animal_id = h.id AND c.status = 'active'::text))
    AND (son_dogum.tarih IS NULL OR son_dogum.tarih < (CURRENT_DATE - 55));
GRANT SELECT ON public.v_eligible TO anon, authenticated;

-- ── sessiz_hayvanlar_listele ──
CREATE OR REPLACE FUNCTION public.sessiz_hayvanlar_listele(
  p_padok   text    DEFAULT NULL,
  p_min_gun integer DEFAULT 55
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN (SELECT COALESCE(jsonb_agg(
    jsonb_build_object('hayvan_id', e.id, 'kupe_no', e.kupe_no, 'grup', e.grup, 'padok', e.padok,
      'sessiz_gun', COALESCE(e.sessiz_gun, 9999), 'son_aktivite', e.son_aktivite_tarihi)
    ORDER BY COALESCE(e.sessiz_gun, 9999) DESC), '[]'::jsonb)
  FROM public.v_eligible e
  WHERE (p_padok IS NULL OR e.padok = p_padok) AND COALESCE(e.sessiz_gun, 9999) >= p_min_gun);
END;
$$;
GRANT EXECUTE ON FUNCTION public.sessiz_hayvanlar_listele(text, integer) TO anon, authenticated;

-- ── sessiz_hayvanlar_reconcile (TEK OTORİTE) + eski jeneratör → wrapper ──
-- v2 (2026-06-25): kararlı kaynak='SESSIZ-<id>', 30g cooldown (yalnız kullanıcı tamamlaması).
-- Günlük cron: sessiz-reconcile-daily 05:00.
CREATE OR REPLACE FUNCTION public.sessiz_hayvanlar_reconcile()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_uretilen  integer := 0;
  v_kapatilan integer := 0;
  v_rec       record;
BEGIN
  FOR v_rec IN
    SELECT e.id, e.kupe_no, e.sessiz_gun
    FROM public.v_eligible e
    WHERE e.sessiz_gun >= 55
      AND NOT EXISTS (
        SELECT 1 FROM public.gorev_log g
        WHERE g.hayvan_id = e.id
          AND g.kaynak = 'SESSIZ-' || e.id
          AND g.tamamlandi = false AND g.iptal = false
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.gorev_log g
        WHERE g.hayvan_id = e.id
          AND g.kaynak = 'SESSIZ-' || e.id
          AND g.tamamlandi = true
          AND g.tamamlanma_tarihi >= (CURRENT_DATE - 30)
      )
  LOOP
    INSERT INTO public.gorev_log
      (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, iptal, kaynak)
    VALUES (
      gen_random_uuid(), v_rec.id, 'VETERINER_KONTROL',
      format('Sessiz hayvan: %s gündür üreme aktivitesi yok (%s)', v_rec.sessiz_gun, v_rec.kupe_no),
      CURRENT_DATE, false, false, 'SESSIZ-' || v_rec.id
    );
    v_uretilen := v_uretilen + 1;
  END LOOP;

  UPDATE public.gorev_log g
  SET iptal = true, kapatan_ref = 'sessiz-noteligible'
  WHERE g.gorev_tipi = 'VETERINER_KONTROL'
    AND g.kaynak LIKE 'SESSIZ-%'
    AND g.tamamlandi = false AND g.iptal = false
    AND NOT EXISTS (
      SELECT 1 FROM public.v_eligible e
      WHERE e.id = g.hayvan_id AND e.sessiz_gun >= 55
    );
  GET DIAGNOSTICS v_kapatilan = ROW_COUNT;

  RETURN jsonb_build_object('uretilen', v_uretilen, 'kapatilan', v_kapatilan, 'zaman', now());
END;
$function$
;
GRANT EXECUTE ON FUNCTION public.sessiz_hayvanlar_reconcile() TO anon, authenticated;

-- Eski jeneratör → ince wrapper (kalıntı çağıranlar güvenli; tek otorite reconcile)
CREATE OR REPLACE FUNCTION public.sessiz_hayvanlar_gorev_olustur()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE v_res jsonb;
BEGIN
  v_res := public.sessiz_hayvanlar_reconcile();
  RETURN COALESCE((v_res->>'uretilen')::int, 0);
END;
$function$
;
GRANT EXECUTE ON FUNCTION public.sessiz_hayvanlar_gorev_olustur() TO anon, authenticated;

-- ── _sessiz_gorev_iptal helper ──
CREATE OR REPLACE FUNCTION public._sessiz_gorev_iptal(p_hayvan_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.gorev_log
  SET iptal = true, kapatan_ref = 'sessiz-auto-iptal'
  WHERE hayvan_id = p_hayvan_id
    AND gorev_tipi = 'VETERINER_KONTROL'
    AND tamamlandi = false AND iptal = false;
END;
$$;
GRANT EXECUTE ON FUNCTION public._sessiz_gorev_iptal(text) TO anon, authenticated;

-- ── Sessiz hayvan auto-cancel triggerları ──
-- tohumlama INSERT
CREATE OR REPLACE FUNCTION public._trg_tohumlama_sessiz_iptal()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN PERFORM public._sessiz_gorev_iptal(NEW.hayvan_id); RETURN NEW; END;
$$;
DROP TRIGGER IF EXISTS trg_tohumlama_sessiz_iptal ON public.tohumlama;
CREATE TRIGGER trg_tohumlama_sessiz_iptal
  AFTER INSERT ON public.tohumlama FOR EACH ROW EXECUTE FUNCTION public._trg_tohumlama_sessiz_iptal();

-- tohumlama UPDATE → Gebe
CREATE OR REPLACE FUNCTION public._trg_tohumlama_gebe_sessiz_iptal()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.sonuc = 'Gebe' AND (OLD.sonuc IS DISTINCT FROM 'Gebe') THEN
    PERFORM public._sessiz_gorev_iptal(NEW.hayvan_id);
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_tohumlama_gebe_sessiz_iptal ON public.tohumlama;
CREATE TRIGGER trg_tohumlama_gebe_sessiz_iptal
  AFTER UPDATE OF sonuc ON public.tohumlama FOR EACH ROW EXECUTE FUNCTION public._trg_tohumlama_gebe_sessiz_iptal();

-- kizginlik_log INSERT
CREATE OR REPLACE FUNCTION public._trg_kizginlik_sessiz_iptal()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN PERFORM public._sessiz_gorev_iptal(NEW.hayvan_id); RETURN NEW; END;
$$;
DROP TRIGGER IF EXISTS trg_kizginlik_sessiz_iptal ON public.kizginlik_log;
CREATE TRIGGER trg_kizginlik_sessiz_iptal
  AFTER INSERT ON public.kizginlik_log FOR EACH ROW EXECUTE FUNCTION public._trg_kizginlik_sessiz_iptal();

-- cases INSERT → sadece Üreme kategorisi
CREATE OR REPLACE FUNCTION public._trg_case_ureme_sessiz_iptal()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_cat text;
BEGIN
  SELECT d.category INTO v_cat FROM public.diseases d WHERE d.id = NEW.disease_id;
  IF v_cat = 'Üreme' THEN PERFORM public._sessiz_gorev_iptal(NEW.animal_id); END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_case_ureme_sessiz_iptal ON public.cases;
CREATE TRIGGER trg_case_ureme_sessiz_iptal
  AFTER INSERT ON public.cases FOR EACH ROW EXECUTE FUNCTION public._trg_case_ureme_sessiz_iptal();

-- ── Gebelik kontrol görev iptali fix ─────────────────────────────────────────
-- Sorun: tohumlama_kaydet / sonuc_gebe / sonuc_bos, GEBELIK_KONTROL ve
--        TOHUMLAMA_HAZIRLIK görevlerini iptal etmiyordu.
-- Düzeltme: Sonuç yazılırken bekleyen kontrol görevleri otomatik iptal edilir,
--           sebep islem_log snapshot'a 'iptal_gorevler' olarak kaydedilir.
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. tohumlama_kaydet (5-param) — eski kontrol görevlerini yeni kayıt öncesi iptal et
DROP FUNCTION IF EXISTS public.tohumlama_kaydet(text, date, text, text, text);
CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_gebe(
  p_tohumlama_id text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh               record;
  v_son_toh_id        text;
  v_islem_id          text   := gen_random_uuid()::text;
  v_onceki_durum      text;
  v_iptal_gorev_ids   text[] := '{}';
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama WHERE id::text = p_tohumlama_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  IF v_toh.sonuc != 'Bekliyor' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Bekliyor durumundaki tohumlama gebe ilanı alabilir');
  END IF;

  SELECT id::text INTO v_son_toh_id
  FROM public.tohumlama
  WHERE hayvan_id = v_toh.hayvan_id
  ORDER BY deneme_no DESC LIMIT 1 FOR UPDATE;

  IF v_son_toh_id != p_tohumlama_id THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece son tohumlama gebe ilanı alabilir');
  END IF;

  SELECT tohumlama_durumu INTO v_onceki_durum
  FROM public.hayvanlar WHERE id = v_toh.hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil');
  END IF;

  UPDATE public.tohumlama SET sonuc = 'Gebe' WHERE id::text = p_tohumlama_id;
  UPDATE public.hayvanlar SET tohumlama_durumu = 'Gebe' WHERE id = v_toh.hayvan_id;

  -- Bekleyen gebelik kontrol görevlerini topla ve iptal et (sebep: gebe)
  SELECT COALESCE(array_agg(id::text), '{}') INTO v_iptal_gorev_ids
  FROM public.gorev_log
  WHERE hayvan_id = v_toh.hayvan_id
    AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK')
    AND NOT tamamlandi AND NOT iptal;

  UPDATE public.gorev_log SET iptal = true
  WHERE hayvan_id = v_toh.hayvan_id
    AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK')
    AND NOT tamamlandi AND NOT iptal;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id, 'GEBE_ATAMA', v_toh.hayvan_id, p_tohumlama_id, 'tohumlama',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object('tablo', 'tohumlama', 'id', p_tohumlama_id, 'onceki', jsonb_build_object('sonuc', v_toh.sonuc)),
        jsonb_build_object('tablo', 'hayvanlar', 'id', v_toh.hayvan_id, 'onceki', jsonb_build_object('tohumlama_durumu', v_onceki_durum))
      ),
      'iptal_gorevler', to_jsonb(v_iptal_gorev_ids),
      'iptal_sebep', 'gebe'
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.tohumlama_sonuc_gebe(text) TO anon, authenticated;

-- 3. tohumlama_sonuc_bos — Boş atanınca bekleyen kontrol görevlerini iptal et
CREATE OR REPLACE FUNCTION public.tohumlama_sonuc_bos(
  p_tohumlama_id text,
  p_notlar       text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_toh               record;
  v_islem_id          text   := gen_random_uuid()::text;
  v_onceki_durum      text;
  v_iptal_gorev_ids   text[] := '{}';
BEGIN
  SELECT * INTO v_toh FROM public.tohumlama WHERE id::text = p_tohumlama_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Tohumlama bulunamadı');
  END IF;

  IF v_toh.sonuc != 'Bekliyor' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Sadece Bekliyor durumundaki tohumlama boş ilan edilebilir');
  END IF;

  SELECT tohumlama_durumu INTO v_onceki_durum
  FROM public.hayvanlar WHERE id = v_toh.hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Hayvan aktif değil');
  END IF;

  UPDATE public.tohumlama SET sonuc = 'Boş' WHERE id::text = p_tohumlama_id;
  UPDATE public.hayvanlar SET tohumlama_durumu = 'Boş' WHERE id = v_toh.hayvan_id;

  -- Bekleyen gebelik kontrol görevlerini topla ve iptal et (sebep: bos)
  SELECT COALESCE(array_agg(id::text), '{}') INTO v_iptal_gorev_ids
  FROM public.gorev_log
  WHERE hayvan_id = v_toh.hayvan_id
    AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK')
    AND NOT tamamlandi AND NOT iptal;

  UPDATE public.gorev_log SET iptal = true
  WHERE hayvan_id = v_toh.hayvan_id
    AND gorev_tipi IN ('GEBELIK_KONTROL', 'TOHUMLAMA_HAZIRLIK')
    AND NOT tamamlandi AND NOT iptal;

  INSERT INTO public.islem_log (id, tip, ana_hayvan_id, ref_id, ref_tablo, snapshot)
  VALUES (
    v_islem_id, 'TOHUMLAMA_SONUC', v_toh.hayvan_id, p_tohumlama_id, 'tohumlama',
    jsonb_build_object(
      'olusturulan', '[]'::jsonb,
      'guncellenen', jsonb_build_array(
        jsonb_build_object('tablo', 'tohumlama', 'id', p_tohumlama_id, 'onceki', jsonb_build_object('sonuc', v_toh.sonuc)),
        jsonb_build_object('tablo', 'hayvanlar', 'id', v_toh.hayvan_id, 'onceki', jsonb_build_object('tohumlama_durumu', v_onceki_durum))
      ),
      'iptal_gorevler', to_jsonb(v_iptal_gorev_ids),
      'iptal_sebep', 'bos'
    )
  );

  RETURN jsonb_build_object('ok', true, 'islem_id', v_islem_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.tohumlama_sonuc_bos(text, text) TO anon, authenticated;

END;

-- ══════════════════════════════════════════════════════════════
-- Protokol Uyarı Sistemi (Task 1-11, 2026-06-03)
-- Yeni fonksiyonlar ve trigger'lar
-- ══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public._etken_kod_bul(
  p_stok_id text DEFAULT NULL,
  p_vaccine_id uuid DEFAULT NULL
) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_class_name text;
  v_group_name text;
  v_active_ing text;
  v_stok_ad text;
  v_vaccine_name text;
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

    -- Önce stok.drug_product_id FK kullan (en doğru yol)
    SELECT dc.group_name, dc.class_name, dc.active_ingredient
    INTO v_group_name, v_class_name, v_active_ing
    FROM public.drug_products dp
    JOIN public.drug_classes dc ON dc.id = dp.drug_class_id
    WHERE dp.id = (SELECT drug_product_id FROM public.stok WHERE id = p_stok_id)
    LIMIT 1;

    -- Fallback: brand_name eşleşmesi
    IF v_class_name IS NULL THEN
      SELECT dc.group_name, dc.class_name, dc.active_ingredient
      INTO v_group_name, v_class_name, v_active_ing
      FROM public.drug_products dp
      JOIN public.drug_classes dc ON dc.id = dp.drug_class_id
      WHERE dp.brand_name ILIKE '%' || COALESCE(v_stok_ad,'') || '%'
      LIMIT 1;
    END IF;

    -- Sınıf bazlı eşleşme
    IF v_class_name ILIKE '%oksitosin%' OR v_active_ing ILIKE '%oxytocin%' THEN RETURN 'OKSITOSIN'; END IF;
    IF v_class_name ILIKE '%prostaglandin%' OR v_group_name ILIKE '%PG%' OR v_active_ing ILIKE '%dinoprost%' OR v_active_ing ILIKE '%cloprostenol%' THEN RETURN 'PG'; END IF;
    IF v_active_ing ILIKE '%E Vitamini%' THEN RETURN 'E_VIT'; END IF;
    IF v_class_name ILIKE '%E Vit%' OR v_stok_ad ILIKE '%yeldif%' OR v_stok_ad ILIKE '%e vit%' THEN RETURN 'E_VIT'; END IF;
    IF v_class_name ILIKE '%ademin%' OR v_stok_ad ILIKE '%ademin%' THEN RETURN 'ADEMIN'; END IF;
    IF v_class_name ILIKE '%kalsiyum%' OR v_class_name ILIKE '%calcium%' OR v_stok_ad ILIKE '%kalsiyum%' THEN RETURN 'KALSIYUM'; END IF;

    RETURN NULL;
  END IF;

  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public._gorev_dinle(
  p_hayvan_id text,
  p_etken_kod text,
  p_ref text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev_id uuid;
BEGIN
  IF p_etken_kod IS NULL OR p_hayvan_id IS NULL THEN
    RETURN;
  END IF;

  SELECT id INTO v_gorev_id
  FROM public.gorev_log
  WHERE hayvan_id = p_hayvan_id
    AND etken_kod = p_etken_kod
    AND tamamlandi = false
    AND iptal = false
  ORDER BY hedef_tarih ASC
  LIMIT 1;

  IF v_gorev_id IS NOT NULL THEN
    UPDATE public.gorev_log
    SET tamamlandi = true,
        tamamlanma_tarihi = now(),
        kapatan_ref = p_ref
    WHERE id = v_gorev_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.hizli_uygulama(
  p_hayvan_id text,
  p_stok_id text,
  p_doz numeric,
  p_birim text,
  p_rota text,
  p_notlar text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_hayvan record;
  v_stok record;
  v_etken text;
  v_id uuid;
  v_kalan numeric;
BEGIN
  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Hayvan bulunamadı veya aktif değil');
  END IF;

  SELECT * INTO v_stok FROM public.stok WHERE id = p_stok_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Stok bulunamadı');
  END IF;

  v_etken := public._etken_kod_bul(p_stok_id, NULL);

  INSERT INTO public.uygulama_log (hayvan_id, stok_id, etken_kod, doz, birim, rota, notlar)
  VALUES (p_hayvan_id, p_stok_id, v_etken, p_doz, p_birim, p_rota, p_notlar)
  RETURNING id INTO v_id;

  -- Stok düşüm
  INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
  VALUES (gen_random_uuid(), p_stok_id, 'Hızlı Uygulama', p_doz,
          'Hızlı Uygulama — ' || v_hayvan.kupe_no || ' — ' || v_stok.urun_adi, false);

  SELECT COALESCE(s.baslangic_miktar, 0) - COALESCE(SUM(CASE WHEN sh.iptal = false THEN sh.miktar ELSE 0 END), 0)
  INTO v_kalan
  FROM public.stok s
  LEFT JOIN public.stok_hareket sh ON sh.stok_id = s.id
  WHERE s.id = p_stok_id
  GROUP BY s.baslangic_miktar;

  RETURN jsonb_build_object(
    'ok', true,
    'id', v_id,
    'etken_kod', v_etken,
    'stok_kalan', COALESCE(v_kalan, 0)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.hizli_uygulama_geri_al(
  p_uygulama_id uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uyg record;
  v_hayvan record;
BEGIN
  SELECT * INTO v_uyg FROM public.uygulama_log WHERE id = p_uygulama_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Uygulama kaydı bulunamadı');
  END IF;

  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = v_uyg.hayvan_id;

  -- Stok iade (ters hareket)
  IF v_uyg.stok_id IS NOT NULL THEN
    INSERT INTO public.stok_hareket (id, stok_id, tur, miktar, notlar, iptal)
    VALUES (gen_random_uuid(), v_uyg.stok_id, 'İade (Hızlı Uyg.)', -v_uyg.doz,
            'Geri Al — ' || COALESCE(v_hayvan.kupe_no, v_uyg.hayvan_id), false);
  END IF;

  -- Bu uygulama ile kapanan görevi tekrar aç
  UPDATE public.gorev_log
  SET tamamlandi = false,
      tamamlanma_tarihi = NULL,
      kapatan_ref = NULL
  WHERE kapatan_ref = 'uygulama_log:' || p_uygulama_id::text;

  DELETE FROM public.uygulama_log WHERE id = p_uygulama_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

-- Protokol eksik tara scanner (Task 11)
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
  -- A. DOĞUM SONRASI PROTOKOL
  FOR v_rec IN
    SELECT d.id, d.anne_id AS hayvan_id, d.tarih AS dogum_tarihi, h.kupe_no, h.grup, a.gun, a.ek, a.aciklama
    FROM (
      SELECT DISTINCT ON (anne_id) *
      FROM public.dogum
      ORDER BY anne_id, tarih DESC
    ) d
    JOIN public.hayvanlar h ON h.id = d.anne_id AND h.durum = 'Aktif'
    CROSS JOIN (VALUES
      (0,'OKSITOSIN','Dogum gunu: Oksitosin'),(0,'ADEMIN','Dogum gunu: Ademin'),(0,'KALSIYUM','Dogum gunu: Kalsiyum'),
      (2,'PG','2. Gun PG'),(11,'PG','11. Gun PG'),(25,'PG','25. Gun PG'),
      (53,'ADEMIN','53. Gun: Ademin'),(54,'E_VIT','54. Gun: Yeldif')
    ) AS a(gun,ek,aciklama)
    WHERE d.tarih >= v_today - 70 AND d.tarih <= v_today
  LOOP
    DECLARE
      v_hedef date := v_rec.dogum_tarihi + v_rec.gun;
      v_gecikme int; v_durum text;
    BEGIN
      IF v_hedef > v_today + 7 THEN CONTINUE; END IF;
      v_found := false; v_tamamlanma := NULL; v_kapatan := NULL;

      SELECT true,g.tamamlanma_tarihi,g.kapatan_ref INTO v_found,v_tamamlanma,v_kapatan
      FROM gorev_log g WHERE g.hayvan_id=v_rec.hayvan_id AND g.etken_kod=v_rec.ek AND g.tamamlandi=true AND g.hedef_tarih BETWEEN v_hedef-3 AND v_hedef+3 LIMIT 1;

      IF v_found IS NOT TRUE THEN SELECT true, u.created_at, 'uygulama_log:'||u.id::text INTO v_found, v_tamamlanma, v_kapatan FROM uygulama_log u WHERE u.hayvan_id=v_rec.hayvan_id AND u.etken_kod=v_rec.ek AND u.tarih BETWEEN v_hedef-3 AND v_hedef+3 ORDER BY u.created_at DESC LIMIT 1; END IF;
      IF v_found IS NOT TRUE THEN SELECT true INTO v_found FROM drug_administrations da JOIN treatment_days td ON td.id=da.treatment_day_id JOIN cases c ON c.id=td.case_id WHERE c.animal_id=v_rec.hayvan_id AND public._etken_kod_bul(da.stok_id,NULL)=v_rec.ek AND da.created_at::date BETWEEN v_hedef-3 AND v_hedef+3 LIMIT 1; END IF;
      IF v_found IS NOT TRUE THEN SELECT true INTO v_found FROM protokol_dismiss pd WHERE pd.hayvan_id=v_rec.hayvan_id AND pd.etken_kod=v_rec.ek AND pd.protokol='DOGUM_PROTOKOL' LIMIT 1; END IF;

      v_gecikme := v_today - v_hedef;
      IF v_found IS TRUE AND v_tamamlanma IS NOT NULL AND v_tamamlanma >= now()-interval '24 hours' THEN v_durum:='tamamlandi';
      ELSIF v_found IS TRUE THEN CONTINUE;
      ELSIF v_gecikme >= 0 THEN v_durum:='eksik'; ELSE v_durum:='yaklasan'; END IF;

      v_result := v_result || jsonb_build_object('hayvan_id',v_rec.hayvan_id,'kupe_no',v_rec.kupe_no,'grup',v_rec.grup,'protokol','DOGUM_PROTOKOL','adim',v_rec.aciklama,'etken_kod',v_rec.ek,'hedef_tarih',v_hedef,'gecikme_gun',v_gecikme,'durum',v_durum,'tamamlanma_tarihi',v_tamamlanma,'kapatan_ref',v_kapatan);
    END;
  END LOOP;

  -- B. İLERI GEBE PROTOKOL
  FOR v_rec IN
    SELECT t.id,t.hayvan_id,t.tarih::date AS toh_tarihi,h.kupe_no,h.grup
    FROM public.tohumlama t JOIN public.hayvanlar h ON h.id=t.hayvan_id AND h.durum='Aktif'
    WHERE t.sonuc='Gebe' AND (v_today-t.tarih::date)>=230
  LOOP
    DECLARE v_a record;
    BEGIN
      FOR v_a IN SELECT * FROM (VALUES(240,'ROTA','Rota-Corona Aşısı'),(260,'ADEMIN','SC Ademin uygulaması'),(265,'E_VIT','IM E Vitamini uygulaması')) AS t(gun,ek,aciklama) LOOP
        DECLARE v_hedef date:=v_rec.toh_tarihi+v_a.gun; v_gecikme int; v_durum text;
        BEGIN
          IF v_hedef>v_today+7 THEN CONTINUE; END IF;
          v_found:=false; v_tamamlanma:=NULL; v_kapatan:=NULL;
          SELECT true,g.tamamlanma_tarihi,g.kapatan_ref INTO v_found,v_tamamlanma,v_kapatan FROM gorev_log g WHERE g.hayvan_id=v_rec.hayvan_id AND g.etken_kod=v_a.ek AND g.tamamlandi=true AND g.hedef_tarih BETWEEN v_hedef-3 AND v_hedef+3 LIMIT 1;
          IF v_found IS NOT TRUE AND v_a.ek='ROTA' THEN SELECT true INTO v_found FROM vaccination_log vl JOIN vaccines v ON v.id=vl.vaccine_id WHERE vl.animal_id=v_rec.hayvan_id AND v.name ILIKE '%Rota%' AND vl.vaccination_date BETWEEN v_hedef-7 AND v_hedef+7 LIMIT 1; END IF;
          IF v_found IS NOT TRUE THEN SELECT true, u.created_at, 'uygulama_log:'||u.id::text INTO v_found, v_tamamlanma, v_kapatan FROM uygulama_log u WHERE u.hayvan_id=v_rec.hayvan_id AND u.etken_kod=v_a.ek AND u.tarih BETWEEN v_hedef-3 AND v_hedef+3 ORDER BY u.created_at DESC LIMIT 1; END IF;
          IF v_found IS NOT TRUE THEN SELECT true INTO v_found FROM protokol_dismiss pd WHERE pd.hayvan_id=v_rec.hayvan_id AND pd.etken_kod=v_a.ek AND pd.protokol='ILERI_GEBE_PROTOKOL' LIMIT 1; END IF;
          v_gecikme:=v_today-v_hedef;
          IF v_found IS TRUE AND v_tamamlanma IS NOT NULL AND v_tamamlanma>=now()-interval '24 hours' THEN v_durum:='tamamlandi'; ELSIF v_found IS TRUE THEN CONTINUE; ELSIF v_gecikme>=0 THEN v_durum:='eksik'; ELSE v_durum:='yaklasan'; END IF;
          v_result:=v_result||jsonb_build_object('hayvan_id',v_rec.hayvan_id,'kupe_no',v_rec.kupe_no,'grup',v_rec.grup,'protokol','ILERI_GEBE_PROTOKOL','adim',v_a.aciklama,'etken_kod',v_a.ek,'hedef_tarih',v_hedef,'gecikme_gun',v_gecikme,'durum',v_durum,'tamamlanma_tarihi',v_tamamlanma,'kapatan_ref',v_kapatan);
        END;
      END LOOP;
    END;
  END LOOP;

  -- C. KIZGINLIK TAKİBİ
  FOR v_rec IN
    SELECT d.id,d.anne_id AS hayvan_id,d.tarih AS dogum_tarihi,h.kupe_no,h.grup
    FROM (
      SELECT DISTINCT ON (anne_id) *
      FROM public.dogum
      ORDER BY anne_id, tarih DESC
    ) d
    JOIN public.hayvanlar h ON h.id=d.anne_id AND h.durum='Aktif'
    WHERE (v_today-d.tarih) BETWEEN 55 AND 75
  LOOP
    DECLARE v_hedef date:=v_rec.dogum_tarihi+58; v_gecikme int:=v_today-v_hedef; v_durum text;
    BEGIN
      v_found:=false; v_tamamlanma:=NULL; v_kapatan:=NULL;
      SELECT true,g.tamamlanma_tarihi INTO v_found,v_tamamlanma FROM gorev_log g WHERE g.hayvan_id=v_rec.hayvan_id AND g.aciklama ILIKE '%kizginlik%' AND g.tamamlandi=true AND g.hedef_tarih BETWEEN v_hedef-3 AND v_hedef+7 LIMIT 1;
      IF v_found IS NOT TRUE THEN SELECT true INTO v_found FROM kizginlik_log k WHERE k.hayvan_id=v_rec.hayvan_id AND k.tarih>=v_rec.dogum_tarihi+50 LIMIT 1; END IF;
      IF v_found IS NOT TRUE THEN SELECT true INTO v_found FROM tohumlama t WHERE t.hayvan_id=v_rec.hayvan_id AND t.tarih>=v_rec.dogum_tarihi+50 LIMIT 1; END IF;
      IF v_found IS NOT TRUE THEN SELECT true INTO v_found FROM protokol_dismiss pd WHERE pd.hayvan_id=v_rec.hayvan_id AND pd.protokol='KIZGINLIK_TAKIP' LIMIT 1; END IF;
      IF v_found IS TRUE AND v_tamamlanma IS NOT NULL AND v_tamamlanma>=now()-interval '24 hours' THEN v_durum:='tamamlandi'; ELSIF v_found IS TRUE THEN CONTINUE; ELSIF v_gecikme>=0 THEN v_durum:='eksik'; ELSE v_durum:='yaklasan'; END IF;
      v_result:=v_result||jsonb_build_object('hayvan_id',v_rec.hayvan_id,'kupe_no',v_rec.kupe_no,'grup',v_rec.grup,'protokol','KIZGINLIK_TAKIP','adim','58-63. gun kizginlik takibi','etken_kod',NULL,'hedef_tarih',v_hedef,'gecikme_gun',v_gecikme,'durum',v_durum,'tamamlanma_tarihi',v_tamamlanma,'kapatan_ref',v_kapatan);
    END;
  END LOOP;

  RETURN v_result;
END;
$$;

-- Dinleme trigger fonksiyonları + trigger'lar
CREATE OR REPLACE FUNCTION public.fn_dinle_vaccination()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_etken text;
BEGIN
  v_etken := public._etken_kod_bul(NULL, NEW.vaccine_id);
  IF v_etken IS NOT NULL THEN
    PERFORM public._gorev_dinle(NEW.animal_id, v_etken, 'vaccination_log:' || NEW.id::text);
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_dinle_vaccination ON public.vaccination_log;
CREATE TRIGGER trg_dinle_vaccination AFTER INSERT ON public.vaccination_log FOR EACH ROW EXECUTE FUNCTION public.fn_dinle_vaccination();

CREATE OR REPLACE FUNCTION public.fn_dinle_uygulama()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.etken_kod IS NOT NULL THEN
    PERFORM public._gorev_dinle(NEW.hayvan_id, NEW.etken_kod, 'uygulama_log:' || NEW.id::text);
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_dinle_uygulama ON public.uygulama_log;
CREATE TRIGGER trg_dinle_uygulama AFTER INSERT ON public.uygulama_log FOR EACH ROW EXECUTE FUNCTION public.fn_dinle_uygulama();

CREATE OR REPLACE FUNCTION public.fn_dinle_drug_admin()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_etken text;
  v_animal_id text;
BEGIN
  v_etken := public._etken_kod_bul(NEW.stok_id, NULL);
  IF v_etken IS NULL THEN RETURN NEW; END IF;
  SELECT c.animal_id INTO v_animal_id
  FROM public.treatment_days td JOIN public.cases c ON c.id = td.case_id
  WHERE td.id = NEW.treatment_day_id;
  IF v_animal_id IS NOT NULL THEN
    PERFORM public._gorev_dinle(v_animal_id, v_etken, 'drug_admin:' || NEW.id::text);
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_dinle_drug_admin ON public.drug_administrations;
CREATE TRIGGER trg_dinle_drug_admin AFTER INSERT ON public.drug_administrations FOR EACH ROW EXECUTE FUNCTION public.fn_dinle_drug_admin();

-- Scanner performans index'leri (Review Fix — Task 17)
CREATE INDEX IF NOT EXISTS idx_dogum_anne_tarih ON public.dogum(anne_id, tarih);
CREATE INDEX IF NOT EXISTS idx_tohumlama_hayvan_sonuc_tarih ON public.tohumlama(hayvan_id, sonuc, tarih);

-- ═══════════════════════════════════════════════════════════════════════════
-- protokol_instance + lifecycle cancel (2026-06-05 — migration 000003-000009)
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. protokol_instance tablosu
CREATE TABLE IF NOT EXISTS public.protokol_instance (
  id            uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  hayvan_id     text        NOT NULL REFERENCES public.hayvanlar(id) ON DELETE CASCADE,
  tip           text        NOT NULL,
  alttip        text        NOT NULL,
  kaynak_ref    text        NOT NULL,
  baslangic     date        NOT NULL,
  durum         text        NOT NULL DEFAULT 'aktif',
  kapandi_at    timestamptz,
  kapandi_sebep text,
  created_at    timestamptz DEFAULT now(),
  CONSTRAINT protokol_instance_kaynak_unique UNIQUE (kaynak_ref)
);
ALTER TABLE public.protokol_instance ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "protokol_instance_all" ON public.protokol_instance;
CREATE POLICY "protokol_instance_all" ON public.protokol_instance FOR ALL USING (true) WITH CHECK (true);
CREATE INDEX IF NOT EXISTS idx_pi_hayvan_durum ON public.protokol_instance(hayvan_id, durum);
CREATE INDEX IF NOT EXISTS idx_pi_tip_alttip   ON public.protokol_instance(tip, alttip);
CREATE INDEX IF NOT EXISTS idx_pi_kaynak_ref   ON public.protokol_instance(kaynak_ref);

-- 2. gorev_log.protokol_instance_id FK
ALTER TABLE public.gorev_log
  ADD COLUMN IF NOT EXISTS protokol_instance_id uuid
  REFERENCES public.protokol_instance(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_gorev_protokol ON public.gorev_log(protokol_instance_id)
  WHERE protokol_instance_id IS NOT NULL;

-- 3. _protokol_kapat helper
CREATE OR REPLACE FUNCTION public._protokol_kapat(
  p_kaynak_ref  text,
  p_sebep       text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.gorev_log
  SET iptal = true
  WHERE kaynak = p_kaynak_ref
    AND tamamlandi = false
    AND iptal = false;

  UPDATE public.protokol_instance
  SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = p_sebep
  WHERE kaynak_ref = p_kaynak_ref AND durum = 'aktif';
END;
$$;
GRANT EXECUTE ON FUNCTION public._protokol_kapat(text, text) TO anon, authenticated;

-- 4. cikis_yap
CREATE OR REPLACE FUNCTION public.dogum_kaydet(
  p_anne_id    text,
  p_tarih      date,
  p_kupe       text,
  p_cins       text    DEFAULT 'Dişi',
  p_tip        text    DEFAULT 'Normal',
  p_kg         numeric DEFAULT NULL,
  p_baba       text    DEFAULT NULL,
  p_hekim_id   text    DEFAULT NULL
) RETURNS jsonb AS $$
DECLARE
  v_anne           record;
  v_dogum_id       uuid := gen_random_uuid();
  v_buzagi_id      text;
  v_ana_gorev      uuid := gen_random_uuid();
  v_sayac          integer;
  v_dup            text;
  v_baba_bilgi     text;
  v_anne_inst_id   uuid;
  v_buzagi_inst_id uuid;
BEGIN
  SELECT * INTO v_anne FROM public.hayvanlar WHERE id = p_anne_id AND durum = 'Aktif';
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Anne bulunamadı'); END IF;

  SELECT id INTO v_dup FROM public.hayvanlar WHERE kupe_no = p_kupe OR devlet_kupe = p_kupe LIMIT 1;
  IF FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Bu küpe zaten kayıtlı: ' || p_kupe); END IF;

  IF p_baba IS NULL OR p_baba = '' THEN
    SELECT sperma INTO v_baba_bilgi FROM public.tohumlama
    WHERE hayvan_id = p_anne_id AND sonuc = 'Gebe' ORDER BY tarih DESC LIMIT 1;
  ELSE v_baba_bilgi := p_baba; END IF;

  INSERT INTO public.dogum (id, anne_id, tarih, yavru_cins, yavru_kupe, yavru_irk, dogum_tipi, hekim_id, dogum_kg, baba_bilgi)
  VALUES (v_dogum_id, p_anne_id, p_tarih, p_cins, p_kupe, v_anne.irk, p_tip, p_hekim_id, p_kg, v_baba_bilgi);

  SELECT 'H' || LPAD((COUNT(*)+1)::text, 6, '0') INTO v_buzagi_id FROM public.hayvanlar;

  INSERT INTO public.hayvanlar (id, kupe_no, irk, dogum_tarihi, anne_id, baba_bilgi, cinsiyet, grup, padok, durum, dogum_kg)
  VALUES (v_buzagi_id, p_kupe, v_anne.irk, p_tarih, p_anne_id, v_baba_bilgi, p_cins,
          'Süt İçen Buzağı', 'Buzağı Padok (Süt İçenler)', 'Aktif', p_kg);

  UPDATE public.hayvanlar SET grup = 'Sağmal (Laktasyonda)', padok = 'Sağmal Padok' WHERE id = p_anne_id;

  INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
  VALUES (p_anne_id, 'UREME', 'DOGUM', 'DOGUM-' || p_anne_id, p_tarih, 'aktif')
  ON CONFLICT (kaynak_ref) DO UPDATE SET durum = 'aktif', kapandi_at = NULL, kapandi_sebep = NULL
  RETURNING id INTO v_anne_inst_id;
  IF v_anne_inst_id IS NULL THEN
    SELECT id INTO v_anne_inst_id FROM public.protokol_instance WHERE kaynak_ref = 'DOGUM-' || p_anne_id;
  END IF;

  INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
  VALUES (v_buzagi_id, 'BAKIM', 'BUZAGI', 'BUZAGI-' || v_buzagi_id, p_tarih, 'aktif')
  RETURNING id INTO v_buzagi_inst_id;

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod, protokol_instance_id)
  VALUES
    (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Oksitosin', p_tarih,      false, 'DOGUM-' || p_anne_id, 'OKSITOSIN', v_anne_inst_id),
    (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Ademin',    p_tarih,      false, 'DOGUM-' || p_anne_id, 'ADEMIN',    v_anne_inst_id),
    (gen_random_uuid(), p_anne_id, 'ILAC', 'Doğum günü: Kalsiyum',  p_tarih,      false, 'DOGUM-' || p_anne_id, 'KALSIYUM',  v_anne_inst_id),
    (gen_random_uuid(), p_anne_id, 'ILAC', '2. Gün PG',             p_tarih + 2,  false, 'DOGUM-' || p_anne_id, 'PG',        v_anne_inst_id),
    (gen_random_uuid(), p_anne_id, 'ILAC', '11. Gün PG',            p_tarih + 11, false, 'DOGUM-' || p_anne_id, 'PG',        v_anne_inst_id),
    (gen_random_uuid(), p_anne_id, 'ILAC', '25. Gün PG',            p_tarih + 25, false, 'DOGUM-' || p_anne_id, 'PG',        v_anne_inst_id),
    (gen_random_uuid(), p_anne_id, 'ILAC', '53. Gün: Ademin',       p_tarih + 53, false, 'DOGUM-' || p_anne_id, 'ADEMIN',    v_anne_inst_id),
    (gen_random_uuid(), p_anne_id, 'ILAC', '53. Gün: Yeldif',       p_tarih + 53, false, 'DOGUM-' || p_anne_id, 'E_VIT',     v_anne_inst_id),
    (gen_random_uuid(), p_anne_id, 'ILAC', '54. Gün: Yeldif',       p_tarih + 54, false, 'DOGUM-' || p_anne_id, 'E_VIT',     v_anne_inst_id),
    (gen_random_uuid(), p_anne_id, 'DIGER','⚡ 58-63. gün kızgınlık takibi', p_tarih + 58, false, 'DOGUM-' || p_anne_id, NULL, v_anne_inst_id);

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

  UPDATE public.tohumlama
  SET sonuc = 'Doğum Yaptı', dogum_tarihi = p_tarih, buzagi_kupe = p_kupe
  WHERE hayvan_id = p_anne_id AND sonuc = 'Gebe';
  GET DIAGNOSTICS v_sayac = ROW_COUNT;

  UPDATE public.gorev_log SET iptal = true
  WHERE hayvan_id = p_anne_id AND gorev_tipi = 'BESLEME' AND tamamlandi = false AND iptal = false;

  UPDATE public.protokol_instance SET durum = 'iptal', kapandi_at = now(), kapandi_sebep = 'DOGUM'
  WHERE hayvan_id = p_anne_id AND alttip = 'BESLEME' AND durum = 'aktif';

  RETURN jsonb_build_object(
    'ok', true, 'buzagi_id', v_buzagi_id, 'dogum_id', v_dogum_id,
    'gorev_sayisi', 17, 'anne_inst_id', v_anne_inst_id,
    'buzagi_inst_id', v_buzagi_inst_id, 'tohumlama_kapatildi', v_sayac
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
GRANT EXECUTE ON FUNCTION public.dogum_kaydet(text,date,text,text,text,numeric,text,text) TO anon, authenticated;

-- 6. tohumlama_kaydet (protokol_instance_id entegrasyonu)
CREATE OR REPLACE FUNCTION public.fn_gebe_gorev_yarat()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_stok_id text;
  v_kaynak  text;
  v_inst_id uuid;
BEGIN
  IF NEW.sonuc != 'Gebe' OR OLD.sonuc = 'Gebe' THEN RETURN NEW; END IF;
  SELECT stock_item_id INTO v_stok_id FROM vaccines WHERE name ILIKE '%Rota%' LIMIT 1;
  v_kaynak := 'ILERI_GEBE-' || NEW.hayvan_id;

  INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
  VALUES (NEW.hayvan_id, 'UREME', 'GEBELIK', v_kaynak, NEW.tarih::date, 'aktif')
  ON CONFLICT (kaynak_ref) DO UPDATE SET durum = 'aktif', kapandi_at = NULL, kapandi_sebep = NULL
  RETURNING id INTO v_inst_id;
  IF v_inst_id IS NULL THEN
    SELECT id INTO v_inst_id FROM public.protokol_instance WHERE kaynak_ref = v_kaynak;
  END IF;

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, kaynak, etken_kod, protokol_instance_id)
  SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE_ASI',
         '💉 Rota-Corona Aşısı (1. doz)', NEW.tarih::date + 240, false, v_stok_id, 1, v_kaynak, 'ROTA', v_inst_id
  WHERE NOT EXISTS (SELECT 1 FROM public.gorev_log WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💉 Rota-Corona Aşısı (1. doz)' AND tamamlandi = false);

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod, protokol_instance_id)
  SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE',
         '💊 SC Ademin uygulaması', NEW.tarih::date + 260, false, v_kaynak, 'ADEMIN', v_inst_id
  WHERE NOT EXISTS (SELECT 1 FROM public.gorev_log WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💊 SC Ademin uygulaması' AND tamamlandi = false);

  INSERT INTO public.gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, etken_kod, protokol_instance_id)
  SELECT gen_random_uuid(), NEW.hayvan_id, 'ILERI_GEBE',
         '💊 IM E Vitamini uygulaması', NEW.tarih::date + 265, false, v_kaynak, 'E_VIT', v_inst_id
  WHERE NOT EXISTS (SELECT 1 FROM public.gorev_log WHERE hayvan_id = NEW.hayvan_id AND aciklama = '💊 IM E Vitamini uygulaması' AND tamamlandi = false);

  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_tohumlama_gebe_gorev ON tohumlama;
CREATE TRIGGER trg_tohumlama_gebe_gorev
  AFTER UPDATE ON tohumlama
  FOR EACH ROW EXECUTE FUNCTION public.fn_gebe_gorev_yarat();

-- 8. ileri_gebe_gorev_kontrol (protokol_instance_id entegrasyonu)
CREATE OR REPLACE FUNCTION public.ileri_gebe_gorev_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_toh         record;
  v_hayvan      record;
  v_gun         int;
  v_hedef       date;
  v_stok_id     text;
  v_kaynak      text;
  v_inst_id     uuid;
BEGIN
  SELECT v.stock_item_id INTO v_stok_id FROM vaccines v WHERE v.name ILIKE '%Rota%' LIMIT 1;

  FOR v_toh IN
    SELECT DISTINCT ON (t.hayvan_id) t.hayvan_id, t.tarih
    FROM tohumlama t
    JOIN hayvanlar h ON h.id = t.hayvan_id AND h.durum = 'Aktif'
    WHERE t.sonuc = 'Gebe'
    ORDER BY t.hayvan_id, t.tarih DESC
  LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_toh.hayvan_id;
    v_gun    := CURRENT_DATE - v_toh.tarih::date;
    v_kaynak := 'ILERI_GEBE-' || v_toh.hayvan_id;

    INSERT INTO public.protokol_instance (hayvan_id, tip, alttip, kaynak_ref, baslangic, durum)
    VALUES (v_toh.hayvan_id, 'UREME', 'GEBELIK', v_kaynak, v_toh.tarih::date, 'aktif')
    ON CONFLICT (kaynak_ref) DO NOTHING;
    SELECT id INTO v_inst_id FROM public.protokol_instance WHERE kaynak_ref = v_kaynak;

    IF v_gun >= 240 THEN
      v_hedef := v_toh.tarih::date + 240;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, kaynak, protokol_instance_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (1. doz)', v_hedef, false, v_stok_id, 1, v_kaynak, v_inst_id
      WHERE NOT EXISTS (SELECT 1 FROM gorev_log WHERE hayvan_id = v_toh.hayvan_id AND aciklama = '💉 Rota-Corona Aşısı (1. doz)');
      GET DIAGNOSTICS v_sayac = ROW_COUNT; v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    IF v_gun >= 261 AND v_hayvan.grup ILIKE '%Düve%' THEN
      v_hedef := v_toh.tarih::date + 261;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, kaynak, protokol_instance_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI',
             '💉 Rota-Corona Aşısı (2. doz — düve)', v_hedef, false, v_stok_id, 1, v_kaynak, v_inst_id
      WHERE NOT EXISTS (SELECT 1 FROM gorev_log WHERE hayvan_id = v_toh.hayvan_id AND aciklama = '💉 Rota-Corona Aşısı (2. doz — düve)');
      GET DIAGNOSTICS v_sayac = ROW_COUNT; v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    IF v_gun >= 260 THEN
      v_hedef := v_toh.tarih::date + 260;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, protokol_instance_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE', '💊 SC Ademin uygulaması', v_hedef, false, v_kaynak, v_inst_id
      WHERE NOT EXISTS (SELECT 1 FROM gorev_log WHERE hayvan_id = v_toh.hayvan_id AND aciklama = '💊 SC Ademin uygulaması');
      GET DIAGNOSTICS v_sayac = ROW_COUNT; v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    IF v_gun >= 265 THEN
      v_hedef := v_toh.tarih::date + 265;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, protokol_instance_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE', '💊 IM E Vitamini uygulaması', v_hedef, false, v_kaynak, v_inst_id
      WHERE NOT EXISTS (SELECT 1 FROM gorev_log WHERE hayvan_id = v_toh.hayvan_id AND aciklama = '💊 IM E Vitamini uygulaması');
      GET DIAGNOSTICS v_sayac = ROW_COUNT; v_olusturulan := v_olusturulan + v_sayac;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan);
END;
$$;
GRANT EXECUTE ON FUNCTION public.ileri_gebe_gorev_kontrol() TO anon, authenticated;

-- 9. gebelik_protokol_kontrol (eşikler protokol_ayar/_ayar config'inde; besleme = BESLEME_OTOMATIK)
-- NOT: besleme protokol_instance mantığı 20260613000001'de BESLEME_OTOMATIK'e geri alındı; canlı ile birebir.
CREATE OR REPLACE FUNCTION public.gebelik_protokol_kontrol()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_olusturulan int := 0;
  v_sayac       int := 0;
  v_toh         record;
  v_hayvan      record;
  v_gun         int;
  v_hedef       date;
  v_padok_kuru  text;
  v_stok_id     text;
  v_g_kuru   constant numeric := public._ayar('kuru_donem_gun', 210);
  v_g_asi1   constant numeric := public._ayar('ileri_gebe_asi1_gun', 240);
  v_g_asi2   constant numeric := public._ayar('ileri_gebe_asi2_gun', 261);
  v_g_ademin constant numeric := public._ayar('ileri_gebe_ademin_gun', 260);
  v_g_evit   constant numeric := public._ayar('ileri_gebe_evit_gun', 265);
  v_g_besle  constant numeric := public._ayar('besleme_baslangic_gun', 260);
BEGIN
  SELECT v.stock_item_id INTO v_stok_id FROM vaccines v WHERE v.name ILIKE '%Rota%' LIMIT 1;
  SELECT ad INTO v_padok_kuru FROM padoklar WHERE ad ILIKE '%Kuru%' LIMIT 1;

  FOR v_toh IN
    SELECT DISTINCT ON (t.hayvan_id) t.hayvan_id, t.tarih, t.id
    FROM tohumlama t JOIN hayvanlar h ON h.id = t.hayvan_id AND h.durum = 'Aktif'
    WHERE t.sonuc = 'Gebe'
    ORDER BY t.hayvan_id, t.tarih DESC
  LOOP
    SELECT * INTO v_hayvan FROM hayvanlar WHERE id = v_toh.hayvan_id;
    v_gun := CURRENT_DATE - v_toh.tarih::date;

    IF v_gun >= v_g_kuru AND v_hayvan.grup ILIKE '%Sağmal%' AND v_hayvan.grup NOT ILIKE '%Kuru%' THEN
      v_hedef := v_toh.tarih::date + v_g_kuru::int;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, padok_hedef, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'PADOK_DEGISIM',
             '⚠️ Kuru döneme geçiş zamanı (' || v_gun || '. gün gebelik) — Kuru/Gebe padoğuna transfer',
             v_hedef, false, v_padok_kuru, v_toh.id::text
      WHERE NOT EXISTS (
        SELECT 1 FROM gorev_log WHERE hayvan_id = v_toh.hayvan_id AND gorev_tipi = 'PADOK_DEGISIM'
          AND aciklama ILIKE '%Kuru döneme%' AND iptal = false
          AND (NOT tamamlandi OR tamamlanma_tarihi > now() - interval '24 hours')
      );
      GET DIAGNOSTICS v_sayac = ROW_COUNT; v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    IF v_gun >= v_g_asi1 THEN
      v_hedef := v_toh.tarih::date + v_g_asi1::int;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI', '💉 Rota-Corona Aşısı (1. doz)', v_hedef, false, v_stok_id, 1, v_toh.id::text
      WHERE NOT EXISTS (SELECT 1 FROM gorev_log WHERE hayvan_id = v_toh.hayvan_id AND aciklama = '💉 Rota-Corona Aşısı (1. doz)' AND iptal = false);
      GET DIAGNOSTICS v_sayac = ROW_COUNT; v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    IF v_gun >= v_g_asi2 AND v_hayvan.grup ILIKE '%Düve%' THEN
      v_hedef := v_toh.tarih::date + v_g_asi2::int;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, stok_id, miktar, ref_tohumlama_id, etken_kod)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE_ASI', '💉 Rota-Corona Aşısı (2. doz — düve)', v_hedef, false, v_stok_id, 1, v_toh.id::text, 'ROTA_2DOZ'
      WHERE NOT EXISTS (SELECT 1 FROM gorev_log WHERE hayvan_id = v_toh.hayvan_id AND etken_kod = 'ROTA_2DOZ' AND iptal = false);
      GET DIAGNOSTICS v_sayac = ROW_COUNT; v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    IF v_gun >= v_g_ademin THEN
      v_hedef := v_toh.tarih::date + v_g_ademin::int;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE', '💊 SC Ademin uygulaması', v_hedef, false, v_toh.id::text
      WHERE NOT EXISTS (SELECT 1 FROM gorev_log WHERE hayvan_id = v_toh.hayvan_id AND aciklama = '💊 SC Ademin uygulaması' AND iptal = false);
      GET DIAGNOSTICS v_sayac = ROW_COUNT; v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    IF v_gun >= v_g_evit THEN
      v_hedef := v_toh.tarih::date + v_g_evit::int;
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'ILERI_GEBE', '💊 IM E Vitamini uygulaması', v_hedef, false, v_toh.id::text
      WHERE NOT EXISTS (SELECT 1 FROM gorev_log WHERE hayvan_id = v_toh.hayvan_id AND aciklama = '💊 IM E Vitamini uygulaması' AND iptal = false);
      GET DIAGNOSTICS v_sayac = ROW_COUNT; v_olusturulan := v_olusturulan + v_sayac;
    END IF;

    IF v_gun >= v_g_besle THEN
      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'BESLEME', '🌅 Anyonik Besleme (Sabah)', CURRENT_DATE, false, 'BESLEME_OTOMATIK', v_toh.id::text
      WHERE NOT EXISTS (SELECT 1 FROM gorev_log WHERE hayvan_id = v_toh.hayvan_id AND gorev_tipi = 'BESLEME' AND aciklama = '🌅 Anyonik Besleme (Sabah)' AND hedef_tarih = CURRENT_DATE AND iptal = false);
      GET DIAGNOSTICS v_sayac = ROW_COUNT; v_olusturulan := v_olusturulan + v_sayac;

      INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, ref_tohumlama_id)
      SELECT gen_random_uuid(), v_toh.hayvan_id, 'BESLEME', '🌙 Anyonik Besleme (Akşam)', CURRENT_DATE, false, 'BESLEME_OTOMATIK', v_toh.id::text
      WHERE NOT EXISTS (SELECT 1 FROM gorev_log WHERE hayvan_id = v_toh.hayvan_id AND gorev_tipi = 'BESLEME' AND aciklama = '🌙 Anyonik Besleme (Akşam)' AND hedef_tarih = CURRENT_DATE AND iptal = false);
      GET DIAGNOSTICS v_sayac = ROW_COUNT; v_olusturulan := v_olusturulan + v_sayac;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('ok', true, 'olusturulan', v_olusturulan,
    'hayvanlar', (
      SELECT jsonb_agg(jsonb_build_object('hayvan_id', t.hayvan_id, 'tarih', t.tarih::text,
        'gebelik_gun', CURRENT_DATE - t.tarih::date, 'kupe_no', h.kupe_no,
        'devlet_kupe', h.devlet_kupe, 'grup', h.grup, 'padok', h.padok)
        ORDER BY CURRENT_DATE - t.tarih::date DESC)
      FROM tohumlama t JOIN hayvanlar h ON h.id = t.hayvan_id
      WHERE t.sonuc = 'Gebe' AND h.durum = 'Aktif' AND CURRENT_DATE - t.tarih::date >= v_g_kuru
        AND t.tarih = (SELECT MAX(t2.tarih) FROM tohumlama t2 WHERE t2.hayvan_id = t.hayvan_id AND t2.sonuc = 'Gebe')
    )
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.gebelik_protokol_kontrol() TO anon, authenticated;

-- 10. besleme_tamam (protokol_instance_id zincirleme)
CREATE OR REPLACE FUNCTION public.besleme_tamam(p_gorev_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_gorev gorev_log%ROWTYPE;
  v_yeni_id uuid;
BEGIN
  SELECT * INTO v_gorev FROM gorev_log WHERE id = p_gorev_id::uuid;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev bulunamadı'); END IF;
  IF v_gorev.tamamlandi OR v_gorev.iptal THEN RETURN jsonb_build_object('ok', false, 'mesaj', 'Görev zaten kapalı'); END IF;

  UPDATE gorev_log SET tamamlandi = true, tamamlanma_tarihi = now() WHERE id = p_gorev_id::uuid;

  IF NOT EXISTS (SELECT 1 FROM tohumlama WHERE hayvan_id = v_gorev.hayvan_id AND sonuc = 'Gebe') THEN
    RETURN jsonb_build_object('ok', true, 'zincir', 'hayvan_artik_gebe_degil');
  END IF;

  v_yeni_id := gen_random_uuid();
  INSERT INTO gorev_log (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, kaynak, parent_id, protokol_instance_id)
  SELECT v_yeni_id, v_gorev.hayvan_id, 'BESLEME', v_gorev.aciklama, v_gorev.hedef_tarih + 1,
         false, COALESCE(v_gorev.kaynak, 'BESLEME-' || v_gorev.hayvan_id), v_gorev.id, v_gorev.protokol_instance_id
  WHERE NOT EXISTS (
    SELECT 1 FROM gorev_log WHERE hayvan_id = v_gorev.hayvan_id AND aciklama = v_gorev.aciklama
      AND hedef_tarih = v_gorev.hedef_tarih + 1 AND iptal = false
  );

  RETURN jsonb_build_object('ok', true, 'yeni_gorev_id', v_yeni_id, 'tarih', v_gorev.hedef_tarih + 1);
END;
$$;
GRANT EXECUTE ON FUNCTION public.besleme_tamam(text) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';


-- ════════════════════════════════════════════════════════════════
-- 2 DOĞRU TANIM (REGEN 2026-06-13)
-- ════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.gorev_log_cycle_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
  IF NEW.ref_tohumlama_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.tohumlama
      WHERE id::text = NEW.ref_tohumlama_id
        AND sonuc IN ('Bekliyor', 'Gebe')
    ) THEN
      NEW.iptal := true;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.stale_tohumlama_gorev_temizle()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_iptal_sayisi integer;
BEGIN
  UPDATE public.gorev_log
  SET iptal = true
  WHERE tamamlandi = false
    AND iptal = false
    AND gorev_tipi = 'TOHUMLAMA_HAZIRLIK'
    AND hedef_tarih < (
      SELECT MAX(t.tarih) + INTERVAL '20 days'
      FROM public.tohumlama t
      WHERE t.hayvan_id = gorev_log.hayvan_id
    );

  GET DIAGNOSTICS v_iptal_sayisi = ROW_COUNT;
  RETURN jsonb_build_object('iptal_edilen', v_iptal_sayisi, 'zaman', now());
END;
$function$;

CREATE OR REPLACE FUNCTION public.tohumlama_tekrar_kaydet(p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text DEFAULT NULL::text, p_irk_bilgisi text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_hayvan   record;
  v_toh      record;
  v_eski     jsonb;
  v_yeni_denemeler jsonb;
BEGIN
  SELECT * INTO v_hayvan
  FROM public.hayvanlar
  WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id;
  END IF;

  IF p_tarih > CURRENT_DATE THEN
    RAISE EXCEPTION 'Tarih ileri olamaz';
  END IF;

  SELECT * INTO v_toh
  FROM public.tohumlama
  WHERE hayvan_id = p_hayvan_id
    AND sonuc = 'Bekliyor'
    AND tarih >= CURRENT_DATE - INTERVAL '15 days'
  ORDER BY tarih DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Son 15 gün içinde Bekliyor tohumlama bulunamadı';
  END IF;

  v_eski := jsonb_build_object(
    'no',       v_toh.deneme_sayisi,
    'tarih',    v_toh.tarih,
    'sperma',   v_toh.sperma,
    'hekim_id', v_toh.hekim_id
  );
  v_yeni_denemeler := v_toh.denemeler || jsonb_build_array(v_eski);

  UPDATE public.tohumlama
  SET tarih         = p_tarih,
      sperma        = p_sperma,
      hekim_id      = COALESCE(p_hekim_id, hekim_id),
      irk_bilgisi   = COALESCE(p_irk_bilgisi, irk_bilgisi),
      deneme_sayisi = deneme_sayisi + 1,
      denemeler     = v_yeni_denemeler
  WHERE id = v_toh.id;

  UPDATE public.gorev_log
  SET iptal = true
  WHERE hayvan_id = p_hayvan_id
    AND tamamlandi = false
    AND iptal = false
    AND gorev_tipi IN ('TOHUMLAMA_HAZIRLIK', 'GEBELIK_KONTROL');

  INSERT INTO public.gorev_log
    (id, hayvan_id, gorev_tipi, aciklama, hedef_tarih, tamamlandi, ref_tohumlama_id)
  VALUES
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '21. Gün gebelik kontrolü', p_tarih + 21, false, v_toh.id::text),
    (gen_random_uuid(), p_hayvan_id, 'GEBELIK_KONTROL',
     '35. Gün gebelik kontrolü', p_tarih + 35, false, v_toh.id::text);

  INSERT INTO public.stok_hareket (stok_id, tur, miktar, notlar, iptal)
  SELECT
    s.id, 'Tohumlama', 1,
    'Tekrar Aşım ' || (v_toh.deneme_sayisi + 1) || '. deneme — ' ||
      COALESCE(v_hayvan.kupe_no, p_hayvan_id),
    false
  FROM public.stok s
  WHERE (s.urun_adi ILIKE '%' || p_sperma || '%' OR s.urun_adi = p_sperma)
    AND s.kategori = 'Sperma'
  LIMIT 1;

  RETURN jsonb_build_object(
    'ok',           true,
    'tohumlama_id', v_toh.id,
    'deneme_sayisi', v_toh.deneme_sayisi + 1
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.test_migrate_working()
 RETURNS text
 LANGUAGE plpgsql
AS $function$BEGIN RETURN 'ok'; END;$function$;

CREATE OR REPLACE FUNCTION public.cikis_yap(p_hayvan_id text, p_cikis_tipi text, p_cikis_tarihi date DEFAULT ((now() AT TIME ZONE 'Europe/Istanbul'::text))::date, p_cikis_sebebi text DEFAULT NULL::text, p_satis_fiyati numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_durum_yeni      text;
  v_iptal_gorev_say integer;
  v_iptal_inst_say  integer;
BEGIN
  IF p_cikis_tipi = 'olum' THEN
    v_durum_yeni := 'Ölü';
  ELSIF p_cikis_tipi = 'satis' THEN
    v_durum_yeni := 'Satıldı';
  ELSE
    RAISE EXCEPTION 'Geçersiz çıkış tipi: % (beklenen: olum veya satis)', p_cikis_tipi;
  END IF;

  UPDATE public.hayvanlar
  SET durum        = v_durum_yeni,
      cikis_tipi   = p_cikis_tipi,
      cikis_tarihi = p_cikis_tarihi,
      cikis_sebebi = p_cikis_sebebi,
      satis_fiyati = CASE WHEN p_cikis_tipi = 'satis' THEN p_satis_fiyati ELSE satis_fiyati END
  WHERE id = p_hayvan_id AND durum = 'Aktif';

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'mesaj', 'Aktif hayvan bulunamadı: ' || p_hayvan_id);
  END IF;

  UPDATE public.gorev_log
  SET iptal = true
  WHERE hayvan_id = p_hayvan_id
    AND tamamlandi = false
    AND iptal = false;

  GET DIAGNOSTICS v_iptal_gorev_say = ROW_COUNT;

  UPDATE public.protokol_instance
  SET durum = 'iptal',
      kapandi_at = now(),
      kapandi_sebep = upper(p_cikis_tipi)
  WHERE hayvan_id = p_hayvan_id
    AND durum = 'aktif';

  GET DIAGNOSTICS v_iptal_inst_say = ROW_COUNT;

  RETURN jsonb_build_object(
    'ok',              true,
    'hayvan_id',       p_hayvan_id,
    'durum',           v_durum_yeni,
    'iptal_gorev',     v_iptal_gorev_say,
    'iptal_protokol',  v_iptal_inst_say
  );
END;
$function$;


CREATE OR REPLACE FUNCTION public.tohumlama_kaydet(p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text, p_irk_bilgisi text, p_ek_uygulamalar jsonb DEFAULT '[]'::jsonb, p_vwp_override boolean DEFAULT NULL::boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_id text;
  v_hayvan record;
  v_result jsonb;
  v_deneme integer;
BEGIN
  v_id := gen_random_uuid()::text;

  SELECT * INTO v_hayvan FROM public.hayvanlar WHERE id = p_hayvan_id AND durum = 'Aktif';
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'Aktif hayvan bulunamadı: ' || p_hayvan_id);
  END IF;

  IF p_tarih > CURRENT_DATE THEN
    RETURN jsonb_build_object('ok', false, 'hata', 'İleri tarihli tohumlama kaydedilemez');
  END IF;

  SELECT COALESCE(MAX(deneme_no), 0) + 1 INTO v_deneme
  FROM public.tohumlama WHERE hayvan_id = p_hayvan_id;

  INSERT INTO public.tohumlama (id, hayvan_id, tarih, sperma, hekim_id, irk_bilgisi, sonuc, deneme_no)
  VALUES (v_id, p_hayvan_id, p_tarih, p_sperma, p_hekim_id, p_irk_bilgisi, 'Bekliyor', v_deneme)
  RETURNING to_jsonb(tohumlama.*) INTO v_result;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'data', v_result);
END;
$function$;


NOTIFY pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════
-- SÜTTEN KESME PROTOKOL ENTEGRASYONU (2026-06-20)
-- protokol_ayar config + _ayar + guncelle + listener trigger'lar + toplu/geri_al
-- ════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.protokol_ayar (
  anahtar     text PRIMARY KEY,
  deger       numeric NOT NULL,
  birim       text DEFAULT 'gün',
  min_deger   numeric,
  max_deger   numeric,
  aciklama    text,
  guncellendi timestamptz DEFAULT now()
);
ALTER TABLE public.protokol_ayar ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS protokol_ayar_all ON public.protokol_ayar;
CREATE POLICY protokol_ayar_all ON public.protokol_ayar FOR ALL USING (true) WITH CHECK (true);

INSERT INTO public.protokol_ayar(anahtar, deger, min_deger, max_deger, aciklama) VALUES
  ('sutten_kesme_gun',          60, 20, 200, 'Otomatik sütten kesme alarmı eşiği (gün)'),
  ('sutten_kesme_gecikme_gun',  75, 30, 250, 'Bu günden sonra görev "GECİKMİŞ" vurgulanır'),
  ('sutten_kesme_erken_uyari',  40, 0,  120, 'SERT ALT SINIR: kesim yaşı bu günün altında ise DB reddeder'),
  ('besleme_baslangic_gun',    260, 200, 285, 'Anyonik besleme başlangıcı (gebelik günü)'),
  ('kuru_donem_gun',           210, 180, 285, 'Kuru döneme transfer (gebelik günü)'),
  ('ileri_gebe_asi1_gun',      240, 200, 285, 'Rota-Corona 1. doz (gebelik günü)'),
  ('ileri_gebe_asi2_gun',      261, 200, 285, 'Rota-Corona 2. doz düve (gebelik günü)'),
  ('ileri_gebe_ademin_gun',    260, 200, 285, 'SC Ademin (gebelik günü)'),
  ('ileri_gebe_evit_gun',      265, 200, 285, 'IM E Vitamini (gebelik günü)')
ON CONFLICT (anahtar) DO NOTHING;

CREATE OR REPLACE FUNCTION public._ayar(p_anahtar text, p_varsayilan numeric)
RETURNS numeric LANGUAGE sql STABLE AS $$
  SELECT COALESCE((SELECT deger FROM public.protokol_ayar WHERE anahtar = p_anahtar), p_varsayilan);
$$;

CREATE OR REPLACE FUNCTION public.protokol_ayar_guncelle(p_anahtar text, p_deger numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_row record;
BEGIN
  SELECT * INTO v_row FROM public.protokol_ayar WHERE anahtar = p_anahtar;
  IF NOT FOUND THEN RAISE EXCEPTION 'Bilinmeyen ayar: %', p_anahtar; END IF;
  IF v_row.min_deger IS NOT NULL AND p_deger < v_row.min_deger THEN
    RAISE EXCEPTION 'Değer çok küçük: % (min %)', p_deger, v_row.min_deger; END IF;
  IF v_row.max_deger IS NOT NULL AND p_deger > v_row.max_deger THEN
    RAISE EXCEPTION 'Değer çok büyük: % (max %)', p_deger, v_row.max_deger; END IF;
  UPDATE public.protokol_ayar SET deger = p_deger, guncellendi = now() WHERE anahtar = p_anahtar;
  INSERT INTO public.islem_log (tip, ref_tablo, snapshot, kullanici_notu)
  VALUES ('PROTOKOL_AYAR', 'protokol_ayar',
    jsonb_build_object('olusturulan','[]'::jsonb,'silinen','[]'::jsonb,
      'guncellenen', jsonb_build_array(jsonb_build_object(
        'tablo','protokol_ayar','id',p_anahtar,
        'onceki', jsonb_build_object('deger', v_row.deger),
        'sonraki', jsonb_build_object('deger', p_deger)))),
    'Protokol ayarı: ' || p_anahtar);
  RETURN jsonb_build_object('ok', true, 'anahtar', p_anahtar, 'deger', p_deger);
END; $$;
GRANT EXECUTE ON FUNCTION public._ayar(text, numeric) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.protokol_ayar_guncelle(text, numeric) TO anon, authenticated;

-- BEFORE: kesim sinyali → atomik senkron (tarih+grup+padok) + 40g sert alt sınır
CREATE OR REPLACE FUNCTION public.trg_sutten_kesme_normalize()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  v_wgrup constant text := 'Sütten Kesilmiş Buzağı';
  v_wpadok record;
  v_signal boolean := false;
  v_kesim_tarihi date;
  v_min numeric;
BEGIN
  IF (NEW.suttten_kesme_tarihi IS NOT NULL AND OLD.suttten_kesme_tarihi IS NULL)
     OR (NEW.grup = v_wgrup AND OLD.grup IS DISTINCT FROM v_wgrup) THEN
    v_signal := true;
  END IF;
  IF NOT v_signal AND NEW.padok IS DISTINCT FROM OLD.padok THEN
    SELECT * INTO v_wpadok FROM public.padoklar WHERE ad ILIKE '%Sütten Kesilmiş%' ORDER BY id LIMIT 1;
    IF FOUND AND NEW.padok = v_wpadok.ad THEN v_signal := true; END IF;
  END IF;

  IF v_signal THEN
    v_kesim_tarihi := COALESCE(NEW.suttten_kesme_tarihi, CURRENT_DATE);
    IF NEW.dogum_tarihi IS NULL THEN
      RAISE EXCEPTION 'Sütten kesim için doğum tarihi gerekli (hayvan %)', NEW.id;
    END IF;
    v_min := public._ayar('sutten_kesme_erken_uyari', 40);
    IF (v_kesim_tarihi - NEW.dogum_tarihi) < v_min THEN
      RAISE EXCEPTION 'Çok erken sütten kesim: % gün (min %)', (v_kesim_tarihi - NEW.dogum_tarihi), v_min;
    END IF;
    SELECT * INTO v_wpadok FROM public.padoklar WHERE ad ILIKE '%Sütten Kesilmiş%' ORDER BY id LIMIT 1;
    NEW.suttten_kesme_tarihi := v_kesim_tarihi;
    NEW.grup := v_wgrup;
    IF FOUND THEN
      NEW.padok := v_wpadok.ad;
      NEW.padok_id := v_wpadok.id;
    ELSE
      RAISE WARNING 'weaned padok bulunamadı (Sütten Kesilmiş) — padok güncellenmedi';
    END IF;
  END IF;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_sutten_kesme_normalize ON public.hayvanlar;
CREATE TRIGGER trg_sutten_kesme_normalize
  BEFORE UPDATE ON public.hayvanlar
  FOR EACH ROW EXECUTE FUNCTION public.trg_sutten_kesme_normalize();

-- AFTER: protokol_instance + gorev_log lifecycle (kapat / undo'da aç)
CREATE OR REPLACE FUNCTION public.trg_sutten_kesme_kapat()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.suttten_kesme_tarihi IS NULL AND NEW.suttten_kesme_tarihi IS NOT NULL THEN
    UPDATE public.gorev_log
       SET tamamlandi=true, tamamlanma_tarihi=now(), kapatan_ref='trg-sutten-kes'
     WHERE hayvan_id=NEW.id AND gorev_tipi='SUTTEN_KESME' AND tamamlandi=false AND iptal=false;
    UPDATE public.protokol_instance
       SET durum='tamamlandi', kapandi_at=now(), kapandi_sebep='TAMAMLANDI'
     WHERE kaynak_ref='SUTTENKES-'||NEW.id AND durum='aktif';
  ELSIF OLD.suttten_kesme_tarihi IS NOT NULL AND NEW.suttten_kesme_tarihi IS NULL THEN
    UPDATE public.protokol_instance
       SET durum='aktif', kapandi_at=NULL, kapandi_sebep=NULL
     WHERE kaynak_ref='SUTTENKES-'||NEW.id AND durum='tamamlandi';
    UPDATE public.gorev_log
       SET tamamlandi=false, tamamlanma_tarihi=NULL
     WHERE hayvan_id=NEW.id AND gorev_tipi='SUTTEN_KESME' AND kapatan_ref='trg-sutten-kes';
  END IF;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_sutten_kesme_kapat ON public.hayvanlar;
CREATE TRIGGER trg_sutten_kesme_kapat
  AFTER UPDATE ON public.hayvanlar
  FOR EACH ROW EXECUTE FUNCTION public.trg_sutten_kesme_kapat();

CREATE OR REPLACE FUNCTION public.buzagi_sutten_kesme_toplu(
  p_hayvan_idler text[],
  p_tarih date DEFAULT CURRENT_DATE
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id text;
  v_basari int := 0;
  v_hatalar jsonb := '[]'::jsonb;
BEGIN
  IF p_hayvan_idler IS NULL OR array_length(p_hayvan_idler,1) IS NULL THEN
    RETURN jsonb_build_object('ok',false,'hata','Hayvan listesi boş','basari',0,'hata_sayisi',0,'hatalar','[]'::jsonb);
  END IF;
  IF array_length(p_hayvan_idler,1) > 200 THEN
    RETURN jsonb_build_object('ok',false,'hata','Çok fazla hayvan (limit 200)','basari',0,'hata_sayisi',0,'hatalar','[]'::jsonb);
  END IF;
  FOREACH v_id IN ARRAY p_hayvan_idler LOOP
    BEGIN
      PERFORM public.buzagi_sutten_kesme_onayla(v_id, p_tarih);
      v_basari := v_basari + 1;
    EXCEPTION WHEN OTHERS THEN
      v_hatalar := v_hatalar || jsonb_build_array(jsonb_build_object('hayvan_id',v_id,'hata',SQLERRM,'kod',SQLSTATE));
    END;
  END LOOP;
  RETURN jsonb_build_object('ok',true,'basari',v_basari,
    'hata_sayisi',jsonb_array_length(v_hatalar),'hatalar',v_hatalar,
    'toplam',v_basari+jsonb_array_length(v_hatalar));
END; $$;

CREATE OR REPLACE FUNCTION public.buzagi_sutten_kesme_geri_al(p_hayvan_id text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_log record; v_onceki jsonb; v_h record;
BEGIN
  -- geri alma koşulları (FE ile birebir): buzağı grubu + ≤15 gün + (dogum yok VEYA yaş≤180) + tohumlama yok
  SELECT * INTO v_h FROM public.hayvanlar WHERE id = p_hayvan_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Hayvan bulunamadı: %', p_hayvan_id; END IF;
  IF v_h.suttten_kesme_tarihi IS NULL THEN
    RAISE EXCEPTION 'Hayvan sütten kesilmemiş'; END IF;
  IF v_h.grup IS NULL OR v_h.grup NOT ILIKE '%Buzağı%' THEN
    RAISE EXCEPTION 'Sadece buzağı grubunda geri alınabilir (grup: %)', v_h.grup; END IF;
  IF (CURRENT_DATE - v_h.suttten_kesme_tarihi) > 15 THEN
    RAISE EXCEPTION 'Kesimden 15 günden fazla geçti (% gün) — geri alınamaz', (CURRENT_DATE - v_h.suttten_kesme_tarihi); END IF;
  IF v_h.dogum_tarihi IS NOT NULL AND (CURRENT_DATE - v_h.dogum_tarihi) > 180 THEN
    RAISE EXCEPTION '6 aylıktan büyük (% gün) — geri alınamaz', (CURRENT_DATE - v_h.dogum_tarihi); END IF;
  IF EXISTS (SELECT 1 FROM public.tohumlama WHERE hayvan_id = p_hayvan_id) THEN
    RAISE EXCEPTION 'Tohumlama kaydı olan hayvanda geri alınamaz'; END IF;

  SELECT * INTO v_log FROM public.islem_log
   WHERE tip='SUTEN_KESME' AND ana_hayvan_id=p_hayvan_id AND durum='aktif'
   ORDER BY tarih DESC LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'Sütten kesim kaydı bulunamadı: %', p_hayvan_id; END IF;
  v_onceki := v_log.snapshot->'guncellenen'->0->'onceki';
  UPDATE public.hayvanlar
     SET suttten_kesme_tarihi = NULL,
         grup     = COALESCE(v_onceki->>'grup', grup),
         padok    = COALESCE(v_onceki->>'padok', padok),
         padok_id = COALESCE((v_onceki->>'padok_id')::uuid, padok_id)
   WHERE id = p_hayvan_id;
  UPDATE public.islem_log SET durum='geri_alindi', geri_alma_tarihi=now() WHERE id=v_log.id;
  INSERT INTO public.islem_log (tip, ana_hayvan_id, ref_id, ref_tablo, snapshot, kullanici_notu)
  VALUES ('SUTTEN_KESME_GERI_AL', p_hayvan_id, p_hayvan_id, 'hayvanlar',
    jsonb_build_object('olusturulan','[]'::jsonb,'silinen','[]'::jsonb,
      'guncellenen', jsonb_build_array(jsonb_build_object('tablo','hayvanlar','id',p_hayvan_id,'geri_alinan_log',v_log.id))),
    'Sütten kesim geri alındı');
  RETURN jsonb_build_object('ok', true, 'hayvan_id', p_hayvan_id);
END; $$;
GRANT EXECUTE ON FUNCTION public.buzagi_sutten_kesme_toplu(text[], date) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.buzagi_sutten_kesme_geri_al(text) TO anon, authenticated;

-- ════════════════════════════════════════════════════════════
-- AUTH GATE LOCKDOWN (Faz 1, 2026-06-14) — bu blok dosya sonunda
-- KALMALI. Yukarıdaki tüm GRANT ... TO anon satırlarını override eder.
-- Fonksiyonlar EXECUTE'u PUBLIC'e default verir → PUBLIC'ten de revoke şart.
-- ════════════════════════════════════════════════════════════
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES    FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES    FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM PUBLIC;
-- ── gorev_log yaşam döngüsü (2026-06-26) — append ──

-- VIEW: v_gorev_log_sync
CREATE OR REPLACE VIEW public.v_gorev_log_sync AS
 SELECT gorev_log.id,
    gorev_log.hayvan_id,
    gorev_log.gorev_tipi,
    gorev_log.aciklama,
    gorev_log.hedef_tarih,
    gorev_log.tamamlandi,
    gorev_log.tamamlanma_tarihi,
    gorev_log.padok_hedef,
    gorev_log.stok_id,
    gorev_log.miktar,
    gorev_log.stok_dusuldu,
    gorev_log.kaynak,
    gorev_log.created_at,
    gorev_log.parent_id,
    gorev_log.iptal,
    gorev_log.hekim_id,
    gorev_log.ref_tohumlama_id,
    gorev_log.etken_kod,
    gorev_log.kapatan_ref,
    gorev_log.protokol_instance_id,
    gorev_log.seans_admin_id,
    gorev_log.hedef_saat
   FROM gorev_log
  WHERE NOT gorev_log.tamamlandi AND NOT gorev_log.iptal
UNION ALL
 SELECT kapali.id,
    kapali.hayvan_id,
    kapali.gorev_tipi,
    kapali.aciklama,
    kapali.hedef_tarih,
    kapali.tamamlandi,
    kapali.tamamlanma_tarihi,
    kapali.padok_hedef,
    kapali.stok_id,
    kapali.miktar,
    kapali.stok_dusuldu,
    kapali.kaynak,
    kapali.created_at,
    kapali.parent_id,
    kapali.iptal,
    kapali.hekim_id,
    kapali.ref_tohumlama_id,
    kapali.etken_kod,
    kapali.kapatan_ref,
    kapali.protokol_instance_id,
    kapali.seans_admin_id,
    kapali.hedef_saat
   FROM ( SELECT gorev_log.id,
            gorev_log.hayvan_id,
            gorev_log.gorev_tipi,
            gorev_log.aciklama,
            gorev_log.hedef_tarih,
            gorev_log.tamamlandi,
            gorev_log.tamamlanma_tarihi,
            gorev_log.padok_hedef,
            gorev_log.stok_id,
            gorev_log.miktar,
            gorev_log.stok_dusuldu,
            gorev_log.kaynak,
            gorev_log.created_at,
            gorev_log.parent_id,
            gorev_log.iptal,
            gorev_log.hekim_id,
            gorev_log.ref_tohumlama_id,
            gorev_log.etken_kod,
            gorev_log.kapatan_ref,
            gorev_log.protokol_instance_id,
            gorev_log.seans_admin_id,
            gorev_log.hedef_saat
           FROM gorev_log
          WHERE gorev_log.tamamlandi OR gorev_log.iptal
          ORDER BY gorev_log.created_at DESC NULLS LAST
         LIMIT 300) kapali;
;

-- VIEW: v_orphan_gorev
CREATE OR REPLACE VIEW public.v_orphan_gorev AS
 SELECT id,
    hayvan_id,
    gorev_tipi,
    aciklama,
    hedef_tarih,
    tamamlandi,
    tamamlanma_tarihi,
    padok_hedef,
    stok_id,
    miktar,
    stok_dusuldu,
    kaynak,
    created_at,
    parent_id,
    iptal,
    hekim_id,
    ref_tohumlama_id,
    etken_kod,
    kapatan_ref,
    protokol_instance_id,
    seans_admin_id,
    hedef_saat
   FROM gorev_log g
  WHERE NOT tamamlandi AND NOT iptal AND (NOT (EXISTS ( SELECT 1
           FROM hayvanlar h
          WHERE h.id = g.hayvan_id AND h.durum = 'Aktif'::text)) OR parent_id IS NOT NULL AND (gorev_tipi <> ALL (ARRAY['BESLEME'::text, 'BUZAGI_BAKIM'::text, 'TEDAVI_GUN'::text, 'ILERI_GEBE_ASI'::text])) AND NOT (EXISTS ( SELECT 1
           FROM gorev_log p
          WHERE p.id = g.parent_id)) OR parent_id IS NOT NULL AND (EXISTS ( SELECT 1
           FROM gorev_log p
          WHERE p.id = g.parent_id AND (p.tamamlandi OR p.iptal) AND p.gorev_tipi <> g.gorev_tipi)));
;

-- FUNCTION: _trg_gorev_parent_kapandi
CREATE OR REPLACE FUNCTION public._trg_gorev_parent_kapandi()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF TG_OP = 'DELETE' THEN
    UPDATE public.gorev_log
       SET iptal = true, kapatan_ref = 'parent-silindi'
     WHERE parent_id = OLD.id AND NOT tamamlandi AND NOT iptal
       AND gorev_tipi NOT IN ('BESLEME','BUZAGI_BAKIM','TEDAVI_GUN','ILERI_GEBE_ASI');
    RETURN OLD;
  END IF;
  IF (NEW.tamamlandi OR NEW.iptal) AND NOT (OLD.tamamlandi OR OLD.iptal) THEN
    UPDATE public.gorev_log c
       SET iptal = true, kapatan_ref = 'parent-kapandi'
     WHERE c.parent_id = NEW.id AND NOT c.tamamlandi AND NOT c.iptal
       AND c.gorev_tipi <> NEW.gorev_tipi;
  END IF;
  RETURN NEW;
END;
$function$
;

-- FUNCTION: _trg_hayvan_cikis_gorev_iptal
CREATE OR REPLACE FUNCTION public._trg_hayvan_cikis_gorev_iptal()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.durum <> 'Aktif' AND OLD.durum = 'Aktif' THEN
    UPDATE public.gorev_log
       SET iptal = true, kapatan_ref = 'hayvan-cikis'
     WHERE hayvan_id = NEW.id
       AND NOT tamamlandi AND NOT iptal;
  END IF;
  RETURN NEW;
END;
$function$
;

-- FUNCTION: gorev_orphan_temizle
CREATE OR REPLACE FUNCTION public.gorev_orphan_temizle()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_temizlenen int;
BEGIN
  UPDATE public.gorev_log g
     SET iptal = true, kapatan_ref = 'orphan-temizle'
   WHERE g.id IN (SELECT id FROM public.v_orphan_gorev);
  GET DIAGNOSTICS v_temizlenen = ROW_COUNT;

  IF v_temizlenen > 0 THEN
    INSERT INTO public.bildirim_log (tip, mesaj)
    VALUES ('ORPHAN_GOREV',
            format('%s orphan görev temizlendi (trigger kaçağı?)', v_temizlenen));
  END IF;

  RETURN jsonb_build_object('temizlenen', v_temizlenen, 'zaman', now());
END;
$function$
;

-- TRIGGER: trg_gorev_parent_kapandi (gorev_log)
CREATE TRIGGER trg_gorev_parent_kapandi AFTER DELETE OR UPDATE OF tamamlandi, iptal ON public.gorev_log FOR EACH ROW EXECUTE FUNCTION _trg_gorev_parent_kapandi();

-- TRIGGER: trg_hayvan_cikis_gorev_iptal (hayvanlar)
CREATE TRIGGER trg_hayvan_cikis_gorev_iptal AFTER UPDATE OF durum ON public.hayvanlar FOR EACH ROW EXECUTE FUNCTION _trg_hayvan_cikis_gorev_iptal();

-- ════════════════════════════════════════════════════════════════════════════
-- farm_id İleri-Disiplini — Temel (2026-07-01, Faz 2 hazırlığı)
-- Kapsam: SADECE public.current_farm_id() helper'ı. Mevcut tablo/RLS'e dokunmaz.
-- Lockdown bloğu (yukarıda) zaten GRANT EXECUTE ON ALL FUNCTIONS ... TO
-- authenticated yapıyor → current_farm_id authenticated-only olur.
-- Kaynak: .claude/farm-id-discipline.md (kanonik kural).
-- ════════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.current_farm_id() RETURNS uuid
LANGUAGE sql STABLE SET search_path = pg_catalog, public AS $$
  SELECT '400b9107-a85e-4126-af2c-fd7fe73fb68e'::uuid;
$$;

COMMENT ON FUNCTION public.current_farm_id() IS
  'farm_id ileri-disiplini: şimdilik REAL_FARM_ID sabiti. Faz 2 multi-tenant''te JWT/profiles''tan okunacak. Detay: .claude/farm-id-discipline.md';

