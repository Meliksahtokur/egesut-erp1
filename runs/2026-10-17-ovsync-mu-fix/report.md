# ovsync-mu-fix report (worker a6b6376bc95fb318a, ss-worker-high opus)

> Root yazdı (2026-10-17): alt ajanın rapor dosyası yazması araçla engellendi
> ("Subagents should return findings as text, not write report files."); içerik
> worker'ın iki dönüş metninden birebir aktarıldı.

sonuc: TAMAM
kabul SHA: 4163167 (dal fix/ovsync-mu-log-kolu; taban 56900c3)
Commit'ler: e7ba499 SQL test (kırmızı 8/11) · c38f0e3 migration · b48a0ba kanıt · d68be34 JS test (kırmızı) · 51389be JS fix + k10 testleri + ?v=20261017-01 · 074343e git mv → 20261017100001 · 4163167 kanıt
BOYUT: migration 52 (≤80) · SQL test 94 (≤150) · ui.js +6/−2 (≤40) · JS test 59 (≤80) · iki eski testte 3 satır

## Ana bulgu (MEASURED)
Prod'da 5 vaka yanlış Ovsync sayılıyor (46 → 41). Açık 2'si aynı hayvanda (197): Klinik Mastit 232e7f7d, İnaktif Ovaryum aad17352. Veri bozulmadı: hiçbiri ERKEN_KAPANIS ile kapanmamış, hiçbirine hastalık günü açılmamış.

| vaka | hastalık | durum | log | bugün yanlış olan |
|---|---|---|---|---|
| aad17352 | İnaktif Ovaryum | açık | `:MANUEL` | hastalık günü kabul edilir; kısır işaretlenirse kapanır |
| 232e7f7d | Klinik Mastit | açık | NULL aileli şablon, iptal=true | aynı iki risk |
| 0a23bc51 | İnaktif Ovaryum | kapalı | `:MANUEL` | etkisi yok |
| 375a8d6a | Neonatal Zayıflık | kapalı | NULL aileli şablon, iptal=true | etkisi yok |
| 1f03f184 | Tırnak Yarası | kapalı | NULL aileli şablon, iptal=true | etkisi yok |

Prod'daki 23 iptal edilmiş OVSYNC şablon logunun hepsi zaten Ovsync damgalı vakalarda; `iptal=false` gerçek Ovsync vakasını düşürmüyor. İptali NULL log yok.

## Değişiklik
- `supabase/migrations/20261017100001_ovsync_mu_log_kolu.sql`: log kolu yalnız anahtardaki şablon OVSYNC ve log iptal değilse (`JOIN tedavi_sablonu t ON t.id::text = split_part(g.kaynak,':',3)` + `t.protokol_ailesi='OVSYNC'` + `g.iptal = false`). protocol_family ve hastalık eşlemesi kolları aynen; STABLE, DEFINER, search_path, REVOKE PUBLIC/anon/authenticated, GRANT yalnız service_role.
- `tests/sql/ovsync_mu_log_kolu_test.sql`: 11 senaryo.
- `js/ui.js` `_hastalikKabulMu`: log kolu yalnız `g.iptal===false` ve `kaynak` şablon id'si OVSYNC şablon kümesindeyse; `:MANUEL` ve NULL aileli şablon sayılmaz. Çağıranlar `_hastalikBtnSync`, `_ovsyncBaglamKur` (atlas) değişmedi. IDB `gorev_log` = `v_gorev_log_sync` (`kaynak`, `iptal` taşır).
- `tests/unit/ovsync-mu-log-kolu-js.test.js` yeni; `k10-hastalik-modal` ve `k10-ilac-bar-yalniz-ovsync` yeni kurala çekildi.
- `index.html`: `?v=20261013-09` → `20261017-01` (26 yer).

## Etki
Fonksiyonu iki yer çağırıyor (prod+demo pg_proc + repo grep): `ovsync_hastalik_gunu_ekle` (yanlış pozitifte mastit vakasına gün/ilaç yazar, TAI öteler) ve `_kisir_zincir_bitir` tetiği (kısırda vakayı ERKEN_KAPANIS kapatır); ikisi de izole DB'de düzeltme öncesi ölçüldü.

## Testler
- SQL: 8/11 RED → 11/11 PASS; mutantlar (iptal→true, OVSYNC→true, IS NOT TRUE) 3/3 RED. `sessiz_ovsync_dislama_test` iki durumda PASS; `ovsync_paketi_test`/`ovsync_takip_test` iki durumda ortam hatası (aynada ON CONFLICT hedefi / kizginlik_vaka_ac imzası yok), ilgisiz.
- JS: 3/3 RED → hedefli 18/18 PASS; mutantlar M1 iptal yok, M2 şablon yok, M3 iptal!==true 3/3 RED.
- Tam birim: 1598 / pass 1594 / fail 4 (LUNA-3, EG-7, EG-8, bc-tarih) = taban kümesi; `migration-sira-kilidi` PASS.
- db-validate PASS, rapor SHA `3a69ea5d…` (yeni yolla da aynı). İlk iki yeni-yol koşusu ortam FAIL (istatistik oturumuyla paylaşılan `egesut_val_tmp`; ardından konteyner kapalı); üçüncü PASS.

## :MANUEL kararı
MANUEL Ovsync sayılmaz (yeni kural kendiliğinden sağlar). Prod'da MANUEL loglu 15 vakanın 13'ü zaten damgalı, 2'si bağımsız İnaktif Ovaryum; `vaka_tohumlama_ekle` genel eylem; §18.18.

## Demo
- Prova BEGIN…ROLLBACK 65 → 62; kalıcı uygulama gövde + schema_migrations tek transaction; md5 `28b209ab…` → `6fd299d3…`.
- Yeniden adlandırma: demo `schema_migrations` `20261017000001 ovsync_mu_log_kolu` → `20261017100001` (DO bloğu, ROW_COUNT=1); md5 değişmedi.
- Prod (CONFIRMED): md5 `28b209ab…`, max sürüm `20261013000005`; dokunulmadı.

## Prod taslağı (sahip kapısı)
1. Yedek, `BEGIN … ROLLBACK` provası; beklenen 41 (bugün 46).
2. Gövde + `INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES ('20261017100001','ovsync_mu_log_kolu')` tek transaction.
3. Doğrulama: md5 `6fd299d3…`, düşen küme tam aad17352/0a23bc51/232e7f7d/375a8d6a/1f03f184, `veri-eslesme-kontrol.py hepsi`.
4. JS (`?v=20261017-01`) aynı pencerede merge ile yayınlanır.
5. Geri alma: `20261013000003_alt_vaka.sql` satır 70-88 geri yükle, kaydı DELETE; md5 `28b209ab…`.

## Demo tarayıcı test listesi (UI kapısı)
1. Klinik Mastit 232e7f7d (hayvan 197) detayında "+ Hastalık"/"+ İlaç" görünmez, `#cd-hastalik-bar` gizli (ekran + `display==='none'`); IDB `gorev_log`'da `TEDAVI_SABLON_TOHUMLAMA:232e7f7d…` satırı var mı raporlanır (iptal kaydı son-300 penceresinde değil; yoksa eski kodla da gizli çıkar, asıl kanıt birim testi).
2. Damgasız yalnız `:MANUEL` loglu açık vaka varsa düğmeler görünmez; yoksa "uygulanamaz, birim kanıtlı".
3. Damgalı (`protocol_family='OVSYNC'`) açık vakada düğmeler görünür, bar `flex`; "+ Hastalık" sheet'i açılır ("+ Hastalık — Küpe <no>"), kayıtsız kapatılır.
4. Ovsync takip ekranında damgalı satırda "MUAYENEDE SORUN VARSA HASTALIK GÜNÜ AÇ" kartları görünür.
5. Konsolda yeni JS hatası yok; `js/ui.js?v=20261017-01` yüklü.

## Kapsam dışı bulgu
`v_gorev_log_sync` kapalı/iptal logları son 300 ile sınırlıyor; tamamlanmış OVSYNC şablon logu pencereden düşerse JS log kolu false negatif verir (DB doğru). Bugün damga/eşlem kolları gerçek vakaları kapsıyor, risk düşük.

## Varsayımlar
- İptali NULL log sayılmaz (prod/demo'da yok).
- Worktree'de `.env` yok; `refresh_lsp_schema.sh`, `db-build-baseline.sh`, `db-validate.sh` ana checkout'tan (/home/melik/egesut-erp1, 56900c3) koşuldu.
- Yerel şema aynası prod'dan salt-okuma tazelendi.
- Demo kalıcı uygulama kontrattaki "demo prova apply db-validate PASS sonrası serbest" kuralına dayanır.

## Kanıt
`runs/2026-10-17-ovsync-mu-fix/kanit/`: db-validation-3a69ea5d.md, sql-test-kirmizi/yesil.out, js-test-kirmizi/yesil.out, js-mutant-M1/M2/M3.out, birim-ozet.txt
