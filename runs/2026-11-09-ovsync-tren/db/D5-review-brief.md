# D5 T2 kapı review
job_id: j-20261109T102942Z-caf1e1

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D5-review-report.md
repo: ~/.herdr/worktrees/egesut-erp1/ovsync-tren
base: 1adffe6
head: 4dd94df
butce: 600

## İş
Şablon: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/review-sablon.md (D<k>=D5). Görev brief'i: D5-brief.md, worker report'u: D5-report.md (aynı klasör).
Diff'i yalnız L-DB dosyalarıyla sınırla: `git diff 1adffe6 4dd94df -- supabase/ runs/2026-11-09-ovsync-tren/db/` (dalda başka kulvarların js/ commit'leri olabilir — onlar kapsam dışı, scope-violation sayma).
Bu tur İKİ kapsam: (1) D5 (6eabd94) PLAN D5 + R5 kilit tanımı + RL-1 (etiket artışı vaka_kalan_gunleri_kaydir içinde, bayrak 0'da NULL) + D4 :432 iç içe CASE dar fix; (2) D4-EK (4dd94df) root ruling + RL-11 (progress.md): gecikmiş/ritim dışı görev → onizle ilk tren + gorev_hedef_eski, start_first_service_protocol yeniden hedefleme (basladi:false) ve OVSYNC_TREN_UYELIK_YOK fail-closed; uye_sayisi tek kaynak. Odak: K10 kilidi iç zincirleri kırıyor mu (vaka_kalan_gunleri_kaydir→tohumlama_gorev_ertele, hastalık günü → TAI ötele, D4-EK yeniden hedefleme → gorev_ertele) — her iç yolda _ovsync_ic_ac() var mı; _coklu ovsync_atlanan toplam/hatalar'a girmiyor mu; bayrak 0 regresyonu (TR-K10-REG, TR-K8-REG); cron ilk_tohumlama_zamanlayici gecikmiş görevde artık yeniden hedefleme yapıyor — bayrak 0'da değişmediğini doğrula. D5 plan dışı `pg_catalog.jsonb_array_elements` öneki (db-validate için) davranış eşdeğeri mi.
build.sh KOŞMA (kabul DB'si hazır). db-validate RL-8 biçimiyle (aşağıdaki Run).

## Model/effort
opus / high (ss-reviewer-kapi)

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D5-review-report.md

## Kabul
Şablondaki çıktı biçimi; `## Run kanıtı` bölümü (komut + `rc: N` + ham son satırlar).

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && bash ~/egesut-erp1/scripts/db-validate.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100005_ovsync_tren_kilit.sql --priors ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100004_ovsync_tren_baslatma.sql
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql

## Bağımlı
D5

## Review: T2

## Önceden cevaplanmış kararlar
PLAN.md R1–R20, Kapı tur 2 ekleri, progress.md RL-* ve SORU cevapları.
