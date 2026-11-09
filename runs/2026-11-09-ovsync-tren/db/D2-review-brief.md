# D2 T2 kapı review
job_id: j-20261109T091443Z-1266fd

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D2-review-report.md
repo: ~/.herdr/worktrees/egesut-erp1/ovsync-tren
base: 4e46386
head: 0426ce2
butce: 220

## İş
Şablon: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/review-sablon.md (D<k>=D2). Görev brief'i: D2-brief.md, worker report'u: D2-report.md (aynı klasör).
Diff'i yalnız L-DB dosyalarıyla sınırla: `git diff 4e46386 0426ce2 -- supabase/ runs/2026-11-09-ovsync-tren/db/` (dalda başka kulvarların js/ commit'leri olabilir — onlar kapsam dışı, scope-violation sayma).
D2'ye özgü: R1 çapa doğrulaması (to_date istisna yakalama), _ovsync_tren_gunu_ic formülü (öne çekme ≤2, NULL), R6/R18 aşama/kayma tanımları, R5 _ovsync_gorev_mu (a)/(b)/(c) ve bozuk JSON güvenliği, iç yardımcı ACL (anon+authenticated kapalı). Worker varsayımları (D2-report '## Varsayımlar') tek tek değerlendir — özellikle geçmiş tarihli gün → aşama NULL sonucunun spec §7 ile uyumu.
build.sh KOŞMA (kabul DB'si hazır). db-validate RL-8 biçimiyle (aşağıdaki Run).

## Model/effort
opus / high (ss-reviewer-kapi)

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D2-review-report.md

## Kabul
Şablondaki çıktı biçimi; `## Run kanıtı` bölümü (komut + `rc: N` + ham son satırlar).

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql

## Bağımlı
D2

## Review: T2

## Önceden cevaplanmış kararlar
PLAN.md R1–R20, Kapı tur 2 ekleri, progress.md RL-* ve SORU cevapları.
