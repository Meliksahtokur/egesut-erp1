---
id: G-20260903-PILOT2-MODAL-ACTIONS
status: active
owner: root
parent: G-20260903-UNIFIED-HARNESS-PHASE5
flow: zcode_builtin
created: 2026-09-03
base_sha: eaa1afa2fcdd106ec271d1de427d0e10580aa372
launch_sha: eaa1afa2fcdd106ec271d1de427d0e10580aa372
branch: idle/pilot2-modal-actions
worktree: /home/melik/egesut-wt/pilot2-modal-actions
write_manifest:
  - .harness/goals/2026/G-20260903-PILOT2-MODAL-ACTIONS.md
  - .harness/reports/2026/G-20260903-PILOT2-MODAL-ACTIONS.md
  - js/ui.js
  - js/utils/handlers.js
  - tests/unit/modal-actions.test.js
docs_authority:
  tracked_paths:
    write:
      - .harness/goals/2026/G-20260903-PILOT2-MODAL-ACTIONS.md
      - .harness/reports/2026/G-20260903-PILOT2-MODAL-ACTIONS.md
      - js/ui.js
      - js/utils/handlers.js
      - tests/unit/modal-actions.test.js
    append: []
  local_paths:
    write: []
    append: []
  db: none
  propose_only:
    - .claude/**
    - .harness/references/**
pattern_refs:
  - MODAL-ROUTER-01
acceptance:
  - The three generated empty-state buttons that open router modals through inline onclick openM(...) dispatch registered data-action handlers instead.
  - open-insem-modal and stok-add-open reuse their existing registered actions verbatim; only open-kizginlik-modal is newly registered.
  - A product-owned unit test locks the three registrations and their modal targets red-first.
  - The full product unit suite stays green and no other behavior changes.
  - The pre-existing pre-commit hook file remains byte-identical through the pilot commit.
stop_conditions:
  - Main or origin/main moves away from the launch SHA before integration review.
  - A required write falls outside the exact manifest above.
  - The refactor changes any modal open behavior beyond routing through the equivalent action.
  - Live DB access, deploy, hook change, or a dependency install becomes necessary.
report: .harness/reports/2026/G-20260903-PILOT2-MODAL-ACTIONS.md
checkpoint:
  sequence: 2
  kind: pre-commit
  head: eaa1afa2fcdd106ec271d1de427d0e10580aa372
  docs_verdict: PASS
---

# Pilot 2 — Modal Action Routing (Full goal)

## Objective

The second harness pilot: a small real UI refactor through the full Full-goal
flow, reusing MODAL-ROUTER-01, proving pattern enforcement, gates, and hook
preservation on a product change.

## Invariants

- Behavior-preserving routing change only: inline `onclick="openM('m-X')"`
  becomes the registered `data-action` that opens the same modal.
- Product tests stay product-owned.

## Exclusions

- No new modal, no styling, no live DB, no deploy, no hook change.
