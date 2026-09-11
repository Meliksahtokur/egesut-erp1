-- ============================================================================
-- Migration: 20260911000004_pedigree_projection_rpc (Task 3 / P2 — gate G3)
-- Tarih: 2026-09-11
-- Otorite: .claude/plans/2026-09-10-pedigree-genetics-impl.md Rev 3.1 L921-1002
--          (Task 3) + zarf .claude/tasks/2026-09-11-pedigree-p2-W1.md.
--          Çelişkide goal (G-20260911-PEDIGREE-P2-AGAC) kazanır.
--
-- B1 DÜZELTMESİ (lead kapı bulgusu): planın literal adı "20260910000003_..."
-- ÇAKIŞIYORDU — P1 fiilen 20260911000002 (foundation) + 20260911000003
-- (farm_backfill) attı; planın adı sözcüksel sıralamada foundation'dan önce
-- düşer. Bu dosya 20260911000004 sırasındadır.
--
-- Kapsam: SALT-OKUNUR 2 projection RPC. Tablo/RLS/index DEĞİŞİKLİĞİ YOK.
--
-- Dönüş kontratı (W3 buna karşı kodlar — BİREBİR; anahtar seti artırılmaz):
--   { focus: uuid,
--     nodes: [{id, kind: farm_animal|external_animal,
--              farm_animal_id: <hayvanlar.id|null>, label, sex, breed,
--              birth_date}],
--     edges: [{id, source(parent), target(child), role: dam|sire,
--              source_type: birth|manual|import|reconcile}],
--     meta:  {ancestor_depth, descendant_depth, truncated} }
--
-- Alan çözümü (zarf: farm alanları hayvanlar'dan resolve, external kendi
-- alanından; canlı ölçüm — hayvanlar'da isim kolonu yoktur, kupe_no etikettir):
--   farm_animal     : label=COALESCE(hayvanlar.kupe_no, node.display_name,
--                                     farm_animal_id, id::text)
--                     sex=normalize(cinsiyet: 'Erkek'→male, 'Dişi'→female,
--                                   bilinmeyen→node.sex)
--                     breed=COALESCE(hayvanlar.irk, node.breed)
--                     birth_date=COALESCE(hayvanlar.dogum_tarihi, node.birth_date)
--   external_animal : label=COALESCE(display_name, registry_code, id::text)
--                     sex/breed/birth_date node'un kendi alanlarından.
--   (Node LEFT JOIN ile çekilir: hayvanlar satırı yoksa node nodes[]'dan
--    DÜŞMEZ — dangling nodes üretme yasağı.)
--
-- Guard'lar (plan 3.1):
--   - NULL/negatif depth reddi (fail-closed; NULL açık çağrı da red —
--     LEAST NULL'u yutmaz diye varsayma).
--   - max ancestor 8 / max descendant 3: CLAMP (red değil); meta CLAMP'LENMİŞ
--     EFEKTİF değerleri taşır (goal G3: "effective_depth yanıtta" — meta
--     ancestor_depth/descendant_depth alanları bu efektif değerlerdir).
--   - same-farm check: focus node current_farm_id()'de değilse red.
--   - recursive CTE path uuid[] cycle guard: bozuk tarihsel döngüde bile
--     sonlanır (döngü verisi DDL-FK ile imkânsızdır; guard savunma derinliğidir).
--
-- Semantik kararları (fixture testleri ölçer):
--   - visited kümesi = focus + N ata + M döl; MIN-depth ile dedup (shared
--     ancestor diamond'da tek node).
--   - edges = İKİ ucu da visited kümesinde olan parentage satırları (dangling
--     edge yasak: dış parent — ör. torunun kayınpederi — nodes[]'a girmeden
--     edge üretilmez).
--   - truncated = limit derinliğinde durmuş bir visited node'un hâlâ
--     gezilmemiş parent (ata yönü) / child (döl yönü) edge'i varsa true.
--     Grafiğin limitten önce tükendiği yönde false.
--
-- Replay-safe: yalnız CREATE OR REPLACE + grant; ikinci koşum no-op.
-- Grant disiplini (P1 F5 dersi): authenticated-only, AYNI migration'da;
-- service_role'a EXECUTE YOK.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.pedigree_subgraph(
  p_focus_node_id    uuid,
  p_ancestor_depth   integer DEFAULT 4,
  p_descendant_depth integer DEFAULT 1
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE
  v_farm   uuid := public.current_farm_id();
  v_focus  uuid;
  v_anc    integer;
  v_desc   integer;
  v_result jsonb;
BEGIN
  -- ── Guard'lar: parametreler önce (deterministik hata önceliği) ───────────
  IF p_focus_node_id IS NULL THEN
    RAISE EXCEPTION 'focus node id gerekli';
  END IF;
  IF p_ancestor_depth IS NULL OR p_ancestor_depth < 0 THEN
    RAISE EXCEPTION 'gecersiz ancestor depth (NULL/negatif reddedilir): %', p_ancestor_depth;
  END IF;
  IF p_descendant_depth IS NULL OR p_descendant_depth < 0 THEN
    RAISE EXCEPTION 'gecersiz descendant depth (NULL/negatif reddedilir): %', p_descendant_depth;
  END IF;

  -- Clamp (red değil): MVP üst sınırlar — meta efektif değeri taşır.
  v_anc  := LEAST(p_ancestor_depth, 8);
  v_desc := LEAST(p_descendant_depth, 3);

  -- Same-farm check: focus bu farm'da olmalı.
  SELECT id INTO v_focus
    FROM public.pedigree_nodes
   WHERE farm_id = v_farm AND id = p_focus_node_id;
  IF v_focus IS NULL THEN
    RAISE EXCEPTION 'focus node bulunamadi ya da farkli farm: %', p_focus_node_id;
  END IF;

  -- ── Traversal: recursive CTE + path uuid[] cycle guard ──────────────────
  WITH RECURSIVE anc AS (
    SELECT pp.parent_node_id AS node_id, 1 AS depth,
           ARRAY[pp.parent_node_id]::uuid[] AS path
      FROM public.pedigree_parentage pp
     WHERE pp.farm_id = v_farm
       AND pp.child_node_id = v_focus
       AND v_anc >= 1
    UNION ALL
    SELECT pp.parent_node_id, a.depth + 1, a.path || pp.parent_node_id
      FROM public.pedigree_parentage pp
      JOIN anc a ON pp.child_node_id = a.node_id
     WHERE pp.farm_id = v_farm
       AND a.depth < v_anc
       AND NOT (pp.parent_node_id = ANY(a.path))
  ),
  desc_ AS (
    SELECT pp.child_node_id AS node_id, 1 AS depth,
           ARRAY[pp.child_node_id]::uuid[] AS path
      FROM public.pedigree_parentage pp
     WHERE pp.farm_id = v_farm
       AND pp.parent_node_id = v_focus
       AND v_desc >= 1
    UNION ALL
    SELECT pp.child_node_id, d.depth + 1, d.path || pp.child_node_id
      FROM public.pedigree_parentage pp
      JOIN desc_ d ON pp.parent_node_id = d.node_id
     WHERE pp.farm_id = v_farm
       AND d.depth < v_desc
       AND NOT (pp.child_node_id = ANY(d.path))
  ),
  visited AS (
    -- side: truncation kontrolü yön-bazlıdır — ata yönünde derinlik 2'de
    -- durmuş bir node (limit 4), döl yönü limitinde durmuş SANILMAMALI
    -- (ölçüldü: E4 kırmızısı — diamond paylaşılan atası iki yönün
    -- derinlik havuzuna karışıyordu).
    SELECT v_focus AS node_id, 0 AS depth, 'anc' AS side
    UNION ALL SELECT v_focus, 0, 'desc'
    UNION ALL SELECT node_id, depth, 'anc' FROM anc
    UNION ALL SELECT node_id, depth, 'desc' FROM desc_
  ),
  visited_min AS (
    SELECT node_id, MIN(depth) AS depth FROM visited GROUP BY node_id
  ),
  visited_min_side AS (
    SELECT node_id, side, MIN(depth) AS depth FROM visited GROUP BY node_id, side
  ),
  nodes_json AS (
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', n.id,
        'kind', n.node_kind,
        'farm_animal_id', n.farm_animal_id,
        'label', CASE WHEN n.node_kind = 'farm_animal'
                      THEN COALESCE(h.kupe_no, n.display_name, n.farm_animal_id, n.id::text)
                      ELSE COALESCE(n.display_name, n.registry_code, n.id::text) END,
        'sex', CASE WHEN n.node_kind = 'farm_animal'
                    THEN COALESCE(CASE h.cinsiyet WHEN 'Erkek' THEN 'male'
                                                  WHEN 'Dişi'  THEN 'female' END, n.sex)
                    ELSE n.sex END,
        'breed', CASE WHEN n.node_kind = 'farm_animal'
                      THEN COALESCE(h.irk, n.breed) ELSE n.breed END,
        'birth_date', CASE WHEN n.node_kind = 'farm_animal'
                           THEN COALESCE(h.dogum_tarihi, n.birth_date)
                           ELSE n.birth_date END
      ) ORDER BY n.id) AS j
      FROM visited_min vm
      JOIN public.pedigree_nodes n ON n.farm_id = v_farm AND n.id = vm.node_id
      LEFT JOIN public.hayvanlar h ON h.id = n.farm_animal_id
  ),
  edges_json AS (
    SELECT jsonb_agg(
      jsonb_build_object(
        'id', pp.id,
        'source', pp.parent_node_id,
        'target', pp.child_node_id,
        'role', pp.parent_role,
        'source_type', pp.source_type
      ) ORDER BY pp.id) AS j
      FROM public.pedigree_parentage pp
     WHERE pp.farm_id = v_farm
       AND EXISTS (SELECT 1 FROM visited_min vp WHERE vp.node_id = pp.parent_node_id)
       AND EXISTS (SELECT 1 FROM visited_min vc WHERE vc.node_id = pp.child_node_id)
  ),
  trunc_anc AS (
    SELECT EXISTS (
      SELECT 1
        FROM visited_min_side vm
        JOIN public.pedigree_parentage pp
          ON pp.farm_id = v_farm AND pp.child_node_id = vm.node_id
       WHERE vm.side = 'anc' AND vm.depth = v_anc
         -- Review bulgusu #1 (ölçüldü: E5 kırmızısı): "sınır edge'i var" ≠
         -- "gezilmemiş komşu var". Limit derinliğindeki node'un komşusu
         -- ZATEN visited ise kapanış tamdır → flag YOK (inbred DAG
         -- false-pozitifi: tam kapsanan graf 'daha fazla kuşak' der).
         AND NOT EXISTS (SELECT 1 FROM visited_min v2
                          WHERE v2.node_id = pp.parent_node_id)
    ) AS t
  ),
  trunc_desc AS (
    SELECT EXISTS (
      SELECT 1
        FROM visited_min_side vm
        JOIN public.pedigree_parentage pp
          ON pp.farm_id = v_farm AND pp.parent_node_id = vm.node_id
       WHERE vm.side = 'desc' AND vm.depth = v_desc
         AND NOT EXISTS (SELECT 1 FROM visited_min v2
                          WHERE v2.node_id = pp.child_node_id)
    ) AS t
  )
  SELECT jsonb_build_object(
    'focus', v_focus,
    'nodes', COALESCE((SELECT j FROM nodes_json), '[]'::jsonb),
    'edges', COALESCE((SELECT j FROM edges_json), '[]'::jsonb),
    'meta', jsonb_build_object(
      'ancestor_depth', v_anc,
      'descendant_depth', v_desc,
      'truncated', (SELECT t FROM trunc_anc) OR (SELECT t FROM trunc_desc))
  )
  INTO v_result;

  RETURN v_result;
END;
$fn$;

CREATE OR REPLACE FUNCTION public.pedigree_subgraph_for_animal(
  p_hayvan_id        text,
  p_ancestor_depth   integer DEFAULT 4,
  p_descendant_depth integer DEFAULT 1
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $fn$
DECLARE
  v_node uuid;
BEGIN
  IF p_hayvan_id IS NULL THEN
    RAISE EXCEPTION 'hayvan id gerekli';
  END IF;
  SELECT id INTO v_node
    FROM public.pedigree_nodes
   WHERE farm_id = public.current_farm_id() AND farm_animal_id = p_hayvan_id;
  IF v_node IS NULL THEN
    RAISE EXCEPTION 'hayvan icin pedigree node bulunamadi ya da farkli farm: %', p_hayvan_id;
  END IF;
  RETURN public.pedigree_subgraph(v_node, p_ancestor_depth, p_descendant_depth);
END;
$fn$;

-- ── Grant'lar (P1 F5: authenticated-only, AYNI migration'da; service_role'a
--    EXECUTE YOK — default ACL yeni fonksiyona service_role=X veriyor) ──────

REVOKE ALL ON FUNCTION public.pedigree_subgraph(uuid, integer, integer)
  FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.pedigree_subgraph(uuid, integer, integer)
  TO authenticated;

REVOKE ALL ON FUNCTION public.pedigree_subgraph_for_animal(text, integer, integer)
  FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.pedigree_subgraph_for_animal(text, integer, integer)
  TO authenticated;
