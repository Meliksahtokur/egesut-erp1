#!/usr/bin/env python3
"""Block direct db.from() writes to protected tables added to js/ code."""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

WRITE_RE = re.compile(
    r"db\.from\(['\"`]"
    r"(tohumlama|dogum|hayvanlar|kizginlik_log|islem_log|gorev_log)"
    r"['\"`]\)\s*\.\s*(update|insert|delete|upsert)\s*\(",
    re.S,
)
REASON_TAIL = (
    "Writes go through RPCs: tohumlama→tohumlama_kaydet, dogum→dogum_kaydet, "
    "hayvanlar→hayvan_ekle/hayvan_guncelle, kizginlik_log/islem_log/gorev_log→"
    "RPC/trigger only. Direct writes bypass validation and state-machine "
    "guards. See .harness/references/domain-rules.md §13. Note: generic "
    "helpers dbUpdate()/dbInsert() are outside this regex's reach by design — "
    "do not route protected tables through them either."
)


def main() -> int:
    try:
        payload = json.loads(sys.stdin.read() or "{}")
    except (json.JSONDecodeError, OSError):
        payload = {}
    try:
        tool_input = payload.get("tool_input") or {}
        fp = tool_input.get("file_path")
        if not fp:
            return 0
        project = Path(os.environ.get("ZCODE_PROJECT_DIR", Path.cwd())).resolve()
        try:
            target = Path(str(fp)).resolve()
            rel = target.relative_to(project)
        except (OSError, ValueError):
            return 0
        if not rel.as_posix().startswith("js/") or target.suffix != ".js":
            return 0
        key = "content" if payload.get("tool_name") == "Write" else "new_string"
        match = WRITE_RE.search(str(tool_input.get(key) or ""))
        if not match:
            return 0
        table, verb = match.group(1), match.group(2)
        reason = (
            f"RPC-bypass write blocked: direct db.from('{table}').{verb}() on a "
            f"protected table. {REASON_TAIL}"
        )
        print(json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": reason,
                }
            },
            ensure_ascii=False,
        ))
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
