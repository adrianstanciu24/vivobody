#!/usr/bin/env python3
#
#  catalog.py
#  vivobody
#
#  Foundation validator and deterministic compiler for the family-first
#  exercise catalog. It validates the canonical 58-region taxonomy,
#  exact SceneKit mesh ownership, independent joint-action profiles, evidence
#  references, and every reviewed movement-family contract. The exact-region
#  taxonomy keeps action-divergent lower-body muscles separate wherever the
#  scene can represent the distinction. This is the sole deterministic writer
#  for the app's bundled runtime catalog; check mode reads that generated
#  artifact only to prove exact compiler parity.
#

from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import re
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Optional


ROOT = Path(__file__).resolve().parents[1]
SPEC_ROOT = ROOT / "specs" / "catalog"
TAXONOMY_PATH = SPEC_ROOT / "taxonomy.json"
JOINT_ACTIONS_PATH = SPEC_ROOT / "joint-actions.json"
EVIDENCE_PATH = SPEC_ROOT / "evidence.json"
FAMILY_SCHEMA_PATH = SPEC_ROOT / "family.schema.json"
FAMILY_FIXTURE_PATH = SPEC_ROOT / "fixtures" / "valid-family.json"
FAMILIES_ROOT = SPEC_ROOT / "families"
BODY_MODEL_PATH = ROOT / "vivobody" / "Resources" / "BodyModel.scn"
CANONICAL_RUNTIME_CATALOG_PATH = (
    ROOT / "vivobody" / "Resources" / "catalog.json"
)
RUNTIME_CATALOG_PATH = CANONICAL_RUNTIME_CATALOG_PATH
XCODE_INPUT_FILE_LIST_PATH = ROOT / "Scripts" / "catalog-inputs.xcfilelist"

SCHEMA_VERSION = 1
EXPECTED_GROUPS = ("chest", "back", "shoulders", "arms", "core", "legs")
EXPECTED_MESH_BASE_COUNT = 60
NON_TRAINABLE_MESH_BASES = {
    "Serratus_Posterior_Inferior",
    "Serratus_Posterior_Superior",
}
EXPECTED_ACTION_COUNT = 44
DIRECTION_AGGREGATED_ACTIONS = {
    "spine.lateralFlexion",
    "spine.rotation",
}
EXPECTED_MUSCLE_IDS = {
    "pectoralisMajorClavicular",
    "pectoralisMajorSternocostal",
    "pectoralisMinor",
    "serratus",
    "lats",
    "trapeziusUpper",
    "trapeziusMiddle",
    "trapeziusLower",
    "levatorScapulae",
    "rhomboids",
    "teresMajor",
    "quadratusLumborum",
    "lumbarExtensors",
    "deltoidAnterior",
    "deltoidLateral",
    "deltoidPosterior",
    "externalRotators",
    "subscapularis",
    "supraspinatus",
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
    "triceps",
    "abs",
    "obliques",
    "rectusFemoris",
    "vasti",
    "bicepsFemoris",
    "medialHamstrings",
    "gluteMax",
    "gluteMed",
    "gluteMin",
    "tensorFasciaeLatae",
    "piriformis",
    "obturatorInternusGemelli",
    "obturatorExternus",
    "quadratusFemoris",
    "gastrocnemius",
    "soleus",
    "flexorHallucisLongus",
    "adductorMagnus",
    "adductorLongusBrevis",
    "gracilis",
    "pectineus",
    "iliopsoas",
    "sartorius",
    "tibialisAnterior",
    "fibularisLongusBrevis",
    "fibularisTertius",
    "toeExtensors",
}
EXPECTED_MUSCLE_COUNT = len(EXPECTED_MUSCLE_IDS)
EXPECTED_SPLIT_MESHES = {
    "pectoralisMajorClavicular": ["Pectoralis_Major_Clavicular"],
    "pectoralisMajorSternocostal": ["Pectoralis_Major_Sternocostal"],
    "pectoralisMinor": ["Pectoralis_Minor"],
    "deltoidAnterior": ["Deltoid_Anterior"],
    "deltoidLateral": ["Deltoid_Lateral"],
    "deltoidPosterior": ["Deltoid_Posterior"],
    "trapeziusUpper": ["Trapezius_Upper"],
    "quadratusLumborum": ["Quadratus_Lumborum"],
    "lumbarExtensors": [],
    "trapeziusMiddle": ["Trapezius_Middle"],
    "trapeziusLower": ["Trapezius_Lower"],
    "levatorScapulae": ["Levator_Scapulaes"],
    "bicepsBrachii": ["Biceps"],
    "brachialis": ["Brachialis"],
    "brachioradialis": ["Brachioradialis"],
    "flexorCarpiRadialis": ["Flexor_Carpi_Radialis"],
    "flexorCarpiUlnaris": ["Flexor_Carpi_Ulnaris"],
    "extensorCarpiRadialis": [
        "Extensor_Carpi_Radialis_Longus",
        "Extensor_Carpi_Radialis_Brevis",
    ],
    "extensorCarpiUlnaris": ["Extensor_Carpi_Ulnaris"],
    "fingerFlexors": [
        "Flexor_Digitorum_Superficialis",
        "Flexor_Digitorum_Profundus",
    ],
    "fingerExtensors": ["Extensor_Digitorum_Communis"],
    "rectusFemoris": ["Rectus_Femoris"],
    "vasti": ["Vastus_Lateralis", "Vastus_Medialis", "Vastus_Intermedius"],
    "bicepsFemoris": ["Biceps_femoris"],
    "medialHamstrings": ["Semitendinosus", "Semimembranosus"],
    "gluteMed": ["Gluteus_Medius"],
    "gluteMin": [],
    "piriformis": [],
    "obturatorInternusGemelli": [],
    "obturatorExternus": [],
    "quadratusFemoris": [],
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
    "toeExtensors": ["Extensor_Digitorum_Longus", "Extensor_Hallucis_Longus"],
}

EQUIPMENT = {
    "barbell", "dumbbell", "cable", "machine", "bodyweight",
    "kettlebell", "band", "gripTrainer", "other",
}
MECHANICS = {"compound", "isolation"}
PATTERNS = {"push", "pull", "squat", "hinge", "lunge", "carry", "core", "locomotion"}
DIRECTIONS = {"horizontal", "vertical", "diagonal"}
CARDINAL_PLANES = {"sagittal", "frontal", "transverse"}
LATERALITIES = {"bilateral", "unilateral"}
TRACKING_MODES = {"reps", "duration"}
MODALITIES = {"dynamicStrength", "isometricStrength", "power", "conditioning", "mobility"}
LOAD_MODES = {"external", "bodyweightAdded", "assistanceSubtracted", "nonComparable"}
ROLES = {"primary", "secondary", "stabilizer"}
ROLE_RANK = {"stabilizer": 1, "secondary": 2, "primary": 3}
RULE_FIELD_DOMAINS = {
    "equipment": EQUIPMENT,
    "laterality": LATERALITIES,
    "modality": MODALITIES,
    "trackingMode": TRACKING_MODES,
    "loadMode": LOAD_MODES,
}
RULE_NUMERIC_FIELDS = {
    "bodyweightFraction": (0, 1),
}

ActionRequirement = tuple[str, Optional[str]]

STABLE_ID = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
SYMBOL_ID = re.compile(r"^[a-z][A-Za-z0-9]*$")
ACTION_ID = re.compile(r"^[a-z][A-Za-z0-9]*\.[a-z][A-Za-z0-9]*$")
MESH_BASE_NAME = re.compile(r"^[A-Za-z0-9_]+$")
RULE_FIELD_PATH = re.compile(r"^[a-z][A-Za-z0-9]*(?:\.[a-z][A-Za-z0-9]*)?$")
MISSING = object()


class ValidationFailure(ValueError):
    """One deterministic catalog contract violation."""


@dataclass(frozen=True)
class Foundation:
    taxonomy: dict[str, Any]
    joint_actions: dict[str, Any]
    evidence: dict[str, Any]
    family_schema: dict[str, Any]
    muscle_by_id: dict[str, dict[str, Any]]
    profile_by_muscle: dict[str, dict[str, Any]]
    capabilities_by_muscle: dict[str, frozenset[ActionRequirement]]
    action_ids: frozenset[str]
    plane_by_action: dict[str, str]
    condition_actions: dict[str, frozenset[str]]
    condition_variant_constraints: dict[str, tuple[str, Any]]
    opposing_action_by_action: dict[str, str]
    region_ids: frozenset[str]
    evidence_ids: frozenset[str]
    mesh_base_count: int


def fail(message: str) -> None:
    raise ValidationFailure(message)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def display_path(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        fail(f"missing JSON source: {display_path(path)}")
    except json.JSONDecodeError as error:
        fail(f"invalid JSON in {display_path(path)}: {error}")
    require(isinstance(value, dict), f"{display_path(path)} must contain a JSON object")
    return value


def require_keys(
    value: dict[str, Any],
    *,
    required: Iterable[str],
    optional: Iterable[str] = (),
    context: str,
) -> None:
    required_set = set(required)
    allowed = required_set | set(optional)
    missing = sorted(required_set - value.keys())
    unknown = sorted(value.keys() - allowed)
    require(not missing, f"{context} is missing keys: {', '.join(missing)}")
    require(not unknown, f"{context} has unknown keys: {', '.join(unknown)}")


def require_non_empty_string(value: Any, context: str) -> str:
    require(isinstance(value, str) and value.strip(), f"{context} must be a non-empty string")
    return value


def require_list(value: Any, context: str, *, allow_empty: bool = False) -> list[Any]:
    require(isinstance(value, list), f"{context} must be an array")
    require(allow_empty or bool(value), f"{context} must not be empty")
    return value


def require_unique(values: list[Any], context: str) -> None:
    canonical = [json.dumps(value, sort_keys=True) for value in values]
    require(len(canonical) == len(set(canonical)), f"{context} contains duplicates")


def require_schema_version(value: dict[str, Any], context: str) -> None:
    require(value.get("schemaVersion") == SCHEMA_VERSION, f"{context} must use schemaVersion {SCHEMA_VERSION}")


def normalized_name(value: str) -> str:
    return " ".join(value.split()).casefold()


def action_requirement_label(requirement: ActionRequirement) -> str:
    action, condition = requirement
    return action if condition is None else f"{action} ({condition})"


def parse_action_requirement(
    value: Any,
    *,
    action_ids: set[str] | frozenset[str],
    condition_actions: dict[str, frozenset[str]],
    context: str,
) -> ActionRequirement:
    if isinstance(value, str):
        action = require_non_empty_string(value, context)
        condition = None
    else:
        require(isinstance(value, dict), f"{context} must be an action ID or a conditional action object")
        require_keys(value, required={"action", "condition"}, context=context)
        action = require_non_empty_string(value["action"], f"{context}.action")
        condition = require_non_empty_string(value["condition"], f"{context}.condition")
        require(SYMBOL_ID.fullmatch(condition) is not None, f"{context}.condition is not a stable symbol ID: {condition}")

    require(action in action_ids, f"{context} references unknown action {action}")
    if condition is not None:
        require(condition in condition_actions, f"{context} references unknown action condition {condition}")
        require(
            action in condition_actions[condition],
            f"{context} condition {condition} does not apply to {action}",
        )
    return action, condition


def validate_action_requirements(
    value: Any,
    *,
    action_ids: set[str] | frozenset[str],
    condition_actions: dict[str, frozenset[str]],
    context: str,
    allow_empty: bool = False,
) -> frozenset[ActionRequirement]:
    raw_requirements = require_list(value, context, allow_empty=allow_empty)
    require_unique(raw_requirements, context)
    requirements = [
        parse_action_requirement(
            item,
            action_ids=action_ids,
            condition_actions=condition_actions,
            context=f"{context}[{index}]",
        )
        for index, item in enumerate(raw_requirements)
    ]
    require(len(requirements) == len(set(requirements)), f"{context} contains equivalent action requirements")
    return frozenset(requirements)


def capability_satisfies(
    capability: ActionRequirement,
    requirement: ActionRequirement,
) -> bool:
    capability_action, capability_condition = capability
    required_action, required_condition = requirement
    if capability_action != required_action:
        return False
    if required_condition is None:
        return capability_condition is None
    return capability_condition is None or capability_condition == required_condition


def capability_opposes(
    capability: ActionRequirement,
    resisted_requirement: ActionRequirement,
    opposing_action_by_action: dict[str, str],
) -> bool:
    """Whether a muscle capability can oppose an externally imposed action.

    `resistedActions` names the external joint-action tendency, not the muscle's
    internal action. The muscle must therefore produce the centrally paired
    opposite action. A position condition qualifies the external tendency only;
    it is never translated into a different condition on the opposing action.
    Until such a translation is reviewed explicitly, only an unconditional
    opposing capability is accepted.
    """

    capability_action, capability_condition = capability
    resisted_action, _ = resisted_requirement
    return (
        capability_action == opposing_action_by_action[resisted_action]
        and capability_condition is None
    )


def scene_strings(path: Path) -> set[str]:
    try:
        root = plistlib.loads(path.read_bytes())
    except (FileNotFoundError, plistlib.InvalidFileException) as error:
        fail(f"cannot decode SceneKit asset {display_path(path)}: {error}")

    strings: set[str] = set()

    def walk(value: Any) -> None:
        if isinstance(value, dict):
            for key, nested in value.items():
                if isinstance(key, str):
                    strings.add(key)
                walk(nested)
        elif isinstance(value, (list, tuple)):
            for nested in value:
                walk(nested)
        elif isinstance(value, str):
            strings.add(value)

    walk(root)
    return strings


def validate_taxonomy(data: dict[str, Any], body_model_path: Path = BODY_MODEL_PATH) -> tuple[dict[str, dict[str, Any]], int]:
    context = "taxonomy.json"
    require_keys(
        data,
        required={"schemaVersion", "description", "groups", "muscles"},
        context=context,
    )
    require_schema_version(data, context)
    require_non_empty_string(data["description"], f"{context}.description")

    groups = require_list(data["groups"], f"{context}.groups")
    require_unique(groups, f"{context}.groups")
    require(tuple(groups) == EXPECTED_GROUPS, f"{context}.groups must match the app's six MuscleGroup raw values")

    muscles = require_list(data["muscles"], f"{context}.muscles")
    require(
        len(muscles) == EXPECTED_MUSCLE_COUNT,
        f"{context} must define exactly {EXPECTED_MUSCLE_COUNT} muscles, found {len(muscles)}",
    )
    muscle_by_id: dict[str, dict[str, Any]] = {}
    owner_by_mesh_base: dict[str, str] = {}

    for index, muscle in enumerate(muscles):
        item_context = f"{context}.muscles[{index}]"
        require(isinstance(muscle, dict), f"{item_context} must be an object")
        require_keys(
            muscle,
            required={"id", "displayName", "anatomicalName", "group", "meshBaseNames"},
            optional={"unvisualizedReason"},
            context=item_context,
        )
        muscle_id = require_non_empty_string(muscle["id"], f"{item_context}.id")
        require(SYMBOL_ID.fullmatch(muscle_id) is not None, f"{item_context}.id is not a stable symbol ID: {muscle_id}")
        require(muscle_id not in muscle_by_id, f"duplicate muscle ID: {muscle_id}")
        require_non_empty_string(muscle["displayName"], f"{item_context}.displayName")
        require_non_empty_string(muscle["anatomicalName"], f"{item_context}.anatomicalName")
        require(muscle["group"] in groups, f"{item_context}.group is unknown: {muscle['group']}")

        mesh_bases = require_list(muscle["meshBaseNames"], f"{item_context}.meshBaseNames", allow_empty=True)
        require_unique(mesh_bases, f"{item_context}.meshBaseNames")
        if mesh_bases:
            require("unvisualizedReason" not in muscle, f"{item_context} has meshes and must not declare unvisualizedReason")
        else:
            require_non_empty_string(muscle.get("unvisualizedReason"), f"{item_context}.unvisualizedReason")

        for mesh_base in mesh_bases:
            require(
                isinstance(mesh_base, str) and MESH_BASE_NAME.fullmatch(mesh_base) is not None,
                f"{item_context} has invalid mesh base name: {mesh_base!r}",
            )
            previous_owner = owner_by_mesh_base.get(mesh_base)
            require(
                previous_owner is None,
                f"mesh base {mesh_base} is owned by both {previous_owner} and {muscle_id}",
            )
            owner_by_mesh_base[mesh_base] = muscle_id

        muscle_by_id[muscle_id] = muscle

    actual_ids = set(muscle_by_id)
    missing_ids = sorted(EXPECTED_MUSCLE_IDS - actual_ids)
    unexpected_ids = sorted(actual_ids - EXPECTED_MUSCLE_IDS)
    require(
        actual_ids == EXPECTED_MUSCLE_IDS,
        f"{context} muscle IDs differ from the locked taxonomy; missing={missing_ids}, unexpected={unexpected_ids}",
    )

    for muscle_id, expected_meshes in EXPECTED_SPLIT_MESHES.items():
        actual_meshes = muscle_by_id[muscle_id]["meshBaseNames"]
        require(
            actual_meshes == expected_meshes,
            f"{muscle_id} must own exactly {expected_meshes}, found {actual_meshes}",
        )

    require(
        len(owner_by_mesh_base) == EXPECTED_MESH_BASE_COUNT,
        f"{context} must own exactly {EXPECTED_MESH_BASE_COUNT} mesh bases, found {len(owner_by_mesh_base)}",
    )

    model_strings = scene_strings(body_model_path)
    for mesh_base, owner in sorted(owner_by_mesh_base.items()):
        for suffix in ("L", "R"):
            node_name = f"{mesh_base}_{suffix}"
            require(node_name in model_strings, f"{owner} references missing BodyModel.scn node {node_name}")

    for mesh_base in sorted(NON_TRAINABLE_MESH_BASES):
        require(mesh_base not in owner_by_mesh_base, f"non-trainable mesh base {mesh_base} must not be owned by a muscle region")
        for suffix in ("L", "R"):
            node_name = f"{mesh_base}_{suffix}"
            require(node_name in model_strings, f"declared non-trainable BodyModel.scn node is missing: {node_name}")

    return muscle_by_id, len(owner_by_mesh_base)


def validate_evidence(data: dict[str, Any]) -> frozenset[str]:
    context = "evidence.json"
    require_keys(data, required={"schemaVersion", "description", "sources"}, context=context)
    require_schema_version(data, context)
    require_non_empty_string(data["description"], f"{context}.description")
    sources = require_list(data["sources"], f"{context}.sources")
    evidence_ids: set[str] = set()
    identifier_owners: dict[tuple[str, str], str] = {}

    for index, source in enumerate(sources):
        item_context = f"{context}.sources[{index}]"
        require(isinstance(source, dict), f"{item_context} must be an object")
        require_keys(
            source,
            required={"id", "sourceType", "title", "authors", "year", "url", "scope"},
            optional={"doi", "pmid", "pmcid"},
            context=item_context,
        )
        source_id = require_non_empty_string(source["id"], f"{item_context}.id")
        require(STABLE_ID.fullmatch(source_id) is not None, f"invalid evidence ID: {source_id}")
        require(source_id not in evidence_ids, f"duplicate evidence ID: {source_id}")
        evidence_ids.add(source_id)
        require_non_empty_string(source["sourceType"], f"{item_context}.sourceType")
        require_non_empty_string(source["title"], f"{item_context}.title")
        authors = require_list(source["authors"], f"{item_context}.authors")
        require_unique(authors, f"{item_context}.authors")
        for author in authors:
            require_non_empty_string(author, f"{item_context}.authors entry")
        require(type(source["year"]) is int and 1900 <= source["year"] <= 2100, f"{item_context}.year is invalid")
        require_non_empty_string(source["scope"], f"{item_context}.scope")
        require(
            any(key in source for key in ("doi", "pmid", "pmcid")),
            f"{item_context} must declare at least one canonical identifier: doi, pmid, or pmcid",
        )
        if "doi" in source:
            doi = require_non_empty_string(source["doi"], f"{item_context}.doi")
            expected_url = f"https://doi.org/{doi}"
        elif "pmcid" in source:
            pmcid = source["pmcid"]
            require(
                isinstance(pmcid, str) and re.fullmatch(r"PMC[1-9][0-9]*", pmcid) is not None,
                f"{item_context}.pmcid must use the canonical PMC plus digits form",
            )
            expected_url = f"https://pmc.ncbi.nlm.nih.gov/articles/{pmcid}/"
        else:
            pmid = source["pmid"]
            require(isinstance(pmid, str) and pmid.isdigit(), f"{item_context}.pmid must contain digits")
            expected_url = f"https://pubmed.ncbi.nlm.nih.gov/{pmid}/"
        require(source["url"] == expected_url, f"{item_context}.url must match its highest-priority canonical identifier")
        if "pmid" in source:
            require(
                isinstance(source["pmid"], str) and re.fullmatch(r"[1-9][0-9]*", source["pmid"]) is not None,
                f"{item_context}.pmid must use canonical non-zero digits",
            )
        if "pmcid" in source:
            require(
                isinstance(source["pmcid"], str) and re.fullmatch(r"PMC[1-9][0-9]*", source["pmcid"]) is not None,
                f"{item_context}.pmcid must use the canonical PMC plus digits form",
            )
        for identifier_key in ("doi", "pmid", "pmcid"):
            if identifier_key not in source:
                continue
            identifier = source[identifier_key]
            owner_key = (identifier_key, identifier.casefold() if identifier_key == "doi" else identifier)
            previous_owner = identifier_owners.get(owner_key)
            require(
                previous_owner is None,
                f"{item_context}.{identifier_key} duplicates canonical identifier owned by {previous_owner}",
            )
            identifier_owners[owner_key] = source_id

    return frozenset(evidence_ids)


def validate_joint_actions(
    data: dict[str, Any],
    muscle_ids: set[str],
    evidence_ids: frozenset[str],
) -> tuple[
    dict[str, dict[str, Any]],
    dict[str, frozenset[ActionRequirement]],
    frozenset[str],
    dict[str, str],
    dict[str, frozenset[str]],
    dict[str, tuple[str, Any]],
    dict[str, str],
    frozenset[str],
]:
    context = "joint-actions.json"
    require_keys(
        data,
        required={
            "schemaVersion",
            "description",
            "regions",
            "actions",
            "actionOppositions",
            "actionConditions",
            "muscleProfiles",
        },
        context=context,
    )
    require_schema_version(data, context)
    require_non_empty_string(data["description"], f"{context}.description")

    regions = require_list(data["regions"], f"{context}.regions")
    require_unique(regions, f"{context}.regions")
    for region in regions:
        require(isinstance(region, str) and SYMBOL_ID.fullmatch(region), f"invalid stability region ID: {region!r}")
    region_ids = frozenset(regions)

    actions = require_list(data["actions"], f"{context}.actions")
    action_ids: set[str] = set()
    plane_by_action: dict[str, str] = {}
    for index, action in enumerate(actions):
        item_context = f"{context}.actions[{index}]"
        require(isinstance(action, dict), f"{item_context} must be an object")
        require_keys(action, required={"id", "region", "plane", "displayName"}, context=item_context)
        action_id = require_non_empty_string(action["id"], f"{item_context}.id")
        require(ACTION_ID.fullmatch(action_id) is not None, f"invalid joint-action ID: {action_id}")
        require(action_id not in action_ids, f"duplicate joint-action ID: {action_id}")
        require(action["region"] in region_ids, f"{action_id} references unknown region {action['region']}")
        require(action_id.split(".", 1)[0] == action["region"], f"{action_id} prefix must match region {action['region']}")
        require(action["plane"] in CARDINAL_PLANES, f"{action_id} references unknown plane {action['plane']}")
        require_non_empty_string(action["displayName"], f"{item_context}.displayName")
        action_ids.add(action_id)
        plane_by_action[action_id] = action["plane"]

    require(
        len(action_ids) == EXPECTED_ACTION_COUNT,
        f"{context} must define exactly {EXPECTED_ACTION_COUNT} joint actions, found {len(action_ids)}",
    )

    opposition_values = require_list(
        data["actionOppositions"],
        f"{context}.actionOppositions",
    )
    opposing_action_by_action: dict[str, str] = {}
    singleton_actions: set[str] = set()
    for index, opposition in enumerate(opposition_values):
        item_context = f"{context}.actionOppositions[{index}]"
        require(isinstance(opposition, dict), f"{item_context} must be an object")
        require_keys(opposition, required={"actions"}, context=item_context)
        members = require_list(opposition["actions"], f"{item_context}.actions")
        require_unique(members, f"{item_context}.actions")
        require(
            len(members) in {1, 2},
            f"{item_context}.actions must contain one direction-aggregated action or one opposing pair",
        )
        unknown_actions = sorted(set(members) - action_ids)
        require(
            not unknown_actions,
            f"{item_context}.actions references unknown actions: {', '.join(unknown_actions)}",
        )
        repeated_actions = sorted(set(members) & opposing_action_by_action.keys())
        require(
            not repeated_actions,
            f"{item_context}.actions repeats opposition members: {', '.join(repeated_actions)}",
        )
        regions = {action.split(".", 1)[0] for action in members}
        planes = {plane_by_action[action] for action in members}
        require(
            len(regions) == 1 and len(planes) == 1,
            f"{item_context}.actions must share one joint region and cardinal plane",
        )
        if len(members) == 1:
            singleton_actions.add(members[0])
            opposing_action_by_action[members[0]] = members[0]
        else:
            first, second = members
            opposing_action_by_action[first] = second
            opposing_action_by_action[second] = first

    require(
        set(opposing_action_by_action) == action_ids,
        f"{context}.actionOppositions must cover every action exactly once",
    )
    require(
        singleton_actions == DIRECTION_AGGREGATED_ACTIONS,
        f"{context}.actionOppositions singleton actions must be exactly the direction-aggregated vocabulary",
    )

    conditions = require_list(data["actionConditions"], f"{context}.actionConditions", allow_empty=True)
    condition_actions: dict[str, frozenset[str]] = {}
    condition_variant_constraints: dict[str, tuple[str, Any]] = {}
    for index, condition_value in enumerate(conditions):
        item_context = f"{context}.actionConditions[{index}]"
        require(isinstance(condition_value, dict), f"{item_context} must be an object")
        require_keys(
            condition_value,
            required={"id", "displayName", "definition", "appliesTo"},
            optional={"variantConstraint"},
            context=item_context,
        )
        condition_id = require_non_empty_string(condition_value["id"], f"{item_context}.id")
        require(SYMBOL_ID.fullmatch(condition_id) is not None, f"invalid action-condition ID: {condition_id}")
        require(condition_id not in condition_actions, f"duplicate action-condition ID: {condition_id}")
        require_non_empty_string(condition_value["displayName"], f"{item_context}.displayName")
        require_non_empty_string(condition_value["definition"], f"{item_context}.definition")
        applies_to = require_list(condition_value["appliesTo"], f"{item_context}.appliesTo")
        require_unique(applies_to, f"{item_context}.appliesTo")
        unknown_actions = sorted(set(applies_to) - action_ids)
        require(not unknown_actions, f"{condition_id} applies to unknown actions: {', '.join(unknown_actions)}")
        condition_actions[condition_id] = frozenset(applies_to)
        if "variantConstraint" in condition_value:
            constraint = condition_value["variantConstraint"]
            constraint_context = f"{item_context}.variantConstraint"
            require(isinstance(constraint, dict), f"{constraint_context} must be an object")
            require_keys(
                constraint,
                required={"axis", "equals"},
                context=constraint_context,
            )
            axis_id = require_non_empty_string(
                constraint["axis"], f"{constraint_context}.axis"
            )
            require(
                SYMBOL_ID.fullmatch(axis_id) is not None,
                f"{constraint_context}.axis is not a stable symbol ID: {axis_id}",
            )
            expected = constraint["equals"]
            require(
                type(expected) in {str, int, float, bool} and expected != "",
                f"{constraint_context}.equals must be a non-empty scalar",
            )
            condition_variant_constraints[condition_id] = (axis_id, expected)

    profiles = require_list(data["muscleProfiles"], f"{context}.muscleProfiles")
    profile_by_muscle: dict[str, dict[str, Any]] = {}
    capabilities_by_muscle: dict[str, frozenset[ActionRequirement]] = {}
    produced_actions: set[str] = set()
    referenced_conditions: set[str] = set()

    for index, profile in enumerate(profiles):
        item_context = f"{context}.muscleProfiles[{index}]"
        require(isinstance(profile, dict), f"{item_context} must be an object")
        require_keys(
            profile,
            required={"muscleID", "produces", "stabilizes", "evidenceRefs"},
            optional={"notes"},
            context=item_context,
        )
        muscle_id = require_non_empty_string(profile["muscleID"], f"{item_context}.muscleID")
        require(muscle_id in muscle_ids, f"{item_context} references unknown muscle {muscle_id}")
        require(muscle_id not in profile_by_muscle, f"duplicate joint-action profile for {muscle_id}")

        capabilities = validate_action_requirements(
            profile["produces"],
            action_ids=action_ids,
            condition_actions=condition_actions,
            context=f"{item_context}.produces",
        )
        unconditional_actions = {
            action
            for action, condition in capabilities
            if condition is None
        }
        redundant_conditionals = sorted(
            action_requirement_label(capability)
            for capability in capabilities
            if capability[1] is not None and capability[0] in unconditional_actions
        )
        require(
            not redundant_conditionals,
            f"{muscle_id} declares conditional capabilities already covered unconditionally: {', '.join(redundant_conditionals)}",
        )
        produced_actions.update(action for action, _ in capabilities)
        referenced_conditions.update(
            condition
            for _, condition in capabilities
            if condition is not None
        )

        stabilizes = require_list(profile["stabilizes"], f"{item_context}.stabilizes")
        require_unique(stabilizes, f"{item_context}.stabilizes")
        unknown_regions = sorted(set(stabilizes) - region_ids)
        require(not unknown_regions, f"{muscle_id} stabilizes unknown regions: {', '.join(unknown_regions)}")

        refs = require_list(profile["evidenceRefs"], f"{item_context}.evidenceRefs")
        require_unique(refs, f"{item_context}.evidenceRefs")
        unknown_refs = sorted(set(refs) - evidence_ids)
        require(not unknown_refs, f"{muscle_id} references unknown evidence: {', '.join(unknown_refs)}")
        if "notes" in profile:
            require_non_empty_string(profile["notes"], f"{item_context}.notes")

        profile_by_muscle[muscle_id] = profile
        capabilities_by_muscle[muscle_id] = capabilities

    missing_profiles = sorted(muscle_ids - profile_by_muscle.keys())
    extra_profiles = sorted(profile_by_muscle.keys() - muscle_ids)
    require(not missing_profiles and not extra_profiles, f"joint-action profiles mismatch taxonomy; missing={missing_profiles}, extra={extra_profiles}")
    unproduced_actions = sorted(action_ids - produced_actions)
    require(not unproduced_actions, f"joint-action vocabulary contains actions no muscle can produce: {', '.join(unproduced_actions)}")
    unused_conditions = sorted(condition_actions.keys() - referenced_conditions)
    require(not unused_conditions, f"joint-action vocabulary contains unused conditions: {', '.join(unused_conditions)}")
    return (
        profile_by_muscle,
        capabilities_by_muscle,
        frozenset(action_ids),
        plane_by_action,
        condition_actions,
        condition_variant_constraints,
        opposing_action_by_action,
        region_ids,
    )


def validate_family_schema(data: dict[str, Any]) -> None:
    context = "family.schema.json"
    require(data.get("$schema") == "https://json-schema.org/draft/2020-12/schema", f"{context} must use JSON Schema 2020-12")
    require(data.get("type") == "object", f"{context} root must describe an object")
    require(data.get("additionalProperties") is False, f"{context} root must reject unknown properties")
    require(data.get("properties", {}).get("schemaVersion", {}).get("const") == SCHEMA_VERSION, f"{context} schemaVersion must be locked to 1")
    roles = data.get("$defs", {}).get("role", {}).get("enum")
    require(set(roles or []) == ROLES, f"{context} role enum must remain primary/secondary/stabilizer")

    definitions = data.get("$defs", {})
    require(isinstance(definitions, dict) and definitions, f"{context} must define reusable contract fragments")
    fixed_classification = definitions.get("fixedClassification", {})
    require(
        set(fixed_classification.get("required", []))
        == {"mechanic", "pattern", "direction", "planes"},
        f"{context} fixedClassification required fields differ from validator contract",
    )
    fixed_properties = fixed_classification.get("properties", {})
    direction_values = fixed_properties.get("direction", {}).get("enum")
    planes_schema = fixed_properties.get("planes", {})
    plane_values = planes_schema.get("items", {}).get("enum")
    require(
        set(direction_values or []) == {*DIRECTIONS, None},
        f"{context} direction enum differs from validator vocabulary",
    )
    require(
        set(plane_values or []) == CARDINAL_PLANES,
        f"{context} movement-plane enum must contain exactly the three cardinal planes",
    )
    require(
        planes_schema.get("minItems") == 1
        and planes_schema.get("maxItems") == 3
        and planes_schema.get("uniqueItems") is True,
        f"{context} planes must require one to three unique cardinal planes",
    )
    movement_signature = definitions.get("movementSignature", {})
    signature_required = set(movement_signature.get("required", []))
    require(
        signature_required == {"planeBasisActions", "primeActions", "stabilityDemands"},
        f"{context} movementSignature required fields differ from validator contract",
    )
    plane_basis_schema = movement_signature.get("properties", {}).get("planeBasisActions", {})
    require(
        plane_basis_schema.get("minItems") == 1
        and plane_basis_schema.get("maxItems") == 3
        and plane_basis_schema.get("uniqueItems") is True,
        f"{context} planeBasisActions must require one to three unique actions",
    )
    prime_actions_schema = movement_signature.get("properties", {}).get(
        "primeActions", {}
    )
    resisted_actions_schema = movement_signature.get("properties", {}).get(
        "resistedActions", {}
    )
    require(
        "minItems" not in prime_actions_schema
        and prime_actions_schema.get("uniqueItems") is True,
        f"{context} primeActions must permit an empty anti-motion contract",
    )
    require(
        resisted_actions_schema.get("minItems") == 1
        and resisted_actions_schema.get("uniqueItems") is True,
        f"{context} resistedActions must be an optional non-empty unique action list",
    )
    require(
        movement_signature.get("anyOf")
        == [
            {"properties": {"primeActions": {"minItems": 1}}},
            {"required": ["resistedActions"]},
        ],
        f"{context} movementSignature must require at least one prime or resisted action",
    )
    variant_axis = definitions.get("variantAxis", {})
    variant_axis_properties = variant_axis.get("properties", {})
    require(
        variant_axis_properties.get("fixedValue") == {"type": "boolean"},
        f"{context} variantAxis.fixedValue must be a boolean",
    )
    fixed_boolean_constraint = {
        "if": {"required": ["fixedValue"]},
        "then": {
            "properties": {
                "valueType": {"const": "boolean"},
                "required": {"const": True},
            }
        },
    }
    require(
        fixed_boolean_constraint in variant_axis.get("allOf", []),
        f"{context} fixedValue must require a required boolean axis",
    )
    internal_refs: set[str] = set()

    def collect_refs(value: Any) -> None:
        if isinstance(value, dict):
            reference = value.get("$ref")
            if isinstance(reference, str) and reference.startswith("#/$defs/"):
                internal_refs.add(reference.removeprefix("#/$defs/"))
            for nested in value.values():
                collect_refs(nested)
        elif isinstance(value, list):
            for nested in value:
                collect_refs(nested)

    collect_refs(data)
    missing_definitions = sorted(internal_refs - definitions.keys())
    require(not missing_definitions, f"{context} has unresolved internal references: {', '.join(missing_definitions)}")


def validate_foundation(body_model_path: Path = BODY_MODEL_PATH) -> Foundation:
    taxonomy = load_json(TAXONOMY_PATH)
    evidence = load_json(EVIDENCE_PATH)
    joint_actions = load_json(JOINT_ACTIONS_PATH)
    family_schema = load_json(FAMILY_SCHEMA_PATH)

    muscle_by_id, mesh_base_count = validate_taxonomy(taxonomy, body_model_path)
    evidence_ids = validate_evidence(evidence)
    (
        profile_by_muscle,
        capabilities_by_muscle,
        action_ids,
        plane_by_action,
        condition_actions,
        condition_variant_constraints,
        opposing_action_by_action,
        region_ids,
    ) = validate_joint_actions(
        joint_actions,
        set(muscle_by_id),
        evidence_ids,
    )
    validate_family_schema(family_schema)

    return Foundation(
        taxonomy=taxonomy,
        joint_actions=joint_actions,
        evidence=evidence,
        family_schema=family_schema,
        muscle_by_id=muscle_by_id,
        profile_by_muscle=profile_by_muscle,
        capabilities_by_muscle=capabilities_by_muscle,
        action_ids=action_ids,
        plane_by_action=plane_by_action,
        condition_actions=condition_actions,
        condition_variant_constraints=condition_variant_constraints,
        opposing_action_by_action=opposing_action_by_action,
        region_ids=region_ids,
        evidence_ids=evidence_ids,
        mesh_base_count=mesh_base_count,
    )


def require_known_evidence(refs: Any, foundation: Foundation, context: str) -> None:
    values = require_list(refs, context)
    require_unique(values, context)
    unknown = sorted(set(values) - foundation.evidence_ids)
    require(not unknown, f"{context} references unknown evidence: {', '.join(unknown)}")


def validate_fixed_classification(value: Any, context: str) -> None:
    require(isinstance(value, dict), f"{context} must be an object")
    require_keys(value, required={"mechanic", "pattern", "direction", "planes"}, context=context)
    mechanic = value["mechanic"]
    pattern = value["pattern"]
    direction = value["direction"]
    require(mechanic in MECHANICS, f"{context}.mechanic is unknown: {mechanic}")
    require(pattern is None or pattern in PATTERNS, f"{context}.pattern is unknown: {pattern}")
    require(direction is None or direction in DIRECTIONS, f"{context}.direction is unknown: {direction}")
    planes = require_list(value["planes"], f"{context}.planes")
    require_unique(planes, f"{context}.planes")
    require(len(planes) <= 3, f"{context}.planes accepts at most three cardinal planes")
    unknown_planes = sorted(set(planes) - CARDINAL_PLANES)
    require(
        not unknown_planes,
        f"{context}.planes contains unknown values: {', '.join(unknown_planes)}",
    )
    require((mechanic == "compound") == (pattern is not None), f"{context} compound families require a pattern and isolation families require null")
    is_push_pull = pattern in {"push", "pull"}
    require(is_push_pull == (direction is not None), f"{context} direction must exist exactly for push/pull families")


def validate_allowed(value: Any, context: str) -> None:
    require(isinstance(value, dict), f"{context} must be an object")
    require_keys(
        value,
        required={"equipment", "modalities", "trackingModes", "loadModes", "lateralities"},
        context=context,
    )
    domains = {
        "equipment": EQUIPMENT,
        "modalities": MODALITIES,
        "trackingModes": TRACKING_MODES,
        "loadModes": LOAD_MODES,
        "lateralities": LATERALITIES,
    }
    for key, domain in domains.items():
        choices = require_list(value[key], f"{context}.{key}")
        require_unique(choices, f"{context}.{key}")
        unknown = sorted(set(choices) - domain)
        require(not unknown, f"{context}.{key} contains unknown values: {', '.join(unknown)}")


def validate_variant_axes(value: Any, context: str) -> dict[str, dict[str, Any]]:
    axes = require_list(value, context, allow_empty=True)
    axis_by_id: dict[str, dict[str, Any]] = {}
    for index, axis in enumerate(axes):
        axis_context = f"{context}[{index}]"
        require(isinstance(axis, dict), f"{axis_context} must be an object")
        require_keys(
            axis,
            required={"id", "valueType", "required", "description"},
            optional={"allowedValues", "minimum", "maximum", "fixedValue"},
            context=axis_context,
        )
        axis_id = require_non_empty_string(axis["id"], f"{axis_context}.id")
        require(SYMBOL_ID.fullmatch(axis_id) is not None, f"invalid variant-axis ID: {axis_id}")
        require(axis_id not in axis_by_id, f"duplicate variant-axis ID: {axis_id}")
        value_type = axis["valueType"]
        require(value_type in {"enum", "number", "boolean", "string"}, f"{axis_context}.valueType is unknown: {value_type}")
        require(type(axis["required"]) is bool, f"{axis_context}.required must be a boolean")
        require_non_empty_string(axis["description"], f"{axis_context}.description")

        if value_type == "enum":
            allowed_values = require_list(axis.get("allowedValues"), f"{axis_context}.allowedValues")
            require_unique(allowed_values, f"{axis_context}.allowedValues")
            for allowed in allowed_values:
                require_non_empty_string(allowed, f"{axis_context}.allowedValues entry")
            require("minimum" not in axis and "maximum" not in axis, f"{axis_context} enum axis cannot declare numeric bounds")
        elif value_type == "number":
            require("allowedValues" not in axis, f"{axis_context} number axis cannot declare allowedValues")
            minimum = axis.get("minimum")
            maximum = axis.get("maximum")
            require(minimum is None or type(minimum) in {int, float}, f"{axis_context}.minimum must be numeric")
            require(maximum is None or type(maximum) in {int, float}, f"{axis_context}.maximum must be numeric")
            require(minimum is None or maximum is None or minimum <= maximum, f"{axis_context} minimum exceeds maximum")
        else:
            require(
                not ({"allowedValues", "minimum", "maximum"} & axis.keys()),
                f"{axis_context} {value_type} axis cannot declare enum values or numeric bounds",
            )
        if "fixedValue" in axis:
            require(
                value_type == "boolean",
                f"{axis_context}.fixedValue is only valid for a boolean axis",
            )
            require(
                type(axis["fixedValue"]) is bool,
                f"{axis_context}.fixedValue must be a boolean",
            )
            require(
                axis["required"],
                f"{axis_context} with fixedValue must be required",
            )
        axis_by_id[axis_id] = axis
    return axis_by_id


def validate_muscle_requirements(
    value: Any,
    foundation: Foundation,
    allowed_by_role: dict[str, set[str]],
    context: str,
    *,
    allow_empty: bool,
) -> list[dict[str, Any]]:
    requirements = require_list(value, context, allow_empty=allow_empty)
    normalized_requirements: set[tuple[tuple[str, ...], str]] = set()
    for index, requirement in enumerate(requirements):
        item_context = f"{context}[{index}]"
        require(isinstance(requirement, dict), f"{item_context} must be an object")
        require_keys(requirement, required={"anyOf", "minimumRole"}, context=item_context)
        candidates = require_list(requirement["anyOf"], f"{item_context}.anyOf")
        require_unique(candidates, f"{item_context}.anyOf")
        unknown = sorted(set(candidates) - foundation.muscle_by_id.keys())
        require(not unknown, f"{item_context}.anyOf references unknown muscles: {', '.join(unknown)}")
        minimum_role = requirement["minimumRole"]
        require(minimum_role in ROLES, f"{item_context}.minimumRole is unknown: {minimum_role}")
        candidate_is_permitted = any(
            candidate in allowed_by_role[role]
            for candidate in candidates
            for role in ROLES
            if ROLE_RANK[role] >= ROLE_RANK[minimum_role]
        )
        require(candidate_is_permitted, f"{item_context} cannot be satisfied by the family's allowed role matrix")
        normalized = (tuple(sorted(candidates)), minimum_role)
        require(
            normalized not in normalized_requirements,
            f"{context} contains equivalent muscle requirements",
        )
        normalized_requirements.add(normalized)

    return requirements


def validate_role_policy(value: Any, foundation: Foundation, context: str) -> tuple[list[dict[str, Any]], dict[str, set[str]]]:
    require(isinstance(value, dict), f"{context} must be an object")
    require_keys(value, required={"requirements", "allowedByRole"}, context=context)
    allowed_raw = value["allowedByRole"]
    require(isinstance(allowed_raw, dict), f"{context}.allowedByRole must be an object")
    require_keys(allowed_raw, required=ROLES, context=f"{context}.allowedByRole")

    allowed_by_role: dict[str, set[str]] = {}
    for role in sorted(ROLES):
        values = require_list(allowed_raw[role], f"{context}.allowedByRole.{role}", allow_empty=True)
        require_unique(values, f"{context}.allowedByRole.{role}")
        unknown = sorted(set(values) - foundation.muscle_by_id.keys())
        require(not unknown, f"{context}.allowedByRole.{role} references unknown muscles: {', '.join(unknown)}")
        allowed_by_role[role] = set(values)

    requirements = validate_muscle_requirements(
        value["requirements"],
        foundation,
        allowed_by_role,
        f"{context}.requirements",
        allow_empty=True,
    )

    return requirements, allowed_by_role


def validate_recommended(value: Any, context: str) -> None:
    require(isinstance(value, dict), f"{context} must be an object")
    require_keys(value, required=set(), optional={"defaultReps", "defaultDuration"}, context=context)
    for key in ("defaultReps", "defaultDuration"):
        if key not in value:
            continue
        item = value[key]
        require(isinstance(item, dict), f"{context}.{key} must be an object")
        require_keys(item, required={"minimum", "maximum"}, context=f"{context}.{key}")
        minimum = item["minimum"]
        maximum = item["maximum"]
        expected_types = {int} if key == "defaultReps" else {int, float}
        require(type(minimum) in expected_types and type(maximum) in expected_types, f"{context}.{key} bounds have invalid types")
        require(minimum > 0 and maximum > 0 and minimum <= maximum, f"{context}.{key} bounds are invalid")


def validate_variant(
    value: Any,
    axes: dict[str, dict[str, Any]],
    context: str,
) -> None:
    require(isinstance(value, dict), f"{context} must be an object")
    unknown_axes = sorted(value.keys() - axes.keys())
    require(not unknown_axes, f"{context} contains undeclared axes: {', '.join(unknown_axes)}")
    missing_axes = sorted(axis_id for axis_id, axis in axes.items() if axis["required"] and axis_id not in value)
    require(not missing_axes, f"{context} is missing required axes: {', '.join(missing_axes)}")

    for axis_id, axis_value in value.items():
        axis = axes[axis_id]
        value_type = axis["valueType"]
        if value_type in {"enum", "string"}:
            require(isinstance(axis_value, str) and axis_value, f"{context}.{axis_id} must be a non-empty string")
        elif value_type == "number":
            require(type(axis_value) in {int, float}, f"{context}.{axis_id} must be numeric")
        elif value_type == "boolean":
            require(type(axis_value) is bool, f"{context}.{axis_id} must be a boolean")

        if "fixedValue" in axis:
            require(
                axis_value == axis["fixedValue"],
                f"{context}.{axis_id} must equal fixed value {axis['fixedValue']!r}",
            )

        if value_type == "enum":
            require(axis_value in axis["allowedValues"], f"{context}.{axis_id} has disallowed value {axis_value!r}")
        if value_type == "number":
            minimum = axis.get("minimum")
            maximum = axis.get("maximum")
            require(minimum is None or axis_value >= minimum, f"{context}.{axis_id} is below {minimum}")
            require(maximum is None or axis_value <= maximum, f"{context}.{axis_id} exceeds {maximum}")


def validate_rule_field_path(
    path: Any,
    axes: dict[str, dict[str, Any]],
    context: str,
) -> str:
    field_path = require_non_empty_string(path, context)
    require(RULE_FIELD_PATH.fullmatch(field_path) is not None, f"{context} is not a valid field path: {field_path}")
    if "." in field_path:
        root, axis_id = field_path.split(".", 1)
        require(root == "variant", f"{context} may only use nested fields below variant")
        require(axis_id in axes, f"{context} references undeclared variant axis {axis_id}")
    else:
        require(
            field_path in RULE_FIELD_DOMAINS or field_path in RULE_NUMERIC_FIELDS,
            f"{context} references unsupported exercise field {field_path}",
        )
    return field_path


def validate_rule_expected_value(
    field_path: str,
    value: Any,
    axes: dict[str, dict[str, Any]],
    context: str,
) -> None:
    if field_path in RULE_FIELD_DOMAINS:
        require(
            isinstance(value, str) and value in RULE_FIELD_DOMAINS[field_path],
            f"{context} has invalid value {value!r} for {field_path}",
        )
        return

    if field_path in RULE_NUMERIC_FIELDS:
        minimum, maximum = RULE_NUMERIC_FIELDS[field_path]
        require(
            type(value) in {int, float} and minimum <= value <= maximum,
            f"{context} has invalid value {value!r} for {field_path}",
        )
        return

    axis_id = field_path.split(".", 1)[1]
    axis = axes[axis_id]
    value_type = axis["valueType"]
    if value_type in {"enum", "string"}:
        require(isinstance(value, str) and value, f"{context} must be a non-empty string")
    elif value_type == "number":
        require(type(value) in {int, float}, f"{context} must be numeric")
    else:
        require(type(value) is bool, f"{context} must be a boolean")

    if value_type == "enum":
        require(value in axis["allowedValues"], f"{context} has disallowed value {value!r}")
    elif value_type == "number":
        minimum = axis.get("minimum")
        maximum = axis.get("maximum")
        require(minimum is None or value >= minimum, f"{context} is below {minimum}")
        require(maximum is None or value <= maximum, f"{context} exceeds {maximum}")


def validate_exercise_rules(
    value: Any,
    axes: dict[str, dict[str, Any]],
    foundation: Foundation,
    allowed_by_role: dict[str, set[str]],
    context: str,
) -> list[dict[str, Any]]:
    rules = require_list(value, context, allow_empty=True)
    rule_ids: set[str] = set()
    for index, rule in enumerate(rules):
        item_context = f"{context}[{index}]"
        require(isinstance(rule, dict), f"{item_context} must be an object")
        require_keys(
            rule,
            required={"id", "description", "when", "then", "requirePresent", "requireAbsent"},
            optional={
                "requireInvolvement",
                "requireMuscleRequirements",
                "requireAdditionalStabilityDemands",
            },
            context=item_context,
        )
        rule_id = require_non_empty_string(rule["id"], f"{item_context}.id")
        require(STABLE_ID.fullmatch(rule_id) is not None, f"{item_context}.id is invalid: {rule_id}")
        require(rule_id not in rule_ids, f"duplicate exercise-rule ID: {rule_id}")
        rule_ids.add(rule_id)
        require_non_empty_string(rule["description"], f"{item_context}.description")

        predicate = rule["when"]
        require(isinstance(predicate, dict), f"{item_context}.when must be an object")
        require_keys(predicate, required={"field", "operator", "value"}, context=f"{item_context}.when")
        predicate_path = validate_rule_field_path(predicate["field"], axes, f"{item_context}.when.field")
        require(predicate["operator"] in {"equals", "notEquals"}, f"{item_context}.when.operator is invalid")
        validate_rule_expected_value(predicate_path, predicate["value"], axes, f"{item_context}.when.value")

        assertions = require_list(rule["then"], f"{item_context}.then", allow_empty=True)
        asserted_paths: set[str] = set()
        for assertion_index, assertion in enumerate(assertions):
            assertion_context = f"{item_context}.then[{assertion_index}]"
            require(isinstance(assertion, dict), f"{assertion_context} must be an object")
            require_keys(
                assertion,
                required={"field"},
                optional={"value", "allowedValues"},
                context=assertion_context,
            )
            has_value = "value" in assertion
            has_allowed_values = "allowedValues" in assertion
            require(
                has_value != has_allowed_values,
                f"{assertion_context} must declare exactly one of value or allowedValues",
            )
            assertion_path = validate_rule_field_path(assertion["field"], axes, f"{assertion_context}.field")
            require(assertion_path not in asserted_paths, f"{item_context}.then asserts {assertion_path} more than once")
            asserted_paths.add(assertion_path)
            if has_value:
                validate_rule_expected_value(
                    assertion_path,
                    assertion["value"],
                    axes,
                    f"{assertion_context}.value",
                )
            else:
                allowed_values = require_list(
                    assertion["allowedValues"],
                    f"{assertion_context}.allowedValues",
                )
                require_unique(
                    allowed_values,
                    f"{assertion_context}.allowedValues",
                )
                for allowed_index, allowed_value in enumerate(allowed_values):
                    validate_rule_expected_value(
                        assertion_path,
                        allowed_value,
                        axes,
                        f"{assertion_context}.allowedValues[{allowed_index}]",
                    )

        require_present = require_list(rule["requirePresent"], f"{item_context}.requirePresent", allow_empty=True)
        require_absent = require_list(rule["requireAbsent"], f"{item_context}.requireAbsent", allow_empty=True)
        require_unique(require_present, f"{item_context}.requirePresent")
        require_unique(require_absent, f"{item_context}.requireAbsent")
        present_paths = {
            validate_rule_field_path(path, axes, f"{item_context}.requirePresent")
            for path in require_present
        }
        absent_paths = {
            validate_rule_field_path(path, axes, f"{item_context}.requireAbsent")
            for path in require_absent
        }
        require(not (present_paths & absent_paths), f"{item_context} requires the same field present and absent")
        required_involvement = require_list(
            rule.get("requireInvolvement", []),
            f"{item_context}.requireInvolvement",
            allow_empty=True,
        )
        required_assignments: set[tuple[str, str]] = set()
        for assignment_index, assignment in enumerate(required_involvement):
            assignment_context = (
                f"{item_context}.requireInvolvement[{assignment_index}]"
            )
            require(isinstance(assignment, dict), f"{assignment_context} must be an object")
            require_keys(
                assignment,
                required={"muscle", "role"},
                context=assignment_context,
            )
            muscle_id = assignment["muscle"]
            role = assignment["role"]
            require(
                muscle_id in foundation.muscle_by_id,
                f"{assignment_context} references unknown muscle {muscle_id}",
            )
            require(role in ROLES, f"{assignment_context} uses unknown role {role}")
            require(
                muscle_id in allowed_by_role[role],
                f"{assignment_context} requires disallowed {muscle_id} as {role}",
            )
            pair = (muscle_id, role)
            require(
                pair not in required_assignments,
                f"{item_context}.requireInvolvement repeats {muscle_id} as {role}",
            )
            required_assignments.add(pair)
        required_muscle_requirements = validate_muscle_requirements(
            rule.get("requireMuscleRequirements", []),
            foundation,
            allowed_by_role,
            f"{item_context}.requireMuscleRequirements",
            allow_empty=True,
        )
        required_additional_stability_demands = require_list(
            rule.get("requireAdditionalStabilityDemands", []),
            f"{item_context}.requireAdditionalStabilityDemands",
            allow_empty=True,
        )
        require_unique(
            required_additional_stability_demands,
            f"{item_context}.requireAdditionalStabilityDemands",
        )
        for region_index, region in enumerate(
            required_additional_stability_demands
        ):
            region_context = (
                f"{item_context}.requireAdditionalStabilityDemands[{region_index}]"
            )
            require(
                isinstance(region, str) and SYMBOL_ID.fullmatch(region) is not None,
                f"{region_context} is not a stable region ID: {region!r}",
            )
        unknown_regions = sorted(
            set(required_additional_stability_demands) - foundation.region_ids
        )
        require(
            not unknown_regions,
            f"{item_context}.requireAdditionalStabilityDemands references unknown stability "
            f"regions: {', '.join(unknown_regions)}",
        )
        require(
            assertions
            or present_paths
            or absent_paths
            or required_assignments
            or required_muscle_requirements
            or required_additional_stability_demands,
            f"{item_context} does not enforce anything",
        )
    return rules


def exercise_rule_field(exercise: dict[str, Any], field_path: str) -> Any:
    if "." not in field_path:
        return exercise.get(field_path, MISSING)
    _, axis_id = field_path.split(".", 1)
    return exercise.get("variant", {}).get(axis_id, MISSING)


def validate_exercise_rule_matches(
    exercise: dict[str, Any],
    rules: list[dict[str, Any]],
    context: str,
) -> None:
    role_by_muscle = {
        assignment["muscle"]: assignment["role"]
        for assignment in exercise["involvement"]
    }
    for rule in rules:
        predicate = rule["when"]
        actual = exercise_rule_field(exercise, predicate["field"])
        if actual is MISSING:
            matches = False
        elif predicate["operator"] == "equals":
            matches = actual == predicate["value"]
        else:
            matches = actual != predicate["value"]
        if not matches:
            continue

        for assertion in rule["then"]:
            asserted_value = exercise_rule_field(exercise, assertion["field"])
            if "value" in assertion:
                require(
                    asserted_value is not MISSING
                    and asserted_value == assertion["value"],
                    f"{context} violates exercise rule {rule['id']}: "
                    f"{assertion['field']} must equal {assertion['value']!r}",
                )
            else:
                allowed_values = assertion["allowedValues"]
                require(
                    asserted_value is not MISSING
                    and asserted_value in allowed_values,
                    f"{context} violates exercise rule {rule['id']}: "
                    f"{assertion['field']} must be one of {allowed_values!r}",
                )
        for field_path in rule["requirePresent"]:
            require(
                exercise_rule_field(exercise, field_path) is not MISSING,
                f"{context} violates exercise rule {rule['id']}: {field_path} must be present",
            )
        for field_path in rule["requireAbsent"]:
            require(
                exercise_rule_field(exercise, field_path) is MISSING,
                f"{context} violates exercise rule {rule['id']}: {field_path} must be absent",
            )
        for assignment in rule.get("requireInvolvement", []):
            muscle_id = assignment["muscle"]
            role = assignment["role"]
            require(
                role_by_muscle.get(muscle_id) == role,
                f"{context} violates exercise rule {rule['id']}: "
                f"{muscle_id} must be assigned as {role}",
            )
        for requirement in rule.get("requireMuscleRequirements", []):
            minimum_role = requirement["minimumRole"]
            minimum_rank = ROLE_RANK[minimum_role]
            candidates = requirement["anyOf"]
            satisfied = any(
                candidate in role_by_muscle
                and ROLE_RANK[role_by_muscle[candidate]] >= minimum_rank
                for candidate in candidates
            )
            require(
                satisfied,
                f"{context} violates exercise rule {rule['id']}: "
                f"one of {candidates!r} must be assigned as {minimum_role} or higher",
            )
        additional_stability_demands = set(
            exercise["additionalStabilityDemands"]
        )
        for region in rule.get("requireAdditionalStabilityDemands", []):
            require(
                region in additional_stability_demands,
                f"{context} violates exercise rule {rule['id']}: "
                f"{region} must be declared in additionalStabilityDemands",
            )


def validate_exercise(
    exercise: Any,
    *,
    index: int,
    family: dict[str, Any],
    foundation: Foundation,
    group_default: str,
    allowed_groups: set[str],
    requirements: list[dict[str, Any]],
    allowed_by_role: dict[str, set[str]],
    axes: dict[str, dict[str, Any]],
    exercise_rules: list[dict[str, Any]],
    family_prime_actions: frozenset[ActionRequirement],
    family_resisted_actions: frozenset[ActionRequirement],
    family_forbidden_prime_actions: frozenset[str],
    additional_prime_actions: frozenset[ActionRequirement],
) -> list[str]:
    context = f"family {family['id']} exercise[{index}]"
    require(isinstance(exercise, dict), f"{context} must be an object")
    required_keys = {
        "catalogID", "name", "aliases", "equipment", "laterality", "modality",
        "trackingMode", "loadMode", "bodyweightFraction", "defaultWeight", "reps",
        "involvement", "variant", "additionalPrimeActions", "additionalStabilityDemands",
        "evidenceRefs", "movementSteps",
    }
    optional_keys = {
        "groupOverride",
        "defaultWeightKg",
        "defaultDuration",
        "searchPriority",
    }
    require_keys(exercise, required=required_keys, optional=optional_keys, context=context)

    catalog_id = require_non_empty_string(exercise["catalogID"], f"{context}.catalogID")
    require(STABLE_ID.fullmatch(catalog_id) is not None, f"{context}.catalogID is invalid: {catalog_id}")
    require_non_empty_string(exercise["name"], f"{context}.name")
    aliases = require_list(exercise["aliases"], f"{context}.aliases", allow_empty=True)
    require_unique([normalized_name(alias) for alias in aliases], f"{context}.aliases")
    for alias in aliases:
        require_non_empty_string(alias, f"{context}.aliases entry")
        require(normalized_name(alias) != normalized_name(exercise["name"]), f"{context} alias duplicates its canonical name: {alias}")

    selected = {
        "equipment": exercise["equipment"],
        "modalities": exercise["modality"],
        "trackingModes": exercise["trackingMode"],
        "loadModes": exercise["loadMode"],
        "lateralities": exercise["laterality"],
    }
    for family_key, selected_value in selected.items():
        require(selected_value in family["allowed"][family_key], f"{context} selects disallowed {family_key}: {selected_value}")

    group = exercise.get("groupOverride", group_default)
    require(group in allowed_groups, f"{context} selects disallowed group: {group}")
    require(type(exercise["bodyweightFraction"]) in {int, float}, f"{context}.bodyweightFraction must be numeric")
    require(0 <= exercise["bodyweightFraction"] <= 1, f"{context}.bodyweightFraction must be in 0...1")
    require(type(exercise["defaultWeight"]) in {int, float} and exercise["defaultWeight"] >= 0, f"{context}.defaultWeight is invalid")
    require(type(exercise["reps"]) is int and exercise["reps"] > 0, f"{context}.reps must be a positive integer")
    if "searchPriority" in exercise:
        require(type(exercise["searchPriority"]) is int and 0 <= exercise["searchPriority"] <= 100, f"{context}.searchPriority is invalid")
    if "defaultWeightKg" in exercise:
        kilograms = exercise["defaultWeightKg"]
        require(type(kilograms) in {int, float} and kilograms > 0, f"{context}.defaultWeightKg must be positive")
        require(abs(round(kilograms / 2.5) - kilograms / 2.5) < 0.000_001, f"{context}.defaultWeightKg must use the 2.5 kg grid")

    load_mode = exercise["loadMode"]
    bodyweight_fraction = exercise["bodyweightFraction"]
    if exercise["defaultWeight"] > 0:
        require(
            "defaultWeightKg" in exercise,
            f"{context} positive defaultWeight requires defaultWeightKg",
        )
    if load_mode in {"external", "nonComparable"}:
        require(bodyweight_fraction == 0, f"{context} {load_mode} load must use zero bodyweightFraction")
    else:
        require(bodyweight_fraction > 0, f"{context} {load_mode} load requires positive bodyweightFraction")
    if exercise["equipment"] == "band":
        require(load_mode == "nonComparable", f"{context} band resistance must remain nonComparable")

    modality = exercise["modality"]
    tracking_mode = exercise["trackingMode"]
    if modality in {"dynamicStrength", "power"}:
        require(tracking_mode == "reps", f"{context} {modality} must use reps")
    if modality == "isometricStrength":
        require(tracking_mode == "duration", f"{context} isometricStrength must use duration")
    if tracking_mode == "duration":
        duration = exercise.get("defaultDuration")
        require(type(duration) in {int, float} and duration > 0, f"{context} duration tracking requires defaultDuration")

    involvement = require_list(exercise["involvement"], f"{context}.involvement")
    role_by_muscle: dict[str, str] = {}
    for contribution_index, contribution in enumerate(involvement):
        contribution_context = f"{context}.involvement[{contribution_index}]"
        require(isinstance(contribution, dict), f"{contribution_context} must be an object")
        require_keys(contribution, required={"muscle", "role"}, context=contribution_context)
        muscle_id = contribution["muscle"]
        role = contribution["role"]
        require(muscle_id in foundation.muscle_by_id, f"{contribution_context} references unknown muscle {muscle_id}")
        require(role in ROLES, f"{contribution_context} uses unknown role {role}")
        require(muscle_id not in role_by_muscle, f"{context} assigns {muscle_id} more than once")
        require(muscle_id in allowed_by_role[role], f"{context} does not allow {muscle_id} as {role}")
        role_by_muscle[muscle_id] = role

    requires_primary = modality in {"dynamicStrength", "isometricStrength", "power"}
    if requires_primary:
        require("primary" in role_by_muscle.values(), f"{context} requires at least one primary muscle")
        primary_groups = {
            foundation.muscle_by_id[muscle_id]["group"]
            for muscle_id, role in role_by_muscle.items()
            if role == "primary"
        }
        require(group in primary_groups, f"{context} group {group} has no matching primary muscle")

    for requirement_index, requirement in enumerate(requirements):
        minimum_rank = ROLE_RANK[requirement["minimumRole"]]
        satisfied = any(
            candidate in role_by_muscle and ROLE_RANK[role_by_muscle[candidate]] >= minimum_rank
            for candidate in requirement["anyOf"]
        )
        require(satisfied, f"{context} fails muscle requirement {requirement_index}")

    additional_actions = additional_prime_actions
    family_prime_action_ids = {
        action for action, _ in family_prime_actions
    }
    for action, _ in additional_actions:
        require(
            action not in family_prime_action_ids,
            f"{context} redeclares family prime action {action} in "
            "additionalPrimeActions",
        )
        require(
            action not in family_forbidden_prime_actions,
            f"{context} declares forbidden prime action {action}",
        )
    basis_region = family["movementSignature"]["planeBasisActions"][0].split(".", 1)[0]
    declared_planes = set(family["fixed"]["planes"])
    for action_requirement in additional_actions:
        action, _ = action_requirement
        if action.split(".", 1)[0] != basis_region:
            continue
        action_plane = foundation.plane_by_action[action]
        require(
            action_plane in declared_planes,
            f"{context} additional prime action "
            f"{action_requirement_label(action_requirement)} uses undeclared "
            f"{action_plane} plane at {basis_region}",
        )
    prime_actions = family_prime_actions | additional_actions
    resisted_actions = family_resisted_actions

    movers = {
        muscle_id
        for muscle_id, role in role_by_muscle.items()
        if role in {"primary", "secondary"}
    }
    for action_requirement in sorted(prime_actions, key=action_requirement_label):
        capable = [
            muscle_id
            for muscle_id in movers
            if any(
                capability_satisfies(capability, action_requirement)
                for capability in foundation.capabilities_by_muscle[muscle_id]
            )
        ]
        require(
            capable,
            f"{context} has no primary/secondary muscle capable of {action_requirement_label(action_requirement)}",
        )
    for resisted_requirement in sorted(
        resisted_actions,
        key=action_requirement_label,
    ):
        capable = [
            muscle_id
            for muscle_id in movers
            if any(
                capability_opposes(
                    capability,
                    resisted_requirement,
                    foundation.opposing_action_by_action,
                )
                for capability in foundation.capabilities_by_muscle[muscle_id]
            )
        ]
        resisted_action, _ = resisted_requirement
        opposing_action = foundation.opposing_action_by_action[resisted_action]
        require(
            capable,
            f"{context} has no primary/secondary muscle capable of opposing "
            f"{action_requirement_label(resisted_requirement)} with "
            f"{opposing_action}",
        )

    for muscle_id, role in role_by_muscle.items():
        if role not in {"primary", "secondary"}:
            continue
        capabilities = foundation.capabilities_by_muscle[muscle_id]
        require(
            any(
                capability_satisfies(capability, action_requirement)
                for capability in capabilities
                for action_requirement in prime_actions
            )
            or any(
                capability_opposes(
                    capability,
                    resisted_requirement,
                    foundation.opposing_action_by_action,
                )
                for capability in capabilities
                for resisted_requirement in resisted_actions
            ),
            f"{context} {role} muscle {muscle_id} cannot produce any declared "
            "prime action or oppose any declared resisted action",
        )

    additional_stability = require_list(
        exercise["additionalStabilityDemands"],
        f"{context}.additionalStabilityDemands",
        allow_empty=True,
    )
    require_unique(additional_stability, f"{context}.additionalStabilityDemands")
    unknown_regions = sorted(set(additional_stability) - foundation.region_ids)
    require(not unknown_regions, f"{context} references unknown stability regions: {', '.join(unknown_regions)}")
    stability_demands = set(family["movementSignature"]["stabilityDemands"]) | set(additional_stability)
    # Stability coverage is intentionally role-agnostic: a prime mover may
    # also control a declared joint without being duplicated as a stabilizer.
    for region in sorted(stability_demands):
        capable = [
            muscle_id
            for muscle_id in role_by_muscle
            if region in foundation.profile_by_muscle[muscle_id]["stabilizes"]
        ]
        require(capable, f"{context} has no assigned muscle capable of stabilizing {region}")

    for muscle_id, role in role_by_muscle.items():
        if role != "stabilizer":
            continue
        stabilized = set(foundation.profile_by_muscle[muscle_id]["stabilizes"])
        require(
            stabilized & stability_demands,
            f"{context} stabilizer muscle {muscle_id} cannot stabilize any declared demand",
        )

    validate_variant(exercise["variant"], axes, f"{context}.variant")
    validate_exercise_rule_matches(exercise, exercise_rules, context)
    require_known_evidence(exercise["evidenceRefs"], foundation, f"{context}.evidenceRefs")
    movement_steps = require_list(
        exercise["movementSteps"],
        f"{context}.movementSteps",
    )
    require(
        2 <= len(movement_steps) <= 10,
        f"{context}.movementSteps must contain 2...10 steps",
    )
    require_unique(movement_steps, f"{context}.movementSteps")
    for step_index, raw_step in enumerate(movement_steps):
        step_context = f"{context}.movementSteps[{step_index}]"
        step = require_non_empty_string(raw_step, step_context).strip()
        require(
            step == raw_step
            and
            len(step) >= 12
            and step[0].isupper()
            and step[-1] in ".!?",
            f"{step_context} is malformed",
        )
        words = re.findall(r"[a-z0-9]+", step.casefold())
        require(
            all(left != right for left, right in zip(words, words[1:])),
            f"{step_context} repeats an adjacent word",
        )

    warnings: list[str] = []
    recommended = family.get("recommended", {})
    if "defaultReps" in recommended:
        bounds = recommended["defaultReps"]
        if not bounds["minimum"] <= exercise["reps"] <= bounds["maximum"]:
            warnings.append(
                f"{catalog_id}: reps {exercise['reps']} is outside recommended "
                f"{bounds['minimum']}...{bounds['maximum']}"
            )
    if tracking_mode == "duration" and "defaultDuration" in recommended:
        bounds = recommended["defaultDuration"]
        duration = exercise["defaultDuration"]
        if not bounds["minimum"] <= duration <= bounds["maximum"]:
            warnings.append(
                f"{catalog_id}: duration {duration} is outside recommended "
                f"{bounds['minimum']}...{bounds['maximum']}"
            )
    return warnings


def validate_family(data: dict[str, Any], foundation: Foundation, source: str = "family") -> list[str]:
    context = source
    required_keys = {
        "schemaVersion", "id", "name", "definition", "evidenceRefs", "fixed",
        "groupPolicy", "allowed", "movementSignature", "musclePolicy", "variantAxes",
        "exerciseRules", "exercises",
    }
    require_keys(data, required=required_keys, optional={"$schema", "recommended"}, context=context)
    require_schema_version(data, context)
    if "$schema" in data:
        require_non_empty_string(data["$schema"], f"{context}.$schema")
    family_id = require_non_empty_string(data["id"], f"{context}.id")
    require(STABLE_ID.fullmatch(family_id) is not None, f"{context}.id is invalid: {family_id}")
    require_non_empty_string(data["name"], f"{context}.name")
    require_non_empty_string(data["definition"], f"{context}.definition")
    require_known_evidence(data["evidenceRefs"], foundation, f"{context}.evidenceRefs")
    validate_fixed_classification(data["fixed"], f"{context}.fixed")
    validate_allowed(data["allowed"], f"{context}.allowed")

    group_policy = data["groupPolicy"]
    require(isinstance(group_policy, dict), f"{context}.groupPolicy must be an object")
    require_keys(group_policy, required={"default", "allowed"}, context=f"{context}.groupPolicy")
    allowed_groups_list = require_list(group_policy["allowed"], f"{context}.groupPolicy.allowed")
    require_unique(allowed_groups_list, f"{context}.groupPolicy.allowed")
    allowed_groups = set(allowed_groups_list)
    require(allowed_groups <= set(EXPECTED_GROUPS), f"{context}.groupPolicy contains unknown groups")
    group_default = group_policy["default"]
    require(group_default in allowed_groups, f"{context}.groupPolicy.default must be allowed")

    signature = data["movementSignature"]
    require(isinstance(signature, dict), f"{context}.movementSignature must be an object")
    require_keys(
        signature,
        required={"planeBasisActions", "primeActions", "stabilityDemands"},
        optional={
            "forbiddenPrimeActions",
            "resistedActions",
        },
        context=f"{context}.movementSignature",
    )
    prime_actions = validate_action_requirements(
        signature["primeActions"],
        action_ids=foundation.action_ids,
        condition_actions=foundation.condition_actions,
        context=f"{context}.movementSignature.primeActions",
        allow_empty=True,
    )
    if "resistedActions" in signature:
        resisted_actions = validate_action_requirements(
            signature["resistedActions"],
            action_ids=foundation.action_ids,
            condition_actions=foundation.condition_actions,
            context=f"{context}.movementSignature.resistedActions",
        )
    else:
        resisted_actions = frozenset()
    require(
        prime_actions or resisted_actions,
        f"{context}.movementSignature requires at least one prime or resisted action",
    )
    forbidden_prime_actions = require_list(
        signature.get("forbiddenPrimeActions", []),
        f"{context}.movementSignature.forbiddenPrimeActions",
        allow_empty=True,
    )
    require_unique(
        forbidden_prime_actions,
        f"{context}.movementSignature.forbiddenPrimeActions",
    )
    for index, action in enumerate(forbidden_prime_actions):
        action_id = require_non_empty_string(
            action,
            f"{context}.movementSignature.forbiddenPrimeActions[{index}]",
        )
        require(
            action_id in foundation.action_ids,
            f"{context} references unknown forbidden prime action {action_id}",
        )
    forbidden_prime_action_ids = frozenset(forbidden_prime_actions)
    declared_prime_action_ids = {action for action, _ in prime_actions}
    declared_resisted_action_ids = {action for action, _ in resisted_actions}
    action_mode_conflicts = sorted(
        declared_prime_action_ids & declared_resisted_action_ids
    )
    require(
        not action_mode_conflicts,
        f"{context} both declares prime and resisted actions: "
        + ", ".join(action_mode_conflicts),
    )
    conflicts = sorted(declared_prime_action_ids & forbidden_prime_action_ids)
    require(
        not conflicts,
        f"{context} both declares and forbids prime actions: {', '.join(conflicts)}",
    )
    exercises = require_list(data["exercises"], f"{context}.exercises")
    roster_additional_prime_actions: set[ActionRequirement] = set()
    additional_prime_actions_by_exercise: list[frozenset[ActionRequirement]] = []
    for exercise_index, exercise in enumerate(exercises):
        exercise_context = f"family {family_id} exercise[{exercise_index}]"
        require(isinstance(exercise, dict), f"{exercise_context} must be an object")
        additional_prime_actions = validate_action_requirements(
            exercise.get("additionalPrimeActions", []),
            action_ids=foundation.action_ids,
            condition_actions=foundation.condition_actions,
            context=f"{exercise_context}.additionalPrimeActions",
            allow_empty=True,
        )
        additional_prime_actions_by_exercise.append(additional_prime_actions)
        roster_additional_prime_actions.update(additional_prime_actions)
    roster_prime_actions = prime_actions | frozenset(
        roster_additional_prime_actions
    )
    roster_prime_action_ids = {action for action, _ in roster_prime_actions}
    roster_resisted_action_ids = {action for action, _ in resisted_actions}
    roster_action_mode_conflicts = sorted(
        roster_prime_action_ids & roster_resisted_action_ids
    )
    require(
        not roster_action_mode_conflicts,
        f"{context} family roster declares actions as both prime and resisted: "
        + ", ".join(roster_action_mode_conflicts),
    )
    plane_basis_values = require_list(
        signature["planeBasisActions"],
        f"{context}.movementSignature.planeBasisActions",
    )
    require_unique(plane_basis_values, f"{context}.movementSignature.planeBasisActions")
    require(
        len(plane_basis_values) <= 3,
        f"{context}.movementSignature.planeBasisActions accepts at most three component actions",
    )
    plane_basis_actions: list[str] = []
    reviewed_family_action_ids = (
        declared_prime_action_ids | declared_resisted_action_ids
    )
    for index, value in enumerate(plane_basis_values):
        plane_basis_action = require_non_empty_string(
            value,
            f"{context}.movementSignature.planeBasisActions[{index}]",
        )
        require(
            plane_basis_action in foundation.action_ids,
            f"{context} references unknown plane-basis action {plane_basis_action}",
        )
        require(
            plane_basis_action in reviewed_family_action_ids,
            f"{context} plane-basis action {plane_basis_action} must also be a "
            "family prime or resisted action",
        )
        plane_basis_actions.append(plane_basis_action)

    basis_planes = {foundation.plane_by_action[action] for action in plane_basis_actions}
    basis_regions = {action.split(".", 1)[0] for action in plane_basis_actions}
    if len(plane_basis_actions) > 1:
        require(
            len(basis_regions) == 1,
            f"{context} multi-plane basis actions must belong to the same joint region",
        )
        require(
            len(basis_planes) == len(plane_basis_actions),
            f"{context} each plane-basis action must represent a distinct cardinal plane",
        )

    basis_description = ", ".join(plane_basis_actions)
    declared_planes = set(data["fixed"]["planes"])
    require(
        declared_planes == basis_planes,
        f"{context} planes {', '.join(sorted(declared_planes))} conflict with "
        f"plane-basis actions {basis_description} ({', '.join(sorted(basis_planes))})",
    )
    basis_region = next(iter(basis_regions))
    for action_requirement in prime_actions | resisted_actions:
        action, _ = action_requirement
        if action.split(".", 1)[0] != basis_region:
            continue
        action_plane = foundation.plane_by_action[action]
        action_kind = (
            "prime action"
            if action_requirement in prime_actions
            else "resisted action"
        )
        require(
            action_plane in declared_planes,
            f"{context} {action_kind} "
            f"{action_requirement_label(action_requirement)} "
            f"uses undeclared {action_plane} plane at {basis_region}",
        )
    stability = require_list(signature["stabilityDemands"], f"{context}.movementSignature.stabilityDemands", allow_empty=True)
    require_unique(stability, f"{context}.movementSignature.stabilityDemands")
    unknown_regions = sorted(set(stability) - foundation.region_ids)
    require(not unknown_regions, f"{context} references unknown stability regions: {', '.join(unknown_regions)}")
    resisted_regions = {
        action.split(".", 1)[0]
        for action, _ in resisted_actions
    }
    missing_resisted_regions = sorted(resisted_regions - set(stability))
    require(
        not missing_resisted_regions,
        f"{context} family resisted actions require matching stability demands: "
        + ", ".join(missing_resisted_regions),
    )

    requirements, allowed_by_role = validate_role_policy(data["musclePolicy"], foundation, f"{context}.musclePolicy")
    axes = validate_variant_axes(data["variantAxes"], f"{context}.variantAxes")
    used_conditions = {
        condition
        for _, condition in roster_prime_actions | resisted_actions
        if condition is not None
    }
    for condition_id in sorted(used_conditions):
        constraint = foundation.condition_variant_constraints.get(condition_id)
        if constraint is None:
            continue
        axis_id, expected = constraint
        require(
            axis_id in axes,
            f"{context} action condition {condition_id} requires variant axis {axis_id}",
        )
        axis = axes[axis_id]
        require(
            axis["required"],
            f"{context} action condition {condition_id} requires {axis_id} to be required",
        )
        if axis["valueType"] == "number":
            require(
                type(expected) in {int, float}
                and axis.get("minimum") == expected
                and axis.get("maximum") == expected,
                f"{context} action condition {condition_id} requires numeric axis "
                f"{axis_id} pinned to {expected!r}",
            )
        elif axis["valueType"] == "enum":
            require(
                type(expected) is str and axis.get("allowedValues") == [expected],
                f"{context} action condition {condition_id} requires enum axis "
                f"{axis_id} pinned to {expected!r}",
            )
        elif axis["valueType"] == "boolean":
            require(
                type(expected) is bool and axis.get("fixedValue") is expected,
                f"{context} action condition {condition_id} requires boolean axis "
                f"{axis_id} pinned to {expected!r}",
            )
        else:
            fail(
                f"{context} action condition {condition_id} cannot be pinned by "
                f"string axis {axis_id}"
            )
        for exercise_index, exercise in enumerate(exercises):
            require(
                exercise.get("variant", {}).get(axis_id) == expected,
                f"family {family_id} exercise[{exercise_index}] action condition "
                f"{condition_id} requires variant.{axis_id} == {expected!r}",
            )
    exercise_rules = validate_exercise_rules(
        data["exerciseRules"],
        axes,
        foundation,
        allowed_by_role,
        f"{context}.exerciseRules",
    )
    if "recommended" in data:
        validate_recommended(data["recommended"], f"{context}.recommended")

    warnings: list[str] = []
    catalog_ids: set[str] = set()
    canonical_names: set[str] = set()
    aliases: set[str] = set()
    for index, exercise in enumerate(exercises):
        warnings.extend(
            validate_exercise(
                exercise,
                index=index,
                family=data,
                foundation=foundation,
                group_default=group_default,
                allowed_groups=allowed_groups,
                requirements=requirements,
                allowed_by_role=allowed_by_role,
                axes=axes,
                exercise_rules=exercise_rules,
                family_prime_actions=prime_actions,
                family_resisted_actions=resisted_actions,
                family_forbidden_prime_actions=forbidden_prime_action_ids,
                additional_prime_actions=additional_prime_actions_by_exercise[index],
            )
        )
        catalog_id = exercise["catalogID"]
        name = normalized_name(exercise["name"])
        require(catalog_id not in catalog_ids, f"{context} duplicates catalogID {catalog_id}")
        require(name not in canonical_names, f"{context} duplicates exercise name {exercise['name']}")
        catalog_ids.add(catalog_id)
        canonical_names.add(name)

    for exercise in exercises:
        for alias in exercise["aliases"]:
            normalized = normalized_name(alias)
            require(normalized not in canonical_names, f"{context} alias conflicts with an exercise name: {alias}")
            require(normalized not in aliases, f"{context} duplicates alias: {alias}")
            aliases.add(normalized)

    return warnings


def validate_evidence_coverage(
    foundation: Foundation,
    families: Iterable[dict[str, Any]],
) -> None:
    referenced = {
        evidence_id
        for profile in foundation.profile_by_muscle.values()
        for evidence_id in profile["evidenceRefs"]
    }
    for family in families:
        referenced.update(family["evidenceRefs"])
        for exercise in family["exercises"]:
            referenced.update(exercise["evidenceRefs"])

    unused = sorted(foundation.evidence_ids - referenced)
    require(
        not unused,
        f"evidence registry contains sources unused by anatomy or real families: {', '.join(unused)}",
    )


def validate_family_set(families: Iterable[dict[str, Any]]) -> None:
    family_values = list(families)
    family_ids: set[str] = set()
    catalog_ids: set[str] = set()
    canonical_names: dict[str, str] = {}

    for family in family_values:
        family_id = family["id"]
        require(family_id not in family_ids, f"family set duplicates family ID {family_id}")
        family_ids.add(family_id)
        for exercise in family["exercises"]:
            catalog_id = exercise["catalogID"]
            require(catalog_id not in catalog_ids, f"family set duplicates catalogID {catalog_id}")
            catalog_ids.add(catalog_id)
            normalized = normalized_name(exercise["name"])
            require(
                normalized not in canonical_names,
                f"family set duplicates exercise name {exercise['name']}",
            )
            canonical_names[normalized] = exercise["name"]

    aliases: dict[str, str] = {}
    for family in family_values:
        for exercise in family["exercises"]:
            for alias in exercise["aliases"]:
                normalized = normalized_name(alias)
                require(
                    normalized not in canonical_names,
                    f"family-set alias conflicts with exercise name: {alias}",
                )
                require(
                    normalized not in aliases,
                    f"family set duplicates alias: {alias}",
                )
                aliases[normalized] = alias


def canonical_foundation_digest(foundation: Foundation) -> str:
    payload = {
        "taxonomy": foundation.taxonomy,
        "jointActions": foundation.joint_actions,
        "evidence": foundation.evidence,
        "familySchema": foundation.family_schema,
    }
    encoded = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def compile_runtime_catalog(families: Iterable[dict[str, Any]]) -> list[dict[str, Any]]:
    """Project validated family sources into the app's runtime catalog shape.

    The compiler consumes only canonical family contracts.
    Family file order is deterministic and exercise order remains authored.
    """
    records: list[dict[str, Any]] = []
    canonical_planes = ("sagittal", "frontal", "transverse")
    for family in sorted(families, key=lambda value: value["id"]):
        fixed = family["fixed"]
        group_default = family["groupPolicy"]["default"]
        for exercise in family["exercises"]:
            record: dict[str, Any] = {
                "familyID": family["id"],
                "catalogID": exercise["catalogID"],
                "name": exercise["name"],
                "group": exercise.get("groupOverride", group_default),
                "defaultWeight": exercise["defaultWeight"],
            }
            if "defaultWeightKg" in exercise:
                record["defaultWeightKg"] = exercise["defaultWeightKg"]
            record.update(
                {
                    "reps": exercise["reps"],
                    "trackingMode": exercise["trackingMode"],
                }
            )
            if "defaultDuration" in exercise:
                record["defaultDuration"] = exercise["defaultDuration"]
            record.update(
                {
                    "equipment": exercise["equipment"],
                    "mechanic": fixed["mechanic"],
                    "pattern": fixed["pattern"],
                    "direction": fixed["direction"],
                    "planes": [
                        plane for plane in canonical_planes if plane in fixed["planes"]
                    ],
                    "laterality": exercise["laterality"],
                    "aliases": exercise["aliases"],
                }
            )
            if "searchPriority" in exercise:
                record["searchPriority"] = exercise["searchPriority"]
            record.update(
                {
                    "bodyweightFraction": exercise["bodyweightFraction"],
                    "modality": exercise["modality"],
                    "loadMode": exercise["loadMode"],
                    "movementSteps": exercise["movementSteps"],
                    "involvement": exercise["involvement"],
                }
            )
            records.append(record)
    return records


def encoded_runtime_catalog(records: Iterable[dict[str, Any]]) -> str:
    return json.dumps(
        list(records),
        ensure_ascii=False,
        indent=2,
    ) + "\n"


def write_text_atomically(path: Path, contents: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=path.parent,
            prefix=f".{path.name}.",
            suffix=".tmp",
            delete=False,
        ) as temporary:
            temporary.write(contents)
            temporary_path = Path(temporary.name)
        temporary_path.chmod(0o644)
        temporary_path.replace(path)
        temporary_path = None
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


def write_runtime_catalog_atomically(contents: str) -> None:
    write_text_atomically(RUNTIME_CATALOG_PATH, contents)


def discovered_family_paths() -> list[Path]:
    return sorted(FAMILIES_ROOT.glob("*.json"))


def encoded_xcode_input_file_list(family_paths: Iterable[Path]) -> str:
    paths = [
        ROOT / "Scripts" / "catalog.py",
        TAXONOMY_PATH,
        JOINT_ACTIONS_PATH,
        EVIDENCE_PATH,
        FAMILY_SCHEMA_PATH,
        FAMILY_FIXTURE_PATH,
        *family_paths,
        BODY_MODEL_PATH,
        CANONICAL_RUNTIME_CATALOG_PATH,
    ]
    return "".join(
        f"$(SRCROOT)/{path.relative_to(ROOT)}\n"
        for path in paths
    )


def validate_xcode_input_file_list(family_paths: Iterable[Path]) -> None:
    require(
        XCODE_INPUT_FILE_LIST_PATH.exists(),
        "Xcode catalog sandbox allowlist is missing",
    )
    require(
        XCODE_INPUT_FILE_LIST_PATH.read_text(encoding="utf-8")
        == encoded_xcode_input_file_list(family_paths),
        "Xcode catalog sandbox allowlist differs from compiler inputs; "
        "run --emit-runtime",
    )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate and compile the canonical family-first exercise catalog."
    )
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        "--check",
        action="store_true",
        help="Validate sources and fail if the bundled runtime output is stale.",
    )
    mode.add_argument(
        "--emit-runtime",
        action="store_true",
        help="Write the deterministic app runtime catalog after validation.",
    )
    parser.add_argument(
        "--family",
        action="append",
        type=Path,
        default=[],
        help="Also validate an explicit family JSON file.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        foundation = validate_foundation()
        discovered_paths = discovered_family_paths()
        if args.check:
            validate_xcode_input_file_list(discovered_paths)
        discovered_resolved = {path.resolve() for path in discovered_paths}
        family_paths = [FAMILY_FIXTURE_PATH, *discovered_paths, *args.family]
        warnings: list[str] = []
        real_families: list[dict[str, Any]] = []
        runtime_families: list[dict[str, Any]] = []
        validated_paths: set[Path] = set()
        for path in family_paths:
            resolved = path if path.is_absolute() else ROOT / path
            resolved = resolved.resolve()
            if resolved in validated_paths:
                continue
            validated_paths.add(resolved)
            family = load_json(resolved)
            context = display_path(resolved)
            warnings.extend(validate_family(family, foundation, context))
            if resolved != FAMILY_FIXTURE_PATH.resolve():
                real_families.append(family)
            if resolved in discovered_resolved:
                runtime_families.append(family)

        validate_family_set(real_families)
        validate_evidence_coverage(foundation, real_families)

        runtime_catalog = encoded_runtime_catalog(
            compile_runtime_catalog(runtime_families)
        )
        if args.emit_runtime:
            write_runtime_catalog_atomically(runtime_catalog)
            write_text_atomically(
                XCODE_INPUT_FILE_LIST_PATH,
                encoded_xcode_input_file_list(discovered_paths),
            )
        elif args.check:
            require(
                RUNTIME_CATALOG_PATH.exists(),
                "bundled runtime catalog is missing",
            )
            require(
                RUNTIME_CATALOG_PATH.read_text(encoding="utf-8") == runtime_catalog,
                "bundled runtime catalog differs from catalog compiler output",
            )

        digest = canonical_foundation_digest(foundation)
        print(
            "catalog foundation valid: "
            f"{len(foundation.muscle_by_id)} muscles, "
            f"{foundation.mesh_base_count} mesh bases, "
            f"{len(foundation.action_ids)} joint actions, "
            f"{len(foundation.evidence_ids)} evidence sources, "
            f"{len(validated_paths)} family contract(s), "
            f"digest {digest[:12]}"
        )
        for warning in warnings:
            print(f"warning: {warning}")
        return 0
    except ValidationFailure as error:
        print(f"catalog validation failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
