# DB Migration Runbook

Version: `1` (2026-09-15; source: `reports/2026-09-15-gt-migration-kayit-baglam.md` §7a, D4)

Every migration applied to a managed environment (demo or prod) follows these
seven steps in order. Each step records its stated evidence; the first failing
step returns the work to the previous step. Live DB writes keep their own
owner gate (`.harness/contract.md`, "EgeSut product invariants"); this
runbook governs process and documentation, not DB authority.

| # | Step | Evidence | Tool |
|---|---|---|---|
| 1 | **Documentation first:** migration file, rationale, and a rollback note ready for the commit; goal or report link recorded | file + diff | — |
| 2 | **Backup:** row-level backup of affected tables outside the repo; for high-risk (DROP/RENAME) work include the schema definitions too | backup directory + manifest sha256 | Mgmt API SELECT |
| 3 | **Dry run:** the migration is replayed against a mirror inside BEGIN/ROLLBACK; error codes 42703/42P01/42710 must be zero | script output | `scripts/db-dry-run.sh` |
| 4 | **Apply:** `BEGIN; <file>; COMMIT;` in a single transaction (Mgmt API); the runner stops if the file carries its own BEGIN/COMMIT | raw response | Mgmt API |
| 5 | **Record:** `schema_migrations` INSERT for the applied version in the same session; without its record an apply is not "done" | the row read back via SELECT | Mgmt API |
| 6 | **Ground-truth refresh:** objects added or changed by this migration enter the ground truth (or a full regen per the regen procedure); the `Tarih:` header is updated | GT diff + commit | ground-truth regen procedure |
| 7 | **Verify + merge:** `scripts/ground-truth-audit.sh` (schema) + `scripts/veri-eslesme-kontrol.py hepsi` (data) + an md5 body probe of critical functions where applicable → report → merge | script outputs | — |

## The inseparable triple

Steps 4, 5, and 6 are one unit: the session that applies a migration delivers
its `schema_migrations` record and its ground-truth sync in the same delivery.
A step that cannot be delivered in that delivery is listed in the delivery
report as an explicit **balance** item — it is never dropped silently.

## Worked example (2026-09-15 prod Adım B)

Reference flow for steps 2, 4, and 7 (steps 5-6 were not delivered in that
session; they belong to the separate follow-up wave — the record batch of
`reports/2026-09-15-gt-migration-kayit-baglam.md` §7b and the ground-truth
regen §7c, with remaining owner steps recorded in
`reports/2026-09-15-prod-adim-b.md` §6): owner-approved backup
`prod-yedek-2026-09-15-adim-b`, single-transaction apply of the L2+L4
migrations through the Management API (8/8 OK, 7.3 s), then root read-only
measurement of live state. Commits: `e3c281e` (apply), `b75d154`
(merge + root measurement); integrated into main as `6a0edb1`.

## Boundaries

- The `schema_migrations` record means "was applied"; it never means
  "run it again".
- Push is not deploy; a migration commit is not a DB mutation
  (`.harness/acceptance.md`).
- Live schema remains the only structure authority; the ground-truth file is
  a generated reference that goes stale without step 6.
