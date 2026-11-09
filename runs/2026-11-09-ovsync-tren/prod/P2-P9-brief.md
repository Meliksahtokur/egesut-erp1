# N7 P2–P7 + P9 kuru — prod uygulama (bayrak KAPALI kalır)
job_id: j-20261109T191039Z-2c8a3b

İlk iş: ~/.claude/skills/using-superpowers-obra/SKILL.md oku ve uygula (sahip kuralı; SUBAGENT-STOP bu kural için geçersiz). Sonra Skill/oku: db-validation (~/.claude/skills/db-validation/SKILL.md varsa), ~/.herdr/worktrees/egesut-erp1/ovsync-tren/.harness/references/domain-rules.md, ~/.herdr/worktrees/egesut-erp1/ovsync-tren/.harness/runbooks/db-migration.md, PLAN N7 (~/.herdr/worktrees/egesut-erp1/ovsync-tren/docs/plans/2026-11-09-ovsync-tren/PLAN.md:614-633), P1 raporu (~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/prod/P1-kuru-report.md — ENGEL yok, md5 16/16), prod erişimi ~/.claude/projects/-home-melik-egesut-erp1/memory/live-schema-verification-mgmt-api.md, kimlik kalıbı (authenticated + sahip jwt sub) ~/.herdr/worktrees/egesut-erp1/tedavi-arge/runs/2026-11-09-ovsync-toplu-gun/prod-uygula-report.md §P1.

## Plan maddesi
Sahip onayı (birebir, 2026-11-09): S1 "bence mahsuru yoksa hemen uygulanabilir teknik engel yoksa" + demo "tamam kral onay verdim". Yürüt:
- **P2 yedek:** `git tag backup/2026-11-09-ovsync-tren-oncesi main` (yerel, push yok); satır yedeği (`protokol_ayar`, açık `gorev_log`, aktif `protokol_instance`, aktif `cases` + `treatment_days` + `treatment_day_uygulamalar`) + değişecek tüm fonksiyonların `pg_get_functiondef` → `~/tmp/ovsync-tren-prod-yedek-<UTCts>/` + sha256 manifest.
- **Dosya listesi:** `git diff --name-only main...ovsync-tren -- supabase/migrations/` (GT hariç) ∩ prod `schema_migrations`'ta olmayanlar. PLAN "8 dosya" der; D9 (7ff1e7b, cases.ovsync_bagimsiz) sonradan eklendi — listeyi ölç, report'a yaz; beklenenden farklıysa (D0-D9 dışı dosya) DUR → SORU.
- **P3 dry run:** her dosya `scripts/db-dry-run.sh` (worktree'de .env yoksa ana checkout ~/egesut-erp1/.env'i kaynak göster; açık kalem 9c486f89bafe). Ayrıca db-validation kapısı (`scripts/db-validate.sh`) dosyalar üzerinde.
- **Mekanik kapı (P4 öncesi, ZORUNLU):** P3'te 42703/42P01/42710 = 0, db-validate yeşil, P1'den sonra md5 16/16 yeniden ölçülüp aynı. Biri tutmazsa P4'e GEÇME → `sonuc: KISMI` + SORU.
- **P4 apply:** dosyalar sırayla TEK transaction (Management API); md5 koruması tutmazsa tümü geri. Ham yanıt kaydet.
- **P5 kayıt:** `schema_migrations` satırları aynı oturumda; SELECT ile geri oku.
- **P6 ground truth:** `supabase/migrations/99999999999999_ground_truth.sql` dosya sonu bölümü (kolon(lar) + yeni + değişen fonksiyonlar, `Tarih:` başlığı). Commit (yalnız bu dosya + prod/ raporu), `git add` dosya dosya (`reports/`/`runs/` gitignore ise `-f`), mesaj sonu `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Push/merge YOK.
- **P7 doğrulama:** `scripts/ground-truth-audit.sh` (bilinen 83/116 eski fark bloke etmez — yalnız YENİ fark say); `python3 scripts/veri-eslesme-kontrol.py hepsi` (SIZINTI/YETIM 0); yeni gövdelerin `md5(prosrc)` = repo dosyaları; `ovsync_tren_onizle()` → `aktif:false`; yeni RPC'ler için `has_function_privilege('anon', …)=false` (açık kalemler ff39271e3d98, 36d89c3fdba9 — burada kapanır).
- **P8:** P1(b) = 0 açık doğum sonrası PG; yeniden ölç, hâlâ 0 ise atla (yazma yok). >0 ise listele, İPTAL ETME.
- **P9 göç KURU:** `BEGIN; <authenticated + sahip jwt set_config>; SELECT ovsync_tren_yeniden_hedefle(true, '2026-11-12'); ROLLBACK;` — önce/sonra listesi (beklenen 25 satır: 6 AYNI + 19 TAŞINIR, P1 §e) → `prod/p9-goc-kuru.json` + report'ta sahip okunur tablo (küpe · eski hedef → yeni tren). ROLLBACK'i ayrı sorguyla doğrula (görev hedefleri değişmemiş).

## Model
opus (ss-worker-high) — canlı prod yazma

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/99999999999999_ground_truth.sql
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/prod/P2-P9-report.md
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/prod/p9-goc-kuru.json
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/prod/geri-al.sql
~/tmp/ovsync-tren-prod-yedek-<UTCts>/ (repo dışı yedek)

## Boyut bütçesi
GT eki yalnız mekanik (fonksiyon gövdeleri prod'dan); başka kod değişikliği 0.

## Önceden cevaplanmış kararlar
- **P10 (bayrak açma) YAPILMAZ.** Sahip P9 listesini görünce açılır. P10 son saati 2026-11-18 07:00 TR (P1).
- P11 geri alma dosyası (`prod/geri-al.sql`) D8 provasındaki dosyadan hazırlanır, KOŞULMAZ.
- Report'a/commit'e prod proje ref'i, token, parola, ~ dışı sır yazma (public repo kapısı tarar).
- Prod yazma yalnız P4/P5 (migration + kayıt). Veri satırına UPDATE/DELETE yok (P8 dahil).
- Hata/çelişki: dur, `sonuc: KISMI` + `SORU:` + `progress:` (devam noktası). Kısmi apply olmasın — tek transaction.

## Run
bash scripts/ground-truth-audit.sh
python3 scripts/veri-eslesme-kontrol.py hepsi

(cwd = ~/.herdr/worktrees/egesut-erp1/ovsync-tren; ağır komutlar `ram-ultracode exec --class test --wait 300 -- bash <script>` ile.)

## Review: T2 (root P4 sonrası nokta-kontrol; P4 öncesi mekanik kapı yukarıda)

## DONE
Report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/prod/P2-P9-report.md — `sonuc:`, `kabul SHA:`, adım başına kanıt, yedek dizini + manifest yolu, `## Run kanıtı` (komut + rc + son ≤30 satır), P9 sahip tablosu.
