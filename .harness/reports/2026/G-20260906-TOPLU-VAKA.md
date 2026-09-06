# Toplu Vaka Aç Implementation Report

Goal: `G-20260906-TOPLU-VAKA`

Date: 2026-09-06

Flow: `zcode_builtin`

Root verdict: `IN_PROGRESS`

> Skeleton opened at goal-open. Every section below is filled by the
> implementer as evidence accumulates; per-criterion verdicts use
> `PASS` / `PARTIAL` / `FAIL` / `INCONCLUSIVE` and stay honest per
> `.harness/acceptance.md`. Workers cannot mark the goal done.

## 1. Launch baseline

```text
launch SHA: 434c14236b95a1121339322c548df34c06b9e9e2
branch: idle/toplu-vaka
worktree: /home/melik/egesut-wt/toplu-vaka
manifest: 11 exact paths (goal, report, index.html, js/forms.js, js/ui.js,
          js/utils/handlers.js, js/utils/modal.js, js/utils/helpers.js,
          js/api.js, supabase/migrations/20260906120000_vaka_toplu_ac.sql,
          tests/unit/vaka-toplu-ac.test.js)
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

Per-criterion status (fill as work proceeds):

| # | Acceptance criterion | Verdict | Evidence |
|---|---|---|---|
| 1 | Red-before unit tests (mükerrer pre-check + küpe chip/paste logic) | `PENDING` | |
| 2 | Unit suite green: `npm run test:unit` | `PENDING` | |
| 3 | `vaka_toplu_ac` in `RPC_TABLES`, NOT in `RPC_MAP` | `PENDING` | |
| 4 | Migration on DEMO DB + demo-mode manual E2E (şablon path, duplicate-skip path) | `PENDING` | |
| 5 | GitNexus impact pre-check on touched JS symbols before edits | `PENDING` | |
| 6 | Read-only live-schema probe recorded (create_case, tedavi_sablon_uygula, _tohumlama_gorev_uygunluk, add_drug_administration) | `PENDING` | |
| 7 | `harness.py validate --json` zero findings | `PENDING` | |
| 8 | Root diff review; merge/push and PROD migration only after owner approval | `PENDING` | |

### 3.1 Red-before evidence

(to record: test file, failing assertion output against unmodified sources,
then passing output after implementation)

### 3.2 Test runs

(to record: exact command, exit code, pass/fail counts)

### 3.3 Live-schema probe

(to record: read-only probe commands and results; external DB effects are
ATTESTED, never VERIFIED, in docs receipts)

### 3.4 DEMO E2E evidence

(to record: migration application on DEMO, serve command, manual flow steps
including şablon path and duplicate-skip path, observations)

## 4. Independent review

(to record reviewer, diff semantics check, pattern conformance, findings and
verdict)

## 5. Checkpoint evidence

```text
pre-commit: staged receipt PASS recorded at goal open (goal-bound)
implementation commits: (to record)
docs checkpoints: (pre-review / handoff / final to record)
residual risks: (to record)
temporary mutations and artifacts restored: (to record)
```

Root acceptance: `IN_PROGRESS` — goal open; nothing delivered yet.
