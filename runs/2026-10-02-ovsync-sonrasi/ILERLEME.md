# İLERLEME — ovsync sonrası borç turu (board)

Goal: `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi/.harness/goals/2026/G-20261002-OVSYNC-SONRASI-BORC.md`
Dal/worktree: `ovsync-sonrasi` @ `/home/melik/.herdr/worktrees/egesut-erp1/ovsync-sonrasi`

| # | Kalem | Sahip | Durum |
|---|---|---|---|
| 1 | B9 cron saati ölçümü | delege (sonnet) | TAMAM — KAYMA YOK (cron TR 08:10), migration yok; k1-B9-DONE.md |
| 2 | GT refresh | delege (sonnet) | TAMAM — commit 9ecd6a0; bakiye 79 eski fark |
| 3 | TB-6 e2e temizle() | delege + koltuk | TAMAM — 626e3ee+5e8466e; e2e 12/12 ×2 |
| 4 | TB-1 arşiv | kendim | TAMAM — `runs/2026-10-02-ovsync-sonrasi/arsiv-tb1/ARSIV-NOTU.md` |
| 5a | TB-5 SQL (`_pg_kapi_detay.karar`) | delege (sonnet) | TAMAM — commit bf35723; db-validate e98ae410 PASS; PROD apply sahip |
| 5b | TB-5 UI ayağı | delege (sonnet) | TAMAM — commit 20766cb (birim 11/11); tarayıcı UI kapısında |
| 6 | TB-7 TAI bugün/yarın tarayıcı kanıtı | koltuk sonnet-medium | TAMAM — T10/T11 PASS |
| 7 | TB-3 render zaman aşımı TDD | delege (sonnet) | TAMAM — commit d6ea1dd; UI kapısında yürünecek |
| 8 | TB-2 demo_sema_diff 401 | delege (sonnet) | TAMAM — commit f9ca7b6 (js/demo.js); UI kapısında konsol kontrolü |
| 9 | TB-4 ram-pool | root'a not | kapsam dışı (ram-pool deaktif) |
| — | UI kapısı (T1-T12) | koltuk sonnet-medium | PASS 12/12 — ui-kapi-DONE.md; tab kapatıldı |
| — | PROD apply / merge / push | sahip (root üzerinden) | talep DONE.md'de — bekliyor |
