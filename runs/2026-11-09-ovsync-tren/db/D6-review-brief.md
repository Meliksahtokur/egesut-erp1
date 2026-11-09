# D6 T2 kapı review
job_id: j-20261109T105938Z-6bf11d

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D6-review-report.md
repo: ~/.herdr/worktrees/egesut-erp1/ovsync-tren
base: 6a9e8db
head: 00420d2
butce: 450

## İş
Şablon: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/review-sablon.md (D<k>=D6). Görev brief'i: D6-brief.md, worker report'u: D6-report.md (aynı klasör).
Diff'i yalnız L-DB dosyalarıyla sınırla: `git diff 6a9e8db 00420d2 -- supabase/ runs/2026-11-09-ovsync-tren/db/` (dalda başka kulvarların js/ commit'leri olabilir — onlar kapsam dışı, scope-violation sayma).
D6'ya özgü: üç yeni RPC (ovsync_hayvan_ertele, ovsync_pg48_tohumla, ovsync_bastan_baslat) — _ovsync_ic_ac + advisory lock + bayrak kapalı OVSYNC_TREN_KAPALI; aşama 0/1/2/NULL dalları ve hata payload'ları planla birebir; RL-1 (etiket artışı yalnız vaka_kalan_gunleri_kaydir içinde, burada çift sayım yok — TR-K4-2/TR-K5-1); R18 birikimli tolerans (TR-K5-N2, TR-K5-2); R12 PG48 (seans_tamamla p_uygulanmadi ile kapanış, stok iadesi); seans_tamamla R13 K11 (bayrak açık OVSYNC'te olay anı now(), bayrak 0'da LEAST eski) + SÖZLEŞME EKİ ovsync_uyari alanları (TR-EK-UYARI); R6-EK'e dayanan fixture'lar. Bilinen: ovsync_pg_kabul.sql S10 gorev_sayisi D1 planlı etkisi (D8 kapsamı).
build.sh KOŞMA (kabul DB'si hazır). db-validate RL-8 biçimiyle (aşağıdaki Run).

## Model/effort
opus / high (ss-reviewer-kapi)

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D6-review-report.md

## Kabul
Şablondaki çıktı biçimi; `## Run kanıtı` bölümü (komut + `rc: N` + ham son satırlar).

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/migrations/20261110100006_ovsync_tren_asama.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql

## Bağımlı
D6

## Review: T2

## Önceden cevaplanmış kararlar
PLAN.md R1–R20, Kapı tur 2 ekleri, progress.md RL-* ve SORU cevapları.
