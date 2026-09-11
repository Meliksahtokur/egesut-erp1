-- ============================================================================
-- Migration: 20260911000002_pedigree_foundation (Task 1 / P1 — gate G1)
-- Tarih: 2026-09-11
-- Otorite: .claude/plans/2026-09-10-pedigree-genetics-impl.md L381-685 (Task 1.1-1.7)
--          spec §4 referans; plan ile çelişirse plan kazanır.
--
-- Kapsam: pedigree_nodes, pedigree_parentage, semen_catalog, pedigree_meta
--         + assert_is_operator + 5 helper + hayvanlar INSERT trigger
--         + RLS (USING true) + grant'lar (yalnız authenticated).
--         tohumlama.semen_id genişletmesi BURADA DEĞİL (sonraki migration).
--
-- Replay-safe: tüm DDL idempotent (IF NOT EXISTS / DROP IF EXISTS / CREATE OR
-- REPLACE) — ikinci koşum no-op'tur.
--
-- ÖLÇÜLMÜŞ DEMO GERÇEĞİ (2026-09-11, pg_default_acl):
--   postgres rolü için default ACL yeni tablolara authenticated=arwd (YAZMA
--   dahil) veriyor. Graph DML istemciye açılmaz kontratı yüzünden REVOKE'lar
--   açıkça yazıldı — default ACL geçmişine güvenme.
--
-- DEPLOY TALİMATI (owner bootstrap; migration op_owner_uid YAZMAZ — fail-closed):
--   INSERT INTO public.pedigree_meta (key, value)
--     VALUES ('op_owner_uid', '<owner-auth-uid>');
--   -- farm_id DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e' dolar.
--   -- Bu satır girilene dek assert_is_operator() herkese kapalıdır.
-- ============================================================================

-- ── 1.2 Tablolar ───────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.pedigree_nodes (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id           uuid NOT NULL DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e',
  farm_animal_id    text NULL REFERENCES public.hayvanlar(id) ON DELETE CASCADE,
  node_kind         text NOT NULL CHECK (node_kind IN ('farm_animal','external_animal')),
  display_name      text NULL,
  registry_system   text NULL,
  registry_code     text NULL,
  sex               text NULL,
  breed             text NULL,
  birth_date        date NULL,
  country_code      text NULL,
  founder_status    text NOT NULL DEFAULT 'ordinary'
                    CHECK (founder_status IN ('explicit_founder','ordinary')),
  metadata          jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chk_pedigree_nodes_kind_invariant CHECK (
    (node_kind = 'farm_animal'     AND farm_animal_id IS NOT NULL)
    OR (node_kind = 'external_animal' AND farm_animal_id IS NULL)),
  CONSTRAINT pedigree_nodes_farm_id_id_key UNIQUE (farm_id, id),
  CONSTRAINT pedigree_nodes_farm_animal_id_key UNIQUE (farm_id, farm_animal_id)
);

CREATE TABLE IF NOT EXISTS public.pedigree_parentage (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id           uuid NOT NULL DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e',
  parent_node_id    uuid NOT NULL,
  child_node_id     uuid NOT NULL,
  parent_role       text NOT NULL CHECK (parent_role IN ('dam','sire')),
  source_type       text NOT NULL CHECK (source_type IN ('birth','manual','import','reconcile')),
  source_ref        text NULL,
  evidence          jsonb NOT NULL DEFAULT '{}'::jsonb,
  confidence        numeric NOT NULL DEFAULT 1.0 CHECK (confidence >= 0 AND confidence <= 1),
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_parentage_parent_farm_node FOREIGN KEY (farm_id, parent_node_id)
    REFERENCES public.pedigree_nodes(farm_id, id) ON DELETE CASCADE,
  CONSTRAINT fk_parentage_child_farm_node FOREIGN KEY (farm_id, child_node_id)
    REFERENCES public.pedigree_nodes(farm_id, id) ON DELETE CASCADE,
  CONSTRAINT chk_parentage_parent_ne_child CHECK (parent_node_id <> child_node_id),
  CONSTRAINT pedigree_parentage_farm_child_role_key UNIQUE (farm_id, child_node_id, parent_role)
);

CREATE TABLE IF NOT EXISTS public.semen_catalog (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id           uuid NOT NULL DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e',
  bull_node_id      uuid NOT NULL,
  stock_id          text NULL REFERENCES public.stok(id) ON DELETE SET NULL,
  code              text NULL,
  display_name      text NOT NULL,
  supplier          text NULL,
  semen_type        text NULL,
  active            boolean NOT NULL DEFAULT true,
  metadata          jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_semen_catalog_bull_farm_node FOREIGN KEY (farm_id, bull_node_id)
    REFERENCES public.pedigree_nodes(farm_id, id),
  CONSTRAINT semen_catalog_farm_stock_key UNIQUE (farm_id, stock_id)
);

CREATE TABLE IF NOT EXISTS public.pedigree_meta (
  farm_id           uuid NOT NULL DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e',
  key               text NOT NULL,
  value             text NOT NULL,
  PRIMARY KEY (farm_id, key)
);

-- İndexler (farm_id ile BAŞLAR — tenant disiplini)
CREATE UNIQUE INDEX IF NOT EXISTS uq_pedigree_nodes_registry
  ON public.pedigree_nodes (farm_id, registry_system, registry_code)
  WHERE registry_system IS NOT NULL AND registry_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pedigree_nodes_farm_kind
  ON public.pedigree_nodes (farm_id, node_kind);

CREATE INDEX IF NOT EXISTS idx_parentage_farm_child
  ON public.pedigree_parentage (farm_id, child_node_id);

CREATE INDEX IF NOT EXISTS idx_parentage_farm_parent
  ON public.pedigree_parentage (farm_id, parent_node_id);

CREATE INDEX IF NOT EXISTS idx_parentage_farm_role_child
  ON public.pedigree_parentage (farm_id, parent_role, child_node_id);

-- ── 1.3 RLS (USING true — repo politikası) ────────────────────────────────

ALTER TABLE public.pedigree_nodes     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pedigree_parentage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.semen_catalog      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pedigree_meta      ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS allow_all ON public.pedigree_nodes;
CREATE POLICY allow_all ON public.pedigree_nodes FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS allow_all ON public.pedigree_parentage;
CREATE POLICY allow_all ON public.pedigree_parentage FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS allow_all ON public.semen_catalog;
CREATE POLICY allow_all ON public.semen_catalog FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS allow_all ON public.pedigree_meta;
CREATE POLICY allow_all ON public.pedigree_meta FOR ALL USING (true) WITH CHECK (true);

-- ── Grant'lar (ölçülmüş default ACL'ye karşı AÇIK state) ──────────────────
-- Yeni tablolar default ACL'de authenticated=arwd ile doğuyor → graph tablo-
-- larına yazmayı açıkça geri al; yalnız semen_catalog SELECT authenticated'da.

REVOKE ALL ON public.pedigree_nodes     FROM anon, authenticated;
REVOKE ALL ON public.pedigree_parentage FROM anon, authenticated;
REVOKE ALL ON public.pedigree_meta      FROM anon, authenticated;
REVOKE ALL ON public.semen_catalog      FROM anon;
-- F1 (tur-1): default ACL authenticated=arwd — INSERT/UPDATE/DELETE açıkça
-- geri alınır; yalnız SELECT kalır (D3 IDB sync okuması). Yazma yolu yalnız
-- guarded RPC (semen_catalog_upsert).
REVOKE INSERT, UPDATE, DELETE ON public.semen_catalog FROM authenticated;

GRANT SELECT ON public.semen_catalog TO authenticated;

-- ── 1.2b Operatör guard (fail-closed) ─────────────────────────────────────

CREATE OR REPLACE FUNCTION public.assert_is_operator() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE
  v_owner text;
BEGIN
  SELECT value INTO v_owner FROM public.pedigree_meta
   WHERE farm_id = public.current_farm_id() AND key = 'op_owner_uid';
  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'op_owner_uid tanimli degil - sistem kapali (fail-closed)';
  END IF;
  IF coalesce(auth.uid()::text, '') <> v_owner THEN
    RAISE EXCEPTION 'operator degil';
  END IF;
END;
$fn$;

-- assert_is_operator içseldir: istemciye EXECUTE yok.
REVOKE ALL ON FUNCTION public.assert_is_operator() FROM PUBLIC, anon, authenticated, service_role;

-- ── 1.4 Helper'lar ────────────────────────────────────────────────────────

-- Farm hayvanı için node bul-ya-da-yarat (idempotent). Sex normalize kontratı:
-- 'Erkek'→'male', 'Dişi'→'female', bilinmeyen/boş→NULL.
CREATE OR REPLACE FUNCTION public.pedigree_ensure_farm_node(p_hayvan_id text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE
  v_node_id uuid;
  v_sex     text;
BEGIN
  SELECT id INTO v_node_id
    FROM public.pedigree_nodes
   WHERE farm_id = public.current_farm_id() AND farm_animal_id = p_hayvan_id;
  IF v_node_id IS NOT NULL THEN
    RETURN v_node_id;
  END IF;

  SELECT CASE cinsiyet WHEN 'Erkek' THEN 'male' WHEN 'Dişi' THEN 'female' ELSE NULL END
    INTO v_sex
    FROM public.hayvanlar
   WHERE id = p_hayvan_id;

  INSERT INTO public.pedigree_nodes (farm_animal_id, node_kind, sex)
  VALUES (p_hayvan_id, 'farm_animal', v_sex)
  ON CONFLICT (farm_id, farm_animal_id) DO UPDATE SET updated_at = now()
  RETURNING id INTO v_node_id;

  RETURN v_node_id;
END;
$fn$;
-- F2 (tur-1): INTERNAL makine fonksiyonu — istemci yüzeyi yok. Trigger yolu
-- kırılmaz: (a) trigger çağrısında EXECUTE ayrıca denetlenmez, (b) çağrı zinciri
-- _trg_pedigree_hayvan_insert (SECURITY DEFINER, definer=postgres) içinden
-- geçer → çalışma-anı EXECUTE denetimi definer olarak yapılır. Kanıt: test C19.
REVOKE ALL ON FUNCTION public.pedigree_ensure_farm_node(text)
  FROM PUBLIC, anon, authenticated, service_role;

-- Katı ata sorgusu: p_ancestor, p_descendant'ın atası mı? (kendisi değil)
CREATE OR REPLACE FUNCTION public.pedigree_is_ancestor(p_ancestor uuid, p_descendant uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
  WITH RECURSIVE up AS (
    SELECT pp.parent_node_id AS node_id
      FROM public.pedigree_parentage pp
     WHERE pp.farm_id = public.current_farm_id() AND pp.child_node_id = p_descendant
    UNION
    SELECT pp.parent_node_id
      FROM public.pedigree_parentage pp
      JOIN up ON pp.child_node_id = up.node_id
     WHERE pp.farm_id = public.current_farm_id()
  )
  SELECT EXISTS (SELECT 1 FROM up WHERE node_id = p_ancestor);
$fn$;
-- F2 (tur-1): okuma helper'ı da içseldir — guardsız graph atası sorgusu istemciye açılmaz.
REVOKE ALL ON FUNCTION public.pedigree_is_ancestor(uuid,uuid)
  FROM PUBLIC, anon, authenticated, service_role;

-- INTERNAL çekirdek: pedigree_parent_set ile AYNI parametreler. EXECUTE grant'i
-- kimseye verilmez (aşağıda REVOKE) — yalnız SQL-içi çağrı: public.pedigree_parent_set
-- (guard + core). Doğum yolunun üretim bağlantısı Faz 7'dedir (P1'de YOK —
-- review F4). r12-F62.
CREATE OR REPLACE FUNCTION public._pedigree_parent_set_core(
  p_child_node_id uuid,
  p_role          text,
  p_parent_node_id uuid,
  p_source_type   text DEFAULT 'manual',
  p_source_ref    text DEFAULT NULL,
  p_replace       boolean DEFAULT false,
  p_evidence      jsonb DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE
  v_farm        uuid := public.current_farm_id();
  v_edge_id     uuid;
  v_cur_parent  uuid;
  v_parent_sex  text;
BEGIN
  -- Parentage mutasyonunu serialize et (check-then-use penceresini kapat)
  PERFORM pg_advisory_xact_lock(hashtext('pedigree_parentage'));

  IF p_role NOT IN ('dam','sire') THEN
    RAISE EXCEPTION 'gecersiz parent_role: %', p_role;
  END IF;
  IF p_source_type NOT IN ('birth','manual','import','reconcile') THEN
    RAISE EXCEPTION 'gecersiz source_type: %', p_source_type;
  END IF;
  IF p_child_node_id = p_parent_node_id THEN
    RAISE EXCEPTION 'parent = child reddedildi';
  END IF;

  -- same-farm check (DDL composite FK ikinci savunma; burada açık mesaj)
  IF NOT EXISTS (SELECT 1 FROM public.pedigree_nodes
                  WHERE farm_id = v_farm AND id = p_child_node_id) THEN
    RAISE EXCEPTION 'child node bulunamadi ya da farkli farm: %', p_child_node_id;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.pedigree_nodes
                  WHERE farm_id = v_farm AND id = p_parent_node_id) THEN
    RAISE EXCEPTION 'parent node bulunamadi ya da farkli farm: %', p_parent_node_id;
  END IF;

  -- explicit_founder node'a parent edge eklenmez (önce ordinary yapılır)
  IF EXISTS (SELECT 1 FROM public.pedigree_nodes
              WHERE farm_id = v_farm AND id = p_child_node_id
                AND founder_status = 'explicit_founder') THEN
    RAISE EXCEPTION 'explicit_founder node parent edge alamaz (once ordinary yapilmeli)';
  END IF;

  -- Sex kontrolü fail-closed DEĞİL (veri uyumu): bilinen değerlerde reddet
  SELECT sex INTO v_parent_sex
    FROM public.pedigree_nodes
   WHERE farm_id = v_farm AND id = p_parent_node_id;
  IF p_role = 'dam' AND v_parent_sex = 'male' THEN
    RAISE EXCEPTION 'bilinen erkek dam olamaz';
  END IF;
  IF p_role = 'sire' AND v_parent_sex = 'female' THEN
    RAISE EXCEPTION 'bilinen disi sire olamaz';
  END IF;

  -- Cycle: parent, child'ın dölü olamaz (yeni edge parent→child döngü kapatır)
  IF public.pedigree_is_ancestor(p_child_node_id, p_parent_node_id) THEN
    RAISE EXCEPTION 'cycle reddedildi: child zaten parent''in atasi';
  END IF;

  -- Mevcut edge: aynı role
  SELECT id, parent_node_id INTO v_edge_id, v_cur_parent
    FROM public.pedigree_parentage
   WHERE farm_id = v_farm AND child_node_id = p_child_node_id AND parent_role = p_role;

  IF v_edge_id IS NOT NULL THEN
    IF v_cur_parent = p_parent_node_id THEN
      RETURN v_edge_id;  -- idempotent success
    END IF;
    -- F3 (tur-1): üç-değerli tuzak — NULL p_replace açık onay DEĞİLDİR (fail-closed)
    IF p_replace IS NOT TRUE THEN
      RAISE EXCEPTION 'farkli parent — sessiz overwrite yok; p_replace=true gerekli';
    END IF;
    UPDATE public.pedigree_parentage
       SET parent_node_id = p_parent_node_id,
           source_type    = p_source_type,
           source_ref     = p_source_ref,
           evidence       = COALESCE(p_evidence, '{}'::jsonb)
     WHERE id = v_edge_id
    RETURNING id INTO v_edge_id;
    RETURN v_edge_id;
  END IF;

  INSERT INTO public.pedigree_parentage
    (farm_id, parent_node_id, child_node_id, parent_role, source_type, source_ref, evidence)
  VALUES
    (v_farm, p_parent_node_id, p_child_node_id, p_role, p_source_type, p_source_ref,
     COALESCE(p_evidence, '{}'::jsonb))
  RETURNING id INTO v_edge_id;

  RETURN v_edge_id;
END;
$fn$;

-- INTERNAL kontratı: core'a kimsenin EXECUTE'u yok (yalnız sahibi postgres).
REVOKE ALL ON FUNCTION public._pedigree_parent_set_core(uuid,text,uuid,text,text,boolean,jsonb)
  FROM PUBLIC, anon, authenticated, service_role;

-- PUBLIC RPC: operatör guard'ı + core. (r5-F29: p_evidence COALESCE core'da.)
CREATE OR REPLACE FUNCTION public.pedigree_parent_set(
  p_child_node_id uuid,
  p_role          text,
  p_parent_node_id uuid,
  p_source_type   text DEFAULT 'manual',
  p_source_ref    text DEFAULT NULL,
  p_replace       boolean DEFAULT false,
  p_evidence      jsonb DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
BEGIN
  PERFORM public.assert_is_operator();
  RETURN public._pedigree_parent_set_core(
    p_child_node_id, p_role, p_parent_node_id,
    p_source_type, p_source_ref, p_replace, p_evidence);
END;
$fn$;

-- PUBLIC RPC: external node find-or-create. Zorunlu parametreler ÖNCE (r4-F13).
CREATE OR REPLACE FUNCTION public.pedigree_external_upsert(
  p_display_name   text,
  p_node_id        uuid DEFAULT NULL,
  p_sex            text DEFAULT NULL,
  p_breed          text DEFAULT NULL,
  p_birth_date     date DEFAULT NULL,
  p_registry_system text DEFAULT NULL,
  p_registry_code  text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE
  v_farm     uuid := public.current_farm_id();
  v_id       uuid;
  v_norm_sex text := CASE p_sex WHEN 'Erkek' THEN 'male'
                                 WHEN 'Dişi'  THEN 'female'
                                 ELSE p_sex END;
BEGIN
  PERFORM public.assert_is_operator();

  IF p_node_id IS NOT NULL THEN
    UPDATE public.pedigree_nodes
       SET display_name    = COALESCE(p_display_name, display_name),
           sex             = COALESCE(v_norm_sex, sex),
           breed           = COALESCE(p_breed, breed),
           birth_date      = COALESCE(p_birth_date, birth_date),
           registry_system = COALESCE(p_registry_system, registry_system),
           registry_code   = COALESCE(p_registry_code, registry_code),
           updated_at      = now()
     WHERE id = p_node_id AND farm_id = v_farm AND node_kind = 'external_animal'
    RETURNING id INTO v_id;
    IF v_id IS NULL THEN
      RAISE EXCEPTION 'external node bulunamadi ya da farkli farm: %', p_node_id;
    END IF;
    RETURN v_id;
  END IF;

  -- Aynı registry identity ikinci kez oluşmaz: bul-duysa-dön (idempotent)
  IF p_registry_system IS NOT NULL AND p_registry_code IS NOT NULL THEN
    SELECT id INTO v_id
      FROM public.pedigree_nodes
     WHERE farm_id = v_farm
       AND registry_system = p_registry_system
       AND registry_code   = p_registry_code;
    IF v_id IS NOT NULL THEN
      RETURN v_id;
    END IF;
  END IF;

  INSERT INTO public.pedigree_nodes
    (node_kind, display_name, sex, breed, birth_date, registry_system, registry_code)
  VALUES
    ('external_animal', p_display_name, v_norm_sex, p_breed, p_birth_date,
     p_registry_system, p_registry_code)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$fn$;

-- PUBLIC RPC: semen katalog upsert (Task 11 "Elle Gir" akışının tek yolu).
-- Kilit kontratı: gövde başında advisory xact lock — check-then-use kapansın.
-- Tarihsel değişmezlik: satır tohumlama.semen_id ile referans edildiyse
-- bull_node_id DEĞİŞTİRİLEMEZ (semen_id kolonu sonraki migration'da gelir;
-- information_schema ile varlık-guard'lı).
CREATE OR REPLACE FUNCTION public.semen_catalog_upsert(
  p_display_name   text,
  p_id             uuid DEFAULT NULL,
  p_bull_node_id   uuid DEFAULT NULL,
  p_registry_system text DEFAULT NULL,
  p_registry_code  text DEFAULT NULL,
  p_stock_id       text DEFAULT NULL,
  p_code           text DEFAULT NULL,
  p_supplier       text DEFAULT NULL,
  p_semen_type     text DEFAULT NULL,
  p_active         boolean DEFAULT true
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE
  v_farm      uuid := public.current_farm_id();
  v_id        uuid;
  v_bull      uuid;
  v_cur_bull  uuid;
  v_sex       text;
  v_kategori  text;
  v_refs      integer := 0;
  v_semen_id_kolon boolean;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('pedigree_semen_catalog'));
  PERFORM public.assert_is_operator();

  -- (a) stock guard: verilen stok Sperma kategorisinde olmalı
  IF p_stock_id IS NOT NULL THEN
    SELECT kategori INTO v_kategori FROM public.stok WHERE id = p_stock_id;
    IF v_kategori IS NULL THEN
      RAISE EXCEPTION 'stok bulunamadi: %', p_stock_id;
    END IF;
    IF v_kategori <> 'Sperma' THEN
      RAISE EXCEPTION 'stok kategorisi Sperma degil: %', v_kategori;
    END IF;
  END IF;

  IF p_id IS NOT NULL THEN
    SELECT bull_node_id INTO v_cur_bull
      FROM public.semen_catalog
     WHERE farm_id = v_farm AND id = p_id;
    IF v_cur_bull IS NULL THEN
      RAISE EXCEPTION 'semen_catalog satiri bulunamadi: %', p_id;
    END IF;

    -- Tarihsel kimlik değişmezliği (r10-F57/r12-F78)
    SELECT EXISTS (
      SELECT 1 FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = 'tohumlama'
         AND column_name = 'semen_id'
    ) INTO v_semen_id_kolon;
    IF v_semen_id_kolon THEN
      EXECUTE 'SELECT count(*) FROM public.tohumlama WHERE semen_id = $1'
         INTO v_refs USING p_id;
    END IF;
    IF p_bull_node_id IS NOT NULL AND p_bull_node_id <> v_cur_bull THEN
      IF v_refs > 0 THEN
        RAISE EXCEPTION 'bull_node_id degistirilemez: satir % tohumlama kaydi tarafindan referans ediliyor', v_refs;
      END IF;
      -- (b) guard güncelleme yolunda da geçerli: yeni bull female olamaz
      SELECT sex INTO v_sex
        FROM public.pedigree_nodes
       WHERE farm_id = v_farm AND id = p_bull_node_id;
      IF v_sex IS NULL THEN
        RAISE EXCEPTION 'bull node bulunamadi ya da farkli farm: %', p_bull_node_id;
      END IF;
      IF v_sex = 'female' THEN
        RAISE EXCEPTION 'bull node female olamaz';
      END IF;
    END IF;

    UPDATE public.semen_catalog
       SET bull_node_id  = COALESCE(p_bull_node_id, bull_node_id),
           stock_id      = COALESCE(p_stock_id, stock_id),
           code          = COALESCE(p_code, code),
           display_name  = COALESCE(p_display_name, display_name),
           supplier      = COALESCE(p_supplier, supplier),
           semen_type    = COALESCE(p_semen_type, semen_type),
           active        = p_active
     WHERE farm_id = v_farm AND id = p_id
    RETURNING id INTO v_id;
    RETURN v_id;
  END IF;

  -- Bull çözümü: verilmediyse external bull node yarat (sex='male' yazar)
  IF p_bull_node_id IS NOT NULL THEN
    v_bull := p_bull_node_id;
  ELSE
    v_bull := public.pedigree_external_upsert(
      p_display_name, NULL, 'male', NULL, NULL, p_registry_system, p_registry_code);
  END IF;

  -- (b) bull node guard: bilinen female node bull olamaz
  SELECT sex INTO v_sex
    FROM public.pedigree_nodes
   WHERE farm_id = v_farm AND id = v_bull;
  IF v_sex IS NULL THEN
    RAISE EXCEPTION 'bull node bulunamadi ya da farkli farm: %', v_bull;
  END IF;
  IF v_sex = 'female' THEN
    RAISE EXCEPTION 'bull node female olamaz';
  END IF;

  INSERT INTO public.semen_catalog
    (bull_node_id, stock_id, code, display_name, supplier, semen_type, active)
  VALUES
    (v_bull, p_stock_id, p_code, p_display_name, p_supplier, p_semen_type, p_active)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$fn$;

-- ── 1.3 Grant'lar (fonksiyonlar — plan 1.3 listesi birebir) ───────────────
-- F5 (root-gate): authenticated-only kontratı service_role'u da kapsar —
-- default ACL yeni fonksiyona service_role=X veriyor; açık revoke şart.

REVOKE ALL ON FUNCTION public.pedigree_parent_set(uuid,text,uuid,text,text,boolean,jsonb)
  FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.pedigree_parent_set(uuid,text,uuid,text,text,boolean,jsonb)
  TO authenticated;

REVOKE ALL ON FUNCTION public.pedigree_external_upsert(text,uuid,text,text,date,text,text)
  FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.pedigree_external_upsert(text,uuid,text,text,date,text,text)
  TO authenticated;

REVOKE ALL ON FUNCTION public.semen_catalog_upsert(text,uuid,uuid,text,text,text,text,text,text,boolean)
  FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.semen_catalog_upsert(text,uuid,uuid,text,text,text,text,text,text,boolean)
  TO authenticated;

-- ── 1.5 Hayvan insert trigger ─────────────────────────────────────────────
-- CREATE TRIGGER argümanları sabit olmak zorundadır (NEW.id geçemez) → ince
-- wrapper (ev deseni: trg_islem_hayvanlar → _islem_log_yaz()).

CREATE OR REPLACE FUNCTION public._trg_pedigree_hayvan_insert() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
BEGIN
  PERFORM public.pedigree_ensure_farm_node(NEW.id);
  RETURN NULL;  -- AFTER trigger: dönüş değeri yok sayılır
END;
$fn$;

DROP TRIGGER IF EXISTS trg_pedigree_hayvan_insert ON public.hayvanlar;
CREATE TRIGGER trg_pedigree_hayvan_insert
  AFTER INSERT ON public.hayvanlar
  FOR EACH ROW EXECUTE FUNCTION public._trg_pedigree_hayvan_insert();

-- F2 (tur-1): trigger sarmalayıcısı da içseldir — doğrudan istemci çağrısı kapalı.
REVOKE ALL ON FUNCTION public._trg_pedigree_hayvan_insert()
  FROM PUBLIC, anon, authenticated, service_role;
