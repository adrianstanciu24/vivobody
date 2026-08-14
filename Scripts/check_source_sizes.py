#!/usr/bin/env python3
#
#  check_source_sizes.py
#  vivobody
#
#  Ratchets oversized production Swift files against a checked-in baseline.
#  Existing debt may shrink or be split, but new oversized files and growth are
#  rejected. A shrink must update the baseline so removed entropy cannot return.
#

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BASELINE = ROOT / "Scripts" / "source_size_baseline.json"
SOURCE_ROOTS = (
    "vivobody",
    "vivobodyWidgets",
    "VivoKit/Sources",
)


@dataclass(frozen=True, order=True)
class Violation:
    path: str
    line: int
    rule: str
    message: str

    def diagnostic(self) -> str:
        return f"{self.path}:{self.line}: error: [{self.rule}] {self.message}"


def physical_line_count(path: Path) -> int:
    return len(path.read_text(encoding="utf-8").splitlines())


def discovered_sources(root: Path) -> dict[str, int]:
    sources: dict[str, int] = {}
    for relative_root in SOURCE_ROOTS:
        directory = root / relative_root
        if not directory.exists():
            continue
        for path in sorted(directory.rglob("*.swift")):
            relative = path.relative_to(root).as_posix()
            sources[relative] = physical_line_count(path)
    return sources


def load_baseline(path: Path) -> tuple[int, dict[str, int]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    threshold = data.get("threshold")
    files = data.get("files")
    if not isinstance(threshold, int) or isinstance(threshold, bool) or threshold < 1:
        raise ValueError("baseline threshold must be a positive integer")
    if not isinstance(files, dict) or not all(
        isinstance(key, str)
        and isinstance(value, int)
        and not isinstance(value, bool)
        and value > threshold
        for key, value in files.items()
    ):
        raise ValueError("baseline files must map paths to line counts above threshold")
    return threshold, dict(files)


def check(
    root: Path,
    baseline_path: Path,
) -> tuple[list[Violation], int, int]:
    threshold, baseline = load_baseline(baseline_path)
    sources = discovered_sources(root)
    violations: list[Violation] = []

    for path, allowance in sorted(baseline.items()):
        current = sources.get(path)
        if current is None:
            violations.append(Violation(
                path,
                1,
                "SIZE003",
                "baseline entry is stale; remove it after deleting or moving the file",
            ))
        elif current > allowance:
            violations.append(Violation(
                path,
                current,
                "SIZE001",
                f"oversized file grew from its {allowance}-line baseline to {current}; split or shrink it",
            ))
        elif current < allowance:
            violations.append(Violation(
                path,
                current,
                "SIZE004",
                f"file shrank from {allowance} to {current} lines; lower the baseline to lock in the gain",
            ))

    for path, current in sorted(sources.items()):
        if current > threshold and path not in baseline:
            violations.append(Violation(
                path,
                current,
                "SIZE002",
                f"new oversized file has {current} lines; keep new files at or below {threshold}",
            ))

    return sorted(violations), len(sources), len(baseline)


def write_baseline(root: Path, baseline_path: Path, threshold: int) -> None:
    files = {
        path: count
        for path, count in discovered_sources(root).items()
        if count > threshold
    }
    baseline_path.write_text(
        json.dumps({"threshold": threshold, "files": files}, indent=2, sort_keys=True)
        + "\n",
        encoding="utf-8",
    )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Check the production Swift source-size ratchet.")
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--baseline", type=Path, default=DEFAULT_BASELINE)
    parser.add_argument("--update", action="store_true", help="Rewrite the baseline from current files.")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    root = args.root.resolve()
    baseline_path = args.baseline
    if not baseline_path.is_absolute():
        baseline_path = root / baseline_path

    if args.update:
        threshold = load_baseline(baseline_path)[0]
        write_baseline(root, baseline_path, threshold)
        print(f"Updated source-size baseline: {baseline_path}")
        return 0

    try:
        violations, source_count, allowance_count = check(root, baseline_path)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"error: invalid source-size baseline: {error}", file=sys.stderr)
        return 1
    if violations:
        for violation in violations:
            print(violation.diagnostic(), file=sys.stderr)
        print(f"Source-size ratchet failed with {len(violations)} violation(s).", file=sys.stderr)
        return 1
    print(
        f"Source-size ratchet passed: {source_count} Swift files, "
        f"{allowance_count} existing oversized allowances."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
