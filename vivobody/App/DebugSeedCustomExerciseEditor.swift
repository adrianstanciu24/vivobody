//
//  DebugSeedCustomExerciseEditor.swift
//  vivobody
//
//  DEBUG-only launch-argument support for opening the custom-exercise editor
//  directly in deterministic verification scenarios.
//

import Foundation

#if DEBUG
    extension UITestSupport {
        static var opensCustomExerciseEditor: Bool {
            route().opensCustomExerciseEditor
        }
    }
#endif
