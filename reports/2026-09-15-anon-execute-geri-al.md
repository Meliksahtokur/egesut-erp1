# S1 — anon/PUBLIC EXECUTE geri alma (2026-09-15)

Worker: glmf (anon-revoke workspace) · Sahip onayı: 2026-09-15 (zarf
`.ss/tasks/S1-anon-revoke.md`) · Yalnız yetki değişikliği — DROP/RENAME/TRUNCATE yok, veri yok.

**Sonuç: PROD'da anon ve PUBLIC'e EXECUTE açık public fonksiyon sayısı 67 → 0.
Authenticated erişimi kesintisiz (206 → 221, azalma 0; +15 artış genel GRANT
kalkanının fonksiyon-tek genişlemesidir, kayıp yok).**

## 1. Kapsam ölçümü (salt okunur, uygulama öncesi)

Sorgu: `pg_proc` × `pg_namespace` (public şema) ×
`has_function_privilege(<rol>, p.oid, 'EXECUTE')`.

| Proje | anon-EXECUTE'lu public fn | SECURITY DEFINER | SECURITY DEFINER değil |
|---|---|---|---|
| Prod (zqnexqbd…) | **67** | 53 | 14 |
| Demo (vtzqjma…) | 72 | 53 | 19 |

- Prod 53 SECURITY DEFINER sayısı, root'un 2026-09-15 ölçümüyle (zarf bağlamı) birebir aynı.
- **Demo–prod farkı (5):** demo'daki 5 fazlası `postgres_fdw_*` extension
  fonksiyonları (postgres_fdw extension'u demo'da kurulu, prod'da değil). Aşağıda §4'teki istisna.
- Prod'da `asistan_sql_calistir(p_sql text)` ve `get_vaccination_schedule(text)`
  PUBLIC'ten kapalıyken doğrudan `GRANT … TO anon` almıştı — REVOKE ile kapatıldı.
- Prod'daki 67 fonksiyonun tamamının sahibi `postgres` (uygulama öncesi ölçüm) →
  REVOKE'ların işleyeceği garanti.

Tam kapsam listesi (ad + imza): aşağıda §6 (67 satır) ve
`~/tmp/agents/anon-revoke-2026-09-15/before.json` (repo dışı ham çıktı).

## 2. Migration

`supabase/migrations/20260915000001_anon_execute_geri_al.sql` (99 satır):

1. 67 fonksiyon için `REVOKE ALL ON FUNCTION public.<ad>(<imza>) FROM anon, PUBLIC;`
   — imzalar prod ölçümünden `pg_get_function_identity_arguments` ile alındı (overload'lar ayrı satır).
2. Genel kalkan: `REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon, PUBLIC;`
3. `ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon/PUBLIC;`
   (lockdown `20260614000007` ile aynı desen — gelecek fonksiyonlar anon'a açılmasın)
4. `GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO authenticated;` (lockdown deseni)

`authenticated` GRANT'larına dokunulmadı; kapanışta genel GRANT yeniden verildi.
Demo ile prod **aynı dosya** uygulandı.

## 3. Demo doğrulama (uygulamadan prod'a geçmeden)

Mgmt API `/v1/projects/<demo_ref>/database/query`, migration tek istekte
(tek transaction) uygulandı → `[]` (hata yok).

| Ölçüt | Öncesi | Sonrası | Sonuç |
|---|---|---|---|
| anon EXECUTE'lu public fn | 72 | 5 (yalnız §4 istisnası) | ✅ (kapatılabilir her şey kapandı) |
| PUBLIC EXECUTE'lu public fn | 72 | 5 | ✅ |
| authenticated EXECUTE'lu | 226 | 226 (toplam fn 226) | ✅ azalma 0 |
| 10 örnek fonksiyon (tohumlama_kaydet, dogum_kaydet, vaka_toplu_ac, hayvan_kilo_guncelle, asi_ekle, gorev_tamamla, tedavi_sablon_uygula, buzagi_sutten_kesme_onayla, asistan_plan_olustur, irk_listesi) | — | `auth=true`, `anon=false` | ✅ |

**Canlı kırılma testi (demo PostgREST):**

| Çağrı | Rol | Sonuç |
|---|---|---|
| `POST /rest/v1/rpc/irk_listesi` | authenticated (demo kullanıcı, password grant) | **HTTP 200** — veri döndü ✅ |
| `POST /rest/v1/rpc/irk_listesi` | anon (yalnız anon key) | **HTTP 401** `42501 permission denied for function irk_listesi` ✅ (beklenen) |

Kırılma authenticated'ta OLMADI → prod geçişine izin.

## 4. Teknik istisna (ölçülmüş sınır): demo'daki 5 postgres_fdw fonksiyonu

Demo'da `postgres_fdw_*` 5 extension fonksiyonu (`disconnect(text)`,
`disconnect_all()`, `get_connections(OUT…)`, `handler()`, `validator(text[], oid)`)
kapatılamadı — kanıtlı neden:

- Fonksiyon sahibi ve grant veren: `supabase_admin` (`proacl = {=X/supabase_admin,…}`).
- `postgres` rolü başka rolün grant'ini geri alamıyor (REVOKE sessiz geçiyor, proacl değişmiyor — ölçüldü).
- `SET ROLE supabase_admin` → `ERROR: 42501 permission denied to set role` (ölçüldü).
- Bu 5 fonksiyon **prod'da yok**; Supabase platformunun standart extension kalıbı, app'te hiç kullanılmıyor.

Bu istisna demo ölçütü "anon fn = 0"da ölçülmüş platform sınırıdır; prod
kapsamına etkisi yoktur (prod'da bu fonksiyonlar bulunmadığından prod 0'a ulaştı).

## 5. Prod uygulama ve doğrulama

Uygulama öncesi anon-açık liste `~/tmp/agents/anon-revoke-2026-09-15/before.json`
(repo dışı, ad+imza+secdef; yedek gerekmez — yalnız yetki, veri/DDL yok).
Migration prod'a tek istekte (tek transaction) uygulandı → `[]` (hata yok).

| Ölçüt | Öncesi | Sonrası | Sonuç |
|---|---|---|---|
| anon EXECUTE'lu public fn | 67 | **0** | ✅ |
| PUBLIC EXECUTE'lu public fn | 54 | **0** | ✅ |
| authenticated EXECUTE'lu | 206 (toplam 221) | 221 (toplam 221) | ✅ azalma 0; +15 genel GRANT kalkanından (fonksiyon-tek grant'i olmayan 15 fn authenticated'a açıldı — lockdown deseni) |
| Hedef 67 fonksiyon denetimi | — | `anon=false` VE `authenticated=true` bozan: **0** | ✅ (53 SECURITY DEFINER dahil) |

Denetim sorgusu, hedef listedeki 67 fonksiyonun her biri için
`has_function_privilege('anon'|'authenticated', p.oid, 'EXECUTE')` döndü; kural
bozan tek satır yok (`[]`).

## 6. Kapsam listesi (prod, uygulama öncesi — ad + imza + secdef)

- `_asistan_ref_coz(p_param jsonb, p_ctx jsonb)` — SECURITY DEFINER: **false**
- `_asistan_step_calistir(p_tip text, p_param jsonb)` — SECURITY DEFINER: **false**
- `_asistan_step_dogrula(p_tip text, p_param jsonb)` — SECURITY DEFINER: **false**
- `_ayar(p_anahtar text, p_varsayilan numeric)` — SECURITY DEFINER: **false**
- `_etken_kod_bul(p_stok_id text, p_vaccine_id uuid)` — SECURITY DEFINER: **true**
- `_gorev_dinle(p_hayvan_id text, p_etken_kod text, p_ref text, p_tarih date)` — SECURITY DEFINER: **true**
- `_guard_dogum_ileri_tarih()` — SECURITY DEFINER: **false**
- `_guard_hayvanlar_cinsiyet_grup()` — SECURITY DEFINER: **false**
- `_guard_tohumlama_yas_cinsiyet()` — SECURITY DEFINER: **false**
- `_islem_log_immutable_guard()` — SECURITY DEFINER: **false**
- `_tohumlama_gorev_uygunluk(p_hayvan_id text, p_tarih date)` — SECURITY DEFINER: **true**
- `_trg_gorev_parent_kapandi()` — SECURITY DEFINER: **false**
- `_trg_hayvan_cikis_gorev_iptal()` — SECURITY DEFINER: **false**
- `_vaka_ac_tek(p_hayvan_id text, p_disease_id uuid, p_notes text, p_tarih date)` — SECURITY DEFINER: **true**
- `add_vaccination(p_animal_id text, p_vaccine_id uuid, p_date date, p_dose_override numeric, p_notes text, p_next_offset_days integer)` — SECURITY DEFINER: **true**
- `agent_plans_prune()` — SECURITY DEFINER: **true**
- `agent_threads_prune()` — SECURITY DEFINER: **true**
- `asi_ekle(p_name text, p_marka text, p_etken_madde text, p_dose numeric, p_unit text, p_route text, p_is_mandatory boolean, p_disease_ids uuid[], p_protokol_tipi text, p_protokol_adimlar jsonb, p_repeat_interval_days integer, p_baslangic_stok numeric, p_esik numeric)` — SECURITY DEFINER: **true**
- `asi_gorev_planla(p_hayvan_id text, p_vaccine_id uuid, p_doz numeric, p_tarih date, p_aciklama text)` — SECURITY DEFINER: **true**
- `asi_guncelle(p_vaccine_id uuid, p_name text, p_marka text, p_etken_madde text, p_dose numeric, p_unit text, p_route text, p_is_mandatory boolean, p_disease_ids uuid[], p_protokol_tipi text, p_protokol_adimlar jsonb, p_repeat_interval_days integer, p_baslangic_stok numeric, p_esik numeric)` — SECURITY DEFINER: **true**
- `asi_planli_tamamla(p_gorev_id text, p_tarih date, p_doz numeric, p_vaccine_id uuid)` — SECURITY DEFINER: **true**
- `asi_sil(p_vaccine_id uuid)` — SECURITY DEFINER: **true**
- `asi_toplu_planla(p_hayvan_id text, p_tarih date, p_items jsonb, p_aciklama text)` — SECURITY DEFINER: **true**
- `asistan_hayvan_detay(p_kupe text, p_id text)` — SECURITY DEFINER: **true**
- `asistan_plan_geri_al(p_plan_id uuid)` — SECURITY DEFINER: **true**
- `asistan_plan_iptal(p_plan_id uuid)` — SECURITY DEFINER: **true**
- `asistan_plan_olustur(p_thread_id uuid, p_adimlar jsonb)` — SECURITY DEFINER: **true**
- `asistan_plan_uygula(p_plan_id uuid)` — SECURITY DEFINER: **true**
- `asistan_sql_calistir(p_sql text)` — SECURITY DEFINER: **false**
- `asistan_tumunu_sil()` — SECURITY DEFINER: **true**
- `buzagi_sutten_kesme_geri_al(p_hayvan_id text)` — SECURITY DEFINER: **true**
- `buzagi_sutten_kesme_kontrol()` — SECURITY DEFINER: **true**
- `buzagi_sutten_kesme_onayla(p_hayvan_id text, p_tarih date)` — SECURITY DEFINER: **true**
- `buzagi_sutten_kesme_toplu(p_hayvan_idler text[], p_tarih date)` — SECURITY DEFINER: **true**
- `create_case(p_animal_id text, p_disease_id uuid, p_notes text)` — SECURITY DEFINER: **true**
- `dogum_kaydet(p_anne_id text, p_tarih date, p_kupe text, p_cins text, p_tip text, p_kg numeric, p_baba text, p_hekim_id text)` — SECURITY DEFINER: **true**
- `fn_gorev_asip_iade()` — SECURITY DEFINER: **true**
- `fn_padok_transfer_gorev_kapat()` — SECURITY DEFINER: **true**
- `gebelik_protokol_kontrol()` — SECURITY DEFINER: **true**
- `get_vaccination_schedule(p_animal_id text)` — SECURITY DEFINER: **false**
- `gorev_geri_al(p_gorev_id text)` — SECURITY DEFINER: **true**
- `gorev_orphan_temizle()` — SECURITY DEFINER: **true**
- `gorev_tamamla(p_gorev_id text, p_padok_hedef text)` — SECURITY DEFINER: **true**
- `hayvan_belirsiz_ureme_listele()` — SECURITY DEFINER: **true**
- `hayvan_kilo_guncelle(p_id text, p_canli_agirlik numeric)` — SECURITY DEFINER: **true**
- `ilac_dozaj_guncelle(p_id uuid, p_guncellemeler jsonb)` — SECURITY DEFINER: **true**
- `ilac_ekle(p_urun_adi text, p_kategori text, p_birim text, p_baslangic_miktar numeric, p_esik numeric, p_drug_class_id uuid, p_concentration numeric, p_concentration_unit text, p_default_route text)` — SECURITY DEFINER: **true**
- `padok_degistir_toplu(p_hayvan_ids text[], p_yeni_padok_id uuid, p_etiketler text[], p_yeni_grup text)` — SECURITY DEFINER: **true**
- `padok_transfer_gorev_uzlastir()` — SECURITY DEFINER: **true**
- `planli_tohumlama_kaydet(p_gorev_id uuid, p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text, p_irk_bilgisi text, p_ek_uygulamalar jsonb, p_vwp_override boolean)` — SECURITY DEFINER: **true**
- `protokol_ayar_guncelle(p_anahtar text, p_deger numeric)` — SECURITY DEFINER: **true**
- `protokol_eksik_tara()` — SECURITY DEFINER: **true**
- `protokol_gorev_bol(p_dry_run boolean)` — SECURITY DEFINER: **true**
- `protokol_orphan_audit()` — SECURITY DEFINER: **true**
- `protokol_orphan_temizle(p_dry_run boolean)` — SECURITY DEFINER: **true**
- `sessiz_hayvanlar_reconcile()` — SECURITY DEFINER: **true**
- `tedavi_sablon_kaydet(p_id uuid, p_ad text, p_aciklama text, p_disease_ids jsonb, p_kalemler jsonb)` — SECURITY DEFINER: **true**
- `tedavi_sablon_tohumlama_gorev_ekle(p_case_id uuid, p_sablon_id uuid, p_baslangic_tarihi date)` — SECURITY DEFINER: **true**
- `tedavi_sablon_uygula(p_case_id uuid, p_sablon_id uuid, p_baslangic_tarihi date)` — SECURITY DEFINER: **true**
- `tohumlama_abort(p_tohumlama_id text, p_notlar text, p_abort_tarihi date)` — SECURITY DEFINER: **true**
- `tohumlama_duplicate_bekliyor_temizle()` — SECURITY DEFINER: **true**
- `tohumlama_kaydet(p_hayvan_id text, p_tarih date, p_sperma text, p_hekim_id text, p_irk_bilgisi text, p_ek_uygulamalar jsonb, p_vwp_override boolean)` — SECURITY DEFINER: **true**
- `tohumlama_orphan_gorev_temizle()` — SECURITY DEFINER: **true**
- `trg_sutten_kesme_kapat()` — SECURITY DEFINER: **false**
- `trg_sutten_kesme_normalize()` — SECURITY DEFINER: **false**
- `vaka_tohumlama_ekle(p_case_id uuid, p_tarih date, p_saat time without time zone)` — SECURITY DEFINER: **true**
- `vaka_toplu_ac(p_animal_ids text[], p_disease_id uuid, p_items jsonb, p_sablon_id uuid, p_notes text, p_tarih date, p_tohumlama boolean, p_tohumlama_gun_offset integer, p_tohumlama_saat text, p_tohumlama_cakisma text)` — SECURITY DEFINER: **true**

## 7. Notlar ve kanıt dosyaları

- **schema_migrations kaydı ve GT yenileme bu işte yapılmadı** (zarf: ayrı iş, D3 dalgası). Prod `schema_migrations`'a bu migration kaydedilmedi.
- Ham çıktılar (repo dışı): `~/tmp/agents/anon-revoke-2026-09-15/` —
  `prod-before.json` (67), `demo-before.json` (72), `before.json` (ad+imza),
  `prod-verify-before.json`, `prod-verify-after.json`, `prod-verify67.json` (boş = kural bozan yok),
  `demo-verify.json`, `demo-verify10.json`, `demo-rpc-auth.json` (200), `demo-rpc-anon.json` (401).
- Ders: REVOKE imzasında `DEFAULT` kabul edilmiyor (yerel Postgres'te ölçüldü);
  bu migration'ın imzalarında DEFAULT/OUT yoktu (jq denetimi), sorun çıkarmadı.
- Ders: `REVOKE ALL ON ALL FUNCTIONS IN SCHEMA` başka rolün (supabase_admin)
  grant'lerine işlemiyor — hata vermeden sessiz geçiyor; doğrulama mutlaka
  `has_function_privilege` ile sayım yoluyla yapılmalı.
