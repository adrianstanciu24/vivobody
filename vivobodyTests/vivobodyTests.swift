//
//  vivobodyTests.swift
//  vivobodyTests
//
//  Created by Adrian Stanciu on 11.03.2026.
//

import Foundation
import SwiftData
import Testing
@testable import vivobody

struct VivobodyTests {
    @Test func exerciseCreation() {
        let exercise = Exercise(name: "Bench Press", muscleGroup: .chest, category: .barbell)
        #expect(exercise.name == "Bench Press")
        #expect(exercise.muscleGroup == .chest)
        #expect(exercise.category == .barbell)
        #expect(exercise.notes.isEmpty)
    }

    @Test func workoutDefaults() {
        let workout = Workout()
        #expect(!workout.isCompleted)
        #expect(workout.duration == nil)
        #expect(workout.exercises.isEmpty)
        #expect(workout.notes.isEmpty)
    }

    @Test func workoutCompletion() {
        let start = Date.now
        let workout = Workout(startedAt: start)
        workout.completedAt = start.addingTimeInterval(3600)
        #expect(workout.isCompleted)
        #expect(workout.duration == 3600)
    }

    @Test func muscleGroupDisplayNames() {
        #expect(MuscleGroup.fullBody.displayName == "Full Body")
        #expect(MuscleGroup.chest.displayName == "Chest")
    }

    @Test func exerciseCategoryDisplayNames() {
        #expect(ExerciseCategory.barbell.displayName == "Barbell")
        #expect(ExerciseCategory.bodyweight.displayName == "Bodyweight")
    }
}
