# Pedigree Revision 2 Review — Round 4

## Review basis and incoming-work gate

The assigned checkout is `idle/pedigree-rev2-review-r4` at
`259df95e2b454d16e9054ced8784d158bb917645`. It is 24 commits behind local
`main` (`809b16ae9125cbd8981f037fdb373be634eadbcc`), and the named review
artifacts are absent from the r4 tree. They are present in the same repository
at `main`; therefore all `spec:`, `plan:`, `r3:`, `evidence:`, and `BUGS:`
references below mean the material at `main@809b16a`. The r4 branch was not
rebased or otherwise changed to obtain them.

Incoming-work gate: **ACCEPT AND START with an environment-boundary note**.
The report-only scope and acceptance shape are measurable. The checkout
boundary is recorded in gate crumb `0f357d9c05e7`. There is no live DB access;
the evidence file is the only live-claim source, and its explicit gaps remain
unverified.

## 1. Round-3 finding resolution

Status is judged from the current artifacts, not from revision banners or
author summaries. `PARTIAL` means a material part is fixed but an acceptance,
authority, or safety gap remains. `UNRESOLVED` means the original defect still
prevents a safe/executable contract.

| ID | Status | Current evidence and residual |
|---|---|---|
| A4 | **PARTIAL** | S4 adds the requested column-type evidence (`evidence:67-85`), S5 adds legacy return types (`evidence:87-98`), and S6 adds a maternal aggregate (`evidence:100-111`). The Task 0.2 signature set still includes `hayvan_ekle`, `dogum_kaydet`, and `geri_al` (`plan:168-177`) but S1 measures only four RPCs; PROD 42804 remains explicitly outside the evidence (`evidence:113-118`), and S6 is not the date-bounded per-animal query specified by Task 0.3 (`plan:246-259`). |
| I3 | **PARTIAL** | S5 proves `jsonb` return types, but the `_semen` equivalence rule still requires the legacy return shape and basic error behavior to be captured (`plan:1027-1035`). S5 contains neither those shapes nor error fixtures. |
| I6 | **PARTIAL** | The filename cutoff is replaced by a DB-stored `pedigree_meta` value (`plan:1165-1170`). The table has no executable DDL/type/key/cast contract, is introduced after the Phase-2 integrity report, and therefore remains a non-reproducible cutoff authority (F11). |
| I7 | **PARTIAL** | The evidence destination and concrete type/maternal probes are named (`plan:178-190`; `evidence:67-111`). The owner ET decision, commit-backed mapping output, complete signature set, and PROD reproduction remain absent/open (`plan:239-265`; `evidence:113-120`). |
| C3 | **RESOLVED** | External evaluations are now explicitly v2 on the animal and semen surfaces (`spec:898-914`), in the rollout boundary (`spec:1198-1202,1244-1248`), and in the v1 DoD (`plan:1844-1850`). |
| C4 | **RESOLVED** | The summary, detailed layout rule, phase acceptance, and final diagram now agree on focal `breadthfirst` and lazy ELK only for mating (`spec:52,850-858,1213-1221,1440-1446`; `plan:747-764,797-798`). The conditional focal fallback is an explicit measurement gate, not the former generic ELK assignment. |
| C6 | **PARTIAL** | `BUGS.md` calls DOC-001..006 met while simultaneously recording DOC-006 as a partial tracked-tool debt (`BUGS:97-103,129-134`). The status is still internally mixed rather than a single acceptance state. |
| G3 | **PARTIAL** | Parentage now has paired farm/node columns and composite FKs, and semen has a `bull_farm_id` pair (`spec:226-255,275-294`; `plan:331-359`). The semen row is not constrained to `farm_id = bull_farm_id`, while the evaluation schema remains a single-column FK and the plan only comments an undeclared `node_farm_id` (`spec:336-352`; `plan:1526-1546`). See F14-F15. |
| N4 | **PARTIAL** | Farm-prefixed keys, a client source, and an auth hook are now named (`plan:686-694`). The source is only a one-farm constant, no concrete farm-context event is defined, and the referenced cache-clear API/order is not executable in the current browser-global surface (F17-F18). |
| N10 | **RESOLVED** | P2/P4 layout scope is explicit in the task and final map (`plan:736-764,1795-1800`), with the former general ELK references corrected in the spec (C4). |
| N12 | **RESOLVED** | The stub handler/call-counter requirement and the required `tests/support/stub-backend.js` path now both appear in the plan (`plan:1617-1622,1791-1793`). |
| N15 | **RESOLVED** | `evaluation_date` is `NOT NULL` in both the canonical schema and the v2 table minimum (`spec:335-353`; `plan:1526-1546`), so the original nullable unique-key defect is removed. |
| N17 | **PARTIAL** | A previous canonical ID column and a required `islem_log` snapshot key are added (`spec:304-311`; `plan:1021-1025`). This is still a one-slot/one-step history, with no exact per-attempt canonical record or snapshot contract; the plan explicitly defers full attempt history to v2. |
| I4 | **RESOLVED** | The foundation grant block no longer uses `...` or the wrong parent-set arity; the listed signatures are concrete (`plan:385-401`). Later missing grants are separate fresh findings, not the original invalid foundation grant. |
| N1 | **RESOLVED** | Foundation grants now use the six-, seven-, and ten-argument type lists matching the foundation helper contracts (`plan:385-389,414-438`). |
| N3 | **PARTIAL** | The missing semen composite pair was added (`spec:275-294`; `plan:355-361`), but the catalog's own `farm_id` is not tied to `bull_farm_id`, and the evaluation relation remains inconsistent. A cross-farm catalog/evaluation relationship is still representable (F14-F15). |
| F1 | **PARTIAL** | The new UI rule removes non-empty manual free text and allows controlled selection or NULL (`plan:1085-1089,1157-1163`). The same plan later says every tohumlama/tekrar/gebelik record carries `semen_id` and tests that no frontend NULL path remains (`plan:1165-1177`), contradicting the intentional NULL manual-pregnancy path (F16). |
| F2 | **PARTIAL** | The edge `evidence` column and birth-call payload were added (`spec:233-242`; `plan:1193-1210`). The canonical `pedigree_parent_set` signature has no evidence parameter (`plan:417-423`) and its grant remains six-argument (`plan:386`), so the new provenance cannot be written through the stated mutation path (F10). |
| F3 | **RESOLVED for the stated one-farm v1 scope** | The cache key now has an explicit `PEDIGREE_FARM_ID` source and the plan records the future multi-farm transition (`plan:686-692`; `spec:983-988`). Cross-environment/session cache separation is not part of this original one-farm finding; the logout implementation gap remains F17-F18. |
| F4 | **PARTIAL** | `js/auth.js` is now named in the final map and the intended call is stated (`plan:692-694,1791`). The current auth flow has no such call and reloads both after `signOut` and on `SIGNED_OUT` (`js/auth.js:239-265`); the current API has no `api.clearPedigreeCache` namespace/function (`js/api.js:94-133`). See F17-F18. |
| F5 | **RESOLVED** | The required stub file is now in the final change map, alongside the handler and call-counter acceptance (`plan:1617-1622,1793`). |
| F6 | **PARTIAL** | The DB value replaces the filename authority (`plan:1165-1170`), but its DDL, uniqueness, value type, insertion semantics, and Phase-2 ordering are absent; live timestamp proof is also not in the evidence. See F11. |
| F7 | **PARTIAL** | A recurrence and named fixture set were added (`plan:1320-1373`). Missing-parent semantics still treat an unknown branch as a founder while counting its completeness slot as known, and the inbred-ancestor case has no numeric expected value; these leave deterministic accuracy/acceptance gaps (F19). |
| F8 | **RESOLVED** | The `node_kind`/`farm_animal_id` conditional CHECK is now in the spec DDL and the plan's foundation requirements (`spec:196-206`; `plan:318-329`). |
| F9 | **PARTIAL** | The v2 read RPC now names a response shape, ordering, and same-farm empty-list behavior (`plan:1552-1559`). Its table contract still conflicts with the spec's single FK and does not declare the plan's `node_farm_id` column (`spec:336-353`; `plan:1526-1546`), so the tenant proof is not complete (F15). |

## 2. Fresh hunt

The following are additional document/repository defects found after checking
the r3 repairs. They are static findings unless marked as an unverified live
boundary; no live DB behavior is inferred.

### Accuracy

**F10 — [dead-path] VERIFIED — Birth provenance cannot reach the new `evidence` column.**

The architecture adds `pedigree_parentage.evidence` for
`tohumlama_id`/`semen_id` provenance (`spec:233-242`), and Task 12 calls
`pedigree_parent_set(..., evidence={...})` (`plan:1207-1208`). However, the
canonical helper has only `p_child_node_id, p_role, p_parent_node_id,
p_source_type, p_source_ref, p_replace` (`plan:417-423`), and the foundation
grant names those six types (`plan:386`). A literal call cannot bind the
extra argument; no direct evidence write is specified. The claimed
rebuild/audit provenance therefore disappears or requires an undeclared API
change.

**F14 — [scope-violation] VERIFIED — The semen composite FK does not bind the catalog row to its own farm.**

`semen_catalog` has `farm_id`, `bull_farm_id`, and a composite FK from the
latter pair to `pedigree_nodes(farm_id,id)` (`spec:275-294`; `plan:355-361`),
but neither artifact adds `CHECK (farm_id = bull_farm_id)`. A row with
`farm_id = A`, `bull_farm_id = B`, and `bull_node_id = node_B` satisfies the
shown FK while linking an A catalog entry to B's bull. The prose says the
relation is same-farm (`plan:441-444`), but the stated DDL does not enforce
that invariant for future writers or migration mistakes.

**F19 — [unmeasured-claim] VERIFIED static contract defect — Unknown ancestry is counted as known completeness.**

The new algorithm says an unknown parent behaves like a founder and that its
completeness slot is counted as known (`plan:1324-1335`). The profile contract
reports `known_slots`/`ratio` (`spec:684-706`), while the surrounding model
requires unknown ancestry to remain visible rather than silently becoming a
known founder (`spec:712-739`; `plan:1451-1458`). A missing parent can thus
inflate completeness and produce a founder-like contribution without an
identity. The fixture list has no expected missing-parent result, so this
wrong-but-green outcome is not pinned down.

**F22 — [unmeasured-claim] VERIFIED — The profile response has no representation for unknown founder mass.**

The plan requires unknown ancestry to remain separate and requires
`known + unknown ≈ 1` (`plan:1451-1458`), and the DoD requires founder totals
and the unknown share to be shown (`plan:1844-1848`). The v1
`pedigree_profile` JSON, however, defines `founder_contributions` only as
`founder_node_id`, `label`, and `contribution`, with no `unknown_share` or
null-founder contract (`spec:684-706`). Implementations can omit, normalize,
or invent an unknown founder while still matching the shown JSON shape.

### Implementability

**F11 — [race-lifecycle] VERIFIED — Phase-2 integrity reporting depends on a Phase-6 table.**

Task 2 creates the `pedigree_integrity_report()` migration and requires it to
report post-cutoff rows using `pedigree_meta` (`plan:500-554`). The only
creation instruction for `pedigree_meta` is in Task 10's
`20260910000005_semen_controlled_writes.sql` (`plan:985-996,1165-1170`), after
the Phase-2 migration in the stated order (`plan:1721-1726`). Phase-2
acceptance can therefore call the report before the table exists; the call
has no cutoff source and can fail on the missing relation. The new cutoff
fix is not executable in the planned phase order.

**F12 — [dead-path] VERIFIED — The four semen-aware write RPCs have no EXECUTE grant.**

Task 10 defines `tohumlama_kaydet_semen`,
`planli_tohumlama_kaydet_semen`, `tohumlama_tekrar_kaydet_semen`, and
`gebelik_kaydet_manual_semen` (`plan:998-1019`). The complete grant inventory
lists foundation, projection, profile/mating, and v2 evaluation functions but
none of these four (`plan:391-401`). The same plan says a missing grant blocks
the client under the tracked auth-lockdown (`plan:363-369`;
`supabase/migrations/99999999999999_ground_truth.sql:11098-11112`). The
controlled-write browser path is consequently dead unless an undeclared grant
block is added.

**F13 — [dead-path] VERIFIED — Two foundation helper signatures are not legal PostgreSQL input-parameter lists.**

`pedigree_external_upsert` puts `p_node_id uuid default null` before required
`p_display_name text`, and `semen_catalog_upsert` puts `p_id uuid default null`
before required `p_display_name text` (`plan:424-438`). PostgreSQL requires
subsequent input parameters to have defaults after the first defaulted input
parameter. A literal foundation definition fails; reordering the parameters
or adding a default changes an executor-facing contract that the plan does
not choose, while the grant list fixes the original type order (`plan:386-388`).

**F17 — [dead-path] VERIFIED — The logout repair names an undefined API surface.**

The r3 repair says `js/auth.js` will call `api.clearPedigreeCache()`
(`plan:686-694,1791`), but the current buildless API exposes top-level
functions and `_idb` rather than an `api` object; the shown section contains
no `clearPedigreeCache` function or namespace (`js/api.js:94-133`). The current
logout code likewise has no call (`js/auth.js:239-244`). A worker following
the plan literally gets a `ReferenceError` or must invent an unlisted export
contract, so F4 is only partial.

**F20 — [dead-path] VERIFIED — Kinship primitive APIs have no creation or grant path.**

Task 15 declares `pedigree_kinship(node_a,node_b,depth)` and
`pedigree_inbreeding(node,depth)` as the API split for the algorithm
(`plan:1320-1345`). The migration task that follows only explicitly creates
`mating_analyze` and `pedigree_profile` (`plan:1388-1414`); the migration
sequence has no separate kinship/inbreeding migration (`plan:1718-1732`), and
neither function appears in the grant inventory (`plan:391-401`). The known
coefficient DoD cannot be reached through the declared API surface.

**F21 — [dead-path] VERIFIED — `pedigree_integrity_report()` has no client EXECUTE grant.**

Task 2 creates the report (`plan:540-554`) and Task 4 exposes an
`integrityReport()` client wrapper (`plan:698-704`), but the subsequent grant
block omits `pedigree_integrity_report` (`plan:391-401`). Because the plan
explicitly relies on per-object grants after auth lockdown (`plan:363-369`),
the integrity read used by Phase 2 cannot be called by the browser.

### Contradiction and lifecycle gaps

**F15 — [doc-drift] VERIFIED — The v2 evaluation composite FK names a column the plan does not define, while the spec keeps a single FK.**

The architecture DDL has only `node_id uuid REFERENCES pedigree_nodes(id)`
(`spec:335-353`). The plan's table minimum says the relationship is
`(node_farm_id,node_id)` but lists no `node_farm_id` column and gives no
choice to reuse `farm_id` (`plan:1526-1546`). The read RPC's same-farm guard
(`plan:1552-1559`) does not repair this schema contradiction. An executor
cannot produce one unambiguous tenant-enforced table from these authorities,
so F9/G3 remain partial.

**F16 — [doc-drift] VERIFIED — Manual pregnancy is simultaneously allowed to use NULL and required to be non-NULL.**

The `_semen` contract explicitly permits `p_semen_id DEFAULT NULL` for manual
pregnancy (`plan:1016-1018`), and Task 11 repeats that `geb-sperma` selection
is optional (`plan:1157-1163`). The same Phase-6 acceptance says every
tohumlama/tekrar/gebelik record carries `semen_id` and tests that no frontend
NULL path remains (`plan:1165-1177`). A valid unknown-sire manual pregnancy
cannot satisfy both criteria; the gate must distinguish the two forms or the
NULL behavior must be removed.

**F18 — [race-lifecycle] VERIFIED static lifecycle risk — SIGNED_OUT reload can preempt cache invalidation.**

The current logout flow awaits `db.auth.signOut()` and then reloads
(`js/auth.js:239-244`), while the auth-state listener independently reloads as
soon as it sees `SIGNED_OUT` (`js/auth.js:262-265`). The plan does not require
cache clearing before `signOut`, await it before either reload, or remove the
listener reload (`plan:686-694`). If the new clear hook is placed after the
await as a literal “exit hook”, the event-driven reload can happen first and
leave stale `pedigree_cache` data for the next session.

## 3. VERDICT: FAIL

The documents are **not ready to serve as implementation authority**.

Blocking reasons are:

- foundation/helper execution is not stable: provenance is called with an
  undeclared argument (F10), two helper signatures are invalid as written
  (F13), and all four controlled-write RPCs lack grants (F12);
- the Phase-2 integrity gate depends on an unspecified table created only in
  Phase 6 and its read RPC has no grant (F11, F21);
- farm isolation remains structurally incomplete for semen and evaluations
  (N3/G3, F14-F15), despite the new prose and read guard;
- the manual-pregnancy acceptance is contradictory (F16), and the newly
  specified algorithm can overstate completeness/unknown founder data
  (F19, F22);
- the proposed logout invalidation has neither a defined API surface nor a
  safe ordering against the existing reload path (F17-F18);
- live preflight/owner gates remain incomplete (A4, I3, I7), so the live
  signatures, PROD error, ET decision, mapping, and deployment state cannot
  be promoted from the evidence file to implementation authority.

## 4. Confidence and unverified boundaries

Confidence is high for the static document/repository findings: the current
spec, plan, r3 report, evidence file, BUGS.md, tracked auth/API source, grant
inventory, migration order, and exact `main@809b16a` relationship were checked
locally. Confidence is limited for runtime behavior because this seat has no
live DB access. The evidence artifact contains S1-S6, but still does not prove
the PROD 42804 reproduction, the complete live signature/error inventory, ET
history/owner decision, commit-backed identity mapping, or post-deploy
privileges. Those boundaries remain **UNVERIFIABLE FROM THIS REVIEW SEAT**.

Only this report is written to the r4 branch; no product or migration file was
changed.
