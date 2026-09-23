#!/usr/bin/env python3
#
#  test_catalog_single_leg_six.py
#  vivobody
#
#  Exact roster, load, and negative-boundary checks for the six Boxing Science
#  single-leg catalog fixtures.
#

from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import catalog  # noqa: E402


class SingleLegSixCatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.foundation = catalog.validate_foundation()
        cls.families = {
            family_id: catalog.load_json(
                catalog.FAMILIES_ROOT / f"{family_id}.json"
            )
            for family_id in (
                "split-stance-squat",
                "dynamic-lunge",
                "landmine-reverse-lunge-knee-drive",
                "single-leg-deadlift",
                "banded-single-leg-hip-thrust",
            )
        }

    def exercise(self, family_id: str, catalog_id: str) -> dict:
        return next(
            exercise
            for exercise in self.families[family_id]["exercises"]
            if exercise["catalogID"] == catalog_id
        )

    def test_exact_names_and_load_contracts(self) -> None:
        expected = {
            ("split-stance-squat", "goblet-split-squat"):
                ("Goblet Split Squat", "dumbbell", "external", 25),
            ("dynamic-lunge", "goblet-reverse-lunge"):
                ("Goblet Reverse Lunge", "dumbbell", "external", 25),
            ("landmine-reverse-lunge-knee-drive", "landmine-reverse-lunge-to-knee-raise"):
                ("Landmine Reverse Lunge to Knee Raise", "barbell", "external", 0),
            ("single-leg-deadlift", "landmine-single-leg-romanian-deadlift"):
                ("Landmine Single-Leg RDL", "barbell", "external", 0),
            ("single-leg-deadlift", "kettlebell-single-leg-romanian-deadlift"):
                ("Kettlebell Single-Leg RDL", "kettlebell", "external", 25),
            ("banded-single-leg-hip-thrust", "banded-single-leg-hip-thrust"):
                ("Banded Single-Leg Hip Thrust", "band", "nonComparable", 0),
        }
        for (family_id, catalog_id), contract in expected.items():
            with self.subTest(catalog_id=catalog_id):
                exercise = self.exercise(family_id, catalog_id)
                self.assertEqual(
                    (
                        exercise["name"], exercise["equipment"],
                        exercise["loadMode"], exercise["defaultWeight"],
                    ),
                    contract,
                )
                self.assertEqual(exercise["laterality"], "unilateral")
                self.assertEqual(exercise["trackingMode"], "reps")
                self.assertIn(
                    "boxing-science-exercise-library", exercise["evidenceRefs"]
                )
                catalog.validate_family(
                    self.families[family_id], self.foundation, family_id
                )

    def test_fixture_geometry_is_distinct_from_neighbours(self) -> None:
        expected = {
            ("split-stance-squat", "goblet-split-squat"): {
                "implementConfiguration": "singleDumbbellGoblet",
                "rangeOfMotion": "leadKneeApproximatelyNinetyDegrees",
                "loadAccounting": "wholeImplement",
            },
            ("dynamic-lunge", "goblet-reverse-lunge"): {
                "implementConfiguration": "singleDumbbellGoblet",
                "returnTopology": "returnToBilateralStart",
                "loadAccounting": "wholeImplement",
            },
            ("landmine-reverse-lunge-knee-drive", "landmine-reverse-lunge-to-knee-raise"): {
                "returnTopology": "singleLegKneeDriveNextEntryUnreported",
                "barPath": "landmineArc",
                "fixedPath": True,
                "loadAccounting": "addedPlatesSameLandmineOnly",
            },
            ("single-leg-deadlift", "landmine-single-leg-romanian-deadlift"): {
                "loadSideRelativeToWorkingLeg": "contralateral",
                "externalPath": "landmineArc",
                "fixedPath": True,
                "loadAccounting": "addedPlatesSameLandmineOnly",
            },
            ("single-leg-deadlift", "kettlebell-single-leg-romanian-deadlift"): {
                "loadSideRelativeToWorkingLeg": "ipsilateral",
                "bottomEndpoint": "bellJustPastWorkingKnee",
                "externalPath": "free",
                "fixedPath": False,
            },
            ("banded-single-leg-hip-thrust", "banded-single-leg-hip-thrust"): {
                "loadPlacement": "bandAcrossPelvis",
                "stanceConfiguration": "singleWorkingHeel",
                "torsoSupport": "bench",
                "bandResistance": "variableNonComparable",
            },
        }
        for (family_id, catalog_id), fields in expected.items():
            with self.subTest(catalog_id=catalog_id):
                variant = self.exercise(family_id, catalog_id)["variant"]
                for field, value in fields.items():
                    self.assertEqual(variant[field], value)

    def test_crossed_fixture_mutations_are_rejected(self) -> None:
        cases = (
            ("split-stance-squat", "goblet-split-squat", "variant.loadAccounting", "perImplement"),
            ("split-stance-squat", "goblet-split-squat", "variant.fixedPath", True),
            ("dynamic-lunge", "goblet-reverse-lunge", "variant.fixedPath", True),
            ("dynamic-lunge", "goblet-reverse-lunge", "variant.implementConfiguration", "pairedDumbbells"),
            ("landmine-reverse-lunge-knee-drive", "landmine-reverse-lunge-to-knee-raise", "variant.fixedPath", False),
            ("landmine-reverse-lunge-knee-drive", "landmine-reverse-lunge-to-knee-raise", "variant.returnTopology", "returnToBilateralStart"),
            ("single-leg-deadlift", "landmine-single-leg-romanian-deadlift", "variant.fixedPath", False),
            ("single-leg-deadlift", "landmine-single-leg-romanian-deadlift", "variant.externalPath", "free"),
            ("single-leg-deadlift", "landmine-single-leg-romanian-deadlift", "variant.loadAccounting", "wholeDumbbell"),
            ("single-leg-deadlift", "kettlebell-single-leg-romanian-deadlift", "variant.loadSideRelativeToWorkingLeg", "contralateral"),
            ("single-leg-deadlift", "kettlebell-single-leg-romanian-deadlift", "variant.bottomEndpoint", "trunkAboutParallelByInstructionKinematicsUnmeasured"),
            ("banded-single-leg-hip-thrust", "banded-single-leg-hip-thrust", "variant.loadPlacement", "aroundKnees"),
            ("banded-single-leg-hip-thrust", "banded-single-leg-hip-thrust", "loadMode", "external"),
        )
        for family_id, catalog_id, path, value in cases:
            with self.subTest(catalog_id=catalog_id, path=path):
                family = copy.deepcopy(self.families[family_id])
                exercise = next(
                    item for item in family["exercises"]
                    if item["catalogID"] == catalog_id
                )
                if path.startswith("variant."):
                    exercise["variant"][path.removeprefix("variant.")] = value
                else:
                    exercise[path] = value
                with self.assertRaises(catalog.ValidationFailure):
                    catalog.validate_family(family, self.foundation, family_id)


if __name__ == "__main__":
    unittest.main()
