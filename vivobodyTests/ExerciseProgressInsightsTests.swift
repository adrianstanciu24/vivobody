//
//  ExerciseProgressInsightsTests.swift
//  vivobodyTests
//
//  Covers the two derived reads the Exercise detail screen layers on
//  top of the progress series: the best estimated-1RM headline (Epley
//  over every logged set) and the plateau detector (consecutive
//  sessions since the last all-time high on the primary metric).
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct ExerciseProgressInsightsTests {

    // MARK: - Virtual clock

    private static let origin = Date(timeIntervalSince1970: 1_700_000_000)
    private func day(_ n: Double) -> Date { Self.origin.addingTimeInterval(n * 86_400) }

    // MARK: - Builders

    private func session(
        at date: Date,
        _ exercises: [Exercise],
        bodyweightAtStart: Double = ExerciseLoad.unknownBodyweight
    ) -> WorkoutSession {
        let s = WorkoutSession(
            exercises: exercises,
            bodyweightAtStart: bodyweightAtStart,
            startedAt: date
        )
        s.completedAt = date
        return s
    }

    private func lift(_ name: String, _ group: MuscleGroup = .chest, weight: Double, reps: Int = 5) -> Exercise {
        let ex = Exercise(name: name, group: group, plannedSets: 1, plannedReps: reps, plannedWeight: weight)
        ex.sets.forEach { $0.isCompleted = true }
        return ex
    }

    private func hold(_ name: String, seconds: TimeInterval) -> Exercise {
        let ex = Exercise(
            name: name,
            group: .core,
            plannedSets: 1,
            plannedReps: 0,
            plannedWeight: 0,
            trackingMode: .duration,
            plannedDuration: seconds
        )
        ex.modality = .isometricStrength
        ex.loadMode = .nonComparable
        ex.sets.forEach {
            $0.duration = seconds
            $0.isCompleted = true
        }
        return ex
    }

    /// One session per (weight, reps) pair, `everyDays` apart.
    private func series(_ name: String, _ pairs: [(weight: Double, reps: Int)], group: MuscleGroup = .chest, everyDays: Double = 4) -> [WorkoutSession] {
        pairs.enumerated().map { i, p in
            session(at: day(Double(i) * everyDays), [lift(name, group, weight: p.weight, reps: p.reps)])
        }
    }

    private func progress(_ sessions: [WorkoutSession], _ name: String) -> ExerciseProgress? {
        sessions.progressByExercise.first { $0.name == name }
    }

    // MARK: - Best e1RM

    @Test func bestE1RMUsesEpleyAcrossSessions() {
        // 130×3 → 143.0 beats 100×10 → 133.3 and 120×5 → 140.0.
        let s = series("Bench Press", [(100, 10), (120, 5), (130, 3)])
        let prog = progress(s, "Bench Press")
        #expect(prog != nil)
        #expect(abs((prog?.bestE1RM ?? 0) - 143.0) < 0.01)
        // The PR point is the 130×3 session (the last one).
        #expect(prog?.bestE1RMPoint?.topWeight == 130)
        #expect(prog?.bestE1RMPoint?.topReps == 3)
    }

    @Test func conditioningKeepsHistoryButCannotCreateStrengthRecords() {
        let exercises = [(50.0, 12), (60.0, 15)].map { weight, reps in
            let exercise = lift("Conditioning Fixture", .core, weight: weight, reps: reps)
            exercise.modality = .conditioning
            return exercise
        }
        let sessions = exercises.enumerated().map { index, exercise in
            session(at: day(Double(index)), [exercise])
        }

        let prog = progress(sessions, "Conditioning Fixture")
        #expect(prog?.points.count == 2)
        #expect(prog?.points.allSatisfy { !$0.isStrengthPR } == true)
        #expect(prog?.bestE1RM == 0)
        #expect(prog?.recordDate == nil)
        #expect(prog?.plateauStatus(threshold: 1) == nil)
    }

    @Test func isometricStrengthUsesDurationForRecords() {
        let sessions = [
            session(at: day(0), [hold("Plank Fixture", seconds: 30)]),
            session(at: day(2), [hold("Plank Fixture", seconds: 45)]),
        ]

        let prog = progress(sessions, "Plank Fixture")
        #expect(prog?.bestE1RM == 0)
        #expect(prog?.points.map(\.isStrengthPR) == [true, true])
        #expect(prog?.recordPoint?.topDuration == 45)
    }

    @Test func nonComparableResistanceCannotCreateLoadRecords() {
        let exercises = [1.0, 2.0].map { marker in
            let exercise = lift("Band Fixture", .back, weight: marker, reps: 12)
            exercise.loadMode = .nonComparable
            return exercise
        }
        let sessions = exercises.enumerated().map { index, exercise in
            session(at: day(Double(index)), [exercise])
        }

        let prog = progress(sessions, "Band Fixture")
        #expect(prog?.points.count == 2)
        #expect(prog?.points.allSatisfy { !$0.isStrengthPR } == true)
        #expect(prog?.bestE1RM == 0)
    }

    @Test func assistedProgressUsesInverseEffectiveLoad() {
        let exercises = [60.0, 40.0].map { assistance in
            let exercise = lift("Assisted Pull-Up Fixture", .back, weight: assistance, reps: 5)
            exercise.loadMode = .assistanceSubtracted
            exercise.bodyweightFraction = 1
            return exercise
        }
        let sessions = exercises.enumerated().map { index, exercise in
            session(
                at: day(Double(index)),
                [exercise],
                bodyweightAtStart: 155
            )
        }

        let prog = progress(sessions, "Assisted Pull-Up Fixture")
        // Captured 155 lb bodyweight: 95 lb then 115 lb effective.
        #expect(prog?.points.map(\.effectiveTopLoad) == [95, 115])
        #expect(prog?.bestWeight == 115)
        #expect(prog?.bestWeightPoint?.topWeight == 40)
        #expect(prog?.weightDelta == 20)
        #expect(prog?.points.map(\.isStrengthPR) == [true, true])
        #expect(abs((prog?.bestE1RM ?? 0) - (115 * (1 + 5.0 / 30.0))) < 0.01)
    }

    @Test func bodyweightProgressUsesEachSessionsCapturedBodyweight() {
        let first = lift("Pull-Up Fixture", .back, weight: 0, reps: 5)
        first.loadMode = .bodyweightAdded
        first.bodyweightFraction = 1
        let second = lift("Pull-Up Fixture", .back, weight: 0, reps: 6)
        second.loadMode = .bodyweightAdded
        second.bodyweightFraction = 1

        let firstSession = WorkoutSession(
            exercises: [first],
            bodyweightAtStart: 180,
            startedAt: day(0)
        )
        firstSession.completedAt = day(0)
        let secondSession = WorkoutSession(
            exercises: [second],
            bodyweightAtStart: 160,
            startedAt: day(1)
        )
        secondSession.completedAt = day(1)

        let prog = progress([firstSession, secondSession], "Pull-Up Fixture")
        #expect(prog?.points.map(\.effectiveTopLoad) == [180, 160])
        #expect(prog?.points.map(\.isStrengthPR) == [true, false])
    }

    @Test func unknownBodyweightDoesNotFabricateAbsoluteStrengthMetrics() {
        let exercises = [5, 6].map { reps in
            let exercise = lift("Unknown Bodyweight Fixture", .back, weight: 25, reps: reps)
            exercise.loadMode = .bodyweightAdded
            exercise.bodyweightFraction = 1
            return exercise
        }
        let sessions = exercises.enumerated().map { index, exercise in
            session(at: day(Double(index)), [exercise])
        }

        let prog = progress(sessions, "Unknown Bodyweight Fixture")
        #expect(prog?.points.map(\.effectiveTopLoad) == [nil, nil])
        #expect(prog?.points.allSatisfy { !$0.isStrengthPR } == true)
        #expect(prog?.points.allSatisfy { $0.totalVolume == 0 } == true)
        #expect(prog?.points.allSatisfy {
            $0.comparableTonnageAvailability == .unavailable
        } == true)
        #expect(prog?.bestWeight == 0)
        #expect(prog?.weightDelta == nil)
        #expect(prog?.bestE1RM == 0)
        #expect(exercises.allSatisfy { $0.completedComparableTonnage == nil })
    }

    @Test func unknownBodyweightSessionsDoNotCountTowardAPlateau() {
        func pullUp(reps: Int) -> Exercise {
            let exercise = lift("Plateau Bodyweight Fixture", .back, weight: 0, reps: reps)
            exercise.loadMode = .bodyweightAdded
            exercise.bodyweightFraction = 1
            return exercise
        }

        let known = session(
            at: day(0),
            [pullUp(reps: 5)],
            bodyweightAtStart: 180
        )
        let unknown = (1...5).map { index in
            session(at: day(Double(index)), [pullUp(reps: 5)])
        }
        let prog = progress([known] + unknown, "Plateau Bodyweight Fixture")

        #expect(prog?.points.count == 6)
        #expect(prog?.points.compactMap(\.strengthPerformance).count == 1)
        #expect(prog?.plateauStatus(threshold: 5) == nil)
    }

    @Test func loadedIsometricRecordsUseLoadThenDuration() {
        func loadedHold(weight: Double, duration: TimeInterval) -> Exercise {
            let exercise = Exercise(
                name: "Loaded Hold Fixture",
                group: .core,
                plannedSets: 1,
                plannedReps: 0,
                plannedWeight: weight,
                trackingMode: .duration,
                modality: .isometricStrength,
                loadMode: .external,
                plannedDuration: duration
            )
            exercise.sets.forEach {
                $0.weight = weight
                $0.duration = duration
                $0.isCompleted = true
            }
            return exercise
        }

        let sessions = [
            session(at: day(0), [loadedHold(weight: 50, duration: 60)]),
            session(at: day(1), [loadedHold(weight: 55, duration: 30)]),
            session(at: day(2), [loadedHold(weight: 55, duration: 45)]),
            session(at: day(3), [loadedHold(weight: 50, duration: 120)]),
        ]

        let prog = progress(sessions, "Loaded Hold Fixture")
        #expect(prog?.points.map(\.isStrengthPR) == [true, true, true, false])
        #expect(prog?.recordPoint?.topWeight == 55)
        #expect(prog?.recordPoint?.topDuration == 45)
        #expect(prog?.recordPoint?.strengthPerformance?.primaryMetricKind == .load)

        let stalled = (0..<6).map { index in
            session(
                at: day(10 + Double(index)),
                [loadedHold(weight: 55, duration: 45)]
            )
        }
        let status = progress(stalled, "Loaded Hold Fixture")?.plateauStatus(threshold: 5)
        #expect(status?.metric == 55)
        #expect(status?.metricKind == .load)
        #expect(status?.isDuration == false)
    }

    @Test func externalPowerHasLoadRecordsAndTonnageWithoutE1RM() {
        func power(weight: Double, reps: Int) -> Exercise {
            let exercise = lift("Power Fixture", .legs, weight: weight, reps: reps)
            exercise.modality = .power
            exercise.loadMode = .external
            return exercise
        }

        let sessions = [
            session(at: day(0), [power(weight: 100, reps: 3)]),
            session(at: day(1), [power(weight: 105, reps: 2)]),
        ]
        let prog = progress(sessions, "Power Fixture")

        #expect(prog?.points.map(\.isStrengthPR) == [true, true])
        #expect(prog?.points.map(\.totalVolume) == [300, 210])
        #expect(prog?.bestE1RM == 0)
    }

    @Test func customReclassificationCreatesSeparatePerformanceSeries() {
        let itemID = UUID()

        func customLift(weight: Double) -> Exercise {
            let exercise = lift("Reclassified Custom", weight: weight)
            exercise.catalogItemID = itemID
            return exercise
        }

        func customHold(duration: TimeInterval) -> Exercise {
            let exercise = hold("Reclassified Custom", seconds: duration)
            exercise.catalogItemID = itemID
            return exercise
        }

        let progress = [
            session(at: day(0), [customLift(weight: 100)]),
            session(at: day(1), [customLift(weight: 105)]),
            session(at: day(2), [customHold(duration: 30)]),
            session(at: day(3), [customHold(duration: 45)]),
        ].progressByExercise

        #expect(progress.count == 2)
        #expect(Set(progress.map(\.performanceSemanticKind)) == Set([
            PerformanceSemanticKind.dynamicLoadAndReps,
            .isometricDuration,
        ]))
        #expect(Set(progress.map(\.id)).count == 2)
        #expect(progress.allSatisfy { $0.points.count == 2 })
    }

    @Test func customExternalAndAssistedLoadsRemainSeparateSeries() {
        let itemID = UUID()

        func custom(_ mode: ExerciseLoadMode, weight: Double) -> Exercise {
            let exercise = lift("Load-Edited Custom", .back, weight: weight)
            exercise.catalogItemID = itemID
            exercise.loadMode = mode
            exercise.bodyweightFraction = mode == .assistanceSubtracted ? 1 : 0
            return exercise
        }

        let progress = [
            session(at: day(0), [custom(.external, weight: 100)], bodyweightAtStart: 200),
            session(at: day(1), [custom(.external, weight: 105)], bodyweightAtStart: 200),
            session(at: day(2), [custom(.assistanceSubtracted, weight: 60)], bodyweightAtStart: 200),
            session(at: day(3), [custom(.assistanceSubtracted, weight: 50)], bodyweightAtStart: 200),
        ].progressByExercise

        #expect(progress.count == 2)
        #expect(Set(progress.map(\.performanceSemanticKind)) == [.dynamicLoadAndReps])
        #expect(Set(progress.compactMap { $0.points.first?.loadMode }) == [
            ExerciseLoadMode.external,
            .assistanceSubtracted,
        ])
        #expect(Set(progress.map(\.id)).count == 2)
        #expect(progress.allSatisfy { $0.points.count == 2 })
    }

    @Test func customBodyweightFractionEditsRemainSeparateSeries() {
        let itemID = UUID()

        func custom(fraction: Double, weight: Double) -> Exercise {
            let exercise = lift("Fraction-Edited Custom", .back, weight: weight)
            exercise.catalogItemID = itemID
            exercise.loadMode = .bodyweightAdded
            exercise.bodyweightFraction = fraction
            return exercise
        }

        let progress = [
            session(at: day(0), [custom(fraction: 0.5, weight: 10)], bodyweightAtStart: 200),
            session(at: day(1), [custom(fraction: 0.5, weight: 15)], bodyweightAtStart: 200),
            session(at: day(2), [custom(fraction: 1, weight: 10)], bodyweightAtStart: 200),
            session(at: day(3), [custom(fraction: 1, weight: 15)], bodyweightAtStart: 200),
        ].progressByExercise

        #expect(progress.count == 2)
        #expect(Set(progress.compactMap { $0.points.first?.bodyweightFraction }) == [0.5, 1])
        #expect(Set(progress.map(\.id)).count == 2)
        #expect(progress.allSatisfy { $0.points.count == 2 })
    }

    @Test func conditioningAndNonComparableHistoryHaveNoComparableTonnage() {
        let conditioning = lift("Conditioning Volume Fixture", .core, weight: 50, reps: 10)
        conditioning.modality = .conditioning
        let band = lift("Band Volume Fixture", .back, weight: 25, reps: 10)
        band.loadMode = .nonComparable

        let sessions = [
            session(at: day(0), [conditioning]),
            session(at: day(1), [lift("Conditioning Volume Fixture", .core, weight: 55, reps: 10)]),
            session(at: day(2), [band]),
            session(at: day(3), [lift("Band Volume Fixture", .back, weight: 30, reps: 10)]),
        ]
        sessions[1].exercises[0].modality = .conditioning
        sessions[3].exercises[0].loadMode = .nonComparable

        #expect(progress(sessions, "Conditioning Volume Fixture")?.points.allSatisfy { $0.totalVolume == 0 } == true)
        #expect(progress(sessions, "Band Volume Fixture")?.points.allSatisfy { $0.totalVolume == 0 } == true)
        #expect(progress(sessions, "Conditioning Volume Fixture")?.points.allSatisfy {
            $0.comparableTonnageAvailability == .complete
        } == true)
        #expect(progress(sessions, "Band Volume Fixture")?.points.allSatisfy {
            $0.comparableTonnageAvailability == .complete
        } == true)
    }

    @Test func bundledProgressRetainsStableIdentityAcrossCatalogReseeds() {
        let firstCatalogUUID = UUID()
        let reseededCatalogUUID = UUID()
        let first = Exercise(
            name: "Renamed Display A",
            catalogItemID: firstCatalogUUID,
            catalogID: "stable-lift",
            group: .chest,
            plannedSets: 1,
            plannedReps: 5,
            plannedWeight: 100
        )
        first.sets.forEach { $0.isCompleted = true }
        let second = Exercise(
            name: "Renamed Display B",
            catalogItemID: reseededCatalogUUID,
            catalogID: "stable-lift",
            group: .chest,
            plannedSets: 1,
            plannedReps: 5,
            plannedWeight: 105
        )
        second.sets.forEach { $0.isCompleted = true }

        let progress = [
            session(at: day(0), [first]),
            session(at: day(1), [second]),
        ].progressByExercise

        #expect(progress.count == 1)
        #expect(progress.first?.catalogID == "stable-lift")
        #expect(progress.first?.id == "bundled:stable-lift")
        #expect(progress.first?.points.count == 2)
    }

    // MARK: - Plateau detector

    @Test func flatTopWeightFlagsPlateau() {
        // Baseline PR at the first session, then five stale ones.
        let s = series("Overhead Press", Array(repeating: (95.0, 5), count: 6), group: .shoulders)
        let status = progress(s, "Overhead Press")?.plateauStatus(threshold: 5)
        #expect(status != nil)
        #expect(status?.sessions == 5)
        #expect(status?.metric == 95)
        #expect(status?.isDuration == false)
    }

    @Test func progressiveOverloadNeverPlateaus() {
        let s = series("Bench Press", [(135, 5), (140, 5), (145, 5), (150, 5), (155, 5), (160, 5)])
        #expect(progress(s, "Bench Press")?.plateauStatus(threshold: 5) == nil)
    }

    @Test func recentPRClearsThePlateau() {
        // Five flat, then a new high on the very last session.
        let s = series("Back Squat", [(225, 5), (225, 5), (225, 5), (225, 5), (225, 5), (235, 5)], group: .legs)
        #expect(progress(s, "Back Squat")?.plateauStatus(threshold: 5) == nil)
    }

    @Test func plateauNeedsMoreThanThresholdSessions() {
        // Exactly five flat sessions: a baseline plus only four stale
        // ones — short of the five-session bar, so no flag yet.
        let s = series("Deadlift", Array(repeating: (315.0, 5), count: 5), group: .back)
        #expect(progress(s, "Deadlift")?.plateauStatus(threshold: 5) == nil)
    }

    @Test func moreRepsAtTheSameLoadAdvanceTheSharedRecord() {
        // Live, History, the PR wall, and plateau detection all use the
        // same transparent lexicographic comparison: load, then reps.
        let s = series("Bench Press", [(135, 5), (135, 6), (135, 7), (135, 8), (135, 9), (135, 10)])
        let prog = progress(s, "Bench Press")
        #expect(prog?.points.map(\.isStrengthPR) == [true, true, true, true, true, true])
        #expect(prog?.recordPoint?.topReps == 10)
        #expect(prog?.plateauStatus(threshold: 5) == nil)
    }

    @Test func lowerLoadDoesNotBeatTheRecordThroughVolumeAlone() {
        let s = series("Bench Press", [(135, 5), (130, 20)])
        let prog = progress(s, "Bench Press")
        #expect(prog?.points.map(\.isStrengthPR) == [true, false])
        #expect(prog?.recordPoint?.topWeight == 135)
    }
}
