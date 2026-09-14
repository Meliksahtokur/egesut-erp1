# W-R1 — Sahip testi revizyonu: tarih seçimi UI + el girişi (goal G-20260913-TARIH-SECICI-R1)

You are a WORKER in the ss_org structure. Read the authority files first. If
you hit a question you cannot resolve from the repo, STOP and end your turn
with a question on screen — do not guess.

## Authority (read first)

1. Goal: `.harness/goals/2026/G-20260913-TARIH-SECICI-R1.md`
2. Task envelope (owner, verbatim): `/home/melik/egesut-erp1/.ss/tasks/R1-tarih-secici-revizyon.md`
   — the 5 findings are the contract; this file adds implementation detail.
3. `code-change-precheck` BEFORE editing js/ui.js / js/forms.js symbols.
   Measured environment notes: GitNexus index is stale for recent symbols —
   use built-in LSP findReferences + grep for real blast radius; satisfy the
   PreToolUse `blast-radius-check.sh` hook as earlier workers did (real
   analysis, then `/tmp/blast-radius-done` stamp).
- Known-red baseline: unit suite 836/835/1 (`_gmGroupHtml` date-bomb — DO
  NOT touch it; zero NEW reds).

## Implementation notes (verified surfaces — re-verify before touching)

- The canonical calendar lives in `js/ui.js` `tekTarihTakvimAc` block
  (~ui.js:6752+ after F1-F3 merges; grep `function tekTarihTakvimAc` for the
  current line). It renders with INLINE styles; ‹ › month paging buttons are
  small dark-on-light today.
- Multi-day treatment calendar `bcTakvim*` (js/forms.js) and case-days modal
  `caseGunModalRender` (js/ui.js) have their own inline styles — the owner's
  findings apply to ALL three ("Tüm tarih seçim ekranlarında aynı").
- Pure layer: `js/tarih/tarih.js` (`tarihParse` accepts `.`/`/`/`-`
  separators today; `,` and space are NOT accepted yet).
- F4 guard in `tests/unit/tarih-saf.test.js`: calendar-semantic function
  names (`/Takvim|GunSecim/i`) must be in the whitelist constant — add any
  NEW function name you introduce there deliberately.

## Work items (owner findings 1-5)

1. **Nav buttons:** ‹ › (month AND year paging) bigger, dark background
   with high-contrast light glyph, touch target ≥ 40px (min-width+min-height)
   — in all three calendars.
2. **Desktop compact modal:** media-query or JS width handling so the modal
   is ~360–420px max, centered, small square day cells on wide screens
   (≥ ~900px viewport); mobile (narrow) keeps the CURRENT full-width look
   UNCHANGED (owner: "telefonda gayet iyi"). Same treatment in all three.
3. **Manual entry mask + tolerance:**
   - digits auto-dot mask while typing: `11122026` → `11.12.2026`;
     deleting/backspacing must feel natural (mask must not fight the user —
     implement as input-event transform, keep caret sane);
   - separators `,` `/` `-` and space normalize to `.` (owner saw
     `13,09,2026` fail today);
   - segment limits while typing: day 01–31 (and real month length on
     commit), month 01–12; invalid segment (`90` day) either blocked or
     immediately flagged — owner's words: "yazılamasın ya da anında işaretlensin";
   - `inputmode="numeric"`, Enter = Uygula; a valid entry jumps the calendar
     to that month AND selects it; error message names the wrong segment
     (e.g. "Ay 1–12 olmalı");
   - NEVER `mm/dd` (existing rule — `tarihParse` tests already pin it).
   - Put the pure mask/normalize/segment functions in `js/tarih/tarih.js`
     (testable), wire them in the component.
4. **Month + year dropdowns in the header** (owner sketch): Turkish month
   list (TARIH_AY_ADLARI) + year select; keep the ‹ › month paging. Year
   range derived from the bound field's min/max (birth: past years
   dominated; task dates: a few future years). Sensible defaults when a
   bound is absent (e.g. max-absent → min+120y; min-absent → max-120y) —
   declare your choice in the report. Wire the same into `bcTakvim` and
   `caseGunModalRender` headers.
5. **Font sizes:** header, month/year selectors and error text noticeably
   larger; do not break the mobile layout.

## Hard constraints

- `?v=` stamp: runtime changes → bump to ONE new common value
  (`20260913-17`) across ALL stamped sources in index.html in the SAME
  commit. Partial bump = automatic F-finding.
- Reader `.value` → ISO contract and hidden-holder design stay intact.
- Guard tests must stay green: `type="date"`=0, copy-symbol ban, saf-layer
  bans, name whitelist (add your new names), stamp-guard tests updated to
  the new value.
- `git merge` FORBIDDEN (root integrates). main untouched. Commit only on
  YOUR branch; every commit message contains `R1`.
- No DB writes; Playwright uses the existing demo gate pattern.

## Mandatory review before delivery (owner standing rule)

Run a builtin subagent code review on your own diff (correctness + UX
constraints + mobile preservation + guard fit). Attach the finding note
(`bulgu: ...` / `bulgu yok`) to your report. No report without the note.

## Delivery format (exact — the waiter matches on this)

Commit everything on your branch; delivery report at
`.claude/reviews/2026-09-13-tarih-secici-r1-teslim.md` containing, in order:

1. Branch name + final commit SHA (message contains R1)
2. Changed files (git diff --stat against your base)
3. Test evidence: unit baseline → final (guard included); Playwright
   results: desktop 1920×1080 modal width ≤440px check, mobile 412×915
   unchanged, dropdown selection, `11122026` mask entry
4. Per-finding table: finding 1-5 → what changed → files
5. New function names added to the guard whitelist
6. `?v=` stamp state (new common value, all sources)
7. Review note: `bulgu: ...` or `bulgu yok`
8. Open risks / deferred items

End your turn after the report is committed.
