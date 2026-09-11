-- 20260911000004_pedigree_projection_rpc.sql davranis testi (Task 3 / gate G3).
-- Demo DB'de guvenlidir: tum test verisi transaction sonunda ROLLBACK edilir.
-- Calistirma: psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/sql/pedigree_projection_rpc_test.sql
-- Hedef dogrulamasi: testten ONCE psql ile $DATABASE_URL'nin demo oldugu gosterilir
-- (teslimat kanitinda: demo project ref vtzqjmazsvurxdeondmi pooler uzerinden;
-- on-kozum: pedigree_nodes=166 / pedigree_parentage=59 — P1 fixture verisi).
--
-- Kapsam (goal G3 + zarf W1 + plan Task 3.3; M-O: zarf W1-fix / luna F3):
--   A guard'lar (NULL/negatif depth, NULL focus), B depth clamp (99→8/3),
--   C focus-only, D unknown parent (founder), E 4-nesil zincir + tam graf
--   truncated=false, F shared ancestor dedup (diamond), G sibling
--   descendants, H max depth truncate (iki yon), I bozuk dongude termination,
--   J same-farm reddi, K for_animal birebir parite + bilinmeyen hayvan,
--   L grants authenticated-only (service_role dahil yok — P1 F5).
--   M-O GERÇEK veri blokları (sentetikten ÖNCE, salt-okunur): canlı boyut
--   alt-sınırı + gerçek odak projeksiyonu + gerçek kardeş/ortak-ata tek düğüm.
--
-- Test grafigi:
--   A4→A3→A2→A1→focus (4 nesil ata zinciri, dam)
--   P1→focus (sire); A2→P1 (dam)  → A2 diamond'da paylasilan ata
--   focus→C1, focus→C2 (dam; sibling descendants); C1→GC (dam; 2. nesil döl)
--   X→Y→X (sire; RPC guard'ini BYPASS eden dogrudan INSERT — bozuk tarihsel
--          dongu; DDL-FK ile kurumsal invaryant disi ama FK-legal)
--   FND (kenarsiz founder), YABANCI (farkli farm node)

BEGIN;

-- ══════════════════════════════════════════════════════════════════════════
-- Gerçek-veri blokları M-O (luna F3 / zarf W1-fix): P1'in canlı demo verisi
-- üzerinde salt-okunur iddialar. Senteitik kurulumdan ÖNCE koşar — filtre
-- gerektirmez. Veri YAZMAZ; BEGIN/ROLLBACK yine de tüm dosyayı sarar.
--   M  canlı graf boyutu + sentetik-olmayan id varlığı
--   N  gerçek odak projeksiyonu (odak sorguyla seçilir — hardcode id YOK)
--   O  gerçek kardeş çifti + ortak ata tek düğüm (id sayımı)
-- ══════════════════════════════════════════════════════════════════════════
DO $real$
DECLARE
  v_m integer; v_n integer;
  v_real_node uuid; v_real_dam uuid;
  v_dam uuid; v_sib1 uuid; v_sib2 uuid;
  v_json jsonb;
BEGIN
  -- ═══ M) Canlı graf boyutu ═══════════════════════════════════════════════
  -- EŞİTLİK DEĞİL ALT-SINIR (>=): demo PAYLAŞIMLI — P1 teslimi 166/59 bıraktı,
  -- başka aktör veri ekleyebilir; eşitlik kırılgan FAIL üretirdi (zarf onayı:
  -- ">= 166 düğüm ve >= 59 kenar" sağlamlaştırması). Radikal silme ihtimaline
  -- karşı alt-sınır yine de G3'ün "P1 verisi üzerinden" ölçütünü korur.
  SELECT count(*) INTO v_m FROM public.pedigree_nodes;
  SELECT count(*) INTO v_n FROM public.pedigree_parentage;
  IF v_m < 166 THEN
    RAISE EXCEPTION 'M1 canlı graf beklenen alt sınırın altında: % node (beklenen >= 166)', v_m;
  END IF;
  IF v_n < 59 THEN
    RAISE EXCEPTION 'M2 canlı kenar sayısı beklenen alt sınırın altında: % (beklenen >= 59)', v_n;
  END IF;
  -- Sentetik-olmayan (P1/backfill kökenli) gerçek id varlığı: sayısal kupe_no
  -- yalnız gerçek demo verisinde var; '__*' test desenleri hariçtir.
  SELECT n.id INTO v_real_node
    FROM public.hayvanlar h
    JOIN public.pedigree_nodes n ON n.farm_animal_id = h.id
   WHERE h.kupe_no ~ '^[0-9]+$'
   LIMIT 1;
  IF v_real_node IS NULL THEN
    RAISE EXCEPTION 'M3 sentetik olmayan gerçek farm node bulunamadi — P1 verisi kaybolmus';
  END IF;

  -- ═══ N) Gerçek odak projeksiyonu (odak sorgulanarak seçilir) ════════════
  -- Odak: sayısal kupe'li gerçek hayvanlar içinde en çok kenarı olan —
  -- hardcode id YOK (id çürüğüne karşı; kupe_no UNIQUE ama değer de
  -- değişebilir → tamamen sorgu-ile seçim).
  SELECT n.id INTO v_real_node
    FROM public.hayvanlar h
    JOIN public.pedigree_nodes n ON n.farm_animal_id = h.id
   WHERE h.kupe_no ~ '^[0-9]+$'
   ORDER BY (SELECT count(*) FROM public.pedigree_parentage pp
              WHERE pp.parent_node_id = n.id) DESC,
            (SELECT count(*) FROM public.pedigree_parentage pp
              WHERE pp.child_node_id = n.id) DESC,
            n.id
   LIMIT 1;
  IF v_real_node IS NULL THEN
    RAISE EXCEPTION 'N1 gerçek odak seçilemedi';
  END IF;

  v_json := public.pedigree_subgraph(v_real_node, 4, 1);
  -- IS DISTINCT FROM (review notu #1): <> NULL-kördür; focus anahtarı
  -- düşerse/regrese olursa sessiz yeşil kalmasın.
  IF v_json->>'focus' IS DISTINCT FROM v_real_node::text THEN
    RAISE EXCEPTION 'N2 gerçek odakta focus anahtarı odak id''si değil: %', v_json->>'focus';
  END IF;
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'nodes') AS nd(value)
   WHERE value->>'id' = v_real_node::text;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'N3 gerçek odak nodes[] içinde tam 1 kez olmalı, eslesen %', v_n;
  END IF;
  -- farm düğüm kontratı: gerçek veride her farm_animal node'unun
  -- farm_animal_id'si dolu (null'suz).
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'nodes') AS nd(value)
   WHERE value->>'kind' = 'farm_animal' AND value->>'farm_animal_id' IS NULL;
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'N4 gerçek veride farm_animal_id NULL olan % farm node var', v_n;
  END IF;
  -- Kenar kapanışı + kontrat: her kenarın İKİ ucu da nodes[] kümesinde
  -- (dangling yok), role/source_type enum içinde (yön parent→child
  -- yapısal: source=parent_node_id, target=child_node_id).
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'edges') AS ed(value)
   WHERE NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_json->'nodes') AS nd(value)
                      WHERE value->>'id' = ed.value->>'source')
      OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_json->'nodes') AS nd(value)
                      WHERE value->>'id' = ed.value->>'target')
      OR ed.value->>'role' NOT IN ('dam','sire')
      OR ed.value->>'source_type' NOT IN ('birth','manual','import','reconcile');
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'N5 gerçek veride % kenar kapanış/enum kontratını bozuyor', v_n;
  END IF;
  -- Clamp uyumu gerçek veride: aşırı istek → meta efektif 8/3.
  v_json := public.pedigree_subgraph(v_real_node, 99, 99);
  IF (v_json->'meta'->>'ancestor_depth')::int <> 8
     OR (v_json->'meta'->>'descendant_depth')::int <> 3 THEN
    RAISE EXCEPTION 'N6 gerçek veride clamp meta 8/3 beklenirdi, gelen %/%',
      v_json->'meta'->>'ancestor_depth', v_json->'meta'->>'descendant_depth';
  END IF;
  -- Ata yönü gerçek veride: parent'ı olan (backfill dam-edge'li) gerçek node
  -- seçilir; (4,0) çağrısı dam'ını nodes[]'ta döndürmeli.
  SELECT pp.child_node_id, pp.parent_node_id INTO v_real_node, v_real_dam
    FROM public.pedigree_parentage pp
    JOIN public.pedigree_nodes n ON n.id = pp.child_node_id
   WHERE n.farm_animal_id IS NOT NULL
     AND pp.parent_role = 'dam'                       -- review notu #2: dam-edge kısıtı
     AND n.farm_id = public.current_farm_id()         -- (multi-farm drift'te doğru hata)
   ORDER BY pp.child_node_id
   LIMIT 1;
  IF v_real_node IS NULL THEN
    RAISE EXCEPTION 'N7 gerçek dam-edge''li node bulunamadi — backfill verisi kaybolmus';
  END IF;
  v_json := public.pedigree_subgraph(v_real_node, 4, 0);
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'nodes') AS nd(value)
   WHERE value->>'id' = v_real_dam::text;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'N8 gerçek odağın dam''ı ata projeksiyonunda yok, eslesen %', v_n;
  END IF;

  -- ═══ O) Gerçek kardeş çifti + ortak ata tek düğüm ═══════════════════════
  -- NOT: gerçek demo verisinde inbred diamond YOKTUR (2026-09-11 ölçümü:
  -- iki parent'ı ortak parent'lı node sayısı 0) — paylaşılan ata iddiası
  -- dam-paylaşımlı kardeş formülasyonuyla kurulur: dam D, kardeşler {s1, s2};
  -- D'nin projeksiyonunda her kardeş tam 1 kez, D→s kenarları ikisi de var.
  SELECT pp1.parent_node_id, pp1.child_node_id, pp2.child_node_id
    INTO v_dam, v_sib1, v_sib2
    FROM public.pedigree_parentage pp1
    JOIN public.pedigree_parentage pp2
      ON pp1.parent_node_id = pp2.parent_node_id
     AND pp1.child_node_id < pp2.child_node_id
   WHERE pp1.parent_role = 'dam' AND pp2.parent_role = 'dam'
   ORDER BY pp1.parent_node_id, pp1.child_node_id, pp2.child_node_id  -- review notu #3: tam determinizm
   LIMIT 1;
  IF v_dam IS NULL THEN
    RAISE EXCEPTION 'O1 gerçek kardeş çifti bulunamadı (dam paylaşımlı) — P1 backfill verisi değişmis';
  END IF;
  v_json := public.pedigree_subgraph(v_dam, 4, 1);
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'nodes') AS nd(value)
   WHERE value->>'id' = v_sib1::text;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'O2 gerçek kardeş s1 projeksiyonda tam 1 kez olmalı, eslesen %', v_n;
  END IF;
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'nodes') AS nd(value)
   WHERE value->>'id' = v_sib2::text;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'O3 gerçek kardeş s2 projeksiyonda tam 1 kez olmalı, eslesen %', v_n;
  END IF;
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'nodes') AS nd(value)
   WHERE value->>'id' = v_dam::text;
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'O4 ortak ata (dam) tam 1 kez listelenmeli, eslesen %', v_n;
  END IF;
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'edges') AS ed(value)
   WHERE ed.value->>'source' = v_dam::text
     AND ed.value->>'target' IN (v_sib1::text, v_sib2::text)
     AND ed.value->>'role' = 'dam';
  IF v_n <> 2 THEN
    RAISE EXCEPTION 'O5 dam→kardeş 2 dam kenarı beklenirdi, eslesen %', v_n;
  END IF;

  RAISE NOTICE 'REALDONE:gerçek-veri blokları M-O yeşil (boyut >=166/>=59, gerçek odak projeksiyonu, kardeş/ortak-ata tek düğüm)';
END;
$real$;

DO $test$
DECLARE
  v_focus_id  text := '__TEST_PED_FOC__';
  v_focus_kupe text := '__PED_T_KUPE136__';  -- kupe_no UNIQUE: demo verisiyle çakışmasın
  v_c1_id     text := '__TEST_PED_C1__';
  v_c2_id     text := '__TEST_PED_C2__';
  v_gc_id     text := '__TEST_PED_GC__';
  v_fnd_id    text := '__TEST_PED_FND__';
  v_ib_id     text := '__TEST_PED_IB__';

  v_focus uuid; v_c1 uuid; v_c2 uuid; v_gc uuid; v_fnd uuid;
  v_a1 uuid; v_a2 uuid; v_a3 uuid; v_a4 uuid; v_p1 uuid;
  v_cx uuid; v_cy uuid; v_yabanci uuid;
  v_ib uuid; v_ib1 uuid; v_ib2 uuid; v_ib3 uuid; v_ib4 uuid;

  v_json jsonb; v_json2 jsonb;
  v_n integer; v_hata text;
BEGIN
  -- Claims mock'u (ev deseni; current_farm_id() Faz 2'ye dek sabittir).
  PERFORM set_config('request.jwt.claims',
    format('{"sub":"%s"}', '99999999-9999-9999-9999-999999999999'), true);

  -- ═══════════ Kurulum: harici ata node'ları + kenarları ═══════════════════
  INSERT INTO public.pedigree_nodes (node_kind, display_name, sex, breed, birth_date)
  VALUES ('external_animal', '__PED_A1__', 'female', 'Montofon', DATE '2020-05-01')
  RETURNING id INTO v_a1;
  INSERT INTO public.pedigree_nodes (node_kind, display_name, sex)
  VALUES ('external_animal', '__PED_A2__', 'female') RETURNING id INTO v_a2;
  INSERT INTO public.pedigree_nodes (node_kind, display_name, sex)
  VALUES ('external_animal', '__PED_A3__', 'female') RETURNING id INTO v_a3;
  INSERT INTO public.pedigree_nodes (node_kind, display_name, sex)
  VALUES ('external_animal', '__PED_A4__', 'female') RETURNING id INTO v_a4;
  INSERT INTO public.pedigree_nodes (node_kind, display_name, sex)
  VALUES ('external_animal', '__PED_P1__', 'male') RETURNING id INTO v_p1;
  INSERT INTO public.pedigree_nodes (node_kind, display_name, sex)
  VALUES ('external_animal', '__PED_CX__', 'male') RETURNING id INTO v_cx;
  INSERT INTO public.pedigree_nodes (node_kind, display_name, sex)
  VALUES ('external_animal', '__PED_CY__', 'male') RETURNING id INTO v_cy;
  INSERT INTO public.pedigree_nodes (farm_id, node_kind, display_name)
  VALUES ('11111111-1111-1111-1111-111111111111', 'external_animal', '__PED_YABANCI__')
  RETURNING id INTO v_yabanci;

  -- Farm node'ları: hayvanlar INSERT trigger'i node yaratir.
  INSERT INTO public.hayvanlar (id, kupe_no, grup, cinsiyet, irk, dogum_tarihi, durum)
  VALUES (v_focus_id, v_focus_kupe, 'Süt İçen Buzağı', 'Dişi', 'Holstein', DATE '2024-01-10', 'Aktif');
  SELECT id INTO STRICT v_focus FROM public.pedigree_nodes WHERE farm_animal_id = v_focus_id;
  INSERT INTO public.hayvanlar (id, kupe_no, grup, cinsiyet, durum)
  VALUES (v_c1_id, v_c1_id, 'Süt İçen Buzağı', 'Dişi', 'Aktif');
  SELECT id INTO STRICT v_c1 FROM public.pedigree_nodes WHERE farm_animal_id = v_c1_id;
  INSERT INTO public.hayvanlar (id, kupe_no, grup, cinsiyet, durum)
  VALUES (v_c2_id, v_c2_id, 'Süt İçen Buzağı', 'Dişi', 'Aktif');
  SELECT id INTO STRICT v_c2 FROM public.pedigree_nodes WHERE farm_animal_id = v_c2_id;
  INSERT INTO public.hayvanlar (id, kupe_no, grup, cinsiyet, durum)
  VALUES (v_gc_id, v_gc_id, 'Süt İçen Buzağı', 'Dişi', 'Aktif');
  SELECT id INTO STRICT v_gc FROM public.pedigree_nodes WHERE farm_animal_id = v_gc_id;
  INSERT INTO public.hayvanlar (id, kupe_no, grup, durum)
  VALUES (v_fnd_id, v_fnd_id, 'Süt İçen Buzağı', 'Aktif');  -- kenarsiz founder
  SELECT id INTO STRICT v_fnd FROM public.pedigree_nodes WHERE farm_animal_id = v_fnd_id;

  -- E5 inbred topolojisi node'ları (harici) + odak çiftliği hayvanı:
  INSERT INTO public.pedigree_nodes (node_kind, display_name, sex)
  VALUES ('external_animal', '__PED_IB1__', 'female') RETURNING id INTO v_ib1;
  INSERT INTO public.pedigree_nodes (node_kind, display_name, sex)
  VALUES ('external_animal', '__PED_IB2__', 'male') RETURNING id INTO v_ib2;
  INSERT INTO public.pedigree_nodes (node_kind, display_name, sex)
  VALUES ('external_animal', '__PED_IB3__', 'female') RETURNING id INTO v_ib3;
  INSERT INTO public.pedigree_nodes (node_kind, display_name, sex)
  VALUES ('external_animal', '__PED_IB4__', 'female') RETURNING id INTO v_ib4;
  INSERT INTO public.hayvanlar (id, kupe_no, grup, durum)
  VALUES (v_ib_id, v_ib_id, 'Süt İçen Buzağı', 'Aktif');
  SELECT id INTO STRICT v_ib FROM public.pedigree_nodes WHERE farm_animal_id = v_ib_id;

  -- Kenarlar (dogrudan INSERT — bu test projection RPC testidir; write yolu
  -- P1 fixture'inda ölçüldü):
  INSERT INTO public.pedigree_parentage (parent_node_id, child_node_id, parent_role, source_type)
  VALUES (v_a4, v_a3, 'dam', 'manual'),
         (v_a3, v_a2, 'dam', 'manual'),
         (v_a2, v_a1, 'dam', 'manual'),
         (v_a1, v_focus, 'dam', 'manual'),
         (v_p1, v_focus, 'sire', 'manual'),
         (v_a2, v_p1, 'dam', 'manual'),
         (v_focus, v_c1, 'dam', 'birth'),
         (v_focus, v_c2, 'dam', 'birth'),
         (v_c1, v_gc, 'dam', 'birth'),
         (v_cx, v_cy, 'sire', 'manual'),
         (v_cy, v_cx, 'sire', 'manual'),
         -- E5 inbred: IB3→IB4 çapraz edge, IB4'ün parent'ını depth-2'de visited kılar
         (v_ib1, v_ib, 'dam', 'manual'),
         (v_ib2, v_ib, 'sire', 'manual'),
         (v_ib3, v_ib1, 'dam', 'manual'),
         (v_ib4, v_ib2, 'dam', 'manual'),
         (v_ib3, v_ib4, 'dam', 'manual');

  -- ═══ A) Guard'lar: NULL/negatif depth, NULL focus ════════════════════════
  v_hata := NULL;
  BEGIN
    v_json := public.pedigree_subgraph(v_focus, -1, 1);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  IF v_hata IS NULL OR v_hata NOT LIKE '%gecersiz ancestor depth%' THEN
    RAISE EXCEPTION 'A1 negatif ancestor depth reddi gelmedi: %', coalesce(v_hata, 'hic hata yok');
  END IF;

  v_hata := NULL;
  BEGIN
    v_json := public.pedigree_subgraph(v_focus, 1, -1);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  IF v_hata IS NULL OR v_hata NOT LIKE '%gecersiz descendant depth%' THEN
    RAISE EXCEPTION 'A2 negatif descendant depth reddi gelmedi: %', coalesce(v_hata, 'hic hata yok');
  END IF;

  v_hata := NULL;
  BEGIN
    v_json := public.pedigree_subgraph(v_focus, NULL, 1);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  IF v_hata IS NULL OR v_hata NOT LIKE '%gecersiz ancestor depth%' THEN
    RAISE EXCEPTION 'A3 NULL depth fail-closed red gelmedi: %', coalesce(v_hata, 'hic hata yok');
  END IF;

  v_hata := NULL;
  BEGIN
    v_json := public.pedigree_subgraph(NULL, 1, 1);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  IF v_hata IS NULL OR v_hata NOT LIKE '%focus node id gerekli%' THEN
    RAISE EXCEPTION 'A4 NULL focus reddi gelmedi: %', coalesce(v_hata, 'hic hata yok');
  END IF;

  -- ═══ B) Depth clamp: 99 → efektif 8/3 (meta yansir) ══════════════════════
  v_json := public.pedigree_subgraph(v_focus, 99, 99);
  IF (v_json->'meta'->>'ancestor_depth')::int <> 8 THEN
    RAISE EXCEPTION 'B1 ancestor clamp 8 beklenirdi, gelen %', v_json->'meta'->>'ancestor_depth';
  END IF;
  IF (v_json->'meta'->>'descendant_depth')::int <> 3 THEN
    RAISE EXCEPTION 'B2 descendant clamp 3 beklenirdi, gelen %', v_json->'meta'->>'descendant_depth';
  END IF;
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'nodes');
  IF v_n <> 9 THEN RAISE EXCEPTION 'B3 clamp sonrasi tam graf 9 node beklenirdi, gelen %', v_n; END IF;

  -- ═══ C) Focus-only (0,0) + farm alan çözümü kontratı ═════════════════════
  -- (0,0) limitinde focus'un parent'ı (ata yönü) VE child'ı (döl yönü)
  -- varken her iki yönde de kesilme olur → truncated=TRUE beklenir (H ile
  -- tutarlı semantik). Kenarsız founder'da ise false'tur (D3 ölçer).
  v_json := public.pedigree_subgraph(v_focus, 0, 0);
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'nodes');
  IF v_n <> 1 THEN RAISE EXCEPTION 'C1 focus-only 1 node beklenirdi, gelen %', v_n; END IF;
  IF jsonb_array_length(v_json->'edges') <> 0 THEN
    RAISE EXCEPTION 'C2 focus-only edges bos olmali';
  END IF;
  IF NOT (v_json->'meta'->>'truncated')::boolean THEN
    RAISE EXCEPTION 'C3 (0,0) limitinde focus''un parent/child''i varken truncated=true beklenirdi';
  END IF;
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'nodes') AS nd(value)
   WHERE value->>'label' = v_focus_kupe AND value->>'kind' = 'farm_animal'
     AND value->>'farm_animal_id' = v_focus_id
     AND value->>'sex' = 'female' AND value->>'breed' = 'Holstein'
     AND value->>'birth_date' = '2024-01-10';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'C4 farm alan cozumu (label=kupe_no, sex=female, breed=Holstein, birth_date) piklenmedi, eslesen %', v_n;
  END IF;

  -- ═══ D) Unknown parent: kenarsiz founder ═════════════════════════════════
  v_json := public.pedigree_subgraph(v_fnd, 4, 1);
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'nodes');
  IF v_n <> 1 THEN RAISE EXCEPTION 'D1 founder 1 node beklenirdi, gelen %', v_n; END IF;
  IF jsonb_array_length(v_json->'edges') <> 0 THEN
    RAISE EXCEPTION 'D2 founder edges bos olmali';
  END IF;
  IF (v_json->'meta'->>'truncated')::boolean THEN
    RAISE EXCEPTION 'D3 kenarsiz founder truncated=false beklenirdi';
  END IF;

  -- ═══ E) 4-nesil zincir + tam graf: (4,2) truncated=false ═════════════════
  v_json := public.pedigree_subgraph(v_focus, 4, 2);
  IF (v_json->'meta'->>'ancestor_depth')::int <> 4
     OR (v_json->'meta'->>'descendant_depth')::int <> 2 THEN
    RAISE EXCEPTION 'E1 meta efektif depth 4/2 beklenirdi, gelen %/%',
      v_json->'meta'->>'ancestor_depth', v_json->'meta'->>'descendant_depth';
  END IF;
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'nodes');
  IF v_n <> 9 THEN RAISE EXCEPTION 'E2 tam graf 9 node (focus+A1-4+P1+C1,C2,GC) beklenirdi, gelen %', v_n; END IF;
  IF jsonb_array_length(v_json->'edges') <> 9 THEN
    RAISE EXCEPTION 'E3 tam graf 9 edge beklenirdi, gelen %', jsonb_array_length(v_json->'edges');
  END IF;
  IF (v_json->'meta'->>'truncated')::boolean THEN
    RAISE EXCEPTION 'E4 tam graf kapsandiginda truncated=false beklenirdi';
  END IF;

  -- E5 (review bulgusu #1): inbred DAG — reviewer topolojisi birebir:
  --   IB1→IB (dam), IB2→IB (sire); IB3→IB1 (dam); IB4→IB2 (dam);
  --   IB3→IB4 (dam — çapraz edge: IB4'ün parent'ı IB3, depth-2 limitinde
  --   IB3 BAŞKA YOLDAN visited).
  -- (2,0)'da depth-2 node'ları {IB3, IB4}; IB3 parent'sız, IB4'ün tek
  -- parent'ı visited → ata kapanışı TAM: truncated=false olmalı. "Sınır
  -- edge'i var" ≠ "gezilmemiş komşu var"; aksi halde tam kapsanan inbred
  -- graf false-positive verir (W3 boşuna 'daha fazla kuşak' basar).
  v_json := public.pedigree_subgraph(v_ib, 2, 0);
  IF (v_json->'meta'->>'truncated')::boolean THEN
    RAISE EXCEPTION 'E5 inbred DAG''de tam ata kapanışında truncated=false beklenirdi (IB4''ün tek parent''ı IB3 visited)';
  END IF;
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'nodes');
  IF v_n <> 5 THEN RAISE EXCEPTION 'E5b inbred (2,0) 5 node beklenirdi, gelen %', v_n; END IF;
  IF jsonb_array_length(v_json->'edges') <> 5 THEN
    RAISE EXCEPTION 'E5c inbred 5 edge beklenirdi, gelen %', jsonb_array_length(v_json->'edges');
  END IF;

  -- E6 (review bulgusu #3): external_animal alan çözümü — kendi kolonlarından
  -- passthrough + farm_animal_id NULL kontratı (tam graf çağrısında).
  v_json := public.pedigree_subgraph(v_focus, 4, 2);
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'nodes') AS nd(value)
   WHERE value->>'label' = '__PED_A1__' AND value->>'kind' = 'external_animal'
     AND value->>'farm_animal_id' IS NULL
     AND value->>'sex' = 'female' AND value->>'breed' = 'Montofon'
     AND value->>'birth_date' = '2020-05-01';
  IF v_n <> 1 THEN
    RAISE EXCEPTION 'E6 external alan cozumu (label/sex/breed/birth_date kendi kolonlarindan, farm_animal_id null) piklenmedi, eslesen %', v_n;
  END IF;

  -- E7 (review bulgusu #4): anahtar-set kontratı — W3 birebir kodluyor;
  -- key adı/adedi kayması yeşile bırakılmaz.
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'nodes') AS nd(value)
   WHERE (SELECT count(*) FROM jsonb_object_keys(value)) <> 7
      OR NOT value ? 'id' OR NOT value ? 'kind' OR NOT value ? 'farm_animal_id'
      OR NOT value ? 'label' OR NOT value ? 'sex' OR NOT value ? 'breed'
      OR NOT value ? 'birth_date';
  IF v_n <> 0 THEN RAISE EXCEPTION 'E7 node anahtar seti 7 degil (id,kind,farm_animal_id,label,sex,breed,birth_date), bozuk % satir', v_n; END IF;
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'edges') AS ed(value)
   WHERE (SELECT count(*) FROM jsonb_object_keys(value)) <> 5
      OR NOT value ? 'id' OR NOT value ? 'source' OR NOT value ? 'target'
      OR NOT value ? 'role' OR NOT value ? 'source_type';
  IF v_n <> 0 THEN RAISE EXCEPTION 'E7b edge anahtar seti 5 degil (id,source,target,role,source_type), bozuk % satir', v_n; END IF;
  IF (SELECT count(*) FROM jsonb_object_keys(v_json->'meta')) <> 3
     OR NOT (v_json->'meta') ? 'ancestor_depth'
     OR NOT (v_json->'meta') ? 'descendant_depth'
     OR NOT (v_json->'meta') ? 'truncated' THEN
    RAISE EXCEPTION 'E7c meta anahtar seti 3 degil (ancestor_depth,descendant_depth,truncated)';
  END IF;
  IF v_json->>'focus' <> v_focus::text THEN
    RAISE EXCEPTION 'E7d focus anahtari focus node id''si degil: %', v_json->>'focus';
  END IF;
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'edges') AS ed(value)
   WHERE value->>'target' = v_focus::text AND value->>'role' = 'dam'
     AND value->>'source_type' = 'manual';
  IF v_n <> 1 THEN RAISE EXCEPTION 'E7e A1→focus dam/manual edge''i hedef/rol/source_type ile bulunamadi, eslesen %', v_n; END IF;

  -- ═══ F) Shared ancestor dedup: A2 hem A1'in hem P1'in dam'i ══════════════
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'nodes')
   WHERE value->>'label' = '__PED_A2__';
  IF v_n <> 1 THEN RAISE EXCEPTION 'F1 paylasilan ata A2 tam 1 kez listelenmeli, gelen %', v_n; END IF;
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'edges')
   WHERE value->>'source' = v_a2::text;
  IF v_n <> 2 THEN RAISE EXCEPTION 'F2 A2''nin iki dam edge''i (A1,P1) listelenmeli, gelen %', v_n; END IF;

  -- ═══ G) Sibling descendants: C1+C2 kardes, GC 2. nesil ═══════════════════
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'nodes')
   WHERE value->>'label' IN (v_c1_id, v_c2_id, v_gc_id);
  IF v_n <> 3 THEN RAISE EXCEPTION 'G1 iki kardes döl + torun listelenmeli, gelen %', v_n; END IF;

  -- Default descendant depth 1: GC yok, truncated=true (C1'in devami var)
  v_json := public.pedigree_subgraph(v_focus, 4, 1);
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'nodes')
   WHERE value->>'label' = v_gc_id;
  IF v_n <> 0 THEN RAISE EXCEPTION 'G2 default desc depth 1''de torun GC listelenmamali'; END IF;
  -- G2b (review bulgusu #2): GC nodes[]'ta yokken C1→GC edge'i de SIZMAMALI
  -- (dangling edge yasağı — iki uçlu kapanış).
  IF jsonb_array_length(v_json->'edges') <> 8 THEN
    RAISE EXCEPTION 'G2b (4,1) 8 edge beklenirdi (9 - C1→GC), gelen %', jsonb_array_length(v_json->'edges');
  END IF;
  IF NOT (v_json->'meta'->>'truncated')::boolean THEN
    RAISE EXCEPTION 'G3 limit 1''de C1''in devami varken truncated=true beklenirdi';
  END IF;

  -- ═══ H) Max depth truncate (iki yon) ═════════════════════════════════════
  v_json := public.pedigree_subgraph(v_focus, 1, 0);
  IF NOT (v_json->'meta'->>'truncated')::boolean THEN
    RAISE EXCEPTION 'H1 ata limiti 1''de A1''in parent''i varken truncated=true beklenirdi';
  END IF;
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'nodes');
  IF v_n <> 3 THEN RAISE EXCEPTION 'H2 (1,0) focus+A1+P1=3 node beklenirdi, gelen %', v_n; END IF;

  -- ═══ I) Bozuk dongude termination: X→Y→X ═════════════════════════════════
  v_json := public.pedigree_subgraph(v_cx, 4, 0);
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json->'nodes');
  IF v_n <> 2 THEN RAISE EXCEPTION 'I1 dongu node''lari 2 (CX,CY) beklenirdi, gelen %', v_n; END IF;
  IF jsonb_array_length(v_json->'edges') <> 2 THEN
    RAISE EXCEPTION 'I2 dongu 2 edge beklenirdi, gelen %', jsonb_array_length(v_json->'edges');
  END IF;
  v_json2 := public.pedigree_subgraph(v_cy, 4, 0);
  SELECT count(*) INTO v_n FROM jsonb_array_elements(v_json2->'nodes');
  IF v_n <> 2 THEN RAISE EXCEPTION 'I3 ters dongu de sonlanmali (CY focus), gelen %', v_n; END IF;

  -- ═══ J) Same-farm guard: yabanci farm focus'u ════════════════════════════
  v_hata := NULL;
  BEGIN
    v_json := public.pedigree_subgraph(v_yabanci, 4, 1);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  IF v_hata IS NULL OR v_hata NOT LIKE '%bulunamadi ya da farkli farm%' THEN
    RAISE EXCEPTION 'J1 yabanci farm focus reddi gelmedi: %', coalesce(v_hata, 'hic hata yok');
  END IF;

  -- ═══ K) for_animal: node-id cagrisiyla BIREBIR parite ════════════════════
  v_json  := public.pedigree_subgraph(v_focus, 4, 2);
  v_json2 := public.pedigree_subgraph_for_animal(v_focus_id, 4, 2);
  IF v_json IS DISTINCT FROM v_json2 THEN
    RAISE EXCEPTION 'K1 for_animal sonucu node-id cagrisindan farkli: % vs %', v_json, v_json2;
  END IF;

  v_hata := NULL;
  BEGIN
    v_json := public.pedigree_subgraph_for_animal('__TEST_PED_YOK__', 4, 1);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  IF v_hata IS NULL OR v_hata NOT LIKE '%bulunamadi%' THEN
    RAISE EXCEPTION 'K2 bilinmeyen hayvan id reddi gelmedi: %', coalesce(v_hata, 'hic hata yok');
  END IF;

  v_hata := NULL;
  BEGIN
    v_json := public.pedigree_subgraph_for_animal(NULL, 4, 1);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  IF v_hata IS NULL OR v_hata NOT LIKE '%hayvan id gerekli%' THEN
    RAISE EXCEPTION 'K3 NULL hayvan id reddi gelmedi: %', coalesce(v_hata, 'hic hata yok');
  END IF;

  -- ═══ L) Grants: authenticated-only, service_role dahil (P1 F5) ═══════════
  IF NOT has_function_privilege('authenticated',
       'public.pedigree_subgraph(uuid,integer,integer)', 'EXECUTE') THEN
    RAISE EXCEPTION 'L1 authenticated subgraph EXECUTE yok';
  END IF;
  IF has_function_privilege('anon',
       'public.pedigree_subgraph(uuid,integer,integer)', 'EXECUTE') THEN
    RAISE EXCEPTION 'L2 anon subgraph EXECUTE almis';
  END IF;
  IF has_function_privilege('service_role',
       'public.pedigree_subgraph(uuid,integer,integer)', 'EXECUTE') THEN
    RAISE EXCEPTION 'L3 service_role subgraph EXECUTE almis (F5 ihlali)';
  END IF;
  IF NOT has_function_privilege('authenticated',
       'public.pedigree_subgraph_for_animal(text,integer,integer)', 'EXECUTE') THEN
    RAISE EXCEPTION 'L4 authenticated for_animal EXECUTE yok';
  END IF;
  IF has_function_privilege('anon',
       'public.pedigree_subgraph_for_animal(text,integer,integer)', 'EXECUTE') THEN
    RAISE EXCEPTION 'L5 anon for_animal EXECUTE almis';
  END IF;
  IF has_function_privilege('service_role',
       'public.pedigree_subgraph_for_animal(text,integer,integer)', 'EXECUTE') THEN
    RAISE EXCEPTION 'L6 service_role for_animal EXECUTE almis (F5 ihlali)';
  END IF;

  RAISE NOTICE 'TESTDONE:pedigree_projection_rpc_test tamam — gerçek-veri M-O + sentetik A-L toplam 15 blok yesil';
END;
$test$;

ROLLBACK;
