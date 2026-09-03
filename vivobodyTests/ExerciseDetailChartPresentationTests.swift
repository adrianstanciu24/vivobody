//
//  ExerciseDetailChartPresentationTests.swift
//  vivobodyTests
//
//  Guards Exercise Detail's pure chart presentation: metric fallback,
//  captured-time filtering, dormant points, units, and record markers.
//

import Foundation
import Testing
@testable import vivobody

@MainActor
struct ExerciseDetailChartPresentationTests {
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
        modality: ExerciseModality = .dynamicStrength,
        trackingMode: TrackingMode = .reps,
        loadMode: ExerciseLoadMode = .external,
        tracksResistance: Bool = true
    ) -> ExerciseDetailReadModel.ExerciseDescriptor {
        ExerciseDetailReadModel.ExerciseDescriptor(
            name: "Fixture Lift",
            modality: modality,
            trackingMode: trackingMode,
            loadMode: loadMode,
            bodyweightFraction: 0,
            tracksResistance: tracksResistance,
            measuredOneRepMax: nil,
            defaultLoggedWeight: 0,
            currentBodyweight: ExerciseLoad.unknownBodyweight
        )
    }

    private func session(
        daysAgo: Int,
        weight: Double = 0,
        reps: Int = 0,
        duration: TimeInterval = 0,
        modality: ExerciseModality = .dynamicStrength,
        trackingMode: TrackingMode = .reps,
        loadMode: ExerciseLoadMode = .external
    ) -> WorkoutSession {
        let exercise = Exercise(
            name: "Fixture Lift",
            catalogID: "fixture-lift",
            group: .chest,
            plannedSets: 0,
            plannedWeight: 0,
            trackingMode: trackingMode,
            modality: modality,
            loadMode: loadMode
        )
        exercise.sets.append(
            WorkoutSet(
                weight: weight,
                reps: reps,
                duration: duration,
                isCompleted: true
            )
        )
        let timestamp = date(daysAgo: daysAgo)
        let session = WorkoutSession(
            exercises: [exercise],
            startedAt: timestamp
        )
        session.completedAt = timestamp
        return session
    }

    private func readModel(
        descriptor: ExerciseDetailReadModel.ExerciseDescriptor,
        sessions: [WorkoutSession]
    ) -> ExerciseDetailReadModel {
        let accumulator = AnalyticsAccumulator.history(
            AnalyticsSnapshot(sessions: sessions)
        )
        let history = accumulator.exerciseHistoryByExercise().values.first
        let progress = accumulator.progressByExercise.first
        return ExerciseDetailReadModel(
            exercise: descriptor,
            history: history,
            progress: progress,
            strengthTrendStat: nil,
            effort: nil,
            volumeContribution: nil,
            weeklyVolumeByMuscle: [:],
            unit: .lb,
            now: now,
            calendar: calendar
        )
    }

    private func presentation(
        _ readModel: ExerciseDetailReadModel,
        metric: ExerciseDetailChartMetric,
        range: ExerciseDetailChartRange = .all
    ) -> ExerciseDetailChartPresentation {
        ExerciseDetailChartPresentation(
            readModel: readModel,
            selectedMetric: metric,
            range: range,
            unit: .lb,
            calendar: calendar
        )
    }

    @Test func unresistedRepsUseTheOnlyHonestMetric() {
        let readModel = readModel(
            descriptor: descriptor(
                modality: .power,
                loadMode: .nonComparable,
                tracksResistance: false
            ),
            sessions: [
                session(daysAgo: 8, reps: 6, modality: .power, loadMode: .nonComparable),
                session(daysAgo: 2, reps: 9, modality: .power, loadMode: .nonComparable),
            ]
        )

        let presentation = presentation(readModel, metric: .e1rm)

        #expect(presentation.availableMetrics == [.reps])
        #expect(presentation.effectiveMetric == .reps)
        #expect(presentation.plottablePoints.map(\.value) == [6, 9])
        #expect(presentation.metricAccessibilityName == "Reps")
        #expect(presentation.chartAccessibilityValue.contains("6 reps"))
        #expect(presentation.chartAccessibilityValue.contains("9 reps"))
        #expect(presentation.personalRecordPointIDs.isEmpty)
    }

    @Test func rangeAndFutureFilteringShareTheCapturedClock() {
        let readModel = readModel(
            descriptor: descriptor(),
            sessions: [
                session(daysAgo: 40, weight: 90, reps: 5),
                session(daysAgo: 10, weight: 100, reps: 5),
                session(daysAgo: -1, weight: 110, reps: 5),
            ]
        )

        let presentation = presentation(
            readModel,
            metric: .weight,
            range: .oneMonth
        )

        #expect(presentation.visiblePoints.map(\.date) == [date(daysAgo: 10)])
        #expect(presentation.plottablePoints.map(\.value) == [100])
        #expect(presentation.placeholder?.legend == "Only one session in this range")
        #expect(presentation.placeholder?.showsNextSlot == false)
    }

    @Test func dormantChartUsesTheSingleImmutableHistoryPoint() {
        let readModel = readModel(
            descriptor: descriptor(),
            sessions: [session(daysAgo: 40, weight: 100, reps: 5)]
        )

        let allTime = presentation(readModel, metric: .weight)
        let oneMonth = presentation(
            readModel,
            metric: .weight,
            range: .oneMonth
        )

        #expect(allTime.placeholder?.legend == "One more session draws the line")
        #expect(allTime.placeholder?.plottedValue == "100 lb")
        #expect(allTime.placeholder?.showsNextSlot == true)
        #expect(oneMonth.placeholder?.legend == "No sessions in this range")
        #expect(oneMonth.placeholder?.plottedValue == nil)
        #expect(
            oneMonth.placeholder?.accessibilityLabel
                == "Progress chart unavailable. Choose a longer range or log another session."
        )
    }

    @Test func durationHistoryKeepsTimeValuesAndLabels() {
        let readModel = readModel(
            descriptor: descriptor(
                modality: .isometricStrength,
                trackingMode: .duration,
                loadMode: .nonComparable,
                tracksResistance: false
            ),
            sessions: [
                session(
                    daysAgo: 8,
                    duration: 30,
                    modality: .isometricStrength,
                    trackingMode: .duration,
                    loadMode: .nonComparable
                ),
                session(
                    daysAgo: 2,
                    duration: 45,
                    modality: .isometricStrength,
                    trackingMode: .duration,
                    loadMode: .nonComparable
                ),
            ]
        )

        let presentation = presentation(readModel, metric: .e1rm)

        #expect(presentation.effectiveMetric == .weight)
        #expect(presentation.metricAccessibilityName == "Duration")
        #expect(presentation.plottablePoints.map(\.valueLabel) == ["0:30", "0:45"])
        #expect(presentation.placeholder == nil)
    }

    @Test func recordMarkersStayOffTheVolumeSeries() {
        let readModel = readModel(
            descriptor: descriptor(),
            sessions: [
                session(daysAgo: 8, weight: 100, reps: 5),
                session(daysAgo: 2, weight: 110, reps: 5),
            ]
        )

        let load = presentation(readModel, metric: .weight)
        let volume = presentation(readModel, metric: .volume)

        #expect(load.personalRecordPointIDs.count == 2)
        #expect(volume.personalRecordPointIDs.isEmpty)
    }
}
