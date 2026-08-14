#!/usr/bin/env python3
#
#  test_check_complexity.py
#  vivobody
#
#  Tests for the cyclomatic-complexity ratchet. The parsing and ratchet layers
#  are exercised with synthetic SwiftLint reports so they run without the
#  binary; a guarded integration test proves the real rule still measures the
#  declarations this repository cares about.
#

from __future__ import annotations

import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPTS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_ROOT))

import check_complexity  # noqa: E402


SWIFTLINT_AVAILABLE = shutil.which(check_complexity.DEFAULT_EXECUTABLE) is not None

SWIFTLINT_CONFIG = """only_rules:
  - cyclomatic_complexity

cyclomatic_complexity:
  warning: 10
  error: 20
  ignores_case_statements: false

included:
  - Sources
"""


def report(file: Path, line: int, character: int, complexity: int, limit: int = 10) -> dict:
    return {
        "character": character,
        "file": str(file),
        "line": line,
        "reason": (
            f"Function should have complexity {limit} or less; "
            f"currently complexity is {complexity}"
        ),
        "rule_id": "cyclomatic_complexity",
        "severity": "Warning",
        "type": "Cyclomatic Complexity",
    }


def finding(path: str, line: int, name: str, complexity: int) -> check_complexity.Finding:
    return check_complexity.Finding(
        path=path,
        line=line,
        name=name,
        complexity=complexity,
        limit=10,
    )


class DeclarationNameTests(unittest.TestCase):
    def name(self, line: str, column: int = 1) -> str:
        return check_complexity.declaration_name(line, column)

    def test_plain_function(self) -> None:
        self.assertEqual(self.name("func handle(_ action: IncomingAction) {", 1), "handle")

    def test_modifiers_before_declaration(self) -> None:
        line = "    private static func startUpdatePumpIfNeeded() {"
        self.assertEqual(self.name(line, 5), "startUpdatePumpIfNeeded")

    def test_generic_function(self) -> None:
        self.assertEqual(self.name("static func compute<T>(values: [T]) {", 1), "compute")

    def test_multiline_signature(self) -> None:
        self.assertEqual(self.name("    func consistency(", 5), "consistency")

    def test_operator_function(self) -> None:
        self.assertEqual(self.name("static func == (lhs: K, rhs: K) -> Bool {", 1), "==")

    def test_initializer(self) -> None:
        self.assertEqual(self.name("init(session: WorkoutSession) {", 1), "init")

    def test_unrecognized_declaration(self) -> None:
        self.assertEqual(self.name("let value = 0", 1), check_complexity.UNNAMED)


class PayloadParsingTests(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name).resolve()
        self.source = self.root / "vivobody" / "Sample.swift"
        self.source.parent.mkdir(parents=True)
        self.source.write_text(
            "struct Sample {\n"
            "    func alpha(_ value: Int) -> Int {\n"
            "        return value\n"
            "    }\n"
            "    func beta(_ value: String) -> String {\n"
            "        return value\n"
            "    }\n"
            "}\n",
            encoding="utf-8",
        )

    def test_parses_name_complexity_and_limit(self) -> None:
        findings = check_complexity.findings_from_payload(
            self.root,
            [report(self.source, 2, 5, complexity=18)],
        )
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0].path, "vivobody/Sample.swift")
        self.assertEqual(findings[0].name, "alpha")
        self.assertEqual(findings[0].complexity, 18)
        self.assertEqual(findings[0].limit, 10)

    def test_ignores_other_rules(self) -> None:
        entry = report(self.source, 2, 5, complexity=18)
        entry["rule_id"] = "line_length"
        self.assertEqual(check_complexity.findings_from_payload(self.root, [entry]), [])

    def test_unrecognized_reason_fails_loudly(self) -> None:
        entry = report(self.source, 2, 5, complexity=18)
        entry["reason"] = "Function is too complex"
        with self.assertRaises(ValueError):
            check_complexity.findings_from_payload(self.root, [entry])

    def test_non_list_payload_fails(self) -> None:
        with self.assertRaises(ValueError):
            check_complexity.findings_from_payload(self.root, {"file": "x"})

    def test_overloads_are_disambiguated_by_order(self) -> None:
        keyed = check_complexity.keyed_findings([
            finding("vivobody/Sample.swift", 2, "alpha", 12),
            finding("vivobody/Sample.swift", 40, "alpha", 15),
        ])
        self.assertEqual(
            {key: value.complexity for key, value in keyed["vivobody/Sample.swift"].items()},
            {"alpha": 12, "alpha#2": 15},
        )


class RatchetTests(unittest.TestCase):
    def compare(self, findings: list, baseline: dict) -> set[str]:
        violations = check_complexity.compare(
            check_complexity.keyed_findings(findings),
            baseline,
        )
        return {violation.rule for violation in violations}

    def test_matching_baseline_passes(self) -> None:
        rules = self.compare(
            [finding("vivobody/Sample.swift", 12, "alpha", 18)],
            {"vivobody/Sample.swift": {"alpha": 18}},
        )
        self.assertEqual(rules, set())

    def test_growth_fails(self) -> None:
        rules = self.compare(
            [finding("vivobody/Sample.swift", 12, "alpha", 19)],
            {"vivobody/Sample.swift": {"alpha": 18}},
        )
        self.assertEqual(rules, {"COMPLEX001"})

    def test_new_violation_fails(self) -> None:
        rules = self.compare(
            [finding("vivobody/Sample.swift", 12, "alpha", 14)],
            {},
        )
        self.assertEqual(rules, {"COMPLEX002"})

    def test_stale_entry_fails(self) -> None:
        rules = self.compare([], {"vivobody/Sample.swift": {"alpha": 18}})
        self.assertEqual(rules, {"COMPLEX003"})

    def test_shrink_requires_baseline_update(self) -> None:
        rules = self.compare(
            [finding("vivobody/Sample.swift", 12, "alpha", 15)],
            {"vivobody/Sample.swift": {"alpha": 18}},
        )
        self.assertEqual(rules, {"COMPLEX004"})

    def test_moving_a_function_does_not_break_its_allowance(self) -> None:
        baseline = {"vivobody/Sample.swift": {"alpha": 18}}
        for line in (12, 400, 1):
            with self.subTest(line=line):
                rules = self.compare(
                    [finding("vivobody/Sample.swift", line, "alpha", 18)],
                    baseline,
                )
                self.assertEqual(rules, set())

    def test_diagnostic_names_the_function_and_line(self) -> None:
        violations = check_complexity.compare(
            check_complexity.keyed_findings([finding("vivobody/Sample.swift", 12, "alpha", 19)]),
            {"vivobody/Sample.swift": {"alpha": 18}},
        )
        self.assertEqual(
            violations[0].diagnostic(),
            "vivobody/Sample.swift:12: error: [COMPLEX001] `alpha` grew from complexity "
            "18 to 19; split it or extract the branching",
        )


class BaselineFileTests(unittest.TestCase):
    def load(self, payload: object) -> dict:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "baseline.json"
            path.write_text(json.dumps(payload), encoding="utf-8")
            return check_complexity.load_baseline(path)

    def test_valid_baseline(self) -> None:
        self.assertEqual(
            self.load({"files": {"vivobody/Sample.swift": {"alpha": 18}}}),
            {"vivobody/Sample.swift": {"alpha": 18}},
        )

    def test_missing_files_key_fails(self) -> None:
        with self.assertRaises(ValueError):
            self.load({"threshold": 10})

    def test_non_integer_complexity_fails(self) -> None:
        with self.assertRaises(ValueError):
            self.load({"files": {"vivobody/Sample.swift": {"alpha": "18"}}})

    def test_non_positive_complexity_fails(self) -> None:
        with self.assertRaises(ValueError):
            self.load({"files": {"vivobody/Sample.swift": {"alpha": 0}}})

    def test_repository_baseline_is_valid(self) -> None:
        self.assertIsInstance(
            check_complexity.load_baseline(check_complexity.DEFAULT_BASELINE),
            dict,
        )


@unittest.skipUnless(SWIFTLINT_AVAILABLE, "swiftlint is not installed")
class SwiftLintIntegrationTests(unittest.TestCase):
    def collect(self, body: str) -> list[check_complexity.Finding]:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        root = Path(directory.name).resolve()
        (root / ".swiftlint.yml").write_text(SWIFTLINT_CONFIG, encoding="utf-8")
        source = root / "Sources" / "Fixture.swift"
        source.parent.mkdir(parents=True)
        source.write_text(body, encoding="utf-8")
        return check_complexity.collect(
            root,
            root / ".swiftlint.yml",
            check_complexity.DEFAULT_EXECUTABLE,
        )

    def test_simple_function_is_not_reported(self) -> None:
        self.assertEqual(self.collect("func simple() -> Int { return 0 }\n"), [])

    def test_branching_function_is_reported_with_its_name(self) -> None:
        branches = "\n".join(f"    if value == {index} {{ return {index} }}" for index in range(11))
        findings = self.collect(f"func branchy(value: Int) -> Int {{\n{branches}\n    return 0\n}}\n")
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0].name, "branchy")
        self.assertEqual(findings[0].complexity, 11)
        self.assertEqual(findings[0].limit, 10)

    def test_closure_default_argument_does_not_hide_the_body(self) -> None:
        # A multi-line signature whose first brace belongs to a parameter
        # default is the shape that the previous hand-rolled parser measured as
        # complexity 1, silently exempting most of the analytics layer.
        branches = "\n".join(f"    if value == {index} {{ return {index} }}" for index in range(11))
        findings = self.collect(
            "func cancellable(\n"
            "    value: Int,\n"
            "    isCancelled: @Sendable () -> Bool = { false }\n"
            ") -> Int {\n"
            f"{branches}\n"
            "    return 0\n"
            "}\n"
        )
        self.assertEqual(len(findings), 1)
        self.assertEqual(findings[0].name, "cancellable")
        self.assertEqual(findings[0].complexity, 11)

    def test_data_enum_is_not_reported(self) -> None:
        cases = "\n".join(f"    case value{index}" for index in range(40))
        self.assertEqual(self.collect(f"enum Big: String {{\n{cases}\n}}\n"), [])

    def test_optional_properties_are_not_reported(self) -> None:
        properties = "\n".join(f"    var value{index}: String?" for index in range(20))
        self.assertEqual(self.collect(f"struct Holder {{\n{properties}\n}}\n"), [])

    def test_missing_executable_is_reported_as_unavailable(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(check_complexity.SwiftLintUnavailable):
                check_complexity.collect(Path(directory), None, "swiftlint-not-installed")

    def test_end_to_end_update_then_check(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        root = Path(directory.name).resolve()
        config = root / ".swiftlint.yml"
        config.write_text(SWIFTLINT_CONFIG, encoding="utf-8")
        source = root / "Sources" / "Fixture.swift"
        source.parent.mkdir(parents=True)
        branches = "\n".join(f"    if value == {index} {{ return {index} }}" for index in range(11))
        source.write_text(
            f"func branchy(value: Int) -> Int {{\n{branches}\n    return 0\n}}\n",
            encoding="utf-8",
        )
        baseline = root / "baseline.json"

        written = check_complexity.write_baseline(
            root,
            baseline,
            config,
            check_complexity.DEFAULT_EXECUTABLE,
        )
        self.assertEqual(written, 1)
        self.assertEqual(
            check_complexity.load_baseline(baseline),
            {"Sources/Fixture.swift": {"branchy": 11}},
        )

        violations, measured, allowances = check_complexity.check(root, baseline, config)
        self.assertEqual(violations, [])
        self.assertEqual((measured, allowances), (1, 1))

        # Prepending unrelated code shifts every line but must not disturb the
        # allowance, which is the failure mode of a line-keyed baseline.
        source.write_text("// leading comment\n\n" + source.read_text(encoding="utf-8"), encoding="utf-8")
        self.assertEqual(check_complexity.check(root, baseline, config)[0], [])

        source.write_text(
            source.read_text(encoding="utf-8").replace(
                "    return 0\n}",
                "    if value == 99 { return 99 }\n    return 0\n}",
            ),
            encoding="utf-8",
        )
        violations, _, _ = check_complexity.check(root, baseline, config)
        self.assertEqual([violation.rule for violation in violations], ["COMPLEX001"])


if __name__ == "__main__":
    unittest.main()
