# Toplu Vaka Aç Implementation Report

Goal: `G-20260906-TOPLU-VAKA`

Date: 2026-09-06

Flow: `zcode_builtin`

Root verdict: `PASS`

Per-criterion evidence verified by root 2026-09-06; goal status `review`:
implementation complete, awaiting root close + owner merge approval. Push
and PROD migration remain separately owner-gated.

> Per-criterion verdicts use `PASS` / `PARTIAL` / `FAIL` / `INCONCLUSIVE`
> and stay honest per `.harness/acceptance.md`. Workers cannot mark the
> goal done.

## 1. Launch baseline

```text
launch SHA: eaa0640e65d576c403cbd7aee0fefa66dc81a6f9 (post-rebase)
original base SHA: 434c14236b95a1121339322c548df34c06b9e9e2 (kept as base_sha)
rebase: 434c142 → eaa0640 on 2026-09-06, conflict-free (main advanced
  mid-task with the protokol-dismiss hotfix + reference alignment; no
  overlap conflicts). Pre-rebase implementation shas
  (dfc5643/777bc7b/799c912/1b2bfff) superseded by
  0036fa5/c45fd72/9a89e15/1139798.
branch: idle/toplu-vaka
worktree: /home/melik/egesut-wt/toplu-vaka
manifest: 12 exact paths (goal, report, index.html, js/forms.js, js/ui.js,
          js/utils/handlers.js, js/utils/modal.js, js/utils/helpers.js,
          js/api.js, supabase/migrations/20260906120000_vaka_toplu_ac.sql,
          supabase/migrations/99999999999999_ground_truth.sql,
          tests/unit/vaka-toplu-ac.test.js)
  (ground-truth migration path added to the manifest mid-task by W1 to
  clear a MANIFEST_VIOLATION — goal's own write authority, +1 line,
  disclosed)
pattern_refs: FORM-SUBMIT-01, MODAL-ROUTER-01, RPC-WRITE-01, TESTING-01
db authority: write — DEMO project only; PROD needs separate owner approval
unit suite at launch: `npm run test:unit` → 442/442 PASS (0 fail)
  (fresh worktree lacks gitignored node_modules; run used
  NODE_PATH=/home/melik/egesut-erp1/node_modules — install or keep NODE_PATH
  for local runs)
worktree status at launch: clean
```

## 2. Scope

Bulk case creation ("Toplu Vaka Aç"): modal `m-bulk-case` + dashboard tile
(`open-bulk-case`), `m-disease`-mirroring form with multi-küpe chips + paste
box, ONLINE-ONLY single-RPC submit `vaka_toplu_ac`, IndexedDB mükerrer
pre-check with confirm, pullTables with the `submitCase` set, per-animal
result list; migration `20260906120000_vaka_toplu_ac.sql` refactoring
`create_case` into `_vaka_ac_tek` + bulk loop with şablon application.
Exclusions per goal: dosing matrix panel, padok tabs, süt yasağı, bulk_ilac
double-decrement fix.

## 3. Implementation and evidence

Per-criterion status:

| # | Acceptance criterion | Verdict | Evidence |
|---|---|---|---|
| 1 | Red-before unit tests (mükerrer pre-check + küpe chip/paste logic) | `PASS` | W3 captured verbatim before implementation: 12 failures — `TypeError: sb.bcMukerrerBul is not a function` ×6 and `TypeError: sb.bcSonucSatirlari is not a function` ×6 in tests/unit/vaka-toplu-ac.test.js against unmodified sources; 5 pre-existing `bcKupeParse` coverage tests already green (§3.1) |
| 2 | Unit suite green: `npm run test:unit` | `PASS` | baseline 442/442 → final 465/465 pass, 0 fail, exit 0; +17 new (vaka-toplu-ac) + +6 protokol-dismiss arrived via rebase; command and counts in §3.2 |
| 3 | `vaka_toplu_ac` in `RPC_TABLES`, NOT in `RPC_MAP` | `PASS` | js/api.js:314 `vaka_toplu_ac: ['cases','diseases',...]` (additive entry); js/ui.js `RPC_MAP` (dataTrafficTekGonder, lines 7438-7447) contains no `vaka_toplu_ac` entry — offline replay unchanged |
| 4 | Migration on DEMO DB + demo-mode manual E2E (şablon path, duplicate-skip path) | `PASS` | migration applied to DEMO via Management API (HTTP 201, catalog verified); browser E2E covered şablon path (5/5 açıldı, 15 treatment_days, 30 drug_administrations, positive-only stok_hareket) and duplicate-skip path (5/5 atlanan with server guard messages) — §3.4. External DB effects are ATTESTED, never VERIFIED. Demo parity of pre-migration `create_case` state: `INCONCLUSIVE`-to-good (applied to demo directly; demo pre-state not separately captured) |
| 5 | GitNexus impact pre-check on touched JS symbols before edits | `PASS` | per-worker pre-checks: `_renderSablonSecim` LOW, `onDiseaseSelect` LOW, `openM` LOW (via uid), `acHayvan` MEDIUM — `acHayvan` NOT modified, new `acHayvanMulti` added alongside; ac-hayvan.test.js 7/7 before+after (§3.5) |
| 6 | Read-only live-schema probe (create_case, tedavi_sablon_uygula, _tohumlama_gorev_uygunluk, add_drug_administration) | `PASS` | W1 Management API pg_catalog/pg_get_functiondef probe, zero writes: create_case body byte-identical to GT:3569-3633 incl. all 3 guard messages; tedavi_sablon_uygula matches GT:4802; tedavi_sablon_tohumlama_gorev_ekle EXISTS in PROD (absent from GT — documented drift); _tohumlama_gorev_uygunluk EXISTS in PROD (rpc-reference.md:581 flag verified correct); add_drug_administration signature identical to GT:893 (§3.3) |
| 7 | `harness.py validate --json` zero findings | `PASS` | `{"ok": true, "goal_count": 8, "decision_count": 2, "pattern_count": 5, "findings": []}` re-run after goal/report finalization (2026-09-06) |
| 8 | Root diff review; merge/push and PROD migration only after owner approval | `PASS` | root reviewed the diff via hunk analysis (§4); detect_changes(compare main) = 11 changed files = write manifest exactly; merge/push NOT performed (owner-gated), PROD migration NOT applied (owner-gated) — gating respected |

### 3.1 Red-before evidence

`tests/unit/vaka-toplu-ac.test.js` run against unmodified sources before
implementation (captured verbatim by W3): 12 failures, all of the shape

```text
TypeError: sb.bcMukerrerBul is not a function   ×6
TypeError: sb.bcSonucSatirlari is not a function ×6
```

The 5 pre-existing `bcKupeParse` coverage tests were green in the same run —
the failures are the new enforcement surface, not harness breakage. After
implementation the same file is green inside the 465/465 final run.

### 3.2 Test runs

```text
baseline: NODE_PATH=/home/melik/egesut-erp1/node_modules \
            node --test tests/unit/*.test.js   (npm run test:unit script)
          → 442/442 pass, 0 fail (launch, pre-rebase base)
final:    NODE_PATH=/home/melik/egesut-erp1/node_modules \
            node --test tests/unit/*.test.js   (worktree, post-rebase)
          → 465/465 pass, 0 fail, exit 0
delta:    +17 new tests in tests/unit/vaka-toplu-ac.test.js
          +6 protokol-dismiss tests arrived via the rebase (442+17+6=465)
focused:  tests/unit/ac-hayvan.test.js 7/7 before and after
```

### 3.3 Live-schema probe

W1, read-only via Management API (`pg_catalog` / `pg_get_functiondef`),
zero writes:

- `create_case(text,uuid,uuid)`: body byte-identical to GT:3569-3633,
  including all three guard messages (hayvan aktif, disease mevcut,
  aktif-vaka mükerrer → `{ok:false, mesaj}`).
- `tedavi_sablon_uygula`: matches GT:4802.
- `tedavi_sablon_tohumlama_gorev_ekle`: EXISTS in PROD — absent from GT
  (documented migration drift, confirmed rather than assumed).
- `_tohumlama_gorev_uygunluk`: EXISTS in PROD — absent from GT;
  rpc-reference.md:581 flag verified correct.
- `add_drug_administration`: signature identical to GT:893.

Local PG behavioral tests (throwaway PostgreSQL 18.6 scratch cluster,
deleted after): all 3 create_case guards verbatim; `vaka_toplu_ac` empty-list
guard; >200 cap guard; order-preserving dedupe (6→4); duplicate-active →
`atlanan` with kupe; per-animal EXCEPTION → `hatalar`; şablon-engine
exception → `hatalar` with case_id (case stays active); helper-absent →
`toplanti_uygulandi:false`; `VAKA_ACILDI` snapshot shape identical to GT.

### 3.4 DEMO E2E evidence

Migration: `20260906120000_vaka_toplu_ac.sql` applied to DEMO (project
vtzqjmazsvurxdeondmi) via Management API — curl + `jq -Rs` byte-exact
payload, HTTP 201, no error. Post-apply catalog verification: 
`vaka_toplu_ac(text[],uuid,uuid,uuid)` and `_vaka_ac_tek(text,uuid,uuid)`
exist; `create_case(text,uuid,uuid)` wrapper with anon+authenticated EXECUTE
true. NOT applied to PROD (owner-gated).

Browser E2E (root; worktree serve :8097, `?demo` auto-login, tab closed
after):

- Kayıt page: "🩺🩺 Toplu Vaka" tile sibling of Vaka Aç, opens
  `m-bulk-case`; all 12 `bc-*` elements present; 45 diseases loaded.
- Autocomplete multi-entry: typed `002` → dropdown (data-kupe rows) →
  picked → chip `002✕`, input cleared, dropdown closed; same for `008`;
  counter "2 hayvan".
- Paste box: `01\n015, 02` → resolved → chips 002/008/01/015/02, counter
  "5 hayvan", paste box cleared, bulunamayan empty.
- Disease "Klinik Mastit" → category chip "📂 Meme"; şablon radio list:
  "Enrolen mastit 3 gün · 6 seans", "5 x 30 sefanel 5 gün · 5 seans",
  default "Şablonsuz (boş vaka aç)"; radio pick set `_bcSeciliSablonId`.
- Submit #1 → result "Toplam 5 · Açılan 5 · Atlanan 0 · Hata 0", each row
  "✅ <kupe> — vaka açıldı + 3 gün şablon".
- Demo DB verification (Management API): cases×5 active (Klinik Mastit,
  start_date=CURRENT_DATE, küpeler 002/008/01/015/02); treatment_days×15;
  drug_administrations×30 (= 6 seans × 5 hayvan); islem_log VAKA_ACILDI×5 +
  TEDAVI_GUN_EKLENDI×15 (tarih>2026-09-06); stok_hareket tur='Tedavi'×30
  positive (miktar 50, notlar 'drug_admin:<uuid>') — positive-ledger-only,
  no `baslangic_miktar` double-deduct (new RPC follows the correct pattern;
  the legacy `bulk_ilac` double-deduction is a separate deferred item).
- Submit #2 (same 5 + same disease) → `openConfirm` "⚠️ Aktif vaka
  mükerrer" listing all 5 küpeler + "Bu hayvanlar atlanacak. Devam edilsin
  mi?" (İptal/Onayla) → Onayla → "Toplam 5 · Açılan 0 · Atlanan 5 · Hata 0",
  each "⏭ <kupe> — Bu hayvan için zaten aktif bir Klinik Mastit vakası
  mevcut" (server guard messages surfaced per-animal).
- Single-animal regression: `m-disease` Vaka Aç still opens, disease select
  + şablon radio work, `_seciliSablonId` set (Pnömoni/Solunum). No submit
  performed (no extra data).
- NOT live-tested: `geri_al` undo of a bulk-created case (snapshot shape
  verified only on the scratch cluster; deleting demo rows requires owner
  approval).

### 3.5 GitNexus discipline

Impact pre-checks run per worker before edits: `_renderSablonSecim` LOW,
`onDiseaseSelect` LOW, `openM` LOW (via uid), `acHayvan` MEDIUM — `acHayvan`
NOT modified; new `acHayvanMulti` added alongside; ac-hayvan.test.js 7/7
before+after.

`detect_changes` (compare main, worktree): 11 changed files = write manifest
exactly. Symbol-level "critical" listing is largely line-shift attribution
noise — root verified via hunk analysis that semantic touches are only:
`_renderSablonSecim` default-param refactor, `openM` id-gated hook,
`RPC_TABLES` additive entry, new `bc*`/`acHayvanMulti` functions, new
ACTIONS entries; no existing function body edited except
`_renderSablonSecim`.

## 4. Independent review

Reviewer: root (2026-09-06). Diff semantics checked via hunk analysis
against the detect_changes listing rather than worker summaries — semantic
touches confined to the five areas listed in §3.5; no existing function body
edited except `_renderSablonSecim`. Pattern conformance: FORM-SUBMIT-01
(online-only guard, thrown-`.data` error handling, pullTables `submitCase`
set, busy state), MODAL-ROUTER-01 (`closeM` paths, `openM` reset hook),
RPC-WRITE-01 (RPC_TABLES registration, not offline-replayable), TESTING-01
(red-before, focused regression). Gating: every commit went through
docs-update pre-commit (PASS) + receipt-check (ok) + commit-gate --goal
(ok:true, findings []); W1 recovered one MANIFEST_VIOLATION by adding the GT
path to the goal manifest (goal's own write authority, +1 line, disclosed);
W3 first docs-update attempt FAIL (missing --surface evaluations) resolved
by passing explicit evaluations. Repo pre-commit hook self-skips on idle/*
branches by design — harness gates were authoritative. Merge/push and PROD
deploy await owner approval.

## 5. Checkpoint evidence

```text
pre-commit: staged receipt PASS recorded at goal open (goal-bound)
implementation commits (post-rebase):
  0036fa5 docs(harness): open goal G-20260906-TOPLU-VAKA
  c45fd72 feat(ui): m-bulk-case modalı — küpe çoklu seçim (chip+yapıştır),
          hastalık/şablon formu
  9a89e15 feat(db): vaka_toplu_ac RPC — create_case _vaka_ac_tek helper
          refactor + GT sync
  1139798 feat(ui): toplu vaka gönderim akışı — mükerrer uyarısı,
          vaka_toplu_ac çağrısı, sonuç listesi + testler
  ad40561 docs(harness): G-20260906-TOPLU-VAKA rapor doldurma + rebase
          sonrası launch hizalama
  dcd8128 feat(db): vaka_toplu_ac V1.1 — p_items manuel ilaç listesi
          (gün 1 uygulama, add_treatment_day_with_sessions motoru)
  5e463d9 feat(ui): toplu vaka manuel ilaç listesi — cdf-chk dili,
          şablon/mutual exclusion, dinamik buton + testler
  (7 commits on branch idle/toplu-vaka; branch tip 5e463d9)
docs checkpoints:
  pre-review @ 1139798 — docs_verdict PASS (V1 docs commit)
  pre-review @ 5e463d9 — docs_verdict PASS (V1.1 amendment docs commit)
  handoff/final: not recorded — root close + owner merge approval pending
residual risks: see §6
temporary mutations and artifacts restored:
  - throwaway PostgreSQL 18.6 scratch cluster deleted after behavioral tests
  - browser tab closed after E2E; serve process stopped
  - demo rows NOT deleted (owner data — listed in §7 for owner review)
```

Root acceptance: implementation complete — goal moved to `review`; merge,
push and PROD migration happen only after owner approval.

## 6. Residual risks / open items

1. PROD migration NOT applied — owner-gated; before PROD deploy re-run the
   read-only probe (GT drift already ruled out for the five functions).
2. `geri_al` of bulk-created cases untested live (snapshot shape verified on
   the scratch cluster only).
3. rpc-reference.md row for `vaka_toplu_ac` + `create_case` wrapper note =
   propose_only, separate docs commit after merge.
4. `bulk_ilac` çifte stok düşümü bug deferred (see
   `.claude/DEFERRED_FEATURES.md`, 2026-09-06 entry).
5. Online-only by design (offline demo kullanılamaz — `submitCase`
   paraleli).
6. 200-hayvan cap (UI toast + RPC guard).

## 7. Demo rows created (owner data — NOT deleted, listed for owner review)

5 active cases (küpeler 002, 008, 01, 015, 02 × Klinik Mastit, notes "E2E
toplu vaka testi — 5 hayvan, Enrolen mastit şablonu (otomatik test)") and
their dependents: 15 treatment_days, 30 drug_administrations, 30
TEDAVI_GUN/TEDAVI_SEANS görev rows, 30 stok_hareket ledger rows, 20
islem_log rows.

## V1.1 Amendment (2026-09-06, owner feedback)

V1 (8×PASS above, status review) was extended the same day after owner
feedback: the modal must not end at opening cases — an entered treatment
must APPLY to all animals. W5 added the RPC layer (p_items), W6 the manual
drug-list UI; W5 re-opened the goal (status→active) and added acceptance
criterion 9. Root has since verified V1.1 end-to-end (below); the goal
returns to `review` with criterion 9 `PASS`. All V1 content above stays
intact; only the §5 commit/checkpoint lists were extended (7 commits on
branch).

### V1.1 commits

- `dcd8128` feat(db): vaka_toplu_ac V1.1 — p_items manuel ilaç listesi
  (gün 1 uygulama, add_treatment_day_with_sessions motoru)
- `5e463d9` feat(ui): toplu vaka manuel ilaç listesi — cdf-chk dili,
  şablon/mutual exclusion, dinamik buton + testler

Branch tip: `5e463d9`. Full branch sequence (7 commits):
0036fa5 → c45fd72 → 9a89e15 → 1139798 → ad40561 → dcd8128 → 5e463d9.

### RPC v2 contract

```text
vaka_toplu_ac(p_animal_ids text[], p_disease_id uuid,
              p_items jsonb DEFAULT NULL, p_sablon_id uuid DEFAULT NULL,
              p_notes text DEFAULT NULL) → jsonb
```

- `p_items` ↔ `p_sablon_id` mutual exclusion: both supplied →
  `{ok:false}`; UI mirrors the same exclusion in both directions.
- Per-item fail-fast validation: any invalid kalem returns
  `{ok:false, mesaj:'Geçersiz ilaç kalemi: <index>: <sebep>'}` before any
  case is created.
- Per-animal day-1 application runs the verbatim
  `add_treatment_day_with_sessions` engine (bug059, migration
  20260611000002) — treatment_days + treatment_day_uygulamalar +
  drug_administrations + stok_hareket + TEDAVI_GUN/TEDAVI_SEANS görevleri —
  the same engine the şablon path already feeds; şablon path unchanged.
- planned_time discovery: the engine requires NOT NULL
  (`treatment_day_uygulamalar.planned_time` is `time NOT NULL` per
  migration 20260611000001; the NOT NULL violation was proven on the
  scratch cluster) → manual items missing/empty `planned_time` are coerced
  to `'09:00'`; the şablon path is unaffected (it supplies its own times).
- Engine results are captured per animal as `acilan[i].manuel =
  {day_no, seans_sayisi}`.
- The old 4-arg variant is DROPped first (overload avoidance);
  catalog-verified gone from demo.

### UI (manual drug list in m-bulk-case)

- cdf-chk drug-picker language copied into `m-bulk-case`: `bc-ilac-*` ids,
  32 drugs rendered, search filter, dose rows prefilled with unit/route.
- Mutual exclusion both directions: picking a şablon disables/clears drug
  rows and vice versa.
- Dynamic submit label: "💊 Tedaviyi Uygula" when drug items are entered,
  "🩺 Vakaları Aç" otherwise.
- Result rows: "✅ <kupe> — vaka açıldı + N ilaç".

### Tests (V1.1)

```text
V1 final:  465/465 pass, 0 fail
V1.1 final: 481/481 pass, 0 fail  (+16, RED→GREEN)
RED: W6 captured 14 RED TypeErrors against unmodified sources before
     implementing the UI layer
engine finding: planned_time NOT-NULL requirement documented under the
     RPC contract above (scratch-cluster proof)
```

### Root E2E (demo, browser) — criterion 9: PASS

3 animals (002/008/01) + Pnömoni + 2 manual drugs (Enrolen 10 ml IM +
Meloksikam 10 ml):

- Result: "Toplam 3 · Açılan 3 · Atlanan 0 · Hata 0", each row
  "vaka açıldı + 2 ilaç".
- Mutual exclusion observed live: şablon selected → a drug was checked →
  the radio snapped back to "Şablonsuz", `_bcSeciliSablonId` null, submit
  button flipped to "💊 Tedaviyi Uygula".
- DB verification (demo): 3 active Pnömoni cases (start_date =
  CURRENT_DATE); drug_administrations ×6; treatment_day_uygulamalar ×6 all
  planned_time='09:00'; stok_hareket tur='Tedavi' ×6 positive (timestamps
  after 08:30Z).
- Acceptance criterion 9 ("Manual drug path E2E: bulk case + day-1
  drug_administrations per animal verified in demo"): `PASS`.

### Demo rows created by V1.1 E2E (owner data, not deleted)

3 Pnömoni cases (küpeler 002/008/01) + 6 drug_administrations + 6 sessions
(treatment_day_uygulamalar) + 6 stok_hareket ledger rows.

### V1.1 residual notes

1. `planned_time` is hardcoded to the `'09:00'` default for manual items —
   the UI has no time input (YAGNI); per-dose time only if the owner asks.
2. W6 left a disposable GitNexus probe index `wt-toplu-vaka-w6-probe`
   registered — cleanup at goal close.
3. The worktree `node_modules` is symlinked to the main repo (gitignored).
