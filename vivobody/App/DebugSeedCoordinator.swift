//
//  DebugSeedCoordinator.swift
//  vivobody
//
//  Executes already-parsed DEBUG fixture steps in their original global order.
//  Individual seed families retain ownership of construction and idempotence.
//

import Foundation
import SwiftData
import VivoKit

#if DEBUG

    @MainActor
    enum DebugSeedCoordinator {
        static func seedLaunchFixtures(
            _ steps: [DebugLaunchStep],
            in context: ModelContext
        ) {
            for step in steps {
                if DebugActiveWorkoutSeeder.handleCore(step, in: context) { continue }
                if DebugActiveWorkoutSeeder.handleInstrument(step, in: context) { continue }
                if DebugArchivedHistorySeeder.handle(step, in: context) { continue }
                if DebugInsightsSeeder.handle(step, in: context) { continue }
                if DebugTemplateSeeder.handle(step, in: context) { continue }
                if handleWidgetRequest(step) { continue }
                assertionFailure("Unhandled debug launch step: \(step)")
            }
        }

        static func seedManualFixture(
            _ fixture: DebugManualFixture?,
            in context: ModelContext
        ) {
            switch fixture {
            case .history:
                DebugArchivedHistorySeeder.seedGeneral(in: context)
            case .showcase:
                DebugArchivedHistorySeeder.seedShowcase(in: context)
            case .personalRecord:
                DebugArchivedHistorySeeder.seedPRProximity(in: context)
            case .templates:
                DebugTemplateSeeder.seedLibrary(in: context)
            case nil:
                break
            }
        }

        private static func handleWidgetRequest(_ step: DebugLaunchStep) -> Bool {
            guard step == .widgetStartRequest else { return false }
            // AppRoot consumes this mailbox through the real parser handoff.
            UserDefaults(suiteName: WidgetShared.appGroup)?.set(
                Date().timeIntervalSince1970,
                forKey: WidgetShared.startWorkoutRequestKey
            )
            return true
        }
    }

#endif
