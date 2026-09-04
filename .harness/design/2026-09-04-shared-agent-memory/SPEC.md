# EgeSüt Shared Agent Memory Specification

Status: `DRAFT — approved in principle by the owner 2026-09-04; open items listed in §11`

Date: 2026-09-04

Baseline HEAD: `07816df33fcd81c39240af98f9226003a65292ab`

This document specifies a single shared durable-memory layer for every agent
runtime that works in this repository, and the closing routine that maintains
it. It is a governance and execution contract, not an implementation.

The implementing agent did not participate in the analysis that produced this
document. Every inventory figure below was measured at the baseline HEAD and is
reproducible with the command given. Re-verify before relying on a figure; a
mismatch is a finding, not noise. Where a claim is unverified, it says so.

## 1. Problem statement

Durable knowledge about this repository is spread across seven independent
stores, written by three CLIs under three different disciplines, with no shared
reader and no mechanical trigger.

Measured at the baseline HEAD:

| # | Store | Volume | Newest write | Knows the harness? |
|---|---|---|---|---|
| 1 | ZCode auto-memory (`~/.zcode/cli/memories/projects/egesut-erp1-*/`) | 38 notes + index | 2026-09-04 | yes (4 notes) |
| 2 | Claude native memory (`~/.claude/projects/-home-melik-egesut-erp1/memory/`) | 32 notes + index | 2026-08-30 | no (0 mentions) |
| 3 | tools-bank local vector DB (`~/tools-bank/memory/memory.db`) | 379 notes / 509 vectors | 2026-09-03 | barely (5 of 379) |
| 4 | Codex memory repository (`~/.codex/memories/`) | 60 task groups, 77 rollout summaries, 234 KB index | 2026-09-03 | no (0 mentions) |
| 5 | `.remember/remember.md` | 11.5 KB, 3 layers | 2026-09-04 | yes, but unreachable |
| 6 | `.harness/memory/` | empty (README only) | — | canonical slot, unused |
| 7 | Supabase `memory_notes` table | 275 rows | 2026-07-04 | frozen historical copy |

The consequences are structural:

- **The canonical slot is empty while the gate already demands it.** `memory` is
  a required docs-update surface at the `post-merge` and `final` checkpoints
  (`.harness/bin/harness.py:327-328`). The last publish receipt at the baseline
  HEAD recorded `memory: NO_CHANGE_REQUIRED` while the same session wrote five
  notes to store 3, three to store 1, and a new layer to store 5.
- **Two of three runtimes start from stale, contradictory context.** Store 2
  contains no `.harness` knowledge at all. Store 4 injects a project-discipline
  profile instructing the agent to consult `BOARD/ROADMAP/HANDOFF`, a convention
  this repository does not use.
- **Nothing fires the closing routine.** No runtime configures a `SessionEnd`
  hook here. `~/.local/bin/docs-checkpoint` exits silently in this repository
  because its scope gate recognises only `.claude/skills/docs-update` or a root
  `MEMORY.md` plus `BOARD.md` (lines 130-132); this repository has neither. The
  global ZCode `docs-update` skill detects project convention from the same two
  families and also does not recognise `.harness`. Discipline is therefore
  entirely voluntary, and it measurably collapsed: store 3 received 145 notes in
  May, 126 in June, 85 in July, **one** in August, and 22 in September after the
  owner declared the routine mandatory on 2026-09-02.
- **Store 3's ranking cannot surface current knowledge.** 357 of 379 notes (94%)
  predate 2026-09-01, ranking is pure vector similarity with no recency weight,
  and a query for the current RPC reference rule returns six May–June results
  and none naming `.harness/references/rpc-reference.md`.
- **Store 3 is not project-scoped.** Roughly 76 of 379 notes mention EgeSüt. It
  is a cross-project pool, not a cross-CLI shared memory.
- **The freshest handoff is structurally unreachable.** `.remember/remember.md`
  was deliberately untracked in commit `b3b247c` (`.gitignore:76`) and no
  entrypoint references it. It does not survive a clone, and no agent is told to
  read it.

### 1.1 What this specification is *not* reacting to

An earlier draft argued that a large memory document is inherently a failure
mode, citing `ilan-arastirma/MEMORY.md` at 29,071 lines. Direct measurement
refuted that argument and it has been withdrawn:

```text
632 entries | median 33 lines | mean 45 | largest entry 300
plus a 674-line generated "## Index" section
```

Entries there are short and disciplined without any mechanical size bound. The
file is large because it holds 632 curated entries, not because entries sprawl.
That system works in practice. Consequently this specification imposes **no
entry-count cap and no per-entry size cap**; see §4.3 for what replaced them.

## 2. Non-goals

This specification will not:

- introduce a new database, vector index, embedding model, graph store, or
  external memory service;
- make `docs-update` write content, or otherwise merge the verifier with the
  thing it verifies;
- create a root `MEMORY.md`, `BOARD.md`, `ROADMAP.md`, or `HANDOFF.md`;
- migrate the full historical corpus into canonical memory;
- delete any historical store;
- introduce any hard block; every mechanism added here is warning-only;
- change the authority order, the DB authority rule, `core.hooksPath`, or
  `.git/hooks/pre-commit`;
- require any runtime to be installed, running, or reachable for harness
  correctness.

## 3. Target architecture

Durable knowledge occupies four slots. Every slot already exists.

| Slot | Location | Role | Tracked | Authority |
|---|---|---|---|---|
| Canonical memory | `.harness/memory/MEMORY.md` | evidenced lessons that prevent a future wrong decision | yes | governance plane |
| Linked documents | `.harness/memory/*.md` (other files) | long-form material an entry points to | yes | same as their entry |
| Rotating handoff | `.harness/handoff.md` | where the last few sessions left off | yes | reminder only, never authority |
| Historical archive | frozen store 3, plus `.claude/archive/` exports | interrogable history | no (local) | evidence, never current policy |
| Runtime pointers | each CLI's own auto-memory index | redirect to the canonical slot | no (local) | none |

Nothing else stores durable repository knowledge.

### 3.1 Why the repository, not a database

The canonical slot must be a tracked path in this repository because that is the
only surface all three runtimes read without per-runtime configuration, that
survives a clone, that is reviewable in a diff, and that the existing gates
already route. A database satisfies none of those four properties.

Verified at the baseline HEAD: `.harness/memory/*.md` is trackable.
`.gitignore:185-186` re-includes the directory, and `git add --dry-run` on a
probe file succeeds while `git check-ignore -q` exits 1. No `.gitignore` change
is required. Note that `git check-ignore -v` prints the negation rule as the
matching line, which reads as if the file were ignored; the exit code is the
authority.

### 3.2 One file, with linked documents

Canonical memory is **one file** containing `## ` entries, plus optional
sibling documents that entries link to. This matches the shape already in use in
`ilan-arastirma` and in each runtime's native memory, and it is the shape the
owner selected on 2026-09-04.

The reasoning, recorded so it is not re-litigated:

- Agents read memory by keyword, not end to end. One `grep` over one file
  returns cross-cutting matches in a single call; a directory requires a walk
  and a read per hit.
- Appending an entry is one heredoc write. A file-per-note store costs one write
  per note.
- The shape is proven at 632 entries in the owner's other repository.
- The evidence that once argued for many small files came from *vector*
  retrieval failing under volume (§1). That failure does not transfer to grep,
  which locates an entry regardless of store size.

Accepted cost: two worktrees appending to the same file in the same session
produce a Git conflict where separate files would not. This repository does run
worktree-per-lane. The conflict is append-vs-append and is resolved by keeping
both entries; it is not considered decisive.

### 3.3 Runtime pointers, not runtime stores

Per-CLI auto-memory indexes are retained, because each is injected into its
runtime's context for free at session start, and that is the cheapest available
channel for correcting a cold start. They are demoted from stores to pointers:
each index is reduced to a short stub naming `.harness/memory/MEMORY.md` as
canonical.

A pointer cannot drift from the canonical store, because it holds no facts to
drift with. This makes divergence structurally impossible rather than merely
discouraged.

The Codex `memory_summary.md` user-profile section is preserved verbatim; only
its project-discipline claims are replaced.

## 4. Canonical memory contract

### 4.1 Admission rule

An entry may enter `MEMORY.md` only if all four hold:

1. it is evidenced — it names the probe, commit, test, or observation that
   established it;
2. it prevents a specific future wrong decision;
3. it is not already represented by a goal, report, decision, contract,
   pattern, or reference;
4. it is not progress narration, transcript, runtime state, credentials, or a
   fact recoverable from `git log`.

Rules 1–4 restate `.harness/contract.md` and `.harness/memory/README.md`. This
specification adds only the mechanical enforcement in §6.

### 4.2 Entry format

Entries are `## ` sections, numbered so they can be cross-referenced from other
entries, reports, and goals as `§N`. Numbers are assigned in sequence and are
never reused after retirement.

```markdown
## §N — <Subject, one specific line> (YYYY-MM-DD)

Verified-at: <commit sha, probe command, or ISO date — and how it was checked>
Applies-to: <repository paths, RPC names, or flows this governs>

<The rule, stated as one imperative sentence.>

**Why:** <the incident or measurement that produced it>
**How to apply:** <when the reader should act on it>
```

`Verified-at` and `Applies-to` are required fields; §6.3 tests for their
presence. `Applies-to` may be `none` when the entry governs no specific path,
and that value disables the §6.2 staleness signal for that entry.

Long-form material lives in a sibling document under `.harness/memory/` and is
linked from its entry. `README.md` is not an entry and is excluded from the
index.

### 4.3 Bounds

There is no entry-count cap and no per-entry size cap. The measurement in §1.1
showed that entry discipline holds without one, and the owner's system operates
at 632 entries without difficulty.

What replaces them is a staleness signal (§6.2). The real risk in a
grep-accessed store is not size — it is that `grep` surfaces an entry that
silently stopped being true, and the reader believes it. Five entries in store 3
still cite paths retired by `D-20260904-PHASE6-LEGACY-RETIREMENT`; nothing in
either system would have caught that.

Retirement is deletion of the entry from `MEMORY.md`. The content stays
recoverable in Git history, so no archive copy is required and the entry number
is not reused.

### 4.4 Database claims

Live schema remains the only DB authority. A memory entry never upgrades a claim
about the database into fact, regardless of its `Verified-at` value.

## 5. The closing routine

### 5.1 One command, two responsibilities

Agents invoke exactly one routine at session close. It writes, then asks the
existing gate to verify:

```text
session-close
  1. survey  — what did this session establish?
  2. route   — canonical memory? handoff? reference/pattern? nothing?
  3. write   — .harness/memory/MEMORY.md and/or .harness/handoff.md
  4. verify  — harness.py docs-update <checkpoint> --write-receipt
```

Step 4 is the existing engine, unchanged. `docs-update` continues to evaluate
and receipt; it never writes content. This preserves the property that makes a
receipt evidence: the artefact that checks the work is not the artefact that
performs it.

`session-update` and `memory-update` are superseded. Their overlap is documented
rather than suspected: `memory-update` describes itself as the expanded form of
`session-update` step 3.5. They persisted as two skills because of *location* —
`session-update` is ZCode-global and invisible to Claude and Codex — not because
they did different work.

### 5.2 Discovery

The routine's canonical text lives in `.harness/`, as `docs-update.md` already
does, because `D-20260904-PHASE6-LEGACY-RETIREMENT` designates `.claude/` as the
owner's local surface rather than a canonical one. Runtime-visible skill
wrappers are thin pointers. The existing `.agents/skills/* -> ../../.claude/skills/*`
symlink pattern is reused so one body of text serves multiple discovery paths.

Which directories each runtime actually scans is an empirical question. The
implementation plan probes it in Phase 0 and does not assume it.

### 5.3 Rotating handoff

`.harness/handoff.md` replaces `.remember/remember.md` and is tracked, so it
survives a clone and is reachable from the entrypoint map.

It carries the three most recent layers. A fourth is pruned when a new one is
written; Git history retains it. This is a convention enforced by the routine
and by review, not by a test.

Full-mode goals continue to record blockers and next actions in their reports;
`blockers_risks` and `next_action` remain report surfaces. `.harness/handoff.md`
exists because Fast-mode sessions produce no report and would otherwise have no
continuity slot.

## 6. Enforcement model

Three mechanisms. **All are warning-only.** No mechanism specified here blocks a
commit, a push, or an edit. The owner's stated reason is that hard blocks make
work harder and agents do act on warnings; the harness's existing edit and commit
guards already follow this convention.

### 6.1 Trigger — SessionEnd hooks

Each runtime gains a `SessionEnd` hook that detects undocumented debt and names
the closing routine. All three already support hooks: `.claude/settings.json`,
`.zcode/config.json`, `~/.codex/hooks.json`.

The existing `docs-checkpoint` implementation is reused rather than replaced.
Its scope gate is extended to recognise a third project family — a repository
containing `.harness/contract.md` — alongside the two it already knows. The same
extension is applied to the global ZCode `docs-update` skill's convention
detection, mapping the harness roles: canonical memory `.harness/memory/MEMORY.md`,
handoff `.harness/handoff.md`, direction `.harness/goals/`, mechanical audit
`harness.py docs-update`.

### 6.2 Gate — the `memory` docs surface and two signals

The `memory` surface is already required at `post-merge` and `final`. No engine
change is needed for it to exist. One limitation must be stated plainly:

> `evaluate_docs_update` (`.harness/bin/harness.py:489`) validates the *enum* and
> the *freshness flag* of a surface outcome. It does not inspect content.
> `memory: NO_CHANGE_REQUIRED` is an attestation by the agent, not a verified
> fact.

Two `WARNING`-level findings are added. Neither changes a verdict:
`evaluate_docs_update` computes `FAIL` only from `ERROR` entries.

**Signal A — decision without a lesson.** At the `final` checkpoint, when the
change set includes a new `.harness/decisions/` record and `memory` is attested
`NO_CHANGE_REQUIRED`, emit a warning. A session that produced a durable decision
usually produced a durable lesson.

**Signal B — staleness by change, not by calendar.** When a path in the current
change set matches an entry's `Applies-to` field and that entry's `Verified-at`
was not updated in the same change, emit a warning naming the entry. This reuses
the routing the engine already performs for `ui_map` and `rpc_reference`, and it
is preferred over a calendar rule because a stable rule does not rot on a
schedule — it rots when the thing it describes changes.

A coarse calendar backstop (`Verified-at` older than 180 days on an entry whose
`Applies-to` paths never change) is **deferred**, not specified here. It should
only be added if Signal B proves insufficient in practice.

Residual limit, accepted deliberately: nothing mechanical judges whether an entry
is *good*, or whether an agent read it when it mattered. That remains a review
responsibility.

### 6.3 Format — harness tests

`tests/harness/test_memory.py` joins the existing 106-test suite and enforces §4.2:

- every `## ` entry has a unique, sequential `§N` number;
- every entry carries non-empty `Verified-at` and `Applies-to` fields;
- `render memory-index` lists every entry and every linked document;
- the index render is stable — running it twice produces identical output.

A red-before fixture is required for each assertion, per the harness's standing
rule that new enforcement behaviour must be demonstrated failing first.

### 6.4 Required change to `render_memory_index`

`render_memory_index` (`.harness/bin/harness.py:1244`) currently globs
`.harness/memory/**/*.md`, skips `README.md`, and emits one row per file using
the file's first `# ` line as the subject. Under §3.2 that yields a single row
for the whole store.

It must instead emit:

- one row per `## ` entry in `MEMORY.md`, with the entry number, its subject, and
  a link anchor;
- one row per other `*.md` file in the directory, as today, marked as a linked
  document.

`rendered_cache_findings` (`.harness/bin/harness.py:1269`) compares the rendered
`MEMORY-INDEX.md` against any cached copy and must keep working unchanged. The
cache remains ignored derived state and never becomes authority.

## 7. Historical consolidation

### 7.1 Principle

The corpus is triaged, not imported. A historical note enters canonical memory
only by passing §4.1 on its own merits. Provenance is preserved; volume is not.

### 7.2 Measured funnel

The apparent problem is roughly 750 records. The real candidate pool is smaller,
and the first stages are mechanical:

| Stage | Rule | Effect |
|---|---|---|
| Freeze | stop writes to stores 1–5 and 7 | prevents merging a moving target |
| Export | one provenance-tagged JSONL from all stores | machine step |
| Drop migrated duplicates | store 3 rows carrying a `+00:00` suffix in `created_at` are the Supabase migration; 274 such rows exist in a contiguous id block 1001–1274 with a date range identical to the Supabase table's | −274 records |
| Drop out-of-scope | Codex `rollout_summaries` mention EgeSüt zero times | −77 records |
| Drop retired infrastructure | entries whose subject is OMP, pi, goose, telsiz, goused, Muse, ACP bridges, `.qwen`, or `ground_truth`, carrying no product or harness claim | −71 records in store 3 alone |
| Drop narration | `code_change` entries recording that a commit landed or a task closed — forbidden by §4.1 rule 4 | largest reduction of the remaining 129 |
| Drop represented | claims already carried by `.harness/references/`, `patterns/`, `decisions/`, or goal reports — `rpc_reference` (19) and `domain_rules` (20) are largely in this class | −39 or fewer |
| Deduplicate | cluster survivors using the local embedding index, once, as a merge tool | consolidation, not storage |
| Triage | §4.1 applied per surviving entry | manual, bounded |

There is no target entry count. The admission rule is the only filter.

#### 7.2.1 Correction to an earlier claim

An earlier draft asserted that the Supabase table is a verified full duplicate of
store 3, based on four content probes. Fuller measurement corrected this:

```text
store 3 rows with a "+00:00" created_at suffix : 274   (migrated)
store 3 rows without it                        : 105   (written natively)
Supabase memory_notes rows                     : 275
```

**274 of 275 rows are accounted for; one is not.** The five timestamps that
repeat in the Supabase table were checked and the missing row is not among them.
Identifying it is a Phase 0 task. Until it is identified, "full duplicate" is not
established, and no removal decision may rest on the four-probe sample.

The `+00:00` suffix is the migration marker and is the recommended mechanism for
the full comparison: natively written rows do not carry it.

### 7.3 Archival, not deletion

Nothing is deleted from a historical store during consolidation. The full
provenance-tagged export and a copy of each store are written to
`.claude/archive/memory-consolidation-2026-09-XX/`, following the precedent of
`.claude/archive/qwen-retirement-2026-09-04/`.

Per owner decision, the archive stays local and untracked. Everything that
enters canonical memory is in Git history; the archive holds only what did not.

## 8. Disposition of every existing surface

| Store | Disposition | Rationale |
|---|---|---|
| ZCode auto-memory | reduce index to pointer stub; notes exported then archived | freshest store, but single-runtime |
| Claude native memory | reduce index to pointer stub; notes exported then archived | zero harness knowledge; actively misleads |
| tools-bank vector DB | writes disabled; reads retained; used once as dedup tool | interrogable history has value; continued construction does not |
| Codex memory repository | preserve user profile verbatim; replace project-discipline text with stub; rollout summaries archived | profile is accurate and useful; project claims are not |
| `.remember/remember.md` | latest layer migrated to `.harness/handoff.md`; file retired | untracked plus unreferenced is the worst of both |
| `.harness/memory/MEMORY.md` | becomes the canonical store | gate already routes the directory |
| Supabase `memory_notes` | **kept**, documented in canonical memory; drop optional and owner-gated | inert, and one row is still unaccounted for (§7.2.1) |
| GitNexus index | unchanged, out of scope | a code-structure index, not durable knowledge; mechanically bound to HEAD and needs no memory discipline |

The Supabase table is retained per owner decision on 2026-09-04. Keeping it has
one cost: it appears in every live-schema probe and table inventory as an
unexplained agent-infrastructure table in a product database. That cost is paid
once by adding a canonical entry describing what it is, so no future schema audit
has to re-investigate it — the July 2026 orphan-RLS-table episode is the
precedent for what happens otherwise.

## 9. Acceptance criteria

Each criterion needs a `PASS`, `PARTIAL`, `FAIL`, or `INCONCLUSIVE` verdict
backed by a named command and its output.

1. `.harness/memory/MEMORY.md` is tracked, holds at least one entry, and every
   entry conforms to §4.2.
2. `harness.py render memory-index` lists every entry and every linked document,
   and produces identical output on a second run.
3. `tests/harness/test_memory.py` passes, each assertion has a demonstrated
   red-before fixture, and the full harness suite passes at its new count.
4. Signals A and B each fire on a constructed fixture and are absent otherwise,
   and neither changes a `PASS` verdict into `FAIL`.
5. A `SessionEnd` hook is configured and **observed firing** in each of the three
   runtimes. File presence is not evidence.
6. `docs-checkpoint` produces output in this repository where the baseline
   produced silence, and still exits silently in a repository matching neither
   pre-existing family.
7. Each runtime's auto-memory index is a pointer stub containing no repository
   facts, and the Codex user profile is otherwise unchanged.
8. `.harness/handoff.md` is tracked and referenced from `AGENTS.md`; `.remember/`
   is retired and no entrypoint references it.
9. One closing routine is discoverable from every runtime path identified in
   Phase 0; `session-update` and `memory-update` no longer exist as separate
   routines.
10. The consolidation export exists in `.claude/archive/`, and every canonical
    entry traces to either a source record in it or to a new session.
11. The unaccounted Supabase row is identified, and a canonical entry documents
    the table.
12. `core.hooksPath` is unset, `.git/hooks/pre-commit` is unchanged, no
    mechanism added here blocks any operation, and the pre-existing dirty
    working tree is preserved.

## 10. Risks and reversibility

| Risk | Mitigation | Reversal |
|---|---|---|
| Entries accumulate and silently go stale | Signal B warns when a changed path matches an entry's `Applies-to` | correct or retire entries; Git history retains them |
| Consolidation imports narration | §4.1 applied per entry; triage record states why each rejection happened | delete entries |
| A SessionEnd hook annoys its user into disabling hooks entirely | warning-only, deduplicated by HEAD, silent when there is no debt | remove the hook entry; nothing else depends on it |
| Freezing store 3 loses recall the team relies on | reads stay enabled; the DB file is untouched | re-enable writes |
| Pointer stubs discard useful runtime-local context | notes are exported and archived before any index is reduced | restore from archive |
| Two worktrees conflict appending to `MEMORY.md` | append-vs-append conflict; resolution is to keep both entries | ordinary merge resolution |
| A global tooling change regresses another repository | additive change; before/after probe in a second repository; file archived before editing | restore from archive |
| Archive is lost with the local machine | accepted by owner decision; everything canonical is in Git | none needed |

Every phase is independently reversible, and no phase requires the next to run.

## 11. Decisions and open items

Settled by the owner on 2026-09-04:

- Canonical memory is **one file with linked documents**, not a file per entry.
- **No entry-count cap and no per-entry size cap.**
- Staleness is a **warning**, never a block.
- The archive stays **local and untracked**.
- Editing global tooling (`~/.local/bin/docs-checkpoint`, the ZCode global
  `docs-update` skill, runtime hook configs) is **authorised**, executed
  file-by-file with each file archived first.
- The Supabase `memory_notes` table is **kept**; the drop is optional and
  requires separate approval.

Open:

1. **The unaccounted Supabase row** (§7.2.1) — identify in Phase 0.
2. **Skill discovery per runtime** — which directories Claude Code, Codex, and
   ZCode actually scan for repository-local skills is unverified and is probed in
   Phase 0. The Phase 2 wrapper layout depends on the answer.
3. **Context injection per runtime** — that a stub in each runtime's auto-memory
   location actually reaches the model is unverified and is probed in Phase 0.
   Phase 5 depends on the answer.
4. **Calendar staleness backstop** (§6.2) — deferred; add only if Signal B proves
   insufficient.
