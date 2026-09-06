#!/usr/bin/env python3
"""Emit per-session and targeted non-blocking precheck pointers for ZCode edits."""

from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import tempfile
from pathlib import Path

GENERIC = (
    "EgeSut JS edit boundary: read .harness/contract.md and the applicable "
    "code-change-precheck skill before editing a symbol. This reminder is "
    "warning-only and does not assert that impact analysis has passed."
)
BLAST_RE = re.compile(r"js/(ui|api|forms|app|state)\.js$")
DUP_SCOPE_RE = re.compile(r"js/(ui|forms|app|api)\.js$")
CRITICAL_RE = re.compile(
    r"(sw\.js|manifest\.json|js/config\.js|js/state\.js"
    r"|\.harness/references/domain-rules\.md)$"
)
FUNC_DEF_RES = (
    re.compile(r"(^|\n)(async\s+)?function\s+\w+\s*\("),
    re.compile(r"(^|\n)(const|let|var)\s+\w+\s*=\s*(async\s*)?\("),
)


def main() -> int:
    try:
        payload = json.loads(sys.stdin.read() or "{}")
    except (json.JSONDecodeError, OSError):
        payload = {}
    try:
        tool_input = payload.get("tool_input") or {}
        file_path = str(tool_input.get("file_path") or "")
        project = Path(os.environ.get("ZCODE_PROJECT_DIR", Path.cwd())).resolve()
        try:
            target = Path(file_path).resolve()
            rel = target.relative_to(project).as_posix()
        except (OSError, ValueError):
            return 0

        notes = []
        if BLAST_RE.search(rel):
            notes.append(
                "Blast radius: run gitnexus_impact(target, direction:'upstream') "
                f"before editing {rel}; notify the owner on HIGH/CRITICAL impact."
            )
        if DUP_SCOPE_RE.search(rel):
            key = "content" if payload.get("tool_name") == "Write" else "new_string"
            text = str(tool_input.get(key) or "")
            if any(p.search(text) for p in FUNC_DEF_RES):
                notes.append(
                    "Duplicate check: grep the new function name across js/*.js "
                    "before adding (past incident: tohSonuc defined in both "
                    "ui.js and forms.js)."
                )
        if CRITICAL_RE.search(rel):
            notes.append(
                f"Critical file: {rel} — broad blast radius (PWA/cache/global "
                "state/pattern rules); run focused tests after the edit."
            )

        session = (
            os.environ.get("ZCODE_SESSION_ID")
            or os.environ.get("CLAUDE_SESSION_ID")
            or "no-session"
        )
        digest = hashlib.sha256(session.encode("utf-8")).hexdigest()[:20]
        marker = Path(tempfile.gettempdir()) / f"egesut-zcode-js-guard-{digest}"
        if marker.exists():
            if notes:
                print(json.dumps(
                    {"additionalContext": "\n".join(notes)}, ensure_ascii=False
                ))
            return 0

        try:
            marker.write_text("1", encoding="utf-8")
        except OSError:
            pass

        message = GENERIC + ("\n" + "\n".join(notes) if notes else "")
        print(json.dumps({"additionalContext": message}, ensure_ascii=False))
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
