# History Tab Redesign — "Daily Ledger" — FINAL SPEC (rev 2)

Branch: `idle/gecmis-refactor` · Worktree: `/home/melik/egesut-wt/gecmis-sekmesi`
Rev 2 (2026-09-09): incorporates the Codex luna-max worker review
(`egesut-gecmis-design-review`, APPROVE-WITH-CHANGES, session `eeff947c`) and
live-schema probes. Rev 1 sections that the review confirmed are kept; changes
are marked **[R]**.

## Problem (confirmed by review)

1. Pending-work leak: `js/ui.js:3679` — `_gecmisTumu` disables both filters;
   pending tasks use future `hedef_tarih` as date (`js/ui.js:3687`).
2. Completed treatments invisible: `TEDAVI_GUN` rows have `parent_id`, and
   `!t.parent_id` excludes them unconditionally.
3. Undo unreachable from history: `_gecmisEntryHtml` has no undo affordance,
   though `openGeriAl`/`islemGeriAl` + RPCs work.
4. Leaked in-progress state: "Bekliyor" tohumlama rows and active cases.

## Verified live-schema facts (probed 2026-09-09, read-only)

- `cases` columns include `status text` and `closed_at timestamptz`.
  58/58 closed cases have `closed_at` filled. **No fallback needed**: rule is
  `status='closed' AND closed_at IS NOT NULL`; a closed case without
  `closed_at` simply does not enter history (data-quality signal).
- `tohumlama.sonuc` value set: `Boş`, `Doğum Yaptı`, `Gebe`, `Bekliyor`,
  `Abort`. Non-terminal value is exactly `Bekliyor`.

## Decision set

| # | Decision |
|---|---|
| D1 | History = completed work only (owner, explicit) |
| D2 | `parent_id` exclusion removed; completed TEDAVI_GUN days are first-class rows at completion date |
| D3 | "Tümü" toggle removed entirely |
| D4 | Day-grouped reverse-chronology ledger with per-day counters and counted chips |
| D5 | Structured CSV, client-side only |
| D6 | Undo: entry-level ↩ wired to existing RPC path; central undo architecture stays a separate round |
| D7 | **[R]** CSV = WYSIWYG over the **capped visible list** (300), not the uncapped search result — less surprising |
| D8 | CSV: `;` separator, BOM, one row per event, full date+category columns |
| D9 | **[R]** ONE shared pipeline (normalize → policy-filter → search → cap → group) feeds the main history, the animal-card history, chips, day counters, and CSV. Animal-card parity is mandatory. |
| D10 | **[R]** Entries carry a precomputed `undoRef` derived from existing guard logic; rows without a valid undoRef get NO button |
| D11 | **[R]** Reverted records (`durum='geri_alindi'` / cancelled) are excluded from history: a reverted event is no longer "done work" |
| D12 | **[R]** Day groups use native `<details>` elements; counters computed from the visible capped slice |
| D13 | **[R]** Undo button hidden when offline (`js/forms.js:3440` rejects offline undo) |
| D14 | **[R]** History tab pulls fresh data on entry (online only), same pattern as `loadTasks` |

## Design

### A. Shared pipeline [R]

New pure module-level functions in `js/ui.js` (kept inline to match the file
conventions; no new files unless size forces it):

```
_gmNormalize(sources, scope)  -> entries[]
_gmApplyPolicy(entries)       -> entries[]   (per-source rules below)
_gmSearch(entries, q)         -> entries[]   (reuse _gecmisSearchText logic)
_gmCap(entries, n=300)        -> {visible, total}
_gmGroup(visible)             -> [{dateKey, label, entries, counters}]
```

Entry contract: `{ type, category, eventAt, dateKey, data, searchText, undoRef }`
where `eventAt` is the authoritative ISO timestamp, `dateKey` its local
`YYYY-MM-DD`, `category` ∈ {dogum, tohumlama, hastalik, gorev, uygulama,
islem} (chip mapping below). Entries with empty `eventAt` are NOT accepted.

`scope` parameter: `{animalId?: id}` — the animal-card history
(`_detRenderGecmis`) calls the same pipeline with the animal scope instead of
its own loading logic (replaces `js/ui.js:2340-2384` ad-hoc loads).

### B. Data rules (policy filter)

| Source | Accept rule | eventAt |
|---|---|---|
| `gorev_log` | `tamamlandi===true` AND non-empty `tamamlanma_tarihi` AND not reverted | `tamamlanma_tarihi` (no `hedef_tarih` fallback) |
| `tohumlama` | `sonuc` ∈ {`Gebe`,`Boş`,`Doğum Yaptı`,`Abort`} (allowlist) AND not reverted | `created_at` (row keeps its result timestamp semantics; if `created_at` empty → `tarih` at 00:00) |
| `cases` | `status='closed'` AND `closed_at` non-empty | `closed_at` |
| `dogum` | all (unchanged) | `created_at` || `tarih` |
| `uygulama_log` | all (unchanged) | `created_at` || `tarih` |
| `islem_log` (5 types as today) | `durum` ≠ `geri_alindi` | `tarih` || `created_at` |

TEDAVI_GUN rows of a still-active case DO appear once completed (the drug was
administered — that is done work); the case-level card follows the case rule
above. [R explicit]

### C. Rendering

- `_gecmisRender` builds native `<details open>` day sections: header
  `BUGÜN` / `DÜN` / `d MMMM weekday` + counters (🐄 💉 🏥 ✅ 💊 🐮).
- Counters computed from the visible slice only; when capped, show
  `İlk 300 / {total} kayıt` hint. [R]
- Chip mapping unchanged: `uygulama` counts under the ✅ Görev chip, `islem`
  under the 🐮 Hayvan chip (current behavior, now explicit). [R]
- Search keeps `_gecmisSearchText` semantics; active search forces all day
  groups open.
- Keep `_keepScroll`; keep the 200ms debounced search handler.

### D. CSV export [R hardened]

- Button `↧ CSV` in the header row; exports the **capped visible list** (D7).
- Built from normalized entries (never from DOM).
- Columns: `Tarih;Saat;Kategori;Küpe;Detay;Ek Bilgi;Hekim;Tip`.
- Escaping: field wrapped in `"` if it contains `;`, `"`, newline; inner `"`
  doubled; line endings CRLF; prefix `\uFEFF` BOM; MIME `text/csv;charset=utf-8`;
  `URL.revokeObjectURL` after download.
- Formula-injection guard: fields starting with `=`, `+`, `-`, `@` get a
  leading `'`. Applies to all text fields.
- Dates `DD.MM.YYYY`, times `HH:MM` from `eventAt`.
- Filename `egesut-gecmis-YYYY-MM-DD.csv`.

### E. Undo button restore [R hardened]

`undoRef` derivation (precomputed during normalize; NO blanket paths):

| type | rule |
|---|---|
| `islem` | button only if `data.tip` ∈ the existing geri-alınabilir set intersected with what `islemGeriAl` routes (`TOHUMLAMA`, `TOHUMLAMA_GUNCELLENDI`, `HASTALIK_KAYDI`, `VAKA_ACILDI`, `TEDAVI_GUN_EKLENDI` + others present at `js/ui.js:2664`); ref = `data.id` |
| `tohumlama` | reuse `openTohDet`'s guard logic (`js/ui.js:6774-6807`): if the row has an `islem_log` ref → that id; else only if it is the animal's LATEST tohumlama and not abort-guarded → `toh:`+id; older/guarded rows → `undoRef=null` (no button) |
| others | `undoRef=null` |

- Button is a **sibling button inside the card content** (correct existing
  pattern at `js/ui.js:3452`, `3456`), NOT the outer onclick; unaffected by
  `overrideOc` so it also lives in the animal-card history. `stopPropagation`.
- Offline (`!navigator.onLine`): button hidden.
- Confirm stays `m-geri-al` (math check). After undo, re-run pipeline and
  re-render BOTH surfaces if open.

### F. Data freshness [R]

`loadGecmis` on tab entry, when online, pulls before reading IDB
(`pullTables` list mirrors `loadTasks`: `gorev_log`, `tohumlama`, `cases`,
`treatment_days`, `drug_administrations`, `drug_products`, `stok`, `islem_log`,
`uygulama_log`) with `.catch(()=>{})` — offline falls back to cached IDB.

### G. Cleanup

Delete: `_gecmisTumu` state (`js/app.js:51` + import list `js/ui.js:7`), toggle
markup (`index.html:714-719`), `gecmis-tumu-toggle` handler
(`js/utils/handlers.js:102-110`). Add `gecmis-csv` handler. If `index.html`
bumps asset `?v=` stamps, bump the SINGLE shared value once for all local
assets (repo invariant: one shared stamp).

## Files touched

`js/ui.js` (pipeline + render + CSV + undo), `index.html` (toggle out, CSV
button), `js/utils/handlers.js`, `js/app.js`, `tests/unit/*` (new).

## Testing

- Unit: policy filter per source (incl. reverted exclusion, allowlist tohumlama,
  closed_at requirement, TEDAVI_GUN-of-active-case accepted); dateKey/eventAt
  normalization; cap+counter math ("İlk 300/N"); CSV escaping matrix (`;`,
  `"`, newline, formula prefixes, BOM/CRLF presence); undoRef derivation
  (islem tip matrix; tohumlama latest-vs-older; guarded rows → null);
  searchText parity for animal-card scope.
- Manual (demo mode, worktree server): no pending rows under any filter;
  completed treatment days visible at completion date; day groups + counters;
  CSV opens in TR-locale spreadsheet; undo button appears only on eligible
  rows, opens math-check modal, refreshes both surfaces; offline button hidden.
- No CI/demo-DB writes; no prod deploy without owner approval.

## Out of scope (separate rounds)

- Central undo architecture (5-surface inventory recorded in rev 1).
- PDF export; period summary cards (proposal C leftovers).
- Dashboard/other tabs.

## Review provenance

Worker `egesut-gecmis-design-review` (Codex gpt-5.6-luna max, 9m): verdict
APPROVE-WITH-CHANGES; all four required revisions are folded in above as
[D9]-[D14] + sections A/E hardening. Live-schema facts probed directly by the
coordinator (read-only SQL): `cases.closed_at` exists and 58/58 closed rows
filled; `tohumlama.sonuc` enumerated.
