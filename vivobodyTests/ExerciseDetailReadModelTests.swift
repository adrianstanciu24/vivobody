//
//  ExerciseDetailReadModelTests.swift
//  vivobodyTests
//
//  Guards Exercise Detail's immutable archive report: zero/one/many history
//  branches, standing-record and recent-row selection, effective-load and
//  one-rep-max and strength-readiness values, cadence/frequency reads,
//  accessibility text, and the SwiftData-facing factory's coherent published
//  cache boundary.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct ExerciseDetailReadModelTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(daysAgo: Int) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: now)!
    }

    private func descriptor(
        name: String = "Fixture Lift",
        modality: ExerciseModality = .dynamicStrength,
        trackingMode: TrackingMode = .reps,
        loadMode: ExerciseLoadMode = .external,
        bodyweightFraction: Double = 0,
        tracksResistance: Bool = true,
        measuredOneRepMax: Double? = nil,
        defaultLoggedWeight: Double = 135,
        currentBodyweight: Double = ExerciseLoad.unknownBodyweight
    ) -> ExerciseDetailReadModel.ExerciseDescriptor {
        ExerciseDetailReadModel.ExerciseDescriptor(
            name: name,
            modality: modality,
            trackingMode: trackingMode,
            loadMode: loadMode,
            bodyweightFraction: bodyweightFraction,
            tracksResistance: tracksResistance,
            measuredOneRepMax: measuredOneRepMax,
            defaultLoggedWeight: defaultLoggedWeight,
            currentBodyweight: currentBodyweight
        )
    }

    private func exercise(
        weight: Double,
        reps: Int = 8,
        duration: TimeInterval = 0,
        setCount: Int = 1,
        rir: Int? = nil,
        modality: ExerciseModality = .dynamicStrength,
        trackingMode: TrackingMode = .reps,
        loadMode: ExerciseLoadMode = .external,
        bodyweightFraction: Double = 0,
        classification: ExerciseClassification? = nil,
        involvement: Muscle.Involvement? = nil
    ) -> Exercise {
        let exercise = Exercise(
            name: "Fixture Lift",
            catalogID: "fixture-lift",
            group: .chest,
            plannedSets: 0,
            plannedWeight: 0,
            muscleInvolvement: involvement,
            classification: classification,
            trackingMode: trackingMode,
            modality: modality,
            loadMode: loadMode,
            bodyweightFraction: bodyweightFraction
        )
        for index in 0 ..< setCount {
            exercise.sets.append(
                WorkoutSet(
                    weight: weight,
                    reps: reps,
                    duration: duration,
                    isCompleted: true,
                    repsInReserve: rir ?? 2,
                    rirLogged: rir != nil,
                    sortOrder: index
                )
            )
        }
        return exercise
    }

    private func session(
        daysAgo: Int,
        bodyweight: Double = ExerciseLoad.unknownBodyweight,
        exercise: Exercise
    ) -> WorkoutSession {
        let date = date(daysAgo: daysAgo)
        let session = WorkoutSession(
            exercises: [exercise],
            bodyweightAtStart: bodyweight,
            startedAt: date
        )
        session.completedAt = date
        return session
    }

    private func reports(
        _ sessions: [WorkoutSession]
    ) -> (
        history: ExerciseHistorySummary?,
        progress: ExerciseProgress?
    ) {
        let accumulator = AnalyticsAccumulator.history(
            AnalyticsSnapshot(sessions: sessions)
        )
        return (
            accumulator.exerciseHistoryByExercise()["bundled:fixture-lift"],
            accumulator.progressByExercise.first {
                $0.id == "bundled:fixture-lift"
            }
        )
    }

    private func cachedReports(
        _ sessions: [WorkoutSession]
    ) -> ExerciseDetailReports {
        let accumulator = AnalyticsAccumulator.replay(
            AnalyticsSnapshot(sessions: sessions)
        )
        let progress = accumulator.progressByExercise
        let weeklyVolume = accumulator.muscleVolume(now: now)
        return ExerciseDetailReports.make(
            from: accumulator,
            history: accumulator.exerciseHistoryByExercise(),
            progress: progress,
            strength: StrengthOutlookBoard.compute(
                progress: progress,
                now: now
            ),
            weeklyVolume: weeklyVolume,
            now: now
        )
    }

    private func readModel(
        exercise: ExerciseDetailReadModel.ExerciseDescriptor,
        history: ExerciseHistorySummary? = nil,
        progress: ExerciseProgress? = nil,
        strengthTrendStat: StrengthOutlookStat? = nil,
        effort: ExerciseEffortSummary? = nil,
        volumeContribution: ExerciseVolumeContribution? = nil,
        weeklyVolumeStats: [MuscleVolumeStat] = [],
        unit: WeightUnit = .lb
    ) -> ExerciseDetailReadModel {
        ExerciseDetailReadModel(
            exercise: exercise,
            history: history,
            progress: progress,
            strengthTrendStat: strengthTrendStat,
            effort: effort,
            volumeContribution: volumeContribution,
            weeklyVolumeByMuscle: Dictionary(
                uniqueKeysWithValues: weeklyVolumeStats.map {
                    ($0.muscle, $0)
                }
            ),
            unit: unit,
            now: now,
            calendar: calendar
        )
    }

    @Test func emptyHistoryOwnsTheDormantBranchAndDefaultSeed() {
        let model = readModel(exercise: descriptor())

        #expect(model.historyState == .empty)
        #expect(!model.hasHistory)
        #expect(model.sessionCount == 0)
        #expect(model.now == now)
        #expect(model.latestHistoryInstance == nil)
        #expect(model.recordSource == nil)
        #expect(model.strengthTrendStat == nil)
        #expect(model.strengthTrendReadinessDates.isEmpty)
        #expect(model.bestSet.value == "—")
        #expect(model.bestSet.accessibilityLabel == "Best set, not recorded")
        #expect(model.frequency == nil)
        #expect(model.recentSessions.isEmpty)
        #expect(model.effectiveLoad == nil)
        #expect(model.estimatedOneRepMax == nil)
        #expect(model.oneRepMaxSeed == 135)
        #expect(model.cadence == nil)
    }

    @Test func singleBodyweightSessionExplainsLoadAndSeedsEstimatedMax() {
        let workout = session(
            daysAgo: 2,
            bodyweight: 180,
            exercise: exercise(
                weight: 20,
                reps: 5,
                setCount: 3,
                loadMode: .bodyweightAdded,
                bodyweightFraction: 1
            )
        )
        let report = reports([workout])
        let model = readModel(
            exercise: descriptor(
                loadMode: .bodyweightAdded,
                bodyweightFraction: 1,
                defaultLoggedWeight: 10,
                currentBodyweight: 180
            ),
            history: report.history,
            progress: report.progress
        )

        #expect(model.historyState == .single)
        #expect(model.bestSet.value == "BW + 20")
        #expect(model.bestSet.unit == "lb")
        #expect(model.bestSet.detail == "× 5")
        #expect(model.bestSet.dateText == "2d ago")
        #expect(model.frequency?.sessionCountText == "1")
        #expect(model.frequency?.perWeek == nil)
        #expect(model.frequency?.perWeekText == "—")
        #expect(model.effectiveLoad?.value == 200)
        #expect(model.effectiveLoad?.valueText == "200 lb")
        #expect(model.effectiveLoad?.formulaText?.contains("BW × 100% + 20 lb") == true)
        #expect(model.estimatedOneRepMax != nil)
        #expect(abs((model.estimatedOneRepMax ?? 0) - 233.333_333) < 0.001)
        #expect(abs(model.oneRepMaxSeed - 233.333_333) < 0.001)
        #expect(model.recentSessions.count == 1)
        #expect(model.recentSessions[0].completedSetCount == 3)
        #expect(model.recentSessions[0].metric.display == "BW + 20 lb × 5")
        #expect(model.recentSessions[0].isPersonalRecord)
    }

    @Test func unknownBodyweightKeepsEffectiveLoadUnavailable() {
        let workout = session(
            daysAgo: 1,
            exercise: exercise(
                weight: 20,
                reps: 5,
                loadMode: .bodyweightAdded,
                bodyweightFraction: 1
            )
        )
        let report = reports([workout])
        let model = readModel(
            exercise: descriptor(
                loadMode: .bodyweightAdded,
                bodyweightFraction: 1,
                currentBodyweight: ExerciseLoad.unknownBodyweight
            ),
            history: report.history,
            progress: report.progress
        )

        #expect(model.effectiveLoad?.value == nil)
        #expect(model.effectiveLoad?.valueText == "—")
        #expect(model.effectiveLoad?.formulaText == nil)
        #expect(
            model.effectiveLoad?.explanationText
                == "Body weight unavailable for this session"
        )
        #expect(
            model.effectiveLoad?.accessibilityLabel
                == "Effective load, —. Body weight unavailable for this session"
        )
        #expect(model.estimatedOneRepMax == nil)
    }

    @Test func multiSessionUnknownBodyweightDoesNotInventABestSet() {
        let sessions = [
            session(
                daysAgo: 2,
                exercise: exercise(
                    weight: 20,
                    reps: 5,
                    loadMode: .bodyweightAdded,
                    bodyweightFraction: 1
                )
            ),
            session(
                daysAgo: 1,
                exercise: exercise(
                    weight: 25,
                    reps: 5,
                    loadMode: .bodyweightAdded,
                    bodyweightFraction: 1
                )
            ),
        ]
        let report = reports(sessions)
        let model = readModel(
            exercise: descriptor(
                loadMode: .bodyweightAdded,
                bodyweightFraction: 1,
                currentBodyweight: ExerciseLoad.unknownBodyweight
            ),
            history: report.history,
            progress: report.progress
        )

        #expect(report.progress != nil)
        #expect(model.historyState == .many)
        #expect(model.recordSource == nil)
        #expect(model.bestSet.value == "—")
        #expect(model.bestSet.accessibilityLabel == "Best set, not recorded")
    }

    @Test func singleSessionEstimateRetainsTheHistoryFallbackAboveTwelveReps() {
        let workout = session(
            daysAgo: 1,
            exercise: exercise(weight: 100, reps: 15)
        )
        let report = reports([workout])
        let model = readModel(
            exercise: descriptor(),
            history: report.history,
            progress: report.progress
        )

        #expect(report.progress == nil)
        #expect(model.estimatedOneRepMax == 150)
        #expect(model.oneRepMaxSeed == 150)
    }

    @Test func progressAloneCannotInventHistoryCardinality() {
        let report = reports([
            session(daysAgo: 7, exercise: exercise(weight: 100)),
            session(daysAgo: 0, exercise: exercise(weight: 105)),
        ])
        let model = readModel(
            exercise: descriptor(),
            history: nil,
            progress: report.progress
        )

        #expect(model.progress != nil)
        #expect(model.historyState == .empty)
        #expect(model.sessionCount == 0)
        #expect(!model.hasHistory)
    }

    @Test func recentBadgesUseOnlyTheCurrentStandingRecordKind() throws {
        let oldHold = session(
            daysAgo: 2,
            exercise: exercise(
                weight: 200,
                reps: 0,
                duration: 60,
                modality: .isometricStrength,
                trackingMode: .duration
            )
        )
        let currentLift = session(
            daysAgo: 1,
            exercise: exercise(weight: 100, reps: 5)
        )
        let report = reports([oldHold, currentLift])
        let history = try #require(report.history)
        let model = readModel(
            exercise: descriptor(),
            history: history,
            progress: report.progress
        )

        #expect(history.currentAllTimeBest == .dynamic(effectiveLoad: 100, reps: 5))
        #expect(model.recentSessions.map(\.isPersonalRecord) == [true, false])
    }

    @Test func manySessionsChooseStandingRecordAndBuildCadenceOnce() {
        let inputs = [
            (35, 100.0),
            (28, 110.0),
            (21, 105.0),
            (14, 120.0),
            (7, 115.0),
            (0, 115.0),
        ]
        let sessions = inputs.map { daysAgo, weight in
            session(
                daysAgo: daysAgo,
                exercise: exercise(weight: weight)
            )
        }
        let report = reports(sessions.reversed())
        let model = readModel(
            exercise: descriptor(),
            history: report.history,
            progress: report.progress
        )

        #expect(model.historyState == .many)
        #expect(model.sessionCount == 6)
        #expect(model.bestSet.value == "120")
        #expect(model.bestSet.unit == "lb")
        #expect(model.bestSet.detail == "× 8")
        #expect(model.bestSet.dateText == "2w ago")
        #expect(model.frequency?.perWeek != nil)
        #expect(abs((model.frequency?.perWeek ?? 0) - 1.2) < 0.001)
        #expect(model.frequency?.perWeekText == "1.2×")
        #expect(model.recentSessions.count == 5)
        #expect(model.recentSessions.map(\.metric.display) == [
            "115 lb × 8", "115 lb × 8", "120 lb × 8",
            "105 lb × 8", "110 lb × 8",
        ])
        #expect(model.recentSessions[2].isPersonalRecord)
        #expect(model.cadence?.medianGapDays == 11)
        #expect(model.cadence?.daysSinceLastIncrease == 14)
        #expect(model.cadence?.isPastUsualRhythm == true)
        #expect(model.cadence?.currentDetailText == "3 days longer than usual")
        #expect(model.cadence?.loadRangeText == "100 → 120 lb")
        #expect(model.latestHistoryInstance?.date == date(daysAgo: 0))
        #expect(model.recordSource?.loggedWeight == 120)
    }

    @Test func untrackedHoldUsesDurationMetricAndSpokenTime() {
        let classification = ExerciseClassification(
            equipment: .bodyweight,
            mechanic: .compound,
            pattern: nil,
            direction: nil,
            planes: [.sagittal],
            laterality: .bilateral
        )
        let workout = session(
            daysAgo: 1,
            exercise: exercise(
                weight: 0,
                reps: 0,
                duration: 45,
                modality: .isometricStrength,
                trackingMode: .duration,
                loadMode: .nonComparable,
                classification: classification
            )
        )
        let report = reports([workout])
        let model = readModel(
            exercise: descriptor(
                modality: .isometricStrength,
                trackingMode: .duration,
                loadMode: .nonComparable,
                tracksResistance: false,
                defaultLoggedWeight: 0
            ),
            history: report.history,
            progress: report.progress
        )

        #expect(model.bestSet.value == "0:45")
        #expect(model.bestSet.unit == nil)
        #expect(model.bestSet.detail == nil)
        #expect(model.bestSet.accessibilityLabel.contains("45 seconds"))
        #expect(model.recentSessions[0].metric.display == "0:45")
        #expect(model.recentSessions[0].metric.accessibilityLabel == "45 seconds")
        #expect(model.estimatedOneRepMax == nil)
        #expect(model.oneRepMaxSeed == 0)
    }

    @Test func effortAndWeeklyVolumeCarryCompleteAccessibilitySemantics() throws {
        let effort = ExerciseEffortSummary(
            avgRIR: 2.25,
            lifetimeAvgRIR: 1.75,
            loggedSetCount: 8,
            lastSessionSetCount: 3,
            verdict: .ready
        )
        let contribution = ExerciseVolumeContribution(
            shares: [
                .init(
                    muscle: .pectoralisMajorSternocostal,
                    role: .primary,
                    sets: 4.5
                ),
            ],
            totalSets: 4.5
        )
        let stat = MuscleVolumeStat(
            muscle: .pectoralisMajorSternocostal,
            effectiveSets: 12.5,
            allTimeEffectiveSets: 80,
            daysSinceLastTrained: 1,
            landmark: .default
        )
        let model = readModel(
            exercise: descriptor(loadMode: .assistanceSubtracted),
            effort: effort,
            volumeContribution: contribution,
            weeklyVolumeStats: [stat]
        )

        #expect(model.effort?.averageText == "RIR 2.2")
        #expect(model.effort?.lastSessionText == "Last · 3 sets")
        #expect(model.effort?.headline == "Ready · reduce assistance")
        #expect(model.effort?.accessibilityLabel.contains("8 logged RIR readings") == true)
        let row = try #require(model.weeklyVolume?.rows.first)
        #expect(row.contributionText == "+4.5")
        #expect(row.totalText == "12.5")
        #expect(row.zone == .optimal)
        #expect(row.accessibilityLabel.contains("inside the 8 to 18 productive band"))
        #expect(model.weeklyVolume?.bandText == "8–18")
    }

    @Test func measuredOneRepMaxAlwaysWinsTheEditorSeed() {
        let model = readModel(
            exercise: descriptor(
                measuredOneRepMax: 315,
                defaultLoggedWeight: 135
            )
        )

        #expect(model.oneRepMaxSeed == 315)
    }

    @Test func factoryUsesCoherentCacheWithoutConsultingTheArchive() {
        let item = ExerciseCatalogItem(
            catalogID: "fixture-lift",
            name: "Fixture Lift",
            group: .chest,
            defaultWeight: 95
        )
        let workout = session(
            daysAgo: 1,
            exercise: exercise(weight: 100, setCount: 3, rir: 2)
        )
        let cached = cachedReports([workout])
        let model = ExerciseDetailReadModel.make(
            item: item,
            cached: cached,
            unit: .lb,
            currentBodyweight: 180,
            calendar: calendar
        )

        item.name = "Changed later"
        workout.orderedExercises[0].sets[0].weight = 300

        #expect(model.exercise.name == "Fixture Lift")
        #expect(model.historyState == .single)
        #expect(model.bestSet.value == "100")
        #expect(model.effort?.verdict == .ready)
    }

    @Test func factoryPublishesCachedStrengthTrendAndReadiness() {
        let item = ExerciseCatalogItem(
            catalogID: "fixture-lift",
            name: "Fixture Lift",
            group: .chest,
            defaultWeight: 95
        )
        let sessions = [35, 28, 21, 14, 7, 0].enumerated().map { index, daysAgo in
            session(
                daysAgo: daysAgo,
                exercise: exercise(weight: 100 + Double(index * 5))
            )
        }
        let model = ExerciseDetailReadModel.make(
            item: item,
            cached: cachedReports(sessions),
            unit: .lb,
            currentBodyweight: 180,
            calendar: calendar
        )

        #expect(model.now == now)
        #expect(model.strengthTrendStat?.historyKey == "bundled:fixture-lift")
        #expect(model.strengthTrendReadinessDates.count == 6)
        #expect(model.latestHistoryInstance?.date == date(daysAgo: 0))
    }

    @Test func authoritativeEmptyCacheDoesNotFallBackToTheArchive() {
        let item = ExerciseCatalogItem(
            catalogID: "fixture-lift",
            name: "Fixture Lift",
            group: .chest,
            defaultWeight: 95
        )
        let model = ExerciseDetailReadModel.make(
            item: item,
            cached: .empty,
            unit: .lb,
            currentBodyweight: 180,
            calendar: calendar
        )

        #expect(model.historyState == .empty)
        #expect(model.progress == nil)
        #expect(model.strengthTrendStat == nil)
        #expect(model.strengthTrendReadinessDates.isEmpty)
        #expect(model.bestSet.value == "—")
        #expect(model.effort == nil)
        #expect(model.weeklyVolume == nil)
    }

    @Test func analyticsBridgeRetainsLastCompleteCoreGeneration() async {
        let analytics = SessionAnalytics()
        let workout = session(
            daysAgo: 1,
            exercise: exercise(weight: 100, setCount: 3, rir: 2)
        )

        let initial = analytics.exerciseDetailCachedReports()
        #expect(initial.historyByKey.isEmpty)
        #expect(initial.effortByKey.isEmpty)

        analytics.requestCore(for: [workout], now: now)
        await analytics.waitForPendingWork()

        let published = analytics.exerciseDetailCachedReports()
        #expect(published.generatedAt == now)
        #expect(
            published.historyByKey["bundled:fixture-lift"]?.sessionCount == 1
        )

        let nextNow = now.addingTimeInterval(86400)
        let nextWorkout = session(
            daysAgo: 0,
            exercise: exercise(weight: 105, setCount: 3, rir: 2)
        )
        analytics.requestCore(
            for: [nextWorkout, workout],
            now: nextNow
        )

        // The worker cannot publish until this MainActor turn yields.
        let retained = analytics.exerciseDetailCachedReports()
        #expect(retained.generatedAt == now)
        #expect(
            retained.historyByKey["bundled:fixture-lift"]?.sessionCount == 1
        )

        await analytics.waitForPendingWork()
        let replacement = analytics.exerciseDetailCachedReports()
        #expect(replacement.generatedAt == nextNow)
        #expect(
            replacement.historyByKey["bundled:fixture-lift"]?.sessionCount == 2
        )
    }
}
