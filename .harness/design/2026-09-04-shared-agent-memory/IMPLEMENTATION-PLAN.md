# EgeSüt Shared Agent Memory — Implementation Plan

Status: `DRAFT — approved in principle by the owner 2026-09-04; for execution by ZCode agents, owner reviews afterwards`

Baseline HEAD: `07816df33fcd81c39240af98f9226003a65292ab`

This plan implements `SPEC.md` incrementally. It separates mechanical
infrastructure (phases 1–3), trigger wiring that touches files outside this
repository (phase 4), context correction (phase 5), and historical adjudication
(phases 6–7), so that a phase can be accepted, deferred, or reverted alone.

**Read `SPEC.md` first.** This plan does not restate its contracts. Where the two
disagree, `SPEC.md` wins and the disagreement is a finding.

## 0. Notes for the implementing agent

You did not participate in the analysis behind this plan. Three things follow.

1. **Every baseline figure carries its command.** Re-run it. A mismatch is a
   finding to report, not noise to absorb, and not a reason to redesign.
2. **Two central findings were invisible from file listings** — a globally
   installed watcher that exits silently in this repository, and a global skill
   whose project-convention detection does not recognise `.harness`. Both only
   appeared on execution. Do not claim hook behaviour, skill discovery, or
   context injection from file presence. Probe it.
3. **Nothing here may block.** Every mechanism added is warning-only. If an
   implementation would cause a `FAIL` verdict, a rejected commit, or a refused
   edit, it is wrong — see `SPEC.md` §6.

Scope discipline: the main worktree holds substantial unrelated dirty and
untracked `.claude` state (43 entries at the baseline), and
`/home/melik/egesut-wt/planli-asi` belongs to other work. Both must be preserved
untouched. Only your phase's manifest may change.

## 1. Delivery strategy

The work changes tracked governance surfaces, documentation authority, runtime
hook configuration, and three global tool installations. It uses one Full goal
and an isolated worktree.

Suggested identity, subject to owner approval:

```text
goal:     G-20260904-SHARED-AGENT-MEMORY
branch:   idle/shared-agent-memory
worktree: /home/melik/egesut-wt/shared-agent-memory
```

No phase includes push, deploy, DB mutation, or destructive cleanup by default.
Phase 4 requires its own authorisation for the reason stated in its section.

### 1.1 Measured baseline

Measured at `07816df` on 2026-09-04.

| Fact | Command | Value | Consequence for this plan |
|---|---|---|---|
| `memory` is already a required surface | `grep -n '"memory"' .harness/bin/harness.py` | required at `post-merge`, `final` (lines 327-328) | phase 1 needs no routing change for the gate to demand memory |
| The canonical store is empty | `ls .harness/memory/` | `README.md` only | `render memory-index` currently emits an empty table |
| `.harness/memory/*.md` is trackable | `git add --dry-run`, `git check-ignore -q` | add succeeds; check-ignore exits 1 | no `.gitignore` work; note `check-ignore -v` prints the negation rule and reads misleadingly |
| Index renderer is file-per-note | `.harness/bin/harness.py:1244` | globs `**/*.md`, one row per file, subject from first `# ` | must be changed per `SPEC.md` §6.4 |
| Surface outcomes are attestations | `.harness/bin/harness.py:489-540` | enum + freshness validated; content not inspected | signals A and B are the only mechanical checks available |
| Verdict severity source | same function | `FAIL` only from `ERROR` findings | `WARNING` findings are safe to add |
| Harness suite size | `grep -rc 'def test_' tests/harness/*.py` | 106 across 11 files | phase 1 raises this; the new total is an exit criterion |
| `docs-checkpoint` is silent here | run with a scratch `XDG_CACHE_HOME` | `exit=0`, no output | the trigger is genuinely absent, not unreliable |
| Its scope gate | `grep -n 'docs-update\|MEMORY.md' ~/.local/bin/docs-checkpoint` | needs `.claude/skills/docs-update` or `MEMORY.md`+`BOARD.md` (lines 130-132) | a third family must be recognised |
| Global ZCode `docs-update` convention detection | `head -40 ~/.zcode/skills/docs-update/SKILL.md` | knows two families; `.harness` is neither | same fix, second location |
| `.remember` is untracked | `git ls-files .remember`; `.gitignore:76` | empty; ignored since `b3b247c` | migration is a new tracked file plus retirement, not `git mv` |
| No entrypoint references `.remember` | `grep -rn remember AGENTS.md CLAUDE.md .harness/` | no hits | nothing breaks when it is retired |
| Skill discovery uses symlinks | `ls -la .agents/skills/memory-update` | symlink into `.claude/skills/` | one body of text can serve multiple discovery paths |
| `.claude/skills/` is untracked, not ignored | `git check-ignore -v` returns nothing | untracked | canonical text lives in `.harness/`, per `D-20260904-PHASE6-LEGACY-RETIREMENT` |
| Supabase migration marker | `created_at like '%+00:00'` in store 3 | 274 migrated, 105 native, ids 1001–1274 | phase 0 uses this for the full comparison |
| Supabase table size | `supabase_query` count | 275 rows | one row unaccounted; see `SPEC.md` §7.2.1 |
| Store 3 monthly write volume | `sqlite3` group-by on `created_at` | 145 / 126 / 85 / **1** / 22 | the August collapse is the evidence that voluntary discipline fails |
| GitNexus index | `list_repos` | at `07816df`, 0 commits behind | out of scope, confirmed current |
| Owner's other memory system | `awk` over `ilan-arastirma/MEMORY.md` | 632 entries, median 33 lines | the single-file shape is proven at scale; see `SPEC.md` §1.1 |

## 2. Global acceptance principles

Every phase must provide:

- exact changed-file scope;
- deterministic tests;
- a red-before fixture or mutation for new enforcement behaviour;
- a `docs-update` verdict with a written receipt;
- `PASS`, `PARTIAL`, `FAIL`, or `INCONCLUSIVE` per criterion;
- an independent review before integration;
- explicit residual and unmeasured boundaries;
- clean restoration of temporary mutations and test artefacts.

### 2.1 Phase dependency rule

No phase validates an artefact a later phase defines.

Known instance: the pointer stubs in phase 5 redirect readers to
`.harness/memory/MEMORY.md`. They must not ship before phase 1 has populated it,
or the stubs will point at an empty file and produce a worse cold start than the
stale indexes they replace.

### 2.2 Recommended first slice

Phases 1 and 5 together are the cold-start fix and deliver most of the value:
two of three runtimes stop injecting pre-harness discipline into every session.
They are small and independently reversible. Phases 2–4 make the discipline
mechanical. Phases 6–7 settle history and can be deferred indefinitely without
degrading the working system.

## 3. Phase 0 — Probe, freeze, and export

### Objective

Establish the facts later phases depend on, stop the corpus from moving, and
capture it once with provenance. Read-mostly; the only writes are the export and
the freeze notices.

### Scope

```text
.claude/archive/memory-consolidation-2026-09-XX/   (new, local, untracked)
.harness/design/2026-09-04-shared-agent-memory/    (findings appended)
```

### Steps

1. Re-verify every row of §1.1 and record deviations.
2. **Probe skill discovery per runtime.** Determine empirically which directories
   Claude Code, Codex, and ZCode scan for repository-local skills. Do not assume
   `.agents/skills/` is read by ZCode; the symlink pattern is evidence about
   Claude and Codex only. This determines the phase 2 wrapper layout.
3. **Probe context injection per runtime.** Confirm which auto-memory index each
   runtime loads at session start and that a stub placed there reaches the model.
   This determines whether phase 5 works at all.
4. **Identify the unaccounted Supabase row.** Export all 275 `created_at` values
   and compare against store 3's 274 rows carrying the `+00:00` suffix. Report
   the missing row's id, timestamp, and content. Do not delete anything.
5. Export all stores to one provenance-tagged JSONL: source store, record id,
   timestamp, category, tags, content. Stores 1, 2, 3, 4, 5, 7.
6. Copy each store verbatim into the archive directory alongside the export.
7. Freeze writes: mark `memory-update` and `session-update` superseded in place,
   and remove `memory_add` from repository guidance. The tools-bank DB file is
   left byte-identical; freezing is a policy act, not a mutation.

### Exit criteria

- Export record counts reconcile with the per-store counts in `SPEC.md` §1, or
  every discrepancy is explained.
- The unaccounted Supabase row is identified, or the comparison is reported with
  its method and why it was inconclusive.
- Skill discovery and context injection are answered per runtime with a named
  probe and its output, or explicitly marked `INCONCLUSIVE`.
- No historical store was modified.

### Risks

The discovery probes may show that no single repository-local path serves all
three runtimes. That is a finding, not a blocker: the fallback is one canonical
body in `.harness/` with per-runtime wrappers, which phase 2 already assumes.

## 4. Phase 1 — Open the canonical store

### Objective

Make `.harness/memory/MEMORY.md` real, correctly indexed, and format-checked,
and seed it from evidence this repository already has.

### Scope

```text
.harness/memory/MEMORY.md          (new)
.harness/memory/README.md          (unchanged)
.harness/bin/harness.py            (render_memory_index only)
tests/harness/test_memory.py       (new)
tests/harness/test_rendered_views.py  (if the index change affects its assertions)
```

### Steps

1. Change `render_memory_index` per `SPEC.md` §6.4: one row per `## ` entry in
   `MEMORY.md` with number, subject, and anchor; one row per other `*.md` file as
   a linked document; `README.md` still excluded. Keep `rendered_cache_findings`
   working — it compares the render against the ignored cached copy.
2. Write `tests/harness/test_memory.py` per `SPEC.md` §6.3: unique sequential
   entry numbers, required `Verified-at` and `Applies-to` fields, index lists
   every entry and linked document, render is stable across two runs.
3. Demonstrate each assertion red-before with a temporary fixture, then restore.
4. Create `MEMORY.md` and seed it from measured evidence, not recollection. Each
   candidate below satisfies `SPEC.md` §4.1 and was established by a probe:
   - the gate chain order, and the `cmd --json | python -c ...` pipe swallowing
     the exit code — a final `FAIL` did not stop an `&&` chain in pilot 2 and a
     merge commit landed before it was corrected;
   - live schema is the only DB authority — a live RPC body was observed
     differing from the retired tracked mirror;
   - the `farm_id` forward discipline for new tables and new write RPCs;
   - the surface-set discovery rule — run `docs-update` without `--surface`
     first and read the required set from the `MISSING_SURFACE_EVALUATION`
     finding rather than guessing;
   - use an aggregate query for probe counts rather than counting by hand — two
     manual counts disagreed with each other and both were wrong;
   - `git check-ignore -v` prints a negation rule as the matching line; the exit
     code is the authority.
5. Run `harness.py render memory-index` twice and confirm identical output
   listing every entry.

### Exit criteria

- Harness suite passes at its new count; the delta is stated.
- Each assertion has a named red-before demonstration.
- `MEMORY.md` is tracked and every entry conforms to `SPEC.md` §4.2.
- The `docs-update` receipt for this change records `memory: UPDATED`.

### Risks

Seeding from the frozen corpus rather than from evidence would import narration.
Mitigation: every seeded entry names its probe or commit in `Verified-at`; an
entry that cannot be traced is not seeded.

## 5. Phase 2 — One closing routine

### Objective

Collapse `session-update` and `memory-update` into a single routine whose
canonical text is tracked here and which every runtime can reach.

### Scope

```text
.harness/session-close.md              (new, canonical)
.claude/skills/session-close/SKILL.md  (thin wrapper, local)
.agents/skills/session-close           (symlink; layout per phase 0 probe)
.claude/skills/memory-update/          (retired)
AGENTS.md, .harness/README.md          (routing rows)
```

Retiring the ZCode-global `session-update` edits a file outside this repository
and belongs to phase 4's authorisation boundary. Until then it is marked
superseded in place.

### Steps

1. Write `.harness/session-close.md` as the canonical procedure: survey, route,
   write, verify. The routing table names canonical memory, the rotating
   handoff, `references/`/`patterns/`, and "nothing" as legitimate destinations.
2. State explicitly that step 4 invokes the existing `docs-update` engine and
   that the routine never bypasses, wraps, or reimplements a gate.
3. Create runtime wrappers per the phase 0 discovery result. Each wrapper is a
   pointer; no policy text is duplicated into it.
4. Retire `memory-update`.
5. Add the routing row to `AGENTS.md` task routing and `.harness/README.md`.

### Exit criteria

- One routine is discoverable from every runtime path identified in phase 0, or
  the gap is recorded with the runtime named.
- No routine other than `session-close` instructs an agent to write durable
  memory.
- The `docs-update` receipt records `harness_contract: UPDATED`.

### Risks

A runtime whose discovery path was `INCONCLUSIVE` in phase 0 will not find the
routine. Mitigation: that runtime's SessionEnd hook (phase 4) names the canonical
path directly, so the routine stays reachable by instruction.

## 6. Phase 3 — Rotating handoff and the two signals

### Objective

Give Fast-mode sessions a tracked continuity slot, retire `.remember`, and add
the two warning signals the `memory` surface can honestly support.

### Scope

```text
.harness/handoff.md                (new, tracked)
.remember/                         (retired)
.harness/bin/harness.py            (two WARNING findings in evaluate_docs_update)
tests/harness/test_docs_update.py  (new cases)
AGENTS.md                          ("Start here" row)
```

### Steps

1. Create `.harness/handoff.md` carrying the most recent layer migrated from
   `.remember/remember.md`; the two older layers stay in the archive.
2. Add the reading step to the `AGENTS.md` "Start here" list, so the handoff has
   a systematic reader — the property `.remember` never had.
3. Retire `.remember/`, leaving `.gitignore:76` in place so a stray recreation
   stays untracked.
4. Implement **Signal A** (`SPEC.md` §6.2): at `final`, when the change set adds
   a `.harness/decisions/` record and `memory` is attested `NO_CHANGE_REQUIRED`,
   emit a `WARNING`.
5. Implement **Signal B**: when a changed path matches an entry's `Applies-to`
   and that entry's `Verified-at` did not change in the same change set, emit a
   `WARNING` naming the entry. Reuse the existing `changed_paths` routing.
6. Assert in tests that both signals leave the verdict at `PASS`. This is the
   single most important assertion in the phase: the mechanism must not become a
   blocker by accident.

### Exit criteria

- `.harness/handoff.md` is tracked and referenced from `AGENTS.md`.
- Each signal fires on a constructed fixture and is absent otherwise, with both
  cases tested.
- Verdict semantics are unchanged: all 15 existing `test_docs_update.py` cases
  pass unmodified.

### Risks

Adding findings to a shipped gate risks changing verdicts. Mitigation: both are
`WARNING`, and `evaluate_docs_update` computes `FAIL` only from `ERROR` entries.
Signal B additionally risks noise if `Applies-to` is written too broadly; if it
proves noisy, narrow the field convention rather than removing the signal, and
report the observation.

## 7. Phase 4 — Triggers (requires separate authorisation)

### Objective

Make the closing routine fire without the agent volunteering. This phase
addresses the root cause; the August write collapse is what it fixes.

### Authorisation boundary

Owner authorisation was given on 2026-09-04, with the condition that execution is
file-by-file and each file is archived before editing. Files outside this
repository: `~/.local/bin/docs-checkpoint`, `~/.zcode/skills/docs-update/SKILL.md`,
`~/.zcode/skills/session-update/`, `~/.codex/hooks.json`, `~/.codex/memories/`.
They are shared with other projects.

`core.hooksPath` stays unset and `.git/hooks/pre-commit` is not touched.

### Scope

```text
.claude/settings.json                   (SessionEnd entry)
.zcode/config.json                      (SessionEnd entry)
~/.codex/hooks.json                     (SessionEnd entry)
~/.local/bin/docs-checkpoint            (third project family)
~/.zcode/skills/docs-update/SKILL.md    (third project family)
~/.zcode/skills/session-update/         (retired)
```

### Steps

1. Archive each global file before editing it.
2. Extend the `docs-checkpoint` scope gate with a third family: a repository
   containing `.harness/contract.md`. Preserve the existing two families exactly;
   this script is installed globally and other repositories depend on it.
3. Extend the global ZCode `docs-update` skill's convention detection with the
   same family, mapping the harness roles per `SPEC.md` §6.1.
4. Add a warning-only `SessionEnd` hook to each of the three runtime configs,
   invoking `docs-checkpoint --mode session` and naming `session-close`.
5. Retire the ZCode-global `session-update`.
6. **Observe each hook firing.** A configuration entry is not evidence. Exercise
   each runtime and capture its output.
7. Confirm the hook stays silent when there is no debt, and that its HEAD-based
   deduplication prevents repeat warnings within a session.

### Exit criteria

- `docs-checkpoint` produces output in this repository where the baseline
  produced silence, and still exits silently in a repository matching neither
  pre-existing family — verified by running it in one such repository.
- Each of the three runtimes has an observed firing, or is named `INCONCLUSIVE`
  with the reason.
- No hook blocks any operation, verified by performing an ordinary edit and
  commit with hooks active.
- The `.zcode` hook set remains within its existing warning-only contract.

### Risks

A global script regression would affect every repository on this machine.
Mitigation: the change is additive, the pre-existing families are covered by a
before/after probe in at least one other repository, and every file is archived
before editing.

## 8. Phase 5 — Runtime pointer stubs

### Objective

Stop two of three runtimes from injecting pre-harness discipline into every
session. Cheapest change in the plan and, with phase 1, the highest value.

### Scope

```text
~/.claude/projects/-home-melik-egesut-erp1/memory/   (index reduced to stub)
~/.zcode/cli/memories/projects/egesut-erp1-*/        (index reduced to stub)
~/.codex/memories/memory_summary.md                  (project section only)
```

### Steps

1. Confirm the phase 0 export covers all three stores before reducing anything.
2. Replace each index with a stub naming `.harness/memory/MEMORY.md` as
   canonical, `.harness/handoff.md` as current state, and `.harness/contract.md`
   as governance. The stub holds no repository facts.
3. In the Codex `memory_summary.md`, preserve the user-profile section verbatim;
   replace only the project-discipline text naming `BOARD/ROADMAP/HANDOFF`.
4. Archive the individual note files; do not delete them in this phase.
5. Verify by starting one session per runtime and confirming the injected context
   names the harness rather than the retired conventions.

### Exit criteria

- Each index is a stub containing no repository facts.
- The Codex user profile is unchanged apart from the project-discipline section.
- A fresh session in each runtime demonstrably reaches
  `.harness/memory/MEMORY.md`.

### Risks

Reducing an index before phase 1 populates the store would leave a runtime with
nothing. Mitigation: §2.1 ordering; this phase is blocked on phase 1's exit
criteria.

## 9. Phase 6 — Historical consolidation

### Objective

Adjudicate the frozen corpus down to entries satisfying `SPEC.md` §4.1, and
archive the rest.

### Scope

```text
.harness/memory/MEMORY.md                            (entries appended)
.harness/memory/*.md                                 (linked documents, if any)
.claude/archive/memory-consolidation-2026-09-XX/     (export and triage record)
```

### Steps

1. Apply the `SPEC.md` §7.2 mechanical stages in order. Each stage records its
   input count, rule, and output count, so the funnel is auditable rather than
   asserted.
2. Deduplicate survivors using the local embedding index, once, as a merge tool.
   This is the last operational use of store 3.
3. Triage survivors against §4.1. Record per candidate: keep,
   already-represented (naming the artefact), or archive-only.
4. Append kept entries to `MEMORY.md` with sequential numbers. There is no cap;
   the admission rule is the only filter.
5. Write the triage record into the archive so a future session can see why an
   entry was rejected without re-reading the corpus.

### Exit criteria

- Every stage's counts are recorded and reconcile with the export.
- Every canonical entry traces to a source record or is marked as new.
- The suite passes and the index lists every entry.
- No historical store was deleted.

### Risks

Triage is judgement work and can silently drop a valuable lesson. Mitigation:
rejection is recorded with a reason, and nothing is deleted, so any rejection is
reversible from the archive.

## 10. Phase 7 — Document the Supabase table

### Objective

Close the open question about `memory_notes` and remove the need for any future
schema audit to re-investigate it. **This phase does not drop the table.**

The owner decided on 2026-09-04 to keep it: it is inert, nothing reads it, and
one of its 275 rows is still unaccounted for (`SPEC.md` §7.2.1).

### Scope

```text
.harness/memory/MEMORY.md    (one entry)
```

### Steps

1. Take the phase 0 comparison result. If the unaccounted row was identified,
   state whether its content exists in store 3 under a different timestamp.
2. If phase 0 was inconclusive, re-run the comparison using the `+00:00`
   migration marker and report the method and outcome.
3. Add one canonical entry recording: the table lives in the demo Supabase
   project, it is a frozen historical agent-memory store with writes ending
   2026-07-04, 274 of 275 rows are also in the local store, it is not a product
   table, and nothing in the application references it. `Applies-to` names the
   schema-audit flow so a future audit finds it.
4. Verify that no application code references the table, rather than assuming it.
   `memory_notes` is agent infrastructure; its absence from the product surface
   must be shown.

### Exit criteria

- The entry exists and states the unaccounted row's status honestly, including
  `INCONCLUSIVE` if that is the outcome.
- No DB mutation occurred.
- The verification in step 4 is recorded with its command.

### Optional follow-on (separate owner approval, not part of this plan)

Dropping the table. Preconditions if it is ever requested: the archive holds a
full export, duplication is re-verified at execution time rather than relied upon
from this document, and the drop goes through the authorised migration path. The
owner has not requested it.

## 11. Verification summary

| Phase | Primary evidence | Reversal |
|---|---|---|
| 0 | export counts reconcile; probes answered or marked inconclusive | delete export; nothing else changed |
| 1 | suite at new count; red-before per assertion; index stable across runs | delete `MEMORY.md`, the test, and revert the renderer |
| 2 | routine discoverable per runtime probe | restore prior skills from archive |
| 3 | both signals fire and are absent, both tested; 15 existing cases unmodified | revert the findings; restore `.remember` from archive |
| 4 | observed hook firing per runtime; global script probed in a second repository | remove hook entries; restore scripts from archive |
| 5 | fresh session per runtime reaches `.harness/memory/MEMORY.md` | restore indexes from archive |
| 6 | funnel counts reconcile; triage record complete | delete entries; Git history retains them |
| 7 | entry exists; no DB mutation; step 4 command recorded | delete the entry |

## 12. What this plan does not measure

- Whether an entry is *good*. No mechanism here judges content quality; that is
  a review responsibility, stated as an accepted residual limit in `SPEC.md` §6.2.
- Whether an agent reads `.harness/memory/MEMORY.md` when it matters. Injection
  is verifiable; attention is not.
- Whether Signal B's `Applies-to` matching produces useful precision in practice.
  It is the first mechanism of its kind here; report what it actually does during
  phase 3 rather than assuming the design holds.
