# D4 T2 kapı review
job_id: j-20261109T100416Z-94b0cd

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D4-review-report.md
repo: ~/.herdr/worktrees/egesut-erp1/ovsync-tren
base: 9aba75e
head: 1adffe6
butce: 450

## İş
Şablon: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/review-sablon.md (D<k>=D4). Görev brief'i: D4-brief.md, worker report'u: D4-report.md (aynı klasör).
Diff'i yalnız L-DB dosyalarıyla sınırla: `git diff 9aba75e 1adffe6 -- supabase/ runs/2026-11-09-ovsync-tren/db/` (dalda başka kulvarların js/ commit'leri olabilir — onlar kapsam dışı, scope-violation sayma).
D4'e özgü: start_first_service_protocol DROP+CREATE (p_bagimsiz; cron tek-arg çağrısı), tedavi_sablon_uygula üyelik UPDATE (R3/R4: yalnız D0 tren günüyse), _vaka_ac_tek TR tarihi, ovsync_tren_onizle + SÖZLEŞME EKİ (kupe_no, kural_tarihi, uye_kupeler; TR-EK-ONIZLE) — progress.md 'SÖZLEŞME EKİ'. ACL: kabul DB anon'a varsayılan EXECUTE vermediği için anon REVOKE mutantı ölçülemiyor (D4-report) — REVOKE satırlarının her yeni/yeniden yaratılan fonksiyonda metin olarak varlığını tek tek doğrula (prod varsayılan yetkisi anon'a EXECUTE verir; hafıza anon-execute-acigi). Bilinen: ovsync_pg_kabul.sql:1506 eski imza (D8 kapsamı, bulgu sayma).
build.sh KOŞMA (kabul DB'si hazır). db-validate RL-8 biçimiyle (aşağıdaki Run).

## Model/effort
opus / high (ss-reviewer-kapi)

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D4-review-report.md

## Kabul
Şablondaki çıktı biçimi; `## Run kanıtı` bölümü (komut + `rc: N` + ham son satırlar).

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql

## Bağımlı
D4

## Review: T2

## Önceden cevaplanmış kararlar
PLAN.md R1–R20, Kapı tur 2 ekleri, progress.md RL-* ve SORU cevapları.
