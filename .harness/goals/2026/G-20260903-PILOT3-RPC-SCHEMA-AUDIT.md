---
id: G-20260903-PILOT3-RPC-SCHEMA-AUDIT
status: active
owner: root
parent: G-20260903-UNIFIED-HARNESS-PHASE5
flow: zcode_builtin
created: 2026-09-03
base_sha: b24927098e9352f6b8779d55f8b53ee2c52ef718
launch_sha: b24927098e9352f6b8779d55f8b53ee2c52ef718
branch: idle/pilot3-rpc-schema-audit
worktree: /home/melik/egesut-wt/pilot3-rpc-schema-audit
write_manifest:
  - .harness/goals/2026/G-20260903-PILOT3-RPC-SCHEMA-AUDIT.md
  - .harness/reports/2026/G-20260903-PILOT3-RPC-SCHEMA-AUDIT.md
  - .harness/references/rpc-reference.md
docs_authority:
  tracked_paths:
    write:
      - .harness/goals/2026/G-20260903-PILOT3-RPC-SCHEMA-AUDIT.md
      - .harness/reports/2026/G-20260903-PILOT3-RPC-SCHEMA-AUDIT.md
      - .harness/references/rpc-reference.md
    append: []
  local_paths:
    write: []
    append: []
  db: read
  propose_only:
    - .claude/**
pattern_refs: []
acceptance:
  - A read-only live-schema probe of the connected demo project verifies a sample of curated RPC signatures (arguments and result type) against the reference.
  - Every mismatch is classified as a reference error, a demo-parity gap, or an environment boundary — never silently resolved.
  - The audit note in rpc-reference.md records the probe date, environment, method, and result; the local docs engine still receives the DB observation as ATTESTED, never VERIFIED.
  - No DB write, migration, deploy, or product-code change occurs; push is not deploy.
  - The full gate flow runs: pre-review receipt, independent review, staged pre-commit with commit-gate, integration, final(publishing=true), push-gate.
stop_conditions:
  - Main or origin/main moves away from the launch SHA before integration review.
  - A required write falls outside the exact manifest above.
  - The probe would need a DB write, a deploy, or credentials beyond the already-configured read connection.
report: .harness/reports/2026/G-20260903-PILOT3-RPC-SCHEMA-AUDIT.md
checkpoint:
  sequence: 1
  kind: pre-review
  head: b24927098e9352f6b8779d55f8b53ee2c52ef718
  docs_verdict: PASS
---

# Pilot 3 — RPC Reference Live-Schema Audit (Full goal, db: read)

## Objective

The third harness pilot: exercise schema evidence, declared DB read
authority, the ATTESTED boundary, and the explicit no-deploy rule on a
documentation-accuracy task.

## Invariants

- Read-only probe; the engine never records a DB observation as VERIFIED.
- The reference stays a contract document with provenance; the probe result is evidence about its accuracy, dated and environment-scoped.

## Exclusions

- No DB write, no migration deploy, no product change, no credential probing.
