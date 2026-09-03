# EgeSut Unified Agent Harness

Contract version: `1`

This directory is the repository-local governance surface for agent-assisted
work. It does not replace Git as factual state, the selected runtime as the
execution mechanism, or EgeSut code/tests/live schema as product truth.

Read in this order:

1. `contract.md` for shared authority and safety rules;
2. `task-modes.md` to choose Fast or Full mode;
3. `flow-routing.md` to select an execution flow;
4. `acceptance.md` before declaring work complete;
5. the active goal under `goals/YYYY/` when Full mode applies;
6. one runtime adapter under `runtimes/` only when that runtime is selected.

Canonical records are tracked. Generated boards, indexes, schema summaries,
receipts, and runtime state belong in ignored `.harness/cache/` or stdout.

Phase 2 adds standard-library goal/report/decision validation and deterministic
queries. Phase 3 adds checkpoint docs evaluation, authority checks,
HEAD/diff-bound ignored receipts, and memory-index rendering. Phase 4 adds the
pattern catalog under `patterns/`, the curated references under `references/`
(symbol-keyed UI map plus RPC/domain contracts; live schema stays the only DB
authority), product-diff routing for `js/state.js`, `js/config.js`, and
`supabase/functions/**`, and pattern_ref enforcement for product-code goals.
Run `harness.py --help` for commands. Git lifecycle gates shipped in
Phase 5 and the legacy `.claude` reference retirement in Phase 6 (decisions
`D-20260904-*`); the harness is the standing governance surface per the
rollout decision.

## Phase 2 query surface

Invoke commands with `python3 .harness/bin/harness.py`:

```text
validate                  validate canonical records and active worktrees
goals                     list goal metadata
show G-...                show one goal
search QUERY              search goals, reports, and decisions
history                   reconstruct basic commit history from Git
worktrees                 combine Git existence with recorded goal intent
stale                     report active goal/worktree/checkpoint discrepancies
lineage G-...             show parent and direct children
render board              generate the goal board to stdout
render handoff            generate active-goal handoff to stdout
render goal-index         generate deterministic JSON to stdout
render memory-index       generate curated-memory navigation to stdout
docs-update CHECKPOINT    evaluate routed documentation surfaces and authority
receipt-check             reject missing, stale, or dishonest docs receipts
commit-gate               verify staged receipt, goal manifest, hook state, trailers
push-gate                 verify finalized acceptance and the fast-forward publish range
```

Add `--json` to query commands that support structured output. `render ...
--cache` writes only to ignored `.harness/cache/`; cached projections never
become authority. `history` always reports commit subject, paths, author, and
date. Goal, flow, and mode remain `null` when no truthful trailer exists.

See `docs-update.md` for checkpoint outcomes, receipt semantics, and CLI
examples, and `contract.md` for the Fast and Full Git flows behind
`commit-gate`/`push-gate`. Receipts and all four rendered aggregate views
remain ignored derived state; gates verify, they never mutate Git.
