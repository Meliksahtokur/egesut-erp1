# Pedigree Revision 2 Review — Round 5

## Review basis and incoming-work gate

This review was run on `idle/pedigree-rev2-review-r5` at
`ffd6768c70ed1cc14974b4295de831abcfdf6825`, after `git merge --ff-only main`.
The named spec, plan, r1-r4 reports, S1-S8 evidence, `BUGS.md`, active goal,
tracked migrations, `js/`, `tests/`, and `demo/` material were present at that
HEAD. The report-only write boundary was preserved.

Incoming-work gate: **ACCEPT AND START**. The task is executable as a static
document/repository review and its report path is measurable. The checkout
boundary and material availability were verified after the fast-forward. There
is no live DB access in this seat; the evidence file is the only source for
live claims. The plan's ET decision, mapping, PROD 42804 reproduction, and
legacy return/error capture are treated as open preflight inputs because the
plan explicitly binds them to phase gates (`plan:272-277`), not as silently
closed facts. Gate crumb: `41a89bf428a9`.

For compactness below: `spec` means
`.claude/specs/2026-09-10-pedigree-genetics-architecture.md`, `plan` means
`.claude/plans/2026-09-10-pedigree-genetics-impl.md`, and `evidence` means
`.claude/reviews/2026-09-10-live-probe-evidence.md`.

## 1. Round-4 finding resolution

Statuses are judged from the current artifacts, not from revision banners or
author summaries. `RESOLVED (gated)` means the missing live input is now an
explicit prerequisite that blocks the affected phase; it is not a claim that
this seat re-measured live state. `PARTIAL` means the original mechanism is
improved but an acceptance, authority, or safety residual remains.

| ID | Status | Current evidence and residual |
|---|---|---|
| A4 | **RESOLVED (gated)** | S1/S7 jointly cover the seven Task 0.2 signatures (`evidence:21-27,113-121`), while S4/S5 provide the measured column and return types (`evidence:79-98`). The remaining PROD 42804 reproduction is explicitly an open preflight input with a phase stop (`plan:272-277`). |
| I3 | **RESOLVED (gated)** | S5 confirms the legacy return type is `jsonb` (`evidence:87-98`); the plan requires each legacy shape and basic error behavior to be captured before `_semen` equivalence work and blocks the relevant phase until then (`plan:1070-1078,272-277`). |
| I6 | **PARTIAL** | `pedigree_meta` is now created in Phase 2 with a keyed row and is populated by the controlled-write phase (`plan:562-580,1208-1213`), fixing the filename/order defect. Its cutoff value remains generic `text`, with no explicit cast, validation, or malformed-value behavior. |
| I7 | **RESOLVED (gated)** | S7/S8 attach the remaining named signature and maternal measurements (`evidence:113-150`). ET owner decision, mapping, PROD reproduction, and return/error capture are explicitly preflight inputs whose absence prevents the relevant phase envelope (`plan:239-277`). |
| C3 | **RESOLVED** | External evaluations are consistently marked v2 on the UI, rollout, and v1 DoD surfaces (`spec:909-925,1211-1213`; `plan:1882-1902`). |
| C4 | **RESOLVED** | Focal layout is `breadthfirst`; ELK is lazy and limited to the mating overlay in both documents and the final diagram (`spec:861-869,1224-1228,1452-1457`; `plan:790-807`). |
| C6 | **PARTIAL** | `BUGS.md` still calls DOC-001..006 met while recording DOC-006 as only partly met and deferred to a future tooling task (`BUGS.md:97-135`). The status is internally mixed. |
| G3 | **RESOLVED** | Parentage, semen, and v2 evaluation relations now all carry farm-paired node keys plus same-farm checks (`spec:226-255,275-295,336-359`; `plan:1578-1612`). |
| N4 | **RESOLVED for stated one-farm v1** | The cache key source and concrete clear-before-sign-out order are now specified (`plan:726-737`). Multi-farm context resolution remains a future boundary, explicitly outside this v1 scope. |
| N10 | **RESOLVED** | P2 uses embedded `breadthfirst`; P4 alone uses lazy ELK layered layout (`plan:779-807,840`; `spec:861-869`). |
| N12 | **RESOLVED** | Stub handlers, call counters, and the required `tests/support/stub-backend.js` path are in the regression task and final map (`plan:1670-1675,1841-1846`). |
| N15 | **RESOLVED** | `evaluation_date` is `NOT NULL` in the canonical table and v2 table minimum (`spec:345-358`; `plan:1581-1599`). |
| N17 | **PARTIAL** | `semen_id_onceki` and the required old-ID log snapshot prevent immediate silent loss, but the design remains one-slot/one-step history and explicitly defers exact per-attempt identity to v2 (`spec:305-324`; `plan:1064-1068`). |
| I4 | **RESOLVED** | The foundation grant block now has concrete, seven-argument parentage and ordered helper signatures (`plan:397-400,438-460`). |
| N1 | **RESOLVED** | The helper definitions and grants use matching legal input-parameter order and complete type lists (`plan:397-400,446-460`). |
| N3 | **RESOLVED** | The semen catalog now has `bull_farm_id` plus composite FK and `CHECK (farm_id = bull_farm_id)` (`spec:275-295`; `plan:367-373`). |
| F1 | **RESOLVED** | The manual-pregnancy path now explicitly blocks non-empty free text and defines controlled selection versus deliberate NULL; the three input sources are inventoried (`plan:1128-1144,1180-1205`). |
| F2 | **RESOLVED** | `evidence` is present on the edge schema, the helper accepts `p_evidence`, and birth calls pass provenance payloads (`spec:233-268`; `plan:438-445,1253-1254`). A separate acceptance gap is listed below. |
| F3 | **RESOLVED for stated one-farm v1** | `PEDIGREE_FARM_ID` and the farm-prefixed cache key are now concrete (`plan:726-732`; `spec:994-1003`). Cross-farm context selection is deferred by scope. |
| F4 | **RESOLVED at implementation-surface level** | `js/auth.js` is named and the plan now specifies the top-level API function and ordering (`plan:732-737,1841-1845`). The final-map spelling drift is a new finding below. |
| F5 | **RESOLVED** | The required stub file and handler/call-counter acceptance are both explicit (`plan:1670-1675,1841-1846`). |
| F6 | **PARTIAL** | The DB-owned cutoff now has Phase-2 DDL and Phase-6 population (`plan:562-580,1208-1213`), so the filename authority is gone. The untyped text value and absent cast/error contract remain. |
| F7 | **PARTIAL** | The recurrence and numeric missing-parent example were added (`plan:1370-1388`), but the inbred-ancestor fixture still has no expected numeric result (`plan:1409-1423`). The missing-parent depth ambiguity is a new finding below. |
| F8 | **RESOLVED** | The node-kind/farm-animal conditional CHECK is present in both the canonical schema and foundation requirements (`spec:200-206`; `plan:319-335`). |
| F9 | **RESOLVED** | The v2 table contract now declares `node_farm_id`, the composite FK/check, response fields, ordering, and same-farm empty-list behavior (`spec:336-359`; `plan:1576-1612`). |
| F10 | **RESOLVED at signature/schema level** | The edge evidence column, `p_evidence` argument, matching grant, and birth payload now agree (`spec:233-242`; `plan:397-400,438-445,1253-1254`). Persistence coverage is a fresh gap below. |
| F11 | **RESOLVED** | `pedigree_meta` is created with the Phase-2 report, and a missing cutoff is explicitly handled without a missing-relation failure (`plan:562-580`). |
| F12 | **RESOLVED** | All four semen-aware write grants are listed in the Task 10 migration (`plan:411-415`). |
| F13 | **RESOLVED** | Required helper parameters precede defaulted parameters and the grants match those signatures (`plan:397-400,446-460`). |
| F14 | **RESOLVED** | The catalog row is now constrained to the farm of its bull FK (`spec:275-295`). |
| F15 | **RESOLVED** | Spec and plan both define `node_farm_id`, its composite FK, and `farm_id = node_farm_id` (`spec:336-359`; `plan:1578-1584`). |
| F16 | **RESOLVED** | The Phase-6 acceptance distinguishes required semen IDs for insemination/repeat from intentional NULL for unknown-sire pregnancy (`plan:1208-1223`). |
| F17 | **RESOLVED at implementation-surface level** | The plan now names a top-level `clearPedigreeCacheStore()` in `js/api.js`, matching the buildless global pattern (`plan:732-737`). The final map still uses another spelling; see F25. |
| F18 | **RESOLVED at ordering level** | Cache clear is required before `db.auth.signOut()`, so the existing `SIGNED_OUT` reload cannot precede invalidation (`plan:733-737`; current reload paths `js/auth.js:239-265`). |
| F19 | **RESOLVED at original semantic level** | Unknown parent slots are now excluded from known completeness and assigned to `unknown_share`, with a numeric one-unknown-parent example (`plan:1376-1381`; `spec:710-713`). The example's depth is still underspecified; see F27. |
| F20 | **RESOLVED** | Task 17 now explicitly creates and grants both primitive functions (`plan:1390-1440`; grants `plan:419-420`). |
| F21 | **RESOLVED** | The Task 2 grant for `pedigree_integrity_report()` is present (`plan:406-407`). |
| F22 | **RESOLVED at response-field level** | `unknown_share` and the sum invariant are now part of the profile contract (`spec:694-713`). Founder/unknown classification under all traversal cases remains a fresh gap below. |

## 2. Fresh hunt

The findings below are new in r5. `VERIFIED` means the defect follows from the
current documents/repository (with the evidence file treated as the only live
claim source); `HYPOTHESIS` marks a risk whose exact SQL body is not present in
the plan.

### Accuracy

**F23 — [unmeasured-claim] VERIFIED — The measured maternal anomaly still enters the “safe” confidence-1 backfill.**

The backfill accepts every row where `child.anne_id` equals an existing
`hayvanlar.id` and assigns `source_type = reconcile` with `confidence = 1`
(`plan:542-560`). S8 reports one measured animal whose dam's `dogum.tarih` is
after the child's birth (`evidence:123-141`), and the plan acknowledges that
anomaly (`plan:259-264`). That row still satisfies the only backfill predicate,
so the migration can create an impossible dam edge while asserting full
confidence. No exclude, warning-only, unresolved, or reduced-confidence rule
is specified for the known anomaly.

**F26 — [doc-drift] VERIFIED — Known founder nodes and unknown parent slots are not distinguished by the model/algorithm contract.**

The profile contract sends a missing parent slot to `unknown_share`
(`spec:710-713`), while the founder propagation rule says a node with no
parent information or a depth boundary is a founder boundary (`spec:723-729`;
`plan:1501-1508`). The graph schema has no state identifying whether a
parentless external node is a known founder or an unrecorded parent slot. A
child with no parent edge can therefore be assigned named-founder mass or
unknown mass depending on which sentence an implementer follows, violating
the claimed `founder_contributions + unknown_share = 1` semantics.

**F27 — [unmeasured-claim] VERIFIED — The missing-parent fixture expects depth-one slots without declaring depth one.**

The new fixture expects `known_slots = 1`, `total_slots = 2`, and
`unknown_share = 0.5` (`plan:1376-1381`), but the profile and mating APIs
default to depth 6 (`spec:684-687`; `plan:1440-1447`), whose complete target
has 126 slots (`spec:697`). No fixture call or rule says this case uses
`depth = 1`, nor how deeper slots under the missing branch are counted. A
default-depth implementation cannot know whether the required result is 1/2
or a depth-six result.

### Implementability

**F25 — [doc-drift] VERIFIED — The logout hook has two authoritative names.**

The implementation section requires the top-level
`clearPedigreeCacheStore()` function (`plan:732-737`), while the final change
map still requires a `clearPedigreeCache()` hook (`plan:1841-1845`). The current
buildless source has neither function and the logout/listener paths are still
the old ones (`js/api.js:94-133`; `js/auth.js:239-265`). A worker using the
final map can implement the wrong name and leave the required call undefined;
the cache-invalidation acceptance then depends on an unrecorded choice.

**F28 — [unmeasured-claim] VERIFIED — `pedigree_integrity_report()` has no response-shape contract.**

The spec and plan list the checks that should be returned as JSON
(`spec:1128-1147`; `plan:582-594`), but define no field names, scalar-versus-
array shape, row identity, severity/status, or representation for the missing
cutoff/anomaly rows. The client wrapper is named (`plan:741-755`) and the P1/G2
gates consume the report, yet no fixture can assert a compatible payload or
surface the S8 anomaly consistently. Different implementations can all satisfy
“JSON groups” while producing incompatible report and UI behavior.

**F29 — [dead-path] HYPOTHESIS — The new optional evidence argument can violate the NOT NULL edge column.**

The canonical edge column is `evidence jsonb NOT NULL DEFAULT '{}'` (`spec:233-236`),
but `pedigree_parent_set` declares `p_evidence jsonb default null`
(`plan:438-445`). Birth calls pass evidence (`plan:1253-1254`), while manual,
import, and reconciliation calls may use the helper default
(`plan:470-481`). If the planned body inserts `p_evidence` directly, those
paths fail the NOT NULL constraint; if it coalesces NULL, that behavior is not
specified or tested. The SQL body is not included, so this remains a
hypothesis requiring an explicit non-null/coalesce contract.

### Contradiction and lifecycle gaps

**F24 — [doc-drift] VERIFIED — Rollout G2 is undefined/dead against the measured data.**

G2 requires “integrity report + maternal backfill clean” before projection
(`plan:1865-1873`), while S8 records one temporal maternal mismatch and the
plan calls it the first real integrity finding (`evidence:138-141`;
`plan:259-264`). The plan never defines “clean” as “report ran with accepted
warnings” rather than “zero findings.” Under the literal zero-finding reading
G2 cannot open; under the warning reading the acceptance is not measurable.

**F30 — [doc-drift] VERIFIED — The spec's self-review still presents the v2 founder table as an unqualified design decision.**

The v1 boundary says `pedigree_founder_contributions` is absent and founder
mass is returned on demand (`spec:399-425`; `plan:129-136,1494-1510`), but the
spec self-review says the founder distribution “was separated” into that table
without a v2 qualifier (`spec:1393-1403`). An executor reading the decision
section can create the deferred table in v1 or treat the v1 profile response
as incomplete. The authority needs one explicit v1/v2 interpretation.

## 3. VERDICT: FAIL

The documents are **not ready to serve as implementation authority**.

The r4 fixes close the original signature, grant, composite-key, evidence-
field, cache-order, and unknown-share omissions at the stated surface level.
However, the current authority still has material blockers:

- the known S8 maternal anomaly is accepted by the backfill as a confidence-1
  “safe” edge, while the G2 gate has no way to pass or classify that finding
  (F23, F24);
- founder versus unknown ancestry is still ambiguous, and the only new
  missing-parent fixture is incompatible with the default depth unless an
  unstated choice is made (F26, F27);
- the integrity report cannot be implemented or consumed compatibly without a
  JSON contract (F28);
- the logout function name drift can recreate the cache dead path (F25);
- I6/F6 retain an untyped cutoff parsing/validation residual, C6 retains a
  contradictory documentation status, N17 retains only one-step repeat
  history, and F7 still lacks a numeric inbred-ancestor expectation;
- the v1/v2 founder-table boundary remains ambiguous in the spec decision log
  (F30).

The explicitly gated live preflight inputs are not counted as defects merely
because this seat cannot produce them; they remain prerequisites for the
affected implementation phases.

## 4. Confidence and unverified boundaries

Confidence is high for the static document/repository findings: the current
spec, plan, r4 report, evidence file, `BUGS.md`, current auth/API source,
migration inventory, rollout gates, and exact post-merge HEAD were checked
locally. Confidence is limited for live behavior: there is no live DB access,
S8 supplies aggregate evidence without identifying the anomalous row, and the
PROD 42804 reproduction, ET decision, mapping, legacy return/error shapes, and
post-deploy privileges remain **UNVERIFIABLE FROM THIS REVIEW SEAT**. F29 is
explicitly a hypothesis because the planned SQL bodies are not present.

Only this report is written on the branch; no product, migration, evidence,
spec, plan, or prior report file was changed.
