# D8 T2 kapı review
job_id: j-20261109T115810Z-144ab1

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D8-review-report.md
repo: ~/.herdr/worktrees/egesut-erp1/ovsync-tren
base: a9e4ff5
head: acd0f71
butce: 200

## İş
Şablon: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/review-sablon.md (D<k>=D8). Görev brief'i: D8-brief.md, worker report'u: D8-report.md (aynı klasör).
Diff'i yalnız L-DB dosyalarıyla sınırla: `git diff a9e4ff5 acd0f71 -- supabase/ runs/2026-11-09-ovsync-tren/db/` (dalda başka kulvarların js/ commit'leri olabilir — onlar kapsam dışı, scope-violation sayma).
TEK TUR (root: sahip token kaygısı; yeni tur yok, KRİTİK hariç). İki kapsam: (1) D8 PLAN D8 + SORU-4 regresyon kabulü (düzeltilmiş ovsync_pg_kabul.sql seri tam PASS + Bölüm 1 PASS; d8-pgk-assert-diff.txt yalnız A5–A7 + D8a A1–A4), R9/R14 göç, R6-EK belirsiz_asama sayımı, geri-al.sql provası (16 md5 = D0 tablosu, yeni fonksiyonlar/imzalar yok, kolon yok); (2) D8a (97aeab2, 4e46386; base aeb2a78 için ): yalnız kurulum/fixture + SORU-2 A1–A4, hiçbir başka kb_ok beklentisi değişmemiş. Bulguları tek seferde ver; bulgu başına dar fix yaz (worker düzeltip Run kanıtıyla kapatacak).
build.sh KOŞMA (kabul DB'si hazır). db-validate RL-8 biçimiyle (aşağıdaki Run).

## Model/effort
opus / high (ss-reviewer-kapi)

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D8-review-report.md

## Kabul
Şablondaki çıktı biçimi; `## Run kanıtı` bölümü (komut + `rc: N` + ham son satırlar).

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/migrations/20261110100006_ovsync_tren_asama.sql supabase/migrations/20261110100007_ovsync_tren_toptan.sql supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100007_ovsync_tren_toptan.sql
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql

## Bağımlı
D8

## Review: T2

## Önceden cevaplanmış kararlar
PLAN.md R1–R20, Kapı tur 2 ekleri, progress.md RL-* ve SORU cevapları.
