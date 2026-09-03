# Herdr Runtime Adapter

Shared policy: `../contract.md`

Herdr is an explicitly selected terminal execution surface. It is not a
default flow, governance authority, semantic controller, or acceptance source.

When selected, record `flow: herdr` in the goal or task metadata and keep every
writer inside its assigned worktree and manifest. Runtime process state stays
in Herdr; durable goal and acceptance state stays in the harness.

If Herdr is unavailable or not probed, report it as `INCONCLUSIVE` rather than
claiming runtime acceptance.
