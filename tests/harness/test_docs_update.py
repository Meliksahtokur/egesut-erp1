"""Checkpoint routing and receipt tests for the docs-update engine."""

from __future__ import annotations

import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / ".harness" / "bin" / "harness.py"
SPEC = importlib.util.spec_from_file_location("egesut_harness_docs_update", MODULE_PATH)
HARNESS = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(HARNESS)


def git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args], cwd=root, check=True, text=True, capture_output=True
    )
    return result.stdout.strip()


def init_repo(root: Path) -> None:
    git(root, "init", "-q")
    git(root, "config", "user.name", "Harness Test")
    git(root, "config", "user.email", "harness-test@invalid")
    (root / ".gitignore").write_text("/.harness/cache/\n", encoding="utf-8")
    (root / "README.md").write_text("baseline\n", encoding="utf-8")
    git(root, "add", ".gitignore", "README.md")
    git(root, "commit", "-qm", "baseline")


class DocsUpdateTests(unittest.TestCase):
    def test_goal_rejects_non_contract_checkpoint_kind(self) -> None:
        goal = HARNESS.minimal_goal_for_test()
        goal["checkpoint"]["kind"] = "progress"
        codes = {
            item["code"] for item in HARNESS.validate_goal_meta(goal, Path("goal.md"))
        }
        self.assertIn("INVALID_CHECKPOINT_KIND", codes)

    def _passing_evaluations(
        self, checkpoint: str, paths: list[str], *, goal: dict | None = None,
        publishing: bool = False,
    ) -> dict[str, str]:
        required = HARNESS.required_docs_surfaces(
            checkpoint, paths, goal=goal, publishing=publishing
        )
        return {surface: "NO_CHANGE_REQUIRED" for surface in required}

    def test_ui_change_requires_map_patterns_and_tests_evaluation(self) -> None:
        required = HARNESS.required_docs_surfaces(
            "pre-commit", ["js/ui.js"], goal=None, publishing=False
        )
        self.assertTrue({"ui_map", "ui_patterns", "tests"}.issubset(required))
        result = HARNESS.evaluate_docs_update(
            ROOT,
            "pre-commit",
            {"tests": "NO_CHANGE_REQUIRED"},
            changed_paths=["js/ui.js"],

            actor_role="root",
        )
        self.assertEqual("FAIL", result["verdict"])
        self.assertIn("MISSING_SURFACE_EVALUATION", {item["code"] for item in result["findings"]})

    def test_stale_surface_cannot_produce_pass(self) -> None:
        evaluations = self._passing_evaluations("pre-commit", ["js/ui.js"])
        evaluations["ui_map"] = {"outcome": "NO_CHANGE_REQUIRED", "fresh": False}
        result = HARNESS.evaluate_docs_update(
            ROOT, "pre-commit", evaluations, changed_paths=["js/ui.js"]
,
            actor_role="root",
        )
        self.assertEqual("FAIL", result["verdict"])
        self.assertIn("STALE_DOCUMENTATION_SURFACE", {item["code"] for item in result["findings"]})

    def test_rpc_change_requires_schema_contract_domain_and_deploy_boundary(self) -> None:
        required = HARNESS.required_docs_surfaces(
            "pre-review", ["supabase/migrations/20990101000000_example.sql"]
        )
        self.assertTrue(
            {"live_schema", "rpc_reference", "domain_rules", "deploy_boundary", "tests"}
            .issubset(required)
        )

    def test_all_five_checkpoint_kinds_have_stable_required_surfaces(self) -> None:
        goal = HARNESS.minimal_goal_for_test()
        expected = {
            "pre-commit", "pre-review", "handoff", "post-merge", "final"
        }
        self.assertEqual(expected, HARNESS.CHECKPOINT_KINDS)
        for checkpoint in sorted(expected):
            evaluations = self._passing_evaluations(
                checkpoint, [], goal=goal, publishing=checkpoint == "final"
            )
            result = HARNESS.evaluate_docs_update(
                ROOT,
                checkpoint,
                evaluations,
                goal=goal,
                changed_paths=[],
                publishing=checkpoint == "final",

                actor_role="root",
            )
            if checkpoint == "final":
                self.assertIn("MISSING_FINAL_REPORT", {item["code"] for item in result["findings"]})
            else:
                self.assertNotIn("MISSING_SURFACE_EVALUATION", {item["code"] for item in result["findings"]})

    def test_receipt_is_bound_to_head_and_diff_hash(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            (root / "README.md").write_text("first change\n", encoding="utf-8")
            evaluations = self._passing_evaluations("pre-commit", ["README.md"])
            result = HARNESS.evaluate_docs_update(
                root, "pre-commit", evaluations, changed_paths=["README.md"]
,
                actor_role="root",
            )
            self.assertEqual("PASS", result["verdict"])
            receipt_path = HARNESS.write_docs_receipt(root, result["receipt"])
            self.assertTrue(HARNESS.check_docs_receipt(root, receipt_path)["ok"])

            (root / "README.md").write_text("second change\n", encoding="utf-8")
            checked = HARNESS.check_docs_receipt(root, receipt_path)
            self.assertFalse(checked["ok"])
            self.assertIn("STALE_RECEIPT_DIFF", {item["code"] for item in checked["findings"]})

    def test_receipt_detects_mode_only_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            (root / "README.md").write_text("changed\n", encoding="utf-8")
            evaluations = self._passing_evaluations("pre-commit", ["README.md"])
            result = HARNESS.evaluate_docs_update(
                root, "pre-commit", evaluations, changed_paths=["README.md"]
,
                actor_role="root",
            )
            receipt_path = HARNESS.write_docs_receipt(root, result["receipt"])
            (root / "README.md").chmod(0o755)
            checked = HARNESS.check_docs_receipt(root, receipt_path)
            self.assertIn("STALE_RECEIPT_DIFF", {item["code"] for item in checked["findings"]})

    def test_fake_pass_without_receipt_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            checked = HARNESS.check_docs_receipt(
                root, root / ".harness/cache/DOCS-RECEIPT.json", expected_verdict="PASS"
            )
            self.assertFalse(checked["ok"])
            self.assertEqual("MISSING_DOCS_RECEIPT", checked["findings"][0]["code"])

    def test_cli_requires_explicit_role_attestation(self) -> None:
        result = subprocess.run(
            [sys.executable, str(MODULE_PATH), "docs-update", "pre-commit"],
            cwd=ROOT,
            check=False,
            text=True,
            capture_output=True,
        )
        self.assertEqual(2, result.returncode)
        self.assertIn("--role", result.stderr)

    def test_receipt_without_explicit_role_attestation_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            (root / "README.md").write_text("changed\n", encoding="utf-8")
            evaluations = self._passing_evaluations("pre-commit", ["README.md"])
            result = HARNESS.evaluate_docs_update(
                root, "pre-commit", evaluations, changed_paths=["README.md"],
                actor_role="root",
            )
            receipt = dict(result["receipt"])
            del receipt["actor_role"]
            receipt_path = HARNESS.write_docs_receipt(root, receipt)
            checked = HARNESS.check_docs_receipt(root, receipt_path)
            self.assertFalse(checked["ok"])
            self.assertIn(
                "INVALID_RECEIPT_ROLE", {item["code"] for item in checked["findings"]}
            )

    def test_state_and_config_changes_require_ui_map_evaluation(self) -> None:
        required = HARNESS.required_docs_surfaces(
            "pre-commit", ["js/state.js"], goal=None, publishing=False
        )
        self.assertTrue({"ui_map", "ui_patterns", "tests"}.issubset(required))
        config_required = HARNESS.required_docs_surfaces(
            "pre-commit", ["js/config.js"], goal=None, publishing=False
        )
        self.assertTrue("ui_map" in config_required)
        result = HARNESS.evaluate_docs_update(
            ROOT,
            "pre-commit",
            {"tests": "NO_CHANGE_REQUIRED"},
            changed_paths=["js/config.js"],

            actor_role="root",
        )
        self.assertEqual("FAIL", result["verdict"])
        self.assertIn("MISSING_SURFACE_EVALUATION", {item["code"] for item in result["findings"]})
        missing = {item["path"] for item in result["findings"] if item["code"] == "MISSING_SURFACE_EVALUATION"}
        self.assertTrue(any("ui_map" in path for path in missing), missing)

    def test_edge_function_change_requires_domain_and_deploy_evaluation(self) -> None:
        required = HARNESS.required_docs_surfaces(
            "pre-commit", ["supabase/functions/stat-hesapla/index.ts"], goal=None, publishing=False
        )
        self.assertTrue({"domain_rules", "deploy_boundary", "tests"}.issubset(required))
        self.assertNotIn("live_schema", required)

    def test_pre_commit_with_goal_requires_goal_report(self) -> None:
        goal = HARNESS.minimal_goal_for_test()
        result = HARNESS.evaluate_docs_update(
            ROOT,
            "pre-commit",
            {"tests": "NO_CHANGE_REQUIRED"},
            goal=goal,
            actor_role="root",
            changed_paths=["example.txt"],
        )
        missing = {item["path"] for item in result["findings"] if item["code"] == "MISSING_SURFACE_EVALUATION"}
        self.assertTrue(any("goal_report" in path for path in missing), missing)

    def test_actor_role_must_be_explicit(self) -> None:
        result = HARNESS.evaluate_docs_update(
            ROOT,
            "pre-commit",
            {"tests": "NO_CHANGE_REQUIRED"},
            changed_paths=["README.md"],
        )
        self.assertIn("INVALID_DOCS_ACTOR", {item["code"] for item in result["findings"]})

    def test_unbound_active_goal_worktree_warns(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            head = git(root, "rev-parse", "HEAD")
            goal_dir = root / ".harness" / "goals" / "2026"
            report_dir = root / ".harness" / "reports" / "2026"
            goal_dir.mkdir(parents=True)
            report_dir.mkdir(parents=True)
            report_dir.joinpath("G-20990101-TEST.md").write_text(
                "# r\n\nGoal: `G-20990101-TEST`\n\nDate: 2099-01-01\n\nFlow: `inline`\n\nRoot verdict: `IN_PROGRESS`\n",
                encoding="utf-8",
            )
            frontmatter = (
                "---\nid: G-20990101-TEST\nstatus: active\nowner: root\nflow: inline\n"
                "created: 2099-01-01\nbase_sha: " + head + "\nlaunch_sha: " + head + "\n"
                "branch: main\nworktree: " + str(root) + "\nwrite_manifest:\n  - README.md\n"
                "docs_authority:\n  tracked_paths:\n    write:\n      - README.md\n    append: []\n"
                "  local_paths:\n    write: []\n    append: []\n  db: none\npattern_refs: []\n"
                "acceptance:\n  - a\nstop_conditions:\n  - s\n"
                "report: .harness/reports/2026/G-20990101-TEST.md\n"
                "checkpoint:\n  sequence: 0\n  kind: null\n  head: null\n  docs_verdict: null\n---\n\n# goal\n"
            )
            goal_dir.joinpath("G-20990101-TEST.md").write_text(frontmatter, encoding="utf-8")
            (root / "README.md").write_text("changed\n", encoding="utf-8")
            result = HARNESS.evaluate_docs_update(
                root,
                "pre-commit",
                {"tests": "NO_CHANGE_REQUIRED"},
                actor_role="root",
                changed_paths=["README.md"],
            )
            warning = [item for item in result["findings"] if item["code"] == "ACTIVE_GOAL_UNBOUND"]
            self.assertEqual(1, len(warning))
            self.assertEqual("WARNING", warning[0]["level"])
            self.assertEqual("PASS", result["verdict"])


if __name__ == "__main__":
    unittest.main()
