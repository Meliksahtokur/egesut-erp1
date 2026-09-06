#!/usr/bin/env python3
"""Schema-check supabase SQL writes/edits via postgrestools before they are saved."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.parse
from pathlib import Path

CLOSING = "Fix the migration before writing; the refreshed live-schema mirror is the reference."


def warn(msg: str) -> None:
    print(json.dumps({"additionalContext": msg}, ensure_ascii=False))


def deny(msg: str) -> None:
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse", "permissionDecision": "deny",
        "permissionDecisionReason": msg}}, ensure_ascii=False))


def first_lines(diagnostics: list, limit: int = 5) -> str:
    out = []
    for d in diagnostics[:limit]:
        start = (d.get("location") or {}).get("start") or {}
        out.append(f"line {start.get('line', '?')}:{start.get('column', '?')} — {d.get('message', '?')}")
    return "\n".join(out)


def db_env(root: Path):
    """Export PG* vars from LOCAL_LSP_URL in repo/.env; the password is never printed."""
    try:
        text = (root / ".env").read_text(encoding="utf-8")
    except OSError:
        return None
    for line in text.splitlines():
        if line.startswith("LOCAL_LSP_URL="):
            u = urllib.parse.urlparse(line.split("=", 1)[1].strip().strip("\"'"))
            env = dict(os.environ)
            env.update({"PGHOST": u.hostname or "", "PGPORT": str(u.port or 5432),
                        "PGUSER": u.username or "", "PGDATABASE": u.path.lstrip("/"),
                        "PGPASSWORD": u.password or ""})
            return env
    return None


def pgt_binary():
    found = shutil.which("postgrestools")
    if found:
        return found
    fallback = Path.home() / ".npm-global" / "bin" / "postgrestools"
    return str(fallback) if fallback.exists() else None


def run_check(root: Path, content: str):
    """Returns ("ok", None) | ("skip", reason) | ("errors", parsed report dict)."""
    pgt = pgt_binary()
    if not pgt:
        return "skip", "postgrestools binary not found"
    env = db_env(root)
    if env is None:
        return "skip", "LOCAL_LSP_URL missing in repo .env"
    tmp = None
    try:
        with tempfile.NamedTemporaryFile(prefix="egesut-sqlguard-", suffix=".sql",
                                         delete=False, mode="w", encoding="utf-8") as fh:
            fh.write(content)
            tmp = fh.name
        args = [pgt, "check", "--reporter=json", "--config-path",
                str(root / "postgres-language-server.jsonc"), tmp]
        proc = subprocess.run(args, capture_output=True, text=True, timeout=15, env=env)
    except subprocess.TimeoutExpired:
        return "skip", "postgrestools check timed out after 15s"
    except OSError as exc:
        return "skip", f"postgrestools could not run ({exc.__class__.__name__})"
    finally:
        if tmp:
            try:
                os.unlink(tmp)
            except OSError:
                pass
    if proc.returncode == 0:
        return "ok", None
    if proc.returncode != 1:
        return "skip", f"postgrestools check exited {proc.returncode}"
    try:
        report = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return "skip", "postgrestools JSON report unparseable"
    if not (report.get("summary") or {}).get("errors") or not (report.get("diagnostics") or []):
        return "skip", "exit 1 without usable diagnostics"
    return "errors", report


def decide(report: dict, relpath: str, is_edit: bool) -> None:
    diags = report.get("diagnostics") or []
    count = (report.get("summary") or {}).get("errors") or len(diags)
    listing = first_lines(diags)
    if is_edit:
        hard = [d for d in diags
                if d.get("category") == "typecheck" and "does not exist" in str(d.get("message", ""))]
        if not hard:
            warn(f"SQL LSP guard: {count} error(s) in {relpath}:\n{listing}\n"
                 "fragment edit — verify manually; not blocking.")
            return
        deny(f"SQL LSP guard: {len(hard)} schema error(s) in {relpath} "
             f"(column/relation does not exist):\n{listing}\n{CLOSING}")
        return
    deny(f"SQL LSP guard: {count} schema error(s) in {relpath}:\n{listing}\n{CLOSING}")


def guard(payload: dict) -> None:
    if os.environ.get("ZCODE_GUARD_SKIP_LSP") == "1":
        return
    tool_input = payload.get("tool_input") or {}
    root = Path(os.environ.get("ZCODE_PROJECT_DIR", Path.cwd())).resolve()
    try:
        target = Path(str(tool_input.get("file_path") or "")).resolve()
        relpath = target.relative_to(root).as_posix()
    except (OSError, ValueError):
        return
    if not (relpath.startswith("supabase/") and relpath.endswith(".sql")):
        return
    is_edit = str(payload.get("tool_name") or "") == "Edit"
    if is_edit:
        try:
            content = target.read_text(encoding="utf-8")
            content = content.replace(str(tool_input.get("old_string") or ""),
                                      str(tool_input.get("new_string") or ""), 1)
        except (OSError, ValueError):
            content = str(tool_input.get("new_string") or "")
    else:
        content = str(tool_input.get("content") or "")
    if not content.strip():
        return
    status, info = run_check(root, content)
    if status == "ok":
        return
    if status == "skip":
        warn(f"SQL LSP check skipped ({info}) — edit proceeds unverified.")
        return
    decide(info, relpath, is_edit)


def selftest() -> int:
    """Exercise deny/warn/silent decision branches with synthetic reports (no stdin)."""
    root = Path(os.environ.get("ZCODE_PROJECT_DIR", Path.cwd())).resolve()
    hard = {"summary": {"errors": 1}, "diagnostics": [
        {"severity": "error", "category": "typecheck",
         "message": "column \"olmayan_kolon_xyz\" does not exist",
         "location": {"start": {"line": 1, "column": 8}}}]}
    soft = {"summary": {"errors": 1}, "diagnostics": [
        {"severity": "error", "category": "parse",
         "message": "syntax error at or near \"SELEC\"",
         "location": {"start": {"line": 1, "column": 1}}}]}

    def label(name: str) -> None:
        print(f"--- {name}", file=sys.stderr)

    label("case 0: non-supabase/non-sql path -> expect silent (no stdout)")
    guard({"tool_name": "Write", "tool_input": {"file_path": str(root / "js" / "app.js"),
                                                "content": "DROP TABLE x;"}})
    label("case 1: write full content with typecheck error -> expect deny")
    decide(hard, "supabase/migrations/0001_selftest.sql", is_edit=False)
    label("case 2: edit fragment with typecheck does-not-exist -> expect deny")
    decide(hard, "supabase/migrations/0001_selftest.sql", is_edit=True)
    label("case 3: edit fragment with parse-only error -> expect warn (not blocking)")
    decide(soft, "supabase/migrations/0001_selftest.sql", is_edit=True)
    label("case 4: infra-skip (root without .env) -> expect skip reason")
    status, info = run_check(Path("/tmp/egesut-sqlguard-no-such-root"), "SELECT 1;")
    print(f"status={status} reason={info}", file=sys.stderr)
    if pgt_binary() and db_env(root):
        label("case 5: real postgrestools check on bogus column -> expect errors+deny")
        status, info = run_check(root, "SELECT olmayan_kolon_xyz FROM hayvanlar LIMIT 1;")
        print(f"status={status}", file=sys.stderr)
        if status == "errors":
            decide(info, "supabase/selftest/probe.sql", is_edit=False)
    print("selftest done", file=sys.stderr)
    return 0


def main() -> int:
    if "--selftest" in sys.argv[1:]:
        return selftest()
    try:
        payload = json.loads(sys.stdin.read() or "{}")
    except (json.JSONDecodeError, OSError):
        payload = {}
    try:
        guard(payload)
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
