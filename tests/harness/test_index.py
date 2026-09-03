"""Git history, canonical search, and generated-cache tests."""

from __future__ import annotations

import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / ".harness" / "bin" / "harness.py"
SPEC = importlib.util.spec_from_file_location("egesut_harness_index", MODULE_PATH)
HARNESS = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(HARNESS)


def git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args], cwd=root, check=True, text=True, capture_output=True
    )
    return result.stdout.strip()


class IndexTests(unittest.TestCase):
    def _repo(self, root: Path) -> None:
        git(root, "init", "-q")
        git(root, "config", "user.name", "Harness Test")
        git(root, "config", "user.email", "harness-test@invalid")
        (root / ".gitignore").write_text("/.harness/cache/\n", encoding="utf-8")
        (root / "note.txt").write_text("first\n", encoding="utf-8")
        git(root, "add", ".gitignore", "note.txt")
        git(root, "commit", "-qm", "docs: fast work without goal")

    def test_fast_commit_is_queryable_without_goal_or_trailers(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self._repo(root)
            entry = HARNESS.git_history(root)[0]
            self.assertEqual("docs: fast work without goal", entry["subject"])
            self.assertEqual([".gitignore", "note.txt"], entry["paths"])
            self.assertIsNone(entry["goal"])
            self.assertIsNone(entry["flow"])
            self.assertIsNone(entry["mode"])

    def test_merge_commit_paths_are_computed_against_first_parent(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self._repo(root)
            base_branch = git(root, "branch", "--show-current")
            git(root, "checkout", "-qb", "feature")
            (root / "feature.txt").write_text("feature\n", encoding="utf-8")
            git(root, "add", "feature.txt")
            git(root, "commit", "-qm", "feat: add feature")
            git(root, "checkout", "-q", base_branch)
            git(root, "merge", "--no-ff", "-m", "merge feature", "feature")
            entry = HARNESS.git_history(root)[0]
            self.assertEqual("merge feature", entry["subject"])
            self.assertEqual(["feature.txt"], entry["paths"])

    def test_search_reads_only_canonical_record_trees(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            report = root / ".harness/reports/2099/report.md"
            report.parent.mkdir(parents=True)
            report.write_text("Needle governance evidence\n", encoding="utf-8")
            outside = root / "outside.md"
            outside.write_text("Needle must not be indexed\n", encoding="utf-8")
            matches = HARNESS.search_records(root, "needle")
            self.assertEqual(1, len(matches))
            self.assertEqual(".harness/reports/2099/report.md", matches[0]["path"])

    def test_board_render_is_derived_and_cache_is_ignored(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self._repo(root)
            goal = HARNESS.minimal_goal_for_test()
            board = HARNESS.render_board([{"meta": goal, "path": Path("goal.md")}])
            self.assertIn("G-20990101-TEST", board)
            cache_path = HARNESS.write_cache(root, "BOARD.md", board)
            self.assertEqual(root / ".harness/cache/BOARD.md", cache_path)
            self.assertEqual("", git(root, "status", "--porcelain=v1"))


if __name__ == "__main__":
    unittest.main()
