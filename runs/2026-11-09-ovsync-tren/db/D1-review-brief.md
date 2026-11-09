# D1 T2 kapı review
job_id: j-20261109T085602Z-9aa3f7

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D1-review-report.md
repo: ~/.herdr/worktrees/egesut-erp1/ovsync-tren
base: cc6ed7a
head: 4a32f60
butce: 120

## İş
Şablon: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/review-sablon.md (D<k>=D1). Görev brief'i: D1-brief.md, worker report'u: D1-report.md (aynı klasör).
D1'e özgü: kabul betiği sözleşmesi ve senaryo izolasyonu (PLAN.md N1 başı) burada kuruldu — sonraki 7 görev bunun üstüne yazacak; sözleşme sağlamlığı (savepoint üçlüsü, temp sequence sayaç, kb_bugun TR, TR-IZOL-1 gerçekten sızıntıyı ölçüyor mu) öncelikli.
`dogum_kaydet` gövde diff'i: kanit `~/.herdr/worktrees/egesut-erp1/tedavi-arge/runs/2026-11-09-ovsync-toplu-gun/kanit/fn/dogum_kaydet.sql` ↔ migration.
build.sh KOŞMA (kabul DB'si hazır; paralelde başka koşum var). db-validate RL-8 biçimiyle.

## Model/effort
opus / high (ss-reviewer-kapi)

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D1-review-report.md

## Kabul
Şablondaki çıktı biçimi.

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql

## Bağımlı
D1

## Review: T2

## Önceden cevaplanmış kararlar
PLAN.md R1–R20, Kapı tur 2 ekleri, progress.md RL-1..RL-8.
