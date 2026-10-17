# Brief — `_vaka_ovsync_mu` log kolu yanlış pozitif düzeltmesi (2026-10-17)

## Plan maddesi
Sahip onayı (2026-10-17, "ok"): istatistikten AYRI küçük düzeltme işi. Dal `fix/ovsync-mu-log-kolu` (main 56900c3'ten), worktree `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix`. Prod'a uygulama ve merge YOK (sahip kapısı) — yalnız fix + test + doğrulama + prod etki ölçümü.

**Hata (MEASURED, demo salt-okuma, 2026-10-17):** `_vaka_ovsync_mu` (`supabase/migrations/20261013000003_alt_vaka.sql:66-84`) `gorev_log`'daki `TEDAVI_SABLON_TOHUMLAMA:<case>:%` anahtarını Ovsync belirteci sayıyor. Aynı anahtarı tedavi şablonlarının opsiyonel "planlı tohumlama" adımı da yazıyor (`20260730000001_sablon_tohumlama_opsiyonel_ve_yasam_dongusu.sql:97,128`, `20260909000001_sablon_aktif_vakaya_uygula.sql:115,130`; elle ekleme `20260730000002_vaka_tohumlama_ekle.sql:134` `:MANUEL`). Demo örnekleri: vaka 232e7f7d Klinik Mastit (şablon "Enrolen mastit"), 375a8d6a Neonatal Zayıflık (3 günlük buzağı H000159, şablon "Kas / tendon zayiflik"), 1f03f184 Tırnak Yarası (şablon "3x30 sefanel + nsaid") — logları `gorev_tipi=TOHUMLAMA_PLANLI`, `iptal=true`, şablonların `protokol_ailesi` NULL. Prod'da aynı tanım farkı 5 vaka (İnaktif Ovaryum 2, Klinik Mastit 1, Neonatal Zayıflık 1, Tırnak Yarası 1).

**İstenen düzeltme (root ruling; istatistik dalındaki `stat_vaka_ovsync_mu` ile aynı kural):** log kolu yalnız log anahtarındaki şablonun `protokol_ailesi = 'OVSYNC'` olduğu VE log `iptal = false` olduğu durumda Ovsync sayar. Diğer kollar (protocol_family, ad, şablon-eşlem) AYNEN. Elle tohumlama `:MANUEL` anahtarının bugünkü davranışı ölç, değiştirme kararını gerekçeyle rapora yaz (Ruling).

## Adımlar
1. Önce oku: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix/.harness/references/domain-rules.md` (Ovsync §18 ve sonrası) — çelişki → dur, `SORU:`. code-change-precheck ve db-validation skill'lerini yükle.
2. Etki: `_vaka_ovsync_mu`'yu kim çağırıyor (gitnexus/atlas → grep supabase/migrations js/); hangi davranış (alt vaka, rozet, senkron) yanlış sınıflamadan etkileniyor — prod'daki 5 vakada bugün ne yanlış oluyor (Mgmt API SALT-OKUMA: `BEGIN; SET TRANSACTION READ ONLY; …; ROLLBACK;`), MEASURED.
3. TDD: kırmızı SQL testi (mevcut alt_vaka test kalıbıyla) — (i) protokol_ailesi NULL şablondan iptal=true TOHUMLAMA logu olan tedavi vakası → Ovsync DEĞİL; (ii) OVSYNC şablonundan iptal=false logu → Ovsync; (iii) mevcut pozitif durumlar değişmez. Sonra yeni migration (damga ≥ 20261017, main'in migration sırası kilidi testine uygun — `tests/unit/migration-sira-kilidi.test.js`'i oku) `CREATE OR REPLACE` ile; GRANT/SECURITY aynen korunur (anon GRANT YAZMA).
4. Doğrulama: `scripts/db-validate.sh` PASS; SQL testleri PASS; `NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/` — yeni fail 0 (taban: main 56900c3'te 6 bilinen fail; önce tabanı ölç).
5. Demo'ya uygulama YALNIZ planlı yolla ve rapora yaz; prod'a HİÇBİR ŞEY uygulanmaz.

## Model
opus high (ss-worker-high) — prod'daki Ovsync paketinin fonksiyonu, domain hassas.

## Yazılabilir dosyalar
/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix/supabase/migrations/2026101700000X_ovsync_mu_log_kolu.sql (tek yeni migration; X main sırasına göre)
/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix/tests/sql/ altında tek yeni test dosyası (ya da mevcut alt_vaka testine ek — raporda belirt)
/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix/runs/2026-10-17-ovsync-mu-fix/ (report, progress)

## Boyut bütçesi
Migration ≤80 satır, test ≤150 satır. Commit: görev başına, `git add` dosya dosya; `-A`/`.` YASAK; git stash YASAK; push/merge YOK.

## Teslim
`/home/melik/.herdr/worktrees/egesut-erp1/ovsync-mu-fix/runs/2026-10-17-ovsync-mu-fix/report.md`: etki (çağıranlar + prod 5 vakada bugünkü yanlış davranış), test kırmızı→yeşil kanıtı, db-validate sonucu, birim süit sayıları, `:MANUEL` ruling'i, prod uygulama taslağı (sahip kapısı için: hangi migration, geri alma), `kabul SHA:`. Dönüş ≤5 satır.
