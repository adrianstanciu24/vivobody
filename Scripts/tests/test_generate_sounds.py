#!/usr/bin/env python3
#
#  test_generate_sounds.py
#  vivobody
#
#  Guards the synthesized-sound inventory and the clean transition from each
#  generated signal into its appended digital-silence tail.
#

from __future__ import annotations

import sys
import unittest
from pathlib import Path


SCRIPTS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_ROOT))

import generate_sounds  # noqa: E402


class SoundGeneratorTests(unittest.TestCase):
    def test_finalize_fades_signal_before_padding(self) -> None:
        signal = [0.5] * generate_sounds.samples(0.01)
        tail_count = generate_sounds.samples(0.03)

        result = generate_sounds.finalize(signal, tail=0.03)

        self.assertEqual(len(result), len(signal) + tail_count)
        self.assertEqual(result[len(signal) - 1], 0.0)
        self.assertTrue(all(sample == 0.0 for sample in result[len(signal):]))

    def test_generated_inventory_contains_only_runtime_cafs(self) -> None:
        expected = {
            "sfx-breath",
            "sfx-crescendo",
            "sfx-rest-done",
            "sfx-swell",
        }
        expected.update(
            f"sfx-scrub-{role}-{variant}"
            for role in ("load", "reps")
            for variant in range(1, 7)
        )

        self.assertEqual(set(generate_sounds.build_all()), expected)


if __name__ == "__main__":
    unittest.main()
