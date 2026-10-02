"""Guard the loaded plank row's identity and boundary with bodyweight touches."""
import copy
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import catalog


class DumbbellPlankRowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.foundation = catalog.validate_foundation()
        cls.row = catalog.load_json(catalog.FAMILIES_ROOT / "dumbbell-plank-row.json")
        cls.neighbors = {
            name: catalog.load_json(catalog.FAMILIES_ROOT / f"{name}.json")
            for name in (
                "high-plank-shoulder-tap",
                "high-plank-contralateral-knee-touch",
                "shoulder-extension-row",
            )
        }

    def test_search_names_own_distinct_stable_records(self):
        families = [self.row, *self.neighbors.values()]
        runtime = catalog.compile_runtime_catalog(families)
        owners = {
            term: record["catalogID"]
            for record in runtime
            for term in [record["name"], *record["aliases"]]
        }
        self.assertEqual(owners["Plank Row"], "alternating-dumbbell-plank-row")
        self.assertEqual(owners["Renegade Row"], "alternating-dumbbell-plank-row")
        self.assertEqual(owners["Plank Shoulder Tap"], "alternating-high-plank-shoulder-tap")
        self.assertEqual(owners["Plank with Knee Touch"], "alternating-high-plank-contralateral-knee-touch")
        self.assertNotIn("Plank Row with Knee Touch", owners)
        self.assertNotIn("Plank Row w/ Knee Touch", owners)
        row = next(record for record in runtime if record["catalogID"] == "alternating-dumbbell-plank-row")
        self.assertEqual(row["loadMode"], "external")
        self.assertEqual(row["bodyweightFraction"], 0)
        variant = self.row["exercises"][0]["variant"]
        self.assertEqual(variant["loadAccounting"], "oneWorkingDumbbellEqualPair")
        self.assertEqual(variant["repetitionCounting"], "eachRowAndReturn")
        self.assertEqual(row["reps"] % 2, 0)

    def test_row_contract_rejects_different_geometry_and_repetition(self):
        mutations = {
            "rowSupport": "kneesAndSingleDumbbell",
            "repetitionComposition": "rowAndPushUp",
            "trunkMotion": "deliberateRotation",
            "loadAccounting": "combinedDumbbellPair",
            "repetitionCounting": "bothRowsCountOnce",
            "rowEndpoint": "oppositeShoulderTouch",
        }
        for axis, value in mutations.items():
            family = copy.deepcopy(self.row)
            family["exercises"][0]["variant"][axis] = value
            with self.subTest(axis=axis):
                with self.assertRaises(catalog.ValidationFailure):
                    catalog.validate_family(family, self.foundation, "different plank task")

    def test_neighbors_and_row_cannot_accept_each_others_records(self):
        for name, neighbor in self.neighbors.items():
            changed = copy.deepcopy(neighbor)
            changed["exercises"].append(copy.deepcopy(self.row["exercises"][0]))
            with self.subTest(owner=name):
                with self.assertRaises(catalog.ValidationFailure):
                    catalog.validate_family(changed, self.foundation, "loaded plank row leak")
            changed = copy.deepcopy(self.row)
            changed["exercises"].append(copy.deepcopy(neighbor["exercises"][0]))
            with self.subTest(foreign=name):
                with self.assertRaises(catalog.ValidationFailure):
                    catalog.validate_family(changed, self.foundation, "foreign row or touch leak")


if __name__ == "__main__":
    unittest.main()
