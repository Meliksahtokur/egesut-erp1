# Pilot 2 Implementation Report

Goal: `G-20260903-PILOT2-MODAL-ACTIONS`

Date: 2026-09-03

Flow: `zcode_builtin`

Root verdict: `IN_PROGRESS`

## 1. Launch baseline

```text
main/worktree launch SHA: eaa1afa2fcdd106ec271d1de427d0e10580aa372
branch: idle/pilot2-modal-actions
worktree: /home/melik/egesut-wt/pilot2-modal-actions
manifest: five exact paths (goal, report, js/ui.js, js/utils/handlers.js, one unit test)
pattern_refs: MODAL-ROUTER-01 (required: the manifest touches product code)
pre-commit hook sha256 at launch: 254d023e66e0ed7abcadd886de8efc26873b2b619338e582d104ce90fd29eae0
main status after Pilot 1: 2 tracked modifications + 41 collapsed untracked entries
```

## 2. Scope

The three generated empty-state buttons that open router modals through
inline `onclick="openM(...)"` (js/ui.js kızgınlık list, üreme gebe list,
stock empty state) switch to their registered `data-action` handlers per
MODAL-ROUTER-01. `open-insem-modal` and `stok-add-open` already exist in the
registry; `open-kizginlik-modal` is registered once. One product-owned unit
test locks the registrations red-first.

## 3. Implementation and evidence

The refactor: js/ui.js kızgınlık empty-state, üreme gebe empty-state, and
stock empty-state buttons now carry `data-action` instead of inline
`onclick="openM(...)"`; handlers.js registers `open-kizginlik-modal` once;
`open-insem-modal` and `stok-add-open` are reused verbatim. Diff: 4 lines
(3 rewires + 1 registration).

Red-before: `tests/unit/modal-actions.test.js` was written first and failed
2/2 against the unmodified sources (unregistered action; inline onclick
present); after the change it passes 2/2 and the full product unit suite is
`442/442 PASS` (440 prior + 2). The harness suite is `106/106 PASS` and
`validate` reports six goals, zero findings — the goal itself proves the
Phase 4 product-manifest enforcement (it required `pattern_refs`, and
MODAL-ROUTER-01 cross-checked against the pattern index).

Hook preservation: the shared pre-commit hook sha256 stayed
`254d023e66e0…` through the pilot; the pilot commit happens on the idle
branch where the hook deliberately skips, and Pilot 1 already proved the
hook executes on main.

## 4. Independent review

A compact independent reviewer verified: the diff is exactly three
wiring-only edits plus one registration (styles byte-identical); zero
residual inline `onclick="openM("` in js/ui.js; the delegated dispatcher
calls preventDefault for BUTTON targets and no `<form>` exists, so no
default-submit path; the one behavioral delta (`stok-add-open` routes
through `openStokAdd()` which additionally runs `saTipSec('ilac')` on
static modal markup) is benign on the empty-stock path; and both suites
pass (442/442 unit, 106/106 harness).

Reviewer verdict: `PASS` — no blocking findings; the `saTipSec` null-guard
note is recorded as product polish, not pilot scope.

## 5. Checkpoints

Pre-review, pre-commit, integration, and final evidence follow below.
