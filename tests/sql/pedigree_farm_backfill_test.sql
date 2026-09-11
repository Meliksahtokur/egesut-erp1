-- 20260911000003_pedigree_farm_backfill.sql davranis testi (Task 2 / gate G2).
-- Demo DB'de guvenlidir: tum test verisi transaction sonunda ROLLBACK edilir.
-- Calistirma: psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/sql/pedigree_farm_backfill_test.sql
-- Hedef dogrulamasi: testten ONCE psql ile $DATABASE_URL'nin demo oldugu gosterilir
-- (teslimat kanitinda: demo project ref vtzqjmazsvurxdeondmi pooler uzerinden).
--
-- Kapsam (goal G2 + plan Task 2.1-2.4):
--   2.1/2.2 farm node + maternal edge backfill, buzagi_id FK predicate,
--           source_type='reconcile', confidence=1
--   2.3     pedigree_integrity_report() — 18-kod evreni, emisyon kurallari
--           (bos grup emit edilmez; cutoff tanimsiz → post_cutoff atlanir;
--           gecersiz cutoff → cutoff_invalid blocker; r12-F68 ayrim kurali),
--           yanit kontrati (tek JSON, key kimlik)
--   2.4     idempotency — ikinci kosum 0 node / 0 edge
--   G2      "blockers==0 with fixture data" → Faz A temiz fixture +1 blocker
--           üretmez (delta B0'a karsi); gercek demo verisinin kendi bulgulari
--           (maternal_tarihsel_uyumsuz x2, 2026-09-11 olcumu) raporun KONUSU-
--           dur, test delta yontemiyle fixture katkisini izole eder.
--
-- Yontem notu: rapor GERCEK demo verisini de tarar (166 hayvan). Bu yuzden
-- tum grup iddialari fixture-anahtarina gore (sentinel '__TEST_BF_*__') ya da
-- delta ile yapilir; mutlak sayim iddiasi yoktur.

BEGIN;

-- ── pg_temp yardimcilar (transaction sonunda yok olur) ───────────────────
CREATE FUNCTION pg_temp.bf_has_group(p_report jsonb, p_code text)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM jsonb_array_elements(p_report->'groups') g
                  WHERE g->>'code' = p_code);
$$;

CREATE FUNCTION pg_temp.bf_has_key(p_report jsonb, p_code text, p_key text)
RETURNS boolean LANGUAGE sql STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM jsonb_array_elements(p_report->'groups') g,
                        jsonb_array_elements(g->'items') it
                  WHERE g->>'code' = p_code AND it->>'key' = p_key);
$$;

CREATE FUNCTION pg_temp.bf_blocker_count(p_report jsonb)
RETURNS integer LANGUAGE sql STABLE AS $$
  SELECT COALESCE(sum(jsonb_array_length(g->'items')), 0)::integer
    FROM jsonb_array_elements(p_report->'groups') g
   WHERE g->>'severity' = 'blocker';
$$;

CREATE FUNCTION pg_temp.bf_group_keys(p_report jsonb, p_code text)
RETURNS text[] LANGUAGE sql STABLE AS $$
  SELECT COALESCE(array_agg(it->>'key'), '{}'::text[])
    FROM jsonb_array_elements(p_report->'groups') g,
         jsonb_array_elements(g->'items') it
   WHERE g->>'code' = p_code;
$$;

DO $test$
DECLARE
  -- ── fixture kimlikleri ────────────────────────────────────────────────
  v_anne   text := '__TEST_BF_ANNE1__';   -- temiz dam
  v_calf   text := '__TEST_BF_CUFC1__';   -- GUVENLI satir (S8 predikati)
  v_mism   text := '__TEST_BF_MISMAT__';  -- dogum kaydi tarihi gec → uyumsuz
  v_nodg   text := '__TEST_BF_NODGUM__';  -- kendi dogum kaydi YOK → uyumsuz
  v_tarih  text := '__TEST_BF_TARIHSZ__'; -- dogum_tarihi NULL → tarih bilinmiyor
  v_unres  text := '__TEST_BF_UNRESOL__'; -- anne_id cozulmuyor
  v_z      text := '__TEST_BF_DOGUMZ__';  -- dogum_anne celiski senaryosu
  v_anne2  text := '__TEST_BF_ANNE2__';
  v_anne3  text := '__TEST_BF_ANNE3__';
  v_sapma1 text := '__TEST_BF_SAPMA1__';
  v_sapma2 text := '__TEST_BF_SAPMA2__';
  v_cyc1   text := '__TEST_BF_CYC1__';
  v_cyc2   text := '__TEST_BF_CYC2__';
  v_erkek  text := '__TEST_BF_ERKEK__';
  v_rc     text := '__TEST_BF_RCC__';     -- role_sex_contradiction child
  v_k1     text := '__TEST_BF_K1__';      -- parent dogum > child dogum
  v_k2     text := '__TEST_BF_K2__';      -- suspiciously young (111 gun)
  v_k3     text := '__TEST_BF_K3__';      -- fark > 548 gun → iki grupta da yok
  v_p1     text := '__TEST_BF_P1__';
  v_p2     text := '__TEST_BF_P2__';
  v_p3     text := '__TEST_BF_P3__';
  v_y1     text := '__TEST_BF_Y1__';      -- 1 yas ustu, dam edge yok
  v_y2     text := '__TEST_BF_Y2__';      -- 1 yas alti → child_without_dam YOK
  v_nd     text := '__TEST_BF_NODEDEL__'; -- node'u silinir → node_eksik
  v_baba   text := '__TEST_BF_BABA__';    -- baba_bilgi dolu; map tablosu YOK

  v_node_calf uuid; v_node_anne uuid; v_node_z uuid; v_node_cyc1 uuid;
  v_node_cyc2 uuid; v_node_erkek uuid; v_node_rc uuid;
  v_dz uuid := gen_random_uuid(); v_dw uuid := gen_random_uuid();
  v_edge uuid; v_tmp uuid; v_j jsonb;
  v_b0 integer; v_b integer; v_r jsonb; v_r1 jsonb;
  v_c1 jsonb; v_c2 jsonb; v_c3 jsonb; v_c4 jsonb;
  v_n integer; v_e integer; v_hata text; v_keys text[];
  v_real_pc integer; v_semcol boolean;
  v_st text; v_conf numeric; v_par uuid; v_sref text;
  r2 record;
BEGIN

  -- ═══ FAZ 0) Rapor sekli + baseline snapshot ═══════════════════════════
  v_r := public.pedigree_integrity_report();

  -- Yanit kontrati (r5-F28): TEK jsonb, tam olarak 3 ust anahtar
  IF v_r IS NULL OR NOT (v_r ? 'generated_at' AND v_r ? 'cutoff' AND v_r ? 'groups') THEN
    RAISE EXCEPTION 'F0: yanit kontrati bozuk: %', COALESCE(v_r::text, 'NULL');
  END IF;
  SELECT count(*) INTO v_n FROM jsonb_object_keys(v_r) k;
  IF v_n <> 3 THEN
    RAISE EXCEPTION 'F0: ust anahtar sayisi 3 olmali, %', v_n;
  END IF;
  IF v_r->>'generated_at' !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$' THEN
    RAISE EXCEPTION 'F0: generated_at ISO degil: %', v_r->>'generated_at';
  END IF;
  -- Emisyon kurali (a): bulgusu olmayan grup emit edilmez — her grubun items'i
  -- GERCEK dizi olmali (bos dizi VE items:null F1 dersinden ikisi de red)
  SELECT count(*) INTO v_n
    FROM jsonb_array_elements(v_r->'groups') g
   WHERE jsonb_typeof(g->'items') <> 'array';
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'F0: % grubun items''i dizi degil (bos/null emit — kural a ihlali)', v_n;
  END IF;
  -- Demo baseline: cutoff anahtari YOK → 'tanimsiz', post_cutoff + cutoff_invalid yok
  IF v_r->>'cutoff' IS DISTINCT FROM 'tanimsiz' THEN
    RAISE EXCEPTION 'F0: demo cutoff beklenen tanimsiz, gelen %', v_r->>'cutoff';
  END IF;
  IF pg_temp.bf_has_group(v_r, 'post_cutoff_null_semen')
     OR pg_temp.bf_has_group(v_r, 'cutoff_invalid') THEN
    RAISE EXCEPTION 'F0: cutoff tanimsizken post_cutoff/cutoff_invalid emit edildi (kural ihlali)';
  END IF;
  v_b0 := pg_temp.bf_blocker_count(v_r);
  RAISE NOTICE 'F0 OK: sekil + tanimsiz-cutoff + bos-grup-yok; baseline blocker sayisi %', v_b0;

  -- ═══ F0b) Grant yuzeyi (F5, root-gate tur-1) ══════════════════════════
  IF has_function_privilege('service_role', 'public.pedigree_integrity_report()', 'EXECUTE') THEN
    RAISE EXCEPTION 'F0b: service_role integrity_report EXECUTE aliyor (F5 ihlali)';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.pedigree_integrity_report()', 'EXECUTE') THEN
    RAISE EXCEPTION 'F0b: authenticated integrity_report EXECUTE verilmemis';
  END IF;
  IF has_function_privilege('anon', 'public.pedigree_integrity_report()', 'EXECUTE') THEN
    RAISE EXCEPTION 'F0b: anon integrity_report EXECUTE aliyor';
  END IF;
  RAISE NOTICE 'F0b OK: grantlar — authenticated=t, anon=f, service_role=f';

  -- ═══ FAZ A) Temiz fixture: guvenli maternal satir → edge + SIFIR blocker ═
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi)
    VALUES (v_anne, v_anne, 'Dişi', 'Aktif', '2023-01-01');
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi, anne_id)
    VALUES (v_calf, v_calf, 'Dişi', 'Aktif', '2025-06-01', v_anne);
  INSERT INTO public.dogum (id, anne_id, tarih, yavru_kupe, yavru_cins, buzagi_id)
    VALUES (gen_random_uuid(), v_anne, '2025-06-01', v_calf, 'Dişi', v_calf);

  v_c1 := public.pedigree_farm_backfill();

  SELECT pn.id INTO v_node_calf FROM public.pedigree_nodes pn WHERE pn.farm_animal_id = v_calf;
  SELECT pn.id INTO v_node_anne FROM public.pedigree_nodes pn WHERE pn.farm_animal_id = v_anne;
  IF v_node_calf IS NULL OR v_node_anne IS NULL THEN
    RAISE EXCEPTION 'FA: fixture node''lari uretilmedi';
  END IF;

  SELECT pp.id INTO v_edge FROM public.pedigree_parentage pp
   WHERE pp.farm_id = public.current_farm_id()
     AND pp.child_node_id = v_node_calf AND pp.parent_role = 'dam';
  IF v_edge IS NULL THEN
    RAISE EXCEPTION 'FA: guvenli satir icin dam edge uretilmedi';
  END IF;
  SELECT source_type, confidence, parent_node_id, source_ref INTO v_st, v_conf, v_par, v_sref
    FROM public.pedigree_parentage WHERE id = v_edge;
  IF v_st <> 'reconcile' OR v_conf <> 1.0 OR v_par <> v_node_anne
     OR v_sref IS DISTINCT FROM 'pedigree_farm_backfill' THEN
    RAISE EXCEPTION 'FA: edge kontrati — source_type=% confidence=% parent_ok=% ref=%',
      v_st, v_conf, (v_par = v_node_anne), v_sref;
  END IF;

  -- G2 "blockers==0 with fixture data": temiz fixture blocker KATMADI
  v_r1 := public.pedigree_integrity_report();
  v_b := pg_temp.bf_blocker_count(v_r1);
  IF v_b <> v_b0 THEN
    RAISE EXCEPTION 'FA: temiz fixture blocker sayisini degistirdi (% → %)', v_b0, v_b;
  END IF;
  RAISE NOTICE 'FA OK: guvenli satir → reconcile edge (conf=1); blockers=% (delta 0)', v_b;

  -- ═══ FAZ A2) Idempotency (2.4): ikinci kosum 0 node / 0 edge ═══════════
  v_c2 := public.pedigree_farm_backfill();
  IF (v_c2->>'nodes_created')::integer <> 0 OR (v_c2->>'maternal_edges_created')::integer <> 0 THEN
    RAISE EXCEPTION 'FA2: ikinci kosum yazdi — nodes=% edges=% (idempotency ihlali)',
      v_c2->>'nodes_created', v_c2->>'maternal_edges_created';
  END IF;
  IF (v_c2->>'maternal_safe_rows')::integer <> (v_c1->>'maternal_safe_rows')::integer THEN
    RAISE EXCEPTION 'FA2: safe satir sayisi degisti (% → %)',
      v_c1->>'maternal_safe_rows', v_c2->>'maternal_safe_rows';
  END IF;
  RAISE NOTICE 'FA2 OK: ikinci kosum 0/0 (safe_rows=%, skipped=%)',
    v_c2->>'maternal_safe_rows', v_c2->>'maternal_edges_skipped';

  -- ═══ FAZ B) Dislama siniflari → rapor kodlariyla birebir ═══════════════
  -- M: kendi dogum kaydi VAR ama tarihi dogum_tarihi'den SONRA → uyumsuz (blocker)
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi, anne_id)
    VALUES (v_mism, v_mism, 'Dişi', 'Aktif', '2025-01-01', v_anne);
  INSERT INTO public.dogum (id, anne_id, tarih, yavru_kupe, yavru_cins, buzagi_id)
    VALUES (gen_random_uuid(), v_anne, '2026-01-01', v_mism, 'Dişi', v_mism);
  -- N: kendi dogum kaydi HIC YOK → uyumsuz (blocker)
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi, anne_id)
    VALUES (v_nodg, v_nodg, 'Dişi', 'Aktif', '2025-02-01', v_anne);
  -- T: dogum_tarihi NULL → maternal_tarih_bilinmiyor (warning)
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, anne_id)
    VALUES (v_tarih, v_tarih, 'Dişi', 'Aktif', v_anne);
  -- U: anne_id hicbir hayvanla resolve olmuyor → unresolved_anne_id (warning)
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi, anne_id)
    VALUES (v_unres, v_unres, 'Dişi', 'Aktif', '2025-03-01', '__TEST_BF_ANNE_YOK__');
  -- Z: dogum_anne celiski senaryosunun calf'i (kendi dogum kaydi UYAR → GUVENLI)
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi)
    VALUES (v_anne2, v_anne2, 'Dişi', 'Aktif', '2022-01-01');
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi)
    VALUES (v_anne3, v_anne3, 'Dişi', 'Aktif', '2022-03-01');
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi, anne_id)
    VALUES (v_z, v_z, 'Dişi', 'Aktif', '2025-07-01', v_anne3);
  INSERT INTO public.dogum (id, anne_id, tarih, yavru_kupe, yavru_cins, buzagi_id)
    VALUES (v_dz, v_anne3, '2025-07-01', v_z, 'Dişi', v_z);
  -- sapma damlari (graph'ta yanlis dam olarak duracaklar)
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi)
    VALUES (v_sapma1, v_sapma1, 'Dişi', 'Aktif', '2022-02-01');
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi)
    VALUES (v_sapma2, v_sapma2, 'Dişi', 'Aktif', '2022-04-01');
  -- dongu cifti + erkek dam + yas senaryolari
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi)
    VALUES (v_cyc1, v_cyc1, 'Dişi', 'Aktif', '2022-05-01');
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi)
    VALUES (v_cyc2, v_cyc2, 'Dişi', 'Aktif', '2022-06-01');
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi)
    VALUES (v_erkek, v_erkek, 'Erkek', 'Aktif', '2022-07-01');
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi)
    VALUES (v_rc, v_rc, 'Dişi', 'Aktif', '2025-08-01');
  -- K1: parent (P1, 2026-01-01) child'dan (2025-01-01) SONRA dogmus
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi)
    VALUES (v_k1, v_k1, 'Dişi', 'Aktif', '2025-01-01');
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi)
    VALUES (v_p1, v_p1, NULL, 'Aktif', '2026-01-01');
  -- K2: fark 111 gun (0 <= fark < 548) → suspiciously_young
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi)
    VALUES (v_k2, v_k2, 'Dişi', 'Aktif', '2025-05-01');
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi)
    VALUES (v_p2, v_p2, NULL, 'Aktif', '2025-01-10');
  -- K3: fark > 548 gun → hicbirinde yok
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi)
    VALUES (v_k3, v_k3, 'Dişi', 'Aktif', '2025-01-01');
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi)
    VALUES (v_p3, v_p3, NULL, 'Aktif', '2023-01-01');
  -- Y1/Y2: child_without_dam yas kapisi; ND: node silme; baba_bilgi
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi)
    VALUES (v_y1, v_y1, 'Dişi', 'Aktif', '2024-06-01');
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi)
    VALUES (v_y2, v_y2, 'Dişi', 'Aktif', current_date - 30);
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi)
    VALUES (v_nd, v_nd, 'Dişi', 'Aktif', '2024-01-01');
  INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi, baba_bilgi)
    VALUES (v_baba, v_baba, 'Dişi', 'Aktif', '2024-02-01', 'BOGA-BF-TEST');
  -- W: buzagi_id'siz dogum satiri (info kodu dogum_buzagi_missing)
  INSERT INTO public.dogum (id, anne_id, tarih, yavru_kupe, yavru_cins, buzagi_id)
    VALUES (v_dw, v_anne, '2024-05-01', '__TEST_BF_W__', 'Dişi', NULL);

  v_c3 := public.pedigree_farm_backfill();

  -- Uyumsuz/tarih-bilinmeyen/cozumsuz satirlara edge YOK (predicate dislar)
  SELECT count(*) INTO v_n
    FROM public.pedigree_parentage pp
    JOIN public.pedigree_nodes pn ON pn.id = pp.child_node_id AND pn.farm_id = pp.farm_id
   WHERE pp.parent_role = 'dam'
     AND pn.farm_animal_id IN (v_mism, v_nodg, v_tarih, v_unres);
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'FB: dislanan satirlara % dam edge yazildi', v_n;
  END IF;

  v_r := public.pedigree_integrity_report();
  -- maternal_tarihsel_uyumsuz (blocker): M + N
  IF NOT (pg_temp.bf_has_key(v_r, 'maternal_tarihsel_uyumsuz', v_mism)
      AND pg_temp.bf_has_key(v_r, 'maternal_tarihsel_uyumsuz', v_nodg)) THEN
    RAISE EXCEPTION 'FB: uyumsuz sinif emit edilmedi (M/N)';
  END IF;
  IF pg_temp.bf_has_key(v_r, 'maternal_tarihsel_uyumsuz', v_tarih)
     OR pg_temp.bf_has_key(v_r, 'maternal_tarihsel_uyumsuz', v_unres) THEN
    RAISE EXCEPTION 'FB: uyumsuz grubunda yabanci fixture (T/U)';
  END IF;
  -- maternal_tarih_bilinmiyor (warning): T
  IF NOT pg_temp.bf_has_key(v_r, 'maternal_tarih_bilinmiyor', v_tarih) THEN
    RAISE EXCEPTION 'FB: tarih-bilinmiyor emit edilmedi (T)';
  END IF;
  IF pg_temp.bf_has_key(v_r, 'maternal_tarih_bilinmiyor', v_unres) THEN
    RAISE EXCEPTION 'FB: U tarih-bilinmiyor grubuna sizdi (sinif karmasasi)';
  END IF;
  -- unresolved_anne_id (warning): U
  IF NOT pg_temp.bf_has_key(v_r, 'unresolved_anne_id', v_unres) THEN
    RAISE EXCEPTION 'FB: unresolved_anne_id emit edilmedi (U)';
  END IF;
  -- blocker delta: sadece M+N (B0+2)
  v_b := pg_temp.bf_blocker_count(v_r);
  IF v_b <> v_b0 + 2 THEN
    RAISE EXCEPTION 'FB: blocker delta beklenen +2, gercek % (B0=%)', v_b, v_b0;
  END IF;
  RAISE NOTICE 'FB OK: dislama siniflari → kod eslemesi dogru; blockers=% (B0+2)', v_b;

  -- Idempotency, dislanan satirlar VARKEN de gecerli:
  v_c4 := public.pedigree_farm_backfill();
  IF (v_c4->>'nodes_created')::integer <> 0 OR (v_c4->>'maternal_edges_created')::integer <> 0 THEN
    RAISE EXCEPTION 'FB2: dislamali kosumda ikinci tur yazdi (nodes=% edges=%)',
      v_c4->>'nodes_created', v_c4->>'maternal_edges_created';
  END IF;
  RAISE NOTICE 'FB2 OK: dislamali ikinci kosum 0/0';

  -- ═══ FAZ C) Graph-anomali kodlari (dogrudan edge ile) ══════════════════
  SELECT pn.id INTO v_node_z FROM public.pedigree_nodes pn WHERE pn.farm_animal_id = v_z;
  SELECT pn.id INTO v_node_cyc1 FROM public.pedigree_nodes pn WHERE pn.farm_animal_id = v_cyc1;
  SELECT pn.id INTO v_node_cyc2 FROM public.pedigree_nodes pn WHERE pn.farm_animal_id = v_cyc2;
  SELECT pn.id INTO v_node_erkek FROM public.pedigree_nodes pn WHERE pn.farm_animal_id = v_erkek;
  SELECT pn.id INTO v_node_rc FROM public.pedigree_nodes pn WHERE pn.farm_animal_id = v_rc;

  -- C1) dogum_anne celiski: backfill A3→Z dogru edge'ini sil, B3→Z yanlisini koy
  DELETE FROM public.pedigree_parentage
   WHERE farm_id = public.current_farm_id() AND child_node_id = v_node_z AND parent_role = 'dam';
  SELECT pn.id INTO v_tmp FROM public.pedigree_nodes pn WHERE pn.farm_animal_id = v_sapma2;
  INSERT INTO public.pedigree_parentage (farm_id, parent_node_id, child_node_id, parent_role, source_type)
    VALUES (public.current_farm_id(), v_tmp, v_node_z, 'dam', 'manual');
  -- C2) legacy_anne celiski: X senaryosu (anne_id=anne2, graph dam=sapma1)
  --     X'yi Y1/Y2 sonrasindaki taze kimlikle koy:
  DECLARE
    v_x text := '__TEST_BF_LEGACYX__'; v_xa text := v_anne2; v_xs text := v_sapma1;
    v_xn uuid; v_xsn uuid;
  BEGIN
    INSERT INTO public.hayvanlar (id, kupe_no, cinsiyet, durum, dogum_tarihi, anne_id)
      VALUES (v_x, v_x, 'Dişi', 'Aktif', '2025-04-01', v_xa);
    SELECT pn.id INTO v_xn FROM public.pedigree_nodes pn WHERE pn.farm_animal_id = v_x;
    SELECT pn.id INTO v_xsn FROM public.pedigree_nodes pn WHERE pn.farm_animal_id = v_xs;
    INSERT INTO public.pedigree_parentage (farm_id, parent_node_id, child_node_id, parent_role, source_type)
      VALUES (public.current_farm_id(), v_xsn, v_xn, 'dam', 'manual');
  END;
  -- C3) dongu: CYC1 ↔ CYC2 (dam edgeleriyle iki yonlu)
  INSERT INTO public.pedigree_parentage (farm_id, parent_node_id, child_node_id, parent_role, source_type)
    VALUES (public.current_farm_id(), v_node_cyc1, v_node_cyc2, 'dam', 'manual'),
           (public.current_farm_id(), v_node_cyc2, v_node_cyc1, 'dam', 'manual');
  -- C4) role_sex_contradiction: erkek node'a dam rolu
  INSERT INTO public.pedigree_parentage (farm_id, parent_node_id, child_node_id, parent_role, source_type)
    VALUES (public.current_farm_id(), v_node_erkek, v_node_rc, 'dam', 'manual');
  -- C5) yas kodlari: K1←P1 (parent sonra dogmus), K2←P2 (111 gun), K3←P3 (uzak)
  DECLARE
    v_kn uuid; v_pn uuid;
  BEGIN
    FOR r2 IN
      SELECT x.k, x.p FROM (VALUES
        (v_k1, v_p1), (v_k2, v_p2), (v_k3, v_p3)
      ) AS x(k, p)
    LOOP
      SELECT pn.id INTO v_kn FROM public.pedigree_nodes pn WHERE pn.farm_animal_id = r2.k;
      SELECT pn.id INTO v_pn FROM public.pedigree_nodes pn WHERE pn.farm_animal_id = r2.p;
      INSERT INTO public.pedigree_parentage (farm_id, parent_node_id, child_node_id, parent_role, source_type)
        VALUES (public.current_farm_id(), v_pn, v_kn, 'dam', 'manual');
    END LOOP;
  END;

  v_r := public.pedigree_integrity_report();
  -- dogum_anne_graph_dam_celiskisi: key = dogum satiri (v_dz)
  IF NOT pg_temp.bf_has_key(v_r, 'dogum_anne_graph_dam_celiskisi', v_dz::text) THEN
    RAISE EXCEPTION 'FC: dogum_anne celiski emit edilmedi (dogum %)', v_dz;
  END IF;
  -- legacy_anne_graph_dam_celiskisi: key = X hayvan id; detail bicimi (r9-F48)
  IF NOT pg_temp.bf_has_key(v_r, 'legacy_anne_graph_dam_celiskisi', '__TEST_BF_LEGACYX__') THEN
    RAISE EXCEPTION 'FC: legacy_anne celiski emit edilmedi (X)';
  END IF;
  SELECT detail INTO v_hata FROM (
    SELECT it->>'detail' AS detail
      FROM jsonb_array_elements(v_r->'groups') g,
           jsonb_array_elements(g->'items') it
     WHERE g->>'code' = 'legacy_anne_graph_dam_celiskisi'
       AND it->>'key' = '__TEST_BF_LEGACYX__') s;
  IF v_hata NOT LIKE 'anne_id=__TEST_BF_ANNE2__ graph=%' OR length(v_hata) <> length('anne_id=__TEST_BF_ANNE2__ graph=') + 8 THEN
    RAISE EXCEPTION 'FC: legacy_anne detail kontrati bozuk: %', v_hata;
  END IF;
  -- cycle_count (blocker): TEK item, key = bileşen min id, iki uye detail'de
  v_keys := pg_temp.bf_group_keys(v_r, 'cycle_count');
  v_n := array_length(v_keys, 1);
  IF v_n IS NULL OR v_n <> 1 THEN
    RAISE EXCEPTION 'FC: dongu icin 1 item beklenirdi, %', COALESCE(v_n, 0);
  END IF;
  IF v_keys[1] <> LEAST(v_node_cyc1::text, v_node_cyc2::text) THEN
    RAISE EXCEPTION 'FC: dongu key min-node degil: %', v_keys[1];
  END IF;
  -- role_sex_contradiction: key = edge id
  SELECT pp.id::text INTO v_tmp
    FROM public.pedigree_parentage pp
   WHERE pp.child_node_id = v_node_rc AND pp.parent_role = 'dam';
  IF NOT pg_temp.bf_has_key(v_r, 'role_sex_contradiction', v_tmp::text) THEN
    RAISE EXCEPTION 'FC: role_sex_contradiction emit edilmedi (edge %)', v_tmp;
  END IF;
  -- parent_born_after_child: K1 VAR; K2/K3 YOK
  IF NOT pg_temp.bf_has_key(v_r, 'parent_born_after_child', v_k1 || ':dam') THEN
    RAISE EXCEPTION 'FC: parent_born_after_child emit edilmedi (K1)';
  END IF;
  IF pg_temp.bf_has_key(v_r, 'parent_born_after_child', v_k2 || ':dam')
     OR pg_temp.bf_has_key(v_r, 'parent_born_after_child', v_k3 || ':dam') THEN
    RAISE EXCEPTION 'FC: parent_born_after_child yalnis satir (K2/K3)';
  END IF;
  -- suspiciously_young_parent: K2 VAR (r10-F61: negatif fark K1'e GIRMEZ), K3 YOK
  IF NOT pg_temp.bf_has_key(v_r, 'suspiciously_young_parent', v_k2 || ':dam') THEN
    RAISE EXCEPTION 'FC: suspiciously_young_parent emit edilmedi (K2)';
  END IF;
  IF pg_temp.bf_has_key(v_r, 'suspiciously_young_parent', v_k1 || ':dam')
     OR pg_temp.bf_has_key(v_r, 'suspiciously_young_parent', v_k3 || ':dam') THEN
    RAISE EXCEPTION 'FC: suspiciously_young yalnis satir (K1 negatif fark / K3 uzak)';
  END IF;
  RAISE NOTICE 'FC OK: dogum/legacy celiski + dongu + cinsiyet + yas kodlari';

  -- ═══ FAZ D) duplicate_registry (blocker) — unique index fixture icinde kaldirilir
  DROP INDEX IF EXISTS public.uq_pedigree_nodes_registry;
  INSERT INTO public.pedigree_nodes (node_kind, display_name, registry_system, registry_code)
    VALUES ('external_animal', '__TEST_BF_DUP1__', 'TESTSYS', 'BFDUP'),
           ('external_animal', '__TEST_BF_DUP2__', 'TESTSYS', 'BFDUP');
  v_r := public.pedigree_integrity_report();
  IF NOT pg_temp.bf_has_key(v_r, 'duplicate_registry', 'BFDUP') THEN
    RAISE EXCEPTION 'FD: duplicate_registry emit edilmedi';
  END IF;
  SELECT detail INTO v_hata FROM (
    SELECT it->>'detail' AS detail
      FROM jsonb_array_elements(v_r->'groups') g,
           jsonb_array_elements(g->'items') it
     WHERE g->>'code' = 'duplicate_registry') s LIMIT 1;
  IF v_hata NOT LIKE '%node_sayisi=2%' THEN
    RAISE EXCEPTION 'FD: duplicate detail node_sayisi tasimiyor: %', v_hata;
  END IF;
  RAISE NOTICE 'FD OK: duplicate_registry (blocker)';

  -- ═══ FAZ E) cutoff durumlari ═══════════════════════════════════════════
  -- E1) gecersiz deger → istisna DEGIL, cutoff:'gecersiz' + cutoff_invalid (blocker)
  INSERT INTO public.pedigree_meta (key, value) VALUES ('semen_controlled_cutoff', '1900-13-45');
  v_r := public.pedigree_integrity_report();
  IF v_r->>'cutoff' IS DISTINCT FROM 'gecersiz' THEN
    RAISE EXCEPTION 'FE1: bozuk cutoff raporu COldurdu/yanlis durum: %', v_r->>'cutoff';
  END IF;
  SELECT jsonb_build_object('key', it->>'key', 'detail', it->>'detail') INTO v_j
    FROM jsonb_array_elements(v_r->'groups') g,
         jsonb_array_elements(g->'items') it
   WHERE g->>'code' = 'cutoff_invalid';
  IF v_j IS NULL OR v_j->>'key' <> 'cutoff' OR v_j->>'detail' NOT LIKE '%1900-13-45%' THEN
    RAISE EXCEPTION 'FE1: cutoff_invalid item kontrati bozuk: %', COALESCE(v_j::text, 'yok');
  END IF;
  IF pg_temp.bf_has_group(v_r, 'post_cutoff_null_semen') THEN
    RAISE EXCEPTION 'FE1: cutoff gecersizken post_cutoff emit edildi (NULL-sayici bolum atlanmali)';
  END IF;
  DELETE FROM public.pedigree_meta WHERE key = 'semen_controlled_cutoff';

  -- E2) gecerli cutoff + semen_id kolonu (fixture icinde eklenir, rollback geri alir)
  SELECT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema='public' AND table_name='tohumlama' AND column_name='semen_id')
    INTO v_semcol;
  IF NOT v_semcol THEN
    ALTER TABLE public.tohumlama ADD COLUMN semen_id text;
  END IF;
  INSERT INTO public.pedigree_meta (key, value) VALUES ('semen_controlled_cutoff', '2026-06-01T00:00:00Z');
  -- gercek (fixture'siz) ihlal sayisi ONCE olculur (r12-F68 predikati, in-tx)
  SELECT count(*) INTO v_real_pc
    FROM public.tohumlama
   WHERE created_at > '2026-06-01T00:00:00Z'::timestamptz
     AND semen_id IS NULL
     AND sperma IS NOT NULL AND btrim(sperma) <> '';
  -- fixture tohumlama satirlari: t1 ihlal; t2 pre-cutoff; t3 sperma NULL; t4 bosluk; t5 semen_id dolu
  INSERT INTO public.tohumlama (id, hayvan_id, tarih, sperma, sonuc, created_at)
    VALUES (gen_random_uuid(), v_anne, '2026-07-01', 'SERA-BF-1', 'Beklemede', '2026-07-01');
  INSERT INTO public.tohumlama (id, hayvan_id, tarih, sperma, sonuc, created_at)
    VALUES (gen_random_uuid(), v_anne, '2026-05-01', 'SERA-BF-2', 'Beklemede', '2026-05-01');
  INSERT INTO public.tohumlama (id, hayvan_id, tarih, sperma, sonuc, created_at)
    VALUES (gen_random_uuid(), v_anne, '2026-07-02', NULL, 'Beklemede', '2026-07-02');
  INSERT INTO public.tohumlama (id, hayvan_id, tarih, sperma, sonuc, created_at)
    VALUES (gen_random_uuid(), v_anne, '2026-07-03', '  ', 'Beklemede', '2026-07-03');
  INSERT INTO public.tohumlama (id, hayvan_id, tarih, sperma, sonuc, created_at, semen_id)
    VALUES (gen_random_uuid(), v_anne, '2026-07-04', 'SERA-BF-5', 'Beklemede', '2026-07-04', gen_random_uuid()::text);

  v_r := public.pedigree_integrity_report();
  IF v_r->>'cutoff' !~ '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$' THEN
    RAISE EXCEPTION 'FE2: gecerli cutoff ISO degil: %', v_r->>'cutoff';
  END IF;
  IF NOT pg_temp.bf_has_group(v_r, 'post_cutoff_null_semen') THEN
    RAISE EXCEPTION 'FE2: gecerli cutoff + ihlal varken post_cutoff emit edilmedi';
  END IF;
  v_keys := pg_temp.bf_group_keys(v_r, 'post_cutoff_null_semen');
  IF array_length(v_keys, 1) <> v_real_pc + 1 THEN
    RAISE EXCEPTION 'FE2: post_cutoff item sayisi beklenen %, gelen % (anahtarlar: %)',
      v_real_pc + 1, array_length(v_keys, 1), array_to_string(v_keys, ',');
  END IF;
  SELECT t.id::text INTO v_hata
    FROM public.tohumlama t
   WHERE t.created_at = '2026-07-01' AND t.sperma = 'SERA-BF-1';
  IF NOT pg_temp.bf_has_key(v_r, 'post_cutoff_null_semen', v_hata) THEN
    RAISE EXCEPTION 'FE2: t1 ihlali post_cutoff''da yok';
  END IF;
  SELECT detail INTO v_hata FROM (
    SELECT it->>'detail' AS detail
      FROM jsonb_array_elements(v_r->'groups') g,
           jsonb_array_elements(g->'items') it
     WHERE g->>'code' = 'post_cutoff_null_semen' AND it->>'key' = v_hata) s;
  IF v_hata IS NULL OR v_hata NOT LIKE 'created_at > cutoff, sperma=%' THEN
    RAISE EXCEPTION 'FE2: post_cutoff detail kontrati bozuk: %', v_hata;
  END IF;
  DELETE FROM public.pedigree_meta WHERE key = 'semen_controlled_cutoff';
  RAISE NOTICE 'FE OK: cutoff gecersiz→gecersiz+blocker; gecerli→post_cutoff r12-F68 predikati (%+1 item)', v_real_pc;

  -- E3) gecerli cutoff + SIFIR ihlal → grup HIC emit edilmez (F1, root-gate
  -- tur-1: ne items:null ne bos dizi — absent-group kurali; Goal Rev 1 G2)
  -- semen_id kolonu E2'de bu tx icinde eklendi; ihlal uretmeyen gelecek cutoff
  INSERT INTO public.pedigree_meta (key, value) VALUES ('semen_controlled_cutoff', '2999-01-01T00:00:00Z');
  v_r := public.pedigree_integrity_report();
  IF v_r->>'cutoff' IS DISTINCT FROM '2999-01-01T00:00:00.000Z' THEN
    RAISE EXCEPTION 'E3: cutoff ISO beklenirdi, gelen %', v_r->>'cutoff';
  END IF;
  IF pg_temp.bf_has_group(v_r, 'post_cutoff_null_semen') THEN
    RAISE EXCEPTION 'E3/F1: gecerli cutoff + 0 ihlalde post_cutoff emit edildi (items=null/bos)';
  END IF;
  -- butun gruplarda items gercek dizi (global olcek — her durumda gecerli)
  SELECT count(*) INTO v_n
    FROM jsonb_array_elements(v_r->'groups') g
   WHERE jsonb_typeof(g->'items') <> 'array';
  IF v_n <> 0 THEN
    RAISE EXCEPTION 'E3: % grubun items''i dizi degil (F1 regresyonu)', v_n;
  END IF;
  DELETE FROM public.pedigree_meta WHERE key = 'semen_controlled_cutoff';
  RAISE NOTICE 'E3 OK: gecerli cutoff + 0 ihlal → post_cutoff grup YOK (F1 fix)';

  -- ═══ FAZ F) Task 8 gecikmis gruplari: map tablosu YOK → ASLA emit edilmez ═
  INSERT INTO public.tohumlama (id, hayvan_id, tarih, sperma, sonuc, created_at)
    VALUES (gen_random_uuid(), v_anne, '2025-09-01', 'BOGA-BF-TEST', 'Beklemede', '2025-09-01');
  v_r := public.pedigree_integrity_report();
  IF to_regclass('public.pedigree_legacy_identity_map') IS NOT NULL THEN
    RAISE EXCEPTION 'FF: legacy map tablosu VAR — bu test P1 varsayimiyla yazildi, durumu lead''e raporla';
  END IF;
  IF pg_temp.bf_has_group(v_r, 'unresolved_baba_bilgi')
     OR pg_temp.bf_has_group(v_r, 'legacy_semen_no_mapping') THEN
    RAISE EXCEPTION 'FF: map tablosuz emit edildi — r12-F69 kurali ihlali';
  END IF;
  RAISE NOTICE 'FF OK: Task 8 gecikmis gruplari emit edilmiyor';

  -- ═══ FAZ G) node eksik / yas kapisi / sire / buzagi_missing ════════════
  DELETE FROM public.pedigree_nodes pn
   USING public.hayvanlar h
   WHERE h.id = v_nd AND pn.farm_animal_id = h.id AND pn.farm_id = public.current_farm_id();
  v_r := public.pedigree_integrity_report();
  -- farm_animal_node_eksik: ND
  IF NOT pg_temp.bf_has_key(v_r, 'farm_animal_node_eksik', v_nd) THEN
    RAISE EXCEPTION 'FG: farm_animal_node_eksik emit edilmedi (ND)';
  END IF;
  -- child_without_dam: Y1 VAR (1 yas ustu, edge yok); Y2 YOK (1 yas alti); C VAR DEGIL (edge'i var)
  IF NOT pg_temp.bf_has_key(v_r, 'child_without_dam', v_y1) THEN
    RAISE EXCEPTION 'FG: child_without_dam emit edilmedi (Y1)';
  END IF;
  IF pg_temp.bf_has_key(v_r, 'child_without_dam', v_y2) THEN
    RAISE EXCEPTION 'FG: 1 yas alti Y2 child_without_dam''a girdi (yas kapisi ihlali)';
  END IF;
  IF pg_temp.bf_has_key(v_r, 'child_without_dam', v_calf) THEN
    RAISE EXCEPTION 'FG: dam edge''li C child_without_dam''a girdi';
  END IF;
  -- child_without_sire (info; yas kapisi YOK): Y2 ve C
  IF NOT (pg_temp.bf_has_key(v_r, 'child_without_sire', v_y2)
      AND pg_temp.bf_has_key(v_r, 'child_without_sire', v_calf)) THEN
    RAISE EXCEPTION 'FG: child_without_sire beklenen anahtarlar yok (Y2/C)';
  END IF;
  -- dogum_buzagi_missing (info): W dogum satiri
  IF NOT pg_temp.bf_has_key(v_r, 'dogum_buzagi_missing', v_dw::text) THEN
    RAISE EXCEPTION 'FG: dogum_buzagi_missing emit edilmedi (W)';
  END IF;
  RAISE NOTICE 'FG OK: node_eksik + yas kapisi + sire + buzagi_missing';

  -- ═══ FAZ H) Grup siralaması + son sekil ═══════════════════════════════
  v_r := public.pedigree_integrity_report();
  v_n := 0; v_e := 0;  -- v_n: onceki rank, v_e: siralama ihlali sayaci
  SELECT count(*) INTO v_e
    FROM (
      SELECT (g->>'severity') AS sev,
             LAG(g->>'severity') OVER () AS prev_sev,
             CASE g->>'severity' WHEN 'blocker' THEN 1 WHEN 'warning' THEN 2 ELSE 3 END AS rk,
             LAG(CASE g->>'severity' WHEN 'blocker' THEN 1 WHEN 'warning' THEN 2 ELSE 3 END)
               OVER () AS prev_rk,
             g->>'code' AS code,
             LAG(g->>'code') OVER () AS prev_code
        FROM jsonb_array_elements(v_r->'groups') g
    ) s
   WHERE (prev_rk IS NOT NULL AND rk < prev_rk)
      OR (prev_rk IS NOT NULL AND rk = prev_rk AND code <= prev_code);
  IF v_e <> 0 THEN
    RAISE EXCEPTION 'FH: grup siralamasi bozuk (% ihlal — blocker→warning→info, code asc)', v_e;
  END IF;
  SELECT count(*) INTO v_n FROM jsonb_object_keys(v_r) k;
  IF v_n <> 3 THEN RAISE EXCEPTION 'FH: son sekilde ust anahtar sayisi %', v_n; END IF;
  RAISE NOTICE 'FH OK: siralama + sekil';
  RAISE NOTICE 'TUM KONTROLLER GECTI (pedigree_farm_backfill_test)';
END
$test$;

ROLLBACK;
