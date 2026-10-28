#!/usr/bin/env python3
# Exact roster and adversarial fixture boundaries for the straight-arm High Plank.

from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import catalog  # noqa: E402


class HighPlankCatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.foundation = catalog.validate_foundation()
        cls.family = catalog.load_json(catalog.FAMILIES_ROOT / "high-plank-hold.json")
        cls.forearm = catalog.load_json(catalog.FAMILIES_ROOT / "anti-extension.json")

    def validate(self, family: dict) -> None:
        catalog.validate_family(family, self.foundation, "high-plank")

    def test_exact_roster_and_logging_contract(self) -> None:
        self.validate(self.family)
        self.assertEqual(
            [exercise["catalogID"] for exercise in self.family["exercises"]],
            ["high-plank"],
        )
        exercise = self.family["exercises"][0]
        self.assertEqual(
            tuple(exercise[key] for key in (
                "name", "equipment", "laterality", "modality", "trackingMode",
                "loadMode", "bodyweightFraction", "defaultWeight", "defaultDuration",
            )),
            ("High Plank", "bodyweight", "bilateral", "isometricStrength",
             "duration", "bodyweightAdded", 1, 0, 30),
        )
        self.assertEqual(
            {(item["muscle"], item["role"]) for item in exercise["involvement"]},
            {
                ("abs", "primary"), ("obliques", "secondary"),
                ("serratus", "stabilizer"), ("externalRotators", "stabilizer"),
                ("triceps", "stabilizer"), ("fingerFlexors", "stabilizer"),
                ("gluteMax", "stabilizer"), ("vasti", "stabilizer"),
                ("soleus", "stabilizer"),
            },
        )
        self.assertEqual(self.family["movementSignature"]["resistedActions"], ["spine.extension"])
        self.assertEqual(self.family["movementSignature"]["primeActions"], [])
        runtime = catalog.compile_runtime_catalog([self.family])
        self.assertEqual(runtime[0]["catalogID"], "high-plank")
        self.assertEqual(runtime[0]["familyID"], "high-plank-hold")
        self.assertIn("Straight-Arm Plank", runtime[0]["aliases"])

    def test_palm_support_and_extended_elbows_identify_the_fixture(self) -> None:
        variant = self.family["exercises"][0]["variant"]
        self.assertEqual(variant["upperBodySupport"], "bilateralPalmSupport")
        self.assertEqual(variant["elbowPosition"], "extended")
        self.assertEqual(variant["handPlacement"], "directlyUnderShoulders")
        forearm_plank = next(e for e in self.forearm["exercises"] if e["catalogID"] == "plank")
        self.assertEqual(forearm_plank["variant"]["upperBodySupport"], "bilateralForearmSupport")

    def test_neighbouring_fixtures_are_rejected(self) -> None:
        mutations = {
            "upperBodySupport": "bilateralForearmSupport",
            "elbowPosition": "flexed",
            "handPlacement": "forwardOfShoulders",
            "lowerBodySupport": "knees",
            "supportSurface": "floorAndSuspensionTrainer",
            "spineMotion": "dynamic",
            "hipMotion": "dynamic",
            "holdType": "repetitions",
            "fixedPath": True,
        }
        for axis, value in mutations.items():
            with self.subTest(axis=axis):
                family = copy.deepcopy(self.family)
                family["exercises"][0]["variant"][axis] = value
                with self.assertRaises(catalog.ValidationFailure):
                    self.validate(family)
        for field, value in (
            ("equipment", "suspensionTrainer"), ("laterality", "unilateral"),
            ("modality", "dynamicStrength"), ("trackingMode", "reps"),
            ("loadMode", "nonComparable"), ("bodyweightFraction", 0.5),
        ):
            with self.subTest(field=field):
                family = copy.deepcopy(self.family)
                family["exercises"][0][field] = value
                with self.assertRaises(catalog.ValidationFailure):
                    self.validate(family)

    def test_every_axis_is_required(self) -> None:
        for axis in self.family["variantAxes"]:
            with self.subTest(axis=axis["id"]):
                family = copy.deepcopy(self.family)
                family["exercises"][0]["variant"].pop(axis["id"])
                with self.assertRaises(catalog.ValidationFailure):
                    self.validate(family)

    def test_forbidden_actions_and_required_roles_are_mutation_guarded(self) -> None:
        for action in self.family["movementSignature"]["forbiddenPrimeActions"]:
            with self.subTest(forbidden_action=action):
                family = copy.deepcopy(self.family)
                family["exercises"][0]["additionalPrimeActions"] = [action]
                with self.assertRaises(catalog.ValidationFailure):
                    self.validate(family)
        for requirement in self.family["musclePolicy"]["requirements"]:
            candidates = set(requirement["anyOf"])
            with self.subTest(required=tuple(sorted(candidates))):
                family = copy.deepcopy(self.family)
                family["exercises"][0]["involvement"] = [
                    item for item in family["exercises"][0]["involvement"]
                    if item["muscle"] not in candidates
                ]
                with self.assertRaises(catalog.ValidationFailure):
                    self.validate(family)

    def test_support_values_alone_cross_the_family_boundary(self) -> None:
        forearm_plank = next(e for e in self.forearm["exercises"] if e["catalogID"] == "plank")
        family = copy.deepcopy(self.forearm)
        record = copy.deepcopy(forearm_plank)
        record["catalogID"] = "palm-supported-forearm-family-leak"
        record["name"] = "Palm Supported Forearm Family Leak"
        record["aliases"] = []
        record["variant"]["upperBodySupport"] = "bilateralPalmSupport"
        family["exercises"].append(record)
        with self.assertRaises(catalog.ValidationFailure):
            catalog.validate_family(family, self.foundation, "palm support leak")

        family = copy.deepcopy(self.family)
        family["exercises"][0]["variant"]["upperBodySupport"] = "bilateralForearmSupport"
        with self.assertRaises(catalog.ValidationFailure):
            self.validate(family)

    def test_forearm_and_high_plank_families_reject_each_other(self) -> None:
        high_plank = self.family["exercises"][0]
        forearm_plank = next(e for e in self.forearm["exercises"] if e["catalogID"] == "plank")
        for owner, foreign in ((self.forearm, high_plank), (self.family, forearm_plank)):
            with self.subTest(owner=owner["id"], foreign=foreign["catalogID"]):
                family = copy.deepcopy(owner)
                record = copy.deepcopy(foreign)
                record["catalogID"] = "foreign-plank-leak"
                record["name"] = "Foreign Plank Leak"
                record["aliases"] = []
                family["exercises"].append(record)
                with self.assertRaises(catalog.ValidationFailure):
                    catalog.validate_family(family, self.foundation, "neighbor leak")


if __name__ == "__main__":
    unittest.main()
