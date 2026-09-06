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
  - Manual drug path E2E: bulk case + day-1 drug_administrations per animal verified in demo.
  - V1.2 E2E: future-dated bulk case (şablon or manuel) anchors days+tohumlama to planned date; male/young animals' tohumlama skipped with exact reasons in demo.
  - V2 E2E: multi-day bulk plan anchors each day to start_date+(n-1) with per-day/per-kalem times verified in demo.
  - V2.1 E2E: gapped multi-day plan (e.g. gün 1+5) with two sessions on one day and a day-copy, verified in demo.
  - V2.1 E2E: sonuçlar bantlı bölümlerde + uyarı diyaloğu satır satır + tohumlama çakışması uyarıda listeleniyor (demo).
  - Root reviews the diff; merge and push happen only after owner approval; PROD migration happens only after separate owner approval.
stop_conditions:
  - Live schema materially contradicts ground-truth assumptions before implementation (create_case, tedavi_sablon_uygula, or _tohumlama_gorev_uygunluk drift).
  - The unit test harness cannot express red-first coverage for the new mukerrer pre-check or kupe chip/paste logic.
  - Gate tooling blocks the goal commit irrecoverably.
  - Owner revokes or changes scope.
  - A required write falls outside the exact manifest above.
report: .harness/reports/2026/G-20260906-TOPLU-VAKA.md
checkpoint:
  sequence: 5
  kind: pre-review
  head: b32fb6541fe407080b13e01149dc5757a642d478
  docs_verdict: PASS
---

# Toplu Vaka Aç — Bulk Case Creation (Full goal)

> Rebase note (2026-09-06): the branch was rebased conflict-free from the
> original base 434c142 onto eaa0640 (main advanced mid-task with the
> protokol-dismiss hotfix + reference alignment); `base_sha` is kept as the
> original 434c142 and `launch_sha` records the post-rebase launch point
> eaa0640. Pre-rebase implementation shas (dfc5643/777bc7b/799c912/1b2bfff)
> are superseded by 0036fa5/c45fd72/9a89e15/1139798.

**V1.1 amendment (2026-09-06, owner feedback):** the bulk modal must APPLY a
manually-entered treatment, not just open cases. The manual drug list layer
(`p_items jsonb`) is the primary treatment path: for each animal the day-1
treatment (treatment_days + treatment_day_uygulamalar + drug_administrations
+ stok_hareket + TEDAVI_GUN/TEDAVI_SEANS görevleri) is created immediately
after case creation through the existing `add_treatment_day_with_sessions`
engine (bug059, migration 20260611000002) — the same engine the şablon path
already feeds. The şablon path is retained unchanged; `p_items` and
`p_sablon_id` are mutually exclusive (enforced in the RPC and mirrored by
the UI). Engine compatibility: the engine reads the exact keys
`drug_product_id/stok_id/dose/unit/route` and REQUIRES a non-NULL
`planned_time` (`treatment_day_uygulamalar.planned_time` is `time NOT NULL`
per migration 20260611000001; `gorev_log.hedef_saat` is nullable but the
uygulamalar INSERT fails first), so `vaka_toplu_ac` validates and normalizes
`p_items` before any case is created — items missing `planned_time` are
coerced to `'09:00'`; violations return
`{ok:false, mesaj:'Geçersiz ilaç kalemi: <index>: <sebep>'}` fail-fast.
New signature:
`vaka_toplu_ac(p_animal_ids text[], p_disease_id uuid, p_items jsonb DEFAULT NULL, p_sablon_id uuid DEFAULT NULL, p_notes text DEFAULT NULL)`
(the old 4-arg body is DROPped first to avoid an overload). Per-animal engine
results are captured as `acilan[i].manuel = {day_no, seans_sayisi}` and the
top-level result gains `'manuel' boolean`.

**V1.2 amendment (2026-09-06, owner feedback):** date planning + planlı
tohumlama. ROOT DECISION: `p_tarih date` is the planned START date and is
WRITTEN to `cases.start_date` — the first-ever non-default start_date write in
the modern case system; everything anchors to it coherently (şablon günleri
`start_date+(n-1)` automatic via `tedavi_sablon_uygula` which reads
`v_case.start_date`; manuel gün-1 at `p_tarih`; tohumlama hedefi
`start_date+offset`). NULL → CURRENT_DATE (today's behavior unchanged);
`p_tarih < CURRENT_DATE` → `{ok:false, mesaj:'Geçmiş tarih planlanamaz'}`
fail-fast before any case. `_vaka_ac_tek` gains `p_tarih date DEFAULT NULL`
(last param) and the INSERT sets `start_date = COALESCE(p_tarih,
CURRENT_DATE)` explicitly; the `create_case` wrapper signature is UNCHANGED
(passes NULL → single-animal flow still defaults to today). The manual engine
call becomes `add_treatment_day_with_sessions(case, COALESCE(p_tarih,
CURRENT_DATE), items, NULL)`. Tohumlama option: when `p_tohumlama` is true,
EVERY successfully opened case (after şablon/manuel) reuses the EXISTING
`public.vaka_tohumlama_ekle(case, start_date + p_tohumlama_gun_offset,
COALESCE(p_tohumlama_saat,'08:00')::time)` — per-case SOFT skip, never
counted in `hatalar`: `ok:true → acilan[i].tohumlama = {olustu:true,
gorev_id}`; `ok:false → {olustu:false, sebep:<server mesaj>}` with the exact
eligibility reasons ('Erkek hayvana tohumlama görevi açılmaz', 'Hayvan hedef
tarihte 12 aydan küçük', 'Hayvan gebe') plus 'Bu vakada zaten açık bir planlı
tohumlama var' when the şablon path already opened one; RPC absent
(GT-drift, probed live via pg_proc guard like the şablon tohumlama helper) →
`{olustu:false, sebep:'Tohumlama RPC yok'}`; EXCEPTION → same soft shape,
case stays open. Bounds (fail-fast): `p_tohumlama_gun_offset` integer 0..365
else `{ok:false, mesaj:'Tohumlama gün ofseti 0-365 aralığında olmalı'}`;
`p_tohumlama_saat` NULL → '08:00', else must match `^([01][0-9]|2[0-3]):[0-5][0-9]$`
else `{ok:false, mesaj:'Geçersiz saat'}`. New signature (old 5-arg body
DROPped first):
`vaka_toplu_ac(p_animal_ids text[], p_disease_id uuid, p_items jsonb DEFAULT NULL, p_sablon_id uuid DEFAULT NULL, p_notes text DEFAULT NULL, p_tarih date DEFAULT NULL, p_tohumlama boolean DEFAULT false, p_tohumlama_gun_offset int DEFAULT 0, p_tohumlama_saat text DEFAULT NULL)`.
`acilan[i]` gains `'tarih'` (the case's actual start_date ISO); the top-level
result gains `'tohumlama' boolean`. All V1/V1.1 behavior retained.

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

## V2 Direction (owner clarification, 2026-09-06)

Owner tested V1.2 and clarified the long-term design intent: the reference UI
for "tedavi planı" is the multi-day plan-editor language of the şablon
builder (modal `m-sablon`; `openSablonBuilder` / `sablonSeansAc`,
js/ui.js) — gün-gün ilaç kalemleri + seans saatleri + tohumlama ofseti
(`tohumlama_plani.gun_ofset`) — not a single anchor date. V1-V1.2
deliberately shipped: single-date anchor + day-1 manual drugs OR pre-built
şablon + tohumlama offset option.

V2 (owner: "üzerine eklenmeye devam edilebilir"): embed the ad-hoc multi-day
plan editor into the bulk modal — generalize `p_items` to a day-keyed
structure `[{gun_no, planned_time?, kalemler:[...]}]` and loop
`add_treatment_day_with_sessions` per day server-side (the engine already
supports per-day invocation; the şablon path already chains days from
`start_date`). Nothing in V1-V1.2 needs rework:
şablon/manuel/tohumlama/date layers all compose.

Constraint carried forward: past dates stay blocked; per-day saat must
satisfy the engine's `planned_time NOT NULL` (default `'09:00'` convention
or per-kalem saat input like the şablon builder).

**V2 implementation (2026-09-06, owner: devam):** the RPC half of the V2
direction is now implemented in this goal (status review → active). The
`vaka_toplu_ac` signature is UNCHANGED (9 params); only the `p_items` SHAPE
evolves to a day-keyed array
`[{"gun": <int 1..31>, "saat"?: "<HH:MM>", "kalemler": [...]}]` where each
kalem keeps the V1.1 keys plus an optional per-kalem `saat`. Saat precedence
per kalem is `COALESCE(kalem.saat, gün.saat, '09:00')`; days sort by `gun`
ASC and each day executes through `add_treatment_day_with_sessions` anchored
at `start_date + (gun - 1)`. PARTIAL-DAYS-ON-ERROR semantics: an engine
`ok:false` or EXCEPTION on any day pushes the per-animal error into
`hatalar` WITH `case_id` + `gun`, the case STAYS OPEN with all earlier
days' rows remaining, the remaining days are not attempted, and the loop
continues with the next animal (such an animal never enters `acilan`).
`acilan[i].manuel` becomes `{gun_sayisi, seans_sayisi}`. The flat V1.1
array shape is no longer accepted and fails day validation fail-fast
(`'Geçersiz plan: gün 1..31'`; the only caller is this goal's UI, never
deployed to PROD). Everything else unchanged: mutual exclusion, `p_tarih`
anchor (past blocked), tohumlama branch, cap 200, dedupe, atlanan/hatalar,
şablon pg_proc guard, NOTIFY pgrst, GRANTs. UI half: parallel worker W10.

**V2.1 amendment (owner brainstorm 2026-09-06):** the bulk plan editor
(W10's sequential day-tabs + day-saat + flat per-day drug list) is REBUILT
into the m-sablon builder + seans planner language — UI only, engine and
RPC untouched (V2 `p_items` day-keyed contract is consumed as-is; day-level
`saat` is simply no longer sent and each kalem ALWAYS carries
`saat = <seans saati>`, which the existing kalem-level precedence already
supports — zero migration in V2.1). Owner-approved design (three "İKİSİ
BİRDEN" decisions):
1. Gün girişi = SAYI inputu + TAKVİM ikisi birden: each day card carries a
   "Başlangıçtan gün" number input (1..31, user-chosen — GAPPED plans like
   gün 1+5 are valid; unique-check toast 'Aynı gün zaten var; seansları o
   günün altında toplayın' + revert; ASC re-sort; delete PRESERVES other
   day numbers) plus a `[+ Gün ▾]` menu with `📅 Takvimden` (bc-gun-takvim,
   a variant of the case-detail gun-tarih-modal: only dates ≥ bc-tarih
   selectable → 'Başlangıçtan tarihinden önceki gün seçilemez'; existing
   day dates pre-highlighted; Onayla adds days with the seans form open).
   Card headers show the computed date `Gün N · <DD Ay>` (bc-tarih + N−1),
   re-rendered on any gün/tarih change.
2. Seans = SAAT-GRUP dili: per day, MULTIPLE sessions each with its own
   saat ('⏰ Seans · SS:DD'); the inline `＋ Bu güne seans ekle` form
   (collapsed by default) copies sablonSeansAc/caseSeansEkleFormAc: saat
   input (default 09:00) + HIZLI_SAATLER chips + grouped drug checkbox
   list (stock coloring) + dose rows + [Seansı Ekle]; validates saat and
   doz/birim per checked drug, appends the session, resets saat, STAYS
   OPEN (the exact 'seans A + seans B' interaction; same drug in multiple
   sessions is allowed). Old day-level `bc-gun-saat` input REMOVED.
3. Gün kopyalama = BUTON + EKLERKEN-KOPYALA ikisi birden: card footer
   `📋 Günü Kopyala → Gün № [<input>] [Uygula]` (creates the target day if
   missing, REPLACES its sessions otherwise; toast 'Gün N → Gün M
   kopyalandı (oluşturuldu / değiştirildi)') AND `[+ Gün ▾] → 📋 Önceki
   günden` (new next day seeded from the open/last day). Pure core:
   bcGunKopyala. State: `window._bcGunler = [{gun, seanslar: [{saat,
   ilaclar: {drugId: {name, dose, unit, route, legacy, stock_id}}}]}]`,
   `window._bcAktifGunCard` (collapse), `_bcSeansFormGun` (open form);
   validation in bcGunlardenItems v2: per-session saat regex, kalem errors
   prefixed 'Gün N (<saat>): ', zero-session day (>1st, when any kalem
   exists) → 'Gün N: en az bir seans ekleyin ya da günü silin', ALL days
   empty → items:[] (drug-free case unchanged); submitBulkCase flow and
   the 'N gün · M ilaç' result text unchanged; şablon↔kalem mutual
   exclusion now snaps/clears across ALL days' sessions. W10 unit tests
   adapted deliberately (documented in tests/unit/vaka-toplu-ac.test.js
   header: seans-state toplama, gün № koruma, buton etiketi).

**V2.1 result/warning amendment (2026-09-06, owner-approved — W12):**
1. Bantlı sonuç düzeni: the bc-sonuc in-modal result list is REBUILT in
   the dashboard alarm-band language (`band()` js/ui.js + `.aband` /
   `.aband-hdr.green|.amber|.red` / `.aband-body` / `.arow` markup) via
   the pure `bcSonucBantlari(satirlar, opts)` on top of the UNCHANGED
   `bcSonucSatirlari` — bands 'Açılan (N)' green → 'Atlanan (N)' amber →
   'Hata (N)' red in fixed order, empty group → no band, counts live in
   band headers, the old single-line 'Toplam X · Açılan Y · …' summary is
   REMOVED, ok-row suffixes (manuel/şablon/tohumlama eki) preserved
   verbatim, each band body gets a max-height:220px scroll box, success
   toast unchanged.
2. `m-confirm-desc` gains `white-space:pre-line` — joined('\n') warning
   lists render line-by-line (also improves planlı aşı tekrarı + görev
   düzenleme diff); CSS only, no behavior change.
3. Tohumlama çakışma uyarısı (UI-only, NON-BLOCKING): pure
   `bcTohumCakismaBul(hayvanlar, gorevler)` finds selected animals with an
   OPEN gorev_log row (tamamlandi falsy, iptal falsy,
   gorev_tipi='TOHUMLAMA_PLANLI' case-insensitive per the A1 audit
   finding), surfaced in the combined openConfirm warning list as
   '• <kupe> — açık planlı tohumlaması var (<DD.AA>) — yenisi de
   açılacak' when tohumlama is requested; confirm proceeds, server
   per-case soft-skip semantics unchanged.
4. sk-hatalar color fix: `var(--err)` (undefined variable, 0 index.html
   hits) → `var(--red)` in submitSuttenKes error list.
