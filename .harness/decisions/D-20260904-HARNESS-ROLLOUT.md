---
id: D-20260904-HARNESS-ROLLOUT
date: 2026-09-04
status: accepted
head: 6bc036775f3970369cfc9b0271dd0b11968c758f
---

# Harness rollout

## Context

Phases 1-5 of the unified agent harness are integrated and pushed, and all
three required pilots completed on 2026-09-03 with zero operator prompts,
zero scope escapes, and byte-stable hook and protected-file hashes
(.harness/reports/2026/2026-09-03-HARNESS-PILOTS-SUMMARY.md). The
implementation plan made rollout conditional on an explicit owner decision
after the pilots.

## Decision

The owner approved rollout on 2026-09-04: the harness — the shared contract
under `..harness/`, Full goals with exact write manifests, checkpoint
docs-update receipts, and the commit/push gates — is the standing
governance surface for agent-assisted work in this repository. Vector
memory remains optional, GitHub E2E stays outside the acceptance gate, and
the local harness + unit suites remain the deterministic gate. All five
checkpoint kinds are retained; the pilot measurement found no deletion
candidate.

## Consequences

Agent sessions start from `AGENTS.md` into `..harness/contract.md`; Fast
and Full flows with their gates become the default way of working; hooks
stay warning-only with `.git/hooks/pre-commit` untouched and
`core.hooksPath` unset; future phases (pattern growth, reference refresh,
legacy handling) run as harness goals under this decision.
