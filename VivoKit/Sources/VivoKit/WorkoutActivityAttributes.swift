//
//  WorkoutActivityAttributes.swift
//  vivobody
//
//  ActivityKit contract shared by the app and widget extension for
//  the Active Workout Live Activity.
//

import ActivityKit
import Foundation

public struct WorkoutActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var exerciseName: String
        public var exerciseIndex: Int
        public var setNumber: Int
        public var plannedSets: Int
        public var setSpec: String
        public var isResting: Bool
        public var restEndsAt: Date?
        public var restDuration: TimeInterval
        public var totalVolume: Double
        public var totalSetsCompleted: Int

        public init(exerciseName: String, exerciseIndex: Int, setNumber: Int, plannedSets: Int, setSpec: String, isResting: Bool, restEndsAt: Date?, restDuration: TimeInterval, totalVolume: Double, totalSetsCompleted: Int) {
            self.exerciseName = exerciseName
            self.exerciseIndex = exerciseIndex
            self.setNumber = setNumber
            self.plannedSets = plannedSets
            self.setSpec = setSpec
            self.isResting = isResting
            self.restEndsAt = restEndsAt
            self.restDuration = restDuration
            self.totalVolume = totalVolume
            self.totalSetsCompleted = totalSetsCompleted
        }
    }

    public var sessionStartedAt: Date
    public var totalExercises: Int

    public init(sessionStartedAt: Date, totalExercises: Int) {
        self.sessionStartedAt = sessionStartedAt
        self.totalExercises = totalExercises
    }
}
