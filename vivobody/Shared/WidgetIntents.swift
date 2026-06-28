//
//  WidgetIntents.swift
//  vivobody
//
//  App Intents used by interactive widgets. The intent keeps business
//  logic in the main app by recording a tiny App Group handoff and
//  opening vivobody, where AppState can start the scheduled workout
//  through its normal SwiftData path.
//

import AppIntents
import Foundation

struct StartTodaysWorkoutIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Start Workout"
    nonisolated static let description = IntentDescription("Start the workout scheduled for today in vivobody.")
    nonisolated static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: WidgetShared.appGroup)?
            .set(Date().timeIntervalSince1970, forKey: WidgetShared.startWorkoutRequestKey)
        return .result()
    }
}

struct CompleteActiveSetIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Complete Set"
    nonisolated static let description = IntentDescription("Complete the current vivobody workout set.")
    nonisolated static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: WidgetShared.appGroup)?
            .set(Date().timeIntervalSince1970, forKey: WidgetShared.completeSetRequestKey)
        return .result()
    }
}
