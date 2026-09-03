"""Decision-record validation tests."""

from __future__ import annotations

import importlib.util
import tempfile
import textwrap
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / ".harness" / "bin" / "harness.py"
SPEC = importlib.util.spec_from_file_location("egesut_harness_decisions", MODULE_PATH)
HARNESS = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(HARNESS)


class DecisionTests(unittest.TestCase):
    def _write(self, root: Path, status: str = "accepted", body: str | None = None) -> Path:
        path = root / ".harness/decisions/D-20990101-EXAMPLE.md"
        path.parent.mkdir(parents=True)
        header = textwrap.dedent(
            f"""\
            ---
            id: D-20990101-EXAMPLE
            date: 2099-01-01
            status: {status}
            head: 0123456789abcdef0123456789abcdef01234567
            superseded_by: null
            ---
            """
        )
        decision_body = body or "## Context\n\nWhy.\n\n## Decision\n\nDo it.\n\n## Consequences\n\nCost."
        content = f"{header}\n{decision_body}\n"
        path.write_text(content, encoding="utf-8")
        return path

    def test_valid_decision_record_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            record = HARNESS.read_markdown_record(self._write(Path(temp)))
            self.assertEqual([], HARNESS.validate_decision_record(record))

    def test_invalid_decision_status_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            record = HARNESS.read_markdown_record(self._write(Path(temp), status="done"))
            codes = {item["code"] for item in HARNESS.validate_decision_record(record)}
            self.assertIn("INVALID_DECISION_STATUS", codes)

    def test_missing_decision_section_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            record = HARNESS.read_markdown_record(
                self._write(Path(temp), body="## Context\n\nOnly context.")
            )
            codes = {item["code"] for item in HARNESS.validate_decision_record(record)}
            self.assertIn("MISSING_DECISION_SECTION", codes)

    def test_superseded_decision_requires_target(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            record = HARNESS.read_markdown_record(self._write(Path(temp), status="superseded"))
            codes = {item["code"] for item in HARNESS.validate_decision_record(record)}
            self.assertIn("MISSING_SUPERSEDING_DECISION", codes)


if __name__ == "__main__":
    unittest.main()
