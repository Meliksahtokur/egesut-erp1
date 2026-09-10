# Pedigree Revision 2 Review — Round 9

## Review basis and incoming-work gate

The post-round-8 target material is read-only `main@7b0c4a72a3801a8d5ce0eb3fc936be3fb99629fe`.
This worker checkout remains at `2917c6b17ac1a06a2b1cecf892fa898992db55bd`; the
round-9 task and the post-round-8 spec/plan are on local `main`, as in the
previous review setup. No merge or rebase was performed.

Citation shorthand below: `plan:` means
`.claude/plans/2026-09-10-pedigree-genetics-impl.md`, and `spec:` means
`.claude/specs/2026-09-10-pedigree-genetics-architecture.md`.

Incoming-work gate: **ACCEPT AND START**. The envelope is executable as a static
spec/plan/repository review and the report path and verdict are measurable.
Gate crumb: `59f9dd0cbd73`.

No live DB, provider, browser, or migration execution was used. The S1-S8 file
was the only source used for live claims. Prior reports and revision banners
were treated as material to verify, not as authority. No instruction-like
injection text was found in the reviewed material.

## 1. Round-8 finding resolution

`RESOLVED` means the original round-8 mechanism is coherent at the document
contract level; it does not claim that implementation exists. `PARTIAL` means
the fix is present but a contradiction or missing contract detail still blocks
implementation authority. Findings below refer to the post-round-8 `main`
tree, not to the stale worker base.

| Finding | Status | Evidence and resolution judgement |
|---|---|---|
| F40 | **PARTIAL** | The item schema now declares `stale_disposition`, missing cutoff suppresses `post_cutoff_null_semen`, invalid cutoff emits a `cutoff_invalid` blocker, and Task 2.3 gives one G2 rule (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:618-663,689-691`). However, the rollout G2 row still says only “warning/info acceptance recorded” and omits the required non-stale condition (`plan:1999-2006`), while the prose first describes a non-enum `tanımsız — controlled writes devrede değil` value (`plan:600-602`) before the exact `tanimsiz` contract (`plan:623,637-640`). See F49-F50. |
| F41 | **PARTIAL** | The explicit fix places the counter on `globalThis.__pedigreeSessionGen` and forbids a module-level counter (`plan:867-874`), which closes the original classic-script binding gap. The preceding cache-policy contract still tells an implementer to read a “module-seviye” `pedigreeSessionGen` (`plan:852-856`). The artifact therefore contains two incompatible implementations; see F46. |
| F42 | **PARTIAL** | The localStorage epoch quarantine and the rejected-IDB-clear acceptance scenario are now specified (`plan:876-884`), so the direct stale-row scenario is addressed conceptually. The required `epoch` field is absent from the declared IDB row shape (`plan:803-812`), leaving the read/write contract incomplete; see F47. |
| F43 | **RESOLVED at the original authority surface** | The client acceptance RPC and broad `authenticated` grant are removed; the plan now requires an owner-run SQL decision and grants only the hash helper no client access (`plan:665-687`, `plan:405-409`). The copied SQL template itself is not executable; that is the independent F45 implementation finding. |
| F44 | **PARTIAL** | The three previously omitted control codes are now present in the severity matrix (`plan:642-653`), so the silent omission is corrected at the naming level. No report predicate, item-key rule, NULL/unknown-date behavior, or exact legacy-vs-graph join is specified for any of them; the only occurrences are the matrix entries. See F48. |
| F33 residual | **PARTIAL** | The plan now defines the item hash, owner SQL storage shape, current-detail binding, and stale-on-change behavior (`plan:665-687`). The acceptance SQL sample is syntactically malformed, so the promised owner acceptance fixture cannot execute; see F45. |
| F36 residual | **PARTIAL** | The central Task 2.3 text now distinguishes `tanimsiz`, `gecersiz`, `cutoff_invalid`, and the G2 blocker rule (`plan:656-663,689-691`). The final rollout gate and earlier cutoff prose do not preserve the same machine-readable contract; see F49-F50. |
| F37 residual | **PARTIAL** | The old client RPC/grant risk is removed and the hash/stale mechanism is materially specified (`plan:665-687`). The owner template cannot be run as written (F45), so the acceptance mechanism is not executable authority yet. |
| F39 residual | **PARTIAL** | Fail-open cleanup, `try/finally` auth control flow, and epoch quarantine are specified (`plan:862-884`), addressing the original stale-cache-after-clear failure in concept. The cache row contract still omits the epoch required to enforce that quarantine (F47), and the guard text remains contradictory (F46). |
| N17 documented residual | **PARTIAL — documented and intentional v1 residual** | The architecture explicitly limits v1 to one `semen_id_onceki` predecessor and defers complete per-attempt semen history to v2 (`.claude/specs/2026-09-10-pedigree-genetics-architecture.md:305-326,1355-1371`; plan `1192-1196`). This is documented scope, not a new round-9 defect. |

## 2. Fresh hunt

The following are static findings against the post-round-8 artifacts.

### Accuracy / gaps

**F48 — [unmeasured-claim] VERIFIED — F44 control names have no executable detection contract.**

The only occurrences of `legacy_anne_graph_dam_celiskisi`,
`dogum_anne_graph_dam_celiskisi`, and `suspiciously_young_parent` in the plan
are the matrix comments (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:650-652`).
The plan gives no SQL predicate, item key/detail construction, behavior when a
legacy or graph dam is absent/multiple, or behavior when a parent birth date is
NULL. An implementer can therefore emit different findings from the same data,
despite the claimed exact control universe. Adding names closes F44's omission
but does not make those reconciliation checks reproducible.

### Implementability

**F45 — [doc-drift] VERIFIED — The owner acceptance SQL template is syntactically invalid.**

The template closes the `VALUES` row before applying `::text` and then leaves a
second closing parenthesis (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:673-681`):
`jsonb_build_object(...)` is closed on line 678, while line 679 is `)::text)`.
The cast must be inside the third value expression, before the single closing
parenthesis of `VALUES`. The same section requires a fixture using this template
(`plan:683-687`), so copying the documented acceptance path fails before it can
record a decision.

**F47 — [doc-drift] VERIFIED — The cache row schema omits the epoch required by the quarantine.**

The declared `pedigree_cache` row shape contains only `key`, `payload`,
`cached_at`, and `schema_version` (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:796-812`).
The r8 fix subsequently requires every write to add `epoch` and every read to
filter on it (`plan:876-884`). Without adding `epoch` to the storage contract
and cache test schema, an implementation following the row shape cannot satisfy
the logout isolation acceptance; an implementation that adds it ad hoc is no
longer following the declared contract.

### Contradiction

**F46 — [doc-drift] VERIFIED — The session-generation binding is specified twice incompatibly.**

The cache policy says the request reads a module-level `pedigreeSessionGen`
(`.claude/plans/2026-09-10-pedigree-genetics-impl.md:850-856`), while the
buildless-script correction says the shared counter must be
`globalThis.__pedigreeSessionGen` and that a module-level `let` is forbidden
(`plan:867-874`). An implementer following the earlier behavior block can wire
the writer to a counter that `api.js` never increments, reopening the F41 race.

**F49 — [doc-drift] VERIFIED — G2 has conflicting stale-acceptance rules.**

Task 2.3's machine rule requires every warning/info item to have
`disposition=accepted AND stale_disposition=false` (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:656-663`).
The rollout matrix, which is the gate used to open read projection, requires
only “warning/info acceptance recorded” (`plan:1999-2006`). A stale accepted
finding can therefore pass the rollout wording while failing the Task 2.3
wording; the two locations do not define one reproducible G2 decision.

**F50 — [doc-drift] VERIFIED — The missing-cutoff value is described with two incompatible representations.**

The cutoff preamble says the report returns `tanımsız — controlled writes
devrede değil` (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:600-602`),
but the JSON contract and state rules require the exact machine value
`"tanimsiz"` (`plan:618-640,656-660`). A consumer that compares the declared
enum cannot treat the prose value as `not_applicable`, so the preflight state
is still not a single implementable contract.

No additional live or runtime findings were asserted: no implementation,
migration, browser, or DB execution exists in the reviewed material.

## 3. VERDICT: FAIL

The documents are **not ready to serve as implementation authority**.

The r8 fixes materially improve cutoff-state modeling, cache lifecycle fencing,
and removal of the broad authenticated acceptance RPC. They do not yet provide
a single executable contract: F45 blocks the owner acceptance path, F46-F47
leave the cache fence internally inconsistent/incomplete, F48 leaves the new
integrity controls without predicates, and F49-F50 reopen divergent G2/cutoff
interpretations. Those fresh findings keep F33/F36/F37/F39/F40/F41/F42/F44
partial. N17 remains an explicit documented v1 residual.

## 4. Confidence and unverified boundaries

Confidence is **high** for the resolution statuses and F45-F50 as static
document/source findings. The target spec, plan, r8 report, r9 envelope, S1-S8
evidence, `BUGS.md`, active goal, tracked migrations, current auth source, and
test loader were read locally. No live DB, provider, browser, migration, or
frontend implementation was exercised; deployed privileges and runtime cache
behavior remain **UNMEASURED**. The verdict is therefore a document-authority
verdict, not a claim about code that has not been written.

## 5. Verification evidence

```text
$ git rev-parse HEAD
2917c6b17ac1a06a2b1cecf892fa898992db55bd

$ git rev-parse main
7b0c4a72a3801a8d5ce0eb3fc936be3fb99629fe

$ git cat-file -e main:.claude/tasks/2026-09-10-pedigree-rev2-review-r9.md
# exit 0

$ git show main:.claude/plans/2026-09-10-pedigree-genetics-impl.md | nl -ba | sed -n '650,681p;850,884p;1999,2006p'
# output contains the cited stale-disposition, owner-SQL, generation, epoch, and G2 lines

$ git show main:.claude/plans/2026-09-10-pedigree-genetics-impl.md | nl -ba | rg 'legacy_anne_graph_dam_celiskisi|dogum_anne_graph_dam_celiskisi|suspiciously_young_parent'
650: ... legacy_anne_graph_dam_celiskisi ...
651: ... dogum_anne_graph_dam_celiskisi ...
652: ... suspiciously_young_parent ...

$ git status --short --untracked-files=all
# empty before this report was created
```

Only this requested report is written on the worker branch. No product,
migration, spec, plan, BUGS, evidence, or prior-review file was changed.
