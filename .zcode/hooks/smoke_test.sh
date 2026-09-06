#!/usr/bin/env bash
# EgeSut ZCode hook smoke test.
#
# Feeds synthetic stdin JSON to every hook under .zcode/hooks/ and asserts the
# expected exit code / stdout contract for each case.
#
# Conventions:
#   - Cases whose guard file has not landed yet FAIL (never SKIP): the parallel
#     authors are expected to satisfy the fixed interface contract.
#   - Real-LSP cases (sql_migration_guard without ZCODE_GUARD_SKIP_LSP) are
#     SKIPped when `postgrestools` or LOCAL_LSP_URL is unavailable.
#
# Usage:   bash .zcode/hooks/smoke_test.sh
# Exit:    0 when FAIL == 0, otherwise 1.

set -u

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HOOKS_DIR/../.." && pwd)"
export ZCODE_PROJECT_DIR="$ROOT"

SMOKE_TMP="$(mktemp -d /tmp/egesut-smoke.XXXXXX)"
trap 'rm -rf "$SMOKE_TMP"' EXIT

PASS=0
SKIP=0
FAIL=0
FAILED_CASES=()

pass() { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); FAILED_CASES+=("$1"); printf 'FAIL  %s\n' "$1"; }
skip() { SKIP=$((SKIP + 1)); printf 'SKIP  %s\n' "$1"; }
note() { printf 'NOTE  %s\n' "$1"; }

# expect_exit <desc> <expected_rc> <actual_rc>
expect_exit() {
  if [ "$3" -eq "$2" ]; then
    pass "$1"
  else
    fail "$1 (expected exit=$2, got=$3)"
  fi
}

# expect_empty <desc> <stdout>
expect_empty() {
  if [ -z "$2" ]; then
    pass "$1"
  else
    fail "$1 (expected empty stdout, got: $2)"
  fi
}

# expect_json_field <desc> <stdout-json> <python expression over obj>
expect_json_field() {
  if [ -z "$2" ]; then
    fail "$1 (expected JSON on stdout, got nothing)"
    return
  fi
  if printf '%s' "$2" | EXPR="$3" python3 -c '
import json, os, sys
try:
    obj = json.load(sys.stdin)
except json.JSONDecodeError as exc:
    sys.stderr.write("invalid JSON: %s\n" % exc)
    sys.exit(2)
assert eval(os.environ["EXPR"]), "assertion failed"
' >/dev/null 2>&1; then
    pass "$1"
  else
    fail "$1 (json=$2)"
  fi
}

# make_payload <outfile> <tool_name> <file_path|-> <new_string|content|-> <text|->
#              <extra_key|command|sql|-> <extra_value|->
# Builds {"tool_name": ..., "tool_input": {...}} via python3 (quoting-safe).
make_payload() {
  python3 - "$@" <<'PY'
import json, sys
out, tool, fpath, field, text, ekey, evalue = sys.argv[1:8]
tool_input = {}
if fpath != "-":
    tool_input["file_path"] = fpath
if field != "-":
    tool_input[field] = text
if ekey != "-":
    tool_input[ekey] = evalue
with open(out, "w", encoding="utf-8") as fh:
    json.dump({"tool_name": tool, "tool_input": tool_input}, fh)
PY
}

# run_hook <hook.py> <payload.json>  -> sets OUT (stdout) and RC (exit code)
run_hook() {
  OUT="$(timeout 30 python3 "$HOOKS_DIR/$1" < "$2" 2>"$SMOKE_TMP/stderr.log")"
  RC=$?
}

DENY_KEYS_EXPR="set(obj) <= {'hookSpecificOutput'} and set(obj['hookSpecificOutput']) <= {'hookEventName','permissionDecision','permissionDecisionReason'}"
CONTEXT_KEYS_EXPR="set(obj) <= {'additionalContext'}"

echo "== EgeSut ZCode hook smoke =="
echo "hooks dir: $HOOKS_DIR"
echo

# --------------------------------------------------------------------------
# 1. session_contract.py — SessionStart contract injection.
# --------------------------------------------------------------------------
make_payload "$SMOKE_TMP/p1.json" SessionStart - - - - -
run_hook session_contract.py "$SMOKE_TMP/p1.json"
expect_exit "1. session_contract.py exits 0" 0 "$RC"
# Stdout content is intentionally not asserted: it mirrors .harness/contract.md.

# --------------------------------------------------------------------------
# 2. js_edit_guard.py — one precheck reminder per session for js/*.js edits.
# --------------------------------------------------------------------------
if [ ! -f "$HOOKS_DIR/js_edit_guard.py" ]; then
  note "js_edit_guard.py missing on disk; case 2 will FAIL (expected until it lands)"
fi

JS_MARKER_HASH="$(python3 -c 'import hashlib; print(hashlib.sha256(b"no-session").hexdigest()[:20])')"
JS_MARKER_PATH="${TMPDIR:-/tmp}/egesut-zcode-js-guard-$JS_MARKER_HASH"
rm -f "$JS_MARKER_PATH"

make_payload "$SMOKE_TMP/p2a.json" Edit "$ROOT/js/ui.js" \
  new_string "function renderHayvanList(rows) { return rows.map(renderHayvanRow); }" - -
run_hook js_edit_guard.py "$SMOKE_TMP/p2a.json"
expect_exit "2a. js_edit_guard js/ui.js (first call of session) exits 0" 0 "$RC"
expect_json_field "2a. js_edit_guard additionalContext mentions 'Blast radius' and 'Duplicate check'" "$OUT" \
  "'Blast radius' in obj.get('additionalContext', '') and 'Duplicate check' in obj.get('additionalContext', '')"
expect_json_field "2a. js_edit_guard warn output key set is clean" "$OUT" "$CONTEXT_KEYS_EXPR"
# The hook created the session marker above; a repeat js/ call would be silent.

make_payload "$SMOKE_TMP/p2b.json" Edit "$ROOT/README.md" new_string "unrelated non-js edit" - -
run_hook js_edit_guard.py "$SMOKE_TMP/p2b.json"
expect_exit "2b. js_edit_guard README.md exits 0" 0 "$RC"
expect_empty "2b. js_edit_guard README.md is silent (outside js/, marker-gated)" "$OUT"

# --------------------------------------------------------------------------
# 3. commit_guard.py — acceptance pointer before `git commit`.
# --------------------------------------------------------------------------
make_payload "$SMOKE_TMP/p3a.json" Bash - - - command "git commit -m x"
run_hook commit_guard.py "$SMOKE_TMP/p3a.json"
expect_exit "3a. commit_guard 'git commit' exits 0" 0 "$RC"
expect_json_field "3a. commit_guard additionalContext mentions 'detect_changes' and 'commit-gate'" "$OUT" \
  "'detect_changes' in obj.get('additionalContext', '') and 'commit-gate' in obj.get('additionalContext', '')"
expect_json_field "3a. commit_guard warn output key set is clean" "$OUT" "$CONTEXT_KEYS_EXPR"

make_payload "$SMOKE_TMP/p3b.json" Bash - - - command "ls"
run_hook commit_guard.py "$SMOKE_TMP/p3b.json"
expect_exit "3b. commit_guard 'ls' exits 0" 0 "$RC"
expect_empty "3b. commit_guard 'ls' is silent" "$OUT"

# --------------------------------------------------------------------------
# 4. rpc_write_guard.py — deny direct protected-table writes in js/*.js.
# --------------------------------------------------------------------------
if [ ! -f "$HOOKS_DIR/rpc_write_guard.py" ]; then
  note "rpc_write_guard.py missing on disk; case 4 will FAIL (expected until it lands)"
fi

make_payload "$SMOKE_TMP/p4a.json" Edit "$ROOT/js/api.js" \
  new_string "db.from('hayvanlar').update(x)" - -
run_hook rpc_write_guard.py "$SMOKE_TMP/p4a.json"
expect_exit "4a. rpc_write_guard js/api.js protected update exits 0" 0 "$RC"
expect_json_field "4a. rpc_write_guard denies protected-table write" "$OUT" \
  "obj.get('hookSpecificOutput', {}).get('permissionDecision') == 'deny'"
expect_json_field "4a. rpc_write_guard deny output key set is clean" "$OUT" "$DENY_KEYS_EXPR"

make_payload "$SMOKE_TMP/p4b.json" Edit "$ROOT/js/api.js" \
  new_string "db.from('hayvanlar').select('*')" - -
run_hook rpc_write_guard.py "$SMOKE_TMP/p4b.json"
expect_exit "4b. rpc_write_guard select exits 0" 0 "$RC"
expect_empty "4b. rpc_write_guard select is silent (reads allowed)" "$OUT"

make_payload "$SMOKE_TMP/p4c.json" Edit "$ROOT/tests/foo.js" \
  new_string "db.from('hayvanlar').insert(row)" - -
run_hook rpc_write_guard.py "$SMOKE_TMP/p4c.json"
expect_exit "4c. rpc_write_guard tests/ path exits 0" 0 "$RC"
expect_empty "4c. rpc_write_guard tests/ path is silent (out of scope)" "$OUT"

# --------------------------------------------------------------------------
# 5. sql_migration_guard.py — LSP validation of supabase/**.sql edits.
#    5a runs unconditionally (skip env). 5b/5c need the real LSP toolchain.
# --------------------------------------------------------------------------
if [ ! -f "$HOOKS_DIR/sql_migration_guard.py" ]; then
  note "sql_migration_guard.py missing on disk; case 5 will FAIL (expected until it lands)"
fi

# 5a. ZCODE_GUARD_SKIP_LSP=1 short-circuits entirely and silently.
make_payload "$SMOKE_TMP/p5a.json" Write "$ROOT/supabase/migrations/x.sql" \
  content "SELECT olmayan_kolon_xyz FROM hayvanlar LIMIT 1;" - -
export ZCODE_GUARD_SKIP_LSP=1
run_hook sql_migration_guard.py "$SMOKE_TMP/p5a.json"
unset ZCODE_GUARD_SKIP_LSP
expect_exit "5a. sql_migration_guard SKIP_LSP exits 0" 0 "$RC"
expect_empty "5a. sql_migration_guard SKIP_LSP is silent" "$OUT"

# 5b/5c only make sense when postgrestools and the local schema mirror exist.
# The guard reads LOCAL_LSP_URL from repo .env, so gate on that, not on an env var.
if command -v postgrestools >/dev/null 2>&1 && grep -q '^LOCAL_LSP_URL=' "$ROOT/.env" 2>/dev/null; then
  # 5b. Definitive schema error against a non-existent column -> deny.
  ZZ_BAD="$ROOT/supabase/migrations/zz-smoke-guard.sql"
  rm -f "$ZZ_BAD"
  make_payload "$SMOKE_TMP/p5b.json" Write "$ZZ_BAD" \
    content "SELECT olmayan_kolon_xyz FROM hayvanlar LIMIT 1;" - -
  run_hook sql_migration_guard.py "$SMOKE_TMP/p5b.json"
  expect_exit "5b. sql_migration_guard bad column exits 0" 0 "$RC"
  expect_json_field "5b. sql_migration_guard denies schema error" "$OUT" \
    "obj.get('hookSpecificOutput', {}).get('permissionDecision') == 'deny'"
  expect_json_field "5b. sql_migration_guard deny output key set is clean" "$OUT" "$DENY_KEYS_EXPR"
  rm -f "$ZZ_BAD"

  # 5c. Clean SQL passes silently.
  ZZ_OK="$ROOT/supabase/migrations/zz-smoke-guard-clean.sql"
  rm -f "$ZZ_OK"
  make_payload "$SMOKE_TMP/p5c.json" Write "$ZZ_OK" content "SELECT 1;" - -
  run_hook sql_migration_guard.py "$SMOKE_TMP/p5c.json"
  expect_exit "5c. sql_migration_guard clean SQL exits 0" 0 "$RC"
  expect_empty "5c. sql_migration_guard clean SQL is silent" "$OUT"
  rm -f "$ZZ_OK"
else
  skip "5b. sql_migration_guard bad column -> deny (SKIP: postgrestools or LOCAL_LSP_URL unavailable)"
  skip "5c. sql_migration_guard clean SQL -> silent (SKIP: postgrestools or LOCAL_LSP_URL unavailable)"
fi

# --------------------------------------------------------------------------
# 6. ddl_refresh_guard.py — background schema-mirror refresh after DDL.
# --------------------------------------------------------------------------
if [ ! -f "$HOOKS_DIR/ddl_refresh_guard.py" ]; then
  note "ddl_refresh_guard.py missing on disk; case 6 will FAIL (expected until it lands)"
fi

REFRESH_SCRIPT="$SMOKE_TMP/refresh_cmd.sh"
REFRESH_MARKER="$SMOKE_TMP/refreshed"
printf '#!/usr/bin/env bash\ntouch "%s"\n' "$REFRESH_MARKER" > "$REFRESH_SCRIPT"
chmod +x "$REFRESH_SCRIPT"
export ZCODE_GUARD_REFRESH_CMD="$REFRESH_SCRIPT"

# 6a. CREATE triggers the refresh command and a warning.
rm -f "$REFRESH_MARKER"
make_payload "$SMOKE_TMP/p6a.json" mcp__tools-bank__supabase_migrate - - - sql \
  "CREATE TABLE t(id int);"
run_hook ddl_refresh_guard.py "$SMOKE_TMP/p6a.json"
expect_exit "6a. ddl_refresh_guard CREATE exits 0" 0 "$RC"
expect_json_field "6a. ddl_refresh_guard warns with 'DDL detected'" "$OUT" \
  "'DDL detected' in obj.get('additionalContext', '')"
expect_json_field "6a. ddl_refresh_guard warn output key set is clean" "$OUT" "$CONTEXT_KEYS_EXPR"
MARKER_SEEN=0
for _ in $(seq 1 50); do
  if [ -f "$REFRESH_MARKER" ]; then
    MARKER_SEEN=1
    break
  fi
  sleep 0.1
done
if [ "$MARKER_SEEN" -eq 1 ]; then
  pass "6a. refresh command ran in background (marker file created)"
else
  fail "6a. refresh command did not run (marker missing after 5s)"
fi

# 6b. SELECT-only is silent and never refreshes.
rm -f "$REFRESH_MARKER"
make_payload "$SMOKE_TMP/p6b.json" mcp__tools-bank__supabase_migrate - - - sql \
  "SELECT * FROM t;"
run_hook ddl_refresh_guard.py "$SMOKE_TMP/p6b.json"
expect_exit "6b. ddl_refresh_guard SELECT exits 0" 0 "$RC"
expect_empty "6b. ddl_refresh_guard SELECT-only is silent" "$OUT"
sleep 1
if [ ! -f "$REFRESH_MARKER" ]; then
  pass "6b. refresh command not triggered by SELECT (marker still absent)"
else
  fail "6b. refresh command ran on SELECT-only (marker was created)"
fi
unset ZCODE_GUARD_REFRESH_CMD

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo
echo "------------------------------------------------------------"
echo "Smoke summary: PASS=$PASS SKIP=$SKIP FAIL=$FAIL"
if [ "${#FAILED_CASES[@]}" -gt 0 ]; then
  echo "Failed cases:"
  for c in "${FAILED_CASES[@]}"; do
    printf '  - %s\n' "$c"
  done
fi
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
