#!/usr/bin/env python3
# Exact roster and adversarial fixture boundaries for counted Jump Rope.

from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import catalog  # noqa: E402


class JumpRopeCatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.foundation = catalog.validate_foundation()
        cls.family = catalog.load_json(
            catalog.FAMILIES_ROOT / "stationary-two-foot-jump-rope.json"
        )

    def test_exact_roster_and_logging_contract(self) -> None:
        catalog.validate_family(self.family, self.foundation, "jump-rope")
        self.assertEqual(
            [exercise["catalogID"] for exercise in self.family["exercises"]],
            ["jump-rope"],
        )
        exercise = self.family["exercises"][0]
        self.assertEqual(
            tuple(exercise[key] for key in (
                "name", "equipment", "laterality", "modality", "trackingMode",
                "loadMode", "bodyweightFraction", "defaultWeight", "reps",
            )),
            ("Jump Rope", "other", "bilateral", "power", "reps",
             "nonComparable", 0, 0, 30),
        )
        runtime = catalog.compile_runtime_catalog([self.family])
        self.assertEqual(runtime[0]["catalogID"], "jump-rope")
        self.assertEqual(runtime[0]["familyID"], self.family["id"])
        self.assertIn("Rope Skipping", runtime[0]["aliases"])

    def test_neighbouring_fixtures_are_rejected(self) -> None:
        mutations = {
            "travel": "forward",
            "footSequence": "alternatingContacts",
            "implement": "weightedRope",
            "ropeRotation": "backward",
            "ropeTurnsPerJump": "two",
            "jumpIntent": "maximumHeight",
            "externalSupport": "handSupport",
            "fixedPath": True,
        }
        for axis, value in mutations.items():
            with self.subTest(axis=axis):
                family = copy.deepcopy(self.family)
                family["exercises"][0]["variant"][axis] = value
                with self.assertRaises(catalog.ValidationFailure):
                    catalog.validate_family(family, self.foundation, "jump-rope")
        for field, value in (
            ("equipment", "bodyweight"), ("laterality", "unilateral"),
            ("modality", "isometricStrength"), ("trackingMode", "duration"),
            ("loadMode", "external"),
        ):
            with self.subTest(field=field):
                family = copy.deepcopy(self.family)
                family["exercises"][0][field] = value
                with self.assertRaises(catalog.ValidationFailure):
                    catalog.validate_family(family, self.foundation, "jump-rope")

    def test_landing_and_takeoff_require_dynamic_knee_and_hip_roles(self) -> None:
        for muscle in ("vasti", "gluteMax"):
            with self.subTest(muscle=muscle):
                family = copy.deepcopy(self.family)
                family["exercises"][0]["involvement"] = [
                    entry for entry in family["exercises"][0]["involvement"]
                    if entry["muscle"] != muscle
                ]
                with self.assertRaises(catalog.ValidationFailure):
                    catalog.validate_family(family, self.foundation, "jump-rope")


if __name__ == "__main__":
    unittest.main()
