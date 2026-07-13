//
//  ExerciseDominanceTests.swift
//  vivobodyTests
//
//  Guards recent working-set allocation: name grouping across
//  sessions, set-count ordering, four-week windowing, share
//  arithmetic, exclusions, and the empty-history edge.
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
        catalogItemID: UUID? = nil,
        _ sets: [(weight: Double, reps: Int, completed: Bool)]
    ) -> Exercise {
        let ex = Exercise(
            name: name,
            catalogItemID: catalogItemID,
            group: group,
            plannedSets: 0,
            plannedWeight: 0
        )
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

    /// Timed-hold exercise, excluded from working-set allocation.
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
        #expect(board.top?.sets == 3)
    }

    // MARK: - Shares

    @Test func sharesSumToOne() {
        let squat = lift("Back Squat", group: .legs, [(100, 10, true)])
        let bench = lift("Bench Press", group: .chest, [(100, 5, true)])
        let board = [session(daysAgo: 1, [squat, bench])].exerciseDominance(now: now)

        let sum = board.stats.reduce(0.0) { $0 + $1.share }
        #expect(abs(sum - 1.0) < 0.0001)
        #expect(board.totalSets == 2)
        #expect(board.stats.allSatisfy { abs($0.share - 0.5) < 0.0001 })
    }

    // MARK: - Ordering

    @Test func sortsDescendingBySetCount() {
        let small = lift("Curl", group: .arms, [(50, 10, true)])
        let big = lift("Deadlift", group: .back, [(200, 5, true), (200, 5, true), (200, 5, true)])
        let mid = lift("Row", group: .back, [(100, 8, true), (100, 8, true)])
        let board = [session(daysAgo: 1, [small, big, mid])].exerciseDominance(now: now)

        #expect(board.stats.map(\.name) == ["Deadlift", "Row", "Curl"])
        #expect(board.top?.name == "Deadlift")
    }

    @Test func lightExercisesAreNotPenalizedByWeight() {
        let heavy = lift("Deadlift", group: .back, [(500, 3, true)])
        let light = lift("Leg Curl", group: .legs, [
            (40, 12, true),
            (40, 12, true),
            (40, 12, true),
            (40, 12, true),
        ])
        let board = [session(daysAgo: 1, [heavy, light])].exerciseDominance(now: now)

        #expect(board.top?.name == "Leg Curl")
        #expect(board.top?.sets == 4)
        #expect(abs(board.topShare - 0.8) < 0.0001)
    }

    @Test func equalCountsUseStableIdentityAfterName() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let second = lift(
            "Press",
            catalogItemID: secondID,
            [(100, 8, true)]
        )
        let first = lift(
            "Press",
            catalogItemID: firstID,
            [(100, 8, true)]
        )
        let board = [session(daysAgo: 1, [second, first])].exerciseDominance(now: now)

        #expect(board.stats.map(\.historyKey) == [
            "catalog:\(firstID.uuidString)",
            "catalog:\(secondID.uuidString)",
        ])
    }

    // MARK: - Exclusions

    @Test func excludesDurationHolds() {
        let reps = lift("Bench Press", group: .chest, [(100, 8, true)])
        let plank = hold(seconds: [60, 45])
        let board = [session(daysAgo: 1, [reps, plank])].exerciseDominance(now: now)

        #expect(board.stats.count == 1)
        #expect(board.top?.name == "Bench Press")
        #expect(board.totalSets == 1)
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
        #expect(board.totalSets == 1)
    }

    // MARK: - Window

    @Test func respectsTheFourWeekWindow() {
        let recent = session(daysAgo: 3, [lift("Bench Press", [(100, 8, true)])])
        let old = session(daysAgo: 40, [lift("Back Squat", [(200, 5, true), (200, 5, true)])])
        let board = [recent, old].exerciseDominance(now: now)

        #expect(board.stats.map(\.name) == ["Bench Press"])
        #expect(board.totalSets == 1)
    }

    @Test func excludesTheExactWindowBoundary() {
        let inside = session(daysAgo: 27.999, [lift("Bench Press", [(100, 8, true)])])
        let boundary = session(daysAgo: 28, [lift("Back Squat", [(200, 5, true)])])
        let board = [inside, boundary].exerciseDominance(now: now)

        #expect(board.stats.map(\.name) == ["Bench Press"])
        #expect(board.totalSets == 1)
    }

    @Test func excludesFutureSessions() {
        let recent = session(daysAgo: 1, [lift("Bench Press", [(100, 8, true)])])
        let future = session(daysAgo: -1, [lift("Back Squat", [(200, 5, true)])])
        let board = [recent, future].exerciseDominance(now: now)

        #expect(board.stats.map(\.name) == ["Bench Press"])
    }

    // MARK: - Empty

    @Test func emptyArchiveHasNothing() {
        let board = [WorkoutSession]().exerciseDominance(now: now)
        #expect(board.hasAny == false)
        #expect(board.top == nil)
        #expect(board.topShare == 0)
        #expect(board.topTwoShare == 0)
        #expect(board.totalSets == 0)
    }

    // MARK: - topTwoShare

    @Test func topTwoShareSumsTopTwo() {
        let big = lift("Squat", group: .legs, [(100, 10, true), (100, 10, true), (100, 10, true)])
        let mid = lift("Bench", group: .chest, [(100, 5, true), (100, 5, true)])
        let small = lift("Curl", group: .arms, [(50, 5, true)])
        let board = [session(daysAgo: 1, [big, mid, small])].exerciseDominance(now: now)

        let expected = 5.0 / 6.0
        #expect(abs(board.topTwoShare - expected) < 0.0001)
    }
}
