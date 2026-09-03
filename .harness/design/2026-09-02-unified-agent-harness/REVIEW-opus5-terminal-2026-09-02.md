# Independent Review — EgeSüt Unified Agent Harness

| Field | Value |
|---|---|
| Reviewer id | `opus5-terminal` |
| Model | Claude Opus 5 (`claude-opus-5`), Claude Code terminal session |
| Date | 2026-09-02 |
| Repo | `/home/melik/egesut-erp1` |
| `git rev-parse --short HEAD` | `e8cd620` |
| `git status --porcelain \| wc -l` **before** | `46` |
| `git status --porcelain \| wc -l` **after** | `46` (this file lands inside the already-untracked `.harness/` entry) |
| Writes performed | exactly one: this file |

## Baseline drift observed during the review

Re-measured after writing this file. `git status --porcelain | wc -l` is unchanged at `46`,
`core.hooksPath` is still unset, and `HEAD` is still `e8cd620`. One input **did** change
under the review, through no action of this session (which performed no Git mutation):

| Fact | At review start | At review end |
|---|---|---|
| `git worktree list` | 3 worktrees (`main`, `idle/planli-asi-stok2`, `idle/sut-buzagi-tablosu`) | **6** worktrees — `idle/aktif-hastalik-filtre`, `idle/suruden-cikan-filtre`, `idle/sutten-kes-liste` added; `idle/sut-buzagi-tablosu` moved `e8cd620 → d1de3e8` |

Reported as instructed ("treat any surprise as a finding"). It does not weaken any finding —
it strengthens two. Evidence row **E17** understates concurrency: five concurrent `idle/*`
worktrees is the live state, not three, which makes **F3** (tracked generated views conflict
on every concurrent pair) and **H2** more severe, and makes **A7**'s point — that `idle/*`
worktree creation is this repository's *routine* unit of work, not a Full-goal trigger —
directly observable rather than inferred.

## Files read

Design documents under review:

- `.harness/design/2026-09-02-unified-agent-harness/SPEC.md` (685 lines, full)
- `.harness/design/2026-09-02-unified-agent-harness/IMPLEMENTATION-PLAN.md` (456 lines, full)
- `.harness/design/2026-09-02-unified-agent-harness/REVIEW-OF-REVIEW-PROMPT-2026-09-02.md` (lines 1–90, 388–440; context only, not edited)

Repository files read for evidence:

- `AGENTS.md` (headings; lines 51, 102–120, 568–577)
- `CLAUDE.md` (headings; lines 306–313, 347)
- `.gitignore` (full grep; lines 33–34, 52, 88–89, 104, 133–136)
- `package.json` (`scripts`)
- `.git/hooks/pre-commit` (lines 1–40 verbatim, 40–184 by grep)
- `.zcode/config.json` (lines 1–40)
- `.zcode/hooks/session_contract.py` (full), `.zcode/hooks/commit_guard.py` (by grep), `.zcode/hooks/js_edit_guard.py` (line count only)
- `js/utils/modal.js` (line 4)
- `.claude/goals/2026-08-30-gA-abort-vwp-penceresi.md` (lines 1–20)
- Directory/metadata listings only: `.claude/`, `.agents/`, `.qwen/`, `.zcode/`, `.openclaude/`, `.commandcode/`, `.mimosa/`, `.gitnexus/`, `tests/`, `tests/unit/`, `supabase/migrations/`, `docs/`, `.github/workflows/`, `/home/melik/egesut-wt/planli-asi`, `/home/melik/egesut-wt/sut-buzagi-tablosu`

No file was modified. No worker, worktree, package, migration, provider, or database was touched. No index was rebuilt.

---
## 1. Verdict and owner decisions

### Verdict: `ACCEPT_WITH_CHANGES`

The architecture is sound and the acceptance model is the right one for a production ERP.
Two critical findings are open, so `ACCEPT` is unavailable; nothing in the design violates a
process invariant and no owner decision is `UNIMPLEMENTABLE`, so `REJECT` is not warranted.

**Five reasons.**

1. **The design's core is correct and better than current practice.** Acceptance computed
   from Git, tests, and documentation evidence rather than from a worker's self-report
   (SPEC 3.2, 9, 10, 15.3), and four separated gates for commit/push/deploy/live-DB (15.4,
   15.5), are exactly the right invariants for this repository. Current live policy says the
   opposite — `CLAUDE.md:347`: "**İş bitince commit + push**: Bir görev tamamlandığında
   otomatik olarak commit oluştur ve `git push origin main` yap. Kullanıcıdan onay bekleme."
   The SPEC's position is a genuine improvement, not ceremony.

2. **The problem statement is verified, not assumed.** SPEC 1 claims overlapping surfaces
   that "disagree about schema facts". They do: `AGENTS.md:51` asserts the tracked ground
   truth is "canlı kanonik (EgeSüt) ile birebir … 41 tablo · 12 view · 165 fn ✓" while
   `CLAUDE.md:307` records the live schema as "**50 tablo / 175 fonksiyon (169 + 6 vector
   ext) / 12 view**", and an in-use goal file warns readers off the tracked copy outright
   (E19, E20). ~45 lines of policy are duplicated byte-for-byte across both root files (E18).

3. **Two critical defects are open, both mechanical and both cheap to fix.** `AGENTS.md` and
   `CLAUDE.md` are gitignored and absent from every linked worktree (F1, E5, E6), which makes
   the entire runtime-discovery half of the design unachievable as planned. And the proposed
   `core.hooksPath` bootstrap would silently disable an existing, active, blocking
   `.git/hooks/pre-commit` that no document mentions (F2, E11, E12). Neither requires a
   redesign; both must land before any other phase.

4. **The design carries roughly a third more documentation ceremony than its own named
   failures justify.** Five of eight checkpoint kinds read no diff, and two (`progress`,
   `blocked`) prevent no failure that a state transition and a generator do not already
   cover (4.2, 6.1). Tracking four whole-repository generated views guarantees a merge
   conflict for every concurrent Full-goal pair in a repository whose normal working mode is
   concurrent `idle/*` worktrees (F3, E17).

5. **The pre-review revisions are a net improvement, but two of the three unpiloted
   mechanisms have defects.** Revision #1 (planes) is the best change in the set and already
   catches real errors. Revision #5 (hook enrichment) is correctly reasoned and unsafely
   bootstrapped (F2). Revision #6 (staleness anchors) is inoperative here: the lexically last
   migration is a permanent `99999999999999_ground_truth.sql` sentinel, so `migration_head`
   can never move, and a migration-tree anchor structurally cannot observe live-schema drift —
   the only kind of staleness that has actually occurred (F4, E26, E19).

### Owner decisions

Seven of the eight settled decisions carry a finding. `D4` (Herdr as an explicitly selected
terminal surface) is accepted without cost: it costs one adapter file and nothing depends
on it.

| # | Decision | Verdict | Finding |
|---|---|---|---|
| D1 | The harness is repository-local | `COST_NOTED` | Correct, and the cost is a duplication window. `.claude/` already holds the live governance system — 9 goals, 12 tasks, 3 architecture decisions, 8 knowledge notes, 11 **tracked** idle-reports (E23) — and PLAN 11 correctly defers retirement until after the pilots. So the repository runs two goal trees, two report trees, and two decision trees for the whole rollout. This is the right sequencing; the cost should be budgeted, and mitigated by migrating `.claude/goals/` and `.claude/idle-reports/` in Phase 2 rather than Phase 6 (A1). |
| D2 | No orchestration runtime is mandatory | `COST_NOTED` | Correct and consistently implemented — no acceptance criterion, check, or exit criterion in either document depends on a named external runtime (5.2). The cost lands on the operator: with no runtime to ask "did it pass", every acceptance is a root re-derivation from diff, tests, and docs. Combined with D7, this is the largest recurring cost in the design, ~4–6 operator prompts per Full goal (4.1). |
| D3 | ZCode Desktop uses its built-in agents by default | **`TENSION`** with **D1** → `DECISION_NEEDED` | ZCode's actual contract-discovery surface is not a document. `.zcode/config.json` runs `python3 ${ZCODE_PROJECT_DIR}/.zcode/hooks/session_contract.py` at `SessionStart`, and that script hard-codes a five-rule "[EgeSüt proje kontratı — AGENTS.md özet]" string (E24). `.zcode/` is untracked and **absent from both live worktrees** (E3, E6). A repository-local harness (D1) therefore cannot reach ZCode's default agents (D3) as things stand. **Both options, for the owner:** (a) track `.zcode/` after a secret scan, accepting a runtime-specific directory in Git; or (b) rewrite `session_contract.py` to read `.harness/contract.md` from disk instead of embedding a copy, so the tracked harness becomes its source. Option (b) also fixes the SPEC 5.5 adapter-thinness violation (5.3(3)) and is the recommendation. |
| D5 | Root and lead work does not require a goal for every small action | **`TENSION`** with **D8** → `DECISION_NEEDED` | Presented together with D8 below. Separately, D5 is right and matches how the repository works (E17), but SPEC 8.2 partly defeats it: "a worktree is created" is a Full trigger, and `idle/*` worktrees are this repository's *routine* unit of work (`AGENTS.md:110`, three live now). Recommend recalibrating the trigger to independent write ownership by a non-root actor (A7, roadmap rank 7). |
| D6 | A lead writes only within its goal's declared product and docs authority | **`TENSION`** with **D1** → `DECISION_NEEDED` | Implementable in-repo, not implementable repo-locally in full. Three live write channels escape a staged-path check: 255 of 277 `.claude/` files plus both root instruction files are ignored (E2, E5), agent memory is written outside the repository entirely, and live DB mutations have no path at all (F5, H4). The in-repo half is fixable and cheap (roadmap ranks 1 and 6). The out-of-repo half is structurally beyond a repository-local harness. **Owner choice:** either declare out-of-repo surfaces in the goal and accept attestation rather than verification for them, or state plainly in `contract.md` that D6 governs in-repository writes only. Silence is the one option that should be ruled out, because it makes an unenforceable rule look enforced. |
| D7 | Worker `PASS` is not root acceptance | `COST_NOTED` | The best-implemented decision in the document: SPEC 9 (workers cannot set `DONE`), 10 ("`DONE` is not inferred from a clean branch or green worker report"), 15.3, and 3.2 all enforce it, and 7.5 keeps the verifier out of product repair. Cost: root re-derives every acceptance (see D2), and the verifier is a separate role that, under single-operator use, is one person entering a mode (A8). Keep the constraint; drop the separate identity. |
| D8 | Docs-update is a root/lead checkpoint responsibility | **`TENSION`** with **D5** → `DECISION_NEEDED` | D8 requires a structured docs verdict at every checkpoint, including `pre-commit` on Fast root work (15.1). D5 removes the artefact that holds it: `checkpoint.docs_verdict` is *goal* frontmatter (SPEC 9), and Fast work has no goal. So a Fast docs verdict has no canonical home — it can only live in the ephemeral receipt, which by design must not outlive its HEAD, making it unqueryable and quietly weakening D8 for the majority of commits. **Resolution the documents already support:** SPEC 15.2.1 forbids a `Docs-Update` trailer *unless* a current receipt matches the commit's HEAD and diff hash — so permit exactly that trailer on Fast commits, making the commit itself the canonical record. This satisfies both decisions with a mechanism already specified, and needs only an owner ruling that a verdict trailer is acceptable on ad-hoc commits. |

**Threshold check.** No `UNIMPLEMENTABLE` verdicts (0 of 8; `REJECT` requires ≥2). The design
does not itself violate a process invariant: SPEC 12.4 explicitly subordinates every generated
summary to live schema verification, and every phase's acceptance requires the dirty tree to be
preserved. Two critical findings remain open (F1, F2), which rules out `ACCEPT`.

---

## 2. Evidence

### 2.1 PASS 1 — mechanical evidence table

Every row is a claim taken from `SPEC.md`, `IMPLEMENTATION-PLAN.md`, or the review
prompt's baseline block, checked against the live repository at `e8cd620`.

| # | Claim | Source | Status | Evidence (command → first relevant output line, or `path:line`) |
|---|---|---|---|---|
| E1 | `.harness/` is untracked (0 tracked files) | PLAN 1.1 | TRUE | `git ls-files .harness \| wc -l` → `0` |
| E2 | `.claude/` is partly tracked, 23 files | PLAN 1.1 | TRUE | `git ls-files .claude \| wc -l` → `23`; on-disk `find .claude -type f \| wc -l` → `277` (8 %) |
| E3 | `.agents/`, `.qwen/`, `.zcode/` are untracked (0) | PLAN 1.1 | TRUE (incomplete) | `git ls-files .agents .qwen .zcode \| wc -l` → `0`. But `.agents/` and `.qwen/` are **ignored**, not merely untracked: `.gitignore:104` `.agents/`, `.gitignore:52` `.qwen/`, `.gitignore:135-136` repeats both. All three exist on disk (39 / 3 / 4 files). |
| E4 | Root instruction volume 577 / 422 | PLAN 1.1 | TRUE | `wc -l AGENTS.md CLAUDE.md` → `577 AGENTS.md`, `422 CLAUDE.md` |
| E5 | **`AGENTS.md` and `CLAUDE.md` are gitignored and untracked** | *asserted by neither document* | TRUE | `git ls-files AGENTS.md CLAUDE.md \| wc -l` → `0`; `git check-ignore -v AGENTS.md CLAUDE.md` → `.gitignore:133  AGENTS.md` / `.gitignore:134  CLAUDE.md` |
| E6 | Both root instruction files are absent in every linked worktree | *asserted by neither document* | TRUE | `ls -a /home/melik/egesut-wt/sut-buzagi-tablosu` → no `AGENTS.md`, no `CLAUDE.md`, no `.zcode`, no `.agents`; `.claude` present |
| E7 | `tests/harness/` does not exist | PLAN 1.1 (“`ls tests/` → absent”) | TRUE (mis-worded) | `ls -d tests/harness` → `tests/harness MISSING`. `tests/` itself exists with 13 entries incl. `unit/`, `sql/`, `support/`, 7 `*.spec.js`. The PLAN row’s value “absent” reads as if `tests/` were absent. |
| E8 | Working tree dirty, ~46 entries | PLAN 1.1 | TRUE | `git status --porcelain \| wc -l` → `46` (2 modified tracked: `.claude/domain-rules.md`, `.claude/rpc-reference.md`; 44 untracked) |
| E9 | `core.hooksPath` is unset today | SPEC 15.2.1 / prompt baseline | TRUE | `git config --get core.hooksPath` → `(unset)`; `git config --get extensions.worktreeConfig` → `UNSET` (so repo config is shared with linked worktrees) |
| E10 | `.harness/bin/` does not exist | prompt baseline | TRUE | `ls .harness/bin/` → `(no .harness/bin)`; `find .harness -type f` → only the 4 design `.md` files |
| E11 | **An active blocking `.git/hooks/pre-commit` already exists** | *asserted by neither document* | TRUE | `ls .git/hooks/ \| grep -v sample` → `pre-commit`; `.git/hooks/pre-commit:2` → `// shazam pre-commit hook - auto-installed by pi-shazam`; mode `-rwxr-xr-x`, 184 lines; grep shows `process.exit(1)` on `"FAIL: " + errors + " check(s) failed."` |
| E12 | That hook skips non-main branches | *new* | TRUE | `.git/hooks/pre-commit` → `log("Skipping pre-commit verification on branch '" + branch + "' (only runs on main/master)."); process.exit(0);` |
| E13 | `js/utils/modal.js:openM` exists (SPEC 11 example) | SPEC 11 | TRUE | `js/utils/modal.js:4` → `function openM(id) {` |
| E14 | `npm run test:unit` exists | PLAN 12 | TRUE | `package.json` scripts → `test:unit = node --test tests/unit/*.test.js` (23 entries in `tests/unit/`) |
| E15 | `tests/modal-router.spec.js` exists | PLAN 12 | TRUE | `ls tests/` → `modal-router.spec.js` |
| E16 | `python3 .harness/bin/harness.py validate` is not currently runnable | PLAN 12 (self-declared) | TRUE | see E10 |
| E17 | Three worktrees are live; `idle/*` branch convention is real | PLAN 1 | TRUE | `git worktree list` → `/home/melik/egesut-erp1 e8cd620 [main]`, `/home/melik/egesut-wt/planli-asi 3a892a6 [idle/planli-asi-stok2]`, `/home/melik/egesut-wt/sut-buzagi-tablosu e8cd620 [idle/sut-buzagi-tablosu]`; `AGENTS.md:110` → “`main` dışında branch — YASAK (**istisna:** `idle/*` worktree branch'leri … idle görevler worktree'de yazar, sabah review'unda main'e merge edilir)” |
| E18 | Root files duplicate ~45 lines of identical policy | SPEC 1, SPEC 5.2 | TRUE | `diff <(sed -n '444,489p' AGENTS.md) <(sed -n '365,409p' CLAUDE.md)` → single-line delta (`45d44 < ---`). Same “GitNexus — Code Intelligence / Always Do / Never Do / Resources / CLI” block in both. `Çalışma Ortamı — Shell & Terminal (2026-07-04 tespit)` also duplicated (`AGENTS.md:572`, `CLAUDE.md:410`). |
| E19 | Root files carry contradictory schema facts | SPEC 1, SPEC 12.4 | TRUE | `AGENTS.md:51` → “ground_truth … canlı kanonik (EgeSüt) ile birebir … 41 tablo · 12 view · 165 fn ✓”; `CLAUDE.md:307` → “Gerçek şema canlı Supabase (bugün **50 tablo / 175 fonksiyon (169 + 6 vector ext) / 12 view**) … ground_truth.sql artık eşit.” 41 ≠ 50, 165 ≠ 175, in files that both claim equality. |
| E20 | A live goal record contradicts the tracked ground truth | *new* | TRUE | `.claude/goals/2026-08-30-gA-abort-vwp-penceresi.md:12` → “`.claude/goals/assets/tohumlama_kaydet_canli.sql` — **canlı prod gövdesi** (172 satır). Bu dosya gerçekliktir; `ground_truth.sql`'deki kopya BAYATTIR, ona bakma.” |
| E21 | Current push policy contradicts SPEC 15.4 | SPEC 15.4 | TRUE | `CLAUDE.md:347` → “**İş bitince commit + push**: Bir görev tamamlandığında otomatik olarak commit oluştur ve `git push origin main` yap. Kullanıcıdan onay bekleme.” vs SPEC 15.4 “Push is root-only by default and occurs only after accepted integration, clean status, final docs verdict, and final acceptance.” |
| E22 | Editing `CLAUDE.md` is currently forbidden to non-Claude agents | PLAN 4 write manifest | TRUE | `AGENTS.md:111` → “**CLAUDE.md değiştirme — YASAK** (kullanıcı söylemedikçe OMP dokunamaz; Claude Code'un dosyası)”. Phase 1’s manifest lists `CLAUDE.md`. |
| E23 | A goal convention already exists and is in active use | *asserted by neither document* | TRUE | `.claude/goals/` → 9 files, e.g. `2026-08-30-gA-abort-vwp-penceresi.md:1-5` → “# Goal A — … **Tip:** backend RPC (migration) + frontend form · **Hat:** external worker + izole worktree / **Öncelik:** P1 · **Sahip:** glmf worker W1”. Also `.claude/tasks/` 12, `.claude/reviews/` 2, `.claude/arch-decisions/` 3, `.claude/knowledge/` 8, `.claude/idle-reports/` (11 of them **tracked**). |
| E24 | ZCode’s real discovery surface is an untracked hook, not a document | SPEC 5.3, 5.5 | TRUE | `.zcode/config.json` → `SessionStart` runs `python3 ${ZCODE_PROJECT_DIR}/.zcode/hooks/session_contract.py`; that script hard-codes a 5-rule “[EgeSüt proje kontratı — AGENTS.md özet]” string. `.zcode/` is untracked (E3) and absent in both worktrees (E6). |
| E25 | ZCode already carries Git policy in an “adapter” | SPEC 5.5 | TRUE | `.zcode/hooks/commit_guard.py:2-3` → “ZCode uyarı hook'u — `git commit` içeren Bash çağrısında kontrol listesi basar. Non-blocking: her zaman exit 0 (asla bloklamaz — Mimosa L3 dersi)” |
| E26 | Migration tree cannot supply a moving `migration_head` anchor | SPEC 12.4 | TRUE | `ls supabase/migrations/*.sql \| wc -l` → `247`; `ls supabase/migrations/ \| tail -3` → `20260902000004_asi_toplu_gorev.sql`, `99999999999999_ground_truth.sql`, `backup`. The lexically last filename is the permanent `99999999999999_` sentinel plus a `backup/` directory. |
| E27 | GitNexus index is stale relative to HEAD | CLAUDE.md “Always Do”, prompt | TRUE | `ls -la .gitnexus/` → `meta.json` and `lbug` dated `Ağu 31 18:58`; `git log -6 --date=iso` → six commits on `2026-09-02` up to `09:45:40`. CLAUDE.md mandates `impact()` before editing any symbol against this index. |
| E28 | 40 files still hard-code `/root/egesut-erp1` | PLAN 9 work item 5 | TRUE | `grep -rl "/root/egesut-erp1" --exclude-dir=.git .` → `40` files, all under `.claude/` (mostly `.claude/archive/`), none tracked |
| E29 | Surfaces present on disk that Phase 0’s read scope omits | PLAN 3 read scope | TRUE | `.commandcode/` (5 files, `taste/{coding,workflow,tooling,communication}/taste.md`) and `.mimosa/` (2 hook-state session files) exist; PLAN 3 lists only `.claude/`, `.agents/`, `.zcode/`, `.qwen/`, `.openclaude/` |
| E30 | A malformed filename is tracked in Git | *new* | TRUE | `git ls-files \| grep WATCHDOG` → `"\"$WATCHDOG_PID_FILE\""` (a shell-quoting accident committed at repo root; 375 tracked files total) |
| E31 | Tracked product documentation exists outside SPEC 4’s tree | SPEC 4, SPEC 12.5 | TRUE | `git ls-files '*.md'` → `ARCHITECTURE.md`, `DESIGN.md`, `README.md`, `README.tr.md`, `demo/README.md`, plus `git ls-files docs \| wc -l` → `8`. None appear in SPEC 4’s target layout or in 12.5’s diff-routing table. |
| E32 | `.harness/` is trackable (not ignored) | SPEC 4 | TRUE | `git check-ignore -v .harness …` → `NOT ignored (trackable)` |
| E33 | Hook inheritance in linked worktrees is untested here | PLAN 10 (self-declared) | UNVERIFIABLE (read-only) | `git --version` → `git version 2.55.0`; `extensions.worktreeConfig` unset (E9) so the *config value* is shared, but whether a **relative** `core.hooksPath` resolves to each worktree’s own root cannot be established without creating a commit. Labelled `HYPOTHESIS` throughout this review, matching PLAN 10. |
| E34 | Any external runtime (goose/codex/omp/pi/herdr) is currently active | `CLAUDE.md`, `AGENTS.md` at length | UNVERIFIABLE | No live probe performed; read-only constraint forbids starting workers. Per `<PLANES>`, every such claim is treated as documentation, not proof. No finding in this review rests on one. |

### 2.2 Cross-document check 1 — layout coverage

`SPEC.md` 4 tree × the `IMPLEMENTATION-PLAN.md` phase whose write manifest creates it.

| SPEC 4 path | Creating phase | Verdict |
|---|---|---|
| `AGENTS.md`, `CLAUDE.md` | Phase 1 | **DEFECT** — both are gitignored (E5). Phase 1 lists them in its manifest but explicitly defers `.gitignore` (“`.gitignore` changes require explicit review”). No phase’s manifest contains `.gitignore`. |
| `.harness/README.md`, `contract.md`, `flow-routing.md`, `acceptance.md`, `task-modes.md` | Phase 1 | OK |
| `.harness/docs-update.md` | Phase 3 | OK |
| `.harness/patterns/*` (6 files) | Phase 4 | OK |
| `.harness/references/*` (4 files) | Phase 4 | OK |
| `.harness/runtimes/*` (4 files) | Phase 1 | OK — revision #2 closed this gap |
| `.harness/githooks/prepare-commit-msg` | **none** | **DEFECT** — Phase 5 work item 3 describes building it but Phase 5 has **no write manifest at all** |
| `.harness/goals/YYYY/`, `reports/YYYY/`, `decisions/` | Phase 2 | OK — revision #3 closed `decisions/` |
| `.harness/memory/` | Phase 3 | OK (but see schema gap below) |
| `.harness/generated/GOAL-INDEX.md` | Phase 2 | OK |
| `.harness/generated/BOARD.md`, `HANDOFF.md`, `MEMORY-INDEX.md` | Phase 3 | OK |
| `.harness/schemas/{goal,report,decision}.schema.json` | Phase 2 | OK |
| `.harness/bin/harness.py` | Phase 2 (extended Phase 3) | OK |
| `.harness/cache/` (“ignored and rebuildable”) | Phase 2 work item 4 builds it; **no phase ignores it** | **DEFECT** — requires a `.gitignore` entry that no manifest creates |
| `tests/harness/` | Phases 1–3 | OK |

Reverse direction — plan manifest paths absent from SPEC 4:

| Plan path | Phase | Verdict |
|---|---|---|
| `tests/harness/test_*.py` (8 files) | 1–3 | OK — SPEC 4 lists `tests/harness/` generically |
| `tests/unit/*`, `tests/*.spec.js` | Phase 4 | OK — product-owned, correctly outside the harness tree |
| `.gitignore` | referenced in Phase 1 prose only | **DEFECT** — a required edit that is in no manifest and in no layout |

Canonical record types with no schema in `.harness/schemas/`:

| Canonical input | Declared canonical at | Schema | Verdict |
|---|---|---|---|
| goal | SPEC 9 | `goal.schema.json` | OK |
| report | SPEC 12.4 | `report.schema.json` | OK |
| decision | SPEC 12.6 | `decision.schema.json` | OK (revision #3) |
| **curated memory note** | SPEC 12.4 (“canonical inputs are … curated memory notes”), 12.7 | none | **DEFECT** — feeds generated `MEMORY-INDEX.md`; identical to the defect revision #3 fixed for `decisions/` |
| **pattern (`patterns/index.yaml`)** | SPEC 11; SPEC 14 checks “pattern IDs, source anchors” | none | **DEFECT** |
| **commit/docs receipt** | SPEC 15.2.1 (“a current receipt … whose recorded HEAD and diff hash match”), Phase 3 work item 6 | none; also **no location in SPEC 4** | **DEFECT (highest of the three)** — the receipt is the sole mechanism preventing a fabricated `Docs-Update: PASS`, and it has no format, no schema, and no home in the layout |

### 2.3 Cross-document check 2 — dependency order

`IMPLEMENTATION-PLAN.md` 2.1 claims backward dependencies are resolved and states one
known instance. Verification:

| Phase | Artifact it validates | Defined in | Verdict |
|---|---|---|---|
| 2 | `checkpoint.docs_verdict` enum | SPEC 12.1 (spec-normative) | **RESOLVED** — and correctly declared in Phase 2 exit criteria (“Validated but not created by this phase”) |
| 3 | same enum | SPEC 12.1 | **RESOLVED** — Phase 3 work item 1 says “do not redefine it here”, but Phase 3’s exit criteria do **not** carry the declaration that 2.1 requires of every phase |
| 1 | “`orchestrator-master` is selected without explicit **flow metadata**” (red-before) | `flow:` is goal frontmatter, SPEC 9, implemented in **Phase 2** | **UNRESOLVED** — Phase 1 asserts a red-before test over a field no Phase-1 artifact contains, and its exit criteria do not declare it |
| 1 | “a worktree lacks the expected tracked harness” (red-before) | worktree contract + `test_worktree_contract.py` are **Phase 2** | **UNRESOLVED (weak)** — testable as bare file presence, but it is worktree-contract behaviour asserted a phase early |
| 2 | “Index ad-hoc root/lead commits without requiring a goal”, indexing `mode, flow, goal` (SPEC 13) | trailers are produced by the enrichment hook, **Phase 5** (SPEC 15.2.1) | **UNRESOLVED** — mitigated because SPEC 15.2.1 pins the trailer names, but 2.1 never names this instance, and Phase 2’s exit criterion (“A Fast inline commit … is queryable”) is only satisfiable at the degraded richness Phase 5 later improves |
| 5 | receipts (`Docs-Update`/`Tests` refusal test) | receipts are produced in **Phase 3** | OK — forward dependency |
| 0, 5, 6, 7 | — | — | **DEFECT** — these phases have no write manifest; PLAN 2 requires “exact changed-file scope” from *every* phase. Phases 5 and 6 additionally have no exit criteria. |

**Conclusion on 2.1:** the rule is stated correctly and applied to exactly one instance.
Two further backward dependencies exist (Phase 1 → flow metadata; Phase 2 → Phase 5
trailers), and the “each phase lists it in its exit criteria” obligation is honoured by
Phase 2 alone.

---
## 3. Critical findings

Severity order. Each carries an evidence anchor from 2.1–2.3 and a concrete correction.

### F1 — CRITICAL — The two files the whole discovery design rests on are gitignored `VERIFIED`

**Anchor:** E5, E6, E32.

`AGENTS.md` and `CLAUDE.md` are matched by `.gitignore:133` and `.gitignore:134`. They
are not tracked, and they are physically **absent** from both live linked worktrees.

This falsifies three load-bearing statements at once:

- SPEC 18 acceptance criterion 1 — “Codex/OMP load root `AGENTS.md`; Claude loads the same
  shared rules through `CLAUDE.md`” — cannot hold in a worktree today.
- Phase 1 exit criterion — “All four supported runtimes demonstrate the same contract
  version from root **and worktree**” — is unachievable by Phase 1’s manifest, because the
  manifest edits the files but the `.gitignore` change that would make them reach a
  worktree is explicitly deferred (“`.gitignore` changes require explicit review”) and
  appears in no phase manifest (2.2).
- PLAN 1.1’s framing of these files as “roughly 1000 lines of live policy … the largest
  single item in Phase 1” measures the right lines and misses the decisive property. The
  problem is not that the files are long. It is that they do not exist where agents work.

It also reframes the design’s own premise. SPEC 1 attributes drift to “overlapping
instruction and runtime surfaces”. The measured cause is narrower and cheaper: the
authoritative surfaces are ignored, so `git worktree add` produces a checkout with
`.claude/` (23 tracked files) and no root contract at all.

**Correction.** Promote `.gitignore` to a first-class Phase 1 deliverable with its own
manifest line and its own red-before test:

1. Remove lines 133–134; commit `AGENTS.md` and `CLAUDE.md` after a secret scan (they
   currently contain no credentials but do contain local absolute paths — E28 shows the
   pattern is common in this repo).
2. Add `.harness/cache/` to `.gitignore` in the same change (2.2 defect).
3. Red-before: create a scratch linked worktree in CI or a pilot and assert
   `test -f AGENTS.md && test -f .harness/contract.md` inside it. Phase 1 must fail
   without this.
4. Until 1 is done, no phase may claim any runtime-discovery exit criterion.

### F2 — CRITICAL — The enrichment bootstrap silently disables an existing active enforcement hook `VERIFIED`

**Anchor:** E11, E12, E9.

`.git/hooks/pre-commit` exists, is executable, is 184 lines, was installed by a third
party (`pi-shazam`), and **blocks**: it exits `1` after `"FAIL: " + errors + " check(s)
failed."`. `core.hooksPath` is currently unset, so it runs today.

`SPEC.md` 15.2.1 and Phase 5 work item 3 instruct `git config core.hooksPath
.harness/githooks`. Git’s `core.hooksPath` **replaces** the hook directory; it does not
add to it. Setting it stops `.git/hooks/pre-commit` from ever running again. Neither
document mentions that this hook exists.

This is the sharpest failure of the proposal’s own discipline. SPEC 14 draws a careful
line — “Metadata enrichment is a distinct category from enforcement” — and the line holds
in the text. It breaks in the bootstrap: installing the enrichment mechanism deletes an
enforcement mechanism, silently, with no error and no test.

Two aggravating details:

- The disabled hook is the only automated pre-commit verification in the repo, and it
  runs **only on main/master** (E12). Root inline Fast work on main is exactly the path
  that loses coverage.
- SPEC 13 rollback says “unset `core.hooksPath` to revert enrichment; commits stay valid
  and only query richness degrades.” That is true for enrichment and false for the repo:
  the round trip set → unset silently restores a hook that was silently removed, so
  neither direction is observable.

**Correction.**

1. Phase 0 inventory must enumerate `.git/hooks/*` (its read scope says “Git hooks/config”
   — the finding is that the inventory has not been run, not that the scope is wrong).
2. `.harness/githooks/` must ship a `pre-commit` dispatcher that execs the previous hook
   (path recorded at bootstrap) and preserves its exit code, or the bootstrap must refuse
   to run while `.git/hooks/` contains a non-sample hook and require an explicit owner
   decision.
3. `harness validate` must assert, alongside its existing `core.hooksPath` warning, that
   every hook that existed before bootstrap is still reachable. Red-before: a fixture with
   a stub `.git/hooks/pre-commit` that must still fire after bootstrap.

### F3 — HIGH — Tracked generated views create a guaranteed conflict class in a repo that already runs concurrent worktrees `VERIFIED`

**Anchor:** E17, SPEC 4 (tree), SPEC 14 (“stale generated views”), Phase 3 manifest.

`BOARD.md`, `HANDOFF.md`, `GOAL-INDEX.md`, and `MEMORY-INDEX.md` sit inside the tracked
tree, are checked for drift by `harness validate`, and are each a function of **all**
goals. Three worktrees are live right now and the `idle/*` convention is the repository’s
normal working mode (E17), so two or more concurrent Full goals is the expected case, not
a corner case.

The consequence is mechanical: lead A’s branch regenerates all four files including its
own goal’s row; lead B’s branch does the same; both differ from main. Every pair of
concurrent Full goals conflicts on all four files, on every merge, forever. Because SPEC
14 checks for drift, a lead cannot simply leave them unregenerated.

SPEC 15.3’s `--no-commit` reconciliation is the stated mitigation. It converts a conflict
into manual work performed by root on every merge, which is a cost, not a fix.

**Correction.** Stop tracking the four generated views. They are already, by SPEC 12.4’s
own definition, pure projections of canonical records plus Git — the same category as
`.harness/cache/`, which the SPEC correctly ignores. Move them there, render on demand
(`harness board`, `harness handoff`), and delete “stale generated views” from the SPEC 14
check list entirely, because a rebuilt-on-read projection cannot be stale. Queryability is
unchanged: every input remains tracked. See A2 and H2.

### F4 — HIGH — The 12.4 staleness anchor is inoperative in this repository and measures the wrong thing `VERIFIED`

**Anchor:** E26, E19, E20.

Revision #6 added a “cheap, offline-checkable provenance” anchor:
`migration_head: <last applied migration filename>` and `migration_count: <n>`.

Two defects, both specific to this repo:

1. **`migration_head` is frozen.** The lexically last file in `supabase/migrations/` is
   `99999999999999_ground_truth.sql` — a permanent sentinel whose *content* is regenerated
   but whose *filename* never changes (E26). The anchor field is therefore a constant and
   can never diverge. `migration_count` still moves, so the mechanism degrades to a file
   counter.
2. **The anchor cannot see the staleness that actually occurs.** The live divergence in
   this repository is not “a migration was added”; it is “the tracked summary disagrees
   with the live database”. `AGENTS.md:51` claims 41 tables / 165 functions and asserts
   byte-equality with live; `CLAUDE.md:307` reports live at 50 tables / 175 functions
   (E19); an active goal file states plainly that the tracked ground-truth copy is stale
   and must not be consulted (E20). Migrations were added and counted throughout that
   period. A migration-count anchor would have reported `fresh` the entire time.

SPEC 15.5 already contains the principle that refutes its own anchor: “A migration file in
Git is not evidence of deploy.” A migration-tree anchor is therefore, by the SPEC’s own
reasoning, not evidence of schema currency.

**Correction.** Split the rule by provenance of the source:

- `ui-map.md` — source (`js/`) is in Git. Keep it tracked and anchor it on a content hash
  of the source file set. This anchor is real and offline-checkable.
- `schema-summary.md` — source is a live database outside Git. **Do not track it.**
  Generate into `.harness/cache/`, stamp it with the timestamp of the live probe that
  produced it, and have `harness validate` report `UNKNOWN`, never `FRESH`, for any
  DB-derived document. A governance-plane check must not answer a product-plane question
  (see section 5).

### F5 — HIGH — `docs_authority` enforced against staged paths cannot see most of this repository’s write surface `VERIFIED`

**Anchor:** E2, E5, E28; SPEC 12.3, 14.

`docs_authority` (`write` / `append` / `propose_only`) is enforced by checking manifest and
staged paths. Three live write channels are invisible to that check:

1. **Ignored paths.** 255 of 277 files under `.claude/` are untracked/ignored (E2), and
   `AGENTS.md`/`CLAUDE.md` are ignored outright (E5). A lead can rewrite the repository’s
   *actual* operative instructions and `git diff --cached` stays empty.
2. **Out-of-repo surfaces.** This environment routinely writes agent memory outside the
   repository (the harness’s own memory directory under the user’s home). Nothing in
   SPEC 12.3 or 14 reaches it.
3. **Live database mutations.** These have no path at all. SPEC 15.5 gates them by prose
   only; no check can observe them.

The first channel is the serious one, because it is exactly where policy lives today.

**Correction.** Redefine authority over *surfaces*, not staged paths:

- extend the goal’s `docs_authority` with an explicit `out_of_repo: []` list and a
  `db: none|read|write` field;
- have the pre-review check run `git status --porcelain` (working tree, not index) inside
  the lead’s worktree, so ignored-but-modified files are at least *reported* — `git status
  --porcelain --ignored` where the goal touches ignored policy;
- make F1 the structural fix: once `AGENTS.md`/`CLAUDE.md` are tracked, the highest-value
  member of channel 1 becomes visible to the ordinary staged-path check.

### F6 — MEDIUM — Four of eight phases have no write manifest; two have no exit criteria `VERIFIED`

**Anchor:** 2.2, 2.3.

PLAN 2 requires “exact changed-file scope” from every phase. Phases 0, 5, 6, and 7 provide
none, and Phases 5 and 6 also have no exit-criteria section. The concrete casualty is
`.harness/githooks/prepare-commit-msg`: it is in SPEC 4’s tree, it is described in Phase 5
work item 3, and no manifest creates it. `.gitignore` and `.harness/cache/` are in the same
position.

**Correction.** Give Phases 0, 5, 6, 7 explicit manifests. Phase 5’s must include
`.harness/githooks/prepare-commit-msg`, `.harness/githooks/pre-commit` (the F2
dispatcher), `tests/harness/test_git_lifecycle.py`, and `.gitignore` if not already
consumed by Phase 1. Phase 6’s must be the deletion manifest it already promises
(“cleanup is its own reviewed manifest”) written down rather than referred to.

### F7 — MEDIUM — Revision #3 fixed one schema-less canonical type and left three `VERIFIED`

**Anchor:** 2.2 (schema table).

`decisions/` got a schema and an owner. Curated **memory notes** (canonical per 12.4,
feeds `MEMORY-INDEX.md`), **patterns** (`patterns/index.yaml`, whose IDs SPEC 14 validates),
and **receipts** did not. Receipts are the worst case: SPEC 15.2.1 makes “a current receipt
whose recorded HEAD and diff hash match the commit” the single barrier against a fabricated
`Docs-Update: PASS`, and the receipt has no schema, no format, and no location in SPEC 4.

**Correction.** Add `memory.schema.json` and `pattern.schema.json` to Phase 2’s manifest.
Define the receipt in SPEC — `.harness/cache/receipts/<head>-<diffhash>.json`, fields
`head`, `diff_hash`, `checkpoint`, `verdict`, `generated_at`, `tests` — and add
`receipt.schema.json`. The receipt should live in the ignored cache precisely because it
must never outlive the HEAD it describes.

### F8 — MEDIUM — Two backward dependencies survive PLAN 2.1 `VERIFIED`

**Anchor:** 2.3.

Phase 1’s red-before asserts that `orchestrator-master` selection carries “explicit flow
metadata”, but `flow` is goal frontmatter created in Phase 2. Phase 2 indexes
`Harness-Mode/Goal/Flow` trailers that only Phase 5 produces. 2.1 names neither, and only
Phase 2 honours 2.1’s “declare what you validate but do not create” obligation.

**Correction.** Either move the `orchestrator-master` red-before to Phase 2, or restate it
as a Phase-1-owned fact (a `flow-routing.md` assertion, not a metadata assertion). Add the
trailer-format dependency to 2.1’s known-instance list and to Phase 2’s exit criteria,
noting that Phase 2’s queryability criterion is satisfiable only at degraded richness until
Phase 5.

### F9 — MEDIUM — Phase 1 must edit a file that current policy forbids editing `VERIFIED`

**Anchor:** E22.

`AGENTS.md:111` reads “**CLAUDE.md değiştirme — YASAK** (kullanıcı söylemedikçe OMP
dokunamaz; Claude Code'un dosyası)”. Phase 1’s write manifest contains `CLAUDE.md`. If
Phase 1 is executed by any non-Claude runtime — which the design explicitly permits, since
D2 makes no runtime mandatory — it violates live policy on its first action.

**Correction.** Add to PLAN 14 (owner decisions) an explicit item: who may execute Phase 1,
and whether the `CLAUDE.md`-edit prohibition is lifted for this goal only. This is a
one-line owner decision, not a design change.

### F10 — LOW — Phase 0’s read scope omits two runtime surfaces that exist `VERIFIED`

**Anchor:** E29. `.commandcode/taste/` (5 policy documents, in four categories:
coding, workflow, tooling, communication) and `.mimosa/hook-state/` are on disk and absent
from Phase 0’s enumerated read scope. SPEC 1’s problem statement also omits them.

**Correction.** Add both to Phase 0’s read scope and to SPEC 1’s surface list. `.commandcode/taste/`
is a genuine fifth policy surface and needs the same `canonical-candidate | runtime-adapter
| historical | local-state` classification as the rest.

### F11 — LOW — GitNexus index is stale and CLAUDE.md mandates decisions from it `VERIFIED`

**Anchor:** E27. Index artifacts date to 2026-08-31 18:58; six commits landed 2026-09-02.
`CLAUDE.md:371` (“Always Do”) makes `impact()` mandatory before editing any symbol.
Reported per the review’s instruction; **not** repaired, since `analyze` writes.

**Correction.** Phase 0 already lists “refreshed GitNexus index and freshness evidence” as
an output — that is the right place. Add a `harness validate` warning comparing index mtime
against `HEAD` commit date so the staleness is visible rather than assumed away.

### F12 — LOW — A malformed filename is tracked `VERIFIED`

**Anchor:** E30. `git ls-files` contains a file literally named `"\"$WATCHDOG_PID_FILE\""` —
a shell-quoting accident committed at repo root. Harmless, but it is precisely the class of
artefact Phase 0’s inventory exists to surface, and its presence is weak evidence that no
such inventory has ever been run.

**Correction.** Add to Phase 0’s output as a named removal candidate; delete under Phase 6’s
reviewed manifest, not before.

---
## 4. Bloat audit

### 4.1 Cost per Full goal, as specified

No pilot has run, so these are derived from the documents, not measured. Label:
`HYPOTHESIS`. The derivation is stated so the pilot can falsify it.

A minimal Full goal — one worktree, three commits, one review, one merge, one push —
triggers the following docs-update evaluations under SPEC 12.2:

| Checkpoint kind | Occurrences | Note |
|---|---|---|
| `pre-commit` | 3 | one per commit (15.1/15.2) |
| `progress` | ≥2 | SPEC sets no cap and no trigger; “at every defined checkpoint” |
| `pre-review` | 1 | |
| `post-merge` | 1 | |
| `pre-push` | 1 | |
| `final` | 1 | |
| `handoff` / `blocked` | 0–2 | only if the goal spans sessions or stalls |
| **Total** | **9–11 evaluations** | |

Each evaluation must classify the diff into the seven surface classes of 12.5 and emit one
of four verdicts per relevant surface (12.1), then roll up to `PASS|PARTIAL|FAIL`. If
classification is scripted, that is ~1 model call per evaluation to adjudicate the
surfaces; if the classification itself is model-driven, 2–3.

- **Model calls per Full goal, documentation only: ~10–30.** This is on top of all product
  work, and it is per goal, not per project.
- **Operator prompts per Full goal: 4–6 minimum.** Flow selection (SPEC 6 requires asking
  the owner for “ambiguous multi-worker or long-running work”), goal approval (PLAN 14.6),
  merge decision (15.3, “the exact merge strategy remains a root decision”), push gate
  (15.4), plus a separate gate each for deploy and DB if in scope (15.5). Every
  `propose_only` docs change a lead raises (12.3) adds one more adjudication prompt.

After the reductions recommended below (five checkpoint kinds, untracked generated views,
no tracked schema summary): **6 evaluations, ~6–15 model calls, 4 operator prompts.** The
saving is roughly one third of the documentation overhead, and it removes the entire
merge-conflict class of F3.

For contrast, the repository’s current cost for the same unit of work is one `idle/*`
worktree, one merge commit, and zero mandatory documentation evaluations (E17). The
harness is a real increase; the question is whether each increment buys a named failure.

### 4.2 Checkpoint kinds — the failure each one prevents

SPEC 12.2 defines eight. For each, the specific failure it prevents, or `DELETE`.

| Kind | Specific failure prevented | Verdict |
|---|---|---|
| `pre-commit` | Code ships while its reference documents describe the old behaviour. **This failure has already occurred here**: `AGENTS.md:51` and `CLAUDE.md:306` assert 41 tables / 165 functions against a live 50 / 175 (E19), and an active goal file has to warn readers off the tracked copy (E20). | **KEEP** |
| `pre-review` | A lead hands root a diff outside its write manifest or docs authority, and root accepts it without noticing. Directly implements D6 and D7. | **KEEP** |
| `post-merge` | Main-owned aggregate state and goal status are left describing the pre-merge world. Note: **the strength of this checkpoint is entirely a consequence of F3.** If generated views stop being tracked, its only remaining content is “set goal status”, which is a state transition Phase 2 already validates. | **KEEP, conditional** — demote to a scripted step once F3 is fixed |
| `final` | A goal reaches `DONE` with no report and no evidence, or a worker’s `PASS` becomes acceptance. Implements D7 and SPEC 9 (“Workers cannot mark a goal `DONE`”). | **KEEP** |
| `pre-push` | Pushing a HEAD that moved after `final` ran. Real, but it is `final` re-run with one extra field (“remote-bound range”), and push is already an explicit owner gate (15.4). | **MERGE into `final`** — parameterise as `final(publishing: true)`; re-running the receipt check when HEAD moved is one condition, not a checkpoint kind |
| `handoff` | Context loss at a session boundary: the next session cannot tell what the next action is. A generator cannot invent “next action” text, so this checkpoint forces a human/agent to write something that does not otherwise exist. | **KEEP** |
| `blocked` | Nothing that `handoff` does not. “Decision request, blockers, and handoff state” is `handoff` with a reason field, and `status: blocked` is already a validated state transition (Phase 2) surfaced by `harness stale` (SPEC 13). | **DELETE** — keep `blocked` as a goal *status*, delete it as a checkpoint kind |
| `progress` | Nothing. Its stated content is “goal state and board projection”. Goal state is already in the goal file and versioned by Git; the board is a projection a generator computes on demand. It is the only kind with no diff input and no artefact that a machine could not derive. | **DELETE** |

Result: **8 → 5** (`pre-commit`, `pre-review`, `post-merge`, `handoff`, `final`). This is the
`MODIFY` behind A3.

### 4.3 Concrete deletions

Nine, ordered by value. The first three satisfy the “at least three concrete deletions”
requirement on their own.

1. **Delete the `progress` checkpoint kind** (SPEC 12.2). No nameable failure; it is the
   largest single contributor to the 9–11 evaluations in 4.1 because it is the only kind
   with no natural trigger.
2. **Delete the `blocked` checkpoint kind** (SPEC 12.2), keeping `blocked` as a status.
   Folds into `handoff`.
3. **Delete the four tracked generated views** from SPEC 4’s tracked tree
   (`generated/BOARD.md`, `HANDOFF.md`, `GOAL-INDEX.md`, `MEMORY-INDEX.md`) and from
   Phase 2/3 write manifests. Move to `.harness/cache/`. This also deletes the “stale
   generated views” item from SPEC 14’s check list and the `test_generated_views.py`
   drift-detection burden (F3).
4. **Delete `references/schema-summary.md` from the tracked tree** (F4). A DB-derived
   document that is “GENERATED — NOT AUTHORITY” and cannot be honestly anchored has no
   reason to be in Git. Deleting it also deletes half of revision #6.
5. **Delete `pre-push` as a distinct kind** (4.2), merging into `final`.
6. **Delete `.harness/memory/` and `MEMORY-INDEX.md` from Phase 3.** Memory is a canonical
   record type with no schema (F7), no measured failure, and an unresolved owner question
   (PLAN 14.4 — “Decide whether leads can ever append canonical memory directly”). Defer
   the whole subsystem to a decision record after the pilots. SPEC 12.7’s exclusion list is
   good policy and can live in `contract.md` without a directory.
7. **Delete four of the six pattern files from Phase 4** (`patterns/{modal,forms,rpc,offline-sync,testing}.md`).
   Ship `index.yaml` plus the patterns that already have an automated test — `modal-router`
   qualifies today (`tests/modal-router.spec.js`, E15). SPEC 11 already requires “an
   automated test” per pattern; honour it by shipping only what passes that bar, and grow
   the catalogue as tests appear.
8. **Delete the `verifier` role as a separate role** (SPEC 7.5), keeping its *constraint*
   (“does not repair product code”) as a mode any actor enters. Under single-operator use
   it is a checklist, not a person (A8).
9. **Delete the `owner`/`root` split from goal frontmatter**, keeping it in `contract.md`
   prose. `owner: root-or-lead-id` already collapses them in practice; the distinction
   matters for gates (15.4, 15.5), which are already separately enumerated.

### 4.4 Metadata and ceremony that should stay

Stated so the audit is not one-directional. These earn their cost:

- `base_sha` / `launch_sha` / `branch` / `worktree` in the goal (SPEC 10). Cheap, and the
  only way to reconstruct what a worktree was based on after it is removed.
- `write_manifest`. It is the input to the one check (F5) that implements D6.
- The `NO_CHANGE_REQUIRED` verdict (12.1). It is what keeps the remaining five checkpoints
  from becoming churn, and it is correctly declared a first-class success.
- The 3.1/3.2 plane tables (revision #1). They are prose, they cost nothing, and section 5
  shows they already caught real errors.
- The prohibition on fabricated verdict trailers (15.2.1). The mechanism needs a schema
  (F7) but the rule is the single most valuable sentence in the SPEC.

---
## 5. Authority and planes

### 5.1 Role × action matrix

Compiled from SPEC 7, 10, 12.3, 15.3–15.5. `✓` = permitted; `✓*` = permitted only within
the goal’s declared manifest/authority; `gate` = requires a separate explicit approval;
`—` = not permitted.

| | code | docs | goal | worktree | commit | merge | push | deploy | DB |
|---|---|---|---|---|---|---|---|---|---|
| **owner** | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **root** | ✓ | ✓ (global reconciliation, 12.3) | ✓ create/close | ✓ own | ✓ | ✓ | gate (15.4) | gate (15.5) | gate (15.5) |
| **lead** | ✓* (write_manifest) | ✓* (`write`/`append`; else `propose_only`) | ✓* own goal only | ✓* own | ✓ (local branch) | — | — unless goal grants (15.4) | — | — |
| **worker** | ✓* (exact manifest + active goal + owned worktree) | — (memory: candidates only, 12.7) | — cannot set `DONE` (SPEC 9) | — (uses assigned) | ✓ (in own worktree) | — | — | — | — |
| **verifier** | — (7.5: “does not repair product code”) | — | — (returns verdict only) | — | — | — | — | — | — |

The matrix is internally consistent and correctly implements D6, D7, and the separation in
15.5. Three observations:

1. **`worker → docs` is under-specified.** SPEC 12.7 says workers do not write canonical
   memory, but nothing states whether a worker may edit a documentation file that appears
   in its `write_manifest`. Given D6 constrains leads, the stricter reading is surely
   intended; it should be written down, because a `write_manifest` is currently a path list
   with no doc/code distinction.
2. **`lead → commit` and `lead → push` are correctly separated**, and this is where the
   design most clearly improves on current practice: `CLAUDE.md:347` currently instructs
   automatic `git push origin main` without approval (E21). The SPEC’s position is the
   better one, but F9’s owner decision must resolve which text wins during migration.
3. **Under single-operator use, rows 1–2 and row 5 are the same human** (A8). The matrix is
   still worth keeping as a *contract* — it tells a delegated runtime what it may not do —
   but it should not generate five separate identity fields.

### 5.2 Does the four-plane separation hold?

Mostly yes, and revision #1 was worth making. Verified checks:

- **Execution plane is genuinely pluggable.** SPEC 3.1’s enum, 6’s routing, and the rule
  that “no specific external runtime … is assumed to be active” survive contact with the
  rest of the document: no acceptance criterion, no check in SPEC 14, and no phase exit
  criterion depends on a named external runtime. `VERIFIED` by absence — I searched both
  documents for a mechanism keyed to a specific bridge or worker system and found none.
- **The governance plane does not trust self-reports.** SPEC 3.2’s “Was the work accepted?
  → root verification of diff, tests, and docs evidence” is consistently applied: SPEC 9
  (workers cannot set `DONE`), 10 (`DONE` is not inferred from a clean branch or green
  worker report), 15.3 (root verifies before merge). D7 is implemented, not merely stated.
- **Worktree existence is read from Git, not from records.** SPEC 10 and 13 both say so
  explicitly, and 3.2 names the discrepancy case. This is the single best correction in
  revision #1 — it is exactly the failure mode that produces a second registry.

### 5.3 Where a plane answers a question it does not own

Three instances, in decreasing severity.

1. **Governance answers a product-plane question about the database.** SPEC 12.4 requires
   `harness validate` to mark `schema-summary.md` `STALE` on anchor divergence — and, by
   implication, not-stale otherwise. Freshness of a database summary is owned by the live
   schema, which 3.2 states correctly (“What is the database structure? → live schema”).
   Computing it from the migration tree is a governance-plane answer to a product-plane
   question, and F4 shows it is empirically wrong here. **Fix:** `validate` must emit
   `UNKNOWN` for DB-derived documents, never `FRESH`; only `STALE` may be asserted, and only
   as a lower bound.
2. **A missing row: deploy state.** 3.2 has no “Is this change deployed?” row, yet 15.5
   asserts a fact about it (“A migration file in Git is not evidence of deploy”) and the
   repository has two independent deploy paths (`AGENTS.md:102-106`: GitHub Pages ships JS
   only; Supabase SQL requires a separate `supabase_migrate` step). Without an owner, this
   question defaults to the governance plane, which cannot answer it. **Fix:** add the row
   with authority “the live environment / the deploy tool’s own output”, and make `final`
   record deploy state as `unknown` unless a probe supplied it — the same honest-default
   pattern 15.2.1 already uses for `Harness-Flow: unknown`.
3. **The runtime adapter question is answered by the wrong artefact.** SPEC 5.5 says a
   check “detects duplicated policy markers across adapters”, scanning
   `.harness/runtimes/*.md`. But ZCode’s real adapter is `.zcode/hooks/session_contract.py`,
   which hard-codes a five-rule contract summary in a Python string (E24), and
   `.zcode/hooks/commit_guard.py` sets Git-commit expectations (E25) — precisely what 5.5
   forbids adapters from doing. A check that reads only `.harness/runtimes/` will report
   “no duplication” while the actual duplication sits one directory away, untracked and
   invisible in worktrees (E6). **Fix:** the 5.5 check must take the runtime’s *real*
   discovery surface as input — for ZCode, `.zcode/config.json`’s `SessionStart` command and
   the script it names — or the adapter must be rewritten to read `.harness/contract.md`
   from disk rather than embed a copy.

---
## 6. Docs, goals, worktrees, and index

### 6.1 Checkpoint matrix

| Kind | Diff-driven? | Canonical artefact it writes | Generated artefact it refreshes | Verdict enum | After this review |
|---|---|---|---|---|---|
| `progress` | no | none | BOARD | 12.1 | **DELETE** (4.2) |
| `blocked` | no | goal `status`, handoff fields | HANDOFF | 12.1 | **DELETE**, fold into `handoff` |
| `handoff` | no | goal handoff fields, report | HANDOFF | 12.1 | KEEP |
| `pre-commit` | **yes** (12.5) | references, patterns | none | 12.1 | KEEP |
| `pre-review` | yes | report, manifest evidence | none | 12.1 | KEEP |
| `post-merge` | partly | goal `status`, memory promotion | BOARD, INDEX | 12.1 | KEEP (demote once F3 fixed) |
| `pre-push` | no | none | none | 12.1 | MERGE into `final` |
| `final` | yes | report, decisions, memory | all | 12.1 | KEEP |

The load-bearing observation: **only three of eight kinds actually read a diff.** SPEC 12.5’s
diff-routing table — the mechanism that makes docs-update more than a reminder — applies to
`pre-commit`, `pre-review`, and `final`. The other five evaluate goal/board state, which is
already machine-derivable. That asymmetry is the whole argument of 4.2.

### 6.2 Canonical vs generated boundary

The boundary as drawn in 12.4 is correct in principle and misplaced in practice.

Correct: goals, reports, decisions, curated references are canonical; aggregate views are
projections; “Generated views are never independently edited.”

Misplaced: the projections are placed **inside the tracked tree** (SPEC 4). A projection
that is tracked acquires three properties it should not have — it can conflict (F3), it can
drift (requiring the SPEC 14 check that exists only because it is tracked), and it can be
edited by hand (requiring the prohibition). All three disappear if the projection is
rebuilt on read. The `.harness/cache/` directory in SPEC 4 already establishes exactly this
category; the generated views belong in it.

The one genuine counter-argument — that a tracked `BOARD.md` is readable on GitHub without
running anything — is worth stating and does not survive: nothing in the acceptance
criteria (SPEC 18) or the query surface (SPEC 13) depends on web-readability, and D1 makes
the harness repository-local.

**Verdict on A2:** `MODIFY` — keep full generation, drop tracking. See 7.2 for the H2 test.

### 6.3 Authority enforcement

Covered in F5. Summarising the enforcement surface honestly:

| Write channel | Visible to a staged-path check? | Notes |
|---|---|---|
| tracked product code | yes | the intended case; works |
| tracked docs (`.claude/{ui-map,rpc-reference,domain-rules}.md`, `docs/*`) | yes | 23 tracked `.claude` files (E2) |
| **ignored `.claude/**` (255 files)** | **no** | includes the live goal/task/knowledge trees (E23) |
| **`AGENTS.md`, `CLAUDE.md`** | **no** | ignored (E5); the operative policy surface |
| **out-of-repo agent memory** | **no** | outside the repository entirely |
| **live DB** | **no** | no path; prose gate only (15.5) |

F1 is the cheapest structural improvement to this table: it converts row 4 from invisible to
visible for two lines of `.gitignore`.

### 6.4 Memory and decision records

**Decisions (12.6)** are well-specified after revision #3: schema, owner, status enum,
supersession, and “canonical inputs, never generated”. No objection. One addition: a
decision record should carry the `head` at which it was accepted, so a later reader can tell
whether it predates a structural change.

**Memory (12.7)** is the weakest subsystem in the SPEC. The *policy* is excellent — “only
reusable, evidenced knowledge that prevents future wrong decisions”, with progress
summaries and information already in a goal/report/commit explicitly excluded. That
exclusion list is the correct lesson and should survive. The *implementation* is a
directory with no schema (F7), no promotion mechanism beyond prose, and an unresolved owner
question the plan itself defers (PLAN 14.4). Recommend deletion from Phase 3 (deletion #6)
and re-entry through a decision record after the pilots, with the 12.7 exclusion list moved
verbatim into `contract.md` so nothing of value is lost.

On A6 — vector memory removal — the evidence supports the owner’s position rather than
undermining it. The failure mode a vector store introduces is the same one F4 identifies:
a derived copy that silently disagrees with its source and is trusted anyway. This
repository has already paid that cost twice, in the tracked schema summary (E19/E20). With
375 tracked files, `rg` over tracked Markdown plus `git log -S` covers the retrieval need.

### 6.5 Omission risks

Where documentation can still be silently skipped after this design is implemented:

1. **The five non-diff checkpoints** can be satisfied without reading anything (6.1). This
   is H3’s falsifier and is fixed by deleting three of them and binding the rest to a
   receipt.
2. **`NO_CHANGE_REQUIRED` has no evidence requirement.** 12.1 makes it a first-class
   outcome — correctly, or the mechanism becomes churn — but nothing distinguishes “I
   classified the diff and no surface was affected” from “I typed the words”. The receipt
   mechanism of 15.2.1 already solves this for trailers; extend it: a verdict of any kind
   must reference a receipt carrying the diff hash it was computed over.
3. **Ignored surfaces (6.3)** are never evaluated at all, because 12.5’s routing operates on
   the diff.
4. **Ad-hoc Fast work has no docs checkpoint by design.** This is D5 and is correct, but it
   means the entire class of change that currently produces stale references (E19) is the
   class with the least coverage. Mitigation is F1 plus 15.1’s `pre-commit`, which does
   apply to Fast root commits — worth stating explicitly in `task-modes.md`, since 8.1’s
   text (“No pre-authored goal is required”) is easy to read as “no checkpoint”.

### 6.6 Queryability

SPEC 13’s command surface is proportionate and the index inputs are correct. Two notes:

- **Ad-hoc queryability degrades honestly.** Subject, paths, author, date always; mode,
  flow, goal only with the hook. 15.2.1 states this and PLAN 8 requires a scenario proving
  the degraded path. This is well handled — see H5 for what the documents still miss.
- **The index is an ignored rebuildable cache** (13). Correct, and it is the precedent that
  makes the F3 recommendation obviously consistent rather than novel.

### 6.7 State transitions, lineage, stale goals, reconstruction

- **Transitions.** The lifecycle in SPEC 9 is complete (`DRAFT → ACTIVE → REVIEW → DONE`
  plus four terminal states) and Phase 2 red-befores cover illegal transitions and the
  worker-cannot-set-`DONE` rule. No gap found.
- **Lineage.** `parent` + `harness lineage` cover child goals. Missing: `superseded` is a
  status in SPEC 9 but the frontmatter has no `superseded_by` field, unlike decisions
  (12.6), which do. A superseded goal is therefore a dead end. **Fix:** add
  `superseded_by: null` to the goal frontmatter.
- **Stale goals.** `harness stale` exists in SPEC 13 with no definition of stale anywhere
  in either document. **Fix:** define it — an `active` goal whose `launch_sha` is more than
  N commits behind `HEAD`, or whose recorded worktree is absent from `git worktree list`
  (the 3.2 discrepancy case), or whose latest checkpoint predates its branch tip.
- **Reconstruction from Git.** Achievable for everything the SPEC declares canonical, since
  all canonical inputs are tracked Markdown/YAML and 12.4 caps the goal at one current
  checkpoint with history in Git. The one non-reconstructible item is the receipt
  (F7) — correctly so, since it must not outlive its HEAD.

---
## 7. Git lifecycle

### 7.1 Fast direct-main flow

SPEC 15.1: `change → tests → docs-update pre-commit → diff/status review → atomic code+docs
commit → optional final checkpoint → push gate`.

| Step | Assessment |
|---|---|
| no goal required | Correct, implements D5, and matches how the repository actually works today |
| `pre-commit` docs-update | The single most valuable checkpoint in the design; it targets the exact failure that has already occurred (E19) |
| atomic code+docs commit | Good — it makes the docs update reviewable in the same diff |
| push gate | **Conflicts with live policy**: `CLAUDE.md:347` mandates automatic `git push origin main` with no approval (E21). Not a defect in the SPEC; a migration conflict that F9’s owner decision must settle explicitly, or Fast work will keep auto-pushing past the gate. |
| dirty-tree interaction | **Unaddressed.** Main carries 46 dirty entries permanently (E8). “diff/status review” over a permanently dirty tree means the operator reviews 44 untracked entries they did not create every time. `git status --short` in PLAN 12’s acceptance suite will always be non-empty. **Fix:** define the Fast review as `git diff --cached` plus `git status --porcelain -- <manifest paths>`, not bare `git status`. |

### 7.2 Full worktree flow and merge

SPEC 15.2 → 15.3. Root “may merge with `--no-commit`, reconcile main-owned aggregate/docs
state, run post-merge/final docs-update, then create the merge commit.”

The mechanism is sound for a single integrator, and “history preservation and clean rollback
are preferred over ceremony” is the right instinct. Three failure modes, all live here:

1. **Untracked-file collision aborts the merge.** `.harness/` is currently untracked and
   contains four files on main (E1, E10). A lead branch that adds tracked files under
   `.harness/` — which is precisely what the implementation goal does — will hit Git’s
   “untracked working tree files would be overwritten by merge” refusal for any colliding
   path. Recovery requires moving user-owned untracked files, i.e. mutating the state every
   phase promises to preserve. `HYPOTHESIS` on the exact Git message (no merge was
   performed); the collision itself is `VERIFIED` from E1/E8.
2. **Conflict leaves `MERGE_HEAD` set on a permanently dirty tree.** After a conflicted
   `--no-commit` merge, the operator cannot distinguish pre-existing dirt from merge
   output by inspection. `git merge --abort` is safe and restores both; the common recovery
   reflex `git checkout -- .` or `git clean -fd` destroys 44 untracked user files.
3. **Generated-view conflicts on every concurrent pair** (F3). The `--no-commit`
   reconciliation is the SPEC’s answer to this, which means the mechanism’s main
   justification is a problem the design itself created.

**Correction.** Perform integration in a dedicated clean integration worktree rather than on
the permanently dirty main checkout: `git worktree add` at main, merge there, push/return.
Record a non-destructive snapshot (`git stash create` writes a commit object without
touching the working tree) in the goal before any merge, so recovery never needs `clean` or
`checkout -- .`. Both are cheap and eliminate failure modes 1 and 2 outright; fixing F3
eliminates 3.

### 7.3 Enrichment metadata

SPEC 15.2.1 is the best-reasoned new mechanism in the revision set. The chain — ad-hoc work
is queryable without trailers; richer queries need trailers; discipline-dependent trailers
are unreliable; therefore derive them mechanically; and never write a verdict trailer
without a matching receipt — is correct at every link, and the “fabricated `PASS` is a
governance failure covered by a red-before test” sentence is exactly right.

Three gaps, none fatal to the idea:

1. **F2** — the bootstrap disables an existing enforcement hook. This is the blocking issue.
2. **Relative `core.hooksPath` in a linked worktree.** Git resolves a relative `core.hooksPath`
   against the directory hooks run in, i.e. the working tree top level. In a linked worktree
   that is the worktree’s own root, so the hook fires only if that branch has
   `.harness/githooks/prepare-commit-msg` checked out **and executable**. A branch based on a
   pre-harness commit gets no enrichment and no warning. `HYPOTHESIS` — establishing it
   requires creating a commit, which this review may not do; PLAN 10 already flags inherited
   hook behaviour as unproven, and this is the specific sub-case the pilot must measure.
   **Fix:** set an absolute path at bootstrap, or have `harness validate` assert the hook is
   present-and-executable relative to the *current* worktree rather than the repo root.
3. **The receipt has no schema or home** (F7).

`Harness-Flow: unknown` as an honest default deserves explicit praise: it is a governance
artefact declining to assert an execution-plane fact it cannot observe, which is 3.2 applied
correctly at the smallest scale in the document.

### 7.4 Push, deploy, DB

15.4/15.5 keep four gates distinct — push, deploy, live DB, destructive — and state that a
migration file in Git is not evidence of deploy. This matches the repository’s real topology
(`AGENTS.md:102-106`: GitHub Pages ships JS only; Supabase SQL needs a separate deploy step),
and it is the part of the design that most directly protects a production ERP. No changes
recommended beyond the missing 3.2 row identified in 5.3(2).

### 7.5 Rollback

PLAN 13 is well-formed: independently revertible phases, “do not weaken the checker to force
green”, retain the prior instruction path, preserve evidence, do not proceed to cleanup. The
sequencing decision in PLAN 11 — legacy deletion *after* pilots — is correct and should not
be traded away under schedule pressure.

One correction: “unset `core.hooksPath` to revert enrichment” is not a complete rollback once
F2 is fixed, because the dispatcher will have been installed. The rollback step must be
“unset `core.hooksPath` **and verify `.git/hooks/pre-commit` is reachable again**”.

---
## 8. Roadmap and final recommendation

### 8.1 Challengeable assumptions A1–A10

| # | Assumption | Verdict | Evidence | Cost of being wrong |
|---|---|---|---|---|
| A1 | `.harness/` is the right directory name and namespace | **MODIFY** | E23 (`.claude/` already holds 9 goals, 12 tasks, 3 arch-decisions, 8 knowledge files, 11 tracked idle-reports); E5/E6 (the root files are ignored and absent in worktrees) | The name is right — it is runtime-neutral, and four distinct runtimes read this repo (E1/E24/E29), so `.claude/` cannot be the shared namespace. What is wrong is the **scope**: the design creates a parallel governance tree while retirement of the old one is deferred until after the pilots (PLAN 11), guaranteeing a long window with two goal trees, two report trees, two decision trees. Cost if wrong: a third governance surface alongside `.claude/` and `.commandcode/taste/`, and an operator who must check both. **Modification:** keep the name; cut the tracked tree to contract + schemas + goals + reports + decisions + runtimes + githooks + tests; move projections, cache, and DB-derived references out of Git; and migrate `.claude/goals/` and `.claude/idle-reports/` in Phase 2 rather than Phase 6, since they are the two surfaces that would otherwise be duplicated. |
| A2 | BOARD and HANDOFF fully generated from canonical records | **MODIFY** | F3, 6.2, E17 | Full generation is right; **tracking** the output is wrong. Cost if wrong (i.e. if kept tracked): a guaranteed conflict on four files for every concurrent Full-goal pair, in a repo whose normal mode is concurrent `idle/*` worktrees. Queryability is unaffected — inputs stay tracked, and `harness board` renders on read. Ceremony is not increased: Fast work never touches these files either way. |
| A3 | All eight checkpoint kinds are necessary | **MODIFY** (8 → 5) | 4.2, 6.1 | `progress` and `blocked` prevent no nameable failure; `pre-push` is `final` re-run. Cost if wrong: 9–11 documentation evaluations per Full goal (4.1), of which five read no diff. Reducing to five keeps every named failure covered — see the per-kind table in 4.2 — and keeps ad-hoc work untouched, since none of the deleted kinds applies to Fast mode. |
| A4 | Commit metadata from an enrichment hook rather than mandatory/manual/absent | **MODIFY** | F2 (E11/E12), 7.3 | The reasoning is correct and should be kept; the bootstrap is unsafe because `core.hooksPath` replaces `.git/hooks` and an active blocking hook lives there. Cost if wrong: silently losing the only automated pre-commit verification in the repo, on main, with no error. Fix is a dispatcher plus a `validate` assertion, not a reversal. |
| A5 | Root `merge --no-commit` plus main reconciliation is robust here | **MODIFY** | 7.2, E1/E8/E17 | Robust for one integrator on a clean tree; this tree is never clean (46 entries) and `.harness/` collides untracked-vs-tracked. Cost if wrong: an aborted merge whose recovery reflex destroys 44 untracked user files. Fix: integrate in a dedicated clean worktree and snapshot with `git stash create` before merging. |
| A6 | Vector memory should be removed entirely | **KEEP** | 6.4, E19/E20 | The removal is right, and the repository’s own history supports it: every derived-copy knowledge store here has gone silently stale and been trusted anyway. Cost if wrong: losing semantic recall over 375 tracked files — recoverable with `rg` and `git log -S`, and out of scope under D1 anyway. |
| A7 | The stated Fast/Full threshold is correct | **MODIFY** | E17, `AGENTS.md:110`, SPEC 8.2 | Six of the eight Full triggers are well-calibrated. Two are not: “a worktree is created” and “a risky cross-layer or multi-file change is planned”. This repository already runs **routine** work in `idle/*` worktrees and merges them the next morning (E17, `AGENTS.md:110`) — making every worktree a Full goal converts today’s ordinary lane into mandatory ceremony and directly erodes D5. **Modification:** trigger Full on *independent write ownership by a non-root actor*, not on worktree creation as such; a root-owned solo worktree stays Fast. Keep the DB/migration, outlives-session, parallel-write-ownership, rollback-sensitive, and owner-request triggers unchanged. Ad-hoc queryability is preserved because Fast work remains indexed from Git subject/paths/author/date, plus `Harness-Mode: fast` from the enrichment hook. Cost if wrong: either ceremony on routine idle work (as written) or a multi-file risky change proceeding without a goal (after modification) — the latter is mitigated because the DB/migration and cross-session triggers still fire, and `pre-commit` docs-update applies to Fast work too. |
| A8 | Five roles are worth separating under single-operator use | **MODIFY** | 5.1, E-git-user (single author across recent history) | Keep the *contract* — it tells a delegated runtime what it may not do — but collapse the identities: three named roles (owner-root, lead, worker) plus verification as a mode with the 7.5 constraint attached. Cost if wrong: if a second human joins, owner ≠ root matters — so keep the distinction documented in `contract.md` and the gates in 15.4/15.5 unchanged; only the goal frontmatter loses a field. |
| A9 | Runtime adapters should be tracked files, not generated or symlinked | **KEEP** | E6, E24, E3 | Strongly supported. `.zcode/` is untracked and therefore **absent in both live worktrees**; a generated or symlinked adapter inherits exactly that fate. Tracked files are the only form that survives `git worktree add`. Cost if wrong: adapters drift from runtime reality — which is already true (E24: the real ZCode adapter is an untracked Python script embedding a stale copy of AGENTS.md). Mitigation belongs in the 5.5 check, not in the storage format — see 5.3(3). |
| A10 | Generated reference documents with staleness anchors are safe enough to track | **MODIFY** | F4, E26, E19, E20 | Split by provenance. Source-in-Git (`ui-map.md`): safe to track, anchor on a content hash of the source set. Source-outside-Git (`schema-summary.md`): not safe at any anchor, because the anchor cannot observe the source. Cost if wrong: a tracked schema summary becomes the fourth stale schema knowledge source in this repository — the exact outcome 12.4 says the rule exists to prevent, and the one that has already happened three times (`ground_truth.sql`, `AGENTS.md:51`, `CLAUDE.md:306`). |

### 8.2 Hypotheses H1–H8

| # | Verdict | Falsifier actually checked | Result |
|---|---|---|---|
| H1 | **EXTEND** | Sought a drift class the tracked layout cannot detect. Ran `ls -a` in both linked worktrees and `git check-ignore` on every root surface. | Found one, and it is the dominant class here: every runtime-discovery surface except `.claude/` is ignored or untracked (`AGENTS.md`, `CLAUDE.md`, `.zcode/`, `.agents/`, `.qwen/`, `.commandcode/`, `.openclaude/`) and therefore **absent** in both live worktrees (E5, E6). A tracked `.harness/` cannot detect drift in a file Git never sees. The hypothesis holds **conditionally**: tracking reduces drift only after the ignore rules are removed (F1). As stated — “a tracked `.harness/` reduces drift” — it is true but far from sufficient, and the two-line `.gitignore` fix delivers more of the benefit than the eight-phase program does. |
| H2 | **REFUTE** (as stated) | Sought a regenerate-on-merge conflict path with two leads plus root on main. | Found, and it is the normal case rather than a corner case: three worktrees are live now (E17) and `idle/*` is the standard mode. All four generated views are whole-repository functions, so every concurrent Full-goal pair conflicts on all four, every merge. Generator-as-authority also materialises: SPEC 14 checks “stale generated views”, making the generator’s output a gate. Narrative loss is the one failure that does **not** occur — narrative lives in the goal’s handoff fields, which stay canonical. Generation is not the problem; tracking the output is. Fixed by A2. |
| H3 | **EXTEND** | Sought a checkpoint satisfiable without reading the diff. | Five of eight are: `progress`, `blocked`, `handoff`, `post-merge`, `pre-push` have no diff input at all — 12.5’s routing table is defined over a diff, and only `pre-commit`, `pre-review`, and `final` receive one (6.1). `NO_CHANGE_REQUIRED` therefore prevents churn exactly as intended, but nothing distinguishes a real evaluation from a typed word. The hypothesis is right about churn and wrong about omission. Fix: extend 15.2.1’s receipt requirement from trailers to *all* verdicts — a verdict must cite a receipt carrying the diff hash it was computed over. |
| H4 | **REFUTE** (as stated) | Sought a lead write the staged-path check cannot see. | Three found, all live: (a) 255 of 277 `.claude/` files plus both root instruction files are ignored (E2, E5) — a lead can rewrite the repository’s operative policy with an empty `git diff --cached`; (b) out-of-repo agent memory under the user’s home; (c) live DB mutations, which have no path. `docs_authority` checked against staged paths constrains only tracked-and-staged writes, which is a minority of the real write surface. D6 is not unimplementable — it needs surface-based authority (F5) — but it is not implemented by the mechanism the SPEC names. |
| H5 | **EXTEND** | Checked what is lost when `core.hooksPath` is unset, and whether the degraded mode is honest. | `core.hooksPath` is unset today (E9), so the loss is total and current: no `Harness-Mode`, `Harness-Goal`, or `Harness-Flow` on any commit. The SPEC’s honesty requirement **passes** — 15.2.1 says `validate` warns and never blocks, and PLAN 8 requires a degraded-path scenario. Two losses the documents do not state: enabling `hooksPath` disables the existing active blocking hook (F2), i.e. degradation in the opposite direction; and a relative `hooksPath` in a linked worktree fires only if that branch carries the hook, so enrichment vanishes silently on pre-harness branches (7.3, `HYPOTHESIS`). PLAN 10 correctly flags worktree hook inheritance as unproven; it flags neither of these. |
| H6 | **CONFIRM** | Sought a dirty-tree or conflict scenario that strands the repository. | Found two (7.2): an untracked-vs-tracked collision under `.harness/` aborts the merge and its recovery requires moving user-owned untracked files; and a conflicted `--no-commit` merge on a permanently 46-entry-dirty tree makes merge output indistinguishable from pre-existing dirt, so the usual `git clean -fd` / `git checkout -- .` reflex destroys 44 untracked user files. Useful **and** fragile, exactly as hypothesised. Both are removed by integrating in a clean dedicated worktree with a `git stash create` snapshot recorded in the goal. |
| H7 | **CONFIRM** | Sought an enforcement gap only a blocking hook closes. | None found that a blocking hook actually closes **here**. The obvious candidate — pushing without a final receipt — is already an explicit owner gate (15.4), and the repository’s existing blocking hook exits 0 on every non-main branch (E12), so it does not cover the lead-worktree path either. Positive evidence for the hypothesis: `.zcode/hooks/commit_guard.py:2-3` is deliberately non-blocking with a recorded rationale — “Non-blocking: her zaman exit 0 (asla bloklamaz — Mimosa L3 dersi)” — a prior lesson in this repository that blocking hooks caused harm. The enrichment/enforcement distinction holds **in the text**; it breaks **in the bootstrap** (F2), which is an installation defect, not a conceptual one. |
| H8 | **CONFIRM** | None required. | Nine concrete removals named in 4.3, of which the top four (`progress`, `blocked`, tracked generated views, tracked `schema-summary.md`) remove roughly a third of the per-goal documentation cost and one entire class of merge conflict. |

### 8.3 Roadmap

| Rank | Change | Why | Impact | Effort | Risk | Acceptance evidence |
|---|---|---|---|---|---|---|
| 1 | Remove `.gitignore:133-134`; track `AGENTS.md` and `CLAUDE.md` after a secret scan. Add `.harness/cache/` to `.gitignore` in the same change. | F1. Without this, no runtime-discovery criterion in the whole design can pass, and the drift the harness exists to fix keeps its main cause. | Very high | ~1 hour incl. secret scan | Low — content already on disk and read by agents daily | In a scratch linked worktree: `test -f AGENTS.md && test -f CLAUDE.md` passes; `git check-ignore AGENTS.md` returns non-zero |
| 2 | Ship `.harness/githooks/pre-commit` as a dispatcher that chains the pre-existing hook; make `harness validate` assert every pre-bootstrap hook is still reachable; add a red-before fixture. | F2. The proposed bootstrap silently deletes the repository’s only automated pre-commit verification. | Very high | ~2 hours | Low | Fixture repo with a stub `.git/hooks/pre-commit`: after `git config core.hooksPath .harness/githooks`, the stub still fires and its exit code is preserved |
| 3 | Move `generated/{BOARD,HANDOFF,GOAL-INDEX,MEMORY-INDEX}.md` into `.harness/cache/`; render on demand; delete “stale generated views” from SPEC 14 and `test_generated_views.py` from Phase 3. | F3 / A2 / H2. Removes a guaranteed conflict class in a repo whose normal mode is concurrent worktrees, and deletes a check that exists only because the files are tracked. | High | ~3 hours (mostly deletions) | Low | Two concurrent goal branches, each adding a goal, merge into main with zero conflicts; `harness board` output matches canonical goal statuses |
| 4 | Delete `progress` and `blocked` checkpoint kinds; merge `pre-push` into `final`; bind every remaining verdict to a receipt carrying its diff hash. | 4.2 / H3. Cuts documentation evaluations per Full goal from 9–11 to 6 and closes the “satisfiable without reading the diff” hole. | High | ~4 hours | Medium — the receipt binding is new behaviour needing its own red-before | Pilot measures ≤6 evaluations per Full goal; a fabricated verdict with a stale diff hash is rejected by fixture |
| 5 | Untrack `references/schema-summary.md`; generate into cache with a live-probe timestamp; `harness validate` reports `UNKNOWN`, never `FRESH`, for DB-derived docs. Keep `ui-map.md` tracked with a source-content-hash anchor. | F4 / A10 / 5.3(1). The migration-tree anchor is frozen on a sentinel filename and structurally cannot see live-schema drift. | High | ~2 hours | Low | Adding a migration does not change `migration_head`; `validate` on `schema-summary.md` returns `UNKNOWN`; a `ui-map.md` anchor flips to `STALE` when a `js/` source file changes |
| 6 | Redefine `docs_authority` over surfaces: add `out_of_repo: []` and `db: none\|read\|write`; pre-review runs `git status --porcelain` (working tree, with `--ignored` where the goal touches ignored policy). | F5 / H4 / D6. Staged-path checking sees a minority of the real write surface. | High | ~3 hours | Medium — `--ignored` output is noisy and needs scoping to the goal’s declared surfaces | Fixture: a lead edits an ignored `.claude/**` policy file outside its authority and pre-review fails |
| 7 | Recalibrate the Fast/Full threshold: trigger Full on independent write ownership by a non-root actor, not on worktree creation. | A7 / D5. As written, every routine `idle/*` worktree — the repository’s normal working unit — becomes a Full goal. | High | ~1 hour (text) | Medium — needs an owner decision, since it changes what “risky” means | Pilot 1 completes a routine `idle/*` UI change with no goal and remains queryable via `harness history` |
| 8 | Integrate in a dedicated clean worktree; record a `git stash create` snapshot ref in the goal before any merge; extend PLAN 13 rollback to re-verify hook reachability. | A5 / H6. Merging into a permanently dirty main risks destroying 44 untracked user files during recovery. | Medium-high | ~2 hours | Low | Rehearse a conflicting merge in a scratch clone; `git merge --abort` restores byte-identical dirty state; the snapshot ref resolves |
| 9 | Give Phases 0, 5, 6, 7 write manifests; add exit criteria to 5 and 6; add `.harness/githooks/prepare-commit-msg`, `.gitignore`, and the Phase 6 deletion manifest explicitly. | F6. PLAN 2 requires exact changed-file scope from every phase and four phases do not provide it. | Medium | ~2 hours | Low | Every SPEC 4 path maps to exactly one creating phase; the 2.2 table has no `DEFECT` rows |
| 10 | Add `memory.schema.json`, `pattern.schema.json`, `receipt.schema.json`; define the receipt’s format and cache location in SPEC. | F7. Three canonical/gating record types remain schema-less after revision #3 fixed a fourth. | Medium | ~3 hours | Low | Every canonical record type in 2.2’s schema table has a schema; a malformed receipt is rejected |
| 11 | Resolve the two remaining backward dependencies (Phase 1 flow metadata; Phase 2 trailer format) and add both to PLAN 2.1’s known-instance list. | F8. 2.1 states the right rule and applies it to one of three instances. | Medium | ~1 hour | Low | Each phase’s exit criteria list every artefact it validates but does not create |
| 12 | Owner decision: who may execute Phase 1 given `AGENTS.md:111`, and does the `CLAUDE.md`-edit prohibition lift for this goal. | F9. Phase 1 must edit a file current policy forbids editing. | Medium | ~10 minutes | Low | The decision is recorded in `.harness/decisions/` before Phase 1 starts |
| 13 | Add `.commandcode/` and `.mimosa/` to Phase 0 read scope and SPEC 1; add `superseded_by` to the goal frontmatter; define `stale`; add the deploy-state row to SPEC 3.2. | F10, 6.7, 5.3(2). Small completeness gaps. | Low-medium | ~1 hour | Low | Phase 0 inventory classifies both surfaces; `harness stale` has a written definition its tests assert |
| 14 | Report GitNexus index staleness and the malformed tracked filename in Phase 0’s output. | F11, F12. Reported here, not repaired, per the read-only constraint. | Low | ~30 minutes | Low | Phase 0 inventory names both; `validate` warns when index mtime predates `HEAD` |
| **DO NOT** | **Do not run the `core.hooksPath` bootstrap before rank 2 lands.** | It silently disables `.git/hooks/pre-commit` (E11, E12), removing the only automated pre-commit verification, on main, with no error in either direction. | — | — | — | — |
| **DO NOT** | **Do not begin Phase 6 legacy retirement before the pilots.** PLAN 11 already sequences it last; the pressure to reclaim the duplication cost created by A1 will push against that. | `.claude/` holds 277 files including the live goal, task, knowledge, and report trees actually in use today (E23). Deleting before the replacement is proven loses the only working system. | — | — | — | — |
| **DO NOT** | **Do not make any checkpoint kind, hook, or check a hard blocker for Fast root/lead work.** | D5 and H7. The repository already recorded this lesson once — `.zcode/hooks/commit_guard.py:2-3`, “Non-blocking: her zaman exit 0 (asla bloklamaz — Mimosa L3 dersi)”. | — | — | — | — |
| **DO NOT** | **Do not track any document derived from the live database, at any anchor.** | F4. Three stale schema sources already exist here (`ground_truth.sql`, `AGENTS.md:51`, `CLAUDE.md:306`); a fourth with a `generated: true` header is not safer, only better documented. | — | — | — | — |

### 8.4 Implement / revise first / abandon

**Implement now, largely as written:**

- The plane separation and per-question ground-truth tables (SPEC 3.1, 3.2). Revision #1
  earns its place; section 5 shows it already catches real errors.
- The acceptance model: root verification from Git, tests, and docs evidence; workers cannot
  set `DONE`; worker `PASS` ≠ acceptance (SPEC 9, 10, 15.3). This is the design’s core value
  and it is correctly specified.
- The four distinct gates — commit, push, deploy, live DB — and “a migration file in Git is
  not evidence of deploy” (15.4, 15.5). This is what protects a production ERP.
- Goal/report/decision schemas, status transitions, lineage, and the Git-derived index
  (SPEC 9, 12.6, 13; Phase 2).
- The prohibition on fabricated verdict trailers (15.2.1) — with the receipt defined (rank 10).
- Bloat controls (SPEC 16) and the docs-update exclusion list (12.7). Both are good policy.
- PLAN 11’s sequencing and PLAN 13’s rollback discipline.

**Revise before implementing:**

- Ranks 1–8 above, in order. Ranks 1 and 2 are prerequisites for anything else: rank 1
  because no discovery criterion can pass without it, rank 2 because the alternative is
  silently removing existing enforcement.
- SPEC 4’s tracked tree — smaller, per ranks 3 and 5.
- SPEC 12.2 — five checkpoint kinds, per rank 4.
- SPEC 8.2 — recalibrated Full trigger, per rank 7.
- SPEC 7 — three roles plus a verification mode, per A8.

**Abandon (for now):**

- `.harness/memory/` and `MEMORY-INDEX.md` as Phase 3 deliverables (deletion #6). No schema,
  no measured failure, and an unresolved owner question the plan itself defers. Re-enter
  through a decision record after the pilots; move 12.7’s exclusion list into `contract.md`
  so the policy survives the directory.
- Four of six pattern documents (deletion #7). Ship `index.yaml` plus the patterns that
  already satisfy SPEC 11’s own “requires an automated test” bar.
- The eight-kind checkpoint taxonomy as a whole; five kinds carry every named failure.

### 8.5 Self-check attestation

| Item | Verdict |
|---|---|
| Every process invariant preserved | **PASS** — read-only throughout; one file written (this one); no package, worker, worktree, commit, merge, push, deploy, DB mutation, provider call, or index rebuild; no `gitnexus analyze`. |
| Existing dirty/untracked state preserved byte-identically | **PASS** — `git status --porcelain \| wc -l` = 46 before and 46 after; `.harness/` was already a single untracked entry and remains one. |
| Fast work was not silently turned into mandatory goals | **PASS** — A7 moves in the opposite direction, removing “a worktree is created” as a Full trigger because it would have made routine `idle/*` work ceremonial; none of the deleted checkpoint kinds applied to Fast mode. |
| No orchestration runtime was made mandatory | **PASS** — no recommendation names or requires any external runtime; A9 concerns adapter *storage*, not adapter *use*. |
| Warning hooks not confused with deterministic acceptance; enrichment not confused with enforcement | **PASS** — H7 confirms the distinction holds in the text; F2 is reported explicitly as an installation defect (the bootstrap removing enforcement), not as a collapse of the concept. |
| No specific external runtime assumed active or used as empirical justification | **PASS** — E34 records the deliberate abstention; every finding rests on Git state, file presence, `.gitignore`, hook files, and document text. The one runtime-specific citation, `.zcode/hooks/*`, is used as evidence about **files that exist on disk**, not about a runtime being active. |
| Docs-update omission and bloat addressed together | **PASS** — 4.2 deletes kinds and 6.5/H3 closes the omission hole in the survivors with a single mechanism (receipt-bound verdicts), so the reduction does not weaken coverage. |
| Every criticism carries an implementable correction | **PASS** — each of F1–F12 ends in a **Correction** paragraph, and each maps to a numbered roadmap rank. |
| `VERIFIED`, `HYPOTHESIS`, `DECISION_NEEDED` cleanly separated | **PASS** — F1–F12 each carry a label; the two `HYPOTHESIS` items (relative `hooksPath` resolution in a linked worktree, 7.3; the exact merge-refusal message, 7.2) are marked inline with the reason they could not be probed read-only; `DECISION_NEEDED` items are isolated in section 1. |
| Every D1–D8 concern carries `COST_NOTED` / `TENSION` / `UNIMPLEMENTABLE` | **PASS** — section 1, eight rows. |
| Every A1–A10 received `KEEP` / `MODIFY` / `REVERSE` | **PASS** — 8.1, ten rows. |
| Every H1–H8 received a falsifier that was actually checked | **PASS** — 8.2 names the check performed for each; the H1, H2, H4, H5, H6, H7 falsifiers were run as live read-only commands (E5, E6, E9, E11, E12, E17, E25), H3 and H8 were derived from the document text as the hypotheses permit. |
| Section 1 composed after sections 3–7 | **PASS** — sections 2 through 8 were written to this file first; section 1 was composed last and inserted at a reserved placeholder. |

### 8.6 Question coverage

All ten challengeable assumptions received a verdict: **A1** MODIFY, **A2** MODIFY, **A3**
MODIFY, **A4** MODIFY, **A5** MODIFY, **A6** KEEP, **A7** MODIFY, **A8** MODIFY, **A9** KEEP,
**A10** MODIFY (8.1). All eight hypotheses received a verdict and a checked falsifier:
**H1** EXTEND, **H2** REFUTE, **H3** EXTEND, **H4** REFUTE, **H5** EXTEND, **H6** CONFIRM,
**H7** CONFIRM, **H8** CONFIRM (8.2). No `REVERSE` was returned on A2, A3, A4, or A7, so the
supplementary burden attached to those four does not apply; the queryability and
no-added-ceremony consequences are nevertheless argued in each of their rows.
