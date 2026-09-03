---
id: G-20260903-UNIFIED-HARNESS-PHASE2
status: review
owner: root
parent: G-20260902-UNIFIED-HARNESS-PHASE01
flow: codex_builtin
created: 2026-09-03
base_sha: fd38192ebc7bfffc7dd38e41da1ee2f441d66fdc
launch_sha: fd38192ebc7bfffc7dd38e41da1ee2f441d66fdc
branch: idle/unified-agent-harness-phase2
worktree: /home/melik/egesut-wt/unified-agent-harness-phase2
write_manifest:
  - .harness/goals/2026/G-20260903-UNIFIED-HARNESS-PHASE2.md
  - .harness/reports/2026/G-20260903-UNIFIED-HARNESS-PHASE2.md
  - .harness/README.md
  - .harness/decisions/README.md
  - .harness/schemas/goal.schema.json
  - .harness/schemas/report.schema.json
  - .harness/schemas/decision.schema.json
  - .harness/bin/harness.py
  - tests/harness/test_goals.py
  - tests/harness/test_index.py
  - tests/harness/test_decisions.py
  - tests/harness/test_worktree_contract.py
docs_authority:
  tracked_paths:
    write:
      - .harness/goals/2026/G-20260903-UNIFIED-HARNESS-PHASE2.md
      - .harness/reports/2026/G-20260903-UNIFIED-HARNESS-PHASE2.md
      - .harness/README.md
      - .harness/decisions/README.md
      - .harness/schemas/goal.schema.json
      - .harness/schemas/report.schema.json
      - .harness/schemas/decision.schema.json
      - .harness/bin/harness.py
      - tests/harness/test_goals.py
      - tests/harness/test_index.py
      - tests/harness/test_decisions.py
      - tests/harness/test_worktree_contract.py
    append: []
  local_paths:
    write: []
    append: []
  db: none
  propose_only:
    - .claude/**
    - .agents/**
    - .qwen/**
pattern_refs: []
acceptance:
  - Validate all tracked goal records and reject malformed or duplicate identities.
  - Query goals, lineage, history, and search deterministically without a vector database.
  - Report worktree existence from Git and ownership intent from goal records.
  - Render derived query state only to stdout or ignored cache.
  - Prove Fast Git history remains queryable without a goal or metadata trailer.
  - Preserve main user state, Git hooks, product code, and legacy agent surfaces.
stop_conditions:
  - Main HEAD moves away from the launch SHA before implementation acceptance.
  - A required write falls outside the exact 12-path manifest.
  - The implementation requires a package install, Git hook change, live DB access, or product edit.
  - A generated view would need to become tracked authority.
  - Existing Phase 1 goals or reports would require destructive migration.
report: .harness/reports/2026/G-20260903-UNIFIED-HARNESS-PHASE2.md
checkpoint:
  sequence: 2
  kind: pre-commit
  head: fd38192ebc7bfffc7dd38e41da1ee2f441d66fdc
  docs_verdict: PASS
---

# Phase 2 Goal and Query Substrate

## Objective

Implement the smallest standard-library governance substrate that validates
goal, report, and decision records; reconstructs queryable history from tracked
records and Git; and reports worktree fact separately from recorded intent.

## Invariants

- Git remains the authority for commits, changed paths, branches, and live
  worktree existence.
- Goal records provide ownership, intent, manifests, and lineage only.
- Generated indexes and aggregate views stay in ignored cache or stdout.
- Fast work remains queryable from Git without requiring a goal or trailer.
- Validation never silently repairs repository or governance state.

## Exclusions

- No docs-update engine, receipt enforcement, hook integration, pattern
  catalog, legacy migration, memory subsystem, product code, DB, deploy,
  merge, push, or destructive cleanup.
- No dependency installation. The CLI uses the Python standard library.
- No rewrite of the completed Phase 1 goal or report.
