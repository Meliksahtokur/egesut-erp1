# EgeSüt Unified Agent Harness Specification

Status: `ACCEPTED — phases 1-5 implemented and integrated 2026-09-03; pilots, phase 6, and rollout remain`

Date: 2026-09-02

This document specifies a repository-local, runtime-neutral agent harness for
EgeSüt ERP. It is a governance and execution contract, not an implementation.
No current `AGENTS.md`, `CLAUDE.md`, hook, skill, goal, memory, or runtime file
is made authoritative merely because it exists today.

## 1. Problem statement

EgeSüt currently exposes overlapping instruction and runtime surfaces through
`AGENTS.md`, `CLAUDE.md`, `.claude/`, `.agents/`, `.zcode/`, `.qwen/`, local
skills, hooks, memories, and task documents. Some are stale, some are local
only, and several disagree about schema facts, commit/push behavior, worker
authority, and orchestration.

The new harness must provide:

- one repository-local source of governance truth;
- native discovery by Codex, OMP, Claude Code, and ZCode;
- runtime choice without assuming a universal orchestrator;
- lightweight inline work for roots/leads;
- disciplined goals and worktrees when delegation or risk requires them;
- checkpoint-based documentation maintenance;
- queryable goal, report, decision, worktree, and commit history;
- clear commit, merge, push, deploy, and live-DB authority;
- pattern reuse and tests that discourage agents from inventing UI/RPC flows;
- low operational overhead and no mandatory vector-memory system.

## 2. Non-goals

The first implementation will not:

- build a general multi-project orchestration platform;
- make `orchestrator-master` the default control plane;
- require a goal document for every root/lead action;
- require Herdr outside an explicitly selected terminal workflow;
- make hooks hard blockers for ordinary work;
- treat worker `PASS` as integration acceptance;
- store raw transcripts, terminal logs, credentials, or runtime state in Git;
- require Obsidian, embeddings, a vector DB, or a graph DB;
- rewrite all existing documentation in one migration;
- deploy SQL, mutate live databases, merge, or push as part of harness setup.

## 3. Authority and precedence

Instruction precedence is:

1. system/developer instructions and explicit owner direction;
2. the active goal/task envelope;
3. `.harness/contract.md`;
4. applicable domain and pattern references;
5. runtime adapters;
6. historical reports, memory, and archived documents.

Runtime adapters may describe tool syntax and capabilities. They must not
define independent domain facts, schema facts, Git policy, or task authority.

Historical documents are evidence, not automatically current policy.
Documentation describing a runtime is not evidence that the runtime is currently
in use; only a live probe is.

### 3.1 Planes

Governance, factual Git state, execution, and product are separate planes. This
specification owns exactly one of them.

| Plane | Authority | Holds |
|---|---|---|
| Governance | `.harness/` | goal, manifest, docs authority, acceptance, patterns, history |
| Factual Git | Git itself | `status`, `diff`, `worktree list`, `HEAD`, branches, commits |
| Selected execution | the runtime chosen for the task | how the work is actually run |
| Product / domain | EgeSüt code, tests, live schema | product behavior and business rules |

The execution plane is pluggable. It is whichever flow was selected for the task:

```text
inline | zcode_builtin | codex_builtin | claude_builtin | herdr |
universal_worker | explicitly_named_other
```

No specific external runtime, worker bridge, mailbox, registry, or event bus is
part of this specification, and none is assumed to be active. Such a system is
consulted only when a goal explicitly selects the flow that uses it, and then
only as that flow's adapter under `.harness/runtimes/`.

The governance plane does not trust execution-plane self-reports. Acceptance is
computed from factual Git state, tests, and documentation evidence, never from a
worker's own claim of success.

### 3.2 Ground truth by question

| Question | Authoritative source |
|---|---|
| Does this worktree exist? | `git worktree list` |
| Which files changed? | real `git status` / `git diff` |
| Who owns this goal, and what is its manifest? | the `.harness/` goal record |
| Is a worker currently running? | the selected runtime's own surface |
| Was the work accepted? | root verification of diff, tests, and docs evidence |
| What is the database structure? | live schema |

A plane never answers a question it does not own. The harness records intent and
ownership for worktrees; it reads their existence from Git and never infers it
from its own records. The harness does not track live worker process state.

## 4. Target repository layout

```text
AGENTS.md                         # tracked after secret scan
CLAUDE.md                         # tracked; imports AGENTS.md

.harness/
├── README.md
├── contract.md
├── flow-routing.md
├── acceptance.md
├── docs-update.md
├── task-modes.md
├── patterns/
│   ├── index.yaml
│   ├── modal.md
│   ├── forms.md
│   ├── rpc.md
│   ├── offline-sync.md
│   └── testing.md
├── references/
│   ├── ui-map.md                # source-symbol map; validated against code
│   ├── domain-rules.md          # curated
│   └── rpc-reference.md         # curated contract; live schema still wins
├── runtimes/                    # thin per-runtime adapters, no shared policy
│   ├── zcode.md
│   ├── codex.md
│   ├── claude.md
│   └── herdr.md
├── goals/
│   └── YYYY/
├── reports/
│   └── YYYY/
├── memory/
├── decisions/
├── schemas/
│   ├── goal.schema.json
│   ├── report.schema.json
│   └── decision.schema.json
├── bin/
│   └── harness.py
└── cache/                       # ignored; rendered board/handoff/index/schema views

tests/harness/
```

Tracked files contain portable policy, contracts, references, tests, and
history. Ignored files contain credentials, local permissions, runtime state,
rendered aggregate/schema views, SQLite/JSON caches, and temporary agent
artifacts.

The current `.gitignore` entries for `AGENTS.md` and `CLAUDE.md` must be removed
only after a secret scan. Both files must be tracked before native discovery is
claimed. A scratch linked worktree must prove that they and `.harness/` arrive
through Git rather than local copying.

## 5. Native runtime discovery

### 5.1 `AGENTS.md`

Root `AGENTS.md` is the short runtime-neutral entrypoint for Codex and OMP. It
must remain a map, not a complete manual. It points agents to the applicable
files under `.harness/` based on task type.

### 5.2 `CLAUDE.md`

Root `CLAUDE.md` imports `@AGENTS.md` and may add a short Claude-only runtime
section. Shared policy must not be copied into both files.

### 5.3 ZCode

ZCode Desktop uses its built-in agents. Its adapter, `.harness/runtimes/zcode.md`,
points to the same repository-local contract. The runtime entrypoint must read
`.harness/contract.md` rather than embedding an independent policy summary. It
must not invoke Herdr by default. Credentials and local permissions stay
ignored even when a minimal adapter is tracked.

### 5.4 Herdr

Herdr is an explicitly selected terminal execution surface for Codex/Claude or
universal workers. It is not the semantic controller and is never selected
merely because parallel work might help. Its adapter is
`.harness/runtimes/herdr.md`.

### 5.5 Adapter constraints

Adapters are thin. They describe tool syntax, invocation, and capability limits
for one runtime. They must not restate shared policy, define domain or schema
facts, or set Git, goal, or acceptance rules. A check detects duplicated policy
markers across adapters.

## 6. Flow routing

Explicit owner selection always wins. If no flow is specified:

- small, tightly coupled work proceeds inline;
- independent read-only work may use built-in agents;
- ambiguous multi-worker or long-running work requires the root/lead to state
  a recommendation and ask the owner which flow to use;
- ZCode Desktop recommends ZCode built-in agents;
- terminal Codex/Claude recommends inline or built-in delegation first;
- Herdr and universal-worker flows require explicit selection;
- full orchestration skills require explicit selection and are not defaults.

The chosen flow identifies the selected execution plane for that task. The
harness consults a runtime's own surfaces only while that runtime is the selected
flow. The flow is recorded as metadata, not embedded into product policy:

```text
inline | zcode_builtin | codex_builtin | claude_builtin | herdr |
universal_worker | explicitly_named_other
```

## 7. Roles and permissions

### 7.1 Owner

The owner selects or overrides flow, approves material scope changes, and owns
push, deploy, live DB, destructive, and other separately gated decisions.

### 7.2 Root

Root is the integration authority. Root may work inline on main or in owned
worktrees, create goals, assign leads/workers, review, merge, and perform final
docs reconciliation. Root still respects explicit gates for push, deploy, DB,
and destructive actions.

### 7.3 Lead / administrative orchestrator

A lead may manage agents, goals, checkpoints, tests, and owned worktrees. A
lead may write only within the goal's product and documentation authority. A
lead may not silently expand scope, edit another goal, merge to main, push, or
perform live mutations unless the goal and owner explicitly grant that power.

### 7.4 Worker

A write worker requires an active goal, exact write manifest, owned worktree,
acceptance commands, stop conditions, and report target. A read-only worker
does not require a child goal unless its result is independently durable or
will outlive the session.

### 7.5 Verifier mode

A verifier is an independent review mode, not necessarily a persistent person
or process. It does not repair product code. It checks criteria, changed scope,
tests, docs state, and evidence, returning `PASS`, `FAIL`, or `INCONCLUSIVE`.

## 8. Task modes and goal trigger

### 8.1 Fast mode

Fast mode is allowed for root/lead inline work that is low risk, tightly
coupled, and does not require an independent write owner. No pre-authored goal
is required. Durable code work remains queryable through Git commits; durable
research may receive a short report.

### 8.2 Full mode

A goal is mandatory when any of these is true:

- independent write ownership is assigned to a non-root actor;
- parallel write ownership is introduced;
- the task can outlive the session or needs a handoff;
- DB/migration/live/external mutation is in scope;
- an experiment or rollback-sensitive change is planned;
- the owner explicitly requests a goal.

Read-only fanout, diagnosis, small docs corrections, and simple root/lead
changes do not automatically require goals. Worktree creation alone is not a
Full trigger: a root-owned solo worktree may remain Fast. Root may still choose
Full mode for a complex or risky change.

## 9. Goal contract

Each goal is a concise Markdown document with validated YAML frontmatter:

```yaml
id: G-YYYYMMDD-SLUG
status: draft|active|review|done|partial|blocked|cancelled|superseded
owner: root-or-lead-id
parent: null
flow: codex_builtin
created: YYYY-MM-DD
base_sha: null
launch_sha: null
branch: null
worktree: null
write_manifest: []
docs_authority:
  tracked_paths:
    write: []
    append: []
  local_paths:
    write: []
    append: []
  db: none
  propose_only: []
pattern_refs: []
acceptance: []
stop_conditions: []
report: null
checkpoint:
  sequence: 0
  kind: null
  head: null
  docs_verdict: null
```

`checkpoint.docs_verdict` uses the enum defined in 12.1. That enum is normative
in this specification, so the goal schema can validate against it independently of
when the docs-update engine is implemented.

The body contains only objective, invariants, exclusions, and necessary notes.
One goal represents one meaningful delivery unit. Child goals are created only
for independent write ownership, independent acceptance, or resumable work.

Lifecycle:

```text
DRAFT -> ACTIVE -> REVIEW -> DONE
                       \-> PARTIAL | BLOCKED | CANCELLED | SUPERSEDED
```

Workers cannot mark a goal `DONE`; integration authority does so after review.

## 10. Worktree contract

Every goal-owned worktree records exact base SHA, launch SHA, branch, path,
owner, write manifest, and current status.

The governance plane authorizes and records a worktree; the selected execution
plane creates and removes it. `harness worktrees` reads existence from
`git worktree list` and reports its own records only as ownership and intent. A
recorded worktree that Git does not show is reported as a discrepancy, never as
existing.

- one active write owner per worktree;
- parallel writes use disjoint worktrees and manifests;
- main and unrelated dirty work are preserved;
- worktrees do not imply DB, port, browser, provider, or process isolation;
- `DONE` is not inferred from a clean branch or green worker report;
- worktree cleanup occurs only after integration/rejection is recorded and
  Git state is independently checked;
- read-only work normally does not need a worktree.

## 11. Pattern reuse

Product changes identify relevant patterns and real source examples:

```yaml
pattern_refs:
  - MODAL-ROUTER-01
existing_examples:
  - js/utils/modal.js:openM
reuse_decisions:
  MODAL-ROUTER-01: reused
exceptions: []
```

A new pattern requires a production example, stated invariants and
anti-patterns, and an automated test. References prefer symbols and stable
identifiers over manually maintained line numbers.

## 12. Documentation update architecture

### 12.1 Core rule

Root and lead must run docs-update at every defined checkpoint. Running the
evaluation is mandatory; modifying every document is not. Each relevant
surface receives one result:

```text
UPDATED | NO_CHANGE_REQUIRED | PROPOSED | OUT_OF_SCOPE
```

The final docs verdict is `PASS`, `PARTIAL`, or `FAIL`.

### 12.2 Checkpoint kinds

- `pre-commit`: diff-driven references, goal, tests, and evidence;
- `pre-review`: report, manifest, acceptance, and documentation authority;
- `handoff`: goal/report state, blockers, open risks, and next action;
- `post-merge`: main reconciliation, goal status, and memory promotion;
- `final(publishing=false|true)`: goal closure, final references, durable
  learning, and—when publishing—remote-bound HEAD/range validation.

Ordinary test/fix iterations are not checkpoints.

`blocked` remains a goal status and uses the `handoff` checkpoint when context
must be transferred. `progress` is a normal goal update, not a checkpoint.
`pre-push` is represented by `final(publishing=true)`.

### 12.3 Documentation authority

Root has global reconciliation authority within the user-approved scope. Lead
authority is declared in the goal:

```yaml
docs_authority:
  tracked_paths:
    write:
      - .harness/goals/2026/G-....md
      - .harness/reports/2026/G-....md
      - .harness/references/ui-map.md
    append:
      - .harness/memory/ui.md
  local_paths:
    write: []
    append: []
  db: none
  propose_only:
    - .harness/references/domain-rules.md
```

Without explicit authority, a lead may update only its own tracked goal and
report. Ignored/local paths are forbidden unless named under `local_paths`.
Database access is separately declared as `none|read|write` and remains subject
to owner/live-DB gates. Proposed changes are recorded in the report for root
adjudication.

Tracked paths are verified from real Git status/diff, not only the staged diff.
Scoped ignored paths may be inspected with `git status --ignored` or direct
hashes. Out-of-repo and DB effects that cannot be independently observed are
reported as `ATTESTED`, never `VERIFIED`. Silence about an unobservable surface
is a failure.

### 12.4 Canonical and generated documents

Canonical inputs are goal files, reports, decisions, reference documents, and
curated memory notes. Aggregate views are rendered on demand into ignored
`.harness/cache/` or stdout:

- `BOARD.md` from goal statuses;
- `HANDOFF.md` from active goal handoff fields;
- `GOAL-INDEX.md` from goal/report metadata;
- `MEMORY-INDEX.md` from curated memory notes.

Rendered views are never independently edited or tracked. Queryability derives
from their tracked canonical inputs, not the rendered files.

No live-schema mirror is tracked. An optional `cache/schema-summary.md` may be
generated for local navigation with `authority: false`, project ref, generation
time, and source provenance, but only a live schema probe can establish a DB
fact. Curated `rpc-reference.md` and domain rules are product contracts rather
than claims that they mirror the live database; DB work must still verify them
against live schema.

### 12.5 Diff-driven routing

Docs-update classifies the diff:

- UI/forms/index changes evaluate UI map, modal/form patterns, and tests;
- RPC/migration changes evaluate live schema evidence, RPC reference, optional
  cached schema view, domain rules, and migration/deploy boundary;
- domain/state-machine changes evaluate domain rules and decisions;
- harness changes evaluate contract, routing, adapters, and harness tests;
- fixture changes evaluate testing patterns and producer provenance;
- goal/worktree changes evaluate goal, report, board, and handoff;
- durable new learning evaluates a memory candidate or decision record.

### 12.6 Decision records

`.harness/decisions/` holds durable governance and architecture decisions that a
goal or report should not own because they outlive both. A decision record is
validated by `decisions/../schemas/decision.schema.json` and carries id, date,
status (`proposed|accepted|superseded|rejected`), context, decision, consequences,
and superseded-by. Decisions are canonical inputs, never generated. Root owns
them; a lead may propose one through its report.

### 12.7 Memory

Memory contains only reusable, evidenced knowledge that prevents future wrong
decisions. Progress summaries, raw output, transient state, and information
already represented by a goal/report/commit are excluded. Workers do not write
canonical memory. Leads may write only with explicit authority; otherwise they
submit memory candidates for root promotion.

No vector DB is required. A search index may be derived from tracked files.

## 13. Query and indexing

Tracked Markdown/YAML and Git are canonical. A rebuildable ignored cache may
provide deterministic queries:

```text
harness goals active
harness show G-...
harness search modal
harness history --owner root
harness history --flow herdr
harness worktrees
harness stale
harness lineage G-...
```

The index covers goals, reports, parent/child relations, decisions, worktrees,
branches, SHAs, manifests, patterns, checkpoints, acceptance verdicts, and
associated commits. Ad-hoc root/lead code work is indexed from Git history:
subject, paths, author, and date always. Rich mode/flow/goal/docs/test metadata
is available only when a valid commit receipt or trailer supplied it. The index
must report absence honestly rather than infer `inline` or `PASS`.

Per 3.2, `worktrees` reports Git as the source of existence and the harness
records as the source of ownership and intent. No query reports live worker
process state.

## 14. Hooks and enforcement

Runtime hooks remain warning/context mechanisms and must not become the sole
authority. Deterministic enforcement belongs to explicit harness checks at
checkpoint, commit, review, merge, and push boundaries.

Metadata enrichment is not required by the MVP. No implementation phase may set
`core.hooksPath` until an independently reviewed dispatcher preserves every
pre-existing hook and exit code in main and linked worktrees. A future hook that
records only derivable facts is enrichment rather than enforcement, but it must
never assert a verdict it did not read from a matching receipt.

Checks cover:

- goal/report schema and unique IDs;
- manifest and documentation-authority violations;
- broken references and failures to render views from canonical data;
- invalid status transitions and missing reports;
- pattern IDs, source anchors, and required tests;
- worktree/base/launch identity;
- secret-like content in tracked harness files;
- runtime adapter drift;
- docs-update verdict and checkpoint freshness.

No checker may silently repair product or governance documents.

## 15. Git lifecycle

### 15.1 Root inline commit

```text
change -> tests -> docs-update pre-commit -> diff/status review
       -> atomic code+docs commit -> optional final checkpoint -> push gate
```

No goal is required for eligible fast-mode work. In a persistently dirty main
tree, review is scoped to the staged diff and declared manifest paths rather
than requiring a globally clean `git status`.

### 15.2 Lead worktree commit

```text
goal/worktree -> implementation -> tests -> docs-update pre-review
              -> lead local branch commit -> root review
```

### 15.2.1 Commit metadata

Ad-hoc work is queryable from Git subject, paths, author, and date without any
trailer. Richer queries by mode, flow, goal, and acceptance may use trailers or
a commit helper, but are not an MVP correctness dependency. Only derivable facts
or receipt-backed verdicts may be written:

```text
Harness-Mode: fast|full        # only when known
Harness-Goal: G-...            # omitted when there is no goal
Harness-Flow: unknown          # never silently inferred as inline
Docs-Update: PASS|PARTIAL      # only from a matching receipt
Tests: PASS|PARTIAL            # only from a matching receipt
```

A `Docs-Update` or `Tests` trailer requires a current receipt whose recorded HEAD
and diff hash match the commit input. An absent trailer is correct; a fabricated
`PASS` is a governance failure. Fast work still runs `pre-commit` docs-update;
its receipt may be represented by a valid trailer without requiring a goal.

The existing `.git/hooks/pre-commit` remains untouched. Optional future
enrichment through `core.hooksPath` is a separate post-pilot goal requiring a
dispatcher, red-before coverage, linked-worktree proof, and rollback proof that
the original hook is reachable again. Unsetting `core.hooksPath` alone is not
sufficient rollback evidence.

### 15.3 Merge

Root verifies manifest, diff, tests, docs authority, and evidence. For a Full
goal, root may merge with `--no-commit`, reconcile main-owned canonical docs
state, run post-merge/final docs-update, then create the merge commit. The
exact merge strategy remains a root decision; history preservation and clean
rollback are preferred over ceremony.

### 15.4 Push

Push is root-only by default and occurs only after accepted integration, clean
status, final docs verdict, and final acceptance. A lead may push only when a
goal explicitly grants it. Push does not imply deployment or DB migration.

### 15.5 Deploy and DB

Deploy, live DB writes, destructive actions, and remote creation remain
separate explicit gates. A migration file in Git is not evidence of deploy.

## 16. Bloat controls

- no goal for every root/lead action;
- no child goal for ordinary read-only agents;
- no per-worker artifact tree by default;
- no raw logs or transcripts in tracked docs;
- no manually maintained duplicate BOARD/HANDOFF/index state;
- no automatic memory entry at every checkpoint;
- no vector-memory requirement;
- one goal per meaningful delivery unit;
- one current checkpoint in the goal; Git retains earlier versions;
- docs-update may legitimately return `NO_CHANGE_REQUIRED`;
- checker output aggregates repeated findings;
- runtime-specific policy cannot fork the shared contract.

## 17. Security and privacy

Tracked harness files must not contain credentials, tokens, cookies, private
URLs, local permission grants, personal runtime state, or secret-bearing MCP
configuration. Migration begins with an inventory and secret scan; existing
ignored files are not bulk-added.

## 18. Acceptance criteria for the completed harness

1. Codex/OMP load root `AGENTS.md`; Claude loads the same shared rules through
   `CLAUDE.md`; ZCode sees the same contract through its native adapter.
2. No shared policy is duplicated across runtime adapters.
3. Fast root/lead work can complete without a goal while remaining queryable
   through Git.
4. Every independent non-root write owner has a valid goal, worktree, manifest,
   acceptance, docs authority, and report.
5. Docs-update produces a structured verdict at every defined checkpoint.
6. BOARD/HANDOFF/index views render on demand from canonical goal/report state
   and are not tracked.
7. Lead documentation writes outside declared authority are detected.
8. Root can review and integrate a goal without relying on worker claims.
9. Commit, merge, push, deploy, and live DB boundaries are distinct.
10. Modal, form, RPC, offline, and test work names and reuses canonical
    patterns or records a reviewed exception.
11. Goal/report/history queries rebuild from tracked files and Git without
    requiring a vector DB.
12. Current legacy runtime surfaces are either migrated, explicitly retained,
    or marked deprecated with an owner and removal condition.

## 19. Review scope

### 19.1 Owner decisions

Already decided by the owner. A reviewer may cost them, may show that two of them
conflict, and may show that one is unimplementable — but may not reverse one
unilaterally. Such findings return as `DECISION_NEEDED`.

- the harness is repository-local;
- no orchestration runtime is mandatory;
- ZCode Desktop uses its built-in agents by default;
- Herdr is a terminal surface chosen explicitly;
- root/lead work does not require a goal for every small action;
- a lead writes only within its goal's declared product and docs authority;
- worker `PASS` is not root acceptance;
- docs-update is a root/lead checkpoint responsibility.

### 19.2 Challengeable assumptions

Open for reversal on evidence:

- whether `.harness/` is the right directory name and namespace;
- the exact presentation of on-demand BOARD/HANDOFF views;
- whether future optional hook enrichment is worth its dispatcher cost;
- whether `--no-commit` merge reconciliation is robust for this repository;
- whether vector memory should be removed entirely;
- the exact Fast/Full threshold;
- which of the five roles collapse under single-operator use;
- whether leads should ever receive direct canonical memory authority;
- whether runtime adapters should be tracked files, generated files, or thin
  symlinks;
- how current dirty/local `.claude`, `.agents`, `.zcode`, and `.qwen` content
  is classified without losing evidence or secrets.

## 20. Pre-review revisions

This specification was revised once before independent review. The changes are
listed so a reviewer can challenge the corrections themselves, not only the
original text.

| # | Change | Reason |
|---|---|---|
| 1 | Added 3.1/3.2: plane separation and per-question ground truth | The original text left governance, Git, execution, and product authority implicit, which invites a second worker registry and lets documentation about a runtime be mistaken for proof it is in use |
| 2 | Added `runtimes/` to the 4 layout tree | The implementation plan wrote adapters into a directory the layout never defined |
| 3 | Added `decision.schema.json` and 12.6 | `decisions/` was a canonical input with no schema and no owner |
| 4 | Declared the 12.1 verdict enum spec-normative | The goal schema otherwise depended on an artifact defined in a later phase |
| 5 | Replaced recommended trailers with hook-based enrichment (15.2.1) | Optional trailers made ad-hoc queryability depend on discipline; verdict trailers are now forbidden without a matching receipt |
| 6 | Added staleness anchors to generated reference docs (12.4) | A tracked schema summary would otherwise become a new stale knowledge source |
| 7 | Split 19 into owner decisions and challengeable assumptions | Design conclusions and settled owner policy were previously indistinguishable |
| 8 | Made root instruction files tracked and moved aggregate views to ignored cache | Independent review F1/F3: ignored discovery files never reach worktrees; tracked whole-repo projections guarantee conflicts |
| 9 | Removed `core.hooksPath` from the MVP and preserved the existing hook | Independent review F2: changing the hook directory would silently disable active pre-commit enforcement |
| 10 | Reduced checkpoints from eight to five and expanded docs authority by surface | Independent review checkpoint/F5 findings: two kinds prevented no distinct failure and staged paths could not see local/DB writes |
| 11 | Removed tracked schema mirrors and recalibrated Fast/Full triggers | Independent review F4/A7: migration anchors cannot prove live-schema freshness, and worktree creation alone is routine rather than Full |

These revisions remain unproven until Phase 0/1 and pilot evidence. The two
critical review findings are closed in the design: tracked discovery is now a
Phase 1 prerequisite, and hook-directory replacement is no longer part of the
MVP.
