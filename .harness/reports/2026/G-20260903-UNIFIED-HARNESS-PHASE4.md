# Phase 4 Implementation Report

Goal: `G-20260903-UNIFIED-HARNESS-PHASE4`

Date: 2026-09-03

Flow: `zcode_builtin`

Root verdict: `IN_PROGRESS`

## 1. Launch baseline

```text
main/worktree launch SHA: 9f34fe1c45bed6eb1f7712247839321ed7db910d
branch: idle/unified-agent-harness-phase4
worktree: /home/melik/egesut-wt/unified-agent-harness-phase4
manifest: eighteen exact paths (goal, report, five patterns, three references, shared contract, harness CLI, docs-update contract, README, three harness test files)
main status: 2 tracked modifications + 43 collapsed untracked entries = 45
main status fingerprint: 6249c018b06ccf9ad31fb7107b6ab0f40a7323024b1142eff32de125f4d2230f
protected main files and existing pre-commit hook: unchanged
core.hooksPath: unset
GitNexus: current at 9f34fe1
harness validate at launch: PASS, three goals, zero findings
```

## 2. Scope and evidence policy

Phase 4 delivers the pattern catalog, source-symbol UI map, curated RPC and
domain references, product-routing corrections deferred from the Phase 3
review, the surface-name mapping, and pattern_ref goal enforcement. Each
acceptance criterion receives `PASS`, `PARTIAL`, `FAIL`, or `INCONCLUSIVE`.
New enforcement requires behavior-changing red-before evidence.

GitHub E2E is excluded. Product code, live DB, deploy, hooks, legacy agent
surfaces, and main user state are out of scope. The pattern and reference
content is derived from current production symbols by read-only inventory.

## 3. Current state

The candidate is complete and measured at the pre-review checkpoint: five
patterns, three references, both routing corrections, pattern_ref
enforcement, the surface-name mapping, and three test files. Sections 4-8
record the evidence.

## 4. Implemented content

- `.harness/patterns/`: `index.yaml` (five flat ids) plus MODAL-ROUTER-01
  (router core in `js/utils/`, DOM-property onclick ban, legitimate
  non-router onclick section), FORM-SUBMIT-01 (canonical chain around
  `submitKizginlik`), RPC-WRITE-01 (wrapper stack, `RPC_TABLES`/`RPC_MAP`
  consistency), OFFLINE-SYNC-01 (write/pull/queue contracts, new-table
  recipe), TESTING-01 (loader, placement rules, read-only E2E discipline).
- `.harness/references/ui-map.md`: symbol-keyed map (no line numbers) with
  the full 33-modal router table, per-file symbol tables, dead-surface
  notes, and non-router overlay classification.
- `.harness/references/domain-rules.md` and `rpc-reference.md`: curated from
  the owner's `.claude` working copies (2026-09-01 revision plus the pending
  2026-09-02 additions) with explicit provenance headers; rpc-reference
  gains the 2026-09-03 audit notes (wrapper stack, measured ~144 call sites
  / 113 unique functions, `RPC_TABLES` gaps, edge-function classification).
- `harness.py`: product routing (`js/state.js`, `js/config.js` ->
  ui_map; `supabase/functions/**` -> domain_rules + deploy_boundary),
  pattern index loading, and `pattern_refs`/`pattern_exceptions` goal
  validation with `pattern_count` in `validate`.
- `docs-update.md`: required-surface name to owning document mapping
  (Phase 3 review finding 7). `README.md`: Phase 4 paragraph.

Product-test coverage measured rather than duplicated: modal/router
(tests/modal-router.spec.js, tests/unit/modal.test.js), form/RPC
(tests/unit/forms-validation.test.js, buildRpcParams.test.js, api.test.js),
and offline replay (tests/offline-kuyruk.spec.js, api.test.js syncNow
coverage) already exist; Phase 4 adds the pattern/reference consistency
checks instead of duplicating product-owned suites.

## 5. Red-before evidence

Enforcement corrections were written test-first and observed failing:

1. routing tests for `js/state.js`/`js/config.js` and
   `supabase/functions/**` failed against the Phase 3 routing table;
2. `MISSING_PATTERN_REF`, `INVALID_PATTERN_REF`, and `UNKNOWN_PATTERN_REF`
   assertions failed before the goal-validation change;
3. pattern-content tests errored on the absent catalog before the documents
   existed.

The anchor drift check proved itself during development: it caught a
misfiled opener (`dogumYaptiAc`/`ikinciYavruAc` live in `js/ui.js`, not
`js/forms.js`) and two resolver gaps (class methods like `setBatch`,
markup-only handlers like `ekChipSec`), all corrected before this report.

## 6. Pre-review acceptance

```text
manifest vs real status: PASS, exactly 17 paths
harness suite: 83/83 PASS (64 prior + 19 new: 2 routing, 10 pattern, 7 reference)
product unit suite: 440/440 PASS
harness validate: PASS, four goals, five patterns, zero decisions, zero findings
pattern anchors resolved against current code: all (patterns + ui-map)
main/origin-main: 9f34fe1 unchanged since launch
main user-state fingerprint and protected hashes: unchanged
core.hooksPath: unset; no hook, product, DB, or legacy-surface write
```

## 7. Criterion verdicts

| Criterion | Verdict |
|---|---|
| Patterns cite real current symbols; drift detectable | `PASS` |
| UI map symbol-keyed, router surface covered, checkable | `PASS` |
| RPC/domain curated with provenance; live schema stays authority | `PASS` |
| Routing gaps closed with red-before | `PASS` |
| pattern_refs/pattern_exceptions enforcement | `PASS` |
| Surface-name mapping documented | `PASS` |
| Legitimate non-router onclick documented and existing | `PASS` |
| Product code, DB, hooks, legacy surfaces, main state untouched | `PASS` (out of scope, verified) |

## 8. Residual boundaries

- `RPC_TABLES` gaps and the orphaned `stat-hesapla` edge function are
  recorded product follow-ups; fixing them edits product code outside this
  goal.
- Dead modal surface (`mClose`, `#m-gebelik`, `m-tohum-ertele`) is recorded
  in the ui map as do-not-imitate; removal is a product cleanup decision.
- Live-schema verification of the RPC reference is deferred to the planned
  DB/RPC pilot, which owns separately authorized schema evidence.
- The `.claude` transitional references remain owner-owned dirty copies;
  Phase 6 owns their retirement. The curated copies incorporate the owner's
  pending 2026-09-02 working-copy additions (4 + 5 lines, listed in the
  Phase 3 handoff diff) so no uncommitted knowledge is lost.
- `js/ai-asistan.js` ui-map coverage is partial (plan-management symbols
  only); the streaming surface belongs to the AI assistant workstream.

## 9. Pre-review docs checkpoint

Checkpoint: `pre-review`, sequence `1`

| Surface | Outcome |
|---|---|
| Phase 4 goal and report | `UPDATED` |
| Pattern catalog and references | `UPDATED` |
| Harness CLI routing and validation | `UPDATED` |
| Docs-update contract surface mapping | `UPDATED` |
| Harness tests | `UPDATED` |
| Shared contract, acceptance, runtime adapters | `NO_CHANGE_REQUIRED` |
| Product/domain documents (transitional `.claude`) | `OUT_OF_SCOPE` — propose_only, Phase 6 |
| Durable memory promotion | `NO_CHANGE_REQUIRED` |

Docs verdict: `PASS` (engine surfaces complete; the OUT_OF_SCOPE row records
goal authority scope, matching the Phase 2/3 precedent).

## 10. Independent review

An independent read-only reviewer agent verified the candidate adversarially:
re-measured the manifest (exactly 18 paths after the corrections below),
reran the harness suite (83/83), the product unit suite (440/440), and
`harness validate` (4 goals, 5 patterns, 0 findings), replayed the red-before
claims against the Phase 3 harness from Git (all four enforcement gaps
reproduce), independently re-resolved every pattern/ui-map anchor with a
stricter comment-stripping checker, verified the modal-router claims in
code, spot-checked the RPC wrapper contract and `RPC_TABLES` membership, and
confirmed the curation disclosure (the owner's uncommitted `.claude`
additions are 4+5 lines, incorporated verbatim with matching headers).

Reviewer verdict: `PASS` — accept into main.

Findings and root adjudication:

| # | Severity | Finding | Disposition |
|---|---|---|---|
| 1 | MINOR | audit notes wrongly listed `vaka_tohumlama_ekle` among `RPC_TABLES` gaps (it is registered, api.js:374) | FIXED before integration; the correction itself is recorded in the audit notes |
| 2 | MINOR | per-file call-site counts did not reproduce (unique-name vs call-site mixing) | FIXED — reworded to tolerant totals with an explicit drift caveat |
| 3 | MINOR | `pattern_exceptions` attestation semantics absent from tracked contract surfaces | FIXED — `contract.md` Pattern reuse section now states the requirement and attestation semantics; manifest grown to 18 paths for it |
| 4 | NOTE | `symbol_defined` accepts comment-only matches; `ekChipSec` anchor resolves to a usage site | recorded — the checker's purpose is drift detection, not adversarial proof; ui-map now documents that markup anchors may resolve to sanctioned usage sites |
| 5 | NOTE | inherited 2026-09-01 line numbers in the historical rpc-reference section are stale | recorded — disclosed by the provenance header; Phase 4 audit notes avoid line numbers |

## 11. Pre-commit checkpoint

Checkpoint: `pre-commit`, sequence `2`

Staged review evidence, produced after staging exactly the eighteen manifest
paths:

```text
staged names: 5 M + 13 A, exactly the manifest set, no other path staged
staged stat: 18 files changed, 2077 insertions(+), 7 deletions(-)
git diff --cached --check: clean
unstaged/untracked leftovers outside the manifest: none
GitNexus staged detection: 18 changed files, 0 changed symbols, risk low,
  no affected processes (governance docs and unindexed harness Python only)
harness suite: 83/83 PASS
product unit suite: 440/440 PASS
harness validate: PASS, four goals, five patterns, zero findings
pre-review receipt (scope all, 18 paths): PASS, then superseded by the
  staged receipt below
```

Pre-commit docs evaluation:

| Surface | Outcome |
|---|---|
| Tests (harness 83/83, product unit 440/440) | `UPDATED` |
| Pattern catalog, ui-map, RPC/domain references | `UPDATED` |
| Harness contract pattern-exception semantics | `UPDATED` |
| Harness CLI routing/validation and tests | `UPDATED` |
| Phase 4 goal and report | `UPDATED` |
| Generated views | `NO_CHANGE_REQUIRED` |

Docs verdict: `PASS`.

The local Phase 4 commit follows this checkpoint; merge, main fast-forward,
GitNexus refresh, and push remain separately gated.
