# Phase 6 — Legacy Surface Classification Proposal (NO DELETIONS)

Date: 2026-09-03

Owner decision required: this document classifies every legacy agent
surface and proposes dispositions. **Nothing is deleted, moved, or tracked
by this proposal.** Per the implementation plan, Phase 6 executes only
after the owner approves a separate cleanup manifest built from this table.

## Inventory and classification

| Surface | State | Classification | Proposed disposition (owner decision) |
|---|---|---|---|
| `.claude/domain-rules.md` (dirty working copy) | tracked, modified | **migrated** — curated copy lives at `.harness/references/domain-rules.md` (includes the pending 2026-09-02 additions) | retire the tracked copy after the owner's uncommitted edits are either committed or confirmed incorporated; keep the schema-snapshot provenance link |
| `.claude/rpc-reference.md` (dirty working copy) | tracked, modified | **migrated** — `.harness/references/rpc-reference.md` (incl. audit notes + live-schema audit 2026-09-03) | same as above |
| `.claude/ui-map.md` | tracked | **superseded** — symbol-keyed `.harness/references/ui-map.md` replaces the line-numbered map | retire after one confirmation that no workflow still reads the old map |
| `.claude/idle-reports/`, `.claude/plans/`, `.claude/specs/`, `.claude/gt-v5-taslak/`, `.claude/schema-snapshots/`, `.claude/draft-migrations/` | tracked, 25 files | **historical evidence** — cited by goal/report records | keep tracked as history; no action |
| `.claude/` untracked mass (archive/, idle-gorevler/, skills/, knowledge/, notes/, goals/, reviews/, eksikler/, arch-decisions/, agents/, scripts/, gwen, ideas/, tasks/, security-report.md, …) | untracked, user-owned | **local working state** — owner's active notes and archived transcripts | keep untracked; optional: add one `.gitignore` section to make the local/working split explicit |
| `.agents/skills/` (15 skills incl. code-change-precheck, memory-update, tools-bank-mcp, gitnexus-*, orchestrator-master) | untracked, **actively used by ZCode sessions** | **runtime adapter surface, in use** | keep until each skill has a harness-owned replacement or is explicitly retired; do NOT clean while sessions still load them |
| `.agents/` non-skill files (QWEN.md, setup.sh, mcp/, pre-commit.hook, …) | untracked | **local-state / deprecated-candidate** (qwen-related) | propose retire with the qwen cleanup below |
| `.qwen/` | untracked | **deprecated-candidate** — qwen runtime config | retire after an owner confirms qwen is no longer used |
| `.commandcode/taste`, `.mimosa/hook-state` | untracked | **local state** | keep untracked; no action |
| `.harness/design/` 4 process artifacts (review prompts, review outputs, compact handoff) | untracked | **historical evidence** (the canonical SPEC/PLAN are now tracked) | optional: track alongside SPEC/PLAN, or leave as local history — owner preference |
| `/root/egesut-erp1` hard-coded paths (40 files, all under untracked `.claude/`) | untracked | **local-state debt** | no repo action; if any of those scripts become tracked later, rewrite paths to repo-root discovery first |
| `memory-update` skill + tools-bank vector memory | in active use | **retained** — the plan's retire condition ("if confirmed unused") is NOT met | keep |

## Proposed cleanup manifest (requires explicit owner approval)

1. Retire tracked `.claude/domain-rules.md`, `.claude/rpc-reference.md`,
   `.claude/ui-map.md` after the migrated `.harness/references/` copies are
   confirmed sufficient (rollback: the migrated copies carry full
   provenance headers).
2. Retire `.qwen/` and qwen-related `.agents/` files if the owner confirms
   the qwen runtime is dead.
3. Optionally track the four design process artifacts.
4. Everything else: keep as classified; no action.

## Safety

No bulk deletion, no bulk `git add`, no credential probing; the owner's
dirty main state stays untouched. Archives remain until replacement
acceptance. This proposal itself writes only this report file.

## Execution record (2026-09-04)

The owner approved the full cleanup manifest. Executed in one Fast-mode
gated commit: the three tracked transitional references retired (`git rm`,
recoverable from history; their content — including the owner's pending
2026-09-02 additions — lives in `.harness/references/`), the four design
process artifacts tracked, `AGENTS.md` and the contract re-routed to the
canonical references, the qwen runtime surfaces archived (moved, not
deleted, to `.claude/archive/qwen-retirement-2026-09-04/`), and the two
decision records `D-20260904-HARNESS-ROLLOUT` and
`D-20260904-PHASE6-LEGACY-RETIREMENT` added. No product code, live DB,
hook, or deployment was touched.
