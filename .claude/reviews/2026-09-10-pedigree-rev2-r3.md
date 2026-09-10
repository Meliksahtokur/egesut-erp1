# Pedigree Revision 2 Review — Round 3

## Review basis and incoming-work gate

The assigned r3 checkout is `idle/pedigree-rev2-review-r3` at
`259df95e2b454d16e9054ced8784d158bb917645`. It is 21 commits behind local
`main` (`088a6d6`), and the five named review artifacts are absent from the r3
tree. They are present in the same repository at `main`; therefore all line
references below are to the material at `main@088a6d6`. The r3 branch was not
rebased or otherwise changed to obtain it.

Incoming-work gate: **ACCEPT AND START with an environment-boundary note**.
The report-only scope and acceptance shape are measurable; the checkout
boundary is recorded in the gate crumb. No live DB access was available.
The evidence file is treated as the only source for live claims, and its
explicit gaps remain unverified.

## 1. Round-2 resolution check

Status is judged from the current artifacts, not from revision banners or
author summaries. `PARTIAL` means a material part is fixed but an acceptance
or authority gap remains; `UNRESOLVED` means the claimed repair is still not
executable or safe.

### Round-2 resolution-table items

| ID | Status | Current evidence and residual |
|---|---|---|
| A1 | **RESOLVED** | Task 1.7 now gives a tracked `scripts/db-dry-run.sh` task, TMPDIR-safe replacement, dependency handling, and acceptance (`plan:485-492`; final map `plan:1746-1748`). The tool itself is not yet implemented, which is expected at plan-review time. |
| A2 | **RESOLVED** | The spec points to `.harness/contract.md` and identifies the owner-local `.claude` copy as non-authoritative (`spec:205-211,409-417`). |
| A3 | **RESOLVED** | The claim is scoped to live/product schema and explicitly excludes the demo helper (`plan:1636-1642`); the demo table remains separately identified. |
| A4 | **PARTIAL** | S1-S3 catalog/body evidence is present (`live-probe-evidence:21-65`), but the artifact still says PROD 42804 and the 207-row maternal probe are not measured (`live-probe-evidence:67-74`); Task 0.2's complete signature/type set is not attached (`plan:166-190`). |
| I1 | **RESOLVED** | `semen_catalog_upsert` now has an explicit helper contract and is the planned “Elle Gir” path (`plan:408-442`). |
| I2 | **RESOLVED** | `pedigree_profile` has a JSON contract (`spec:663-694`) and Task 17 now creates it before Task 21 consumes it (`plan:1350-1353,1458-1474`). |
| I3 | **PARTIAL** | The four semen-aware signatures and equivalence rule are stated (`plan:991-1022`), but the legacy return/error fixture still depends on live evidence that does not contain those measurements. |
| I4 | **UNRESOLVED** | The grant block still contains invalid `...` function signatures and a grant for the wrong arity (`plan:383-400`; `pedigree_parent_set` is six-argument in `plan:415-436` but the grant names five types). |
| I5 | **RESOLVED** | The impossible cold-start/reopen claim is replaced with an already-open tab losing network (`spec:943-950`; `plan:701-724,1560-1571`). |
| I6 | **PARTIAL** | A cutoff query and filename authority were added (`plan:552,1146-1153`), but the cutoff is not stored/queried as a migration value and the fixed filename conflicts with the later next-free timestamp rule (`plan:1690`). See fresh F6. |
| I7 | **PARTIAL** | The destination and maternal probe query are named (`plan:185-190,244-257`), but the evidence file still lacks the probe output, full live type/signature results, and a commit-backed ET owner decision (`live-probe-evidence:67-74`; `plan:259-264`). |
| C1 | **RESOLVED** | Metric/founder tables and invalidation are consistently marked v2/on-demand in the active schema and plan boundaries (`spec:315-405,1037-1046`; `plan:129-136,1266-1278`). |
| C2 | **RESOLVED** | Both artifacts use long-form trait rows and the same uniqueness dimensions (`spec:315-341`; `plan:1488-1508`). |
| C3 | **PARTIAL** | Phase/DoD text moves external EBV/PTA to v2 (`spec:1184-1190,1232-1236`; `plan:111-124,1784-1805`), but the animal/semen UI surfaces still list published evaluations without a v2 qualifier (`spec:871-901`). |
| C4 | **PARTIAL** | The detailed layout boundary is fixed to focal `breadthfirst` and lazy ELK mating (`spec:838-846,1201-1209,1247-1256`; `plan:729-757`), but the top decision summary still assigns hierarchical layout generically to ELK (`spec:52`) and the final diagram still labels the frontend `Cytoscape bf + ELK` (`spec:1427-1434`). |
| C5 | **RESOLVED** | Worker/lead/root commit flow now matches the active ss-org contract (`plan:11-17`). |
| C6 | **PARTIAL** | `BUGS.md` now labels DOC-001..006 met, but the same section records DOC-006 as only partially met because the tracked gate remains a debt (`BUGS:97-103,128-133`). |
| G1 | **RESOLVED** | Task 27 and the final map now include the harness RPC reference, `ARCHITECTURE.md`, and conditional README paths (`plan:1615-1624,1694-1744`). |
| G2 | **RESOLVED** | The ET gate is now tied to plan Phase 7/spec reproduction Phase 2 (`plan:259-264`; `spec:1184-1219`). |
| G3 | **PARTIAL** | Parentage now has farm-paired columns/FKs (`spec:218-252`; `plan:329-351`), but `semen_catalog` and evaluation links remain single-column in the actual DDL (`spec:270-285,324-341`; `plan:353-359`). N3 remains unresolved. |
| G4 | **RESOLVED** | Empty/whitespace guard, exact-before-substring, and the shared three-path rule are explicit (`spec:531-538`; `plan:90-109,1024-1031`). |

### Round-2 N findings

| ID | Status | Current evidence and residual |
|---|---|---|
| N1 | **UNRESOLVED** | Foundation grants still use `...` for `pedigree_external_upsert` and `semen_catalog_upsert`, and `pedigree_parent_set` is granted with five rather than six argument types (`plan:383-387,415-436`). The first foundation migration can still fail before acceptance. |
| N2 | **RESOLVED** | The plan now specifies `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`, `USING(true)` policies, no graph-table client grant, and `SECURITY DEFINER SET search_path = public, pg_temp` (`plan:361-406`). The separate invalid grant syntax remains N1/I4. |
| N3 | **UNRESOLVED** | The prose claims composite farm locking, but the `semen_catalog` DDL has only `bull_node_id ... REFERENCES pedigree_nodes(id)` and no `bull_farm_id`/composite FK (`spec:265-293`; `plan:353-359`). The upsert guard cannot repair a missing relational constraint. |
| N4 | **PARTIAL** | Farm-prefixed keys and clear-on-context-change are now stated (`plan:664-687`), but no client source for the farm ID or concrete logout/farm-change hook is defined. See F3/F4. |
| N5 | **RESOLVED** | The plan explicitly corrects the earlier false queueability claim: semen-aware writes are online-only and no `RPC_MAP` entry is added (`plan:1057-1066`). |
| N6 | **RESOLVED** | The mapping file, columns, owner/version rule, and final-map entry now agree (`plan:237-242,1746-1747`; `spec:1442-1445`). Its preflight production is still pending by design. |
| N7 | **RESOLVED** | Task 17 explicitly creates `pedigree_profile` in the mating migration and grants it (`plan:1350-1353`). |
| N8 | **RESOLVED for existence of a read path** | Task 22 now names `genetic_evaluations_for_node(uuid) -> jsonb` and its grant, and Task 23 consumes it (`plan:1480-1517`). The response/farm contract remains thin; this is a fresh residual, not the original absent-path finding. |
| N9 | **RESOLVED** | The new manual-pregnancy RPC permits `NULL` semen and the UI acceptance explicitly limits the required-ID block to insemination/repeat forms (`plan:1009-1011,1138-1144`). F1 below covers the non-empty text case. |
| N10 | **PARTIAL** | Detailed P2/P4 layout tasks are corrected, but the summary/diagram still leave ELK attached to the general frontend surface (`spec:52,1427-1434`). |
| N11 | **RESOLVED** | SQL fixtures are required to run inside `BEGIN ... ROLLBACK`, with demo-target proof and a PROD prohibition (`plan:475-483`). |
| N12 | **PARTIAL** | The plan now requires real pedigree stub handlers plus call counters (`plan:1575-1580`), but the required `tests/support/stub-backend.js` change is absent from the final change map (`plan:1750-1763`). See F5. |
| N13 | **RESOLVED** | Numeric p50/p95 limits, representative data, and max-depth constraints are now given (`plan:1582-1602`). |
| N14 | **RESOLVED** | Both spec and plan consistently require an open tab with a later network loss; cold-start offline is excluded (`spec:943-950`; `plan:723-724,1560-1571`). |
| N15 | **PARTIAL** | The spec now makes `evaluation_date` `NOT NULL` and records the reason beside the unique key (`spec:324-341`), but the plan still says `published_at / evaluation_date` without carrying that nullability/period choice into its table contract (`plan:1488-1508`). A worker can reintroduce the nullable-key defect by following the plan rather than the spec. |
| N16 | **RESOLVED** | The spec now uses `ON DELETE CASCADE` for the farm-animal node and parentage edges, matching D1 (`spec:180-202`; `plan:38-60,305-321`). |
| N17 | **PARTIAL** | Silent overwrite is blocked by `p_force_semen`, but the force path promises only an `islem_log`/text snapshot and still has no per-attempt canonical semen field or exact snapshot contract (`spec:540-546`; `plan:1004-1008,1045-1051`). A forced Armada→Fresco repeat can still erase the prior canonical ID. |

## 2. Fresh hunt

All findings below are source-proven document/repository defects; no live
database behavior is inferred.

### Accuracy

**F1 — [dead-path] Non-empty manual-pregnancy semen text has no controlled identity path.**

The current modal collects a free-text value (`index.html:2241-2244`) and the
current submit sends `p_sperma` (`js/forms.js:3599-3603`). The planned replacement
accepts only `p_semen_id uuid` (`plan:1009-1011`), while the UI section makes NULL
optional but does not define how a non-empty `geb-sperma` string becomes a
catalog row or is rejected (`plan:1120-1143`). A user can therefore enter a
non-empty semen value that the controlled RPC cannot represent: silently drop it,
fall back to the legacy free-text RPC, or block it are three different behaviors.
This violates the spec's no-new-arbitrary-free-text rule (`spec:302-313`).

**F2 — [unmeasured-claim] Parentage provenance promised by the architecture is not representable by the proposed edge schema.**

The spec says a birth edge may carry `tohumlama_id + semen_id` evidence
(`spec:256-263`) and that the graph can be rebuilt from birth plus semen
identity (`spec:456-468`), but `pedigree_parentage` contains only
`source_type`, `source_ref`, and `confidence` (`spec:218-241`). Task 12 writes
only `source_ref=dogum.id` for both parent edges (`plan:1173-1185`). Since the
current `dogum` table has no tohumlama/semen reference in the tracked schema,
an edge cannot later prove which attempt supplied the sire, especially after a
repeat or multiple eligible inseminations. The claimed audit/rebuild property
has no stable, queryable field contract.

**F3 — [dead-path] The farm-scoped cache key has no client-side farm-context source.**

The cache key requires `farm:<farm_id>...` and the policy requires matching it
before an offline lookup (`plan:664-687`), but the current client configuration
and table state expose no farm-context value (`js/api.js:22-35`), and the plan
does not add a farm-context RPC, session claim, or state contract. A wrapper
cannot calculate the correct key when the network is already unavailable; it
must either guess the farm, omit the prefix, or fail to find an otherwise valid
cache. The N4 key fix is therefore not yet an executable offline design.

### Implementability

**F4 — [scope-violation] Sign-out invalidation is required but has no implementation surface.**

The plan requires clearing `pedigree_cache` on exit/farm-context changes
(`plan:684-687,708-723`). The actual logout path only signs out and reloads
(`js/auth.js:239-265`); it does not clear the store. The final change map names
`js/api.js`, `js/app.js`, `js/forms.js`, `js/ui.js`, and pedigree files, but not
`js/auth.js` or an equivalent auth-event hook (`plan:1694-1763`). After a
sign-out, the next session can reopen stale graph data unless an undeclared file
or undocumented hook is added.

**F5 — [scope-violation] The required E2E stub fix is outside the declared change map.**

Task 24 requires modifying `tests/support/stub-backend.js` with pedigree RPC
handlers and call counters (`plan:1575-1580`), but the final map lists only
`tests/unit`, `tests/sql`, and `tests/pedigree.spec.js` (`plan:1750-1763`). A
worker following the copied manifest cannot make the fake-green fix without
scope expansion; leaving the stub unchanged preserves the existing unknown-RPC
`{ok:true}` arm (`tests/support/stub-backend.js:131-140`).

**F6 — [doc-drift] The new semen cutoff is contradicted by migration numbering and lacks a proven timestamp column.**

Task 11 fixes the cutoff to the literal filename timestamp
`20260910000005_semen_controlled_writes.sql` (`plan:1146-1153`), while the
migration section says all timestamps are selected by a next-free rule after
the reproduction bugfix migrations (`plan:1676-1690`). If the file is renamed,
the integrity report's `created_at > cutoff` boundary no longer identifies the
controlled-write release. The tracked main ground-truth table definition does
not show `tohumlama.created_at` (`supabase/migrations/99999999999999_ground_truth.sql:115-130`),
and the evidence file explicitly omits the complete live type inventory
(`live-probe-evidence:67-74`). The cutoff is therefore neither stable nor live-
verified.

**F7 — [unmeasured-claim] Kinship/inbreeding is not specified tightly enough for reproducible implementation.**

The spec names a “Wright-compatible” server calculation and concepts
(`spec:729-754`); the plan names a “tabular numerator relationship /
kinship-compatible” approach and five fixtures (`plan:1296-1335`). It does not
define the recurrence, founder/inbred-ancestor handling, duplicate/shared-node
counting, missing-parent behavior, or depth truncation. Different algorithms
can pass the listed unrelated/parent/sibling fixtures while returning different
values for an inbred ancestor or incomplete graph. The core v1 analysis cannot
produce a deterministic PASS from the current contract.

### Contradiction and gaps

**F8 — [doc-drift] The canonical node DDL does not encode its own farm-node invariant.**

The spec's SQL checks only that `node_kind` is one of two strings
(`spec:180-202`); the conditional requirement “farm animal implies
`farm_animal_id IS NOT NULL`, external implies NULL” appears only in prose
(`spec:205-210`). The plan separately says a DB CHECK is required
(`plan:316-321`), so an executor following the spec literal can create an
invalid farm node and still pass the shown DDL. The canonical schema example
and implementation authority need one exact constraint and a regression case.

**F9 — [dead-path] The new v2 evaluation read path still lacks a response and tenant contract.**

The repair adds only `genetic_evaluations_for_node(uuid) -> jsonb` plus a grant
(`plan:1514-1517`). It does not define the JSON shape/order, a same-farm guard,
or how `node_id` is checked against the caller's farm, while the evaluation DDL
itself uses a single-column node FK (`spec:324-341`). The UI acceptance can be
implemented with incompatible payloads or can read a node from another farm;
N8 is fixed only at the name-of-RPC level.

## 3. VERDICT: FAIL

The documents are **not ready to serve as implementation authority**.

Blocking reasons are the still-invalid foundation grants (N1/I4), the missing
semen/farm relational enforcement (N3/G3), incomplete live preflight evidence
(A4/I3/I7), and the new dead or non-reproducible paths for manual pregnancy,
cache context/invalidation, birth provenance, evaluation reads, and kinship
calculation. The v1/v2 and focal-layout boundaries also retain contradictory
surface text. A green implementation run could therefore fail at migration
parse time, lose canonical identity/provenance, or pass a fake/offline test
without proving the intended tenant-scoped behavior.

## 4. Confidence and unverified boundaries

Confidence is high for the static findings: the current spec, plan, previous
reports, current tracked source, final change map, and exact r3/main commit
relationship were checked locally. Confidence is limited for live behavior:
there was no live DB access, and the evidence artifact contains only S1-S3. The
PROD 42804 reproduction, full live signatures/types/return contracts, 207-row
maternal probe, ET decision, mapping output, and current farm inventory remain
**UNVERIFIABLE FROM THIS REVIEW SEAT** until authorized probes attach their
outputs. The report itself is the only file written on this branch.
