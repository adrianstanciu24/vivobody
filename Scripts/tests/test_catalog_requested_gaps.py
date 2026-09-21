"""Protect the requested assistance, unloaded, cable, and press fixtures."""

import copy
import hashlib
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import catalog


OWNERS = {
    "band-assisted-pull-up": "vertical-pull",
    "bodyweight-split-squat": "split-stance-squat",
    "bodyweight-bulgarian-split-squat": "split-stance-squat",
    "standing-cable-hip-abduction": "hip-abduction",
    "dumbbell-triceps-kickback": "elbow-extension",
    "ez-bar-skull-crusher": "elbow-extension",
    "cable-pull-through": "cable-pull-through",
    "pike-push-up": "pike-push-up",
}

SECOND_WAVE_RECORD_IDS = {
    "alternating-supine-bicycle-crunch",
    "single-leg-bodyweight-glute-bridge",
    "simultaneous-bilateral-dumbbell-front-raise",
}

TRX_SUSPENSION_RECORD_IDS = {
    "trx-squat", "trx-single-leg-squat", "trx-reverse-lunge",
    "trx-lateral-lunge", "trx-hamstring-curl", "trx-hip-press",
    "trx-low-row", "trx-high-row", "trx-reverse-fly",
    "trx-biceps-curl", "trx-chest-press", "trx-suspended-push-up",
    "trx-triceps-press", "trx-y-fly", "trx-suspended-plank",
    "trx-suspended-side-plank", "trx-body-saw", "trx-knee-tuck",
    "trx-pike", "trx-mountain-climber",
}

MEDICINE_BALL_RECORD_IDS = {
    "standing-medicine-ball-slam",
    "tall-kneeling-medicine-ball-slam",
    "rotational-medicine-ball-slam",
    "half-kneeling-rotational-medicine-ball-throw",
    "split-stance-rotational-medicine-ball-throw",
    "standing-rotational-medicine-ball-throw",
    "tall-kneeling-rotational-medicine-ball-throw",
    "lateral-shuffle-to-medicine-ball-throw",
    "crossover-to-medicine-ball-rotational-throw",
}

ROTATIONAL_STRENGTH_RECORD_IDS = {
    "seated-medicine-ball-russian-twist",
    "standing-two-hand-landmine-rotation",
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
        for catalog_id in ("band-assisted-pull-up", "bodyweight-split-squat",
                           "bodyweight-bulgarian-split-squat", "pike-push-up"):
            with self.subTest(exercise=catalog_id):
                _, exercise = self.fixture(catalog_id)
                self.assertEqual(exercise["loadMode"], "nonComparable")
                self.assertEqual(exercise["bodyweightFraction"], 0)
                self.assertEqual(exercise["defaultWeight"], 0)

    def test_existing_runtime_records_are_preserved(self):
        families = [catalog.load_json(p) for p in catalog.FAMILIES_ROOT.glob("*.json")]
        records = [r for r in catalog.compile_runtime_catalog(families)
                   if r["catalogID"] not in (
                       set(OWNERS) | SECOND_WAVE_RECORD_IDS
                       | TRX_SUSPENSION_RECORD_IDS | MEDICINE_BALL_RECORD_IDS
                       | ROTATIONAL_STRENGTH_RECORD_IDS
                   )]
        self.assertEqual(len(records), 254)
        encoded = json.dumps(records, sort_keys=True, separators=(",", ":")).encode()
        # Reviewed runtime after later catalog additions; source-only support
        # metadata may change without changing product records or muscle credit.
        self.assertEqual(hashlib.sha256(encoded).hexdigest(),
                         "918c60bc17a9f3a7fdbd3d2841afb376c2e6492c51e24466e28710fab61746e0")

    def test_unloaded_splits_do_not_credit_an_implement_hold(self):
        for catalog_id in ("bodyweight-split-squat", "bodyweight-bulgarian-split-squat"):
            _, exercise = self.fixture(catalog_id)
            muscles = {i["muscle"] for i in exercise["involvement"]}
            self.assertFalse(muscles & {"fingerFlexors", "extensorCarpiRadialis",
                                        "brachialis", "triceps", "trapeziusUpper"})
            self.assertEqual(exercise["laterality"], "unilateral")
            self.assertIn("sideOrDirection", exercise["execution"])

    def test_neighboring_movements_are_rejected(self):
        mutations = {
            "band-assisted-pull-up": [("loadMode", "assistanceSubtracted"),
                                      ("variant.lowerBodySupport", "assistancePlatform"),
                                      ("variant.gripOrientation", "supinated")],
            "bodyweight-split-squat": [("equipment", "dumbbell"),
                                       ("variant.interRepFootTransition", "step")],
            "bodyweight-bulgarian-split-squat": [("equipment", "barbell"),
                                                ("variant.trailFootSupport", "forefootFloor")],
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
            "loaded-split-squat-requires-implement-control",
            "paired-dumbbell-bench-split-squat-pins-fixture",
            "bodyweight-bench-split-squat-pins-fixture",
            "non-bench-split-squat-omits-bench-fixture",
            "bodyweight-split-squat-has-no-implement",
            "no-loadplacement-identifies-unloaded-split",
            "no-implementconfiguration-identifies-unloaded-split",
            "no-loadaccounting-identifies-unloaded-split",
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
