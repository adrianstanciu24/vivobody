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

    private func session(at date: Date, _ exercises: [Exercise]) -> WorkoutSession {
        let s = WorkoutSession(exercises: exercises, startedAt: date)
        s.completedAt = date
        return s
    }

    private func lift(_ name: String, _ group: MuscleGroup = .chest, weight: Double, reps: Int = 5) -> Exercise {
        let ex = Exercise(name: name, group: group, plannedSets: 1, plannedReps: reps, plannedWeight: weight)
        ex.sets.forEach { $0.isCompleted = true }
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

    @Test func e1RMRisingTopWeightFlatStillPlateausOnPrimary() {
        // Plateau reads the PRIMARY metric (top weight), not e1RM —
        // grinding more reps at the same load is still a weight stall.
        let s = series("Bench Press", [(135, 5), (135, 6), (135, 7), (135, 8), (135, 9), (135, 10)])
        let status = progress(s, "Bench Press")?.plateauStatus(threshold: 5)
        #expect(status != nil)
        #expect(status?.metric == 135)
    }
}
