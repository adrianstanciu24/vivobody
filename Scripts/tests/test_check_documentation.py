#!/usr/bin/env python3
#
#  test_check_documentation.py
#  vivobody
#
#  Mutation tests for the documentation-map checker. Fixtures prove broken
#  links, unindexed specs, and volatile root guidance fail while ordinary
#  external links and a complete map pass.
#

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path


SCRIPTS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_ROOT))

import check_documentation  # noqa: E402


class DocumentationCheckerTests(unittest.TestCase):
    def make_root(self, directory: str) -> Path:
        root = Path(directory)
        for relative in check_documentation.REQUIRED_FILES:
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f"# {path.stem}\n", encoding="utf-8")
        return root

    def rules(self, root: Path) -> set[str]:
        return {violation.rule for violation in check_documentation.run(root)}

    def test_complete_map_passes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_root(directory)
            (root / "AGENTS.md").write_text(
                "# Guide\n[Architecture](ARCHITECTURE.md)\n"
                "[Official docs](https://learn.chatgpt.com/)\n",
                encoding="utf-8",
            )
            self.assertEqual(self.rules(root), set())

    def test_missing_local_link_fails(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_root(directory)
            (root / "ARCHITECTURE.md").write_text(
                "# Architecture\n[Missing](engineering/missing.md)\n",
                encoding="utf-8",
            )
            self.assertIn("DOC002", self.rules(root))

    def test_concrete_schema_version_in_agents_fails(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_root(directory)
            (root / "AGENTS.md").write_text(
                "# Guide\nThe current schema is V4.\n",
                encoding="utf-8",
            )
            self.assertIn("DOC003", self.rules(root))

    def test_unindexed_top_level_spec_fails(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_root(directory)
            spec = root / "specs/new-feature.md"
            spec.write_text("# New feature\n", encoding="utf-8")
            self.assertIn("DOC004", self.rules(root))


if __name__ == "__main__":
    unittest.main()
