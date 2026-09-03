"""Curated reference document tests (ui-map, rpc-reference, domain-rules)."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REFERENCES = ROOT / ".harness" / "references"


def reference(name: str) -> str:
    return (REFERENCES / name).read_text(encoding="utf-8")


def flat(name: str) -> str:
    lines = [
        line[2:] if line.startswith("> ") else line
        for line in reference(name).splitlines()
    ]
    return " ".join(" ".join(lines).split())


class RpcReferenceTests(unittest.TestCase):
    def test_records_provenance_and_live_schema_authority(self) -> None:
        body = flat("rpc-reference.md")
        self.assertIn("Provenance", body)
        self.assertIn("live-schema", body)
        self.assertIn("never live-schema truth", body)

    def test_documents_wrapper_contract_and_both_maps(self) -> None:
        body = reference("rpc-reference.md")
        for required in (
            "`ok:false`",
            "`.data`",
            "`RPC_TABLES`",
            "`RPC_MAP`",
            "`rpcOptimistic`",
        ):
            self.assertIn(required, body)

    def test_records_measured_call_surface_and_edge_function_classification(self) -> None:
        body = flat("rpc-reference.md")
        self.assertIn("113 unique Postgres functions", body)
        self.assertIn("supabase/functions/ai-agent", body)
        self.assertIn("stat-hesapla", body)
        self.assertIn("no frontend caller", body)


class DomainRulesTests(unittest.TestCase):
    def test_records_provenance_and_transitional_boundary(self) -> None:
        body = flat("domain-rules.md")
        self.assertIn("Provenance", body)
        self.assertIn(".claude/domain-rules.md", body)
        self.assertIn("Phase 6", body)
        self.assertIn("not a schema mirror", body)

    def test_carries_curated_domain_knowledge(self) -> None:
        body = reference("domain-rules.md")
        self.assertIn("500-599", body)
        self.assertIn("`kupe_musait_mi`", body)
        self.assertIn("asi_toplu_planla", body)


class UiMapTests(unittest.TestCase):
    def test_is_symbol_keyed_not_line_numbered(self) -> None:
        body = flat("ui-map.md")
        self.assertIn("Symbol-keyed", body)
        self.assertIn("line numbers are deliberately absent", body)
        self.assertNotIn("| Satır |", body)

    def test_documents_dead_router_surface(self) -> None:
        body = reference("ui-map.md")
        for marker in ("mClose", "m-tohum-ertele", "orphaned"):
            self.assertIn(marker, body)


if __name__ == "__main__":
    unittest.main()
