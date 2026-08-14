#!/usr/bin/env python3
#
#  verify_scenario.py
#  vivobody
#
#  Drives deterministic Baguette verification scenarios from declarative JSON.
#  Elements are selected through accessibility semantics and tapped at the
#  visible midpoint of their reported frame, so flows never depend on recorded
#  screen coordinates. Every run leaves a screenshot, UI tree, action trace,
#  runtime log, and machine-readable result in its scenario artifact folder.
#

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Iterable, Mapping, Sequence


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SCENARIOS_DIR = ROOT / "Scripts" / "verify_scenarios"
DEFAULT_TIMEOUT = 15.0
POLL_INTERVAL = 0.25

EXACT_SELECTOR_FIELDS = ("identifier", "label", "role", "value")
TEXT_SELECTOR_FIELDS = ("identifier", "label", "value")
SUPPORTED_SELECTOR_FIELDS = {
    *EXACT_SELECTOR_FIELDS,
    *(f"{field}Contains" for field in TEXT_SELECTOR_FIELDS),
    *(f"{field}Regex" for field in TEXT_SELECTOR_FIELDS),
    "enabled",
    "visible",
}


class ScenarioFailure(RuntimeError):
    """Expected scenario failure with a concise, actionable diagnostic."""


@dataclass(frozen=True)
class Match:
    node: Mapping[str, Any]
    path: str


def _number(value: Any) -> float | None:
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return float(value)
    return None


def node_frame(node: Mapping[str, Any]) -> tuple[float, float, float, float] | None:
    frame = node.get("frame")
    if not isinstance(frame, Mapping):
        return None
    values = tuple(_number(frame.get(key)) for key in ("x", "y", "width", "height"))
    if any(value is None for value in values):
        return None
    x, y, width, height = values
    assert x is not None and y is not None and width is not None and height is not None
    return x, y, width, height


def visible_intersection(
    node: Mapping[str, Any],
    root: Mapping[str, Any],
) -> tuple[float, float, float, float] | None:
    if node.get("hidden") is True:
        return None
    frame = node_frame(node)
    root_frame = node_frame(root)
    if frame is None or root_frame is None:
        return None
    x, y, width, height = frame
    root_x, root_y, root_width, root_height = root_frame
    if width <= 0 or height <= 0 or root_width <= 0 or root_height <= 0:
        return None
    left = max(x, root_x)
    top = max(y, root_y)
    right = min(x + width, root_x + root_width)
    bottom = min(y + height, root_y + root_height)
    if right <= left or bottom <= top:
        return None
    return left, top, right - left, bottom - top


def element_midpoint(
    node: Mapping[str, Any],
    root: Mapping[str, Any],
) -> tuple[float, float]:
    intersection = visible_intersection(node, root)
    if intersection is None:
        raise ScenarioFailure("Cannot tap an element without a visible on-screen frame.")
    x, y, width, height = intersection
    return x + width / 2, y + height / 2


def swipe_points(
    root: Mapping[str, Any],
    direction: str,
) -> tuple[float, float, float, float, float, float]:
    root_frame = node_frame(root)
    if root_frame is None:
        raise ScenarioFailure("Application accessibility root has no usable frame.")
    x, y, width, height = root_frame
    if direction == "up":
        return (
            x + width * 0.5,
            y + height * 0.68,
            x + width * 0.5,
            y + height * 0.32,
            width,
            height,
        )
    if direction == "down":
        return (
            x + width * 0.5,
            y + height * 0.32,
            x + width * 0.5,
            y + height * 0.68,
            width,
            height,
        )
    raise ScenarioFailure("scrollTo.direction must be 'up' or 'down'.")


def walk_nodes(node: Mapping[str, Any], path: str = "root") -> Iterable[Match]:
    yield Match(node=node, path=path)
    children = node.get("children", [])
    if not isinstance(children, list):
        return
    for index, child in enumerate(children):
        if isinstance(child, Mapping):
            yield from walk_nodes(child, f"{path}.children[{index}]")


def validate_selector(selector: Mapping[str, Any]) -> None:
    unknown = set(selector) - SUPPORTED_SELECTOR_FIELDS
    if unknown:
        names = ", ".join(sorted(unknown))
        raise ScenarioFailure(f"Unsupported selector field(s): {names}")
    if not selector or set(selector).issubset({"visible", "enabled"}):
        raise ScenarioFailure("A selector must include an identifier, label, role, or value matcher.")
    for key, value in selector.items():
        if key in {"visible", "enabled"}:
            if not isinstance(value, bool):
                raise ScenarioFailure(f"Selector field {key!r} must be a boolean.")
        elif not isinstance(value, str):
            raise ScenarioFailure(f"Selector field {key!r} must be a string.")
        elif key.endswith("Regex"):
            try:
                re.compile(value)
            except re.error as error:
                raise ScenarioFailure(f"Invalid regex in {key!r}: {error}") from error


def selector_matches(
    node: Mapping[str, Any],
    selector: Mapping[str, Any],
    root: Mapping[str, Any],
) -> bool:
    validate_selector(selector)
    visible = visible_intersection(node, root) is not None
    if selector.get("visible", True) != visible:
        return False
    if "enabled" in selector and node.get("enabled") is not selector["enabled"]:
        return False

    for field in EXACT_SELECTOR_FIELDS:
        if field in selector and node.get(field) != selector[field]:
            return False
    for field in TEXT_SELECTOR_FIELDS:
        actual = node.get(field)
        contains_key = f"{field}Contains"
        regex_key = f"{field}Regex"
        if contains_key in selector:
            if actual is None or selector[contains_key] not in str(actual):
                return False
        if regex_key in selector:
            if actual is None or re.search(selector[regex_key], str(actual)) is None:
                return False
    return True


def find_matches(
    tree: Mapping[str, Any],
    selector: Mapping[str, Any],
) -> list[Match]:
    return [
        match
        for match in walk_nodes(tree)
        if selector_matches(match.node, selector, tree)
    ]


def describe_node(match: Match) -> str:
    node = match.node
    fields = []
    for key in ("identifier", "label", "role", "value"):
        value = node.get(key)
        if value is not None:
            fields.append(f"{key}={value!r}")
    frame = node_frame(node)
    if frame is not None:
        fields.append(f"frame={frame}")
    return f"{match.path} ({', '.join(fields)})"


def choose_unique(matches: Sequence[Match], selector: Mapping[str, Any]) -> Match:
    if len(matches) == 1:
        return matches[0]
    rendered = json.dumps(selector, sort_keys=True)
    if not matches:
        raise ScenarioFailure(f"No visible element matched selector {rendered}.")
    candidates = "\n".join(f"  - {describe_node(match)}" for match in matches[:8])
    raise ScenarioFailure(
        f"Selector {rendered} matched {len(matches)} visible elements; taps must be unique:\n{candidates}"
    )


def constraint_failures(
    tree: Mapping[str, Any],
    required: Sequence[Mapping[str, Any]],
    forbidden: Sequence[Mapping[str, Any]],
) -> list[str]:
    failures: list[str] = []
    for selector in required:
        if not find_matches(tree, selector):
            failures.append(f"missing required {json.dumps(selector, sort_keys=True)}")
    for selector in forbidden:
        matches = find_matches(tree, selector)
        if matches:
            failures.append(
                f"found forbidden {json.dumps(selector, sort_keys=True)}: "
                f"{describe_node(matches[0])}"
            )
    return failures


def log_constraint_failures(
    source: str,
    required: Sequence[str],
    forbidden: Sequence[str],
) -> list[str]:
    failures = [f"missing required log {value!r}" for value in required if value not in source]
    failures.extend(
        f"found forbidden log {value!r}"
        for value in forbidden
        if value in source
    )
    return failures


class ScenarioRunner:
    def __init__(
        self,
        *,
        scenario: Mapping[str, Any],
        udid: str,
        bundle_id: str,
        output_dir: Path,
        baguette: str,
        timeout: float,
    ) -> None:
        self.scenario = scenario
        self.udid = udid
        self.bundle_id = bundle_id
        self.output_dir = output_dir
        self.baguette = baguette
        self.timeout = timeout
        self.current_tree_path = output_dir / "current-ui.json"
        self.actions_path = output_dir / "actions.log"
        self.runtime_path = output_dir / "runtime.log"
        self.runtime_process: subprocess.Popen[str] | None = None
        self.runtime_handle: Any = None
        self.started_at = datetime.now(timezone.utc)

    def log(self, message: str) -> None:
        timestamp = datetime.now(timezone.utc).isoformat(timespec="milliseconds")
        line = f"{timestamp}  {message}"
        print(line, flush=True)
        with self.actions_path.open("a", encoding="utf-8") as stream:
            stream.write(line + "\n")

    def command(self, arguments: Sequence[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
        self.log("$ " + " ".join(arguments))
        result = subprocess.run(
            list(arguments),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
        if result.stdout.strip():
            with self.actions_path.open("a", encoding="utf-8") as stream:
                stream.write(result.stdout.rstrip() + "\n")
        if check and result.returncode != 0:
            raise ScenarioFailure(
                f"Command failed with status {result.returncode}: {' '.join(arguments)}"
            )
        return result

    def start_runtime_log(self) -> None:
        self.runtime_handle = self.runtime_path.open("w", encoding="utf-8")
        self.runtime_process = subprocess.Popen(
            [
                "xcrun",
                "simctl",
                "spawn",
                self.udid,
                "log",
                "stream",
                "--style",
                "compact",
                "--level",
                "default",
                "--predicate",
                'process == "vivobody" AND '
                '(messageType == error OR messageType == fault OR '
                'subsystem BEGINSWITH "astanciu.vivobody")',
            ],
            text=True,
            stdout=self.runtime_handle,
            stderr=subprocess.STDOUT,
        )

    def stop_runtime_log(self) -> None:
        if self.runtime_process is not None:
            self.runtime_process.terminate()
            try:
                self.runtime_process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.runtime_process.kill()
                self.runtime_process.wait(timeout=3)
            self.runtime_process = None
        if self.runtime_handle is not None:
            self.runtime_handle.close()
            self.runtime_handle = None

    def launch_arguments(self, configuration: Mapping[str, Any]) -> list[str]:
        arguments: list[str] = []
        if configuration.get("reset", False):
            arguments.append("--ui-test-reset")
        tab = configuration.get("tab")
        if tab is not None:
            if tab not in {"today", "history", "library", "insights", "me"}:
                raise ScenarioFailure(f"Unknown launch tab {tab!r}.")
            arguments.extend(["--verify-tab", tab])
        extra = configuration.get("arguments", [])
        if not isinstance(extra, list) or not all(isinstance(value, str) for value in extra):
            raise ScenarioFailure("launch.arguments must be an array of strings.")
        arguments.extend(extra)
        return arguments

    def launch(self, configuration: Mapping[str, Any]) -> None:
        arguments = self.launch_arguments(configuration)
        self.command(
            ["xcrun", "simctl", "terminate", self.udid, self.bundle_id],
            check=False,
        )
        self.command(
            ["xcrun", "simctl", "launch", self.udid, self.bundle_id, *arguments]
        )
        self.wait_for_application()

    def describe_tree(self, output: Path | None = None) -> Mapping[str, Any]:
        destination = output or self.current_tree_path
        destination.unlink(missing_ok=True)
        result = subprocess.run(
            [
                self.baguette,
                "describe-ui",
                "--udid",
                self.udid,
                "--output",
                str(destination),
            ],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
        if result.returncode != 0 or not destination.exists():
            detail = result.stdout.strip() or "no accessibility tree produced"
            raise ScenarioFailure(f"Baguette could not describe the UI: {detail}")
        try:
            tree = json.loads(destination.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise ScenarioFailure(f"Invalid accessibility tree at {destination}: {error}") from error
        if not isinstance(tree, Mapping):
            raise ScenarioFailure("Accessibility tree root must be a JSON object.")
        return tree

    def wait_until(
        self,
        description: str,
        predicate: Callable[[Mapping[str, Any]], tuple[bool, str]],
        *,
        timeout: float | None = None,
    ) -> Mapping[str, Any]:
        deadline = time.monotonic() + (timeout if timeout is not None else self.timeout)
        last_detail = ""
        while time.monotonic() < deadline:
            try:
                tree = self.describe_tree()
                passed, last_detail = predicate(tree)
                if passed:
                    self.log(f"PASS {description}")
                    return tree
            except ScenarioFailure as error:
                last_detail = str(error)
            time.sleep(POLL_INTERVAL)
        suffix = f": {last_detail}" if last_detail else ""
        raise ScenarioFailure(f"Timed out waiting for {description}{suffix}")

    def wait_for_application(self) -> Mapping[str, Any]:
        def ready(tree: Mapping[str, Any]) -> tuple[bool, str]:
            label = str(tree.get("label") or "").lower()
            children = tree.get("children")
            passed = label == "vivobody" and isinstance(children, list) and bool(children)
            return passed, f"root label={label!r}, children={len(children) if isinstance(children, list) else 0}"

        return self.wait_until("the Vivobody accessibility tree", ready)

    def wait_for_selector(
        self,
        selector: Mapping[str, Any],
        *,
        unique: bool = False,
    ) -> tuple[Mapping[str, Any], list[Match]]:
        validate_selector(selector)
        found: list[Match] = []

        def present(tree: Mapping[str, Any]) -> tuple[bool, str]:
            nonlocal found
            found = find_matches(tree, selector)
            expected = len(found) == 1 if unique else bool(found)
            return expected, f"matched {len(found)} element(s)"

        tree = self.wait_until(f"selector {json.dumps(selector, sort_keys=True)}", present)
        return tree, found

    def wait_for_stable_selector(
        self,
        selector: Mapping[str, Any],
    ) -> tuple[Mapping[str, Any], Match]:
        validate_selector(selector)
        deadline = time.monotonic() + self.timeout
        previous_frame: tuple[float, float, float, float] | None = None
        stable_samples = 0
        last_detail = ""
        while time.monotonic() < deadline:
            try:
                tree = self.describe_tree()
                matches = find_matches(tree, selector)
                if len(matches) != 1:
                    previous_frame = None
                    stable_samples = 0
                    last_detail = f"matched {len(matches)} element(s)"
                else:
                    match = matches[0]
                    frame = visible_intersection(match.node, tree)
                    if frame is None:
                        previous_frame = None
                        stable_samples = 0
                        last_detail = "match had no visible frame"
                    elif previous_frame is not None and all(
                        abs(current - previous) <= 1.0
                        for current, previous in zip(frame, previous_frame)
                    ):
                        stable_samples += 1
                        if stable_samples >= 2:
                            self.log(
                                "PASS stable selector "
                                f"{json.dumps(selector, sort_keys=True)} at frame={frame}"
                            )
                            return tree, match
                    else:
                        stable_samples = 0
                    previous_frame = frame
                    last_detail = f"last frame={frame}, stable samples={stable_samples}"
            except ScenarioFailure as error:
                last_detail = str(error)
            time.sleep(POLL_INTERVAL)
        raise ScenarioFailure(
            f"Timed out waiting for stable selector {json.dumps(selector, sort_keys=True)}: "
            f"{last_detail}"
        )

    def wait_for_constraints(
        self,
        required: Sequence[Mapping[str, Any]],
        forbidden: Sequence[Mapping[str, Any]],
    ) -> Mapping[str, Any]:
        for selector in [*required, *forbidden]:
            validate_selector(selector)

        def satisfied(tree: Mapping[str, Any]) -> tuple[bool, str]:
            failures = constraint_failures(tree, required, forbidden)
            return not failures, "; ".join(failures)

        return self.wait_until("semantic assertions", satisfied)

    def wait_for_log_constraints(
        self,
        required: Sequence[str],
        forbidden: Sequence[str],
    ) -> None:
        deadline = time.monotonic() + self.timeout
        last_failures: list[str] = []
        while time.monotonic() < deadline:
            try:
                source = self.runtime_path.read_text(encoding="utf-8")
            except OSError as error:
                last_failures = [f"runtime log unavailable: {error}"]
                time.sleep(POLL_INTERVAL)
                continue
            last_failures = log_constraint_failures(source, required, forbidden)
            forbidden_failure = next(
                (failure for failure in last_failures if failure.startswith("found forbidden")),
                None,
            )
            if forbidden_failure is not None:
                raise ScenarioFailure(forbidden_failure)
            if not last_failures:
                self.log("PASS runtime log assertions")
                return
            time.sleep(POLL_INTERVAL)
        detail = "; ".join(last_failures) or "no matching runtime events"
        raise ScenarioFailure(f"Timed out waiting for runtime log assertions: {detail}")

    def tap(self, selector: Mapping[str, Any]) -> None:
        tree, match = self.wait_for_stable_selector(selector)
        if match.node.get("enabled") is False:
            raise ScenarioFailure(f"Matched element is disabled: {describe_node(match)}")
        x, y = element_midpoint(match.node, tree)
        root_frame = node_frame(tree)
        if root_frame is None:
            raise ScenarioFailure("Application accessibility root has no usable frame.")
        _, _, width, height = root_frame
        self.log(f"TAP {describe_node(match)} at ({x:.2f}, {y:.2f})")
        self.command([
            self.baguette,
            "tap",
            "--udid",
            self.udid,
            "--x",
            f"{x:.3f}",
            "--y",
            f"{y:.3f}",
            "--width",
            f"{width:.3f}",
            "--height",
            f"{height:.3f}",
        ])

    def scroll_to(self, configuration: Mapping[str, Any]) -> None:
        selector = configuration.get("selector")
        if not isinstance(selector, Mapping):
            raise ScenarioFailure("scrollTo.selector must be a selector object.")
        validate_selector(selector)
        direction = configuration.get("direction", "up")
        if not isinstance(direction, str):
            raise ScenarioFailure("scrollTo.direction must be a string.")
        max_swipes = configuration.get("maxSwipes", 6)
        if not isinstance(max_swipes, int) or isinstance(max_swipes, bool) or max_swipes < 1:
            raise ScenarioFailure("scrollTo.maxSwipes must be a positive integer.")

        for attempt in range(max_swipes + 1):
            tree = self.describe_tree()
            matches = find_matches(tree, selector)
            if matches:
                self.log(
                    f"PASS scrolled to {json.dumps(selector, sort_keys=True)} "
                    f"after {attempt} swipe(s)"
                )
                return
            if attempt == max_swipes:
                break
            start_x, start_y, end_x, end_y, width, height = swipe_points(tree, direction)
            self.log(
                f"SWIPE {direction} toward {json.dumps(selector, sort_keys=True)} "
                f"({attempt + 1}/{max_swipes})"
            )
            self.command([
                self.baguette,
                "swipe",
                "--udid",
                self.udid,
                "--start-x",
                f"{start_x:.3f}",
                "--start-y",
                f"{start_y:.3f}",
                "--end-x",
                f"{end_x:.3f}",
                "--end-y",
                f"{end_y:.3f}",
                "--width",
                f"{width:.3f}",
                "--height",
                f"{height:.3f}",
                "--duration",
                "0.75",
            ])
            time.sleep(POLL_INTERVAL)
        raise ScenarioFailure(
            f"Could not scroll {direction} to selector "
            f"{json.dumps(selector, sort_keys=True)} after {max_swipes} swipe(s)."
        )

    def run_step(self, index: int, step: Mapping[str, Any]) -> None:
        if len(step) != 1:
            raise ScenarioFailure(f"Step {index} must contain exactly one action.")
        action, payload = next(iter(step.items()))
        self.log(f"STEP {index} {action}")
        if action == "wait":
            if not isinstance(payload, Mapping):
                raise ScenarioFailure(f"Step {index} wait payload must be a selector object.")
            self.wait_for_selector(payload)
        elif action == "waitAbsent":
            if not isinstance(payload, Mapping):
                raise ScenarioFailure(f"Step {index} waitAbsent payload must be a selector object.")
            self.wait_for_constraints([], [payload])
        elif action == "tap":
            if not isinstance(payload, Mapping):
                raise ScenarioFailure(f"Step {index} tap payload must be a selector object.")
            self.tap(payload)
        elif action == "scrollTo":
            if not isinstance(payload, Mapping):
                raise ScenarioFailure(f"Step {index} scrollTo payload must be an object.")
            self.scroll_to(payload)
        elif action == "assert":
            if not isinstance(payload, Mapping):
                raise ScenarioFailure(f"Step {index} assert payload must be an object.")
            self.wait_for_constraints(
                _selector_list(payload.get("required", []), f"step {index} required"),
                _selector_list(payload.get("forbidden", []), f"step {index} forbidden"),
            )
        elif action == "relaunch":
            if not isinstance(payload, Mapping):
                raise ScenarioFailure(f"Step {index} relaunch payload must be an object.")
            self.launch(payload)
        elif action == "openURL":
            if not isinstance(payload, str):
                raise ScenarioFailure(f"Step {index} openURL payload must be a string.")
            self.command(["xcrun", "simctl", "openurl", self.udid, payload])
        else:
            raise ScenarioFailure(f"Step {index} uses unsupported action {action!r}.")

    def capture_artifacts(self, stem: str) -> None:
        screenshot = self.output_dir / f"{stem}.jpg"
        ui_tree = self.output_dir / f"{stem}-ui.json"
        try:
            self.command([
                self.baguette,
                "screenshot",
                "--udid",
                self.udid,
                "--output",
                str(screenshot),
            ])
        except ScenarioFailure as error:
            self.log(f"CAPTURE WARNING {error}")
        try:
            self.describe_tree(ui_tree)
            self.log(f"UI TREE {ui_tree}")
        except ScenarioFailure as error:
            self.log(f"CAPTURE WARNING {error}")

    def run(self) -> int:
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.actions_path.write_text("", encoding="utf-8")
        status = "failed"
        error_message: str | None = None
        capture_stem = "failure"
        try:
            self.start_runtime_log()
            launch = self.scenario.get("launch", {})
            if not isinstance(launch, Mapping):
                raise ScenarioFailure("Scenario launch must be an object.")
            self.launch(launch)

            steps = self.scenario.get("steps", [])
            if not isinstance(steps, list):
                raise ScenarioFailure("Scenario steps must be an array.")
            for index, step in enumerate(steps, start=1):
                if not isinstance(step, Mapping):
                    raise ScenarioFailure(f"Step {index} must be an object.")
                self.run_step(index, step)

            required = _selector_list(self.scenario.get("required", []), "required")
            forbidden = _selector_list(self.scenario.get("forbidden", []), "forbidden")
            self.wait_for_constraints(required, forbidden)
            required_logs = _string_list(
                self.scenario.get("requiredLogs", []),
                "requiredLogs",
            )
            forbidden_logs = _string_list(
                self.scenario.get("forbiddenLogs", []),
                "forbiddenLogs",
            )
            if required_logs or forbidden_logs:
                self.wait_for_log_constraints(required_logs, forbidden_logs)
            status = "passed"
            capture_stem = "final"
            self.log("SCENARIO PASSED")
        except (ScenarioFailure, OSError) as error:
            error_message = str(error)
            self.log(f"SCENARIO FAILED {error_message}")
        finally:
            self.capture_artifacts(capture_stem)
            self.stop_runtime_log()
            finished_at = datetime.now(timezone.utc)
            result = {
                "scenario": self.scenario.get("name"),
                "status": status,
                "error": error_message,
                "startedAt": self.started_at.isoformat(),
                "finishedAt": finished_at.isoformat(),
                "durationSeconds": round((finished_at - self.started_at).total_seconds(), 3),
                "artifacts": {
                    "screenshot": f"{capture_stem}.jpg",
                    "uiTree": f"{capture_stem}-ui.json",
                    "actions": self.actions_path.name,
                    "runtime": self.runtime_path.name,
                },
            }
            (self.output_dir / "result.json").write_text(
                json.dumps(result, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )

        print(flush=True)
        print(f"Scenario:   {self.scenario.get('name')}", flush=True)
        print(f"Status:     {status}", flush=True)
        print(f"Artifacts:  {self.output_dir}", flush=True)
        if error_message:
            print(f"Error:      {error_message}", file=sys.stderr, flush=True)
        return 0 if status == "passed" else 1


def _selector_list(value: Any, field: str) -> list[Mapping[str, Any]]:
    if not isinstance(value, list) or not all(isinstance(item, Mapping) for item in value):
        raise ScenarioFailure(f"Scenario {field} must be an array of selector objects.")
    return list(value)


def _string_list(value: Any, field: str) -> list[str]:
    if not isinstance(value, list) or not all(
        isinstance(item, str) and item
        for item in value
    ):
        raise ScenarioFailure(f"Scenario {field} must be an array of non-empty strings.")
    return list(value)


def validate_launch_configuration(configuration: Any, field: str) -> None:
    if not isinstance(configuration, Mapping):
        raise ScenarioFailure(f"Scenario {field} must be an object.")
    unknown = set(configuration) - {"reset", "tab", "arguments"}
    if unknown:
        raise ScenarioFailure(
            f"Scenario {field} has unsupported field(s): {', '.join(sorted(unknown))}."
        )
    if "reset" in configuration and not isinstance(configuration["reset"], bool):
        raise ScenarioFailure(f"Scenario {field}.reset must be a boolean.")
    tab = configuration.get("tab")
    if tab is not None and tab not in {"today", "history", "library", "insights", "me"}:
        raise ScenarioFailure(f"Scenario {field}.tab has unknown value {tab!r}.")
    arguments = configuration.get("arguments", [])
    if not isinstance(arguments, list) or not all(isinstance(value, str) for value in arguments):
        raise ScenarioFailure(f"Scenario {field}.arguments must be an array of strings.")


def validate_scenario_definition(scenario: Mapping[str, Any]) -> None:
    unknown = set(scenario) - {
        "name",
        "launch",
        "steps",
        "required",
        "forbidden",
        "requiredLogs",
        "forbiddenLogs",
    }
    if unknown:
        raise ScenarioFailure(
            f"Scenario has unsupported top-level field(s): {', '.join(sorted(unknown))}."
        )
    validate_launch_configuration(scenario.get("launch", {}), "launch")
    required = _selector_list(scenario.get("required", []), "required")
    forbidden = _selector_list(scenario.get("forbidden", []), "forbidden")
    _string_list(scenario.get("requiredLogs", []), "requiredLogs")
    _string_list(scenario.get("forbiddenLogs", []), "forbiddenLogs")
    for selector in [*required, *forbidden]:
        validate_selector(selector)

    steps = scenario.get("steps", [])
    if not isinstance(steps, list):
        raise ScenarioFailure("Scenario steps must be an array.")
    for index, step in enumerate(steps, start=1):
        if not isinstance(step, Mapping) or len(step) != 1:
            raise ScenarioFailure(f"Step {index} must contain exactly one action.")
        action, payload = next(iter(step.items()))
        if action in {"wait", "waitAbsent", "tap"}:
            if not isinstance(payload, Mapping):
                raise ScenarioFailure(f"Step {index} {action} payload must be a selector object.")
            validate_selector(payload)
        elif action == "assert":
            if not isinstance(payload, Mapping):
                raise ScenarioFailure(f"Step {index} assert payload must be an object.")
            assert_required = _selector_list(payload.get("required", []), f"step {index} required")
            assert_forbidden = _selector_list(payload.get("forbidden", []), f"step {index} forbidden")
            for selector in [*assert_required, *assert_forbidden]:
                validate_selector(selector)
        elif action == "relaunch":
            validate_launch_configuration(payload, f"step {index} relaunch")
        elif action == "openURL":
            if not isinstance(payload, str) or not payload:
                raise ScenarioFailure(f"Step {index} openURL payload must be a non-empty string.")
        elif action == "scrollTo":
            if not isinstance(payload, Mapping):
                raise ScenarioFailure(f"Step {index} scrollTo payload must be an object.")
            unknown_scroll = set(payload) - {"selector", "direction", "maxSwipes"}
            if unknown_scroll:
                raise ScenarioFailure(
                    f"Step {index} scrollTo has unsupported field(s): "
                    f"{', '.join(sorted(unknown_scroll))}."
                )
            selector = payload.get("selector")
            if not isinstance(selector, Mapping):
                raise ScenarioFailure(f"Step {index} scrollTo.selector must be an object.")
            validate_selector(selector)
            if payload.get("direction", "up") not in {"up", "down"}:
                raise ScenarioFailure(f"Step {index} scrollTo.direction must be 'up' or 'down'.")
            max_swipes = payload.get("maxSwipes", 6)
            if not isinstance(max_swipes, int) or isinstance(max_swipes, bool) or max_swipes < 1:
                raise ScenarioFailure(f"Step {index} scrollTo.maxSwipes must be a positive integer.")
        else:
            raise ScenarioFailure(f"Step {index} uses unsupported action {action!r}.")


def load_scenario(name: str, directory: Path) -> Mapping[str, Any]:
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name):
        raise ScenarioFailure(
            "Scenario names may contain lowercase letters, numbers, and single hyphens."
        )
    path = directory / f"{name}.json"
    if not path.is_file():
        available = ", ".join(sorted(item.stem for item in directory.glob("*.json")))
        suffix = f" Available scenarios: {available}." if available else ""
        raise ScenarioFailure(f"Unknown scenario {name!r}.{suffix}")
    try:
        scenario = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ScenarioFailure(f"Could not load scenario {path}: {error}") from error
    if not isinstance(scenario, Mapping):
        raise ScenarioFailure(f"Scenario {path} must contain a JSON object.")
    if scenario.get("name") != name:
        raise ScenarioFailure(
            f"Scenario file {path.name} must declare name {name!r}, got {scenario.get('name')!r}."
        )
    validate_scenario_definition(scenario)
    return scenario


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run a semantic Baguette verification scenario."
    )
    parser.add_argument("--scenario", required=True)
    parser.add_argument("--udid", required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--scenarios-dir", type=Path, default=DEFAULT_SCENARIOS_DIR)
    parser.add_argument("--baguette", default="baguette")
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        scenario = load_scenario(args.scenario, args.scenarios_dir)
    except ScenarioFailure as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    runner = ScenarioRunner(
        scenario=scenario,
        udid=args.udid,
        bundle_id=args.bundle_id,
        output_dir=args.output_dir,
        baguette=args.baguette,
        timeout=args.timeout,
    )
    return runner.run()


if __name__ == "__main__":
    raise SystemExit(main())
