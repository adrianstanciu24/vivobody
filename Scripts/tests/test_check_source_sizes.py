#!/usr/bin/env python3
#
#  test_check_source_sizes.py
#  vivobody
#
#  Mutation tests for the production Swift source-size ratchet: unchanged debt
#  passes, while growth, new oversized files, stale entries, and unratcheted
#  reductions produce actionable diagnostics.
#

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPTS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_ROOT))

import check_source_sizes  # noqa: E402


class SourceSizeCheckerTests(unittest.TestCase):
    def fixture(
        self,
        *,
        current_lines: int = 650,
        baseline_lines: int = 650,
    ) -> tuple[tempfile.TemporaryDirectory[str], Path, Path]:
        directory = tempfile.TemporaryDirectory()
        root = Path(directory.name)
        source = root / "vivobody" / "Large.swift"
        source.parent.mkdir(parents=True)
        source.write_text("// line\n" * current_lines, encoding="utf-8")
        baseline = root / "baseline.json"
        baseline.write_text(json.dumps({
            "threshold": 600,
            "files": {"vivobody/Large.swift": baseline_lines},
        }), encoding="utf-8")
        return directory, root, baseline

    def rules(self, root: Path, baseline: Path) -> set[str]:
        violations, _, _ = check_source_sizes.check(root, baseline)
        return {violation.rule for violation in violations}

    def test_unchanged_existing_oversized_file_passes(self) -> None:
        directory, root, baseline = self.fixture()
        with directory:
            self.assertEqual(self.rules(root, baseline), set())

    def test_existing_oversized_file_cannot_grow(self) -> None:
        directory, root, baseline = self.fixture(current_lines=651)
        with directory:
            self.assertIn("SIZE001", self.rules(root, baseline))

    def test_new_oversized_file_fails(self) -> None:
        directory, root, baseline = self.fixture()
        with directory:
            new_file = root / "vivobody" / "NewLarge.swift"
            new_file.write_text("// line\n" * 601, encoding="utf-8")
            self.assertIn("SIZE002", self.rules(root, baseline))

    def test_deleted_file_requires_removing_stale_allowance(self) -> None:
        directory, root, baseline = self.fixture()
        with directory:
            (root / "vivobody" / "Large.swift").unlink()
            self.assertIn("SIZE003", self.rules(root, baseline))

    def test_shrink_requires_tightening_baseline(self) -> None:
        directory, root, baseline = self.fixture(current_lines=640)
        with directory:
            self.assertIn("SIZE004", self.rules(root, baseline))


if __name__ == "__main__":
    unittest.main()
