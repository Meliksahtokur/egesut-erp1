# W-R1 REVİZYON — R1 denetim bulguları (goal G-20260913-TARIH-SECICI-R1)

You are the same worker (W-R1), continuing on YOUR branch
`agent/tarih-secici-standardi-R1`. The independent audit returned REVİZYON.
Fix the findings below, re-run the gates, update your delivery report, commit
with `R1` in the message. Do NOT merge. If a question stops you, end your
turn with the question on screen.

Authority: audit report
`.claude/reviews/2026-09-13-tarih-secici-r1-denetim.md` (committed on
`agent/tarih-secici-r1-denetim`; findings quoted below with their probes) +
your own previous delivery report `.claude/reviews/2026-09-13-tarih-secici-r1-teslim.md`.
Keep everything that was verified TEMİZ intact (three-surface wiring, mobile
preservation, guard/damga state).

## Findings → required fixes

1. **KRİTİK — maske taşması yanlış-geçerli ISO üretip Uygula kabul ediyor**
   (`js/tarih/tarih.js:154-168`, probe: `151.12.2026` → mask drops the
   overflow digit and yields `15.11.2202` with an error, but Apply only runs
   `tarihGirisCoz('15.11.2202')` → `{ok, iso:'2202-11-15'}` — wrong but
   VALID date accepted). Fix BOTH layers:
   a) maske: on segment overflow do NOT rewrite/drop digits — keep the
      user's typed text and raise the segment error (mask must never
      produce a silently different date);
   b) Uygula (all three surfaces' apply paths wired through
      `tarihSeciciMaskeBagla`): if the last mask result carries `hata`,
      reject with that message BEFORE calling `tarihGirisCoz`.
   Pin with unit tests: `tarihMaskeUygula('151.12.2026')` (or the equivalent
   mask call) keeps the typed text + returns non-null `hata`; a DOM-level
   test where Apply with a pending mask error does NOT call `onSec`.

2. **ORTA — rakam-dışı junk sessizce siliniyor** (`tarih.js:154`,
   probe: mask `05.02.2026abc` → `05.02.2026`, Apply accepts). Fix: separators
   (`.` `,` `/` `-` space) normalize as today, but ANY other non-digit
   character must NOT be silently removed — mark an error (e.g. "Rakam
   girmelisiniz") and leave the text. Update the wrong acceptance assertion
   at `tests/unit/tarih-saf.test.js:224-225` (`'ab?!12cd2026'` currently
   expected to clean to `12.20.26`) to expect a mask ERROR instead.

3. **DÜŞÜK — `00` alt sınırı maske tarafından görülmüyor** (`tarih.js:162-164`
   only checks the upper bound; `tarihMaskeUygula('00')` → no error). Fix:
   day/month segment value `0` (or `00`) raises the segment error.

4. **DÜŞÜK — bcTakvim offset yılları taşırıyor** (`js/forms.js:1704-1706`;
   probe: base `9999-12-01`, ‹/› → year 10000, empty grid, year option `10000`).
   Fix: after offset update clamp the month/year to 1..9999 (refuse the
   paging step beyond the edge).

5. **DÜŞÜK — caseGun yıl kelepiri ayı bozuyor** (`js/ui.js:6739-6743`;
   probe: 1-Ocak ‹ → {y:1,m:11} (1-Aralık), 9999-Aralık › → {y:9999,m:0}).
   Fix: when the year clamp fires, do not apply the raw modulo — keep the
   edge month/year (paging refused at the boundary) or recompute month/year
   consistently; declare which.

6. **DÜŞÜK — e2e üç-yüzey kapsamı** (audit: R1 browser tests drive only
   tekTarih). NOT required to fix by test — declare it as a measured
   limitation in your report (unit layer covers bcTakvim via
   vaka-toplu-ac; caseGun runtime coverage is a deferred gap).

## Gates (worker runs them, report the outputs)

- Unit: full suite, expected ≥ 857 tests, ONLY known `_gmGroupHtml` red.
- New unit pins: mask overflow keeps text + error (KRİTİK), junk → error
  (ORTA), `00` → error (DÜŞÜK-3).
- Playwright `tests/tarih-secici.spec.js` must stay 9/9 (the `11122026`
  mask happy path must keep passing — the fix must not break legit entry).
- `?v=` stamp: unchanged (no further bump needed if runtime files change —
  actually YES: js/tarih/tarih.js + js/forms.js + js/ui.js change → bump to
  ONE new common value `20260913-18` across ALL stamped sources in the same
  commit).
- Guard whitelist: unchanged names expected (no new Takvim/GunSecim names).

## Mandatory review before delivery (owner standing rule)

Run a builtin subagent code review on your own fix diff. Attach
`bulgu: ...` / `bulgu yok`.

## Delivery format (exact)

Update `.claude/reviews/2026-09-13-tarih-secici-r1-teslim.md` — append a
"## REVİZYON TURU" section: per-finding fix table (1-6 → what changed →
files → test pins), gate outputs (unit count, Playwright 9/9, stamp state),
review note. Commit message contains `R1`. End your turn after committing.
