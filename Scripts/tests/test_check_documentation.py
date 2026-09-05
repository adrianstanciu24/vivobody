#!/usr/bin/env python3
#
#  test_check_documentation.py
#  vivobody
#
#  Mutation tests for the documentation-map checker. Fixtures prove broken
#  links, unindexed specs, volatile root guidance, and stale generated inventories
#  fail while ordinary external links and a complete map pass.
#

from __future__ import annotations

import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPTS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_ROOT))

import check_documentation  # noqa: E402
import documentation_inventory  # noqa: E402


class DocumentationCheckerTests(unittest.TestCase):
    def write_json(self, path: Path, value: dict) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(value), encoding="utf-8")

    def make_root(self, directory: str) -> Path:
        root = Path(directory)
        for relative in check_documentation.REQUIRED_FILES:
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f"# {path.stem}\n", encoding="utf-8")
        catalog = root / "specs/catalog"
        for name in ("README.md", "family-roadmap.md"):
            (catalog / name).write_text("# Catalog\n", encoding="utf-8")
        self.write_json(catalog / "taxonomy.json", {"muscles": [
            {"meshBaseNames": ["upper", "lower"]}, {"meshBaseNames": []},
        ]})
        self.write_json(catalog / "joint-actions.json", {"actions": ["press"]})
        self.write_json(catalog / "evidence.json", {"sources": ["source-a", "source-b"]})
        self.write_json(catalog / "families/press.json", {"id": "press", "exercises": ["one", "two"]})
        self.write_json(root / "Scripts/verify_scenarios/normal.json", {
            "name": "normal", "launch": {"tab": "today", "arguments": ["--fixture"]},
        })
        for relative, content in documentation_inventory.generated_documents(root).items():
            (root / relative).write_text(content, encoding="utf-8")
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

    def test_links_in_onboarding_specs_skills_and_scenarios_are_checked(self) -> None:
        for relative in ("README.md", "worklog.md", "specs/catalog/README.md",
                         ".agents/skills/vivobody-add-exercise/SKILL.md",
                         "Scripts/verify_scenarios/README.md"):
            with self.subTest(path=relative), tempfile.TemporaryDirectory() as directory:
                root = self.make_root(directory)
                (root / relative).write_text("[Missing](missing.md)\n", encoding="utf-8")
                errors = check_documentation.check_links(root)
                self.assertTrue(any(error.path == relative and error.rule == "DOC002" for error in errors))

    def test_new_scenario_fails_until_inventory_is_refreshed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_root(directory)
            self.write_json(root / "Scripts/verify_scenarios/locked.json", {
                "name": "locked", "launch": {"tab": "insights", "arguments": ["--locked"]},
            })
            before = (root / "Scripts/verify_scenarios/index.md").read_bytes()
            self.assertIn("DOC005", self.rules(root))
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(documentation_inventory.main(["--check"], root), 1)
            self.assertEqual((root / "Scripts/verify_scenarios/index.md").read_bytes(), before)
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(documentation_inventory.main(["--write"], root), 0)
            self.assertEqual(self.rules(root), set())
            index = (root / "Scripts/verify_scenarios/index.md").read_text()
            self.assertIn("[locked](locked.json)", index)
            self.assertIn("--locked", index)

    def test_changed_launch_arguments_and_removed_scenarios_invalidate_inventory(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_root(directory)
            scenario = root / "Scripts/verify_scenarios/normal.json"
            self.write_json(scenario, {"launch": {"tab": "library", "arguments": ["--different"]}})
            self.assertIn("DOC005", self.rules(root))
            scenario.unlink()
            self.assertIn("DOC005", self.rules(root))

    def test_catalog_counts_use_family_sources_and_exclude_synthetic_fixture(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_root(directory)
            catalog = root / "specs/catalog"
            self.write_json(catalog / "fixtures/valid-family.json", {"id": "synthetic", "exercises": ["x"] * 20})
            inventory = documentation_inventory.catalog_inventory(root)
            self.assertIn("| Reviewed families | 1 |", inventory)
            self.assertIn("| Exercises | 2 |", inventory)
            self.assertIn("| Muscle regions | 2 |", inventory)
            self.assertIn("| Unique trainable mesh bases | 2 |", inventory)
            self.assertIn("| Evidence sources | 2 |", inventory)
            self.assertNotIn("[synthetic]", inventory)
            self.write_json(catalog / "families/pull.json", {"id": "pull", "exercises": ["three"]})
            self.assertIn("DOC005", self.rules(root))
            updated = documentation_inventory.catalog_inventory(root)
            self.assertIn("| Reviewed families | 2 |", updated)
            self.assertIn("| Exercises | 3 |", updated)
            self.assertIn("[pull](families/pull.json)", updated)

    def test_missing_generated_file_and_invalid_input_fail(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_root(directory)
            (root / "specs/catalog/inventory.md").unlink()
            self.assertIn("DOC005", self.rules(root))
            (root / "specs/catalog/evidence.json").write_text("invalid JSON", encoding="utf-8")
            self.assertIn("DOC005", self.rules(root))
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(documentation_inventory.main(["--write"], root), 1)
            self.assertFalse((root / "specs/catalog/inventory.md").exists())

    def test_inventory_generation_is_deterministic_and_preserves_source(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_root(directory)
            inputs = {path: path.read_bytes() for path in root.rglob("*.json")}
            first = documentation_inventory.generated_documents(root)
            self.assertEqual(first, documentation_inventory.generated_documents(root))
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(documentation_inventory.main(["--write"], root), 0)
                self.assertEqual(documentation_inventory.main(["--check"], root), 0)
            for path, content in inputs.items():
                self.assertEqual(path.read_bytes(), content)


if __name__ == "__main__":
    unittest.main()
