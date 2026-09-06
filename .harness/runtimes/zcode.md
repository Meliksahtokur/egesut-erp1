# ZCode Runtime Adapter

Shared policy: `../contract.md`

ZCode Desktop defaults to its built-in agents. `.zcode/config.json` wires the
workspace hook suite under `.zcode/hooks/` (suite docs:
`.zcode/hooks/README.md`; smoke test: `bash .zcode/hooks/smoke_test.sh`).
Hooks load at session bootstrap and run behind the workspace hook trust gate
(`zcode hooks trust status|review|grant|revoke`; trust store:
`~/.zcode/security/workspace-hook-trust-v1.json`), so config changes take
effect in a new session.

- `session_contract.py` injects the contract at SessionStart.
- `rpc_write_guard.py` DENIES direct protected-table `db.from(...)` writes
  added inside `js/*.js`; canonical table→RPC mapping lives in
  `.harness/references/domain-rules.md` §13.
- `sql_migration_guard.py` validates `supabase/**.sql` edits with
  `postgrestools check` (deny on definite schema errors, warn on
  infrastructure gaps, `ZCODE_GUARD_SKIP_LSP=1` to skip).
- `ddl_refresh_guard.py` refreshes the live-schema mirror in the background
  after DDL migrations (`mcp__tools-bank__supabase_migrate`).
- `js_edit_guard.py` and `commit_guard.py` remain warning-only pointers to
  shared references.
- Herdr and external worker systems are not selected by default.
- Root/lead owns scope, evidence, and acceptance.

This adapter does not define product, Git, database, or acceptance policy.
