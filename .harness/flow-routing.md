# Execution Flow Routing

Shared authority remains in `contract.md`; this file only selects an execution
surface.

## Selection rule

Explicit owner selection always wins. When the owner did not choose:

| Situation | Recommendation |
|---|---|
| Small, tightly coupled root/lead work | `inline` |
| Independent read-only analysis | current runtime's built-in agents |
| ZCode Desktop session | `zcode_builtin` |
| Terminal Codex session | `codex_builtin` or `inline` |
| Terminal Claude session | `claude_builtin` or `inline` |
| Ambiguous multi-writer or long-running work | recommend a flow and ask the owner |
| Herdr or universal worker | only when explicitly selected |

Allowed flow metadata:

```text
inline
zcode_builtin
codex_builtin
claude_builtin
herdr
universal_worker
explicitly_named_other
```

Read-only fanout alone does not require a Full goal. Independent write
ownership does.

## Boundaries

- A flow says how work runs, not what policy applies.
- Runtime process state belongs to that runtime, not the harness.
- Governance never accepts a runtime's self-report without checking Git,
  tests, docs, and evidence.
- Do not consult an external runtime's registry, mailbox, or configuration
  unless that runtime is the selected flow.
- A runtime unavailable during acceptance is `INCONCLUSIVE`, not simulated or
  silently marked `PASS`.
