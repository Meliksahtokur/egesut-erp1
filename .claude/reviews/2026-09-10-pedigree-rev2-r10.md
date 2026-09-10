# Pedigree Revision 2 Review — Round 10

## Review basis and incoming-work gate

The target post-round-9 material is reviewed at local `main@0dde147ce882436e475ff83b98f7207738305f03`, which contains the r9 report merge and the post-r9 document fix commit `51113c0`. This worker checkout remains at `2917c6b17ac1a06a2b1cecf892fa898992db55bd`; the task boundary forbids merge/rebase, so target files are read with `git show main:<path>`. The stale checkout is an environment limitation, not implementation evidence.

Incoming-work gate: **ACCEPT AND START**. The envelope is executable as a static spec/plan/repository review; the report path and `PASS|FAIL` verdict are measurable. Gate crumb: `ed80f479af80`.

No live DB, provider, browser, or migration execution was used. The S1-S8 file is the only source used for live claims. Prior reports and revision banners were treated as material to verify, not authority. No instruction-like injection text was found in the reviewed material.

Citation shorthand: `spec`, `plan`, `evidence`, and `repo` below refer to the corresponding files at the review-basis `main` tree unless a different path is stated.

## 1. Round-9 finding resolution

`RESOLVED` means the original mechanism is coherent at the document-contract level; it does not claim that migrations, frontend code, or deployment exist. `PARTIAL` means the named fix is present but a material contract residual remains.

| Finding | Status | Evidence and resolution judgement |
|---|---|---|
| F45 | **RESOLVED** | The owner SQL template now places `::text` inside the third `VALUES` expression and has balanced parentheses (`plan:699-710`). The original syntax failure is closed statically; it was not executed against a database in this review. |
| F46 | **RESOLVED** | The current cache policy names `globalThis.__pedigreeSessionGen` in the write rule, and the shared-counter section explicitly forbids a module-level `let` (`plan:882-905`). The incompatible earlier reader binding from r9 is gone from the current plan. |
| F47 | **RESOLVED** | The declared `pedigree_cache` row shape now includes `epoch` (`plan:832-842`), and the read/write quarantine uses that same field (`plan:907-915`). The original row-contract omission is closed. |
| F48 | **PARTIAL** | The three added controls now have predicates, keys/details, and some NULL behavior (`plan:658-680`). However, `dogum_anne_graph_dam_celiskisi` still says only “the calf node of the birth row” and never defines the join from the live `dogum` shape to that node; S8 lists `dogum.id`, `anne_id`, `tarih`, and `yavru_kupe` but no calf-node foreign key (`evidence:123-128`). The parent-date source for farm nodes is likewise not made into one executable expression. The original names-only omission is improved, but the detection contract is not fully reproducible. |
| F49 | **RESOLVED** | Task 2.3 and the rollout row now use one G2 rule: no emitted blocker items and every warning/info item must be `accepted` with `stale_disposition=false` (`plan:682-689,2030-2037`). The original stale-acceptance wording split is removed; F53 below is a separate emission-shape gap. |
| F50 | **RESOLVED** | The current plan uses the single machine value `tanimsiz` for a missing cutoff in the preamble, JSON shape, state rule, and G2 note (`plan:600-604,620-640,718-720`). No `tanımsız` spelling remains in the current spec/plan. |
| F33 residual | **RESOLVED at the original acceptance-binding level** | The plan now defines an immutable finding hash, owner SQL storage, current-detail equality, and stale-on-change behavior (`plan:691-716`); the formerly invalid template is fixed (`plan:699-710`). Output-cardinality omissions remain fresh F53, not the original absence of a hash/write path. |
| F36 residual | **RESOLVED at the original cutoff/G2 representation level** | Missing and invalid cutoff states, `cutoff_invalid`, and the exact G2 predicate are represented consistently (`plan:600-604,644-689,718-720,2034-2037`). F53 still prevents the complete report contract from being implementation-ready. |
| F37 residual | **RESOLVED at the original owner-decision mechanism level** | The client acceptance RPC/grant is removed; the owner SQL template and hash-based stale decision are present (`plan:691-716`). The template is syntactically valid now. |
| F39 residual | **PARTIAL** | Epoch quarantine and generation fencing are now stated (`plan:832-842,898-915`), but the plan does not require generation/epoch rotation to occur before the asynchronous IDB clear begins. A pending response can therefore still pass a conforming but incorrectly ordered clear implementation; see F54. |
| F40 | **RESOLVED at the original machine-state level** | The item carries `stale_disposition`, missing cutoff suppresses the post-cutoff group, invalid cutoff emits a blocker, and G2 includes the non-stale condition (`plan:620-689,718-720`). F53 identifies the remaining count/item emission gap separately. |
| F41 | **RESOLVED** | The buildless script split is addressed with one shared `globalThis.__pedigreeSessionGen`; the clear path increments that exact binding and module-local counters are forbidden (`plan:898-905`). |
| F42 | **RESOLVED at the original row-quarantine level** | The epoch is part of the row schema and all reads, including network fallback, must compare it with the current epoch; the rejected-clear scenario is stated (`plan:832-842,907-915`). F54 is a new ordering residual. |
| F43 | **RESOLVED at the original acceptance-RPC surface** | `pedigree_accept_finding` and its broad authenticated grant are explicitly absent; acceptance is owner SQL plus an internal hash helper (`plan:691-716`, with the grant inventory at `plan:403-408`). F51 below concerns unrelated read grants that reopen anonymous access. |
| F44 | **PARTIAL** | The three control codes are now in the severity matrix and have a first predicate contract (`plan:644-680`), but the earlier “groups returned” list remains a competing, incomplete list (`plan:606-618`); see F52. The unresolved child-node join in the F48 resolution also prevents a fully executable reconciliation contract. |
| N17 documented residual | **PARTIAL — documented and intentional v1 residual** | v1 still stores only one predecessor in `semen_id_onceki`, preserves the overwritten ID in an operation-log snapshot, and defers complete per-attempt semen identity history to v2 (`spec:305-326,1355-1371`; `plan:1223-1227`). This is an explicit scope limitation, not a claim that full history is delivered. |

## 2. Fresh hunt

### F51 — [scope-violation] VERIFIED — v1 grant list reopens anonymous access after the repository auth gate

The planned foundation explicitly grants `semen_catalog` `SELECT` to `anon` (`plan:383-400`) and grants the projection, profile, and mating read RPCs to `anon` (`plan:403-423`). The tracked auth gate says unauthenticated `anon` has no table/RPC/sequence access and that only `authenticated` receives the explicit grants (`supabase/migrations/20260614000007_auth_gate_lockdown.sql:2-21`). The current app also blocks initialization without a session (`js/auth.js:248-259`). A migration following the plan therefore makes graph/semen data callable before login, with no demo-only scope or compensating revoke in the plan. That contradicts the active login gate and the plan’s own statement that access boundaries are established by explicit DDL (`plan:375-381`).

### F52 — [doc-drift] VERIFIED — Task 2.3 still has two control universes

The first “groups” list omits `cutoff_invalid`, `legacy_anne_graph_dam_celiskisi`, `dogum_anne_graph_dam_celiskisi`, and `suspiciously_young_parent` (`plan:606-618`). The later severity matrix includes all four (`plan:644-655`), while the text claims that the group-code list is one-to-one with the controls in the section (`plan:634-635`). An implementer can consequently emit the matrix union or the earlier list and still point to a seemingly authoritative paragraph; G2 and owner acceptance then observe different group sets. This also keeps F44 partial.

### F53 — [unmeasured-claim] VERIFIED — blocker counts are not mapped to the item contract

`post_cutoff_null_semen` is described as a count (`plan:618`), but every group item is required to have `key`, `detail`, `disposition`, and `stale_disposition` (`plan:620-631,682-684`). The plan never says whether a zero count omits the blocker group or emits a zero-count item. Emitting `{count:0}` as one blocker item makes the G2 rule fail because G2 counts blocker items, while omitting it relies on an unstated special case (`plan:647-689`). Conversely, invalid cutoff is said to emit one blocker item (`plan:685-687`) without defining its key/detail. The report cannot therefore be reproduced or tested from the stated JSON contract, even though F49’s boolean G2 wording is now single.

### F54 — [race-lifecycle] VERIFIED — the cache fence is not ordered before asynchronous cleanup

The plan makes cleanup fail-open and asynchronous, then separately says that the generation is incremented and the epoch replaced “in every case” (`plan:893-915`). It does not require those invalidation markers to change before `idbClearStore` is awaited. An implementation that starts the IDB clear first lets a pending network response observe the old generation and write while cleanup is in flight; if the clear rejects, that row can remain until the later marker update. The acceptance sentence requires that the pending response not write (`plan:913-915`) but does not specify the ordering/barrier that makes this deterministic. The old F39/F42 mechanism is therefore not a complete implementation authority until marker rotation is explicitly first (or the operation is otherwise serialized).

### F55 — [doc-drift] VERIFIED — Task 17 offers a v2 metrics migration for a v1 delivery

Task 14 explicitly labels `20260910000007_pedigree_metrics_foundation.sql` as v2 and says it must not be created in v1 (`plan:1495-1507`). Task 17 nevertheless says its v1 profile/kinship/inbreeding functions may be created or updated in “the metrics migration or” `20260910000008_mating_analyze.sql` (`plan:1602-1604`). The final order separately classifies `000007` as v2 and `000008` as v1 (`plan:1936-1950`). A worker following the first Task 17 option can put required v1 RPCs into the explicitly forbidden v2 migration; the plan must choose the v1 migration unambiguously.

### F56 — [unmeasured-claim] VERIFIED — D4 treats a function-body probe as proof that the planned path has no stock deduction

D4 calls it live truth that `planli_tohumlama_kaydet` “does not deduct” (`plan:106-109`). S1’s query only tests whether the literal string `stok_hareket` occurs in that function’s own `pg_get_functiondef`, and its conclusion repeats that narrow observation (`evidence:8-31`). The tracked production migration shows the planned function delegating to `public.tohumlama_kaydet` (`supabase/migrations/20260730000001_sablon_tohumlama_opsiyonel_ve_yasam_dongusu.sql:477-496`), while that same source contains the stock insert in `tohumlama_kaydet` (`:433-439`). This does not prove what is currently deployed—the evidence file remains the live authority—but it proves the plan’s probe is not a call-graph or behavioral measurement. If the delegation remains, adding an independent planli deduction double-charges stock; if live drift removed it, that must be behaviorally remeasured before Task 10. D4 cannot safely freeze the three-path write contract from the current evidence.

### F57 — [silent-success] VERIFIED — catalog upsert can silently rewrite historical sire identity

`semen_catalog.bull_node_id` is the authoritative semen-to-sire relationship (`spec:451-452`), and the upsert contract accepts an existing `p_id` plus a new `p_bull_node_id` without an “already used” immutability guard or audit rule (`plan:456-464`). If a catalog row referenced by historical `tohumlama.semen_id` is reassigned from Armada to Fresco, future resolution of those historical rows yields Fresco while already-created birth edges still point at Armada. The documents therefore permit split-brain history after a successful update. The column-delete behavior is also not one authority: the spec’s `REFERENCES` has the default action (`spec:305-313`), while the plan specifies `ON DELETE SET NULL` (`plan:1126-1133`). A used catalog row needs an explicit immutable/replacement model and one deletion contract before it can be authoritative.

### F58 — [scope-violation] VERIFIED — “admin-level” parent correction has no authorization gate

The parent mutation is granted to every `authenticated` caller (`plan:397-400`), and `p_replace=true` is the documented way to replace an existing canonical parent (`plan:474-485`). Task 13 calls the UI “admin-level” but specifies no role, owner identity, or RPC authorization check (`plan:1458-1477`); the current auth surface permits arbitrary signup (`js/auth.js:62-84`). Any registered account can therefore invoke the same canonical lineage replacement that changes downstream pedigree metrics. A UI label or confirmation is not an authorization contract.

### F59 — [scope-violation] VERIFIED — analysis depth limits are not executable for all exposed endpoints

Projection has concrete negative and maximum-depth guards (`plan:760-766`), but the relationship/profile APIs expose caller-supplied depth without a concrete bound or negative-input rule (`plan:1551-1556,1602-1628`). The only analysis wording is “max depth guard e.g. 8,” which is not a value or a rule covering `pedigree_profile`, `pedigree_kinship`, and `pedigree_inbreeding`; those functions are also granted to authenticated callers (`plan:417-421`). An extreme depth can trigger an unnecessarily large recursive closure or an unbounded request path. The plan must specify one finite, non-negative bound and enforce it in every exposed analysis RPC.

### F60 — [doc-drift] VERIFIED — mating completeness has incompatible response shapes

The spec’s `mating_analyze` example returns one scalar `pedigree_completeness` (`spec:643-679`), while the implementation plan requires separate `completeness cow/bull/combined` values (`plan:1602-1626`) but gives no JSON field names or object shape. A consumer or fixture following the spec cannot know how to consume the planned three-value result, and a worker following the plan can return a shape that violates the only concrete spec example. The plan needs an explicit override and exact response schema.

### F61 — [unmeasured-claim] VERIFIED — young-parent control classifies future-born parents as merely young

The new predicate emits `suspiciously_young_parent` whenever `(child_tarih - parent_tarih) < 548` (`plan:674-679`), with no `>= 0` condition. A parent born after the child therefore produces a negative “age” detail and also matches the separate `parent_born_after_child` control (`plan:649-650`). The same chronology error can be reported under two different warning codes, and the younger-parent detail is false in meaning; the young-parent predicate must exclude future-born parents and leave that case to the chronology anomaly.

F48’s unresolved join details are retained as a resolution residual rather than duplicated as a fresh ID. No additional runtime or live findings are asserted.

## 3. VERDICT: FAIL

The documents are **not ready to serve as implementation authority**.

The direct F45, F46, F47, F49, and F50 repairs are present, and the original owner/hash, cutoff, and generation/epoch mechanisms are materially improved. However, F48 and F44 remain partial; F51 reopens unauthenticated read access; F52-F53 leave the integrity report and G2 input non-deterministic; F54 leaves the cache lifecycle race dependent on an unstated ordering; F55 makes a v1 delivery path conflict with its v2 boundary; F56 shows that the D4 stock-path premise is not established by the sole live evidence; and F57-F61 leave historical identity, mutation authorization, resource bounds, response shape, and anomaly classification underspecified or unsafe. These are independent blockers to a reproducible implementation and rollout gate.

## 4. Confidence and unverified boundaries

Confidence is **high** for the static document contradictions, missing contracts, grant conflict, catalog reassignment path, authorization omission, response-shape drift, and anomaly predicate. F54 is a contract-level race counterexample, not a claim that cache code already exists. F56 deliberately does not promote tracked migration text to live-schema proof. The worker branch was 18 commits behind local `main`; all post-r9 target material was read from `main@0dde147`. No live DB, provider, browser, migration, or frontend implementation was exercised; deployed privileges, runtime cache ordering, and current production call behavior remain **UNMEASURED** beyond S1-S8.

## 5. Verification evidence

```text
$ git rev-parse HEAD
2917c6b17ac1a06a2b1cecf892fa898992db55bd

$ git rev-parse main
0dde147ce882436e475ff83b98f7207738305f03

$ git rev-list --left-right --count HEAD...main
0 18

$ git cat-file -e main:.claude/tasks/2026-09-10-pedigree-rev2-review-r10.md
# exit 0

$ git cat-file -e main:.claude/reviews/2026-09-10-pedigree-rev2-r9.md
# exit 0

$ git show main:.claude/plans/2026-09-10-pedigree-genetics-impl.md | nl -ba | sed -n '600,720p;832,915p;1495,1507p;1602,1604p;2030,2037p'
# output contains the current cutoff, predicate, epoch/generation, migration-boundary, and G2 lines cited above

$ git show main:.claude/plans/2026-09-10-pedigree-genetics-impl.md | nl -ba | sed -n '606,618p;634,655p'
# output shows the incomplete first group list and the larger severity matrix

$ git show main:.claude/plans/2026-09-10-pedigree-genetics-impl.md | nl -ba | sed -n '1458,1477p;1551,1628p'
# output contains the parent-edit authorization gap and incomplete analysis-depth contract

$ git show main:.claude/specs/2026-09-10-pedigree-genetics-architecture.md | nl -ba | sed -n '305,313p;643,679p;1355,1371p'
# output contains the semen delete/reference and scalar mating-completeness contracts

$ git show main:supabase/migrations/20260614000007_auth_gate_lockdown.sql | nl -ba | sed -n '2,21p'
# output shows anon revocation and authenticated-only grants in the tracked auth gate

$ git show main:supabase/migrations/20260730000001_sablon_tohumlama_opsiyonel_ve_yasam_dongusu.sql | nl -ba | sed -n '433,439p;477,496p'
# output shows the stock insert in tohumlama_kaydet and planli's delegation

$ git status --short --untracked-files=all
# clean before this review's report and role-process surfaces were created
```

Only the requested r10 report is committed on this worker branch. The `.ss/`
board and crumb are role-process surfaces and are not included in the report
commit. No product, migration, spec, plan, BUGS, evidence, or prior-review file
was changed.
