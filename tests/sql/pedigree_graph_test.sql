-- 20260911000002_pedigree_foundation.sql davranis testi (Task 1 / gate G1).
-- Demo DB'de guvenlidir: tum test verisi transaction sonunda ROLLBACK edilir.
-- Calistirma: psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/sql/pedigree_graph_test.sql
--
-- Kapsam (goal G1 + plan Task 1.1):
--   1.1 invarianlari (1-10) + sex normalization + operator guard uclusu
--   (fail-closed / owner gecisi / INTERNAL core guardsız çağrısı — mekanizma
--   kanıtı, üretim bağlantısı Faz 7) + grants authenticated-only
--   + evidence COALESCE (r5-F29) + semen catalog guard'lari.

BEGIN;

DO $test$
DECLARE
  v_owner_uid  uuid := '99999999-9999-9999-9999-999999999999';
  v_other_uid  uuid := '88888888-8888-8888-8888-888888888888';
  v_diger_farm uuid := '11111111-1111-1111-1111-111111111111';

  v_h_erkek text := '__TEST_PED_H1__';
  v_h_disi  text := '__TEST_PED_H2__';
  v_h_null  text := '__TEST_PED_H3__';
  v_h_sil   text := '__TEST_PED_H4__';

  v_node_h1 uuid; v_node_h2 uuid; v_node_h3 uuid; v_node_h4 uuid;
  v_ea uuid; v_ef uuid; v_ep uuid; v_eq uuid; v_ex uuid; v_ey uuid; v_ez uuid;
  v_efem uuid; v_anne uuid;
  v_edge uuid; v_edge_dam uuid; v_edge_sire uuid; v_edge_tmp uuid;
  v_sem1 uuid;
  v_hata text;
  v_id uuid;
  v_evd jsonb;
  v_n integer;
  v_ev text;
BEGIN
  -- Claims mock'u (tum transaction boyunca): owner uid.
  PERFORM set_config('request.jwt.claims', format('{"sub":"%s"}', v_owner_uid), true);

  -- ═══ A) Guard fail-closed: op_owner_uid YOKKEN manual yol kapali ═════════
  v_hata := NULL;
  BEGIN
    v_edge := public.pedigree_parent_set(gen_random_uuid(), 'dam', gen_random_uuid());
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  IF v_hata IS NULL OR v_hata NOT LIKE '%tanimli degil%' THEN
    RAISE EXCEPTION 'A1 fail-closed: op_owner_uid yokken manual red gelmedi: %', coalesce(v_hata, 'hic hata yok');
  END IF;

  -- ═══ A2) INTERNAL core guard'sız çağrılabilir — MEKANİZMA kanıtı (review ══
  -- F4 düzeltmesi: P1'de dogum_kaydet→core üretim bağlantısı YOK; "doğum yolu"
  -- write'ı Faz 7'de bağlanır. Bu blok yalnız core'un guardsız çalışabildiğini
  -- kanıtlar; dogum_kaydet akışı iddiası TAŞIMAZ.)
  INSERT INTO public.pedigree_nodes (node_kind, display_name, sex)
  VALUES ('external_animal', '__TEST_PED_CORE_ANNE__', 'female')
  RETURNING id INTO v_ey;
  v_anne := v_ey;  -- female external node; C5 replace testinde yedek dam olarak kullanılır
  INSERT INTO public.pedigree_nodes (node_kind, display_name, sex)
  VALUES ('external_animal', '__TEST_PED_CORE_YAVRU__', NULL)
  RETURNING id INTO v_ez;

  v_edge := public._pedigree_parent_set_core(v_ez, 'dam', v_ey, 'birth', '__TEST_CORE_REF__', false, NULL);
  IF v_edge IS NULL THEN RAISE EXCEPTION 'A2: core dogum yolu edge uretmedi'; END IF;
  SELECT source_type, evidence INTO v_ev, v_evd FROM public.pedigree_parentage WHERE id = v_edge;
  IF v_ev <> 'birth' THEN RAISE EXCEPTION 'A2: source_type beklenen birth, gelen %', v_ev; END IF;
  -- r5-F29: p_evidence NULL → COALESCE '{}' yazilir
  IF v_evd IS DISTINCT FROM '{}'::jsonb THEN
    RAISE EXCEPTION 'A2/r5-F29: evidence COALESCE(bos) beklenirdi, gelen %', v_evd::text;
  END IF;

  -- ═══ B) Operator bootstrap fixture (migration YAZMAZ; test yazar) ════════
  INSERT INTO public.pedigree_meta (key, value) VALUES ('op_owner_uid', v_owner_uid::text);

  -- ═══ C1) Farm hayvani → tek node + idempotent create (inv. 1, 2) ═════════
  INSERT INTO public.hayvanlar (id, kupe_no, grup, cinsiyet, durum)
  VALUES (v_h_erkek, v_h_erkek, 'Süt İçen Buzağı', 'Erkek', 'Aktif');
  -- trigger zaten node yaratti:
  SELECT id INTO STRICT v_node_h1 FROM public.pedigree_nodes WHERE farm_animal_id = v_h_erkek;
  v_node_h4 := public.pedigree_ensure_farm_node(v_h_erkek);  -- ikinci cagri
  IF v_node_h4 <> v_node_h1 THEN RAISE EXCEPTION 'C1: ensure idempotent degil (% <> %)', v_node_h4, v_node_h1; END IF;
  SELECT count(*) INTO v_n FROM public.pedigree_nodes WHERE farm_animal_id = v_h_erkek;
  IF v_n <> 1 THEN RAISE EXCEPTION 'C1/inv1: tek node beklenirdi, % node var', v_n; END IF;

  -- ═══ C2) Sex normalization: Erkek→male, Dişi→female, bos→NULL ════════════
  INSERT INTO public.hayvanlar (id, kupe_no, grup, cinsiyet, durum)
  VALUES (v_h_disi, v_h_disi, 'Süt İçen Buzağı', 'Dişi', 'Aktif');
  SELECT sex INTO STRICT v_ev FROM public.pedigree_nodes WHERE farm_animal_id = v_h_disi;
  IF v_ev <> 'female' THEN RAISE EXCEPTION 'C2: Disi→female beklenirdi, gelen %', v_ev; END IF;

  INSERT INTO public.hayvanlar (id, kupe_no, grup, durum)
  VALUES (v_h_null, v_h_null, 'Süt İçen Buzağı', 'Aktif');  -- cinsiyet NULL
  SELECT sex INTO STRICT v_ev FROM public.pedigree_nodes WHERE farm_animal_id = v_h_null;
  IF v_ev IS NOT NULL THEN RAISE EXCEPTION 'C2: bos cinsiyet→NULL beklenirdi, gelen %', v_ev; END IF;

  SELECT id INTO STRICT v_node_h2 FROM public.pedigree_nodes WHERE farm_animal_id = v_h_disi;
  SELECT id INTO STRICT v_node_h3 FROM public.pedigree_nodes WHERE farm_animal_id = v_h_null;

  -- ═══ C3) External node yaratma (inv. 3) ══════════════════════════════════
  v_ea := public.pedigree_external_upsert('__TEST_PED_DIS_ARMADA__', NULL, 'male', NULL, NULL, 'CDC', 'ARM-1');
  IF v_ea IS NULL THEN RAISE EXCEPTION 'C3: external node uretilmedi'; END IF;
  SELECT node_kind INTO STRICT v_ev FROM public.pedigree_nodes WHERE id = v_ea;
  IF v_ev <> 'external_animal' THEN RAISE EXCEPTION 'C3: node_kind external degil: %', v_ev; END IF;

  -- ═══ C4) Ayni registry identity ikinci kez olusmaz (inv. 4) ══════════════
  v_id := public.pedigree_external_upsert('__TEST_PED_DIS_ARMADA_2__', NULL, NULL, NULL, NULL, 'CDC', 'ARM-1');
  IF v_id <> v_ea THEN RAISE EXCEPTION 'C4/inv4: ayni registry yeni node uretti (% <> %)', v_id, v_ea; END IF;
  SELECT count(*) INTO v_n FROM public.pedigree_nodes
   WHERE farm_id = public.current_farm_id() AND registry_system = 'CDC' AND registry_code = 'ARM-1';
  IF v_n <> 1 THEN RAISE EXCEPTION 'C4/inv4: registry basina 1 node beklenirdi, % var', v_n; END IF;

  -- ═══ C5) Child basina bir dam + bir sire; sessiz overwrite yok (inv. 5) ══
  v_edge_dam := public.pedigree_parent_set(v_node_h3, 'dam', v_node_h2);
  v_edge_sire := public.pedigree_parent_set(v_node_h3, 'sire', v_node_h1);
  SELECT count(*) INTO v_n FROM public.pedigree_parentage
   WHERE farm_id = public.current_farm_id() AND child_node_id = v_node_h3;
  IF v_n <> 2 THEN RAISE EXCEPTION 'C5: child basina 2 edge beklenirdi, % var', v_n; END IF;

  v_hata := NULL;
  BEGIN
    PERFORM public.pedigree_parent_set(v_node_h3, 'dam', v_anne);  -- farkli dam, replace yok
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  IF v_hata IS NULL OR v_hata NOT LIKE '%p_replace%' THEN
    RAISE EXCEPTION 'C5/inv5: farkli parent sessizce overwrite edilmedi mi? gelen: %', coalesce(v_hata, 'hic hata yok');
  END IF;
  -- F3 (tur-1): p_replace=NULL da açık onay DEĞİLDİR (üç-değerli tuzak, fail-closed)
  v_hata := NULL;
  BEGIN
    PERFORM public.pedigree_parent_set(v_node_h3, 'dam', v_anne, 'manual', NULL, NULL);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  IF v_hata IS NULL OR v_hata NOT LIKE '%p_replace%' THEN
    RAISE EXCEPTION 'C5/F3: p_replace=NULL overwrite''i engellemeliydi: %', coalesce(v_hata, 'hic hata yok');
  END IF;
  v_edge_tmp := public.pedigree_parent_set(v_node_h3, 'dam', v_anne, 'manual', NULL, true);
  SELECT parent_node_id INTO STRICT v_id FROM public.pedigree_parentage WHERE id = v_edge_tmp;
  IF v_id <> v_anne THEN RAISE EXCEPTION 'C5: replace sonrasi dam parent degismedi'; END IF;
  SELECT count(*) INTO v_n FROM public.pedigree_parentage
   WHERE farm_id = public.current_farm_id() AND child_node_id = v_node_h3 AND parent_role = 'dam';
  IF v_n <> 1 THEN RAISE EXCEPTION 'C5/inv5: replace sonrasi dam sayisi 1 degil: %', v_n; END IF;

  -- ═══ C6) parent = child reddi (inv. 6) ═══════════════════════════════════
  v_hata := NULL;
  BEGIN
    PERFORM public.pedigree_parent_set(v_node_h1, 'sire', v_node_h1);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  IF v_hata IS NULL OR v_hata NOT LIKE '%parent = child%' THEN
    RAISE EXCEPTION 'C6/inv6: parent=child reddi gelmedi: %', coalesce(v_hata, 'hic hata yok');
  END IF;

  -- ═══ C7) Cross-farm edge reddi (inv. 7) ══════════════════════════════════
  INSERT INTO public.pedigree_nodes (farm_id, node_kind, display_name, sex)
  VALUES (v_diger_farm, 'external_animal', '__TEST_PED_YABANCI__', 'male')
  RETURNING id INTO v_ep;
  v_hata := NULL;
  BEGIN
    PERFORM public.pedigree_parent_set(v_node_h3, 'sire', v_ep);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  IF v_hata IS NULL OR v_hata NOT LIKE '%farkli farm%' THEN
    RAISE EXCEPTION 'C7/inv7: cross-farm edge reddi gelmedi: %', coalesce(v_hata, 'hic hata yok');
  END IF;

  -- ═══ C8) Cycle A→B→C→A reddi (inv. 8) ════════════════════════════════════
  v_ex := public.pedigree_external_upsert('__TEST_PED_CYC_X__');
  v_ey := public.pedigree_external_upsert('__TEST_PED_CYC_Y__');
  v_ez := public.pedigree_external_upsert('__TEST_PED_CYC_Z__');
  PERFORM public.pedigree_parent_set(v_ey, 'sire', v_ex);  -- X→Y
  PERFORM public.pedigree_parent_set(v_ez, 'sire', v_ey);  -- Y→Z
  v_hata := NULL;
  BEGIN
    PERFORM public.pedigree_parent_set(v_ex, 'sire', v_ez);  -- Z→X: dongu kapatir
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  IF v_hata IS NULL OR v_hata NOT LIKE '%cycle%' THEN
    RAISE EXCEPTION 'C8/inv8: cycle reddi gelmedi: %', coalesce(v_hata, 'hic hata yok');
  END IF;

  -- ═══ C9) explicit_founder node parent edge alamaz ════════════════════════
  v_ef := public.pedigree_external_upsert('__TEST_PED_FOUNDER__');
  UPDATE public.pedigree_nodes SET founder_status = 'explicit_founder' WHERE id = v_ef;
  v_hata := NULL;
  BEGIN
    PERFORM public.pedigree_parent_set(v_ef, 'sire', v_node_h1);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  IF v_hata IS NULL OR v_hata NOT LIKE '%explicit_founder%' THEN
    RAISE EXCEPTION 'C9: explicit_founder parent-edge reddi gelmedi: %', coalesce(v_hata, 'hic hata yok');
  END IF;
  -- "once ordinary yapilir" akisi:
  UPDATE public.pedigree_nodes SET founder_status = 'ordinary' WHERE id = v_ef;
  v_edge := public.pedigree_parent_set(v_ef, 'sire', v_node_h1);
  IF v_edge IS NULL THEN RAISE EXCEPTION 'C9: ordinary sonrasi edge kurulmaliydi'; END IF;

  -- ═══ C10) Sex rol validasyonu: bilinen erkek dam / disi sire olamaz ══════
  v_eq := public.pedigree_external_upsert('__TEST_PED_ROLE_CHILD__');
  v_hata := NULL;
  BEGIN
    PERFORM public.pedigree_parent_set(v_eq, 'dam', v_node_h1);  -- erkek dam
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  IF v_hata IS NULL OR v_hata NOT LIKE '%erkek dam%' THEN
    RAISE EXCEPTION 'C10: bilinen erkek dam reddi gelmedi: %', coalesce(v_hata, 'hic hata yok');
  END IF;
  v_hata := NULL;
  BEGIN
    PERFORM public.pedigree_parent_set(v_eq, 'sire', v_node_h2);  -- disi sire
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  IF v_hata IS NULL OR v_hata NOT LIKE '%disi sire%' THEN
    RAISE EXCEPTION 'C10: bilinen disi sire reddi gelmedi: %', coalesce(v_hata, 'hic hata yok');
  END IF;
  -- sex NULL → izinli
  v_edge := public.pedigree_parent_set(v_eq, 'dam', v_node_h3);
  IF v_edge IS NULL THEN RAISE EXCEPTION 'C10: sex NULL parent izinli olmaliydi'; END IF;

  -- ═══ C11) Node silinince edge orphan kalmaz (inv. 9) ═════════════════════
  v_ep := public.pedigree_external_upsert('__TEST_PED_SILINECEK_BABA__');
  v_edge := public.pedigree_parent_set(v_eq, 'sire', v_ep);
  DELETE FROM public.pedigree_nodes WHERE id = v_ep;
  SELECT count(*) INTO v_n FROM public.pedigree_parentage WHERE parent_node_id = v_ep;
  IF v_n <> 0 THEN RAISE EXCEPTION 'C11/inv9: node silinince edge orphan kaldi (% adet)', v_n; END IF;

  -- ═══ C12) Farm hayvani silinince farm node orphan kalmaz (inv. 10) ═══════
  INSERT INTO public.hayvanlar (id, kupe_no, grup, durum)
  VALUES (v_h_sil, v_h_sil, 'Süt İçen Buzağı', 'Aktif');
  SELECT id INTO STRICT v_node_h4 FROM public.pedigree_nodes WHERE farm_animal_id = v_h_sil;
  DELETE FROM public.hayvanlar WHERE id = v_h_sil;
  SELECT count(*) INTO v_n FROM public.pedigree_nodes WHERE id = v_node_h4;
  IF v_n <> 0 THEN RAISE EXCEPTION 'C12/inv10: hayvan silinince node orphan kaldi'; END IF;

  -- ═══ C13) Yanlis operator reddi (auth.uid() <> op_owner_uid) ═════════════
  PERFORM set_config('request.jwt.claims', format('{"sub":"%s"}', v_other_uid), true);
  v_hata := NULL;
  BEGIN
    PERFORM public.pedigree_parent_set(v_eq, 'sire', v_node_h1);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  IF v_hata IS NULL OR v_hata NOT LIKE '%operator degil%' THEN
    RAISE EXCEPTION 'C13: yanlis operator reddi gelmedi: %', coalesce(v_hata, 'hic hata yok');
  END IF;
  PERFORM set_config('request.jwt.claims', format('{"sub":"%s"}', v_owner_uid), true);

  -- ═══ C14) Ayni rol + ayni parent tekrar → idempotent success ═════════════
  v_edge_tmp := public.pedigree_parent_set(v_node_h3, 'sire', v_node_h1);
  IF v_edge_tmp <> v_edge_sire THEN
    RAISE EXCEPTION 'C14: ayni parent tekrari yeni edge uretti (% <> %)', v_edge_tmp, v_edge_sire;
  END IF;

  -- ═══ C15) Manual yolda evidence COALESCE '{}' (r5-F29) ═══════════════════
  v_edge := public.pedigree_parent_set(v_eq, 'sire', v_node_h1, 'manual', NULL, false, NULL);
  SELECT evidence INTO v_evd FROM public.pedigree_parentage WHERE id = v_edge;
  IF v_evd IS DISTINCT FROM '{}'::jsonb THEN
    RAISE EXCEPTION 'C15/r5-F29: manual evidence {} beklenirdi, gelen %', v_evd::text;
  END IF;

  -- ═══ C16) semen_catalog guard'lari ═══════════════════════════════════════
  v_sem1 := public.semen_catalog_upsert('__TEST_PED_SEMEN_1__');
  IF v_sem1 IS NULL THEN RAISE EXCEPTION 'C16: semen katalog satiri uretilmedi'; END IF;
  SELECT sex INTO STRICT v_ev
    FROM public.pedigree_nodes n
    JOIN public.semen_catalog s ON s.bull_node_id = n.id
   WHERE s.id = v_sem1;
  IF v_ev <> 'male' THEN RAISE EXCEPTION 'C16: yaratilean bull sex male beklenirdi, gelen %', v_ev; END IF;

  -- (a) stock guard: Sperma olmayan kategori red
  INSERT INTO public.stok (id, kategori, urun_adi)
  VALUES ('__TEST_PED_STOK_ILAC__', 'İlaç', '__TEST_PED_STOK_ILAC__');
  v_hata := NULL;
  BEGIN
    PERFORM public.semen_catalog_upsert('__TEST_PED_SEMEN_2__', NULL, NULL, NULL, NULL, '__TEST_PED_STOK_ILAC__');
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  IF v_hata IS NULL OR v_hata NOT LIKE '%Sperma degil%' THEN
    RAISE EXCEPTION 'C16a: Sperma olmayan stok reddi gelmedi: %', coalesce(v_hata, 'hic hata yok');
  END IF;

  -- (a) Sperma stoku kabul
  INSERT INTO public.stok (id, kategori, urun_adi)
  VALUES ('__TEST_PED_STOK_SPERMA__', 'Sperma', '__TEST_PED_STOK_SPERMA__');
  v_id := public.semen_catalog_upsert('__TEST_PED_SEMEN_3__', NULL, NULL, NULL, NULL, '__TEST_PED_STOK_SPERMA__');
  IF v_id IS NULL THEN RAISE EXCEPTION 'C16a: Sperma stoklu katalog kabul edilmedi'; END IF;

  -- (b) female bull INSERT yolu red
  INSERT INTO public.pedigree_nodes (node_kind, display_name, sex)
  VALUES ('external_animal', '__TEST_PED_DISI_BULL__', 'female')
  RETURNING id INTO v_efem;
  v_hata := NULL;
  BEGIN
    PERFORM public.semen_catalog_upsert('__TEST_PED_SEMEN_4__', NULL, v_efem);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  IF v_hata IS NULL OR v_hata NOT LIKE '%female olamaz%' THEN
    RAISE EXCEPTION 'C16b: female bull reddi gelmedi: %', coalesce(v_hata, 'hic hata yok');
  END IF;

  -- (b) female bull UPDATE yolu da red (tohumlama.semen_id henuz yok → refs=0)
  v_hata := NULL;
  BEGIN
    PERFORM public.semen_catalog_upsert('__TEST_PED_SEMEN_1__', v_sem1, v_efem);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  IF v_hata IS NULL OR v_hata NOT LIKE '%female olamaz%' THEN
    RAISE EXCEPTION 'C16b-update: female bull guncelleme reddi gelmedi: %', coalesce(v_hata, 'hic hata yok');
  END IF;

  -- ayni degerle guncelleme zararsiz
  v_id := public.semen_catalog_upsert('__TEST_PED_SEMEN_1__', v_sem1, NULL);
  IF v_id <> v_sem1 THEN RAISE EXCEPTION 'C16: ayni katalog guncellemesi id degistirdi'; END IF;

  -- ═══ C17) Grants: authenticated-only ═════════════════════════════════════
  IF NOT has_table_privilege('authenticated', 'public.semen_catalog', 'SELECT') THEN
    RAISE EXCEPTION 'C17: authenticated semen_catalog SELECT yok';
  END IF;
  IF has_table_privilege('anon', 'public.semen_catalog', 'SELECT') THEN
    RAISE EXCEPTION 'C17: anon semen_catalog SELECT almis';
  END IF;
  IF has_table_privilege('anon', 'public.pedigree_nodes', 'SELECT')
     OR has_table_privilege('authenticated', 'public.pedigree_nodes', 'SELECT')
     OR has_table_privilege('authenticated', 'public.pedigree_nodes', 'INSERT')
     OR has_table_privilege('authenticated', 'public.pedigree_parentage', 'SELECT')
     OR has_table_privilege('authenticated', 'public.pedigree_meta', 'SELECT') THEN
    RAISE EXCEPTION 'C17: graph tablolari istemciye acik (default ACL sizintisi)';
  END IF;

  IF has_function_privilege('anon', 'public.pedigree_parent_set(uuid,text,uuid,text,text,boolean,jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'C17: anon pedigree_parent_set EXECUTE almis';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.pedigree_parent_set(uuid,text,uuid,text,text,boolean,jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'C17: authenticated pedigree_parent_set EXECUTE yok';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.pedigree_external_upsert(text,uuid,text,text,date,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'C17: authenticated pedigree_external_upsert EXECUTE yok';
  END IF;
  IF has_function_privilege('anon', 'public.pedigree_external_upsert(text,uuid,text,text,date,text,text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'C17: anon pedigree_external_upsert EXECUTE almis';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.semen_catalog_upsert(text,uuid,uuid,text,text,text,text,text,text,boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'C17: authenticated semen_catalog_upsert EXECUTE yok';
  END IF;
  IF has_function_privilege('anon', 'public.semen_catalog_upsert(text,uuid,uuid,text,text,text,text,text,text,boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'C17: anon semen_catalog_upsert EXECUTE almis';
  END IF;
  -- F5 (root-gate): service_role da kapali — authenticated-only kontratı
  IF has_function_privilege('service_role', 'public.pedigree_parent_set(uuid,text,uuid,text,text,boolean,jsonb)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.pedigree_external_upsert(text,uuid,text,text,date,text,text)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public.semen_catalog_upsert(text,uuid,uuid,text,text,text,text,text,text,boolean)', 'EXECUTE') THEN
    RAISE EXCEPTION 'C17/F5: service_role public RPC EXECUTE almis (authenticated-only ihlali)';
  END IF;

  -- INTERNAL core: kimse cagiramaz
  IF has_function_privilege('anon', 'public._pedigree_parent_set_core(uuid,text,uuid,text,text,boolean,jsonb)', 'EXECUTE')
     OR has_function_privilege('authenticated', 'public._pedigree_parent_set_core(uuid,text,uuid,text,text,boolean,jsonb)', 'EXECUTE')
     OR has_function_privilege('service_role', 'public._pedigree_parent_set_core(uuid,text,uuid,text,text,boolean,jsonb)', 'EXECUTE') THEN
    RAISE EXCEPTION 'C17: INTERNAL core''a EXECUTE sizmıs';
  END IF;

  -- ═══ C18) F1: authenticated'in semen_catalog DML'i kapalı, SELECT açık ═══
  IF has_table_privilege('authenticated', 'public.semen_catalog', 'INSERT')
     OR has_table_privilege('authenticated', 'public.semen_catalog', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.semen_catalog', 'DELETE')
     OR has_table_privilege('authenticated', 'public.pedigree_nodes', 'INSERT')
     OR has_table_privilege('authenticated', 'public.pedigree_parentage', 'INSERT')
     OR has_table_privilege('authenticated', 'public.pedigree_meta', 'INSERT') THEN
    RAISE EXCEPTION 'C18/F1: authenticated graph/katalog tablolarında DML yetkisi var (default ACL sizintisi)';
  END IF;

  -- F1: authenticated olarak doğrudan catalog INSERT → red
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_hata := NULL;
  BEGIN
    INSERT INTO public.semen_catalog (bull_node_id, display_name)
    VALUES (gen_random_uuid(), '__TEST_PED_F1_DOGRUDAN_YAZ__');
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  IF v_hata IS NULL OR (v_hata NOT LIKE '%permission denied%' AND v_hata NOT LIKE '%yetki%') THEN
    RAISE EXCEPTION 'C18/F1: authenticated dogrudan catalog INSERT reddi gelmedi: %', coalesce(v_hata, 'hic hata yok');
  END IF;

  -- ═══ C19) F2: helper'lar istemciye kapali; trigger yolu calisir ═══════════
  -- (a) anon dogrudan ensure_farm_node / is_ancestor → red
  EXECUTE 'SET LOCAL ROLE anon';
  v_hata := NULL;
  BEGIN
    PERFORM public.pedigree_ensure_farm_node(v_h_erkek);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  IF v_hata IS NULL OR (v_hata NOT LIKE '%permission denied%' AND v_hata NOT LIKE '%yetki%') THEN
    RAISE EXCEPTION 'C19/F2: anon ensure_farm_node reddi gelmedi: %', coalesce(v_hata, 'hic hata yok');
  END IF;
  v_hata := NULL;
  BEGIN
    PERFORM public.pedigree_is_ancestor(v_node_h1, v_node_h3);
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  IF v_hata IS NULL OR (v_hata NOT LIKE '%permission denied%' AND v_hata NOT LIKE '%yetki%') THEN
    RAISE EXCEPTION 'C19/F2: anon is_ancestor reddi gelmedi: %', coalesce(v_hata, 'hic hata yok');
  END IF;

  -- (b) trigger yolu KIRILMAMALI: authenticated dogrudan hayvanlar INSERT →
  --     node yaratilir (wrapper SECURITY DEFINER; trigger cagrisinda EXECUTE
  --     denetlenmez — review F2 kanit talebi)
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_hata := NULL;
  BEGIN
    INSERT INTO public.hayvanlar (id, kupe_no, grup, cinsiyet, durum)
    VALUES ('__TEST_PED_H5__', '__TEST_PED_H5__', 'Süt İçen Buzağı', 'Erkek', 'Aktif');
  EXCEPTION WHEN OTHERS THEN v_hata := SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  IF v_hata IS NOT NULL THEN
    RAISE EXCEPTION 'C19/F2: authenticated hayvan INSERT trigger yolunu kırdı: %', v_hata;
  END IF;
  SELECT count(*) INTO v_n FROM public.pedigree_nodes WHERE farm_animal_id = '__TEST_PED_H5__';
  IF v_n <> 1 THEN RAISE EXCEPTION 'C19/F2: authenticated INSERT sonrasi node yaratilmadi (% node)', v_n; END IF;

  RAISE NOTICE 'TESTDONE:pedigree_graph_test tamam — 19 blok yeşil';
END;
$test$;

ROLLBACK;
