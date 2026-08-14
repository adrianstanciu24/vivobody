#!/usr/bin/env python3
#
#  test_quality_scan.py
#  vivobody
#
#  Focused tests for deterministic report-only quality heuristics: stale
#  knowledge dates, orphaned screen candidates, and repeated UI surface lines.
#

from __future__ import annotations

import sys
import tempfile
import unittest
from datetime import date
from pathlib import Path


SCRIPTS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_ROOT))

import quality_scan  # noqa: E402


class QualityScanTests(unittest.TestCase):
    def test_stale_knowledge_records_use_fixed_today(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "specs").mkdir()
            (root / "engineering").mkdir()
            (root / "specs" / "index.md").write_text(
                "| Old spec | Active | source | 2025-01-01 |\n"
                "| Fresh spec | Active | source | 2026-08-01 |\n",
                encoding="utf-8",
            )
            (root / "engineering" / "tech-debt.md").write_text(
                "- Last checked: 2025-02-01\n",
                encoding="utf-8",
            )

            records = quality_scan.stale_knowledge_records(
                root,
                date(2026, 8, 14),
                90,
            )

        self.assertEqual(len(records), 2)

    def test_orphaned_screen_candidate_has_only_its_definition(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            screens = root / "vivobody" / "Screens"
            screens.mkdir(parents=True)
            (screens / "Views.swift").write_text(
                "struct UsedScreen: View {}\n"
                "struct OrphanScreen: View {}\n",
                encoding="utf-8",
            )
            (root / "vivobody" / "Router.swift").write_text(
                "let destination = UsedScreen()\n",
                encoding="utf-8",
            )

            candidates = quality_scan.orphaned_screen_candidates(root)

        self.assertEqual(candidates, [("OrphanScreen", "vivobody/Screens/Views.swift", 2)])

    def test_duplicate_surface_requires_three_distinct_files(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            screens = root / "vivobody" / "Screens"
            screens.mkdir(parents=True)
            for index in range(3):
                (screens / f"View{index}.swift").write_text(
                    "RoundedRectangle(cornerRadius: 16)\n",
                    encoding="utf-8",
                )

            candidates = quality_scan.duplicated_ui_surface_candidates(root)

        self.assertEqual(len(candidates), 1)
        self.assertEqual(len(candidates[0][1]), 3)


if __name__ == "__main__":
    unittest.main()
