---
id: G-20260906-TOPLU-VAKA
status: review
owner: root
flow: zcode_builtin
created: 2026-09-06
base_sha: 434c14236b95a1121339322c548df34c06b9e9e2
launch_sha: eaa0640e65d576c403cbd7aee0fefa66dc81a6f9
branch: idle/toplu-vaka
worktree: /home/melik/egesut-wt/toplu-vaka
write_manifest:
  - .harness/goals/2026/G-20260906-TOPLU-VAKA.md
  - .harness/reports/2026/G-20260906-TOPLU-VAKA.md
  - index.html
  - js/forms.js
  - js/ui.js
  - js/utils/handlers.js
  - js/utils/modal.js
  - js/utils/helpers.js
  - js/api.js
  - supabase/migrations/20260906120000_vaka_toplu_ac.sql
  - supabase/migrations/99999999999999_ground_truth.sql
  - tests/unit/vaka-toplu-ac.test.js
docs_authority:
  tracked_paths:
    write:
      - .harness/goals/2026/G-20260906-TOPLU-VAKA.md
      - .harness/reports/2026/G-20260906-TOPLU-VAKA.md
    append: []
  local_paths:
    write: []
    append: []
  db: write
  propose_only:
    - .claude/**
    - .harness/references/**
pattern_refs:
  - FORM-SUBMIT-01
  - MODAL-ROUTER-01
  - RPC-WRITE-01
  - TESTING-01
acceptance:
  - Red-before unit tests in tests/unit/vaka-toplu-ac.test.js fail against unmodified sources for (a) the IndexedDB mukerrer pre-check warning logic and (b) the kupe chip/paste resolution logic; failure evidence recorded in the report.
  - Full product unit suite green with the exact repo command `npm run test:unit` (script `node --test tests/unit/*.test.js`); exit 0, 0 failures.
  - `vaka_toplu_ac` registered in `RPC_TABLES` (js/api.js) and NOT in the offline-replay `RPC_MAP` (js/ui.js dataTrafficTekGonder).
  - Migration 20260906120000_vaka_toplu_ac.sql applied to the DEMO DB; local worktree serve in demo mode gives a manual E2E pass of the bulk case flow including the sablon path and the duplicate-skip path; evidence recorded in the report.
  - GitNexus impact pre-check run on every touched JS symbol before edits; output referenced in the report, HIGH/CRITICAL findings escalated before proceeding.
  - Read-only live-schema probe recorded in the report verifying create_case guards, tedavi_sablon_uygula engine outputs, and the _tohumlama_gorev_uygunluk / add_drug_administration signatures before RPC reliance.
  - `python3 .harness/bin/harness.py validate --json` reports zero findings for this goal and its linked report.
  - Root reviews the diff; merge and push happen only after owner approval; PROD migration happens only after separate owner approval.
stop_conditions:
  - Live schema materially contradicts ground-truth assumptions before implementation (create_case, tedavi_sablon_uygula, or _tohumlama_gorev_uygunluk drift).
  - The unit test harness cannot express red-first coverage for the new mukerrer pre-check or kupe chip/paste logic.
  - Gate tooling blocks the goal commit irrecoverably.
  - Owner revokes or changes scope.
  - A required write falls outside the exact manifest above.
report: .harness/reports/2026/G-20260906-TOPLU-VAKA.md
checkpoint:
  sequence: 1
  kind: pre-review
  head: 1139798057cf27250fe91c8eb87ca969325d2cbc
  docs_verdict: PASS
---

# Toplu Vaka Aç — Bulk Case Creation (Full goal)

> Rebase note (2026-09-06): the branch was rebased conflict-free from the
> original base 434c142 onto eaa0640 (main advanced mid-task with the
> protokol-dismiss hotfix + reference alignment); `base_sha` is kept as the
> original 434c142 and `launch_sha` records the post-rebase launch point
> eaa0640. Pre-rebase implementation shas (dfc5643/777bc7b/799c912/1b2bfff)
> are superseded by 0036fa5/c45fd72/9a89e15/1139798.

## Objective

Apply the same case/treatment to multiple animals at once, exactly mirroring
the existing single-animal Vaka Aç flow. V1 delivers a router modal
`m-bulk-case` ("🩺 Toplu Vaka Aç") with a dashboard tile next to the existing
"Vaka Aç" tile, multi-küpe selection, a disease/şablon/notlar form copied from
`m-disease`, an ONLINE-ONLY submit through one new write RPC `vaka_toplu_ac`,
an IndexedDB mükerrer pre-check with confirm, and a new migration that
refactors `create_case` into a shared per-animal helper plus the bulk loop.

## Invariants

Modal and form

- Dashboard tile: new sibling of the existing "Vaka Aç" tile
  (`index.html:747` `data-action="open-disease-modal"`) carrying
  `data-action="open-bulk-case"`.
- Form copies `m-disease` (`index.html:1089-1124`); element ids use the
  `bc-` prefix; actions are `open-bulk-case` / `submit-bulk-case` /
  `close-bulk-case`; every close path runs through `closeM` per
  MODAL-ROUTER-01.
- Hastalık select `bc-disease-id` plus category chip replicating
  `onDiseaseSelect` (`js/forms.js:541-552`).
- Şablon radio list reuses `_renderSablonSecim` (`js/forms.js:555-580`)
  container-parametrized; default "Şablonsuz (boş vaka)"; visible only when
  the disease has `sablon_hastalik_eslem` rows. Şablon selection is a USER
  radio choice, never auto-applied.
- `notlar` textarea: one note text applied to all cases in the batch.
- Per-modal reset hook in `openM` (`js/utils/modal.js:40-66` pattern), cf.
  the `m-bulk-ilac` onOpen loaders (`js/ui.js:7152-7154`).

Küpe multi-entry

- Per-entry autocomplete via `acHayvan` (`js/ui.js:7057-7103`) with
  `srchAdaySirala` (`js/utils/helpers.js:182-204`); each pick appends a
  removable chip (`bc-chips`) with a running count.
- A small paste box resolves multi-line / comma-separated küpe lists;
  unresolved entries are listed in red.

Submit and result handling (FORM-SUBMIT-01)

- Submit is ONLINE-ONLY: the same `navigator.onLine` guard as `submitCase`
  (`js/forms.js:583`). One RPC call: `vaka_toplu_ac`.
- `rpc()` throws on failure (a post-call `if (!res.ok)` check is dead code);
  error handling uses the thrown `.data` payload per FORM-SUBMIT-01.
- After success: `pullTables` with the exact `submitCase` set
  (`js/forms.js:621`): cases, diseases, drugs, kizginlik_log, islem_log,
  treatment_days, treatment_day_uygulamalar, drug_administrations, stok,
  stok_hareket, gorev_log; then `renderSafe`.
- In-modal per-animal result list: green/red rows in the `sk-hatalar` pattern.
- Idempotent under double-tap: busy state on the submit button is mandatory.

Mükerrer policy (owner choice)

- UI pre-check through IndexedDB (selected animals × disease ×
  status='active' cases) → `openConfirm` lists the animals that will be
  skipped.
- SERVER GUARD UNCHANGED: the `create_case` invariant stays — same animal +
  disease with an active case → per-animal soft skip, not an error.
- Result shape mirrors `buzagi_sutten_kesme_toplu`:
  `{ok, toplam, basari, atlanan:[{kupe, mesaj}], hatalar}`; hard limit of 200
  animal ids.

Database (RPC-WRITE-01)

- New migration `supabase/migrations/20260906120000_vaka_toplu_ac.sql`:
  1. Refactor the `create_case` body into a private helper
     `_vaka_ac_tek(p_hayvan_id, p_disease_id, p_notes)` — identical behavior,
     including the per-case `islem_log` `VAKA_ACILDI` snapshot consumed by the
     `geri_al` undo. `create_case` becomes a thin wrapper with the same
     signature.
  2. `vaka_toplu_ac(p_animal_ids text[], p_disease_id uuid, p_sablon_id uuid
     DEFAULT NULL, p_notes text DEFAULT NULL) → jsonb`, SECURITY DEFINER,
     GRANT anon + authenticated. Loops the animals: guard-clone (hayvan aktif,
     disease mevcut, aktif-vaka mükerrer → atlanan) → case create → if
     `p_sablon_id`: PERFORM `tedavi_sablon_uygula` +
     `tedavi_sablon_tohumlama_gorev_ekle`, collecting per-animal atlanan
     kalemler/sebep.
- Stock: serbest düşüm (no guard; the engine writes the ledger) per
  domain-rules.md §15.
- farm_id: none — current convention; the `cases` table has no farm_id and
  `vaka_toplu_ac` follows the existing `create_case` convention. The live
  probe confirms this before finalizing.
- Süt yasağı (withdrawal) does not exist in the modern case system — nothing
  to implement.
- `cases.start_date` is server-defaulted CURRENT_DATE; the RPC takes no date
  parameter.

Ground-truth caveats driving the live probe

- `create_case` guards (hayvan durumu Aktif; duplicate active animal+disease
  case → `{ok:false, mesaj}`) are verified facts from ground truth.
- The `tedavi_sablon_uygula` engine creates treatment_days + TEDAVI_GUN
  görev + treatment_day_uygulamalar + drug_administrations + positive
  stok_hareket + TEDAVI_SEANS görev via `add_treatment_day_with_sessions`
  PERFORM.
- `_tohumlama_gorev_uygunluk` is MISSING from ground truth
  (rpc-reference.md:581) → the live-schema probe MUST verify before relying
  on `tedavi_sablon_tohumlama_gorev_ekle`.
- `add_drug_administration` live signature exists only in GT (migration
  drift) → the live probe confirms parity.

JS registration

- Add `vaka_toplu_ac` to `RPC_TABLES` (`js/api.js:319-326`).
- NOT offline-replayable → do NOT extend `RPC_MAP`
  (`js/ui.js` `dataTrafficTekGonder`).

DB authority boundary

- `docs_authority.db: write` is scoped to the isolated DEMO project only
  (applying this migration and E2E data). Any write against PRODUCTION,
  including this migration, requires a separate explicit owner approval.

## Exclusions

- Per-animal disease / individual-dosing matrix panel (owner's future wish,
  10–1000 animals) — the V1 design must NOT block it.
- Padok/filtre selection tabs for bulk case creation.
- Süt yasağı (milk withdrawal) tracking — does not exist in the modern case
  system.
- `bulk_ilac` çifte stok düşümü bug fix (known issue, separate deferred item:
  bulk_ilac decrements `baslangic_miktar` AND writes a positive
  `stok_hareket` while `stok_tuketim_view` counts both).
- No PROD DB mutation, no deploy, no push within this goal without separate
  owner approval.
