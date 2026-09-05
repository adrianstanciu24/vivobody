//
//  SetSeriesStaminaTests.swift
//  vivobodyTests
//
// Constant-load runs, RIR ambiguity, and matched trends with deterministic dates.

import Foundation
import Testing
@testable import vivobody

@MainActor
struct SetSeriesStaminaTests {
    private typealias F = InsightsDimensionFixtures

    private func runs(_ sets: [AnalyticsSetSnapshot]) -> [StaminaSeries] {
        F.replay([F.session([F.exercise(sets)])]).staminaSeries(now: F.now)
    }

    @Test func tenNineEightHoldsEightyPercent() throws {
        let run = try #require(runs([F.set(10), F.set(9), F.set(8)]).first)
        #expect(run.reps == [10, 9, 8])
        #expect(run.retention == 0.8)
        #expect(!run.isHeldBack)
        #expect(run.hasUnratedSets)
    }

    @Test func threeIsMinimumAndLongSeriesIsNotSplitIntoTriples() {
        #expect(runs([F.set(), F.set()]).isEmpty)
        #expect(runs(Array(repeating: F.set(), count: 6)).count == 1)
        #expect(runs(Array(repeating: F.set(), count: 6)).first?.reps.count == 6)
    }

    @Test func weightChangeBreaksSeriesAndReturningWeightDoesNotBridgeIt() {
        let sets = [F.set(), F.set(), F.set(weight: 110), F.set(), F.set()]
        #expect(runs(sets).isEmpty)
        let twoRuns = [F.set(), F.set(), F.set(), F.set(weight: 110), F.set(weight: 110), F.set(weight: 110)]
        #expect(runs(twoRuns).map(\.weight) == [100, 110])
    }

    @Test func incompleteEmptyAndInvalidWeightsBreakContiguity() {
        for breaker in [F.set(completed: false), F.set(0), F.set(-1), F.set(weight: .nan), F.set(weight: -1)] {
            #expect(runs([F.set(), F.set(), breaker, F.set(), F.set()]).isEmpty)
        }
    }

    @Test func separateExercisesAndSessionsNeverFormASeries() {
        let short = F.exercise([F.set(), F.set()])
        let replay = F.replay([F.session([short, short]), F.session([short], daysAgo: 2)])
        #expect(replay.staminaSeries(now: F.now).isEmpty)
    }

    @Test func latestRunKeepsNumericSetOrderBeyondTenSets() {
        let sets = Array(repeating: F.set(weight: 90), count: 4)
            + Array(repeating: F.set(weight: 100), count: 6)
            + Array(repeating: F.set(weight: 110), count: 3)
        let report = ExerciseStamina(series: runs(sets))
        #expect(report.latest?.weight == 110)
    }

    @Test func includesAllHistoryButRequiresCompletedDynamicRepWork() {
        let sets = [F.set(), F.set(), F.set()]
        let valid = F.exercise(sets)
        let archive = [F.session([F.exercise(sets, modality: .power)]),
                       F.session([F.exercise(sets, tracking: .duration)]),
                       F.session([F.exercise(sets, modality: .isometricStrength)]),
                       F.session([valid], completed: false), F.session([valid], daysAgo: -1),
                       F.session([valid], daysAgo: 0), F.session([valid], daysAgo: 84),
                       F.session([valid], daysAgo: 730)]
        #expect(F.replay(archive).staminaSeries(now: F.now).count == 3)
    }

    @Test func higherMiddleRIRFlagsRunEvenWhenLastSetReturnsToEffort() throws {
        let series = runs([F.set(10, rir: 1), F.set(8, rir: 3), F.set(8, rir: 1)])
        let run = try #require(series.first)
        #expect(run.heldBackIndices == [1])
        #expect(run.comparisonKey == nil)
        let report = SetSeriesStamina.make(series: series, now: F.now)
        #expect(report.patterns.isEmpty)
        #expect(report.heldBackCount == 1)
        #expect(report.byExercise["bench"]?.latest?.isHeldBack == true)
    }

    @Test func unloggedRIRDoesNotInventHeldBackStatus() throws {
        let run = try #require(runs([F.set(10), F.set(9, rir: 4), F.set(8, rir: 3)]).first)
        #expect(!run.isHeldBack)
        #expect(run.hasUnratedSets)
        #expect(run.rir == [nil, 4, 3])
    }

    @Test func unknownMiddleRIRDoesNotEraseEarlierLoggedEffort() throws {
        let run = try #require(runs([F.set(10, rir: 1), F.set(9), F.set(7, rir: 2)]).first)
        #expect(run.heldBackIndices == [2])
    }

    @Test func retentionAboveOneHundredIsPreserved() {
        #expect(runs([F.set(8), F.set(9), F.set(10)]).first?.retention == 1.25)
    }

    @Test func patternReadAveragesRunsAndExcludesIsolationFromPatternOnly() throws {
        let push = F.exercise([F.set(10), F.set(9), F.set(8)])
        let other = F.exercise([F.set(10), F.set(8), F.set(6)], key: "other")
        let isolation = F.exercise([F.set(), F.set(), F.set()], key: "curl", pattern: nil)
        let series = F.replay([F.session([push, other, isolation])]).staminaSeries(now: F.now)
        let report = SetSeriesStamina.make(series: series, now: F.now)
        let pattern = try #require(report.patterns.first)
        #expect(abs(pattern.retention - 0.7) < 0.000001)
        #expect(pattern.series.count == 2)
        #expect(report.unclassifiedCount == 1)
        #expect(report.byExercise["curl"] != nil)
    }

    @Test func trendMatchesSamePrescriptionAndExcludesChangedLoadOrRepScheme() throws {
        let current = F.exercise([F.set(10), F.set(9), F.set(8)])
        let prior = F.exercise([F.set(10), F.set(8), F.set(6)])
        let otherWeight = F.exercise([F.set(10, weight: 90), F.set(10, weight: 90), F.set(10, weight: 90)])
        let shorterReps = F.exercise([F.set(5), F.set(5), F.set(5)])
        let longer = F.exercise([F.set(10), F.set(9), F.set(8), F.set(8)])
        let series = F.replay([F.session([current]), F.session([prior], daysAgo: 730),
                               F.session([otherWeight, shorterReps, longer], daysAgo: 735)])
            .staminaSeries(now: F.now)
        let report = SetSeriesStamina.make(series: series, now: F.now)
        let pattern = try #require(report.patterns.first)
        #expect(try abs(#require(pattern.change) - 0.2) < 0.000001)
        #expect(pattern.matchedComparisons == 1)
        #expect(report.byExercise["bench"]?.trend.count == 2)
    }

    @Test func firstToLatestTrendUsesEndpointMeansAcrossAllHistory() throws {
        func exercise(_ last: Int) -> AnalyticsExerciseSnapshot {
            F.exercise([F.set(10), F.set(9), F.set(last)])
        }
        let archive = [F.session([exercise(8)]),
                       F.session([exercise(10)], daysAgo: 365),
                       F.session([exercise(4), exercise(6)], daysAgo: 730)]
        let series = F.replay(archive).staminaSeries(now: F.now)
        let report = SetSeriesStamina.make(series: series, now: F.now)
        let pattern = try #require(report.patterns.first)
        #expect(pattern.series.count == 4)
        #expect(try abs(#require(pattern.change) - 0.3) < 0.000001)
        #expect(pattern.matchedComparisons == 1)
        #expect(report.byExercise["bench"]?.trend.count == 4)
    }

    @Test func sameDateRunsCannotCreateAFirstToLatestChange() {
        let first = F.exercise([F.set(10), F.set(9), F.set(6)])
        let last = F.exercise([F.set(10), F.set(9), F.set(8)])
        let series = F.replay([F.session([first, last], daysAgo: 730)]).staminaSeries(now: F.now)
        let pattern = SetSeriesStamina.make(series: series, now: F.now).patterns.first
        #expect(pattern?.series.count == 2)
        #expect(pattern?.change == nil)
        #expect(pattern?.matchedComparisons == 0)
    }

    @Test func oldHistoryFeedsPatternsCountsAndExerciseDetail() {
        let regular = F.exercise([F.set(10), F.set(9), F.set(8)])
        let heldBack = F.exercise([F.set(10, rir: 1), F.set(9, rir: 3), F.set(8, rir: 1)], key: "held")
        let isolation = F.exercise([F.set(), F.set(), F.set()], key: "curl", pattern: nil)
        let common = F.replay([F.session([regular, heldBack, isolation], daysAgo: 730)])
        let core = SessionAnalytics.CoreReports.make(from: common, now: F.now)
        #expect(core.stamina.patterns.first?.retention == 0.8)
        #expect(core.stamina.patterns.first?.series.count == 1)
        #expect(core.stamina.heldBackCount == 1)
        #expect(core.stamina.unratedCount == 2)
        #expect(core.stamina.unclassifiedCount == 1)
        #expect(core.exerciseDetail.staminaByKey["bench"]?.series.count == 1)
        #expect(core.exerciseDetail.staminaByKey["held"]?.latest?.isHeldBack == true)
    }

    @Test func changedBodyweightAndUnknownResistanceCannotClaimSameLoadTrend() {
        let sets = [F.set(), F.set(), F.set()]
        let current = F.exercise(sets, mode: .bodyweightAdded, bodyweight: 180)
        let prior = F.exercise(sets, mode: .bodyweightAdded, bodyweight: 170)
        let series = F.replay([F.session([current]), F.session([prior], daysAgo: 35)]).staminaSeries(now: F.now)
        #expect(SetSeriesStamina.make(series: series, now: F.now).patterns.first?.change == nil)
        let unknown = F.exercise(sets, mode: .nonComparable)
        let unknownRun = F.replay([F.session([unknown])]).staminaSeries(now: F.now).first
        #expect(unknownRun?.comparisonKey == nil)
    }

    @Test func liveAndFutureSeriesAreExcludedFromTheCachedGeneration() {
        let exercise = F.exercise([F.set(), F.set(), F.set()])
        let common = F.replay([F.session([exercise]), F.session([exercise], daysAgo: -1)])
        let core = SessionAnalytics.CoreReports.make(from: common, now: F.now)
        #expect(core.stamina.series.count == 1)
        #expect(core.exerciseDetail.staminaByKey["bench"]?.series.count == 1)
    }

    @Test func effortLoggingAndFirstEffortMustMatchForTrend() {
        let current = F.exercise([F.set(10, rir: 2), F.set(9, rir: 2), F.set(8, rir: 1)])
        let unrated = F.exercise([F.set(10), F.set(9), F.set(8)])
        let differentEffort = F.exercise([F.set(10, rir: 1), F.set(9, rir: 1), F.set(8, rir: 1)])
        let series = F.replay([F.session([current]), F.session([unrated, differentEffort], daysAgo: 35)])
            .staminaSeries(now: F.now)
        #expect(SetSeriesStamina.make(series: series, now: F.now).patterns.first?.change == nil)
    }
}
