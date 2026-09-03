"""Phase 1 acceptance tests for portable runtime discovery and thin adapters."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUNTIMES = ROOT / ".harness" / "runtimes"
ZCODE_CONFIG = ROOT / ".zcode" / "config.json"
GENERATED_START = "<!-- gitnexus:start -->"
GENERATED_END = "<!-- gitnexus:end -->"


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def authored_text(text: str) -> str:
    """Remove one exact GitNexus-generated marker region, if present."""
    starts = text.count(GENERATED_START)
    ends = text.count(GENERATED_END)
    if starts != ends or starts > 1:
        raise ValueError("unbalanced or repeated GitNexus marker region")
    if starts == 0:
        return text
    before, remainder = text.split(GENERATED_START, 1)
    _, after = remainder.split(GENERATED_END, 1)
    return before + after


def policy_copy_violations(text: str) -> list[str]:
    """Detect legacy policy facts that adapters must never embed."""
    forbidden = {
        "automatic push command": r"git\s+push\s+origin\s+main",
        "volatile schema count": r"\b(?:41|50)\s+tablo\b",
        "copied ID-type fact": r"gorev_log\.id\s*=",
        "copied MCP tool spelling": r"mcp__tools_bank_",
        "hook-directory policy": r"core\.hooksPath",
    }
    lowered = authored_text(text).lower()
    return [name for name, pattern in forbidden.items() if re.search(pattern, lowered)]


def configured_hook_paths(config: dict) -> list[Path]:
    paths: list[Path] = []
    events = config.get("hooks", {}).get("events", {})
    for groups in events.values():
        for group in groups:
            for hook in group.get("hooks", []):
                command = str(hook.get("command", ""))
                match = re.search(r"\$\{ZCODE_PROJECT_DIR\}/([^\s]+)", command)
                if match:
                    paths.append(ROOT / match.group(1))
    return paths


class RuntimeContractTests(unittest.TestCase):
    def test_required_phase1_files_exist(self) -> None:
        required = [
            "AGENTS.md",
            "CLAUDE.md",
            ".harness/README.md",
            ".harness/contract.md",
            ".harness/flow-routing.md",
            ".harness/acceptance.md",
            ".harness/task-modes.md",
            ".harness/runtimes/codex.md",
            ".harness/runtimes/claude.md",
            ".harness/runtimes/zcode.md",
            ".harness/runtimes/herdr.md",
            ".zcode/config.json",
            ".zcode/hooks/session_contract.py",
            ".zcode/hooks/commit_guard.py",
            ".zcode/hooks/js_edit_guard.py",
        ]
        missing = [path for path in required if not (ROOT / path).is_file()]
        self.assertEqual([], missing)

    def test_root_entrypoints_are_short(self) -> None:
        self.assertLessEqual(len(read("AGENTS.md").splitlines()), 80)
        self.assertLessEqual(len(read("CLAUDE.md").splitlines()), 40)

    def test_agents_entrypoint_is_a_map_not_a_second_manual(self) -> None:
        agents = read("AGENTS.md")
        headings = set(re.findall(r"^## (.+)$", agents, flags=re.MULTILINE))
        self.assertEqual(
            {"Start here", "Project shape", "Task routing", "Runtime selection"},
            headings,
        )
        self.assertNotIn("## Non-negotiable reminders", agents)

    def test_claude_imports_agents_first(self) -> None:
        first = next(line for line in read("CLAUDE.md").splitlines() if line.strip())
        self.assertEqual("@AGENTS.md", first)

    def test_contract_version_matches_agents_entrypoint(self) -> None:
        contract = re.search(r"Contract version: `([^`]+)`", read(".harness/contract.md"))
        agents = re.search(r"Harness contract version: `([^`]+)`", read("AGENTS.md"))
        self.assertIsNotNone(contract)
        self.assertIsNotNone(agents)
        self.assertEqual(contract.group(1), agents.group(1))

    def test_runtime_adapters_are_thin_and_point_to_contract(self) -> None:
        for adapter in sorted(RUNTIMES.glob("*.md")):
            with self.subTest(adapter=adapter.name):
                text = adapter.read_text(encoding="utf-8")
                self.assertIn("Shared policy: `../contract.md`", text)
                self.assertLessEqual(len(text.splitlines()), 40)
                self.assertEqual([], policy_copy_violations(text))

    def test_policy_copy_detector_rejects_legacy_samples(self) -> None:
        sample = "git push origin main; 41 tablo; gorev_log.id = uuid"
        self.assertGreaterEqual(len(policy_copy_violations(sample)), 3)

    def test_entrypoints_have_no_gitnexus_file_injection(self) -> None:
        for relative in ("AGENTS.md", "CLAUDE.md"):
            with self.subTest(relative=relative):
                text = read(relative)
                self.assertNotIn(GENERATED_START, text)
                self.assertNotIn(GENERATED_END, text)

    def test_entrypoints_do_not_link_ignored_agent_skills(self) -> None:
        entrypoints = read("AGENTS.md") + read(".harness/contract.md")
        self.assertNotIn(".agents/", entrypoints)
        self.assertNotIn(".claude/farm-id-discipline.md", entrypoints)

    def test_canonical_product_references_exist_in_worktree(self) -> None:
        references = [
            ".harness/references/domain-rules.md",
            ".harness/references/rpc-reference.md",
            ".harness/references/ui-map.md",
        ]
        self.assertEqual([], [path for path in references if not (ROOT / path).is_file()])
        retired = [
            ".claude/domain-rules.md",
            ".claude/rpc-reference.md",
            ".claude/ui-map.md",
        ]
        self.assertEqual(
            [], [path for path in retired if (ROOT / path).exists()],
            "transitional copies must stay retired (D-20260904-PHASE6-LEGACY-RETIREMENT)",
        )

    def test_zcode_config_references_all_existing_hooks(self) -> None:
        config = json.loads(ZCODE_CONFIG.read_text(encoding="utf-8"))
        paths = configured_hook_paths(config)
        self.assertEqual(3, len(paths))
        self.assertEqual([], [str(path) for path in paths if not path.is_file()])

    def test_zcode_session_hook_reads_tracked_contract(self) -> None:
        source = read(".zcode/hooks/session_contract.py")
        self.assertIn('".harness" / "contract.md"', source)
        self.assertNotIn("CONTEXT =", source)
        self.assertEqual([], policy_copy_violations(source))

        env = os.environ.copy()
        env["ZCODE_PROJECT_DIR"] = str(ROOT)
        result = subprocess.run(
            [sys.executable, str(ROOT / ".zcode/hooks/session_contract.py")],
            input="{}",
            text=True,
            capture_output=True,
            check=True,
            env=env,
        )
        payload = json.loads(result.stdout)
        self.assertEqual(read(".harness/contract.md"), payload["additionalContext"])

    def test_zcode_is_builtin_and_herdr_is_not_default(self) -> None:
        adapter = read(".harness/runtimes/zcode.md").lower()
        self.assertIn("defaults to its built-in agents", adapter)
        self.assertNotRegex(adapter, r"defaults?\s+to\s+herdr")

    def test_canonical_phase1_paths_are_not_ignored(self) -> None:
        paths = [
            "AGENTS.md",
            "CLAUDE.md",
            ".harness/reports/2026/G-20260902-UNIFIED-HARNESS-PHASE01.md",
            ".zcode/hooks/session_contract.py",
            ".zcode/hooks/commit_guard.py",
            ".zcode/hooks/js_edit_guard.py",
            "tests/harness/test_runtime_contract.py",
        ]
        for relative in paths:
            with self.subTest(relative=relative):
                result = subprocess.run(
                    ["git", "check-ignore", "--no-index", "--quiet", relative],
                    cwd=ROOT,
                    check=False,
                )
                self.assertEqual(1, result.returncode)

    def test_harness_cache_is_ignored(self) -> None:
        result = subprocess.run(
            ["git", "check-ignore", "--no-index", "--quiet", ".harness/cache/probe"],
            cwd=ROOT,
            check=False,
        )
        self.assertEqual(0, result.returncode)

    def test_disposable_committed_tree_preserves_discovery_files(self) -> None:
        portable = [
            ".gitignore",
            "AGENTS.md",
            "CLAUDE.md",
            ".harness/README.md",
            ".harness/contract.md",
            ".harness/flow-routing.md",
            ".harness/acceptance.md",
            ".harness/task-modes.md",
            ".harness/runtimes/codex.md",
            ".harness/runtimes/claude.md",
            ".harness/runtimes/zcode.md",
            ".harness/runtimes/herdr.md",
            ".harness/reports/2026/G-20260902-UNIFIED-HARNESS-PHASE01.md",
            ".zcode/config.json",
            ".zcode/hooks/session_contract.py",
            ".zcode/hooks/commit_guard.py",
            ".zcode/hooks/js_edit_guard.py",
            "tests/harness/test_runtime_contract.py",
        ]
        with tempfile.TemporaryDirectory(prefix="egesut-harness-discovery-") as temp:
            repository = Path(temp) / "repo"
            linked = Path(temp) / "linked"
            repository.mkdir()
            subprocess.run(["git", "init", "-q"], cwd=repository, check=True)
            for relative in portable:
                destination = repository / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / relative, destination)
            subprocess.run(["git", "add", *portable], cwd=repository, check=True)
            subprocess.run(
                [
                    "git",
                    "-c",
                    "user.name=Harness Test",
                    "-c",
                    "user.email=harness-test@invalid",
                    "commit",
                    "-qm",
                    "test fixture",
                ],
                cwd=repository,
                check=True,
            )
            subprocess.run(
                ["git", "worktree", "add", "--detach", str(linked), "HEAD"],
                cwd=repository,
                check=True,
                capture_output=True,
                text=True,
            )
            missing = [relative for relative in portable if not (linked / relative).is_file()]
            self.assertEqual([], missing)
            status = subprocess.run(
                ["git", "status", "--porcelain=v1", "--untracked-files=all"],
                cwd=linked,
                check=True,
                capture_output=True,
                text=True,
            )
            self.assertEqual("", status.stdout)

    def test_mvp_does_not_install_git_hooks(self) -> None:
        self.assertFalse((ROOT / ".harness" / "githooks").exists())
        combined = "\n".join(
            [
                read(".harness/README.md"),
                read(".harness/flow-routing.md"),
                *[path.read_text(encoding="utf-8") for path in RUNTIMES.glob("*.md")],
            ]
        )
        self.assertNotIn("git config core.hooksPath", combined)


if __name__ == "__main__":
    unittest.main()
