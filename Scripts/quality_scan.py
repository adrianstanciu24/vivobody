#!/usr/bin/env python3
#
#  quality_scan.py
#  vivobody
#
#  Produces a deterministic manual maintenance report by aggregating enforced
#  repository checks with explicitly report-only heuristics for stale knowledge,
#  orphaned screens, and repeated screen-level UI surface expressions.
#

from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from datetime import date
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "Scripts"))

import check_architecture  # noqa: E402
import check_complexity  # noqa: E402
import check_documentation  # noqa: E402
import check_source_sizes  # noqa: E402


DATE_PATTERN = re.compile(r"\b(\d{4}-\d{2}-\d{2})\b")
SCREEN_DEFINITION_PATTERN = re.compile(
    r"(?m)^(?!\s*(?:private|fileprivate)\b)\s*"
    r"(?:final\s+)?(?:struct|class)\s+([A-Za-z_][A-Za-z0-9_]*(?:Screen|Sheet))\s*:\s*View\b"
)
UI_SURFACE_TOKENS = (
    "RoundedRectangle(cornerRadius:",
    "Color.white.opacity(",
    ".background(",
)


def markdown_escape(value: str) -> str:
    return value.replace("|", "\\|").replace("`", "\\`")


def swift_sources(root: Path) -> list[Path]:
    paths: list[Path] = []
    for relative_root in (*check_source_sizes.SOURCE_ROOTS, "vivobodyTests", "vivobodyUITests"):
        directory = root / relative_root
        if directory.exists():
            paths.extend(directory.rglob("*.swift"))
    return sorted(set(paths))


def stale_knowledge_records(
    root: Path,
    today: date,
    stale_days: int,
) -> list[tuple[str, int, str, int]]:
    candidates = [root / "specs" / "index.md", root / "engineering" / "tech-debt.md"]
    records: list[tuple[str, int, str, int]] = []
    for path in candidates:
        if not path.is_file():
            continue
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            if path.name == "index.md" and not line.lstrip().startswith("|"):
                continue
            if path.name == "tech-debt.md" and "Last checked:" not in line:
                continue
            matches = DATE_PATTERN.findall(line)
            if not matches:
                continue
            checked = date.fromisoformat(matches[-1])
            age = (today - checked).days
            if age > stale_days:
                records.append((path.relative_to(root).as_posix(), line_number, matches[-1], age))
    return records


def orphaned_screen_candidates(root: Path) -> list[tuple[str, str, int]]:
    sources = swift_sources(root)
    contents = {}
    for path in sources:
        source = path.read_text(encoding="utf-8")
        contents[path] = (source, check_architecture.mask_swift(source).code)
    candidates: list[tuple[str, str, int]] = []
    for path, (source, code) in contents.items():
        if "/Screens/" not in path.as_posix():
            continue
        for match in SCREEN_DEFINITION_PATTERN.finditer(code):
            name = match.group(1)
            referenced_files = [
                candidate
                for candidate, (_, candidate_code) in contents.items()
                if re.search(rf"\b{re.escape(name)}\b", candidate_code)
            ]
            if referenced_files == [path]:
                candidates.append(
                    (
                        name,
                        path.relative_to(root).as_posix(),
                        source.count("\n", 0, match.start()) + 1,
                    )
                )
    return sorted(candidates)


def normalized_surface_line(line: str) -> str | None:
    stripped = " ".join(line.strip().split())
    if not stripped or stripped.startswith("//"):
        return None
    if not any(token in stripped for token in UI_SURFACE_TOKENS):
        return None
    return stripped


def duplicated_ui_surface_candidates(
    root: Path,
    minimum_files: int = 3,
) -> list[tuple[str, tuple[str, ...]]]:
    occurrences: dict[str, set[str]] = defaultdict(set)
    screens = root / "vivobody" / "Screens"
    if not screens.exists():
        return []
    for path in sorted(screens.rglob("*.swift")):
        relative = path.relative_to(root).as_posix()
        for line in path.read_text(encoding="utf-8").splitlines():
            normalized = normalized_surface_line(line)
            if normalized is not None:
                occurrences[normalized].add(relative)
    return sorted(
        (snippet, tuple(sorted(paths)))
        for snippet, paths in occurrences.items()
        if len(paths) >= minimum_files
    )


def bullets(items: Iterable[str], empty: str) -> list[str]:
    values = list(items)
    return [f"- {value}" for value in values] if values else [f"- {empty}"]


def build_report(root: Path, today: date, stale_days: int) -> str:
    documentation = check_documentation.run(root)
    architecture, source_count = check_architecture.check_repository(root)
    size_baseline = root / "Scripts" / "source_size_baseline.json"
    try:
        sizes, production_count, allowance_count = check_source_sizes.check(
            root,
            size_baseline,
        )
    except (OSError, ValueError) as error:
        sizes = [check_source_sizes.Violation(
            "Scripts/source_size_baseline.json",
            1,
            "SIZE000",
            str(error),
        )]
        production_count = 0
        allowance_count = 0
    complexity_baseline = root / "Scripts" / "complexity_baseline.json"
    try:
        complexity, complexity_measured, complexity_allowance_count = check_complexity.check(
            root,
            complexity_baseline,
            root / ".swiftlint.yml",
        )
        complexity_detail = (
            f"{len(complexity)} finding(s), {complexity_measured} function(s) "
            f"over the limit, {complexity_allowance_count} allowances"
        )
        complexity_status = "FAIL" if complexity else "PASS"
    except check_complexity.SwiftLintUnavailable as error:
        complexity = []
        complexity_detail = str(error)
        complexity_status = "SKIP"
    except (OSError, ValueError) as error:
        complexity = [check_complexity.Violation(
            "Scripts/complexity_baseline.json",
            1,
            "COMPLEX000",
            str(error),
        )]
        complexity_detail = f"{len(complexity)} finding(s)"
        complexity_status = "FAIL"
    stale = stale_knowledge_records(root, today, stale_days)
    orphans = orphaned_screen_candidates(root)
    duplicates = duplicated_ui_surface_candidates(root)

    lines = [
        "# Vivobody quality scan",
        "",
        f"- Generated: {today.isoformat()}",
        "- Mode: manual report; scheduling is intentionally disabled",
        f"- Stale-knowledge threshold: {stale_days} days",
        "",
        "## Mechanically enforced signals",
        "",
        "| Signal | Status | Detail |",
        "|---|---|---|",
        f"| Documentation and local paths | {'PASS' if not documentation else 'FAIL'} | {len(documentation)} finding(s) |",
        f"| Architecture and forbidden imports | {'PASS' if not architecture else 'FAIL'} | {len(architecture)} finding(s) across {source_count} Swift files |",
        f"| Source-size ratchet | {'PASS' if not sizes else 'FAIL'} | {len(sizes)} finding(s), {production_count} production files, {allowance_count} allowances |",
        f"| Complexity ratchet | {complexity_status} | {complexity_detail} |",
        "",
        "### Enforced findings",
        "",
    ]
    lines.extend(bullets(
        (f"`{markdown_escape(item.diagnostic())}`" for item in [*documentation, *architecture, *sizes, *complexity]),
        "None.",
    ))
    lines.extend([
        "",
        "## Report-only heuristics",
        "",
        "These findings need human review and do not fail `Scripts/check.sh`.",
        "",
        "### Stale knowledge records",
        "",
    ])
    lines.extend(bullets(
        (
            f"`{path}:{line}` was checked {checked} ({age} days ago)."
            for path, line, checked, age in stale
        ),
        "None.",
    ))
    lines.extend(["", "### Potential orphaned screens and sheets", ""])
    lines.extend(bullets(
        (f"`{name}` is only referenced at its definition: `{path}:{line}`." for name, path, line in orphans),
        "None.",
    ))
    lines.extend(["", "### Repeated screen-level UI surface expressions", ""])
    lines.extend(bullets(
        (
            f"`{markdown_escape(snippet)}` appears in {len(paths)} files: "
            + ", ".join(f"`{path}`" for path in paths)
            for snippet, paths in duplicates
        ),
        "None.",
    ))
    lines.extend([
        "",
        "## Scheduling gate",
        "",
        "Do not schedule this scan yet. Run it manually for at least two or three",
        "maintenance cycles, tune false positives, then record the scheduling",
        "decision separately.",
        "",
    ])
    return "\n".join(lines)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Write the manual Vivobody quality report.")
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--output", type=Path, default=ROOT / ".verify" / "quality-scan.md")
    parser.add_argument("--today", type=date.fromisoformat, default=date.today())
    parser.add_argument("--stale-days", type=int, default=90)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    if args.stale_days < 1:
        print("error: --stale-days must be positive", file=sys.stderr)
        return 2
    root = args.root.resolve()
    output = args.output
    if not output.is_absolute():
        output = root / output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(build_report(root, args.today, args.stale_days), encoding="utf-8")
    print(f"Quality scan written to {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
