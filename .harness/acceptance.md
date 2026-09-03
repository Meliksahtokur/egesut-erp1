# Acceptance Contract

Passing tests or a worker report alone is not delivery. Root acceptance is a
criterion-level judgment from factual state and reproducible evidence.

## Required evidence

Every delivery states:

- exact changed-file scope;
- relevant commands and exit results;
- behavior-changing red-before evidence for new enforcement;
- focused regression and neighboring-path coverage;
- docs-update outcome;
- `PASS`, `PARTIAL`, `FAIL`, or `INCONCLUSIVE` per criterion;
- residual risks and unmeasured live boundaries;
- restoration of temporary mutations and artifacts.

Review `git status --short` together with the diff. Untracked additions do not
appear in `git diff --stat`. In a persistently dirty checkout, scope status to
the manifest instead of demanding global cleanliness.

## Full-goal review

Before accepting a lead or worker branch, root verifies:

1. worktree, branch, base SHA, and launch SHA from Git;
2. every changed tracked, untracked, and declared local path against the
   manifest and docs authority;
3. real diff semantics rather than the worker summary;
4. required patterns or reviewed exceptions;
5. focused tests and red-before evidence;
6. report completeness and docs checkpoint freshness;
7. no undeclared DB, provider, deployment, or destructive effect.

Return `PARTIAL` rather than upgrading missing live proof to `PASS`.

## Git gates

### Commit

Commit requires scoped diff/status review, relevant tests, and `pre-commit`
docs evaluation. It does not authorize merge or push.

### Merge

Root reviews the manifest, diff, tests, documentation authority, and evidence.
Integration strategy is explicit and must preserve unrelated dirty state.

### Push

Push requires separate owner authority, accepted integration, a current final
checkpoint with `publishing=true`, and the exact remote-bound range.

### Deploy and DB

Push is not deploy. A migration commit is not a DB mutation. Live deployment,
DB writes, and destructive actions each require their own explicit gate and
evidence from the owning environment.

## Hook boundary

Hooks may remind or enrich. Acceptance commands own deterministic decisions.
Do not set `core.hooksPath` in the MVP, bypass the existing hook, or fabricate
`Docs-Update: PASS` or `Tests: PASS` metadata without a matching receipt.
