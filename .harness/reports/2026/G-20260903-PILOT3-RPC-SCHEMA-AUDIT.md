# Pilot 3 Implementation Report

Goal: `G-20260903-PILOT3-RPC-SCHEMA-AUDIT`

Date: 2026-09-03

Flow: `zcode_builtin`

Root verdict: `IN_PROGRESS`

## 1. Launch baseline

```text
main/worktree launch SHA: b24927098e9352f6b8779d55f8b53ee2c52ef718
branch: idle/pilot3-rpc-schema-audit
worktree: /home/melik/egesut-wt/pilot3-rpc-schema-audit
manifest: three exact paths (goal, report, rpc-reference audit note)
db authority: read (first goal to declare it)
probe environment: the configured demo project (vtzqjmazsvurxdeondmi), read-only
```

## 2. Scope

A read-only `pg_proc` signature probe over a 20-function sample from
`.harness/references/rpc-reference.md`, mismatch classification, and an
audit note.

## 3. Probe result

```text
probe: pg_get_function_identity_arguments + pg_get_function_result over pg_proc (public schema)
environment: demo project vtzqjmazsvurxdeondmi (the configured read connection), read-only
sample: 20 requested names -> 23 signature rows (hayvan_ekle x2, hayvan_guncelle x3)
presence: 20/20 names present on demo (23/23 signature rows), including asi_toplu_planla (20260902000004)
match: parameter names and jsonb result types match the reference for the whole sample
  - tohumlama pair carries p_irk_bilgisi exactly as documented (rpc-reference lines 93/101)
  - hayvan_guncelle overload 3 carries p_kisir exactly as documented (line 52)
  - kupe_musait_mi optional p_hayvan_id present; both hayvan_ekle overloads present
mismatches: none in the sample
classification: no reference error found; no demo-parity gap observable in the sample
db observation recorded to the engine as: ATTESTED (never VERIFIED)
```

Two initially suspected gaps (missing `p_irk_bilgisi`, undocumented
`p_kisir` overload) were disproven against the actual reference text — both
are documented; the suspicion came from a research summary, not the
reference. That correction is itself audit evidence: conclusions were
checked against the artifact, not the summary.

## 4. Review adjudication and count correction

The independent reviewer re-probed live and confirmed the reference
fidelity, audit honesty, `db: read`/ATTESTED semantics, gates, and scope —
but flagged the signature count as an off-by-one (claiming 19 names / 22
signatures). Root re-measurement with a deterministic aggregate probe
settled it: **20 distinct names / 23 signature rows** — the report's
original "22 signatures" was a miscount of the probe output (corrected
above), and the reviewer's "19 names" was a dropped name in their own
re-probe list. Both errors are recorded here; the aggregate probe output is
the settled evidence. Reviewer verdict otherwise: all five claim groups
verified clean; with the count corrected the pilot is acceptable.

## 5. Boundaries

No DB write, migration, or deploy occurred; push is not deploy. The probe
covers the demo environment only; PROD parity is assumed from the
2026-09-02 sync and is not proven by this pilot.
