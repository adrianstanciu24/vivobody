#!/usr/bin/env python3
#
#  test_catalog.py
#  vivobody
#
#  Mutation-oriented tests for the isolated family-first catalog foundation.
#  They prove the validator rejects unknown muscles, invalid mesh ownership,
#  anatomically incapable movers, uncovered stability demands, undeclared
#  variant axes, forbidden prime actions, mismatched position conditions,
#  resisted-action opposition and family-level boundaries, conditional
#  muscle-role, allowed-set and variant-specific stability requirements, and
#  numeric involvement weights while keeping recommendations non-fatal.
#

from __future__ import annotations

import copy
import hashlib
import json
import re
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SCRIPTS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_ROOT))

import catalog  # noqa: E402


class CatalogFoundationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.foundation = catalog.validate_foundation()
        cls.valid_family = catalog.load_json(catalog.FAMILY_FIXTURE_PATH)
        cls.horizontal_press = catalog.load_json(
            catalog.FAMILIES_ROOT / "horizontal-press.json"
        )
        cls.incline_press = catalog.load_json(
            catalog.FAMILIES_ROOT / "incline-press.json"
        )
        cls.decline_press = catalog.load_json(
            catalog.FAMILIES_ROOT / "decline-press.json"
        )
        cls.vertical_press = catalog.load_json(
            catalog.FAMILIES_ROOT / "vertical-press.json"
        )
        cls.vertical_pull = catalog.load_json(
            catalog.FAMILIES_ROOT / "vertical-pull.json"
        )
        cls.shoulder_extension_row = catalog.load_json(
            catalog.FAMILIES_ROOT / "shoulder-extension-row.json"
        )
        cls.shoulder_horizontal_abduction_row = catalog.load_json(
            catalog.FAMILIES_ROOT
            / "shoulder-horizontal-abduction-row.json"
        )
        cls.real_families = [
            catalog.load_json(path)
            for path in catalog.discovered_family_paths()
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
        batch2_ids = {
            "elbow-flexion",
            "elbow-extension",
            "forearm-pronation",
            "forearm-supination",
            "wrist-flexion",
            "wrist-extension",
            "wrist-radial-deviation",
            "wrist-ulnar-deviation",
        }
        cls.batch2_families = {
            family["id"]: family
            for family in cls.real_families
            if family["id"] in batch2_ids
        }
        batch3_ids = {
            "scapular-protraction",
            "scapular-elevation",
            "dip",
            "push-press",
        }
        cls.batch3_families = {
            family["id"]: family
            for family in cls.real_families
            if family["id"] in batch3_ids
        }
        batch4_ids = {
            "knee-extension",
            "knee-flexion",
            "hip-extension",
            "ankle-plantarflexion",
        }
        cls.batch4_families = {
            family["id"]: family
            for family in cls.real_families
            if family["id"] in batch4_ids
        }
        batch5_ids = {
            "bilateral-squat",
            "hip-thrust-bridge",
            "split-stance-squat",
            "step-up",
        }
        cls.batch5_families = {
            family["id"]: family
            for family in cls.real_families
            if family["id"] in batch5_ids
        }
        batch6_ids = {
            "hip-abduction",
            "hip-adduction",
            "ankle-dorsiflexion",
            "hip-internal-rotation",
            "hip-external-rotation",
        }
        cls.batch6_families = {
            family["id"]: family
            for family in cls.real_families
            if family["id"] in batch6_ids
        }
        batch7_ids = {
            "spine-flexion",
            "spine-extension",
            "spine-lateral-flexion",
            "spine-rotation",
            "anti-extension",
            "anti-lateral-flexion",
            "anti-rotation",
            "farmer-carry",
            "suitcase-carry",
        }
        cls.batch7_families = {
            family["id"]: family
            for family in cls.real_families
            if family["id"] in batch7_ids
        }
        scapular_closure_ids = {
            "scapular-retraction",
            "scapular-depression",
            "scapular-elevation",
            "upright-row",
        }
        cls.scapular_closure_families = {
            family["id"]: family
            for family in cls.real_families
            if family["id"] in scapular_closure_ids
        }
        late_lower_body_closure_ids = {
            "hip-flexion",
            "hip-hinge",
            "dynamic-lunge",
        }
        cls.late_lower_body_closure_families = {
            family["id"]: family
            for family in cls.real_families
            if family["id"] in late_lower_body_closure_ids
        }

    def family_copy(self) -> dict:
        return copy.deepcopy(self.valid_family)

    @staticmethod
    def evidence_source(
        source_id: str,
        *,
        url: str,
        doi: str | None = None,
        pmid: str | None = None,
        pmcid: str | None = None,
    ) -> dict:
        source = {
            "id": source_id,
            "sourceType": "experimentalStudy",
            "title": f"Evidence fixture {source_id}",
            "authors": ["Test Author"],
            "year": 2026,
            "url": url,
            "scope": "Mutation fixture for canonical evidence identifiers.",
        }
        for key, value in (("doi", doi), ("pmid", pmid), ("pmcid", pmcid)):
            if value is not None:
                source[key] = value
        return source

    @staticmethod
    def evidence_registry(*sources: dict) -> dict:
        return {
            "schemaVersion": catalog.SCHEMA_VERSION,
            "description": "Canonical evidence identifier test registry.",
            "sources": list(sources),
        }

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
        with self.assertRaisesRegex(catalog.ValidationFailure, message):
            catalog.validate_family(
                family,
                self.foundation,
                f"mutated {family['id']}",
            )

    def assert_batch2_family_fails(
        self,
        family: dict,
        message: str,
    ) -> None:
        with self.assertRaisesRegex(catalog.ValidationFailure, message):
            catalog.validate_family(
                family,
                self.foundation,
                f"mutated {family['id']}",
            )

    def assert_batch3_family_fails(
        self,
        family: dict,
        message: str,
    ) -> None:
        with self.assertRaisesRegex(catalog.ValidationFailure, message):
            catalog.validate_family(
                family,
                self.foundation,
                f"mutated {family['id']}",
            )

    def assert_batch4_family_fails(
        self,
        family: dict,
        message: str,
    ) -> None:
        with self.assertRaisesRegex(catalog.ValidationFailure, message):
            catalog.validate_family(
                family,
                self.foundation,
                f"mutated {family['id']}",
            )

    def assert_batch5_family_fails(
        self,
        family: dict,
        message: str,
    ) -> None:
        with self.assertRaisesRegex(catalog.ValidationFailure, message):
            catalog.validate_family(
                family,
                self.foundation,
                f"mutated {family['id']}",
            )

    def assert_batch6_family_fails(
        self,
        family: dict,
        message: str,
    ) -> None:
        with self.assertRaisesRegex(catalog.ValidationFailure, message):
            catalog.validate_family(
                family,
                self.foundation,
                f"mutated {family['id']}",
            )

    def assert_batch7_family_fails(
        self,
        family: dict,
        message: str,
    ) -> None:
        with self.assertRaisesRegex(catalog.ValidationFailure, message):
            catalog.validate_family(
                family,
                self.foundation,
                f"mutated {family['id']}",
            )

    def assert_late_lower_body_closure_fails(
        self,
        family: dict,
        message: str,
    ) -> None:
        with self.assertRaisesRegex(catalog.ValidationFailure, message):
            catalog.validate_family(
                family,
                self.foundation,
                f"mutated late closure {family['id']}",
            )

    def scapular_closure_family_copy(self, family_id: str) -> dict:
        return copy.deepcopy(self.scapular_closure_families[family_id])

    def assert_scapular_closure_family_fails(
        self,
        family: dict,
        message: str,
    ) -> None:
        with self.assertRaisesRegex(catalog.ValidationFailure, message):
            catalog.validate_family(
                family,
                self.foundation,
                f"mutated {family['id']}",
            )

    def rule_matches_exercise(self, rule: dict, exercise: dict) -> bool:
        predicate = rule["when"]
        actual = catalog.exercise_rule_field(exercise, predicate["field"])
        if actual is catalog.MISSING:
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

    def sternocostal_flexion_family(self, action_requirement: object) -> dict:
        family = self.family_copy()
        family["fixed"]["planes"] = ["sagittal"]
        family["movementSignature"]["planeBasisActions"] = ["shoulder.flexion"]
        family["movementSignature"]["primeActions"] = [action_requirement]
        family["exercises"][0]["involvement"] = [
            {"muscle": "pectoralisMajorSternocostal", "role": "primary"},
            {"muscle": "serratus", "role": "stabilizer"},
        ]
        return family

    def resisted_spine_family(self) -> dict:
        family = self.family_copy()
        family["fixed"] = {
            "mechanic": "isolation",
            "pattern": None,
            "direction": None,
            "planes": ["sagittal"],
        }
        family["groupPolicy"] = {
            "default": "core",
            "allowed": ["core"],
        }
        family["movementSignature"] = {
            "planeBasisActions": ["spine.extension"],
            "primeActions": [],
            "resistedActions": ["spine.extension"],
            "stabilityDemands": ["spine"],
        }
        family["musclePolicy"] = {
            "requirements": [
                {"anyOf": ["abs"], "minimumRole": "primary"}
            ],
            "allowedByRole": {
                "primary": ["abs"],
                "secondary": [],
                "stabilizer": [],
            },
        }
        exercise = family["exercises"][0]
        exercise["involvement"] = [
            {"muscle": "abs", "role": "primary"}
        ]
        exercise["additionalPrimeActions"] = []
        exercise["additionalStabilityDemands"] = []
        return family

    def assert_family_fails(self, family: dict, message: str) -> None:
        with self.assertRaisesRegex(catalog.ValidationFailure, message):
            catalog.validate_family(family, self.foundation, "mutated fixture")

    def assert_horizontal_press_fails(self, family: dict, message: str) -> None:
        with self.assertRaisesRegex(catalog.ValidationFailure, message):
            catalog.validate_family(
                family,
                self.foundation,
                "mutated horizontal press",
            )

    def assert_incline_press_fails(self, family: dict, message: str) -> None:
        with self.assertRaisesRegex(catalog.ValidationFailure, message):
            catalog.validate_family(
                family,
                self.foundation,
                "mutated incline press",
            )

    def assert_decline_press_fails(self, family: dict, message: str) -> None:
        with self.assertRaisesRegex(catalog.ValidationFailure, message):
            catalog.validate_family(
                family,
                self.foundation,
                "mutated decline press",
            )

    def assert_vertical_press_fails(self, family: dict, message: str) -> None:
        with self.assertRaisesRegex(catalog.ValidationFailure, message):
            catalog.validate_family(
                family,
                self.foundation,
                "mutated vertical press",
            )

    def assert_vertical_pull_fails(self, family: dict, message: str) -> None:
        with self.assertRaisesRegex(catalog.ValidationFailure, message):
            catalog.validate_family(
                family,
                self.foundation,
                "mutated vertical pull",
            )

    def assert_shoulder_extension_row_fails(
        self,
        family: dict,
        message: str,
    ) -> None:
        with self.assertRaisesRegex(catalog.ValidationFailure, message):
            catalog.validate_family(
                family,
                self.foundation,
                "mutated shoulder extension row",
            )

    def assert_shoulder_horizontal_abduction_row_fails(
        self,
        family: dict,
        message: str,
    ) -> None:
        with self.assertRaisesRegex(catalog.ValidationFailure, message):
            catalog.validate_family(
                family,
                self.foundation,
                "mutated shoulder horizontal abduction row",
            )

    def test_taxonomy_is_the_locked_58_region_clean_slate(self) -> None:
        self.assertEqual(catalog.EXPECTED_MUSCLE_COUNT, 58)
        self.assertEqual(set(self.foundation.muscle_by_id), catalog.EXPECTED_MUSCLE_IDS)
        self.assertEqual(
            len(self.foundation.muscle_by_id),
            catalog.EXPECTED_MUSCLE_COUNT,
        )
        self.assertEqual(
            self.foundation.mesh_base_count,
            catalog.EXPECTED_MESH_BASE_COUNT,
        )

    def test_hip_rotation_taxonomy_additions_and_unvisualized_set_are_exact(
        self,
    ) -> None:
        expected_new = {
            "gluteMin": (
                "Glute Min",
                "Gluteus Minimus",
                "BodyModel.scn has no gluteus-minimus surface mesh.",
            ),
            "piriformis": (
                "Piriformis",
                "Piriformis",
                "BodyModel.scn has no piriformis surface mesh.",
            ),
            "obturatorInternusGemelli": (
                "Obturator Internus + Gemelli",
                "Obturator Internus, Superior Gemellus, and Inferior Gemellus",
                "BodyModel.scn has no obturator-internus or gemelli surface mesh.",
            ),
            "obturatorExternus": (
                "Obturator Externus",
                "Obturator Externus",
                "BodyModel.scn has no obturator-externus surface mesh.",
            ),
            "quadratusFemoris": (
                "Quadratus Femoris",
                "Quadratus Femoris",
                "BodyModel.scn has no quadratus-femoris surface mesh.",
            ),
        }
        for muscle_id, (display, anatomical, reason) in expected_new.items():
            with self.subTest(muscle=muscle_id):
                muscle = self.foundation.muscle_by_id[muscle_id]
                self.assertEqual(muscle["displayName"], display)
                self.assertEqual(muscle["anatomicalName"], anatomical)
                self.assertEqual(muscle["group"], "legs")
                self.assertEqual(muscle["meshBaseNames"], [])
                self.assertEqual(muscle["unvisualizedReason"], reason)

        self.assertEqual(
            {
                muscle_id
                for muscle_id, muscle in self.foundation.muscle_by_id.items()
                if muscle["meshBaseNames"] == []
            },
            {
                "lumbarExtensors",
                "subscapularis",
                "supraspinatus",
                "forearmPronators",
                "supinator",
                *expected_new,
            },
        )

        for muscle_id in expected_new:
            taxonomy = copy.deepcopy(self.foundation.taxonomy)
            muscle = next(
                item
                for item in taxonomy["muscles"]
                if item["id"] == muscle_id
            )
            muscle["unvisualizedReason"] = ""
            with self.subTest(muscle=muscle_id), self.assertRaisesRegex(
                catalog.ValidationFailure,
                "unvisualizedReason must be a non-empty string",
            ):
                catalog.validate_taxonomy(taxonomy)

    def test_non_trainable_scene_meshes_are_exactly_pinned(self) -> None:
        self.assertEqual(
            catalog.NON_TRAINABLE_MESH_BASES,
            {
                "Serratus_Posterior_Inferior",
                "Serratus_Posterior_Superior",
            },
        )

    def test_posterior_serratus_cannot_become_trainable_mesh_ownership(
        self,
    ) -> None:
        for mesh_base in sorted(catalog.NON_TRAINABLE_MESH_BASES):
            taxonomy = copy.deepcopy(self.foundation.taxonomy)
            lats = next(
                muscle
                for muscle in taxonomy["muscles"]
                if muscle["id"] == "lats"
            )
            lats["meshBaseNames"] = [mesh_base]
            with self.subTest(mesh_base=mesh_base), self.assertRaisesRegex(
                catalog.ValidationFailure,
                f"non-trainable mesh base {mesh_base} must not be owned",
            ):
                catalog.validate_taxonomy(taxonomy)

    def test_every_declared_non_trainable_scene_node_must_exist(self) -> None:
        actual_scene_strings = catalog.scene_strings(catalog.BODY_MODEL_PATH)
        for mesh_base in sorted(catalog.NON_TRAINABLE_MESH_BASES):
            for suffix in ("L", "R"):
                missing_node = f"{mesh_base}_{suffix}"
                mutated_scene_strings = actual_scene_strings - {missing_node}
                with (
                    self.subTest(node=missing_node),
                    mock.patch.object(
                        catalog,
                        "scene_strings",
                        return_value=mutated_scene_strings,
                    ),
                    self.assertRaisesRegex(
                        catalog.ValidationFailure,
                        f"declared non-trainable BodyModel.scn node is missing: "
                        f"{missing_node}",
                    ),
                ):
                    catalog.validate_taxonomy(
                        copy.deepcopy(self.foundation.taxonomy)
                    )

    def test_evidence_canonical_identifier_routes_accept_each_supported_form(
        self,
    ) -> None:
        sources = (
            self.evidence_source(
                "doi-source",
                doi="10.1234/doi-source",
                pmid="123456",
                pmcid="PMC123456",
                url="https://doi.org/10.1234/doi-source",
            ),
            self.evidence_source(
                "pmcid-source",
                pmid="234567",
                pmcid="PMC234567",
                url="https://pmc.ncbi.nlm.nih.gov/articles/PMC234567/",
            ),
            self.evidence_source(
                "pmid-source",
                pmid="345678",
                url="https://pubmed.ncbi.nlm.nih.gov/345678/",
            ),
        )
        self.assertEqual(
            catalog.validate_evidence(self.evidence_registry(*sources)),
            {"doi-source", "pmcid-source", "pmid-source"},
        )

    def test_konrad_pmcid_and_pmid_pass_without_a_doi(self) -> None:
        konrad = next(
            source
            for source in self.foundation.evidence["sources"]
            if source["id"] == "konrad-2001-trunk-training"
        )
        self.assertNotIn("doi", konrad)
        self.assertEqual(konrad["pmid"], "12937449")
        self.assertEqual(konrad["pmcid"], "PMC155519")
        self.assertEqual(
            konrad["url"],
            "https://pmc.ncbi.nlm.nih.gov/articles/PMC155519/",
        )
        self.assertEqual(
            catalog.validate_evidence(
                self.evidence_registry(copy.deepcopy(konrad))
            ),
            {"konrad-2001-trunk-training"},
        )

    def test_evidence_requires_at_least_one_canonical_identifier(self) -> None:
        source = self.evidence_source(
            "missing-identifier",
            url="https://example.com/no-identifier",
        )
        with self.assertRaisesRegex(
            catalog.ValidationFailure,
            "must declare at least one canonical identifier",
        ):
            catalog.validate_evidence(self.evidence_registry(source))

    def test_evidence_identifier_formats_are_strict(self) -> None:
        mutations = (
            (
                "empty-doi",
                self.evidence_source(
                    "empty-doi",
                    doi="",
                    url="https://doi.org/",
                ),
                r"doi must be a non-empty string",
            ),
            (
                "zero-pmid",
                self.evidence_source(
                    "zero-pmid",
                    pmid="0",
                    url="https://pubmed.ncbi.nlm.nih.gov/0/",
                ),
                "pmid must use canonical non-zero digits",
            ),
            (
                "leading-zero-pmid",
                self.evidence_source(
                    "leading-zero-pmid",
                    pmid="012345",
                    url="https://pubmed.ncbi.nlm.nih.gov/012345/",
                ),
                "pmid must use canonical non-zero digits",
            ),
            (
                "non-ascii-pmid",
                self.evidence_source(
                    "non-ascii-pmid",
                    pmid="１２３４５",
                    url="https://pubmed.ncbi.nlm.nih.gov/１２３４５/",
                ),
                "pmid must use canonical non-zero digits",
            ),
            (
                "zero-pmcid",
                self.evidence_source(
                    "zero-pmcid",
                    pmcid="PMC0",
                    url="https://pmc.ncbi.nlm.nih.gov/articles/PMC0/",
                ),
                "pmcid must use the canonical PMC plus digits form",
            ),
            (
                "lowercase-pmcid",
                self.evidence_source(
                    "lowercase-pmcid",
                    pmcid="pmc155519",
                    url="https://pmc.ncbi.nlm.nih.gov/articles/pmc155519/",
                ),
                "pmcid must use the canonical PMC plus digits form",
            ),
        )
        for label, source, message in mutations:
            with self.subTest(mutation=label), self.assertRaisesRegex(
                catalog.ValidationFailure,
                message,
            ):
                catalog.validate_evidence(self.evidence_registry(source))

    def test_evidence_url_must_match_highest_priority_identifier(self) -> None:
        mutations = (
            self.evidence_source(
                "doi-priority",
                doi="10.1234/doi-priority",
                pmid="123456",
                pmcid="PMC123456",
                url="https://pmc.ncbi.nlm.nih.gov/articles/PMC123456/",
            ),
            self.evidence_source(
                "pmcid-priority",
                pmid="234567",
                pmcid="PMC234567",
                url="https://pubmed.ncbi.nlm.nih.gov/234567/",
            ),
            self.evidence_source(
                "pmid-priority",
                pmid="345678",
                url="https://example.com/345678",
            ),
        )
        for source in mutations:
            with self.subTest(source=source["id"]), self.assertRaisesRegex(
                catalog.ValidationFailure,
                "url must match its highest-priority canonical identifier",
            ):
                catalog.validate_evidence(self.evidence_registry(source))

    def test_evidence_rejects_duplicate_canonical_identifiers(self) -> None:
        duplicate_sources = {
            "doi": (
                self.evidence_source(
                    "first-doi",
                    doi="10.1234/Duplicate",
                    url="https://doi.org/10.1234/Duplicate",
                ),
                self.evidence_source(
                    "second-doi",
                    doi="10.1234/duplicate",
                    url="https://doi.org/10.1234/duplicate",
                ),
            ),
            "pmid": (
                self.evidence_source(
                    "first-pmid",
                    pmid="123456",
                    url="https://pubmed.ncbi.nlm.nih.gov/123456/",
                ),
                self.evidence_source(
                    "second-pmid",
                    pmid="123456",
                    url="https://pubmed.ncbi.nlm.nih.gov/123456/",
                ),
            ),
            "pmcid": (
                self.evidence_source(
                    "first-pmcid",
                    pmcid="PMC123456",
                    url="https://pmc.ncbi.nlm.nih.gov/articles/PMC123456/",
                ),
                self.evidence_source(
                    "second-pmcid",
                    pmcid="PMC123456",
                    url="https://pmc.ncbi.nlm.nih.gov/articles/PMC123456/",
                ),
            ),
        }
        for identifier, sources in duplicate_sources.items():
            with self.subTest(identifier=identifier), self.assertRaisesRegex(
                catalog.ValidationFailure,
                f"{identifier} duplicates canonical identifier owned by",
            ):
                catalog.validate_evidence(self.evidence_registry(*sources))

    def test_distal_taxonomy_replaces_both_aggregate_regions_exactly(self) -> None:
        distal_ids = {
            "bicepsBrachii",
            "brachialis",
            "brachioradialis",
            "forearmPronators",
            "supinator",
            "flexorCarpiRadialis",
            "flexorCarpiUlnaris",
            "extensorCarpiRadialis",
            "extensorCarpiUlnaris",
            "fingerFlexors",
            "fingerExtensors",
        }
        self.assertTrue(distal_ids <= set(self.foundation.muscle_by_id))
        self.assertTrue(
            {"biceps", "forearms"}.isdisjoint(self.foundation.muscle_by_id)
        )

    def test_lower_body_taxonomy_replaces_six_false_action_unions_exactly(self) -> None:
        expected_meshes = {
            "rectusFemoris": ["Rectus_Femoris"],
            "vasti": [
                "Vastus_Lateralis",
                "Vastus_Medialis",
                "Vastus_Intermedius",
            ],
            "bicepsFemoris": ["Biceps_femoris"],
            "medialHamstrings": ["Semitendinosus", "Semimembranosus"],
            "gastrocnemius": ["Gastrocnemius"],
            "soleus": ["Soleus"],
            "flexorHallucisLongus": ["Flexor_Hallucis_Longus"],
            "adductorMagnus": ["Adductor_Mangus"],
            "adductorLongusBrevis": ["Adductor_Longus", "Adductor_Brevis"],
            "gracilis": ["Gracilis"],
            "pectineus": ["Pectineus"],
            "iliopsoas": ["Psoas_Major", "Iliacus"],
            "sartorius": ["Sartorius"],
            "tibialisAnterior": ["Tibialis_Anterior"],
            "fibularisLongusBrevis": ["Peroneus_Longus", "Peroneus_Brevis"],
            "fibularisTertius": ["Peroneus_Tertius"],
            "toeExtensors": [
                "Extensor_Digitorum_Longus",
                "Extensor_Hallucis_Longus",
            ],
        }
        for muscle_id, meshes in expected_meshes.items():
            with self.subTest(muscle=muscle_id):
                self.assertEqual(
                    self.foundation.muscle_by_id[muscle_id]["meshBaseNames"],
                    meshes,
                )

        retired = {
            "quads",
            "hamstrings",
            "calves",
            "adductors",
            "hipFlexors",
            "shins",
        }
        self.assertTrue(retired.isdisjoint(self.foundation.muscle_by_id))

        expected_plain_anatomical_names = {
            "bicepsFemoris": "Biceps Femoris",
            "gluteMed": "Gluteus Medius",
            "adductorMagnus": "Adductor Magnus",
        }
        for muscle_id, expected_name in expected_plain_anatomical_names.items():
            with self.subTest(anatomical_name=muscle_id):
                self.assertEqual(
                    self.foundation.muscle_by_id[muscle_id]["anatomicalName"],
                    expected_name,
                )

    def test_lower_body_capabilities_do_not_leak_between_split_regions(self) -> None:
        capabilities = self.foundation.capabilities_by_muscle
        expected = {
            "rectusFemoris": {"hip.flexion", "knee.extension"},
            "vasti": {"knee.extension"},
            "bicepsFemoris": {"knee.flexion"},
            "medialHamstrings": {"hip.extension", "knee.flexion"},
            "gastrocnemius": {"knee.flexion", "ankle.plantarflexion"},
            "soleus": {"ankle.plantarflexion"},
            "flexorHallucisLongus": {
                "ankle.plantarflexion",
                "foot.toeFlexion",
            },
            "adductorMagnus": {"hip.adduction"},
            "adductorLongusBrevis": {"hip.adduction"},
            "gracilis": {"hip.adduction", "knee.flexion"},
            "pectineus": {"hip.adduction"},
            "iliopsoas": {"hip.flexion"},
            "sartorius": {
                "hip.flexion",
                "hip.abduction",
                "hip.externalRotation",
                "knee.flexion",
            },
            "tibialisAnterior": {"ankle.dorsiflexion", "ankle.inversion"},
            "fibularisLongusBrevis": {
                "ankle.plantarflexion",
                "ankle.eversion",
            },
            "fibularisTertius": {"ankle.dorsiflexion", "ankle.eversion"},
            "toeExtensors": {"ankle.dorsiflexion", "foot.toeExtension"},
        }
        for muscle_id, actions in expected.items():
            with self.subTest(muscle=muscle_id):
                self.assertEqual(
                    capabilities[muscle_id],
                    frozenset((action, None) for action in actions),
                )

        self.assertEqual(
            capabilities["gluteMed"],
            frozenset(
                {
                    ("hip.abduction", None),
                    ("hip.internalRotation", "atNinetyDegreeHipFlexion"),
                }
            ),
        )
        for muscle_id in ("adductorLongusBrevis", "pectineus"):
            with self.subTest(position_condition=muscle_id):
                self.assertIn(
                    "hip-position condition",
                    self.foundation.profile_by_muscle[muscle_id]["notes"],
                )

        roadmap = (catalog.SPEC_ROOT / "family-roadmap.md").read_text(
            encoding="utf-8"
        )
        self.assertIn(
            "Whole gluteus maximus retains external rotation\n"
            "only at neutral flexion and is not copied into the 30-degree family",
            roadmap,
        )
        self.assertIn(
            "only at neutral hip flexion",
            self.foundation.profile_by_muscle["gluteMax"]["notes"],
        )
        self.assertIn(
            "only at the active family’s exact 90-degree posture",
            self.foundation.profile_by_muscle[
                "tensorFasciaeLatae"
            ]["notes"],
        )
        self.assertIn(
            "only currently authored toe-flexion producer",
            self.foundation.profile_by_muscle[
                "flexorHallucisLongus"
            ]["notes"],
        )
        self.assertIn("Generic `foot.toeFlexion` remains", roadmap)

    def test_hip_rotation_conditions_and_capabilities_are_exact(self) -> None:
        conditions = {
            item["id"]: item
            for item in self.foundation.joint_actions["actionConditions"]
        }
        self.assertEqual(
            {
                condition_id: conditions[condition_id]
                for condition_id in {
                    "atNeutralHipFlexion",
                    "atThirtyDegreeHipFlexion",
                    "atNinetyDegreeHipFlexion",
                }
            },
            {
                "atNeutralHipFlexion": {
                    "id": "atNeutralHipFlexion",
                    "displayName": "At neutral hip flexion",
                    "definition": (
                        "The hip is held at zero degrees of flexion while the "
                        "reviewed rotation action is produced."
                    ),
                    "appliesTo": ["hip.externalRotation"],
                    "variantConstraint": {
                        "axis": "hipFlexionDegrees",
                        "equals": 0,
                    },
                },
                "atThirtyDegreeHipFlexion": {
                    "id": "atThirtyDegreeHipFlexion",
                    "displayName": "At thirty degrees of hip flexion",
                    "definition": (
                        "The hip is supported at exactly thirty degrees of "
                        "flexion while the reviewed rotation action is produced."
                    ),
                    "appliesTo": ["hip.externalRotation"],
                    "variantConstraint": {
                        "axis": "hipFlexionDegrees",
                        "equals": 30,
                    },
                },
                "atNinetyDegreeHipFlexion": {
                    "id": "atNinetyDegreeHipFlexion",
                    "displayName": "At ninety degrees of hip flexion",
                    "definition": (
                        "The hip is held at exactly ninety degrees of flexion "
                        "while the reviewed rotation action is produced."
                    ),
                    "appliesTo": ["hip.internalRotation"],
                    "variantConstraint": {
                        "axis": "hipFlexionDegrees",
                        "equals": 90,
                    },
                },
            },
        )
        self.assertEqual(
            self.foundation.condition_variant_constraints,
            {
                "atNeutralHipFlexion": ("hipFlexionDegrees", 0),
                "atThirtyDegreeHipFlexion": ("hipFlexionDegrees", 30),
                "atNinetyDegreeHipFlexion": ("hipFlexionDegrees", 90),
            },
        )

        capabilities = self.foundation.capabilities_by_muscle
        internal = ("hip.internalRotation", "atNinetyDegreeHipFlexion")
        external = ("hip.externalRotation", "atThirtyDegreeHipFlexion")
        for muscle_id in ("gluteMed", "tensorFasciaeLatae", "gluteMin"):
            with self.subTest(muscle=muscle_id, action="internal"):
                self.assertIn(internal, capabilities[muscle_id])
                for condition in (None, "atNeutralHipFlexion", "atThirtyDegreeHipFlexion"):
                    self.assertNotIn(
                        ("hip.internalRotation", condition),
                        capabilities[muscle_id],
                    )

        self.assertIn(
            ("hip.externalRotation", "atNeutralHipFlexion"),
            capabilities["gluteMax"],
        )
        for condition in (None, "atThirtyDegreeHipFlexion", "atNinetyDegreeHipFlexion"):
            self.assertNotIn(
                ("hip.externalRotation", condition),
                capabilities["gluteMax"],
            )

        external_units = {
            "piriformis",
            "obturatorInternusGemelli",
            "obturatorExternus",
            "quadratusFemoris",
        }
        for muscle_id in external_units:
            with self.subTest(muscle=muscle_id, action="external"):
                self.assertIn(external, capabilities[muscle_id])
                for condition in (None, "atNeutralHipFlexion", "atNinetyDegreeHipFlexion"):
                    self.assertNotIn(
                        ("hip.externalRotation", condition),
                        capabilities[muscle_id],
                    )

    def test_hip_rotation_variant_constraint_schema_is_mutation_guarded(
        self,
    ) -> None:
        mutations = (
            ("not-object", [], r"variantConstraint must be an object"),
            (
                "missing-axis",
                {"equals": 90},
                r"variantConstraint is missing keys: axis",
            ),
            (
                "unknown-key",
                {"axis": "hipFlexionDegrees", "equals": 90, "units": "degrees"},
                r"variantConstraint has unknown keys: units",
            ),
            (
                "invalid-axis",
                {"axis": "hip.flexionDegrees", "equals": 90},
                r"variantConstraint\.axis is not a stable symbol ID",
            ),
            (
                "empty-equals",
                {"axis": "hipFlexionDegrees", "equals": ""},
                r"variantConstraint\.equals must be a non-empty scalar",
            ),
        )
        for label, constraint, message in mutations:
            actions = copy.deepcopy(self.foundation.joint_actions)
            condition = next(
                item
                for item in actions["actionConditions"]
                if item["id"] == "atNinetyDegreeHipFlexion"
            )
            condition["variantConstraint"] = constraint
            with self.subTest(mutation=label), self.assertRaisesRegex(
                catalog.ValidationFailure,
                message,
            ):
                catalog.validate_joint_actions(
                    actions,
                    set(self.foundation.muscle_by_id),
                    self.foundation.evidence_ids,
                )

    def test_hip_rotation_condition_requires_the_pinned_exercise_variant(
        self,
    ) -> None:
        for family_id, expected in (
            ("hip-internal-rotation", 90),
            ("hip-external-rotation", 30),
        ):
            original = self.batch6_families[family_id]
            condition = original["movementSignature"]["primeActions"][0][
                "condition"
            ]
            with self.subTest(family=family_id, mutation="missing-axis"):
                family = copy.deepcopy(original)
                family["variantAxes"] = [
                    axis
                    for axis in family["variantAxes"]
                    if axis["id"] != "hipFlexionDegrees"
                ]
                family["exercises"][0]["variant"].pop("hipFlexionDegrees")
                self.assert_batch6_family_fails(
                    family,
                    f"action condition {condition} requires variant axis hipFlexionDegrees",
                )

            with self.subTest(family=family_id, mutation="optional-axis"):
                family = copy.deepcopy(original)
                next(
                    axis
                    for axis in family["variantAxes"]
                    if axis["id"] == "hipFlexionDegrees"
                )["required"] = False
                self.assert_batch6_family_fails(
                    family,
                    f"action condition {condition} requires hipFlexionDegrees to be required",
                )

            with self.subTest(family=family_id, mutation="unpinned-axis"):
                family = copy.deepcopy(original)
                axis = next(
                    axis
                    for axis in family["variantAxes"]
                    if axis["id"] == "hipFlexionDegrees"
                )
                axis["minimum"] = expected - 1
                self.assert_batch6_family_fails(
                    family,
                    f"requires numeric axis hipFlexionDegrees pinned to {expected}",
                )

            with self.subTest(family=family_id, mutation="wrong-record-value"):
                family = copy.deepcopy(original)
                family["exercises"][0]["variant"]["hipFlexionDegrees"] = (
                    expected - 1
                )
                self.assert_batch6_family_fails(
                    family,
                    rf"requires variant\.hipFlexionDegrees == {expected}",
                )

    def test_rotation_families_reject_bare_and_wrong_posture_actions(self) -> None:
        for family_id, action, wrong_condition in (
            (
                "hip-internal-rotation",
                "hip.internalRotation",
                "atThirtyDegreeHipFlexion",
            ),
            (
                "hip-external-rotation",
                "hip.externalRotation",
                "atNinetyDegreeHipFlexion",
            ),
        ):
            original = self.batch6_families[family_id]
            family = copy.deepcopy(original)
            family["movementSignature"]["primeActions"] = [action]
            with self.subTest(family=family_id, mutation="bare"):
                self.assert_batch6_family_fails(
                    family,
                    f"no primary/secondary muscle capable of {re.escape(action)}",
                )

            family = copy.deepcopy(original)
            family["movementSignature"]["primeActions"][0][
                "condition"
            ] = wrong_condition
            with self.subTest(family=family_id, mutation="wrong-posture"):
                self.assert_batch6_family_fails(
                    family,
                    f"condition {wrong_condition} does not apply to {re.escape(action)}",
                )

        external = copy.deepcopy(
            self.batch6_families["hip-external-rotation"]
        )
        external["movementSignature"]["primeActions"][0][
            "condition"
        ] = "atNeutralHipFlexion"
        hip_flexion_axis = next(
            axis
            for axis in external["variantAxes"]
            if axis["id"] == "hipFlexionDegrees"
        )
        hip_flexion_axis["minimum"] = 0
        hip_flexion_axis["maximum"] = 0
        external["exercises"][0]["variant"]["hipFlexionDegrees"] = 0
        with self.subTest(
            family="hip-external-rotation",
            mutation="coordinated-neutral-posture",
        ):
            self.assert_batch6_family_fails(
                external,
                r"no primary/secondary muscle capable of hip\.externalRotation",
            )

    def test_distal_unvisualized_regions_carry_exact_scene_reasons(self) -> None:
        expected_reasons = {
            "forearmPronators": (
                "BodyModel.scn has no pronator-teres or "
                "pronator-quadratus surface mesh."
            ),
            "supinator": "BodyModel.scn has no supinator surface mesh.",
        }
        for muscle_id, reason in expected_reasons.items():
            with self.subTest(muscle=muscle_id):
                muscle = self.foundation.muscle_by_id[muscle_id]
                self.assertEqual(muscle["meshBaseNames"], [])
                self.assertEqual(muscle["unvisualizedReason"], reason)

    def test_finger_actions_replace_the_generic_grip_task(self) -> None:
        self.assertEqual(
            len(self.foundation.action_ids),
            catalog.EXPECTED_ACTION_COUNT,
        )
        self.assertNotIn("hand.grip", self.foundation.action_ids)
        self.assertTrue(
            {"hand.fingerFlexion", "hand.fingerExtension"}
            <= self.foundation.action_ids
        )

    def test_brachioradialis_position_conditions_are_exact(self) -> None:
        self.assertEqual(
            self.foundation.condition_actions["fromSupinatedPosition"],
            frozenset({"forearm.pronation"}),
        )
        self.assertEqual(
            self.foundation.condition_actions["fromPronatedPosition"],
            frozenset({"forearm.supination"}),
        )
        capabilities = self.foundation.capabilities_by_muscle[
            "brachioradialis"
        ]
        self.assertIn(
            ("forearm.pronation", "fromSupinatedPosition"),
            capabilities,
        )
        self.assertIn(
            ("forearm.supination", "fromPronatedPosition"),
            capabilities,
        )
        self.assertNotIn(("forearm.pronation", None), capabilities)
        self.assertNotIn(("forearm.supination", None), capabilities)

    def test_distal_capability_antagonists_are_bounded(self) -> None:
        capabilities = self.foundation.capabilities_by_muscle
        expected = {
            "bicepsBrachii": {
                ("elbow.flexion", None),
                ("forearm.supination", None),
            },
            "brachialis": {("elbow.flexion", None)},
            "brachioradialis": {("elbow.flexion", None)},
            "forearmPronators": {("forearm.pronation", None)},
            "supinator": {("forearm.supination", None)},
            "flexorCarpiRadialis": {
                ("wrist.flexion", None),
                ("wrist.radialDeviation", None),
            },
            "flexorCarpiUlnaris": {
                ("wrist.flexion", None),
                ("wrist.ulnarDeviation", None),
            },
            "extensorCarpiRadialis": {
                ("wrist.extension", None),
                ("wrist.radialDeviation", None),
            },
            "extensorCarpiUlnaris": {
                ("wrist.extension", None),
                ("wrist.ulnarDeviation", None),
            },
            "fingerFlexors": {
                ("wrist.flexion", None),
                ("hand.fingerFlexion", None),
            },
            "fingerExtensors": {
                ("wrist.extension", None),
                ("hand.fingerExtension", None),
            },
        }
        for muscle_id, required in expected.items():
            with self.subTest(muscle=muscle_id):
                self.assertTrue(required <= capabilities[muscle_id])

        excluded = {
            "brachialis": {("forearm.supination", None)},
            "brachioradialis": {
                ("forearm.pronation", None),
                ("forearm.supination", None),
            },
            "flexorCarpiRadialis": {("wrist.ulnarDeviation", None)},
            "flexorCarpiUlnaris": {("wrist.radialDeviation", None)},
            "extensorCarpiRadialis": {("wrist.ulnarDeviation", None)},
            "extensorCarpiUlnaris": {("wrist.radialDeviation", None)},
            "fingerExtensors": {("hand.fingerFlexion", None)},
        }
        for muscle_id, forbidden in excluded.items():
            with self.subTest(muscle=muscle_id):
                self.assertTrue(forbidden.isdisjoint(capabilities[muscle_id]))

    def test_each_new_position_condition_is_structurally_load_bearing(self) -> None:
        cases = (
            (
                "fromSupinatedPosition",
                "forearm.pronation",
                "forearm.supination",
            ),
            (
                "fromPronatedPosition",
                "forearm.supination",
                "forearm.pronation",
            ),
        )
        for condition, action, opposite_action in cases:
            with self.subTest(condition=condition, mutation="delete"):
                actions = copy.deepcopy(self.foundation.joint_actions)
                profile = next(
                    item
                    for item in actions["muscleProfiles"]
                    if item["muscleID"] == "brachioradialis"
                )
                capability = next(
                    item
                    for item in profile["produces"]
                    if isinstance(item, dict)
                    and item["condition"] == condition
                )
                capability.pop("condition")
                with self.assertRaisesRegex(
                    catalog.ValidationFailure,
                    "is missing keys: condition",
                ):
                    catalog.validate_joint_actions(
                        actions,
                        set(self.foundation.muscle_by_id),
                        self.foundation.evidence_ids,
                    )

            with self.subTest(condition=condition, mutation="opposite action"):
                actions = copy.deepcopy(self.foundation.joint_actions)
                profile = next(
                    item
                    for item in actions["muscleProfiles"]
                    if item["muscleID"] == "brachioradialis"
                )
                capability = next(
                    item
                    for item in profile["produces"]
                    if isinstance(item, dict)
                    and item["condition"] == condition
                )
                capability["action"] = opposite_action
                with self.assertRaisesRegex(
                    catalog.ValidationFailure,
                    f"condition {condition} does not apply to {opposite_action}",
                ):
                    catalog.validate_joint_actions(
                        actions,
                        set(self.foundation.muscle_by_id),
                        self.foundation.evidence_ids,
                    )

            conditional = (action, condition)
            self.assertTrue(
                catalog.capability_satisfies(
                    conditional,
                    conditional,
                )
            )
            self.assertFalse(
                catalog.capability_satisfies(
                    conditional,
                    (action, None),
                )
            )

    def test_distal_evidence_registry_is_complete_and_bounded(self) -> None:
        source_by_id = {
            source["id"]: source
            for source in self.foundation.evidence["sources"]
        }
        expected_scope_phrases = {
            "murray-1995-elbow-forearm-moment-arms": (
                "does not establish exercise-level activation"
            ),
            "bremer-2006-forearm-rotator-moment-arms": (
                "not in-vivo exercise roles"
            ),
            "boland-2008-brachioradialis-function": (
                "not unconditional full-range pronation or supination"
            ),
            "gordon-2004-forearm-rotation-emg": (
                "not dynamic exercise trajectories"
            ),
            "garland-2018-wrist-tendon-moment-arms": (
                "categorical wrist actions"
            ),
            "nichols-2015-wrist-muscle-moment-arms": (
                "do not define healthy exercise contribution magnitudes"
            ),
            "an-1983-index-finger-moment-arms": (
                "not whole-hand grip tasks"
            ),
            "mirakhorlo-2018-hand-wrist-model": (
                "not population-level force estimates"
            ),
            "ferrer-uris-2023-finger-dead-hangs": (
                "does not by itself admit a dynamic gripper"
            ),
        }
        for source_id, phrase in expected_scope_phrases.items():
            with self.subTest(source=source_id):
                self.assertIn(source_id, source_by_id)
                self.assertIn(phrase, source_by_id[source_id]["scope"])

    def test_distal_migration_removes_retired_ids_from_every_active_source(
        self,
    ) -> None:
        def strings(value: object) -> set[str]:
            if isinstance(value, dict):
                return {
                    item
                    for nested in value.values()
                    for item in strings(nested)
                }
            if isinstance(value, list):
                return {
                    item
                    for nested in value
                    for item in strings(nested)
                }
            return {value} if isinstance(value, str) else set()

        for source in [self.valid_family, *self.real_families]:
            with self.subTest(source=source["id"]):
                self.assertTrue(
                    {"biceps", "forearms"}.isdisjoint(strings(source))
                )

    def test_distal_migration_assigns_explicit_hand_and_wrist_stabilizers(
        self,
    ) -> None:
        affected_ids = {
            "vertical-pull",
            "shoulder-extension-row",
            "shoulder-horizontal-abduction-row",
            "shoulder-extension-isolation",
            "shoulder-flexion-raise",
            "shoulder-abduction-raise",
            "chest-fly",
            "reverse-fly",
        }
        affected = {
            family["id"]: family
            for family in self.real_families
            if family["id"] in affected_ids
        }
        self.assertEqual(set(affected), affected_ids)
        for family_id, family in affected.items():
            self.assertTrue(
                {"wrist", "hand"}
                <= set(family["movementSignature"]["stabilityDemands"])
            )
            for exercise in family["exercises"]:
                roles = {
                    assignment["muscle"]: assignment["role"]
                    for assignment in exercise["involvement"]
                }
                with self.subTest(
                    family=family_id,
                    exercise=exercise["catalogID"],
                ):
                    self.assertEqual(roles["fingerFlexors"], "stabilizer")
                    self.assertEqual(
                        roles["extensorCarpiRadialis"],
                        "stabilizer",
                    )

    def test_dynamic_elbow_flexion_families_assign_all_three_flexors(self) -> None:
        family_ids = {
            "vertical-pull",
            "shoulder-extension-row",
            "shoulder-horizontal-abduction-row",
        }
        for family in self.real_families:
            if family["id"] not in family_ids:
                continue
            self.assertIn(
                "elbow.flexion",
                family["movementSignature"]["primeActions"],
            )
            for exercise in family["exercises"]:
                roles = {
                    assignment["muscle"]: assignment["role"]
                    for assignment in exercise["involvement"]
                }
                for muscle_id in (
                    "bicepsBrachii",
                    "brachialis",
                    "brachioradialis",
                ):
                    with self.subTest(
                        family=family["id"],
                        exercise=exercise["catalogID"],
                        muscle=muscle_id,
                    ):
                        self.assertEqual(roles[muscle_id], "secondary")

    def test_held_elbow_reverse_fly_uses_brachialis_stabilization(self) -> None:
        family = self.batch1_families["reverse-fly"]
        self.assertNotIn("elbow.flexion", family["movementSignature"]["primeActions"])
        for exercise in family["exercises"]:
            roles = {
                assignment["muscle"]: assignment["role"]
                for assignment in exercise["involvement"]
            }
            with self.subTest(exercise=exercise["catalogID"]):
                self.assertEqual(roles["brachialis"], "stabilizer")
                self.assertNotIn("bicepsBrachii", roles)
                self.assertNotIn("brachioradialis", roles)

    def test_distal_migration_requirements_reject_missing_assignments(
        self,
    ) -> None:
        affected_ids = {
            "vertical-pull",
            "shoulder-extension-row",
            "shoulder-horizontal-abduction-row",
            "shoulder-extension-isolation",
            "shoulder-flexion-raise",
            "shoulder-abduction-raise",
            "chest-fly",
            "reverse-fly",
        }
        for original in self.real_families:
            if original["id"] not in affected_ids:
                continue
            for muscle_id in ("fingerFlexors", "extensorCarpiRadialis"):
                family = copy.deepcopy(original)
                family["exercises"][0]["involvement"] = [
                    assignment
                    for assignment in family["exercises"][0]["involvement"]
                    if assignment["muscle"] != muscle_id
                ]
                with self.subTest(family=family["id"], muscle=muscle_id):
                    with self.assertRaisesRegex(
                        catalog.ValidationFailure,
                        "fails muscle requirement",
                    ):
                        catalog.validate_family(
                            family,
                            self.foundation,
                            f"mutated {family['id']}",
                        )

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
        for muscle_id, expected_meshes in catalog.EXPECTED_SPLIT_MESHES.items():
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

    def test_sternocostal_sagittal_actions_are_position_conditioned(self) -> None:
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
        self.assertEqual(
            self.foundation.condition_actions["fromExtendedPosition"],
            frozenset({"shoulder.flexion"}),
        )
        self.assertIn(
            {
                "action": "shoulder.flexion",
                "condition": "fromExtendedPosition",
            },
            profile["produces"],
        )
        self.assertIn(
            ("shoulder.flexion", "fromExtendedPosition"),
            capabilities,
        )
        self.assertNotIn(("shoulder.flexion", None), capabilities)

    def test_valid_family_fixture_passes_without_warnings(self) -> None:
        family = self.family_copy()
        self.assertNotIn(
            "resistedActions",
            family["movementSignature"],
        )
        warnings = catalog.validate_family(
            family,
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
        warnings = catalog.validate_family(
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

    def test_late_lower_body_closure_forbids_every_other_prime_action(
        self,
    ) -> None:
        mutation_count = 0
        for family_id, original in (
            self.late_lower_body_closure_families.items()
        ):
            own_actions = set(
                original["movementSignature"]["primeActions"]
            )
            expected_forbidden = set(self.foundation.action_ids) - own_actions
            self.assertEqual(
                set(
                    original["movementSignature"]["forbiddenPrimeActions"]
                ),
                expected_forbidden,
            )
            for action in expected_forbidden:
                family = copy.deepcopy(original)
                family["exercises"][0]["additionalPrimeActions"] = [action]
                with self.subTest(family=family_id, action=action):
                    self.assert_late_lower_body_closure_fails(
                        family,
                        f"declares forbidden prime action {re.escape(action)}",
                    )
                mutation_count += 1
        self.assertEqual(mutation_count, 126)

    def test_dynamic_lunge_rules_bind_each_discrete_topology_directly(
        self,
    ) -> None:
        original = self.late_lower_body_closure_families["dynamic-lunge"]
        expected = [
            {
                "id": "forward-step-binds-selected-lead-landing-topology",
                "description": (
                    "A selected-lead forward step requires the exact "
                    "lead-foot landing and return topology from Comfort et al."
                ),
                "when": {
                    "field": "variant.stepDirection",
                    "operator": "equals",
                    "value": "selectedLeadForward",
                },
                "then": [
                    {
                        "field": "variant.selectedLeadFootTransition",
                        "value": "stepsForwardThenReturns",
                    },
                    {
                        "field": "variant.contralateralFootTransition",
                        "value": "remainsAtStartThenReceivesReturn",
                    },
                    {
                        "field": "variant.landingFoot",
                        "value": "selectedLead",
                    },
                    {
                        "field": "variant.selectedLeadFootContact",
                        "value": "stepsThenWholeFootMaintained",
                    },
                ],
                "requirePresent": [],
                "requireAbsent": [],
            },
            {
                "id": "reverse-step-binds-planted-front-foot-topology",
                "description": (
                    "A contralateral rearward step requires the selected front "
                    "foot to remain planted while the rear foot lands and "
                    "returns."
                ),
                "when": {
                    "field": "variant.stepDirection",
                    "operator": "equals",
                    "value": "contralateralRearward",
                },
                "then": [
                    {
                        "field": "variant.selectedLeadFootTransition",
                        "value": "remainsPlantedThroughout",
                    },
                    {
                        "field": "variant.contralateralFootTransition",
                        "value": "stepsRearwardThenReturns",
                    },
                    {
                        "field": "variant.landingFoot",
                        "value": "contralateral",
                    },
                    {
                        "field": "variant.selectedLeadFootContact",
                        "value": "maintainedOnStartPlate",
                    },
                ],
                "requirePresent": [],
                "requireAbsent": [],
            },
        ]
        self.assertEqual(original["exerciseRules"], expected)

        mutation_count = 0
        for rule in original["exerciseRules"]:
            matches = [
                exercise
                for exercise in original["exercises"]
                if self.rule_matches_exercise(rule, exercise)
            ]
            self.assertEqual(len(matches), 1)
            self.assertEqual(
                sum(
                    not self.rule_matches_exercise(rule, exercise)
                    for exercise in original["exercises"]
                ),
                1,
            )
            for assertion in rule["then"]:
                mutated = copy.deepcopy(matches[0])
                self.set_rule_field(
                    mutated,
                    assertion["field"],
                    "mutated",
                )
                with self.subTest(
                    rule=rule["id"],
                    field=assertion["field"],
                ):
                    with self.assertRaisesRegex(
                        catalog.ValidationFailure,
                        "violates exercise rule " + re.escape(rule["id"]),
                    ):
                        catalog.validate_exercise_rule_matches(
                            mutated,
                            [rule],
                            "mutated dynamic-lunge topology",
                        )
                mutation_count += 1
        self.assertEqual(mutation_count, 8)

    def test_late_lower_body_required_roles_are_removed_and_demoted_directly(
        self,
    ) -> None:
        removal_count = 0
        demotion_count = 0
        lower_role = {"primary": "secondary", "secondary": "stabilizer"}
        for family_id, original in (
            self.late_lower_body_closure_families.items()
        ):
            for exercise_index, exercise in enumerate(original["exercises"]):
                roles = {
                    item["muscle"]: item["role"]
                    for item in exercise["involvement"]
                }
                for requirement_index, requirement in enumerate(
                    original["musclePolicy"]["requirements"]
                ):
                    family = copy.deepcopy(original)
                    family["exercises"][exercise_index]["involvement"] = [
                        item
                        for item in family["exercises"][exercise_index][
                            "involvement"
                        ]
                        if item["muscle"] not in requirement["anyOf"]
                    ]
                    with self.subTest(
                        family=family_id,
                        exercise=exercise["catalogID"],
                        requirement=requirement_index,
                        mutation="remove",
                    ):
                        self.assert_late_lower_body_closure_fails(
                            family,
                            (
                                f"fails muscle requirement {requirement_index}"
                                "|requires at least one primary muscle"
                                "|no assigned muscle capable of stabilizing"
                            ),
                        )
                    removal_count += 1

                    minimum_role = requirement["minimumRole"]
                    if minimum_role == "stabilizer":
                        continue
                    candidate = next(
                        muscle_id
                        for muscle_id in requirement["anyOf"]
                        if muscle_id in roles
                    )
                    family = copy.deepcopy(original)
                    target = family["exercises"][exercise_index]
                    demoted_role = lower_role[minimum_role]
                    family["musclePolicy"]["allowedByRole"][
                        demoted_role
                    ].append(candidate)
                    next(
                        item
                        for item in target["involvement"]
                        if item["muscle"] == candidate
                    )["role"] = demoted_role
                    if not any(
                        item["role"] == "primary"
                        for item in target["involvement"]
                    ):
                        substitute = next(
                            item
                            for item in target["involvement"]
                            if item["role"] == "secondary"
                            and item["muscle"] != candidate
                        )
                        family["musclePolicy"]["allowedByRole"][
                            "primary"
                        ].append(substitute["muscle"])
                        substitute["role"] = "primary"
                    with self.subTest(
                        family=family_id,
                        exercise=exercise["catalogID"],
                        requirement=requirement_index,
                        mutation="demote",
                    ):
                        self.assert_late_lower_body_closure_fails(
                            family,
                            f"fails muscle requirement {requirement_index}",
                        )
                    demotion_count += 1
        self.assertEqual(removal_count, 40)
        self.assertEqual(demotion_count, 15)

    def test_late_lower_body_stability_providers_are_exact(self) -> None:
        expected = {
            "bodyweight-active-straight-leg-raise": {
                "hip": {"iliopsoas", "rectusFemoris"},
                "pelvis": {"iliopsoas", "abs", "obliques"},
                "knee": {"rectusFemoris"},
                "spine": {"abs", "obliques"},
            },
            "barbell-good-morning-25-percent-body-mass": {
                "shoulder": {"externalRotators"},
                "scapula": {"trapeziusUpper"},
                "elbow": {"brachialis"},
                "wrist": {"fingerFlexors", "extensorCarpiRadialis"},
                "hand": {"fingerFlexors"},
                "spine": {"lumbarExtensors", "abs", "obliques"},
                "pelvis": {
                    "medialHamstrings", "gluteMax", "lumbarExtensors",
                    "gluteMed", "abs", "obliques",
                },
                "hip": {"medialHamstrings", "gluteMax", "gluteMed"},
                "knee": {
                    "medialHamstrings", "bicepsFemoris", "gastrocnemius",
                },
                "ankle": {"gastrocnemius", "soleus"},
                "foot": {"gastrocnemius", "soleus"},
            },
        }
        lunge_providers = {
            "spine": {"abs", "obliques", "lumbarExtensors"},
            "pelvis": {
                "gluteMax", "medialHamstrings", "gluteMed", "abs",
                "obliques", "lumbarExtensors",
            },
            "hip": {
                "gluteMax", "rectusFemoris", "medialHamstrings", "gluteMed",
            },
            "knee": {
                "vasti", "rectusFemoris", "medialHamstrings",
                "bicepsFemoris", "gastrocnemius",
            },
            "ankle": {"gastrocnemius", "soleus"},
            "foot": {"gastrocnemius", "soleus"},
        }
        expected["bodyweight-forward-lunge"] = lunge_providers
        expected["bodyweight-reverse-lunge"] = lunge_providers

        actual = {}
        for family in self.late_lower_body_closure_families.values():
            for exercise in family["exercises"]:
                assigned = {
                    item["muscle"] for item in exercise["involvement"]
                }
                actual[exercise["catalogID"]] = {
                    region: {
                        muscle_id
                        for muscle_id in assigned
                        if region
                        in self.foundation.profile_by_muscle[muscle_id][
                            "stabilizes"
                        ]
                    }
                    for region in family["movementSignature"][
                        "stabilityDemands"
                    ]
                }
        self.assertEqual(actual, expected)

    def test_late_lower_body_closure_axes_are_exact_and_fully_covered(
        self,
    ) -> None:
        def enum(*values: object) -> tuple:
            return ("enum", values)

        def number(minimum: float, maximum: float) -> tuple:
            return ("number", minimum, maximum)

        expected = {
            "hip-flexion": {
                "kineticChain": enum("open"),
                "bodyPosition": enum("supine"),
                "torsoSupport": enum("table"),
                "pelvisSupport": enum("table"),
                "pelvisMotion": enum("nonstandardized"),
                "spineMotion": enum("nonstandardized"),
                "hipMotion": enum("flexes"),
                "rangeOfMotion": enum("activeEndRange"),
                "kneeMotion": enum("positionHeld"),
                "kneePosture": enum("extended"),
                "movingSegment": enum("thigh"),
                "loadInterface": enum("none"),
                "resistanceGeometry": enum("limbSegmentGravity"),
                "fixedPath": ("boolean", False),
                "lowerBodyContribution": enum("isolatedJointMotion"),
            },
            "hip-hinge": {
                "kineticChain": enum("closed"),
                "bodyPosition": enum("standing"),
                "torsoSupport": enum("none"),
                "stanceConfiguration": enum("symmetricBilateral"),
                "stanceWidth": enum("shoulderWidth"),
                "footOrientation": enum("slightNaturalToeOut"),
                "footContact": enum("continuous"),
                "loadPlacement": enum("posteriorShoulderUpperBack"),
                "gripOrientation": enum("comfortableUnreported"),
                "externalLoadPrescription": enum(
                    "twentyFivePercentBodyMass"
                ),
                "hipMotion": enum("extends"),
                "spineMotion": enum(
                    "extendsWithMeasuredSegmentalExcursion"
                ),
                "kneeMotion": enum("measuredSmallNondefiningExcursion"),
                "rangeOfMotion": enum(
                    "maximumHipFlexionWithNaturalSpineTechnique"
                ),
                "headPosition": enum("alignedWithSpine"),
                "tempo": enum("equalNormalDescentAscent"),
                "fixedPath": ("boolean", False),
                "interRepSupport": enum("none"),
                "lowerBodyContribution": enum(
                    "hipAndSpineExtensionWithSmallKneeExcursion"
                ),
            },
            "dynamic-lunge": {
                "kineticChain": enum("closedDuringLoadedPhase"),
                "bodyPosition": enum("standing"),
                "torsoSupport": enum("none"),
                "trunkOrientation": enum("upright"),
                "upperLimbPosition": enum("crossed"),
                "startSupport": enum("bilateralStanding"),
                "stepDirection": enum(
                    "selectedLeadForward", "contralateralRearward"
                ),
                "selectedLeadFootTransition": enum(
                    "stepsForwardThenReturns", "remainsPlantedThroughout"
                ),
                "contralateralFootTransition": enum(
                    "remainsAtStartThenReceivesReturn",
                    "stepsRearwardThenReturns",
                ),
                "landingFoot": enum("selectedLead", "contralateral"),
                "selectedLeadFootContact": enum(
                    "stepsThenWholeFootMaintained", "maintainedOnStartPlate"
                ),
                "landingDemand": enum("dynamicFootContact"),
                "depthCriterion": enum("fullSelfSelectedDepth"),
                "returnTopology": enum("returnToBilateralStart"),
                "spineMotion": enum("nonstandardized"),
                "pelvisMotion": enum("nonstandardized"),
                "hipMotion": enum("extends"),
                "kneeMotion": enum("extends"),
                "ankleMotion": enum("plantarflexes"),
                "footMotion": enum("positionHeldDuringLoadedPhase"),
                "loadPlacement": enum("none"),
                "eccentricSeconds": number(3, 3),
                "concentricSeconds": number(2, 2),
                "lowerBodyContribution": enum(
                    "compoundHipKneeAnkleExtension"
                ),
            },
        }
        for family_id, family in (
            self.late_lower_body_closure_families.items()
        ):
            actual = {}
            for axis in family["variantAxes"]:
                self.assertTrue(axis["required"])
                axis_id = axis["id"]
                observed = {
                    exercise["variant"][axis_id]
                    for exercise in family["exercises"]
                }
                if axis["valueType"] == "enum":
                    actual[axis_id] = (
                        "enum", tuple(axis["allowedValues"]),
                    )
                    self.assertEqual(observed, set(axis["allowedValues"]))
                elif axis["valueType"] == "number":
                    actual[axis_id] = (
                        "number", axis["minimum"], axis["maximum"],
                    )
                    self.assertEqual(
                        observed,
                        {axis["minimum"], axis["maximum"]},
                    )
                elif axis["valueType"] == "boolean":
                    actual[axis_id] = ("boolean", axis["fixedValue"])
                    self.assertEqual(observed, {axis["fixedValue"]})
                else:
                    self.fail(
                        f"unexpected late-closure axis type "
                        f"{axis['valueType']}"
                    )
            with self.subTest(family=family_id):
                self.assertEqual(actual, expected[family_id])

    def test_late_lower_body_closure_mutates_every_axis_and_field_domain(
        self,
    ) -> None:
        mutation_count = 0
        field_domains = {
            "equipment": ("equipment", catalog.EQUIPMENT),
            "laterality": ("lateralities", catalog.LATERALITIES),
            "modality": ("modalities", catalog.MODALITIES),
            "trackingMode": ("trackingModes", catalog.TRACKING_MODES),
            "loadMode": ("loadModes", catalog.LOAD_MODES),
        }
        for family_id, original in (
            self.late_lower_body_closure_families.items()
        ):
            for exercise_index, exercise in enumerate(original["exercises"]):
                for axis in original["variantAxes"]:
                    family = copy.deepcopy(original)
                    axis_id = axis["id"]
                    if axis["valueType"] == "enum":
                        value = "mutated"
                        expected_error = re.escape(
                            f"variant.{axis_id} has disallowed value 'mutated'"
                        )
                    elif axis["valueType"] == "number":
                        value = axis["maximum"] + 1
                        expected_error = re.escape(
                            f"variant.{axis_id} exceeds {axis['maximum']}"
                        )
                    elif axis["valueType"] == "boolean":
                        value = not axis["fixedValue"]
                        expected_error = re.escape(
                            f"variant.{axis_id} must equal fixed value "
                            f"{axis['fixedValue']!r}"
                        )
                    else:
                        self.fail(
                            f"unexpected late-closure axis type "
                            f"{axis['valueType']}"
                        )
                    family["exercises"][exercise_index]["variant"][
                        axis_id
                    ] = value
                    with self.subTest(
                        family=family_id,
                        exercise=exercise["catalogID"],
                        axis=axis_id,
                    ):
                        self.assert_late_lower_body_closure_fails(
                            family,
                            expected_error,
                        )
                    mutation_count += 1

                for field, (allowed_key, domain) in field_domains.items():
                    family = copy.deepcopy(original)
                    mutated_value = sorted(
                        domain - set(original["allowed"][allowed_key])
                    )[0]
                    family["exercises"][exercise_index][field] = mutated_value
                    with self.subTest(
                        family=family_id,
                        exercise=exercise["catalogID"],
                        field=field,
                    ):
                        self.assert_late_lower_body_closure_fails(
                            family,
                            re.escape(
                                f"selects disallowed {allowed_key}: "
                                f"{mutated_value}"
                            ),
                        )
                    mutation_count += 1
        self.assertEqual(mutation_count, 102)

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
        warnings = catalog.validate_family(
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

    def test_family_schema_declares_boolean_fixed_value_shape(self) -> None:
        variant_axis = self.foundation.family_schema["$defs"]["variantAxis"]
        self.assertEqual(
            variant_axis["properties"]["fixedValue"],
            {"type": "boolean"},
        )
        self.assertIn(
            {
                "if": {"required": ["fixedValue"]},
                "then": {
                    "properties": {
                        "valueType": {"const": "boolean"},
                        "required": {"const": True},
                    }
                },
            },
            variant_axis["allOf"],
        )

        schema = copy.deepcopy(self.foundation.family_schema)
        del schema["$defs"]["variantAxis"]["properties"]["fixedValue"]
        with self.assertRaisesRegex(
            catalog.ValidationFailure,
            r"variantAxis\.fixedValue must be a boolean",
        ):
            catalog.validate_family_schema(schema)

        schema = copy.deepcopy(self.foundation.family_schema)
        schema["$defs"]["variantAxis"]["allOf"] = []
        with self.assertRaisesRegex(
            catalog.ValidationFailure,
            r"fixedValue must require a required boolean axis",
        ):
            catalog.validate_family_schema(schema)

    def test_conditional_muscle_requirement_rejects_missing_any_of_set(
        self,
    ) -> None:
        family = self.family_copy()
        family["musclePolicy"]["allowedByRole"]["stabilizer"].extend(
            ["abs", "obliques", "lumbarExtensors"]
        )
        family["exerciseRules"] = [
            self.conditional_muscle_rule(
                [
                    {
                        "anyOf": ["abs", "obliques", "lumbarExtensors"],
                        "minimumRole": "stabilizer",
                    }
                ]
            )
        ]
        family["exercises"][0]["variant"]["support"] = "standing"
        self.assert_family_fails(
            family,
            "violates exercise rule standing-requires-trunk-muscle: "
            r"one of \['abs', 'obliques', 'lumbarExtensors'\] must be assigned as "
            "stabilizer or higher",
        )

    def test_conditional_muscle_requirement_accepts_any_reviewed_candidate(
        self,
    ) -> None:
        family = self.family_copy()
        family["musclePolicy"]["allowedByRole"]["stabilizer"].extend(
            ["abs", "obliques", "lumbarExtensors"]
        )
        family["exerciseRules"] = [
            self.conditional_muscle_rule(
                [
                    {
                        "anyOf": ["abs", "obliques", "lumbarExtensors"],
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
            catalog.validate_family(
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
            catalog.validate_family(
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
        warnings = catalog.validate_family(
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

    def test_exercise_cannot_redeclare_a_family_prime_action(self) -> None:
        family = self.family_copy()
        family["exercises"][0]["additionalPrimeActions"] = [
            "shoulder.horizontalAdduction"
        ]
        self.assert_family_fails(
            family,
            "redeclares family prime action shoulder.horizontalAdduction",
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
                            catalog.ValidationFailure,
                            f"{muscle_id} must be assigned as stabilizer",
                        ):
                            catalog.validate_family(
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
        warnings = catalog.validate_family(
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
                "lumbarExtensors": "stabilizer",
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
                if muscle not in {"abs", "obliques", "lumbarExtensors"}
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
        warnings = catalog.validate_family(
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
            if assignment["muscle"] not in {"abs", "obliques", "lumbarExtensors"}
        ]
        warnings = catalog.validate_family(
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
        warnings = catalog.validate_family(
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
        trunk_stabilizers = {"abs", "obliques", "lumbarExtensors"}
        for exercise in self.vertical_pull["exercises"]:
            roles = {
                assignment["muscle"]: assignment["role"]
                for assignment in exercise["involvement"]
            }
            with self.subTest(exercise=exercise["catalogID"]):
                self.assertEqual(roles["lats"], "primary")
                self.assertEqual(roles["teresMajor"], "secondary")
                self.assertEqual(roles["bicepsBrachii"], "secondary")
                self.assertEqual(roles["brachialis"], "secondary")
                self.assertEqual(roles["brachioradialis"], "secondary")
                self.assertTrue(
                    any(roles.get(muscle) == "secondary" for muscle in retractors)
                )
                self.assertEqual(roles["externalRotators"], "stabilizer")
                self.assertEqual(roles["fingerFlexors"], "stabilizer")
                self.assertEqual(
                    roles["extensorCarpiRadialis"],
                    "stabilizer",
                )
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
        warnings = catalog.validate_family(
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
                catalog.exercise_rule_field(
                    exercise,
                    predicate["field"],
                )
                for exercise in exercises
            ]
            if predicate["operator"] == "equals":
                matches = [value == predicate["value"] for value in values]
            else:
                matches = [
                    value is not catalog.MISSING
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
            "bicepsBrachii": "secondary",
            "brachialis": "secondary",
            "brachioradialis": "secondary",
            "trapeziusMiddle": "secondary",
            "rhomboids": "secondary",
            "subscapularis": "stabilizer",
            "fingerFlexors": "stabilizer",
            "extensorCarpiRadialis": "stabilizer",
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
                    self.assertEqual(roles["lumbarExtensors"], "stabilizer")
                    self.assertEqual(roles["gluteMax"], "stabilizer")
                if exercise["laterality"] == "unilateral":
                    self.assertEqual(roles["obliques"], "stabilizer")
                if exercise["variant"]["bodyPosition"] == "supineSuspended":
                    self.assertEqual(roles["abs"], "stabilizer")
                    self.assertEqual(roles["lumbarExtensors"], "stabilizer")
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
            actual = catalog.exercise_rule_field(
                exercise,
                predicate["field"],
            )
            if actual is catalog.MISSING:
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
            if path in catalog.RULE_FIELD_DOMAINS:
                return sorted(catalog.RULE_FIELD_DOMAINS[path])
            if path in catalog.RULE_NUMERIC_FIELDS:
                minimum, maximum = catalog.RULE_NUMERIC_FIELDS[path]
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
                    catalog.MISSING,
                )
                mutated = copy.deepcopy(matching)
                if alternative is catalog.MISSING:
                    delete_field(mutated, path)
                else:
                    set_field(mutated, path, alternative)
                with self.subTest(rule=rule["id"], assertion=path):
                    with self.assertRaisesRegex(
                        catalog.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog.validate_exercise_rule_matches(
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
                        catalog.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog.validate_exercise_rule_matches(
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
                        catalog.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog.validate_exercise_rule_matches(
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
                        catalog.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog.validate_exercise_rule_matches(
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
                        catalog.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog.validate_exercise_rule_matches(
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
                        catalog.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog.validate_exercise_rule_matches(
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
        warnings = catalog.validate_family(
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
                catalog.exercise_rule_field(
                    exercise,
                    predicate["field"],
                )
                for exercise in exercises
            ]
            if predicate["operator"] == "equals":
                matches = [value == predicate["value"] for value in values]
            else:
                matches = [
                    value is not catalog.MISSING
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
            "bicepsBrachii": "secondary",
            "brachialis": "secondary",
            "brachioradialis": "secondary",
            "trapeziusUpper": "stabilizer",
            "fingerFlexors": "stabilizer",
            "extensorCarpiRadialis": "stabilizer",
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
                    self.assertEqual(roles["lumbarExtensors"], "stabilizer")
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
            actual = catalog.exercise_rule_field(
                exercise,
                predicate["field"],
            )
            if actual is catalog.MISSING:
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
            if path in catalog.RULE_FIELD_DOMAINS:
                return sorted(catalog.RULE_FIELD_DOMAINS[path])
            if path in catalog.RULE_NUMERIC_FIELDS:
                minimum, maximum = catalog.RULE_NUMERIC_FIELDS[path]
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
                    catalog.MISSING,
                )
                mutated = copy.deepcopy(matching)
                if alternative is catalog.MISSING:
                    delete_field(mutated, path)
                else:
                    set_field(mutated, path, alternative)
                with self.subTest(rule=rule["id"], assertion=path):
                    with self.assertRaisesRegex(
                        catalog.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog.validate_exercise_rule_matches(
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
                        catalog.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog.validate_exercise_rule_matches(
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
                        catalog.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog.validate_exercise_rule_matches(
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
                        catalog.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog.validate_exercise_rule_matches(
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
                        catalog.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog.validate_exercise_rule_matches(
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
                        catalog.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog.validate_exercise_rule_matches(
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
            catalog.ValidationFailure,
            "violates exercise rule unsupported-requires-trunk-stability",
        ):
            catalog.validate_exercise_rule_matches(
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
            "bicepsBrachii cannot produce any declared prime action",
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
        with self.assertRaises(catalog.ValidationFailure):
            catalog.validate_family_set(
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
                        catalog.ValidationFailure,
                        message,
                    ):
                        catalog.validate_family(
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
        warnings = catalog.validate_family(
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
        warnings = catalog.validate_family(
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
        self.assertIn("diagonal", catalog.DIRECTIONS)
        self.assertNotIn("diagonal", catalog.CARDINAL_PLANES)
        self.assertEqual(
            catalog.CARDINAL_PLANES,
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
            "elbow-flexion",
            "elbow-extension",
            "forearm-pronation",
            "forearm-supination",
            "wrist-flexion",
            "wrist-extension",
            "wrist-radial-deviation",
            "wrist-ulnar-deviation",
            "scapular-protraction",
            "scapular-elevation",
            "scapular-retraction",
            "scapular-depression",
            "upright-row",
            "dip",
            "push-press",
            "knee-extension",
            "knee-flexion",
            "hip-extension",
            "hip-flexion",
            "ankle-plantarflexion",
            "bilateral-squat",
            "hip-hinge",
            "hip-thrust-bridge",
            "split-stance-squat",
            "step-up",
            "dynamic-lunge",
            "hip-abduction",
            "hip-adduction",
            "ankle-dorsiflexion",
            "hip-internal-rotation",
            "hip-external-rotation",
            "spine-flexion",
            "spine-extension",
            "spine-lateral-flexion",
            "spine-rotation",
            "anti-extension",
            "anti-lateral-flexion",
            "anti-rotation",
            "farmer-carry",
            "suitcase-carry",
        }
        self.assertEqual(
            {family["id"] for family in self.real_families},
            expected_ids,
        )
        self.assertEqual(
            sum(len(family["exercises"]) for family in self.real_families),
            132,
        )

    def test_every_discovered_real_family_validates_without_warnings(
        self,
    ) -> None:
        for family in self.real_families:
            with self.subTest(family=family["id"]):
                self.assertEqual(
                    catalog.validate_family(
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

    def test_batch1_later_closures_are_active_families(self) -> None:
        active_ids = {family["id"] for family in self.real_families}
        self.assertTrue(
            {"scapular-retraction", "upright-row"}.issubset(active_ids)
        )

    def test_batch2_activated_exactly_eight_narrow_families(self) -> None:
        expected = {
            "elbow-flexion": {
                "plane": "sagittal",
                "basis": "elbow.flexion",
                "prime": "elbow.flexion",
                "primary": ["brachialis", "bicepsBrachii"],
                "roster": [
                    "supinated-straight-bar-cable-curl",
                    "neutral-rope-cable-curl",
                    "pronated-straight-bar-cable-curl",
                ],
            },
            "elbow-extension": {
                "plane": "sagittal",
                "basis": "elbow.extension",
                "prime": "elbow.extension",
                "primary": ["triceps"],
                "roster": [
                    "single-arm-supinated-cable-triceps-pushdown",
                    "single-arm-pronated-cable-triceps-pushdown",
                    "single-arm-overhead-cable-triceps-extension",
                    "seated-single-arm-overhead-dumbbell-triceps-extension",
                    "single-arm-lying-dumbbell-triceps-extension",
                ],
            },
            "forearm-pronation": {
                "plane": "transverse",
                "basis": "forearm.pronation",
                "prime": "forearm.pronation@fromSupinatedPosition",
                "primary": ["forearmPronators"],
                "roster": ["seated-dumbbell-forearm-pronation"],
            },
            "forearm-supination": {
                "plane": "transverse",
                "basis": "forearm.supination",
                "prime": "forearm.supination@fromPronatedPosition",
                "primary": ["supinator", "bicepsBrachii"],
                "roster": ["seated-dumbbell-forearm-supination"],
            },
            "wrist-flexion": {
                "plane": "sagittal",
                "basis": "wrist.flexion",
                "prime": "wrist.flexion",
                "primary": ["flexorCarpiRadialis", "flexorCarpiUlnaris"],
                "roster": ["seated-barbell-wrist-curl"],
            },
            "wrist-extension": {
                "plane": "sagittal",
                "basis": "wrist.extension",
                "prime": "wrist.extension",
                "primary": [
                    "extensorCarpiRadialis",
                    "extensorCarpiUlnaris",
                ],
                "roster": ["seated-barbell-reverse-wrist-curl"],
            },
            "wrist-radial-deviation": {
                "plane": "frontal",
                "basis": "wrist.radialDeviation",
                "prime": "wrist.radialDeviation",
                "primary": [
                    "flexorCarpiRadialis",
                    "extensorCarpiRadialis",
                ],
                "roster": ["standing-dumbbell-wrist-radial-deviation"],
            },
            "wrist-ulnar-deviation": {
                "plane": "frontal",
                "basis": "wrist.ulnarDeviation",
                "prime": "wrist.ulnarDeviation",
                "primary": [
                    "flexorCarpiUlnaris",
                    "extensorCarpiUlnaris",
                ],
                "roster": ["standing-dumbbell-wrist-ulnar-deviation"],
            },
        }
        self.assertEqual(set(self.batch2_families), set(expected))

        for family_id, contract in expected.items():
            with self.subTest(family=family_id):
                family = self.batch2_families[family_id]
                prime = family["movementSignature"]["primeActions"][0]
                prime_label = (
                    f"{prime['action']}@{prime['condition']}"
                    if isinstance(prime, dict)
                    else prime
                )
                self.assertEqual(
                    family["fixed"],
                    {
                        "mechanic": "isolation",
                        "pattern": None,
                        "direction": None,
                        "planes": [contract["plane"]],
                    },
                )
                self.assertEqual(
                    family["movementSignature"]["planeBasisActions"],
                    [contract["basis"]],
                )
                self.assertEqual(prime_label, contract["prime"])
                self.assertEqual(
                    family["musclePolicy"]["allowedByRole"]["primary"],
                    contract["primary"],
                )
                self.assertEqual(
                    [
                        exercise["catalogID"]
                        for exercise in family["exercises"]
                    ],
                    contract["roster"],
                )

    def test_batch2_exact_involvement_rosters_are_pinned(self) -> None:
        expected = {
            "supinated-straight-bar-cable-curl": {
                "brachialis": "primary",
                "bicepsBrachii": "primary",
                "brachioradialis": "secondary",
                "deltoidAnterior": "stabilizer",
                "trapeziusMiddle": "stabilizer",
                "fingerFlexors": "stabilizer",
                "extensorCarpiRadialis": "stabilizer",
                "obliques": "stabilizer",
            },
            "neutral-rope-cable-curl": {
                "brachialis": "primary",
                "bicepsBrachii": "secondary",
                "brachioradialis": "secondary",
                "deltoidAnterior": "stabilizer",
                "trapeziusMiddle": "stabilizer",
                "fingerFlexors": "stabilizer",
                "extensorCarpiRadialis": "stabilizer",
                "obliques": "stabilizer",
            },
            "pronated-straight-bar-cable-curl": {
                "brachialis": "primary",
                "bicepsBrachii": "secondary",
                "brachioradialis": "secondary",
                "deltoidAnterior": "stabilizer",
                "trapeziusMiddle": "stabilizer",
                "fingerFlexors": "stabilizer",
                "extensorCarpiRadialis": "stabilizer",
                "obliques": "stabilizer",
            },
            "single-arm-supinated-cable-triceps-pushdown": {
                "triceps": "primary",
                "brachioradialis": "stabilizer",
                "fingerFlexors": "stabilizer",
                "extensorCarpiRadialis": "stabilizer",
                "externalRotators": "stabilizer",
                "trapeziusMiddle": "stabilizer",
                "obliques": "stabilizer",
            },
            "single-arm-pronated-cable-triceps-pushdown": {
                "triceps": "primary",
                "brachioradialis": "stabilizer",
                "fingerFlexors": "stabilizer",
                "extensorCarpiRadialis": "stabilizer",
                "flexorCarpiRadialis": "stabilizer",
                "externalRotators": "stabilizer",
                "trapeziusMiddle": "stabilizer",
                "obliques": "stabilizer",
            },
            "single-arm-overhead-cable-triceps-extension": {
                "triceps": "primary",
                "brachioradialis": "stabilizer",
                "fingerFlexors": "stabilizer",
                "extensorCarpiRadialis": "stabilizer",
                "externalRotators": "stabilizer",
                "trapeziusLower": "stabilizer",
                "obliques": "stabilizer",
            },
            "seated-single-arm-overhead-dumbbell-triceps-extension": {
                "triceps": "primary",
                "brachioradialis": "stabilizer",
                "fingerFlexors": "stabilizer",
                "extensorCarpiRadialis": "stabilizer",
                "externalRotators": "stabilizer",
                "trapeziusLower": "stabilizer",
                "obliques": "stabilizer",
            },
            "single-arm-lying-dumbbell-triceps-extension": {
                "triceps": "primary",
                "brachioradialis": "stabilizer",
                "fingerFlexors": "stabilizer",
                "extensorCarpiRadialis": "stabilizer",
                "externalRotators": "stabilizer",
                "trapeziusMiddle": "stabilizer",
            },
            "seated-dumbbell-forearm-pronation": {
                "forearmPronators": "primary",
                "brachioradialis": "secondary",
                "extensorCarpiRadialis": "stabilizer",
                "fingerFlexors": "stabilizer",
                "externalRotators": "stabilizer",
                "trapeziusMiddle": "stabilizer",
            },
            "seated-dumbbell-forearm-supination": {
                "supinator": "primary",
                "bicepsBrachii": "primary",
                "brachioradialis": "secondary",
                "extensorCarpiRadialis": "stabilizer",
                "fingerFlexors": "stabilizer",
                "externalRotators": "stabilizer",
                "trapeziusMiddle": "stabilizer",
            },
            "seated-barbell-wrist-curl": {
                "flexorCarpiRadialis": "primary",
                "flexorCarpiUlnaris": "primary",
                "fingerFlexors": "secondary",
                "extensorCarpiRadialis": "stabilizer",
                "extensorCarpiUlnaris": "stabilizer",
                "fingerExtensors": "stabilizer",
                "brachioradialis": "stabilizer",
                "externalRotators": "stabilizer",
                "trapeziusMiddle": "stabilizer",
            },
            "seated-barbell-reverse-wrist-curl": {
                "extensorCarpiRadialis": "primary",
                "extensorCarpiUlnaris": "primary",
                "fingerExtensors": "secondary",
                "flexorCarpiRadialis": "stabilizer",
                "flexorCarpiUlnaris": "stabilizer",
                "fingerFlexors": "stabilizer",
                "brachioradialis": "stabilizer",
                "externalRotators": "stabilizer",
                "trapeziusMiddle": "stabilizer",
            },
            "standing-dumbbell-wrist-radial-deviation": {
                "flexorCarpiRadialis": "primary",
                "extensorCarpiRadialis": "primary",
                "flexorCarpiUlnaris": "stabilizer",
                "extensorCarpiUlnaris": "stabilizer",
                "fingerFlexors": "stabilizer",
                "brachioradialis": "stabilizer",
                "externalRotators": "stabilizer",
                "trapeziusMiddle": "stabilizer",
            },
            "standing-dumbbell-wrist-ulnar-deviation": {
                "flexorCarpiUlnaris": "primary",
                "extensorCarpiUlnaris": "primary",
                "flexorCarpiRadialis": "stabilizer",
                "extensorCarpiRadialis": "stabilizer",
                "fingerFlexors": "stabilizer",
                "brachioradialis": "stabilizer",
                "externalRotators": "stabilizer",
                "trapeziusMiddle": "stabilizer",
            },
        }
        actual = {
            exercise["catalogID"]: {
                assignment["muscle"]: assignment["role"]
                for assignment in exercise["involvement"]
            }
            for family in self.batch2_families.values()
            for exercise in family["exercises"]
        }
        self.assertEqual(actual, expected)

    def test_batch2_authored_roster_surface_is_exactly_pinned(self) -> None:
        payload = []
        for family_id in sorted(self.batch2_families):
            family = self.batch2_families[family_id]
            payload.append(
                {
                    "familyID": family_id,
                    "familyEvidenceRefs": family["evidenceRefs"],
                    "exercises": [
                        {
                            key: exercise[key]
                            for key in (
                                "catalogID",
                                "name",
                                "aliases",
                                "variant",
                                "evidenceRefs",
                                "movementDefinition",
                            )
                        }
                        for exercise in family["exercises"]
                    ],
                }
            )
        encoded = json.dumps(
            payload,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
        self.assertEqual(
            hashlib.sha256(encoded).hexdigest(),
            "49c4cd53963a26b15f1991cfb4024e3170f42534307b3e44021ea9eb269cbc11",
        )

    def test_batch2_forbids_every_other_known_prime_action(self) -> None:
        for family_id, original in self.batch2_families.items():
            own_action_ids = {
                action if isinstance(action, str) else action["action"]
                for action in original["movementSignature"]["primeActions"]
            }
            expected_forbidden = (
                set(self.foundation.action_ids) - own_action_ids
            )
            self.assertEqual(
                set(
                    original["movementSignature"]["forbiddenPrimeActions"]
                ),
                expected_forbidden,
            )
            for action in expected_forbidden:
                with self.subTest(family=family_id, action=action):
                    family = copy.deepcopy(original)
                    family["exercises"][0]["additionalPrimeActions"] = [
                        action
                    ]
                    self.assert_batch2_family_fails(
                        family,
                        f"declares forbidden prime action {re.escape(action)}",
                    )

    def test_batch2_rosters_cover_every_admitted_discrete_axis_value(
        self,
    ) -> None:
        for family_id, family in self.batch2_families.items():
            for axis in family["variantAxes"]:
                observed = {
                    exercise["variant"][axis["id"]]
                    for exercise in family["exercises"]
                }
                with self.subTest(family=family_id, axis=axis["id"]):
                    self.assertTrue(axis["required"])
                    if axis["valueType"] == "enum":
                        self.assertEqual(
                            observed,
                            set(axis["allowedValues"]),
                        )
                    elif axis["valueType"] == "boolean":
                        self.assertEqual(observed, {False})
                    else:
                        self.fail(
                            f"unexpected Batch-2 axis type {axis['valueType']}"
                        )

    def test_single_value_free_path_families_enforce_boolean_fixed_value(
        self,
    ) -> None:
        expected_family_ids = {
            "elbow-extension",
            "elbow-flexion",
            "forearm-pronation",
            "forearm-supination",
            "shoulder-external-rotation",
            "shoulder-internal-rotation",
            "wrist-extension",
            "wrist-flexion",
            "wrist-radial-deviation",
            "wrist-ulnar-deviation",
            "scapular-elevation",
            "scapular-retraction",
            "scapular-depression",
            "upright-row",
            "scapular-protraction",
            "push-press",
            "hip-extension",
            "hip-flexion",
            "bilateral-squat",
            "hip-hinge",
            "hip-thrust-bridge",
            "split-stance-squat",
            "hip-abduction",
            "hip-adduction",
            "ankle-dorsiflexion",
            "hip-internal-rotation",
            "hip-external-rotation",
            "spine-flexion",
            "spine-lateral-flexion",
            "anti-extension",
            "anti-lateral-flexion",
            "anti-rotation",
            "farmer-carry",
            "suitcase-carry",
        }
        actual_family_ids = set()
        for original in self.real_families:
            axes = {axis["id"]: axis for axis in original["variantAxes"]}
            fixed_path = axes.get("fixedPath")
            if (
                fixed_path is None
                or fixed_path.get("fixedValue") is not False
            ):
                continue
            actual_family_ids.add(original["id"])
            with self.subTest(family=original["id"]):
                self.assertEqual(fixed_path["valueType"], "boolean")
                self.assertIs(fixed_path["required"], True)
                self.assertIs(fixed_path["fixedValue"], False)
                for exercise_index in range(len(original["exercises"])):
                    family = copy.deepcopy(original)
                    family["exercises"][exercise_index]["variant"][
                        "fixedPath"
                    ] = True
                    with self.assertRaisesRegex(
                        catalog.ValidationFailure,
                        r"variant\.fixedPath must equal fixed value False",
                    ):
                        catalog.validate_family(
                            family,
                            self.foundation,
                            f"mutated {family['id']}",
                        )
        self.assertEqual(actual_family_ids, expected_family_ids)

    def test_boolean_fixed_value_metadata_is_type_checked(self) -> None:
        family = copy.deepcopy(self.batch2_families["elbow-flexion"])
        fixed_path = next(
            axis for axis in family["variantAxes"]
            if axis["id"] == "fixedPath"
        )
        fixed_path["fixedValue"] = "false"
        self.assert_batch2_family_fails(
            family,
            r"fixedValue must be a boolean",
        )

        family = copy.deepcopy(self.batch2_families["elbow-flexion"])
        fixed_path = next(
            axis for axis in family["variantAxes"]
            if axis["id"] == "fixedPath"
        )
        fixed_path["required"] = False
        self.assert_batch2_family_fails(
            family,
            r"with fixedValue must be required",
        )

        family = copy.deepcopy(self.batch2_families["elbow-flexion"])
        body_position = next(
            axis for axis in family["variantAxes"]
            if axis["id"] == "bodyPosition"
        )
        body_position["fixedValue"] = False
        self.assert_batch2_family_fails(
            family,
            r"fixedValue is only valid for a boolean axis",
        )

    def test_every_batch2_rule_has_a_match_and_a_contrast(self) -> None:
        for family_id, family in self.batch2_families.items():
            for rule in family["exerciseRules"]:
                matches = [
                    self.rule_matches_exercise(rule, exercise)
                    for exercise in family["exercises"]
                ]
                with self.subTest(family=family_id, rule=rule["id"]):
                    self.assertTrue(any(matches))
                    self.assertTrue(any(not value for value in matches))

    def test_every_batch2_rule_consequence_has_a_direct_mutation(
        self,
    ) -> None:
        mutation_count = 0
        for family_id, family in self.batch2_families.items():
            for rule in family["exerciseRules"]:
                matching = next(
                    exercise
                    for exercise in family["exercises"]
                    if self.rule_matches_exercise(rule, exercise)
                )
                expected_message = (
                    "violates exercise rule " + re.escape(rule["id"])
                )

                for assertion in rule["then"]:
                    mutated = copy.deepcopy(matching)
                    current = catalog.exercise_rule_field(
                        mutated,
                        assertion["field"],
                    )
                    alternative = (
                        not current if isinstance(current, bool) else "mutated"
                    )
                    self.set_rule_field(
                        mutated,
                        assertion["field"],
                        alternative,
                    )
                    with self.subTest(
                        family=family_id,
                        rule=rule["id"],
                        assertion=assertion["field"],
                    ):
                        with self.assertRaisesRegex(
                            catalog.ValidationFailure,
                            expected_message,
                        ):
                            catalog.validate_exercise_rule_matches(
                                mutated,
                                [rule],
                                "mutated Batch-2 exercise",
                            )
                    mutation_count += 1

                for field_path in rule["requirePresent"]:
                    mutated = copy.deepcopy(matching)
                    self.delete_rule_field(mutated, field_path)
                    with self.assertRaisesRegex(
                        catalog.ValidationFailure,
                        expected_message,
                    ):
                        catalog.validate_exercise_rule_matches(
                            mutated,
                            [rule],
                            "mutated Batch-2 exercise",
                        )
                    mutation_count += 1

                for field_path in rule["requireAbsent"]:
                    mutated = copy.deepcopy(matching)
                    self.set_rule_field(mutated, field_path, "mutated")
                    with self.assertRaisesRegex(
                        catalog.ValidationFailure,
                        expected_message,
                    ):
                        catalog.validate_exercise_rule_matches(
                            mutated,
                            [rule],
                            "mutated Batch-2 exercise",
                        )
                    mutation_count += 1

                for assignment in rule.get("requireInvolvement", []):
                    mutated = copy.deepcopy(matching)
                    contribution = next(
                        item
                        for item in mutated["involvement"]
                        if item["muscle"] == assignment["muscle"]
                    )
                    contribution["role"] = (
                        "stabilizer"
                        if assignment["role"] != "stabilizer"
                        else "secondary"
                    )
                    with self.assertRaisesRegex(
                        catalog.ValidationFailure,
                        expected_message,
                    ):
                        catalog.validate_exercise_rule_matches(
                            mutated,
                            [rule],
                            "mutated Batch-2 exercise",
                        )
                    mutation_count += 1

                for requirement in rule.get(
                    "requireMuscleRequirements", []
                ):
                    mutated = copy.deepcopy(matching)
                    mutated["involvement"] = [
                        item
                        for item in mutated["involvement"]
                        if item["muscle"] not in requirement["anyOf"]
                    ]
                    with self.assertRaisesRegex(
                        catalog.ValidationFailure,
                        expected_message,
                    ):
                        catalog.validate_exercise_rule_matches(
                            mutated,
                            [rule],
                            "mutated Batch-2 exercise",
                        )
                    mutation_count += 1

                for region in rule.get(
                    "requireAdditionalStabilityDemands", []
                ):
                    mutated = copy.deepcopy(matching)
                    mutated["additionalStabilityDemands"].remove(region)
                    with self.assertRaisesRegex(
                        catalog.ValidationFailure,
                        expected_message,
                    ):
                        catalog.validate_exercise_rule_matches(
                            mutated,
                            [rule],
                            "mutated Batch-2 exercise",
                        )
                    mutation_count += 1

        self.assertEqual(mutation_count, 37)

    def test_conditioned_rotation_cannot_be_broadened_per_exercise(
        self,
    ) -> None:
        cases = {
            "forearm-pronation": (
                "forearm.pronation",
                "fromSupinatedPosition",
                "supinated",
                "neutral",
            ),
            "forearm-supination": (
                "forearm.supination",
                "fromPronatedPosition",
                "pronated",
                "neutral",
            ),
        }
        for family_id, (action, condition, start, end) in cases.items():
            original = self.batch2_families[family_id]
            self.assertEqual(
                original["movementSignature"]["primeActions"],
                [{"action": action, "condition": condition}],
            )
            exercise = original["exercises"][0]
            self.assertEqual(
                exercise["variant"]["forearmStartOrientation"],
                start,
            )
            self.assertEqual(
                exercise["variant"]["forearmEndOrientation"],
                end,
            )
            self.assertNotIn(
                "forearmOrientation",
                {axis["id"] for axis in original["variantAxes"]},
            )
            for redeclaration in (
                action,
                {"action": action, "condition": condition},
            ):
                with self.subTest(
                    family=family_id,
                    redeclaration=redeclaration,
                ):
                    family = copy.deepcopy(original)
                    family["exercises"][0]["additionalPrimeActions"] = [
                        redeclaration
                    ]
                    self.assert_batch2_family_fails(
                        family,
                        f"redeclares family prime action {re.escape(action)}",
                    )

    def test_batch2_static_hand_task_never_becomes_a_finger_prime_action(
        self,
    ) -> None:
        finger_actions = {"hand.fingerFlexion", "hand.fingerExtension"}
        for family_id, family in self.batch2_families.items():
            with self.subTest(family=family_id):
                axes = {axis["id"]: axis for axis in family["variantAxes"]}
                self.assertEqual(
                    axes["handTask"]["allowedValues"],
                    ["staticImplementHold"],
                )
                prime_ids = {
                    action if isinstance(action, str) else action["action"]
                    for action in family["movementSignature"]["primeActions"]
                }
                self.assertTrue(finger_actions.isdisjoint(prime_ids))
                self.assertTrue(
                    all(
                        exercise["variant"]["handTask"]
                        == "staticImplementHold"
                        for exercise in family["exercises"]
                    )
                )
                for exercise in family["exercises"]:
                    assigned = {
                        item["muscle"] for item in exercise["involvement"]
                    }
                    self.assertTrue(
                        {"fingerFlexors", "extensorCarpiRadialis"}
                        <= assigned
                    )

    def test_batch2_resistance_geometries_and_metric_seeds_are_exact(
        self,
    ) -> None:
        expected = {
            "supinated-straight-bar-cable-curl": (30, 15, "lowCableCurl"),
            "neutral-rope-cable-curl": (30, 15, "lowCableCurl"),
            "pronated-straight-bar-cable-curl": (20, 10, "lowCableCurl"),
            "single-arm-supinated-cable-triceps-pushdown": (15, 7.5, "highCablePushdown"),
            "single-arm-pronated-cable-triceps-pushdown": (15, 7.5, "highCablePushdown"),
            "single-arm-overhead-cable-triceps-extension": (10, 5, "overheadCableExtension"),
            "seated-single-arm-overhead-dumbbell-triceps-extension": (10, 5, "gravityLoadedDumbbell"),
            "single-arm-lying-dumbbell-triceps-extension": (10, 5, "gravityLoadedDumbbell"),
            "seated-dumbbell-forearm-pronation": (5, 2.5, "rotationalPlateLoadedDumbbell"),
            "seated-dumbbell-forearm-supination": (5, 2.5, "rotationalPlateLoadedDumbbell"),
            "seated-barbell-wrist-curl": (20, 10, "centeredBar"),
            "seated-barbell-reverse-wrist-curl": (10, 5, "centeredBar"),
            "standing-dumbbell-wrist-radial-deviation": (5, 2.5, "collarOffsetLever"),
            "standing-dumbbell-wrist-ulnar-deviation": (5, 2.5, "collarOffsetLever"),
        }
        actual = {}
        for family in self.batch2_families.values():
            for exercise in family["exercises"]:
                actual[exercise["catalogID"]] = (
                    exercise["defaultWeight"],
                    exercise["defaultWeightKg"],
                    exercise["variant"]["resistanceGeometry"],
                )
        self.assertEqual(actual, expected)

    def test_elbow_resistance_geometry_and_held_forearm_are_contract_data(
        self,
    ) -> None:
        flexion = self.batch2_families["elbow-flexion"]
        extension = self.batch2_families["elbow-extension"]
        flexion_axes = {axis["id"]: axis for axis in flexion["variantAxes"]}
        extension_axes = {
            axis["id"]: axis for axis in extension["variantAxes"]
        }
        self.assertEqual(
            flexion_axes["resistanceGeometry"]["allowedValues"],
            ["lowCableCurl"],
        )
        self.assertEqual(
            extension_axes["resistanceGeometry"]["allowedValues"],
            [
                "highCablePushdown",
                "overheadCableExtension",
                "gravityLoadedDumbbell",
            ],
        )
        self.assertEqual(
            extension_axes["handleType"]["allowedValues"],
            [
                "singleCableHandle",
                "unreportedCableInterface",
                "dumbbellHandle",
            ],
        )
        self.assertEqual(
            extension["exercises"][2]["variant"]["handleType"],
            "unreportedCableInterface",
        )
        self.assertIn(
            "forearm",
            extension["movementSignature"]["stabilityDemands"],
        )
        self.assertIn(
            {
                "anyOf": ["brachioradialis"],
                "minimumRole": "stabilizer",
            },
            extension["musclePolicy"]["requirements"],
        )
        for family in (flexion, extension):
            self.assertIn(
                {
                    "anyOf": ["extensorCarpiRadialis"],
                    "minimumRole": "stabilizer",
                },
                family["musclePolicy"]["requirements"],
            )

        geometry_mutations = (
            ("elbow-flexion", 0, "highCablePushdown"),
            ("elbow-extension", 0, "overheadCableExtension"),
            ("elbow-extension", 2, "highCablePushdown"),
            ("elbow-extension", 3, "overheadCableExtension"),
        )
        for family_id, exercise_index, geometry in geometry_mutations:
            with self.subTest(
                family=family_id,
                exercise=exercise_index,
                geometry=geometry,
            ):
                family = copy.deepcopy(self.batch2_families[family_id])
                family["exercises"][exercise_index]["variant"][
                    "resistanceGeometry"
                ] = geometry
                with self.assertRaises(catalog.ValidationFailure):
                    catalog.validate_family(
                        family,
                        self.foundation,
                        f"mutated {family_id}",
                    )

        family = copy.deepcopy(extension)
        family["exercises"][2]["variant"]["handleType"] = (
            "singleCableHandle"
        )
        self.assert_batch2_family_fails(
            family,
            r"violates exercise rule "
            r"overhead-cable-preserves-unreported-interface",
        )

    def test_batch2_evidence_scopes_preserve_material_limitations(self) -> None:
        source_by_id = {
            source["id"]: source
            for source in self.foundation.evidence["sources"]
        }
        expected_scope_phrases = {
            "szymanski-2004-wrist-forearm-training": (
                "laboratory restraint"
            ),
            "fukunaga-2023-flexor-pronator-exercises": (
                "unmeasured muscles cannot be ranked inactive"
            ),
            "forman-2020-dynamic-wrist-flexion-extension": (
                "not equivalence between the robot handle"
            ),
            "coratella-2023-curl-handgrips": (
                "brachialis was not measured"
            ),
            "kleiber-2015-elbow-flexion-hand-position": (
                "conflict with Coratella's orientation ordering"
            ),
            "alves-2018-triceps-shoulder-position": (
                "measured only the long and lateral triceps heads"
            ),
            "maeo-2023-overhead-neutral-elbow-extension": (
                "does not report the cable attachment"
            ),
            "villalba-2024-pushdown-forearm-position": (
                "attachment mechanics limit triceps ranking"
            ),
        }
        for source_id, phrase in expected_scope_phrases.items():
            with self.subTest(source=source_id):
                self.assertIn(phrase, source_by_id[source_id]["scope"])

    def test_batch3_activates_exactly_four_evidence_ready_families(
        self,
    ) -> None:
        expected = {
            "scapular-protraction": {
                "fixed": {
                    "mechanic": "isolation",
                    "pattern": None,
                    "direction": None,
                    "planes": ["transverse"],
                },
                "basis": ["scapula.protraction"],
                "prime": ["scapula.protraction"],
                "primary": ["serratus"],
                "group": {"default": "chest", "allowed": ["chest"]},
                "reps": {"minimum": 8, "maximum": 15},
                "evidence": [
                    "castelein-2016-serratus-pectoralis-minor-protraction",
                    "intelangelo-2022-supine-scapular-punch",
                    "seth-2019-shoulder-work",
                ],
                "roster": ["supine-dumbbell-scapular-punch"],
            },
            "scapular-elevation": {
                "fixed": {
                    "mechanic": "isolation",
                    "pattern": None,
                    "direction": None,
                    "planes": ["frontal"],
                },
                "basis": ["scapula.elevation"],
                "prime": [
                    "scapula.elevation",
                    "scapula.upwardRotation",
                ],
                "primary": ["levatorScapulae", "trapeziusUpper"],
                "group": {"default": "back", "allowed": ["back"]},
                "reps": {"minimum": 2, "maximum": 15},
                "evidence": [
                    "castelein-2016-scapular-muscles-shrug",
                    "lee-2016-stabilization-shrug-upward-rotation",
                    "seth-2019-shoulder-work",
                    "werthel-2019-trapezius-transfer",
                ],
                "roster": [
                    "single-arm-dumbbell-shrug",
                    "bilateral-30-degree-stabilization-shrug",
                ],
            },
            "dip": {
                "fixed": {
                    "mechanic": "compound",
                    "pattern": "push",
                    "direction": "vertical",
                    "planes": ["sagittal"],
                },
                "basis": ["shoulder.flexion"],
                "prime": [
                    {
                        "action": "shoulder.flexion",
                        "condition": "fromExtendedPosition",
                    },
                    "elbow.extension",
                ],
                "primary": [
                    "pectoralisMajorClavicular",
                    "pectoralisMajorSternocostal",
                    "triceps",
                ],
                "group": {"default": "chest", "allowed": ["chest"]},
                "reps": {"minimum": 5, "maximum": 15},
                "evidence": [
                    "ackland-2008-shoulder-moment-arms",
                    "cinarli-2021-parallel-bar-dip",
                    "da-silva-2022-ring-dip-pectoralis-rupture",
                    "mckenzie-2022-dip-variations",
                    "mckenzie-2022-bar-dip-fatigue",
                ],
                "roster": ["bar-dip", "ring-dip"],
            },
            "push-press": {
                "fixed": {
                    "mechanic": "compound",
                    "pattern": "push",
                    "direction": "vertical",
                    "planes": ["sagittal", "frontal"],
                },
                "basis": ["shoulder.flexion", "shoulder.abduction"],
                "prime": [
                    "shoulder.flexion",
                    "shoulder.abduction",
                    "scapula.upwardRotation",
                    "scapula.posteriorTilt",
                    "elbow.extension",
                    "hip.extension",
                    "knee.extension",
                    "ankle.plantarflexion",
                ],
                "primary": ["deltoidAnterior", "vasti", "gluteMax"],
                "group": {
                    "default": "shoulders",
                    "allowed": ["shoulders"],
                },
                "reps": {"minimum": 1, "maximum": 6},
                "evidence": [
                    "ackland-2008-shoulder-moment-arms",
                    "arnold-2010-lower-limb",
                    "chiu-2006-push-press-joint-kinetics",
                    "coratella-2022-overhead-press-variants",
                    "ichihashi-2014-military-press-kinematics",
                    "lake-2014-push-press-power",
                    "seth-2019-shoulder-work",
                    "soriano-2024-push-press-jerk",
                ],
                "roster": ["barbell-push-press"],
            },
        }
        self.assertEqual(set(self.batch3_families), set(expected))

        for family_id, contract in expected.items():
            with self.subTest(family=family_id):
                family = self.batch3_families[family_id]
                self.assertEqual(family["fixed"], contract["fixed"])
                self.assertEqual(
                    family["movementSignature"]["planeBasisActions"],
                    contract["basis"],
                )
                self.assertEqual(
                    family["movementSignature"]["primeActions"],
                    contract["prime"],
                )
                self.assertEqual(
                    family["musclePolicy"]["allowedByRole"]["primary"],
                    contract["primary"],
                )
                self.assertEqual(family["groupPolicy"], contract["group"])
                self.assertEqual(
                    family["recommended"]["defaultReps"],
                    contract["reps"],
                )
                self.assertEqual(family["evidenceRefs"], contract["evidence"])
                self.assertEqual(
                    [
                        exercise["catalogID"]
                        for exercise in family["exercises"]
                    ],
                    contract["roster"],
                )

    def test_batch3_exact_involvement_rosters_are_pinned(self) -> None:
        expected = {
            "supine-dumbbell-scapular-punch": {
                "serratus": "primary",
                "pectoralisMinor": "secondary",
                "externalRotators": "stabilizer",
                "triceps": "stabilizer",
                "extensorCarpiRadialis": "stabilizer",
                "fingerFlexors": "stabilizer",
            },
            "single-arm-dumbbell-shrug": {
                "levatorScapulae": "primary",
                "trapeziusUpper": "primary",
                "serratus": "secondary",
                "externalRotators": "stabilizer",
                "triceps": "stabilizer",
                "extensorCarpiRadialis": "stabilizer",
                "fingerFlexors": "stabilizer",
                "abs": "stabilizer",
                "obliques": "stabilizer",
                "lumbarExtensors": "stabilizer",
            },
            "bilateral-30-degree-stabilization-shrug": {
                "levatorScapulae": "primary",
                "trapeziusUpper": "primary",
                "serratus": "secondary",
                "trapeziusLower": "secondary",
                "externalRotators": "stabilizer",
                "triceps": "stabilizer",
                "deltoidLateral": "stabilizer",
                "supraspinatus": "stabilizer",
                "abs": "stabilizer",
                "obliques": "stabilizer",
                "lumbarExtensors": "stabilizer",
            },
            "bar-dip": {
                "pectoralisMajorClavicular": "primary",
                "pectoralisMajorSternocostal": "primary",
                "triceps": "primary",
                "deltoidAnterior": "secondary",
                "serratus": "stabilizer",
                "externalRotators": "stabilizer",
                "fingerFlexors": "stabilizer",
                "extensorCarpiRadialis": "stabilizer",
                "abs": "stabilizer",
                "obliques": "stabilizer",
                "lumbarExtensors": "stabilizer",
            },
            "ring-dip": {
                "pectoralisMajorClavicular": "primary",
                "pectoralisMajorSternocostal": "primary",
                "triceps": "primary",
                "deltoidAnterior": "secondary",
                "serratus": "stabilizer",
                "externalRotators": "stabilizer",
                "lats": "stabilizer",
                "bicepsBrachii": "stabilizer",
                "fingerFlexors": "stabilizer",
                "extensorCarpiRadialis": "stabilizer",
                "abs": "stabilizer",
                "obliques": "stabilizer",
                "lumbarExtensors": "stabilizer",
            },
            "barbell-push-press": {
                "deltoidAnterior": "primary",
                "vasti": "primary",
                "gluteMax": "primary",
                "deltoidLateral": "secondary",
                "supraspinatus": "secondary",
                "triceps": "secondary",
                "serratus": "secondary",
                "trapeziusUpper": "secondary",
                "trapeziusLower": "secondary",
                "rectusFemoris": "secondary",
                "gastrocnemius": "secondary",
                "soleus": "secondary",
                "extensorCarpiRadialis": "stabilizer",
                "fingerFlexors": "stabilizer",
                "externalRotators": "stabilizer",
                "subscapularis": "stabilizer",
                "abs": "stabilizer",
                "obliques": "stabilizer",
                "lumbarExtensors": "stabilizer",
            },
        }
        actual = {
            exercise["catalogID"]: {
                assignment["muscle"]: assignment["role"]
                for assignment in exercise["involvement"]
            }
            for family in self.batch3_families.values()
            for exercise in family["exercises"]
        }
        self.assertEqual(actual, expected)

    def test_unsupported_suspended_dips_share_the_pullup_trunk_policy(
        self,
    ) -> None:
        expected = {"abs", "obliques", "lumbarExtensors"}
        for family in (self.vertical_pull, self.batch3_families["dip"]):
            for exercise in family["exercises"]:
                variant = exercise["variant"]
                if not (
                    variant["bodyPosition"] == "suspended"
                    and variant["lowerBodySupport"] == "none"
                ):
                    continue
                assigned = {
                    item["muscle"]
                    for item in exercise["involvement"]
                    if item["role"] == "stabilizer"
                }
                with self.subTest(exercise=exercise["catalogID"]):
                    self.assertTrue(expected <= assigned)

    def test_dip_sternocostal_flexion_gap_is_closed_narrowly(self) -> None:
        capabilities = self.foundation.capabilities_by_muscle[
            "pectoralisMajorSternocostal"
        ]
        self.assertEqual(
            self.foundation.condition_actions["fromExtendedPosition"],
            {"shoulder.flexion"},
        )
        self.assertNotIn(("shoulder.flexion", None), capabilities)
        self.assertIn(
            ("shoulder.flexion", "fromExtendedPosition"),
            capabilities,
        )

        dip = self.batch3_families["dip"]
        self.assertEqual(
            dip["movementSignature"]["primeActions"][0],
            {
                "action": "shoulder.flexion",
                "condition": "fromExtendedPosition",
            },
        )
        for exercise in dip["exercises"]:
            with self.subTest(exercise=exercise["catalogID"]):
                roles = {
                    assignment["muscle"]: assignment["role"]
                    for assignment in exercise["involvement"]
                }
                self.assertEqual(
                    roles["pectoralisMajorSternocostal"],
                    "primary",
                )

        consumers = {
            family["id"]
            for family in self.real_families
            if any(
                isinstance(requirement, dict)
                and requirement.get("condition") == "fromExtendedPosition"
                for requirement in (
                    family["movementSignature"]["primeActions"]
                    + family["movementSignature"].get("resistedActions", [])
                )
            )
        }
        self.assertEqual(consumers, {"dip"})
        for family_id in {
            "push-press",
            "shoulder-flexion-raise",
            "vertical-press",
        }:
            family = next(
                family for family in self.real_families
                if family["id"] == family_id
            )
            for exercise in family["exercises"]:
                self.assertNotIn(
                    "pectoralisMajorSternocostal",
                    {
                        assignment["muscle"]
                        for assignment in exercise["involvement"]
                    },
                    exercise["catalogID"],
                )

        roadmap = (
            catalog.SPEC_ROOT / "family-roadmap.md"
        ).read_text(encoding="utf-8")
        proposal = (
            catalog.SPEC_ROOT
            / "proposals"
            / "batch-3-dip-closed-chain.md"
        ).read_text(encoding="utf-8")
        normalized_proposal = " ".join(proposal.split())
        foundation_readme = (
            catalog.SPEC_ROOT / "README.md"
        ).read_text(encoding="utf-8")
        self.assertIn("Four work items remain unresolved", roadmap)
        self.assertIn(
            "Sternocostal flexion from an extended start — complete",
            roadmap,
        )
        self.assertIn(
            "Resolved foundation condition: sternocostal flexion from extension",
            proposal,
        )
        self.assertIn("triangulated basis", normalized_proposal)
        self.assertIn("closing the prior user-visible zero-credit gap", normalized_proposal)
        self.assertIn(
            "symmetry of naming is not evidence of symmetry of function",
            foundation_readme,
        )
        self.assertNotIn("tracked foundation hold", foundation_readme.lower())

    def test_batch3_authored_roster_surface_is_exactly_pinned(self) -> None:
        payload = []
        for family_id in sorted(self.batch3_families):
            family = self.batch3_families[family_id]
            payload.append(
                {
                    "familyID": family_id,
                    "familyEvidenceRefs": family["evidenceRefs"],
                    "exercises": [
                        {
                            key: exercise[key]
                            for key in (
                                "catalogID",
                                "name",
                                "aliases",
                                "variant",
                                "evidenceRefs",
                                "movementDefinition",
                            )
                        }
                        for exercise in family["exercises"]
                    ],
                }
            )
        encoded = json.dumps(
            payload,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
        self.assertEqual(
            hashlib.sha256(encoded).hexdigest(),
            "da07e9c428c77ed6eddd5ede6456c88120d4a0ef76211a83e28db49562a1461e",
        )

    def test_batch3_variant_axis_contracts_are_exact_and_covered(
        self,
    ) -> None:
        expected = {
            "scapular-protraction": {
                "kineticChain": ("enum", ("open",)),
                "bodyPosition": ("enum", ("supine",)),
                "torsoSupport": ("enum", ("bench",)),
                "scapularTranslation": (
                    "enum",
                    ("supportConstrained",),
                ),
                "upperArmPosition": ("enum", ("flexed90",)),
                "humeralRotation": ("enum", ("neutral",)),
                "elbowMotion": ("enum", ("angleHeld",)),
                "elbowPosture": ("enum", ("extended",)),
                "forearmMotion": ("enum", ("angleHeld",)),
                "forearmOrientation": ("enum", ("neutral",)),
                "handTask": ("enum", ("staticImplementHold",)),
                "resistanceGeometry": (
                    "enum",
                    ("gravityLoadedDumbbell",),
                ),
                "fixedPath": ("boolean", False),
                "lowerBodyContribution": ("enum", ("none",)),
            },
            "scapular-elevation": {
                "kineticChain": ("enum", ("open",)),
                "bodyPosition": ("enum", ("standing",)),
                "torsoSupport": ("enum", ("none",)),
                "contralateralSupport": ("enum", ("none",)),
                "scapularTranslation": ("enum", ("free",)),
                "upperArmPosition": (
                    "enum", ("atSide", "abducted30")
                ),
                "humerothoracicElevationDegrees": (
                    "number", (0, 30)
                ),
                "elevationPlane": (
                    "enum", ("notApplicable", "frontal")
                ),
                "humeralRotation": (
                    "enum", ("neutral", "notReported")
                ),
                "elbowMotion": ("enum", ("angleHeld",)),
                "elbowPosture": ("enum", ("extended",)),
                "forearmMotion": ("enum", ("angleHeld",)),
                "forearmOrientation": (
                    "enum", ("neutral", "notReported")
                ),
                "handTask": (
                    "enum", ("staticImplementHold", "none")
                ),
                "resistanceGeometry": (
                    "enum", ("gravityLoadedDumbbell", "armSegmentGravity")
                ),
                "humerothoracicAngleControl": (
                    "enum", ("none", "digitalInclinometer")
                ),
                "craniocervicothoracicStabilization": (
                    "enum", ("none", "investigatorManual")
                ),
                "shrugHeightTarget": (
                    "enum", ("none", "individualMaximumTargetBars")
                ),
                "topHoldSeconds": ("number", (0, 5)),
                "wristGuide": (
                    "enum", ("none", "radialBordersAgainstPlasticGuides")
                ),
                "fixedPath": ("boolean", False),
                "lowerBodyContribution": ("enum", ("none",)),
                "neckContribution": ("enum", ("none",)),
            },
            "dip": {
                "kineticChain": ("enum", ("closed",)),
                "bodyPosition": ("enum", ("suspended",)),
                "torsoSupport": ("enum", ("none",)),
                "lowerBodySupport": ("enum", ("none",)),
                "scapularTranslation": ("enum", ("free",)),
                "pathConstraint": ("enum", ("free",)),
                "lowerBodyContribution": ("enum", ("none",)),
                "bodyweightApparatus": (
                    "enum",
                    ("fixedDipBars", "rings"),
                ),
                "handSupportConstraint": (
                    "enum",
                    ("fixed", "independentUnstable"),
                ),
            },
            "push-press": {
                "kineticChain": ("enum", ("open",)),
                "bodyPosition": ("enum", ("standing",)),
                "torsoSupport": ("enum", ("none",)),
                "scapularTranslation": ("enum", ("free",)),
                "pressInclinationDegrees": ("number", (90, 90)),
                "gripOrientation": ("enum", ("pronated",)),
                "fixedPath": ("boolean", False),
                "lowerBodyContribution": (
                    "enum",
                    ("countermovementPropulsion",),
                ),
                "pressPath": ("enum", ("frontScapular",)),
                "legDriveDipStyle": (
                    "enum",
                    ("pushPressCountermovement",),
                ),
                "receivingStrategy": (
                    "enum",
                    ("standingNoRedip",),
                ),
                "footContact": ("enum", ("continuous",)),
            },
        }
        for family_id, family in self.batch3_families.items():
            actual_contract = {}
            for axis in family["variantAxes"]:
                self.assertTrue(axis["required"])
                if axis["valueType"] == "enum":
                    actual_contract[axis["id"]] = (
                        "enum",
                        tuple(axis["allowedValues"]),
                    )
                    observed = {
                        exercise["variant"][axis["id"]]
                        for exercise in family["exercises"]
                    }
                    self.assertEqual(observed, set(axis["allowedValues"]))
                elif axis["valueType"] == "boolean":
                    actual_contract[axis["id"]] = (
                        "boolean",
                        axis["fixedValue"],
                    )
                    observed = {
                        exercise["variant"][axis["id"]]
                        for exercise in family["exercises"]
                    }
                    self.assertEqual(observed, {axis["fixedValue"]})
                elif axis["valueType"] == "number":
                    actual_contract[axis["id"]] = (
                        "number",
                        (axis["minimum"], axis["maximum"]),
                    )
                    observed = {
                        exercise["variant"][axis["id"]]
                        for exercise in family["exercises"]
                    }
                    self.assertEqual(
                        observed,
                        {axis["minimum"], axis["maximum"]},
                    )
                else:
                    self.fail(
                        f"unexpected Batch-3 axis type {axis['valueType']}"
                    )
            with self.subTest(family=family_id):
                self.assertEqual(actual_contract, expected[family_id])

    def test_batch3_forbidden_action_sets_are_exact_and_mutation_gated(
        self,
    ) -> None:
        dip_forbidden = {
            "shoulder.extension",
            "shoulder.abduction",
            "shoulder.adduction",
            "shoulder.horizontalAdduction",
            "shoulder.horizontalAbduction",
            "shoulder.internalRotation",
            "shoulder.externalRotation",
            "scapula.elevation",
            "scapula.depression",
            "scapula.protraction",
            "scapula.retraction",
            "scapula.upwardRotation",
            "scapula.downwardRotation",
            "scapula.anteriorTilt",
            "scapula.posteriorTilt",
            "spine.flexion",
            "spine.extension",
            "spine.lateralFlexion",
            "spine.rotation",
            "hip.extension",
            "knee.extension",
            "ankle.plantarflexion",
        }
        for family_id, original in self.batch3_families.items():
            prime_ids = {
                action if isinstance(action, str) else action["action"]
                for action in original["movementSignature"]["primeActions"]
            }
            expected = (
                dip_forbidden
                if family_id == "dip"
                else set(self.foundation.action_ids) - prime_ids
            )
            self.assertEqual(
                set(
                    original["movementSignature"][
                        "forbiddenPrimeActions"
                    ]
                ),
                expected,
            )
            for action in expected:
                with self.subTest(family=family_id, action=action):
                    family = copy.deepcopy(original)
                    family["exercises"][0]["additionalPrimeActions"] = [
                        action
                    ]
                    self.assert_batch3_family_fails(
                        family,
                        f"declares forbidden prime action {re.escape(action)}",
                    )

    def test_every_dip_rule_has_a_match_and_a_contrast(self) -> None:
        family = self.batch3_families["dip"]
        self.assertEqual(
            [rule["id"] for rule in family["exerciseRules"]],
            [
                "dip-bars-use-fixed-support",
                "rings-use-independent-unstable-support",
            ],
        )
        for rule in family["exerciseRules"]:
            matches = [
                self.rule_matches_exercise(rule, exercise)
                for exercise in family["exercises"]
            ]
            with self.subTest(rule=rule["id"]):
                self.assertEqual(matches.count(True), 1)
                self.assertEqual(matches.count(False), 1)

    def test_every_dip_rule_consequence_has_a_direct_mutation(self) -> None:
        family = self.batch3_families["dip"]
        mutation_count = 0
        for rule in family["exerciseRules"]:
            matching = next(
                exercise
                for exercise in family["exercises"]
                if self.rule_matches_exercise(rule, exercise)
            )
            expected_message = "violates exercise rule " + re.escape(
                rule["id"]
            )

            for assertion in rule["then"]:
                mutated = copy.deepcopy(matching)
                self.set_rule_field(
                    mutated,
                    assertion["field"],
                    "mutated",
                )
                with self.subTest(
                    rule=rule["id"],
                    assertion=assertion["field"],
                ):
                    with self.assertRaisesRegex(
                        catalog.ValidationFailure,
                        expected_message,
                    ):
                        catalog.validate_exercise_rule_matches(
                            mutated,
                            [rule],
                            "mutated Batch-3 dip",
                        )
                mutation_count += 1

            for assignment in rule.get("requireInvolvement", []):
                mutated = copy.deepcopy(matching)
                mutated["involvement"] = [
                    item
                    for item in mutated["involvement"]
                    if item["muscle"] != assignment["muscle"]
                ]
                with self.subTest(
                    rule=rule["id"],
                    muscle=assignment["muscle"],
                ):
                    with self.assertRaisesRegex(
                        catalog.ValidationFailure,
                        expected_message,
                    ):
                        catalog.validate_exercise_rule_matches(
                            mutated,
                            [rule],
                            "mutated Batch-3 dip",
                        )
                mutation_count += 1

        self.assertEqual(mutation_count, 4)

    def test_dip_condition_and_sternocostal_role_are_directly_mutated(
        self,
    ) -> None:
        original = self.batch3_families["dip"]

        family = copy.deepcopy(original)
        family["movementSignature"]["primeActions"][0] = "shoulder.flexion"
        self.assert_batch3_family_fails(
            family,
            "primary muscle pectoralisMajorSternocostal cannot produce any declared prime action",
        )

        for exercise_index, exercise in enumerate(original["exercises"]):
            family = copy.deepcopy(original)
            family["exercises"][exercise_index]["involvement"] = [
                assignment
                for assignment in family["exercises"][exercise_index][
                    "involvement"
                ]
                if assignment["muscle"] != "pectoralisMajorSternocostal"
            ]
            with self.subTest(exercise=exercise["catalogID"], mutation="remove"):
                self.assert_batch3_family_fails(
                    family,
                    "fails muscle requirement 1",
                )

            family = copy.deepcopy(original)
            family["musclePolicy"]["allowedByRole"]["secondary"].append(
                "pectoralisMajorSternocostal"
            )
            assignment = next(
                item
                for item in family["exercises"][exercise_index]["involvement"]
                if item["muscle"] == "pectoralisMajorSternocostal"
            )
            assignment["role"] = "secondary"
            with self.subTest(exercise=exercise["catalogID"], mutation="demote"):
                self.assert_batch3_family_fails(
                    family,
                    "fails muscle requirement 1",
                )

    def test_batch3_every_required_muscle_assignment_is_mutation_gated(
        self,
    ) -> None:
        mutation_count = 0
        for family_id, original in self.batch3_families.items():
            for exercise_index, exercise in enumerate(original["exercises"]):
                for requirement_index, requirement in enumerate(
                    original["musclePolicy"]["requirements"]
                ):
                    family = copy.deepcopy(original)
                    family["exercises"][exercise_index]["involvement"] = [
                        assignment
                        for assignment in family["exercises"][
                            exercise_index
                        ]["involvement"]
                        if assignment["muscle"] not in requirement["anyOf"]
                    ]
                    with self.subTest(
                        family=family_id,
                        exercise=exercise["catalogID"],
                        requirement=requirement_index,
                    ):
                        self.assert_batch3_family_fails(
                            family,
                            (
                                "fails muscle requirement "
                                f"{requirement_index}"
                                "|requires at least one primary muscle"
                                "|group .* has no matching primary muscle"
                            ),
                        )
                    mutation_count += 1
        self.assertEqual(mutation_count, 57)

    def test_batch3_cross_family_press_and_scapular_boundaries_are_pinned(
        self,
    ) -> None:
        push_press = self.batch3_families["push-press"]
        strict_press = self.vertical_press
        lower_body_actions = {
            "hip.extension",
            "knee.extension",
            "ankle.plantarflexion",
        }
        strict_prime = strict_press["movementSignature"]["primeActions"]
        push_prime = push_press["movementSignature"]["primeActions"]
        self.assertEqual(push_prime[: len(strict_prime)], strict_prime)
        self.assertEqual(set(push_prime) - set(strict_prime), lower_body_actions)
        self.assertTrue(
            lower_body_actions
            <= set(strict_press["movementSignature"]["forbiddenPrimeActions"])
        )
        strict_lower_body = next(
            axis
            for axis in strict_press["variantAxes"]
            if axis["id"] == "lowerBodyContribution"
        )
        self.assertEqual(strict_lower_body["allowedValues"], ["none"])

        elevation = self.batch3_families["scapular-elevation"]
        protraction = self.batch3_families["scapular-protraction"]
        self.assertEqual(
            elevation["movementSignature"]["planeBasisActions"],
            ["scapula.elevation"],
        )
        self.assertIn(
            "scapula.upwardRotation",
            elevation["movementSignature"]["primeActions"],
        )
        self.assertEqual(
            elevation["musclePolicy"]["allowedByRole"]["secondary"],
            ["serratus", "trapeziusLower"],
        )
        self.assertIn(
            "model-specific abduction/adduction",
            elevation["definition"],
        )
        self.assertIn(
            "winging coordinates; those remain disclosed coupling",
            elevation["definition"],
        )
        self.assertIn(
            "scapula.upwardRotation",
            protraction["movementSignature"]["forbiddenPrimeActions"],
        )

        dip = self.batch3_families["dip"]
        self.assertEqual(
            dip["movementSignature"]["primeActions"],
            [
                {
                    "action": "shoulder.flexion",
                    "condition": "fromExtendedPosition",
                },
                "elbow.extension",
            ],
        )
        self.assertTrue(
            {
                "shoulder.extension",
                "scapula.depression",
                "scapula.protraction",
            }
            <= set(dip["movementSignature"]["forbiddenPrimeActions"])
        )
        self.assertEqual(
            dip["musclePolicy"]["allowedByRole"]["secondary"],
            ["deltoidAnterior"],
        )

        push_press = self.batch3_families["push-press"]
        self.assertTrue(
            {"wrist", "hand"}
            <= set(push_press["movementSignature"]["stabilityDemands"])
        )

        mutations = (
            ("scapular-protraction", "scapula.upwardRotation"),
            ("scapular-elevation", "shoulder.abduction"),
            ("dip", "shoulder.extension"),
            ("dip", "scapula.depression"),
            ("push-press", "hip.flexion"),
        )
        for family_id, action in mutations:
            family = copy.deepcopy(self.batch3_families[family_id])
            family["exercises"][0]["additionalPrimeActions"] = [action]
            with self.subTest(family=family_id, action=action):
                self.assert_batch3_family_fails(
                    family,
                    f"declares forbidden prime action {re.escape(action)}",
                )

    def test_batch3_one_record_contracts_keep_invariants_at_axis_level(
        self,
    ) -> None:
        expected_seeds = {
            "scapular-protraction": (
                "supine-dumbbell-scapular-punch",
                "dynamicStrength",
                5,
                2.5,
                12,
            ),
            "push-press": (
                "barbell-push-press",
                "power",
                45,
                20,
                5,
            ),
        }
        for family_id, seed in expected_seeds.items():
            family = self.batch3_families[family_id]
            self.assertEqual(len(family["exercises"]), 1)
            self.assertEqual(family["exerciseRules"], [])
            exercise = family["exercises"][0]
            self.assertEqual(
                (
                    exercise["catalogID"],
                    exercise["modality"],
                    exercise["defaultWeight"],
                    exercise["defaultWeightKg"],
                    exercise["reps"],
                ),
                seed,
            )
            self.assertEqual(exercise["additionalPrimeActions"], [])
            self.assertEqual(exercise["additionalStabilityDemands"], [])
            self.assertEqual(
                set(exercise["variant"]),
                {axis["id"] for axis in family["variantAxes"]},
            )
            self.assertTrue(all(axis["required"] for axis in family["variantAxes"]))

        boundary_mutations = (
            (
                "scapular-protraction",
                "variant.elbowMotion",
                "dynamic",
            ),
            (
                "push-press",
                "variant.receivingStrategy",
                "receivingDip",
            ),
            (
                "push-press",
                "variant.footContact",
                "displaced",
            ),
            (
                "push-press",
                "variant.pressInclinationDegrees",
                89,
            ),
        )
        for family_id, field, value in boundary_mutations:
            family = copy.deepcopy(self.batch3_families[family_id])
            self.set_rule_field(family["exercises"][0], field, value)
            with self.subTest(family=family_id, field=field):
                self.assert_batch3_family_fails(
                    family,
                    re.escape(field),
                )

    def test_batch3_dip_load_and_apparatus_semantics_are_exact(self) -> None:
        family = self.batch3_families["dip"]
        by_id = {
            exercise["catalogID"]: exercise
            for exercise in family["exercises"]
        }
        self.assertEqual(
            {
                catalog_id: (
                    exercise["loadMode"],
                    exercise["bodyweightFraction"],
                    exercise["defaultWeight"],
                    exercise.get("defaultWeightKg"),
                    exercise["variant"]["bodyweightApparatus"],
                    exercise["variant"]["handSupportConstraint"],
                )
                for catalog_id, exercise in by_id.items()
            },
            {
                "bar-dip": (
                    "bodyweightAdded",
                    1,
                    0,
                    None,
                    "fixedDipBars",
                    "fixed",
                ),
                "ring-dip": (
                    "bodyweightAdded",
                    1,
                    0,
                    None,
                    "rings",
                    "independentUnstable",
                ),
            },
        )
        bar_muscles = {
            assignment["muscle"]
            for assignment in by_id["bar-dip"]["involvement"]
        }
        ring_muscles = {
            assignment["muscle"]
            for assignment in by_id["ring-dip"]["involvement"]
        }
        self.assertEqual(ring_muscles - bar_muscles, {"lats", "bicepsBrachii"})

    def test_batch3_evidence_scopes_preserve_material_limitations(self) -> None:
        source_by_id = {
            source["id"]: source
            for source in self.foundation.evidence["sources"]
        }
        expected_scope_phrases = {
            "castelein-2016-serratus-pectoralis-minor-protraction": (
                "not numeric contribution weights or unmeasured scapular "
                "rotations and tilts"
            ),
            "intelangelo-2022-supine-scapular-punch": (
                "does not supply three-dimensional scapular kinematics"
            ),
            "castelein-2016-scapular-muscles-shrug": (
                "did not measure scapular kinematics"
            ),
            "mckenzie-2022-dip-variations": (
                "raw within-muscle EMG cannot rank different muscles"
            ),
            "mckenzie-2022-bar-dip-fatigue": (
                "does not establish a whole-pectoralis or between-muscle "
                "force ranking"
            ),
            "cinarli-2021-parallel-bar-dip": (
                "triangulated, exercise-specific basis"
            ),
            "da-silva-2022-ring-dip-pectoralis-rupture": (
                "cannot establish normal concentric recruitment"
            ),
            "chiu-2006-push-press-joint-kinetics": (
                "do not establish a categorical individual-muscle "
                "hierarchy or scapular actions"
            ),
            "lake-2014-push-press-power": (
                "does not provide joint-resolved moments, scapular "
                "kinematics, or a complete muscle-role panel"
            ),
            "soriano-2024-push-press-jerk": (
                "does not provide joint-resolved lower-limb moments, "
                "scapular kinematics, or a muscle-role hierarchy"
            ),
        }
        for source_id, phrase in expected_scope_phrases.items():
            with self.subTest(source=source_id):
                self.assertIn(phrase, source_by_id[source_id]["scope"])

    def test_batch3_deferred_candidates_remain_explicitly_gated(self) -> None:
        active_ids = {family["id"] for family in self.real_families}
        self.assertTrue(
            {"scapular-depression", "scapular-retraction"}.issubset(
                active_ids
            )
        )
        self.assertTrue(
            {
                "scapular-upward-rotation",
                "scapular-downward-rotation",
                "closed-chain-vertical-press",
                "landmine-press",
                "leg-driven-overhead-press",
            }.isdisjoint(active_ids)
        )
        self.assertIn("push-press", active_ids)

        proposals_root = catalog.SPEC_ROOT / "proposals"
        scapular = (
            proposals_root / "batch-3-scapular-actions.md"
        ).read_text(encoding="utf-8")
        dip = (
            proposals_root / "batch-3-dip-closed-chain.md"
        ).read_text(encoding="utf-8")
        power = (
            proposals_root / "batch-3-landmine-power.md"
        ).read_text(encoding="utf-8")
        self.assertIn("Three narrow contracts are active", scapular)
        self.assertIn(
            "`scapular-depression` | Active | McCabe unilateral "
            "overhead-band depression",
            scapular,
        )
        self.assertIn(
            "`scapular-upward-rotation` | Resolved without standalone family",
            scapular,
        )
        self.assertIn(
            "`scapular-downward-rotation` | Resolved: no standalone family",
            scapular,
        )
        self.assertIn(
            "`closed-chain-vertical-press` | Merge into `vertical-press`, "
            "defer branch",
            dip,
        )
        self.assertIn("`landmine-press` | Defer | 0", power)
        self.assertIn(
            "`leg-driven-overhead-press` | Resolve to and activate narrowly "
            "as `push-press` | 1",
            power,
        )

        evidence_ids = {
            source["id"] for source in self.foundation.evidence["sources"]
        }
        self.assertNotIn("zhao-2026-landmine-press-kinematics", evidence_ids)

    def test_batch4_activates_exactly_four_lower_body_isolation_families(
        self,
    ) -> None:
        expected = {
            "knee-extension": {
                "name": "Knee Extension",
                "basis": ["knee.extension"],
                "demands": ["hip", "knee"],
                "primary": ["vasti", "rectusFemoris"],
                "reps": {"minimum": 8, "maximum": 15},
                "evidence": [
                    "arnold-2010-lower-limb",
                    "larsen-2025-leg-extension-hip-flexion",
                    "mitsuya-2023-leg-extension-hip-flexion",
                ],
                "roster": [
                    "reclined-unilateral-machine-leg-extension",
                    "upright-unilateral-machine-leg-extension",
                ],
            },
            "knee-flexion": {
                "name": "Knee Flexion",
                "basis": ["knee.flexion"],
                "demands": ["pelvis", "hip", "knee"],
                "primary": ["medialHamstrings", "bicepsFemoris"],
                "reps": {"minimum": 8, "maximum": 15},
                "evidence": [
                    "arnold-2010-lower-limb",
                    "maeo-2021-seated-prone-leg-curl",
                    "gallucci-2002-gastrocnemius-leg-curl",
                ],
                "roster": [
                    "seated-unilateral-machine-leg-curl",
                    "prone-unilateral-machine-leg-curl",
                ],
            },
            "hip-extension": {
                "name": "Hip Extension Isolation",
                "basis": ["hip.extension"],
                "demands": ["hip", "pelvis", "knee", "spine"],
                "primary": ["gluteMax"],
                "reps": {"minimum": 8, "maximum": 15},
                "evidence": [
                    "arnold-2010-lower-limb",
                    "jeon-2016-prone-table-hip-extension",
                ],
                "roster": ["prone-table-bent-knee-hip-extension"],
            },
            "ankle-plantarflexion": {
                "name": "Ankle Plantarflexion",
                "basis": ["ankle.plantarflexion"],
                "demands": ["knee", "ankle", "foot"],
                "primary": ["soleus", "gastrocnemius"],
                "reps": {"minimum": 8, "maximum": 20},
                "evidence": [
                    "arnold-2010-lower-limb",
                    "kinoshita-2023-standing-seated-calf-raise",
                ],
                "roster": [
                    "standing-unilateral-machine-calf-raise",
                    "seated-unilateral-machine-calf-raise",
                ],
            },
        }
        self.assertEqual(set(self.batch4_families), set(expected))
        for family_id, contract in expected.items():
            with self.subTest(family=family_id):
                family = self.batch4_families[family_id]
                self.assertEqual(
                    family["fixed"],
                    {
                        "mechanic": "isolation",
                        "pattern": None,
                        "direction": None,
                        "planes": ["sagittal"],
                    },
                )
                self.assertEqual(family["name"], contract["name"])
                self.assertEqual(
                    family["movementSignature"]["planeBasisActions"],
                    contract["basis"],
                )
                self.assertEqual(
                    family["movementSignature"]["primeActions"],
                    contract["basis"],
                )
                self.assertEqual(
                    family["movementSignature"]["stabilityDemands"],
                    contract["demands"],
                )
                self.assertEqual(
                    family["musclePolicy"]["allowedByRole"]["primary"],
                    contract["primary"],
                )
                self.assertEqual(
                    family["groupPolicy"],
                    {"default": "legs", "allowed": ["legs"]},
                )
                self.assertEqual(
                    family["recommended"]["defaultReps"],
                    contract["reps"],
                )
                self.assertEqual(family["evidenceRefs"], contract["evidence"])
                self.assertEqual(
                    [exercise["catalogID"] for exercise in family["exercises"]],
                    contract["roster"],
                )

    def test_batch4_exact_exercise_surface_and_involvement_are_pinned(
        self,
    ) -> None:
        expected = {
            "reclined-unilateral-machine-leg-extension": {
                "name": "Reclined Unilateral Machine Leg Extension",
                "aliases": [
                    "40-Degree Single-Leg Extension",
                    "Reclined Single-Leg Extension",
                ],
                "setup": ("machine", "unilateral", "external", 20, 10, 12),
                "roles": {"vasti": "primary", "rectusFemoris": "primary"},
                "evidence": [
                    "larsen-2025-leg-extension-hip-flexion",
                    "mitsuya-2023-leg-extension-hip-flexion",
                ],
            },
            "upright-unilateral-machine-leg-extension": {
                "name": "Upright Unilateral Machine Leg Extension",
                "aliases": [
                    "90-Degree Single-Leg Extension",
                    "Upright Single-Leg Extension",
                ],
                "setup": ("machine", "unilateral", "external", 20, 10, 12),
                "roles": {"vasti": "primary", "rectusFemoris": "secondary"},
                "evidence": [
                    "larsen-2025-leg-extension-hip-flexion",
                    "mitsuya-2023-leg-extension-hip-flexion",
                ],
            },
            "seated-unilateral-machine-leg-curl": {
                "name": "Seated Unilateral Machine Leg Curl",
                "aliases": [
                    "Seated Single-Leg Curl",
                    "Unilateral Seated Leg Curl",
                ],
                "setup": ("machine", "unilateral", "external", 20, 10, 10),
                "roles": {
                    "medialHamstrings": "primary",
                    "bicepsFemoris": "primary",
                    "sartorius": "secondary",
                    "gracilis": "secondary",
                },
                "evidence": ["maeo-2021-seated-prone-leg-curl"],
            },
            "prone-unilateral-machine-leg-curl": {
                "name": "Prone Unilateral Machine Leg Curl",
                "aliases": [
                    "Lying Single-Leg Curl",
                    "Unilateral Prone Leg Curl",
                ],
                "setup": ("machine", "unilateral", "external", 20, 10, 10),
                "roles": {
                    "medialHamstrings": "primary",
                    "bicepsFemoris": "primary",
                    "sartorius": "secondary",
                    "gracilis": "secondary",
                },
                "evidence": ["maeo-2021-seated-prone-leg-curl"],
            },
            "prone-table-bent-knee-hip-extension": {
                "name": "Prone Table Bent-Knee Hip Extension",
                "aliases": [
                    "Prone Table Hip Extension",
                    "Bent-Knee Prone Hip Extension",
                ],
                "setup": ("bodyweight", "unilateral", "nonComparable", 0, None, 10),
                "roles": {
                    "gluteMax": "primary",
                    "medialHamstrings": "secondary",
                    "bicepsFemoris": "stabilizer",
                    "lumbarExtensors": "stabilizer",
                },
                "evidence": [
                    "arnold-2010-lower-limb",
                    "jeon-2016-prone-table-hip-extension",
                ],
            },
            "standing-unilateral-machine-calf-raise": {
                "name": "Standing Unilateral Machine Calf Raise",
                "aliases": [
                    "Single-Leg Standing Calf Raise",
                    "Single-Leg Standing Calf Raise Machine",
                ],
                "setup": ("machine", "unilateral", "external", 20, 10, 10),
                "roles": {"gastrocnemius": "primary", "soleus": "primary"},
                "evidence": ["kinoshita-2023-standing-seated-calf-raise"],
            },
            "seated-unilateral-machine-calf-raise": {
                "name": "Seated Unilateral Machine Calf Raise",
                "aliases": [
                    "Single-Leg Seated Calf Raise",
                    "Single-Leg Seated Calf Raise Machine",
                ],
                "setup": ("machine", "unilateral", "external", 20, 10, 10),
                "roles": {"soleus": "primary", "gastrocnemius": "secondary"},
                "evidence": ["kinoshita-2023-standing-seated-calf-raise"],
            },
        }
        actual = {}
        for family in self.batch4_families.values():
            for exercise in family["exercises"]:
                actual[exercise["catalogID"]] = {
                    "name": exercise["name"],
                    "aliases": exercise["aliases"],
                    "setup": (
                        exercise["equipment"],
                        exercise["laterality"],
                        exercise["loadMode"],
                        exercise["defaultWeight"],
                        exercise.get("defaultWeightKg"),
                        exercise["reps"],
                    ),
                    "roles": {
                        item["muscle"]: item["role"]
                        for item in exercise["involvement"]
                    },
                    "evidence": exercise["evidenceRefs"],
                }
                self.assertEqual(exercise["additionalPrimeActions"], [])
                self.assertEqual(exercise["additionalStabilityDemands"], [])
                self.assertTrue(exercise["movementDefinition"])
        self.assertEqual(actual, expected)

    def test_batch4_variant_axis_contracts_are_exact_and_fully_covered(
        self,
    ) -> None:
        def enum(*values: object) -> tuple[str, tuple[object, ...]]:
            return ("enum", values)

        def number(
            minimum: int,
            maximum: int,
        ) -> tuple[str, int, int]:
            return ("number", minimum, maximum)
        expected = {
            "knee-extension": {
                "kineticChain": enum("open"),
                "bodyPosition": enum("reclined", "seated"),
                "torsoSupport": enum("machinePad"),
                "pelvisSupport": enum("machineSeat"),
                "pelvisMotion": enum("positionHeld"),
                "spineMotion": enum("positionHeld"),
                "hipMotion": enum("positionHeld"),
                "hipFlexionDegrees": number(40, 90),
                "kneeMotion": enum("extends"),
                "kneeStartFlexionDegrees": number(110, 110),
                "kneeEndFlexionDegrees": number(0, 0),
                "ankleMotion": enum("positionHeld"),
                "footMotion": enum("positionHeld"),
                "movingSegment": enum("lowerLeg"),
                "loadInterface": enum("distalShinPad"),
                "machineType": enum("leverKneeExtension"),
                "fixedPath": ("boolean", True),
                "lowerBodyContribution": enum("isolatedJointMotion"),
            },
            "knee-flexion": {
                "kineticChain": enum("open"),
                "bodyPosition": enum("seated", "prone"),
                "torsoSupport": enum("machinePad"),
                "pelvisSupport": enum("machinePadAndStrap"),
                "pelvisMotion": enum("positionHeld"),
                "spineMotion": enum("positionHeld"),
                "hipMotion": enum("positionHeld"),
                "hipFlexionDegrees": number(30, 90),
                "kneeMotion": enum("flexes"),
                "kneeStartFlexionDegrees": number(0, 0),
                "kneeEndFlexionDegrees": number(90, 90),
                "ankleMotion": enum("positionHeld"),
                "anklePosture": enum("unreported"),
                "footMotion": enum("positionHeld"),
                "movingSegment": enum("lowerLeg"),
                "loadInterface": enum("distalShinPad"),
                "machineType": enum("leverLegCurl"),
                "fixedPath": ("boolean", True),
                "lowerBodyContribution": enum("isolatedJointMotion"),
            },
            "hip-extension": {
                "kineticChain": enum("open"),
                "bodyPosition": enum("prone"),
                "torsoSupport": enum("table"),
                "pelvisSupport": enum("table"),
                "pelvisMotion": enum("positionHeld"),
                "spineMotion": enum("positionHeld"),
                "hipMotion": enum("extends"),
                "hipStartFlexionDegrees": number(30, 30),
                "hipEndExtensionDegrees": number(5, 5),
                "kneeMotion": enum("positionHeld"),
                "kneeFlexionDegrees": number(90, 90),
                "movingSegment": enum("thigh"),
                "loadInterface": enum("none"),
                "resistanceGeometry": enum("limbSegmentGravity"),
                "fixedPath": ("boolean", False),
                "lowerBodyContribution": enum("isolatedJointMotion"),
            },
            "ankle-plantarflexion": {
                "kineticChain": enum("closed"),
                "bodyPosition": enum("standing", "seated"),
                "torsoSupport": enum("none"),
                "pelvisSupport": enum("none", "machineSeat"),
                "pelvisMotion": enum("positionHeld"),
                "spineMotion": enum("positionHeld"),
                "hipMotion": enum("positionHeld"),
                "kneeMotion": enum("positionHeld"),
                "kneeFlexionDegrees": number(0, 90),
                "ankleMotion": enum("plantarflexes"),
                "footMotion": enum("positionHeld"),
                "footOrientation": enum("neutral"),
                "movingSegment": enum("foot"),
                "forefootSupport": enum("machinePlatform"),
                "heelSupport": enum("none"),
                "loadInterface": enum("shoulderPad", "distalThighPad"),
                "machineType": enum(
                    "standingCalfRaise", "seatedCalfRaise"
                ),
                "fixedPath": ("boolean", True),
                "lowerBodyContribution": enum("isolatedJointMotion"),
            },
        }
        for family_id, family in self.batch4_families.items():
            actual = {}
            for axis in family["variantAxes"]:
                self.assertTrue(axis["required"])
                if axis["valueType"] == "enum":
                    actual[axis["id"]] = (
                        "enum",
                        tuple(axis["allowedValues"]),
                    )
                    observed = {
                        exercise["variant"][axis["id"]]
                        for exercise in family["exercises"]
                    }
                    self.assertEqual(observed, set(axis["allowedValues"]))
                elif axis["valueType"] == "number":
                    actual[axis["id"]] = (
                        "number",
                        axis["minimum"],
                        axis["maximum"],
                    )
                    observed = {
                        exercise["variant"][axis["id"]]
                        for exercise in family["exercises"]
                    }
                    self.assertEqual(
                        observed,
                        {axis["minimum"], axis["maximum"]},
                    )
                elif axis["valueType"] == "boolean":
                    actual[axis["id"]] = (
                        "boolean",
                        axis["fixedValue"],
                    )
                    self.assertEqual(
                        {
                            exercise["variant"][axis["id"]]
                            for exercise in family["exercises"]
                        },
                        {axis["fixedValue"]},
                    )
                else:
                    self.fail(
                        f"unexpected Batch-4 axis type {axis['valueType']}"
                    )
            with self.subTest(family=family_id):
                self.assertEqual(actual, expected[family_id])

    def test_batch4_machine_and_resistance_axes_are_nonredundant(self) -> None:
        machine_family_ids = {
            "knee-extension",
            "knee-flexion",
            "ankle-plantarflexion",
        }
        for family_id in machine_family_ids:
            axes = {
                axis["id"]
                for axis in self.batch4_families[family_id]["variantAxes"]
            }
            with self.subTest(machine_family=family_id):
                self.assertIn("machineType", axes)
                self.assertNotIn("resistanceGeometry", axes)
                for exercise in self.batch4_families[family_id]["exercises"]:
                    self.assertIn("machineType", exercise["variant"])
                    self.assertNotIn(
                        "resistanceGeometry", exercise["variant"]
                    )

        hip_extension = self.batch4_families["hip-extension"]
        hip_axes = {axis["id"] for axis in hip_extension["variantAxes"]}
        self.assertIn("resistanceGeometry", hip_axes)
        self.assertNotIn("machineType", hip_axes)
        self.assertEqual(
            hip_extension["exercises"][0]["variant"]["resistanceGeometry"],
            "limbSegmentGravity",
        )

    def test_batch4_stability_demands_have_exact_role_agnostic_providers(
        self,
    ) -> None:
        expected = {
            "knee-extension": {
                "hip": {"rectusFemoris"},
                "knee": {"vasti", "rectusFemoris"},
            },
            "knee-flexion": {
                "pelvis": {"medialHamstrings", "sartorius", "gracilis"},
                "hip": {"medialHamstrings", "sartorius", "gracilis"},
                "knee": {
                    "medialHamstrings",
                    "bicepsFemoris",
                    "sartorius",
                    "gracilis",
                },
            },
            "ankle-plantarflexion": {
                "knee": {"gastrocnemius"},
                "ankle": {"gastrocnemius", "soleus"},
                "foot": {"gastrocnemius", "soleus"},
            },
            "hip-extension": {
                "hip": {"gluteMax", "medialHamstrings"},
                "pelvis": {"gluteMax", "medialHamstrings", "lumbarExtensors"},
                "knee": {"medialHamstrings", "bicepsFemoris"},
                "spine": {"lumbarExtensors"},
            },
        }
        for family_id, family in self.batch4_families.items():
            for exercise in family["exercises"]:
                assigned = {
                    item["muscle"] for item in exercise["involvement"]
                }
                actual = {
                    region: {
                        muscle_id
                        for muscle_id in assigned
                        if region
                        in self.foundation.profile_by_muscle[muscle_id][
                            "stabilizes"
                        ]
                    }
                    for region in family["movementSignature"][
                        "stabilityDemands"
                    ]
                }
                with self.subTest(
                    family=family_id,
                    exercise=exercise["catalogID"],
                ):
                    self.assertEqual(actual, expected[family_id])

        for family_id in {
            "knee-extension",
            "knee-flexion",
            "ankle-plantarflexion",
        }:
            self.assertEqual(
                self.batch4_families[family_id]["musclePolicy"][
                    "allowedByRole"
                ]["stabilizer"],
                [],
            )
        self.assertEqual(
            self.batch4_families["hip-extension"]["musclePolicy"][
                "allowedByRole"
            ]["stabilizer"],
            ["bicepsFemoris", "lumbarExtensors"],
        )

    def test_batch4_forbids_every_other_known_prime_action(self) -> None:
        for family_id, original in self.batch4_families.items():
            own_action_ids = set(
                original["movementSignature"]["primeActions"]
            )
            expected = set(self.foundation.action_ids) - own_action_ids
            self.assertEqual(
                set(
                    original["movementSignature"]["forbiddenPrimeActions"]
                ),
                expected,
            )
            for action in expected:
                with self.subTest(family=family_id, action=action):
                    family = copy.deepcopy(original)
                    family["exercises"][0]["additionalPrimeActions"] = [
                        action
                    ]
                    self.assert_batch4_family_fails(
                        family,
                        f"declares forbidden prime action {re.escape(action)}",
                    )

    def test_batch4_boolean_fixed_path_invariants_are_directly_mutated(
        self,
    ) -> None:
        expected = {
            "knee-extension": True,
            "knee-flexion": True,
            "hip-extension": False,
            "ankle-plantarflexion": True,
        }
        for family_id, fixed_value in expected.items():
            original = self.batch4_families[family_id]
            axis = next(
                axis
                for axis in original["variantAxes"]
                if axis["id"] == "fixedPath"
            )
            self.assertEqual(
                axis,
                {
                    "id": "fixedPath",
                    "valueType": "boolean",
                    "required": True,
                    "fixedValue": fixed_value,
                    "description": axis["description"],
                },
            )
            for exercise_index, exercise in enumerate(original["exercises"]):
                family = copy.deepcopy(original)
                family["exercises"][exercise_index]["variant"][
                    "fixedPath"
                ] = not fixed_value
                with self.subTest(
                    family=family_id,
                    exercise=exercise["catalogID"],
                ):
                    self.assert_batch4_family_fails(
                        family,
                        (
                            r"variant\.fixedPath must equal fixed value "
                            f"{fixed_value}"
                        ),
                    )

    def test_batch4_hip_extension_setup_boundaries_are_directly_mutated(
        self,
    ) -> None:
        original = self.batch4_families["hip-extension"]
        mutations = (
            ("variant.pelvisMotion", "moves"),
            ("variant.spineMotion", "extends"),
            ("variant.kneeMotion", "flexes"),
            ("variant.kneeFlexionDegrees", 0),
            ("variant.torsoSupport", "none"),
            ("variant.pelvisSupport", "none"),
            ("variant.resistanceGeometry", "externalLoad"),
            ("variant.loadInterface", "ankleCuff"),
            ("laterality", "bilateral"),
            ("loadMode", "external"),
            ("equipment", "cable"),
        )
        for field, value in mutations:
            family = copy.deepcopy(original)
            self.set_rule_field(family["exercises"][0], field, value)
            expected_message = {
                "laterality": "lateralities",
                "loadMode": "loadModes",
                "equipment": "equipment",
            }.get(field, field.split(".")[-1])
            with self.subTest(field=field):
                self.assert_batch4_family_fails(
                    family,
                    re.escape(expected_message),
                )

        promoted = copy.deepcopy(original)
        exercise = promoted["exercises"][0]
        next(
            item
            for item in exercise["involvement"]
            if item["muscle"] == "bicepsFemoris"
        )["role"] = "secondary"
        promoted["musclePolicy"]["allowedByRole"]["secondary"].append(
            "bicepsFemoris"
        )
        promoted["musclePolicy"]["allowedByRole"]["stabilizer"].remove(
            "bicepsFemoris"
        )
        self.assert_batch4_family_fails(
            promoted,
            (
                "secondary muscle bicepsFemoris cannot produce any declared "
                "prime action"
            ),
        )

    def test_every_batch4_rule_has_a_match_and_a_contrast(self) -> None:
        expected_rule_ids = {
            "knee-extension": [
                "reclined-leg-extension-uses-reviewed-hip-angle",
                "forty-degree-leg-extension-is-reclined",
                "seated-leg-extension-uses-reviewed-hip-angle",
                "ninety-degree-leg-extension-is-seated",
            ],
            "knee-flexion": [
                "seated-leg-curl-uses-reviewed-hip-angle",
                "ninety-degree-leg-curl-is-seated",
                "prone-leg-curl-uses-reviewed-hip-angle",
                "thirty-degree-leg-curl-is-prone",
            ],
            "hip-extension": [],
            "ankle-plantarflexion": [
                "standing-calf-raise-uses-extended-knee-setup",
                "standing-calf-machine-requires-standing-setup",
                "seated-calf-raise-uses-flexed-knee-setup",
                "seated-calf-machine-requires-seated-setup",
            ],
        }
        for family_id, family in self.batch4_families.items():
            self.assertEqual(
                [rule["id"] for rule in family["exerciseRules"]],
                expected_rule_ids[family_id],
            )
            for rule in family["exerciseRules"]:
                matches = [
                    self.rule_matches_exercise(rule, exercise)
                    for exercise in family["exercises"]
                ]
                with self.subTest(family=family_id, rule=rule["id"]):
                    self.assertEqual(matches.count(True), 1)
                    self.assertEqual(matches.count(False), 1)

    def test_every_batch4_rule_assertion_has_a_direct_mutation(self) -> None:
        mutation_count = 0
        for family_id, family in self.batch4_families.items():
            for rule in family["exerciseRules"]:
                matching = next(
                    exercise
                    for exercise in family["exercises"]
                    if self.rule_matches_exercise(rule, exercise)
                )
                expected_message = "violates exercise rule " + re.escape(
                    rule["id"]
                )
                for assertion in rule["then"]:
                    mutated = copy.deepcopy(matching)
                    self.set_rule_field(
                        mutated,
                        assertion["field"],
                        "mutated",
                    )
                    with self.subTest(
                        family=family_id,
                        rule=rule["id"],
                        field=assertion["field"],
                    ):
                        with self.assertRaisesRegex(
                            catalog.ValidationFailure,
                            expected_message,
                        ):
                            catalog.validate_exercise_rule_matches(
                                mutated,
                                [rule],
                                "mutated Batch-4 rule assertion",
                            )
                    mutation_count += 1
                for assignment in rule.get("requireInvolvement", []):
                    mutated = copy.deepcopy(matching)
                    mutated["involvement"] = [
                        item
                        for item in mutated["involvement"]
                        if item["muscle"] != assignment["muscle"]
                    ]
                    with self.subTest(
                        family=family_id,
                        rule=rule["id"],
                        muscle=assignment["muscle"],
                    ):
                        with self.assertRaisesRegex(
                            catalog.ValidationFailure,
                            expected_message,
                        ):
                            catalog.validate_exercise_rule_matches(
                                mutated,
                                [rule],
                                "mutated Batch-4 role assertion",
                            )
                    mutation_count += 1
        self.assertEqual(mutation_count, 28)

    def test_batch4_required_muscles_and_posture_roles_are_mutation_gated(
        self,
    ) -> None:
        mutation_count = 0
        for family_id, original in self.batch4_families.items():
            for exercise_index, exercise in enumerate(original["exercises"]):
                for requirement_index, requirement in enumerate(
                    original["musclePolicy"]["requirements"]
                ):
                    family = copy.deepcopy(original)
                    family["exercises"][exercise_index]["involvement"] = [
                        assignment
                        for assignment in family["exercises"][exercise_index][
                            "involvement"
                        ]
                        if assignment["muscle"] not in requirement["anyOf"]
                    ]
                    with self.subTest(
                        family=family_id,
                        exercise=exercise["catalogID"],
                        requirement=requirement_index,
                    ):
                        self.assert_batch4_family_fails(
                            family,
                            (
                                "fails muscle requirement "
                                f"{requirement_index}"
                                "|requires at least one primary muscle"
                                "|group .* has no matching primary muscle"
                                "|no assigned muscle capable of stabilizing"
                            ),
                        )
                    mutation_count += 1
        self.assertEqual(mutation_count, 20)

        knee_extension = self.batch4_families["knee-extension"]
        ext_by_position = {
            exercise["variant"]["bodyPosition"]: {
                item["muscle"]: item["role"]
                for item in exercise["involvement"]
            }
            for exercise in knee_extension["exercises"]
        }
        self.assertEqual(ext_by_position["reclined"]["rectusFemoris"], "primary")
        self.assertEqual(ext_by_position["seated"]["rectusFemoris"], "secondary")

        plantarflexion = self.batch4_families["ankle-plantarflexion"]
        calf_by_position = {
            exercise["variant"]["bodyPosition"]: {
                item["muscle"]: item["role"]
                for item in exercise["involvement"]
            }
            for exercise in plantarflexion["exercises"]
        }
        self.assertEqual(calf_by_position["standing"]["gastrocnemius"], "primary")
        self.assertEqual(calf_by_position["seated"]["gastrocnemius"], "secondary")

    def test_batch4_taxonomy_boundaries_are_preserved_in_every_family(self) -> None:
        retired = {
            "quads",
            "hamstrings",
            "calves",
            "adductors",
            "hipFlexors",
            "shins",
        }
        for family in self.real_families:
            declared = set()
            for values in family["musclePolicy"]["allowedByRole"].values():
                declared.update(values)
            for requirement in family["musclePolicy"]["requirements"]:
                declared.update(requirement["anyOf"])
            for exercise in family["exercises"]:
                declared.update(
                    item["muscle"] for item in exercise["involvement"]
                )
            with self.subTest(family=family["id"]):
                self.assertTrue(retired.isdisjoint(declared))

        hip_extension = self.batch4_families["hip-extension"]
        roles = {
            item["muscle"]: item["role"]
            for item in hip_extension["exercises"][0]["involvement"]
        }
        self.assertNotIn(
            ("hip.extension", None),
            self.foundation.capabilities_by_muscle["bicepsFemoris"],
        )
        self.assertEqual(roles["bicepsFemoris"], "stabilizer")
        self.assertEqual(roles["medialHamstrings"], "secondary")

        knee_flexion = self.batch4_families["knee-flexion"]
        self.assertEqual(
            next(
                axis["allowedValues"]
                for axis in knee_flexion["variantAxes"]
                if axis["id"] == "anklePosture"
            ),
            ["unreported"],
        )
        self.assertNotIn(
            "gastrocnemius",
            {
                item["muscle"]
                for exercise in knee_flexion["exercises"]
                for item in exercise["involvement"]
            },
        )

    def test_batch4_evidence_scopes_preserve_material_limitations(self) -> None:
        source_by_id = {
            source["id"]: source
            for source in self.foundation.evidence["sources"]
        }
        expected_scope_phrases = {
            "larsen-2025-leg-extension-hip-flexion": (
                "not unmeasured vasti-head ranking, intermediate hip angles"
            ),
            "mitsuya-2023-leg-extension-hip-flexion": (
                "not long-term hypertrophy, other quadriceps-head roles"
            ),
            "maeo-2021-seated-prone-leg-curl": (
                "ankle posture was not reported and calf involvement was not measured"
            ),
            "gallucci-2002-gastrocnemius-leg-curl": (
                "not a categorical gastrocnemius role on the ankle-unreported"
            ),
            "kinoshita-2023-standing-seated-calf-raise": (
                "not a universal machine-stack seed or exact user range-of-motion"
            ),
            "jeon-2016-prone-table-hip-extension": (
                "not other apparatus, external loading, bilateral variants"
            ),
        }
        for source_id, phrase in expected_scope_phrases.items():
            with self.subTest(source=source_id):
                self.assertIn(phrase, source_by_id[source_id]["scope"])

    def test_batch4_hip_flexion_hold_is_resolved_by_exact_okubo_fixture(
        self,
    ) -> None:
        active_ids = {family["id"] for family in self.real_families}
        self.assertIn("hip-flexion", active_ids)
        self.assertTrue(
            (catalog.FAMILIES_ROOT / "hip-flexion.json").exists()
        )

        proposal = (
            catalog.SPEC_ROOT
            / "proposals"
            / "batch-4-hip-isolations.md"
        ).read_text(encoding="utf-8")
        roadmap = (catalog.SPEC_ROOT / "family-roadmap.md").read_text(
            encoding="utf-8"
        )
        normalized_proposal = " ".join(proposal.split())
        normalized_roadmap = " ".join(roadmap.split())
        self.assertIn("`hip-flexion` | Active | 1", normalized_proposal)
        self.assertIn(
            "does not revive the earlier position-held-pelvis proposal",
            normalized_proposal,
        )
        self.assertIn(
            "both motions as nonstandardized",
            normalized_proposal,
        )
        self.assertIn("| `hip-flexion` | 1 |", roadmap)
        self.assertIn(
            "held hip-flexion family later activated through an exact "
            "active-straight-leg-raise fixture",
            normalized_roadmap,
        )

        source = next(
            source
            for source in self.foundation.evidence["sources"]
            if source["id"]
            == "okubo-2021-end-range-active-straight-leg-raise"
        )
        self.assertEqual(source["sourceType"], "experimentalKinematicsEMGStudy")
        self.assertEqual(source["doi"], "10.1016/j.jelekin.2021.102588")
        self.assertEqual(source["pmid"], "34455371")
        self.assertIn("each participant's active end range", source["scope"])
        self.assertIn(
            "does not establish a universal endpoint angle, cadence, hold "
            "duration, external load, zero pelvic or spinal motion",
            source["scope"],
        )
        self.assertIn(
            "roles for sartorius, tensor fasciae latae, or adductors",
            source["scope"],
        )

    def test_batch5_activates_exactly_four_compound_families(self) -> None:
        expected = {
            "bilateral-squat": {
                "name": "Bilateral Squat",
                "fixed": {
                    "mechanic": "compound",
                    "pattern": "squat",
                    "direction": None,
                    "planes": ["sagittal"],
                },
                "prime": [
                    "hip.extension",
                    "knee.extension",
                    "ankle.plantarflexion",
                ],
                "demands": [
                    "shoulder", "scapula", "elbow", "wrist", "hand",
                    "spine", "pelvis", "hip", "knee", "ankle", "foot",
                ],
                "primary": ["vasti", "gluteMax"],
                "reps": {"minimum": 3, "maximum": 12},
                "allowed": {
                    "equipment": ["barbell"],
                    "modalities": ["dynamicStrength"],
                    "trackingModes": ["reps"],
                    "loadModes": ["external"],
                    "lateralities": ["bilateral"],
                },
                "evidence": [
                    "arnold-2010-lower-limb",
                    "armstrong-2022-squat-movement-dynamics",
                    "gorsic-2024-squat-load-placement",
                    "joseph-2020-back-belt-squat",
                    "kubo-2019-squat-depth-hypertrophy",
                    "mccormick-2023-front-back-squat-bracing",
                    "purzel-2026-powerlifting-squat-joint-moments",
                    "sinclair-2022-back-squat-foot-angle",
                    "yavuz-2015-front-back-squat-emg",
                ],
                "roster": ["barbell-back-squat", "barbell-front-squat"],
            },
            "hip-thrust-bridge": {
                "name": "Hip Thrust and Bridge",
                "fixed": {
                    "mechanic": "compound",
                    "pattern": "hinge",
                    "direction": None,
                    "planes": ["sagittal"],
                },
                "prime": ["hip.extension", "knee.extension"],
                "demands": [
                    "spine", "pelvis", "hip", "knee", "ankle", "foot",
                ],
                "primary": ["gluteMax"],
                "reps": {"minimum": 5, "maximum": 15},
                "allowed": {
                    "equipment": ["barbell"],
                    "modalities": ["dynamicStrength"],
                    "trackingModes": ["reps"],
                    "loadModes": ["external"],
                    "lateralities": ["bilateral"],
                },
                "evidence": [
                    "arnold-2010-lower-limb",
                    "brazil-2021-barbell-hip-thrust",
                    "kennedy-2024-hip-thrust-glute-bridge",
                ],
                "roster": ["barbell-hip-thrust", "barbell-glute-bridge"],
            },
            "split-stance-squat": {
                "name": "Stationary Split Squat",
                "fixed": {
                    "mechanic": "compound",
                    "pattern": "lunge",
                    "direction": None,
                    "planes": ["sagittal"],
                },
                "prime": [
                    "hip.extension",
                    "knee.extension",
                    "ankle.plantarflexion",
                ],
                "demands": [
                    "shoulder", "scapula", "elbow", "wrist", "hand",
                    "spine", "pelvis", "hip", "knee", "ankle", "foot",
                ],
                "primary": ["vasti", "gluteMax"],
                "reps": {"minimum": 5, "maximum": 15},
                "allowed": {
                    "equipment": ["barbell"],
                    "modalities": ["dynamicStrength"],
                    "trackingModes": ["reps"],
                    "loadModes": ["external"],
                    "lateralities": ["unilateral"],
                },
                "evidence": [
                    "arnold-2010-lower-limb",
                    "song-2023-split-squat-step-length",
                    "stastny-2015-split-squat-dumbbell-position",
                ],
                "roster": ["barbell-split-squat"],
            },
            "step-up": {
                "name": "Forward Step-Up",
                "fixed": {
                    "mechanic": "compound",
                    "pattern": "lunge",
                    "direction": None,
                    "planes": ["sagittal"],
                },
                "prime": [
                    "hip.extension",
                    "knee.extension",
                    "ankle.plantarflexion",
                ],
                "demands": ["spine", "pelvis", "hip", "knee", "ankle", "foot"],
                "primary": ["vasti", "gluteMax"],
                "reps": {"minimum": 5, "maximum": 15},
                "allowed": {
                    "equipment": ["bodyweight"],
                    "modalities": ["dynamicStrength"],
                    "trackingModes": ["reps"],
                    "loadModes": ["nonComparable"],
                    "lateralities": ["unilateral"],
                },
                "evidence": [
                    "arnold-2010-lower-limb",
                    "simenz-2012-loaded-step-up-variations",
                    "wang-2003-forward-lateral-step-up-biomechanics",
                ],
                "roster": ["bodyweight-forward-step-up-21cm"],
            },
        }
        self.assertEqual(set(self.batch5_families), set(expected))
        for family_id, contract in expected.items():
            family = self.batch5_families[family_id]
            with self.subTest(family=family_id):
                self.assertEqual(family["name"], contract["name"])
                self.assertEqual(family["fixed"], contract["fixed"])
                self.assertEqual(
                    family["movementSignature"]["planeBasisActions"],
                    ["hip.extension"],
                )
                self.assertEqual(
                    family["movementSignature"]["primeActions"],
                    contract["prime"],
                )
                self.assertEqual(
                    family["movementSignature"]["stabilityDemands"],
                    contract["demands"],
                )
                self.assertEqual(
                    family["musclePolicy"]["allowedByRole"]["primary"],
                    contract["primary"],
                )
                self.assertEqual(
                    family["groupPolicy"],
                    {"default": "legs", "allowed": ["legs"]},
                )
                self.assertEqual(
                    family["recommended"]["defaultReps"],
                    contract["reps"],
                )
                self.assertEqual(family["allowed"], contract["allowed"])
                self.assertEqual(family["evidenceRefs"], contract["evidence"])
                self.assertEqual(
                    [exercise["catalogID"] for exercise in family["exercises"]],
                    contract["roster"],
                )

    def test_batch5_exact_exercise_surface_and_involvement_are_pinned(
        self,
    ) -> None:
        expected = {
            "barbell-back-squat": {
                "name": "Barbell Back Squat",
                "aliases": ["Back Squat", "Straight-Bar Back Squat"],
                "setup": ("barbell", "bilateral", "external", 45, 20, 8),
                "roles": {
                    "vasti": "primary", "gluteMax": "primary",
                    "rectusFemoris": "secondary",
                    "medialHamstrings": "stabilizer",
                    "gastrocnemius": "secondary", "soleus": "secondary",
                    "fingerFlexors": "stabilizer",
                    "extensorCarpiRadialis": "stabilizer",
                    "externalRotators": "stabilizer",
                    "trapeziusUpper": "stabilizer", "brachialis": "stabilizer",
                    "abs": "stabilizer", "obliques": "stabilizer",
                    "lumbarExtensors": "stabilizer",
                },
                "evidence": [
                    "armstrong-2022-squat-movement-dynamics",
                    "gorsic-2024-squat-load-placement",
                    "joseph-2020-back-belt-squat",
                    "mccormick-2023-front-back-squat-bracing",
                    "purzel-2026-powerlifting-squat-joint-moments",
                    "sinclair-2022-back-squat-foot-angle",
                    "yavuz-2015-front-back-squat-emg",
                ],
            },
            "barbell-front-squat": {
                "name": "Barbell Front Squat",
                "aliases": ["Front Squat", "Clean-Grip Front Squat"],
                "setup": ("barbell", "bilateral", "external", 45, 20, 8),
                "roles": {
                    "vasti": "primary", "gluteMax": "primary",
                    "rectusFemoris": "secondary",
                    "medialHamstrings": "stabilizer",
                    "gastrocnemius": "secondary", "soleus": "secondary",
                    "fingerFlexors": "stabilizer",
                    "extensorCarpiRadialis": "stabilizer",
                    "deltoidAnterior": "stabilizer",
                    "trapeziusUpper": "stabilizer", "brachialis": "stabilizer",
                    "abs": "stabilizer", "obliques": "stabilizer",
                    "lumbarExtensors": "stabilizer",
                },
                "evidence": [
                    "armstrong-2022-squat-movement-dynamics",
                    "gorsic-2024-squat-load-placement",
                    "mccormick-2023-front-back-squat-bracing",
                    "yavuz-2015-front-back-squat-emg",
                ],
            },
            "barbell-hip-thrust": {
                "name": "Barbell Hip Thrust",
                "aliases": ["Hip Thrust", "BHT"],
                "setup": ("barbell", "bilateral", "external", 95, 42.5, 8),
                "roles": {
                    "gluteMax": "primary", "vasti": "secondary",
                    "bicepsFemoris": "stabilizer", "gluteMed": "stabilizer",
                    "lumbarExtensors": "stabilizer", "soleus": "stabilizer",
                },
                "evidence": [
                    "brazil-2021-barbell-hip-thrust",
                    "kennedy-2024-hip-thrust-glute-bridge",
                ],
            },
            "barbell-glute-bridge": {
                "name": "Barbell Glute Bridge",
                "aliases": ["Weighted Glute Bridge", "BGB"],
                "setup": ("barbell", "bilateral", "external", 95, 42.5, 10),
                "roles": {
                    "gluteMax": "primary", "vasti": "secondary",
                    "bicepsFemoris": "stabilizer", "gluteMed": "stabilizer",
                    "lumbarExtensors": "stabilizer", "soleus": "stabilizer",
                },
                "evidence": ["kennedy-2024-hip-thrust-glute-bridge"],
            },
            "barbell-split-squat": {
                "name": "Barbell Split Squat",
                "aliases": ["Stationary Barbell Split Squat"],
                "setup": ("barbell", "unilateral", "external", 45, 20, 8),
                "roles": {
                    "vasti": "primary", "gluteMax": "primary",
                    "rectusFemoris": "secondary",
                    "gastrocnemius": "secondary", "soleus": "secondary",
                    "medialHamstrings": "stabilizer",
                    "bicepsFemoris": "stabilizer", "gluteMed": "stabilizer",
                    "fingerFlexors": "stabilizer",
                    "extensorCarpiRadialis": "stabilizer",
                    "externalRotators": "stabilizer",
                    "trapeziusUpper": "stabilizer", "brachialis": "stabilizer",
                    "abs": "stabilizer", "obliques": "stabilizer",
                    "lumbarExtensors": "stabilizer",
                },
                "evidence": ["song-2023-split-squat-step-length"],
            },
            "bodyweight-forward-step-up-21cm": {
                "name": "21 cm Bodyweight Forward Step-Up",
                "aliases": ["21 cm Forward Step-Up"],
                "setup": ("bodyweight", "unilateral", "nonComparable", 0, None, 10),
                "roles": {
                    "vasti": "primary", "gluteMax": "primary",
                    "rectusFemoris": "secondary",
                    "medialHamstrings": "stabilizer",
                    "gastrocnemius": "secondary", "soleus": "secondary",
                    "bicepsFemoris": "stabilizer", "gluteMed": "stabilizer",
                    "abs": "stabilizer", "obliques": "stabilizer",
                    "lumbarExtensors": "stabilizer",
                },
                "evidence": [
                    "wang-2003-forward-lateral-step-up-biomechanics"
                ],
            },
        }
        actual = {}
        for family in self.batch5_families.values():
            for exercise in family["exercises"]:
                actual[exercise["catalogID"]] = {
                    "name": exercise["name"],
                    "aliases": exercise["aliases"],
                    "setup": (
                        exercise["equipment"], exercise["laterality"],
                        exercise["loadMode"], exercise["defaultWeight"],
                        exercise.get("defaultWeightKg"), exercise["reps"],
                    ),
                    "roles": {
                        item["muscle"]: item["role"]
                        for item in exercise["involvement"]
                    },
                    "evidence": exercise["evidenceRefs"],
                }
                self.assertEqual(exercise["additionalPrimeActions"], [])
                self.assertEqual(exercise["additionalStabilityDemands"], [])
                self.assertTrue(exercise["movementDefinition"])
        self.assertEqual(actual, expected)

    def test_batch5_variant_axes_are_exact_and_rosters_cover_values(
        self,
    ) -> None:
        def enum(*values: object) -> tuple[str, tuple[object, ...]]:
            return ("enum", values)

        def number(minimum: float, maximum: float, required: bool = True) -> tuple:
            return ("number", minimum, maximum, required)

        expected = {
            "bilateral-squat": {
                "kineticChain": enum("closed"),
                "bodyPosition": enum("standing"),
                "torsoSupport": enum("none"),
                "stanceConfiguration": enum("symmetricBilateral"),
                "stanceWidth": enum("hipWidth"),
                "loadPlacement": enum(
                    "upperBackBarbell", "anteriorDeltoidClavicleBarbell"
                ),
                "gripOrientation": enum("pronated", "cleanGrip"),
                "rangeOfMotion": enum("thighParallel"),
                "spineMotion": enum("nonstandardized"),
                "hipMotion": enum("extends"),
                "kneeMotion": enum("extends"),
                "ankleMotion": enum("plantarflexes"),
                "footMotion": enum("positionHeld"),
                "footContact": enum("continuous"),
                "interRepSupport": enum("none"),
                "fixedPath": ("boolean", False),
                "lowerBodyContribution": enum("compoundHipKneeAnkleExtension"),
            },
            "hip-thrust-bridge": {
                "kineticChain": enum("closed"),
                "bodyPosition": enum("supineShouldersElevated", "supineFloor"),
                "torsoSupport": enum("bench", "floor"),
                "pelvisSupport": enum("none"),
                "pelvisMotion": enum("elevates"),
                "spineMotion": enum("nonstandardized"),
                "hipMotion": enum("extends"),
                "hipEndPosition": enum("neutral"),
                "kneeMotion": enum("extends"),
                "kneeEndFlexionDegrees": number(90, 115),
                "ankleMotion": enum("nonstandardized"),
                "footMotion": enum("positionHeld"),
                "footContact": enum("continuous"),
                "footOrientation": enum("straightOrSlightToeOut"),
                "stanceConfiguration": enum("symmetricBilateral"),
                "stanceWidth": enum("shoulderWidth"),
                "movingSegment": enum("pelvis"),
                "loadPlacement": enum("acrossPelvis"),
                "loadInterface": enum("paddedBarbellAcrossPelvis"),
                "gripOrientation": enum("supinated"),
                "rangeOfMotion": enum("floorToHipNeutral"),
                "fixedPath": ("boolean", False),
                "interRepSupport": enum("floor"),
                "benchHeightCm": number(35.5, 35.5, False),
                "lowerBodyContribution": enum("combinedHipAndKneeExtension"),
            },
            "split-stance-squat": {
                "kineticChain": enum("closed"),
                "bodyPosition": enum("standing"),
                "torsoSupport": enum("none"),
                "stanceConfiguration": enum("splitSagittal"),
                "stanceLength": enum("approximatelyLegLength"),
                "leadFootSupport": enum("fullFootFloor"),
                "trailFootSupport": enum("forefootFloor"),
                "interRepFootTransition": enum("none"),
                "loadPlacement": enum("upperBackBarbell"),
                "gripOrientation": enum("pronated"),
                "rangeOfMotion": enum("leadThighParallel"),
                "trunkOrientation": enum("erect"),
                "spineMotion": enum("nonstandardized"),
                "hipMotion": enum("extends"),
                "kneeMotion": enum("extends"),
                "ankleMotion": enum("plantarflexes"),
                "footMotion": enum("positionHeld"),
                "footContact": enum("continuous"),
                "interRepSupport": enum("none"),
                "fixedPath": ("boolean", False),
                "lowerBodyContribution": enum("compoundHipKneeAnkleExtension"),
            },
            "step-up": {
                "kineticChain": enum("closed"),
                "bodyPosition": enum("standing"),
                "torsoSupport": enum("none"),
                "stanceConfiguration": enum("leadFootRaisedStart"),
                "stepDirection": enum("forward"),
                "platformHeightCm": number(21, 21),
                "leadFootTransition": enum("platformToFloorAfterTrailDescent"),
                "trailFootTransition": enum("floorToPlatformToFloor"),
                "trailLegPropulsion": enum("prohibited"),
                "topSupport": enum("bilateralPlatformBriefPause"),
                "loadPlacement": enum("none"),
                "rangeOfMotion": enum(
                    "raisedLeadStartToPlatformStandingToFloor"
                ),
                "spineMotion": enum("nonstandardized"),
                "hipMotion": enum("extends"),
                "kneeMotion": enum("extends"),
                "ankleMotion": enum("plantarflexes"),
                "footMotion": enum("positionHeld"),
                "footContact": enum("leadLoadsPlatformThenBothReturnFloor"),
                "interRepFootTransition": enum("leadFloorToPlatformReset"),
                "interRepSupport": enum("none"),
                "lowerBodyContribution": enum("compoundHipKneeAnkleExtension"),
            },
        }
        for family_id, family in self.batch5_families.items():
            actual = {}
            for axis in family["variantAxes"]:
                axis_id = axis["id"]
                if axis["valueType"] == "enum":
                    actual[axis_id] = ("enum", tuple(axis["allowedValues"]))
                    observed = {
                        exercise["variant"][axis_id]
                        for exercise in family["exercises"]
                    }
                    self.assertEqual(observed, set(axis["allowedValues"]))
                elif axis["valueType"] == "boolean":
                    actual[axis_id] = ("boolean", axis["fixedValue"])
                    self.assertTrue(axis["required"])
                    self.assertEqual(
                        {exercise["variant"][axis_id] for exercise in family["exercises"]},
                        {axis["fixedValue"]},
                    )
                elif axis["valueType"] == "number":
                    actual[axis_id] = (
                        "number", axis["minimum"], axis["maximum"], axis["required"]
                    )
                    observed = {
                        exercise["variant"][axis_id]
                        for exercise in family["exercises"]
                        if axis_id in exercise["variant"]
                    }
                    self.assertTrue(observed)
                    if axis["required"]:
                        self.assertEqual(
                            observed,
                            {axis["minimum"], axis["maximum"]},
                        )
                    else:
                        self.assertTrue(
                            all(
                                axis["minimum"] <= value <= axis["maximum"]
                                for value in observed
                            )
                        )
                else:
                    self.fail(
                        f"unexpected Batch-5 axis type {axis['valueType']}"
                    )
                if axis_id != "benchHeightCm":
                    self.assertTrue(axis["required"])
            with self.subTest(family=family_id):
                self.assertEqual(actual, expected[family_id])

        self.assertNotIn(
            "fixedPath",
            {axis["id"] for axis in self.batch5_families["step-up"]["variantAxes"]},
        )
        self.assertEqual(
            self.batch5_families["split-stance-squat"]["exercises"][0]["variant"][
                "loadPlacement"
            ],
            "upperBackBarbell",
        )
        split_squat = self.batch5_families["split-stance-squat"]
        self.assertNotIn(
            "loadDistribution",
            {axis["id"] for axis in split_squat["variantAxes"]},
        )
        self.assertNotIn(
            "stanceLengthRelativeToLegLength",
            {axis["id"] for axis in split_squat["variantAxes"]},
        )
        self.assertNotIn(
            "loadDistribution",
            split_squat["exercises"][0]["variant"],
        )
        self.assertNotIn(
            "stanceLengthRelativeToLegLength",
            split_squat["exercises"][0]["variant"],
        )

    def test_batch5_forbids_every_other_known_prime_action(self) -> None:
        for family_id, original in self.batch5_families.items():
            own = set(original["movementSignature"]["primeActions"])
            expected = set(self.foundation.action_ids) - own
            self.assertEqual(
                set(original["movementSignature"]["forbiddenPrimeActions"]),
                expected,
            )
            for action in expected:
                family = copy.deepcopy(original)
                family["exercises"][0]["additionalPrimeActions"] = [action]
                with self.subTest(family=family_id, action=action):
                    self.assert_batch5_family_fails(
                        family,
                        f"declares forbidden prime action {re.escape(action)}",
                    )

        for family_id in {"bilateral-squat", "split-stance-squat"}:
            family = self.batch5_families[family_id]
            self.assertIn("spine.flexion", family["movementSignature"]["forbiddenPrimeActions"])
            self.assertIn("spine.extension", family["movementSignature"]["forbiddenPrimeActions"])
            self.assertEqual(
                {
                    exercise["variant"]["spineMotion"]
                    for exercise in family["exercises"]
                },
                {"nonstandardized"},
            )

        thrust = self.batch5_families["hip-thrust-bridge"]
        self.assertEqual(
            {
                exercise["variant"]["ankleMotion"]
                for exercise in thrust["exercises"]
            },
            {"nonstandardized"},
        )
        self.assertTrue(
            {
                "ankle.plantarflexion",
                "ankle.dorsiflexion",
                "ankle.inversion",
                "ankle.eversion",
            }.issubset(thrust["movementSignature"]["forbiddenPrimeActions"])
        )

    def test_every_batch5_rule_has_a_match_and_a_contrast(self) -> None:
        expected_rule_ids = {
            "bilateral-squat": [
                "upper-back-load-uses-back-squat-setup",
                "pronated-grip-is-back-squat",
                "anterior-load-uses-clean-grip",
                "clean-grip-is-front-rack-squat",
            ],
            "hip-thrust-bridge": [
                "bench-supported-fixture-is-hip-thrust",
                "hip-thrust-position-requires-bench",
                "floor-supported-fixture-is-glute-bridge",
                "glute-bridge-position-requires-floor",
            ],
            "split-stance-squat": [],
            "step-up": [],
        }
        for family_id, family in self.batch5_families.items():
            self.assertEqual(
                [rule["id"] for rule in family["exerciseRules"]],
                expected_rule_ids[family_id],
            )
            for rule in family["exerciseRules"]:
                matches = [
                    self.rule_matches_exercise(rule, exercise)
                    for exercise in family["exercises"]
                ]
                with self.subTest(family=family_id, rule=rule["id"]):
                    self.assertEqual(matches.count(True), 1)
                    self.assertEqual(matches.count(False), 1)

    def test_every_batch5_rule_assertion_has_a_direct_mutation(self) -> None:
        mutation_count = 0
        for family_id, family in self.batch5_families.items():
            for rule in family["exerciseRules"]:
                matching = next(
                    exercise
                    for exercise in family["exercises"]
                    if self.rule_matches_exercise(rule, exercise)
                )
                expected_message = "violates exercise rule " + re.escape(
                    rule["id"]
                )
                for assertion in rule["then"]:
                    mutated = copy.deepcopy(matching)
                    self.set_rule_field(mutated, assertion["field"], "mutated")
                    with self.subTest(
                        family=family_id,
                        rule=rule["id"],
                        field=assertion["field"],
                    ):
                        with self.assertRaisesRegex(
                            catalog.ValidationFailure,
                            expected_message,
                        ):
                            catalog.validate_exercise_rule_matches(
                                mutated,
                                [rule],
                                "mutated Batch-5 rule assertion",
                            )
                    mutation_count += 1
                for field_path in rule["requirePresent"]:
                    mutated = copy.deepcopy(matching)
                    self.delete_rule_field(mutated, field_path)
                    with self.subTest(
                        family=family_id,
                        rule=rule["id"],
                        required=field_path,
                    ):
                        with self.assertRaisesRegex(
                            catalog.ValidationFailure,
                            expected_message,
                        ):
                            catalog.validate_exercise_rule_matches(
                                mutated,
                                [rule],
                                "mutated Batch-5 presence assertion",
                            )
                    mutation_count += 1
                for field_path in rule["requireAbsent"]:
                    mutated = copy.deepcopy(matching)
                    self.set_rule_field(mutated, field_path, 35.5)
                    with self.subTest(
                        family=family_id,
                        rule=rule["id"],
                        absent=field_path,
                    ):
                        with self.assertRaisesRegex(
                            catalog.ValidationFailure,
                            expected_message,
                        ):
                            catalog.validate_exercise_rule_matches(
                                mutated,
                                [rule],
                                "mutated Batch-5 absence assertion",
                            )
                    mutation_count += 1
                for assignment in rule.get("requireInvolvement", []):
                    mutated = copy.deepcopy(matching)
                    mutated["involvement"] = [
                        item
                        for item in mutated["involvement"]
                        if item["muscle"] != assignment["muscle"]
                    ]
                    with self.subTest(
                        family=family_id,
                        rule=rule["id"],
                        muscle=assignment["muscle"],
                    ):
                        with self.assertRaisesRegex(
                            catalog.ValidationFailure,
                            expected_message,
                        ):
                            catalog.validate_exercise_rule_matches(
                                mutated,
                                [rule],
                                "mutated Batch-5 role assertion",
                            )
                    mutation_count += 1
        self.assertEqual(mutation_count, 17)

    def test_batch5_squat_shoulder_rules_are_minima_not_exclusive(self) -> None:
        family = copy.deepcopy(self.batch5_families["bilateral-squat"])
        additions = {
            "barbell-back-squat": "deltoidAnterior",
            "barbell-front-squat": "externalRotators",
        }
        for exercise in family["exercises"]:
            exercise["involvement"].append(
                {
                    "muscle": additions[exercise["catalogID"]],
                    "role": "stabilizer",
                }
            )
        self.assertEqual(
            catalog.validate_family(
                family,
                self.foundation,
                "squat shoulder-role non-exclusivity fixture",
            ),
            [],
        )

    def test_batch5_required_muscles_and_minimum_roles_are_mutation_gated(
        self,
    ) -> None:
        removal_count = 0
        demotion_count = 0
        lower_role = {"primary": "secondary", "secondary": "stabilizer"}
        for family_id, original in self.batch5_families.items():
            for exercise_index, exercise in enumerate(original["exercises"]):
                roles = {
                    item["muscle"]: item["role"]
                    for item in exercise["involvement"]
                }
                for requirement_index, requirement in enumerate(
                    original["musclePolicy"]["requirements"]
                ):
                    family = copy.deepcopy(original)
                    family["exercises"][exercise_index]["involvement"] = [
                        assignment
                        for assignment in family["exercises"][exercise_index][
                            "involvement"
                        ]
                        if assignment["muscle"] not in requirement["anyOf"]
                    ]
                    with self.subTest(
                        family=family_id,
                        exercise=exercise["catalogID"],
                        requirement=requirement_index,
                        mutation="remove",
                    ):
                        self.assert_batch5_family_fails(
                            family,
                            (
                                "fails muscle requirement "
                                f"{requirement_index}"
                                "|requires at least one primary muscle"
                                "|group .* has no matching primary muscle"
                                "|no assigned muscle capable of stabilizing"
                                "|violates exercise rule"
                            ),
                        )
                    removal_count += 1

                    minimum_role = requirement["minimumRole"]
                    if minimum_role == "stabilizer":
                        continue
                    candidate = next(
                        muscle_id
                        for muscle_id in requirement["anyOf"]
                        if muscle_id in roles
                    )
                    family = copy.deepcopy(original)
                    family["exercises"] = [family["exercises"][exercise_index]]
                    allowed_by_role = family["musclePolicy"]["allowedByRole"]
                    allowed_by_role[lower_role[minimum_role]].append(candidate)
                    next(
                        item
                        for item in family["exercises"][0]["involvement"]
                        if item["muscle"] == candidate
                    )["role"] = lower_role[minimum_role]
                    if not any(
                        item["role"] == "primary"
                        for item in family["exercises"][0]["involvement"]
                    ):
                        substitute = next(
                            item
                            for item in family["exercises"][0]["involvement"]
                            if item["role"] == "secondary"
                            and item["muscle"] != candidate
                        )
                        allowed_by_role["primary"].append(
                            substitute["muscle"]
                        )
                        substitute["role"] = "primary"
                    with self.subTest(
                        family=family_id,
                        exercise=exercise["catalogID"],
                        requirement=requirement_index,
                        mutation="demote",
                    ):
                        self.assert_batch5_family_fails(
                            family,
                            f"fails muscle requirement {requirement_index}",
                        )
                    demotion_count += 1
        self.assertEqual(removal_count, 67)
        self.assertEqual(demotion_count, 24)

    def test_batch5_one_record_contracts_mutate_every_invariant_directly(
        self,
    ) -> None:
        mutation_count = 0
        for family_id in {"split-stance-squat", "step-up"}:
            original = self.batch5_families[family_id]
            self.assertEqual(original["exerciseRules"], [])
            for axis in original["variantAxes"]:
                family = copy.deepcopy(original)
                if axis["valueType"] == "enum":
                    value = "mutated"
                    expected_error = re.escape(
                        f"variant.{axis['id']} has disallowed value 'mutated'"
                    )
                elif axis["valueType"] == "boolean":
                    value = not axis["fixedValue"]
                    expected_error = re.escape(
                        f"variant.{axis['id']} must equal fixed value "
                        f"{axis['fixedValue']!r}"
                    )
                elif axis["valueType"] == "number":
                    value = axis["maximum"] + 1
                    expected_error = re.escape(
                        f"variant.{axis['id']} exceeds {axis['maximum']}"
                    )
                else:
                    self.fail(
                        f"unexpected Batch-5 axis type {axis['valueType']}"
                    )
                family["exercises"][0]["variant"][axis["id"]] = value
                with self.subTest(family=family_id, axis=axis["id"]):
                    self.assert_batch5_family_fails(
                        family,
                        expected_error,
                    )
                mutation_count += 1

            field_domains = {
                "equipment": catalog.EQUIPMENT,
                "laterality": catalog.LATERALITIES,
                "modality": catalog.MODALITIES,
                "trackingMode": catalog.TRACKING_MODES,
                "loadMode": catalog.LOAD_MODES,
            }
            allowed_keys = {
                "equipment": "equipment",
                "laterality": "lateralities",
                "modality": "modalities",
                "trackingMode": "trackingModes",
                "loadMode": "loadModes",
            }
            for field, domain in field_domains.items():
                family = copy.deepcopy(original)
                allowed = family["allowed"][allowed_keys[field]]
                mutated_value = sorted(domain - set(allowed))[0]
                family["exercises"][0][field] = mutated_value
                with self.subTest(family=family_id, field=field):
                    self.assert_batch5_family_fails(
                        family,
                        re.escape(
                            f"selects disallowed {allowed_keys[field]}: "
                            f"{mutated_value}"
                        ),
                    )
                mutation_count += 1
        self.assertEqual(mutation_count, 52)

    def test_batch5_support_topology_and_step_cycle_boundaries_are_exact(
        self,
    ) -> None:
        variant_by_family = {
            family_id: family["exercises"][0]["variant"]
            for family_id, family in self.batch5_families.items()
        }
        self.assertEqual(
            {
                family_id: variant["stanceConfiguration"]
                for family_id, variant in variant_by_family.items()
            },
            {
                "bilateral-squat": "symmetricBilateral",
                "hip-thrust-bridge": "symmetricBilateral",
                "split-stance-squat": "splitSagittal",
                "step-up": "leadFootRaisedStart",
            },
        )
        self.assertEqual(
            variant_by_family["split-stance-squat"]["loadPlacement"],
            "upperBackBarbell",
        )
        step = variant_by_family["step-up"]
        self.assertEqual(
            {
                "lead": step["leadFootTransition"],
                "trail": step["trailFootTransition"],
                "contact": step["footContact"],
                "reset": step["interRepFootTransition"],
            },
            {
                "lead": "platformToFloorAfterTrailDescent",
                "trail": "floorToPlatformToFloor",
                "contact": "leadLoadsPlatformThenBothReturnFloor",
                "reset": "leadFloorToPlatformReset",
            },
        )
        self.assertNotIn("fixedPath", step)
        self.assertEqual(
            variant_by_family["hip-thrust-bridge"]["lowerBodyContribution"],
            "combinedHipAndKneeExtension",
        )
        for family_id in {
            "bilateral-squat", "split-stance-squat", "step-up"
        }:
            self.assertEqual(
                variant_by_family[family_id]["lowerBodyContribution"],
                "compoundHipKneeAnkleExtension",
            )

    def test_batch5_split_squat_measurement_scope_is_not_a_variant(
        self,
    ) -> None:
        family = self.batch5_families["split-stance-squat"]
        self.assertNotIn(
            "loadDistribution",
            {axis["id"] for axis in family["variantAxes"]},
        )
        self.assertNotIn(
            "stanceLengthRelativeToLegLength",
            {axis["id"] for axis in family["variantAxes"]},
        )
        self.assertNotIn(
            "loadDistribution",
            family["exercises"][0]["variant"],
        )
        self.assertNotIn(
            "stanceLengthRelativeToLegLength",
            family["exercises"][0]["variant"],
        )
        self.assertEqual(
            family["exercises"][0]["variant"]["stanceLength"],
            "approximatelyLegLength",
        )

        proposal = (
            catalog.SPEC_ROOT
            / "proposals"
            / "batch-5-unilateral-compounds.md"
        ).read_text(encoding="utf-8")
        normalized_proposal = " ".join(proposal.split())
        self.assertIn(
            "collected the anterior/dominant limb and explicitly identifies "
            "the absence of posterior-limb data",
            normalized_proposal,
        )
        self.assertIn(
            "what a study instrumented is not an observable exercise property",
            normalized_proposal,
        )
        self.assertIn(
            "stanceLength: approximatelyLegLength` rather than a false numeric "
            "ratio",
            normalized_proposal,
        )
        self.assertIn(
            "does not claim that the rear leg contributes zero load, that the "
            "lead leg is load-dominant, or that a percentage split is known",
            normalized_proposal,
        )

        song = next(
            source
            for source in self.foundation.evidence["sources"]
            if source["id"] == "song-2023-split-squat-step-length"
        )
        self.assertIn(
            "lead-limb kinematics, kinetics, and eight-muscle surface EMG",
            song["scope"],
        )
        self.assertIn(
            "posterior-limb loading was not collected",
            song["scope"],
        )
        self.assertIn(
            "establishes neither zero rear contribution nor a lead-dominant "
            "or percentage load split",
            song["scope"],
        )
        self.assertIn(
            "does not textually specify a stance landmark",
            song["scope"],
        )

    def test_batch5_stability_demands_have_exact_role_agnostic_providers(
        self,
    ) -> None:
        expected = {
            "barbell-back-squat": {
                "shoulder": {"externalRotators"},
                "scapula": {"trapeziusUpper"},
                "elbow": {"brachialis"},
                "wrist": {"extensorCarpiRadialis", "fingerFlexors"},
                "hand": {"fingerFlexors"},
                "spine": {"abs", "lumbarExtensors", "obliques"},
                "pelvis": {
                    "abs", "gluteMax", "lumbarExtensors", "medialHamstrings",
                    "obliques",
                },
                "hip": {"gluteMax", "medialHamstrings", "rectusFemoris"},
                "knee": {
                    "gastrocnemius", "medialHamstrings", "rectusFemoris",
                    "vasti",
                },
                "ankle": {"gastrocnemius", "soleus"},
                "foot": {"gastrocnemius", "soleus"},
            },
            "barbell-front-squat": {},
            "barbell-hip-thrust": {
                "spine": {"lumbarExtensors"},
                "pelvis": {"gluteMax", "gluteMed", "lumbarExtensors"},
                "hip": {"gluteMax", "gluteMed"},
                "knee": {"bicepsFemoris", "vasti"},
                "ankle": {"soleus"},
                "foot": {"soleus"},
            },
            "barbell-glute-bridge": {},
            "barbell-split-squat": {
                "shoulder": {"externalRotators"},
                "scapula": {"trapeziusUpper"},
                "elbow": {"brachialis"},
                "wrist": {"extensorCarpiRadialis", "fingerFlexors"},
                "hand": {"fingerFlexors"},
                "spine": {"abs", "lumbarExtensors", "obliques"},
                "pelvis": {
                    "abs", "gluteMax", "gluteMed", "lumbarExtensors",
                    "medialHamstrings", "obliques",
                },
                "hip": {
                    "gluteMax", "gluteMed", "medialHamstrings",
                    "rectusFemoris",
                },
                "knee": {
                    "bicepsFemoris", "gastrocnemius", "medialHamstrings",
                    "rectusFemoris", "vasti",
                },
                "ankle": {"gastrocnemius", "soleus"},
                "foot": {"gastrocnemius", "soleus"},
            },
            "bodyweight-forward-step-up-21cm": {},
        }
        expected["barbell-front-squat"] = {
            **expected["barbell-back-squat"],
            "shoulder": {"deltoidAnterior"},
        }
        expected["barbell-glute-bridge"] = expected["barbell-hip-thrust"]
        expected["bodyweight-forward-step-up-21cm"] = {
            region: providers
            for region, providers in expected["barbell-split-squat"].items()
            if region not in {"shoulder", "scapula", "elbow", "wrist", "hand"}
        }
        for family in self.batch5_families.values():
            for exercise in family["exercises"]:
                assigned = {
                    item["muscle"] for item in exercise["involvement"]
                }
                actual = {
                    region: {
                        muscle_id
                        for muscle_id in assigned
                        if region
                        in self.foundation.profile_by_muscle[muscle_id][
                            "stabilizes"
                        ]
                    }
                    for region in family["movementSignature"][
                        "stabilityDemands"
                    ]
                }
                with self.subTest(exercise=exercise["catalogID"]):
                    self.assertEqual(actual, expected[exercise["catalogID"]])

    def test_batch5_evidence_scopes_preserve_material_limitations(self) -> None:
        source_by_id = {
            source["id"]: source
            for source in self.foundation.evidence["sources"]
        }
        expected_scope_phrases = {
            "armstrong-2022-squat-movement-dynamics": (
                "does not provide a complete muscle-policy ranking"
            ),
            "gorsic-2024-squat-load-placement": (
                "study contains no exercise EMG"
            ),
            "joseph-2020-back-belt-squat": (
                "contains no front-squat condition"
            ),
            "kubo-2019-squat-depth-hypertrophy": (
                "cannot override the visible-region action model"
            ),
            "mccormick-2023-front-back-squat-bracing": (
                "lower front-squat load prevents a numeric cross-variant"
            ),
            "purzel-2026-powerlifting-squat-joint-moments": (
                "support only the cross-squat ankle-action gate"
            ),
            "sinclair-2022-back-squat-foot-angle": (
                "does not pre-authorize a foot-orientation axis"
            ),
            "yavuz-2015-front-back-squat-emg": (
                "surface EMG cannot establish net hip-extension contribution"
            ),
            "brazil-2021-barbell-hip-thrust": (
                "observed but nonstandardized ankle motion"
            ),
            "kennedy-2024-hip-thrust-glute-bridge": (
                "not bodyweight, unilateral, machine, or band variants"
            ),
            "song-2023-split-squat-step-length": (
                "posterior-limb loading was not collected"
            ),
            "stastny-2015-split-squat-dumbbell-position": (
                "does not test the active straight-bar placement"
            ),
            "simenz-2012-loaded-step-up-variations": (
                "does not report an external-load implement or placement"
            ),
            "wang-2003-forward-lateral-step-up-biomechanics": (
                "absence of muscle EMG or external load"
            ),
        }
        for source_id, phrase in expected_scope_phrases.items():
            with self.subTest(source=source_id):
                self.assertIn(phrase, source_by_id[source_id]["scope"])

    def test_batch5_step_up_evidence_and_load_boundaries_are_pinned(self) -> None:
        family = self.batch5_families["step-up"]
        exercise = family["exercises"][0]
        self.assertIn("simenz-2012-loaded-step-up-variations", family["evidenceRefs"])
        self.assertNotIn(
            "simenz-2012-loaded-step-up-variations",
            exercise["evidenceRefs"],
        )
        self.assertEqual(
            exercise["evidenceRefs"],
            ["wang-2003-forward-lateral-step-up-biomechanics"],
        )
        self.assertNotIn("Step-Up", exercise["aliases"])
        self.assertEqual(exercise["loadMode"], "nonComparable")
        self.assertEqual(exercise["bodyweightFraction"], 0)
        self.assertEqual(exercise["defaultWeight"], 0)
        self.assertNotIn("defaultWeightKg", exercise)

    def test_batch5_hip_hinge_and_dynamic_lunge_holds_are_resolved(self) -> None:
        active_ids = {family["id"] for family in self.real_families}
        self.assertTrue({"hip-hinge", "dynamic-lunge"} <= active_ids)
        self.assertTrue((catalog.FAMILIES_ROOT / "hip-hinge.json").exists())
        self.assertTrue(
            (catalog.FAMILIES_ROOT / "dynamic-lunge.json").exists()
        )
        hip_proposal = (
            catalog.SPEC_ROOT / "proposals" / "batch-5-hip-patterns.md"
        ).read_text(encoding="utf-8")
        lunge_proposal = (
            catalog.SPEC_ROOT
            / "proposals"
            / "batch-5-unilateral-compounds.md"
        ).read_text(encoding="utf-8")
        roadmap = (catalog.SPEC_ROOT / "family-roadmap.md").read_text(
            encoding="utf-8"
        )
        families_readme = (
            catalog.FAMILIES_ROOT / "README.md"
        ).read_text(encoding="utf-8")
        normalized_hip = " ".join(hip_proposal.split())
        normalized_lunge = " ".join(lunge_proposal.split())
        normalized_roadmap = " ".join(roadmap.split())
        normalized_readme = " ".join(families_readme.split())
        self.assertIn(
            "`hip-hinge` | Activate the exact Schellenberg good-morning "
            "fixture | 1",
            normalized_hip,
        )
        self.assertIn(
            "does not revive the rejected static-knee Romanian-deadlift draft",
            normalized_hip,
        )
        self.assertIn(
            "representative 45-pound / 20-kilogram seed",
            normalized_hip,
        )
        self.assertIn(
            "explicitly instructs the athlete to replace it with 25 percent "
            "of their own body mass",
            normalized_hip,
        )
        self.assertIn(
            "`dynamic-lunge` | `bodyweight-forward-lunge`; "
            "`bodyweight-reverse-lunge`",
            normalized_lunge,
        )
        self.assertIn(
            "walking or alternating lunges",
            normalized_lunge,
        )
        self.assertIn("| `hip-hinge` | 1 |", roadmap)
        self.assertIn("| `dynamic-lunge` | 2 |", roadmap)
        self.assertIn(
            "Later review activated both the good-morning hinge owner and the "
            "forward/reverse dynamic-lunge family",
            normalized_roadmap,
        )
        self.assertIn(
            "one exact 25-percent-body-mass barbell good morning",
            normalized_readme,
        )

        source_by_id = {
            source["id"]: source
            for source in self.foundation.evidence["sources"]
        }
        schellenberg = source_by_id[
            "schellenberg-2013-deadlift-goodmorning-kinematics"
        ]
        comfort = source_by_id[
            "comfort-2015-forward-reverse-lunge-kinetics"
        ]
        self.assertEqual(schellenberg["doi"], "10.1186/2052-1847-5-27")
        self.assertEqual(schellenberg["pmid"], "24314057")
        self.assertEqual(comfort["doi"], "10.4085/1062-6050-50.9.05")
        self.assertEqual(comfort["pmid"], "26418958")
        self.assertEqual(
            tuple(comfort["authors"]),
            (
                "Paul Comfort",
                "Paul A. Jones",
                "Laura Constance Smith",
                "Lee Herrington",
            ),
        )
        self.assertEqual(
            {schellenberg["sourceType"], comfort["sourceType"]},
            {"experimentalKinematicsKineticsStudy"},
        )

    def test_late_lower_body_closure_contracts_and_rosters_are_exact(
        self,
    ) -> None:
        expected = {
            "hip-flexion": {
                "name": "Hip Flexion Isolation",
                "fixed": ("isolation", None, None, ("sagittal",)),
                "allowed": (
                    ("bodyweight",), ("dynamicStrength",), ("reps",),
                    ("nonComparable",), ("unilateral",),
                ),
                "basis": ("hip.flexion",),
                "prime": ("hip.flexion",),
                "demands": ("hip", "pelvis", "knee", "spine"),
                "requirements": (
                    (("iliopsoas",), "primary"),
                    (("rectusFemoris",), "secondary"),
                    (("abs",), "stabilizer"),
                    (("obliques",), "stabilizer"),
                ),
                "roles": {
                    "primary": ("iliopsoas",),
                    "secondary": ("rectusFemoris",),
                    "stabilizer": ("abs", "obliques"),
                },
                "reps": (8, 15),
                "evidence": (
                    "arnold-2010-lower-limb",
                    "okubo-2021-end-range-active-straight-leg-raise",
                ),
                "roster": ("bodyweight-active-straight-leg-raise",),
            },
            "hip-hinge": {
                "name": "Hip Hinge",
                "fixed": ("compound", "hinge", None, ("sagittal",)),
                "allowed": (
                    ("barbell",), ("dynamicStrength",), ("reps",),
                    ("external",), ("bilateral",),
                ),
                "basis": ("hip.extension",),
                "prime": ("hip.extension", "spine.extension"),
                "demands": (
                    "shoulder", "scapula", "elbow", "wrist", "hand",
                    "spine", "pelvis", "hip", "knee", "ankle", "foot",
                ),
                "requirements": (
                    (("medialHamstrings",), "primary"),
                    (("gluteMax",), "primary"),
                    (("lumbarExtensors",), "primary"),
                    (("bicepsFemoris",), "stabilizer"),
                    (("gluteMed",), "stabilizer"),
                    (("gastrocnemius",), "stabilizer"),
                    (("soleus",), "stabilizer"),
                    (("fingerFlexors",), "stabilizer"),
                    (("extensorCarpiRadialis",), "stabilizer"),
                    (("externalRotators",), "stabilizer"),
                    (("trapeziusUpper",), "stabilizer"),
                    (("brachialis",), "stabilizer"),
                    (("abs",), "stabilizer"),
                    (("obliques",), "stabilizer"),
                ),
                "roles": {
                    "primary": (
                        "medialHamstrings", "gluteMax", "lumbarExtensors",
                    ),
                    "secondary": (),
                    "stabilizer": (
                        "bicepsFemoris", "gluteMed", "gastrocnemius",
                        "soleus", "fingerFlexors",
                        "extensorCarpiRadialis", "externalRotators",
                        "trapeziusUpper", "brachialis", "abs", "obliques",
                    ),
                },
                "reps": (8, 8),
                "evidence": (
                    "arnold-2010-lower-limb",
                    "christophy-2012-lumbar-spine",
                    "schellenberg-2013-deadlift-goodmorning-kinematics",
                ),
                "roster": ("barbell-good-morning-25-percent-body-mass",),
            },
            "dynamic-lunge": {
                "name": "Dynamic Lunge",
                "fixed": ("compound", "lunge", None, ("sagittal",)),
                "allowed": (
                    ("bodyweight",), ("dynamicStrength",), ("reps",),
                    ("nonComparable",), ("unilateral",),
                ),
                "basis": ("hip.extension",),
                "prime": (
                    "hip.extension", "knee.extension",
                    "ankle.plantarflexion",
                ),
                "demands": (
                    "spine", "pelvis", "hip", "knee", "ankle", "foot",
                ),
                "requirements": (
                    (("vasti",), "primary"),
                    (("gluteMax",), "primary"),
                    (("rectusFemoris",), "secondary"),
                    (("gastrocnemius",), "secondary"),
                    (("soleus",), "secondary"),
                    (("medialHamstrings",), "stabilizer"),
                    (("bicepsFemoris",), "stabilizer"),
                    (("gluteMed",), "stabilizer"),
                    (("abs",), "stabilizer"),
                    (("obliques",), "stabilizer"),
                    (("lumbarExtensors",), "stabilizer"),
                ),
                "roles": {
                    "primary": ("vasti", "gluteMax"),
                    "secondary": (
                        "rectusFemoris", "gastrocnemius", "soleus",
                    ),
                    "stabilizer": (
                        "medialHamstrings", "bicepsFemoris", "gluteMed",
                        "abs", "obliques", "lumbarExtensors",
                    ),
                },
                "reps": (5, 15),
                "evidence": (
                    "arnold-2010-lower-limb",
                    "comfort-2015-forward-reverse-lunge-kinetics",
                ),
                "roster": (
                    "bodyweight-forward-lunge",
                    "bodyweight-reverse-lunge",
                ),
            },
        }
        self.assertEqual(
            set(self.late_lower_body_closure_families),
            set(expected),
        )
        for family_id, contract in expected.items():
            family = self.late_lower_body_closure_families[family_id]
            actual_fixed = (
                family["fixed"]["mechanic"],
                family["fixed"]["pattern"],
                family["fixed"]["direction"],
                tuple(family["fixed"]["planes"]),
            )
            actual_allowed = (
                tuple(family["allowed"]["equipment"]),
                tuple(family["allowed"]["modalities"]),
                tuple(family["allowed"]["trackingModes"]),
                tuple(family["allowed"]["loadModes"]),
                tuple(family["allowed"]["lateralities"]),
            )
            actual_requirements = tuple(
                (tuple(item["anyOf"]), item["minimumRole"])
                for item in family["musclePolicy"]["requirements"]
            )
            actual_roles = {
                role: tuple(muscles)
                for role, muscles in family["musclePolicy"][
                    "allowedByRole"
                ].items()
            }
            with self.subTest(family=family_id):
                self.assertEqual(family["name"], contract["name"])
                self.assertEqual(actual_fixed, contract["fixed"])
                self.assertEqual(actual_allowed, contract["allowed"])
                self.assertEqual(
                    tuple(family["movementSignature"]["planeBasisActions"]),
                    contract["basis"],
                )
                self.assertEqual(
                    tuple(family["movementSignature"]["primeActions"]),
                    contract["prime"],
                )
                self.assertEqual(
                    tuple(family["movementSignature"]["stabilityDemands"]),
                    contract["demands"],
                )
                self.assertEqual(actual_requirements, contract["requirements"])
                self.assertEqual(actual_roles, contract["roles"])
                self.assertEqual(
                    (
                        family["recommended"]["defaultReps"]["minimum"],
                        family["recommended"]["defaultReps"]["maximum"],
                    ),
                    contract["reps"],
                )
                self.assertEqual(tuple(family["evidenceRefs"]), contract["evidence"])
                self.assertEqual(
                    tuple(
                        exercise["catalogID"]
                        for exercise in family["exercises"]
                    ),
                    contract["roster"],
                )

    def test_late_lower_body_closure_exercise_surfaces_are_exact(self) -> None:
        expected = {
            "bodyweight-active-straight-leg-raise": {
                "name": "Bodyweight Active Straight-Leg Raise",
                "aliases": (
                    "Active Straight-Leg Raise",
                    "Supine Straight-Leg Raise",
                ),
                "setup": (
                    "bodyweight", "unilateral", "dynamicStrength", "reps",
                    "nonComparable", 0, 0, None, 10, 68,
                ),
                "roles": {
                    "iliopsoas": "primary",
                    "rectusFemoris": "secondary",
                    "abs": "stabilizer",
                    "obliques": "stabilizer",
                },
                "evidence": (
                    "arnold-2010-lower-limb",
                    "okubo-2021-end-range-active-straight-leg-raise",
                ),
            },
            "barbell-good-morning-25-percent-body-mass": {
                "name": "25% Body-Mass Barbell Good Morning",
                "aliases": (
                    "Barbell Good Morning at 25% Body Mass",
                    "25% Bodyweight Good Morning",
                ),
                "setup": (
                    "barbell", "bilateral", "dynamicStrength", "reps",
                    "external", 0, 45, 20, 8, 76,
                ),
                "roles": {
                    "medialHamstrings": "primary",
                    "gluteMax": "primary",
                    "lumbarExtensors": "primary",
                    "bicepsFemoris": "stabilizer",
                    "gluteMed": "stabilizer",
                    "gastrocnemius": "stabilizer",
                    "soleus": "stabilizer",
                    "fingerFlexors": "stabilizer",
                    "extensorCarpiRadialis": "stabilizer",
                    "externalRotators": "stabilizer",
                    "trapeziusUpper": "stabilizer",
                    "brachialis": "stabilizer",
                    "abs": "stabilizer",
                    "obliques": "stabilizer",
                },
                "evidence": (
                    "schellenberg-2013-deadlift-goodmorning-kinematics",
                ),
            },
            "bodyweight-forward-lunge": {
                "name": "Bodyweight Forward Lunge",
                "aliases": ("Forward Lunge",),
                "setup": (
                    "bodyweight", "unilateral", "dynamicStrength", "reps",
                    "nonComparable", 0, 0, None, 5, 88,
                ),
                "evidence": (
                    "comfort-2015-forward-reverse-lunge-kinetics",
                ),
            },
            "bodyweight-reverse-lunge": {
                "name": "Bodyweight Reverse Lunge",
                "aliases": ("Reverse Lunge",),
                "setup": (
                    "bodyweight", "unilateral", "dynamicStrength", "reps",
                    "nonComparable", 0, 0, None, 5, 87,
                ),
                "evidence": (
                    "comfort-2015-forward-reverse-lunge-kinetics",
                ),
            },
        }
        lunge_roles = {
            "vasti": "primary",
            "gluteMax": "primary",
            "rectusFemoris": "secondary",
            "gastrocnemius": "secondary",
            "soleus": "secondary",
            "medialHamstrings": "stabilizer",
            "bicepsFemoris": "stabilizer",
            "gluteMed": "stabilizer",
            "abs": "stabilizer",
            "obliques": "stabilizer",
            "lumbarExtensors": "stabilizer",
        }
        expected["bodyweight-forward-lunge"]["roles"] = lunge_roles
        expected["bodyweight-reverse-lunge"]["roles"] = lunge_roles

        actual = {}
        for family in self.late_lower_body_closure_families.values():
            for exercise in family["exercises"]:
                actual[exercise["catalogID"]] = {
                    "name": exercise["name"],
                    "aliases": tuple(exercise["aliases"]),
                    "setup": (
                        exercise["equipment"], exercise["laterality"],
                        exercise["modality"], exercise["trackingMode"],
                        exercise["loadMode"], exercise["bodyweightFraction"],
                        exercise["defaultWeight"],
                        exercise.get("defaultWeightKg"), exercise["reps"],
                        exercise["searchPriority"],
                    ),
                    "roles": {
                        item["muscle"]: item["role"]
                        for item in exercise["involvement"]
                    },
                    "evidence": tuple(exercise["evidenceRefs"]),
                }
                self.assertEqual(exercise["additionalPrimeActions"], [])
                self.assertEqual(exercise["additionalStabilityDemands"], [])
                self.assertTrue(exercise["movementDefinition"])
        self.assertEqual(actual, expected)

    def test_late_lower_body_negative_topology_boundaries_are_pinned(
        self,
    ) -> None:
        hip_flexion = self.late_lower_body_closure_families["hip-flexion"]
        hip_exercise = hip_flexion["exercises"][0]
        hip_axes = {axis["id"]: axis for axis in hip_flexion["variantAxes"]}
        self.assertTrue(
            all(axis["valueType"] != "number" for axis in hip_axes.values())
        )
        self.assertTrue(
            {
                "hipFlexionDegrees", "endpointDegrees", "cadenceSeconds",
                "holdDurationSeconds",
            }.isdisjoint(hip_axes)
        )
        self.assertEqual(hip_axes["rangeOfMotion"]["allowedValues"], [
            "activeEndRange"
        ])
        self.assertEqual(hip_axes["pelvisMotion"]["allowedValues"], [
            "nonstandardized"
        ])
        self.assertEqual(hip_axes["spineMotion"]["allowedValues"], [
            "nonstandardized"
        ])
        hip_muscles = {
            item["muscle"] for item in hip_exercise["involvement"]
        }
        excluded_hip_flexors = {
            "tensorFasciaeLatae", "sartorius", "adductorLongusBrevis",
            "adductorMagnus", "pectineus",
        }
        self.assertTrue(excluded_hip_flexors.isdisjoint(hip_muscles))
        for muscle_id in excluded_hip_flexors:
            family = copy.deepcopy(hip_flexion)
            family["exercises"][0]["involvement"].append(
                {"muscle": muscle_id, "role": "secondary"}
            )
            with self.subTest(family="hip-flexion", excluded=muscle_id):
                self.assert_late_lower_body_closure_fails(
                    family,
                    f"does not allow {muscle_id} as secondary",
                )
        family = copy.deepcopy(hip_flexion)
        family["exercises"][0]["variant"]["hipFlexionDegrees"] = 60
        self.assert_late_lower_body_closure_fails(
            family,
            "contains undeclared axes: hipFlexionDegrees",
        )

        hinge = self.late_lower_body_closure_families["hip-hinge"]
        hinge_exercise = hinge["exercises"][0]
        hinge_variant = hinge_exercise["variant"]
        self.assertEqual(
            hinge["movementSignature"]["primeActions"],
            ["hip.extension", "spine.extension"],
        )
        self.assertNotIn(
            "knee.extension", hinge["movementSignature"]["primeActions"]
        )
        self.assertEqual(
            hinge_variant["spineMotion"],
            "extendsWithMeasuredSegmentalExcursion",
        )
        self.assertEqual(
            hinge_variant["kneeMotion"],
            "measuredSmallNondefiningExcursion",
        )
        self.assertEqual(
            hinge_variant["externalLoadPrescription"],
            "twentyFivePercentBodyMass",
        )
        self.assertEqual(hinge_exercise["loadMode"], "external")
        self.assertEqual(hinge_exercise["defaultWeight"], 45)
        self.assertEqual(hinge_exercise["defaultWeightKg"], 20)
        self.assertIn(
            "Replace the representative 45-pound or 20-kilogram seed with "
            "external barbell load equal to 25 percent of your body mass",
            hinge_exercise["movementDefinition"],
        )
        hinge_names = " ".join(
            [hinge_exercise["name"], *hinge_exercise["aliases"]]
        ).lower()
        self.assertNotIn("deadlift", hinge_names)
        self.assertNotIn("rdl", hinge_names)

        lunge = self.late_lower_body_closure_families["dynamic-lunge"]
        variants = {
            exercise["catalogID"]: exercise["variant"]
            for exercise in lunge["exercises"]
        }
        self.assertEqual(
            {
                catalog_id: {
                    "direction": variant["stepDirection"],
                    "lead": variant["selectedLeadFootTransition"],
                    "other": variant["contralateralFootTransition"],
                    "landing": variant["landingFoot"],
                    "contact": variant["selectedLeadFootContact"],
                }
                for catalog_id, variant in variants.items()
            },
            {
                "bodyweight-forward-lunge": {
                    "direction": "selectedLeadForward",
                    "lead": "stepsForwardThenReturns",
                    "other": "remainsAtStartThenReceivesReturn",
                    "landing": "selectedLead",
                    "contact": "stepsThenWholeFootMaintained",
                },
                "bodyweight-reverse-lunge": {
                    "direction": "contralateralRearward",
                    "lead": "remainsPlantedThroughout",
                    "other": "stepsRearwardThenReturns",
                    "landing": "contralateral",
                    "contact": "maintainedOnStartPlate",
                },
            },
        )
        authored_lunge_names = " ".join(
            value
            for exercise in lunge["exercises"]
            for value in [exercise["name"], *exercise["aliases"]]
        ).lower()
        for excluded in (
            "walking", "alternating", "stationary", "lateral", "crossover",
            "jump", "barbell", "dumbbell",
        ):
            with self.subTest(family="dynamic-lunge", excluded=excluded):
                self.assertNotIn(excluded, authored_lunge_names)
        for exercise in lunge["exercises"]:
            self.assertEqual(exercise["equipment"], "bodyweight")
            self.assertEqual(exercise["loadMode"], "nonComparable")
            self.assertEqual(exercise["bodyweightFraction"], 0)
            self.assertEqual(exercise["defaultWeight"], 0)
            self.assertNotIn("defaultWeightKg", exercise)

    def test_late_lower_body_evidence_scopes_preserve_material_limits(
        self,
    ) -> None:
        source_by_id = {
            source["id"]: source
            for source in self.foundation.evidence["sources"]
        }
        expected_phrases = {
            "okubo-2021-end-range-active-straight-leg-raise": (
                "Nine healthy men performed a supine active straight-leg raise",
                "Fine-wire psoas-major EMG",
                "does not establish a universal endpoint angle",
                "zero pelvic or spinal motion",
                "roles for sartorius, tensor fasciae latae, or adductors",
            ),
            "schellenberg-2013-deadlift-goodmorning-kinematics": (
                "added load equal to twenty-five percent of body mass",
                "material pelvis-lumbar and lumbar-thoracic excursion",
                "small nondefining knee motion",
                "did not measure EMG",
                "Romanian-deadlift, stiff-leg-deadlift, floor-pull, "
                "unilateral, or externally supported variants",
            ),
            "comfort-2015-forward-reverse-lunge-kinetics": (
                "standardized three-second eccentric and two-second "
                "concentric cadence",
                "selected front foot remained planted",
                "two discrete step-and-return records",
                "not walking or alternating locomotion, external loading, "
                "a fixed depth angle, EMG-based cross-muscle ranking",
                "lateral lunges, or jumping variants",
            ),
        }
        for source_id, phrases in expected_phrases.items():
            for phrase in phrases:
                with self.subTest(source=source_id, phrase=phrase):
                    self.assertIn(phrase, source_by_id[source_id]["scope"])

    def test_late_lower_body_runtime_projection_is_exact(self) -> None:
        records = catalog.compile_runtime_catalog(self.real_families)
        by_id = {record["catalogID"]: record for record in records}
        expected = {
            "bodyweight-active-straight-leg-raise": {
                "familyID": "hip-flexion",
                "mechanic": "isolation",
                "pattern": None,
                "direction": None,
                "planes": ["sagittal"],
                "equipment": "bodyweight",
                "laterality": "unilateral",
                "modality": "dynamicStrength",
                "trackingMode": "reps",
                "loadMode": "nonComparable",
                "defaultWeight": 0,
                "bodyweightFraction": 0,
                "reps": 10,
                "searchPriority": 68,
            },
            "barbell-good-morning-25-percent-body-mass": {
                "familyID": "hip-hinge",
                "mechanic": "compound",
                "pattern": "hinge",
                "direction": None,
                "planes": ["sagittal"],
                "equipment": "barbell",
                "laterality": "bilateral",
                "modality": "dynamicStrength",
                "trackingMode": "reps",
                "loadMode": "external",
                "defaultWeight": 45,
                "defaultWeightKg": 20,
                "bodyweightFraction": 0,
                "reps": 8,
                "searchPriority": 76,
            },
            "bodyweight-forward-lunge": {
                "familyID": "dynamic-lunge",
                "mechanic": "compound",
                "pattern": "lunge",
                "direction": None,
                "planes": ["sagittal"],
                "equipment": "bodyweight",
                "laterality": "unilateral",
                "modality": "dynamicStrength",
                "trackingMode": "reps",
                "loadMode": "nonComparable",
                "defaultWeight": 0,
                "bodyweightFraction": 0,
                "reps": 5,
                "searchPriority": 88,
            },
            "bodyweight-reverse-lunge": {
                "familyID": "dynamic-lunge",
                "mechanic": "compound",
                "pattern": "lunge",
                "direction": None,
                "planes": ["sagittal"],
                "equipment": "bodyweight",
                "laterality": "unilateral",
                "modality": "dynamicStrength",
                "trackingMode": "reps",
                "loadMode": "nonComparable",
                "defaultWeight": 0,
                "bodyweightFraction": 0,
                "reps": 5,
                "searchPriority": 87,
            },
        }
        source_exercises = {
            exercise["catalogID"]: exercise
            for family in self.late_lower_body_closure_families.values()
            for exercise in family["exercises"]
        }
        for catalog_id, projected in expected.items():
            record = by_id[catalog_id]
            with self.subTest(catalog_id=catalog_id):
                self.assertEqual(
                    {key: record[key] for key in projected},
                    projected,
                )
                self.assertEqual(
                    record["involvement"],
                    source_exercises[catalog_id]["involvement"],
                )
                self.assertEqual(
                    record["movementDefinition"],
                    source_exercises[catalog_id]["movementDefinition"],
                )
                self.assertNotIn("variant", record)

    def test_batch6_dorsiflexion_contract_and_roster_are_exact(self) -> None:
        family = self.batch6_families["ankle-dorsiflexion"]
        self.assertEqual(family["name"], "Ankle Dorsiflexion")
        self.assertEqual(
            family["fixed"],
            {
                "mechanic": "isolation",
                "pattern": None,
                "direction": None,
                "planes": ["sagittal"],
            },
        )
        self.assertEqual(
            family["movementSignature"]["planeBasisActions"],
            ["ankle.dorsiflexion"],
        )
        self.assertEqual(
            family["movementSignature"]["primeActions"],
            ["ankle.dorsiflexion"],
        )
        self.assertEqual(
            family["movementSignature"]["stabilityDemands"],
            ["ankle", "foot"],
        )
        self.assertEqual(
            family["musclePolicy"],
            {
                "requirements": [
                    {"anyOf": ["tibialisAnterior"], "minimumRole": "primary"}
                ],
                "allowedByRole": {
                    "primary": ["tibialisAnterior"],
                    "secondary": [],
                    "stabilizer": [],
                },
            },
        )
        self.assertEqual(
            family["allowed"],
            {
                "equipment": ["band"],
                "modalities": ["dynamicStrength"],
                "trackingModes": ["reps"],
                "loadModes": ["nonComparable"],
                "lateralities": ["unilateral"],
            },
        )
        self.assertEqual(family["groupPolicy"], {"default": "legs", "allowed": ["legs"]})
        self.assertEqual(
            family["recommended"]["defaultReps"],
            {"minimum": 15, "maximum": 30},
        )
        self.assertEqual(family["exerciseRules"], [])
        self.assertEqual(
            family["evidenceRefs"],
            ["arnold-2010-lower-limb", "kjeldsen-2019-dorsiflexor-training"],
        )

        exercise = family["exercises"][0]
        self.assertEqual(
            {
                "catalogID": exercise["catalogID"],
                "name": exercise["name"],
                "aliases": exercise["aliases"],
                "setup": (
                    exercise["equipment"],
                    exercise["laterality"],
                    exercise["modality"],
                    exercise["trackingMode"],
                    exercise["loadMode"],
                    exercise["bodyweightFraction"],
                    exercise["defaultWeight"],
                    exercise.get("defaultWeightKg"),
                    exercise["reps"],
                    exercise["searchPriority"],
                ),
                "involvement": exercise["involvement"],
                "evidence": exercise["evidenceRefs"],
            },
            {
                "catalogID": "seated-band-ankle-dorsiflexion",
                "name": "Seated Band Ankle Dorsiflexion",
                "aliases": [
                    "Band Ankle Dorsiflexion",
                    "Seated Band Dorsiflexion",
                    "Resistance Band Dorsiflexion",
                ],
                "setup": (
                    "band", "unilateral", "dynamicStrength", "reps",
                    "nonComparable", 0, 0, None, 15, 72,
                ),
                "involvement": [
                    {"muscle": "tibialisAnterior", "role": "primary"}
                ],
                "evidence": ["kjeldsen-2019-dorsiflexor-training"],
            },
        )
        self.assertEqual(exercise["additionalPrimeActions"], [])
        self.assertEqual(exercise["additionalStabilityDemands"], [])
        self.assertEqual(
            exercise["variant"],
            {
                "kineticChain": "open",
                "bodyPosition": "seated",
                "pelvisSupport": "seat",
                "kneeMotion": "positionHeld",
                "kneePosture": "selfSelected",
                "ankleMotion": "dorsiflexes",
                "ankleStartPosition": "selfSelectedRestingPosition",
                "rangeOfMotion": "toComfortableDorsiflexionStop",
                "movingSegment": "foot",
                "footBoardContact": "soleAtBottom",
                "loadInterface": "footUnderBand",
                "resistanceGeometry": "bandAffixedToFootBoard",
                "fixedPath": False,
                "lowerBodyContribution": "isolatedJointMotion",
            },
        )
        self.assertEqual(
            exercise["movementDefinition"],
            "Sit comfortably with the working foot resting on a board beneath "
            "an elastic band affixed to that board. Set a physical stop at the "
            "working ankle's comfortable dorsiflexion limit. Begin from the "
            "self-selected resting position with the sole on the board and hold "
            "the selected knee posture still. Dorsiflex the ankle to lift the "
            "foot toward the shin until reaching the stop, without deliberately "
            "turning the foot inward or outward or extending the toes to create "
            "the repetition. Return under control until the sole touches the "
            "board, then repeat before changing sides.",
        )

    def test_batch6_hip_contracts_and_rosters_are_exact(self) -> None:
        expected_families = {
            "hip-abduction": {
                "name": "Hip Abduction",
                "plane": "frontal",
                "action": "hip.abduction",
                "demands": ["hip", "pelvis", "knee"],
                "policy": {
                    "requirements": [
                        {"anyOf": ["gluteMed"], "minimumRole": "primary"},
                        {
                            "anyOf": ["tensorFasciaeLatae"],
                            "minimumRole": "secondary",
                        },
                    ],
                    "allowedByRole": {
                        "primary": ["gluteMed"],
                        "secondary": ["tensorFasciaeLatae"],
                        "stabilizer": [],
                    },
                },
                "allowed": {
                    "equipment": ["other"],
                    "modalities": ["dynamicStrength"],
                    "trackingModes": ["reps"],
                    "loadModes": ["external"],
                    "lateralities": ["unilateral"],
                },
                "reps": {"minimum": 10, "maximum": 20},
                "evidence": [
                    "arnold-2010-lower-limb",
                    "mcbeth-2012-side-lying-hip-abduction",
                ],
                "roster": "pressure-biofeedback-side-lying-hip-abduction",
            },
            "hip-adduction": {
                "name": "Hip Adduction",
                "plane": "frontal",
                "action": "hip.adduction",
                "demands": ["hip", "pelvis", "knee", "spine"],
                "policy": {
                    "requirements": [
                        {
                            "anyOf": ["adductorLongusBrevis"],
                            "minimumRole": "primary",
                        },
                        {"anyOf": ["gracilis"], "minimumRole": "secondary"},
                        {"anyOf": ["abs"], "minimumRole": "stabilizer"},
                        {"anyOf": ["obliques"], "minimumRole": "stabilizer"},
                        {"anyOf": ["gluteMed"], "minimumRole": "stabilizer"},
                    ],
                    "allowedByRole": {
                        "primary": ["adductorLongusBrevis"],
                        "secondary": ["gracilis"],
                        "stabilizer": ["abs", "obliques", "gluteMed"],
                    },
                },
                "allowed": {
                    "equipment": ["band"],
                    "modalities": ["dynamicStrength"],
                    "trackingModes": ["reps"],
                    "loadModes": ["nonComparable"],
                    "lateralities": ["unilateral"],
                },
                "reps": {"minimum": 8, "maximum": 15},
                "evidence": [
                    "arnold-2010-lower-limb",
                    "serner-2014-hip-adduction-exercises",
                    "jensen-2014-elastic-hip-adduction-training",
                ],
                "roster": "supported-standing-band-hip-adduction",
            },
            "hip-internal-rotation": {
                "name": "Hip Internal Rotation",
                "plane": "transverse",
                "action": {
                    "action": "hip.internalRotation",
                    "condition": "atNinetyDegreeHipFlexion",
                },
                "demands": ["hip", "pelvis", "knee", "spine"],
                "policy": {
                    "requirements": [
                        {"anyOf": ["gluteMed"], "minimumRole": "primary"},
                        {
                            "anyOf": ["tensorFasciaeLatae"],
                            "minimumRole": "primary",
                        },
                        {"anyOf": ["gluteMin"], "minimumRole": "secondary"},
                        {"anyOf": ["obliques"], "minimumRole": "stabilizer"},
                    ],
                    "allowedByRole": {
                        "primary": ["gluteMed", "tensorFasciaeLatae"],
                        "secondary": ["gluteMin"],
                        "stabilizer": ["obliques"],
                    },
                },
                "allowed": {
                    "equipment": ["other"],
                    "modalities": ["dynamicStrength"],
                    "trackingModes": ["reps"],
                    "loadModes": ["nonComparable"],
                    "lateralities": ["unilateral"],
                },
                "reps": {"minimum": 7, "maximum": 7},
                "evidence": [
                    "delp-1999-hip-rotation-moment-arms",
                    "lahuerta-martin-2024-flywheel-hip-rotation",
                    "peduzzi-de-castro-2021-hip-rotation-isometric",
                ],
                "roster": "seated-flywheel-hip-internal-rotation",
            },
            "hip-external-rotation": {
                "name": "Hip External Rotation",
                "plane": "transverse",
                "action": {
                    "action": "hip.externalRotation",
                    "condition": "atThirtyDegreeHipFlexion",
                },
                "demands": ["hip", "pelvis", "knee", "spine"],
                "policy": {
                    "requirements": [
                        {
                            "anyOf": ["obturatorInternusGemelli"],
                            "minimumRole": "primary",
                        },
                        {
                            "anyOf": ["obturatorExternus"],
                            "minimumRole": "secondary",
                        },
                        {"anyOf": ["piriformis"], "minimumRole": "secondary"},
                        {
                            "anyOf": ["quadratusFemoris"],
                            "minimumRole": "secondary",
                        },
                        {"anyOf": ["obliques"], "minimumRole": "stabilizer"},
                        {
                            "anyOf": ["medialHamstrings"],
                            "minimumRole": "stabilizer",
                        },
                    ],
                    "allowedByRole": {
                        "primary": ["obturatorInternusGemelli"],
                        "secondary": [
                            "obturatorExternus",
                            "piriformis",
                            "quadratusFemoris",
                        ],
                        "stabilizer": ["obliques", "medialHamstrings"],
                    },
                },
                "allowed": {
                    "equipment": ["band"],
                    "modalities": ["dynamicStrength"],
                    "trackingModes": ["reps"],
                    "loadModes": ["nonComparable"],
                    "lateralities": ["unilateral"],
                },
                "reps": {"minimum": 10, "maximum": 10},
                "evidence": [
                    "delp-1999-hip-rotation-moment-arms",
                    "ito-2025-short-hip-external-rotator-torque",
                    "vaarbakken-2015-quadratus-femoris-obturator-externus",
                    "matthews-2017-fohx-protocol",
                    "matthews-2020-fohx-trial",
                ],
                "roster": "therapist-held-supine-band-hip-external-rotation",
            },
        }
        self.assertEqual(
            set(self.batch6_families),
            {*expected_families, "ankle-dorsiflexion"},
        )
        for family_id, expected in expected_families.items():
            family = self.batch6_families[family_id]
            with self.subTest(family=family_id):
                self.assertEqual(family["name"], expected["name"])
                self.assertEqual(
                    family["fixed"],
                    {
                        "mechanic": "isolation",
                        "pattern": None,
                        "direction": None,
                        "planes": [expected["plane"]],
                    },
                )
                self.assertEqual(
                    family["movementSignature"]["planeBasisActions"],
                    [
                        expected["action"]["action"]
                        if isinstance(expected["action"], dict)
                        else expected["action"]
                    ],
                )
                self.assertEqual(
                    family["movementSignature"]["primeActions"],
                    [expected["action"]],
                )
                self.assertEqual(
                    family["movementSignature"]["stabilityDemands"],
                    expected["demands"],
                )
                self.assertEqual(family["musclePolicy"], expected["policy"])
                self.assertEqual(family["allowed"], expected["allowed"])
                self.assertEqual(
                    family["groupPolicy"],
                    {"default": "legs", "allowed": ["legs"]},
                )
                self.assertEqual(
                    family["recommended"]["defaultReps"], expected["reps"]
                )
                self.assertEqual(family["evidenceRefs"], expected["evidence"])
                self.assertEqual(family["exerciseRules"], [])
                self.assertEqual(
                    [exercise["catalogID"] for exercise in family["exercises"]],
                    [expected["roster"]],
                )

        abduction = self.batch6_families["hip-abduction"]["exercises"][0]
        self.assertEqual(
            {
                "name": abduction["name"],
                "aliases": abduction["aliases"],
                "setup": (
                    abduction["equipment"], abduction["laterality"],
                    abduction["modality"], abduction["trackingMode"],
                    abduction["loadMode"], abduction["bodyweightFraction"],
                    abduction["defaultWeight"], abduction.get("defaultWeightKg"),
                    abduction["reps"], abduction["searchPriority"],
                ),
                "roles": {
                    item["muscle"]: item["role"]
                    for item in abduction["involvement"]
                },
                "evidence": abduction["evidenceRefs"],
            },
            {
                "name": "Pressure-Biofeedback Side-Lying Hip Abduction",
                "aliases": [
                    "PBU Side-Lying Hip Abduction",
                    "Pressure-Biofeedback Cuff-Weight Hip Abduction",
                ],
                "setup": (
                    "other", "unilateral", "dynamicStrength", "reps",
                    "external", 0, 5, 2.5, 12, 80,
                ),
                "roles": {
                    "gluteMed": "primary",
                    "tensorFasciaeLatae": "secondary",
                },
                "evidence": ["mcbeth-2012-side-lying-hip-abduction"],
            },
        )
        self.assertEqual(
            abduction["movementDefinition"],
            "Lie on one side on a treatment table with the working leg on top, "
            "the hip neutral in flexion-extension and axial rotation, the lower "
            "leg flexed for stability, and a cuff weight secured just above the "
            "working ankle. Place a pressure-biofeedback unit beneath the trunk, "
            "inflate it to 40 mmHg, and keep it between 35 and 45 mmHg while a "
            "horizontal contact band marks 35 degrees of abduction. Keep the "
            "pelvis and spine still, the working knee straight, and the toes "
            "pointing forward. Raise the straight top leg in the frontal plane "
            "until it contacts the endpoint band, then lower it under control "
            "without rolling the pelvis or turning the toes upward.",
        )
        self.assertNotIn(
            "Side-Lying Hip Abduction",
            [abduction["name"], *abduction["aliases"]],
        )

        adduction = self.batch6_families["hip-adduction"]["exercises"][0]
        self.assertEqual(
            {
                "name": adduction["name"],
                "aliases": adduction["aliases"],
                "setup": (
                    adduction["equipment"], adduction["laterality"],
                    adduction["modality"], adduction["trackingMode"],
                    adduction["loadMode"], adduction["bodyweightFraction"],
                    adduction["defaultWeight"], adduction.get("defaultWeightKg"),
                    adduction["reps"], adduction["searchPriority"],
                ),
                "roles": {
                    item["muscle"]: item["role"]
                    for item in adduction["involvement"]
                },
                "evidence": adduction["evidenceRefs"],
            },
            {
                "name": "Supported Standing Band Hip Adduction",
                "aliases": ["Standing Band Hip Adduction", "Band Hip Adduction"],
                "setup": (
                    "band", "unilateral", "dynamicStrength", "reps",
                    "nonComparable", 0, 0, None, 10, 80,
                ),
                "roles": {
                    "adductorLongusBrevis": "primary",
                    "gracilis": "secondary",
                    "abs": "stabilizer",
                    "obliques": "stabilizer",
                    "gluteMed": "stabilizer",
                },
                "evidence": [
                    "serner-2014-hip-adduction-exercises",
                    "jensen-2014-elastic-hip-adduction-training",
                ],
            },
        )
        self.assertEqual(
            adduction["movementDefinition"],
            "Stand upright on the support leg while holding a stable external "
            "support with both hands and secure an elastic band around the "
            "working ankle from the side. Place the straight working leg in "
            "maximal comfortable abduction with tension already in the band and "
            "hold it at the same slight posterior hip posture used at the "
            "endpoint. Keep the pelvis still, the working knee straight, and "
            "both sets of toes pointing forward as you draw the working thigh "
            "medially without swinging it farther backward, finishing one "
            "foot-width lateral to and about half a foot-length behind the stance "
            "foot. Return under control along the same strictly frontal path, "
            "then repeat before changing sides.",
        )
        for exercise in (abduction, adduction):
            self.assertEqual(exercise["additionalPrimeActions"], [])
            self.assertEqual(exercise["additionalStabilityDemands"], [])

    def test_batch6_rotation_records_and_role_exclusions_are_exact(self) -> None:
        expected = {
            "hip-internal-rotation": {
                "identity": (
                    "seated-flywheel-hip-internal-rotation",
                    "Seated Flywheel Hip Internal Rotation",
                    [
                        "Flywheel Hip Internal Rotation",
                        "Seated Flywheel Internal Rotation",
                    ],
                ),
                "setup": (
                    "other", "unilateral", "dynamicStrength", "reps",
                    "nonComparable", 0, 0, None, 7, 65,
                ),
                "roles": {
                    "gluteMed": "primary",
                    "tensorFasciaeLatae": "primary",
                    "gluteMin": "secondary",
                    "obliques": "stabilizer",
                },
                "evidence": ["lahuerta-martin-2024-flywheel-hip-rotation"],
            },
            "hip-external-rotation": {
                "identity": (
                    "therapist-held-supine-band-hip-external-rotation",
                    "Therapist-Held Supine Band Hip External Rotation",
                    [
                        "Supine Band Hip External Rotation",
                        "Therapist-Resisted Hip External Rotation",
                    ],
                ),
                "setup": (
                    "band", "unilateral", "dynamicStrength", "reps",
                    "nonComparable", 0, 0, None, 10, 72,
                ),
                "roles": {
                    "obturatorInternusGemelli": "primary",
                    "obturatorExternus": "secondary",
                    "piriformis": "secondary",
                    "quadratusFemoris": "secondary",
                    "obliques": "stabilizer",
                    "medialHamstrings": "stabilizer",
                },
                "evidence": [
                    "matthews-2017-fohx-protocol",
                    "matthews-2020-fohx-trial",
                ],
            },
        }
        for family_id, contract in expected.items():
            exercise = self.batch6_families[family_id]["exercises"][0]
            with self.subTest(family=family_id):
                self.assertEqual(
                    (
                        exercise["catalogID"],
                        exercise["name"],
                        exercise["aliases"],
                    ),
                    contract["identity"],
                )
                self.assertEqual(
                    (
                        exercise["equipment"], exercise["laterality"],
                        exercise["modality"], exercise["trackingMode"],
                        exercise["loadMode"], exercise["bodyweightFraction"],
                        exercise["defaultWeight"],
                        exercise.get("defaultWeightKg"), exercise["reps"],
                        exercise["searchPriority"],
                    ),
                    contract["setup"],
                )
                self.assertEqual(
                    {
                        item["muscle"]: item["role"]
                        for item in exercise["involvement"]
                    },
                    contract["roles"],
                )
                self.assertEqual(exercise["evidenceRefs"], contract["evidence"])
                self.assertEqual(exercise["additionalPrimeActions"], [])
                self.assertEqual(exercise["additionalStabilityDemands"], [])

        external_muscles = {
            item["muscle"]
            for item in self.batch6_families["hip-external-rotation"][
                "exercises"
            ][0]["involvement"]
        }
        self.assertTrue(
            {"sartorius", "gluteMax", "gluteMed"}.isdisjoint(external_muscles)
        )

    def test_batch6_dorsiflexion_axes_and_boundaries_are_exact(self) -> None:
        family = self.batch6_families["ankle-dorsiflexion"]
        actual = {}
        for axis in family["variantAxes"]:
            self.assertTrue(axis["required"])
            if axis["valueType"] == "enum":
                actual[axis["id"]] = tuple(axis["allowedValues"])
            elif axis["valueType"] == "boolean":
                actual[axis["id"]] = axis["fixedValue"]
            else:
                self.fail(f"unexpected dorsiflexion axis type {axis['valueType']}")
        self.assertEqual(
            actual,
            {
                "kineticChain": ("open",),
                "bodyPosition": ("seated",),
                "pelvisSupport": ("seat",),
                "kneeMotion": ("positionHeld",),
                "kneePosture": ("selfSelected",),
                "ankleMotion": ("dorsiflexes",),
                "ankleStartPosition": ("selfSelectedRestingPosition",),
                "rangeOfMotion": ("toComfortableDorsiflexionStop",),
                "movingSegment": ("foot",),
                "footBoardContact": ("soleAtBottom",),
                "loadInterface": ("footUnderBand",),
                "resistanceGeometry": ("bandAffixedToFootBoard",),
                "fixedPath": False,
                "lowerBodyContribution": ("isolatedJointMotion",),
            },
        )
        exercise = family["exercises"][0]
        assigned = {item["muscle"] for item in exercise["involvement"]}
        self.assertEqual(assigned, {"tibialisAnterior"})
        self.assertTrue(
            {
                "fibularisTertius", "toeExtensors", "fibularisLongusBrevis",
                "gastrocnemius", "soleus", "flexorHallucisLongus",
            }.isdisjoint(assigned)
        )
        self.assertFalse(
            any(
                "tibialis raise" in value.lower()
                or "blood flow" in value.lower()
                or "machine" in value.lower()
                for value in [exercise["name"], *exercise["aliases"]]
            )
        )

    def test_batch6_hip_axes_are_exact_and_fully_covered(self) -> None:
        def enum(*values: object) -> tuple[str, tuple[object, ...]]:
            return ("enum", values)

        def number(value: float) -> tuple[str, float, float]:
            return ("number", value, value)

        expected = {
            "hip-abduction": {
                "kineticChain": enum("open"),
                "bodyPosition": enum("sideLying"),
                "torsoSupport": enum("table"),
                "pelvisSupport": enum("table"),
                "supportLegPosture": enum("flexedForStability"),
                "pelvisMotion": enum("positionHeld"),
                "spineMotion": enum("positionHeld"),
                "hipMotion": enum("abducts"),
                "hipSagittalPosture": enum("neutral"),
                "hipStartAbductionDegrees": number(0),
                "hipEndAbductionDegrees": number(35),
                "hipRotation": enum("neutral"),
                "trunkPositionFeedback": enum(
                    "pressureBiofeedback35To45MmHg"
                ),
                "abductionEndpointReference": enum("horizontalContactBand"),
                "kneeMotion": enum("positionHeld"),
                "kneePosture": enum("extended"),
                "movingSegment": enum("thigh"),
                "loadInterface": enum("cuffJustAboveAnkle"),
                "resistanceGeometry": enum("gravityLoadedAnkleCuff"),
                "fixedPath": ("boolean", False),
                "lowerBodyContribution": enum("isolatedJointMotion"),
            },
            "hip-adduction": {
                "kineticChain": enum("open"),
                "bodyPosition": enum("standing"),
                "torsoSupport": enum("none"),
                "handSupport": enum("bothHandsOnStableExternalSupport"),
                "pelvisMotion": enum("positionHeld"),
                "spineMotion": enum("positionHeld"),
                "hipMotion": enum("adducts"),
                "hipStartPosition": enum("maximalComfortableAbduction"),
                "frontalEndDistance": enum("oneFootWidthFromStanceFoot"),
                "hipSagittalPosture": enum("slightExtensionHeld"),
                "hipRotation": enum("neutral"),
                "kneeMotion": enum("positionHeld"),
                "kneePosture": enum("extended"),
                "movingSegment": enum("thigh"),
                "loadInterface": enum("bandCuffAtAnkle"),
                "resistanceGeometry": enum("lateralBandAnchor"),
                "fixedPath": ("boolean", False),
                "lowerBodyContribution": enum("isolatedJointMotion"),
            },
            "hip-internal-rotation": {
                "kineticChain": enum("open"),
                "bodyPosition": enum("seated"),
                "seatSurface": enum("hydraulicTreatmentTable"),
                "seatHeightCm": number(75),
                "torsoSupport": enum("none"),
                "handPosition": enum("crossedOnOppositeShoulders"),
                "footSupport": enum("bothSuspended"),
                "pelvisPosture": enum("neutral"),
                "pelvisFixation": enum("bilateralASISBelts"),
                "distalFemurFixation": enum("belt"),
                "hipMotion": enum("internallyRotatesThenReturns"),
                "hipFlexionDegrees": number(90),
                "kneeMotion": enum("positionHeld"),
                "kneeFlexionDegrees": number(90),
                "movingSegment": enum("lowerLeg"),
                "loadInterface": enum("ankleBraceAndCarabiner"),
                "resistanceGeometry": enum(
                    "ankleCableToRotaryAxisFlywheel"
                ),
                "flywheelModel": enum("conicPowerMove"),
                "flywheelMount": enum("horizontalWallFixed"),
                "flywheelHeightAboveFloorCm": number(7),
                "flywheelMeanDiameterCm": number(7.5),
                "flywheelAttachedLoadGrams": number(460),
                "flywheelAxisDistanceCm": number(15),
                "slidingFramePosition": enum("upperMiddle"),
                "cableLengthSetting": enum("maximumActiveHipRotationRange"),
                "concentricIntent": enum("asFastAsPossible"),
                "eccentricIntent": enum(
                    "counteractGeneratedFlywheelInertia"
                ),
                "fixedPath": ("boolean", False),
                "lowerBodyContribution": enum("isolatedHipRotation"),
            },
            "hip-external-rotation": {
                "kineticChain": enum("open"),
                "bodyPosition": enum("supine"),
                "torsoSupport": enum("table"),
                "pelvisSupport": enum("table"),
                "hipFlexionSupport": enum("wedgeUnderBothThighs"),
                "contralateralLegPosture": enum(
                    "hipAndKneeFlexedOverWedge"
                ),
                "pelvisMotion": enum("positionHeld"),
                "spineMotion": enum("positionHeld"),
                "hipMotion": enum("externallyRotates"),
                "hipFlexionDegrees": number(30),
                "hipStartRotation": enum("neutral"),
                "hipEndRotation": enum("midAvailableExternalRotation"),
                "kneeMotion": enum("positionHeld"),
                "kneePosture": enum("flexedOverWedge"),
                "kneeSupport": enum("therapistStabilized"),
                "movingSegment": enum("lowerLeg"),
                "loadInterface": enum("bandAtWorkingAnkle"),
                "resistanceGeometry": enum(
                    "therapistHeldAnkleBandOpposesExternalRotation"
                ),
                "loadPrescription": enum("approximatelyTenToTwelveRM"),
                "fixedPath": ("boolean", False),
                "lowerBodyContribution": enum("isolatedJointMotion"),
            },
        }
        for family_id, expected_axes in expected.items():
            family = self.batch6_families[family_id]
            actual = {}
            for axis in family["variantAxes"]:
                self.assertTrue(axis["required"])
                observed = {
                    exercise["variant"][axis["id"]]
                    for exercise in family["exercises"]
                }
                if axis["valueType"] == "enum":
                    actual[axis["id"]] = ("enum", tuple(axis["allowedValues"]))
                    self.assertEqual(observed, set(axis["allowedValues"]))
                elif axis["valueType"] == "number":
                    actual[axis["id"]] = (
                        "number", axis["minimum"], axis["maximum"]
                    )
                    self.assertEqual(observed, {axis["minimum"], axis["maximum"]})
                elif axis["valueType"] == "boolean":
                    actual[axis["id"]] = ("boolean", axis["fixedValue"])
                    self.assertEqual(observed, {axis["fixedValue"]})
                else:
                    self.fail(f"unexpected Batch-6 axis type {axis['valueType']}")
            with self.subTest(family=family_id):
                self.assertEqual(actual, expected_axes)

    def test_batch6_one_record_contracts_mutate_every_axis_and_domain(self) -> None:
        mutation_count = 0
        for family_id, original in self.batch6_families.items():
            self.assertEqual(len(original["exercises"]), 1)
            self.assertEqual(original["exerciseRules"], [])
            for axis in original["variantAxes"]:
                family = copy.deepcopy(original)
                if axis["valueType"] == "enum":
                    family["exercises"][0]["variant"][axis["id"]] = "mutated"
                    expected_error = re.escape(
                        f"variant.{axis['id']} has disallowed value 'mutated'"
                    )
                elif axis["valueType"] == "boolean":
                    family["exercises"][0]["variant"][axis["id"]] = not axis[
                        "fixedValue"
                    ]
                    expected_error = re.escape(
                        f"variant.{axis['id']} must equal fixed value "
                        f"{axis['fixedValue']!r}"
                    )
                elif axis["valueType"] == "number":
                    family["exercises"][0]["variant"][axis["id"]] = (
                        axis["maximum"] + 1
                    )
                    if (
                        axis["id"] == "hipFlexionDegrees"
                        and family_id
                        in {"hip-internal-rotation", "hip-external-rotation"}
                    ):
                        condition = original["movementSignature"][
                            "primeActions"
                        ][0]["condition"]
                        expected_error = re.escape(
                            f"action condition {condition} requires "
                            f"variant.hipFlexionDegrees == {axis['maximum']}"
                        )
                    else:
                        expected_error = re.escape(
                            f"variant.{axis['id']} exceeds {axis['maximum']}"
                        )
                else:
                    self.fail(f"unexpected Batch-6 axis type {axis['valueType']}")
                with self.subTest(family=family_id, axis=axis["id"]):
                    self.assert_batch6_family_fails(family, expected_error)
                mutation_count += 1

            domains = {
                "equipment": ("equipment", catalog.EQUIPMENT),
                "laterality": ("lateralities", catalog.LATERALITIES),
                "modality": ("modalities", catalog.MODALITIES),
                "trackingMode": ("trackingModes", catalog.TRACKING_MODES),
                "loadMode": ("loadModes", catalog.LOAD_MODES),
            }
            for field, (allowed_key, domain) in domains.items():
                family = copy.deepcopy(original)
                value = sorted(domain - set(family["allowed"][allowed_key]))[0]
                family["exercises"][0][field] = value
                with self.subTest(family=family_id, field=field):
                    self.assert_batch6_family_fails(
                        family,
                        re.escape(f"selects disallowed {allowed_key}: {value}"),
                    )
                mutation_count += 1
        self.assertEqual(mutation_count, 128)

    def test_batch6_forbids_every_other_known_prime_action(self) -> None:
        mutation_count = 0
        for family_id, original in self.batch6_families.items():
            own = {
                action if isinstance(action, str) else action["action"]
                for action in original["movementSignature"]["primeActions"]
            }
            expected = set(self.foundation.action_ids) - own
            self.assertEqual(
                set(original["movementSignature"]["forbiddenPrimeActions"]),
                expected,
            )
            for action in expected:
                family = copy.deepcopy(original)
                family["exercises"][0]["additionalPrimeActions"] = [action]
                with self.subTest(family=family_id, action=action):
                    self.assert_batch6_family_fails(
                        family,
                        f"declares forbidden prime action {re.escape(action)}",
                    )
                mutation_count += 1
        self.assertEqual(mutation_count, 215)

    def test_batch6_required_roles_are_removed_and_demoted_directly(self) -> None:
        primary_substitutes = {
            "hip-abduction": ("tensorFasciaeLatae", "gluteMed"),
            "hip-adduction": ("gracilis", "adductorLongusBrevis"),
            "ankle-dorsiflexion": ("fibularisTertius", "tibialisAnterior"),
            "hip-internal-rotation": ("gluteMed", "tensorFasciaeLatae"),
            "hip-external-rotation": (
                "obturatorExternus",
                "obturatorInternusGemelli",
            ),
        }
        removal_count = 0
        demotion_count = 0
        lower_role = {"primary": "secondary", "secondary": "stabilizer"}
        for family_id, original in self.batch6_families.items():
            for requirement_index, requirement in enumerate(
                original["musclePolicy"]["requirements"]
            ):
                candidate = requirement["anyOf"][0]
                family = copy.deepcopy(original)
                exercise = family["exercises"][0]
                role = next(
                    item["role"]
                    for item in exercise["involvement"]
                    if item["muscle"] == candidate
                )
                exercise["involvement"] = [
                    item
                    for item in exercise["involvement"]
                    if item["muscle"] != candidate
                ]
                if role == "primary":
                    substitutes = primary_substitutes[family_id]
                    substitute = next(
                        muscle_id
                        for muscle_id in substitutes
                        if muscle_id != candidate
                    )
                    substitute_item = next(
                        (
                            item for item in exercise["involvement"]
                            if item["muscle"] == substitute
                        ),
                        None,
                    )
                    if substitute_item is None:
                        substitute_item = {
                            "muscle": substitute,
                            "role": "primary",
                        }
                        exercise["involvement"].append(substitute_item)
                    else:
                        substitute_item["role"] = "primary"
                    allowed = family["musclePolicy"]["allowedByRole"]["primary"]
                    if substitute not in allowed:
                        allowed.append(substitute)
                with self.subTest(
                    family=family_id,
                    requirement=requirement_index,
                    mutation="remove",
                ):
                    self.assert_batch6_family_fails(
                        family,
                        f"fails muscle requirement {requirement_index}",
                    )
                removal_count += 1

                if requirement["minimumRole"] == "stabilizer":
                    continue
                family = copy.deepcopy(original)
                exercise = family["exercises"][0]
                demoted_role = lower_role[requirement["minimumRole"]]
                family["musclePolicy"]["allowedByRole"][demoted_role].append(
                    candidate
                )
                next(
                    item for item in exercise["involvement"]
                    if item["muscle"] == candidate
                )["role"] = demoted_role
                if requirement["minimumRole"] == "primary":
                    substitutes = primary_substitutes[family_id]
                    substitute = next(
                        muscle_id
                        for muscle_id in substitutes
                        if muscle_id != candidate
                    )
                    substitute_item = next(
                        (
                            item for item in exercise["involvement"]
                            if item["muscle"] == substitute
                        ),
                        None,
                    )
                    if substitute_item is None:
                        substitute_item = {
                            "muscle": substitute,
                            "role": "primary",
                        }
                        exercise["involvement"].append(substitute_item)
                    else:
                        substitute_item["role"] = "primary"
                    allowed = family["musclePolicy"]["allowedByRole"]["primary"]
                    if substitute not in allowed:
                        allowed.append(substitute)
                with self.subTest(
                    family=family_id,
                    requirement=requirement_index,
                    mutation="demote",
                ):
                    self.assert_batch6_family_fails(
                        family,
                        f"fails muscle requirement {requirement_index}",
                    )
                demotion_count += 1
        self.assertEqual(removal_count, 18)
        self.assertEqual(demotion_count, 12)

    def test_batch6_stability_demands_have_exact_role_agnostic_providers(
        self,
    ) -> None:
        expected = {
            "pressure-biofeedback-side-lying-hip-abduction": {
                "hip": {"gluteMed", "tensorFasciaeLatae"},
                "pelvis": {"gluteMed", "tensorFasciaeLatae"},
                "knee": {"tensorFasciaeLatae"},
            },
            "supported-standing-band-hip-adduction": {
                "hip": {"adductorLongusBrevis", "gracilis", "gluteMed"},
                "pelvis": {
                    "adductorLongusBrevis", "gracilis", "abs", "obliques",
                    "gluteMed",
                },
                "knee": {"gracilis"},
                "spine": {"abs", "obliques"},
            },
            "seated-band-ankle-dorsiflexion": {
                "ankle": {"tibialisAnterior"},
                "foot": {"tibialisAnterior"},
            },
            "seated-flywheel-hip-internal-rotation": {
                "hip": {
                    "gluteMed", "tensorFasciaeLatae", "gluteMin",
                },
                "pelvis": {
                    "gluteMed", "tensorFasciaeLatae", "gluteMin", "obliques",
                },
                "knee": {"tensorFasciaeLatae"},
                "spine": {"obliques"},
            },
            "therapist-held-supine-band-hip-external-rotation": {
                "hip": {
                    "obturatorInternusGemelli", "obturatorExternus",
                    "piriformis", "quadratusFemoris", "medialHamstrings",
                },
                "pelvis": {"obliques", "medialHamstrings"},
                "knee": {"medialHamstrings"},
                "spine": {"obliques"},
            },
        }
        for family in self.batch6_families.values():
            exercise = family["exercises"][0]
            assigned = {item["muscle"] for item in exercise["involvement"]}
            actual = {
                region: {
                    muscle_id
                    for muscle_id in assigned
                    if region
                    in self.foundation.profile_by_muscle[muscle_id]["stabilizes"]
                }
                for region in family["movementSignature"]["stabilityDemands"]
            }
            with self.subTest(exercise=exercise["catalogID"]):
                self.assertEqual(actual, expected[exercise["catalogID"]])

    def test_batch6_load_seeds_and_anatomy_credit_are_conservative(self) -> None:
        abduction = self.batch6_families["hip-abduction"]["exercises"][0]
        self.assertEqual(abduction["loadMode"], "external")
        self.assertEqual(abduction["defaultWeight"], 5)
        self.assertEqual(abduction["defaultWeightKg"], 2.5)
        self.assertEqual(abduction["bodyweightFraction"], 0)
        self.assertTrue(
            {"gluteMin", "gluteMax"}.isdisjoint(
                item["muscle"] for item in abduction["involvement"]
            )
        )

        for family_id in {"hip-adduction", "ankle-dorsiflexion"}:
            exercise = self.batch6_families[family_id]["exercises"][0]
            with self.subTest(family=family_id):
                self.assertEqual(exercise["equipment"], "band")
                self.assertEqual(exercise["loadMode"], "nonComparable")
                self.assertEqual(exercise["bodyweightFraction"], 0)
                self.assertEqual(exercise["defaultWeight"], 0)
                self.assertNotIn("defaultWeightKg", exercise)

        adduction_muscles = {
            item["muscle"]
            for item in self.batch6_families["hip-adduction"]["exercises"][0][
                "involvement"
            ]
        }
        self.assertTrue(
            {"adductorMagnus", "pectineus"}.isdisjoint(adduction_muscles)
        )

    def test_batch6_evidence_scopes_preserve_material_limitations(self) -> None:
        source_by_id = {
            source["id"]: source for source in self.foundation.evidence["sources"]
        }
        self.assertEqual(len(source_by_id), 149)
        self.assertTrue(
            {
                "mcbeth-2012-side-lying-hip-abduction",
                "serner-2014-hip-adduction-exercises",
                "jensen-2014-elastic-hip-adduction-training",
                "kjeldsen-2019-dorsiflexor-training",
                "delp-1999-hip-rotation-moment-arms",
                "peduzzi-de-castro-2021-hip-rotation-isometric",
                "lahuerta-martin-2024-flywheel-hip-rotation",
                "beck-2000-gluteus-minimus",
                "ito-2025-short-hip-external-rotator-torque",
                "vaarbakken-2015-quadratus-femoris-obturator-externus",
                "matthews-2017-fohx-protocol",
                "matthews-2020-fohx-trial",
            }.issubset(source_by_id)
        )
        expected = {
            "mcbeth-2012-side-lying-hip-abduction": (
                "pressure biofeedback beneath the trunk inflated to 40 mmHg",
                "did not compare feedback with no feedback",
                "does not support a no-feedback adaptation",
            ),
            "serner-2014-hip-adduction-exercises": (
                "Gluteus medius reached 18 percent MVC on both measured sides",
                "supports categorical hip-and-pelvis stabilization credit",
                "sagittal coordinate of the abducted start and the three-dimensional path were not reported",
                "not internal-oblique measurement, gracilis ranking",
            ),
            "jensen-2014-elastic-hip-adduction-training": (
                "upper body was fixed to a stationary object with both hands",
                "supports the bilateral stable-hand setup",
                "does not establish a separate hip-extension prime action or directly support the catalog's mechanics-derived held-posterior adaptation",
                "not muscle-specific roles, a comparable external load",
            ),
            "kjeldsen-2019-dorsiflexor-training": (
                "does not establish fibularis-tertius or toe-extensor roles",
            ),
        }
        for source_id, phrases in expected.items():
            for phrase in phrases:
                with self.subTest(source=source_id, phrase=phrase):
                    self.assertIn(phrase, source_by_id[source_id]["scope"])

        proposal = (
            catalog.SPEC_ROOT
            / "proposals"
            / "batch-6-hip-abduction-adduction.md"
        ).read_text(encoding="utf-8")
        normalized = " ".join(proposal.split())
        self.assertIn(
            "3D highlight and volume credit understated the full abductor system",
            normalized,
        )
        self.assertIn("still understate it today", normalized)
        self.assertIn(
            "Anatomy alone does not justify awarding adductor magnus or pectineus exercise volume",
            normalized,
        )
        self.assertIn(
            "Brandt 2013 was reviewed as context but has no DOI and is neither needed nor registered",
            normalized,
        )
        self.assertIn(
            "The active fixture makes one transparent catalog-authored adaptation",
            normalized,
        )
        self.assertIn(
            "Serner measured external oblique only; the visible `obliques` region also contains internal oblique",
            normalized,
        )

    def test_batch6_rotation_candidates_are_active_and_evidence_backed(self) -> None:
        active_ids = {family["id"] for family in self.real_families}
        rotation_ids = {"hip-internal-rotation", "hip-external-rotation"}
        self.assertTrue(rotation_ids <= active_ids)
        for family_id in rotation_ids:
            self.assertTrue((catalog.FAMILIES_ROOT / f"{family_id}.json").exists())

        proposal = (
            catalog.SPEC_ROOT / "proposals" / "batch-6-hip-rotation.md"
        ).read_text(encoding="utf-8")
        normalized = " ".join(proposal.split())
        self.assertIn(
            "`hip-internal-rotation` | Activate one exact 90-degree fixture | 1",
            normalized,
        )
        self.assertIn(
            "`hip-external-rotation` | Activate one exact 30-degree fixture | 1",
            normalized,
        )
        self.assertIn(
            "exactly 58 taxonomy IDs and 60 trainable mesh bases",
            normalized,
        )

        registered_ids = {
            source["id"] for source in self.foundation.evidence["sources"]
        }
        self.assertTrue(
            {
                "delp-1999-hip-rotation-moment-arms",
                "peduzzi-de-castro-2021-hip-rotation-isometric",
                "lahuerta-martin-2024-flywheel-hip-rotation",
                "beck-2000-gluteus-minimus",
                "ito-2025-short-hip-external-rotator-torque",
                "vaarbakken-2015-quadratus-femoris-obturator-externus",
                "matthews-2017-fohx-protocol",
                "matthews-2020-fohx-trial",
            } <= registered_ids
        )

    def test_batch7_activates_exactly_nine_families_and_nine_records(
        self,
    ) -> None:
        expected_rosters = {
            "spine-flexion": ["30-degree-curl-up"],
            "spine-extension": ["medx-isolated-lumbar-extension"],
            "spine-lateral-flexion": ["fixed-leg-side-lying-lateral-trunk-lift"],
            "spine-rotation": ["seated-machine-torso-twist"],
            "anti-extension": ["plank"],
            "anti-lateral-flexion": ["side-plank"],
            "anti-rotation": ["feet-together-band-pallof-hold"],
            "farmer-carry": ["two-dumbbell-farmer-carry"],
            "suitcase-carry": ["single-dumbbell-suitcase-carry"],
        }
        self.assertEqual(set(self.batch7_families), set(expected_rosters))
        self.assertEqual(
            {
                family_id: [
                    exercise["catalogID"]
                    for exercise in self.batch7_families[family_id]["exercises"]
                ]
                for family_id in expected_rosters
            },
            expected_rosters,
        )
        self.assertEqual(
            sum(
                len(family["exercises"])
                for family in self.batch7_families.values()
            ),
            9,
        )
        self.assertEqual(len(self.real_families), 54)
        self.assertEqual(len(self.foundation.evidence_ids), 149)

    def test_batch7_family_signatures_and_role_contracts_are_exact(
        self,
    ) -> None:
        expected = {
            "spine-flexion": {
                "name": "Spine Flexion",
                "fixed": ("isolation", None, None, ("sagittal",)),
                "basis": ("spine.flexion",),
                "prime": ("spine.flexion",),
                "resisted": (),
                "demands": ("spine", "pelvis"),
                "requirements": (("abs", "primary"), ("obliques", "secondary")),
                "roles": {
                    "primary": ("abs",),
                    "secondary": ("obliques",),
                    "stabilizer": (),
                },
            },
            "spine-extension": {
                "name": "Spine Extension",
                "fixed": ("isolation", None, None, ("sagittal",)),
                "basis": ("spine.extension",),
                "prime": ("spine.extension",),
                "resisted": (),
                "demands": ("spine", "pelvis"),
                "requirements": (("lumbarExtensors", "primary"),),
                "roles": {
                    "primary": ("lumbarExtensors",),
                    "secondary": (),
                    "stabilizer": (),
                },
            },
            "spine-lateral-flexion": {
                "name": "Spine Lateral Flexion",
                "fixed": ("isolation", None, None, ("frontal",)),
                "basis": ("spine.lateralFlexion",),
                "prime": ("spine.lateralFlexion",),
                "resisted": (),
                "demands": ("spine", "pelvis"),
                "requirements": (
                    ("obliques", "primary"),
                    ("quadratusLumborum", "secondary"),
                    ("lumbarExtensors", "stabilizer"),
                    ("abs", "stabilizer"),
                ),
                "roles": {
                    "primary": ("obliques",),
                    "secondary": ("quadratusLumborum",),
                    "stabilizer": ("lumbarExtensors", "abs"),
                },
            },
            "spine-rotation": {
                "name": "Spine Rotation",
                "fixed": ("isolation", None, None, ("transverse",)),
                "basis": ("spine.rotation",),
                "prime": ("spine.rotation",),
                "resisted": (),
                "demands": ("spine", "pelvis"),
                "requirements": (("obliques", "primary"),),
                "roles": {
                    "primary": ("obliques",),
                    "secondary": (),
                    "stabilizer": (),
                },
            },
            "anti-extension": {
                "name": "Anti-Extension",
                "fixed": ("compound", "core", None, ("sagittal",)),
                "basis": ("spine.extension",),
                "prime": (),
                "resisted": ("spine.extension",),
                "demands": (
                    "scapula", "shoulder", "elbow", "spine", "pelvis",
                    "hip", "knee", "ankle", "foot",
                ),
                "requirements": (
                    ("abs", "primary"), ("obliques", "secondary"),
                    ("serratus", "stabilizer"),
                    ("externalRotators", "stabilizer"),
                    ("triceps", "stabilizer"),
                    ("gluteMax", "stabilizer"),
                    ("vasti", "stabilizer"), ("soleus", "stabilizer"),
                ),
                "roles": {
                    "primary": ("abs",),
                    "secondary": ("obliques",),
                    "stabilizer": (
                        "serratus", "externalRotators", "triceps",
                        "gluteMax", "vasti", "soleus",
                    ),
                },
            },
            "anti-lateral-flexion": {
                "name": "Anti-Lateral Flexion",
                "fixed": ("compound", "core", None, ("frontal",)),
                "basis": ("spine.lateralFlexion",),
                "prime": (),
                "resisted": ("spine.lateralFlexion",),
                "demands": (
                    "scapula", "spine", "pelvis", "shoulder", "elbow",
                    "hip", "knee", "ankle", "foot",
                ),
                "requirements": (
                    ("obliques", "primary"), ("quadratusLumborum", "secondary"),
                    ("abs", "stabilizer"),
                    ("deltoidLateral", "stabilizer"),
                    ("gluteMed", "stabilizer"),
                    ("serratus", "stabilizer"),
                    ("triceps", "stabilizer"),
                    ("rectusFemoris", "stabilizer"),
                    ("soleus", "stabilizer"),
                ),
                "roles": {
                    "primary": ("obliques",),
                    "secondary": ("quadratusLumborum",),
                    "stabilizer": (
                        "abs", "deltoidLateral", "gluteMed", "serratus",
                        "triceps", "rectusFemoris", "soleus",
                    ),
                },
            },
            "anti-rotation": {
                "name": "Anti-Rotation",
                "fixed": ("compound", "core", None, ("transverse",)),
                "basis": ("spine.rotation",),
                "prime": (),
                "resisted": ("spine.rotation",),
                "demands": (
                    "scapula", "spine", "pelvis", "shoulder", "elbow",
                    "wrist", "hand", "hip", "knee", "ankle", "foot",
                ),
                "requirements": (
                    ("obliques", "primary"), ("abs", "stabilizer"),
                    ("lumbarExtensors", "stabilizer"),
                    ("deltoidAnterior", "stabilizer"),
                    ("triceps", "stabilizer"),
                    ("fingerFlexors", "stabilizer"),
                    ("extensorCarpiRadialis", "stabilizer"),
                    ("serratus", "stabilizer"),
                    ("gluteMed", "stabilizer"),
                    ("vasti", "stabilizer"), ("soleus", "stabilizer"),
                ),
                "roles": {
                    "primary": ("obliques",),
                    "secondary": (),
                    "stabilizer": (
                        "abs", "lumbarExtensors", "serratus", "deltoidAnterior",
                        "triceps", "fingerFlexors", "extensorCarpiRadialis",
                        "gluteMed", "vasti", "soleus",
                    ),
                },
            },
            "farmer-carry": {
                "name": "Farmer Carry",
                "fixed": ("compound", "carry", None, ("sagittal",)),
                "basis": ("hand.fingerExtension",),
                "prime": (),
                "resisted": ("hand.fingerExtension",),
                "demands": (
                    "scapula", "shoulder", "elbow", "wrist", "hand",
                    "spine", "pelvis", "hip", "knee", "ankle", "foot",
                ),
                "requirements": (
                    ("fingerFlexors", "primary"),
                    ("extensorCarpiRadialis", "stabilizer"),
                    ("trapeziusUpper", "stabilizer"),
                    ("externalRotators", "stabilizer"),
                    ("triceps", "stabilizer"), ("abs", "stabilizer"),
                    ("obliques", "stabilizer"),
                    ("lumbarExtensors", "stabilizer"),
                    ("gluteMed", "stabilizer"),
                    ("vasti", "stabilizer"), ("soleus", "stabilizer"),
                ),
                "roles": {
                    "primary": ("fingerFlexors",),
                    "secondary": (),
                    "stabilizer": (
                        "extensorCarpiRadialis", "trapeziusUpper",
                        "externalRotators", "triceps", "abs", "obliques",
                        "lumbarExtensors", "gluteMed", "vasti", "soleus",
                    ),
                },
            },
            "suitcase-carry": {
                "name": "Suitcase Carry",
                "fixed": ("compound", "carry", None, ("frontal",)),
                "basis": ("spine.lateralFlexion",),
                "prime": (),
                "resisted": (
                    "hand.fingerExtension", "spine.lateralFlexion",
                ),
                "demands": (
                    "scapula", "shoulder", "elbow", "wrist", "hand",
                    "spine", "pelvis", "hip", "knee", "ankle", "foot",
                ),
                "requirements": (
                    ("obliques", "primary"),
                    ("quadratusLumborum", "secondary"),
                    ("lumbarExtensors", "stabilizer"),
                    ("fingerFlexors", "secondary"),
                    ("extensorCarpiRadialis", "stabilizer"),
                    ("trapeziusUpper", "stabilizer"),
                    ("externalRotators", "stabilizer"),
                    ("triceps", "stabilizer"), ("abs", "stabilizer"),
                    ("gluteMed", "stabilizer"),
                    ("vasti", "stabilizer"), ("soleus", "stabilizer"),
                ),
                "roles": {
                    "primary": ("obliques",),
                    "secondary": ("quadratusLumborum", "fingerFlexors"),
                    "stabilizer": (
                        "extensorCarpiRadialis", "trapeziusUpper",
                        "externalRotators", "triceps", "abs", "lumbarExtensors",
                        "gluteMed", "vasti", "soleus",
                    ),
                },
            },
        }
        for family_id, wanted in expected.items():
            family = self.batch7_families[family_id]
            signature = family["movementSignature"]
            fixed = family["fixed"]
            requirements = tuple(
                (requirement["anyOf"][0], requirement["minimumRole"])
                for requirement in family["musclePolicy"]["requirements"]
            )
            roles = {
                role: tuple(muscles)
                for role, muscles in family["musclePolicy"][
                    "allowedByRole"
                ].items()
            }
            with self.subTest(family=family_id):
                self.assertEqual(family["name"], wanted["name"])
                self.assertEqual(
                    (
                        fixed["mechanic"], fixed["pattern"],
                        fixed["direction"], tuple(fixed["planes"]),
                    ),
                    wanted["fixed"],
                )
                self.assertEqual(
                    tuple(signature["planeBasisActions"]), wanted["basis"]
                )
                self.assertEqual(tuple(signature["primeActions"]), wanted["prime"])
                self.assertEqual(
                    tuple(signature.get("resistedActions", [])),
                    wanted["resisted"],
                )
                self.assertEqual(
                    tuple(signature["stabilityDemands"]), wanted["demands"]
                )
                self.assertEqual(requirements, wanted["requirements"])
                self.assertEqual(roles, wanted["roles"])

    def test_batch7_roster_roles_seeds_and_evidence_are_exact(self) -> None:
        expected = {
            "30-degree-curl-up": {
                "family": "spine-flexion",
                "name": "30-Degree Curl-Up",
                "aliases": ["Thirty-Degree Curl-Up", "30-Degree Partial Curl-Up"],
                "domain": ("bodyweight", "bilateral", "dynamicStrength", "reps", "nonComparable"),
                "seed": (0, None, 12, None, 82),
                "roles": {"abs": "primary", "obliques": "secondary"},
                "evidence": ["ha-2020-curl-up-angle"],
            },
            "medx-isolated-lumbar-extension": {
                "family": "spine-extension",
                "name": "MedX Isolated Lumbar Extension",
                "aliases": ["MedX Lumbar Extension", "Restrained Lumbar Extension Machine"],
                "domain": ("machine", "bilateral", "dynamicStrength", "reps", "external"),
                "seed": (20, 10, 10, None, 78),
                "roles": {"lumbarExtensors": "primary"},
                "evidence": ["fisher-2018-isolated-lumbar-extension"],
            },
            "fixed-leg-side-lying-lateral-trunk-lift": {
                "family": "spine-lateral-flexion",
                "name": "Fixed-Leg Side-Lying Lateral Trunk Lift",
                "aliases": [
                    "30-Degree Side-Lying Trunk Lift",
                    "Fixed-Leg Lateral Trunk Lift",
                ],
                "domain": ("bodyweight", "unilateral", "dynamicStrength", "reps", "nonComparable"),
                "seed": (0, None, 10, None, 74),
                "roles": {
                    "obliques": "primary",
                    "quadratusLumborum": "secondary",
                    "lumbarExtensors": "stabilizer",
                    "abs": "stabilizer",
                },
                "evidence": [
                    "konrad-2001-trunk-training",
                    "andersson-1996-quadratus-lumborum-emg",
                    "phillips-2008-quadratus-lumborum-biomechanics",
                ],
            },
            "seated-machine-torso-twist": {
                "family": "spine-rotation",
                "name": "Seated Machine Torso Twist",
                "aliases": ["Machine Axial Trunk Rotation"],
                "domain": ("machine", "unilateral", "dynamicStrength", "reps", "external"),
                "seed": (20, 10, 10, None, 66),
                "roles": {"obliques": "primary"},
                "evidence": ["vinstrup-2015-torso-twist", "stevens-2007-seated-axial-rotation"],
            },
            "plank": {
                "family": "anti-extension",
                "name": "Stable Forearm Plank",
                "aliases": ["Plank", "Front Plank", "Forearm Plank"],
                "domain": ("bodyweight", "bilateral", "isometricStrength", "duration", "nonComparable"),
                "seed": (0, None, 1, 30, 98),
                "roles": {
                    "abs": "primary", "obliques": "secondary",
                    "serratus": "stabilizer", "externalRotators": "stabilizer",
                    "triceps": "stabilizer", "gluteMax": "stabilizer",
                    "vasti": "stabilizer", "soleus": "stabilizer",
                },
                "evidence": ["lehman-2005-stable-prone-bridge", "cinarli-2025-anti-movement-training"],
            },
            "side-plank": {
                "family": "anti-lateral-flexion",
                "name": "Side Plank",
                "aliases": ["Side Bridge", "Side Plank Hold", "Lateral Plank Hold"],
                "domain": ("bodyweight", "unilateral", "isometricStrength", "duration", "nonComparable"),
                "seed": (0, None, 1, 30, 94),
                "roles": {
                    "obliques": "primary", "quadratusLumborum": "secondary",
                    "abs": "stabilizer", "deltoidLateral": "stabilizer",
                    "gluteMed": "stabilizer", "serratus": "stabilizer",
                    "triceps": "stabilizer", "rectusFemoris": "stabilizer",
                    "soleus": "stabilizer",
                },
                "evidence": ["juan-recio-2022-side-bridge-endurance", "cinarli-2025-anti-movement-training"],
            },
            "feet-together-band-pallof-hold": {
                "family": "anti-rotation",
                "name": "Feet-Together Band Pallof Hold",
                "aliases": ["Standing Band Pallof Hold", "Band Anti-Rotation Hold"],
                "domain": ("band", "unilateral", "isometricStrength", "duration", "nonComparable"),
                "seed": (0, None, 1, 15, 84),
                "roles": {
                    "obliques": "primary", "abs": "stabilizer",
                    "lumbarExtensors": "stabilizer", "deltoidAnterior": "stabilizer",
                    "triceps": "stabilizer", "fingerFlexors": "stabilizer",
                    "extensorCarpiRadialis": "stabilizer",
                    "serratus": "stabilizer", "gluteMed": "stabilizer",
                    "vasti": "stabilizer", "soleus": "stabilizer",
                },
                "evidence": ["juan-recio-2025-pallof-postural-challenge", "cinarli-2025-anti-movement-training"],
            },
            "two-dumbbell-farmer-carry": {
                "family": "farmer-carry",
                "name": "Two-Dumbbell Farmer Carry",
                "aliases": [
                    "Bilateral Dumbbell Farmer Carry",
                    "Two-Dumbbell Farmer Walk",
                ],
                "domain": ("dumbbell", "bilateral", "isometricStrength", "duration", "external"),
                "seed": (60, 27.5, 1, 40, 90),
                "roles": {
                    "fingerFlexors": "primary", "extensorCarpiRadialis": "stabilizer",
                    "trapeziusUpper": "stabilizer", "externalRotators": "stabilizer",
                    "triceps": "stabilizer", "abs": "stabilizer",
                    "obliques": "stabilizer", "lumbarExtensors": "stabilizer",
                    "gluteMed": "stabilizer", "vasti": "stabilizer",
                    "soleus": "stabilizer",
                },
                "evidence": [
                    "ellestad-2024-loaded-carry-muscle-activation",
                    "mcgill-2013-one-two-hand-carry",
                    "stastny-2015-farmers-walk-lower-limb",
                ],
            },
            "single-dumbbell-suitcase-carry": {
                "family": "suitcase-carry",
                "name": "Single-Dumbbell Suitcase Carry",
                "aliases": [
                    "Unilateral Dumbbell Suitcase Carry",
                    "Single-Dumbbell Suitcase Walk",
                ],
                "domain": ("dumbbell", "unilateral", "isometricStrength", "duration", "external"),
                "seed": (50, 22.5, 1, 40, 88),
                "roles": {
                    "obliques": "primary", "quadratusLumborum": "secondary",
                    "lumbarExtensors": "stabilizer",
                    "fingerFlexors": "secondary", "extensorCarpiRadialis": "stabilizer",
                    "trapeziusUpper": "stabilizer", "externalRotators": "stabilizer",
                    "triceps": "stabilizer", "abs": "stabilizer",
                    "gluteMed": "stabilizer", "vasti": "stabilizer",
                    "soleus": "stabilizer",
                },
                "evidence": ["ellestad-2024-loaded-carry-muscle-activation", "mcgill-2013-one-two-hand-carry"],
            },
        }
        actual_records = {
            exercise["catalogID"]: (family_id, exercise)
            for family_id, family in self.batch7_families.items()
            for exercise in family["exercises"]
        }
        self.assertEqual(set(actual_records), set(expected))
        for catalog_id, wanted in expected.items():
            family_id, exercise = actual_records[catalog_id]
            with self.subTest(exercise=catalog_id):
                self.assertEqual(family_id, wanted["family"])
                self.assertEqual(exercise["name"], wanted["name"])
                self.assertEqual(exercise["aliases"], wanted["aliases"])
                self.assertEqual(
                    (
                        exercise["equipment"], exercise["laterality"],
                        exercise["modality"], exercise["trackingMode"],
                        exercise["loadMode"],
                    ),
                    wanted["domain"],
                )
                self.assertEqual(
                    (
                        exercise["defaultWeight"],
                        exercise.get("defaultWeightKg"), exercise["reps"],
                        exercise.get("defaultDuration"),
                        exercise["searchPriority"],
                    ),
                    wanted["seed"],
                )
                self.assertEqual(exercise["bodyweightFraction"], 0)
                self.assertEqual(
                    {item["muscle"]: item["role"] for item in exercise["involvement"]},
                    wanted["roles"],
                )
                self.assertEqual(exercise["evidenceRefs"], wanted["evidence"])
                self.assertEqual(exercise["additionalPrimeActions"], [])
                self.assertEqual(exercise["additionalStabilityDemands"], [])

    def test_batch7_variant_axes_and_roster_coverage_are_exact(self) -> None:
        expected_variants = {
            "30-degree-curl-up": {
                "bodyPosition": "supine",
                "spineMotion": "flexesThenReturns",
                "trunkStartElevationDegrees": 0,
                "trunkEndElevationDegrees": 30,
                "pelvisMotion": "positionHeld",
                "hipMotion": "positionHeld",
                "loadInterface": "none",
                "resistanceGeometry": "upperTrunkGravity",
                "fixedPath": False,
                "lowerBodyContribution": "none",
            },
            "medx-isolated-lumbar-extension": {
                "bodyPosition": "seated",
                "spineMotion": "extendsThenReturns",
                "lumbarStartFlexionDegrees": 72,
                "lumbarEndFlexionDegrees": 0,
                "pelvisMotion": "positionHeldByRestraints",
                "hipMotion": "positionHeld",
                "thighRestraint": "present",
                "distalFemurRestraint": "present",
                "footSupport": "tightenedFootboard",
                "posteriorPelvisContact": "rollingPad",
                "loadInterface": "posteriorUpperTorsoPad",
                "machineType": "medxIsolatedLumbarExtension",
                "fixedPath": True,
                "concentricMinimumSeconds": 2,
                "fullExtensionHoldSeconds": 1,
                "eccentricMinimumSeconds": 4,
                "lowerBodyContribution": "none",
            },
            "fixed-leg-side-lying-lateral-trunk-lift": {
                "bodyPosition": "sideLying",
                "spineMotion": "lateralFlexesThenReturns",
                "trunkStartElevationDegrees": 0,
                "trunkEndElevationDegrees": 30,
                "setDirection": "oneDirectionAtATime",
                "trainingDirectionPrescription": "bothDirections",
                "upperFootPosition": "crossedOverLowerLeg",
                "legFixation": "externallyFixed",
                "pelvisMotion": "positionHeldCatalogAdaptation",
                "hipMotion": "positionHeldCatalogAdaptation",
                "loadInterface": "none",
                "resistanceGeometry": "upperTrunkGravity",
                "fixedPath": False,
                "lowerBodyContribution": "none",
            },
            "seated-machine-torso-twist": {
                "bodyPosition": "seated",
                "machineType": "horizontalSeatedTorsoTwist",
                "lowerBodyConstraint": "feetBehindAnkleRollers",
                "pelvisMotion": "positionHeldCatalogAdaptation",
                "hipMotion": "positionHeld",
                "spineMotion": "rotatesOneDirectionThenReturns",
                "setDirection": "oneDirectionAtATime",
                "trainingDirectionPrescription": "bothDirections",
                "handPosition": "handlesAtShoulderHeight",
                "loadInterface": "bilateralShoulderPads",
                "fixedPath": True,
                "lowerBodyContribution": "none",
            },
            "plank": {
                "kineticChain": "closed", "bodyPosition": "proneHorizontal",
                "supportSurface": "floor",
                "upperBodySupport": "bilateralForearmSupport",
                "lowerBodySupport": "feet", "elbowAlignment": "belowShoulders",
                "upperArmPosition": "perpendicularToFloor",
                "bodyAlignment": "neutralStraightLine",
                "spineMotion": "positionHeld", "pelvisMotion": "positionHeld",
                "hipMotion": "positionHeld", "kneeMotion": "positionHeld",
                "holdType": "timedIsometric", "fixedPath": False,
                "lowerBodyContribution": "staticSupportOnly",
            },
            "side-plank": {
                "kineticChain": "closed", "bodyPosition": "sideBridge",
                "supportSurface": "floor", "supportSide": "oneSideAtATime",
                "trainingSidePrescription": "bothSides",
                "upperBodySupport": "oneForearmAndElbow",
                "lowerBodySupport": "feet", "legPosture": "extended",
                "footStagger": "topFootInFront",
                "freeArmPosition": "handOnOppositeShoulder",
                "supportShoulderAngleDegrees": 90,
                "supportElbowFlexionDegrees": 90,
                "bodyAlignment": "shoulderHipFeetStraight",
                "spineMotion": "positionHeld", "pelvisMotion": "positionHeld",
                "hipMotion": "positionHeld", "holdType": "timedIsometric",
                "fixedPath": False,
                "lowerBodyContribution": "staticSupportOnly",
            },
            "feet-together-band-pallof-hold": {
                "kineticChain": "closed", "bodyPosition": "standing",
                "supportSurface": "floor", "stanceConfiguration": "feetTogether",
                "resistanceSide": "oneSideAtATime",
                "trainingSidePrescription": "bothSides",
                "torsoOrientation": "sideOnToAnchor",
                "spineMotion": "positionHeld", "pelvisMotion": "positionHeld",
                "armPosition": "bothPerpendicularToTorso",
                "handHeight": "shoulderHeight", "elbowMotion": "angleHeld",
                "elbowPosture": "extended",
                "handTask": "staticTwoHandHandleHold",
                "resistanceAnchor": "sidePulley",
                "resistanceTrajectory": "horizontalLateral",
                "resistanceSelection": "selfSelectedWithoutVisibleRotation",
                "holdType": "timedIsometric", "fixedPath": False,
                "lowerBodyContribution": "staticSupportOnly",
            },
            "two-dumbbell-farmer-carry": {
                "kineticChain": "closed", "bodyPosition": "standing",
                "upperArmPosition": "atSide", "humeralRotation": "neutral",
                "carryPath": "continuousForwardWalk",
                "loadSymmetry": "balancedBilateral",
                "gripAssistance": "none", "elbowMotion": "angleHeld",
                "elbowPosture": "extended", "forearmMotion": "angleHeld",
                "forearmOrientation": "neutral",
                "handTask": "staticImplementHold",
                "loadAccounting": "perImplement",
                "spineMotion": "nonstandardized",
                "lowerBodyContribution": "walkingPropulsion",
                "fixedPath": False,
            },
            "single-dumbbell-suitcase-carry": {
                "kineticChain": "closed", "bodyPosition": "standing",
                "upperArmPosition": "atSide", "humeralRotation": "neutral",
                "carryPath": "continuousForwardWalk",
                "loadSymmetry": "unilateral", "gripAssistance": "none",
                "elbowMotion": "angleHeld", "elbowPosture": "extended",
                "forearmMotion": "angleHeld", "forearmOrientation": "neutral",
                "handTask": "staticImplementHold",
                "loadAccounting": "perImplement",
                "spineMotion": "nonstandardized",
                "lowerBodyContribution": "walkingPropulsion",
                "fixedPath": False,
            },
        }
        for family_id, family in self.batch7_families.items():
            roster = family["exercises"]
            axes = {axis["id"]: axis for axis in family["variantAxes"]}
            expected_axis_ids = set().union(
                *(set(expected_variants[item["catalogID"]]) for item in roster)
            )
            self.assertEqual(set(axes), expected_axis_ids)
            for exercise in roster:
                with self.subTest(exercise=exercise["catalogID"]):
                    self.assertEqual(
                        exercise["variant"],
                        expected_variants[exercise["catalogID"]],
                    )
            for axis_id, axis in axes.items():
                self.assertTrue(axis["required"])
                observed = {exercise["variant"][axis_id] for exercise in roster}
                with self.subTest(family=family_id, axis=axis_id):
                    if axis["valueType"] == "enum":
                        self.assertEqual(observed, set(axis["allowedValues"]))
                    elif axis["valueType"] == "number":
                        self.assertEqual(
                            observed, {axis["minimum"], axis["maximum"]}
                        )
                    elif axis["valueType"] == "boolean":
                        self.assertEqual(observed, {axis["fixedValue"]})
                    else:
                        self.fail(f"unexpected Batch-7 axis type {axis['valueType']}")

    def test_batch7_one_record_contracts_mutate_every_axis_and_domain(
        self,
    ) -> None:
        mutation_count = 0
        one_record_families = {
            family_id: family
            for family_id, family in self.batch7_families.items()
            if len(family["exercises"]) == 1
        }
        self.assertEqual(
            set(one_record_families),
            {
                "spine-flexion", "spine-extension",
                "spine-lateral-flexion", "spine-rotation",
                "anti-extension", "anti-lateral-flexion", "anti-rotation",
                "farmer-carry", "suitcase-carry",
            },
        )
        for family_id, original in one_record_families.items():
            self.assertEqual(original["exerciseRules"], [])
            for axis in original["variantAxes"]:
                family = copy.deepcopy(original)
                if axis["valueType"] == "enum":
                    family["exercises"][0]["variant"][axis["id"]] = "mutated"
                    expected_error = re.escape(
                        f"variant.{axis['id']} has disallowed value 'mutated'"
                    )
                elif axis["valueType"] == "boolean":
                    family["exercises"][0]["variant"][axis["id"]] = not axis[
                        "fixedValue"
                    ]
                    expected_error = re.escape(
                        f"variant.{axis['id']} must equal fixed value "
                        f"{axis['fixedValue']!r}"
                    )
                elif axis["valueType"] == "number":
                    family["exercises"][0]["variant"][axis["id"]] = (
                        axis["maximum"] + 1
                    )
                    expected_error = re.escape(
                        f"variant.{axis['id']} exceeds {axis['maximum']}"
                    )
                else:
                    self.fail(f"unexpected Batch-7 axis type {axis['valueType']}")
                with self.subTest(family=family_id, axis=axis["id"]):
                    self.assert_batch7_family_fails(family, expected_error)
                mutation_count += 1

            domains = {
                "equipment": ("equipment", catalog.EQUIPMENT),
                "laterality": ("lateralities", catalog.LATERALITIES),
                "modality": ("modalities", catalog.MODALITIES),
                "trackingMode": ("trackingModes", catalog.TRACKING_MODES),
                "loadMode": ("loadModes", catalog.LOAD_MODES),
            }
            for field, (allowed_key, domain) in domains.items():
                family = copy.deepcopy(original)
                value = sorted(domain - set(family["allowed"][allowed_key]))[0]
                family["exercises"][0][field] = value
                with self.subTest(family=family_id, field=field):
                    self.assert_batch7_family_fails(
                        family,
                        re.escape(f"selects disallowed {allowed_key}: {value}"),
                    )
                mutation_count += 1
        self.assertEqual(mutation_count, 184)

    def test_batch7_forbids_every_unreviewed_dynamic_prime_action(
        self,
    ) -> None:
        mutation_count = 0
        for family_id, original in self.batch7_families.items():
            prime_actions = {
                action if isinstance(action, str) else action["action"]
                for action in original["movementSignature"]["primeActions"]
            }
            resisted_actions = {
                action if isinstance(action, str) else action["action"]
                for action in original["movementSignature"].get(
                    "resistedActions", []
                )
            }
            expected_forbidden = self.foundation.action_ids - prime_actions
            self.assertEqual(
                set(
                    original["movementSignature"][
                        "forbiddenPrimeActions"
                    ]
                ),
                expected_forbidden,
            )
            for action in expected_forbidden:
                family = copy.deepcopy(original)
                family["exercises"][0]["additionalPrimeActions"] = [action]
                if action in resisted_actions:
                    expected_error = (
                        "family roster declares actions as both prime and "
                        f"resisted: {re.escape(action)}"
                    )
                else:
                    expected_error = (
                        f"declares forbidden prime action {re.escape(action)}"
                    )
                with self.subTest(family=family_id, action=action):
                    self.assert_batch7_family_fails(
                        family,
                        expected_error,
                    )
                mutation_count += 1
        self.assertEqual(mutation_count, 392)

    def test_batch7_every_required_role_is_removed_and_demoted_directly(
        self,
    ) -> None:
        primary_substitutes = {
            "spine-flexion": "obliques",
            "spine-extension": "quadratusLumborum",
            "spine-lateral-flexion": "abs",
            "spine-rotation": "abs",
            "anti-extension": "obliques",
            "anti-lateral-flexion": "abs",
            "anti-rotation": "abs",
            "farmer-carry": "extensorCarpiRadialis",
            "suitcase-carry": "fingerFlexors",
        }

        def ensure_primary(family_id: str, family: dict, exercise: dict) -> None:
            if any(
                item["role"] == "primary"
                for item in exercise["involvement"]
            ):
                return
            substitute = primary_substitutes[family_id]
            item = next(
                (
                    assignment
                    for assignment in exercise["involvement"]
                    if assignment["muscle"] == substitute
                ),
                None,
            )
            if item is None:
                exercise["involvement"].append(
                    {"muscle": substitute, "role": "primary"}
                )
            else:
                item["role"] = "primary"
            allowed = family["musclePolicy"]["allowedByRole"]["primary"]
            if substitute not in allowed:
                allowed.append(substitute)
            if family_id == "suitcase-carry":
                allowed_groups = family["groupPolicy"]["allowed"]
                if "arms" not in allowed_groups:
                    allowed_groups.append("arms")
                exercise["groupOverride"] = "arms"

        removal_count = 0
        demotion_count = 0
        lower_role = {"primary": "secondary", "secondary": "stabilizer"}
        for family_id, original in self.batch7_families.items():
            for requirement_index, requirement in enumerate(
                original["musclePolicy"]["requirements"]
            ):
                candidate = requirement["anyOf"][0]
                family = copy.deepcopy(original)
                exercise = family["exercises"][0]
                exercise["involvement"] = [
                    item
                    for item in exercise["involvement"]
                    if item["muscle"] != candidate
                ]
                ensure_primary(family_id, family, exercise)
                with self.subTest(
                    family=family_id,
                    requirement=requirement_index,
                    mutation="remove",
                ):
                    self.assert_batch7_family_fails(
                        family,
                        f"fails muscle requirement {requirement_index}",
                    )
                removal_count += 1

                minimum_role = requirement["minimumRole"]
                if minimum_role == "stabilizer":
                    continue
                family = copy.deepcopy(original)
                exercise = family["exercises"][0]
                demoted_role = lower_role[minimum_role]
                allowed = family["musclePolicy"]["allowedByRole"][demoted_role]
                if candidate not in allowed:
                    allowed.append(candidate)
                next(
                    item
                    for item in exercise["involvement"]
                    if item["muscle"] == candidate
                )["role"] = demoted_role
                ensure_primary(family_id, family, exercise)
                with self.subTest(
                    family=family_id,
                    requirement=requirement_index,
                    mutation="demote",
                ):
                    self.assert_batch7_family_fails(
                        family,
                        f"fails muscle requirement {requirement_index}",
                    )
                demotion_count += 1
        self.assertEqual(removal_count, 59)
        self.assertEqual(demotion_count, 15)

    def test_batch7_stability_demands_have_exact_role_agnostic_providers(
        self,
    ) -> None:
        expected = {
            "30-degree-curl-up": {
                "spine": {"abs", "obliques"},
                "pelvis": {"abs", "obliques"},
            },
            "medx-isolated-lumbar-extension": {
                "spine": {"lumbarExtensors"},
                "pelvis": {"lumbarExtensors"},
            },
            "fixed-leg-side-lying-lateral-trunk-lift": {
                "spine": {"abs", "obliques", "quadratusLumborum", "lumbarExtensors"},
                "pelvis": {"abs", "obliques", "quadratusLumborum", "lumbarExtensors"},
            },
            "seated-machine-torso-twist": {
                "spine": {"obliques"},
                "pelvis": {"obliques"},
            },
            "plank": {
                "scapula": {"serratus"},
                "shoulder": {"externalRotators"},
                "elbow": {"triceps"},
                "spine": {"abs", "obliques"},
                "pelvis": {"abs", "obliques", "gluteMax"},
                "hip": {"gluteMax"},
                "knee": {"vasti"},
                "ankle": {"soleus"},
                "foot": {"soleus"},
            },
            "side-plank": {
                "scapula": {"serratus"},
                "spine": {"abs", "obliques", "quadratusLumborum"},
                "pelvis": {"abs", "obliques", "quadratusLumborum", "gluteMed"},
                "shoulder": {"deltoidLateral"},
                "elbow": {"triceps"},
                "hip": {"gluteMed", "rectusFemoris"},
                "knee": {"rectusFemoris"},
                "ankle": {"soleus"},
                "foot": {"soleus"},
            },
            "feet-together-band-pallof-hold": {
                "scapula": {"serratus"},
                "spine": {"abs", "obliques", "lumbarExtensors"},
                "pelvis": {"abs", "obliques", "lumbarExtensors", "gluteMed"},
                "shoulder": {"deltoidAnterior"},
                "elbow": {"triceps"},
                "wrist": {"extensorCarpiRadialis", "fingerFlexors"},
                "hand": {"fingerFlexors"},
                "hip": {"gluteMed"},
                "knee": {"vasti"},
                "ankle": {"soleus"},
                "foot": {"soleus"},
            },
            "two-dumbbell-farmer-carry": {
                "scapula": {"trapeziusUpper"},
                "shoulder": {"externalRotators"},
                "elbow": {"triceps"},
                "wrist": {"extensorCarpiRadialis", "fingerFlexors"},
                "hand": {"fingerFlexors"},
                "spine": {"abs", "obliques", "lumbarExtensors"},
                "pelvis": {"abs", "obliques", "lumbarExtensors", "gluteMed"},
                "hip": {"gluteMed"},
                "knee": {"vasti"},
                "ankle": {"soleus"},
                "foot": {"soleus"},
            },
            "single-dumbbell-suitcase-carry": {
                "scapula": {"trapeziusUpper"},
                "shoulder": {"externalRotators"},
                "elbow": {"triceps"},
                "wrist": {"extensorCarpiRadialis", "fingerFlexors"},
                "hand": {"fingerFlexors"},
                "spine": {"abs", "obliques", "quadratusLumborum", "lumbarExtensors"},
                "pelvis": {"abs", "obliques", "quadratusLumborum", "lumbarExtensors", "gluteMed"},
                "hip": {"gluteMed"},
                "knee": {"vasti"},
                "ankle": {"soleus"},
                "foot": {"soleus"},
            },
        }
        for family in self.batch7_families.values():
            for exercise in family["exercises"]:
                assigned = {
                    item["muscle"] for item in exercise["involvement"]
                }
                demands = [
                    *family["movementSignature"]["stabilityDemands"],
                    *exercise["additionalStabilityDemands"],
                ]
                actual = {
                    region: {
                        muscle_id
                        for muscle_id in assigned
                        if region in self.foundation.profile_by_muscle[
                            muscle_id
                        ]["stabilizes"]
                    }
                    for region in demands
                }
                with self.subTest(exercise=exercise["catalogID"]):
                    self.assertEqual(actual, expected[exercise["catalogID"]])

    def test_batch7_family_resisted_actions_and_opposition_are_exact(
        self,
    ) -> None:
        oppositions = self.foundation.opposing_action_by_action
        self.assertEqual(oppositions["spine.extension"], "spine.flexion")
        self.assertEqual(
            oppositions["spine.lateralFlexion"], "spine.lateralFlexion"
        )
        self.assertEqual(oppositions["spine.rotation"], "spine.rotation")
        self.assertEqual(
            oppositions["hand.fingerExtension"], "hand.fingerFlexion"
        )

        expected_opponents = {
            "plank": {"spine.extension": {"abs", "obliques"}},
            "side-plank": {
                "spine.lateralFlexion": {"obliques", "quadratusLumborum"}
            },
            "feet-together-band-pallof-hold": {
                "spine.rotation": {"obliques"}
            },
            "two-dumbbell-farmer-carry": {
                "hand.fingerExtension": {"fingerFlexors"}
            },
            "single-dumbbell-suitcase-carry": {
                "hand.fingerExtension": {"fingerFlexors"},
                "spine.lateralFlexion": {"obliques", "quadratusLumborum"},
            },
        }
        family_ids = (
            "anti-extension", "anti-lateral-flexion", "anti-rotation",
            "farmer-carry", "suitcase-carry",
        )
        for family_id in family_ids:
            family = self.batch7_families[family_id]
            self.assertEqual(len(family["exercises"]), 1)
            exercise = family["exercises"][0]
            actual = {}
            for action in family["movementSignature"]["resistedActions"]:
                action_id = action if isinstance(action, str) else action["action"]
                actual[action_id] = {
                    item["muscle"]
                    for item in exercise["involvement"]
                    if item["role"] in {"primary", "secondary"}
                    and any(
                        catalog.capability_opposes(
                            capability,
                            (action_id, None),
                            oppositions,
                        )
                        for capability in self.foundation.capabilities_by_muscle[
                            item["muscle"]
                        ]
                    )
                }
            with self.subTest(family=family_id):
                self.assertEqual(
                    actual, expected_opponents[exercise["catalogID"]]
                )

    def test_batch7_movement_definitions_pin_reviewed_boundaries(self) -> None:
        expected = {
            "30-degree-curl-up": (
                "Lie supine in a stable lower-body position with the pelvis held "
                "still. Begin with the trunk resting on the floor, then flex the "
                "spine to curl the head, shoulders, and upper trunk through the "
                "reviewed 30-degree range without using hip motion. Return to the "
                "supine start under control without turning the repetition into a "
                "full sit-up."
            ),
            "medx-isolated-lumbar-extension": (
                "Sit in the MedX lumbar-extension machine with the thighs perpendicular to the seat. "
                "Tighten the thigh restraint, secure the distal-femur restraint just above the patella, "
                "tighten the footboard, and maintain contact with the rolling upper-pelvis restraint. "
                "Apply extension force only to the posterior upper-torso resistance pad. From the machine's "
                "72-degree full-lumbar-flexion reference, extend for at least two seconds to its 0-degree "
                "full-extension reference, hold one second, then return for at least four seconds without "
                "lifting or rotating the pelvis or driving with the hips."
            ),
            "fixed-leg-side-lying-lateral-trunk-lift": (
                "Lie on one side with the trunk resting on the floor, cross the upper foot over the lower leg, "
                "and have the crossed upper foot fixed securely without assuming a particular device. As a "
                "catalog coaching standard beyond the measured source, hold the pelvis and hip still rather "
                "than driving the lift from the hip. Laterally flex the spine to lift the upper body to the "
                "30-degree trunk-elevation endpoint; this is not a segmental lumbar-angle prescription. "
                "Return to the side-lying start under control, then complete the same separately logged work "
                "in the opposite lateral-flexion direction."
            ),
            "seated-machine-torso-twist": (
                "Sit in a horizontal torso-twist machine with the feet behind the "
                "ankle rollers, the shoulder pads in contact, "
                "and both hands holding the separate handles at shoulder height. "
                "Hold the pelvis against the seat and keep the hips and legs still. "
                "For one logged direction, begin rotated left, drive the shoulder "
                "pads from left to right in a controlled motion, stop at the largest "
                "comfortable torso-rotation endpoint, and return to the left-rotated "
                "start under control. Then reset the machine and perform the same "
                "prescribed work from right to left as a separately logged direction. "
                "The right-to-left direction is a mirrored training adaptation; do "
                "not alternate directions within a repetition."
            ),
            "plank": (
                "Set both forearms on a stable floor with the elbows below the "
                "shoulders and the upper arms perpendicular to the floor, then "
                "support the lower body on both feet. Hold the spine, pelvis, hips, "
                "and knees in one neutral straight line for the prescribed duration "
                "while resisting the tendency of the lower back to sag; do not turn "
                "the hold into a crunch, hip lift, reach, or limb movement."
            ),
            "side-plank": (
                "Lie on one side and support the body on that forearm and elbow with "
                "the shoulder and elbow at the reviewed 90-degree angles. Extend "
                "both legs, place the top foot in front of the lower foot, place the "
                "free hand on the opposite shoulder, and lift into a straight line "
                "from shoulder through hip to feet. Hold the spine, pelvis, and hips "
                "still for the prescribed duration, then repeat on the other side "
                "without adding a hip dip, row, or leg movement."
            ),
            "feet-together-band-pallof-hold": (
                "Attach a band to a side pulley so its line of pull is horizontal, "
                "stand side-on with the feet together on a stable floor, and hold "
                "the handle in both hands at shoulder height. Extend both elbows so "
                "the arms are perpendicular to the torso, choose a tension you can "
                "control, and hold for the prescribed duration without letting the "
                "spine or pelvis rotate. Repeat with the anchor on the other side; "
                "do not turn the hold into a repeated press."
            ),
            "two-dumbbell-farmer-carry": (
                "Log the weight of one dumbbell, not the combined pair. Hold one "
                "equal-weight dumbbell in each hand with the upper arms at the "
                "sides, neutral humeral and forearm rotation, palms facing the "
                "thighs, no straps or hooks, and the elbows held extended beside "
                "the torso. Walk continuously forward on a level surface for the "
                "prescribed duration while keeping the shoulders controlled and "
                "the trunk upright without turning, marching in place, or "
                "converting the carry into another exercise."
            ),
            "single-dumbbell-suitcase-carry": (
                "Log the weight of the single dumbbell. Hold it at one side with "
                "the upper arm at the side, neutral humeral and forearm rotation, "
                "the palm facing the thigh, no straps or hooks, and the elbow held "
                "extended beside the torso. Walk continuously forward on a level "
                "surface for the prescribed duration while resisting the dumbbell's "
                "side-bending tendency without forcing the spine motionless. Log "
                "the other side as well; do not turn, march in place, walk backward, "
                "or lean deliberately to create repetitions."
            ),
        }
        actual = {
            exercise["catalogID"]: exercise["movementDefinition"]
            for family in self.batch7_families.values()
            for exercise in family["exercises"]
        }
        self.assertEqual(actual, expected)

    def test_batch7_evidence_scopes_preserve_material_limitations(self) -> None:
        source_by_id = {
            source["id"]: source for source in self.foundation.evidence["sources"]
        }
        expected = {
            "ha-2020-curl-up-angle": (
                "directly anchoring the active 30-degree dynamic range",
                "not establish a comparable external load, bodyweight fraction",
                "categorical numeric role split",
            ),
            "fisher-2018-isolated-lumbar-extension": (
                "MedX lumbar-extension machine",
                "at least two seconds of extension",
                "did not record EMG",
            ),
            "konrad-2001-trunk-training": (
                "upper foot crossed over the lower leg",
                "did not measure quadratus lumborum, internal oblique, or multifidus",
                "or support an unfixed-leg side bend",
            ),
            "andersson-1996-quadratus-lumborum-emg": (
                "ultrasound-guided fine-wire EMG",
                "ipsilateral trunk flexion in side-lying",
                "does not directly measure the active 30-degree repetitions",
            ),
            "phillips-2008-quadratus-lumborum-biomechanics": (
                "possible lumbar extensor and lateral-bending moments",
                "no greater than ten percent",
                "not an exercise role",
            ),
            "vinstrup-2015-torso-twist": (
                "hands on shoulder-height handles",
                "photographed shoulder-pad lever interface",
                "pelvic kinematics were neither stated as stationary nor measured",
            ),
            "stevens-2007-seated-axial-rotation": (
                "supports dynamic internal-and-external-oblique participation",
                "not equivalence to the active Technogym topology",
                "zero pelvic motion",
            ),
            "lehman-2005-stable-prone-bridge": (
                "feet and forearms contacting the floor",
                "not a universal endurance prescription",
                "shoulder or hip role ranking",
            ),
            "juan-recio-2022-side-bridge-endurance": (
                "preferred-side floor side bridge",
                "recorded on the preferred support side",
                "or directly measure quadratus lumborum",
            ),
            "juan-recio-2025-pallof-postural-challenge": (
                "feet-together standing-on-floor topology",
                "not muscle roles, self-selected load equivalence",
                "sacral smartphone acceleration",
            ),
            "cinarli-2025-anti-movement-training": (
                "stable prone plank, lateral plank, and standing Pallof hold",
                "not a per-exercise causal adaptation",
                "muscle-role hierarchy",
            ),
            "ellestad-2024-loaded-carry-muscle-activation": (
                "paired-versus-single dumbbell topology",
                "not side-specific product highlighting",
                "catalog duration and weight seeds",
            ),
            "mcgill-2013-one-two-hand-carry": (
                "greater asymmetric trunk demand",
                "not support dumbbell-specific upper-limb roles",
                "claim that gait-related spinal motion is absent",
            ),
            "stastny-2015-farmers-walk-lower-limb": (
                "8-meter dumbbell farmer-walk trials",
                "categorical gluteus-medius and knee-control envelope",
                "does not establish suitcase roles",
            ),
        }
        for source_id, phrases in expected.items():
            self.assertIn(source_id, source_by_id)
            for phrase in phrases:
                with self.subTest(source=source_id, phrase=phrase):
                    self.assertIn(phrase, source_by_id[source_id]["scope"])

        proposals = {
            "dynamic": (
                catalog.SPEC_ROOT
                / "proposals"
                / "batch-7-dynamic-spine.md"
            ).read_text(encoding="utf-8"),
            "anti": (
                catalog.SPEC_ROOT
                / "proposals"
                / "batch-7-anti-motion.md"
            ).read_text(encoding="utf-8"),
            "carry": (
                catalog.SPEC_ROOT
                / "proposals"
                / "batch-7-loaded-carry.md"
            ).read_text(encoding="utf-8"),
        }
        normalized = {
            key: " ".join(value.split()) for key, value in proposals.items()
        }
        self.assertIn(
            "0-to-30-degree trunk-elevation range, explicitly not a segmental lumbar-angle claim",
            normalized["dynamic"],
        )
        self.assertIn(
            "`lumbarExtensors` is an explicitly unvisualized erector-spinae/multifidus region",
            normalized["dynamic"],
        )
        self.assertIn(
            "posterior serratus is excluded from trainable ownership",
            normalized["dynamic"],
        )
        self.assertIn(
            "Holding the pelvis and hip still and prescribing equal work in the opposite direction are disclosed product coaching adaptations",
            normalized["dynamic"],
        )
        self.assertIn(
            "DOI first, otherwise PMCID, otherwise PMID",
            normalized["dynamic"],
        )
        self.assertIn(
            "It measured sacral acceleration, not muscle EMG",
            normalized["anti"],
        )
        self.assertIn(
            "not an erector-spinae proxy",
            normalized["anti"],
        )
        self.assertIn(
            "does not resolve left/right credit inside bilateral mesh aggregates",
            normalized["anti"],
        )
        self.assertIn(
            "Product duration and seed are catalog defaults",
            normalized["carry"],
        )
        self.assertIn(
            "`loadAccounting: perImplement` makes the product semantics explicit",
            normalized["carry"],
        )

    def test_batch7_spine_closure_and_count_arithmetic_are_explicit(
        self,
    ) -> None:
        active_ids = {family["id"] for family in self.real_families}
        closed = {"spine-extension", "spine-lateral-flexion"}
        self.assertTrue(closed.issubset(active_ids))
        self.assertTrue(
            {
                "fisher-2018-isolated-lumbar-extension",
                "konrad-2001-trunk-training",
                "andersson-1996-quadratus-lumborum-emg",
                "phillips-2008-quadratus-lumborum-biomechanics",
            }.issubset(self.foundation.evidence_ids)
        )
        self.assertFalse(
            (catalog.FAMILIES_ROOT / "loaded-carry.json").exists()
        )

        roadmap = (catalog.SPEC_ROOT / "family-roadmap.md").read_text(
            encoding="utf-8"
        )
        families_readme = (
            catalog.FAMILIES_ROOT / "README.md"
        ).read_text(encoding="utf-8")
        normalized_families_readme = " ".join(families_readme.split())
        foundation_readme = (
            catalog.SPEC_ROOT / "README.md"
        ).read_text(encoding="utf-8")
        normalized_foundation_readme = " ".join(foundation_readme.split())
        proposal = (
            catalog.SPEC_ROOT
            / "proposals"
            / "batch-7-dynamic-spine.md"
        ).read_text(encoding="utf-8")
        normalized_proposal = " ".join(proposal.split())

        self.assertIn(
            "54 reviewed families are active, containing 132 exercises",
            roadmap,
        )
        self.assertIn(
            "Batch 7 now contains nine active families",
            roadmap,
        )
        self.assertIn(
            "Four work items remain unresolved, all family or branch items",
            roadmap,
        )
        self.assertIn("| `farmer-carry` | 1 |", roadmap)
        self.assertIn("| `suitcase-carry` | 1 |", roadmap)
        self.assertIn("| **Total** | **132** |", roadmap)
        self.assertIn("Fifty-four reviewed family files", families_readme)
        self.assertIn("Batch 7 adds nine exercises", families_readme)
        self.assertIn(
            "`spine-extension` and `spine-lateral-flexion` are active", normalized_families_readme
        )
        self.assertIn(
            "posterior serratus is excluded from trainable ownership",
            normalized_families_readme,
        )
        self.assertIn("## Resisted-action semantics", foundation_readme)
        self.assertIn(
            "an externally imposed joint-action tendency",
            normalized_foundation_readme,
        )
        self.assertIn(
            "all four dynamic-spine candidates are active",
            normalized_proposal,
        )
        self.assertIn(
            "DOI first, otherwise PMCID, otherwise PMID",
            normalized_proposal,
        )

    def test_scapular_closure_activates_exactly_three_families_and_four_records(
        self,
    ) -> None:
        expected_rosters = {
            "scapular-retraction": ["standing-band-scapular-retraction"],
            "scapular-depression": ["standing-band-scapular-depression"],
            "scapular-elevation": [
                "single-arm-dumbbell-shrug",
                "bilateral-30-degree-stabilization-shrug",
            ],
            "upright-row": ["standing-low-cable-upright-row"],
        }
        self.assertEqual(
            set(self.scapular_closure_families),
            set(expected_rosters),
        )
        self.assertEqual(
            {
                family_id: [
                    exercise["catalogID"]
                    for exercise in self.scapular_closure_families[
                        family_id
                    ]["exercises"]
                ]
                for family_id in expected_rosters
            },
            expected_rosters,
        )
        self.assertEqual(
            sum(
                len(family["exercises"])
                for family in self.scapular_closure_families.values()
            ),
            5,
        )
        preexisting = {"single-arm-dumbbell-shrug"}
        self.assertEqual(
            {
                exercise["catalogID"]
                for family in self.scapular_closure_families.values()
                for exercise in family["exercises"]
            }
            - preexisting,
            {
                "standing-band-scapular-retraction",
                "standing-band-scapular-depression",
                "bilateral-30-degree-stabilization-shrug",
                "standing-low-cable-upright-row",
            },
        )
        self.assertFalse(
            (
                catalog.FAMILIES_ROOT / "scapular-upward-rotation.json"
            ).exists()
        )
        self.assertFalse(
            (
                catalog.FAMILIES_ROOT / "scapular-downward-rotation.json"
            ).exists()
        )

    def test_scapular_closure_new_family_contracts_are_exact(self) -> None:
        expected = {
            "scapular-retraction": {
                "fixed": ("isolation", None, None, ("transverse",)),
                "allowed": (
                    ("band",), ("dynamicStrength",), ("reps",),
                    ("nonComparable",), ("unilateral",),
                ),
                "basis": ("scapula.retraction",),
                "prime": ("scapula.retraction",),
                "demands": (
                    "scapula", "shoulder", "elbow", "wrist", "hand",
                    "spine", "pelvis",
                ),
                "requirements": (
                    (("trapeziusMiddle",), "primary"),
                    (("trapeziusLower",), "secondary"),
                    (("trapeziusUpper",), "stabilizer"),
                    (("serratus",), "stabilizer"),
                    (("externalRotators",), "stabilizer"),
                    (("triceps",), "stabilizer"),
                    (("extensorCarpiRadialis",), "stabilizer"),
                    (("fingerFlexors",), "stabilizer"),
                    (("obliques",), "stabilizer"),
                ),
                "roles": {
                    "primary": ("trapeziusMiddle",),
                    "secondary": ("trapeziusLower",),
                    "stabilizer": (
                        "trapeziusUpper", "serratus", "externalRotators",
                        "triceps", "extensorCarpiRadialis", "fingerFlexors",
                        "abs", "obliques", "lumbarExtensors",
                    ),
                },
                "familyEvidence": (
                    "mccabe-2007-below-90-scapular-exercises",
                    "cools-2004-isokinetic-scapular-rotators",
                ),
                "exerciseEvidence": (
                    "mccabe-2007-below-90-scapular-exercises",
                ),
            },
            "scapular-depression": {
                "fixed": ("isolation", None, None, ("frontal",)),
                "allowed": (
                    ("band",), ("dynamicStrength",), ("reps",),
                    ("nonComparable",), ("unilateral",),
                ),
                "basis": ("scapula.depression",),
                "prime": ("scapula.depression",),
                "demands": (
                    "scapula", "shoulder", "elbow", "wrist", "hand",
                    "spine", "pelvis",
                ),
                "requirements": (
                    (("trapeziusLower",), "primary"),
                    (("serratus",), "stabilizer"),
                    (("externalRotators",), "stabilizer"),
                    (("triceps",), "stabilizer"),
                    (("extensorCarpiRadialis",), "stabilizer"),
                    (("fingerFlexors",), "stabilizer"),
                    (("obliques",), "stabilizer"),
                ),
                "roles": {
                    "primary": ("trapeziusLower",),
                    "secondary": (),
                    "stabilizer": (
                        "serratus", "externalRotators", "triceps",
                        "extensorCarpiRadialis", "fingerFlexors", "abs",
                        "obliques", "lumbarExtensors",
                    ),
                },
                "familyEvidence": (
                    "mccabe-2007-below-90-scapular-exercises",
                ),
                "exerciseEvidence": (
                    "mccabe-2007-below-90-scapular-exercises",
                ),
            },
            "upright-row": {
                "fixed": (
                    "compound", "pull", "vertical",
                    ("sagittal", "frontal"),
                ),
                "allowed": (
                    ("cable",), ("dynamicStrength",), ("reps",),
                    ("external",), ("bilateral",),
                ),
                "basis": ("shoulder.flexion", "shoulder.abduction"),
                "prime": (
                    "shoulder.flexion", "shoulder.abduction",
                    "scapula.upwardRotation", "scapula.posteriorTilt",
                    "elbow.flexion",
                ),
                "demands": (
                    "shoulder", "scapula", "elbow", "forearm", "wrist",
                    "hand", "spine", "pelvis",
                ),
                "requirements": (
                    (("deltoidLateral",), "primary"),
                    (("deltoidAnterior",), "secondary"),
                    (("supraspinatus",), "secondary"),
                    (("bicepsBrachii",), "secondary"),
                    (("brachialis",), "secondary"),
                    (("brachioradialis",), "secondary"),
                    (("serratus",), "secondary"),
                    (("trapeziusUpper",), "secondary"),
                    (("trapeziusLower",), "secondary"),
                    (("deltoidPosterior",), "stabilizer"),
                    (("trapeziusMiddle",), "stabilizer"),
                    (("externalRotators",), "stabilizer"),
                    (("subscapularis",), "stabilizer"),
                    (("fingerFlexors",), "stabilizer"),
                    (("extensorCarpiRadialis",), "stabilizer"),
                    (("abs",), "stabilizer"),
                    (("obliques",), "stabilizer"),
                    (("lumbarExtensors",), "stabilizer"),
                ),
                "roles": {
                    "primary": ("deltoidLateral",),
                    "secondary": (
                        "deltoidAnterior", "supraspinatus", "bicepsBrachii",
                        "brachialis", "brachioradialis", "serratus",
                        "trapeziusUpper", "trapeziusLower",
                    ),
                    "stabilizer": (
                        "deltoidPosterior", "trapeziusMiddle",
                        "externalRotators", "subscapularis", "fingerFlexors",
                        "extensorCarpiRadialis", "abs", "obliques",
                        "lumbarExtensors",
                    ),
                },
                "familyEvidence": (
                    "lorenzetti-2017-pulling-exercise-kinematics",
                    "mcallister-2013-upright-row-grip-width",
                    "eldridge-2024-loaded-scapular-elevation",
                    "ludewig-2009-multiplanar-humeral-elevation",
                    "seth-2019-shoulder-work",
                ),
                "exerciseEvidence": (
                    "lorenzetti-2017-pulling-exercise-kinematics",
                ),
            },
        }
        new_families = {
            family_id: self.scapular_closure_families[family_id]
            for family_id in expected
        }
        self.assertEqual(set(new_families), set(expected))
        for family_id, family in new_families.items():
            wanted = expected[family_id]
            fixed = family["fixed"]
            actual_fixed = (
                fixed["mechanic"], fixed["pattern"], fixed["direction"],
                tuple(fixed["planes"]),
            )
            allowed = family["allowed"]
            actual_allowed = (
                tuple(allowed["equipment"]), tuple(allowed["modalities"]),
                tuple(allowed["trackingModes"]),
                tuple(allowed["loadModes"]),
                tuple(allowed["lateralities"]),
            )
            signature = family["movementSignature"]
            policy = family["musclePolicy"]
            actual_requirements = tuple(
                (tuple(item["anyOf"]), item["minimumRole"])
                for item in policy["requirements"]
            )
            actual_roles = {
                role: tuple(muscles)
                for role, muscles in policy["allowedByRole"].items()
            }
            exercise = family["exercises"][0]
            with self.subTest(family=family_id):
                self.assertEqual(actual_fixed, wanted["fixed"])
                self.assertEqual(actual_allowed, wanted["allowed"])
                self.assertEqual(
                    tuple(signature["planeBasisActions"]), wanted["basis"]
                )
                self.assertEqual(
                    tuple(signature["primeActions"]), wanted["prime"]
                )
                self.assertEqual(
                    tuple(signature["stabilityDemands"]), wanted["demands"]
                )
                self.assertEqual(actual_requirements, wanted["requirements"])
                self.assertEqual(actual_roles, wanted["roles"])
                self.assertEqual(
                    tuple(family["evidenceRefs"]), wanted["familyEvidence"]
                )
                self.assertEqual(
                    tuple(exercise["evidenceRefs"]),
                    wanted["exerciseEvidence"],
                )
                self.assertEqual(signature.get("resistedActions", []), [])
                self.assertEqual(exercise["additionalPrimeActions"], [])
                self.assertEqual(exercise["additionalStabilityDemands"], [])
                self.assertEqual(family["exerciseRules"], [])

    def test_scapular_closure_new_family_variants_are_exact(self) -> None:
        expected = {
            "standing-band-scapular-retraction": {
                "kineticChain": "open", "bodyPosition": "standing",
                "torsoSupport": "none", "contralateralSupport": "none",
                "scapularTranslation": "free",
                "humerothoracicElevationDegrees": 80,
                "elevationPlane": "sagittal", "humeralRotation": "neutral",
                "elbowMotion": "angleHeld", "elbowPosture": "extended",
                "forearmMotion": "angleHeld",
                "forearmOrientation": "neutral",
                "handTask": "staticImplementHold",
                "bandAnchor": "anteriorBelowHand",
                "bandStartTension": "justTaut",
                "resistancePrescription": (
                    "subjectAdjustedModerateFiveRepEffort"
                ),
                "resistanceGeometry": (
                    "anteriorElasticResistanceOpposesRetraction"
                ),
                "concentricSeconds": 2, "eccentricSeconds": 2,
                "interRepRestSeconds": 5, "fixedPath": False,
                "lowerBodyContribution": "none", "neckContribution": "none",
            },
            "standing-band-scapular-depression": {
                "kineticChain": "open", "bodyPosition": "standing",
                "torsoSupport": "none", "contralateralSupport": "none",
                "scapularTranslation": "free", "upperArmPosition": "atSide",
                "humeralRotation": "neutral", "elbowMotion": "angleHeld",
                "elbowPosture": "extended", "forearmMotion": "angleHeld",
                "forearmOrientation": "neutral",
                "handTask": "staticImplementHold", "bandAnchor": "overhead",
                "bandStartTension": "justTaut",
                "resistancePrescription": (
                    "subjectAdjustedModerateFiveRepEffort"
                ),
                "resistanceGeometry": (
                    "overheadElasticResistanceOpposesDepression"
                ),
                "concentricSeconds": 2, "eccentricSeconds": 2,
                "interRepRestSeconds": 5, "fixedPath": False,
                "lowerBodyContribution": "none", "neckContribution": "none",
            },
            "standing-low-cable-upright-row": {
                "kineticChain": "open", "bodyPosition": "standing",
                "torsoSupport": "none", "scapularTranslation": "free",
                "elevationPath": "mixedFlexionAbductionCatalogAdaptation",
                "endpointCriterion": "elbowsAtShoulderHeight",
                "elbowMotion": "flexes",
                "elbowHandRelationship": "elbowsSlightlyAboveHands",
                "humeralRotation": "nonstandardized",
                "gripOrientation": "pronated",
                "gripWidth": "sourceShownNotQuantified",
                "handleType": "straightBar",
                "handTask": "staticImplementHold",
                "resistanceGeometry": "lowCableVerticalPull",
                "fixedPath": False, "spineMotion": "nonstandardized",
                "kneeSetup": "slightlyFlexed",
                "lowerBodyContribution": "none",
            },
        }
        for family_id in {
            "scapular-retraction", "scapular-depression", "upright-row"
        }:
            family = self.scapular_closure_families[family_id]
            self.assertEqual(len(family["exercises"]), 1)
            exercise = family["exercises"][0]
            axes = {axis["id"]: axis for axis in family["variantAxes"]}
            wanted = expected[exercise["catalogID"]]
            with self.subTest(family=family_id):
                self.assertEqual(exercise["variant"], wanted)
                self.assertEqual(set(axes), set(wanted))
            for axis_id, axis in axes.items():
                self.assertTrue(axis["required"])
                value = wanted[axis_id]
                with self.subTest(family=family_id, axis=axis_id):
                    if axis["valueType"] == "enum":
                        self.assertEqual(axis["allowedValues"], [value])
                    elif axis["valueType"] == "number":
                        self.assertEqual(
                            (axis["minimum"], axis["maximum"]),
                            (value, value),
                        )
                    elif axis["valueType"] == "boolean":
                        self.assertEqual(axis["fixedValue"], value)
                    else:
                        self.fail(
                            f"unexpected scapular-closure axis type "
                            f"{axis['valueType']}"
                        )

    def test_scapular_closure_mutates_every_new_axis_and_domain_directly(
        self,
    ) -> None:
        mutation_count = 0
        family_ids = {
            "scapular-retraction", "scapular-depression", "upright-row"
        }
        domains = {
            "equipment": ("equipment", catalog.EQUIPMENT),
            "laterality": ("lateralities", catalog.LATERALITIES),
            "modality": ("modalities", catalog.MODALITIES),
            "trackingMode": ("trackingModes", catalog.TRACKING_MODES),
            "loadMode": ("loadModes", catalog.LOAD_MODES),
        }
        for family_id in family_ids:
            original = self.scapular_closure_families[family_id]
            self.assertEqual(len(original["exercises"]), 1)
            for axis in original["variantAxes"]:
                family = copy.deepcopy(original)
                axis_id = axis["id"]
                if axis["valueType"] == "enum":
                    family["exercises"][0]["variant"][axis_id] = "mutated"
                    expected_error = re.escape(
                        f"variant.{axis_id} has disallowed value 'mutated'"
                    )
                elif axis["valueType"] == "boolean":
                    family["exercises"][0]["variant"][axis_id] = not axis[
                        "fixedValue"
                    ]
                    expected_error = re.escape(
                        f"variant.{axis_id} must equal fixed value "
                        f"{axis['fixedValue']!r}"
                    )
                elif axis["valueType"] == "number":
                    family["exercises"][0]["variant"][axis_id] = (
                        axis["maximum"] + 1
                    )
                    expected_error = re.escape(
                        f"variant.{axis_id} exceeds {axis['maximum']}"
                    )
                else:
                    self.fail(
                        f"unexpected scapular-closure axis type "
                        f"{axis['valueType']}"
                    )
                with self.subTest(family=family_id, axis=axis_id):
                    self.assert_scapular_closure_family_fails(
                        family,
                        expected_error,
                    )
                mutation_count += 1

            for field, (allowed_key, domain) in domains.items():
                family = copy.deepcopy(original)
                value = sorted(
                    domain - set(family["allowed"][allowed_key])
                )[0]
                family["exercises"][0][field] = value
                with self.subTest(family=family_id, field=field):
                    self.assert_scapular_closure_family_fails(
                        family,
                        re.escape(
                            f"selects disallowed {allowed_key}: {value}"
                        ),
                    )
                mutation_count += 1
        self.assertEqual(mutation_count, 78)

    def test_scapular_closure_forbids_every_unreviewed_prime_action(
        self,
    ) -> None:
        mutation_count = 0
        for family_id in {
            "scapular-retraction", "scapular-depression", "upright-row"
        }:
            original = self.scapular_closure_families[family_id]
            signature = original["movementSignature"]
            prime_actions = {
                item if isinstance(item, str) else item["action"]
                for item in signature["primeActions"]
            }
            expected_forbidden = self.foundation.action_ids - prime_actions
            self.assertEqual(
                set(signature["forbiddenPrimeActions"]),
                expected_forbidden,
            )
            self.assertEqual(
                prime_actions | set(signature["forbiddenPrimeActions"]),
                self.foundation.action_ids,
            )
            for action in signature["forbiddenPrimeActions"]:
                family = copy.deepcopy(original)
                family["exercises"][0]["additionalPrimeActions"] = [action]
                with self.subTest(family=family_id, action=action):
                    self.assert_scapular_closure_family_fails(
                        family,
                        f"declares forbidden prime action {re.escape(action)}",
                    )
                mutation_count += 1
        self.assertEqual(mutation_count, 125)

    def test_scapular_closure_required_roles_are_removed_and_demoted_directly(
        self,
    ) -> None:
        removal_count = 0
        demotion_count = 0
        lower_role = {"primary": "secondary", "secondary": "stabilizer"}
        for family_id in {
            "scapular-retraction", "scapular-depression", "upright-row"
        }:
            original = self.scapular_closure_families[family_id]
            for requirement_index, requirement in enumerate(
                original["musclePolicy"]["requirements"]
            ):
                candidate = requirement["anyOf"][0]
                family = copy.deepcopy(original)
                family["exercises"][0]["involvement"] = [
                    item
                    for item in family["exercises"][0]["involvement"]
                    if item["muscle"] != candidate
                ]
                with self.subTest(
                    family=family_id,
                    requirement=requirement_index,
                    mutation="remove",
                ):
                    self.assert_scapular_closure_family_fails(
                        family,
                        (
                            f"fails muscle requirement {requirement_index}"
                            "|requires at least one primary muscle"
                        ),
                    )
                removal_count += 1

                minimum_role = requirement["minimumRole"]
                if minimum_role == "stabilizer":
                    continue
                family = copy.deepcopy(original)
                demoted_role = lower_role[minimum_role]
                allowed = family["musclePolicy"]["allowedByRole"][
                    demoted_role
                ]
                if candidate not in allowed:
                    allowed.append(candidate)
                next(
                    item
                    for item in family["exercises"][0]["involvement"]
                    if item["muscle"] == candidate
                )["role"] = demoted_role
                with self.subTest(
                    family=family_id,
                    requirement=requirement_index,
                    mutation="demote",
                ):
                    self.assert_scapular_closure_family_fails(
                        family,
                        (
                            f"fails muscle requirement {requirement_index}"
                            "|requires at least one primary muscle"
                        ),
                    )
                demotion_count += 1
        self.assertEqual(removal_count, 34)
        self.assertEqual(demotion_count, 12)

    def test_scapular_closure_allowed_roles_are_removed_directly(self) -> None:
        mutation_count = 0
        for family_id in {
            "scapular-retraction", "scapular-depression", "upright-row"
        }:
            original = self.scapular_closure_families[family_id]
            assignments = {
                item["muscle"]: item["role"]
                for item in original["exercises"][0]["involvement"]
            }
            allowed = original["musclePolicy"]["allowedByRole"]
            self.assertEqual(
                set(assignments),
                {muscle for muscles in allowed.values() for muscle in muscles},
            )
            for role, muscles in allowed.items():
                for muscle in muscles:
                    family = copy.deepcopy(original)
                    family["musclePolicy"]["allowedByRole"][role].remove(
                        muscle
                    )
                    with self.subTest(
                        family=family_id,
                        muscle=muscle,
                        role=role,
                    ):
                        self.assert_scapular_closure_family_fails(
                            family,
                            (
                                "cannot be satisfied by the family's allowed "
                                "role matrix|does not allow "
                                f"{re.escape(muscle)} as {role}"
                            ),
                        )
                    mutation_count += 1
        self.assertEqual(mutation_count, 38)

    def test_scapular_closure_stability_providers_are_exact_and_direct(
        self,
    ) -> None:
        expected = {
            "standing-band-scapular-retraction": {
                "scapula": {
                    "trapeziusMiddle", "trapeziusLower", "trapeziusUpper",
                    "serratus",
                },
                "shoulder": {"externalRotators"},
                "elbow": {"triceps"},
                "wrist": {"extensorCarpiRadialis", "fingerFlexors"},
                "hand": {"fingerFlexors"},
                "spine": {"abs", "obliques", "lumbarExtensors"},
                "pelvis": {"abs", "obliques", "lumbarExtensors"},
            },
            "standing-band-scapular-depression": {
                "scapula": {"trapeziusLower", "serratus"},
                "shoulder": {"externalRotators"},
                "elbow": {"triceps"},
                "wrist": {"extensorCarpiRadialis", "fingerFlexors"},
                "hand": {"fingerFlexors"},
                "spine": {"abs", "obliques", "lumbarExtensors"},
                "pelvis": {"abs", "obliques", "lumbarExtensors"},
            },
            "standing-low-cable-upright-row": {
                "shoulder": {
                    "deltoidLateral", "deltoidAnterior", "supraspinatus",
                    "bicepsBrachii", "deltoidPosterior", "externalRotators",
                    "subscapularis",
                },
                "scapula": {
                    "serratus", "trapeziusUpper", "trapeziusLower",
                    "trapeziusMiddle",
                },
                "elbow": {
                    "bicepsBrachii", "brachialis", "brachioradialis",
                },
                "forearm": {"bicepsBrachii", "brachioradialis"},
                "wrist": {"fingerFlexors", "extensorCarpiRadialis"},
                "hand": {"fingerFlexors"},
                "spine": {"abs", "obliques", "lumbarExtensors"},
                "pelvis": {"abs", "obliques", "lumbarExtensors"},
            },
        }
        mutation_count = 0
        for family_id in {
            "scapular-retraction", "scapular-depression", "upright-row"
        }:
            original = self.scapular_closure_families[family_id]
            exercise = original["exercises"][0]
            assigned = {
                item["muscle"] for item in exercise["involvement"]
            }
            demands = original["movementSignature"]["stabilityDemands"]
            actual = {
                region: {
                    muscle_id
                    for muscle_id in assigned
                    if region in self.foundation.profile_by_muscle[
                        muscle_id
                    ]["stabilizes"]
                }
                for region in demands
            }
            self.assertEqual(actual, expected[exercise["catalogID"]])
            for region, providers in actual.items():
                family = copy.deepcopy(original)
                family["exercises"][0]["involvement"] = [
                    item
                    for item in family["exercises"][0]["involvement"]
                    if item["muscle"] not in providers
                ]
                with self.subTest(family=family_id, demand=region):
                    self.assert_scapular_closure_family_fails(
                        family,
                        (
                            f"no assigned muscle capable of stabilizing "
                            f"{region}|fails muscle requirement|requires at "
                            "least one primary muscle|fails prime action"
                        ),
                    )
                mutation_count += 1
        self.assertEqual(mutation_count, 22)

    def test_scapular_elevation_coupled_owner_contract_is_exact(self) -> None:
        family = self.scapular_closure_families["scapular-elevation"]
        signature = family["movementSignature"]
        self.assertEqual(
            family["fixed"],
            {
                "mechanic": "isolation",
                "pattern": None,
                "direction": None,
                "planes": ["frontal"],
            },
        )
        self.assertEqual(
            family["allowed"],
            {
                "equipment": ["dumbbell", "other"],
                "modalities": ["dynamicStrength"],
                "trackingModes": ["reps"],
                "loadModes": ["external", "nonComparable"],
                "lateralities": ["unilateral", "bilateral"],
            },
        )
        self.assertEqual(
            signature["planeBasisActions"], ["scapula.elevation"]
        )
        self.assertEqual(
            signature["primeActions"],
            ["scapula.elevation", "scapula.upwardRotation"],
        )
        self.assertEqual(
            set(signature["forbiddenPrimeActions"]),
            self.foundation.action_ids - set(signature["primeActions"]),
        )
        self.assertEqual(
            signature["stabilityDemands"],
            ["scapula", "shoulder", "elbow", "spine", "pelvis"],
        )
        self.assertNotIn("scapula.downwardRotation", signature["primeActions"])
        self.assertFalse(
            (
                catalog.FAMILIES_ROOT / "scapular-upward-rotation.json"
            ).exists()
        )
        self.assertFalse(
            (
                catalog.FAMILIES_ROOT / "scapular-downward-rotation.json"
            ).exists()
        )

    def test_scapular_elevation_variants_and_grip_boundary_are_exact(
        self,
    ) -> None:
        family = self.scapular_closure_families["scapular-elevation"]
        by_id = {
            exercise["catalogID"]: exercise
            for exercise in family["exercises"]
        }
        expected_variants = {
            "single-arm-dumbbell-shrug": {
                "kineticChain": "open",
                "bodyPosition": "standing",
                "torsoSupport": "none",
                "contralateralSupport": "none",
                "scapularTranslation": "free",
                "upperArmPosition": "atSide",
                "humerothoracicElevationDegrees": 0,
                "elevationPlane": "notApplicable",
                "humeralRotation": "neutral",
                "elbowMotion": "angleHeld",
                "elbowPosture": "extended",
                "forearmMotion": "angleHeld",
                "forearmOrientation": "neutral",
                "handTask": "staticImplementHold",
                "resistanceGeometry": "gravityLoadedDumbbell",
                "humerothoracicAngleControl": "none",
                "craniocervicothoracicStabilization": "none",
                "shrugHeightTarget": "none",
                "topHoldSeconds": 0,
                "wristGuide": "none",
                "fixedPath": False,
                "lowerBodyContribution": "none",
                "neckContribution": "none",
            },
            "bilateral-30-degree-stabilization-shrug": {
                "kineticChain": "open",
                "bodyPosition": "standing",
                "torsoSupport": "none",
                "contralateralSupport": "none",
                "scapularTranslation": "free",
                "upperArmPosition": "abducted30",
                "humerothoracicElevationDegrees": 30,
                "elevationPlane": "frontal",
                "humeralRotation": "notReported",
                "elbowMotion": "angleHeld",
                "elbowPosture": "extended",
                "forearmMotion": "angleHeld",
                "forearmOrientation": "notReported",
                "handTask": "none",
                "resistanceGeometry": "armSegmentGravity",
                "humerothoracicAngleControl": "digitalInclinometer",
                "craniocervicothoracicStabilization": (
                    "investigatorManual"
                ),
                "shrugHeightTarget": "individualMaximumTargetBars",
                "topHoldSeconds": 5,
                "wristGuide": "radialBordersAgainstPlasticGuides",
                "fixedPath": False,
                "lowerBodyContribution": "none",
                "neckContribution": "none",
            },
        }
        expected_roles = {
            "single-arm-dumbbell-shrug": {
                "levatorScapulae": "primary",
                "trapeziusUpper": "primary",
                "serratus": "secondary",
                "externalRotators": "stabilizer",
                "triceps": "stabilizer",
                "extensorCarpiRadialis": "stabilizer",
                "fingerFlexors": "stabilizer",
                "abs": "stabilizer",
                "obliques": "stabilizer",
                "lumbarExtensors": "stabilizer",
            },
            "bilateral-30-degree-stabilization-shrug": {
                "levatorScapulae": "primary",
                "trapeziusUpper": "primary",
                "serratus": "secondary",
                "trapeziusLower": "secondary",
                "externalRotators": "stabilizer",
                "triceps": "stabilizer",
                "deltoidLateral": "stabilizer",
                "supraspinatus": "stabilizer",
                "abs": "stabilizer",
                "obliques": "stabilizer",
                "lumbarExtensors": "stabilizer",
            },
        }
        axes = {axis["id"]: axis for axis in family["variantAxes"]}
        self.assertEqual(set(axes), set(next(iter(expected_variants.values()))))
        for catalog_id, exercise in by_id.items():
            self.assertEqual(exercise["variant"], expected_variants[catalog_id])
            self.assertEqual(
                {
                    item["muscle"]: item["role"]
                    for item in exercise["involvement"]
                },
                expected_roles[catalog_id],
            )
            self.assertEqual(exercise["additionalPrimeActions"], [])
        self.assertEqual(
            by_id["single-arm-dumbbell-shrug"][
                "additionalStabilityDemands"
            ],
            ["wrist", "hand"],
        )
        self.assertEqual(
            by_id["bilateral-30-degree-stabilization-shrug"][
                "additionalStabilityDemands"
            ],
            [],
        )
        lee = by_id["bilateral-30-degree-stabilization-shrug"]
        self.assertEqual(lee["reps"], 2)
        self.assertEqual(lee["variant"]["topHoldSeconds"], 5)
        self.assertIn("hold the top position for five seconds", lee["movementDefinition"])
        self.assertIn("Perform two source-prescribed trials", lee["movementDefinition"])
        self.assertIn(
            "measured immediately after this condition, not a continuously "
            "tracked dynamic angle",
            lee["movementDefinition"],
        )
        lee_muscles = set(expected_roles["bilateral-30-degree-stabilization-shrug"])
        self.assertTrue(
            {"extensorCarpiRadialis", "fingerFlexors"}.isdisjoint(lee_muscles)
        )

    def test_scapular_elevation_mutates_every_axis_and_domain_directly(
        self,
    ) -> None:
        original = self.scapular_closure_families["scapular-elevation"]
        domains = {
            "equipment": ("equipment", catalog.EQUIPMENT),
            "laterality": ("lateralities", catalog.LATERALITIES),
            "modality": ("modalities", catalog.MODALITIES),
            "trackingMode": ("trackingModes", catalog.TRACKING_MODES),
            "loadMode": ("loadModes", catalog.LOAD_MODES),
        }
        mutation_count = 0
        for exercise_index, exercise in enumerate(original["exercises"]):
            for axis in original["variantAxes"]:
                family = copy.deepcopy(original)
                axis_id = axis["id"]
                if axis["valueType"] == "enum":
                    family["exercises"][exercise_index]["variant"][
                        axis_id
                    ] = "mutated"
                    error = re.escape(
                        f"variant.{axis_id} has disallowed value 'mutated'"
                    )
                elif axis["valueType"] == "number":
                    family["exercises"][exercise_index]["variant"][
                        axis_id
                    ] = axis["maximum"] + 1
                    error = re.escape(
                        f"variant.{axis_id} exceeds {axis['maximum']}"
                    )
                elif axis["valueType"] == "boolean":
                    family["exercises"][exercise_index]["variant"][
                        axis_id
                    ] = not axis["fixedValue"]
                    error = re.escape(
                        f"variant.{axis_id} must equal fixed value "
                        f"{axis['fixedValue']!r}"
                    )
                else:
                    self.fail(f"unexpected axis type {axis['valueType']}")
                with self.subTest(
                    exercise=exercise["catalogID"], axis=axis_id
                ):
                    self.assert_scapular_closure_family_fails(family, error)
                mutation_count += 1

            for field, (allowed_key, domain) in domains.items():
                family = copy.deepcopy(original)
                alternatives = domain - set(original["allowed"][allowed_key])
                value = sorted(alternatives)[0] if alternatives else "mutated"
                family["exercises"][exercise_index][field] = value
                with self.subTest(
                    exercise=exercise["catalogID"], field=field
                ):
                    self.assert_scapular_closure_family_fails(
                        family,
                        re.escape(f"selects disallowed {allowed_key}: {value}"),
                    )
                mutation_count += 1
        self.assertEqual(mutation_count, 56)

    def test_scapular_elevation_rules_mutate_every_consequence_directly(
        self,
    ) -> None:
        family = self.scapular_closure_families["scapular-elevation"]
        by_equipment = {
            exercise["equipment"]: exercise
            for exercise in family["exercises"]
        }
        consequence_count = 0
        for rule in family["exerciseRules"]:
            exercise = by_equipment[rule["when"]["value"]]
            for assertion in rule["then"]:
                mutated = copy.deepcopy(exercise)
                field = assertion["field"]
                if field.startswith("variant."):
                    axis_id = field.removeprefix("variant.")
                    axis = next(
                        item
                        for item in family["variantAxes"]
                        if item["id"] == axis_id
                    )
                    if axis["valueType"] == "number":
                        alternatives = {
                            candidate["variant"][axis_id]
                            for candidate in family["exercises"]
                        } - {assertion["value"]}
                    else:
                        alternatives = set(axis["allowedValues"]) - {
                            assertion["value"]
                        }
                    mutated["variant"][axis_id] = next(iter(alternatives))
                else:
                    allowed_key = {
                        "laterality": "lateralities",
                        "loadMode": "loadModes",
                    }[field]
                    alternatives = set(family["allowed"][allowed_key]) - {
                        assertion["value"]
                    }
                    mutated[field] = next(iter(alternatives))
                with self.subTest(rule=rule["id"], field=field):
                    with self.assertRaisesRegex(
                        catalog.ValidationFailure,
                        re.escape(
                            f"violates exercise rule {rule['id']}: {field} "
                            f"must equal {assertion['value']!r}"
                        ),
                    ):
                        catalog.validate_exercise_rule_matches(
                            mutated, [rule], "mutated elevation"
                        )
                consequence_count += 1

            for requirement in rule["requireMuscleRequirements"]:
                mutated = copy.deepcopy(exercise)
                candidates = set(requirement["anyOf"])
                mutated["involvement"] = [
                    item
                    for item in mutated["involvement"]
                    if item["muscle"] not in candidates
                ]
                with self.subTest(rule=rule["id"], muscles=candidates):
                    with self.assertRaisesRegex(
                        catalog.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog.validate_exercise_rule_matches(
                            mutated, [rule], "mutated elevation"
                        )
                consequence_count += 1

            for region in rule["requireAdditionalStabilityDemands"]:
                mutated = copy.deepcopy(exercise)
                mutated["additionalStabilityDemands"].remove(region)
                with self.subTest(rule=rule["id"], region=region):
                    with self.assertRaisesRegex(
                        catalog.ValidationFailure,
                        f"violates exercise rule {rule['id']}",
                    ):
                        catalog.validate_exercise_rule_matches(
                            mutated, [rule], "mutated elevation"
                        )
                consequence_count += 1
        self.assertEqual(consequence_count, 34)

    def test_scapular_closure_evidence_scopes_preserve_limitations(self) -> None:
        sources = {
            source["id"]: source["scope"]
            for source in self.foundation.evidence["sources"]
        }
        retraction = self.scapular_closure_families[
            "scapular-retraction"
        ]
        depression = self.scapular_closure_families[
            "scapular-depression"
        ]
        upright = self.scapular_closure_families["upright-row"]
        self.assertEqual(
            retraction["exercises"][0]["evidenceRefs"],
            ["mccabe-2007-below-90-scapular-exercises"],
        )
        self.assertIn(
            "cools-2004-isokinetic-scapular-rotators",
            retraction["evidenceRefs"],
        )
        self.assertIn(
            "supplemental role evidence only",
            sources["cools-2004-isokinetic-scapular-rotators"],
        )
        self.assertIn(
            "not the active one-way band-retraction fixture",
            sources["cools-2004-isokinetic-scapular-rotators"],
        )
        mccabe_scope = sources["mccabe-2007-below-90-scapular-exercises"]
        self.assertIn("did not measure three-dimensional scapular kinematics", mccabe_scope)
        self.assertIn("pectoralis minor", mccabe_scope)
        self.assertNotIn(
            "pectoralisMinor",
            {
                item["muscle"]
                for item in depression["exercises"][0]["involvement"]
            },
        )
        lee_scope = sources["lee-2016-stabilization-shrug-upward-rotation"]
        self.assertIn("performed two bilateral shrug trials", lee_scope)
        self.assertIn("maximum-height target for five seconds", lee_scope)
        self.assertIn(
            "measured immediately after each exercise condition rather than "
            "continuously through the repetition",
            lee_scope,
        )
        self.assertIn("not a dynamic angle trace", lee_scope)
        self.assertIn("coupled elevation-plus-upward-rotation variant", lee_scope)
        self.assertIn("a pure or separately owned upward-rotation family", lee_scope)
        lorenzetti_scope = sources[
            "lorenzetti-2017-pulling-exercise-kinematics"
        ]
        self.assertIn("mixed sagittal-plus-frontal shoulder path", lorenzetti_scope)
        self.assertIn("does not establish numeric humeral components", lorenzetti_scope)
        self.assertIn("scapular actions, or muscle rankings", lorenzetti_scope)
        self.assertIn(
            "raw cross-channel amplitudes do not rank muscles",
            sources["mcallister-2013-upright-row-grip-width"],
        )
        self.assertIn(
            "cannot independently assign upright-row roles",
            sources["eldridge-2024-loaded-scapular-elevation"],
        )
        self.assertEqual(
            upright["exercises"][0]["evidenceRefs"],
            ["lorenzetti-2017-pulling-exercise-kinematics"],
        )

    def test_upright_row_runtime_classification_and_closure_counts_are_exact(
        self,
    ) -> None:
        records = catalog.compile_runtime_catalog(self.real_families)
        by_id = {record["catalogID"]: record for record in records}
        upright = by_id["standing-low-cable-upright-row"]
        self.assertEqual(len(self.real_families), 54)
        self.assertEqual(len(records), 132)
        self.assertEqual(len(self.foundation.evidence_ids), 149)
        self.assertEqual(
            {
                key: upright[key]
                for key in (
                    "familyID", "mechanic", "pattern", "direction", "planes",
                    "equipment", "laterality", "modality", "trackingMode",
                    "loadMode",
                )
            },
            {
                "familyID": "upright-row",
                "mechanic": "compound",
                "pattern": "pull",
                "direction": "vertical",
                "planes": ["sagittal", "frontal"],
                "equipment": "cable",
                "laterality": "bilateral",
                "modality": "dynamicStrength",
                "trackingMode": "reps",
                "loadMode": "external",
            },
        )
        primes = set(
            self.scapular_closure_families["upright-row"][
                "movementSignature"
            ]["primeActions"]
        )
        self.assertEqual(
            primes,
            {
                "shoulder.flexion",
                "shoulder.abduction",
                "scapula.upwardRotation",
                "scapula.posteriorTilt",
                "elbow.flexion",
            },
        )
        self.assertTrue(
            {
                "scapula.elevation",
                "scapula.retraction",
                "shoulder.internalRotation",
                "shoulder.externalRotation",
            }.isdisjoint(primes)
        )

    def test_lumbar_taxonomy_split_migrates_each_active_role_exactly(self) -> None:
        actual = {
            exercise["catalogID"]: {
                assignment["muscle"]: assignment["role"]
                for assignment in exercise["involvement"]
                if assignment["muscle"] in {
                    "quadratusLumborum", "lumbarExtensors"
                }
            }
            for family in self.real_families
            for exercise in family["exercises"]
            if any(
                assignment["muscle"] in {
                    "quadratusLumborum", "lumbarExtensors"
                }
                for assignment in exercise["involvement"]
            )
        }
        ql_secondary = {
            "side-plank",
            "fixed-leg-side-lying-lateral-trunk-lift",
            "single-dumbbell-suitcase-carry",
        }
        self.assertEqual(
            {
                catalog_id
                for catalog_id, roles in actual.items()
                if roles.get("quadratusLumborum") == "secondary"
            },
            ql_secondary,
        )
        self.assertEqual(
            {
                catalog_id
                for catalog_id, roles in actual.items()
                if set(roles) == {"quadratusLumborum", "lumbarExtensors"}
            },
            {
                "fixed-leg-side-lying-lateral-trunk-lift",
                "single-dumbbell-suitcase-carry",
            },
        )
        self.assertEqual(
            actual["medx-isolated-lumbar-extension"],
            {"lumbarExtensors": "primary"},
        )
        self.assertNotIn(
            "quadratusLumborum",
            self.batch7_families["spine-extension"]["musclePolicy"][
                "allowedByRole"
            ]["primary"],
        )

        # QL can anatomically extend, so the generic validator would accept a
        # coordinated substitution. This exact reviewed-role tripwire keeps
        # that capability from silently becoming a MedX exercise oracle.
        medx = copy.deepcopy(self.batch7_families["spine-extension"])
        medx["musclePolicy"]["requirements"][0]["anyOf"] = [
            "quadratusLumborum"
        ]
        medx["musclePolicy"]["allowedByRole"]["primary"] = [
            "quadratusLumborum"
        ]
        medx["exercises"][0]["involvement"] = [
            {"muscle": "quadratusLumborum", "role": "primary"}
        ]
        catalog.validate_family(medx, self.foundation)
        self.assertNotEqual(
            medx["exercises"][0]["involvement"],
            self.batch7_families["spine-extension"]["exercises"][0][
                "involvement"
            ],
        )

    def test_generic_grip_is_not_an_active_family(self) -> None:
        active_ids = {family["id"] for family in self.real_families}
        self.assertTrue(
            {"grip", "finger-flexion-grip"}.isdisjoint(active_ids)
        )
        proposal = (
            catalog.SPEC_ROOT
            / "proposals"
            / "batch-2-distal-actions.md"
        ).read_text(encoding="utf-8")
        self.assertIn("generic `grip` remains deferred", proposal)

    def test_all_evidence_is_used_by_anatomy_or_a_family(self) -> None:
        catalog.validate_evidence_coverage(
            self.foundation,
            self.real_families,
        )

    def test_real_family_set_has_no_cross_family_identity_collisions(self) -> None:
        catalog.validate_family_set(self.real_families)

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
            catalog.ValidationFailure,
            "family set duplicates catalogID barbell-bench-press",
        ):
            catalog.validate_family_set(
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
            "plane-basis action shoulder.flexion must also be a family prime "
            "or resisted action",
        )

    def test_resisted_only_family_uses_resisted_action_as_plane_basis(self) -> None:
        family = self.resisted_spine_family()
        warnings = catalog.validate_family(
            family,
            self.foundation,
            "resisted-only fixture",
        )
        self.assertEqual(warnings, [])

    def test_family_requires_at_least_one_prime_or_resisted_action(self) -> None:
        family = self.resisted_spine_family()
        family["movementSignature"].pop("resistedActions")
        self.assert_family_fails(
            family,
            "movementSignature requires at least one prime or resisted action",
        )

    def test_present_resisted_action_surface_cannot_be_empty(self) -> None:
        family = self.resisted_spine_family()
        family["movementSignature"]["resistedActions"] = []
        self.assert_family_fails(
            family,
            r"movementSignature\.resistedActions must not be empty",
        )

    def test_resisted_family_rejects_an_orphan_plane_basis_action(self) -> None:
        family = self.resisted_spine_family()
        family["movementSignature"]["planeBasisActions"] = [
            "spine.flexion"
        ]
        self.assert_family_fails(
            family,
            "plane-basis action spine.flexion must also be a family prime or "
            "resisted action",
        )

    def test_resisted_action_at_basis_region_must_use_a_declared_plane(
        self,
    ) -> None:
        family = copy.deepcopy(self.batch7_families["anti-rotation"])
        family["movementSignature"]["resistedActions"].append(
            "spine.flexion"
        )
        self.assert_batch7_family_fails(
            family,
            "resisted action spine.flexion uses undeclared sagittal plane "
            "at spine",
        )

    def test_family_cannot_mark_one_action_prime_and_resisted(self) -> None:
        family = self.resisted_spine_family()
        family["movementSignature"]["primeActions"] = ["spine.extension"]
        self.assert_family_fails(
            family,
            "both declares prime and resisted actions: spine.extension",
        )

    def test_exercise_union_cannot_mark_one_action_prime_and_resisted(
        self,
    ) -> None:
        family = self.resisted_spine_family()
        family["exercises"][0]["additionalPrimeActions"] = [
            "spine.extension"
        ]
        self.assert_family_fails(
            family,
            "family roster declares actions as both prime and resisted: "
            "spine.extension",
        )

    def test_roster_prepass_uses_canonical_exercise_context_for_unknown_action(
        self,
    ) -> None:
        family = copy.deepcopy(self.batch7_families["anti-rotation"])
        family["exercises"][0]["additionalPrimeActions"] = ["bogus.action"]
        self.assert_batch7_family_fails(
            family,
            r"^family anti-rotation exercise\[0\]\.additionalPrimeActions\[0\] "
            r"references unknown action bogus\.action",
        )

    def test_roster_prepass_uses_canonical_exercise_context_for_non_object(
        self,
    ) -> None:
        family = copy.deepcopy(self.batch7_families["anti-rotation"])
        family["exercises"][0] = "not-an-exercise"
        self.assert_batch7_family_fails(
            family,
            r"^family anti-rotation exercise\[0\] must be an object$",
        )

    def test_resisted_action_requires_a_mover_that_produces_its_opposite(
        self,
    ) -> None:
        family = self.resisted_spine_family()
        family["musclePolicy"] = {
            "requirements": [
                {"anyOf": ["lumbarExtensors"], "minimumRole": "primary"}
            ],
            "allowedByRole": {
                "primary": ["lumbarExtensors"],
                "secondary": [],
                "stabilizer": [],
            },
        }
        family["exercises"][0]["involvement"] = [
            {"muscle": "lumbarExtensors", "role": "primary"}
        ]
        family["groupPolicy"]["allowed"].append("back")
        family["exercises"][0]["groupOverride"] = "back"
        self.assert_family_fails(
            family,
            "has no primary/secondary muscle capable of opposing "
            "spine.extension with spine.flexion",
        )

    def test_conditioned_opposite_capability_is_not_broadened(self) -> None:
        family = self.family_copy()
        family["fixed"]["planes"] = ["sagittal"]
        family["movementSignature"] = {
            "planeBasisActions": ["shoulder.flexion"],
            "primeActions": [],
            "resistedActions": ["shoulder.flexion"],
            "stabilityDemands": ["shoulder"],
        }
        family["musclePolicy"] = {
            "requirements": [
                {
                    "anyOf": ["pectoralisMajorSternocostal"],
                    "minimumRole": "primary",
                }
            ],
            "allowedByRole": {
                "primary": ["pectoralisMajorSternocostal"],
                "secondary": [],
                "stabilizer": [],
            },
        }
        family["exercises"][0]["involvement"] = [
            {
                "muscle": "pectoralisMajorSternocostal",
                "role": "primary",
            }
        ]
        self.assert_family_fails(
            family,
            "has no primary/secondary muscle capable of opposing "
            "shoulder.flexion with shoulder.extension",
        )

    def test_resisted_action_condition_qualifies_external_tendency(self) -> None:
        family = self.family_copy()
        family["fixed"] = {
            "mechanic": "isolation",
            "pattern": None,
            "direction": None,
            "planes": ["sagittal"],
        }
        family["groupPolicy"] = {
            "default": "shoulders",
            "allowed": ["shoulders"],
        }
        family["movementSignature"] = {
            "planeBasisActions": ["shoulder.extension"],
            "primeActions": [],
            "resistedActions": [
                {
                    "action": "shoulder.extension",
                    "condition": "fromFlexedPosition",
                }
            ],
            "stabilityDemands": ["shoulder"],
        }
        family["musclePolicy"] = {
            "requirements": [
                {"anyOf": ["deltoidAnterior"], "minimumRole": "primary"}
            ],
            "allowedByRole": {
                "primary": ["deltoidAnterior"],
                "secondary": [],
                "stabilizer": [],
            },
        }
        family["exercises"][0]["involvement"] = [
            {"muscle": "deltoidAnterior", "role": "primary"}
        ]
        self.assertEqual(
            catalog.validate_family(
                family,
                self.foundation,
                "conditioned resisted-action fixture",
            ),
            [],
        )

    def test_action_opposition_map_is_total_symmetric_and_supports_grip(
        self,
    ) -> None:
        oppositions = self.foundation.opposing_action_by_action
        expected_groups = {
            frozenset({"scapula.elevation", "scapula.depression"}),
            frozenset({"scapula.protraction", "scapula.retraction"}),
            frozenset(
                {"scapula.upwardRotation", "scapula.downwardRotation"}
            ),
            frozenset({"scapula.anteriorTilt", "scapula.posteriorTilt"}),
            frozenset({"shoulder.flexion", "shoulder.extension"}),
            frozenset({"shoulder.abduction", "shoulder.adduction"}),
            frozenset(
                {
                    "shoulder.horizontalAdduction",
                    "shoulder.horizontalAbduction",
                }
            ),
            frozenset(
                {"shoulder.internalRotation", "shoulder.externalRotation"}
            ),
            frozenset({"elbow.flexion", "elbow.extension"}),
            frozenset({"forearm.pronation", "forearm.supination"}),
            frozenset({"wrist.flexion", "wrist.extension"}),
            frozenset({"wrist.radialDeviation", "wrist.ulnarDeviation"}),
            frozenset({"hand.fingerFlexion", "hand.fingerExtension"}),
            frozenset({"spine.flexion", "spine.extension"}),
            frozenset({"spine.lateralFlexion"}),
            frozenset({"spine.rotation"}),
            frozenset({"hip.flexion", "hip.extension"}),
            frozenset({"hip.abduction", "hip.adduction"}),
            frozenset({"hip.internalRotation", "hip.externalRotation"}),
            frozenset({"knee.flexion", "knee.extension"}),
            frozenset({"ankle.plantarflexion", "ankle.dorsiflexion"}),
            frozenset({"ankle.inversion", "ankle.eversion"}),
            frozenset({"foot.toeFlexion", "foot.toeExtension"}),
        }
        actual_groups = {
            frozenset({action, opposite})
            for action, opposite in oppositions.items()
        }
        self.assertEqual(actual_groups, expected_groups)
        self.assertEqual(set(oppositions), self.foundation.action_ids)
        for action, opposite in oppositions.items():
            self.assertEqual(oppositions[opposite], action)
        self.assertEqual(
            oppositions["hand.fingerExtension"],
            "hand.fingerFlexion",
        )
        self.assertEqual(oppositions["spine.extension"], "spine.flexion")
        self.assertEqual(
            {
                action
                for action, opposite in oppositions.items()
                if action == opposite
            },
            catalog.DIRECTION_AGGREGATED_ACTIONS,
        )

    def test_action_opposition_map_rejects_incomplete_coverage(self) -> None:
        actions = copy.deepcopy(self.foundation.joint_actions)
        hand_pair = next(
            pair
            for pair in actions["actionOppositions"]
            if "hand.fingerExtension" in pair["actions"]
        )
        hand_pair["actions"].remove("hand.fingerExtension")
        with self.assertRaisesRegex(
            catalog.ValidationFailure,
            "actionOppositions must cover every action exactly once",
        ):
            catalog.validate_joint_actions(
                actions,
                set(self.foundation.muscle_by_id),
                self.foundation.evidence_ids,
            )

    def test_action_opposition_pair_must_share_region_and_plane(self) -> None:
        actions = copy.deepcopy(self.foundation.joint_actions)
        scapular_pair = next(
            pair
            for pair in actions["actionOppositions"]
            if "scapula.elevation" in pair["actions"]
        )
        scapular_pair["actions"][1] = "shoulder.abduction"
        with self.assertRaisesRegex(
            catalog.ValidationFailure,
            "must share one joint region and cardinal plane",
        ):
            catalog.validate_joint_actions(
                actions,
                set(self.foundation.muscle_by_id),
                self.foundation.evidence_ids,
            )

    def test_action_opposition_entry_must_be_an_object(self) -> None:
        actions = copy.deepcopy(self.foundation.joint_actions)
        actions["actionOppositions"][0] = []
        with self.assertRaisesRegex(
            catalog.ValidationFailure,
            r"actionOppositions\[0\] must be an object",
        ):
            catalog.validate_joint_actions(
                actions,
                set(self.foundation.muscle_by_id),
                self.foundation.evidence_ids,
            )

    def test_action_opposition_entry_rejects_unknown_keys(self) -> None:
        actions = copy.deepcopy(self.foundation.joint_actions)
        actions["actionOppositions"][0]["note"] = "not structural data"
        with self.assertRaisesRegex(
            catalog.ValidationFailure,
            r"actionOppositions\[0\] has unknown keys: note",
        ):
            catalog.validate_joint_actions(
                actions,
                set(self.foundation.muscle_by_id),
                self.foundation.evidence_ids,
            )

    def test_action_opposition_members_must_be_an_array(self) -> None:
        actions = copy.deepcopy(self.foundation.joint_actions)
        actions["actionOppositions"][0]["actions"] = "scapula.elevation"
        with self.assertRaisesRegex(
            catalog.ValidationFailure,
            r"actionOppositions\[0\]\.actions must be an array",
        ):
            catalog.validate_joint_actions(
                actions,
                set(self.foundation.muscle_by_id),
                self.foundation.evidence_ids,
            )

    def test_action_opposition_members_must_be_unique(self) -> None:
        actions = copy.deepcopy(self.foundation.joint_actions)
        actions["actionOppositions"][0]["actions"] = [
            "scapula.elevation",
            "scapula.elevation",
        ]
        with self.assertRaisesRegex(
            catalog.ValidationFailure,
            r"actionOppositions\[0\]\.actions contains duplicates",
        ):
            catalog.validate_joint_actions(
                actions,
                set(self.foundation.muscle_by_id),
                self.foundation.evidence_ids,
            )

    def test_action_opposition_entry_accepts_at_most_one_pair(self) -> None:
        actions = copy.deepcopy(self.foundation.joint_actions)
        actions["actionOppositions"][0]["actions"] = [
            "scapula.elevation",
            "scapula.depression",
            "scapula.protraction",
        ]
        with self.assertRaisesRegex(
            catalog.ValidationFailure,
            "must contain one direction-aggregated action or one opposing pair",
        ):
            catalog.validate_joint_actions(
                actions,
                set(self.foundation.muscle_by_id),
                self.foundation.evidence_ids,
            )

    def test_action_opposition_entry_rejects_unknown_actions(self) -> None:
        actions = copy.deepcopy(self.foundation.joint_actions)
        actions["actionOppositions"][0]["actions"][1] = "bogus.action"
        with self.assertRaisesRegex(
            catalog.ValidationFailure,
            r"actionOppositions\[0\]\.actions references unknown actions: "
            r"bogus\.action",
        ):
            catalog.validate_joint_actions(
                actions,
                set(self.foundation.muscle_by_id),
                self.foundation.evidence_ids,
            )

    def test_action_opposition_member_cannot_repeat_across_entries(self) -> None:
        actions = copy.deepcopy(self.foundation.joint_actions)
        actions["actionOppositions"][1]["actions"][1] = "scapula.elevation"
        with self.assertRaisesRegex(
            catalog.ValidationFailure,
            r"actionOppositions\[1\]\.actions repeats opposition members: "
            r"scapula\.elevation",
        ):
            catalog.validate_joint_actions(
                actions,
                set(self.foundation.muscle_by_id),
                self.foundation.evidence_ids,
            )

    def test_action_opposition_singletons_are_only_direction_aggregated(
        self,
    ) -> None:
        actions = copy.deepcopy(self.foundation.joint_actions)
        first_pair = actions["actionOppositions"][0]["actions"]
        actions["actionOppositions"][0]["actions"] = [first_pair[0]]
        actions["actionOppositions"].insert(1, {"actions": [first_pair[1]]})
        with self.assertRaisesRegex(
            catalog.ValidationFailure,
            "singleton actions must be exactly the direction-aggregated vocabulary",
        ):
            catalog.validate_joint_actions(
                actions,
                set(self.foundation.muscle_by_id),
                self.foundation.evidence_ids,
            )

    def test_family_resisted_action_requires_matching_stability_demand(
        self,
    ) -> None:
        family = self.resisted_spine_family()
        family["movementSignature"]["stabilityDemands"] = []
        self.assert_family_fails(
            family,
            "family resisted actions require matching stability demands: "
            "spine",
        )

    def test_foundation_digest_is_deterministic(self) -> None:
        first = catalog.canonical_foundation_digest(self.foundation)
        second = catalog.canonical_foundation_digest(
            catalog.validate_foundation()
        )
        self.assertEqual(first, second)
        self.assertEqual(len(first), 64)

    def test_family_schema_cannot_introduce_a_fourth_plane(self) -> None:
        schema = copy.deepcopy(self.foundation.family_schema)
        planes = schema["$defs"]["fixedClassification"]["properties"]["planes"]
        planes["items"]["enum"].append("oblique")
        with self.assertRaisesRegex(
            catalog.ValidationFailure,
            "movement-plane enum must contain exactly the three cardinal planes",
        ):
            catalog.validate_family_schema(schema)

    def test_family_schema_must_permit_empty_unique_prime_actions(self) -> None:
        mutations = {
            "requires-one": lambda schema: schema["$defs"][
                "movementSignature"
            ]["properties"]["primeActions"].__setitem__("minItems", 1),
            "permits-duplicates": lambda schema: schema["$defs"][
                "movementSignature"
            ]["properties"]["primeActions"].__setitem__(
                "uniqueItems", False
            ),
        }
        for label, mutate in mutations.items():
            schema = copy.deepcopy(self.foundation.family_schema)
            mutate(schema)
            with self.subTest(mutation=label), self.assertRaisesRegex(
                catalog.ValidationFailure,
                "primeActions must permit an empty anti-motion contract",
            ):
                catalog.validate_family_schema(schema)

    def test_family_schema_resisted_actions_remain_optional_non_empty_unique(
        self,
    ) -> None:
        for label, key, value in (
            ("permits-empty", "minItems", None),
            ("permits-duplicates", "uniqueItems", False),
        ):
            schema = copy.deepcopy(self.foundation.family_schema)
            resisted_actions = schema["$defs"]["movementSignature"][
                "properties"
            ]["resistedActions"]
            if value is None:
                resisted_actions.pop(key)
            else:
                resisted_actions[key] = value
            with self.subTest(mutation=label), self.assertRaisesRegex(
                catalog.ValidationFailure,
                "resistedActions must be an optional non-empty unique action list",
            ):
                catalog.validate_family_schema(schema)

        schema = copy.deepcopy(self.foundation.family_schema)
        schema["$defs"]["movementSignature"]["required"].append(
            "resistedActions"
        )
        with self.subTest(mutation="becomes-required"), self.assertRaisesRegex(
            catalog.ValidationFailure,
            "movementSignature required fields differ from validator contract",
        ):
            catalog.validate_family_schema(schema)

    def test_family_schema_requires_a_prime_or_resisted_action(self) -> None:
        schema = copy.deepcopy(self.foundation.family_schema)
        schema["$defs"]["movementSignature"].pop("anyOf")
        with self.assertRaisesRegex(
            catalog.ValidationFailure,
            "movementSignature must require at least one prime or resisted action",
        ):
            catalog.validate_family_schema(schema)

    def test_duplicate_mesh_ownership_is_rejected(self) -> None:
        taxonomy = copy.deepcopy(self.foundation.taxonomy)
        by_id = {muscle["id"]: muscle for muscle in taxonomy["muscles"]}
        by_id["serratus"]["meshBaseNames"] = ["Latissimus_Dorsi"]
        with self.assertRaisesRegex(
            catalog.ValidationFailure,
            "owned by both serratus and lats",
        ):
            catalog.validate_taxonomy(taxonomy)

    def test_unknown_evidence_reference_is_rejected(self) -> None:
        actions = copy.deepcopy(self.foundation.joint_actions)
        actions["muscleProfiles"][0]["evidenceRefs"] = ["invented-source"]
        with self.assertRaisesRegex(
            catalog.ValidationFailure,
            "references unknown evidence",
        ):
            catalog.validate_joint_actions(
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
            catalog.ValidationFailure,
            "references unknown action condition inventedPosition",
        ):
            catalog.validate_joint_actions(
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
        warnings = catalog.validate_family(
            family,
            self.foundation,
            "conditioned extension fixture",
        )
        self.assertEqual(warnings, [])

    def test_matching_extended_start_flexion_condition_satisfies_family(
        self,
    ) -> None:
        family = self.sternocostal_flexion_family(
            {
                "action": "shoulder.flexion",
                "condition": "fromExtendedPosition",
            }
        )
        self.assertEqual(
            catalog.validate_family(
                family,
                self.foundation,
                "conditioned flexion fixture",
            ),
            [],
        )

    def test_conditioned_sternocostal_flexion_cannot_satisfy_bare_flexion(
        self,
    ) -> None:
        family = self.sternocostal_flexion_family("shoulder.flexion")
        self.assert_family_fails(
            family,
            "no primary/secondary muscle capable of shoulder.flexion",
        )

    def test_sternocostal_flexion_capability_is_pinned_conditioned(self) -> None:
        profile = self.foundation.profile_by_muscle[
            "pectoralisMajorSternocostal"
        ]
        conditioned = {
            "action": "shoulder.flexion",
            "condition": "fromExtendedPosition",
        }
        self.assertIn(conditioned, profile["produces"])
        self.assertNotIn("shoulder.flexion", profile["produces"])

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
        family["musclePolicy"]["allowedByRole"]["secondary"].append(
            "medialHamstrings"
        )
        family["exercises"][0]["involvement"].append(
            {"muscle": "medialHamstrings", "role": "secondary"}
        )
        self.assert_family_fails(
            family,
            "secondary muscle medialHamstrings cannot produce any declared prime action",
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

    def test_mover_may_cover_a_stability_demand_without_role_duplication(
        self,
    ) -> None:
        family = copy.deepcopy(self.batch4_families["knee-extension"])
        self.assertEqual(
            family["musclePolicy"]["allowedByRole"]["stabilizer"],
            [],
        )
        for exercise in family["exercises"]:
            self.assertTrue(
                all(
                    assignment["role"] in {"primary", "secondary"}
                    for assignment in exercise["involvement"]
                )
            )
        self.assertEqual(
            catalog.validate_family(
                family,
                self.foundation,
                "mover-covered stability fixture",
            ),
            [],
        )

        family["movementSignature"]["stabilityDemands"].append("spine")
        self.assert_batch4_family_fails(
            family,
            "no assigned muscle capable of stabilizing spine",
        )

    def test_stabilizer_must_match_a_declared_stability_demand(self) -> None:
        family = self.family_copy()
        family["musclePolicy"]["allowedByRole"]["stabilizer"].append("soleus")
        family["exercises"][0]["involvement"].append(
            {"muscle": "soleus", "role": "stabilizer"}
        )
        self.assert_family_fails(
            family,
            "stabilizer muscle soleus cannot stabilize any declared demand",
        )

    def test_undeclared_variant_axis_is_rejected(self) -> None:
        family = self.family_copy()
        family["exercises"][0]["variant"]["inventedAxis"] = "invented"
        self.assert_family_fails(family, "contains undeclared axes: inventedAxis")

    def test_programming_recommendation_is_a_warning_not_membership_failure(self) -> None:
        family = self.family_copy()
        family["exercises"][0]["reps"] = 30
        warnings = catalog.validate_family(
            family,
            self.foundation,
            "recommendation fixture",
        )
        self.assertEqual(
            warnings,
            ["fixture-barbell-horizontal-press: reps 30 is outside recommended 5...15"],
        )

    def test_runtime_projection_is_exactly_54_families_and_132_exercises(
        self,
    ) -> None:
        records = catalog.compile_runtime_catalog(self.real_families)
        self.assertEqual(len(records), 132)
        self.assertEqual(
            {record["familyID"] for record in records},
            {family["id"] for family in self.real_families},
        )
        self.assertEqual(len({record["familyID"] for record in records}), 54)
        self.assertEqual(
            records,
            catalog.compile_runtime_catalog(reversed(self.real_families)),
        )

        records_by_id = {record["catalogID"]: record for record in records}
        self.assertEqual(
            {
                catalog_id: {
                    "familyID": records_by_id[catalog_id]["familyID"],
                    "planes": records_by_id[catalog_id]["planes"],
                    "involvement": records_by_id[catalog_id]["involvement"],
                }
                for catalog_id in {
                    "seated-flywheel-hip-internal-rotation",
                    "therapist-held-supine-band-hip-external-rotation",
                }
            },
            {
                "seated-flywheel-hip-internal-rotation": {
                    "familyID": "hip-internal-rotation",
                    "planes": ["transverse"],
                    "involvement": [
                        {"muscle": "gluteMed", "role": "primary"},
                        {
                            "muscle": "tensorFasciaeLatae",
                            "role": "primary",
                        },
                        {"muscle": "gluteMin", "role": "secondary"},
                        {"muscle": "obliques", "role": "stabilizer"},
                    ],
                },
                "therapist-held-supine-band-hip-external-rotation": {
                    "familyID": "hip-external-rotation",
                    "planes": ["transverse"],
                    "involvement": [
                        {
                            "muscle": "obturatorInternusGemelli",
                            "role": "primary",
                        },
                        {"muscle": "obturatorExternus", "role": "secondary"},
                        {"muscle": "piriformis", "role": "secondary"},
                        {"muscle": "quadratusFemoris", "role": "secondary"},
                        {"muscle": "obliques", "role": "stabilizer"},
                        {
                            "muscle": "medialHamstrings",
                            "role": "stabilizer",
                        },
                    ],
                },
            },
        )

        expected_identity_order = [
            (family["id"], exercise["catalogID"])
            for family in sorted(self.real_families, key=lambda value: value["id"])
            for exercise in family["exercises"]
        ]
        self.assertEqual(
            [
                (record["familyID"], record["catalogID"])
                for record in records
            ],
            expected_identity_order,
        )

    def test_runtime_projection_has_one_canonical_plane_order(self) -> None:
        fixture = self.family_copy()
        fixture["fixed"]["planes"] = [
            "transverse",
            "frontal",
            "sagittal",
        ]
        record = catalog.compile_runtime_catalog([fixture])[0]
        self.assertEqual(
            record["planes"],
            ["sagittal", "frontal", "transverse"],
        )

    def test_runtime_projection_preserves_diagonal_and_multiplane_contracts(
        self,
    ) -> None:
        records = {
            record["catalogID"]: record
            for record in catalog.compile_runtime_catalog(self.real_families)
        }
        for catalog_id in {
            "incline-barbell-bench-press",
            "incline-dumbbell-bench-press",
            "incline-smith-machine-bench-press",
            "incline-machine-chest-press",
        }:
            with self.subTest(catalog_id=catalog_id):
                self.assertEqual(records[catalog_id]["direction"], "diagonal")
                self.assertEqual(
                    records[catalog_id]["planes"],
                    ["sagittal", "transverse"],
                )
        self.assertEqual(
            records["standing-barbell-overhead-press"]["planes"],
            ["sagittal", "frontal"],
        )
        self.assertEqual(
            records["decline-barbell-bench-press"]["direction"],
            "diagonal",
        )
        self.assertEqual(
            records["decline-barbell-bench-press"]["planes"],
            ["transverse"],
        )

    def test_runtime_projection_applies_group_override_and_optionals_exactly(
        self,
    ) -> None:
        records = {
            record["catalogID"]: record
            for record in catalog.compile_runtime_catalog(self.real_families)
        }
        self.assertEqual(records["barbell-pullover"]["group"], "chest")
        self.assertEqual(
            self.batch1_families["shoulder-extension-isolation"][
                "groupPolicy"
            ]["default"],
            "back",
        )

        base_keys = {
            "familyID", "catalogID", "name", "group", "defaultWeight",
            "reps", "trackingMode", "equipment", "mechanic", "pattern",
            "direction", "planes", "laterality", "aliases",
            "bodyweightFraction", "modality", "loadMode",
            "movementDefinition", "involvement",
        }
        optional_keys = {"defaultWeightKg", "defaultDuration", "searchPriority"}
        for family in self.real_families:
            for exercise in family["exercises"]:
                record = records[exercise["catalogID"]]
                expected_optionals = optional_keys & exercise.keys()
                with self.subTest(catalog_id=exercise["catalogID"]):
                    self.assertEqual(set(record), base_keys | expected_optionals)
                    for key in optional_keys:
                        self.assertEqual(key in record, key in exercise)

        fixture = self.family_copy()
        fixture["exercises"][0].pop("defaultWeightKg")
        fixture["exercises"][0].pop("searchPriority")
        record = catalog.compile_runtime_catalog([fixture])[0]
        self.assertNotIn("defaultWeightKg", record)
        self.assertNotIn("defaultDuration", record)
        self.assertNotIn("searchPriority", record)

    def test_bundled_runtime_is_byte_for_byte_compiler_output(self) -> None:
        encoded = catalog.encoded_runtime_catalog(
            catalog.compile_runtime_catalog(self.real_families)
        )
        self.assertTrue(encoded.endswith("\n"))
        self.assertEqual(
            catalog.RUNTIME_CATALOG_PATH.read_text(encoding="utf-8"),
            encoded,
        )

    def test_xcode_catalog_sandbox_allowlist_matches_compiler_inputs(self) -> None:
        expected = catalog.encoded_xcode_input_file_list(
            catalog.discovered_family_paths()
        )
        self.assertEqual(
            catalog.XCODE_INPUT_FILE_LIST_PATH.read_text(encoding="utf-8"),
            expected,
        )

    def test_xcode_catalog_phase_is_incremental_and_family_directory_sensitive(
        self,
    ) -> None:
        project = (
            catalog.ROOT / "vivobody.xcodeproj" / "project.pbxproj"
        ).read_text(encoding="utf-8")
        phase = project.split(
            "C7A10B22D3E44F55A6677889 /* Verify Canonical Catalog */ = {",
            maxsplit=1,
        )[1].split("/* End PBXShellScriptBuildPhase section */", maxsplit=1)[0]
        self.assertNotIn("alwaysOutOfDate = 1", phase)
        self.assertIn(
            '"$(SRCROOT)/specs/catalog/families"',
            phase,
        )
        self.assertIn(
            '"$(DERIVED_FILE_DIR)/catalog-check.stamp"',
            phase,
        )

    def test_runtime_writer_is_atomic_and_publishes_normal_resource_mode(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "catalog.json"
            output.write_text("old", encoding="utf-8")
            output.chmod(0o600)
            with mock.patch.object(
                catalog,
                "RUNTIME_CATALOG_PATH",
                output,
            ):
                catalog.write_runtime_catalog_atomically("new\n")
            self.assertEqual(output.read_text(encoding="utf-8"), "new\n")
            self.assertEqual(output.stat().st_mode & 0o777, 0o644)
            self.assertEqual(list(output.parent.glob(".catalog.json.*.tmp")), [])

            with mock.patch.object(
                catalog,
                "RUNTIME_CATALOG_PATH",
                output,
            ), mock.patch.object(
                Path,
                "replace",
                side_effect=OSError("simulated replacement failure"),
            ):
                with self.assertRaisesRegex(
                    OSError,
                    "simulated replacement failure",
                ):
                    catalog.write_runtime_catalog_atomically("broken\n")
            self.assertEqual(output.read_text(encoding="utf-8"), "new\n")
            self.assertEqual(list(output.parent.glob(".catalog.json.*.tmp")), [])

    def test_check_is_read_only_and_emit_is_the_only_write_mode(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "catalog.json"
            allowlist = Path(directory) / "catalog-inputs.xcfilelist"
            allowlist.write_text(
                catalog.encoded_xcode_input_file_list(
                    catalog.discovered_family_paths()
                ),
                encoding="utf-8",
            )
            output.write_text("stale\n", encoding="utf-8")
            with mock.patch.object(
                catalog,
                "RUNTIME_CATALOG_PATH",
                output,
            ), mock.patch.object(
                catalog,
                "XCODE_INPUT_FILE_LIST_PATH",
                allowlist,
            ), mock.patch("builtins.print"):
                self.assertEqual(catalog.main([]), 0)
                self.assertEqual(output.read_text(encoding="utf-8"), "stale\n")
                self.assertEqual(catalog.main(["--check"]), 1)
                self.assertEqual(output.read_text(encoding="utf-8"), "stale\n")
                self.assertEqual(catalog.main(["--emit-runtime"]), 0)

            expected = catalog.encoded_runtime_catalog(
                catalog.compile_runtime_catalog(self.real_families)
            )
            self.assertEqual(output.read_text(encoding="utf-8"), expected)

    def test_check_and_emit_modes_are_mutually_exclusive(self) -> None:
        with mock.patch.object(sys, "stderr"), self.assertRaises(SystemExit):
            catalog.parse_args(["--check", "--emit-runtime"])

    def test_supplemental_family_validation_cannot_enter_runtime_output(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temporary_root = Path(directory)
            supplemental = temporary_root / "supplemental-family.json"
            supplemental.write_text(
                json.dumps(self.valid_family),
                encoding="utf-8",
            )
            output = temporary_root / "catalog.json"
            allowlist = temporary_root / "catalog-inputs.xcfilelist"
            with mock.patch.object(
                catalog,
                "RUNTIME_CATALOG_PATH",
                output,
            ), mock.patch.object(
                catalog,
                "XCODE_INPUT_FILE_LIST_PATH",
                allowlist,
            ), mock.patch("builtins.print"):
                self.assertEqual(
                    catalog.main(
                        ["--emit-runtime", "--family", str(supplemental)]
                    ),
                    0,
                )
            emitted = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(len(emitted), 132)
            self.assertNotIn(
                "fixture-horizontal-press",
                {record["familyID"] for record in emitted},
            )
            self.assertEqual(
                emitted,
                catalog.compile_runtime_catalog(self.real_families),
            )

if __name__ == "__main__":
    unittest.main()
