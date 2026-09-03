---
id: G-20260903-UNIFIED-HARNESS-PHASE4
status: active
owner: root
parent: G-20260903-UNIFIED-HARNESS-PHASE3
flow: zcode_builtin
created: 2026-09-03
base_sha: 9f34fe1c45bed6eb1f7712247839321ed7db910d
launch_sha: 9f34fe1c45bed6eb1f7712247839321ed7db910d
branch: idle/unified-agent-harness-phase4
worktree: /home/melik/egesut-wt/unified-agent-harness-phase4
write_manifest:
  - .harness/goals/2026/G-20260903-UNIFIED-HARNESS-PHASE4.md
  - .harness/reports/2026/G-20260903-UNIFIED-HARNESS-PHASE4.md
  - .harness/patterns/index.yaml
  - .harness/patterns/modal.md
  - .harness/patterns/forms.md
  - .harness/patterns/rpc.md
  - .harness/patterns/offline-sync.md
  - .harness/patterns/testing.md
  - .harness/references/ui-map.md
  - .harness/references/domain-rules.md
  - .harness/references/rpc-reference.md
  - .harness/contract.md
  - .harness/bin/harness.py
  - .harness/docs-update.md
  - .harness/README.md
  - tests/harness/test_patterns.py
  - tests/harness/test_references.py
  - tests/harness/test_docs_update.py
docs_authority:
  tracked_paths:
    write:
      - .harness/goals/2026/G-20260903-UNIFIED-HARNESS-PHASE4.md
      - .harness/reports/2026/G-20260903-UNIFIED-HARNESS-PHASE4.md
      - .harness/patterns/index.yaml
      - .harness/patterns/modal.md
      - .harness/patterns/forms.md
      - .harness/patterns/rpc.md
      - .harness/patterns/offline-sync.md
      - .harness/patterns/testing.md
      - .harness/references/ui-map.md
      - .harness/references/domain-rules.md
      - .harness/references/rpc-reference.md
      - .harness/contract.md
      - .harness/bin/harness.py
      - .harness/docs-update.md
      - .harness/README.md
      - tests/harness/test_patterns.py
      - tests/harness/test_references.py
      - tests/harness/test_docs_update.py
    append: []
  local_paths:
    write: []
    append: []
  db: none
  propose_only:
    - .harness/design/**
    - .claude/**
    - .agents/**
pattern_refs: []
acceptance:
  - Patterns derive from real current production symbols; every exemplar symbol cited in .harness/patterns/** exists in current code and drift is mechanically detectable.
  - The UI map is source-symbol keyed rather than line-number keyed, covers the router surface, and its cited symbols are checkable against js/** and index.html.
  - Curated RPC and domain references state provenance and keep live schema as the declared authority; no live-schema mirror is tracked and no DB claim is marked VERIFIED locally.
  - Product routing gaps close with red-before coverage: js/state.js and js/config.js require ui_map evaluation; supabase/functions/** requires domain_rules and deploy_boundary evaluation.
  - Full goals whose write manifest touches js/, index.html, or supabase/ must declare pattern_refs or pattern_exceptions, validated against .harness/patterns/index.yaml.
  - docs-update.md records the required-surface name to document mapping (Phase 3 review finding 7).
  - The modal pattern documents legitimate dynamic-row onclick usage so no blanket onclick ban misclassifies it, and the cited examples exist in code.
  - Harness implementation remains standard-library only; product code, live DB, hooks, legacy agent surfaces, and main user state remain untouched.
stop_conditions:
  - Main or origin/main moves away from the launch SHA before integration review.
  - A required write falls outside the exact manifest above.
  - A pattern or reference would need to cite a symbol that does not exist in current code.
  - The work would require a live DB read or write, a dependency install, a hook change, or a product-code edit.
  - A generated view, receipt, or reference would need to become tracked live-schema authority.
report: .harness/reports/2026/G-20260903-UNIFIED-HARNESS-PHASE4.md
checkpoint:
  sequence: 2
  kind: pre-commit
  head: 9f34fe1c45bed6eb1f7712247839321ed7db910d
  docs_verdict: PASS
---

# Phase 4 Patterns, References, and Product Routing

## Objective

Make the existing EgeSut UI, form/RPC, and offline-sync patterns discoverable
and mechanically checkable, and close the product-routing and surface-naming
gaps deferred from the Phase 3 review.

## Invariants

- Patterns and references cite current production symbols, not historical agent examples.
- Live schema remains the only DB authority; curated references are contracts, never mirrors.
- New enforcement ships with red-before coverage in the harness suite.
- Product code and product tests change only within their own authority; this goal writes governance surfaces only.

## Exclusions

- No product-code edit, live DB access, deploy, hook change, or legacy cleanup.
- No third-party dependency, schema file beyond the stdlib-parsable pattern index, or tracked aggregate view.
