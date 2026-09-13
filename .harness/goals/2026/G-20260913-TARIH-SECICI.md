---
id: G-20260913-TARIH-SECICI
status: in_progress
owner: root
flow: ss_org
created: 2026-09-13
base_sha: 621f12a
branch: agent/tarih-secici-standardi
worktree: /home/melik/.superset/worktrees/1dddb562-abe3-495c-970e-872567945510/agent/tarih-secici-standardi
report: .harness/reports/2026-09-13-tarih-secici-teslim.md
write_manifest:
  - index.html                        # 14 native date input -> tarihAlaniBagla binding
  - js/ui.js                          # tekTarihTakvimAc hardening + tarihAlaniBagla + caseGunModalRender grid refactor + dynamic input
  - js/forms.js                       # bcTarihTakvim*/bcTakvim* consolidation + field readers (value contract preserved)
  - js/app.js                         # reset points (app.js:600) keep working
  - js/tarih/tarih.js                 # NEW pure date layer + grid core (single module, name FIXED by harness manifest matching)
  - tests/unit/tarih-saf.test.js      # pure-layer + grid core unit tests (name FIXED)
  - tests/unit/tarih-guard.test.js    # F4 guard test (optional new file; may extend tarih-saf instead)
  - tests/unit/vaka-toplu-ac.test.js  # F2: stamp/manifest guard tests updated in place (existing file)
  - tests/tarih-secici.spec.js        # Playwright mobile-viewport TR calendar spec (F2+, demo DB)
  - .harness/decisions/D-20260909-CANONICAL-DATE-PICKER.md   # F4: "this is THE component" + API
  - .harness/references/ui-map.md     # F4: canonical date picker usage section
  - .harness/goals/2026/G-20260913-TARIH-SECICI.md
  - .harness/reports/2026-09-13-tarih-secici-teslim.md
  - .claude/tasks/2026-09-13-tarih-secici-f1.md
  - .claude/tasks/2026-09-13-tarih-secici-f2.md
  - .claude/tasks/2026-09-13-tarih-secici-f3.md
  - .claude/tasks/2026-09-13-tarih-secici-f4.md
  - .claude/tasks/2026-09-13-tarih-secici-luna.md
  - .claude/reviews/2026-09-13-tarih-secici-f1-teslim.md
  - .claude/reviews/2026-09-13-tarih-secici-f2-teslim.md
  - .claude/reviews/2026-09-13-tarih-secici-f3-teslim.md
  - .claude/reviews/2026-09-13-tarih-secici-f4-teslim.md
  - .claude/reviews/2026-09-13-tarih-secici-luna-review.md
pattern_refs:
  - FORM-SUBMIT-01    # form field binding/value conventions
  - MODAL-ROUTER-01   # router-managed modal pattern (calendar modals)
  - TESTING-01        # unit + stub-backend test pattern
pattern_exceptions: []
docs_authority:
  tracked_paths:
    write:
      - .harness/goals/2026/G-20260913-TARIH-SECICI.md
      - .harness/decisions/D-20260909-CANONICAL-DATE-PICKER.md
      - .harness/references/ui-map.md
      - .harness/reports/2026-09-13-tarih-secici-teslim.md
      - .claude/tasks/2026-09-13-tarih-secici-*.md
      - .claude/reviews/2026-09-13-tarih-secici-*.md
review_lane: codex_luna_max_bounded
implement_lane: glmf_workers
---

# G-20260913-TARIH-SECICI — Single canonical date picker standard

- **Status:** IN_PROGRESS (2026-09-13, owner /goal directive)
- **Task envelope:** `/home/melik/egesut-erp1/.ss/tasks/L1-tarih-secici-standardi.md`
  (owner-authored; verbatim authority for scope)
- **Goal:** every date entry in the app flows through the canonical component
  `tekTarihTakvimAc` (js/ui.js:6752, decision
  `.harness/decisions/D-20260909-CANONICAL-DATE-PICKER.md`). No browser/OS
  locale may surface (`mm/dd/yyyy` native dialogs). Screen format is always
  `gg.aa.yyyy`, Turkish month/day names, Monday first.

## Measured corrections to the task inventory (lead, 2026-09-13)

1. **CORRECTED AGAIN (F2 audit):** the lead's initial "15th dynamic input"
   claim was a GHOST — the js/ui.js grep hit was a COMMENT line, not a
   real input. Actual native inputs = **14** (all in index.html), all
   migrated in F2; source `type="date"` grep is 0 (acceptance met; runtime
   `input.type='date'` property assignment on the hidden holder is a
   deliberate, documented exception that keeps modal.js auto-fill working).
   Earlier claim kept here for the audit trail.
2. Task asks for the delivery report at `reports/…` but `reports/` is
   gitignored (`.gitignore:122`; only `.harness/reports/` is excepted).
   Report path is therefore `.harness/reports/2026-09-13-tarih-secici-teslim.md`.
   Deviation recorded here and in the report itself; root may relocate.
3. Symbol inventory verified at base 621f12a by runner + lead grep:
   `bcTakvim*` forms.js:1615-1799 (multi-select), `bcTarihTakvim*`
   forms.js:1812+ (single-select, canonical's functional twin),
   `caseGunModalRender` ui.js:6644 + `_gunSecim*` state ui.js:6641-6642,
   `bcIsoTrGoster` forms.js:943, `bcTrGosterIso` forms.js:954,
   `tekTarihTakvimAc` ui.js:6752. Line numbers are hints; workers re-verify.

## Phases (sequential; each phase = worker + merge into this branch)

- **F1 — Harden the canonical component.** Year selection from header
  (‹/› month paging stays). Manual entry `gg.aa.yyyy` (accept and normalize
  `gg/aa/yyyy`, `gg-aa-yyyy`, 2-digit year `gg.aa.yy`; invalid date → explicit
  error, NO silent correction, NEVER `mm/dd` interpretation). Options: `min`,
  `max`, `temizlenebilir`, `kapaliGun(iso)`. Pure layer (no DOM, no locale,
  string ops only; `toLocale*`/`new Date(string)` parsing FORBIDDEN — follow
  existing `bcIsoTrGoster`/`bcTrGosterIso` approach). Shared pure month-grid
  core `(yil, ay) -> cell list` used by single/multi components.
- **F2 — Binding helper + migrate all 15 native inputs.** Helper
  (`tarihAlaniBagla(id, opts)`) converts native input into readonly TR
  button/field opening the canonical calendar + hidden ISO value. Reader JS
  `.value -> ISO` contract PRESERVED (readers must not need changes; if the
  contract changes, all readers change in the same phase). Reset points
  (app.js:600, ui.js:7854) keep working. Sensible `min`/`max` per field
  (birth/event dates not in future; task/rapel dates may be).
- **F3 — Consolidate copies.** `bcTarihTakvim*` removed → canonical +
  `kapaliGun`. `bcTakvim*` and `caseGunModalRender` move onto the shared grid
  core; multi-select behavior and the W13 fix preserved (existing tests stay
  green).
- **F4 — Lock the standard.** Unit guard test: new `type="date"` and
  non-canonical month-grid rendering in `index.html`/`js/` fails the suite.
  Update `D-20260909-CANONICAL-DATE-PICKER.md` ("this is THE component" +
  API) and `.harness/references/ui-map.md`.

## Lane rules (owner standing directive 2026-09-11, binding)

1. **Worker subagent review MANDATORY** before lead delivery; finding note
   (`bulgu`/`bulgu yok`) is part of the delivery. Worker runs mechanical
   gates itself.
2. **Lead luna review MANDATORY** (codex max, single pass) before root
   handoff; findings loop back to the same worker.
3. Workload lives in workers; lead orchestrates + small touches.

## Acceptance criteria (root will re-measure)

1. `type="date"` count in `index.html` + `js/` is 0 (grep output in report).
2. All unit tests green (count in report; measure own baseline first — base
   known-red `tests/unit/gecmis-pipeline.test.js:283` exists on main).
3. New pure-layer tests: manual-entry parse (valid/invalid/2-digit-year/
   `mm/dd` trap: `05.02.2026` → `2026-02-05`), year change, min/max,
   month-grid core.
4. Playwright: Android-Firefox-like mobile viewport + `en-US` locale; at
   least birth (`b-tarih`), animal (`a-dt`), insemination (`i-tarih`) fields
   open TR calendar and saved value is correct ISO. Demo DB gate (no prod
   writes).
5. Multi-day treatment modal (bcTakvim) and case-days modal behavior
   unchanged — existing tests + manual steps in report.
6. Delivery report `.harness/reports/2026-09-13-tarih-secici-teslim.md`:
   per-phase commit SHAs, grep evidence, test outputs, residual risks.

## DB access rules

No DB scope at all (frontend-only). Demo DB only for Playwright runs; PROD
NO access (stop + `ss-ask --class cross` to root if ever needed).

## Stop conditions

- PROD/live-DB need → stop + ss-ask cross.
- Reader `.value` contract cannot be preserved for some field → lead
  decision point; if it forces multi-file reader rewrites beyond the 15
  fields' own bindings, ss-ask cross before expanding.
- Pattern deviation (FORM-SUBMIT-01/MODAL-ROUTER-01/TESTING-01) →
  pattern_exceptions entry + lead approval, else no merge.
- Merge conflicts between worker branches → lead resolves on this branch;
  unresolvable semantic conflicts → re-dispatch.

## Out of scope

DB/migration work, PROD anything, push (root/owner), main integration
(root), GT regen, backend RPC changes.
