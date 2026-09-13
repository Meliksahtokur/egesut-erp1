# W2 — F2: Binding helper + migrate all 15 native date inputs (goal G-20260913-TARIH-SECICI)

You are a WORKER in the ss_org structure. Read the authority files first. If
you hit a question you cannot resolve from the repo, STOP and end your turn
with a question on screen — do not guess.

## Authority (read first)

1. Goal: `.harness/goals/2026/G-20260913-TARIH-SECICI.md` — your scope is
   EXACTLY Phase F2 below (F1 is MERGED on your base branch; F3/F4 NOT
   started).
2. F1 delivery report:
   `.claude/reviews/2026-09-13-tarih-secici-f1-teslim.md` — the pure-layer
   API you will consume (`tarihParse`, `tarihIsoTr`, `tarihAraliktaMi`,
   `TARIH_AY_ADLARI`, …) and the grid contract (`out-of-month = null`,
   `ayIci` present-but-always-true in v1).
3. Decision: `.harness/decisions/D-20260909-CANONICAL-DATE-PICKER.md`
4. `code-change-precheck` skill BEFORE editing js/ui.js, js/forms.js,
   js/app.js symbols. NOTE (measured, W1): the repo PreToolUse hook
   `blast-radius-check.sh` requires a fresh GitNexus impact run before ui.js
   edits; tools-bank impact wrapper fails in worktrees
   (`/root/egesut-erp1` permission) — use direct `mcp__gitnexus__impact` +
   built-in LSP, then satisfy the hook as W1 did.

## Scope — F2

- **Binding helper `tarihAlaniBagla(id, opts)`** (in js/ui.js, near the
  canonical component): converts a native `<input type="date">` into a
  readonly TR field/button that opens `tekTarihTakvimAc`, with a HIDDEN
  holder that preserves the `.value -> ISO` contract. HARD CONSTRAINT: JS
  that reads these fields does `el.value` and expects ISO (`YYYY-MM-DD`)
  and reset code sets `.value = ''` — the reader contract MUST NOT change
  (if you find a field where this is impossible, STOP and report the field
  id + reader list instead of changing readers). Options to support: `min`,
  `max` (ISO strings), `temizlenebilir`, `kapaliGun`.
- **Migrate ALL 15 native inputs** (verify each with grep before touching;
  line hints from the goal): the 14 in index.html (`k-tarih`, `i-tarih`,
  `tr-tarih`, `v-date`, `bv-tarih`, `sk-tarih`, `b-tarih`, `a-dt`,
  `ta-tarih`, `td-asi-tarih`, `td-rapel-tarih`, `te-tarih`, `cx-tarih`,
  `geb-tarih`) + the 1 dynamically generated `type="date"` in js/ui.js.
  After migration `grep -c 'type="date"' index.html js/*.js` must be 0.
- **Sensible min/max per field** (goal F2 bullet): birth/event-style dates
  must not be in the future (`b-tarih` etc.); task/rapel/treatment dates
  may be future. If a field's semantics are unclear from context, prefer
  NO bound over a wrong bound, and note it in the report.
- **Playwright spec** `tests/tarih-secici.spec.js` (EXACT filename, goal
  manifest): mobile viewport (Android-Firefox-like) + `en-US` locale; at
  least `b-tarih`, `a-dt`, `i-tarih` open the TR calendar and save correct
  ISO. Demo DB only (existing e2e conventions in tests/*.spec.js — follow
  them, incl. how they avoid prod writes). The spec must FAIL on the old
  native behavior conceptually (red-before via the native input being
  replaced — document your red-before approach in the report; if the page
  cannot be rendered in e2e for a field, say so explicitly rather than
  weakening the test silently).
- **`?v=` stamp:** this phase visibly changes source files users cache —
  bump the stamp to ONE new common value (e.g. `20260913-15`) across ALL
  stamped local sources in index.html in the SAME commit. Partial bump is
  an automatic F-finding (repo lesson).

## Rules

- Measure your baseline first: unit suite + `git status` clean start on
  your branch (base = lead branch at F1 merge `c220b0f`).
- Known-red `tests/unit/gecmis-pipeline.test.js:283` expected; zero NEW
  reds allowed.
- No DB access beyond what existing e2e conventions already use (demo).
  No migrations. Do not touch main; commit only on YOUR branch.
- Do not start F3 (`bcTakvim*`/`bcTarihTakvim*`/`caseGunModalRender`
  refactor) or F4 (guard test + docs updates) work.
- Reset points that must keep working: app.js:600, ui.js:7854 (verify with
  the field ids they touch).

## Mandatory review before delivery (owner standing rule)

Run a builtin subagent code review on your own diff (correctness + contract
fit + XSS + reader-contract preservation). Attach the finding note
(`bulgu: ...` / `bulgu yok`) to your report. No report without the note.

## Delivery format (exact — the waiter matches on this)

Commit everything on your branch, with a delivery report at
`.claude/reviews/2026-09-13-tarih-secici-f2-teslim.md` containing, in order:

1. Branch name + final commit SHA
2. Changed files (git diff --stat against your base)
3. Test evidence: unit baseline → final; Playwright spec result (count);
   `grep -c 'type="date"' index.html js/*.js` output (must be 0 matches)
4. Field migration table: field id → reader contract preserved? min/max
   applied? notes
5. `?v=` stamp state (new common value, all sources stamped)
6. Review note: `bulgu: ...` or `bulgu yok`
7. Open risks / deferred items

End your turn after the report is committed.
