# EgeSüt Unified Agent Harness — Implementation Plan

Status: `ACTIVE — phases 1-5 complete and integrated; pilots, phase 6 legacy retirement, and the rollout decision remain`

This plan implements `SPEC.md` incrementally. It intentionally separates
mechanical infrastructure from policy adjudication and legacy cleanup.

## 1. Delivery strategy

Implementation should use one dedicated Full goal and an isolated worktree
because it changes instruction discovery, documentation authority, Git flow,
and several runtime surfaces. The current main worktree contains unrelated
dirty and untracked `.claude` state; it must be preserved.

Suggested identity, subject to owner approval:

```text
goal: G-YYYYMMDD-UNIFIED-HARNESS
branch: idle/unified-agent-harness
worktree: /home/melik/egesut-wt/unified-agent-harness
```

Workers, if used, receive disjoint manifests. Root owns integration. No phase
includes push, deploy, DB mutation, or destructive cleanup by default.

### 1.1 Measured baseline

Measured at HEAD `e8cd620` on 2026-09-02. Re-verify before relying on any row;
a mismatch is a finding, not noise.

| Fact | Command | Value | Consequence for this plan |
|---|---|---|---|
| `.harness/` is untracked | `git ls-files .harness \| wc -l` | 0 | A tracked harness is the target state, not the current one; `.gitignore` and tracking decisions are real Phase 1 work |
| `.claude/` is partly tracked | `git ls-files .claude \| wc -l` | 23 | It is not purely user-local state; Phase 0 classification must separate tracked policy from local runtime state |
| `.agents/`, `.qwen/`, `.zcode/` are untracked | `git ls-files .agents .qwen .zcode \| wc -l` | 0 | Phase 6 retirement is mostly a non-Git operation, with correspondingly low Git risk and no history to preserve |
| Root instruction volume | `wc -l AGENTS.md CLAUDE.md` | 577 / 422 | "Reduce `AGENTS.md` to a short map" means splitting roughly 1000 lines of live policy — the largest single item in Phase 1 |
| No harness test tree | `test -d tests/harness` | false | `tests/harness/` is new; the acceptance suite in 12 does not run until Phase 2 |
| Working tree is dirty | `git status --porcelain \| wc -l` | ~46 | Every phase must preserve this state; only the phase's own manifest may change it |

Effort estimates that ignore the `AGENTS.md`/`CLAUDE.md` split are wrong.

## 2. Global acceptance principles

Every phase must provide:

- exact changed-file scope;
- deterministic tests;
- a red-before fixture or mutation for new enforcement behavior;
- docs-update verdict;
- `PASS`, `PARTIAL`, `FAIL`, or `INCONCLUSIVE` per criterion;
- an independent review before integration;
- explicit residual and unmeasured boundaries;
- clean restoration of temporary mutations and test artifacts.

No phase may claim runtime discovery, worktree behavior, hook behavior, or
queryability from file presence alone; each needs an actual probe.

### 2.1 Phase dependency rule

No phase may validate an artifact that a later phase defines. Where a dependency
would run backwards, the contract is pinned in `SPEC.md` and the phase validates
against the specification rather than against a future implementation.

Known instance: the docs verdict enum (`UPDATED | NO_CHANGE_REQUIRED | PROPOSED |
OUT_OF_SCOPE` and `PASS | PARTIAL | FAIL`) is normative in `SPEC.md` 12.1, so
Phase 2's goal schema validates `checkpoint.docs_verdict` without waiting for the
Phase 3 engine. Phase 3 implements behavior for an enum it does not own.

Each phase lists, in its exit criteria, any artifact it validates that it does
not create.

## 3. Phase 0 — Inventory, freeze, and risk classification

### Objective

Establish a safe migration baseline without changing active behavior.

### Read scope

- root `AGENTS.md`, `CLAUDE.md`, `.gitignore`, Git hooks/config;
- `.claude/`, `.agents/`, `.zcode/`, `.qwen/`, `.openclaude/`, memory surfaces;
- current goals, reports, plans, architecture documents, and runtime scripts;
- current GitNexus status and current tracked/untracked/ignored classifications.

### Outputs

- an inventory mapping each surface to:
  `canonical-candidate | runtime-adapter | generated | historical |
  local-state | credential-risk | deprecated-candidate`;
- contradiction matrix for schema facts, Git policy, goal/worktree policy,
  docs authority, orchestration, and runtime paths;
- secret-safe path inventory and removal/rotation recommendations;
- migration manifest; no bulk `git add`;
- refreshed GitNexus index and freshness evidence.

### Write manifest

Phase 0 writes only its goal-owned inventory/report paths declared before the
run. It does not edit current runtime, policy, product, or Git-hook files.

### Acceptance

- existing dirty files remain byte-identical;
- no credential values are copied into reports;
- no files are deleted or moved;
- current runtime behavior is measured, not inferred;
- current Git status is captured before and after and differs only within the
  approved report manifest.

## 4. Phase 1 — Canonical skeleton and runtime discovery

### Objective

Create the minimal tracked harness and prove native discovery.

### Proposed write manifest

```text
.gitignore
AGENTS.md
CLAUDE.md
.harness/README.md
.harness/contract.md
.harness/flow-routing.md
.harness/acceptance.md
.harness/task-modes.md
.harness/runtimes/*
tests/harness/test_runtime_contract.py
```

`.gitignore` changes require explicit review because existing ignored files may
contain local state or credentials.

### Work

1. Secret-scan root instruction files and the new tracked harness surface.
2. Remove only the `.gitignore` rules that hide `AGENTS.md` and `CLAUDE.md`;
   add `.harness/cache/` to ignored local state.
3. Reduce root `AGENTS.md` to a concise shared map and track it.
4. Make tracked `CLAUDE.md` import `@AGENTS.md` plus Claude-only guidance.
5. Make the ZCode entrypoint read `.harness/contract.md` rather than embedding
   a separate policy summary; keep credentials/local permissions ignored.
6. Define ZCode Desktop built-in routing and terminal Codex/Claude routing.
7. Make Herdr and full orchestration explicit-only.
8. Add contract markers and checks preventing policy duplication in adapters.
9. Probe Codex, Claude Code, OMP, and ZCode discovery from repo root and a
   linked worktree.

### Red-before

Tests must fail when:

- `CLAUDE.md` stops importing `AGENTS.md`;
- an adapter duplicates a shared policy marker;
- a worktree lacks the expected tracked harness;
- either root instruction file remains ignored or absent in a scratch worktree;
- ZCode routing claims Herdr as its default;
- `orchestrator-master` is selected without explicit flow metadata.

### Exit criteria

All four supported runtimes demonstrate the same contract version from root
and a scratch linked worktree. `git check-ignore AGENTS.md CLAUDE.md` finds
nothing. Unsupported/unmeasured runtime behavior is labeled explicitly.

## 5. Phase 2 — Goal, report, worktree, and query substrate

### Objective

Implement lightweight Fast/Full task governance and queryable history.

### Proposed write manifest

```text
.harness/goals/
.harness/reports/
.harness/decisions/
.harness/schemas/goal.schema.json
.harness/schemas/report.schema.json
.harness/schemas/decision.schema.json
.harness/bin/harness.py
tests/harness/test_goals.py
tests/harness/test_index.py
tests/harness/test_decisions.py
tests/harness/test_worktree_contract.py
```

### Work

1. Implement goal/report/decision parsing and schema validation, including
   `checkpoint.docs_verdict` against the enum pinned in `SPEC.md` 12.1.
2. Enforce status transitions and worker inability to self-declare `DONE`.
3. Record base/launch SHA, branch, worktree, owner, manifests, acceptance,
   docs authority, patterns, and report link.
4. Build a deterministic ignored `.harness/cache/` from tracked records and
   Git history; no rendered index is tracked.
5. Implement `goals`, `show`, `search`, `history`, `worktrees`, `stale`, and
   `lineage` commands.
6. Index ad-hoc root/lead commits without requiring a goal.

### Red-before

Fixtures must prove rejection of duplicate IDs, illegal status transitions,
missing report links, manifestless write worktrees, mismatched base/launch SHA,
and a lead editing another goal.

### Exit criteria

A Fast inline commit and a Full worktree goal are both queryable; only the Full
path requires a pre-authored goal. `worktrees` reports existence from
`git worktree list` and ownership from harness records, and flags a recorded
worktree that Git does not show as a discrepancy.

Validated but not created by this phase: the docs verdict enum (`SPEC.md` 12.1).

## 6. Phase 3 — Docs-update engine and generated views

### Objective

Make checkpoint documentation complete, scoped, and difficult to forget
without making runtime hooks hard blockers.

### Proposed write manifest

```text
.harness/docs-update.md
.harness/memory/
.harness/bin/harness.py
tests/harness/test_docs_update.py
tests/harness/test_docs_authority.py
tests/harness/test_rendered_views.py
```

### Work

1. Implement the five checkpoint kinds and per-document outcomes for the enum already
   pinned in `SPEC.md` 12.1; do not redefine it here.
2. Classify diffs into required documentation surfaces.
3. Validate lead `tracked_paths`, `local_paths`, `db`, and `propose_only`
   authority from actual scoped Git/local/DB evidence.
4. Render BOARD, HANDOFF, GOAL-INDEX, and MEMORY-INDEX on demand into ignored
   cache or stdout from canonical records.
5. Store only the latest checkpoint in goal metadata; recover history from Git.
6. Produce a concise receipt for commit/review/merge/push checks.
7. Keep runtime hooks warning-only; acceptance commands consume receipts.

### Red-before

Fixtures must prove detection of:

- UI changes with stale UI map or missing evaluation;
- RPC changes with no RPC/schema/domain evaluation;
- lead documentation edits outside goal authority;
- an ignored/local policy edit outside `local_paths`, and an unobservable DB
  effect reported as `VERIFIED` rather than `ATTESTED`;
- rendered BOARD/HANDOFF output that disagrees with canonical records;
- a final goal with no report;
- a fake `docs-update: PASS` without a current diff/head receipt;
- noisy repeated findings that should be aggregated.

### Exit criteria

Pre-commit, pre-review, handoff, post-merge, and final checkpoint fixtures
produce stable verdicts. `final(publishing=true)` covers remote-bound
validation. `NO_CHANGE_REQUIRED` is a first-class successful outcome.

## 7. Phase 4 — Pattern catalog, references, and product tests

### Objective

Make existing EgeSüt UI/RPC/offline patterns discoverable and test-backed.

### Proposed write areas

```text
.harness/patterns/*
.harness/references/*
tests/harness/*
tests/unit/*                    # only targeted additions
tests/*.spec.js                 # only targeted additions
```

### Work

1. Derive patterns from real current production symbols, not historical agent
   examples.
2. Build and validate a source-symbol UI map.
3. Audit curated RPC/domain contracts against the approved live-schema
   procedure; do not trust the stale architecture skill and do not track a
   live-schema mirror. Optional schema navigation output belongs in cache.
4. Add contextual modal/router tests, form/RPC tests, offline replay tests,
   adapter/discovery tests, and pattern-source consistency checks.
5. Require pattern references or reviewed exceptions in Full goals.

### Acceptance

- no blanket ban misclassifies legitimate non-router `.onclick` usage;
- modal/router invariants cover all relevant routed modals;
- references prefer symbols over fragile line ranges;
- source-symbol reference drift is detectable;
- product tests remain product-owned rather than harness-only assertions.

## 8. Phase 5 — Git commit, merge, push, and gate integration

### Objective

Connect harness evidence to Git lifecycle without changing the active Git hook
directory. Commit enrichment is optional and deferred beyond the MVP.

### Proposed write manifest

```text
.harness/contract.md
.harness/acceptance.md
.harness/bin/harness.py
tests/harness/test_git_lifecycle.py
```

### Work

1. Implement or document root inline commit flow.
2. Implement lead worktree pre-review and local-commit flow.
3. Preserve the existing `.git/hooks/pre-commit`; do not set `core.hooksPath`.
   A commit helper may add receipt-backed metadata, but basic queryability must
   not depend on it.
4. Reject fabricated `Docs-Update` or `Tests` metadata when no receipt with a
   matching HEAD and diff hash exists.
5. Implement root pre-merge inspection and post-merge docs reconciliation.
6. Implement final publishing checks for scoped status, accepted HEAD, receipt,
   tests, and remote-bound range.
7. Keep push, deploy, and live DB as distinct gates.

### Required scenarios

- an unenriched commit produces basic subject/path/author/date queryability,
  and the harness reports absent rich metadata rather than failing;
- a red-before fixture proving the commit helper/check refuses
  `Docs-Update: PASS` when no matching receipt exists;
- the pre-existing `.git/hooks/pre-commit` remains reachable and unchanged;
- Fast root direct-main commit with no goal;
- Full lead worktree commit and root `--no-commit` reconciliation;
- rejected lead diff due to manifest/docs-authority violation;
- `PARTIAL` acceptance preserved without being mislabeled `PASS`;
- push refused by harness check when final docs receipt is stale;
- migration commit that is explicitly not considered deployed.

### Exit criteria

Fast and Full commit flows preserve the active pre-commit hook, reject stale or
fabricated receipts, distinguish push from deploy/DB actions, and work against
manifest-scoped status even when main contains unrelated dirt.

## 9. Phase 6 — Legacy migration and retirement

### Objective

Remove ambiguity only after the replacement is proven.

### Work

1. Classify and migrate useful current `.claude`/`.agents` content.
2. Update or retire the stale architecture skill.
3. Retire `memory-update` and optional vector-memory dependencies if confirmed
   unused.
4. Remove `.qwen` and `.agents/qwen` only after reference and capability scans.
5. Replace hard-coded `/root/egesut-erp1` paths with repo-root discovery where
   the active implementation still needs those scripts.
6. Mark retained legacy surfaces with authority, owner, and removal condition.
7. Secret-scan every candidate before tracking it.

### Write manifest

Phase 6 receives a separate owner-approved cleanup manifest after the pilots.
No deletion target is authorized by this plan alone.

### Exit criteria

Every retired surface has an accepted replacement and rollback record; every
retained surface has an owner and authority label; no secret-bearing file is
tracked.

### Safety

- no bulk deletion;
- no bulk `git add`;
- no credential validity probe unless separately authorized;
- preserve archives until replacement acceptance and owner review;
- cleanup is its own reviewed manifest.

## 10. Phase 7 — Pilot and rollout

Run three bounded pilots:

1. Fast root/lead inline UI or docs maintenance with no goal.
2. Full UI/modal worktree goal using built-in agents and pattern reuse.
3. Full DB/RPC goal exercising schema evidence, docs authority, commit/merge,
   and explicit no-deploy boundary.

Optional fourth pilot: terminal Herdr/universal-worker flow, only if explicitly
selected by the owner.

Pilot 2 must additionally verify with a real commit that the pre-existing Git
hook behavior remains unchanged and that harness correctness does not depend on
optional commit enrichment.

The selected execution plane for each pilot is recorded as goal metadata. No
pilot assumes any particular external runtime is available.

For each pilot measure:

- operator prompts required;
- harness/documentation time versus product time;
- missed/stale docs findings;
- manifest and authority violations;
- worktree lifecycle correctness;
- query/index usefulness;
- false-positive warning/check rate;
- total new tracked governance volume;
- documentation cost per Full goal: checkpoint evaluations performed, model calls
  and operator prompts consumed, and the specific failure each checkpoint kind
  prevented. A checkpoint kind that prevented nothing across all pilots is a
  deletion candidate.

Roll out only if the pilots show lower coordination cost without weakening
scope, evidence, or safety.

### Write manifest

Each pilot writes only its approved goal/report/product manifest. Pilot summary
metrics are written to one root-owned report; no generated aggregate view is
tracked.

### Exit criteria

All three required pilots have criterion-level verdicts, measured operator/docs
cost, worktree cleanup evidence, and an explicit rollout/revise/reject decision.

## 11. Integration sequence

Recommended merge order:

```text
Phase 0 report
  -> Phase 1 contract/discovery
  -> Phase 2 goals/index
  -> Phase 3 docs-update
  -> Phase 4 patterns/references/tests
  -> Phase 5 Git gates
  -> pilots
  -> Phase 6 legacy retirement
  -> final rollout decision
```

Legacy deletion intentionally follows successful pilots rather than preceding
them.

## 12. Final acceptance commands

None of these commands exist at the baseline in 1.1; each becomes runnable in the
phase that creates it. Do not treat this block as a currently executable suite.
The intended final suite is:

```bash
python3 .harness/bin/harness.py validate
python3 -m unittest discover -s tests/harness -p 'test_*.py'
npm run test:unit
npx playwright test tests/modal-router.spec.js
git diff --check
git status --short -- .harness AGENTS.md CLAUDE.md .gitignore tests/harness
```

Additional DB/live/browser checks are goal-specific and must not be inferred
from this offline harness suite. Every phase also runs status against its exact
manifest; a globally dirty main tree is not itself a harness failure.

## 13. Rollback

Each phase must be independently revertible. Runtime adapters continue to read
the last accepted contract until a replacement phase passes. If a phase fails:

- do not weaken the checker to force green;
- retain the prior active instruction path;
- preserve the pre-existing Git hook configuration; optional future enrichment
  has its own rollback proof and is outside the MVP;
- mark the phase `PARTIAL` or `REJECTED`;
- preserve evidence and restore temporary mutations;
- do not proceed to legacy cleanup.

## 14. Owner decisions required after review

Items already settled in `SPEC.md` 19.1 are not reopened here. A reviewer
returns them as `DECISION_NEEDED` only when they conflict with each other or
prove unimplementable.

1. `.harness/` is the tracked namespace; root instruction files are tracked
   after a secret scan.
2. Full mode is triggered by independent non-root write ownership, parallel
   writes, cross-session/handoff, DB/live scope, experiments/rollback risk, or
   explicit owner choice—not worktree creation alone.
3. Select root direct-main commit policy and merge strategy.
4. Decide whether leads can ever append canonical memory directly.
5. Runtime adapters are tracked and thin; existing Git hooks remain untouched
   in the MVP. Future enrichment is a separate decision.
6. Approve the first implementation goal, worktree, and write manifest.
7. Gate any commit, merge, push, live schema probe, DB mutation, or deletion
   separately as required.
