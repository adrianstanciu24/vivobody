#!/usr/bin/env python3
#
#  test_check_naming.py
#  vivobody
#
#  Mutation tests for the Swift naming-convention checker. Each fixture
#  introduces one casing violation and proves the diagnostic fires, while
#  operators, backticked keywords, tuple destructuring, switch patterns,
#  comments, and strings remain valid so the guardrail stays signal instead
#  of regex noise.
#

from __future__ import annotations

import sys
import unittest
from pathlib import Path


SCRIPTS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_ROOT))

import check_naming  # noqa: E402


class NamingCheckerTests(unittest.TestCase):
    def rules_for(self, body: str) -> set[str]:
        return {
            violation.rule
            for violation in check_naming.check_swift_file(
                "vivobody/Models/Fixture.swift",
                body,
            )
        }

    def test_canonical_conventions_pass(self) -> None:
        rules = self.rules_for("""struct WorkoutSessionController {
    let peekWidth: Double
    func restoreSession() {}
}

enum LoadMode {
    case bodyweightAdded, assistanceSubtracted
    case external(WeightSource)
    case custom = 1
}
""")
        self.assertEqual(rules, set())

    def test_type_names_must_be_pascal_case(self) -> None:
        self.assertIn("NAME001", self.rules_for("struct vivobodyApp {}\n"))
        self.assertIn("NAME001", self.rules_for("enum workout_store {}\n"))
        self.assertIn("NAME001", self.rules_for("typealias handler = () -> Void\n"))
        self.assertIn("NAME001", self.rules_for("protocol rest_timer {}\n"))

    def test_modifier_positions_are_not_type_declarations(self) -> None:
        rules = self.rules_for("""final class Fixture {
    override class var runsForEachTargetApplicationUIConfiguration: Bool { false }
    class func makeDefault() -> Fixture { Fixture() }
}
""")
        self.assertNotIn("NAME001", rules)

    def test_functions_must_be_lower_camel_case(self) -> None:
        self.assertIn("NAME002", self.rules_for("func RestoreSession() {}\n"))
        self.assertIn("NAME002", self.rules_for("func restore_session() {}\n"))
        self.assertIn("NAME002", self.rules_for("func Load_All<T>(_ value: T) {}\n"))

    def test_operators_and_backticked_functions_are_exempt(self) -> None:
        rules = self.rules_for("""static func == (lhs: Fixture, rhs: Fixture) -> Bool { true }
func `repeat`() {}
""")
        self.assertNotIn("NAME002", rules)

    def test_properties_must_be_lower_camel_case(self) -> None:
        self.assertIn("NAME003", self.rules_for("let W = geo.size.width\n"))
        self.assertIn("NAME003", self.rules_for("var card_width = 0.0\n"))
        self.assertIn("NAME003", self.rules_for("static let MaxRetries = 3\n"))

    def test_tuple_destructuring_and_optional_binding_pass(self) -> None:
        rules = self.rules_for("""let (width, height) = pair
if let container = container { _ = container }
guard let self = self else { return }
""")
        self.assertNotIn("NAME003", rules)

    def test_enum_cases_must_be_lower_camel_case(self) -> None:
        self.assertIn("NAME004", self.rules_for("enum Phase { case High }\n"))
        self.assertIn("NAME004", self.rules_for("enum Phase {\n    case low, High_Contrast\n}\n"))
        self.assertIn("NAME004", self.rules_for("enum Phase {\n    indirect case Wrapped(Phase)\n}\n"))

    def test_switch_patterns_inside_enums_are_not_declarations(self) -> None:
        rules = self.rules_for("""enum Phase {
    case high
    case low

    var isActive: Bool {
        switch self {
        case .high:
            return true
        case .low:
            return false
        }
    }

    func combine(_ other: Phase) -> Bool {
        switch (self, other) {
        case let (
            .high,
            .low
        ):
            return true
        case (.low, _):
            return false
        default:
            return false
        }
    }
}
""")
        self.assertEqual(rules, set())

    def test_nested_type_cases_still_checked(self) -> None:
        rules = self.rules_for("""struct Outer {
    enum Inner {
        case Bad
    }
}
""")
        self.assertIn("NAME004", rules)

    def test_comments_and_strings_do_not_look_like_declarations(self) -> None:
        rules = self.rules_for("""// struct rogue_type {}
// func BadName() {}
/* enum broken { case Upper } */
let guidance = "let SCREAMING = 1; func Bad() {}; struct lower {}"
let block = \"\"\"
enum hidden { case Nope }
\"\"\"
""")
        self.assertEqual(rules, set())


if __name__ == "__main__":
    unittest.main()
