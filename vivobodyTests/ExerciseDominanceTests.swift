//
//  ExerciseDominanceTests.swift
//  vivobodyTests
//
//  Guards the lifetime tonnage ranking: name grouping across
//  sessions, descending order by volume, share arithmetic, exclusion
//  of timed holds and incomplete sets, and the empty-archive edge.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct ExerciseDominanceTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func session(daysAgo: Double, _ exercises: [Exercise]) -> WorkoutSession {
        let date = now.addingTimeInterval(-daysAgo * 86_400)
        let s = WorkoutSession(exercises: exercises, startedAt: date)
        s.completedAt = date
        return s
    }

    /// Reps exercise from (weight, reps, completed) tuples.
    private func lift(
        _ name: String = "Bench Press",
        group: MuscleGroup = .chest,
        _ sets: [(weight: Double, reps: Int, completed: Bool)]
    ) -> Exercise {
        let ex = Exercise(name: name, group: group, plannedSets: 0, plannedWeight: 0)
        for (i, s) in sets.enumerated() {
            ex.sets.append(WorkoutSet(
                weight: s.weight,
                reps: s.reps,
                isCompleted: s.completed,
                sortOrder: i
            ))
        }
        return ex
    }

    /// Timed-hold exercise — carries duration, no weight×reps volume.
    private func hold(seconds: [TimeInterval]) -> Exercise {
        let ex = Exercise(
            name: "Plank",
            group: .core,
            plannedSets: 0,
            plannedWeight: 0,
            trackingMode: .duration
        )
        for (i, sec) in seconds.enumerated() {
            ex.sets.append(WorkoutSet(weight: 0, reps: 0, duration: sec, isCompleted: true, sortOrder: i))
        }
        return ex
    }

    // MARK: - Grouping

    @Test func groupsByNameAcrossSessions() {
        let a = session(daysAgo: 10, [lift("Back Squat", group: .legs, [(185, 8, true), (185, 8, true)])])
        let b = session(daysAgo: 3, [lift("back squat", group: .legs, [(205, 5, true)])])
        let board = [a, b].exerciseDominance(now: now)

        #expect(board.stats.count == 1)
        #expect(board.top?.name == "Back Squat")
        // 185*8 + 185*8 + 205*5 = 1480 + 1480 + 1025 = 3985
        #expect(board.top?.volume ?? 0 == 3985)
    }

    // MARK: - Shares

    @Test func sharesSumToOne() {
        let squat = lift("Back Squat", group: .legs, [(100, 10, true)])
        let bench = lift("Bench Press", group: .chest, [(100, 5, true)])
        let board = [session(daysAgo: 1, [squat, bench])].exerciseDominance(now: now)

        let sum = board.stats.reduce(0.0) { $0 + $1.share }
        #expect(abs(sum - 1.0) < 0.0001)
        #expect(board.totalVolume == 1500) // 1000 + 500
    }

    // MARK: - Ordering

    @Test func sortsDescendingByVolume() {
        let small = lift("Curl", group: .arms, [(50, 10, true)])      // 500
        let big = lift("Deadlift", group: .back, [(200, 5, true)])    // 1000
        let mid = lift("Row", group: .back, [(100, 8, true)])         // 800
        let board = [session(daysAgo: 1, [small, big, mid])].exerciseDominance(now: now)

        #expect(board.stats.map(\.name) == ["Deadlift", "Row", "Curl"])
        #expect(board.top?.name == "Deadlift")
    }

    // MARK: - Exclusions

    @Test func excludesDurationHolds() {
        let reps = lift("Bench Press", group: .chest, [(100, 8, true)])
        let plank = hold(seconds: [60, 45])
        let board = [session(daysAgo: 1, [reps, plank])].exerciseDominance(now: now)

        #expect(board.stats.count == 1)
        #expect(board.top?.name == "Bench Press")
        #expect(board.totalVolume == 800)
    }

    @Test func excludesIncompleteSets() {
        // Only the first (completed) set counts; the incomplete set
        // and the unlogged-reps set are ignored.
        let ex = lift("Bench Press", group: .chest, [
            (100, 8, true),
            (100, 8, false),
            (100, 0, true),
        ])
        let board = [session(daysAgo: 1, [ex])].exerciseDominance(now: now)

        #expect(board.stats.count == 1)
        #expect(board.totalVolume == 800) // only 100*8
    }

    // MARK: - Empty

    @Test func emptyArchiveHasNothing() {
        let board = [WorkoutSession]().exerciseDominance(now: now)
        #expect(board.hasAny == false)
        #expect(board.top == nil)
        #expect(board.topShare == 0)
        #expect(board.topTwoShare == 0)
        #expect(board.totalVolume == 0)
    }

    // MARK: - topTwoShare

    @Test func topTwoShareSumsTopTwo() {
        // Volumes: 1000, 500, 250 → total 1750.
        // topTwoShare = (1000 + 500) / 1750
        let big = lift("Squat", group: .legs, [(100, 10, true)])
        let mid = lift("Bench", group: .chest, [(100, 5, true)])
        let small = lift("Curl", group: .arms, [(50, 5, true)])
        let board = [session(daysAgo: 1, [big, mid, small])].exerciseDominance(now: now)

        let expected = (1000.0 + 500.0) / 1750.0
        #expect(abs(board.topTwoShare - expected) < 0.0001)
    }
}
