//
//  StrengthOutlookTests.swift
//  vivobodyTests
//
//  Guards the confidence-gated per-exercise strength-trend engine:
//  eligible estimated-1RM points, stale highs, now-relative forecasts,
//  sparse histories, unsupported estimates, and deterministic ranking.
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

    /// One session per weight, `everyDays` apart, from `startingDay`.
    private func series(
        _ name: String,
        _ group: MuscleGroup,
        weights: [Double],
        startingDay: Double = 0,
        everyDays: Double = 7,
        reps: Int = 5
    ) -> [WorkoutSession] {
        weights.enumerated().map { i, w in
            session(
                at: day(startingDay + Double(i) * everyDays),
                [lift(name, group, weight: w, reps: reps)]
            )
        }
    }

    private func now(after sessions: [WorkoutSession]) -> Date {
        sessions.map { $0.completedAt! }.max()!
    }

    // MARK: - Climbing / recent e1RM high

    @Test func progressiveOverloadSetsRecentE1RMHigh() {
        let s = series("Bench Press", .chest, weights: [135, 140, 145, 150, 155])
        let board = s.strengthOutlook(now: now(after: s))

        let bench = board.stat(forHistoryKey: ExerciseIdentity.nameKey("Bench Press"))
        #expect(bench?.trend == .climbing)
        #expect(bench?.isLatestE1RMHigh == true)
        #expect(bench?.isRecentE1RMHigh == true)
        #expect(bench?.isFreshPR == true)
        // Just set the e1RM high — no projection needed.
        #expect(bench?.daysToE1RMHigh == nil)
        #expect((bench?.slopePerWeek ?? 0) > 0)
        #expect(board.nearestE1RMHigh == nil)
    }

    // MARK: - Climbing back → projected e1RM high

    @Test func grindingBackProjectsDaysToE1RMHigh() {
        // An old e1RM high, then a block climbing back up but not yet there.
        let s = series("Back Squat", .legs, weights: [255, 205, 215, 225, 235, 245, 250])
        let board = s.strengthOutlook(now: now(after: s))

        let squat = board.stat(forHistoryKey: ExerciseIdentity.nameKey("Back Squat"))
        #expect(squat?.trend == .climbing)
        #expect(squat?.isFreshPR == false)
        // Below the old best, climbing → a finite ETA within horizon.
        if let days = squat?.daysToE1RMHigh {
            #expect(days >= 1)
            #expect(days <= StrengthOutlookBoard.horizonDays)
        } else {
            Issue.record("expected a projected date for the prior e1RM high")
        }
    }

    @Test func projectedE1RMHighExpiresAsNowPassesTheCrossingDate() {
        let s = series(
            "Back Squat",
            .legs,
            weights: [255, 205, 215, 225, 235, 245, 250]
        )
        let latest = now(after: s)
        let key = ExerciseIdentity.nameKey("Back Squat")

        #expect(s.strengthOutlook(now: latest)
            .stat(forHistoryKey: key)?.daysToE1RMHigh != nil)
        #expect(s.strengthOutlook(now: latest.addingTimeInterval(10 * 86_400))
            .stat(forHistoryKey: key)?.daysToE1RMHigh == nil)
    }

    // MARK: - Plateau

    @Test func flatProgramPlateaus() {
        let s = series("Overhead Press", .shoulders, weights: [95, 95, 95, 95, 95, 95])
        let board = s.strengthOutlook(now: now(after: s))

        let ohp = board.stat(forHistoryKey: ExerciseIdentity.nameKey("Overhead Press"))
        #expect(ohp?.trend == .plateaued)
        #expect(ohp?.isFreshPR == false)
        #expect(ohp?.daysToE1RMHigh == nil)
    }

    // MARK: - Slipping

    @Test func descendingProgramSlips() {
        let s = series("Deadlift", .back, weights: [405, 395, 385, 375, 365])
        let board = s.strengthOutlook(now: now(after: s))

        let dl = board.stat(forHistoryKey: ExerciseIdentity.nameKey("Deadlift"))
        #expect(dl?.trend == .slipping)
        #expect((dl?.slopePerWeek ?? 0) < 0)
        #expect(dl?.daysToE1RMHigh == nil)
    }

    // MARK: - Exclusions

    @Test func tooFewPointsExcluded() {
        let s = series("Bench Press", .chest, weights: [135, 140, 145])
        let board = s.strengthOutlook(now: now(after: s))
        #expect(board.stat(forHistoryKey: ExerciseIdentity.nameKey("Bench Press")) == nil)
    }

    @Test func compressedHistoryIsExcluded() {
        let s = series(
            "Bench Press",
            .chest,
            weights: [135, 140, 145, 150],
            everyDays: 3
        )
        let board = s.strengthOutlook(now: now(after: s))

        #expect(board.stat(forHistoryKey: ExerciseIdentity.nameKey("Bench Press")) == nil)
    }

    @Test func confidenceRequiresSixRecentPointsAcrossFourWeeks() {
        let developing = series("Early Press", .chest, weights: [100, 105, 110, 115])
        let established = series("Mature Press", .chest, weights: [100, 105, 110, 115, 120, 125])

        let earlyStat = developing.strengthOutlook(now: now(after: developing))
            .stat(forHistoryKey: ExerciseIdentity.nameKey("Early Press"))
        let matureStat = established.strengthOutlook(now: now(after: established))
            .stat(forHistoryKey: ExerciseIdentity.nameKey("Mature Press"))

        #expect(earlyStat?.confidence == .developing)
        #expect(earlyStat?.sampleCount == 4)
        #expect(earlyStat?.spanDays == 21)
        #expect(matureStat?.confidence == .established)
        #expect(matureStat?.sampleCount == 6)
        #expect(matureStat?.spanDays == 35)
    }

    @Test func unloadedExternalLiftExcluded() {
        // Zero external load cannot produce a comparable strength estimate.
        let s = series("Pull-Up", .back, weights: [0, 0, 0, 0])
        let board = s.strengthOutlook(now: now(after: s))
        #expect(board.stat(forHistoryKey: ExerciseIdentity.nameKey("Pull-Up")) == nil)
    }

    @Test func highRepOnlyHistoryCannotCreateStrengthCurve() {
        let s = series(
            "High-Rep Press",
            .chest,
            weights: [80, 85, 90, 95],
            reps: 20
        )
        let board = s.strengthOutlook(now: now(after: s))

        #expect(board.stat(forHistoryKey: ExerciseIdentity.nameKey("High-Rep Press")) == nil)
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
            session(at: day(7), [weightedPullUp(25)], bodyweightAtStart: 200),
            session(at: day(14), [weightedPullUp(30)], bodyweightAtStart: 200),
            session(at: day(21), [weightedPullUp(35)], bodyweightAtStart: 200),
            session(at: day(28), [weightedPullUp(40)]),
        ]
        let stat = sessions.strengthOutlook(now: day(30)).stat(
            forHistoryKey: ExerciseIdentity.nameKey("Weighted Pull-Up Fixture")
        )

        #expect(stat?.currentE1RM == 235 * (1 + 5.0 / 30.0))
        #expect(stat?.daysSinceLastEstimate == 9)
        #expect(stat?.daysSinceLastTrained == 2)
    }

    @Test func aStandingHighStopsReadingAsNewWhenItIsStale() {
        let s = series("Bench Press", .chest, weights: [135, 140, 145, 150, 155])
        let stat = s.strengthOutlook(now: day(128)).stat(
            forHistoryKey: ExerciseIdentity.nameKey("Bench Press")
        )

        #expect(stat?.isLatestE1RMHigh == true)
        #expect(stat?.isRecentE1RMHigh == false)
        #expect(stat?.isFreshPR == false)
        #expect(stat?.daysSinceLastEstimate == 100)
    }

    @Test func aRecentHighDoesNotOverrideADecliningTrend() {
        let s = series(
            "Volatile Press",
            .chest,
            weights: [99, 98, 1, 1, 1, 100]
        )
        let stat = s.strengthOutlook(now: now(after: s)).stat(
            forHistoryKey: ExerciseIdentity.nameKey("Volatile Press")
        )

        #expect(stat?.isRecentE1RMHigh == true)
        #expect(stat?.trend == .slipping)
        #expect((stat?.slopePerWeek ?? 0) < 0)
    }

    @Test func emptyArchiveEmptyBoard() {
        let board = [WorkoutSession]().strengthOutlook(now: day(0))
        #expect(!board.hasAny)
        #expect(board.stats.isEmpty)
        #expect(board.nearestE1RMHigh == nil)
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
            session(at: day(21), [lift(
                "Current Press Name",
                .chest,
                catalogItemID: reseededCatalogUUID,
                catalogID: "stable-press",
                weight: 115
            )]),
        ]

        let board = sessions.strengthOutlook(now: now(after: sessions))
        let stat = board.stat(forHistoryKey: "bundled:stable-press")

        #expect(board.stats.count == 1)
        #expect(stat?.historyKey == "bundled:stable-press")
        #expect(stat?.catalogID == "stable-press")
        #expect(stat?.currentE1RM == 115 * (1 + 5.0 / 30.0))
    }

    @Test func sameNameCustomExercisesRemainDistinctByCatalogUUID() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000021")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000022")!
        let first = [100.0, 105, 110, 115].enumerated().map { index, weight in
            session(at: day(Double(index) * 7), [lift(
                "Custom Press",
                .chest,
                catalogItemID: firstID,
                weight: weight
            )])
        }
        let second = [200.0, 195, 190, 185].enumerated().map { index, weight in
            session(at: day(Double(index) * 7 + 1), [lift(
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
        let sessions = series("  Custom Cable Curl  ", .arms, weights: [30, 35, 40, 45])
        let board = sessions.strengthOutlook(now: now(after: sessions))

        #expect(
            board.stat(forHistoryKey: ExerciseIdentity.nameKey("custom cable curl"))?.historyKey
                == "name:custom cable curl"
        )
    }

    // MARK: - Ranking

    @Test func climbingRanksAheadOfSlipping() {
        let climbing = series(
            "Back Squat",
            .legs,
            weights: [255, 205, 215, 225, 235, 245, 250]
        )
        let slipping = series(
            "Deadlift",
            .back,
            weights: [405, 395, 385, 375, 365, 355, 345]
        )
        let all = climbing + slipping
        let board = all.strengthOutlook(now: now(after: all))

        #expect(board.stats.first?.exercise == "Back Squat")
        #expect(board.nearestE1RMHigh?.exercise == "Back Squat")
        #expect(board.climbingCount == 1)
        #expect(board.slippingCount == 1)
    }

    @Test func estimateRecencyRanksAheadOfTrend() {
        let oldClimber = series(
            "Old Climber",
            .chest,
            weights: [100, 105, 110, 115, 120]
        )
        let recentPlateau = series(
            "Recent Plateau",
            .shoulders,
            weights: [95, 95, 95, 95, 95],
            startingDay: 35
        )
        let all = oldClimber + recentPlateau
        let board = all.strengthOutlook(now: now(after: all))

        #expect(board.stats.first?.exercise == "Recent Plateau")
        #expect(board.stats.first?.trend == .plateaued)
    }

    @Test func exactRankingTiesUseDeterministicIdentityOrder() {
        let alpha = series("Alpha Press", .chest, weights: [100, 105, 110, 115])
        let zulu = series("Zulu Press", .chest, weights: [100, 105, 110, 115])

        let forward = (alpha + zulu).strengthOutlook(now: now(after: alpha + zulu))
        let reversed = (zulu + alpha).strengthOutlook(now: now(after: alpha + zulu))

        #expect(forward.stats.map(\.exercise) == ["Alpha Press", "Zulu Press"])
        #expect(reversed.stats.map(\.exercise) == ["Alpha Press", "Zulu Press"])
    }
}
