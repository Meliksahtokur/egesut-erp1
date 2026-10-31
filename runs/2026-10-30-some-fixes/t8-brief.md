# t8 — Prod apply 20261031000001 + ground truth
job_id: j-20261031T042036Z-c40db1
## Plan maddesi
SAHİP ONAYI (2026-10-31, seçim "Uygula"): `supabase/migrations/20261031000001_olu_yavru_kupe_serbest.sql` prod'a. Review KABUL, demoda uygulandı. Runbook: .harness/runbooks/db-migration.md. t5 yöntemi: runs/2026-10-30-some-fixes/t5-report.md (Mgmt API, dry run sapmaları).
1. Yedek: `dogum_kaydet`, `kupe_musait_mi` gövdeleri + ACL → repo dışı `$HOME/yedek/prod-yedek-2026-10-31-olu-yavru/` + manifest.
2. Dry run (t5 kopya yöntemi; NOTICE 00000 sahte hata), 42703/42P01/42710 sıfır.
3. Apply, schema_migrations kaydı, geri oku; md5 gövde = migration. Hata → DUR.
4. Ground truth refresh (runbook adım 6, regen prosedürü): 20261030000001, 20261030100001, 20261031000001 değişiklikleri (`uq_hayvanlar_kupe_no` çıkar, üç fonksiyon, kupe_musait_mi, Tarih başlığı). Elle yama değil prosedür; prosedür tam regen ise diff'i kapsamlı olacak, raporla. `scripts/ground-truth-audit.sh` koş.
5. Commit: dosya dosya. `tests/unit/migration-sira-kilidi.test.js` ve ilgili birim yeşil kalsın.
Gerçek doğum kaydı DENEME. Prod'a bu migration dışında yazma yok, push/merge yok.
## Model
opus (high)
## Yazılabilir dosyalar
supabase/migrations/99999999999999_ground_truth.sql
runs/2026-10-30-some-fixes/t8-report.md
$HOME/yedek/prod-yedek-2026-10-31-olu-yavru/
## Run
scripts/ground-truth-audit.sh
ram-ultracode exec --class test --sh 'NODE_PATH=~/egesut-erp1/node_modules node --test tests/unit/migration-sira-kilidi.test.js'
## Bağımlı
t6
## Review: T1
## Önceden cevaplanmış kararlar
Muse yok. Token yazdırma. Geçici dosya mutlak yol $HOME/tmp; ana checkout'a yazma.
