# Pedigree Revision 2 Review — Round 6

## Review basis and incoming-work gate

Incoming-work gate: **ACCEPT AND START**. The task is executable as a static
spec/plan/repository review and the report path is measurable. The gate crumb
is `a7ffc0c1bcc0`.

The worker checkout is at `2917c6b17ac1a06a2b1cecf892fa898992db55bd`, while
the local `main` containing the post-round-5 integration is
`c9dd71c2c38c0c766bdd56c60a18e218476761bf`. The task boundary forbids a merge,
so the post-round-5 material was verified read-only with `git show main:<path>`;
the report itself is written only on this worker branch. The review basis for
the target documents is therefore the named `main` commit, not the stale worker
tree. This checkout mismatch is recorded as an environment limitation, not
silently treated as an implementation result.

No live DB access was used. The S1-S8 evidence file is the only source for live
claims. The round-5 report was treated as material to verify, not as authority.
For compactness below, `spec`, `plan`, `evidence`, and `BUGS` refer to the
corresponding files under `.claude/` or the repository root at the review-basis
commit.

## 1. Round-5 finding resolution

Statuses are based on the artifact. `RESOLVED` means the round-5 mechanism is
now stated sufficiently at the document/contract level; it does not claim that
the planned implementation or live deployment exists. `PARTIAL` means the
original mechanism is improved but an intentional or material residual remains.

| ID | Status | Evidence and residual |
|---|---|---|
| I6 | **RESOLVED** | `plan:573-590` creates `pedigree_meta` in the integrity phase and defines missing-key behavior. `plan:618-622` now states ISO-8601 storage, `value::timestamptz` parsing, invalid/missing outcomes, and skipping the NULL counter; the value remains a deliberately generic metadata `text` field, but the previously absent parse/error contract is explicit. |
| C6 | **RESOLVED at documentation-status level** | `BUGS:99-103,130-136` no longer calls DOC-006 partly met while also calling the group complete: it records the tracked dry-run as a scheduled `plan:512-519` delivery. `scripts/db-dry-run.sh` is still absent from the current tree, but that is future implementation work explicitly staged in Task 1.7, not the round-5 mixed-status contradiction. |
| N17 | **PARTIAL** | The design now openly scopes v1 to a one-step predecessor (`spec:305-324,1371-1375`; `plan:1092-1096`). `semen_id_onceki` plus the required log snapshot prevents immediate loss, but full per-attempt semen history is still deferred to v2; this is a documented residual, not a complete resolution. |
| F6 | **RESOLVED** | The DB-owned cutoff authority remains in `plan:1236-1249`, while `plan:573-590,618-622` supplies the missing typed-parse/error behavior and avoids a silent default. |
| F7 | **RESOLVED** | The previously missing numeric inbred-ancestor expectation is now explicit: `plan:1451-1456` requires `pedigree_kinship(X,A)=0.3125` for an ancestor with `F_A=0.25`, and ties it to the fixture gate. |
| F23 | **RESOLVED at the original mechanism level** | `plan:565-569` now excludes the measured temporal anomaly from the confidence-1 maternal backfill and routes it to `maternal_tarihsel_uyumsuz` as a blocker. S8 remains the evidence for the measured anomaly (`evidence:123-141`). A predicate-quality residual introduced by this wording is reported as F31 below. |
| F24 | **RESOLVED at literal gate-definition level** | `plan:1901-1905` defines G2 as blocker count zero with every warning/info finding classified and accepted, explicitly rejecting the old ambiguous “clean” wording. The missing acceptance-record mechanism is a new residual reported as F33, not the old undefined-zero-versus-warning ambiguity. |
| F25 | **RESOLVED** | The implementation surface and final map use the same name, `clearPedigreeCacheStore()` (`plan:760-765,1875-1879`); the old `clearPedigreeCache()` spelling is gone. The current production source still has the pre-feature logout code because the plan has not been implemented, which is expected for this review. |
| F26 | **RESOLVED at contract level** | The three states are now explicit: registered founder, unknown parent slot, and depth boundary (`spec:719-734`; `plan:1403-1415,1534-1542`). The invariant and unknown-share behavior are stated, so the prior absence of a model/algorithm distinction is closed. The remaining gate/acceptance ambiguity is covered separately by F33. |
| F27 | **RESOLVED** | The missing-parent fixture now explicitly calls with `p_depth=1` and expects `known_slots=1`, `total_slots=2`, ratio `0.5`, and `unknown_share=0.5` (`plan:1409-1411`), removing the default-depth ambiguity. |
| F28 | **RESOLVED at response-shape level** | `plan:605-622` defines one JSON object with `generated_at`, `cutoff`, `groups`, `code`, `severity`, `items`, `key`, and `detail`; invalid/missing cutoff representation is also named. The remaining question is whether G2 acceptance is represented and measurable, which is F33. |
| F29 | **RESOLVED** | The helper contract now requires `COALESCE(p_evidence, '{}'::jsonb)` for the NOT NULL edge field and requires a fixture for omitted evidence (`plan:438-448`), matching `spec:233-236`. |
| F30 | **RESOLVED** | The v1/v2 boundary is now explicit both in the v1 metric decision (`plan:129-136,1527-1532`) and in the spec self-review (`spec:399-425,1412`): v1 returns founder mass on demand; the persistent table is v2. |

## 2. Fresh hunt

The findings below are new in round 6. `VERIFIED` means the defect follows
from the current documents/repository and does not require a live probe.

### Accuracy

**F31 — [doc-drift] VERIFIED — The F23 maternal exclusion does not implement the measured S8 predicate and mishandles valid/unknown dates.**

The new rule says to reject a child when the dam’s *latest* birth record has
`dogum.tarih > child.dogum_tarihi` (`plan:565-568`). S8 instead defines the
measured anomaly as `NOT EXISTS` any dam birth record with
`d.tarih <= h.dogum_tarihi` (`evidence:130-141`). If a dam has one valid birth
record before a child and a later birth record after that child, the planned
“latest” predicate rejects a valid maternal edge even though S8’s predicate
does not. If `child.dogum_tarihi` is NULL, `d.tarih > NULL` is unknown and the
new exclusion does not fire, so the earlier resolve-by-`anne_id` predicate can
still create a confidence-1 edge without a temporal proof. The plan needs one
exact predicate plus an explicit missing-date outcome before the backfill can be
implementation authority.

### Implementability

**F34 — [unmeasured-claim] VERIFIED — The invalid-cutoff result is promised but the prescribed cast can abort the report.**

The plan requires `value::timestamptz` and says a cast error must return
`cutoff: "gecersiz"` and skip the NULL counter (`plan:618-622`). In PostgreSQL,
an invalid text-to-`timestamptz` cast raises an exception; no safe-cast helper,
PL/pgSQL exception block, validation constraint, or SQL fixture is specified.
An implementation following the literal operation can therefore abort
`pedigree_integrity_report()` instead of returning the documented JSON, making
the malformed-metadata path non-deterministic. The plan must prescribe the
exception-safe operation and test its result.

### Contradiction and acceptance gaps

**F33 — [unmeasured-claim] VERIFIED — G2 requires recorded warning/info acceptance without defining the record or severity matrix.**

G2 requires “every finding classified,” `blocker=0`, and warning/info findings
“accepted recorded” (`plan:1901-1905`). The response contract provides a
`severity` field but no disposition/accepted field, owner decision artifact,
status transition, or fixture for that acceptance (`plan:605-622`; `spec:1154-1156`).
It also gives no code-to-severity mapping for the listed integrity groups; only
the maternal group is shown as a blocker and the spec only labels the last two
checks as warnings (`plan:591-603`; `spec:1139-1152`). Two implementations can
produce valid-looking JSON while disagreeing on whether G2 is open. The gate
needs an explicit group/severity table and a recorded acceptance mechanism.

### Lifecycle gaps

**F32 — [race-lifecycle] VERIFIED — Non-explicit `SIGNED_OUT` events bypass the planned pedigree-cache clear.**

The plan specifies cache clearing before the explicit `db.auth.signOut()` call
(`plan:760-765`) and the final map names that logout hook (`plan:1875-1879`).
The existing auth listener independently handles `SIGNED_OUT` by reloading the
page (`js/auth.js:262-265`), while the explicit logout path is separate
(`js/auth.js:239-244`). Session expiry, another-tab logout, or another
Supabase-originated sign-out can therefore reload without clearing the
`pedigree_cache` store. The next session can retain and reuse the prior cache,
contradicting the plan’s “exit/context change completely clears the store”
requirement (`plan:754-756`). The listener path must clear before reload, and
the acceptance must exercise both explicit and externally-originated sign-out.

No additional independent findings were found in the four required angles
beyond F31-F34 and the resolution-table residuals above.

## 3. VERDICT: FAIL

The documents are **not ready to serve as implementation authority**.

The round-5 changes close most of the named surface defects: cutoff
interpretation, DOC-006 status wording, the inbred fixture, maternal anomaly
routing, logout naming, founder/unknown terminology, missing-parent depth,
integrity-response shape, evidence defaulting, and v1/v2 founder scope are now
substantially clearer. N17 remains a deliberate but material one-step history
limitation.

The fresh blockers are sufficient for FAIL:

- F31 can either reject a valid maternal edge or accept a missing-date edge as
  confidence 1, so the central reconciliation safety rule is not executable as
  written.
- F34 can turn the promised malformed-cutoff report into a function exception.
- F33 leaves the G2 rollout gate dependent on an unrecorded owner decision and
  an undefined severity mapping.
- F32 leaves a sign-out lifecycle path with stale pedigree data despite the
  cache-isolation requirement.

## 4. Confidence and unverified boundaries

Confidence is high for the static document/source findings and the resolution
checks at `main` commit `c9dd71c`: the target spec, plan, r5 report, S1-S8
evidence, `BUGS.md`, current auth/API source, migration inventory, and rollout
gates were checked by exact line. Confidence is limited for live behavior:
there was no live DB access, S8 is an aggregate result without the anomalous
row identity, and the ET decision, mapping artifact, PROD 42804 reproduction,
legacy error/return captures, and post-deploy privileges remain
**UNVERIFIABLE FROM THIS REVIEW SEAT**. The worker branch being behind `main`
is explicitly recorded above; no merge was performed.

## 5. Verification evidence

The read-only basis checks produced:

```text
$ git rev-parse HEAD
2917c6b17ac1a06a2b1cecf892fa898992db55bd
$ git rev-parse main
c9dd71c2c38c0c766bdd56c60a18e218476761bf
$ git status --short --untracked-files=all
# empty
$ git ls-tree -r --name-only main | rg '^scripts/db-dry-run\.sh$'
# no match (tracked dry-run is planned, not yet present)
$ git cat-file -e main:.claude/tasks/2026-09-10-pedigree-rev2-review-r6.md
# exit 0
```

Only this report file is written in the repository. No product, migration,
evidence, spec, plan, BUGS, or prior-review file was changed.
