# D7 T2 kapı review
job_id: j-20261109T113424Z-72af81

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D7-review-report.md
repo: ~/.herdr/worktrees/egesut-erp1/ovsync-tren
base: 7ce4781
head: 9dc700c
butce: 400

## İş
Şablon: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/review-sablon.md (D<k>=D7). Görev brief'i: D7-brief.md, worker report'u: D7-report.md (aynı klasör).
Diff'i yalnız L-DB dosyalarıyla sınırla: `git diff 7ce4781 9dc700c -- supabase/ runs/2026-11-09-ovsync-tren/db/` (dalda başka kulvarların js/ commit'leri olabilir — onlar kapsam dışı, scope-violation sayma).
D7'ye özgü: R7 küme (i)/(ii)/(iii), aşama kararları (R18 birikimli), kısmi başarı yok (alt-blok + OVSYNC_TREN_ERTELE_DUSTU, çapa dahil geri — TR-K7-5), önizleme yazmaz (TR-K7-ONIZLE), R9 ileri görevler, R16 listele (+28 gün, ileri_sayisi), RL-1 (etiket çift sayılmıyor), RL-12 (toptan BASTAN/PG48 D6 RPC'leriyle), R6-EK düşen hayvan önerisi, SÖZLEŞME EKİ (TR-EK-LISTE, TR-EK-ONIZLE-2: pg_pay, ritim_disi_neden, pg1_zaman, ovsync_tren, tren_sayisi, dokunulmaz). D7-report Varsayım 1'i (toptan BASTAN hedefi = bastan_baslat'ın yeni çapa+K2 hedefi, plan X+N'den farklı olabileceği durum) spec K5/K7 ve TR-K7-2 açısından değerlendir. Bilinen: lead RL-14 (progress.md — ileri D0'lı aşama 0 vakaların toptanda kaydırılması) tur 2'de eklenecek, bu turda bulgu olarak tekrar yazma. Ayrıca D6 dar fix (iptal_tai) dahil.
build.sh KOŞMA (kabul DB'si hazır). db-validate RL-8 biçimiyle (aşağıdaki Run).

## Model/effort
opus / high (ss-reviewer-kapi)

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D7-review-report.md

## Kabul
Şablondaki çıktı biçimi; `## Run kanıtı` bölümü (komut + `rc: N` + ham son satırlar).

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/migrations/20261110100006_ovsync_tren_asama.sql supabase/migrations/20261110100007_ovsync_tren_toptan.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100007_ovsync_tren_toptan.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100006_ovsync_tren_asama.sql
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql

## Bağımlı
D7

## Review: T2

## Önceden cevaplanmış kararlar
PLAN.md R1–R20, Kapı tur 2 ekleri, progress.md RL-* ve SORU cevapları.
