# P2 "Ağaç" package — independent lead review

Review target: `idle/pedigree-p2` at `1a88e4e`, compared with the task-pinned
base `88684dd` (not the later symbolic `main` tip). Review scope is the P2
manifest plus the authorized B3 `js/ui.js` / `js/utils/handlers.js` touch.

## Findings

### F1 — Frontend acceptance is not mechanically covered

- **Evidence:** `.harness/goals/2026/G-20260911-PEDIGREE-P2-AGAC.md:66-70`
  requires adapter/style/view/controller unit coverage. The diff contains only
  `tests/unit/pedigree-adapter.test.js:38-154`; there are no controller, view,
  or style tests. `tests/support/stub-backend.js:93-100` adds RPC counters, but
  `tests/support/app.js:12` does not import them and no test asserts them.
- **Why:** The green tests exercise the adapter and API/cache in isolation, not
  lazy tab activation, stale-response fencing, node routing, view lifecycle,
  badge behavior, or the real stub-backed caller chain.
- **Impact:** G3d and the claim that the counters prevent a fake arm remain
  unmeasured; frontend regressions can pass the reported suite.
- **Severity:** major
- **Defect class:** fake-arm

### F2 — Stub pedigree fixture is not contract-shaped and does not recenter

- **Evidence:** the production invariant requires `farm_animal` nodes to have
  a non-null `farm_animal_id` (`supabase/migrations/20260911000002_pedigree_foundation.sql:46-50`),
  but `tests/support/stub-backend.js:52-64` emits `PED_GD` and `PED_GGD` as
  `farm_animal` with `farm_animal_id: null`. `pedigreeFixtureForNode()` only
  changes `focus` and leaves nodes/edges unchanged (`tests/support/stub-backend.js:79-84`);
  unknown animal ids silently fall back to the focal graph
  (`tests/support/stub-backend.js:87-90`).
- **Why:** The controller opens a farm animal only when both kind and id are
  present (`js/pedigree/pedigree-controller.js:242-249`), so the fixture routes
  those malformed farm nodes through the external sheet and cannot model a
  true node-centered projection or unknown-id error.
- **Impact:** Stub-backed demo/E2E paths can report a successful 4-generation
  flow while exercising the wrong node-routing and `subgraphForNode` semantics.
- **Severity:** major
- **Defect class:** fake-arm

### F3 — SQL fixture does not exercise the claimed 166/59 production-shaped graph

- **Evidence:** the goal requires the SQL fixture to operate over the P1
  `166 node / 59 edge` demo graph (`.harness/goals/2026/G-20260911-PEDIGREE-P2-AGAC.md:56-60`),
  but `tests/sql/pedigree_projection_rpc_test.sql:24-117` creates its own
  synthetic graph and every assertion targets those `v_*` test ids
  (`tests/sql/pedigree_projection_rpc_test.sql:156-343`); the 166/59 values
  appear only as a comment (`tests/sql/pedigree_projection_rpc_test.sql:4-6`).
  The transaction then rolls the synthetic graph back
  (`tests/sql/pedigree_projection_rpc_test.sql:380-384`).
- **Why:** A green A–L fixture proves the handcrafted topology, not projection
  behavior against the existing P1 dataset or a production-shaped focal path.
- **Impact:** Regression in the live-data join/selection path can remain green;
  the separate read-only live probe below is not part of the fixture gate.
- **Severity:** major
- **Defect class:** fake-arm

### F4 — Invalidation has a late-writer race

- **Evidence:** a cache miss writes its result unconditionally after `await`
  (`js/pedigree/pedigree-api.js:82-89`), while invalidation only clears the Map
  (`js/pedigree/pedigree-api.js:137-144`). Existing tests cover only sequential
  invalidation (`tests/unit/pedigree-cache.test.js:100-115,172-189`). A direct
  deferred-RPC probe produced `{"calls":1,"sizeAfterLateWriter":1,"revision":1,"cached":true}`:
  `invalidateCache()` ran before the in-flight response, yet that stale response
  repopulated the cache and the next cache-first read skipped the network.
- **Why:** A graph write can complete and invalidate while an older projection
  request is still in flight; its post-invalidation writer has no generation or
  request fence.
- **Impact:** The first post-write tree can serve pre-write pedigree data until
  another invalidation or session reset.
- **Severity:** major
- **Defect class:** race-lifecycle

### F5 — `integrityReport()` mutates the P1 report shape with graph-cache metadata

- **Evidence:** `_sealCached()` adds `meta.cached` to every object
  (`js/pedigree/pedigree-api.js:63-70`), and `integrityReport()` uses that
  generic path (`:128-133`). The P1 RPC returns the report object with
  `generated_at`, `cutoff`, and `groups` (`supabase/migrations/20260911000003_pedigree_farm_backfill.sql:472-476`),
  while the API test checks only call/key wiring (`tests/unit/pedigree-api.test.js:98-108`).
  A direct shape probe returned keys `cutoff,generated_at,groups,meta`.
- **Why:** The cache receipt is meaningful for projection payloads consumed by
  the tree, but the generic wrapper adds a new top-level field to the existing
  integrity-report contract without a shape test or documented exception.
- **Impact:** Strict or key-set-sensitive integrity consumers can observe a
  contract drift; the report path has no regression lock.
- **Severity:** minor
- **Defect class:** doc-drift

## Re-run summary

- `git diff --stat 88684dd..idle/pedigree-p2` and `git diff --name-status
  88684dd..idle/pedigree-p2`: 20 changed manifest surfaces; no product path
  outside the stated P2/B3 scope.
- `npm run test:unit`: direct exit `1`; `762` tests, `761` passed, one known-red
  `tests/unit/gecmis-pipeline.test.js:283` failure (`DÜN` assertion), matching
  the envelope's allowed known-red boundary.
- `node --test tests/unit/pedigree-api.test.js tests/unit/pedigree-cache.test.js
  tests/unit/pedigree-adapter.test.js`: direct exit `0`; `25/25` passed.
- Demo target probe using the task-provided ref `vtzqjmazsvurxdeondmi`: direct
  `psql` probe returned `postgres|postgres|166|59`, exit `0`.
- `psql ... -v ON_ERROR_STOP=1 -f tests/sql/pedigree_projection_rpc_test.sql`:
  direct exit `0`; emitted `TESTDONE:pedigree_projection_rpc_test tamam — 12
  blok (A-L) yesil`, then `ROLLBACK`.
- Read-only connected live projection probe: direct exit `0`; returned
  `2 nodes / 1 edge`, effective depth `4/3`, `truncated=false`.
- `node --check js/pedigree/*.js`: all five files direct exit `0`.
- `sha256sum vendor/cytoscape.min.js`: `5f3b5b529546d5af1fc5628590af033b74511a5b6f789f5f4682845863228b91`;
  the file footer reports Cytoscape `3.34.3`.
- Local browser smoke remained **UNMEASURED**: Playwright Chromium is not
  installed, and the system Firefox launch exited before the Juggler pipe was
  available. No browser PASS was inferred from the static/version checks.

## Explicit boundaries

- W2 explicitly defers production graph-write callers to P3
  (`.claude/tasks/2026-09-11-pedigree-p2-W2.md:19-21`); this review therefore
  records the late-writer defect in the exposed invalidation primitive rather
  than treating absent P3 callers as a separate scope finding.
- PROD was not accessed. Demo SQL test data was transaction-scoped and rolled
  back.
