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

The current implementation is Phase 1. Goal/report schemas, the query CLI,
docs-update automation, pattern catalogs, and legacy retirement arrive only in
their later reviewed phases. Their absence must not be papered over with
runtime-specific policy copies.
