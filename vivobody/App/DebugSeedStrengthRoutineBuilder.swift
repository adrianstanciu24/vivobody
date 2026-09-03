//
//  DebugSeedStrengthRoutineBuilder.swift
//  vivobody
//
//  DEBUG-only launch-argument support for opening the strength routine builder
//  directly in deterministic verification scenarios.
//

import Foundation

#if DEBUG
    extension UITestSupport {
        static var opensStrengthRoutineBuilder: Bool {
            route().opensStrengthRoutineBuilder
        }
    }
#endif
