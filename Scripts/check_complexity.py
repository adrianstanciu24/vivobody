#!/usr/bin/env python3
#
#  check_complexity.py
#  vivobody
#
#  Cyclomatic-complexity ratchet for production Swift sources. SwiftLint's
#  SwiftSyntax-based `cyclomatic_complexity` rule supplies the measurements and
#  .swiftlint.yml owns the limit; this script owns the checked-in baseline so
#  existing debt may shrink but never grow, and new functions above the limit
#  are rejected. Entries are keyed by declaration name rather than line number
#  so edits above a function do not invalidate its allowance.
#

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BASELINE = ROOT / "Scripts" / "complexity_baseline.json"
DEFAULT_CONFIG = ROOT / ".swiftlint.yml"
DEFAULT_EXECUTABLE = "swiftlint"

RULE_ID = "cyclomatic_complexity"

# SwiftLint reports "Function should have complexity 10 or less; currently
# complexity is 18". Both numbers are parsed so diagnostics can quote the
# configured limit without duplicating it outside .swiftlint.yml.
REASON_PATTERN = re.compile(
    r"complexity (?P<limit>\d+) or less; currently complexity is (?P<complexity>\d+)"
)

# The reported column is the first token of the declaration, so the name is
# always found by scanning forward from it. `func` covers operators, whose
# names are punctuation rather than identifiers.
DECLARATION_PATTERN = re.compile(
    r"\bfunc\s+(?P<function>\S+?)\s*[(<]|\b(?P<keyword>init|deinit|subscript)\b"
)

UNNAMED = "<unnamed>"


class SwiftLintUnavailable(RuntimeError):
    """Raised when the swiftlint executable is not installed."""


@dataclass(frozen=True, order=True)
class Violation:
    path: str
    line: int
    rule: str
    message: str

    def diagnostic(self) -> str:
        return f"{self.path}:{self.line}: error: [{self.rule}] {self.message}"


@dataclass(frozen=True, order=True)
class Finding:
    """One measured function that SwiftLint reported above the limit."""

    path: str
    line: int
    name: str
    complexity: int
    limit: int


def declaration_name(line: str, column: int) -> str:
    """Return the declaration name at a one-based column, or a stable marker."""

    match = DECLARATION_PATTERN.search(line[max(column - 1, 0):])
    if match is None:
        return UNNAMED
    return match.group("function") or match.group("keyword")


def findings_from_payload(root: Path, payload: object) -> list[Finding]:
    """Convert SwiftLint JSON entries into findings with declaration names."""

    if not isinstance(payload, list):
        raise ValueError("swiftlint JSON output must be a list of violations")

    sources: dict[Path, list[str]] = {}
    findings: list[Finding] = []
    for entry in payload:
        if not isinstance(entry, dict) or entry.get("rule_id") != RULE_ID:
            continue
        reason = entry.get("reason", "")
        match = REASON_PATTERN.search(reason if isinstance(reason, str) else "")
        if match is None:
            raise ValueError(
                f"unrecognized {RULE_ID} reason {reason!r}; "
                "the SwiftLint rule output format changed"
            )
        absolute = Path(str(entry["file"])).resolve()
        if absolute not in sources:
            sources[absolute] = absolute.read_text(encoding="utf-8").splitlines()
        lines = sources[absolute]
        line = int(entry["line"])
        column = int(entry.get("character") or 1)
        text = lines[line - 1] if 0 < line <= len(lines) else ""
        findings.append(Finding(
            path=absolute.relative_to(root).as_posix(),
            line=line,
            name=declaration_name(text, column),
            complexity=int(match.group("complexity")),
            limit=int(match.group("limit")),
        ))
    return sorted(findings)


def keyed_findings(findings: list[Finding]) -> dict[str, dict[str, Finding]]:
    """Group findings by file, disambiguating same-named overloads by order."""

    grouped: dict[str, dict[str, Finding]] = {}
    for finding in sorted(findings):
        entries = grouped.setdefault(finding.path, {})
        key = finding.name
        occurrence = 2
        while key in entries:
            key = f"{finding.name}#{occurrence}"
            occurrence += 1
        entries[key] = finding
    return grouped


def run_swiftlint(
    root: Path,
    config: Path | None,
    executable: str,
) -> list[dict[str, object]]:
    """Run SwiftLint and return its parsed JSON report."""

    if shutil.which(executable) is None:
        raise SwiftLintUnavailable(
            f"{executable} not installed; install it with 'brew install swiftlint'"
        )
    command = [executable, "lint", "--quiet", "--reporter", "json"]
    if config is not None:
        command.extend(["--config", str(config)])
    # SwiftLint exits non-zero when it reports error-severity violations, which
    # is an expected state here; only unreadable output is treated as failure.
    completed = subprocess.run(
        command,
        cwd=root,
        capture_output=True,
        text=True,
        check=False,
    )
    output = completed.stdout.strip()
    if not output:
        if completed.returncode != 0:
            raise ValueError(
                f"{executable} failed: {completed.stderr.strip() or completed.returncode}"
            )
        return []
    try:
        return json.loads(output)
    except json.JSONDecodeError as error:
        raise ValueError(f"{executable} produced unreadable output: {error}") from error


def collect(root: Path, config: Path | None, executable: str) -> list[Finding]:
    return findings_from_payload(root, run_swiftlint(root, config, executable))


def load_baseline(path: Path) -> dict[str, dict[str, int]]:
    """Load the checked-in allowances.

    The limit itself lives in .swiftlint.yml, so the baseline records only the
    measured complexity of functions that already exceed it:

    {"files": {"vivobody/App/DebugSeed.swift": {"seedIfRequested": 12}}}
    """

    data = json.loads(path.read_text(encoding="utf-8"))
    files = data.get("files") if isinstance(data, dict) else None
    if not isinstance(files, dict):
        raise ValueError("baseline files must be a dictionary")
    for file_path, entries in files.items():
        if not isinstance(file_path, str) or not isinstance(entries, dict):
            raise ValueError("baseline files must map paths to entry dictionaries")
        for key, value in entries.items():
            if (
                not isinstance(key, str)
                or not isinstance(value, int)
                or isinstance(value, bool)
                or value < 1
            ):
                raise ValueError("baseline entries must map names to positive complexities")
    return {path: dict(entries) for path, entries in files.items()}


def compare(
    current: dict[str, dict[str, Finding]],
    baseline: dict[str, dict[str, int]],
) -> list[Violation]:
    violations: list[Violation] = []

    for path, entries in sorted(baseline.items()):
        measured = current.get(path, {})
        for key, allowance in sorted(entries.items()):
            finding = measured.get(key)
            if finding is None:
                violations.append(Violation(
                    path,
                    1,
                    "COMPLEX003",
                    f"baseline entry `{key}` is stale; it is gone or now within the "
                    "limit, so run Scripts/check_complexity.py --update",
                ))
            elif finding.complexity > allowance:
                violations.append(Violation(
                    path,
                    finding.line,
                    "COMPLEX001",
                    f"`{key}` grew from complexity {allowance} to {finding.complexity}; "
                    "split it or extract the branching",
                ))
            elif finding.complexity < allowance:
                violations.append(Violation(
                    path,
                    finding.line,
                    "COMPLEX004",
                    f"`{key}` shrank from complexity {allowance} to {finding.complexity}; "
                    "run Scripts/check_complexity.py --update to lock in the gain",
                ))

    for path, entries in sorted(current.items()):
        allowances = baseline.get(path, {})
        for key, finding in sorted(entries.items()):
            if key not in allowances:
                violations.append(Violation(
                    path,
                    finding.line,
                    "COMPLEX002",
                    f"new function `{key}` has complexity {finding.complexity}; "
                    f"keep new code at or below {finding.limit}",
                ))

    return sorted(violations)


def check(
    root: Path,
    baseline_path: Path,
    config: Path | None = None,
    executable: str = DEFAULT_EXECUTABLE,
) -> tuple[list[Violation], int, int]:
    """Return (violations, measured function count, baseline allowance count)."""

    baseline = load_baseline(baseline_path)
    current = keyed_findings(collect(root, config, executable))
    allowance_count = sum(len(entries) for entries in baseline.values())
    measured_count = sum(len(entries) for entries in current.values())
    return compare(current, baseline), measured_count, allowance_count


def write_baseline(
    root: Path,
    baseline_path: Path,
    config: Path | None,
    executable: str,
) -> int:
    current = keyed_findings(collect(root, config, executable))
    files = {
        path: {key: finding.complexity for key, finding in sorted(entries.items())}
        for path, entries in sorted(current.items())
    }
    baseline_path.write_text(
        json.dumps({"files": files}, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return sum(len(entries) for entries in files.values())


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check the production Swift cyclomatic-complexity ratchet."
    )
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--baseline", type=Path, default=DEFAULT_BASELINE)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--swiftlint", default=DEFAULT_EXECUTABLE)
    parser.add_argument("--update", action="store_true", help="Rewrite the baseline from current sources.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    root = args.root.resolve()
    baseline_path = args.baseline
    if not baseline_path.is_absolute():
        baseline_path = root / baseline_path

    try:
        if args.update:
            count = write_baseline(root, baseline_path, args.config, args.swiftlint)
            print(f"Updated complexity baseline with {count} allowance(s): {baseline_path}")
            return 0
        violations, measured_count, allowance_count = check(
            root,
            baseline_path,
            args.config,
            args.swiftlint,
        )
    except SwiftLintUnavailable as error:
        print(f"warning: skipping cyclomatic-complexity check; {error}", file=sys.stderr)
        return 0
    except (OSError, ValueError) as error:
        print(f"error: complexity check failed: {error}", file=sys.stderr)
        return 1

    if violations:
        for violation in violations:
            print(violation.diagnostic(), file=sys.stderr)
        print(f"Complexity ratchet failed with {len(violations)} violation(s).", file=sys.stderr)
        return 1
    print(
        f"Complexity ratchet passed: {measured_count} function(s) above the limit, "
        f"{allowance_count} existing allowances."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
