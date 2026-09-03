---
id: G-20260903-UNIFIED-HARNESS-PHASE3
status: review
owner: root
parent: G-20260903-UNIFIED-HARNESS-PHASE2
flow: codex_builtin
created: 2026-09-03
base_sha: b42c6358346b35e4afe395ec06360543b5a70244
launch_sha: b42c6358346b35e4afe395ec06360543b5a70244
branch: idle/unified-agent-harness-phase3
worktree: /home/melik/egesut-wt/unified-agent-harness-phase3
write_manifest:
  - .harness/goals/2026/G-20260903-UNIFIED-HARNESS-PHASE3.md
  - .harness/reports/2026/G-20260903-UNIFIED-HARNESS-PHASE3.md
  - .gitignore
  - .harness/README.md
  - .harness/docs-update.md
  - .harness/memory/README.md
  - .harness/bin/harness.py
  - tests/harness/test_docs_update.py
  - tests/harness/test_docs_authority.py
  - tests/harness/test_rendered_views.py
docs_authority:
  tracked_paths:
    write:
      - .harness/goals/2026/G-20260903-UNIFIED-HARNESS-PHASE3.md
      - .harness/reports/2026/G-20260903-UNIFIED-HARNESS-PHASE3.md
      - .gitignore
      - .harness/README.md
      - .harness/docs-update.md
      - .harness/memory/README.md
      - .harness/bin/harness.py
      - tests/harness/test_docs_update.py
      - tests/harness/test_docs_authority.py
      - tests/harness/test_rendered_views.py
    append: []
  local_paths:
    write: []
    append: []
  db: none
  propose_only:
    - .harness/design/**
    - .harness/references/**
    - .claude/**
    - .agents/**
pattern_refs: []
acceptance:
  - Produce stable verdicts for all five documentation checkpoint kinds.
  - Route product and governance diffs to explicit required documentation surfaces.
  - Detect tracked and local documentation writes outside declared lead authority.
  - Reject unobservable DB effects represented as VERIFIED rather than ATTESTED.
  - Bind PASS receipts to the current HEAD and deterministic diff hash.
  - Render BOARD, HANDOFF, GOAL-INDEX, and MEMORY-INDEX only to stdout or ignored cache.
  - Aggregate repeated findings without hiding distinct failures.
  - Preserve product code, live DB, legacy agent surfaces, Git hooks, and main user state.
stop_conditions:
  - Main or origin/main moves away from the launch SHA before integration review.
  - A required write falls outside the exact ten-path manifest.
  - The implementation requires a dependency install, hook change, product edit, or live DB access.
  - A generated view or receipt would need to become tracked authority.
  - A runtime hook would become a hard correctness dependency.
report: .harness/reports/2026/G-20260903-UNIFIED-HARNESS-PHASE3.md
checkpoint:
  sequence: 3
  kind: pre-commit
  head: b42c6358346b35e4afe395ec06360543b5a70244
  docs_verdict: PASS
---

# Phase 3 Docs-Update Engine

## Objective

Implement the smallest deterministic docs-update evaluation and receipt layer
that makes checkpoint coverage explicit without turning hooks, generated views,
or external memory into correctness dependencies.

## Invariants

- Canonical documents remain tracked inputs; aggregate views and receipts are derived.
- Git provides HEAD, diff, and changed-path facts.
- Root acceptance remains stronger than a generated receipt or execution-plane claim.
- Documentation evaluation is mandatory at checkpoints; document editing is not.

## Exclusions

- No product, DB, deploy, hook, legacy-agent cleanup, pattern catalog, or reference migration.
- No third-party YAML, schema, index, or storage dependency.
- No commit, merge, or push until the corresponding acceptance gate is reached.
