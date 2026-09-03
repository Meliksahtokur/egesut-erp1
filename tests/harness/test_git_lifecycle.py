"""Git lifecycle gate tests: commit-gate and push-gate."""

from __future__ import annotations

import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / ".harness" / "bin" / "harness.py"
SPEC = importlib.util.spec_from_file_location("egesut_harness_git_lifecycle", MODULE_PATH)
HARNESS = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(HARNESS)


def git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args], cwd=root, check=True, text=True, capture_output=True
    )
    return result.stdout.strip()


def init_repo(root: Path) -> None:
    git(root, "init", "-q", "-b", "main")
    git(root, "config", "user.name", "Harness Test")
    git(root, "config", "user.email", "harness-test@invalid")
    (root / ".gitignore").write_text("/.harness/cache/\n", encoding="utf-8")
    (root / "README.md").write_text("baseline\n", encoding="utf-8")
    git(root, "add", ".gitignore", "README.md")
    git(root, "commit", "-qm", "baseline")


def stage_change(root: Path, name: str = "README.md", content: str = "changed\n") -> None:
    (root / name).write_text(content, encoding="utf-8")
    git(root, "add", "--", name)


def write_staged_receipt(root: Path, checkpoint: str = "pre-commit") -> Path:
    paths = HARNESS.current_changed_paths(root, "staged")
    evaluations = {
        surface: "NO_CHANGE_REQUIRED"
        for surface in HARNESS.required_docs_surfaces(checkpoint, paths)
    }
    result = HARNESS.evaluate_docs_update(
        root,
        checkpoint,
        evaluations,
        actor_role="root",
        changed_paths=paths,
        scope="staged",
    )
    assert result["verdict"] == "PASS", result["findings"]
    return HARNESS.write_docs_receipt(root, result["receipt"])


def message_file(root: Path, message: str) -> Path:
    path = root / ".harness" / "cache" / "COMMIT-MSG.tmp"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(message, encoding="utf-8")
    return path


class CommitGateTests(unittest.TestCase):
    def test_fast_commit_with_current_staged_receipt_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            stage_change(root)
            receipt = write_staged_receipt(root)
            result = HARNESS.commit_gate(root)
            self.assertTrue(result["ok"], result["findings"])
            self.assertEqual(str(receipt), result["receipt_path"])

    def test_missing_or_stale_staged_receipt_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            stage_change(root)
            result = HARNESS.commit_gate(root)
            self.assertFalse(result["ok"])
            codes = {item["code"] for item in result["findings"]}
            self.assertIn("MISSING_DOCS_RECEIPT", codes)

            write_staged_receipt(root)
            (root / "extra.md").write_text("new staged file\n", encoding="utf-8")
            git(root, "add", "--", "extra.md")
            result = HARNESS.commit_gate(root)
            self.assertFalse(result["ok"])
            codes = {item["code"] for item in result["findings"]}
            self.assertIn("STALE_RECEIPT_PATHS", codes)

    def test_fabricated_docs_trailer_without_receipt_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            stage_change(root)
            result = HARNESS.commit_gate(
                root,
                message_file=message_file(root, "subject\n\nDocs-Update: PASS\n"),
            )
            self.assertFalse(result["ok"])
            codes = {item["code"] for item in result["findings"]}
            self.assertIn("FABRICATED_DOCS_TRAILER", codes)

    def test_trailer_verdict_must_match_receipt(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            stage_change(root)
            write_staged_receipt(root)
            result = HARNESS.commit_gate(
                root,
                message_file=message_file(root, "subject\n\nDocs-Update: PARTIAL\n"),
            )
            self.assertFalse(result["ok"])
            codes = {item["code"] for item in result["findings"]}
            self.assertIn("FABRICATED_DOCS_TRAILER", codes)

    def test_tests_trailer_is_refused_without_a_receipt_kind(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            stage_change(root)
            write_staged_receipt(root)
            result = HARNESS.commit_gate(
                root,
                message_file=message_file(root, "subject\n\nTests: PASS\n"),
            )
            self.assertFalse(result["ok"])
            codes = {item["code"] for item in result["findings"]}
            self.assertIn("UNSUPPORTED_TESTS_TRAILER", codes)

    def test_unenriched_message_is_valid(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            stage_change(root)
            write_staged_receipt(root)
            result = HARNESS.commit_gate(root, message_file=message_file(root, "plain subject\n"))
            self.assertTrue(result["ok"], result["findings"])

    def test_goal_manifest_violation_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            (root / "docs").mkdir()
            (root / "docs/owned.md").write_text("owned\n", encoding="utf-8")
            (root / "docs/outside.md").write_text("outside\n", encoding="utf-8")
            git(root, "add", "docs")
            git(root, "commit", "-qm", "docs baseline")
            (root / "docs/outside.md").write_text("changed\n", encoding="utf-8")
            git(root, "add", "--", "docs/outside.md")
            goal = HARNESS.minimal_goal_for_test()
            goal["write_manifest"] = ["docs/owned.md"]
            write_staged_receipt(root)
            result = HARNESS.commit_gate(root, goal=goal)
            self.assertFalse(result["ok"])
            codes = {item["code"] for item in result["findings"]}
            self.assertIn("MANIFEST_VIOLATION", codes)

    def test_hook_state_is_reported_without_mutating_it(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            stage_change(root)
            write_staged_receipt(root)
            hook = root / ".git" / "hooks" / "pre-commit"
            hook.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
            result = HARNESS.commit_gate(root)
            self.assertTrue(result["ok"])
            self.assertEqual("present", result["pre_commit_hook"])
            self.assertTrue(hook.is_file())

            hook.unlink()
            result = HARNESS.commit_gate(root)
            self.assertTrue(result["ok"])
            self.assertEqual("missing", result["pre_commit_hook"])
            self.assertTrue(
                any(
                    item["code"] == "NO_PRE_COMMIT_HOOK" and item["level"] == "WARNING"
                    for item in result["findings"]
                )
            )

            git(root, "config", "core.hooksPath", ".githooks")
            result = HARNESS.commit_gate(root)
            self.assertFalse(result["ok"])
            codes = {item["code"] for item in result["findings"]}
            self.assertIn("HOOKS_PATH_SET", codes)


class PushGateTests(unittest.TestCase):
    def _finalized_goal(self, head: str) -> dict:
        goal = HARNESS.minimal_goal_for_test()
        goal["checkpoint"] = {
            "sequence": 3,
            "kind": "final(publishing=true)",
            "head": head,
            "docs_verdict": "PASS",
        }
        return goal

    def test_requires_goal_or_receipt_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            result = HARNESS.push_gate(root)
            self.assertFalse(result["ok"])
            codes = {item["code"] for item in result["findings"]}
            self.assertIn("NO_ACCEPTANCE_EVIDENCE", codes)

    def test_goal_must_be_finalized_publishing_pass(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            head = git(root, "rev-parse", "HEAD")
            goal = self._finalized_goal(head)
            goal["checkpoint"]["kind"] = "pre-review"
            result = HARNESS.push_gate(root, goal=goal, remote="HEAD")
            self.assertFalse(result["ok"])
            codes = {item["code"] for item in result["findings"]}
            self.assertIn("NOT_FINALIZED", codes)

    def test_publish_range_is_fast_forward_and_printed(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            base = git(root, "rev-parse", "HEAD")
            stage_change(root)
            git(root, "commit", "-qm", "candidate")
            head = git(root, "rev-parse", "HEAD")
            goal = self._finalized_goal(head)
            result = HARNESS.push_gate(root, goal=goal, remote=base)
            self.assertTrue(result["ok"], result["findings"])
            self.assertEqual(f"{base}..{head}", result["remote_range"])
            self.assertIn("push is not deploy", result["deploy_boundary"])

    def test_non_fast_forward_remote_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            stage_change(root)
            git(root, "commit", "-qm", "candidate")
            head = git(root, "rev-parse", "HEAD")
            diverged = git(root, "commit-tree", "HEAD^{tree}", "-m", "diverged")
            goal = self._finalized_goal(head)
            result = HARNESS.push_gate(root, goal=goal, remote=diverged)
            self.assertFalse(result["ok"])
            codes = {item["code"] for item in result["findings"]}
            self.assertIn("NOT_FAST_FORWARD", codes)

    def test_stale_final_receipt_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            stage_change(root)
            receipt = write_staged_receipt(root, checkpoint="final")
            git(root, "commit", "-qm", "candidate")
            result = HARNESS.push_gate(root, receipt=receipt)
            self.assertFalse(result["ok"])
            codes = {item["code"] for item in result["findings"]}
            self.assertIn("STALE_RECEIPT_HEAD", codes)

    def test_dirty_path_inside_publish_range_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            base = git(root, "rev-parse", "HEAD")
            stage_change(root, "README.md", "committed change\n")
            git(root, "commit", "-qm", "candidate")
            head = git(root, "rev-parse", "HEAD")
            (root / "README.md").write_text("local dirt on a published path\n", encoding="utf-8")
            goal = self._finalized_goal(head)
            result = HARNESS.push_gate(root, goal=goal, remote=base)
            self.assertFalse(result["ok"])
            codes = {item["code"] for item in result["findings"]}
            self.assertIn("DIRTY_RANGE_PATHS", codes)

    def test_commit_gate_receipt_binds_to_gate_goal(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            stage_change(root)
            write_staged_receipt(root)
            goal = HARNESS.minimal_goal_for_test()
            goal["write_manifest"] = ["README.md"]
            result = HARNESS.commit_gate(root, goal=goal)
            self.assertFalse(result["ok"])
            codes = {item["code"] for item in result["findings"]}
            self.assertIn("RECEIPT_GOAL_MISMATCH", codes)

    def test_commit_gate_goal_bound_receipt_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            stage_change(root)
            paths = HARNESS.current_changed_paths(root, "staged")
            evaluations = {
                surface: "NO_CHANGE_REQUIRED"
                for surface in HARNESS.required_docs_surfaces("pre-commit", paths, goal=True)
            }
            goal = HARNESS.minimal_goal_for_test()
            goal["write_manifest"] = ["README.md"]
            goal_dir = root / ".harness" / "goals" / "2026"
            report_dir = root / ".harness" / "reports" / "2026"
            goal_dir.mkdir(parents=True, exist_ok=True)
            report_dir.mkdir(parents=True, exist_ok=True)
            report_dir.joinpath("G-20990101-TEST.md").write_text(
                "# r\n\nGoal: `G-20990101-TEST`\n\nDate: 2099-01-01\n\nFlow: `inline`\n\nRoot verdict: `IN_PROGRESS`\n",
                encoding="utf-8",
            )
            goal_dir.joinpath("G-20990101-TEST.md").write_text(
                "---\nid: G-20990101-TEST\nstatus: active\nowner: root\nflow: inline\n"
                "created: 2099-01-01\nbase_sha: " + git(root, "rev-parse", "HEAD")
                + "\nlaunch_sha: " + git(root, "rev-parse", "HEAD")
                + "\nbranch: main\nworktree: " + str(root)
                + "\nwrite_manifest:\n  - README.md\ndocs_authority:\n"
                "  tracked_paths:\n    write:\n      - README.md\n    append: []\n"
                "  local_paths:\n    write: []\n    append: []\n  db: none\npattern_refs: []\n"
                "acceptance:\n  - a\nstop_conditions:\n  - s\n"
                "report: .harness/reports/2026/G-20990101-TEST.md\n"
                "checkpoint:\n  sequence: 0\n  kind: null\n  head: null\n  docs_verdict: null\n---\n\n# goal\n",
                encoding="utf-8",
            )
            result = HARNESS.evaluate_docs_update(
                root, "pre-commit", evaluations,
                goal=goal, actor_role="root", changed_paths=paths, scope="staged",
            )
            HARNESS.write_docs_receipt(root, result["receipt"])
            gated = HARNESS.commit_gate(root, goal=goal)
            self.assertTrue(gated["ok"], gated["findings"])

    def test_push_gate_receipt_must_be_final_publishing(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            stage_change(root)
            pre_commit_receipt = write_staged_receipt(root, checkpoint="pre-commit")
            git(root, "commit", "-qm", "candidate")
            result = HARNESS.push_gate(root, receipt=pre_commit_receipt)
            self.assertFalse(result["ok"])
            codes = {item["code"] for item in result["findings"]}
            self.assertIn("NOT_FINAL_RECEIPT", codes)

            git(root, "reset", "--hard", "-q")
            evaluations = {
                surface: "NO_CHANGE_REQUIRED"
                for surface in HARNESS.required_docs_surfaces("final", [], publishing=True)
            }
            final_result = HARNESS.evaluate_docs_update(
                root, "final", evaluations, actor_role="root", scope="all", publishing=True
            )
            final_receipt = HARNESS.write_docs_receipt(root, final_result["receipt"])
            result = HARNESS.push_gate(root, receipt=final_receipt, remote="HEAD")
            self.assertTrue(result["ok"], result["findings"])

    def test_push_gate_remote_name_prefers_tracking_ref(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            base = git(root, "rev-parse", "HEAD")
            stage_change(root)
            git(root, "commit", "-qm", "candidate")
            head = git(root, "rev-parse", "HEAD")
            diverged = git(root, "commit-tree", "HEAD^{tree}", "-m", "diverged")
            git(root, "update-ref", "refs/remotes/origin/main", diverged)
            git(root, "tag", "origin/main", base)
            goal = self._finalized_goal(head)
            result = HARNESS.push_gate(root, goal=goal, remote="origin/main")
            self.assertFalse(result["ok"])
            codes = {item["code"] for item in result["findings"]}
            self.assertIn("NOT_FAST_FORWARD", codes)

    def test_dirty_typechange_inside_publish_range_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            base = git(root, "rev-parse", "HEAD")
            stage_change(root, "README.md", "committed change\n")
            git(root, "commit", "-qm", "candidate")
            head = git(root, "rev-parse", "HEAD")
            (root / "README.md").unlink()
            (root / "README.md").symlink_to("/etc/hostname")
            goal = self._finalized_goal(head)
            result = HARNESS.push_gate(root, goal=goal, remote=base)
            self.assertFalse(result["ok"])
            codes = {item["code"] for item in result["findings"]}
            self.assertIn("DIRTY_RANGE_PATHS", codes)

    def test_unenriched_commit_keeps_basic_queryability(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            init_repo(root)
            stage_change(root)
            git(root, "commit", "-qm", "plain fast commit")
            entries = HARNESS.git_history(root, 5)
            entry = next(item for item in entries if "plain fast commit" in item["subject"])
            self.assertIsNone(entry["goal"])
            self.assertIsNone(entry["flow"])
            self.assertIn("README.md", entry["paths"])


if __name__ == "__main__":
    unittest.main()
