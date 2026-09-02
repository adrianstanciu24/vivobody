#!/usr/bin/env python3
#
#  check_architecture.py
#  vivobody
#
#  Fast structural checks for the repository's load-bearing boundaries.
#  The rules deliberately target architecture that Swift's compiler cannot
#  express: system-framework isolation, app-only SwiftData ownership, shared
#  surface wrappers, persistence conventions, and session side-effect routing.
#  Diagnostics include the approved path so an agent can repair drift without
#  guessing which local pattern to copy.
#

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]

SWIFT_SOURCE_ROOTS = (
    "vivobody/",
    "vivobodyWidgets/",
    "VivoKit/Sources/",
)
SWIFT_HEADER_ROOTS = (
    *SWIFT_SOURCE_ROOTS,
    "vivobodyTests",
    "vivobodyUITests",
)

# Frameworks with exactly one or two repository-wide owners. Adding another
# target or concern is possible, but it must be an explicit architecture edit.
GLOBAL_FRAMEWORK_BOUNDARIES: dict[str, frozenset[str]] = {
    "HealthKit": frozenset({
        "vivobody/HealthKit/HealthKitWorkoutService.swift",
    }),
    "StoreKit": frozenset({
        "vivobody/App/ReviewRequestController.swift",
        "vivobody/Store/ProStore.swift",
    }),
    "UserNotifications": frozenset({
        "vivobody/App/RestNotificationController.swift",
    }),
}

# These frameworks are expected in extensions/shared code, so only their use
# inside the app target is constrained here.
APP_FRAMEWORK_BOUNDARIES: dict[str, frozenset[str]] = {
    "ActivityKit": frozenset({
        "vivobody/App/WorkoutLiveActivityController.swift",
    }),
    "CoreSpotlight": frozenset({
        "vivobody/App/AppRoot.swift",
        "vivobody/App/IncomingAction.swift",
        "vivobody/App/SpotlightIndexer.swift",
    }),
    "WidgetKit": frozenset({
        "vivobody/App/WidgetSnapshotWriter.swift",
        "vivobody/Store/ProStore.swift",
    }),
}

SWIFTDATA_FORBIDDEN_ROOTS = (
    "vivobodyWidgets/",
    "VivoKit/Sources/",
)
ACTIVE_EXERCISE_CARD_PREFIX = (
    "vivobody/Screens/ActiveWorkout/ActiveExerciseCard"
)

RAW_GLASS_BOUNDARIES = frozenset({
    "vivobody/App/GlassStyle.swift",
    "vivobodyWidgets/WidgetChrome.swift",
})

SESSION_SIDE_EFFECT_BOUNDARY = "vivobody/App/SessionSideEffects.swift"
LOGGER_BOUNDARY = "vivobody/App/AppDiagnostics.swift"
DIRECT_SAVE_SUPPRESSION = "architecture: allow-direct-save"
VERSION_SOURCE = "Shared.xcconfig"
VERSION_KEYS = ("MARKETING_VERSION", "CURRENT_PROJECT_VERSION")

IMPORT_PATTERN = re.compile(r"(?m)^\s*import\s+([A-Za-z_][A-Za-z0-9_]*)\b")
RAW_GLASS_PATTERN = re.compile(r"\bglassEffect\s*\(")
SWIFTDATA_TOKEN_PATTERN = re.compile(
    r"(?:\bimport\s+SwiftData\b|\bSwiftData\s*\.|\bModelContainer\b|"
    r"\bModelContext\b|@Model\b|@Query\b)"
)
ACTIVE_EXERCISE_CARD_BOUNDARY_PATTERN = re.compile(
    r"(?:\bimport\s+SwiftData\b|\bSwiftData\s*\.|\bModelContainer\b|"
    r"\bModelContext\b|@Model\b|@Query\b|\bmodelContext\b|"
    r"\bSessionAnalytics\b|\bsessionAnalytics\b|\bSessionSideEffects\b|"
    r"\bsaveOrRollback\s*\()"
)
LITERAL_DEFAULT_PATTERNS = (
    (re.compile(r"@AppStorage\s*\(\s*#*\""), "@AppStorage key"),
    (re.compile(r"\bforKey\s*:\s*#*\""), "UserDefaults key"),
    (re.compile(r"\bsuiteName\s*:\s*#*\""), "UserDefaults suite name"),
)
DIRECT_CONTEXT_SAVE_PATTERN = re.compile(
    r"\b(?:context|[A-Za-z_][A-Za-z0-9_]*Context)\s*\.\s*save\s*\("
)
DIRECT_LOGGER_PATTERN = re.compile(r"\b(?:OSLog\s*\.\s*)?Logger\s*\(")
VALID_DIRECT_SAVE_SUPPRESSION = re.compile(
    rf"//\s*{re.escape(DIRECT_SAVE_SUPPRESSION)}\s*--\s*\S.+$"
)
LIFECYCLE_CALL_PATTERNS = (
    (
        re.compile(r"\bHealthKitWorkoutService\s*\.\s*saveWorkout\s*\("),
        "HealthKit archive writes",
    ),
    (
        re.compile(
            r"\bWorkoutLiveActivityController\s*\.\s*"
            r"(?:start|update|end|scheduleSettledScrubUpdate)\s*\("
        ),
        "Live Activity session transitions",
    ),
    (
        re.compile(r"\bWidgetSnapshotWriter\s*\.\s*writeActiveWorkout\s*\("),
        "active-workout widget snapshots",
    ),
)


@dataclass(frozen=True, order=True)
class Violation:
    path: str
    line: int
    rule: str
    message: str

    def diagnostic(self) -> str:
        return f"{self.path}:{self.line}: error: [{self.rule}] {self.message}"


@dataclass(frozen=True)
class MaskedSwift:
    """Parallel source views with positions/newlines preserved."""

    code: str
    comments_removed: str


def _blank(characters: list[str], index: int) -> None:
    if characters[index] not in "\r\n":
        characters[index] = " "


def mask_swift(source: str) -> MaskedSwift:
    """Mask comments and strings without changing offsets or line numbers.

    `code` excludes both, preventing documentation and UI copy from looking
    like executable calls. `comments_removed` retains strings so literal
    UserDefaults keys can be identified without matching commented examples.
    Swift interpolation inside a string is intentionally treated as string
    content; project boundary calls should never be hidden in interpolation.
    """

    code = list(source)
    comments_removed = list(source)
    index = 0
    state = "code"
    block_depth = 0

    while index < len(source):
        if state == "code":
            if source.startswith("//", index):
                _blank(code, index)
                _blank(code, index + 1)
                _blank(comments_removed, index)
                _blank(comments_removed, index + 1)
                index += 2
                state = "line_comment"
                continue
            if source.startswith("/*", index):
                _blank(code, index)
                _blank(code, index + 1)
                _blank(comments_removed, index)
                _blank(comments_removed, index + 1)
                index += 2
                block_depth = 1
                state = "block_comment"
                continue
            if source.startswith('"""', index):
                for offset in range(3):
                    _blank(code, index + offset)
                index += 3
                state = "multiline_string"
                continue
            if source[index] == '"':
                _blank(code, index)
                index += 1
                state = "string"
                continue
            index += 1
            continue

        if state == "line_comment":
            if source[index] in "\r\n":
                state = "code"
            else:
                _blank(code, index)
                _blank(comments_removed, index)
            index += 1
            continue

        if state == "block_comment":
            if source.startswith("/*", index):
                _blank(code, index)
                _blank(code, index + 1)
                _blank(comments_removed, index)
                _blank(comments_removed, index + 1)
                block_depth += 1
                index += 2
                continue
            if source.startswith("*/", index):
                _blank(code, index)
                _blank(code, index + 1)
                _blank(comments_removed, index)
                _blank(comments_removed, index + 1)
                block_depth -= 1
                index += 2
                if block_depth == 0:
                    state = "code"
                continue
            _blank(code, index)
            _blank(comments_removed, index)
            index += 1
            continue

        if state == "string":
            _blank(code, index)
            if source[index] == "\\":
                if index + 1 < len(source):
                    _blank(code, index + 1)
                    index += 2
                else:
                    index += 1
                continue
            if source[index] == '"':
                state = "code"
            index += 1
            continue

        if state == "multiline_string":
            if source.startswith('"""', index):
                for offset in range(3):
                    _blank(code, index + offset)
                index += 3
                state = "code"
                continue
            _blank(code, index)
            index += 1

    return MaskedSwift("".join(code), "".join(comments_removed))


def line_number(source: str, offset: int) -> int:
    return source.count("\n", 0, offset) + 1


def is_under(path: str, roots: Iterable[str]) -> bool:
    return any(path.startswith(root) for root in roots)


def header_violation(path: str, source: str) -> Violation | None:
    lines = source.splitlines()
    index = next((i for i, line in enumerate(lines) if line.strip()), None)
    if index is None:
        return Violation(path, 1, "ARCH008", "Swift files must not be empty.")

    if lines[index].strip() == "#if DEBUG":
        index += 1
        while index < len(lines) and not lines[index].strip():
            index += 1

    if index >= len(lines) or not lines[index].lstrip().startswith("//"):
        return Violation(
            path,
            index + 1,
            "ARCH008",
            "Start the file with its purpose comment header (a DEBUG wrapper may precede it).",
        )

    header: list[str] = []
    cursor = index
    while cursor < len(lines):
        stripped = lines[cursor].strip()
        if stripped.startswith("//"):
            text = stripped[2:].strip()
            if text:
                header.append(text)
        elif stripped:
            break
        cursor += 1

    filename = PurePosixPath(path).name
    if filename not in header:
        return Violation(
            path,
            index + 1,
            "ARCH008",
            f"The opening comment header must name {filename}.",
        )

    boilerplate = {
        filename,
        "vivobody",
        "vivobodyWidgets",
        "VivoKit",
        "vivobodyTests",
        "vivobodyUITests",
    }
    purpose = [
        line
        for line in header
        if line not in boilerplate and not line.startswith("Created by ")
    ]
    if not purpose:
        return Violation(
            path,
            index + 1,
            "ARCH008",
            "Add a concise purpose statement to the opening file header.",
        )
    return None


def check_swift_file(path: str, source: str) -> list[Violation]:
    violations: list[Violation] = []
    header = header_violation(path, source)
    if header is not None:
        violations.append(header)

    # Tests still follow the header convention, but production architecture
    # checks apply only to source targets.
    if not is_under(path, SWIFT_SOURCE_ROOTS):
        return violations

    masked = mask_swift(source)
    imports = [
        (match.group(1), line_number(masked.code, match.start()))
        for match in IMPORT_PATTERN.finditer(masked.code)
    ]

    for module, line in imports:
        allowed = GLOBAL_FRAMEWORK_BOUNDARIES.get(module)
        if allowed is not None and path not in allowed:
            owners = ", ".join(sorted(allowed))
            violations.append(Violation(
                path,
                line,
                "ARCH001",
                f"Keep {module} behind its boundary: {owners}. Move the system call there or update the architecture allowlist with rationale.",
            ))

        app_allowed = APP_FRAMEWORK_BOUNDARIES.get(module)
        if path.startswith("vivobody/") and app_allowed is not None and path not in app_allowed:
            owners = ", ".join(sorted(app_allowed))
            violations.append(Violation(
                path,
                line,
                "ARCH001",
                f"The app target may import {module} only in: {owners}. Route the behavior through that boundary.",
            ))

    if is_under(path, SWIFTDATA_FORBIDDEN_ROOTS):
        for match in SWIFTDATA_TOKEN_PATTERN.finditer(masked.code):
            violations.append(Violation(
                path,
                line_number(masked.code, match.start()),
                "ARCH002",
                "Widgets and VivoKit must not access SwiftData. Put persistence in the app and exchange versioned VivoKit snapshots.",
            ))

    if path.startswith(ACTIVE_EXERCISE_CARD_PREFIX):
        for match in ACTIVE_EXERCISE_CARD_BOUNDARY_PATTERN.finditer(masked.code):
            violations.append(Violation(
                path,
                line_number(masked.code, match.start()),
                "ARCH012",
                "Keep SwiftData, SessionAnalytics, and SessionSideEffects outside ActiveExerciseCard files; route completion through the typed screen/controller boundary.",
            ))

    if path not in RAW_GLASS_BOUNDARIES:
        for match in RAW_GLASS_PATTERN.finditer(masked.code):
            violations.append(Violation(
                path,
                line_number(masked.code, match.start()),
                "ARCH003",
                "Use GlassStyle surface modifiers; raw glassEffect calls belong only in GlassStyle.swift or WidgetChrome.swift.",
            ))

    for pattern, description in LITERAL_DEFAULT_PATTERNS:
        for match in pattern.finditer(masked.comments_removed):
            violations.append(Violation(
                path,
                line_number(masked.comments_removed, match.start()),
                "ARCH004",
                f"Replace this literal {description} with SettingsKey or WidgetShared.",
            ))

    direct_save_lines: set[int] = set()
    source_lines = source.splitlines()
    for match in DIRECT_CONTEXT_SAVE_PATTERN.finditer(masked.code):
        line = line_number(masked.code, match.start())
        direct_save_lines.add(line)
        original_line = source_lines[line - 1] if line <= len(source_lines) else ""
        if VALID_DIRECT_SAVE_SUPPRESSION.search(original_line):
            continue
        violations.append(Violation(
            path,
            line,
            "ARCH005",
            "Use saveOrRollback(). If direct save semantics are essential, add an inline '// architecture: allow-direct-save -- <reason>' exception.",
        ))

    for line, text in enumerate(source_lines, start=1):
        if DIRECT_SAVE_SUPPRESSION not in text:
            continue
        if line not in direct_save_lines or not VALID_DIRECT_SAVE_SUPPRESSION.search(text):
            violations.append(Violation(
                path,
                line,
                "ARCH006",
                "Direct-save exceptions must be inline on the save call and include '-- <reason>'. Remove or complete this suppression.",
            ))

    if path != SESSION_SIDE_EFFECT_BOUNDARY:
        for pattern, concern in LIFECYCLE_CALL_PATTERNS:
            for match in pattern.finditer(masked.code):
                violations.append(Violation(
                    path,
                    line_number(masked.code, match.start()),
                    "ARCH007",
                    f"Route {concern} through SessionSideEffects instead of calling the system boundary directly.",
                ))

    if path != LOGGER_BOUNDARY:
        for match in DIRECT_LOGGER_PATTERN.finditer(masked.code):
            violations.append(Violation(
                path,
                line_number(masked.code, match.start()),
                "ARCH011",
                "Route unified logging through AppDiagnostics so event names and privacy policy stay centralized.",
            ))

    return violations


def discovered_swift_paths(root: Path) -> list[Path]:
    paths: set[Path] = set()
    for relative_root in SWIFT_HEADER_ROOTS:
        directory = root / relative_root
        if directory.exists():
            paths.update(directory.rglob("*.swift"))
    return sorted(paths)


def check_boundary_configuration(root: Path) -> list[Violation]:
    violations: list[Violation] = []
    configured = {
        module: paths
        for boundaries in (GLOBAL_FRAMEWORK_BOUNDARIES, APP_FRAMEWORK_BOUNDARIES)
        for module, paths in boundaries.items()
    }
    for module, paths in configured.items():
        for path in paths:
            absolute = root / path
            if not absolute.exists():
                violations.append(Violation(
                    path,
                    1,
                    "ARCH010",
                    f"The {module} boundary allowlist points to a missing file. Update the checker when moving or removing a boundary.",
                ))
                continue
            masked = mask_swift(absolute.read_text(encoding="utf-8"))
            imported = {match.group(1) for match in IMPORT_PATTERN.finditer(masked.code)}
            if module not in imported:
                violations.append(Violation(
                    path,
                    1,
                    "ARCH010",
                    f"The {module} boundary allowlist is stale because this file no longer imports {module}. Update the checker.",
                ))
    return violations


def check_version_sources(root: Path) -> list[Violation]:
    violations: list[Violation] = []
    candidates = sorted(root.rglob("*.xcconfig"))
    project_file = root / "vivobody.xcodeproj" / "project.pbxproj"
    if project_file.exists():
        candidates.append(project_file)

    definitions: dict[str, list[tuple[str, int]]] = {key: [] for key in VERSION_KEYS}
    for path in candidates:
        try:
            relative = path.relative_to(root).as_posix()
        except ValueError:
            continue
        if relative.startswith(("build/", ".verify/")):
            continue
        for line, text in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            for key in VERSION_KEYS:
                if re.match(rf"^\s*{re.escape(key)}\s*=", text):
                    definitions[key].append((relative, line))

    for key, sites in definitions.items():
        canonical_sites = [site for site in sites if site[0] == VERSION_SOURCE]
        if len(canonical_sites) != 1:
            line = canonical_sites[0][1] if canonical_sites else 1
            violations.append(Violation(
                VERSION_SOURCE,
                line,
                "ARCH009",
                f"Define {key} exactly once in {VERSION_SOURCE}.",
            ))
        for path, line in sites:
            if path != VERSION_SOURCE:
                violations.append(Violation(
                    path,
                    line,
                    "ARCH009",
                    f"{key} must be defined only in {VERSION_SOURCE}; remove this duplicate definition.",
                ))
    return violations


def check_repository(root: Path = ROOT) -> tuple[list[Violation], int]:
    paths = discovered_swift_paths(root)
    violations: list[Violation] = []
    for path in paths:
        relative = path.relative_to(root).as_posix()
        violations.extend(check_swift_file(relative, path.read_text(encoding="utf-8")))
    violations.extend(check_boundary_configuration(root))
    violations.extend(check_version_sources(root))
    return sorted(set(violations)), len(paths)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check Vivobody's mechanically enforceable architecture boundaries."
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=ROOT,
        help="Repository root (defaults to the parent of Scripts/).",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    root = args.root.resolve()
    violations, file_count = check_repository(root)
    if violations:
        print(
            f"architecture check failed: {len(violations)} violation(s)",
            file=sys.stderr,
        )
        for violation in violations:
            print(violation.diagnostic(), file=sys.stderr)
        return 1

    print(
        "architecture checks passed: "
        f"{file_count} Swift files, "
        f"{len(GLOBAL_FRAMEWORK_BOUNDARIES) + len(APP_FRAMEWORK_BOUNDARIES)} framework boundaries, "
        "8 structural contracts"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
