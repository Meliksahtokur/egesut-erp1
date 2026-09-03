# EgeSut Shared Agent Contract

Contract version: `1`

This is the single shared governance contract for repository work. Runtime
adapters may explain invocation and capability limits, but may not redefine
these rules.

## Authority order

1. system/developer instructions and explicit owner direction;
2. the active goal or task envelope;
3. this contract;
4. applicable domain, pattern, and source references;
5. the selected runtime adapter;
6. historical reports, memory, generated blocks, and archived documents.

When two sources disagree, do not silently choose one. Follow the higher
authority, record the contradiction, and request an owner decision when the
choice would materially change scope or behavior.

## Ground truth by question

| Question | Authority |
|---|---|
| Does a worktree exist? | `git worktree list` |
| Which files changed? | real `git status` and `git diff` |
| Who owns a Full goal and its manifest? | the goal record |
| Is a worker running? | the selected runtime's own surface |
| Was work accepted? | root verification of diff, tests, docs, and evidence |
| What is the database structure? | a separately authorized live-schema probe |
| Is a change deployed? | the live environment or deploy tool's own evidence |

Documentation about a runtime is not proof that the runtime is active. A
worker report is evidence, not acceptance.

## Repository safety

- Preserve pre-existing dirty, untracked, ignored, and user-owned state.
- Write only inside the active manifest. Never use bulk `git add` in a dirty
  repository.
- Do not move, delete, restore, or overwrite unrelated files.
- `main` is the integration branch. Isolated task branches use the approved
  `idle/*` convention.
- Commit, merge, push, deploy, destructive action, and live DB access are
  separate authority gates. Permission for one never implies another.
- Hooks provide warnings or context unless a reviewed deterministic acceptance
  check explicitly owns enforcement.
- Keep the existing `.git/hooks/pre-commit` reachable. Do not set
  `core.hooksPath` in the MVP.
- Refresh GitNexus with `--index-only` unless an active manifest explicitly
  authorizes generated instruction and skill files. Default analyze is not a
  policy-maintenance mechanism.
- A disposable GitNexus probe uses a unique `--name`; it must not register or
  clean through the shared project alias.

## Roles

- **Owner:** selects or overrides flow and grants external or destructive
  authority.
- **Root:** integrates, independently verifies, reconciles docs, and owns final
  acceptance.
- **Lead:** works only inside the goal's product and documentation authority.
- **Worker:** requires an exact write manifest, worktree, acceptance commands,
  stop conditions, and report for write work.
- **Verifier mode:** reviews evidence and does not repair the product while
  producing the verdict.

Workers and leads cannot silently expand scope. Worker `PASS` never sets a goal
to `DONE`.

## Execution flow

The owner may select any available flow. If none is selected, use
`flow-routing.md`. No orchestrator, external worker system, Herdr session, or
vector-memory service is required for correctness.

ZCode Desktop defaults to its built-in agents. Terminal Codex or Claude work
defaults to inline or built-in delegation. Herdr and universal-worker flows are
explicit choices only.

## Fast and Full work

Fast mode is allowed for root/lead work that is low-risk, tightly coupled, and
does not assign independent write ownership. It needs no pre-authored goal but
still needs scoped tests, docs evaluation, and evidence.

Full mode is mandatory for independent non-root write ownership, parallel
writes, cross-session handoff, DB/live scope, rollback-sensitive experiments,
or explicit owner choice. See `task-modes.md`.

## EgeSut product invariants

- The frontend collects input and renders data; business rules, validation,
  calculations, and state machines belong in PostgreSQL/RPC.
- Frontend writes use established RPC/API helpers. Do not construct raw SQL
  strings or directly bypass a state-machine RPC.
- Before changing a JS symbol, database object, RPC, view, or migration, run
  the applicable repository pre-check and inspect upstream impact. Warn before
  proceeding on HIGH or CRITICAL impact.
- Live schema is the only authority for DB structure. Tracked migrations,
  skills, snapshots, RPC references, and generated summaries are subordinate
  references and may be stale.
- A migration file in Git is not evidence of deployment.
- Live DB writes require an explicit owner instruction. High-risk
  DROP/RENAME/TRUNCATE operations require a final specific approval.
- New tenant-scoped tables use
  `farm_id uuid NOT NULL DEFAULT '400b9107-a85e-4126-af2c-fd7fe73fb68e'`
  plus an index beginning with `farm_id`. New write RPCs stamp
  `farm_id = public.current_farm_id()`. Existing `USING(true)` RLS remains
  unchanged until the separately approved multi-tenant phase; global catalogs
  do not receive `farm_id`. Verify the target live schema before applying the
  rule.
- Router-managed modal links use the established HTML-attribute plus dataset
  pattern; agents must inspect the current production example before editing.
- Demo credentials and public demo access are intentionally public-by-design
  for the isolated demo project. Do not report that accepted design as a bug.

Transitional product references, pending Phase 4 migration:

- `.claude/domain-rules.md`
- `.claude/rpc-reference.md`
- `.claude/ui-map.md`

The references above do not override live schema or current source code.

## Pattern reuse

Before inventing a modal, form, RPC, offline-sync path, fixture, or test helper:

1. search current production symbols and tests;
2. name the example being reused;
3. preserve its relevant invariants;
4. record and review an exception when reuse is inappropriate.

Line numbers are hints. Prefer stable symbols and behavior-backed tests.

## Documentation checkpoints

Root and lead evaluate documentation at:

- `pre-commit`;
- `pre-review`;
- `handoff`;
- `post-merge`;
- `final(publishing=false|true)`.

Each relevant surface is `UPDATED`, `NO_CHANGE_REQUIRED`, `PROPOSED`, or
`OUT_OF_SCOPE`; the aggregate verdict is `PASS`, `PARTIAL`, or `FAIL`.
Evaluation is mandatory, but editing every document is not. Progress and
ordinary test/fix loops are not checkpoints.

## Documentation authority

Root reconciles documentation within owner-approved scope. A lead may write
only to declared `tracked_paths`, declared `local_paths`, and declared DB
authority. Unobservable external effects are `ATTESTED`, never `VERIFIED`.
Workers do not write canonical memory; they may submit candidates in reports.

## Memory and generated state

Durable memory contains only evidenced knowledge that prevents a future wrong
decision. Do not store progress narration, raw transcripts, temporary state,
or facts already represented by a goal, report, decision, or commit.

No vector DB is required. BOARD, HANDOFF, indexes, receipts, and schema views
are generated into ignored cache or stdout and are never independent authority.

## Language and communication

Communicate with the owner in Turkish. Internal goals, reports, prompts, and
artifacts are written in English unless the owner requests otherwise.
