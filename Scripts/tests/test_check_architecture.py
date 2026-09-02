#!/usr/bin/env python3
#
#  test_check_architecture.py
#  vivobody
#
#  Mutation tests for the repository architecture checker. Each fixture
#  introduces one forbidden pattern and proves the diagnostic identifies the
#  exact contract, while comments, strings, and documented exceptions remain
#  valid so the guardrail stays useful instead of becoming regex noise.
#

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path


SCRIPTS_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_ROOT))

import check_architecture  # noqa: E402


def swift_source(filename: str, body: str) -> str:
    return f"""//
//  {filename}
//  vivobody
//
//  Focused architecture-check fixture with a real purpose header.
//

{body}
"""


class ArchitectureCheckerTests(unittest.TestCase):
    def rules_for(self, path: str, body: str) -> set[str]:
        source = swift_source(path.rsplit("/", 1)[-1], body)
        return {
            violation.rule
            for violation in check_architecture.check_swift_file(path, source)
        }

    def test_sensitive_framework_import_outside_boundary_fails(self) -> None:
        rules = self.rules_for(
            "vivobody/Screens/Today/RogueHealthView.swift",
            "import HealthKit\n",
        )
        self.assertIn("ARCH001", rules)

    def test_sensitive_framework_import_inside_boundary_passes(self) -> None:
        rules = self.rules_for(
            "vivobody/HealthKit/HealthKitWorkoutService.swift",
            "import HealthKit\n",
        )
        self.assertNotIn("ARCH001", rules)

    def test_widgets_cannot_open_swiftdata(self) -> None:
        rules = self.rules_for(
            "vivobodyWidgets/RogueStore.swift",
            "import SwiftData\nlet context: ModelContext? = nil\n",
        )
        self.assertIn("ARCH002", rules)

    def test_raw_glass_and_literal_defaults_keys_fail(self) -> None:
        rules = self.rules_for(
            "vivobody/Screens/Today/RogueSurface.swift",
            """import SwiftUI
let key = UserDefaults.standard.bool(forKey: "rogue.key")
let view = Text("Hi").glassEffect()
""",
        )
        self.assertIn("ARCH003", rules)
        self.assertIn("ARCH004", rules)

    def test_comments_and_strings_do_not_look_like_code(self) -> None:
        rules = self.rules_for(
            "vivobody/Screens/Today/DocumentationView.swift",
            """import SwiftUI
// import HealthKit; context.save(); Text("Hi").glassEffect()
let guidance = "context.save(); .glassEffect()"
""",
        )
        self.assertFalse({"ARCH001", "ARCH003", "ARCH005"} & rules)

    def test_direct_save_requires_a_reasoned_inline_exception(self) -> None:
        rejected = self.rules_for(
            "vivobody/App/RogueWriter.swift",
            "func write(context: ModelContext) throws { try context.save() }\n",
        )
        accepted = self.rules_for(
            "vivobody/App/TransactionalWriter.swift",
            """func write(context: ModelContext) throws {
    try context.save() // architecture: allow-direct-save -- owns a manual sentinel transaction
}
""",
        )
        self.assertIn("ARCH005", rejected)
        self.assertNotIn("ARCH005", accepted)
        self.assertNotIn("ARCH006", accepted)

    def test_malformed_or_unused_save_exception_fails(self) -> None:
        malformed = self.rules_for(
            "vivobody/App/RogueWriter.swift",
            """// architecture: allow-direct-save
func write(context: ModelContext) throws { try context.save() }
""",
        )
        self.assertIn("ARCH005", malformed)
        self.assertIn("ARCH006", malformed)

    def test_session_system_calls_must_use_fanout(self) -> None:
        rules = self.rules_for(
            "vivobody/App/RogueLifecycle.swift",
            "WorkoutLiveActivityController.start(for: session)\n",
        )
        self.assertIn("ARCH007", rules)

    def test_unified_logger_must_use_diagnostics_boundary(self) -> None:
        rejected = self.rules_for(
            "vivobody/Screens/Today/RogueLogger.swift",
            'import OSLog\nlet logger = Logger(subsystem: "app", category: "rogue")\n',
        )
        accepted = self.rules_for(
            "vivobody/App/AppDiagnostics.swift",
            'import OSLog\nlet logger = Logger(subsystem: "app", category: "storage")\n',
        )

        self.assertIn("ARCH011", rejected)
        self.assertNotIn("ARCH011", accepted)

    def test_active_exercise_card_cannot_reclaim_completion_services(self) -> None:
        rejected = self.rules_for(
            "vivobody/Screens/ActiveWorkout/ActiveExerciseCardRogue.swift",
            """import SwiftData
let analytics: SessionAnalytics? = nil
SessionSideEffects.handle(.updated, session: session, in: modelContext)
""",
        )
        accepted = self.rules_for(
            "vivobody/Screens/ActiveWorkout/ActiveExerciseCardFocused.swift",
            "let completion: ActiveSetCompletionActions? = nil\n",
        )

        self.assertIn("ARCH012", rejected)
        self.assertNotIn("ARCH012", accepted)

    def test_debug_wrapper_may_precede_header(self) -> None:
        source = """#if DEBUG
//
//  Gallery.swift
//  vivobody
//
//  Interactive component gallery.
//

import SwiftUI
#endif
"""
        violations = check_architecture.check_swift_file(
            "vivobody/Components/Gallery.swift",
            source,
        )
        self.assertNotIn("ARCH008", {violation.rule for violation in violations})

    def test_header_requires_a_purpose_statement(self) -> None:
        source = """//
//  EmptyHeader.swift
//  vivobody
//
//  Created by Developer.
//

import SwiftUI
"""
        violations = check_architecture.check_swift_file(
            "vivobody/EmptyHeader.swift",
            source,
        )
        self.assertIn("ARCH008", {violation.rule for violation in violations})

    def test_versions_must_be_defined_only_in_shared_config(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Shared.xcconfig").write_text(
                "MARKETING_VERSION = 1.0\nCURRENT_PROJECT_VERSION = 1\n",
                encoding="utf-8",
            )
            project = root / "vivobody.xcodeproj"
            project.mkdir()
            (project / "project.pbxproj").write_text(
                "MARKETING_VERSION = 2.0;\n",
                encoding="utf-8",
            )

            violations = check_architecture.check_version_sources(root)

        self.assertIn("ARCH009", {violation.rule for violation in violations})
        self.assertIn(
            "vivobody.xcodeproj/project.pbxproj",
            {violation.path for violation in violations},
        )


if __name__ == "__main__":
    unittest.main()
