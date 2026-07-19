//
//  StrengthOutlookTests.swift
//  vivobodyTests
//
//  Guards the strength-trend engine behind the Insights "Strength"
//  section. It fits a line to each lift's estimated-1RM history, so
//  it's tested on a virtual clock: progressive overload sets a fresh
//  PR and reads climbing; a lift grinding back toward an old record
//  projects a days-to-PR; a flat program plateaus; a descending one
//  slips; bodyweight and too-thin histories are excluded.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct StrengthOutlookTests {

    // MARK: - Virtual clock

    private static let origin = Date(timeIntervalSince1970: 1_700_000_000)
    private func day(_ n: Double) -> Date { Self.origin.addingTimeInterval(n * 86_400) }

    // MARK: - Helpers

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

    private func lift(
        _ name: String,
        _ group: MuscleGroup,
        catalogItemID: UUID? = nil,
        catalogID: String? = nil,
        weight: Double,
        reps: Int = 5,
        loadMode: ExerciseLoadMode = .external,
        bodyweightFraction: Double = 0
    ) -> Exercise {
        let ex = Exercise(
            name: name,
            catalogItemID: catalogItemID,
            catalogID: catalogID,
            group: group,
            plannedSets: 1,
            plannedReps: reps,
            plannedWeight: weight,
            loadMode: loadMode,
            bodyweightFraction: bodyweightFraction
        )
        ex.sets.forEach { $0.isCompleted = true }
        return ex
    }

    /// One session per weight, `everyDays` apart, starting at day 0.
    private func series(_ name: String, _ group: MuscleGroup, weights: [Double], everyDays: Double = 4, reps: Int = 5) -> [WorkoutSession] {
        weights.enumerated().map { i, w in
            session(at: day(Double(i) * everyDays), [lift(name, group, weight: w, reps: reps)])
        }
    }

    private func now(after sessions: [WorkoutSession]) -> Date {
        sessions.map { $0.completedAt! }.max()!
    }

    // MARK: - Climbing / fresh PR

    @Test func progressiveOverloadSetsFreshPR() {
        let s = series("Bench Press", .chest, weights: [135, 140, 145, 150, 155])
        let board = s.strengthOutlook(now: now(after: s))

        let bench = board.stat(forHistoryKey: ExerciseIdentity.nameKey("Bench Press"))
        #expect(bench?.trend == .climbing)
        #expect(bench?.isFreshPR == true)
        // Just set the record — no projection needed.
        #expect(bench?.daysToPR == nil)
        #expect((bench?.slopePerWeek ?? 0) > 0)
    }

    // MARK: - Climbing back → projected PR

    @Test func grindingBackProjectsDaysToPR() {
        // An old record, then a block climbing back up but not yet there.
        let s = series("Back Squat", .legs, weights: [255, 205, 215, 225, 235, 245, 250])
        let board = s.strengthOutlook(now: now(after: s))

        let squat = board.stat(forHistoryKey: ExerciseIdentity.nameKey("Back Squat"))
        #expect(squat?.trend == .climbing)
        #expect(squat?.isFreshPR == false)
        // Below the old best, climbing → a finite ETA within horizon.
        if let days = squat?.daysToPR {
            #expect(days >= 1)
            #expect(days <= StrengthOutlookBoard.horizonDays)
        } else {
            Issue.record("expected a projected days-to-PR")
        }
    }

    // MARK: - Plateau

    @Test func flatProgramPlateaus() {
        let s = series("Overhead Press", .shoulders, weights: [95, 95, 95, 95, 95, 95])
        let board = s.strengthOutlook(now: now(after: s))

        let ohp = board.stat(forHistoryKey: ExerciseIdentity.nameKey("Overhead Press"))
        #expect(ohp?.trend == .plateaued)
        #expect(ohp?.isFreshPR == false)
        #expect(ohp?.daysToPR == nil)
    }

    // MARK: - Slipping

    @Test func descendingProgramSlips() {
        let s = series("Deadlift", .back, weights: [405, 395, 385, 375, 365])
        let board = s.strengthOutlook(now: now(after: s))

        let dl = board.stat(forHistoryKey: ExerciseIdentity.nameKey("Deadlift"))
        #expect(dl?.trend == .slipping)
        #expect((dl?.slopePerWeek ?? 0) < 0)
        #expect(dl?.daysToPR == nil)
    }

    // MARK: - Exclusions

    @Test func tooFewPointsExcluded() {
        let s = series("Bench Press", .chest, weights: [135, 140])
        let board = s.strengthOutlook(now: now(after: s))
        #expect(board.stat(forHistoryKey: ExerciseIdentity.nameKey("Bench Press")) == nil)
    }

    @Test func bodyweightLiftExcluded() {
        // Zero logged weight → estimated 1RM is zero → no strength curve.
        let s = series("Pull-Up", .back, weights: [0, 0, 0, 0])
        let board = s.strengthOutlook(now: now(after: s))
        #expect(board.stat(forHistoryKey: ExerciseIdentity.nameKey("Pull-Up")) == nil)
    }

    @Test func unknownBodyweightSessionStillUpdatesTrainingRecency() {
        func weightedPullUp(_ addedWeight: Double) -> Exercise {
            lift(
                "Weighted Pull-Up Fixture",
                .back,
                weight: addedWeight,
                loadMode: .bodyweightAdded,
                bodyweightFraction: 1
            )
        }

        let sessions = [
            session(at: day(0), [weightedPullUp(20)], bodyweightAtStart: 200),
            session(at: day(4), [weightedPullUp(25)], bodyweightAtStart: 200),
            session(at: day(8), [weightedPullUp(30)], bodyweightAtStart: 200),
            session(at: day(12), [weightedPullUp(35)]),
        ]
        let stat = sessions.strengthOutlook(now: day(14)).stat(
            forHistoryKey: ExerciseIdentity.nameKey("Weighted Pull-Up Fixture")
        )

        #expect(stat?.currentE1RM == 230 * (1 + 5.0 / 30.0))
        #expect(stat?.daysSinceLastTrained == 2)
    }

    @Test func emptyArchiveEmptyBoard() {
        let board = [WorkoutSession]().strengthOutlook(now: day(0))
        #expect(!board.hasAny)
        #expect(board.stats.isEmpty)
        #expect(board.nearestPR == nil)
    }

    // MARK: - Stable identity

    @Test func bundledRenameKeepsOneStrengthSeriesAcrossCatalogReseed() {
        let oldCatalogUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
        let reseededCatalogUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
        let sessions = [
            session(at: day(0), [lift(
                "Old Press Name",
                .chest,
                catalogItemID: oldCatalogUUID,
                catalogID: "stable-press",
                weight: 100
            )]),
            session(at: day(4), [lift(
                "Current Press Name",
                .chest,
                catalogItemID: reseededCatalogUUID,
                catalogID: "stable-press",
                weight: 105
            )]),
            session(at: day(8), [lift(
                "Current Press Name",
                .chest,
                catalogItemID: reseededCatalogUUID,
                catalogID: "stable-press",
                weight: 110
            )]),
        ]

        let board = sessions.strengthOutlook(now: now(after: sessions))
        let stat = board.stat(forHistoryKey: "bundled:stable-press")

        #expect(board.stats.count == 1)
        #expect(stat?.historyKey == "bundled:stable-press")
        #expect(stat?.catalogID == "stable-press")
        #expect(stat?.currentE1RM == 110 * (1 + 5.0 / 30.0))
    }

    @Test func sameNameCustomExercisesRemainDistinctByCatalogUUID() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000021")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000022")!
        let first = [100.0, 105, 110].enumerated().map { index, weight in
            session(at: day(Double(index) * 4), [lift(
                "Custom Press",
                .chest,
                catalogItemID: firstID,
                weight: weight
            )])
        }
        let second = [200.0, 195, 190].enumerated().map { index, weight in
            session(at: day(Double(index) * 4 + 1), [lift(
                "Custom Press",
                .chest,
                catalogItemID: secondID,
                weight: weight
            )])
        }
        let board = (first + second).strengthOutlook(now: now(after: first + second))
        let firstKey = first[0].exercises[0].historyKey
        let secondKey = second[0].exercises[0].historyKey

        #expect(board.stats.count == 2)
        #expect(Set(board.stats.map(\.id)) == [firstKey, secondKey])
        #expect(board.stat(forHistoryKey: firstKey)?.trend == .climbing)
        #expect(board.stat(forHistoryKey: secondKey)?.trend == .slipping)
    }

    @Test func unlinkedCustomExerciseUsesNormalizedNameFallback() {
        let sessions = series("  Custom Cable Curl  ", .arms, weights: [30, 35, 40])
        let board = sessions.strengthOutlook(now: now(after: sessions))

        #expect(
            board.stat(forHistoryKey: ExerciseIdentity.nameKey("custom cable curl"))?.historyKey
                == "name:custom cable curl"
        )
    }

    // MARK: - Ranking

    @Test func climbingRanksAheadOfSlipping() {
        let climbing = series("Bench Press", .chest, weights: [135, 140, 145, 150, 155])
        let slipping = series("Deadlift", .back, weights: [405, 395, 385, 375, 365])
        let all = climbing + slipping
        let board = all.strengthOutlook(now: now(after: all))

        #expect(board.stats.first?.exercise == "Bench Press")
        #expect(board.nearestPR?.exercise == "Bench Press")
        #expect(board.climbingCount == 1)
        #expect(board.slippingCount == 1)
    }
}
