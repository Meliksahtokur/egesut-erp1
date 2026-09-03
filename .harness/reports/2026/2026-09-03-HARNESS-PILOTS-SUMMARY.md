# Unified Agent Harness — Pilot Summary and Rollout Recommendation

Date: 2026-09-03

Owner: root

Status: three required pilots complete; rollout recommendation below for
the owner decision.

## Pilot results

| Measure | Pilot 1 (Fast, no goal) | Pilot 2 (Full, UI/modal) | Pilot 3 (Full, DB/RPC) |
|---|---|---|---|
| Work | design SPEC/PLAN tracked with current headers | 3 inline `openM` onclicks → registered actions | 20-function live-schema audit of the RPC reference |
| Operator prompts required | 0 | 0 | 0 |
| Wall time (gate-to-gate, agent-side) | ~13 s | minutes (dominated by the independent review) | minutes (probe + review) |
| Checkpoints evaluated | pre-commit, final | pre-review, pre-commit, final | pre-review, pre-commit, final (all with `db_observation: ATTESTED`) |
| Receipts written | 2 | 3 | 3 |
| Independent review | root only (docs-only diff) | PASS, 1 benign note | PARTIAL → count corrected by a deterministic re-probe; all other claims verified |
| Red-before evidence | n/a (no new enforcement) | 2 new product unit tests, 2/2 red first | n/a (probe is the evidence) |
| Missed/stale docs findings | 0 | 1 self-inflicted (final run pre-stage missed the routed `tests` surface; the engine correctly refused) | 2 self-inflicted surface omissions, both correctly refused |
| Manifest/authority violations | 0 | 0 | 0 |
| Worktree lifecycle | n/a (inline on main) | full: open → commit → detached verify → integrate → FF → push → clean | full, same |
| False-positive warnings | 0 | 0 | 0 |
| DB / deploy boundary | n/a | n/a | read-only demo probe; no write, no migration, no deploy |
| Pre-existing hook | executed on main (`PASS: All checks passed`) | byte-identical throughout (254d023e…) | byte-identical throughout |
| Result | eaa1afa | 15ad33c + b249270 | bfceb4b + 2784df4 |

## Program totals (phases 1-5 + pilots, 7543401..2784df4)

```text
governance surface added: 46 files, +8359 lines (.harness + tests/harness + 1 unit test)
product code touched by the program: 2 files, +4/-3 lines (Pilot 2 only, review-verified)
goals recorded: 7, all done
harness suite: 106/106; product unit suite: 442/442; validate: 7 goals, 5 patterns, 0 findings
core.hooksPath: unset throughout; shared hook sha unchanged throughout
```

## Checkpoint cost (the plan's deletion test)

Every checkpoint kind prevented at least one real failure during the
program: `pre-commit` receipt binding caught a post-receipt restage
(development-time), `pre-review` caught stale manifests, `handoff`
transferred a live candidate across sessions without loss, `final` refused
two under-evaluated publishes (Pilot 2/3 surface omissions), and
`commit-gate`/`push-gate` refused unbacked trailers, non-final receipts,
and dirty publish ranges in adversarial probing. No checkpoint kind is a
deletion candidate.

## Lessons recorded

1. Pipes swallow exit codes: a `--json | print` chain kept a FAILing
   `docs-update` from stopping a `&&` chain once (Pilot 2); verdicts are now
   read from the JSON before continuing.
2. Routing completeness: the engine, not the operator, knows the required
   surfaces — when in doubt run without `--surface` first and read the
   findings; both refusals above were operator omissions the engine caught.
3. Both the report author and an independent reviewer miscounted a probe
   sample; a deterministic aggregate query settled it. Prefer aggregate
   probes over hand-counted rows.

## Rollout recommendation (owner decision)

1. **Adopt the harness as the standing governance surface** — all three
   pilots completed with zero operator prompts, zero scope escapes, and the
   hook/main state byte-identical throughout.
2. **Approve Phase 6 in two steps**: first the classification report
   (`2026-09-03-PHASE6-CLASSIFICATION-PROPOSAL.md` in this directory),
   then a separately owner-approved cleanup manifest. No deletion happens
   without that manifest.
3. **Keep vector memory optional** — nothing in the program needed it.
4. **Keep GitHub E2E out of the acceptance gate** (existing owner policy);
   local suites remain the gate.
