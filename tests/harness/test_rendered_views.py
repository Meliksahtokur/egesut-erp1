"""Derived BOARD, HANDOFF, goal-index, and memory-index tests."""

from __future__ import annotations

import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / ".harness" / "bin" / "harness.py"
SPEC = importlib.util.spec_from_file_location("egesut_harness_rendered", MODULE_PATH)
HARNESS = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(HARNESS)


def git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args], cwd=root, check=True, text=True, capture_output=True
    )
    return result.stdout.strip()


class RenderedViewTests(unittest.TestCase):
    def test_harness_memory_directory_is_not_hidden_by_global_ignore_rules(self) -> None:
        result = subprocess.run(
            ["git", "check-ignore", "--quiet", ".harness/memory/README.md"],
            cwd=ROOT,
            check=False,
        )
        self.assertNotEqual(0, result.returncode)

    def test_memory_index_is_deterministic_and_excludes_readme(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            memory = root / ".harness/memory"
            memory.mkdir(parents=True)
            (memory / "README.md").write_text("# Guidance\n", encoding="utf-8")
            (memory / "z-last.md").write_text("# Zeta fact\n", encoding="utf-8")
            (memory / "a-first.md").write_text("# Alpha fact\n", encoding="utf-8")
            first = HARNESS.render_memory_index(root)
            second = HARNESS.render_memory_index(root)
            self.assertEqual(first, second)
            self.assertLess(first.index("Alpha fact"), first.index("Zeta fact"))
            self.assertNotIn("Guidance", first)

    def test_stale_cached_board_is_detected_without_becoming_authority(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            cache = root / ".harness/cache"
            cache.mkdir(parents=True)
            (cache / "BOARD.md").write_text("stale\n", encoding="utf-8")
            goal = HARNESS.minimal_goal_for_test()
            findings = HARNESS.rendered_cache_findings(
                root, [{"meta": goal, "path": Path("goal.md")}]
            )
            self.assertEqual("STALE_RENDERED_VIEW", findings[0]["code"])

    def test_all_four_views_write_only_to_ignored_cache(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            git(root, "init", "-q")
            (root / ".gitignore").write_text("/.harness/cache/\n", encoding="utf-8")
            git(root, "add", ".gitignore")
            git(root, "-c", "user.name=Harness Test", "-c", "user.email=test@invalid", "commit", "-qm", "baseline")
            goal = HARNESS.minimal_goal_for_test()
            goals = [{"meta": goal, "path": Path("goal.md")}]
            outputs = {
                "BOARD.md": HARNESS.render_board(goals),
                "HANDOFF.md": HARNESS.render_handoff(goals),
                "GOAL-INDEX.md": HARNESS.render_goal_index(goals),
                "MEMORY-INDEX.md": HARNESS.render_memory_index(root),
            }
            for name, content in outputs.items():
                path = HARNESS.write_cache(root, name, content)
                self.assertEqual(root / ".harness/cache" / name, path)
            self.assertEqual("", git(root, "status", "--porcelain=v1"))


if __name__ == "__main__":
    unittest.main()
