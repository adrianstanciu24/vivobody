//
//  WidgetIntents.swift
//  vivobody
//
//  App Intents shared by the widget extension and the app. The extension
//  only builds intent values for its buttons and controls; `perform()`
//  always runs in the app process, where the registered
//  WorkoutIntentActions route the request to the app's workout session.
//

import AppIntents
import Foundation

/// App-provided entry points for the shared intents. The app registers one
/// value with `AppDependencyManager` at launch; VivoKit stays free of app
/// and persistence types.
public struct WorkoutIntentActions: Sendable {
    public let startTodaysWorkout: @MainActor @Sendable () async -> Void
    public let completeActiveSet: @MainActor @Sendable () async -> Void

    public init(
        startTodaysWorkout: @escaping @MainActor @Sendable () async -> Void,
        completeActiveSet: @escaping @MainActor @Sendable () async -> Void
    ) {
        self.startTodaysWorkout = startTodaysWorkout
        self.completeActiveSet = completeActiveSet
    }
}

public struct StartTodaysWorkoutIntent: AppIntent {
    public nonisolated static let title: LocalizedStringResource = "Start Workout"
    public nonisolated static let description = IntentDescription("Start the workout scheduled for today in vivobody.")
    public nonisolated static var supportedModes: IntentModes {
        .foreground(.immediate)
    }

    @Dependency private var actions: WorkoutIntentActions

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        await actions.startTodaysWorkout()
        return .result()
    }
}

/// Runs in the app process without opening the app, so a Live Activity tap
/// completes the set while the user stays where they are. Hidden from
/// Shortcuts and Siri, where it would log a set the user cannot see.
public struct CompleteActiveSetIntent: LiveActivityIntent {
    public nonisolated static let title: LocalizedStringResource = "Complete Set"
    public nonisolated static let description = IntentDescription("Complete the current vivobody workout set.")
    public nonisolated static let isDiscoverable = false
    public nonisolated static var supportedModes: IntentModes {
        .background
    }

    @Dependency private var actions: WorkoutIntentActions

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        await actions.completeActiveSet()
        return .result()
    }
}
