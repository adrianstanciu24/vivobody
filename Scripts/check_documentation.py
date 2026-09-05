#!/usr/bin/env python3
#
#  check_documentation.py
#  vivobody
#
#  Keeps the repository knowledge map navigable. It verifies required entry
#  points, local Markdown links, top-level spec indexing, generated inventories,
#  and the rule that volatile schema claims do not accumulate in AGENTS.md.
#

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import unquote

import documentation_inventory

ROOT = Path(__file__).resolve().parents[1]

REQUIRED_FILES = (
    "AGENTS.md",
    "README.md",
    "workout-app-principles.md",
    "worklog.md",
    "ARCHITECTURE.md",
    "engineering/verification.md",
    "engineering/code-review.md",
    "engineering/quality.md",
    "engineering/tech-debt.md",
    "engineering/decisions/README.md",
    "engineering/plans/README.md",
    "engineering/plans/active/README.md",
    "engineering/plans/completed/README.md",
    "specs/index.md",
    "specs/catalog/inventory.md",
    "Scripts/verify_scenarios/README.md",
    "Scripts/verify_scenarios/index.md",
    ".agents/skills/vivobody-add-exercise/SKILL.md",
)

MARKDOWN_LINK_PATTERN = re.compile(
    r"(?<!!)\[[^\]]+\]\((?P<target><[^>]+>|[^)\s]+)"
    r"(?:\s+[\"'][^\"']*[\"'])?\)"
)
EXTERNAL_SCHEME_PATTERN = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")
VOLATILE_AGENTS_PATTERNS = (
    re.compile(r"\bSchemaV\d+\b", re.IGNORECASE),
    re.compile(r"\bcurrent\s+schema\s+(?:is|:)\s*V?\d+\b", re.IGNORECASE),
    re.compile(r"\bschema\s+version\s+(?:is|:)\s*V?\d+\b", re.IGNORECASE),
)


@dataclass(frozen=True, order=True)
class Violation:
    path: str
    line: int
    rule: str
    message: str

    def diagnostic(self) -> str:
        return f"{self.path}:{self.line}: error: [{self.rule}] {self.message}"


def map_documents(root: Path) -> list[Path]:
    paths = list(root.glob("*.md"))
    for directory in ("engineering", "specs", "Scripts/verify_scenarios", ".agents", ".factory"):
        paths.extend((root / directory).rglob("*.md"))
    return sorted({path for path in paths if path.is_file()})


def line_number(source: str, offset: int) -> int:
    return source.count("\n", 0, offset) + 1


def local_target(source_path: Path, raw_target: str, root: Path) -> Path | None:
    target = raw_target[1:-1] if raw_target.startswith("<") else raw_target
    target = unquote(target).split("#", 1)[0].split("?", 1)[0]
    if not target or target.startswith("#") or EXTERNAL_SCHEME_PATTERN.match(target):
        return None
    if target.startswith("/"):
        return root / target.lstrip("/")
    return source_path.parent / target


def check_links(root: Path) -> list[Violation]:
    violations: list[Violation] = []
    for path in map_documents(root):
        source = path.read_text(encoding="utf-8")
        relative = path.relative_to(root).as_posix()
        for match in MARKDOWN_LINK_PATTERN.finditer(source):
            target = local_target(path, match.group("target"), root)
            if target is not None and not target.exists():
                violations.append(
                    Violation(
                        relative,
                        line_number(source, match.start()),
                        "DOC002",
                        f"local link target does not exist: {match.group('target')}",
                    )
                )
    return violations


def check_required_files(root: Path) -> list[Violation]:
    return [
        Violation(path, 1, "DOC001", "required knowledge-map entry is missing")
        for path in REQUIRED_FILES
        if not (root / path).is_file()
    ]


def check_agents_volatility(root: Path) -> list[Violation]:
    path = root / "AGENTS.md"
    if not path.is_file():
        return []
    source = path.read_text(encoding="utf-8")
    violations: list[Violation] = []
    for pattern in VOLATILE_AGENTS_PATTERNS:
        for match in pattern.finditer(source):
            violations.append(
                Violation(
                    "AGENTS.md",
                    line_number(source, match.start()),
                    "DOC003",
                    "keep concrete schema versions in persistence source or a migration plan",
                )
            )
    return violations


def check_spec_index(root: Path) -> list[Violation]:
    index_path = root / "specs/index.md"
    if not index_path.is_file():
        return []
    index = index_path.read_text(encoding="utf-8")
    violations: list[Violation] = []
    for spec in sorted((root / "specs").glob("*.md")):
        if spec.name == "index.md":
            continue
        if spec.name not in index:
            violations.append(
                Violation(
                    spec.relative_to(root).as_posix(),
                    1,
                    "DOC004",
                    "top-level specification is missing from specs/index.md",
                )
            )
    return violations


def check_inventories(root: Path) -> list[Violation]:
    try:
        return [
            Violation(path, 1, "DOC005", "generated inventory is stale; run /usr/bin/python3 Scripts/documentation_inventory.py --write")
            for path in documentation_inventory.stale_documents(root)
        ]
    except (OSError, ValueError, KeyError, TypeError) as error:
        return [Violation("Scripts/documentation_inventory.py", 1, "DOC005", f"cannot read inventory inputs: {error}")]


def run(root: Path = ROOT) -> list[Violation]:
    return sorted(
        check_required_files(root)
        + check_links(root)
        + check_agents_volatility(root)
        + check_spec_index(root)
        + check_inventories(root)
    )


def main() -> int:
    violations = run()
    if violations:
        for violation in violations:
            print(violation.diagnostic(), file=sys.stderr)
        print(
            f"Documentation check failed with {len(violations)} violation(s).",
            file=sys.stderr,
        )
        return 1
    print("Documentation knowledge map passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
