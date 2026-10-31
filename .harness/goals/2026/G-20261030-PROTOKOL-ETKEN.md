# G-20261030-PROTOKOL-ETKEN

- status: DONE (root kabul 2026-10-31)
- owner: sahip; root kabul eder
- flow: root → builtin ss-worker-high (opus high); Muse YOK (sahip 2026-10-30)
- base SHA: 5d3f6a3 · launch SHA: t3 kabul SHA'sı
- branch: some-fixes
- worktree: .

## Amaç
Teşhis: `runs/2026-10-30-some-fixes/t2-report.md`
- F1: `gebelik_protokol_kontrol` 3 INSERT'ine `etken_kod` (ROTA, ADEMIN, E_VIT).
- F2: `hizli_uygulama` `p_occurred_at` gelirse `uygulama_log.tarih`e yazar.
- Veri: 9 görev `etken_kod` backfill (907, 906, 207) + sahip kararına göre 906/191 onarımı — ayrı SQL, prod apply ayrı kapı.

## Write manifest
- supabase/migrations/2026103010000*_*.sql
- runs/2026-10-30-some-fixes/t4-*
- tests/ (ilgili birim/SQL testleri)
- reports/db-validation-*.md (git add -f)

## Kapsam dışı (open_item)
F3, F4 (dismiss tarih kapsamı, `_gorev_dinle` alt sınır), §15 notu dışı belgeler; yalnız raporlanır.

## Acceptance
- scripts/db-validate.sh PASS
- Davranış testi: etken'li görev done → tarama düşer; `hizli_uygulama` → görev kapanır; p_occurred_at tarihe yazılır
- Red-before kanıtı

## Stop conditions
Domain-rules çelişkisi; canlı gövde drift; prod'a yazma ihtiyacı → dur, root'a.

## DB gate
Prod apply bu goal'de değil; ayrı sahip kapısı.

## Report
`runs/2026-10-30-some-fixes/t4-report.md`

## Checkpoint
- 2026-10-30: goal açıldı, teşhis t2 TAMAM.
- 2026-10-31: 20261030100001 + veri onarimi prod (t5). Kapsam disi F3/F4 ayri is.
