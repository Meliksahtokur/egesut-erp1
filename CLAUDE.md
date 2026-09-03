@AGENTS.md

# Claude Code Runtime Entry Point

Shared governance is imported from `AGENTS.md` and
`.harness/contract.md`. Do not copy shared policy into this file.

For Claude-specific execution guidance, read
`.harness/runtimes/claude.md`.

Use inline work or Claude built-in agents by default. Recommend a flow and ask
the owner when ambiguous multi-worker or long-running work has no selection.
Herdr and external worker systems are explicit-only flows.

Task completion does not authorize automatic commit, merge, push, deploy, or
database mutation. The active goal and owner gates control those actions.
