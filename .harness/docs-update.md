# Documentation Update Contract

Contract version: `1`

Docs-update is a deterministic checkpoint evaluation. It answers which
documentation surfaces were considered, whether the evidence was current, and
whether the evaluator stayed inside its authority. It does not edit documents,
run Git hooks, or turn generated state into authority.

## Checkpoints

| Checkpoint | Prevented failure |
|---|---|
| `pre-commit` | code or governance changes committed without tests and diff-routed documentation evaluation |
| `pre-review` | a candidate reviewed with a stale manifest, acceptance list, report, or docs authority |
| `handoff` | the next actor receives stale goal state, risks, blockers, or next action |
| `post-merge` | integrated state and durable-learning decisions are not reconciled |
| `final` | a goal closes or publishes without final report, memory decision, or remote-range evaluation |

`final --publishing` adds the `remote_range` surface. Ordinary test/fix loops
are not checkpoints.

## Surface outcomes and verdict

Every required surface receives exactly one outcome:

```text
UPDATED | NO_CHANGE_REQUIRED | PROPOSED | OUT_OF_SCOPE
```

- missing, invalid, or stale required evidence produces `FAIL`;
- `PROPOSED` or `OUT_OF_SCOPE` on an otherwise complete evaluation produces
  `PARTIAL`;
- current `UPDATED`/`NO_CHANGE_REQUIRED` coverage with no authority finding
  produces `PASS`.

The engine routes current Git paths to relevant surfaces. UI changes require
UI map, pattern, and test evaluation. RPC/migration changes require live-schema,
RPC reference, domain, deploy-boundary, and test evaluation. Harness and goal
changes require their contract/tests and goal/generated-view surfaces.

## Authority and evidence

With a Full goal, every repository change must fit the goal write manifest.
Lead documentation writes must additionally fit `tracked_paths`; ignored or
local policy writes must be declared through `local_paths`. Root remains the
integration authority but does not silently expand a Full goal manifest.

The local engine cannot observe a live DB mutation. Such an external effect is
`ATTESTED`, never `VERIFIED`. Live DB truth and mutation authority remain with
the separately approved DB surface.

The `--role` value is an explicit attestation by the invoker, not
authentication: a local receipt cannot prove who produced it. The CLI therefore
requires `--role` on every evaluation and never defaults it, and a receipt that
does not record an explicit role is invalid. Root acceptance reruns the
evaluation with the known actor role instead of trusting the recorded claim.

## Receipts

A receipt contains the checkpoint, goal, role, required/evaluated surfaces,
verdict, Git HEAD, exact changed paths, diff scope, and a deterministic content
hash. It is written only on explicit request to ignored:

```text
.harness/cache/DOCS-RECEIPT.json
```

`receipt-check` recomputes current paths, HEAD, content hash, authority, and
verdict. A missing or stale receipt cannot support `Docs-Update: PASS`. Receipts
are evidence, not canonical history; accepted goal/report/commit records remain
the durable source.

## CLI

Evaluate the current worktree:

```bash
python3 .harness/bin/harness.py docs-update pre-review \
  --goal G-YYYYMMDD-SLUG --role root \
  --surface manifest=NO_CHANGE_REQUIRED \
  --surface acceptance=NO_CHANGE_REQUIRED \
  --surface docs_authority=NO_CHANGE_REQUIRED \
  --surface goal_report=UPDATED \
  --surface harness_contract=NO_CHANGE_REQUIRED \
  --surface harness_tests=NO_CHANGE_REQUIRED \
  --surface generated_views=NO_CHANGE_REQUIRED \
  --write-receipt --json
```

Validate the current receipt:

```bash
python3 .harness/bin/harness.py receipt-check --expect PASS --json
```

Use `--scope staged` only when the checkpoint is intentionally bound to the
staged commit input. `--local-path` declares an observed ignored/local write;
it does not grant authority. `--db-observation ATTESTED` records an external
claim without upgrading it to locally verified fact.

## Surface names

Required-surface names map to the document or evidence that owns them:

| Surface | Owning document or evidence |
|---|---|
| `manifest` | the active goal's `write_manifest` |
| `acceptance` | `.harness/acceptance.md` and per-criterion verdicts |
| `docs_authority` | the goal's `docs_authority` block |
| `tests` | the test-run evidence recorded in the goal report |
| `ui_map` | `.harness/references/ui-map.md` |
| `ui_patterns` | `.harness/patterns/modal.md` and `.harness/patterns/forms.md` |
| `live_schema` | a separately authorized live-schema probe (never a tracked mirror) |
| `rpc_reference` | `.harness/references/rpc-reference.md` |
| `domain_rules` | `.harness/references/domain-rules.md` |
| `deploy_boundary` | the report's deploy record; push is not deploy |
| `decisions` | `.harness/decisions/` records |
| `harness_contract` | `.harness/contract.md` and this document |
| `harness_tests` | `tests/harness/` |
| `goal_report` | the active goal and its linked report |
| `generated_views` | the ignored `.harness/cache/` views |
| `blockers_risks`, `next_action` | the handoff section of the report |
| `memory` | curated notes under `.harness/memory/` |
| `remote_range` | the exact push range recorded at `final --publishing` |
| `testing_patterns` | `.harness/patterns/testing.md` |
| `producer_provenance` | fixture provenance notes in the report |

## Generated views

BOARD, HANDOFF, GOAL-INDEX, MEMORY-INDEX, and receipts belong to ignored cache
or stdout. Cached views may be checked for staleness, deleted, or rebuilt at
any time. They are never edited as canonical documents.
