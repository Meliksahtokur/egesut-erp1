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


if __name__ == "__main__":
    unittest.main()
