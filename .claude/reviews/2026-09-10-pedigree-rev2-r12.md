# Pedigree Revision 2 Review — Round 12

## Review basis and incoming-work gate

This review uses the current worker checkout after the explicit root instruction
to fast-forward from local `main`:

- `HEAD`: `c2631d13073162a686ce0f2dcb304c120a081326`
- branch: `idle/pedigree-rev2-review-r12`
- review basis: the current spec, plan, S1-S8 evidence, BUGS.md, tracked
  migrations, JS, tests, and the available active goal at that SHA

The initial stale checkout at `2917c6b` was corrected with
`git merge --ff-only main`; no merge into `main` or push was performed. The
requested report path and review manifest are supplied by the R12 task envelope.
There is no pedigree-specific active `.harness` goal; the only active goal is
the separate reproduction bugfix goal, which is treated as repository material
and is cited below where its contradiction is relevant.

Incoming-work gate: **ACCEPT AND START**. The envelope is executable as a static
spec/plan/repository audit with a measurable `PASS|FAIL` verdict. The gate crumb
is `50848aba750e` in the worker `.ss` process store.

Prior reports, revision banners, BUGS.md, the active goal, and evidence were
treated as data to verify, not as instructions. No actionable instruction-like
injection was found in the reviewed material. No live DB, provider, browser,
migration execution, or frontend execution was used; the S1-S8 file is the only
source used for live claims.

`RESOLVED` means the original document-contract defect is closed at the static
artifact level; it does not claim that migrations, code, deployment, or live
behavior exist. `PARTIAL` means the named repair exists but a material residual
remains. `UNRESOLVED` means a conforming counterexample or missing authority
still remains.

## 1. Resolution table for the R11 input findings

The table includes the round-10 findings and residuals carried in R11, followed
by R11's own fresh findings F62-F65.

| Finding | Status | Evidence and resolution judgement |
|---|---|---|
| F45 | **RESOLVED** | The owner SQL acceptance template has balanced `VALUES`/`jsonb_build_object` structure and puts `::text` inside the value expression (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:739-758`). It remains statically unexecuted. |
| F46 | **RESOLVED** | The cache contract has one `globalThis.__pedigreeSessionGen` binding and explicitly forbids a module-local counter (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:946-953`). |
| F47 | **RESOLVED** | `epoch` is part of the declared cache row and is required for cache write/read quarantine (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:880-890,967-975`). |
| F48 residual | **PARTIAL** | The calf lookup now has a stated ordering and the parent-date expression (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:712-727`), but it is still a `kupe_no` heuristic. The domain permits inactive tag recycle (`.harness/references/domain-rules.md:31-37`; `supabase/migrations/20260901000002_kupe_revizyon.sql:218-220`), and no authoritative `dogum`-to-calf identity exists. The ordering can be deterministic while still selecting the wrong historical animal; F67 is a concrete new failure of the stated ordering. |
| F49 | **RESOLVED** | The G2 rule is now one explicit predicate: no emitted blocker items and every warning/info item is accepted and non-stale (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:730-737,2102-2103`). |
| F50 | **RESOLVED** | The machine states are consistently `tanimsiz` and `gecersiz` in the cutoff response and G2 sections (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:627-631,655,766-768`; `.claude/specs/2026-09-10-pedigree-genetics-architecture.md:1149-1151`). |
| F51 | **RESOLVED at the new-surface grant level** | The planned new table/RPC grants are authenticated-only (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:394-435`) and the tracked auth gate revokes anonymous/default access (`supabase/migrations/20260614000007_auth_gate_lockdown.sql:7-29`). Existing legacy RPC ACLs are a separate fresh finding (F73). |
| F52 | **RESOLVED** | The 17-code universe and severity matrix enumerate the same codes, with the earlier competing list removed (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:633-641,674-686`). |
| F53 | **RESOLVED at the original count/item level** | Empty groups are omitted, post-cutoff violations are per-row items with `key` and `detail`, and invalid cutoff is one defined item (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:643-647,650-662`). F68 identifies a separate semantic exception that is still misclassified. |
| F54 | **RESOLVED at the original fence-order level** | The generation counter, epoch, and suspension marker are required before `idbClearStore` starts (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:946-958`). F64 remains unresolved because the protection is not shared or bound to an exact writer check. |
| F55 | **RESOLVED** | Task 17 now names `20260910000008_mating_analyze.sql` as the single v1 RPC migration, excludes the metrics foundation from v1, and the final sequence labels `000007` v2 (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:1555-1567,1670,2002-2016`). |
| F56 | **PARTIAL** | D4 acknowledges that the lexical probe was insufficient and records a behavioral claim (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:106-120`; `.claude/reviews/2026-09-10-live-probe-evidence.md:33-39`). The evidence file still contains no reproducible behavioral call, input, before/after stock output, or durable referenced bugfix report in this checkout, so the stock-path premise is not independently reproducible from the allowed live evidence. |
| F57 | **RESOLVED at the original identity/delete-action level** | The guard covers both `tohumlama.semen_id` and `semen_id_onceki`, and the plan aligns both historical FKs to default `NO ACTION` while keeping only `stock_id` nullable on stock deletion (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:499-507`; `.claude/specs/2026-09-10-pedigree-genetics-architecture.md:305-313`). F78 finds a separate concurrency residual in the check. |
| F58 | **PARTIAL** | An owner/operator guard and birth-path intent are now named (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:444-457`), but the metadata/function DDL and exact public-versus-internal call binding are still absent; see F62/F63. |
| F59 | **PARTIAL** | A finite rule is explicit for all four analysis RPCs (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:1611-1615`), but concrete response shapes do not carry the required field consistently and an older “e.g. 8” sentence remains (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:1624-1633,1690-1694`; `.claude/specs/2026-09-10-pedigree-genetics-architecture.md:691-709`). See F75. |
| F60 | **RESOLVED** | The mating example and Task 17 use the same named completeness object and `effective_depth` (`.claude/specs/2026-09-10-pedigree-genetics-architecture.md:667-680`; `.claude/plans/2026-09-10-pedigree-genetics-impl.md:1680-1694`). |
| F61 | **RESOLVED** | `suspiciously_young_parent` now requires a non-negative age difference, leaving future-born parents to `parent_born_after_child` (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:704-710`). |
| F33 residual | **RESOLVED at the original acceptance-binding level** | The immutable hash, owner SQL write, current-detail comparison, and stale-on-change rule are present (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:739-764`). |
| F36 residual | **RESOLVED at the original cutoff/G2 representation level** | Missing/invalid cutoff states, `cutoff_invalid`, group emission, and G2 are represented consistently (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:627-737,766-768`). |
| F37 residual | **RESOLVED at the owner-decision mechanism level** | Client acceptance RPC/grant remains explicitly absent; owner SQL plus hash-based stale acceptance is specified (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:739-764`). |
| F39 residual | **PARTIAL** | Shared generation and epoch quarantine address the original stale-after-clear case (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:941-975`), but F64 still supplies a conforming post-fence cross-tab counterexample. |
| F40 | **RESOLVED at the original machine-state level** | Item state, cutoff suppression/invalid blocker, and G2 are explicit (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:730-737`). F68 is a distinct source-row classification defect. |
| F41 | **RESOLVED** | The buildless script split is bound to `globalThis.__pedigreeSessionGen` and module-local counters are forbidden (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:946-953`). |
| F42 | **PARTIAL** | Epoch is part of each row and read quarantine is defined (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:967-975`), but another tab can write a row with the new shared epoch before its own suspension fence; see F64. |
| F43 | **RESOLVED at the original acceptance-RPC surface** | `pedigree_accept_finding` and its client grant remain absent; the owner SQL path is the declared mechanism (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:739-764`). |
| F44 | **PARTIAL** | The three omitted controls now have predicates and keys (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:688-710`), but the calf identity remains a recycled-tag heuristic (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:712-727`); F48 and F67 remain. |
| N17 documented residual | **PARTIAL — intentional v1 residual** | The one-step `semen_id_onceki` predecessor and operation-log snapshot are explicit, while full per-attempt history remains v2 (`.claude/specs/2026-09-10-pedigree-genetics-architecture.md:305-326,1356-1370`; `.claude/plans/2026-09-10-pedigree-genetics-impl.md:1283-1287`). F57's historical guard is present, but concurrency and complete history are not v1 guarantees. |
| F62 | **PARTIAL** | The new prose introduces an internal `_pedigree_parent_set_core` birth bypass (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:444-457`), but the actual Task 12 transaction steps still call guarded `pedigree_parent_set` for both edges (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:1458-1478`). No exact internal signature, migration definition, or binding makes the bypass authoritative. |
| F63 | **UNRESOLVED** | The foundation create/table list contains only the three graph/catalog tables (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:294-328`); no `CREATE TABLE pedigree_meta`, `assert_is_operator()` definition, `op_owner_uid` storage contract, or bootstrap DDL exists. The guard merely asserts that all are in Task 1 (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:444-457`), while Task 2 still contains the stale claim that the table is created in “this migration” (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:621-625,648`). |
| F64 | **UNRESOLVED** | The fence now sets `globalThis.__pedigreeWritesSuspended` before IDB clear (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:955-965`), but the flag is per-tab and the plan never gives an exact writer check or cross-tab propagation. The shared `localStorage` epoch can therefore be used by a different tab's old request. This is a remaining conforming counterexample, not merely a missing test. |
| F65 | **PARTIAL** | `BUGS.md` now labels BUG-001 refuted (`BUGS.md:15-25`), closing the exact old BUGS mismatch. However the active bugfix goal still records “no stock deduction” (`.harness/goals/2026/G-20260910-UREME-STOK-BUGFIX.md:31-49`), the architecture spec repeats that premise (`.claude/specs/2026-09-10-pedigree-genetics-architecture.md:15-19,549-556`), and D4 points to a bugfix report that is not present in this checkout (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:106-115`). The provenance/authority chain is not reconciled. |

## 2. Fresh findings

### F66 — [silent-success] VERIFIED — maternal backfill can invent a dam edge from an unrelated prior birth

The “safe” maternal edge predicate requires a valid `c.anne_id`, an existing
parent row, a non-null child birth date, and **any** `dogum` row for that parent
with `d.tarih <= c.dogum_tarihi` (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:583-619`). It never joins the child to its own birth event through `c.id`,
`c.kupe_no = d.yavru_kupe`, or another calf identity. The repository model says
one `dogum` row represents one calf (`.claude/specs/2026-09-10-pedigree-genetics-architecture.md:115-117`), and the actual `dogum` table stores `yavru_kupe` (`supabase/migrations/99999999999999_ground_truth.sql:143-158`).

Counterexample: an incorrectly populated later calf has `anne_id=A`; A has any
older birth, but there is no birth row for that calf or its tag. The predicate
passes and creates `A -> calf`. The resulting graph agrees with the bad legacy
`anne_id`, so the later reconciliation controls need not expose the error. S8
only measures the same parent-wide temporal existence, not child identity
(`.claude/reviews/2026-09-10-live-probe-evidence.md:131-149`).

### F67 — [silent-success] VERIFIED — the R11 “deterministic” calf join can select NULL-dated history first

The new join says the exact birth date is first, then active status, then the
latest birth date (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:712-724`). In PostgreSQL, `ORDER BY ... DESC` defaults to `NULLS FIRST`. Thus a recycled-tag `hayvanlar` row with `h.dogum_tarihi IS NULL` produces NULL for the boolean exact-date expression and sorts before a row whose date equals `dogum.tarih`; the later `h.dogum_tarihi DESC` has the same NULL-first behavior. With no authoritative calf foreign key, the report can silently compare the graph edge of the wrong animal. This is a correctness residual inside F48, not merely nondeterministic row order.

### F68 — [silent-success] VERIFIED — intentional unknown-sire pregnancy is counted as a post-cutoff blocker

The manual pregnancy `_semen` RPC explicitly accepts `p_semen_id = NULL`
(`.claude/plans/2026-09-10-pedigree-genetics-impl.md:1278-1280`), and the UI contract calls that NULL an intentional unknown-sire path (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:1421-1425,1434-1438`). The legacy pregnancy implementation nevertheless inserts a `tohumlama` row with `sonuc='Gebe'` and the supplied NULL sperm value (`supabase/migrations/20260605000002_timezone_fix.sql:261-267`).

The integrity rule is unqualified: every `tohumlama` row after the cutoff with
`semen_id IS NULL` is a `post_cutoff_null_semen` violation
(`.claude/plans/2026-09-10-pedigree-genetics-impl.md:643-648,1427-1440`). The live evidence confirms `tohumlama.created_at` exists for that cutoff design (`.claude/reviews/2026-09-10-live-probe-evidence.md:87-93`). Therefore a new intentional unknown-sire pregnancy can emit a blocker and make G2 fail; no source discriminator or exclusion rule is defined.

### F69 — [unmeasured-claim] VERIFIED — most of the 17 integrity groups still lack executable predicates

Task 2.3 declares 17 group codes and a severity matrix
(`.claude/plans/2026-09-10-pedigree-genetics-impl.md:633-686`), while the explicit predicate block only defines the two graph-dam controls, the young-parent control, and the cutoff cases (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:688-728`; the maternal section gives only a coarse temporal predicate at `:603-619`). There is no per-row predicate, key/detail rule, or emission rule for groups including `farm_animal_node_eksik`, `unresolved_anne_id`, `unresolved_baba_bilgi`, `child_without_dam`, `child_without_sire`, `role_sex_contradiction`, `duplicate_registry`, `legacy_semen_no_mapping`, `cycle_count`, and `parent_born_after_child`.

The spec deliberately makes Task 2.3 the sole control authority
(`.claude/specs/2026-09-10-pedigree-genetics-architecture.md:1140-1151`). An implementer can therefore produce materially different reports while satisfying the same listed codes and severity matrix. In particular, `cycle_count` has no report-level recursive path/termination contract, although malformed-cycle termination is specified separately only for projection (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:808-815`).

### F70 — [dead-path] VERIFIED — cache mutation invalidation can permanently disable cache writes

The logout fence sets `globalThis.__pedigreeWritesSuspended = true` and says the
flag remains set until reload (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:955-960`). Separately, every successful graph mutation is required to clear `pedigree_cache` (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:977-990`), but no separate non-fencing invalidator or reset contract is defined. If the only named full-clear path, `clearPedigreeCacheStore()`, is reused for that mutation invalidation, the first parent/catalog mutation suspends all later cache writes until reload. If it is not reused, the plan has not specified the required mutation-clear behavior. Either conforming reading leaves the cache lifecycle non-authoritative.

### F71 — [race-lifecycle] VERIFIED — the suspension flag does not protect a shared cache across tabs

`globalThis.__pedigreeSessionGen` and `__pedigreeWritesSuspended` are browser-realm
globals, while the epoch is stored in shared `localStorage` and rows are in
shared IndexedDB (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:946-975`). Tab A can fence and rotate the shared epoch; before Tab B receives its `SIGNED_OUT` event or runs its own clear, a Tab B request can start and write a row tagged with that new epoch. Tab A's next session accepts that row because it matches the current shared epoch. The plan has no `storage`/`BroadcastChannel` propagation or shared persistent suspension, and its auth listener is only an eventual per-tab callback (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:907-916`). This is the cross-tab counterexample left open in F64.

### F72 — [race-lifecycle] VERIFIED — twin `olay_id` assignment is not serialized

The birth contract requires two concurrent/nearby calves to share one
`olay_id` (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:1458-1478,1498-1514`). The existing transaction first reads the 10-day window and only then creates a new UUID when no row is found (`supabase/migrations/20260901000001_ikiz_dogum_olay_id.sql:53-66`). There is no birth-level advisory lock or unique event key in Task 12; the only stated advisory lock is for parentage mutation (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:511-522`), which occurs after event selection. Two same-mother calls can both observe no prior row and create separate events, so the stated twin acceptance is not concurrency-safe.

### F73 — [scope-violation] VERIFIED — the pedigree-enabled birth path retains an anonymous RPC grant

The plan's new-surface grant block is authenticated-only and the operator text
only discusses authenticated normal births (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:394-457`). Task 12 does not require changing the existing ACL
(`.claude/plans/2026-09-10-pedigree-genetics-impl.md:1448-1478`). The tracked current birth migration explicitly grants `dogum_kaydet` to `anon, authenticated` (`supabase/migrations/20260901000001_ikiz_dogum_olay_id.sql:148-150`), despite the earlier auth lockdown's anonymous revoke (`supabase/migrations/20260614000007_auth_gate_lockdown.sql:7-29`). `CREATE OR REPLACE FUNCTION` does not remove that ACL. Once the new body calls the security-definer graph helper/trigger, a direct anonymous RPC caller can create a birth, calf, and pedigree side effects; no revoke or in-function anonymous guard is specified.

### F74 — [scope-violation] VERIFIED — Task 11 has no declared write owner for the required repeat-selector code

Task 11 requires all three current semen surfaces to close, including the
repeat selector (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:1343-1363`), but its explicit modify list omits `js/ui.js` (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:1343-1346`). The required repeat functions and text-valued option are in `js/ui.js:7452-7495`; the handler calls those functions at `js/utils/handlers.js:430-433`. The final map describes `js/ui.js` only as Soy-tab integration (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:2045-2047`). Because the buildless page loads `ui.js` before `app.js` (`index.html:2221-2228`), editing only the Task 11-listed files leaves the repeat path's existing text identity and handler path without a declared owner. This is a scope/implementability gap, not a cosmetic file-list issue.

### F75 — [doc-drift] VERIFIED — `effective_depth` is not represented consistently in concrete responses

The plan requires `effective_depth` for `pedigree_profile`, `pedigree_kinship`,
`pedigree_inbreeding`, and `mating_analyze` (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:1611-1615`). The concrete relationship JSON omits it (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:1624-1633`), and the profile JSON has only `completeness.target_depth` (`.claude/specs/2026-09-10-pedigree-genetics-architecture.md:691-709`). Task 17's mating sentence adds the object field, but immediately afterward still says “Max depth guard e.g. 8” (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:1680-1694`). A client/fixture following the concrete shapes cannot determine whether clamping is exposed for every endpoint.

### F76 — [scope-violation] VERIFIED — analysis RPCs lack an explicit same-farm/input guard

Projection and semen-aware write contracts explicitly require same-farm checks
and active validation (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:808-815,1299-1305`), while the Task 17 contract only lists caller IDs and result fields and gives no equivalent guard for `p_cow_hayvan_id`, `p_semen_id`, or the primitive node IDs (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:1617-1633,1668-1694`). The global rule makes these functions `SECURITY DEFINER` and graph RLS permissive (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:438-442`). If the declared farm scope is ever populated beyond the current one-farm deployment, an authenticated caller with a foreign ID can obtain or combine data across farms; the plan has no implementation-level guard to prevent it. This is a contract gap, not a claim that multi-farm live data currently exists.

### F77 — [silent-success] VERIFIED — the birth undo acceptance is not connected to the current undo surface

Task 12 promises that undoing a birth/generated calf cascades its pedigree node
and edges (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:1506-1514`), but it does not modify `geri_al`, add a birth-specific undo RPC, or define a birth snapshot. The current undo whitelist excludes `dogum` and `pedigree_nodes` (`supabase/migrations/20260830000033_geri_al_hardening.sql:31-45`), and the undo loop only processes `snapshot.olusturulan`/`snapshot.guncellenen` (`supabase/migrations/20260830000033_geri_al_hardening.sql:48-95`). The current `dogum` audit trigger stores the raw NEW row rather than an `olusturulan` envelope (`supabase/migrations/99999999999999_ground_truth.sql:2363-2365,8339-8342,8399-8400`). Calling `geri_al` on that log can skip deletion and still return `ok:true` (`supabase/migrations/20260830000033_geri_al_hardening.sql:133-134`). The stated undo test is therefore a silent-success path until the undo contract is explicitly integrated.

### F78 — [race-lifecycle] VERIFIED — catalog historical immutability has a check-then-use race

The catalog guard is specified as an `EXISTS` check over historical
`tohumlama.semen_id`/`semen_id_onceki` references followed by the update
(`.claude/plans/2026-09-10-pedigree-genetics-impl.md:499-507`). The only declared advisory transaction lock is on parentage mutation, not on catalog update/use (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:511-522`). A birth can resolve `semen_catalog.bull_node_id` and proceed toward its edge while a catalog update has already passed an uncommitted/no-reference check; the update can commit before the historical-use transaction, leaving the catalog's current sire different from the sire captured by the birth edge. No shared row lock or serialization contract covers this check-to-use window.

### F79 — [doc-drift] VERIFIED — the architecture spec still states the refuted BUG-001 premise

The current architecture banner and reproduction section still say that
`planli_tohumlama_kaydet` does not deduct stock (`.claude/specs/2026-09-10-pedigree-genetics-architecture.md:15-19,549-556`). D4 and BUGS.md now say the opposite: planli delegates and deduction occurs through delegation (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:106-120`; `BUGS.md:15-25`), while S1 itself labels the old lexical result misleading (`.claude/reviews/2026-09-10-live-probe-evidence.md:21-39`). The plan says its D4 decisions are authoritative, but the architecture document remains a competing input named as the plan's architectural authority (`.claude/plans/2026-09-10-pedigree-genetics-impl.md:3-7`). An implementer reading the required spec and plan can select either one-stock-deduction or no-deduction behavior.

## 3. VERDICT: FAIL

**FAIL — the documents are not ready to serve as implementation authority.**

The original SQL template, grants for new surfaces, code-universe list, cutoff
states, v1 migration boundary, response-shape correction for mating, and several
cache/hash repairs are materially improved. They do not close the authority
blockers:

- F62/F63 leave the birth bypass and operator metadata foundation unbound or
  undefined; F73 leaves the new graph-writing birth RPC callable by `anon`.
- F48/F44 remain heuristic, and F66/F67 show that the maternal/calf integrity
  path can produce a plausible but wrong lineage.
- F56/F65/F79 leave the only allowed live stock evidence and its repository
  consumers contradictory or not reproducible.
- F64/F70/F71/F72/F78 leave cache, twin-event, and catalog identity lifecycle
  races with conforming counterexamples.
- F68/F69/F75/F76/F77 show that the integrity, analysis, and undo acceptance
  contracts are not complete enough to implement or test deterministically.

These are implementation-authority failures, not missing polish. The required
verdict is therefore `FAIL`.

## 4. Confidence and unverified boundaries

Confidence is **high** for the static document contradictions and the F66-F79
counterexamples. F67 relies on PostgreSQL's documented NULL ordering semantics;
it is a static SQL-contract finding, not a live query execution. F56/F65/F79
are provenance findings; no live behavior was re-probed. No migration, SQL
fixture, frontend, browser, provider, deployment, or live DB state was
executed. Deployed privileges and current production behavior beyond S1-S8
remain **UNMEASURED**.

The review did not treat the missing human-reviewed semen mapping as a new
finding because the plan explicitly frames it as an expected preflight input;
the separate D4 reference to a missing committed bugfix report and the stale
goal/spec text are reported because they contradict the already-asserted stock
authority.

## 5. Verification evidence

```text
$ git merge --ff-only main
Updating 2917c6b..c2631d1
Fast-forward

$ git rev-parse HEAD && git branch --show-current
c2631d13073162a686ce0f2dcb304c120a081326
idle/pedigree-rev2-review-r12

$ /home/melik/tools-bank/scripts/ss-crumbs add --type gate ... --workspace pedigree-rev2-review-r12 --json
{"id":"50848aba750e","type":"gate","defect_class":"doc-drift", ...}

$ rg -n -i '(^|[^[:alnum:]])(ignore|system|assistant|directive|talimat|komut|previous instructions|forget instructions)([^[:alnum:]]|$)' \
    .claude/specs/2026-09-10-pedigree-genetics-architecture.md \
    .claude/plans/2026-09-10-pedigree-genetics-impl.md \
    .claude/reviews/2026-09-10-live-probe-evidence.md \
    .claude/reviews/2026-09-10-pedigree-rev2-r{2,3,4,5,6,7,8,9,10,11}.md \
    .harness/goals/2026/G-20260910-UREME-STOK-BUGFIX.md BUGS.md
# no actionable foreign instruction found

$ git diff --check
# no output

$ npm run test:unit
# not run: this is a documentation-only static review; no product code changed

$ git status --short --untracked-files=all
?? .ss/pedigree-rev2-review-r12-BOARD.md
?? .ss/pedigree-rev2-review-r12-crumbs.jsonl
?? .claude/reviews/2026-09-10-pedigree-rev2-r12.md
```

Only the requested report is a tracked repository delivery. The `.ss` board
and crumb are untracked worker process surfaces; they are not included in the
report commit. No product, migration, spec, plan, BUGS.md, evidence, or prior
review file was changed by this worker.
