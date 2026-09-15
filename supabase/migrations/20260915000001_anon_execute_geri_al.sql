-- ════════════════════════════════════════════════════════════
-- S1 — Güvenlik: anon/PUBLIC EXECUTE geri alma (2026-09-15, sahip onaylı)
--
-- AMAÇ: anon ve PUBLIC rollerinin public şemadaki fonksiyonlarda EXECUTE
--       yetkisini geri al. 2026-06-14 lockdown
--       (20260614000007_auth_gate_lockdown.sql) anon+PUBLIC'i REVOKE etmişti;
--       sonraki ~33 migration'daki "GRANT EXECUTE ... TO anon, authenticated"
--       şablonu bu kilidi fonksiyon tekilinde yeniden deldi. Bu migration
--       deliği kapatır.
--
-- KAPSAM: prod ölçümü 2026-09-15 — anon EXECUTE'lu 67 public fonksiyon
--         (53 SECURITY DEFINER + 14 SECURITY DEFINER değil), ad+imza
--         fonksiyon-tek REVOKE + genel kalkan.
--
-- KURAL: yalnız yetki (GRANT/REVOKE/DEFAULT PRIVILEGES). DROP/RENAME/TRUNCATE
--        YOK, veri YOK. authenticated GRANT'ları korunur (dokunulmaz),
--        kapanışta authenticated'a genel EXECUTE yeniden verilir
--        (lockdown ile aynı desen).
-- ════════════════════════════════════════════════════════════

-- ── Fonksiyon-tek REVOKE (prod ölçümünden, ad+imza; açıklık için) ──
REVOKE ALL ON FUNCTION public._asistan_ref_coz(p_param jsonb, p_ctx jsonb) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public._asistan_step_calistir(p_tip text, p_param jsonb) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public._asistan_step_dogrula(p_tip text, p_param jsonb) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public._ayar(p_anahtar text, p_varsayilan numeric) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public._etken_kod_bul(p_stok_id text, p_vaccine_id uuid) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public._gorev_dinle(p_hayvan_id text, p_etken_kod text, p_ref text, p_tarih date) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public._guard_dogum_ileri_tarih() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public._guard_hayvanlar_cinsiyet_grup() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public._guard_tohumlama_yas_cinsiyet() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public._islem_log_immutable_guard() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public._tohumlama_gorev_uygunluk(p_hayvan_id text, p_tarih date) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public._trg_gorev_parent_kapandi() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public._trg_hayvan_cikis_gorev_iptal() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public._vaka_ac_tek(p_hayvan_id text, p_disease_id uuid, p_notes text, p_tarih date) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.add_vaccination(p_animal_id text, p_vaccine_id uuid, p_date date, p_dose_override numeric, p_notes text, p_next_offset_days integer) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.agent_plans_prune() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.agent_threads_prune() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.asi_ekle(p_name text, p_marka text, p_etken_madde text, p_dose numeric, p_unit text, p_route text, p_is_mandatory boolean, p_disease_ids uuid[], p_protokol_tipi text, p_protokol_adimlar jsonb, p_repeat_interval_days integer, p_baslangic_stok numeric, p_esik numeric) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.asi_gorev_planla(p_hayvan_id text, p_vaccine_id uuid, p_doz numeric, p_tarih date, p_aciklama text) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.asi_guncelle(p_vaccine_id uuid, p_name text, p_marka text, p_etken_madde text, p_dose numeric, p_unit text, p_route text, p_is_mandatory boolean, p_disease_ids uuid[], p_protokol_tipi text, p_protokol_adimlar jsonb, p_repeat_interval_days integer, p_baslangic_stok numeric, p_esik numeric) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.asi_planli_tamamla(p_gorev_id text, p_tarih date, p_doz numeric, p_vaccine_id uuid) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.asi_sil(p_vaccine_id uuid) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.asi_toplu_planla(p_hayvan_id text, p_tarih date, p_items jsonb, p_aciklama text) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.asistan_hayvan_detay(p_kupe text, p_id text) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.asistan_plan_geri_al(p_plan_id uuid) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.asistan_plan_iptal(p_plan_id uuid) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.asistan_plan_olustur(p_thread_id uuid, p_adimlar jsonb) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.asistan_plan_uygula(p_plan_id uuid) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.asistan_sql_calistir(p_sql text) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.asistan_tumunu_sil() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.buzagi_sutten_kesme_geri_al(p_hayvan_id text) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.buzagi_sutten_kesme_kontrol() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.buzagi_sutten_kesme_onayla(p_hayvan_id text, p_tarih date) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.buzagi_sutten_kesme_toplu(p_hayvan_idler text[], p_tarih date) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.create_case(p_animal_id text, p_disease_id uuid, p_notes text) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.dogum_kaydet(p_anne_id text, p_tarih date, p_kupe text, p_cins text, p_tip text, p_kg numeric, p_baba text, p_hekim_id text) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.fn_gorev_asip_iade() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.fn_padok_transfer_gorev_kapat() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.gebelik_protokol_kontrol() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.get_vaccination_schedule(p_animal_id text) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.gorev_geri_al(p_gorev_id text) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.gorev_orphan_temizle() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.gorev_tamamla(p_gorev_id text, p_padok_hedef text) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.hayvan_belirsiz_ureme_listele() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.hayvan_kilo_guncelle(p_id text, p_canli_agirlik numeric) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.ilac_dozaj_guncelle(p_id uuid, p_guncellemeler jsonb) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.ilac_ekle(p_urun_adi text, p_kategori text, p_birim text, p_baslangic_miktar numeric, p_esik numeric, p_drug_class_id uuid, p_concentration numeric, p_concentration_unit text, p_default_route text) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.padok_degistir_toplu(p_hayvan_ids text[], p_yeni_padok_id uuid, p_etiketler text[], p_yeni_grup text) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.padok_transfer_gorev_uzlastir() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.planli_tohumlama_kaydet(p_gorev_id uuid, p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text, p_irk_bilgisi text, p_ek_uygulamalar jsonb, p_vwp_override boolean) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.protokol_ayar_guncelle(p_anahtar text, p_deger numeric) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.protokol_eksik_tara() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.protokol_gorev_bol(p_dry_run boolean) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.protokol_orphan_audit() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.protokol_orphan_temizle(p_dry_run boolean) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.sessiz_hayvanlar_reconcile() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.tedavi_sablon_kaydet(p_id uuid, p_ad text, p_aciklama text, p_disease_ids jsonb, p_kalemler jsonb) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.tedavi_sablon_tohumlama_gorev_ekle(p_case_id uuid, p_sablon_id uuid, p_baslangic_tarihi date) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.tedavi_sablon_uygula(p_case_id uuid, p_sablon_id uuid, p_baslangic_tarihi date) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.tohumlama_abort(p_tohumlama_id text, p_notlar text, p_abort_tarihi date) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.tohumlama_duplicate_bekliyor_temizle() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.tohumlama_kaydet(p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text, p_irk_bilgisi text, p_ek_uygulamalar jsonb, p_vwp_override boolean) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.tohumlama_orphan_gorev_temizle() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.trg_sutten_kesme_kapat() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.trg_sutten_kesme_normalize() FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.vaka_tohumlama_ekle(p_case_id uuid, p_tarih date, p_saat time without time zone) FROM anon, PUBLIC;
REVOKE ALL ON FUNCTION public.vaka_toplu_ac(p_animal_ids text[], p_disease_id uuid, p_items jsonb, p_sablon_id uuid, p_notes text, p_tarih date, p_tohumlama boolean, p_tohumlama_gun_offset integer, p_tohumlama_saat text, p_tohumlama_cakisma text) FROM anon, PUBLIC;

-- ── Genel kalkan: kalan her fonksiyondan da anon/PUBLIC'i al ──
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon, PUBLIC;

-- Gelecekte eklenen fonksiyonlar da anon/PUBLIC'e açılmasın
-- (lockdown 20260614000007 ile aynı desen).
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM PUBLIC;

-- authenticated kesintisiz çalışmaya devam etsin (lockdown deseni)
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
