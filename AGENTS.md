# EgeSut ERP — Agent Entry Point

Harness contract version: `1`

This file is the short shared entrypoint for Codex and OMP-compatible agents.
The canonical governance contract is `.harness/contract.md`; do not treat this
map or a runtime adapter as an independent policy source.

## Start here

1. Read `.harness/contract.md`.
2. Select Fast or Full mode with `.harness/task-modes.md`.
3. Follow `.harness/flow-routing.md`; ask the owner when an ambiguous
   multi-worker or long-running flow was not selected.
4. If Full mode applies, read the active goal before writing anything.
5. Read `.harness/acceptance.md` before claiming completion.
6. Load only the applicable runtime adapter under `.harness/runtimes/`.

## Project shape

```text
Frontend: Vanilla JS in js/ and index.html
Backend: Supabase/PostgreSQL through REST and RPC
Tests: Playwright E2E plus Node unit tests
Hosting: GitHub Pages; database deployment is separate
```

Important current source areas:

- `js/api.js`: Supabase API, pull/sync, IndexedDB interaction;
- `js/app.js`: application orchestration;
- `js/ui.js`: rendering and modal behavior;
- `js/forms.js`: form and RPC submission;
- `js/state.js`: application state;
- `js/config.js`: stable configuration lists;
- `supabase/migrations/`: migration history, not live-schema proof;
- `tests/`: product acceptance evidence.

## Task routing

| Task | Read next |
|---|---|
| Any repository change | `.harness/contract.md`, `.harness/acceptance.md` |
| Full goal/worktree task | active `.harness/goals/YYYY/G-*.md` |
| JS symbol or DB/RPC change | `.harness/contract.md` pre-check rules plus the runtime-provided `code-change-precheck` skill when available |
| Domain or state-machine work | `.claude/domain-rules.md` |
| RPC work | `.claude/rpc-reference.md` plus separately authorized live schema |
| UI/modal work | `.claude/ui-map.md` and current production/test example |
| New tenant-scoped DB object | `.harness/contract.md` plus separately verified live schema |
| GitNexus CLI/index work | `.harness/contract.md`; use `--index-only` for non-injecting refresh |

The tracked `.claude` references above are transitional until Phase 4. They are useful
contracts or maps, not live database authority. Do not modify the currently
user-owned dirty copies unless the active manifest explicitly allows it.

## Runtime selection

- ZCode Desktop: built-in agents by default; see `.harness/runtimes/zcode.md`.
- Terminal Codex: inline or built-in agents; see
  `.harness/runtimes/codex.md`.
- Claude Code: `CLAUDE.md` imports this entrypoint; see
  `.harness/runtimes/claude.md`.
- Herdr: explicit terminal choice only; see `.harness/runtimes/herdr.md`.

No orchestration runtime, mailbox, registry, vector DB, or external memory
service is required for harness correctness.

If the contract or active Full goal is missing, contradictory, or unreadable,
stop before writing and report the discovery failure instead of reconstructing
policy from memory.
