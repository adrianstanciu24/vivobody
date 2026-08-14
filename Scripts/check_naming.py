#!/usr/bin/env python3
#
#  check_naming.py
#  vivobody
#
#  Enforces the repository's Swift naming conventions: PascalCase for type
#  declarations and lowerCamelCase for functions, properties, and enum case
#  declarations. Comments and strings are masked before scanning so prose
#  and UI copy never look like declarations, and enum bodies are tracked by
#  brace depth so switch patterns are never mistaken for case declarations.
#  The conventions themselves are documented in engineering/quality.md.
#

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


SCRIPTS_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPTS_ROOT))

from check_architecture import (  # noqa: E402
    Violation,
    discovered_swift_paths,
    line_number,
    mask_swift,
)


ROOT = Path(__file__).resolve().parents[1]

PASCAL_CASE = re.compile(r"[A-Z][A-Za-z0-9]*\Z")
LOWER_CAMEL_CASE = re.compile(r"[a-z][A-Za-z0-9]*\Z")

# A type keyword followed by another declaration keyword (`class var`,
# `enum case`) is a modifier position, not a type declaration.
DECLARATION_KEYWORDS = frozenset({
    "actor",
    "associatedtype",
    "case",
    "class",
    "deinit",
    "enum",
    "extension",
    "func",
    "init",
    "let",
    "protocol",
    "struct",
    "subscript",
    "typealias",
    "var",
})

TYPE_DECL_PATTERN = re.compile(
    r"\b(?:class|struct|enum|protocol|actor|typealias|associatedtype)"
    r"\s+([A-Za-z_][A-Za-z0-9_]*)"
)
# Requiring `(` or `<` after the name skips operator declarations
# (`static func ==`) and backticked keywords, which have no casing.
FUNC_DECL_PATTERN = re.compile(r"\bfunc\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?=[(<])")
PROP_DECL_PATTERN = re.compile(r"\b(?:var|let)\s+([A-Za-z_][A-Za-z0-9_]*)")

# Tracks `enum Name ... {` openings, other braces, and `case` keywords in one
# pass so a `case` directly inside an enum body can be told apart from a
# switch pattern nested in a member function or computed property.
STRUCTURE_PATTERN = re.compile(
    r"\benum\s+[A-Za-z_][A-Za-z0-9_]*[^{}]*\{|\{|\}|\bcase\b"
)
IDENTIFIER_PATTERN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def parse_case_names(code: str, start: int) -> list[tuple[str, int]]:
    """Parse the identifiers declared by one enum `case` declaration.

    `start` is the offset just after the `case` keyword. Declarations end at
    the newline; associated-value clauses are skipped with balanced parens
    and raw-value clauses (already string-masked) are skipped to the next
    comma, so `case lb, kg` and `case foo(Int)` both yield their names.
    """

    names: list[tuple[str, int]] = []
    index = start
    expect_name = True
    while index < len(code):
        char = code[index]
        if char in "\r\n":
            break
        if char.isspace():
            index += 1
            continue
        if expect_name:
            match = IDENTIFIER_PATTERN.match(code, index)
            if match is None:
                break
            names.append((match.group(0), match.start()))
            index = match.end()
            expect_name = False
            continue
        if char == "(":
            depth = 0
            while index < len(code):
                if code[index] == "(":
                    depth += 1
                elif code[index] == ")":
                    depth -= 1
                    if depth == 0:
                        index += 1
                        break
                elif code[index] in "\r\n":
                    break
                index += 1
            continue
        if char == "=":
            while index < len(code) and code[index] not in ",\r\n":
                index += 1
            continue
        if char == ",":
            expect_name = True
            index += 1
            continue
        break
    return names


def check_swift_file(path: str, source: str) -> list[Violation]:
    violations: list[Violation] = []
    code = mask_swift(source).code

    for match in TYPE_DECL_PATTERN.finditer(code):
        name = match.group(1)
        if name in DECLARATION_KEYWORDS:
            continue
        if not PASCAL_CASE.fullmatch(name):
            violations.append(Violation(
                path,
                line_number(code, match.start(1)),
                "NAME001",
                f"Type `{name}` must be PascalCase (e.g. WorkoutSessionController).",
            ))

    for match in FUNC_DECL_PATTERN.finditer(code):
        name = match.group(1)
        if not LOWER_CAMEL_CASE.fullmatch(name):
            violations.append(Violation(
                path,
                line_number(code, match.start(1)),
                "NAME002",
                f"Function `{name}` must be lowerCamelCase (e.g. restoreSession).",
            ))

    for match in PROP_DECL_PATTERN.finditer(code):
        name = match.group(1)
        if name in DECLARATION_KEYWORDS:
            continue
        if not LOWER_CAMEL_CASE.fullmatch(name):
            violations.append(Violation(
                path,
                line_number(code, match.start(1)),
                "NAME003",
                f"Property `{name}` must be lowerCamelCase (e.g. peekWidth).",
            ))

    enum_body_depths: list[bool] = []
    for match in STRUCTURE_PATTERN.finditer(code):
        token = match.group(0)
        if token == "{":
            enum_body_depths.append(False)
            continue
        if token == "}":
            if enum_body_depths:
                enum_body_depths.pop()
            continue
        if token.startswith("enum"):
            enum_body_depths.append(True)
            continue
        # `case` keyword: a declaration only when the innermost brace scope
        # is an enum body; anything deeper is a switch pattern.
        if enum_body_depths and enum_body_depths[-1]:
            for name, offset in parse_case_names(code, match.end()):
                if not LOWER_CAMEL_CASE.fullmatch(name):
                    violations.append(Violation(
                        path,
                        line_number(code, offset),
                        "NAME004",
                        f"Enum case `{name}` must be lowerCamelCase (e.g. case bodyweightAdded).",
                    ))

    return violations


def check_repository(root: Path = ROOT) -> tuple[list[Violation], int]:
    paths = discovered_swift_paths(root)
    violations: list[Violation] = []
    for path in paths:
        relative = path.relative_to(root).as_posix()
        violations.extend(
            check_swift_file(relative, path.read_text(encoding="utf-8"))
        )
    return sorted(set(violations)), len(paths)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check Vivobody's Swift naming conventions."
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
            f"naming check failed: {len(violations)} violation(s)",
            file=sys.stderr,
        )
        for violation in violations:
            print(violation.diagnostic(), file=sys.stderr)
        return 1

    print(
        "naming checks passed: "
        f"{file_count} Swift files, "
        "4 naming conventions"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
