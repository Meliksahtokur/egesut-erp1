# EgeSut ZCode Hooks

## 1. Purpose

This directory hosts the ZCode-native discipline layer for the EgeSut ERP
repository: a deterministic hook suite ported from the former Claude Code
hooks/hookify setup. Every guard is a plain `python3` script wired through
`.zcode/config.json`; it reads the tool-call JSON on stdin and either warns
(adds `additionalContext`), denies (emits `hookSpecificOutput` with
`permissionDecision: "deny"`), or stays silent. Guards never guess: warnings
point at the tracked `.harness/` rules, and only reviewed deterministic
acceptance checks own enforcement.

## 2. Guard table

| File | Event / matcher | What it does | Mode |
|---|---|---|---|
| `session_contract.py` | `SessionStart` (all) | Injects `.harness/contract.md` into the session as context. | warn |
| `js_edit_guard.py` | `PreToolUse` `Edit\|Write` | Once per session, reminds about blast-radius and duplicate-symbol prechecks before any edit under `js/*.js` (marker file in the system temp dir deduplicates). | warn |
| `commit_guard.py` | `PreToolUse` `Bash` | Before any `git commit`, points at `.harness/acceptance.md`, the active goal, and the `detect_changes` / commit-gate routine. | warn |
| `rpc_write_guard.py` | `PreToolUse` `Edit\|Write` | Denies direct `db.from(<protected table>).insert/update/delete/upsert` added inside `js/*.js`; tenant writes must go through RPC. Reads (`select`) and files outside `js/` are ignored. | deny |
| `sql_migration_guard.py` | `PreToolUse` `Edit\|Write` | Validates `supabase/**.sql` edits with `postgrestools check --reporter=json` against the live-schema mirror before they are applied. | deny on schema error / warn on infra issue / silent when clean or skipped |
| `ddl_refresh_guard.py` | `PostToolUse` `mcp__tools-bank__supabase_migrate` | When migrated SQL contains `CREATE`/`ALTER`/`DROP`, launches the schema-mirror refresh command in the background and warns; SELECT-only migrations stay silent. | warn + background side effect |

## 3. Activation and trust gate

- Workspace hooks are read from `.zcode/config.json` at **session bootstrap**.
- ZCode v3.11.2-20 requires an explicit trust decision for workspace hooks.
  Approve via the client banner ("Review") or the CLI
  (`zcode hooks trust status|review|grant|revoke --workspace <path>`).
- Trust state lives in `~/.zcode/security/workspace-hook-trust-v1.json`.
- Mid-session edits to `.zcode/config.json` do **not** hot-reload: the
  snapshot mismatch keeps the hook bundle blocked until the next session.
  After changing this config, start a new session and re-check trust.

## 4. Escape hatches

- `ZCODE_GUARD_SKIP_LSP=1` — `sql_migration_guard.py` skips the LSP check
  entirely and stays silent (for offline or emergency SQL edits).
- `ZCODE_GUARD_REFRESH_CMD` — overrides the command `ddl_refresh_guard.py`
  launches after DDL (default: `bash scripts/refresh_lsp_schema.sh`).
- Removing an entry from `.zcode/config.json` disables that guard for the
  next session.

## 5. Testing

```bash
bash .zcode/hooks/smoke_test.sh
```

The script feeds synthetic stdin JSON to all six hooks and asserts exit codes
and stdout contracts. Cases whose guard file has not landed yet report FAIL;
real-LSP cases report SKIP when `postgrestools` or `LOCAL_LSP_URL` is not
available. Exit code is `1` when any case failed.

## 6. Provenance

Ported from the Claude Code runtime artifacts `.claude/hookify.*.local.md`
(blast-radius-guard, block-direct-writes, check-duplicates,
protect-critical-files) and `scripts/hooks/*.sh` (`precheck-reminder.sh`,
`post-migration-refresh.sh`). The canonical rules live in
`.harness/references/domain-rules.md` §13. Deny enforcement is justified under
`.harness/contract.md:47-48`: "Hooks provide warnings or context unless a
reviewed deterministic acceptance check explicitly owns enforcement."
