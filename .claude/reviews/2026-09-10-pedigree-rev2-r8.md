# Pedigree Revision 2 Review — Round 8

## Review basis and incoming-work gate

The target post-round-7 material is `main@72bdee5673951f5f1e1b3305446d7bf0c47f8aa1`.
This worker branch is still at `2917c6b17ac1a06a2b1cecf892fa898992db55bd`;
the task boundary forbids a merge, so the current spec, plan, r7 report, and
r8 envelope were read from `git show main:<path>` and the report is committed
only on this worker branch. The current `main` contains the r7 report merge
(`72bdee5`) and the post-r7 document fix commit (`a675b73`).

Incoming-work gate: **ACCEPT AND START**. The review is executable as a static
spec/plan/repository review and the report path and verdict are measurable.
Gate crumb: `496a10c716f9`.

No live DB access was used. The S1-S8 evidence file is the only source for live
claims; it is treated as point-in-time evidence, not as a substitute for a new
probe. Prior reports and revision banners were treated as material to verify,
not as authority. No instruction-like injection text was found in the reviewed
material.

## 1. Round-7 finding resolution

Statuses are judged from the current artifacts, not from the revision summary.
`RESOLVED` means the original document-level mechanism is now coherent; it
does not claim that the planned migrations or frontend implementation exist.
`PARTIAL` means the original omission is materially improved but a contract,
authority, or lifecycle residual still prevents implementation authority.

| Finding | Status | Current evidence and residual |
|---|---|---|
| F33 residual | **PARTIAL** | The plan now supplies a severity matrix, `disposition`, an acceptance key/value shape, a dedicated `pedigree_accept_finding` RPC, an MD5 finding hash, and an acceptance/detail-change fixture (`plan:642-663`). The residual is that the RPC accepts only `p_code`, `p_key`, and `p_note` (`plan:652-657`), while the hash requires the current item's `detail`; no atomic current-report lookup or caller-hash contract is stated. The response schema also omits the later-required `stale_disposition` field (`plan:618-629,660`). Owner authorization is a separate unresolved issue (F43). |
| F35 | **RESOLVED at the original document-contradiction level** | The spec now explicitly makes plan Task 2.3 the sole authority for the control universe, severity matrix, JSON shape, and acceptance mechanism, and says its former list is retired (`spec:1139-1150`). There is no longer a second spec list to conflict with the plan. The selected universe still has a coverage gap reported as F44. |
| F36 | **PARTIAL** | The post-r7 prose distinguishes missing cutoff (`tanimsiz`/`not_applicable`), invalid cutoff (`gecersiz`/blocker), and valid cutoff measurement (`plan:665-668`). However, the declared item vocabulary is only `open|accepted` (`plan:623-629`), the invalid path skips the NULL counter (`plan:634-640`), and the exact group list has no `cutoff_invalid` control (`plan:642-649`). G2 still says only `blocker=0` plus accepted warning/info (`plan:1960-1967`). It is therefore unclear how the invalid-cutoff blocker or missing-cutoff `not_applicable` state enters the machine-readable gate; see F40. |
| F37 | **PARTIAL** | A named RPC, stored JSON value, `finding_hash`, stale-on-detail-change behavior, and two-step SQL fixture are now present (`plan:652-663`). The mechanism is not fully executable/freshness-bound: the RPC contract does not state whether it re-reads the current report detail atomically or receives a hash from the caller, `stale_disposition` is absent from the response contract, and the only privilege rule is a grant to `authenticated` (`plan:652-655`). See F40 and F43. |
| F38 | **PARTIAL** | The plan now requires a request-generation check before cache write and increments the generation on every cache clear (`plan:829-833,839-845`). The counter is described as module-level in `pedigree-api.js`, while the clear function is a top-level global in `api.js`; the buildless app loads separate classic scripts (`index.html:2214-2228`), and the repository's test loader explicitly records that top-level `let`/`const` lexical bindings are not shared between scripts (`tests/unit/support/loadModule.js:10-12`). No shared global/bridge/export is specified, so the guard can still be disconnected; see F41. |
| F39 | **PARTIAL** | The original blocking failure is addressed at the control-flow level: clear is fail-open and auth paths are required to use `try/finally` (`plan:839-845`). That choice also allows logout/reload to succeed while an IDB clear failed, leaving old rows available to a later cache read; the stated cache-isolation guarantee is not preserved. See F42. |
| N17 | **PARTIAL — documented residual** | The design still keeps only one previous canonical semen ID plus an `islem_log` snapshot (`spec:305-324`; `plan:1153-1157`) and explicitly defers complete per-attempt history to v2 (`spec:1368-1371`). This is an acknowledged v1 limitation, not a new r8 defect. |

## 2. Fresh hunt

The findings below are static document/source findings. `VERIFIED` means the
failure follows from the current artifacts and does not require a live probe.

### Accuracy

**F44 — [unmeasured-claim] VERIFIED — The post-r7 “single control universe” silently drops previously named reconciliation checks.**

The spec now says the plan's Task 2.3 list is complete and authoritative
(`spec:1139-1146`). That exact list and matrix (`plan:606-616,632,642-649`)
contain no control for `hayvanlar.anne_id`/graph-dam mismatch,
`dogum.anne_id`/graph-dam mismatch, or `suspiciously_young_parent`. The
architecture therefore resolves the former F35 contradiction by retiring its
spec list, but does not record an explicit non-goal or replacement for those
checks. A child whose legacy dam points to A while the canonical graph points
to B can have a resolved `anne_id`, one graph dam, no cycle/sex/date issue, and
still produce no listed integrity finding; G2 can then pass. The same blind
spot applies to a suspiciously young parent. This is a correctness/reconciliation
gap, not merely a naming difference.

### Implementability and contradiction

**F40 — [doc-drift] VERIFIED — G2-relevant statuses are required by prose but absent from the declared report contract.**

The JSON contract permits only `disposition: open|accepted`
(`plan:618-629`). The r8 additions require `stale_disposition: true` when a
hash is stale (`plan:657-661`) and call the missing-cutoff control
`not_applicable` while calling an invalid cutoff a blocker
(`plan:665-668`). Neither state has a declared field/value in the JSON shape;
the exact control matrix has no `cutoff_invalid` item (`plan:642-649`). The
invalid path also says to skip the NULL counter (`plan:634-640`). An
implementation that omits the control makes `blocker=0` and can open G2; an
implementation that adds an unlisted blocker or a third disposition violates
the stated exact contract. Different executors can therefore make different
G2 decisions from the same cutoff state. This leaves F36 and F37 materially
open.

**F41 — [race-lifecycle] VERIFIED — The generation guard has no shared binding across the buildless script split.**

The cache writer is in the dedicated `pedigree-api.js` surface and reads a
module-level `pedigreeSessionGen`, while `clearPedigreeCacheStore()` is
specified as a top-level function in `api.js` that must increment it
(`plan:807-815,829-845`). The production page loads `api.js`, `auth.js`, and
future pedigree scripts as separate non-module `<script>` tags
(`index.html:2214-2228`). A literal `let pedigreeSessionGen` in
`pedigree-api.js` is not addressable by `api.js`; a second counter in `api.js`
would not be the counter read by the writer. Without a named `globalThis`
state or a shared bump function, a pending response can pass the writer's
counter check after logout and repopulate the next session's cache. The
generation prose alone does not close F38.

**F42 — [race-lifecycle] VERIFIED — Fail-open cache cleanup can preserve stale data while satisfying the logout test.**

The cache key is farm-scoped (`plan:780-789`), successful network calls fall
back to a matching cached payload (`plan:829-835`), and clear errors are
explicitly swallowed so logout/reload continues (`plan:839-845`). If a
transaction rejects after a previous payload is already stored, the page
reloads with that payload still present. A later session, especially during an
offline interval, can then receive the old row from the fallback path. The
generation increment blocks pending writes but does not remove existing rows;
no session-scoped key, read quarantine, or retry/delete fallback is specified.
Thus F39's availability fix can violate the stated “completely clear on exit”
and cross-context cache-isolation guarantee.

### Authority / security gap

**F43 — [scope-violation] VERIFIED — The owner acceptance RPC is granted to every authenticated account.**

The acceptance mechanism is described as an owner decision and “v1 single
user,” but its only access rule is `GRANT EXECUTE ... TO authenticated`
(`plan:652-655`; the general SECURITY DEFINER rule is `plan:426-430`). The
current auth surface exposes a signup path for arbitrary accounts
(`js/auth.js:62-84`), and no `auth.uid()` allow-list, owner identity, or
owner-only role check is specified for `pedigree_accept_finding`. Any
authenticated signup account that can call the RPC can write an accepted
finding and influence G2. “Single user” is an unstated deployment assumption,
not an enforced acceptance authority.

## 3. VERDICT: FAIL

The documents are **not ready to serve as implementation authority**.

F35's original list-vs-plan contradiction is closed, and the r7 fixes
materially improve the acceptance record, cutoff prose, generation guard, and
logout error handling. They do not close the authority:

- F40 leaves G2 without one machine-readable interpretation for
  `not_applicable`, invalid-cutoff blocker, or stale acceptance;
- F41 means the stated F38 generation guard can be unwired in the actual
  buildless browser;
- F42 permits a successful logout/reload while stale cache data survives;
- F43 does not make the claimed owner acceptance owner-only; and
- F44 leaves material legacy-vs-canonical dam and parent-age anomalies outside
  the sole integrity control universe.

F33, F36, F37, and F39 therefore remain partial rather than resolved. N17 is
still an explicit one-step v1 residual. These are independent blockers to a
reproducible implementation and rollout gate, so the verdict is FAIL.

## 4. Confidence and unverified boundaries

Confidence is **high** for the static resolution statuses and F40-F44. The
post-r7 spec/plan, r7 report, r8 envelope, S1-S8 evidence, `BUGS.md`, current
buildless `index.html`/auth source, test loader, and tracked migration material
were checked locally against `main@72bdee5`. F42 is a contract-level lifecycle
counterexample rather than a claim that an implementation already exists.

No live DB, provider, browser, or migration execution was performed. The
evidence file remains the only live-claim source, and no pedigree migration or
frontend implementation exists in the reviewed tree. Consequently, runtime
behavior, deployed privileges, and live acceptance are **UNMEASURED** here.

## 5. Verification evidence

```text
$ git rev-parse HEAD^  # pre-commit review basis
2917c6b17ac1a06a2b1cecf892fa898992db55bd

$ git rev-parse main
72bdee5673951f5f1e1b3305446d7bf0c47f8aa1

$ git cat-file -e main:.claude/tasks/2026-09-10-pedigree-rev2-review-r8.md
# exit 0

$ git show --format= --name-status a675b73
M	.claude/plans/2026-09-10-pedigree-genetics-impl.md
M	.claude/specs/2026-09-10-pedigree-genetics-architecture.md
A	.claude/tasks/2026-09-10-pedigree-rev2-review-r8.md

$ git ls-tree -r --name-only main | rg '(^|/)(pedigree|semen|genetic)' | head
.claude/plans/2026-09-10-pedigree-genetics-impl.md
.claude/specs/2026-09-10-pedigree-genetics-architecture.md

$ git diff --cached --check
# exit 0, no output

$ git diff-tree --no-commit-id --name-status -r HEAD
A	.claude/reviews/2026-09-10-pedigree-rev2-r8.md

$ git diff HEAD^ HEAD --check
# exit 0, no output
```

Only the requested report was staged for the worker commit. The `.ss/` board
and crumb file are role-process surfaces required by the worker contract and
are not part of the report commit.
