---
id: G-20260903-UNIFIED-HARNESS-PHASE5
status: active
owner: root
parent: G-20260903-UNIFIED-HARNESS-PHASE4
flow: zcode_builtin
created: 2026-09-03
base_sha: 3c4bbb5c94fc6b37f0f266756f7d308a58e40025
launch_sha: 3c4bbb5c94fc6b37f0f266756f7d308a58e40025
branch: idle/unified-agent-harness-phase5
worktree: /home/melik/egesut-wt/unified-agent-harness-phase5
write_manifest:
  - .harness/goals/2026/G-20260903-UNIFIED-HARNESS-PHASE5.md
  - .harness/reports/2026/G-20260903-UNIFIED-HARNESS-PHASE5.md
  - .harness/contract.md
  - .harness/acceptance.md
  - .harness/README.md
  - .harness/bin/harness.py
  - tests/harness/test_git_lifecycle.py
  - tests/harness/test_docs_update.py
  - tests/harness/test_docs_authority.py
docs_authority:
  tracked_paths:
    write:
      - .harness/goals/2026/G-20260903-UNIFIED-HARNESS-PHASE5.md
      - .harness/reports/2026/G-20260903-UNIFIED-HARNESS-PHASE5.md
      - .harness/contract.md
      - .harness/acceptance.md
      - .harness/README.md
      - .harness/bin/harness.py
      - tests/harness/test_git_lifecycle.py
      - tests/harness/test_docs_update.py
      - tests/harness/test_docs_authority.py
    append: []
  local_paths:
    write: []
    append: []
  db: none
  propose_only:
    - .harness/design/**
    - .claude/**
    - .agents/**
pattern_refs:
  - TESTING-01
acceptance:
  - commit-gate verifies a current staged-scope PASS receipt for the commit input and refuses a missing or stale one.
  - commit-gate refuses fabricated or mismatched Docs-Update/Tests trailers when no matching receipt exists; unenriched commit messages stay valid with basic queryability.
  - commit-gate enforces goal write manifests for Full commits and reports the pre-existing pre-commit hook state without modifying hooks or core.hooksPath.
  - push-gate requires a final(publishing=true) acceptance (goal checkpoint or current receipt), prints the exact remote-bound range, and refuses a stale receipt; it never asserts deployment or DB state.
  - Library actor_role defaults no longer silently claim root: an evaluation without an explicit role is an authority finding.
  - An evaluation run without --goal in a worktree an active goal records produces an ACTIVE_GOAL_UNBOUND warning.
  - pre-commit requires goal_report evaluation whenever a goal is bound (closing the recorded SPEC 12.2 narrowing).
  - Fast (no goal) and Full (goal-bound) flows, the PARTIAL-not-PASS distinction, and the migration-commit-not-deployed boundary are locked by red-before tests.
  - Product code, live DB, deploy, legacy agent surfaces, the existing hook, and main user state remain untouched; the implementation stays standard-library only.
stop_conditions:
  - Main or origin/main moves away from the launch SHA before integration review.
  - A required write falls outside the exact manifest above.
  - A gate would need to mutate Git state, install a hook, set core.hooksPath, or perform network access.
  - A receipt or gate would need to become an independent authority over root acceptance.
report: .harness/reports/2026/G-20260903-UNIFIED-HARNESS-PHASE5.md
checkpoint:
  sequence: 2
  kind: pre-commit
  head: 3c4bbb5c94fc6b37f0f266756f7d308a58e40025
  docs_verdict: PASS
---

# Phase 5 Git Lifecycle Gates

## Objective

Connect harness receipt evidence to the commit and push boundaries through
verification-only gates, close the three review findings deferred from
Phase 3, and document the Fast and Full Git flows — without changing the
active hook, adding enforcement hooks, or making receipts an authority over
root acceptance.

## Invariants

- Gates read Git and receipt state; they never mutate it.
- The existing `.git/hooks/pre-commit` stays reachable and unchanged; `core.hooksPath` stays unset.
- An absent trailer is valid; a fabricated one is a governance failure.
- Push, deploy, and live DB remain distinct gates.

## Exclusions

- No hook installation or dispatcher, no commit helper that writes metadata, no network access, no vector memory, no product or DB change.
