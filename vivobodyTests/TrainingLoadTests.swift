//
//  TrainingLoadTests.swift
//  vivobodyTests
//
//  Guards personal rolling training load on a virtual clock: comparable
//  volume-load selection, exact hard-set fallback, seven-day calendar
//  windows, four prior-week baseline, recent-range bands, concrete
//  baseline progress, recent-measure transitions, drivers, and the
//  12-week trend.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct TrainingLoadTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func session(
        daysAgo: Int,
        sets: Int,
        reps: Int = 8,
        weight: Double = 100,
        completed: Bool = true,
        mode: TrackingMode = .reps,
        modality: ExerciseModality = .dynamicStrength,
        loadMode: ExerciseLoadMode = .external,
        bodyweightFraction: Double = 0,
        bodyweightAtStart: Double = ExerciseLoad.unknownBodyweight,
        setCompleted: Bool = true,
        duration: TimeInterval = 0
    ) -> WorkoutSession {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        let ex = Exercise(
            name: mode == .duration ? "Plank" : "Bench Press",
            group: mode == .duration ? .core : .chest,
            plannedSets: 0,
            plannedWeight: 0,
            trackingMode: mode,
            modality: modality,
            loadMode: loadMode,
            bodyweightFraction: bodyweightFraction
        )
        for i in 0..<sets {
            ex.sets.append(
                WorkoutSet(
                    weight: weight,
                    reps: reps,
                    duration: duration,
                    isCompleted: setCompleted,
                    sortOrder: i
                )
            )
        }
        let s = WorkoutSession(
            exercises: [ex],
            bodyweightAtStart: bodyweightAtStart,
            startedAt: date
        )
        if completed {
            s.completedAt = date
        }
        return s
    }

    private func steadyBaseline(sets: Int = 3) -> [WorkoutSession] {
        [9, 16, 23, 30].map { session(daysAgo: $0, sets: sets) }
    }

    // MARK: - History gate

    @Test func insufficientBeforeFourWeeks() {
        let sessions = [
            session(daysAgo: 1, sets: 3),
            session(daysAgo: 8, sets: 3),
        ]
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(report.verdict == .insufficient)
        #expect(report.hasEnoughHistory == false)
        #expect(abs((report.provisionalRatio ?? 0) - 1) < 0.001)
        #expect(report.gaugeRatio == report.provisionalRatio)
        #expect(report.activeBaselineWeeks == 1)
        #expect(report.baselineWeeksRemaining == 2)
        #expect(report.baselineDaysRemaining == 20)
        #expect(report.observedBaselineDays == 8)
    }

    @Test func sparseBaselineStaysInsufficient() {
        let sessions = [
            session(daysAgo: 2, sets: 3),
            session(daysAgo: 9, sets: 3),
            session(daysAgo: 30, sets: 3),
        ]
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(report.daysLogged >= 28)
        #expect(report.verdict == .insufficient)
        #expect(report.usualLoad == nil)
        #expect(report.activeBaselineWeeks == 2)
        #expect(report.baselineWeeksRemaining == 1)
        #expect(report.baselineDaysRemaining == 0)
        #expect(report.observedBaselineDays == TrainingLoadReport.baselineMinimumDays)
    }

    @Test func emptyHistoryIsInsufficient() {
        let report = [WorkoutSession]().trainingLoad(now: now, calendar: calendar)
        #expect(report.verdict == .insufficient)
        #expect(report.currentLoad == 0)
        #expect(report.points.isEmpty)
        #expect(report.provisionalRatio == nil)
        #expect(report.gaugeRatio == nil)
        #expect(report.activeBaselineWeeks == 0)
        #expect(report.baselineWeeksRemaining == TrainingLoadReport.requiredActiveBaselineWeeks)
        #expect(report.baselineDaysRemaining == TrainingLoadReport.baselineMinimumDays)
    }

    // MARK: - Personal range

    @Test func steadyLoadReadsWithinRecentRange() {
        var sessions = steadyBaseline()
        sessions.append(session(daysAgo: 2, sets: 3))
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(report.measure == .volumeLoad)
        #expect(abs(report.currentLoad - 2400) < 0.001)
        #expect(abs((report.usualLoad ?? 0) - 2400) < 0.001)
        #expect(abs(report.ratio - 1.0) < 0.001)
        #expect(report.provisionalRatio == nil)
        #expect(report.gaugeRatio == report.ratio)
        #expect(report.verdict == .productive)
        #expect(report.activeBaselineWeeks == 4)
        #expect(abs((report.recentRange?.lowerBound ?? 0) - 1920) < 0.001)
        #expect(abs((report.recentRange?.upperBound ?? 0) - 3120) < 0.001)
    }

    @Test func loadReadsAboveRecentRange() {
        var sessions = steadyBaseline(sets: 2)
        sessions.append(session(daysAgo: 2, sets: 4))
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(report.ratio > 1.3)
        #expect(report.verdict == .high)
    }

    @Test func loadReadsBelowRecentRange() {
        var sessions = steadyBaseline(sets: 4)
        sessions.append(session(daysAgo: 2, sets: 2))
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(report.ratio < 0.8)
        #expect(report.verdict == .low)
    }

    @Test func statusBoundariesAreInclusiveOfRecentRange() {
        #expect(LoadVerdict.from(ratio: 0.799) == .low)
        #expect(LoadVerdict.from(ratio: 0.8) == .productive)
        #expect(LoadVerdict.from(ratio: 1.3) == .productive)
        #expect(LoadVerdict.from(ratio: 1.301) == .high)
    }

    @Test func medianBaselineResistsOneUnusualWeek() {
        var sessions = [
            session(daysAgo: 9, sets: 3),
            session(daysAgo: 16, sets: 12),
            session(daysAgo: 23, sets: 3),
            session(daysAgo: 30, sets: 3),
        ]
        sessions.append(session(daysAgo: 2, sets: 3))
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(abs((report.usualLoad ?? 0) - 2400) < 0.001)
        #expect(report.verdict == .productive)
    }

    @Test func volumeLoadMeasureShowsProgressiveOverload() {
        var sessions = [
            session(daysAgo: 30, sets: 1, weight: 100),
            session(daysAgo: 23, sets: 1, weight: 105),
            session(daysAgo: 16, sets: 1, weight: 110),
            session(daysAgo: 9, sets: 1, weight: 115),
        ]
        sessions.append(session(daysAgo: 2, sets: 1, weight: 120))

        let report = sessions.trainingLoad(now: now, calendar: calendar)
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now))
        let priorPoint = report.points.first(where: { $0.date == sevenDaysAgo })

        #expect(report.measure == .volumeLoad)
        #expect(report.ratio > 1)
        #expect((report.points.last?.load ?? 0) > (priorPoint?.load ?? 0))
    }

    @Test func volumeLoadMeasureRecognizesDeloadAtFixedSetsAndReps() {
        var sessions = steadyBaseline(sets: 3)
        sessions.append(session(daysAgo: 2, sets: 3, weight: 60))

        let report = sessions.trainingLoad(now: now, calendar: calendar)

        #expect(report.measure == .volumeLoad)
        #expect(abs(report.ratio - 0.6) < 0.001)
        #expect(report.verdict == .low)
    }

    @Test func unknownBodyweightOnlyHistoryKeepsHardSetMeasure() {
        var sessions = [9, 16, 23, 30].map {
            session(
                daysAgo: $0,
                sets: 3,
                weight: 0,
                loadMode: .bodyweightAdded,
                bodyweightFraction: 1
            )
        }
        sessions.append(session(
            daysAgo: 2,
            sets: 3,
            weight: 0,
            loadMode: .bodyweightAdded,
            bodyweightFraction: 1
        ))

        let report = sessions.trainingLoad(now: now, calendar: calendar)

        #expect(report.measure == .hardSets)
        #expect(report.currentLoad == 3)
        #expect(report.usualLoad == 3)
        #expect(report.ratio == 1)
        #expect(report.drivers.hardSets.current == 3)
        #expect(report.drivers.volumeLoad.current == 0)
        #expect(report.loadAvailability == .unavailable)
    }

    @Test func zeroEnteredExternalLoadKeepsHardSetMeasure() {
        var sessions = [9, 16, 23, 30].map {
            session(daysAgo: $0, sets: 3, weight: 0)
        }
        sessions.append(session(daysAgo: 2, sets: 3, weight: 0))

        let report = sessions.trainingLoad(now: now, calendar: calendar)

        #expect(report.measure == .hardSets)
        #expect(report.currentLoad == 3)
        #expect(report.ratio == 1)
        #expect(report.loadAvailability == .complete)
    }

    @Test func mixedComparableCoverageReportsPartial() {
        let known = session(daysAgo: 2, sets: 1, reps: 8, weight: 100)
        let unknown = session(
            daysAgo: 1,
            sets: 1,
            reps: 8,
            weight: 0,
            loadMode: .bodyweightAdded,
            bodyweightFraction: 1
        )

        let report = [known, unknown].trainingLoad(now: now, calendar: calendar)

        #expect(report.measure == .volumeLoad)
        #expect(report.currentLoad == 800)
        #expect(report.loadAvailability == .partial)
        #expect(report.drivers.hardSets.current == 2)
        #expect(report.drivers.sessions.current == 2)
    }

    @Test func oldVolumeOnlyWorkDoesNotAgeHardSetFallback() {
        let oldPower = session(
            daysAgo: 60,
            sets: 1,
            reps: 3,
            weight: 100,
            modality: .power
        )
        let baseline = session(
            daysAgo: 9,
            sets: 2,
            weight: 0,
            loadMode: .bodyweightAdded,
            bodyweightFraction: 1
        )
        let current = session(
            daysAgo: 1,
            sets: 2,
            weight: 0,
            loadMode: .bodyweightAdded,
            bodyweightFraction: 1
        )

        let report = [oldPower, baseline, current].trainingLoad(now: now, calendar: calendar)

        #expect(report.measure == .hardSets)
        #expect(report.daysLogged == 9)
        #expect(report.activeBaselineWeeks == 1)
        #expect(report.points.count == 10)
    }

    @Test func externalPowerCanEstablishVolumeLoadBaseline() {
        var sessions = [9, 16, 23, 30].map {
            session(daysAgo: $0, sets: 1, reps: 3, weight: 100, modality: .power)
        }
        sessions.append(session(daysAgo: 2, sets: 1, reps: 3, weight: 100, modality: .power))

        let report = sessions.trainingLoad(now: now, calendar: calendar)

        #expect(report.measure == .volumeLoad)
        #expect(report.daysLogged == 30)
        #expect(report.activeBaselineWeeks == 4)
        #expect(report.currentLoad == 300)
        #expect(report.ratio == 1)
        #expect(report.drivers.hardSets.current == 0)
        #expect(report.drivers.sessions.current == 1)
        #expect(report.drivers.sessions.usual == 1)
    }

    @Test func returningToVolumeLoadAfterHardSetOnlyGapRebuildsRecentBaseline() {
        let oldWeighted = session(daysAgo: 70, sets: 3, weight: 100)
        let recentBodyweight = [2, 9, 16, 23, 30].map {
            session(
                daysAgo: $0,
                sets: 3,
                weight: 0,
                loadMode: .bodyweightAdded,
                bodyweightFraction: 1
            )
        }
        let fallback = ([oldWeighted] + recentBodyweight)
            .trainingLoad(now: now, calendar: calendar)

        #expect(fallback.measure == .hardSets)
        #expect(fallback.hasEnoughHistory)

        let resumed = ([oldWeighted] + recentBodyweight + [
            session(daysAgo: 1, sets: 3, weight: 100),
        ]).trainingLoad(now: now, calendar: calendar)

        #expect(resumed.measure == .volumeLoad)
        #expect(resumed.daysLogged == 70)
        #expect(resumed.activeBaselineWeeks == 0)
        #expect(resumed.usualLoad == nil)
        #expect(resumed.verdict == .insufficient)
    }

    @Test func oneReportMeasureDrivesEveryRollingSample() {
        let baselineVolume = session(daysAgo: 9, sets: 1, weight: 100)
        let currentBodyweight = session(
            daysAgo: 1,
            sets: 1,
            weight: 0,
            loadMode: .bodyweightAdded,
            bodyweightFraction: 1
        )

        let report = [baselineVolume, currentBodyweight]
            .trainingLoad(now: now, calendar: calendar)

        #expect(report.measure == .volumeLoad)
        #expect(report.currentLoad == 0)
        #expect(report.points.last?.load == 0)
        #expect(report.recentDays.map(\.load).reduce(0, +) == 0)
        #expect(report.recentDays[5].trained)
        #expect(report.drivers.hardSets.current == 1)
    }

    // MARK: - Calendar windows

    @Test func rollingWindowIncludesSevenCalendarDays() {
        let sessions = [
            session(daysAgo: 6, sets: 2),
            session(daysAgo: 7, sets: 5),
        ]
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(abs(report.currentLoad - 1600) < 0.001)
    }

    @Test func futureAndIncompleteSessionsAreExcluded() {
        let sessions = [
            session(daysAgo: 1, sets: 2),
            session(daysAgo: 2, sets: 5, completed: false),
            session(daysAgo: -1, sets: 7),
        ]
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(abs(report.currentLoad - 1600) < 0.001)
    }

    @Test func bodyweightAndTimedWorkContribute() {
        let sessions = [
            session(daysAgo: 1, sets: 1, reps: 10, weight: 0),
            session(
                daysAgo: 2,
                sets: 1,
                reps: 0,
                weight: 0,
                mode: .duration,
                modality: .isometricStrength,
                duration: 30
            ),
        ]
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(abs(report.currentLoad - 2) < 0.001)
    }

    @Test func mixedModalitiesCreditStrengthWorkOnly() {
        let sessions = [
            session(daysAgo: 1, sets: 2, reps: 5, modality: .dynamicStrength),
            session(daysAgo: 2, sets: 3, reps: 3, modality: .power),
            session(
                daysAgo: 3,
                sets: 2,
                reps: 0,
                mode: .duration,
                modality: .isometricStrength,
                duration: 30
            ),
            session(
                daysAgo: 4,
                sets: 4,
                reps: 0,
                mode: .duration,
                modality: .dynamicStrength,
                duration: 30
            ),
        ]
        let report = sessions.trainingLoad(now: now, calendar: calendar)

        #expect(abs(report.currentLoad - 1900) < 0.001)
        #expect(report.drivers.sessions.current == 3)
        #expect(report.drivers.heavySets.current == 2)
        #expect(report.drivers.moderateSets.current == 0)
    }

    @Test func incompleteWorkingSetsDoNotContribute() {
        let sessions = [
            session(daysAgo: 1, sets: 1, reps: 8),
            session(daysAgo: 2, sets: 3, reps: 8, setCompleted: false),
            session(
                daysAgo: 3,
                sets: 2,
                reps: 0,
                mode: .duration,
                modality: .isometricStrength,
                setCompleted: false,
                duration: 30
            ),
        ]
        let report = sessions.trainingLoad(now: now, calendar: calendar)

        #expect(abs(report.currentLoad - 800) < 0.001)
        #expect(report.drivers.sessions.current == 1)
        #expect(report.drivers.heavySets.current == 0)
        #expect(report.drivers.moderateSets.current == 1)
    }

    // MARK: - Drivers

    @Test func driversCompareCurrentWorkWithUsual() {
        var sessions = [9, 16, 23, 30].map {
            session(daysAgo: $0, sets: 3, reps: 5)
        }
        sessions.append(session(daysAgo: 1, sets: 3, reps: 5))
        sessions.append(session(daysAgo: 4, sets: 3, reps: 5))

        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(report.drivers.volumeLoad.current == 3000)
        #expect(report.drivers.volumeLoad.usual == 1500)
        #expect(report.drivers.hardSets.current == 6)
        #expect(report.drivers.hardSets.usual == 3)
        #expect(report.drivers.sessions.current == 2)
        #expect(report.drivers.sessions.usual == 1)
        #expect(report.drivers.heavySets.current == 6)
        #expect(report.drivers.heavySets.usual == 3)
        #expect(report.drivers.moderateSets.current == 0)
        #expect(report.drivers.moderateSets.usual == 0)
    }

    @Test func moderateRepDriverCountsSixThroughTwelve() {
        let report = [
            session(daysAgo: 1, sets: 2, reps: 6),
            session(daysAgo: 2, sets: 3, reps: 12),
            session(daysAgo: 3, sets: 4, reps: 13),
            session(daysAgo: 7, sets: 5, reps: 8),
        ].trainingLoad(now: now, calendar: calendar)

        #expect(report.drivers.moderateSets.current == 5)
    }

    // MARK: - Recent days

    @Test func recentDaysSpanTrailingWeekEndingToday() {
        let sessions = [
            session(daysAgo: 0, sets: 3),
            session(daysAgo: 2, sets: 2),
            session(daysAgo: 7, sets: 5),
        ]
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(report.recentDays.count == 7)
        #expect(report.recentDays == report.recentDays.sorted { $0.date < $1.date })
        #expect(report.recentDays.last?.date == calendar.startOfDay(for: now))
        #expect(report.recentDays.last?.load == 2400)
        #expect(report.recentDays[4].load == 1600)
        // Day 7 falls outside the trailing-week strip.
        #expect(report.recentDays.map(\.load).reduce(0, +) == 4000)
    }

    @Test func recentDaysZeroFillRestDays() {
        let sessions = [session(daysAgo: 3, sets: 4)]
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(report.recentDays.filter(\.trained).count == 1)
        #expect(report.recentDays[3].load == 3200)
        #expect(report.recentDays.last?.trained == false)
    }

    @Test func recentDaysMergeSameDaySessions() {
        let sessions = [
            session(daysAgo: 1, sets: 2),
            session(daysAgo: 1, sets: 3),
        ]
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(report.recentDays[5].load == 4000)
    }

    @Test func recentDaysEmptyWithoutHistory() {
        let report = [WorkoutSession]().trainingLoad(now: now, calendar: calendar)
        #expect(report.recentDays.isEmpty)
    }

    // MARK: - Trend

    @Test func trendIsChronologicalAndEndsToday() {
        let sessions = [
            session(daysAgo: 16, sets: 2),
            session(daysAgo: 0, sets: 3),
        ]
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(report.points.count == 17)
        #expect(report.points == report.points.sorted { $0.date < $1.date })
        #expect(report.points.last?.date == calendar.startOfDay(for: now))
        #expect(report.points.last?.load == 2400)
    }

    @Test func trendCapsAtEightyFourDailyPoints() {
        let sessions = stride(from: 0, through: 700, by: 7).map {
            session(daysAgo: $0, sets: 1)
        }
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        #expect(report.points.count == 84)
    }

    @Test func trendBandUsesOnlyPriorWeeks() {
        var sessions = steadyBaseline(sets: 3)
        sessions.append(session(daysAgo: 2, sets: 12))
        let report = sessions.trainingLoad(now: now, calendar: calendar)
        let latest = report.points.last
        #expect(latest?.load == 9600)
        #expect(abs((latest?.rangeLower ?? 0) - 1920) < 0.001)
        #expect(abs((latest?.rangeUpper ?? 0) - 3120) < 0.001)
    }
}
