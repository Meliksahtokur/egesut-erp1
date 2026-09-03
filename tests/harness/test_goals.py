"""Goal parsing, validation, and lifecycle tests for the Phase 2 harness."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / ".harness" / "bin" / "harness.py"
SPEC = importlib.util.spec_from_file_location("egesut_harness", MODULE_PATH)
HARNESS = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(HARNESS)


class GoalTests(unittest.TestCase):
    def test_current_goals_validate(self) -> None:
        result = HARNESS.validate_repository(ROOT)
        errors = [item for item in result["findings"] if item["level"] == "ERROR"]
        self.assertEqual([], errors)
        self.assertGreaterEqual(result["goal_count"], 2)

    def test_frontmatter_parser_handles_nested_manifest_and_authority(self) -> None:
        record = HARNESS.read_markdown_record(
            ROOT / ".harness/goals/2026/G-20260903-UNIFIED-HARNESS-PHASE2.md"
        )
        self.assertEqual("G-20260903-UNIFIED-HARNESS-PHASE2", record["meta"]["id"])
        self.assertEqual(12, len(record["meta"]["write_manifest"]))
        authority = record["meta"]["docs_authority"]["tracked_paths"]["write"]
        self.assertEqual(record["meta"]["write_manifest"], authority)

    def test_duplicate_goal_ids_are_rejected(self) -> None:
        record = {"meta": {"id": "G-20260903-DUPLICATE"}, "path": "one.md"}
        findings = HARNESS.validate_unique_ids([record, {**record, "path": "two.md"}], "goal")
        self.assertEqual("DUPLICATE_GOAL_ID", findings[0]["code"])

    def test_manifestless_full_goal_is_rejected(self) -> None:
        goal = HARNESS.minimal_goal_for_test()
        goal["write_manifest"] = []
        findings = HARNESS.validate_goal_meta(goal, Path("goal.md"))
        self.assertIn("EMPTY_WRITE_MANIFEST", {item["code"] for item in findings})

    def test_invalid_sha_and_docs_verdict_are_rejected(self) -> None:
        goal = HARNESS.minimal_goal_for_test()
        goal["base_sha"] = "not-a-sha"
        goal["checkpoint"]["docs_verdict"] = "GREEN"
        codes = {item["code"] for item in HARNESS.validate_goal_meta(goal, Path("goal.md"))}
        self.assertIn("INVALID_BASE_SHA", codes)
        self.assertIn("INVALID_DOCS_VERDICT", codes)

    def test_docs_authority_cannot_escape_write_manifest(self) -> None:
        goal = HARNESS.minimal_goal_for_test()
        goal["docs_authority"]["tracked_paths"]["write"].append("outside.md")
        codes = {item["code"] for item in HARNESS.validate_goal_meta(goal, Path("goal.md"))}
        self.assertIn("DOCS_AUTHORITY_OUTSIDE_MANIFEST", codes)

    def test_manifest_rejects_absolute_and_parent_paths(self) -> None:
        goal = HARNESS.minimal_goal_for_test()
        goal["write_manifest"] = ["../outside", "/absolute/path"]
        codes = {item["code"] for item in HARNESS.validate_goal_meta(goal, Path("goal.md"))}
        self.assertIn("INVALID_MANIFEST_PATH", codes)

    def test_worker_cannot_transition_goal_to_done(self) -> None:
        with self.assertRaises(HARNESS.HarnessError):
            HARNESS.validate_transition("review", "done", actor_role="worker")
        HARNESS.validate_transition("review", "done", actor_role="root")

    def test_illegal_status_transition_is_rejected(self) -> None:
        with self.assertRaises(HARNESS.HarnessError):
            HARNESS.validate_transition("draft", "done", actor_role="root")

    def test_lead_cannot_edit_another_goal(self) -> None:
        with self.assertRaises(HARNESS.HarnessError):
            HARNESS.authorize_goal_edit(
                actor_role="lead",
                actor_goal_id="G-20990101-ONE",
                target_goal_id="G-20990101-TWO",
            )
        HARNESS.authorize_goal_edit(
            actor_role="root",
            actor_goal_id="G-20990101-ONE",
            target_goal_id="G-20990101-TWO",
        )

    def test_schema_files_are_valid_json_schema_documents(self) -> None:
        for name in ("goal", "report", "decision"):
            path = ROOT / ".harness" / "schemas" / f"{name}.schema.json"
            schema = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual("https://json-schema.org/draft/2020-12/schema", schema["$schema"])
            self.assertEqual("object", schema["type"])

    def test_missing_linked_report_is_an_error(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            goal = HARNESS.minimal_goal_for_test()
            goal["report"] = ".harness/reports/2099/missing.md"
            finding = HARNESS.validate_report_link(root, goal, Path("goal.md"))
            self.assertEqual("MISSING_REPORT", finding["code"])

    def test_report_link_cannot_escape_canonical_report_tree(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            goal = HARNESS.minimal_goal_for_test()
            goal["report"] = "../../etc/passwd"
            result = HARNESS.validate_report_link(Path(temp), goal, Path("goal.md"))
            self.assertEqual("INVALID_REPORT_LINK", result["code"])


if __name__ == "__main__":
    unittest.main()
