# W2 delivery — G-20260913-SURUM-GECMISI F3 (Değişiklikler page)

- Worker: `agent/surum-gecmisi-diff-W2` (worktree `.superset/worktrees/…/agent/surum-gecmisi-diff-W2`)
- Base: `f2027d1` (lead goal commit). Final SHA: see lead message / `git log -1`.
- Task: `/home/melik/egesut-erp1/.ss/tasks/W2-surum-gecmisi-f3-ui.md`
- Gate crumbs: `/home/melik/egesut-erp1/.crumbs/surum-gecmisi-diff-W2.jsonl` (5 gate + 1 decision)

## Changed files (all inside the goal manifest)

| Path | Kind | Notes |
|---|---|---|
| `js/degisiklikler/etiketler.js` | new, pure | `tabloEtiketi`, `alanEtiketi`, `islemEtiketi`, `tabloSecenekleri`; inventory from local schema mirror `egesut_lsp` (48 public tables) |
| `js/degisiklikler/diff.js` | new, pure | `diffSatirlari`, `islemOzeti` (frozen names) + `ozetMetni`, `degerMetni`, `pkKisa` |
| `js/degisiklikler/degisiklikler.js` | new | page controller: list, filters, detail diff, revert flow, ticket modal + remaining time, offline lock |
| `js/degisiklikler/degisiklikler-stub.js` | new, TEMPORARY | contract-shaped stub, overrides the 4 wrappers with identical signatures |
| `js/api.js` | additive | 4 wrappers `rpcGeriAlmaBiletiAl`, `rpcDegisimListele`, `rpcDegisimOnizle`, `rpcDegisimGeriAl` (pattern: `rpcSeansTamamla` / `rpcReceteGuncelle`) |
| `js/ui.js` | additive (1 line) | `_detOzetHtml`: "🧾 Bu hayvanın değişiklikleri" button (guarded by `typeof degisikliklerHayvanIcin`) |
| `index.html` | additive + stamp | `#pg-degisiklikler` page, Kayıt-page `log-btn` entry, modals `m-dg-onizle` / `m-dg-bilet`, 4 script tags; every `?v=` (26 incl. manifest) moved to one value `20260913-15` |
| `tests/unit/degisiklikler-diff.test.js` | new | 11 tests |
| `tests/unit/degisiklikler-etiketler.test.js` | new | 7 tests |
| `tests/unit/vaka-toplu-ac.test.js` | stamp guard | expected stamp `20260911-14` → `20260913-15`, old stamp added to the "must not remain" list (same as every previous bump) |
| `reports/2026-09-13-surum-gecmisi-W2/*.png` | evidence | 8 screenshots |

Untouched: existing Geçmiş tab (`js/gecmis.js`, `loadGecmis`), the 7 legacy undo RPC UIs, `js/app.js`, `js/utils/handlers.js`, all DB/migrations. No DB access, no DDL, no push.

## Pattern reuse (named production examples)

- MODAL-ROUTER-01: `openM`/`closeM` + `.mo[data-action="mclose-overlay"]`, markup modeled on `index.html:m-not` / `js/forms.js:openNotModal`; actions via `js/utils/events.js:registerActions` (module self-registers, so `handlers.js` stays untouched).
- Page: `.pg` + `js/app.js:goTo` (no branch added; the module calls `goTo('degisiklikler')` then renders itself).
- Date: canonical `js/ui.js:tekTarihTakvimAc({baslik, deger, onSec})`; display `fmtTarih` (gg.aa.yyyy).
- Offline: `js/forms.js:submitCikis` guard (`navigator.onLine` → toast "İnternet bağlantısı gerekli") and `js/gecmis.js:_gmUndoButtonHtml` (revert buttons not rendered offline); plus `online`/`offline` listeners re-render the page.
- Animal lookup: `js/ui.js:hayvanByKupeRef` (filter by küpe; UUID → küpe display in diff).
- RPC: `js/api.js:rpc` unchanged; ok:false surfaces as `Error` with `e.data.hata` → mapped to Turkish text (`DG_HATA_METNI`).
- TESTING-01: `tests/unit/support/loadModule.js:loadBrowserModule` loads the product files; no source copy.
- XSS: all dynamic text through `esc()`, attributes through `escAttr()`; jsonb revert targets are never serialized into attributes — they live in an in-memory array indexed by `data-hi`.

## Acceptance

| # | Criterion (W2 share) | Verdict | Evidence |
|---|---|---|---|
| 4 | Unit tests green; new pure-layer tests (diff, Turkish labels); baseline counted | PASS | baseline 796 / 795 pass / 1 fail → after 814 / 813 / 1; the only failure is the known red `tests/unit/gecmis-pipeline.test.js:283` (goal constraint) |
| 5 | UI opens on a local server against demo DB; screenshot | PARTIAL (stub) | 8 screenshots below, real demo DB session (demo login, demo animals) with the RPC layer on the contract-shaped stub; real RPC path is lead integration after W1 merge |
| F3 | list / filters / diff / revert flow / ticket + remaining time / offline lock / animal link | PASS against stub | scripted Playwright flow, output below |

### Commands

```text
$ NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js   (before changes)
ℹ tests 796  ℹ pass 795  ℹ fail 1   (gecmis-pipeline.test.js:283)

$ NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/degisiklikler-*.test.js
ℹ tests 18  ℹ pass 18  ℹ fail 0

$ NODE_PATH=/home/melik/egesut-erp1/node_modules node --test tests/unit/*.test.js   (after)
ℹ tests 814  ℹ pass 813  ℹ fail 1   (same known red)

$ node --check js/degisiklikler/*.js js/api.js js/ui.js   → exit 0
```

`NODE_PATH`: the worktree has no `node_modules`; lead confirmed this route is valid (environment setup, nothing created in the worktree).

### Screenshot run (acceptance 5)

Driver: throwaway Playwright script under `/home/melik/tmp/w2-shot-WbsF8w/shot.cjs` (regenerated per run, not part of the delivery; Playwright from the main checkout, Chromium headless shell 1228, 412×915 @2x, tr-TR, Europe/Istanbul, `EGESUT_DEMO=1`). Ports 8097 and 8098 were already bound by other sessions (`8097` → `/home/melik/egesut-wt/gecmis-sekmesi`, `8098` → `/home/melik/egesut-erp1`); those processes were not touched. The script serves this worktree's files under the `http://127.0.0.1:8097` origin via `context.route` interception, so no new port was opened and 8080 was never used.

Flow (real clicks): Kayıt → Değişiklikler → first tx detail → field revert → preview → wrong password → correct password `demo1234` → applied (new tx 9101) → back → "Sürüden çıkış" tx revert (conflict) → offline → animal detail → "Bu hayvanın değişiklikleri".

```json
{ "conflictConfirmDisabled": true, "offlineRevertButtons": 0,
  "hayvanFilterValue": "TR092757125", "errors": [] }
EXIT=0
```

| File | Shows |
|---|---|
| `reports/2026-09-13-surum-gecmisi-W2/w2-1-liste.png` | list: time, "Doğum kaydı · 3 tablo · 5 satır", I/U/D badges, source, filters |
| `…/w2-2-detay.png` | row-by-row diff (inserted green), Turkish labels, animal UUID shown as küpe, field/row/transaction revert buttons |
| `…/w2-3-onizle.png` | preview: plan, optional reason, confirm |
| `…/w2-4-bilet-hata.png` | ticket modal with `SIFRE_HATALI` message |
| `…/w2-5-sonuc.png` | result: new revert tx detail with `↩ geri alma` source |
| `…/w2-6-cakisma.png` | conflict: `geri_alinabilir:false`, blocker text, confirm disabled |
| `…/w2-7-cevrimdisi.png` | offline banner, no revert buttons |
| `…/w2-8-hayvan-filtre.png` | animal filter pre-filled from animal detail |

## Stub removal (lead, at W1 integration)

1. Delete the line `<script src="js/degisiklikler/degisiklikler-stub.js?v=…"></script>` from `index.html`.
2. Delete `js/degisiklikler/degisiklikler-stub.js`.
3. Bump every `?v=` to one new value and update the stamp guard in `tests/unit/vaka-toplu-ac.test.js` (two tests) the same way as this delivery.

Nothing else references the stub; the page only reads `window.DEGISIM_STUB` to show the "Önizleme verisi (stub)" banner, which disappears automatically. The real wrappers in `js/api.js` are already in place with the same signatures.

## Lead contract update (applied, mid-delivery)

Lead updated the frozen F2 `p_hedef` (goal `3674e62`, arrives at integration):
`pk` is a SCALAR value for single-column PKs and an OBJECT `{pkkolon: deger}`
for composite PKs; `satir`/`alan` targets take an OPTIONAL `txid` (given → that
tx's change is targeted; omitted → the row's/field's LATEST change). Applied:

- `_dgPk` (`degisiklikler.js`) now returns the single value for one-key
  `satir_pk` and a copy of the object for composite PKs; row/field revert
  buttons are no longer hidden for composite rows.
- Detail-view revert buttons always send `txid: _dg.detayTxid`, so the version
  targeted is exact — this resolves the earlier "wrong version" hazard at the
  contract level. The interim client-side version guard added during review
  was therefore removed (server-side CAKISMA / HEDEF_BULUNAMADI remain the
  enforcement; no client duplicate).
- Preview/conflict/dependency `pk` displays go through `pkKisa` (handles
  scalar and composite).
- Stub: `pkEslestir` matches scalar and object pks; `hedefSatirlari` honors
  optional `hedef.txid`; `alan` level requires the targeted tx to be a `U`
  touching that field (else `GECERSIZ_HEDEF`).
- Verified in the screenshot flow: the field revert from tx 9001 with `txid`
  produced the exact revert (`w2-5-sonuc.png`, new tx 9101, "Boş → Gebe").

## Decisions and open questions for lead

1. ~~Row/field target has no txid~~ **RESOLVED** by the lead contract update — UI sends `txid` on every `satir`/`alan` hedef.
2. ~~`pk` string vs jsonb~~ **RESOLVED** — scalar for single-column, object for composite; composite row/field revert buttons are now active. **W1 must accept composite pk OBJECTS** (`vaccine_diseases` etc.).
3. **`teknikal_mi` in detail rows.** The frozen detay-row field list does not include it; the UI renders a small "teknik" badge when present. Ask W1 to include `teknikal_mi` in `degisim_listele` detay rows — or the badge dies silently (missing key → falsy).
4. **Nav entry.** The bottom nav already has 6 slots; the entry is a `log-btn` on the Kayıt page (same as Stok / Tanımlar). A 7th bottom-nav button is a small change if preferred.
5. **Stamp.** Because `js/api.js` and `js/ui.js` also changed, all tags (not only the new ones) moved to `20260913-15`, avoiding the known partial-bump trap.
6. **Ticket storage.** `sessionStorage` (`ege_geri_alma_bileti`); expiry computed from client clock + `kalan_sn` (server `son_gecerlilik` not trusted against a shifted device clock; the server re-validates every use), dropped on expiry, on `BILET_*` errors, or via the "Bırak" button; the header shows remaining minutes (refreshed every 30 s).
7. **Review lane.** A memory note says audits should go to a luna worker, but lane rule 1 in the goal requires a builtin-subagent review for workers, and workers cannot dispatch agents. I followed the goal.

## Docs checkpoint (pre-commit)

- `.harness/references/ui-map.md` — new page + symbols → **PROPOSED** (outside my manifest; lead/root reconciles at merge).
- `.harness/references/rpc-reference.md` — 4 new RPC wrappers → **PROPOSED** (same).
- Others → NO_CHANGE_REQUIRED. Aggregate: **PASS** (evaluation done; edits out of worker scope).

## Review (lane rule 1 — builtin subagent)

Reviewer: builtin `code-reviewer` over the full uncommitted diff (read-only).
Verdict: **"Ready to merge? With fixes"** — 1 Critical / 4 Important / 7 Minor.
 XSS/contract/stub-isolation/additive checks came back clean ("every
innerHTML path goes through esc()/escAttr(); … jsonb targets are kept in
memory and looked up by index, never written into attributes").

| # | Finding (class) | Disposition |
|---|---|---|
| C1 | Row/field revert targeted the row's LATEST version, not the change on screen (contract gap) | **RESOLVED by lead contract update**: optional `txid` added to F2 `p_hedef`; UI now always sends `txid`; interim client guard removed as redundant (see contract-update section) |
| I1 | Ticket expiry trusted server `son_gecerlilik` vs client clock | **Fixed**: `_dgBiletYaz` stores `Date.now() + kalan_sn`; server still re-validates every use |
| I2 | When `geri_alinabilir:false`, blockers shown twice (body block + banner) | **Fixed**: body "⛔ Geri alınamaz" block removed; the `#dg-onizle-engel` banner is the single surface |
| I3a | "Listeye dön" left `_dg.detayTxid` set | **Fixed**: cleared in the `dg-liste-don` handler |
| I3b | `online` event while viewing a detail threw the detail away | **Fixed**: `_dgAgDegisti` re-opens the same tx detail on reconnect |
| I4 | Browser back/forward to `#degisiklikler` rendered stale DOM (no loader branch in `goTo`, which is outside the manifest) | **Fixed** without touching `js/app.js`: module listens for `popstate`, completes the page (render + reload + restart ticket timer) when `state.pg === 'degisiklikler'` |
| M1 | 4 wrappers inserted between `rpcCloseCaseWithRemaining`'s JSDoc and the function | **Fixed**: block moved above the JSDoc (impact re-checked: 0 callers, LOW) |
| M2 | `r.teknikal_mi` not in the frozen detail field list | Kept, surfaced to lead as open question 3 |
| M3 | Stacked `closeM` history leak | **Fixed where in reach**: `_dgAgDegisti` closes only modals that are actually open; the onizle→bilet flow closes one modal per user action |
| M4 | Failed "Daha fazla" replaced the loaded list | **Fixed**: error appends under the kept list, page counter rewinds |
| M5 | List cards unreachable by keyboard | **Partially fixed**: `role="button"` added (full focus/Enter handling left to the existing delegation pattern; noted as residual) |
| M6 | Stub seeded once; fake UUIDs stuck if animals not loaded on first call | Accepted for a demo-only stub (single page load); stub dies at W1 merge |
| M7 | No controller tests (pure layers covered) | Accepted: pure-layer tests are the goal's requirement (kabul 4); controller coverage noted as residual |

Re-review after fixes: syntax `node --check` clean; unit suite 814/813/1
(unchanged known red); full screenshot flow re-run green (JSON above).


## Residual risks / unmeasured

- The real RPC path (W1) has not been exercised; only contract-shaped stub responses. The stub is faithful to the goal's jsonb shapes, but W1 must match `ozet.baslik`, `kaynak`, and `detay:true` exactly.
- Screenshots use a real demo session but stub data; acceptance 5 stays PARTIAL until lead integration.
- `hayvan_id` filtering semantics (which rows count as "this animal's") are decided server-side by W1.
- Observed, out of scope, not fixed: clicking Kayıt quickly after load throws `Cannot read properties of undefined (reading 'transaction')` in `js/api.js:idbGetAll` via `js/ui.js:loadStock` (IDB not yet open). It is pre-existing `goTo('log')` behavior, not introduced here.
- Demo console shows one 401 on a demo REST call during boot; pre-existing and unrelated.
