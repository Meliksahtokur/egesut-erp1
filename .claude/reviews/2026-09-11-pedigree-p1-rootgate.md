# Root-gate review — G-20260911-PEDIGREE-P1-TEMEL

Review target: `idle/pedigree-p1` at `58f51892d4ec3265ba6b27a9a3d37ad5f9cc996f`.
Review range: `main..idle/pedigree-p1`. The lead report and previous review
were treated as untrusted material; the findings below were rechecked against
the target diff, source, and demo transaction probes.

## Findings

### F1 — [doc-drift] VERIFIED — valid cutoff with no violations emits an empty group

- Location: `supabase/migrations/20260911000003_pedigree_farm_backfill.sql:442-456`; the no-empty assertion in `tests/sql/pedigree_farm_backfill_test.sql:110-115` does not cover this valid-cutoff path.
- Evidence: the following demo transaction added a temporary `tohumlama.semen_id`, set cutoff to `2999-01-01T00:00:00Z`, inserted no violating row, and rolled back:

  ```text
  cutoff                    | violation_rows | has_post_cutoff_group | post_cutoff_items
  2999-01-01T00:00:00.000Z | 0              | t                     | null
  (1 row)
  ROLLBACK
  ```

  Command exited `0`.
- Mechanism: `jsonb_build_object(...)` at lines 444-448 is non-NULL even when `jsonb_agg(...)` returns NULL, so the `IF v_dyn_group IS NOT NULL` check at line 454 appends `post_cutoff_null_semen` with `items: null`. This violates the plan's absent-group rule and can make consumers that call `jsonb_array_elements(g->'items')` fail. The test's `jsonb_array_length(g->'items') = 0` predicate also does not match NULL.
- Recommendation: build/append the dynamic group only when at least one row exists (for example, count or a non-NULL aggregate guard), and add a valid-cutoff/no-violation assertion.

### F2 — [dead-path] VERIFIED — W1 overwrites the newer D53 postpartum behavior

- Location: `supabase/migrations/20260911000001_dogum_buzagi_id_foundation.sql:140-183`; newer main migration `supabase/migrations/20260906000001_postpartum_d53_e_vitamin_tek.sql:2-9,122-163`.
- Evidence: W1 writes `53. Gün: Ademin`, `53. Gün: Yeldif`, and `54. Gün: Yeldif` at lines 148-150 and returns `10+7` at line 183. Main's later behavioral fix specifies one `53. Gün: E Vitamini` task and `8+7`. The live demo probe returned:

  ```text
  has_old_d53_ademin | has_old_d54_yeldif | has_new_d53_evit | returns_old_10_plus_7
  t                  | t                  | f                 | t
  ```

- Mechanism: applying the target's later `20260911...00001` migration after main's `20260906...00001` migration replaces `dogum_kaydet` with the stale ten-task body. A real birth therefore resurrects the removed Ademin task, duplicates E_VIT at d53/d54, and reports 17 tasks instead of 15.
- Recommendation: rebase the W1 function body on the current D53-correct body and retain only the `buzagi_id` binding change; add a regression assertion for the 8+7 behavior.

### F3 — [fake-arm] VERIFIED — G0b backfill coverage executes a copy, not the migration's backfill

- Location: `tests/sql/dogum_buzagi_id_test.sql:106-142` versus the production migration block `supabase/migrations/20260911000001_dogum_buzagi_id_foundation.sql:198-242`.
- Evidence: the test explicitly labels its `DO $bf$` block “migration ... birebir kopyasi” and runs that block after inserting the four fixtures. The migration has no callable backfill function; its actual `DO $mig$` block is not invoked or replayed by the test. The fixture command still reports `W1T: TUM TESTLER GECTI`, EXIT `0`.
- Mechanism: changing the production `DO $mig$` logic can leave all four test assertions green because the test's independent `DO $bf$` copy continues to implement the old behavior. The green test is therefore not evidence for the actual migration arm.
- Recommendation: extract the production backfill into one internal callable function and test that function, or apply the real migration in a disposable transaction/schema and assert the resulting four classes; do not maintain a second algorithm in the fixture.

### F4 — [fake-arm] VERIFIED — G1 birth-path acceptance does not exercise `dogum_kaydet`

- Location: `tests/sql/pedigree_graph_test.sql:48-63`; `supabase/migrations/20260911000002_pedigree_foundation.sql:226-229`; W1 `dogum_kaydet` body `supabase/migrations/20260911000001_dogum_buzagi_id_foundation.sql:115-125`.
- Evidence: the test directly calls `_pedigree_parent_set_core(...)` at line 60. A target-source search for `_pedigree_parent_set_core` in `dogum_kaydet` returns no production caller (`dogum_calls_core=ABSENT`); W1 only inserts the birth row, inserts the calf, and updates `dogum.buzagi_id`. The graph fixture nevertheless reports `TESTDONE:pedigree_graph_test tamam — 19 blok yeşil`, EXIT `0`.
- Mechanism: the green A2 block proves only that a privileged SQL caller can invoke the INTERNAL core. It does not prove the G1 criterion “birth-path bypasses guard via INTERNAL core”; a real `dogum_kaydet` call in this P1 target creates no dam/sire graph edge.
- Recommendation: either make the goal explicitly defer the birth-path criterion to the separately planned Task 12/Faz 7 or implement and test the production `dogum_kaydet` → INTERNAL-core caller chain before accepting G1.

### F5 — [unmeasured-claim] VERIFIED — public pedigree RPCs retain direct `service_role` EXECUTE

- Location: `supabase/migrations/20260911000002_pedigree_foundation.sql:529-542` and `supabase/migrations/20260911000003_pedigree_farm_backfill.sql:475-477`; G1 says grants are authenticated-only at `.harness/goals/2026/G-20260911-PEDIGREE-P1-TEMEL.md:55-59`.
- Evidence: the demo privilege probe returned `auth_report=t`, `anon_report=f`, and `service_report=t`; for the three W2 public RPCs it returned `service_parent=t`, `service_external=t`, `service_semen=t`. `pg_proc.proacl` showed, for example, `{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}`. The migrations revoke from `PUBLIC, anon` but do not revoke `service_role` on these public functions.
- Mechanism: the retained default/direct service-role grant contradicts the migration comments and the authenticated-only acceptance claim. The internal helpers explicitly revoke `service_role`, demonstrating that this role was considered in the surface, but the public RPC grant blocks omit it. Operator checks still apply to guarded writes; the verified defect is the privilege contract mismatch.
- Recommendation: explicitly revoke `service_role` where authenticated-only is required, or record service-role as an intentional trusted caller and change the goal/test contract accordingly.

### F6 — [doc-drift] VERIFIED — G2 “blockers==0” is not measured by the fixture

- Location: goal `.harness/goals/2026/G-20260911-PEDIGREE-P1-TEMEL.md:60-64`; plan `.claude/plans/2026-09-10-pedigree-genetics-impl.md:2199-2203`; test `tests/sql/pedigree_farm_backfill_test.sql:158-164,278-283,414-429`.
- Evidence: the real W3 fixture run printed `baseline blocker sayisi 2`, then `blockers=2 (delta 0)` for the clean fixture and `blockers=4 (B0+2)` after intentionally inserting the two maternal blocker fixtures. The same test intentionally emits another blocker for `cutoff_invalid` at lines 414-429. The test compares against `v_b0`; it never establishes an absolute zero-blocker report on the demo DB.
- Mechanism: the goal's literal `blockers==0 with fixture data` and the plan's G2 wording cannot both describe the current test, which deliberately exercises blocker findings and accepts the pre-existing two demo blockers. The lead's “fixture kapsamında blockers==0” statement is only a delta claim.
- Recommendation: reconcile the goal/plan/test contract: use an isolated clean dataset for an absolute-zero assertion, or change G2 to an explicit fixture-delta criterion and document that anomaly fixtures and existing demo data may contain blockers.

### F7 — [scope-violation] VERIFIED — target diff escapes the Full-goal write manifest

- Location: goal write manifest `.harness/goals/2026/G-20260911-PEDIGREE-P1-TEMEL.md:9-13`.
- Evidence: `git diff --name-status main..idle/pedigree-p1` reports changes outside the four manifest entries, including:

  ```text
  .claude/tasks/2026-09-11-pedigree-p1-W1-fix.md
  .claude/tasks/2026-09-11-pedigree-p1-W1.md
  .claude/tasks/2026-09-11-pedigree-p1-W2-fix.md
  .claude/tasks/2026-09-11-pedigree-p1-W2.md
  .claude/tasks/2026-09-11-pedigree-p1-W3.md
  .claude/tasks/2026-09-11-pedigree-p1-review1.md
  .claude/tasks/2026-09-11-pedigree-p1-rootgate.md (deleted)
  .gitignore
  README.md
  scripts/db-dry-run.sh
  scripts/refresh_lsp_schema.sh
  ```

  The diff is 19 files, while the envelope described 18. The lead report itself records this as a write-manifest tension, not as an approved goal-manifest update.
- Mechanism: the Full-goal contract requires staged/changed paths to fit the exact manifest. Plan Task 1.7 does not override the active goal's narrower manifest.
- Recommendation: remove or separately authorize the out-of-manifest paths before merge; do not silently widen the goal at root acceptance.

### F8 — [doc-drift] VERIFIED — retained tooling's TMPDIR claim has a `/tmp` large-artifact fallback

- Location: `scripts/refresh_lsp_schema.sh:16,33-34` and `scripts/db-dry-run.sh:88-91`.
- Evidence: the scripts claim TMPDIR compatibility but use `OUT_DIR="${TMPDIR:-/tmp}/refresh_lsp"` and `mktemp "${TMPDIR:-/tmp}/dry-run-refresh.XXXXXX.log"`. The refresh directory stores generated table/function/view SQL and is not removed by the script.
- Mechanism: outside an agent environment with a pre-set disk-backed `TMPDIR`, a full schema dump goes to `/tmp/refresh_lsp` (the machine's tmpfs) and remains there. This conflicts with the repository's explicit disk-backed temporary-artifact rule.
- Recommendation: require or resolve a disk-backed temporary root and create a unique directory with `mktemp -d`; clean it on exit or place long-lived debug artifacts under an explicit disk work directory.

## Verification

- `git rev-parse idle/pedigree-p1` → `58f51892d4ec3265ba6b27a9a3d37ad5f9cc996f`.
- Target W1, W2, and W3 SQL fixtures were streamed from the target ref to the demo pooler in transaction-scoped runs: all exited `0`; W1 printed `W1T: TUM TESTLER GECTI`, W2 printed `19 blok yeşil`, and W3 printed `TUM KONTROLLER GECTI`. Each ended with `ROLLBACK`.
- The valid-cutoff/no-violation counterexample above exited `0` and ended with `ROLLBACK`.
- `NODE_PATH=<target-worktree-node_modules> npm run test:unit` → 737 tests, 736 pass, 1 fail; the failure is the goal-documented pre-existing `tests/unit/gecmis-pipeline.test.js:283` DÜN assertion. A first run without the dependency root was not used as acceptance evidence because `fast-check` was unavailable in this review checkout.
- `git diff --check main..idle/pedigree-p1` → exit `2`, reporting `supabase/migrations/20260911000001_dogum_buzagi_id_foundation.sql:243: new blank line at EOF`.
- `scripts/refresh_lsp_schema.sh` was not run; no PROD or Management API access was made. No product code was changed in this review.

VERDICT: FAIL (merge-blocking findings: F1-F7; F8 applies if the out-of-manifest tooling is retained)
