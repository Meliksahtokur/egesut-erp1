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
  8ada4b5 docs(harness): G-20260906-TOPLU-VAKA V1.1 rapor + criterion 9
          PASS, status review
  197fbce feat(ui): toplu vaka tarih planlama + tohumlama bölümü —
          birleşik uyarı, erkek/yaş ön-kontrolü + testler
  6d2a285 feat(db): vaka_toplu_ac V1.2 — p_tarih planlama (start_date
          çapası) + tohumlama görevi (vaka_tohumlama_ekle yeniden
          kullanımı)
  afe8791 docs(harness): G-20260906-TOPLU-VAKA V1.2 rapor + criterion 10
          PASS, status review
  02ee51b docs(harness): G-20260906-TOPLU-VAKA V2 direction — çoklu gün
          plan editörü (owner netleştirmesi)
  79ac4e0 feat(db): vaka_toplu_ac V2 — gün-anahtarlı p_items (çoklu
          tarihli plan, saat önceliği kalem>gün>09:00)
  39468f5 feat(ui): toplu vaka çoklu gün plan editörü — gün sekmeleri,
          gün/kalem saati, tohumlama bloğu keşfedilebilirliği + testler
  3f701a9 docs(harness): G-20260906-TOPLU-VAKA V2 rapor + criterion 11
          PASS, status review
  e7d96fb feat(ui): plan editörü v2.1 — gün kartları (boşluklu gün
          №+takvim), seans A/B saat-grup dili, gün kopyalama
  b32fb65 feat(ui): bantlı sonuç/uyarı düzeni + pre-line satır düzeltmesi +
          tohumlama çakışma uyarısı
  1b62258 feat(db): tedavi_sablon_kaydet boşluk koruması — DENSE_RANK
          kaldırıldı (+GT)
  32f73b9 feat(db): vaka_toplu_ac p_tohumlama_cakisma —
          uzerine_yaz=iptal / atla modları (+GT, goal V2.2)
  57ffd15 fix(ui): takvim ay-geçiş/gün-seçim bug'ı — saf durum
          fonksiyonları + RED-önce testler + TR tarih başlığı
  aaa79ca feat(ui): çoklu hedef gün kopyalama + sonuç satırından hayvan
          kartına geçiş
  a247bec feat(ui): planı şablon olarak kaydet (devam edit) + tohumlama
          çakışma radyosu (üzerine yaz/atla)
  (23 commits on branch idle/toplu-vaka since launch eaa0640 through tip
  a247bec — rev-list verified; 24 incl. this V2.2 docs amendment;
  sequence 0036fa5…a247bec)
docs checkpoints:
  pre-review @ 1139798 — docs_verdict PASS (V1 docs commit)
  pre-review @ 5e463d9 — docs_verdict PASS (V1.1 amendment docs commit)
  pre-review @ 6d2a285 — docs_verdict PASS (V1.2 amendment docs commit)
  pre-review @ 39468f5 — docs_verdict PASS (V2 delivery docs commit)
  pre-review @ b32fb65 — docs_verdict PASS (V2.1 delivery docs commit)
  pre-review @ a247bec — docs_verdict PASS (V2.2 delivery docs commit)
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

## V1.2 Amendment (2026-09-06, owner feedback)

V1.1 (criterion 9 PASS above, status review) was extended the same day after
further owner feedback: bulk case opening must support DATE PLANNING and a
PLANNED-INSEMINATION option. W7 added the RPC layer (v3), W8 the UI layer;
W7 re-opened the goal (status→active) and added acceptance criterion 10.
Root has since verified V1.2 end-to-end (below); the goal returns to
`review` with criterion 10 `PASS`. All V1/V1.1 content above stays intact;
only the §5 commit/checkpoint lists were extended (11 commits on branch).

### V1.2 commits

- `6d2a285` feat(db): vaka_toplu_ac V1.2 — p_tarih planlama (start_date
  çapası) + tohumlama görevi (vaka_tohumlama_ekle yeniden kullanımı)
- `197fbce` feat(ui): toplu vaka tarih planlama + tohumlama bölümü —
  birleşik uyarı, erkek/yaş ön-kontrolü + testler

Branch tip at amendment: `6d2a285` (this docs amendment lands on top).
Full branch sequence — 11 commits, 0036fa5…6d2a285 plus this V1.2 docs
amendment:
0036fa5 → c45fd72 → 9a89e15 → 1139798 → ad40561 → dcd8128 → 5e463d9 →
8ada4b5 → 197fbce → 6d2a285 → (this docs amendment).

### RPC v3 contract

```text
vaka_toplu_ac(p_animal_ids text[], p_disease_id uuid,
              p_items jsonb DEFAULT NULL, p_sablon_id uuid DEFAULT NULL,
              p_notes text DEFAULT NULL, p_tarih date DEFAULT NULL,
              p_tohumlama boolean DEFAULT false,
              p_tohumlama_gun_offset int DEFAULT 0,
              p_tohumlama_saat text DEFAULT NULL) → jsonb
```

- ROOT DECISION — start_date anchor: `p_tarih` is the planned START date
  and is WRITTEN to `cases.start_date` — the first-ever non-default
  start_date write in the modern case system. Rationale: one coherent
  anchor for everything — şablon günleri land at `start_date+(n-1)`
  automatically (the `tedavi_sablon_uygula` engine reads
  `v_case.start_date`), manuel day-1 lands at `p_tarih`, and the tohumlama
  target is `start_date + p_tohumlama_gun_offset` — instead of drifting
  per-table dates. `NULL p_tarih` → CURRENT_DATE (today's behavior
  unchanged); `p_tarih < CURRENT_DATE` →
  `{ok:false, mesaj:'Geçmiş tarih planlanamaz'}` fail-fast before any case
  is created.
- `_vaka_ac_tek` gains `p_tarih date DEFAULT NULL` (last param) and the
  INSERT sets `start_date = COALESCE(p_tarih, CURRENT_DATE)` explicitly.
  The `create_case` wrapper signature is UNCHANGED (passes NULL — the
  single-animal flow still defaults to today). The manual engine call
  becomes `add_treatment_day_with_sessions(case, COALESCE(p_tarih,
  CURRENT_DATE), items, NULL)`.
- Tohumlama option (`p_tohumlama` true): every successfully opened case
  (after şablon/manuel) reuses the EXISTING
  `public.vaka_tohumlama_ekle(case, start_date + p_tohumlama_gun_offset,
  COALESCE(p_tohumlama_saat,'08:00')::time)` behind a per-case SOFT
  pg_proc guard (GT-drift safe, same pattern as the şablon tohumlama
  helper). Soft skip is never counted in `hatalar`:
  `ok:true → acilan[i].tohumlama = {olustu:true, gorev_id}`;
  `ok:false / EXCEPTION → {olustu:false, sebep:<server mesaj>}` with the
  exact eligibility reasons ('Erkek hayvana tohumlama görevi açılmaz',
  'Hayvan hedef tarihte 12 aydan küçük', 'Hayvan gebe') plus 'Bu vakada
  zaten açık bir planlı tohumlama var' when the şablon path already opened
  one; RPC absent (GT drift) → `sebep:'Tohumlama RPC yok'`. The case stays
  open in every soft path.
- Bounds (fail-fast): `p_tohumlama_gun_offset` integer 0..365 else
  `{ok:false, mesaj:'Tohumlama gün ofseti 0-365 aralığında olmalı'}`;
  `p_tohumlama_saat` NULL → '08:00', else must match
  `^([01][0-9]|2[0-3]):[0-5][0-9]$` else `{ok:false, mesaj:'Geçersiz
  saat'}`.
- `acilan[i]` gains `tarih` (the case's actual start_date ISO); the
  top-level result gains `tohumlama` boolean. The old 5-arg variant is
  DROPped first (overload avoidance).

### Scratch-cluster behavioral tests + demo catalog (all PASS)

Throwaway PostgreSQL scratch cluster (deleted after): past-date block
('Geçmiş tarih planlanamaz'), offset bounds (0..365), saat regex (incl.
'Geçersiz saat'), future anchor (+30d `p_tarih`, +14:30 saat), eligibility
reasons exact (Erkek / young / gebe / şablon-collision), RPC-absent soft
skip ('Tohumlama RPC yok'), `create_case` wrapper default (NULL → today).

Demo catalog after apply: 9-param `vaka_toplu_ac` live, the 5-arg variant
gone (overload-drop verified), `_vaka_ac_tek` 4-arg with `p_tarih`.

### UI (date planning + tohumlama block in m-bulk-case)

- `bc-tarih` date input with `min=today` and a dynamic hint
  ("Vaka ve tüm tedavi günleri <date> gününe planlanacak").
- 🐄 tohumlama block: gün-ofset input + saat input (default 08:00,
  HIZLI_SAATLER quick-pick chips). Visibility rule: hidden while no
  animals are selected or the selection is all-Erkek.
- Combined single `openConfirm`: one confirm lists BOTH mükerrer warnings
  and tohumlama-uygunsuz warnings. The client mirrors the server rules for
  the pre-check (durum Aktif, cinsiyet Erkek, <365 days AT THE TARGET date
  via Date.UTC); pregnancy is deliberately NOT approximated client-side
  (server-only).
- Result rows gain suffixes: `· 🐄 tohumlama HH:MM` on success,
  `· ⏭ tohumlama: <sebep>` on per-case soft skip.

### Root E2E (demo, browser) — criterion 10: PASS

Worktree serve :8097, `?demo` auto-login, browser, 2026-09-06. Paste
`002\n008\n39` (2 Dişi + 1 Erkek) → 3 chips. `bc-tarih` set to +2 days →
hint "Vaka ve tüm tedavi günleri 2026-09-08 gününe planlanacak". Tohumlama
block visible (≥1 Dişi), checkbox on, offset 0, saat 08:00. Disease
Enterit (şablonsuz default, no drugs). Submit → single combined confirm
"⚠️ Uyarılar": "• 39 — Erkek hayvana tohumlama görevi açılmaz —
tohumlaması atlanacak / Devam edilsin mi?" → Onayla → result
"Toplam 3 · Açılan 3 · Atlanan 0 · Hata 0"; rows: 002/008
"✅ — vaka açıldı · 🐄 tohumlama 08:00", 39 "✅ — vaka açıldı · ⏭
tohumlama: Erkek hayvana tohumlama görevi açılmaz".

DB verification (demo): 3 Enterit cases with `start_date=2026-09-08` —
the first future-dated cases ever written by this system;
TOHUMLAMA_PLANLI görev rows ONLY for 002/008 (hedef_tarih 2026-09-08,
hedef_saat 08:00, kaynak 'TEDAVI_SABLON_TOHUMLAMA:<case>:MANUEL', open) —
39 has none.

Acceptance criterion 10 ("V1.2 E2E: future-dated bulk case (şablon or
manuel) anchors days+tohumlama to planned date; male/young animals'
tohumlama skipped with exact reasons in demo"): `PASS`.

### Tests (V1.2)

```text
V1.1 final: 481/481 pass, 0 fail
V1.2 final: 497/497 pass, 0 fail
delta: +16 in tests/unit/vaka-toplu-ac.test.js (RED→GREEN):
       bcTohumUygunOlmayanlar ×8 (incl. the target-date-not-today age
       case), bcGecmisPlanTarihiMi ×4, bcSonucSatirlari V1.2 ×4
RED: W8 captured 14 RED failures verbatim against unmodified sources
     before implementing the UI layer
```

### Demo rows created by V1.2 E2E (owner data, not deleted)

3 future-dated Enterit cases (start_date 2026-09-08; küpeler 002/008/39) +
2 TOHUMLAMA_PLANLI görev rows (002/008).

### V1.2 residual notes

1. Pregnancy (gebe) eligibility is server-only by design; the client
   deliberately ships NO gebe approximation — its pre-check covers
   durum/cinsiyet/age-at-target-date only.
2. HIZLI_SAATLER chips are a UI convenience over the same 08:00 RPC
   default — no contract surface of their own.
3. rpc-reference.md rows for the v3 signature and the live-schema sync
   remain propose_only, deferred to the post-merge docs commit (same as
   the V1/V1.1 items in §6).

## V2 Amendment — UI multi-day plan editor (W10, 2026-09-06)

Scope (worker W10, files: `index.html`, `js/forms.js`, `js/utils/handlers.js`,
`tests/unit/vaka-toplu-ac.test.js`): the single 💊 ilaç listesi became a
MULTI-DAY plan editor copying the m-sablon builder language
(`openSablonBuilder`/`sablonSeansAc`, js/ui.js) while keeping the existing
bc ilaç list renderer language (cdf-chk rows + dose rows). FROZEN RPC
CONTRACT v4 (`p_items` day-keyed) is implemented by W9 in parallel; this
commit contains ONLY the UI layer + tests.

### UI surface

- Day tabs (`#bc-gun-sekme`, `.ek-chip`/`.aktif` language): per-day chips
  with selected-drug count badge; `＋ Gün` (`bc-gun-ekle`) appends a day;
  `− Gün` (`bc-gun-sil`) deletes the ACTIVE day (no confirm — planned rows
  only). Max 31 days → toast '⚠️ En fazla 31 gün'. Day numbers are
  ORDINALS: after add/remove the array renumbers 1..N; RPC `gun` = ordinal.
- Day-level saat input `#bc-gun-saat` (label "Gün saati (boşsa 09:00)"),
  `data-change="bc-gun-saat"` → active day's default saat.
- Dose rows gain per-kalem saat input `bc-isaat-<drugId>-g<gunNo>`
  (placeholder "gün saati"), read at harvest/collect time (same static
  wiring as `bc-idoz-*`).
- TOHUMLAMA discoverability fix: `#bc-tohum-blok` is ALWAYS visible; state
  comes from pure `bcTohumBlokDurumu(hayvanlar)` →
  `{mod:'disabled-bos'|'disabled-erkek'|'aktif', ipucu}`; disabled =
  opacity .5 + pointer-events:none (no silent uncheck — checkbox state is
  kept and simply not read while disabled; submit reads it only when
  mod==='aktif').
- State: `globalThis._bcGunler = [{gun, saat, secili:{drugId→{name,dose,
  unit,route,saat,legacy,stock_id}}}]`, `globalThis._bcAktifGun`; tab
  switch harvests the active day's DOM inputs into state
  (`_bcHarvestAktifGun`) then re-renders list/rows/tabs.
- Mutual exclusion generalized: a checked drug on ANY day snaps şablon to
  Şablonsuz (`bcIlacChkChange → bcSablonaDonustur`); a şablon pick clears
  ALL days' selections (`bcSablonIlacTemizle`).
- `bcGunlardenItems()` replaces `bcIlacSecilenler()` (V2 collector): all
  days empty → `{hatalar:[], items:[]}` (old şablon/no-drug flow); any
  kalem anywhere → per-day collection with 'Gün N: ' prefixed errors and
  'Gün N: en az bir ilaç seçin' for empty days; saat fields sent ONLY when
  filled (precedence kalem>gün>'09:00' is server-side per contract v4).
- Result rows: `acilan[i].manuel = {gun_sayisi, seans_sayisi}` →
  '✅ <kupe> — vaka açıldı + N gün · M ilaç' via pure `bcManuelSatirEki`
  (falls back to '+ M ilaç' / no suffix when fields missing).

### Tests (V2)

```text
V2 final: 516/516 pass, 0 fail (npm run test:unit)
delta: +19 net vs V1.2's 497 baseline
RED: 26 failing tests captured against unmodified sources, verbatim:
     TypeError: sb.bcGunlardenItems is not a function /
     sb.bcTohumBlokDurumu is not a function /
     sb.bcGunEkle / sb.bcGunSil / sb.bcManuelSatirEki is not a function
ADAPTATIONS (deliberate, internal shape change):
  a. bcIlacSecilenler (7 V1.1 tests) → bcGunlardenItems suite: same
     scenarios re-expressed day-keyed with 'Gün N: ' prefixed error
     strings and state setup (dose/unit/legacy/çoklu-sıra/hep-boş).
  b. bcSablonIlacTemizle: 'doz alanı display=none' assertion REPLACED by
     all-days secili-clear assertion (doz alanı is always visible in V2).
  c. bcButonMetni: +1 state-based test (drug only on day 2, DOM empty).
```

### Verify (V2)

- `node --check js/forms.js js/utils/handlers.js` → OK
- DOM cross-check: `bc-gun-sekme`/`bc-gun-ekle`/`bc-gun-sil`/`bc-gun-saat`
  each present exactly once in index.html; `data-change="bc-gun-saat"`
  wired; 4 new actions registered in `js/utils/handlers.js`; per-kalem
  `bc-isaat-<id>-g<gun>` emitted by `_bcDozSatiri`.
- Serve check: python3 http.server :8098 on the worktree; curl markers for
  all new ids → 200/1; server killed, `ss -tln` confirms :8098 released.
- GitNexus impact pre-check: submitBulkCase LOW (1 direct caller, the
  handler registration); all touched bc* symbols are internal to the
  bulk-case flow (forms.js internal + handlers.js registrations +
  modal.js onOpen hook); no HIGH/CRITICAL.
- NOTE: E2E against the frozen v4 RPC (day-keyed engine, per-day saat,
  partial-day failure semantics) is deferred to root after W9's migration
  lands in demo; this commit is UI-only and its unit suite is the gate.

### Docs (V2)

- ui_map / ui_patterns: NO_CHANGE_REQUIRED at their granularity —
  modal↔action wiring (open/submit/close) unchanged; reference-doc rows
  for the V2 controls follow the goal's established propose_only deferral
  to the post-merge docs commit (§6 / V1.2 item 3).

## V2 Delivery (2026-09-06)

W9 (RPC v4) and W10 (UI multi-day plan editor — section above) landed the
V2 direction; root has since verified V2 end-to-end (below). All
V1/V1.1/V1.2 content above stays intact; only the §5 commit/checkpoint
lists were extended (14 commits on branch). The goal returns to `review`
with acceptance criterion 11 `PASS`.

### V2 commits

- `79ac4e0` feat(db): vaka_toplu_ac V2 — gün-anahtarlı p_items (çoklu
  tarihli plan, saat önceliği kalem>gün>09:00)
- `39468f5` feat(ui): toplu vaka çoklu gün plan editörü — gün sekmeleri,
  gün/kalem saati, tohumlama bloğu keşfedilebilirliği + testler

(preceded by `02ee51b`, the V2 direction docs commit). Branch tip at
delivery: `39468f5` — this docs amendment lands on top. Verified branch
count: `git rev-list --count eaa0640..39468f5` = **14** commits since
launch (15 including this V2 docs amendment); sequence
0036fa5 → … → 39468f5.

### RPC v4 contract (day-keyed p_items)

The signature is UNCHANGED — the same 9 params as v3; only the `p_items`
shape evolved:

```text
[{"gun": <int 1..31, unique>, "saat"?: "<HH:MM>",
  "kalemler": [{"drug_product_id", "stok_id", "dose">0, "unit",
                "route"?, "saat"?}]}]
```

- planned_time precedence per kalem: `kalem.saat > gün.saat > '09:00'`.
- Day N anchors at `start_date + (N - 1)`; each day executes through the
  verbatim `add_treatment_day_with_sessions` engine.
- KISMİ GÜN SEMANTİĞİ (partial-days-on-error): PER-DAY BEGIN/EXCEPTION
  sub-block — an engine `ok:false` or EXCEPTION on day N pushes
  `hatalar[{gun: N, case_id}]`, the case STAYS OPEN with all earlier
  days' rows intact, the remaining days are not attempted, and the loop
  continues with the next animal (such an animal never enters `acilan`).
  W9's scratch test caught the initial whole-loop-rollback bug (a day-2
  failure also destroyed day-1 rows) and fixed it per-day.
- `acilan[i].manuel = {gun_sayisi, seans_sayisi}`.
- The flat V1.1 array shape is REJECTED → day-validation fail-fast
  ('Geçersiz plan: gün 1..31'); the only caller is this goal's UI, never
  deployed to PROD.
- Everything else unchanged: mutual exclusion, `p_tarih` anchor (past
  blocked), tohumlama branch, cap 200, dedupe, GRANTs, NOTIFY pgrst.

### Scratch-cluster behavioral evidence (PG 18.6, verbatim engines, deleted after)

- Two-day plan anchored +10d start: dates exact (day 1 → +10d, day 2 →
  +11d); planned_times 09:00/14:00/16:00 prove the kalem > gün > default
  precedence end-to-end.
- 12 fail-fast cases, all exact messages with 0 cases created: gun 0 /
  gun 32 / gun 1.5 / duplicate gun; flat V1.1 array; empty kalemler; bad
  day saat; bad kalem saat; bad uuid; mutual exclusion (items + şablon).
- Day-2 engine EXCEPTION → `hatalar[{gun: 2, case_id}]`, day-1 rows
  intact, case still active — partial-days semantics proven live.
- Tohumlama alongside items: eligible Dişi got the görev at +21d 08:00;
  Erkek soft-skipped with the exact string ('Erkek hayvana tohumlama
  görevi açılmaz').

### Demo catalog

`vaka_toplu_ac` pronargs=9; `pg_get_functiondef` body contains the
kalemler handling; migration applied HTTP 201.

### Root E2E (demo, browser) — criterion 11: PASS

Worktree serve, `?demo` auto-login, browser, 2026-09-06:

- Tohumlama block visible-but-disabled (opacity .5, hint 'Hayvan seçince
  aktifleşir') before animals → active after paste (015, 02) — the W10
  discoverability fix verified; no silent uncheck.
- Disease Mastit selected; Gün 1: Enrolen dose 10 + gün saati 10:00.
- `＋ Gün` added Gün 2: Meloksikam dose 10 + per-kalem saat 14:00
  (`bc-isaat-<id>-g<gun>` input).
- `bcGunlardenItems` collected `{gun1: saat 10:00, kalemSaat null},
  {gun2: kalemSaat 14:00}`; dynamic button "💊 Tedaviyi Uygula".
- Submit → "Toplam 2 · Açılan 2 · Atlanan 0 · Hata 0"; rows
  "✅ 015/02 — vaka açıldı + 2 gün · 2 ilaç".
- DB verification (demo): 2 new Mastit cases (distinct from the older
  Klinik Mastit set); treatment_days per animal: day_no 1 →
  2026-09-06 10:00:00, day_no 2 → 2026-09-07 14:00:00 — day anchoring
  (start_date + (n-1)) AND time precedence (kalem.saat > gün.saat)
  proven live.

Acceptance criterion 11 ("V2 E2E: multi-day bulk plan anchors each day
to start_date+(n-1) with per-day/per-kalem times verified in demo"):
`PASS`.

### Tests (V2 delivery)

```text
V1.2 final: 497/497 pass, 0 fail
V2 final:   516/516 pass, 0 fail  (+19, RED→GREEN)
```

RED (26 captured verbatim) and the 3 deliberate adaptations are
documented in the W10 section above ("Tests (V2)") — not duplicated
here.

### Demo rows created by V2 E2E (owner data, not deleted)

2 Mastit cases (015, 02) + 2×2 treatment_days + 2×2
drug_administrations + stok_hareket ledger rows.

### Root test-harness note (not a product issue)

A false-positive 'dialog open' check in root's E2E driver (a closed
modal carries an empty inline `style.display`, which the script misread
as open) auto-clicked a hidden never-opened confirm button — a harmless
no-op: the product took the no-warning direct path. Product logic
verified correct by code read (only the mükerrer/tohumlama warning lines
open the confirm dialog).

### V2 residual notes

1. rpc-reference.md rows for the v4 day-keyed shape + live-schema sync
   remain propose_only, deferred to the post-merge docs commit (§6 item
   3 / V1.2 item 3).
2. Gebelik (pregnancy) eligibility stays server-only (V1.2 note 1
   carried forward).
3. W6 GitNexus probe index + node_modules symlink cleanup at goal close
   (V1.1 notes 2-3 carried forward).

## V2.1 Delivery (2026-09-06, owner brainstorm)

W11 (plan editor v2.1, commit `e7d96fb`) and W12 (banded results/warnings,
commit `b32fb65`) landed the V2.1 amendment after an owner brainstorm:
3 parallel research agents (A1/A2/A3) + an ASCII UI draft + 4 owner
decisions. All V1/V1.1/V1.2/V2 content above stays intact; only the §5
commit/checkpoint lists were extended (17 commits on branch through tip
`b32fb65`, rev-list verified). The goal returns to `review` with
acceptance criteria 12 AND 13 `PASS` (root E2E below; unit suite re-run
by this docs amendment: 557/557 pass, 0 fail).

### Research round (one-liners)

- A1 — structural audit of live bulk-created data (25 cases / 45
  treatment_days / 80 sessions / 4 tohumlama rows): ALL PASS structurally
  (independent audit evidence for the V2 engine contract); findings:
  cross-case open-planlı-tohumlama coexistence is possible (→ owner chose
  the non-blocking warning, W12), empty plan producing no tasks is
  conscious behavior, the TOHUMLAMA card lacks case context (noted,
  not in scope).
- A2 — interaction-language research over the m-sablon builder + seans
  planner (`openSablonBuilder`/`sablonSeansAc`) → fed the ASCII draft and
  the W11 gün-kartı + saat-grup seans design.
- A3 — warning/result presentation research → dashboard alarm-band
  language (`band()`, `.aband*`/`.arow`) and the `m-confirm-desc`
  pre-line precedent → fed the W12 banded-results + combined-warning
  design.

### Owner decisions (4, brainstorm output)

1. Gün girişi = SAYI + TAKVİM ikisi birden (gapped plans valid; calendar
   only offers dates ≥ bc-tarih).
2. Bantlı sonuç düzeni approved (alarm-band language, counts in band
   headers, old summary line removed).
3. Gün kopyalama = BUTON + EKLERKEN-KOPYALA ikisi birden.
4. Tohumlama çakışması = NON-BLOCKING uyarı (per-animal line in the
   combined confirm; server soft-skip semantics unchanged).

### V2.1 commits

- `e7d96fb` feat(ui): plan editörü v2.1 — gün kartları (boşluklu gün
  №+takvim), seans A/B saat-grup dili, gün kopyalama (W11)
- `b32fb65` feat(ui): bantlı sonuç/uyarı düzeni + pre-line satır
  düzeltmesi + tohumlama çakışma uyarısı (W12)

Branch tip at delivery: `b32fb65` — this docs amendment lands on top.
Verified branch count: `git rev-list --count eaa0640..b32fb65` = **17**
commits since launch (18 including this V2.1 docs amendment); sequence
0036fa5 → … → b32fb65. Engine and RPC untouched — the V2 day-keyed
`p_items` contract is consumed as-is (day-level `saat` no longer sent;
every kalem carries `saat = <seans saati>`, already supported by the
kalem-level precedence).

### Tests (V2.1)

```text
V2 final:    516/516 pass, 0 fail
W11 final:   539/539 pass, 0 fail  (+23, RED→GREEN)
W12 final:   557/557 pass, 0 fail  (+18, RED→GREEN)
RED (W11): 37 failures captured verbatim against unmodified sources,
     incl. TypeError for bcGunKopyala / bcTakvimdenGunler / bcGunNoKontrol
RED (W12): 18 failures captured verbatim: TypeError for
     bcSonucBantlari / bcTohumCakismaBul / bcTarihKisa
re-run at V2.1 docs amendment (this commit):
     NODE_PATH=/home/melik/egesut-erp1/node_modules npm run test:unit
     → 557 pass, 0 fail, exit 0 (verified live)
```

### Root E2E (demo, browser) — criteria 12 AND 13: PASS

Worktree serve :8097, `?demo` auto-login, browser, 2026-09-06. Animals
002 + 01, disease Mastit.

Plan editor (criterion 12 surface):

- Gün 1 got Seans A 09:00 (Enrolen 10ml) AND Seans B 20:00 (Enrolen 10ml)
  — the SAME drug twice at different times; session-group language works.
- `+ Gün ▾ → 📅 Takvimden` → picked 10.09 → Gün 5 card created (gapped
  plan), Meloksikam 14:00 added.
- Card footer `📋 Günü Kopyala → № 2 Uygula` → Gün 2 created as a copy
  (toast `📋 Gün 1 → Gün 2 kopyalandı (oluşturuldu)`).
- Tohumlama checked.

Submit → combined confirm dialog OPEN (`m-confirm` class `mo on`) showing
`• 002 — açık planlı tohumlaması var (13.09) — yenisi de açılacak`
(002 already had one open planned insemination; per-animal line) with
`white-space:pre-line` applied (computed style verified, ~4 visual
lines) — criterion 13 warning part PASS.

Onayla → banded result: band `AÇILAN (2)` (green `.aband-hdr`) with
`.arow` rows:

- `✅ 002 — vaka açıldı + 3 gün · 5 ilaç · 🐄 tohumlama 08:00`
- `✅ 01 — vaka açıldı + 3 gün · 5 ilaç · ⏭ tohumlama: Hayvan gebe`

The server-side pregnancy check caught 01 — the client deliberately has
no pregnancy check (layered design demonstrated). Old text summary line
gone; counts live in band headers — criterion 13 banded-results part
PASS.

DB verification (demo, Management API): both animals got day_no 1 →
2026-09-06 with planned 09:00 AND 20:00 (same-day two sessions;
UNIQUE(treatment_day_id, planned_time, stok_id) respected), day_no 2 →
2026-09-07 (09:00 + 20:00, the copy), day_no 3 → 2026-09-10 14:00
(gün 5 → start + (5−1) = 10.09 — the GAP; engine untouched, the sparse
gün contract works end-to-end). New TOHUMLAMA_PLANLI görev ONLY for 002
(hedef 2026-09-06 08:00, kaynak `TEDAVI_SABLON_TOHUMLAMA:<case>:MANUEL`);
01 has none.

Acceptance criterion 12 ("V2.1 E2E: gapped multi-day plan (e.g. gün 1+5)
with two sessions on one day and a day-copy, verified in demo"): `PASS`.
Acceptance criterion 13 ("V2.1 E2E: sonuçlar bantlı bölümlerde + uyarı
diyaloğu satır satır + tohumlama çakışması uyarıda listeleniyor"):
`PASS`.

### Root test-harness notes (V2.1 — not product bugs)

Earlier selector mistakes in root's E2E driver: a `bc-dose` DIV prefix
match, and the `m-confirm` open-class is `on` (not `acik`). Product
guards all behaved correctly — `⚠️ Hastalık seçin` early-return fired
when a stray reset emptied the select, with no partial RPC sent.

### Demo rows created by V2.1 E2E (owner data, not deleted)

2 Mastit cases (küpeler 002, 01) + 3 treatment_days each (plan gün
1/2/5 → day_no 1/2/3, dates 06/07/10.09) + 5 drug_administrations each +
1 TOHUMLAMA_PLANLI görev (002 only).

### V2.1 residual notes

1. A1 open questions not acted on — tohumlama card case-context and
   per-case result grouping recorded as future candidates (owner
   brainstorm backlog), not scope of this goal.
2. rpc-reference.md + ui-map sync remain propose_only, post-merge docs
   commit (§6 item 3 carry-forward).
3. W6 GitNexus probe index + node_modules symlink cleanup at goal close
   (V1.1 notes 2-3 carry-forward).

## V2.2 Amendment (2026-09-06, owner decisions — W15-RPC)

Owner decisions (2026-09-06): (1) şablon kaydı boşluklu günleri KORUSUN
(DENSE_RANK compression removed); (2) tohumlama çakışmasında
'Üzerine yaz' = eski görevi İPTAL et (soft), 'Atla' = yenisi açılmasın.

### TASK A — şablon boşluk koruması: discovery + GT alignment

REPO CONVENTION (verified): deployed functions are changed through NEW
migration files via CREATE OR REPLACE; defining migrations are never
edited in place — `tedavi_sablon_kaydet` chain 20260613000008 (original,
DENSE_RANK) → 20260722000001 (DENSE_RANK removed, gun_no stored AS GIVEN
+ `gun_no ≥ 1` validation) → 20260730000001 (pg_get_functiondef-verbatim
rewrite adding tohumlama_plani normalize). `tedavi_sablon_uygula`
(20260613000009) iterates `SELECT DISTINCT gun_no … ORDER BY gun_no` and
dates at `start_date + (gun_no − 1)` — sparse-safe, needs NO change.

KEY DISCOVERY: the owner's decision (1) is ALREADY the live behavior —
the 2026-07-22 migration removed DENSE_RANK. Only GT was stale (it still
carried the original DENSE_RANK body). NO new migration was written:
a third identical rewrite would contradict the convention and add no
behavior. Demo live probe (read-only pg_get_functiondef, project
vtzqjmazsvurxdeondmi): `dense_rank` position 0 in the live body — body
matches 20260730000001 verbatim.

Changes (this commit):
- GT `tedavi_sablon_kaydet` body replaced with the live
  pg_get_functiondef output (no DENSE_RANK; gun_no as-given; validation
  message 'Şablon gün ofseti 0 veya daha büyük olmalı'); GT
  `tedavi_sablonu` DDL gains `tohumlama_plani jsonb` (body dependency,
  live column since 20260722000002).

Scratch-cluster behavioral evidence (throwaway PostgreSQL, deleted
after; live verbatim engines):

- Gapped şablon {gun 1, gun 5} → kalemler stored `gun_no {1,5}` (NOT
  {1,2}); `tedavi_sablon_uygula` on a case with start_date 2026-09-10
  created treatment days at {2026-09-10, 2026-09-14} = start+0 / start+4.
- Gapless regression {1,2,3} → gun_no {1,2,3}; dates +0,+1,+2 unchanged.
- gun_no 0 → `{ok:false, mesaj:'Şablon gün ofseti 0 veya daha büyük
  olmalı'}` (message verbatim).
- Update path re-save with {1,5,9} → gaps preserved (`gun_no {1,5,9}`).
- GT body ↔ live body diff: identical (modulo statement-terminating `;`).

### TASK B — vaka_toplu_ac p_tohumlama_cakisma (V2.2, in-place migration evolve)

Migration 20260906120000_vaka_toplu_ac.sql evolved IN PLACE (undeployed
to PROD; demo had the 9-arg version — dropped & recreated). New
signature: `vaka_toplu_ac(text[], uuid, jsonb, uuid, text, date,
boolean, int, text, p_tohumlama_cakisma text DEFAULT 'ekle')`; invalid
or NULL mode → fail-fast `{ok:false, mesaj:'Geçersiz çakışma modu'}`
before any case. Conflict scan (mode ≠ 'ekle', per opened case, before
ekle): OPEN (`tamamlandi=false AND iptal=false`) TOHUMLAMA_PLANLI
gorev_log rows of the ANIMAL from any case with
`kaynak LIKE 'TEDAVI_SABLON_TOHUMLAMA:%'`, excluding the just-opened
case's own rows; ordered hedef_tarih ASC. 'ekle' = unchanged; 'atla' =
ekle not called, `{olustu:false, sebep:'Açık planlı tohumlama vardı —
atlandı (eski plan: <DD.MM>)'}`; 'uzerine_yaz' = per old görev soft
cancel (`iptal=true, tamamlandi=true, tamamlanma_tarihi=now(),
kapatan_ref='toplu-vaka-uzerine-yaz'` — close_case_with_remaining 5b +
kapatan_ref convention mirror) + islem_log
`tip='TOHUMLAMA_PLANLI_IPTAL', ref_tablo='gorev_log',
snapshot={'sebep':'toplu vaka üzerine yazma'}` per cancelled görev,
then ekle; `{olustu:true, gorev_id, uzerine_yazildi:['<DD.MM>'…]}`
(oldest first; key omitted when nothing cancelled; ekle failure keeps
today's soft shape). 9-arg positional call stays valid.

Audit-tip precedent check: NO `GOREV_IPTAL` tip exists in migrations
(grep); existing ips GOREV_EKLENDI ×8, GOREV_GUNCELLENDI ×10,
GOREV_TAMAMLA ×13, GOREV_OTOKAPAT ×2 → `TOHUMLAMA_PLANLI_IPTAL` chosen
per task spec.

Scratch-cluster behavioral evidence (PG fresh build per run; verbatim
live engines + verbatim migration; fixtures: closed old cases so the
conflict görevler persist — normal close does NOT cancel
TOHUMLAMA_PLANLI, only close_case_with_remaining does):

- T7 'ekle' regression (9-arg positional call, cross-case conflict):
  `tohumlama = {olustu:true, gorev_id:…}`; new görev created (count 1);
  old open görev untouched (count 1) — today's behavior byte-identical.
- T8 'atla' with conflict: `{olustu:false, sebep:'Açık planlı
  tohumlama vardı — atlandı (eski plan: 01.08)'}`; new görev count 0.
- T9 'uzerine_yaz' with TWO open old görevler (2026-07-15, 2026-08-01):
  `tohumlama = {olustu:true, gorev_id:…, uzerine_yazildi:["15.07",
  "01.08"]}`; both old rows iptal=true + tamamlandi=true +
  kapatan_ref='toplu-vaka-uzerine-yaz'; islem_log TOHUMLAMA_PLANLI_IPTAL
  audit rows = 2 with exact snapshot sebep.
- T10 invalid mode 'sil': `{ok:false, mesaj:'Geçersiz çakışma modu'}`;
  cases opened for that animal = 0 (fail-fast).
- T11a/b clean animals under 'atla'/'uzerine_yaz': behave as 'ekle'
  (`{olustu:true, gorev_id:…}`, no uzerine_yazildi key).
- T12 şablon path + 'uzerine_yaz': the görev the şablon helper created
  moments earlier for the SAME new case is NOT cancelled (current-case
  exclusion); ekle soft-skips with its own guard message 'Bu vakada
  zaten açık bir planlı tohumlama var'; fresh görev remains open.
- GT body equivalence proof: GT's transplanted vaka_toplu_ac body
  extracted and CREATE OR REPLACE'd over the migration-installed
  function on a fresh scratch DB → ALL TASK B tests pass identically.

### TASK C — demo apply + catalog verification (2026-09-06)

Management API apply (project vtzqjmazsvurxdeondmi): migration file
posted byte-exact → `[]` (success). Catalog verify (pg_proc +
pg_get_functiondef):

- `vaka_toplu_ac` catalog rows: EXACTLY ONE —
  `p_animal_ids text[], p_disease_id uuid, p_items jsonb, p_sablon_id
  uuid, p_notes text, p_tarih date, p_tohumlama boolean,
  p_tohumlama_gun_offset integer, p_tohumlama_saat text,
  p_tohumlama_cakisma text` (9-arg GONE).
- `create_case(text,uuid,text)` wrapper + `_vaka_ac_tek(text,uuid,text,date)`
  intact; EXECUTE granted to anon+authenticated.
- `tedavi_sablon_kaydet` live body: `dense_rank` position 0 (absent).
- New body markers present: `p_tohumlama_cakisma` +
  `TOHUMLAMA_PLANLI_IPTAL`.

Demo rows: none created by the apply (DDL only); the çakışma modları
E2E on demo (criterion 15 browser path) remains root's E2E step, the
RPC contract is scratch-proven above. NOT applied to PROD (owner-gated).

## V2.2 Delivery (2026-09-06, superset-10x operasyon planı)

Management model: owner-approved superset-10x operasyon planı — research
round → frozen contracts → parallel workers on two disjoint file-lanes
(W13 calendar fix on js/ui.js ‖ W15-RPC `p_tohumlama_cakisma` on the
migration + GT), then sequential W14 (multi-copy + animal-card link) and
W16 (şablon kaydet + çakışma radyosu) on the shared UI lane; W15-RPC
re-opened the goal (status→active, criteria 14/15 per the amendment
above) and root E2E below verifies both — the goal returns to `review`
with criteria 14 AND 15 `PASS`. Unit suite re-run by this docs amendment:
635/635 pass, 0 fail, exit 0 (verified live). All earlier content stays
intact; only the §5 commit/checkpoint lists were extended (23 commits on
branch through tip `a247bec`, rev-list verified).

### Owner decisions (2, V2.2 — implemented, then E2E-verified here)

1. Şablon boşluk koruması — a şablon's gapped day numbers are PRESERVED
   (no DENSE_RANK compression). Discovery: the live body has behaved
   this way since 20260722000001; only GT was stale (commit `1b62258`
   aligned GT, no new migration — see the V2.2 Amendment TASK A above).
2. Üzerine yaz = soft-cancel — 'uzerine_yaz' YUMUŞAK iptal eder the old
   open TOHUMLAMA_PLANLI görevler (iptal+tamamlandi+kapatan_ref +
   per-görev islem_log audit), never a hard delete; 'atla' opens
   nothing (commit `32f73b9`, 10-arg signature).

### V2.2 commits (5)

- `1b62258` feat(db): tedavi_sablon_kaydet boşluk koruması — DENSE_RANK
  kaldırıldı (+GT)
- `32f73b9` feat(db): vaka_toplu_ac p_tohumlama_cakisma —
  uzerine_yaz=iptal / atla modları (+GT, goal V2.2)
- `57ffd15` fix(ui): takvim ay-geçiş/gün-seçim bug'ı — saf durum
  fonksiyonları + RED-önce testler + TR tarih başlığı (W13)
- `aaa79ca` feat(ui): çoklu hedef gün kopyalama + sonuç satırından
  hayvan kartına geçiş (W14)
- `a247bec` feat(ui): planı şablon olarak kaydet (devam edit) +
  tohumlama çakışma radyosu (üzerine yaz/atla) (W16)

Branch tip at delivery: `a247bec` — this docs amendment lands on top.
Verified branch count: `git rev-list --count eaa0640..a247bec` = **23**
commits since launch; **24** including this V2.2 docs amendment
(post-commit rev-list verified); sequence 0036fa5 → … → a247bec.

### Root E2E (demo, browser) — criteria 14 AND 15: PASS

Test-env lesson first (not a product bug): the first E2E pass on the
long-lived local-serve tab :8097 showed a stale `ui.js` browser-cache
artifact; diagnosed as staleness, then re-run clean on a fresh-origin
serve :8099 (demo mode, 2026-09-06). Cache-busting `?v=` on script tags
noted as a future candidate — out of scope here.

1. Calendar (bug fix, W13): title 'BAŞLANGIÇ: 06.09.2026' (TR format);
   month labels Turkish ('Eylül 2026', 'Ekim 2026'); day beyond bound
   (15 Ekim = start+39) → toast '⚠️ Başlangıçtan itibaren en fazla 31
   gün seçilebilir (son gün: 06.10.2026)' + NOT selected (the REAL bug
   W13 found: no upper bound → gün 35/40 cards silently); 20.09
   selected → chip '20.09' → Ekle → gün 15 derived correctly. 29
   RED-first tests (bcTakvimAyKaydir/AyGosterim/SecimEkle/BaslikTarihi),
   586/586 after W13.
2. Multi-target day copy (W14): source Gün 1 → chips {existing Gün 15 +
   new №3} → single Uygula → günler [1,3,15] all with copied seans;
   toast '📋 Gün 1 → Gün 3, 15 (2 değişti, 0 oluşturuldu)'. Empty day
   deletion also verified.
3. Şablon kaydet (criterion 14, W16): plan gün {1,3,15} saved as
   'E2E Test Kürüsü — boşluklu' → toast '💾 Şablon kaydedildi'; şablon
   appears in the modal's radio list immediately; plan + modal stay
   open (continue-editing). DB: `tedavi_sablonu_kalem` gun_no = {1,3,15}
   EXACTLY (gap round-trip preserved; DENSE_RANK era over).
4. Çakışma radyosu + Üzerine yaz (criterion 15, W16): submit with
   tohumlama → confirm dialog shows the 002 conflict line AND the radio
   group ('Üzerine yaz — eski plan iptal, yenisi planlanır' / 'Atla —
   eski plan kalır, yenisi açılmaz', default 'atla'); chose Üzerine yaz
   → Onayla → result band 'AÇILAN (1)' row: '✅ 002 — vaka açıldı +
   1 gün · 1 ilaç · 🐄 tohumlama 08:00 (üzerine yazıldı: eski 06.09,
   08.09, 13.09, 18.10)'. DB: 002's 4 old open TOHUMLAMA_PLANLI rows
   now iptal=true/tamamlandi=true; 1 new open row (06.09 08:00); 4
   islem_log TOHUMLAMA_PLANLI_IPTAL audit rows.
5. Sonuç satırı → hayvan kartı (W14): row carries `data-hayvan-id` +
   '›' + hint '👆 Hayvana gitmek için satıra dokun'; tap → m-bulk-case
   closes + animal detail opens ('002 · Sağmal Padok · 🚨 7 aktif vaka ·
   ÖZET/SAĞLIK/ÜREME').
6. Tests final: 635/635 (557 → 586 W13 +29 → 605 W14 +19 → 635 W16
   +30; every round RED-verbatim captured).
7. W16 `openConfirm` impact: GitNexus CRITICAL-by-caller-count (12
   direct) but all 11 existing call sites are zero-arg → the default
   path is byte-identical, locked by 3 dedicated tests (root reviewed
   + accepted).

Acceptance criterion 14 ("V2.2: şablon boşluk round-trip — boşluklu
şablon kaydedilir, kalemler gun_no 1 ve 5 olarak saklanır
(SIKIŞTIRILMAZ)…"): `PASS` (scratch-cluster proof in the V2.2 Amendment
TASK A above + demo round-trip here, gun_no {1,3,15} EXACTLY).
Acceptance criterion 15 ("V2.2: tohumlama çakışma modları — 10-parametreli
imza… 'uzerine_yaz' eski açık görevleri YUMUŞAK iptal eder… görev
başına islem_log tip='TOHUMLAMA_PLANLI_IPTAL' denetimi yazar…"):
`PASS` (scratch-cluster T7-T12 above + demo browser path here).

### Demo rows created by V2.2 E2E (owner data, not deleted)

1 Tırnak Yarası case (002, 1 gün / 1 ilaç) + 1 şablon 'E2E Test Kürüsü —
boşluklu' (gun 1,3,15) + 1 new tohumlama görev + 4 cancelled tohumlama
görevler + 4 islem_log TOHUMLAMA_PLANLI_IPTAL audit rows.

### V2.2 residual notes

1. Browser-cache staleness on long-lived local-serve tabs (test-env;
   future cache-busting '?v=' candidate — noted, not scope).
2. rpc-reference.md + ui-map sync remain propose_only, post-merge docs
   commit (§6 item 3 carry-forward).
3. Probe index + node_modules symlink cleanup at goal close (V1.1/V2.1
   carry-forward).
4. A1's open candidates still parked (owner brainstorm backlog).
