"""Protect the requested assistance, unloaded, cable, and press fixtures."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import catalog


OWNERS = {
    "band-assisted-pull-up": "vertical-pull",
    "standing-cable-hip-abduction": "hip-abduction",
    "dumbbell-triceps-kickback": "elbow-extension",
    "ez-bar-skull-crusher": "elbow-extension",
    "cable-pull-through": "cable-pull-through",
    "pike-push-up": "pike-push-up",
}











class RequestedCatalogGapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.foundation = catalog.validate_foundation()
        cls.families = {
            name: catalog.load_json(catalog.FAMILIES_ROOT / f"{name}.json")
            for name in set(OWNERS.values())
        }

    def fixture(self, catalog_id):
        family = copy.deepcopy(self.families[OWNERS[catalog_id]])
        exercise = next(e for e in family["exercises"] if e["catalogID"] == catalog_id)
        return family, exercise

    def test_exact_ownership_and_tracking(self):
        all_families = [catalog.load_json(p) for p in catalog.FAMILIES_ROOT.glob("*.json")]
        records = catalog.compile_runtime_catalog(all_families)
        for catalog_id, owner in OWNERS.items():
            with self.subTest(exercise=catalog_id):
                matches = [r for r in records if r["catalogID"] == catalog_id]
                self.assertEqual(len(matches), 1)
                self.assertEqual(matches[0]["familyID"], owner)
                self.assertEqual(matches[0]["modality"], "dynamicStrength")
                self.assertEqual(matches[0]["trackingMode"], "reps")
                family, _ = self.fixture(catalog_id)
                self.assertEqual(catalog.validate_family(family, self.foundation, owner), [])

    def test_unquantified_fixtures_do_not_invent_loads(self):
        for catalog_id in ("band-assisted-pull-up", "pike-push-up"):
            with self.subTest(exercise=catalog_id):
                _, exercise = self.fixture(catalog_id)
                self.assertEqual(exercise["loadMode"], "nonComparable")
                self.assertEqual(exercise["bodyweightFraction"], 0)
                self.assertEqual(exercise["defaultWeight"], 0)

    def test_retired_variants_leave_unrelated_runtime_records_intact(self):
        families = [catalog.load_json(p) for p in catalog.FAMILIES_ROOT.glob("*.json")]
        records = catalog.compile_runtime_catalog(families)
        ids = {record["catalogID"] for record in records}
        self.assertEqual(len(records), 330)
        self.assertEqual(len(ids), len(records))
        self.assertTrue({
            "barbell-good-morning", "barbell-back-squat", "chin-up",
            "barbell-stiff-leg-deadlift", "landmine-reverse-lunge-to-knee-raise",
        } <= ids)
        self.assertTrue({
            "pronated-grip-machine-reverse-fly", "kettlebell-high-plank-drag",
            "single-arm-dumbbell-front-raise", "barbell-split-squat",
            "barbell-rear-foot-elevated-split-squat", "bodyweight-split-squat",
            "bodyweight-bulgarian-split-squat", "goblet-split-squat",
            "barbell-romanian-deadlift", "barbell-romanian-deadlift-15-cm-step",
            "two-dumbbell-continuous-romanian-deadlift",
            "single-kettlebell-romanian-deadlift", "neutral-grip-pull-up",
            "wide-grip-pull-up", "barbell-good-morning-25-percent-body-mass",
        }.isdisjoint(ids))

    def test_neighboring_movements_are_rejected(self):
        mutations = {
            "band-assisted-pull-up": [("loadMode", "assistanceSubtracted"),
                                      ("variant.lowerBodySupport", "assistancePlatform"),
                                      ("variant.gripOrientation", "supinated")],
            "standing-cable-hip-abduction": [("laterality", "bilateral"),
                                             ("variant.hipMotion", "adducts")],
            "dumbbell-triceps-kickback": [("equipment", "cable"),
                                          ("variant.upperArmPosition", "overhead")],
            "ez-bar-skull-crusher": [("variant.handleType", "barbellShapeUnreported"),
                                     ("variant.loadAccounting", "perImplement")],
            "cable-pull-through": [("laterality", "unilateral"),
                                   ("equipment", "barbell")],
            "pike-push-up": [("loadMode", "bodyweightAdded"),
                             ("equipment", "machine")],
        }
        for catalog_id, changes in mutations.items():
            for path, value in changes:
                with self.subTest(exercise=catalog_id, field=path):
                    family, exercise = self.fixture(catalog_id)
                    if path.startswith("variant."):
                        exercise["variant"][path.split(".", 1)[1]] = value
                    else:
                        exercise[path] = value
                    with self.assertRaises(catalog.ValidationFailure):
                        catalog.validate_family(family, self.foundation, "neighbor mutation")

    def test_new_families_reject_forbidden_actions_and_missing_geometry(self):
        for name in ("cable-pull-through", "pike-push-up"):
            original = self.families[name]
            for action in original["movementSignature"]["forbiddenPrimeActions"]:
                family = copy.deepcopy(original)
                family["exercises"][0]["additionalPrimeActions"] = [action]
                with self.subTest(family=name, action=action):
                    with self.assertRaises(catalog.ValidationFailure):
                        catalog.validate_family(family, self.foundation, "forbidden action")
            for axis in original["variantAxes"]:
                if not axis["required"]:
                    continue
                family = copy.deepcopy(original)
                family["exercises"][0]["variant"].pop(axis["id"])
                with self.subTest(family=name, axis=axis["id"]):
                    with self.assertRaises(catalog.ValidationFailure):
                        catalog.validate_family(family, self.foundation, "missing geometry")

    def test_new_family_rosters_cover_the_admitted_geometry(self):
        for name in ("cable-pull-through", "pike-push-up"):
            family = self.families[name]
            self.assertEqual({e["catalogID"] for e in family["exercises"]},
                             {key for key, value in OWNERS.items() if value == name})
            for axis in family["variantAxes"]:
                observed = {e["variant"][axis["id"]] for e in family["exercises"]}
                if axis["valueType"] == "enum":
                    self.assertEqual(observed, set(axis["allowedValues"]))
                elif "fixedValue" in axis:
                    self.assertEqual(observed, {axis["fixedValue"]})

    def test_each_introduced_rule_rejects_each_changed_consequence(self):
        rule_ids = {
            "band-pull-up-is-foot-loop-unquantified",
            "foot-loop-support-identifies-band-pull-up",
            "bent-over-extension-is-dumbbell-kickback",
            "kickback-fixture-pins-bent-over-extension",
            "inclined-torso-upper-arm-identifies-kickback",
            "ez-bar-inside-grip-pins-skull-crusher",
            "forehead-range-identifies-ez-skull-crusher",
            "standing-position-identifies-cable-abduction",
            "cable-cuff-identifies-standing-abduction",
            "standing-cable-abduction-pins-fixture",
        }
        observed = set()
        for family in self.families.values():
            for rule in family["exerciseRules"]:
                if rule["id"] not in rule_ids:
                    continue
                observed.add(rule["id"])
                predicate = rule["when"]
                exercise = next(e for e in family["exercises"]
                                if (catalog.exercise_rule_field(e, predicate["field"])
                                    == predicate["value"])
                                == (predicate["operator"] == "equals"))
                for assertion in rule["then"]:
                    mutated = copy.deepcopy(exercise)
                    path = assertion["field"]
                    if path.startswith("variant."):
                        mutated["variant"][path.split(".", 1)[1]] = "mutated"
                    else:
                        mutated[path] = "mutated"
                    with self.subTest(rule=rule["id"], consequence=path):
                        with self.assertRaises(catalog.ValidationFailure):
                            catalog.validate_exercise_rule_matches(
                                mutated, [rule], "introduced consequence mutation")
                for path in rule["requirePresent"] + rule["requireAbsent"]:
                    mutated = copy.deepcopy(exercise)
                    target = mutated["variant"] if path.startswith("variant.") else mutated
                    key = path.split(".", 1)[-1]
                    if path in rule["requirePresent"]:
                        target.pop(key)
                    else:
                        target[key] = "mutated"
                    with self.subTest(rule=rule["id"], presence=path):
                        with self.assertRaises(catalog.ValidationFailure):
                            catalog.validate_exercise_rule_matches(mutated, [rule], "presence mutation")
                for region in rule.get("requireAdditionalStabilityDemands", []):
                    mutated = copy.deepcopy(exercise)
                    mutated["additionalStabilityDemands"].remove(region)
                    with self.subTest(rule=rule["id"], stability=region):
                        with self.assertRaises(catalog.ValidationFailure):
                            catalog.validate_exercise_rule_matches(mutated, [rule], "stability mutation")
                requirements = list(rule.get("requireMuscleRequirements", []))
                requirements += [{"anyOf": [i["muscle"]]} for i in rule.get("requireInvolvement", [])]
                for requirement in requirements:
                    mutated = copy.deepcopy(exercise)
                    mutated["involvement"] = [i for i in mutated["involvement"]
                                               if i["muscle"] not in requirement["anyOf"]]
                    with self.subTest(rule=rule["id"], muscles=requirement["anyOf"]):
                        with self.assertRaises(catalog.ValidationFailure):
                            catalog.validate_exercise_rule_matches(mutated, [rule], "muscle mutation")
        self.assertEqual(observed, rule_ids)


if __name__ == "__main__":
    unittest.main()
