#!/usr/bin/env python3
# Runtime projection and adversarial contract boundaries for the weight-logged Plank Drag.

from __future__ import annotations

import copy
import re
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import catalog  # noqa: E402


RETIRED_DRAG_IDS = ("dumbbell-high-plank-drag", "kettlebell-high-plank-drag")


class PlankDragCatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.foundation = catalog.validate_foundation()
        cls.family = catalog.load_json(catalog.FAMILIES_ROOT / "high-plank-crossbody-drag.json")

    def validate(self, family: dict) -> None:
        catalog.validate_family(family, self.foundation, "plank-drag")

    def test_runtime_record_logs_the_dragged_weight_as_comparable_load(self) -> None:
        self.validate(self.family)
        records = catalog.compile_runtime_catalog([self.family])
        self.assertEqual([record["catalogID"] for record in records], ["plank-drag"])
        record = records[0]
        self.assertEqual(
            tuple(record[key] for key in (
                "familyID", "name", "equipment", "laterality", "modality", "trackingMode",
                "loadMode", "bodyweightFraction", "defaultWeight", "defaultWeightKg", "reps",
            )),
            ("high-plank-crossbody-drag", "Plank Drag", "other", "unilateral", "dynamicStrength",
             "reps", "external", 0, 20, 10, 10),
        )
        self.assertEqual(
            {item["muscle"] for item in record["involvement"] if item["role"] == "primary"},
            {"abs", "obliques"},
        )
        self.assertEqual(
            [(action["actionID"], action["kind"]) for action in record["movementActions"]],
            [("spine.extension", "resisted"), ("spine.rotation", "resisted")],
        )
        self.assertIn("Plank Pull-Through", record["aliases"])
        self.assertNotIn("Pull-Through", record["aliases"])
        self.assertNotIn("Bridge Pull-Through", record["aliases"])

    def test_retired_drag_ids_stay_reserved(self) -> None:
        catalog.validate_retired_exercises([self.family])
        registry = catalog.load_json(catalog.RETIRED_EXERCISES_PATH)
        retired = {entry["catalogID"]: entry["familyID"] for entry in registry["retired"]}
        for catalog_id in RETIRED_DRAG_IDS:
            with self.subTest(catalog_id=catalog_id):
                self.assertEqual(retired[catalog_id], "high-plank-crossbody-drag")
                family = copy.deepcopy(self.family)
                family["exercises"][0]["catalogID"] = catalog_id
                with self.assertRaisesRegex(
                    catalog.ValidationFailure,
                    re.escape(f"retired exercise IDs reused by active catalog: {catalog_id}"),
                ):
                    catalog.validate_retired_exercises([family])

    def test_contract_rejects_neighbouring_fixtures(self) -> None:
        cases = {
            "two implements": (
                {"variant.implementCount": "pair"},
                "variant.implementCount has disallowed value 'pair'",
            ),
            "dumbbell-only implement": (
                {"variant.implement": "dumbbell"},
                "variant.implement has disallowed value 'dumbbell'",
            ),
            "elbow-flexion row": (
                {"additionalPrimeActions": ["elbow.flexion"]},
                "declares forbidden prime action elbow.flexion",
            ),
            "bodyweight plus added load": (
                {"loadMode": "bodyweightAdded", "bodyweightFraction": 1},
                "selects disallowed loadModes: bodyweightAdded",
            ),
            "non-comparable load": (
                {"loadMode": "nonComparable"},
                "selects disallowed loadModes: nonComparable",
            ),
            "dumbbell-specific equipment": (
                {"equipment": "dumbbell"},
                "selects disallowed equipment: dumbbell",
            ),
        }
        for label, (changes, reason) in cases.items():
            with self.subTest(label):
                family = copy.deepcopy(self.family)
                exercise = family["exercises"][0]
                for path, value in changes.items():
                    *parents, key = path.split(".")
                    target = exercise
                    for parent in parents:
                        target = target[parent]
                    target[key] = value
                with self.assertRaisesRegex(catalog.ValidationFailure, re.escape(reason)):
                    self.validate(family)


if __name__ == "__main__":
    unittest.main()
