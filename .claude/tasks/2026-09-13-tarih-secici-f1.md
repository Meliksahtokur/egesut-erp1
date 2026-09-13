# W1 — F1: Harden the canonical date picker (goal G-20260913-TARIH-SECICI)

You are a WORKER in the ss_org structure. Your role contract and this task
file are your envelope. Read BOTH. If you hit a question you cannot resolve
from the repo, STOP and end your turn with a question on screen — do not
guess.

## Authority (read first)

1. Goal: `.harness/goals/2026/G-20260913-TARIH-SECICI.md` — scope, manifest,
   acceptance, stop conditions. Your scope is EXACTLY Phase F1 below.
2. Decision: `.harness/decisions/D-20260909-CANONICAL-DATE-PICKER.md`
3. Contract: `.harness/contract.md` (product invariants, pattern reuse)
4. `code-change-precheck` skill before touching JS symbols (mandated by
   contract for ui.js/forms.js symbol changes).

## Scope — F1 only (NOT F2/F3/F4)

- **Pure date layer** in a single NEW module file `js/tarih/tarih.js`
  (EXACT filename — the goal manifest matches literal paths; do not invent
  other file names under js/tarih/) (DOM-free, locale-free,
  string arithmetic only; `toLocale*` and `new Date(string)` parsing are
  FORBIDDEN — follow the existing `bcIsoTrGoster` (forms.js:943) /
  `bcTrGosterIso` (forms.js:954) string approach; numeric date constructors
  are acceptable only if you cannot avoid them, prefer pure arithmetic):
  - manual-entry parser: accepts `gg.aa.yyyy`, `gg/aa/yyyy`, `gg-aa-yyyy`,
    `gg.aa.yy` (2-digit year normalizes to 2000+yy); returns structured
    result `{ok, iso}` or `{ok:false, error}` with an explicit Turkish error
    message; invalid dates (31.02, month 13, garbage) NEVER silently
    corrected; `mm/dd` interpretation NEVER.
  - min/max validation helper (pure).
  - shared pure month-grid core: `(yil, ay) -> cell list` with Monday-first
    weeks, each cell `{iso, gun, ayIci:boolean}` (leading/trailing blanks as
    `null`). This core is the single source other components will adopt in
    F3 — design it as a pure function, no DOM.
- **Canonical component hardening** in `tekTarihTakvimAc`
  (js/ui.js:6752 — re-verify location first):
  - year selection from the header (existing ‹/› month paging stays);
  - optional manual-entry text field `gg.aa.yyyy` wired through the pure
    parser (invalid input → explicit inline error, no silent fix);
  - new options: `min`, `max`, `temizlenebilir`, `kapaliGun(iso)`
    (closed days rendered disabled, not selectable — this is what
    `bcTarihTakvim` needs in F3);
  - wire the new `js/tarih/` module in `index.html` following the existing
    script-tag + `?v=` stamp convention. **Known trap:** if you bump the
    `?v=` value, EVERY stamped local source must get the SAME value in the
    SAME commit; otherwise keep the current common value.
- **Unit tests** (TESTING-01 pattern) in a single new file
  `tests/unit/tarih-saf.test.js` (EXACT filename) covering at minimum:
  parse valid/invalid/2-digit-year/`mm/dd` trap (`05.02.2026` →
  `2026-02-05`), year selection math, min/max enforcement, month-grid core
  (Monday-first, correct ISO for year boundaries). Guard test MAY come in
  F4 — not required here.

## Rules

- Measure YOUR baseline first: run the unit suite before any change; report
  the count (known-red `tests/unit/gecmis-pipeline.test.js:283` exists on
  main — expected).
- No DB access needed. No migrations. Do not touch `main`; commit only on
  YOUR branch.
- Do not start F2/F3/F4 work (no input migration, no bcTakvim*/caseGun
  refactor, no guard test).
- `?v=` partial-bump trap (above) is a known repo lesson — violating it is
  an automatic F-finding.

## Mandatory review before delivery (owner standing rule)

Before reporting delivery, run a builtin subagent code review on your own
diff (correctness + contract fit). Attach the finding note
(`bulgu: ...` / `bulgu yok`) to your report. No report without the note.

## Delivery format (exact — the waiter matches on this)

Commit everything on your branch, with a delivery report at
`.claude/reviews/2026-09-13-tarih-secici-f1-teslim.md` containing, in order:

1. Branch name + final commit SHA
2. Changed files (git diff --stat against your base)
3. Test evidence: baseline count → final count, with the command used
4. Pure-layer API summary (exported function names + signatures)
5. `?v=` stamp state (value, which files stamped)
6. Review note: `bulgu: ...` or `bulgu yok`
7. Open risks / deferred items

End your turn after the report is committed.
