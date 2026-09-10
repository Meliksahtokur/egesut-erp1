# Pedigree Revision 2 Review — Round 2

Review checkout: `idle/pedigree-rev2-review-r2`, after `git merge --ff-only main`,
at `7208e92`. The four material files named by the task were present. This is a
read-only review of the current spec, plan, round-1 report, evidence file, and
repository sources; no live database access was available.

Reference aliases used below: `spec` =
`.claude/specs/2026-09-10-pedigree-genetics-architecture.md`; `plan` =
`.claude/plans/2026-09-10-pedigree-genetics-impl.md`; `live-probe-evidence` =
`.claude/reviews/2026-09-10-live-probe-evidence.md`; `BUGS` = `BUGS.md`.

## Incoming-work gate

**ACCEPT AND START.** The envelope has a single report path, measurable output
requirements, and an explicit live-DB boundary. The live assertions are treated
as evidence-file claims only where that file actually contains the relevant
query/output.

## 1. Round-1 finding resolution

| ID | Round-1 finding | Status | Current evidence and residual |
|---|---|---|---|
| A1 | `scripts/db-dry-run.sh` is absent and the observed copy violates the temporary-file rule. | **PARTIAL** | The plan now admits the tool is untracked and makes psql/demo the interim path (`plan:1551-1558`), but supplies no concrete P1 task, tracked path, command, or acceptance for the promised TMPDIR-safe replacement. The worker migration gate therefore remains non-reproducible. |
| A2 | `.claude/farm-id-discipline.md` is a dead source reference. | **RESOLVED** | The spec names `.harness/contract.md` as authoritative and identifies the `.claude` copy as owner-local/untracked (`spec:206-210,394-402`). |
| A3 | “First `farm_id` table” was false because `demo_klon_log` exists. | **RESOLVED** | The plan scopes the claim to live production/product schema and explicitly excludes the demo helper (`plan:1559-1565`); the repository confirms the demo-only column (`demo/02_demo_klonla.sql:6-17`). |
| A4 | Live claims lacked evidence. | **PARTIAL** | The new evidence file contains catalog/signature and stock-body output S1–S3 (`live-probe-evidence:1-65`). It explicitly does not measure the PROD 42804 or the 207-row maternal spot-check (`live-probe-evidence:67-74`), and it does not cover every Task 0.2 signature/type. |
| I1 | Manual catalog creation had no implementing RPC. | **RESOLVED** | `semen_catalog_upsert` now has a parameter list in the foundation helper contract (`plan:390-404`) and is the “Elle Gir” path (`plan:1054-1070`). |
| I2 | v1 founder-profile delivery had no endpoint contract. | **PARTIAL** | `pedigree_profile` now has a JSON contract in the spec (`spec:640-671`) and is named by Task 21 (`plan:1396-1412`), but Task 21 does not create the RPC or name a migration that does so. See N7. |
| I3 | Semen-aware RPC signatures were not executable. | **PARTIAL** | The four signatures, parameter types, return-equivalence rule, affected-table rule, and equivalence-test requirement are now stated (`plan:937-985`), but “same error behavior” still points at an unstated live legacy contract rather than a concrete error/return fixture. |
| I4 | Required grants were asserted but not specified. | **PARTIAL** | Named grants were added (`plan:358-367`), but two still contain invalid `...`, one uses `pedigree_subgraph(jsonb)` while Task 3 defines `(uuid,integer,integer)`, and later RPCs are granted from the foundation section. The block is not executable as written; see N1 and N2. |
| I5 | Phase 3 required an impossible offline reopen. | **PARTIAL** | Task 4, Task 7, and the full-suite scenario consistently describe an already-open tab losing network (`plan:635-670,794-817,1493-1504`), but the spec still says both that cold-start is impossible and that a second opening serves the cached projection (`spec:922-926`). See N14. |
| I6 | Database-wide `%100 semen_id` was unenforceable with legacy RPCs open. | **PARTIAL** | The plan correctly downgrades the hard guarantee to v2 and narrows v1 to UI plus an integrity query (`plan:1084-1091`). However, the cutoff is only prose (“migration note”), has no stored/queried authority, and Task 2’s report contract is not updated to implement it. |
| I7 | Live preflight gates had no reproducible destination/command. | **PARTIAL** | The evidence destination is now named and several inventory queries are concrete (`plan:166-190,192-248`), but ET ownership/decision format, the 207-row probe command/output, and several live type/signature probes remain unspecified or absent (`live-probe-evidence:67-74`). |
| I8 | Human-reviewed identity mapping was an unnamed dependency. | **RESOLVED** | The plan now names a commit-backed mapping file, columns, owner, version, and “no file/no version” gate (`plan:237-242`). The prerequisite file has not yet been produced, which is expected preflight state; its omission from the final map is a new defect (N6). |
| C1 | v1 metric-cache removal conflicted with later cache requirements. | **PARTIAL** | The metric/founder tables and invalidation are explicitly v2 in the revision notes (`spec:340-392`; `plan:1204-1233,1344-1349,1613,1678`), but the spec’s active schema-additive section still lists all three derived tables without a v2 boundary (`spec:1013-1022`). The remaining v1 cache references are projection/IDB cache, but the schema list can still be read as v1 work. |
| C2 | Evaluation schema differed between spec and plan. | **RESOLVED** | Both now use long-form trait rows and the same fields/key (`spec:300-326`; `plan:1418-1446`). N15 identifies a remaining nullable-key defect in that shared schema. |
| C3 | External evaluation was still in the v1 DoD. | **PARTIAL** | D5 places Phases 11–12 in v2 and the DoD explicitly marks EBV/PTA as v2/outside v1 (`plan:111-124,1416-1474,1723`), but the spec still exposes published evaluations in the v1 mating result and animal/semen surfaces (`spec:612-624,848-879`). N8 shows that the boundary has not been carried through the data path. |
| C4 | The focal layout boundary was not carried through the frontend task. | **PARTIAL** | Task 5/6 now clearly make P2 `breadthfirst` and P4 ELK-lazy (`plan:675-703`). The spec’s Phase 1, tech-stack table, and final diagram still say or imply Cytoscape + ELK for the general v1 surface (`spec:1177-1185,1223-1232,1403-1405`); see N10. |
| C5 | Commit flow conflicted with the active ss-org flow. | **RESOLVED** | The plan now states worker-branch commits, lead merge, root main merge, and owner push gate (`plan:11-17`), matching the active goal’s worker/lead flow. |
| C6 | `BUGS.md` presented incorporated DOC fixes as pending. | **PARTIAL** | The header now says DOC-001..006 are met (`BUGS:97-103`), but DOC-001..004 remain written as “must be corrected” and DOC-006 still records a tracked-gate debt (`BUGS:105-132`). The action source is still internally contradictory. |
| G1 | Task 27 authorized files omitted from the final change map. | **RESOLVED** | Task 27 and the final map now include the harness RPC reference, `ARCHITECTURE.md`, and conditional README paths (`plan:1538-1547,1665-1667`). |
| G2 | ET gate named the wrong phase. | **RESOLVED** | The plan now distinguishes plan Phase 7 from spec Phase 2 and places the gate before birth integration (`plan:250-254`; `spec:549,1187-1195`). |
| G3 | Farm scope was only RPC prose, not relation enforcement. | **PARTIAL** | Composite-FK intent is now stated for parentage (`spec:234-242`; `plan:337-342`), but the actual table definitions do not contain the promised paired columns/constraints, and semen/evaluation node links remain single-column FKs. See N3. |
| G4 | The shared stock rule omitted the whitespace guard. | **RESOLVED** | The empty/whitespace guard, exact-before-substring rule, and three-path dependency are explicit in D4/Task 10 (`plan:90-99,968-973`) and the spec (`spec:516-523`). |

## 2. New findings

### Accuracy and implementability

1. **[dead-path] Foundation grant block cannot run in the planned order.**
   `plan:358-369` contains `GRANT ... pedigree_subgraph(jsonb)` although Task 3
   defines `pedigree_subgraph(uuid, integer, integer)` (`plan:521-539`), and
   `GRANT ... (...)` is not valid PostgreSQL function-grant syntax. The same
   foundation block grants `pedigree_subgraph_for_animal` and `pedigree_profile`
   before their later Task 3/Task 21 definitions (`plan:513-539,1396-1401`). A
   worker applying the foundation migration therefore gets a missing-function
   or invalid-syntax error before the schema can be accepted.

2. **[dead-path] RLS and RPC execution security are asserted, not implemented.**
   `plan:352-375` says all new tables are RLS-enabled, denies direct graph
   grants, and grants `semen_catalog`, but supplies no `ALTER TABLE ... ENABLE
   ROW LEVEL SECURITY`, `CREATE POLICY ... USING(true)`, or exact
   `SECURITY DEFINER`/`search_path` contract for the RPCs (`plan:521-547`). The
   repository’s auth lockdown revokes default table/function access and relies
   on explicit policy/grant setup (`supabase/migrations/20260614000007_auth_gate_lockdown.sql:7-29`).
   As written, semen sync can be denied by RLS and graph RPCs can be unable to
   read/write their deliberately ungranted tables; Task 26 is a later audit,
   not an implementation gate.

3. **[scope-violation] `semen_catalog_upsert` can create semantically foreign links.**
   `semen_catalog.stock_id` and `bull_node_id` are described only as ordinary
   single-column FKs (`plan:344-350`), while the upsert contract has no
   category, same-farm, or male-node guard (`plan:390-404`). The only explicit
   sex checks are for `pedigree_parent_set` (`plan:409-427`). A valid stock FK
   can therefore point at a non-Sperma product, or a valid node FK at a female
   or another farm’s node; Task 10 then uses that `stock_id` for semen stock
   deduction (`plan:968-973`).

4. **[scope-violation] On-demand IDB cache keys omit tenant/session context.**
   The cache key examples contain only focus/cow/semen/depth/version
   (`spec:947-956`; `plan:613-620`), while the browser uses one shared
   `egesut_v12` database (`js/api.js:108-114`). No farm/user context is part of
   the key and no cache clear is specified on sign-out or farm-context change.
   An offline read after account/farm switching can render a prior context’s
   graph as the current one; this violates the same farm-scope invariant the
   DB design is meant to protect.

5. **[dead-path] Adding `*_semen` names to `RPC_MAP` does not make the existing forms offline-queueable.**
   The plan claims the existing tohumlama path is queueable and requires
   `RPC_MAP` updates (`plan:995-1004`), but both actual submit functions reject
   offline before creating a queue item (`js/forms.js:317-322,407-423`). The
   current map has one `tohumlama` POST target, the legacy RPC, with no payload
   discriminator (`js/ui.js:8001-8015`). Merely adding new RPC names cannot
   route a queued record to the semen-aware function or preserve `semen_id`;
   the stated offline canonical-write acceptance is therefore a dead path.

6. **[scope-violation] The required identity-mapping file is outside the final manifest and contradicts the spec’s “no extra document” statement.**
   Task 0.3/Task 8 require `.claude/specs/2026-09-10-pedigree-semen-mapping.md`
   (`plan:237-242,823-832`), and D5 says worker manifests copy the final map
   (`plan:126-127`). The final map contains no mapping file (`plan:1617-1682`),
   while the spec says no additional document is needed (`spec:1414-1445`). A
   compliant worker can neither produce nor declare the required prerequisite
   without violating one of these authorities.

7. **[dead-path] v1 `pedigree_profile` has a contract but no creation task.**
   Task 21 only consumes `pedigree_profile` (`plan:1396-1412`); no task says to
   create it, and the migration sequence contains no profile migration
   (`plan:1599-1613`). The foundation grant also presumes it exists (N1). The
   v1 “Genetik” subtab consequently has no executable backend delivery step.

8. **[dead-path] v2 external-evaluation UI has no read data path.**
   Task 22 creates only the `genetic_evaluations` table and Task 23 describes a
   display (`plan:1416-1472`). D3 excludes the table from full sync
   (`plan:76-88`), Task 1.3 defines neither a read RPC nor a table SELECT grant
   for it (`plan:358-374`), and no evaluation-read wrapper is specified. The
   Phase 11 UI cannot obtain published values from the planned surfaces.

9. **[doc-drift] Manual pregnancy’s optional semen behavior conflicts with the new required-ID flow.**
   The current modal says semen may be left blank (`index.html:2241-2244`),
   and the current submit sends `p_sperma || null` (`js/forms.js:3591-3607`).
   The new RPC has a non-default `p_semen_id uuid`, while Task 11 requires
   “no selected semen id → submit block” (`plan:954-956,1072-1082`). The plan
   does not say whether semen-less manual pregnancy remains valid, how NULL is
   represented in the new RPC, or which compatibility acceptance wins.

### Contradictions and acceptance gaps

10. **[doc-drift] The spec still assigns ELK to the focal v1 surface.**
    Revision 2 says focal v1 is built-in `breadthfirst` and ELK is mating-only
    lazy load (`spec:815-823`), and the plan implements that boundary
    (`plan:675-703`). But the spec’s v1 Phase 1 acceptance package says
    “Cytoscape + ELK,” its tech table names ELK without the mating qualifier, and
    the final diagram labels the frontend “Cytoscape + ELK”
    (`spec:1177-1185,1223-1232,1403-1405`). A worker following the spec can
    ship the wrong initial byte/load path.

11. **[scope-violation] SQL acceptance can write to an unspecified database and has no required rollback contract.**
    Task 1 still describes a “local/test DB” (`plan:438-442`), while Task 27
    says that environment does not exist and runs fixtures against arbitrary
    `DATABASE_URL` (`plan:1551-1558`). The plan does not require the new
    fixtures to begin/rollback or assert a demo-only target, despite the repo’s
    tracked SQL test explicitly using `BEGIN` (`tests/sql/hayvan_grup_padok_sync_test.sql:1-5`).
    A normal worker execution can therefore persist test rows or target an
    unintended live database.

12. **[fake-arm] The available Playwright stub can report success without exercising pedigree behavior.**
    The stub has no pedigree handlers/fixtures (`tests/support/stub-backend.js:23-49,79-106`),
    returns `{ok:true}` for unknown RPCs (`tests/support/stub-backend.js:131-140`),
    and returns empty arrays for unknown tables (`tests/support/stub-backend.js:149-157`).
    The plan’s “full local/demo regression” and pedigree scenarios
    (`plan:1478-1506,1686-1726`) can therefore be green while projection,
    profile, mating, and controlled-write behavior is absent from the test
    backend.

13. **[unmeasured-claim] Performance acceptance has no numeric gate.**
    Task 25 asks for 4-gen, 6-gen, and 8-gen measurements but accepts “anlık
    hissedilmeli” and “no unbounded query” without latency thresholds, dataset
    fixtures, query-count limits, or a command/output format (`plan:1508-1525`).
    This cannot produce a reproducible PASS/FAIL for the performance criterion.

14. **[fake-arm] The spec contradicts its own offline shell limitation.**
    It correctly says the app cannot cold-start offline, then states that the
    second opening should serve the last local projection (`spec:922-926`).
    The plan only defines an already-open-tab network-loss scenario
    (`plan:645-670`). Without a service-worker/app-shell path, “second opening
    offline” is not an executable acceptance scenario.

15. **[silent-success] The shared evaluation uniqueness key does not protect undated rows.**
    Both documents make `evaluation_date` nullable but include it in the
    unique key (`spec:308-326`; `plan:1426-1446`). PostgreSQL permits multiple
    NULL values in a normal unique constraint, so repeated undated
    node/source/trait rows are accepted as distinct. The v2 plan has no
    normalization, partial unique index, or explicit “undated is forbidden”
    rule.

16. **[doc-drift] The lifecycle DDL still has two incompatible authorities.**
    The spec’s canonical `pedigree_nodes` example uses `ON DELETE SET NULL`
    (`spec:181-201`) while the same spec requires a `farm_animal` node to keep
    `farm_animal_id` non-null (`spec:204-210`). D1 in the plan correctly chooses
    `ON DELETE CASCADE` (`plan:38-60,296-312`), but it does not repair the
    architecture spec. An implementer following the spec literal can leave an
    invalid orphan; an implementer following the plan creates a different DDL
    than the stated architecture.

17. **[silent-success] Repeat insemination loses prior canonical semen identity.**
    The current tracked repeat-RPC reference snapshots only the prior text
    `sperma` and updates the single `tohumlama` row’s text (`supabase/migrations/99999999999999_ground_truth.sql:10744-10759`).
    The plan makes `tohumlama.semen_id` authoritative and gives the repeat
    variant one new `p_semen_id` (`spec:280-298`; `plan:950-964`), but defines no
    per-attempt `semen_id` history and no prohibition/enforcement when the
    repeat uses a different semen. Armada followed by Fresco can therefore
    leave the first attempt without a canonical identity even though both
    writes succeed; pedigree reconstruction cannot recover it from the planned
    columns.

## 3. VERDICT: FAIL

The documents are **not ready to serve as implementation authority**. The
round-1 farm-scope and dry-run gates remain incomplete, and the current plan
adds migration-blocking grant syntax/order errors, missing RLS/security DDL,
an absent profile implementation step, no evaluation read path, an unsafe SQL
execution boundary, a dead offline-write claim, a manifest contradiction
around the required identity mapping, and loss of repeat-semen provenance. The
spec also retains conflicting lifecycle/layout/offline statements, while the
available E2E stub can produce false green acceptance.

## 4. Confidence and unverified boundaries

Confidence is high for the repository/document findings: exact paths, line
references, current static script wiring, current form guards, current test
stub behavior, and the post-merge HEAD were checked locally. Confidence is
limited for live state because this review seat had no live DB access. The
evidence artifact contains the root’s S1–S3 catalog/body measurements, but does
not independently establish them here and explicitly leaves the PROD 42804,
the 207-row maternal spot-check, ET history, complete live signatures/types,
and live farm inventory unverified (`live-probe-evidence:67-74`). Those claims
remain **UNVERIFIABLE FROM THIS REVIEW SEAT** until the authorized probes are
rerun and their outputs are attached.
