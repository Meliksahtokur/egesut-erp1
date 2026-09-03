"""Manifest, documentation authority, and DB evidence tests."""

from __future__ import annotations

import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / ".harness" / "bin" / "harness.py"
SPEC = importlib.util.spec_from_file_location("egesut_harness_docs_authority", MODULE_PATH)
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
    (root / ".gitignore").write_text("/.claude/\n/.harness/cache/\n", encoding="utf-8")
    (root / "docs").mkdir()
    (root / "docs/owned.md").write_text("owned\n", encoding="utf-8")
    (root / "docs/outside.md").write_text("outside\n", encoding="utf-8")
    (root / "product.txt").write_text("product\n", encoding="utf-8")
    git(root, "add", ".gitignore", "docs", "product.txt")
    git(root, "commit", "-qm", "baseline")


def goal_for(root: Path) -> dict:
    goal = HARNESS.minimal_goal_for_test()
    goal.update(
        {
            "worktree": str(root),
            "write_manifest": ["docs/owned.md", "product.txt"],
            "docs_authority": {
                "tracked_paths": {"write": ["docs/owned.md"], "append": []},
                "local_paths": {"write": [], "append": []},
                "db": "none",
                "propose_only": ["docs/outside.md", ".claude/**"],
            },
        }
    )
    return goal


class DocsAuthorityTests(unittest.TestCase):
    def test_full_goal_manifest_cannot_use_wildcards_as_write_authority(self) -> None:
        goal = HARNESS.minimal_goal_for_test()
        goal["write_manifest"] = ["docs/**"]
        goal["docs_authority"]["tracked_paths"]["write"] = []
        meta_codes = {
            item["code"] for item in HARNESS.validate_goal_meta(goal, Path("goal.md"))
        }
        self.assertIn("WILDCARD_MANIFEST_PATH", meta_codes)
        result = HARNESS.evaluate_docs_update(
            ROOT,
            "pre-commit",
            {"tests": "NO_CHANGE_REQUIRED"},
            goal=goal,
            changed_paths=["docs/unbounded.md"],

            actor_role="root",
        )
        self.assertIn("MANIFEST_VIOLATION", {item["code"] for item in result["findings"]})

    def test_lead_cannot_write_docs_without_goal_authority(self) -> None:
        result = HARNESS.evaluate_docs_update(
            ROOT,
            "pre-commit",
            {"tests": "NO_CHANGE_REQUIRED"},
            actor_role="lead",
            changed_paths=["docs/unowned.md"],
        )
        self.assertIn(
            "LEAD_DOCS_GOAL_REQUIRED", {item["code"] for item in result["findings"]}
        )

    def test_lead_tracked_doc_write_outside_authority_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            (root / "docs/outside.md").write_text("changed\n", encoding="utf-8")
            result = HARNESS.evaluate_docs_update(
                root,
                "pre-commit",
                {"tests": "NO_CHANGE_REQUIRED"},
                goal=goal_for(root),
                actor_role="lead",
                changed_paths=["docs/outside.md"],
            )
            codes = {item["code"] for item in result["findings"]}
            self.assertIn("MANIFEST_VIOLATION", codes)
            self.assertIn("UNAUTHORIZED_TRACKED_DOC", codes)

    def test_ignored_local_policy_requires_explicit_local_authority(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            policy = root / ".claude/policy.md"
            policy.parent.mkdir()
            policy.write_text("local policy\n", encoding="utf-8")
            result = HARNESS.evaluate_docs_update(
                root,
                "handoff",
                {
                    "goal_report": "NO_CHANGE_REQUIRED",
                    "blockers_risks": "NO_CHANGE_REQUIRED",
                    "next_action": "NO_CHANGE_REQUIRED",
                },
                goal=goal_for(root),
                actor_role="lead",
                changed_paths=[],
                local_paths=[".claude/policy.md"],
            )
            self.assertIn(
                "UNAUTHORIZED_LOCAL_DOC", {item["code"] for item in result["findings"]}
            )

    def test_authorized_local_glob_is_accepted(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            goal = goal_for(root)
            goal["docs_authority"]["local_paths"]["write"] = [".claude/**"]
            evaluations = {
                "goal_report": "NO_CHANGE_REQUIRED",
                "blockers_risks": "NO_CHANGE_REQUIRED",
                "next_action": "NO_CHANGE_REQUIRED",
            }
            result = HARNESS.evaluate_docs_update(
                root,
                "handoff",
                evaluations,
                goal=goal,
                actor_role="lead",
                changed_paths=[],
                local_paths=[".claude/policy.md"],
            )
            self.assertNotIn(
                "UNAUTHORIZED_LOCAL_DOC", {item["code"] for item in result["findings"]}
            )

    def test_root_full_goal_local_write_still_requires_declared_scope(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            result = HARNESS.evaluate_docs_update(
                root,
                "handoff",
                {
                    "goal_report": "NO_CHANGE_REQUIRED",
                    "blockers_risks": "NO_CHANGE_REQUIRED",
                    "next_action": "NO_CHANGE_REQUIRED",
                },
                goal=goal_for(root),
                actor_role="root",
                changed_paths=[],
                local_paths=[".claude/policy.md"],
            )
            self.assertIn(
                "LOCAL_SCOPE_VIOLATION", {item["code"] for item in result["findings"]}
            )

    def test_unobservable_db_effect_cannot_be_claimed_verified(self) -> None:
        result = HARNESS.evaluate_docs_update(
            ROOT,
            "pre-commit",
            {"tests": "NO_CHANGE_REQUIRED"},
            changed_paths=[],
            db_observation="VERIFIED",

            actor_role="root",
        )
        self.assertEqual("FAIL", result["verdict"])
        self.assertIn("UNOBSERVABLE_DB_VERIFICATION", {item["code"] for item in result["findings"]})

    def test_db_attestation_requires_goal_db_authority(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            result = HARNESS.evaluate_docs_update(
                root,
                "pre-commit",
                {"tests": "NO_CHANGE_REQUIRED"},
                goal=goal_for(root),
                changed_paths=[],
                db_observation="ATTESTED",

                actor_role="root",
            )
            self.assertIn(
                "DB_AUTHORITY_VIOLATION", {item["code"] for item in result["findings"]}
            )

    def test_repeated_authority_failures_are_aggregated(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            result = HARNESS.evaluate_docs_update(
                root,
                "pre-commit",
                {"tests": "NO_CHANGE_REQUIRED"},
                goal=goal_for(root),
                actor_role="lead",
                changed_paths=["docs/outside.md", "docs/another.md"],
            )
            rows = [item for item in result["findings"] if item["code"] == "UNAUTHORIZED_TRACKED_DOC"]
            self.assertEqual(1, len(rows))
            self.assertEqual(2, rows[0]["count"])


if __name__ == "__main__":
    unittest.main()
