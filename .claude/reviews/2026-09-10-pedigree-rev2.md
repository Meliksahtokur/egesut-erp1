# Pedigree Revision 2 Review

Review checkout: `idle/pedigree-rev2-review` at `9144cb1` after the required
fast-forward to local `main`. The report reviews the Revision 2 spec and plan
against the checked-out repository, `BUGS.md`, the active goal, and the tracked
ground-truth reference. Live database assertions are not treated as repo proof.

## Accuracy

1. **[env-mismatch] Dry-run gate is not present in this checkout.**
   `.claude/plans/2026-09-10-pedigree-genetics-impl.md:1461-1465` and
   `BUGS.md:118-120` require `scripts/db-dry-run.sh` as a repository acceptance
   tool, but `scripts/` contains only `ground-truth-audit.sh` and
   `git ls-files scripts/db-dry-run.sh` fails. The only observed copy is an
   untracked file in the main checkout; it also calls an untracked
   `refresh_lsp_schema.sh`. A worker checkout therefore cannot reproduce the
   required migration gate. The observed copy additionally writes a fixed
   `/tmp/dry-run-refresh.log` (`db-dry-run.sh:72`) and uses default `/tmp`
   temporaries (`:82-84`), contrary to this workspace's temporary-file rule.

2. **[doc-drift] The farm-discipline source reference is dead.**
   `.claude/specs/2026-09-10-pedigree-genetics-architecture.md:206,373`
   reference `.claude/farm-id-discipline.md`, which does not exist in this
   checkout. The repository entrypoint says the retired `.claude` references
   are replaced by `.harness/contract.md` and `.harness/references/`; the spec
   does not identify that replacement, so its farm/RLS authority pointer is
   not reproducible.

3. **[doc-drift] The “first farm_id table” claim is false as written.**
   `.claude/plans/2026-09-10-pedigree-genetics-impl.md:1466-1470` and
   `BUGS.md:114-116` say the repository has zero `farm_id` tables, but
   `demo/02_demo_klonla.sql:6-13` creates `public.demo_klon_log` with a
   `farm_id` column. If “product migrations” or “live production” is intended,
   the scope must say so; the live portion itself remains unverifiable here.

4. **[unmeasured-claim] Live measurements are not independently evidenced in
   the material.** The live claims in the spec revision banner and stock
   section (`.claude/specs/2026-09-10-pedigree-genetics-architecture.md:7-25,493-500`),
   the plan (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:99-102,159-178,225-229`),
   and `BUGS.md:16-58` require the underlying `pg_get_functiondef`/catalog
   outputs before they can be accepted as current. No live DB access or
   evidence artifact is available from this review seat.

## Implementability

1. **[dead-path] The manual catalog-create path has no implementing RPC task.**
   `.claude/plans/2026-09-10-pedigree-genetics-impl.md:978-986` requires
   `semen_catalog_upsert`, while the foundation helper list at `:340-345`
   names only `pedigree_external_upsert`; no task, migration, exact signature,
   or current repository implementation creates `semen_catalog_upsert`. The
   “Elle Gir” flow therefore cannot be implemented or accepted from this plan.

2. **[dead-path] v1 founder-profile delivery has no endpoint contract.**
   `.claude/plans/2026-09-10-pedigree-genetics-impl.md:1257-1262` says founder
   contribution is part of a `pedigree_profile` RPC, but no task defines or
   creates that RPC, no signature/return contract is given, and the spec's API
   section defines `pedigree_subgraph` and `mating_analyze` instead
   (`.claude/specs/2026-09-10-pedigree-genetics-architecture.md:553-601`).
   The Phase 10 “Genetik” surface consequently has no specified data path.

3. **[dead-path] The semen-aware RPC contract is not executable as written.**
   `.claude/plans/2026-09-10-pedigree-genetics-impl.md:879-884` lists four new
   RPCs with `...` in every signature. Parameter names/types, return contract,
   error behavior, affected-table mappings, and the exact `gebelik` variant
   behavior are absent. This prevents stable frontend calls and SQL tests;
   “RPC_TABLES will be updated” at `:915-917` is not a measurable contract.

4. **[dead-path] Required privileges are asserted but not specified.**
   The plan says `semen_catalog` needs frontend SELECT and graph DML must not be
   client-open (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:326-334`),
   while the spec requires RPC grants (`.claude/specs/2026-09-10-pedigree-genetics-architecture.md:371-379`).
   No migration step gives exact `GRANT SELECT`/`GRANT EXECUTE`/REVOKE
   statements for the new tables and RPCs. The tracked auth-lockdown reference
   revokes PUBLIC table/function access and grants existing objects only
   (`supabase/migrations/99999999999999_ground_truth.sql:11098-11112`), so a
   browser acceptance can fail with insufficient privilege despite green SQL
   function tests.

5. **[fake-arm] Phase 3 acceptance asks for an impossible offline reopen.**
   `.claude/plans/2026-09-10-pedigree-genetics-impl.md:609` requires rendering
   after an “offline reopen”, but the Revision 2 runtime statement says the app
   shell cannot cold-start offline and the intended scenario is an already-open
   tab losing the network (`.claude/specs/2026-09-10-pedigree-genetics-architecture.md:866-870`).
   The later Phase 4 wording at plan `:757` is narrower, but the earlier gate
   remains unimplementable/ambiguous.

6. **[silent-success] `%100 semen_id` is not enforceable with the planned
   compatibility window.** `.claude/plans/2026-09-10-pedigree-genetics-impl.md:909-913`
   keeps legacy RPCs active, while `:1004` accepts all new insemination rows as
   carrying `semen_id`; the column is nullable in the spec
   (`.claude/specs/2026-09-10-pedigree-genetics-architecture.md:266-284`).
   No DB constraint, trigger, or scoped definition of “new” prevents a legacy
   caller or another write path from creating a new NULL row. A UI-only test
   cannot establish the stated database-wide criterion.

7. **[unmeasured-claim] The live preflight gates have no reproducible evidence
   destination or command.** Task 0.2 requires live signatures/types and Task
   0.4 requires a live ET domain decision
   (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:159-178,231-235`),
   but neither specifies the authorized probe, output artifact, owner of the
   decision, or a deterministic stop condition beyond prose. The claimed
   “207 insemination” spot-check at `:225-229` likewise has no repo artifact.

8. **[unmeasured-claim] The human-reviewed identity mapping is an unnamed
   dependency.** `.claude/plans/2026-09-10-pedigree-genetics-impl.md:211-223`
   requires a mapping that Task 8 consumes at `:771-785`, but gives no file,
   receipt, owner, version, or acceptance format. A migration cannot be
   reproduced or independently reviewed from the plan alone.

## Contradiction

1. **[doc-drift] Revision 2 removes persistent metric caches, but later text
   still makes them v1 requirements.** The spec banner and §§4.6–4.7 say the
   metric/founder tables and invalidation are v2/on-demand
   (`.claude/specs/2026-09-10-pedigree-genetics-architecture.md:7-14,321-352`),
   yet the same spec retains active cache/rebuild requirements at `:328-369`,
   a cache test at `:1052-1063`, a cache-equivalence property at `:1094-1100`,
   `metric cache` in Phase 3 at `:1141-1150`, and derived-metric invalidation in
   the v1 acceptance list at `:1268-1286`. The plan repeats the conflict:
   D6 says no v1 tables at `:122-129`, but Task 13 still invalidates metrics
   at `:1093-1100`, Task 14 still has a `Create` migration and global cache
   invalidation at `:1117-1145`, and the final map still lists
   `pedigree_metrics_test.sql` at `:1577-1579`. There is no consistent v2
   override at each use site.

2. **[doc-drift] The evaluation schema differs between spec and plan.** The
   spec defines one `genetic_evaluations` row with `metrics`, `reliability`,
   and `raw_metadata` JSONB (`.claude/specs/2026-09-10-pedigree-genetics-architecture.md:286-319`),
   while the plan requires long-form trait columns (`source_registry`,
   `published_at`, `trait_code`, `value`, `unit`) and a different unique key
   (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:1326-1356`). No Revision 2
   override selects one model, so migration, RPC, and UI work cannot follow
   both authorities.

3. **[doc-drift] v1/v2 scope is contradicted by the v1 DoD.** D5 places
   Phases 11–12 in v2 (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:104-116`),
   and the plan labels external evaluations as Phase 11 (`:1326-1382`), but
   the section titled “ilk ... v1” requires external EBV/PTA provenance as item
   17 (`:1604-1627`). The final migration list also presents the v2 evaluation
   migration alongside the v1 sequence (`:1504-1518`) without a v2 boundary.

4. **[doc-drift] The layout boundary is not carried through the frontend task.**
   Revision 2 and Task 5 make focal `breadthfirst` a P2-only path and defer ELK
   to the P4 mating overlay (`.claude/specs/2026-09-10-pedigree-genetics-architecture.md:759-767`;
   `.claude/plans/2026-09-10-pedigree-genetics-impl.md:617-643`), but Task 6
   still assigns `ELK layered config` to the focal `pedigree-view.js`
   (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:673-679`). A worker
   cannot tell whether P2 must load ELK or must not load it.

5. **[scope-violation] The plan's commit flow conflicts with the active repo
   flow.** The plan says implementers do not commit and a coordinator commits
   (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:9-12`), while the active
   goal requires workers to commit their own branches and the lead to merge
   (`.harness/goals/2026/G-20260910-UREME-STOK-BUGFIX.md:85-88`). Following the
   plan loses the branch commit/waiter handoff contract.

6. **[doc-drift] BUGS.md still presents already-incorporated DOC fixes as
   pending.** `BUGS.md:96-120` says DOC-001..006 must be reflected in the
   spec/plan, but the current plan already addresses the type, stock, UI
   surface, RPC_MAP, farm_id, and SQL-runner points at
   `.claude/plans/2026-09-10-pedigree-genetics-impl.md:159-178,919-924,930-940,1459-1474`.
   Without a resolved/status marker, BUGS.md remains a contradictory action
   source and can cause the same documentation work to be repeated.

## Gaps

1. **[scope-violation] The write manifest is incomplete for its own Task 27.**
   Task 27 authorizes modifications to `supabase/migrations/99999999999999_ground_truth.sql`,
   `.harness/references/rpc-reference.md`, `ARCHITECTURE.md`, and conditional
   README files (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:1448-1457`),
   but the “final repo change map” at `:1522-1583` omits the harness RPC
   reference, `ARCHITECTURE.md`, and README. D5 says that map is copied into
   each worker manifest (`:119-120`), so a compliant worker either cannot do
   Task 27 or must violate the manifest.

2. **[doc-drift] The ET gate names the wrong phase.** The plan says the ET
   decision must precede “Phase 4” birth parentage writes
   (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:231-235`), but the plan's
   Phase 4 is graph rendering (`:613-757`) and the birth parentage task is
   Phase 7 (`:1008-1076`); the spec places the ET prerequisite before its
   reproduction Phase 2 (`.claude/specs/2026-09-10-pedigree-genetics-architecture.md:524-526`).
   This phase mismatch can open the wrong rollout gate.

3. **[unmeasured-claim] The farm-scope invariant is only described in RPC
   prose, not secured by the proposed relations.** The DDL links node IDs but
   not their `farm_id` values (`.claude/specs/2026-09-10-pedigree-genetics-architecture.md:213-227,245-260,290-303`); the plan only specifies a
   same-farm check inside `pedigree_parent_set`
   (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:349-360`). No composite
   FK/trigger or complete table-DML denial is specified for `semen_catalog`,
   parentage, or evaluations. The promised cross-farm rejection test at
   `:254-263` therefore depends on an unstated privilege boundary.

4. **[unmeasured-claim] The shared stock rule is not stated with the goal's
   whitespace guard.** The active goal requires empty *or whitespace* sperma
   never to deduct (`.harness/goals/2026/G-20260910-UREME-STOK-BUGFIX.md:56-63`),
   but the plan's D4 and Task 10 repeat only “empty” (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:89-92,886-893`). The SQL acceptance contract can therefore pass while a whitespace input remains a write-path decision.

## VERDICT: FAIL

The documents are not ready to serve as implementation authority. The cache
and v1/v2 contradictions, missing RPC contracts/paths, unavailable migration
gate, incomplete manifest, and unenforceable `%100 semen_id` criterion are
blocking; they can lead to incompatible schemas, dead UI paths, or a green
acceptance result that does not establish the promised state.

## Confidence and unverified boundaries

Repository facts, tracked migration/reference text, package scripts, UI symbols,
and file existence were checked locally. I could not access the live database,
so current live RPC bodies/signatures, live column types, the 207-row maternal
spot-check, the live farm_id inventory, ET history, and the reported PROD
errors remain **UNVERIFIABLE FROM REPO — REQUEST EVIDENCE**. The tracked
ground-truth SQL was used only as a subordinate reference and not as live-schema
proof.
