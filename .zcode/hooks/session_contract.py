#!/usr/bin/env python3
"""Inject the tracked shared contract into a ZCode session without copying policy."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path


def project_root() -> Path:
    configured = os.environ.get("ZCODE_PROJECT_DIR")
    return Path(configured).resolve() if configured else Path.cwd().resolve()


def load_contract(root: Path) -> str:
    path = root / ".harness" / "contract.md"
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        return (
            "[EgeSut harness warning]\n"
            f"Shared contract could not be read from {path}: {exc.__class__.__name__}.\n"
            "Do not infer or recreate policy; report the missing tracked entrypoint."
        )


def main() -> int:
    try:
        sys.stdin.read()
    except OSError:
        pass

    context = load_contract(project_root())
    print(json.dumps({"additionalContext": context}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
