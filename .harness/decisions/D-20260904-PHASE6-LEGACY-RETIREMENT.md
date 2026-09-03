---
id: D-20260904-PHASE6-LEGACY-RETIREMENT
date: 2026-09-04
status: accepted
head: 6bc036775f3970369cfc9b0271dd0b11968c758f
---

# Phase 6 legacy retirement

## Context

The classification proposal
(.harness/reports/2026/2026-09-03-PHASE6-CLASSIFICATION-PROPOSAL.md)
classified every legacy agent surface and gated every deletion behind an
owner-approved cleanup manifest.

## Decision

The owner approved the full manifest on 2026-09-04: (1) retire the tracked
transitional copies `.claude/domain-rules.md`, `.claude/rpc-reference.md`,
and `.claude/ui-map.md` — the curated `.harness/references/` copies, which
include the owner's pending 2026-09-02 working-copy additions, become the
canonical references; (2) archive the qwen runtime surfaces (`.qwen/`,
`.agents/qwen/`, `.agents/QWEN.md`) into the untracked archive rather than
hard-delete; (3) track the four remaining design process artifacts; (4)
retain `.agents/skills/` and the memory-update skill (actively used).

## Consequences

`AGENTS.md` and the contract now route domain/RPC/UI questions to
`.harness/references/`; retired tracked files stay recoverable from Git
history; the archived qwen files remain on disk until an explicit deletion
review; `.claude/` stays the owner's local working surface for reports,
plans, and archives; no product code, live DB, hook, or deployment is
affected.
