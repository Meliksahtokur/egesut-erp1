# P1 independent review — Task 1 and Task 0.5 diffs

Review range:

- `d7df5c2..idle/pedigree-p1-w1` — Task 0.5 (`dogum.buzagi_id`)
- `d7df5c2..idle/pedigree-p1-w2` — Task 1 (pedigree foundation)

The findings below are evidence-only. No merge or acceptance verdict is recorded here.

## Findings

### F1 — [unmeasured-claim] VERIFIED — `authenticated` retains direct DML on `semen_catalog`

- Severity: **major**
- Evidence: `supabase/migrations/20260911000002_pedigree_foundation.sql:132-141`; `tests/sql/pedigree_graph_test.sql:297-310`.
- Mechanism: the migration revokes `anon` on `semen_catalog` but does not revoke the measured default-ACL `authenticated=arwd`; `GRANT SELECT` does not remove the inherited INSERT/UPDATE/DELETE privileges. RLS is `USING(true)`/`WITH CHECK(true)` at migration lines 126-127.
- Impact: an authenticated client can write or delete catalog rows directly, bypassing `semen_catalog_upsert`, its operator guard, stock-category check, bull-sex check, historical-reference check, and advisory lock. The fixture checks authenticated SELECT and anon SELECT, but never checks authenticated INSERT/UPDATE/DELETE.
- Demo evidence: `has_table_privilege` returned `auth_select=t, auth_insert=t, auth_update=t, auth_delete=t, anon_select=f`; a `SET LOCAL ROLE authenticated` direct INSERT into `semen_catalog` returned a UUID and was then rolled back.

### F2 — [scope-violation] VERIFIED — SECURITY DEFINER helper functions are callable by anon

- Severity: **major**
- Evidence: `supabase/migrations/20260911000002_pedigree_foundation.sql:168-213`; the only helper-specific revokes are for `assert_is_operator()` at `:161-162` and `_pedigree_parent_set_core(...)` at `:313-315`.
- Mechanism: `pedigree_ensure_farm_node(text)` and `pedigree_is_ancestor(uuid,uuid)` are `SECURITY DEFINER` functions with no `REVOKE ... FROM PUBLIC`; their default PUBLIC EXECUTE remains. `pedigree_ensure_farm_node` performs graph DML under the definer, while `pedigree_is_ancestor` reads graph ancestry without an operator guard.
- Impact: the anon role can create a farm node for an existing animal and query ancestry outside the authenticated, operator-guarded RPC surface. The trigger wrapper at `:535-541` also has no explicit revoke, although the two helpers are already sufficient to reproduce the exposure.
- Demo evidence: live privilege query returned `anon_exec=t` for both helpers; inside a transaction, `SET LOCAL ROLE anon; SELECT pedigree_ensure_farm_node(...); SELECT pedigree_is_ancestor(...);` succeeded, followed by `ROLLBACK`.

### F3 — [silent-success] VERIFIED — NULL `p_replace` silently overwrites an existing parent

- Severity: **major**
- Evidence: `supabase/migrations/20260911000002_pedigree_foundation.sql:285-291`.
- Mechanism: when a child/role already has a different parent, the guard is `IF NOT p_replace THEN ...`. In PL/pgSQL, `NOT NULL` is NULL and does not enter the branch, so an explicitly supplied `p_replace=NULL` reaches the UPDATE and replaces the parent.
- Impact: a caller sending JSON/RPC `p_replace: null` can change authoritative parentage without the required explicit replacement flag. The fixture covers omitted/default `false` at `tests/sql/pedigree_graph_test.sql:112-125`, but not explicit NULL.
- Demo evidence: a transaction created two female parents and one child, set the first parent, then called `pedigree_parent_set(..., 'manual', NULL, NULL)`; the query returned `null_replace_overwrote=t, original_preserved=f`. The transaction was rolled back.

### F4 — [fake-arm] VERIFIED — the “birth path” test calls INTERNAL core directly, not `dogum_kaydet`

- Severity: **major**
- Evidence: `tests/sql/pedigree_graph_test.sql:47-63` directly invokes `_pedigree_parent_set_core(...)`; `supabase/migrations/20260911000002_pedigree_foundation.sql:215-217` describes `dogum_kaydet` as a caller; the W1 `dogum_kaydet` body only binds `dogum.buzagi_id` at `supabase/migrations/20260911000001_dogum_buzagi_id_foundation.sql:116-126`.
- Mechanism: no production caller in either reviewed migration invokes `_pedigree_parent_set_core`. The test runs as the privileged SQL owner, so it proves the core can be called directly, not that the production birth path reaches it without the operator guard.
- Impact: G1’s “birth-path bypasses guard via INTERNAL core” claim is green on a preconstructed fake arm while the live `dogum_kaydet` production definition has no `_pedigree_parent_set_core` reference. New birth operations therefore do not exercise this foundation path or create a parentage edge through it.
- Demo evidence: `pg_get_functiondef('public.dogum_kaydet(...)')` search returned `dogum_calls_core=ABSENT`.

### F5 — [silent-success] VERIFIED — the tracked dry-run can accept a stale or partially loaded mirror

- Severity: **major**
- Evidence: `scripts/refresh_lsp_schema.sh:147-180,183-198,210-225`; `scripts/db-dry-run.sh:78-82`.
- Mechanism: the local reset is `psql ... ON_ERROR_STOP=0 ... || true`; each load also uses `ON_ERROR_STOP=0` and increments `LOAD_ERRORS` only when psql exits nonzero. psql file execution with `ON_ERROR_STOP=0` returns zero even after a SQL error, and the final count mismatch only emits a warning; `refresh_lsp_schema.sh` still exits zero. `db-dry-run.sh` treats that zero as “Ayna tazelendi” and continues with the stale/partial mirror when refresh fails.
- Impact: a missing-object or load failure can be hidden behind a green-looking dry-run, so migration compatibility is not measured against the current mirror. The caller can also continue after an explicit refresh failure instead of failing closed.
- Evidence run: a read-only psql reproducer with an intentional missing relation under `-v ON_ERROR_STOP=0 -f -` printed the SQL error and returned `psql_file_exit=0`. `refresh_lsp_schema.sh` itself was not run because the envelope explicitly forbids its PROD Management API read.

### F6 — [silent-success] VERIFIED — `db-dry-run.sh` cannot roll back W1’s self-committing migration

- Severity: **major**
- Evidence: `scripts/db-dry-run.sh:92-101`; `supabase/migrations/20260911000001_dogum_buzagi_id_foundation.sql:17,245`.
- Mechanism: the wrapper starts a transaction and appends `ROLLBACK`, but W1 contains its own `BEGIN`/`COMMIT`. The migration’s COMMIT closes the wrapper transaction; the trailing ROLLBACK then runs outside a transaction and cannot undo the DDL/backfill.
- Impact: running the documented generic dry-run command for W1 mutates the Neon mirror despite the script’s “ROLLBACK / canlıya DOKUNMAZ” contract, contaminating later dry-run results. The equivalent psql transaction probe left a temporary relation present after the outer rollback and emitted “there is no transaction in progress”.

## Re-run and scope evidence

- `git diff --check d7df5c2..idle/pedigree-p1-w1` — exit 0.
- `git diff --check d7df5c2..idle/pedigree-p1-w2` — exit 0.
- W1 SQL fixture, streamed from `idle/pedigree-p1-w1` to the demo DB with `psql -v ON_ERROR_STOP=1 -X -f -` — exit 0; `T1`, unique rejection, SET NULL, all four backfill cases, and `W1T: TUM TESTLER GECTI` notices; final `ROLLBACK`.
- W2 SQL fixture, streamed from `idle/pedigree-p1-w2` to the demo DB with `psql -v ON_ERROR_STOP=1 -X -f -` — exit 0; `TESTDONE:pedigree_graph_test tamam — 17 blok yeşil`; final `ROLLBACK`.
- `bash -n` for both reviewed scripts — exit 0.
- `npm run test:unit` — exit 1: 736 passed, 1 failed. The failure is the goal-documented pre-existing `tests/unit/gecmis-pipeline.test.js:283` assertion (`_gmGroupHtml`, expected `DÜN`).
- `refresh_lsp_schema.sh` was not executed; no PROD access was made. The demo identity query returned `current_database=postgres`, `current_user=postgres`, PostgreSQL 17.6, and the expected pedigree/dogum tables.
- All demo behavior probes that could create rows were transaction-scoped and ended with `ROLLBACK`; the temporary `.env` and `node_modules` symlinks used for the unit command were removed before delivery.
- Reviewed diff scope matched the envelope: W1 had the two declared files; W2 had the two migration/test files plus the four explicitly authorized Task 1.7 tooling/documentation files. No implementation fix was made in this review workspace.
