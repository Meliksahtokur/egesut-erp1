-- ============================================================================
-- Migration: 20260911000003_pedigree_farm_backfill (Task 2 / P1 — gate G2)
-- Tarih: 2026-09-11
-- Otorite: .claude/plans/2026-09-10-pedigree-genetics-impl.md L689-905 (Task 2.1-2.4)
--          Plan ile çelişirse plan kazanır.
--
-- NOT (isim drifti): plan literal dosya adı "20260910000002_pedigree_farm_backfill"
-- idi; W1/W2 gerçek dizisi 20260911000001/2 olduğundan bu dosya ...3 sırasındadır
-- (worker gate kırıntısı ba9910c815a9, doc-drift).
--
-- Kapsam:
--   2.1 farm node backfill  -> pedigree_farm_backfill() (tüm hayvanlar, idempotent)
--   2.2 maternal edge backfill -> yalnız güvenli satırlar (buzagi_id FK predicate)
--   2.3 pedigree_integrity_report() -> 18-kod evreni, tek JSON, read-only
--   2.4 idempotency -> tests/sql/pedigree_farm_backfill_test.sql (ikinci koşum 0/0)
--
-- Replay-safe: tüm DDL CREATE OR REPLACE; backfill yalnız eksik node/edge'e
-- yazar; ikinci koşum 0 yeni node / 0 yeni edge üretir (test kanıtlar).
--
-- Maternal edge dışlama kuralı (r5-F23, r6-F31, buzazi_id KABUL 2026-09-11):
--   edge YALNIZ şu koşulda:
--     c.anne_id IS NOT NULL
--     AND EXISTS (hayvanlar p WHERE p.id = c.anne_id)          -- dam mevcut
--     AND c.dogum_tarihi IS NOT NULL                            -- tarih kanıtı
--     AND EXISTS (dogum d WHERE d.buzagi_id = c.id              -- child'ın KENDİ
--                AND d.anne_id = c.anne_id                      --   doğum satırı (FK)
--                AND d.tarih <= c.dogum_tarihi)                 -- temporal koşul (S8)
--   Kupe-join YOKTUR; "en geç kayıt" yorumu YOKTUR.
--
-- Backfill katılığı: kenar yaratımı tek canonical mutation yolundan geçer
-- (_pedigree_parent_set_core, source_type='reconcile', confidence default 1.0).
-- Core reddi (bilinen erkek dam / mevcut farklı parent / parent=child) satır-
-- bazında ATLANIR ve sayılır (sessiz overwrite YOK korunur; atlanan satır
-- raporda child_without_dam warning olarak görünür — maternal_tarihsel_uyumsuz
-- ve maternal_tarih_bilinmiyor sınıfları plan 2.2'deki predikatlarına göre
-- bağımsız emit edilir).
--
-- pedigree_integrity_report() — 18 kodun severity matrisi (r10-F52; r6-F33):
--   blocker: maternal_tarihsel_uyumsuz, duplicate_registry, cycle_count,
--            post_cutoff_null_semen, cutoff_invalid
--   warning: farm_animal_node_eksik, unresolved_anne_id, child_without_dam,
--            role_sex_contradiction, legacy_semen_no_mapping,
--            parent_born_after_child, maternal_tarih_bilinmiyor,
--            legacy_anne_graph_dam_celiskisi, dogum_anne_graph_dam_celiskisi,
--            suspiciously_young_parent
--   info:    unresolved_baba_bilgi, child_without_sire, dogum_buzagi_missing
-- Emisyon: (a) bulgusu olmayan grup emit edilmez; (b) sayım anlamlı grupta her
-- ihlal satırı bir item'dır ({count:0} item yoktur); (c) cutoff yoksa
-- "tanimsiz", cast NULL ise "gecersiz" (pedigree_try_timestamptz — istisna
-- raporu ÇALIŞTIRAMAZ); cutoff tanimsiz → post_cutoff_null_semen emit edilmez.
--
-- GEÇİCİ NESNE NOTU (P1 gerçeği): pedigree_legacy_identity_map (Task 8) ve
-- tohumlama.semen_id (Task 10) henüz yoktur. unresolved_baba_bilgi ve
-- legacy_semen_no_mapping gruplarının sorguları Task 8 migration'ınca EXTEND
-- edilir (kolonlar orada tanımlanır); tablo inmeden bu gruplar EMİT EDİLMEZ
-- (r12-F69: inmeden önce emit edilmez). post_cutoff_null_semen sorgusu
-- dinamik SQL'dir (information_schema semen_id guard'ı) — kolon yoksa grup
-- atlanır.
-- ============================================================================

-- ── Helper: istisna-güvenli timestamptz cast (plan 2.3 yazma kuralı) ──────
CREATE OR REPLACE FUNCTION public.pedigree_try_timestamptz(p_value text)
RETURNS timestamptz
LANGUAGE plpgsql STABLE
SET search_path = public, pg_temp
AS $fn$
BEGIN
  RETURN p_value::timestamptz;
EXCEPTION WHEN others THEN
  RETURN NULL;
END;
$fn$;

-- İçsel helper: istemci yüzeyi yok (W2 F2 deseni).
REVOKE ALL ON FUNCTION public.pedigree_try_timestamptz(text)
  FROM PUBLIC, anon, authenticated, service_role;

-- ── 2.1 + 2.2 Backfill ────────────────────────────────────────────────────
-- Dönen sayaçlar idempotency kanıtının ta kendisidir: ikinci koşumda
-- nodes_created=0 ve maternal_edges_created=0 (2.4 testi).
CREATE OR REPLACE FUNCTION public.pedigree_farm_backfill()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_farm         uuid := public.current_farm_id();
  r              record;
  v_child_node   uuid;
  v_dam_node     uuid;
  v_nodes_before integer;
  v_nodes_after  integer;
  v_edges_before integer;
  v_edges_after  integer;
  v_matched      integer := 0;
  v_skipped      integer := 0;
BEGIN
  IF to_regclass('public.pedigree_nodes') IS NULL
     OR to_regclass('public.pedigree_parentage') IS NULL THEN
    RAISE EXCEPTION 'pedigree foundation yok — once 20260911000002 koşmalı';
  END IF;

  SELECT count(*) INTO v_nodes_before
    FROM public.pedigree_nodes
   WHERE farm_id = v_farm AND node_kind = 'farm_animal';

  -- 2.1: tüm farm hayvanları için idempotent node (ensure bul-yoksa-yarat)
  FOR r IN SELECT id FROM public.hayvanlar
  LOOP
    PERFORM public.pedigree_ensure_farm_node(r.id);
  END LOOP;

  SELECT count(*) INTO v_nodes_after
    FROM public.pedigree_nodes
   WHERE farm_id = v_farm AND node_kind = 'farm_animal';

  SELECT count(*) INTO v_edges_before
    FROM public.pedigree_parentage
   WHERE farm_id = v_farm;

  -- 2.2: yalnız güvenli satırlar (buzagi_id FK predicate — başlıktaki tam SQL)
  FOR r IN
    SELECT c.id AS cid, c.anne_id AS pid
      FROM public.hayvanlar c
     WHERE c.anne_id IS NOT NULL
       AND EXISTS (SELECT 1 FROM public.hayvanlar p WHERE p.id = c.anne_id)
       AND c.dogum_tarihi IS NOT NULL
       AND EXISTS (SELECT 1 FROM public.dogum d
                    WHERE d.buzagi_id = c.id
                      AND d.anne_id  = c.anne_id
                      AND d.tarih   <= c.dogum_tarihi)
  LOOP
    v_matched := v_matched + 1;
    BEGIN
      v_child_node := public.pedigree_ensure_farm_node(r.cid);
      v_dam_node   := public.pedigree_ensure_farm_node(r.pid);
      -- confidence: kolon default 1.0 (plan: confidence = 1); sessiz overwrite
      -- YOK — mevcut farklı dam varsa core reddeder, satır atlanır.
      PERFORM public._pedigree_parent_set_core(
        v_child_node, 'dam', v_dam_node, 'reconcile', 'pedigree_farm_backfill', false, NULL);
    EXCEPTION WHEN OTHERS THEN
      v_skipped := v_skipped + 1;
    END;
  END LOOP;

  SELECT count(*) INTO v_edges_after
    FROM public.pedigree_parentage
   WHERE farm_id = v_farm;

  RETURN jsonb_build_object(
    'farm_id',               v_farm,
    'nodes_total',           v_nodes_after,
    'nodes_created',         v_nodes_after - v_nodes_before,
    'maternal_safe_rows',    v_matched,
    'maternal_edges_created', v_edges_after - v_edges_before,
    'maternal_edges_skipped', v_skipped);
END;
$fn$;

-- İçsel bakım fonksiyonu: istemci yüzeyi yok (W2 F2 deseni).
REVOKE ALL ON FUNCTION public.pedigree_farm_backfill()
  FROM PUBLIC, anon, authenticated, service_role;

-- ── 2.3 pedigree_integrity_report() — read-only RPC, tek JSON ─────────────
CREATE OR REPLACE FUNCTION public.pedigree_integrity_report()
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public, pg_temp
AS $fn$
DECLARE
  v_farm           uuid := public.current_farm_id();
  v_cutoff_raw     text;
  v_cutoff_ts      timestamptz;
  v_cutoff_iso     text;
  v_cutoff_state   text;      -- 'ok' | 'tanimsiz' | 'gecersiz'
  v_has_semen_col  boolean;
  v_static_groups  jsonb;
  v_dyn_group      jsonb;
  v_groups         jsonb;
  v_ordered        jsonb;
BEGIN
  -- Cutoff okuması NULL-güvenli: anahtar yok → 'tanimsiz', cast NULL → 'gecersiz'
  SELECT value INTO v_cutoff_raw
    FROM public.pedigree_meta
   WHERE farm_id = v_farm AND key = 'semen_controlled_cutoff';

  IF v_cutoff_raw IS NULL THEN
    v_cutoff_state := 'tanimsiz';
  ELSE
    v_cutoff_ts := public.pedigree_try_timestamptz(v_cutoff_raw);
    IF v_cutoff_ts IS NULL THEN
      v_cutoff_state := 'gecersiz';
    ELSE
      v_cutoff_state := 'ok';
      v_cutoff_iso := to_char(v_cutoff_ts AT TIME ZONE 'UTC',
                              'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
    END IF;
  END IF;

  -- Geçici nesne guard'ları (P1: ikisi de yok → ilgili gruplar emit edilmez)
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'tohumlama'
       AND column_name = 'semen_id'
  ) INTO v_has_semen_col;

  -- ── Statik bulgu evreni (UNION ALL; her kod tek branch, severity tek yerde)
  WITH f(code, fkey, detail) AS (
    -- farm_animal_node_eksik (warning): hayvanlar satırı için node yok; key=hayvan_id
    SELECT 'farm_animal_node_eksik', h.id,
           'pedigree_nodes(farm_animal) satırı yok'
      FROM public.hayvanlar h
     WHERE NOT EXISTS (SELECT 1 FROM public.pedigree_nodes pn
                        WHERE pn.farm_id = v_farm AND pn.farm_animal_id = h.id)
    UNION ALL
    -- unresolved_anne_id (warning): key=hayvan_id
    SELECT 'unresolved_anne_id', h.id,
           'anne_id=' || h.anne_id || ' hayvanlar''da bulunamadı'
      FROM public.hayvanlar h
     WHERE h.anne_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.hayvanlar p WHERE p.id = h.anne_id)
    UNION ALL
    -- unresolved_baba_bilgi (info): pedigree_legacy_identity_map materializasyonu
    -- Task 8'de iner — inmeden önce bu grup EMİT EDİLMEZ (r12-F69). Sorgu Task 8
    -- migration'ınca bu UNION'a eklenecek. P1'de branch yoktur.
    SELECT 'unresolved_baba_bilgi', NULL, NULL
      WHERE false
    UNION ALL
    -- child_without_dam (warning): farm animal, 1 yaş üstü, dam edge yok; key=hayvan_id
    SELECT 'child_without_dam', pn.farm_animal_id,
           'dam edge yok; dogum_tarihi=' || COALESCE(h.dogum_tarihi::text, 'NULL')
      FROM public.pedigree_nodes pn
      JOIN public.hayvanlar h ON h.id = pn.farm_animal_id
     WHERE pn.farm_id = v_farm AND pn.node_kind = 'farm_animal'
       AND COALESCE(h.dogum_tarihi, pn.birth_date) < (current_date - interval '1 year')
       AND NOT EXISTS (SELECT 1 FROM public.pedigree_parentage pp
                        WHERE pp.farm_id = v_farm
                          AND pp.child_node_id = pn.id
                          AND pp.parent_role = 'dam')
    UNION ALL
    -- child_without_sire (info): farm animal, sire edge yok; key=hayvan_id
    SELECT 'child_without_sire', pn.farm_animal_id,
           'sire edge yok'
      FROM public.pedigree_nodes pn
     WHERE pn.farm_id = v_farm AND pn.node_kind = 'farm_animal'
       AND NOT EXISTS (SELECT 1 FROM public.pedigree_parentage pp
                        WHERE pp.farm_id = v_farm
                          AND pp.child_node_id = pn.id
                          AND pp.parent_role = 'sire')
    UNION ALL
    -- role_sex_contradiction (warning): key=edge-id
    SELECT 'role_sex_contradiction', pp.id::text,
           pp.parent_role || ' edge ama parent sex=' || COALESCE(pnp.sex, 'NULL')
      FROM public.pedigree_parentage pp
      JOIN public.pedigree_nodes pnp
        ON pnp.farm_id = pp.farm_id AND pnp.id = pp.parent_node_id
     WHERE pp.farm_id = v_farm
       AND ( (pp.parent_role = 'dam'  AND pnp.sex = 'male')
          OR (pp.parent_role = 'sire' AND pnp.sex = 'female') )
    UNION ALL
    -- duplicate_registry (blocker): key=registry_code
    SELECT 'duplicate_registry', pn.registry_code,
           'registry_system=' || pn.registry_system || ' node_sayisi=' || count(*)
      FROM public.pedigree_nodes pn
     WHERE pn.farm_id = v_farm
       AND pn.registry_system IS NOT NULL AND pn.registry_code IS NOT NULL
     GROUP BY pn.registry_system, pn.registry_code
    HAVING count(*) > 1
    UNION ALL
    -- legacy_semen_no_mapping (warning): DISTINCT tohumlama.sperma karşılıksız —
    -- Task 8 materializasyonu; inmeden EMİT EDİLMEZ (r12-F69).
    SELECT 'legacy_semen_no_mapping', NULL, NULL
      WHERE false
    UNION ALL
    -- cycle_count (blocker): recursive CTE, UNION dedup guard (sonsuz traversal
    -- yok); her döngü bileşeni 1 item, key = bileşenin min node-id
    -- (min(text) — PG'nin min(uuid) aggregate'i yoktur, kimlik text'te karşılaştırılır)
    SELECT 'cycle_count', min(rep.rep_id),
           'döngü üyeleri: ' || string_agg(rep.node::text, ',' ORDER BY rep.node)
      FROM (
        WITH RECURSIVE reach(src, dst) AS (
          SELECT pp.parent_node_id, pp.child_node_id
            FROM public.pedigree_parentage pp
           WHERE pp.farm_id = v_farm
          UNION
          SELECT r.src, pp.child_node_id
            FROM public.pedigree_parentage pp
            JOIN reach r ON pp.parent_node_id = r.dst
           WHERE pp.farm_id = v_farm
        ),
        on_cycle AS (
          SELECT DISTINCT src FROM reach WHERE src = dst
        )
        SELECT o.src AS node,
               (SELECT min(o2.src::text) FROM on_cycle o2
                 WHERE EXISTS (SELECT 1 FROM reach r1
                                WHERE r1.src = o.src AND r1.dst = o2.src)
                   AND EXISTS (SELECT 1 FROM reach r2
                                WHERE r2.src = o2.src AND r2.dst = o.src)) AS rep_id
          FROM on_cycle o
      ) rep
     GROUP BY rep.rep_id
    UNION ALL
    -- parent_born_after_child (warning): parent doğum > child doğum; key=<child>:<role>
    SELECT 'parent_born_after_child',
           COALESCE(pnc.farm_animal_id, pnc.id::text) || ':' || pp.parent_role,
           'parent doğum ' || COALESCE(hp.dogum_tarihi, pnp.birth_date)::text
             || ' > child doğum ' || COALESCE(hc.dogum_tarihi, pnc.birth_date)::text
      FROM public.pedigree_parentage pp
      JOIN public.pedigree_nodes pnc
        ON pnc.farm_id = pp.farm_id AND pnc.id = pp.child_node_id
      JOIN public.pedigree_nodes pnp
        ON pnp.farm_id = pp.farm_id AND pnp.id = pp.parent_node_id
      LEFT JOIN public.hayvanlar hc ON hc.id = pnc.farm_animal_id
      LEFT JOIN public.hayvanlar hp ON hp.id = pnp.farm_animal_id
     WHERE pp.farm_id = v_farm
       AND COALESCE(hp.dogum_tarihi, pnp.birth_date) IS NOT NULL
       AND COALESCE(hc.dogum_tarihi, pnc.birth_date) IS NOT NULL
       AND COALESCE(hp.dogum_tarihi, pnp.birth_date)
         > COALESCE(hc.dogum_tarihi, pnc.birth_date)
    UNION ALL
    -- maternal_tarihsel_uyumsuz (blocker): dam var + tarihli ama çocuğun KENDİ
    -- doğum kaydı erken-değil/hiç yok; key=hayvan_id
    SELECT 'maternal_tarihsel_uyumsuz', c.id,
           'anne_id=' || c.anne_id || ' dogum_tarihi=' || c.dogum_tarihi::text
             || ' — çocuğun kendi doğum kaydı yok ya da tarihi geç'
      FROM public.hayvanlar c
     WHERE c.anne_id IS NOT NULL
       AND EXISTS (SELECT 1 FROM public.hayvanlar p WHERE p.id = c.anne_id)
       AND c.dogum_tarihi IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM public.dogum d
                        WHERE d.buzagi_id = c.id
                          AND d.anne_id  = c.anne_id
                          AND d.tarih   <= c.dogum_tarihi)
    UNION ALL
    -- maternal_tarih_bilinmiyor (warning): key=hayvan_id
    SELECT 'maternal_tarih_bilinmiyor', c.id,
           'anne_id dolu, dogum_tarihi NULL — edge yaratılmadı'
      FROM public.hayvanlar c
     WHERE c.anne_id IS NOT NULL AND c.dogum_tarihi IS NULL
    UNION ALL
    -- legacy_anne_graph_dam_celiskisi (warning; r9-F48): hayvanlar.anne_id ile
    -- graph dam edge'i farklı; key=hayvan_id
    SELECT 'legacy_anne_graph_dam_celiskisi', h.id,
           'anne_id=' || h.anne_id || ' graph=' || substring(pp.parent_node_id::text, 1, 8)
      FROM public.hayvanlar h
      JOIN public.pedigree_nodes pnc
        ON pnc.farm_id = v_farm AND pnc.farm_animal_id = h.id
      JOIN public.pedigree_parentage pp
        ON pp.farm_id = v_farm AND pp.child_node_id = pnc.id AND pp.parent_role = 'dam'
      JOIN public.pedigree_nodes pna
        ON pna.farm_id = v_farm AND pna.farm_animal_id = h.anne_id
     WHERE h.anne_id IS NOT NULL
       AND pp.parent_node_id <> pna.id
    UNION ALL
    -- dogum_anne_graph_dam_celiskisi (warning; r8-F44/r12-F66): buzağı node
    -- buzagi_id FK'dan çözülür; key=dogum.id. buzagi_id NULL → bulgu YOK
    -- (o satır dogum_buzagi_missing altında görünür).
    SELECT 'dogum_anne_graph_dam_celiskisi', d.id::text,
           'dogum.anne_id=' || d.anne_id || ' graph=' || substring(pp.parent_node_id::text, 1, 8)
      FROM public.dogum d
      JOIN public.pedigree_nodes pnc
        ON pnc.farm_id = v_farm AND pnc.farm_animal_id = d.buzagi_id
      JOIN public.pedigree_parentage pp
        ON pp.farm_id = v_farm AND pp.child_node_id = pnc.id AND pp.parent_role = 'dam'
      JOIN public.pedigree_nodes pna
        ON pna.farm_id = v_farm AND pna.farm_animal_id = d.anne_id
     WHERE d.buzagi_id IS NOT NULL AND d.anne_id IS NOT NULL
       AND pp.parent_node_id <> pna.id
    UNION ALL
    -- suspiciously_young_parent (warning; r8-F44/r10-F61): 0 <= fark < 548 gün;
    -- negatif fark buraya GİRMEZ (o, parent_born_after_child'in konusu);
    -- key=<child_hayvan_id>:<parent_role>
    SELECT 'suspiciously_young_parent',
           COALESCE(pnc.farm_animal_id, pnc.id::text) || ':' || pp.parent_role,
           'parent ' || pnp.id::text || ' yaşı '
             || (COALESCE(hc.dogum_tarihi, pnc.birth_date)
                 - COALESCE(hp.dogum_tarihi, pnp.birth_date))::text || ' gün'
      FROM public.pedigree_parentage pp
      JOIN public.pedigree_nodes pnc
        ON pnc.farm_id = pp.farm_id AND pnc.id = pp.child_node_id
      JOIN public.pedigree_nodes pnp
        ON pnp.farm_id = pp.farm_id AND pnp.id = pp.parent_node_id
      LEFT JOIN public.hayvanlar hc ON hc.id = pnc.farm_animal_id
      LEFT JOIN public.hayvanlar hp ON hp.id = pnp.farm_animal_id
     WHERE pp.farm_id = v_farm
       AND COALESCE(hc.dogum_tarihi, pnc.birth_date) IS NOT NULL
       AND COALESCE(hp.dogum_tarihi, pnp.birth_date) IS NOT NULL
       AND COALESCE(hc.dogum_tarihi, pnc.birth_date)
         - COALESCE(hp.dogum_tarihi, pnp.birth_date) >= 0
       AND COALESCE(hc.dogum_tarihi, pnc.birth_date)
         - COALESCE(hp.dogum_tarihi, pnp.birth_date) < 548
    UNION ALL
    -- cutoff_invalid (blocker): helper NULL döndü; key="cutoff", detail=ham değer
    SELECT 'cutoff_invalid', 'cutoff',
           'değer timestamptz''e cast edilemedi: ' || v_cutoff_raw
     WHERE v_cutoff_state = 'gecersiz'
    UNION ALL
    -- dogum_buzagi_missing (info): Task 0.5 konservatif backfill eşleşmeyen
    -- legacy satır; key=dogum.id
    SELECT 'dogum_buzagi_missing', d.id::text,
           'tarih=' || d.tarih::text || ' yavru_kupe=' || COALESCE(d.yavru_kupe, 'NULL')
      FROM public.dogum d
     WHERE d.buzagi_id IS NULL
  )
  SELECT COALESCE(jsonb_agg(
           jsonb_build_object('code', g.code, 'severity', s.sev, 'items', g.items)
           ORDER BY s.rank, g.code), '[]'::jsonb)
    INTO v_static_groups
    FROM (
      SELECT code,
             jsonb_agg(jsonb_build_object('key', fkey, 'detail', detail) ORDER BY fkey) AS items
        FROM f
       GROUP BY code
    ) g
    JOIN (VALUES
      ('farm_animal_node_eksik',           'warning', 2),
      ('unresolved_anne_id',               'warning', 2),
      ('unresolved_baba_bilgi',            'info',    3),
      ('child_without_dam',                'warning', 2),
      ('child_without_sire',               'info',    3),
      ('role_sex_contradiction',           'warning', 2),
      ('duplicate_registry',               'blocker', 1),
      ('legacy_semen_no_mapping',          'warning', 2),
      ('cycle_count',                      'blocker', 1),
      ('parent_born_after_child',          'warning', 2),
      ('maternal_tarihsel_uyumsuz',        'blocker', 1),
      ('maternal_tarih_bilinmiyor',        'warning', 2),
      ('legacy_anne_graph_dam_celiskisi',  'warning', 2),
      ('dogum_anne_graph_dam_celiskisi',   'warning', 2),
      ('suspiciously_young_parent',        'warning', 2),
      ('post_cutoff_null_semen',           'blocker', 1),
      ('cutoff_invalid',                   'blocker', 1),
      ('dogum_buzagi_missing',             'info',    3)
    ) s(code, sev, rank) ON s.code = g.code;

  v_groups := v_static_groups;

  -- post_cutoff_null_semen (blocker; r12-F68 ayırım kuralı): yalnız sperma dolu
  -- + semen_id NULL satırlar ihlaldir. Dinamik SQL: kolon Task 10'da iner; kolon
  -- yoksa grup atlanır (cutoff tanimsizken de atlanır — emisyon kuralı).
  IF v_cutoff_state = 'ok' AND v_has_semen_col THEN
    EXECUTE $q$
      SELECT jsonb_build_object('code', 'post_cutoff_null_semen', 'severity', 'blocker',
        'items', jsonb_agg(jsonb_build_object(
                    'key', t.id::text,
                    'detail', 'created_at > cutoff, sperma=' || t.sperma)
                  ORDER BY t.id::text))
        FROM public.tohumlama t
       WHERE t.created_at > $1
         AND t.semen_id IS NULL
         AND t.sperma IS NOT NULL AND btrim(t.sperma) <> ''
    $q$ INTO v_dyn_group USING v_cutoff_ts;
    IF v_dyn_group IS NOT NULL THEN
      v_groups := v_groups || jsonb_build_array(v_dyn_group);
    END IF;
  END IF;

  -- Deterministik sıra: blocker → warning → info, sonra code (dinamik grup da
  -- bu sıraya oturur).
  SELECT COALESCE(jsonb_agg(gr ORDER BY
           CASE gr->>'severity' WHEN 'blocker' THEN 1 WHEN 'warning' THEN 2 ELSE 3 END,
           gr->>'code'), '[]'::jsonb)
    INTO v_ordered
    FROM jsonb_array_elements(v_groups) gr;

  RETURN jsonb_build_object(
    'generated_at', to_char(clock_timestamp() AT TIME ZONE 'UTC',
                            'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'cutoff',       COALESCE(v_cutoff_iso, v_cutoff_state),
    'groups',       v_ordered);
END;
$fn$;

-- Plan 1.3 envanteri: Task 2'nin grant'i BU migration'dadır.
REVOKE ALL ON FUNCTION public.pedigree_integrity_report() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pedigree_integrity_report() TO authenticated;

-- ── Migration uygulaması: backfill'i bir kez koştur (idempotent — replay'te ─
-- 0/0 üretir). Sayaç RAISE NOTICE ile migration log'a düşer.
DO $mig$
DECLARE
  v_r jsonb;
BEGIN
  v_r := public.pedigree_farm_backfill();
  RAISE NOTICE 'pedigree_farm_backfill: %', v_r::text;
END
$mig$;
