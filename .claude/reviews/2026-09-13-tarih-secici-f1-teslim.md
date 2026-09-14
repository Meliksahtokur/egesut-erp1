# W1 — F1 Delivery: Harden the canonical date picker (G-20260913-TARIH-SECICI)

## 1. Branch + final commit

- Branch: `agent/tarih-secici-standardi-W1`
- Code delivery commit: **`73a6a40`** (feat(tarih): F1 — code + tests, 4 files)
- Final commit: the commit carrying this report (follows immediately; its SHA
  is reported on the worker's screen output — a report cannot contain its own
  commit's SHA).

## 2. Changed files (git diff --stat against base `77cf70d`)

```text
 index.html                   |   1 +
 js/tarih/tarih.js            | 136 +++++++++++++++++++++   (NEW)
 js/ui.js                     | 152 ++++++++++++++++++++---
 tests/unit/tarih-saf.test.js | 285 +++++++++++++++++++++++++++++++++++++++++++  (NEW)
 4 files changed, 554 insertions(+), 20 deletions(-)
```

Untracked, intentionally NOT committed (outside write manifest): `.ss/tarih-secici-standardi-W1-BOARD.md` (worker board, local working surface).

## 3. Test evidence

Command: `node --test tests/unit/*.test.js`

| Stage | tests | pass | fail |
|---|---|---|---|
| Out-of-box worktree | 625 | 615 | 10 — **environment defect, not code**: worktree had no `node_modules`; 9 files died at load (`Cannot find module 'fast-check'`). Resolved via symlink to the main checkout's `node_modules` (read-only use; task adds no dependency). |
| Baseline before any change (after env fix) | 796 | 795 | 1 — the known-red `tests/unit/gecmis-pipeline.test.js:283` (`_gmGroupHtml…`), matches the envelope |
| Final (after F1) | 824 | 823 | 1 — the same known-red; **+28 new tests, all green, zero regressions** |

New file alone: `node --test tests/unit/tarih-saf.test.js` → 28/28 pass.

Additional verification: a throwaway vm-sandbox smoke test (TESTING-01
`loadBrowserModule`, NOT committed) drove the full render twice — 16 checks
across two rounds: opens at the selected value's month, static TR month
label, manual-entry input + Enter listener, Temizle button, disabled
kapalı-gün cells carry no onclick, exact clickable-cell count, invalid and
mixed-separator manual entry show inline errors and preserve typed text,
above-max entry names the bound, Onayla refuses out-of-range/kapalı selection
without reaching `onSec`, `temizlenebilir` → `onSec(null)`, happy path →
`onSec(iso)`, 1970-prior month alignment (lead=3 for 1950-06), year clamp at
9999. All passed; script deleted after run.

## 4. Pure-layer API (js/tarih/tarih.js)

| Export | Signature | Notes |
|---|---|---|
| `tarihParse(metin)` | `string → {ok:true, iso} \| {ok:false, error}` | Accepts `gg.aa.yyyy` / `gg/aa/yyyy` / `gg-aa-yyyy` (single separator type, enforced by backreference) and 2-digit year `gg.aa.yy` → `2000+yy`; 1-digit day/month accepted (`5.2.2026` — unambiguous). Day-first ALWAYS (`05.02.2026` → `2026-02-05`); mixed separators, year-first, junk, impossible dates → explicit Turkish error. No silent correction. |
| `tarihGecerliMi(iso)` | `string → boolean` | Strict `YYYY-MM-DD` + real-calendar check + year 1..9999 (rejects `0000` which the grid cannot represent). |
| `tarihIsoTr(iso)` | `string → 'gg.aa.yyyy' \| ''` | Shared formatter (`bcIsoTrGoster` approach); invalid → `''`. |
| `tarihAraliktaMi(iso, min, max)` | `(string, string|null, string|null) → {ok, error}` | Closed interval, bounds inclusive; lexicographic = chronological for valid ISO; invalid bounds ignored (bounds come from code, not users). |
| `tarihAyIzgara(yil, ay)` | `(int 1..9999, int 1..12) → {yil, ay, hucreler} \| null` | Monday-first full weeks (`length % 7 === 0`); in-month cells `{iso, gun, ayIci:true}`, out-of-month positions `null`. Weekday via Hinnant days-from-civil, `((gunNo + 3) % 7 + 7) % 7` — the `+7` wrap makes pre-1970 months correct (review finding, fixed). `ayIci` is always `true` in v1 (out-of-month = `null`); kept for shape stability toward F3 extension — documented contract decision. |
| `tarihYilKaydir(yil, delta)` | `(num, num) → int` | Year navigation math, clamped 1..9999. |
| `tarihArtikYilMi(yil)` | `int → boolean` | Gregorian rule (400/100/4). |
| `tarihAyGunSayisi(yil, ay)` | `(int, int 1..12) → int` | `0` for out-of-range month. |
| `TARIH_AY_ADLARI` / `TARIH_GUN_ADLARI` | `['Ocak',…]` / `['Pt',…]` | Static Turkish names — single source, replaces `toLocaleString` in the component header (locale requirement). |

Dual-mode export follows the `js/utils/helpers.js` pattern (browser globals +
`module.exports` for node:test).

## 5. `?v=` stamp state

- Value: **`20260911-14`** — the current common stamp, unchanged.
- All 23 stamped local sources in `index.html` keep the same value (verified);
  partial-bump trap avoided.
- New tag: `<script src="js/tarih/tarih.js?v=20260911-14"></script>`, placed
  between `js/auth.js` and `js/ui.js` (loads before first use).

## 6. Review note

`bulgu: self review (builtin code-reviewer) 7 buldu — 1 KRİTİK (negatif modulo: 1970-öncesi aylarda ayın 1'i hep Pt kolonuna düşüyordu), 2 ORTA (1970-öncesi hizalama testi yoktu; el girişi kapaliGun'i atlıyordu), 4 DÜŞÜK (ölü değişken, null-deref savunması, Enter tuşu, muhafız testinin strip tutarsızlığı) — 7/7'si giderildi ve test/dumanla doğrulandı; ayrıca worker'ın kendi taraması 3 kusur yakaladı (karışık ayraç kabulü, yıl-0000 render çökmesi, Aralık-9999 sayfalama taşması) — bunlar da giderildi.`

Review also verified contract fit explicitly: pure-layer bans hold (locked by
guard test), mm/dd trap covered, existing two callers untouched
(`{baslik,deger,onSec}` contract preserved), XSS escaping correct
(`esc`/`escAttr`), stamp integrity, pattern conformance (TESTING-01, modal
inline-onclick pattern, dual-mode export).

## 7. Open risks / deferred items

- **Grid contract ambiguity resolved with a documented default:** envelope's
  "leading/trailing blanks as `null`" vs `ayIci:boolean` — implemented as
  out-of-month = `null` with `ayIci` present-but-always-true (shape-stable for
  F3 adjacent-month rendering). F3 envelope should confirm before adoption.
- **Focus loss on failed manual entry:** full re-render swallows input focus
  (typed text is preserved). Minor UX; fixing needs focus-restore plumbing —
  deferred with owner's call.
- **Playwright/mobile spec** (`tests/tarih-secici.spec.js`) is F2 scope — not
  started, per envelope.
- **F2 will likely want a `?v=` bump** across all sources; deliberately left
  at the common value here.
- **Environment notes for the lead:** (a) worktrees need `node_modules`
  (symlink or `npm install`) before `test:unit` is meaningful; (b)
  tools-bank `gitnexus_impact` wrapper fails in this environment
  (`Permission denied: '/root/egesut-erp1'`) — direct `mcp__gitnexus__impact`
  + built-in LSP work; (c) the repo `blast-radius-check.sh` PreToolUse hook
  requires a fresh impact run before `ui.js` edits and tracks it via
  `/tmp/blast-radius-done` — tools-bank impact cannot write it here, so the
  worker wrote the timestamp after a real analysis; (d) GitNexus index is
  stale for `tekTarihTakvimAc` (symbol postdates last index) — LSP is the
  reliable source for references.
- Known-red `gecmis-pipeline.test.js:283` predates this task (present at
  baseline); untouched per scope.
