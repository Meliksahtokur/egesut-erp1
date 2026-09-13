# W3 — F3: Consolidate calendar copies onto the canonical core (goal G-20260913-TARIH-SECICI)

You are a WORKER in the ss_org structure. Read the authority files first. If
you hit a question you cannot resolve from the repo, STOP and end your turn
with a question on screen — do not guess.

## Authority (read first)

1. Goal: `.harness/goals/2026/G-20260913-TARIH-SECICI.md` — your scope is
   EXACTLY Phase F3 (F1+F2 are MERGED on your base branch; F4 NOT started).
2. F1 delivery report: `.claude/reviews/2026-09-13-tarih-secici-f1-teslim.md`
   — pure-layer API + grid contract. Lead confirms for F3: keep
   `out-of-month = null`; if a component needs adjacent-month cells,
   extend `tarihAyIzgara` to emit `{iso, gun, ayIci:false}` cells INSTEAD of
   `null` for those positions, update the grid unit tests in the same
   commit, and declare the contract change in your report.
3. Decision: `.harness/decisions/D-20260909-CANONICAL-DATE-PICKER.md`
4. `code-change-precheck` BEFORE editing js/forms.js / js/ui.js symbols
   (same PreToolUse hook notes as F1/F2: direct `mcp__gitnexus__impact` +
   built-in LSP, then satisfy the hook as W1/W2 did).

## Scope — F3

- **`bcTarihTakvim*` REMOVED** (forms.js:1812+ — single-select treatment
  date; the canonical's functional twin with closed-day disabling). Find
  ALL its callers (grep before touching), repoint them to
  `tekTarihTakvimAc` + `kapaliGun(iso)` (and `min`/`max`/`temizlenebilir`
  where the old behavior had them). After migration:
  `grep -n "bcTarihTakvim" index.html js/*.js` returns nothing (except
  possibly the F1 comment markers — if any remain, remove them too).
- **`bcTakvim*` (forms.js:1615-1799, multi-select)** moves its grid
  generation onto the shared core `tarihAyIzgara`. Multi-select behavior
  and the W13 month-paging fix MUST be preserved — existing tests stay
  green.
- **`caseGunModalRender` + `_gunSecim*` (ui.js:6644+)** moves onto the
  same shared core. Case-days modal behavior unchanged.
- **Close the F1 audit carry-over:** the canonical's `kapaliGun` +
  `temizlenebilir` UI behavior (closed cell rendered disabled, no
  onclick; Onayla refuses; Temizle → `onSec(null)`) currently has no
  automated test. Add a DOM-level test — reuse W1's vm-sandbox approach
  (TESTING-01 `loadBrowserModule`) or a Playwright case in
  `tests/tarih-secici.spec.js`; your choice, declare it in the report.
- **Close the F2 audit carry-over (ORTA):** the F2 binding layer
  (`tarihAlaniTakvimAc`, js/ui.js ~7018-7045) passes only
  `baslik/deger/min/max/temizlenebilir/onSec` to the canonical — a
  `kapaliGun` option in the `TARIH_ALANLARI` schema would be SILENTLY
  DROPPED. Wire `kapaliGun` through the schema + the call (one line +
  schema field), so F3's `bcTarihTakvim` migration can express closed days
  through the binding layer without a silent no-op. No field uses it yet —
  the deliverable is the plumbing, not a field.
- **`?v=` stamp:** bump to ONE new common value across ALL stamped local
  sources in index.html in the SAME commit (F2 already bumped once; use
  its value +1 style, e.g. `20260913-16`). Partial bump = automatic
  F-finding.

## Rules

- Baseline first: unit suite on your clean branch before changes
  (known-red `tests/unit/gecmis-pipeline.test.js:283` expected; zero NEW
  reds).
- Behavior preservation is the bar: the two multi-select modals must keep
  their current selection semantics, chip labels, W13 fix. If an existing
  test pins behavior you'd break, the test is right and your code is
  wrong.
- Do not touch the F2 binding helper (`tarihAlaniBagla`) or the 15 migrated
  fields. Do not start F4 (guard test + docs updates).
- No DB access. No migrations. Do not touch main; commit only on YOUR
  branch.

## Mandatory review before delivery (owner standing rule)

Run a builtin subagent code review on your own diff (correctness + behavior
preservation + XSS). Attach the finding note (`bulgu: ...` / `bulgu yok`)
to your report. No report without the note.

## Delivery format (exact — the waiter matches on this)

Commit everything on your branch, with a delivery report at
`.claude/reviews/2026-09-13-tarih-secici-f3-teslim.md` containing, in order:

1. Branch name + final commit SHA
2. Changed files (git diff --stat against your base)
3. Test evidence: unit baseline → final; kapaliGun/temizlenebilir DOM test
   result; `grep -n "bcTarihTakvim" index.html js/*.js` output (empty)
4. Caller repoint table: old symbol → new call → behavior deltas (want: none)
5. Grid contract state (adjacent-month cells adopted? yes/no + why)
6. `?v=` stamp state (new common value, all sources stamped)
7. Review note: `bulgu: ...` or `bulgu yok`
8. Open risks / deferred items

End your turn after the report is committed.
