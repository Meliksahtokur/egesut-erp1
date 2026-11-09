# D3 T2 kapı review
job_id: j-20261109T093633Z-5c933a

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D3-review-report.md
repo: ~/.herdr/worktrees/egesut-erp1/ovsync-tren
base: 0426ce2
head: 9aba75e
butce: 520

## İş
Şablon: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/review-sablon.md (D<k>=D3). Görev brief'i: D3-brief.md, worker report'u: D3-report.md (aynı klasör).
Diff'i yalnız L-DB dosyalarıyla sınırla: `git diff 0426ce2 9aba75e -- supabase/ runs/2026-11-09-ovsync-tren/db/` (dalda başka kulvarların js/ commit'leri olabilir — onlar kapsam dışı, scope-violation sayma).
Bu tur İKİ kapsam: (1) D3 (03f7415) PLAN D3 + R8/R10; (2) D2-EK (D2 dosyası R6-EK güncellemesi, root SORU-3 — progress.md 'SORU-3 CEVAP'): _ovsync_asama/_ovsync_pg1_kayma yeni tanım ve TR-R6EK-1/2/3, TR-ASAMA-N fixture taşıması. D3'e özgü: DROP+CREATE imza değişikliklerinde tüm çağıranların default ile çözüldüğü (D3-report kanıtı; hayvan_ekle ve tedavi_sablon_bos_ata_uygula yalnız pg_proc taramasıyla — INFERRED, yeterli mi değerlendir), service_role GRANT varsayımı (canlı ACL eşliği), R10 fail-closed geri sarma (TR-ANAH-N1), görev doğumu kapısı p_hemen. BOYUT 1015/520 gerekçesi (902 satır zorunlu tam gövde kopyası) — kopyaların prod gövdesiyle diff'i yalnız plan satırları mı, bunu ölç. Bilinen: seri ovsync_pg_kabul.sql'de 3 assert'i kırıyor (D8 kapsamı, bu turda bulgu sayma).
build.sh KOŞMA (kabul DB'si hazır). db-validate RL-8 biçimiyle (aşağıdaki Run).

## Model/effort
opus / high (ss-reviewer-kapi)

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D3-review-report.md

## Kabul
Şablondaki çıktı biçimi; `## Run kanıtı` bölümü (komut + `rc: N` + ham son satırlar).

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql

## Bağımlı
D3

## Review: T2

## Önceden cevaplanmış kararlar
PLAN.md R1–R20, Kapı tur 2 ekleri, progress.md RL-* ve SORU cevapları.
