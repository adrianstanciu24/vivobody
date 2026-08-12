#!/usr/bin/env python3
#
#  test_catalog_v2.py
#  vivobody
#
#  Mutation-oriented tests for the isolated family-first catalog foundation.
#  They prove the validator rejects unknown muscles, invalid mesh ownership,
#  anatomically incapable movers, uncovered stability demands, undeclared
#  variant axes, forbidden prime actions, mismatched position conditions,
#  conditional muscle-role, allowed-set and variant-specific stability
#  requirements, and numeric involvement weights while keeping recommendations
#  non-fatal.
#

from __future__ import annotations

import copy
import re
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
        cls.vertical_pull = catalog_v2.load_json(
            catalog_v2.FAMILIES_ROOT / "vertical-pull.json"
        )
        cls.shoulder_extension_row = catalog_v2.load_json(
            catalog_v2.FAMILIES_ROOT / "shoulder-extension-row.json"
        )
        cls.shoulder_horizontal_abduction_row = catalog_v2.load_json(
            catalog_v2.FAMILIES_ROOT
            / "shoulder-horizontal-abduction-row.json"
        )
        cls.real_families = [
            catalog_v2.load_json(path)
            for path in catalog_v2.discovered_family_paths()
        ]
        batch1_ids = {
            "shoulder-extension-isolation",
            "chest-fly",
            "reverse-fly",
            "shoulder-flexion-raise",
            "shoulder-abduction-raise",
            "shoulder-external-rotation",
            "shoulder-internal-rotation",
        }
        cls.batch1_families = {
            family["id"]: family
            for family in cls.real_families
            if family["id"] in batch1_ids
        }

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

    def vertical_pull_copy(self) -> dict:
        return copy.deepcopy(self.vertical_pull)

    def shoulder_extension_row_copy(self) -> dict:
        return copy.deepcopy(self.shoulder_extension_row)

    def shoulder_horizontal_abduction_row_copy(self) -> dict:
        return copy.deepcopy(self.shoulder_horizontal_abduction_row)

    def batch1_family_copy(self, family_id: str) -> dict:
        return copy.deepcopy(self.batch1_families[family_id])

    def assert_batch1_family_fails(
        self,
        family: dict,
        message: str,
    ) -> None:
        with self.assertRaisesRegex(catalog_v2.ValidationFailure, message):
            catalog_v2.validate_family(
                family,
                self.foundation,
                f"mutated {family['id']}",
            )

    def rule_matches_exercise(self, rule: dict, exercise: dict) -> bool:
        predicate = rule["when"]
        actual = catalog_v2.exercise_rule_field(exercise, predicate["field"])
        if actual is catalog_v2.MISSING:
            return False
        if predicate["operator"] == "equals":
            return actual == predicate["value"]
        return actual != predicate["value"]

    def set_rule_field(self, exercise: dict, field_path: str, value: object) -> None:
        if "." not in field_path:
            exercise[field_path] = value
            return
        _, axis_id = field_path.split(".", 1)
        exercise["variant"][axis_id] = value

    def delete_rule_field(self, exercise: dict, field_path: str) -> None:
        if "." not in field_path:
            exercise.pop(field_path, None)
            return
        _, axis_id = field_path.split(".", 1)
        exercise["variant"].pop(axis_id, None)

    def alternate_rule_value(
        self,
        family: dict,
        field_path: str,
        rejected_values: set[object],
    ) -> tuple[bool, object | None]:
        if "." not in field_path:
            allowed_key_by_field = {
                "equipment": "equipment",
                "laterality": "lateralities",
                "modality": "modalities",
                "trackingMode": "trackingModes",
                "loadMode": "loadModes",
            }
            allowed_key = allowed_key_by_field[field_path]
            alternatives = [
                value
                for value in family["allowed"][allowed_key]
                if value not in rejected_values
            ]
            return (bool(alternatives), alternatives[0] if alternatives else None)

        _, axis_id = field_path.split(".", 1)
        axis = next(
            axis for axis in family["variantAxes"] if axis["id"] == axis_id
        )
        if axis["valueType"] == "enum":
            alternatives = [
                value
                for value in axis["allowedValues"]
                if value not in rejected_values
            ]
            return (bool(alternatives), alternatives[0] if alternatives else None)
        if axis["valueType"] == "boolean":
            alternatives = [
                value for value in (False, True) if value not in rejected_values
            ]
            return (bool(alternatives), alternatives[0] if alternatives else None)
        if axis["valueType"] == "number":
            alternatives = [
                value
                for value in (axis.get("minimum"), axis.get("maximum"))
                if value is not None and value not in rejected_values
            ]
            return (bool(alternatives), alternatives[0] if alternatives else None)
        return (False, None)

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

    def conditional_muscle_rule(self, requirements: list[dict]) -> dict:
        return {
            "id": "standing-requires-trunk-muscle",
            "description": (
                "Standing variants require one reviewed trunk muscle without "
                "forcing one exact assignment."
            ),
            "when": {
                "field": "variant.support",
                "operator": "equals",
                "value": "standing",
            },
            "then": [],
            "requirePresent": [],
            "requireAbsent": [],
            "requireMuscleRequirements": requirements,
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

    def assert_vertical_pull_fails(self, family: dict, message: str) -> None:
        with self.assertRaisesRegex(catalog_v2.ValidationFailure, message):
            catalog_v2.validate_family(
                family,
                self.foundation,
                "mutated vertical pull",
            )

    def assert_shoulder_extension_row_fails(
        self,
        family: dict,
        message: str,
    ) -> None:
        with self.assertRaisesRegex(catalog_v2.ValidationFailure, message):
            catalog_v2.validate_family(
                family,
                self.foundation,
                "mutated shoulder extension row",
            )

    def assert_shoulder_horizontal_abduction_row_fails(
        self,
        family: dict,
        message: str,
    ) -> None:
        with self.assertRaisesRegex(catalog_v2.ValidationFailure, message):
            catalog_v2.validate_family(
                family,
                self.foundation,
                "mutated shoulder horizontal abduction row",
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

    def test_positive_weight_seed_requires_metric_seed(self) -> None:
        family = self.family_copy()
        family["exercises"][0].pop("defaultWeightKg")
        self.assert_family_fails(
            family,
            "positive defaultWeight requires defaultWeightKg",
        )

    def test_positive_assistance_seed_requires_metric_seed(self) -> None:
        family = self.vertical_pull_copy()
        assisted_pull_up = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"] == "assisted-pull-up-machine"
        )
        assisted_pull_up.pop("defaultWeightKg")
        self.assert_vertical_pull_fails(
            family,
            "positive defaultWeight requires defaultWeightKg",
        )

    def test_zero_weight_seed_does_not_require_metric_seed(self) -> None:
        family = self.family_copy()
        exercise = family["exercises"][0]
        exercise["defaultWeight"] = 0
        exercise.pop("defaultWeightKg")
        warnings = catalog_v2.validate_family(
            family,
            self.foundation,
            "zero-weight external fixture",
        )
        self.assertEqual(warnings, [])

    def test_batch1_external_loads_use_reviewed_metric_seed_detents(self) -> None:
        expected = {
            "flat-dumbbell-fly": 5,
            "prone-dumbbell-reverse-fly": 2.5,
            "neutral-grip-machine-reverse-fly": 15,
            "pronated-grip-machine-reverse-fly": 15,
            "barbell-pullover": 10,
            "shoulder-width-straight-arm-cable-pulldown": 15,
            "wide-grip-straight-arm-cable-pulldown": 15,
        }
        actual = {
            exercise["catalogID"]: exercise["defaultWeightKg"]
            for family_id in (
                "chest-fly",
                "reverse-fly",
                "shoulder-extension-isolation",
            )
            for exercise in self.batch1_families[family_id]["exercises"]
            if exercise["loadMode"] == "external"
            and exercise["defaultWeight"] > 0
        }
        self.assertEqual(actual, expected)

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

    def test_family_schema_declares_conditional_muscle_requirement_shape(
        self,
    ) -> None:
        property_schema = self.foundation.family_schema["$defs"]["exerciseRule"][
            "properties"
        ]["requireMuscleRequirements"]
        self.assertEqual(
            property_schema,
            {
                "type": "array",
                "uniqueItems": True,
                "items": {"$ref": "#/$defs/muscleRequirement"},
            },
        )

    def test_conditional_muscle_requirement_rejects_missing_any_of_set(
        self,
    ) -> None:
        family = self.family_copy()
        family["musclePolicy"]["allowedByRole"]["stabilizer"].extend(
            ["abs", "obliques", "lowerBack"]
        )
        family["exerciseRules"] = [
            self.conditional_muscle_rule(
                [
                    {
                        "anyOf": ["abs", "obliques", "lowerBack"],
                        "minimumRole": "stabilizer",
                    }
                ]
            )
        ]
        family["exercises"][0]["variant"]["support"] = "standing"
        self.assert_family_fails(
            family,
            "violates exercise rule standing-requires-trunk-muscle: "
            r"one of \['abs', 'obliques', 'lowerBack'\] must be assigned as "
            "stabilizer or higher",
        )

    def test_conditional_muscle_requirement_accepts_any_reviewed_candidate(
        self,
    ) -> None:
        family = self.family_copy()
        family["musclePolicy"]["allowedByRole"]["stabilizer"].extend(
            ["abs", "obliques", "lowerBack"]
        )
        family["exerciseRules"] = [
            self.conditional_muscle_rule(
                [
                    {
                        "anyOf": ["abs", "obliques", "lowerBack"],
                        "minimumRole": "stabilizer",
                    }
                ]
            )
        ]
        exercise = family["exercises"][0]
        exercise["variant"]["support"] = "standing"
        exercise["additionalStabilityDemands"] = ["spine"]
        exercise["involvement"].append(
            {"muscle": "obliques", "role": "stabilizer"}
        )
        self.assertEqual(
            catalog_v2.validate_family(
                family,
                self.foundation,
                "conditional-muscle fixture",
            ),
            [],
        )

    def test_conditional_muscle_requirement_rejects_unknown_muscle(self) -> None:
        family = self.family_copy()
        family["exerciseRules"] = [
            self.conditional_muscle_rule(
                [
                    {
                        "anyOf": ["inventedMuscle"],
                        "minimumRole": "stabilizer",
                    }
                ]
            )
        ]
        self.assert_family_fails(
            family,
            r"requireMuscleRequirements\[0\].anyOf references unknown muscles: "
            "inventedMuscle",
        )

    def test_conditional_muscle_requirement_enforces_minimum_role(self) -> None:
        family = self.family_copy()
        family["exerciseRules"] = [
            self.conditional_muscle_rule(
                [
                    {
                        "anyOf": ["serratus"],
                        "minimumRole": "secondary",
                    }
                ]
            )
        ]
        family["exercises"][0]["variant"]["support"] = "standing"
        self.assert_family_fails(
            family,
            "violates exercise rule standing-requires-trunk-muscle: "
            r"one of \['serratus'\] must be assigned as secondary or higher",
        )

    def test_conditional_muscle_requirement_rejects_equivalent_groups(
        self,
    ) -> None:
        family = self.family_copy()
        family["musclePolicy"]["allowedByRole"]["stabilizer"].extend(
            ["abs", "obliques"]
        )
        family["exerciseRules"] = [
            self.conditional_muscle_rule(
                [
                    {
                        "anyOf": ["abs", "obliques"],
                        "minimumRole": "stabilizer",
                    },
                    {
                        "anyOf": ["obliques", "abs"],
                        "minimumRole": "stabilizer",
                    },
                ]
            )
        ]
        self.assert_family_fails(
            family,
            "requireMuscleRequirements contains equivalent muscle requirements",
        )

    def test_rule_assertion_can_require_one_of_several_values(self) -> None:
        family = self.family_copy()
        family["exerciseRules"] = [
            {
                "id": "support-must-be-bench-or-floor",
                "description": "The fixture admits two reviewed support values.",
                "when": {
                    "field": "equipment",
                    "operator": "equals",
                    "value": "barbell",
                },
                "then": [
                    {
                        "field": "variant.support",
                        "allowedValues": ["bench", "floor"],
                    }
                ],
                "requirePresent": [],
                "requireAbsent": [],
            }
        ]
        self.assertEqual(
            catalog_v2.validate_family(
                family,
                self.foundation,
                "allowed-set fixture",
            ),
            [],
        )

        family["exercises"][0]["variant"]["support"] = "standing"
        self.assert_family_fails(
            family,
            "violates exercise rule support-must-be-bench-or-floor: "
            r"variant.support must be one of \['bench', 'floor'\]",
        )

    def test_rule_assertion_requires_exactly_one_expected_value_shape(self) -> None:
        for assertion in (
            {"field": "variant.support"},
            {
                "field": "variant.support",
                "value": "upright",
                "allowedValues": ["upright"],
            },
        ):
            with self.subTest(assertion=assertion):
                family = self.family_copy()
                family["exerciseRules"] = [
                    {
                        "id": "invalid-assertion-shape",
                        "description": "The assertion shape is deliberately invalid.",
                        "when": {
                            "field": "equipment",
                            "operator": "equals",
                            "value": "barbell",
                        },
                        "then": [assertion],
                        "requirePresent": [],
                        "requireAbsent": [],
                    }
                ]
                self.assert_family_fails(
                    family,
                    "must declare exactly one of value or allowedValues",
                )

    def test_family_schema_declares_allowed_set_rule_assertions(self) -> None:
        assertion_schema = self.foundation.family_schema["$defs"]["ruleAssertion"]
        self.assertEqual(assertion_schema["required"], ["field"])
        self.assertEqual(
            assertion_schema["properties"]["allowedValues"],
            {
                "type": "array",
                "minItems": 1,
                "uniqueItems": True,
                "items": {"$ref": "#/$defs/variantValue"},
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

    def test_real_vertical_pull_family_is_multi_plane_and_strict(self) -> None:
        warnings = catalog_v2.validate_family(
            self.vertical_pull_copy(),
            self.foundation,
            "vertical pull",
        )
        self.assertEqual(warnings, [])
        self.assertEqual(self.vertical_pull["fixed"]["direction"], "vertical")
        self.assertEqual(
            set(self.vertical_pull["fixed"]["planes"]),
            {"sagittal", "frontal"},
        )
        self.assertEqual(
            self.vertical_pull["movementSignature"]["planeBasisActions"],
            ["shoulder.extension", "shoulder.adduction"],
        )
        self.assertIn(
            {
                "action": "shoulder.extension",
                "condition": "fromFlexedPosition",
            },
            self.vertical_pull["movementSignature"]["primeActions"],
        )
        self.assertIn(
            "scapula.retraction",
            self.vertical_pull["movementSignature"]["primeActions"],
        )
        self.assertEqual(
            self.foundation.plane_by_action["scapula.retraction"],
            "transverse",
        )
        self.assertNotIn("transverse", self.vertical_pull["fixed"]["planes"])
        axis_ids = {
            axis["id"] for axis in self.vertical_pull["variantAxes"]
        }
        self.assertIn("pathConstraint", axis_ids)
        self.assertNotIn("fixedPath", axis_ids)
        self.assertEqual(
            [
                exercise["catalogID"]
                for exercise in self.vertical_pull["exercises"]
            ],
            [
                "pull-up",
                "chin-up",
                "neutral-grip-pull-up",
                "wide-grip-pull-up",
                "assisted-pull-up-machine",
                "assisted-chin-up-machine",
                "cable-lat-pulldown",
                "close-grip-neutral-lat-pulldown",
                "underhand-lat-pulldown",
                "wide-grip-lat-pulldown",
                "single-arm-cable-lat-pulldown",
                "machine-lat-pulldown",
                "single-arm-machine-lat-pulldown",
            ],
        )

    def test_vertical_pull_roster_is_the_reviewed_coverage_matrix(self) -> None:
        actual = {}
        for exercise in self.vertical_pull["exercises"]:
            variant = exercise["variant"]
            actual[exercise["catalogID"]] = (
                exercise["equipment"],
                exercise["laterality"],
                exercise["loadMode"],
                exercise["bodyweightFraction"],
                variant["kineticChain"],
                variant["bodyPosition"],
                variant["lowerBodySupport"],
                variant["gripOrientation"],
                variant.get("relativeGripWidth"),
                variant["pathConstraint"],
                variant.get("machineType"),
                tuple(exercise["additionalStabilityDemands"]),
            )

        self.assertEqual(
            actual,
            {
                "pull-up": (
                    "bodyweight", "bilateral", "bodyweightAdded", 1,
                    "closed", "suspended", "none", "pronated",
                    "shoulderWidth", "free", None, ("pelvis",),
                ),
                "chin-up": (
                    "bodyweight", "bilateral", "bodyweightAdded", 1,
                    "closed", "suspended", "none", "supinated",
                    "shoulderWidth", "free", None, ("pelvis",),
                ),
                "neutral-grip-pull-up": (
                    "bodyweight", "bilateral", "bodyweightAdded", 1,
                    "closed", "suspended", "none", "neutral",
                    "shoulderWidth", "free", None, ("pelvis",),
                ),
                "wide-grip-pull-up": (
                    "bodyweight", "bilateral", "bodyweightAdded", 1,
                    "closed", "suspended", "none", "pronated", "wide",
                    "free", None, ("pelvis",),
                ),
                "assisted-pull-up-machine": (
                    "machine", "bilateral", "assistanceSubtracted", 1,
                    "closed", "suspended", "assistancePlatform", "pronated",
                    "shoulderWidth", "assistancePlatformGuided",
                    "assistedPullUp", ("pelvis",),
                ),
                "assisted-chin-up-machine": (
                    "machine", "bilateral", "assistanceSubtracted", 1,
                    "closed", "suspended", "assistancePlatform", "supinated",
                    "shoulderWidth", "assistancePlatformGuided",
                    "assistedPullUp", ("pelvis",),
                ),
                "cable-lat-pulldown": (
                    "cable", "bilateral", "external", 0, "open", "seated",
                    "thighPad", "pronated", "medium", "free", None, (),
                ),
                "close-grip-neutral-lat-pulldown": (
                    "cable", "bilateral", "external", 0, "open", "seated",
                    "thighPad", "neutral", "narrow", "free", None,
                    (),
                ),
                "underhand-lat-pulldown": (
                    "cable", "bilateral", "external", 0, "open", "seated",
                    "thighPad", "supinated", "shoulderWidth", "free", None,
                    (),
                ),
                "wide-grip-lat-pulldown": (
                    "cable", "bilateral", "external", 0, "open", "seated",
                    "thighPad", "pronated", "wide", "free", None, (),
                ),
                "single-arm-cable-lat-pulldown": (
                    "cable", "unilateral", "external", 0, "open", "seated",
                    "thighPad", "neutral", None, "free", None,
                    ("pelvis",),
                ),
                "machine-lat-pulldown": (
                    "machine", "bilateral", "external", 0, "open", "seated",
                    "thighPad", "neutral", "medium", "leverGuided",
                    "leverPulldown", (),
                ),
                "single-arm-machine-lat-pulldown": (
                    "machine", "unilateral", "external", 0, "open", "seated",
                    "thighPad", "neutral", None, "leverGuided",
                    "leverPulldown", ("pelvis",),
                ),
            },
        )

    def test_vertical_pull_roster_covers_every_admitted_axis_value(self) -> None:
        exercises = self.vertical_pull["exercises"]
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
                    set(self.vertical_pull["allowed"][allowed_key]),
                )

        for axis in self.vertical_pull["variantAxes"]:
            observed = {
                exercise["variant"][axis["id"]]
                for exercise in exercises
                if axis["id"] in exercise["variant"]
            }
            with self.subTest(axis=axis["id"]):
                self.assertEqual(observed, set(axis["allowedValues"]))

    def test_every_vertical_pull_rule_matches_a_real_roster_branch(self) -> None:
        exercises = self.vertical_pull["exercises"]

        def field_value(exercise: dict, path: str):
            if path.startswith("variant."):
                return exercise["variant"].get(path.removeprefix("variant."))
            return exercise.get(path)

        for rule in self.vertical_pull["exerciseRules"]:
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

    def test_vertical_pull_requires_the_reviewed_role_contract(self) -> None:
        retractors = {"trapeziusMiddle", "trapeziusLower", "rhomboids"}
        trunk_stabilizers = {"abs", "obliques", "lowerBack"}
        for exercise in self.vertical_pull["exercises"]:
            roles = {
                assignment["muscle"]: assignment["role"]
                for assignment in exercise["involvement"]
            }
            with self.subTest(exercise=exercise["catalogID"]):
                self.assertEqual(roles["lats"], "primary")
                self.assertEqual(roles["teresMajor"], "secondary")
                self.assertEqual(roles["biceps"], "secondary")
                self.assertTrue(
                    any(roles.get(muscle) == "secondary" for muscle in retractors)
                )
                self.assertEqual(roles["externalRotators"], "stabilizer")
                self.assertEqual(roles["forearms"], "stabilizer")
                self.assertTrue(
                    any(
                        roles.get(muscle) == "stabilizer"
                        for muscle in trunk_stabilizers
                    )
                )

    def test_vertical_pull_requires_full_bodyweight_fraction(self) -> None:
        cases = (
            (
                "pull-up",
                "bodyweight-is-strict-closed-chain",
            ),
            (
                "assisted-pull-up-machine",
                "assisted-pullup-is-guided-subtractive",
            ),
        )
        for catalog_id, rule_id in cases:
            with self.subTest(exercise=catalog_id):
                family = self.vertical_pull_copy()
                exercise = next(
                    exercise
                    for exercise in family["exercises"]
                    if exercise["catalogID"] == catalog_id
                )
                exercise["bodyweightFraction"] = 0.8
                self.assert_vertical_pull_fails(
                    family,
                    f"violates exercise rule {rule_id}: "
                    "bodyweightFraction must equal 1",
                )

    def test_vertical_pull_rejects_one_arm_bodyweight_pullup(self) -> None:
        family = self.vertical_pull_copy()
        pull_up = family["exercises"][0]
        pull_up["laterality"] = "unilateral"
        pull_up["variant"].pop("relativeGripWidth")
        self.assert_vertical_pull_fails(
            family,
            "violates exercise rule bodyweight-is-strict-closed-chain: "
            "laterality must equal 'bilateral'",
        )

    def test_vertical_pull_machine_type_is_explicitly_scoped(self) -> None:
        family = self.vertical_pull_copy()
        assisted = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"] == "assisted-pull-up-machine"
        )
        assisted["variant"].pop("machineType")
        self.assert_vertical_pull_fails(
            family,
            "violates exercise rule machine-requires-type: "
            "variant.machineType must be present",
        )

        family = self.vertical_pull_copy()
        cable = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"] == "cable-lat-pulldown"
        )
        cable["variant"]["machineType"] = "leverPulldown"
        self.assert_vertical_pull_fails(
            family,
            "violates exercise rule non-machine-omits-machine-type: "
            "variant.machineType must be absent",
        )

    def test_vertical_pull_path_constraints_cannot_be_interchanged(self) -> None:
        cases = (
            (
                "cable-lat-pulldown",
                "leverGuided",
                "cable-is-seated-free-path",
                "free",
            ),
            (
                "machine-lat-pulldown",
                "free",
                "lever-pulldown-is-seated-guided-external",
                "leverGuided",
            ),
            (
                "assisted-pull-up-machine",
                "free",
                "assisted-pullup-is-guided-subtractive",
                "assistancePlatformGuided",
            ),
        )
        for catalog_id, invalid_path, rule_id, expected_path in cases:
            with self.subTest(exercise=catalog_id):
                family = self.vertical_pull_copy()
                exercise = next(
                    exercise
                    for exercise in family["exercises"]
                    if exercise["catalogID"] == catalog_id
                )
                exercise["variant"]["pathConstraint"] = invalid_path
                self.assert_vertical_pull_fails(
                    family,
                    f"violates exercise rule {rule_id}: "
                    f"variant.pathConstraint must equal '{expected_path}'",
                )

    def test_vertical_pull_grip_width_tracks_laterality(self) -> None:
        family = self.vertical_pull_copy()
        bilateral = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"] == "cable-lat-pulldown"
        )
        bilateral["variant"].pop("relativeGripWidth")
        self.assert_vertical_pull_fails(
            family,
            "violates exercise rule bilateral-requires-grip-width: "
            "variant.relativeGripWidth must be present",
        )

        family = self.vertical_pull_copy()
        unilateral = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"] == "single-arm-cable-lat-pulldown"
        )
        unilateral["variant"]["relativeGripWidth"] = "shoulderWidth"
        self.assert_vertical_pull_fails(
            family,
            "violates exercise rule unilateral-is-supported-cable-or-lever: "
            "variant.relativeGripWidth must be absent",
        )

    def test_unilateral_vertical_pull_requires_pelvic_control(self) -> None:
        family = self.vertical_pull_copy()
        unilateral = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"] == "single-arm-cable-lat-pulldown"
        )
        unilateral["additionalStabilityDemands"] = []
        self.assert_vertical_pull_fails(
            family,
            "violates exercise rule unilateral-is-supported-cable-or-lever: "
            "pelvis must be declared in additionalStabilityDemands",
        )

    def test_suspended_vertical_pull_requires_pelvic_control(self) -> None:
        family = self.vertical_pull_copy()
        assisted = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"] == "assisted-pull-up-machine"
        )
        assisted["additionalStabilityDemands"] = []
        self.assert_vertical_pull_fails(
            family,
            "violates exercise rule suspended-requires-pelvic-control: "
            "pelvis must be declared in additionalStabilityDemands",
        )

    def test_vertical_pull_rejects_propulsion_and_opposing_prime_actions(
        self,
    ) -> None:
        for action in (
            "shoulder.flexion",
            "elbow.extension",
            "spine.rotation",
            "hip.flexion",
            "hip.extension",
            "knee.flexion",
        ):
            with self.subTest(action=action):
                family = self.vertical_pull_copy()
                family["exercises"][0]["additionalPrimeActions"] = [action]
                self.assert_vertical_pull_fails(
                    family,
                    f"declares forbidden prime action {action}",
                )

    def test_vertical_pull_evidence_discloses_mechanics_derived_branches(
        self,
    ) -> None:
        source_by_id = {
            source["id"]: source for source in self.foundation.evidence["sources"]
        }
        self.assertIn(
            "no unilateral condition was tested",
            source_by_id["buonsenso-2025-lat-pulldown-grips"]["scope"],
        )
        exercise_by_id = {
            exercise["catalogID"]: exercise
            for exercise in self.vertical_pull["exercises"]
        }
        for catalog_id in (
            "single-arm-cable-lat-pulldown",
            "single-arm-machine-lat-pulldown",
        ):
            self.assertIn(
                "buonsenso-2025-lat-pulldown-grips",
                exercise_by_id[catalog_id]["evidenceRefs"],
            )
        self.assertEqual(
            set(exercise_by_id["assisted-chin-up-machine"]["evidenceRefs"]),
            {"hewit-2018-pullup-alternatives", "youdas-2010-pullup-chinup"},
        )

    def test_real_shoulder_extension_row_family_is_strict(self) -> None:
        warnings = catalog_v2.validate_family(
            self.shoulder_extension_row_copy(),
            self.foundation,
            "shoulder extension row",
        )
        self.assertEqual(warnings, [])
        self.assertEqual(
            self.shoulder_extension_row["fixed"],
            {
                "mechanic": "compound",
                "pattern": "pull",
                "direction": "horizontal",
                "planes": ["sagittal"],
            },
        )
        self.assertEqual(
            self.shoulder_extension_row["movementSignature"][
                "planeBasisActions"
            ],
            ["shoulder.extension"],
        )
        self.assertIn(
            {
                "action": "shoulder.extension",
                "condition": "fromFlexedPosition",
            },
            self.shoulder_extension_row["movementSignature"]["primeActions"],
        )
        self.assertIn(
            "scapula.retraction",
            self.shoulder_extension_row["movementSignature"]["primeActions"],
        )
        self.assertEqual(
            self.foundation.plane_by_action["scapula.retraction"],
            "transverse",
        )
        self.assertNotIn(
            "transverse",
            self.shoulder_extension_row["fixed"]["planes"],
        )
        self.assertIn(
            "Wide or deliberately flared horizontal-abduction rows",
            self.shoulder_extension_row["definition"],
        )
        self.assertIn(
            "diagonal high-row machines",
            self.shoulder_extension_row["definition"],
        )

    def test_shoulder_extension_row_roster_is_the_reviewed_coverage_matrix(
        self,
    ) -> None:
        actual = {}
        for exercise in self.shoulder_extension_row["exercises"]:
            variant = exercise["variant"]
            actual[exercise["catalogID"]] = (
                exercise["equipment"],
                exercise["laterality"],
                exercise["loadMode"],
                exercise["bodyweightFraction"],
                variant["kineticChain"],
                variant["bodyPosition"],
                variant["lowerBodySupport"],
                variant["torsoSupport"],
                variant["scapularTranslation"],
                variant["gripOrientation"],
                variant.get("relativeGripWidth"),
                variant["upperArmPath"],
                variant["fixedPath"],
                variant.get("machineType"),
                variant.get("leverArmConfiguration"),
                variant["interRepSupport"],
                variant["contralateralSupport"],
                variant.get("bodyweightApparatus"),
                variant.get("bodyLeverage"),
                tuple(exercise["additionalStabilityDemands"]),
            )

        self.assertEqual(
            actual,
            {
                "barbell-bent-over-row": (
                    "barbell", "bilateral", "external", 0, "open",
                    "hipHinged", "none", "none", "free", "pronated",
                    "shoulderWidth", "tucked", False, None, None, "none", "none",
                    None, None, ("spine", "pelvis", "hip"),
                ),
                "underhand-barbell-row": (
                    "barbell", "bilateral", "external", 0, "open",
                    "hipHinged", "none", "none", "free", "supinated",
                    "shoulderWidth", "tucked", False, None, None, "none", "none",
                    None, None, ("spine", "pelvis", "hip"),
                ),
                "pendlay-row": (
                    "barbell", "bilateral", "external", 0, "open",
                    "hipHinged", "none", "none", "free", "pronated",
                    "shoulderWidth", "tucked", False, None, None, "floor", "none",
                    None, None, ("spine", "pelvis", "hip"),
                ),
                "dumbbell-bent-over-row": (
                    "dumbbell", "bilateral", "external", 0, "open",
                    "hipHinged", "none", "none", "free", "neutral",
                    "shoulderWidth", "tucked", False, None, None, "none", "none",
                    None, None, ("spine", "pelvis", "hip"),
                ),
                "one-arm-dumbbell-row": (
                    "dumbbell", "unilateral", "external", 0, "open",
                    "hipHinged", "none", "none", "free", "neutral", None,
                    "tucked", False, None, None, "none", "handAndKneeOnBench",
                    None, None, ("spine", "pelvis", "hip"),
                ),
                "chest-supported-dumbbell-row": (
                    "dumbbell", "bilateral", "external", 0, "open", "prone",
                    "none", "bench", "free", "neutral", "shoulderWidth",
                    "tucked", False, None, None, "none", "none", None, None, (),
                ),
                "seated-cable-row": (
                    "cable", "bilateral", "external", 0, "open", "seated",
                    "none", "none", "free", "neutral", "narrow", "tucked",
                    False, None, None, "none", "none", None, None, ("spine",),
                ),
                "single-arm-seated-cable-row": (
                    "cable", "unilateral", "external", 0, "open", "seated",
                    "none", "none", "free", "neutral", None, "tucked",
                    False, None, None, "none", "none", None, None,
                    ("spine", "pelvis"),
                ),
                "chest-supported-machine-row": (
                    "machine", "bilateral", "external", 0, "open", "seated",
                    "none", "machinePad", "free", "neutral",
                    "shoulderWidth", "tucked", True, "leverRow", "linked", "none",
                    "none", None, None, (),
                ),
                "single-arm-chest-supported-machine-row": (
                    "machine", "unilateral", "external", 0, "open", "seated",
                    "none", "machinePad", "free", "neutral", None, "tucked",
                    True, "leverRow", "independent", "none", "none", None, None,
                    ("pelvis",),
                ),
                "smith-machine-bent-over-row": (
                    "machine", "bilateral", "external", 0, "open",
                    "hipHinged", "none", "none", "free", "pronated",
                    "shoulderWidth", "tucked", True, "smith", None, "none", "none",
                    None, None, ("spine", "pelvis", "hip"),
                ),
                "inverted-row": (
                    "bodyweight", "bilateral", "bodyweightAdded", 0.73,
                    "closed", "supineSuspended", "feet", "none", "free",
                    "pronated", "shoulderWidth", "scapular", False, None, None,
                    "none", "none", "fixedBar", "parallelFeetFloor",
                    ("spine", "pelvis", "hip"),
                ),
            },
        )

    def test_shoulder_extension_row_roster_covers_every_admitted_axis_value(
        self,
    ) -> None:
        exercises = self.shoulder_extension_row["exercises"]
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
                    set(self.shoulder_extension_row["allowed"][allowed_key]),
                )

        for axis in self.shoulder_extension_row["variantAxes"]:
            observed = {
                exercise["variant"][axis["id"]]
                for exercise in exercises
                if axis["id"] in exercise["variant"]
            }
            with self.subTest(axis=axis["id"]):
                if axis["valueType"] == "enum":
                    self.assertEqual(observed, set(axis["allowedValues"]))
                elif axis["valueType"] == "boolean":
                    self.assertEqual(observed, {False, True})
                elif axis["valueType"] == "number":
                    self.assertIn(axis["minimum"], observed)
                    self.assertIn(axis["maximum"], observed)

    def test_shoulder_extension_row_has_the_reviewed_rule_set(self) -> None:
        self.assertEqual(
            [
                rule["id"]
                for rule in self.shoulder_extension_row["exerciseRules"]
            ],
            [
                "bodyweight-uses-closed-chain-load-semantics",
                "parallel-feet-floor-pins-bodyweight-load",
                "fixed-bar-apparatus-requires-bodyweight",
                "non-bodyweight-uses-open-chain-external-load",
                "machine-requires-fixed-path-and-type",
                "non-machine-requires-free-path",
                "lever-row-is-supported-seated",
                "smith-row-is-hip-hinged",
                "linked-lever-arms-are-bilateral",
                "barbell-is-unsupported-hip-hinged",
                "dumbbell-is-neutral-free-path",
                "prone-row-is-supported-bilateral-dumbbell",
                "cable-is-unsupported-seated-free-path",
                "bench-support-requires-prone-dumbbell",
                "machine-pad-requires-lever-row",
                "hand-and-knee-support-is-unilateral-dumbbell",
                "bilateral-has-no-contralateral-support",
                "bilateral-requires-grip-width",
                "unilateral-requires-asymmetric-control",
                "hip-hinged-requires-posterior-chain-stability",
                "suspended-requires-straight-body-stability",
                "unsupported-requires-trunk-stability",
                "floor-reset-is-strict-pronated-barbell",
                "narrow-grip-requires-tucked-path",
                "supinated-grip-requires-tucked-path",
            ],
        )

    def test_every_shoulder_extension_row_rule_has_roster_contrast(
        self,
    ) -> None:
        exercises = self.shoulder_extension_row["exercises"]
        for rule in self.shoulder_extension_row["exerciseRules"]:
            predicate = rule["when"]
            values = [
                catalog_v2.exercise_rule_field(
                    exercise,
                    predicate["field"],
                )
                for exercise in exercises
            ]
            if predicate["operator"] == "equals":
                matches = [value == predicate["value"] for value in values]
            else:
                matches = [
                    value is not catalog_v2.MISSING
                    and value != predicate["value"]
                    for value in values
                ]
            with self.subTest(rule=rule["id"]):
                self.assertTrue(any(matches), "rule has no real matching exercise")
                self.assertTrue(
                    any(not match for match in matches),
                    "rule has no contrasting real exercise",
                )

    def test_shoulder_extension_row_requires_the_reviewed_role_contract(
        self,
    ) -> None:
        required_roles = {
            "lats": "primary",
            "teresMajor": "secondary",
            "deltoidPosterior": "secondary",
            "biceps": "secondary",
            "trapeziusMiddle": "secondary",
            "rhomboids": "secondary",
            "subscapularis": "stabilizer",
            "forearms": "stabilizer",
        }
        for exercise in self.shoulder_extension_row["exercises"]:
            roles = {
                assignment["muscle"]: assignment["role"]
                for assignment in exercise["involvement"]
            }
            with self.subTest(exercise=exercise["catalogID"]):
                for muscle_id, role in required_roles.items():
                    self.assertEqual(roles[muscle_id], role)
                if exercise["variant"]["bodyPosition"] == "hipHinged":
                    self.assertEqual(roles["lowerBack"], "stabilizer")
                    self.assertEqual(roles["gluteMax"], "stabilizer")
                if exercise["laterality"] == "unilateral":
                    self.assertEqual(roles["obliques"], "stabilizer")
                if exercise["variant"]["bodyPosition"] == "supineSuspended":
                    self.assertEqual(roles["abs"], "stabilizer")
                    self.assertEqual(roles["lowerBack"], "stabilizer")
                    self.assertEqual(roles["gluteMax"], "stabilizer")

    def test_every_shoulder_extension_row_rule_consequence_rejects_a_mutation(
        self,
    ) -> None:
        axes = {
            axis["id"]: axis
            for axis in self.shoulder_extension_row["variantAxes"]
        }

        def matches(exercise: dict, rule: dict) -> bool:
            predicate = rule["when"]
            actual = catalog_v2.exercise_rule_field(
                exercise,
                predicate["field"],
            )
            if actual is catalog_v2.MISSING:
                return False
            if predicate["operator"] == "equals":
                return actual == predicate["value"]
            return actual != predicate["value"]

        def set_field(exercise: dict, path: str, value: object) -> None:
            if path.startswith("variant."):
                exercise["variant"][path.removeprefix("variant.")] = value
            else:
                exercise[path] = value

        def delete_field(exercise: dict, path: str) -> None:
            if path.startswith("variant."):
                exercise["variant"].pop(
                    path.removeprefix("variant."),
                    None,
                )
            else:
                exercise.pop(path, None)

        def allowed_candidates(path: str) -> list[object]:
            if path in catalog_v2.RULE_FIELD_DOMAINS:
                return sorted(catalog_v2.RULE_FIELD_DOMAINS[path])
            if path in catalog_v2.RULE_NUMERIC_FIELDS:
                minimum, maximum = catalog_v2.RULE_NUMERIC_FIELDS[path]
                return [minimum, maximum]
            axis = axes[path.removeprefix("variant.")]
            if axis["valueType"] == "enum":
                return list(axis["allowedValues"])
            if axis["valueType"] == "boolean":
                return [False, True]
            if axis["valueType"] == "number":
                return [axis["minimum"], axis["maximum"]]
            return ["mutated"]

        mutated_consequences = 0
        for rule in self.shoulder_extension_row["exerciseRules"]:
            matching = next(
                exercise
                for exercise in self.shoulder_extension_row["exercises"]
                if matches(exercise, rule)
            )

            for assertion in rule["then"]:
                path = assertion["field"]
                forbidden = (
                    {assertion["value"]}
                    if "value" in assertion
                    else set(assertion["allowedValues"])
                )
                alternative = next(
                    (
                        candidate
                        for candidate in allowed_candidates(path)
                        if candidate not in forbidden
                    ),
                    catalog_v2.MISSING,
                )
                mutated = copy.deepcopy(matching)
                if alternative is catalog_v2.MISSING:
                    delete_field(mutated, path)
                else:
                    set_field(mutated, path, alternative)
                with self.subTest(rule=rule["id"], assertion=path):
                    with self.assertRaisesRegex(
                        catalog_v2.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog_v2.validate_exercise_rule_matches(
                            mutated,
                            [rule],
                            "mutated row",
                        )
                mutated_consequences += 1

            for path in rule["requirePresent"]:
                mutated = copy.deepcopy(matching)
                delete_field(mutated, path)
                with self.subTest(rule=rule["id"], missing=path):
                    with self.assertRaisesRegex(
                        catalog_v2.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog_v2.validate_exercise_rule_matches(
                            mutated,
                            [rule],
                            "mutated row",
                        )
                mutated_consequences += 1

            for path in rule["requireAbsent"]:
                mutated = copy.deepcopy(matching)
                set_field(mutated, path, allowed_candidates(path)[0])
                with self.subTest(rule=rule["id"], unexpected=path):
                    with self.assertRaisesRegex(
                        catalog_v2.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog_v2.validate_exercise_rule_matches(
                            mutated,
                            [rule],
                            "mutated row",
                        )
                mutated_consequences += 1

            for assignment in rule.get("requireInvolvement", []):
                mutated = copy.deepcopy(matching)
                mutated["involvement"] = [
                    existing
                    for existing in mutated["involvement"]
                    if existing["muscle"] != assignment["muscle"]
                ]
                with self.subTest(
                    rule=rule["id"],
                    muscle=assignment["muscle"],
                ):
                    with self.assertRaisesRegex(
                        catalog_v2.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog_v2.validate_exercise_rule_matches(
                            mutated,
                            [rule],
                            "mutated row",
                        )
                mutated_consequences += 1

            for requirement in rule.get("requireMuscleRequirements", []):
                candidates = set(requirement["anyOf"])
                mutated = copy.deepcopy(matching)
                mutated["involvement"] = [
                    existing
                    for existing in mutated["involvement"]
                    if existing["muscle"] not in candidates
                ]
                with self.subTest(rule=rule["id"], any_of=tuple(candidates)):
                    with self.assertRaisesRegex(
                        catalog_v2.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog_v2.validate_exercise_rule_matches(
                            mutated,
                            [rule],
                            "mutated row",
                        )
                mutated_consequences += 1

            for region in rule.get("requireAdditionalStabilityDemands", []):
                mutated = copy.deepcopy(matching)
                mutated["additionalStabilityDemands"] = [
                    demand
                    for demand in mutated["additionalStabilityDemands"]
                    if demand != region
                ]
                with self.subTest(rule=rule["id"], stability=region):
                    with self.assertRaisesRegex(
                        catalog_v2.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog_v2.validate_exercise_rule_matches(
                            mutated,
                            [rule],
                            "mutated row",
                        )
                mutated_consequences += 1

        self.assertEqual(mutated_consequences, 94)

    def test_row_families_share_lever_arm_configuration_vocabulary(self) -> None:
        extension_axes = {
            axis["id"]: axis
            for axis in self.shoulder_extension_row["variantAxes"]
        }
        shoulder_height_axes = {
            axis["id"]: axis
            for axis in self.shoulder_horizontal_abduction_row["variantAxes"]
        }
        expected = ["linked", "independent"]
        self.assertEqual(
            extension_axes["leverArmConfiguration"]["allowedValues"],
            expected,
        )
        self.assertEqual(
            shoulder_height_axes["leverArmConfiguration"]["allowedValues"],
            expected,
        )

        for family in (
            self.shoulder_extension_row,
            self.shoulder_horizontal_abduction_row,
        ):
            for exercise in family["exercises"]:
                machine_type = exercise["variant"].get("machineType")
                configuration = exercise["variant"].get(
                    "leverArmConfiguration"
                )
                with self.subTest(
                    family=family["id"],
                    exercise=exercise["catalogID"],
                ):
                    if machine_type == "leverRow":
                        self.assertIn(configuration, expected)
                        if exercise["laterality"] == "unilateral":
                            self.assertEqual(configuration, "independent")
                    else:
                        self.assertIsNone(configuration)

    def test_extension_row_unilateral_machine_requires_independent_levers(
        self,
    ) -> None:
        family = self.shoulder_extension_row_copy()
        exercise = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"]
            == "single-arm-chest-supported-machine-row"
        )
        exercise["variant"]["leverArmConfiguration"] = "linked"
        self.assert_shoulder_extension_row_fails(
            family,
            "violates exercise rule linked-lever-arms-are-bilateral",
        )

    def test_unilateral_smith_row_stays_blocked_by_smith_setup_rule(self) -> None:
        family = self.shoulder_extension_row_copy()
        exercise = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"]
            == "single-arm-chest-supported-machine-row"
        )
        exercise["variant"]["machineType"] = "smith"
        self.assert_shoulder_extension_row_fails(
            family,
            "violates exercise rule smith-row-is-hip-hinged: "
            "variant.bodyPosition must equal 'hipHinged'",
        )

    def test_unsupported_trunk_rule_is_pinned_to_seated_cable_row(self) -> None:
        family = self.shoulder_extension_row_copy()
        exercise = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"] == "seated-cable-row"
        )
        exercise["involvement"] = [
            assignment
            for assignment in exercise["involvement"]
            if assignment["muscle"] != "abs"
        ]
        self.assert_shoulder_extension_row_fails(
            family,
            "violates exercise rule unsupported-requires-trunk-stability: "
            "one of .* must be assigned as stabilizer or higher",
        )

    def test_shoulder_extension_row_evidence_discloses_interpolations(
        self,
    ) -> None:
        source_by_id = {
            source["id"]: source
            for source in self.foundation.evidence["sources"]
        }
        self.assertIn(
            "only three participants",
            source_by_id["garcia-jaen-2021-bent-over-row-posture"]["scope"],
        )
        self.assertIn(
            "not load-bearing evidence",
            source_by_id["garcia-jaen-2021-bent-over-row-posture"]["scope"],
        )
        self.assertIn(
            "article appeared online in December 2025",
            source_by_id[
                "padovan-2026-seated-row-scapular-position"
            ]["scope"],
        )
        self.assertEqual(
            source_by_id["padovan-2026-seated-row-scapular-position"]["year"],
            2026,
        )
        exercise_by_id = {
            exercise["catalogID"]: exercise
            for exercise in self.shoulder_extension_row["exercises"]
        }
        self.assertIn(
            "garcia-jaen-2021-bent-over-row-posture",
            exercise_by_id["chest-supported-dumbbell-row"]["evidenceRefs"],
        )
        self.assertIn(
            "saeterbakken-2015-unilateral-row-core",
            exercise_by_id["single-arm-seated-cable-row"]["evidenceRefs"],
        )
        self.assertIn(
            "saeterbakken-2015-unilateral-row-core",
            exercise_by_id[
                "single-arm-chest-supported-machine-row"
            ]["evidenceRefs"],
        )

    def test_shoulder_extension_row_rejects_opposing_and_propulsive_actions(
        self,
    ) -> None:
        for action in (
            "shoulder.flexion",
            "shoulder.horizontalAbduction",
            "scapula.protraction",
            "elbow.extension",
            "spine.extension",
            "hip.extension",
            "knee.extension",
        ):
            with self.subTest(action=action):
                family = self.shoulder_extension_row_copy()
                family["exercises"][0]["additionalPrimeActions"] = [action]
                self.assert_shoulder_extension_row_fails(
                    family,
                    f"declares forbidden prime action {action}",
                )

    def test_real_shoulder_horizontal_abduction_row_family_is_strict(
        self,
    ) -> None:
        warnings = catalog_v2.validate_family(
            self.shoulder_horizontal_abduction_row_copy(),
            self.foundation,
            "shoulder horizontal abduction row",
        )
        self.assertEqual(warnings, [])
        self.assertEqual(
            self.shoulder_horizontal_abduction_row["fixed"],
            {
                "mechanic": "compound",
                "pattern": "pull",
                "direction": "horizontal",
                "planes": ["transverse"],
            },
        )
        self.assertEqual(
            self.shoulder_horizontal_abduction_row["groupPolicy"],
            {"default": "shoulders", "allowed": ["shoulders"]},
        )
        self.assertEqual(
            self.shoulder_horizontal_abduction_row["movementSignature"][
                "planeBasisActions"
            ],
            ["shoulder.horizontalAbduction"],
        )
        self.assertEqual(
            self.shoulder_horizontal_abduction_row["movementSignature"][
                "primeActions"
            ],
            [
                "shoulder.horizontalAbduction",
                "scapula.retraction",
                "elbow.flexion",
            ],
        )
        forbidden = set(
            self.shoulder_horizontal_abduction_row["movementSignature"][
                "forbiddenPrimeActions"
            ]
        )
        self.assertTrue(
            {
                "shoulder.extension",
                "shoulder.externalRotation",
                "scapula.depression",
            }.issubset(forbidden)
        )

    def test_shoulder_horizontal_abduction_row_roster_is_reviewed_matrix(
        self,
    ) -> None:
        actual = {}
        for exercise in self.shoulder_horizontal_abduction_row["exercises"]:
            variant = exercise["variant"]
            actual[exercise["catalogID"]] = (
                exercise["equipment"],
                exercise["laterality"],
                variant["bodyPosition"],
                variant["torsoSupport"],
                variant["gripOrientation"],
                variant.get("relativeGripWidth"),
                variant["fixedPath"],
                variant.get("machineType"),
                variant.get("leverArmConfiguration"),
                variant["upperArmElevationDegrees"],
            )
        self.assertEqual(
            actual,
            {
                "wide-grip-barbell-rear-delt-row": (
                    "barbell",
                    "bilateral",
                    "hipHinged",
                    "none",
                    "pronated",
                    "wide",
                    False,
                    None,
                    None,
                    90,
                ),
                "chest-supported-dumbbell-rear-delt-row": (
                    "dumbbell",
                    "bilateral",
                    "prone",
                    "bench",
                    "neutral",
                    "wide",
                    False,
                    None,
                    None,
                    90,
                ),
                "wide-grip-seated-cable-rear-delt-row": (
                    "cable",
                    "bilateral",
                    "seated",
                    "none",
                    "pronated",
                    "wide",
                    False,
                    None,
                    None,
                    90,
                ),
                "single-arm-seated-cable-rear-delt-row": (
                    "cable",
                    "unilateral",
                    "seated",
                    "none",
                    "neutral",
                    None,
                    False,
                    None,
                    None,
                    90,
                ),
                "chest-supported-machine-rear-delt-row": (
                    "machine",
                    "bilateral",
                    "seated",
                    "machinePad",
                    "pronated",
                    "wide",
                    True,
                    "leverRow",
                    "linked",
                    90,
                ),
                "single-arm-chest-supported-machine-rear-delt-row": (
                    "machine",
                    "unilateral",
                    "seated",
                    "machinePad",
                    "neutral",
                    None,
                    True,
                    "leverRow",
                    "independent",
                    90,
                ),
            },
        )

    def test_shoulder_horizontal_abduction_row_covers_every_axis_value(
        self,
    ) -> None:
        family = self.shoulder_horizontal_abduction_row
        exercises = family["exercises"]
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
                    set(family["allowed"][allowed_key]),
                )

        for axis in family["variantAxes"]:
            observed = {
                exercise["variant"][axis["id"]]
                for exercise in exercises
                if axis["id"] in exercise["variant"]
            }
            with self.subTest(axis=axis["id"]):
                if axis["valueType"] == "enum":
                    self.assertEqual(observed, set(axis["allowedValues"]))
                elif axis["valueType"] == "boolean":
                    self.assertEqual(observed, {False, True})
                elif axis["valueType"] == "number":
                    self.assertIn(axis["minimum"], observed)
                    self.assertIn(axis["maximum"], observed)

    def test_shoulder_horizontal_abduction_row_has_reviewed_rule_set(
        self,
    ) -> None:
        self.assertEqual(
            [
                rule["id"]
                for rule in self.shoulder_horizontal_abduction_row[
                    "exerciseRules"
                ]
            ],
            [
                "machine-requires-fixed-path-and-type",
                "non-machine-requires-free-path",
                "lever-row-is-supported-seated",
                "barbell-is-bilateral-unsupported-hip-hinged",
                "dumbbell-is-bilateral-prone-bench-supported",
                "cable-is-unsupported-seated-free-path",
                "prone-is-supported-bilateral-dumbbell",
                "bench-support-requires-prone-dumbbell",
                "machine-pad-requires-lever-row",
                "bilateral-requires-grip-width",
                "unilateral-requires-asymmetric-control",
                "hip-hinged-requires-posterior-chain-stability",
                "unsupported-requires-trunk-stability",
                "linked-lever-arms-are-bilateral",
            ],
        )

    def test_every_shoulder_horizontal_abduction_row_rule_has_contrast(
        self,
    ) -> None:
        exercises = self.shoulder_horizontal_abduction_row["exercises"]
        for rule in self.shoulder_horizontal_abduction_row["exerciseRules"]:
            predicate = rule["when"]
            values = [
                catalog_v2.exercise_rule_field(
                    exercise,
                    predicate["field"],
                )
                for exercise in exercises
            ]
            if predicate["operator"] == "equals":
                matches = [value == predicate["value"] for value in values]
            else:
                matches = [
                    value is not catalog_v2.MISSING
                    and value != predicate["value"]
                    for value in values
                ]
            with self.subTest(rule=rule["id"]):
                self.assertTrue(any(matches), "rule has no real matching exercise")
                self.assertTrue(
                    any(not match for match in matches),
                    "rule has no contrasting real exercise",
                )

    def test_shoulder_horizontal_abduction_row_requires_role_contract(
        self,
    ) -> None:
        required_roles = {
            "deltoidPosterior": "primary",
            "trapeziusMiddle": "primary",
            "trapeziusLower": "secondary",
            "rhomboids": "secondary",
            "biceps": "secondary",
            "trapeziusUpper": "stabilizer",
            "forearms": "stabilizer",
        }
        for exercise in self.shoulder_horizontal_abduction_row["exercises"]:
            roles = {
                assignment["muscle"]: assignment["role"]
                for assignment in exercise["involvement"]
            }
            with self.subTest(exercise=exercise["catalogID"]):
                for muscle_id, role in required_roles.items():
                    self.assertEqual(roles[muscle_id], role)
                self.assertNotIn("lats", roles)
                self.assertNotIn("teresMajor", roles)
                if exercise["variant"]["bodyPosition"] == "hipHinged":
                    self.assertEqual(roles["lowerBack"], "stabilizer")
                    self.assertEqual(roles["gluteMax"], "stabilizer")
                if exercise["laterality"] == "unilateral":
                    self.assertEqual(roles["obliques"], "stabilizer")

    def test_every_shoulder_horizontal_abduction_rule_consequence_mutates(
        self,
    ) -> None:
        family = self.shoulder_horizontal_abduction_row
        axes = {axis["id"]: axis for axis in family["variantAxes"]}

        def matches(exercise: dict, rule: dict) -> bool:
            predicate = rule["when"]
            actual = catalog_v2.exercise_rule_field(
                exercise,
                predicate["field"],
            )
            if actual is catalog_v2.MISSING:
                return False
            if predicate["operator"] == "equals":
                return actual == predicate["value"]
            return actual != predicate["value"]

        def set_field(exercise: dict, path: str, value: object) -> None:
            if path.startswith("variant."):
                exercise["variant"][path.removeprefix("variant.")] = value
            else:
                exercise[path] = value

        def delete_field(exercise: dict, path: str) -> None:
            if path.startswith("variant."):
                exercise["variant"].pop(
                    path.removeprefix("variant."),
                    None,
                )
            else:
                exercise.pop(path, None)

        def allowed_candidates(path: str) -> list[object]:
            if path in catalog_v2.RULE_FIELD_DOMAINS:
                return sorted(catalog_v2.RULE_FIELD_DOMAINS[path])
            if path in catalog_v2.RULE_NUMERIC_FIELDS:
                minimum, maximum = catalog_v2.RULE_NUMERIC_FIELDS[path]
                return [minimum, maximum]
            axis = axes[path.removeprefix("variant.")]
            if axis["valueType"] == "enum":
                return list(axis["allowedValues"])
            if axis["valueType"] == "boolean":
                return [False, True]
            if axis["valueType"] == "number":
                return [axis["minimum"], axis["maximum"]]
            return ["mutated"]

        mutated_consequences = 0
        for rule in family["exerciseRules"]:
            matching = next(
                exercise
                for exercise in family["exercises"]
                if matches(exercise, rule)
            )

            for assertion in rule["then"]:
                path = assertion["field"]
                forbidden = (
                    {assertion["value"]}
                    if "value" in assertion
                    else set(assertion["allowedValues"])
                )
                alternative = next(
                    (
                        candidate
                        for candidate in allowed_candidates(path)
                        if candidate not in forbidden
                    ),
                    catalog_v2.MISSING,
                )
                mutated = copy.deepcopy(matching)
                if alternative is catalog_v2.MISSING:
                    delete_field(mutated, path)
                else:
                    set_field(mutated, path, alternative)
                with self.subTest(rule=rule["id"], assertion=path):
                    with self.assertRaisesRegex(
                        catalog_v2.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog_v2.validate_exercise_rule_matches(
                            mutated,
                            [rule],
                            "mutated shoulder-height row",
                        )
                mutated_consequences += 1

            for path in rule["requirePresent"]:
                mutated = copy.deepcopy(matching)
                delete_field(mutated, path)
                with self.subTest(rule=rule["id"], missing=path):
                    with self.assertRaisesRegex(
                        catalog_v2.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog_v2.validate_exercise_rule_matches(
                            mutated,
                            [rule],
                            "mutated shoulder-height row",
                        )
                mutated_consequences += 1

            for path in rule["requireAbsent"]:
                mutated = copy.deepcopy(matching)
                set_field(mutated, path, allowed_candidates(path)[0])
                with self.subTest(rule=rule["id"], unexpected=path):
                    with self.assertRaisesRegex(
                        catalog_v2.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog_v2.validate_exercise_rule_matches(
                            mutated,
                            [rule],
                            "mutated shoulder-height row",
                        )
                mutated_consequences += 1

            for assignment in rule.get("requireInvolvement", []):
                mutated = copy.deepcopy(matching)
                mutated["involvement"] = [
                    existing
                    for existing in mutated["involvement"]
                    if existing["muscle"] != assignment["muscle"]
                ]
                with self.subTest(
                    rule=rule["id"],
                    muscle=assignment["muscle"],
                ):
                    with self.assertRaisesRegex(
                        catalog_v2.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog_v2.validate_exercise_rule_matches(
                            mutated,
                            [rule],
                            "mutated shoulder-height row",
                        )
                mutated_consequences += 1

            for requirement in rule.get("requireMuscleRequirements", []):
                candidates = set(requirement["anyOf"])
                mutated = copy.deepcopy(matching)
                mutated["involvement"] = [
                    existing
                    for existing in mutated["involvement"]
                    if existing["muscle"] not in candidates
                ]
                with self.subTest(rule=rule["id"], any_of=tuple(candidates)):
                    with self.assertRaisesRegex(
                        catalog_v2.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog_v2.validate_exercise_rule_matches(
                            mutated,
                            [rule],
                            "mutated shoulder-height row",
                        )
                mutated_consequences += 1

            for region in rule.get("requireAdditionalStabilityDemands", []):
                mutated = copy.deepcopy(matching)
                mutated["additionalStabilityDemands"] = [
                    demand
                    for demand in mutated["additionalStabilityDemands"]
                    if demand != region
                ]
                with self.subTest(rule=rule["id"], stability=region):
                    with self.assertRaisesRegex(
                        catalog_v2.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog_v2.validate_exercise_rule_matches(
                            mutated,
                            [rule],
                            "mutated shoulder-height row",
                        )
                mutated_consequences += 1

        self.assertEqual(mutated_consequences, 49)

    def test_shoulder_height_row_unsupported_rule_is_pinned_to_cable(self) -> None:
        family = self.shoulder_horizontal_abduction_row
        exercise = next(
            copy.deepcopy(exercise)
            for exercise in family["exercises"]
            if exercise["catalogID"]
            == "wide-grip-seated-cable-rear-delt-row"
        )
        exercise["involvement"] = [
            assignment
            for assignment in exercise["involvement"]
            if assignment["muscle"] != "abs"
        ]
        rule = next(
            rule
            for rule in family["exerciseRules"]
            if rule["id"] == "unsupported-requires-trunk-stability"
        )
        with self.assertRaisesRegex(
            catalog_v2.ValidationFailure,
            "violates exercise rule unsupported-requires-trunk-stability",
        ):
            catalog_v2.validate_exercise_rule_matches(
                exercise,
                [rule],
                "mutated shoulder-height cable row",
            )

    def test_unilateral_machine_requires_independent_lever_arms(self) -> None:
        family = self.shoulder_horizontal_abduction_row_copy()
        exercise = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"]
            == "single-arm-chest-supported-machine-rear-delt-row"
        )
        exercise["variant"]["leverArmConfiguration"] = "linked"
        self.assert_shoulder_horizontal_abduction_row_fails(
            family,
            "violates exercise rule linked-lever-arms-are-bilateral",
        )

    def test_shoulder_height_row_rejects_60_degree_mixed_path(self) -> None:
        family = self.shoulder_horizontal_abduction_row_copy()
        family["exercises"][0]["variant"]["upperArmElevationDegrees"] = 60
        self.assert_shoulder_horizontal_abduction_row_fails(
            family,
            "upperArmElevationDegrees is below 90",
        )

    def test_shoulder_height_row_requires_dynamic_elbow_flexion(self) -> None:
        family = self.shoulder_horizontal_abduction_row_copy()
        family["movementSignature"]["primeActions"].remove("elbow.flexion")
        self.assert_shoulder_horizontal_abduction_row_fails(
            family,
            "biceps cannot produce any declared prime action",
        )

    def test_shoulder_height_row_rejects_neighboring_prime_actions(self) -> None:
        for action in (
            "shoulder.extension",
            "shoulder.externalRotation",
            "scapula.depression",
        ):
            with self.subTest(action=action):
                family = self.shoulder_horizontal_abduction_row_copy()
                family["exercises"][0]["additionalPrimeActions"] = [action]
                self.assert_shoulder_horizontal_abduction_row_fails(
                    family,
                    f"declares forbidden prime action {action}",
                )

    def test_shoulder_height_row_rejects_lats_and_teres_in_every_role(
        self,
    ) -> None:
        for muscle in ("lats", "teresMajor"):
            for role in ("primary", "secondary", "stabilizer"):
                with self.subTest(muscle=muscle, role=role):
                    family = self.shoulder_horizontal_abduction_row_copy()
                    family["exercises"][0]["involvement"].append(
                        {"muscle": muscle, "role": role}
                    )
                    self.assert_shoulder_horizontal_abduction_row_fails(
                        family,
                        f"does not allow {muscle} as {role}",
                    )

    def test_shoulder_height_row_rejects_constrained_scapula_and_bodyweight(
        self,
    ) -> None:
        family = self.shoulder_horizontal_abduction_row_copy()
        family["exercises"][1]["variant"]["scapularTranslation"] = "constrained"
        self.assert_shoulder_horizontal_abduction_row_fails(
            family,
            "scapularTranslation has disallowed value 'constrained'",
        )

        family = self.shoulder_horizontal_abduction_row_copy()
        exercise = family["exercises"][0]
        exercise["equipment"] = "bodyweight"
        exercise["loadMode"] = "bodyweightAdded"
        exercise["bodyweightFraction"] = 0.73
        self.assert_shoulder_horizontal_abduction_row_fails(
            family,
            "selects disallowed equipment: bodyweight",
        )

    def test_shoulder_height_row_aliases_and_global_identity_are_locked(
        self,
    ) -> None:
        aliases = {
            exercise["catalogID"]: exercise["aliases"]
            for exercise in self.shoulder_horizontal_abduction_row["exercises"]
        }
        self.assertEqual(
            aliases,
            {
                "wide-grip-barbell-rear-delt-row": [
                    "Barbell Rear-Delt Row",
                    "Wide-Grip Barbell High Row",
                ],
                "chest-supported-dumbbell-rear-delt-row": [
                    "Dumbbell Rear-Delt Row",
                    "Chest-Supported Dumbbell High Row",
                ],
                "wide-grip-seated-cable-rear-delt-row": [
                    "Cable Rear-Delt Row",
                    "Wide-Grip Cable High Row",
                ],
                "single-arm-seated-cable-rear-delt-row": [
                    "Single-Arm Cable Rear-Delt Row",
                    "One-Arm Cable Rear-Delt Row",
                ],
                "chest-supported-machine-rear-delt-row": [
                    "Machine Rear-Delt Row",
                    "Chest-Supported Machine High Row",
                ],
                "single-arm-chest-supported-machine-rear-delt-row": [
                    "Single-Arm Machine Rear-Delt Row",
                    "One-Arm Machine Rear-Delt Row",
                ],
            },
        )

        mutated = self.shoulder_horizontal_abduction_row_copy()
        mutated["exercises"][2]["aliases"].append("Cable Row")
        with self.assertRaises(catalog_v2.ValidationFailure):
            catalog_v2.validate_family_set(
                [self.shoulder_extension_row, mutated]
            )

    def test_shoulder_height_row_evidence_discloses_limits(self) -> None:
        source_by_id = {
            source["id"]: source
            for source in self.foundation.evidence["sources"]
        }
        self.assertIn(
            "nearer 0 degrees, plus separately named 30-, 60-, and 90-degree",
            source_by_id[
                "vasconcelos-2023-seated-row-abduction-angle"
            ]["scope"],
        )
        self.assertIn(
            "only the isometric phase was analyzed",
            source_by_id[
                "kara-2021-scapular-retraction-abduction-angle"
            ]["scope"],
        )
        self.assertIn(
            "not a mandatory cuff role",
            source_by_id[
                "sakaki-2013-shoulder-movement-direction-emg"
            ]["scope"],
        )
        self.assertIn(
            "directly relevant to the shoulder-height-row family",
            source_by_id["fennell-2016-shoulder-retractor-row"]["scope"],
        )

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

    def test_horizontal_lower_body_support_is_required_and_explicit(self) -> None:
        lower_body_support = next(
            axis
            for axis in self.horizontal_press["variantAxes"]
            if axis["id"] == "lowerBodySupport"
        )
        self.assertIs(lower_body_support["required"], True)
        self.assertEqual(
            set(lower_body_support["allowedValues"]),
            {"none", "feet", "knees"},
        )
        for exercise in self.horizontal_press["exercises"]:
            with self.subTest(exercise=exercise["catalogID"]):
                support = exercise["variant"]["lowerBodySupport"]
                if exercise["equipment"] == "bodyweight":
                    self.assertIn(support, {"feet", "knees"})
                else:
                    self.assertEqual(support, "none")

    def test_bodyweight_press_rejects_no_lower_body_support(self) -> None:
        family = self.horizontal_press_copy()
        push_up = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"] == "push-up"
        )
        push_up["variant"]["lowerBodySupport"] = "none"
        self.assert_horizontal_press_fails(
            family,
            "violates exercise rule bodyweight-closed-chain: "
            r"variant.lowerBodySupport must be one of \['feet', 'knees'\]",
        )

    def test_external_press_rejects_bodyweight_leverage_support(self) -> None:
        family = self.horizontal_press_copy()
        bench_press = next(
            exercise
            for exercise in family["exercises"]
            if exercise["catalogID"] == "barbell-bench-press"
        )
        bench_press["variant"]["lowerBodySupport"] = "feet"
        self.assert_horizontal_press_fails(
            family,
            "violates exercise rule external-implement-open-chain: "
            "variant.lowerBodySupport must equal 'none'",
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

    def test_batch1_activated_exactly_seven_narrow_families(self) -> None:
        expected = {
            "shoulder-extension-isolation": {
                "fixed": {
                    "mechanic": "isolation",
                    "pattern": None,
                    "direction": None,
                    "planes": ["sagittal"],
                },
                "basis": ["shoulder.extension"],
                "prime": ["shoulder.extension@fromFlexedPosition"],
                "primary": ["lats", "pectoralisMajorSternocostal"],
                "roster": [
                    "barbell-pullover",
                    "shoulder-width-straight-arm-cable-pulldown",
                    "wide-grip-straight-arm-cable-pulldown",
                ],
            },
            "chest-fly": {
                "fixed": {
                    "mechanic": "isolation",
                    "pattern": None,
                    "direction": None,
                    "planes": ["transverse"],
                },
                "basis": ["shoulder.horizontalAdduction"],
                "prime": ["shoulder.horizontalAdduction"],
                "primary": ["pectoralisMajorSternocostal"],
                "roster": ["flat-dumbbell-fly", "standing-band-fly"],
            },
            "reverse-fly": {
                "fixed": {
                    "mechanic": "isolation",
                    "pattern": None,
                    "direction": None,
                    "planes": ["transverse"],
                },
                "basis": ["shoulder.horizontalAbduction"],
                "prime": ["shoulder.horizontalAbduction"],
                "primary": ["deltoidPosterior"],
                "roster": [
                    "prone-dumbbell-reverse-fly",
                    "standing-band-reverse-fly",
                    "neutral-grip-machine-reverse-fly",
                    "pronated-grip-machine-reverse-fly",
                ],
            },
            "shoulder-flexion-raise": {
                "fixed": {
                    "mechanic": "isolation",
                    "pattern": None,
                    "direction": None,
                    "planes": ["sagittal"],
                },
                "basis": ["shoulder.flexion"],
                "prime": [
                    "shoulder.flexion",
                    "scapula.upwardRotation",
                    "scapula.posteriorTilt",
                ],
                "primary": ["deltoidAnterior"],
                "roster": ["single-arm-dumbbell-front-raise"],
            },
            "shoulder-abduction-raise": {
                "fixed": {
                    "mechanic": "isolation",
                    "pattern": None,
                    "direction": None,
                    "planes": ["frontal"],
                },
                "basis": ["shoulder.abduction"],
                "prime": [
                    "shoulder.abduction",
                    "scapula.upwardRotation",
                    "scapula.posteriorTilt",
                ],
                "primary": ["deltoidLateral"],
                "roster": [
                    "single-arm-dumbbell-lateral-raise",
                    "single-arm-cable-lateral-raise",
                ],
            },
            "shoulder-external-rotation": {
                "fixed": {
                    "mechanic": "isolation",
                    "pattern": None,
                    "direction": None,
                    "planes": ["transverse"],
                },
                "basis": ["shoulder.externalRotation"],
                "prime": ["shoulder.externalRotation"],
                "primary": ["externalRotators"],
                "roster": [
                    "standing-cable-shoulder-external-rotation",
                    "standing-band-shoulder-external-rotation",
                    "side-lying-dumbbell-shoulder-external-rotation",
                ],
            },
            "shoulder-internal-rotation": {
                "fixed": {
                    "mechanic": "isolation",
                    "pattern": None,
                    "direction": None,
                    "planes": ["transverse"],
                },
                "basis": ["shoulder.internalRotation"],
                "prime": ["shoulder.internalRotation"],
                "primary": ["subscapularis"],
                "roster": [
                    "standing-cable-shoulder-internal-rotation",
                    "standing-band-shoulder-internal-rotation",
                ],
            },
        }
        self.assertEqual(set(self.batch1_families), set(expected))

        for family_id, contract in expected.items():
            with self.subTest(family=family_id):
                family = self.batch1_families[family_id]
                prime_actions = [
                    (
                        f"{action['action']}@{action['condition']}"
                        if isinstance(action, dict)
                        else action
                    )
                    for action in family["movementSignature"]["primeActions"]
                ]
                self.assertEqual(family["fixed"], contract["fixed"])
                self.assertEqual(
                    family["movementSignature"]["planeBasisActions"],
                    contract["basis"],
                )
                self.assertEqual(prime_actions, contract["prime"])
                self.assertEqual(
                    family["musclePolicy"]["allowedByRole"]["primary"],
                    contract["primary"],
                )
                self.assertEqual(
                    [exercise["catalogID"] for exercise in family["exercises"]],
                    contract["roster"],
                )

    def test_discovered_real_family_registry_is_intentionally_pinned(
        self,
    ) -> None:
        # Evidence coverage intentionally auto-discovers family files. Keep an
        # exact registry pin beside it so adding or removing a contract remains
        # a reviewed catalog decision rather than an invisible filesystem edit.
        expected_ids = {
            "horizontal-press",
            "incline-press",
            "decline-press",
            "vertical-press",
            "vertical-pull",
            "shoulder-extension-row",
            "shoulder-horizontal-abduction-row",
            "shoulder-extension-isolation",
            "chest-fly",
            "reverse-fly",
            "shoulder-flexion-raise",
            "shoulder-abduction-raise",
            "shoulder-external-rotation",
            "shoulder-internal-rotation",
        }
        self.assertEqual(
            {family["id"] for family in self.real_families},
            expected_ids,
        )
        self.assertEqual(
            sum(len(family["exercises"]) for family in self.real_families),
            78,
        )

    def test_every_discovered_real_family_validates_without_warnings(
        self,
    ) -> None:
        for family in self.real_families:
            with self.subTest(family=family["id"]):
                self.assertEqual(
                    catalog_v2.validate_family(
                        family,
                        self.foundation,
                        f"active family {family['id']}",
                    ),
                    [],
                )

    def test_batch1_elbow_motion_vocabulary_is_shared(self) -> None:
        for family_id, family in self.batch1_families.items():
            with self.subTest(family=family_id):
                axes = {axis["id"]: axis for axis in family["variantAxes"]}
                self.assertEqual(
                    axes["elbowMotion"]["allowedValues"],
                    ["angleHeld"],
                )
                self.assertTrue(
                    all(
                        exercise["variant"]["elbowMotion"] == "angleHeld"
                        for exercise in family["exercises"]
                    )
                )

    def test_batch1_contracts_share_explicit_no_lower_body_prime_boundary(
        self,
    ) -> None:
        forbidden_body_actions = {
            "spine.flexion",
            "spine.extension",
            "spine.lateralFlexion",
            "spine.rotation",
            "hip.extension",
            "knee.extension",
            "ankle.plantarflexion",
        }
        for family_id, family in self.batch1_families.items():
            with self.subTest(family=family_id):
                self.assertTrue(
                    forbidden_body_actions.issubset(
                        family["movementSignature"]["forbiddenPrimeActions"]
                    )
                )
                axes = {axis["id"]: axis for axis in family["variantAxes"]}
                self.assertIn("lowerBodyContribution", axes)
                self.assertTrue(axes["lowerBodyContribution"]["required"])
                self.assertEqual(
                    axes["lowerBodyContribution"]["allowedValues"],
                    ["none"],
                )
                self.assertTrue(
                    all(
                        exercise["variant"]["lowerBodyContribution"] == "none"
                        for exercise in family["exercises"]
                    )
                )

    def test_batch1_raises_treat_upper_trapezius_as_dynamic_secondary(
        self,
    ) -> None:
        evidence_refs = {
            "seth-2019-shoulder-work",
            "morihara-2011-scapular-muscles-flexion-abduction",
        }
        for family_id in (
            "shoulder-flexion-raise",
            "shoulder-abduction-raise",
        ):
            with self.subTest(family=family_id):
                family = self.batch1_families[family_id]
                requirement = next(
                    requirement
                    for requirement in family["musclePolicy"]["requirements"]
                    if requirement["anyOf"] == ["trapeziusUpper"]
                )
                self.assertEqual(requirement["minimumRole"], "secondary")
                self.assertIn(
                    "trapeziusUpper",
                    family["musclePolicy"]["allowedByRole"]["secondary"],
                )
                self.assertNotIn(
                    "trapeziusUpper",
                    family["musclePolicy"]["allowedByRole"]["stabilizer"],
                )
                self.assertTrue(
                    evidence_refs.issubset(family["evidenceRefs"])
                )
                for exercise in family["exercises"]:
                    role = next(
                        item["role"]
                        for item in exercise["involvement"]
                        if item["muscle"] == "trapeziusUpper"
                    )
                    self.assertEqual(role, "secondary")

    def test_batch1_raise_and_rotation_geometry_cannot_be_interchanged(
        self,
    ) -> None:
        flexion = self.batch1_families["shoulder-flexion-raise"]
        abduction = self.batch1_families["shoulder-abduction-raise"]
        self.assertEqual(
            {
                "shoulder-flexion-raise": (
                    "sagittal",
                    "shoulder.flexion",
                    0,
                    90,
                ),
                "shoulder-abduction-raise": (
                    "frontal",
                    "shoulder.abduction",
                    0,
                    90,
                ),
            },
            {
                family["id"]: (
                    next(
                        axis["allowedValues"][0]
                        for axis in family["variantAxes"]
                        if axis["id"] == "elevationPath"
                    ),
                    family["movementSignature"]["planeBasisActions"][0],
                    next(
                        axis["minimum"]
                        for axis in family["variantAxes"]
                        if axis["id"]
                        == "humerothoracicStartElevationDegrees"
                    ),
                    next(
                        axis["maximum"]
                        for axis in family["variantAxes"]
                        if axis["id"]
                        == "humerothoracicEndElevationDegrees"
                    ),
                )
                for family in (flexion, abduction)
            },
        )
        for family in (flexion, abduction):
            self.assertEqual(
                family["movementSignature"]["primeActions"][1:],
                ["scapula.upwardRotation", "scapula.posteriorTilt"],
            )
            self.assertIn(
                "scapula.protraction",
                family["movementSignature"]["forbiddenPrimeActions"],
            )
            self.assertIn(
                "scapula.retraction",
                family["movementSignature"]["forbiddenPrimeActions"],
            )

        for family_id in (
            "shoulder-external-rotation",
            "shoulder-internal-rotation",
        ):
            family = self.batch1_families[family_id]
            axes = {axis["id"]: axis for axis in family["variantAxes"]}
            self.assertNotIn("elevationPath", axes)
            self.assertNotIn("gripOrientation", axes)
            self.assertEqual(
                axes["humerothoracicElevationDegrees"]["minimum"],
                0,
            )
            self.assertEqual(
                axes["humerothoracicElevationDegrees"]["maximum"],
                0,
            )

    def test_batch1_rosters_cover_every_discrete_axis_value(self) -> None:
        expected_boolean_coverage = {
            ("reverse-fly", "fixedPath"): {False, True},
            ("shoulder-external-rotation", "fixedPath"): {False},
            ("shoulder-internal-rotation", "fixedPath"): {False},
        }
        for family_id, family in self.batch1_families.items():
            for axis in family["variantAxes"]:
                observed = {
                    exercise["variant"][axis["id"]]
                    for exercise in family["exercises"]
                    if axis["id"] in exercise["variant"]
                }
                with self.subTest(family=family_id, axis=axis["id"]):
                    if axis["valueType"] == "enum":
                        self.assertEqual(observed, set(axis["allowedValues"]))
                    elif axis["valueType"] == "number":
                        self.assertEqual(axis.get("minimum"), axis.get("maximum"))
                        self.assertEqual(observed, {axis["minimum"]})
                    elif axis["valueType"] == "boolean":
                        self.assertEqual(
                            observed,
                            expected_boolean_coverage[(family_id, axis["id"])],
                        )

    def test_every_batch1_rule_has_a_match_and_a_contrast(self) -> None:
        for family_id, family in self.batch1_families.items():
            for rule in family["exerciseRules"]:
                matches = [
                    self.rule_matches_exercise(rule, exercise)
                    for exercise in family["exercises"]
                ]
                with self.subTest(family=family_id, rule=rule["id"]):
                    self.assertTrue(any(matches))
                    self.assertTrue(any(not value for value in matches))

    def test_every_batch1_rule_consequence_has_a_rejecting_mutation(
        self,
    ) -> None:
        for family_id, original in self.batch1_families.items():
            for rule_index, rule in enumerate(original["exerciseRules"]):
                exercise_index = next(
                    index
                    for index, exercise in enumerate(original["exercises"])
                    if self.rule_matches_exercise(rule, exercise)
                )
                expected_message = (
                    "violates exercise rule " + re.escape(rule["id"])
                )

                for assertion_index, assertion in enumerate(rule["then"]):
                    with self.subTest(
                        family=family_id,
                        rule=rule["id"],
                        assertion=assertion_index,
                    ):
                        family = copy.deepcopy(original)
                        exercise = family["exercises"][exercise_index]
                        rejected = (
                            {assertion["value"]}
                            if "value" in assertion
                            else set(assertion["allowedValues"])
                        )
                        has_alternative, alternative = self.alternate_rule_value(
                            family,
                            assertion["field"],
                            rejected,
                        )
                        if has_alternative:
                            self.set_rule_field(
                                exercise,
                                assertion["field"],
                                alternative,
                            )
                        else:
                            self.delete_rule_field(exercise, assertion["field"])
                        self.assert_batch1_family_fails(
                            family,
                            expected_message,
                        )

                for field_path in rule["requirePresent"]:
                    with self.subTest(
                        family=family_id,
                        rule=rule["id"],
                        require_present=field_path,
                    ):
                        family = copy.deepcopy(original)
                        self.delete_rule_field(
                            family["exercises"][exercise_index],
                            field_path,
                        )
                        self.assert_batch1_family_fails(
                            family,
                            expected_message,
                        )

                for field_path in rule["requireAbsent"]:
                    with self.subTest(
                        family=family_id,
                        rule=rule["id"],
                        require_absent=field_path,
                    ):
                        family = copy.deepcopy(original)
                        has_alternative, alternative = self.alternate_rule_value(
                            family,
                            field_path,
                            set(),
                        )
                        self.assertTrue(has_alternative)
                        self.set_rule_field(
                            family["exercises"][exercise_index],
                            field_path,
                            alternative,
                        )
                        self.assert_batch1_family_fails(
                            family,
                            expected_message,
                        )

                for requirement_index, requirement in enumerate(
                    rule.get("requireMuscleRequirements", [])
                ):
                    with self.subTest(
                        family=family_id,
                        rule=rule["id"],
                        muscle_requirement=requirement_index,
                    ):
                        family = copy.deepcopy(original)
                        exercise = family["exercises"][exercise_index]
                        exercise["involvement"] = [
                            assignment
                            for assignment in exercise["involvement"]
                            if assignment["muscle"] not in requirement["anyOf"]
                        ]
                        # A missing conditional trunk stabilizer can be rejected
                        # by the general stability-demand validator before the
                        # rule evaluator. Either path is the intended failure:
                        # the exercise cannot escape the contract by relying on
                        # validator ordering.
                        self.assert_batch1_family_fails(
                            family,
                            (
                                expected_message
                                + "|has no assigned muscle capable of stabilizing"
                            ),
                        )

                for region in rule.get(
                    "requireAdditionalStabilityDemands", []
                ):
                    with self.subTest(
                        family=family_id,
                        rule=rule["id"],
                        stability_demand=region,
                    ):
                        family = copy.deepcopy(original)
                        exercise = family["exercises"][exercise_index]
                        exercise["additionalStabilityDemands"].remove(region)
                        # The now-orphaned stabilizer may be caught by the
                        # general anatomy validator before the rule-specific
                        # missing-demand assertion. Both prove that removing the
                        # required demand is rejected.
                        self.assert_batch1_family_fails(
                            family,
                            (
                                expected_message
                                + "|cannot stabilize any declared demand"
                            ),
                        )

    def test_shoulder_extension_primary_role_flip_is_rule_enforced(self) -> None:
        original = self.batch1_families["shoulder-extension-isolation"]
        mutations = (
            (
                "barbell-pullover",
                "pectoralisMajorSternocostal",
                "secondary",
                "lats",
                "primary",
                "back",
                "pectoralisMajorSternocostal must be assigned as primary",
            ),
            (
                "barbell-pullover",
                "lats",
                "primary",
                None,
                None,
                "chest",
                "lats must be assigned as secondary",
            ),
            (
                "shoulder-width-straight-arm-cable-pulldown",
                "lats",
                "secondary",
                "pectoralisMajorSternocostal",
                "primary",
                "chest",
                "lats must be assigned as primary",
            ),
            (
                "shoulder-width-straight-arm-cable-pulldown",
                "pectoralisMajorSternocostal",
                "primary",
                None,
                None,
                "back",
                "pectoralisMajorSternocostal must be assigned as secondary",
            ),
        )
        for (
            catalog_id,
            muscle,
            role,
            second_muscle,
            second_role,
            group,
            message,
        ) in mutations:
            with self.subTest(exercise=catalog_id, muscle=muscle, role=role):
                family = copy.deepcopy(original)
                exercise = next(
                    exercise
                    for exercise in family["exercises"]
                    if exercise["catalogID"] == catalog_id
                )
                exercise["groupOverride"] = group
                next(
                    assignment
                    for assignment in exercise["involvement"]
                    if assignment["muscle"] == muscle
                )["role"] = role
                if second_muscle is not None:
                    next(
                        assignment
                        for assignment in exercise["involvement"]
                        if assignment["muscle"] == second_muscle
                    )["role"] = second_role
                self.assert_batch1_family_fails(family, message)

    def test_every_batch1_forbidden_action_rejects_an_exercise_mutation(
        self,
    ) -> None:
        for family_id, original in self.batch1_families.items():
            for action in original["movementSignature"][
                "forbiddenPrimeActions"
            ]:
                with self.subTest(family=family_id, action=action):
                    family = copy.deepcopy(original)
                    family["exercises"][0]["additionalPrimeActions"] = [action]
                    self.assert_batch1_family_fails(
                        family,
                        f"declares forbidden prime action {re.escape(action)}",
                    )

    def test_batch1_primary_roles_cannot_be_demoted(self) -> None:
        for family_id, original in self.batch1_families.items():
            for exercise_index, exercise in enumerate(original["exercises"]):
                with self.subTest(
                    family=family_id,
                    exercise=exercise["catalogID"],
                ):
                    family = copy.deepcopy(original)
                    for assignment in family["exercises"][exercise_index][
                        "involvement"
                    ]:
                        if assignment["role"] == "primary":
                            assignment["role"] = "secondary"
                    self.assert_batch1_family_fails(
                        family,
                        (
                            "does not allow .* as secondary"
                            "|requires at least one primary muscle"
                            "|fails muscle requirement"
                        ),
                    )

    def test_batch1_evidence_scopes_preserve_material_limitations(self) -> None:
        source_by_id = {
            source["id"]: source
            for source in self.foundation.evidence["sources"]
        }
        expected_scope_phrases = {
            "marchetti-2011-barbell-pullover": "resistance-profile-specific",
            "muyor-2022-pullover-straight-arm-pulldown": (
                "distinct resistance-profile branches"
            ),
            "bergquist-2018-band-free-weight-fly": "phase- and implement-dependent",
            "schoenfeld-2013-reverse-fly-hand-position": (
                "not a separate external-rotation prime action"
            ),
            "ludewig-2009-multiplanar-humeral-elevation": (
                "without assigning fixed magnitudes"
            ),
            "morihara-2011-scapular-muscles-flexion-abduction": (
                "activity increased gradually in both paths"
            ),
            "larsen-2025-cable-dumbbell-lateral-raise": (
                "do not admit scaption"
            ),
            "dark-2007-shoulder-rotation-recruitment": (
                "rather than one muscle acting alone"
            ),
            "ginn-2017-subscapularis-internal-rotation": (
                "not direct evidence for a dynamic cable or band trajectory"
            ),
        }
        for source_id, phrase in expected_scope_phrases.items():
            with self.subTest(source=source_id):
                self.assertIn(phrase, source_by_id[source_id]["scope"])

    def test_batch1_deferred_candidates_are_not_active_families(self) -> None:
        active_ids = {family["id"] for family in self.real_families}
        self.assertTrue(
            {"scapular-retraction", "upright-row"}.isdisjoint(active_ids)
        )

    def test_all_evidence_is_used_by_anatomy_or_a_family(self) -> None:
        catalog_v2.validate_evidence_coverage(
            self.foundation,
            self.real_families,
        )

    def test_real_family_set_has_no_cross_family_identity_collisions(self) -> None:
        catalog_v2.validate_family_set(self.real_families)

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
