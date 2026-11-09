# dryrun-fix — scripts/db-dry-run.sh onarımı
job_id: j-20261109T192444Z-b9a1e7

İlk iş: ~/.claude/skills/using-superpowers-obra/SKILL.md oku ve uygula (sahip kuralı; SUBAGENT-STOP bu kural için geçersiz). Sonra: systematic-debugging-obra, db-validation skill (~/.claude/skills/db-validation/SKILL.md varsa), ~/egesut-erp1/.harness/contract.md, ~/egesut-erp1/.harness/runbooks/db-migration.md.

## Plan maddesi
Sahip (2026-11-09, birebir): "bence şimdi düzeltebilrsin bir opus gönder halletsin ufaksa uzunsa lead atra".
Arıza (ovsync-tren N7 P3, MEASURED, kaynak ~/.herdr/worktrees/egesut-erp1/ovsync-tren/runs/2026-11-09-ovsync-tren/prod/P2-P9-report.md:10-24):
1. `scripts/db-dry-run.sh` 9/9 koşumda rc=66: ayna kurulumunda fonksiyonlar view'lardan önce yükleniyor, `v_stat_saglik_vaka` bulunamıyor (muhtemelen `scripts/refresh_lsp_schema.sh` yükleme sırası; istatistik AP1 view'ları eklendiğinden beri — INFERRED, doğrula).
2. Araç yerel DB'yi tazeliyor ama denemeyi Neon'da koşuyor: tazelenen hedef ≠ denenen hedef.
Hedef: dry-run, migration dosyasını prod şemasının güncel aynasında deneyip 42703/42P01/42710 sınıfı hataları güvenilir yakalasın; tazelenen ve denenen DB aynı olsun. Önce kök nedeni ölç (systematic-debugging), sonra düzelt.

## Model
opus (ss-worker-high) — doğrulama kapısı aracı (fail-closed)

## Çalışma yeri
Yeni worktree: `git -C ~/egesut-erp1 worktree add ~/.herdr/worktrees/egesut-erp1/dryrun-fix -b dryrun-fix main`. Tüm iş orada. node_modules/.env gerekirse ana checkout'tan oku (kopyalama, commitleme).

## Yazılabilir dosyalar
~/.herdr/worktrees/egesut-erp1/dryrun-fix/scripts/db-dry-run.sh
~/.herdr/worktrees/egesut-erp1/dryrun-fix/scripts/refresh_lsp_schema.sh
~/.herdr/worktrees/egesut-erp1/dryrun-fix/scripts/tests/ (yeni test betiği gerekirse, tek dosya)
~/.herdr/worktrees/egesut-erp1/tedavi-arge/runs/2026-11-09-dry-run-fix/dryrun-report.md

## Boyut bütçesi
≤60 satır değişiklik, ≤2 betik. Kök neden bunu aşıyorsa (ör. ayna mimarisi değişmeli, 3+ dosya, DB tasarımı) DÜZELTME YAPMA: report'a teşhis + önerilen plan + `sonuc: KISMI` + `SORU: lead'e taşınsın mı` yaz ve dur.

## Önceden cevaplanmış kararlar
- Prod'a ve demo'ya HİÇBİR yazma yok; Neon'u hedef olarak bırakmak ya da yerel'e taşımak senin teşhisine bağlı, report'ta gerekçele (öneri: tek hedef, yerel ayna; Neon kullanılıyorsa tazeleme de Neon'a).
- Eşzamanlılık: başka bir ajan şu an ovsync-tren prod uygulamasında; o iş yerel DB kullanmıyor. `egesut_val_tmp` (db-validate) DB'sine dokunma (açık kalem ce98243ee790: kilitsiz).
- Sır/parola/proje ref'i rapora ve commit'e yazma (public repo); db-dry-run çıktısı URL parolası basıyorsa maskele (açık kalem 102c3b488df0 ile aynı sınıf).
- Commit: dryrun-fix dalında, `git add` dosya dosya, mesaj sonu `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Push/merge YOK (root ss-merge-gate ile).

## Run
bash scripts/db-dry-run.sh ~/.herdr/worktrees/egesut-erp1/ovsync-tren/supabase/migrations/20261110100001_*.sql
(ek: kasıtlı bozuk bir geçici migration — olmayan kolon — ile rc≠0 ve 42703 yakalandığını göster; geçici dosya ~/tmp altında, commitlenmez)

(cwd = ~/.herdr/worktrees/egesut-erp1/dryrun-fix; ağır komutlar `ram-ultracode exec --class test --wait 300 -- bash <script>`.)

## Review: T1

## DONE
Report: ~/.herdr/worktrees/egesut-erp1/tedavi-arge/runs/2026-11-09-dry-run-fix/dryrun-report.md — `sonuc:`, `kabul SHA:`, kök neden (MEASURED), `## Run kanıtı` (komut + rc + son ≤30 satır; temiz migration rc 0, bozuk migration rc≠0 + 42703).
