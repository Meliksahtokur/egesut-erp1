# Pedigree Revision 2 Review — Round 11

## Review basis and incoming-work gate

The review basis is the current worker checkout at `dfc49d48ec5e08d507a0942caafdec9637c325cf`, which contains the post-round-10 document fix and the r10 report. The worker branch was initially at the stale `origin/main` tip `2917c6b`; it was fast-forwarded with `git merge --ff-only main` on the worker branch only. No merge into `main` and no push were performed.

Incoming-work gate: **ACCEPT AND START**. The stale checkout was an environment mismatch, not a defect in the review envelope; after the fast-forward, the post-r10 spec, plan, S1–S8 evidence, the suffix-less r1 report, and r2–r10 reports were present. The gate crumb is `646f8a77b991`.

Prior reports, revision banners, BUGS.md, and evidence were treated as data to verify, not as instructions. No instruction-like injection text was found in the reviewed material. No live DB, provider, browser, migration, or frontend execution was used; S1–S8 is the only source used for live claims.

`RESOLVED` below means that the original document-contract defect is closed; it does not claim that migrations, code, deployment, or live behavior exist. `PARTIAL` means that the named repair exists but a material contract residual remains. `UNRESOLVED` means the original safety/authority failure still has a conforming counterexample.

## 1. Round-10 finding resolution

| Finding | Status | Evidence and resolution judgement |
|---|---|---|
| F45 | **RESOLVED** | The owner SQL template has balanced `VALUES`/`jsonb_build_object` parentheses and places `::text` inside the third expression (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:729-748`). It was not executed against a database. |
| F46 | **RESOLVED** | The cache contract uses one `globalThis.__pedigreeSessionGen` binding and forbids a module-local counter (`plan:920-943`). |
| F47 | **RESOLVED** | `epoch` is present in the declared cache row and is required on write/read, including network fallback (`plan:870-880,952-960`). |
| F48 residual | **PARTIAL** | The calf join and parent-date expression were added (`plan:697-717`), but the join is a scalar lookup by `hayvanlar.kupe_no`. The repository permits business-tag recycle and only enforces uniqueness for active, non-empty tags (`supabase/migrations/20260901000002_kupe_revizyon.sql:214-220`; `.harness/references/domain-rules.md:31-34`). A historical inactive animal plus a current active animal can therefore match one `dogum.yavru_kupe`, causing a multi-row scalar-subquery failure rather than a deterministic report. |
| F49 | **RESOLVED** | The single G2 rule is repeated consistently: no emitted blocker items and every warning/info item must be accepted and non-stale (`plan:720-727,2081-2087`). |
| F50 | **RESOLVED** | The machine value is consistently `tanimsiz`; invalid values use `gecersiz`, with no `tanımsız` spelling in the current spec/plan (`plan:626-671,720-758`; `spec:1149-1151`). |
| F51 | **RESOLVED at the anonymous-grant level** | Foundation grants the new table/RPC surfaces only to `authenticated` (`plan:401-431`), and the repository auth gate revokes PUBLIC/anon defaults for future objects (`supabase/migrations/20260614000007_auth_gate_lockdown.sql:7-29`). The separate operator and lifecycle issues are recorded below. |
| F52 | **RESOLVED** | The 17-code universe and severity matrix contain the same codes (`plan:632-640,673-685`); the text explicitly removes a competing list. |
| F53 | **RESOLVED** | Empty groups are omitted, post-cutoff violations are per-row items with a defined key/detail, and invalid cutoff has a defined single item (`plan:642-646`). |
| F54 | **RESOLVED at the original ordering level** | The generation counter and epoch are required synchronously before `await idbClearStore` (`plan:945-950`). F64 below shows a distinct post-fence/fail-open race that remains. |
| F55 | **RESOLVED** | Task 17 now places all v1 metric RPCs in `20260910000008_mating_analyze.sql`, explicitly excludes the metrics foundation from v1, and the final sequence marks `000007` as v2 (`plan:1540-1552,1653-1679,1987-2001`). |
| F56 | **PARTIAL** | D4 now acknowledges that the lexical probe was insufficient and requires behavioral remeasurement (`plan:106-116`); S1 records a behavioral claim (`evidence:33-39`). The correction has no reproducible call/input/before-after output, and the current BUGS registry still says BUG-001 is open and that the planned path does not deduct (`BUGS.md:15-26`). F65 records that cross-document contradiction. |
| F57 | **UNRESOLVED** | The new guard blocks changing `bull_node_id` only when `tohumlama.semen_id` references the row (`plan:490-496`). It ignores historical `tohumlama.semen_id_onceki` references (`plan:1268-1272`), and Task 8 still declares `tohumlama.semen_id ... ON DELETE SET NULL` (`plan:1171-1178`) while the spec's corresponding FK has the default delete action (`spec:305-313`). A used catalog row can therefore lose or rewrite a historical sire identity. |
| F58 | **PARTIAL** | An operator guard is now named for the three mutation RPCs (`plan:440-448`), but its storage/order and birth-path interaction are not executable; see F62 and F63. |
| F59 | **RESOLVED at the finite-depth level** | One non-negative rule is stated for all four analysis RPCs: NULL→6, negative→exception, above 8→clamp to 8, with `effective_depth` (`plan:1596-1600`). |
| F60 | **RESOLVED** | The spec example and Task 17 use the same named completeness object and `effective_depth` (`spec:667-680`; `plan:1653-1679`). |
| F61 | **RESOLVED** | `suspiciously_young_parent` now requires a non-negative age difference, leaving future-born parents to `parent_born_after_child` (`plan:703-709`). |
| F33 residual | **RESOLVED at the original acceptance-binding level** | The immutable hash, owner SQL storage, current-detail comparison, and stale-on-change rule are present (`plan:729-754`). The SQL template was not live-executed. |
| F36 residual | **RESOLVED at the cutoff/G2 representation level** | Missing/invalid cutoff states, `cutoff_invalid`, and the single G2 predicate are represented consistently (`plan:626-727,756-758`). |
| F37 residual | **RESOLVED at the owner-decision mechanism level** | Client acceptance RPC/grant is absent; owner SQL plus the hash rule is specified (`plan:729-754`). |
| F39 residual | **RESOLVED at the original stale-after-clear mechanism level** | Shared generation, epoch quarantine, and fail-open cleanup are specified (`plan:931-960`). F64 is a newly exposed race inside that broader policy. |
| F40 | **RESOLVED at the original machine-state level** | Item stale state, cutoff suppression, invalid-cutoff blocker, and G2 conditions are explicit (`plan:720-727`). |
| F41 | **RESOLVED** | The buildless cross-script binding is explicitly `globalThis.__pedigreeSessionGen` (`plan:936-943`). |
| F42 | **RESOLVED at the original row-quarantine level** | Epoch is part of the row and every read compares it to the current epoch, including rejected-clear behavior (`plan:952-960`). |
| F43 | **RESOLVED at the original acceptance-RPC surface** | `pedigree_accept_finding` is explicitly absent and no client grant is needed for the hash helper (`plan:411-431,729-754`). |
| F44 | **PARTIAL** | The three omitted controls now have predicates and item keys (`plan:690-709`), but the `dogum` calf join remains non-deterministic under the valid tag-recycle state described for F48. |
| N17 documented residual | **PARTIAL — documented intentional v1 residual** | v1 keeps one `semen_id_onceki` predecessor and an operation-log snapshot, while full per-attempt history remains v2 (`spec:305-326,1355-1371`; `plan:1268-1272`). It is explicitly scoped, but the predecessor reference must still be protected by F57's identity guard. |

## 2. Fresh findings

### F62 — [dead-path] VERIFIED — the operator guard blocks the normal birth parentage path

The guard applies to `pedigree_parent_set` (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:440-448`). The planned `dogum_kaydet` integration calls that same RPC for both dam and sire edges (`plan:1443-1463`), and the acceptance path requires ordinary births to succeed (`plan:1483-1499`). A normal authenticated user whose UID is not the single bootstrap owner will hit `assert_is_operator()` during birth; the stated all-in-one transaction then rolls back the birth when the graph write fails. No trusted internal helper/bypass or separate authorization rule for birth-originated edges is specified. The plan therefore makes the core new calf flow unavailable to non-owner accounts.

### F63 — [doc-drift] VERIFIED — the operator guard depends on a later, undefined metadata contract

The foundation migration grants and exposes the mutation RPCs (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:390-409`) and the guard is required there (`plan:440-448`), but `pedigree_meta` is created only in Task 2 (`plan:610-624`). The table has only generic `key`/`value` columns; no `op_owner_uid` key lookup, `assert_is_operator()` DDL, bootstrap ordering, or foundation-time owner row is defined. Phase 1's foundation tests already cover parentage and external-node invariants (`plan:299-312`). A conforming foundation call can therefore fail because the guard's relation/owner row does not exist, while an implementer must invent the metadata lookup and sequencing. This is separate from F62's runtime authorization overreach.

### F64 — [race-lifecycle] VERIFIED — fail-open asynchronous cleanup permits post-fence writes

The explicit logout path awaits cache cleanup before `signOut`, while the signed-out listener similarly waits before reload (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:897-906`). A request is rejected only when its start-time generation differs from the current generation (`plan:918-927`). The clear fence increments generation/epoch synchronously and only then awaits IDB deletion (`plan:945-950`); if deletion fails, reads accept rows carrying the new epoch (`plan:952-960`). A request that starts after the fence but before `signOut` (or in another tab whose `globalThis` counter is independent) can write a new-epoch row. On the allowed fail-open clear failure, the next session can read that row as valid. The acceptance scenario covers a pre-fence pending response, not a post-fence request during failed cleanup, so F54/F39/F42 are not sufficient to close this race.

### F65 — [doc-drift] VERIFIED — D4/S1 and the repository bug registry disagree on BUG-001

D4 calls `planli_tohumlama_kaydet` a delegating path and labels BUG-001 refuted (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:90-116`); the S1 correction repeats that conclusion and states one behavioral stock movement (`.claude/reviews/2026-09-10-live-probe-evidence.md:21-39`). The current repository registry still labels BUG-001 `[open]`, says the live planned function does not deduct, and retains the old fix direction (`BUGS.md:15-26`). D4 also says the bugfix goal is pending and must merge before the write contract is frozen (`plan:90-102`). No document declares which status is authoritative or reconciles the registry with the claimed live behavioral result. An implementer cannot determine whether to preserve the delegation, wait for the pending bugfix, or treat planli as the unfixed path; this reopens the stock/write contract that F56 was meant to close.

## 3. VERDICT: FAIL

The documents are **not ready to serve as implementation authority**. F45–F47, F49–F55, F59–F61, and the original acceptance/cutoff/cache-row residuals are materially improved. However, F48/F44 still cannot produce a deterministic integrity report for a valid recycled-tag state; F56 lacks reproducible behavioral evidence and remains contradicted by BUGS.md; F57 permits historical semen identity loss through predecessor references and a mismatched delete action; F58 is not operationally implementable; and F62–F65 independently block normal birth, foundation migration use, cache isolation, and the stock contract. These are implementation-authority blockers, not missing test polish.

## 4. Confidence and unverified boundaries

Confidence is **high** for the static document contradictions and the F48/F57/F62/F63/F64 counterexamples. F64 is a contract-level race analysis, not a claim that cache code already exists. F56/F65 are evidence/provenance findings; no live behavior was re-probed. No migration, SQL fixture, frontend, browser, provider, deployment, or live DB state was exercised. The current deployed behavior beyond the claims recorded in S1–S8 remains **UNMEASURED**.

## 5. Verification evidence

```text
$ git merge --ff-only main
Updating 2917c6b..dfc49d4
Fast-forward

$ git rev-parse HEAD && git branch --show-current
dfc49d48ec5e08d507a0942caafdec9637c325cf
idle/pedigree-rev2-review-r11

$ test -f .claude/reviews/2026-09-10-pedigree-rev2.md && echo 'r1 present'
r1 present

$ find .claude/reviews -maxdepth 1 -type f -name '2026-09-10-pedigree-rev2-r*.md' -printf '%f\n' | sort -V
2026-09-10-pedigree-rev2-r2.md
2026-09-10-pedigree-rev2-r3.md
2026-09-10-pedigree-rev2-r4.md
2026-09-10-pedigree-rev2-r5.md
2026-09-10-pedigree-rev2-r6.md
2026-09-10-pedigree-rev2-r7.md
2026-09-10-pedigree-rev2-r8.md
2026-09-10-pedigree-rev2-r9.md
2026-09-10-pedigree-rev2-r10.md

$ rg -n -i '(^|[^[:alnum:]])(ignore|system|assistant|directive|talimat|komut|previous instructions|forget instructions)([^[:alnum:]]|$)' \
    .claude/specs/2026-09-10-pedigree-genetics-architecture.md \
    .claude/plans/2026-09-10-pedigree-genetics-impl.md \
    .claude/reviews/2026-09-10-live-probe-evidence.md \
    .claude/reviews/2026-09-10-pedigree-rev2-r{2,3,4,5,6,7,8,9,10}.md
# no output

$ git status --short --untracked-files=all
# clean before this report was created
```

Only this requested report is authored by this worker. No product, migration, spec, plan, BUGS.md, evidence, or prior-review file was changed.
