#!/usr/bin/env python3
#
#  test_verify_scenario.py
#  vivobody
#
#  Unit tests for semantic scenario selection, on-screen filtering, constraint
#  diagnostics, and frame-based tap resolution. These tests use tiny fixture
#  trees and require neither Baguette nor a booted simulator.
#

from __future__ import annotations

import sys
import unittest
from pathlib import Path


SCRIPTS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_ROOT))

import verify_scenario  # noqa: E402


def element(
    *,
    identifier: str | None = None,
    label: str | None = None,
    role: str = "AXButton",
    value: str | None = None,
    frame: tuple[float, float, float, float] = (10, 10, 100, 44),
    enabled: bool = True,
    hidden: bool = False,
) -> dict[str, object]:
    x, y, width, height = frame
    return {
        "children": [],
        "enabled": enabled,
        "hidden": hidden,
        "identifier": identifier,
        "label": label,
        "role": role,
        "value": value,
        "frame": {"x": x, "y": y, "width": width, "height": height},
    }


def tree(*children: dict[str, object]) -> dict[str, object]:
    return {
        "children": list(children),
        "enabled": True,
        "hidden": False,
        "identifier": None,
        "label": "vivobody",
        "role": "AXApplication",
        "value": None,
        "frame": {"x": 0, "y": 0, "width": 402, "height": 874},
    }


class VerifyScenarioTests(unittest.TestCase):
    def test_matches_nested_semantics(self) -> None:
        button = element(
            identifier="completeSetButton",
            label="8 reps at 135 pounds",
            value="not completed",
        )
        group = element(role="AXGroup")
        group["children"] = [button]
        snapshot = tree(group)

        matches = verify_scenario.find_matches(snapshot, {
            "identifier": "completeSetButton",
            "role": "AXButton",
            "value": "not completed",
        })

        self.assertEqual(len(matches), 1)
        self.assertIs(matches[0].node, button)

    def test_contains_and_regex_match_dynamic_values(self) -> None:
        snapshot = tree(element(
            identifier="restTimerOverlay",
            label="Rest timer",
            role="AXGroup",
            value="89 seconds remaining of 1:30",
        ))

        matches = verify_scenario.find_matches(snapshot, {
            "labelContains": "Rest",
            "valueRegex": r"^[0-9]+ seconds remaining",
        })

        self.assertEqual(len(matches), 1)

    def test_offscreen_and_hidden_elements_are_not_visible_by_default(self) -> None:
        snapshot = tree(
            element(identifier="offscreen", frame=(500, 10, 100, 44)),
            element(identifier="hidden", hidden=True),
            element(identifier="onscreen"),
        )

        self.assertFalse(verify_scenario.find_matches(snapshot, {"identifier": "offscreen"}))
        self.assertFalse(verify_scenario.find_matches(snapshot, {"identifier": "hidden"}))
        self.assertEqual(
            len(verify_scenario.find_matches(snapshot, {"identifier": "onscreen"})),
            1,
        )

    def test_midpoint_uses_visible_intersection(self) -> None:
        partially_visible = element(frame=(380, 850, 100, 100))
        snapshot = tree(partially_visible)

        point = verify_scenario.element_midpoint(partially_visible, snapshot)

        self.assertEqual(point, (391, 862))

    def test_swipe_points_scale_with_the_application_frame(self) -> None:
        snapshot = tree()

        upward = verify_scenario.swipe_points(snapshot, "up")
        downward = verify_scenario.swipe_points(snapshot, "down")

        self.assertEqual(upward, (201, 594.32, 201, 279.68, 402, 874))
        self.assertEqual(downward, (201, 279.68, 201, 594.32, 402, 874))

    def test_ambiguous_tap_selector_fails_with_candidates(self) -> None:
        snapshot = tree(
            element(identifier="row", label="One"),
            element(identifier="row", label="Two", frame=(10, 80, 100, 44)),
        )
        matches = verify_scenario.find_matches(snapshot, {"identifier": "row"})

        with self.assertRaisesRegex(verify_scenario.ScenarioFailure, "matched 2 visible elements"):
            verify_scenario.choose_unique(matches, {"identifier": "row"})

    def test_required_and_forbidden_constraints_report_both_failures(self) -> None:
        snapshot = tree(element(identifier="activeWorkoutMiniBar"))

        failures = verify_scenario.constraint_failures(
            snapshot,
            required=[{"identifier": "historySessionRow"}],
            forbidden=[{"identifier": "activeWorkoutMiniBar"}],
        )

        self.assertEqual(len(failures), 2)
        self.assertIn("missing required", failures[0])
        self.assertIn("found forbidden", failures[1])

    def test_invalid_selector_fields_and_regexes_fail_early(self) -> None:
        with self.assertRaisesRegex(verify_scenario.ScenarioFailure, "Unsupported"):
            verify_scenario.validate_selector({"testID": "button"})
        with self.assertRaisesRegex(verify_scenario.ScenarioFailure, "Invalid regex"):
            verify_scenario.validate_selector({"labelRegex": "["})

    def test_runtime_log_constraints_report_missing_and_forbidden_events(self) -> None:
        failures = verify_scenario.log_constraint_failures(
            "event=session.transition kind=start outcome=success",
            required=["event=incoming_action.received kind=start_today"],
            forbidden=["event=session.transition kind=start outcome=success"],
        )

        self.assertEqual(len(failures), 2)
        self.assertIn("missing required log", failures[0])
        self.assertIn("found forbidden log", failures[1])

    def test_runtime_log_fields_require_non_empty_strings(self) -> None:
        scenario = {
            "name": "invalid-logs",
            "launch": {},
            "steps": [],
            "required": [],
            "forbidden": [],
            "requiredLogs": [""],
        }

        with self.assertRaisesRegex(verify_scenario.ScenarioFailure, "non-empty strings"):
            verify_scenario.validate_scenario_definition(scenario)

    def test_every_checked_in_scenario_is_valid(self) -> None:
        paths = sorted(verify_scenario.DEFAULT_SCENARIOS_DIR.glob("*.json"))
        self.assertGreater(len(paths), 0)
        for path in paths:
            with self.subTest(scenario=path.stem):
                loaded = verify_scenario.load_scenario(
                    path.stem,
                    verify_scenario.DEFAULT_SCENARIOS_DIR,
                )
                self.assertEqual(loaded["name"], path.stem)


if __name__ == "__main__":
    unittest.main()
