"""Runtime movement metadata must preserve authored action kinds and families."""

import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import catalog


class MovementProjectionTests(unittest.TestCase):
    def test_projects_every_action_kind_without_forbidden_or_stability_actions(self):
        families = [json.loads(path.read_text()) for path in catalog.FAMILIES_ROOT.glob("*.json")]
        records = catalog.compile_runtime_catalog(families)
        by_family = {record["familyID"]: record for record in records}
        for family in families:
            record = by_family[family["id"]]
            self.assertEqual(record["familyName"], family["name"])
            signature = family["movementSignature"]
            expected = set()
            for source in [signature, *signature.get("movementPhases", [])]:
                for field, kind in [("primeActions", "produced"), ("resistedActions", "resisted"),
                                    ("yieldingActions", "yielding")]:
                    for action in source.get(field, []):
                        expected.add((action if isinstance(action, str) else action["action"], kind))
            actual = {(a["actionID"], a["kind"]) for a in record["movementActions"]}
            self.assertEqual(actual, expected, family["id"])
            self.assertEqual(len(actual), len(record["movementActions"]))
        carry = by_family["suitcase-carry"]["movementActions"]
        self.assertTrue(all(action["kind"] == "resisted" for action in carry))
        phases = by_family["glute-ham-raise"]["movementActions"]
        self.assertEqual({a["kind"] for a in phases}, {"produced", "yielding"})

    def test_names_and_planes_come_from_joint_action_taxonomy(self):
        actions = {a["id"]: a for a in json.loads(catalog.JOINT_ACTIONS_PATH.read_text())["actions"]}
        family = json.loads((catalog.FAMILIES_ROOT / "vertical-pull.json").read_text())
        projected = catalog.runtime_movement_actions(family, actions)
        for action in projected:
            authored = actions[action["actionID"]]
            self.assertEqual(action["name"], authored["displayName"])
            self.assertEqual(action["plane"], authored["plane"])
