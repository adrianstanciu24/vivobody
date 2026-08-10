#!/usr/bin/env python3
#
#  test_catalog_v2.py
#  vivobody
#
#  Mutation-oriented tests for the isolated family-first catalog foundation.
#  They prove the validator rejects unknown muscles, invalid mesh ownership,
#  anatomically incapable movers, uncovered stability demands, undeclared
#  variant axes, forbidden prime actions, mismatched position conditions,
#  conditional muscle-role and variant-specific stability requirements, and
#  numeric involvement weights while keeping recommendations non-fatal.
#

from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path


SCRIPTS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_ROOT))

import catalog_v2  # noqa: E402


class CatalogV2FoundationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.foundation = catalog_v2.validate_foundation()
        cls.valid_family = catalog_v2.load_json(catalog_v2.FAMILY_FIXTURE_PATH)
        cls.horizontal_press = catalog_v2.load_json(
            catalog_v2.FAMILIES_ROOT / "horizontal-press.json"
        )
        cls.incline_press = catalog_v2.load_json(
            catalog_v2.FAMILIES_ROOT / "incline-press.json"
        )
        cls.decline_press = catalog_v2.load_json(
            catalog_v2.FAMILIES_ROOT / "decline-press.json"
        )
        cls.vertical_press = catalog_v2.load_json(
            catalog_v2.FAMILIES_ROOT / "vertical-press.json"
        )

    def family_copy(self) -> dict:
        return copy.deepcopy(self.valid_family)

    def horizontal_press_copy(self) -> dict:
        return copy.deepcopy(self.horizontal_press)

    def incline_press_copy(self) -> dict:
        return copy.deepcopy(self.incline_press)

    def decline_press_copy(self) -> dict:
        return copy.deepcopy(self.decline_press)

    def vertical_press_copy(self) -> dict:
        return copy.deepcopy(self.vertical_press)

    def additional_stability_demand_rule(self, demands: list[str]) -> dict:
        return {
            "id": "standing-requires-stability-demands",
            "description": (
                "Standing variants must explicitly declare their additional "
                "segment-stability demands."
            ),
            "when": {
                "field": "variant.support",
                "operator": "equals",
                "value": "standing",
            },
            "then": [],
            "requirePresent": [],
            "requireAbsent": [],
            "requireAdditionalStabilityDemands": demands,
        }

    def sternocostal_extension_family(self, action_requirement: object) -> dict:
        family = self.family_copy()
        family["fixed"]["planes"] = ["sagittal"]
        family["movementSignature"]["planeBasisActions"] = ["shoulder.extension"]
        family["movementSignature"]["primeActions"] = [action_requirement]
        family["exercises"][0]["involvement"] = [
            {"muscle": "pectoralisMajorSternocostal", "role": "primary"},
            {"muscle": "serratus", "role": "stabilizer"},
        ]
        return family

    def assert_family_fails(self, family: dict, message: str) -> None:
        with self.assertRaisesRegex(catalog_v2.ValidationFailure, message):
            catalog_v2.validate_family(family, self.foundation, "mutated fixture")

    def assert_horizontal_press_fails(self, family: dict, message: str) -> None:
        with self.assertRaisesRegex(catalog_v2.ValidationFailure, message):
            catalog_v2.validate_family(
                family,
                self.foundation,
                "mutated horizontal press",
            )

    def assert_incline_press_fails(self, family: dict, message: str) -> None:
        with self.assertRaisesRegex(catalog_v2.ValidationFailure, message):
            catalog_v2.validate_family(
                family,
                self.foundation,
                "mutated incline press",
            )

    def assert_decline_press_fails(self, family: dict, message: str) -> None:
        with self.assertRaisesRegex(catalog_v2.ValidationFailure, message):
            catalog_v2.validate_family(
                family,
                self.foundation,
                "mutated decline press",
            )

    def assert_vertical_press_fails(self, family: dict, message: str) -> None:
        with self.assertRaisesRegex(catalog_v2.ValidationFailure, message):
            catalog_v2.validate_family(
                family,
                self.foundation,
                "mutated vertical press",
            )

    def test_taxonomy_is_the_locked_32_muscle_clean_slate(self) -> None:
        self.assertEqual(set(self.foundation.muscle_by_id), catalog_v2.EXPECTED_MUSCLE_IDS)
        self.assertEqual(len(self.foundation.muscle_by_id), 32)

    def test_supraspinatus_is_explicitly_unvisualized(self) -> None:
        muscle = self.foundation.muscle_by_id["supraspinatus"]
        self.assertEqual(muscle["group"], "shoulders")
        self.assertEqual(muscle["meshBaseNames"], [])
        self.assertEqual(
            muscle["unvisualizedReason"],
            "BodyModel.scn has no supraspinatus surface mesh.",
        )

    def test_corrected_shoulder_capabilities_are_evidence_backed(self) -> None:
        anterior_deltoid = self.foundation.capabilities_by_muscle[
            "deltoidAnterior"
        ]
        supraspinatus = self.foundation.capabilities_by_muscle["supraspinatus"]
        self.assertIn(("shoulder.abduction", None), anterior_deltoid)
        self.assertIn(("shoulder.abduction", None), supraspinatus)
        self.assertNotIn(("shoulder.flexion", None), supraspinatus)
        self.assertIn(
            "shoulder",
            self.foundation.profile_by_muscle["supraspinatus"]["stabilizes"],
        )
        self.assertEqual(
            self.foundation.profile_by_muscle["supraspinatus"]["evidenceRefs"],
            [
                "ackland-2008-shoulder-moment-arms",
                "blache-2017-glenohumeral-stability",
            ],
        )

    def test_split_regions_own_exact_scene_meshes(self) -> None:
        for muscle_id, expected_meshes in catalog_v2.EXPECTED_SPLIT_MESHES.items():
            self.assertEqual(
                self.foundation.muscle_by_id[muscle_id]["meshBaseNames"],
                expected_meshes,
            )
        self.assertEqual(
            self.foundation.muscle_by_id["levatorScapulae"]["meshBaseNames"],
            ["Levator_Scapulaes"],
        )

    def test_every_muscle_has_an_evidence_backed_action_profile(self) -> None:
        self.assertEqual(
            set(self.foundation.profile_by_muscle),
            set(self.foundation.muscle_by_id),
        )
        for profile in self.foundation.profile_by_muscle.values():
            self.assertTrue(profile["produces"])
            self.assertTrue(profile["stabilizes"])
            self.assertTrue(profile["evidenceRefs"])

    def test_sternocostal_extension_is_conditioned_on_a_flexed_start(self) -> None:
        profile = self.foundation.profile_by_muscle["pectoralisMajorSternocostal"]
        self.assertIn(
            {
                "action": "shoulder.extension",
                "condition": "fromFlexedPosition",
            },
            profile["produces"],
        )
        capabilities = self.foundation.capabilities_by_muscle[
            "pectoralisMajorSternocostal"
        ]
        self.assertIn(
            ("shoulder.extension", "fromFlexedPosition"),
            capabilities,
        )
        self.assertNotIn(("shoulder.extension", None), capabilities)

    def test_valid_family_fixture_passes_without_warnings(self) -> None:
        warnings = catalog_v2.validate_family(
            self.family_copy(),
            self.foundation,
            "valid fixture",
        )
        self.assertEqual(warnings, [])

    def test_matching_rule_requires_explicit_additional_stability_demand(self) -> None:
        family = self.family_copy()
        family["exerciseRules"] = [
            self.additional_stability_demand_rule(["spine"])
        ]
        family["exercises"][0]["variant"]["support"] = "standing"
        self.assert_family_fails(
            family,
            "violates exercise rule standing-requires-stability-demands: "
            "spine must be declared in additionalStabilityDemands",
        )

    def test_required_additional_stability_demand_needs_capable_muscle(self) -> None:
        family = self.family_copy()
        family["exerciseRules"] = [
            self.additional_stability_demand_rule(["spine"])
        ]
        exercise = family["exercises"][0]
        exercise["variant"]["support"] = "standing"
        exercise["additionalStabilityDemands"] = ["spine"]
        self.assert_family_fails(
            family,
            "has no assigned muscle capable of stabilizing spine",
        )

    def test_required_additional_stability_demand_accepts_capable_muscle(self) -> None:
        family = self.family_copy()
        family["exerciseRules"] = [
            self.additional_stability_demand_rule(["spine"])
        ]
        family["musclePolicy"]["allowedByRole"]["stabilizer"].append("abs")
        exercise = family["exercises"][0]
        exercise["variant"]["support"] = "standing"
        exercise["additionalStabilityDemands"] = ["spine"]
        exercise["involvement"].append({"muscle": "abs", "role": "stabilizer"})
        warnings = catalog_v2.validate_family(
            family,
            self.foundation,
            "standing stability fixture",
        )
        self.assertEqual(warnings, [])

    def test_additional_stability_rule_rejects_unknown_region(self) -> None:
        family = self.family_copy()
        family["exerciseRules"] = [
            self.additional_stability_demand_rule(["inventedRegion"])
        ]
        self.assert_family_fails(
            family,
            "requireAdditionalStabilityDemands references unknown stability regions: "
            "inventedRegion",
        )

    def test_additional_stability_rule_rejects_duplicate_region(self) -> None:
        family = self.family_copy()
        family["exerciseRules"] = [
            self.additional_stability_demand_rule(["spine", "spine"])
        ]
        self.assert_family_fails(
            family,
            "requireAdditionalStabilityDemands contains duplicates",
        )

    def test_family_schema_declares_additional_stability_demand_rule_shape(
        self,
    ) -> None:
        property_schema = self.foundation.family_schema["$defs"]["exerciseRule"][
            "properties"
        ]["requireAdditionalStabilityDemands"]
        self.assertEqual(
            property_schema,
            {
                "type": "array",
                "uniqueItems": True,
                "items": {"$ref": "#/$defs/symbolID"},
            },
        )

    def test_real_horizontal_press_family_is_transverse_and_reviewed(self) -> None:
        warnings = catalog_v2.validate_family(
            self.horizontal_press_copy(),
            self.foundation,
            "horizontal press",
        )
        self.assertEqual(warnings, [])
        self.assertEqual(self.horizontal_press["fixed"]["planes"], ["transverse"])
        self.assertEqual(
            self.horizontal_press["movementSignature"]["planeBasisActions"],
            ["shoulder.horizontalAdduction"],
        )
        self.assertEqual(
            self.horizontal_press["movementSignature"]["forbiddenPrimeActions"],
            ["shoulder.flexion", "shoulder.extension"],
        )
        self.assertEqual(len(self.horizontal_press["exercises"]), 12)

    def test_horizontal_press_rejects_sagittal_shoulder_prime_actions(self) -> None:
        for action in ("shoulder.flexion", "shoulder.extension"):
            with self.subTest(action=action):
                family = self.horizontal_press_copy()
                family["exercises"][0]["additionalPrimeActions"] = [action]
                self.assert_horizontal_press_fails(
                    family,
                    f"declares forbidden prime action {action}",
                )

    def test_additional_same_joint_action_cannot_introduce_another_plane(self) -> None:
        family = self.family_copy()
        family["exercises"][0]["additionalPrimeActions"] = [
            "shoulder.adduction"
        ]
        self.assert_family_fails(
            family,
            "additional prime action shoulder.adduction uses undeclared "
            "frontal plane at shoulder",
        )

    def test_family_prime_action_cannot_bypass_its_plane_basis(self) -> None:
        family = self.family_copy()
        family["movementSignature"]["primeActions"].append(
            "shoulder.adduction"
        )
        self.assert_family_fails(
            family,
            "prime action shoulder.adduction uses undeclared frontal plane "
            "at shoulder",
        )

    def test_chest_press_families_share_machine_axis_vocabulary(self) -> None:
        for family in (
            self.horizontal_press,
            self.incline_press,
            self.decline_press,
        ):
            with self.subTest(family=family["id"]):
                axes = {axis["id"]: axis for axis in family["variantAxes"]}
                self.assertEqual(
                    axes["fixedPath"],
                    {
                        "id": "fixedPath",
                        "valueType": "boolean",
                        "required": True,
                        "description": (
                            "Whether rails or a lever constrain the external "
                            "load path."
                        ),
                    },
                )
                self.assertEqual(
                    axes["machineType"],
                    {
                        "id": "machineType",
                        "valueType": "enum",
                        "required": False,
                        "description": (
                            "The machine mechanism when equipment is machine."
                        ),
                        "allowedValues": ["smith", "convergingChestPress"],
                    },
                )

        vertical_axes = {
            axis["id"]: axis for axis in self.vertical_press["variantAxes"]
        }
        self.assertEqual(
            vertical_axes["fixedPath"]["description"],
            "Whether rails or a lever constrain the external load path.",
        )
        self.assertEqual(
            vertical_axes["machineType"],
            {
                "id": "machineType",
                "valueType": "enum",
                "required": False,
                "description": "The machine mechanism when equipment is machine.",
                "allowedValues": ["smith", "convergingShoulderPress"],
            },
        )

    def test_press_families_enforce_machine_path_semantics(self) -> None:
        required_rules = {
            "machine-requires-fixed-path-and-type",
            "non-machine-requires-free-path",
        }
        for family in (
            self.horizontal_press,
            self.incline_press,
            self.decline_press,
            self.vertical_press,
        ):
            with self.subTest(family=family["id"]):
                rule_ids = {rule["id"] for rule in family["exerciseRules"]}
                self.assertTrue(required_rules <= rule_ids)
                axes = {axis["id"]: axis for axis in family["variantAxes"]}
                for exercise in family["exercises"]:
                    variant = exercise["variant"]
                    if exercise["equipment"] == "machine":
                        self.assertIs(variant["fixedPath"], True)
                        self.assertIn(
                            variant["machineType"],
                            axes["machineType"]["allowedValues"],
                        )
                    else:
                        self.assertIs(variant["fixedPath"], False)
                        self.assertNotIn("machineType", variant)

    def test_support_constrained_presses_share_scapular_stabilizer_pair(self) -> None:
        required_pair = {
            ("serratus", "stabilizer"),
            ("trapeziusMiddle", "stabilizer"),
        }
        for family in (
            self.horizontal_press,
            self.incline_press,
            self.decline_press,
        ):
            with self.subTest(family=family["id"]):
                rule = next(
                    rule
                    for rule in family["exerciseRules"]
                    if rule["id"]
                    == "support-constrained-translation-requires-stabilizer-pair"
                )
                self.assertEqual(
                    {
                        (assignment["muscle"], assignment["role"])
                        for assignment in rule["requireInvolvement"]
                    },
                    required_pair,
                )
                for exercise in family["exercises"]:
                    if (
                        exercise["variant"]["scapularTranslation"]
                        != "supportConstrained"
                    ):
                        continue
                    assignments = {
                        (assignment["muscle"], assignment["role"])
                        for assignment in exercise["involvement"]
                    }
                    self.assertTrue(
                        required_pair <= assignments,
                        exercise["catalogID"],
                    )

    def test_support_constrained_press_rejects_missing_scapular_stabilizer(self) -> None:
        for original in (
            self.horizontal_press,
            self.incline_press,
            self.decline_press,
        ):
            for exercise_index, original_exercise in enumerate(
                original["exercises"]
            ):
                if (
                    original_exercise["variant"]["scapularTranslation"]
                    != "supportConstrained"
                ):
                    continue
                for muscle_id in ("serratus", "trapeziusMiddle"):
                    with self.subTest(
                        family=original["id"],
                        exercise=original_exercise["catalogID"],
                        muscle=muscle_id,
                    ):
                        family = copy.deepcopy(original)
                        exercise = family["exercises"][exercise_index]
                        exercise["involvement"] = [
                            assignment
                            for assignment in exercise["involvement"]
                            if assignment["muscle"] != muscle_id
                        ]
                        with self.assertRaisesRegex(
                            catalog_v2.ValidationFailure,
                            f"{muscle_id} must be assigned as stabilizer",
                        ):
                            catalog_v2.validate_family(
                                family,
                                self.foundation,
                                f"mutated {original['id']}",
                            )

    def test_angled_press_current_scope_is_bilateral_and_supported(self) -> None:
        for family in (self.incline_press, self.decline_press):
            with self.subTest(family=family["id"]):
                self.assertEqual(
                    set(family["allowed"]["equipment"]),
                    {"barbell", "dumbbell", "machine"},
                )
                self.assertEqual(family["allowed"]["lateralities"], ["bilateral"])
                self.assertEqual(family["allowed"]["loadModes"], ["external"])
                axes = {axis["id"]: axis for axis in family["variantAxes"]}
                self.assertEqual(axes["kineticChain"]["allowedValues"], ["open"])
                self.assertEqual(
                    set(axes["torsoSupport"]["allowedValues"]),
                    {"bench", "machinePad"},
                )
                self.assertEqual(
                    axes["scapularTranslation"]["allowedValues"],
                    ["supportConstrained"],
                )

    def test_press_families_share_geometry_axis_vocabulary(self) -> None:
        families = (
            self.horizontal_press,
            self.incline_press,
            self.decline_press,
            self.vertical_press,
        )
        axes_by_family = {
            family["id"]: {
                axis["id"]: axis
                for axis in family["variantAxes"]
            }
            for family in families
        }
        for family_id, axes in axes_by_family.items():
            with self.subTest(family=family_id):
                self.assertIn("kineticChain", axes)
                self.assertIn("scapularTranslation", axes)
                self.assertIn("pressInclinationDegrees", axes)
                self.assertNotIn("scapularFreedom", axes)
                self.assertNotIn("inclineAngleDegrees", axes)
                self.assertNotIn("declineAngleDegrees", axes)

        for axis_id in (
            "kineticChain",
            "scapularTranslation",
            "pressInclinationDegrees",
        ):
            descriptions = {
                axes[axis_id]["description"]
                for axes in axes_by_family.values()
            }
            self.assertEqual(len(descriptions), 1, axis_id)
        self.assertEqual(
            {
                family_id: (
                    axes["pressInclinationDegrees"]["minimum"],
                    axes["pressInclinationDegrees"]["maximum"],
                )
                for family_id, axes in axes_by_family.items()
            },
            {
                "horizontal-press": (0, 0),
                "incline-press": (15, 45),
                "decline-press": (-30, -10),
                "vertical-press": (75, 90),
            },
        )
        self.assertEqual(
            {
                family["id"]: {
                    exercise["variant"]["pressInclinationDegrees"]
                    for exercise in family["exercises"]
                }
                for family in families
            },
            {
                "horizontal-press": {0},
                "incline-press": {30},
                "decline-press": {-15},
                "vertical-press": {75, 80, 85, 90},
            },
        )

    def test_real_vertical_press_family_is_multi_plane_and_strict(self) -> None:
        warnings = catalog_v2.validate_family(
            self.vertical_press_copy(),
            self.foundation,
            "vertical press",
        )
        self.assertEqual(warnings, [])
        self.assertEqual(self.vertical_press["fixed"]["direction"], "vertical")
        self.assertEqual(
            set(self.vertical_press["fixed"]["planes"]),
            {"sagittal", "frontal"},
        )
        self.assertEqual(
            self.vertical_press["movementSignature"]["planeBasisActions"],
            ["shoulder.flexion", "shoulder.abduction"],
        )
        self.assertEqual(
            [
                exercise["catalogID"]
                for exercise in self.vertical_press["exercises"]
            ],
            [
                "standing-barbell-overhead-press",
                "standing-dumbbell-overhead-press",
                "single-arm-standing-dumbbell-overhead-press",
                "seated-dumbbell-overhead-press",
                "seated-barbell-overhead-press",
                "unsupported-seated-dumbbell-overhead-press",
                "single-arm-seated-dumbbell-overhead-press",
                "single-arm-standing-kettlebell-overhead-press",
                "seated-smith-machine-overhead-press",
                "machine-shoulder-press",
            ],
        )

    def test_vertical_press_roster_is_the_reviewed_coverage_matrix(self) -> None:
        actual = {}
        for exercise in self.vertical_press["exercises"]:
            variant = exercise["variant"]
            actual[exercise["catalogID"]] = (
                exercise["equipment"],
                exercise["laterality"],
                variant["bodyPosition"],
                variant["torsoSupport"],
                variant["scapularTranslation"],
                variant["pressInclinationDegrees"],
                variant["gripOrientation"],
                variant["fixedPath"],
                variant.get("machineType"),
                variant.get("kettlebellOrientation"),
                tuple(exercise["additionalStabilityDemands"]),
            )

        self.assertEqual(
            actual,
            {
                "standing-barbell-overhead-press": (
                    "barbell", "bilateral", "standing", "none", "free",
                    90, "pronated", False, None, None, ("spine", "pelvis"),
                ),
                "standing-dumbbell-overhead-press": (
                    "dumbbell", "bilateral", "standing", "none", "free",
                    90, "pronated", False, None, None, ("spine", "pelvis"),
                ),
                "single-arm-standing-dumbbell-overhead-press": (
                    "dumbbell", "unilateral", "standing", "none", "free",
                    90, "pronated", False, None, None, ("spine", "pelvis"),
                ),
                "seated-dumbbell-overhead-press": (
                    "dumbbell", "bilateral", "seated", "bench",
                    "supportConstrained", 85, "pronated", False, None, None,
                    (),
                ),
                "seated-barbell-overhead-press": (
                    "barbell", "bilateral", "seated", "bench",
                    "supportConstrained", 80, "pronated", False, None, None,
                    (),
                ),
                "unsupported-seated-dumbbell-overhead-press": (
                    "dumbbell", "bilateral", "seated", "none", "free",
                    90, "pronated", False, None, None, ("spine",),
                ),
                "single-arm-seated-dumbbell-overhead-press": (
                    "dumbbell", "unilateral", "seated", "bench",
                    "supportConstrained", 75, "neutral", False, None, None,
                    ("spine", "pelvis"),
                ),
                "single-arm-standing-kettlebell-overhead-press": (
                    "kettlebell", "unilateral", "standing", "none", "free",
                    90, "neutral", False, None, "standard",
                    ("spine", "pelvis"),
                ),
                "seated-smith-machine-overhead-press": (
                    "machine", "bilateral", "seated", "bench",
                    "supportConstrained", 85, "pronated", True, "smith", None,
                    (),
                ),
                "machine-shoulder-press": (
                    "machine", "bilateral", "seated", "machinePad",
                    "supportConstrained", 80, "neutral", True,
                    "convergingShoulderPress", None, (),
                ),
            },
        )

    def test_vertical_press_roster_covers_every_admitted_axis_value(self) -> None:
        exercises = self.vertical_press["exercises"]
        top_level_fields = {
            "equipment": "equipment",
            "modalities": "modality",
            "trackingModes": "trackingMode",
            "loadModes": "loadMode",
            "lateralities": "laterality",
        }
        for allowed_key, exercise_key in top_level_fields.items():
            with self.subTest(field=allowed_key):
                self.assertEqual(
                    {exercise[exercise_key] for exercise in exercises},
                    set(self.vertical_press["allowed"][allowed_key]),
                )

        axes = {
            axis["id"]: axis for axis in self.vertical_press["variantAxes"]
        }
        for axis_id, axis in axes.items():
            observed = {
                exercise["variant"][axis_id]
                for exercise in exercises
                if axis_id in exercise["variant"]
            }
            with self.subTest(axis=axis_id):
                if axis["valueType"] == "enum":
                    self.assertEqual(observed, set(axis["allowedValues"]))
                elif axis["valueType"] == "boolean":
                    self.assertEqual(observed, {False, True})
                elif axis["valueType"] == "number":
                    self.assertIn(axis["minimum"], observed)
                    self.assertIn(axis["maximum"], observed)

    def test_every_vertical_press_rule_matches_a_real_roster_branch(self) -> None:
        exercises = self.vertical_press["exercises"]

        def field_value(exercise: dict, path: str):
            if path.startswith("variant."):
                return exercise["variant"].get(path.removeprefix("variant."))
            return exercise.get(path)

        for rule in self.vertical_press["exerciseRules"]:
            predicate = rule["when"]
            values = [
                field_value(exercise, predicate["field"])
                for exercise in exercises
            ]
            if predicate["operator"] == "equals":
                matches = [value == predicate["value"] for value in values]
            else:
                matches = [value != predicate["value"] for value in values]
            with self.subTest(rule=rule["id"]):
                self.assertTrue(any(matches), "rule has no real matching exercise")
                self.assertTrue(
                    any(not match for match in matches),
                    "rule has no contrasting real exercise",
                )

    def test_vertical_press_branch_specific_evidence_is_explicit(self) -> None:
        evidence_by_exercise = {
            exercise["catalogID"]: set(exercise["evidenceRefs"])
            for exercise in self.vertical_press["exercises"]
        }
        self.assertIn(
            "saeterbakken-2012-shoulder-press-core",
            evidence_by_exercise["single-arm-seated-dumbbell-overhead-press"],
        )
        self.assertIn(
            "padovan-2024-standing-overhead-press",
            evidence_by_exercise[
                "single-arm-standing-kettlebell-overhead-press"
            ],
        )
        self.assertIn(
            "balsalobre-fernandez-2018-smith-military-press",
            evidence_by_exercise["seated-smith-machine-overhead-press"],
        )
        self.assertIn(
            "coratella-2022-overhead-press-variants",
            evidence_by_exercise["machine-shoulder-press"],
        )
        self.assertNotIn(
            "saeterbakken-2012-shoulder-press-core",
            evidence_by_exercise[
                "unsupported-seated-dumbbell-overhead-press"
            ],
        )

    def test_vertical_press_requires_dynamic_scapular_contributors(self) -> None:
        for exercise in self.vertical_press["exercises"]:
            role_by_muscle = {
                assignment["muscle"]: assignment["role"]
                for assignment in exercise["involvement"]
            }
            for muscle_id in (
                "serratus",
                "trapeziusUpper",
                "trapeziusLower",
            ):
                with self.subTest(
                    exercise=exercise["catalogID"],
                    muscle=muscle_id,
                ):
                    self.assertEqual(role_by_muscle[muscle_id], "secondary")

    def test_standing_dumbbell_overhead_press_is_reviewed_free_path_variant(
        self,
    ) -> None:
        exercise = next(
            exercise
            for exercise in self.vertical_press["exercises"]
            if exercise["catalogID"] == "standing-dumbbell-overhead-press"
        )
        self.assertEqual(exercise["equipment"], "dumbbell")
        self.assertEqual(exercise["laterality"], "bilateral")
        self.assertEqual(
            exercise["variant"],
            {
                "kineticChain": "open",
                "bodyPosition": "standing",
                "torsoSupport": "none",
                "scapularTranslation": "free",
                "pressInclinationDegrees": 90,
                "gripOrientation": "pronated",
                "fixedPath": False,
                "lowerBodyContribution": "none",
                "pressPath": "frontScapular",
            },
        )
        self.assertEqual(
            {
                assignment["muscle"]: assignment["role"]
                for assignment in exercise["involvement"]
            },
            {
                "deltoidAnterior": "primary",
                "deltoidLateral": "secondary",
                "supraspinatus": "secondary",
                "triceps": "secondary",
                "serratus": "secondary",
                "trapeziusUpper": "secondary",
                "trapeziusLower": "secondary",
                "pectoralisMajorClavicular": "secondary",
                "externalRotators": "stabilizer",
                "subscapularis": "stabilizer",
                "abs": "stabilizer",
                "obliques": "stabilizer",
                "lowerBack": "stabilizer",
            },
        )
        self.assertEqual(
            exercise["evidenceRefs"],
            [
                "ichihashi-2014-military-press-kinematics",
                "saeterbakken-2012-shoulder-press-core",
                "saeterbakken-2013-shoulder-press-position",
            ],
        )

    def test_single_arm_standing_dumbbell_press_is_laterality_only_delta(
        self,
    ) -> None:
        exercises_by_id = {
            exercise["catalogID"]: exercise
            for exercise in self.vertical_press["exercises"]
        }
        bilateral = exercises_by_id["standing-dumbbell-overhead-press"]
        unilateral = exercises_by_id[
            "single-arm-standing-dumbbell-overhead-press"
        ]
        self.assertEqual(unilateral["equipment"], "dumbbell")
        self.assertEqual(bilateral["laterality"], "bilateral")
        self.assertEqual(unilateral["laterality"], "unilateral")
        self.assertEqual(unilateral["variant"], bilateral["variant"])
        self.assertEqual(unilateral["involvement"], bilateral["involvement"])
        self.assertEqual(
            unilateral["additionalStabilityDemands"],
            ["spine", "pelvis"],
        )
        self.assertEqual(unilateral["evidenceRefs"], bilateral["evidenceRefs"])

    def test_unilateral_vertical_press_rule_independently_requires_pelvis(
        self,
    ) -> None:
        family = self.vertical_press_copy()
        exercise = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"]
            == "single-arm-standing-dumbbell-overhead-press"
        )
        exercise["variant"]["bodyPosition"] = "seated"
        exercise["additionalStabilityDemands"] = ["spine"]
        self.assert_vertical_press_fails(
            family,
            "violates exercise rule "
            "unilateral-requires-trunk-and-pelvic-control: "
            "pelvis must be declared in additionalStabilityDemands",
        )

    def test_seated_dumbbell_overhead_press_is_supported_85_degree_variant(
        self,
    ) -> None:
        exercises_by_id = {
            exercise["catalogID"]: exercise
            for exercise in self.vertical_press["exercises"]
        }
        standing = exercises_by_id["standing-dumbbell-overhead-press"]
        seated = exercises_by_id["seated-dumbbell-overhead-press"]
        self.assertEqual(seated["equipment"], "dumbbell")
        self.assertEqual(seated["laterality"], "bilateral")
        self.assertEqual(
            seated["variant"],
            {
                "kineticChain": "open",
                "bodyPosition": "seated",
                "torsoSupport": "bench",
                "scapularTranslation": "supportConstrained",
                "pressInclinationDegrees": 85,
                "gripOrientation": "pronated",
                "fixedPath": False,
                "lowerBodyContribution": "none",
                "pressPath": "frontScapular",
            },
        )
        standing_roles = {
            assignment["muscle"]: assignment["role"]
            for assignment in standing["involvement"]
        }
        seated_roles = {
            assignment["muscle"]: assignment["role"]
            for assignment in seated["involvement"]
        }
        self.assertEqual(
            seated_roles,
            {
                muscle: role
                for muscle, role in standing_roles.items()
                if muscle not in {"abs", "obliques", "lowerBack"}
            },
        )
        self.assertEqual(seated["additionalStabilityDemands"], [])
        self.assertEqual(
            seated["evidenceRefs"],
            [
                "ichihashi-2014-military-press-kinematics",
                "luczak-2013-dumbbell-press-inclinations",
                "saeterbakken-2012-shoulder-press-core",
                "saeterbakken-2013-shoulder-press-position",
            ],
        )

    def test_supported_vertical_press_rejects_free_scapular_translation(
        self,
    ) -> None:
        family = self.vertical_press_copy()
        exercise = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"] == "seated-dumbbell-overhead-press"
        )
        exercise["variant"]["scapularTranslation"] = "free"
        self.assert_vertical_press_fails(
            family,
            "violates exercise rule "
            "supported-torso-is-seated-and-translation-constrained: "
            "variant.scapularTranslation must equal 'supportConstrained'",
        )

    def test_vertical_press_treats_supraspinatus_as_secondary_mover(self) -> None:
        family = self.vertical_press_copy()
        supraspinatus = next(
            assignment
            for assignment in family["exercises"][0]["involvement"]
            if assignment["muscle"] == "supraspinatus"
        )
        self.assertEqual(supraspinatus["role"], "secondary")
        supraspinatus["role"] = "stabilizer"
        self.assert_vertical_press_fails(
            family,
            "does not allow supraspinatus as stabilizer",
        )

    def test_standing_vertical_press_requires_spine_and_pelvis_demands(self) -> None:
        family = self.vertical_press_copy()
        family["exercises"][0]["additionalStabilityDemands"] = ["spine"]
        self.assert_vertical_press_fails(
            family,
            "violates exercise rule "
            "standing-requires-unsupported-upright-pelvic-control: "
            "pelvis must be declared in additionalStabilityDemands",
        )

    def test_unsupported_seated_vertical_press_still_requires_spine_demand(self) -> None:
        family = self.vertical_press_copy()
        exercise = family["exercises"][0]
        exercise["variant"]["bodyPosition"] = "seated"
        exercise["additionalStabilityDemands"] = ["pelvis"]
        self.assert_vertical_press_fails(
            family,
            "violates exercise rule "
            "unsupported-torso-is-upright-free-and-spine-stabilized: "
            "spine must be declared in additionalStabilityDemands",
        )

    def test_standing_vertical_press_must_remain_fully_upright(self) -> None:
        family = self.vertical_press_copy()
        family["exercises"][0]["variant"]["pressInclinationDegrees"] = 85
        self.assert_vertical_press_fails(
            family,
            "variant.pressInclinationDegrees must equal 90",
        )

    def test_vertical_press_rejects_lower_body_propulsion_action(self) -> None:
        family = self.vertical_press_copy()
        family["exercises"][0]["additionalPrimeActions"] = ["hip.extension"]
        self.assert_vertical_press_fails(
            family,
            "declares forbidden prime action hip.extension",
        )

    def test_vertical_press_rejects_trunk_motion_as_a_prime_action(self) -> None:
        for action in (
            "spine.flexion",
            "spine.extension",
            "spine.lateralFlexion",
            "spine.rotation",
        ):
            with self.subTest(action=action):
                family = self.vertical_press_copy()
                family["exercises"][0]["additionalPrimeActions"] = [action]
                self.assert_vertical_press_fails(
                    family,
                    f"declares forbidden prime action {action}",
                )

    def test_vertical_press_rejects_opposite_scapular_actions(self) -> None:
        for action in ("scapula.downwardRotation", "scapula.anteriorTilt"):
            with self.subTest(action=action):
                family = self.vertical_press_copy()
                family["exercises"][0]["additionalPrimeActions"] = [action]
                self.assert_vertical_press_fails(
                    family,
                    f"declares forbidden prime action {action}",
                )

    def test_vertical_press_rejects_bottom_up_kettlebell_orientation(self) -> None:
        family = self.vertical_press_copy()
        exercise = family["exercises"][0]
        exercise["equipment"] = "kettlebell"
        exercise["variant"]["kettlebellOrientation"] = "bottomUp"
        self.assert_vertical_press_fails(
            family,
            "kettlebellOrientation has disallowed value 'bottomUp'",
        )

    def test_vertical_press_accepts_only_standard_neutral_kettlebell_setup(self) -> None:
        family = self.vertical_press_copy()
        exercise = family["exercises"][0]
        exercise["equipment"] = "kettlebell"
        exercise["laterality"] = "unilateral"
        exercise["variant"]["gripOrientation"] = "neutral"
        exercise["variant"]["kettlebellOrientation"] = "standard"
        warnings = catalog_v2.validate_family(
            family,
            self.foundation,
            "standard kettlebell vertical-press fixture",
        )
        self.assertEqual(warnings, [])

        exercise["variant"]["gripOrientation"] = "pronated"
        self.assert_vertical_press_fails(
            family,
            "violates exercise rule kettlebell-requires-standard-orientation: "
            "variant.gripOrientation must equal 'neutral'",
        )

    def test_vertical_press_kettlebell_assertion_requires_orientation(self) -> None:
        family = self.vertical_press_copy()
        exercise = family["exercises"][0]
        exercise["equipment"] = "kettlebell"
        exercise["laterality"] = "unilateral"
        exercise["variant"]["gripOrientation"] = "neutral"
        self.assert_vertical_press_fails(
            family,
            "violates exercise rule kettlebell-requires-standard-orientation: "
            "variant.kettlebellOrientation must equal 'standard'",
        )

    def test_vertical_press_machine_variant_rules_are_compatible(self) -> None:
        family = self.vertical_press_copy()
        exercise = family["exercises"][0]
        exercise["equipment"] = "machine"
        exercise["variant"].update(
            {
                "bodyPosition": "seated",
                "torsoSupport": "machinePad",
                "scapularTranslation": "supportConstrained",
                "pressInclinationDegrees": 80,
                "gripOrientation": "neutral",
                "fixedPath": True,
                "machineType": "convergingShoulderPress",
            }
        )
        exercise["additionalStabilityDemands"] = []
        exercise["involvement"] = [
            assignment
            for assignment in exercise["involvement"]
            if assignment["muscle"] not in {"abs", "obliques", "lowerBack"}
        ]
        warnings = catalog_v2.validate_family(
            family,
            self.foundation,
            "converging shoulder-press fixture",
        )
        self.assertEqual(warnings, [])

    def test_vertical_press_rejects_unilateral_standard_bar_and_smith(self) -> None:
        cases = (
            (
                "standing-barbell-overhead-press",
                "barbell-requires-bilateral-setup",
            ),
            (
                "seated-smith-machine-overhead-press",
                "smith-requires-bilateral-setup",
            ),
        )
        for catalog_id, rule_id in cases:
            with self.subTest(exercise=catalog_id):
                family = self.vertical_press_copy()
                exercise = next(
                    exercise
                    for exercise in family["exercises"]
                    if exercise["catalogID"] == catalog_id
                )
                exercise["laterality"] = "unilateral"
                exercise["additionalStabilityDemands"] = ["spine", "pelvis"]
                if not any(
                    assignment["muscle"] == "abs"
                    for assignment in exercise["involvement"]
                ):
                    exercise["involvement"].append(
                        {"muscle": "abs", "role": "stabilizer"}
                    )
                self.assert_vertical_press_fails(
                    family,
                    f"violates exercise rule {rule_id}: "
                    "laterality must equal 'bilateral'",
                )

    def test_vertical_press_machine_pad_cannot_label_free_weight_support(
        self,
    ) -> None:
        family = self.vertical_press_copy()
        exercise = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"] == "seated-dumbbell-overhead-press"
        )
        exercise["variant"]["torsoSupport"] = "machinePad"
        self.assert_vertical_press_fails(
            family,
            "violates exercise rule machine-pad-requires-purpose-built-machine: "
            "equipment must equal 'machine'",
        )

    def test_vertical_press_rejects_unowned_angle_band(self) -> None:
        for angle, message in ((74, "is below 75"), (91, "exceeds 90")):
            with self.subTest(angle=angle):
                family = self.vertical_press_copy()
                exercise = family["exercises"][0]
                exercise["variant"]["bodyPosition"] = "seated"
                exercise["variant"]["torsoSupport"] = "bench"
                exercise["variant"]["scapularTranslation"] = "supportConstrained"
                exercise["variant"]["pressInclinationDegrees"] = angle
                self.assert_vertical_press_fails(family, message)

    def test_horizontal_press_rejects_nonzero_inclination(self) -> None:
        family = self.horizontal_press_copy()
        family["exercises"][0]["variant"]["pressInclinationDegrees"] = 1
        self.assert_horizontal_press_fails(
            family,
            "pressInclinationDegrees exceeds 0",
        )

    def test_angled_press_rejects_deferred_variant_categories(self) -> None:
        mutations = (
            ("equipment", "cable", "selects disallowed equipment: cable"),
            ("equipment", "bodyweight", "selects disallowed equipment: bodyweight"),
            ("laterality", "unilateral", "selects disallowed lateralities: unilateral"),
        )
        for original in (self.incline_press, self.decline_press):
            for field, value, message in mutations:
                with self.subTest(family=original["id"], field=field, value=value):
                    family = copy.deepcopy(original)
                    family["exercises"][0][field] = value
                    with self.assertRaisesRegex(
                        catalog_v2.ValidationFailure,
                        message,
                    ):
                        catalog_v2.validate_family(
                            family,
                            self.foundation,
                            f"mutated {original['id']} scope",
                        )

    def test_deferred_grip_and_elevation_axes_remain_undeclared(self) -> None:
        mutations = (
            ("barbell-bench-press", "gripWidth", "narrow"),
            ("push-up", "bodyAngleDegrees", 20),
        )
        for catalog_id, axis, value in mutations:
            with self.subTest(axis=axis):
                family = self.horizontal_press_copy()
                exercise = next(
                    candidate
                    for candidate in family["exercises"]
                    if candidate["catalogID"] == catalog_id
                )
                exercise["variant"][axis] = value
                self.assert_horizontal_press_fails(
                    family,
                    f"contains undeclared axes: {axis}",
                )

    def test_horizontal_pushup_support_scope_is_feet_or_knees(self) -> None:
        lower_body_support = next(
            axis
            for axis in self.horizontal_press["variantAxes"]
            if axis["id"] == "lowerBodySupport"
        )
        self.assertEqual(
            set(lower_body_support["allowedValues"]),
            {"feet", "knees"},
        )

    def test_horizontal_machine_press_requires_a_fixed_path(self) -> None:
        family = self.horizontal_press_copy()
        smith_press = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"] == "smith-machine-bench-press"
        )
        smith_press["variant"]["fixedPath"] = False
        self.assert_horizontal_press_fails(
            family,
            "violates exercise rule machine-requires-fixed-path-and-type: "
            "variant.fixedPath must equal True",
        )

    def test_horizontal_non_machine_cannot_declare_a_machine_type(self) -> None:
        family = self.horizontal_press_copy()
        barbell_press = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"] == "barbell-bench-press"
        )
        barbell_press["variant"]["machineType"] = "smith"
        self.assert_horizontal_press_fails(
            family,
            "violates exercise rule non-machine-requires-free-path: "
            "variant.machineType must be absent",
        )

    def test_every_reviewed_dumbbell_press_has_external_rotator_stabilization(self) -> None:
        for family in (
            self.horizontal_press,
            self.incline_press,
            self.decline_press,
        ):
            for exercise in family["exercises"]:
                if exercise["equipment"] != "dumbbell":
                    continue
                with self.subTest(
                    family=family["id"],
                    exercise=exercise["catalogID"],
                ):
                    role_by_muscle = {
                        contribution["muscle"]: contribution["role"]
                        for contribution in exercise["involvement"]
                    }
                    self.assertEqual(
                        role_by_muscle.get("externalRotators"),
                        "stabilizer",
                    )

    def test_real_incline_press_family_is_diagonal_and_multi_plane(self) -> None:
        warnings = catalog_v2.validate_family(
            self.incline_press_copy(),
            self.foundation,
            "incline press",
        )
        self.assertEqual(warnings, [])
        self.assertEqual(self.incline_press["fixed"]["direction"], "diagonal")
        self.assertEqual(
            set(self.incline_press["fixed"]["planes"]),
            {"sagittal", "transverse"},
        )
        self.assertEqual(
            self.incline_press["movementSignature"]["planeBasisActions"],
            ["shoulder.horizontalAdduction", "shoulder.flexion"],
        )
        self.assertEqual(
            self.incline_press["movementSignature"]["forbiddenPrimeActions"],
            ["shoulder.extension"],
        )
        self.assertEqual(len(self.incline_press["exercises"]), 4)
        self.assertEqual(
            {
                exercise["variant"]["pressInclinationDegrees"]
                for exercise in self.incline_press["exercises"]
            },
            {30},
        )

    def test_incline_press_rejects_shoulder_extension(self) -> None:
        family = self.incline_press_copy()
        family["exercises"][0]["additionalPrimeActions"] = [
            {
                "action": "shoulder.extension",
                "condition": "fromFlexedPosition",
            }
        ]
        self.assert_incline_press_fails(
            family,
            "declares forbidden prime action shoulder.extension",
        )

    def test_real_decline_press_family_is_diagonal_but_transverse(self) -> None:
        warnings = catalog_v2.validate_family(
            self.decline_press_copy(),
            self.foundation,
            "decline press",
        )
        self.assertEqual(warnings, [])
        self.assertEqual(self.decline_press["fixed"]["direction"], "diagonal")
        self.assertEqual(self.decline_press["fixed"]["planes"], ["transverse"])
        self.assertEqual(
            self.decline_press["movementSignature"]["planeBasisActions"],
            ["shoulder.horizontalAdduction"],
        )
        self.assertEqual(
            self.decline_press["movementSignature"]["primeActions"],
            ["shoulder.horizontalAdduction", "elbow.extension"],
        )
        self.assertEqual(
            self.decline_press["movementSignature"]["forbiddenPrimeActions"],
            ["shoulder.extension"],
        )
        self.assertEqual(len(self.decline_press["exercises"]), 4)
        self.assertEqual(
            {
                exercise["variant"]["pressInclinationDegrees"]
                for exercise in self.decline_press["exercises"]
            },
            {-15},
        )

    def test_decline_press_rejects_shoulder_extension_as_a_variant_action(self) -> None:
        family = self.decline_press_copy()
        family["exercises"][0]["additionalPrimeActions"] = [
            {
                "action": "shoulder.extension",
                "condition": "fromFlexedPosition",
            }
        ]
        self.assert_decline_press_fails(
            family,
            "declares forbidden prime action shoulder.extension",
        )

    def test_family_cannot_both_declare_and_forbid_a_prime_action(self) -> None:
        family = self.decline_press_copy()
        family["movementSignature"]["primeActions"].append(
            {
                "action": "shoulder.extension",
                "condition": "fromFlexedPosition",
            }
        )
        self.assert_decline_press_fails(
            family,
            "both declares and forbids prime actions: shoulder.extension",
        )

    def test_decline_press_rejects_angles_outside_reviewed_band(self) -> None:
        for angle, message in ((-35, "is below -30"), (-5, "exceeds -10")):
            with self.subTest(angle=angle):
                family = self.decline_press_copy()
                family["exercises"][0]["variant"][
                    "pressInclinationDegrees"
                ] = angle
                self.assert_decline_press_fails(family, message)

    def test_decline_press_sternocostal_pec_cannot_be_demoted(self) -> None:
        family = self.decline_press_copy()
        sternocostal = next(
            contribution
            for contribution in family["exercises"][0]["involvement"]
            if contribution["muscle"] == "pectoralisMajorSternocostal"
        )
        sternocostal["role"] = "secondary"
        self.assert_decline_press_fails(
            family,
            "does not allow pectoralisMajorSternocostal as secondary",
        )

    def test_decline_press_clavicular_pec_cannot_be_promoted(self) -> None:
        family = self.decline_press_copy()
        clavicular = next(
            contribution
            for contribution in family["exercises"][0]["involvement"]
            if contribution["muscle"] == "pectoralisMajorClavicular"
        )
        clavicular["role"] = "primary"
        self.assert_decline_press_fails(
            family,
            "does not allow pectoralisMajorClavicular as primary",
        )

    def test_decline_machine_press_requires_a_fixed_path(self) -> None:
        family = self.decline_press_copy()
        smith_press = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"] == "decline-smith-machine-bench-press"
        )
        smith_press["variant"]["fixedPath"] = False
        self.assert_decline_press_fails(
            family,
            "violates exercise rule machine-requires-fixed-path-and-type: "
            "variant.fixedPath must equal True",
        )

    def test_incline_press_requires_both_shoulder_plane_components(self) -> None:
        family = self.incline_press_copy()
        family["movementSignature"]["planeBasisActions"] = [
            "shoulder.horizontalAdduction"
        ]
        self.assert_incline_press_fails(
            family,
            "planes sagittal, transverse conflict with plane-basis actions "
            "shoulder.horizontalAdduction \\(transverse\\)",
        )

    def test_diagonal_is_a_direction_and_never_an_anatomical_plane(self) -> None:
        self.assertIn("diagonal", catalog_v2.DIRECTIONS)
        self.assertNotIn("diagonal", catalog_v2.CARDINAL_PLANES)
        self.assertEqual(
            catalog_v2.CARDINAL_PLANES,
            {"sagittal", "frontal", "transverse"},
        )

    def test_family_cannot_declare_an_oblique_plane(self) -> None:
        family = self.incline_press_copy()
        family["fixed"]["planes"].append("oblique")
        self.assert_incline_press_fails(
            family,
            "fixed.planes contains unknown values: oblique",
        )

    def test_multi_plane_basis_cannot_mix_actions_from_different_joints(self) -> None:
        family = self.incline_press_copy()
        family["movementSignature"]["planeBasisActions"] = [
            "shoulder.horizontalAdduction",
            "elbow.extension",
        ]
        self.assert_incline_press_fails(
            family,
            "multi-plane basis actions must belong to the same joint region",
        )

    def test_multi_plane_basis_must_span_distinct_cardinal_planes(self) -> None:
        family = self.incline_press_copy()
        family["movementSignature"]["primeActions"].append(
            "shoulder.internalRotation"
        )
        family["movementSignature"]["planeBasisActions"] = [
            "shoulder.horizontalAdduction",
            "shoulder.internalRotation",
        ]
        self.assert_incline_press_fails(
            family,
            "each plane-basis action must represent a distinct cardinal plane",
        )

    def test_incline_press_rejects_angles_outside_chest_oriented_band(self) -> None:
        for angle, message in ((10, "is below 15"), (60, "exceeds 45")):
            with self.subTest(angle=angle):
                family = self.incline_press_copy()
                family["exercises"][0]["variant"][
                    "pressInclinationDegrees"
                ] = angle
                self.assert_incline_press_fails(family, message)

    def test_incline_press_clavicular_pec_cannot_be_demoted(self) -> None:
        family = self.incline_press_copy()
        clavicular = next(
            contribution
            for contribution in family["exercises"][0]["involvement"]
            if contribution["muscle"] == "pectoralisMajorClavicular"
        )
        clavicular["role"] = "secondary"
        self.assert_incline_press_fails(
            family,
            "does not allow pectoralisMajorClavicular as secondary",
        )

    def test_incline_press_sternocostal_pec_cannot_be_promoted(self) -> None:
        family = self.incline_press_copy()
        sternocostal = next(
            contribution
            for contribution in family["exercises"][0]["involvement"]
            if contribution["muscle"] == "pectoralisMajorSternocostal"
        )
        sternocostal["role"] = "primary"
        self.assert_incline_press_fails(
            family,
            "does not allow pectoralisMajorSternocostal as primary",
        )

    def test_incline_machine_press_requires_a_fixed_path(self) -> None:
        family = self.incline_press_copy()
        smith_press = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"] == "incline-smith-machine-bench-press"
        )
        smith_press["variant"]["fixedPath"] = False
        self.assert_incline_press_fails(
            family,
            "violates exercise rule machine-requires-fixed-path-and-type: "
            "variant.fixedPath must equal True",
        )

    def test_horizontal_press_clavicular_pec_cannot_be_promoted_to_primary(self) -> None:
        family = self.horizontal_press_copy()
        bench_press = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"] == "barbell-bench-press"
        )
        clavicular = next(
            contribution
            for contribution in bench_press["involvement"]
            if contribution["muscle"] == "pectoralisMajorClavicular"
        )
        clavicular["role"] = "primary"
        self.assert_horizontal_press_fails(
            family,
            "does not allow pectoralisMajorClavicular as primary",
        )

    def test_horizontal_press_sternocostal_pec_cannot_be_demoted(self) -> None:
        family = self.horizontal_press_copy()
        bench_press = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"] == "barbell-bench-press"
        )
        sternocostal = next(
            contribution
            for contribution in bench_press["involvement"]
            if contribution["muscle"] == "pectoralisMajorSternocostal"
        )
        sternocostal["role"] = "secondary"
        self.assert_horizontal_press_fails(
            family,
            "does not allow pectoralisMajorSternocostal as secondary",
        )

    def test_all_evidence_is_used_by_anatomy_or_a_family(self) -> None:
        catalog_v2.validate_evidence_coverage(
            self.foundation,
            [
                self.horizontal_press,
                self.incline_press,
                self.decline_press,
                self.vertical_press,
            ],
        )

    def test_real_family_set_has_no_cross_family_identity_collisions(self) -> None:
        catalog_v2.validate_family_set(
            [
                self.horizontal_press,
                self.incline_press,
                self.decline_press,
                self.vertical_press,
            ]
        )

    def test_bodyweight_press_must_obey_closed_chain_rule(self) -> None:
        family = self.horizontal_press_copy()
        push_up = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"] == "push-up"
        )
        push_up["variant"]["kineticChain"] = "open"
        self.assert_horizontal_press_fails(
            family,
            "violates exercise rule bodyweight-closed-chain: "
            "variant.kineticChain must equal 'closed'",
        )

    def test_floor_press_must_remain_floor_limited(self) -> None:
        family = self.horizontal_press_copy()
        floor_press = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"] == "barbell-floor-press"
        )
        floor_press["variant"]["rangeOfMotion"] = "full"
        self.assert_horizontal_press_fails(
            family,
            "violates exercise rule floor-support-limits-range: "
            "variant.rangeOfMotion must equal 'floorLimited'",
        )

    def test_family_set_rejects_cross_family_catalog_id_collision(self) -> None:
        duplicate_family = self.horizontal_press_copy()
        duplicate_family["id"] = "another-horizontal-family"
        with self.assertRaisesRegex(
            catalog_v2.ValidationFailure,
            "family set duplicates catalogID barbell-bench-press",
        ):
            catalog_v2.validate_family_set(
                [self.horizontal_press, duplicate_family]
            )

    def test_family_plane_must_match_its_basis_action(self) -> None:
        family = self.family_copy()
        family["fixed"]["planes"] = ["sagittal"]
        self.assert_family_fails(
            family,
            "planes sagittal conflict with plane-basis actions "
            "shoulder.horizontalAdduction \\(transverse\\)",
        )

    def test_plane_basis_must_be_a_prime_action(self) -> None:
        family = self.family_copy()
        family["movementSignature"]["planeBasisActions"] = ["shoulder.flexion"]
        self.assert_family_fails(
            family,
            "plane-basis action shoulder.flexion must also be a prime action",
        )

    def test_foundation_digest_is_deterministic(self) -> None:
        first = catalog_v2.canonical_foundation_digest(self.foundation)
        second = catalog_v2.canonical_foundation_digest(
            catalog_v2.validate_foundation()
        )
        self.assertEqual(first, second)
        self.assertEqual(len(first), 64)

    def test_family_schema_cannot_introduce_a_fourth_plane(self) -> None:
        schema = copy.deepcopy(self.foundation.family_schema)
        planes = schema["$defs"]["fixedClassification"]["properties"]["planes"]
        planes["items"]["enum"].append("oblique")
        with self.assertRaisesRegex(
            catalog_v2.ValidationFailure,
            "movement-plane enum must contain exactly the three cardinal planes",
        ):
            catalog_v2.validate_family_schema(schema)

    def test_duplicate_mesh_ownership_is_rejected(self) -> None:
        taxonomy = copy.deepcopy(self.foundation.taxonomy)
        by_id = {muscle["id"]: muscle for muscle in taxonomy["muscles"]}
        by_id["serratus"]["meshBaseNames"] = ["Latissimus_Dorsi"]
        with self.assertRaisesRegex(
            catalog_v2.ValidationFailure,
            "owned by both serratus and lats",
        ):
            catalog_v2.validate_taxonomy(taxonomy)

    def test_unknown_evidence_reference_is_rejected(self) -> None:
        actions = copy.deepcopy(self.foundation.joint_actions)
        actions["muscleProfiles"][0]["evidenceRefs"] = ["invented-source"]
        with self.assertRaisesRegex(
            catalog_v2.ValidationFailure,
            "references unknown evidence",
        ):
            catalog_v2.validate_joint_actions(
                actions,
                set(self.foundation.muscle_by_id),
                self.foundation.evidence_ids,
            )

    def test_unknown_action_condition_is_rejected(self) -> None:
        actions = copy.deepcopy(self.foundation.joint_actions)
        sternocostal = next(
            profile
            for profile in actions["muscleProfiles"]
            if profile["muscleID"] == "pectoralisMajorSternocostal"
        )
        sternocostal["produces"][0]["condition"] = "inventedPosition"
        with self.assertRaisesRegex(
            catalog_v2.ValidationFailure,
            "references unknown action condition inventedPosition",
        ):
            catalog_v2.validate_joint_actions(
                actions,
                set(self.foundation.muscle_by_id),
                self.foundation.evidence_ids,
            )

    def test_conditional_capability_cannot_satisfy_unrestricted_action(self) -> None:
        family = self.sternocostal_extension_family("shoulder.extension")
        self.assert_family_fails(
            family,
            "no primary/secondary muscle capable of shoulder.extension",
        )

    def test_matching_action_condition_satisfies_family(self) -> None:
        family = self.sternocostal_extension_family(
            {
                "action": "shoulder.extension",
                "condition": "fromFlexedPosition",
            }
        )
        warnings = catalog_v2.validate_family(
            family,
            self.foundation,
            "conditioned extension fixture",
        )
        self.assertEqual(warnings, [])

    def test_family_cannot_reference_unknown_action_condition(self) -> None:
        family = self.sternocostal_extension_family(
            {
                "action": "shoulder.extension",
                "condition": "inventedPosition",
            }
        )
        self.assert_family_fails(
            family,
            "references unknown action condition inventedPosition",
        )

    def test_unknown_muscle_is_rejected(self) -> None:
        family = self.family_copy()
        family["exercises"][0]["involvement"][0]["muscle"] = "inventedMuscle"
        self.assert_family_fails(family, "references unknown muscle inventedMuscle")

    def test_numeric_muscle_involvement_is_rejected(self) -> None:
        family = self.family_copy()
        family["exercises"][0]["involvement"][0]["weight"] = 0.9
        self.assert_family_fails(family, "unknown keys: weight")

    def test_family_anchor_removal_is_rejected(self) -> None:
        family = self.family_copy()
        family["groupPolicy"]["allowed"].append("shoulders")
        family["musclePolicy"]["allowedByRole"]["primary"].append(
            "deltoidAnterior"
        )
        family["exercises"][0]["groupOverride"] = "shoulders"
        family["exercises"][0]["involvement"] = [
            contribution
            for contribution in family["exercises"][0]["involvement"]
            if contribution["muscle"]
            not in {"pectoralisMajorClavicular", "pectoralisMajorSternocostal"}
        ]
        for contribution in family["exercises"][0]["involvement"]:
            if contribution["muscle"] == "deltoidAnterior":
                contribution["role"] = "primary"
        self.assert_family_fails(family, "fails muscle requirement 0")

    def test_uncovered_prime_joint_action_is_rejected(self) -> None:
        family = self.family_copy()
        family["exercises"][0]["involvement"] = [
            contribution
            for contribution in family["exercises"][0]["involvement"]
            if contribution["muscle"] != "triceps"
        ]
        self.assert_family_fails(
            family,
            "no primary/secondary muscle capable of elbow.extension",
        )

    def test_secondary_must_produce_a_declared_prime_action(self) -> None:
        family = self.family_copy()
        family["musclePolicy"]["allowedByRole"]["secondary"].append("hamstrings")
        family["exercises"][0]["involvement"].append(
            {"muscle": "hamstrings", "role": "secondary"}
        )
        self.assert_family_fails(
            family,
            "secondary muscle hamstrings cannot produce any declared prime action",
        )

    def test_primary_must_produce_a_declared_prime_action(self) -> None:
        family = self.family_copy()
        family["groupPolicy"]["allowed"].append("back")
        family["musclePolicy"]["allowedByRole"]["primary"].append("lats")
        exercise = family["exercises"][0]
        exercise["groupOverride"] = "back"
        exercise["involvement"][0]["muscle"] = "lats"
        self.assert_family_fails(
            family,
            "primary muscle lats cannot produce any declared prime action",
        )

    def test_uncovered_stability_demand_is_rejected(self) -> None:
        family = self.family_copy()
        family["exercises"][0]["involvement"] = [
            contribution
            for contribution in family["exercises"][0]["involvement"]
            if contribution["muscle"] != "serratus"
        ]
        self.assert_family_fails(
            family,
            "no assigned muscle capable of stabilizing scapula",
        )

    def test_stabilizer_must_match_a_declared_stability_demand(self) -> None:
        family = self.family_copy()
        family["musclePolicy"]["allowedByRole"]["stabilizer"].append("calves")
        family["exercises"][0]["involvement"].append(
            {"muscle": "calves", "role": "stabilizer"}
        )
        self.assert_family_fails(
            family,
            "stabilizer muscle calves cannot stabilize any declared demand",
        )

    def test_undeclared_variant_axis_is_rejected(self) -> None:
        family = self.family_copy()
        family["exercises"][0]["variant"]["inventedAxis"] = "invented"
        self.assert_family_fails(family, "contains undeclared axes: inventedAxis")

    def test_programming_recommendation_is_a_warning_not_membership_failure(self) -> None:
        family = self.family_copy()
        family["exercises"][0]["reps"] = 30
        warnings = catalog_v2.validate_family(
            family,
            self.foundation,
            "recommendation fixture",
        )
        self.assertEqual(
            warnings,
            ["fixture-barbell-horizontal-press: reps 30 is outside recommended 5...15"],
        )


if __name__ == "__main__":
    unittest.main()
