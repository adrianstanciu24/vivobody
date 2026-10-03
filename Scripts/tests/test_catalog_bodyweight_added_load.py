"""Guard the approved BW-plus-load scope and constrained equipment boundaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import catalog


APPROVED_IDS = {
    "active-dead-hang", "passive-dead-hang", "scapular-pull-up", "speed-pull-up",
    "hanging-knee-raise", "hanging-straight-leg-raise", "pike-push-up", "plank",
    "side-plank", "hollow-hold", "wall-sit", "bodyweight-single-leg-hip-thrust",
    "nordic-curl", "kneeling-ab-wheel-rollout", "30-degree-curl-up",
    "straight-arm-straight-leg-sit-up", "bodyweight-side-lying-hip-abduction",
    "prone-table-bent-knee-hip-extension", "bodyweight-active-straight-leg-raise",
    "dead-bug", "alternating-forearm-plank-arm-reach",
    "alternating-high-plank-shoulder-tap", "supine-reverse-crunch",
    "trx-chest-press", "trx-low-row", "trx-high-row", "trx-biceps-curl",
    "trx-triceps-press", "trx-suspended-push-up",
}
TIMED_IDS = {"active-dead-hang", "passive-dead-hang", "plank", "side-plank", "hollow-hold", "wall-sit"}


class BodyweightAddedLoadTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.foundation = catalog.validate_foundation()
        cls.families = [catalog.load_json(p) for p in catalog.discovered_family_paths()]
        cls.owners = {e["catalogID"]: f for f in cls.families for e in f["exercises"]}
        cls.records = {r["catalogID"]: r for r in catalog.compile_runtime_catalog(cls.families)}

    def test_approved_scope_keeps_zero_added_load_and_tracking(self):
        self.assertEqual(len(APPROVED_IDS), 29)
        for identity in APPROVED_IDS:
            with self.subTest(identity=identity):
                record = self.records[identity]
                self.assertEqual((record["loadMode"], record["bodyweightFraction"], record["defaultWeight"]), ("bodyweightAdded", 1, 0))
                self.assertEqual(record["trackingMode"], "duration" if identity in TIMED_IDS else "reps")
                self.assertEqual(record["modality"], "power" if identity == "speed-pull-up" else "isometricStrength" if identity in TIMED_IDS else "dynamicStrength")
        for identity in ("trx-suspended-plank", "trx-suspended-side-plank", "swiss-ball-stir-the-pot", "bird-dog", "bodyweight-floor-squat-100-degrees"):
            self.assertEqual((self.records[identity]["loadMode"], self.records[identity]["bodyweightFraction"]), ("nonComparable", 0))

    def test_approved_coefficients_are_mutation_guarded(self):
        for identity in APPROVED_IDS:
            with self.subTest(identity=identity):
                family = copy.deepcopy(self.owners[identity])
                exercise = next(e for e in family["exercises"] if e["catalogID"] == identity)
                exercise["bodyweightFraction"] = 0.5
                with self.assertRaises(catalog.ValidationFailure):
                    catalog.validate_family(family, self.foundation, identity)

    def test_constrained_exception_cannot_be_transferred_to_another_id(self):
        for identity in catalog.BUNDLED_BODYWEIGHT_ADDED_EQUIPMENT:
            with self.subTest(identity=identity):
                family = copy.deepcopy(self.owners[identity])
                exercise = next(e for e in family["exercises"] if e["catalogID"] == identity)
                exercise["catalogID"] = "unapproved-added-load-fixture"
                with self.assertRaises(catalog.ValidationFailure):
                    catalog.validate_family(family, self.foundation, identity)

    def test_external_curl_and_extension_neighbours_reject_bw_accounting(self):
        for family_id in ("elbow-flexion", "elbow-extension"):
            source = next(f for f in self.families if f["id"] == family_id)
            for index, original in enumerate(source["exercises"]):
                if original["equipment"] == "suspensionTrainer":
                    continue
                with self.subTest(identity=original["catalogID"]):
                    family = copy.deepcopy(source)
                    family["exercises"][index]["loadMode"] = "bodyweightAdded"
                    family["exercises"][index]["bodyweightFraction"] = 1
                    with self.assertRaises(catalog.ValidationFailure):
                        catalog.validate_family(family, self.foundation, original["catalogID"])
