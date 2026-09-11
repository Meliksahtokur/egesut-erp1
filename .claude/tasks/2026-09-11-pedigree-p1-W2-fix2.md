# W2 düzeltme-2 — root-gate F5 (kendi 3 RPC) + F8 (scriptler)

Kaynak: root-gate tur-1 (FAIL, revizyon turu 1/1). Rapor:
`git show idle/pedigree-p1-rootgate:.claude/reviews/2026-09-11-pedigree-p1-rootgate.md`
Goal Rev 1 (7d908c5) lead dalında merge'li. Tek tur — mekanik kapıyla kanıtla.

## F5 — [unmeasured-claim] (birebir; SENİN KISMIN: 3 public RPC)

> ### F5 — [unmeasured-claim] VERIFIED — public pedigree RPCs retain direct `service_role` EXECUTE
> - Location: `supabase/migrations/20260911000002_pedigree_foundation.sql:529-542`
>   and `supabase/migrations/20260911000003_pedigree_farm_backfill.sql:475-477`;
>   G1 says grants are authenticated-only.
> - Evidence: the demo privilege probe returned `auth_report=t`, `anon_report=f`,
>   and `service_report=t`; for the three W2 public RPCs it returned
>   `service_parent=t`, `service_external=t`, `service_semen=t`. `pg_proc.proacl`
>   showed `{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}`.
>   The migrations revoke from `PUBLIC, anon` but do not revoke `service_role`.
> - Recommendation: explicitly revoke `service_role` where authenticated-only is
>   required, or record service-role as an intentional trusted caller and change
>   the goal/test contract accordingly.

**Talimat (goal kontratı authenticated-only — REVOKE yolu):** migration 000002'de
üç public RPC için `REVOKE EXECUTE ON FUNCTION ... FROM service_role`:
`pedigree_parent_set(uuid,text,uuid,text,text,boolean,jsonb)`,
`pedigree_external_upsert(text,uuid,text,text,date,text,text)`,
`semen_catalog_upsert(text,uuid,uuid,text,text,text,text,text,text,boolean)`.
(integrity_report satırı W3'ün migration'ında — ona W3 dokunuyor.) Test'e
assertion: üç RPC için `has_function_privilege('service_role', ...)=f`,
authenticated `=t`.

## F8 — [doc-drift] (birebir; scriptler senin dosyaların)

> ### F8 — [doc-drift] VERIFIED — retained tooling's TMPDIR claim has a `/tmp` large-artifact fallback
> - Location: `scripts/refresh_lsp_schema.sh:16,33-34` and `scripts/db-dry-run.sh:88-91`.
> - Evidence: the scripts claim TMPDIR compatibility but use
>   `OUT_DIR="${TMPDIR:-/tmp}/refresh_lsp"` and `mktemp "${TMPDIR:-/tmp}/dry-run-refresh.XXXXXX.log"`.
>   The refresh directory stores generated table/function/view SQL and is not
>   removed by the script.
> - Mechanism: outside an agent environment with a pre-set disk-backed `TMPDIR`,
>   a full schema dump goes to `/tmp/refresh_lsp` (the machine's tmpfs) and
>   remains there.
> - Recommendation: require or resolve a disk-backed temporary root and create a
>   unique directory with `mktemp -d`; clean it on exit or place long-lived debug
>   artifacts under an explicit disk work directory.

**Talimat:** iki scriptte de `/tmp` fallback'ini KALDIR: disk-tabanlı kök
gerektir/çöz (örn. `SS_TMP_ROOT` ya da sabit disk yolu; TMPDIR set'sizse
`${TMPDIR:-/home/melik/tmp/agents}` deseni değil — ya zorla hata ver ya disk
köküne düş), her koşumda `mktemp -d` ile TEK kullanımlık dizin, çıkışta `trap`
ile temizlik. Betikleri ÇALIŞTIRMA (refresh PROD API okur) — kod düzelt +
`bash -n`.

## Kabul — kanıtlı

1. `psql $DATABASE_URL -f tests/sql/pedigree_graph_test.sql` yeşil + yeni
   service_role assertion bloğu (çıktı teslim notunda).
2. `bash -n` iki script OK; `grep -n '/tmp' scripts/*.sh` → fallback eşleşmesi yok.
3. `npm run test:unit` — 737/736/1 (yeni kırmızı yok).
4. Değişen dosyalar YALNIZ migration 000002, pedigree_graph_test.sql,
   scripts/db-dry-run.sh, scripts/refresh_lsp_schema.sh.
5. Kendi dalına (idle/pedigree-p1-w2) commit + kırıntı.

Ortam: önceki zarf bootstrap aynen (demo vtzqjmazsvurxdeondmi; PROD yok).
