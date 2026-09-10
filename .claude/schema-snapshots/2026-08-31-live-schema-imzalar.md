# Canlı Şema Snapshot — 2026-08-31 (imza düzeyi)

> Kaynak: PROD Supabase, `pg_proc`/`information_schema` üzerinden salt-okunur sorgu (fix oturumu P3).
> **Amaç:** Idle-A (rpc-reference regen + GT audit) tek girdisi — idle görev DB'ye dokunmaz, bu dosyadan çalışır.
> Kapsam: imza düzeyi (args + return). Gövde metni yoktur; gövde-level GT v5 regen denetimli oturum ister.
> Not: AGENTS.md ID tablosu bu dosyayla teyitlidir (gorev_log=uuid, stok_hareket=uuid?, islem_log=text — aşağıya bakın).

## Fonksiyonlar (195 giriş; overload'lar ayrı satır — `fn(args) :: ret`)

```
_asistan_ref_coz(p_param jsonb, p_ctx jsonb) :: jsonb
_asistan_step_calistir(p_tip text, p_param jsonb) :: jsonb
_asistan_step_dogrula(p_tip text, p_param jsonb) :: jsonb
_ayar(p_anahtar text, p_varsayilan numeric) :: numeric
_debug_protokol_ozet() :: jsonb
_etken_kod_bul(p_stok_id text, p_vaccine_id uuid) :: text
_gorev_dinle(p_hayvan_id text, p_etken_kod text, p_ref text, p_tarih date) :: void
_guard_dogum_ileri_tarih() :: trigger            [2026-08-31 eklendi]
_guard_hayvanlar_cinsiyet_grup() :: trigger      [2026-08-31 eklendi]
_guard_tohumlama_yas_cinsiyet() :: trigger       [2026-08-31 eklendi]
_islem_log_immutable_guard() :: trigger
_islem_log_yaz() :: trigger
_kizginlik_case_close() :: trigger
_protokol_kapat(p_kaynak_ref text, p_sebep text) :: void
_sessiz_gorev_iptal(p_hayvan_id text) :: void
_tohumlama_gorev_uygunluk(p_hayvan_id text, p_tarih date) :: text
_tohumlama_kizginlik_kapat() :: trigger
_trg_case_ureme_sessiz_iptal() :: trigger
_trg_gorev_parent_kapandi() :: trigger
_trg_hayvan_cikis_gorev_iptal() :: trigger
_trg_kizginlik_sessiz_iptal() :: trigger
_trg_tohumlama_gebe_sessiz_iptal() :: trigger
_trg_tohumlama_sessiz_iptal() :: trigger
abort_kaydet(p_tohumlama_id text, p_notlar text) :: jsonb
add_drug_administration(p_day_id uuid, p_drug_product_id uuid, p_stok_id text, p_dose numeric, p_unit text, p_route text) :: jsonb
add_sessions_to_existing_day(p_day_id uuid, p_sessions jsonb) :: jsonb
add_treatment_day(p_case_id uuid, p_date date, p_planned_time time) :: jsonb
add_treatment_day_with_sessions(p_case_id uuid, p_date date, p_sessions jsonb, p_existing_day_id uuid) :: jsonb
add_vaccination(p_animal_id text, p_vaccine_id uuid, p_date date, p_dose_override numeric, p_notes text, p_next_offset_days integer) :: jsonb
agent_plans_prune() :: void
agent_threads_prune() :: void
asi_ekle(p_name text, p_marka text, p_etken_madde text, p_dose numeric, p_unit text, p_route text, p_is_mandatory boolean, p_disease_ids uuid[], p_protokol_tipi text, p_protokol_adimlar jsonb, p_repeat_interval_days integer, p_baslangic_stok numeric, p_esik numeric) :: jsonb
asi_guncelle(p_vaccine_id uuid, [asi_ekle ile aynı 12 alan]) :: jsonb
asi_sil(p_vaccine_id uuid) :: jsonb
asistan_hayvan_detay(p_kupe text, p_id text) :: jsonb
asistan_plan_geri_al(p_plan_id uuid) :: jsonb
asistan_plan_iptal(p_plan_id uuid) :: jsonb
asistan_plan_olustur(p_thread_id uuid, p_adimlar jsonb) :: jsonb
asistan_plan_uygula(p_plan_id uuid) :: jsonb
asistan_sql_calistir(p_sql text) :: jsonb
asistan_tumunu_sil() :: jsonb
besleme_tamam(p_gorev_id text) :: jsonb
bulk_ilac(p_animal_ids text[], p_ilac_stok_id text, p_miktar numeric, p_notlar text) :: jsonb
bulk_vaccination(p_animal_ids text[], p_vaccine_id text, p_date date, p_dose_ml numeric, p_notes text) :: jsonb
buzagi_sutten_kesme_geri_al(p_hayvan_id text) :: jsonb
buzagi_sutten_kesme_kontrol() :: jsonb
buzagi_sutten_kesme_onayla(p_hayvan_id text, p_tarih date) :: jsonb
buzagi_sutten_kesme_toplu(p_hayvan_idler text[], p_tarih date) :: jsonb
case_geri_al(p_case_id uuid) :: jsonb
case_plan_notu_guncelle(p_case_id uuid, p_plan_notu text) :: jsonb
cikis_yap(p_hayvan_id text, p_cikis_tipi text, p_cikis_tarihi date, p_cikis_sebebi text, p_satis_fiyati numeric) :: jsonb
close_case(p_case_id uuid) :: jsonb
close_case_with_remaining(p_case_id uuid, p_not text) :: jsonb
create_case(p_animal_id text, p_disease_id uuid, p_notes text) :: jsonb
current_farm_id() :: uuid
delete_treatment_day(p_day_id uuid) :: jsonb
disease_ekle(p_name text, p_category text) :: jsonb
disease_guncelle(p_id uuid, p_name text, p_category text) :: jsonb
disease_sil(p_id uuid) :: jsonb
dogum_kaydet(p_anne_id text, p_tarih date, p_kupe text, p_cins text, p_tip text, p_kg numeric, p_baba text, p_hekim_id text) :: jsonb
drug_administration_stok_dusum() :: trigger
drug_class_ekle(p_group_name text, p_class_name text, p_active_ingredient text, p_kategori_id uuid) :: jsonb
drug_class_guncelle(p_id uuid, [drug_class_ekle alanları]) :: jsonb
drug_class_sil(p_id uuid) :: jsonb
drug_class_varsayilan_yukle() :: jsonb
drug_ekle(p_name text, p_default_unit text, p_default_route text, p_stock_item_id text, p_kategori text) :: jsonb
drug_guncelle(p_id uuid, [drug_ekle alanları]) :: jsonb
drug_product_ekle(p_drug_class_id uuid, p_brand_name text, p_concentration numeric, p_concentration_unit text, p_default_route text, p_default_unit text, p_stok_id uuid) :: uuid
drug_sil(p_id uuid) :: jsonb
fn_dinle_drug_admin() :: trigger
fn_dinle_uygulama() :: trigger
fn_dinle_vaccination() :: trigger
fn_gebe_gorev_yarat() :: trigger
fn_hayvan_grup_padok_sync() :: trigger
fn_islem_log() :: trigger
fn_padok_transfer_gorev_kapat() :: trigger
gebelik_kaydet_manual(p_hayvan_id text, p_tarih date, p_sperma text) :: jsonb
gebelik_protokol_kontrol() :: jsonb
geri_al(p_islem_id text) :: jsonb
get_vaccination_schedule(p_animal_id text) :: TABLE(vaccine_id uuid, vaccine_name text, disease_target text, dose numeric, unit text, route text, schedule_date date, is_due boolean, notes text)
gorev_geri_al(p_gorev_id text) :: jsonb
gorev_guncelle(p_id text, p_aciklama text, p_hedef_tarih text, p_gorev_tipi text) :: jsonb
gorev_log_cycle_guard() :: trigger
gorev_orphan_temizle() :: jsonb
gorev_tamamla(p_gorev_id text, p_padok_hedef text) :: jsonb
grup_padok_eslem_toggle(p_grup_adi text, p_padok_id uuid) :: jsonb
hastalik_guncelle(p_id text, p_tani text, p_kategori text, p_siddet text, p_semptomlar text, p_lokasyon text, p_hekim_id text, p_tarih date) :: jsonb
hastalik_kapat(p_id text) :: jsonb
hastalik_kaydet(p_hayvan_id text, p_tani text, p_kategori text, p_siddet text, p_semptomlar text, p_lokasyon text, p_hekim_id text, p_ilaclar jsonb, p_tedavi_gun integer) :: jsonb
hastalik_sil(p_id text) :: jsonb
hayvan_belirsiz_ureme_listele() :: TABLE(hayvan_id, kupe_no, grup, padok, dogum_sayisi int, tohumlama_sayisi int, son_tohumlama date)
hayvan_ekle(p_kupe_no text, p_devlet_kupe text, p_irk text, p_cinsiyet text, p_dogum_tarihi date, p_grup text, p_padok text, p_dogum_kg numeric, p_anne_id text, p_baba_bilgi text, p_canli_agirlik numeric, p_boy numeric, p_renk text, p_ayirici_ozellik text) :: jsonb
hayvan_ekle([... 14 aynı alan ..., p_padok_id uuid]) :: jsonb                       [overload 2]
hayvan_genc_anne_isaretle(p_hayvan_id text, p_genc_anne boolean) :: jsonb
hayvan_genc_anne_isaretle_toplu(p_ids text[], p_genc_anne boolean) :: jsonb
hayvan_guncelle(p_id text, p_kupe_no text, p_devlet_kupe text, p_irk text, p_cinsiyet text, p_dogum_tarihi date, p_grup text, p_padok text, p_dogum_kg numeric, p_canli_agirlik numeric, p_boy numeric, p_renk text, p_ayirici_ozellik text) :: jsonb
hayvan_guncelle([... 13 aynı ..., p_baba_bilgi text, p_notlar text, p_anne_id text, p_padok_id uuid]) :: jsonb   [overload 2]
hayvan_guncelle([... 18 aynı ..., p_kisir boolean]) :: jsonb                        [overload 3]
hayvan_kisir_isaretle(p_hayvan_id text, p_kisir boolean) :: jsonb
hayvan_not_ekle(p_hayvan_id text, p_not text) :: jsonb
hayvan_tohumlama_ertele(p_hayvan_id text, p_ay integer) :: jsonb
hayvan_tohumlanabilir_onayla(p_hayvan_id text) :: jsonb
hekim_ekle(p_ad text, p_telefon text) :: jsonb
hekim_guncelle(p_hekim_id text, p_ad text, p_telefon text, p_aktif boolean) :: jsonb
hekim_sil(p_hekim_id text) :: jsonb
hizli_uygulama(p_hayvan_id text, p_stok_id text, p_doz numeric, p_birim text, p_rota text, p_notlar text) :: jsonb
hizli_uygulama_geri_al(p_uygulama_id uuid) :: jsonb
ilac_ekle(p_urun_adi text, p_kategori text, p_birim text, p_baslangic_miktar numeric, p_esik numeric, p_drug_class_id uuid, p_concentration numeric, p_concentration_unit text, p_default_route text) :: jsonb
ileri_gebe_asi_tamamla(p_gorev_id text, p_vaccine_id uuid, p_tarih date, p_doz numeric) :: jsonb
ileri_gebe_gorev_kontrol() :: jsonb
irk_listesi() :: TABLE(irk text, tohumlama_gun int, suttten_kesme_gun int, kullanim_sayisi int)
islem_geri_al(p_islem_id text) :: jsonb
kategori_ekle(p_ad text, p_tip text) :: jsonb
kategori_guncelle(p_id uuid, p_new_ad text, p_tip text) :: jsonb
kategori_sil(p_id uuid) :: jsonb
kizginlik_kaydet(p_hayvan_id text, p_tarih date, p_belirti text, p_notlar text) :: jsonb
kizginlik_sil(p_kayit_id text) :: jsonb
kizginlik_tedavi_baglanti_kur(p_kayit_id text, p_case_id uuid) :: jsonb
kizginlik_vaka_ac(p_kizginlik_id text, p_tani text, p_tohumlama_id text, p_notlar text) :: jsonb
kizginlik_yok_kaydet(p_hayvan_id text, p_dogum_id text, p_notlar text) :: jsonb
kupe_musait_mi(p_kupe_no text, p_devlet_kupe text, p_hayvan_id text) :: jsonb
link_drug_to_stock(p_drug_id uuid, p_stock_item_id text) :: jsonb
list_vaccinations(p_animal_id text) :: TABLE(id uuid, vaccine_name text, disease_target text, vaccination_date date, dose_given numeric, unit text, route text, next_due_date date, notes text)
padok_degistir(p_hayvan_id text, p_yeni_padok_id uuid, p_not text) :: jsonb
padok_degistir_toplu(p_hayvan_ids text[], p_yeni_padok_id uuid, p_etiketler text[], p_yeni_grup text) :: jsonb
padok_ekle(p_ad text, p_kapasite integer, p_sira integer) :: jsonb
padok_guncelle(p_padok_id uuid, p_ad text, p_kapasite integer, p_sira integer, p_aktif boolean) :: jsonb
padok_sil(p_padok_id uuid) :: jsonb
padok_transfer_gorev_uzlastir() :: jsonb
planli_tohumlama_kaydet(p_gorev_id uuid, p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text, p_irk_bilgisi text, p_ek_uygulamalar jsonb, p_vwp_override boolean) :: jsonb
protokol_ayar_guncelle(p_anahtar text, p_deger numeric) :: jsonb
protokol_eksik_tara() :: jsonb
protokol_gorev_bol(p_dry_run boolean) :: jsonb
protokol_orphan_audit() :: jsonb
protokol_orphan_temizle(p_dry_run boolean) :: jsonb
recete_guncelle(p_case_id uuid, p_yeni_plan jsonb) :: jsonb
remove_drug_administration(p_admin_id uuid) :: jsonb
remove_treatment_session(p_seans_id uuid) :: jsonb
rls_auto_enable() :: event_trigger
seans_tamamla(p_seans_admin_id uuid, p_uygulanmadi boolean, p_not text) :: jsonb
search_code(query_embedding vector, match_count integer) :: TABLE(...)
search_memory_notes(query_embedding vector, match_count integer, filter_category text) :: TABLE(...)
seed_defaults(p_tip text) :: jsonb
sessiz_hayvanlar_gorev_olustur() :: integer
sessiz_hayvanlar_listele(p_padok text, p_min_gun integer) :: jsonb
sessiz_hayvanlar_reconcile() :: jsonb
set_deneme_no() :: trigger
set_treatment_day_no() :: trigger
sperma_sil(p_stok_id text) :: jsonb
stale_tohumlama_gorev_temizle() :: jsonb
stat_gebelik_ozet(p_donem_baslangic date, p_donem_bitis date, p_kategori text, p_grup text, p_sperma text) :: jsonb
stat_suru_ozet(p_padok text, p_son_donem boolean) :: jsonb
stok_arsivle(p_stok_id text) :: jsonb
stok_duzelt(p_stok_id text, p_yeni_miktar numeric, p_not text) :: jsonb
stok_ekle(p_urun_adi text, p_kategori text, p_birim text, p_baslangic_miktar numeric, p_esik numeric) :: jsonb
stok_ekleme(p_stok_id text, p_miktar numeric, p_notlar text) :: jsonb
stok_guncelle(p_stok_id text, p_urun_adi text, p_kategori text, p_birim text, p_esik numeric) :: jsonb
stok_hareket_ekle(p_stok_id text, p_tur text, p_miktar numeric, p_notlar text) :: jsonb
tedavi_ekle(p_vaka_id text, p_hayvan_id text, p_ilac_stok_id text, p_miktar numeric, p_uygulama_yolu text, p_bekleme_gun integer, p_hekim_id text, p_notlar text) :: jsonb
tedavi_guncelle(p_tedavi_id text, p_miktar numeric, p_uygulama_yolu text, p_bekleme_gun integer, p_hekim_id text, p_notlar text) :: jsonb
tedavi_sablon_kaydet(p_id uuid, p_ad text, p_aciklama text, p_disease_ids jsonb, p_kalemler jsonb) :: jsonb
tedavi_sablon_sil(p_id uuid) :: jsonb
tedavi_sablon_tohumlama_gorev_ekle(p_case_id uuid, p_sablon_id uuid) :: jsonb
tedavi_sablon_uygula(p_case_id uuid, p_sablon_id uuid) :: jsonb
tedavi_sil(p_tedavi_id text) :: jsonb
test_dollar_block() :: text
test_migrate_working() :: text
tohumlama_abort(p_tohumlama_id text, p_notlar text, p_abort_tarihi date) :: jsonb   [canlı ana imza — GT'deki 2-param'lı eski]
tohumlama_abort(p_tohumlama_id text, p_notlar text) :: jsonb                        [eski overload hâlâ duruyor]
tohumlama_cycle_gorevcil_iptal() :: trigger
tohumlama_duplicate_bekliyor_temizle() :: jsonb
tohumlama_geri_al(p_tohumlama_id text) :: jsonb
tohumlama_kaydet(p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text, p_irk_bilgisi text, p_ek_uygulamalar jsonb, p_vwp_override boolean) :: jsonb
tohumlama_orphan_gorev_temizle() :: jsonb
tohumlama_sonuc_bekliyor(p_tohumlama_id text) :: jsonb
tohumlama_sonuc_bos(p_tohumlama_id text, p_notlar text) :: jsonb
tohumlama_sonuc_gebe(p_tohumlama_id text) :: jsonb
tohumlama_tekrar_kaydet(p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text, p_irk_bilgisi text) :: jsonb
treatment_day_not_guncelle(p_day_id uuid, p_notes text) :: void
treatment_day_tamamla(p_day_id uuid, p_not text, p_uygulanmadi_ids uuid[]) :: jsonb
trg_sutten_kesme_kapat() :: trigger
trg_sutten_kesme_normalize() :: trigger
update_drug_administration(p_admin_id uuid, p_dose numeric, p_unit text, p_route text) :: jsonb
update_treatment_session(p_seans_id uuid, p_dose numeric, p_unit text, p_route text, p_planned_time text) :: jsonb
update_treatment_time(p_day_id uuid, p_treatment_time time) :: jsonb
vaccination_dismiss(p_vaccination_id uuid, p_note text) :: jsonb
vaccination_stok_dusum() :: trigger
vaccine_rapel_guncelle(p_vaccine_id uuid, p_repeat_days integer) :: jsonb
vaka_tohumlama_ekle(p_case_id uuid, p_tarih date, p_saat time) :: jsonb
```

## Tablolar — id kolonu tipi (44 tablo; tamamı canlıdan)

```
grup_padok_eslem: id uuid          | hekimler: id TEXT            | hastalik_log: id uuid
tohumlama: id uuid                  | tedavi: id uuid              | agent_plans: id uuid
stok: id TEXT                       | gorev_log: id UUID           | dogum: id uuid
hayvanlar: id TEXT                  | irk_esik: id TEXT            | kizginlik_log: id TEXT
protokol_instance: id uuid          | tedavi_sablonu_kalem: id uuid| tedavi_sablonu: id uuid
sablon_hastalik_eslem: id uuid      | stok_kategorileri: id uuid   | vaccination_log: id uuid
drug_administrations: id uuid       | diseases: id uuid            | cases: id uuid
treatment_days: id uuid             | drugs: id uuid               | goose_embeddings: id integer
protokol_dismiss: id uuid           | protokol_ayar: PK anahtar TEXT (id yok) | vaccine_diseases: composite PK (vaccine_id+disease_id)
vaccine_protocol_steps: id uuid     | stok_hareket: id UUID        | drug_products: id uuid
vaccines: id uuid                   | drug_classes: id uuid        | vaccination_schedule: id uuid
bildirim_log: id TEXT               | memory_notes: id bigint      | code_embeddings: id bigint
entity_graph: id bigint             | ui_logs: id bigint           | padoklar: id uuid
hayvan_override: PK kupe_no TEXT    | islem_log: id TEXT           | cop_kutusu: id TEXT
uygulama_log: id uuid               | treatment_day_uygulamalar: id uuid | chat: id bigint
tasks: id TEXT                      | agent_threads: id uuid       | agent_messages: id uuid
```

**DİKKAT (AGENTS.md düzeltmesine ek bulgu):** canlıda `stok_hareket.id` = **uuid** (GT:39-40 'text' demişti — docs denetimi 'text' demişti ama CANLI uuid!). `gorev_log.id`=uuid ✓, `islem_log.id`=text ✓. stok_hareket için AGENTS.md'e uuid olarak işlendi.

## View'lar (13)

cozulmemis_kizginlik_view, gebelik_ozet_view, hastalik_istatistik_view, hayvan_durum_view, hayvan_timeline_view, stok_tuketim_view, tedavi_view, tohumlanabilir_hayvanlar, treatment_timeline, v_eligible, v_gorev_log_sync, v_orphan_gorev, v_ureme_dongusu

## Trigger'lar (özet; 20260831000003 ile eklenenler dahil)

hayvanlar: trg_hayvanlar_guard(B/I, 2026-08-31), trg_hayvan_grup_padok_sync(B/I/U), trg_islem_hayvanlar(A/I), trg_hayvan_cikis_gorev_iptal, trg_padok_transfer_gorev, trg_sutten_kesme_kapat, trg_sutten_kesme_normalize
tohumlama: trg_tohumlama_guard(B/I/U, 2026-08-31), trg_deneme_no, trg_islem_tohumlama_insert/abort, trg_tohumlama_gebe_gorev, trg_tohumlama_gebe_sessiz_iptal, trg_tohumlama_sessiz_iptal, trg_tohumlama_kizginlik, tohumlama_cycle_iptal_trigger
dogum: trg_dogum_guard(B/I/U, 2026-08-31), trg_islem_dogum
gorev_log: cycle_guard(B/I), trg_gorev_parent_kapandi
islem_log: trg_islem_log_immutable(B/U/D)
cases: trg_case_ureme_sessiz_iptal, trg_kizginlik_case_close
kizginlik_log: trg_islem_kizginlik, trg_kizginlik_sessiz_iptal
hastalik_log: trg_islem_hastalik (I/U)
drug_administrations/vaccination_log/uygulama_log/treatment_days: dinleyici + stok düşüm + set_no trigger'ları
