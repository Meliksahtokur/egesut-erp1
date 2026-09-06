#!/usr/bin/env python3
"""Emit a non-blocking pointer to shared acceptance rules before Git commits."""

from __future__ import annotations

import json
import sys


def main() -> int:
    try:
        payload = json.loads(sys.stdin.read() or "{}")
    except (json.JSONDecodeError, OSError):
        payload = {}

    command = str((payload.get("tool_input") or {}).get("command") or "")
    if "git commit" not in command:
        return 0

    message = (
        "EgeSut commit boundary: read .harness/acceptance.md and the active "
        "goal before continuing. This runtime hook is warning-only; it does "
        "not replace repository acceptance checks or grant commit authority.\n"
        "Before committing: run gitnexus detect_changes on the staged work, "
        "npm run test:unit, and produce the docs-update pre-commit receipt "
        "(commit-gate verifies it)."
    )
    print(json.dumps({"additionalContext": message}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
