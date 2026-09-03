"""Pattern catalog, pattern_ref enforcement, and cited-symbol tests."""

from __future__ import annotations

import importlib.util
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / ".harness" / "bin" / "harness.py"
SPEC = importlib.util.spec_from_file_location("egesut_harness_patterns", MODULE_PATH)
HARNESS = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(HARNESS)

PATTERNS_DIR = ROOT / ".harness" / "patterns"
ANCHOR_RE = re.compile(r"`((?:js|supabase)/[A-Za-z0-9_./$-]+|index\.html):([A-Za-z0-9_$-]+)`")


def symbol_defined(source: str, symbol: str) -> bool:
    escaped = re.escape(symbol)
    definitions = (
        rf"function\s+{escaped}\b",
        rf"class\s+{escaped}\b",
        rf"(?:const|let|var)\s+{escaped}\b",
        rf"{escaped}\s*=\s*(?:async\s+)?(?:function|\()",
        rf"id=[\"']{escaped}[\"']",
        rf"data-[a-z-]+=[\"']{escaped}[\"']",
        rf"onclick=[\"']{escaped}\s*\(",
        rf"^\s+{escaped}\s*\([^)]*\)\s*\{{",
    )
    return any(
        re.search(pattern, source, flags=re.MULTILINE) for pattern in definitions
    )


def document_anchors(path: Path) -> set[tuple[str, str]]:
    return set(ANCHOR_RE.findall(path.read_text(encoding="utf-8")))


class PatternRefEnforcementTests(unittest.TestCase):
    def _goal(self) -> dict:
        goal = HARNESS.minimal_goal_for_test()
        goal["write_manifest"] = ["js/ui.js"]
        goal["docs_authority"]["tracked_paths"]["write"] = ["js/ui.js"]
        return goal

    def test_product_goal_requires_pattern_refs(self) -> None:
        codes = {
            item["code"]
            for item in HARNESS.validate_goal_meta(self._goal(), Path("goal.md"))
        }
        self.assertIn("MISSING_PATTERN_REF", codes)

    def test_recorded_pattern_exception_is_accepted(self) -> None:
        goal = self._goal()
        goal["pattern_exceptions"] = ["governance-only reference fix, no product behavior"]
        codes = {
            item["code"]
            for item in HARNESS.validate_goal_meta(goal, Path("goal.md"))
        }
        self.assertNotIn("MISSING_PATTERN_REF", codes)

    def test_non_product_goal_needs_no_pattern_refs(self) -> None:
        goal = HARNESS.minimal_goal_for_test()
        codes = {
            item["code"]
            for item in HARNESS.validate_goal_meta(goal, Path("goal.md"))
        }
        self.assertNotIn("MISSING_PATTERN_REF", codes)

    def test_pattern_ref_ids_are_shape_and_index_checked(self) -> None:
        goal = self._goal()
        goal["pattern_refs"] = ["modal"]
        codes = {
            item["code"]
            for item in HARNESS.validate_goal_meta(goal, Path("goal.md"))
        }
        self.assertIn("INVALID_PATTERN_REF", codes)

        goal["pattern_refs"] = ["MODAL-ROUTER-01"]
        known = {"FORM-SUBMIT-01"}
        codes = {
            item["code"]
            for item in HARNESS.validate_goal_meta(goal, Path("goal.md"), pattern_ids=known)
        }
        self.assertIn("UNKNOWN_PATTERN_REF", codes)
        self.assertNotIn("INVALID_PATTERN_REF", codes)

        codes = {
            item["code"]
            for item in HARNESS.validate_goal_meta(goal, Path("goal.md"), pattern_ids={"MODAL-ROUTER-01"})
        }
        self.assertNotIn("UNKNOWN_PATTERN_REF", codes)
        self.assertNotIn("MISSING_PATTERN_REF", codes)

    def test_repository_validate_loads_pattern_index(self) -> None:
        result = HARNESS.validate_repository(ROOT)
        self.assertTrue(result["ok"], result["findings"])
        self.assertGreaterEqual(result.get("pattern_count", 0), 5)


class PatternCatalogTests(unittest.TestCase):
    def test_index_lists_every_pattern_file_and_vice_versa(self) -> None:
        index = (PATTERNS_DIR / "index.yaml").read_text(encoding="utf-8")
        parsed = HARNESS.parse_yaml_subset(index)
        self.assertTrue(parsed, "pattern index must not be empty")
        indexed_files = {str(value) for value in parsed.values()}
        actual_files = {
            path.name for path in PATTERNS_DIR.glob("*.md")
        }
        self.assertEqual(indexed_files, actual_files)
        for pattern_id in parsed:
            self.assertRegex(pattern_id, r"^[A-Z][A-Z0-9]*(-[A-Z0-9]+)*-[0-9]{2}$")

    def test_every_pattern_declares_invariants_and_exemplars(self) -> None:
        for path in sorted(PATTERNS_DIR.glob("*.md")):
            body = path.read_text(encoding="utf-8")
            self.assertIn("## Invariants", body, path.name)
            self.assertIn("## Exemplars", body, path.name)
            self.assertTrue(
                ANCHOR_RE.search(body),
                f"{path.name} must cite at least one source-symbol anchor",
            )

    def test_every_cited_symbol_anchor_exists_in_current_source(self) -> None:
        documents = [*sorted(PATTERNS_DIR.glob("*.md")), ROOT / ".harness" / "references" / "ui-map.md"]
        missing: list[str] = []
        for document in documents:
            for file_path, symbol in sorted(document_anchors(document)):
                source_path = ROOT / file_path
                if not source_path.is_file():
                    missing.append(f"{document.name}: missing file {file_path}")
                    continue
                if not symbol_defined(source_path.read_text(encoding="utf-8"), symbol):
                    missing.append(f"{document.name}: `{file_path}:{symbol}` not defined")
        self.assertEqual([], missing)

    def test_ui_map_covers_router_surface(self) -> None:
        body = (ROOT / ".harness" / "references" / "ui-map.md").read_text(encoding="utf-8")
        anchors = {f"{path}:{symbol}" for path, symbol in ANCHOR_RE.findall(body)}
        for required in (
            "js/utils/modal.js:openM",
            "js/utils/modal.js:closeM",
            "js/utils/events.js:registerActions",
            "js/utils/events.js:ACTIONS",
            "js/ui.js:openConfirm",
        ):
            self.assertIn(required, anchors)
        modal_ids = [symbol for path, symbol in ANCHOR_RE.findall(body) if path == "index.html"]
        self.assertGreaterEqual(len(modal_ids), 25, "ui map must tabulate the router modal surface")

    def test_modal_pattern_documents_legitimate_non_router_onclick(self) -> None:
        body = (PATTERNS_DIR / "modal.md").read_text(encoding="utf-8")
        self.assertIn("Legitimate non-router onclick", body)
        section = body.split("Legitimate non-router onclick", 1)[1].split("\n## ", 1)[0]
        anchors = ANCHOR_RE.findall(section)
        self.assertGreaterEqual(len(anchors), 2)


if __name__ == "__main__":
    unittest.main()
