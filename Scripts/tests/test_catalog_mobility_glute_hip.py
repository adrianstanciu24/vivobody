#!/usr/bin/env python3
"""Exercise-specific boundary checks for the Boxing Science glute/hip batch."""

import json
import sys
import unittest
from pathlib import Path

SCRIPTS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_ROOT))
import catalog  # noqa: E402

FAMILY_ROOT = SCRIPTS_ROOT.parent / "specs" / "catalog" / "families"


class MobilityGluteHipCatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.foundation = catalog.validate_foundation()

    def family(self, name):
        return json.loads((FAMILY_ROOT / f"{name}.json").read_text())

    def rejected_variant(self, family_name, exercise_id, field, value):
        family = self.family(family_name)
        exercise = next(e for e in family["exercises"] if e["catalogID"] == exercise_id)
        exercise["variant"][field] = value
        with self.assertRaises(catalog.ValidationFailure):
            catalog.validate_family(family, self.foundation, "mutated fixture")

    def test_all_seven_named_records_compile_with_distinct_identities(self):
        expected = {
            "foot-anchored-band-reverse-lunge": "Reverse Lunge with Band",
            "quadruped-band-hip-extension": "Quadruped Hip Extension with Band",
            "quadruped-fire-hydrants-with-band": "Quadruped Fire Hydrants with Band",
            "single-kettlebell-romanian-deadlift": "Kettlebell RDL",
            "above-knee-band-side-walk": "Banded Side Walks",
            "bodyweight-single-leg-hip-thrust": "Single-Leg Hip Thrusts",
            "bodyweight-prisoner-box-squat-overhead-reach": "Prisoner Squat with Overhead Reach",
        }
        records = json.loads((SCRIPTS_ROOT.parent / "vivobody" / "Resources" / "catalog.json").read_text())
        actual = {record["catalogID"]: record["name"] for record in records if record["catalogID"] in expected}
        self.assertEqual(actual, expected)

    def test_above_knee_walk_cannot_borrow_ankle_band_placement(self):
        self.rejected_variant("lateral-band-walk", "above-knee-band-side-walk", "bandPlacement", "justAboveAnkles")

    def test_ankle_walk_cannot_borrow_above_knee_placement(self):
        self.rejected_variant("lateral-band-walk", "ankle-band-lateral-walk", "bandPlacement", "justAboveKnees")

    def test_band_lunge_cannot_borrow_unbanded_implement(self):
        self.rejected_variant("dynamic-lunge", "foot-anchored-band-reverse-lunge", "implementConfiguration", "none")

    def test_kettlebell_range_cannot_become_barbell_range(self):
        self.rejected_variant("romanian-deadlift", "continuous-top-start-barbell-romanian-deadlift", "rangeOfMotion", "topStartToSelfSelectedHingeFloorContactUnreported")

    def test_quadruped_extension_requires_moving_knee(self):
        self.rejected_variant("quadruped-band-hip-knee-extension", "quadruped-band-hip-extension", "kneeMotion", "positionHeld")

    def test_bodyweight_thrust_requires_free_path(self):
        self.rejected_variant("bodyweight-single-leg-hip-thrust", "bodyweight-single-leg-hip-thrust", "fixedPath", True)

    def test_fire_hydrant_does_not_claim_unreviewed_hip_rotation(self):
        self.rejected_variant("quadruped-band-fire-hydrant", "quadruped-fire-hydrants-with-band", "hipRotation", "externallyRotates")

    def test_prisoner_reach_requires_seated_bench_phase(self):
        self.rejected_variant("prisoner-box-squat-overhead-reach", "bodyweight-prisoner-box-squat-overhead-reach", "reachTiming", "duringAscent")

    def test_prisoner_wide_reach_includes_shoulder_abduction(self):
        family = self.family("prisoner-box-squat-overhead-reach")
        self.assertIn("shoulder.abduction", family["movementSignature"]["primeActions"])
        exercise = family["exercises"][0]
        self.assertIn({"muscle": "deltoidLateral", "role": "secondary"}, exercise["involvement"])


if __name__ == "__main__":
    unittest.main()
