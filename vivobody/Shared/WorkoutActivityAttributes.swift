//
//  WorkoutActivityAttributes.swift
//  vivobody
//
//  ActivityKit contract shared by the app and widget extension for
//  the Active Workout Live Activity.
//

import ActivityKit
import Foundation

struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var exerciseName: String
        var exerciseIndex: Int
        var setNumber: Int
        var plannedSets: Int
        var setSpec: String
        var isResting: Bool
        var restEndsAt: Date?
        var restDuration: TimeInterval
        var totalVolume: Double
        var totalSetsCompleted: Int
    }

    var sessionStartedAt: Date
    var totalExercises: Int
}
