# K2 (goal kalem 2) — GT refresh DONE

Tarih: 2026-10-02 | Dal: ovsync-sonrasi | Yazan: Sonnet alt-ajan | Prod: YALNIZ SELECT (Mgmt API curl)

## GT dosyası
`/home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi/supabase/migrations/99999999999999_ground_truth.sql`
(`Tarih:` başlığı 2026-09-15 -> 2026-10-02; "Son senkron" satırı K2'ye güncellendi; git add/commit YAPILMADI.)

## Yöntem seçimi: NESNE-BAZLI YAMA (tam regen değil)
- Repoda tanımlı kısa/güvenli "tam regen prosedürü" yok (runbook adım 6 yalnız "nesneler GT'ye girer veya tam regen" der; regen betiği yok) [OBSERVED: grep .harness/runbooks/db-migration.md, scripts/].
- GT canlıdan 92 farkla geride (`scripts/ground-truth-audit.sh`); farkların çoğu 6 migration DIŞI (20260915-20260927: gorev_ertele_*, _pg_*, ovsync_baslat_*, trg_degisim_log vb.). Tam regen bunları da değiştirirdi = kapsam dışı + riskli [OBSERVED audit çıktısı].
- Bu yüzden GT sonuna (S1 kalkanından SONRA) "SENKRON 2026-10-02 (K2)" bölümü eklendi; mevcut G1 incremental deseni (başlık bloğu, `-- FUNCTION: public.ad(args)` + canlı `pg_get_functiondef` + `;`, `DROP TRIGGER IF EXISTS`+`pg_get_triggerdef`) birebir kullanıldı. Mevcut GT satırlarına dokunulmadı (yalnız 2 başlık satırı).

## Eşlenen 6 migration (prod schema_migrations son satırlar, count=159) [OBSERVED]
20260929000001 ovsync_takip_listele | 20260929000002 takip_gorev_ve_bos_devam | 20260929000003 takip_kapanis_tetikleyicileri | 20260929000004 tohumlama_gebelik_gorev_kaldir | 20260929000005 gebelik_gorev_temizlik | 20261001000001 takip_yerel_gun_duzeltme

## Eklenen / değişen nesneler (hepsi canlı pg_catalog'dan)
- Kolon: `gorev_log.takip_kapanis_nedeni text` + COLUMN COMMENT.
- Fonksiyon (21, her biri canlıda tek overload):
  - YENİ (10): ovsync_takip_listele(text,int), _takip_gorev_kur(uuid,text,int,time), _takip_kapat(uuid,text), _acik_disi_hedef_ic(text), _tohumlama_gebe_uygula(text,bool), tohumlama_bos_ve_devam(text,uuid,text,text,numeric,int,time,text,bool), _trg_takip_yeni_tohumlama_kapat(), _trg_takip_pg_olay_kapisi(), _trg_takip_ovsync_case_kapisi(), start_first_service_protocol(uuid,bool)
  - GÖVDE DEĞİŞTİ, imza aynı (4): tohumlama_sonuc_gebe(text), tohumlama_kaydet(text,date,text,text,text,jsonb,bool), _trg_hayvan_cikis_gorev_iptal(), gorev_log_cycle_guard()
  - İMZA GEÇİŞİ (7, canlı yeni imza; GT'deki eski overload DROP satırı eklendi): gorev_tamamla(text,text,bool), hizli_uygulama(10 arg), seans_tamamla(6 arg), bulk_ilac(7 arg), create_case(4 arg), vaka_toplu_ac(11 arg), kizginlik_vaka_ac(5 arg)
  - Eski overload DROP (7): bulk_ilac(text[],text,numeric,text), create_case(text,uuid,text), gorev_tamamla(text,text), hizli_uygulama(6 arg), kizginlik_vaka_ac(4 arg), seans_tamamla(uuid,bool,text), vaka_toplu_ac(10 arg) — GT'de efektif olarak var olup canlıda olmayanlar (simülasyonla bulundu).
- Trigger (3 yeni): trg_takip_yeni_tohumlama_kapat (tohumlama), trg_takip_pg_olay_kapisi (pg_application_event), trg_takip_ovsync_case_kapisi (cases). trg_hayvan_cikis_gorev_iptal ve gorev_log_cycle_guard_trigger GT'de zaten vardı, tanım değişmedi.
- ACL: 21 fonksiyon için canlı proacl aynası (REVOKE ALL FROM PUBLIC, anon, authenticated + GRANT EXECUTE kalan alıcılara; iç yardımcılar yalnız service_role, anon/PUBLIC hiçbirinde yok).
- COMMENT ON FUNCTION: canlıda açıklaması olan 11 fonksiyon.
- Alınmayanlar (bilinçli): gorev_ertele_kural TAKIP_MUAYENE seed satırı (VERİ; tablo GT'de henüz yok); 20260929000005 gorev_log DML temizliği (şema nesnesi değil).

## Kullanılan SELECT'ler (hepsi POST /v1/projects/<ref>/database/query, salt-okunur)
1. `select version,name from supabase_migrations.schema_migrations order by version desc limit 14` + `select count(*)` (159)
2. `pg_proc ⨝ pg_namespace`: proname, pg_get_function_identity_arguments, pg_get_functiondef, proacl::text, obj_description, pg_get_userbyid(proowner), prosecdef — 21 isim, schema public
3. `oidvectortypes(proargtypes)`, `md5(pg_get_functiondef(oid))` — aynı 21 isim
4. `pg_trigger ⨝ pg_class ⨝ pg_proc` + pg_get_triggerdef (not tgisinternal, tgfoid ∈ 21 isim)
5. `information_schema.columns` + `col_description` (gorev_log)
6. Aynı 21 ismin public dışı şemada olmadığı kontrolü
7. `scripts/ground-truth-audit.sh` içindeki SELECT'ler (tablo/view/fn/trigger envanteri; before/after)

## Doğrulama
- GT yapıştırılan 21 fonksiyon bloğunun md5'i canlı `md5(pg_get_functiondef)` ile 21/21 eşleşti [OBSERVED].
- `scripts/ground-truth-audit.sh` (worktree kopyası): 92 fark -> 79 fark. Kapanan 13 = tam olarak 10 fonksiyon (_acik_disi_hedef_ic, ovsync_takip_listele, start_first_service_protocol, _takip_gorev_kur, _takip_kapat, tohumlama_bos_ve_devam, _tohumlama_gebe_uygula, 3 _trg_takip_*) + 3 trigger bağlantısı; bu 6 migration'ın hiçbir nesnesi artık "eksik" listesinde değil [OBSERVED, before/after diff]. Kayıtlar: `~/tmp/gt-audit-before.txt`, `~/tmp/gt-audit-after.txt`.
- GT dosyası SQL olarak çalıştırılmadı (referans dosya; parse/replay doğrulaması yapılmadı) [UNKNOWN: yerel PG'de sözdizimi replay'i].

## BAKİYE (K2 kapsamı dışı, GT hâlâ geride — audit 79 fark)
Eksik tablo: gorev_ertele_kural, pg_application_event; fazla tablo: surum_gizli; 34 eksik fonksiyon (gorev_ertele*, _ovsync_*, _pg_*, protokol_iptal, ilk_tohumlama_zamanlayici, gebelik_muayene_* vb.); 41 eksik trigger bağlantısı (trg_degisim_log x~37, trg_cases_kisir_ovsync, trg_drug_classes_sistem_koru, trg_uygulama_log_pg_geri_al). Bunlar 20260915-20260927 migration'larından; ayrı GT senkron kalemi önerilir (kapsam sahip kararı). Aynı sebeple `tohumlama_kaydet` vb. gövdeler artık canlıyla aynı ama bağımlı bazı yardımcılar GT'de yok.

## git diff --stat (worktree)
```
 supabase/migrations/99999999999999_ground_truth.sql | 3558 +++++-  (3556 ekleme, 2 silme = 2 başlık satırı)
 js/ui.js (48), tests/e2e/ovsync-takip.spec.js (96), untracked tests/unit/ovsync-render-zamanasimi.test.js  <- BEN YAZMADIM (paralel kalemler; son git diff --stat: 3 dosya, 3663+/39-)
```

SONUC: TAMAM
