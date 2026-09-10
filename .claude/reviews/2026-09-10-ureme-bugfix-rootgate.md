# Root-gate review — G-20260910-UREME-STOK-BUGFIX

Review date: 2026-09-10. Reviewed `idle/ureme-stok-bugfix` at
`96ada8211633d3db993e883f0aa8de666ea48aca`, range
`38c3b072eaf743afc560d8619e01895532191b69..96ada8211633d3db993e883f0aa8de666ea48aca`.
No PROD access was performed. Demo checks used transaction rollback; Neon checks
used `BEGIN`/`ROLLBACK`.

## Claim-verification table

| Claim | Status | Evidence and boundary |
|---|---|---|
| Range scope is the declared eight-file deliverable | VERIFIED | `git diff --name-status 38c3b07..idle/ureme-stok-bugfix` lists only the three migrations, three SQL fixtures, `BUGS.md`, and the lead report; `git diff --check` is clean. |
| Ground-truth/live body comparison supports the rewrites | VERIFIED | `tohumlama_kaydet` in M2 matches the retained live body and tracked `20260830000034` body except for the intended semen INSERT→helper replacement and formatting. `tohumlama_tekrar_kaydet` matches the GT/live body except for formatting and the intended replacement. M3 matches GT/live with the three intended text→uuid changes. |
| BUG-001 is a false alarm and planned calls inherit deduction by delegation | VERIFIED | Demo read-only body probe shows `v_result:=public.tohumlama_kaydet(...)`; the retained pre-fix probe reports one ledger row. The post-fix end-to-end fixture also passes the planned path. Current PROD state was not re-probed. |
| M1/M2 implement empty/whitespace guard, exact-first fallback, category scope, and live note text | VERIFIED | M1:56-85 has the regex guard, separate exact query, substring fallback, `kategori='Sperma'`, and caller-supplied notes. Both demo semen fixtures exited 0. The global empty-input assertion is not sufficient; see F3. |
| All three paths produce the claimed behavior | UNVERIFIED | `sperma_eslesme_test.sql` exited 0, but its empty-input assertions only count four seeded stock IDs. Existing demo state has four other Sperma rows, so a guard-removed mutant can write elsewhere and still pass (F3). |
| BUG-003 red-first and green behavior | VERIFIED | Rollback-only `red_repro.sql` exited 0 with `NOTICE: RED-YAKALANDI SQLSTATE=42804 ... id ... uuid ... text`; the green fixture exited 0 with all three PASS notices and `ROLLBACK`. Post-run read-only check: `t|0|0`. |
| Three migration dry-runs | VERIFIED | Independent raw Neon `BEGIN/-f/ROLLBACK` runs for M1, M2, and M3 each exited 0. Retained `M1b.dryrun.log`, `M2c.dryrun.log`, and `M3.dryrun.log` also report exit 0. Exact wrapper freshness is limited because `scripts/db-dry-run.sh` is not present in this review worktree; it is an untracked main-checkout tool. |
| `npm run test:unit` is green | REFUTED | With main checkout dependencies: `tests 737`, `pass 736`, `fail 1`, exit 1; failure is `tests/unit/gecmis-pipeline.test.js:301` (`dun.includes('DÜN')`). No JS or unit-test file is in the review range, so the red is pre-existing, but the literal green criterion is not met. |
| All BUGS statuses are `fixed-pending-deploy` | REFUTED | Target `BUGS.md:14` is `[refuted]`; `:36` and `:68` are `[fixed-pending-deploy]`. This is substantively consistent with BUG-001’s refutation, but it does not satisfy goal acceptance line 126 literally. |

## Findings

### F1 — HIGH — [security] public helper permits direct stock-ledger writes

`supabase/migrations/20260910000001_planli_tohumlama_sperma_dus.sql:47-87` creates
`public.fn_sperma_stok_dus(text,text)` without a `REVOKE`, explicit allow-list, or
private schema. It is invoker-security (`SECURITY DEFINER` is absent), but the
demo catalog shows `anon_execute=t`, `authenticated_execute=t`,
`authenticated_insert=t`, RLS enabled with `allow all`, and
`security_definer=f`; `proacl` includes public and authenticated EXECUTE.
Therefore an authenticated client can call the new helper directly with an
arbitrary product and notes, creating a `stok_hareket` row without the
animal/tohumlama validation or audit path. This is an authorization/security
defect and a merge blocker. The helper needs a deliberate non-client ACL (or a
private schema/internal-only design) before merge.

### F2 — `scope-violation` — `BUGS.md` exceeds the status-only manifest

The goal permits `BUGS.md` as “status edits only” (`.harness/goals/2026/G-20260910-UREME-STOK-BUGFIX.md:74`). The final diff adds 27 explanatory lines at
`BUGS.md:16-23`, `:38-44`, and `:70-75`, not merely the three status changes.
This is outside the declared write surface even though the path itself is
listed.

### F3 — `fake-arm` — empty-input fixtures can miss a write to real stock

`tests/sql/sperma_stok_dus_test.sql:70-75,110-113` and
`tests/sql/sperma_eslesme_test.sql:72-76,107-110,140-144` count only the four
seeded stock IDs. They never compare the total `stok_hareket` count before and
after each empty-input call. The demo read-only probe measured four existing
Sperma stock rows and four matches for `urun_adi ILIKE '%' || '' || '%'`.
A mutant that removes the empty/whitespace guard but retains exact precedence
can deduct one of those existing rows while all current assertions still pass.
The claimed “no row on any path” behavior is consequently not independently
asserted by these fixtures.

### F4 — `doc-drift` — BUG-001 retains its refuted premise as current text

`BUGS.md:16-23` says planned calls delegate and already deduct, but the
following unmarked “Kanıt/Etki/Fix yönü” block at `BUGS.md:25-34` still says
`planli_tohumlama_kaydet` “düşmüyor”, that planned insemination leaves stock
unreduced, and that a planned-path deduction should be added. A future worker
could follow the stale block and reintroduce double deduction. The status
change does not reconcile the retained content.

### F5 — `fake-arm`/`doc-drift` — claimed CR whitespace coverage is absent

The lead report claims tab/newline/CR coverage at
`.claude/idle-reports/2026-09-10-ureme-bugfix.md:33`, but
`tests/sql/sperma_stok_dus_test.sql:61-68` invokes only `E'\\t'` and
`E'\\n  '` (plus ordinary space and NULL). There is no `E'\\r'` or CRLF case.
The production regex may handle CR, but the claimed regression fixture does not
prove it.

### F6 — `doc-drift` — B9 remains open in the goal metadata

The active goal has front-matter `base_sha: 38c3b07` at
`.harness/goals/2026/G-20260910-UREME-STOK-BUGFIX.md:7`, while its body still
says `Base SHA: a3d8bc2` at `:22`. The lead report explicitly leaves this open
at `.claude/idle-reports/2026-09-10-ureme-bugfix.md:158-159`; it is not fixed in
the final branch diff. The root must reconcile this metadata before treating
the goal as merge-ready.

## B1–B9 fix judgment

| Finding | Judgment | Verification |
|---|---|---|
| B1 | PARTIAL | Statuses were edited, but acceptance 7 is still literal-fail for refuted BUG-001 and the old premise remains (F4). |
| B2 | FIXED | Final M1 has one `(text,text DEFAULT)` helper signature; M2 has no helper DROP. Current demo catalog has one such helper. |
| B3 | FIXED for the former DROP/owner-loss defect; F1 remains | Final M1/M2 contain no executable `DROP FUNCTION`; `CREATE OR REPLACE` preserves an existing helper’s ACL/owner, but the newly exposed default ACL is a separate defect. |
| B4 | FIXED | No session `SET client_min_messages` remains in the final M2. |
| B5 | FIXED | M2 wraps both function replacements in one `DO` statement and the independent Neon transaction run exits 0. |
| B6 | PARTIAL | The implementation changed to `^\\s*$` and tab/newline cases pass, but the claimed CR case is missing (F5). |
| B7 | FIXED | The fixture header names `tests/sql/sperma_eslesme_test.sql` at `:17`. |
| B8 | PARTIAL | Superstring-first seeding and a unique İlaç negative are present, but the empty-input global-delta blind spot remains (F3). |
| B9 | OPEN | Goal front-matter/body base SHA mismatch remains (F6). |

## Acceptance command evidence

```text
git diff --stat 38c3b07..idle/ureme-stok-bugfix
8 files changed, 1078 insertions(+), 3 deletions(-)

NODE_PATH=/home/melik/egesut-erp1/node_modules npm run test:unit
tests 737
pass 736
fail 1
npm_exit=1

psql "$DEMO_CONN" -v ON_ERROR_STOP=1 -f tests/sql/sperma_stok_dus_test.sql
BEGIN / NOTICE TESTDONE:t / DO / ROLLBACK / fixture_exit=0
psql "$DEMO_CONN" -v ON_ERROR_STOP=1 -f tests/sql/sperma_eslesme_test.sql
BEGIN / NOTICE TESTDONE:t / DO / ROLLBACK / fixture_exit=0
psql "$DEMO_CONN" -v ON_ERROR_STOP=1 -f tests/sql/gebelik_kaydet_manual_test.sql
BEGIN / three PASS notices / DO / ROLLBACK / fixture_exit=0

psql "$DEMO_CONN" -f red_repro.sql
BEGIN / CREATE FUNCTION / INSERT 0 1 /
NOTICE: RED-YAKALANDI SQLSTATE=42804 MSG=column "id" is of type uuid but expression is of type text
DO / ROLLBACK / exit=0

Neon raw transaction runs:
20260910000001...sql: BEGIN CREATE FUNCTION ROLLBACK / exit=0
20260910000002...sql: BEGIN DO ROLLBACK / exit=0
20260910000003...sql: BEGIN CREATE FUNCTION ROLLBACK / exit=0
```

All demo fixture and red-repro effects were rolled back; the post-run check was
`red_probe_rolled_back=t|red_rows_left=0|fixture_rows_left=0`. No source file
other than this review report was changed in this worktree before delivery.

## VERDICT: FAIL

The migration bodies and post-fix demo behavior are substantially correct, but
the branch is not merge-ready because F1 permits direct authenticated ledger
writes, F3 does not actually prove the global empty-input invariant, F2/F4 are
manifest and documentation failures, B9 is still open, and the literal unit and
BUGS acceptance criteria remain red.

## Confidence

High (0.97) for the static, demo, and Neon findings. Current PROD behavior and
deployment state remain unmeasured by design; the retained live evidence is
point-in-time material, not a fresh PROD proof.
