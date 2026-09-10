---
id: G-20260910-UREME-STOK-BUGFIX
status: active
owner: root
flow: ss_org
created: 2026-09-10
base_sha: 38c3b07
branch: idle/ureme-stok-bugfix
write_manifest:
  - BUGS.md
  - supabase/migrations/
  - tests/sql/
  - .claude/idle-reports/2026-09-10-ureme-bugfix.md
review_lane: codex_luna_max
implement_lane: glmf_workers
---

# G-20260910-UREME-STOK-BUGFIX — Reproduction-path stock/RPC bug fixes

- **Status:** ACTIVE
- **Date:** 2026-09-10
- **Base SHA:** 38c3b07 (main ucu dispatch anında; front-matter ile tek — F6/B9 kapandı)
- **Owner directive (2026-09-10):** fix the bugs recorded in `BUGS.md` via the
  ss-org network — Lead (GLM) coordinates, Worker (GLMF) sessions implement.
  Root verifies the lead branch, then merges to main or sends back for
  revision. PROD deploy and `git push` stay with the owner.
- **Bug registry:** `/home/melik/egesut-erp1/BUGS.md` (BUG-001, BUG-002, BUG-003)
- **Lane:** ss-org; review opened by the LEAD with a Codex (luna max) session —
  different CLI and model than the GLMF implementers.

## Context — root-measured evidence (2026-09-10, live PROD, read-only)

1. LIVE `tohumlama_kaydet(text,date,text,text,text,jsonb,boolean)` DEDUCTS
   sperma stock via `INSERT INTO stok_hareket SELECT ... WHERE (urun_adi ILIKE
   '%'||p_sperma||'%' OR urun_adi = p_sperma) AND kategori='Sperma' LIMIT 1`.
2. LIVE `tohumlama_tekrar_kaydet(text,date,text,text,text)` has the same
   deduction.
3. LIVE `planli_tohumlama_kaydet(uuid,text,date,text,text,text,jsonb,boolean)`
   has NO stock deduction — **BUG-001**.
4. The shared matcher has an empty-string wildcard hazard (`p_sperma=''` →
   `ILIKE '%%'` deducts from an arbitrary Sperma row) and substring
   cross-matching — **BUG-002**.
5. LIVE `gebelik_kaydet_manual(text,date,text)` raises SQL 42804 (text→uuid
   mismatch inside the body) — **BUG-003**; the 🤰 Gebelik Ekle modal is
   broken in production.
6. Tracked ground truth (`supabase/migrations/99999999999999_ground_truth.sql`,
   `tohumlama_kaydet` at lines 10858–10924) does NOT contain the stock
   deduction → GT↔live drift. Live is authority; GT regeneration is the
   root's post-deploy step and is OUT OF SCOPE here.

## Objective

Fix BUG-001, BUG-002, BUG-003 as **three narrow worker goals** (dar-goal: one
mechanism each; max 3 steps per goal). Target behavior on the demo DB:

- All three insemination paths (`tohumlama_kaydet`,
  `planli_tohumlama_kaydet`, `tohumlama_tekrar_kaydet`) deduct sperma stock
  with ONE shared matching rule.
- Matching rule: empty/whitespace `p_sperma` NEVER deducts; exact `urun_adi`
  match is preferred over substring ILIKE; `kategori='Sperma'` scope is kept.
- `gebelik_kaydet_manual` succeeds (reproduce the 42804 red-first on demo,
  then green).
- Stock MAY go below zero (free-deduction policy, precedent `20260902000002`).

## Write manifest (workers — nothing else)

Allowed:

- `supabase/migrations/<next-free-timestamp>_<slug>.sql` — additive only,
  exact filenames chosen by the lead, concept order: (1) planli deduction,
  (2) matcher hardening + shared rule, (3) gebelik fix
- `tests/sql/` new fixtures (psql, `BEGIN/ROLLBACK` pattern; follow
  `tests/sql/hayvan_grup_padok_sync_test.sql`)
- `BUGS.md` — status edits only

Forbidden: `js/**`, `index.html`, the ground-truth file,
`.harness/references/**`, writes to PROD, `git push`, merging to `main`.

Demo DB: migrations may be applied for testing (owner standing rule). Prefer
`BEGIN/ROLLBACK` fixtures; persistent demo test rows are allowed only if
listed and cleaned up in the same session. If the demo copy of
`gebelik_kaydet_manual` does not reproduce 42804, say so in the report and
validate the fix against the PROD error evidence + code-level reasoning.

## Execution discipline

- Workers commit to their own branches; the LEAD merges into
  `idle/ureme-stok-bugfix`. Root merges to main after verification.
- Live orchestration (spawning workers) is the LEAD's job; it is never put
  into a worker envelope.
- Red-first for BUG-003: show the failing demo call before the fix migration.
- Each new migration must pass `scripts/db-dry-run.sh` (Neon mirror).
- `npm run test:unit` must stay green (no JS change is expected).
- Blocking questions: workers → lead; lead → root via
  `ss-ask --class cross|owner`. At most 3 owner-class questions total.
- Record gates via `ss-crumbs` (gate entries carry `defect_class`).

## Independent review

The LEAD opens ONE Codex (luna max) review session over the final diff of
`idle/ureme-stok-bugfix` (input: envelope + `git diff`, not the author's
summary). Findings go back to the same worker once; verification of the fix
is the mechanical gate, not a second review round.

**Owner standing rule (2026-09-10) — supersedes the single-round limit at the
ROOT merge gate:** before ROOT merges this branch into main, ROOT sends the
full deliverable to a separate independent Codex (luna max) review session.
The revision loop (findings → lead/worker fix → root re-verify → review again)
continues until that reviewer's own verdict is PASS. Anti-manipulation: the
review envelope carries neutral material and criteria only — no author
summaries presented as facts, no coaching, no pre-negotiated verdict; findings
are relayed verbatim.

## Acceptance (mechanical — root will re-run)

1. Demo DB: planli tohumlama with a known sperma reduces that stock row by 1
   (before the fix: no change).
2. Empty-string sperma produces NO `stok_hareket` row on any of the three
   paths.
3. Exact-match precedence: a stock row named exactly `p_sperma` wins over a
   superstring product name.
4. `gebelik_kaydet_manual` demo call succeeds and writes its
   tohumlama/islem_log rows.
5. All new migrations pass `scripts/db-dry-run.sh`.
6. `npm run test:unit` green.
7. `BUGS.md` statuses updated to `fixed-pending-deploy`.

## Deliverable / report

`.claude/idle-reports/2026-09-10-ureme-bugfix.md` committed on
`idle/ureme-stok-bugfix` — the existence of this file on the branch is the
root's waiter signal. The report contains: per-bug verdict, exact commands
and outputs of every acceptance run, red-first evidence for BUG-003, review
findings and their resolutions, and the list of demo rows created/cleaned.

## Stop conditions

- Scope beyond BUG-001..003 (pedigree, semen_catalog, UI) — reject and
  ss-ask root.
- Any need to write to PROD — never; escalate to owner via root.
- A gate stays red with unclear cause — stop and ss-ask.
