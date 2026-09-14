# W4 — F4: Lock the standard — guard test + decision + ui-map (goal G-20260913-TARIH-SECICI)

You are a WORKER in the ss_org structure. Read the authority files first. If
you hit a question you cannot resolve from the repo, STOP and end your turn
with a question on screen — do not guess.

## Authority (read first)

1. Goal: `.harness/goals/2026/G-20260913-TARIH-SECICI.md` — your scope is
   EXACTLY Phase F4 (F1+F2+F3 are MERGED on your base branch).
2. F1-F3 delivery reports: `.claude/reviews/2026-09-13-tarih-secici-f*-teslim.md`
   — final API surface you are locking.
3. Decision: `.harness/decisions/D-20260909-CANONICAL-DATE-PICKER.md`
4. Reference: `.harness/references/ui-map.md` (where you add the usage
   section).

## Scope — F4

- **Guard test** (extend `tests/unit/tarih-saf.test.js` or a new sibling —
  if a new file, name it EXACTLY `tests/unit/tarih-guard.test.js` and
  report it so the goal manifest is updated first; extending the existing
  file avoids that): fails the suite when
  (a) `type="date"` appears in `index.html` or `js/*.js`;
  (b) `toLocale`/`toLocaleString`/`new Date(` with a STRING argument
  appears in `js/tarih/tarih.js` (pure-layer ban);
  (c) the known calendar-copy symbols (`bcTarihTakvim`, `bcTakvimRender`,
  `caseGunModalRender` inline grid loops) reappear as month-grid
  renderers — implement as: these symbol names must not contain their own
  day-cell loop; practical check = they must call `tarihAyIzgara` (F3
  consolidated them; pin that).
  **Close the F1 audit carry-over:** the guard must strip BLOCK comments
  (`/* */`), not only `//` lines, before scanning, and must also ban bare
  `new Date()`/`Date.now()` inside `js/tarih/tarih.js` (current-`now`
  dependency breaks pure determinism; the component passes `simdi` in).
- **Red-before evidence:** demonstrate the guard actually fires —
  temporarily inject a violation, show the test fail, remove it, show it
  pass. Put both outputs in the report.
- **Decision record update:** `D-20260909-CANONICAL-DATE-PICKER.md` gains
  the "this is THE single date-entry component" statement + the public API
  table (`tekTarihTakvimAc` options `{baslik, deger, onSec, min, max,
  temizlenebilir, kapaliGun}` + `tarihAlaniBagla(id, opts)` + pure-layer
  exports). Status stays accepted; supersede only if the existing record
  demands it (read it first).
- **ui-map update:** `.harness/references/ui-map.md` gains a canonical
  date-picker usage section: how to bind a field, what NOT to do (no
  native date inputs, no locale-dependent formatting, no copy grids).
- **`?v=` stamp:** docs-only + test changes do not require a stamp bump;
  if you touch no runtime source, do NOT bump. If you must touch a runtime
  source for the guard to compile, bump to ONE common value across ALL
  stamped sources in the same commit.

## Rules

- Baseline first: unit suite clean (known-red
  `tests/unit/gecmis-pipeline.test.js:283` expected; zero NEW reds).
- No DB access. No migrations. Do not touch main; commit only on YOUR
  branch.
- Do not refactor product code beyond what the guard legitimately needs.

## Mandatory review before delivery (owner standing rule)

Run a builtin subagent code review on your own diff (guard bypassability +
docs accuracy). Attach the finding note (`bulgu: ...` / `bulgu yok`) to
your report. No report without the note.

## Delivery format (exact — the waiter matches on this)

Commit everything on your branch, with a delivery report at
`.claude/reviews/2026-09-13-tarih-secici-f4-teslim.md` containing, in order:

1. Branch name + final commit SHA
2. Changed files (git diff --stat against your base)
3. Guard evidence: red-before output (violation injected → fail) and
   green-after output
4. Docs: decision record + ui-map section summaries (paths + what changed)
5. Test evidence: unit baseline → final
6. `?v=` stamp state
7. Review note: `bulgu: ...` or `bulgu yok`
8. Open risks / deferred items

End your turn after the report is committed.
