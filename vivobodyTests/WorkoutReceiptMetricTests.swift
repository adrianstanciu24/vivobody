//
//  WorkoutReceiptMetricTests.swift
//  vivobodyTests
//
//  Freezes primary workout-receipt selection, formatting, availability,
//  and accessibility semantics independently from any SwiftUI layout.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct WorkoutReceiptMetricTests {
    @Test func completeVolumeCompactsVisuallyButSpeaksTheExpandedAmount() {
        let session = makeSession([
            repsExercise(weight: 127, reps: 100),
        ])

        #expect(session.primaryReceiptMetric(unit: .lb) == WorkoutReceiptMetric(
            kind: .volume(.complete),
            value: "12.7k",
            qualifier: nil,
            unit: "lb",
            label: "Volume",
            accessibilityLabel: "12700 pounds of volume"
        ))
        #expect(session.primaryReceiptMetric(unit: .kg) == WorkoutReceiptMetric(
            kind: .volume(.complete),
            value: "5,760",
            qualifier: nil,
            unit: "kg",
            label: "Volume",
            accessibilityLabel: "5760 kilograms of volume"
        ))
        #expect(session.primaryReceiptMetric(
            unit: .lb,
            volumeDisplayStyle: .full
        ).value == "12,700")
    }

    @Test func partialVolumeKeepsItsQualifierAndUncertaintySeparate() {
        let session = makeSession([
            repsExercise(weight: 100, reps: 10),
            unknownBodyweightExercise(reps: 8),
        ])

        #expect(session.primaryReceiptMetric(unit: .lb) == WorkoutReceiptMetric(
            kind: .volume(.partial),
            value: "1,000",
            qualifier: "+",
            unit: "lb",
            label: "Known volume · total unavailable",
            accessibilityLabel: "1000 pounds of known volume; total unavailable"
        ))
    }

    @Test func unavailableVolumeDoesNotFallBackToReps() {
        let session = makeSession([
            unknownBodyweightExercise(reps: 8),
        ])

        #expect(session.primaryReceiptMetric(unit: .lb) == WorkoutReceiptMetric(
            kind: .volume(.unavailable),
            value: "—",
            qualifier: nil,
            unit: nil,
            label: "Volume unavailable",
            accessibilityLabel: "Volume unavailable"
        ))
    }

    @Test func volumeWinsAcrossMixedCompletedWork() {
        let session = makeSession([
            repsExercise(weight: 100, reps: 10),
            unloadedRepsExercise(reps: 12),
            timedExercise(seconds: 90),
        ])

        #expect(session.primaryReceiptMetric(unit: .lb).kind == .volume(.complete))
        #expect(session.primaryReceiptMetric(unit: .lb).value == "1,000")
    }

    @Test func unloadedRepsWinOverTimedWork() {
        let session = makeSession([
            unloadedRepsExercise(reps: 12),
            timedExercise(seconds: 90),
        ])

        #expect(session.primaryReceiptMetric(unit: .lb) == WorkoutReceiptMetric(
            kind: .reps,
            value: "12",
            qualifier: nil,
            unit: nil,
            label: "Reps",
            accessibilityLabel: "12 reps"
        ))
    }

    @Test func timedWorkUsesCompactVisualAndExpandedAccessibility() {
        let singular = makeSession([
            timedExercise(seconds: 1),
        ])
        let plural = makeSession([
            timedExercise(seconds: 90),
        ])

        #expect(singular.primaryReceiptMetric(unit: .lb) == WorkoutReceiptMetric(
            kind: .timedWork,
            value: "1s",
            qualifier: nil,
            unit: nil,
            label: "Timed work",
            accessibilityLabel: "1 second of timed work"
        ))
        #expect(plural.primaryReceiptMetric(unit: .lb) == WorkoutReceiptMetric(
            kind: .timedWork,
            value: "1:30",
            qualifier: nil,
            unit: nil,
            label: "Timed work",
            accessibilityLabel: "90 seconds of timed work"
        ))
    }

    @Test func incompleteOrZeroValueSetsPreserveTheTimedWorkFallback() {
        let incomplete = repsExercise(weight: 100, reps: 10, completed: false)
        let zeroDuration = timedExercise(seconds: 0)
        let session = makeSession([incomplete, zeroDuration])

        #expect(session.primaryReceiptMetric(unit: .lb) == WorkoutReceiptMetric(
            kind: .timedWork,
            value: "0s",
            qualifier: nil,
            unit: nil,
            label: "Timed work",
            accessibilityLabel: "0 seconds of timed work"
        ))
    }

    @Test func accessibilityLabelsUseSingularQuantityNames() {
        let oneRep = makeSession([unloadedRepsExercise(reps: 1)])
        let onePound = makeSession([repsExercise(weight: 1, reps: 1)])
        let oneKilogram = makeSession([
            repsExercise(weight: WeightFormatter.toCanonical(1, unit: .kg), reps: 1),
        ])

        #expect(oneRep.primaryReceiptMetric(unit: .lb).accessibilityLabel == "1 rep")
        #expect(onePound.primaryReceiptMetric(unit: .lb).accessibilityLabel == "1 pound of volume")
        #expect(oneKilogram.primaryReceiptMetric(unit: .kg).accessibilityLabel == "1 kilogram of volume")
    }

    private func makeSession(_ exercises: [Exercise]) -> WorkoutSession {
        WorkoutSession(exercises: exercises)
    }

    private func repsExercise(
        weight: Double,
        reps: Int,
        completed: Bool = true
    ) -> Exercise {
        let exercise = Exercise(
            name: "Loaded Reps Fixture",
            group: .chest,
            plannedSets: 0,
            plannedWeight: 0
        )
        exercise.sets.append(WorkoutSet(
            weight: weight,
            reps: reps,
            isCompleted: completed
        ))
        return exercise
    }

    private func unknownBodyweightExercise(reps: Int) -> Exercise {
        let exercise = Exercise(
            name: "Unknown Bodyweight Fixture",
            group: .back,
            plannedSets: 0,
            plannedWeight: 0,
            loadMode: .bodyweightAdded,
            bodyweightFraction: 1
        )
        exercise.sets.append(WorkoutSet(
            weight: 25,
            reps: reps,
            isCompleted: true
        ))
        return exercise
    }

    private func unloadedRepsExercise(reps: Int) -> Exercise {
        let classification = ExerciseClassification(
            equipment: .bodyweight,
            mechanic: .compound,
            trainingRole: .legs,
            pattern: .hinge,
            direction: nil,
            planes: [.sagittal],
            laterality: .bilateral
        )
        let exercise = Exercise(
            name: "Unloaded Reps Fixture",
            group: .legs,
            plannedSets: 0,
            plannedWeight: 0,
            classification: classification,
            loadMode: .nonComparable
        )
        exercise.sets.append(WorkoutSet(
            weight: 0,
            reps: reps,
            isCompleted: true
        ))
        return exercise
    }

    private func timedExercise(seconds: TimeInterval) -> Exercise {
        let exercise = Exercise(
            name: "Timed Fixture",
            group: .core,
            plannedSets: 0,
            plannedWeight: 0,
            trackingMode: .duration,
            modality: .isometricStrength,
            loadMode: .nonComparable
        )
        exercise.sets.append(WorkoutSet(
            weight: 0,
            reps: 0,
            duration: seconds,
            isCompleted: true
        ))
        return exercise
    }
}
