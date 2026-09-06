#!/usr/bin/env python3
"""Kick off a background live-schema mirror refresh after supabase_migrate DDL runs."""

from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

LOG = "/tmp/lsp-autorefresh.log"


def main() -> int:
    try:
        payload = json.loads(sys.stdin.read() or "{}")
    except (json.JSONDecodeError, OSError):
        payload = {}

    # supabase_migrate sends its DDL in tool_input.sql; accept tool_input.command
    # as a tolerant-reader fallback so fixed smoke fixtures also trip the guard.
    tool_input = payload.get("tool_input") or {}
    sql = str(tool_input.get("sql") or tool_input.get("command") or "")
    if not re.search(r"(create|alter|drop)\s", sql, re.I):
        return 0

    try:
        repo = Path(os.environ.get("ZCODE_PROJECT_DIR", Path.cwd())).resolve()
        raw = os.environ.get("ZCODE_GUARD_REFRESH_CMD")
        cmd = shlex.split(raw) if raw else ["bash", str(repo / "scripts" / "refresh_lsp_schema.sh")]
        with open(LOG, "ab") as log:
            # Inherit env as-is (SB_MGMT_TOKEN) and detach; never block the tool result.
            subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    except Exception:
        return 0

    message = (
        "DDL detected — live-schema mirror refresh started in background "
        f"(log: {LOG}). Re-run SQL schema checks after it completes."
    )
    print(json.dumps({"additionalContext": message}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
