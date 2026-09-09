# History Tab "Daily Ledger" Implementation Plan

> **REQUIRED SUB-SKILL:** Use the executing-plans skill to implement this plan task-by-task.
> **SPEC:** `.claude/plans/2026-09-09-gecmis-sekmesi-tasarim.md` (rev 2) is the authority.
> **REPO FLOW NOTE:** In this repo the implementer does NOT commit — the
> coordinator reviews and commits. Skip every "Commit" step; leave changes in
> the working tree.

**Goal:** Rebuild the history tab as a day-grouped ledger of completed work
only, with one shared pipeline feeding the main tab, the animal-card history,
counters, CSV export, and guarded per-row undo.

**Architecture:** New pure module `js/gecmis.js` (pipeline + CSV + undoRef,
zero DOM writes except string builders) consumed by `js/ui.js` for both
surfaces. No new files beyond `js/gecmis.js` + tests. No DB/RPC changes.

**Tech:** Vanilla JS (browser globals), IndexedDB via existing `idbGetAll`,
`node --test` unit tests via `tests/unit/support/loadModule.js` vm loader.

**Verified anchors (do not re-derive):**
- `trLower` lives at `js/utils/helpers.js:98` (loaded before ui.js).
- Script block: `index.html:2197-2214`; the shared `?v=` stamp is one value
  across ALL 16 script tags — bump to `20260909-1` everywhere or not at all.
- Existing surfaces: `loadGecmis` js/ui.js:3626, `_gecmisEntryHtml` :3511,
  `_gecmisRender` :3614, `_gecmisSearchText` :3585, animal-card loader
  `_detRenderGecmis` ~:2340-2384, undo infra js/forms.js:3425-3489, guard
  example for sibling buttons js/ui.js:3452/3456, tohumlama guard
  `openTohDet` js/ui.js:6774-6807, geri-alınabilir islem tips js/ui.js:2664.
- Live schema (probed): `cases.closed_at` exists, terminal tohumlama values are
  exactly `Gebe|Boş|Doğum Yaptı|Abort` (non-terminal: `Bekliyor`).

**Conventions:** match surrounding code (no semicolons-free style flip, inline
styles for small UI, `esc()/escAttr()` for HTML escaping). Turkish labels.
Datasets over inline onclick strings for NEW buttons where handlers.js routing
fits; the undo button may use the existing global-function onclick pattern used
elsewhere in ui.js rows.

---

### Task 1: `js/gecmis.js` — policy + entry building (pure)

**TDD scenario:** New feature — full TDD.

**Files:**
- Create: `js/gecmis.js`
- Create: `tests/unit/gecmis-pipeline.test.js`

**Step 1: Write failing tests** for `_gmPolicyRow` and `_gmEntriesFromSources`:

```js
const { loadBrowserModule } = require('./support/loadModule.js');
const { sandbox } = loadBrowserModule('js/gecmis.js');
const { _gmPolicyRow, _gmEntriesFromSources } = sandbox;
```

Cases (use `test()`/`node:assert`):
- gorev_log: `{tamamlandi:true, tamamlanma_tarihi:'2026-09-08T09:00:00Z'}` →
  accepted, eventAt = tamamlanma_tarihi; `{tamamlandi:true}` (no date) →
  rejected; `{tamamlandi:false, hedef_tarih:'2099-01-01'}` → rejected (no
  hedef_tarih fallback); reverted (`durum='geri_alindi'`) → rejected.
- tohumlama: sonuc `Gebe`/`Boş`/`Doğum Yaptı`/`Abort` → accepted (eventAt =
  `created_at || tarih`); `Bekliyor`/null → rejected.
- cases: `{status:'closed', closed_at:'…'}` → accepted, eventAt=closed_at;
  `{status:'closed', closed_at:null}` → rejected; `{status:'active'}` → rejected.
- islem_log: `durum:'geri_alindi'` → rejected; accepted otherwise (5 types
  HAYVAN_EKLENDI, ABORT_KAYDI, KIZGINLIK_KAYDI, ASI_KAYDI, TOPLU_ILAC only).
- dogum/uygulama_log: accepted; eventAt fallback order honored.
- Output entry shape `{type, category, eventAt, dateKey, data}`: dateKey =
  local `YYYY-MM-DD` of eventAt (test with a fixed timezone-safe construction —
  build dateKey by string slice `eventAt.slice(0,10)`; document this in a
  comment). Entries with empty eventAt never produced.

**Step 2: Run** `node --test tests/unit/gecmis-pipeline.test.js` → FAIL (module missing).

**Step 3: Implement** `js/gecmis.js`: globals `_gmPolicyRow(type,row)`,
`_gmEntriesFromSources(sources)` where sources =
`{gorev_log:[],tohumlama:[],cases:[],dogum:[],uygulama_log:[],islem_log:[]}`.
Sorting inside `_gmEntriesFromSources`: `eventAt` desc. Keep enrichment joins
(disease name, drug names) OUT of this module — pass through `data` as-is;
enrichment stays in ui.js collect step.

**Step 4: Run** → PASS. **Step 5:** no commit (coordinator owns commits).

### Task 2: undoRef derivation (pure)

**Files:** Modify `js/gecmis.js`, `tests/unit/gecmis-pipeline.test.js`.

**Step 1: Failing tests** for `_gmUndoRef(type, data, ctx)`:
- islem: tip ∈ `['TOHUMLAMA','TOHUMLAMA_GUNCELLENDI','HASTALIK_KAYDI','VAKA_ACILDI','TEDAVI_GUN_EKLENDI']`
  → `{kind:'islem', id:data.id}`; other tips → null. (Verify the list at
  js/ui.js:2664 while implementing; intersect with what `islemGeriAl` routes.)
- tohumlama: ctx = `{latestTohIdByAnimal:{'A1':'T9'}, islemRefByTohId:{'T9':'IL5'}}`:
  row T9 with islem_log ref → `{kind:'islem', id:'IL5'}`; row T9 without ref
  but latest → `{kind:'toh', id:'T9'}`; older row T7 (latest is T9) → null;
  latest but ctx says abortGuarded → null.
- gorev/hastalik/dogum/uygulama → null.
- `_gmUndoButtonHtml(ref, opts)` → button string with `onclick` calling
  `gmUndoClick('KIND','ID')` + `event.stopPropagation()`; ref null → ''.

**Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4:** → PASS.

### Task 3: cap + group + counters (pure)

**Files:** Modify `js/gecmis.js`, tests.

**Step 1: Failing tests**:
- `_gmCap(entries, 300)` returns `{visible, total}`; slice AFTER sort; total =
  pre-cap length.
- `_gmGroup(visible)` → ordered groups `[{dateKey, entries, counters}]`;
  counters = per-category counts of THAT group's visible entries; keys are
  `dogum,tohumlama,hastalik,gorev,uygulama,islem` present-only.
- `_gmGroupHtml(group, {open})` → string starting `<details` with
  `<summary>` header containing `BUGÜN`/`DÜN`/formatted date (fmt helper from
  helpers.js or local; if helpers' `fmtTarih` is loaded it may be used, else
  local formatter — check js/utils/helpers.js first), emoji counters line,
  then entry cards injected via placeholder (the ui.js card renderer provides
  per-entry HTML; group html builder takes `entryHtmlFn`).

**Step 2/3/4:** FAIL → implement → PASS.

### Task 4: CSV builder (pure)

**Files:** Modify `js/gecmis.js`, tests.

**Step 1: Failing tests** for `_gmCsvEscape` + `_gmCsv(visible, meta)`:
- escape: `a;b` → `"a;b"`; `say "hi"` → `"say ""hi"""`; `a\nb` → `"a\nb"`
  (literal newline inside quotes); field starting `=`, `+`, `-`, `@` →
  prefixed `'`.
- `_gmCsv` output starts with `\uFEFIN`… precisely: starts with `\uFEFFTarih;`
  header `Tarih;Saat;Kategori;Küpe;Detay;Ek Bilgi;Hekim;Tip`, CRLF line ends,
  one row per entry, dates `DD.MM.YYYY`, times `HH:MM` when eventAt has time.
- Row content mirrors the on-screen card fields (category label, kupe, title
  text, sub text w/o HTML tags — strip tags; hekim; type).

**Step 2/3/4:** FAIL → implement → PASS.

### Task 5: wire the main history tab (ui.js)

**TDD scenario:** Modifying tested code — first run
`node --test tests/unit/events.test.js` and any existing tests touching
`loadGecmis` (grep tests/ for `loadGecmis|gecmis`) to know the baseline.

**Files:** Modify `js/ui.js` (loadGecmis ~3626-3710, `_gecmisRender` ~3613-3624,
`_gecmisEntryHtml` 3511-3583), `index.html` (script tag insert `js/gecmis.js`
between helpers.js and ui.js lines with SAME `?v=` value as others; CSV button
in header row ~713; remove toggle markup 714-719), `js/utils/handlers.js`
(remove `gecmis-tumu-toggle` 102-110; add `gecmis-csv` handler calling
`_gmDownloadCsv()`), `js/app.js` (remove `_gecmisTumu` from :51), `js/ui.js:7`
(remove `_gecmisTumu` import).

**Steps:**
1. Rewrite `loadGecmis`: online → `await pullTables([...per spec §F]).catch(()=>{})`;
   collect from IDB (keep existing enrichment joins for hastalik/gorev rows);
   build `sources` object → `_gmEntriesFromSources` → store to `_gecmisAllEntries`;
   then `_gecmisRender(q)` as today.
2. `_gecmisRender`: search (existing searchText logic moves to build-time
   `searchText` on entries) → `_gmCap` → `_gmGroup` → render day sections with
   `<details open>`; cap hint `İlk {visible} / {total} kayıt` when capped;
   when `q` non-empty force all groups open.
3. `_gecmisEntryHtml`: add sibling undo button (Task 2 `_gmUndoButtonHtml`)
   inside the card content div, NOT on outer onclick; hidden when
   `!navigator.onLine`. Add `gmUndoClick(kind,id)` global → `openGeriAl(id)`
   or `'toh:'+id` path exactly as derived (never blanket).
4. `loadGecmis` date/label correctness: entries now carry eventAt — the card's
   date line prints entry.eventAt formatted.
5. Chip counts: compute from `_gecmisAllEntries` (policy-passed, pre-search)
   per current filter semantics (`uygulama` under Görev chip, `islem` under
   Hayvan chip); write counts into chip labels on load (id-less: extend the
   existing `data-action="gecmis-*"` buttons' text with count suffix).
6. Remove toggle + `_gecmisTumu` per Files list; add `gecmis-csv` handler →
   `_gmDownloadCsv()` in js/gecmis.js (Blob + `URL.createObjectURL` + anchor
   click + `revokeObjectURL`; filename `egesut-gecmis-YYYY-MM-DD.csv`).
7. Bump `?v=` `20260908-1` → `20260909-1` on ALL 16 tags (single shared value).
8. Run full `npm run test:unit` → fix regressions.

### Task 6: animal-card parity (ui.js)

**Files:** Modify `js/ui.js` `_detRenderGecmis` ~2340-2384 (+ its search box
handler).

**Steps:**
1. Replace ad-hoc loads with the same collect + `_gmEntriesFromSources`
   filtered by `data.hayvan_id === id || data.anne_id === id || data.animal_id
   === id` (per type, mirror current matching incl. yavru for dogum).
2. Keep `overrideOc` behavior for entry cards; undo button must still render
   (it is inside content, unaffected by overrideOc).
3. Existing det-gecmis search box keeps working over `searchText`.

### Task 7: full suite + self-check

1. `npm run test:unit` → all green (baseline before you started: know it).
2. `git status --short` — expected changed: `js/gecmis.js` (new),
   `js/ui.js`, `index.html`, `js/app.js`, `js/utils/handlers.js`,
   `tests/unit/gecmis-pipeline.test.js` (new). Anything else → investigate.
3. `node --test tests/unit/gecmis-pipeline.test.js -v` output attached to the
   completion envelope.
4. Report per the worker envelope (SUPERSET_WORKER_DONE with checks).

**Final report should include:** files changed, test counts (before/after),
any spec deviation with reason, anything left for the coordinator (e.g. manual
demo-mode verification).
