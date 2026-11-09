# D9 T2 kapı review
job_id: j-20261109T124258Z-2ad2ce

report: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D9-review-report.md
repo: ~/.herdr/worktrees/egesut-erp1/ovsync-tren
base: d359e4e
head: 7ff1e7b
butce: 40

## İş
Şablon: ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/review-sablon.md (D<k>=D9). Görev brief'i: D9-brief.md, worker report'u: D9-report.md (aynı klasör; report commitsiz, diskte).
Diff: `git diff d359e4e 7ff1e7b -- supabase/ runs/2026-11-09-ovsync-tren/db/`. TEK TUR (yeni tur yok, KRİTİK hariç); bulgu başına dar fix yaz.
Odak:
1. RD9-3 değişmez: bayrak açıkken etiket NULL kalan HER yazma yolunda `ovsync_bagimsiz = true` mi (004 başlatma / tedavi_sablon_uygula / vaka_toplu_ac, 005 K9, 006 bastan_baslat). Report'taki yazma noktası listesi eksiksiz mi — kendin grep'le.
2. RD9-4: 008 R14 üyelik seçimi ve UPDATE işaretli vakayı dışlıyor mu; 007 sayımları tutarlı mı.
3. R4: bugün tren günü + `p_bagimsiz` → trende, işaret false.
4. Worker açık kalemi: işaretli vakaya ikinci OVSYNC şablonu uygulanırsa 004:473-476 dalı — davranış doğru mu, test gerekir mi.
5. RPC imza/dönüş değişmemiş (N4 UI sözleşmesi donuk, RD9-6).
6. geri-al.sql iki kolonu da düşürüyor, prova fark 0.
Not: LSP typecheck hataları (yerel ayna seriyi bilmez) gürültüdür; aynı tabloda iki ayrı ALTER TABLE lint uyarısı en fazla KÜÇÜK.
build.sh KOŞMA (kabul DB'si hazır).

## Model/effort
opus / high (ss-reviewer-kapi)

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/db/D9-review-report.md

## Kabul
Şablondaki çıktı biçimi (verdict + işaretli satır listesi); `## Run kanıtı` bölümü (komut + `rc: N` + ham son satırlar).

## Run
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ( echo 'BEGIN;'; cat supabase/migrations/20261110100001_dogum_pg_hatirlatma.sql supabase/migrations/20261110100002_ovsync_tren_cekirdek.sql supabase/migrations/20261110100003_ovsync_tren_gorev_dogumu.sql supabase/migrations/20261110100004_ovsync_tren_baslatma.sql supabase/migrations/20261110100005_ovsync_tren_kilit.sql supabase/migrations/20261110100006_ovsync_tren_asama.sql supabase/migrations/20261110100007_ovsync_tren_toptan.sql supabase/migrations/20261110100008_ovsync_tren_ayar_goc.sql supabase/tests/ovsync_tren_kabul.sql; echo 'ROLLBACK;' ) | psql -h 127.0.0.1 -U lsp_user -d egesut_ovsync_kabul -X -v ON_ERROR_STOP=1 2>&1 | tail -3
cd ~/.herdr/worktrees/egesut-erp1/ovsync-tren && ! grep -n "CURRENT_DATE" supabase/migrations/2026111010000*.sql

## Bağımlı
D9

## Review: T2

## Önceden cevaplanmış kararlar
PLAN.md R1–R20, Kapı tur 2 ekleri, progress.md RL-* ve RD9-1..6 (D9 root ruling'i: ikinci DDL ve yerinde düzenleme onaylı — bunları bulgu yapma).
