# impl-P3a-DONE — TAMAM

- **Goal:** `G-20260930-OVSYNC-TAKIP-IMPL` · **Plan madde:** P3a (plan.md:378-397, birebir) + goal açık sözleşme maddesi B (cycle_guard muafiyeti)
- **GOREV:** `runs/2026-09-28-ovsync-takip/impl-P3a-GOREV.md` · **Tarih:** 2026-09-30
- **Sonuç:** 6/6 kabul kanıtlı — **TAMAM** (1 self-repair turu: prova betiği PERFORM→SELECT; migration dosyasına dokunulmadı, SHA sabit)

## Yazılan dosyalar (manifest 2/2)

1. `supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql` (create — SHA-256 ilk 8: `a84e248d` [OBSERVED sha256sum, db-validate raporuyla eşleşiyor]). İçerik: 3 yeni tetikleyici fonksiyon + 3 trigger (`trg_takip_yeni_tohumlama_kapat` AFTER INSERT tohumlama; `trg_takip_pg_olay_kapisi` BEFORE INSERT pg_application_event; `trg_takip_ovsync_case_kapisi` BEFORE INSERT cases) + `_trg_hayvan_cikis_gorev_iptal` CREATE OR REPLACE (canlı gövde birebir + TAKIP_MUAYENE'ye `takip_kapanis_nedeni='CIKIS'` UPDATE'i APPEND) + `gorev_log_cycle_guard` CREATE OR REPLACE (canlı gövde birebir + tek AND muafiyet) + ACL REVOKE (5 fonksiyon, GRANT yok).
2. `runs/2026-09-28-ovsync-takip/impl-P3a-DONE.md` (bu dosya).

Manifest dışı repo yazımı YOK [OBSERVED `git status --porcelain` → benimkiler yalnız yukarıdaki 2 + zaten-var-untracked GOREV zarfı; diğer M satırları diğer oturumların]. Prova betiği `/home/melik/tmp/agents/p3a-demo-prova.sh` + çıktı `/home/melik/tmp/agents/p3a-prova-cikti.txt` (repo dışı). `git diff --check` → temiz, exit 0 [OBSERVED].

## Kabul maddeleri (6/6)

### 1) db-validate.sh (worktree yolu) — PASS

[OBSERVED `bash scripts/db-validate.sh supabase/migrations/20260929000003_takip_kapanis_tetikleyicileri.sql` → "SONUÇ: PASS"; rapor `reports/db-validation-a84e248d.md`]. Fazlar: A sqlfluff/squawk PASS · B şema-uyum PASS (tüm hedefler biliniyor) · C1 baseline-restore+apply+postcheck+parite PASS (T=55 F=256 V=13, parite uyumlu, PG 17.6/17.6) · C2 sentetik-tohum+veri-uyumluluk PASS. SHA-256 raporda `a84e248dca67…` — dosya sonrası değişmedi [OBSERVED sha256sum → `a84e248d`].

### 2) Demo prova — her olay yolu tek tek (T-19..T-24) — 2. koşum TAM

[OBSERVED `/home/melik/tmp/agents/p3a-prova-cikti.txt` — apply → 12 adım → temizlik; değerler anonimsiz]:

| Senaryo | Sonuç |
|---|---|
| **T-19** tohumlama→SESSİZ+kayıtlı neden: açık takip varken 2. tohumlama INSERT hatasız; görev `iptal=t`, `takip_kapanis_nedeni=YENI_TOHUMLAMA`, `kapatan_ref=NULL` (sessiz — kapanış izi yok); islem_log farkı **1** (6202→6203, yalnız tohumlama-INSERT izi; kapanış izi 0) | PASS |
| **T-20** hızlı PG→RED: `HIZLI_UYGULAMA` event INSERT → `TAKIP_ACIK:{"muayene_saat":"09:30:00","muayene_tarihi":"2026-10-07"}`; event count **0** (INSERT olmaz) | PASS |
| **T-21** onay akışı→uygulanır+neden=PG: `SELECT _takip_kapat(id,'PG')` sonrası event INSERT GEÇTİ (count **1**); görev `neden=PG` | PASS |
| **T-22** seans/toplu aynı kapı: `TEDAVI_SEANS` RED + `TOPLU_ILAC` RED (aynı TAKIP_ACIK payload), count **0**; onay sonrası iki source_type da GEÇTİ (count **2**) | PASS |
| **T-23** Ovsync vaka→RED/onay→neden=OVSYNC: `Ovsync Protokol` hastalıklı vaka INSERT → RED; **Mastit** vaka takip açıkken GEÇTİ (count 1 — ad-çözümü ölçütü doğru seçiyor); `protocol_family='OVSYNC'` damgalı Mastit → YİNE RED (bacak 1); onay sonrası Ovsync vaka GEÇTİ (count 2) + `neden=OVSYNC` | PASS |
| **T-24** çıkış→neden=CIKIS: `durum 'Aktif'→'Satıldı'` UPDATE → takip `iptal=t`, `takip_kapanis_nedeni=CIKIS`, `kapatan_ref=hayvan-cikis`; aynı hayvandaki GEBELIK_KONTROL `iptal=t` ama `neden=NULL` (iz yalnız TAKIP_MUAYENE'ye) | PASS |

### 3) Çift olay yarışı (T-24b) — tek kapanış, ikinci tetikleyici no-op

[OBSERVED] İki eşzamanlı psql oturumu aynı hayvana iki farklı tohumlama satırı INSERT etti (exit **0/0**, hata/deadlock yok). Sonuç: 2 tohumlama satırı da kayıtlı; takip görevi **1 kez kapanmış** (`iptal=t`, `takip_kapanis_nedeni=YENI_TOHUMLAMA` tek değer; `kapanmis_gorev_sayisi=1`). Mekanizma: keşif kilitsiz; `_takip_kapat` içinde FOR NO KEY UPDATE + zaten-kapalıya-dokunma branch'i idempotentliği taşır [CONFIRMED 20260929000002:146-158].

### 4) Görev B — cycle_guard muafiyeti önce-sonra kanıtı

- **ÖNCE (muafiyetsiz canlı, apply öncesi):** Boş tohumlama + `ref_tohumlama_id`'li TAKIP_MUAYENE görev INSERT → `iptal=t` [OBSERVED `ONCE-guard|t`] — P2b bulgusu birebir doğrulandı (görev kurulduğu an iptal; impl-P2b-DONE.md:118).
- **SONRA (muafiyetli):** aynı senaryo → `iptal=f` [OBSERVED `SONRA-guard-takip|f`] — takip zinciri artık demo'da kurulabilir.
- **Ters-davranış koruması:** aynı hayvanda GEBELIK_KONTROL + Boş-ref → `iptal=t` [OBSERVED `SONRA-guard-gebelik|t`] — muafiyet yalnız TAKIP_MUAYENE; diğer tipler eski davranışta. Muafiyet yazımı: canlı gövdeye tek `AND COALESCE(NEW.gorev_tipi,'') <> 'TAKIP_MUAYENE'` [CONFIRMED migration:283; canlı gövde pg_get_functiondef ile okundu 2026-09-30].
- **Demo gerçek-akış kanıtı:** T-19..T-24'teki açık takip görevlerinin tamamı muafiyet sayesinde `iptal=false` kuruldu ve senaryolar ilerledi (muafiyetsizde TAKIP_KAPALI kilitlenmesi P2b'de gözlenmişti).

### 5) Ad-çözümü kararı — demo ölçüm kanıtı

Demo ölçümleri (2026-09-30, canlı demo) [OBSERVED]:

| Ölçüm | Çıktı |
|---|---|
| `diseases WHERE name ILIKE '%ovsync%'` | **tek kayıt**: `Ovsync Protokol` (id `c346e115-35ff-4430-92b8-874c505d857e`, kategori `Üreme`, 35 vaka); `'Ovsync'` adında hastalık YOK |
| `cases GROUP BY protocol_family, status` | **148/148 NULL** (NULL|active|31 + NULL|closed|117) — p5b S-3 backfill demo'da etkisiz |
| Ovsync vakaları `protocol_family='OVSYNC'` kırılımı | 0 satır (boş) |
| `protocol_family NULL` + Ovsync-adlı hastalığa bağlı vaka | 35 (tümü name üzerinden bağlı) |
| `public._ovsync_hastalik_mi('c346e115-…')` (şablon-eşleme otoritesi, 20260925000018) | **f** — demo'da `sablon_hastalik_eslem`→`protokol_ailesi` eşlemesi yok |

**KARAR — üç-bacaklı OR ölçütü** (`NEW.protocol_family='OVSYNC' OR public._ovsync_hastalik_mi(NEW.disease_id) OR diseases.name ILIKE 'ovsync%'` [CONFIRMED migration:189-196]): planın `diseases.name='Ovsync'` ölçütü demo'da 0 vaka tutacaktı (ad `Ovsync Protokol`); `protocol_family` tek başına da 0 (148/148 NULL); otorite fonksiyon tek başına da 0 (demo'da şablon eşlemesi yok). Üç bacak birlikte: bacak 1 (damga) yeni yolların açık etiketi — kanıtı T-23'te damgalı Mastit vaka RED yedi; bacak 2 prod otoritesi (kısır guard'ın 8 giriş yolunda kullandığı fonksiyon — tutarlılık); bacak 3 demo gerçekliği — kanıtı T-23'te `Ovsync Protokol` vaka RED yedi, Mastit geçti. OR birleşimi fazla-ret yönünde hata yapar (yanlış Ovsync-sanma → TAKIP_ACIK onay kapısı; az-ret kapanış kaçırtır) — güvenli tarafa hata. `ILIKE 'ovsync%'` prefix'i `'Ovsync'` (prod olası ad) + `'Ovsync Protokol'` (demo) ikisini kapsar; demo'da ovsync-prefix'li başka kayıt yok [OBSERVED ILIKE '%ovsync%' = 1 kayıt].

### 6) `git diff --check` temiz + anon/PUBLIC EXECUTE yok

- [OBSERVED `git diff --check` → boş çıktı, exit 0].
- ACL: 5 trigger fonksiyonu × (anon, authenticated, public) `has_function_privilege(...,'EXECUTE')` → **15×f** [OBSERVED prova adım 3] — REVOKE satırları [CONFIRMED migration:306-310]; GRANT satırı YOK. Not: `_trg_hayvan_cikis_gorev_iptal` ve `gorev_log_cycle_guard` canlıda varsayılan PUBLIC EXECUTE taşıyordu; bu migration DEGISMEZ 8 hizasına çeker (trigger mekanizması EXECUTE hakkı aramaz — davranış değişmez).

## PostgreSQL LSP (zorunlu sahip talimatı)

- [OBSERVED `postgrestools check --config-path=/home/melik/egesut-erp1/postgres-language-server.jsonc supabase/migrations/20260929000003_….sql` → "Checked 1 file", **exit 0**, hata yok].
- [OBSERVED built-in LSP `hover` → sunucu çalışıyor ama dosya-sync hatası ("Cannot send notification… server is running") — P1/P2b'deki bilinen sunucu durumu; CLI check aynı çözümleme motoruyla statik kanıt verir].
- Canlı gövde okumaları (ayna trigger'ları taşımaz): `pg_get_functiondef`/`pg_get_triggerdef` ile demo'dan okundu — `gorev_log_cycle_guard()`, `_trg_hayvan_cikis_gorev_iptal()`, tohumlama/cases/pg_application_event trigger envanterleri, `_ovsync_hastalik_mi`, `_sessiz_gorev_iptal` (TAKIP_MUAYENE'ye dokunmuyor — komşu tetikleyiciler sessiz kırmıyor [OBSERVED]).

## Tetikleyici sözleşme doğrulamaları (zarf A.6/A.7)

- **H3 hayvan kilidi YOK:** kapatıcı tetikleyici hayvanlar tablosuna SELECT FOR … YAZMADI [CONFIRMED migration gövdesi]; kapanış `_takip_kapat` üzerinden yalnız gorev_log satırını FOR NO KEY UPDATE kilitler. Ret tetikleyicileri yalnız okur + RAISE [CONFIRMED gövde, SELECTsuz lock yok]. AFTER INSERT anında tohumlama satırı ekleyen transaction'ın kilidinde → yön kuralı (tohumlama önce, gorev_log sonra) korunur.
- **MK9-K bayraktan bağımsız:** kanıt T-12 adımı — `protokol_ayar.ovsync_pg_kurallari_aktif = 0` iken tohumlama INSERT → kapanış YİNE çalıştı (`neden=YENI_TOHUMLAMA`) [OBSERVED `MK9K-sonuc|t|YENI_TOHUMLAMA`]. Hiçbir tetikleyici protokol_ayar OKUMAZ [CONFIRMED gövde].
- **Geri-al yolu yeniden açmaz:** `geri_alindi_at` hiçbir tetikleyicide okunmaz/kullanılmaz [CONFIRMED gövde] — kapanış kalıcı (takip görevi iptal satırı olarak kalır; yeni açılış yalnız Boş-sonrası-devam seçimiyle).
- **Parametre yok (DEGISMEZ 4):** tetikleyici fonksiyonları parametresiz; `_pg_olay_isle`/`hizli_uygulama`/`seans_tamamla`/`bulk_ilac` gövde değişikliği YOK [CONFIRMED migration yalnız 5 fonksiyon + 3 trigger içeriyor].

## Self-repair izi (1 tur; sınır 2)

- Tur 1 — **prova betiği** hatası (migration değil): `PERFORM public._takip_kapat(...)` psql/SQL'de geçersiz (PL/pgSQL deyimi) → T-21/T-22/T-23'ün onay ayakları 1. koşumda syntax error aldı. `SELECT`-e çevrildi; betik BAŞTAN koşuldu (apply idempotent; ROLLBACK'li bloklar iz bırakmaz — baseline sayılar eş). 2. koşum TAM PASS. Migration dosyası tüm turda sabit (`a84e248d`).

## Açık kalemler (BLOKE değil)

1. **Demo'da P3a nesneleri prova sonrası DROPLANDI** (P1/P2b kalıbı; temizlik `fn-kaldi=0, trg-kaldi=0` [OBSERVED]; demo baseline sayılara döndü: tohumlama 302, gorev_log 3707, cases 148, pg_event 0, E2E marker 0; cycle_guard muafiyetsiz gövdeye döndü [OBSERVED pg_get_functiondef]). P12 demo E2E öncesi SQL zinciri (P1..P3a) demo'ya bütünsel apply edilmeli (mimar karar noktası).
2. **TAKIP_ACIK payload alan sırası** jsonb anahtar-sıralamasına tabi (çıktıda `muayene_saat` önce basıldı) — alan adları P2b kalıbıyla birebir; H5 makine-okunur sabitleme P3b başında (goal açık sözleşme girdisi).
3. **Ç5 yarış çifti (sarmal × kapanış tetikleyicisi)** — P2b'den plan-sırasıyla erteli; T-24b tetikleyici×tetikleyici yarışı burada koşuldu; sarmal etkileşimli çift P3b sonrası koşulacak (P2b-DONE kalem 3).
4. Kısır+takip-açık hayvanda cases BEFORE INSERT sırası: `trg_cases_kisir_ovsync` ('k'<'t' alfabetik) önce çalışır → red mesajı kısır gerekçesi olur (ret yine garanti; §18.5 esnetilmez). Belgeli tasarım notu, iş kalemi değil.
