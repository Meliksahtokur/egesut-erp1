-- ==== functions ====
SELECT n.nspname AS schema, p.proname AS name,
       pg_get_function_identity_arguments(p.oid) AS args,
       pg_get_function_result(p.oid) AS ret,
       p.prosecdef AS secdef, p.provolatile AS vol,
       pg_get_functiondef(p.oid) AS fdef
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public','surum_gizli') AND p.proname = ANY(ARRAY['_cagiran','_degisim_log_degistirilemez','_degisim_log_yaz','_degisim_plan','_degisim_uygula','_dogum_buzagi_backfill','_ekle_bagli','_guard_dogum_ileri_tarih','_guard_hayvanlar_cinsiyet_grup','_guard_tohumlama_yas_cinsiyet','_guncel_satir','_islem_log_degisim_txid','_islem_log_geri_alindi_kapisi','_islem_log_yaz','_kapsamda','_l4_rehber_uyesi','_l4_zaman_txid','_l4_zincir','_pedigree_parent_set_core','_pk_gorunum','_pk_json','_pk_kolonlar','_trg_pedigree_hayvan_insert','_vaka_ac_tek','asi_gorev_planla','asi_planli_tamamla','asi_toplu_planla','asistan_hayvan_detay','assert_is_operator','create_case','degisim_geri_al','degisim_listele','degisim_onizle','dogum_kaydet','fn_gorev_asip_iade','fn_sperma_stok_dus','gebelik_kaydet_manual','geri_al','geri_alma_bileti_al','gorev_tamamla','hayvan_belirsiz_ureme_listele','hayvan_ekle','hayvan_guncelle','hayvan_kilo_guncelle','ilac_dozaj_guncelle','kupe_musait_mi','pedigree_ensure_farm_node','pedigree_external_upsert','pedigree_farm_backfill','pedigree_integrity_report','pedigree_is_ancestor','pedigree_parent_set','pedigree_subgraph','pedigree_subgraph_for_animal','pedigree_try_timestamptz','protokol_eksik_tara','sahip_sifresi_ayarla','semen_catalog_upsert','tedavi_sablon_tohumlama_gorev_ekle','tedavi_sablon_uygula','tohumlama_abort','tohumlama_kaydet','tohumlama_sonuc_gebe','tohumlama_tekrar_kaydet','vaccination_stok_dusum','vaka_toplu_ac'])
ORDER BY 1,2,3;

-- ==== tables ====
SELECT n.nspname AS schema, c.relname AS name, c.relkind, c.relrowsecurity AS rls
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('public','surum_gizli') AND c.relkind IN ('r','p')
  AND c.relname = ANY(ARRAY['cases','degisim_log','diseases','dogum','drug_administrations','drug_classes','drug_products','drugs','geri_alma_bileti','geri_alma_kullanim','gorev_log','grup_padok_eslem','hastalik_log','hayvan_override','hayvanlar','hekimler','irk_esik','islem_log','kizginlik_log','l4_rehber_adimlari','padoklar','pedigree_meta','pedigree_nodes','pedigree_parentage','protokol_ayar','protokol_dismiss','protokol_instance','sablon_hastalik_eslem','sahip_sifresi','semen_catalog','stok','stok_hareket','stok_kategorileri','tedavi','tedavi_sablonu','tedavi_sablonu_kalem','tohumlama','treatment_day_uygulamalar','treatment_days','uygulama_log','vaccination_log','vaccination_schedule','vaccine_diseases','vaccine_protocol_steps','vaccines']);

-- ==== columns ====
SELECT table_schema AS schema, table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema IN ('public','surum_gizli')
  AND table_name = ANY(ARRAY['dogum','drug_products','islem_log','tohumlama'])
  AND column_name = ANY(ARRAY['abort_tarihi','buzagi_id','degisim_txid','olay_id','std_dose','std_dose_max','std_dose_min','std_dose_unit']);

-- ==== triggers ====
SELECT n.nspname AS schema, cl.relname AS table_name, t.tgname AS name,
       pg_get_triggerdef(t.oid) AS tdef
FROM pg_trigger t JOIN pg_class cl ON cl.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = cl.relnamespace
WHERE NOT t.tgisinternal AND n.nspname = 'public'
  AND (cl.relname = ANY(ARRAY['cases','degisim_log','diseases','dogum','drug_administrations','drug_classes','drug_products','drugs','geri_alma_bileti','geri_alma_kullanim','gorev_log','grup_padok_eslem','hastalik_log','hayvan_override','hayvanlar','hekimler','irk_esik','islem_log','kizginlik_log','l4_rehber_adimlari','padoklar','pedigree_meta','pedigree_nodes','pedigree_parentage','protokol_ayar','protokol_dismiss','protokol_instance','sablon_hastalik_eslem','sahip_sifresi','semen_catalog','stok','stok_hareket','stok_kategorileri','tedavi','tedavi_sablonu','tedavi_sablonu_kalem','tohumlama','treatment_day_uygulamalar','treatment_days','uygulama_log','vaccination_log','vaccination_schedule','vaccine_diseases','vaccine_protocol_steps','vaccines']) OR t.tgname = ANY(ARRAY['trg_degisim_log','trg_degisim_log_immutable','trg_degisim_log_no_truncate','trg_dogum_guard','trg_gorev_asip_iade','trg_hayvanlar_guard','trg_islem_log_degisim_txid','trg_islem_log_geri_alindi_kapisi','trg_pedigree_hayvan_insert','trg_tohumlama_guard']));

-- ==== policies ====
SELECT schemaname AS schema, tablename, policyname AS name, cmd, roles
FROM pg_policies WHERE schemaname IN ('public','surum_gizli');

-- ==== indexes ====
SELECT schemaname AS schema, tablename, indexname AS name, indexdef
FROM pg_indexes
WHERE schemaname IN ('public','surum_gizli')
  AND (indexname = ANY(ARRAY['dogum_buzagi_id_uidx','hayvanlar_kupe_no_key','idx_degisim_log_tablo_pk','idx_degisim_log_txid','idx_degisim_log_zaman','idx_geri_alma_kullanim_bilet','idx_islem_log_degisim_txid','idx_parentage_farm_child','idx_parentage_farm_parent','idx_parentage_farm_role_child','idx_pedigree_nodes_farm_kind','uq_pedigree_nodes_registry']) OR tablename = ANY(ARRAY['cases','degisim_log','diseases','dogum','drug_administrations','drug_classes','drug_products','drugs','geri_alma_bileti','geri_alma_kullanim','gorev_log','grup_padok_eslem','hastalik_log','hayvan_override','hayvanlar','hekimler','irk_esik','islem_log','kizginlik_log','l4_rehber_adimlari','padoklar','pedigree_meta','pedigree_nodes','pedigree_parentage','protokol_ayar','protokol_dismiss','protokol_instance','sablon_hastalik_eslem','sahip_sifresi','semen_catalog','stok','stok_hareket','stok_kategorileri','tedavi','tedavi_sablonu','tedavi_sablonu_kalem','tohumlama','treatment_day_uygulamalar','treatment_days','uygulama_log','vaccination_log','vaccination_schedule','vaccine_diseases','vaccine_protocol_steps','vaccines']));

-- ==== constraints ====
SELECT n.nspname::text AS schema, c.conrelid::regclass::text AS tbl,
       c.conname AS name, c.contype, pg_get_constraintdef(c.oid) AS cdef
FROM pg_constraint c JOIN pg_namespace n ON n.oid = c.connamespace
WHERE n.nspname IN ('public','surum_gizli')
  AND (c.conname = ANY(ARRAY['dogum_buzagi_id_fkey','drug_products_std_dose_unit_check']) OR c.conrelid::regclass::text = ANY(ARRAY['public.dogum','public.drug_products','public.islem_log','public.tohumlama']));

-- ==== table_grants ====
SELECT table_schema AS schema, table_name, grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema IN ('public','surum_gizli')
  AND table_name = ANY(ARRAY['cases','degisim_log','diseases','dogum','drug_administrations','drug_classes','drug_products','drugs','geri_alma_bileti','geri_alma_kullanim','gorev_log','grup_padok_eslem','hastalik_log','hayvan_override','hayvanlar','hekimler','irk_esik','islem_log','kizginlik_log','l4_rehber_adimlari','padoklar','pedigree_meta','pedigree_nodes','pedigree_parentage','protokol_ayar','protokol_dismiss','protokol_instance','sablon_hastalik_eslem','sahip_sifresi','semen_catalog','stok','stok_hareket','stok_kategorileri','tedavi','tedavi_sablonu','tedavi_sablonu_kalem','tohumlama','treatment_day_uygulamalar','treatment_days','uygulama_log','v_ureme_dongusu','vaccination_log','vaccination_schedule','vaccine_diseases','vaccine_protocol_steps','vaccines']);

-- ==== routine_grants ====
SELECT n.nspname AS schema, p.proname AS name, gr.rolname AS grantee,
       a.privilege_type
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
CROSS JOIN LATERAL aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
JOIN pg_roles gr ON gr.oid = a.grantee
WHERE n.nspname IN ('public','surum_gizli')
  AND p.proname = ANY(ARRAY['_cagiran','_degisim_log_degistirilemez','_degisim_log_degistirilemez()','_degisim_log_yaz','_degisim_log_yaz()','_degisim_plan','_degisim_plan(jsonb, text)','_degisim_uygula','_dogum_buzagi_backfill','_dogum_buzagi_backfill()','_ekle_bagli','_guard_dogum_ileri_tarih','_guard_hayvanlar_cinsiyet_grup','_guard_tohumlama_yas_cinsiyet','_guncel_satir','_islem_log_degisim_txid','_islem_log_degisim_txid()','_islem_log_geri_alindi_kapisi','_islem_log_geri_alindi_kapisi()','_islem_log_yaz','_kapsamda','_l4_rehber_uyesi','_l4_rehber_uyesi(jsonb)','_l4_zaman_txid','_l4_zaman_txid(text, jsonb, text)','_l4_zincir','_l4_zincir(jsonb)','_pedigree_parent_set_core','_pedigree_parent_set_core(uuid,text,uuid,text,text,boolean,jsonb)','_pk_gorunum','_pk_json','_pk_kolonlar','_trg_pedigree_hayvan_insert','_trg_pedigree_hayvan_insert()','_vaka_ac_tek','abort_kaydet(text, text)','asi_gorev_planla','asi_planli_tamamla','asi_toplu_planla','asistan_hayvan_detay','asistan_hayvan_detay(text, text)','assert_is_operator','assert_is_operator()','create_case','create_case(text, uuid, text)','degisim_geri_al','degisim_geri_al(jsonb, text, uuid, text)','degisim_listele','degisim_listele(jsonb)','degisim_onizle','degisim_onizle(jsonb, text)','dogum_kaydet','dogum_kaydet(text, date, text, text, text, numeric, text, text)','dogum_kaydet(text,date,text,text,text,numeric,text,text)','fn_gorev_asip_iade','fn_sperma_stok_dus','fn_sperma_stok_dus(text, text)','gebelik_kaydet_manual','geri_al','geri_alma_bileti_al','geri_alma_bileti_al(text)','gorev_tamamla','hayvan_belirsiz_ureme_listele','hayvan_belirsiz_ureme_listele()','hayvan_ekle','hayvan_guncelle','hayvan_kilo_guncelle','hayvan_kilo_guncelle(text, numeric)','ilac_dozaj_guncelle','ilac_dozaj_guncelle(uuid, jsonb)','kupe_musait_mi','pedigree_ensure_farm_node','pedigree_ensure_farm_node(text)','pedigree_external_upsert','pedigree_external_upsert(text,uuid,text,text,date,text,text)','pedigree_farm_backfill','pedigree_farm_backfill()','pedigree_integrity_report','pedigree_integrity_report()','pedigree_is_ancestor','pedigree_is_ancestor(uuid,uuid)','pedigree_parent_set','pedigree_parent_set(uuid,text,uuid,text,text,boolean,jsonb)','pedigree_subgraph','pedigree_subgraph(uuid, integer, integer)','pedigree_subgraph_for_animal','pedigree_subgraph_for_animal(text, integer, integer)','pedigree_try_timestamptz','pedigree_try_timestamptz(text)','protokol_eksik_tara','protokol_eksik_tara()','sahip_sifresi_ayarla','sahip_sifresi_ayarla(text)','semen_catalog_upsert','semen_catalog_upsert(text,uuid,uuid,text,text,text,text,text,text,boolean)','tedavi_sablon_tohumlama_gorev_ekle','tedavi_sablon_tohumlama_gorev_ekle(uuid, uuid, date)','tedavi_sablon_uygula','tedavi_sablon_uygula(uuid, uuid, date)','tohumlama_abort','tohumlama_abort(text, text, date)','tohumlama_kaydet','tohumlama_sonuc_gebe','tohumlama_tekrar_kaydet','vaccination_stok_dusum','vaka_toplu_ac','vaka_toplu_ac(text[], uuid, jsonb, uuid, text, date, boolean, int, text, text)']);

-- ==== views ====
SELECT schemaname AS schema, viewname AS name FROM pg_views
WHERE schemaname IN ('public','surum_gizli') AND viewname = ANY(ARRAY['v_eligible','v_ureme_dongusu']);

-- ==== schema_ext ====
SELECT 'schema' AS kind, nspname AS name FROM pg_namespace WHERE nspname = 'surum_gizli'
UNION ALL
SELECT 'extension:' || extname, n.nspname FROM pg_extension e
JOIN pg_namespace n ON n.oid = e.extnamespace WHERE extname = 'pgcrypto';

