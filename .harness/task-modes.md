# Task Modes

## Fast mode

Use Fast mode when all of the following hold:

- root or lead retains write ownership;
- work is low risk and tightly coupled;
- there is no parallel writer;
- work does not require cross-session handoff;
- DB/live/external mutation is outside scope;
- rollback-sensitive experimentation is outside scope.

Fast mode needs no pre-authored goal. It still requires declared scope,
relevant tests, a `pre-commit` docs evaluation, diff/status review, and honest
unmeasured boundaries. A root-owned solo worktree may remain Fast.

## Full mode

Full mode is mandatory when any condition holds:

- a non-root actor receives independent write ownership;
- parallel write ownership exists;
- the work can outlive the session or needs a handoff;
- DB, migration, live environment, or external mutation is in scope;
- an experiment needs explicit rollback evidence;
- the owner requests a goal.

A Full goal records:

```text
id and lifecycle status
owner and selected flow
base SHA and launch SHA
branch and worktree path
exact write manifest
tracked/local/DB documentation authority
pattern references
acceptance commands
stop conditions
report path
latest checkpoint and docs verdict
```

One goal represents one meaningful delivery unit. Create a child goal only for
independent write ownership, independent acceptance, or genuinely resumable
work. Worktree existence comes from Git; goal records provide ownership,
intent, and history.

Workers cannot mark a goal `DONE`. Root closes it after independent review.
