---
id: G-20260902-UNIFIED-HARNESS-PHASE01
status: review
owner: root
parent: null
flow: codex_builtin
created: 2026-09-02
base_sha: 4448b8d5610b27af38a558c3e99dd7abedd800e1
launch_sha: 4448b8d5610b27af38a558c3e99dd7abedd800e1
branch: idle/unified-agent-harness
worktree: /home/melik/egesut-wt/unified-agent-harness
write_manifest:
  - .harness/goals/2026/G-20260902-UNIFIED-HARNESS-PHASE01.md
  - .harness/reports/2026/G-20260902-UNIFIED-HARNESS-PHASE01.md
  - .gitignore
  - AGENTS.md
  - CLAUDE.md
  - .harness/README.md
  - .harness/contract.md
  - .harness/flow-routing.md
  - .harness/acceptance.md
  - .harness/task-modes.md
  - .harness/runtimes/codex.md
  - .harness/runtimes/claude.md
  - .harness/runtimes/zcode.md
  - .harness/runtimes/herdr.md
  - .zcode/config.json
  - .zcode/hooks/session_contract.py
  - .zcode/hooks/commit_guard.py
  - .zcode/hooks/js_edit_guard.py
  - tests/harness/test_runtime_contract.py
docs_authority:
  tracked_paths:
    write:
      - .harness/goals/2026/G-20260902-UNIFIED-HARNESS-PHASE01.md
      - .harness/reports/2026/G-20260902-UNIFIED-HARNESS-PHASE01.md
      - .gitignore
      - AGENTS.md
      - CLAUDE.md
      - .harness/README.md
      - .harness/contract.md
      - .harness/flow-routing.md
      - .harness/acceptance.md
      - .harness/task-modes.md
      - .harness/runtimes/codex.md
      - .harness/runtimes/claude.md
      - .harness/runtimes/zcode.md
      - .harness/runtimes/herdr.md
      - .zcode/config.json
      - .zcode/hooks/session_contract.py
      - .zcode/hooks/commit_guard.py
      - .zcode/hooks/js_edit_guard.py
      - tests/harness/test_runtime_contract.py
    append: []
  local_paths:
    write:
      - /home/melik/egesut-erp1/.gitnexus/**
      - /home/melik/.gitnexus/registry.json
    append: []
  db: none
  propose_only:
    - .harness/design/**
    - .claude/**
    - .agents/**
    - .qwen/**
pattern_refs: []
acceptance:
  - Verify branch, base SHA, launch SHA, and worktree identity from Git.
  - Verify the worktree contains no writes outside the active write manifest.
  - Verify the protected main-worktree files retain their launch hashes.
  - Verify the report contains no credential values and no secret-like material.
  - Verify every Phase 0/1 criterion has PASS, PARTIAL, FAIL, or INCONCLUSIVE evidence.
stop_conditions:
  - Main HEAD differs from the owner-approved launch SHA before worktree creation.
  - The target branch or worktree path is already owned by another task.
  - A protected user-owned file changes during the run.
  - Required writes extend beyond the active write manifest.
  - A credential value would need to be copied into an artifact.
  - A live database, provider, deploy, destructive, or external mutation is required.
  - GitNexus refresh attempts to inject AGENTS.md, CLAUDE.md, or skill files
    instead of remaining in verified index-only local authority.
report: .harness/reports/2026/G-20260902-UNIFIED-HARNESS-PHASE01.md
checkpoint:
  sequence: 6
  kind: pre-commit
  head: 4448b8d5610b27af38a558c3e99dd7abedd800e1
  docs_verdict: PASS
---

# Phase 0/1 Bootstrap Goal

## Objective

Establish a verified, secret-safe migration baseline for the EgeSut unified
agent harness, then propose the exact Phase 1 canonical skeleton and discovery
manifest without changing active policy, runtime behavior, Git hooks, or
product code.

## Read Manifest

The root agent may read the following surfaces from
`/home/melik/egesut-erp1`:

- `AGENTS.md`, `CLAUDE.md`, and `.gitignore`;
- `.harness/design/2026-09-02-unified-agent-harness/**`;
- `.claude/**`, `.agents/**`, `.zcode/**`, `.qwen/**`, `.openclaude/**`;
- `.commandcode/**` and `.mimosa/**`;
- `.git/hooks/*`, `.git/config`, and `.gitnexus/**`;
- `docs/**`, `.github/workflows/**`, `tests/**`, `scripts/**`, and `package.json`;
- `supabase/migrations/99999999999999_ground_truth.sql`;
- read-only Git metadata and history commands.

Credential values, cookies, tokens, private configuration values, and raw
runtime state must not be copied into the goal or report. Inventory records
paths, classifications, counts, contradictions, and risk labels only.

## Required Outputs

The report must contain:

1. a current factual Git, worktree, hook, and GitNexus baseline;
2. a surface inventory using the approved classification vocabulary;
3. a contradiction matrix for schema, Git lifecycle, goal/worktree policy,
   documentation authority, orchestration, and runtime discovery;
4. a secret-safe tracking and retirement risk inventory;
5. an exact proposed Phase 1 write manifest and unresolved owner decisions;
6. criterion-level evidence and explicit unmeasured boundaries.

## Invariants

- Git is factual worktree and diff truth.
- The selected execution flow is `codex_builtin`; it is not governance truth.
- Worker or subagent PASS is not root acceptance.
- Existing dirty and untracked state is preserved.
- The two protected `.claude` modifications are never edited or restored.
- GitNexus refresh is limited to verified `--index-only` behavior and the
  declared local index/registry authority; file injection is unauthorized.

## Exclusions

- No edits outside the approved Phase 1 manifest. In particular, no writes to
  `.claude`, `.agents`, `.qwen`, product code, migrations, hooks, or live
  systems.
- No file move, deletion, retirement, secret validity probe, commit, merge,
  push, deploy, database write, or destructive operation.
- No write outside the owner-approved Phase 1 expansion; Phase 2, legacy
  retirement, commit, merge, and push remain separately gated.

## Current Review State

Phase 0 inventory retains its historical `PARTIAL` verdict because the report
was ignored and a safe GitNexus refresh had not yet been proven at that
checkpoint. Phase 1 resolved both issues with narrow ignore exceptions and
verified `--index-only` refresh. The owner approved the Phase 1 expansion on 2026-09-02,
including the four-file ZCode adapter and disposable GitNexus probe, while
rejecting an unnecessary OMP adapter. Commit, merge, and push remain
unauthorized. Phase 1 implementation reached `review` after the sequence-4
pre-review docs checkpoint and focused acceptance suite. Sequence 5 records
the context-compaction handoff; the next action is the separately gated
worktree commit, not merge or push.
