# History Tab Redesign — "Daily Ledger" (2026-09-09)

Branch: `idle/gecmis-refactor` · Worktree: `/home/melik/egesut-wt/gecmis-sekmesi`
Status: design approved direction (owner picked hybrid: ledger view + structured
CSV + undo button restore); final CSV format and undo scope questions were left
unanswered — resolved by recommendation and flagged below.

## Problem (evidence)

The history tab (`#pg-gecmis`) renders every record kind in one flat
chronological list. Three concrete defects:

1. **Pending-work leak.** `js/ui.js:3679` — the "Tümü" toggle sets
   `_gecmisTumu=true`, which disables *both* filters
   `(_gecmisTumu||t.tamamlandi) && (_gecmisTumu||!t.parent_id)`. Pending tasks
   and child tasks flood the history. Worse, `js/ui.js:3687` falls back to
   `hedef_tarih` (a *future* date) when `tamamlanma_tarihi` is empty, so future
   dates enter and re-order the "history".
2. **Completed treatments invisible.** `TEDAVI_GUN` tasks are born as child
   rows (`parent_id` set, see `supabase/migrations/99999999999999_ground_truth.sql`
   gorev_log constraint). The `!t.parent_id` condition excludes them *always* —
   toggle on or off. "Yesterday's treatments missing" is this filter, not data
   loss.
3. **Undo unreachable from history.** `openGeriAl`/`islemGeriAl`
   (`js/forms.js:3425-3489`) and the `geri_al` / `tohumlama_geri_al` RPCs work,
   but `_gecmisEntryHtml` (`js/ui.js:3511`) has no undo button — the function
   used by BOTH the main history tab and the animal-card history tab.

Adjacent defects accepted into scope: "Bekliyor" tohumlama rows and "Aktif"
case rows also leak into history (owner: "saf bitmişler girmeli; aktif vakalar
sürü listesi üzerinden takip ediliyor").

## Decision set

| # | Decision | Source |
|---|---|---|
| D1 | History = completed work only ("saf bitmiş") | owner, explicit |
| D2 | `parent_id` exclusion REMOVED — completed TEDAVI_GUN days become first-class rows at their completion date | follows from D1 + defect 2 |
| D3 | "Tümü" toggle removed entirely | follows from D1 |
| D4 | Day-grouped reverse-chronology ledger with per-day type counters and counted filter chips (proposal B) | owner picked hybrid |
| D5 | Structured CSV export, client-side only (Blob download), no backend, no PDF this round | owner constraint: GitHub Pages = vanilla JS only |
| D6 | Undo: restore the ↩ button on history entries wired to the EXISTING `openGeriAl`/RPC path; central undo architecture is a SEPARATE design round | owner: "sağlam mimari… belki ayrıca ele alınabilir" |
| D7 | CSV = WYSIWYG: exports exactly the currently filtered+searched list (unanswered question resolved by recommendation) | best judgment, flagged |
| D8 | CSV format: `;`-separated, one row per event, full date+category columns (no day separator rows — keeps spreadsheet filtering intact); UTF-8 BOM for Turkish chars in Excel | owner: "csv sistematik olmalı, düz liste olmaz" |

## Design

### Data rules (loadGecmis)

- `gorev_log`: keep `t.tamamlandi === true` AND require non-empty
  `tamamlanma_tarihi`. Drop the `!t.parent_id` condition. `date`/`sortKey` =
  `tamamlanma_tarihi` only — no `hedef_tarih` fallback.
- `tohumlama`: only rows with non-empty `sonuc` (Gebe/Boş). Pending
  ("Bekliyor") rows are excluded; they surface via reproduction tab once a
  result exists.
- `cases`: only closed cases (`status !== 'active'`). ⚠ Verify the real
  close-date column in the live schema during implementation (contract: live
  schema is the only DB authority); if a close timestamp exists, use it for
  date/sortKey instead of `start_date`.
- `dogum`, `uygulama_log`, `islem_log`: unchanged (already completed facts).
- `_gecmisTumu` state, toggle UI, and `gecmis-tumu-toggle` handler are deleted.

### Rendering (day-grouped ledger)

- Keep the existing entry card (`_gecmisEntryHtml`) and search
  (`_gecmisSearchText`) infrastructure.
- `_gecmisRender` groups the sorted list by `date` (YYYY-MM-DD) into collapsible
  day sections: `BUGÜN` / `DÜN` / `d MMMM, weekday`. Each header carries that
  day's per-type counters (🐄 💉 🏥 ✅ 🐮).
- Filter chips show counts (total on "Hepsi", per-type on category chips).
- The existing 300-entry cap is kept (slice first, then group).

### CSV export

- Button next to the chip row: `↧ CSV`. Exports the currently visible
  (filtered + searched) list — WYSIWYG (D7).
- Columns: `Tarih;Saat;Kategori;Küpe;Detay;Ek Bilgi;Hekim;Tip` — `Tip` is the
  internal record type for unambiguous re-import/analysis.
- Dates `DD.MM.YYYY`, times `HH:MM` when a timestamp exists.
- `\uFEFF` BOM + `;` separator (TR Excel locale). Filename:
  `egesut-gecmis-YYYY-MM-DD.csv`.
- Pure client: `Blob` + `URL.createObjectURL` + `a[download]`. Works offline
  (all sources are already in IndexedDB). No Supabase, no local-machine
  backend, no CDN library (PDF explicitly out).

### Undo button restore (thin layer, D6)

- In `_gecmisEntryHtml`, add a small `↩` affordance on rows whose type has an
  existing undo path:
  - `type:'islem'` → `openGeriAl(data.id, …)` (islem_log id; `islemGeriAl`
    already routes TOHUMLAMA/HASTALIK_KAYDI/VAKA_ACILDI/TEDAVI_GUN_EKLENDI).
  - `type:'tohumlama'` → `openGeriAl('toh:'+data.id, …)` (existing direct
    path).
  - `type:'gorev'`, `type:'hastalik'` (cases): only if a live-schema probe
    confirms an RPC path; otherwise no button (do not invent RPCs).
- Button must `stopPropagation()` so the row's own onclick (detail modal) does
  not fire — this is the pattern break that likely killed the original undo
  button; verify against the current production example (m-case-det
  `td2-geri-al-btn`, `index.html:2104`).
- Confirmation stays the existing math-check modal `m-geri-al`.
- The same button automatically appears in the animal-card history tab
  (`_detRenderGecmis` reuses `_gecmisEntryHtml` with `overrideOc`) — wire the
  undo button OUTSIDE the `overrideOc` replacement path so it survives there.

### Central undo architecture — separate round (out of scope)

Recorded inventory for that future round (5 disconnected surfaces):
`openGeriAl/islemGeriAl` (generic RPC), `_protokolGeriAl` (ui.js:1473/1756),
sütten kesme geri al (forms.js:2789), asistan undo (ai-asistan.js + RPC),
done-session undo window (state.js:26, backend RPC pending). Goals for that
round: single undo router, write RPCs returning undo refs, cascade rules
(stok_hareket, süt yasağı), rate/window policy.

## Files touched

- `js/ui.js` — loadGecmis rules; _gecmisRender grouping+counters; CSV builder
  (new pure helper, e.g. `_gecmisCsvLine`); _gecmisEntryHtml undo button.
- `index.html` — remove toggle row; add CSV button; day-section markup is
  JS-generated.
- `js/utils/handlers.js` — remove `gecmis-tumu-toggle`; add `gecmis-csv`.
- `js/app.js` — remove `_gecmisTumu` declaration + import in ui.js deps list.
- `tests/unit/` — new unit tests (below).

Pattern reuse: entry card, `_keepScroll`, debounce search, `openM/closeM`
modal plumbing, math-check confirm — all reused as-is.

## Testing

- Unit (pure functions): filter rules (pending/child/undated exclusion,
  tohumlama sonuc, case status), day-group keys+counters, CSV line building
  (escaping `;` in text, BOM, date/time formats).
- Manual: worktree serve + demo mode; verify (a) no pending rows under any
  filter, (b) completed treatment days visible at completion date, (c) CSV
  opens correctly in a TR-locale spreadsheet, (d) undo button opens confirm
  and returns to a refreshed list.
- No CI/demo-DB writes; no prod deploy without owner approval (standing rule).

## Risks / open questions

- Case close-date column name must come from a live-schema probe, not
  migrations (D-note above).
- A gorev/case undo RPC may not exist → those rows simply get no ↩ button
  this round (documented in code comment).
- Mobile perf: day headers must stay cheap (single div, no nested layouts).
- Owner did not answer D7/D8 — first implementation review should re-confirm
  CSV scope (WYSIWYG vs fixed period) before polish.
