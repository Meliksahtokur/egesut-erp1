"""Git-factual worktree and stale-goal tests."""

from __future__ import annotations

import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / ".harness" / "bin" / "harness.py"
SPEC = importlib.util.spec_from_file_location("egesut_harness_worktrees", MODULE_PATH)
HARNESS = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(HARNESS)


def git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args], cwd=root, check=True, text=True, capture_output=True
    )
    return result.stdout.strip()


class WorktreeTests(unittest.TestCase):
    def test_git_owns_existence_and_goal_owns_intent(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            root = base / "repo"
            linked = base / "linked"
            root.mkdir()
            git(root, "init", "-q")
            git(root, "config", "user.name", "Harness Test")
            git(root, "config", "user.email", "harness-test@invalid")
            (root / "tracked.txt").write_text("ok\n", encoding="utf-8")
            git(root, "add", "tracked.txt")
            git(root, "commit", "-qm", "initial")
            git(root, "worktree", "add", "-q", "-b", "idle/test", str(linked), "HEAD")

            goal = HARNESS.minimal_goal_for_test()
            goal.update({"branch": "idle/test", "worktree": str(linked), "status": "active"})
            inventory = HARNESS.worktree_inventory(
                root, [{"meta": goal, "path": Path("goal.md")}]
            )
            row = next(item for item in inventory["worktrees"] if item["path"] == str(linked))
            self.assertEqual(["G-20990101-TEST"], row["goal_ids"])
            self.assertTrue(row["exists"])
            self.assertEqual([], inventory["recorded_missing"])

    def test_missing_recorded_worktree_is_a_discrepancy(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            git(root, "init", "-q")
            goal = HARNESS.minimal_goal_for_test()
            goal.update({"worktree": str(root / "missing"), "status": "active"})
            records = [{"meta": goal, "path": Path("goal.md")}]
            inventory = HARNESS.worktree_inventory(root, records)
            self.assertEqual("G-20990101-TEST", inventory["recorded_missing"][0]["goal_id"])
            stale = HARNESS.stale_goals(root, records)
            self.assertIn("recorded_worktree_missing", stale[0]["reasons"])
            findings = HARNESS.validate_worktree_contract(root, records)
            self.assertEqual("RECORDED_WORKTREE_MISSING", findings[0]["code"])

    def test_launch_sha_must_belong_to_live_worktree_history(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            root = base / "repo"
            linked = base / "linked"
            root.mkdir()
            git(root, "init", "-q")
            git(root, "config", "user.name", "Harness Test")
            git(root, "config", "user.email", "harness-test@invalid")
            (root / "tracked.txt").write_text("base\n", encoding="utf-8")
            git(root, "add", "tracked.txt")
            git(root, "commit", "-qm", "base")
            base_sha = git(root, "rev-parse", "HEAD")
            base_branch = git(root, "branch", "--show-current")

            git(root, "checkout", "-qb", "unrelated")
            (root / "unrelated.txt").write_text("other\n", encoding="utf-8")
            git(root, "add", "unrelated.txt")
            git(root, "commit", "-qm", "unrelated launch")
            unrelated_sha = git(root, "rev-parse", "HEAD")
            git(root, "checkout", "-q", base_branch)
            git(root, "worktree", "add", "-q", "-b", "idle/test", str(linked), base_sha)

            goal = HARNESS.minimal_goal_for_test()
            goal.update(
                {
                    "base_sha": base_sha,
                    "launch_sha": unrelated_sha,
                    "branch": "idle/test",
                    "worktree": str(linked),
                    "status": "active",
                }
            )
            findings = HARNESS.validate_worktree_contract(
                root, [{"meta": goal, "path": Path("goal.md")}]
            )
            self.assertIn(
                "LAUNCH_SHA_NOT_IN_WORKTREE_HISTORY",
                {item["code"] for item in findings},
            )


if __name__ == "__main__":
    unittest.main()
