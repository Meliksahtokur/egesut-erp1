# Compact Handoff — EgeSüt Unified Agent Harness

Date: 2026-09-02

Purpose: preserve the accepted architecture and the exact next action across
context compaction. This is a handoff, not an implementation goal.

## Current live state

```text
repository: /home/melik/egesut-erp1
branch: main
HEAD at handoff: d1de3e8
git status entries: 46
tracked user-owned modifications:
  - .claude/domain-rules.md
  - .claude/rpc-reference.md
linked idle worktrees: 4
```

Re-measure all values after compaction. Preserve every pre-existing dirty and
untracked path. The harness design directory is currently untracked.

## Authoritative design package

- `SPEC.md` — revised architecture contract.
- `IMPLEMENTATION-PLAN.md` — revised phased plan.
- `CLAUDE-OPUS-REVIEW-PROMPT.md` — historical v3 review prompt; do not edit.
- `REVIEW-OF-REVIEW-PROMPT-2026-09-02.md` — immutable meta-review evidence.
- `REVIEW-opus5-terminal-2026-09-02.md` — immutable independent architecture
  review; verdict `ACCEPT_WITH_CHANGES`.

## Accepted architecture

1. `.harness/` is repository-local governance; Git is factual worktree/diff
   truth; the selected runtime is the execution plane; EgeSüt code/tests/live
   schema are product/domain truth.
2. No execution runtime or orchestrator is mandatory.
3. ZCode Desktop defaults to built-in agents; Herdr is explicit terminal flow.
4. Root/lead Fast work does not need a pre-authored goal.
5. Independent non-root write ownership, parallel writes, cross-session work,
   DB/live scope, experiments/rollback risk, or owner choice require Full mode.
6. Write workers require goal, worktree, manifest, acceptance, docs authority,
   and report. Worker PASS is not root acceptance.
7. Leads write only within declared tracked/local/DB authority.
8. Docs-update is mandatory at defined checkpoints, but individual documents
   may legitimately be `NO_CHANGE_REQUIRED`.
9. The five checkpoints are `pre-commit`, `pre-review`, `handoff`,
   `post-merge`, and `final(publishing=false|true)`.
10. BOARD/HANDOFF/GOAL-INDEX/MEMORY-INDEX are rendered on demand into ignored
    cache or stdout; they are not tracked.
11. No live-schema mirror is tracked. Curated RPC/domain contracts remain
    subordinate to live schema for DB facts.
12. Hooks remain warning/context mechanisms. `core.hooksPath` is not changed in
    the MVP; the existing `.git/hooks/pre-commit` must remain reachable.
13. Commit, merge, push, deploy, destructive action, and live DB are separate
    authority gates.

## Independent review findings resolved in the design

- F1: `AGENTS.md` and `CLAUDE.md` must be secret-scanned, unignored, tracked,
  and proven present in a scratch linked worktree before discovery acceptance.
- F2: the proposed hooksPath bootstrap was removed from the MVP; existing hook
  behavior is preserved.
- F3: whole-repo generated views moved from tracked tree to ignored cache.
- F4: tracked schema mirror and ineffective migration-tree freshness claim
  removed.
- F5: docs authority expanded from staged paths to tracked paths, scoped local
  paths, and explicit DB authority with `ATTESTED` for unobservable effects.
- Fast/Full threshold recalibrated so worktree creation alone is not Full.
- Verifier is an independent mode rather than a mandatory persistent identity.

## Next action after compaction

Do not begin product implementation immediately. Start Phase 0/1 governance
work through one owner-approved Full goal because instruction discovery and
tracked policy are being changed while main is dirty.

Suggested goal identity:

```text
goal: G-20260902-UNIFIED-HARNESS-PHASE01
branch: idle/unified-agent-harness
worktree: /home/melik/egesut-wt/unified-agent-harness
flow: ask owner if not explicitly selected
```

Initial objective:

1. Inventory and classify current agent/runtime/docs surfaces without changing
   them.
2. Secret-scan `AGENTS.md`, `CLAUDE.md`, and proposed tracked harness files.
3. Produce the exact Phase 1 write manifest and contradiction decisions.
4. Refresh GitNexus only inside the approved local/index scope.
5. Stop for owner review before unignoring, tracking, moving, deleting, or
   replacing any current instruction surface.

## Phase 0 write boundary

The first goal initially writes only:

```text
.harness/goals/2026/G-20260902-UNIFIED-HARNESS-PHASE01.md
.harness/reports/2026/G-20260902-UNIFIED-HARNESS-PHASE01.md
```

Any additional report/inventory path must be named in the goal before writing.
Phase 1 product/harness paths are proposed by Phase 0 and separately approved.

## Still-open owner decisions

- exact root direct-main merge strategy for later phases;
- whether a lead may ever append canonical memory directly;
- whether valid Fast docs/test receipts should be persisted as commit trailers
  before optional post-pilot enrichment exists;
- exact ZCode tracked adapter shape after current local settings are classified;
- whether optional future hook enrichment is worth a dispatcher and rollback
  proof.

None blocks Phase 0 inventory. Any choice that materially changes Phase 1 must
be resolved before Phase 1 writes.

## Prohibited shortcuts

- Do not bulk-add `.claude`, `.agents`, `.zcode`, `.qwen`, or root instruction
  files.
- Do not delete legacy surfaces before pilots prove the replacement.
- Do not set `core.hooksPath`.
- Do not treat current skills or tracked schema copies as live DB truth.
- Do not infer active runtime use from documentation.
- Do not require goals for ordinary root/lead Fast work.
- Do not merge, push, deploy, mutate DB, or clean worktrees without their
  separate gates.
