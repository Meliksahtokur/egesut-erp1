# Pedigree Revision 2 Review — Round 7

## Review basis and incoming-work gate

Incoming-work gate: **ACCEPT AND START**. The envelope is executable as a
static spec/plan/repository review, and its report path and verdict are
measurable. Gate crumb: `894b09fd5618`.

The worker checkout is `2917c6b17ac1a06a2b1cecf892fa898992db55bd`. The target
post-round-6 material is on `main` at `c72bc60a7e82dfc389416ccddc1bf6542f478be7`
(first parent `d8b1a3c`, which contains the post-round-6 plan fixes and the r7
envelope). The worker branch was not merged or rebased; all `spec`, `plan`,
`evidence`, and source line references below refer to that pinned `main` tree.

No live DB access was used. The S1-S8 evidence file is the only source for
live claims. Prior reports were treated as material to verify, not authority.

## 1. Round-6 finding resolution

`RESOLVED` means the original mechanism is specified sufficiently at the
document/contract level; it does not claim that the migration or frontend
implementation exists. `PARTIAL` records a material residual that still
prevents the relevant contract from being implementation-ready.

| Finding | Status | Evidence and residual |
|---|---|---|
| F31 | **RESOLVED at the original mechanism level** | The backfill now requires the exact `EXISTS` predicate, an existing dam, and a non-NULL child date (`plan:565-575`). A later dam record cannot invalidate an earlier valid one, and a missing child date is routed to `maternal_tarih_bilinmiyor` with no automatic edge (`plan:577-581`). This matches the measured S8 comparison (`evidence:123-141`). |
| F32 | **RESOLVED at the original bypass level** | The plan now covers both explicit logout and the independent `SIGNED_OUT` listener, requiring cache clear before sign-out/reload and naming a two-path test (`plan:794-803`). The existing `js/auth.js` remains pre-feature because the plan is not implemented; new lifecycle residuals are F38-F39 below. |
| F33 | **PARTIAL** | The plan adds a group/severity matrix, item `disposition`, and an `integrity_accepted:<code>:<key>` record convention (`plan:617-656`). However, the spec still has a different control universe (F35), and the acceptance record has no exact value schema, write path, fixture, or current-finding binding (F37). The original omission is improved, but G2 is not yet reproducible as an implementation gate. |
| F34 | **RESOLVED at contract level** | The plan replaces the unsafe cast with `pedigree_try_timestamptz()` whose exception block returns NULL, distinguishes missing from invalid cutoff, and requires a malformed-value fixture (`plan:632-639`). Runtime and live-schema proof remain unmeasured. |
| N17 | **PARTIAL — documented residual** | The design explicitly keeps only one predecessor in `tohumlama.semen_id_onceki` and an operation-log snapshot; full per-attempt semen history remains v2 (`spec:305-324`; `plan:1130-1134`). This is an acknowledged v1 limitation, not a newly introduced r7 finding. |

## 2. Fresh hunt

### Accuracy

**F36 — [unmeasured-claim] VERIFIED — G2 can pass while its post-cutoff
semen-null measurement is unavailable.**

The report is explicitly allowed to return `cutoff: tanımsız` when the
`semen_controlled_cutoff` key is absent and to skip the NULL counter
(`plan:599-601`). The same skip applies when the safe helper returns NULL for
an invalid value (`plan:632-639`). Yet `post_cutoff_null_semen` is a blocker in
the new matrix (`plan:641-648`), while G2 only requires `blocker=0` and
accepted warning/info items (`plan:1941-1944`). Thus, before Task 10 has
written the cutoff, or after a malformed cutoff, the blocker is not measured
and G2 can still open read projection. Missing/invalid cutoff must either be a
blocking G2 state or G2 must be explicitly scoped not to claim this check.

### Implementability

**F37 — [fake-arm] VERIFIED — The new F33 acceptance record is not an
executable, freshness-bound acceptance mechanism.**

`pedigree_meta.value` remains an unconstrained `text` column
(`plan:589-597`). The plan says the acceptance key is `= accepted` while also
saying that a JSON owner/date note is stored in `value`, but it defines no
JSON shape or exact predicate (`plan:651-656`). It grants the report RPC but
does not specify an owner-only writer, SQL command, or acceptance RPC
(`plan:405-410`). The only explicit new fixture checks malformed cutoff; the
listed SQL tests do not exercise warning/info disposition or the G2 transition
(`plan:638-639,658-660`; `spec:1160-1174`).

Even if an implementer chooses a representation, a record keyed only by
`<code>:<key>` is not tied to the current item detail, report generation, or a
finding hash. For example, an accepted `parent_born_after_child` item can
remain accepted after the parent/date evidence changes for the same child.
The report can then return `disposition=accepted` without a fresh owner
decision.

### Contradiction

**F35 — [doc-drift] VERIFIED — The architecture spec and implementation plan
define different integrity-report controls and severities.**

The spec lists `hayvanlar.anne_id`/graph-dam mismatch,
`dogum.anne_id`/graph-dam mismatch, and `suspiciously young parent`, then
says the last two checks are warnings (`spec:1139-1152`). The plan's control
list and matrix instead define `unresolved_anne_id`, `child_without_dam`,
`maternal_tarihsel_uyumsuz`, `maternal_tarih_bilinmiyor`, and
`post_cutoff_null_semen`; it has no graph-mismatch codes and no
`suspiciously_young_parent` code, while classifying only
`parent_born_after_child` among that area (`plan:603-649`). The plan also says
its code list is exactly its controls (`plan:631-632`). An implementer
following the spec and one following the plan will produce different JSON and
different G2 blocker/warning outcomes; the spec's pointer to Task 2.3 does not
remove the contradictory control list.

### Lifecycle gaps

**F38 — [race-lifecycle] VERIFIED — Logout clear does not fence in-flight
pedigree cache writes.**

The cache policy writes a successful network response to IDB
(`plan:815-820`). Logout clears before `signOut`, and the `SIGNED_OUT` path
also clears before reload (`plan:788-803`), but no request-generation token,
abort, session check, or drain/barrier is specified. A projection request
started before logout can resolve after either clear and overwrite
`pedigree_cache` for the next session. The required test only spies that the
listener called clear (`plan:801-803`); it does not assert the final store is
empty after a pending response.

**F39 — [race-lifecycle] VERIFIED — A cache-clear rejection can block logout
or reload.**

The planned code awaits `clearPedigreeCacheStore()` before both
`db.auth.signOut()` and `location.reload()` but defines no `try/finally`,
fail-open behavior, or absent-store handling (`plan:795-803`). The current
auth paths have no error boundary around their sign-out/reload sequence
(`js/auth.js:239-265`). If IDB is unavailable, the store is not yet created,
or a transaction rejects, explicit logout can stop before `signOut`, and an
external `SIGNED_OUT` event can stop before reload. Cache isolation must not
turn into a failed sign-out path.

## 3. VERDICT: FAIL

The documents are **not ready to serve as implementation authority**.

F31 and F34 close their original static defects, and F32 closes the original
listener bypass at the stated contract level. The remaining blockers are the
spec/plan integrity-contract drift (F35), a G2 gate that can upgrade an
unmeasured cutoff check to success (F36), an acceptance mechanism that is not
mechanically reproducible or freshness-bound (F37), and cache lifecycle races
and failure behavior that can violate the stated logout isolation guarantee
(F38-F39). N17 is a documented, intentional one-step v1 residual, but it does
not cure those independent blockers.

## 4. Confidence and unverified boundaries

Confidence is **high** for F31-F39 and the resolution statuses as static
document/source findings at `main` `c72bc60`. The target tree, r6 report,
r7 envelope, S1-S8 evidence, `BUGS.md`, active goal, current auth source,
tests, and tracked migration inventory were checked read-only. Confidence is
limited for live behavior: no DB/provider/browser probe was run, no pedigree
migration exists yet, and the planned cache/report code is not implemented.
S8 is an aggregate live result and does not expose the anomalous row identity.

## 5. Verification evidence

```text
$ git rev-parse HEAD
2917c6b17ac1a06a2b1cecf892fa898992db55bd
$ git rev-parse main
c72bc60a7e82dfc389416ccddc1bf6542f478be7
$ git cat-file -e main:.claude/tasks/2026-09-10-pedigree-rev2-review-r7.md
r7 envelope: present
$ git cat-file -e main:.claude/reviews/2026-09-10-pedigree-rev2-r6.md
r6 report: present
$ git status --short --untracked-files=all
# empty before this report was created
$ git diff-tree --no-commit-id --name-status -r d8b1a3c
M	.claude/plans/2026-09-10-pedigree-genetics-impl.md
A	.claude/tasks/2026-09-10-pedigree-rev2-review-r7.md
$ git diff --quiet d8b1a3c^ d8b1a3c -- .claude/specs/2026-09-10-pedigree-genetics-architecture.md
# exit 0: r6 fix commit did not update the spec control list
```

Only this r7 report is written in the worker repository. No product,
migration, evidence, spec, plan, BUGS, or prior-review file was changed.
