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

CORE_STRENGTH_EXPANSION_RECORD_IDS = {
    "alternating-forearm-plank-arm-reach",
    "alternating-forearm-plank-hip-drop",
    "alternating-high-plank-t-spine-rotation",
    "dumbbell-high-plank-drag",
    "kettlebell-high-plank-drag",
    "kneeling-barbell-rollout",
    "medicine-ball-straight-leg-sit-up",
    "medicine-ball-weighted-leg-lower",
    "standing-band-torso-twist",
    "straight-arm-straight-leg-sit-up",
    "trx-standing-rollout",
}

CORE_ENDURANCE_RECORD_IDS = {
    "forty-five-degree-bench-anchored-core-hold",
    "partner-anchored-lateral-trunk-hold",
    "dumbbell-weighted-supine-core-hold",
    "partner-perturbation-manual-core-hold",
}

BOXING_PRESS_BATCH_RECORD_IDS = {
    "dumbbell-push-press",
    "half-kneeling-single-arm-dumbbell-press",
    "half-kneeling-single-arm-landmine-press",
    "isometric-wall-press-hold",
    "landmine-punch",
    "medicine-ball-punch-throw",
    "standing-two-hand-landmine-press",
    "supine-medicine-ball-chest-pass",
}

REQUESTED_PULL_RECORD_IDS = {
    "speed-pull-up",
    "prone-tyw-hold-sequence",
    "single-arm-bent-over-row",
    "kettlebell-row-and-rotate",
}

PLYOMETRIC_RECORD_IDS = {
    "box-jump-20-40-cm",
    "paired-dumbbell-cmj",
    "stationary-pogos",
    "fast-pogos",
    "ice-skaters",
    "ice-skaters-with-jump",
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
                       | CORE_STRENGTH_EXPANSION_RECORD_IDS
                       | CORE_ENDURANCE_RECORD_IDS
                       | BOXING_PRESS_BATCH_RECORD_IDS
                       | REQUESTED_PULL_RECORD_IDS
                       | PLYOMETRIC_RECORD_IDS
                       | {
                           "goblet-split-squat",
                           "goblet-reverse-lunge",
                           "landmine-reverse-lunge-to-knee-raise",
                           "landmine-single-leg-romanian-deadlift",
                           "kettlebell-single-leg-romanian-deadlift",
                           "banded-single-leg-hip-thrust",
                           "two-hand-single-dumbbell-goblet-squat-to-press",
                           "two-hand-landmine-squat",
                           "alternating-landmine-squat-to-press",
                           "foot-anchored-band-reverse-lunge",
                           "quadruped-band-hip-extension",
                           "quadruped-fire-hydrants-with-band",
                           "single-kettlebell-romanian-deadlift",
                           "above-knee-band-side-walk",
                           "bodyweight-single-leg-hip-thrust",
                           "bodyweight-prisoner-box-squat-overhead-reach",
                           "partner-resisted-straight-punch-hold",
                       }
                   )]
        self.assertEqual(len(records), 259)
        encoded = json.dumps(records, sort_keys=True, separators=(",", ":")).encode()
        # Reviewed runtime after the unqualified Landmine Press alias moved from
        # the single-arm record to the new two-hand record. New batch records are
        # excluded above; source-only support metadata may change independently.
        self.assertEqual(hashlib.sha256(encoded).hexdigest(),
                         "9a853e5e4468e88fcbab06b8c05d369199177fe0d8eb75bf7819ca51bd6c31ee")

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
