---
id: G-20260911-PEDIGREE-P1-TEMEL
status: active
owner: root
flow: ss_org
created: 2026-09-11
base_sha: 0dccaeb
branch: idle/pedigree-p1
write_manifest:
  - supabase/migrations/
  - tests/sql/
  - .claude/idle-reports/2026-09-11-pedigree-p1.md
  - .claude/reviews/2026-09-11-pedigree-p1-lead-review.md
review_lane: codex_luna_max_bounded
implement_lane: glmf_workers
---

# G-20260911-PEDIGREE-P1-TEMEL — Pedigree P1 "Temel" package

- **Status:** ACTIVE
- **Date:** 2026-09-11
- **Base SHA:** 0dccaeb (main tip at dispatch; includes this goal's input files)
- **Owner directive (2026-09-11):** Start pedigree implementation via the
  ss-org network. Lead (GLM) coordinates; workers are GLMF. Root verifies the
  lead branch and merges to main or sends back for revision. `git push`,
  PROD deploy, and demo-show approval stay with the owner.
- **Authority:** implementation plan
  `.claude/plans/2026-09-10-pedigree-genetics-impl.md` (Rev 3 + buzagi_id
  acceptance ac537f8) — P1 scope is EXACTLY Task 0.1-0.5, Task 1, Task 2.
  Task 3 and later belong to P2+ and are out of scope.

## Scope

| Wave | Task | Deliverable | Gate |
|---|---|---|---|
| W1 (parallel) | Task 0.5 | `dogum.buzagi_id` foundation migration + `tests/sql/dogum_buzagi_id_test.sql` + conservative backfill report | G0b |
| W2 | Task 1 | pedigree foundation migration (nodes/parentage/semen_catalog/pedigree_meta, assert_is_operator, helpers, RLS+grants) + `tests/sql/pedigree_graph_test.sql` | G1 |
| W3 (after W2) | Task 2 | farm nodes backfill + maternal edges (buzagi_id FK predicate) + `pedigree_integrity_report()` 18-code universe + idempotency test | G2 |

Task 0.1/0.2 (baseline freeze, live schema re-verify): lead records current
sha + verifies the existing probe evidence (`.claude/reviews/2026-09-10-live-probe-evidence.md`)
is still the reference; any live re-measurement goes through root (`ss-ask`).
Task 0.3 inventory is ALREADY measured and committed
(`.claude/specs/2026-09-10-pedigree-semen-mapping.md`, draft — owner review
is a Task 8/P3 gate, NOT blocking here). Task 0.4 (ET decision) is an owner
gate for Faz 7 only — record it as an open item, do not wait.

## Acceptance criteria (mechanical)

1. **G0b:** `dogum_buzagi_id_test.sql` green on demo DB: unique-violation
   reject, SET NULL behavior (calf DELETE → dogum survives, buzagi_id NULL),
   all four backfill classes (auto / multi-candidate / date-mismatch / none),
   `dogum_kaydet` writes buzazi_id in-transaction. Backfill report has the
   four counters.
2. **G1:** `pedigree_graph_test.sql` green: farm-node idempotent create,
   dam/sire unique, self-parent reject, cycle reject, parent-edge on
   explicit founder rejected, sex normalization (Erkek→male, Dişi→female),
   operator-guard fail-closed without op_owner_uid, grants are
   authenticated-only, birth-path bypasses guard via INTERNAL core.
3. **G2:** `pedigree_integrity_report()` on demo DB: blockers==0 with fixture
   data; 18-code emission rules (absent group not emitted; cutoff
   `tanimsiz` skips the post-cutoff group); maternal edges follow the
   buzagi_id FK predicate; backfill is idempotent (second run adds no
   nodes/edges).
4. **Suite:** `npm run test:unit` — existing suite must not regress
   (the known-red gecmis-pipeline DÜN test on main pre-dates this goal).
5. **Migration discipline:** replay-safe (idempotent DO blocks), farm_id
   DEFAULT `'400b9107-...'` + indexes leading with farm_id, RLS
   `USING(true)`, every grant lives in the migration that creates its object,
   exact signatures per plan Task 1.3/1.4.
6. **Report:** `.claude/idle-reports/2026-09-11-pedigree-p1.md` with evidence
   lines (command output / SHA) per criterion + crumbs discipline kept.

## DB access rules (owner standing directive)

- Demo DB: migrations + test runs FREE. Demo rows are USER DATA — list before
  any cleanup/restore.
- PROD: NO access from lead/workers. Needed live measurements go to root via
  `ss-ask --class cross`. PROD writes (deploy) are owner-gated — zero
  tolerance.
- A committed migration is NOT a deployment.

## Review lane — BOUNDED (owner standing rule, 2026-09-10 lesson)

- Lead opens ONE independent Codex (luna max) review round for Task 1
  (architecture/interface class) before merging W2 into the lead branch.
  Findings return to the SAME worker; verification is the mechanical gate,
  not a second review round. Second round only if the defect CLASS changes.
- Root merge gate: at most ONE revision round after root's own verification.
- Anti-manipulation: the review envelope carries neutral material only
  (envelope + git diff), no author summaries as facts, no verdict coaching;
  findings are relayed verbatim.

## Stop conditions

- Any PROD access requirement → stop, `ss-ask` root.
- Plan/spec contradiction inside P1 scope → `ss-ask --class cross` to root.
- Demo DB state blocks a test (fixture conflict) → record, ask lead.
- Unit suite regression beyond the known-red test → fix before delivery.

## Out of scope

Task 3+ (projection RPC, UI), P2-P4 packages, GT regeneration, push, deploy,
`js/` frontend files, semen mapping owner decision (P3 gate).
