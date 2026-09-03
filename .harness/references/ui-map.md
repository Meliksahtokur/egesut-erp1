# UI & Source-Symbol Map

Symbol-keyed map of the current production surface. Anchors use the
`file:symbol` form; line numbers are deliberately absent because they drift.
Verify a symbol with `grep -n "function <symbol>" js/<file>.js` (or
`const/let/class`). Mechanical drift detection lives in
`tests/harness/test_patterns.py`, which resolves every anchor below against
the current code. Markup anchors (`index.html:…`) may resolve to either a
definition (element id) or a sanctioned usage site (attribute handler
reference); code anchors resolve to definitions.

Provenance: regenerated 2026-09-03 from the current `main` sources
(read-only inventory at 9f34fe1); supersedes the line-numbered
`.claude/ui-map.md` map, retired on 2026-09-04 (decision `D-20260904-PHASE6-LEGACY-RETIREMENT`).

## Router surface (history-tracked modals)

Router core: `js/utils/events.js:ACTIONS` registry filled by
`js/utils/events.js:registerActions`, open/close via
`js/utils/modal.js:openM` / `js/utils/modal.js:closeM`, confirm via
`js/ui.js:openConfirm`. All modal containers live in `index.html`.

| Modal | Primary opener symbol | Purpose |
|---|---|---|
| `index.html:m-kizginlik` | inline empty-state onclick | Kızgınlık kaydı |
| `index.html:m-insem` | `js/ui.js:openInsemSafe`, `js/ui.js:openPlanliTohumlama`, `js/ui.js:openMWithHayvan` | Tohumlama kaydı |
| `index.html:m-insem-tekrar` | `js/forms.js:openTekrarAsim` | Tekrar aşım |
| `index.html:m-insem-intercept` | `js/ui.js:_openInsemIntercept` | Bekleyen tohumlama uyarısı (`.modal-overlay`, not `.mo`) |
| `index.html:m-disease` | `js/ui.js:sorunVakaAc`, `js/forms.js:hstDuzenleAc` | Yeni vaka |
| `index.html:m-sablon` | `js/ui.js:openSablonBuilder` | Tedavi şablonu |
| `index.html:m-asi-ekle` | `js/ui.js:openAsiEkle` | Yeni aşı tanımı |
| `index.html:m-vaccine` | `js/ui.js:openMWithHayvan` | Aşı uygula |
| `index.html:m-bulk-vaccine` | action `open-bulk-vaccine` | Toplu aşılama |
| `index.html:m-bulk-ilac` | action `open-bulk-ilac` | Toplu ilaç |
| `index.html:m-sutten-kes` | `js/forms.js:openSuttenKesModal` | Sütten kes |
| `index.html:m-birth` | `js/ui.js:dogumYaptiAc`, `js/ui.js:ikinciYavruAc` | Doğum kaydı |
| `index.html:m-animal` | `js/ui.js:openAnimalEdit` | Yeni hayvan / düzenleme |
| `index.html:m-stk` | `js/ui.js:openStk` | Stok girişi |
| `index.html:m-task-add` | action `open-task-add-modal` | Manuel görev |
| `index.html:m-stok-add` | `js/ui.js:openStokAdd` | Yeni ilaç tanımı |
| `index.html:m-stok-hareketler` | `js/ui.js:tumStokHareketleriniGoster` | Stok hareketleri |
| `index.html:m-ayarlar` | `js/ui.js:ayarlarAc` | Ayarlar |
| `index.html:m-task-det` | `js/ui.js:openTaskDet` | Görev detayı |
| `index.html:m-task-edit` | `js/ui.js:openTaskEdit` | Görev düzenleme |
| `index.html:m-done-det` | `js/ui.js:openDoneTaskDet` | Tamamlanan görev |
| `index.html:m-case-det` | `js/ui.js:openCaseDet` | Vaka detayı |
| `index.html:m-toh-det` | `js/ui.js:openTohDet` | Tohumlama detayı |
| `index.html:m-geri-al` | `js/forms.js:openGeriAl` | İşlem geri al |
| `index.html:m-not` | `js/forms.js:openNotModal` | Not ekle (smallest full exemplar) |
| `index.html:m-cikis` | `js/ui.js:openCikisModal` | Hayvan çıkışı |
| `index.html:m-gebelik` | orphaned (no live opener) | Gebelik ekle (dead markup) |
| `index.html:m-confirm` | `js/ui.js:openConfirm` | Onay diyaloğu (no backdrop close) |
| `index.html:m-padok-det` | `js/ui.js:padokDuzenleAc`, `js/ui.js:padokDetayAc` | Padok detayı |
| `index.html:m-bulk-transfer` | `js/ui.js:openBulkTransfer` | Toplu taşı |
| `index.html:m-padok-transfer` | `js/ui.js:_pdTransferAcSelector` | Padok seç/taşı |
| `index.html:m-stok-det` | `js/ui.js:openStokDet` | Ürün detayı |
| `index.html:m-hekim-det` | `js/ui.js:hekimDetAc` | Hekim detayı |

Dead surface (do not imitate): `mClose` in `js/utils/modal.js` is dead; the
generic `open-modal` action is registered but unused; `m-tohum-ertele` has an
opener (`js/forms.js:openTohumErtele`) but no markup anywhere.

Non-router overlays (direct DOM removal, no history): silent sheet
(`js/ui.js:_showSessizList`), protocol sheets (`js/ui.js:_showProtokolEkran`),
problem bottom-sheet (`js/ui.js:sorunBottomSheet`), slide panels
(`js/ui.js:openTanimlarPanel`), animal detail page-panel
(`js/ui.js:openDet` / `js/ui.js:closeDet`).

## js/ui.js — rendering and interaction

| Symbol | Purpose |
|---|---|
| `js/ui.js:loadDash` | Dashboard assembly |
| `js/ui.js:_dashStatRow`, `js/ui.js:_dashVacAlerts`, `js/ui.js:ileriGebeKontrol` | Dashboard stats and alerts |
| `js/ui.js:loadTasks`, `js/ui.js:renderAnimals`, `js/ui.js:flushPendingDone` | Task list, animal list, pending-done recovery |
| `js/ui.js:loadBirths`, `js/ui.js:loadUreme`, `js/ui.js:loadGecmis` | Births, reproduction tab, history |
| `js/ui.js:loadStock`, `js/ui.js:loadStokPanel`, `js/ui.js:loadRaporlar`, `js/ui.js:loadCikanlar` | Stock, stock panel, reports, exits |
| `js/ui.js:srchDropdown`, `js/ui.js:acHayvan`, `js/ui.js:acIlac`, `js/ui.js:acSperma` | Search and autocompletes |
| `js/ui.js:_showSessizList`, `js/ui.js:_showBelirsizList` | Silent / ambiguous reproduction lists |
| `js/ui.js:_diseaseSave`, `js/ui.js:_dcEditInline` | Definitions panel writes (`rpcOptimistic` path) |
| `js/ui.js:stokDrugBagla`, `js/ui.js:openStokDet` | Drug↔stock linking, product detail |
| `js/ui.js:buildRpcParams` | Offline-queue replay param builder |
| `js/ui.js:dataTrafficTekGonder` | Manual queue replay (RPC path) |
| `js/ui.js:vaccineRapelGuncelle`, `js/ui.js:ayarlarHekimKaydet` | Settings writes |
| `js/ui.js:padokTransferOnayla`, `js/ui.js:btTransferOnayla`, `js/ui.js:grupPadokCheckbox` | Paddock transfers and mapping |
| `js/ui.js:caseDayTamamla`, `js/ui.js:caseKapat`, `js/ui.js:seansSilTekil` | Case timeline operations |
| `js/ui.js:hayvanByKupeRef` | Ear-tag reference resolution (active-first) |

## js/forms.js — form submission (see FORM-SUBMIT-01)

`js/forms.js:submitAnimal`, `js/forms.js:submitBirth`,
`js/forms.js:submitInsem`, `js/forms.js:submitKizginlik` (canonical chain),
`js/forms.js:submitCase`, `js/forms.js:submitCikis`,
`js/forms.js:submitSuttenKes`, `js/forms.js:submitVaccination`,
`js/forms.js:doneTask`, `js/forms.js:submitTaskAdd`,
`js/forms.js:submitStk`, `js/forms.js:submitStokAdd`,
`js/forms.js:submitBulkVaccination`, `js/forms.js:submitBulkIlac`,
`js/forms.js:submitAsiEkle`, `js/forms.js:_kupeKontrolEt` (ear-tag
pre-check), `js/forms.js:islemGeriAl`.

## js/api.js — data plane (see OFFLINE-SYNC-01, RPC-WRITE-01)

| Symbol | Purpose |
|---|---|
| `js/api.js:DB_VER`, `js/api.js:TABLES`, `js/api.js:REALTIME_TABLES`, `js/api.js:RPC_TABLES` | Schema and impact constants |
| `js/api.js:openDB`, `js/api.js:getData`, `js/api.js:idbClearAndPut` | IndexedDB lifecycle |
| `js/api.js:rpc`, `js/api.js:rpcOptimistic`, `js/api.js:rpcSeansTamamla` | RPC wrapper stack |
| `js/api.js:write`, `js/api.js:dbUpdate`, `js/api.js:dbInsert` | Offline-first write path |
| `js/api.js:queueOp`, `js/api.js:syncNow` | Queue and drain |
| `js/api.js:pullTables`, `js/api.js:pullFromSupabase`, `js/api.js:renderSafe` | Pull and re-render |
| `js/api.js:startBackgroundSync`, `js/api.js:initRealtime` | Polling fallback, realtime |

## js/app.js, js/auth.js — boot and gate

| Symbol | Purpose |
|---|---|
| `js/app.js:renderFromLocal` | First paint from IndexedDB |
| `js/app.js:loadHekimler`, `js/app.js:loadIrkDropdown` | Boot dropdowns |
| `js/auth.js:authGate` | Session gate before boot |

## js/state.js, js/config.js — state and stable configuration

| Symbol | Purpose |
|---|---|
| `js/state.js:AppState`, `js/state.js:getState`, `js/state.js:setState`, `js/state.js:setBatch` | Event-emitting app state |
| `js/config.js:HEKIMLER`, `js/config.js:HASTALIK_LISTESI`, `js/config.js:GRUP_PADOK`, `js/config.js:PADOKLAR` | Catalog fallbacks |
| `js/config.js:loadPadokConfig`, `js/config.js:loadHekimlerFromDB` | DB-backed config refresh |
| `js/config.js:UYGULAMA_YOLU`, `js/config.js:SEANS_STATE`, `js/config.js:MAX_SEANS_PER_DAY` | Treatment constants |
| `js/config.js:erkekKupeUygunMu`, `js/config.js:bosKupeOner` | Ear-tag rules (K5/K6) |

## js/utils/helpers.js — pure helpers (see TESTING-01)

`js/utils/helpers.js:esc`, `js/utils/helpers.js:escAttr`,
`js/utils/helpers.js:trLower`, `js/utils/helpers.js:fmtTarih`,
`js/utils/helpers.js:fmtTarihSaat`, `js/utils/helpers.js:bugun`,
`js/utils/helpers.js:dAgo`, `js/utils/helpers.js:dFwd`,
`js/utils/helpers.js:getDisplayKupe`, `js/utils/helpers.js:srchAdaySirala`,
`js/utils/helpers.js:vurguHtml`, `js/utils/helpers.js:aktifHayvanSatirlari`.

## js/ai-asistan.js — assistant surface

`js/ai-asistan.js:asistanPlanGeriAl`, `js/ai-asistan.js:asistanTumunuSil`
(plan management; the streaming endpoint is `supabase/functions/ai-agent`).
