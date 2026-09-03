#!/usr/bin/env python3
"""Emit one non-blocking shared-precheck pointer per ZCode session for JS edits."""

from __future__ import annotations

import hashlib
import json
import os
import sys
import tempfile
from pathlib import Path


def main() -> int:
    try:
        payload = json.loads(sys.stdin.read() or "{}")
    except (json.JSONDecodeError, OSError):
        payload = {}

    project = Path(os.environ.get("ZCODE_PROJECT_DIR", Path.cwd())).resolve()
    file_path = str((payload.get("tool_input") or {}).get("file_path") or "")
    try:
        target = Path(file_path).resolve()
        target.relative_to(project / "js")
    except (OSError, ValueError):
        return 0

    if target.suffix != ".js":
        return 0

    session = (
        os.environ.get("ZCODE_SESSION_ID")
        or os.environ.get("CLAUDE_SESSION_ID")
        or "no-session"
    )
    digest = hashlib.sha256(session.encode("utf-8")).hexdigest()[:20]
    marker = Path(tempfile.gettempdir()) / f"egesut-zcode-js-guard-{digest}"
    if marker.exists():
        return 0

    try:
        marker.write_text("1", encoding="utf-8")
    except OSError:
        pass

    message = (
        "EgeSut JS edit boundary: read .harness/contract.md and the applicable "
        "code-change-precheck skill before editing a symbol. This reminder is "
        "warning-only and does not assert that impact analysis has passed."
    )
    print(json.dumps({"additionalContext": message}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
